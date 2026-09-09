import Foundation
import GRDB
import Testing
import AgentLoopCore

private struct R01FailureFirstFixture {
    let database: AppDatabase
    let root: URL
    let camp: CampRecord
    let companion: CompanionRecord
    let profile: RuntimeProfileRecord
    let resolver: R01PlanningResolver
}

private final class R01PlanningResolver:
    PlanningProviderResolver, @unchecked Sendable
{
    private let lock = NSLock()
    private let provider: any LLMProvider
    private let onResolve: @Sendable () throws -> Void
    private var resolveCountStorage = 0

    init(
        provider: any LLMProvider = MockProvider(script: []),
        onResolve: @escaping @Sendable () throws -> Void = {}
    ) {
        self.provider = provider
        self.onResolve = onResolve
    }

    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider {
        lock.lock()
        resolveCountStorage += 1
        lock.unlock()
        try onResolve()
        return provider
    }

    var resolveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return resolveCountStorage
    }
}

private enum R01ResolverError: Error {
    case unavailable
}

private final class R11MutablePlanningProfileSource:
    PlanningRuntimeProfileSource, @unchecked Sendable
{
    private let lock = NSLock()
    private var profiles: [String: RuntimeProfileRecord]
    private var requestedIdsStorage: [String] = []

    init(_ profiles: [RuntimeProfileRecord]) {
        self.profiles = Dictionary(
            uniqueKeysWithValues: profiles.map { ($0.id, $0) }
        )
    }

    func planningRuntimeProfile(id: String) throws -> RuntimeProfileRecord? {
        lock.withLock {
            requestedIdsStorage.append(id)
            return profiles[id]
        }
    }

    func replace(_ profile: RuntimeProfileRecord) {
        lock.withLock {
            profiles[profile.id] = profile
        }
    }

    func remove(id: String) {
        _ = lock.withLock {
            profiles.removeValue(forKey: id)
        }
    }

    var requestedIds: [String] {
        lock.withLock { requestedIdsStorage }
    }
}

private final class R11MutablePlanningCatalogSource:
    PlanningModelCatalogSource, @unchecked Sendable
{
    private let lock = NSLock()
    private var cached: [String: [String]]
    private var choices: [String: [String]]
    private var manual: [String: [String]]

    init(
        cached: [String: [String]] = [:],
        choices: [String: [String]] = [:],
        manual: [String: [String]] = [:]
    ) {
        self.cached = cached
        self.choices = choices
        self.manual = manual
    }

    func planningCachedCatalog(profileId: String) throws -> [String]? {
        lock.withLock { cached[profileId] }
    }

    func planningModelChoices(profileId: String) throws -> [String]? {
        lock.withLock { choices[profileId] }
    }

    func planningManualModels(profileId: String) throws -> [String] {
        lock.withLock { manual[profileId] ?? [] }
    }

    func setCached(_ models: [String]?, profileId: String) {
        lock.withLock {
            cached[profileId] = models
        }
    }

    func setChoices(_ models: [String]?, profileId: String) {
        lock.withLock {
            choices[profileId] = models
        }
    }

    func setManual(_ models: [String], profileId: String) {
        lock.withLock {
            manual[profileId] = models
        }
    }
}

private final class R11MutablePlanningCredentialSource:
    PlanningCredentialSource, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [String: String]
    private var requestedAccountsStorage: [String] = []

    init(values: [String: String]) {
        self.values = values
    }

    func planningCredential(account: String) throws -> String? {
        lock.withLock {
            requestedAccountsStorage.append(account)
            return values[account]
        }
    }

    func set(_ value: String?, account: String) {
        lock.withLock {
            values[account] = value
        }
    }

    var requestedAccounts: [String] {
        lock.withLock { requestedAccountsStorage }
    }
}

private final class R11PlanningProviderFactory:
    PlanningProviderFactory, @unchecked Sendable
{
    struct APICall: Sendable, Equatable {
        let format: ProviderAPIFormat
        let credential: String
        let model: String
        let baseURL: URL
    }

    private let lock = NSLock()
    private let provider: any LLMProvider
    private var apiCallsStorage: [APICall] = []

    init(provider: any LLMProvider) {
        self.provider = provider
    }

    func makePlanningAPIProvider(
        format: ProviderAPIFormat,
        credential: String,
        model: String,
        baseURL: URL
    ) throws -> any LLMProvider {
        lock.withLock {
            apiCallsStorage.append(
                APICall(
                    format: format,
                    credential: credential,
                    model: model,
                    baseURL: baseURL
                )
            )
        }
        return provider
    }

    func makePlanningOAuthProvider(
        accessToken: String,
        accountId: String,
        model: String
    ) throws -> any LLMProvider {
        provider
    }

    var apiCalls: [APICall] {
        lock.withLock { apiCallsStorage }
    }
}

private actor R11DurablePlannerProvider: LLMProvider {
    private var turns: [TurnResult]
    private(set) var callCount = 0

    init(turns: [TurnResult]) {
        self.turns = turns
    }

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let turn = await self.next() else {
                    continuation.finish(
                        throwing: ProviderError.malformedStream(
                            "R11 planner script exhausted"
                        )
                    )
                    return
                }
                continuation.yield(.turn(turn))
                continuation.finish()
            }
        }
    }

    private func next() -> TurnResult? {
        callCount += 1
        guard !turns.isEmpty else {
            return nil
        }
        return turns.removeFirst()
    }
}

private actor R01BlockingGate {
    private var entered = false
    private var continuation: CheckedContinuation<Void, Never>?

    func block() async {
        entered = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilEntered() async {
        while !entered {
            await Task.yield()
        }
    }

    func release() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

private final class R01GateProvider: LLMProvider, @unchecked Sendable {
    let gate = R01BlockingGate()
    private let lock = NSLock()
    private var callCountStorage = 0

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        lock.lock()
        callCountStorage += 1
        lock.unlock()
        return AsyncThrowingStream<ProviderEvent, Error> { continuation in
            Task {
                await self.gate.block()
                continuation.yield(.turn(r01ValidPlanTurn()))
                continuation.finish()
            }
        }
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCountStorage
    }
}

private actor R01CompletionFlag {
    private(set) var value = false

    func markComplete() {
        value = true
    }
}

private final class R01CancellationIgnoringProvider:
    LLMProvider, @unchecked Sendable
{
    private let condition = NSCondition()
    private var started = false
    private var released = false

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        condition.lock()
        started = true
        condition.broadcast()
        while !released {
            condition.wait()
        }
        condition.unlock()
        return AsyncThrowingStream { continuation in
            continuation.yield(.turn(r01ValidPlanTurn()))
            continuation.finish()
        }
    }

    func waitUntilStarted() async {
        while !hasStarted {
            await Task.yield()
        }
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }

    private var hasStarted: Bool {
        condition.lock()
        defer { condition.unlock() }
        return started
    }
}

private final class R01SQLGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var entered = false
    private var released = false

    func enterAndWait() {
        condition.lock()
        entered = true
        condition.broadcast()
        while !released {
            condition.wait()
        }
        condition.unlock()
    }

    func waitUntilEntered() async {
        while !hasEntered {
            await Task.yield()
        }
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }

    private var hasEntered: Bool {
        condition.lock()
        defer { condition.unlock() }
        return entered
    }
}

@MainActor
private final class R01UUIDSequence {
    private var nextValue = 0

    func next() -> String {
        nextValue += 1
        return "r01-uuid-\(nextValue)"
    }

    var callCount: Int {
        nextValue
    }
}

@MainActor
private struct R01CoordinatorHarness {
    let coordinator: PlanningEntryCoordinator
    let orchestrator: Orchestrator
    let uuidSequence: R01UUIDSequence
}

private struct A3CandidateMissionDetail: Codable, Sendable, Equatable {
    let goal: String
    let why: String
    let acceptance: [String]
}

private struct A3MissionSnapshot: Sendable, Equatable {
    let id: String
    let squadId: String
    let goalRaw: String
    let goalRefined: String
    let status: MissionStatus
    let budgetTokens: Int
    let spentTokens: Int
    let revision: Int
    let autonomy: MissionAutonomy
    let createdAt: Date

    init(_ mission: MissionRecord) {
        id = mission.id
        squadId = mission.squadId
        goalRaw = mission.goalRaw
        goalRefined = mission.goalRefined
        status = mission.status
        budgetTokens = mission.budgetTokens
        spentTokens = mission.spentTokens
        revision = mission.revision
        autonomy = mission.autonomy
        createdAt = mission.createdAt
    }
}

private struct A3SquadSnapshot: Sendable, Equatable {
    let id: String
    let campId: String
    let name: String
    let memberIdsJson: String
    let workspacePath: String?
    let workspaceBookmark: Data?
    let createdAt: Date

    init(_ squad: SquadRecord) {
        id = squad.id
        campId = squad.campId
        name = squad.name
        memberIdsJson = squad.memberIdsJson
        workspacePath = squad.workspacePath
        workspaceBookmark = squad.workspaceBookmark
        createdAt = squad.createdAt
    }
}

private struct A3EventSnapshot: Sendable, Equatable {
    let id: String
    let missionId: String?
    let cardId: String?
    let runId: String?
    let kind: String
    let payloadJson: String
    let createdAt: Date

    init(_ event: EventRecord) {
        id = event.id
        missionId = event.missionId
        cardId = event.cardId
        runId = event.runId
        kind = event.kind
        payloadJson = event.payloadJson
        createdAt = event.createdAt
    }
}

private struct A3BusinessSnapshot: Sendable, Equatable {
    let squadCount: Int
    let missionCount: Int
    let workCount: Int
    let durableAttemptCount: Int
    let durableAttemptEventCount: Int
    let cardCount: Int
    let eventCount: Int
    let ingestionCount: Int
    let noteCount: Int
    let sourceLinkCount: Int
    let candidate: ActionCandidateRecord?
    let mission: A3MissionSnapshot?
    let squad: A3SquadSnapshot?
    let work: DurableWorkRecord?
    let workAttempts: [DurableWorkAttemptRecord]
    let workAttemptEvents: [DurableWorkAttemptEventRecord]
    let missionEvents: [A3EventSnapshot]
}

#if DEBUG
private actor A3ObservationBarrier {
    private let target: Int
    private var entered = 0
    private var released = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(target: Int) {
        precondition(target > 0)
        self.target = target
    }

    func enterAndWait() async {
        entered += 1
        if entered >= target {
            let waiters = readyWaiters
            readyWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
        guard !released else { return }
        await withCheckedContinuation { continuation in
            if released {
                continuation.resume()
            } else {
                releaseWaiters.append(continuation)
            }
        }
    }

    func waitUntilReady() async {
        guard entered < target else { return }
        await withCheckedContinuation { continuation in
            if entered >= target {
                continuation.resume()
            } else {
                readyWaiters.append(continuation)
            }
        }
    }

    func release() {
        guard !released else { return }
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private struct A3ObservationCounts: Sendable, Equatable {
    var ensureTick = 0
    var planningStarted = 0
    var kick = 0
}

private struct A3PreDispatchEvidence: Sendable, Equatable {
    let writerTotalChanges: Int
    let resolverCount: Int
    let snapshot: A3BusinessSnapshot
}

private struct A3ObservationProbeSnapshot: Sendable, Equatable {
    let counts: A3ObservationCounts
    let preDispatch: [A3PreDispatchEvidence]
    let captureFailures: [String]
}

private actor A3PostCommitObservationProbe {
    private let ensureTickBarrier: A3ObservationBarrier?
    private var counts = A3ObservationCounts()
    private var preDispatch: [A3PreDispatchEvidence] = []
    private var captureFailures: [String] = []

    init(ensureTickBarrier: A3ObservationBarrier? = nil) {
        self.ensureTickBarrier = ensureTickBarrier
    }

    func record(
        _ observation: A3CandidatePostCommitObservationForTesting,
        evidence: A3PreDispatchEvidence?,
        captureFailure: String?
    ) async {
        switch observation {
        case .ensureTick:
            counts.ensureTick += 1
            if let evidence {
                preDispatch.append(evidence)
            }
            if let captureFailure {
                captureFailures.append(captureFailure)
            }
            await ensureTickBarrier?.enterAndWait()
        case .planningStarted:
            counts.planningStarted += 1
        case .kick:
            counts.kick += 1
        }
    }

    func snapshot() -> A3ObservationProbeSnapshot {
        A3ObservationProbeSnapshot(
            counts: counts,
            preDispatch: preDispatch,
            captureFailures: captureFailures
        )
    }
}
#endif

private enum A3DedicatedThreadRaceHarnessError: Error, Equatable {
    case peerAborted(index: Int, abortedBy: Int)
    case duplicateRendezvous(index: Int)
    case duplicateOutcome(index: Int)
    case completedBeforeRendezvous(index: Int)
    case missingOutcome(index: Int)
}

private struct A3DedicatedThreadRaceFailure:
    Error, @unchecked Sendable, CustomStringConvertible
{
    let index: Int
    let underlying: any Error

    var description: String {
        "A3 dedicated-thread operation \(index) failed: \(underlying)"
    }
}

private enum A3DedicatedThreadCandidateOutcome: @unchecked Sendable {
    case success(CandidatePlanningStartResult)
    case failure(any Error)
}

private final class A3DedicatedThreadHandle: @unchecked Sendable {
    private let thread: Thread

    init(_ thread: Thread) {
        self.thread = thread
    }

    var name: String? {
        get { thread.name }
        set { thread.name = newValue }
    }

    var isFinished: Bool {
        thread.isFinished
    }

    func start() {
        thread.start()
    }
}

private final class A3DedicatedThreadCandidateRaceState:
    @unchecked Sendable
{
    private let condition = NSCondition()
    private var arrivedIndices: Set<Int> = []
    private var released = false
    private var abortedBy: Int?
    private var indexedOutcomes:
        [A3DedicatedThreadCandidateOutcome?] = [nil, nil]
    private var storageFailure: A3DedicatedThreadRaceHarnessError?

    func rendezvous(index: Int) throws {
        condition.lock()
        defer { condition.unlock() }
        guard abortedBy == nil else {
            throw A3DedicatedThreadRaceHarnessError.peerAborted(
                index: index,
                abortedBy: abortedBy ?? index
            )
        }
        guard arrivedIndices.insert(index).inserted else {
            recordAbortLocked(index: index)
            throw A3DedicatedThreadRaceHarnessError
                .duplicateRendezvous(index: index)
        }
        if arrivedIndices.count == 2 {
            released = true
            condition.broadcast()
        }
        while !released, abortedBy == nil {
            condition.wait()
        }
        if let abortedBy {
            throw A3DedicatedThreadRaceHarnessError.peerAborted(
                index: index,
                abortedBy: abortedBy
            )
        }
    }

    func store(
        index: Int,
        outcome: A3DedicatedThreadCandidateOutcome
    ) {
        condition.lock()
        defer { condition.unlock() }
        guard indexedOutcomes.indices.contains(index) else {
            preconditionFailure("A3 dedicated-thread outcome index is invalid")
        }
        if indexedOutcomes[index] != nil {
            storageFailure = .duplicateOutcome(index: index)
            recordAbortLocked(index: index)
            return
        }
        var storedOutcome = outcome
        if !released, arrivedIndices.count < 2 {
            recordAbortLocked(index: index)
            if case .success = storedOutcome {
                storedOutcome = .failure(
                    A3DedicatedThreadRaceHarnessError
                        .completedBeforeRendezvous(index: index)
                )
            }
        }
        indexedOutcomes[index] = storedOutcome
    }

    func finishedOutcomes() throws
        -> [A3DedicatedThreadCandidateOutcome]
    {
        condition.lock()
        defer { condition.unlock() }
        if let storageFailure {
            throw storageFailure
        }
        guard let first = indexedOutcomes[0] else {
            throw A3DedicatedThreadRaceHarnessError.missingOutcome(index: 0)
        }
        guard let second = indexedOutcomes[1] else {
            throw A3DedicatedThreadRaceHarnessError.missingOutcome(index: 1)
        }
        return [first, second]
    }

    private func recordAbortLocked(index: Int) {
        if abortedBy == nil {
            abortedBy = index
        }
        condition.broadcast()
    }
}

private struct A3DedicatedThreadCandidateRaceResult: Sendable {
    let results: [CandidatePlanningStartResult]
    let resolverCounts: [Int]
}

private func a3RunDedicatedCandidateRace(
    _ fixture: R01FailureFirstFixture,
    firstCommand: CandidatePlanningStartCommand,
    secondCommand: CandidatePlanningStartCommand
) async throws -> A3DedicatedThreadCandidateRaceResult {
    let state = A3DedicatedThreadCandidateRaceState()
    let firstResolver = R01PlanningResolver(onResolve: {
        try state.rendezvous(index: 0)
    })
    let secondResolver = R01PlanningResolver(onResolve: {
        try state.rendezvous(index: 1)
    })
    let indexedOutcomes: [A3DedicatedThreadCandidateOutcome] =
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<
                [A3DedicatedThreadCandidateOutcome],
                any Error
            >) in
            let firstThread = A3DedicatedThreadHandle(Thread {
                let outcome: A3DedicatedThreadCandidateOutcome
                do {
                    outcome = .success(
                        try a3Convert(
                            fixture,
                            command: firstCommand,
                            resolver: firstResolver
                        )
                    )
                } catch {
                    outcome = .failure(error)
                }
                state.store(index: 0, outcome: outcome)
            })
            let secondThread = A3DedicatedThreadHandle(Thread {
                let outcome: A3DedicatedThreadCandidateOutcome
                do {
                    outcome = .success(
                        try a3Convert(
                            fixture,
                            command: secondCommand,
                            resolver: secondResolver
                        )
                    )
                } catch {
                    outcome = .failure(error)
                }
                state.store(index: 1, outcome: outcome)
            })
            firstThread.name = "AgentLoop.A3CandidateRace.first"
            secondThread.name = "AgentLoop.A3CandidateRace.second"
            firstThread.start()
            secondThread.start()
            let completionQueue = DispatchQueue(
                label: "AgentLoop.A3CandidateRace.completion"
            )
            completionQueue.async {
                while !firstThread.isFinished
                    || !secondThread.isFinished
                {
                    Thread.sleep(forTimeInterval: 0.001)
                }
                let completionResult: Result<
                    [A3DedicatedThreadCandidateOutcome],
                    any Error
                > = Result {
                    try state.finishedOutcomes()
                }
                continuation.resume(with: completionResult)
            }
        }

    var peerFailure: (Int, any Error)?
    var results: [CandidatePlanningStartResult] = []
    for (index, outcome) in indexedOutcomes.enumerated() {
        switch outcome {
        case let .success(result):
            results.append(result)
        case let .failure(error):
            if let harnessError = error
                as? A3DedicatedThreadRaceHarnessError,
                case .peerAborted = harnessError
            {
                peerFailure = peerFailure ?? (index, error)
            } else {
                throw A3DedicatedThreadRaceFailure(
                    index: index,
                    underlying: error
                )
            }
        }
    }
    if let peerFailure {
        throw A3DedicatedThreadRaceFailure(
            index: peerFailure.0,
            underlying: peerFailure.1
        )
    }
    precondition(results.count == 2)
    return A3DedicatedThreadCandidateRaceResult(
        results: results,
        resolverCounts: [
            firstResolver.resolveCount,
            secondResolver.resolveCount,
        ]
    )
}

private final class A3LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    func set(_ value: Value) {
        lock.withLock {
            storage = value
        }
    }

    var value: Value? {
        lock.withLock { storage }
    }
}

@MainActor
private func makeR01CoordinatorHarness(
    _ fixture: R01FailureFirstFixture,
    planningProvider: any LLMProvider = MockProvider(
        script: Array(repeating: r01ValidPlanTurn(), count: 20)
    )
) async -> R01CoordinatorHarness {
    let resolver = R01PlanningResolver(provider: planningProvider)
    let orchestrator = Orchestrator(
        db: fixture.database,
        planningProviderResolver: resolver,
        makeProvider: { _, _ in nil },
        artifactStoreRoot: fixture.root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()
    let uuidSequence = R01UUIDSequence()
    return R01CoordinatorHarness(
        coordinator: PlanningEntryCoordinator(
            db: fixture.database,
            orchestrator: orchestrator,
            makeUUIDString: {
                uuidSequence.next()
            }
        ),
        orchestrator: orchestrator,
        uuidSequence: uuidSequence
    )
}

private func r01RuntimeSelection() -> PlanningEntryRuntimeSelection {
    PlanningEntryRuntimeSelection(
        runtimeProfileId: "planning-profile",
        plannerModel: "planner-model"
    )
}

private func r01MissionStartArguments(
    _ fixture: R01FailureFirstFixture,
    goal: String = "交付结果",
    budgetTokens: Int = 1_000
) -> PlanningMissionStartArguments {
    PlanningMissionStartArguments(
        goal: goal,
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        budgetTokens: budgetTokens,
        campId: fixture.camp.id,
        autonomy: .standard
    )
}

private func r01PlanningWork(
    _ fixture: R01FailureFirstFixture,
    idempotencyKey: String
) throws -> DurableWorkRecord? {
    try fixture.database.pool.read { database in
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("idempotencyKey") == idempotencyKey
            )
            .fetchOne(database)
    }
}

@discardableResult
private func r01InsertCandidate(
    _ fixture: R01FailureFirstFixture,
    candidateId: String
) throws -> CodingRanchMissionDraft {
    let now = Date(timeIntervalSinceReferenceDate: 500)
    let ingestionId = "ingestion-\(candidateId)"
    let noteId = "note-\(candidateId)"
    let detail = try String(
        decoding: CanonicalJSONV1.encode(
            A3CandidateMissionDetail(
                goal: "候选目标",
                why: "来源资料要求形成可验证成果",
                acceptance: ["保留来源", "交付可验证成果"]
            )
        ),
        as: UTF8.self
    )
    try fixture.database.pool.write { database in
        try IngestionItemRecord(
            id: ingestionId,
            campId: fixture.camp.id,
            sourceType: .manual,
            title: "候选来源",
            rawText: "候选来源内容",
            sourceURL: nil,
            author: nil,
            userIntent: nil,
            contentHash: String(repeating: "a", count: 64),
            status: .materialized,
            attempt: 0,
            errorText: nil,
            createdAt: now,
            updatedAt: now
        ).insert(database)
        try CampNoteRecord(
            id: noteId,
            campId: fixture.camp.id,
            missionId: nil,
            title: "候选来源笔记",
            bodyMd: "这是候选行动唯一绑定的来源笔记。",
            pinned: false,
            createdAt: now,
            updatedAt: now
        ).insert(database)
        try KnowledgeSourceLinkRecord(
            id: "source-link-\(candidateId)",
            campNoteId: noteId,
            ingestionId: ingestionId,
            locatorJson: nil,
            createdAt: now
        ).insert(database)
        try ActionCandidateRecord(
            id: candidateId,
            ingestionId: ingestionId,
            campId: fixture.camp.id,
            type: .mission,
            title: "候选行动",
            detailJson: detail,
            status: .accepted,
            missionId: nil,
            idemKey: "candidate:\(candidateId)",
            createdAt: now,
            updatedAt: now
        ).insert(database)
    }
    return try MissionDraftFactory(db: fixture.database).draft(
        candidateId: candidateId
    )
}

private func a3Draft(
    _ draft: CodingRanchMissionDraft,
    candidateId: String? = nil,
    ingestionId: String? = nil,
    campId: String? = nil,
    noteId: String? = nil,
    goal: String? = nil,
    acceptance: [String]? = nil,
    why: String? = nil
) -> CodingRanchMissionDraft {
    CodingRanchMissionDraft(
        candidateId: candidateId ?? draft.candidateId,
        ingestionId: ingestionId ?? draft.ingestionId,
        campId: campId ?? draft.campId,
        noteId: noteId ?? draft.noteId,
        goal: goal ?? draft.goal,
        acceptance: acceptance ?? draft.acceptance,
        why: why ?? draft.why
    )
}

private func a3CandidateCommand(
    _ fixture: R01FailureFirstFixture,
    draft: CodingRanchMissionDraft,
    goal: String = "交付候选行动的真实成果",
    companionId: String? = nil,
    workspacePath: String? = nil,
    budgetTokens: Int = 1_000,
    autonomy: MissionAutonomy = .standard,
    profileId: String = "planning-profile",
    model: String = "planner-model",
    idempotencyKey: String? = nil,
    traceId: String = "candidate-first-trace"
) throws -> CandidatePlanningStartCommand {
    CandidatePlanningStartCommand(
        draft: draft,
        goal: goal,
        companionId: companionId ?? fixture.companion.id,
        workspacePath: workspacePath,
        budgetTokens: budgetTokens,
        autonomy: autonomy,
        planningInput: try PlanningWorkInput(
            plannerModel: model,
            runtimeProfileId: profileId
        ),
        idempotencyKey: idempotencyKey
            ?? "mission-start:candidate:\(draft.candidateId):v1",
        traceId: traceId
    )
}

private func a3Convert(
    _ fixture: R01FailureFirstFixture,
    command: CandidatePlanningStartCommand,
    resolver: (any PlanningProviderResolver)? = nil
) throws -> CandidatePlanningStartResult {
    try fixture.database.convertCandidateAndEnqueuePlanning(
        command,
        planningProviderResolver: resolver ?? fixture.resolver
    )
}

private func a3BusinessSnapshot(
    _ fixture: R01FailureFirstFixture,
    candidateId: String,
    workId: String? = nil
) throws -> A3BusinessSnapshot {
    try fixture.database.pool.read { database in
        let candidate = try ActionCandidateRecord.fetchOne(
            database,
            key: candidateId
        )
        let mission = try candidate?.missionId.flatMap {
            try MissionRecord.fetchOne(database, key: $0)
        }
        let squad = try mission.flatMap {
            try SquadRecord.fetchOne(database, key: $0.squadId)
        }
        let work = try workId.flatMap {
            try DurableWorkRecord.fetchOne(database, key: $0)
        }
        let workAttempts = try workId.map {
            try DurableWorkAttemptRecord
                .filter(Column("workId") == $0)
                .order(Column("attempt"), Column("id"))
                .fetchAll(database)
        } ?? []
        let workAttemptEvents = try workId.map {
            try DurableWorkAttemptEventRecord
                .filter(Column("workId") == $0)
                .order(Column("attempt"), Column("sequence"), Column("id"))
                .fetchAll(database)
        } ?? []
        let events = try EventRecord
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
        return A3BusinessSnapshot(
            squadCount: try SquadRecord.fetchCount(database),
            missionCount: try MissionRecord.fetchCount(database),
            workCount: try DurableWorkRecord.fetchCount(database),
            durableAttemptCount:
                try DurableWorkAttemptRecord.fetchCount(database),
            durableAttemptEventCount:
                try DurableWorkAttemptEventRecord.fetchCount(database),
            cardCount: try CardRecord.fetchCount(database),
            eventCount: events.count,
            ingestionCount: try IngestionItemRecord.fetchCount(database),
            noteCount: try CampNoteRecord.fetchCount(database),
            sourceLinkCount: try KnowledgeSourceLinkRecord.fetchCount(database),
            candidate: candidate,
            mission: mission.map(A3MissionSnapshot.init),
            squad: squad.map(A3SquadSnapshot.init),
            work: work,
            workAttempts: workAttempts,
            workAttemptEvents: workAttemptEvents,
            missionEvents: events.map(A3EventSnapshot.init)
        )
    }
}

private func a3WriterTotalChanges(
    _ fixture: R01FailureFirstFixture
) -> Int {
    fixture.database.pool.writeWithoutTransaction { database in
        database.totalChangesCount
    }
}

#if DEBUG
private enum A3RecoveredOrchestratorFixtureError: Error {
    case startupRecoveryFailed
}

private func makeA3RecoveredOrchestrator(
    _ fixture: R01FailureFirstFixture,
    candidateId: String,
    resolver: R01PlanningResolver,
    probe: A3PostCommitObservationProbe,
    artifactStoreRoot: URL? = nil
) async throws -> Orchestrator {
    let orchestrator = Orchestrator(
        db: fixture.database,
        planningProviderResolver: resolver,
        makeProvider: { _, _ in nil },
        artifactStoreRoot: artifactStoreRoot
            ?? fixture.root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
    try await orchestrator.armA3CandidatePostCommitObserverForTesting {
        observation in
        var evidence: A3PreDispatchEvidence?
        var captureFailure: String?
        if observation == .ensureTick {
            do {
                evidence = A3PreDispatchEvidence(
                    writerTotalChanges: a3WriterTotalChanges(fixture),
                    resolverCount: resolver.resolveCount,
                    snapshot: try a3BusinessSnapshot(
                        fixture,
                        candidateId: candidateId,
                        workId: try r01PlanningWork(
                            fixture,
                            idempotencyKey:
                                "mission-start:candidate:\(candidateId):v1"
                        )?.id
                    )
                )
            } catch {
                captureFailure = String(reflecting: error)
            }
        }
        await probe.record(
            observation,
            evidence: evidence,
            captureFailure: captureFailure
        )
    }
    await orchestrator.recoverAndReconcile()
    let recoveryFailed = await orchestrator.isHalted
    guard !recoveryFailed else {
        throw A3RecoveredOrchestratorFixtureError.startupRecoveryFailed
    }
    return orchestrator
}

private func a3OrchestratedConvert(
    _ orchestrator: Orchestrator,
    command: CandidatePlanningStartCommand
) async throws -> CandidatePlanningStartResult {
    try await orchestrator.convertCandidateAndEnqueuePlanning(command)
}

private func shutdownA3Orchestrator(_ orchestrator: Orchestrator) async {
    await orchestrator.clearA3CandidatePostCommitObserverForTesting()
    _ = await orchestrator.shutdown()
}
#endif

private func a3StartEventCounts(
    _ fixture: R01FailureFirstFixture,
    missionId: String
) throws -> [String: Int] {
    try fixture.database.pool.read { database in
        var result: [String: Int] = [:]
        for kind in [
            EventKind.missionCreated,
            EventKind.planStarted,
            EventKind.actionCandidateConverted,
        ] {
            result[kind] = try EventRecord
                .filter(
                    Column("missionId") == missionId
                        && Column("kind") == kind
                )
                .fetchCount(database)
        }
        return result
    }
}

private func a3AdvanceReplayState(
    _ state: DurableWorkState,
    fixture: R01FailureFirstFixture,
    workId: String
) throws {
    let start = Date().addingTimeInterval(1)
    switch state {
    case .queued:
        break
    case .running:
        let claim = try #require(
            try fixture.database.claimNextPlanning(
                workerId: "a3-running-worker",
                now: start,
                leaseDuration: 60
            )
        )
        #expect(claim.workId == workId)
    case .retryScheduled:
        let claim = try #require(
            try fixture.database.claimNextPlanning(
                workerId: "a3-retry-worker",
                now: start,
                leaseDuration: 60
            )
        )
        guard case .retryScheduled = try fixture.database
            .recordPlanningAttemptFailure(
                claim: claim,
                failure: try PlanningAttemptFailure(
                    code: "planning_provider_unavailable",
                    safeMessage: "规划服务暂时不可用。",
                    disposition: .transient,
                    usage: nil
                ),
                now: start.addingTimeInterval(1)
            )
        else {
            Issue.record("Expected retry-scheduled planning work")
            return
        }
    case .succeeded:
        let claim = try #require(
            try fixture.database.claimNextPlanning(
                workerId: "a3-success-worker",
                now: start,
                leaseDuration: 60
            )
        )
        guard case .succeeded = try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(),
            now: start.addingTimeInterval(1)
        ) else {
            Issue.record("Expected succeeded planning work")
            return
        }
    case .failed:
        let claim = try #require(
            try fixture.database.claimNextPlanning(
                workerId: "a3-failed-worker",
                now: start,
                leaseDuration: 60
            )
        )
        guard case .failed = try fixture.database
            .recordPlanningAttemptFailure(
                claim: claim,
                failure: try PlanningAttemptFailure(
                    code: "planning_provider_failed",
                    safeMessage: "规划服务执行失败。",
                    disposition: .deterministic,
                    usage: nil
                ),
                now: start.addingTimeInterval(1)
            )
        else {
            Issue.record("Expected failed planning work")
            return
        }
    case .canceled:
        guard case .canceled = try fixture.database.cancelPlanning(
            workId: workId,
            expectedVersion: 1,
            reason: "a3_replay_cancellation",
            now: start
        ) else {
            Issue.record("Expected canceled planning work")
            return
        }
    }
}

private func a3ConflictingCommands(
    _ fixture: R01FailureFirstFixture,
    command: CandidatePlanningStartCommand
) throws -> [CandidatePlanningStartCommand] {
    let draft = command.draft
    return try [
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, candidateId: "changed-candidate"),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, ingestionId: "changed-ingestion"),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, campId: "changed-camp"),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, noteId: "changed-note"),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, goal: "changed source goal"),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, acceptance: ["changed acceptance"]),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: a3Draft(draft, why: "changed source why"),
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            goal: "changed final goal",
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            companionId: "changed-companion",
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            workspacePath: "/tmp/changed-workspace",
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            budgetTokens: command.budgetTokens + 1,
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            autonomy: .careful,
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            profileId: "changed-profile",
            idempotencyKey: command.idempotencyKey
        ),
        a3CandidateCommand(
            fixture,
            draft: draft,
            model: "changed-model",
            idempotencyKey: command.idempotencyKey
        ),
    ]
}

private func r01ScheduleRecords(
    _ fixture: R01FailureFirstFixture,
    suffix: String
) throws -> (template: MissionTemplateRecord, schedule: ScheduleRecord) {
    let template = try MissionTemplateRecord.new(
        name: "定时行动 \(suffix)",
        goal: "执行定时行动 \(suffix)",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        budgetTokens: 1_000,
        autonomy: .standard,
        campId: fixture.camp.id
    )
    try fixture.database.saveMissionTemplate(template)
    let schedule = ScheduleRecord(
        id: "schedule-\(suffix)",
        templateId: template.id,
        frequency: .daily,
        hour: 0,
        minute: 0,
        weekday: nil,
        enabled: true,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSinceReferenceDate: 500)
    )
    try fixture.database.saveSchedule(schedule)
    return (template, schedule)
}

private func a4ScheduleContext(
    _ schedule: ScheduleRecord,
    scheduledAt: Date
) throws -> ScheduleSlotContextV1 {
    let timeZone = try #require(
        TimeZone(identifier: "America/Los_Angeles")
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    return try ScheduleMath.slotContext(
        for: scheduledAt,
        frequency: schedule.frequency,
        hour: schedule.hour,
        minute: schedule.minute,
        weekday: schedule.weekday,
        calendar: calendar,
        timeZone: timeZone
    )
}

private func a4ScheduleCommand(
    _ schedule: ScheduleRecord,
    scheduledAt: Date,
    preparation: ScheduleFirePreparation = .selected(
        runtimeProfileId: "planning-profile",
        plannerModel: "planner-model"
    ),
    traceId: String
) throws -> SchedulePlanningStartCommand {
    SchedulePlanningStartCommand(
        scheduleId: schedule.id,
        context: try a4ScheduleContext(
            schedule,
            scheduledAt: scheduledAt
        ),
        preparation: preparation,
        traceId: traceId
    )
}

private struct A4RestartSetup: Sendable {
    let scheduleId: String
    let result: ScheduleFireCommitResult
}

private func a4CommitScheduleWithoutWake(
    databasePath: String
) throws -> A4RestartSetup {
    let database = try AppDatabase(path: databasePath)
    let camp = try database.ensureDefaultCamp()
    let profile = RuntimeProfileRecord(
        id: "planning-profile",
        kind: .anthropicAPI,
        name: "Planning",
        baseURL: "https://api.anthropic.com",
        credentialAccount: "planning-credential",
        isDefault: true,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try database.saveRuntimeProfile(profile)
    var companion = CompanionRecord.new(
        name: "重启恢复伙伴",
        color: "blue",
        rolePrompt: "恢复已提交的定时规划",
        model: "planner-model",
        campId: camp.id
    )
    companion.runtimeProfileId = profile.id
    try database.saveCompanion(companion)
    let template = try MissionTemplateRecord.new(
        name: "重启恢复定时行动",
        goal: "恢复已经提交但尚未 kick 的规划工作",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: 1_000,
        autonomy: .standard,
        campId: camp.id
    )
    try database.saveMissionTemplate(template)
    let schedule = ScheduleRecord(
        id: "a4-restart-schedule",
        templateId: template.id,
        frequency: .daily,
        hour: 9,
        minute: 30,
        weekday: nil,
        enabled: true,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 1_699_900_000)
    )
    try database.saveSchedule(schedule)
    let result = try database.startScheduledMission(
        try a4ScheduleCommand(
            schedule,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_000),
            traceId: "a4-restart-first-trace"
        ),
        planningProviderResolver: R01PlanningResolver()
    )
    let workId = try #require(result.workId)
    let committedWork = try #require(try database.pool.read {
        try DurableWorkRecord.fetchOne($0, key: workId)
    })
    #expect(result.disposition == .inserted)
    #expect(result.fire.state == .started)
    #expect(committedWork.state == .queued)
    #expect(committedWork.attempt == 0)
    return A4RestartSetup(
        scheduleId: schedule.id,
        result: result
    )
}

private struct A4ScheduleGraphSnapshot: Equatable {
    let fires: [ScheduleFireRecord]
    let cursor: ScheduleEvaluationCursorRecord?
    let lastFiredAtBits: UInt64?
    let squadCount: Int
    let missionCount: Int
    let workCount: Int
    let eventCount: Int
    let chatThreadCount: Int
    let chatMessageCount: Int
}

private func a4ScheduleGraphSnapshot(
    _ database: AppDatabase,
    scheduleId: String
) throws -> A4ScheduleGraphSnapshot {
    let fires = try database.scheduleFires(scheduleId: scheduleId)
    let cursor = try database.scheduleEvaluationCursor(
        scheduleId: scheduleId
    )
    let lastFiredAtBits = try database.schedule(id: scheduleId)?
        .lastFiredAt?
        .timeIntervalSince1970
        .bitPattern
    return try database.pool.read { db in
        A4ScheduleGraphSnapshot(
            fires: fires,
            cursor: cursor,
            lastFiredAtBits: lastFiredAtBits,
            squadCount: try SquadRecord.fetchCount(db),
            missionCount: try MissionRecord.fetchCount(db),
            workCount: try DurableWorkRecord.fetchCount(db),
            eventCount: try EventRecord.fetchCount(db),
            chatThreadCount: try ChatThreadRecord.fetchCount(db),
            chatMessageCount: try ChatMessageRecord.fetchCount(db)
        )
    }
}

private actor A4KernelPlanningStartedProbe {
    private struct Waiter {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var missionIds: [String] = []
    private var waiters: [UUID: Waiter] = [:]

    func record(_ event: KernelEvent) {
        guard case .planningStarted(let missionId) = event else { return }
        missionIds.append(missionId)
        let readyIds = waiters.compactMap { id, waiter in
            waiter.target <= missionIds.count ? id : nil
        }
        let continuations = readyIds.compactMap {
            waiters.removeValue(forKey: $0)?.continuation
        }
        continuations.forEach { $0.resume() }
    }

    func waitForCount(_ target: Int) async {
        precondition(target > 0)
        guard missionIds.count < target else { return }
        await withCheckedContinuation { continuation in
            waiters[UUID()] = Waiter(
                target: target,
                continuation: continuation
            )
        }
    }

    func snapshot() -> [String] {
        missionIds
    }
}

private struct A4WakeRuntimeHarness: Sendable {
    let orchestrator: Orchestrator
    let provider: R01GateProvider
    let eventProbe: A4KernelPlanningStartedProbe
    let eventTask: Task<Void, Never>
#if DEBUG
    let observationProbe: A3PostCommitObservationProbe
#endif
}

private func makeA4WakeRuntimeHarness(
    _ fixture: R01FailureFirstFixture,
    recover: Bool = true,
    requiresStartupRecovery: Bool = false
) async throws -> A4WakeRuntimeHarness {
    let provider = R01GateProvider()
    let orchestrator = Orchestrator(
        db: fixture.database,
        planningProviderResolver: R01PlanningResolver(provider: provider),
        makeProvider: { _, _ in nil },
        artifactStoreRoot: fixture.root.appendingPathComponent("artifacts"),
        tickInterval: .seconds(3_600),
        requiresStartupRecovery: requiresStartupRecovery
    )
#if DEBUG
    let observationProbe = A3PostCommitObservationProbe()
    try await orchestrator.armA3CandidatePostCommitObserverForTesting {
        observation in
        await observationProbe.record(
            observation,
            evidence: nil,
            captureFailure: nil
        )
    }
#endif
    if recover {
        await orchestrator.recoverAndReconcile()
        try await orchestrator.waitUntilIdle()
    }
    let stream = await orchestrator.events()
    let eventProbe = A4KernelPlanningStartedProbe()
    let eventTask = Task {
        for await event in stream {
            await eventProbe.record(event)
        }
    }
#if DEBUG
    return A4WakeRuntimeHarness(
        orchestrator: orchestrator,
        provider: provider,
        eventProbe: eventProbe,
        eventTask: eventTask,
        observationProbe: observationProbe
    )
#else
    return A4WakeRuntimeHarness(
        orchestrator: orchestrator,
        provider: provider,
        eventProbe: eventProbe,
        eventTask: eventTask
    )
#endif
}

private func finishA4WakeRuntimeHarness(
    _ harness: A4WakeRuntimeHarness,
    releaseProvider: Bool
) async throws {
    if releaseProvider {
        await harness.provider.gate.release()
        try await harness.orchestrator.waitUntilIdle()
    }
    harness.eventTask.cancel()
#if DEBUG
    await harness.orchestrator
        .clearA3CandidatePostCommitObserverForTesting()
#endif
    _ = await harness.orchestrator.shutdown()
}

private func a4NormalizedSource(_ source: some StringProtocol) -> String {
    source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
}

private func a4OccurrenceCount(_ token: String, in source: String) -> Int {
    source.components(separatedBy: token).count - 1
}

private func a4CatchBodies(
    _ function: PlanningSourceFunctionFixture
) throws -> [String] {
    let source = String(function.maskedBody)
    var bodies: [String] = []
    var cursor = source.startIndex
    while cursor < source.endIndex,
          let catchRange = source.range(
            of: "catch",
            range: cursor..<source.endIndex
          )
    {
        guard let openingBrace = source[
            catchRange.upperBound..<source.endIndex
        ].firstIndex(of: "{") else {
            throw PlanningSourceFixtureError.openingBraceMissing("catch")
        }
        var depth = 0
        var index = openingBrace
        var closingBrace: String.Index?
        while index < source.endIndex {
            switch source[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    closingBrace = index
                }
            default:
                break
            }
            if closingBrace != nil { break }
            index = source.index(after: index)
        }
        guard let closingBrace else {
            throw PlanningSourceFixtureError.unbalancedBraces("catch")
        }
        bodies.append(String(source[openingBrace...closingBrace]))
        cursor = source.index(after: closingBrace)
    }
    return bodies
}

private enum A4ScheduleRaceHarnessError: Error, Equatable {
    case duplicateArrival(Int)
    case duplicateOutcome(Int)
    case missingOutcome(Int)
    case peerAborted(index: Int, abortedBy: Int)
}

private struct A4ScheduleRaceFailure:
    Error, @unchecked Sendable, CustomStringConvertible
{
    let index: Int
    let underlying: any Error

    var description: String {
        "A4 schedule race operation \(index) failed: \(underlying)"
    }
}

private enum A4ScheduleRaceOutcome: @unchecked Sendable {
    case success(ScheduleFireCommitResult)
    case failure(any Error)
}

private final class A4ScheduleRaceState: @unchecked Sendable {
    private let condition = NSCondition()
    private var arrivals: Set<Int> = []
    private var released = false
    private var abortedBy: Int?
    private var outcomes: [A4ScheduleRaceOutcome?] = [nil, nil]
    private var storageFailure: A4ScheduleRaceHarnessError?

    func awaitBoth(index: Int) throws {
        condition.lock()
        defer { condition.unlock() }
        guard arrivals.insert(index).inserted else {
            abortLocked(index: index)
            throw A4ScheduleRaceHarnessError.duplicateArrival(index)
        }
        if arrivals.count == 2 {
            released = true
            condition.broadcast()
        }
        while !released, abortedBy == nil {
            condition.wait()
        }
        if let abortedBy {
            throw A4ScheduleRaceHarnessError.peerAborted(
                index: index,
                abortedBy: abortedBy
            )
        }
    }

    func recordA4Outcome(index: Int, outcome: A4ScheduleRaceOutcome) {
        condition.lock()
        defer { condition.unlock() }
        guard outcomes.indices.contains(index), outcomes[index] == nil else {
            storageFailure = .duplicateOutcome(index)
            abortLocked(index: index)
            return
        }
        outcomes[index] = outcome
    }

    func a4FinishedOutcomes() throws -> [A4ScheduleRaceOutcome] {
        condition.lock()
        defer { condition.unlock() }
        if let storageFailure {
            throw storageFailure
        }
        guard let first = outcomes[0] else {
            throw A4ScheduleRaceHarnessError.missingOutcome(0)
        }
        guard let second = outcomes[1] else {
            throw A4ScheduleRaceHarnessError.missingOutcome(1)
        }
        return [first, second]
    }

    private func abortLocked(index: Int) {
        if abortedBy == nil {
            abortedBy = index
        }
        condition.broadcast()
    }
}

private struct A4ScheduleRaceResult: Sendable {
    let results: [ScheduleFireCommitResult]
    let resolverCounts: [Int]
}

private func a4RunScheduleRace(
    database: AppDatabase,
    firstCommand: SchedulePlanningStartCommand,
    secondCommand: SchedulePlanningStartCommand
) async throws -> A4ScheduleRaceResult {
    let state = A4ScheduleRaceState()
    let firstResolver = R01PlanningResolver(onResolve: {
        try state.awaitBoth(index: 0)
    })
    let secondResolver = R01PlanningResolver(onResolve: {
        try state.awaitBoth(index: 1)
    })
    let completionGroup = DispatchGroup()
    completionGroup.enter()
    completionGroup.enter()

    let firstThread = Thread {
        defer { completionGroup.leave() }
        do {
            state.recordA4Outcome(
                index: 0,
                outcome: .success(
                    try database.startScheduledMission(
                        firstCommand,
                        planningProviderResolver: firstResolver
                    )
                )
            )
        } catch {
            state.recordA4Outcome(index: 0, outcome: .failure(error))
        }
    }
    firstThread.name = "AgentLoop.A4ScheduleRace.first"
    let secondThread = Thread {
        defer { completionGroup.leave() }
        do {
            state.recordA4Outcome(
                index: 1,
                outcome: .success(
                    try database.startScheduledMission(
                        secondCommand,
                        planningProviderResolver: secondResolver
                    )
                )
            )
        } catch {
            state.recordA4Outcome(index: 1, outcome: .failure(error))
        }
    }
    secondThread.name = "AgentLoop.A4ScheduleRace.second"

    let outcomes: [A4ScheduleRaceOutcome] = try await
        withCheckedThrowingContinuation { continuation in
            firstThread.start()
            secondThread.start()
            DispatchQueue(
                label: "AgentLoop.A4ScheduleRace.completion"
            ).async {
                completionGroup.wait()
                continuation.resume(with: Result {
                    try state.a4FinishedOutcomes()
                })
            }
        }

    var results: [ScheduleFireCommitResult] = []
    for (index, outcome) in outcomes.enumerated() {
        switch outcome {
        case .success(let result):
            results.append(result)
        case .failure(let error):
            throw A4ScheduleRaceFailure(
                index: index,
                underlying: error
            )
        }
    }
    return A4ScheduleRaceResult(
        results: results,
        resolverCounts: [
            firstResolver.resolveCount,
            secondResolver.resolveCount,
        ]
    )
}

private func r01InsertPendingProposal(
    _ fixture: R01FailureFirstFixture,
    messageId: String,
    proposalId: String
) throws {
    let thread = ChatThreadRecord(
        id: "thread-\(messageId)",
        kind: .guide,
        companionId: fixture.companion.id,
        campId: fixture.camp.id,
        createdAt: Date(timeIntervalSinceReferenceDate: 500)
    )
    let proposal = SquadProposalBlock(
        proposalId: proposalId,
        name: "执行小队",
        memberIds: [fixture.companion.id],
        goal: "完成提案目标",
        budget: 1_000,
        status: .pending
    )
    try fixture.database.pool.write { database in
        try database.execute(sql: "PRAGMA defer_foreign_keys=ON")
        try database.execute(
            sql: """
                INSERT INTO legacy_chat_scope(
                  threadId,scopeKind,campId,cowId,evidenceKind,createdAt
                ) VALUES (?,?,?,?,?,?)
                """,
            arguments: [
                thread.id,
                LegacyContentScopeKindV1.camp.rawValue,
                fixture.camp.id,
                fixture.companion.id,
                LegacyContentEvidenceKindV1.guideThread.rawValue,
                thread.createdAt,
            ]
        )
        try thread.insert(database)
        try ChatMessageRecord(
            id: messageId,
            threadId: thread.id,
            role: "assistant",
            contentJson: try proposal.encodedString(),
            distilled: false,
            createdAt: Date(timeIntervalSinceReferenceDate: 501)
        ).insert(database)
    }
}

@discardableResult
private func r01SaveRuntimeProfile(
    _ fixture: R01FailureFirstFixture,
    id: String,
    kind: RuntimeProfileKind,
    isDefault: Bool = false
) throws -> RuntimeProfileRecord {
    let profile = RuntimeProfileRecord(
        id: id,
        kind: kind,
        name: id,
        baseURL: kind.isCLI ? nil : "https://example.com",
        credentialAccount: kind.isCLI ? nil : "credential-\(id)",
        isDefault: isDefault,
        createdAt: Date(timeIntervalSinceReferenceDate: 700)
    )
    try fixture.database.pool.write { database in
        try profile.insert(database)
    }
    return profile
}

@discardableResult
private func r01SaveCompanion(
    _ fixture: R01FailureFirstFixture,
    id: String,
    profileId: String?
) throws -> CompanionRecord {
    var companion = CompanionRecord.new(
        name: id,
        color: "green",
        rolePrompt: "legacy repair member",
        model: "model-\(id)",
        campId: fixture.camp.id
    )
    companion.id = id
    companion.runtimeProfileId = profileId
    try fixture.database.saveCompanion(companion)
    return companion
}

private func r01DisableDefaultProfiles(
    _ fixture: R01FailureFirstFixture
) throws {
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE runtime_profile SET isDefault = 0"
        )
    }
}

private func r01InstallLegacyRepairGate(
    _ fixture: R01FailureFirstFixture,
    missionId: String,
    gate: R01SQLGate
) throws {
    let function = DatabaseFunction(
        "r01_wait_for_legacy_repair",
        argumentCount: 0
    ) { _ in
        gate.enterAndWait()
        return 1
    }
    try fixture.database.pool.write { database in
        database.add(function: function)
        try database.execute(sql: """
            CREATE TRIGGER r01_pause_legacy_repair
            BEFORE INSERT ON durable_work
            WHEN NEW.idempotencyKey = 'legacy-planning:\(missionId):v1'
            BEGIN
              SELECT r01_wait_for_legacy_repair();
            END
            """)
    }
}

private func makeR01FailureFirstFixture() throws -> R01FailureFirstFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("a1b-failure-first-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: root.appendingPathComponent("fixture.sqlite").path
    )
    let camp = try database.ensureDefaultCamp()
    let profile = RuntimeProfileRecord(
        id: "planning-profile",
        kind: .anthropicAPI,
        name: "Planning",
        baseURL: "https://api.anthropic.com",
        credentialAccount: "planning-credential",
        isDefault: true,
        createdAt: Date(timeIntervalSinceReferenceDate: 900)
    )
    try database.saveRuntimeProfile(profile)
    var companion = CompanionRecord.new(
        name: "规划伙伴",
        color: "blue",
        rolePrompt: "负责把目标拆成可验证的小目标",
        model: "planner-model",
        campId: camp.id
    )
    companion.runtimeProfileId = profile.id
    try database.saveCompanion(companion)
    let resolver = R01PlanningResolver()
    return R01FailureFirstFixture(
        database: database,
        root: root,
        camp: camp,
        companion: companion,
        profile: profile,
        resolver: resolver
    )
}

private func r01PlanningInput(
    profileId: String = "planning-profile",
    model: String = "planner-model"
) throws -> PlanningWorkInput {
    try PlanningWorkInput(
        plannerModel: model,
        runtimeProfileId: profileId
    )
}

private func r01EnqueuePlanning(
    _ fixture: R01FailureFirstFixture,
    goal: String = "交付结果",
    budgetTokens: Int = 1_000,
    campId: String? = nil,
    idempotencyKey: String = "mission-start:test:v1",
    traceId: String = "planning-trace-first",
    resolver: (any PlanningProviderResolver)? = nil
) throws -> (missionId: String, workId: String) {
    try fixture.database.enqueueMissionPlanning(
        goal: goal,
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        budgetTokens: budgetTokens,
        campId: campId,
        autonomy: .standard,
        planningInput: r01PlanningInput(),
        idempotencyKey: idempotencyKey,
        traceId: traceId,
        planningProviderResolver: resolver ?? fixture.resolver
    )
}

private func r01PlanResult(
    usage: Usage = Usage(
        inputTokens: 2,
        outputTokens: 3,
        cacheReadTokens: 1
    ),
    fallbackReason: String? = nil
) -> PlanResult {
    PlanResult(
        proposal: PlanProposal(
            goalRefined: "交付可验证结果",
            cards: [
                .init(
                    title: "完成交付",
                    description: "执行目标并保存证据",
                    expectedOutput: "可验证产物",
                    assignee: 0,
                    dependsOn: []
                ),
            ]
        ),
        fallbackReason: fallbackReason,
        usage: usage
    )
}

private func r01ValidPlanTurn() -> TurnResult {
    TurnResult(
        content: [
            .toolUse(
                id: "plan-1",
                name: "propose_plan",
                input: [
                    "goalRefined": "交付可验证结果",
                    "cards": [
                        [
                            "title": "完成交付",
                            "description": "执行目标并保存证据",
                            "expectedOutput": "可验证产物",
                            "assignee": 0,
                            "dependsOn": [],
                        ],
                    ],
                ]
            ),
        ],
        stopReason: .toolUse,
        usage: Usage(inputTokens: 1, outputTokens: 1)
    )
}

private func r11PlanTurn(
    usage: Usage,
    invalidDependency: Bool = false
) -> TurnResult {
    TurnResult(
        content: [
            .toolUse(
                id: invalidDependency ? "r11-invalid-plan" : "r11-plan",
                name: "propose_plan",
                input: [
                    "goalRefined": "R11 可验证目标",
                    "cards": [
                        [
                            "title": "R11 行动",
                            "description": "执行 R11 行动",
                            "expectedOutput": "R11 证据",
                            "assignee": 0,
                            "dependsOn": invalidDependency ? [1] : [],
                        ],
                    ],
                ]
            ),
        ],
        stopReason: .toolUse,
        usage: usage
    )
}

private func r11CapturedPlanningFailure(
    _ operation: () async throws -> Void
) async -> PlanningAttemptFailure? {
    do {
        try await operation()
        Issue.record("expected PlanningAttemptFailure")
        return nil
    } catch let failure as PlanningAttemptFailure {
        return failure
    } catch {
        Issue.record("unexpected planner error: \(type(of: error))")
        return nil
    }
}

private struct R11StrictResolverFixture {
    let profiles: R11MutablePlanningProfileSource
    let catalogs: R11MutablePlanningCatalogSource
    let credentials: R11MutablePlanningCredentialSource
    let factory: R11PlanningProviderFactory
    let resolver: StrictPlanningProviderResolver
}

private func r11StrictResolverFixture(
    profile: RuntimeProfileRecord,
    provider: any LLMProvider
) -> R11StrictResolverFixture {
    let profiles = R11MutablePlanningProfileSource([profile])
    let catalogs = R11MutablePlanningCatalogSource(
        cached: [profile.id: ["planner-model"]]
    )
    let credentials = R11MutablePlanningCredentialSource(
        values: ["planning-credential": "initial-secret"]
    )
    let factory = R11PlanningProviderFactory(provider: provider)
    return R11StrictResolverFixture(
        profiles: profiles,
        catalogs: catalogs,
        credentials: credentials,
        factory: factory,
        resolver: StrictPlanningProviderResolver(
            profiles: profiles,
            catalogs: catalogs,
            credentials: credentials,
            factory: factory
        )
    )
}

private func r11RunSupervisorToTerminal(
    fixture: R01FailureFirstFixture,
    resolver: any PlanningProviderResolver,
    workId: String,
    workerId: String
) async throws {
    let supervisor = DurableWorkSupervisor(
        database: fixture.database,
        planningProviderResolver: resolver,
        workerId: workerId,
        now: { Date(timeIntervalSinceReferenceDate: 1_000) },
        sleep: { duration in
            try await Task<Never, Never>.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )
    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: "planner-model"]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    try await supervisor.waitUntilTerminal(workId: workId)
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

private func r11AssertClaimResolutionFailure(
    expectedCode: String,
    command: String,
    mutate: (R11StrictResolverFixture, R01FailureFirstFixture) -> Void
) async throws {
    let fixture = try makeR01FailureFirstFixture()
    let provider = MockProvider(script: [r01ValidPlanTurn()])
    let strict = r11StrictResolverFixture(
        profile: fixture.profile,
        provider: provider
    )
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:\(command):v1",
        resolver: strict.resolver
    )
    mutate(strict, fixture)

    try await r11RunSupervisorToTerminal(
        fixture: fixture,
        resolver: strict.resolver,
        workId: ids.workId,
        workerId: "claim-revalidate-\(command)"
    )

    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    let mission = try #require(
        try fixture.database.mission(id: ids.missionId)
    )
    let events = try fixture.database.events(missionId: ids.missionId)
    #expect(work.state == .failed)
    #expect(work.errorCode == expectedCode)
    #expect(mission.status == .failed)
    #expect(mission.spentTokens == 0)
    #expect(
        events.filter { $0.kind == EventKind.missionFailed }
            .map(\.payloadJson)
            == [#"{"reason":"\#(expectedCode)"}"#]
    )
    #expect(events.allSatisfy { $0.kind != EventKind.planningTokens })
    #expect(events.allSatisfy { $0.kind != EventKind.planCompleted })
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
    #expect(await provider.callCount == 0)
}

private func r01OrchestratorSource() throws -> String {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = packageRoot
        .appendingPathComponent("AgentLoopCore")
        .appendingPathComponent("Kernel")
        .appendingPathComponent("Orchestrator.swift")
    return try String(contentsOf: source, encoding: .utf8)
}

private enum A3Revision02SentinelError: Error, Equatable {
    case malformedManifest(String)
    case pathOutsideRepository(String)
    case nonRegularEntry(String)
    case symbolicLink(String)
    case unguardedDebugToken(String)
}

private struct A3Revision02ManifestEntry: Equatable {
    let hash: String
    let path: String
}

private func a3RepositoryRoot() -> URL {
    PlanningTestFixtures.packageRoot()
        .deletingLastPathComponent()
}

private func a3SHA256(at url: URL) throws -> String {
    CanonicalJSONV1.sha256Hex(try Data(contentsOf: url))
}

private let a3P1EHistoricalSuccessorExclusions: Set<String> = [
    "Sources/AgentLoopCore/Support/ShellProcessRegistry.swift",
    "Sources/AgentLoopCore/Ingestion/FeedService.swift",
    "Sources/AgentLoopCore/Ingestion/IngestionRecords.swift",
    "Sources/AgentLoopCore/Product/CowTemplate.swift",
    "Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift",
    "Sources/AgentLoopTestSuite/ChatServiceTests.swift",
    "Sources/AgentLoopTestSuite/FeedTests.swift",
    "Sources/AgentLoopTestSuite/MultiCampTests.swift",
    "Sources/AgentLoopTestSuite/PlanningTokensTests.swift",
    "Sources/AgentLoopTestSuite/ShellToolTests.swift",
]

private func a3P1EExactAllowlist(repositoryRoot root: URL) throws -> Set<String> {
    let allowlistURL = root.appendingPathComponent(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/"
            + "p1-e-identity-memory-ingestion-deletion/"
            + "scope-allowlist.txt"
    )
    try a3RequireRegularNonSymlink(allowlistURL)
    let data = try Data(contentsOf: allowlistURL)
    #expect(
        CanonicalJSONV1.sha256Hex(data)
            == "e6cf95c710cf2c7f513740cb49894f69df4ca1ecc01fc48e8294a3291dd881bb"
    )
    let rows = String(decoding: data, as: UTF8.self)
        .split(separator: "\n", omittingEmptySubsequences: false)
    #expect(rows.last?.isEmpty == true)
    let paths = rows.dropLast().map(String.init)
    #expect(paths.count == 135)
    #expect(!paths.contains(where: { $0.isEmpty }))
    let exact = Set(paths)
    #expect(exact.count == 135)
    return exact
}

private func a3P1F1ExactAllowlist(repositoryRoot root: URL) throws -> Set<String> {
    let allowlistURL = root.appendingPathComponent(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/"
            + "p1-f1-engine-artifact-discussion-attention-growth/"
            + "scope-allowlist.txt"
    )
    try a3RequireRegularNonSymlink(allowlistURL)
    let data = try Data(contentsOf: allowlistURL)
    #expect(
        CanonicalJSONV1.sha256Hex(data)
            == "83db82562cd412e32a6920e222e3dfbafab24a63ebc2fa6a6d3b984e01061e53"
    )
    let rows = String(decoding: data, as: UTF8.self)
        .split(separator: "\n", omittingEmptySubsequences: false)
    #expect(rows.last?.isEmpty == true)
    let paths = rows.dropLast().map(String.init)
    #expect(paths.count == 109)
    #expect(!paths.contains(where: { $0.isEmpty }))
    let exact = Set(paths)
    #expect(exact.count == 109)
    return exact
}

// R9-F full-suite validation made these legacy Orchestrator fixtures use an
// isolated stateRoot/artifacts pair. Keep that test-harness remediation
// explicit instead of mutating any historical stage allowlist or manifest.
private let r9fStateRootIsolationTestFiles: Set<String> = [
    "Sources/AgentLoopTestSuite/BudgetTests.swift",
    "Sources/AgentLoopTestSuite/CrashRecoveryTests.swift",
    "Sources/AgentLoopTestSuite/GoldenPathTests.swift",
    "Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift",
    "Sources/AgentLoopTestSuite/OrchestratorTests.swift",
]

// The cancellation/recovery completion seam is a bounded R9-F successor over
// the existing provider transports. Keep it separate from the byte-frozen
// historical P1-F1 allowlist and manifests.
private let r9fProviderCompletionHandleFiles: Set<String> = [
    "Sources/AgentLoopCore/Provider/AnthropicProvider.swift",
    "Sources/AgentLoopCore/Provider/LLMProvider.swift",
    "Sources/AgentLoopCore/Provider/MockProvider.swift",
    "Sources/AgentLoopCore/Provider/OpenAIProvider.swift",
    "Sources/AgentLoopCore/Provider/OpenAIResponsesProvider.swift",
]

// The 2026-09-05 desktop Coding closure added one opt-in runtime lifecycle
// logger for the approved bounded diagnosis. Keep it separate from every
// byte-frozen historical P1 allowlist and manifest.
private let desktopCodingClosureRuntimeDiagnosticsSuccessorFiles: Set<String> = [
    "Sources/AgentLoopCore/Observability/RuntimeLifecycleDiagnostics.swift",
]

// 2026-09-05 desktop Coding closure A1 foundation only.
// Separate from frozen manifests and the runtime-diagnostics singleton.
private let desktopCodingClosureA1FoundationSuccessorFiles20260905: Set<String> = [
    "Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift",
    "Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift",
    "Sources/AgentLoopTestSuite/DesktopGoalFoundationTests.swift",
    "Sources/AgentLoopTestSuite/DesktopGoalMigrationTests.swift",
]

// The 2026-09-08 blocking-operation forward-progress repair added exactly
// this bridge and its regression. Keep the historical manifests unchanged.
private let desktopCodingClosureBlockingProgressSuccessorFiles20260908: Set<String> = [
    "Sources/AgentLoopCore/Support/BlockingProcessOperation.swift",
    "Sources/AgentLoopTestSuite/BlockingProcessOperationTests.swift",
]

// The 2026-09-08 hermetic native CLI fixture repair changes one historical
// runner and adds one test-library helper. Keep both exact successors separate
// from the frozen A3 manifest and from the earlier blocking-progress repair.
private let desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908: Set<String> = [
    "Sources/AgentLoopTestSuite/CliMechanicsFixture.swift",
    "Sources/RunTests/main.swift",
]

private let desktopCodingClosureNativeCLIFixtureSuccessorHashes20260908 = [
    "Sources/AgentLoopTestSuite/CliMechanicsFixture.swift":
        "7608917b64d70acb41cfe8344f99951242e61c7b21af0ddbd2bae67d02c077ec",
    "Sources/RunTests/main.swift":
        "67d034114d15b735133f5f3749158d885656c6c895365e78fcd35f4c2cca4b37",
]

// The 2026-09-06 desktop Coding closure packaging review approved this exact
// development launcher successor. Keep the historical A4 manifest unchanged;
// package-historical-gate-plan.md records its separately pinned identity.
private let desktopCodingClosureDevelopmentPackagingSuccessorFiles20260906: Set<String> = [
    "scripts/run-app.sh",
]

private func a3Revision02ManifestEntries(
    _ data: Data
) throws -> [A3Revision02ManifestEntry] {
    guard data.last == 0x0A else {
        throw A3Revision02SentinelError.malformedManifest(
            "manifest must end with one newline"
        )
    }
    let rows = data.split(
        separator: 0x0A,
        omittingEmptySubsequences: false
    )
    guard rows.last?.isEmpty == true else {
        throw A3Revision02SentinelError.malformedManifest(
            "manifest terminator missing"
        )
    }
    return try rows.dropLast().map { row in
        let text = String(decoding: row, as: UTF8.self)
        guard text.utf8.count > 66 else {
            throw A3Revision02SentinelError.malformedManifest(text)
        }
        let hashEnd = text.index(text.startIndex, offsetBy: 64)
        let separatorEnd = text.index(hashEnd, offsetBy: 2)
        let hash = String(text[..<hashEnd])
        let separator = String(text[hashEnd..<separatorEnd])
        let path = String(text[separatorEnd...])
        let lowercaseHex = CharacterSet(
            charactersIn: "0123456789abcdef"
        )
        guard hash.count == 64,
              hash.unicodeScalars.allSatisfy(lowercaseHex.contains),
              separator == "  ",
              !path.isEmpty,
              !path.contains("\0"),
              !path.contains("\n"),
              !path.contains("\r"),
              !path.hasPrefix("/"),
              !path.hasPrefix("./")
        else {
            throw A3Revision02SentinelError.malformedManifest(text)
        }
        return A3Revision02ManifestEntry(hash: hash, path: path)
    }
}

private func a3RepositoryRelativePath(
    _ url: URL,
    root: URL
) throws -> String {
    let rootPrefix = root.standardizedFileURL.path + "/"
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(rootPrefix) else {
        throw A3Revision02SentinelError.pathOutsideRepository(path)
    }
    return String(path.dropFirst(rootPrefix.count))
}

private func a3RequireRegularNonSymlink(_ url: URL) throws {
    let values = try url.resourceValues(
        forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
    )
    if values.isSymbolicLink == true {
        throw A3Revision02SentinelError.symbolicLink(url.path)
    }
    guard values.isRegularFile == true else {
        throw A3Revision02SentinelError.nonRegularEntry(url.path)
    }
}

private func a3RegularFilesRecursively(
    under directory: URL,
    repositoryRoot: URL
) throws -> [String] {
    var result: [String] = []
    for url in try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ],
        options: []
    ) {
        let values = try url.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        if values.isSymbolicLink == true {
            throw A3Revision02SentinelError.symbolicLink(url.path)
        }
        if values.isDirectory == true {
            result.append(
                contentsOf: try a3RegularFilesRecursively(
                    under: url,
                    repositoryRoot: repositoryRoot
                )
            )
        } else if values.isRegularFile == true {
            result.append(
                try a3RepositoryRelativePath(url, root: repositoryRoot)
            )
        } else {
            throw A3Revision02SentinelError.nonRegularEntry(url.path)
        }
    }
    return result
}

private func a3RequireDebugGuarded(
    source: String,
    tokens: [String]
) throws {
    let masked = PlanningTestFixtures.maskCommentsAndStrings(in: source)
    var conditions: [Bool] = []
    for rawLine in masked.split(
        separator: "\n",
        omittingEmptySubsequences: false
    ) {
        let line = String(rawLine)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#if ") {
            conditions.append(trimmed == "#if DEBUG")
            continue
        }
        if trimmed == "#endif" {
            guard !conditions.isEmpty else {
                throw A3Revision02SentinelError.malformedManifest(
                    "unbalanced #endif"
                )
            }
            conditions.removeLast()
            continue
        }
        for token in tokens where line.contains(token) {
            guard conditions.contains(true) else {
                throw A3Revision02SentinelError
                    .unguardedDebugToken(token)
            }
        }
    }
    guard conditions.isEmpty else {
        throw A3Revision02SentinelError.malformedManifest(
            "unbalanced #if"
        )
    }
}

private struct R11ScheduleWriteSnapshot: Equatable {
    let scheduleCount: Int
    let lastFiredAtSQL: String
    let missionCount: Int
    let squadCount: Int
    let durableWorkCount: Int
    let durableWorkAttemptCount: Int
    let durableWorkAttemptEventCount: Int
    let cardCount: Int
    let eventCount: Int
}

private func r11ScheduleWriteSnapshot(
    _ fixture: R01FailureFirstFixture,
    scheduleId: String
) throws -> R11ScheduleWriteSnapshot {
    try fixture.database.pool.read { database in
        R11ScheduleWriteSnapshot(
            scheduleCount: try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM schedule"
            ) ?? 0,
            lastFiredAtSQL: try String.fetchOne(
                database,
                sql: """
                    SELECT quote(lastFiredAt)
                    FROM schedule
                    WHERE id = ?
                    """,
                arguments: [scheduleId]
            ) ?? "<missing>",
            missionCount: try MissionRecord.fetchCount(database),
            squadCount: try SquadRecord.fetchCount(database),
            durableWorkCount: try DurableWorkRecord.fetchCount(database),
            durableWorkAttemptCount:
                try DurableWorkAttemptRecord.fetchCount(database),
            durableWorkAttemptEventCount:
                try DurableWorkAttemptEventRecord.fetchCount(database),
            cardCount: try CardRecord.fetchCount(database),
            eventCount: try EventRecord.fetchCount(database)
        )
    }
}

@Test func missionAndPlanningWorkCommitAtomically() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        campId: fixture.camp.id
    )

    let counts = try fixture.database.pool.read { database in
        (
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM mission WHERE id = ?",
                arguments: [ids.missionId]
            ) ?? 0,
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*)
                    FROM durable_work
                    WHERE id = ?
                      AND kind = 'planning'
                      AND aggregateId = ?
                    """,
                arguments: [ids.workId, ids.missionId]
            ) ?? 0
        )
    }

    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
}

@Test func sameMissionStartReplayRequiresExplicitIdentity() throws {
    let source = try r01OrchestratorSource()
    #expect(source.contains("idempotencyKey: String"))
    #expect(source.contains("traceId: String"))
}

@MainActor
@Test func manualMissionStartCapturesProfileModelKeyAndTraceBeforeTask()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let harness = await makeR01CoordinatorHarness(fixture)
    let command = harness.coordinator.prepareManual(
        snapshot: ManualMissionStartSnapshot(
            mission: r01MissionStartArguments(
                fixture,
                budgetTokens: 0
            ),
            runtime: r01RuntimeSelection()
        ),
        pending: nil,
        forceNewCommand: false
    )

    #expect(command.snapshot.mission.budgetTokens == 1)
    #expect(command.snapshot.runtime == r01RuntimeSelection())
    #expect(
        command.idempotencyKey
            == "mission-start:user:r01-uuid-1:v1"
    )
    #expect(command.traceId == "r01-uuid-2")

    _ = try await harness.coordinator.startManual(command)
    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: command.idempotencyKey
        )
    )
    let input = try JSONDecoder().decode(
        PlanningWorkInput.self,
        from: Data(work.inputJson.utf8)
    )
    #expect(input.runtimeProfileId == command.snapshot.runtime.runtimeProfileId)
    #expect(input.plannerModel == command.snapshot.runtime.plannerModel)
    #expect(work.traceId == command.traceId)
    _ = await harness.orchestrator.shutdown()
}

@MainActor
@Test func manualMissionStartReusesPendingCommandAfterPostEnqueueFailure()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let provider = R01GateProvider()
    let harness = await makeR01CoordinatorHarness(
        fixture,
        planningProvider: provider
    )
    let snapshot = ManualMissionStartSnapshot(
        mission: r01MissionStartArguments(fixture),
        runtime: r01RuntimeSelection()
    )
    let command = harness.coordinator.prepareManual(
        snapshot: snapshot,
        pending: nil,
        forceNewCommand: false
    )
    let firstMissionId = try await harness.coordinator.startManual(command)
    await provider.gate.waitUntilEntered()

    let retained = harness.coordinator.prepareManual(
        snapshot: snapshot,
        pending: command,
        forceNewCommand: false
    )
    let replayMissionId = try await harness.coordinator.startManual(retained)
    let count = try await fixture.database.pool.read { database in
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("idempotencyKey") == command.idempotencyKey
            )
            .fetchCount(database)
    }

    #expect(retained == command)
    #expect(replayMissionId == firstMissionId)
    #expect(count == 1)
    await provider.gate.release()
    _ = await harness.orchestrator.shutdown()
}

@MainActor
@Test func manualMissionStartInputChangeCreatesNewCommandAndSuccessClearsPending()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let harness = await makeR01CoordinatorHarness(fixture)
    let first = harness.coordinator.prepareManual(
        snapshot: ManualMissionStartSnapshot(
            mission: r01MissionStartArguments(fixture, goal: "目标 A"),
            runtime: r01RuntimeSelection()
        ),
        pending: nil,
        forceNewCommand: false
    )
    let changed = harness.coordinator.prepareManual(
        snapshot: ManualMissionStartSnapshot(
            mission: r01MissionStartArguments(fixture, goal: "目标 B"),
            runtime: r01RuntimeSelection()
        ),
        pending: first,
        forceNewCommand: false
    )

    #expect(changed != first)
    #expect(changed.idempotencyKey != first.idempotencyKey)
    _ = try await harness.coordinator.startManual(changed)
    #expect(
        harness.coordinator.clearManualAfterSuccess(
            current: changed,
            completed: changed
        ) == nil
    )
    _ = await harness.orchestrator.shutdown()
}

@MainActor
@Test func lateManualMissionSuccessDoesNotClearNewPendingCommand() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let harness = await makeR01CoordinatorHarness(fixture)
    let old = harness.coordinator.prepareManual(
        snapshot: ManualMissionStartSnapshot(
            mission: r01MissionStartArguments(fixture, goal: "旧目标"),
            runtime: r01RuntimeSelection()
        ),
        pending: nil,
        forceNewCommand: false
    )
    let current = harness.coordinator.prepareManual(
        snapshot: ManualMissionStartSnapshot(
            mission: r01MissionStartArguments(fixture, goal: "新目标"),
            runtime: r01RuntimeSelection()
        ),
        pending: old,
        forceNewCommand: false
    )

    #expect(
        harness.coordinator.clearManualAfterSuccess(
            current: current,
            completed: old
        ) == current
    )
    _ = await harness.orchestrator.shutdown()
}

@Test func candidateConversionRollsBackWhenWorkInsertFails() async throws {
    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-work-insert-rollback"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        try await fixture.database.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER a3_fail_candidate_work_insert
                BEFORE INSERT ON durable_work
                WHEN NEW.idempotencyKey = '\(command.idempotencyKey)'
                BEGIN
                  SELECT RAISE(ABORT, 'injected A3 work insert failure');
                END
                """)
        }
        #expect(throws: DatabaseError.self) {
            _ = try a3Convert(fixture, command: command)
        }
        try await fixture.database.pool.write { database in
            try database.execute(
                sql: "DROP TRIGGER a3_fail_candidate_work_insert"
            )
        }
        #expect(fixture.resolver.resolveCount == 1)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-provider-preflight-failure"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let resolver = R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        #expect(throws: R01ResolverError.self) {
            _ = try a3Convert(
                fixture,
                command: command,
                resolver: resolver
            )
        }
        #expect(resolver.resolveCount == 1)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-halt-after-preflight"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let resolver = R01PlanningResolver(onResolve: {
            _ = try fixture.database.transitionDispatchMode(
                from: .running,
                to: .halted
            )
        })
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        #expect(throws: PlanningDurableDispatchNotRunningError.self) {
            _ = try a3Convert(
                fixture,
                command: command,
                resolver: resolver
            )
        }
        #expect(resolver.resolveCount == 1)
        let after = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        #expect(after.squadCount == before.squadCount)
        #expect(after.missionCount == before.missionCount)
        #expect(after.workCount == before.workCount)
        #expect(after.cardCount == before.cardCount)
        #expect(after.ingestionCount == before.ingestionCount)
        #expect(after.noteCount == before.noteCount)
        #expect(after.sourceLinkCount == before.sourceLinkCount)
        #expect(after.candidate == before.candidate)
        #expect(after.mission == before.mission)
        #expect(after.squad == before.squad)
        #expect(after.work == before.work)
        #expect(after.eventCount == before.eventCount + 1)
        #expect(
            after.missionEvents.filter {
                $0.kind == EventKind.missionCreated
                    || $0.kind == EventKind.planStarted
                    || $0.kind == EventKind.actionCandidateConverted
            }.isEmpty
        )
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-profile-deleted-after-preflight"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let resolver = R01PlanningResolver(onResolve: {
            try fixture.database.pool.write { database in
                try database.execute(
                    sql: "UPDATE companion SET runtimeProfileId = NULL"
                )
                try database.execute(
                    sql: "DELETE FROM runtime_profile WHERE id = ?",
                    arguments: [fixture.profile.id]
                )
            }
        })
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        #expect(throws: InvalidDurableWorkStateError.self) {
            _ = try a3Convert(
                fixture,
                command: command,
                resolver: resolver
            )
        }
        #expect(resolver.resolveCount == 1)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
    }

    for (suffix, kind) in [
        ("kind", RuntimeProfileKind.openAIAPI),
        ("cli", RuntimeProfileKind.cliCodex),
    ] {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-profile-\(suffix)-drift"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let resolver = R01PlanningResolver(onResolve: {
            try fixture.database.pool.write { database in
                try database.execute(
                    sql: "UPDATE runtime_profile SET kind = ? WHERE id = ?",
                    arguments: [kind.rawValue, fixture.profile.id]
                )
            }
        })
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        #expect(throws: InvalidDurableWorkStateError.self) {
            _ = try a3Convert(
                fixture,
                command: command,
                resolver: resolver
            )
        }
        #expect(resolver.resolveCount == 1)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-halted-replay"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let inserted = try a3Convert(fixture, command: command)
        _ = try fixture.database.transitionDispatchMode(
            from: .running,
            to: .halted
        )
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId,
            workId: inserted.workId
        )
        let replayResolver = R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
        #expect(throws: PlanningDurableDispatchNotRunningError.self) {
            _ = try a3Convert(
                fixture,
                command: try a3CandidateCommand(
                    fixture,
                    draft: draft,
                    traceId: "halted-replay-trace"
                ),
                resolver: replayResolver
            )
        }
        #expect(replayResolver.resolveCount == 0)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId,
                workId: inserted.workId
            ) == before
        )
    }

    #if DEBUG
    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-orchestrated-work-insert-rollback"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let resolver = R01PlanningResolver()
        let probe = A3PostCommitObservationProbe()
        let orchestrator = try await makeA3RecoveredOrchestrator(
            fixture,
            candidateId: draft.candidateId,
            resolver: resolver,
            probe: probe
        )
        try await fixture.database.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER a3_fail_orchestrated_candidate_work_insert
                BEFORE INSERT ON durable_work
                WHEN NEW.idempotencyKey = '\(command.idempotencyKey)'
                BEGIN
                  SELECT RAISE(ABORT, 'injected A3 work insert failure');
                END
                """)
        }
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        let writerBefore = a3WriterTotalChanges(fixture)
        do {
            _ = try await a3OrchestratedConvert(
                orchestrator,
                command: command
            )
            Issue.record("Expected orchestrated work insert rollback")
        } catch is DatabaseError {
        }
        let writerAfter = a3WriterTotalChanges(fixture)
        #expect(writerAfter > writerBefore)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
        #expect(resolver.resolveCount == 1)
        #expect(
            await probe.snapshot().counts == A3ObservationCounts()
        )
        try await fixture.database.pool.write { database in
            try database.execute(
                sql: "DROP TRIGGER a3_fail_orchestrated_candidate_work_insert"
            )
        }
        await shutdownA3Orchestrator(orchestrator)
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-orchestrated-provider-failure"
        )
        let resolver = R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
        let probe = A3PostCommitObservationProbe()
        let orchestrator = try await makeA3RecoveredOrchestrator(
            fixture,
            candidateId: draft.candidateId,
            resolver: resolver,
            probe: probe
        )
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        let writerBefore = a3WriterTotalChanges(fixture)
        do {
            _ = try await a3OrchestratedConvert(
                orchestrator,
                command: try a3CandidateCommand(fixture, draft: draft)
            )
            Issue.record("Expected orchestrated provider failure")
        } catch is R01ResolverError {
        }
        #expect(a3WriterTotalChanges(fixture) == writerBefore)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
        #expect(resolver.resolveCount == 1)
        #expect(
            await probe.snapshot().counts == A3ObservationCounts()
        )
        await shutdownA3Orchestrator(orchestrator)
    }

    for drift in ["halt", "delete", "kind", "cli"] {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-orchestrated-\(drift)-after-preflight"
        )
        let postSetup = A3LockedBox<(Int, A3BusinessSnapshot)>()
        let resolver = R01PlanningResolver(onResolve: {
            switch drift {
            case "halt":
                _ = try fixture.database.transitionDispatchMode(
                    from: .running,
                    to: .halted
                )
            case "delete":
                try fixture.database.pool.write { database in
                    try database.execute(
                        sql: "UPDATE companion SET runtimeProfileId = NULL"
                    )
                    try database.execute(
                        sql: "DELETE FROM runtime_profile WHERE id = ?",
                        arguments: [fixture.profile.id]
                    )
                }
            case "kind", "cli":
                let kind: RuntimeProfileKind = drift == "kind"
                    ? .openAIAPI
                    : .cliCodex
                try fixture.database.pool.write { database in
                    try database.execute(
                        sql: "UPDATE runtime_profile SET kind = ? WHERE id = ?",
                        arguments: [kind.rawValue, fixture.profile.id]
                    )
                }
            default:
                preconditionFailure("unhandled A3 drift fixture")
            }
            postSetup.set((
                a3WriterTotalChanges(fixture),
                try a3BusinessSnapshot(
                    fixture,
                    candidateId: draft.candidateId
                )
            ))
        })
        let probe = A3PostCommitObservationProbe()
        let orchestrator = try await makeA3RecoveredOrchestrator(
            fixture,
            candidateId: draft.candidateId,
            resolver: resolver,
            probe: probe
        )
        do {
            _ = try await a3OrchestratedConvert(
                orchestrator,
                command: try a3CandidateCommand(fixture, draft: draft)
            )
            Issue.record("Expected orchestrated \(drift) fence failure")
        } catch is PlanningDurableDispatchNotRunningError {
            #expect(drift == "halt")
        } catch is InvalidDurableWorkStateError {
            #expect(drift != "halt")
        }
        let baseline = try #require(postSetup.value)
        #expect(a3WriterTotalChanges(fixture) == baseline.0)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == baseline.1
        )
        #expect(resolver.resolveCount == 1)
        #expect(
            await probe.snapshot().counts == A3ObservationCounts()
        )
        await shutdownA3Orchestrator(orchestrator)
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-orchestrated-halted-existing-winner"
        )
        let command = try a3CandidateCommand(fixture, draft: draft)
        let winner = try a3Convert(fixture, command: command)
        _ = try fixture.database.transitionDispatchMode(
            from: .running,
            to: .halted
        )
        let resolver = R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
        let probe = A3PostCommitObservationProbe()
        let orchestrator = Orchestrator(
            db: fixture.database,
            planningProviderResolver: resolver,
            makeProvider: { _, _ in nil },
            artifactStoreRoot: fixture.root.appendingPathComponent("artifacts"),
            tickInterval: nil
        )
        try await orchestrator.armA3CandidatePostCommitObserverForTesting {
            observation in
            await probe.record(
                observation,
                evidence: nil,
                captureFailure: nil
            )
        }
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId,
            workId: winner.workId
        )
        let writerBefore = a3WriterTotalChanges(fixture)
        do {
            _ = try await a3OrchestratedConvert(
                orchestrator,
                command: command
            )
            Issue.record("Halted replay must fail before winner lookup")
        } catch is KernelHaltedError {
        }
        #expect(resolver.resolveCount == 0)
        #expect(a3WriterTotalChanges(fixture) == writerBefore)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId,
                workId: winner.workId
            ) == before
        )
        #expect(
            await probe.snapshot().counts == A3ObservationCounts()
        )
        await shutdownA3Orchestrator(orchestrator)
    }

    do {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-paused-loser-winner-halt-priority"
        )
        let winnerResolver = R01PlanningResolver()
        let winnerCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "a3-winner-before-halt-trace"
        )
        let postSetup = A3LockedBox<(
            CandidatePlanningStartResult,
            Int,
            A3BusinessSnapshot
        )>()
        let loserResolver = R01PlanningResolver(onResolve: {
            let winner = try a3Convert(
                fixture,
                command: winnerCommand,
                resolver: winnerResolver
            )
            _ = try fixture.database.transitionDispatchMode(
                from: .running,
                to: .halted
            )
            postSetup.set((
                winner,
                a3WriterTotalChanges(fixture),
                try a3BusinessSnapshot(
                    fixture,
                    candidateId: draft.candidateId,
                    workId: winner.workId
                )
            ))
        })
        let probe = A3PostCommitObservationProbe()
        let orchestrator = try await makeA3RecoveredOrchestrator(
            fixture,
            candidateId: draft.candidateId,
            resolver: loserResolver,
            probe: probe
        )
        let loserCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "a3-paused-halt-loser-trace"
        )
        do {
            _ = try await a3OrchestratedConvert(
                orchestrator,
                command: loserCommand
            )
            Issue.record("Durable halt must beat concurrent winner replay")
        } catch is PlanningDurableDispatchNotRunningError {
        }
        let baseline = try #require(postSetup.value)
        let winner = baseline.0
        #expect(loserResolver.resolveCount == 1)
        #expect(winnerResolver.resolveCount == 1)
        #expect(winner.disposition == .inserted)
        #expect(a3WriterTotalChanges(fixture) == baseline.1)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId,
                workId: winner.workId
            ) == baseline.2
        )
        #expect(
            baseline.2.work?.traceId == "a3-winner-before-halt-trace"
        )
        #expect(
            await probe.snapshot().counts == A3ObservationCounts()
        )
        await shutdownA3Orchestrator(orchestrator)
    }
    #endif
}

@Test func candidateConversionReplayReturnsOneMission() async throws {
    for state in [
        DurableWorkState.queued,
        .running,
        .retryScheduled,
        .succeeded,
        .failed,
        .canceled,
    ] {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-replay-\(state.rawValue)"
        )
        let firstCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "first-trace-\(state.rawValue)"
        )
        let inserted = try a3Convert(fixture, command: firstCommand)
        #expect(inserted.disposition == .inserted)
        try a3AdvanceReplayState(
            state,
            fixture: fixture,
            workId: inserted.workId
        )
        try await fixture.database.pool.write { database in
            try AppDatabase.appendEvent(
                database,
                missionId: inserted.missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.kernelError,
                payload: ["message": .string("unrelated later event")]
            )
            try database.execute(
                sql: "UPDATE companion SET runtimeProfileId = NULL"
            )
            try database.execute(
                sql: "DELETE FROM runtime_profile WHERE id = ?",
                arguments: [fixture.profile.id]
            )
        }
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId,
            workId: inserted.workId
        )
        let replayResolver = R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
        let replayed = try a3Convert(
            fixture,
            command: try a3CandidateCommand(
                fixture,
                draft: draft,
                traceId: "fresh-replay-trace-\(state.rawValue)"
            ),
            resolver: replayResolver
        )
        #expect(replayed.disposition == .replayed)
        #expect(replayed.missionId == inserted.missionId)
        #expect(replayed.workId == inserted.workId)
        #expect(replayResolver.resolveCount == 0)
        let after = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId,
            workId: inserted.workId
        )
        #expect(after == before)
        #expect(after.work?.traceId == "first-trace-\(state.rawValue)")
        #expect(after.work?.state == state)
        #expect(
            try a3StartEventCounts(
                fixture,
                missionId: inserted.missionId
            ) == [
                EventKind.missionCreated: 1,
                EventKind.planStarted: 1,
                EventKind.actionCandidateConverted: 1,
            ]
        )

        for conflict in try a3ConflictingCommands(
            fixture,
            command: firstCommand
        ) {
            #expect(throws: DurableWorkReplayConflictError.self) {
                _ = try a3Convert(
                    fixture,
                    command: conflict,
                    resolver: replayResolver
                )
            }
            #expect(replayResolver.resolveCount == 0)
            #expect(
                try a3BusinessSnapshot(
                    fixture,
                    candidateId: draft.candidateId,
                    workId: inserted.workId
                ) == before
            )
        }
    }

    #if DEBUG
    for state in [
        DurableWorkState.queued,
        .running,
        .retryScheduled,
        .succeeded,
        .failed,
        .canceled,
    ] {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-orchestrated-replay-\(state.rawValue)"
        )
        let replayResolver = R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
        let gate: A3ObservationBarrier? =
            state == .queued || state == .retryScheduled
                ? A3ObservationBarrier(target: 1)
                : nil
        let probe = A3PostCommitObservationProbe(
            ensureTickBarrier: gate
        )
        let orchestrator = try await makeA3RecoveredOrchestrator(
            fixture,
            candidateId: draft.candidateId,
            resolver: replayResolver,
            probe: probe
        )
        let firstCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "a3-orchestrated-first-trace-\(state.rawValue)"
        )
        let seedResolver = R01PlanningResolver()
        let inserted = try a3Convert(
            fixture,
            command: firstCommand,
            resolver: seedResolver
        )
        try a3AdvanceReplayState(
            state,
            fixture: fixture,
            workId: inserted.workId
        )
        try await fixture.database.pool.write { database in
            try AppDatabase.appendEvent(
                database,
                missionId: inserted.missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.kernelError,
                payload: ["message": .string("orchestrated unrelated event")]
            )
            try database.execute(
                sql: "UPDATE companion SET runtimeProfileId = NULL"
            )
            try database.execute(
                sql: "DELETE FROM runtime_profile WHERE id = ?",
                arguments: [fixture.profile.id]
            )
        }
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId,
            workId: inserted.workId
        )
        let writerBefore = a3WriterTotalChanges(fixture)

        for conflict in try a3ConflictingCommands(
            fixture,
            command: firstCommand
        ) {
            do {
                _ = try await a3OrchestratedConvert(
                    orchestrator,
                    command: conflict
                )
                Issue.record("Expected orchestrated replay conflict")
            } catch is DurableWorkReplayConflictError {
            }
            #expect(replayResolver.resolveCount == 0)
            #expect(a3WriterTotalChanges(fixture) == writerBefore)
            #expect(
                try a3BusinessSnapshot(
                    fixture,
                    candidateId: draft.candidateId,
                    workId: inserted.workId
                ) == before
            )
            #expect(
                (await probe.snapshot()).counts == A3ObservationCounts()
            )
        }

        let replayCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "ignored-orchestrated-trace-\(state.rawValue)"
        )
        let replayed: CandidatePlanningStartResult
        if let gate {
            let replayTask = Task {
                try await a3OrchestratedConvert(
                    orchestrator,
                    command: replayCommand
                )
            }
            await gate.waitUntilReady()
            let paused = await probe.snapshot()
            #expect(
                paused.counts == A3ObservationCounts(
                    ensureTick: 1,
                    planningStarted: 0,
                    kick: 0
                )
            )
            #expect(paused.captureFailures.isEmpty)
            #expect(paused.preDispatch.count == 1)
            let evidence = try #require(paused.preDispatch.first)
            #expect(evidence.writerTotalChanges == writerBefore)
            #expect(evidence.resolverCount == 0)
            #expect(evidence.snapshot == before)
            #expect(
                evidence.snapshot.work?.traceId
                    == "a3-orchestrated-first-trace-\(state.rawValue)"
            )
            #expect(evidence.snapshot.work?.state == state)
            await gate.release()
            replayed = try await replayTask.value
            #expect(
                (await probe.snapshot()).counts == A3ObservationCounts(
                    ensureTick: 1,
                    planningStarted: 0,
                    kick: 1
                )
            )
        } else {
            replayed = try await a3OrchestratedConvert(
                orchestrator,
                command: replayCommand
            )
            #expect(replayResolver.resolveCount == 0)
            #expect(a3WriterTotalChanges(fixture) == writerBefore)
            #expect(
                try a3BusinessSnapshot(
                    fixture,
                    candidateId: draft.candidateId,
                    workId: inserted.workId
                ) == before
            )
            #expect(
                (await probe.snapshot()).counts == A3ObservationCounts()
            )
        }
        #expect(replayed.disposition == .replayed)
        #expect(replayed.missionId == inserted.missionId)
        #expect(replayed.workId == inserted.workId)
        #expect(seedResolver.resolveCount == 1)
        await shutdownA3Orchestrator(orchestrator)
    }

    for drift in ["delete", "kind", "cli"] {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-winner-replay-profile-\(drift)"
        )
        let dispatchBarrier = A3ObservationBarrier(target: 1)
        let winnerResolver = R01PlanningResolver()
        let winnerCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "a3-profile-drift-winner-\(drift)"
        )
        let postSetup = A3LockedBox<(
            CandidatePlanningStartResult,
            Int,
            A3BusinessSnapshot
        )>()
        let loserResolver = R01PlanningResolver(onResolve: {
            let winner = try a3Convert(
                fixture,
                command: winnerCommand,
                resolver: winnerResolver
            )
            try fixture.database.pool.write { database in
                switch drift {
                case "delete":
                    try database.execute(
                        sql: "UPDATE companion SET runtimeProfileId = NULL"
                    )
                    try database.execute(
                        sql: "DELETE FROM runtime_profile WHERE id = ?",
                        arguments: [fixture.profile.id]
                    )
                case "kind", "cli":
                    let kind: RuntimeProfileKind = drift == "kind"
                        ? .openAIAPI
                        : .cliCodex
                    try database.execute(
                        sql: "UPDATE runtime_profile SET kind = ? WHERE id = ?",
                        arguments: [kind.rawValue, fixture.profile.id]
                    )
                default:
                    preconditionFailure("unhandled A3 winner drift")
                }
            }
            postSetup.set((
                winner,
                a3WriterTotalChanges(fixture),
                try a3BusinessSnapshot(
                    fixture,
                    candidateId: draft.candidateId,
                    workId: winner.workId
                )
            ))
        })
        let probe = A3PostCommitObservationProbe(
            ensureTickBarrier: dispatchBarrier
        )
        let orchestrator = try await makeA3RecoveredOrchestrator(
            fixture,
            candidateId: draft.candidateId,
            resolver: loserResolver,
            probe: probe
        )
        let loserCommand = try a3CandidateCommand(
            fixture,
            draft: draft,
            traceId: "a3-profile-drift-paused-loser-\(drift)"
        )
        let loserTask = Task {
            try await a3OrchestratedConvert(
                orchestrator,
                command: loserCommand
            )
        }
        await dispatchBarrier.waitUntilReady()
        let baseline = try #require(postSetup.value)
        let winner = baseline.0
        let writerBeforeReplay = baseline.1
        let beforeReplay = baseline.2
        let paused = await probe.snapshot()
        #expect(
            paused.counts == A3ObservationCounts(
                ensureTick: 1,
                planningStarted: 0,
                kick: 0
            )
        )
        #expect(paused.captureFailures.isEmpty)
        #expect(paused.preDispatch.count == 1)
        let evidence = try #require(paused.preDispatch.first)
        #expect(evidence.writerTotalChanges == writerBeforeReplay)
        #expect(evidence.resolverCount == 1)
        #expect(evidence.snapshot == beforeReplay)
        #expect(
            evidence.snapshot.work?.traceId
                == "a3-profile-drift-winner-\(drift)"
        )
        #expect(evidence.snapshot.work?.state == .queued)
        #expect(evidence.snapshot.work?.attempt == 0)
        #expect(evidence.snapshot.work?.version == 1)
        #expect(loserResolver.resolveCount == 1)
        #expect(winnerResolver.resolveCount == 1)
        await dispatchBarrier.release()
        let replayed = try await loserTask.value
        #expect(replayed.disposition == .replayed)
        #expect(replayed.missionId == winner.missionId)
        #expect(replayed.workId == winner.workId)
        #expect(
            (await probe.snapshot()).counts == A3ObservationCounts(
                ensureTick: 1,
                planningStarted: 0,
                kick: 1
            )
        )
        await shutdownA3Orchestrator(orchestrator)
    }
    #endif
}

@Test func candidateConversionNeverLeavesUnlinkedMission() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let draft = try r01InsertCandidate(
        fixture,
        candidateId: "a3-concurrent-candidate"
    )
    let firstCommand = try a3CandidateCommand(
        fixture,
        draft: draft,
        traceId: "a3-race-first-trace"
    )
    let secondCommand = try a3CandidateCommand(
        fixture,
        draft: draft,
        traceId: "a3-race-second-trace"
    )
    let race = try await a3RunDedicatedCandidateRace(
        fixture,
        firstCommand: firstCommand,
        secondCommand: secondCommand
    )
    let first = race.results[0]
    let second = race.results[1]

    #expect(first.missionId == second.missionId)
    #expect(first.workId == second.workId)
    #expect(race.resolverCounts == [1, 1])
    let dispositions = [first.disposition, second.disposition]
    #expect(dispositions.filter { $0 == .inserted }.count == 1)
    #expect(dispositions.filter { $0 == .replayed }.count == 1)

    let snapshot = try a3BusinessSnapshot(
        fixture,
        candidateId: draft.candidateId,
        workId: first.workId
    )
    #expect(snapshot.squadCount == 1)
    #expect(snapshot.missionCount == 1)
    #expect(snapshot.workCount == 1)
    #expect(snapshot.candidate?.status == .converted)
    #expect(snapshot.candidate?.missionId == first.missionId)
    #expect(snapshot.mission?.id == first.missionId)
    #expect(snapshot.squad?.id == snapshot.mission?.squadId)
    #expect(snapshot.work?.aggregateId == first.missionId)
    #expect(
        ["a3-race-first-trace", "a3-race-second-trace"]
            .contains(snapshot.work?.traceId ?? "")
    )
    #expect(
        try a3StartEventCounts(
            fixture,
            missionId: first.missionId
        ) == [
            EventKind.missionCreated: 1,
            EventKind.planStarted: 1,
            EventKind.actionCandidateConverted: 1,
        ]
    )

    do {
        let replayFixture = try makeR01FailureFirstFixture()
        let replayDraft = try r01InsertCandidate(
            replayFixture,
            candidateId: "a3-concurrent-winner-profile-drift"
        )
        let pausedCommand = try a3CandidateCommand(
            replayFixture,
            draft: replayDraft,
            traceId: "a3-paused-loser-trace"
        )
        let winnerResolver = R01PlanningResolver()
        let winnerCommand = try a3CandidateCommand(
            replayFixture,
            draft: replayDraft,
            traceId: "a3-profile-drift-winner-trace"
        )
        let postSetup = A3LockedBox<(
            CandidatePlanningStartResult,
            Int,
            A3BusinessSnapshot
        )>()
        let pausedResolver = R01PlanningResolver(onResolve: {
            let winner = try a3Convert(
                replayFixture,
                command: winnerCommand,
                resolver: winnerResolver
            )
            try replayFixture.database.pool.write { database in
                try database.execute(
                    sql: "UPDATE companion SET runtimeProfileId = NULL"
                )
                try database.execute(
                    sql: "DELETE FROM runtime_profile WHERE id = ?",
                    arguments: [replayFixture.profile.id]
                )
            }
            postSetup.set((
                winner,
                a3WriterTotalChanges(replayFixture),
                try a3BusinessSnapshot(
                    replayFixture,
                    candidateId: replayDraft.candidateId,
                    workId: winner.workId
                )
            ))
        })
        let replayed = try a3Convert(
            replayFixture,
            command: pausedCommand,
            resolver: pausedResolver
        )
        let baseline = try #require(postSetup.value)
        let winner = baseline.0
        #expect(a3WriterTotalChanges(replayFixture) == baseline.1)
        #expect(
            try a3BusinessSnapshot(
                replayFixture,
                candidateId: replayDraft.candidateId,
                workId: winner.workId
            ) == baseline.2
        )
        #expect(winner.disposition == .inserted)
        #expect(replayed.disposition == .replayed)
        #expect(replayed.missionId == winner.missionId)
        #expect(replayed.workId == winner.workId)
        #expect(pausedResolver.resolveCount == 1)
        #expect(winnerResolver.resolveCount == 1)
        #expect(
            try r01PlanningWork(
                replayFixture,
                idempotencyKey: pausedCommand.idempotencyKey
            )?.traceId == "a3-profile-drift-winner-trace"
        )
        #expect(
            try a3StartEventCounts(
                replayFixture,
                missionId: winner.missionId
            ) == [
                EventKind.missionCreated: 1,
                EventKind.planStarted: 1,
                EventKind.actionCandidateConverted: 1,
            ]
        )
    }

    #if DEBUG
    do {
        let orchestratedFixture = try makeR01FailureFirstFixture()
        let orchestratedDraft = try r01InsertCandidate(
            orchestratedFixture,
            candidateId: "a3-two-orchestrator-concurrent-candidate"
        )
        let dispatchBarrier = A3ObservationBarrier(target: 2)
        let sharedProbe = A3PostCommitObservationProbe(
            ensureTickBarrier: dispatchBarrier
        )
        let firstResolver = R01PlanningResolver()
        let secondResolver = R01PlanningResolver()
        let firstStateRoot = orchestratedFixture.root
            .appendingPathComponent("a3-owner-1", isDirectory: true)
        let secondStateRoot = orchestratedFixture.root
            .appendingPathComponent("a3-owner-2", isDirectory: true)
        for stateRoot in [firstStateRoot, secondStateRoot] {
            try FileManager.default.createDirectory(
                at: stateRoot,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.createDirectory(
                at: stateRoot.appendingPathComponent(
                    "artifacts",
                    isDirectory: true
                ),
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let firstOrchestrator = try await makeA3RecoveredOrchestrator(
            orchestratedFixture,
            candidateId: orchestratedDraft.candidateId,
            resolver: firstResolver,
            probe: sharedProbe,
            artifactStoreRoot: firstStateRoot.appendingPathComponent(
                "artifacts",
                isDirectory: true
            )
        )
        let secondOrchestrator = try await makeA3RecoveredOrchestrator(
            orchestratedFixture,
            candidateId: orchestratedDraft.candidateId,
            resolver: secondResolver,
            probe: sharedProbe,
            artifactStoreRoot: secondStateRoot.appendingPathComponent(
                "artifacts",
                isDirectory: true
            )
        )
        let firstCommand = try a3CandidateCommand(
            orchestratedFixture,
            draft: orchestratedDraft,
            traceId: "a3-two-orchestrator-first-trace"
        )
        let secondCommand = try a3CandidateCommand(
            orchestratedFixture,
            draft: orchestratedDraft,
            traceId: "a3-two-orchestrator-second-trace"
        )
        let writerBefore = a3WriterTotalChanges(orchestratedFixture)
        let firstTask = Task {
            try await a3OrchestratedConvert(
                firstOrchestrator,
                command: firstCommand
            )
        }
        let secondTask = Task {
            try await a3OrchestratedConvert(
                secondOrchestrator,
                command: secondCommand
            )
        }
        await dispatchBarrier.waitUntilReady()

        let paused = await sharedProbe.snapshot()
        #expect(
            paused.counts == A3ObservationCounts(
                ensureTick: 2,
                planningStarted: 0,
                kick: 0
            )
        )
        #expect(paused.captureFailures.isEmpty)
        #expect(paused.preDispatch.count == 2)
        let firstEvidence = try #require(paused.preDispatch.first)
        #expect(
            paused.preDispatch.allSatisfy {
                $0.writerTotalChanges == firstEvidence.writerTotalChanges
                    && $0.snapshot == firstEvidence.snapshot
            }
        )
        let pausedResolverCounts = paused.preDispatch
            .map(\.resolverCount)
            .sorted()
        #expect(
            pausedResolverCounts == [0, 1]
                || pausedResolverCounts == [1, 1]
        )
        #expect(firstEvidence.writerTotalChanges > writerBefore)
        #expect(firstEvidence.snapshot.squadCount == 1)
        #expect(firstEvidence.snapshot.missionCount == 1)
        #expect(firstEvidence.snapshot.workCount == 1)
        #expect(firstEvidence.snapshot.durableAttemptCount == 0)
        #expect(firstEvidence.snapshot.durableAttemptEventCount == 0)
        #expect(firstEvidence.snapshot.candidate?.status == .converted)
        #expect(
            firstEvidence.snapshot.candidate?.missionId
                == firstEvidence.snapshot.mission?.id
        )
        #expect(
            firstEvidence.snapshot.work?.aggregateId
                == firstEvidence.snapshot.mission?.id
        )
        #expect(
            [
                "a3-two-orchestrator-first-trace",
                "a3-two-orchestrator-second-trace",
            ].contains(firstEvidence.snapshot.work?.traceId ?? "")
        )
        await dispatchBarrier.release()
        let firstResult = try await firstTask.value
        let secondResult = try await secondTask.value
        #expect(firstResult.missionId == secondResult.missionId)
        #expect(firstResult.workId == secondResult.workId)
        #expect(
            [firstResult.disposition, secondResult.disposition]
                .filter { $0 == .inserted }.count == 1
        )
        #expect(
            [firstResult.disposition, secondResult.disposition]
                .filter { $0 == .replayed }.count == 1
        )
        let firstResolverCount = firstResolver.resolveCount
        let secondResolverCount = secondResolver.resolveCount
        #expect(firstResolverCount <= 1)
        #expect(secondResolverCount <= 1)
        #expect(
            [1, 2].contains(firstResolverCount + secondResolverCount)
        )
        if firstResult.disposition == .inserted {
            #expect(firstResolverCount == 1)
            #expect([0, 1].contains(secondResolverCount))
        } else {
            #expect(secondResolverCount == 1)
            #expect([0, 1].contains(firstResolverCount))
        }
        #expect(
            (await sharedProbe.snapshot()).counts
                == A3ObservationCounts(
                    ensureTick: 2,
                    planningStarted: 1,
                    kick: 2
                )
        )
        #expect(
            try a3StartEventCounts(
                orchestratedFixture,
                missionId: firstResult.missionId
            ) == [
                EventKind.missionCreated: 1,
                EventKind.planStarted: 1,
                EventKind.actionCandidateConverted: 1,
            ]
        )
        await shutdownA3Orchestrator(firstOrchestrator)
        await shutdownA3Orchestrator(secondOrchestrator)
    }
    #endif
}

@Test func candidateWithWrongCampCowFailsBeforeWrites() async throws {
    for cowCampId in [nil, "a3-other-camp"] as [String?] {
        let fixture = try makeR01FailureFirstFixture()
        let draft = try r01InsertCandidate(
            fixture,
            candidateId: "a3-wrong-cow-\(cowCampId ?? "nil")"
        )
        try await fixture.database.pool.write { database in
            if let cowCampId {
                try CampRecord(
                    id: cowCampId,
                    name: "其他营地",
                    archived: false,
                    createdAt: Date(timeIntervalSinceReferenceDate: 400)
                ).insert(database)
            }
            guard var companion = try CompanionRecord.fetchOne(
                database,
                key: fixture.companion.id
            ) else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: fixture.companion.id
                )
            }
            companion.campId = cowCampId
            try companion.update(database)
        }
        let resolver = R01PlanningResolver()
        let before = try a3BusinessSnapshot(
            fixture,
            candidateId: draft.candidateId
        )
        #expect(throws: InvalidDurableWorkStateError.self) {
            _ = try a3Convert(
                fixture,
                command: try a3CandidateCommand(
                    fixture,
                    draft: draft
                ),
                resolver: resolver
            )
        }
        #expect(resolver.resolveCount == 1)
        #expect(
            try a3BusinessSnapshot(
                fixture,
                candidateId: draft.candidateId
            ) == before
        )
        #expect(before.candidate?.status == .accepted)
        #expect(before.candidate?.missionId == nil)

        #if DEBUG
        let orchestratedFixture = try makeR01FailureFirstFixture()
        let orchestratedDraft = try r01InsertCandidate(
            orchestratedFixture,
            candidateId:
                "a3-orchestrated-wrong-cow-\(cowCampId ?? "nil")"
        )
        try await orchestratedFixture.database.pool.write { database in
            if let cowCampId {
                try CampRecord(
                    id: cowCampId,
                    name: "其他营地",
                    archived: false,
                    createdAt: Date(timeIntervalSinceReferenceDate: 400)
                ).insert(database)
            }
            guard var companion = try CompanionRecord.fetchOne(
                database,
                key: orchestratedFixture.companion.id
            ) else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: orchestratedFixture.companion.id
                )
            }
            companion.campId = cowCampId
            try companion.update(database)
        }
        let orchestratedResolver = R01PlanningResolver()
        let probe = A3PostCommitObservationProbe()
        let orchestrator = try await makeA3RecoveredOrchestrator(
            orchestratedFixture,
            candidateId: orchestratedDraft.candidateId,
            resolver: orchestratedResolver,
            probe: probe
        )
        let orchestratedBefore = try a3BusinessSnapshot(
            orchestratedFixture,
            candidateId: orchestratedDraft.candidateId
        )
        let writerBefore = a3WriterTotalChanges(orchestratedFixture)
        do {
            _ = try await a3OrchestratedConvert(
                orchestrator,
                command: try a3CandidateCommand(
                    orchestratedFixture,
                    draft: orchestratedDraft
                )
            )
            Issue.record("Expected orchestrated wrong-Camp cow failure")
        } catch is InvalidDurableWorkStateError {
        }
        #expect(orchestratedResolver.resolveCount == 1)
        #expect(
            a3WriterTotalChanges(orchestratedFixture) == writerBefore
        )
        #expect(
            try a3BusinessSnapshot(
                orchestratedFixture,
                candidateId: orchestratedDraft.candidateId
            ) == orchestratedBefore
        )
        #expect(
            (await probe.snapshot()).counts == A3ObservationCounts()
        )
        #expect(orchestratedBefore.candidate?.status == .accepted)
        #expect(orchestratedBefore.candidate?.missionId == nil)
        await shutdownA3Orchestrator(orchestrator)
        #endif
    }
}

@MainActor
@Test func confirmedProposalMissionStartUsesProposalKeyAndPreservesFirstTrace()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let provider = R01GateProvider()
    let harness = await makeR01CoordinatorHarness(
        fixture,
        planningProvider: provider
    )
    let messageId = "proposal-message"
    let proposalId = "proposal-identity"
    try r01InsertPendingProposal(
        fixture,
        messageId: messageId,
        proposalId: proposalId
    )
    let firstCapture = try harness.coordinator.captureConfirmedProposal(
        messageId: messageId,
        runtime: r01RuntimeSelection(),
        fallbackBudget: 1_000,
        autonomy: .standard
    )
    try await fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_proposal_attach_once
            BEFORE UPDATE ON chat_message
            WHEN NEW.id = '\(messageId)'
              AND OLD.contentJson LIKE '%"status":"confirmed"%'
              AND NEW.contentJson LIKE '%"status":"confirmed"%'
            BEGIN
              SELECT RAISE(ABORT, 'injected proposal attach failure');
            END
            """)
    }

    do {
        _ = try await harness.coordinator.startConfirmedProposal(
            firstCapture
        )
        Issue.record("Expected proposal attach failure")
    } catch is DatabaseError {
        // The proposal owner reverts to pending; the durable Mission remains.
    }
    await provider.gate.waitUntilEntered()
    let firstWork = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: firstCapture.idempotencyKey
        )
    )
    try await fixture.database.pool.write { database in
        try database.execute(sql: "DROP TRIGGER fail_proposal_attach_once")
    }
    let secondCapture = try harness.coordinator.captureConfirmedProposal(
        messageId: messageId,
        runtime: r01RuntimeSelection(),
        fallbackBudget: 1_000,
        autonomy: .standard
    )
    let missionId = try await harness.coordinator.startConfirmedProposal(
        secondCapture
    )
    let replayedWork = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: secondCapture.idempotencyKey
        )
    )

    #expect(
        firstCapture.idempotencyKey
            == "mission-start:proposal:\(proposalId):v1"
    )
    #expect(secondCapture.idempotencyKey == firstCapture.idempotencyKey)
    #expect(secondCapture.traceId != firstCapture.traceId)
    #expect(missionId == firstWork.aggregateId)
    #expect(replayedWork.id == firstWork.id)
    #expect(replayedWork.traceId == firstCapture.traceId)
    await provider.gate.release()
    _ = await harness.orchestrator.shutdown()
}

@Test func scheduleStartedTransactionSurvivesRestartBeforePlannerKick()
    async throws
{
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "a4-schedule-restart-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let path = root.appendingPathComponent("fixture.sqlite").path
    let setup = try a4CommitScheduleWithoutWake(databasePath: path)
    let committed = setup.result
    let reopened = try AppDatabase(path: path)
    let provider = R01GateProvider()
    let recoveryResolver = R01PlanningResolver(provider: provider)
    let orchestrator = Orchestrator(
        db: reopened,
        planningProviderResolver: recoveryResolver,
        makeProvider: { _, _ in nil },
        artifactStoreRoot: root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
    await orchestrator.recoverAndReconcile()
    await provider.gate.waitUntilEntered()

    let committedWorkId = try #require(committed.workId)
    let committedMissionId = try #require(committed.missionId)
    let recoveredRecord = try await reopened.pool.read {
        try DurableWorkRecord.fetchOne($0, key: committedWorkId)
    }
    let recovered = try #require(recoveredRecord)
    #expect(recoveryResolver.resolveCount == 1)
    #expect(provider.callCount == 1)
    #expect(recovered.aggregateId == committedMissionId)
    #expect(recovered.attempt == 1)
    #expect(recovered.state == .running)
    #expect(
        try reopened.scheduleFires(scheduleId: setup.scheduleId).count == 1
    )
    await provider.gate.release()
    _ = await orchestrator.shutdown()

    let retryFixture = try makeR01FailureFirstFixture()
    let retryWakeHarness = try await makeA4WakeRuntimeHarness(retryFixture)
    let retryRecords = try r01ScheduleRecords(
        retryFixture,
        suffix: "restart-retry-wake"
    )
    let retryResult = try retryFixture.database.startScheduledMission(
        try a4ScheduleCommand(
            retryRecords.schedule,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_150),
            traceId: "a4-restart-retry-wake"
        ),
        planningProviderResolver: R01PlanningResolver()
    )
    let retryWorkId = try #require(retryResult.workId)
    try a3AdvanceReplayState(
        .retryScheduled,
        fixture: retryFixture,
        workId: retryWorkId
    )
    try await retryFixture.database.pool.write {
        try $0.execute(
            sql: """
                UPDATE durable_work
                SET notBefore = ?
                WHERE id = ? AND state = 'retryScheduled'
                """,
            arguments: [Date(timeIntervalSince1970: 0), retryWorkId]
        )
        guard $0.changesCount == 1 else {
            throw InvalidDurableWorkStateError()
        }
    }
    try await retryWakeHarness.orchestrator.wakeScheduledPlanning(
        retryResult
    )
    await retryWakeHarness.provider.gate.waitUntilEntered()
    await retryWakeHarness.eventProbe.waitForCount(1)
    let retryRunning = try #require(try await retryFixture.database.pool.read {
        try DurableWorkRecord.fetchOne($0, key: retryWorkId)
    })
    #expect(retryResult.disposition == .inserted)
    #expect(retryWakeHarness.provider.callCount == 1)
    #expect(retryRunning.state == .running)
    #expect(
        await retryWakeHarness.eventProbe.snapshot()
            == [try #require(retryResult.missionId)]
    )
#if DEBUG
    #expect(
        (await retryWakeHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts(
                ensureTick: 1,
                planningStarted: 1,
                kick: 1
            )
    )
#endif
    try await finishA4WakeRuntimeHarness(
        retryWakeHarness,
        releaseProvider: true
    )
}

@Test func sameSlotReplayReturnsSameMission() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let replayWakeHarness = try await makeA4WakeRuntimeHarness(fixture)
    let records = try r01ScheduleRecords(fixture, suffix: "same-slot")
    let scheduledAt = Date(timeIntervalSince1970: 1_700_000_200)
    let firstResolver = R01PlanningResolver()
    let first = try fixture.database.startScheduledMission(
        try a4ScheduleCommand(
            records.schedule,
            scheduledAt: scheduledAt,
            traceId: "a4-same-slot-first-trace"
        ),
        planningProviderResolver: firstResolver
    )
    let firstSnapshot = try a4ScheduleGraphSnapshot(
        fixture.database,
        scheduleId: records.schedule.id
    )
    let writerChanges = a3WriterTotalChanges(fixture)
    let replayResolver = R01PlanningResolver(onResolve: {
        throw R01ResolverError.unavailable
    })
    let replayed = try fixture.database.startScheduledMission(
        try a4ScheduleCommand(
            records.schedule,
            scheduledAt: scheduledAt,
            traceId: "a4-same-slot-late-trace"
        ),
        planningProviderResolver: replayResolver
    )

    #expect(first.disposition == .inserted)
    #expect(replayed.disposition == .replayed)
    #expect(replayed.fire == first.fire)
    #expect(replayed.missionId == first.missionId)
    #expect(replayed.workId == first.workId)
    #expect(replayed.fire.traceId == "a4-same-slot-first-trace")
    #expect(firstResolver.resolveCount == 1)
    #expect(replayResolver.resolveCount == 0)
    #expect(a3WriterTotalChanges(fixture) == writerChanges)
    #expect(
        try a4ScheduleGraphSnapshot(
            fixture.database,
            scheduleId: records.schedule.id
        ) == firstSnapshot
    )

    try await replayWakeHarness.orchestrator.wakeScheduledPlanning(replayed)
    await replayWakeHarness.provider.gate.waitUntilEntered()
    let replayedWorkId = try #require(replayed.workId)
    let replayedWork = try #require(try await fixture.database.pool.read {
        try DurableWorkRecord.fetchOne($0, key: replayedWorkId)
    })
    #expect(replayWakeHarness.provider.callCount == 1)
    #expect(replayedWork.state == .running)
    #expect(await replayWakeHarness.eventProbe.snapshot().isEmpty)
#if DEBUG
    #expect(
        (await replayWakeHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts(
                ensureTick: 1,
                planningStarted: 0,
                kick: 1
            )
    )
#endif
    try await finishA4WakeRuntimeHarness(
        replayWakeHarness,
        releaseProvider: true
    )

    let concurrentFixture = try makeR01FailureFirstFixture()
    let concurrentRecords = try r01ScheduleRecords(
        concurrentFixture,
        suffix: "same-slot-concurrent"
    )
    let concurrentAt = Date(timeIntervalSince1970: 1_700_000_300)
    let race = try await a4RunScheduleRace(
        database: concurrentFixture.database,
        firstCommand: try a4ScheduleCommand(
            concurrentRecords.schedule,
            scheduledAt: concurrentAt,
            traceId: "a4-race-first-trace"
        ),
        secondCommand: try a4ScheduleCommand(
            concurrentRecords.schedule,
            scheduledAt: concurrentAt,
            traceId: "a4-race-second-trace"
        )
    )
    #expect(race.results.count == 2)
    #expect(race.resolverCounts == [1, 1])
    #expect(race.results[0].fire == race.results[1].fire)
    #expect(race.results[0].missionId == race.results[1].missionId)
    #expect(race.results[0].workId == race.results[1].workId)
    #expect(
        race.results.map(\.disposition).filter { $0 == .inserted }.count
            == 1
    )
    #expect(
        race.results.map(\.disposition).filter { $0 == .replayed }.count
            == 1
    )
    let concurrentSnapshot = try a4ScheduleGraphSnapshot(
        concurrentFixture.database,
        scheduleId: concurrentRecords.schedule.id
    )
    #expect(concurrentSnapshot.fires.count == 1)
    #expect(concurrentSnapshot.cursor?.version == 1)
    #expect(concurrentSnapshot.missionCount == 1)
    #expect(concurrentSnapshot.squadCount == 1)
    #expect(concurrentSnapshot.workCount == 1)
    #expect(
        ["a4-race-first-trace", "a4-race-second-trace"]
            .contains(concurrentSnapshot.fires.first?.traceId ?? "")
    )
}

@Test func broadcastFailureDoesNotRewriteStartedFire() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let insertedWakeHarness = try await makeA4WakeRuntimeHarness(fixture)
    let records = try r01ScheduleRecords(fixture, suffix: "broadcast")
    let result = try fixture.database.startScheduledMission(
        try a4ScheduleCommand(
            records.schedule,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_400),
            traceId: "a4-broadcast-trace"
        ),
        planningProviderResolver: R01PlanningResolver()
    )
    #expect(result.disposition == .inserted)
    #expect(result.fire.state == .started)
    _ = try fixture.database.findOrCreateGuideThread(
        campId: fixture.camp.id
    )
    let committed = try a4ScheduleGraphSnapshot(
        fixture.database,
        scheduleId: records.schedule.id
    )

    try await fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER a4_fail_guide_broadcast
            BEFORE INSERT ON chat_message
            BEGIN
              SELECT RAISE(ABORT, 'a4 injected guide broadcast failure');
            END
            """)
    }
    #expect(throws: DatabaseError.self) {
        _ = try fixture.database.appendGuideBroadcast(
            campId: fixture.camp.id,
            text: "定时行动已开始"
        )
    }
    #expect(
        try a4ScheduleGraphSnapshot(
            fixture.database,
            scheduleId: records.schedule.id
        ) == committed
    )

    let source = try PlanningTestFixtures.source(
        "AgentLoopApp/AppStore.swift"
    )
    let fireFunction = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private func executeScheduledFire("
    )
    try fireFunction.requireTokensInOrder([
        "missionWorkflowController.fireSchedule(",
        "switch outcome",
        "case .notCommitted(let failure)",
        "case .committed(let result)",
        "applyScheduledFireEffects(result)",
        "case .committedWithVisibilityFailure(let result, let failure)",
        "applyScheduledFireEffects(result)",
    ])
    let committedEffects = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private func applyScheduledFireEffects("
    )
    try committedEffects.requireTokensInOrder([
        "if result.fire.state == .started",
        "missionWorkflowController.publishScheduleWake(",
        "case .notCommitted(let failure)",
        "case .committed",
        "missionWorkflowController.publishScheduleBroadcast(",
        "case .notCommitted(let failure)",
        "case .committed",
        "refreshScheduleRegistrations()",
    ])
    let forbiddenVisibilityMutations = [
        "startScheduledMission(",
        "commitScheduledMission(",
        "replayMissedScheduleFire(",
        "claimScheduleFire(",
        "recordScheduleMissed(",
        "appendScheduleFiredEvent(",
        "scheduleEvaluationCursor(",
        "advanceCursor(",
        "saveSchedule(",
        "setScheduleEnabled(",
        "deleteSchedule(",
        "lastFiredAt",
        "schedule_fire",
        "schedule_evaluation_cursor",
    ]
    for forbidden in forbiddenVisibilityMutations {
        try committedEffects.requireAbsent(forbidden)
    }
    try committedEffects.requireAbsent("db.")

    let controllerSource = try PlanningTestFixtures.source(
        "AgentLoopApplication/MissionWorkflowController.swift"
    )
    let wakeOwner = try PlanningTestFixtures.uniqueFunction(
        in: controllerSource,
        signature: "package func publishScheduleWake("
    )
    try wakeOwner.requireTokensInOrder([
        "try await ports.wake(result)",
        "return .committed(result)",
        "return .committedWithVisibilityFailure(",
        "reporter.capture(error, trace: trace)",
    ])
    let broadcastOwner = try PlanningTestFixtures.uniqueFunction(
        in: controllerSource,
        signature: "package func publishScheduleBroadcast("
    )
    try broadcastOwner.requireTokensInOrder([
        "try ports.broadcastFire(result)",
        "return .committed(result)",
        "return .committedWithVisibilityFailure(",
        "reporter.capture(error, trace: trace)",
    ])
    for forbidden in forbiddenVisibilityMutations {
        try wakeOwner.requireAbsent(forbidden)
        try broadcastOwner.requireAbsent(forbidden)
    }

    let root = a3RepositoryRoot()
    let manifestURL = root.appendingPathComponent(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/"
            + "p1-a4-schedule-fire/a4-entry-source-manifest.sha256"
    )
    try a3RequireRegularNonSymlink(manifestURL)
    let manifestData = try Data(contentsOf: manifestURL)
    #expect(
        CanonicalJSONV1.sha256Hex(manifestData)
            == "6c59ed6d2e411ee2859f16833567471142b59958fabbc56f0f3f78a3602abc71"
    )
    let entries = try a3Revision02ManifestEntries(manifestData)
    #expect(entries.count == 206)
    #expect(Set(entries.map(\.path)).count == entries.count)
    let manifestRows = String(decoding: manifestData, as: UTF8.self)
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map(String.init)
    #expect(manifestRows == manifestRows.sorted())

    let p1bExactAllowlist = a3P1BExactAllowlist()
    #expect(p1bExactAllowlist.count == 66)
    let p1cExactAllowlist = a3P1CExactAllowlist()
    #expect(p1cExactAllowlist.count == 25)
    let p1dExactAllowlist = a3P1DExactAllowlist()
    #expect(p1dExactAllowlist.count == 46)
    let p1eExactAllowlist = try a3P1EExactAllowlist(
        repositoryRoot: root
    )
    let p1f1ExactAllowlist = try a3P1F1ExactAllowlist(
        repositoryRoot: root
    )
    let entryPaths = Set(entries.map(\.path))
    let p1bEntryIntersection = entryPaths.intersection(
        p1bExactAllowlist
    )
    #expect(p1bEntryIntersection.count == 46)
    let p1cEntryIntersection = entryPaths.intersection(
        p1cExactAllowlist
    )
    #expect(
        p1cEntryIntersection == [
            "Sources/AgentLoopCore/Database/EventKind.swift",
            "Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift",
            "Sources/AgentLoopTestSuite/BoardServerTests.swift",
        ]
    )
    let rawP1DIntersection = entryPaths.intersection(
        p1dExactAllowlist
    )
    #expect(rawP1DIntersection.count == 23)
    let p1dEntryIntersection = rawP1DIntersection
        .subtracting(p1bEntryIntersection)
        .subtracting(p1cEntryIntersection)
    #expect(p1dEntryIntersection.count == 19)
    let rawP1EIntersection = entryPaths.intersection(p1eExactAllowlist)
    #expect(rawP1EIntersection.count == 40)
    let p1eEntryIntersection = rawP1EIntersection
        .subtracting(p1bEntryIntersection)
        .subtracting(p1cEntryIntersection)
        .subtracting(p1dEntryIntersection)
    #expect(
        p1eEntryIntersection == a3P1EHistoricalSuccessorExclusions
    )
    let rawP1F1Intersection = entryPaths.intersection(p1f1ExactAllowlist)
    let p1f1EntryIntersection = rawP1F1Intersection
        .subtracting(p1bEntryIntersection)
        .subtracting(p1cEntryIntersection)
        .subtracting(p1dEntryIntersection)
        .subtracting(p1eEntryIntersection)
    #expect(p1f1EntryIntersection.count == 17)
    #expect(
        entryPaths.intersection(r9fStateRootIsolationTestFiles).count == 5
    )
    #expect(
        entryPaths.intersection(r9fProviderCompletionHandleFiles).count == 5
    )
    let unaffectedEntries = entries.filter {
        !p1bEntryIntersection.contains($0.path)
            && !p1cEntryIntersection.contains($0.path)
            && !p1dEntryIntersection.contains($0.path)
            && !p1eEntryIntersection.contains($0.path)
            && !p1f1EntryIntersection.contains($0.path)
            && !r9fStateRootIsolationTestFiles.contains($0.path)
            && !r9fProviderCompletionHandleFiles.contains($0.path)
    }
    #expect(unaffectedEntries.count == 105)
    #expect(
        desktopCodingClosureDevelopmentPackagingSuccessorFiles20260906.count == 1
    )
    #expect(
        desktopCodingClosureDevelopmentPackagingSuccessorFiles20260906
            == ["scripts/run-app.sh"]
    )
    let packagingSuccessorEntries = unaffectedEntries.filter {
        desktopCodingClosureDevelopmentPackagingSuccessorFiles20260906.contains($0.path)
    }
    let byteExactEntries = unaffectedEntries.filter {
        !desktopCodingClosureDevelopmentPackagingSuccessorFiles20260906.contains($0.path)
    }
    #expect(Set(packagingSuccessorEntries.map(\.path)) == ["scripts/run-app.sh"])
    #expect(packagingSuccessorEntries.count == 1)
    #expect(byteExactEntries.count == 104)
    #expect(packagingSuccessorEntries.count + byteExactEntries.count == 105)
    for entry in byteExactEntries {
        let url = root.appendingPathComponent(entry.path)
        try a3RequireRegularNonSymlink(url)
        #expect(
            try a3SHA256(at: url) == entry.hash,
            "A4 unaffected entry drifted: \(entry.path)"
        )
    }
    for entry in packagingSuccessorEntries {
        let url = root.appendingPathComponent(entry.path)
        try a3RequireRegularNonSymlink(url)
        #expect(
            try a3SHA256(at: url)
                == "34ff641b68379e1978367cd2c5c9890638c5913627942858767efe56b475428c",
            "A4 reviewed development packaging successor drifted: \(entry.path)"
        )
    }

    let p1bNewPaths = p1bExactAllowlist
        .subtracting(entryPaths)
        .subtracting([
            "Sources/AgentLoopCore/Database/ScheduleStore.swift",
            "Sources/AgentLoopCore/Database/AppDatabase.swift",
            "Sources/AgentLoopCore/Work/DurableWork.swift",
            "Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift",
            "Sources/AgentLoopCore/Database/DurableWorkStore.swift",
            "Sources/AgentLoopCore/Kernel/Orchestrator.swift",
            "Sources/AgentLoopCore/Kernel/ScheduleMath.swift",
            "Sources/AgentLoopApp/MissionScheduler.swift",
            "Sources/AgentLoopTestSuite/ScheduleTests.swift",
            "Sources/AgentLoopTestSuite/DatabaseTests.swift",
            "Sources/AgentLoopTestSuite/DurablePlanningTests.swift",
            "Sources/P1MigrationMatrixRunner/main.swift",
            "scripts/verify-p1-migrations-sqlite-matrix.sh",
        ])
    #expect(p1bNewPaths.count == 10)
    for path in p1bNewPaths {
        try a3RequireRegularNonSymlink(
            root.appendingPathComponent(path)
        )
    }
    let p1dNewPaths = p1dExactAllowlist
        .subtracting(entryPaths)
        .subtracting(p1bExactAllowlist)
        .subtracting(p1cExactAllowlist)
    #expect(p1dNewPaths.count == 14)
    for path in p1dNewPaths {
        try a3RequireRegularNonSymlink(
            root.appendingPathComponent(path)
        )
    }

    try await insertedWakeHarness.orchestrator.wakeScheduledPlanning(result)
    await insertedWakeHarness.provider.gate.waitUntilEntered()
    await insertedWakeHarness.eventProbe.waitForCount(1)
    let insertedWorkId = try #require(result.workId)
    let insertedMissionId = try #require(result.missionId)
    let insertedRunning = try #require(try await fixture.database.pool.read {
        try DurableWorkRecord.fetchOne($0, key: insertedWorkId)
    })
    #expect(insertedWakeHarness.provider.callCount == 1)
    #expect(insertedRunning.state == .running)
    #expect(
        await insertedWakeHarness.eventProbe.snapshot()
            == [insertedMissionId]
    )
#if DEBUG
    #expect(
        (await insertedWakeHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts(
                ensureTick: 1,
                planningStarted: 1,
                kick: 1
            )
    )
#endif
    try await finishA4WakeRuntimeHarness(
        insertedWakeHarness,
        releaseProvider: true
    )

    let failedFixture = try makeR01FailureFirstFixture()
    let failedHarness = try await makeA4WakeRuntimeHarness(failedFixture)
    let failedRecords = try r01ScheduleRecords(
        failedFixture,
        suffix: "wake-failed"
    )
    let failedResult = try failedFixture.database.startScheduledMission(
        try a4ScheduleCommand(
            failedRecords.schedule,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_410),
            preparation: .unavailable,
            traceId: "a4-wake-failed"
        ),
        planningProviderResolver: R01PlanningResolver()
    )
    try await failedHarness.orchestrator.wakeScheduledPlanning(failedResult)
    #expect(failedResult.fire.state == .failed)
    #expect(failedHarness.provider.callCount == 0)
    #expect((await failedHarness.eventProbe.snapshot()).isEmpty)
#if DEBUG
    #expect(
        (await failedHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts()
    )
#endif
    try await finishA4WakeRuntimeHarness(
        failedHarness,
        releaseProvider: false
    )

    let terminalFixture = try makeR01FailureFirstFixture()
    let terminalHarness = try await makeA4WakeRuntimeHarness(terminalFixture)
    let terminalRecords = try r01ScheduleRecords(
        terminalFixture,
        suffix: "wake-terminal"
    )
    let terminalResult = try terminalFixture.database.startScheduledMission(
        try a4ScheduleCommand(
            terminalRecords.schedule,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_420),
            traceId: "a4-wake-terminal"
        ),
        planningProviderResolver: R01PlanningResolver()
    )
    let terminalWorkId = try #require(terminalResult.workId)
    try a3AdvanceReplayState(
        .succeeded,
        fixture: terminalFixture,
        workId: terminalWorkId
    )
    try await terminalHarness.orchestrator.wakeScheduledPlanning(
        terminalResult
    )
    #expect(terminalHarness.provider.callCount == 0)
    #expect((await terminalHarness.eventProbe.snapshot()).isEmpty)
#if DEBUG
    #expect(
        (await terminalHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts()
    )
#endif
    #expect(
        try await terminalFixture.database.pool.read {
            try DurableWorkRecord.fetchOne($0, key: terminalWorkId)?.state
        } == .succeeded
    )
    try await finishA4WakeRuntimeHarness(
        terminalHarness,
        releaseProvider: false
    )

    let processGateFixture = try makeR01FailureFirstFixture()
    let processGateHarness = try await makeA4WakeRuntimeHarness(
        processGateFixture,
        recover: false,
        requiresStartupRecovery: true
    )
    let processGateRecords = try r01ScheduleRecords(
        processGateFixture,
        suffix: "wake-process-gate"
    )
    let processGateResult = try processGateFixture.database
        .startScheduledMission(
            try a4ScheduleCommand(
                processGateRecords.schedule,
                scheduledAt: Date(timeIntervalSince1970: 1_700_000_430),
                traceId: "a4-wake-process-gate"
            ),
            planningProviderResolver: R01PlanningResolver()
        )
    try await processGateHarness.orchestrator.wakeScheduledPlanning(
        processGateResult
    )
    #expect(processGateHarness.provider.callCount == 0)
    #expect((await processGateHarness.eventProbe.snapshot()).isEmpty)
#if DEBUG
    #expect(
        (await processGateHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts()
    )
#endif
    #expect(
        try await processGateFixture.database.pool.read {
            try DurableWorkRecord.fetchOne(
                $0,
                key: try #require(processGateResult.workId)
            )?.state
        } == .queued
    )
    try await finishA4WakeRuntimeHarness(
        processGateHarness,
        releaseProvider: false
    )

    let durableGateFixture = try makeR01FailureFirstFixture()
    let durableGateHarness = try await makeA4WakeRuntimeHarness(
        durableGateFixture
    )
    let durableGateRecords = try r01ScheduleRecords(
        durableGateFixture,
        suffix: "wake-durable-gate"
    )
    let durableGateResult = try durableGateFixture.database
        .startScheduledMission(
            try a4ScheduleCommand(
                durableGateRecords.schedule,
                scheduledAt: Date(timeIntervalSince1970: 1_700_000_440),
                traceId: "a4-wake-durable-gate"
            ),
            planningProviderResolver: R01PlanningResolver()
        )
    _ = try durableGateFixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    try await durableGateHarness.orchestrator.wakeScheduledPlanning(
        durableGateResult
    )
    #expect(durableGateHarness.provider.callCount == 0)
    #expect((await durableGateHarness.eventProbe.snapshot()).isEmpty)
#if DEBUG
    #expect(
        (await durableGateHarness.observationProbe.snapshot()).counts
            == A3ObservationCounts()
    )
#endif
    #expect(
        try await durableGateFixture.database.pool.read {
            try DurableWorkRecord.fetchOne(
                $0,
                key: try #require(durableGateResult.workId)
            )?.state
        } == .queued
    )
    try await finishA4WakeRuntimeHarness(
        durableGateHarness,
        releaseProvider: false
    )
}

@MainActor
@Test func scheduleMissionStartUsesCheckedUTCMillisecondsKey() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let records = try r01ScheduleRecords(fixture, suffix: "millis")
    let firstSeconds = Double(bitPattern: 0x41d954fc40000001)
    let secondSeconds = Double(bitPattern: 0x41d954fc40000002)
    let firstCommand = try a4ScheduleCommand(
        records.schedule,
        scheduledAt: Date(timeIntervalSince1970: firstSeconds),
        traceId: "a4-submillisecond-first"
    )
    let secondCommand = try a4ScheduleCommand(
        records.schedule,
        scheduledAt: Date(timeIntervalSince1970: secondSeconds),
        traceId: "a4-submillisecond-second"
    )
    let first = try fixture.database.startScheduledMission(
        firstCommand,
        planningProviderResolver: R01PlanningResolver()
    )
    let second = try fixture.database.startScheduledMission(
        secondCommand,
        planningProviderResolver: R01PlanningResolver()
    )
    let firstKey = "mission-start:schedule:\(records.schedule.id):"
        + CanonicalJSONV1.sha256Hex(Data(firstCommand.context.slotKey.utf8))
        + ":v1"
    let secondKey = "mission-start:schedule:\(records.schedule.id):"
        + CanonicalJSONV1.sha256Hex(Data(secondCommand.context.slotKey.utf8))
        + ":v1"
    let firstWorkId = try #require(first.workId)
    let secondWorkId = try #require(second.workId)

    #expect(first.disposition == .inserted)
    #expect(second.disposition == .inserted)
    #expect(first.fire.scheduledAt.timeIntervalSince1970.bitPattern == 0x41d954fc40000001)
    #expect(second.fire.scheduledAt.timeIntervalSince1970.bitPattern == 0x41d954fc40000002)
    #expect(first.fire.slotKey != second.fire.slotKey)
    #expect(firstKey != secondKey)
    #expect(
        try r01PlanningWork(fixture, idempotencyKey: firstKey)?.id
            == firstWorkId
    )
    #expect(
        try r01PlanningWork(fixture, idempotencyKey: secondKey)?.id
            == secondWorkId
    )
}

@MainActor
@Test func scheduleMillisecondsOverflowClaimsSlotThenRecordsMissedWithoutMission()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let records = try r01ScheduleRecords(fixture, suffix: "overflow")
    let fireDate = Date(timeIntervalSince1970: 10_000_000_000_000_000)
    let timeZone = try #require(
        TimeZone(identifier: "America/Los_Angeles")
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    let before = try a4ScheduleGraphSnapshot(
        fixture.database,
        scheduleId: records.schedule.id
    )

    #expect(throws: ScheduleSlotComponentsUnavailableError.self) {
        _ = try ScheduleMath.slotContext(
            for: fireDate,
            frequency: records.schedule.frequency,
            hour: records.schedule.hour,
            minute: records.schedule.minute,
            weekday: records.schedule.weekday,
            calendar: calendar,
            timeZone: timeZone
        )
    }
    #expect(
        try a4ScheduleGraphSnapshot(
            fixture.database,
            scheduleId: records.schedule.id
        ) == before
    )
}

@MainActor
@Test func schedulePlannerSelectionFailureClaimsSlotThenRecordsMissedOnce()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let records = try r01ScheduleRecords(fixture, suffix: "selection")
    let fireDate = Date(timeIntervalSince1970: 1_700_000_100)
    let command = try a4ScheduleCommand(
        records.schedule,
        scheduledAt: fireDate,
        preparation: .unavailable,
        traceId: "a4-runtime-unavailable-first"
    )
    let firstResolver = R01PlanningResolver(onResolve: {
        throw R01ResolverError.unavailable
    })
    let first = try fixture.database.startScheduledMission(
        command,
        planningProviderResolver: firstResolver
    )
    let secondResolver = R01PlanningResolver(onResolve: {
        throw R01ResolverError.unavailable
    })
    let second = try fixture.database.startScheduledMission(
        try a4ScheduleCommand(
            records.schedule,
            scheduledAt: fireDate,
            preparation: .unavailable,
            traceId: "a4-runtime-unavailable-late"
        ),
        planningProviderResolver: secondResolver
    )
    let missed = try fixture.database.scheduleMissedEvents().filter {
        $0.payloadJson.contains(records.schedule.id)
    }

    #expect(first.fire.state == .failed)
    #expect(first.fire.errorCode == "schedule_runtime_unavailable")
    #expect(first.disposition == .inserted)
    #expect(second.disposition == .replayed)
    #expect(second.fire == first.fire)
    #expect(missed.count == 1)
    #expect(try fixture.database.schedule(id: records.schedule.id)?.lastFiredAt == nil)
    #expect(
        try fixture.database.scheduleEvaluationCursor(
            scheduleId: records.schedule.id
        )?.version == 1
    )
    #expect(firstResolver.resolveCount == 0)
    #expect(secondResolver.resolveCount == 0)
}

@MainActor
@Test func nonFiniteScheduleFireFailsBeforeClaimWithoutWrites() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let records = try r01ScheduleRecords(
        fixture,
        suffix: "non-finite"
    )
    let before = try a4ScheduleGraphSnapshot(
        fixture.database,
        scheduleId: records.schedule.id
    )
    var calendar = Calendar(identifier: .gregorian)
    let timeZone = try #require(
        TimeZone(identifier: "America/Los_Angeles")
    )
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone

    #expect(throws: InvalidSchedulePlanningFireTimeError.self) {
        _ = try ScheduleMath.slotContext(
            for: Date(timeIntervalSince1970: .nan),
            frequency: records.schedule.frequency,
            hour: records.schedule.hour,
            minute: records.schedule.minute,
            weekday: records.schedule.weekday,
            calendar: calendar,
            timeZone: timeZone
        )
    }

    let after = try a4ScheduleGraphSnapshot(
        fixture.database,
        scheduleId: records.schedule.id
    )
    #expect(after == before)
}

@MainActor
@Test func a1bSchedulePathDoesNotCreateScheduleFireOrChangeClaimCAS()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let records = try r01ScheduleRecords(fixture, suffix: "claim-cas")
    let fireDate = Date(timeIntervalSince1970: 1_700_000_200)
    let first = try fixture.database.startScheduledMission(
        try a4ScheduleCommand(
            records.schedule,
            scheduledAt: fireDate,
            traceId: "a4-claim-cas-first"
        ),
        planningProviderResolver: R01PlanningResolver()
    )
    let second = try fixture.database.startScheduledMission(
        try a4ScheduleCommand(
            records.schedule,
            scheduledAt: fireDate,
            traceId: "a4-claim-cas-second"
        ),
        planningProviderResolver: R01PlanningResolver(onResolve: {
            throw R01ResolverError.unavailable
        })
    )
    let scheduleFireTableCount = try await fixture.database.pool.read {
        database in
        try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*)
                FROM sqlite_master
                WHERE type = 'table' AND name = 'schedule_fire'
                """
        ) ?? 0
    }

    #expect(first.disposition == .inserted)
    #expect(second.disposition == .replayed)
    #expect(second.fire == first.fire)
    #expect(scheduleFireTableCount == 1)
    #expect(
        try fixture.database.scheduleFires(
            scheduleId: records.schedule.id
        ).count == 1
    )
    #expect(
        try fixture.database.scheduleEvaluationCursor(
            scheduleId: records.schedule.id
        )?.version == 1
    )
    #expect(try fixture.database.schedule(id: records.schedule.id)?.lastFiredAt == fireDate)
}

@Test func manualAppCallsiteCapturesCoordinatorCommandBeforeTask() throws {
    let source = try PlanningTestFixtures.source(
        "AgentLoopApp/AppStore.swift"
    )
    let function = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "func startMission(goal: String"
    )
    try function.requireTokensInOrder([
        "planningEntryCoordinator.prepareManual(",
        "pendingManualMissionStart = command",
        "missionTask = Task",
        "planningEntryCoordinator.startManual(",
        "planningEntryCoordinator.clearManualAfterSuccess(",
    ])
    try function.requireAbsent("orchestrator.startMission(")
}

@Test func candidateAppCallsiteCapturesCoordinatorCommandBeforeFirstAwait()
    throws
{
    let adapterSource = try PlanningTestFixtures.source(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let adapter = try PlanningTestFixtures.uniqueFunction(
        in: adapterSource,
        signature:
            "func startMission(from draft: MissionDraftViewState) async throws -> String"
    )
    try adapter.requireTokensInOrder([
        "guard let capability = draft.startCapability",
        "let trace = makeMissionOperationTrace(operation: .missionStart)",
        "switch capturePlanningRuntimeSelection(trace: trace)",
        "capability.makeMissionStartRequest(",
        "switch await missionWorkflowController.start(",
        "_ = await refreshMissionDetailProjection(missionId: missionId)",
        "_ = await refreshMissionIndexProjection()",
    ])
    try adapter.requireAbsent("orchestrator.startMission(")
    try adapter.requireAbsent("orchestrator.convertCandidateAndEnqueuePlanning(")
    try adapter.requireAbsent("db.convertCandidateAndEnqueuePlanning(")
    try adapter.requireAbsent("existingMissionId(")
    try adapter.requireAbsent("linkConverted(")
    try adapter.requireAbsent("MissionDraftFactory(db: db).draft(")
    try adapter.requireAbsent("planningEntryCoordinator.startCandidate(")

    let controllerSource = try PlanningTestFixtures.source(
        "AgentLoopApplication/MissionWorkflowController.swift"
    )
    let controller = try PlanningTestFixtures.uniqueFunction(
        in: controllerSource,
        signature: "package func start("
    )
    try controller.requireTokensInOrder([
        "guard request.durableTraceId == trace.traceId",
        "reporter.capture(",
        "return await orchestrator.startMission(",
        "idempotencyKey: request.idempotencyKey",
        "trace: trace",
    ])
    try controller.requireAbsent("MissionDraftFactory")
    try controller.requireAbsent("convertCandidateAndEnqueuePlanning(")
    try controller.requireAbsent("db.")

    let factorySource = PlanningTestFixtures.maskCommentsAndStrings(
        in: try PlanningTestFixtures.source(
            "AgentLoopCore/Product/MissionDraftFactory.swift"
        )
    )
    #expect(!factorySource.contains("func existingMissionId("))
    #expect(!factorySource.contains("func linkConverted("))
    #expect(!factorySource.contains("func convert("))

    let ledgerSource = try PlanningTestFixtures.source(
        "AgentLoopCore/Database/DurableWorkStore.swift"
    )
    let atomicEntry = try PlanningTestFixtures.uniqueFunction(
        in: ledgerSource,
        signature: "package func convertCandidateAndEnqueuePlanning("
    )
    try atomicEntry.requireAbsent("enqueueMissionPlanning(")
}

private func a3P1CExactAllowlist() -> Set<String> {
    [
        "Sources/AgentLoopCore/Database/AppDatabase.swift",
        "Sources/AgentLoopCore/Database/EventKind.swift",
        "Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift",
        "Sources/AgentLoopCore/Domain/CommandEnvelope.swift",
        "Sources/AgentLoopCore/Domain/DomainEvent.swift",
        "Sources/AgentLoopCore/Domain/InputEnvelope.swift",
        "Sources/AgentLoopCore/Domain/GoalController.swift",
        "Sources/AgentLoopCore/Domain/CoachContracts.swift",
        "Sources/AgentLoopCore/Domain/UnderstandingCard.swift",
        "Sources/AgentLoopCore/Database/DomainEventStore.swift",
        "Sources/AgentLoopCore/Database/InputGoalStore.swift",
        "Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift",
        "Sources/AgentLoopCore/Work/InputParsingWorker.swift",
        "Sources/AgentLoopCore/Database/DurableWorkStore.swift",
        "Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift",
        "Sources/AgentLoopApplication/InputWorkflowController.swift",
        "Sources/AgentLoopApplication/LocalCaptureIdentity.swift",
        "Sources/AgentLoopTestSuite/DomainEventContractTests.swift",
        "Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift",
        "Sources/AgentLoopTestSuite/GoalCoachContractTests.swift",
        "Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift",
        "Sources/AgentLoopTestSuite/BoardServerTests.swift",
        "Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift",
        "Sources/P1MigrationMatrixRunner/main.swift",
        "scripts/verify-p1-migrations-sqlite-matrix.sh",
    ]
}

private func a3P1DExactAllowlist() -> Set<String> {
    [
        "Sources/AgentLoopApp/AppStore.swift",
        "Sources/AgentLoopApp/CodingRanchContracts.swift",
        "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
        "Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift",
        "Sources/AgentLoopApplication/AcceptanceWorkflowController.swift",
        "Sources/AgentLoopApplication/ExternalOperationWorkflowCoordinator.swift",
        "Sources/AgentLoopCore/Database/AppDatabase.swift",
        "Sources/AgentLoopCore/Database/ApprovalGrantStore.swift",
        "Sources/AgentLoopCore/Database/DomainEventStore.swift",
        "Sources/AgentLoopCore/Database/OutcomeStore.swift",
        "Sources/AgentLoopCore/Database/Records.swift",
        "Sources/AgentLoopCore/Domain/Acceptance.swift",
        "Sources/AgentLoopCore/Domain/ApprovalGrant.swift",
        "Sources/AgentLoopCore/Domain/GoalController.swift",
        "Sources/AgentLoopCore/Domain/Outcome.swift",
        "Sources/AgentLoopCore/Domain/OutcomeContract.swift",
        "Sources/AgentLoopCore/Domain/Verification.swift",
        "Sources/AgentLoopCore/Kernel/Orchestrator.swift",
        "Sources/AgentLoopCore/Loop/BoardToolServer.swift",
        "Sources/AgentLoopCore/Loop/CardRunner.swift",
        "Sources/AgentLoopCore/Loop/CliProcessBackend.swift",
        "Sources/AgentLoopCore/Mcp/McpToolBridge.swift",
        "Sources/AgentLoopCore/Tools/ApprovalGate.swift",
        "Sources/AgentLoopCore/Tools/ApprovalPolicy.swift",
        "Sources/AgentLoopCore/Tools/BoardTools.swift",
        "Sources/AgentLoopCore/Tools/ExternalOperationAdapter.swift",
        "Sources/AgentLoopCore/Tools/FileTools.swift",
        "Sources/AgentLoopCore/Tools/ShellTool.swift",
        "Sources/AgentLoopCore/Tools/ToolExecutor.swift",
        "Sources/AgentLoopCore/Tools/WebFetchTool.swift",
        "Sources/AgentLoopTestSuite/AcceptanceWorkflowTests.swift",
        "Sources/AgentLoopTestSuite/ApprovalGateTests.swift",
        "Sources/AgentLoopTestSuite/ApprovalGrantContractTests.swift",
        "Sources/AgentLoopTestSuite/ApprovalPolicyTests.swift",
        "Sources/AgentLoopTestSuite/BoardToolsTests.swift",
        "Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift",
        "Sources/AgentLoopTestSuite/DurablePlanningTests.swift",
        "Sources/AgentLoopTestSuite/GoalCoachContractTests.swift",
        "Sources/AgentLoopTestSuite/GoldenPathTests.swift",
        "Sources/AgentLoopTestSuite/MissionRollupTests.swift",
        "Sources/AgentLoopTestSuite/OrchestratorTests.swift",
        "Sources/AgentLoopTestSuite/OutcomeContractTests.swift",
        "Sources/AgentLoopTestSuite/ToolExecutorTests.swift",
        "Sources/AgentLoopTestSuite/VerificationContractTests.swift",
        "Sources/P1MigrationMatrixRunner/main.swift",
        "scripts/verify-p1-migrations-sqlite-matrix.sh",
    ]
}

private func a3P1BExactAllowlist() -> Set<String> {
    [
        "Sources/AgentLoopCore/Database/AppDatabase.swift",
        "Sources/AgentLoopCore/Kernel/Orchestrator.swift",
        "Sources/AgentLoopCore/Kernel/Planner.swift",
        "Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift",
        "Sources/AgentLoopCore/Work/PlanningProviderResolver.swift",
        "Sources/AgentLoopCore/Mcp/McpServerManager.swift",
        "Sources/AgentLoopCore/Mcp/McpToolBridge.swift",
        "Sources/AgentLoopCore/Database/KnowledgeStore.swift",
        "Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift",
        "Sources/AgentLoopCore/Knowledge/Distiller.swift",
        "Sources/AgentLoopCore/Rumination/RuminationService.swift",
        "Sources/AgentLoopCore/Chat/GuideChatService.swift",
        "Sources/AgentLoopCore/Support/KeychainStore.swift",
        "Sources/AgentLoopCore/Provider/OpenAIOAuthSession.swift",
        "Sources/AgentLoopCore/Provider/ProfileScopedDefaults.swift",
        "Sources/AgentLoopCore/Provider/ModelCatalogService.swift",
        "Sources/AgentLoopCore/Database/RuntimeProfileStore.swift",
        "Sources/AgentLoopCore/Product/RuntimeProfileBootstrap.swift",
        "Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift",
        "Sources/AgentLoopCore/Database/ScheduleStore.swift",
        "Sources/AgentLoopCore/Chat/ChatService.swift",
        "Sources/AgentLoopCore/Product/MissionDraftFactory.swift",
        "Sources/AgentLoopCore/Product/ProductBootstrapService.swift",
        "Sources/AgentLoopCore/Observability/FailureRecord.swift",
        "Sources/AgentLoopCore/Observability/FailureReporter.swift",
        "Sources/AgentLoopCore/Observability/ContextDependencyLoader.swift",
        "Sources/AgentLoopApplication/WorkflowLoadState.swift",
        "Sources/AgentLoopApplication/MissionWorkflowController.swift",
        "Sources/AgentLoopApplication/InputWorkflowController.swift",
        "Sources/AgentLoopApplication/RuntimeProfileWorkflowController.swift",
        "Sources/AgentLoopApplication/McpWorkflowController.swift",
        "Sources/AgentLoopApp/AppStore.swift",
        "Sources/AgentLoopApp/McpStore.swift",
        "Sources/AgentLoopApp/MissionScheduler.swift",
        "Sources/AgentLoopApp/ScheduledMissionNotifications.swift",
        "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
        "Sources/AgentLoopApp/CodingRanchContracts.swift",
        "Sources/AgentLoopApp/Views/RootView.swift",
        "Sources/AgentLoopApp/Views/RuntimeProfileViews.swift",
        "Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift",
        "Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift",
        "Sources/AgentLoopApp/Views/Components/McpStationSection.swift",
        "Sources/AgentLoopApp/Views/Components/NoteListPane.swift",
        "Sources/AgentLoopApp/Views/CompanionEditorView.swift",
        "Sources/AgentLoopApp/Views/ScheduleManagerView.swift",
        "Sources/AgentLoopTestSuite/ApplicationWorkflowTests.swift",
        "Sources/AgentLoopTestSuite/FailureVisibilityTests.swift",
        "Sources/AgentLoopTestSuite/McpTests.swift",
        "Sources/AgentLoopTestSuite/McpManagerSpikeTest.swift",
        "Sources/AgentLoopTestSuite/KnowledgeStoreTests.swift",
        "Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift",
        "Sources/AgentLoopTestSuite/MemoryDistillTests.swift",
        "Sources/AgentLoopTestSuite/DistillerTests.swift",
        "Sources/AgentLoopTestSuite/RuntimeProfileTests.swift",
        "Sources/AgentLoopTestSuite/ModelCatalogPolicyTests.swift",
        "Sources/AgentLoopTestSuite/OpenAIOAuthSessionTests.swift",
        "Sources/AgentLoopTestSuite/ScheduleTests.swift",
        "Sources/AgentLoopTestSuite/GuideChatTests.swift",
        "Sources/AgentLoopTestSuite/DatabaseTests.swift",
        "Sources/AgentLoopTestSuite/DurablePlanningTests.swift",
        "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
        "Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift",
        "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
        "Package.swift",
        "Sources/P1MigrationMatrixRunner/main.swift",
        "scripts/verify-p1-migrations-sqlite-matrix.sh",
    ]
}

@Test func a3Revision02EntryBoundaryRemainsByteExact() throws {
    let root = a3RepositoryRoot()
    let manifestURL = root.appendingPathComponent(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/"
            + "p1-a3-candidate-transaction/"
            + "revision02-entry-source-manifest.sha256"
    )
    try a3RequireRegularNonSymlink(manifestURL)
    let manifestData = try Data(contentsOf: manifestURL)
    #expect(
        CanonicalJSONV1.sha256Hex(manifestData)
            == "3766f9f8aa902736b1a2a10b80a90c2783aad7fa5615d32eeb101799729f379e"
    )
    let entries = try a3Revision02ManifestEntries(manifestData)
    #expect(entries.count == 206)
    #expect(entries.map(\.path) == entries.map(\.path).sorted())
    #expect(Set(entries.map(\.path)).count == entries.count)

    let originalA3Allowlist: Set<String> = [
        "Sources/AgentLoopCore/Product/MissionDraftFactory.swift",
        "Sources/AgentLoopCore/Work/DurableWork.swift",
        "Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift",
        "Sources/AgentLoopCore/Database/DurableWorkStore.swift",
        "Sources/AgentLoopCore/Database/AppDatabase.swift",
        "Sources/AgentLoopCore/Kernel/Orchestrator.swift",
        "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
        "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
        "Sources/AgentLoopTestSuite/DurablePlanningTests.swift",
    ]
    let a4HistoricalManifestExclusions: Set<String> = [
        "Sources/AgentLoopCore/Database/ScheduleStore.swift",
        "Sources/AgentLoopCore/Kernel/ScheduleMath.swift",
        "Sources/AgentLoopApp/MissionScheduler.swift",
        "Sources/AgentLoopTestSuite/ScheduleTests.swift",
        "Sources/AgentLoopTestSuite/DatabaseTests.swift",
        "Sources/P1MigrationMatrixRunner/main.swift",
        "scripts/verify-p1-migrations-sqlite-matrix.sh",
    ]
    let p1bExactAllowlist = a3P1BExactAllowlist()
    #expect(p1bExactAllowlist.count == 66)
    let p1cExactAllowlist = a3P1CExactAllowlist()
    #expect(p1cExactAllowlist.count == 25)
    let p1dExactAllowlist = a3P1DExactAllowlist()
    #expect(p1dExactAllowlist.count == 46)
    let p1eExactAllowlist = try a3P1EExactAllowlist(
        repositoryRoot: root
    )
    let p1f1ExactAllowlist = try a3P1F1ExactAllowlist(
        repositoryRoot: root
    )
    let manifestPaths = Set(entries.map(\.path))
    let rawP1BIntersection = manifestPaths.intersection(p1bExactAllowlist)
    #expect(rawP1BIntersection.count == 49)
    let historicalP1BOverlap = rawP1BIntersection.intersection(
        a4HistoricalManifestExclusions
    )
    #expect(historicalP1BOverlap.count == 6)
    let p1bSuccessorExclusions = rawP1BIntersection.subtracting(
        a4HistoricalManifestExclusions
    )
    #expect(p1bSuccessorExclusions.count == 43)
    let rawP1CIntersection = manifestPaths.intersection(p1cExactAllowlist)
    #expect(
        rawP1CIntersection == [
            "Sources/AgentLoopCore/Database/EventKind.swift",
            "Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift",
            "Sources/AgentLoopTestSuite/BoardServerTests.swift",
            "Sources/P1MigrationMatrixRunner/main.swift",
            "scripts/verify-p1-migrations-sqlite-matrix.sh",
        ]
    )
    let p1cSuccessorExclusions = rawP1CIntersection
        .subtracting(a4HistoricalManifestExclusions)
        .subtracting(p1bSuccessorExclusions)
    #expect(
        p1cSuccessorExclusions == [
            "Sources/AgentLoopCore/Database/EventKind.swift",
            "Sources/AgentLoopApp/Views/CodingRanch/Fixtures/CodingRanchPreviewFixtures.swift",
            "Sources/AgentLoopTestSuite/BoardServerTests.swift",
        ]
    )
    let rawP1DIntersection = manifestPaths.intersection(p1dExactAllowlist)
    #expect(rawP1DIntersection.count == 24)
    let p1dSuccessorExclusions = rawP1DIntersection
        .subtracting(a4HistoricalManifestExclusions)
        .subtracting(p1bSuccessorExclusions)
        .subtracting(p1cSuccessorExclusions)
    #expect(p1dSuccessorExclusions.count == 19)
    let p1dNewPaths = p1dExactAllowlist
        .subtracting(manifestPaths)
        .subtracting(p1bExactAllowlist)
        .subtracting(p1cExactAllowlist)
    #expect(p1dNewPaths.count == 14)
    for path in p1dNewPaths {
        try a3RequireRegularNonSymlink(
            root.appendingPathComponent(path)
        )
    }
    let rawP1EIntersection = manifestPaths.intersection(p1eExactAllowlist)
    #expect(rawP1EIntersection.count == 42)
    let p1eSuccessorExclusions = rawP1EIntersection
        .subtracting(originalA3Allowlist)
        .subtracting(a4HistoricalManifestExclusions)
        .subtracting(p1bSuccessorExclusions)
        .subtracting(p1cSuccessorExclusions)
        .subtracting(p1dSuccessorExclusions)
    #expect(
        p1eSuccessorExclusions == a3P1EHistoricalSuccessorExclusions
    )
    let rawP1F1Intersection = manifestPaths.intersection(p1f1ExactAllowlist)
    let p1f1SuccessorExclusions = rawP1F1Intersection
        .subtracting(originalA3Allowlist)
        .subtracting(a4HistoricalManifestExclusions)
        .subtracting(p1bSuccessorExclusions)
        .subtracting(p1cSuccessorExclusions)
        .subtracting(p1dSuccessorExclusions)
        .subtracting(p1eSuccessorExclusions)
    #expect(p1f1SuccessorExclusions.count == 16)
    #expect(
        manifestPaths.intersection(r9fStateRootIsolationTestFiles).count == 5
    )
    #expect(
        manifestPaths.intersection(r9fProviderCompletionHandleFiles).count
            == 5
    )
    #expect(
        desktopCodingClosureRuntimeDiagnosticsSuccessorFiles.count == 1
    )
    #expect(
        manifestPaths.intersection(
            desktopCodingClosureRuntimeDiagnosticsSuccessorFiles
        ).isEmpty
    )
    for path in desktopCodingClosureRuntimeDiagnosticsSuccessorFiles {
        try a3RequireRegularNonSymlink(
            root.appendingPathComponent(path)
        )
    }
    #expect(desktopCodingClosureA1FoundationSuccessorFiles20260905.count == 4)
    #expect(
        desktopCodingClosureA1FoundationSuccessorFiles20260905 == [
            "Sources/AgentLoopCore/Domain/DesktopGoalWorkflow.swift",
            "Sources/AgentLoopCore/Database/DesktopGoalWorkflowStore.swift",
            "Sources/AgentLoopTestSuite/DesktopGoalFoundationTests.swift",
            "Sources/AgentLoopTestSuite/DesktopGoalMigrationTests.swift",
        ]
    )
    #expect(
        desktopCodingClosureA1FoundationSuccessorFiles20260905
            .intersection(manifestPaths).isEmpty
    )
    let historicalSourcePaths = originalA3Allowlist
        .union(a4HistoricalManifestExclusions)
        .union(p1bExactAllowlist)
        .union(p1cExactAllowlist)
        .union(p1dExactAllowlist)
        .union(p1eExactAllowlist)
        .union(p1f1ExactAllowlist)
        .union(r9fStateRootIsolationTestFiles)
        .union(r9fProviderCompletionHandleFiles)
        .union(desktopCodingClosureRuntimeDiagnosticsSuccessorFiles)
    #expect(
        desktopCodingClosureA1FoundationSuccessorFiles20260905
            .intersection(historicalSourcePaths).isEmpty
    )
    #expect(
        desktopCodingClosureBlockingProgressSuccessorFiles20260908.count == 2
    )
    #expect(
        desktopCodingClosureBlockingProgressSuccessorFiles20260908 == [
            "Sources/AgentLoopCore/Support/BlockingProcessOperation.swift",
            "Sources/AgentLoopTestSuite/BlockingProcessOperationTests.swift",
        ]
    )
    #expect(
        desktopCodingClosureBlockingProgressSuccessorFiles20260908
            .intersection(manifestPaths).isEmpty
    )
    #expect(
        desktopCodingClosureBlockingProgressSuccessorFiles20260908
            .intersection(historicalSourcePaths).isEmpty
    )
    #expect(
        desktopCodingClosureBlockingProgressSuccessorFiles20260908
            .intersection(
                desktopCodingClosureA1FoundationSuccessorFiles20260905
            ).isEmpty
    )
    for path in desktopCodingClosureA1FoundationSuccessorFiles20260905 {
        try a3RequireRegularNonSymlink(root.appendingPathComponent(path))
    }
    for path in desktopCodingClosureBlockingProgressSuccessorFiles20260908 {
        try a3RequireRegularNonSymlink(root.appendingPathComponent(path))
    }
    #expect(desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908.count == 2)
    #expect(
        desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908 == [
            "Sources/AgentLoopTestSuite/CliMechanicsFixture.swift",
            "Sources/RunTests/main.swift",
        ]
    )
    #expect(
        desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908
            .intersection(manifestPaths) == ["Sources/RunTests/main.swift"]
    )
    #expect(
        desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908
            .intersection(desktopCodingClosureBlockingProgressSuccessorFiles20260908)
            .isEmpty
    )
    for path in desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908 {
        try a3RequireRegularNonSymlink(root.appendingPathComponent(path))
    }
    let liveEntries = entries.filter {
        !a4HistoricalManifestExclusions.contains($0.path)
            && !p1bSuccessorExclusions.contains($0.path)
            && !p1cSuccessorExclusions.contains($0.path)
            && !p1dSuccessorExclusions.contains($0.path)
            && !p1eSuccessorExclusions.contains($0.path)
            && !p1f1SuccessorExclusions.contains($0.path)
            && !r9fStateRootIsolationTestFiles.contains($0.path)
            && !r9fProviderCompletionHandleFiles.contains($0.path)
    }
    #expect(liveEntries.count == 102)
    let unaffectedHistoricalEntries = liveEntries.filter {
        !desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908
            .contains($0.path)
    }
    #expect(unaffectedHistoricalEntries.count == 101)
    let originalRunnerEntry = try #require(entries.first {
        $0.path == "Sources/RunTests/main.swift"
    })
    #expect(
        originalRunnerEntry.hash
            == "70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3"
    )
    var enumerated = try a3RegularFilesRecursively(
        under: root.appendingPathComponent("Sources"),
        repositoryRoot: root
    ).filter {
        !originalA3Allowlist.contains($0)
            && !p1bExactAllowlist.contains($0)
            && !p1cExactAllowlist.contains($0)
            && !p1dExactAllowlist.contains($0)
            && !p1eExactAllowlist.contains($0)
            && !p1f1ExactAllowlist.contains($0)
            && !r9fStateRootIsolationTestFiles.contains($0)
            && !r9fProviderCompletionHandleFiles.contains($0)
            && !desktopCodingClosureRuntimeDiagnosticsSuccessorFiles.contains($0)
            && !desktopCodingClosureA1FoundationSuccessorFiles20260905.contains($0)
            && !desktopCodingClosureBlockingProgressSuccessorFiles20260908.contains($0)
            && !desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908.contains($0)
    }
    enumerated.append("Package.resolved")
    enumerated.removeAll {
        a4HistoricalManifestExclusions.contains($0)
    }
    enumerated.sort()
    #expect(enumerated.count == 101)
    #expect(enumerated == unaffectedHistoricalEntries.map(\.path))

    for entry in unaffectedHistoricalEntries {
        let url = root.appendingPathComponent(entry.path)
        try a3RequireRegularNonSymlink(url)
        #expect(
            try a3SHA256(at: url) == entry.hash,
            "A3 unaffected entry drifted: \(entry.path)"
        )
    }

    #expect(desktopCodingClosureNativeCLIFixtureSuccessorHashes20260908.count == 2)
    #expect(
        Set(desktopCodingClosureNativeCLIFixtureSuccessorHashes20260908.keys)
            == desktopCodingClosureNativeCLIFixtureSuccessorFiles20260908
    )
    for (path, expectedHash) in
        desktopCodingClosureNativeCLIFixtureSuccessorHashes20260908
    {
        #expect(try a3SHA256(at: root.appendingPathComponent(path)) == expectedHash)
    }

    let frozenEntryHashes = [
        "Package.resolved":
            "d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a",
    ]
    #expect(frozenEntryHashes.count == 1)
    for (path, expectedHash) in frozenEntryHashes {
        let url = root.appendingPathComponent(path)
        try a3RequireRegularNonSymlink(url)
        #expect(try a3SHA256(at: url) == expectedHash)
    }
}

@Test func a3Revision02DebugObservationIsGuardedAndAdjacent() throws {
    let orchestratorSource = try PlanningTestFixtures.source(
        "AgentLoopCore/Kernel/Orchestrator.swift"
    )
    let testSource = try PlanningTestFixtures.source(
        "AgentLoopTestSuite/DurablePlanningTests.swift"
    )
    let maskedTestSource = PlanningTestFixtures.maskCommentsAndStrings(
        in: testSource
    )
    let seamTokens = [
        "A3CandidatePostCommitObservationForTesting",
        "a3CandidatePostCommitObserverForTesting",
        "armA3CandidatePostCommitObserverForTesting",
        "clearA3CandidatePostCommitObserverForTesting",
        "observeA3CandidatePostCommitForTesting",
    ]
    try a3RequireDebugGuarded(
        source: orchestratorSource,
        tokens: seamTokens
    )
    try a3RequireDebugGuarded(source: testSource, tokens: seamTokens)

    let candidate = try PlanningTestFixtures.uniqueFunction(
        in: orchestratorSource,
        signature: "package func convertCandidateAndEnqueuePlanning("
    )
    try candidate.requireTokensInOrder([
        "let result = try await planningSupervisor",
        "let currentWork = try await db.pool.read",
        "let durableMode = try db.dispatchMode()",
        "guard currentWork.kind == .planning",
        "guard dispatchPhase.permitsDispatch",
        "switch currentWork.state",
        "observeA3CandidatePostCommitForTesting(",
        ".ensureTick",
        "ensureTickStarted()",
        "if result.disposition == .inserted",
        "observeA3CandidatePostCommitForTesting(",
        ".planningStarted",
        "emit(.planningStarted(",
        "observeA3CandidatePostCommitForTesting(",
        ".kick",
        "planningSupervisor.kick()",
        "case .running, .succeeded, .failed, .canceled",
    ])
    let candidateBody = String(candidate.maskedBody)
    #expect(
        candidateBody.components(
            separatedBy: "observeA3CandidatePostCommitForTesting("
        ).count == 4
    )
    #expect(
        candidateBody.components(separatedBy: "ensureTickStarted()")
            .count == 2
    )
    #expect(
        candidateBody.components(separatedBy: "emit(.planningStarted(")
            .count == 2
    )
    #expect(
        candidateBody.components(
            separatedBy: "planningSupervisor.kick()"
        ).count == 2
    )

    let maskedOrchestrator = PlanningTestFixtures.maskCommentsAndStrings(
        in: orchestratorSource
    )
    #expect(
        maskedOrchestrator.components(
            separatedBy: "observeA3CandidatePostCommitForTesting("
        ).count == 8
    )
    let observer = try PlanningTestFixtures.uniqueFunction(
        in: orchestratorSource,
        signature: "private func observeA3CandidatePostCommitForTesting("
    )
    try observer.requireAbsent("CandidatePlanningStartResult")
    try observer.requireAbsent("planningSupervisor")
    try observer.requireAbsent("ensureTickStarted")
    try observer.requireAbsent("emit(")
    try observer.requireAbsent("db.")

    #expect(!maskedTestSource.contains("A3ResolveBarrier"))
    #expect(
        maskedTestSource.contains(
            "private final class A3DedicatedThreadHandle: @unchecked Sendable"
        )
    )
    #expect(maskedTestSource.contains("A3DedicatedThreadCandidateRaceState"))
    #expect(
        maskedTestSource.contains("private func a3RunDedicatedCandidateRace(")
    )
    #expect(maskedTestSource.contains("firstThread.start()"))
    #expect(maskedTestSource.contains("secondThread.start()"))
    #expect(maskedTestSource.contains("abortedBy"))
    #expect(maskedTestSource.contains("indexedOutcomes"))

    let dedicatedRace = try PlanningTestFixtures.uniqueFunction(
        in: testSource,
        signature: "private func a3RunDedicatedCandidateRace("
    )
    let dedicatedRaceBody = String(dedicatedRace.maskedBody)
    let rawDedicatedRaceBody = String(dedicatedRace.body)
    #expect(
        dedicatedRaceBody.components(separatedBy: "Thread {").count == 3
    )
    #expect(
        dedicatedRaceBody.components(separatedBy: ".start()").count == 3
    )
    #expect(
        dedicatedRaceBody.components(
            separatedBy: "state.rendezvous(index:"
        ).count == 3
    )
    #expect(
        rawDedicatedRaceBody.components(
            separatedBy: "AgentLoop.A3CandidateRace.first"
        ).count == 2
    )
    #expect(
        rawDedicatedRaceBody.components(
            separatedBy: "AgentLoop.A3CandidateRace.second"
        ).count == 2
    )
    try dedicatedRace.requireTokensInOrder([
        "withCheckedThrowingContinuation",
        "Thread",
        "firstThread.start()",
        "secondThread.start()",
        "DispatchQueue",
        "firstThread.isFinished",
        "secondThread.isFinished",
        "state.finishedOutcomes()",
        "continuation.resume(",
    ])
    #expect(
        dedicatedRaceBody.components(
            separatedBy: "continuation.resume("
        ).count == 2
    )
    try dedicatedRace.requireAbsent("Task {")
    try dedicatedRace.requireAbsent("Task.detached")
    try dedicatedRace.requireAbsent("withTaskGroup")

    let dedicatedStateParts = maskedTestSource.components(
        separatedBy: "private final class A3DedicatedThreadCandidateRaceState"
    )
    #expect(dedicatedStateParts.count == 2)
    let dedicatedStateBody = try #require(
        dedicatedStateParts.last?.components(
            separatedBy: "private struct A3DedicatedThreadCandidateRaceResult"
        ).first
    )
    #expect(!dedicatedStateBody.contains("CheckedContinuation"))
    #expect(!dedicatedStateBody.contains("continuation"))
    #expect(!dedicatedStateBody.contains(".resume"))
    #expect(
        dedicatedStateBody.components(
            separatedBy: "condition.broadcast()"
        ).count == 3
    )

    let rendezvous = try PlanningTestFixtures.uniqueFunction(
        in: testSource,
        signature: "func rendezvous(index: Int) throws"
    )
    try rendezvous.requireTokensInOrder([
        "arrivedIndices.insert(index).inserted",
        "arrivedIndices.count == 2",
        "released = true",
        "condition.broadcast()",
        "condition.wait()",
    ])
    let outcomeStore = try PlanningTestFixtures.uniqueFunction(
        in: testSource,
        signature: "func store("
    )
    try outcomeStore.requireTokensInOrder([
        "indexedOutcomes.indices.contains(index)",
        "indexedOutcomes[index] != nil",
        "storageFailure",
        "recordAbortLocked(index: index)",
        "indexedOutcomes[index] = storedOutcome",
    ])
    try outcomeStore.requireAbsent("continuation")
    let abortOwner = try PlanningTestFixtures.uniqueFunction(
        in: testSource,
        signature: "private func recordAbortLocked(index: Int)"
    )
    try abortOwner.requireTokensInOrder([
        "abortedBy == nil",
        "abortedBy = index",
        "condition.broadcast()",
    ])
    try abortOwner.requireAbsent("continuation")
    let finishedOutcomes = try PlanningTestFixtures.uniqueFunction(
        in: testSource,
        signature: "func finishedOutcomes() throws"
    )
    try finishedOutcomes.requireTokensInOrder([
        "storageFailure",
        "indexedOutcomes[0]",
        "indexedOutcomes[1]",
        "return [first, second]",
    ])
    try finishedOutcomes.requireAbsent("continuation")
    #expect(
        maskedTestSource.components(
            separatedBy: "state.rendezvous(index:"
        ).count == 3
    )

    let observationBarrierParts = maskedTestSource.components(
        separatedBy: "private actor A3ObservationBarrier"
    )
    #expect(observationBarrierParts.count == 2)
    let observationBarrierBody = try #require(
        observationBarrierParts.last?.components(
            separatedBy: "private struct A3ObservationCounts"
        ).first
    )
    #expect(observationBarrierBody.contains("withCheckedContinuation"))
    #expect(!observationBarrierBody.contains("NSCondition"))

    for signature in [
        "@Test func candidateConversionRollsBackWhenWorkInsertFails()",
        "@Test func candidateConversionReplayReturnsOneMission()",
        "@Test func candidateConversionNeverLeavesUnlinkedMission()",
        "@Test func candidateWithWrongCampCowFailsBeforeWrites()",
    ] {
        let canonical = try PlanningTestFixtures.uniqueFunction(
            in: testSource,
            signature: signature
        )
        let body = String(canonical.maskedBody)
        #expect(!body.contains("A3ResolveBarrier"))
        #expect(!body.contains("enterAndWait()"))
    }
    let concurrentOwner = try PlanningTestFixtures.uniqueFunction(
        in: testSource,
        signature:
            "@Test func candidateConversionNeverLeavesUnlinkedMission()"
    )
    let concurrentOwnerBody = String(concurrentOwner.maskedBody)
    #expect(!concurrentOwnerBody.contains("Task.detached"))
    #expect(!concurrentOwnerBody.contains("rendezvous"))
    #expect(!concurrentOwnerBody.contains("A3DedicatedThreadCandidateRaceState"))
}

@Test func proposalAppCallsiteCapturesCoordinatorCommandBeforeTask() throws {
    let source = try PlanningTestFixtures.source(
        "AgentLoopApp/AppStore.swift"
    )
    let function = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "func confirmProposal(messageId: String)"
    )
    try function.requireTokensInOrder([
        "planningEntryCoordinator.captureConfirmedProposal(",
        "confirmingProposals.insert(messageId)",
        "Task",
        "planningEntryCoordinator.startConfirmedProposal(",
    ])
    try function.requireAbsent("orchestrator.confirmSquadProposal(")
}

@Test func scheduleAppCallsiteDelegatesClaimAndStartExclusively() throws {
    let source = try PlanningTestFixtures.source(
        "AgentLoopApp/AppStore.swift"
    )
    let fire = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private func executeScheduledFire("
    )
    try fire.requireTokensInOrder([
        "missionWorkflowController.recordMissedSchedule(",
        "missionWorkflowController.fireSchedule(",
        "switch outcome",
        "case .committed",
        "applyScheduledFireEffects(",
        "appendScheduleCatchupIfNeeded(",
    ])
    try fire.requireAbsent("db.claimScheduleFire(")
    try fire.requireAbsent("db.recordScheduleMissed(")
    try fire.requireAbsent("db.appendScheduleFiredEvent(")
    try fire.requireAbsent("orchestrator.startMission(")
    try fire.requireAbsent("planningEntryCoordinator.startScheduledMission(")

    let effects = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private func applyScheduledFireEffects("
    )
    try effects.requireTokensInOrder([
        "missionWorkflowController.publishScheduleWake(",
        "missionWorkflowController.publishScheduleBroadcast(",
        "refreshScheduleRegistrations()",
    ])

    let startup = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private func startScheduleSystem() async"
    )
    try startup.requireTokensInOrder([
        "missionScheduler.start()",
        "refreshScheduleRegistrations()",
        "missionWorkflowController.loadStartupMissedFires(",
        "executeScheduledFire(request, missed: true)",
    ])

    let catchup = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private func appendScheduleCatchupIfNeeded("
    )
    let rawCatchupStart = try #require(
        source.range(of: "    private func appendScheduleCatchupIfNeeded(")
    )
    let rawCatchupEnd = try #require(
        source.range(
            of: "    private func refreshScheduleRegistrations() async",
            range: rawCatchupStart.upperBound..<source.endIndex
        )
    )
    let normalizedCatchup = String(
        source[rawCatchupStart.lowerBound..<rawCatchupEnd.lowerBound]
    )
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
    #expect(
        normalizedCatchup.contains(
            "result.fire.errorCode == \"schedule_missed_while_offline\""
        )
    )
    #expect(
        normalizedCatchup.contains(
            "reason == \"定时行动在应用离线期间错过了触发时间。\""
        )
    )
    try catchup.requireAbsent(
        "result.fire.errorCode != nil"
    )
    try catchup.requireAbsent(
        "result.fire.errorMessage != nil"
    )
}

@Test func appPlanningCallsitesContainNoDirectOrchestratorStart() throws {
    for path in [
        "AgentLoopApp/AppStore.swift",
        "AgentLoopApp/CodingRanchStoreAdapter.swift",
        "AgentLoopApp/MissionScheduler.swift",
    ] {
        let source = try PlanningTestFixtures.source(path)
        let masked = PlanningTestFixtures.maskCommentsAndStrings(in: source)
        #expect(!masked.contains("orchestrator.startMission("))
        #expect(!masked.contains("orchestrator.confirmSquadProposal("))
    }
}

@Test func uiPreviewUsesProcessLocalDefaultsBeforeBootstrapAndReload() throws {
    let source = try PlanningTestFixtures.source(
        "AgentLoopApp/AppStore.swift"
    )
    let masked = PlanningTestFixtures.maskCommentsAndStrings(in: source)

    let previewStore = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "private final class ProcessLocalPreviewUserDefaults"
    )
    try previewStore.requireTokensInOrder([
        "private var values:",
        "override func object(forKey",
        "override func set(_ value: Any?",
        "override func set(_ value: Int",
        "override func set(_ value: Float",
        "override func set(_ value: Double",
        "override func set(_ value: Bool",
        "override func set(_ url: URL?",
        "override func removeObject(forKey",
        "override func string(forKey",
        "override func integer(forKey",
        "override func bool(forKey",
        "override func stringArray(forKey",
    ])
    try previewStore.requireAbsent("super.")
    try previewStore.requireAbsent("UserDefaults.standard")

    let defaultsFactory = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature:
            "nonisolated private static func makeUserDefaults() -> UserDefaults"
    )
    try defaultsFactory.requireTokensInOrder([
        "guard isUIPreview else",
        "return .standard",
        "ProcessLocalPreviewUserDefaults(",
    ])

    let initializer = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "init()"
    )
    try initializer.requireTokensInOrder([
        "let appDefaults = Self.makeUserDefaults()",
        "userDefaults = appDefaults",
        "appDefaults.string(forKey:",
        "appDefaults.set(",
        "let scopedDefaults = ProfileScopedDefaults(defaults: appDefaults)",
        "let localRuntimeBootstrap = SynchronousRuntimeBootstrap(",
        "database: database",
        "defaults: scopedDefaults",
        "presence: runtimePresence",
        "let localRuntimeRequest = RuntimeBootstrapRequest(",
        "let localRuntimeResult = captureSynchronous(",
        "try localRuntimeBootstrap.run(",
    ])
    let catalogRefresh = try PlanningTestFixtures.uniqueFunction(
        in: source,
        signature: "func refreshCatalog(profileId: String) async -> String?"
    )
    try catalogRefresh.requireTokensInOrder([
        "ModelCatalogService(",
        "defaults: profileScopedDefaults",
        ".refresh(",
    ])

    #expect(masked.contains("private let userDefaults: UserDefaults"))
    #expect(
        masked.contains(
            "ProfileScopedDefaults(defaults: userDefaults)"
        )
    )
    #expect(!masked.contains("UserDefaults.standard"))
    #expect(!masked.contains("ProfileScopedDefaults()"))
    #expect(!masked.contains("ModelCatalogService()"))
}

@Test func inputOutputUsageOverflowTerminalizesWithExactEvidence() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        goal: "验证溢出",
        idempotencyKey: "mission-start:overflow:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "overflow-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let result = r01PlanResult(
        usage: Usage(
            inputTokens: Int.max,
            outputTokens: Int.max,
            cacheReadTokens: 0
        )
    )
    guard case let .usageOverflow(work) =
        try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: result,
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected usage overflow")
        return
    }
    #expect(work.id == ids.workId)
    #expect(work.state == .failed)
    #expect(work.errorCode == "usage_overflow")
    #expect(try fixture.database.mission(id: ids.missionId)?.spentTokens == 0)
    let overflowEvent = try #require(
        try fixture.database.events(missionId: ids.missionId)
            .first { $0.kind == EventKind.planningUsageOverflow }
    )
    let evidence = try JSONDecoder().decode(
        PlanningUsageOverflowEvidenceV1.self,
        from: Data(overflowEvent.payloadJson.utf8)
    )
    #expect(
        evidence == .missionProjection(
            existingSpentTokens: 0,
            attemptUsage: try PlanningUsageCountersV1(
                cacheReadTokens: 0,
                inputTokens: Int64.max,
                outputTokens: Int64.max
            ),
            overflowFields: [.attemptBillableTokens]
        )
    )
}

@Test func haltedPlanningCannotClaimThroughGenericStore() throws {
    let fixture = try makeR01FailureFirstFixture()
    _ = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "failure-first-halt"
    )
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )

    #expect(throws: (any Error).self) {
        _ = try fixture.database.claimNextPlanning(
            workerId: "worker-a",
            now: Date(timeIntervalSinceReferenceDate: 1_001),
            leaseDuration: 60
        )
    }
}

@Test func sameMissionStartReplayRunsBeforeCredentialAndCatalogPreflight()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let first = try r01EnqueuePlanning(fixture)
    let unavailable = R01PlanningResolver(onResolve: {
        throw R01ResolverError.unavailable
    })

    let replay = try r01EnqueuePlanning(
        fixture,
        traceId: "ignored-replay-trace",
        resolver: unavailable
    )

    #expect(replay.missionId == first.missionId)
    #expect(replay.workId == first.workId)
    #expect(unavailable.resolveCount == 0)
}

@Test func sameMissionStartReplayAfterProfileDeletionReturnsOriginalIdsAndTrace()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let first = try r01EnqueuePlanning(fixture)
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE companion SET runtimeProfileId = NULL"
        )
        try database.execute(
            sql: "DELETE FROM runtime_profile WHERE id = ?",
            arguments: [fixture.profile.id]
        )
    }
    let replay = try r01EnqueuePlanning(
        fixture,
        traceId: "new-trace-must-not-win"
    )
    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(
            id: replay.workId
        )
    )

    #expect(replay.missionId == first.missionId)
    #expect(replay.workId == first.workId)
    #expect(work.traceId == "planning-trace-first")
}

@Test func sameMissionStartReplayDoesNotConstructProvider() throws {
    let fixture = try makeR01FailureFirstFixture()
    _ = try r01EnqueuePlanning(fixture)
    let replayResolver = R01PlanningResolver()
    _ = try r01EnqueuePlanning(
        fixture,
        resolver: replayResolver
    )
    #expect(replayResolver.resolveCount == 0)
}

@Test func sameMissionStartConflictWinsOverCurrentProviderFailure() throws {
    let fixture = try makeR01FailureFirstFixture()
    _ = try r01EnqueuePlanning(fixture)
    let unavailable = R01PlanningResolver(onResolve: {
        throw R01ResolverError.unavailable
    })

    #expect(throws: DurableWorkReplayConflictError.self) {
        _ = try r01EnqueuePlanning(
            fixture,
            goal: "不同目标",
            resolver: unavailable
        )
    }
    #expect(unavailable.resolveCount == 0)
}

@Test func sameMissionStartPayloadOrGraphConflictFailsWithoutWrites() throws {
    let fixture = try makeR01FailureFirstFixture()
    let first = try r01EnqueuePlanning(fixture)
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE durable_work SET inputHash = ? WHERE id = ?",
            arguments: [String(repeating: "b", count: 64), first.workId]
        )
    }
    let before = try fixture.database.pool.read { database in
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM mission"
        ) ?? 0
    }
    #expect(throws: DurableWorkReplayConflictError.self) {
        _ = try r01EnqueuePlanning(fixture)
    }
    let after = try fixture.database.pool.read { database in
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM mission"
        ) ?? 0
    }
    #expect(after == before)
}

@Test func planningReplayPreservesFirstTrace() throws {
    let fixture = try makeR01FailureFirstFixture()
    let first = try r01EnqueuePlanning(
        fixture,
        traceId: "first-trace"
    )
    _ = try r01EnqueuePlanning(
        fixture,
        traceId: "second-trace"
    )
    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(
            id: first.workId
        )
    )
    #expect(work.traceId == "first-trace")
}

@Test func planningProfileKindDriftBetweenPreflightAndTransactionWritesNothing()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let driftResolver = R01PlanningResolver(onResolve: {
        try fixture.database.pool.write { database in
            try database.execute(
                sql: """
                    UPDATE runtime_profile
                    SET kind = 'openai_api'
                    WHERE id = ?
                    """,
                arguments: [fixture.profile.id]
            )
        }
    })

    #expect(throws: InvalidDurableWorkStateError.self) {
        _ = try r01EnqueuePlanning(
            fixture,
            resolver: driftResolver
        )
    }
    let counts = try fixture.database.pool.read { database in
        (
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM mission"
            ) ?? 0,
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM durable_work"
            ) ?? 0
        )
    }
    #expect(counts.0 == 0)
    #expect(counts.1 == 0)
}

@Test func planningSpecificProviderLifecycleUsesSealedLedgerOwner() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "specialized-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let renewed = try fixture.database.renewPlanningLease(
        claim: claim,
        now: Date(timeIntervalSinceReferenceDate: 1_001),
        leaseDuration: 60
    )

    #expect(renewed.workId == ids.workId)
    #expect(renewed.version == claim.version + 1)
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        _ = try DurableWorkStore(database: fixture.database).renewLease(
            claim: renewed,
            now: Date(timeIntervalSinceReferenceDate: 1_002),
            leaseDuration: 60
        )
    }
}

@Test func planningClaimAndRenewReturnPersistedSubmillisecondLeaseAndTerminalize()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:persisted-lease:v1"
    )
    let store = DurableWorkStore(database: fixture.database)
    let claimNow = Date(timeIntervalSinceReferenceDate: 1_000.123_456)
    let claimed = try #require(try fixture.database.claimNextPlanning(
        workerId: "persisted-lease-worker",
        now: claimNow,
        leaseDuration: 60.654_321
    ))
    let persistedAfterClaim = try #require(try store.work(id: ids.workId))

    #expect(claimed.leaseExpiresAt == persistedAfterClaim.leaseExpiresAt)

    let renewNow = Date(timeIntervalSinceReferenceDate: 1_001.234_567)
    let renewed = try fixture.database.renewPlanningLease(
        claim: claimed,
        now: renewNow,
        leaseDuration: 120.765_432
    )
    let persistedAfterRenew = try #require(try store.work(id: ids.workId))

    #expect(renewed.leaseExpiresAt == persistedAfterRenew.leaseExpiresAt)
    #expect(renewed.version == claimed.version + 1)
    guard case .succeeded =
        try fixture.database.commitPlanningSuccess(
            claim: renewed,
            result: r01PlanResult(),
            now: renewNow.addingTimeInterval(1)
        )
    else {
        Issue.record("Expected renewed persisted claim to terminalize")
        return
    }
    #expect(try store.work(id: ids.workId)?.state == .succeeded)
}

@Test func planningSpecificRecoveryAdoptsInterruptedWithoutGenericAPI() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    _ = try fixture.database.claimNextPlanning(
        workerId: "old-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    )
    let adopted = try fixture.database.adoptInterruptedPlanning(
        currentWorkerId: "new-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )

    #expect(adopted.map(\.id) == [ids.workId])
    #expect(adopted[0].state == .queued)
    #expect(adopted[0].errorCode == "worker_interrupted")
    let reclaimed = try #require(try fixture.database.claimNextPlanning(
        workerId: "new-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_002),
        leaseDuration: 60
    ))
    #expect(reclaimed.attempt == 2)
}

@Test func planningSuccessWithFallbackIsRejectedWithoutWrites() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "fallback-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let before = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )

    #expect(throws: UnexpectedPlanningFallbackError.self) {
        _ = try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(fallbackReason: "legacy fallback"),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    }

    #expect(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
            == before
    )
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
    #expect(
        try fixture.database.events(missionId: ids.missionId)
            .filter { $0.kind == EventKind.planningTokens }
            .isEmpty
    )
}

@Test func planningSuccessWithNilFallbackWritesNoFallbackEvent() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:nil-fallback:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "nil-fallback-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    guard case .succeeded =
        try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(fallbackReason: nil),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected planning success")
        return
    }

    #expect(
        try fixture.database.events(missionId: ids.missionId)
            .allSatisfy { $0.kind != EventKind.planFallback }
    )
}

@Test func planningSuccessCommitsTokensCardsRollupAndWorkOnce() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "success-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    guard case let .succeeded(work) =
        try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected planning success")
        return
    }

    let mission = try #require(
        try fixture.database.mission(id: ids.missionId)
    )
    let events = try fixture.database.events(missionId: ids.missionId)
    let tokenEvents = events.filter {
        $0.kind == EventKind.planningTokens
    }
    #expect(work.state == .succeeded)
    #expect(mission.spentTokens == 5)
    #expect(mission.status == .executing)
    #expect(try fixture.database.cards(missionId: ids.missionId).count == 1)
    #expect(tokenEvents.count == 1)
    #expect(
        tokenEvents[0].payloadJson
            == #"{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3}"#
    )
    #expect(events.filter { $0.kind == EventKind.planCompleted }.count == 1)
}

@Test func planningSuccessOverBudgetCreatesCardsButDispatchesNone() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        budgetTokens: 1,
        idempotencyKey: "mission-start:over-budget:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "over-budget-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    guard case .succeeded =
        try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(
                usage: Usage(
                    inputTokens: 2,
                    outputTokens: 3,
                    cacheReadTokens: 0
                )
            ),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected planning success")
        return
    }

    let cards = try fixture.database.cards(missionId: ids.missionId)
    let runCount = try fixture.database.pool.read { database in
        try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*)
                FROM run
                WHERE cardId IN (
                  SELECT id FROM card WHERE missionId = ?
                )
                """,
            arguments: [ids.missionId]
        ) ?? 0
    }
    #expect(try fixture.database.mission(id: ids.missionId)?.spentTokens == 5)
    #expect(cards.map(\.status) == [.todo])
    #expect(runCount == 0)
}

@Test func planningUsageNilWritesNoTokenEvent() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "nil-usage-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let failure = try PlanningAttemptFailure(
        code: "planning_provider_failed",
        safeMessage: "规划服务失败。",
        disposition: .deterministic,
        usage: nil
    )
    guard case .failed =
        try fixture.database.recordPlanningAttemptFailure(
            claim: claim,
            failure: failure,
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected terminal failure")
        return
    }
    #expect(
        try fixture.database.events(missionId: ids.missionId)
            .filter { $0.kind == EventKind.planningTokens }
            .isEmpty
    )
}

@Test func negativePlanningUsageFailsBeforeSQL() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:negative-usage:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "negative-usage-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let before = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "DELETE FROM kernel_control WHERE id = 'global'"
        )
    }

    do {
        _ = try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(
                usage: Usage(
                    inputTokens: -1,
                    outputTokens: 0,
                    cacheReadTokens: 0
                )
            ),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
        Issue.record("Expected negative usage rejection")
    } catch let error as InvalidPlanningPayloadError {
        #expect(error == .negativeUsage)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
            == before
    )
}

@Test func planningUsageZeroWritesExactTokenEvent() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "zero-usage-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let failure = try PlanningAttemptFailure(
        code: "planning_provider_failed",
        safeMessage: "规划服务失败。",
        disposition: .deterministic,
        usage: Usage()
    )
    _ = try fixture.database.recordPlanningAttemptFailure(
        claim: claim,
        failure: failure,
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let tokenEvents = try fixture.database.events(
        missionId: ids.missionId
    ).filter { $0.kind == EventKind.planningTokens }
    #expect(tokenEvents.count == 1)
    #expect(
        tokenEvents[0].payloadJson
            == #"{"cacheReadTokens":0,"inputTokens":0,"outputTokens":0}"#
    )
}

@Test func transientFailureRecordsUsageAndUsesDurableBackoffOnly() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "retry-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let failure = try PlanningAttemptFailure(
        code: "planning_transport_error",
        safeMessage: "规划网络暂时不可用。",
        disposition: .transient,
        usage: Usage(inputTokens: 7, outputTokens: 11)
    )
    guard case let .retryScheduled(work, notBefore) =
        try fixture.database.recordPlanningAttemptFailure(
            claim: claim,
            failure: failure,
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected retry")
        return
    }
    #expect(
        notBefore == Date(timeIntervalSinceReferenceDate: 1_006)
    )
    #expect(work.state == .retryScheduled)
    #expect(try fixture.database.mission(id: ids.missionId)?.spentTokens == 18)
    #expect(try fixture.database.mission(id: ids.missionId)?.status == .planning)
}

@Test func planningIdentityAndTokenEventsPreserveIntegersAboveTwoTo53()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "wide-integer-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let exact = 9_007_199_254_740_993
    _ = try fixture.database.commitPlanningSuccess(
        claim: claim,
        result: r01PlanResult(
            usage: Usage(
                inputTokens: exact,
                outputTokens: 0,
                cacheReadTokens: exact
            )
        ),
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let tokenEvent = try #require(
        try fixture.database.events(missionId: ids.missionId)
            .first { $0.kind == EventKind.planningTokens }
    )
    #expect(tokenEvent.payloadJson.contains(String(exact)))
    #expect(try fixture.database.mission(id: ids.missionId)?.spentTokens == exact)
}

@Test func existingSpentUsageOverflowTerminalizesWithExactEvidence() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:spent-overflow:v1"
    )
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE mission SET spentTokens = ? WHERE id = ?",
            arguments: [Int64.max, ids.missionId]
        )
    }
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "spent-overflow-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))

    guard case let .usageOverflow(work) =
        try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(
                usage: Usage(
                    inputTokens: 1,
                    outputTokens: 0,
                    cacheReadTokens: 7
                )
            ),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected spent projection overflow")
        return
    }

    let events = try fixture.database.events(missionId: ids.missionId)
    let overflowEvent = try #require(
        events.first { $0.kind == EventKind.planningUsageOverflow }
    )
    let evidence = try JSONDecoder().decode(
        PlanningUsageOverflowEvidenceV1.self,
        from: Data(overflowEvent.payloadJson.utf8)
    )
    #expect(work.state == .failed)
    #expect(
        try fixture.database.mission(id: ids.missionId)?.spentTokens
            == Int.max
    )
    #expect(events.allSatisfy { $0.kind != EventKind.planningTokens })
    #expect(
        evidence == .missionProjection(
            existingSpentTokens: Int64.max,
            attemptUsage: try PlanningUsageCountersV1(
                cacheReadTokens: 7,
                inputTokens: 1,
                outputTokens: 0
            ),
            overflowFields: [.spentTokens]
        )
    )
}

@Test func turnAggregateUsageOverflowTerminalizesWithExactEvidence() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "turn-overflow-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let prior = try PlanningUsageCountersV1(
        cacheReadTokens: 1,
        inputTokens: 2,
        outputTokens: 3
    )
    let incoming = try PlanningUsageCountersV1(
        cacheReadTokens: 4,
        inputTokens: 5,
        outputTokens: 6
    )
    let evidence = PlanningUsageOverflowEvidenceV1.turnAggregate(
        priorAccumulatedUsage: prior,
        incomingUsage: incoming,
        overflowFields: [.outputTokens]
    )
    let work = try fixture.database.recordPlanningUsageOverflow(
        claim: claim,
        evidence: evidence,
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let events = try fixture.database.events(missionId: ids.missionId)

    #expect(work.state == .failed)
    #expect(work.errorCode == "usage_overflow")
    #expect(
        events.filter { $0.kind == EventKind.planningUsageOverflow }.count
            == 1
    )
    #expect(events.filter { $0.kind == EventKind.planningTokens }.isEmpty)
}

@Test func planningUsageOverflowMutationRollbackIsTotal() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:overflow-rollback:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "overflow-rollback-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    try fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_planning_overflow_terminal_event
            BEFORE INSERT ON event
            WHEN NEW.kind = 'mission_failed'
            BEGIN
              SELECT RAISE(ABORT, 'injected overflow terminal failure');
            END
            """)
    }
    let evidence = PlanningUsageOverflowEvidenceV1.turnAggregate(
        priorAccumulatedUsage: try PlanningUsageCountersV1(
            cacheReadTokens: 1,
            inputTokens: 2,
            outputTokens: 3
        ),
        incomingUsage: try PlanningUsageCountersV1(
            cacheReadTokens: 4,
            inputTokens: 5,
            outputTokens: 6
        ),
        overflowFields: [.outputTokens]
    )

    #expect(throws: DatabaseError.self) {
        _ = try fixture.database.recordPlanningUsageOverflow(
            claim: claim,
            evidence: evidence,
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    }

    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    let attempt = try fixture.database.pool.read { database in
        try DurableWorkAttemptRecord.fetchOne(
            database,
            key: ["workId": ids.workId, "attempt": claim.attempt]
        )
    }
    let events = try fixture.database.events(missionId: ids.missionId)
    #expect(work.state == .running)
    #expect(work.version == claim.version)
    #expect(attempt?.endedAt == nil)
    #expect(try fixture.database.mission(id: ids.missionId)?.status == .planning)
    #expect(
        events.allSatisfy {
            $0.kind != EventKind.planningUsageOverflow
                && $0.kind != EventKind.missionFailed
        }
    )
}

@Test func planningTerminalMutationRollbackIsTotal() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "rollback-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    try fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_planning_card_insert
            BEFORE INSERT ON card
            BEGIN
              SELECT RAISE(ABORT, 'injected planning card failure');
            END
            """)
    }
    #expect(throws: DatabaseError.self) {
        _ = try fixture.database.commitPlanningSuccess(
            claim: claim,
            result: r01PlanResult(),
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    }
    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    #expect(work.state == .running)
    #expect(try fixture.database.mission(id: ids.missionId)?.status == .planning)
    #expect(try fixture.database.mission(id: ids.missionId)?.spentTokens == 0)
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
    #expect(
        try fixture.database.events(missionId: ids.missionId)
            .filter { $0.kind == EventKind.planningTokens }
            .isEmpty
    )
}

@Test func planningCancelIsProjectionAtomicAndIdempotent() throws {
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    let before = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    try fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_planning_cancel_projection
            BEFORE INSERT ON event
            WHEN NEW.kind = 'mission_failed'
            BEGIN
              SELECT RAISE(ABORT, 'injected cancel projection failure');
            END
            """)
    }
    #expect(throws: DatabaseError.self) {
        _ = try fixture.database.cancelPlanning(
            workId: ids.workId,
            expectedVersion: before.version,
            reason: "User canceled planning",
            now: Date(timeIntervalSinceReferenceDate: 999)
        )
    }
    #expect(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
            == before
    )
    #expect(try fixture.database.mission(id: ids.missionId)?.status == .planning)
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "DROP TRIGGER fail_planning_cancel_projection"
        )
    }

    guard case let .canceled(canceled) = try fixture.database.cancelPlanning(
        workId: ids.workId,
        expectedVersion: before.version,
        reason: "User canceled planning",
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    ) else {
        Issue.record("Expected cancel")
        return
    }
    guard case let .alreadyCanceled(replayed) =
        try fixture.database.cancelPlanning(
            workId: ids.workId,
            expectedVersion: before.version,
            reason: "User canceled planning",
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("Expected cancel replay")
        return
    }
    #expect(canceled.id == replayed.id)
    #expect(try fixture.database.mission(id: ids.missionId)?.status == .failed)
    #expect(
        try fixture.database.events(missionId: ids.missionId)
            .filter { $0.kind == EventKind.missionFailed }
            .count == 1
    )
}

@Test func haltBulkPlanningCancelIsAllOrNothing() throws {
    let fixture = try makeR01FailureFirstFixture()
    let first = try r01EnqueuePlanning(
        fixture,
        goal: "first",
        idempotencyKey: "mission-start:halt:first:v1"
    )
    let second = try r01EnqueuePlanning(
        fixture,
        goal: "second",
        idempotencyKey: "mission-start:halt:second:v1"
    )
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    try fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_second_halt_projection
            BEFORE INSERT ON event
            WHEN NEW.kind = 'mission_failed'
              AND NEW.missionId = '\(second.missionId)'
            BEGIN
              SELECT RAISE(ABORT, 'injected halt failure');
            END
            """)
    }
    #expect(throws: DatabaseError.self) {
        _ = try fixture.database.cancelAllPlanningForEmergencyHalt(
            reason: "emergency_halt_during_planning",
            now: Date(timeIntervalSinceReferenceDate: 1_000)
        )
    }
    let store = DurableWorkStore(database: fixture.database)
    #expect(try store.work(id: first.workId)?.state == .queued)
    #expect(try store.work(id: second.workId)?.state == .queued)
    #expect(try fixture.database.mission(id: first.missionId)?.status == .planning)
    #expect(try fixture.database.mission(id: second.missionId)?.status == .planning)
}

@Test func planningSpecificSingleAndBulkCancelRemainAvailableWhileHalted()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(fixture)
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    _ = try fixture.database.cancelPlanning(
        workId: work.id,
        expectedVersion: work.version,
        reason: "emergency_halt_during_planning",
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    #expect(
        try fixture.database.cancelAllPlanningForEmergencyHalt(
            reason: "emergency_halt_during_planning",
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        ).isEmpty
    )
}

@Test func legacyPlanningRepairCreatesOneReplayableWork() throws {
    let fixture = try makeR01FailureFirstFixture()
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [fixture.profile.id: "planner-model"],
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [fixture.profile.id: "planner-model"],
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let works = try fixture.database.pool.read { database in
        try DurableWorkRecord
            .filter(
                Column("kind") == "planning"
                    && Column("aggregateId") == missionId
            )
            .fetchAll(database)
    }
    #expect(works.count == 1)
    #expect(works[0].state == .queued)
    #expect(works[0].attempt == 0)
}

@Test func legacyPlanningRepairUsesUniformMemberProfile() throws {
    let fixture = try makeR01FailureFirstFixture()
    let uniformProfile = try r01SaveRuntimeProfile(
        fixture,
        id: "legacy-uniform-profile",
        kind: .openAIAPI
    )
    let first = try r01SaveCompanion(
        fixture,
        id: "legacy-uniform-first",
        profileId: uniformProfile.id
    )
    let second = try r01SaveCompanion(
        fixture,
        id: "legacy-uniform-second",
        profileId: uniformProfile.id
    )
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy uniform profile",
        companionIds: [first.id, second.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )

    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [
            fixture.profile.id: "wrong-default-model",
            uniformProfile.id: "uniform-planner-model",
        ],
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        )
    )
    let input = try JSONDecoder().decode(
        PlanningWorkInput.self,
        from: Data(work.inputJson.utf8)
    )

    #expect(work.state == .queued)
    #expect(input.runtimeProfileId == uniformProfile.id)
    #expect(input.plannerModel == "uniform-planner-model")
}

@Test func legacyPlanningRepairUsesExactlyOneDefaultOnly() throws {
    let fixture = try makeR01FailureFirstFixture()
    let alternateProfile = try r01SaveRuntimeProfile(
        fixture,
        id: "legacy-default-alternate",
        kind: .openAIAPI
    )
    let alternate = try r01SaveCompanion(
        fixture,
        id: "legacy-default-member",
        profileId: alternateProfile.id
    )
    let resolvedMissionId = try fixture.database.createMissionShell(
        goal: "legacy unique default",
        companionIds: [fixture.companion.id, alternate.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )

    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [
            fixture.profile.id: "only-default-model",
            alternateProfile.id: "alternate-model",
        ],
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    let resolvedWork = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey:
                "legacy-planning:\(resolvedMissionId):v1"
        )
    )
    let resolvedInput = try JSONDecoder().decode(
        PlanningWorkInput.self,
        from: Data(resolvedWork.inputJson.utf8)
    )
    #expect(resolvedInput.runtimeProfileId == fixture.profile.id)
    #expect(resolvedInput.plannerModel == "only-default-model")

    try r01DisableDefaultProfiles(fixture)
    let unresolvedMissionId = try fixture.database.createMissionShell(
        goal: "legacy no default",
        companionIds: [fixture.companion.id, alternate.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [
            fixture.profile.id: "former-default-model",
            alternateProfile.id: "alternate-model",
        ],
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let unresolvedWork = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey:
                "legacy-planning:\(unresolvedMissionId):v1"
        )
    )
    #expect(unresolvedWork.state == .failed)
    #expect(
        unresolvedWork.errorCode
            == "legacy_planning_profile_unresolved"
    )
}

@Test func legacyPlanningRepairConflictOrCliFailsMissionOnce() throws {
    let fixture = try makeR01FailureFirstFixture()
    let alternateProfile = try r01SaveRuntimeProfile(
        fixture,
        id: "legacy-conflict-profile",
        kind: .openAIAPI
    )
    let cliProfile = try r01SaveRuntimeProfile(
        fixture,
        id: "legacy-cli-profile",
        kind: .cliCodex
    )
    let alternate = try r01SaveCompanion(
        fixture,
        id: "legacy-conflict-member",
        profileId: alternateProfile.id
    )
    let cli = try r01SaveCompanion(
        fixture,
        id: "legacy-cli-member",
        profileId: cliProfile.id
    )
    try r01DisableDefaultProfiles(fixture)
    let conflictMissionId = try fixture.database.createMissionShell(
        goal: "legacy profile conflict",
        companionIds: [fixture.companion.id, alternate.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    let cliMissionId = try fixture.database.createMissionShell(
        goal: "legacy cli profile",
        companionIds: [cli.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )

    for repairDate in [
        Date(timeIntervalSinceReferenceDate: 1_000),
        Date(timeIntervalSinceReferenceDate: 1_001),
    ] {
        try fixture.database.repairLegacyPlanningMissions(
            profileModels: [
                fixture.profile.id: "first-model",
                alternateProfile.id: "second-model",
                cliProfile.id: "cli-model",
            ],
            now: repairDate
        )
    }

    let conflictWork = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey:
                "legacy-planning:\(conflictMissionId):v1"
        )
    )
    let cliWork = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(cliMissionId):v1"
        )
    )
    #expect(
        conflictWork.errorCode
            == "legacy_planning_profile_unresolved"
    )
    #expect(
        cliWork.errorCode
            == "legacy_planning_profile_cli_unsupported"
    )
    for missionId in [conflictMissionId, cliMissionId] {
        #expect(try fixture.database.mission(id: missionId)?.status == .failed)
        #expect(
            try fixture.database.events(missionId: missionId)
                .filter { $0.kind == EventKind.missionFailed }
                .count == 1
        )
    }
}

@Test func legacyPlanningFailureCreatesAttemptZeroWithoutAttemptRows() throws {
    let fixture = try makeR01FailureFirstFixture()
    try r01DisableDefaultProfiles(fixture)
    let unresolved = try r01SaveCompanion(
        fixture,
        id: "legacy-attempt-zero-member",
        profileId: nil
    )
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy attempt zero",
        companionIds: [unresolved.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )

    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [:],
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        )
    )
    let rowCounts = try fixture.database.pool.read { database in
        (
            try DurableWorkAttemptRecord
                .filter(Column("workId") == work.id)
                .fetchCount(database),
            try DurableWorkAttemptEventRecord
                .filter(Column("workId") == work.id)
                .fetchCount(database)
        )
    }

    #expect(work.state == .failed)
    #expect(work.attempt == 0)
    #expect(rowCounts.0 == 0)
    #expect(rowCounts.1 == 0)
    #expect(
        try fixture.database.events(missionId: missionId)
            .filter { $0.kind == EventKind.planningTokens }
            .isEmpty
    )
}

@Test func runningUnresolvedLegacyMissionKeepsExactLegacyTerminalCode()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    try r01DisableDefaultProfiles(fixture)
    let unresolved = try r01SaveCompanion(
        fixture,
        id: "legacy-terminal-member",
        profileId: nil
    )
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy terminal evidence",
        companionIds: [unresolved.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )

    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [:],
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        )
    )
    let input = try JSONDecoder().decode(
        LegacyPlanningTerminalInputV1.self,
        from: Data(work.inputJson.utf8)
    )
    let failedEvents = try fixture.database.events(missionId: missionId)
        .filter { $0.kind == EventKind.missionFailed }

    #expect(input.contractVersion == 1)
    #expect(
        input.terminalCode == "legacy_planning_profile_unresolved"
    )
    #expect(work.errorCode == input.terminalCode)
    #expect(work.errorMessage == nil)
    #expect(
        failedEvents.map(\.payloadJson)
            == [
                #"{"reason":"legacy_planning_profile_unresolved"}"#,
            ]
    )
}

@Test func legacyRepairRunningModeLinearizesBeforeConcurrentHalt()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    try r01DisableDefaultProfiles(fixture)
    let unresolved = try r01SaveCompanion(
        fixture,
        id: "legacy-linearized-member",
        profileId: nil
    )
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy running linearization",
        companionIds: [unresolved.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    let gate = R01SQLGate()
    try r01InstallLegacyRepairGate(
        fixture,
        missionId: missionId,
        gate: gate
    )

    let repair = Task.detached {
        try fixture.database.repairLegacyPlanningMissions(
            profileModels: [:],
            now: Date(timeIntervalSinceReferenceDate: 1_000)
        )
    }
    await gate.waitUntilEntered()
    let halt = Task.detached {
        try fixture.database.transitionDispatchMode(
            from: .running,
            to: .halted
        )
    }
    await Task.yield()
    gate.release()
    try await repair.value
    _ = try await halt.value
    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [:],
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )

    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        )
    )
    #expect(work.state == .failed)
    #expect(
        work.errorCode == "legacy_planning_profile_unresolved"
    )
    #expect(
        try fixture.database.events(missionId: missionId)
            .filter { $0.kind == EventKind.missionFailed }
            .count == 1
    )
}

@Test func legacyRepairHaltedModeCreatesAndCancelsAttemptZeroAtomically()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy halted atomic",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    try fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_legacy_halted_projection
            BEFORE INSERT ON event
            WHEN NEW.kind = 'mission_failed'
            BEGIN
              SELECT RAISE(ABORT, 'injected legacy halt failure');
            END
            """)
    }

    #expect(throws: DatabaseError.self) {
        try fixture.database.repairLegacyPlanningMissions(
            profileModels: [:],
            now: Date(timeIntervalSinceReferenceDate: 1_000)
        )
    }
    #expect(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        ) == nil
    )
    #expect(try fixture.database.mission(id: missionId)?.status == .planning)

    try fixture.database.pool.write { database in
        try database.execute(
            sql: "DROP TRIGGER fail_legacy_halted_projection"
        )
    }
    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [:],
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        )
    )
    let rowCounts = try fixture.database.pool.read { database in
        (
            try DurableWorkAttemptRecord
                .filter(Column("workId") == work.id)
                .fetchCount(database),
            try DurableWorkAttemptEventRecord
                .filter(Column("workId") == work.id)
                .fetchCount(database)
        )
    }

    #expect(work.state == .canceled)
    #expect(work.attempt == 0)
    #expect(work.errorCode == "work_canceled")
    #expect(
        work.errorMessage == "emergency_halt_during_planning"
    )
    #expect(rowCounts.0 == 0)
    #expect(rowCounts.1 == 0)
    #expect(
        try fixture.database.events(missionId: missionId)
            .filter { $0.kind == EventKind.missionFailed }
            .count == 1
    )
}

@MainActor
@Test func engineFirstStartupAdoptsLegacyCardBeforePlanningRepair() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy card blocks repair",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    let cardId = "legacy-running-card"
    let runId = "legacy-open-run"
    try await fixture.database.pool.write { database in
        try CardRecord(
            id: cardId,
            missionId: missionId,
            idemKey: "legacy-card-idem",
            title: "legacy card",
            descriptionText: "must not be adopted before repair",
            expectedOutput: "none",
            assigneeId: fixture.companion.id,
            status: .running,
            blockedReasonJson: nil,
            dependsOnJson: "[]",
            handoffJson: nil,
            stage: 1,
            maxTurns: 1,
            tokenBudget: 1,
            createdAt: Date(timeIntervalSinceReferenceDate: 900)
        ).insert(database)
        try RunRecord(
            id: runId,
            cardId: cardId,
            attempt: 1,
            outcome: nil,
            turns: 0,
            tokensIn: 0,
            tokensOut: 0,
            startedAt: Date(timeIntervalSinceReferenceDate: 901),
            endedAt: nil
        ).insert(database)
    }
    let resolver = R01PlanningResolver()
    let orchestrator = Orchestrator(
        db: fixture.database,
        planningProviderResolver: resolver,
        makeProvider: { _, _ in nil },
        artifactStoreRoot: fixture.root.appendingPathComponent(
            "legacy-order-artifacts"
        ),
        tickInterval: nil
    )

    await orchestrator.recoverAndReconcile()

    #expect(try fixture.database.card(id: cardId)?.status == .ready)
    let legacyRun = try #require(
        try fixture.database.runs(cardId: cardId)
            .first { $0.id == runId }
    )
    #expect(legacyRun.outcome == "interrupted")
    #expect(legacyRun.endedAt != nil)
    #expect(try fixture.database.mission(id: missionId)?.status == .executing)
    #expect(
        try fixture.database.events(missionId: missionId)
            .filter { $0.cardId == cardId }
            .map(\.kind) == [EventKind.cardInterrupted, EventKind.cardReady]
    )
    #expect(
        try DurableWorkStore(database: fixture.database).latestWork(
            kind: .planning,
            aggregateType: "mission",
            aggregateId: missionId
        ) == nil
    )
    #expect(resolver.resolveCount == 0)
    _ = await orchestrator.shutdown()
}

@Test func haltedWorklessUnresolvedLegacyMissionUsesEmergencyHaltAttemptZero()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy halted",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    try fixture.database.repairLegacyPlanningMissions(
        profileModels: [:],
        now: Date(timeIntervalSinceReferenceDate: 1_000)
    )
    let work = try #require(
        try DurableWorkStore(database: fixture.database).latestWork(
            kind: .planning,
            aggregateType: "mission",
            aggregateId: missionId
        )
    )
    #expect(work.state == .canceled)
    #expect(work.attempt == 0)
    #expect(work.errorCode == "work_canceled")
    #expect(
        work.errorMessage == "emergency_halt_during_planning"
    )
    #expect(try fixture.database.mission(id: missionId)?.status == .failed)
}

private actor R09ShutdownDeadlineProbe {
    private var requestedDuration: Duration?
    private var requestWaiters:
        [CheckedContinuation<Duration, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    private var released = false

    func sleep(for duration: Duration) async throws {
        guard duration == .milliseconds(25) else {
            try await Task<Never, Never>.sleep(for: duration)
            return
        }
        precondition(requestedDuration == nil)
        requestedDuration = duration
        let waiters = requestWaiters
        requestWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: duration)
        }
        if released { return }
        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
        }
    }

    func waitUntilRequested() async -> Duration {
        if let requestedDuration {
            return requestedDuration
        }
        return await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func release() {
        guard !released else { return }
        released = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor R09ShutdownCompletionProbe {
    private var completed = false

    func markCompleted() {
        completed = true
    }

    func isCompleted() -> Bool {
        completed
    }
}

@Test func shutdownWithCancellationIgnoringProviderReturnsBoundedly() async throws {
    let fixture = try makeR01FailureFirstFixture()
    let provider = R01CancellationIgnoringProvider()
    let resolver = R01PlanningResolver(provider: provider)
    let deadline = R09ShutdownDeadlineProbe()
    let completion = R09ShutdownCompletionProbe()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:uncooperative:v1",
        resolver: resolver
    )
    let supervisor = DurableWorkSupervisor(
        database: fixture.database,
        planningProviderResolver: resolver,
        workerId: "shutdown-worker",
        now: { Date(timeIntervalSinceReferenceDate: 1_000) },
        sleep: { duration in
            try await deadline.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )

    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: "planner-model"]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    await provider.waitUntilStarted()

    let shutdownTask = Task {
        let report = await supervisor.shutdown(
            gracePeriod: .milliseconds(25)
        )
        await completion.markCompleted()
        return report
    }
    let requestedDuration = await deadline.waitUntilRequested()

    #expect(requestedDuration == .milliseconds(25))
    #expect(await completion.isCompleted() == false)
    await deadline.release()
    let report = await shutdownTask.value
    #expect(report.uncooperativeWorkIds == [ids.workId])
    provider.release()
}

private struct R11LegacyPlanningWriteSnapshot: Equatable {
    let mission: Data
    let cards: Data
    let planningWork: Data
    let events: Data
}

private func r11LegacyPlanningWriteSnapshot(
    _ fixture: R01FailureFirstFixture,
    missionId: String
) throws -> R11LegacyPlanningWriteSnapshot {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try fixture.database.pool.read { database in
        let mission = try #require(
            try MissionRecord.fetchOne(database, key: missionId)
        )
        let cards = try CardRecord
            .filter(Column("missionId") == missionId)
            .order(Column("id"))
            .fetchAll(database)
        let planningWork = try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("aggregateType") == "mission"
                    && Column("aggregateId") == missionId
            )
            .order(Column("id"))
            .fetchAll(database)
        let events = try EventRecord
            .filter(Column("missionId") == missionId)
            .order(Column("id"))
            .fetchAll(database)
        return try R11LegacyPlanningWriteSnapshot(
            mission: encoder.encode(mission),
            cards: encoder.encode(cards),
            planningWork: encoder.encode(planningWork),
            events: encoder.encode(events)
        )
    }
}

@Test func legacyPlanningWithCardsFailsClosedWithExactTypedErrorAndZeroWrites()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    #expect(try fixture.database.dispatchMode() == .running)
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy planning with an existing card",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    try fixture.database.pool.write { database in
        try CardRecord(
            id: "r11-legacy-existing-card",
            missionId: missionId,
            idemKey: "r11-legacy-existing-card-idem",
            title: "existing legacy card",
            descriptionText: "must remain byte-for-byte unchanged",
            expectedOutput: "no writes",
            assigneeId: fixture.companion.id,
            status: .ready,
            blockedReasonJson: nil,
            dependsOnJson: "[]",
            handoffJson: nil,
            stage: 0,
            maxTurns: 1,
            tokenBudget: 100,
            createdAt: Date(timeIntervalSinceReferenceDate: 900)
        ).insert(database)
    }
    let before = try r11LegacyPlanningWriteSnapshot(
        fixture,
        missionId: missionId
    )

    let capturedError: any Error
    do {
        try fixture.database.repairLegacyPlanningMissions(
            profileModels: [fixture.profile.id: "planner-model"],
            now: Date(timeIntervalSinceReferenceDate: 1_000)
        )
        Issue.record(
            "running legacy planning with Cards must fail closed"
        )
        return
    } catch {
        capturedError = error
    }

    let reflectedType = String(reflecting: type(of: capturedError))
    let reflectedCode = Mirror(reflecting: capturedError).children
        .first { $0.label == "code" }?.value as? String
    #expect(
        reflectedType == "AgentLoopCore.LegacyPlanningHasCardsError",
        "expected exact LegacyPlanningHasCardsError, got \(reflectedType)"
    )
    #expect(
        reflectedCode == "legacy_planning_has_cards",
        "expected exact legacy_planning_has_cards code"
    )
    #expect(
        try r11LegacyPlanningWriteSnapshot(
            fixture,
            missionId: missionId
        ) == before,
        "Mission/Card/planning-work/event snapshot must remain unchanged"
    )
}

#if DEBUG
@Test func unexpectedPlanningFallbackTerminalizesThroughFailureOwner()
    async throws
{
    let fixture = try makeR01FailureFirstFixture()
    let provider = R01GateProvider()
    let resolver = R01PlanningResolver(provider: provider)
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:unexpected-fallback-owner:v1",
        resolver: resolver
    )
    let supervisor = DurableWorkSupervisor(
        database: fixture.database,
        planningProviderResolver: resolver,
        workerId: "unexpected-fallback-worker",
        now: { Date(timeIntervalSinceReferenceDate: 1_000) },
        sleep: { duration in
            try await Task<Never, Never>.sleep(for: duration)
        },
        onMissionChanged: { _ in }
    )

    try await supervisor.recoverOnStartup(
        profileModels: [fixture.profile.id: "planner-model"]
    )
    try await supervisor.activateAfterOrchestratorRecovery()
    await provider.gate.waitUntilEntered()

    let ownedWork = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    #expect(ownedWork.state == .running)
    #expect(ownedWork.leaseOwner == "unexpected-fallback-worker")
    let resolveCountBeforeInjection = resolver.resolveCount
    let providerCallCountBeforeInjection = provider.callCount
    #expect(providerCallCountBeforeInjection == 1)

    do {
        try await supervisor.injectOwnedSuccessProposalForTesting(
            workId: "unknown-owned-work",
            result: r01PlanResult(fallbackReason: "must fail closed")
        )
        Issue.record("unknown work must not enter the terminal owner")
    } catch let error as SupervisorGenerationExpiredError {
        #expect(error.workId == "unknown-owned-work")
    } catch {
        Issue.record("unexpected unknown-work error: \(error)")
    }

    let injectedUsage = Usage(
        inputTokens: 11,
        outputTokens: 13,
        cacheReadTokens: 7
    )
    try await supervisor.injectOwnedSuccessProposalForTesting(
        workId: ids.workId,
        result: r01PlanResult(
            usage: injectedUsage,
            fallbackReason: "unexpected injected fallback"
        )
    )

    #expect(resolver.resolveCount == resolveCountBeforeInjection)
    #expect(provider.callCount == providerCallCountBeforeInjection)
    await provider.gate.release()
    try await supervisor.waitUntilTerminal(workId: ids.workId)

    let work = try #require(
        try DurableWorkStore(database: fixture.database).work(id: ids.workId)
    )
    let mission = try #require(
        try fixture.database.mission(id: ids.missionId)
    )
    let events = try fixture.database.events(missionId: ids.missionId)
    let tokenEvents = events.filter {
        $0.kind == EventKind.planningTokens
    }
    let failedEvents = events.filter {
        $0.kind == EventKind.missionFailed
    }

    #expect(work.state == .failed)
    #expect(work.errorCode == "unexpected_planning_fallback")
    #expect(mission.status == .failed)
    #expect(mission.spentTokens == 24)
    #expect(tokenEvents.count == 1)
    #expect(
        tokenEvents.first?.payloadJson
            == #"{"cacheReadTokens":7,"inputTokens":11,"outputTokens":13}"#
    )
    #expect(failedEvents.count == 1)
    #expect(
        failedEvents.first?.payloadJson
            == #"{"reason":"unexpected_planning_fallback"}"#
    )
    #expect(events.allSatisfy { $0.kind != EventKind.planFallback })
    #expect(events.allSatisfy { $0.kind != EventKind.planCompleted })
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
    #expect(resolver.resolveCount == resolveCountBeforeInjection)
    #expect(provider.callCount == providerCallCountBeforeInjection)

    do {
        try await supervisor.injectOwnedSuccessProposalForTesting(
            workId: ids.workId,
            result: r01PlanResult(fallbackReason: "late fallback")
        )
        Issue.record("terminal work must no longer be owned")
    } catch let error as SupervisorGenerationExpiredError {
        #expect(error.workId == ids.workId)
    } catch {
        Issue.record("unexpected terminal-work error: \(error)")
    }

    let report = await supervisor.shutdown(
        gracePeriod: .milliseconds(50)
    )
    #expect(report.uncooperativeWorkIds.isEmpty)
}
#endif

@Test func claimRevalidatesExactCapturedProfileModelAndCredentials()
    async throws
{
    do {
        let fixture = try makeR01FailureFirstFixture()
        let provider = MockProvider(script: [r01ValidPlanTurn()])
        let strict = r11StrictResolverFixture(
            profile: fixture.profile,
            provider: provider
        )
        let ids = try r01EnqueuePlanning(
            fixture,
            idempotencyKey: "mission-start:claim-rotated-credential:v1",
            resolver: strict.resolver
        )
        strict.credentials.set(
            "rotated-secret",
            account: "planning-credential"
        )

        try await r11RunSupervisorToTerminal(
            fixture: fixture,
            resolver: strict.resolver,
            workId: ids.workId,
            workerId: "claim-rotated-credential-worker"
        )

        let work = try #require(
            try DurableWorkStore(database: fixture.database)
                .work(id: ids.workId)
        )
        #expect(work.state == .succeeded)
        #expect(await provider.callCount == 1)
        #expect(
            strict.profiles.requestedIds
                == [fixture.profile.id, fixture.profile.id]
        )
        #expect(
            strict.credentials.requestedAccounts
                == ["planning-credential", "planning-credential"]
        )
        #expect(strict.factory.apiCalls.count == 2)
        #expect(strict.factory.apiCalls[0].credential == "initial-secret")
        #expect(strict.factory.apiCalls[1].credential == "rotated-secret")
        #expect(
            strict.factory.apiCalls.allSatisfy {
                $0.model == "planner-model"
                    && $0.baseURL
                        == URL(string: "https://api.anthropic.com")!
            }
        )
    }

    try await r11AssertClaimResolutionFailure(
        expectedCode: "model_catalog_unavailable",
        command: "claim-catalog-removed"
    ) { strict, fixture in
        strict.catalogs.setCached(nil, profileId: fixture.profile.id)
        strict.catalogs.setManual([], profileId: fixture.profile.id)
    }
    try await r11AssertClaimResolutionFailure(
        expectedCode: "planning_model_unsupported",
        command: "claim-model-changed"
    ) { strict, fixture in
        strict.catalogs.setCached(
            ["different-model"],
            profileId: fixture.profile.id
        )
    }
    try await r11AssertClaimResolutionFailure(
        expectedCode: "credential_not_found",
        command: "claim-credential-deleted"
    ) { strict, _ in
        strict.credentials.set(nil, account: "planning-credential")
    }
    try await r11AssertClaimResolutionFailure(
        expectedCode: "endpoint_invalid",
        command: "claim-endpoint-invalid"
    ) { strict, fixture in
        strict.profiles.replace(
            RuntimeProfileRecord(
                id: fixture.profile.id,
                kind: fixture.profile.kind,
                name: fixture.profile.name,
                baseURL: "file:///tmp/not-a-planning-api",
                credentialAccount: fixture.profile.credentialAccount,
                isDefault: fixture.profile.isDefault,
                createdAt: fixture.profile.createdAt
            )
        )
        strict.catalogs.setChoices(
            ["planner-model"],
            profileId: fixture.profile.id
        )
    }
}

@Test func deletedOrUnsupportedCapturedProfileTerminalizesExistingWork()
    async throws
{
    try await r11AssertClaimResolutionFailure(
        expectedCode: "runtime_profile_not_found",
        command: "claim-profile-deleted"
    ) { strict, fixture in
        strict.profiles.remove(id: fixture.profile.id)
    }
    try await r11AssertClaimResolutionFailure(
        expectedCode: "planning_profile_cli_unsupported",
        command: "claim-profile-became-cli"
    ) { strict, fixture in
        strict.profiles.replace(
            RuntimeProfileRecord(
                id: fixture.profile.id,
                kind: .cliCodex,
                name: fixture.profile.name,
                baseURL: nil,
                credentialAccount: nil,
                isDefault: fixture.profile.isDefault,
                createdAt: fixture.profile.createdAt
            )
        )
    }
}

@Test func negativeFirstTurnPlanningUsageTerminalizesWithoutTokenEvent()
    async throws
{
    let provider = R11DurablePlannerProvider(
        turns: [
            r11PlanTurn(
                usage: Usage(
                    inputTokens: -1,
                    outputTokens: 5,
                    cacheReadTokens: 7
                )
            ),
        ]
    )
    let failure = try #require(
        await r11CapturedPlanningFailure {
            _ = try await Planner(provider: provider).proposeDurable(
                goal: "negative first usage",
                roster: [
                    CompanionRecord.new(
                        name: "R11 planner",
                        color: "blue",
                        rolePrompt: "plan",
                        model: "planner-model"
                    ),
                ],
                workspacePath: nil
            )
        }
    )
    #expect(failure.failure.code == "planning_usage_invalid")
    #expect(failure.failure.disposition == .deterministic)
    #expect(failure.usage == nil)
    #expect(await provider.callCount == 1)

    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:negative-first-usage:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "negative-first-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    guard case let .failed(work) =
        try fixture.database.recordPlanningAttemptFailure(
            claim: claim,
            failure: failure,
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("negative first usage must deterministically fail")
        return
    }
    let mission = try #require(
        try fixture.database.mission(id: ids.missionId)
    )
    let events = try fixture.database.events(missionId: ids.missionId)
    #expect(work.errorCode == "planning_usage_invalid")
    #expect(mission.status == .failed)
    #expect(mission.spentTokens == 0)
    #expect(events.allSatisfy { $0.kind != EventKind.planningTokens })
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
}

@Test func negativeCorrectionUsagePreservesPriorValidUsage() async throws {
    let priorUsage = Usage(
        inputTokens: 17,
        outputTokens: 19,
        cacheReadTokens: 23
    )
    let provider = R11DurablePlannerProvider(
        turns: [
            r11PlanTurn(
                usage: priorUsage,
                invalidDependency: true
            ),
            r11PlanTurn(
                usage: Usage(
                    inputTokens: 7,
                    outputTokens: -11,
                    cacheReadTokens: 13
                )
            ),
        ]
    )
    let failure = try #require(
        await r11CapturedPlanningFailure {
            _ = try await Planner(provider: provider).proposeDurable(
                goal: "negative correction usage",
                roster: [
                    CompanionRecord.new(
                        name: "R11 planner",
                        color: "blue",
                        rolePrompt: "plan",
                        model: "planner-model"
                    ),
                ],
                workspacePath: nil
            )
        }
    )
    #expect(failure.failure.code == "planning_usage_invalid")
    #expect(failure.failure.disposition == .deterministic)
    #expect(failure.usage == priorUsage)
    #expect(await provider.callCount == 2)

    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:negative-correction-usage:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "negative-correction-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    guard case let .failed(work) =
        try fixture.database.recordPlanningAttemptFailure(
            claim: claim,
            failure: failure,
            now: Date(timeIntervalSinceReferenceDate: 1_001)
        )
    else {
        Issue.record("negative correction must deterministically fail")
        return
    }
    let mission = try #require(
        try fixture.database.mission(id: ids.missionId)
    )
    let tokenEvents = try fixture.database.events(missionId: ids.missionId)
        .filter { $0.kind == EventKind.planningTokens }
    #expect(work.errorCode == "planning_usage_invalid")
    #expect(mission.status == .failed)
    #expect(mission.spentTokens == 36)
    #expect(tokenEvents.count == 1)
    #expect(
        tokenEvents.first?.payloadJson
            == #"{"cacheReadTokens":23,"inputTokens":17,"outputTokens":19}"#
    )
    #expect(try fixture.database.cards(missionId: ids.missionId).isEmpty)
}

@Test func planningUsageOverflowEvidencePreservesIntegersAboveTwoTo53()
    throws
{
    let exact = Int64(9_007_199_254_740_993)
    let evidence = PlanningUsageOverflowEvidenceV1.missionProjection(
        existingSpentTokens: exact,
        attemptUsage: try PlanningUsageCountersV1(
            cacheReadTokens: exact + 1,
            inputTokens: exact + 2,
            outputTokens: exact + 3
        ),
        overflowFields: [.spentTokens, .attemptBillableTokens]
    )
    let encoded = try CanonicalJSONV1.encode(evidence)
    let canonical = String(decoding: encoded, as: UTF8.self)
    #expect(canonical.contains("9007199254740993"))
    #expect(canonical.contains("9007199254740994"))
    #expect(canonical.contains("9007199254740995"))
    #expect(canonical.contains("9007199254740996"))
    #expect(!canonical.contains("9007199254740992"))
    #expect(
        try JSONDecoder().decode(
            PlanningUsageOverflowEvidenceV1.self,
            from: encoded
        ) == .missionProjection(
            existingSpentTokens: exact,
            attemptUsage: try PlanningUsageCountersV1(
                cacheReadTokens: exact + 1,
                inputTokens: exact + 2,
                outputTokens: exact + 3
            ),
            overflowFields: [
                .attemptBillableTokens,
                .spentTokens,
            ]
        )
    )

    let fixture = try makeR01FailureFirstFixture()
    let ids = try r01EnqueuePlanning(
        fixture,
        idempotencyKey: "mission-start:overflow-exact-integers:v1"
    )
    let claim = try #require(try fixture.database.claimNextPlanning(
        workerId: "overflow-exact-integers-worker",
        now: Date(timeIntervalSinceReferenceDate: 1_000),
        leaseDuration: 60
    ))
    let work = try fixture.database.recordPlanningUsageOverflow(
        claim: claim,
        evidence: evidence,
        now: Date(timeIntervalSinceReferenceDate: 1_001)
    )
    let overflowEvent = try #require(
        try fixture.database.events(missionId: ids.missionId)
            .first { $0.kind == EventKind.planningUsageOverflow }
    )
    #expect(work.state == .failed)
    #expect(overflowEvent.payloadJson == canonical)
}

@Test func planningUsageOverflowEvidenceSortsDeduplicatesAndRejectsInvalidShape()
    throws
{
    let counters = try PlanningUsageCountersV1(
        cacheReadTokens: 1,
        inputTokens: 2,
        outputTokens: 3
    )
    let evidence = PlanningUsageOverflowEvidenceV1.turnAggregate(
        priorAccumulatedUsage: counters,
        incomingUsage: counters,
        overflowFields: [
            .outputTokens,
            .inputTokens,
            .outputTokens,
            .cacheReadTokens,
        ]
    )
    let encoded = try CanonicalJSONV1.encode(evidence)
    let canonical = String(decoding: encoded, as: UTF8.self)
    #expect(
        canonical
            == #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":["cacheReadTokens","inputTokens","outputTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#
    )
    #expect(
        try JSONDecoder().decode(
            PlanningUsageOverflowEvidenceV1.self,
            from: encoded
        ) == .turnAggregate(
            priorAccumulatedUsage: counters,
            incomingUsage: counters,
            overflowFields: [
                .cacheReadTokens,
                .inputTokens,
                .outputTokens,
            ]
        )
    )

    let invalidCases: [(String, InvalidPlanningPayloadError)] = [
        (
            #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":[],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#,
            .invalidOverflowFields
        ),
        (
            #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":["outputTokens","inputTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#,
            .nonCanonicalOverflowFields
        ),
        (
            #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":["outputTokens","outputTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#,
            .nonCanonicalOverflowFields
        ),
        (
            #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":["spentTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#,
            .invalidOverflowFields
        ),
        (
            #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":["outputTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate","unexpected":true}"#,
            .invalidOverflowShape
        ),
        (
            #"{"contractVersion":2,"incomingUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"overflowFields":["outputTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#,
            .invalidContractVersion
        ),
        (
            #"{"contractVersion":1,"incomingUsage":{"cacheReadTokens":1,"inputTokens":-2,"outputTokens":3},"overflowFields":["outputTokens"],"priorAccumulatedUsage":{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3},"reason":"turn_aggregate"}"#,
            .negativeUsage
        ),
    ]
    for (json, expected) in invalidCases {
        do {
            _ = try JSONDecoder().decode(
                PlanningUsageOverflowEvidenceV1.self,
                from: Data(json.utf8)
            )
            Issue.record("invalid overflow evidence unexpectedly decoded")
        } catch let error as InvalidPlanningPayloadError {
            #expect(error == expected)
        } catch {
            Issue.record("unexpected overflow decode error: \(error)")
        }
    }
}

@Test func legacyPlanningModelUnavailableFailsMissionOnceWithExactCode()
    throws
{
    let fixture = try makeR01FailureFirstFixture()
    let missionId = try fixture.database.createMissionShell(
        goal: "legacy missing planner model",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        campId: fixture.camp.id
    )
    for now in [
        Date(timeIntervalSinceReferenceDate: 1_000),
        Date(timeIntervalSinceReferenceDate: 1_001),
    ] {
        try fixture.database.repairLegacyPlanningMissions(
            profileModels: [:],
            now: now
        )
    }

    let work = try #require(
        try r01PlanningWork(
            fixture,
            idempotencyKey: "legacy-planning:\(missionId):v1"
        )
    )
    let input = try JSONDecoder().decode(
        LegacyPlanningTerminalInputV1.self,
        from: Data(work.inputJson.utf8)
    )
    let events = try fixture.database.events(missionId: missionId)
    let rowCounts = try fixture.database.pool.read { database in
        (
            try DurableWorkAttemptRecord
                .filter(Column("workId") == work.id)
                .fetchCount(database),
            try DurableWorkAttemptEventRecord
                .filter(Column("workId") == work.id)
                .fetchCount(database)
        )
    }
    #expect(input.terminalCode == "legacy_planning_model_unavailable")
    #expect(work.state == .failed)
    #expect(work.attempt == 0)
    #expect(work.errorCode == "legacy_planning_model_unavailable")
    #expect(work.errorMessage == nil)
    #expect(
        try fixture.database.mission(id: missionId)?.status == .failed
    )
    #expect(
        events.filter { $0.kind == EventKind.missionFailed }
            .map(\.payloadJson)
            == [
                #"{"reason":"legacy_planning_model_unavailable"}"#,
            ]
    )
    #expect(rowCounts.0 == 0)
    #expect(rowCounts.1 == 0)
}
