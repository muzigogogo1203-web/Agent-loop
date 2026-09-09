import Testing
import Foundation
import GRDB
import AgentLoopCore
import AgentLoopApplication

// M7-D3/D4：审批门全链路——挂起 / 一次性令牌 / 拒绝改道

private struct GateHarness {
    let db: AppDatabase
    let workspace: URL
    let cardId: String
    let missionId: String
    let workflow: ExternalOperationWorkflowCoordinator
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
    return GateHarness(
        db: db,
        workspace: workspace,
        cardId: ids.cardId,
        missionId: ids.missionId,
        workflow: ExternalOperationWorkflowCoordinator(
            store: ApprovalGrantStore(database: db)
        )
    )
}

private let writeInput: JSONValue = ["path": "out.md", "content": "内容"]

private struct BlockedExternalToolHandler: ToolHandler {
    func execute(input: JSONValue) async -> ToolOutcome {
        .blocked(reason: "needs_human_input", detail: "blocked locally")
    }
}

private enum GateHarnessError: Error {
    case unexpectedTool(String)
}

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

private func runApprovalScript(
    _ h: GateHarness,
    script: [TurnResult],
    autonomy: MissionAutonomy,
    injectWorkflow: Bool = true
) async throws -> [EngineBoardTerminalIntentV1] {
    let runId = UUID().uuidString
    try h.db.startRun(cardId: h.cardId, runId: runId)
    let squad = try #require(try h.db.squad(forCard: h.cardId))
    let files = FileTools(workspaceRoot: h.workspace)
    let gatedWrite = ApprovalGateHandler(
        inner: FileToolHandler(tools: files, op: .write),
        toolName: "write_file",
        autonomy: autonomy,
        db: h.db,
        cardId: h.cardId,
        runId: runId,
        campId: squad.campId,
        workflow: injectWorkflow ? h.workflow : nil
    )
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let boardTools = BoardTools(
        boardTerminalSink: board,
        progressSink: progress
    )
    for turn in script {
        for use in turn.toolUses {
            let outcome: ToolOutcome
            switch use.name {
            case "write_file":
                outcome = await gatedWrite.execute(input: use.input)
            case "complete_card":
                outcome = try await boardTools.complete(input: use.input)
            default:
                throw GateHarnessError.unexpectedTool(use.name)
            }
            switch outcome {
            case .completed, .blocked:
                return await board.snapshot()
            case .result, .error:
                continue
            }
        }
    }
    return await board.snapshot()
}

private func gateRunCompleted(
    _ intents: [EngineBoardTerminalIntentV1]
) -> Bool {
    intents.count == 1 && intents.contains { intent in
        if case .completed = intent { return true }
        return false
    }
}

@discardableResult
private func answerApproval(
    _ h: GateHarness,
    requestId: String,
    answerJson: String
) throws -> ApprovalAnswerSnapshotV1 {
    try ApprovalGrantStore(database: h.db).answerApprovalRequest(
        requestId: requestId,
        answerJson: answerJson,
        deviceId: "00000000-0000-4000-8000-000000000001"
    )
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
    let boardIntents = try await runApprovalScript(
        h,
        script: [writeTurn()],
        autonomy: .careful
    )

    // 卡片挂起 + approval 请求落库（含动作实体与哈希）
    #expect(boardIntents.isEmpty)
    #expect(try h.db.card(id: h.cardId)?.status == .blocked)
    let requests = try await h.db.pool.read { db in
        try UserRequestRecord
            .filter(Column("cardId") == h.cardId)
            .fetchAll(db)
    }
    #expect(requests.count == 1)
    let request = try #require(requests.first)
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

@Test func approvedGrantExecutesOnceAndTerminalReplayUsesSanitizedAck() async throws {
    let h = try makeHarness()
    try await runApprovalScript(
        h,
        script: [writeTurn()],
        autonomy: .careful
    )
    let request = try #require(try pendingApproval(h))

    let approval = try answerApproval(
        h,
        requestId: request.id,
        answerJson: #"{"decision":"approve"}"#
    )
    #expect(approval.grant?.id == request.id)
    #expect(try h.db.card(id: h.cardId)?.status == .ready)

    // 首次调用执行真实写入；同一 Grant/输入的再次调用只回放净化后的持久化确认。
    let boardIntents = try await runApprovalScript(
        h,
        script: [writeTurn(), writeTurn(), completeTurn()],
        autonomy: .careful
    )
    #expect(FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
    #expect(try String(contentsOf: h.workspace.appendingPathComponent("out.md"), encoding: .utf8) == "内容")
    #expect(gateRunCompleted(boardIntents))
    #expect(try pendingApproval(h) == nil)
    let uses = try ApprovalGrantStore(database: h.db).uses(
        grantId: request.id
    )
    #expect(uses.count == 1)
    #expect(uses.first?.state == .succeeded)
    #expect(try ApprovalGrantStore(database: h.db).grant(id: request.id)?.usedCount == 1)
    #expect(try ApprovalGrantStore(database: h.db).grant(id: request.id)?.state == .exhausted)

    // approval_decided 事件已落
    let events = try await h.db.pool.read { db in
        try EventRecord.filter(Column("cardId") == h.cardId).fetchAll(db)
    }
    #expect(events.contains { $0.kind == "approval_decided" })
}

@Test func deniedActionRoutesToErrorAndCardContinues() async throws {
    let h = try makeHarness()
    try await runApprovalScript(
        h,
        script: [writeTurn()],
        autonomy: .careful
    )
    let request = try #require(try pendingApproval(h))

    _ = try answerApproval(
        h,
        requestId: request.id,
        answerJson: #"{"decision":"deny","reason":"别写这个文件"}"#
    )

    // 重跑：同参调用吃到 is_error（含拒绝理由），模型改道 complete → 卡片完成
    let boardIntents = try await runApprovalScript(
        h,
        script: [writeTurn(), completeTurn()],
        autonomy: .careful
    )
    #expect(gateRunCompleted(boardIntents))
    #expect(!FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
}

@Test func standardAutonomyStillRequiresExplicitGrant() async throws {
    let h = try makeHarness()
    try await runApprovalScript(
        h,
        script: [writeTurn()],
        autonomy: .standard
    )
    #expect(try h.db.card(id: h.cardId)?.status == .blocked)
    #expect(try pendingApproval(h) != nil)
    #expect(!FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
}

@Test func approvedGrantFailsClosedWhenWorkflowPortIsMissing() async throws {
    let h = try makeHarness()
    try await runApprovalScript(
        h,
        script: [writeTurn()],
        autonomy: .careful
    )
    let request = try #require(try pendingApproval(h))
    _ = try answerApproval(
        h,
        requestId: request.id,
        answerJson: #"{"decision":"approve"}"#
    )

    let boardIntents = try await runApprovalScript(
        h,
        script: [writeTurn(), completeTurn()],
        autonomy: .careful,
        injectWorkflow: false
    )

    #expect(gateRunCompleted(boardIntents))
    #expect(!FileManager.default.fileExists(atPath: h.workspace.appendingPathComponent("out.md").path))
    #expect(try ApprovalGrantStore(database: h.db).uses(grantId: request.id).isEmpty)
}

@Test func malformedApprovalOptionsAbortAnswerWithoutGrantOrResume() async throws {
    let h = try makeHarness()
    let requestId = UUID().uuidString
    let prompt = "malformed approval fixture"
    try await h.db.pool.write { db in
        try UserRequestRecord(
            id: requestId,
            cardId: h.cardId,
            kind: .approval,
            prompt: prompt,
            optionsJson: #"{"tool":"write_file""#,
            answerJson: nil,
            createdAt: Date(),
            answeredAt: nil
        ).insert(db)
    }
    let blockedPayload: JSONValue = [
        "detail": .string(prompt),
        "reason": "needs_human_input",
        "userRequestId": .string(requestId),
    ]
    try h.db.transitionCard(
        id: h.cardId,
        to: .blocked,
        eventKind: EventKind.userRequestCreated,
        payload: blockedPayload,
        blockedReasonJson: try blockedPayload.encodedString()
    )

    var failedVisibly = false
    do {
        _ = try answerApproval(
            h,
            requestId: requestId,
            answerJson: #"{"decision":"approve"}"#
        )
    } catch {
        failedVisibly = true
    }

    #expect(failedVisibly)
    #expect(try h.db.card(id: h.cardId)?.status == .blocked)
    #expect(try ApprovalGrantStore(database: h.db).grant(id: requestId) == nil)

    let answered = try makeHarness()
    try await runApprovalScript(
        answered,
        script: [writeTurn()],
        autonomy: .careful
    )
    let answeredRequest = try #require(try pendingApproval(answered))
    _ = try answerApproval(
        answered,
        requestId: answeredRequest.id,
        answerJson: #"{"decision":"approve"}"#
    )
    await #expect(throws: DatabaseError.self) {
        try await answered.db.pool.write { db in
            try db.execute(
                sql: "UPDATE user_request SET answerJson=? WHERE id=?",
                arguments: [
                    #"{"decision":"approve","extra":true}"#,
                    answeredRequest.id,
                ]
            )
        }
    }
    let retainedAnswer = try await answered.db.pool.read { db in
        try UserRequestRecord.fetchOne(db, key: answeredRequest.id)
    }
    #expect(retainedAnswer?.answerJson == #"{"decision":"approve"}"#)
    #expect(retainedAnswer?.lifecycleState == .answered)
}

@Test func approvalHashIsKeyOrderInsensitiveAndInputSensitive() throws {
    let a = try ApprovalToken.hash(input: ["path": "x", "content": "y"])
    let b = try ApprovalToken.hash(input: ["content": "y", "path": "x"])
    let c = try ApprovalToken.hash(input: ["path": "x", "content": "z"])
    #expect(a == b)
    #expect(a != c)
    #expect(try ApprovalToken.hash(input: ["path": "x", "content": "y"]) == a)
}

@Test func toolHandlerAdapterTreatsOnlyErrorAsFailedFinal() async throws {
    let adapter = try ToolHandlerExternalOperationAdapterV1(
        toolId: "mcp__blocked",
        inner: BlockedExternalToolHandler()
    )
    let result = try await adapter.execute(
        input: .object([:]),
        useId: "grant-use:v1:test:1",
        idempotencyKey: "grant-use:v1:test:1"
    )
    #expect(result.effect.result == .succeeded)
    let local = await adapter.takeLocalOutcome(
        useId: "grant-use:v1:test:1"
    )
    guard case .blocked(let reason, let detail) = local else {
        Issue.record("original blocked outcome was not retained locally")
        return
    }
    #expect(reason == "needs_human_input")
    #expect(detail == "blocked locally")
}
