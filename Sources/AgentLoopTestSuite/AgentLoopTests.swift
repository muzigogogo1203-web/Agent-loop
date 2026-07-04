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
