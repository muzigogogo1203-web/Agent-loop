import Foundation
import GRDB
import Testing
import AgentLoopCore

private let durableWorkTestNow = Date(
    timeIntervalSinceReferenceDate: 1_000_000
)
private let durableWorkCanonicalInput = #"{"value":1}"#
private let durableWorkCanonicalUsage =
    #"{"cacheReadTokens":1,"inputTokens":2,"outputTokens":3}"#

private struct DurableWorkTestFixture: Sendable {
    let database: AppDatabase
    let store: DurableWorkStore
    let campId: String?
}

private struct DurableLedgerSnapshot: Equatable {
    let work: [String]
    let attempts: [String]
    let events: [String]
    let businessProbe: [String]
}

private enum DurableWorkInjectedFailure: Error, Equatable {
    case businessMutation
}

private func makeDurableWorkFixture(
    createCamp: Bool = true,
    archived: Bool = false
) throws -> DurableWorkTestFixture {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("durable-work-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("fixture.sqlite").path
    )
    var campId: String?
    if createCamp {
        let camp = try database.ensureDefaultCamp()
        campId = camp.id
        if archived {
            try database.setCampArchived(id: camp.id, archived: true)
        }
    }
    try database.pool.write { database in
        try database.execute(sql: """
            CREATE TABLE durable_work_test_business_probe (
              value TEXT PRIMARY KEY NOT NULL
            )
            """)
    }
    return DurableWorkTestFixture(
        database: database,
        store: DurableWorkStore(database: database),
        campId: campId
    )
}

@discardableResult
private func addDurableWorkCamp(
    _ fixture: DurableWorkTestFixture,
    id: String = UUID().uuidString,
    archived: Bool = false
) throws -> String {
    try fixture.database.pool.write { database in
        try database.execute(
            sql: """
                INSERT INTO camp (id, name, archived, createdAt)
                VALUES (?, ?, ?, ?)
                """,
            arguments: [id, "Camp \(id)", archived, durableWorkTestNow]
        )
        try database.execute(
            sql: """
                INSERT INTO camp_lifecycle(
                  campId,state,version,createdAt,updatedAt,
                  deletionRequestedAt,deletedAt
                ) VALUES (?,?,1,?,?,NULL,NULL)
                """,
            arguments: [
                id,
                archived ? "archived" : "active",
                durableWorkTestNow,
                durableWorkTestNow,
            ]
        )
    }
    return id
}

private func durableInputHash(_ input: String) -> String {
    CanonicalJSONV1.sha256Hex(Data(input.utf8))
}

@discardableResult
private func enqueueDurableWork(
    _ fixture: DurableWorkTestFixture,
    campId: String? = nil,
    kind: DurableWorkKind = .coach,
    aggregateType: String = "mission",
    aggregateId: String? = nil,
    inputJson: String = durableWorkCanonicalInput,
    claimedInputHash: String? = nil,
    idempotencyKey: String? = nil,
    maxAttempts: Int = 4,
    traceId: String? = nil,
    now: Date = durableWorkTestNow
) throws -> DurableWorkEnqueueResult {
    try fixture.store.enqueue(
        campId: campId ?? #require(fixture.campId),
        kind: kind,
        aggregateType: aggregateType,
        aggregateId: aggregateId ?? UUID().uuidString,
        inputJson: inputJson,
        claimedInputHash: claimedInputHash ?? durableInputHash(inputJson),
        idempotencyKey: idempotencyKey ?? UUID().uuidString,
        maxAttempts: maxAttempts,
        traceId: traceId ?? UUID().uuidString,
        now: now
    )
}

private func claimDurableWork(
    _ fixture: DurableWorkTestFixture,
    kinds: [DurableWorkKind] = [.coach],
    workerId: String = "worker-1",
    now: Date = durableWorkTestNow,
    leaseDuration: TimeInterval = 60
) throws -> DurableWorkClaim {
    try #require(try fixture.store.claimNext(
        kinds: kinds,
        workerId: workerId,
        now: now,
        leaseDuration: leaseDuration
    ))
}

private func transientDurableFailure(
    code: String = "network_error",
    message: String? = "Temporary network error",
    usageJson: String? = durableWorkCanonicalUsage
) throws -> DurableWorkFailure {
    try DurableWorkFailure(
        code: code,
        message: message,
        disposition: .transient,
        usageJson: usageJson
    )
}

private func deterministicDurableFailure(
    code: String = "schema_error",
    message: String? = "Invalid response",
    usageJson: String? = nil
) throws -> DurableWorkFailure {
    try DurableWorkFailure(
        code: code,
        message: message,
        disposition: .deterministic,
        usageJson: usageJson
    )
}

private func durableRows(
    _ database: Database,
    table: String,
    columns: [String],
    orderBy: String
) throws -> [String] {
    let projection = columns
        .map { "quote(\($0))" }
        .joined(separator: " || char(31) || ")
    return try String.fetchAll(
        database,
        sql: "SELECT \(projection) FROM \(table) ORDER BY \(orderBy)"
    )
}

private func durableLedgerSnapshot(
    _ fixture: DurableWorkTestFixture
) throws -> DurableLedgerSnapshot {
    try fixture.database.pool.read { database in
        DurableLedgerSnapshot(
            work: try durableRows(
                database,
                table: "durable_work",
                columns: [
                    "id", "campId", "kind", "aggregateType", "aggregateId",
                    "idempotencyKey", "state", "attempt", "maxAttempts",
                    "notBefore", "leaseOwner", "leaseExpiresAt", "inputJson",
                    "inputHash", "outputJson", "errorCode", "errorMessage",
                    "traceId", "version", "createdAt", "updatedAt",
                    "finishedAt",
                ],
                orderBy: "id"
            ),
            attempts: try durableRows(
                database,
                table: "durable_work_attempt",
                columns: [
                    "workId", "attempt", "id", "workerId", "startedAt",
                    "endedAt", "outcome", "errorCode", "errorMessage",
                    "traceId", "terminalWorkVersion",
                ],
                orderBy: "workId, attempt"
            ),
            events: try durableRows(
                database,
                table: "durable_work_attempt_event",
                columns: [
                    "id", "workId", "attempt", "sequence", "eventKind",
                    "workerId", "workVersion", "resultingWorkState",
                    "errorCode", "errorMessage", "occurredAt",
                ],
                orderBy: "workId, attempt, sequence"
            ),
            businessProbe: try String.fetchAll(
                database,
                sql: """
                    SELECT value
                    FROM durable_work_test_business_probe
                    ORDER BY value
                    """
            )
        )
    }
}

private func durableWorkCount(
    _ fixture: DurableWorkTestFixture
) throws -> Int {
    try fixture.database.pool.read {
        try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM durable_work") ?? 0
    }
}

private func activeRuminationWorkCount(
    _ fixture: DurableWorkTestFixture,
    ingestionId: String
) throws -> Int {
    try fixture.database.pool.read {
        try Int.fetchOne(
            $0,
            sql: """
                SELECT COUNT(*)
                FROM durable_work
                WHERE kind = 'rumination'
                  AND aggregateType = 'ingestion'
                  AND aggregateId = ?
                  AND state IN ('queued', 'running', 'retryScheduled')
                """,
            arguments: [ingestionId]
        ) ?? 0
    }
}

@discardableResult
private func startTestRumination(
    _ fixture: DurableWorkTestFixture,
    ingestionId: String,
    profileId: String = "test-rumination-profile",
    model: String = "test-rumination-model"
) throws -> DurableWorkRecord {
    _ = try seedTestPlanningProfile(
        fixture.database,
        profileId: profileId
    )
    let preparation = try fixture.database.prepareRuminationStart(
        ingestionId: ingestionId
    )
    let command = try RuminationStartCommand(
        preparation: preparation,
        traceId: "test-rumination-trace:\(ingestionId)",
        input: RuminationWorkInput(
            model: model,
            runtimeProfileId: profileId
        )
    )
    return try fixture.database.startRumination(
        command: command,
        now: durableWorkTestNow
    ).work
}

private struct A2RuminationStartFixture {
    let item: IngestionItemRecord
    let preparation: RuminationStartPreparation
    let command: RuminationStartCommand
    let work: DurableWorkRecord
}

private func addA2Ingestion(
    _ fixture: DurableWorkTestFixture,
    rawText: String = "A2 durable rumination source",
    title: String? = nil
) throws -> IngestionItemRecord {
    let campId = try #require(fixture.campId)
    guard case let .created(item) = try FeedService(
        db: fixture.database
    ).submit(
        campId: campId,
        rawText: rawText,
        title: title
    ) else {
        throw InvalidDurableWorkStateError()
    }
    return item
}

private func makeA2RuminationCommand(
    _ fixture: DurableWorkTestFixture,
    ingestionId: String,
    preparation: RuminationStartPreparation? = nil,
    profileId: String = "test-rumination-profile",
    model: String = "test-rumination-model",
    traceId: String? = nil,
    seedProfile: Bool = true
) throws -> (
    preparation: RuminationStartPreparation,
    command: RuminationStartCommand
) {
    if seedProfile {
        _ = try seedTestPlanningProfile(
            fixture.database,
            profileId: profileId
        )
    }
    let resolvedPreparation = try preparation
        ?? fixture.database.prepareRuminationStart(
            ingestionId: ingestionId
        )
    return (
        resolvedPreparation,
        try RuminationStartCommand(
            preparation: resolvedPreparation,
            traceId: traceId
                ?? "a2-rumination-trace:\(ingestionId)",
            input: RuminationWorkInput(
                model: model,
                runtimeProfileId: profileId
            )
        )
    )
}

private func makeA2RuminationStart(
    _ fixture: DurableWorkTestFixture,
    rawText: String = "A2 durable rumination source",
    title: String? = nil,
    profileId: String = "test-rumination-profile",
    model: String = "test-rumination-model",
    traceId: String? = nil,
    now: Date = durableWorkTestNow
) throws -> A2RuminationStartFixture {
    let item = try addA2Ingestion(
        fixture,
        rawText: rawText,
        title: title
    )
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id,
        profileId: profileId,
        model: model,
        traceId: traceId
    )
    let result = try fixture.database.startRumination(
        command: prepared.command,
        now: now
    )
    guard result.disposition == .inserted else {
        throw InvalidDurableWorkStateError()
    }
    return A2RuminationStartFixture(
        item: item,
        preparation: prepared.preparation,
        command: prepared.command,
        work: result.work
    )
}

private func claimA2Rumination(
    _ fixture: DurableWorkTestFixture,
    workerId: String = "a2-rumination-worker",
    now: Date = durableWorkTestNow,
    leaseDuration: TimeInterval = 60
) throws -> DurableWorkClaim {
    try #require(
        try fixture.database.claimNextSupervisedWork(
            workerId: workerId,
            now: now,
            leaseDuration: leaseDuration
        )
    )
}

private func a2RuminationResult(
    title: String = "A2 反刍成果",
    summary: String = "A2 durable result"
) -> RuminationResult {
    RuminationResult(
        suggestedTitle: title,
        summary: summary,
        keyPoints: [
            .init(text: "durable", sourceQuote: "A2 durable rumination source"),
        ],
        requirements: [
            .init(
                title: "persist",
                detail: "commit exactly once",
                confidence: .high
            ),
        ],
        todos: [.init(title: "verify")],
        suggestedMission: .init(
            goal: "verify durable rumination",
            acceptance: ["one result"],
            why: "prove atomic persistence"
        ),
        uncertainties: []
    )
}

private func a2RuminationUsage(
    cacheRead: Int64 = 1,
    input: Int64 = 2,
    output: Int64 = 3
) throws -> RuminationUsageCountersV1 {
    try RuminationUsageCountersV1(
        cacheReadTokens: cacheRead,
        inputTokens: input,
        outputTokens: output
    )
}

private func a2RuminationProduction(
    title: String = "A2 反刍成果",
    summary: String = "A2 durable result"
) throws -> RuminationProduction {
    RuminationProduction(
        result: a2RuminationResult(title: title, summary: summary),
        usage: try a2RuminationUsage()
    )
}

private func a2TransientRuminationFailure()
    throws -> RuminationAttemptFailure
{
    try RuminationAttemptFailure(
        code: "rumination_transport_error",
        safeMessage: "反刍服务网络连接失败。",
        disposition: .transient,
        usage: nil
    )
}

private func a2DeterministicRuminationFailure(
    usage: RuminationUsageCountersV1? = nil
) throws -> RuminationAttemptFailure {
    try RuminationAttemptFailure(
        code: "rumination_contract_invalid",
        safeMessage: "反刍结果格式无效。",
        disposition: .deterministic,
        usage: usage ?? a2RuminationUsage()
    )
}

private func setA2IngestionStatus(
    _ fixture: DurableWorkTestFixture,
    ingestionId: String,
    status: IngestionStatus,
    attempt: Int? = nil,
    errorText: String? = nil,
    now: Date = durableWorkTestNow
) throws {
    try fixture.database.pool.write { database in
        guard var item = try IngestionItemRecord.fetchOne(
            database,
            key: ingestionId
        ) else {
            throw FeedServiceError.ingestionNotFound(ingestionId)
        }
        item.status = status
        if let attempt {
            item.attempt = attempt
        }
        item.errorText = errorText
        item.updatedAt = now
        try item.update(database)
    }
}

private func a2RuminationWorks(
    _ fixture: DurableWorkTestFixture,
    ingestionId: String
) throws -> [DurableWorkRecord] {
    try fixture.database.pool.read {
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.rumination.rawValue
                    && Column("aggregateType") == "ingestion"
                    && Column("aggregateId") == ingestionId
            )
            .order(Column("createdAt"), Column("rowid"))
            .fetchAll($0)
    }
}

private func a2RuminationResultRecord(
    _ fixture: DurableWorkTestFixture,
    ingestionId: String
) throws -> RuminationResultRecord? {
    try fixture.database.pool.read {
        try RuminationResultRecord
            .filter(Column("ingestionId") == ingestionId)
            .fetchOne($0)
    }
}

private func a2DomainEvents(
    _ fixture: DurableWorkTestFixture,
    kind: String
) throws -> [EventRecord] {
    try fixture.database.pool.read {
        try EventRecord
            .filter(Column("kind") == kind)
            .order(Column("createdAt"), Column("rowid"))
            .fetchAll($0)
    }
}

private func a2Attempt(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    attempt: Int
) throws -> DurableWorkAttemptRecord? {
    try fixture.database.pool.read {
        try DurableWorkAttemptRecord.fetchOne(
            $0,
            key: ["workId": workId, "attempt": attempt]
        )
    }
}

private func a2AttemptEvents(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    attempt: Int
) throws -> [DurableWorkAttemptEventRecord] {
    try fixture.database.pool.read {
        try DurableWorkAttemptEventRecord
            .filter(
                Column("workId") == workId
                    && Column("attempt") == attempt
            )
            .order(Column("sequence"))
            .fetchAll($0)
    }
}

private func installA2AbortTrigger(
    _ fixture: DurableWorkTestFixture,
    name: String,
    sql: String
) throws {
    try fixture.database.pool.write {
        try $0.execute(sql: "CREATE TEMP TRIGGER \(name) \(sql)")
    }
}

private func removeA2AbortTrigger(
    _ fixture: DurableWorkTestFixture,
    name: String
) throws {
    try fixture.database.pool.write {
        try $0.execute(sql: "DROP TRIGGER IF EXISTS \(name)")
    }
}

private enum A2TestTimeoutError: Error {
    case conditionNotReached
}

private func a2Eventually(
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(1),
    _ condition: @escaping @Sendable () async throws -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while true {
        if try await condition() {
            return
        }
        guard clock.now < deadline else {
            throw A2TestTimeoutError.conditionNotReached
        }
        try await Task.sleep(for: pollInterval)
    }
}

private final class A2MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date = durableWorkTestNow) {
        self.value = value
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ value: Date) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
}

private final class A2ResolverRecorder:
    PlanningProviderResolver, @unchecked Sendable
{
    typealias Body = @Sendable (
        _ profileId: String,
        _ model: String
    ) throws -> any LLMProvider

    private let lock = NSLock()
    private var recorded: [(String, String)] = []
    private let body: Body

    init(
        provider: any LLMProvider
    ) {
        self.body = { _, _ in provider }
    }

    init(body: @escaping Body) {
        self.body = body
    }

    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider {
        lock.lock()
        recorded.append((profileId, model))
        lock.unlock()
        return try body(profileId, model)
    }

    func calls() -> [(String, String)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

private actor A2RuminationCommandRecorder {
    private var values: [RuminationPhaseCommand] = []

    func record(_ command: RuminationPhaseCommand) {
        values.append(command)
    }

    func commands() -> [RuminationPhaseCommand] {
        values
    }
}

private actor A2ProviderGate {
    private var opened = false
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        entered = true
        if opened {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func hasEntered() -> Bool {
        entered
    }

    func open() {
        opened = true
        let pending = waiters
        waiters.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}

private actor A2RuminationSinkGate {
    private var commands: [RuminationPhaseCommand] = []
    private var shouldBlockFirstProjection = true
    private var projectionBlocked = false
    private var projectionContinuation:
        CheckedContinuation<Void, Never>?

    func receive(_ command: RuminationPhaseCommand) async {
        commands.append(command)
        guard shouldBlockFirstProjection,
              case .invalidate(.projectionCommitted) = command
        else {
            return
        }
        shouldBlockFirstProjection = false
        projectionBlocked = true
        await withCheckedContinuation { continuation in
            projectionContinuation = continuation
        }
    }

    func hasBlockedProjection() -> Bool {
        projectionBlocked
    }

    func releaseProjection() {
        let continuation = projectionContinuation
        projectionContinuation = nil
        continuation?.resume()
    }

    func recordedCommands() -> [RuminationPhaseCommand] {
        commands
    }
}

private actor A2GatedRuminationProvider: LLMProvider {
    private let gate: A2ProviderGate
    private let turn: TurnResult
    private(set) var callCount = 0
    private(set) var recordedTools: [[ToolDef]] = []

    init(gate: A2ProviderGate, turn: TurnResult) {
        self.gate = gate
        self.turn = turn
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
                let turn = await self.next(tools: tools)
                await gate.wait()
                for block in turn.content {
                    if case let .text(text) = block {
                        continuation.yield(.textDelta(text))
                    }
                }
                continuation.yield(.turn(turn))
                continuation.finish()
            }
        }
    }

    private func next(tools: [ToolDef]) -> TurnResult {
        callCount += 1
        recordedTools.append(tools)
        return turn
    }
}

#if DEBUG
struct A2RuminationAuthorizationPersistenceSnapshot:
    Equatable, Sendable
{
    let workRows: [String]
    let attemptRows: [String]
    let attemptEventRows: [String]
    let ingestionRows: [String]
    let resultRows: [String]
    let domainEventRows: [String]
    let businessRows: [String]
    let campRows: [String]
    let persistedWorkState: DurableWorkState?
    let persistedWorkAttempt: Int?
    let persistedWorkVersion: Int?
    let persistedWorkErrorCode: String?
    let persistedItemStatus: IngestionStatus?
    let persistedItemAttempt: Int?
    let resultCount: Int
    let completedEventCount: Int
    let failedEventCount: Int
}

struct A2RuminationAuthorizationMatrixObservation: Sendable {
    let checkpoint: A2RuminationAuthorizationCheckpointForTesting
    let loss: A2RuminationAuthorizationLossForTesting
    let identity: RuminationPhaseIdentity
    let commands: [RuminationPhaseCommand]
    let providerCallCount: Int
    let before: A2RuminationAuthorizationPersistenceSnapshot
    let after: A2RuminationAuthorizationPersistenceSnapshot
    let lateCommands: [RuminationPhaseCommand]
}

private final class A2RuminationAuthorizationMatrixProvider:
    LLMProvider, @unchecked Sendable
{
    private typealias Continuation =
        AsyncThrowingStream<ProviderEvent, Error>.Continuation

    private let lock = NSLock()
    private let turn: TurnResult
    private var continuation: Continuation?
    private var calls = 0
    private var tools: [[ToolDef]] = []

    init(turn: TurnResult) {
        self.turn = turn
    }

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            calls += 1
            self.tools.append(tools)
            precondition(
                self.continuation == nil,
                "matrix provider received a concurrent second turn"
            )
            self.continuation = continuation
            lock.unlock()
        }
    }

    func hasEntered() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return continuation != nil
    }

    func open() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        precondition(
            continuation != nil,
            "matrix provider opened before dispatch"
        )
        for block in turn.content {
            if case let .text(text) = block {
                continuation?.yield(.textDelta(text))
            }
        }
        continuation?.yield(.turn(turn))
        continuation?.finish()
    }

    func callCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func recordedTools() -> [[ToolDef]] {
        lock.lock()
        defer { lock.unlock() }
        return tools
    }
}

private func a2RuminationAuthorizationPersistenceSnapshot(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    ingestionId: String
) throws -> A2RuminationAuthorizationPersistenceSnapshot {
    try fixture.database.pool.read { database in
        let work = try DurableWorkRecord.fetchOne(database, key: workId)
        let item = try IngestionItemRecord.fetchOne(
            database,
            key: ingestionId
        )
        let resultCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM rumination_result
                WHERE ingestionId = ?
                """,
            arguments: [ingestionId]
        ) ?? 0
        let completedEventCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM event
                WHERE kind = ?
                  AND json_extract(payloadJson, '$.workId') = ?
                """,
            arguments: [EventKind.ruminationCompleted, workId]
        ) ?? 0
        let failedEventCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM event
                WHERE kind = ?
                  AND json_extract(payloadJson, '$.workId') = ?
                """,
            arguments: [EventKind.ruminationFailed, workId]
        ) ?? 0
        return A2RuminationAuthorizationPersistenceSnapshot(
            workRows: try durableRows(
                database,
                table: "durable_work",
                columns: [
                    "id", "campId", "kind", "aggregateType",
                    "aggregateId", "idempotencyKey", "state",
                    "attempt", "maxAttempts", "notBefore",
                    "leaseOwner", "leaseExpiresAt", "inputJson",
                    "inputHash", "outputJson", "errorCode",
                    "errorMessage", "traceId", "version",
                    "createdAt", "updatedAt", "finishedAt",
                ],
                orderBy: "id"
            ),
            attemptRows: try durableRows(
                database,
                table: "durable_work_attempt",
                columns: [
                    "workId", "attempt", "id", "workerId",
                    "startedAt", "endedAt", "outcome", "errorCode",
                    "errorMessage", "traceId", "terminalWorkVersion",
                ],
                orderBy: "workId, attempt"
            ),
            attemptEventRows: try durableRows(
                database,
                table: "durable_work_attempt_event",
                columns: [
                    "id", "workId", "attempt", "sequence",
                    "eventKind", "workerId", "workVersion",
                    "resultingWorkState", "errorCode",
                    "errorMessage", "occurredAt",
                ],
                orderBy: "workId, attempt, sequence"
            ),
            ingestionRows: try durableRows(
                database,
                table: "ingestion_item",
                columns: [
                    "id", "campId", "sourceType", "title", "rawText",
                    "sourceURL", "author", "userIntent", "contentHash",
                    "status", "attempt", "errorText", "createdAt",
                    "updatedAt",
                ],
                orderBy: "id"
            ),
            resultRows: try durableRows(
                database,
                table: "rumination_result",
                columns: [
                    "id", "ingestionId", "pipelineVersion",
                    "resultJson", "userEditedJson", "materializedAt",
                    "createdAt", "updatedAt",
                ],
                orderBy: "id"
            ),
            domainEventRows: try durableRows(
                database,
                table: "event",
                columns: [
                    "id", "missionId", "cardId", "runId", "kind",
                    "payloadJson", "createdAt",
                ],
                orderBy: "rowid"
            ),
            businessRows: try String.fetchAll(
                database,
                sql: """
                    SELECT value
                    FROM durable_work_test_business_probe
                    ORDER BY value
                    """
            ),
            campRows: try durableRows(
                database,
                table: "camp",
                columns: ["id", "name", "archived", "createdAt"],
                orderBy: "id"
            ),
            persistedWorkState: work?.state,
            persistedWorkAttempt: work?.attempt,
            persistedWorkVersion: work?.version,
            persistedWorkErrorCode: work?.errorCode,
            persistedItemStatus: item?.status,
            persistedItemAttempt: item?.attempt,
            resultCount: resultCount,
            completedEventCount: completedEventCount,
            failedEventCount: failedEventCount
        )
    }
}

func a2RunRuminationAuthorizationMatrixCell(
    checkpoint: A2RuminationAuthorizationCheckpointForTesting,
    loss: A2RuminationAuthorizationLossForTesting
) async throws -> A2RuminationAuthorizationMatrixObservation {
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let provider = A2RuminationAuthorizationMatrixProvider(
        turn: TurnResult(
            content: [
                .text(try RuminationCoding.encode(a2RuminationResult())),
            ],
            stopReason: .endTurn,
            usage: Usage(
                inputTokens: 23,
                outputTokens: 46,
                cacheReadTokens: 7
            )
        )
    )
    let recorder = A2RuminationCommandRecorder()
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider),
        recorder: recorder
    )
    try await activateA2Supervisor(supervisor)
    let work = try await supervisor.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await a2Eventually {
        provider.hasEntered()
    }
    let identity = try RuminationPhaseIdentity(
        ingestionId: item.id,
        workId: work.id,
        attempt: 1
    )
    let before = try a2RuminationAuthorizationPersistenceSnapshot(
        fixture,
        workId: work.id,
        ingestionId: item.id
    )
    try await supervisor.armA2RuminationAuthorizationScenarioForTesting(
        .inject(checkpoint: checkpoint, loss: loss),
        identity: identity
    )
    provider.open()
    try await a2Eventually {
        let commands = await recorder.commands()
        return commands.contains { command in
            guard case let .invalidate(
                .phase(invalidated, _)
            ) = command else {
                return false
            }
            return invalidated == identity
        }
    }
    let after = try a2RuminationAuthorizationPersistenceSnapshot(
        fixture,
        workId: work.id,
        ingestionId: item.id
    )
    let commands = await recorder.commands()
    for _ in 0..<100 {
        await Task.yield()
    }
    let settledCommands = await recorder.commands()
    let lateCommands = Array(
        settledCommands.dropFirst(commands.count)
    )
    let providerCallCount = provider.callCount()
    #expect(provider.recordedTools() == [[]])
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
    return A2RuminationAuthorizationMatrixObservation(
        checkpoint: checkpoint,
        loss: loss,
        identity: identity,
        commands: commands,
        providerCallCount: providerCallCount,
        before: before,
        after: after,
        lateCommands: lateCommands
    )
}
#endif

private func a2ValidPlanTurn() -> TurnResult {
    TurnResult(
        content: [
            .toolUse(
                id: "a2-plan",
                name: "propose_plan",
                input: [
                    "goalRefined": "A2 FIFO verified",
                    "cards": [
                        [
                            "title": "Verify FIFO",
                            "description": "Complete the supervised work",
                            "expectedOutput": "A durable result",
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

private func makeA2Supervisor(
    _ fixture: DurableWorkTestFixture,
    resolver: any PlanningProviderResolver,
    recorder: A2RuminationCommandRecorder =
        A2RuminationCommandRecorder(),
    phaseSink: (
        @Sendable (RuminationPhaseCommand) async -> Void
    )? = nil,
    clock: A2MutableClock = A2MutableClock(),
    workerId: String = "a2-supervisor-worker"
) -> DurableWorkSupervisor {
    DurableWorkSupervisor(
        database: fixture.database,
        planningProviderResolver: resolver,
        workerId: workerId,
        now: { clock.now() },
        sleep: { _ in
            try await Task.sleep(for: .seconds(3_600))
        },
        onMissionChanged: { _ in },
        onRuminationPhase: { command in
            if let phaseSink {
                await phaseSink(command)
            } else {
                await recorder.record(command)
            }
        }
    )
}

private func activateA2Supervisor(
    _ supervisor: DurableWorkSupervisor,
    legacySnapshot: LegacyRuminationStartupSnapshot =
        .legacyProfileUnresolved
) async throws {
    let mode = try await supervisor.recoverOnStartup(
        profileModels: [:],
        legacyRuminationSnapshot: legacySnapshot
    )
    guard mode == .running else {
        throw InvalidDurableWorkStateError()
    }
    try await supervisor.activateAfterOrchestratorRecovery()
}

private struct A2SupervisorRuminationOutcome {
    let work: DurableWorkRecord
    let item: IngestionItemRecord
    let attempt: DurableWorkAttemptRecord
    let result: RuminationResultRecord?
    let completedEvents: [EventRecord]
    let failedEvents: [EventRecord]
    let providerCallCount: Int
    let providerTools: [[ToolDef]]
}

private func a2RunSupervisorRuminationTurn(
    rawText: String,
    usage: Usage
) async throws -> A2SupervisorRuminationOutcome {
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(
        fixture,
        rawText: "Supervisor usage accounting source"
    )
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let provider = MockProvider(script: [
        TurnResult(
            content: [.text(rawText)],
            stopReason: .endTurn,
            usage: usage
        ),
    ])
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider)
    )
    try await activateA2Supervisor(supervisor)
    let started = try await supervisor.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await supervisor.waitUntilTerminal(workId: started.id)
    let work = try #require(try fixture.store.work(id: started.id))
    let projected = try #require(
        try FeedService(db: fixture.database).item(id: item.id)
    )
    let attempt = try #require(
        try a2Attempt(fixture, workId: work.id, attempt: 1)
    )
    let result = try a2RuminationResultRecord(
        fixture,
        ingestionId: item.id
    )
    let completed = try a2DomainEvents(
        fixture,
        kind: EventKind.ruminationCompleted
    )
    let failed = try a2DomainEvents(
        fixture,
        kind: EventKind.ruminationFailed
    )
    let providerCallCount = await provider.callCount
    let providerTools = await provider.recordedTools
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
    return A2SupervisorRuminationOutcome(
        work: work,
        item: projected,
        attempt: attempt,
        result: result,
        completedEvents: completed,
        failedEvents: failed,
        providerCallCount: providerCallCount,
        providerTools: providerTools
    )
}

private func a2EventPayload(
    _ event: EventRecord
) throws -> [String: Any] {
    try #require(
        try JSONSerialization.jsonObject(
            with: Data(event.payloadJson.utf8)
        ) as? [String: Any]
    )
}

private func a2PayloadUsage(
    _ payload: [String: Any]
) throws -> [String: Any] {
    try #require(payload["usage"] as? [String: Any])
}

private enum A2StrictResolverScenario: CaseIterable {
    case profileNotFound
    case catalogUnavailable
    case modelUnsupported
    case credentialAccountMissing
    case credentialNotFound
    case credentialReadFailed
    case endpointInvalid
    case providerConstructionFailed
    case oauthAccountIdNotFound
    case oauthAccountIdReadFailed
    case cliUnsupported

    var expectedRuminationCode: String {
        switch self {
        case .profileNotFound:
            return "rumination_profile_not_found"
        case .catalogUnavailable:
            return "rumination_model_catalog_unavailable"
        case .modelUnsupported:
            return "rumination_model_unsupported"
        case .credentialAccountMissing:
            return "rumination_credential_account_missing"
        case .credentialNotFound:
            return "rumination_credential_not_found"
        case .credentialReadFailed:
            return "rumination_credential_read_failed"
        case .endpointInvalid:
            return "rumination_endpoint_invalid"
        case .providerConstructionFailed:
            return "rumination_provider_construction_failed"
        case .oauthAccountIdNotFound:
            return "rumination_oauth_account_id_not_found"
        case .oauthAccountIdReadFailed:
            return "rumination_oauth_account_id_read_failed"
        case .cliUnsupported:
            return "rumination_profile_cli_unsupported"
        }
    }

    var expectedSafeMessage: String {
        switch self {
        case .profileNotFound:
            return "反刍所用运行配置不存在。"
        case .catalogUnavailable:
            return "反刍所用模型目录不可用。"
        case .modelUnsupported:
            return "反刍所用模型不受该运行配置支持。"
        case .credentialAccountMissing:
            return "反刍运行配置缺少凭据账户。"
        case .credentialNotFound:
            return "反刍所需凭据不存在。"
        case .credentialReadFailed:
            return "反刍所需凭据读取失败。"
        case .endpointInvalid:
            return "反刍运行配置的服务地址无效。"
        case .providerConstructionFailed:
            return "反刍服务初始化失败。"
        case .oauthAccountIdNotFound:
            return "反刍所需 OAuth 账户信息不存在。"
        case .oauthAccountIdReadFailed:
            return "反刍所需 OAuth 账户信息读取失败。"
        case .cliUnsupported:
            return "当前 CLI 运行配置不支持耐久反刍。"
        }
    }

    var usesOAuth: Bool {
        switch self {
        case .oauthAccountIdNotFound, .oauthAccountIdReadFailed:
            return true
        default:
            return false
        }
    }
}

private enum A2StrictResolverInjectedError: Error {
    case injected
}

private struct A2StrictProfileSource: PlanningRuntimeProfileSource {
    let scenario: A2StrictResolverScenario
    let profileId: String

    func planningRuntimeProfile(
        id: String
    ) throws -> RuntimeProfileRecord? {
        guard scenario != .profileNotFound, id == profileId else {
            return nil
        }
        let kind: RuntimeProfileKind
        if scenario == .cliUnsupported {
            kind = .cliCodex
        } else if scenario.usesOAuth {
            kind = .chatGPTOAuth
        } else {
            kind = .openAIAPI
        }
        let account: String?
        if scenario == .credentialAccountMissing {
            account = nil
        } else if scenario.usesOAuth {
            account = "oauth-access"
        } else {
            account = "api-access"
        }
        return RuntimeProfileRecord(
            id: profileId,
            kind: kind,
            name: "A2 strict resolver",
            baseURL: scenario == .endpointInvalid
                ? nil
                : "https://api.openai.com",
            credentialAccount: account,
            isDefault: false,
            createdAt: durableWorkTestNow
        )
    }
}

private struct A2StrictCatalogSource: PlanningModelCatalogSource {
    let scenario: A2StrictResolverScenario
    let model: String

    func planningCachedCatalog(profileId: String) throws -> [String]? {
        try catalog()
    }

    func planningModelChoices(profileId: String) throws -> [String]? {
        try catalog()
    }

    func planningManualModels(profileId: String) throws -> [String] {
        if scenario == .catalogUnavailable {
            throw A2StrictResolverInjectedError.injected
        }
        return []
    }

    private func catalog() throws -> [String] {
        if scenario == .catalogUnavailable {
            throw A2StrictResolverInjectedError.injected
        }
        if scenario == .modelUnsupported {
            return ["a2-different-model"]
        }
        return [model]
    }
}

private struct A2StrictCredentialSource: PlanningCredentialSource {
    let scenario: A2StrictResolverScenario

    func planningCredential(account: String) throws -> String? {
        if account == "oauth-chatgpt-account-id" {
            if scenario == .oauthAccountIdReadFailed {
                throw A2StrictResolverInjectedError.injected
            }
            if scenario == .oauthAccountIdNotFound {
                return nil
            }
            return "oauth-account-id"
        }
        if scenario == .credentialReadFailed {
            throw A2StrictResolverInjectedError.injected
        }
        if scenario == .credentialNotFound {
            return nil
        }
        return "a2-secret"
    }
}

private struct A2StrictProviderFactory: PlanningProviderFactory {
    let scenario: A2StrictResolverScenario
    let provider: any LLMProvider

    func makePlanningAPIProvider(
        format: ProviderAPIFormat,
        credential: String,
        model: String,
        baseURL: URL
    ) throws -> any LLMProvider {
        if scenario == .providerConstructionFailed {
            throw A2StrictResolverInjectedError.injected
        }
        return provider
    }

    func makePlanningOAuthProvider(
        accessToken: String,
        accountId: String,
        model: String
    ) throws -> any LLMProvider {
        if scenario == .providerConstructionFailed {
            throw A2StrictResolverInjectedError.injected
        }
        return provider
    }
}

private func a2StrictResolver(
    scenario: A2StrictResolverScenario,
    profileId: String,
    model: String,
    provider: any LLMProvider
) -> StrictPlanningProviderResolver {
    StrictPlanningProviderResolver(
        profiles: A2StrictProfileSource(
            scenario: scenario,
            profileId: profileId
        ),
        catalogs: A2StrictCatalogSource(
            scenario: scenario,
            model: model
        ),
        credentials: A2StrictCredentialSource(scenario: scenario),
        factory: A2StrictProviderFactory(
            scenario: scenario,
            provider: provider
        )
    )
}

private func enqueueA2PlanningWork(
    _ fixture: DurableWorkTestFixture,
    suffix: String,
    provider: any LLMProvider = MockProvider(script: [])
) throws -> (missionId: String, workId: String) {
    let campId = try #require(fixture.campId)
    let profileId = "a2-planning-profile-\(suffix)"
    _ = try seedTestPlanningProfile(
        fixture.database,
        profileId: profileId
    )
    var companion = CompanionRecord.new(
        name: "A2 planner \(suffix)",
        color: "blue",
        rolePrompt: "Plan one durable result",
        model: "a2-planning-model",
        kind: .regular,
        campId: campId
    )
    companion.runtimeProfileId = profileId
    try fixture.database.saveCompanion(companion)
    return try fixture.database.enqueueMissionPlanning(
        goal: "A2 planning \(suffix)",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: 1_000,
        campId: campId,
        autonomy: .standard,
        planningInput: PlanningWorkInput(
            plannerModel: "a2-planning-model",
            runtimeProfileId: profileId
        ),
        idempotencyKey: "a2-planning:\(suffix):v1",
        traceId: "a2-planning:\(suffix):trace:v1",
        planningProviderResolver:
            TestPlanningProviderResolver(provider: provider)
    )
}

private func durableAttemptCount(
    _ fixture: DurableWorkTestFixture,
    workId: String
) throws -> Int {
    try fixture.database.pool.read {
        try Int.fetchOne(
            $0,
            sql: "SELECT COUNT(*) FROM durable_work_attempt WHERE workId = ?",
            arguments: [workId]
        ) ?? 0
    }
}

private func durableEventCount(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    kind: String? = nil
) throws -> Int {
    try fixture.database.pool.read { database in
        if let kind {
            return try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM durable_work_attempt_event
                    WHERE workId = ? AND eventKind = ?
                    """,
                arguments: [workId, kind]
            ) ?? 0
        }
        return try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM durable_work_attempt_event
                WHERE workId = ?
                """,
            arguments: [workId]
        ) ?? 0
    }
}

private func durableWorkString(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    column: String
) throws -> String? {
    try fixture.database.pool.read {
        try String.fetchOne(
            $0,
            sql: "SELECT \(column) FROM durable_work WHERE id = ?",
            arguments: [workId]
        )
    }
}

private func durableWorkInt(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    column: String
) throws -> Int? {
    try fixture.database.pool.read {
        try Int.fetchOne(
            $0,
            sql: "SELECT \(column) FROM durable_work WHERE id = ?",
            arguments: [workId]
        )
    }
}

private func durableWorkDate(
    _ fixture: DurableWorkTestFixture,
    workId: String,
    column: String
) throws -> Date? {
    try fixture.database.pool.read {
        try Date.fetchOne(
            $0,
            sql: "SELECT \(column) FROM durable_work WHERE id = ?",
            arguments: [workId]
        )
    }
}

private func insertDurableBusinessProbe(
    _ database: Database,
    value: String
) throws {
    try database.execute(
        sql: """
            INSERT INTO durable_work_test_business_probe (value)
            VALUES (?)
            """,
        arguments: [value]
    )
}

private func expectDurableConstraintFailure(
    _ fixture: DurableWorkTestFixture,
    sql: String,
    arguments: StatementArguments = []
) {
    #expect(throws: DatabaseError.self) {
        try fixture.database.pool.write { database in
            try database.execute(sql: sql, arguments: arguments)
        }
    }
}

private enum DurableDiagnosticCode: CaseIterable, Sendable {
    case null
    case workerInterrupted
    case workCanceled
    case otherError

    var value: String? {
        switch self {
        case .null:
            return nil
        case .workerInterrupted:
            return "worker_interrupted"
        case .workCanceled:
            return "work_canceled"
        case .otherError:
            return "other_error"
        }
    }

    var label: String {
        value ?? "null"
    }
}

private enum DurableDiagnosticMessage: CaseIterable, Sendable {
    case null
    case present

    var value: String? {
        switch self {
        case .null:
            return nil
        case .present:
            return "safe message"
        }
    }

    var label: String {
        switch self {
        case .null:
            return "null"
        case .present:
            return "present"
        }
    }
}

private enum DurableDiagnosticWorkShape: String, CaseIterable, Sendable {
    case queued
    case running
    case retryScheduled
    case succeededWithoutOutput
    case succeededWithOutput
    case failed
    case canceled

    var state: String {
        switch self {
        case .queued:
            return "queued"
        case .running:
            return "running"
        case .retryScheduled:
            return "retryScheduled"
        case .succeededWithoutOutput, .succeededWithOutput:
            return "succeeded"
        case .failed:
            return "failed"
        case .canceled:
            return "canceled"
        }
    }

    var notBefore: Int? {
        self == .retryScheduled ? 1_000_060 : nil
    }

    var leaseOwner: String? {
        self == .running ? "diagnostic-worker" : nil
    }

    var leaseExpiresAt: Int? {
        self == .running ? 1_000_060 : nil
    }

    var outputJSON: String? {
        self == .succeededWithOutput ? "{}" : nil
    }

    var finishedAt: Int? {
        switch self {
        case .succeededWithoutOutput, .succeededWithOutput, .failed, .canceled:
            return 1_000_001
        case .queued, .running, .retryScheduled:
            return nil
        }
    }
}

private enum DurableDiagnosticAttemptShape: String, CaseIterable, Sendable {
    case open
    case succeeded
    case failed
    case canceled
    case interrupted

    var endedAt: Int? {
        self == .open ? nil : 1_000_001
    }

    var outcome: String? {
        self == .open ? nil : rawValue
    }

    var terminalWorkVersion: Int? {
        self == .open ? nil : 1
    }
}

private enum DurableDiagnosticEventKind: String, CaseIterable, Sendable {
    case claimed
    case leaseRenewed
    case succeeded
    case failed
    case canceled
    case interrupted

    var sequence: Int {
        self == .claimed ? 0 : 1
    }
}

private enum DurableDiagnosticEventState: String, CaseIterable, Sendable {
    case running
    case retryScheduled
    case succeeded
    case failed
    case canceled
    case queued
}

private enum DurableDiagnosticTable: Sendable {
    case work
    case attempt
    case event
}

private enum DurableDiagnosticCandidate: Sendable {
    case work(
        DurableDiagnosticWorkShape,
        DurableDiagnosticCode,
        DurableDiagnosticMessage
    )
    case attempt(
        DurableDiagnosticAttemptShape,
        DurableDiagnosticCode,
        DurableDiagnosticMessage
    )
    case event(
        DurableDiagnosticEventKind,
        DurableDiagnosticEventState,
        DurableDiagnosticCode,
        DurableDiagnosticMessage
    )

    var id: String {
        switch self {
        case let .work(shape, code, message):
            return "work|\(shape.rawValue)|\(code.label)|\(message.label)"
        case let .attempt(shape, code, message):
            return "attempt|\(shape.rawValue)|\(code.label)|\(message.label)"
        case let .event(kind, state, code, message):
            return """
                event|\(kind.rawValue)|\(state.rawValue)|\(code.label)|\
                \(message.label)
                """
        }
    }

    var table: DurableDiagnosticTable {
        switch self {
        case .work:
            return .work
        case .attempt:
            return .attempt
        case .event:
            return .event
        }
    }

    var expectedAccepted: Bool {
        switch self {
        case let .work(shape, code, message):
            switch shape {
            case .queued:
                return (code == .null && message == .null)
                    || (code == .workerInterrupted && message == .null)
            case .running, .succeededWithoutOutput, .succeededWithOutput:
                return code == .null && message == .null
            case .retryScheduled, .failed:
                return code != .null
            case .canceled:
                return code == .workCanceled && message == .present
            }
        case let .attempt(shape, code, message):
            switch shape {
            case .open, .succeeded:
                return code == .null && message == .null
            case .failed:
                return code != .null
            case .canceled:
                return code == .workCanceled && message == .present
            case .interrupted:
                return code == .workerInterrupted && message == .null
            }
        case let .event(kind, state, code, message):
            switch kind {
            case .claimed, .leaseRenewed:
                return state == .running
                    && code == .null
                    && message == .null
            case .succeeded:
                return state == .succeeded
                    && code == .null
                    && message == .null
            case .failed:
                return (state == .retryScheduled || state == .failed)
                    && code != .null
            case .canceled:
                return state == .canceled
                    && code == .workCanceled
                    && message == .present
            case .interrupted:
                return state == .queued
                    && code == .workerInterrupted
                    && message == .null
            }
        }
    }
}

private enum DurableDiagnosticVerdict: Equatable {
    case accepted
    case checkRejected
}

private struct DurableDiagnosticRowCounts: Equatable {
    let work: Int
    let attempt: Int
    let event: Int
}

private enum DurableDiagnosticCatalogError: Error {
    case duplicateCaseID(String)
    case insertedRowMissing(String)
}

private func makeDurableDiagnosticCatalog()
    -> [DurableDiagnosticCandidate]
{
    var catalog: [DurableDiagnosticCandidate] = []
    for shape in DurableDiagnosticWorkShape.allCases {
        for code in DurableDiagnosticCode.allCases {
            for message in DurableDiagnosticMessage.allCases {
                catalog.append(.work(shape, code, message))
            }
        }
    }
    for shape in DurableDiagnosticAttemptShape.allCases {
        for code in DurableDiagnosticCode.allCases {
            for message in DurableDiagnosticMessage.allCases {
                catalog.append(.attempt(shape, code, message))
            }
        }
    }
    for kind in DurableDiagnosticEventKind.allCases {
        for state in DurableDiagnosticEventState.allCases {
            for code in DurableDiagnosticCode.allCases {
                for message in DurableDiagnosticMessage.allCases {
                    catalog.append(.event(kind, state, code, message))
                }
            }
        }
    }
    return catalog
}

private func durableDiagnosticSentinelIDs() -> Set<String> {
    Set([
        DurableDiagnosticCandidate.work(
            .canceled,
            .null,
            .present
        ).id,
        DurableDiagnosticCandidate.attempt(
            .open,
            .otherError,
            .null
        ).id,
        DurableDiagnosticCandidate.attempt(
            .open,
            .null,
            .present
        ).id,
        DurableDiagnosticCandidate.attempt(
            .canceled,
            .null,
            .present
        ).id,
        DurableDiagnosticCandidate.attempt(
            .interrupted,
            .null,
            .null
        ).id,
        DurableDiagnosticCandidate.event(
            .canceled,
            .canceled,
            .null,
            .present
        ).id,
        DurableDiagnosticCandidate.event(
            .interrupted,
            .queued,
            .null,
            .null
        ).id,
    ])
}

private func durableDiagnosticControlIDs() -> Set<String> {
    Set([
        DurableDiagnosticCandidate.work(.queued, .null, .null).id,
        DurableDiagnosticCandidate.work(
            .queued,
            .workerInterrupted,
            .null
        ).id,
        DurableDiagnosticCandidate.work(.running, .null, .null).id,
        DurableDiagnosticCandidate.work(
            .retryScheduled,
            .otherError,
            .present
        ).id,
        DurableDiagnosticCandidate.work(
            .succeededWithOutput,
            .null,
            .null
        ).id,
        DurableDiagnosticCandidate.work(
            .failed,
            .otherError,
            .present
        ).id,
        DurableDiagnosticCandidate.work(
            .canceled,
            .workCanceled,
            .present
        ).id,
        DurableDiagnosticCandidate.attempt(.open, .null, .null).id,
        DurableDiagnosticCandidate.attempt(.succeeded, .null, .null).id,
        DurableDiagnosticCandidate.attempt(
            .failed,
            .otherError,
            .present
        ).id,
        DurableDiagnosticCandidate.attempt(
            .canceled,
            .workCanceled,
            .present
        ).id,
        DurableDiagnosticCandidate.attempt(
            .interrupted,
            .workerInterrupted,
            .null
        ).id,
        DurableDiagnosticCandidate.event(
            .claimed,
            .running,
            .null,
            .null
        ).id,
        DurableDiagnosticCandidate.event(
            .leaseRenewed,
            .running,
            .null,
            .null
        ).id,
        DurableDiagnosticCandidate.event(
            .succeeded,
            .succeeded,
            .null,
            .null
        ).id,
        DurableDiagnosticCandidate.event(
            .failed,
            .retryScheduled,
            .otherError,
            .present
        ).id,
        DurableDiagnosticCandidate.event(
            .failed,
            .failed,
            .otherError,
            .present
        ).id,
        DurableDiagnosticCandidate.event(
            .canceled,
            .canceled,
            .workCanceled,
            .present
        ).id,
        DurableDiagnosticCandidate.event(
            .interrupted,
            .queued,
            .workerInterrupted,
            .null
        ).id,
    ])
}

private func insertDurableDiagnosticWork(
    _ database: Database,
    id: String,
    campID: String,
    shape: DurableDiagnosticWorkShape,
    code: DurableDiagnosticCode,
    message: DurableDiagnosticMessage
) throws {
    let values: [(any DatabaseValueConvertible)?] = [
        id,
        campID,
        id,
        id,
        shape.state,
        shape.notBefore,
        shape.leaseOwner,
        shape.leaseExpiresAt,
        String(repeating: "a", count: 64),
        shape.outputJSON,
        code.value,
        message.value,
        "trace-\(id)",
        shape.finishedAt,
    ]
    try database.execute(
        sql: """
            INSERT INTO durable_work (
              id, campId, campLifecycleVersion, kind, aggregateType,
              aggregateId, idempotencyKey,
              state, attempt, maxAttempts, notBefore, leaseOwner,
              leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
              errorMessage, traceId, version, createdAt, updatedAt, finishedAt
            ) VALUES (
              ?, ?, 1, 'planning', 'diagnostic', ?, ?, ?, 1, 4, ?, ?, ?,
              '{}', ?, ?, ?, ?, ?, 1, 1000000, 1000000, ?
            )
            """,
        arguments: StatementArguments(values)
    )
}

private func insertDurableDiagnosticHarness(
    _ database: Database,
    campID: String
) throws {
    try insertDurableDiagnosticWork(
        database,
        id: "diagnostic-attempt-parent",
        campID: campID,
        shape: .running,
        code: .null,
        message: .null
    )
    try insertDurableDiagnosticWork(
        database,
        id: "diagnostic-event-parent",
        campID: campID,
        shape: .running,
        code: .null,
        message: .null
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt (
              workId, attempt, id, workerId, startedAt, endedAt, outcome,
              errorCode, errorMessage, traceId, terminalWorkVersion
            ) VALUES (
              'diagnostic-event-parent', 1, 'diagnostic-event-parent-attempt',
              'diagnostic-worker', 1000000, NULL, NULL, NULL, NULL,
              'diagnostic-event-parent-trace', NULL
            )
            """
    )
}

private func insertDurableDiagnosticCandidate(
    _ candidate: DurableDiagnosticCandidate,
    database: Database,
    campID: String
) throws {
    switch candidate {
    case let .work(shape, code, message):
        try insertDurableDiagnosticWork(
            database,
            id: candidate.id,
            campID: campID,
            shape: shape,
            code: code,
            message: message
        )
    case let .attempt(shape, code, message):
        let values: [(any DatabaseValueConvertible)?] = [
            candidate.id,
            shape.endedAt,
            shape.outcome,
            code.value,
            message.value,
            shape.terminalWorkVersion,
        ]
        try database.execute(
            sql: """
                INSERT INTO durable_work_attempt (
                  workId, attempt, id, workerId, startedAt, endedAt, outcome,
                  errorCode, errorMessage, traceId, terminalWorkVersion
                ) VALUES (
                  'diagnostic-attempt-parent', 1, ?, 'diagnostic-worker',
                  1000000, ?, ?, ?, ?, 'diagnostic-attempt-trace', ?
                )
                """,
            arguments: StatementArguments(values)
        )
    case let .event(kind, state, code, message):
        let values: [(any DatabaseValueConvertible)?] = [
            candidate.id,
            kind.sequence,
            kind.rawValue,
            state.rawValue,
            code.value,
            message.value,
        ]
        try database.execute(
            sql: """
                INSERT INTO durable_work_attempt_event (
                  id, workId, attempt, sequence, eventKind, workerId,
                  workVersion, resultingWorkState, errorCode, errorMessage,
                  occurredAt
                ) VALUES (
                  ?, 'diagnostic-event-parent', 1, ?, ?, 'diagnostic-worker',
                  1, ?, ?, ?, 1000001
                )
                """,
            arguments: StatementArguments(values)
        )
    }
}

private func requireDurableDiagnosticCandidateWasInserted(
    _ candidate: DurableDiagnosticCandidate,
    database: Database
) throws {
    let count: Int
    switch candidate {
    case .work:
        count = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM durable_work WHERE id = ?",
            arguments: [candidate.id]
        ) ?? 0
    case .attempt:
        count = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt WHERE id = ?",
            arguments: [candidate.id]
        ) ?? 0
    case .event:
        count = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt_event WHERE id = ?",
            arguments: [candidate.id]
        ) ?? 0
    }
    guard count == 1 else {
        throw DurableDiagnosticCatalogError.insertedRowMissing(candidate.id)
    }
}

private func evaluateDurableDiagnosticCandidate(
    _ candidate: DurableDiagnosticCandidate,
    database: Database,
    campID: String
) throws -> DurableDiagnosticVerdict {
    do {
        try database.inSavepoint {
            try insertDurableDiagnosticCandidate(
                candidate,
                database: database,
                campID: campID
            )
            try requireDurableDiagnosticCandidateWasInserted(
                candidate,
                database: database
            )
            return .rollback
        }
        return .accepted
    } catch let error as DatabaseError {
        guard error.extendedResultCode == .SQLITE_CONSTRAINT_CHECK else {
            throw error
        }
        return .checkRejected
    }
}

private func durableDiagnosticRowCounts(
    _ database: Database
) throws -> DurableDiagnosticRowCounts {
    DurableDiagnosticRowCounts(
        work: try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM durable_work"
        ) ?? 0,
        attempt: try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt"
        ) ?? 0,
        event: try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt_event"
        ) ?? 0
    )
}

@Test func sameIdempotencyAndPayloadReplaysButDifferentPayloadConflicts() throws {
    let fixture = try makeDurableWorkFixture()
    let aggregateId = "mission-replay"
    let idempotencyKey = "planning-replay"
    let first = try enqueueDurableWork(
        fixture,
        aggregateId: aggregateId,
        idempotencyKey: idempotencyKey
    )
    #expect(first.disposition == .inserted)

    let replay = try enqueueDurableWork(
        fixture,
        aggregateId: aggregateId,
        idempotencyKey: idempotencyKey
    )
    #expect(replay.disposition == .replayed)
    #expect(replay.work == first.work)
    #expect(try durableWorkCount(fixture) == 1)

    let changed = #"{"value":2}"#
    #expect(throws: DurableWorkReplayConflictError.self) {
        try enqueueDurableWork(
            fixture,
            aggregateId: aggregateId,
            inputJson: changed,
            claimedInputHash: durableInputHash(changed),
            idempotencyKey: idempotencyKey
        )
    }
    #expect(try durableWorkCount(fixture) == 1)
}

@Test func enqueueMissingCampThrowsRecordNotFoundAndWritesNothing() throws {
    let fixture = try makeDurableWorkFixture(createCamp: false)
    #expect(
        throws: RecordNotFoundError(
            table: "camp",
            id: "missing-camp"
        )
    ) {
        try enqueueDurableWork(fixture, campId: "missing-camp")
    }
    #expect(try durableWorkCount(fixture) == 0)
}

@Test func enqueueArchivedCampThrowsCampArchivedAndWritesNothing() throws {
    let fixture = try makeDurableWorkFixture(archived: true)
    let campId = try #require(fixture.campId)
    #expect(throws: CampArchivedError(campId: campId)) {
        try enqueueDurableWork(fixture)
    }
    #expect(try durableWorkCount(fixture) == 0)
}

@Test func enqueueReplayAfterArchiveIsRejected() throws {
    let fixture = try makeDurableWorkFixture()
    let idempotencyKey = "archive-replay"
    let aggregateId = "mission-archive"
    _ = try enqueueDurableWork(
        fixture,
        aggregateId: aggregateId,
        idempotencyKey: idempotencyKey
    )
    let campId = try #require(fixture.campId)
    try fixture.database.setCampArchived(id: campId, archived: true)

    #expect(throws: CampArchivedError(campId: campId)) {
        try enqueueDurableWork(
            fixture,
            aggregateId: aggregateId,
            idempotencyKey: idempotencyKey
        )
    }
    #expect(try durableWorkCount(fixture) == 1)
}

@Test func genericPlanningKindAPIsRejectBeforeSQL() throws {
    let fixture = try makeDurableWorkFixture()
    try fixture.database.pool.write { database in
        try database.execute(sql: "DROP TABLE durable_work_attempt_event")
        try database.execute(sql: "DROP TABLE durable_work_attempt")
        try database.execute(sql: "DROP TABLE durable_work")
    }

    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.enqueue(
            campId: "missing-camp",
            kind: .planning,
            aggregateType: "mission",
            aggregateId: "planning",
            inputJson: "not canonical JSON",
            claimedInputHash: "not-a-hash",
            idempotencyKey: "planning",
            maxAttempts: 0,
            traceId: "trace",
            now: Date(timeIntervalSinceReferenceDate: .nan)
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.planning],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: 10
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.nextClaimableDate(
            kinds: [.planning],
            now: durableWorkTestNow
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.cancelActive(
            kind: .planning,
            aggregateType: "mission",
            aggregateId: "planning",
            reason: "",
            now: Date(timeIntervalSinceReferenceDate: .nan)
        ) { _, _ in }
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.adoptInterrupted(
            kinds: [.planning],
            currentWorkerId: "worker",
            now: durableWorkTestNow
        )
    }
}

@Test func genericReservedKindOrderingUsesCallerOrderBeforeDeduplication() throws {
    let fixture = try makeDurableWorkFixture()
    try fixture.database.pool.write { database in
        try database.execute(sql: "DROP TABLE durable_work_attempt_event")
        try database.execute(sql: "DROP TABLE durable_work_attempt")
        try database.execute(sql: "DROP TABLE durable_work")
    }

    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.planning, .campDeletion],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: 10
        )
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.campDeletion, .planning],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: 10
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.nextClaimableDate(
            kinds: [.planning, .campDeletion],
            now: durableWorkTestNow
        )
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.nextClaimableDate(
            kinds: [.campDeletion, .planning],
            now: durableWorkTestNow
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.adoptInterrupted(
            kinds: [.planning, .campDeletion],
            currentWorkerId: "worker",
            now: durableWorkTestNow
        )
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.adoptInterrupted(
            kinds: [.campDeletion, .planning],
            currentWorkerId: "worker",
            now: durableWorkTestNow
        )
    }

    let invalidNow = Date(timeIntervalSinceReferenceDate: .nan)
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.claimNext(
            kinds: [.planning],
            workerId: "worker",
            now: invalidNow,
            leaseDuration: 10
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonPositiveLeaseDuration) {
        try fixture.store.claimNext(
            kinds: [.planning],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: 0
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.nextClaimableDate(
            kinds: [.planning],
            now: invalidNow
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.adoptInterrupted(
            kinds: [.planning],
            currentWorkerId: "worker",
            now: invalidNow
        )
    }
}

@Test func genericPlanningTargetAPIsRejectBeforeMutationAndClosures() throws {
    let fixture = try makeDurableWorkFixture()
    let enqueued = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE durable_work SET kind = 'planning' WHERE id = ?",
            arguments: [enqueued.work.id]
        )
    }
    let baseline = try durableLedgerSnapshot(fixture)

    #expect(throws: InvalidDurableWorkTimeError.nonPositiveLeaseDuration) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow,
            leaseDuration: 0
        )
    }
    #expect(throws: InvalidDurableWorkOutputJSONError.rootMustBeObject) {
        try fixture.store.complete(
            claim: claim,
            outputJson: "[]",
            now: durableWorkTestNow
        ) { _, _ in }
    }
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try transientDurableFailure(),
            now: Date(timeIntervalSinceReferenceDate: .nan)
        ) { _, _ in }
    }
    #expect(throws: InvalidDurableWorkCancellationReasonError.empty) {
        try fixture.store.cancel(
            workId: claim.workId,
            expectedVersion: claim.version,
            reason: "",
            now: durableWorkTestNow
        ) { _, _ in }
    }

    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow.addingTimeInterval(1),
            leaseDuration: 60
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.complete(
            claim: claim,
            outputJson: nil,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(
                database,
                value: "planning-complete"
            )
        }
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try transientDurableFailure(),
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(
                database,
                value: "planning-failure"
            )
        }
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.cancel(
            workId: claim.workId,
            expectedVersion: claim.version,
            reason: "Cancel planning",
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(
                database,
                value: "planning-cancel"
            )
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == baseline)

    let terminal = try enqueueDurableWork(
        fixture,
        aggregateId: "terminal-planning"
    ).work
    try fixture.database.pool.write { database in
        try database.execute(
            sql: """
                UPDATE durable_work
                SET kind = 'planning',
                    state = 'canceled',
                    errorCode = 'work_canceled',
                    errorMessage = 'Already canceled',
                    finishedAt = ?,
                    updatedAt = ?
                WHERE id = ?
                """,
            arguments: [
                durableWorkTestNow,
                durableWorkTestNow,
                terminal.id,
            ]
        )
    }
    let terminalBaseline = try durableLedgerSnapshot(fixture)
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.cancel(
            workId: terminal.id,
            expectedVersion: terminal.version,
            reason: "Already canceled",
            now: durableWorkTestNow
        ) { database, _ in
            try insertDurableBusinessProbe(
                database,
                value: "terminal-planning-cancel"
            )
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == terminalBaseline)
}

@Test func genericPlanningReadSeamsRemainAvailable() throws {
    let fixture = try makeDurableWorkFixture()
    let enqueued = try enqueueDurableWork(
        fixture,
        aggregateId: "planning-read"
    ).work
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE durable_work SET kind = 'planning' WHERE id = ?",
            arguments: [enqueued.id]
        )
    }

    let byID = try #require(try fixture.store.work(id: enqueued.id))
    #expect(byID.kind == .planning)
    #expect(try fixture.store.activeWork(
        kind: .planning,
        aggregateType: enqueued.aggregateType,
        aggregateId: enqueued.aggregateId
    ) == byID)
    #expect(try fixture.store.latestWork(
        kind: .planning,
        aggregateType: enqueued.aggregateType,
        aggregateId: enqueued.aggregateId
    ) == byID)
    #expect(try fixture.store.work(id: "missing-work") == nil)
}

@Test func genericEnqueueClaimScheduleAndAdoptRejectCampDeletionBeforeSQL() throws {
    let fixture = try makeDurableWorkFixture()
    try fixture.database.pool.write { database in
        try database.execute(sql: "DROP TABLE durable_work_attempt_event")
        try database.execute(sql: "DROP TABLE durable_work_attempt")
        try database.execute(sql: "DROP TABLE durable_work")
    }

    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try enqueueDurableWork(fixture, kind: .campDeletion)
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.coach, .campDeletion],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: 10
        )
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.nextClaimableDate(
            kinds: [.campDeletion],
            now: durableWorkTestNow
        )
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.cancelActive(
            kind: .campDeletion,
            aggregateType: "camp",
            aggregateId: "camp",
            reason: "User requested retirement",
            now: durableWorkTestNow
        ) { _, _ in }
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.adoptInterrupted(
            kinds: [.campDeletion],
            currentWorkerId: "worker",
            now: durableWorkTestNow
        )
    }
}

@Test func genericClaimScopedAndCancelCommandsRejectExistingCampDeletionBeforeMutation() throws {
    let fixture = try makeDurableWorkFixture()
    let enqueued = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    try fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE durable_work SET kind = 'campDeletion' WHERE id = ?",
            arguments: [enqueued.work.id]
        )
    }
    let before = try durableLedgerSnapshot(fixture)

    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow.addingTimeInterval(1),
            leaseDuration: 60
        )
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.complete(
            claim: claim,
            outputJson: nil,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(database, value: "complete")
        }
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try transientDurableFailure(),
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(database, value: "failure")
        }
    }
    #expect(throws: CampDeletionRequiresRetirementCapabilityError.self) {
        try fixture.store.cancel(
            workId: claim.workId,
            expectedVersion: claim.version,
            reason: "Cancel",
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(database, value: "cancel")
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func enqueueRejectsUppercaseOrNonHexClaimedInputHash() throws {
    let fixture = try makeDurableWorkFixture()
    let valid = durableInputHash(durableWorkCanonicalInput)
    let invalidHashes = [
        valid.uppercased(),
        String(repeating: "g", count: 64),
        String(repeating: "a", count: 63),
        String(repeating: "a", count: 65),
    ]
    for invalid in invalidHashes {
        #expect(throws: DurableWorkInputHashMismatchError.self) {
            try enqueueDurableWork(
                fixture,
                aggregateId: UUID().uuidString,
                claimedInputHash: invalid
            )
        }
    }
    #expect(try durableWorkCount(fixture) == 0)
}

@Test func enqueueRejectsNonCanonicalJSONBeforeDatabaseWrite() throws {
    let fixture = try makeDurableWorkFixture()
    let invalidInputs = [
        #" {"value":1}"#,
        #"{"value":1.0}"#,
        #"{"value":1,"slash":"a\/b"}"#,
        #"[]"#,
        #"{"#,
    ]
    for input in invalidInputs {
        #expect(throws: DurableWorkInvalidCanonicalJSONError.self) {
            try enqueueDurableWork(
                fixture,
                aggregateId: UUID().uuidString,
                inputJson: input,
                claimedInputHash: durableInputHash(input)
            )
        }
    }
    #expect(try durableWorkCount(fixture) == 0)
}

@Test func sameClaimedHashWithDifferentPayloadIsRecomputedAndRejected() throws {
    let fixture = try makeDurableWorkFixture()
    let firstInput = #"{"value":1}"#
    let secondInput = #"{"value":2}"#
    let firstHash = durableInputHash(firstInput)
    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "mission-hash",
        inputJson: firstInput,
        claimedInputHash: firstHash,
        idempotencyKey: "hash-key"
    )

    #expect(throws: DurableWorkInputHashMismatchError.self) {
        try enqueueDurableWork(
            fixture,
            aggregateId: "mission-hash",
            inputJson: secondInput,
            claimedInputHash: firstHash,
            idempotencyKey: "hash-key"
        )
    }
    #expect(try durableWorkCount(fixture) == 1)
}

@Test func completeAcceptsNilOrCanonicalObjectOutput() throws {
    let fixture = try makeDurableWorkFixture()
    let nilWork = try enqueueDurableWork(
        fixture,
        aggregateId: "mission-output-nil"
    ).work
    let nilClaim = try claimDurableWork(fixture)
    let nilResult = try fixture.store.complete(
        claim: nilClaim,
        outputJson: nil,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }
    #expect(nilResult.id == nilWork.id)
    #expect(nilResult.state == .succeeded)
    #expect(nilResult.outputJson == nil)

    let outputWork = try enqueueDurableWork(
        fixture,
        aggregateId: "mission-output-object"
    ).work
    let outputClaim = try claimDurableWork(fixture)
    let output = #"{"answer":42}"#
    let outputResult = try fixture.store.complete(
        claim: outputClaim,
        outputJson: output,
        now: durableWorkTestNow.addingTimeInterval(2)
    ) { _, _ in }
    #expect(outputResult.id == outputWork.id)
    #expect(outputResult.state == .succeeded)
    #expect(outputResult.outputJson == output)
}

@Test func completeRejectsInvalidNonObjectOrAlternateOutputBeforeWrite() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    let before = try durableLedgerSnapshot(fixture)

    #expect(throws: InvalidDurableWorkOutputJSONError.invalidJSON) {
        try fixture.store.complete(
            claim: claim,
            outputJson: "{",
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { _, _ in }
    }
    #expect(throws: InvalidDurableWorkOutputJSONError.rootMustBeObject) {
        try fixture.store.complete(
            claim: claim,
            outputJson: "[]",
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { _, _ in }
    }
    #expect(throws: InvalidDurableWorkOutputJSONError.notCanonical) {
        try fixture.store.complete(
            claim: claim,
            outputJson: #"{ "answer":42}"#,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { _, _ in }
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func invalidCompleteOutputSkipsBusinessMutationAndLeavesAttemptRunning() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    let before = try durableLedgerSnapshot(fixture)

    #expect(throws: InvalidDurableWorkOutputJSONError.notCanonical) {
        try fixture.store.complete(
            claim: claim,
            outputJson: #"{"answer":42.0}"#,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(database, value: "must-not-run")
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
    #expect(try durableWorkString(fixture, workId: work.id, column: "state") == "running")
    #expect(try durableWorkString(
        fixture,
        workId: work.id,
        column: "leaseOwner"
    ) == claim.workerId)
}

@Test func completeBusinessMutationFailureRollsBackValidatedOutputAndTerminalRows() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    let before = try durableLedgerSnapshot(fixture)

    #expect(throws: DurableWorkInjectedFailure.businessMutation) {
        try fixture.store.complete(
            claim: claim,
            outputJson: #"{"answer":42}"#,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(database, value: "rolled-back")
            throw DurableWorkInjectedFailure.businessMutation
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func failureDispositionRawValuesAndCodableRoundTripAreStable() throws {
    #expect(DurableWorkFailureDisposition.transient.rawValue == "transient")
    #expect(
        DurableWorkFailureDisposition.deterministic.rawValue
            == "deterministic"
    )

    for failure in [
        try transientDurableFailure(),
        try deterministicDurableFailure(),
    ] {
        let encoded = try JSONEncoder().encode(failure)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(Set(object.keys) == [
            "code", "message", "disposition", "usageJson",
        ])
        let decoded = try JSONDecoder().decode(
            DurableWorkFailure.self,
            from: encoded
        )
        #expect(decoded == failure)
    }

    let nilOptionals = try DurableWorkFailure(
        code: "no_usage",
        message: nil,
        disposition: .deterministic,
        usageJson: nil
    )
    let nilObject = try #require(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(nilOptionals)
        ) as? [String: Any]
    )
    #expect(nilObject["message"] is NSNull)
    #expect(nilObject["usageJson"] is NSNull)
}

@Test func failureInitializerAcceptsNilOrExactCanonicalUsage() throws {
    let withoutUsage = try DurableWorkFailure(
        code: "timeout",
        message: nil,
        disposition: .transient,
        usageJson: nil
    )
    #expect(withoutUsage.usageJson == nil)

    let withUsage = try DurableWorkFailure(
        code: "timeout",
        message: "Safe summary",
        disposition: .transient,
        usageJson: durableWorkCanonicalUsage
    )
    #expect(withUsage.usageJson == durableWorkCanonicalUsage)

    let maximumUsage =
        #"{"cacheReadTokens":9223372036854775807,"inputTokens":9223372036854775807,"outputTokens":9223372036854775807}"#
    #expect(try DurableWorkFailure(
        code: "max_usage",
        message: "Maximum",
        disposition: .deterministic,
        usageJson: maximumUsage
    ).usageJson == maximumUsage)
}

@Test func failureInitializerRejectsInvalidCodeMessageAndUsageSchema() throws {
    let invalidCodes = [
        "", "Upper", "1starts_digit", "has-dash",
        String(repeating: "a", count: 65),
    ]
    for code in invalidCodes {
        #expect(throws: InvalidDurableWorkFailureError.invalidCode) {
            try DurableWorkFailure(
                code: code,
                message: nil,
                disposition: .deterministic,
                usageJson: nil
            )
        }
    }

    #expect(throws: InvalidDurableWorkFailureError.emptyMessage) {
        try DurableWorkFailure(
            code: "error",
            message: "",
            disposition: .deterministic,
            usageJson: nil
        )
    }
    #expect(throws: InvalidDurableWorkFailureError.messageTooLong) {
        try DurableWorkFailure(
            code: "error",
            message: String(repeating: "🙂", count: 1_001),
            disposition: .deterministic,
            usageJson: nil
        )
    }
    for message in ["line\nbreak", "c1\u{0085}control"] {
        #expect(
            throws:
                InvalidDurableWorkFailureError.messageContainsControlScalar
        ) {
            try DurableWorkFailure(
                code: "error",
                message: message,
                disposition: .deterministic,
                usageJson: nil
            )
        }
    }

    let invalidUsage = [
        #"{"cacheReadTokens":0,"inputTokens":0}"#,
        #"{"cacheReadTokens":0,"extra":0,"inputTokens":0,"outputTokens":0}"#,
        #"{"cacheReadTokens":-1,"inputTokens":0,"outputTokens":0}"#,
        #"{"cacheReadTokens":0,"inputTokens":"0","outputTokens":0}"#,
        #"{"cacheReadTokens":0,"inputTokens":0,"outputTokens":9223372036854775808}"#,
        #"{ "cacheReadTokens":0,"inputTokens":0,"outputTokens":0}"#,
        #"[]"#,
    ]
    for usage in invalidUsage {
        #expect(throws: InvalidDurableWorkFailureError.invalidUsageJson) {
            try DurableWorkFailure(
                code: "error",
                message: nil,
                disposition: .deterministic,
                usageJson: usage
            )
        }
    }
}

@Test func failureDecoderRevalidatesAndCannotBypassInitializer() throws {
    let decoder = JSONDecoder()
    let explicitNull = Data(
        #"{"code":"safe","message":null,"disposition":"deterministic","usageJson":null}"#.utf8
    )
    let decoded = try decoder.decode(
        DurableWorkFailure.self,
        from: explicitNull
    )
    #expect(decoded.message == nil)
    #expect(decoded.usageJson == nil)

    let invalidShapes = [
        #"{"code":"safe","disposition":"deterministic","usageJson":null}"#,
        #"{"code":"safe","message":null,"disposition":"deterministic"}"#,
        #"{"code":"safe","message":null,"disposition":"deterministic","usageJson":null,"extra":0}"#,
        #"{"code":"Upper","message":null,"disposition":"deterministic","usageJson":null}"#,
        #"{"code":"safe","message":"","disposition":"deterministic","usageJson":null}"#,
        #"{"code":"safe","message":null,"disposition":"deterministic","usageJson":"{}"}"#,
    ]
    for json in invalidShapes {
        do {
            _ = try decoder.decode(
                DurableWorkFailure.self,
                from: Data(json.utf8)
            )
            Issue.record("Invalid DurableWorkFailure decoded: \(json)")
        } catch DecodingError.dataCorrupted {
            // Required typed failure: public decoding cannot bypass validation.
        } catch {
            Issue.record("Expected dataCorrupted, got \(error)")
        }
    }
}

@Test func retryOrFailUsesDispositionOnlyEvenWhenCodeIsIdentical() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "transient-same-code"
    )
    let transientClaim = try claimDurableWork(fixture)
    let transient = try DurableWorkFailure(
        code: "same_code",
        message: "Same safe message",
        disposition: .transient,
        usageJson: nil
    )
    let transientResolution = try fixture.store.retryOrFail(
        claim: transientClaim,
        failure: transient,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in
        Issue.record("Transient retry must not run terminal mutation")
    }
    guard case let .retryScheduled(transientWork, notBefore) =
        transientResolution
    else {
        Issue.record("Expected retryScheduled")
        return
    }
    #expect(transientWork.state == .retryScheduled)
    #expect(notBefore == durableWorkTestNow.addingTimeInterval(6))

    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "deterministic-same-code"
    )
    let deterministicClaim = try claimDurableWork(
        fixture,
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    let deterministic = try DurableWorkFailure(
        code: "same_code",
        message: "Same safe message",
        disposition: .deterministic,
        usageJson: nil
    )
    let deterministicResolution = try fixture.store.retryOrFail(
        claim: deterministicClaim,
        failure: deterministic,
        now: durableWorkTestNow.addingTimeInterval(3)
    ) { _, _ in }
    guard case let .failed(deterministicWork) = deterministicResolution else {
        Issue.record("Expected failed")
        return
    }
    #expect(deterministicWork.state == .failed)
}

@Test func oneAggregateKindHasOneActiveWorkButKeepsTerminalHistory() throws {
    let fixture = try makeDurableWorkFixture()
    let aggregateId = "single-active"
    let first = try enqueueDurableWork(
        fixture,
        aggregateId: aggregateId,
        idempotencyKey: "single-active-1"
    ).work

    #expect(throws: DatabaseError.self) {
        try enqueueDurableWork(
            fixture,
            aggregateId: aggregateId,
            idempotencyKey: "single-active-2"
        )
    }

    let claim = try claimDurableWork(fixture)
    _ = try fixture.store.complete(
        claim: claim,
        outputJson: nil,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }
    let second = try enqueueDurableWork(
        fixture,
        aggregateId: aggregateId,
        idempotencyKey: "single-active-2",
        now: durableWorkTestNow.addingTimeInterval(2)
    ).work

    #expect(try fixture.store.activeWork(
        kind: .coach,
        aggregateType: "mission",
        aggregateId: aggregateId
    )?.id == second.id)
    #expect(try fixture.store.latestWork(
        kind: .coach,
        aggregateType: "mission",
        aggregateId: aggregateId
    )?.id == second.id)
    #expect(
        try fixture.database.pool.read {
            try Int.fetchOne(
                $0,
                sql: """
                    SELECT COUNT(*) FROM durable_work
                    WHERE kind = 'coach'
                      AND aggregateType = 'mission'
                      AND aggregateId = ?
                    """,
                arguments: [aggregateId]
            )
        } == 2
    )
    #expect(first.id != second.id)
}

@Test func claimQueuedAndDueRetryAreSingleOwner() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let firstClaim = try claimDurableWork(
        fixture,
        workerId: "owner-one"
    )
    #expect(firstClaim.workId == work.id)
    #expect(firstClaim.workerId == "owner-one")
    #expect(try fixture.store.claimNext(
        kinds: [.coach],
        workerId: "owner-two",
        now: durableWorkTestNow,
        leaseDuration: 60
    ) == nil)

    let retry = try fixture.store.retryOrFail(
        claim: firstClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow
    ) { _, _ in }
    guard case let .retryScheduled(_, due) = retry else {
        Issue.record("Expected retry")
        return
    }
    #expect(try fixture.store.claimNext(
        kinds: [.coach],
        workerId: "too-early",
        now: due.addingTimeInterval(-0.001),
        leaseDuration: 60
    ) == nil)

    let secondClaim = try claimDurableWork(
        fixture,
        workerId: "owner-two",
        now: due
    )
    #expect(secondClaim.workId == work.id)
    #expect(secondClaim.workerId == "owner-two")
    #expect(secondClaim.attempt == firstClaim.attempt + 1)
    #expect(try fixture.store.claimNext(
        kinds: [.coach],
        workerId: "owner-three",
        now: due,
        leaseDuration: 60
    ) == nil)
}

@Test func queuedAndRetryCancellationDoNotRequireLeaseOwner() throws {
    let fixture = try makeDurableWorkFixture()
    let queued = try enqueueDurableWork(
        fixture,
        aggregateId: "cancel-queued"
    ).work
    let queuedResult = try fixture.store.cancel(
        workId: queued.id,
        expectedVersion: queued.version,
        reason: "No longer needed",
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }
    guard case let .canceled(canceledQueued) = queuedResult else {
        Issue.record("Expected queued cancellation")
        return
    }
    #expect(canceledQueued.state == .canceled)
    #expect(try durableAttemptCount(fixture, workId: queued.id) == 0)
    #expect(try durableEventCount(fixture, workId: queued.id) == 0)

    let retryWork = try enqueueDurableWork(
        fixture,
        aggregateId: "cancel-retry"
    ).work
    let retryClaim = try claimDurableWork(fixture)
    let retryResolution = try fixture.store.retryOrFail(
        claim: retryClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(2)
    ) { _, _ in }
    guard case let .retryScheduled(retryScheduled, _) = retryResolution else {
        Issue.record("Expected retryScheduled")
        return
    }
    let attemptsBefore = try durableAttemptCount(
        fixture,
        workId: retryWork.id
    )
    let eventsBefore = try durableEventCount(fixture, workId: retryWork.id)
    let retryCancel = try fixture.store.cancel(
        workId: retryWork.id,
        expectedVersion: retryScheduled.version,
        reason: "User changed direction",
        now: durableWorkTestNow.addingTimeInterval(3)
    ) { _, _ in }
    guard case let .canceled(canceledRetry) = retryCancel else {
        Issue.record("Expected retry cancellation")
        return
    }
    #expect(canceledRetry.state == .canceled)
    #expect(
        try durableAttemptCount(fixture, workId: retryWork.id)
            == attemptsBefore
    )
    #expect(
        try durableEventCount(fixture, workId: retryWork.id)
            == eventsBefore
    )
    #expect(
        try durableEventCount(
            fixture,
            workId: retryWork.id,
            kind: "canceled"
        ) == 0
    )
}

@Test func runningCancellationCommitsProjectionAndAttemptAtomically() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    let result = try fixture.store.cancel(
        workId: work.id,
        expectedVersion: claim.version,
        reason: "Stop this work",
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { database, resultingWork in
        #expect(resultingWork.state == .canceled)
        try insertDurableBusinessProbe(database, value: "canceled")
    }
    guard case let .canceled(canceled) = result else {
        Issue.record("Expected canceled")
        return
    }
    #expect(canceled.state == .canceled)
    #expect(try durableWorkString(
        fixture,
        workId: work.id,
        column: "errorCode"
    ) == "work_canceled")
    #expect(try durableWorkString(
        fixture,
        workId: work.id,
        column: "errorMessage"
    ) == "Stop this work")
    #expect(
        try durableEventCount(
            fixture,
            workId: work.id,
            kind: "canceled"
        ) == 1
    )
    #expect(
        try fixture.database.pool.read {
            try String.fetchOne(
                $0,
                sql: """
                    SELECT outcome FROM durable_work_attempt
                    WHERE workId = ? AND attempt = ?
                    """,
                arguments: [work.id, claim.attempt]
            )
        } == "canceled"
    )
    #expect(try durableLedgerSnapshot(fixture).businessProbe == ["canceled"])
}

@Test func cancelActiveNoRowIsIdempotentAndSkipsMutation() throws {
    let fixture = try makeDurableWorkFixture()
    for _ in 0..<2 {
        let result = try fixture.store.cancelActive(
            kind: .coach,
            aggregateType: "mission",
            aggregateId: "absent",
            reason: "Nothing active",
            now: durableWorkTestNow
        ) { database, _ in
            try insertDurableBusinessProbe(
                database,
                value: "must-not-run"
            )
        }
        #expect(result == .noActiveWork)
    }
    #expect(try durableLedgerSnapshot(fixture).businessProbe.isEmpty)
}

@Test func concurrentTerminalAndCancelHaveExactlyOneWinner() async throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)

    async let completeWon: Bool = {
        do {
            _ = try fixture.store.complete(
                claim: claim,
                outputJson: #"{"winner":"complete"}"#,
                now: durableWorkTestNow.addingTimeInterval(1)
            ) { _, _ in }
            return true
        } catch {
            return false
        }
    }()
    async let cancelWon: Bool = {
        do {
            _ = try fixture.store.cancel(
                workId: work.id,
                expectedVersion: claim.version,
                reason: "Concurrent cancel",
                now: durableWorkTestNow.addingTimeInterval(1)
            ) { _, _ in }
            return true
        } catch {
            return false
        }
    }()
    let winners = await [completeWon, cancelWon].filter { $0 }.count
    #expect(winners == 1)

    let state = try #require(try durableWorkString(
        fixture,
        workId: work.id,
        column: "state"
    ))
    #expect(["succeeded", "canceled"].contains(state))
    let terminalEventCount = try await fixture.database.pool.read {
        try Int.fetchOne(
            $0,
            sql: """
                SELECT COUNT(*) FROM durable_work_attempt_event
                WHERE workId = ?
                  AND eventKind IN (
                    'succeeded','failed','canceled','interrupted'
                  )
                """,
            arguments: [work.id]
        )
    }
    #expect(terminalEventCount == 1)
}

@Test func adoptionClosesExactlyOneInterruptedAttemptWithoutLeaseExpiry() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let oldClaim = try claimDurableWork(
        fixture,
        workerId: "old-worker",
        leaseDuration: 86_400
    )
    #expect(oldClaim.leaseExpiresAt > durableWorkTestNow)

    let adopted = try fixture.store.adoptInterrupted(
        kinds: [.coach],
        currentWorkerId: "new-worker",
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    #expect(adopted.map(\.id) == [work.id])
    #expect(adopted[0].state == .queued)
    #expect(try durableEventCount(
        fixture,
        workId: work.id,
        kind: "interrupted"
    ) == 1)
    #expect(
        try fixture.store.adoptInterrupted(
            kinds: [.coach],
            currentWorkerId: "new-worker",
            now: durableWorkTestNow.addingTimeInterval(2)
        ).isEmpty
    )
    #expect(
        try fixture.database.pool.read {
            try Int.fetchOne(
                $0,
                sql: """
                    SELECT COUNT(*) FROM durable_work_attempt
                    WHERE workId = ? AND outcome = 'interrupted'
                    """,
                arguments: [work.id]
            )
        } == 1
    )
}

@Test func leaseRenewalReturnsNewVersionAndOldClaimCannotComplete() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let original = try claimDurableWork(fixture)
    let renewed = try fixture.store.renewLease(
        claim: original,
        now: durableWorkTestNow.addingTimeInterval(10),
        leaseDuration: 120
    )
    #expect(renewed.version > original.version)
    #expect(renewed.attempt == original.attempt)
    #expect(renewed.workerId == original.workerId)
    #expect(
        renewed.leaseExpiresAt
            == durableWorkTestNow.addingTimeInterval(130)
    )

    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.store.complete(
            claim: original,
            outputJson: nil,
            now: durableWorkTestNow.addingTimeInterval(11)
        ) { _, _ in }
    }
    let completed = try fixture.store.complete(
        claim: renewed,
        outputJson: nil,
        now: durableWorkTestNow.addingTimeInterval(11)
    ) { _, _ in }
    #expect(completed.state == .succeeded)
}

@Test func genericClaimAndRenewReturnPersistedSubmillisecondLease() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claimNow = Date(
        timeIntervalSinceReferenceDate: 1_000_000.123_456
    )
    let claimed = try claimDurableWork(
        fixture,
        now: claimNow,
        leaseDuration: 60.654_321
    )
    let persistedAfterClaim = try #require(
        try fixture.store.work(id: claimed.workId)
    )

    #expect(claimed.leaseExpiresAt == persistedAfterClaim.leaseExpiresAt)

    let renewNow = Date(
        timeIntervalSinceReferenceDate: 1_000_001.234_567
    )
    let renewed = try fixture.store.renewLease(
        claim: claimed,
        now: renewNow,
        leaseDuration: 120.765_432
    )
    let persistedAfterRenew = try #require(
        try fixture.store.work(id: renewed.workId)
    )

    #expect(renewed.leaseExpiresAt == persistedAfterRenew.leaseExpiresAt)
    #expect(renewed.version == claimed.version + 1)
    let completed = try fixture.store.complete(
        claim: renewed,
        outputJson: nil,
        now: renewNow.addingTimeInterval(1)
    ) { _, _ in }
    #expect(completed.state == .succeeded)
}

@Test func nextClaimableDateEmptyKindsReturnsNil() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    #expect(try fixture.store.nextClaimableDate(
        kinds: [],
        now: durableWorkTestNow
    ) == nil)
    #expect(try fixture.store.claimNext(
        kinds: [],
        workerId: "worker",
        now: durableWorkTestNow,
        leaseDuration: 60
    ) == nil)
    #expect(try durableAttemptCount(fixture, workId: work.id) == 0)
}

@Test func nextClaimableDateRejectsNonFiniteNowBeforeRead() throws {
    let fixture = try makeDurableWorkFixture()
    try fixture.database.pool.write { database in
        try database.execute(sql: "DROP TABLE durable_work_attempt_event")
        try database.execute(sql: "DROP TABLE durable_work_attempt")
        try database.execute(sql: "DROP TABLE durable_work")
    }

    for interval in [Double.nan, Double.infinity, -Double.infinity] {
        let now = Date(timeIntervalSinceReferenceDate: interval)
        #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
            try fixture.store.nextClaimableDate(
                kinds: [],
                now: now
            )
        }
        #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
            try fixture.store.claimNext(
                kinds: [],
                workerId: "worker",
                now: now,
                leaseDuration: 60
            )
        }
    }
}

@Test func nextClaimableDateReturnsNowForQueued() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(
        fixture,
        now: durableWorkTestNow.addingTimeInterval(-100)
    )
    let queryNow = durableWorkTestNow.addingTimeInterval(10)
    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach],
        now: queryNow
    ) == queryNow)
}

@Test func nextClaimableDateReturnsNowForDueRetryIncludingEquality() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    let resolution = try fixture.store.retryOrFail(
        claim: claim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow
    ) { _, _ in }
    guard case let .retryScheduled(_, due) = resolution else {
        Issue.record("Expected retry")
        return
    }
    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach],
        now: due
    ) == due)
}

@Test func nextClaimableDateReturnsEarliestFutureRetry() throws {
    let fixture = try makeDurableWorkFixture()

    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "future-later"
    )
    let laterClaim = try claimDurableWork(fixture)
    let laterResolution = try fixture.store.retryOrFail(
        claim: laterClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(20)
    ) { _, _ in }
    guard case let .retryScheduled(_, later) = laterResolution else {
        Issue.record("Expected later retry")
        return
    }

    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "future-earlier"
    )
    let earlierClaim = try claimDurableWork(
        fixture,
        now: durableWorkTestNow
    )
    let earlierResolution = try fixture.store.retryOrFail(
        claim: earlierClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(10)
    ) { _, _ in }
    guard case let .retryScheduled(_, earlier) = earlierResolution else {
        Issue.record("Expected earlier retry")
        return
    }
    #expect(earlier < later)
    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach, .coach],
        now: durableWorkTestNow
    ) == earlier)
}

@Test func nextClaimableDateIgnoresRunningTerminalAndArchivedCampRows() throws {
    let fixture = try makeDurableWorkFixture()

    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "running-ignore"
    )
    _ = try claimDurableWork(fixture)

    _ = try enqueueDurableWork(
        fixture,
        aggregateId: "terminal-ignore"
    )
    let terminalClaim = try claimDurableWork(fixture)
    _ = try fixture.store.complete(
        claim: terminalClaim,
        outputJson: nil,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }

    let archivedCamp = try addDurableWorkCamp(fixture)
    _ = try enqueueDurableWork(
        fixture,
        campId: archivedCamp,
        aggregateId: "archived-ignore"
    )
    try fixture.database.setCampArchived(
        id: archivedCamp,
        archived: true
    )

    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach],
        now: durableWorkTestNow.addingTimeInterval(2)
    ) == nil)
}

@Test func claimNextUsesExactlyTheSameEligibilityPredicate() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let firstClaim = try claimDurableWork(fixture)
    let retry = try fixture.store.retryOrFail(
        claim: firstClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow
    ) { _, _ in }
    guard case let .retryScheduled(_, due) = retry else {
        Issue.record("Expected retry")
        return
    }

    let beforeDue = due.addingTimeInterval(-0.001)
    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach],
        now: beforeDue
    ) == due)
    #expect(try fixture.store.claimNext(
        kinds: [.coach],
        workerId: "too-early",
        now: beforeDue,
        leaseDuration: 60
    ) == nil)

    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach],
        now: due
    ) == due)
    let dueClaim = try #require(try fixture.store.claimNext(
        kinds: [.coach],
        workerId: "on-time",
        now: due,
        leaseDuration: 60
    ))
    #expect(dueClaim.workId == work.id)
}

@Test func claimAndRenewRejectNaNInfinityZeroAndNegativeLeaseBeforeWrite() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)

    for duration in [Double.nan, Double.infinity, -Double.infinity] {
        #expect(
            throws:
                InvalidDurableWorkTimeError.nonFiniteLeaseDuration
        ) {
            try fixture.store.claimNext(
                kinds: [.coach],
                workerId: "worker",
                now: durableWorkTestNow,
                leaseDuration: duration
            )
        }
    }
    for duration in [0.0, -0.0, -1.0] {
        #expect(
            throws:
                InvalidDurableWorkTimeError.nonPositiveLeaseDuration
        ) {
            try fixture.store.claimNext(
                kinds: [.coach],
                workerId: "worker",
                now: durableWorkTestNow,
                leaseDuration: duration
            )
        }
    }

    let claim = try claimDurableWork(fixture)
    for duration in [Double.nan, Double.infinity, -Double.infinity] {
        #expect(
            throws:
                InvalidDurableWorkTimeError.nonFiniteLeaseDuration
        ) {
            try fixture.store.renewLease(
                claim: claim,
                now: durableWorkTestNow.addingTimeInterval(1),
                leaseDuration: duration
            )
        }
    }
    for duration in [0.0, -0.0, -1.0] {
        #expect(
            throws:
                InvalidDurableWorkTimeError.nonPositiveLeaseDuration
        ) {
            try fixture.store.renewLease(
                claim: claim,
                now: durableWorkTestNow.addingTimeInterval(1),
                leaseDuration: duration
            )
        }
    }
}

@Test func claimAndRenewRejectNonFiniteOrNonAdvancingExpirationBeforeWrite() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)

    let hugeNow = Date(
        timeIntervalSinceReferenceDate: Double.greatestFiniteMagnitude
    )
    #expect(
        throws:
            InvalidDurableWorkTimeError.nonFiniteLeaseExpiration
    ) {
        try fixture.store.claimNext(
            kinds: [.coach],
            workerId: "worker",
            now: hugeNow,
            leaseDuration: Double.greatestFiniteMagnitude
        )
    }
    #expect(
        throws:
            InvalidDurableWorkTimeError.nonAdvancingLeaseExpiration
    ) {
        try fixture.store.claimNext(
            kinds: [.coach],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: Double.leastNonzeroMagnitude
        )
    }

    let claim = try claimDurableWork(fixture)
    #expect(
        throws:
            InvalidDurableWorkTimeError.nonFiniteLeaseExpiration
    ) {
        try fixture.store.renewLease(
            claim: claim,
            now: hugeNow,
            leaseDuration: Double.greatestFiniteMagnitude
        )
    }
    #expect(
        throws:
            InvalidDurableWorkTimeError.nonAdvancingLeaseExpiration
    ) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow.addingTimeInterval(1),
            leaseDuration: Double.leastNonzeroMagnitude
        )
    }
}

@Test func invalidLeaseLeavesVersionLeaseAttemptsAndEventsUnchanged() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let beforeClaim = try durableLedgerSnapshot(fixture)
    #expect(
        throws:
            InvalidDurableWorkTimeError.nonPositiveLeaseDuration
    ) {
        try fixture.store.claimNext(
            kinds: [.coach],
            workerId: "worker",
            now: durableWorkTestNow,
            leaseDuration: 0
        )
    }
    #expect(try durableLedgerSnapshot(fixture) == beforeClaim)

    let claim = try claimDurableWork(fixture)
    let beforeRenew = try durableLedgerSnapshot(fixture)
    #expect(
        throws:
            InvalidDurableWorkTimeError.nonAdvancingLeaseExpiration
    ) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow.addingTimeInterval(1),
            leaseDuration: Double.leastNonzeroMagnitude
        )
    }
    #expect(try durableLedgerSnapshot(fixture) == beforeRenew)
}

@Test func oneTerminalAttemptOutcomePerClaim() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    _ = try fixture.store.complete(
        claim: claim,
        outputJson: nil,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }

    #expect(
        try fixture.database.pool.read {
            try Int.fetchOne(
                $0,
                sql: """
                    SELECT COUNT(*) FROM durable_work_attempt_event
                    WHERE workId = ? AND attempt = ?
                      AND eventKind IN (
                        'succeeded','failed','canceled','interrupted'
                      )
                    """,
                arguments: [work.id, claim.attempt]
            )
        } == 1
    )
    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try deterministicDurableFailure(),
            now: durableWorkTestNow.addingTimeInterval(2)
        ) { _, _ in }
    }
    expectDurableConstraintFailure(
        fixture,
        sql: """
            INSERT INTO durable_work_attempt_event (
              id, workId, attempt, sequence, eventKind, workerId,
              workVersion, resultingWorkState, errorCode, errorMessage,
              occurredAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
        arguments: [
            UUID().uuidString, work.id, claim.attempt, 2, "failed",
            claim.workerId, claim.version + 2, "failed", "schema_error",
            "Duplicate terminal", durableWorkTestNow.addingTimeInterval(2),
        ]
    )
}

@Test func businessMutationFailureRollsBackTerminalAndAttemptClose() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    let before = try durableLedgerSnapshot(fixture)

    #expect(throws: DurableWorkInjectedFailure.businessMutation) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try deterministicDurableFailure(),
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(
                database,
                value: "terminal-failure"
            )
            throw DurableWorkInjectedFailure.businessMutation
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func transientRetryUsesFiveThirtyOneTwentySecondBackoff() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(
        fixture,
        maxAttempts: 4
    ).work
    let failure = try transientDurableFailure()
    var claim = try claimDurableWork(fixture)
    let expectedDelays: [TimeInterval] = [5, 30, 120]
    var failureNow = durableWorkTestNow

    for delay in expectedDelays {
        let resolution = try fixture.store.retryOrFail(
            claim: claim,
            failure: failure,
            now: failureNow
        ) { _, _ in
            Issue.record("Retry branch invoked terminal mutation")
        }
        guard case let .retryScheduled(retryWork, notBefore) = resolution else {
            Issue.record("Expected retryScheduled")
            return
        }
        #expect(retryWork.id == work.id)
        #expect(notBefore == failureNow.addingTimeInterval(delay))
        claim = try claimDurableWork(
            fixture,
            workerId: "worker-\(claim.attempt + 1)",
            now: notBefore
        )
        failureNow = notBefore
    }

    let terminal = try fixture.store.retryOrFail(
        claim: claim,
        failure: failure,
        now: failureNow
    ) { _, _ in }
    guard case let .failed(failed) = terminal else {
        Issue.record("Fourth transient failure must be terminal")
        return
    }
    #expect(failed.state == .failed)
    #expect(failed.attempt == 4)
}

@Test func deterministicFailureIsImmediatelyTerminal() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(
        fixture,
        maxAttempts: 10
    ).work
    let claim = try claimDurableWork(fixture)
    let resolution = try fixture.store.retryOrFail(
        claim: claim,
        failure: try deterministicDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, resultingWork in
        #expect(resultingWork.state == .failed)
    }
    guard case let .failed(failed) = resolution else {
        Issue.record("Expected immediate terminal failure")
        return
    }
    #expect(failed.id == work.id)
    #expect(failed.attempt == 1)
    #expect(failed.state == .failed)
    #expect(failed.notBefore == nil)
}

@Test func retryExhaustionStopsAtMaxAttempts() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(
        fixture,
        maxAttempts: 2
    ).work
    let firstClaim = try claimDurableWork(fixture)
    let firstFailure = try fixture.store.retryOrFail(
        claim: firstClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow
    ) { _, _ in
        Issue.record("First attempt should retry")
    }
    guard case let .retryScheduled(_, due) = firstFailure else {
        Issue.record("Expected first retry")
        return
    }
    let secondClaim = try claimDurableWork(
        fixture,
        workerId: "worker-2",
        now: due
    )
    let secondFailure = try fixture.store.retryOrFail(
        claim: secondClaim,
        failure: try transientDurableFailure(),
        now: due
    ) { _, _ in }
    guard case let .failed(failed) = secondFailure else {
        Issue.record("Max attempts must terminalize")
        return
    }
    #expect(failed.id == work.id)
    #expect(failed.attempt == 2)
    #expect(failed.state == .failed)
}

@Test func retryDateOverflowThrowsAndRollsBack() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    let before = try durableLedgerSnapshot(fixture)
    let overflowingNow = Date(
        timeIntervalSinceReferenceDate: Double.greatestFiniteMagnitude
    )

    #expect(throws: BackoffOverflowError.self) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try transientDurableFailure(),
            now: overflowingNow
        ) { _, _ in }
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func claimClearsRetryAndInterruptedDiagnostics() throws {
    let fixture = try makeDurableWorkFixture()

    let retryWork = try enqueueDurableWork(
        fixture,
        aggregateId: "retry-clear"
    ).work
    let retryClaim = try claimDurableWork(fixture)
    let retry = try fixture.store.retryOrFail(
        claim: retryClaim,
        failure: try transientDurableFailure(
            code: "temporary",
            message: "Retry me"
        ),
        now: durableWorkTestNow
    ) { _, _ in }
    guard case let .retryScheduled(_, due) = retry else {
        Issue.record("Expected retry")
        return
    }
    #expect(try durableWorkString(
        fixture,
        workId: retryWork.id,
        column: "errorCode"
    ) == "temporary")
    let clearedRetryClaim = try claimDurableWork(
        fixture,
        workerId: "retry-worker",
        now: due
    )
    #expect(try durableWorkString(
        fixture,
        workId: retryWork.id,
        column: "errorCode"
    ) == nil)
    #expect(try durableWorkString(
        fixture,
        workId: retryWork.id,
        column: "errorMessage"
    ) == nil)
    _ = try fixture.store.complete(
        claim: clearedRetryClaim,
        outputJson: nil,
        now: due.addingTimeInterval(0.5)
    ) { _, _ in }

    let interruptedWork = try enqueueDurableWork(
        fixture,
        aggregateId: "interrupt-clear"
    ).work
    _ = try claimDurableWork(
        fixture,
        workerId: "old-worker",
        now: due
    )
    _ = try fixture.store.adoptInterrupted(
        kinds: [.coach],
        currentWorkerId: "new-worker",
        now: due.addingTimeInterval(1)
    )
    #expect(try durableWorkString(
        fixture,
        workId: interruptedWork.id,
        column: "errorCode"
    ) == "worker_interrupted")
    _ = try claimDurableWork(
        fixture,
        workerId: "new-worker",
        now: due.addingTimeInterval(2)
    )
    #expect(try durableWorkString(
        fixture,
        workId: interruptedWork.id,
        column: "errorCode"
    ) == nil)
}

@Test func retryFailureCopiesDiagnosticsToWorkAttemptAndEvent() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    let failure = try transientDurableFailure(
        code: "temporary",
        message: "Try again"
    )
    _ = try fixture.store.retryOrFail(
        claim: claim,
        failure: failure,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }

    try fixture.database.pool.read { database in
        let workRow = try #require(try Row.fetchOne(
            database,
            sql: "SELECT * FROM durable_work WHERE id = ?",
            arguments: [work.id]
        ))
        #expect(workRow["state"] as String == "retryScheduled")
        #expect(workRow["errorCode"] as String? == "temporary")
        #expect(workRow["errorMessage"] as String? == "Try again")
        #expect(workRow["outputJson"] as String? == nil)

        let attempt = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(attempt["outcome"] as String? == "failed")
        #expect(attempt["errorCode"] as String? == "temporary")
        #expect(attempt["errorMessage"] as String? == "Try again")

        let event = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ? AND eventKind = 'failed'
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(event["resultingWorkState"] as String == "retryScheduled")
        #expect(event["errorCode"] as String? == "temporary")
        #expect(event["errorMessage"] as String? == "Try again")
    }
}

@Test func terminalFailureCopiesDiagnosticsToWorkAttemptAndEvent() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    let failure = try deterministicDurableFailure(
        code: "invalid_contract",
        message: "Contract rejected"
    )
    _ = try fixture.store.retryOrFail(
        claim: claim,
        failure: failure,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }

    try fixture.database.pool.read { database in
        let workRow = try #require(try Row.fetchOne(
            database,
            sql: "SELECT * FROM durable_work WHERE id = ?",
            arguments: [work.id]
        ))
        #expect(workRow["state"] as String == "failed")
        #expect(workRow["errorCode"] as String? == "invalid_contract")
        #expect(workRow["errorMessage"] as String? == "Contract rejected")
        #expect(workRow["outputJson"] as String? == nil)

        let attempt = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(attempt["outcome"] as String? == "failed")
        #expect(attempt["errorCode"] as String? == "invalid_contract")
        #expect(attempt["errorMessage"] as String? == "Contract rejected")

        let event = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ? AND eventKind = 'failed'
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(event["resultingWorkState"] as String == "failed")
        #expect(event["errorCode"] as String? == "invalid_contract")
        #expect(event["errorMessage"] as String? == "Contract rejected")
    }
}

@Test func queuedAndRetryCancelWriteOnlyWorkCancellationDiagnostics() throws {
    let fixture = try makeDurableWorkFixture()
    let queued = try enqueueDurableWork(
        fixture,
        aggregateId: "queued-diagnostics"
    ).work
    _ = try fixture.store.cancel(
        workId: queued.id,
        expectedVersion: queued.version,
        reason: "Queued canceled",
        now: durableWorkTestNow
    ) { _, _ in }
    #expect(try durableWorkString(
        fixture,
        workId: queued.id,
        column: "errorCode"
    ) == "work_canceled")
    #expect(try durableWorkString(
        fixture,
        workId: queued.id,
        column: "errorMessage"
    ) == "Queued canceled")
    #expect(try durableAttemptCount(fixture, workId: queued.id) == 0)
    #expect(try durableEventCount(fixture, workId: queued.id) == 0)

    let retryWork = try enqueueDurableWork(
        fixture,
        aggregateId: "retry-diagnostics"
    ).work
    let claim = try claimDurableWork(fixture)
    let retry = try fixture.store.retryOrFail(
        claim: claim,
        failure: try transientDurableFailure(
            code: "temporary",
            message: "Historical failure"
        ),
        now: durableWorkTestNow
    ) { _, _ in }
    guard case let .retryScheduled(retrying, _) = retry else {
        Issue.record("Expected retry")
        return
    }
    let attemptsBefore = try durableLedgerSnapshot(fixture).attempts
    let eventsBefore = try durableLedgerSnapshot(fixture).events
    _ = try fixture.store.cancel(
        workId: retryWork.id,
        expectedVersion: retrying.version,
        reason: "Retry canceled",
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }
    #expect(try durableWorkString(
        fixture,
        workId: retryWork.id,
        column: "errorCode"
    ) == "work_canceled")
    #expect(try durableWorkString(
        fixture,
        workId: retryWork.id,
        column: "errorMessage"
    ) == "Retry canceled")
    #expect(try durableLedgerSnapshot(fixture).attempts == attemptsBefore)
    #expect(try durableLedgerSnapshot(fixture).events == eventsBefore)
}

@Test func runningCancelCopiesCancellationDiagnosticsAtomically() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    _ = try fixture.store.cancel(
        workId: work.id,
        expectedVersion: claim.version,
        reason: "User canceled running work",
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }

    try fixture.database.pool.read { database in
        let workRow = try #require(try Row.fetchOne(
            database,
            sql: "SELECT * FROM durable_work WHERE id = ?",
            arguments: [work.id]
        ))
        #expect(workRow["state"] as String == "canceled")
        #expect(workRow["errorCode"] as String? == "work_canceled")
        #expect(
            workRow["errorMessage"] as String?
                == "User canceled running work"
        )

        let attempt = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(attempt["outcome"] as String? == "canceled")
        #expect(attempt["errorCode"] as String? == "work_canceled")
        #expect(
            attempt["errorMessage"] as String?
                == "User canceled running work"
        )

        let event = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ? AND eventKind = 'canceled'
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(event["resultingWorkState"] as String == "canceled")
        #expect(event["errorCode"] as String? == "work_canceled")
        #expect(
            event["errorMessage"] as String?
                == "User canceled running work"
        )
    }
}

@Test func adoptionCopiesInterruptedDiagnosticsAndNextClaimClearsWorkError() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let oldClaim = try claimDurableWork(
        fixture,
        workerId: "old-worker"
    )
    _ = try fixture.store.adoptInterrupted(
        kinds: [.coach],
        currentWorkerId: "new-worker",
        now: durableWorkTestNow.addingTimeInterval(1)
    )

    try fixture.database.pool.read { database in
        let workRow = try #require(try Row.fetchOne(
            database,
            sql: "SELECT * FROM durable_work WHERE id = ?",
            arguments: [work.id]
        ))
        #expect(workRow["state"] as String == "queued")
        #expect(workRow["errorCode"] as String? == "worker_interrupted")
        #expect(workRow["errorMessage"] as String? == nil)

        let attempt = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [work.id, oldClaim.attempt]
        ))
        #expect(attempt["outcome"] as String? == "interrupted")
        #expect(attempt["errorCode"] as String? == "worker_interrupted")
        #expect(attempt["errorMessage"] as String? == nil)

        let event = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ?
                  AND eventKind = 'interrupted'
                """,
            arguments: [work.id, oldClaim.attempt]
        ))
        #expect(event["resultingWorkState"] as String == "queued")
        #expect(event["errorCode"] as String? == "worker_interrupted")
        #expect(event["errorMessage"] as String? == nil)
    }

    let newClaim = try claimDurableWork(
        fixture,
        workerId: "new-worker",
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    #expect(newClaim.attempt == oldClaim.attempt + 1)
    #expect(try durableWorkString(
        fixture,
        workId: work.id,
        column: "errorCode"
    ) == nil)
    #expect(try durableWorkString(
        fixture,
        workId: work.id,
        column: "errorMessage"
    ) == nil)
}

@Test func successStoresOnlyOptionalCanonicalOutputAndNoErrors() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    let output = #"{"artifact":"report.md"}"#
    _ = try fixture.store.complete(
        claim: claim,
        outputJson: output,
        now: durableWorkTestNow.addingTimeInterval(1)
    ) { _, _ in }

    try fixture.database.pool.read { database in
        let workRow = try #require(try Row.fetchOne(
            database,
            sql: "SELECT * FROM durable_work WHERE id = ?",
            arguments: [work.id]
        ))
        #expect(workRow["state"] as String == "succeeded")
        #expect(workRow["outputJson"] as String? == output)
        #expect(workRow["errorCode"] as String? == nil)
        #expect(workRow["errorMessage"] as String? == nil)

        let attempt = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt
                WHERE workId = ? AND attempt = ?
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(attempt["outcome"] as String? == "succeeded")
        #expect(attempt["errorCode"] as String? == nil)
        #expect(attempt["errorMessage"] as String? == nil)

        let event = try #require(try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM durable_work_attempt_event
                WHERE workId = ? AND attempt = ? AND eventKind = 'succeeded'
                """,
            arguments: [work.id, claim.attempt]
        ))
        #expect(event["resultingWorkState"] as String == "succeeded")
        #expect(event["errorCode"] as String? == nil)
        #expect(event["errorMessage"] as String? == nil)
        #expect(try database.columns(
            in: "durable_work_attempt"
        ).map(\.name).contains("outputJson") == false)
        #expect(try database.columns(
            in: "durable_work_attempt_event"
        ).map(\.name).contains("outputJson") == false)
    }
}

@Test func invalidOutputBackoffOverflowAndClosureFailureLeaveAllThreeLayersUnchanged() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try enqueueDurableWork(fixture)
    let claim = try claimDurableWork(fixture)
    let baseline = try durableLedgerSnapshot(fixture)

    #expect(throws: InvalidDurableWorkOutputJSONError.notCanonical) {
        try fixture.store.complete(
            claim: claim,
            outputJson: #"{"value":1.0}"#,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { _, _ in }
    }
    #expect(try durableLedgerSnapshot(fixture) == baseline)

    #expect(throws: BackoffOverflowError.self) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: try transientDurableFailure(),
            now: Date(
                timeIntervalSinceReferenceDate:
                    Double.greatestFiniteMagnitude
            )
        ) { _, _ in }
    }
    #expect(try durableLedgerSnapshot(fixture) == baseline)

    #expect(throws: DurableWorkInjectedFailure.businessMutation) {
        try fixture.store.complete(
            claim: claim,
            outputJson: #"{"value":1}"#,
            now: durableWorkTestNow.addingTimeInterval(1)
        ) { database, _ in
            try insertDurableBusinessProbe(database, value: "rollback")
            throw DurableWorkInjectedFailure.businessMutation
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == baseline)
}

@Test func ddlRejectsOutputOutsideSucceeded() throws {
    let fixture = try makeDurableWorkFixture()
    let running = try enqueueDurableWork(
        fixture,
        aggregateId: "ddl-output-running"
    ).work
    _ = try claimDurableWork(fixture)
    let queued = try enqueueDurableWork(
        fixture,
        aggregateId: "ddl-output-queued"
    ).work

    expectDurableConstraintFailure(
        fixture,
        sql: "UPDATE durable_work SET outputJson = ? WHERE id = ?",
        arguments: [#"{"illegal":true}"#, queued.id]
    )
    expectDurableConstraintFailure(
        fixture,
        sql: "UPDATE durable_work SET outputJson = ? WHERE id = ?",
        arguments: [#"{"illegal":true}"#, running.id]
    )
    #expect(try durableWorkString(
        fixture,
        workId: queued.id,
        column: "outputJson"
    ) == nil)
    #expect(try durableWorkString(
        fixture,
        workId: running.id,
        column: "outputJson"
    ) == nil)
}

@Test func ddlRejectsEveryInvalidWorkAttemptEventErrorStatePair() throws {
    let fixture = try makeDurableWorkFixture()
    let campID = try #require(fixture.campId)
    let catalog = makeDurableDiagnosticCatalog()
    let sentinelIDs = durableDiagnosticSentinelIDs()
    let controlIDs = durableDiagnosticControlIDs()
    let allIDs = Set(catalog.map(\.id))

    #expect(catalog.count == 384)
    #expect(allIDs.count == catalog.count)
    #expect(sentinelIDs.count == 7)
    #expect(controlIDs.count == 19)
    #expect(sentinelIDs.isSubset(of: allIDs))
    #expect(controlIDs.isSubset(of: allIDs))

    let workCases = catalog.filter { $0.table == .work }
    let attemptCases = catalog.filter { $0.table == .attempt }
    let eventCases = catalog.filter { $0.table == .event }
    #expect(workCases.count == 56)
    #expect(workCases.filter(\.expectedAccepted).count == 18)
    #expect(attemptCases.count == 40)
    #expect(attemptCases.filter(\.expectedAccepted).count == 10)
    #expect(eventCases.count == 288)
    #expect(eventCases.filter(\.expectedAccepted).count == 17)

    for id in sentinelIDs {
        #expect(catalog.first { $0.id == id }?.expectedAccepted == false)
    }
    for id in controlIDs {
        #expect(catalog.first { $0.id == id }?.expectedAccepted == true)
    }

    let before = try fixture.database.pool.read(durableDiagnosticRowCounts)
    var verdicts: [String: DurableDiagnosticVerdict] = [:]
    try fixture.database.pool.writeWithoutTransaction { database in
        try database.inTransaction {
            try insertDurableDiagnosticHarness(database, campID: campID)
            for candidate in catalog {
                let verdict = try evaluateDurableDiagnosticCandidate(
                    candidate,
                    database: database,
                    campID: campID
                )
                guard verdicts.updateValue(
                    verdict,
                    forKey: candidate.id
                ) == nil else {
                    throw DurableDiagnosticCatalogError.duplicateCaseID(
                        candidate.id
                    )
                }
            }
            return .rollback
        }
    }
    let after = try fixture.database.pool.read(durableDiagnosticRowCounts)
    #expect(after == before)
    #expect(verdicts.count == 384)

    for candidate in catalog {
        let expected: DurableDiagnosticVerdict = candidate.expectedAccepted
            ? .accepted
            : .checkRejected
        if verdicts[candidate.id] != expected {
            Issue.record(
                "Diagnostic verdict mismatch for \(candidate.id)"
            )
        }
    }
    for id in sentinelIDs where verdicts[id] != .checkRejected {
        Issue.record("NULL/UNKNOWN sentinel did not fail CHECK: \(id)")
    }
    for id in controlIDs where verdicts[id] != .accepted {
        Issue.record("Legal diagnostics control was rejected: \(id)")
    }

    #expect(
        workCases.filter { verdicts[$0.id] == .accepted }.count == 18
    )
    #expect(
        workCases.filter { verdicts[$0.id] == .checkRejected }.count == 38
    )
    #expect(
        attemptCases.filter { verdicts[$0.id] == .accepted }.count == 10
    )
    #expect(
        attemptCases.filter { verdicts[$0.id] == .checkRejected }.count == 30
    )
    #expect(
        eventCases.filter { verdicts[$0.id] == .accepted }.count == 17
    )
    #expect(
        eventCases.filter { verdicts[$0.id] == .checkRejected }.count == 271
    )
}

@Test func ddlRequiresClaimedSequenceZeroAndExactEventResultingState() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let claim = try claimDurableWork(fixture)
    try fixture.database.pool.write { database in
        try database.execute(
            sql: """
                INSERT INTO durable_work_attempt (
                  workId, attempt, id, workerId, startedAt, endedAt, outcome,
                  errorCode, errorMessage, traceId, terminalWorkVersion
                ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, NULL)
                """,
            arguments: [
                work.id, claim.attempt + 1, UUID().uuidString,
                claim.workerId, durableWorkTestNow, "trace-extra",
            ]
        )
    }
    let attempt = claim.attempt + 1

    let invalidEvents: [
        (
            eventKind: String,
            sequence: Int,
            state: String,
            errorCode: String?,
            errorMessage: String?
        )
    ] = [
        ("claimed", 1, "running", nil, nil),
        ("leaseRenewed", 0, "running", nil, nil),
        ("claimed", 0, "queued", nil, nil),
        ("leaseRenewed", 1, "queued", nil, nil),
        ("succeeded", 1, "failed", nil, nil),
        ("failed", 1, "running", "failure", "safe"),
        ("canceled", 1, "failed", "work_canceled", "reason"),
        ("interrupted", 1, "canceled", "worker_interrupted", nil),
    ]
    for event in invalidEvents {
        expectDurableConstraintFailure(
            fixture,
            sql: """
                INSERT INTO durable_work_attempt_event (
                  id, workId, attempt, sequence, eventKind, workerId,
                  workVersion, resultingWorkState, errorCode, errorMessage,
                  occurredAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                UUID().uuidString, work.id, attempt, event.sequence,
                event.eventKind, claim.workerId, claim.version + 1,
                event.state, event.errorCode, event.errorMessage,
                durableWorkTestNow.addingTimeInterval(1),
            ]
        )
    }
}

@Test func invalidCancellationReasonIsPreSQLAndSkipsBusinessMutation() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    let baseline = try durableLedgerSnapshot(fixture)
    let invalidReasons: [
        (String, InvalidDurableWorkCancellationReasonError)
    ] = [
        ("", .empty),
        (String(repeating: "🙂", count: 1_001), .tooLong),
        ("line\nbreak", .containsControlScalar),
        ("c1\u{0085}control", .containsControlScalar),
    ]

    for (reason, expected) in invalidReasons {
        #expect(throws: expected) {
            try fixture.store.cancel(
                workId: work.id,
                expectedVersion: work.version,
                reason: reason,
                now: durableWorkTestNow
            ) { database, _ in
                try insertDurableBusinessProbe(
                    database,
                    value: "must-not-run"
                )
            }
        }
        #expect(throws: expected) {
            try fixture.store.cancelActive(
                kind: .coach,
                aggregateType: work.aggregateType,
                aggregateId: work.aggregateId,
                reason: reason,
                now: durableWorkTestNow
            ) { database, _ in
                try insertDurableBusinessProbe(
                    database,
                    value: "must-not-run-active"
                )
            }
        }
    }
    #expect(try durableLedgerSnapshot(fixture) == baseline)
}

@Test func attemptEventsRejectUpdateAndDelete() throws {
    let fixture = try makeDurableWorkFixture()
    let work = try enqueueDurableWork(fixture).work
    _ = try claimDurableWork(fixture)
    let before = try durableLedgerSnapshot(fixture)

    expectDurableConstraintFailure(
        fixture,
        sql: """
            UPDATE durable_work_attempt_event
            SET workerId = workerId
            WHERE workId = ?
            """,
        arguments: [work.id]
    )
    expectDurableConstraintFailure(
        fixture,
        sql: """
            DELETE FROM durable_work_attempt_event
            WHERE workId = ?
            """,
        arguments: [work.id]
    )
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func nextClaimableDateSelectsEarliestRetry() throws {
    let fixture = try makeDurableWorkFixture()

    _ = try enqueueDurableWork(
        fixture,
        kind: .coach,
        aggregateId: "coach-later"
    )
    let coachLaterClaim = try claimDurableWork(
        fixture,
        kinds: [.coach]
    )
    let coachLater = try fixture.store.retryOrFail(
        claim: coachLaterClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(20)
    ) { _, _ in }
    guard case let .retryScheduled(_, coachLaterDue) = coachLater else {
        Issue.record("Expected coach retry")
        return
    }

    _ = try enqueueDurableWork(
        fixture,
        kind: .coach,
        aggregateId: "coach-earlier"
    )
    let coachEarlierClaim = try claimDurableWork(
        fixture,
        kinds: [.coach]
    )
    let coachEarlier = try fixture.store.retryOrFail(
        claim: coachEarlierClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(10)
    ) { _, _ in }
    guard case let .retryScheduled(_, coachEarlierDue) =
        coachEarlier
    else {
        Issue.record("Expected coach retry")
        return
    }

    _ = try enqueueDurableWork(
        fixture,
        kind: .inputParsing,
        aggregateType: "input",
        aggregateId: "input-earliest"
    )
    let inputClaim = try claimDurableWork(
        fixture,
        kinds: [.inputParsing]
    )
    let input = try fixture.store.retryOrFail(
        claim: inputClaim,
        failure: try transientDurableFailure(),
        now: durableWorkTestNow.addingTimeInterval(5)
    ) { _, _ in }
    guard case let .retryScheduled(_, inputDue) = input else {
        Issue.record("Expected input retry")
        return
    }

    #expect(inputDue < coachEarlierDue)
    #expect(coachEarlierDue < coachLaterDue)
    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach],
        now: durableWorkTestNow
    ) == coachEarlierDue)
    #expect(try fixture.store.nextClaimableDate(
        kinds: [.coach, .inputParsing],
        now: durableWorkTestNow
    ) == inputDue)
}

@Suite(.serialized)
struct A2DurableRuminationTests {
@Test func ruminationStartAndWorkAreAtomic() throws {
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(
        fixture,
        rawText: "验证反刍开始与耐久工作原子提交"
    )
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    try installA2AbortTrigger(
        fixture,
        name: "a2_start_item_abort",
        sql: """
            BEFORE UPDATE ON ingestion_item
            WHEN NEW.status = 'ruminating'
            BEGIN
              SELECT RAISE(ABORT, 'a2 start rollback');
            END
            """
    )
    #expect(throws: DatabaseError.self) {
        try fixture.database.startRumination(
            command: prepared.command,
            now: durableWorkTestNow
        )
    }
    try removeA2AbortTrigger(
        fixture,
        name: "a2_start_item_abort"
    )
    #expect(try durableWorkCount(fixture) == 0)
    #expect(
        try FeedService(db: fixture.database).item(id: item.id)?.status
            == .queued
    )
    #expect(
        try FeedService(db: fixture.database).item(id: item.id)?.attempt
            == 0
    )

    let started = try fixture.database.startRumination(
        command: prepared.command,
        now: durableWorkTestNow
    )

    let projected = try FeedService(db: fixture.database).item(id: item.id)
    let work = try fixture.store.activeWork(
        kind: .rumination,
        aggregateType: "ingestion",
        aggregateId: item.id
    )
    guard projected?.status == .ruminating,
          try activeRuminationWorkCount(fixture, ingestionId: item.id) == 1,
          let work,
          started.disposition == .inserted,
          started.work == work,
          work.state == .queued,
          work.attempt == 0,
          work.version == 1,
          projected?.attempt == 1,
          projected?.errorText == nil
    else {
        Issue.record("A2 start transaction was not atomic")
        return
    }
}

@Test func legacyRuminatingRowGetsOneRepairWork() async throws {
    let fixture = try makeDurableWorkFixture()
    let campId = try #require(fixture.campId)
    guard case let .created(item) = try FeedService(db: fixture.database)
        .submit(campId: campId, rawText: "验证旧反刍行启动修复")
    else {
        Issue.record("A2_RED_LEGACY_FIXTURE_NOT_CREATED")
        return
    }
    try await fixture.database.pool.write { database in
        guard var legacyItem = try IngestionItemRecord.fetchOne(
            database,
            key: item.id
        ) else {
            throw FeedServiceError.ingestionNotFound(item.id)
        }
        legacyItem.status = .ruminating
        legacyItem.updatedAt = durableWorkTestNow
        try legacyItem.update(database)
    }
    try fixture.database.repairLegacyRumination(
        snapshot: .valid(
            runtimeProfileId: "test-rumination-profile",
            model: "test-rumination-model"
        ),
        now: durableWorkTestNow
    )
    try fixture.database.repairLegacyRumination(
        snapshot: .legacyProfileUnresolved,
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    let repairCount = try activeRuminationWorkCount(
        fixture,
        ingestionId: item.id
    )
    let works = try a2RuminationWorks(fixture, ingestionId: item.id)
    #expect(repairCount == 1)
    #expect(works.count == 1)
    #expect(works.first?.idempotencyKey == "legacy-rumination:\(item.id)")
    #expect(works.first?.attempt == 0)
    let work = try #require(works.first)
    #expect(try durableAttemptCount(fixture, workId: work.id) == 0)
    #expect(try durableEventCount(fixture, workId: work.id) == 0)
}

@Test func ruminationCancelAndQueuedProjectionRollbackTogether() throws {
    let fixture = try makeDurableWorkFixture()
    let campId = try #require(fixture.campId)
    guard case let .created(item) = try FeedService(db: fixture.database)
        .submit(campId: campId, rawText: "验证取消同时回滚投影与耐久工作")
    else {
        Issue.record("A2_RED_CANCEL_FIXTURE_NOT_CREATED")
        return
    }
    let work = try startTestRumination(
        fixture,
        ingestionId: item.id
    )
    let before = try durableLedgerSnapshot(fixture)
    try installA2AbortTrigger(
        fixture,
        name: "a2_cancel_item_abort",
        sql: """
            BEFORE UPDATE ON ingestion_item
            WHEN NEW.status = 'queued'
            BEGIN
              SELECT RAISE(ABORT, 'a2 cancel rollback');
            END
            """
    )
    #expect(throws: DatabaseError.self) {
        try fixture.database.cancelRumination(
            ingestionId: item.id,
            workId: work.id,
            expectedVersion: work.version,
            reason: "rumination_deferred_by_user",
            now: durableWorkTestNow
        )
    }
    try removeA2AbortTrigger(
        fixture,
        name: "a2_cancel_item_abort"
    )
    #expect(try durableLedgerSnapshot(fixture) == before)
    #expect(
        try FeedService(db: fixture.database).item(id: item.id)?.status
            == .ruminating
    )

    let canceled = try fixture.database.cancelRumination(
        ingestionId: item.id,
        workId: work.id,
        expectedVersion: work.version,
        reason: "rumination_deferred_by_user",
        now: durableWorkTestNow
    )

    let projected = try FeedService(db: fixture.database).item(id: item.id)
    let activeCount = try activeRuminationWorkCount(
        fixture,
        ingestionId: item.id
    )
    #expect(canceled?.state == .canceled)
    #expect(canceled?.version == work.version + 1)
    #expect(projected?.status == .queued)
    #expect(projected?.errorText == nil)
    #expect(activeCount == 0)
}

@Test func ruminationCrashIsAdoptedAndCompletesOnce() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let firstClaim = try claimA2Rumination(
        fixture,
        workerId: "crashed-worker"
    )

    let adopted = try fixture.database.adoptInterruptedRumination(
        currentWorkerId: "replacement-worker",
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    #expect(adopted.map(\.id) == [started.work.id])
    #expect(adopted.first?.state == .queued)
    #expect(
        try a2Attempt(
            fixture,
            workId: started.work.id,
            attempt: firstClaim.attempt
        )?.outcome == .interrupted
    )

    let replacementClaim = try claimA2Rumination(
        fixture,
        workerId: "replacement-worker",
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    #expect(replacementClaim.workId == firstClaim.workId)
    #expect(replacementClaim.attempt == firstClaim.attempt + 1)

    let completed = try fixture.database.commitRuminationSuccess(
        claim: replacementClaim,
        production: a2RuminationProduction(),
        now: durableWorkTestNow.addingTimeInterval(3)
    )
    #expect(completed.state == .succeeded)
    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.database.commitRuminationSuccess(
            claim: replacementClaim,
            production: a2RuminationProduction(title: "duplicate"),
            now: durableWorkTestNow.addingTimeInterval(4)
        )
    }
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationCompleted
        ).count == 1
    )
    #expect(
        try a2RuminationResultRecord(
            fixture,
            ingestionId: started.item.id
        ) != nil
    )
}

@Test func ruminationFailurePersistenceFailureRemainsRecoverable() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    let before = try durableLedgerSnapshot(fixture)

    try installA2AbortTrigger(
        fixture,
        name: "a2_failure_event_abort",
        sql: """
            BEFORE INSERT ON event
            WHEN NEW.kind = 'rumination_failed'
            BEGIN
              SELECT RAISE(ABORT, 'a2 failure rollback');
            END
            """
    )
    #expect(throws: DatabaseError.self) {
        try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2TransientRuminationFailure(),
            now: durableWorkTestNow.addingTimeInterval(1)
        )
    }
    try removeA2AbortTrigger(
        fixture,
        name: "a2_failure_event_abort"
    )

    #expect(try durableLedgerSnapshot(fixture) == before)
    let context = try fixture.database.ruminationExecutionContext(
        claim: claim,
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    #expect(context.ingestion.id == started.item.id)

    let retried = try fixture.database.recordRuminationAttemptFailure(
        claim: claim,
        failure: a2TransientRuminationFailure(),
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    guard case let .retryScheduled(work, notBefore) = retried else {
        Issue.record("Expected recoverable retry after rollback")
        return
    }
    #expect(work.state == .retryScheduled)
    #expect(notBefore == durableWorkTestNow.addingTimeInterval(7))
}

@Test func ruminationCancelRejectsStaleResponse() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    let running = try #require(
        try fixture.store.work(id: started.work.id)
    )

    let canceled = try fixture.database.cancelRumination(
        ingestionId: started.item.id,
        workId: running.id,
        expectedVersion: running.version,
        reason: "rumination_deferred_by_user",
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    #expect(canceled?.state == .canceled)
    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.database.commitRuminationSuccess(
            claim: claim,
            production: a2RuminationProduction(),
            now: durableWorkTestNow.addingTimeInterval(2)
        )
    }
    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2TransientRuminationFailure(),
            now: durableWorkTestNow.addingTimeInterval(2)
        )
    }
    #expect(
        try FeedService(db: fixture.database)
            .item(id: started.item.id)?.status == .queued
    )
    #expect(
        try a2RuminationResultRecord(
            fixture,
            ingestionId: started.item.id
        ) == nil
    )
}

@Test func repeatedRuminationCommandReturnsExistingWork() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let replayPreparation = try fixture.database.prepareRuminationStart(
        ingestionId: started.item.id
    )
    guard case let .replay(ingestionId, workId) = replayPreparation else {
        Issue.record("Expected preparation replay")
        return
    }
    #expect(ingestionId == started.item.id)
    #expect(workId == started.work.id)

    let readReplay = try fixture.database.ruminationStartReplay(
        command: started.command
    )
    let transactionReplay = try fixture.database.startRumination(
        command: started.command,
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    #expect(readReplay == started.work)
    #expect(transactionReplay.disposition == .replayed)
    #expect(transactionReplay.work == started.work)
    #expect(
        try a2RuminationWorks(
            fixture,
            ingestionId: started.item.id
        ).count == 1
    )
    #expect(
        try FeedService(db: fixture.database)
            .item(id: started.item.id)?.attempt == 1
    )
}

@Test func ruminationAttemptClosesExactlyOnce() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    let failed = try fixture.database.recordRuminationAttemptFailure(
        claim: claim,
        failure: a2DeterministicRuminationFailure(),
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    guard case let .failed(work) = failed else {
        Issue.record("Expected deterministic terminal failure")
        return
    }
    #expect(work.state == .failed)
    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2DeterministicRuminationFailure(),
            now: durableWorkTestNow.addingTimeInterval(2)
        )
    }
    let attempt = try #require(
        try a2Attempt(
            fixture,
            workId: started.work.id,
            attempt: claim.attempt
        )
    )
    let events = try a2AttemptEvents(
        fixture,
        workId: started.work.id,
        attempt: claim.attempt
    )
    #expect(attempt.outcome == .failed)
    #expect(attempt.terminalWorkVersion == work.version)
    #expect(events.filter { $0.eventKind == .failed }.count == 1)
}

@Test func ruminationWorkInputUsesCanonicalCapturedIdentityAndFirstTrace()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let trace = "first-captured-trace"
    let started = try makeA2RuminationStart(
        fixture,
        profileId: "captured-profile",
        model: "captured-model",
        traceId: trace
    )
    let bytes = try CanonicalJSONV1.encode(started.command.input)
    #expect(started.work.inputJson == String(decoding: bytes, as: UTF8.self))
    #expect(started.work.inputHash == CanonicalJSONV1.sha256Hex(bytes))
    #expect(started.work.traceId == trace)
    #expect(
        try JSONDecoder().decode(
            RuminationWorkInput.self,
            from: Data(started.work.inputJson.utf8)
        ) == started.command.input
    )

    let replay = try fixture.database.startRumination(
        command: started.command,
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    #expect(replay.disposition == .replayed)
    #expect(replay.work.traceId == trace)
    #expect(replay.work.createdAt == started.work.createdAt)
}

@Test func ruminationSameKeyDifferentCapturedIdentityConflictsWithoutResolution()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let conflicting = try RuminationStartCommand(
        preparation: started.preparation,
        traceId: started.command.traceId,
        input: RuminationWorkInput(
            model: "different-model",
            runtimeProfileId: started.command.input.runtimeProfileId
        )
    )
    let before = try durableLedgerSnapshot(fixture)
    #expect(throws: DurableWorkReplayConflictError.self) {
        try fixture.database.ruminationStartReplay(command: conflicting)
    }
    #expect(throws: DurableWorkReplayConflictError.self) {
        try fixture.database.startRumination(
            command: conflicting,
            now: durableWorkTestNow.addingTimeInterval(1)
        )
    }
    #expect(try durableLedgerSnapshot(fixture) == before)
}

@Test func ruminationTerminalRetryCreatesReplacementWhileActiveReplayReusesWork()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let first = try makeA2RuminationStart(fixture)
    let firstClaim = try claimA2Rumination(fixture)
    guard case .failed = try fixture.database.recordRuminationAttemptFailure(
        claim: firstClaim,
        failure: a2DeterministicRuminationFailure(),
        now: durableWorkTestNow.addingTimeInterval(1)
    ) else {
        Issue.record("Expected terminal first generation")
        return
    }

    let retryPrepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: first.item.id,
        traceId: "second-generation-trace"
    )
    let replacement = try fixture.database.startRumination(
        command: retryPrepared.command,
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    #expect(replacement.disposition == .inserted)
    #expect(replacement.work.id != first.work.id)
    #expect(retryPrepared.command.generation == 2)

    let activePreparation = try fixture.database.prepareRuminationStart(
        ingestionId: first.item.id
    )
    guard case let .replay(_, activeWorkId) = activePreparation else {
        Issue.record("Expected active generation replay")
        return
    }
    #expect(activeWorkId == replacement.work.id)
    #expect(
        try a2RuminationWorks(
            fixture,
            ingestionId: first.item.id
        ).count == 2
    )
}

@Test func ruminationCapturedProfileAndModelIgnoreDefaultDrift() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(
        fixture,
        profileId: "captured-profile",
        model: "captured-model"
    )
    try fixture.database.saveRuntimeProfile(
        RuntimeProfileRecord(
            id: "new-default-profile",
            kind: .openAIAPI,
            name: "New Default",
            baseURL: "https://api.openai.com",
            credentialAccount: "new-default-credential",
            isDefault: true,
            createdAt: durableWorkTestNow
        )
    )

    let claim = try claimA2Rumination(fixture)
    let context = try fixture.database.ruminationExecutionContext(
        claim: claim,
        now: durableWorkTestNow
    )
    #expect(context.input.runtimeProfileId == "captured-profile")
    #expect(context.input.model == "captured-model")
    #expect(context.input == started.command.input)
}

@Test func ruminationClaimResolutionFailureMatrixIsStableSafeAndFailClosed()
    async throws
{
    for scenario in A2StrictResolverScenario.allCases {
        let fixture = try makeDurableWorkFixture()
        let profileId = "matrix-profile-\(scenario.expectedRuminationCode)"
        let model = scenario.usesOAuth
            ? try #require(KernelDefaults.chatGPTStaticModels.first)
            : "matrix-model"
        let started = try makeA2RuminationStart(
            fixture,
            profileId: profileId,
            model: model
        )
        let provider = MockProvider(script: [])
        let supervisor = makeA2Supervisor(
            fixture,
            resolver: a2StrictResolver(
                scenario: scenario,
                profileId: profileId,
                model: model,
                provider: provider
            )
        )
        try await activateA2Supervisor(supervisor)
        try await supervisor.waitUntilTerminal(workId: started.work.id)

        let persisted = try #require(
            try fixture.store.work(id: started.work.id)
        )
        let item = try #require(
            try FeedService(db: fixture.database).item(id: started.item.id)
        )
        #expect(persisted.state == .failed)
        #expect(persisted.errorCode == scenario.expectedRuminationCode)
        #expect(persisted.errorMessage == scenario.expectedSafeMessage)
        #expect(item.status == .failed)
        #expect(item.errorText == scenario.expectedSafeMessage)
        #expect(await provider.callCount == 0)
        #expect(
            try a2DomainEvents(
                fixture,
                kind: EventKind.ruminationFailed
            ).count == 1
        )
        _ = await supervisor.shutdown(
            gracePeriod: .milliseconds(50)
        )
    }
}

@Test func ruminationResolverNeverFallsBackToCurrentDefaultOrCompanion()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id,
        profileId: "captured-resolver-profile",
        model: "captured-resolver-model"
    )
    try fixture.database.saveRuntimeProfile(
        RuntimeProfileRecord(
            id: "drifted-default-profile",
            kind: .openAIAPI,
            name: "Drifted Default",
            baseURL: "https://api.openai.com",
            credentialAccount: "drifted-default-account",
            isDefault: true,
            createdAt: durableWorkTestNow
        )
    )
    let provider = MockProvider(script: [
        TurnResult(
            content: [
                .text(try RuminationCoding.encode(a2RuminationResult())),
            ],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 2, outputTokens: 3, cacheReadTokens: 1)
        ),
    ])
    let resolver = A2ResolverRecorder(provider: provider)
    let supervisor = makeA2Supervisor(fixture, resolver: resolver)
    try await activateA2Supervisor(supervisor)
    let work = try await supervisor.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await supervisor.waitUntilTerminal(workId: work.id)

    let calls = resolver.calls()
    #expect(calls.count == 2)
    #expect(
        calls.allSatisfy {
            $0.0 == "captured-resolver-profile"
                && $0.1 == "captured-resolver-model"
        }
    )
    #expect(
        !calls.contains {
            $0.0 == "drifted-default-profile"
        }
    )
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationTransientFailureRetriesAtFiveThirtyOneTwentyThenTerminates()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    var claimNow = durableWorkTestNow
    let expectedDelays: [TimeInterval] = [5, 30, 120]

    for expectedAttempt in 1...4 {
        let claim = try claimA2Rumination(
            fixture,
            workerId: "retry-worker",
            now: claimNow
        )
        #expect(claim.attempt == expectedAttempt)
        let result = try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2TransientRuminationFailure(),
            now: claimNow
        )
        if expectedAttempt <= expectedDelays.count {
            guard case let .retryScheduled(work, notBefore) = result else {
                Issue.record("Expected transient retry \(expectedAttempt)")
                return
            }
            let expectedDue = claimNow.addingTimeInterval(
                expectedDelays[expectedAttempt - 1]
            )
            #expect(work.state == .retryScheduled)
            #expect(notBefore == expectedDue)
            #expect(
                try FeedService(db: fixture.database)
                    .item(id: started.item.id)?.status == .ruminating
            )
            claimNow = expectedDue
        } else {
            guard case let .failed(work) = result else {
                Issue.record("Expected exhausted terminal failure")
                return
            }
            #expect(work.state == .failed)
            #expect(
                try FeedService(db: fixture.database)
                    .item(id: started.item.id)?.status == .failed
            )
        }
    }
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationFailed
        ).count == 4
    )
}

@Test func ruminationDeterministicFailureDoesNotRetry() throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    let result = try fixture.database.recordRuminationAttemptFailure(
        claim: claim,
        failure: a2DeterministicRuminationFailure(),
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    guard case let .failed(work) = result else {
        Issue.record("Expected deterministic failure")
        return
    }
    #expect(work.state == .failed)
    #expect(work.notBefore == nil)
    #expect(work.errorCode == "rumination_contract_invalid")
    #expect(
        try FeedService(db: fixture.database)
            .item(id: started.item.id)?.status == .failed
    )
    #expect(
        try fixture.database.claimNextSupervisedWork(
            workerId: "must-not-retry",
            now: durableWorkTestNow.addingTimeInterval(500),
            leaseDuration: 60
        ) == nil
    )
}

@Test func ruminationTerminalFailureAndProjectionCommitOrRollbackTogether()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    let before = try durableLedgerSnapshot(fixture)
    try installA2AbortTrigger(
        fixture,
        name: "a2_terminal_failure_abort",
        sql: """
            BEFORE INSERT ON event
            WHEN NEW.kind = 'rumination_failed'
            BEGIN
              SELECT RAISE(ABORT, 'a2 terminal failure rollback');
            END
            """
    )
    #expect(throws: DatabaseError.self) {
        try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2DeterministicRuminationFailure(),
            now: durableWorkTestNow.addingTimeInterval(1)
        )
    }
    try removeA2AbortTrigger(
        fixture,
        name: "a2_terminal_failure_abort"
    )
    #expect(try durableLedgerSnapshot(fixture) == before)
    #expect(
        try FeedService(db: fixture.database)
            .item(id: started.item.id)?.status == .ruminating
    )

    guard case let .failed(work) =
        try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2DeterministicRuminationFailure(),
            now: durableWorkTestNow.addingTimeInterval(2)
        )
    else {
        Issue.record("Expected committed terminal failure")
        return
    }
    #expect(work.version == claim.version + 1)
    #expect(work.state == .failed)
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationFailed
        ).count == 1
    )
}

@Test func ruminationSuccessResultProjectionAndWorkCommitOrRollbackTogether()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture, title: nil)
    let claim = try claimA2Rumination(fixture)
    let before = try durableLedgerSnapshot(fixture)
    try installA2AbortTrigger(
        fixture,
        name: "a2_success_event_abort",
        sql: """
            BEFORE INSERT ON event
            WHEN NEW.kind = 'rumination_completed'
            BEGIN
              SELECT RAISE(ABORT, 'a2 success rollback');
            END
            """
    )
    #expect(throws: DatabaseError.self) {
        try fixture.database.commitRuminationSuccess(
            claim: claim,
            production: a2RuminationProduction(),
            now: durableWorkTestNow.addingTimeInterval(1)
        )
    }
    try removeA2AbortTrigger(
        fixture,
        name: "a2_success_event_abort"
    )
    #expect(try durableLedgerSnapshot(fixture) == before)
    #expect(
        try a2RuminationResultRecord(
            fixture,
            ingestionId: started.item.id
        ) == nil
    )

    let completed = try fixture.database.commitRuminationSuccess(
        claim: claim,
        production: a2RuminationProduction(),
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    let item = try #require(
        try FeedService(db: fixture.database).item(id: started.item.id)
    )
    #expect(completed.state == .succeeded)
    #expect(completed.outputJson == nil)
    #expect(item.status == .needsReview)
    #expect(item.title == "A2 反刍成果")
    #expect(
        try a2RuminationResultRecord(
            fixture,
            ingestionId: started.item.id
        ) != nil
    )
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationCompleted
        ).count == 1
    )
}

@Test func ruminationLeaseRenewalAllowsOnlyLatestClaimToCommit() throws {
    let fixture = try makeDurableWorkFixture()
    _ = try makeA2RuminationStart(fixture)
    let original = try claimA2Rumination(fixture)
    let renewed = try fixture.database.renewRuminationLease(
        claim: original,
        now: durableWorkTestNow.addingTimeInterval(1),
        leaseDuration: 60
    )
    #expect(renewed.version == original.version + 1)
    #expect(renewed.leaseExpiresAt > original.leaseExpiresAt)

    #expect(throws: StaleDurableWorkClaimError.self) {
        try fixture.database.commitRuminationSuccess(
            claim: original,
            production: a2RuminationProduction(),
            now: durableWorkTestNow.addingTimeInterval(2)
        )
    }
    let completed = try fixture.database.commitRuminationSuccess(
        claim: renewed,
        production: a2RuminationProduction(),
        now: durableWorkTestNow.addingTimeInterval(2)
    )
    #expect(completed.state == .succeeded)
    #expect(completed.version == renewed.version + 1)
}

@Test func ruminationTerminalCommitFailureRetainsProposalAndDoesNotRecallProvider()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let provider = MockProvider(script: [
        TurnResult(
            content: [
                .text(try RuminationCoding.encode(a2RuminationResult())),
            ],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 2, outputTokens: 3, cacheReadTokens: 1)
        ),
    ])
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider)
    )
    try installA2AbortTrigger(
        fixture,
        name: "a2_supervisor_terminal_abort",
        sql: """
            BEFORE INSERT ON event
            WHEN NEW.kind = 'rumination_completed'
            BEGIN
              SELECT RAISE(ABORT, 'a2 retained proposal');
            END
            """
    )
    try await activateA2Supervisor(supervisor)
    let work = try await supervisor.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await a2Eventually {
        await provider.callCount == 1
    }
    for _ in 0..<1_000 {
        await Task.yield()
    }
    #expect(try fixture.store.work(id: work.id)?.state == .running)
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationCompleted
        ).isEmpty
    )

    try removeA2AbortTrigger(
        fixture,
        name: "a2_supervisor_terminal_abort"
    )
    try await supervisor.kick()
    try await supervisor.waitUntilTerminal(workId: work.id)
    #expect(await provider.callCount == 1)
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationCompleted
        ).count == 1
    )
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationProcessRestartMayRecallProviderButCommitsOneResultAndTerminal()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let resultJSON = try RuminationCoding.encode(a2RuminationResult())
    let firstProvider = MockProvider(script: [
        TurnResult(content: [.text(resultJSON)], stopReason: .endTurn),
    ])
    let first = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: firstProvider)
    )
    try installA2AbortTrigger(
        fixture,
        name: "a2_restart_terminal_abort",
        sql: """
            BEFORE INSERT ON event
            WHEN NEW.kind = 'rumination_completed'
            BEGIN
              SELECT RAISE(ABORT, 'a2 restart retained proposal');
            END
            """
    )
    try await activateA2Supervisor(first)
    let work = try await first.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await a2Eventually {
        await firstProvider.callCount == 1
    }
    for _ in 0..<1_000 {
        await Task.yield()
    }
    _ = await first.shutdown(gracePeriod: .milliseconds(50))
    try removeA2AbortTrigger(
        fixture,
        name: "a2_restart_terminal_abort"
    )

    let secondProvider = MockProvider(script: [
        TurnResult(content: [.text(resultJSON)], stopReason: .endTurn),
    ])
    let second = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: secondProvider),
        workerId: "a2-restarted-supervisor-worker"
    )
    try await activateA2Supervisor(second)
    try await second.waitUntilTerminal(workId: work.id)
    #expect(await firstProvider.callCount == 1)
    #expect(await secondProvider.callCount == 1)
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationCompleted
        ).count == 1
    )
    #expect(
        try a2RuminationWorks(
            fixture,
            ingestionId: item.id
        ).count == 1
    )
    #expect(
        try a2RuminationResultRecord(
            fixture,
            ingestionId: item.id
        ) != nil
    )
    _ = await second.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationEmergencyHaltCancelsWorkAndQueuesProjectionAtomically()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    let before = try durableLedgerSnapshot(fixture)
    try installA2AbortTrigger(
        fixture,
        name: "a2_halt_item_abort",
        sql: """
            BEFORE UPDATE ON ingestion_item
            WHEN NEW.status = 'queued'
            BEGIN
              SELECT RAISE(ABORT, 'a2 halt rollback');
            END
            """
    )
    #expect(throws: DatabaseError.self) {
        try fixture.database.cancelAllRuminationForEmergencyHalt(
            reason: "emergency_halt_during_rumination",
            now: durableWorkTestNow.addingTimeInterval(1)
        )
    }
    try removeA2AbortTrigger(
        fixture,
        name: "a2_halt_item_abort"
    )
    #expect(try durableLedgerSnapshot(fixture) == before)
    #expect(
        try FeedService(db: fixture.database)
            .item(id: started.item.id)?.status == .ruminating
    )

    let commits =
        try fixture.database.cancelAllRuminationForEmergencyHalt(
            reason: "emergency_halt_during_rumination",
            now: durableWorkTestNow.addingTimeInterval(2)
        )
    let persisted = try #require(
        try fixture.store.work(id: started.work.id)
    )
    #expect(commits.count == 1)
    let commit = try #require(commits.first)
    #expect(commit.phaseIdentity.ingestionId == started.item.id)
    #expect(commit.phaseIdentity.workId == started.work.id)
    #expect(commit.phaseIdentity.attempt == claim.attempt)
    #expect(commit.workVersion == persisted.version)
    #expect(persisted.state == .canceled)
    #expect(
        try FeedService(db: fixture.database)
            .item(id: started.item.id)?.status == .queued
    )
    #expect(
        try a2Attempt(
            fixture,
            workId: started.work.id,
            attempt: claim.attempt
        )?.outcome == .canceled
    )
    #expect(
        try fixture.database.cancelAllRuminationForEmergencyHalt(
            reason: "emergency_halt_during_rumination",
            now: durableWorkTestNow.addingTimeInterval(3)
        ).isEmpty
    )
}

@Test func ruminationEmergencyHaltRejectsClaimResolveAndProviderDispatch()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    let provider = MockProvider(script: [
        TurnResult(
            content: [.text(try RuminationCoding.encode(a2RuminationResult()))],
            stopReason: .endTurn
        ),
    ])
    let resolver = A2ResolverRecorder(provider: provider)
    let supervisor = makeA2Supervisor(fixture, resolver: resolver)
    let mode = try await supervisor.recoverOnStartup(
        profileModels: [:],
        legacyRuminationSnapshot: .legacyProfileUnresolved
    )
    #expect(mode == .halted)
    #expect(resolver.calls().isEmpty)
    #expect(await provider.callCount == 0)
    #expect(
        try fixture.store.work(id: started.work.id)?.state == .canceled
    )
    #expect(throws: RuminationDurableDispatchNotRunningError.self) {
        try fixture.database.claimNextSupervisedWork(
            workerId: "halted-worker",
            now: durableWorkTestNow,
            leaseDuration: 60
        )
    }
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationLateProviderResponseCannotOverrideEmergencyHalt()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let gate = A2ProviderGate()
    let provider = A2GatedRuminationProvider(
        gate: gate,
        turn: TurnResult(
            content: [.text(try RuminationCoding.encode(a2RuminationResult()))],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 2, outputTokens: 3, cacheReadTokens: 1)
        )
    )
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider)
    )
    try await activateA2Supervisor(supervisor)
    let work = try await supervisor.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await a2Eventually {
        await gate.hasEntered()
    }

    try await supervisor.suppressForEmergencyStop()
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    try await supervisor.didCommitEmergencyPlanningCleanup(
        missionIds: []
    )
    await gate.open()
    for _ in 0..<1_000 {
        await Task.yield()
    }

    #expect(try fixture.store.work(id: work.id)?.state == .canceled)
    #expect(
        try FeedService(db: fixture.database).item(id: item.id)?.status
            == .queued
    )
    #expect(
        try a2RuminationResultRecord(
            fixture,
            ingestionId: item.id
        ) == nil
    )
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationCompleted
        ).isEmpty
    )
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationResumeDoesNotReviveCanceledWork() async throws {
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    let provider = MockProvider(script: [])
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider)
    )
    let mode = try await supervisor.recoverOnStartup(
        profileModels: [:],
        legacyRuminationSnapshot: .legacyProfileUnresolved
    )
    #expect(mode == .halted)
    #expect(
        try fixture.store.work(id: started.work.id)?.state == .canceled
    )

    _ = try fixture.database.transitionDispatchMode(
        from: .halted,
        to: .running
    )
    try await supervisor.resumeAfterDurableRunning()
    try await supervisor.kick()
    #expect(
        try fixture.store.work(id: started.work.id)?.state == .canceled
    )
    #expect(
        try activeRuminationWorkCount(
            fixture,
            ingestionId: started.item.id
        ) == 0
    )
    #expect(await provider.callCount == 0)
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationWaitUntilIdleIncludesDueRuminationAndIgnoresFutureRetry()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    guard case let .retryScheduled(_, due) =
        try fixture.database.recordRuminationAttemptFailure(
            claim: claim,
            failure: a2TransientRuminationFailure(),
            now: durableWorkTestNow
        )
    else {
        Issue.record("Expected future retry")
        return
    }

    let provider = MockProvider(script: [
        TurnResult(
            content: [.text(try RuminationCoding.encode(a2RuminationResult()))],
            stopReason: .endTurn
        ),
    ])
    let clock = A2MutableClock(durableWorkTestNow)
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider),
        clock: clock
    )
    try await activateA2Supervisor(supervisor)
    try await supervisor.waitUntilIdle()
    #expect(await provider.callCount == 0)
    #expect(
        try fixture.store.work(id: started.work.id)?.state
            == .retryScheduled
    )

    clock.set(due)
    try await supervisor.kick()
    try await supervisor.waitUntilTerminal(workId: started.work.id)
    try await supervisor.waitUntilIdle()
    #expect(await provider.callCount == 1)
    #expect(
        try fixture.store.work(id: started.work.id)?.state == .succeeded
    )
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let recorder = A2RuminationCommandRecorder()
    let provider = MockProvider(script: [
        TurnResult(
            content: [.text(try RuminationCoding.encode(a2RuminationResult()))],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 2, outputTokens: 3, cacheReadTokens: 1)
        ),
    ])
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider),
        recorder: recorder
    )
    try await activateA2Supervisor(supervisor)
    let work = try await supervisor.startRumination(
        preparation: prepared.preparation,
        command: prepared.command
    )
    try await supervisor.waitUntilTerminal(workId: work.id)

    let commands = await recorder.commands()
    var phases: [RuminationPhase] = []
    var commits: [RuminationProjectionCommitIdentity] = []
    for command in commands {
        switch command {
        case let .set(identity, phase):
            #expect(identity.ingestionId == item.id)
            #expect(identity.workId == work.id)
            #expect(identity.attempt == 1)
            phases.append(phase)
        case let .invalidate(.projectionCommitted(commit)):
            commits.append(commit)
        case .invalidate(.phase):
            Issue.record("Successful owner emitted control invalidation")
        }
    }
    #expect(phases == [.reading, .extracting, .organizing])
    if commits.count == 2 {
        #expect(commits[0].phaseIdentity.attempt == 0)
        #expect(commits[0].workVersion == 1)
        #expect(commits[1].phaseIdentity.attempt == 1)
        #expect(commits[1].workVersion > commits[0].workVersion)
    } else {
        Issue.record("Expected start and terminal projection commits")
    }
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))

    let restartRecorder = A2RuminationCommandRecorder()
    let restart = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: MockProvider(script: [])),
        recorder: restartRecorder
    )
    try await activateA2Supervisor(restart)
    #expect(await restartRecorder.commands().isEmpty)
    _ = await restart.shutdown(gracePeriod: .milliseconds(50))

    #if DEBUG
    let checkpoints =
        A2RuminationAuthorizationCheckpointForTesting.allCases
    let losses = A2RuminationAuthorizationLossForTesting.allCases
    #expect(checkpoints == [.first, .second])
    #expect(losses.count == 23)
    for checkpoint in checkpoints {
        for loss in losses {
            let observation =
                try await a2RunRuminationAuthorizationMatrixCell(
                    checkpoint: checkpoint,
                    loss: loss
                )
            #expect(observation.checkpoint == checkpoint)
            #expect(observation.loss == loss)
            #expect(observation.providerCallCount == 1)
            #expect(observation.before == observation.after)
            #expect(observation.before.persistedWorkState == .running)
            #expect(observation.before.persistedWorkAttempt == 1)
            #expect(observation.before.persistedWorkVersion != nil)
            #expect(observation.before.persistedWorkErrorCode == nil)
            #expect(
                observation.before.persistedItemStatus == .ruminating
            )
            #expect(observation.before.persistedItemAttempt == 1)
            #expect(observation.before.resultCount == 0)
            #expect(observation.before.completedEventCount == 0)
            #expect(observation.before.failedEventCount == 0)

            let phaseSets = observation.commands.compactMap {
                command -> (
                    identity: RuminationPhaseIdentity,
                    phase: RuminationPhase
                )? in
                guard case let .set(identity, phase) = command else {
                    return nil
                }
                return (identity, phase)
            }
            #expect(
                phaseSets.allSatisfy {
                    $0.identity == observation.identity
                }
            )
            let expectedPhases: [RuminationPhase] =
                checkpoint == .first
                    ? [.reading, .extracting]
                    : [.reading, .extracting, .organizing]
            #expect(phaseSets.map(\.phase) == expectedPhases)

            let phaseInvalidations = observation.commands.compactMap {
                command -> (
                    identity: RuminationPhaseIdentity,
                    reason: RuminationPhaseInvalidationReason
                )? in
                guard case let .invalidate(
                    .phase(identity, reason)
                ) = command else {
                    return nil
                }
                return (identity, reason)
            }
            #expect(phaseInvalidations.count == 1)
            #expect(
                phaseInvalidations.first?.identity
                    == observation.identity
            )
            let expectedReason: RuminationPhaseInvalidationReason
            switch loss {
            case .fatal,
                 .durableReadFailure,
                 .durableInvariantCorruption:
                expectedReason = .globalFatal
            default:
                expectedReason = .controlLoss
            }
            #expect(
                phaseInvalidations.first?.reason == expectedReason
            )
            let invalidationIndex = try #require(
                observation.commands.firstIndex {
                    guard case let .invalidate(
                        .phase(identity, _)
                    ) = $0 else {
                        return false
                    }
                    return identity == observation.identity
                }
            )
            #expect(
                !observation.commands
                    .dropFirst(invalidationIndex + 1)
                    .contains {
                        guard case let .set(identity, _) = $0 else {
                            return false
                        }
                        return identity == observation.identity
                    }
            )
            #expect(observation.lateCommands.isEmpty)
        }
    }
    #endif
}

@Test func legacyRuminationWithoutResolvableRuntimeFailsSafelyExactlyOnce()
    throws
{
    let fixture = try makeDurableWorkFixture()
    let item = try addA2Ingestion(
        fixture,
        rawText: "legacy source must remain"
    )
    try setA2IngestionStatus(
        fixture,
        ingestionId: item.id,
        status: .ruminating
    )
    try fixture.database.repairLegacyRumination(
        snapshot: .legacyProfileUnresolved,
        now: durableWorkTestNow
    )
    try fixture.database.repairLegacyRumination(
        snapshot: .legacyProfileUnresolved,
        now: durableWorkTestNow.addingTimeInterval(1)
    )

    let works = try a2RuminationWorks(
        fixture,
        ingestionId: item.id
    )
    let persistedItem = try #require(
        try FeedService(db: fixture.database).item(id: item.id)
    )
    #expect(works.count == 1)
    let work = try #require(works.first)
    #expect(work.state == .failed)
    #expect(
        work.errorCode
            == "legacy_rumination_profile_unresolved"
    )
    #expect(work.errorMessage == nil)
    #expect(work.attempt == 0)
    #expect(persistedItem.status == .failed)
    #expect(persistedItem.rawText == "legacy source must remain")
    #expect(
        persistedItem.errorText
            == "旧反刍任务缺少可恢复的运行配置。"
    )
    #expect(try durableAttemptCount(fixture, workId: work.id) == 0)
    #expect(try durableEventCount(fixture, workId: work.id) == 0)
    #expect(
        try a2DomainEvents(
            fixture,
            kind: EventKind.ruminationFailed
        ).count == 1
    )
}

@Test func genericDurableWorkAPIsSealRuminationWithExactPriority() throws {
    let fixture = try makeDurableWorkFixture()
    let invalidNow = Date(timeIntervalSinceReferenceDate: .nan)

    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.enqueue(
            campId: "missing",
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: "missing",
            inputJson: "not-json",
            claimedInputHash: "not-a-hash",
            idempotencyKey: "sealed",
            maxAttempts: 0,
            traceId: "trace",
            now: invalidNow
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonPositiveLeaseDuration) {
        try fixture.store.claimNext(
            kinds: [.rumination],
            workerId: "sealed",
            now: durableWorkTestNow,
            leaseDuration: 0
        )
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.rumination],
            workerId: "sealed",
            now: durableWorkTestNow,
            leaseDuration: 60
        )
    }
    #expect(throws: PlanningRequiresDurablePlanningCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.planning, .rumination],
            workerId: "sealed",
            now: durableWorkTestNow,
            leaseDuration: 60
        )
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.claimNext(
            kinds: [.rumination, .planning],
            workerId: "sealed",
            now: durableWorkTestNow,
            leaseDuration: 60
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.nextClaimableDate(
            kinds: [.rumination],
            now: invalidNow
        )
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.nextClaimableDate(
            kinds: [.rumination],
            now: durableWorkTestNow
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.adoptInterrupted(
            kinds: [.rumination],
            currentWorkerId: "sealed",
            now: invalidNow
        )
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.adoptInterrupted(
            kinds: [.rumination],
            currentWorkerId: "sealed",
            now: durableWorkTestNow
        )
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.cancelActive(
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: "missing",
            reason: "",
            now: invalidNow
        ) { _, _ in }
    }

    let started = try makeA2RuminationStart(fixture)
    let claim = try claimA2Rumination(fixture)
    #expect(throws: InvalidDurableWorkTimeError.nonPositiveLeaseDuration) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow,
            leaseDuration: 0
        )
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.renewLease(
            claim: claim,
            now: durableWorkTestNow,
            leaseDuration: 60
        )
    }
    #expect(throws: InvalidDurableWorkTimeError.nonFiniteNow) {
        try fixture.store.complete(
            claim: claim,
            outputJson: "[]",
            now: invalidNow
        ) { _, _ in }
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.complete(
            claim: claim,
            outputJson: nil,
            now: durableWorkTestNow
        ) { _, _ in }
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.retryOrFail(
            claim: claim,
            failure: transientDurableFailure(),
            now: durableWorkTestNow
        ) { _, _ in }
    }
    #expect(throws: InvalidDurableWorkCancellationReasonError.empty) {
        try fixture.store.cancel(
            workId: claim.workId,
            expectedVersion: claim.version,
            reason: "",
            now: durableWorkTestNow
        ) { _, _ in }
    }
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.cancel(
            workId: claim.workId,
            expectedVersion: claim.version,
            reason: "sealed",
            now: durableWorkTestNow
        ) { _, _ in }
    }

    let running = try #require(
        try fixture.store.work(id: started.work.id)
    )
    _ = try fixture.database.cancelRumination(
        ingestionId: started.item.id,
        workId: running.id,
        expectedVersion: running.version,
        reason: "rumination_deferred_by_user",
        now: durableWorkTestNow.addingTimeInterval(1)
    )
    let canceled = try #require(
        try fixture.store.work(id: started.work.id)
    )
    #expect(throws: RuminationRequiresDurableRuminationCapabilityError.self) {
        try fixture.store.cancel(
            workId: canceled.id,
            expectedVersion: canceled.version,
            reason: "sealed",
            now: durableWorkTestNow.addingTimeInterval(2)
        ) { _, _ in }
    }
}

@Test func supervisedWorkPumpIsGlobalFIFOWithoutPlanningRegression()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let planningGate = A2ProviderGate()
    let ruminationGate = A2ProviderGate()
    let sinkGate = A2RuminationSinkGate()
    let planningProvider = A2GatedRuminationProvider(
        gate: planningGate,
        turn: a2ValidPlanTurn()
    )
    let ruminationProvider = A2GatedRuminationProvider(
        gate: ruminationGate,
        turn: TurnResult(
            content: [
                .text(try RuminationCoding.encode(a2RuminationResult())),
            ],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 2, outputTokens: 3)
        )
    )
    let resolver = A2ResolverRecorder { profileId, _ in
        if profileId.hasPrefix("a2-planning-profile-") {
            return planningProvider
        }
        return ruminationProvider
    }
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: resolver,
        phaseSink: { command in
            await sinkGate.receive(command)
        }
    )
    try await activateA2Supervisor(supervisor)
    try await supervisor.waitUntilIdle()

    let planningOld = try enqueueA2PlanningWork(
        fixture,
        suffix: "fifo-old"
    )
    let item = try addA2Ingestion(fixture)
    let prepared = try makeA2RuminationCommand(
        fixture,
        ingestionId: item.id
    )
    let startTask = Task {
        try await supervisor.startRumination(
            preparation: prepared.preparation,
            command: prepared.command
        )
    }
    try await a2Eventually {
        await sinkGate.hasBlockedProjection()
    }
    let reservedRumination = try #require(
        try fixture.store.activeWork(
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: item.id
        )
    )

    try await supervisor.kick()
    #expect(
        try fixture.store.work(id: planningOld.workId)?.state == .queued
    )
    #expect(reservedRumination.state == .queued)
    #expect(await planningProvider.callCount == 0)
    #expect(await ruminationProvider.callCount == 0)

    let planningNew = try enqueueA2PlanningWork(
        fixture,
        suffix: "fifo-new"
    )
    try await fixture.database.pool.write { database in
        try database.execute(
            sql: "UPDATE durable_work SET createdAt = ? WHERE id = ?",
            arguments: [durableWorkTestNow, planningOld.workId]
        )
        try database.execute(
            sql: "UPDATE durable_work SET createdAt = ? WHERE id = ?",
            arguments: [
                durableWorkTestNow.addingTimeInterval(1),
                reservedRumination.id,
            ]
        )
        try database.execute(
            sql: "UPDATE durable_work SET createdAt = ? WHERE id = ?",
            arguments: [
                durableWorkTestNow.addingTimeInterval(2),
                planningNew.workId,
            ]
        )
    }
    await sinkGate.releaseProjection()
    let rumination = try await startTask.value
    #expect(rumination.id == reservedRumination.id)

    try await a2Eventually {
        let states = try [
            fixture.store.work(id: planningOld.workId)?.state,
            fixture.store.work(id: rumination.id)?.state,
            fixture.store.work(id: planningNew.workId)?.state,
        ]
        return states == [.running, .running, .running]
    }
    try await a2Eventually {
        let planningCalls = await planningProvider.callCount
        let ruminationCalls = await ruminationProvider.callCount
        let planningEntered = await planningGate.hasEntered()
        let ruminationEntered = await ruminationGate.hasEntered()
        return planningCalls == 2
            && ruminationCalls == 1
            && planningEntered
            && ruminationEntered
    }
    #expect(await planningProvider.callCount == 2)
    #expect(await ruminationProvider.callCount == 1)
    #expect(
        try fixture.store.work(id: planningOld.workId)?.attempt == 1
    )
    #expect(try fixture.store.work(id: rumination.id)?.attempt == 1)
    #expect(
        try fixture.store.work(id: planningNew.workId)?.attempt == 1
    )

    let commands = await sinkGate.recordedCommands()
    let firstCommand = try #require(commands.first)
    let startCommit: RuminationProjectionCommitIdentity?
    if case let .invalidate(.projectionCommitted(commit)) = firstCommand {
        startCommit = commit
    } else {
        Issue.record("Attempt-zero projection did not precede global claim")
        startCommit = nil
    }
    #expect(startCommit?.phaseIdentity.workId == rumination.id)
    #expect(startCommit?.phaseIdentity.attempt == 0)
    #expect(
        commands.contains {
            if case let .set(identity, .reading) = $0 {
                return identity.workId == rumination.id
                    && identity.attempt == 1
            }
            return false
        }
    )

    await planningGate.open()
    await ruminationGate.open()
    try await supervisor.waitUntilTerminal(workId: planningOld.workId)
    try await supervisor.waitUntilTerminal(workId: rumination.id)
    try await supervisor.waitUntilTerminal(workId: planningNew.workId)
    try await supervisor.waitUntilIdle()
    #expect(
        try fixture.store.work(id: planningOld.workId)?.state
            == .succeeded
    )
    #expect(
        try fixture.store.work(id: rumination.id)?.state == .succeeded
    )
    #expect(
        try fixture.store.work(id: planningNew.workId)?.state
            == .succeeded
    )
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func ruminationStartupRemainsSuppressedUntilOrchestratorActivation()
    async throws
{
    let fixture = try makeDurableWorkFixture()
    let started = try makeA2RuminationStart(fixture)
    let provider = MockProvider(script: [
        TurnResult(
            content: [.text(try RuminationCoding.encode(a2RuminationResult()))],
            stopReason: .endTurn
        ),
    ])
    let supervisor = makeA2Supervisor(
        fixture,
        resolver: A2ResolverRecorder(provider: provider)
    )
    let mode = try await supervisor.recoverOnStartup(
        profileModels: [:],
        legacyRuminationSnapshot: .legacyProfileUnresolved
    )
    #expect(mode == .running)
    await #expect(throws: SupervisorDispatchSuppressedError.self) {
        try await supervisor.kick()
    }
    await #expect(throws: SupervisorDispatchSuppressedError.self) {
        try await supervisor.startIfNeeded()
    }
    #expect(await provider.callCount == 0)
    #expect(
        try fixture.store.work(id: started.work.id)?.state == .queued
    )

    try await supervisor.activateAfterOrchestratorRecovery()
    try await supervisor.waitUntilTerminal(workId: started.work.id)
    #expect(await provider.callCount == 1)
    #expect(
        try fixture.store.work(id: started.work.id)?.state == .succeeded
    )
    _ = await supervisor.shutdown(gracePeriod: .milliseconds(50))
}

@Test func legacyRuminationRepairCoversValidHaltedAndEveryTerminalReason()
    async throws
{
    let cases: [
        (
            mode: DispatchMode,
            snapshot: LegacyRuminationStartupSnapshot,
            terminalCode: String?,
            safeMessage: String?
        )
    ] = [
        (.running, .valid(runtimeProfileId: "legacy-profile", model: "legacy-model"), nil, nil),
        (
            .running,
            .legacyProfileUnresolved,
            "legacy_rumination_profile_unresolved",
            "旧反刍任务缺少可恢复的运行配置。"
        ),
        (
            .running,
            .legacyModelUnavailable,
            "legacy_rumination_model_unavailable",
            "旧反刍任务缺少可恢复的模型。"
        ),
        (
            .running,
            .legacyProfileCLIUnsupported,
            "legacy_rumination_profile_cli_unsupported",
            "旧反刍任务的 CLI 运行配置不受支持。"
        ),
        (.halted, .valid(runtimeProfileId: "legacy-profile", model: "legacy-model"), nil, nil),
        (.halted, .legacyProfileUnresolved, nil, nil),
        (.halted, .legacyModelUnavailable, nil, nil),
        (.halted, .legacyProfileCLIUnsupported, nil, nil),
    ]

    for (index, testCase) in cases.enumerated() {
        let fixture = try makeDurableWorkFixture()
        let item = try addA2Ingestion(
            fixture,
            rawText: "legacy-\(index)"
        )
        try setA2IngestionStatus(
            fixture,
            ingestionId: item.id,
            status: .ruminating,
            attempt: 7
        )
        if testCase.mode == .halted {
            _ = try fixture.database.transitionDispatchMode(
                from: .running,
                to: .halted
            )
        }
        let firstProvider = MockProvider(script: [])
        let firstResolver = A2ResolverRecorder(provider: firstProvider)
        let firstSupervisor = makeA2Supervisor(
            fixture,
            resolver: firstResolver
        )
        let firstMode = try await firstSupervisor.recoverOnStartup(
            profileModels: [:],
            legacyRuminationSnapshot: testCase.snapshot
        )
        #expect(firstMode == testCase.mode)
        #expect(firstResolver.calls().isEmpty)
        #expect(await firstProvider.callCount == 0)
        _ = await firstSupervisor.shutdown(
            gracePeriod: .milliseconds(50)
        )

        let restartProvider = MockProvider(script: [])
        let restartResolver = A2ResolverRecorder(
            provider: restartProvider
        )
        let restartSupervisor = makeA2Supervisor(
            fixture,
            resolver: restartResolver
        )
        let restartMode = try await restartSupervisor.recoverOnStartup(
            profileModels: [:],
            legacyRuminationSnapshot: testCase.snapshot
        )
        #expect(restartMode == testCase.mode)
        #expect(restartResolver.calls().isEmpty)
        #expect(await restartProvider.callCount == 0)

        let works = try a2RuminationWorks(
            fixture,
            ingestionId: item.id
        )
        let work = try #require(works.first)
        let projected = try #require(
            try FeedService(db: fixture.database).item(id: item.id)
        )
        #expect(works.count == 1)
        #expect(work.attempt == 0)
        #expect(work.maxAttempts == 4)
        #expect(projected.attempt == 7)
        #expect(try durableAttemptCount(fixture, workId: work.id) == 0)
        #expect(try durableEventCount(fixture, workId: work.id) == 0)

        if testCase.mode == .halted {
            let legacyInput = try JSONDecoder().decode(
                LegacyRuminationTerminalInputV1.self,
                from: Data(work.inputJson.utf8)
            )
            #expect(
                legacyInput.terminalCode
                    == "emergency_halt_during_rumination"
            )
            #expect(work.state == .canceled)
            #expect(work.errorCode == "work_canceled")
            #expect(
                work.errorMessage
                    == "emergency_halt_during_rumination"
            )
            #expect(projected.status == .queued)
            #expect(projected.errorText == nil)
            #expect(
                try a2DomainEvents(
                    fixture,
                    kind: EventKind.ruminationFailed
                ).isEmpty
            )
            _ = try fixture.database.transitionDispatchMode(
                from: .halted,
                to: .running
            )
            try await restartSupervisor.resumeAfterDurableRunning()
            try await restartSupervisor.kick()
            #expect(
                try a2RuminationWorks(
                    fixture,
                    ingestionId: item.id
                ).count == 1
            )
            #expect(await restartProvider.callCount == 0)
        } else if let terminalCode = testCase.terminalCode {
            let legacyInput = try JSONDecoder().decode(
                LegacyRuminationTerminalInputV1.self,
                from: Data(work.inputJson.utf8)
            )
            #expect(legacyInput.terminalCode == terminalCode)
            #expect(work.state == .failed)
            #expect(work.errorCode == terminalCode)
            #expect(work.errorMessage == nil)
            #expect(projected.status == .failed)
            #expect(projected.errorText == testCase.safeMessage)
            #expect(
                try a2DomainEvents(
                    fixture,
                    kind: EventKind.ruminationFailed
                ).count == 1
            )
        } else {
            let input = try JSONDecoder().decode(
                RuminationWorkInput.self,
                from: Data(work.inputJson.utf8)
            )
            #expect(input.runtimeProfileId == "legacy-profile")
            #expect(input.model == "legacy-model")
            #expect(work.state == .queued)
            #expect(work.errorCode == nil)
            #expect(projected.status == .ruminating)
            #expect(projected.errorText == nil)
            #expect(
                try a2DomainEvents(
                    fixture,
                    kind: EventKind.ruminationFailed
                ).isEmpty
            )
        }
        _ = await restartSupervisor.shutdown(
            gracePeriod: .milliseconds(50)
        )
    }
}

@Test func ruminationUsageIsExactOrFailsBeforeAccounting() async throws {
    #expect(throws: InvalidRuminationPayloadError.negativeUsage) {
        try RuminationUsageCountersV1(
            cacheReadTokens: -1,
            inputTokens: 0,
            outputTokens: 0
        )
    }

    let encodedResult = try RuminationCoding.encode(
        a2RuminationResult()
    )
    let exact = try await a2RunSupervisorRuminationTurn(
        rawText: encodedResult,
        usage: Usage(
            inputTokens: 11,
            outputTokens: 13,
            cacheReadTokens: 7
        )
    )
    #expect(exact.providerCallCount == 1)
    #expect(exact.providerTools == [[]])
    #expect(exact.work.state == .succeeded)
    #expect(exact.work.attempt == 1)
    #expect(exact.work.errorCode == nil)
    #expect(exact.item.status == .needsReview)
    #expect(exact.item.attempt == 1)
    #expect(exact.attempt.workId == exact.work.id)
    #expect(exact.attempt.attempt == exact.work.attempt)
    #expect(exact.attempt.outcome == .succeeded)
    #expect(exact.attempt.errorCode == nil)
    #expect(exact.attempt.terminalWorkVersion == exact.work.version)
    #expect(exact.result?.ingestionId == exact.item.id)
    #expect(exact.completedEvents.count == 1)
    #expect(exact.failedEvents.isEmpty)
    let exactPayload = try a2EventPayload(
        try #require(exact.completedEvents.first)
    )
    #expect(exactPayload["workId"] as? String == exact.work.id)
    #expect(exactPayload["ingestionId"] as? String == exact.item.id)
    #expect(
        (exactPayload["attempt"] as? NSNumber)?.intValue
            == exact.work.attempt
    )
    let exactPayloadUsage = try a2PayloadUsage(exactPayload)
    #expect(
        (exactPayloadUsage["cacheReadTokens"] as? NSNumber)?
            .int64Value == 7
    )
    #expect(
        (exactPayloadUsage["inputTokens"] as? NSNumber)?
            .int64Value == 11
    )
    #expect(
        (exactPayloadUsage["outputTokens"] as? NSNumber)?
            .int64Value == 13
    )

    let parseFailure = try await a2RunSupervisorRuminationTurn(
        rawText: #"{"not":"the rumination contract"}"#,
        usage: Usage(
            inputTokens: 101,
            outputTokens: 103,
            cacheReadTokens: 107
        )
    )
    #expect(parseFailure.providerCallCount == 1)
    #expect(parseFailure.providerTools == [[]])
    #expect(parseFailure.work.state == .failed)
    #expect(parseFailure.work.attempt == 1)
    #expect(
        parseFailure.work.errorCode == "rumination_contract_invalid"
    )
    #expect(parseFailure.item.status == .failed)
    #expect(parseFailure.item.attempt == 1)
    #expect(parseFailure.attempt.workId == parseFailure.work.id)
    #expect(parseFailure.attempt.attempt == parseFailure.work.attempt)
    #expect(parseFailure.attempt.outcome == .failed)
    #expect(
        parseFailure.attempt.errorCode
            == "rumination_contract_invalid"
    )
    #expect(
        parseFailure.attempt.terminalWorkVersion
            == parseFailure.work.version
    )
    #expect(parseFailure.result == nil)
    #expect(parseFailure.completedEvents.isEmpty)
    #expect(parseFailure.failedEvents.count == 1)
    let parsePayload = try a2EventPayload(
        try #require(parseFailure.failedEvents.first)
    )
    #expect(parsePayload["workId"] as? String == parseFailure.work.id)
    #expect(
        parsePayload["ingestionId"] as? String
            == parseFailure.item.id
    )
    #expect(
        (parsePayload["attempt"] as? NSNumber)?.intValue
            == parseFailure.work.attempt
    )
    #expect(
        parsePayload["code"] as? String
            == "rumination_contract_invalid"
    )
    #expect(parsePayload["terminal"] as? Bool == true)
    let parsePayloadUsage = try a2PayloadUsage(parsePayload)
    #expect(
        (parsePayloadUsage["cacheReadTokens"] as? NSNumber)?
            .int64Value == 107
    )
    #expect(
        (parsePayloadUsage["inputTokens"] as? NSNumber)?
            .int64Value == 101
    )
    #expect(
        (parsePayloadUsage["outputTokens"] as? NSNumber)?
            .int64Value == 103
    )

    let invalidUsage = try await a2RunSupervisorRuminationTurn(
        rawText: encodedResult,
        usage: Usage(
            inputTokens: -1,
            outputTokens: 2,
            cacheReadTokens: 3
        )
    )
    #expect(invalidUsage.providerCallCount == 1)
    #expect(invalidUsage.providerTools == [[]])
    #expect(invalidUsage.work.state == .failed)
    #expect(invalidUsage.work.attempt == 1)
    #expect(
        invalidUsage.work.errorCode == "rumination_usage_invalid"
    )
    #expect(invalidUsage.item.status == .failed)
    #expect(invalidUsage.item.attempt == 1)
    #expect(invalidUsage.attempt.workId == invalidUsage.work.id)
    #expect(invalidUsage.attempt.attempt == invalidUsage.work.attempt)
    #expect(invalidUsage.attempt.outcome == .failed)
    #expect(
        invalidUsage.attempt.errorCode == "rumination_usage_invalid"
    )
    #expect(
        invalidUsage.attempt.terminalWorkVersion
            == invalidUsage.work.version
    )
    #expect(invalidUsage.result == nil)
    #expect(invalidUsage.completedEvents.isEmpty)
    #expect(invalidUsage.failedEvents.count == 1)
    let invalidPayload = try a2EventPayload(
        try #require(invalidUsage.failedEvents.first)
    )
    #expect(invalidPayload["workId"] as? String == invalidUsage.work.id)
    #expect(
        invalidPayload["ingestionId"] as? String
            == invalidUsage.item.id
    )
    #expect(
        (invalidPayload["attempt"] as? NSNumber)?.intValue
            == invalidUsage.work.attempt
    )
    #expect(
        invalidPayload["code"] as? String
            == "rumination_usage_invalid"
    )
    #expect(invalidPayload["terminal"] as? Bool == true)
    #expect(invalidPayload["usage"] is NSNull)

    let boundary = try await a2RunSupervisorRuminationTurn(
        rawText: encodedResult,
        usage: Usage(
            inputTokens: Int.max,
            outputTokens: Int.max,
            cacheReadTokens: Int.max
        )
    )
    #expect(boundary.providerCallCount == 1)
    #expect(boundary.work.state == .succeeded)
    #expect(boundary.item.status == .needsReview)
    #expect(boundary.attempt.outcome == .succeeded)
    #expect(boundary.completedEvents.count == 1)
    #expect(boundary.failedEvents.isEmpty)
    let boundaryUsage = try a2PayloadUsage(
        try a2EventPayload(
            try #require(boundary.completedEvents.first)
        )
    )
    #expect(
        (boundaryUsage["cacheReadTokens"] as? NSNumber)?
            .int64Value == Int64.max
    )
    #expect(
        (boundaryUsage["inputTokens"] as? NSNumber)?
            .int64Value == Int64.max
    )
    #expect(
        (boundaryUsage["outputTokens"] as? NSNumber)?
            .int64Value == Int64.max
    )
}

@Test func activeRuminationFencesDiscardDeleteAndArchiveRaces() throws {
    let statusOnly = try makeDurableWorkFixture()
    let statusOnlyItem = try addA2Ingestion(statusOnly)
    try setA2IngestionStatus(
        statusOnly,
        ingestionId: statusOnlyItem.id,
        status: .ruminating,
        attempt: 1
    )
    let statusOnlyLedgerBefore = try durableLedgerSnapshot(statusOnly)
    let statusOnlyItemBefore = try #require(
        try FeedService(db: statusOnly.database).item(
            id: statusOnlyItem.id
        )
    )
    let statusOnlyCampId = try #require(statusOnly.campId)
    let statusOnlyCampBefore = try #require(
        try statusOnly.database.camp(
            id: statusOnlyCampId
        )
    ).archived
    let statusOnlyEventCountBefore = try statusOnly.database.pool.read {
        try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM event") ?? 0
    }
    #expect(throws: FeedServiceError.invalidState(.ruminating)) {
        try FeedService(db: statusOnly.database).discard(
            id: statusOnlyItem.id
        )
    }
    #expect(throws: InvalidDurableWorkStateError.self) {
        try statusOnly.database.setCampArchived(
            id: statusOnlyCampId,
            archived: true
        )
    }
    #expect(
        try durableLedgerSnapshot(statusOnly)
            == statusOnlyLedgerBefore
    )
    #expect(
        try FeedService(db: statusOnly.database).item(
            id: statusOnlyItem.id
        ) == statusOnlyItemBefore
    )
    #expect(
        try statusOnly.database.camp(
            id: statusOnlyCampId
        )?.archived == statusOnlyCampBefore
    )
    #expect(
        try statusOnly.database.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM event")
                ?? 0
        } == statusOnlyEventCountBefore
    )
    #expect(
        try activeRuminationWorkCount(
            statusOnly,
            ingestionId: statusOnlyItem.id
        ) == 0
    )

    let workOnly = try makeDurableWorkFixture()
    let workOnlyStarted = try makeA2RuminationStart(workOnly)
    try setA2IngestionStatus(
        workOnly,
        ingestionId: workOnlyStarted.item.id,
        status: .queued
    )
    let workOnlyLedgerBefore = try durableLedgerSnapshot(workOnly)
    let workOnlyItemBefore = try #require(
        try FeedService(db: workOnly.database).item(
            id: workOnlyStarted.item.id
        )
    )
    let workOnlyCampId = try #require(workOnly.campId)
    let workOnlyCampBefore = try #require(
        try workOnly.database.camp(
            id: workOnlyCampId
        )
    ).archived
    let workOnlyEventCountBefore = try workOnly.database.pool.read {
        try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM event") ?? 0
    }
    #expect(throws: FeedServiceError.invalidState(.ruminating)) {
        try FeedService(db: workOnly.database).discard(
            id: workOnlyStarted.item.id
        )
    }
    #expect(throws: InvalidDurableWorkStateError.self) {
        try workOnly.database.setCampArchived(
            id: workOnlyCampId,
            archived: true
        )
    }
    #expect(
        try activeRuminationWorkCount(
            workOnly,
            ingestionId: workOnlyStarted.item.id
        ) == 1
    )
    #expect(
        try durableLedgerSnapshot(workOnly) == workOnlyLedgerBefore
    )
    #expect(
        try FeedService(db: workOnly.database).item(
            id: workOnlyStarted.item.id
        ) == workOnlyItemBefore
    )
    #expect(
        try workOnly.database.camp(
            id: workOnlyCampId
        )?.archived == workOnlyCampBefore
    )
    #expect(
        try workOnly.database.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM event")
                ?? 0
        } == workOnlyEventCountBefore
    )

    let neither = try makeDurableWorkFixture()
    let neitherItem = try addA2Ingestion(neither)
    let neitherEventCountBefore = try neither.database.pool.read {
        try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM event") ?? 0
    }
    #expect(
        try activeRuminationWorkCount(
            neither,
            ingestionId: neitherItem.id
        ) == 0
    )
    try FeedService(db: neither.database).discard(id: neitherItem.id)
    #expect(
        try FeedService(db: neither.database).item(
            id: neitherItem.id
        )?.status == .discarded
    )
    try neither.database.setCampArchived(
        id: try #require(neither.campId),
        archived: true
    )
    #expect(
        try neither.database.camp(
            id: try #require(neither.campId)
        )?.archived == true
    )
    #expect(
        try neither.database.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM event")
                ?? 0
        } == neitherEventCountBefore + 1
    )
    #expect(try durableWorkCount(neither) == 0)

    let adapterSource = try PlanningTestFixtures.source(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let prepareFunction = try PlanningTestFixtures.uniqueFunction(
        in: adapterSource,
        signature: "func prepareIngestionDeletion("
    )
    try prepareFunction.requireTokensInOrder([
        ".prepareActiveIngestionDeletion(",
        "applyPendingIngestionDeletion(pending)",
    ])
    let executeFunction = try PlanningTestFixtures.uniqueFunction(
        in: adapterSource,
        signature: "func executeIngestionDeletion() async -> Bool"
    )
    try executeFunction.requireTokensInOrder([
        "executePendingActiveIngestionDeletion()",
        "completeCommittedIngestionDeletionRefresh()",
    ])
    let resolveFunction = try PlanningTestFixtures.uniqueFunction(
        in: adapterSource,
        signature: "func resolveIngestionDeletion() async -> Bool"
    )
    try resolveFunction.requireTokensInOrder([
        "resolvePendingActiveIngestionDeletion()",
        "completeCommittedIngestionDeletionRefresh()",
    ])
    try prepareFunction.requireAbsent("db.pool.write")
    try executeFunction.requireAbsent("db.pool.write")
    try resolveFunction.requireAbsent("db.pool.write")

    let inputWorkflowSource = try PlanningTestFixtures.source(
        "AgentLoopApplication/InputWorkflowController.swift"
    )
    let livePorts = try PlanningTestFixtures.uniqueFunction(
        in: inputWorkflowSource,
        signature:
            "private static func configured(\n"
                + "        store: IngestionDeletionStore,\n"
                + "        beforeCommittedRefresh:\n"
                + "            @escaping @Sendable () async throws -> Void = {}"
    )
    try livePorts.requireTokensInOrder([
        "makeEnvelope:",
        "prepare:",
        "try store.prepareActiveIngestionDeletion(request: $0)",
        "execute:",
        "store.executeActiveIngestionDeletion(preparedCommand: $0)",
        "resolve:",
        "store.resolveActiveIngestionDeletionExecution(",
    ])
    try livePorts.requireAbsent("deleteIngestionAtomically")

    let deletionStoreSource = try PlanningTestFixtures.source(
        "AgentLoopCore/Database/IngestionDeletionStore.swift"
    )
    let atomicDelete = try PlanningTestFixtures.uniqueFunction(
        in: deletionStoreSource,
        signature: "func execute(\n        _ command: ActiveIngestionDeletionCommandV1,"
    )
    try atomicDelete.requireTokensInOrder([
        "validateAllPersistedGraphs(in: transaction)",
        "snapshot = try readSnapshot(",
        "livePayload == command.payload",
        "registry.requireWriterCell(for: transaction)",
        "registry.beginGeneration(",
        "invocation: .deleteResult",
        "switch command.payload.scope",
        "invocation: .deleteIngestion",
        "registry.finishGeneration(",
    ])
    let rawAtomicDelete = String(atomicDelete.body)
    for persistedMutation in [
        "DELETE FROM rumination_result",
        "DELETE FROM ingestion_item",
        "UPDATE ingestion_item",
    ] {
        #expect(rawAtomicDelete.contains(persistedMutation))
    }
}
}
