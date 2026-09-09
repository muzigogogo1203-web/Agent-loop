import Foundation

package protocol ModelLoopExecutionDrivingV1: Sendable {
    func startExecution(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> ModelLoopExecutionRunV1

    func execute(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>

    func cancel(executionId: String) async throws
}

package enum ModelLoopExecutionCancellationV1: @unchecked Sendable {
    case target(@Sendable () async throws -> Void)
    case completed(Result<Void, any Error>)
}

package struct ModelLoopExecutionRunV1: @unchecked Sendable {
    package let events: AsyncThrowingStream<
        EngineExecutionEventPayloadV1,
        Error
    >
    package let cancellation: ModelLoopExecutionCancellationV1

    package init(
        events: AsyncThrowingStream<
            EngineExecutionEventPayloadV1,
            Error
        >,
        cancellation: ModelLoopExecutionCancellationV1
    ) {
        self.events = events
        self.cancellation = cancellation
    }
}

package extension ModelLoopExecutionDrivingV1 {
    func startExecution(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> ModelLoopExecutionRunV1 {
        ModelLoopExecutionRunV1(
            events: execute(
                request: request,
                context: context,
                workspaceURL: workspaceURL,
                terminalSink: terminalSink,
                boardTerminalSink: boardTerminalSink,
                progressSink: progressSink
            ),
            cancellation: .target {
                try await cancel(executionId: request.executionId)
            }
        )
    }
}

package enum EngineAdapterCancellationLifecycleEventV1:
    Sendable,
    Equatable
{
    case claimLookup
    case generationOutcomePublished
    case cancellationOwnerSettled
}

package final class EngineAdapterCancellationGenerationV1:
    @unchecked Sendable
{
    package enum TaskOrOutcome: @unchecked Sendable {
        case task(Task<Void, Error>)
        case completed(Result<Void, any Error>)
    }

    private enum CancellationOwner: @unchecked Sendable {
        case none
        case running(
            EngineAdapterCancellationOwnerTokenV1,
            Task<Void, Error>
        )
        case settled(
            EngineAdapterCancellationOwnerTokenV1,
            Result<Void, any Error>
        )
    }

    package typealias CancellationOperation = @Sendable (
        EngineAdapterCancellationGenerationV1
    ) async throws -> Void
    package typealias CancellationOwnerSettled = @Sendable (
        EngineAdapterCancellationGenerationV1,
        EngineAdapterCancellationOwnerTokenV1
    ) -> Void
    package typealias StartCancellationOwner = @Sendable () -> Void

    package let executionId: String
    package let token = EngineAdapterCancellationGenerationTokenV1()

    private let lock = NSLock()
    private var task: Task<Void, Error>?
    private var outcome: Result<Void, any Error>?
    private var outerTaskSettled = false
    private var taskWaiters: [
        CheckedContinuation<TaskOrOutcome, Never>
    ] = []
    private var outcomeWaiters: [
        CheckedContinuation<Result<Void, any Error>, Never>
    ] = []
    private var cancellationOwner: CancellationOwner = .none
    private var productionHandoffRequired = false
    private var productionHandoffAcknowledged = false
    private var issuedClaims: [
        ObjectIdentifier: EngineAdapterCancellationClaimTokenV1
    ] = [:]
    private var outstandingLiveClaims: Set<ObjectIdentifier> = []

    package init(executionId: String) {
        self.executionId = executionId
    }

    package func attach(_ task: Task<Void, Error>) throws {
        let waiters = try lock.withLock {
            () throws -> [CheckedContinuation<TaskOrOutcome, Never>] in
            guard self.task == nil, outcome == nil, !outerTaskSettled else {
                throw EngineDispatchConflictErrorV1()
            }
            self.task = task
            let waiters = taskWaiters
            taskWaiters.removeAll()
            return waiters
        }
        waiters.forEach { $0.resume(returning: .task(task)) }
    }

    package func publishOutcome(
        _ result: Result<Void, any Error>
    ) {
        let waiters = lock.withLock { () -> (
            task: [CheckedContinuation<TaskOrOutcome, Never>],
            outcome: [
                CheckedContinuation<Result<Void, any Error>, Never>
            ],
            taskResolution: TaskOrOutcome
        ) in
            guard outcome == nil else {
                preconditionFailure("duplicate adapter generation outcome")
            }
            outcome = result
            let taskResolution = TaskOrOutcome.completed(result)
            let task = taskWaiters
            taskWaiters.removeAll()
            let outcome = outcomeWaiters
            outcomeWaiters.removeAll()
            return (task, outcome, taskResolution)
        }
        waiters.task.forEach {
            $0.resume(returning: waiters.taskResolution)
        }
        waiters.outcome.forEach { $0.resume(returning: result) }
    }

    package func markOuterTaskSettled() {
        lock.withLock {
            precondition(
                outcome != nil,
                "adapter outer Task settled before generation outcome"
            )
            precondition(
                !outerTaskSettled,
                "duplicate adapter outer Task settlement"
            )
            outerTaskSettled = true
            task = nil
        }
    }

    package func loadTaskOrOutcome() async -> TaskOrOutcome {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock { () -> TaskOrOutcome? in
                if let outcome { return .completed(outcome) }
                if let task { return .task(task) }
                taskWaiters.append(continuation)
                return nil
            }
            if let immediate { continuation.resume(returning: immediate) }
        }
    }

    package func waitForOutcome() async -> Result<Void, any Error> {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock {
                () -> Result<Void, any Error>? in
                if let outcome { return outcome }
                outcomeWaiters.append(continuation)
                return nil
            }
            if let immediate { continuation.resume(returning: immediate) }
        }
    }

    package func claimCancellation(
        operation: @escaping CancellationOperation,
        onSettled: @escaping CancellationOwnerSettled
    ) -> (
        claim: EngineAdapterCancellationClaimV1,
        startOwner: StartCancellationOwner
    ) {
        let installed = installCancellationOwner(
            operation: operation,
            onSettled: onSettled,
            issuesClaim: true
        )
        guard let claimToken = installed.claimToken else {
            preconditionFailure("cancellation claim token was not installed")
        }
        return (
            EngineAdapterCancellationClaimV1(
                executionId: executionId,
                generationToken: token,
                ownerToken: installed.ownerToken,
                claimToken: claimToken,
                task: installed.task
            ),
            installed.startOwner
        )
    }

    package func signalCancellation(
        operation: @escaping CancellationOperation,
        onSettled: @escaping CancellationOwnerSettled
    ) -> StartCancellationOwner {
        installCancellationOwner(
            operation: operation,
            onSettled: onSettled,
            issuesClaim: false
        ).startOwner
    }

    @discardableResult
    package func acknowledgeCancellation(
        generationToken: EngineAdapterCancellationGenerationTokenV1,
        ownerToken: EngineAdapterCancellationOwnerTokenV1,
        claimToken: EngineAdapterCancellationClaimTokenV1
    ) -> Bool {
        lock.withLock {
            guard token === generationToken,
                  ownerTokenMatches(ownerToken),
                  issuedClaims.removeValue(
                    forKey: ObjectIdentifier(claimToken)
                  ) === claimToken
            else { return false }
            outstandingLiveClaims.remove(ObjectIdentifier(claimToken))
            productionHandoffAcknowledged = true
            return true
        }
    }

    package var isRetirable: Bool {
        lock.withLock {
            guard outcome != nil,
                  outerTaskSettled,
                  outstandingLiveClaims.isEmpty
            else { return false }
            switch cancellationOwner {
            case .none:
                return !productionHandoffRequired
            case .running:
                return false
            case .settled:
                return !productionHandoffRequired
                    || productionHandoffAcknowledged
            }
        }
    }

    private func installCancellationOwner(
        operation: @escaping CancellationOperation,
        onSettled: @escaping CancellationOwnerSettled,
        issuesClaim: Bool
    ) -> (
        ownerToken: EngineAdapterCancellationOwnerTokenV1,
        task: Task<Void, Error>,
        claimToken: EngineAdapterCancellationClaimTokenV1?,
        startOwner: StartCancellationOwner
    ) {
        lock.withLock {
            productionHandoffRequired = true
            let ownerToken: EngineAdapterCancellationOwnerTokenV1
            let ownerTask: Task<Void, Error>
            let gate: ModelLoopAdapterPublicationGateV1?
            let ownerIsRunning: Bool
            switch cancellationOwner {
            case .none:
                let newOwnerToken = EngineAdapterCancellationOwnerTokenV1()
                let newGate = ModelLoopAdapterPublicationGateV1()
                let generation = self
                let newTask = Task {
                    await newGate.waitUntilOpened()
                    let result: Result<Void, any Error>
                    do {
                        try await operation(generation)
                        result = .success(())
                    } catch {
                        result = .failure(error)
                    }
                    generation.settleCancellationOwner(
                        newOwnerToken,
                        result: result
                    )
                    onSettled(generation, newOwnerToken)
                    return try result.get()
                }
                cancellationOwner = .running(newOwnerToken, newTask)
                ownerToken = newOwnerToken
                ownerTask = newTask
                gate = newGate
                ownerIsRunning = true
            case let .running(currentToken, currentTask):
                ownerToken = currentToken
                ownerTask = currentTask
                gate = nil
                ownerIsRunning = true
            case let .settled(currentToken, result):
                ownerToken = currentToken
                ownerTask = Task { try result.get() }
                gate = nil
                ownerIsRunning = false
            }

            let claimToken: EngineAdapterCancellationClaimTokenV1?
            if issuesClaim {
                let newClaimToken = EngineAdapterCancellationClaimTokenV1()
                let identifier = ObjectIdentifier(newClaimToken)
                issuedClaims[identifier] = newClaimToken
                if ownerIsRunning { outstandingLiveClaims.insert(identifier) }
                claimToken = newClaimToken
            } else {
                claimToken = nil
            }
            return (
                ownerToken,
                ownerTask,
                claimToken,
                { gate?.open() }
            )
        }
    }

    private func settleCancellationOwner(
        _ ownerToken: EngineAdapterCancellationOwnerTokenV1,
        result: Result<Void, any Error>
    ) {
        lock.withLock {
            guard case let .running(currentToken, _) = cancellationOwner,
                  currentToken === ownerToken
            else {
                preconditionFailure(
                    "cancellation owner settled outside its generation"
                )
            }
            cancellationOwner = .settled(ownerToken, result)
            outstandingLiveClaims.removeAll()
        }
    }

    private func ownerTokenMatches(
        _ ownerToken: EngineAdapterCancellationOwnerTokenV1
    ) -> Bool {
        switch cancellationOwner {
        case .none:
            return false
        case let .running(currentToken, _),
             let .settled(currentToken, _):
            return currentToken === ownerToken
        }
    }
}

package final class EngineAdapterCancellationGenerationTokenV1:
    @unchecked Sendable
{}

package final class EngineAdapterCancellationOwnerTokenV1:
    @unchecked Sendable
{}

package final class EngineAdapterCancellationClaimTokenV1:
    @unchecked Sendable
{}

package struct EngineAdapterCancellationClaimV1: Sendable {
    package let executionId: String
    package let generationToken: EngineAdapterCancellationGenerationTokenV1
    package let ownerToken: EngineAdapterCancellationOwnerTokenV1
    package let claimToken: EngineAdapterCancellationClaimTokenV1
    package let task: Task<Void, Error>

    package init(
        executionId: String,
        generationToken: EngineAdapterCancellationGenerationTokenV1,
        ownerToken: EngineAdapterCancellationOwnerTokenV1,
        claimToken: EngineAdapterCancellationClaimTokenV1,
        task: Task<Void, Error>
    ) {
        self.executionId = executionId
        self.generationToken = generationToken
        self.ownerToken = ownerToken
        self.claimToken = claimToken
        self.task = task
    }

    package func wait() async throws {
        try await task.value
    }
}

private final class ModelLoopAdapterPublicationGateV1: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var waiter: CheckedContinuation<Void, Never>?

    func waitUntilOpened() async {
        if lock.withLock({ opened }) { return }
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock { () -> Bool in
                if opened { return true }
                precondition(waiter == nil, "duplicate ModelLoop start waiter")
                waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func open() {
        let current = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            precondition(!opened, "duplicate ModelLoop start open")
            opened = true
            let current = waiter
            waiter = nil
            return current
        }
        current?.resume()
    }
}

private final class ModelLoopDownstreamCancellationCellV1:
    @unchecked Sendable
{
    private enum Resolution: @unchecked Sendable {
        case target(@Sendable () async throws -> Void)
        case completed(Result<Void, any Error>)
    }

    private enum State {
        case pending([CheckedContinuation<Resolution, Never>])
        case resolved(Resolution)
    }

    private let lock = NSLock()
    private var state: State = .pending([])

    func waitUntilResolved() async -> ModelLoopExecutionCancellationV1 {
        let resolution: Resolution = await withCheckedContinuation {
            continuation in
            let immediate = lock.withLock { () -> Resolution? in
                switch state {
                case let .pending(waiters):
                    state = .pending(waiters + [continuation])
                    return nil
                case let .resolved(resolution):
                    return resolution
                }
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
        return Self.publicResolution(resolution)
    }

    func publish(_ cancellation: ModelLoopExecutionCancellationV1) {
        let resolution: Resolution
        switch cancellation {
        case let .target(target): resolution = .target(target)
        case let .completed(result): resolution = .completed(result)
        }
        let waiters = lock.withLock {
            () -> [CheckedContinuation<Resolution, Never>] in
            guard case let .pending(waiters) = state else {
                preconditionFailure("duplicate ModelLoop downstream publication")
            }
            state = .resolved(resolution)
            return waiters
        }
        waiters.forEach { $0.resume(returning: resolution) }
    }

    func completeIfPending(_ result: Result<Void, any Error>) {
        let resolution = Resolution.completed(result)
        let waiters = lock.withLock {
            () -> [CheckedContinuation<Resolution, Never>] in
            guard case let .pending(waiters) = state else { return [] }
            state = .resolved(resolution)
            return waiters
        }
        waiters.forEach { $0.resume(returning: resolution) }
    }

    private static func publicResolution(
        _ resolution: Resolution
    ) -> ModelLoopExecutionCancellationV1 {
        switch resolution {
        case let .target(target): return .target(target)
        case let .completed(result): return .completed(result)
        }
    }
}

private final class ModelLoopAdapterTaskRegistryV1: @unchecked Sendable {
    private struct Entry {
        let generation: EngineAdapterCancellationGenerationV1
        let downstream: ModelLoopDownstreamCancellationCellV1
    }

    private let lock = NSLock()
    private let cancellationLifecycleObserver: @Sendable (
        EngineAdapterCancellationLifecycleEventV1
    ) -> Void
    private var entries: [String: Entry] = [:]

    init(
        cancellationLifecycleObserver: @escaping @Sendable (
            EngineAdapterCancellationLifecycleEventV1
        ) -> Void
    ) {
        self.cancellationLifecycleObserver = cancellationLifecycleObserver
    }

    func reserve(
        executionId: String,
        downstream: ModelLoopDownstreamCancellationCellV1
    ) throws -> EngineAdapterCancellationGenerationV1
    {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        let generation = EngineAdapterCancellationGenerationV1(
            executionId: executionId
        )
        try lock.withLock {
            guard entries[executionId] == nil else {
                throw EngineDispatchConflictErrorV1()
            }
            entries[executionId] = Entry(
                generation: generation,
                downstream: downstream
            )
        }
        return generation
    }

    func attach(
        _ task: Task<Void, Error>,
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1
    ) throws {
        try lock.withLock {
            guard entries[executionId]?.generation === generation else {
                throw EngineDispatchConflictErrorV1()
            }
            try generation.attach(task)
        }
    }

    func publishOutcome(
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1,
        result: Result<Void, any Error>
    ) {
        generation.publishOutcome(result)
        cancellationLifecycleObserver(.generationOutcomePublished)
        lock.withLock {
            retireIfEligibleLocked(
                executionId: executionId,
                generation: generation
            )
        }
    }

    func markOuterTaskSettled(
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1
    ) {
        generation.markOuterTaskSettled()
        lock.withLock {
            retireIfEligibleLocked(
                executionId: executionId,
                generation: generation
            )
        }
    }

    func claimCancellation(
        executionId: String
    ) throws -> EngineAdapterCancellationClaimV1 {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        let installed = try lock.withLock { () throws -> (
            claim: EngineAdapterCancellationClaimV1,
            startOwner:
                EngineAdapterCancellationGenerationV1.StartCancellationOwner
        ) in
            guard let entry = entries[executionId] else {
                throw EngineDispatchConflictErrorV1()
            }
            let installed = makeCancellationClaimLocked(entry)
            cancellationLifecycleObserver(.claimLookup)
            return installed
        }
        installed.startOwner()
        return installed.claim
    }

    func signalCancellation(
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1
    ) {
        let startOwner = lock.withLock {
            () -> EngineAdapterCancellationGenerationV1
                .StartCancellationOwner? in
            guard let entry = entries[executionId],
                  entry.generation === generation
            else { return nil }
            return makeCancellationSignalLocked(entry)
        }
        startOwner?()
    }

    func acknowledgeCancellation(
        _ claim: EngineAdapterCancellationClaimV1
    ) {
        lock.withLock {
            guard let entry = entries[claim.executionId],
                  entry.generation.token === claim.generationToken,
                  entry.generation.acknowledgeCancellation(
                    generationToken: claim.generationToken,
                    ownerToken: claim.ownerToken,
                    claimToken: claim.claimToken
                  )
            else { return }
            retireIfEligibleLocked(
                executionId: claim.executionId,
                generation: entry.generation
            )
        }
    }

    private func makeCancellationClaimLocked(
        _ entry: Entry
    ) -> (
        claim: EngineAdapterCancellationClaimV1,
        startOwner:
            EngineAdapterCancellationGenerationV1.StartCancellationOwner
    ) {
        entry.generation.claimCancellation(
            operation: cancellationOperation(for: entry),
            onSettled: { [weak self] generation, _ in
                self?.cancellationOwnerDidSettle(generation)
            }
        )
    }

    private func makeCancellationSignalLocked(
        _ entry: Entry
    ) -> EngineAdapterCancellationGenerationV1.StartCancellationOwner {
        entry.generation.signalCancellation(
            operation: cancellationOperation(for: entry),
            onSettled: { [weak self] generation, _ in
                self?.cancellationOwnerDidSettle(generation)
            }
        )
    }

    private func cancellationOperation(
        for entry: Entry
    ) -> EngineAdapterCancellationGenerationV1.CancellationOperation {
        { generation in
            var firstError: (any Error)?
            var cancelOuter = false
            let outerTask: Task<Void, Error>?
            switch await generation.loadTaskOrOutcome() {
            case let .task(task): outerTask = task
            case let .completed(result):
                outerTask = nil
                if case let .failure(error) = result,
                   !(error is CancellationError)
                {
                    throw error
                }
                return
            }
            switch await entry.downstream.waitUntilResolved() {
            case let .target(cancel):
                cancelOuter = true
                do {
                    try await cancel()
                } catch {
                    firstError = error
                }
            case let .completed(result):
                if case let .failure(error) = result {
                    firstError = error
                }
            }

            // A downstream cancellation target owns teardown and waits for
            // its producer outcome. If that teardown already failed, keep
            // the outer consumer alive long enough to observe the same
            // non-cancellation failure from its event stream. Cancelling the
            // outer task here would replace that durable failure with a
            // consumer-side CancellationError.
            if cancelOuter, firstError == nil { outerTask?.cancel() }
            let outer = await generation.waitForOutcome()
            if let outerTask { _ = await outerTask.result }
            if case let .failure(error) = outer,
               !(error is CancellationError), firstError == nil
            {
                firstError = error
            }
            if let firstError { throw firstError }
        }
    }

    private func cancellationOwnerDidSettle(
        _ generation: EngineAdapterCancellationGenerationV1
    ) {
        cancellationLifecycleObserver(.cancellationOwnerSettled)
        lock.withLock {
            retireIfEligibleLocked(
                executionId: generation.executionId,
                generation: generation
            )
        }
    }

    private func retireIfEligibleLocked(
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1
    ) {
        guard entries[executionId]?.generation === generation,
              generation.isRetirable
        else { return }
        entries[executionId] = nil
    }
}

package struct ModelLoopEngineAdapter: ExecutionEngineAdapter {
    package let profile: RuntimeProfileRecord
    package let descriptor: ExecutionEngineDescriptor
    package let driver: any ModelLoopExecutionDrivingV1
    package let context: EngineResolvedContextTransportV1
    package let workspace: EngineResolvedWorkspaceV1
    package let boundCapabilityTools: EngineBoundCapabilityToolsV1
    package let terminalSink: any EngineTerminalSink
    package let boardTerminalSink: any EngineBoardTerminalSink
    package let progressSink: any EngineProgressSink
    private let taskRegistry: ModelLoopAdapterTaskRegistryV1

    package init(
        profile: RuntimeProfileRecord,
        descriptor: ExecutionEngineDescriptor,
        driver: any ModelLoopExecutionDrivingV1,
        context: EngineResolvedContextTransportV1,
        workspace: EngineResolvedWorkspaceV1,
        boundCapabilityTools: EngineBoundCapabilityToolsV1,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        cancellationLifecycleObserver: @escaping @Sendable (
            EngineAdapterCancellationLifecycleEventV1
        ) -> Void = { _ in }
    ) {
        self.profile = profile
        self.descriptor = descriptor
        self.driver = driver
        self.context = context
        self.workspace = workspace
        self.boundCapabilityTools = boundCapabilityTools
        self.terminalSink = terminalSink
        self.boardTerminalSink = boardTerminalSink
        self.progressSink = progressSink
        taskRegistry = ModelLoopAdapterTaskRegistryV1(
            cancellationLifecycleObserver: cancellationLifecycleObserver
        )
    }

    package func descriptor(
        profile: RuntimeProfileRecord
    ) throws -> ExecutionEngineDescriptor {
        guard profile.id == self.profile.id,
              profile.kind == self.profile.kind
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        return try validatedDescriptor()
    }

    package func execute(
        request: EngineExecutionRequest
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        AsyncThrowingStream { continuation in
            let downstream = ModelLoopDownstreamCancellationCellV1()
            let generation: EngineAdapterCancellationGenerationV1
            do {
                generation = try taskRegistry.reserve(
                    executionId: request.executionId,
                    downstream: downstream
                )
            } catch {
                continuation.finish(throwing: error)
                return
            }
            let gate = ModelLoopAdapterPublicationGateV1()
            let task = Task {
                let result: Result<Void, any Error>
                do {
                    await gate.waitUntilOpened()
                    try validate(request)
                    try Task.checkCancellation()
                    let run = driver.startExecution(
                        request: request,
                        context: context,
                        workspaceURL: workspace.url,
                        terminalSink: terminalSink,
                        boardTerminalSink: boardTerminalSink,
                        progressSink: progressSink
                    )
                    downstream.publish(run.cancellation)
                    for try await payload in run.events {
                        continuation.yield(payload)
                    }
                    try Task.checkCancellation()
                    result = .success(())
                } catch {
                    result = .failure(error)
                }
                downstream.completeIfPending(result)
                taskRegistry.publishOutcome(
                    executionId: request.executionId,
                    generation: generation,
                    result: result
                )
                return try result.get()
            }
            do {
                try taskRegistry.attach(
                    task,
                    executionId: request.executionId,
                    generation: generation
                )
            } catch {
                task.cancel()
                gate.open()
                continuation.finish(throwing: error)
                return
            }
            continuation.onTermination = { termination in
                guard case .cancelled = termination else { return }
                taskRegistry.signalCancellation(
                    executionId: request.executionId,
                    generation: generation
                )
            }
            Task {
                let result = await task.result
                taskRegistry.markOuterTaskSettled(
                    executionId: request.executionId,
                    generation: generation
                )
                switch result {
                case .success:
                    continuation.finish()
                case let .failure(error) where error is CancellationError:
                    continuation.finish()
                case let .failure(error):
                    continuation.finish(throwing: error)
                }
            }
            gate.open()
        }
    }

    package func cancel(executionId: String) async throws {
        let claim = try await claimCancellation(executionId: executionId)
        defer { acknowledgeCancellation(claim) }
        do {
            try await claim.wait()
        } catch is CancellationError {
        } catch {
            throw error
        }
    }

    package func claimCancellation(
        executionId: String
    ) async throws -> EngineAdapterCancellationClaimV1 {
        try taskRegistry.claimCancellation(executionId: executionId)
    }

    package func acknowledgeCancellation(
        _ claim: EngineAdapterCancellationClaimV1
    ) {
        taskRegistry.acknowledgeCancellation(claim)
    }

    private func validatedDescriptor() throws -> ExecutionEngineDescriptor {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(profile.id)
        } catch {
            throw EngineDescriptorMismatchErrorV1()
        }
        guard !profile.kind.isCLI,
              descriptor.adapterId == "agentloop.model-loop",
              descriptor.adapterVersion == "1",
              descriptor.profileKind == profile.kind,
              descriptor.streamingProgress == .supported,
              descriptor.boardTerminal == .supported,
              descriptor.toolBridge == .supported,
              descriptor.cancellation == .supported,
              descriptor.sessionResume == .unsupported,
              descriptor.usageMetering == .supported,
              descriptor.workspaceRead == .supported,
              descriptor.workspaceWrite == .supported,
              descriptor.network == .supported
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        return descriptor
    }

    private func validate(_ request: EngineExecutionRequest) throws {
        let descriptor = try validatedDescriptor()
        let canonical = try EngineExecutionRequest.makeCanonical(
            protocolVersion: request.protocolVersion,
            executionId: request.executionId,
            idempotencyKey: request.idempotencyKey,
            campId: request.campId,
            campLifecycleVersion: request.campLifecycleVersion,
            runId: request.runId,
            cardId: request.cardId,
            contract: request.contract,
            adapterId: request.adapterId,
            adapterVersion: request.adapterVersion,
            profileId: request.profileId,
            engineKind: request.engineKind,
            model: request.model,
            replayClass: request.replayClass,
            contextJson: request.contextJson,
            contextHash: request.contextHash,
            sessionScopeJson: request.sessionScopeJson,
            sessionScopeHash: request.sessionScopeHash,
            requiredCapabilities: request.requiredCapabilities,
            approvalGrantIds: request.approvalGrantIds,
            budget: request.budget,
            workspace: request.workspace,
            predecessorExecutionId: request.predecessorExecutionId,
            sessionRef: request.sessionRef
        )
        guard canonical == request else {
            throw EngineExecutionReplayConflictError()
        }
        do {
            try CanonicalContractCodingV1.validateNonempty(request.engineKind)
            try CanonicalContractCodingV1.validateNonempty(request.model)
            for grantId in request.approvalGrantIds {
                try CanonicalContractCodingV1.validateCanonicalUUID(grantId)
            }
        } catch {
            throw EngineContextValidationErrorV1()
        }
        guard request.adapterId == descriptor.adapterId,
              request.adapterVersion == descriptor.adapterVersion,
              request.profileId == profile.id
        else {
            throw EngineDescriptorMismatchErrorV1()
        }
        for capability in request.requiredCapabilities {
            guard descriptor.support(for: capability) == .supported else {
                throw EngineAdapterSelectionErrorV1.unsupportedCapability(
                    capability
                )
            }
        }
        guard request.sessionRef == nil,
              request.predecessorExecutionId == nil
        else {
            throw EngineSessionScopeMismatchError()
        }

        let contextBytes = Data(context.canonicalEnvelopeJSON.utf8)
        guard context.canonicalEnvelopeJSON == request.contextJson,
              context.hash == request.contextHash,
              CanonicalJSONV1.sha256Hex(contextBytes) == context.hash
        else {
            throw EngineContextValidationErrorV1()
        }
        let expectedWorkspaceReference =
            "squad-workspace.v1:\(workspace.identity.squadId)"
        guard request.campId == workspace.identity.campId,
              request.workspace.reference == expectedWorkspaceReference,
              workspace.url.isFileURL,
              workspace.url.baseURL == nil,
              workspace.url.path.hasPrefix("/"),
              workspace.url.standardizedFileURL.path
                == workspace.identity.workspacePath
        else {
            throw EngineContextValidationErrorV1()
        }

        let scope = try EngineSessionScopeV1.derived(
            campId: request.campId,
            profileId: request.profileId,
            descriptor: descriptor,
            engineKind: request.engineKind,
            model: request.model,
            workspaceHash: request.workspace.hash,
            contract: request.contract
        )
        let scopeBytes = try CanonicalJSONV1.encode(scope)
        guard request.sessionScopeJson
                == String(decoding: scopeBytes, as: UTF8.self),
              request.sessionScopeHash
                == CanonicalJSONV1.sha256Hex(scopeBytes),
              request.replayClass == .nonReplayable,
              descriptor.executionReplayClass(for: scope)
                == request.replayClass
        else {
            throw EngineSessionScopeMismatchError()
        }
    }
}
