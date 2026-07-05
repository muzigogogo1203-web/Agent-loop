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

private func runLoop(
    provider: any LLMProvider,
    handlers: [String: any ToolHandler],
    maxTurns: Int = 10,
    tokenBudget: Int = Int.max,
    retryDelays: [Duration] = [.seconds(2), .seconds(4)]
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
        tools: ToolDef.m1Tools,
        maxTurns: maxTurns,
        tokenBudget: tokenBudget,
        maxTokensPerTurn: 4096,
        retryDelays: retryDelays
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

private func runLoop(
    script: [TurnResult],
    handlers: [String: any ToolHandler],
    maxTurns: Int = 10,
    tokenBudget: Int = Int.max,
    retryDelays: [Duration] = [.seconds(2), .seconds(4)]
) async throws -> (outcome: LoopOutcome, events: [AgentEvent], mock: MockProvider) {
    let mock = MockProvider(script: script)
    let result = try await runLoop(
        provider: mock,
        handlers: handlers,
        maxTurns: maxTurns,
        tokenBudget: tokenBudget,
        retryDelays: retryDelays
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
        tools: ToolDef.m1Tools,
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
        tools: ToolDef.m1Tools,
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
        tools: ToolDef.m1Tools,
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
