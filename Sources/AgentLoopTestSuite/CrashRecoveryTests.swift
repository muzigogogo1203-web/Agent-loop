import Testing
import Foundation
import GRDB
import AgentLoopCore

private func recoveryTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func recoveryArtifactRoot() throws -> URL {
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "recovery-state-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: stateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let artifacts = stateRoot.appendingPathComponent("artifacts", isDirectory: true)
    try FileManager.default.createDirectory(
        at: artifacts,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    return artifacts
}

private func recoveryDoneTurn() -> TurnResult {
    TurnResult(
        content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
            "outcome": "完成",
            "summary": "续跑完成",
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])],
        stopReason: .toolUse
    )
}

/// 挂起的 provider：模拟正在真实执行中的卡（流不结束直到取消）。
private actor RecoveryHangingProvider: LLMProvider {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String, history: [APIMessage], tools: [ToolDef],
        toolChoice: ToolChoice, maxTokens: Int
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
        await withCheckedContinuation { waiters.append($0) }
    }

    private func markStarted() {
        started = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

// MARK: - 杀进程重启续跑（spec §16-M5 验收）

@Test func killRestartAdoptsOrphanAndResumesToDone() async throws {
    let db = try recoveryTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "断电的卡",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )

    // 模拟崩溃现场：卡 running + run 未收口（进程死掉，无人认领）
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    #expect(try db.card(id: ids.cardId)?.status == .running)

    // 「重启」：全新 Orchestrator（内存注册表为空）→ 启动恢复
    let orch = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: MockProvider(script: [recoveryDoneTurn()])
        ),
        makeProvider: { _, _ in MockProvider(script: [recoveryDoneTurn()]) },
        artifactStoreRoot: try recoveryArtifactRoot(),
        tickInterval: nil
    )
    await orch.recoverAndReconcile()
    try await orch.waitUntilIdle()

    // 续跑到 done；崩溃 run 标记 interrupted；领养事件带 crash_recovery
    #expect(try db.card(id: ids.cardId)?.status == .done)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(runs.contains { $0.outcome == "completed" })
    let events = try db.events(cardId: ids.cardId)
    #expect(events.contains {
        $0.kind == "card_interrupted" && $0.payloadJson.contains("crash_recovery")
    })
    await orch.shutdown()
}

@Test func adoptionSkipsCardsWithActiveRunners() async throws {
    let db = try recoveryTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "活着的卡",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )

    let hanging = RecoveryHangingProvider()
    let orch = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: hanging),
        makeProvider: { _, _ in hanging },
        artifactStoreRoot: try recoveryArtifactRoot(),
        tickInterval: nil
    )
    // 正常派发（活跑者在注册表里）
    await orch.reconcile()
    await hanging.waitUntilStarted()
    #expect(try db.card(id: ids.cardId)?.status == .running)

    // 再次启动恢复：不得误伤活跑者
    await orch.recoverAndReconcile()
    #expect(try db.card(id: ids.cardId)?.status == .running)
    let openRuns = try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }
    #expect(openRuns.count == 1) // run 仍未收口（没被标 interrupted）

    await orch.shutdown()
}

// MARK: - 提案自愈（M4 评审遗留的崩溃窗口）

@Test func startupHealsConfirmedProposalWithoutMission() async throws {
    let db = try recoveryTempDB()
    let camp = try db.ensureDefaultCamp()
    let thread = try db.findOrCreateGuideThread(campId: camp.id)

    func insert(_ status: SquadProposalBlock.Status, missionId: String?) throws -> String {
        var block = SquadProposalBlock(
            proposalId: UUID().uuidString, name: "队", memberIds: ["c1"],
            goal: "g", budget: nil, status: status)
        block.missionId = missionId
        return try db.appendChatMessage(
            threadId: thread.id, role: "guide", contentJson: try block.encodedString())
    }

    let orphaned = try insert(.confirmed, missionId: nil)      // 崩溃窗口遗留 → 应治愈
    let landed = try insert(.confirmed, missionId: "mi-ok")    // 正常已建队 → 不动
    let dismissed = try insert(.dismissed, missionId: nil)     // 已驳回 → 不动

    let healed = try db.healOrphanedConfirmedProposals()
    #expect(healed == [orphaned])

    let messages = try db.messages(threadId: thread.id)
    #expect(messages.first { $0.id == orphaned }?.proposal?.status == .pending)
    #expect(messages.first { $0.id == landed }?.proposal?.status == .confirmed)
    #expect(messages.first { $0.id == dismissed }?.proposal?.status == .dismissed)

    // 治愈后可正常重新确认（CAS 语义完整）
    _ = try db.confirmProposalBlock(messageId: orphaned)
}

// MARK: - 安全作用域书签（M5-1b）

@Test func workspaceBookmarkCaptureAndResolveRoundtrip() throws {
    let db = try recoveryTempDB()
    _ = try db.ensureDefaultCamp()
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

    // 建行动时捕获书签
    let missionId = try db.createMissionShell(
        goal: "g", companionIds: [], workspacePath: workspace.path)
    let squad = try #require(try db.squad(forMission: missionId))
    #expect(squad.workspaceBookmark != nil)

    // 书签解析回同一目录
    let resolved = WorkspaceScopedAccess(
        workspacePath: squad.workspacePath, bookmark: squad.workspaceBookmark)
    #expect(resolved.url?.standardizedFileURL.path == workspace.standardizedFileURL.path)
    resolved.stop()

    // 损坏书签 → path 兜底
    let corrupt = WorkspaceScopedAccess(
        workspacePath: workspace.path, bookmark: Data([0x00, 0x01, 0x02]))
    #expect(corrupt.url?.path == workspace.path)
    corrupt.stop()

    // 无书签 → path 兜底；无 path → nil
    #expect(WorkspaceScopedAccess(workspacePath: workspace.path, bookmark: nil).url?.path == workspace.path)
    #expect(WorkspaceScopedAccess(workspacePath: nil, bookmark: nil).url == nil)

    // 无工作目录的行动不捕获书签
    let bare = try db.createMissionShell(goal: "g2", companionIds: [], workspacePath: nil)
    #expect(try db.squad(forMission: bare)?.workspaceBookmark == nil)
}

private final class RecoveryMutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    private var nextReadObserver: (@Sendable () -> Void)?

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.lock()
        let current = value
        let observer = nextReadObserver
        nextReadObserver = nil
        lock.unlock()
        observer?()
        return current
    }

    func set(_ value: Date) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func observeNextRead(
        _ observer: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        nextReadObserver = observer
        lock.unlock()
    }
}

private actor RecoveryControlledSleeper {
    struct Request: Sendable, Equatable {
        let id: UUID
        let duration: Duration
    }

    private struct Entry {
        let duration: Duration
        let continuation: CheckedContinuation<Void, Error>
    }

    private struct Observer {
        let duration: Duration?
        let continuation: CheckedContinuation<Request, Never>
    }

    private var entries: [UUID: Entry] = [:]
    private var observed: Set<UUID> = []
    private var observers: [UUID: Observer] = [:]
    private var recordedDurations: [Duration] = []

    func sleep(_ duration: Duration) async throws {
        try Task.checkCancellation()
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                entries[id] = Entry(
                    duration: duration,
                    continuation: continuation
                )
                recordedDurations.append(duration)
                fulfillObservers()
            }
        } onCancel: {
            Task {
                await self.cancel(id)
            }
        }
    }

    func waitForRequest(
        duration: Duration? = nil
    ) async -> Request {
        if let request = nextUnobserved(duration: duration) {
            observed.insert(request.id)
            return request
        }
        let observerId = UUID()
        return await withCheckedContinuation { continuation in
            observers[observerId] = Observer(
                duration: duration,
                continuation: continuation
            )
        }
    }

    func succeed(_ request: Request) {
        guard let entry = entries.removeValue(forKey: request.id) else {
            return
        }
        entry.continuation.resume()
    }

    func durations() -> [Duration] {
        recordedDurations
    }

    private func cancel(_ id: UUID) {
        guard let entry = entries.removeValue(forKey: id) else {
            return
        }
        entry.continuation.resume(throwing: CancellationError())
    }

    private func nextUnobserved(
        duration: Duration?
    ) -> Request? {
        entries
            .filter { id, entry in
                !observed.contains(id)
                    && (duration == nil || entry.duration == duration)
            }
            .map { Request(id: $0.key, duration: $0.value.duration) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .first
    }

    private func fulfillObservers() {
        for observerId in observers.keys.sorted(
            by: { $0.uuidString < $1.uuidString }
        ) {
            guard let observer = observers[observerId],
                  let request = nextUnobserved(
                    duration: observer.duration
                  )
            else {
                continue
            }
            observed.insert(request.id)
            observers.removeValue(forKey: observerId)
            observer.continuation.resume(returning: request)
        }
    }
}

private actor RecoveryPlanningGate {
    private var starts = 0
    private var startWaiters:
        [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var released = false
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        starts += 1
        let ready = startWaiters.filter { starts >= $0.count }
        startWaiters.removeAll { starts >= $0.count }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }

    func waitUntilStarted(count: Int = 1) async {
        if starts >= count {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append((count, continuation))
        }
    }

    func waitForRelease() async {
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func startCount() -> Int {
        starts
    }
}

private final class RecoveryControlledPlanningProvider:
    LLMProvider, @unchecked Sendable
{
    let gate = RecoveryPlanningGate()

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                await self.gate.markStarted()
                await self.gate.waitForRelease()
                guard !Task.isCancelled else {
                    continuation.finish(throwing: CancellationError())
                    return
                }
                continuation.yield(.turn(recoveryPlanningTurn()))
                continuation.finish()
            }
            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
    }
}

private final class RecoveryIgnoringCancellationPlanningProvider:
    LLMProvider, @unchecked Sendable
{
    private let condition = NSCondition()
    private var released = false
    private let startedSignal = RecoveryAsyncFlag()

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        condition.lock()
        Task {
            await startedSignal.mark()
        }
        while !released {
            condition.wait()
        }
        condition.unlock()
        return AsyncThrowingStream { continuation in
                continuation.yield(.turn(recoveryPlanningTurn()))
                continuation.finish()
        }
    }

    func waitUntilStarted() async {
        await startedSignal.wait()
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }
}

private final class RecoveryProviderResolver:
    PlanningProviderResolver, @unchecked Sendable
{
    private let providers: [String: any LLMProvider]

    init(providers: [String: any LLMProvider]) {
        self.providers = providers
    }

    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider {
        guard let provider = providers[model] else {
            throw TestPlanningProviderResolverError.providerUnavailable
        }
        return provider
    }
}

private actor RecoveryAsyncFlag {
    private var marked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func mark() {
        marked = true
        let current = waiters
        waiters.removeAll()
        for waiter in current {
            waiter.resume()
        }
    }

    func wait() async {
        if marked {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func value() -> Bool {
        marked
    }
}

private actor RecoveryIdleCheckObservation {
    enum Event: Sendable, Equatable {
        case ledgerRead
        case completed
    }

    private var firstEvent: Event?
    private var waiters: [CheckedContinuation<Event, Never>] = []

    func record(_ event: Event) {
        guard firstEvent == nil else {
            return
        }
        firstEvent = event
        let current = waiters
        waiters.removeAll()
        for waiter in current {
            waiter.resume(returning: event)
        }
    }

    func waitForFirstEvent() async -> Event {
        if let firstEvent {
            return firstEvent
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

private struct RecoveryPlanningProbe {
    let missionId: String
    let workId: String
    let profileId: String
    let model: String
}

private func recoveryPlanningTurn() -> TurnResult {
    TurnResult(
        content: [
            .toolUse(
                id: UUID().uuidString,
                name: "propose_plan",
                input: [
                    "goalRefined": "恢复后交付",
                    "cards": [
                        [
                            "title": "恢复任务",
                            "description": "验证 durable supervisor",
                            "expectedOutput": "可验证结果",
                            "assignee": 0,
                            "dependsOn": [],
                        ],
                    ],
                ]
            ),
        ],
        stopReason: .toolUse,
        usage: Usage(inputTokens: 3, outputTokens: 5)
    )
}

private func recoveryPlanResult() -> PlanResult {
    PlanResult(
        proposal: PlanProposal(
            goalRefined: "恢复后交付",
            cards: [
                .init(
                    title: "恢复任务",
                    description: "验证 durable supervisor",
                    expectedOutput: "可验证结果",
                    assignee: 0,
                    dependsOn: []
                ),
            ]
        ),
        fallbackReason: nil,
        usage: Usage(inputTokens: 3, outputTokens: 5)
    )
}

private func enqueueRecoveryPlanningProbe(
    db: AppDatabase,
    resolver: any PlanningProviderResolver,
    command: String,
    model: String
) throws -> RecoveryPlanningProbe {
    let camp = try db.ensureDefaultCamp()
    let identity = try testPlanningCommandIdentity(
        db: db,
        command: command,
        model: model
    )
    var companion = CompanionRecord.new(
        name: "恢复伙伴-\(command)",
        color: "blue",
        rolePrompt: "执行恢复验证",
        model: model,
        campId: camp.id
    )
    companion.runtimeProfileId = identity.runtimeProfileId
    try db.saveCompanion(companion)
    let ids = try db.enqueueMissionPlanning(
        goal: "恢复验证-\(command)",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: 1_000,
        campId: camp.id,
        autonomy: .standard,
        planningInput: try PlanningWorkInput(
            plannerModel: model,
            runtimeProfileId: identity.runtimeProfileId
        ),
        idempotencyKey: identity.idempotencyKey,
        traceId: identity.traceId,
        planningProviderResolver: resolver
    )
    return RecoveryPlanningProbe(
        missionId: ids.missionId,
        workId: ids.workId,
        profileId: identity.runtimeProfileId,
        model: model
    )
}

private func recoverySupervisor(
    db: AppDatabase,
    resolver: any PlanningProviderResolver,
    workerId: String,
    clock: RecoveryMutableClock,
    sleeper: RecoveryControlledSleeper
) -> DurableWorkSupervisor {
    DurableWorkSupervisor(
        database: db,
        planningProviderResolver: resolver,
        workerId: workerId,
        now: { clock.now() },
        sleep: { duration in
            try await sleeper.sleep(duration)
        },
        onMissionChanged: { _ in }
    )
}

private func activateRecoverySupervisor(
    _ supervisor: DurableWorkSupervisor,
    profileId: String,
    model: String
) async throws {
    try await supervisor.recoverOnStartup(
        profileModels: [profileId: model]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
}

private func recoveryClaim(
    from work: DurableWorkRecord
) throws -> DurableWorkClaim {
    DurableWorkClaim(
        workId: work.id,
        attempt: work.attempt,
        workerId: try #require(work.leaseOwner),
        version: work.version,
        leaseExpiresAt: try #require(work.leaseExpiresAt)
    )
}

private func seedRecoveryRetry(
    db: AppDatabase,
    probe: RecoveryPlanningProbe,
    now: Date
) throws -> Date {
    let claim = try #require(
        try db.claimNextPlanning(
            workerId: "recovery-retry-seed",
            now: now,
            leaseDuration: 60
        )
    )
    #expect(claim.workId == probe.workId)
    let failure = try PlanningAttemptFailure(
        code: "temporary_recovery_failure",
        safeMessage: "temporary",
        disposition: .transient,
        usage: nil
    )
    switch try db.recordPlanningAttemptFailure(
        claim: claim,
        failure: failure,
        now: now
    ) {
    case let .retryScheduled(_, notBefore):
        return notBefore
    case .failed, .usageOverflow:
        throw InvalidDurableWorkStateError()
    }
}

@Test func leaseRenewalCompletionUsesLatestClaim() async throws {
    let db = try recoveryTempDB()
    let provider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["renew-latest": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "renew-latest",
        model: "renew-latest"
    )
    let clock = RecoveryMutableClock(
        Date(timeIntervalSinceReferenceDate: 1_000)
    )
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "renew-latest-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    await provider.gate.waitUntilStarted()

    let firstRenewal = await sleeper.waitForRequest(
        duration: .seconds(15)
    )
    clock.set(Date(timeIntervalSinceReferenceDate: 1_015))
    await sleeper.succeed(firstRenewal)
    _ = await sleeper.waitForRequest(duration: .seconds(15))

    await provider.gate.release()
    try await supervisor.waitUntilTerminal(workId: probe.workId)
    let work = try #require(
        try DurableWorkStore(database: db).work(id: probe.workId)
    )
    let renewedEvents = try await db.pool.read { database in
        try DurableWorkAttemptEventRecord
            .filter(
                Column("workId") == probe.workId
                    && Column("eventKind")
                        == DurableWorkAttemptEventKind.leaseRenewed.rawValue
            )
            .fetchCount(database)
    }
    #expect(work.state == .succeeded)
    #expect(renewedEvents == 1)
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

@Test func staleRenewCancelsOnlyMatchingOwnedTask() async throws {
    let db = try recoveryTempDB()
    let staleProvider = RecoveryControlledPlanningProvider()
    let survivorProvider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: [
            "stale-renew": staleProvider,
            "survivor-renew": survivorProvider,
        ]
    )
    let stale = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "stale-renew",
        model: "stale-renew"
    )
    let survivor = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "survivor-renew",
        model: "survivor-renew"
    )
    let clock = RecoveryMutableClock(
        Date(timeIntervalSinceReferenceDate: 2_000)
    )
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "two-renew-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: stale.profileId,
        model: stale.model
    )
    await staleProvider.gate.waitUntilStarted()
    await survivorProvider.gate.waitUntilStarted()
    let renewalA = await sleeper.waitForRequest(duration: .seconds(15))
    let renewalB = await sleeper.waitForRequest(duration: .seconds(15))

    let staleWork = try #require(
        try DurableWorkStore(database: db).work(id: stale.workId)
    )
    _ = try db.renewPlanningLease(
        claim: recoveryClaim(from: staleWork),
        now: Date(timeIntervalSinceReferenceDate: 2_001),
        leaseDuration: 60
    )
    clock.set(Date(timeIntervalSinceReferenceDate: 2_015))
    await sleeper.succeed(renewalA)
    await sleeper.succeed(renewalB)
    _ = await sleeper.waitForRequest(duration: .seconds(15))

    await staleProvider.gate.release()
    await survivorProvider.gate.release()
    try await supervisor.waitUntilTerminal(workId: survivor.workId)
    try await supervisor.waitUntilIdle()
    let staleAfter = try #require(
        try DurableWorkStore(database: db).work(id: stale.workId)
    )
    let survivorAfter = try #require(
        try DurableWorkStore(database: db).work(id: survivor.workId)
    )
    #expect(staleAfter.state == .running)
    #expect(survivorAfter.state == .succeeded)
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

@Test func supervisorNextDueTimerWakesRetryWithoutPolling() async throws {
    let db = try recoveryTempDB()
    let provider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["next-due": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "next-due",
        model: "next-due"
    )
    let start = Date(timeIntervalSinceReferenceDate: 3_000)
    let due = try seedRecoveryRetry(db: db, probe: probe, now: start)
    let clock = RecoveryMutableClock(start)
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "next-due-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    let dueRequest = await sleeper.waitForRequest()
    #expect(
        dueRequest.duration == .seconds(due.timeIntervalSince(start))
    )
    #expect(await provider.gate.startCount() == 0)
    #expect(await sleeper.durations() == [dueRequest.duration])

    clock.set(due)
    await sleeper.succeed(dueRequest)
    await provider.gate.waitUntilStarted()
    await provider.gate.release()
    try await supervisor.waitUntilTerminal(workId: probe.workId)
    #expect(
        try DurableWorkStore(database: db).work(id: probe.workId)?.state
            == .succeeded
    )
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

@Test func waitUntilIdleIgnoresFutureRetryButWaitUntilTerminalDoesNot()
    async throws
{
    let db = try recoveryTempDB()
    let provider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["future-retry": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "future-retry",
        model: "future-retry"
    )
    let start = Date(timeIntervalSinceReferenceDate: 4_000)
    let due = try seedRecoveryRetry(db: db, probe: probe, now: start)
    let clock = RecoveryMutableClock(start)
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "future-retry-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    let dueRequest = await sleeper.waitForRequest()
    try await supervisor.waitUntilIdle()

    let terminalCompleted = RecoveryAsyncFlag()
    let terminalTask = Task {
        try await supervisor.waitUntilTerminal(workId: probe.workId)
        await terminalCompleted.mark()
    }
    await Task.yield()
    #expect(await terminalCompleted.value() == false)

    clock.set(due)
    await sleeper.succeed(dueRequest)
    await provider.gate.waitUntilStarted()
    await provider.gate.release()
    try await terminalTask.value
    #expect(await terminalCompleted.value())
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

@Test
func suppressedWaitUntilIdleDistinguishesDueFutureRetryAndHaltedCleanup()
    async throws
{
    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["suppressed-due": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "suppressed-due",
            model: "suppressed-due"
        )
        let clock = RecoveryMutableClock(
            Date(timeIntervalSinceReferenceDate: 4_100)
        )
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "suppressed-due-worker",
            clock: clock,
            sleeper: sleeper
        )
        try await supervisor.recoverOnStartup(
            profileModels: [probe.profileId: probe.model]
        )
        #expect(await provider.gate.startCount() == 0)

        let observation = RecoveryIdleCheckObservation()
        let idleCompleted = RecoveryAsyncFlag()
        clock.observeNextRead {
            Task {
                await observation.record(.ledgerRead)
            }
        }
        let idleTask = Task {
            try await supervisor.waitUntilIdle()
            await idleCompleted.mark()
            await observation.record(.completed)
        }

        #expect(
            await observation.waitForFirstEvent() == .ledgerRead
        )
        #expect(await idleCompleted.value() == false)

        try await supervisor.activateAfterOrchestratorRecovery()
        await provider.gate.waitUntilStarted()
        #expect(await idleCompleted.value() == false)
        await provider.gate.release()
        try await supervisor.waitUntilTerminal(workId: probe.workId)
        try await idleTask.value
        #expect(await idleCompleted.value())
        #expect(
            try DurableWorkStore(database: db).work(id: probe.workId)?
                .state == .succeeded
        )
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }

    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["suppressed-future": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "suppressed-future",
            model: "suppressed-future"
        )
        let start = Date(timeIntervalSinceReferenceDate: 4_200)
        let due = try seedRecoveryRetry(
            db: db,
            probe: probe,
            now: start
        )
        #expect(due > start)
        let clock = RecoveryMutableClock(start)
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "suppressed-future-worker",
            clock: clock,
            sleeper: sleeper
        )
        try await supervisor.recoverOnStartup(
            profileModels: [probe.profileId: probe.model]
        )

        try await supervisor.waitUntilIdle()
        #expect(await provider.gate.startCount() == 0)
        #expect(await sleeper.durations().isEmpty)
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }

    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["restored-halted-idle": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "restored-halted-idle",
            model: "restored-halted-idle"
        )
        #expect(
            try db.transitionDispatchMode(
                from: .running,
                to: .halted
            )
        )
        let clock = RecoveryMutableClock(
            Date(timeIntervalSinceReferenceDate: 4_300)
        )
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "restored-halted-idle-worker",
            clock: clock,
            sleeper: sleeper
        )

        try await supervisor.recoverOnStartup(
            profileModels: [probe.profileId: probe.model]
        )
        try await supervisor.waitUntilIdle()
        #expect(try db.dispatchMode() == .halted)
        #expect(
            try DurableWorkStore(database: db).work(id: probe.workId)?
                .state == .canceled
        )
        #expect(await provider.gate.startCount() == 0)
        #expect(await sleeper.durations().isEmpty)
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }
}

#if DEBUG
@Test func terminalCommitStoreFailureRetainsOwnershipAndPendingProposal()
    async throws
{
    let db = try recoveryTempDB()
    let provider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["terminal-retain": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "terminal-retain",
        model: "terminal-retain"
    )
    let clock = RecoveryMutableClock(
        Date(timeIntervalSinceReferenceDate: 5_000)
    )
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "terminal-retain-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    await provider.gate.waitUntilStarted()
    let renewal = await sleeper.waitForRequest(duration: .seconds(15))
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_recovery_terminal_commit
            BEFORE UPDATE ON durable_work
            WHEN OLD.id = '\(probe.workId)'
              AND NEW.state = 'succeeded'
            BEGIN
              SELECT RAISE(ABORT, 'injected terminal failure');
            END
            """)
    }
    await #expect(throws: DatabaseError.self) {
        try await supervisor.injectOwnedSuccessProposalForTesting(
            workId: probe.workId,
            result: recoveryPlanResult()
        )
    }
    #expect(
        try DurableWorkStore(database: db).work(id: probe.workId)?.state
            == .running
    )
    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_recovery_terminal_commit")
    }
    clock.set(Date(timeIntervalSinceReferenceDate: 5_015))
    await sleeper.succeed(renewal)
    try await supervisor.waitUntilTerminal(workId: probe.workId)
    #expect(
        try DurableWorkStore(database: db).work(id: probe.workId)?.state
            == .succeeded
    )
    await provider.gate.release()
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

@Test func terminalPendingProposalRetriesOnlyAfterRenewOrExplicitKick()
    async throws
{
    let db = try recoveryTempDB()
    let provider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["terminal-kick": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "terminal-kick",
        model: "terminal-kick"
    )
    let clock = RecoveryMutableClock(
        Date(timeIntervalSinceReferenceDate: 6_000)
    )
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "terminal-kick-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    await provider.gate.waitUntilStarted()
    _ = await sleeper.waitForRequest(duration: .seconds(15))
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_recovery_terminal_kick
            BEFORE UPDATE ON durable_work
            WHEN OLD.id = '\(probe.workId)'
              AND NEW.state = 'succeeded'
            BEGIN
              SELECT RAISE(ABORT, 'injected terminal kick failure');
            END
            """)
    }
    await #expect(throws: DatabaseError.self) {
        try await supervisor.injectOwnedSuccessProposalForTesting(
            workId: probe.workId,
            result: recoveryPlanResult()
        )
    }
    try await db.pool.write {
        try $0.execute(sql: "DROP TRIGGER fail_recovery_terminal_kick")
    }
    await Task.yield()
    #expect(
        try DurableWorkStore(database: db).work(id: probe.workId)?.state
            == .running
    )
    #expect(await provider.gate.startCount() == 1)
    try await supervisor.kick()
    try await supervisor.waitUntilTerminal(workId: probe.workId)
    #expect(await provider.gate.startCount() == 1)
    await provider.gate.release()
    _ = await supervisor.shutdown(gracePeriod: .zero)
}
#endif

@Test func claimOrNextDueStoreFailureLatchesFatalAndWakesWaiters()
    async throws
{
    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["claim-fatal": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "claim-fatal",
            model: "claim-fatal"
        )
        let clock = RecoveryMutableClock(
            Date(timeIntervalSinceReferenceDate: 7_000)
        )
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "claim-fatal-worker",
            clock: clock,
            sleeper: sleeper
        )
        try await db.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER fail_recovery_claim
                BEFORE UPDATE ON durable_work
                WHEN OLD.id = '\(probe.workId)'
                  AND NEW.state = 'running'
                BEGIN
                  SELECT RAISE(ABORT, 'injected claim failure');
                END
                """)
        }
        try await supervisor.recoverOnStartup(
            profileModels: [probe.profileId: probe.model]
        )
        let waiterStarted = RecoveryAsyncFlag()
        let terminalWaiter = Task { () -> (any Error)? in
            await waiterStarted.mark()
            do {
                try await supervisor.waitUntilTerminal(
                    workId: probe.workId
                )
                return nil
            } catch {
                return error
            }
        }
        await waiterStarted.wait()
        await Task.yield()
        try await supervisor.activateAfterOrchestratorRecovery()
        let error = await terminalWaiter.value
        #expect(
            (error as? SupervisorFatalError)?.code == .storeFailure
        )
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }

    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["next-due-fatal": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "next-due-fatal",
            model: "next-due-fatal"
        )
        let start = Date(timeIntervalSinceReferenceDate: 7_100)
        _ = try seedRecoveryRetry(db: db, probe: probe, now: start)
        try await db.pool.write { database in
            try database.execute(
                sql: "UPDATE mission SET status = 'accepted' WHERE id = ?",
                arguments: [probe.missionId]
            )
        }
        let clock = RecoveryMutableClock(start)
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "next-due-fatal-worker",
            clock: clock,
            sleeper: sleeper
        )
        try await supervisor.recoverOnStartup(profileModels: [:])
        let waiterStarted = RecoveryAsyncFlag()
        let terminalWaiter = Task { () -> (any Error)? in
            await waiterStarted.mark()
            do {
                try await supervisor.waitUntilTerminal(
                    workId: probe.workId
                )
                return nil
            } catch {
                return error
            }
        }
        await waiterStarted.wait()
        await Task.yield()
        try await supervisor.activateAfterOrchestratorRecovery()
        let error = await terminalWaiter.value
        #expect(
            (error as? SupervisorFatalError)?.code == .invalidLifecycle
        )
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }
}

@Test func renewNonStaleFailureLatchesFatalWithoutDroppingLedgerOwnership()
    async throws
{
    let db = try recoveryTempDB()
    let provider = RecoveryControlledPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["renew-fatal": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "renew-fatal",
        model: "renew-fatal"
    )
    let clock = RecoveryMutableClock(
        Date(timeIntervalSinceReferenceDate: 8_000)
    )
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "renew-fatal-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    await provider.gate.waitUntilStarted()
    let before = try #require(
        try DurableWorkStore(database: db).work(id: probe.workId)
    )
    let renewal = await sleeper.waitForRequest(duration: .seconds(15))
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_recovery_renew
            BEFORE UPDATE ON durable_work
            WHEN OLD.id = '\(probe.workId)'
              AND NEW.leaseExpiresAt <> OLD.leaseExpiresAt
            BEGIN
              SELECT RAISE(ABORT, 'injected renew failure');
            END
            """)
    }
    let waiterStarted = RecoveryAsyncFlag()
    let waiter = Task { () -> (any Error)? in
        await waiterStarted.mark()
        do {
            try await supervisor.waitUntilTerminal(workId: probe.workId)
            return nil
        } catch {
            return error
        }
    }
    await waiterStarted.wait()
    await Task.yield()
    clock.set(Date(timeIntervalSinceReferenceDate: 8_015))
    await sleeper.succeed(renewal)
    let error = await waiter.value
    #expect((error as? SupervisorFatalError)?.code == .storeFailure)
    let after = try #require(
        try DurableWorkStore(database: db).work(id: probe.workId)
    )
    #expect(after.state == .running)
    #expect(after.leaseOwner == before.leaseOwner)
    #expect(after.version == before.version)
    await provider.gate.release()
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

@Test func staleClaimAndGenerationLosersDoNotLatchFatal() async throws {
    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["stale-loser": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "stale-loser",
            model: "stale-loser"
        )
        let clock = RecoveryMutableClock(
            Date(timeIntervalSinceReferenceDate: 9_000)
        )
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "stale-loser-worker",
            clock: clock,
            sleeper: sleeper
        )
        try await activateRecoverySupervisor(
            supervisor,
            profileId: probe.profileId,
            model: probe.model
        )
        await provider.gate.waitUntilStarted()
        let renewal = await sleeper.waitForRequest(duration: .seconds(15))
        let current = try #require(
            try DurableWorkStore(database: db).work(id: probe.workId)
        )
        _ = try db.renewPlanningLease(
            claim: recoveryClaim(from: current),
            now: Date(timeIntervalSinceReferenceDate: 9_001),
            leaseDuration: 60
        )
        clock.set(Date(timeIntervalSinceReferenceDate: 9_015))
        await sleeper.succeed(renewal)
        await provider.gate.release()
        try await supervisor.waitUntilIdle()
        try await supervisor.kick()
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }

    do {
        let db = try recoveryTempDB()
        let provider = RecoveryControlledPlanningProvider()
        let resolver = RecoveryProviderResolver(
            providers: ["generation-loser": provider]
        )
        let probe = try enqueueRecoveryPlanningProbe(
            db: db,
            resolver: resolver,
            command: "generation-loser",
            model: "generation-loser"
        )
        let clock = RecoveryMutableClock(
            Date(timeIntervalSinceReferenceDate: 9_100)
        )
        let sleeper = RecoveryControlledSleeper()
        let supervisor = recoverySupervisor(
            db: db,
            resolver: resolver,
            workerId: "generation-loser-worker",
            clock: clock,
            sleeper: sleeper
        )
        try await activateRecoverySupervisor(
            supervisor,
            profileId: probe.profileId,
            model: probe.model
        )
        await provider.gate.waitUntilStarted()
        try await supervisor.suppressForEmergencyStop()
        _ = try db.transitionDispatchMode(from: .running, to: .halted)
        let missionIds = try db.cancelAllPlanningForEmergencyHalt(
            reason: "emergency_halt_during_planning",
            now: clock.now()
        )
        try await supervisor.didCommitEmergencyPlanningCleanup(
            missionIds: missionIds
        )
        await provider.gate.release()
        try await supervisor.waitUntilIdle()
        do {
            try await supervisor.kick()
            Issue.record("suppressed supervisor must reject kick")
        } catch is SupervisorDispatchSuppressedError {
        } catch let fatal as SupervisorFatalError {
            Issue.record("generation loser latched fatal: \(fatal.code)")
        }
        _ = await supervisor.shutdown(gracePeriod: .zero)
    }
}

@Test func terminalWaiterReturnsAfterDurableCancelWhileIdleWaitsForProviderExit()
    async throws
{
    let db = try recoveryTempDB()
    let provider = RecoveryIgnoringCancellationPlanningProvider()
    let resolver = RecoveryProviderResolver(
        providers: ["cancel-waiters": provider]
    )
    let probe = try enqueueRecoveryPlanningProbe(
        db: db,
        resolver: resolver,
        command: "cancel-waiters",
        model: "cancel-waiters"
    )
    let clock = RecoveryMutableClock(
        Date(timeIntervalSinceReferenceDate: 10_000)
    )
    let sleeper = RecoveryControlledSleeper()
    let supervisor = recoverySupervisor(
        db: db,
        resolver: resolver,
        workerId: "cancel-waiters-worker",
        clock: clock,
        sleeper: sleeper
    )
    try await activateRecoverySupervisor(
        supervisor,
        profileId: probe.profileId,
        model: probe.model
    )
    await provider.waitUntilStarted()

    let terminalCompleted = RecoveryAsyncFlag()
    let idleCompleted = RecoveryAsyncFlag()
    let terminalTask = Task {
        try await supervisor.waitUntilTerminal(workId: probe.workId)
        await terminalCompleted.mark()
    }
    let idleTask = Task {
        try await supervisor.waitUntilIdle()
        await idleCompleted.mark()
    }
    await Task.yield()
    try await supervisor.cancelPlanning(
        missionId: probe.missionId,
        reason: "test_cancel"
    )
    try await terminalTask.value
    #expect(await terminalCompleted.value())
    #expect(await idleCompleted.value() == false)

    provider.release()
    try await idleTask.value
    #expect(await idleCompleted.value())
    _ = await supervisor.shutdown(gracePeriod: .zero)
}

// MARK: - P1-F1 kernel-owned engine recovery

private func p1f1RecoveryMarkStarted(
    fixture: P1F1EngineFixture,
    request: EngineExecutionRequest,
    command: String
) throws {
    let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: request.executionId,
        expectedVersion: row["version"],
        requestHash: request.requestHash,
        commandIdempotencyKey: command,
        now: p1f1EngineTestNow.addingTimeInterval(1)
    )
}

private func p1f1RecoveryCancel(
    fixture: P1F1EngineFixture,
    request: EngineExecutionRequest,
    reason: String = "user_cancel"
) throws {
    _ = try fixture.store.requestCancellation(
        executionId: request.executionId,
        reason: reason,
        now: p1f1EngineTestNow.addingTimeInterval(2)
    )
}

private func p1f1RecoveryRowState(
    fixture: P1F1EngineFixture,
    request: EngineExecutionRequest
) throws -> (String, String, String?) {
    let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
    return (
        row["state"],
        row["dispatchState"],
        row["terminalSubtype"]
    )
}

@Test func p1f1_042RecoveryPrecedenceAndFourDispatchCrashWindows() throws {
    // 1. An active Camp with a pending zero-artifact proposal can commit the
    // exact durable proposal locally; recovery does not invent another one.
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-pending-active")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-pending-active-dispatch"
        )
        let pending = try fixture.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(
                request: request,
                key: "p1f1-recovery-pending-active-terminal"
            )
        )
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.scannedCount == 1)
        #expect(summary.directives.isEmpty)
        #expect(summary.terminalReceipts.count == 1)
        #expect(summary.terminalReceipts.first?.proposalId == pending.proposal.id)
        #expect(try p1f1RecoveryRowState(fixture: fixture, request: request).0 == "completed")
    }

    // 2. Camp deletion takes precedence over normal proposal preparation or
    // commit. F2 owns the specialized supersession.
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-pending-deletion")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-pending-deletion-dispatch"
        )
        let pending = try fixture.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(
                request: request,
                key: "p1f1-recovery-pending-deletion-terminal"
            )
        )
        try fixture.db.pool.write { database in
            try database.execute(
                sql: "UPDATE engine_terminal_proposal SET proposalJson='not-json' WHERE id=?",
                arguments: [pending.proposal.id]
            )
            try database.execute(
                sql: "UPDATE engine_execution SET requestJson='not-json' WHERE id=?",
                arguments: [request.executionId]
            )
            try database.execute(
                sql: """
                    UPDATE camp_lifecycle
                    SET state='deletionRequested',version=version+1,
                        updatedAt=?,deletionRequestedAt=?
                    WHERE campId=?
                    """,
                arguments: [
                    p1f1EngineTestNow.addingTimeInterval(5),
                    p1f1EngineTestNow.addingTimeInterval(5),
                    p1f1EngineCampID,
                ]
            )
        }
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.terminalReceipts.isEmpty)
        #expect(summary.directives.map(\.action) == [
            .deferCampDeletion(proposalId: pending.proposal.id),
        ])
        #expect(try fixture.db.pool.read { database in
            try String.fetchOne(
                database,
                sql: "SELECT state FROM engine_terminal_proposal WHERE id=?",
                arguments: [pending.proposal.id]
            )
        } == "pending")
        #expect(try p1f1RecoveryRowState(fixture: fixture, request: request).0 == "running")
    }

    // 2b. Deletion is lifecycle-first even without a proposal; deleting
    // carries only IDs, archived fails read-only, and tombstones are no-write.
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-deleting-no-proposal")
        try fixture.db.pool.write { database in
            try database.execute(
                sql: "UPDATE engine_execution SET requestJson='not-json' WHERE id=?",
                arguments: [request.executionId]
            )
        }
        try p1f1ApplyCampFence(.deleting, fixture: fixture)
        let stable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.terminalReceipts.isEmpty)
        #expect(summary.directives.map(\.action) == [
            .deferCampDeletion(proposalId: nil),
        ])
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == stable)
    }
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-legacy-archived")
        try p1f1ApplyCampFence(.legacyArchived, fixture: fixture)
        let stable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        #expect(throws: CampLifecycleWriteAuthorizationError.legacyArchived) {
            _ = try fixture.store.recoverInterruptedEngineExecutions(
                missionId: nil,
                now: p1f1EngineTestNow.addingTimeInterval(10)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == stable)
    }
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-tombstone")
        try fixture.db.pool.write { database in
            try database.execute(
                sql: "UPDATE engine_execution SET requestJson='not-json' WHERE id=?",
                arguments: [request.executionId]
            )
        }
        try p1f1ApplyCampFence(.deletedTombstone, fixture: fixture)
        let stable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.directives.isEmpty)
        #expect(summary.terminalReceipts.isEmpty)
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == stable)
    }

    // 3. A persisted CLI selection with a requested cancellation must surface
    // cancel-and-reconcile even when it is nonreplayable. The coordinator,
    // not this Store scan, owns the captured process-driver cleanup evidence.
    do {
        let fixture = try P1F1EngineFixture(replayClass: .nonReplayable)
        let request = try fixture.begin(key: "p1f1-recovery-nonreplayable")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-nonreplayable-dispatch"
        )
        try p1f1RecoveryCancel(fixture: fixture, request: request)
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.terminalReceipts.isEmpty)
        #expect(summary.directives.map(\.action) == [.cancelAndReconcile])
        #expect(try p1f1RecoveryRowState(fixture: fixture, request: request) == (
            "running", "started", nil
        ))
    }

    // 4. A canceled prepared execution proves the adapter was never called and
    // is the only cancellation branch recovery may terminalize immediately.
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-cancel-prepared")
        try p1f1RecoveryCancel(fixture: fixture, request: request)
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.directives.isEmpty)
        #expect(summary.terminalReceipts.first?.terminalKind == .canceled)
        #expect(try fixture.db.card(id: p1f1EngineCardID)?.status == .ready)
        #expect(try p1f1RecoveryRowState(fixture: fixture, request: request).0 == "canceled")
        _ = try p1f1AssertSyntheticTerminalGraph(
            fixture: fixture,
            request: request,
            terminalKey: "engine.recovery.cancel-prepared.v1:\(request.executionId)",
            expectedSequence: 0,
            expectedKind: .canceled,
            expectedSubtype: nil,
            expectedReasonCode: "user_cancel",
            expectedDetail: "engine execution canceled before dispatch",
            attention: false,
            receipt: summary.terminalReceipts.first
        )
    }

    // 5. Once dispatch started, replayable cancellation requires adapter
    // reconciliation evidence; a local request alone cannot become canceled.
    do {
        let fixture = try P1F1EngineFixture(replayClass: .idempotencyKeyed)
        let request = try fixture.begin(key: "p1f1-recovery-cancel-started")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-cancel-started-dispatch"
        )
        try p1f1RecoveryCancel(fixture: fixture, request: request)
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.terminalReceipts.isEmpty)
        #expect(summary.directives.map(\.action) == [.cancelAndReconcile])
        #expect(try p1f1RecoveryRowState(fixture: fixture, request: request).0 == "running")
    }

    // 6 / crash window one: pre-CAS is durably prepared and may start the exact
    // persisted request for the first time.
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-window-pre-cas")
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.directives.count == 1)
        #expect(summary.directives.first?.executionId == request.executionId)
        #expect(summary.directives.first?.request?.requestHash == request.requestHash)
        #expect(summary.directives.first?.action == .startPrepared)
        #expect(summary.terminalReceipts.isEmpty)
    }

    // 8 / crash windows two and three: post-CAS/pre-call and
    // post-call/pre-event have the same durable state. Both require exact-key
    // replay; neither has a persisted field that guesses success/no-effect.
    for key in [
        "p1f1-recovery-window-post-cas",
        "p1f1-recovery-window-post-call",
    ] {
        let fixture = try P1F1EngineFixture(replayClass: .replaySafe)
        let request = try fixture.begin(key: key)
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "\(key)-dispatch"
        )
        let before = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((before["state"] as String) == "running")
        #expect((before["terminalReceiptHash"] as String?) == nil)
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.directives.map(\.action) == [.replayExecution])
        #expect(summary.terminalReceipts.isEmpty)
        let after = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((after["state"] as String) == "running")
        #expect((after["terminalReceiptHash"] as String?) == nil)
        #expect((after["dispatchState"] as String) == "started")
    }

    // 8b. A persisted kernel-owned proposal command without its terminal
    // command is an R-only append-only graph. Recovery must fail closed and
    // must never convert it into a different protocol-error terminal.
    do {
        let fixture = try P1F1EngineFixture(replayClass: .nonReplayable)
        let request = try fixture.begin(key: "p1f1-recovery-r-only")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-r-only-dispatch"
        )
        let terminalKey =
            "engine.recovery.external-effect-unknown.v1:\(request.executionId)"
        _ = try fixture.store.recordEngineTerminalProposal(
            EngineTerminalProposalContentV1(
                protocolVersion: engineExecutionProtocolVersionV1,
                executionId: request.executionId,
                runId: request.runId,
                cardId: request.cardId,
                sequence: 0,
                terminalIdempotencyKey: terminalKey,
                terminalKind: .blocked,
                terminalSubtype: .externalEffectUnknown,
                payload: .blocked(
                    reasonCode: "external_effect_unknown",
                    detail: "non-replayable dispatch outcome is unknown"
                ),
                artifacts: []
            )
        )
        // Public adapter proposal recording consumes its accepted sequence.
        // Reset only that projection field to reproduce the exact synthetic
        // R projection, whose kernel path deliberately consumes no sequence.
        try fixture.db.pool.write { database in
            try database.execute(
                sql: "UPDATE engine_execution SET nextSequence=0 WHERE id=?",
                arguments: [request.executionId]
            )
        }
        let stable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try fixture.store.recoverInterruptedEngineExecutions(
                missionId: nil,
                now: p1f1EngineTestNow.addingTimeInterval(10)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == stable)
    }

    // 8c. R and C are one outer transaction. A deterministic failure at the
    // C projection must roll the proposal, receipt, event, scope, and outbox
    // written by R back together.
    do {
        let fixture = try P1F1EngineFixture(replayClass: .nonReplayable)
        let request = try fixture.begin(key: "p1f1-recovery-synthetic-c-abort")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-synthetic-c-abort-dispatch"
        )
        try fixture.db.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER p1f1_abort_synthetic_terminal_c
                BEFORE UPDATE ON engine_execution
                WHEN OLD.state='running' AND NEW.state<>'running'
                BEGIN
                  SELECT RAISE(ABORT, 'p1f1 injected synthetic C failure');
                END
                """)
        }
        let stable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        #expect(throws: DatabaseError.self) {
            _ = try fixture.store.recoverInterruptedEngineExecutions(
                missionId: nil,
                now: p1f1EngineTestNow.addingTimeInterval(10)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == stable)
    }

    // 7 / crash window four: an exact committed bind is resumable only by its
    // exact durable external session ID.
    do {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-recovery-window-session")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-window-session-dispatch"
        )
        let sessionStore = EngineSessionStore(
            sessionIdFactory: { fixture.ids.next("session") }
        )
        let session = try fixture.db.pool.write { database in
            try sessionStore.bindOrReplay(
                execution: try #require(
                    try EngineExecutionRecord.fetchOne(
                        database,
                        key: request.executionId
                    )
                ),
                externalSessionId: "codex-thread-recovery",
                database: database,
                now: p1f1EngineTestNow.addingTimeInterval(2)
            )
        }
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.directives.map(\.action) == [
            .resumeSession(
                sessionId: session.id,
                externalSessionId: "codex-thread-recovery"
            ),
        ])
        #expect(summary.terminalReceipts.isEmpty)
    }

    // 9. Descriptor/row replay-class drift is a protocol error, never a
    // permissive replay-class substitution.
    do {
        let fixture = try P1F1EngineFixture(replayClass: .replaySafe)
        let request = try fixture.begin(key: "p1f1-recovery-descriptor-drift")
        try p1f1RecoveryMarkStarted(
            fixture: fixture,
            request: request,
            command: "p1f1-recovery-descriptor-drift-dispatch"
        )
        try p1f1RecoveryCancel(
            fixture: fixture,
            request: request,
            reason: "must_not_override_descriptor_failure"
        )
        try fixture.db.pool.write { database in
            try database.execute(
                sql: "UPDATE engine_execution SET replayClass='idempotencyKeyed' WHERE id=?",
                arguments: [request.executionId]
            )
        }
        let summary = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(summary.directives.isEmpty)
        #expect(summary.terminalReceipts.count == 1)
        #expect(summary.terminalReceipts.first?.terminalKind == .blocked)
        #expect(summary.terminalReceipts.first?.terminalSubtype == .engineProtocolError)
        #expect(try p1f1RecoveryRowState(fixture: fixture, request: request) == (
            "blocked", "terminal", "engineProtocolError"
        ))
        _ = try p1f1AssertSyntheticTerminalGraph(
            fixture: fixture,
            request: request,
            terminalKey: "engine.recovery.protocol-error.v1:\(request.executionId)",
            expectedSequence: 0,
            expectedKind: .blocked,
            expectedSubtype: .engineProtocolError,
            expectedReasonCode: "engine_protocol_error",
            expectedDetail: "persisted engine recovery identity mismatch",
            attention: true,
            receipt: summary.terminalReceipts.first
        )
    }

    // 10. Mission filtering is part of the Store snapshot. A canonical target
    // sees only executions joined through Cards in that Mission, nil sees all,
    // and an invalid identity fails before either execution can be changed.
    do {
        let fixture = try P1F1EngineFixture()
        let otherMissionID = "00000000-0000-4000-8000-000000000142"
        let otherCardID = "00000000-0000-4000-8000-000000000143"
        try fixture.db.pool.write { database in
            try MissionRecord(
                id: otherMissionID,
                squadId: "p1f1-engine-squad",
                goalRaw: "other mission",
                goalRefined: "other mission",
                status: .executing,
                budgetTokens: 50_000,
                spentTokens: 0,
                revision: 1,
                createdAt: p1f1EngineTestNow
            ).insert(database)
            try CardRecord(
                id: otherCardID,
                missionId: otherMissionID,
                idemKey: "p1f1-recovery-other-mission-card",
                title: "Other engine card",
                descriptionText: "must remain isolated",
                expectedOutput: "unchanged sibling",
                assigneeId: nil,
                status: .ready,
                blockedReasonJson: nil,
                dependsOnJson: "[]",
                handoffJson: nil,
                stage: 1,
                maxTurns: 8,
                tokenBudget: 10_000,
                createdAt: p1f1EngineTestNow
            ).insert(database)
        }
        let target = try fixture.begin(key: "p1f1-recovery-filter-target")
        let baseContext = try CanonicalContractCodingV1.decode(
            EngineContextEnvelopeV1.self,
            from: Data(p1f1ContextGolden.utf8)
        )
        let siblingReferences = try EngineContextReferencesV1(
            inputRefs: baseContext.inputRefs,
            memoryRefs: baseContext.memoryRefs,
            resourceRefs: baseContext.resourceRefs,
            priorHandoffRefs: baseContext.priorHandoffRefs,
            instructionBlocks: baseContext.instructionBlocks
        )
        let siblingPacket = ContextPacket(
            companionName: "Recovery sibling",
            rolePrompt: "Preserve mission filtering.",
            cardTitle: "Other engine card",
            cardDescription: "must remain isolated",
            expectedOutput: "unchanged sibling",
            workspacePath: nil,
            upstreamHandoffs: [],
            toolNames: [],
            engineContextReferences: siblingReferences
        )
        let siblingContext = try EngineContextEnvelopeV1.from(
            packet: siblingPacket,
            scope: EngineContextScopeV1(
                campId: p1f1EngineCampID,
                goalId: p1f1EngineGoalID,
                missionId: otherMissionID,
                cardId: otherCardID,
                outcomeContract: baseContext.outcomeContract
            )
        )
        let siblingContextBytes = try CanonicalJSONV1.encode(siblingContext)
        let sibling = try fixture.begin(
            key: "p1f1-recovery-filter-sibling",
            fields: fixture.fields(
                cardID: otherCardID,
                contextJson: String(
                    decoding: siblingContextBytes,
                    as: UTF8.self
                ),
                contextHash: CanonicalJSONV1.sha256Hex(
                    siblingContextBytes
                )
            )
        )
        let targetBefore = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: target.executionId,
            runID: target.runId
        )
        let siblingBefore = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: sibling.executionId,
            runID: sibling.runId
        )

        #expect(throws: EngineDispatchConflictErrorV1.self) {
            _ = try fixture.store.recoverInterruptedEngineExecutions(
                missionId: "not-a-canonical-mission",
                now: p1f1EngineTestNow.addingTimeInterval(10)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: target.executionId,
            runID: target.runId
        ) == targetBefore)
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: sibling.executionId,
            runID: sibling.runId
        ) == siblingBefore)

        let scoped = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: p1f1EngineMissionID,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(scoped.scannedCount == 1)
        #expect(scoped.terminalReceipts.isEmpty)
        #expect(scoped.directives.map(\.executionId) == [target.executionId])
        #expect(scoped.directives.map(\.action) == [.startPrepared])
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: sibling.executionId,
            runID: sibling.runId
        ) == siblingBefore)

        let all = try fixture.store.recoverInterruptedEngineExecutions(
            missionId: nil,
            now: p1f1EngineTestNow.addingTimeInterval(10)
        )
        #expect(all.scannedCount == 2)
        #expect(Set(all.directives.map(\.executionId)) == [
            target.executionId, sibling.executionId,
        ])
    }
}
