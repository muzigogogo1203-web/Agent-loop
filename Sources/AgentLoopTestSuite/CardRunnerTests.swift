import Testing
import Foundation
import AgentLoopCore

@Test func runnerDrivesCardToDoneWithRunRecord() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try "内容".write(to: workspace.appendingPathComponent("out.md"), atomically: true, encoding: .utf8)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "t",
        cardDescription: "d",
        expectedOutput: "e",
        assigneeId: nil,
        maxTurns: 10,
        workspacePath: workspace.path
    )

    let handoffInput: JSONValue = [
        "outcome": "ok",
        "summary": "s",
        "artifacts": [["relativePath": "out.md", "kind": "markdown", "label": "产出"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]],
        "risks": [],
    ]
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "t1", name: "complete_card", input: handoffInput)],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 100, outputTokens: 50)
        ),
    ])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("store"))
    var sawFinished = false
    for try await event in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {
        if case .finished(.completed) = event {
            sawFinished = true
        }
    }

    #expect(sawFinished)
    #expect(try db.card(id: ids.cardId)?.status == .done)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "completed")
    #expect(runs[0].tokensOut == 50)
    #expect(runs[0].endedAt != nil)
}

@Test func runnerBlocksCardWhenLoopBlocksItself() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "t",
        cardDescription: "d",
        expectedOutput: "e",
        assigneeId: nil,
        maxTurns: 10,
        workspacePath: workspace.path
    )
    let mock = MockProvider(script: [
        TurnResult(content: [.text("done?")], stopReason: .endTurn),
        TurnResult(content: [.text("still done")], stopReason: .endTurn),
    ])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("store"))
    var sawBlocked = false
    for try await event in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {
        if case .finished(.blocked) = event {
            sawBlocked = true
        }
    }

    #expect(sawBlocked)
    #expect(try db.card(id: ids.cardId)?.status == .blocked)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "blocked")
}
