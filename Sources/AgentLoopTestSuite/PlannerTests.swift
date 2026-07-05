import Testing
import Foundation
import GRDB
import AgentLoopCore

private func plannerTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func savePlannerCompanions(_ db: AppDatabase) throws -> [CompanionRecord] {
    let camp = try db.ensureDefaultCamp()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "负责资料整理\n其他", model: "model-a", campId: camp.id)
    let b = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "负责写作", model: "model-b", campId: camp.id)
    try db.saveCompanion(a)
    try db.saveCompanion(b)
    return [a, b]
}

private func missionEvents(_ db: AppDatabase, missionId: String) throws -> [EventRecord] {
    try db.pool.read { database in
        try EventRecord
            .filter(Column("missionId") == missionId)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
    }
}

private func proposalInput(
    goalRefined: String = "整理并交付",
    cards: [JSONValue]
) -> JSONValue {
    ["goalRefined": .string(goalRefined), "cards": .array(cards)]
}

private func cardDraftInput(
    title: String,
    description: String = "说明",
    expectedOutput: String = "产出",
    assignee: Int = 0,
    dependsOn: [Int] = []
) -> JSONValue {
    [
        "title": .string(title),
        "description": .string(description),
        "expectedOutput": .string(expectedOutput),
        "assignee": .number(Double(assignee)),
        "dependsOn": .array(dependsOn.map { .number(Double($0)) }),
    ]
}

private func persist(_ result: PlanResult, db: AppDatabase, missionId: String) throws {
    if let reason = result.fallbackReason {
        try db.recordPlanFallback(missionId: missionId, reason: reason)
    }
    try db.planMission(missionId: missionId, goalRefined: result.proposal.goalRefined, drafts: result.proposal.cards)
}

@Test func validProposalPersistsCardsWithKernelIds() throws {
    let db = try plannerTempDB()
    let companions = try savePlannerCompanions(db)
    let missionId = try db.createMissionShell(goal: "做一份报告", companionIds: companions.map(\.id), workspacePath: "/tmp/ws")
    let drafts = [
        PlanProposal.CardDraft(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        PlanProposal.CardDraft(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: [0]),
    ]

    try db.planMission(missionId: missionId, goalRefined: "精炼目标", drafts: drafts)

    let cards = try db.cards(missionId: missionId)
    #expect(cards.count == 2)
    #expect(cards.map(\.idemKey) == ["mission:\(missionId):stage-1", "mission:\(missionId):stage-2"])
    #expect(cards.map(\.stage) == [1, 2])
    #expect(cards.map(\.status) == [.todo, .todo])
    #expect(cards[0].assigneeId == companions[0].id)
    #expect(cards[1].assigneeId == companions[1].id)
    #expect(cards[1].dependsOnJson.contains(cards[0].id))
    #expect(try db.mission(id: missionId)?.goalRefined == "精炼目标")
    let events = try missionEvents(db, missionId: missionId)
    #expect(events.contains { $0.kind == "plan_completed" })
}

@Test func plannerForcesToolChoice() async throws {
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "p1", name: "propose_plan", input: proposalInput(cards: [cardDraftInput(title: "A")]))],
            stopReason: .toolUse
        ),
    ])
    let planner = Planner(provider: mock, retryDelays: [])
    _ = try await planner.propose(goal: "g", roster: [CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")], workspacePath: nil)
    #expect(await mock.recordedToolChoices == [.tool(name: "propose_plan")])
}

@Test func invalidProposalRetriesOnceThenFallsBack() async throws {
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "bad1", name: "propose_plan", input: proposalInput(cards: [
                cardDraftInput(title: "A", dependsOn: [1]),
            ]))],
            stopReason: .toolUse
        ),
        TurnResult(
            content: [.toolUse(id: "bad2", name: "propose_plan", input: proposalInput(cards: [
                cardDraftInput(title: "A", dependsOn: [1]),
            ]))],
            stopReason: .toolUse
        ),
    ])
    let planner = Planner(provider: mock, retryDelays: [])
    let roster = [CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")]
    let result = try await planner.propose(goal: "原始目标", roster: roster, workspacePath: nil)

    #expect(result.fallbackReason == "invalid_after_retry")
    #expect(result.proposal.cards.count == 1)
    #expect(await mock.callCount == 2)
    let retryHistory = await mock.recordedHistories[1]
    guard case .toolResult(let id, let content, let isError) = retryHistory.last?.content.first else {
        Issue.record("expected tool_result correction")
        return
    }
    #expect(id == "bad1")
    #expect(isError)
    #expect(content.contains("dependsOn"))

    let db = try plannerTempDB()
    let companions = try savePlannerCompanions(db)
    let missionId = try db.createMissionShell(goal: "原始目标", companionIds: companions.map(\.id), workspacePath: nil)
    try persist(result, db: db, missionId: missionId)
    #expect(try db.cards(missionId: missionId).count == 1)
    #expect(try missionEvents(db, missionId: missionId).contains { $0.kind == "plan_fallback" && $0.payloadJson.contains("invalid_after_retry") })
}

@Test func noToolCallFallsBack() async throws {
    let mock = MockProvider(script: [
        TurnResult(content: [.text("我会这样做")], stopReason: .endTurn),
        TurnResult(content: [.text("还是不调用工具")], stopReason: .endTurn),
    ])
    let planner = Planner(provider: mock, retryDelays: [])
    let roster = [CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")]
    let result = try await planner.propose(goal: "原始目标", roster: roster, workspacePath: nil)

    #expect(result.fallbackReason == "invalid_after_retry")
    let retryHistory = await mock.recordedHistories[1]
    #expect(retryHistory.contains { message in
        message.role == .assistant && message.content.contains(.text("我会这样做"))
    })
    #expect(retryHistory.last?.content.contains { block in
        if case .toolResult = block { return true }
        return false
    } == false)
    guard case .text(let correction) = retryHistory.last?.content.first else { return }
    #expect(correction.contains("必须调用 propose_plan"))
}

@Test func doublePlanIsNoopWithAuditEvent() throws {
    let db = try plannerTempDB()
    let companions = try savePlannerCompanions(db)
    let missionId = try db.createMissionShell(goal: "g", companionIds: companions.map(\.id), workspacePath: nil)
    let draft = PlanProposal.CardDraft(title: "A", description: "a", expectedOutput: "o", assignee: 0, dependsOn: [])
    try db.planMission(missionId: missionId, goalRefined: "g", drafts: [draft])
    try db.planMission(missionId: missionId, goalRefined: "g2", drafts: [draft])
    #expect(try db.cards(missionId: missionId).count == 1)
    #expect(try missionEvents(db, missionId: missionId).contains { $0.kind == "plan_noop" && $0.payloadJson.contains("cards_exist") })
}

@Test func planAfterCancelIsNoop() throws {
    let db = try plannerTempDB()
    let companions = try savePlannerCompanions(db)
    let missionId = try db.createMissionShell(goal: "g", companionIds: companions.map(\.id), workspacePath: nil)
    try db.pool.write { database in
        var mission = try #require(try MissionRecord.fetchOne(database, key: missionId))
        mission.status = .failed
        try mission.update(database)
    }
    let draft = PlanProposal.CardDraft(title: "A", description: "a", expectedOutput: "o", assignee: 0, dependsOn: [])
    try db.planMission(missionId: missionId, goalRefined: "g", drafts: [draft])
    #expect(try db.cards(missionId: missionId).isEmpty)
    #expect(try missionEvents(db, missionId: missionId).contains { $0.kind == "plan_noop" && $0.payloadJson.contains("not_planning") })
}

@Test func validateRejectsBadShapes() {
    let good = PlanProposal.CardDraft(title: "A", description: "a", expectedOutput: "o", assignee: 0, dependsOn: [])
    let cases = [
        PlanProposal(goalRefined: "g", cards: []),
        PlanProposal(goalRefined: "g", cards: Array(repeating: good, count: 7)),
        PlanProposal(goalRefined: "g", cards: [.init(title: "A", description: "a", expectedOutput: " ", assignee: 0, dependsOn: [])]),
        PlanProposal(goalRefined: "g", cards: [.init(title: "A", description: "a", expectedOutput: "o", assignee: 1, dependsOn: [])]),
        PlanProposal(goalRefined: "g", cards: [.init(title: "A", description: "a", expectedOutput: "o", assignee: 0, dependsOn: [0])]),
    ]
    for proposal in cases {
        guard case .failure = proposal.validate(rosterCount: 1) else {
            Issue.record("expected validation failure for \(proposal)")
            continue
        }
    }
}
