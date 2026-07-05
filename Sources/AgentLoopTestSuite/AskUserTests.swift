import Testing
import Foundation
import AgentLoopCore

private func askTempRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func askTempDB(root: URL) throws -> AppDatabase {
    try AppDatabase(path: root.appendingPathComponent("test.sqlite").path)
}

private func askCompanions(_ db: AppDatabase, count: Int = 2) throws -> [CompanionRecord] {
    let camp = try db.ensureDefaultCamp()
    let names = ["甲", "乙", "丙"]
    var companions: [CompanionRecord] = []
    for index in 0..<count {
        let companion = CompanionRecord.new(
            name: names[index],
            color: "blue",
            rolePrompt: "执行",
            model: "ask-model-\(index)",
            campId: camp.id
        )
        try db.saveCompanion(companion)
        companions.append(companion)
    }
    return companions
}

private func askMission(
    _ db: AppDatabase,
    companionCount: Int = 1,
    drafts: [PlanProposal.CardDraft]
) throws -> (missionId: String, companions: [CompanionRecord]) {
    let companions = try askCompanions(db, count: companionCount)
    let missionId = try db.createMissionShell(goal: "g", companionIds: companions.map(\.id), workspacePath: nil)
    try db.planMission(missionId: missionId, goalRefined: "g", drafts: drafts)
    return (missionId, companions)
}

private func askOrchestrator(
    db: AppDatabase,
    root: URL,
    providers: [String: any LLMProvider]
) -> Orchestrator {
    Orchestrator(
        db: db,
        makeProvider: { model in providers[model] ?? MockProvider(script: []) },
        artifactStoreRoot: root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
}

private func askUserTurn(
    kind: String = "choice",
    prompt: String = "选哪个？",
    options: [JSONValue] = ["A", "B"],
    id: String = UUID().uuidString
) -> TurnResult {
    var input: JSONValue = [
        "kind": .string(kind),
        "prompt": .string(prompt),
    ]
    if !options.isEmpty {
        input = [
            "kind": .string(kind),
            "prompt": .string(prompt),
            "options": .array(options),
        ]
    }
    return TurnResult(
        content: [.toolUse(id: id, name: "ask_user", input: input)],
        stopReason: .toolUse
    )
}

private func askCompleteTurn(summary: String = "done") -> TurnResult {
    TurnResult(
        content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
            "outcome": .string(summary),
            "summary": .string(summary),
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])],
        stopReason: .toolUse
    )
}

private func firstText(_ message: APIMessage) -> String {
    guard case .text(let text) = message.content.first else { return "" }
    return text
}

@Test func askUserSuspendsCardAndPersistsRequest() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 10)
    let mock = MockProvider(script: [askUserTurn()])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: root.appendingPathComponent("artifacts"))

    var sawBlocked = false
    for try await event in try runner.run(cardId: ids.cardId, companionName: "甲", rolePrompt: "r") {
        if case .finished(.blocked(let reason, let detail)) = event {
            sawBlocked = reason == "needs_human_input" && detail == "选哪个？"
        }
    }

    #expect(sawBlocked)
    let card = try #require(try db.card(id: ids.cardId))
    #expect(card.status == .blocked)
    #expect(card.blockedReasonJson?.contains("userRequestId") == true)
    let pending = try db.pendingUserRequests(missionId: ids.missionId)
    #expect(pending.count == 1)
    #expect(pending[0].kind == .choice)
    #expect(pending[0].prompt == "选哪个？")
}

@Test func askUserValidationErrorsSelfHeal() async throws {
    let fixture = try makeAskBoardFixture()

    let badKind = await fixture.tools.askUser(input: ["kind": "number", "prompt": "p"])
    guard case .error = badKind else {
        Issue.record("invalid kind should self-heal as tool error")
        return
    }
    let missingOptions = await fixture.tools.askUser(input: ["kind": "choice", "prompt": "p"])
    guard case .error = missingOptions else {
        Issue.record("choice without options should self-heal as tool error")
        return
    }
    let oneOption = await fixture.tools.askUser(input: [
        "kind": "choice",
        "prompt": "p",
        "options": ["only"],
    ])
    guard case .error = oneOption else {
        Issue.record("choice with one option should self-heal as tool error")
        return
    }

    #expect(try fixture.db.card(id: fixture.cardId)?.status == .running)
    #expect(try fixture.db.pendingUserRequests(missionId: fixture.missionId).isEmpty)
}

@Test func answerResumesWithQAInContext() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let (missionId, companions) = try askMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    let provider = MockProvider(script: [
        askUserTurn(prompt: "请选择执行路线", options: ["北线-唯一选项", "南线-唯一选项"]),
        askCompleteTurn(summary: "answered"),
    ])
    let orch = askOrchestrator(db: db, root: root, providers: [companions[0].model: provider])

    await orch.reconcile()
    await orch.waitUntilIdle()
    let request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":1}"#)
    await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.done])
    let histories = await provider.recordedHistories
    #expect(histories.count == 2)
    let resumed = firstText(histories[1][0])
    #expect(resumed.contains("# 此前你向用户提问的记录"))
    #expect(resumed.contains("请选择执行路线"))
    #expect(resumed.contains("南线-唯一选项"))
    await orch.shutdown()
}

@Test func answerStaleRequestThrows() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let (missionId, companions) = try askMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    let provider = MockProvider(script: [askUserTurn()])
    let orch = askOrchestrator(db: db, root: root, providers: [companions[0].model: provider])

    await orch.reconcile()
    await orch.waitUntilIdle()
    let request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    await orch.cancelMission(missionId)

    await #expect(throws: StaleUserRequestError.self) {
        try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":0}"#)
    }
    #expect(try db.cards(missionId: missionId).map(\.status) == [.canceled])
    await orch.shutdown()
}

@Test func answerGuardRejectsMismatchedRequest() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 10)
    try db.startRun(cardId: ids.cardId, runId: "run-1")
    let requestId = try db.suspendCardForUserRequest(
        cardId: ids.cardId,
        runId: "run-1",
        kind: .choice,
        prompt: "选？",
        options: ["A", "B"]
    )
    try db.transitionCard(id: ids.cardId, to: .ready, eventKind: "card_ready", payload: .object([:]))
    try db.blockCard(id: ids.cardId, runId: nil, reason: "tool_failure", detail: "工具失败")

    #expect(throws: StaleUserRequestError.self) {
        try db.answerUserRequest(requestId: requestId, answerJson: #"{"choice":0}"#)
    }
    let card = try #require(try db.card(id: ids.cardId))
    #expect(card.status == .blocked)
    #expect(card.blockedReasonJson?.contains("tool_failure") == true)
}

@Test func askingCompanionDoesNotBlockOthers() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let (missionId, companions) = try askMission(db, companionCount: 2, drafts: [
        .init(title: "Ask", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "Done", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    let asker = MockProvider(script: [askUserTurn()])
    let finisher = MockProvider(script: [askCompleteTurn()])
    let orch = askOrchestrator(db: db, root: root, providers: [
        companions[0].model: asker,
        companions[1].model: finisher,
    ])

    await orch.reconcile()
    await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.blocked, .done])
    #expect(try db.pendingUserRequests(missionId: missionId).count == 1)
    await orch.shutdown()
}

@Test func multipleQARoundsAccumulate() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let (missionId, companions) = try askMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    let provider = MockProvider(script: [
        askUserTurn(prompt: "第一题？", options: ["红队-唯一选项", "蓝队-唯一选项"]),
        askUserTurn(kind: "text", prompt: "第二题？", options: []),
        askCompleteTurn(summary: "answered twice"),
    ])
    let orch = askOrchestrator(db: db, root: root, providers: [companions[0].model: provider])

    await orch.reconcile()
    await orch.waitUntilIdle()
    var request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":0}"#)
    await orch.waitUntilIdle()
    request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"text":"补充信息"}"#)
    await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.done])
    let histories = await provider.recordedHistories
    #expect(histories.count == 3)
    let finalUser = firstText(histories[2][0])
    let firstRange = finalUser.range(of: "第一题？")
    let secondRange = finalUser.range(of: "第二题？")
    #expect(firstRange != nil && secondRange != nil)
    if let firstRange, let secondRange {
        #expect(firstRange.lowerBound < secondRange.lowerBound)
    }
    #expect(finalUser.contains("红队-唯一选项"))
    #expect(finalUser.contains("补充信息"))
    await orch.shutdown()
}

private struct AskBoardFixture {
    let db: AppDatabase
    let missionId: String
    let cardId: String
    let tools: BoardTools
}

private func makeAskBoardFixture() throws -> AskBoardFixture {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 10)
    try db.startRun(cardId: ids.cardId, runId: "run-1")
    return AskBoardFixture(
        db: db,
        missionId: ids.missionId,
        cardId: ids.cardId,
        tools: BoardTools(
            db: db,
            cardId: ids.cardId,
            runId: "run-1",
            workspaceRoot: nil,
            artifactStoreRoot: root.appendingPathComponent("artifacts")
        )
    )
}
