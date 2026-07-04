import Testing
import Foundation
import AgentLoopCore

private struct BoardFixture {
    let db: AppDatabase
    let ws: URL
    let store: URL
    let cardId: String
    let tools: BoardTools
}

private func makeBoardFixture() throws -> BoardFixture {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let ws = base.appendingPathComponent("ws")
    let store = base.appendingPathComponent("artifacts")
    try FileManager.default.createDirectory(at: ws, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c",
        squadName: "s",
        goal: "g",
        cardTitle: "t",
        cardDescription: "d",
        expectedOutput: "e",
        assigneeId: nil,
        maxTurns: 30,
        workspacePath: ws.path
    )
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    let tools = BoardTools(db: db, cardId: ids.cardId, runId: "run-1", workspaceRoot: ws, artifactStoreRoot: store)
    return BoardFixture(db: db, ws: ws, store: store, cardId: ids.cardId, tools: tools)
}

@Test func completeCopiesArtifactBeforeDone() async throws {
    let fixture = try makeBoardFixture()
    try "# 清单".write(to: fixture.ws.appendingPathComponent("清单.md"), atomically: true, encoding: .utf8)

    let output = await fixture.tools.complete(input: [
        "outcome": "完成",
        "summary": "已整理",
        "artifacts": [["relativePath": "清单.md", "kind": "markdown", "label": "装备清单"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]],
        "risks": [],
    ])

    guard case .completed = output else {
        Issue.record("should complete")
        return
    }
    let card = try fixture.db.card(id: fixture.cardId)
    #expect(card?.status == .done)
    let artifacts = try fixture.db.artifacts(cardId: fixture.cardId)
    #expect(artifacts.count == 1)
    #expect(FileManager.default.fileExists(atPath: artifacts[0].path))
    #expect(artifacts[0].path.hasPrefix(fixture.store.path))
    #expect(FileManager.default.fileExists(atPath: fixture.ws.appendingPathComponent("清单.md").path))
}

@Test func missingArtifactKeepsCardRunning() async throws {
    let fixture = try makeBoardFixture()
    let output = await fixture.tools.complete(input: [
        "outcome": "完成",
        "summary": "x",
        "artifacts": [["relativePath": "不存在.md", "kind": "md", "label": "l"]],
        "verification": [],
        "risks": [],
    ])
    guard case .error(let message) = output else {
        Issue.record("should error")
        return
    }
    #expect(message.contains("不存在.md"))
    #expect(try fixture.db.card(id: fixture.cardId)?.status == .running)
    #expect(try fixture.db.artifacts(cardId: fixture.cardId).isEmpty)
}

@Test func invalidHandoffKeepsCardRunning() async throws {
    let fixture = try makeBoardFixture()
    let output = await fixture.tools.complete(input: [
        "outcome": "",
        "summary": "",
        "artifacts": [],
        "verification": [],
        "risks": [],
    ])
    guard case .error = output else {
        Issue.record("should error")
        return
    }
    #expect(try fixture.db.card(id: fixture.cardId)?.status == .running)
}

@Test func blockRecordsTypedReason() async throws {
    let fixture = try makeBoardFixture()
    let output = await fixture.tools.block(input: ["reason": "needs_human_input", "detail": "缺预算数字"])
    guard case .blocked = output else { return }
    let card = try fixture.db.card(id: fixture.cardId)
    #expect(card?.status == .blocked)
    #expect(card?.blockedReasonJson?.contains("needs_human_input") == true)
}

@Test func progressNoteAppendsEvent() async throws {
    let fixture = try makeBoardFixture()
    _ = await fixture.tools.progressNote(input: ["text": "整理到第 8 件"])
    let events = try fixture.db.events(cardId: fixture.cardId)
    #expect(events.contains { $0.kind == "progress_note" && $0.payloadJson.contains("第 8 件") })
}
