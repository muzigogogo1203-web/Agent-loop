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

private func orchestrationCompanions(_ db: AppDatabase, count: Int = 2) throws -> [CompanionRecord] {
    let camp = try db.ensureDefaultCamp()
    let names = ["甲", "乙", "丙", "丁", "戊", "己"]
    var companions: [CompanionRecord] = []
    for index in 0..<count {
        let companion = CompanionRecord.new(
            name: names[index],
            color: "blue",
            rolePrompt: "执行",
            model: "model-\(index)",
            campId: camp.id
        )
        try db.saveCompanion(companion)
        companions.append(companion)
    }
    return companions
}

private func orchestrationMissionEvents(_ db: AppDatabase, missionId: String) throws -> [EventRecord] {
    try db.pool.read { database in
        try EventRecord
            .filter(Column("missionId") == missionId)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
    }
}

private func plannedMission(
    _ db: AppDatabase,
    companionCount: Int = 2,
    drafts: [PlanProposal.CardDraft]
) throws -> (missionId: String, companions: [CompanionRecord]) {
    let companions = try orchestrationCompanions(db, count: companionCount)
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

private actor GatedProvider: LLMProvider {
    private struct Pending {
        let id: UUID
        let continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    }

    private var script: [TurnResult]
    private var pending: [Pending] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var callCount = 0

    init(script: [TurnResult]) {
        self.script = script
    }

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        let id = UUID()
        return AsyncThrowingStream { continuation in
            Task {
                await self.enqueue(id: id, continuation: continuation)
            }
            continuation.onTermination = { _ in
                Task { await self.cancel(id: id) }
            }
        }
    }

    func waitUntilStarted(count: Int = 1) async {
        if callCount >= count { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func release() {
        guard !pending.isEmpty else { return }
        let next = pending.removeFirst()
        guard !script.isEmpty else {
            next.continuation.finish(throwing: ProviderError.malformedStream("gated script exhausted"))
            return
        }
        let turn = script.removeFirst()
        for block in turn.content {
            if case .text(let text) = block {
                next.continuation.yield(.textDelta(text))
            }
        }
        next.continuation.yield(.turn(turn))
        next.continuation.finish()
    }

    private func enqueue(
        id: UUID,
        continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    ) {
        callCount += 1
        pending.append(Pending(id: id, continuation: continuation))
        resumeReadyWaiters()
    }

    private func cancel(id: UUID) {
        pending.removeAll { $0.id == id }
    }

    private func resumeReadyWaiters() {
        let ready = waiters.filter { callCount >= $0.count }
        waiters.removeAll { callCount >= $0.count }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}

private func orchestrationRuns(_ db: AppDatabase, missionId: String) throws -> [RunRecord] {
    try db.pool.read { database in
        try RunRecord
            .filter(sql: "cardId IN (SELECT id FROM card WHERE missionId = ?)", arguments: [missionId])
            .order(Column("startedAt"))
            .fetchAll(database)
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

@Test func sameCompanionCardsStaySerial() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 0, dependsOn: []),
    ])
    let provider = GatedProvider(script: [doneTurn(summary: "A"), doneTurn(summary: "B")])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.reconcile()
    await provider.waitUntilStarted()
    #expect(await provider.callCount == 1)
    await provider.release()
    await provider.waitUntilStarted(count: 2)
    await provider.release()
    await orch.waitUntilIdle()
    let runs = try orchestrationRuns(db, missionId: missionId)
    #expect(runs.count == 2)
    let firstEnd = try #require(runs[0].endedAt)
    #expect(firstEnd <= runs[1].startedAt)
    await orch.shutdown()
}

@Test func distinctCompanionsRunConcurrently() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, companionCount: 3, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
        .init(title: "C", description: "c", expectedOutput: "oc", assignee: 2, dependsOn: []),
    ])
    let providers = [
        GatedProvider(script: [doneTurn(summary: "A")]),
        GatedProvider(script: [doneTurn(summary: "B")]),
        GatedProvider(script: [doneTurn(summary: "C")]),
    ]
    let orch = try Orchestrator(
        db: db,
        makeProvider: { model in
            switch model {
            case "model-0": providers[0]
            case "model-1": providers[1]
            default: providers[2]
            }
        },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.reconcile()
    await providers[0].waitUntilStarted()
    await providers[1].waitUntilStarted()
    await providers[2].waitUntilStarted()
    #expect(await providers[0].callCount == 1)
    #expect(await providers[1].callCount == 1)
    #expect(await providers[2].callCount == 1)

    await providers[0].release()
    await providers[1].release()
    await providers[2].release()
    await orch.waitUntilIdle()

    let runs = try orchestrationRuns(db, missionId: missionId)
    #expect(runs.count == 3)
    let latestStart = try #require(runs.map(\.startedAt).max())
    let earliestEnd = try #require(runs.compactMap(\.endedAt).min())
    #expect(latestStart <= earliestEnd)
    await orch.shutdown()
}

@Test func mixedGatingDispatchesEagerly() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A1", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "A2", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B1", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    let providerA = GatedProvider(script: [doneTurn(summary: "A1"), doneTurn(summary: "A2")])
    let providerB = GatedProvider(script: [doneTurn(summary: "B1")])
    let orch = try Orchestrator(
        db: db,
        makeProvider: { model in model == "model-0" ? providerA : providerB },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.reconcile()
    await providerA.waitUntilStarted()
    await providerB.waitUntilStarted()
    #expect(await providerA.callCount == 1)
    #expect(await providerB.callCount == 1)

    await providerB.release()
    await orch.reconcile()
    #expect(await providerA.callCount == 1)

    await providerA.release()
    await providerA.waitUntilStarted(count: 2)
    await providerA.release()
    await orch.waitUntilIdle()
    #expect(try db.cards(missionId: missionId).map(\.status) == [.done, .done, .done])
    await orch.shutdown()
}

@Test func busyCompanionSkippedNotStarved() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A1", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "A2", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B1", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    let providerA = GatedProvider(script: [doneTurn(summary: "A1"), doneTurn(summary: "A2")])
    let providerB = GatedProvider(script: [doneTurn(summary: "B1")])
    let orch = try Orchestrator(
        db: db,
        makeProvider: { model in model == "model-0" ? providerA : providerB },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.reconcile()
    await providerA.waitUntilStarted()
    await providerB.waitUntilStarted()
    await providerB.release()
    await orch.reconcile()
    #expect(await providerA.callCount == 1)

    await providerA.release()
    await providerA.waitUntilStarted(count: 2)
    await providerA.release()
    await orch.waitUntilIdle()
    #expect(try db.cards(missionId: missionId).map(\.status) == [.done, .done, .done])
    await orch.shutdown()
}

@Test func cancelDuringConcurrentRunsTerminalizesAll() async throws {
    let db = try orchestratorTempDB()
    let (missionId, _) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    let providerA = GatedProvider(script: [doneTurn(summary: "A")])
    let providerB = GatedProvider(script: [doneTurn(summary: "B")])
    let orch = try Orchestrator(
        db: db,
        makeProvider: { model in model == "model-0" ? providerA : providerB },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.reconcile()
    await providerA.waitUntilStarted()
    await providerB.waitUntilStarted()
    await orch.cancelMission(missionId)

    #expect(try db.cards(missionId: missionId).map(\.status) == [.canceled, .canceled])
    let outcomes = try orchestrationRuns(db, missionId: missionId).map(\.outcome)
    #expect(outcomes == ["canceled", "canceled"])
    #expect(try db.mission(id: missionId)?.status == .failed)
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
        .init(title: "Ready", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
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

@Test func startupProposalHealingFailureIsPersistedAndEmitted() async throws {
    let db = try orchestratorTempDB()
    try await db.pool.write { database in
        try database.drop(table: "chat_message")
    }
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    let stream = await orch.events()
    let emittedError = Task { () -> String? in
        for await event in stream {
            if case .kernelError(_, let message) = event,
               message.contains("提案自愈失败") {
                return message
            }
        }
        return nil
    }

    await orch.recoverAndReconcile()
    await orch.shutdown()

    #expect(await emittedError.value?.contains("提案自愈失败") == true)
    let persisted = try db.events(missionId: "").first { $0.kind == EventKind.kernelError }
    #expect(persisted?.payloadJson.contains("提案自愈失败") == true)
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
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
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
        try await orch.closeout(missionId, distillModel: "distill-model")
    }
    await orch.shutdown()
}

// MARK: - 收营蒸馏旁路（M4，spec §9-1）

@Test func closeoutDistillsFallbackNoteOnProviderFailure() async throws {
    let db = try orchestratorTempDB()
    let camp = try db.ensureDefaultCamp()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "探索北岭", cardTitle: "画地图",
        cardDescription: "a", expectedOutput: "o", assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: ids.cardId, runId: nil, handoff: HandoffPayload(
        outcome: "完成", summary: "地图画好了", artifacts: [], noArtifactReason: "无", verification: [], risks: []
    ), durableArtifacts: [])

    // 空脚本 → 蒸馏 LLM 必失败 → 确定性回退，任何路径都产出一张笔记
    let orch = try orchestrator(db: db, provider: MockProvider(script: []))
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    await orch.waitUntilIdle() // waitUntilIdle 必须等到蒸馏旁路任务完成

    let notes = try db.campNotes(campId: camp.id)
    #expect(notes.count == 1)
    #expect(notes.first?.missionId == ids.missionId)
    #expect(notes.first?.bodyMd.contains("地图画好了") == true)

    let events = try orchestrationMissionEvents(db, missionId: ids.missionId)
    let noteEvent = events.first { $0.kind == "camp_note_created" }
    #expect(noteEvent != nil)
    #expect(noteEvent?.payloadJson.contains(#""source":"fallback""#) == true)
    await orch.shutdown()
}

@Test func closeoutDistillsLLMNoteWhenParseable() async throws {
    let db = try orchestratorTempDB()
    let camp = try db.ensureDefaultCamp()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "探索北岭", cardTitle: "画地图",
        cardDescription: "a", expectedOutput: "o", assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: ids.cardId, runId: nil, handoff: HandoffPayload(
        outcome: "完成", summary: "地图画好了", artifacts: [], noArtifactReason: "无", verification: [], risks: []
    ), durableArtifacts: [])

    let distillJSON = ###"{"title":"北岭复盘","body":"## 做了什么\n画了地图"}"###
    let orch = try orchestrator(db: db, provider: MockProvider(script: [
        TurnResult(content: [.text(distillJSON)], stopReason: .endTurn),
    ]))
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    await orch.waitUntilIdle()

    let notes = try db.campNotes(campId: camp.id)
    #expect(notes.first?.title == "北岭复盘")

    let events = try orchestrationMissionEvents(db, missionId: ids.missionId)
    let noteEvent = events.first { $0.kind == "camp_note_created" }
    #expect(noteEvent?.payloadJson.contains(#""source":"closeout""#) == true)
    await orch.shutdown()
}

@Test func closeoutDistillsCoworkNoteWithMissionGoalPrefix() async throws {
    let db = try orchestratorTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "甲",
        color: "blue",
        rolePrompt: "执行",
        model: "model-a",
        campId: camp.id
    )
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: camp.name,
        squadName: "远征队",
        goal: "abcdefghijklmnopqrstuv",
        cardTitle: "画地图",
        cardDescription: "a",
        expectedOutput: "o",
        assigneeId: companion.id,
        maxTurns: KernelDefaults.maxTurns,
        campId: camp.id
    )
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: ids.cardId, runId: nil, handoff: HandoffPayload(
        outcome: "完成", summary: "地图画好了", artifacts: [], noArtifactReason: "无", verification: [], risks: []
    ), durableArtifacts: [])

    let provider = MockProvider(script: [
        TurnResult(content: [.text(###"{"title":"北岭复盘","body":"## 做了什么\n画了地图"}"###)], stopReason: .endTurn),
        TurnResult(content: [.text(###"{"title":"协作经验","body":"- 先确认地形"}"###)], stopReason: .endTurn),
    ])
    let orch = try orchestrator(db: db, provider: provider)
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    await orch.waitUntilIdle()

    let notes = try db.companionNotes(companionId: companion.id)
    #expect(notes.count == 1)
    #expect(notes.first?.title == "共事·abcdefghijklmnopqrst:协作经验")
    await orch.shutdown()
}
