import Testing
import Foundation
import GRDB
import AgentLoopCore

private func budgetTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func budgetArtifactRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func budgetDoneTurn() -> TurnResult {
    TurnResult(
        content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
            "outcome": "完成", "summary": "s", "artifacts": [],
            "noArtifactReason": "无", "verification": [], "risks": [],
        ])],
        stopReason: .toolUse
    )
}

private func drainBudget(_ db: AppDatabase, missionId: String) throws {
    try db.pool.write { database in
        try database.execute(
            sql: "UPDATE mission SET spentTokens = budgetTokens WHERE id = ?",
            arguments: [missionId])
    }
}

private func budgetEvents(_ db: AppDatabase, missionId: String, kind: String) throws -> Int {
    try db.pool.read { database in
        try EventRecord
            .filter(Column("missionId") == missionId && Column("kind") == kind)
            .fetchCount(database)
    }
}

private actor BudgetHangingProvider: LLMProvider {
    nonisolated func streamTurn(
        system: String, history: [APIMessage], tools: [ToolDef],
        toolChoice: ToolChoice, maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(3600))
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - 预算门（spec §13）

@Test func exhaustedBudgetStopsDispatchAndNotifiesOnce() async throws {
    let db = try budgetTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "t",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)
    try drainBudget(db, missionId: ids.missionId)

    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in MockProvider(script: [budgetDoneTurn()]) },
        artifactStoreRoot: try budgetArtifactRoot(),
        tickInterval: nil
    )
    await orch.reconcile()
    await orch.reconcile() // 第二次不重复发事件

    #expect(try db.card(id: ids.cardId)?.status == .ready) // 停派发
    #expect(try budgetEvents(db, missionId: ids.missionId, kind: "mission_budget_exhausted") == 1)
    await orch.shutdown()
}

@Test func addBudgetResumesDispatchToDone() async throws {
    let db = try budgetTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "t",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)
    try drainBudget(db, missionId: ids.missionId)

    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in MockProvider(script: [budgetDoneTurn()]) },
        artifactStoreRoot: try budgetArtifactRoot(),
        tickInterval: nil
    )
    await orch.reconcile()
    #expect(try db.card(id: ids.cardId)?.status == .ready)

    // 三选：加预算 → 立即恢复派发并跑完
    try await orch.addBudget(missionId: ids.missionId, tokens: 100_000)
    await orch.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(try budgetEvents(db, missionId: ids.missionId, kind: "budget_added") == 1)

    let mission = try #require(try db.mission(id: ids.missionId))
    #expect(mission.budgetTokens > mission.spentTokens)
    await orch.shutdown()
}

// MARK: - 就地收成果

@Test func harvestKeepsDoneAndCancelsRest() async throws {
    let db = try budgetTempDB()
    _ = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(companion)
    let (missionId, _) = try {
        let missionId = try db.createMissionShell(goal: "g", companionIds: [companion.id], workspacePath: nil)
        try db.planMission(missionId: missionId, goalRefined: "g", drafts: [
            .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
            .init(title: "B", description: "b", expectedOutput: "ob", assignee: 0, dependsOn: [0]),
        ])
        return (missionId, ())
    }()
    // A 做完，B 还没跑
    let cards = try db.cards(missionId: missionId)
    let cardA = cards[0]
    try db.transitionCard(id: cardA.id, to: .ready, eventKind: "card_ready", payload: .object([:]))
    try db.transitionCard(id: cardA.id, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: cardA.id, runId: nil, handoff: HandoffPayload(
        outcome: "done", summary: "s", artifacts: [], noArtifactReason: "无",
        verification: [], risks: []), durableArtifacts: [])

    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: try budgetArtifactRoot(),
        tickInterval: nil
    )
    await orch.harvestMission(missionId)

    let after = try db.cards(missionId: missionId)
    #expect(after[0].status == .done)      // 已完成的保留
    #expect(after[1].status == .canceled)  // 未完成的取消
    #expect(try db.mission(id: missionId)?.status == .delivering) // 可正常收营
    let harvested = try db.events(cardId: after[1].id)
    #expect(harvested.contains { $0.kind == "card_canceled" && $0.payloadJson.contains("budget_harvest") })
    await orch.shutdown()
}

@Test func harvestWithNothingDoneFails() async throws {
    let db = try budgetTempDB()
    _ = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(companion)
    let missionId = try db.createMissionShell(goal: "g", companionIds: [companion.id], workspacePath: nil)
    try db.planMission(missionId: missionId, goalRefined: "g", drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    // planning→executing：卡 ready 后 rollup
    let card = try db.cards(missionId: missionId)[0]
    try db.transitionCard(id: card.id, to: .ready, eventKind: "card_ready", payload: .object([:]))

    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: try budgetArtifactRoot(),
        tickInterval: nil
    )
    await orch.harvestMission(missionId)
    #expect(try db.cards(missionId: missionId)[0].status == .canceled)
    #expect(try db.mission(id: missionId)?.status == .failed)
    await orch.shutdown()
}

// MARK: - 全局并发节流

@Test func globalThrottleCapsConcurrentRuns() async throws {
    let db = try budgetTempDB()
    let camp = try db.ensureDefaultCamp()
    var cardIds: [String] = []
    for index in 0..<6 {
        let companion = CompanionRecord.new(
            name: "伙伴\(index)", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
        try db.saveCompanion(companion)
        let ids = try db.createSingleCardMission(
            campName: "c", squadName: "s\(index)", goal: "g\(index)", cardTitle: "t\(index)",
            cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)
        cardIds.append(ids.cardId)
    }

    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in BudgetHangingProvider() },
        artifactStoreRoot: try budgetArtifactRoot(),
        tickInterval: nil
    )
    await orch.reconcile()

    // 等派发落库（startRun 在 runner task 内异步发生）
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    var runningCount = 0
    while ContinuousClock.now < deadline {
        runningCount = try await db.pool.read { database in
            try CardRecord.filter(Column("status") == CardStatus.running.rawValue).fetchCount(database)
        }
        if runningCount == KernelDefaults.maxConcurrentCardRuns { break }
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(runningCount == KernelDefaults.maxConcurrentCardRuns)

    // 再 reconcile 一次也不超上限
    await orch.reconcile()
    try await Task.sleep(for: .milliseconds(100))
    let after = try await db.pool.read { database in
        try CardRecord.filter(Column("status") == CardStatus.running.rawValue).fetchCount(database)
    }
    #expect(after == KernelDefaults.maxConcurrentCardRuns)

    await orch.shutdown()
}
