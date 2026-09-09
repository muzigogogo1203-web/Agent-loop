import Foundation

/// 外部工具装配单元：定义进入 provider 工具区，handler 进入同名分发表。
public struct ExternalTool: Sendable {
    public let def: ToolDef
    public let handler: any ToolHandler

    public init(def: ToolDef, handler: any ToolHandler) {
        self.def = def
        self.handler = handler
    }
}

package typealias ModelLoopCapabilityToolsResolveV1 =
    @Sendable (
        _ request: EngineExecutionRequest,
        _ workspaceURL: URL
    ) throws -> [ExternalTool]

private final class ModelLoopTaskPublicationGateV1: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var waiter: CheckedContinuation<Void, Never>?

    func waitUntilOpened() async {
        if lock.withLock({ opened }) { return }
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock { () -> Bool in
                if opened { return true }
                precondition(waiter == nil, "duplicate CardRunner start waiter")
                waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func open() {
        let current = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            precondition(!opened, "duplicate CardRunner start open")
            opened = true
            let current = waiter
            waiter = nil
            return current
        }
        current?.resume()
    }
}

private final class ModelLoopTaskRegistryV1: @unchecked Sendable {
    private let lock = NSLock()
    private let cancellationLifecycleObserver: @Sendable (
        EngineAdapterCancellationLifecycleEventV1
    ) -> Void
    private var entries: [
        String: EngineAdapterCancellationGenerationV1
    ] = [:]

    init(
        cancellationLifecycleObserver: @escaping @Sendable (
            EngineAdapterCancellationLifecycleEventV1
        ) -> Void
    ) {
        self.cancellationLifecycleObserver = cancellationLifecycleObserver
    }

    func reserve(
        executionId: String
    ) throws -> EngineAdapterCancellationGenerationV1 {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        } catch {
            throw EngineDispatchConflictErrorV1()
        }
        let generation = EngineAdapterCancellationGenerationV1(
            executionId: executionId
        )
        lock.lock()
        defer { lock.unlock() }
        guard entries[executionId] == nil else {
            throw EngineDispatchConflictErrorV1()
        }
        entries[executionId] = generation
        return generation
    }

    func attach(
        _ task: Task<Void, Error>,
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1
    ) throws {
        try lock.withLock {
            guard entries[executionId] === generation else {
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
            guard let generation = entries[executionId] else {
                throw EngineDispatchConflictErrorV1()
            }
            let installed = makeCancellationClaimLocked(
                generation: generation
            )
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
            guard entries[executionId] === generation else { return nil }
            return makeCancellationSignalLocked(generation: generation)
        }
        startOwner?()
    }

    func claimCancellation(
        executionId: String,
        generation: EngineAdapterCancellationGenerationV1
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
            guard generation.executionId == executionId,
                  entries[executionId] === generation
            else { throw EngineDispatchConflictErrorV1() }
            let installed = makeCancellationClaimLocked(
                generation: generation
            )
            cancellationLifecycleObserver(.claimLookup)
            return installed
        }
        installed.startOwner()
        return installed.claim
    }

    func acknowledgeCancellation(
        _ claim: EngineAdapterCancellationClaimV1
    ) {
        lock.withLock {
            guard let generation = entries[claim.executionId],
                  generation.token === claim.generationToken,
                  generation.acknowledgeCancellation(
                    generationToken: claim.generationToken,
                    ownerToken: claim.ownerToken,
                    claimToken: claim.claimToken
                  )
            else { return }
            retireIfEligibleLocked(
                executionId: claim.executionId,
                generation: generation
            )
        }
    }

    private func makeCancellationClaimLocked(
        generation: EngineAdapterCancellationGenerationV1
    ) -> (
        claim: EngineAdapterCancellationClaimV1,
        startOwner:
            EngineAdapterCancellationGenerationV1.StartCancellationOwner
    ) {
        generation.claimCancellation(
            operation: cancellationOperation,
            onSettled: { [weak self] generation, _ in
                self?.cancellationOwnerDidSettle(generation)
            }
        )
    }

    private func makeCancellationSignalLocked(
        generation: EngineAdapterCancellationGenerationV1
    ) -> EngineAdapterCancellationGenerationV1.StartCancellationOwner {
        generation.signalCancellation(
            operation: cancellationOperation,
            onSettled: { [weak self] generation, _ in
                self?.cancellationOwnerDidSettle(generation)
            }
        )
    }

    private var cancellationOperation:
        EngineAdapterCancellationGenerationV1.CancellationOperation
    {
        { generation in
            let outerTask: Task<Void, Error>?
            switch await generation.loadTaskOrOutcome() {
            case let .task(task):
                outerTask = task
                task.cancel()
            case let .completed(result):
                outerTask = nil
                if case let .failure(error) = result,
                   !(error is CancellationError)
                {
                    throw error
                }
                return
            }
            let result = await generation.waitForOutcome()
            if let outerTask { _ = await outerTask.result }
            if case let .failure(error) = result,
               !(error is CancellationError)
            {
                throw error
            }
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
        guard entries[executionId] === generation,
              generation.isRetirable
        else { return }
        entries[executionId] = nil
    }
}

private actor ModelLoopForwardingBoardTerminalSinkV1:
    EngineBoardTerminalSink
{
    private let downstream: any EngineBoardTerminalSink
    private var acceptedTerminal = false

    init(downstream: any EngineBoardTerminalSink) {
        self.downstream = downstream
    }

    func submit(_ intent: EngineBoardTerminalIntentV1) async throws {
        try await downstream.submit(intent)
        acceptedTerminal = true
    }

    func hasAcceptedTerminal() -> Bool {
        acceptedTerminal
    }
}

private struct ModelLoopCapabilityHandlerV1: ToolHandler {
    let inner: any ToolHandler

    func execute(input: JSONValue) async -> ToolOutcome {
        switch await inner.execute(input: input) {
        case let .result(value):
            return .result(value)
        case let .error(message):
            return .error(message)
        case .completed, .blocked:
            return .error("Capability tools cannot submit Board outcomes.")
        }
    }
}

private struct ModelLoopTerminalDeliveryFailureV1:
    Error,
    @unchecked Sendable
{
    let underlying: any Error
}

public struct CardRunner: ModelLoopExecutionDrivingV1, Sendable {
    package static let rateLimitReasonCode = "engine_provider_rate_limit"

    let provider: any LLMProvider
    let capabilityToolsResolver: ModelLoopCapabilityToolsResolveV1
    let maxTurns: Int
    let maxTokensPerTurn: Int
    let retryDelays: [Duration]
    let turnTimeout: Duration
    private let taskRegistry: ModelLoopTaskRegistryV1

    package init(
        provider: any LLMProvider,
        capabilityToolsResolver:
            @escaping ModelLoopCapabilityToolsResolveV1,
        maxTurns: Int = KernelDefaults.maxTurns,
        maxTokensPerTurn: Int = KernelDefaults.maxTokensPerTurn,
        retryDelays: [Duration] = [.seconds(2), .seconds(4)],
        turnTimeout: Duration = KernelDefaults.turnTimeout,
        cancellationLifecycleObserver: @escaping @Sendable (
            EngineAdapterCancellationLifecycleEventV1
        ) -> Void = { _ in }
    ) {
        self.provider = provider
        self.capabilityToolsResolver = capabilityToolsResolver
        self.maxTurns = maxTurns
        self.maxTokensPerTurn = maxTokensPerTurn
        self.retryDelays = retryDelays
        self.turnTimeout = turnTimeout
        taskRegistry = ModelLoopTaskRegistryV1(
            cancellationLifecycleObserver: cancellationLifecycleObserver
        )
    }

    package func execute(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        startExecution(
            request: request,
            context: context,
            workspaceURL: workspaceURL,
            terminalSink: terminalSink,
            boardTerminalSink: boardTerminalSink,
            progressSink: progressSink
        ).events
    }

    package func startExecution(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> ModelLoopExecutionRunV1 {
        let generation: EngineAdapterCancellationGenerationV1
        do {
            generation = try taskRegistry.reserve(
                executionId: request.executionId
            )
        } catch {
            return ModelLoopExecutionRunV1(
                events: AsyncThrowingStream {
                    $0.finish(throwing: error)
                },
                cancellation: .completed(.failure(error))
            )
        }

        let stream = AsyncThrowingStream<
            EngineExecutionEventPayloadV1,
            Error
        > { continuation in
            let gate = ModelLoopTaskPublicationGateV1()
            let task = Task {
                let result: Result<Void, any Error>
                do {
                    await gate.waitUntilOpened()
                    try Task.checkCancellation()
                    try await drive(
                        request: request,
                        context: context,
                        workspaceURL: workspaceURL,
                        terminalSink: terminalSink,
                        boardTerminalSink: boardTerminalSink,
                        progressSink: progressSink,
                        continuation: continuation
                    )
                    result = .success(())
                } catch {
                    result = .failure(error)
                }
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
        return ModelLoopExecutionRunV1(
            events: stream,
            cancellation: .target {
                let claim = try taskRegistry.claimCancellation(
                    executionId: request.executionId,
                    generation: generation
                )
                defer { taskRegistry.acknowledgeCancellation(claim) }
                try await claim.wait()
            }
        )
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

    private func drive(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink,
        continuation:
            AsyncThrowingStream<EngineExecutionEventPayloadV1, Error>
                .Continuation
    ) async throws {
        let forwardingBoardSink =
            ModelLoopForwardingBoardTerminalSinkV1(
                downstream: boardTerminalSink
            )
        do {
            try validateConfiguration()
            try Task.checkCancellation()
            let capabilityTools = try capabilityToolsResolver(
                request,
                workspaceURL
            )
            let assembled = try assembleTools(
                capabilityTools,
                boardTerminalSink: forwardingBoardSink,
                progressSink: progressSink
            )
            let loop = AgentLoop(
                provider: provider,
                executor: ToolExecutor(handlers: assembled.handlers),
                packet: context.packet,
                tools: assembled.definitions,
                maxTurns: maxTurns,
                tokenBudget: request.budget.tokenLimit,
                maxTokensPerTurn: maxTokensPerTurn,
                retryDelays: retryDelays,
                turnTimeout: turnTimeout
            )

            try Task.checkCancellation()
            continuation.yield(.accepted)
            let run = loop.makeRunHandle()
            var streamFailure: (any Error)?
            do {
                for try await event in run.events {
                    try Task.checkCancellation()
                    if case let .finished(outcome) = event {
                        let boardAccepted =
                            await forwardingBoardSink.hasAcceptedTerminal()
                        if !boardAccepted {
                            let intent = try Self.terminalIntent(for: outcome)
                            try await finishThroughSink(
                                intent,
                                terminalSink: terminalSink
                            )
                        }
                    }
                    if let payload = try Self.payload(for: event) {
                        continuation.yield(payload)
                    }
                }
            } catch {
                streamFailure = error
                run.completion.cancel()
            }

            let completionResult = await run.completion.result
            if case let .failure(completionFailure) = completionResult,
               !(completionFailure is CancellationError)
            {
                throw completionFailure
            }
            if let streamFailure {
                throw streamFailure
            }
            if case let .failure(completionFailure) = completionResult {
                throw completionFailure
            }
        } catch let delivery as ModelLoopTerminalDeliveryFailureV1 {
            throw delivery.underlying
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw error
            }
            if await forwardingBoardSink.hasAcceptedTerminal() {
                return
            }
            if Self.isRateLimit(error) {
                try await finishThroughSink(
                    .blocked(
                        subtype: .ordinary,
                        reasonCode: Self.rateLimitReasonCode,
                        detail: "ModelLoop provider rate limit exhausted."
                    ),
                    terminalSink: terminalSink
                )
            } else {
                try await finishThroughSink(
                    .failed(
                        code: "engine_provider_error",
                        detail: "ModelLoop execution failed."
                    ),
                    terminalSink: terminalSink
                )
            }
        }
    }

    private static func isRateLimit(_ error: any Error) -> Bool {
        guard let providerError = error as? ProviderError else { return false }
        switch providerError {
        case .http(let status, _):
            return status == 429
        case .overloadedRetriesExhausted:
            return true
        case .apiError(let type, _):
            return type == "rate_limit_error"
        case .unauthorized, .malformedStream:
            return false
        }
    }

    private func validateConfiguration() throws {
        guard maxTurns > 0,
              maxTokensPerTurn > 0,
              turnTimeout > .zero,
              retryDelays.allSatisfy({ $0 >= .zero })
        else {
            throw EngineContextValidationErrorV1()
        }
    }

    private func assembleTools(
        _ capabilityTools: [ExternalTool],
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) throws -> (
        definitions: [ToolDef],
        handlers: [String: any ToolHandler]
    ) {
        let board = BoardTools(
            boardTerminalSink: boardTerminalSink,
            progressSink: progressSink
        )
        let boardTools: [ExternalTool] = [
            ExternalTool(
                def: .completeCard,
                handler: BoardToolHandler(tools: board, op: .complete)
            ),
            ExternalTool(
                def: .blockCard,
                handler: BoardToolHandler(tools: board, op: .block)
            ),
            ExternalTool(
                def: .addProgressNote,
                handler: BoardToolHandler(tools: board, op: .note)
            ),
            ExternalTool(
                def: .askUser,
                handler: BoardToolHandler(tools: board, op: .askUser)
            ),
        ]
        let boardNames = Set(boardTools.map(\.def.name))
        var seen = boardNames
        var handlers = Dictionary(
            uniqueKeysWithValues: boardTools.map {
                ($0.def.name, $0.handler)
            }
        )

        for tool in capabilityTools {
            try EngineContractValidationV1.validateToolName(tool.def.name)
            guard !boardNames.contains(tool.def.name),
                  seen.insert(tool.def.name).inserted
            else {
                throw EngineDispatchConflictErrorV1()
            }
            handlers[tool.def.name] = ModelLoopCapabilityHandlerV1(
                inner: tool.handler
            )
        }

        let sortedCapabilities = capabilityTools.sorted {
            $0.def.name.utf8.lexicographicallyPrecedes($1.def.name.utf8)
        }
        return (
            definitions: boardTools.map(\.def)
                + sortedCapabilities.map(\.def),
            handlers: handlers
        )
    }

    private static func payload(
        for event: AgentEvent
    ) throws -> EngineExecutionEventPayloadV1? {
        switch event {
        case .turnStarted, .toolFinished, .finished:
            return nil
        case let .textDelta(text):
            try EngineContractValidationV1.validateProgress(text)
            return .progress(message: text)
        case let .toolStarted(name):
            try EngineContractValidationV1.validateToolName(name)
            return .toolActivity(name: name)
        case let .turnEnded(usage):
            let payload = EngineUsageV1(
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                cacheReadTokens: usage.cacheReadTokens,
                costMicros: 0
            )
            try payload.validateNonnegative()
            return .usage(payload)
        case let .turnRetrying(attempt, _):
            try CanonicalContractCodingV1.validatePositive(attempt)
            return .progress(message: "Model turn retry \(attempt).")
        case let .contextCompacted(fromMessages, toMessages):
            try CanonicalContractCodingV1.validateNonnegative(fromMessages)
            try CanonicalContractCodingV1.validateNonnegative(toMessages)
            return .progress(
                message:
                    "Model context compacted \(fromMessages) -> \(toMessages)."
            )
        }
    }

    private static func terminalIntent(
        for outcome: LoopOutcome
    ) throws -> EngineTerminalIntentV1 {
        switch outcome {
        case let .completed(handoff):
            return .completed(handoff: handoff)
        case let .blocked(reason, detail):
            try EngineContractValidationV1.validateReasonCode(reason)
            try EngineContractValidationV1.validateDetail(detail)
            return .blocked(
                subtype: .ordinary,
                reasonCode: reason,
                detail: detail
            )
        }
    }

    private func finishThroughSink(
        _ intent: EngineTerminalIntentV1,
        terminalSink: any EngineTerminalSink
    ) async throws {
        do {
            try await terminalSink.submit(intent)
        } catch {
            throw ModelLoopTerminalDeliveryFailureV1(underlying: error)
        }
    }

}
