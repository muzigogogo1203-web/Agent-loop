import Testing
import Foundation
import GRDB
import AgentLoopCore

// M6-D13：规划轮 token 入账——失败的规划也烧了钱，账不能漏

private func tokensTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func roster() -> [CompanionRecord] {
    [CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "整理", model: "m")]
}

private func validPlanTurn(usage: Usage) -> TurnResult {
    TurnResult(
        content: [.toolUse(id: "p1", name: "propose_plan", input: [
            "goalRefined": "整理并交付",
            "cards": [[
                "title": "卡一", "description": "说明", "expectedOutput": "产出",
                "assignee": 0, "dependsOn": [],
            ]],
        ])],
        stopReason: .toolUse,
        usage: usage
    )
}

private func chatterTurn(usage: Usage) -> TurnResult {
    TurnResult(content: [.text("我来想想")], stopReason: .endTurn, usage: usage)
}

@Test func plannerAccumulatesUsageAcrossTurns() async throws {
    // 第一轮没调工具（重试），第二轮成功——两轮 usage 都要入账
    let mock = MockProvider(script: [
        chatterTurn(usage: Usage(inputTokens: 500, outputTokens: 100, cacheReadTokens: 50)),
        validPlanTurn(usage: Usage(inputTokens: 1000, outputTokens: 200, cacheReadTokens: 80)),
    ])
    let planner = Planner(provider: mock, retryDelays: [])
    let result = try await planner.propose(goal: "g", roster: roster(), workspacePath: nil)
    #expect(result.fallbackReason == nil)
    #expect(result.usage == Usage(inputTokens: 1500, outputTokens: 300, cacheReadTokens: 130))
}

@Test func plannerFallbackStillCarriesSpentUsage() async throws {
    // 两轮都没调出合法规划 → 确定性回退，但已消耗的 usage 照样带回
    let mock = MockProvider(script: [
        chatterTurn(usage: Usage(inputTokens: 500, outputTokens: 100)),
        chatterTurn(usage: Usage(inputTokens: 300, outputTokens: 50)),
    ])
    let planner = Planner(provider: mock, retryDelays: [])
    let result = try await planner.propose(goal: "g", roster: roster(), workspacePath: nil)
    #expect(result.fallbackReason == "invalid_after_retry")
    #expect(result.usage == Usage(inputTokens: 800, outputTokens: 150))
}

@Test func recordPlanningTokensUpdatesSpentAndAppendsEvent() throws {
    let db = try tokensTempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: nil
    )
    try db.recordPlanningTokens(
        missionId: ids.missionId, inputTokens: 1200, outputTokens: 300, cacheReadTokens: 400)

    let mission = try #require(try db.mission(id: ids.missionId))
    #expect(mission.spentTokens == 1500)

    let events = try db.pool.read { database in
        try EventRecord.filter(Column("missionId") == ids.missionId)
            .order(Column("createdAt"), Column.rowID).fetchAll(database)
    }
    // 事件 kind 是持久化契约：测试钉裸字符串（D2 纪律）
    let tokenEvents = events.filter { $0.kind == "planning_tokens" }
    #expect(tokenEvents.count == 1)
    #expect(tokenEvents.first?.payloadJson.contains("1200") == true)
}

@Test func recordPlanningTokensSaturatesInsteadOfOverflowing() throws {
    let db = try tokensTempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: nil
    )
    try db.recordPlanningTokens(
        missionId: ids.missionId, inputTokens: Int.max, outputTokens: Int.max, cacheReadTokens: 0)
    let mission = try #require(try db.mission(id: ids.missionId))
    #expect(mission.spentTokens == Int.max)
}
