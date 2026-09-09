import Testing
import Foundation
import Darwin
import GRDB
import AgentLoopCore

enum TestPlanningProviderResolverError: Error, Sendable, Equatable {
    case unexpectedProfile(expected: String, actual: String)
    case unexpectedModel(expected: String, actual: String)
    case providerUnavailable
}

struct TestPlanningProviderResolver: PlanningProviderResolver, Sendable {
    private let resolveBody:
        @Sendable (String, String) throws -> any LLMProvider

    init(provider: any LLMProvider) {
        self.resolveBody = { _, _ in provider }
    }

    init(
        profileId: String,
        model: String,
        provider: any LLMProvider
    ) {
        self.resolveBody = { actualProfileId, actualModel in
            guard actualProfileId == profileId else {
                throw TestPlanningProviderResolverError.unexpectedProfile(
                    expected: profileId,
                    actual: actualProfileId
                )
            }
            guard actualModel == model else {
                throw TestPlanningProviderResolverError.unexpectedModel(
                    expected: model,
                    actual: actualModel
                )
            }
            return provider
        }
    }

    init(
        resolve: @escaping @Sendable (
            _ profileId: String,
            _ model: String
        ) throws -> any LLMProvider
    ) {
        self.resolveBody = resolve
    }

    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider {
        try resolveBody(profileId, model)
    }
}

struct TestPlanningCommandIdentity: Sendable, Equatable {
    let runtimeProfileId: String
    let plannerModel: String
    let idempotencyKey: String
    let traceId: String
}

@discardableResult
func seedTestPlanningProfile(
    _ db: AppDatabase,
    profileId: String = "test-planning-profile"
) throws -> RuntimeProfileRecord {
    if let existing = try db.runtimeProfile(id: profileId) {
        guard !existing.kind.isCLI else {
            throw TestPlanningProviderResolverError.providerUnavailable
        }
        return existing
    }
    let profile = RuntimeProfileRecord(
        id: profileId,
        kind: .openAIAPI,
        name: "Test Planning",
        baseURL: "https://api.openai.com",
        credentialAccount: "test-planning-credential",
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 1)
    )
    try db.saveRuntimeProfile(profile)
    return profile
}

func testPlanningCommandIdentity(
    db: AppDatabase,
    command: String,
    model: String,
    profileId: String = "test-planning-profile"
) throws -> TestPlanningCommandIdentity {
    _ = try seedTestPlanningProfile(db, profileId: profileId)
    return TestPlanningCommandIdentity(
        runtimeProfileId: profileId,
        plannerModel: model,
        idempotencyKey: "test-planning:\(command):v1",
        traceId: "test-planning-trace:\(command):v1"
    )
}

func testPlanningRuntimeSelection(
    db: AppDatabase,
    model: String,
    profileId: String = "test-planning-profile"
) throws -> PlanningEntryRuntimeSelection {
    _ = try seedTestPlanningProfile(db, profileId: profileId)
    return PlanningEntryRuntimeSelection(
        runtimeProfileId: profileId,
        plannerModel: model
    )
}

private struct A1bRecoveryFixture {
    let database: AppDatabase
    let camp: CampRecord
    let companion: CompanionRecord
    let profile: RuntimeProfileRecord
    let model: String
}

private func makeA1bRecoveryFixture(
    suffix: String
) throws -> A1bRecoveryFixture {
    let database = try orchestratorTempDB()
    let camp = try database.ensureDefaultCamp()
    let profile = try seedTestPlanningProfile(
        database,
        profileId: "a1b-recovery-profile-\(suffix)"
    )
    var companion = CompanionRecord.new(
        name: "恢复伙伴-\(suffix)",
        color: "blue",
        rolePrompt: "把目标拆成可验证卡片",
        model: "a1b-recovery-model",
        campId: camp.id
    )
    companion.runtimeProfileId = profile.id
    try database.saveCompanion(companion)
    return A1bRecoveryFixture(
        database: database,
        camp: camp,
        companion: companion,
        profile: profile,
        model: "a1b-recovery-model"
    )
}

private func enqueueA1bRecoveryPlanning(
    _ fixture: A1bRecoveryFixture,
    suffix: String,
    resolver: any PlanningProviderResolver
) throws -> (missionId: String, workId: String) {
    try fixture.database.enqueueMissionPlanning(
        goal: "恢复规划-\(suffix)",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        budgetTokens: 1_000,
        campId: fixture.camp.id,
        autonomy: .standard,
        planningInput: try PlanningWorkInput(
            plannerModel: fixture.model,
            runtimeProfileId: fixture.profile.id
        ),
        idempotencyKey: "a1b-recovery:\(suffix):v1",
        traceId: "a1b-recovery-trace:\(suffix):v1",
        planningProviderResolver: resolver
    )
}

private func a1bRecoveryPlanTurn(
    suffix: String
) -> TurnResult {
    TurnResult(
        content: [
            .toolUse(
                id: "a1b-plan-\(suffix)",
                name: "propose_plan",
                input: [
                    "goalRefined": .string("恢复后完成-\(suffix)"),
                    "cards": .array([
                        .object([
                            "title": .string("执行-\(suffix)"),
                            "description": .string(
                                "执行恢复后的规划"
                            ),
                            "expectedOutput": .string("可验证结果"),
                            "assignee": .number(0),
                            "dependsOn": .array([]),
                        ]),
                    ]),
                ]
            ),
        ],
        stopReason: .toolUse
    )
}

private final class A1bBlockingPlanProvider:
    LLMProvider, @unchecked Sendable
{
    private let condition = NSCondition()
    private var started = 0
    private var returned = 0
    private var released = false
    private var startWaiters:
        [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var returnWaiters:
        [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private let turn: TurnResult

    init(suffix: String) {
        self.turn = a1bRecoveryPlanTurn(suffix: suffix)
    }

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        condition.lock()
        started += 1
        let readyStartWaiters = startWaiters.filter {
            started >= $0.count
        }
        startWaiters.removeAll { started >= $0.count }
        condition.broadcast()
        condition.unlock()
        for waiter in readyStartWaiters {
            waiter.continuation.resume()
        }

        condition.lock()
        while !released {
            condition.wait()
        }
        returned += 1
        let readyReturnWaiters = returnWaiters.filter {
            returned >= $0.count
        }
        returnWaiters.removeAll { returned >= $0.count }
        condition.unlock()
        for waiter in readyReturnWaiters {
            waiter.continuation.resume()
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(.turn(turn))
            continuation.finish()
        }
    }

    func waitUntilStarted(_ count: Int = 1) async {
        await withCheckedContinuation { continuation in
            condition.lock()
            if started >= count {
                condition.unlock()
                continuation.resume()
            } else {
                startWaiters.append((count, continuation))
                condition.unlock()
            }
        }
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }

    func waitUntilReturned(_ count: Int = 1) async {
        await withCheckedContinuation { continuation in
            condition.lock()
            if returned >= count {
                condition.unlock()
                continuation.resume()
            } else {
                returnWaiters.append((count, continuation))
                condition.unlock()
            }
        }
    }

    var callCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return started
    }

    var returnCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return returned
    }
}

private func a1bPlanningEventCount(
    _ database: AppDatabase,
    missionId: String,
    kind: String
) throws -> Int {
    try database.events(missionId: missionId)
        .filter { $0.kind == kind }
        .count
}

private func makeA1bSupervisor(
    _ fixture: A1bRecoveryFixture,
    resolver: any PlanningProviderResolver,
    workerId: String,
    now: Date
) -> DurableWorkSupervisor {
    DurableWorkSupervisor(
        database: fixture.database,
        planningProviderResolver: resolver,
        workerId: workerId,
        now: { now },
        sleep: { duration in
            try await Task<Never, Never>.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )
}

// Legacy split-write helpers live only in the test target. Production planning
// must enter through the durable enqueue/claim/terminal pipeline.
extension AppDatabase {
    func createMissionShell(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int = KernelDefaults.missionBudget,
        campId: String? = nil,
        autonomy: MissionAutonomy = .standard
    ) throws -> String {
        let camp: CampRecord
        if let campId {
            guard let existing = try self.camp(id: campId) else {
                throw RecordNotFoundError(table: "camp", id: campId)
            }
            guard !existing.archived else {
                throw CampArchivedError(campId: campId)
            }
            camp = existing
        } else {
            camp = try ensureDefaultCamp()
        }

        return try pool.write { database in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let memberIdsData = try encoder.encode(companionIds)
            guard let memberIdsJson = String(
                data: memberIdsData,
                encoding: .utf8
            ) else {
                throw EncodingError.invalidValue(
                    companionIds,
                    .init(
                        codingPath: [],
                        debugDescription: "UTF-8 encoding failed"
                    )
                )
            }
            let firstLine =
                goal.split(whereSeparator: \.isNewline).first
                    .map(String.init) ?? goal
            let squad = SquadRecord(
                id: UUID().uuidString,
                campId: camp.id,
                name: String(firstLine.prefix(30)),
                memberIdsJson: memberIdsJson,
                workspacePath: workspacePath,
                workspaceBookmark:
                    WorkspaceScopedAccess.captureBookmark(
                        forPath: workspacePath
                    ),
                createdAt: Date()
            )
            try squad.insert(database)

            let mission = MissionRecord(
                id: UUID().uuidString,
                squadId: squad.id,
                goalRaw: goal,
                goalRefined: "",
                status: .planning,
                budgetTokens: max(1, budgetTokens),
                spentTokens: 0,
                revision: 1,
                autonomy: autonomy,
                createdAt: Date()
            )
            try mission.insert(database)
            try AppDatabase.appendEvent(
                database,
                missionId: mission.id,
                cardId: nil,
                runId: nil,
                kind: EventKind.missionCreated,
                payload: ["goal": .string(goal)]
            )
            try AppDatabase.appendEvent(
                database,
                missionId: mission.id,
                cardId: nil,
                runId: nil,
                kind: EventKind.planStarted,
                payload: .object([:])
            )
            return mission.id
        }
    }

    func recordPlanFallback(
        missionId: String,
        reason: String
    ) throws {
        try pool.write { database in
            try AppDatabase.appendEvent(
                database,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.planFallback,
                payload: ["reason": .string(reason)]
            )
        }
    }

    func planMission(
        missionId: String,
        goalRefined: String,
        drafts: [PlanProposal.CardDraft]
    ) throws {
        try pool.write { database in
            guard var mission = try MissionRecord.fetchOne(
                database,
                key: missionId
            ) else {
                throw RecordNotFoundError(
                    table: "mission",
                    id: missionId
                )
            }
            let existingCount = try CardRecord
                .filter(Column("missionId") == missionId)
                .fetchCount(database)
            if existingCount > 0 {
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.planNoop,
                    payload: ["reason": "cards_exist"]
                )
                return
            }
            guard mission.status == .planning else {
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.planNoop,
                    payload: ["reason": "not_planning"]
                )
                return
            }
            guard let squad = try SquadRecord.fetchOne(
                database,
                key: mission.squadId
            ) else {
                throw RecordNotFoundError(
                    table: "squad",
                    id: mission.squadId
                )
            }
            let memberIds = try JSONDecoder().decode(
                [String].self,
                from: Data(squad.memberIdsJson.utf8)
            )
            let cardIds = drafts.map { _ in UUID().uuidString }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]

            for (index, draft) in drafts.enumerated() {
                let dependencyIds = draft.dependsOn.map {
                    cardIds[$0]
                }
                let dependencyData = try encoder.encode(dependencyIds)
                guard let dependsOnJson = String(
                    data: dependencyData,
                    encoding: .utf8
                ) else {
                    throw EncodingError.invalidValue(
                        dependencyIds,
                        .init(
                            codingPath: [],
                            debugDescription: "UTF-8 encoding failed"
                        )
                    )
                }
                let card = CardRecord(
                    id: cardIds[index],
                    missionId: missionId,
                    idemKey:
                        "mission:\(missionId):stage-\(index + 1)",
                    title: draft.title,
                    descriptionText: draft.description,
                    expectedOutput: draft.expectedOutput,
                    assigneeId: memberIds[draft.assignee],
                    status: .todo,
                    blockedReasonJson: nil,
                    dependsOnJson: dependsOnJson,
                    handoffJson: nil,
                    stage: index + 1,
                    maxTurns: KernelDefaults.maxTurns,
                    tokenBudget: KernelDefaults.cardTokenBudget,
                    createdAt: Date()
                )
                try card.insert(database)
            }

            mission.goalRefined = goalRefined
            try mission.update(database)
            try AppDatabase.appendEvent(
                database,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.planCompleted,
                payload: [
                    "goalRefined": .string(goalRefined),
                    "cardIds":
                        .array(cardIds.map(JSONValue.string)),
                    "titles":
                        .array(drafts.map { .string($0.title) }),
                ]
            )

            let statuses = try CardRecord
                .filter(Column("missionId") == missionId)
                .fetchAll(database)
                .map(\.status)
            let next = MissionStatus.rollup(
                current: mission.status,
                cards: statuses
            )
            if next != mission.status {
                let previous = mission.status
                mission.status = next
                try mission.update(database)
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: [
                        "from": .string(previous.rawValue),
                        "to": .string(next.rawValue),
                    ]
                )
            }
        }
    }

    func recordPlanningTokens(
        missionId: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int
    ) throws {
        try pool.write { database in
            guard var mission = try MissionRecord.fetchOne(
                database,
                key: missionId
            ) else {
                return
            }
            let (total, totalOverflow) =
                max(0, inputTokens).addingReportingOverflow(
                    max(0, outputTokens)
                )
            let (spent, spentOverflow) =
                mission.spentTokens.addingReportingOverflow(
                    totalOverflow ? Int.max : total
                )
            mission.spentTokens =
                (totalOverflow || spentOverflow) ? Int.max : spent
            try mission.update(database)
            let counters = try PlanningUsageCountersV1(
                cacheReadTokens: Int64(max(0, cacheReadTokens)),
                inputTokens: Int64(max(0, inputTokens)),
                outputTokens: Int64(max(0, outputTokens))
            )
            let payloadJSON = String(
                decoding: try CanonicalJSONV1.encode(counters),
                as: UTF8.self
            )
            try AppDatabase.appendLegacyEventAndScope(
                database,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.planningTokens,
                payloadJSON: payloadJSON,
                createdAt: Date()
            )
        }
    }
}

private func orchestratorTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func artifactRoot() throws -> URL {
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "orchestrator-state-\(UUID().uuidString)",
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

@discardableResult
private func attachOrchestrationDispatchContext(
    _ db: AppDatabase,
    missionId: String,
    companions: [CompanionRecord]
) throws -> URL {
    let firstCompanion = try #require(companions.first)
    let workspaceURL = try attachP1F1DispatchContext(
        db: db,
        missionId: missionId,
        companionId: firstCompanion.id
    )
    let profileID = try #require(
        try db.companion(id: firstCompanion.id)?.runtimeProfileId
    )
    for companion in companions.dropFirst() {
        var configured = try #require(try db.companion(id: companion.id))
        configured.runtimeProfileId = profileID
        configured.modelPolicy = .pinned
        try db.saveCompanion(configured)
    }
    return workspaceURL
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
        planningProviderResolver: TestPlanningProviderResolver(
            provider: provider
        ),
        makeProvider: { _, _ in provider },
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
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: [0]),
    ])
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: missionId,
        companionId: companions[0].id
    )
    let profileID = try #require(
        try db.companion(id: companions[0].id)?.runtimeProfileId
    )
    var downstreamCompanion = try #require(
        try db.companion(id: companions[1].id)
    )
    downstreamCompanion.runtimeProfileId = profileID
    downstreamCompanion.modelPolicy = .pinned
    try db.saveCompanion(downstreamCompanion)
    let provider = MockProvider(script: [doneTurn(summary: "A done"), doneTurn(summary: "B done")])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.recoverAndReconcile()
    try await orch.waitUntilIdle()
    let statuses = try db.cards(missionId: missionId).map(\.status)
    #expect(statuses == [.done, .done])
    await orch.shutdown()
}

@Test func sameCompanionCardsStaySerial() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 0, dependsOn: []),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: missionId,
        companions: [companions[0]]
    )
    let provider = GatedProvider(script: [doneTurn(summary: "A"), doneTurn(summary: "B")])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.recoverAndReconcile()
    await provider.waitUntilStarted()
    #expect(await provider.callCount == 1)
    await provider.release()
    await provider.waitUntilStarted(count: 2)
    await provider.release()
    try await orch.waitUntilIdle()
    let runs = try orchestrationRuns(db, missionId: missionId)
    #expect(runs.count == 2)
    let firstEnd = try #require(runs[0].endedAt)
    #expect(firstEnd <= runs[1].startedAt)
    await orch.shutdown()
}

@Test func distinctCompanionsRunConcurrently() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, companionCount: 3, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
        .init(title: "C", description: "c", expectedOutput: "oc", assignee: 2, dependsOn: []),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: missionId,
        companions: companions
    )
    let providers = [
        GatedProvider(script: [doneTurn(summary: "A")]),
        GatedProvider(script: [doneTurn(summary: "B")]),
        GatedProvider(script: [doneTurn(summary: "C")]),
    ]
    let orch = try Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: providers[0]
        ),
        makeProvider: { model, _ in
            switch model {
            case "model-0": providers[0]
            case "model-1": providers[1]
            default: providers[2]
            }
        },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
    await providers[0].waitUntilStarted()
    await providers[1].waitUntilStarted()
    await providers[2].waitUntilStarted()
    #expect(await providers[0].callCount == 1)
    #expect(await providers[1].callCount == 1)
    #expect(await providers[2].callCount == 1)

    await providers[0].release()
    await providers[1].release()
    await providers[2].release()
    try await orch.waitUntilIdle()

    let runs = try orchestrationRuns(db, missionId: missionId)
    #expect(runs.count == 3)
    let latestStart = try #require(runs.map(\.startedAt).max())
    let earliestEnd = try #require(runs.compactMap(\.endedAt).min())
    #expect(latestStart <= earliestEnd)
    await orch.shutdown()
}

@Test func mixedGatingDispatchesEagerly() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "A1", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "A2", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B1", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: missionId,
        companions: [companions[0], companions[1]]
    )
    let providerA = GatedProvider(script: [doneTurn(summary: "A1"), doneTurn(summary: "A2")])
    let providerB = GatedProvider(script: [doneTurn(summary: "B1")])
    let orch = try Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: providerA
        ),
        makeProvider: { model, _ in model == "model-0" ? providerA : providerB },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
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
    try await orch.waitUntilIdle()
    #expect(try db.cards(missionId: missionId).map(\.status) == [.done, .done, .done])
    await orch.shutdown()
}

@Test func busyCompanionSkippedNotStarved() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "A1", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "A2", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B1", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: missionId,
        companions: [companions[0], companions[1]]
    )
    let providerA = GatedProvider(script: [doneTurn(summary: "A1"), doneTurn(summary: "A2")])
    let providerB = GatedProvider(script: [doneTurn(summary: "B1")])
    let orch = try Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: providerA
        ),
        makeProvider: { model, _ in model == "model-0" ? providerA : providerB },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
    await providerA.waitUntilStarted()
    await providerB.waitUntilStarted()
    await providerB.release()
    await orch.reconcile()
    #expect(await providerA.callCount == 1)

    await providerA.release()
    await providerA.waitUntilStarted(count: 2)
    await providerA.release()
    try await orch.waitUntilIdle()
    #expect(try db.cards(missionId: missionId).map(\.status) == [.done, .done, .done])
    await orch.shutdown()
}

@Test func cancelDuringConcurrentRunsTerminalizesAll() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: missionId,
        companions: [companions[0], companions[1]]
    )
    let providerA = GatedProvider(script: [
        doneTurn(summary: "A"), doneTurn(summary: "other"),
    ])
    let providerB = GatedProvider(script: [doneTurn(summary: "B")])
    let orch = try Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: providerA
        ),
        makeProvider: { model, _ in model == "model-0" ? providerA : providerB },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
    await providerA.waitUntilStarted()
    await providerB.waitUntilStarted()
    await orch.cancelMission(missionId)

    #expect(try db.cards(missionId: missionId).map(\.status) == [.canceled, .canceled])
    let outcomes = try orchestrationRuns(db, missionId: missionId).map(\.outcome)
    #expect(outcomes == ["canceled", "canceled"])
    #expect(try db.mission(id: missionId)?.status == .failed)

    let (otherMissionId, otherCompanions) = try plannedMission(db, drafts: [
        .init(
            title: "Other",
            description: "continues after scoped cancellation",
            expectedOutput: "other",
            assignee: 0,
            dependsOn: []
        ),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: otherMissionId,
        companions: [otherCompanions[0]]
    )
    await orch.reconcile()
    await providerA.waitUntilStarted(count: 2)
    await providerA.release()
    try await orch.waitUntilIdle()
    #expect(try db.cards(missionId: otherMissionId).map(\.status) == [.done])
    await orch.shutdown()
}

@Test func reconcileIsIdempotent() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: missionId,
        companionId: companions[0].id
    )
    let provider = MockProvider(script: [doneTurn()])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.recoverAndReconcile()
    await orch.reconcile()
    try await orch.waitUntilIdle()
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
    #expect(try orchestrationRuns(db, missionId: missionId).allSatisfy {
        $0.outcome != nil
    })
    await orch.shutdown()
}

@Test func cancelMissionDoesNotDispatchReadyCardDuringRunnerShutdown() async throws {
    let db = try orchestratorTempDB()
    let (missionId, companions) = try plannedMission(db, drafts: [
        .init(title: "Slow", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
        .init(title: "Ready", description: "d", expectedOutput: "o", assignee: 0, dependsOn: []),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: missionId,
        companions: [companions[0]]
    )
    let (otherMissionId, otherCompanions) = try plannedMission(db, drafts: [
        .init(
            title: "Other",
            description: "must remain dispatchable",
            expectedOutput: "done",
            assignee: 1,
            dependsOn: []
        ),
    ])
    _ = try attachOrchestrationDispatchContext(
        db,
        missionId: otherMissionId,
        companions: [otherCompanions[1]]
    )
    let provider = HangingProvider()
    let otherProvider = MockProvider(script: [doneTurn(summary: "other")])
    let orch = try Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: otherProvider
        ),
        makeProvider: { model, _ -> any LLMProvider in
            if model == "model-0" {
                return provider
            }
            return otherProvider
        },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil
    )
    await orch.recoverAndReconcile()
    await provider.waitUntilStarted()

    let cards = try db.cards(missionId: missionId)
    await orch.cancelMission(missionId)

    #expect(try db.runs(cardId: cards[1].id).isEmpty)
    #expect(try db.cards(missionId: missionId).map(\.status) == [.canceled, .canceled])
    #expect(try db.mission(id: missionId)?.status == .failed)
    try await orch.waitUntilIdle()
    #expect(try db.cards(missionId: otherMissionId).map(\.status) == [.done])
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

@Test func approvalAnswerCreatesGrantAndStartupWithoutWorkflowFailsClosed()
async throws {
    let db = try orchestratorTempDB()
    let ids = try db.createSingleCardMission(
        campName: "approval-camp",
        squadName: "approval-squad",
        goal: "approval-goal",
        cardTitle: "approval-card",
        cardDescription: "write one file",
        expectedOutput: "out.md",
        assigneeId: nil,
        maxTurns: KernelDefaults.maxTurns
    )
    let runId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: runId)
    let input: JSONValue = ["path": "out.md", "content": "content"]
    let requestId = try db.suspendCardForApproval(
        cardId: ids.cardId,
        runId: runId,
        prompt: "approve write",
        tool: "write_file",
        input: input,
        inputHash: try ApprovalToken.hash(input: input)
    )
    let provider = MockProvider(script: [])
    let orch = try Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: provider
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: artifactRoot(),
        tickInterval: nil,
        requiresStartupRecovery: true
    )
    try await orch.answerUserRequest(
        requestId: requestId,
        answerJson: #"{"decision":"approve"}"#,
        deviceId: "00000000-0000-4000-8000-0000000000D4"
    )
    let store = ApprovalGrantStore(database: db)
    let grant = try #require(try store.grant(id: requestId))
    #expect(grant.id == requestId)
    #expect(try db.card(id: ids.cardId)?.status == .ready)

    let useId = try store.nextUseIdentity(grantId: grant.id)
    let reserved = try store.reserveUse(ReserveApprovalGrantUseCommandV1(
        envelope: CommandEnvelopeV1(
            idempotencyKey: useId,
            actorType: .system,
            actorId: P1DActorID.externalOperation,
            deviceId: nil,
            correlationId: "external-operation:\(useId)",
            causationId: nil,
            occurredAt: P1DTimestampV1.canonical(Date())
        ),
        useId: useId,
        grantId: grant.id,
        expectedGrantVersion: grant.version,
        capability: grant.capability,
        campId: grant.campId,
        cardId: grant.cardId,
        toolId: grant.toolId,
        inputHash: grant.approvedInputHash,
        adapter: ExternalOperationAdapterDescriptorV1(
            adapterId: "tool-handler:v1:write_file",
            toolId: "write_file",
            replayClass: .nonReplayable
        )
    ))
    _ = try store.commitDispatchIntent(
        ApprovalGrantUseTransitionCommandV1(
            envelope: CommandEnvelopeV1(
                idempotencyKey: "\(useId):dispatch-intent",
                actorType: .system,
                actorId: P1DActorID.externalOperation,
                deviceId: nil,
                correlationId: "external-operation:\(useId)",
                causationId: useId,
                occurredAt: P1DTimestampV1.canonical(Date())
            ),
            useId: useId,
            expectedUseVersion: reserved.version,
            expectedGrantVersion: grant.version
        )
    )

    await orch.recoverAndReconcile()

    #expect(try store.pendingUses().map(\.id) == [useId])
    #expect(try db.card(id: ids.cardId)?.status == .ready)
    let errorEvents = try db.events(missionId: "")
        .filter { $0.kind == EventKind.kernelError }
    #expect(errorEvents.count == 1)
    let errorPayload = try JSONValue.decoded(
        from: try #require(errorEvents.first).payloadJson
    )
    #expect(errorPayload == [
        "message": "Engine startup recovery failed."
    ])
    await orch.shutdown()
}

@Test func retryBlockedCardRedispatches() async throws {
    let db = try orchestratorTempDB()
    let companion = try orchestrationCompanions(db)[0]
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "A",
        cardDescription: "a", expectedOutput: "o", assigneeId: companion.id, maxTurns: KernelDefaults.maxTurns)
    _ = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.blockCard(id: ids.cardId, runId: nil, reason: "other", detail: "blocked")
    let provider = MockProvider(script: [doneTurn()])
    let orch = try orchestrator(db: db, provider: provider)
    await orch.recoverAndReconcile()
    try await orch.retryCard(ids.cardId)
    try await orch.waitUntilIdle()
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
    await orch.recoverAndReconcile()
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    try await orch.waitUntilIdle() // waitUntilIdle 必须等到蒸馏旁路任务完成

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
    await orch.recoverAndReconcile()
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    try await orch.waitUntilIdle()

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
    await orch.recoverAndReconcile()
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    try await orch.waitUntilIdle()

    let notes = try db.companionNotes(companionId: companion.id)
    #expect(notes.count == 1)
    #expect(notes.first?.title == "共事·abcdefghijklmnopqrst:协作经验")
    await orch.shutdown()
}

private func a1bPlanningAttempts(
    _ database: AppDatabase,
    workId: String
) throws -> [DurableWorkAttemptRecord] {
    try database.pool.read { db in
        try DurableWorkAttemptRecord
            .filter(Column("workId") == workId)
            .order(Column("attempt"))
            .fetchAll(db)
    }
}

private func a1bPlanningWork(
    _ database: AppDatabase,
    workId: String
) throws -> DurableWorkRecord {
    try #require(
        try DurableWorkStore(database: database).work(id: workId)
    )
}

@Test func stalePlannerAfterCancelCannotWriteTokensOrCards()
    async throws
{
    let fixture = try makeA1bRecoveryFixture(suffix: "stale-cancel")
    let provider = A1bBlockingPlanProvider(suffix: "stale-cancel")
    let resolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: provider
    )
    let ids = try enqueueA1bRecoveryPlanning(
        fixture,
        suffix: "stale-cancel",
        resolver: resolver
    )
    let supervisor = makeA1bSupervisor(
        fixture,
        resolver: resolver,
        workerId: "stale-cancel-worker",
        now: Date(timeIntervalSinceReferenceDate: 10_000)
    )

    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    await provider.waitUntilStarted()
    #expect(try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    ).state == .running)

    try await supervisor.cancelPlanning(
        missionId: ids.missionId,
        reason: "mission_abandoned"
    )
    provider.release()
    await provider.waitUntilReturned()
    await Task.yield()

    let work = try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    )
    let mission = try #require(
        try fixture.database.mission(id: ids.missionId)
    )
    let attempts = try a1bPlanningAttempts(
        fixture.database,
        workId: ids.workId
    )
    #expect(work.state == .canceled)
    #expect(work.errorCode == "work_canceled")
    #expect(mission.status == .failed)
    #expect(mission.spentTokens == 0)
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planningTokens
        ) == 0
    )
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planCompleted
        ) == 0
    )
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.missionFailed
        ) == 1
    )
    #expect(attempts.count == 1)
    #expect(attempts[0].outcome == .canceled)
    #expect(provider.callCount == 1)
    #expect(provider.returnCount == 1)
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func missingOrCorruptKernelControlFailsPlanningClosed()
    async throws
{
    enum ControlDamage {
        case missing
        case corrupt
    }

    for (suffix, damage) in [
        ("missing-control", ControlDamage.missing),
        ("corrupt-control", ControlDamage.corrupt),
    ] {
        let fixture = try makeA1bRecoveryFixture(suffix: suffix)
        let provider = A1bBlockingPlanProvider(suffix: suffix)
        let resolver = TestPlanningProviderResolver(
            profileId: fixture.profile.id,
            model: fixture.model,
            provider: provider
        )
        let ids = try enqueueA1bRecoveryPlanning(
            fixture,
            suffix: suffix,
            resolver: resolver
        )
        let workBefore = try a1bPlanningWork(
            fixture.database,
            workId: ids.workId
        )
        let eventEncoder = JSONEncoder()
        eventEncoder.outputFormatting = [.sortedKeys]
        let eventsBefore = try eventEncoder.encode(
            fixture.database.events(missionId: ids.missionId)
        )

        switch damage {
        case .missing:
            try await fixture.database.pool.write { db in
                _ = try KernelControlRecord.deleteOne(
                    db,
                    key: "global"
                )
            }
        case .corrupt:
            try await fixture.database.pool.writeWithoutTransaction { db in
                try db.execute(
                    sql: "PRAGMA ignore_check_constraints = ON"
                )
                try db.execute(
                    sql: """
                        UPDATE kernel_control
                        SET dispatchMode = 'corrupt'
                        WHERE id = 'global'
                        """
                )
                try db.execute(
                    sql: "PRAGMA ignore_check_constraints = OFF"
                )
            }
        }

        let supervisor = makeA1bSupervisor(
            fixture,
            resolver: resolver,
            workerId: "\(suffix)-worker",
            now: Date(timeIntervalSinceReferenceDate: 11_000)
        )
        await #expect(throws: (any Error).self) {
            try await supervisor.recoverOnStartup(
                profileModels: [fixture.profile.id: fixture.model]
            )
        }

        #expect(provider.callCount == 0)
        #expect(
            try a1bPlanningWork(
                fixture.database,
                workId: ids.workId
            ) == workBefore
        )
        #expect(
            try fixture.database.mission(id: ids.missionId)?.status
                == .planning
        )
        #expect(
            try fixture.database.mission(id: ids.missionId)?.spentTokens
                == 0
        )
        #expect(
            try fixture.database.cards(
                missionId: ids.missionId
            ).isEmpty
        )
        #expect(
            try eventEncoder.encode(
                fixture.database.events(missionId: ids.missionId)
            )
                == eventsBefore
        )
        _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
    }
}

@Test func shutdownReportSortsUniqueUncooperativeWorkIds()
    async throws
{
    let fixture = try makeA1bRecoveryFixture(suffix: "shutdown-report")
    let provider = A1bBlockingPlanProvider(suffix: "shutdown-report")
    let resolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: provider
    )
    let ids = try (0..<3).map { index in
        try enqueueA1bRecoveryPlanning(
            fixture,
            suffix: "shutdown-report-\(index)",
            resolver: resolver
        )
    }
    let supervisor = makeA1bSupervisor(
        fixture,
        resolver: resolver,
        workerId: "shutdown-report-worker",
        now: Date(timeIntervalSinceReferenceDate: 12_000)
    )

    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    await provider.waitUntilStarted(3)

    let report = await supervisor.shutdown(
        gracePeriod: .milliseconds(25)
    )
    let expected = ids.map(\.workId).sorted()
    #expect(report.uncooperativeWorkIds == expected)
    #expect(
        Set(report.uncooperativeWorkIds).count
            == report.uncooperativeWorkIds.count
    )
    #expect(
        try ids.map {
            try a1bPlanningWork(
                fixture.database,
                workId: $0.workId
            ).state
        } == [.running, .running, .running]
    )
    #expect(provider.callCount == 3)

    provider.release()
    await provider.waitUntilReturned(3)
}

@Test func providerReturningAfterShutdownCannotCommit() async throws {
    let fixture = try makeA1bRecoveryFixture(
        suffix: "return-after-shutdown"
    )
    let provider = A1bBlockingPlanProvider(
        suffix: "return-after-shutdown"
    )
    let resolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: provider
    )
    let ids = try enqueueA1bRecoveryPlanning(
        fixture,
        suffix: "return-after-shutdown",
        resolver: resolver
    )
    let supervisor = makeA1bSupervisor(
        fixture,
        resolver: resolver,
        workerId: "return-after-shutdown-worker",
        now: Date(timeIntervalSinceReferenceDate: 13_000)
    )

    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    await provider.waitUntilStarted()
    let report = await supervisor.shutdown(
        gracePeriod: .milliseconds(25)
    )
    #expect(report.uncooperativeWorkIds == [ids.workId])

    provider.release()
    await provider.waitUntilReturned()
    await Task.yield()

    let work = try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    )
    let attempts = try a1bPlanningAttempts(
        fixture.database,
        workId: ids.workId
    )
    #expect(work.state == .running)
    #expect(work.leaseOwner == "return-after-shutdown-worker")
    #expect(attempts.count == 1)
    #expect(attempts[0].outcome == nil)
    #expect(
        try fixture.database.mission(id: ids.missionId)?.spentTokens
            == 0
    )
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planningTokens
        ) == 0
    )
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planCompleted
        ) == 0
    )
    #expect(provider.callCount == 1)
}

@Test func shutdownRacingTerminalProposalHasOneActorSerializedWinner()
    async throws
{
    let fixture = try makeA1bRecoveryFixture(suffix: "shutdown-race")
    let provider = A1bBlockingPlanProvider(suffix: "shutdown-race")
    let resolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: provider
    )
    let ids = try enqueueA1bRecoveryPlanning(
        fixture,
        suffix: "shutdown-race",
        resolver: resolver
    )
    let supervisor = makeA1bSupervisor(
        fixture,
        resolver: resolver,
        workerId: "shutdown-race-worker",
        now: Date(timeIntervalSinceReferenceDate: 14_000)
    )

    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    await provider.waitUntilStarted()

    let shutdownTask = Task {
        await supervisor.shutdown(gracePeriod: .milliseconds(100))
    }
    let releaseTask = Task.detached {
        provider.release()
    }
    _ = await releaseTask.value
    let report = await shutdownTask.value
    await provider.waitUntilReturned()
    await Task.yield()

    let work = try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    )
    let attempts = try a1bPlanningAttempts(
        fixture.database,
        workId: ids.workId
    )
    let cards = try fixture.database.cards(missionId: ids.missionId)
    let tokenEvents = try a1bPlanningEventCount(
        fixture.database,
        missionId: ids.missionId,
        kind: EventKind.planningTokens
    )
    let planEvents = try a1bPlanningEventCount(
        fixture.database,
        missionId: ids.missionId,
        kind: EventKind.planCompleted
    )

    #expect(report.uncooperativeWorkIds.count <= 1)
    #expect(attempts.count == 1)
    #expect(provider.callCount == 1)
    switch work.state {
    case .succeeded:
        #expect(work.leaseOwner == nil)
        #expect(attempts[0].outcome == .succeeded)
        #expect(cards.count == 1)
        #expect(tokenEvents == 1)
        #expect(planEvents == 1)
    case .running:
        #expect(work.leaseOwner == "shutdown-race-worker")
        #expect(attempts[0].outcome == nil)
        #expect(cards.isEmpty)
        #expect(tokenEvents == 0)
        #expect(planEvents == 0)
    default:
        Issue.record(
            "actor race must have either terminal proposal or shutdown win"
        )
    }
}

@Test func nextProcessAdoptsShutdownRowAndCompletesExactlyOnce()
    async throws
{
    let fixture = try makeA1bRecoveryFixture(
        suffix: "next-process"
    )
    let firstProvider = A1bBlockingPlanProvider(
        suffix: "next-process-stale"
    )
    let firstResolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: firstProvider
    )
    let ids = try enqueueA1bRecoveryPlanning(
        fixture,
        suffix: "next-process",
        resolver: firstResolver
    )
    let firstSupervisor = makeA1bSupervisor(
        fixture,
        resolver: firstResolver,
        workerId: "next-process-old-worker",
        now: Date(timeIntervalSinceReferenceDate: 15_000)
    )

    try await firstSupervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    try await firstSupervisor.activateAfterOrchestratorRecovery()
    await firstProvider.waitUntilStarted()
    let firstReport = await firstSupervisor.shutdown(
        gracePeriod: .milliseconds(25)
    )
    #expect(firstReport.uncooperativeWorkIds == [ids.workId])
    #expect(try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    ).state == .running)

    firstProvider.release()
    await firstProvider.waitUntilReturned()

    let nextProvider = MockProvider(
        script: [a1bRecoveryPlanTurn(suffix: "next-process")]
    )
    let nextResolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: nextProvider
    )
    let nextSupervisor = makeA1bSupervisor(
        fixture,
        resolver: nextResolver,
        workerId: "next-process-new-worker",
        now: Date(timeIntervalSinceReferenceDate: 15_001)
    )
    try await nextSupervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    try await nextSupervisor.activateAfterOrchestratorRecovery()
    try await nextSupervisor.waitUntilTerminal(workId: ids.workId)

    let work = try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    )
    let attempts = try a1bPlanningAttempts(
        fixture.database,
        workId: ids.workId
    )
    #expect(work.state == .succeeded)
    #expect(attempts.map(\.attempt) == [1, 2])
    #expect(attempts.map(\.outcome) == [.interrupted, .succeeded])
    #expect(
        attempts.map(\.workerId)
            == [
                "next-process-old-worker",
                "next-process-new-worker",
            ]
    )
    #expect(try fixture.database.cards(missionId: ids.missionId).count == 1)
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planningTokens
        ) == 1
    )
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planCompleted
        ) == 1
    )
    #expect(await nextProvider.callCount == 1)
    _ = await nextSupervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func restartAdoptsPlanningWorkAndCreatesCardsOnce() async throws {
    let fixture = try makeA1bRecoveryFixture(suffix: "restart-adopt")
    let provider = MockProvider(
        script: [a1bRecoveryPlanTurn(suffix: "restart-adopt")]
    )
    let resolver = TestPlanningProviderResolver(
        profileId: fixture.profile.id,
        model: fixture.model,
        provider: provider
    )
    let ids = try enqueueA1bRecoveryPlanning(
        fixture,
        suffix: "restart-adopt",
        resolver: resolver
    )
    let crashedClaim = try #require(
        try fixture.database.claimNextPlanning(
            workerId: "crashed-planning-worker",
            now: Date(timeIntervalSinceReferenceDate: 16_000),
            leaseDuration: 60
        )
    )
    #expect(crashedClaim.workId == ids.workId)
    #expect(crashedClaim.attempt == 1)

    let restartedSupervisor = makeA1bSupervisor(
        fixture,
        resolver: resolver,
        workerId: "restarted-planning-worker",
        now: Date(timeIntervalSinceReferenceDate: 16_001)
    )
    try await restartedSupervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: fixture.model]
    )
    #expect(
        try a1bPlanningAttempts(
            fixture.database,
            workId: ids.workId
        ).map(\.outcome) == [.interrupted]
    )
    try await restartedSupervisor.activateAfterOrchestratorRecovery()
    try await restartedSupervisor.waitUntilTerminal(workId: ids.workId)

    let work = try a1bPlanningWork(
        fixture.database,
        workId: ids.workId
    )
    let attempts = try a1bPlanningAttempts(
        fixture.database,
        workId: ids.workId
    )
    let cards = try fixture.database.cards(missionId: ids.missionId)
    #expect(work.state == .succeeded)
    #expect(work.attempt == 2)
    #expect(attempts.map(\.attempt) == [1, 2])
    #expect(attempts.map(\.outcome) == [.interrupted, .succeeded])
    #expect(cards.count == 1)
    #expect(Set(cards.map(\.idemKey)).count == 1)
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planningTokens
        ) == 1
    )
    #expect(
        try a1bPlanningEventCount(
            fixture.database,
            missionId: ids.missionId,
            kind: EventKind.planCompleted
        ) == 1
    )
    #expect(await provider.callCount == 1)
    _ = await restartedSupervisor.shutdown(
        gracePeriod: .milliseconds(50)
    )
}

private final class P1F1D076FactoryProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptorCalls: [String: Int] = [:]
    private var makeCalls: [String: Int] = [:]
    private var runtimeReferences: [String: [EngineSessionReferenceV1?]] = [:]
    private var processLaunches = 0
    private var storeSnapshots: [String: [String]] = [:]
    private var prepareCalls: [String: Int] = [:]
    private var transportCalls: [String: Int] = [:]
    private var recoveryTransportCalls: [String: Int] = [:]
    private var boundToolNames: [String: [[String]]] = [:]

    func recordDescriptor(_ adapterId: String) {
        lock.lock()
        descriptorCalls[adapterId, default: 0] += 1
        lock.unlock()
    }

    func descriptorCount(_ adapterId: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return descriptorCalls[adapterId, default: 0]
    }

    func recordMake(_ adapterId: String) {
        lock.lock()
        makeCalls[adapterId, default: 0] += 1
        lock.unlock()
    }

    func makeCount(_ adapterId: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return makeCalls[adapterId, default: 0]
    }

    func recordRuntime(
        _ adapterId: String,
        reference: EngineSessionReferenceV1?
    ) {
        lock.lock()
        runtimeReferences[adapterId, default: []].append(reference)
        lock.unlock()
    }

    func runtimes(_ adapterId: String) -> [EngineSessionReferenceV1?] {
        lock.lock()
        defer { lock.unlock() }
        return runtimeReferences[adapterId, default: []]
    }

    func recordProcessLaunch() {
        lock.lock()
        processLaunches += 1
        lock.unlock()
    }

    var processLaunchCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return processLaunches
    }

    func recordPrepare(_ adapterId: String) {
        lock.withLock { prepareCalls[adapterId, default: 0] += 1 }
    }

    func prepareCount(_ adapterId: String) -> Int {
        lock.withLock { prepareCalls[adapterId, default: 0] }
    }

    func recordTransport(
        _ adapterId: String,
        bound: EngineBoundCapabilityToolsV1,
        recovery: Bool
    ) {
        lock.withLock {
            if recovery {
                recoveryTransportCalls[adapterId, default: 0] += 1
            } else {
                transportCalls[adapterId, default: 0] += 1
            }
            boundToolNames[adapterId, default: []].append(
                bound.logicalDefinitions.map(\.name)
            )
        }
    }

    func transportCount(_ adapterId: String) -> Int {
        lock.withLock { transportCalls[adapterId, default: 0] }
    }

    func recoveryTransportCount(_ adapterId: String) -> Int {
        lock.withLock { recoveryTransportCalls[adapterId, default: 0] }
    }

    func boundNames(_ adapterId: String) -> [[String]] {
        lock.withLock { boundToolNames[adapterId, default: []] }
    }

    func recordStoreSnapshot(_ snapshot: [String], key: String) {
        lock.lock()
        storeSnapshots[key] = snapshot
        lock.unlock()
    }

    func storeSnapshot(_ key: String) -> [String]? {
        lock.lock()
        defer { lock.unlock() }
        return storeSnapshots[key]
    }
}

private struct P1F1D076Adapter: ExecutionEngineAdapter {
    let value: ExecutionEngineDescriptor
    let payloads: [EngineExecutionEventPayloadV1]

    init(
        value: ExecutionEngineDescriptor,
        payloads: [EngineExecutionEventPayloadV1] = []
    ) {
        self.value = value
        self.payloads = payloads
    }

    func descriptor(
        profile: RuntimeProfileRecord
    ) throws -> ExecutionEngineDescriptor { value }

    func execute(
        request: EngineExecutionRequest
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        _ = request
        return AsyncThrowingStream { continuation in
            for payload in payloads {
                continuation.yield(payload)
            }
            continuation.finish()
        }
    }

    func cancel(executionId: String) async throws {}
}

private struct P1F1D076ModelDriver: ModelLoopExecutionDrivingV1 {
    func execute(
        request: EngineExecutionRequest,
        context: EngineResolvedContextTransportV1,
        workspaceURL: URL,
        terminalSink: any EngineTerminalSink,
        boardTerminalSink: any EngineBoardTerminalSink,
        progressSink: any EngineProgressSink
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        _ = request
        _ = context
        _ = workspaceURL
        _ = terminalSink
        _ = boardTerminalSink
        _ = progressSink
        return AsyncThrowingStream { $0.finish() }
    }

    func cancel(executionId: String) async throws {
        _ = executionId
    }
}

private func p1f1d076PreparedRequest(
    profile: RuntimeProfileRecord,
    descriptor: ExecutionEngineDescriptor,
    seed: EngineExecutionTransportSeedV1,
    probe: P1F1D076FactoryProbe,
    recovery: Bool
) throws -> EngineAdapterPreparedRequestV1 {
    guard profile == seed.context.profile,
          descriptor.profileKind == profile.kind
    else {
        throw EngineAdapterSelectionErrorV1.descriptorMismatch
    }
    if !recovery {
        probe.recordPrepare(descriptor.adapterId)
    }
    var capabilities = seed.baseRequiredCapabilities
    if seed.context.capabilityTools.requiresWorkspaceWrite {
        capabilities.append(.workspaceWrite)
    }
    capabilities = Array(Set(capabilities)).sorted {
        $0.rawValue < $1.rawValue
    }
    return EngineAdapterPreparedRequestV1(
        descriptor: descriptor,
        engineKind: descriptor.adapterId,
        model: seed.context.companionModel,
        budget: EngineExecutionBudgetV1(
            tokenLimit: seed.context.cardTokenBudget,
            costMicrosLimit: 0,
            wallClockSeconds: 0
        ),
        context: seed.context.modelLoop,
        requiredCapabilities: capabilities,
        makeTransport: { request, context, workspace in
            guard request.profileId == profile.id,
                  request.engineKind == descriptor.adapterId,
                  context.hash == request.contextHash
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            let bound = try seed.context.capabilityTools
                .makeCapabilityTools(workspace.url)
            probe.recordTransport(
                descriptor.adapterId,
                bound: bound,
                recovery: recovery
            )
            return try EngineExecutionTransportV1(
                contextRequest: seed.context.modelLoop.request,
                workspaceRequest: seed.workspace.request,
                boundCapabilityTools: bound,
                modelLoopDriver: P1F1D076ModelDriver(),
                cliProcessDriver: nil,
                cliConfiguration: nil
            )
        }
    )
}

private func p1f1d076Factory(
    adapterId: String,
    kind: RuntimeProfileKind,
    sessionResume: EngineCapabilitySupportV1,
    probe: P1F1D076FactoryProbe,
    payloads: [EngineExecutionEventPayloadV1] = []
) -> EngineAdapterFactoryV1 {
    EngineAdapterFactoryV1(
        adapterId: adapterId,
        adapterVersion: "1",
        profileKinds: [kind],
        helpRequirement: nil,
        descriptor: { profile, help in
            guard profile.kind == kind, help == nil else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            probe.recordDescriptor(adapterId)
            return p1f1d076Descriptor(
                adapterId: adapterId,
                kind: kind,
                sessionResume: sessionResume,
                replayClass: .idempotencyKeyed
            )
        },
        prepareRequest: { profile, help, seed in
            guard help == nil else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            return try p1f1d076PreparedRequest(
                profile: profile,
                descriptor: p1f1d076Descriptor(
                    adapterId: adapterId,
                    kind: kind,
                    sessionResume: sessionResume,
                    replayClass: .idempotencyKeyed
                ),
                seed: seed,
                probe: probe,
                recovery: false
            )
        },
        makeRecoveryTransport: {
            profile, help, request, context, workspace, seed in
            guard help == nil else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            let prepared = try p1f1d076PreparedRequest(
                profile: profile,
                descriptor: p1f1d076Descriptor(
                    adapterId: adapterId,
                    kind: kind,
                    sessionResume: sessionResume,
                    replayClass: .idempotencyKeyed
                ),
                seed: seed,
                probe: probe,
                recovery: true
            )
            return try prepared.makeTransport(
                request,
                context,
                workspace
            )
        },
        makeAdapter: { profile, runtime in
            guard profile.kind == kind else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            probe.recordMake(adapterId)
            probe.recordRuntime(
                adapterId,
                reference: runtime.resolvedSessionRef
            )
            return P1F1D076Adapter(
                value: p1f1d076Descriptor(
                    adapterId: adapterId,
                    kind: kind,
                    sessionResume: sessionResume,
                    replayClass: .idempotencyKeyed
                ),
                payloads: payloads
            )
        }
    )
}

private func p1f1d076DependencyLoader(
    _ database: AppDatabase
) -> ContextDependencyLoader {
    ContextDependencyLoader(
        database: database,
        manager: nil,
        reporter: FailureReporter(database: database),
        searchCredential: { nil },
        knowledge: .live(database: database),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
}

private struct P1F1D076RegistryDescriptorAuthority: Sendable {
    let registry: EngineAdapterRegistryV1

    func callAsFunction(
        _ profile: RuntimeProfileRecord
    ) throws -> ExecutionEngineDescriptor {
        try registry.resolve(
            profile: profile,
            requiredCapabilities: []
        ).descriptor
    }

    func callAsFunction(
        _ profile: RuntimeProfileRecord,
        _ requiredCapabilities: [EngineCapabilityV1]
    ) throws -> ExecutionEngineDescriptor {
        try registry.resolve(
            profile: profile,
            requiredCapabilities: requiredCapabilities
        ).descriptor
    }
}

private func p1f1d076Store(
    fixture: P1F1DCanonicalExecutionFixture,
    registry: EngineAdapterRegistryV1
) -> EngineExecutionStore {
    let authority = P1F1D076RegistryDescriptorAuthority(registry: registry)
    return EngineExecutionStore(
        database: fixture.db,
        descriptorResolver: { profile, requiredCapabilities in
            try authority(profile, requiredCapabilities)
        },
        clock: { P1F1DCanonicalExecutionFixture.now }
    )
}

private func p1f1d076Descriptor(
    adapterId: String,
    adapterVersion: String = "1",
    kind: RuntimeProfileKind,
    sessionResume: EngineCapabilitySupportV1,
    replayClass: EngineExecutionReplayClassV1 = .nonReplayable
) -> ExecutionEngineDescriptor {
    ExecutionEngineDescriptor(
        adapterId: adapterId,
        adapterVersion: adapterVersion,
        profileKind: kind,
        streamingProgress: .supported,
        boardTerminal: .supported,
        toolBridge: .supported,
        cancellation: .supported,
        sessionResume: sessionResume,
        usageMetering: .supported,
        workspaceRead: .supported,
        workspaceWrite: .supported,
        network: .supported,
        replayClassResolver: { _ in replayClass }
    )
}

private enum P1F1D076FixtureError: Error, Sendable, Equatable {
    case cliDriverMustStayLazy
    case externalRecovery
    case unexpectedExternalExecution
}

private final class P1F1D076LifecycleProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var cliDriverConstructions = 0
    private var processSnapshots = 0
    private var processSignals = 0
    private var processGroupChecks = 0

    func recordCLIDriverConstruction() {
        lock.withLock { cliDriverConstructions += 1 }
    }

    func recordProcessSnapshot() {
        lock.withLock { processSnapshots += 1 }
    }

    func recordProcessSignal() {
        lock.withLock { processSignals += 1 }
    }

    func recordProcessGroupCheck() {
        lock.withLock { processGroupChecks += 1 }
    }

    var snapshot: (
        cliDriverConstructions: Int,
        processSnapshots: Int,
        processSignals: Int,
        processGroupChecks: Int
    ) {
        lock.withLock {
            (
                cliDriverConstructions,
                processSnapshots,
                processSignals,
                processGroupChecks
            )
        }
    }
}

private struct P1F1D076ProcessInspector:
    EngineRuntimeProcessInspectingV1, Sendable
{
    let probe: P1F1D076LifecycleProbe

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        probe.recordProcessSnapshot()
        return []
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        _ = signal
        _ = processGroupId
        probe.recordProcessSignal()
        throw EngineContextValidationErrorV1()
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        _ = processGroupId
        probe.recordProcessGroupCheck()
        return false
    }
}

private actor P1F1D076ExternalWorkflow:
    ExternalOperationWorkflowPortV1
{
    private var failsRecovery: Bool
    private var recoveryAttempts = 0
    private var executionAttempts = 0

    init(failsRecovery: Bool) {
        self.failsRecovery = failsRecovery
    }

    func execute(
        grantId: String,
        expectedGrantVersion: Int,
        capability: String,
        campId: String,
        cardId: String,
        toolId: String,
        input: JSONValue,
        adapter: any ExternalOperationAdapterV1
    ) async throws -> ExternalOperationSanitizedAcknowledgmentV1 {
        _ = grantId
        _ = expectedGrantVersion
        _ = capability
        _ = campId
        _ = cardId
        _ = toolId
        _ = input
        _ = adapter
        executionAttempts += 1
        throw P1F1D076FixtureError.unexpectedExternalExecution
    }

    func recoverPending() async throws {
        recoveryAttempts += 1
        if failsRecovery {
            throw P1F1D076FixtureError.externalRecovery
        }
    }

    func setFailsRecovery(_ value: Bool) {
        failsRecovery = value
    }

    func snapshot() -> (recoveries: Int, executions: Int) {
        (recoveryAttempts, executionAttempts)
    }
}

private actor P1F1D076BindRecorder {
    private var requests: [EngineExecutionRequest] = []

    func dispatch(
        _ request: EngineExecutionRequest
    ) -> EngineExecutionBindDispositionV1 {
        requests.append(request)
        return .dispatch
    }

    func snapshot() -> [EngineExecutionRequest] { requests }
}

private struct P1F1D076PendingProjection: Sendable, Equatable {
    let execution: EngineExecutionRecord
    let lifecycle: CampLifecycleSnapshotV1
    let cardStatus: CardStatus
    let missionStatus: MissionStatus
    let runOutcome: String?
    let proposalCount: Int
}

private final class P1F1D076LifetimeCapsule: @unchecked Sendable {
    let canonical: P1F1DCanonicalExecutionFixture
    let stateDirectoryLock: StateDirectoryLock
    let environment: EngineExecutionEnvironmentV1

    init(
        provider: any LLMProvider,
        probe: P1F1D076LifecycleProbe
    ) throws {
        let canonical = try P1F1DCanonicalExecutionFixture(
            replayClass: .idempotencyKeyed,
            profileKind: .openAIAPI
        )
        let stateDirectoryLock = try StateDirectoryLock(
            directoryURL: canonical.root
        )
        let environment = try p1f1d076Environment(
            fixture: canonical,
            stateDirectoryLock: stateDirectoryLock,
            provider: provider,
            probe: probe
        )
        guard environment.database === canonical.db,
              environment.stateDirectoryLock === stateDirectoryLock
        else {
            throw EngineContextValidationErrorV1()
        }
        self.canonical = canonical
        self.stateDirectoryLock = stateDirectoryLock
        self.environment = environment
    }
}

private struct P1F1D076PendingFixture: Sendable {
    let lifetime: P1F1D076LifetimeCapsule
    let orchestrator: Orchestrator
    let runtime: EngineExecutionRuntimeV1
    let store: EngineExecutionStore
    let request: EngineExecutionRequest
    let identity: EngineDispatchIdentityV1
    let probe: P1F1D076LifecycleProbe
    let workflow: P1F1D076ExternalWorkflow

    var canonical: P1F1DCanonicalExecutionFixture {
        lifetime.canonical
    }
}

private func p1f1d076Environment(
    fixture: P1F1DCanonicalExecutionFixture,
    stateDirectoryLock: StateDirectoryLock,
    provider: any LLMProvider,
    probe: P1F1D076LifecycleProbe
) throws -> EngineExecutionEnvironmentV1 {
    let artifacts = fixture.root.appendingPathComponent(
        "runtime-artifacts",
        isDirectory: true
    )
    let claude = fixture.root.appendingPathComponent(
        "runtime-claude",
        isDirectory: true
    )
    let executables = fixture.root.appendingPathComponent(
        "runtime-executables",
        isDirectory: true
    )
    for directory in [artifacts, claude, executables] {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
    let inspector = P1F1D076ProcessInspector(probe: probe)
    return try EngineExecutionEnvironmentV1(
        database: fixture.db,
        stateDirectoryLock: stateDirectoryLock,
        artifactStoreRoot: artifacts,
        bridgeExecutablePath: nil,
        boardSocketDirectoryAuthority: nil,
        validateCodexManagedPolicy: nil,
        validateClaudeManagedPolicy: nil,
        claudeConfigDirectory: claude,
        cliExecutableDirectory: executables,
        processInspector: inspector,
        dependencyLoader: p1f1d076DependencyLoader(fixture.db),
        resolveInitialModelLoopProvider: {
            profile, companionId, companionModel, _ in
            guard profile == fixture.profile,
                  companionId == fixture.companion.id
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            return try EngineModelLoopProviderAuthorityV1(
                profileId: profile.id,
                effectiveModel: companionModel,
                makeProvider: { provider }
            )
        },
        resolveRecoveryModelLoopProvider: {
            profile, companionId, persistedModel in
            guard profile == fixture.profile,
                  companionId == fixture.companion.id
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            return try EngineModelLoopProviderAuthorityV1(
                profileId: profile.id,
                effectiveModel: persistedModel,
                makeProvider: { provider }
            )
        },
        helpProbe: CliHelpProbeV1(processInspector: inspector),
        makeCliProcessDriver: {
            probe.recordCLIDriverConstruction()
            throw P1F1D076FixtureError.cliDriverMustStayLazy
        },
        clock: { P1F1DCanonicalExecutionFixture.now }
    )
}

private func p1f1d076Orchestrator(
    fixture: P1F1DCanonicalExecutionFixture,
    environment: EngineExecutionEnvironmentV1,
    provider: any LLMProvider,
    probe: P1F1D076LifecycleProbe,
    workflow: P1F1D076ExternalWorkflow,
    requiresStartupRecovery: Bool
) throws -> Orchestrator {
    guard environment.database === fixture.db else {
        throw EngineContextValidationErrorV1()
    }
    return Orchestrator(
        db: fixture.db,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: provider
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: environment.artifactStoreRoot,
        tickInterval: nil,
        externalOperationWorkflow: workflow,
        requiresStartupRecovery: requiresStartupRecovery,
        legacyRuminationSnapshot: .legacyProfileUnresolved,
        contextDependencyLoader: p1f1d076DependencyLoader(fixture.db),
        engineEnvironment: environment
    )
}

private func p1f1d076AppendReadyCause(
    _ fixture: P1F1DCanonicalExecutionFixture
) throws -> EngineCardReadyCauseV1 {
    try fixture.db.pool.write { database in
        try AppDatabase.appendEvent(
            database,
            missionId: fixture.mission.id,
            cardId: fixture.card.id,
            runId: nil,
            kind: EventKind.cardReady,
            payload: .object([:])
        )
    }
    return try fixture.db.pool.read { database in
        try fixture.db.resolveEngineCardReadyCause(
            for: fixture.card,
            in: database
        )
    }
}

private func p1f1d076RequestDeletion(
    _ fixture: P1F1DCanonicalExecutionFixture
) throws {
    try fixture.db.pool.write { database in
        try database.execute(
            sql: """
                UPDATE camp_lifecycle
                SET state='deletionRequested',version=version+1,
                    updatedAt=?,deletionRequestedAt=?
                WHERE campId=? AND state='active'
                """,
            arguments: [
                P1F1DCanonicalExecutionFixture.now.addingTimeInterval(1),
                P1F1DCanonicalExecutionFixture.now.addingTimeInterval(1),
                fixture.camp.id,
            ]
        )
        guard database.changesCount == 1 else {
            throw EngineContextValidationErrorV1()
        }
    }
}

private func p1f1d076PendingProjection(
    _ fixture: P1F1D076PendingFixture
) throws -> P1F1D076PendingProjection {
    try fixture.canonical.db.pool.read { database in
        guard let execution = try EngineExecutionRecord.fetchOne(
            database,
            key: fixture.request.executionId
        ),
            let lifecycle = try CampLifecycleStore(
                database: fixture.canonical.db
            ).lifecycle(
                campId: fixture.canonical.camp.id,
                database: database
            ),
            let card = try CardRecord.fetchOne(
                database,
                key: fixture.canonical.card.id
            ),
            let mission = try MissionRecord.fetchOne(
                database,
                key: fixture.canonical.mission.id
            ),
            let run = try RunRecord.fetchOne(
                database,
                key: fixture.request.runId
            )
        else {
            throw EngineContextValidationErrorV1()
        }
        return P1F1D076PendingProjection(
            execution: execution,
            lifecycle: lifecycle,
            cardStatus: card.status,
            missionStatus: mission.status,
            runOutcome: run.outcome,
            proposalCount: try EngineTerminalProposalRecord
                .filter(Column("executionId") == fixture.request.executionId)
                .fetchCount(database)
        )
    }
}

private func p1f1d076MakePendingFixture(
    requiresStartupRecovery: Bool,
    workflowFails: Bool = false,
    initiallyHalted: Bool = false
) async throws -> P1F1D076PendingFixture {
    let provider = MockProvider(script: [])
    let probe = P1F1D076LifecycleProbe()
    let lifetime = try P1F1D076LifetimeCapsule(
        provider: provider,
        probe: probe
    )
    let canonical = lifetime.canonical
    let workflow = P1F1D076ExternalWorkflow(
        failsRecovery: requiresStartupRecovery && workflowFails
    )
    if initiallyHalted {
        _ = try canonical.db.transitionDispatchMode(
            from: .running,
            to: .halted
        )
    }
    let orchestrator = try p1f1d076Orchestrator(
        fixture: canonical,
        environment: lifetime.environment,
        provider: provider,
        probe: probe,
        workflow: workflow,
        requiresStartupRecovery: requiresStartupRecovery
    )
    if !requiresStartupRecovery {
        await orchestrator.recoverAndReconcile()
        guard await workflow.snapshot().recoveries == 1 else {
            throw EngineContextValidationErrorV1()
        }
        await workflow.setFailsRecovery(workflowFails)
    }
    let cause = try p1f1d076AppendReadyCause(canonical)
    let runtime = try await orchestrator.engineExecutionRuntime()
    let identity = EngineDispatchIdentityV1(
        campId: canonical.camp.id,
        cardId: canonical.card.id,
        companionId: canonical.companion.id,
        cause: cause
    )
    let prepared = try await runtime.prepare(identity)
    let registry = try await runtime.registry(
        requestedProfileKinds: [.openAIAPI]
    )
    let store = p1f1d076Store(fixture: canonical, registry: registry)
    let request = try store.beginEngineExecution(
        requestFields: prepared.requestFields,
        idempotencyKey: prepared.idempotencyKey
    )
    try p1f1d076RequestDeletion(canonical)
    return P1F1D076PendingFixture(
        lifetime: lifetime,
        orchestrator: orchestrator,
        runtime: runtime,
        store: store,
        request: request,
        identity: identity,
        probe: probe,
        workflow: workflow
    )
}

private func p1f1d076MakeBoundPendingFixture()
    async throws -> P1F1D076PendingFixture
{
    let provider = HangingProvider()
    let probe = P1F1D076LifecycleProbe()
    let lifetime = try P1F1D076LifetimeCapsule(
        provider: provider,
        probe: probe
    )
    let canonical = lifetime.canonical
    let workflow = P1F1D076ExternalWorkflow(failsRecovery: false)
    let orchestrator = try p1f1d076Orchestrator(
        fixture: canonical,
        environment: lifetime.environment,
        provider: provider,
        probe: probe,
        workflow: workflow,
        requiresStartupRecovery: false
    )
    await orchestrator.recoverAndReconcile()
    guard await workflow.snapshot().recoveries == 1 else {
        throw EngineContextValidationErrorV1()
    }
    await workflow.setFailsRecovery(true)
    let cause = try p1f1d076AppendReadyCause(canonical)
    let identity = EngineDispatchIdentityV1(
        campId: canonical.camp.id,
        cardId: canonical.card.id,
        companionId: canonical.companion.id,
        cause: cause
    )
    await orchestrator.reconcile()
    await provider.waitUntilStarted()

    let runtime = try await orchestrator.engineExecutionRuntime()
    let registry = try await runtime.registry(
        requestedProfileKinds: [.openAIAPI]
    )
    let store = p1f1d076Store(fixture: canonical, registry: registry)
    let execution = try await canonical.db.pool.read { database in
        try #require(
            try EngineExecutionRecord
                .filter(Column("cardId") == canonical.card.id)
                .filter(
                    Column("state")
                        == EngineExecutionStateV1.running.rawValue
                )
                .fetchOne(database)
        )
    }
    let request = try CanonicalContractCodingV1.decode(
        EngineExecutionRequest.self,
        from: Data(execution.requestJson.utf8)
    )
    #expect(request.executionId == execution.id)
    try p1f1d076RequestDeletion(canonical)
    return P1F1D076PendingFixture(
        lifetime: lifetime,
        orchestrator: orchestrator,
        runtime: runtime,
        store: store,
        request: request,
        identity: identity,
        probe: probe,
        workflow: workflow
    )
}

private func p1f1d076AssertPendingSummary(
    _ fixture: P1F1D076PendingFixture
) async throws {
    let summary = try await fixture.runtime.recover(
        missionId: nil,
        now: P1F1DCanonicalExecutionFixture.now.addingTimeInterval(10)
    )
    #expect(summary.scannedCount == 1)
    #expect(summary.terminalReceipts.isEmpty)
    #expect(summary.directives.count == 1)
    #expect(summary.directives.first?.executionId == fixture.request.executionId)
    #expect(summary.directives.first?.request == nil)
    #expect(
        summary.directives.first?.action
            == .deferCampDeletion(proposalId: nil)
    )
}

private func p1f1d076AssertLifetimeIdentity(
    _ fixture: P1F1D076PendingFixture
) {
    #expect(
        fixture.lifetime.environment.database
            === fixture.lifetime.canonical.db
    )
    #expect(
        fixture.lifetime.environment.stateDirectoryLock
            === fixture.lifetime.stateDirectoryLock
    )
}

private func p1f1d076AssertIndependentLockRejected(
    _ fixture: P1F1D076PendingFixture
) throws {
    do {
        _ = try StateDirectoryLock(
            directoryURL: fixture.canonical.root
        )
        Issue.record("same-root independent lock unexpectedly succeeded")
    } catch let error as StateDirectoryLockError {
        switch error {
        case .alreadyLocked(let path, let code):
            #expect(
                path
                    == fixture.lifetime.stateDirectoryLock
                        .lockFileURL.path
            )
            #expect(
                Set<Int32>([EWOULDBLOCK, EAGAIN, EACCES])
                    .contains(code)
            )
        default:
            Issue.record("same-root lock failed with wrong error: \(error)")
        }
    }
}

private func p1f1d076ExpectAuthorityClosed(
    _ label: String,
    operation: @escaping @Sendable () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("sealed runtime accepted \(label)")
    } catch let error as EngineRuntimeAuthorityErrorV1 {
        #expect(error == .authorityClosed)
    } catch {
        Issue.record("sealed runtime returned wrong \(label) error: \(error)")
    }
}

private func p1f1d076AssertRuntimeSealed(
    _ fixture: P1F1D076PendingFixture
) async throws {
    let stable = try p1f1d076PendingProjection(fixture)
    let probe = fixture.probe.snapshot
    let workflow = await fixture.workflow.snapshot()
    await p1f1d076ExpectAuthorityClosed("registry") {
        _ = try await fixture.runtime.registry(
            requestedProfileKinds: [.openAIAPI]
        )
    }
    await p1f1d076ExpectAuthorityClosed("prepare") {
        _ = try await fixture.runtime.prepare(fixture.identity)
    }
    await p1f1d076ExpectAuthorityClosed("recover") {
        _ = try await fixture.runtime.recover(
            missionId: nil,
            now: P1F1DCanonicalExecutionFixture.now
                .addingTimeInterval(20)
        )
    }
    await p1f1d076ExpectAuthorityClosed("cancel") {
        try await fixture.runtime.cancel(
            executionId: fixture.request.executionId,
            reason: "p1f1d-076-sealed-runtime"
        )
    }
    #expect(try p1f1d076PendingProjection(fixture) == stable)
    let afterProbe = fixture.probe.snapshot
    #expect(
        afterProbe.cliDriverConstructions
            == probe.cliDriverConstructions
    )
    #expect(afterProbe.processSnapshots == probe.processSnapshots)
    #expect(afterProbe.processSignals == probe.processSignals)
    #expect(afterProbe.processGroupChecks == probe.processGroupChecks)
    let afterWorkflow = await fixture.workflow.snapshot()
    #expect(afterWorkflow.recoveries == workflow.recoveries)
    #expect(afterWorkflow.executions == workflow.executions)
}

private let p1f1d076PendingCode = "engine_recovery_pending_f2"
private let p1f1d076PendingDescription =
    "Engine recovery is waiting for sealed deferred cleanup."

private func p1f1d076PendingErrorPayloads(
    database: AppDatabase,
    missionId: String
) throws -> [String] {
    try database.events(missionId: missionId).compactMap { event in
        guard event.kind == EventKind.kernelError else { return nil }
        let bytes = Data(event.payloadJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
        let value = try JSONValue.decoded(from: event.payloadJson)
        guard let object = value.objectValue,
              Set(object.keys) == ["code", "description"],
              object["code"]?.stringValue == p1f1d076PendingCode,
              object["description"]?.stringValue
                == p1f1d076PendingDescription
        else {
            return nil
        }
        return event.payloadJson
    }
}

private func p1f1d076LifecycleErrorPayloads(
    database: AppDatabase,
    missionId: String
) throws -> [String] {
    try database.events(missionId: missionId).compactMap { event in
        guard event.kind == EventKind.kernelError else { return nil }
        let bytes = Data(event.payloadJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
        let value = try JSONValue.decoded(from: event.payloadJson)
        guard let object = value.objectValue,
              Set(object.keys) == ["code", "description"],
              object["code"]?.stringValue != nil,
              object["description"]?.stringValue != nil
        else {
            return nil
        }
        return event.payloadJson
    }
}

@Test func p1f1_076OrchestratorSelectsByRequiredCapabilitiesNotProfileKind()
    async throws
{
    let executionFixture = try P1F1DCanonicalExecutionFixture(
        replayClass: .idempotencyKeyed,
        profileKind: .openAIAPI
    )
    let probe = P1F1D076FactoryProbe()
    let selectedId = "agentloop.selected-runtime"
    let unselectedId = "agentloop.unselected-runtime"
    let selectedFactory = p1f1d076Factory(
        adapterId: selectedId,
        kind: .openAIAPI,
        sessionResume: .supported,
        probe: probe
    )
    let unselectedFactory = p1f1d076Factory(
        adapterId: unselectedId,
        kind: .anthropicAPI,
        sessionResume: .unsupported,
        probe: probe
    )
    let registry = try EngineAdapterRegistryV1(
        // Reverse product order so a first/fallback selector cannot pass.
        factories: [unselectedFactory, selectedFactory],
        helpSnapshots: [:]
    )
    let selection = try registry.resolve(
        profile: executionFixture.profile,
        requiredCapabilities: [.boardTerminal, .sessionResume]
    )

    #expect(selection.descriptor.adapterId == selectedId)
    #expect(selection.descriptor.profileKind == .openAIAPI)
    #expect(
        selection.descriptor.support(for: .sessionResume) == .supported
    )
    #expect(probe.descriptorCount(selectedId) == 1)
    #expect(probe.descriptorCount(unselectedId) == 0)

    let modelProfile = RuntimeProfileRecord(
        id: "50000000-0000-4000-8000-000000000076",
        kind: .anthropicAPI,
        name: "P1-F1D ModelLoop",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )
    do {
        _ = try registry.resolve(
            profile: modelProfile,
            requiredCapabilities: [.sessionResume]
        )
        Issue.record(
            "matching profile kind must not bypass a required capability"
        )
    } catch let error as EngineAdapterSelectionErrorV1 {
        #expect(error == .unsupportedCapability(.sessionResume))
    } catch {
        throw error
    }
    #expect(probe.descriptorCount(unselectedId) == 1)
    #expect(probe.descriptorCount(selectedId) == 1)
    #expect(probe.makeCount(unselectedId) == 0)

    // Drive the reviewed runtime surface itself. Preparation selects and
    // captures once; execute is the only transport/adapter construction point.
    let runtimeProbe = P1F1D076LifecycleProbe()
    let runtimeProvider = MockProvider(script: [])
    let runtimeStateDirectoryLock = try StateDirectoryLock(
        directoryURL: executionFixture.root
    )
    let runtimeEnvironment = try p1f1d076Environment(
        fixture: executionFixture,
        stateDirectoryLock: runtimeStateDirectoryLock,
        provider: runtimeProvider,
        probe: runtimeProbe
    )
    let runtime = EngineExecutionRuntimeV1(
        environment: runtimeEnvironment,
        factories: [unselectedFactory, selectedFactory],
        eventObserver: { _, _ in }
    )
    let cause = try p1f1d076AppendReadyCause(executionFixture)
    let identity = EngineDispatchIdentityV1(
        campId: executionFixture.camp.id,
        cardId: executionFixture.card.id,
        companionId: executionFixture.companion.id,
        cause: cause
    )
    let prepared = try await runtime.prepare(identity)
    #expect(prepared.idempotencyKey == cause.idempotencyKey)
    #expect(prepared.requestFields.campId == executionFixture.camp.id)
    #expect(prepared.requestFields.cardId == executionFixture.card.id)
    #expect(prepared.requestFields.profileId == executionFixture.profile.id)
    #expect(prepared.requestFields.engineKind == selectedId)
    #expect(prepared.selected.descriptor.adapterId == selectedId)
    #expect(probe.prepareCount(selectedId) == 1)
    #expect(probe.prepareCount(unselectedId) == 0)
    #expect(probe.transportCount(selectedId) == 0)
    #expect(probe.makeCount(selectedId) == 0)
    #expect(runtimeProbe.snapshot.cliDriverConstructions == 0)

    let bindRecorder = P1F1D076BindRecorder()
    let receipt = try await runtime.execute(
        prepared,
        onExecutionBound: { request in
            await bindRecorder.dispatch(request)
        }
    )
    #expect(receipt.terminalKind == .blocked)
    #expect(receipt.terminalSubtype == .engineProtocolError)
    let boundRequests = await bindRecorder.snapshot()
    #expect(boundRequests.count == 1)
    #expect(boundRequests.first?.cardId == executionFixture.card.id)
    #expect(probe.prepareCount(selectedId) == 1)
    #expect(probe.transportCount(selectedId) == 1)
    #expect(probe.recoveryTransportCount(selectedId) == 0)
    #expect(probe.makeCount(selectedId) == 1)
    #expect(probe.makeCount(unselectedId) == 0)
    #expect(
        probe.boundNames(selectedId)
            == [
                prepared.context.capabilityTools.logicalDefinitions
                    .map(\.name),
            ]
    )
    #expect(runtimeProbe.snapshot.cliDriverConstructions == 0)
    try await runtime.cancel(
        executionId: receipt.executionId,
        reason: "p1f1d-076-terminal-won"
    )
    let terminalRecovery = try await runtime.recover(
        missionId: nil,
        now: P1F1DCanonicalExecutionFixture.now.addingTimeInterval(2)
    )
    #expect(terminalRecovery.scannedCount == 0)
    #expect(terminalRecovery.directives.isEmpty)

    // A durable prepared row is recovered through the same runtime generation.
    let recoveryFixture = try P1F1DCanonicalExecutionFixture(
        replayClass: .idempotencyKeyed,
        profileKind: .openAIAPI
    )
    let recoveryProbe = P1F1D076FactoryProbe()
    let recoveryLifecycleProbe = P1F1D076LifecycleProbe()
    let recoverySelected = p1f1d076Factory(
        adapterId: selectedId,
        kind: .openAIAPI,
        sessionResume: .supported,
        probe: recoveryProbe
    )
    let recoveryUnselected = p1f1d076Factory(
        adapterId: unselectedId,
        kind: .anthropicAPI,
        sessionResume: .unsupported,
        probe: recoveryProbe
    )
    let recoveryStateDirectoryLock = try StateDirectoryLock(
        directoryURL: recoveryFixture.root
    )
    let recoveryEnvironment = try p1f1d076Environment(
        fixture: recoveryFixture,
        stateDirectoryLock: recoveryStateDirectoryLock,
        provider: MockProvider(script: []),
        probe: recoveryLifecycleProbe
    )
    let recoveryRuntime = EngineExecutionRuntimeV1(
        environment: recoveryEnvironment,
        factories: [recoveryUnselected, recoverySelected],
        eventObserver: { _, _ in }
    )
    let recoveryCause = try p1f1d076AppendReadyCause(recoveryFixture)
    let recoveryPrepared = try await recoveryRuntime.prepare(
        EngineDispatchIdentityV1(
            campId: recoveryFixture.camp.id,
            cardId: recoveryFixture.card.id,
            companionId: recoveryFixture.companion.id,
            cause: recoveryCause
        )
    )
    let recoveryRegistry = try await recoveryRuntime.registry(
        requestedProfileKinds: [.openAIAPI]
    )
    let recoveryStore = p1f1d076Store(
        fixture: recoveryFixture,
        registry: recoveryRegistry
    )
    let interrupted = try recoveryStore.beginEngineExecution(
        requestFields: recoveryPrepared.requestFields,
        idempotencyKey: recoveryPrepared.idempotencyKey
    )
    let preparedRow = try p1f1ExecutionRow(
        recoveryFixture.db,
        id: interrupted.executionId
    )
    #expect((preparedRow["dispatchState"] as String) == "prepared")
    let recovered = try await recoveryRuntime.recover(
        missionId: nil,
        now: P1F1DCanonicalExecutionFixture.now.addingTimeInterval(3)
    )
    #expect(recovered.scannedCount == 1)
    #expect(recovered.directives.isEmpty)
    #expect(recovered.terminalReceipts.count == 1)
    #expect(recovered.terminalReceipts.first?.terminalKind == .blocked)
    #expect(recoveryProbe.prepareCount(selectedId) == 1)
    #expect(recoveryProbe.transportCount(selectedId) == 0)
    #expect(recoveryProbe.recoveryTransportCount(selectedId) == 1)
    #expect(recoveryProbe.makeCount(selectedId) == 1)
    #expect(recoveryProbe.makeCount(unselectedId) == 0)
    #expect(recoveryLifecycleProbe.snapshot.cliDriverConstructions == 0)

    // Pending F2 is a durable Store state, not an in-memory handoff. Each
    // lifecycle consumer sees it twice from the unchanged row.
    do {
        let startup = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: true
        )
        let stable = try p1f1d076PendingProjection(startup)
        await startup.orchestrator.recoverAndReconcile()
        #expect(await startup.orchestrator.isHalted)
        #expect(
            try p1f1d076PendingErrorPayloads(
                database: startup.canonical.db,
                missionId: ""
            ).count == 1
        )
        do {
            try await startup.orchestrator.resume()
            Issue.record("startup retry accepted pending F2")
        } catch let error as EngineRecoveryPendingF2ErrorV1 {
            #expect(error == EngineRecoveryPendingF2ErrorV1())
            #expect(error.code == p1f1d076PendingCode)
            #expect(error.errorDescription == p1f1d076PendingDescription)
        }
        #expect(try p1f1d076PendingProjection(startup) == stable)
        #expect(await startup.workflow.snapshot().recoveries == 2)
        #expect(startup.probe.snapshot.cliDriverConstructions == 0)
        try await p1f1d076AssertPendingSummary(startup)
    }

    do {
        let manual = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false,
            initiallyHalted: true
        )
        let stable = try p1f1d076PendingProjection(manual)
        for _ in 0..<2 {
            do {
                try await manual.orchestrator.resume()
                Issue.record("manual resume accepted pending F2")
            } catch let error as EngineRecoveryPendingF2ErrorV1 {
                #expect(error == EngineRecoveryPendingF2ErrorV1())
                #expect(error.code == p1f1d076PendingCode)
                #expect(error.errorDescription == p1f1d076PendingDescription)
            }
            #expect(try p1f1d076PendingProjection(manual) == stable)
            #expect(await manual.orchestrator.isHalted)
        }
        #expect(await manual.workflow.snapshot().recoveries == 3)
        #expect(manual.probe.snapshot.cliDriverConstructions == 0)
    }

    do {
        let emergency = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false
        )
        let stable = try p1f1d076PendingProjection(emergency)
        for _ in 0..<2 {
            do {
                try await emergency.orchestrator.emergencyStop()
                Issue.record("emergency stop reported settled pending F2")
            } catch let error as EngineRecoveryPendingF2ErrorV1 {
                #expect(error == EngineRecoveryPendingF2ErrorV1())
                #expect(error.code == p1f1d076PendingCode)
                #expect(error.errorDescription == p1f1d076PendingDescription)
            }
            #expect(try p1f1d076PendingProjection(emergency) == stable)
            #expect(await emergency.orchestrator.isHalted)
        }
        #expect(await emergency.workflow.snapshot().recoveries == 3)
        #expect(emergency.probe.snapshot.cliDriverConstructions == 0)
    }

    do {
        let mission = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false
        )
        let stable = try p1f1d076PendingProjection(mission)
        for attempt in 1...2 {
            await mission.orchestrator.cancelMission(
                mission.canonical.mission.id
            )
            #expect(try p1f1d076PendingProjection(mission) == stable)
            #expect(
                try p1f1d076PendingErrorPayloads(
                    database: mission.canonical.db,
                    missionId: mission.canonical.mission.id
                ).count == attempt
            )
        }
        #expect(await mission.workflow.snapshot().recoveries == 3)
        #expect(mission.probe.snapshot.cliDriverConstructions == 0)
    }

    do {
        let shutdown = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false
        )
        p1f1d076AssertLifetimeIdentity(shutdown)
        let stable = try p1f1d076PendingProjection(shutdown)
        _ = await shutdown.orchestrator.shutdown()
        #expect(try p1f1d076PendingProjection(shutdown) == stable)
        #expect(
            try p1f1d076PendingErrorPayloads(
                database: shutdown.canonical.db,
                missionId: ""
            ).count == 1
        )
        #expect(await shutdown.workflow.snapshot().recoveries == 2)
        try await p1f1d076AssertRuntimeSealed(shutdown)
        try p1f1d076AssertIndependentLockRejected(shutdown)

        let nextProbe = P1F1D076LifecycleProbe()
        let nextWorkflow = P1F1D076ExternalWorkflow(
            failsRecovery: false
        )
        #expect(
            shutdown.lifetime.environment.database
                === shutdown.canonical.db
        )
        #expect(
            shutdown.lifetime.environment.stateDirectoryLock
                === shutdown.lifetime.stateDirectoryLock
        )
        let next = try p1f1d076Orchestrator(
            fixture: shutdown.canonical,
            environment: shutdown.lifetime.environment,
            provider: MockProvider(script: []),
            probe: nextProbe,
            workflow: nextWorkflow,
            requiresStartupRecovery: true
        )
        let nextRuntime = try await next.engineExecutionRuntime()
        #expect(nextRuntime !== shutdown.runtime)
        await next.recoverAndReconcile()
        #expect(await next.isHalted)
        #expect(try p1f1d076PendingProjection(shutdown) == stable)
        #expect(
            try p1f1d076PendingErrorPayloads(
                database: shutdown.canonical.db,
                missionId: ""
            ).count == 2
        )
        #expect(await nextWorkflow.snapshot().recoveries == 1)
        #expect(nextProbe.snapshot.cliDriverConstructions == 0)
        let nextFixture = P1F1D076PendingFixture(
            lifetime: shutdown.lifetime,
            orchestrator: next,
            runtime: nextRuntime,
            store: shutdown.store,
            request: shutdown.request,
            identity: shutdown.identity,
            probe: nextProbe,
            workflow: nextWorkflow
        )
        _ = await next.shutdown()
        try await p1f1d076AssertRuntimeSealed(nextFixture)
    }

    // Pending F2 remains the first failure while every authorized later
    // external cleanup is attempted exactly once.
    do {
        let emergency = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false,
            workflowFails: true
        )
        let stable = try p1f1d076PendingProjection(emergency)
        do {
            try await emergency.orchestrator.emergencyStop()
            Issue.record("later cleanup replaced pending F2")
        } catch let error as EngineRecoveryPendingF2ErrorV1 {
            #expect(error == EngineRecoveryPendingF2ErrorV1())
        }
        #expect(await emergency.workflow.snapshot().recoveries == 2)
        #expect(try p1f1d076PendingProjection(emergency) == stable)
    }

    do {
        let shutdown = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false,
            workflowFails: true
        )
        let stable = try p1f1d076PendingProjection(shutdown)
        _ = await shutdown.orchestrator.shutdown()
        #expect(await shutdown.workflow.snapshot().recoveries == 2)
        #expect(try p1f1d076PendingProjection(shutdown) == stable)
        #expect(
            try p1f1d076PendingErrorPayloads(
                database: shutdown.canonical.db,
                missionId: ""
            ).count == 1
        )
        try await p1f1d076AssertRuntimeSealed(shutdown)
    }

    do {
        let mission = try await p1f1d076MakePendingFixture(
            requiresStartupRecovery: false,
            workflowFails: true
        )
        let stable = try p1f1d076PendingProjection(mission)
        await mission.orchestrator.cancelMission(
            mission.canonical.mission.id
        )
        #expect(await mission.workflow.snapshot().recoveries == 2)
        #expect(try p1f1d076PendingProjection(mission) == stable)
        #expect(
            try p1f1d076PendingErrorPayloads(
                database: mission.canonical.db,
                missionId: mission.canonical.mission.id
            ).count == 1
        )
    }

    // An earlier bound-execution cancellation failure remains first while
    // pending F2 and the later external cleanup are still attempted once.
    do {
        let emergency = try await p1f1d076MakeBoundPendingFixture()
        let stable = try p1f1d076PendingProjection(emergency)
        do {
            try await emergency.orchestrator.emergencyStop()
            Issue.record("earlier engine cancel failure was swallowed")
        } catch let error as CampLifecycleWriteAuthorizationError {
            #expect(
                error == .lifecycleVersionMismatch(
                    expected: emergency.request.campLifecycleVersion,
                    actual: emergency.request.campLifecycleVersion + 1
                )
            )
        }
        #expect(await emergency.workflow.snapshot().recoveries == 2)
        #expect(try p1f1d076PendingProjection(emergency) == stable)
        #expect(await emergency.orchestrator.isHalted)
        #expect(emergency.probe.snapshot.cliDriverConstructions == 0)
        try await p1f1d076AssertPendingSummary(emergency)
    }

    do {
        let shutdown = try await p1f1d076MakeBoundPendingFixture()
        let stable = try p1f1d076PendingProjection(shutdown)
        _ = await shutdown.orchestrator.shutdown()
        #expect(await shutdown.workflow.snapshot().recoveries == 2)
        #expect(try p1f1d076PendingProjection(shutdown) == stable)
        let payloads = try p1f1d076LifecycleErrorPayloads(
            database: shutdown.canonical.db,
            missionId: ""
        )
        #expect(payloads.count == 1)
        let payload = try JSONValue.decoded(
            from: try #require(payloads.first)
        )
        #expect(payload["code"]?.stringValue != p1f1d076PendingCode)
        #expect(
            payload["description"]?.stringValue
                != p1f1d076PendingDescription
        )
        #expect(shutdown.probe.snapshot.cliDriverConstructions == 0)
        try await p1f1d076AssertRuntimeSealed(shutdown)
    }

    do {
        let mission = try await p1f1d076MakeBoundPendingFixture()
        let stable = try p1f1d076PendingProjection(mission)
        await mission.orchestrator.cancelMission(
            mission.canonical.mission.id
        )
        #expect(await mission.workflow.snapshot().recoveries == 2)
        #expect(try p1f1d076PendingProjection(mission) == stable)
        let payloads = try p1f1d076LifecycleErrorPayloads(
            database: mission.canonical.db,
            missionId: mission.canonical.mission.id
        )
        #expect(payloads.count == 1)
        let payload = try JSONValue.decoded(
            from: try #require(payloads.first)
        )
        #expect(payload["code"]?.stringValue != p1f1d076PendingCode)
        #expect(
            payload["description"]?.stringValue
                != p1f1d076PendingDescription
        )
        #expect(mission.probe.snapshot.cliDriverConstructions == 0)
    }

    #expect(probe.descriptorCount(unselectedId) == 1)
    #expect(probe.makeCount(unselectedId) == 0)
}
