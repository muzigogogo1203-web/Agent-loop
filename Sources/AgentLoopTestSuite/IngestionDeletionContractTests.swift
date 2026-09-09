import Foundation
import GRDB
import Testing
@testable import AgentLoopCore
@testable import AgentLoopApplication

private let p1eDeletionEpoch = Date(timeIntervalSince1970: 4_000)

private struct P1EDeletionFixture {
    let database: AppDatabase
    let store: IngestionDeletionStore
    let campID: String
    let ingestionID: String
    let resultID: String?
}

private func p1eDeletionFixture(
    _ label: String,
    status: IngestionStatus = .needsReview,
    withResult: Bool = true,
    resultMaterialized: Bool = false
) throws -> P1EDeletionFixture {
    let database = try p1eE2Database("deletion-\(label)")
    let campID = "camp:deletion:\(label)"
    _ = try p1eE2SeedCamp(campID, database: database)
    let ingestionID = "ingestion:deletion:\(label)"
    let resultID = withResult ? "result:deletion:\(label)" : nil
    try database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO ingestion_item(
                  id,campId,sourceType,title,rawText,sourceURL,author,userIntent,
                  contentHash,status,attempt,errorText,createdAt,updatedAt,
                  version,terminalReason,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,NULL,NULL)
                """,
            arguments: [
                ingestionID, campID, "url", "Private title \(label)",
                "Private raw text \(label)", "https://private.invalid/\(label)",
                "Private author", "Private intent",
                FeedContentHasher.hash("Private raw text \(label)"),
                status.rawValue, 2,
                status == .failed ? "private provider failure" : nil,
                p1eDeletionEpoch, p1eDeletionEpoch,
            ]
        )
        if let resultID {
            try db.execute(
                sql: """
                    INSERT INTO rumination_result(
                      id,ingestionId,pipelineVersion,resultJson,userEditedJson,
                      materializedAt,createdAt,updatedAt,version,redactedAt
                    ) VALUES (?,?,?,?,?,?,?,?,1,NULL)
                    """,
                arguments: [
                    resultID, ingestionID, "p1e-test",
                    "{\"private\":\"model result \(label)\"}",
                    "{\"private\":\"user edit \(label)\"}",
                    resultMaterialized
                        ? p1eDeletionEpoch.addingTimeInterval(1) : nil,
                    p1eDeletionEpoch, p1eDeletionEpoch,
                ]
            )
        }
    }
    return P1EDeletionFixture(
        database: database,
        store: IngestionDeletionStore(
            database: database,
            clock: { p1eDeletionEpoch.addingTimeInterval(10) }
        ),
        campID: campID,
        ingestionID: ingestionID,
        resultID: resultID
    )
}

private func p1eDeletionRequest(
    _ fixture: P1EDeletionFixture,
    scope: ActiveIngestionDeletionScopeV1,
    key: String? = nil
) throws -> ActiveIngestionDeletionPrepareRequestV1 {
    try ActiveIngestionDeletionPrepareRequestV1(
        envelope: p1eE2Envelope(
            key ?? "p1e:deletion:\(fixture.ingestionID):\(scope.rawValue)",
            at: p1eDeletionEpoch
        ),
        campId: fixture.campID,
        ingestionId: fixture.ingestionID,
        scope: scope
    )
}

private func p1ePrepared(
    _ fixture: P1EDeletionFixture,
    scope: ActiveIngestionDeletionScopeV1,
    key: String? = nil
) throws -> PreparedActiveIngestionDeletionV1 {
    try fixture.store.prepareActiveIngestionDeletion(
        request: p1eDeletionRequest(fixture, scope: scope, key: key)
    )
}

private func p1eCommitted(
    _ fixture: P1EDeletionFixture,
    scope: ActiveIngestionDeletionScopeV1,
    key: String? = nil
) throws -> (
    PreparedActiveIngestionDeletionV1,
    ActiveIngestionDeletionResultV1
) {
    let prepared = try p1ePrepared(fixture, scope: scope, key: key)
    let resolution = fixture.store.executeActiveIngestionDeletion(
        preparedCommand: prepared
    )
    guard case .committed(let result) = resolution else {
        throw P1EDeletionTestFailure.unexpectedResolution
    }
    return (prepared, result)
}

private enum P1EDeletionTestFailure: Error {
    case unexpectedResolution
    case forcedRefresh
    case forcedReload
}

private actor P1EDeletionExecutionGate {
    private var didArrive = false
    private var isReleased = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func suspendUntilReleased() async {
        didArrive = true
        let waiters = arrivalWaiters
        arrivalWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
        }
    }

    func waitUntilArrived() async {
        guard !didArrive else { return }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append(continuation)
        }
    }

    func release() {
        isReleased = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private enum P1EDeletionExecutionStep: Sendable {
    case store
    case resolution(ActiveIngestionDeletionExecutionResolutionV1)
    case commitThenResolutionPending(
        ActiveIngestionDeletionResolutionDispositionV1
    )
}

private final class P1EDeletionWorkflowHarness: @unchecked Sendable {
    private let lock = NSLock()
    private let label: String
    private let store: IngestionDeletionStore
    private let executionGate: P1EDeletionExecutionGate?
    private var envelopeOrdinal = 0
    private var prepareCallCount = 0
    private var executeCallCount = 0
    private var resolveCallCount = 0
    private var preparedKeys: [String] = []
    private var executeSteps: [P1EDeletionExecutionStep]
    private var resolveSteps:
        [ActiveIngestionDeletionExecutionResolutionV1]

    init(
        label: String,
        store: IngestionDeletionStore,
        executionGate: P1EDeletionExecutionGate? = nil,
        executeSteps: [P1EDeletionExecutionStep] = [],
        resolveSteps: [ActiveIngestionDeletionExecutionResolutionV1] = []
    ) {
        self.label = label
        self.store = store
        self.executionGate = executionGate
        self.executeSteps = executeSteps
        self.resolveSteps = resolveSteps
    }

    var ports: InputActiveIngestionDeletionPorts {
        InputActiveIngestionDeletionPorts(
            makeEnvelope: { [self] in try makeEnvelope() },
            prepare: { [self] in try prepare($0) },
            execute: { [self] in await execute($0) },
            resolve: { [self] in await resolve($0) }
        )
    }

    var counts: (envelope: Int, prepare: Int, execute: Int, resolve: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (
            envelopeOrdinal,
            prepareCallCount,
            executeCallCount,
            resolveCallCount
        )
    }

    var keys: [String] {
        lock.lock()
        defer { lock.unlock() }
        return preparedKeys
    }

    private func makeEnvelope() throws -> CommandEnvelopeV1 {
        let ordinal: Int
        lock.lock()
        envelopeOrdinal += 1
        ordinal = envelopeOrdinal
        lock.unlock()
        return try p1eE2Envelope(
            "p1e:e5:\(label):\(ordinal)",
            at: p1eDeletionEpoch.addingTimeInterval(Double(ordinal))
        )
    }

    private func prepare(
        _ request: ActiveIngestionDeletionPrepareRequestV1
    ) throws -> PreparedActiveIngestionDeletionV1 {
        lock.lock()
        prepareCallCount += 1
        preparedKeys.append(request.envelope.idempotencyKey)
        lock.unlock()
        return try store.prepareActiveIngestionDeletion(request: request)
    }

    private func nextExecuteStep() -> P1EDeletionExecutionStep {
        lock.lock()
        defer { lock.unlock() }
        executeCallCount += 1
        return executeSteps.isEmpty ? .store : executeSteps.removeFirst()
    }

    private func execute(
        _ prepared: PreparedActiveIngestionDeletionV1
    ) async -> ActiveIngestionDeletionExecutionResolutionV1 {
        let step = nextExecuteStep()
        if let executionGate {
            await executionGate.suspendUntilReleased()
        }
        switch step {
        case .store:
            return store.executeActiveIngestionDeletion(
                preparedCommand: prepared
            )
        case .resolution(let resolution):
            return resolution
        case .commitThenResolutionPending(let disposition):
            guard case .committed = store.executeActiveIngestionDeletion(
                preparedCommand: prepared
            ) else {
                return .resolutionPending(.integrityBlocked)
            }
            return .resolutionPending(disposition)
        }
    }

    private func resolve(
        _ prepared: PreparedActiveIngestionDeletionV1
    ) async -> ActiveIngestionDeletionExecutionResolutionV1 {
        let scripted = lock.withLock {
            resolveCallCount += 1
            return resolveSteps.isEmpty
                ? nil
                : resolveSteps.removeFirst()
        }
        return scripted ?? store.resolveActiveIngestionDeletionExecution(
            preparedCommand: prepared
        )
    }
}

private struct P1EDeletionEmptyCredentialStore:
    CredentialStore, Sendable
{
    let backendNamespace: CredentialStoreBackendNamespace =
        .isolated(UUID())

    func set(_ value: String, account: String) throws {
        _ = value
        _ = account
    }

    func get(account: String) throws -> String? {
        _ = account
        return nil
    }

    func delete(account: String) throws {
        _ = account
    }
}

private func p1eDeletionController(
    _ fixture: P1EDeletionFixture,
    harness: P1EDeletionWorkflowHarness
) throws -> InputWorkflowController {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "agentloop-p1e-e5-controller-\(UUID().uuidString)"
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let defaultsName = "agentloop-p1e-e5-defaults-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: defaultsName))
    defaults.removePersistentDomain(forName: defaultsName)
    let scopedDefaults = ProfileScopedDefaults(defaults: defaults)
    let resolver = RuntimeCredentialResolver(
        database: fixture.database,
        defaults: scopedDefaults,
        credentialAccess: SynchronizedCredentialAccess(
            store: P1EDeletionEmptyCredentialStore()
        ),
        accounts: RuntimeCredentialAccounts(
            apiKey: "p1e-e5-api",
            searchKey: "p1e-e5-search",
            oauth: .live
        ),
        defaultBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
        tokenRefresher: nil
    )
    let orchestrator = Orchestrator(
        db: fixture.database,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: MockProvider(script: [])
        ),
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
    return InputWorkflowController(
        database: fixture.database,
        orchestrator: orchestrator,
        resolver: resolver,
        reporter: FailureReporter(database: fixture.database),
        activeIngestionDeletionPorts: harness.ports
    )
}

private func p1eDeletionConfirmation(
    _ fixture: P1EDeletionFixture,
    scope: InputDeletionScope = .sourceAndResult
) -> InputDeletionConfirmation {
    InputDeletionConfirmation(
        campId: fixture.campID,
        ingestionId: fixture.ingestionID,
        scope: scope
    )
}

private func p1eDeletionTrace(_ label: String) -> OperationTrace {
    _ = label
    return OperationTraceFactory.live.generated(
        operation: .inputDelete,
        scope: .fixed(.application)
    )
}

private func p1eExpectNotCommitted(
    _ resolution: ActiveIngestionDeletionExecutionResolutionV1,
    _ expected: ActiveIngestionDeletionFailureV1
) {
    guard case .notCommitted(let actual) = resolution else {
        Issue.record("expected notCommitted(\(expected)), got \(resolution)")
        return
    }
    #expect(actual == expected)
}

private func p1eDeletionCounts(
    _ database: AppDatabase
) throws -> (receipt: Int, event: Int, outbox: Int, scope: Int) {
    try database.pool.read { db in
        (
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM domain_command_receipt") ?? 0,
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM domain_event") ?? 0,
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_outbox") ?? 0,
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM camp_event_scope WHERE sourceTable='domain_event'"
            ) ?? 0
        )
    }
}

private func p1eJSONKeys(_ json: String) throws -> Set<String> {
    let object = try #require(
        JSONSerialization.jsonObject(with: Data(json.utf8))
            as? [String: Any]
    )
    return Set(object.keys)
}

private func p1eSeedKnowledgeBlocker(_ fixture: P1EDeletionFixture) throws {
    let note = CampNoteRecord.new(
        campId: fixture.campID,
        missionId: nil,
        title: "Projection",
        bodyMd: "Private projection"
    )
    try fixture.database.saveCampNote(note)
    try fixture.database.pool.write { db in
        try KnowledgeSourceLinkRecord(
            id: "link:\(fixture.ingestionID)",
            campNoteId: note.id,
            ingestionId: fixture.ingestionID,
            locatorJson: "{\"private\":true}",
            createdAt: p1eDeletionEpoch
        ).insert(db)
    }
}

private func p1eSeedCandidateBlocker(_ fixture: P1EDeletionFixture) throws {
    try fixture.database.pool.write { db in
        try ActionCandidateRecord(
            id: "candidate:\(fixture.ingestionID)",
            ingestionId: fixture.ingestionID,
            campId: fixture.campID,
            type: .todo,
            title: "Private candidate",
            detailJson: "{\"private\":true}",
            status: .dismissed,
            missionId: nil,
            idemKey: "candidate-key:\(fixture.ingestionID)",
            createdAt: p1eDeletionEpoch,
            updatedAt: p1eDeletionEpoch
        ).insert(db)
    }
}

private func p1eSeedRuminationWorkBlocker(
    _ fixture: P1EDeletionFixture,
    state: DurableWorkState = .queued,
    withOpenAttempt: Bool = false
) throws -> String {
    let workID = "work:\(fixture.ingestionID):\(state.rawValue)"
    let finishedAt: Date? = [.succeeded, .failed, .canceled].contains(state)
        ? p1eDeletionEpoch : nil
    try fixture.database.pool.write { db in
        let work = DurableWorkRecord(
            id: workID,
            campId: fixture.campID,
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: fixture.ingestionID,
            idempotencyKey: "work-key:\(workID)",
            state: state,
            attempt: withOpenAttempt ? 1 : 0,
            maxAttempts: 4,
            notBefore: nil,
            leaseOwner: state == .running ? "worker:p1e" : nil,
            leaseExpiresAt: state == .running
                ? p1eDeletionEpoch.addingTimeInterval(60) : nil,
            inputJson: "{}",
            inputHash: CanonicalJSONV1.sha256Hex(Data("{}".utf8)),
            outputJson: nil,
            errorCode: state == .failed ? "test_failure" : nil,
            errorMessage: nil,
            traceId: "trace:\(workID)",
            version: 1,
            createdAt: p1eDeletionEpoch,
            updatedAt: p1eDeletionEpoch,
            finishedAt: finishedAt
        )
        try DurableWorkStore.insertCurrentSchemaRecord(work, in: db)
        if withOpenAttempt {
            try db.execute(
                sql: """
                    INSERT INTO durable_work_attempt(
                      workId,attempt,id,workerId,startedAt,endedAt,outcome,
                      errorCode,errorMessage,traceId,terminalWorkVersion
                    ) VALUES (?,1,?,?,?,NULL,NULL,NULL,NULL,?,NULL)
                    """,
                arguments: [
                    workID, "attempt:\(workID)", "worker:p1e",
                    p1eDeletionEpoch, "trace:\(workID)",
                ]
            )
        }
    }
    return workID
}

private func p1eSeedProviderBlocker(_ fixture: P1EDeletionFixture) throws {
    let workID = try p1eSeedRuminationWorkBlocker(
        fixture,
        state: .failed,
        withOpenAttempt: false
    )
    try fixture.database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO durable_work_attempt(
                  workId,attempt,id,workerId,startedAt,endedAt,outcome,
                  errorCode,errorMessage,traceId,terminalWorkVersion
                ) VALUES (?,1,?,?,?,?,?,?,NULL,?,1)
                """,
            arguments: [
                workID, "attempt:\(workID)", "worker:p1e",
                p1eDeletionEpoch, p1eDeletionEpoch, "failed", "test_failure",
                "trace:\(workID)",
            ]
        )
        try db.execute(
            sql: """
                INSERT INTO camp_provider_dispatch(
                  id,workId,workAttempt,turnOrdinal,dispatchAttempt,
                  replayOfDispatchId,idempotencyKey,campId,campLifecycleVersion,
                  operationKind,replayClass,state,requestJson,requestHash,
                  responseJson,responseHash,version,preparedAt,startedAt,
                  returnedAt,consumedAt,abandonedAt,redactedAt
                ) VALUES (?,?,1,0,1,NULL,?,?,1,'memoryPromotion',
                  'replaySafeInference','prepared','{}',?,NULL,NULL,1,?,
                  NULL,NULL,NULL,NULL,NULL)
                """,
            arguments: [
                "dispatch:\(fixture.ingestionID)", workID,
                "dispatch-key:\(fixture.ingestionID)", fixture.campID,
                CanonicalJSONV1.sha256Hex(Data("{}".utf8)), p1eDeletionEpoch,
            ]
        )
    }
}

private struct P1ERuminationRun {
    let work: DurableWorkRecord
    let claim: DurableWorkClaim
}

private func p1eRuminationCommand(
    _ fixture: P1EDeletionFixture,
    label: String
) throws -> RuminationStartCommand {
    let profileID = "profile:p1e:\(label)"
    _ = try seedTestPlanningProfile(
        fixture.database,
        profileId: profileID
    )
    return try RuminationStartCommand(
        preparation: fixture.database.prepareRuminationStart(
            ingestionId: fixture.ingestionID
        ),
        traceId: "trace:p1e:\(label)",
        input: RuminationWorkInput(
            model: "model:p1e:\(label)",
            runtimeProfileId: profileID
        )
    )
}

private func p1eStartAndClaimRumination(
    _ fixture: P1EDeletionFixture,
    label: String
) throws -> P1ERuminationRun {
    let work = try fixture.database.startRumination(
        command: p1eRuminationCommand(fixture, label: label),
        now: p1eDeletionEpoch.addingTimeInterval(1)
    ).work
    let claim = try #require(
        try fixture.database.claimNextSupervisedWork(
            workerId: "worker:p1e:\(label)",
            now: p1eDeletionEpoch.addingTimeInterval(2),
            leaseDuration: 120
        )
    )
    #expect(claim.workId == work.id)
    return P1ERuminationRun(work: work, claim: claim)
}

private func p1eRuminationResult(_ label: String) -> RuminationResult {
    RuminationResult(
        suggestedTitle: "P1-E \(label)",
        summary: "P1-E durable race result",
        keyPoints: [
            .init(text: "winner", sourceQuote: "serialized writer"),
        ],
        requirements: [
            .init(
                title: "preserve winner",
                detail: "late callback cannot recreate rows",
                confidence: .high
            ),
        ],
        todos: [.init(title: "verify race")],
        suggestedMission: nil,
        uncertainties: []
    )
}

private func p1eRuminationProduction(
    _ label: String
) throws -> RuminationProduction {
    RuminationProduction(
        result: p1eRuminationResult(label),
        usage: try RuminationUsageCountersV1(
            cacheReadTokens: 1,
            inputTokens: 2,
            outputTokens: 3
        )
    )
}

private func p1eRuminationFailure() throws -> RuminationAttemptFailure {
    try RuminationAttemptFailure(
        code: "rumination_provider_failed",
        safeMessage: "反刍服务执行失败。",
        disposition: .deterministic,
        usage: nil
    )
}

private func p1eProjectionCounts(
    _ fixture: P1EDeletionFixture
) throws -> (result: Int, candidate: Int, link: Int) {
    try fixture.database.pool.read { database in
        (
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM rumination_result WHERE ingestionId=?",
                arguments: [fixture.ingestionID]
            ) ?? 0,
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM action_candidate WHERE ingestionId=?",
                arguments: [fixture.ingestionID]
            ) ?? 0,
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM knowledge_source_link WHERE ingestionId=?",
                arguments: [fixture.ingestionID]
            ) ?? 0
        )
    }
}

private func p1ePackageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Suite(.serialized)
struct P1EIngestionDeletionContractTests {
    @Test func p1e49DeletionPrepareRequestSurface() throws {
        let fixture = try p1eDeletionFixture("request-surface")
        let request = try p1eDeletionRequest(fixture, scope: .resultOnly)
        #expect(Set(Mirror(reflecting: request).children.compactMap(\.label)) == [
            "envelope", "campId", "ingestionId", "scope",
        ])
    }

    @Test func p1e50DeletionCommandFactoryAuthority() throws {
        let root = p1ePackageRoot()
        let domain = try String(contentsOf: root.appendingPathComponent(
            "Sources/AgentLoopCore/Domain/IngestionDeletion.swift"
        ))
        let store = try String(contentsOf: root.appendingPathComponent(
            "Sources/AgentLoopCore/Database/IngestionDeletionStore.swift"
        ))
        #expect(!domain.contains("ActiveIngestionDeletionCommandV1("))
        #expect(store.contains("fileprivate init("))
        let appDatabase = try String(contentsOf: root.appendingPathComponent(
            "Sources/AgentLoopCore/Database/AppDatabase.swift"
        ))
        #expect(!appDatabase.contains("deleteIngestionAtomically"))
    }

    @Test func p1e51DeletionPrepareSnapshotZeroWritePrivacy() throws {
        let fixture = try p1eDeletionFixture("prepare-private")
        let before = try p1eDeletionCounts(fixture.database)
        let prepared = try p1ePrepared(fixture, scope: .resultOnly)
        #expect(try p1eDeletionCounts(fixture.database) == before)
        let reflected = String(reflecting: prepared)
        for privateValue in [
            "Private title", "Private raw text", "private.invalid",
            "model result", "user edit", "Private author", "Private intent",
        ] {
            #expect(!reflected.contains(privateValue))
        }
    }

    @Test func p1e52DeletionCommandCanonicalHashAndCounts() throws {
        let fixture = try p1eDeletionFixture("canonical")
        let first = try p1ePrepared(fixture, scope: .resultOnly)
        let second = try p1ePrepared(fixture, scope: .resultOnly)
        #expect(first.commandPayloadHash == second.commandPayloadHash)
        #expect(first.commandPayloadHash.count == 64)
        #expect(first.commandPayloadHash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        #expect(first.preview.deletedResultCount == 1)
        #expect(first.preview.deletedIngestionCount == 0)
        #expect(first.preview.updatedIngestionCount == 1)
        #expect(first.preview.allBlockerCountsAreZero)
    }

    @Test func p1e53ResultOnlyNeedsReviewSuccess() throws {
        let fixture = try p1eDeletionFixture("result-review")
        let (_, result) = try p1eCommitted(fixture, scope: .resultOnly)
        #expect(result.deletedResultCount == 1)
        #expect(result.deletedIngestionCount == 0)
        #expect(result.updatedIngestionCount == 1)
        let row = try fixture.database.pool.read { db in
            try Row.fetchOne(db, sql: "SELECT status,errorText,version FROM ingestion_item WHERE id=?", arguments: [fixture.ingestionID])
        }
        #expect(row?["status"] as String? == IngestionStatus.queued.rawValue)
        #expect(row?["errorText"] as String? == nil)
        #expect(row?["version"] as Int? == 2)
        #expect(try fixture.database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM rumination_result WHERE ingestionId=?", arguments: [fixture.ingestionID])
        } == 0)
    }

    @Test func p1e54ResultOnlyFailedWithResultSuccess() throws {
        let fixture = try p1eDeletionFixture("result-failed", status: .failed)
        let (_, result) = try p1eCommitted(fixture, scope: .resultOnly)
        #expect(result.oldIngestionStatus == .failed)
        #expect(result.deletedResultCount == 1)
        #expect(try fixture.database.pool.read { db in
            try String.fetchOne(db, sql: "SELECT status FROM ingestion_item WHERE id=?", arguments: [fixture.ingestionID])
        } == IngestionStatus.queued.rawValue)
    }

    @Test func p1e55ResultOnlyRejectionMatrix() throws {
        for (label, status, result, materialized, expected) in [
            ("queued", IngestionStatus.queued, true, false, ActiveIngestionDeletionFailureV1.invalidIngestionState),
            ("discarded", .discarded, true, false, .invalidIngestionState),
            ("materialized-source", .materialized, true, false, .invalidIngestionState),
            ("missing-result", .needsReview, false, false, .resultRequired),
            ("materialized-result", .needsReview, true, true, .resultMaterialized),
        ] {
            let fixture = try p1eDeletionFixture(
                "result-reject-\(label)",
                status: status,
                withResult: result,
                resultMaterialized: materialized
            )
            #expect(throws: expected) {
                _ = try p1ePrepared(fixture, scope: .resultOnly)
            }
        }
    }

    @Test func p1e56SourceAndResultWithoutResultSuccess() throws {
        let fixture = try p1eDeletionFixture(
            "source-no-result", status: .queued, withResult: false
        )
        let (_, result) = try p1eCommitted(fixture, scope: .sourceAndResult)
        #expect(result.deletedResultCount == 0)
        #expect(result.deletedIngestionCount == 1)
        #expect(result.updatedIngestionCount == 0)
        #expect(try fixture.database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ingestion_item WHERE id=?", arguments: [fixture.ingestionID])
        } == 0)
    }

    @Test func p1e57SourceAndResultWithResultSuccess() throws {
        let fixture = try p1eDeletionFixture("source-with-result")
        let (_, result) = try p1eCommitted(fixture, scope: .sourceAndResult)
        #expect(result.deletedResultCount == 1)
        #expect(result.deletedIngestionCount == 1)
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
    }

    @Test func p1e58SourceAndResultRejectionMatrix() throws {
        for (label, status, materialized, expected) in [
            (
                "ruminating", IngestionStatus.ruminating, false,
                ActiveIngestionDeletionFailureV1.invalidIngestionState
            ),
            ("materialized-source", .materialized, false, .invalidIngestionState),
            ("materialized-result", .needsReview, true, .resultMaterialized),
        ] {
            let fixture = try p1eDeletionFixture(
                "source-reject-\(label)",
                status: status,
                resultMaterialized: materialized
            )
            #expect(throws: expected) {
                _ = try p1ePrepared(fixture, scope: .sourceAndResult)
            }
        }
    }

    @Test func p1e59ProjectionScopeAndPermanentProjectionGuards() throws {
        let fixture = try p1eDeletionFixture("projection")
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try p1ePrepared(fixture, scope: .everythingIncludingProjection)
        }
        try p1eSeedKnowledgeBlocker(fixture)
        try p1eSeedCandidateBlocker(fixture)
        #expect(throws: DatabaseError.self) {
            try fixture.database.pool.write { db in
                try db.execute(sql: "DELETE FROM knowledge_source_link WHERE ingestionId=?", arguments: [fixture.ingestionID])
            }
        }
        #expect(throws: DatabaseError.self) {
            try fixture.database.pool.write { db in
                try db.execute(sql: "DELETE FROM action_candidate WHERE ingestionId=?", arguments: [fixture.ingestionID])
            }
        }
    }

    @Test func p1e60KnowledgeLinkBlockerRejects() throws {
        let fixture = try p1eDeletionFixture("block-link")
        try p1eSeedKnowledgeBlocker(fixture)
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try p1ePrepared(fixture, scope: .sourceAndResult)
        }
    }

    @Test func p1e61CandidateBlockerRejects() throws {
        let fixture = try p1eDeletionFixture("block-candidate")
        try p1eSeedCandidateBlocker(fixture)
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try p1ePrepared(fixture, scope: .sourceAndResult)
        }
    }

    @Test func p1e62RuminationWorkBlockerRejects() throws {
        let fixture = try p1eDeletionFixture("block-work")
        _ = try p1eSeedRuminationWorkBlocker(fixture)
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try p1ePrepared(fixture, scope: .sourceAndResult)
        }
    }

    @Test func p1e63OpenAttemptBlockerRejects() throws {
        let fixture = try p1eDeletionFixture("block-attempt")
        _ = try p1eSeedRuminationWorkBlocker(
            fixture, state: .failed, withOpenAttempt: true
        )
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try p1ePrepared(fixture, scope: .sourceAndResult)
        }
    }

    @Test func p1e64ProviderDispatchBlockerRejects() throws {
        let fixture = try p1eDeletionFixture("block-provider")
        try p1eSeedProviderBlocker(fixture)
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try p1ePrepared(fixture, scope: .sourceAndResult)
        }
    }

    @Test func p1e65DeletionLifecycleTOCTOURejects() throws {
        let fixture = try p1eDeletionFixture("toctou-lifecycle")
        let prepared = try p1ePrepared(fixture, scope: .sourceAndResult)
        try fixture.database.pool.write { db in
            try db.execute(sql: "UPDATE camp SET archived=1 WHERE id=?", arguments: [fixture.campID])
            try db.execute(sql: "UPDATE camp_lifecycle SET state='archived',version=version+1 WHERE campId=?", arguments: [fixture.campID])
        }
        p1eExpectNotCommitted(
            fixture.store.executeActiveIngestionDeletion(preparedCommand: prepared),
            .lifecycleChanged
        )
        #expect(try p1eDeletionCounts(fixture.database) == (0, 0, 0, 0))
    }

    @Test func p1e66DeletionRowAndResultTOCTOURejects() throws {
        let source = try p1eDeletionFixture("toctou-source")
        let sourcePrepared = try p1ePrepared(source, scope: .sourceAndResult)
        try source.database.pool.write { db in
            try db.execute(sql: "UPDATE ingestion_item SET title='changed',version=version+1 WHERE id=?", arguments: [source.ingestionID])
        }
        p1eExpectNotCommitted(
            source.store.executeActiveIngestionDeletion(preparedCommand: sourcePrepared),
            .rowChanged
        )

        let result = try p1eDeletionFixture("toctou-result")
        let resultPrepared = try p1ePrepared(result, scope: .resultOnly)
        try result.database.pool.write { db in
            try db.execute(sql: "UPDATE rumination_result SET resultJson='{}',version=version+1 WHERE ingestionId=?", arguments: [result.ingestionID])
        }
        p1eExpectNotCommitted(
            result.store.executeActiveIngestionDeletion(preparedCommand: resultPrepared),
            .rowChanged
        )
    }

    @Test func p1e67DeletionBlockerTOCTOURejects() throws {
        let fixture = try p1eDeletionFixture("toctou-blocker")
        let prepared = try p1ePrepared(fixture, scope: .sourceAndResult)
        try p1eSeedCandidateBlocker(fixture)
        p1eExpectNotCommitted(
            fixture.store.executeActiveIngestionDeletion(preparedCommand: prepared),
            .blockersChanged
        )
        #expect(try p1eDeletionCounts(fixture.database) == (0, 0, 0, 0))
    }

    @Test func p1e68DeletionEnvelopeAndPersistedGraph() throws {
        let fixture = try p1eDeletionFixture("envelope-graph")
        let (prepared, result) = try p1eCommitted(
            fixture, scope: .sourceAndResult
        )
        let row = try fixture.database.pool.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM domain_event WHERE id=?", arguments: [result.eventId])
        }
        #expect(row?["actorType"] as String? == prepared.envelope.actorType.rawValue)
        #expect(row?["actorId"] as String? == prepared.envelope.actorId)
        #expect(row?["deviceId"] as String? == prepared.envelope.deviceId)
        #expect(row?["correlationId"] as String? == prepared.envelope.correlationId)
        #expect(row?["causationId"] as String? == prepared.envelope.causationId)
        #expect(row?["eventOrdinal"] as Int? == 0)
        #expect(row?["eventIdempotencyKey"] as String? == "\(prepared.envelope.idempotencyKey)#0000:ingestion:\(fixture.ingestionID)")
    }

    @Test func p1e68aDeletionModernCanonicalEnvelopeCommitsPersistedGraph()
        throws
    {
        let fixture = try p1eDeletionFixture("modern-canonical-envelope")
        let occurredAt = try P1DTimestampV1.canonical(
            Date(timeIntervalSince1970: 1_788_279_977.123_456)
        )
        let envelope = try p1eE2Envelope(
            "p1e:deletion:modern-canonical-envelope",
            at: occurredAt
        )
        let prepared = try fixture.store.prepareActiveIngestionDeletion(
            request: ActiveIngestionDeletionPrepareRequestV1(
                envelope: envelope,
                campId: fixture.campID,
                ingestionId: fixture.ingestionID,
                scope: .sourceAndResult
            )
        )

        let resolution = fixture.store.executeActiveIngestionDeletion(
            preparedCommand: prepared
        )

        guard case .committed = resolution else {
            Issue.record("expected committed, got \(resolution)")
            return
        }
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
    }

    @Test func p1e69DeletionExactJSONAndOutboxContract() throws {
        let fixture = try p1eDeletionFixture("json-outbox")
        let (_, result) = try p1eCommitted(fixture, scope: .resultOnly)
        let persisted = try fixture.database.pool.read { db -> (String, String, Row?) in
            let receipt = try String.fetchOne(db, sql: "SELECT resultJson FROM domain_command_receipt WHERE idempotencyKey=?", arguments: [result.commandIdempotencyKey]) ?? ""
            let event = try String.fetchOne(db, sql: "SELECT payloadJson FROM domain_event WHERE id=?", arguments: [result.eventId]) ?? ""
            let outbox = try Row.fetchOne(db, sql: "SELECT * FROM event_outbox WHERE eventId=?", arguments: [result.eventId])
            return (receipt, event, outbox)
        }
        #expect(try p1eJSONKeys(persisted.0) == ActiveIngestionDeletionResultV1.exactJSONKeys)
        #expect(try p1eJSONKeys(persisted.1) == ActiveIngestionDeletionEventPayloadV1.exactJSONKeys)
        for forbidden in ["rawText", "title", "sourceURL", "resultJson", "userEditedJson", "actorId", "deviceId", "accountId"] {
            #expect(!persisted.0.contains(forbidden))
            #expect(!persisted.1.contains(forbidden))
        }
        #expect(persisted.2?["state"] as String? == "pending")
        #expect(persisted.2?["attempt"] as Int? == 0)
        #expect(persisted.2?["version"] as Int? == 1)
    }

    @Test func p1e70DeletionReplayAfterLifecycleAndSourceLoss() throws {
        let fixture = try p1eDeletionFixture("replay-loss")
        let (prepared, first) = try p1eCommitted(fixture, scope: .sourceAndResult)
        try fixture.database.pool.write { db in
            try db.execute(sql: "UPDATE camp SET archived=1 WHERE id=?", arguments: [fixture.campID])
            try db.execute(sql: "UPDATE camp_lifecycle SET state='archived',version=version+1 WHERE campId=?", arguments: [fixture.campID])
        }
        let replay = fixture.store.executeActiveIngestionDeletion(
            preparedCommand: prepared
        )
        #expect(replay == .committed(first))
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
    }

    @Test func p1e71DeletionConflictIntegrityAndNewKeyMatrix() throws {
        let fixture = try p1eDeletionFixture("conflict-integrity")
        let (prepared, _) = try p1eCommitted(fixture, scope: .sourceAndResult)
        try fixture.database.pool.write { db in
            try db.execute(sql: "UPDATE event_outbox SET lastError='tampered',version=version+1 WHERE eventId IN (SELECT id FROM domain_event WHERE commandIdempotencyKey=?)", arguments: [prepared.envelope.idempotencyKey])
        }
        #expect(
            fixture.store.executeActiveIngestionDeletion(preparedCommand: prepared)
                == .resolutionPending(.integrityBlocked)
        )
        #expect(throws: ActiveIngestionDeletionFailureV1.self) {
            _ = try fixture.store.prepareActiveIngestionDeletion(
                request: ActiveIngestionDeletionPrepareRequestV1(
                    envelope: p1eE2Envelope("p1e:new-key-after-loss"),
                    campId: fixture.campID,
                    ingestionId: fixture.ingestionID,
                    scope: .sourceAndResult
                )
            )
        }
    }

    @Test func p1e72DeletionRawEvidenceAndUDFRejectMatrix() throws {
        let fixture = try p1eDeletionFixture("raw-negative")
        #expect(throws: DatabaseError.self) {
            try fixture.database.pool.write { db in
                try db.execute(sql: "DELETE FROM ingestion_item WHERE id=?", arguments: [fixture.ingestionID])
            }
        }
        #expect(throws: DatabaseError.self) {
            try fixture.database.pool.write { db in
                try db.execute(sql: "DELETE FROM rumination_result WHERE ingestionId=?", arguments: [fixture.ingestionID])
            }
        }
        for sql in [
            "SELECT agentloop_active_ingestion_deletion_permit_v1('deleteIngestion')",
            "SELECT agentloop_active_ingestion_deletion_permit_v1('wrongStep',1,2)",
        ] {
            #expect(throws: DatabaseError.self) {
                try fixture.database.pool.read { db in try db.execute(sql: sql) }
            }
        }
    }

    @Test func p1e73DeletionOriginalFourP0Counterexamples() throws {
        let fixture = try p1eDeletionFixture("p0-counterexamples")
        try p1eSeedKnowledgeBlocker(fixture)
        try p1eSeedCandidateBlocker(fixture)
        let attacks = [
            "DELETE FROM ingestion_item WHERE id=?",
            "DELETE FROM rumination_result WHERE ingestionId=?",
            "DELETE FROM knowledge_source_link WHERE ingestionId=?",
            "DELETE FROM action_candidate WHERE ingestionId=?",
        ]
        for sql in attacks {
            #expect(throws: DatabaseError.self) {
                try fixture.database.pool.write { db in
                    try db.execute(sql: sql, arguments: [fixture.ingestionID])
                }
            }
        }
        #expect(try p1eDeletionCounts(fixture.database) == (0, 0, 0, 0))
    }

    @Test func p1e74PermitRegistryInstallAndIsolationContract() throws {
        let first = try ActiveIngestionDeletionSQLPermitTestProbeV1
            .runLifecycleScenario(.directPoolClose)
        let second = try ActiveIngestionDeletionSQLPermitTestProbeV1
            .runLifecycleScenario(.directPoolClose)
        #expect(first.successfulRegistrations == 1)
        #expect(first.rawRegistrationCalls == 1)
        #expect(first.xDestroyCalls == 1)
        #expect(first.activeEntries == 0)
        #expect(first.connectionNonceFingerprint != second.connectionNonceFingerprint)
    }

    @Test func p1e75PermitLifecycleScenarioMatrix() throws {
        for scenario in ActiveIngestionDeletionSQLPermitLifecycleScenarioV1.allCases {
            let report = try ActiveIngestionDeletionSQLPermitTestProbeV1
                .runLifecycleScenario(scenario)
            #expect(report.scenario == scenario)
            #expect(report.completed)
            #expect(report.activeEntries == 0)
            switch scenario {
            case .registrationFailure:
                #expect(report.rawRegistrationCalls == 1)
                #expect(report.successfulRegistrations == 0)
                #expect(report.xDestroyCalls == 1)
                #expect(report.contextDeinits == 1)
                #expect(report.destroyAfterFinalRelease)
            case .laterPrepareDatabaseSetupThrow, .directPoolClose:
                #expect(report.rawRegistrationCalls == 1)
                #expect(report.successfulRegistrations == 1)
                #expect(report.xDestroyCalls == 1)
                #expect(report.contextDeinits == 1)
                #expect(report.destroyAfterFinalRelease)
            case .duplicatePointerInstall:
                #expect(report.installAttempts == 2)
                #expect(report.rawRegistrationCalls == 1)
                #expect(report.successfulRegistrations == 1)
                #expect(report.xDestroyCalls == 1)
                #expect(report.duplicateRejectedBeforeRawCall)
                #expect(report.stickyFaultPresent)
            case .busyCloseThenRetry:
                #expect(report.firstCloseResultClass == .busy)
                #expect(report.secondCloseResultClass == .success)
                #expect(!report.destroyBeforeFinalRelease)
                #expect(report.destroyAfterFinalRelease)
            case .closeV2ZombieFinalRelease:
                #expect(report.firstCloseResultClass == .success)
                #expect(report.secondCloseResultClass == .notAttempted)
                #expect(!report.destroyBeforeFinalRelease)
                #expect(report.destroyAfterFinalRelease)
            case .boundedPointerReuse:
                #expect(report.installAttempts == 256)
                #expect(report.rawRegistrationCalls == 256)
                #expect(report.successfulRegistrations == 256)
                #expect(report.xDestroyCalls == 256)
                #expect(report.contextDeinits == 256)
                #expect(report.pointerReuseCount > 0)
                #expect(report.oldContextDestroyedBeforeReuse)
                #expect(report.destroyAfterFinalRelease)
            }
        }
    }

    @Test func p1e76PermitCleanupMismatchStickyFaultMatrix() throws {
        for scenario in ActiveIngestionDeletionSQLPermitCleanupMismatchV1.allCases {
            let report = try ActiveIngestionDeletionSQLPermitTestProbeV1
                .injectCleanupMismatch(scenario)
            #expect(report.scenario == scenario)
            #expect(report.stickyFaultPresent)
            #expect(report.subsequentSetupRejected)
            #expect(report.subsequentMutationRejected)
            #expect(report.subsequentResolutionRejected)
        }
    }

    @Test func p1e77PermitGenerationArityCursorAndReuseMatrix() throws {
        let fixture = try p1eDeletionFixture("permit-generation")
        let (prepared, first) = try p1eCommitted(fixture, scope: .sourceAndResult)
        #expect(
            fixture.store.executeActiveIngestionDeletion(preparedCommand: prepared)
                == .committed(first)
        )
        #expect(throws: DatabaseError.self) {
            try fixture.database.pool.write { db in
                try db.execute(sql: "SELECT agentloop_active_ingestion_deletion_permit_v1('deleteIngestion')")
            }
        }
        let permitSource = try String(contentsOf: p1ePackageRoot().appendingPathComponent(
            "Sources/AgentLoopCore/Database/ActiveIngestionDeletionSQLPermit.swift"
        ))
        for token in ["receipt", "scope", "event", "outbox", "resultMutation", "ingestionMutation", "finish"] {
            #expect(permitSource.contains(token))
        }
        #expect(permitSource.contains("argumentCount == 53"))
        #expect(permitSource.contains("argumentCount == 63"))
    }

    @Test func p1e78DeletionExecutionResolutionMatrix() throws {
        let committedFixture = try p1eDeletionFixture("resolve-committed")
        let (committedHandle, committedResult) = try p1eCommitted(
            committedFixture, scope: .sourceAndResult
        )
        #expect(
            committedFixture.store.resolveActiveIngestionDeletionExecution(
                preparedCommand: committedHandle
            ) == .committed(committedResult)
        )

        let rolledBackFixture = try p1eDeletionFixture("resolve-rollback")
        let rolledBackHandle = try p1ePrepared(
            rolledBackFixture, scope: .sourceAndResult
        )
        p1eExpectNotCommitted(
            rolledBackFixture.store.resolveActiveIngestionDeletionExecution(
                preparedCommand: rolledBackHandle
            ),
            .notExecuted
        )
    }

    @Test func p1e79DeletionSharedValidatorForgeryAndRelaunch() throws {
        let fixture = try p1eDeletionFixture("validator-relaunch")
        let (prepared, result) = try p1eCommitted(fixture, scope: .resultOnly)
        let reloaded = IngestionDeletionStore(
            database: fixture.database,
            clock: { p1eDeletionEpoch.addingTimeInterval(20) }
        )
        #expect(
            reloaded.resolveActiveIngestionDeletionExecution(
                preparedCommand: prepared
            ) == .committed(result)
        )
        try fixture.database.pool.write { db in
            try db.execute(sql: "UPDATE event_outbox SET lastError='forged',version=version+1 WHERE eventId=?", arguments: [result.eventId])
        }
        #expect(
            reloaded.resolveActiveIngestionDeletionExecution(
                preparedCommand: prepared
            ) == .resolutionPending(.integrityBlocked)
        )
    }

    @Test func p1e80DeletionWorkerAndMaterializerRaceMatrix() throws {
        let startFirst = try p1eDeletionFixture(
            "race-start-first",
            status: .queued,
            withResult: false
        )
        let startFirstDeletion = try p1ePrepared(
            startFirst,
            scope: .sourceAndResult
        )
        _ = try p1eStartAndClaimRumination(
            startFirst,
            label: "start-first"
        )
        guard case .notCommitted(let startFirstFailure) =
            startFirst.store.executeActiveIngestionDeletion(
                preparedCommand: startFirstDeletion
            )
        else {
            throw P1EDeletionTestFailure.unexpectedResolution
        }
        #expect([
            ActiveIngestionDeletionFailureV1.rowChanged,
            .blockersChanged,
        ].contains(startFirstFailure))

        let deleteBeforeStart = try p1eDeletionFixture(
            "race-delete-before-start",
            status: .queued,
            withResult: false
        )
        let staleStartCommand = try p1eRuminationCommand(
            deleteBeforeStart,
            label: "delete-before-start"
        )
        _ = try p1eCommitted(deleteBeforeStart, scope: .sourceAndResult)
        #expect(throws: FeedServiceError.self) {
            _ = try deleteBeforeStart.database.startRumination(
                command: staleStartCommand,
                now: p1eDeletionEpoch.addingTimeInterval(1)
            )
        }
        #expect(try p1eProjectionCounts(deleteBeforeStart) == (0, 0, 0))

        let completeFirst = try p1eDeletionFixture(
            "race-complete-first",
            status: .queued,
            withResult: false
        )
        let completeRun = try p1eStartAndClaimRumination(
            completeFirst,
            label: "complete-first"
        )
        _ = try completeFirst.database.commitRuminationSuccess(
            claim: completeRun.claim,
            production: p1eRuminationProduction("complete-first"),
            now: p1eDeletionEpoch.addingTimeInterval(3)
        )
        let completedVersions = try completeFirst.database.pool.read { db in
            (
                try Int.fetchOne(
                    db,
                    sql: "SELECT version FROM ingestion_item WHERE id=?",
                    arguments: [completeFirst.ingestionID]
                ),
                try Int.fetchOne(
                    db,
                    sql: "SELECT version FROM rumination_result WHERE ingestionId=?",
                    arguments: [completeFirst.ingestionID]
                )
            )
        }
        #expect(completedVersions.0 == 3)
        #expect(completedVersions.1 == 1)
        _ = try p1eCommitted(completeFirst, scope: .sourceAndResult)
        #expect(throws: StaleDurableWorkClaimError.self) {
            _ = try completeFirst.database.commitRuminationSuccess(
                claim: completeRun.claim,
                production: p1eRuminationProduction("late-complete"),
                now: p1eDeletionEpoch.addingTimeInterval(4)
            )
        }
        #expect(try p1eProjectionCounts(completeFirst) == (0, 0, 0))

        let failureFirst = try p1eDeletionFixture(
            "race-failure-first",
            status: .queued,
            withResult: false
        )
        let failureRun = try p1eStartAndClaimRumination(
            failureFirst,
            label: "failure-first"
        )
        _ = try failureFirst.database.recordRuminationAttemptFailure(
            claim: failureRun.claim,
            failure: p1eRuminationFailure(),
            now: p1eDeletionEpoch.addingTimeInterval(3)
        )
        #expect(try failureFirst.database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT version FROM ingestion_item WHERE id=?",
                arguments: [failureFirst.ingestionID]
            )
        } == 3)
        _ = try p1eCommitted(failureFirst, scope: .sourceAndResult)
        #expect(throws: StaleDurableWorkClaimError.self) {
            _ = try failureFirst.database.recordRuminationAttemptFailure(
                claim: failureRun.claim,
                failure: p1eRuminationFailure(),
                now: p1eDeletionEpoch.addingTimeInterval(4)
            )
        }

        let cancelFirst = try p1eDeletionFixture(
            "race-cancel-first",
            status: .queued,
            withResult: false
        )
        let cancelRun = try p1eStartAndClaimRumination(
            cancelFirst,
            label: "cancel-first"
        )
        _ = try cancelFirst.database.cancelRumination(
            ingestionId: cancelFirst.ingestionID,
            workId: cancelRun.work.id,
            expectedVersion: cancelRun.claim.version,
            reason: "p1e_race_cancel",
            now: p1eDeletionEpoch.addingTimeInterval(3)
        )
        _ = try p1eCommitted(cancelFirst, scope: .sourceAndResult)
        #expect(throws: StaleDurableWorkClaimError.self) {
            _ = try cancelFirst.database.commitRuminationSuccess(
                claim: cancelRun.claim,
                production: p1eRuminationProduction("late-after-cancel"),
                now: p1eDeletionEpoch.addingTimeInterval(4)
            )
        }
        #expect(try p1eProjectionCounts(cancelFirst) == (0, 0, 0))

        let lifecycleFirst = try p1eDeletionFixture(
            "race-lifecycle-first",
            status: .queued,
            withResult: false
        )
        let lifecycleRun = try p1eStartAndClaimRumination(
            lifecycleFirst,
            label: "lifecycle-first"
        )
        try lifecycleFirst.database.pool.write { db in
            try db.execute(
                sql: "UPDATE camp SET archived=1 WHERE id=?",
                arguments: [lifecycleFirst.campID]
            )
            try db.execute(
                sql: "UPDATE camp_lifecycle SET state='archived',version=version+1 WHERE campId=?",
                arguments: [lifecycleFirst.campID]
            )
        }
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try lifecycleFirst.database.commitRuminationSuccess(
                claim: lifecycleRun.claim,
                production: p1eRuminationProduction("inactive-lifecycle"),
                now: p1eDeletionEpoch.addingTimeInterval(3)
            )
        }
        #expect(try p1eProjectionCounts(lifecycleFirst) == (0, 0, 0))

        let materializedFirst = try p1eDeletionFixture(
            "race-materialized-first"
        )
        let materializedPrepared = try p1ePrepared(
            materializedFirst,
            scope: .sourceAndResult
        )
        _ = try RuminationMaterializer(
            db: materializedFirst.database
        ).materialize(
            ingestionId: materializedFirst.ingestionID,
            edited: p1eRuminationResult("materialized-first")
        )
        p1eExpectNotCommitted(
            materializedFirst.store.executeActiveIngestionDeletion(
                preparedCommand: materializedPrepared
            ),
            .blockersChanged
        )
        let materializedCounts = try p1eProjectionCounts(materializedFirst)
        #expect(materializedCounts.candidate > 0)
        #expect(materializedCounts.link == 1)

        let deleteBeforeMaterialize = try p1eDeletionFixture(
            "race-delete-before-materialize"
        )
        _ = try p1eCommitted(
            deleteBeforeMaterialize,
            scope: .sourceAndResult
        )
        #expect(throws: FeedServiceError.self) {
            _ = try RuminationMaterializer(
                db: deleteBeforeMaterialize.database
            ).materialize(
                ingestionId: deleteBeforeMaterialize.ingestionID,
                edited: p1eRuminationResult("late-materialize")
            )
        }
        #expect(try p1eProjectionCounts(deleteBeforeMaterialize) == (0, 0, 0))

        let reviewFirst = try p1eDeletionFixture("race-review-first")
        let reviewPrepared = try p1ePrepared(
            reviewFirst,
            scope: .resultOnly
        )
        try reviewFirst.database.saveRuminationReview(
            ingestionId: reviewFirst.ingestionID,
            result: p1eRuminationResult("review-first")
        )
        #expect(try reviewFirst.database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT version FROM rumination_result WHERE ingestionId=?",
                arguments: [reviewFirst.ingestionID]
            )
        } == 2)
        p1eExpectNotCommitted(
            reviewFirst.store.executeActiveIngestionDeletion(
                preparedCommand: reviewPrepared
            ),
            .rowChanged
        )
    }

    @Test func p1e81DeletionControllerSingleFlight() async throws {
        let fixture = try p1eDeletionFixture("controller-single-flight")
        let gate = P1EDeletionExecutionGate()
        let harness = P1EDeletionWorkflowHarness(
            label: "single-flight",
            store: fixture.store,
            executionGate: gate
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let confirmation = p1eDeletionConfirmation(fixture)
        let trace = p1eDeletionTrace("single-flight")

        async let firstPrepare = controller.prepareActiveIngestionDeletion(
            confirmation,
            trace: trace
        )
        async let duplicatePrepare = controller.prepareActiveIngestionDeletion(
            confirmation,
            trace: trace
        )
        let (first, duplicate) = try await (firstPrepare, duplicatePrepare)
        #expect(first.preparedCommand == duplicate.preparedCommand)
        #expect(first.envelope == duplicate.envelope)
        #expect(first.phase == .prepared)
        #expect(harness.counts.envelope == 1)
        #expect(harness.counts.prepare == 1)

        async let execution = controller
            .executePendingActiveIngestionDeletion()
        await gate.waitUntilArrived()
        let duplicateExecution = await controller
            .executePendingActiveIngestionDeletion()
        #expect(duplicateExecution?.phase == .executing)
        #expect(harness.counts.execute == 1)
        #expect(await controller.cancelPreparedActiveIngestionDeletion() == false)
        await gate.release()
        let committed = await execution
        #expect(committed?.phase == .committedRefreshPending)
        #expect(committed?.envelope.idempotencyKey == first.envelope.idempotencyKey)
        #expect(harness.counts.execute == 1)
    }

    @Test func p1e82DeletionPreparedCancelAndNotCommittedRetry()
        async throws
    {
        let fixture = try p1eDeletionFixture("prepared-cancel-retry")
        let harness = P1EDeletionWorkflowHarness(
            label: "prepared-cancel-retry",
            store: fixture.store,
            executeSteps: [
                .resolution(.notCommitted(.rowChanged)),
                .store,
            ]
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let confirmation = p1eDeletionConfirmation(fixture)
        let trace = p1eDeletionTrace("prepared-cancel-retry")

        let canceled = try await controller.prepareActiveIngestionDeletion(
            confirmation,
            trace: trace
        )
        #expect(await controller.cancelPreparedActiveIngestionDeletion())
        #expect(await controller.activeIngestionDeletionPendingState() == nil)
        #expect(harness.counts.execute == 0)

        let retryHandle = try await controller
            .prepareActiveIngestionDeletion(confirmation, trace: trace)
        #expect(
            retryHandle.envelope.idempotencyKey
                != canceled.envelope.idempotencyKey
        )
        let notCommitted = await controller
            .executePendingActiveIngestionDeletion()
        #expect(notCommitted?.phase == .prepared)
        #expect(notCommitted?.failure?.traceId == trace.traceId)
        #expect(
            notCommitted?.envelope.idempotencyKey
                == retryHandle.envelope.idempotencyKey
        )
        let committed = await controller
            .executePendingActiveIngestionDeletion()
        #expect(committed?.phase == .committedRefreshPending)
        #expect(
            committed?.envelope.idempotencyKey
                == retryHandle.envelope.idempotencyKey
        )
        #expect(harness.counts.prepare == 2)
        #expect(harness.counts.execute == 2)
    }

    @Test func p1e83DeletionExecutingCancelCommitRace() async throws {
        let fixture = try p1eDeletionFixture("executing-cancel-race")
        let gate = P1EDeletionExecutionGate()
        let harness = P1EDeletionWorkflowHarness(
            label: "executing-cancel-race",
            store: fixture.store,
            executionGate: gate
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let prepared = try await controller.prepareActiveIngestionDeletion(
            p1eDeletionConfirmation(fixture),
            trace: p1eDeletionTrace("executing-cancel-race")
        )

        async let execution = controller
            .executePendingActiveIngestionDeletion()
        await gate.waitUntilArrived()
        #expect(await controller.cancelPreparedActiveIngestionDeletion() == false)
        #expect(await controller.dismissCommittedActiveIngestionDeletion() == false)
        let executing = await controller
            .activeIngestionDeletionPendingState()
        #expect(executing?.phase == .executing)
        #expect(
            executing?.envelope.idempotencyKey
                == prepared.envelope.idempotencyKey
        )
        await gate.release()
        let committed = await execution
        #expect(committed?.phase == .committedRefreshPending)
        #expect(harness.counts.execute == 1)
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
    }

    @Test func p1e84DeletionRefreshFailureSameKeyReplay() async throws {
        let fixture = try p1eDeletionFixture("refresh-replay")
        let harness = P1EDeletionWorkflowHarness(
            label: "refresh-replay",
            store: fixture.store
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let trace = p1eDeletionTrace("refresh-replay")
        let prepared = try await controller.prepareActiveIngestionDeletion(
            p1eDeletionConfirmation(fixture),
            trace: trace
        )
        _ = await controller.executePendingActiveIngestionDeletion()
        #expect(
            await controller.refreshCommittedActiveIngestionDeletion {
                throw P1EDeletionTestFailure.forcedRefresh
            } == false
        )
        let failedRefresh = await controller
            .activeIngestionDeletionPendingState()
        #expect(failedRefresh?.phase == .committedRefreshPending)
        #expect(failedRefresh?.failure?.traceId == trace.traceId)
        #expect(
            failedRefresh?.envelope.idempotencyKey
                == prepared.envelope.idempotencyKey
        )

        let replayed = await controller
            .executePendingActiveIngestionDeletion()
        #expect(replayed?.phase == .committedRefreshPending)
        #expect(
            replayed?.envelope.idempotencyKey
                == prepared.envelope.idempotencyKey
        )
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
        #expect(
            await controller.refreshCommittedActiveIngestionDeletion {}
        )
        #expect(await controller.activeIngestionDeletionPendingState() == nil)
        #expect(harness.counts.envelope == 1)
        #expect(harness.counts.prepare == 1)
        #expect(harness.counts.execute == 2)
    }

    @Test func p1e85DeletionCommitOutcomeUnknownActions() async throws {
        let fixture = try p1eDeletionFixture("commit-outcome-unknown")
        let harness = P1EDeletionWorkflowHarness(
            label: "commit-outcome-unknown",
            store: fixture.store,
            executeSteps: [
                .commitThenResolutionPending(.commitOutcomeUnknown),
            ]
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let prepared = try await controller.prepareActiveIngestionDeletion(
            p1eDeletionConfirmation(fixture),
            trace: p1eDeletionTrace("commit-outcome-unknown")
        )
        let pending = await controller
            .executePendingActiveIngestionDeletion()
        #expect(pending?.phase == .executionResolutionPending)
        #expect(
            pending?.resolutionDisposition == .commitOutcomeUnknown
        )
        _ = await controller.executePendingActiveIngestionDeletion()
        #expect(harness.counts.execute == 1)
        #expect(await controller.cancelPreparedActiveIngestionDeletion() == false)
        #expect(await controller.dismissCommittedActiveIngestionDeletion() == false)

        let resolved = await controller
            .resolvePendingActiveIngestionDeletion()
        #expect(resolved?.phase == .committedRefreshPending)
        #expect(
            resolved?.envelope.idempotencyKey
                == prepared.envelope.idempotencyKey
        )
        #expect(harness.counts.resolve == 1)
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
    }

    @Test func p1e86DeletionIntegrityBlockedActions() async throws {
        let fixture = try p1eDeletionFixture("integrity-blocked")
        let harness = P1EDeletionWorkflowHarness(
            label: "integrity-blocked",
            store: fixture.store,
            executeSteps: [
                .resolution(.resolutionPending(.integrityBlocked)),
            ],
            resolveSteps: [
                .resolutionPending(.integrityBlocked),
            ]
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let trace = p1eDeletionTrace("integrity-blocked")
        let prepared = try await controller.prepareActiveIngestionDeletion(
            p1eDeletionConfirmation(fixture),
            trace: trace
        )
        let blocked = await controller
            .executePendingActiveIngestionDeletion()
        #expect(blocked?.phase == .executionResolutionPending)
        #expect(blocked?.resolutionDisposition == .integrityBlocked)
        #expect(blocked?.failure?.traceId == trace.traceId)
        _ = await controller.executePendingActiveIngestionDeletion()
        #expect(harness.counts.execute == 1)
        #expect(await controller.cancelPreparedActiveIngestionDeletion() == false)
        #expect(await controller.dismissCommittedActiveIngestionDeletion() == false)
        #expect(
            await controller.abandonTerminalConflict {} == false
        )

        let reread = await controller.resolvePendingActiveIngestionDeletion()
        #expect(reread?.resolutionDisposition == .integrityBlocked)
        #expect(
            reread?.envelope.idempotencyKey
                == prepared.envelope.idempotencyKey
        )
        #expect(harness.counts.resolve == 1)
        #expect(try p1eDeletionCounts(fixture.database) == (0, 0, 0, 0))
    }

    @Test func p1e87DeletionTerminalConflictAbandonFlow() async throws {
        let fixture = try p1eDeletionFixture("terminal-conflict")
        let harness = P1EDeletionWorkflowHarness(
            label: "terminal-conflict",
            store: fixture.store,
            executeSteps: [
                .resolution(.resolutionPending(.terminalConflict)),
            ]
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let trace = p1eDeletionTrace("terminal-conflict")
        let conflictedHandle = try await controller
            .prepareActiveIngestionDeletion(
                p1eDeletionConfirmation(fixture),
                trace: trace
            )
        let conflicted = await controller
            .executePendingActiveIngestionDeletion()
        #expect(conflicted?.resolutionDisposition == .terminalConflict)
        _ = await controller.executePendingActiveIngestionDeletion()
        _ = await controller.resolvePendingActiveIngestionDeletion()
        #expect(harness.counts.execute == 1)
        #expect(harness.counts.resolve == 0)

        #expect(
            await controller.abandonTerminalConflict {
                throw P1EDeletionTestFailure.forcedReload
            } == false
        )
        let reloadFailed = await controller
            .activeIngestionDeletionPendingState()
        #expect(reloadFailed?.resolutionDisposition == .terminalConflict)
        #expect(reloadFailed?.failure?.traceId == trace.traceId)
        #expect(await controller.abandonTerminalConflict {})
        #expect(await controller.activeIngestionDeletionPendingState() == nil)

        let fresh = try await controller.prepareActiveIngestionDeletion(
            p1eDeletionConfirmation(fixture),
            trace: p1eDeletionTrace("terminal-conflict-fresh")
        )
        #expect(
            fresh.envelope.idempotencyKey
                != conflictedHandle.envelope.idempotencyKey
        )
        #expect(harness.counts.prepare == 2)
    }

    @Test func p1e88DeletionCommittedDismissAndReload() async throws {
        let fixture = try p1eDeletionFixture("committed-dismiss")
        let harness = P1EDeletionWorkflowHarness(
            label: "committed-dismiss",
            store: fixture.store
        )
        let controller = try p1eDeletionController(fixture, harness: harness)
        let prepared = try await controller.prepareActiveIngestionDeletion(
            p1eDeletionConfirmation(fixture),
            trace: p1eDeletionTrace("committed-dismiss")
        )
        let committed = await controller
            .executePendingActiveIngestionDeletion()
        #expect(committed?.phase == .committedRefreshPending)
        #expect(await controller.dismissCommittedActiveIngestionDeletion())
        #expect(await controller.activeIngestionDeletionPendingState() == nil)
        #expect(harness.counts.envelope == 1)
        #expect(harness.counts.prepare == 1)
        #expect(harness.counts.execute == 1)
        #expect(harness.keys == [prepared.envelope.idempotencyKey])
        #expect(
            try FeedService(db: fixture.database).item(
                id: fixture.ingestionID
            ) == nil
        )
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
    }

    @Test func p1e89DeletionProcessDeathPersistenceMatrix() async throws {
        let fixture = try p1eDeletionFixture("process-death")
        let beforeCommitHarness = P1EDeletionWorkflowHarness(
            label: "process-death-before",
            store: fixture.store
        )
        do {
            let controller = try p1eDeletionController(
                fixture,
                harness: beforeCommitHarness
            )
            _ = try await controller.prepareActiveIngestionDeletion(
                p1eDeletionConfirmation(fixture),
                trace: p1eDeletionTrace("process-death-before")
            )
            #expect(
                await controller.activeIngestionDeletionPendingState() != nil
            )
        }
        #expect(try p1eDeletionCounts(fixture.database) == (0, 0, 0, 0))
        #expect(
            try FeedService(db: fixture.database).item(
                id: fixture.ingestionID
            ) != nil
        )

        let afterCommitHarness = P1EDeletionWorkflowHarness(
            label: "process-death-after",
            store: fixture.store
        )
        do {
            let controller = try p1eDeletionController(
                fixture,
                harness: afterCommitHarness
            )
            #expect(
                await controller.activeIngestionDeletionPendingState() == nil
            )
            _ = try await controller.prepareActiveIngestionDeletion(
                p1eDeletionConfirmation(fixture),
                trace: p1eDeletionTrace("process-death-after")
            )
            let committed = await controller
                .executePendingActiveIngestionDeletion()
            #expect(committed?.phase == .committedRefreshPending)
        }

        let relaunchedHarness = P1EDeletionWorkflowHarness(
            label: "process-death-relaunch",
            store: fixture.store
        )
        let relaunched = try p1eDeletionController(
            fixture,
            harness: relaunchedHarness
        )
        #expect(
            await relaunched.activeIngestionDeletionPendingState() == nil
        )
        #expect(relaunchedHarness.counts == (0, 0, 0, 0))
        #expect(try p1eDeletionCounts(fixture.database) == (1, 1, 1, 1))
        #expect(
            try FeedService(db: fixture.database).item(
                id: fixture.ingestionID
            ) == nil
        )
    }

    @Test func p1e90DeletionUISourcePrivacyAndScopeSentinels() throws {
        let application = try PlanningTestFixtures.source(
            "AgentLoopApplication/InputWorkflowController.swift"
        )
        let scope = try PlanningTestFixtures.uniqueFunction(
            in: application,
            signature: "package enum InputDeletionScope"
        )
        let scopeBody = String(scope.maskedBody)
        #expect(scopeBody.contains("case resultOnly"))
        #expect(scopeBody.contains("case sourceAndResult"))
        #expect(!scopeBody.contains("everythingIncludingProjection"))

        let pending = try PlanningTestFixtures.uniqueFunction(
            in: application,
            signature: "package struct PendingActiveIngestionDeletion"
        )
        try pending.requireTokensInOrder([
            "preparedCommand:",
            "envelope:",
            "selection:",
            "preview:",
            "phase:",
            "result:",
            "failure:",
            "resolutionDisposition:",
        ])
        for phase in [
            "prepared", "executing", "executionResolutionPending",
            "committedRefreshPending",
        ] {
            #expect(application.contains("case \(phase)"))
        }
        for operation in [
            "prepareActiveIngestionDeletion(",
            "executePendingActiveIngestionDeletion(",
            "resolvePendingActiveIngestionDeletion(",
            "cancelPreparedActiveIngestionDeletion(",
            "refreshCommittedActiveIngestionDeletion(",
            "abandonTerminalConflict(",
            "dismissCommittedActiveIngestionDeletion(",
        ] {
            #expect(application.contains(operation))
        }
        #expect(application.contains("beforeCommittedRefresh"))
        #expect(
            application.contains(
                "try await activeIngestionDeletionPorts.beforeCommittedRefresh()"
            )
        )
        #expect(
            application.contains(
                "occurredAt: try P1DTimestampV1.canonical(Date())"
            )
        )
        #expect(!application.contains("occurredAt: Date()"))
        #expect(!application.contains("InputDeletionReceipt"))
        #expect(!application.contains("delete: @escaping @Sendable (String, InputDeletionScope)"))

        let contracts = try PlanningTestFixtures.source(
            "AgentLoopApp/CodingRanchContracts.swift"
        )
        #expect(!contracts.contains("everythingIncludingProjection"))
        #expect(!contracts.contains("func deleteIngestion("))
        for operation in [
            "prepareIngestionDeletion(", "executeIngestionDeletion(",
            "resolveIngestionDeletion(", "cancelIngestionDeletion(",
            "retryIngestionDeletionRefresh(",
            "abandonIngestionDeletionConflict(",
            "dismissCommittedIngestionDeletion(",
        ] {
            #expect(contracts.contains(operation))
        }

        let adapter = try PlanningTestFixtures.source(
            "AgentLoopApp/CodingRanchStoreAdapter.swift"
        )
        #expect(!adapter.contains("func deleteIngestion("))
        #expect(!adapter.contains("CommandEnvelopeV1("))
        #expect(!adapter.contains("ActiveIngestionDeletionPrepareRequestV1("))
        #expect(!adapter.contains("everythingIncludingProjection"))
        #expect(!adapter.contains("p1eDeletionRefreshShouldFailOnce"))

        let liveHosts = try PlanningTestFixtures.source(
            "AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift"
        )
        #expect(!liveHosts.contains("store.deleteIngestion("))
        #expect(liveHosts.contains("pendingIngestionDeletion"))

        let ruminationViews = try PlanningTestFixtures.source(
            "AgentLoopApp/Views/CodingRanch/RuminationViews.swift"
        )
        let deletionView = try PlanningTestFixtures.uniqueFunction(
            in: ruminationViews,
            signature: "struct IngestionDeletionConfirmationView"
        )
        let rawDeletionView = String(deletionView.body)
        #expect(rawDeletionView.contains("只删除反刍结果"))
        #expect(rawDeletionView.contains("删除原文和反刍结果"))
        #expect(rawDeletionView.contains("已经形成的营地成果不会被删除"))
        #expect(rawDeletionView.contains("追踪 ID"))
        for privateCarrier in [
            "rawText", "sourceURL", "resultJson", "userEditedJson",
        ] {
            #expect(!rawDeletionView.contains(privateCarrier))
        }
        #expect(!ruminationViews.contains("everythingIncludingProjection"))
        #expect(!ruminationViews.contains("try await onDelete(.sourceAndResult)"))

        let store = try PlanningTestFixtures.source(
            "AgentLoopCore/Database/IngestionDeletionStore.swift"
        )
        let executionDiagnostic = try PlanningTestFixtures.uniqueFunction(
            in: store,
            signature:
                "private func recordActiveIngestionDeletionExecutionFailure("
        )
        let rawExecutionDiagnostic = String(executionDiagnostic.body)
        for safeDiagnosticField in [
            "error_type=", "failure_code=", "sqlite_extended_result=",
            "sqlite_message=",
        ] {
            #expect(rawExecutionDiagnostic.contains(safeDiagnosticField))
        }
        for privateCarrier in [
            "rawText", "sourceURL", "resultJson", "userEditedJson",
            "command.envelope", "command.payload", "sql:", "arguments:",
        ] {
            #expect(!rawExecutionDiagnostic.contains(privateCarrier))
        }
        #expect(store.contains("#if DEBUG"))
        #expect(store.contains("ActiveIngestionDeletionPreviewCheckpointV1"))
        #expect(store.contains("beforeEvidenceWrites"))
        let appStore = try PlanningTestFixtures.source(
            "AgentLoopApp/AppStore.swift"
        )
        #expect(appStore.contains("#if DEBUG"))
        #expect(appStore.contains("storeBeforeEvidenceFailure"))
        #expect(appStore.contains("refreshAfterCommitOnce"))
        for forbiddenCapability in [
            "GRDBSQLite", "sqlite3_", "ActiveIngestionDeletionSQLPermit",
        ] {
            #expect(!contracts.contains(forbiddenCapability))
            #expect(!adapter.contains(forbiddenCapability))
            #expect(!liveHosts.contains(forbiddenCapability))
            #expect(!ruminationViews.contains(forbiddenCapability))
        }
    }
}
