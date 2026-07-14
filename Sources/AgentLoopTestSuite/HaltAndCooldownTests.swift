import Testing
import Foundation
import GRDB
import AgentLoopCore

// M7-D5/D8：紧急收哨 + 429 全局冷却

private func haltTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func haltCompanion(_ db: AppDatabase) throws -> CompanionRecord {
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    return companion
}

private func completeScript() -> [TurnResult] {
    [TurnResult(content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
        "outcome": "o", "summary": "s", "noArtifactReason": "无",
        "verification": [["method": "自查", "passed": true, "note": "ok"]],
        "risks": [],
    ])], stopReason: .toolUse)]
}

private func planningScript() -> [TurnResult] {
    [TurnResult(content: [.toolUse(id: "plan", name: "propose_plan", input: [
        "goalRefined": "规划完成",
        "cards": [[
            "title": "执行",
            "description": "执行任务",
            "expectedOutput": "可验证结果",
            "assignee": 0,
            "dependsOn": [],
        ]],
    ])], stopReason: .toolUse)]
}

private func waitForCard(
    _ db: AppDatabase, _ cardId: String, status: CardStatus, timeout: Duration = .seconds(5)
) async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if try db.card(id: cardId)?.status == status { return true }
        try await Task.sleep(for: .milliseconds(30))
    }
    return try db.card(id: cardId)?.status == status
}

private func globalEvents(_ db: AppDatabase, kind: String) throws -> Int {
    try db.pool.read { database in
        try EventRecord.filter(Column("kind") == kind).fetchCount(database)
    }
}

private actor HaltGate {
    private var entered = false
    private var opened = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func suspend() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        guard !opened else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        opened = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

private actor HaltHangingProvider: LLMProvider {
    private var calls = 0
    private var cancellations = 0
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String, history: [APIMessage], tools: [ToolDef],
        toolChoice: ToolChoice, maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.markStarted()
                do {
                    try await Task.sleep(for: .seconds(3_600))
                    continuation.finish()
                } catch is CancellationError {
                    await self.markCanceled()
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func markStarted() {
        calls += 1
        startedWaiters.forEach { $0.resume() }
        startedWaiters.removeAll()
    }

    private func markCanceled() {
        cancellations += 1
    }

    func waitUntilStarted() async {
        guard calls == 0 else { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func waitUntilCanceled(timeout: Duration = .seconds(1)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while cancellations == 0 && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return cancellations > 0
    }

    var callCount: Int { calls }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private struct HaltFailingTransport: McpTransport {
    let messages = AsyncThrowingStream<Data, Error> { $0.finish() }
    func start() async throws { throw McpClientError.connectionClosed }
    func send(_ data: Data) async throws { throw McpClientError.connectionClosed }
    func close() async {}
}

/// 立抛 429 的替身：AgentLoop 层 429 不重试（provider 层已重试过），错误直达 Orchestrator
private struct RateLimitedProvider: LLMProvider {
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                    toolChoice: ToolChoice, maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ProviderError.http(status: 429, body: "rate limited"))
        }
    }
}

@Test func emergencyStopHaltsDispatchAndResumeContinues() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in MockProvider(script: completeScript()) },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    // 收哨后 reconcile 不派发
    try await orchestrator.emergencyStop()
    await orchestrator.reconcile()
    try await Task.sleep(for: .milliseconds(150))
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(try globalEvents(db, kind: "camp_halted") == 1)
    let halted = await orchestrator.isHalted
    #expect(halted)

    // 解除收哨 → 立即派发 → 完成
    try await orchestrator.resume()
    let done = try await waitForCard(db, ids.cardId, status: .done)
    #expect(done)
    #expect(try globalEvents(db, kind: "camp_resumed") == 1)
}

@Test func haltedRecoveryStartsNoKernelWorkOrMcpTransport() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let planningMissionId = try db.createMissionShell(
        goal: "planning", companionIds: [companion.id], workspacePath: nil)
    let campId = try #require(try db.squad(forMission: ids.missionId)?.campId)
    let server = McpServerRecord.new(name: "halt-test", command: "false", args: [])
    try db.addMcpServer(server)
    try db.setMcpServerEnabled(campId: campId, serverId: server.id, enabled: true)
    try db.transitionDispatchMode(from: .running, to: .halted)

    let transportCreations = LockedCounter()
    let manager = McpServerManager(
        db: db,
        transportFactory: { _, _ in
            transportCreations.increment()
            return HaltFailingTransport()
        },
        baseEnvironment: { [:] },
        initTimeout: .milliseconds(10),
        callTimeout: .milliseconds(10)
    )
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: .milliseconds(1),
        mcpManager: manager
    )

    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(await provider.callCount == 0)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(transportCreations.count == 0)
    #expect(try db.mission(id: planningMissionId)?.status == .failed)
    #expect(try db.events(missionId: planningMissionId).contains {
        $0.kind == EventKind.missionFailed
            && $0.payloadJson.contains("emergency_halt_during_planning")
    })
    let planningStatusEvents = try db.events(missionId: planningMissionId).filter {
        $0.kind == EventKind.missionStatusChanged
            && $0.payloadJson.contains("\"from\":\"planning\"")
            && $0.payloadJson.contains("\"to\":\"failed\"")
    }
    #expect(planningStatusEvents.count == 1)
    await orchestrator.shutdown()
}

@Test func startupBootstrapGateBlocksDispatchUntilRecoveryCompletes() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        requiresStartupRecovery: true
    )
    let missionCountBefore = try await db.pool.read { try MissionRecord.fetchCount($0) }

    await orchestrator.reconcile()
    do {
        _ = try await orchestrator.startMission(
            goal: "too early", companionIds: [companion.id],
            workspacePath: nil, plannerModel: "m")
        Issue.record("startup bootstrap must reject direct starts before recovery")
    } catch is KernelHaltedError {
    } catch {
        Issue.record("unexpected bootstrap error: \(error)")
    }

    #expect(try await db.pool.read { try MissionRecord.fetchCount($0) } == missionCountBefore)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)

    await orchestrator.recoverAndReconcile()
    await orchestrator.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@Test func delayedStartupRecoveryCannotClearFailedEmergencyStop() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_bootstrap_halt_event
            BEFORE INSERT ON event WHEN NEW.kind = 'camp_halted'
            BEGIN SELECT RAISE(ABORT, 'injected bootstrap halt failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        requiresStartupRecovery: true
    )

    do {
        try await orchestrator.emergencyStop()
        Issue.record("injected bootstrap halt persistence failure should throw")
    } catch is HaltPersistenceError {
    } catch {
        Issue.record("unexpected bootstrap stop error: \(error)")
    }
    await orchestrator.recoverAndReconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_bootstrap_halt_event") }
    try await orchestrator.emergencyStop()
    #expect(try db.dispatchMode() == .halted)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 1)
    await orchestrator.shutdown()
}

@Test func delayedStartupRecoveryCannotReviveShutdownKernel() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        requiresStartupRecovery: true
    )

    await orchestrator.shutdown()
    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
}

@Test func missingDurableControlRowKeepsStartupFailClosed() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    try await db.pool.write { database in
        try database.execute(sql: "DELETE FROM kernel_control WHERE id = 'global'")
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: .milliseconds(1)
    )

    await orchestrator.recoverAndReconcile()
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(await provider.callCount == 0)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    await orchestrator.shutdown()
}

@Test func haltedRecoveryAdoptsCrashResidueAndResumeDispatchesOnce() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try db.transitionDispatchMode(from: .running, to: .halted)
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(await provider.callCount == 0)

    try await orchestrator.resume()
    await orchestrator.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(await provider.callCount == 1)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 2)
    #expect(runs.filter { $0.outcome == nil }.isEmpty)
    await orchestrator.shutdown()
}

@Test func haltDuringReconcileDatabaseWindowDropsStaleCandidate() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let provider = MockProvider(script: completeScript())
    let gate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        reconcilePostDatabaseGate: { await gate.suspend() }
    )

    let staleReconcile = Task { await orchestrator.reconcile() }
    await gate.waitUntilEntered()
    try await orchestrator.emergencyStop()
    await gate.open()
    await staleReconcile.value

    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    await orchestrator.shutdown()
}

@Test func haltedPendingReconcileDoesNotRunAnotherDatabasePass() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let provider = MockProvider(script: completeScript())
    let gate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        reconcilePostDatabaseGate: { await gate.suspend() }
    )

    let firstReconcile = Task { await orchestrator.reconcile() }
    await gate.waitUntilEntered()
    try await db.pool.write { database in
        try database.execute(
            sql: "UPDATE card SET status = ? WHERE id = ?",
            arguments: [CardStatus.todo.rawValue, ids.cardId]
        )
    }
    let pendingReconcile = Task { await orchestrator.reconcile() }
    await pendingReconcile.value

    try await orchestrator.emergencyStop()
    await gate.open()
    await firstReconcile.value

    #expect(try db.card(id: ids.cardId)?.status == .todo)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    await orchestrator.shutdown()
}

@Test func haltDuringRunningCardLeavesReadyCardAndNoOpenRun() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let provider = HaltHangingProvider()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    await orchestrator.reconcile()
    await provider.waitUntilStarted()
    try await orchestrator.emergencyStop()
    await orchestrator.reconcile()

    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@Test func haltAfterPlannerResponsePreventsCommitAndFailsPlanningMission() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let provider = MockProvider(script: planningScript())
    let gate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        planningPostProviderGate: { await gate.suspend() }
    )
    let missionId = try await orchestrator.startMission(
        goal: "g", companionIds: [companion.id], workspacePath: nil, plannerModel: "m")
    await gate.waitUntilEntered()

    let stopping = Task { try await orchestrator.emergencyStop() }
    while !(await orchestrator.isHalted) { await Task.yield() }
    await gate.open()
    try await stopping.value

    #expect(try db.mission(id: missionId)?.status == .failed)
    #expect(try db.cards(missionId: missionId).isEmpty)
    #expect(try db.events(missionId: missionId).contains {
        $0.kind == EventKind.missionFailed
            && $0.payloadJson.contains("emergency_halt_during_planning")
    })
    #expect(!((try db.events(missionId: missionId)).contains { $0.kind == EventKind.planningTokens }))
    await orchestrator.shutdown()
}

@Test func emergencyStopCancelsRunningBeforeWaitingForPlanner() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let runningIds = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "running",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let planner = MockProvider(script: planningScript())
    let runner = HaltHangingProvider()
    let gate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { model in
            if model == "planner" { return planner }
            return runner
        },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        planningPostProviderGate: { await gate.suspend() }
    )

    await orchestrator.reconcile()
    await runner.waitUntilStarted()
    let planningMissionId = try await orchestrator.startMission(
        goal: "planning", companionIds: [companion.id],
        workspacePath: nil, plannerModel: "planner")
    await gate.waitUntilEntered()

    let stopping = Task { try await orchestrator.emergencyStop() }
    while !(await orchestrator.isHalted) { await Task.yield() }
    let runningWasCanceledBeforePlannerReleased = await runner.waitUntilCanceled()
    #expect(runningWasCanceledBeforePlannerReleased)

    await gate.open()
    try await stopping.value

    #expect(try db.card(id: runningIds.cardId)?.status == .ready)
    #expect(try db.runs(cardId: runningIds.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(try db.mission(id: planningMissionId)?.status == .failed)
    await orchestrator.shutdown()
}

@Test func planningCleanupFailureIsSurfacedAndBlocksResumeUntilRetried() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let readyIds = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "ready",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let planner = MockProvider(script: planningScript())
    let runner = MockProvider(script: completeScript())
    let gate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { model in
            if model == "planner" { return planner }
            return runner
        },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        planningPostProviderGate: { await gate.suspend() }
    )
    let planningMissionId = try await orchestrator.startMission(
        goal: "planning", companionIds: [companion.id],
        workspacePath: nil, plannerModel: "planner")
    await gate.waitUntilEntered()
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_interrupted_planning_event
            BEFORE INSERT ON event WHEN NEW.kind = 'mission_failed'
            BEGIN SELECT RAISE(ABORT, 'injected planning cleanup failure'); END
            """)
    }

    let stopping = Task { try await orchestrator.emergencyStop() }
    while !(await orchestrator.isHalted) { await Task.yield() }
    await gate.open()
    do {
        try await stopping.value
        Issue.record("planning cleanup failure should make stop throw")
    } catch is PlanningHaltCleanupError {
    } catch {
        Issue.record("unexpected stop error: \(error)")
    }

    #expect(try db.dispatchMode() == .halted)
    #expect(try db.mission(id: planningMissionId)?.status == .planning)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 1)
    let rolledBackPlanningEvents = try db.events(missionId: planningMissionId)
    #expect(!rolledBackPlanningEvents.contains { $0.kind == EventKind.missionFailed })
    #expect(!rolledBackPlanningEvents.contains {
        $0.kind == EventKind.missionStatusChanged
            && $0.payloadJson.contains("\"to\":\"failed\"")
    })
    #expect(await runner.callCount == 0)
    #expect(try db.runs(cardId: readyIds.cardId).isEmpty)

    do {
        try await orchestrator.resume()
        Issue.record("resume must remain fail-closed while planning cleanup fails")
    } catch is PlanningHaltCleanupError {
    } catch {
        Issue.record("unexpected resume error: \(error)")
    }
    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await runner.callCount == 0)

    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_interrupted_planning_event")
    }
    try await orchestrator.resume()
    await orchestrator.waitUntilIdle()

    #expect(try db.mission(id: planningMissionId)?.status == .failed)
    #expect(try db.events(missionId: planningMissionId).contains {
        $0.kind == EventKind.missionFailed
            && $0.payloadJson.contains("emergency_halt_during_planning")
    })
    let committedPlanningStatusEvents = try db.events(missionId: planningMissionId).filter {
        $0.kind == EventKind.missionStatusChanged
            && $0.payloadJson.contains("\"from\":\"planning\"")
            && $0.payloadJson.contains("\"to\":\"failed\"")
    }
    #expect(committedPlanningStatusEvents.count == 1)
    #expect(try db.card(id: readyIds.cardId)?.status == .done)
    #expect(await runner.callCount == 1)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 1)
    await orchestrator.shutdown()
}

@Test func haltPersistenceFailureStillStopsAndCanRetryPersistence() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_halt_orchestrator_event
            BEFORE INSERT ON event WHEN NEW.kind = 'camp_halted'
            BEGIN SELECT RAISE(ABORT, 'injected halt failure'); END
            """)
    }
    let provider = HaltHangingProvider()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )
    await orchestrator.reconcile()
    await provider.waitUntilStarted()

    do {
        try await orchestrator.emergencyStop()
        Issue.record("halt persistence failure should throw")
    } catch {}

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 0)
    await orchestrator.reconcile()
    #expect(await provider.callCount == 1)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_halt_orchestrator_event") }
    try await orchestrator.emergencyStop()
    #expect(try db.dispatchMode() == .halted)
    #expect(try globalEvents(db, kind: EventKind.campHalted) == 1)
    await orchestrator.shutdown()
}

@Test func resumePersistenceFailureStaysHaltedAndDispatchesNothing() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    try db.transitionDispatchMode(from: .running, to: .halted)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_resume_orchestrator_event
            BEFORE INSERT ON event WHEN NEW.kind = 'camp_resumed'
            BEGIN SELECT RAISE(ABORT, 'injected resume failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    do {
        try await orchestrator.resume()
        Issue.record("resume persistence failure should throw")
    } catch {}
    await orchestrator.reconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try db.runs(cardId: ids.cardId).isEmpty)
    #expect(await provider.callCount == 0)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    await orchestrator.shutdown()
}

@Test func orphanRecoveryFailureKeepsResumeClosedUntilRetried() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try db.transitionDispatchMode(from: .running, to: .halted)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_orphan_adoption
            BEFORE UPDATE OF status ON card
            WHEN OLD.status = 'running' AND NEW.status = 'ready'
            BEGIN SELECT RAISE(ABORT, 'injected orphan adoption failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let resumeGate = HaltGate()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        resumePreAdoptionGate: { await resumeGate.suspend() }
    )

    let firstResume = Task { try await orchestrator.resume() }
    await resumeGate.waitUntilEntered()
    do {
        try await orchestrator.resume()
        Issue.record("a concurrent resume must not report success while recovery is pending")
    } catch is KernelTransitionInProgressError {
    } catch {
        Issue.record("unexpected concurrent resume error: \(error)")
    }
    await resumeGate.open()
    do {
        try await firstResume.value
        Issue.record("resume must not open dispatch when orphan adoption fails")
    } catch is HaltRecoveryError {
    } catch {
        Issue.record("unexpected recovery error: \(error)")
    }

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try db.card(id: ids.cardId)?.status == .running)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == nil)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 0)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_orphan_adoption") }
    try await orchestrator.resume()
    await orchestrator.waitUntilIdle()

    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(await provider.callCount == 1)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 1)
    await orchestrator.shutdown()
}

@Test func startupOrphanRecoveryFailureFailsClosedUntilExplicitRetry() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_startup_orphan_adoption
            BEFORE UPDATE OF status ON card
            WHEN OLD.status = 'running' AND NEW.status = 'ready'
            BEGIN SELECT RAISE(ABORT, 'injected startup orphan adoption failure'); END
            """)
    }
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .running)
    #expect(try db.card(id: ids.cardId)?.status == .running)
    #expect(try db.runs(cardId: ids.cardId).count == 1)
    #expect(try db.runs(cardId: ids.cardId).first?.outcome == nil)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 0)

    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_startup_orphan_adoption")
    }
    try await orchestrator.resume()
    await orchestrator.waitUntilIdle()

    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(try db.runs(cardId: ids.cardId).count == 2)
    #expect(try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }.isEmpty)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@Test func staleStartupRecoveryCannotStealNewResumePhase() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    let recoveryGate = HaltGate()
    let resumeGate = HaltGate()
    let provider = MockProvider(script: completeScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        recoveryPostAdoptionGate: { await recoveryGate.suspend() },
        resumePreAdoptionGate: { await resumeGate.suspend() }
    )

    let staleRecovery = Task { await orchestrator.recoverAndReconcile() }
    await recoveryGate.waitUntilEntered()
    try await orchestrator.emergencyStop()

    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_aba_resume_adoption
            BEFORE UPDATE OF status ON card
            WHEN OLD.status = 'running' AND NEW.status = 'ready'
            BEGIN SELECT RAISE(ABORT, 'injected ABA adoption failure'); END
            """)
    }

    let resuming = Task { try await orchestrator.resume() }
    await resumeGate.waitUntilEntered()
    await recoveryGate.open()
    await staleRecovery.value
    await resumeGate.open()
    do {
        try await resuming.value
        Issue.record("the owning resume should surface its adoption failure")
    } catch is HaltRecoveryError {
    } catch {
        Issue.record("unexpected resume error: \(error)")
    }

    #expect(await orchestrator.isHalted)
    #expect(try db.dispatchMode() == .halted)
    #expect(try db.card(id: ids.cardId)?.status == .running)
    #expect(try db.runs(cardId: ids.cardId).first { $0.id == crashedRunId }?.outcome == nil)
    #expect(try globalEvents(db, kind: EventKind.campResumed) == 0)
    #expect(await provider.callCount == 0)

    try await db.pool.write { try $0.execute(sql: "DROP TRIGGER fail_aba_resume_adoption") }
    try await orchestrator.resume()
    await orchestrator.waitUntilIdle()
    #expect(try db.card(id: ids.cardId)?.status == .done)
    #expect(await provider.callCount == 1)
    await orchestrator.shutdown()
}

@Test func directMissionAndProposalStartsAreRejectedWhileHalted() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let campId = try #require(companion.campId)
    let thread = try db.findOrCreateGuideThread(campId: campId)
    let block = SquadProposalBlock(
        proposalId: "halted-proposal", name: "队", memberIds: [companion.id],
        goal: "g", budget: nil, status: .pending)
    let messageId = try db.appendChatMessage(
        threadId: thread.id, role: "guide", contentJson: try block.encodedString())
    try db.transitionDispatchMode(from: .running, to: .halted)
    let provider = MockProvider(script: planningScript())
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in provider },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )
    let beforeCount = try await db.pool.read { try MissionRecord.fetchCount($0) }

    do {
        _ = try await orchestrator.startMission(
            goal: "g", companionIds: [companion.id], workspacePath: nil, plannerModel: "m")
        Issue.record("direct start should be rejected while halted")
    } catch is KernelHaltedError {
    } catch {
        Issue.record("unexpected direct-start error: \(error)")
    }
    do {
        _ = try await orchestrator.confirmSquadProposal(messageId: messageId, plannerModel: "m")
        Issue.record("proposal confirmation should be rejected while halted")
    } catch is KernelHaltedError {
    } catch {
        Issue.record("unexpected proposal error: \(error)")
    }

    let afterCount = try await db.pool.read { try MissionRecord.fetchCount($0) }
    #expect(afterCount == beforeCount)
    let stored = try db.messages(threadId: thread.id).first { $0.id == messageId }?.proposal
    #expect(stored?.status == .pending)
    #expect(await provider.callCount == 0)
    await orchestrator.shutdown()
}

@Test func rateLimitTriggersGlobalCooldownThenRecovers() async throws {
    let db = try haltTempDB()
    let companion = try haltCompanion(db)
    let first = try db.createSingleCardMission(
        campName: "c", squadName: "s1", goal: "g",
        cardTitle: "t1", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    // 首个 provider 抛 429，之后的派发换成正常 Mock（按调用次数切换）
    let counter = CallCounter()
    let orchestrator = Orchestrator(
        db: db,
        makeProvider: { _ in
            if counter.next() == 0 {
                return RateLimitedProvider()
            }
            return MockProvider(script: completeScript())
        },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil,
        rateLimitCooldown: .milliseconds(400)
    )

    await orchestrator.reconcile()
    // 429 → 卡片按错误路径 blocked + 冷却事件
    let blocked = try await waitForCard(db, first.cardId, status: .blocked)
    #expect(blocked)
    // CardRunner 先持久化 blocked，Orchestrator 随后写 cooldown 事件并移除 running。
    // 等完整错误处理周期结束，避免用 card 状态替代 cooldown 事件的同步点。
    await orchestrator.waitUntilIdle()
    #expect(try globalEvents(db, kind: "rate_limit_cooldown") == 1)

    // 冷却期内：第二个行动不派发
    let second = try db.createSingleCardMission(
        campName: "c", squadName: "s2", goal: "g",
        cardTitle: "t2", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, workspacePath: nil
    )
    await orchestrator.reconcile()
    try await Task.sleep(for: .milliseconds(100))
    #expect(try db.runs(cardId: second.cardId).isEmpty)

    // 冷却过点：恢复派发
    try await Task.sleep(for: .milliseconds(400))
    await orchestrator.reconcile()
    let done = try await waitForCard(db, second.cardId, status: .done)
    #expect(done)
}

/// 线程安全的调用计数器（makeProvider 是 @Sendable 闭包）
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = count
        count += 1
        return current
    }
}
