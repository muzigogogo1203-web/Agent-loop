import Testing
import Foundation
import AgentLoopCore

final class StubHandler: ToolHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ToolOutcome]
    private(set) var calls: [JSONValue] = []

    init(_ outcomes: [ToolOutcome]) {
        self.outcomes = outcomes
    }

    func execute(input: JSONValue) async -> ToolOutcome {
        lock.withLock {
            calls.append(input)
            return outcomes.isEmpty ? .error("stub exhausted") : outcomes.removeFirst()
        }
    }
}

private actor FlakyProvider: LLMProvider {
    enum Failure: Sendable {
        case url(URLError.Code)
        case provider(ProviderError)

        var error: Error {
            switch self {
            case .url(let code):
                return URLError(code)
            case .provider(let error):
                return error
            }
        }
    }

    private enum Next: Sendable {
        case failure(Failure)
        case turn(TurnResult)
        case exhausted
    }

    private var failures: [Failure]
    private var script: [TurnResult]
    private(set) var callCount = 0
    private(set) var recordedHistories: [[APIMessage]] = []

    init(failures: [Failure], script: [TurnResult]) {
        self.failures = failures
        self.script = script
    }

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                switch await self.next(history: history) {
                case .failure(let failure):
                    continuation.finish(throwing: failure.error)
                case .turn(let turn):
                    for block in turn.content {
                        if case .text(let text) = block {
                            continuation.yield(.textDelta(text))
                        }
                    }
                    continuation.yield(.turn(turn))
                    continuation.finish()
                case .exhausted:
                    continuation.finish(throwing: ProviderError.malformedStream("flaky script exhausted"))
                }
            }
        }
    }

    private func next(history: [APIMessage]) -> Next {
        callCount += 1
        recordedHistories.append(history)
        if !failures.isEmpty {
            return .failure(failures.removeFirst())
        }
        return script.isEmpty ? .exhausted : .turn(script.removeFirst())
    }
}

#if DEBUG
private final class ManualAgentLoopClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        typealias Duration = Swift.Duration

        fileprivate let offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    typealias Duration = Swift.Duration

    private let storage = Storage()

    var now: Instant {
        storage.now
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        storage.prepare(id: id)
        defer { storage.finish(id: id) }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                storage.register(id: id, deadline: deadline, continuation: continuation)
            }
        } onCancel: {
            storage.cancel(id: id)
        }
    }

    func advance(by duration: Duration) {
        storage.advance(by: duration)
    }

    var waiterCount: Int {
        storage.waiterCount
    }

    var activeSleepCount: Int {
        storage.activeSleepCount
    }

    var cancellationCompletionCount: Int {
        storage.cancellationCompletionCount
    }

    var cancelBeforeRegistrationCompletionCount: Int {
        storage.cancelBeforeRegistrationCompletionCount
    }

    var registerBeforeCancelCompletionCount: Int {
        storage.registerBeforeCancelCompletionCount
    }

    func waitForWaiterCount(_ exactCount: Int) async {
        await storage.waitForWaiterCount(exactCount)
    }

    func waitForCancellationCompletionCount(_ minimumCount: Int) async {
        await storage.waitForCancellationCompletionCount(minimumCount)
    }

    private final class Storage: @unchecked Sendable {
        private enum CancellationOrder {
            case cancelBeforeRegistration
            case registerBeforeCancel
        }

        private enum SleepCompletion {
            case success
            case cancellation(CancellationOrder)
        }

        private enum SleepState {
            case prepared
            case waiting(deadline: Instant, continuation: CheckedContinuation<Void, Error>)
            case cancelledBeforeRegistration
            case completed(SleepCompletion)
        }

        private enum SleepResolution {
            case success(CheckedContinuation<Void, Error>)
            case cancellation(CheckedContinuation<Void, Error>)

            func resume() {
                switch self {
                case .success(let continuation):
                    continuation.resume()
                case .cancellation(let continuation):
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        private struct CountObserver {
            let target: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private let lock = NSLock()
        private var currentInstant = Instant(offset: .zero)
        private var sleepStates: [UUID: SleepState] = [:]
        private var waiterObservers: [UUID: CountObserver] = [:]
        private var cancellationObservers: [UUID: CountObserver] = [:]
        private var completedCancellationCount = 0
        private var completedCancelBeforeRegistrationCount = 0
        private var completedRegisterBeforeCancelCount = 0

        var now: Instant {
            lock.withLock { currentInstant }
        }

        var waiterCount: Int {
            lock.withLock { waiterCountLocked() }
        }

        var activeSleepCount: Int {
            lock.withLock { sleepStates.count }
        }

        var cancellationCompletionCount: Int {
            lock.withLock { completedCancellationCount }
        }

        var cancelBeforeRegistrationCompletionCount: Int {
            lock.withLock { completedCancelBeforeRegistrationCount }
        }

        var registerBeforeCancelCompletionCount: Int {
            lock.withLock { completedRegisterBeforeCancelCount }
        }

        func prepare(id: UUID) {
            lock.withLock {
                precondition(sleepStates[id] == nil, "manual clock sleep ID was reused")
                sleepStates[id] = .prepared
            }
        }

        func register(
            id: UUID,
            deadline: Instant,
            continuation: CheckedContinuation<Void, Error>
        ) {
            let result: (
                SleepResolution?,
                [CheckedContinuation<Void, Never>],
                [CheckedContinuation<Void, Never>]
            ) = lock.withLock {
                let resolution: SleepResolution?
                switch sleepStates[id] {
                case .prepared:
                    if deadline <= currentInstant {
                        sleepStates[id] = .completed(.success)
                        resolution = .success(continuation)
                    } else {
                        sleepStates[id] = .waiting(deadline: deadline, continuation: continuation)
                        resolution = nil
                    }
                case .cancelledBeforeRegistration:
                    sleepStates[id] = .completed(.cancellation(.cancelBeforeRegistration))
                    resolution = .cancellation(continuation)
                case .waiting, .completed, .none:
                    preconditionFailure("manual clock sleep registered from an invalid state")
                }
                return (
                    resolution,
                    takeSatisfiedWaiterObserversLocked(),
                    takeSatisfiedCancellationObserversLocked()
                )
            }

            result.0?.resume()
            result.1.forEach { $0.resume() }
            result.2.forEach { $0.resume() }
        }

        func cancel(id: UUID) {
            let result: (
                SleepResolution?,
                [CheckedContinuation<Void, Never>],
                [CheckedContinuation<Void, Never>]
            ) = lock.withLock {
                let resolution: SleepResolution?
                switch sleepStates[id] {
                case .prepared:
                    sleepStates[id] = .cancelledBeforeRegistration
                    resolution = nil
                case .waiting(_, let continuation):
                    sleepStates[id] = .completed(.cancellation(.registerBeforeCancel))
                    resolution = .cancellation(continuation)
                case .cancelledBeforeRegistration, .completed, .none:
                    resolution = nil
                }
                return (
                    resolution,
                    takeSatisfiedWaiterObserversLocked(),
                    takeSatisfiedCancellationObserversLocked()
                )
            }

            result.0?.resume()
            result.1.forEach { $0.resume() }
            result.2.forEach { $0.resume() }
        }

        func advance(by duration: Duration) {
            precondition(duration >= .zero, "manual clock cannot move backwards")
            let result: (
                [SleepResolution],
                [CheckedContinuation<Void, Never>],
                [CheckedContinuation<Void, Never>]
            ) = lock.withLock {
                currentInstant = currentInstant.advanced(by: duration)
                let dueIDs = sleepStates.compactMap { id, state -> UUID? in
                    guard case .waiting(let deadline, _) = state,
                          deadline <= currentInstant else {
                        return nil
                    }
                    return id
                }
                let resolutions = dueIDs.compactMap { id -> SleepResolution? in
                    guard case .waiting(_, let continuation) = sleepStates[id] else {
                        return nil
                    }
                    sleepStates[id] = .completed(.success)
                    return .success(continuation)
                }
                return (
                    resolutions,
                    takeSatisfiedWaiterObserversLocked(),
                    takeSatisfiedCancellationObserversLocked()
                )
            }

            result.0.forEach { $0.resume() }
            result.1.forEach { $0.resume() }
            result.2.forEach { $0.resume() }
        }

        func finish(id: UUID) {
            let observers: (
                [CheckedContinuation<Void, Never>],
                [CheckedContinuation<Void, Never>]
            ) = lock.withLock {
                guard let state = sleepStates.removeValue(forKey: id) else {
                    preconditionFailure("manual clock sleep finished without state")
                }
                switch state {
                case .completed(.success):
                    break
                case .completed(.cancellation(let order)):
                    completedCancellationCount += 1
                    switch order {
                    case .cancelBeforeRegistration:
                        completedCancelBeforeRegistrationCount += 1
                    case .registerBeforeCancel:
                        completedRegisterBeforeCancelCount += 1
                    }
                case .prepared, .waiting, .cancelledBeforeRegistration:
                    preconditionFailure("manual clock sleep finished before resolution")
                }
                return (
                    takeSatisfiedWaiterObserversLocked(),
                    takeSatisfiedCancellationObserversLocked()
                )
            }
            observers.0.forEach { $0.resume() }
            observers.1.forEach { $0.resume() }
        }

        func waitForWaiterCount(_ exactCount: Int) async {
            precondition(exactCount >= 0)
            await withCheckedContinuation { continuation in
                let shouldResume = lock.withLock {
                    if waiterCountLocked() == exactCount {
                        return true
                    }
                    waiterObservers[UUID()] = CountObserver(
                        target: exactCount,
                        continuation: continuation
                    )
                    return false
                }
                if shouldResume {
                    continuation.resume()
                }
            }
        }

        func waitForCancellationCompletionCount(_ minimumCount: Int) async {
            precondition(minimumCount >= 0)
            await withCheckedContinuation { continuation in
                let shouldResume = lock.withLock {
                    if completedCancellationCount >= minimumCount {
                        return true
                    }
                    cancellationObservers[UUID()] = CountObserver(
                        target: minimumCount,
                        continuation: continuation
                    )
                    return false
                }
                if shouldResume {
                    continuation.resume()
                }
            }
        }

        private func waiterCountLocked() -> Int {
            sleepStates.values.reduce(into: 0) { count, state in
                if case .waiting = state {
                    count += 1
                }
            }
        }

        private func takeSatisfiedWaiterObserversLocked() -> [CheckedContinuation<Void, Never>] {
            let count = waiterCountLocked()
            let ids = waiterObservers.compactMap { id, observer in
                observer.target == count ? id : nil
            }
            return ids.compactMap { waiterObservers.removeValue(forKey: $0)?.continuation }
        }

        private func takeSatisfiedCancellationObserversLocked() -> [CheckedContinuation<Void, Never>] {
            let ids = cancellationObservers.compactMap { id, observer in
                observer.target <= completedCancellationCount ? id : nil
            }
            return ids.compactMap { cancellationObservers.removeValue(forKey: $0)?.continuation }
        }
    }
}

private enum ControlledIdleProviderError: Error {
    case missingCall(Int)
}

private actor ControlledIdleProvider: LLMProvider {
    private struct OpenStream {
        let id: UUID
        let continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    }

    private struct CallObserver {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var nextCall = 0
    private var streams: [Int: OpenStream] = [:]
    private var callByID: [UUID: Int] = [:]
    private var openedIDs: Set<UUID> = []
    private var terminatedBeforeOpen: Set<UUID> = []
    private var callObservers: [UUID: CallObserver] = [:]

    private(set) var callCount = 0

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        let id = UUID()
        return AsyncThrowingStream { continuation in
            continuation.onTermination = { _ in
                Task { await self.terminate(id: id) }
            }
            Task { await self.open(id: id, continuation: continuation) }
        }
    }

    func waitForCall(_ ordinal: Int) async {
        precondition(ordinal > 0)
        if callCount >= ordinal {
            return
        }
        await withCheckedContinuation { continuation in
            callObservers[UUID()] = CallObserver(target: ordinal, continuation: continuation)
        }
    }

    func send(_ event: ProviderEvent, to ordinal: Int) throws {
        guard let stream = streams[ordinal] else {
            throw ControlledIdleProviderError.missingCall(ordinal)
        }
        stream.continuation.yield(event)
    }

    func finish(_ ordinal: Int) throws {
        guard let stream = streams.removeValue(forKey: ordinal) else {
            throw ControlledIdleProviderError.missingCall(ordinal)
        }
        callByID.removeValue(forKey: stream.id)
        stream.continuation.finish()
    }

    private func open(
        id: UUID,
        continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    ) {
        openedIDs.insert(id)
        if terminatedBeforeOpen.remove(id) != nil {
            return
        }

        nextCall += 1
        callCount = nextCall
        streams[nextCall] = OpenStream(id: id, continuation: continuation)
        callByID[id] = nextCall

        let observerIDs = callObservers.compactMap { observerID, observer in
            observer.target <= callCount ? observerID : nil
        }
        let continuations = observerIDs.compactMap {
            callObservers.removeValue(forKey: $0)?.continuation
        }
        continuations.forEach { $0.resume() }
    }

    private func terminate(id: UUID) {
        if let ordinal = callByID.removeValue(forKey: id) {
            streams.removeValue(forKey: ordinal)
        } else if !openedIDs.contains(id) {
            terminatedBeforeOpen.insert(id)
        }
    }
}

private actor AgentEventProbe {
    private struct TextObserver {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var textDeltaCount = 0
    private var observers: [UUID: TextObserver] = [:]

    func record(_ event: AgentEvent) {
        guard case .textDelta = event else { return }
        textDeltaCount += 1
        let observerIDs = observers.compactMap { id, observer in
            observer.target <= textDeltaCount ? id : nil
        }
        let continuations = observerIDs.compactMap {
            observers.removeValue(forKey: $0)?.continuation
        }
        continuations.forEach { $0.resume() }
    }

    func waitForTextDeltaCount(_ target: Int) async {
        precondition(target > 0)
        if textDeltaCount >= target {
            return
        }
        await withCheckedContinuation { continuation in
            observers[UUID()] = TextObserver(target: target, continuation: continuation)
        }
    }
}

private actor OneShotGate {
    private var isOpen = false
    private var blockedWaiter: CheckedContinuation<Void, Never>?
    private var blockedObservers: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            precondition(blockedWaiter == nil, "one-shot gate only supports one waiter")
            blockedWaiter = continuation
            let observers = blockedObservers
            blockedObservers.removeAll()
            observers.forEach { $0.resume() }
        }
    }

    func waitUntilBlocked() async {
        if blockedWaiter != nil {
            return
        }
        await withCheckedContinuation { continuation in
            blockedObservers.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let waiter = blockedWaiter
        blockedWaiter = nil
        waiter?.resume()
    }
}
#endif

private func runLoop(
    provider: any LLMProvider,
    handlers: [String: any ToolHandler],
    maxTurns: Int = 10,
    tokenBudget: Int = Int.max,
    retryDelays: [Duration] = [.seconds(2), .seconds(4)],
    turnTimeout: Duration = KernelDefaults.turnTimeout
) async throws -> (outcome: LoopOutcome, events: [AgentEvent]) {
    let loop = AgentLoop(
        provider: provider,
        executor: ToolExecutor(handlers: handlers),
        packet: ContextPacket(
            companionName: "T",
            rolePrompt: "r",
            cardTitle: "t",
            cardDescription: "d",
            expectedOutput: "e",
            workspacePath: nil,
            upstreamHandoffs: []
        ),
        tools: ToolDef.agentTools,
        maxTurns: maxTurns,
        tokenBudget: tokenBudget,
        maxTokensPerTurn: 4096,
        retryDelays: retryDelays,
        turnTimeout: turnTimeout
    )
    var events: [AgentEvent] = []
    var final: LoopOutcome?
    for try await event in loop.run() {
        events.append(event)
        if case .finished(let outcome) = event {
            final = outcome
        }
    }
    return (try #require(final), events)
}

#if DEBUG
private func startControlledLoop<C: Clock>(
    provider: ControlledIdleProvider,
    handlers: [String: any ToolHandler],
    clock: C,
    maxTurns: Int = 10,
    tokenBudget: Int = Int.max,
    retryDelays: [Duration] = [.seconds(2), .seconds(4)],
    turnTimeout: Duration
) -> (
    task: Task<(outcome: LoopOutcome, events: [AgentEvent]), Error>,
    probe: AgentEventProbe
) where C.Duration == Duration {
    let loop = AgentLoop(
        provider: provider,
        executor: ToolExecutor(handlers: handlers),
        packet: ContextPacket(
            companionName: "T",
            rolePrompt: "r",
            cardTitle: "t",
            cardDescription: "d",
            expectedOutput: "e",
            workspacePath: nil,
            upstreamHandoffs: []
        ),
        tools: ToolDef.agentTools,
        maxTurns: maxTurns,
        tokenBudget: tokenBudget,
        maxTokensPerTurn: 4096,
        retryDelays: retryDelays,
        turnTimeout: turnTimeout,
        idleClockForTesting: clock
    )
    let probe = AgentEventProbe()
    let task = Task<(outcome: LoopOutcome, events: [AgentEvent]), Error> {
        var events: [AgentEvent] = []
        var final: LoopOutcome?
        for try await event in loop.run() {
            await probe.record(event)
            events.append(event)
            if case .finished(let outcome) = event {
                final = outcome
            }
        }
        try Task.checkCancellation()
        guard let final else {
            throw ProviderError.malformedStream("controlled loop ended without an outcome")
        }
        return (final, events)
    }
    return (task, probe)
}
#endif

private func runLoop(
    script: [TurnResult],
    handlers: [String: any ToolHandler],
    maxTurns: Int = 10,
    tokenBudget: Int = Int.max,
    retryDelays: [Duration] = [.seconds(2), .seconds(4)],
    turnTimeout: Duration = KernelDefaults.turnTimeout
) async throws -> (outcome: LoopOutcome, events: [AgentEvent], mock: MockProvider) {
    let mock = MockProvider(script: script)
    let result = try await runLoop(
        provider: mock,
        handlers: handlers,
        maxTurns: maxTurns,
        tokenBudget: tokenBudget,
        retryDelays: retryDelays,
        turnTimeout: turnTimeout
    )
    return (result.outcome, result.events, mock)
}

private let doneHandoff: JSONValue = [
    "outcome": "done",
    "summary": "s",
    "noArtifactReason": "纯文本任务",
    "artifacts": [],
    "verification": [],
    "risks": [],
]

@Test func happyPathToolThenComplete() async throws {
    let handoff = try HandoffPayload.parse(from: doneHandoff).get()
    let write = StubHandler([.result("已写入")])
    let complete = StubHandler([.completed(handoff)])
    let result = try await runLoop(
        script: [
            TurnResult(
                content: [
                    .text("开工"),
                    .toolUse(id: "t1", name: "write_file", input: ["path": "a.md", "content": "x"]),
                ],
                stopReason: .toolUse
            ),
            TurnResult(
                content: [.toolUse(id: "t2", name: "complete_card", input: doneHandoff)],
                stopReason: .toolUse
            ),
        ],
        handlers: ["write_file": write, "complete_card": complete]
    )
    guard case .completed = result.outcome else {
        Issue.record("expected completed")
        return
    }
    #expect(write.calls.count == 1 && complete.calls.count == 1)
    let secondHistory = await result.mock.recordedHistories[1]
    #expect(secondHistory.count == 3)
    #expect(secondHistory[1].role == .assistant)
    #expect(secondHistory[2].role == .user)
    guard case .toolResult(let id, _, let isError) = secondHistory[2].content[0] else { return }
    #expect(id == "t1" && isError == false)
}

@Test func endTurnWithoutTerminatorRemindsOnceThenBlocks() async throws {
    let result = try await runLoop(
        script: [
            TurnResult(content: [.text("我做完了！")], stopReason: .endTurn),
            TurnResult(content: [.text("真的做完了")], stopReason: .endTurn),
        ],
        handlers: [:]
    )
    guard case .blocked(let reason, _) = result.outcome else {
        Issue.record("expected blocked")
        return
    }
    #expect(reason == "no_terminator")
    let second = await result.mock.recordedHistories[1]
    guard case .text(let reminder) = second.last?.content.first else { return }
    #expect(reminder.contains("complete_card"))
}

@Test func toolErrorSelfHealsButThreeStrikesBlocks() async throws {
    let failing = StubHandler([.error("坏了1"), .error("坏了2"), .error("坏了3")])
    let makeTurn = {
        TurnResult(
            content: [.toolUse(id: UUID().uuidString, name: "read_file", input: ["path": "x"])],
            stopReason: .toolUse
        )
    }
    let result = try await runLoop(
        script: [makeTurn(), makeTurn(), makeTurn(), makeTurn()],
        handlers: ["read_file": failing]
    )
    guard case .blocked(let reason, let detail) = result.outcome else {
        Issue.record("expected blocked")
        return
    }
    #expect(reason == "tool_failure")
    #expect(detail.contains("read_file"))
    #expect(failing.calls.count == 3)
    let third = await result.mock.recordedHistories[2]
    guard case .toolResult(_, _, let isError) = third.last?.content.first else { return }
    #expect(isError == true)
}

@Test func maxTurnsExhaustionBlocks() async throws {
    let note = StubHandler(Array(repeating: ToolOutcome.result("ok"), count: 5))
    let makeTurn = {
        TurnResult(
            content: [.toolUse(id: UUID().uuidString, name: "add_progress_note", input: ["text": "..."])],
            stopReason: .toolUse
        )
    }
    let result = try await runLoop(
        script: (0..<5).map { _ in makeTurn() },
        handlers: ["add_progress_note": note],
        maxTurns: 3
    )
    guard case .blocked(let reason, _) = result.outcome else { return }
    #expect(reason == "budget_exhausted")
}

@Test func tokenBudgetExhaustionBlocks() async throws {
    let note = StubHandler(Array(repeating: ToolOutcome.result("ok"), count: 10))
    let makeTurn = {
        TurnResult(
            content: [.toolUse(id: UUID().uuidString, name: "add_progress_note", input: ["text": "..."])],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 8, outputTokens: 9)
        )
    }
    let result = try await runLoop(
        script: (0..<10).map { _ in makeTurn() },
        handlers: ["add_progress_note": note],
        maxTurns: 10,
        tokenBudget: 25
    )
    guard case .blocked(let reason, let detail) = result.outcome else { return }
    #expect(reason == "budget_exhausted")
    #expect(detail.contains("已用"))
    #expect(await result.mock.callCount < 10)
}

@Test func refusalBlocksImmediately() async throws {
    let result = try await runLoop(
        script: [TurnResult(content: [], stopReason: .refusal)],
        handlers: [:]
    )
    guard case .blocked(let reason, _) = result.outcome else { return }
    #expect(reason == "refusal")
    #expect(await result.mock.callCount == 1)
}

@Test func toolUseStopWithZeroBlocksThrowsMalformed() async throws {
    // stopReason == .toolUse but no tool_use content blocks → must throw malformedStream
    // on the FIRST turn without making a second provider call.
    // (sending an empty tool_results user message would result in an API 400)
    let mock = MockProvider(script: [
        TurnResult(content: [.text("oops")], stopReason: .toolUse),
        // Second entry should never be reached
        TurnResult(content: [.text("unreachable")], stopReason: .endTurn),
    ])
    let loop = AgentLoop(
        provider: mock,
        executor: ToolExecutor(handlers: [:]),
        packet: ContextPacket(
            companionName: "T", rolePrompt: "r", cardTitle: "t",
            cardDescription: "d", expectedOutput: "e",
            workspacePath: nil, upstreamHandoffs: []
        ),
        tools: ToolDef.agentTools,
        maxTurns: 10,
        tokenBudget: Int.max,
        maxTokensPerTurn: 4096
    )
    var threw = false
    do {
        for try await _ in loop.run() {}
    } catch let err as ProviderError {
        if case .malformedStream = err { threw = true }
    } catch {}
    #expect(threw, "expected malformedStream when toolUse stop has zero tool_use blocks")
    // Must throw without making the second provider call
    #expect(await mock.callCount == 1, "should not call provider again after detecting empty toolUse")
}

@Test func pauseTurnCappedAtFiveContinuations() async throws {
    // Spec: max 5 continuations after the initial call.
    // Script: 7 consecutive pause_turn responses.
    // Expected: blocked(no_terminator) after 6 provider calls (initial + 5 continuations).
    let script: [TurnResult] = (0..<7).map { _ in
        TurnResult(content: [.text("…")], stopReason: .pauseTurn)
    }
    let result = try await runLoop(script: script, handlers: [:], maxTurns: 20)
    guard case .blocked(let reason, _) = result.outcome else {
        Issue.record("expected blocked, got \(result.outcome)")
        return
    }
    #expect(reason == "no_terminator")
    // Initial call + 5 continuations = 6; the 6th pause_turn response triggers block
    // without another provider call.
    #expect(await result.mock.callCount == 6)
}

@Test func multiToolUseOrderPreservedInHistory() async throws {
    // One turn with TWO tool_use blocks — both must execute in content order
    // and the single user reply must contain both tool_results with matching ids, in order.
    let write = StubHandler([.result("written")])
    let note = StubHandler([.result("noted")])
    let result = try await runLoop(
        script: [
            TurnResult(
                content: [
                    .toolUse(id: "t1", name: "write_file", input: ["path": "a.md", "content": "x"]),
                    .toolUse(id: "t2", name: "add_progress_note", input: ["text": "note"]),
                ],
                stopReason: .toolUse
            ),
            TurnResult(
                content: [.toolUse(id: "t3", name: "complete_card", input: doneHandoff)],
                stopReason: .toolUse
            ),
        ],
        handlers: [
            "write_file": write,
            "add_progress_note": note,
            "complete_card": StubHandler([.completed(try HandoffPayload.parse(from: doneHandoff).get())]),
        ]
    )
    guard case .completed = result.outcome else {
        Issue.record("expected completed")
        return
    }
    // Both tools called in order
    #expect(write.calls.count == 1)
    #expect(note.calls.count == 1)

    // Second call's history: [userMsg, assistantMsg(2 tools), userMsg(2 tool_results)]
    let secondHistory = await result.mock.recordedHistories[1]
    #expect(secondHistory.count == 3)
    let toolResultsMsg = secondHistory[2]
    #expect(toolResultsMsg.role == .user)
    #expect(toolResultsMsg.content.count == 2)
    guard case .toolResult(let id0, _, _) = toolResultsMsg.content[0],
          case .toolResult(let id1, _, _) = toolResultsMsg.content[1] else {
        Issue.record("expected toolResult blocks")
        return
    }
    #expect(id0 == "t1")
    #expect(id1 == "t2")
}

@Test func unknownBlocksPreservedInHistory() async throws {
    let thinking = ContentBlock.unknown(["type": "thinking", "thinking": "hmm", "signature": "sig"])
    let result = try await runLoop(
        script: [
            TurnResult(
                content: [thinking, .toolUse(id: "t", name: "add_progress_note", input: ["text": "x"])],
                stopReason: .toolUse
            ),
            TurnResult(content: [.text("done")], stopReason: .endTurn),
            TurnResult(content: [.text("done")], stopReason: .endTurn),
        ],
        handlers: ["add_progress_note": StubHandler([.result("ok")])]
    )
    let second = await result.mock.recordedHistories[1]
    #expect(second[1].content.first == thinking)
}

@Test func turnRetriesTransientErrorThenCompletes() async throws {
    let handoff = try HandoffPayload.parse(from: doneHandoff).get()
    let provider = FlakyProvider(
        failures: [.url(.networkConnectionLost)],
        script: [
            TurnResult(
                content: [.toolUse(id: "t1", name: "complete_card", input: doneHandoff)],
                stopReason: .toolUse
            ),
        ]
    )
    let result = try await runLoop(
        provider: provider,
        handlers: ["complete_card": StubHandler([.completed(handoff)])],
        retryDelays: [.milliseconds(1), .milliseconds(1)]
    )

    guard case .completed = result.outcome else {
        Issue.record("expected completed")
        return
    }
    let retryEvents = retryAttempts(in: result.events)
    #expect(retryEvents == [1])
    #expect(await provider.callCount == 2)
}

@Test func appTransportSecurityErrorDoesNotRetry() async throws {
    let provider = FlakyProvider(
        failures: [.url(.appTransportSecurityRequiresSecureConnection)],
        script: []
    )

    await #expect(throws: URLError.self) {
        _ = try await runLoop(
            provider: provider,
            handlers: [:],
            retryDelays: [.milliseconds(1), .milliseconds(1)]
        )
    }
    #expect(await provider.callCount == 1)
}

#if DEBUG
@Test func turnTimeoutRetriesOnceThenBlocks() async throws {
    let timeout = Duration.milliseconds(50)
    let clock = ManualAgentLoopClock()
    let provider = ControlledIdleProvider()
    let run = startControlledLoop(
        provider: provider,
        handlers: [:],
        clock: clock,
        turnTimeout: timeout
    )

    await provider.waitForCall(1)
    await clock.waitForWaiterCount(1)
    clock.advance(by: timeout)
    await provider.waitForCall(2)
    await clock.waitForWaiterCount(1)
    clock.advance(by: timeout)

    let result = try await run.task.value

    guard case .blocked(let reason, let detail) = result.outcome else {
        Issue.record("expected blocked after repeated idle timeout")
        return
    }
    #expect(reason == "tool_failure")
    #expect(detail.contains("超时"))
    let retries = result.events.compactMap { event -> (Int, String)? in
        if case .turnRetrying(let attempt, let reason) = event {
            return (attempt, reason)
        }
        return nil
    }
    #expect(retries.count == 1)
    #expect(retries[0].0 == 1)
    #expect(retries[0].1 == "本轮超时")
    #expect(await provider.callCount == 2)
    #expect(clock.waiterCount == 0)
    #expect(clock.activeSleepCount == 0)
}

@Test func cancelWinsOverIdleTimeout() async throws {
    enum CancelOutcome: Equatable {
        case canceled
        case timedOut
        case finished
        case other
    }

    let cancelBeforeRegistrationClock = ManualAgentLoopClock()
    let cancelBeforeRegistrationGate = OneShotGate()
    let cancelBeforeRegistrationDeadline = cancelBeforeRegistrationClock.now.advanced(
        by: .milliseconds(50)
    )
    let cancelBeforeRegistrationTask = Task<Void, Error> {
        await cancelBeforeRegistrationGate.wait()
        try await cancelBeforeRegistrationClock.sleep(
            until: cancelBeforeRegistrationDeadline,
            tolerance: nil
        )
    }
    await cancelBeforeRegistrationGate.waitUntilBlocked()
    cancelBeforeRegistrationTask.cancel()
    await cancelBeforeRegistrationGate.open()
    await cancelBeforeRegistrationClock.waitForCancellationCompletionCount(1)
    await #expect(throws: CancellationError.self) {
        try await cancelBeforeRegistrationTask.value
    }
    #expect(cancelBeforeRegistrationClock.waiterCount == 0)
    #expect(cancelBeforeRegistrationClock.activeSleepCount == 0)
    #expect(cancelBeforeRegistrationClock.cancelBeforeRegistrationCompletionCount == 1)
    #expect(cancelBeforeRegistrationClock.registerBeforeCancelCompletionCount == 0)

    let timeout = Duration.milliseconds(50)
    let clock = ManualAgentLoopClock()
    let provider = ControlledIdleProvider()
    let run = startControlledLoop(
        provider: provider,
        handlers: [:],
        clock: clock,
        turnTimeout: timeout
    )

    await provider.waitForCall(1)
    await clock.waitForWaiterCount(1)
    let cancellationCountBeforeOuterCancel = clock.cancellationCompletionCount
    run.task.cancel()
    await clock.waitForCancellationCompletionCount(cancellationCountBeforeOuterCancel + 1)
    #expect(clock.waiterCount == 0)
    #expect(clock.activeSleepCount == 0)
    #expect(clock.cancelBeforeRegistrationCompletionCount == 0)
    #expect(clock.registerBeforeCancelCompletionCount == 1)
    clock.advance(by: timeout + .milliseconds(1))

    let outcome: CancelOutcome
    do {
        _ = try await run.task.value
        outcome = .finished
    } catch is CancellationError {
        outcome = .canceled
    } catch is TurnTimeoutError {
        outcome = .timedOut
    } catch {
        outcome = .other
    }
    #expect(outcome == .canceled)
    #expect(clock.waiterCount == 0)
    #expect(clock.activeSleepCount == 0)
}

@Test func timeoutThenSuccessDoesNotAccumulate() async throws {
    let handoff = try HandoffPayload.parse(from: doneHandoff).get()
    let timeout = Duration.milliseconds(60)
    let clock = ManualAgentLoopClock()
    let provider = ControlledIdleProvider()
    let run = startControlledLoop(
        provider: provider,
        handlers: [
            "add_progress_note": StubHandler([.result("ok")]),
            "complete_card": StubHandler([.completed(handoff)]),
        ],
        clock: clock,
        turnTimeout: timeout
    )

    await provider.waitForCall(1)
    await clock.waitForWaiterCount(1)
    clock.advance(by: timeout)

    await provider.waitForCall(2)
    await clock.waitForWaiterCount(1)
    try await provider.send(
        .turn(TurnResult(
            content: [.toolUse(id: "n1", name: "add_progress_note", input: ["text": "step"])],
            stopReason: .toolUse
        )),
        to: 2
    )
    try await provider.finish(2)

    await provider.waitForCall(3)
    await clock.waitForWaiterCount(1)
    clock.advance(by: timeout)

    await provider.waitForCall(4)
    await clock.waitForWaiterCount(1)
    try await provider.send(
        .turn(TurnResult(
            content: [.toolUse(id: "c1", name: "complete_card", input: doneHandoff)],
            stopReason: .toolUse
        )),
        to: 4
    )
    try await provider.finish(4)

    let result = try await run.task.value

    guard case .completed = result.outcome else {
        Issue.record("expected completed when each turn succeeds on retry")
        return
    }
    #expect(retryAttempts(in: result.events) == [1, 1])
    #expect(await provider.callCount == 4)
    #expect(clock.waiterCount == 0)
    #expect(clock.activeSleepCount == 0)
}

@Test func slowActiveStreamDoesNotIdleTimeout() async throws {
    let handoff = try HandoffPayload.parse(from: doneHandoff).get()
    let finalTurn = TurnResult(
        content: [.text("done"), .toolUse(id: "c1", name: "complete_card", input: doneHandoff)],
        stopReason: .toolUse
    )
    let timeout = Duration.seconds(1)
    let segment = Duration.milliseconds(50)
    let clock = ManualAgentLoopClock()
    let start = clock.now
    let provider = ControlledIdleProvider()
    let run = startControlledLoop(
        provider: provider,
        handlers: ["complete_card": StubHandler([.completed(handoff)])],
        clock: clock,
        turnTimeout: timeout
    )

    await provider.waitForCall(1)
    await clock.waitForWaiterCount(1)

    for index in 0..<24 {
        try await provider.send(.textDelta("\(index)"), to: 1)
        await run.probe.waitForTextDeltaCount(index + 1)
        clock.advance(by: segment)
        await clock.waitForWaiterCount(1)
    }

    try await provider.send(.turn(finalTurn), to: 1)
    try await provider.finish(1)
    let result = try await run.task.value

    guard case .completed = result.outcome else {
        Issue.record("expected active stream to complete")
        return
    }
    let elapsed = start.duration(to: clock.now)
    #expect(elapsed > timeout)
    #expect(segment < timeout)
    #expect(retryAttempts(in: result.events).isEmpty)
    #expect(await provider.callCount == 1)
    #expect(clock.waiterCount == 0)
    #expect(clock.activeSleepCount == 0)
}

@Test func turnCompletesUnderTimeout() async throws {
    let handoff = try HandoffPayload.parse(from: doneHandoff).get()
    let clock = ManualAgentLoopClock()
    let start = clock.now
    let provider = ControlledIdleProvider()
    let run = startControlledLoop(
        provider: provider,
        handlers: ["complete_card": StubHandler([.completed(handoff)])],
        clock: clock,
        turnTimeout: .seconds(1)
    )

    await provider.waitForCall(1)
    await clock.waitForWaiterCount(1)
    try await provider.send(
        .turn(TurnResult(
            content: [.text("done"), .toolUse(id: "c1", name: "complete_card", input: doneHandoff)],
            stopReason: .toolUse
        )),
        to: 1
    )
    try await provider.finish(1)

    let result = try await run.task.value
    guard case .completed = result.outcome else {
        Issue.record("expected completed")
        return
    }
    #expect(clock.now == start)
    #expect(retryAttempts(in: result.events).isEmpty)
    #expect(await provider.callCount == 1)
    #expect(clock.waiterCount == 0)
    #expect(clock.activeSleepCount == 0)
}
#endif

@Test func turnRetryExhaustionSurfacesLastError() async throws {
    let provider = FlakyProvider(
        failures: [.url(.networkConnectionLost), .url(.networkConnectionLost), .url(.networkConnectionLost)],
        script: []
    )
    let loop = AgentLoop(
        provider: provider,
        executor: ToolExecutor(handlers: [:]),
        packet: ContextPacket(
            companionName: "T",
            rolePrompt: "r",
            cardTitle: "t",
            cardDescription: "d",
            expectedOutput: "e",
            workspacePath: nil,
            upstreamHandoffs: []
        ),
        tools: ToolDef.agentTools,
        maxTurns: 10,
        tokenBudget: Int.max,
        maxTokensPerTurn: 4096,
        retryDelays: [.milliseconds(1), .milliseconds(1)]
    )
    var events: [AgentEvent] = []
    var caughtNetworkLost = false
    do {
        for try await event in loop.run() {
            events.append(event)
        }
    } catch let error as URLError {
        caughtNetworkLost = error.code == .networkConnectionLost
    } catch {
        Issue.record("expected URLError, got \(error)")
    }

    #expect(caughtNetworkLost)
    #expect(retryAttempts(in: events) == [1, 2])
    #expect(await provider.callCount == 3)
}

@Test func unauthorizedNotRetried() async throws {
    let provider = FlakyProvider(failures: [.provider(.unauthorized)], script: [])
    let loop = AgentLoop(
        provider: provider,
        executor: ToolExecutor(handlers: [:]),
        packet: ContextPacket(
            companionName: "T",
            rolePrompt: "r",
            cardTitle: "t",
            cardDescription: "d",
            expectedOutput: "e",
            workspacePath: nil,
            upstreamHandoffs: []
        ),
        tools: ToolDef.agentTools,
        maxTurns: 10,
        tokenBudget: Int.max,
        maxTokensPerTurn: 4096
    )
    var events: [AgentEvent] = []
    var caughtUnauthorized = false
    do {
        for try await event in loop.run() {
            events.append(event)
        }
    } catch let error as ProviderError {
        caughtUnauthorized = error == .unauthorized
    } catch {
        Issue.record("expected ProviderError.unauthorized, got \(error)")
    }

    #expect(caughtUnauthorized)
    #expect(retryAttempts(in: events).isEmpty)
    #expect(await provider.callCount == 1)
}

@Test func turnStartedPrecedesEachTurn() async throws {
    let write = StubHandler([.result("已写入")])
    let complete = StubHandler([.completed(try HandoffPayload.parse(from: doneHandoff).get())])
    let result = try await runLoop(
        script: [
            TurnResult(
                content: [
                    .text("第一轮"),
                    .toolUse(id: "t1", name: "write_file", input: ["path": "a.md", "content": "x"]),
                ],
                stopReason: .toolUse
            ),
            TurnResult(
                content: [
                    .text("第二轮"),
                    .toolUse(id: "t2", name: "complete_card", input: doneHandoff),
                ],
                stopReason: .toolUse
            ),
        ],
        handlers: ["write_file": write, "complete_card": complete]
    )

    let starts = result.events.indices.filter { index in
        if case .turnStarted = result.events[index] {
            return true
        }
        return false
    }
    let deltas = result.events.indices.filter { index in
        if case .textDelta = result.events[index] {
            return true
        }
        return false
    }

    let callCount = await result.mock.callCount
    #expect(starts.count == callCount)
    #expect(starts.count == 2)
    #expect(deltas.count == 2)
    #expect(starts[0] < deltas[0])
    #expect(starts[1] < deltas[1])
}

@Test func providerErrorDescriptionsAreHuman() {
    #expect(String(describing: ProviderError.unauthorized).contains("401"))
    #expect(String(describing: ProviderError.http(status: 503, body: "gateway unavailable")).contains("503"))
    #expect(String(describing: ProviderError.overloadedRetriesExhausted).contains("过载"))
    #expect(String(describing: ProviderError.apiError(type: "api_error", message: "bad")).contains("api_error"))
    #expect(String(describing: ProviderError.malformedStream("lost")).contains("响应流异常中断"))
}

private func retryAttempts(in events: [AgentEvent]) -> [Int] {
    events.compactMap { event in
        if case .turnRetrying(let attempt, _) = event {
            return attempt
        }
        return nil
    }
}
