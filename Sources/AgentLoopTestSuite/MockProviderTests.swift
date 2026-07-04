import Testing
import AgentLoopCore

@Test func mockReplaysScriptInOrder() async throws {
    let mock = MockProvider(script: [
        TurnResult(content: [.text("想一下")], stopReason: .endTurn),
        TurnResult(content: [.toolUse(id: "t1", name: "read_file", input: ["path": "a"])], stopReason: .toolUse),
    ])
    var turns: [TurnResult] = []
    for _ in 0..<2 {
        for try await ev in mock.streamTurn(system: "", history: [], tools: [], maxTokens: 1) {
            if case .turn(let t) = ev { turns.append(t) }
        }
    }
    #expect(turns.count == 2)
    #expect(turns[0].stopReason == .endTurn)
    #expect(turns[1].stopReason == .toolUse)
    #expect(await mock.callCount == 2)
}
