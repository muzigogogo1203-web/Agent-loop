import Testing
import Foundation
import GRDB
import AgentLoopCore

private func orchestratorTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func artifactRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func orchestrationCompanions(_ db: AppDatabase) throws -> [CompanionRecord] {
    let camp = try db.ensureDefaultCamp()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "整理", model: "model-a", campId: camp.id)
    let b = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "写作", model: "model-b", campId: camp.id)
    try db.saveCompanion(a)
    try db.saveCompanion(b)
    return [a, b]
}

private func orchestrationMissionEvents(_ db: AppDatabase, missionId: String) throws -> [EventRecord] {
    try db.pool.read { database in
        try EventRecord
            .filter(Column("missionId") == missionId)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
    }
}

private func plannedMission(_ db: AppDatabase, drafts: [PlanProposal.CardDraft]) throws -> (missionId: String, companions: [CompanionRecord]) {
    let companions = try orchestrationCompanions(db)
    let missionId = try db.createMissionShell(goal: "g", companionIds: companions.map(\.id), workspacePath: nil)
    try db.planMission(missionId: missionId, goalRefined: "g", drafts: drafts)
    return (missionId, companions)
}

private func doneTurn(summary: String = "done") -> TurnResult {
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

private func orchestrator(db: AppDatabase, provider: any LLMProvider) throws -> Orchestrator {
    try Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )
}

private actor HangingProvider: LLMProvider {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.markStarted()
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

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func markStarted() {
        started = true
        let current = waiters
        waiters.removeAll()
        for waiter in current {
            waiter.resume()
        }
    }
}

@Test func dependentCardStaysTodoUntilUpstreamDone() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: [0]),
    ])
    let cards = try db.cards(missionId: missionId)
    try await db.pool.write { database in
        var first = cards[0]
        first.status = .blocked
        try first.update(database)
    }
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    await orch.reconcile()
    let refreshed = try db.cards(missionId: missionId)
    #expect(refreshed[1].status == .todo)
    await orch.shutdown()
}

@Test func upstreamDoneUnlocksAndDispatchesDownstream() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: [0]),
    ])
    let provider = MockProvider(script: [doneTurn(summary: "A done"), doneTurn(summary: "B done")])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.reconcile()
    await orch.waitUntilIdle()
    let statuses = try db.cards(missionId: missionId).map(\.status)
    #expect(statuses == [.done, .done])
    await orch.shutdown()
}

@Test func serialGateNeverRunsTwoCards() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    let provider = MockProvider(script: [doneTurn(summary: "A"), doneTurn(summary: "B")])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.reconcile()
    await orch.waitUntilIdle()
    let runs = try await db.pool.read { database in
        try RunRecord
            .filter(sql: "cardId IN (SELECT id FROM card WHERE missionId = ?)", arguments: [missionId])
            .order(Column("startedAt"))
            .fetchAll(database)
    }
    #expect(runs.count == 2)
    let firstEnd = try #require(runs[0].endedAt)
    #expect(firstEnd <= runs[1].startedAt)
    await orch.shutdown()
}

@Test func reconcileIsIdempotent() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    let provider = MockProvider(script: [doneTurn()])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.reconcile()
    await orch.reconcile()
    await orch.waitUntilIdle()
    let runs = try await db.pool.read { database in
        try RunRecord
            .filter(sql: "cardId IN (SELECT id FROM card WHERE missionId = ?)", arguments: [missionId])
            .fetchAll(database)
    }
    #expect(runs.count == 1)
    await orch.shutdown()
}

@Test func cancelMissionTerminalizesAndFails() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "Done", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
        .init(title: "Todo", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
        .init(title: "Blocked", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
        .init(title: "Ready", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
    ])
    let cards = try db.cards(missionId: missionId)
    try await db.pool.write { database in
        var done = cards[0]
        var todo = cards[1]
        var blocked = cards[2]
        var ready = cards[3]
        done.status = .done
        todo.status = .todo
        blocked.status = .blocked
        ready.status = .ready
        for card in [done, todo, blocked, ready] { try card.update(database) }
    }
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    await orch.cancelMission(missionId)
    let refreshed = try db.cards(missionId: missionId)
    #expect(refreshed.map(\.status) == [.done, .canceled, .canceled, .canceled])
    #expect(try db.mission(id: missionId)?.status == .failed)
    let events = try orchestrationMissionEvents(db, missionId: missionId)
    #expect(events.contains { $0.kind == "mission_failed" && $0.payloadJson.contains("abandoned") })
    #expect(events.filter { $0.kind == "card_canceled" }.count == 3)
    #expect(!events.contains { $0.kind == "mission_status_changed" && $0.payloadJson.contains("delivering") })
    await orch.shutdown()
}

@Test func cancelMissionDoesNotDispatchReadyCardDuringRunnerShutdown() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "Slow", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
        .init(title: "Ready", description: "d", expectedOutput: "o", assignee: 1, dependsOn: []),
    ])
    let provider = HangingProvider()
    let orch = try orchestrator(db: db, provider: provider)
    await orch.reconcile()
    await provider.waitUntilStarted()

    let cards = try db.cards(missionId: missionId)
    await orch.cancelMission(missionId)

    #expect(try db.runs(cardId: cards[1].id).isEmpty)
    #expect(try db.cards(missionId: missionId).map(\.status) == [.canceled, .canceled])
    #expect(try db.mission(id: missionId)?.status == .failed)
    await orch.shutdown()
}

@Test func cancelIsNoopWhenTerminal() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    try await db.pool.write { database in
        var mission = try #require(try MissionRecord.fetchOne(database, key: missionId))
        mission.status = .accepted
        try mission.update(database)
    }
    let before = try orchestrationMissionEvents(db, missionId: missionId).count
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    await orch.cancelMission(missionId)
    #expect(try db.mission(id: missionId)?.status == .accepted)
    #expect(try orchestrationMissionEvents(db, missionId: missionId).count == before)
    await orch.shutdown()
}

@Test func missingAssigneeBlocksReadyCard() async throws {
    let db = try orchestratorTempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "A",
        cardDescription: "a", expectedOutput: "o", assigneeId: "missing-companion", maxTurns: KernelDefaults.maxTurns)
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    await orch.reconcile()

    let card = try #require(try db.card(id: ids.cardId))
    #expect(card.status == .blocked)
    let reason = try #require(card.blockedReasonJson)
    #expect(reason.contains("负责伙伴不存在或未指派"))
    await orch.shutdown()
}

@Test func retryBlockedCardRedispatches() async throws {
    let db = try orchestratorTempDB()
    let companion = try orchestrationCompanions(db)[0]
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "A",
        cardDescription: "a", expectedOutput: "o", assigneeId: companion.id, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.blockCard(id: ids.cardId, runId: nil, reason: "other", detail: "blocked")
    let provider = MockProvider(script: [doneTurn()])
    let orch = try orchestrator(db: db, provider: provider)
    try await orch.retryCard(ids.cardId)
    await orch.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    await orch.shutdown()
}

@Test func closeoutAcceptsFromDelivering() async throws {
    let db = try orchestratorTempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "A",
        cardDescription: "a", expectedOutput: "o", assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: ids.cardId, runId: nil, handoff: HandoffPayload(
        outcome: "done", summary: "done", artifacts: [], noArtifactReason: "none", verification: [], risks: []
    ), durableArtifacts: [])
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    try await orch.closeout(ids.missionId)
    #expect(try db.mission(id: ids.missionId)?.status == .accepted)
    await orch.shutdown()
}

@Test func closeoutThrowsWhenNotDelivering() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    await #expect(throws: MissionStateError.self) {
        try await orch.closeout(missionId)
    }
    await orch.shutdown()
}
