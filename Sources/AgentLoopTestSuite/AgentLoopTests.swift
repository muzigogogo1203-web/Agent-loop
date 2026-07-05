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

private func runLoop(
    script: [TurnResult],
    handlers: [String: any ToolHandler],
    maxTurns: Int = 10
) async throws -> (outcome: LoopOutcome, events: [AgentEvent], mock: MockProvider) {
    let mock = MockProvider(script: script)
    let loop = AgentLoop(
        provider: mock,
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
        maxTokensPerTurn: 4096
    )
    var events: [AgentEvent] = []
    var final: LoopOutcome?
    for try await event in loop.run() {
        events.append(event)
        if case .finished(let outcome) = event {
            final = outcome
        }
    }
    return (try #require(final), events, mock)
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
