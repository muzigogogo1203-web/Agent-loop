import Testing
import Foundation
import GRDB
import AgentLoopCore

// M7-D3/D4：审批门全链路——挂起 / 一次性令牌 / 拒绝改道

private struct GateHarness {
    let db: AppDatabase
    let workspace: URL
    let base: URL
    let cardId: String
    let missionId: String
}

private func makeHarness() throws -> GateHarness {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 10, workspacePath: workspace.path
    )
    return GateHarness(db: db, workspace: workspace, base: base,
                       cardId: ids.cardId, missionId: ids.missionId)
}

private let writeInput: JSONValue = ["path": "out.md", "content": "内容"]

private func writeTurn(id: String = UUID().uuidString) -> TurnResult {
    TurnResult(content: [.toolUse(id: id, name: "write_file", input: writeInput)], stopReason: .toolUse)
}

private func completeTurn() -> TurnResult {
    TurnResult(content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
        "outcome": "o", "summary": "s", "noArtifactReason": "无",
        "verification": [["method": "自查", "passed": true, "note": "ok"]],
        "risks": [],
    ])], stopReason: .toolUse)
}

private func runCard(
    _ h: GateHarness, script: [TurnResult], autonomy: MissionAutonomy
) async throws {
    let mock = MockProvider(script: script)
    let runner = CardRunner(db: h.db, provider: mock, artifactStoreRoot: h.base.appendingPathComponent("a"))
    for try await _ in try runner.run(
        cardId: h.cardId, companionName: "n", rolePrompt: "r", autonomy: autonomy) {}
}

private func pendingApproval(_ h: GateHarness) throws -> UserRequestRecord? {
    try h.db.pool.read { db in
        try UserRequestRecord
            .filter(Column("cardId") == h.cardId && Column("answerJson") == nil)
            .fetchOne(db)
    }
}

@Test func carefulAutonomySuspendsWriteFileForApproval() async throws {
    let h = try makeHarness()
    try await runCard(h, script: [writeTurn()], autonomy: .careful)

    // 卡片挂起 + approval 请求落库（含动作实体与哈希）
    #expect(try h.db.card(id: h.cardId)?.status == .blocked)
    let request = try #require(try pendingApproval(h))
    #expect(request.kind == .approval)
    let optionsJson = try #require(request.optionsJson)
    let payload = try #require(try? JSONValue.decoded(from: optionsJson))
    #expect(payload["tool"]?.stringValue == "write_file")
    #expect(payload["inputHash"]?.stringValue?.count == 64)
    // 文件未写入（动作被门挡下）
    #expect(!FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))

    // approval_requested 事件（kind 钉裸字符串）
    let events = try await h.db.pool.read { db in
        try EventRecord.filter(Column("cardId") == h.cardId).fetchAll(db)
    }
    #expect(events.contains { $0.kind == "approval_requested" })
}

@Test func approvedTokenAllowsExactlyOnce() async throws {
    let h = try makeHarness()
    try await runCard(h, script: [writeTurn()], autonomy: .careful)
    let request = try #require(try pendingApproval(h))

    try h.db.answerUserRequest(requestId: request.id, answerJson: #"{"decision":"approve"}"#)
    #expect(try h.db.card(id: h.cardId)?.status == .ready)

    // 重跑：第一次同参调用被令牌放行（文件落盘），第二次同参调用令牌已耗 → 再次挂起
    try await runCard(h, script: [writeTurn(), writeTurn()], autonomy: .careful)
    #expect(FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
    #expect(try h.db.card(id: h.cardId)?.status == .blocked)
    let resuspended = try pendingApproval(h)
    #expect(resuspended != nil)

    // approval_decided 事件已落
    let events = try await h.db.pool.read { db in
        try EventRecord.filter(Column("cardId") == h.cardId).fetchAll(db)
    }
    #expect(events.contains { $0.kind == "approval_decided" })
}

@Test func deniedActionRoutesToErrorAndCardContinues() async throws {
    let h = try makeHarness()
    try await runCard(h, script: [writeTurn()], autonomy: .careful)
    let request = try #require(try pendingApproval(h))

    try h.db.answerUserRequest(
        requestId: request.id, answerJson: #"{"decision":"deny","reason":"别写这个文件"}"#)

    // 重跑：同参调用吃到 is_error（含拒绝理由），模型改道 complete → 卡片完成
    try await runCard(h, script: [writeTurn(), completeTurn()], autonomy: .careful)
    #expect(try h.db.card(id: h.cardId)?.status == .done)
    #expect(!FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
}

@Test func standardAutonomyWritesWithoutApproval() async throws {
    let h = try makeHarness()
    try await runCard(h, script: [writeTurn(), completeTurn()], autonomy: .standard)
    #expect(try h.db.card(id: h.cardId)?.status == .done)
    #expect(FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
}

@Test func approvalHashIsKeyOrderInsensitiveAndInputSensitive() {
    let a = ApprovalToken.hash(tool: "write_file", input: ["path": "x", "content": "y"])
    let b = ApprovalToken.hash(tool: "write_file", input: ["content": "y", "path": "x"])
    let c = ApprovalToken.hash(tool: "write_file", input: ["path": "x", "content": "z"])
    #expect(a == b)
    #expect(a != c)
    #expect(ApprovalToken.hash(tool: "run_shell", input: ["path": "x", "content": "y"]) != a)
}
