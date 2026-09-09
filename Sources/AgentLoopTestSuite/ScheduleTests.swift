import Foundation
import GRDB
import Testing
import AgentLoopCore

private func scheduleTempDB() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AppDatabase(path: directory.appendingPathComponent("schedule.sqlite").path)
}

private func scheduleCalendar(_ timeZoneID: String) -> (Calendar, TimeZone) {
    let timeZone = TimeZone(identifier: timeZoneID)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return (calendar, timeZone)
}

private func scheduleDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    timeZoneID: String
) -> Date {
    let (calendar, timeZone) = scheduleCalendar(timeZoneID)
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

private func scheduleStamp(_ date: Date, timeZoneID: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: timeZoneID)!
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}

private func scheduleTemplateFixture(
    db: AppDatabase,
    budgetTokens: Int? = 10_000,
    autonomy: MissionAutonomy = .standard
) throws -> (camp: CampRecord, companion: CompanionRecord, template: MissionTemplateRecord) {
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "甲",
        color: "blue",
        rolePrompt: "执行",
        model: "model-a",
        campId: camp.id
    )
    try db.saveCompanion(companion)
    let template = try MissionTemplateRecord.new(
        name: "每日晨报",
        goal: "整理今天的晨报",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: budgetTokens,
        autonomy: autonomy,
        campId: camp.id
    )
    return (camp, companion, template)
}

private struct ScheduleFireTestFixture {
    let database: AppDatabase
    let camp: CampRecord
    let companion: CompanionRecord
    let template: MissionTemplateRecord
    let schedule: ScheduleRecord
    let runtimeProfileId: String
    let plannerModel: String
}

private final class ScheduleTestResolverRecorder:
    PlanningProviderResolver, @unchecked Sendable
{
    private let lock = NSLock()
    private let provider: any LLMProvider
    private let onResolve: @Sendable () throws -> Void
    private var callCountStorage = 0

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
        callCountStorage += 1
        lock.unlock()
        try onResolve()
        return provider
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCountStorage
    }
}

private struct ScheduleMissingProfileSource: PlanningRuntimeProfileSource {
    func planningRuntimeProfile(id: String) throws -> RuntimeProfileRecord? {
        nil
    }
}

private struct ScheduleEmptyCatalogSource: PlanningModelCatalogSource {
    func planningCachedCatalog(profileId: String) throws -> [String]? {
        nil
    }

    func planningModelChoices(profileId: String) throws -> [String]? {
        nil
    }

    func planningManualModels(profileId: String) throws -> [String] {
        []
    }
}

private struct ScheduleEmptyCredentialSource: PlanningCredentialSource {
    func planningCredential(account: String) throws -> String? {
        nil
    }
}

private struct ScheduleTestProviderFactory: PlanningProviderFactory {
    func makePlanningAPIProvider(
        format: ProviderAPIFormat,
        credential: String,
        model: String,
        baseURL: URL
    ) throws -> any LLMProvider {
        MockProvider(script: [])
    }

    func makePlanningOAuthProvider(
        accessToken: String,
        accountId: String,
        model: String
    ) throws -> any LLMProvider {
        MockProvider(script: [])
    }
}

private func scheduleTypedUnavailableResolver()
    -> StrictPlanningProviderResolver
{
    StrictPlanningProviderResolver(
        profiles: ScheduleMissingProfileSource(),
        catalogs: ScheduleEmptyCatalogSource(),
        credentials: ScheduleEmptyCredentialSource(),
        factory: ScheduleTestProviderFactory()
    )
}

private struct ScheduleEventSnapshot: Equatable {
    let id: String
    let missionId: String?
    let cardId: String?
    let runId: String?
    let kind: String
    let payloadJson: String
    let createdAtBits: UInt64

    init(_ event: EventRecord) {
        id = event.id
        missionId = event.missionId
        cardId = event.cardId
        runId = event.runId
        kind = event.kind
        payloadJson = event.payloadJson
        createdAtBits = event.createdAt.timeIntervalSince1970.bitPattern
    }
}

private struct ScheduleMutationSnapshot: Equatable {
    let fireCount: Int
    let missionCount: Int
    let planningWorkCount: Int
    let scheduleEventCount: Int
    let events: [ScheduleEventSnapshot]
    let cursor: ScheduleEvaluationCursorRecord?
    let lastFiredAt: Date?
}

private func makeScheduleFireTestFixture(
    scheduleId: String = "schedule-a4",
    templateId: String? = nil
) throws -> ScheduleFireTestFixture {
    let database = try scheduleTempDB()
    let base = try scheduleTemplateFixture(db: database)
    var template = base.template
    if let templateId {
        template.id = templateId
    }
    try database.saveMissionTemplate(template)
    let schedule = ScheduleRecord(
        id: scheduleId,
        templateId: template.id,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        enabled: true,
        lastFiredAt: nil,
        createdAt: scheduleDate(
            2026,
            7,
            13,
            8,
            0,
            timeZoneID: "America/Los_Angeles"
        )
    )
    try database.saveSchedule(schedule)
    let runtimeProfileId = "schedule-a4-runtime"
    _ = try seedTestPlanningProfile(
        database,
        profileId: runtimeProfileId
    )
    return ScheduleFireTestFixture(
        database: database,
        camp: base.camp,
        companion: base.companion,
        template: template,
        schedule: schedule,
        runtimeProfileId: runtimeProfileId,
        plannerModel: "schedule-a4-model"
    )
}

private func scheduleSlotContext(
    _ fixture: ScheduleFireTestFixture,
    at date: Date
) throws -> ScheduleSlotContextV1 {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    return try ScheduleMath.slotContext(
        for: date,
        frequency: fixture.schedule.frequency,
        hour: fixture.schedule.hour,
        minute: fixture.schedule.minute,
        weekday: fixture.schedule.weekday,
        calendar: calendar,
        timeZone: timeZone
    )
}

private func scheduleStartCommand(
    _ fixture: ScheduleFireTestFixture,
    context: ScheduleSlotContextV1,
    preparation: ScheduleFirePreparation,
    traceId: String
) -> SchedulePlanningStartCommand {
    SchedulePlanningStartCommand(
        scheduleId: fixture.schedule.id,
        context: context,
        preparation: preparation,
        traceId: traceId
    )
}

private func scheduleSelectedPreparation(
    _ fixture: ScheduleFireTestFixture
) -> ScheduleFirePreparation {
    .selected(
        runtimeProfileId: fixture.runtimeProfileId,
        plannerModel: fixture.plannerModel
    )
}

private func scheduleReplayCommand(
    original: ScheduleFireRecord,
    effectiveTemplateId: String,
    preparation: ScheduleFirePreparation,
    replayIdempotencyKey: String,
    traceId: String
) throws -> ScheduleReplayStartCommand {
    let payload = try ScheduleReplayPayloadV1(
        originalFire: original,
        effectiveTemplateId: effectiveTemplateId,
        preparation: preparation
    )
    return ScheduleReplayStartCommand(
        originalFireId: original.id,
        replayIdempotencyKey: replayIdempotencyKey,
        payload: payload,
        replayPayloadHash: try payload.canonicalHash(),
        traceId: traceId
    )
}

private func scheduleEventCount(
    _ database: AppDatabase,
    kind: String
) throws -> Int {
    try database.pool.read {
        try EventRecord.filter(Column("kind") == kind).fetchCount($0)
    }
}

private func scheduleMutationSnapshot(
    _ fixture: ScheduleFireTestFixture
) throws -> ScheduleMutationSnapshot {
    let database = fixture.database
    return try database.pool.read { db in
        ScheduleMutationSnapshot(
            fireCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM schedule_fire"
            ) ?? 0,
            missionCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM mission"
            ) ?? 0,
            planningWorkCount: try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM durable_work
                    WHERE kind = 'planning'
                    """
            ) ?? 0,
            scheduleEventCount: try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM event
                    WHERE kind IN ('schedule_fired', 'schedule_missed')
                    """
            ) ?? 0,
            events: try EventRecord
                .order(Column.rowID)
                .fetchAll(db)
                .map(ScheduleEventSnapshot.init),
            cursor: try ScheduleEvaluationCursorRecord.fetchOne(
                db,
                sql: """
                    SELECT * FROM schedule_evaluation_cursor
                    WHERE scheduleId = ?
                    """,
                arguments: [fixture.schedule.id]
            ),
            lastFiredAt: try Date.fetchOne(
                db,
                sql: "SELECT lastFiredAt FROM schedule WHERE id = ?",
                arguments: [fixture.schedule.id]
            )
        )
    }
}

private func scheduleWriterTotalChanges(
    _ fixture: ScheduleFireTestFixture
) -> Int {
    fixture.database.pool.writeWithoutTransaction { database in
        database.totalChangesCount
    }
}

private func scheduleEvent(
    _ database: AppDatabase,
    fireId: String,
    kind: String
) throws -> EventRecord {
    try database.pool.read { db in
        let events = try EventRecord.fetchAll(
            db,
            sql: """
                SELECT * FROM event
                WHERE kind = ?
                  AND json_extract(payloadJson, '$.fireId') = ?
                ORDER BY rowid
                """,
            arguments: [kind, fireId]
        )
        guard events.count == 1 else {
            throw ScheduleFireReplayIntegrityError(fireId: fireId)
        }
        return events[0]
    }
}

private func scheduleWithForeignKeysDisabled(
    _ database: Database,
    body: () throws -> Void
) throws {
    try database.execute(sql: "PRAGMA foreign_keys = OFF")
    do {
        try body()
    } catch {
        let original = error
        try database.execute(sql: "PRAGMA foreign_keys = ON")
        throw original
    }
    try database.execute(sql: "PRAGMA foreign_keys = ON")
}

private struct ScheduleCoreGraphSnapshot: Equatable {
    let fires: [ScheduleFireRecord]
    let cursor: ScheduleEvaluationCursorRecord?
    let lastFiredAtBits: UInt64?
    let squadCount: Int
    let missionCount: Int
    let planningWorkCount: Int
}

private func scheduleCoreGraphSnapshot(
    _ fixture: ScheduleFireTestFixture
) throws -> ScheduleCoreGraphSnapshot {
    let fires = try fixture.database.scheduleFires(
        scheduleId: fixture.schedule.id
    )
    let cursor = try fixture.database.scheduleEvaluationCursor(
        scheduleId: fixture.schedule.id
    )
    let lastFiredAtBits = try fixture.database
        .schedule(id: fixture.schedule.id)?
        .lastFiredAt?
        .timeIntervalSince1970
        .bitPattern
    return try fixture.database.pool.read { db in
        ScheduleCoreGraphSnapshot(
            fires: fires,
            cursor: cursor,
            lastFiredAtBits: lastFiredAtBits,
            squadCount: try SquadRecord.fetchCount(db),
            missionCount: try MissionRecord.fetchCount(db),
            planningWorkCount: try DurableWorkRecord
                .filter(Column("kind") == DurableWorkKind.planning.rawValue)
                .fetchCount(db)
        )
    }
}

private struct ScheduleStartedReplayWinnerFixture {
    let fixture: ScheduleFireTestFixture
    let command: ScheduleReplayStartCommand
    let winner: ScheduleFireCommitResult
}

private func makeScheduleStartedReplayWinnerFixture(
    label: String
) throws -> ScheduleStartedReplayWinnerFixture {
    let fixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-winner-\(label)"
    )
    let original = try fixture.database.startScheduledMission(
        scheduleStartCommand(
            fixture,
            context: try scheduleSlotContext(
                fixture,
                at: scheduleDate(
                    2026,
                    7,
                    18,
                    9,
                    0,
                    timeZoneID: "America/Los_Angeles"
                )
            ),
            preparation: .unavailable,
            traceId: "trace-winner-\(label)-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let command = try scheduleReplayCommand(
        original: original.fire,
        effectiveTemplateId: fixture.template.id,
        preparation: scheduleSelectedPreparation(fixture),
        replayIdempotencyKey:
            "schedule-replay:\(UUID().uuidString.lowercased())",
        traceId: "trace-winner-\(label)"
    )
    let winner = try fixture.database.replayMissedScheduleFire(
        command,
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    guard winner.fire.state == .started,
          winner.missionId != nil,
          winner.workId != nil
    else {
        throw ScheduleFireReplayIntegrityError(fireId: winner.fire.id)
    }
    return ScheduleStartedReplayWinnerFixture(
        fixture: fixture,
        command: command,
        winner: winner
    )
}

private enum ScheduleStartedWinnerCorruption:
    String, CaseIterable, Sendable
{
    case firedCreatedAt
    case firedCardId
    case firedRunId
    case planStartedPayload
    case planningWorkInputSemantic
    case planningWorkInputPayloadMismatch
    case missionIdentitySemantic
    case oppositeEvent
}

private func corruptScheduleStartedWinner(
    _ setup: ScheduleStartedReplayWinnerFixture,
    corruption: ScheduleStartedWinnerCorruption
) throws {
    let fire = setup.winner.fire
    let missionId = try #require(setup.winner.missionId)
    let workId = try #require(setup.winner.workId)
    try setup.fixture.database.pool.write { db in
        switch corruption {
        case .firedCreatedAt, .firedCardId, .firedRunId,
             .planStartedPayload, .planningWorkInputPayloadMismatch,
             .missionIdentitySemantic:
            try db.execute(
                sql: "DROP TRIGGER event_reject_update_except_camp_redaction"
            )
        case .planningWorkInputSemantic, .oppositeEvent:
            break
        }
        switch corruption {
        case .firedCreatedAt:
            try db.execute(
                sql: """
                    UPDATE event
                    SET createdAt = ?
                    WHERE kind = ?
                      AND json_extract(payloadJson, '$.fireId') = ?
                    """,
                arguments: [
                    fire.createdAt.timeIntervalSince1970 + 1,
                    EventKind.scheduleFired,
                    fire.id,
                ]
            )
        case .firedCardId:
            try db.execute(
                sql: """
                    UPDATE event
                    SET cardId = 'corrupt-card-id'
                    WHERE kind = ?
                      AND json_extract(payloadJson, '$.fireId') = ?
                    """,
                arguments: [EventKind.scheduleFired, fire.id]
            )
        case .firedRunId:
            try db.execute(
                sql: """
                    UPDATE event
                    SET runId = 'corrupt-run-id'
                    WHERE kind = ?
                      AND json_extract(payloadJson, '$.fireId') = ?
                    """,
                arguments: [EventKind.scheduleFired, fire.id]
            )
        case .planStartedPayload:
            try db.execute(
                sql: """
                    UPDATE event
                    SET payloadJson = '{"corrupt":true}'
                    WHERE missionId = ? AND kind = ?
                """,
                arguments: [missionId, EventKind.planStarted]
            )
        case .planningWorkInputSemantic:
            guard let work = try DurableWorkRecord.fetchOne(
                db,
                key: workId
            ) else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let inputBytes = Data(work.inputJson.utf8)
            let validInput = try JSONDecoder().decode(
                PlanningWorkInput.self,
                from: inputBytes
            )
            guard try CanonicalJSONV1.encode(validInput) == inputBytes else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let runtimeMarker =
                "\"runtimeProfileId\":\"\(setup.fixture.runtimeProfileId)\""
            guard work.inputJson.components(
                separatedBy: runtimeMarker
            ).count == 2 else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let corruptInputJson = work.inputJson.replacingOccurrences(
                of: runtimeMarker,
                with: "\"runtimeProfileId\":\"\""
            )
            let corruptInputBytes = Data(corruptInputJson.utf8)
            let semanticError: InvalidPlanningPayloadError
            do {
                _ = try JSONDecoder().decode(
                    PlanningWorkInput.self,
                    from: corruptInputBytes
                )
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            } catch let error as InvalidPlanningPayloadError {
                semanticError = error
            }
            guard semanticError == .emptyRuntimeProfileId else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            try db.execute(
                sql: """
                    UPDATE durable_work
                    SET inputJson = ?, inputHash = ?
                    WHERE id = ?
                    """,
                arguments: [
                    corruptInputJson,
                    CanonicalJSONV1.sha256Hex(corruptInputBytes),
                    workId,
                ]
            )
        case .planningWorkInputPayloadMismatch:
            guard let work = try DurableWorkRecord.fetchOne(
                db,
                key: workId
            ) else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let inputBytes = Data(work.inputJson.utf8)
            let validInput = try JSONDecoder().decode(
                PlanningWorkInput.self,
                from: inputBytes
            )
            guard try CanonicalJSONV1.encode(validInput) == inputBytes
            else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let events = try EventRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM event
                    WHERE missionId = ? AND kind = ?
                    ORDER BY rowid
                    """,
                arguments: [missionId, EventKind.missionCreated]
            )
            guard events.count == 1 else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let identityEvent = events[0]
            let identityBytes = Data(identityEvent.payloadJson.utf8)
            let identity = try JSONDecoder().decode(
                MissionPlanningStartIdentityV1.self,
                from: identityBytes
            )
            guard try CanonicalJSONV1.encode(identity) == identityBytes,
                  identity.planningInput == validInput
            else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let differentInput = try PlanningWorkInput(
                plannerModel: "coherent-different-model",
                runtimeProfileId: "coherent-different-runtime"
            )
            let differentInputBytes = try CanonicalJSONV1.encode(
                differentInput
            )
            let differentIdentity = try MissionPlanningStartIdentityV1(
                contractVersion: identity.contractVersion,
                goal: identity.goal,
                companionIds: identity.companionIds,
                workspacePath: identity.workspacePath,
                budgetTokens: identity.budgetTokens,
                campId: identity.campId,
                autonomy: identity.autonomy,
                planningInput: differentInput
            )
            try db.execute(
                sql: """
                    UPDATE durable_work
                    SET inputJson = ?, inputHash = ?
                    WHERE id = ?
                    """,
                arguments: [
                    String(decoding: differentInputBytes, as: UTF8.self),
                    CanonicalJSONV1.sha256Hex(differentInputBytes),
                    workId,
                ]
            )
            guard db.changesCount == 1 else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            try db.execute(
                sql: "UPDATE event SET payloadJson = ? WHERE id = ?",
                arguments: [
                    String(
                        decoding: try CanonicalJSONV1.encode(
                            differentIdentity
                        ),
                        as: UTF8.self
                    ),
                    identityEvent.id,
                ]
            )
        case .missionIdentitySemantic:
            let events = try EventRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM event
                    WHERE missionId = ? AND kind = ?
                    ORDER BY rowid
                    """,
                arguments: [missionId, EventKind.missionCreated]
            )
            guard events.count == 1 else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let identityEvent = events[0]
            let identityBytes = Data(identityEvent.payloadJson.utf8)
            let validIdentity = try JSONDecoder().decode(
                MissionPlanningStartIdentityV1.self,
                from: identityBytes
            )
            guard try CanonicalJSONV1.encode(validIdentity)
                == identityBytes
            else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let budgetTokens = try #require(
                setup.fixture.template.budgetTokens
            )
            let budgetMarker = "\"budgetTokens\":\(budgetTokens)"
            guard identityEvent.payloadJson.components(
                separatedBy: budgetMarker
            ).count == 2 else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            let corruptIdentityJson = identityEvent.payloadJson
                .replacingOccurrences(
                    of: budgetMarker,
                    with: "\"budgetTokens\":0"
                )
            let corruptIdentityBytes = Data(corruptIdentityJson.utf8)
            let semanticError: InvalidPlanningPayloadError
            do {
                _ = try JSONDecoder().decode(
                    MissionPlanningStartIdentityV1.self,
                    from: corruptIdentityBytes
                )
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            } catch let error as InvalidPlanningPayloadError {
                semanticError = error
            }
            guard semanticError == .invalidBudgetTokens else {
                throw ScheduleFireReplayIntegrityError(fireId: fire.id)
            }
            try db.execute(
                sql: "UPDATE event SET payloadJson = ? WHERE id = ?",
                arguments: [corruptIdentityJson, identityEvent.id]
            )
        case .oppositeEvent:
            let payload = ScheduleMissedPayloadV1(
                fireId: fire.id,
                scheduleId: fire.scheduleId,
                templateId: fire.templateId,
                slotKey: fire.slotKey,
                scheduledAt: fire.scheduledAt.timeIntervalSince1970,
                replayOfFireId: fire.replayOfFireId,
                traceId: fire.traceId,
                errorCode: "schedule_runtime_unavailable",
                errorMessage: "定时行动缺少可用的规划运行时。"
            )
            _ = try AppDatabase.appendLegacyEventAndScope(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.scheduleMissed,
                payloadJSON: String(
                    decoding: try CanonicalJSONV1.encode(payload),
                    as: UTF8.self
                ),
                createdAt: fire.createdAt
            )
        }
        guard db.changesCount == 1 else {
            throw ScheduleFireReplayIntegrityError(fireId: fire.id)
        }
    }
}

private enum ScheduleReplayRaceOutcome: @unchecked Sendable {
    case success(ScheduleFireCommitResult)
    case failure(any Error)
}

private struct ScheduleReplayRaceFailure:
    Error, @unchecked Sendable, CustomStringConvertible
{
    let index: Int
    let underlying: any Error

    var description: String {
        "A4 replay race operation \(index) failed: \(underlying)"
    }
}

private enum ScheduleReplayRaceHarnessError: Error, Equatable {
    case duplicateArrival(Int)
    case duplicateOutcome(Int)
    case missingOutcome(Int)
    case peerAborted(index: Int, abortedBy: Int)
}

private final class ScheduleReplayRaceState: @unchecked Sendable {
    private let condition = NSCondition()
    private var arrivals: Set<Int> = []
    private var released = false
    private var abortedBy: Int?
    private var outcomes: [ScheduleReplayRaceOutcome?] = [nil, nil]
    private var storageFailure: ScheduleReplayRaceHarnessError?

    func rendezvous(index: Int) throws {
        condition.lock()
        defer { condition.unlock() }
        guard arrivals.insert(index).inserted else {
            abortLocked(index: index)
            throw ScheduleReplayRaceHarnessError.duplicateArrival(index)
        }
        if arrivals.count == 2 {
            released = true
            condition.broadcast()
        }
        while !released, abortedBy == nil {
            condition.wait()
        }
        if let abortedBy {
            throw ScheduleReplayRaceHarnessError.peerAborted(
                index: index,
                abortedBy: abortedBy
            )
        }
    }

    func store(index: Int, outcome: ScheduleReplayRaceOutcome) {
        condition.lock()
        defer { condition.unlock() }
        guard outcomes.indices.contains(index), outcomes[index] == nil else {
            storageFailure = .duplicateOutcome(index)
            abortLocked(index: index)
            return
        }
        outcomes[index] = outcome
    }

    func finished() throws -> [ScheduleReplayRaceOutcome] {
        condition.lock()
        defer { condition.unlock() }
        if let storageFailure {
            throw storageFailure
        }
        guard let first = outcomes[0] else {
            throw ScheduleReplayRaceHarnessError.missingOutcome(0)
        }
        guard let second = outcomes[1] else {
            throw ScheduleReplayRaceHarnessError.missingOutcome(1)
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

private struct ScheduleReplayRaceResult: Sendable {
    let results: [ScheduleFireCommitResult]
    let resolverCounts: [Int]
}

private func runScheduleReplayRace(
    database: AppDatabase,
    firstCommand: ScheduleReplayStartCommand,
    secondCommand: ScheduleReplayStartCommand
) async throws -> ScheduleReplayRaceResult {
    let state = ScheduleReplayRaceState()
    let firstResolver = ScheduleTestResolverRecorder(onResolve: {
        try state.rendezvous(index: 0)
    })
    let secondResolver = ScheduleTestResolverRecorder(onResolve: {
        try state.rendezvous(index: 1)
    })
    let group = DispatchGroup()
    group.enter()
    group.enter()

    let firstThread = Thread {
        defer { group.leave() }
        do {
            state.store(
                index: 0,
                outcome: .success(
                    try database.replayMissedScheduleFire(
                        firstCommand,
                        planningProviderResolver: firstResolver
                    )
                )
            )
        } catch {
            state.store(index: 0, outcome: .failure(error))
        }
    }
    firstThread.name = "AgentLoop.A4ReplayRace.first"
    let secondThread = Thread {
        defer { group.leave() }
        do {
            state.store(
                index: 1,
                outcome: .success(
                    try database.replayMissedScheduleFire(
                        secondCommand,
                        planningProviderResolver: secondResolver
                    )
                )
            )
        } catch {
            state.store(index: 1, outcome: .failure(error))
        }
    }
    secondThread.name = "AgentLoop.A4ReplayRace.second"

    let outcomes: [ScheduleReplayRaceOutcome] = try await
        withCheckedThrowingContinuation { continuation in
            firstThread.start()
            secondThread.start()
            DispatchQueue(label: "AgentLoop.A4ReplayRace.completion").async {
                group.wait()
                continuation.resume(with: Result {
                    try state.finished()
                })
            }
        }
    var results: [ScheduleFireCommitResult] = []
    for (index, outcome) in outcomes.enumerated() {
        switch outcome {
        case .success(let result):
            results.append(result)
        case .failure(let error):
            throw ScheduleReplayRaceFailure(
                index: index,
                underlying: error
            )
        }
    }
    return ScheduleReplayRaceResult(
        results: results,
        resolverCounts: [
            firstResolver.callCount,
            secondResolver.callCount,
        ]
    )
}

@Test func scheduleMathDailyNextFireSameDay() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 8, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 9,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-14 09:30")
}

@Test func scheduleMathDailyNextFireMovesToTomorrowAfterSlot() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 10, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 9,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-15 09:30")
}

@Test func scheduleMathWeeklyNextFireSameWeek() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 8, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 4,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-15 09:00")
}

@Test func scheduleMathWeeklyNextFireWrapsAcrossWeek() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 16, 8, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 4,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-22 09:00")
}

@Test func scheduleMathSpringForwardUsesNextValidLocalTime() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 3, 8, 0, 30, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 2,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    // .nextTime 语义:被春令时跳过的 02:30 顺延到首个有效时刻 03:00(而非保留分钟数的 03:30)
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-03-08 03:00")
}

@Test func scheduleMathFallBackChoosesFirstRepeatedLocalTime() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 11, 1, 0, 30, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 1,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-11-01 01:30")
}

@Test func scheduleMathPreviousFireIsInclusive() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let exact = scheduleDate(
        2026,
        7,
        14,
        9,
        0,
        timeZoneID: "America/Los_Angeles"
    )
    let inclusive = try #require(ScheduleMath.previousFireDate(
        onOrBefore: exact,
        frequency: .daily,
        hour: 9,
        minute: 0,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(inclusive == exact)

    let fractionalBefore = exact.addingTimeInterval(-0.5)
    let prior = try #require(ScheduleMath.previousFireDate(
        onOrBefore: fractionalBefore,
        frequency: .daily,
        hour: 9,
        minute: 0,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(prior <= fractionalBefore)
    #expect(
        scheduleStamp(prior, timeZoneID: "America/Los_Angeles")
            == "2026-07-13 09:00"
    )

    let (utcCalendar, utcTimeZone) = scheduleCalendar("UTC")
    let exactEpochBoundaries = [
        Date(timeIntervalSince1970: 0),
        Date(timeIntervalSinceReferenceDate: 0),
        Date(timeIntervalSince1970: -86_400),
        Date(timeIntervalSinceReferenceDate: 86_400),
    ]
    for boundary in exactEpochBoundaries {
        let exactPrevious = try #require(
            ScheduleMath.previousFireDate(
                onOrBefore: boundary,
                frequency: .daily,
                hour: 0,
                minute: 0,
                calendar: utcCalendar,
                timeZone: utcTimeZone
            )
        )
        #expect(
            exactPrevious.timeIntervalSinceReferenceDate.bitPattern
                == boundary.timeIntervalSinceReferenceDate.bitPattern
        )

        let justBefore = boundary.addingTimeInterval(-0.5)
        let strictlyPrior = try #require(
            ScheduleMath.previousFireDate(
                onOrBefore: justBefore,
                frequency: .daily,
                hour: 0,
                minute: 0,
                calendar: utcCalendar,
                timeZone: utcTimeZone
            )
        )
        #expect(strictlyPrior <= justBefore)
        #expect(
            strictlyPrior.timeIntervalSinceReferenceDate.bitPattern
                == boundary.addingTimeInterval(-86_400)
                    .timeIntervalSinceReferenceDate.bitPattern
        )
    }
}

@Test func scheduleMathMisfireDetectsPreviousUnfiredSlot() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 10, 0, timeZoneID: "America/Los_Angeles")
    let createdAt = scheduleDate(2026, 7, 13, 8, 0, timeZoneID: "America/Los_Angeles")
    let missed = try #require(try ScheduleMath.latestUnevaluatedSlot(
        now: now,
        createdAt: createdAt,
        cursor: nil,
        frequency: .daily,
        hour: 9,
        minute: 0,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(
        scheduleStamp(
            missed.scheduledAt,
            timeZoneID: "America/Los_Angeles"
        ) == "2026-07-14 09:00"
    )
    #expect(missed.calendarId == "gregorian")
    #expect(missed.timeZoneId == "America/Los_Angeles")
}

@Test func scheduleMathMisfireIgnoresScheduleCreatedAfterSlot() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 10, 0, timeZoneID: "America/Los_Angeles")
    let createdAt = scheduleDate(2026, 7, 14, 9, 45, timeZoneID: "America/Los_Angeles")
    let missed = try ScheduleMath.latestUnevaluatedSlot(
        now: now,
        createdAt: createdAt,
        cursor: nil,
        frequency: .daily,
        hour: 9,
        minute: 0,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(missed == nil)
}

@Test func scheduleMathSameSlotDedupeCoversDailyAndWeekly() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let fire = scheduleDate(2026, 7, 14, 9, 0, timeZoneID: "America/Los_Angeles")
    let first = try ScheduleMath.slotContext(
        for: fire,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        calendar: calendar,
        timeZone: timeZone
    )
    let repeated = try ScheduleMath.slotContext(
        for: fire,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(repeated == first)

    let nextDay = scheduleDate(
        2026,
        7,
        15,
        9,
        0,
        timeZoneID: "America/Los_Angeles"
    )
    let later = try ScheduleMath.slotContext(
        for: nextDay,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(later.slotKey != first.slotKey)

    let weekly = try ScheduleMath.slotContext(
        for: fire,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 3,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(weekly.slotKey != first.slotKey)
}

@Test func scheduleFireDSTSlotKeysAreStable() throws {
    let (calendar, timeZone) = scheduleCalendar(
        "America/Los_Angeles"
    )
    let springAnchor = scheduleDate(
        2026,
        3,
        8,
        0,
        30,
        timeZoneID: "America/Los_Angeles"
    )
    let springFire = try #require(ScheduleMath.nextFireDate(
        after: springAnchor,
        frequency: .daily,
        hour: 2,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    let spring = try ScheduleMath.slotContext(
        for: springFire,
        frequency: .daily,
        hour: 2,
        minute: 30,
        weekday: nil,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(
        spring.slotKey
            == "schedule-slot:v1|f=daily|c=9:gregorian|"
                + "z=19:America/Los_Angeles|p=02:30:0|"
                + "r=1:2026:3:8:03:00:00:000000000|"
                + "o=-25200|i=41da6b5228000000"
    )
    #expect(
        try ScheduleMath.slotContext(
            for: springFire,
            frequency: .daily,
            hour: 2,
            minute: 30,
            weekday: nil,
            calendar: calendar,
            timeZone: timeZone
        ) == spring
    )

    let firstFallDate = Date(timeIntervalSince1970: 1_793_521_800)
    let secondFallDate = Date(timeIntervalSince1970: 1_793_525_400)
    let firstFall = try ScheduleMath.slotContext(
        for: firstFallDate,
        frequency: .daily,
        hour: 1,
        minute: 30,
        weekday: nil,
        calendar: calendar,
        timeZone: timeZone
    )
    let secondFall = try ScheduleMath.slotContext(
        for: secondFallDate,
        frequency: .daily,
        hour: 1,
        minute: 30,
        weekday: nil,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(
        firstFall.slotKey
            == "schedule-slot:v1|f=daily|c=9:gregorian|"
                + "z=19:America/Los_Angeles|p=01:30:0|"
                + "r=1:2026:11:1:01:30:00:000000000|"
                + "o=-25200|i=41dab9be22000000"
    )
    #expect(
        secondFall.slotKey
            == "schedule-slot:v1|f=daily|c=9:gregorian|"
                + "z=19:America/Los_Angeles|p=01:30:0|"
                + "r=1:2026:11:1:01:30:00:000000000|"
                + "o=-28800|i=41dab9c1a6000000"
    )
    #expect(firstFall.slotKey != secondFall.slotKey)
    let weekly = try ScheduleMath.slotContext(
        for: firstFallDate,
        frequency: .weekly,
        hour: 1,
        minute: 30,
        weekday: 1,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(weekly.slotKey != firstFall.slotKey)
    let (utcCalendar, utcTimeZone) = scheduleCalendar("UTC")
    let utc = try ScheduleMath.slotContext(
        for: firstFallDate,
        frequency: .daily,
        hour: 1,
        minute: 30,
        weekday: nil,
        calendar: utcCalendar,
        timeZone: utcTimeZone
    )
    #expect(utc.slotKey != firstFall.slotKey)

    #expect(throws: ScheduleSlotComponentsUnavailableError.self) {
        _ = try ScheduleSlotComponentsV1(
            validating: DateComponents(
                era: 1,
                year: 2026,
                month: 7,
                day: 14,
                hour: 9,
                minute: 0,
                second: 0
            )
        )
    }
    #expect(throws: UnsupportedScheduleCalendarError.self) {
        _ = try ScheduleMath.slotContext(
            for: firstFallDate,
            frequency: .daily,
            hour: 1,
            minute: 30,
            weekday: nil,
            calendar: Calendar(identifier: .buddhist),
            timeZone: timeZone
        )
    }
    let negativeZero = try ScheduleMath.slotContext(
        for: Date(timeIntervalSince1970: -0.0),
        frequency: .daily,
        hour: 0,
        minute: 0,
        weekday: nil,
        calendar: utcCalendar,
        timeZone: utcTimeZone
    )
    #expect(negativeZero.scheduledAtInstantBits == "0000000000000000")
    #expect(
        negativeZero.scheduledAt.timeIntervalSince1970.bitPattern == 0
    )
    _ = try ScheduleMath.slotContext(
        for: Date(timeIntervalSince1970: -62_135_596_800),
        frequency: .daily,
        hour: 0,
        minute: 0,
        weekday: nil,
        calendar: utcCalendar,
        timeZone: utcTimeZone
    )
    for seconds in [
        253_402_300_800.0,
        10_000_000_000_000_000.0,
        Double.greatestFiniteMagnitude,
        -Double.greatestFiniteMagnitude,
    ] {
        #expect(throws: ScheduleSlotComponentsUnavailableError.self) {
            _ = try ScheduleMath.slotContext(
                for: Date(timeIntervalSince1970: seconds),
                frequency: .daily,
                hour: 0,
                minute: 0,
                weekday: nil,
                calendar: utcCalendar,
                timeZone: utcTimeZone
            )
        }
    }
    for seconds in [Double.nan, Double.infinity, -Double.infinity] {
        #expect(throws: InvalidSchedulePlanningFireTimeError.self) {
            _ = try ScheduleMath.slotContext(
                for: Date(timeIntervalSince1970: seconds),
                frequency: .daily,
                hour: 0,
                minute: 0,
                weekday: nil,
                calendar: utcCalendar,
                timeZone: utcTimeZone
            )
        }
    }
}

@Test func scheduleValidationFailureAdvancesEvaluationCursorButNotLastFiredAt()
    throws
{
    let scheduledAt = scheduleDate(
        2026,
        7,
        14,
        9,
        0,
        timeZoneID: "America/Los_Angeles"
    )

    func requireTerminalFailure(
        label: String,
        preparation: ScheduleFirePreparation,
        expectedCode: String,
        expectedMessage: String,
        resolver: any PlanningProviderResolver,
        mutate: (ScheduleFireTestFixture, inout ScheduleRecord) throws -> Void
    ) throws {
        let fixture = try makeScheduleFireTestFixture(
            scheduleId: "schedule-a4-\(label)"
        )
        var capturedSchedule = fixture.schedule
        try mutate(fixture, &capturedSchedule)
        let (calendar, timeZone) = scheduleCalendar(
            "America/Los_Angeles"
        )
        let context = try ScheduleMath.slotContext(
            for: scheduledAt,
            frequency: capturedSchedule.frequency,
            hour: capturedSchedule.hour,
            minute: capturedSchedule.minute,
            weekday: capturedSchedule.weekday,
            calendar: calendar,
            timeZone: timeZone
        )
        let result = try fixture.database.startScheduledMission(
            SchedulePlanningStartCommand(
                scheduleId: capturedSchedule.id,
                context: context,
                preparation: preparation,
                traceId: "trace-\(label)"
            ),
            planningProviderResolver: resolver
        )
        let snapshot = try scheduleMutationSnapshot(fixture)
        let missedEvent = try scheduleEvent(
            fixture.database,
            fireId: result.fire.id,
            kind: EventKind.scheduleMissed
        )
        let missedPayload = try JSONDecoder().decode(
            ScheduleMissedPayloadV1.self,
            from: Data(missedEvent.payloadJson.utf8)
        )
        let eventCreatedAtStorage = try fixture.database.pool.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT typeof(createdAt) FROM event WHERE id = ?",
                arguments: [missedEvent.id]
            )
        }

        #expect(result.disposition == .inserted)
        #expect(result.fire.state == .failed)
        #expect(result.fire.errorCode == expectedCode)
        #expect(result.fire.errorMessage == expectedMessage)
        #expect(result.fire.missionId == nil)
        #expect(result.missionId == nil)
        #expect(result.workId == nil)
        #expect(snapshot.fireCount == 1)
        #expect(snapshot.missionCount == 0)
        #expect(snapshot.planningWorkCount == 0)
        #expect(snapshot.scheduleEventCount == 1)
        #expect(snapshot.cursor?.version == 1)
        #expect(snapshot.cursor?.lastEvaluatedSlotKey == context.slotKey)
        #expect(
            snapshot.cursor?.lastEvaluatedScheduledAt
                .timeIntervalSince1970.bitPattern
                == context.scheduledAt.timeIntervalSince1970.bitPattern
        )
        #expect(snapshot.lastFiredAt == nil)
        #expect(missedEvent.missionId == nil)
        #expect(missedEvent.cardId == nil)
        #expect(missedEvent.runId == nil)
        #expect(
            missedEvent.createdAt.timeIntervalSince1970.bitPattern
                == result.fire.createdAt.timeIntervalSince1970.bitPattern
        )
        #expect(
            eventCreatedAtStorage == "real"
                || eventCreatedAtStorage == "integer"
        )
        #expect(missedPayload.fireId == result.fire.id)
        #expect(missedPayload.scheduleId == result.fire.scheduleId)
        #expect(missedPayload.templateId == result.fire.templateId)
        #expect(missedPayload.slotKey == result.fire.slotKey)
        #expect(
            missedPayload.scheduledAt.bitPattern
                == result.fire.scheduledAt.timeIntervalSince1970.bitPattern
        )
        #expect(
            missedPayload.scheduledAtInstantBits
                == context.scheduledAtInstantBits
        )
        #expect(missedPayload.replayOfFireId == nil)
        #expect(missedPayload.traceId == result.fire.traceId)
        #expect(missedPayload.errorCode == expectedCode)
        #expect(missedPayload.errorMessage == expectedMessage)
        #expect(
            try scheduleEventCount(
                fixture.database,
                kind: EventKind.scheduleMissed
            ) == 1
        )
    }

    try requireTerminalFailure(
        label: "disabled",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_disabled",
        expectedMessage: "定时行动已停用。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE schedule SET enabled = 0 WHERE id = ?",
                arguments: [fixture.schedule.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "configuration",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_configuration_invalid",
        expectedMessage: "定时行动配置无效。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, captured in
        captured.weekday = 1
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE schedule SET weekday = 1 WHERE id = ?",
                arguments: [fixture.schedule.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "archived",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_camp_archived",
        expectedMessage: "定时行动所属营地已归档。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE camp SET archived = 1 WHERE id = ?",
                arguments: [fixture.camp.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "template",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_template_invalid",
        expectedMessage: "定时行动模板配置无效。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE mission_template SET goal = '' WHERE id = ?",
                arguments: [fixture.template.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "missing-cow",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_companion_missing",
        expectedMessage: "定时行动模板引用的伙伴不存在。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE mission_template SET companionIdsJson = ? WHERE id = ?",
                arguments: [
                    try MissionTemplateRecord.companionIdsJSON([
                        "missing-companion:\(fixture.template.id)"
                    ]),
                    fixture.template.id,
                ]
            )
        }
    }
    try requireTerminalFailure(
        label: "wrong-camp-cow",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_companion_wrong_camp",
        expectedMessage: "定时行动模板中的伙伴不属于该营地。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE companion SET campId = NULL WHERE id = ?",
                arguments: [fixture.companion.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "global-missing-before-wrong-camp",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_companion_missing",
        expectedMessage: "定时行动模板引用的伙伴不存在。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        let companionIdsJson = String(
            decoding: try CanonicalJSONV1.encode([
                fixture.companion.id,
                "schedule-a4-global-missing-companion",
            ]),
            as: UTF8.self
        )
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE companion SET campId = NULL WHERE id = ?",
                arguments: [fixture.companion.id]
            )
            try $0.execute(
                sql: """
                    UPDATE mission_template
                    SET companionIdsJson = ?
                    WHERE id = ?
                    """,
                arguments: [companionIdsJson, fixture.template.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "malformed-companion-json",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_template_invalid",
        expectedMessage: "定时行动模板配置无效。",
        resolver: ScheduleTestResolverRecorder()
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: """
                    UPDATE mission_template
                    SET companionIdsJson = '{'
                    WHERE id = ?
                    """,
                arguments: [fixture.template.id]
            )
        }
    }
    try requireTerminalFailure(
        label: "runtime-unavailable",
        preparation: .unavailable,
        expectedCode: "schedule_runtime_unavailable",
        expectedMessage: "定时行动的运行配置不可用。",
        resolver: ScheduleTestResolverRecorder(onResolve: {
            Issue.record("unavailable preparation must not resolve provider")
        })
    ) { _, _ in }
    try requireTerminalFailure(
        label: "profile-missing",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_runtime_unavailable",
        expectedMessage: "定时行动的运行配置不可用。",
        resolver: ScheduleTestResolverRecorder(onResolve: {
            Issue.record("missing profile must not resolve provider")
        })
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "DELETE FROM runtime_profile WHERE id = ?",
                arguments: [fixture.runtimeProfileId]
            )
        }
    }
    try requireTerminalFailure(
        label: "profile-cli",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_runtime_unavailable",
        expectedMessage: "定时行动的运行配置不可用。",
        resolver: ScheduleTestResolverRecorder(onResolve: {
            Issue.record("CLI profile must not resolve provider")
        })
    ) { fixture, _ in
        try fixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE runtime_profile SET kind = 'cli_codex' WHERE id = ?",
                arguments: [fixture.runtimeProfileId]
            )
        }
    }
    try requireTerminalFailure(
        label: "provider",
        preparation: .selected(
            runtimeProfileId: "schedule-a4-runtime",
            plannerModel: "schedule-a4-model"
        ),
        expectedCode: "schedule_provider_unavailable",
        expectedMessage: "定时行动的规划服务暂不可用。",
        resolver: scheduleTypedUnavailableResolver()
    ) { _, _ in }
    try requireTerminalFailure(
        label: "offline",
        preparation: .forcedFailure,
        expectedCode: "schedule_missed_while_offline",
        expectedMessage: "定时行动在应用离线期间错过了触发时间。",
        resolver: ScheduleTestResolverRecorder(onResolve: {
            Issue.record("forced offline failure must not resolve provider")
        })
    ) { _, _ in }

    func requireMissingScope(
        label: String,
        expectedError: RecordNotFoundError,
        mutate: (ScheduleFireTestFixture) throws -> Void
    ) throws {
        let fixture = try makeScheduleFireTestFixture(
            scheduleId: "schedule-a4-missing-scope-\(label)"
        )
        let context = try scheduleSlotContext(fixture, at: scheduledAt)
        try mutate(fixture)
        let before = try scheduleMutationSnapshot(fixture)
        let resolver = ScheduleTestResolverRecorder(onResolve: {
            Issue.record("missing \(label) scope must skip provider")
        })
        #expect(throws: expectedError) {
            _ = try fixture.database.startScheduledMission(
                scheduleStartCommand(
                    fixture,
                    context: context,
                    preparation: scheduleSelectedPreparation(fixture),
                    traceId: "trace-missing-scope-\(label)"
                ),
                planningProviderResolver: resolver
            )
        }
        #expect(resolver.callCount == 0)
        #expect(try scheduleMutationSnapshot(fixture) == before)
    }

    try requireMissingScope(
        label: "schedule",
        expectedError: RecordNotFoundError(
            table: ScheduleRecord.databaseTableName,
            id: "schedule-a4-missing-scope-schedule"
        )
    ) { fixture in
        try fixture.database.deleteSchedule(id: fixture.schedule.id)
    }
    try requireMissingScope(
        label: "template",
        expectedError: RecordNotFoundError(
            table: MissionTemplateRecord.databaseTableName,
            id: "schedule-a4-absent-template"
        )
    ) { fixture in
        try fixture.database.pool.writeWithoutTransaction { db in
            try scheduleWithForeignKeysDisabled(db) {
                try db.execute(
                    sql: "UPDATE schedule SET templateId = ? WHERE id = ?",
                    arguments: [
                        "schedule-a4-absent-template",
                        fixture.schedule.id,
                    ]
                )
            }
        }
    }
    try requireMissingScope(
        label: "camp",
        expectedError: RecordNotFoundError(
            table: CampRecord.databaseTableName,
            id: "schedule-a4-absent-camp"
        )
    ) { fixture in
        try fixture.database.pool.writeWithoutTransaction { db in
            try scheduleWithForeignKeysDisabled(db) {
                try db.execute(
                    sql: """
                        UPDATE mission_template SET campId = ? WHERE id = ?
                        """,
                    arguments: [
                        "schedule-a4-absent-camp",
                        fixture.template.id,
                    ]
                )
            }
        }
    }

    let rollbackScenarios: [(String, String)] = [
        (
            "work",
            """
            CREATE TRIGGER fail_a4_work_insert
            BEFORE INSERT ON durable_work
            BEGIN SELECT RAISE(ABORT, 'injected work failure'); END
            """
        ),
        (
            "event",
            """
            CREATE TRIGGER fail_a4_schedule_event
            BEFORE INSERT ON event
            WHEN NEW.kind = 'schedule_fired'
            BEGIN SELECT RAISE(ABORT, 'injected event failure'); END
            """
        ),
    ]
    for (label, triggerSQL) in rollbackScenarios {
        let fixture = try makeScheduleFireTestFixture(
            scheduleId: "schedule-a4-rollback-\(label)"
        )
        let context = try scheduleSlotContext(fixture, at: scheduledAt)
        try fixture.database.pool.write {
            try $0.execute(sql: triggerSQL)
        }
        let before = try scheduleMutationSnapshot(fixture)
        #expect(throws: DatabaseError.self) {
            _ = try fixture.database.startScheduledMission(
                scheduleStartCommand(
                    fixture,
                    context: context,
                    preparation: scheduleSelectedPreparation(fixture),
                    traceId: "trace-rollback-\(label)"
                ),
                planningProviderResolver: ScheduleTestResolverRecorder()
            )
        }
        #expect(try scheduleMutationSnapshot(fixture) == before)
    }

    let scopeIntegrityFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-scope-integrity-rollback"
    )
    let scopeIntegrityContext = try scheduleSlotContext(
        scopeIntegrityFixture,
        at: scheduledAt
    )
    try scopeIntegrityFixture.database.pool.write { db in
        try db.execute(
            sql: """
                CREATE TRIGGER ignore_a4_schedule_last_fired_update
                BEFORE UPDATE OF lastFiredAt ON schedule
                WHEN NEW.id = '\(scopeIntegrityFixture.schedule.id)'
                BEGIN SELECT RAISE(IGNORE); END
                """
        )
    }
    let scopeTriggerSQL = try scopeIntegrityFixture.database.pool.read {
        try String.fetchOne(
            $0,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'trigger'
                  AND name = 'ignore_a4_schedule_last_fired_update'
                """
        )
    }
    #expect(
        scopeTriggerSQL?.contains(scopeIntegrityFixture.schedule.id) == true
    )
    let scopeIntegrityBefore = try scheduleMutationSnapshot(
        scopeIntegrityFixture
    )
    let scopeIntegrityResolver = ScheduleTestResolverRecorder()
    #expect(throws: ScheduleFireScopeIntegrityError(
        scheduleId: scopeIntegrityFixture.schedule.id
    )) {
        _ = try scopeIntegrityFixture.database.startScheduledMission(
            scheduleStartCommand(
                scopeIntegrityFixture,
                context: scopeIntegrityContext,
                preparation: scheduleSelectedPreparation(
                    scopeIntegrityFixture
                ),
                traceId: "trace-scope-integrity-rollback"
            ),
            planningProviderResolver: scopeIntegrityResolver
        )
    }
    #expect(scopeIntegrityResolver.callCount == 1)
    #expect(
        try scheduleMutationSnapshot(scopeIntegrityFixture)
            == scopeIntegrityBefore
    )

    let halted = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-halted"
    )
    let haltedContext = try scheduleSlotContext(halted, at: scheduledAt)
    _ = try halted.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    let haltedBefore = try scheduleMutationSnapshot(halted)
    #expect(throws: PlanningDurableDispatchNotRunningError.self) {
        _ = try halted.database.startScheduledMission(
            scheduleStartCommand(
                halted,
                context: haltedContext,
                preparation: scheduleSelectedPreparation(halted),
                traceId: "trace-halted"
            ),
            planningProviderResolver: ScheduleTestResolverRecorder()
        )
    }
    #expect(try scheduleMutationSnapshot(halted) == haltedBefore)

    let unknown = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-unknown-resolver"
    )
    let unknownContext = try scheduleSlotContext(unknown, at: scheduledAt)
    let unknownBefore = try scheduleMutationSnapshot(unknown)
    enum UnknownScheduleResolverError: Error { case injected }
    #expect(throws: UnknownScheduleResolverError.injected) {
        _ = try unknown.database.startScheduledMission(
            scheduleStartCommand(
                unknown,
                context: unknownContext,
                preparation: scheduleSelectedPreparation(unknown),
                traceId: "trace-unknown-resolver"
            ),
            planningProviderResolver: ScheduleTestResolverRecorder(
                onResolve: { throw UnknownScheduleResolverError.injected }
            )
        )
    }
    #expect(try scheduleMutationSnapshot(unknown) == unknownBefore)

    enum ProfileIdentityDrift: String, CaseIterable, Sendable {
        case kind
        case baseURL
        case credentialAccount
    }
    for drift in ProfileIdentityDrift.allCases {
        let fixture = try makeScheduleFireTestFixture(
            scheduleId: "schedule-a4-profile-fence-\(drift.rawValue)"
        )
        let context = try scheduleSlotContext(fixture, at: scheduledAt)
        let database = fixture.database
        let profileId = fixture.runtimeProfileId
        let resolver = ScheduleTestResolverRecorder(onResolve: {
            try database.pool.write { db in
                switch drift {
                case .kind:
                    try db.execute(
                        sql: "UPDATE runtime_profile SET kind = 'anthropic_api' WHERE id = ?",
                        arguments: [profileId]
                    )
                case .baseURL:
                    try db.execute(
                        sql: "UPDATE runtime_profile SET baseURL = 'https://drift.invalid' WHERE id = ?",
                        arguments: [profileId]
                    )
                case .credentialAccount:
                    try db.execute(
                        sql: "UPDATE runtime_profile SET credentialAccount = 'drift-account' WHERE id = ?",
                        arguments: [profileId]
                    )
                }
            }
        })
        let result = try database.startScheduledMission(
            scheduleStartCommand(
                fixture,
                context: context,
                preparation: scheduleSelectedPreparation(fixture),
                traceId: "trace-profile-fence-\(drift.rawValue)"
            ),
            planningProviderResolver: resolver
        )
        let snapshot = try scheduleMutationSnapshot(fixture)
        #expect(resolver.callCount == 1)
        #expect(result.disposition == .inserted)
        #expect(result.fire.state == .failed)
        #expect(result.fire.errorCode == "schedule_runtime_unavailable")
        #expect(result.fire.errorMessage == "定时行动的运行配置不可用。")
        #expect(snapshot.fireCount == 1)
        #expect(snapshot.missionCount == 0)
        #expect(snapshot.planningWorkCount == 0)
        #expect(snapshot.cursor?.version == 1)
        #expect(snapshot.lastFiredAt == nil)
    }

    enum ProfileNonIdentityDrift: String, CaseIterable, Sendable {
        case name
        case isDefault
        case createdAt
    }
    for drift in ProfileNonIdentityDrift.allCases {
        let fixture = try makeScheduleFireTestFixture(
            scheduleId: "schedule-a4-profile-nonidentity-\(drift.rawValue)"
        )
        let context = try scheduleSlotContext(fixture, at: scheduledAt)
        let database = fixture.database
        let profileId = fixture.runtimeProfileId
        let resolver = ScheduleTestResolverRecorder(onResolve: {
            try database.pool.write { db in
                switch drift {
                case .name:
                    try db.execute(
                        sql: "UPDATE runtime_profile SET name = 'Renamed During Preflight' WHERE id = ?",
                        arguments: [profileId]
                    )
                case .isDefault:
                    try db.execute(
                        sql: "UPDATE runtime_profile SET isDefault = 1 WHERE id = ?",
                        arguments: [profileId]
                    )
                case .createdAt:
                    try db.execute(
                        sql: "UPDATE runtime_profile SET createdAt = 2 WHERE id = ?",
                        arguments: [profileId]
                    )
                }
            }
        })
        let result = try database.startScheduledMission(
            scheduleStartCommand(
                fixture,
                context: context,
                preparation: scheduleSelectedPreparation(fixture),
                traceId: "trace-profile-nonidentity-\(drift.rawValue)"
            ),
            planningProviderResolver: resolver
        )
        let snapshot = try scheduleMutationSnapshot(fixture)
        #expect(resolver.callCount == 1)
        #expect(result.disposition == .inserted)
        #expect(result.fire.state == .started)
        #expect(result.missionId != nil)
        #expect(result.workId != nil)
        #expect(snapshot.fireCount == 1)
        #expect(snapshot.missionCount == 1)
        #expect(snapshot.planningWorkCount == 1)
        #expect(snapshot.cursor?.version == 1)
        #expect(
            snapshot.lastFiredAt?.timeIntervalSince1970.bitPattern
                == context.scheduledAt.timeIntervalSince1970.bitPattern
        )
    }
}

@Test func failedSlotDoesNotSpinOrAutoRetryAfterConfigurationFix()
    throws
{
    let fixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-no-spin"
    )
    let scheduledAt = scheduleDate(
        2026,
        7,
        14,
        9,
        0,
        timeZoneID: "America/Los_Angeles"
    )
    var invalidSchedule = fixture.schedule
    invalidSchedule.weekday = 1
    try fixture.database.pool.write {
        try $0.execute(
            sql: "UPDATE schedule SET weekday = 1 WHERE id = ?",
            arguments: [fixture.schedule.id]
        )
    }
    let (calendar, timeZone) = scheduleCalendar(
        "America/Los_Angeles"
    )
    let invalidContext = try ScheduleMath.slotContext(
        for: scheduledAt,
        frequency: invalidSchedule.frequency,
        hour: invalidSchedule.hour,
        minute: invalidSchedule.minute,
        weekday: invalidSchedule.weekday,
        calendar: calendar,
        timeZone: timeZone
    )
    let firstResolver = ScheduleTestResolverRecorder()
    let originalCommand = SchedulePlanningStartCommand(
        scheduleId: fixture.schedule.id,
        context: invalidContext,
        preparation: scheduleSelectedPreparation(fixture),
        traceId: "trace-no-spin-original"
    )
    let failed = try fixture.database.startScheduledMission(
        originalCommand,
        planningProviderResolver: firstResolver
    )
    #expect(failed.disposition == .inserted)
    #expect(failed.fire.state == .failed)
    #expect(failed.fire.errorCode == "schedule_configuration_invalid")
    #expect(firstResolver.callCount == 1)
    let failedSnapshot = try scheduleMutationSnapshot(fixture)

    try fixture.database.pool.write {
        try $0.execute(
            sql: "UPDATE schedule SET weekday = NULL WHERE id = ?",
            arguments: [fixture.schedule.id]
        )
    }
    let replayResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("consumed original slot must not resolve again")
    })
    let duplicate = try fixture.database.startScheduledMission(
        SchedulePlanningStartCommand(
            scheduleId: originalCommand.scheduleId,
            context: originalCommand.context,
            preparation: scheduleSelectedPreparation(fixture),
            traceId: "trace-no-spin-late"
        ),
        planningProviderResolver: replayResolver
    )
    #expect(duplicate.disposition == .replayed)
    #expect(duplicate.fire == failed.fire)
    #expect(replayResolver.callCount == 0)
    #expect(try scheduleMutationSnapshot(fixture) == failedSnapshot)

    let repairedSchedule = try #require(
        try fixture.database.schedule(id: fixture.schedule.id)
    )
    let due = try ScheduleMath.latestUnevaluatedSlot(
        now: scheduledAt.addingTimeInterval(60),
        createdAt: repairedSchedule.createdAt,
        cursor: failedSnapshot.cursor,
        frequency: repairedSchedule.frequency,
        hour: repairedSchedule.hour,
        minute: repairedSchedule.minute,
        weekday: repairedSchedule.weekday,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(due == nil)

    let replayCommand = try scheduleReplayCommand(
        original: failed.fire,
        effectiveTemplateId: fixture.template.id,
        preparation: scheduleSelectedPreparation(fixture),
        replayIdempotencyKey:
            "schedule-replay:10000000-0000-0000-0000-000000000001",
        traceId: "trace-no-spin-explicit-replay"
    )
    let explicit = try fixture.database.replayMissedScheduleFire(
        replayCommand,
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    #expect(explicit.disposition == .inserted)
    #expect(explicit.fire.state == .started)
    #expect(explicit.fire.replayOfFireId == failed.fire.id)
    #expect(
        try fixture.database.scheduleEvaluationCursor(
            scheduleId: fixture.schedule.id
        ) == failedSnapshot.cursor
    )
    #expect(
        try fixture.database.schedule(id: fixture.schedule.id)?.lastFiredAt
            == nil
    )

    func installCursor(
        _ fixture: ScheduleFireTestFixture,
        slotKey: String,
        scheduledAt: Date,
        version: Int
    ) throws {
        try fixture.database.pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO schedule_evaluation_cursor (
                      scheduleId, lastEvaluatedSlotKey,
                      lastEvaluatedScheduledAt, version, updatedAt
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    fixture.schedule.id,
                    slotKey,
                    scheduledAt.timeIntervalSince1970,
                    version,
                    scheduledAt.timeIntervalSince1970,
                ]
            )
        }
    }

    let cursorCases: [(String, String, TimeInterval, Int)] = [
        ("later-time", "a", 60, 1),
        ("raw-utf8-greater", "z", 0, 1),
    ]
    for (label, cursorKey, offset, version) in cursorCases {
        let staleFixture = try makeScheduleFireTestFixture(
            scheduleId: "schedule-a4-cursor-stale-\(label)"
        )
        let staleContext = try scheduleSlotContext(
            staleFixture,
            at: scheduledAt
        )
        try installCursor(
            staleFixture,
            slotKey: cursorKey,
            scheduledAt: scheduledAt.addingTimeInterval(offset),
            version: version
        )
        let before = try scheduleMutationSnapshot(staleFixture)
        let resolver = ScheduleTestResolverRecorder()
        #expect(throws: StaleScheduleEvaluationError(
            scheduleId: staleFixture.schedule.id,
            slotKey: staleContext.slotKey
        )) {
            _ = try staleFixture.database.startScheduledMission(
                scheduleStartCommand(
                    staleFixture,
                    context: staleContext,
                    preparation: scheduleSelectedPreparation(staleFixture),
                    traceId: "trace-cursor-stale-\(label)"
                ),
                planningProviderResolver: resolver
            )
        }
        #expect(resolver.callCount == 1)
        #expect(try scheduleMutationSnapshot(staleFixture) == before)
    }

    let equalFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-cursor-equal-without-fire"
    )
    let equalContext = try scheduleSlotContext(equalFixture, at: scheduledAt)
    try installCursor(
        equalFixture,
        slotKey: equalContext.slotKey,
        scheduledAt: scheduledAt,
        version: 1
    )
    let equalBefore = try scheduleMutationSnapshot(equalFixture)
    let equalResolver = ScheduleTestResolverRecorder()
    #expect(throws: ScheduleEvaluationIntegrityError(
        scheduleId: equalFixture.schedule.id,
        slotKey: equalContext.slotKey
    )) {
        _ = try equalFixture.database.startScheduledMission(
            scheduleStartCommand(
                equalFixture,
                context: equalContext,
                preparation: scheduleSelectedPreparation(equalFixture),
                traceId: "trace-cursor-equal"
            ),
            planningProviderResolver: equalResolver
        )
    }
    #expect(equalResolver.callCount == 1)
    #expect(try scheduleMutationSnapshot(equalFixture) == equalBefore)

    let overflowFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-cursor-version-overflow"
    )
    let overflowContext = try scheduleSlotContext(
        overflowFixture,
        at: scheduledAt
    )
    try installCursor(
        overflowFixture,
        slotKey: "a",
        scheduledAt: scheduledAt,
        version: Int.max
    )
    let overflowBefore = try scheduleMutationSnapshot(overflowFixture)
    let overflowResolver = ScheduleTestResolverRecorder()
    #expect(throws: ScheduleEvaluationVersionOverflowError(
        scheduleId: overflowFixture.schedule.id,
        version: Int.max
    )) {
        _ = try overflowFixture.database.startScheduledMission(
            scheduleStartCommand(
                overflowFixture,
                context: overflowContext,
                preparation: scheduleSelectedPreparation(overflowFixture),
                traceId: "trace-cursor-version-overflow"
            ),
            planningProviderResolver: overflowResolver
        )
    }
    #expect(overflowResolver.callCount == 1)
    #expect(try scheduleMutationSnapshot(overflowFixture) == overflowBefore)

    let configurationDriftFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-configuration-drift"
    )
    let configurationDriftContext = try scheduleSlotContext(
        configurationDriftFixture,
        at: scheduledAt
    )
    let configurationDriftBefore = try scheduleMutationSnapshot(
        configurationDriftFixture
    )
    let configurationDriftResolver = ScheduleTestResolverRecorder(
        onResolve: {
            try configurationDriftFixture.database.pool.write {
                try $0.execute(
                    sql: "UPDATE schedule SET hour = 10 WHERE id = ?",
                    arguments: [configurationDriftFixture.schedule.id]
                )
            }
        }
    )
    #expect(throws: StaleScheduleConfigurationError(
        scheduleId: configurationDriftFixture.schedule.id
    )) {
        _ = try configurationDriftFixture.database.startScheduledMission(
            scheduleStartCommand(
                configurationDriftFixture,
                context: configurationDriftContext,
                preparation: scheduleSelectedPreparation(
                    configurationDriftFixture
                ),
                traceId: "trace-configuration-drift"
            ),
            planningProviderResolver: configurationDriftResolver
        )
    }
    #expect(configurationDriftResolver.callCount == 1)
    #expect(
        try scheduleMutationSnapshot(configurationDriftFixture)
            == configurationDriftBefore
    )
    #expect(
        try configurationDriftFixture.database.schedule(
            id: configurationDriftFixture.schedule.id
        )?.hour == 10
    )
}

@Test func explicitReplayUsesNewIdempotencyKeyAndDoesNotMoveCursor()
    throws
{
    let fixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-explicit-replay"
    )
    let context = try scheduleSlotContext(
        fixture,
        at: scheduleDate(
            2026,
            7,
            14,
            9,
            0,
            timeZoneID: "America/Los_Angeles"
        )
    )
    let original = try fixture.database.startScheduledMission(
        scheduleStartCommand(
            fixture,
            context: context,
            preparation: .forcedFailure,
            traceId: "trace-replay-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    #expect(original.fire.state == .failed)
    let cursorBefore = try #require(
        try fixture.database.scheduleEvaluationCursor(
            scheduleId: fixture.schedule.id
        )
    )
    let originalBefore = original.fire

    let reboundTemplate = try MissionTemplateRecord.new(
        name: "修复后的模板",
        goal: "使用当前有效模板显式补跑",
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        budgetTokens: 2_000,
        autonomy: .standard,
        campId: fixture.camp.id
    )
    try fixture.database.saveMissionTemplate(reboundTemplate)
    try fixture.database.pool.write {
        try $0.execute(
            sql: "UPDATE schedule SET templateId = ? WHERE id = ?",
            arguments: [reboundTemplate.id, fixture.schedule.id]
        )
    }

    func requireReplayPayloadShape(
        _ payload: ScheduleReplayPayloadV1,
        runtimeProfileId: String?,
        plannerModel: String?,
        preflightFailureCode: String?
    ) throws {
        let data = try payload.canonicalData()
        #expect(try CanonicalJSONV1.encode(payload) == data)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let orderedKeys = [
            "contractVersion",
            "effectiveTemplateId",
            "originalFireId",
            "originalTemplateId",
            "plannerModel",
            "preflightFailureCode",
            "runtimeProfileId",
            "runtimeState",
            "scheduleId",
            "scheduledAtInstantBits",
            "slotKey",
        ]
        #expect(object.count == 11)
        #expect(Set(object.keys) == Set(orderedKeys))
        let json = String(decoding: data, as: UTF8.self)
        var cursor = json.startIndex
        for key in orderedKeys {
            let token = "\"\(key)\":"
            let range = try #require(
                json.range(of: token, range: cursor..<json.endIndex)
            )
            cursor = range.upperBound
        }
        if let runtimeProfileId {
            #expect(object["runtimeProfileId"] as? String == runtimeProfileId)
        } else {
            #expect(object["runtimeProfileId"] is NSNull)
        }
        if let plannerModel {
            #expect(object["plannerModel"] as? String == plannerModel)
        } else {
            #expect(object["plannerModel"] is NSNull)
        }
        if let preflightFailureCode {
            #expect(
                object["preflightFailureCode"] as? String
                    == preflightFailureCode
            )
        } else {
            #expect(object["preflightFailureCode"] is NSNull)
        }
    }

    let selectedReplayPayload = try ScheduleReplayPayloadV1(
        originalFire: original.fire,
        effectiveTemplateId: reboundTemplate.id,
        preparation: scheduleSelectedPreparation(fixture)
    )
    try requireReplayPayloadShape(
        selectedReplayPayload,
        runtimeProfileId: fixture.runtimeProfileId,
        plannerModel: fixture.plannerModel,
        preflightFailureCode: nil
    )
    let unavailableReplayPayload = try ScheduleReplayPayloadV1(
        originalFire: original.fire,
        effectiveTemplateId: reboundTemplate.id,
        preparation: .unavailable
    )
    try requireReplayPayloadShape(
        unavailableReplayPayload,
        runtimeProfileId: nil,
        plannerModel: nil,
        preflightFailureCode: "schedule_runtime_unavailable"
    )
    let replayKey =
        "schedule-replay:20000000-0000-0000-0000-000000000002"
    let replay = try fixture.database.replayMissedScheduleFire(
        try scheduleReplayCommand(
            original: original.fire,
            effectiveTemplateId: reboundTemplate.id,
            preparation: scheduleSelectedPreparation(fixture),
            replayIdempotencyKey: replayKey,
            traceId: "trace-replay-started"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let replayWorkId = try #require(replay.workId)
    let replayWork = try #require(try fixture.database.pool.read {
        try DurableWorkRecord.fetchOne($0, key: replayWorkId)
    })
    let expectedWorkKey = "mission-start:schedule-replay:"
        + CanonicalJSONV1.sha256Hex(Data(replayKey.utf8))
        + ":v1"
    let firedEvent = try scheduleEvent(
        fixture.database,
        fireId: replay.fire.id,
        kind: EventKind.scheduleFired
    )
    let firedPayload = try JSONDecoder().decode(
        ScheduleFiredPayloadV1.self,
        from: Data(firedEvent.payloadJson.utf8)
    )
    let firedEventCreatedAtStorage = try fixture.database.pool.read {
        try String.fetchOne(
            $0,
            sql: "SELECT typeof(createdAt) FROM event WHERE id = ?",
            arguments: [firedEvent.id]
        )
    }

    #expect(replay.disposition == .inserted)
    #expect(replay.fire.state == .started)
    #expect(replay.fire.replayOfFireId == original.fire.id)
    #expect(replay.fire.templateId == reboundTemplate.id)
    #expect(replay.fire.slotKey == original.fire.slotKey)
    #expect(
        replay.fire.scheduledAt.timeIntervalSince1970.bitPattern
            == original.fire.scheduledAt.timeIntervalSince1970.bitPattern
    )
    #expect(replayWork.idempotencyKey == expectedWorkKey)
    #expect(firedEvent.missionId == replay.missionId)
    #expect(firedEvent.cardId == nil)
    #expect(firedEvent.runId == nil)
    #expect(
        firedEvent.createdAt.timeIntervalSince1970.bitPattern
            == replay.fire.createdAt.timeIntervalSince1970.bitPattern
    )
    #expect(
        firedEventCreatedAtStorage == "real"
            || firedEventCreatedAtStorage == "integer"
    )
    #expect(firedPayload.contractVersion == 1)
    #expect(firedPayload.fireId == replay.fire.id)
    #expect(firedPayload.scheduleId == fixture.schedule.id)
    #expect(firedPayload.templateId == reboundTemplate.id)
    #expect(firedPayload.slotKey == original.fire.slotKey)
    #expect(
        firedPayload.scheduledAt.bitPattern
            == replay.fire.scheduledAt.timeIntervalSince1970.bitPattern
    )
    #expect(
        firedPayload.scheduledAtInstantBits
            == context.scheduledAtInstantBits
    )
    #expect(firedPayload.replayOfFireId == original.fire.id)
    #expect(firedPayload.traceId == "trace-replay-started")
    #expect(
        try fixture.database.scheduleFire(id: original.fire.id)
            == originalBefore
    )
    #expect(
        try fixture.database.scheduleEvaluationCursor(
            scheduleId: fixture.schedule.id
        ) == cursorBefore
    )
    #expect(
        try fixture.database.schedule(id: fixture.schedule.id)?.lastFiredAt
            == nil
    )

    let failedReplay = try fixture.database.replayMissedScheduleFire(
        try scheduleReplayCommand(
            original: original.fire,
            effectiveTemplateId: reboundTemplate.id,
            preparation: .unavailable,
            replayIdempotencyKey:
                "schedule-replay:20000000-0000-0000-0000-000000000003",
            traceId: "trace-replay-failed"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder(onResolve: {
            Issue.record("unavailable replay must not resolve provider")
        })
    )
    #expect(failedReplay.fire.state == .failed)
    #expect(
        failedReplay.fire.errorCode == "schedule_runtime_unavailable"
    )
    #expect(failedReplay.fire.replayOfFireId == original.fire.id)
    #expect(
        try fixture.database.scheduleEvaluationCursor(
            scheduleId: fixture.schedule.id
        ) == cursorBefore
    )
    #expect(
        try fixture.database.schedule(id: fixture.schedule.id)?.lastFiredAt
            == nil
    )

    let beforeInvalidSource = try scheduleMutationSnapshot(fixture)
    #expect(throws: InvalidScheduleReplaySourceError.self) {
        _ = try fixture.database.replayMissedScheduleFire(
            try scheduleReplayCommand(
                original: replay.fire,
                effectiveTemplateId: reboundTemplate.id,
                preparation: scheduleSelectedPreparation(fixture),
                replayIdempotencyKey:
                    "schedule-replay:20000000-0000-0000-0000-000000000004",
                traceId: "trace-replay-of-replay"
            ),
            planningProviderResolver: ScheduleTestResolverRecorder()
        )
    }
    #expect(try scheduleMutationSnapshot(fixture) == beforeInvalidSource)

    let driftFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-replay-template-drift"
    )
    let driftOriginal = try driftFixture.database.startScheduledMission(
        scheduleStartCommand(
            driftFixture,
            context: try scheduleSlotContext(
                driftFixture,
                at: scheduleDate(
                    2026,
                    7,
                    16,
                    9,
                    0,
                    timeZoneID: "America/Los_Angeles"
                )
            ),
            preparation: .unavailable,
            traceId: "trace-replay-template-drift-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let driftTemplate = try MissionTemplateRecord.new(
        name: "并发切换后的模板",
        goal: "捕获后切换模板必须拒绝旧准备结果",
        companionIds: [driftFixture.companion.id],
        workspacePath: nil,
        budgetTokens: 2_000,
        autonomy: .standard,
        campId: driftFixture.camp.id
    )
    try driftFixture.database.saveMissionTemplate(driftTemplate)
    let driftCommand = try scheduleReplayCommand(
        original: driftOriginal.fire,
        effectiveTemplateId: driftFixture.template.id,
        preparation: scheduleSelectedPreparation(driftFixture),
        replayIdempotencyKey:
            "schedule-replay:20000000-0000-0000-0000-000000000005",
        traceId: "trace-replay-template-drift"
    )
    let driftBefore = try scheduleMutationSnapshot(driftFixture)
    let driftResolver = ScheduleTestResolverRecorder(onResolve: {
        try driftFixture.database.pool.write {
            try $0.execute(
                sql: "UPDATE schedule SET templateId = ? WHERE id = ?",
                arguments: [
                    driftTemplate.id,
                    driftFixture.schedule.id,
                ]
            )
        }
    })
    #expect(throws: StaleScheduleReplayPreparationError(
        originalFireId: driftOriginal.fire.id,
        expectedTemplateId: driftFixture.template.id,
        actualTemplateId: driftTemplate.id
    )) {
        _ = try driftFixture.database.replayMissedScheduleFire(
            driftCommand,
            planningProviderResolver: driftResolver
        )
    }
    #expect(driftResolver.callCount == 1)
    #expect(try scheduleMutationSnapshot(driftFixture) == driftBefore)
    #expect(
        try driftFixture.database.schedule(
            id: driftFixture.schedule.id
        )?.templateId == driftTemplate.id
    )
}

@Test func replaySamePayloadReturnsSameFireButConflictFails() async throws {
    let fixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-replay-key"
    )
    let context = try scheduleSlotContext(
        fixture,
        at: scheduleDate(
            2026,
            7,
            14,
            9,
            0,
            timeZoneID: "America/Los_Angeles"
        )
    )
    let original = try fixture.database.startScheduledMission(
        scheduleStartCommand(
            fixture,
            context: context,
            preparation: .unavailable,
            traceId: "trace-key-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let key = "schedule-replay:30000000-0000-0000-0000-000000000005"
    let firstCommand = try scheduleReplayCommand(
        original: original.fire,
        effectiveTemplateId: fixture.template.id,
        preparation: scheduleSelectedPreparation(fixture),
        replayIdempotencyKey: key,
        traceId: "trace-key-first"
    )
    let firstResolver = ScheduleTestResolverRecorder()
    let first = try fixture.database.replayMissedScheduleFire(
        firstCommand,
        planningProviderResolver: firstResolver
    )
    let firstSnapshot = try scheduleMutationSnapshot(fixture)
    let replayResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("same replay key winner must skip provider")
    })
    let repeated = try fixture.database.replayMissedScheduleFire(
        ScheduleReplayStartCommand(
            originalFireId: firstCommand.originalFireId,
            replayIdempotencyKey: firstCommand.replayIdempotencyKey,
            payload: firstCommand.payload,
            replayPayloadHash: firstCommand.replayPayloadHash,
            traceId: "trace-key-late"
        ),
        planningProviderResolver: replayResolver
    )
    #expect(first.disposition == .inserted)
    #expect(repeated.disposition == .replayed)
    #expect(repeated.fire == first.fire)
    #expect(repeated.missionId == first.missionId)
    #expect(repeated.workId == first.workId)
    #expect(repeated.fire.traceId == "trace-key-first")
    #expect(firstResolver.callCount == 1)
    #expect(replayResolver.callCount == 0)
    #expect(try scheduleMutationSnapshot(fixture) == firstSnapshot)

    let conflictingPayload = try ScheduleReplayPayloadV1(
        originalFire: original.fire,
        effectiveTemplateId: "different-template",
        preparation: scheduleSelectedPreparation(fixture)
    )
    let conflictBefore = try scheduleMutationSnapshot(fixture)
    let conflictResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("replay-key conflict must skip provider")
    })
    #expect(throws: DurableWorkReplayConflictError.self) {
        _ = try fixture.database.replayMissedScheduleFire(
            ScheduleReplayStartCommand(
                originalFireId: original.fire.id,
                replayIdempotencyKey: key,
                payload: conflictingPayload,
                replayPayloadHash: try conflictingPayload.canonicalHash(),
                traceId: "trace-key-conflict"
            ),
            planningProviderResolver: conflictResolver
        )
    }
    #expect(conflictResolver.callCount == 0)
    #expect(try scheduleMutationSnapshot(fixture) == conflictBefore)

    _ = try fixture.database.transitionDispatchMode(
        from: .running,
        to: .halted
    )
    let haltedConflictBefore = try scheduleMutationSnapshot(fixture)
    let haltedConflictResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("halted replay conflict must fail at the dispatch gate")
    })
    #expect(throws: PlanningDurableDispatchNotRunningError(
        actualMode: .halted
    )) {
        _ = try fixture.database.replayMissedScheduleFire(
            ScheduleReplayStartCommand(
                originalFireId: original.fire.id,
                replayIdempotencyKey: key,
                payload: conflictingPayload,
                replayPayloadHash: try conflictingPayload.canonicalHash(),
                traceId: "trace-key-halted-conflict"
            ),
            planningProviderResolver: haltedConflictResolver
        )
    }
    #expect(haltedConflictResolver.callCount == 0)
    #expect(
        try scheduleMutationSnapshot(fixture) == haltedConflictBefore
    )

    let hashFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-replay-absent-hash-conflict"
    )
    let hashOriginal = try hashFixture.database.startScheduledMission(
        scheduleStartCommand(
            hashFixture,
            context: try scheduleSlotContext(
                hashFixture,
                at: scheduleDate(
                    2026,
                    7,
                    16,
                    9,
                    0,
                    timeZoneID: "America/Los_Angeles"
                )
            ),
            preparation: .unavailable,
            traceId: "trace-hash-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let validHashCommand = try scheduleReplayCommand(
        original: hashOriginal.fire,
        effectiveTemplateId: hashFixture.template.id,
        preparation: scheduleSelectedPreparation(hashFixture),
        replayIdempotencyKey:
            "schedule-replay:30000000-0000-0000-0000-000000000007",
        traceId: "trace-absent-wrong-hash"
    )
    let wrongHash = validHashCommand.replayPayloadHash
        == String(repeating: "0", count: 64)
        ? String(repeating: "f", count: 64)
        : String(repeating: "0", count: 64)
    let hashBefore = try scheduleMutationSnapshot(hashFixture)
    let hashResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("invalid absent replay hash must skip provider")
    })
    #expect(throws: DurableWorkReplayConflictError()) {
        _ = try hashFixture.database.replayMissedScheduleFire(
            ScheduleReplayStartCommand(
                originalFireId: validHashCommand.originalFireId,
                replayIdempotencyKey:
                    validHashCommand.replayIdempotencyKey,
                payload: validHashCommand.payload,
                replayPayloadHash: wrongHash,
                traceId: validHashCommand.traceId
            ),
            planningProviderResolver: hashResolver
        )
    }
    #expect(hashResolver.callCount == 0)
    #expect(try scheduleMutationSnapshot(hashFixture) == hashBefore)

    let providerFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-replay-provider-recovery"
    )
    let providerOriginal = try providerFixture.database.startScheduledMission(
        scheduleStartCommand(
            providerFixture,
            context: try scheduleSlotContext(
                providerFixture,
                at: scheduleDate(
                    2026,
                    7,
                    17,
                    9,
                    0,
                    timeZoneID: "America/Los_Angeles"
                )
            ),
            preparation: .unavailable,
            traceId: "trace-provider-recovery-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let providerCommand = try scheduleReplayCommand(
        original: providerOriginal.fire,
        effectiveTemplateId: providerFixture.template.id,
        preparation: scheduleSelectedPreparation(providerFixture),
        replayIdempotencyKey:
            "schedule-replay:30000000-0000-0000-0000-000000000008",
        traceId: "trace-provider-recovery-first"
    )
    let providerFailure = try providerFixture.database
        .replayMissedScheduleFire(
            providerCommand,
            planningProviderResolver: scheduleTypedUnavailableResolver()
        )
    #expect(providerFailure.disposition == .inserted)
    #expect(providerFailure.fire.state == .failed)
    #expect(
        providerFailure.fire.errorCode == "schedule_provider_unavailable"
    )
    let providerFailureSnapshot = try scheduleMutationSnapshot(
        providerFixture
    )
    let recoveredResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("committed provider failure replay must skip provider")
    })
    let recovered = try providerFixture.database.replayMissedScheduleFire(
        ScheduleReplayStartCommand(
            originalFireId: providerCommand.originalFireId,
            replayIdempotencyKey: providerCommand.replayIdempotencyKey,
            payload: providerCommand.payload,
            replayPayloadHash: providerCommand.replayPayloadHash,
            traceId: "trace-provider-recovery-late"
        ),
        planningProviderResolver: recoveredResolver
    )
    #expect(recovered.disposition == .replayed)
    #expect(recovered.fire == providerFailure.fire)
    #expect(recovered.missionId == nil)
    #expect(recovered.workId == nil)
    #expect(recoveredResolver.callCount == 0)
    #expect(
        try scheduleMutationSnapshot(providerFixture)
            == providerFailureSnapshot
    )

    for corruption in ScheduleStartedWinnerCorruption.allCases {
        let setup = try makeScheduleStartedReplayWinnerFixture(
            label: corruption.rawValue
        )
        try corruptScheduleStartedWinner(
            setup,
            corruption: corruption
        )
        let winnerBefore = try #require(
            try setup.fixture.database.scheduleFire(
                id: setup.winner.fire.id
            )
        )
        let corruptionBefore = try scheduleMutationSnapshot(setup.fixture)
        let totalChangesBefore = scheduleWriterTotalChanges(setup.fixture)
        let corruptionResolver = ScheduleTestResolverRecorder(onResolve: {
            Issue.record(
                "corrupt \(corruption.rawValue) winner must skip provider"
            )
        })
        #expect(throws: ScheduleFireReplayIntegrityError(
            fireId: setup.winner.fire.id
        )) {
            _ = try setup.fixture.database.replayMissedScheduleFire(
                setup.command,
                planningProviderResolver: corruptionResolver
            )
        }
        #expect(corruptionResolver.callCount == 0)
        #expect(
            scheduleWriterTotalChanges(setup.fixture)
                == totalChangesBefore
        )
        #expect(
            try scheduleMutationSnapshot(setup.fixture)
                == corruptionBefore
        )
        #expect(
            try setup.fixture.database.scheduleFire(
                id: setup.winner.fire.id
            ) == winnerBefore
        )
    }

    let provenanceSetup = try makeScheduleStartedReplayWinnerFixture(
        label: "source-provenance-mismatch"
    )
    let provenanceOriginal = try #require(
        try provenanceSetup.fixture.database.scheduleFire(
            id: provenanceSetup.command.originalFireId
        )
    )
    let provenanceErrorCode = try #require(provenanceOriginal.errorCode)
    let provenanceErrorMessage = try #require(
        provenanceOriginal.errorMessage
    )
    let differentSlotKey = provenanceOriginal.slotKey
        + ":coherent-different-provenance"
    let differentMissedPayload = ScheduleMissedPayloadV1(
        fireId: provenanceOriginal.id,
        scheduleId: provenanceOriginal.scheduleId,
        templateId: provenanceOriginal.templateId,
        slotKey: differentSlotKey,
        scheduledAt: provenanceOriginal.scheduledAt.timeIntervalSince1970,
        replayOfFireId: nil,
        traceId: provenanceOriginal.traceId,
        errorCode: provenanceErrorCode,
        errorMessage: provenanceErrorMessage
    )
    try await provenanceSetup.fixture.database.pool.write { db in
        try db.execute(
            sql: "DROP TRIGGER event_reject_update_except_camp_redaction"
        )
        try db.execute(
            sql: "UPDATE schedule_fire SET slotKey = ? WHERE id = ?",
            arguments: [differentSlotKey, provenanceOriginal.id]
        )
        guard db.changesCount == 1 else {
            throw ScheduleFireReplayIntegrityError(
                fireId: provenanceOriginal.id
            )
        }
        try db.execute(
            sql: """
                UPDATE event
                SET payloadJson = ?
                WHERE kind = ?
                  AND json_extract(payloadJson, '$.fireId') = ?
                """,
            arguments: [
                String(
                    decoding: try CanonicalJSONV1.encode(
                        differentMissedPayload
                    ),
                    as: UTF8.self
                ),
                EventKind.scheduleMissed,
                provenanceOriginal.id,
            ]
        )
        guard db.changesCount == 1 else {
            throw ScheduleFireReplayIntegrityError(
                fireId: provenanceOriginal.id
            )
        }
    }
    let provenanceSourceBefore = try #require(
        try provenanceSetup.fixture.database.scheduleFire(
            id: provenanceOriginal.id
        )
    )
    let provenanceWinnerBefore = try #require(
        try provenanceSetup.fixture.database.scheduleFire(
            id: provenanceSetup.winner.fire.id
        )
    )
    let provenanceBefore = try scheduleMutationSnapshot(
        provenanceSetup.fixture
    )
    let provenanceTotalChangesBefore = scheduleWriterTotalChanges(
        provenanceSetup.fixture
    )
    let provenanceResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("source provenance conflict must skip provider")
    })
    #expect(throws: DurableWorkReplayConflictError.self) {
        _ = try provenanceSetup.fixture.database.replayMissedScheduleFire(
            provenanceSetup.command,
            planningProviderResolver: provenanceResolver
        )
    }
    #expect(provenanceResolver.callCount == 0)
    #expect(
        scheduleWriterTotalChanges(provenanceSetup.fixture)
            == provenanceTotalChangesBefore
    )
    #expect(
        try scheduleMutationSnapshot(provenanceSetup.fixture)
            == provenanceBefore
    )
    #expect(
        try provenanceSetup.fixture.database.scheduleFire(
            id: provenanceOriginal.id
        ) == provenanceSourceBefore
    )
    #expect(
        try provenanceSetup.fixture.database.scheduleFire(
            id: provenanceSetup.winner.fire.id
        ) == provenanceWinnerBefore
    )

    let failureFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-corrupt-failure-pair"
    )
    let failureOriginal = try failureFixture.database.startScheduledMission(
        scheduleStartCommand(
            failureFixture,
            context: try scheduleSlotContext(
                failureFixture,
                at: scheduleDate(
                    2026,
                    7,
                    19,
                    9,
                    0,
                    timeZoneID: "America/Los_Angeles"
                )
            ),
            preparation: .unavailable,
            traceId: "trace-corrupt-failure-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let failureCommand = try scheduleReplayCommand(
        original: failureOriginal.fire,
        effectiveTemplateId: failureFixture.template.id,
        preparation: scheduleSelectedPreparation(failureFixture),
        replayIdempotencyKey:
            "schedule-replay:30000000-0000-0000-0000-000000000009",
        traceId: "trace-corrupt-failure-replay"
    )
    let corruptFailureCode = "corrupt_failure"
    let corruptFailureMessage = "伪造失败。"
    let corruptMissedPayload = ScheduleMissedPayloadV1(
        fireId: failureOriginal.fire.id,
        scheduleId: failureOriginal.fire.scheduleId,
        templateId: failureOriginal.fire.templateId,
        slotKey: failureOriginal.fire.slotKey,
        scheduledAt:
            failureOriginal.fire.scheduledAt.timeIntervalSince1970,
        replayOfFireId: nil,
        traceId: failureOriginal.fire.traceId,
        errorCode: corruptFailureCode,
        errorMessage: corruptFailureMessage
    )
    try await failureFixture.database.pool.write { db in
        try db.execute(
            sql: "DROP TRIGGER event_reject_update_except_camp_redaction"
        )
        try db.execute(
            sql: """
                UPDATE schedule_fire
                SET errorCode = ?, errorMessage = ?
                WHERE id = ?
                """,
            arguments: [
                corruptFailureCode,
                corruptFailureMessage,
                failureOriginal.fire.id,
            ]
        )
        guard db.changesCount == 1 else {
            throw ScheduleFireReplayIntegrityError(
                fireId: failureOriginal.fire.id
            )
        }
        try db.execute(
            sql: """
                UPDATE event
                SET payloadJson = ?
                WHERE kind = ?
                  AND json_extract(payloadJson, '$.fireId') = ?
                """,
            arguments: [
                String(
                    decoding: try CanonicalJSONV1.encode(
                        corruptMissedPayload
                    ),
                    as: UTF8.self
                ),
                EventKind.scheduleMissed,
                failureOriginal.fire.id,
            ]
        )
        guard db.changesCount == 1 else {
            throw ScheduleFireReplayIntegrityError(
                fireId: failureOriginal.fire.id
            )
        }
    }
    let failureBefore = try scheduleMutationSnapshot(failureFixture)
    let failureResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("corrupt failure pair must skip provider")
    })
    #expect(throws: ScheduleFireReplayIntegrityError(
        fireId: failureOriginal.fire.id
    )) {
        _ = try failureFixture.database.replayMissedScheduleFire(
            failureCommand,
            planningProviderResolver: failureResolver
        )
    }
    #expect(failureResolver.callCount == 0)
    #expect(try scheduleMutationSnapshot(failureFixture) == failureBefore)

    let databaseErrorSetup = try makeScheduleStartedReplayWinnerFixture(
        label: "event-table-database-error"
    )
    let databaseErrorBefore = try scheduleCoreGraphSnapshot(
        databaseErrorSetup.fixture
    )
    try await databaseErrorSetup.fixture.database.pool.write {
        try $0.execute(sql: "DROP TABLE event")
    }
    let databaseErrorResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("winner database error must skip provider")
    })
    #expect(throws: DatabaseError.self) {
        _ = try databaseErrorSetup.fixture.database
            .replayMissedScheduleFire(
                databaseErrorSetup.command,
                planningProviderResolver: databaseErrorResolver
            )
    }
    #expect(databaseErrorResolver.callCount == 0)
    #expect(
        try scheduleCoreGraphSnapshot(databaseErrorSetup.fixture)
            == databaseErrorBefore
    )

    let raceFixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-a4-replay-race"
    )
    let raceOriginal = try raceFixture.database.startScheduledMission(
        scheduleStartCommand(
            raceFixture,
            context: try scheduleSlotContext(
                raceFixture,
                at: scheduleDate(
                    2026,
                    7,
                    15,
                    9,
                    0,
                    timeZoneID: "America/Los_Angeles"
                )
            ),
            preparation: .unavailable,
            traceId: "trace-race-original"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let racePayload = try ScheduleReplayPayloadV1(
        originalFire: raceOriginal.fire,
        effectiveTemplateId: raceFixture.template.id,
        preparation: scheduleSelectedPreparation(raceFixture)
    )
    let raceKey =
        "schedule-replay:30000000-0000-0000-0000-000000000006"
    let race = try await runScheduleReplayRace(
        database: raceFixture.database,
        firstCommand: ScheduleReplayStartCommand(
            originalFireId: raceOriginal.fire.id,
            replayIdempotencyKey: raceKey,
            payload: racePayload,
            replayPayloadHash: try racePayload.canonicalHash(),
            traceId: "trace-race-first"
        ),
        secondCommand: ScheduleReplayStartCommand(
            originalFireId: raceOriginal.fire.id,
            replayIdempotencyKey: raceKey,
            payload: racePayload,
            replayPayloadHash: try racePayload.canonicalHash(),
            traceId: "trace-race-second"
        )
    )
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
    let raceSnapshot = try scheduleMutationSnapshot(raceFixture)
    #expect(raceSnapshot.fireCount == 2)
    #expect(raceSnapshot.missionCount == 1)
    #expect(raceSnapshot.planningWorkCount == 1)
    #expect(raceSnapshot.cursor?.version == 1)
    #expect(raceSnapshot.lastFiredAt == nil)
}

@Test func scheduledTemplateValidationRejectsMissingBudgetAtSave() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db, budgetTokens: nil)
    #expect(throws: MissionTemplateValidationError.missingBudgetTokens) {
        try db.saveMissionTemplate(fixture.template)
    }
}

@Test func scheduledTemplateValidationRejectsFreeAutonomyAtSaveAndFireTime() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db, autonomy: .free)
    #expect(throws: MissionTemplateValidationError.freeAutonomyNotAllowed) {
        try db.saveMissionTemplate(fixture.template)
    }
    #expect(throws: MissionTemplateValidationError.freeAutonomyNotAllowed) {
        try fixture.template.validateForScheduledMission()
    }
}

@Test func evercampMigrationV9ReplaysFromV8() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: directory.appendingPathComponent("v8.sqlite").path)
    let migrator = AppDatabase.migrator
    #expect(migrator.migrations.contains("v9-evercamp"))
    try migrator.migrate(pool, upTo: "v8-coding-ranch")
    #expect(try pool.read { try !$0.tableExists("mission_template") })
    #expect(try pool.read { try !$0.tableExists("schedule") })

    try migrator.migrate(pool)
    try migrator.migrate(pool)
    #expect(try pool.read { try $0.tableExists("mission_template") })
    #expect(try pool.read { try $0.tableExists("schedule") })
}

@Test func evercampMigrationV9AdoptsValidatedLegacyV8Tables() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: directory.appendingPathComponent("legacy-v8.sqlite").path)
    let migrator = AppDatabase.migrator
    try migrator.migrate(pool, upTo: "v8-coding-ranch")

    try pool.write { db in
        try db.execute(sql: """
            CREATE TABLE mission_template (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                goal TEXT NOT NULL,
                companionIdsJson TEXT NOT NULL,
                workspacePath TEXT,
                budgetTokens INTEGER NOT NULL,
                autonomy TEXT NOT NULL,
                campId TEXT NOT NULL REFERENCES camp(id),
                createdAt DATETIME NOT NULL
            );
            CREATE TABLE schedule (
                id TEXT PRIMARY KEY NOT NULL,
                templateId TEXT NOT NULL REFERENCES mission_template(id) ON DELETE CASCADE,
                frequency TEXT NOT NULL,
                hour INTEGER NOT NULL,
                minute INTEGER NOT NULL,
                weekday INTEGER,
                enabled BOOLEAN NOT NULL DEFAULT 1,
                lastFiredAt DATETIME,
                createdAt DATETIME NOT NULL
            );
            INSERT INTO camp(id, name, createdAt) VALUES ('camp-legacy', 'Legacy', CURRENT_TIMESTAMP);
            INSERT INTO mission_template(
                id, name, goal, companionIdsJson, workspacePath,
                budgetTokens, autonomy, campId, createdAt
            ) VALUES (
                'template-legacy', 'Legacy', 'Preserve me', '[]', NULL,
                1000, 'supervised', 'camp-legacy', CURRENT_TIMESTAMP
            );
            INSERT INTO schedule(
                id, templateId, frequency, hour, minute, weekday,
                enabled, lastFiredAt, createdAt
            ) VALUES (
                'schedule-legacy', 'template-legacy', 'daily', 9, 30, NULL,
                1, NULL, CURRENT_TIMESTAMP
            );
            """)
    }

    try migrator.migrate(pool)
    try migrator.migrate(pool)

    let migrationNames = try pool.read { db in
        try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
    }
    #expect(migrationNames.contains("v9-evercamp"))
    #expect(migrationNames.contains("v10-runtime-profiles"))
    #expect(migrationNames.contains("v11-cli-kinds"))
    #expect(try pool.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mission_template WHERE id = 'template-legacy'") == 1
    })
    #expect(try pool.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM schedule WHERE id = 'schedule-legacy'") == 1
    })
    let indexes = try pool.read { db in
        try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'index' AND tbl_name IN ('mission_template', 'schedule')
            """)
    }
    #expect(indexes.contains("mission_template_camp"))
    #expect(indexes.contains("schedule_template"))
    #expect(indexes.contains("schedule_enabled"))
}

@Test func scheduleCRUDAndClaimDedupe() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db)
    try db.saveMissionTemplate(fixture.template)
    var schedule = ScheduleRecord.new(
        templateId: fixture.template.id,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        enabled: false
    )
    schedule.createdAt = scheduleDate(
        2026,
        7,
        13,
        9,
        0,
        timeZoneID: "America/Los_Angeles"
    )
    try db.saveSchedule(schedule)
    #expect(try db.schedules(campId: fixture.camp.id).map(\.id) == [schedule.id])

    schedule = try db.setScheduleEnabled(id: schedule.id, enabled: true)
    #expect(schedule.enabled)
    #expect(try db.enabledSchedules().map(\.schedule.id) == [schedule.id])

    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let fire = scheduleDate(2026, 7, 14, 9, 0, timeZoneID: "America/Los_Angeles")
    let runtimeProfileId = "schedule-crud-runtime"
    _ = try seedTestPlanningProfile(db, profileId: runtimeProfileId)
    let context = try ScheduleMath.slotContext(
        for: fire,
        frequency: schedule.frequency,
        hour: schedule.hour,
        minute: schedule.minute,
        weekday: schedule.weekday,
        calendar: calendar,
        timeZone: timeZone
    )
    let command = SchedulePlanningStartCommand(
        scheduleId: schedule.id,
        context: context,
        preparation: .selected(
            runtimeProfileId: runtimeProfileId,
            plannerModel: "schedule-crud-model"
        ),
        traceId: "schedule-crud-first"
    )
    let first = try db.startScheduledMission(
        command,
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let secondResolver = ScheduleTestResolverRecorder(onResolve: {
        Issue.record("same slot replay must not resolve provider")
    })
    let second = try db.startScheduledMission(
        SchedulePlanningStartCommand(
            scheduleId: schedule.id,
            context: context,
            preparation: command.preparation,
            traceId: "schedule-crud-second"
        ),
        planningProviderResolver: secondResolver
    )
    #expect(first.disposition == .inserted)
    #expect(second.disposition == .replayed)
    #expect(second.fire == first.fire)
    #expect(secondResolver.callCount == 0)
    #expect(try db.scheduleFires(scheduleId: schedule.id).count == 1)
    #expect(
        try db.scheduleEvaluationCursor(scheduleId: schedule.id)?.version
            == 1
    )

    let deleteOnlySchedule = ScheduleRecord(
        id: "schedule-delete-preimage",
        templateId: fixture.template.id,
        frequency: .daily,
        hour: 11,
        minute: 0,
        weekday: nil,
        enabled: false,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 199)
    )
    try db.saveSchedule(deleteOnlySchedule)
    let deletedSchedule = try db.deleteScheduleWithPreimage(
        id: deleteOnlySchedule.id
    )
    #expect(deletedSchedule == deleteOnlySchedule)
    #expect(try db.schedule(id: deleteOnlySchedule.id) == nil)

    var cascadeTemplate = fixture.template
    cascadeTemplate.id = "template-delete-preimage"
    cascadeTemplate.name = "Delete Preimage"
    cascadeTemplate.createdAt = Date(timeIntervalSince1970: 200)
    try db.saveMissionTemplate(cascadeTemplate)
    let cascadeB = ScheduleRecord(
        id: "schedule-delete-b",
        templateId: cascadeTemplate.id,
        frequency: .daily,
        hour: 8,
        minute: 0,
        weekday: nil,
        enabled: false,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 202)
    )
    let cascadeA = ScheduleRecord(
        id: "schedule-delete-a",
        templateId: cascadeTemplate.id,
        frequency: .daily,
        hour: 7,
        minute: 0,
        weekday: nil,
        enabled: false,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 201)
    )
    try db.saveSchedule(cascadeB)
    try db.saveSchedule(cascadeA)
    let deletion = try db.deleteMissionTemplateWithPreimage(
        id: cascadeTemplate.id
    )
    #expect(deletion.template == cascadeTemplate)
    #expect(deletion.deletedSchedules == [cascadeA, cascadeB])
    #expect(try db.missionTemplate(id: cascadeTemplate.id) == nil)
    #expect(
        try db.schedules(campId: fixture.camp.id).contains {
            $0.templateId == cascadeTemplate.id
        } == false
    )
}

@Test func scheduleExtremeFiniteLastFiredAtPersistsNumericallyReloadsAndDedupes()
    throws
{
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db)
    try db.saveMissionTemplate(fixture.template)
    let extremeFiniteFire = Date(timeIntervalSince1970: 253_402_300_800)
    let schedule = ScheduleRecord(
        id: "schedule-extreme-finite",
        templateId: fixture.template.id,
        frequency: .daily,
        hour: 0,
        minute: 0,
        weekday: nil,
        enabled: true,
        lastFiredAt: extremeFiniteFire,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    try db.saveSchedule(schedule)

    let storageClass = try db.pool.read { database in
        try String.fetchOne(
            database,
            sql: "SELECT typeof(lastFiredAt) FROM schedule WHERE id = ?",
            arguments: [schedule.id]
        )
    }
    #expect(storageClass == "integer" || storageClass == "real")
    let reloaded = try #require(try db.schedule(id: schedule.id))
    #expect(reloaded.lastFiredAt == extremeFiniteFire)

    let (calendar, timeZone) = scheduleCalendar("UTC")
    #expect(throws: ScheduleSlotComponentsUnavailableError.self) {
        _ = try ScheduleMath.slotContext(
            for: extremeFiniteFire,
            frequency: schedule.frequency,
            hour: schedule.hour,
            minute: schedule.minute,
            weekday: schedule.weekday,
            calendar: calendar,
            timeZone: timeZone
        )
    }
    #expect(try db.schedule(id: schedule.id)?.lastFiredAt == extremeFiniteFire)
    #expect(try db.scheduleFires(scheduleId: schedule.id).isEmpty)
    #expect(try db.scheduleEvaluationCursor(scheduleId: schedule.id) == nil)
}

@Test func scheduleLegacyTextLastFiredAtRemainsReadable() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db)
    try db.saveMissionTemplate(fixture.template)
    let schedule = ScheduleRecord(
        id: "schedule-legacy-text",
        templateId: fixture.template.id,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        enabled: true,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try db.saveSchedule(schedule)
    try db.pool.write { database in
        try database.execute(
            sql: """
                UPDATE schedule
                SET lastFiredAt = '2026-07-14 09:00:00.000'
                WHERE id = ?
                """,
            arguments: [schedule.id]
        )
    }

    let rawStorage = try db.pool.read { database in
        (
            try String.fetchOne(
                database,
                sql: "SELECT typeof(lastFiredAt) FROM schedule WHERE id = ?",
                arguments: [schedule.id]
            ),
            try String.fetchOne(
                database,
                sql: "SELECT lastFiredAt FROM schedule WHERE id = ?",
                arguments: [schedule.id]
            )
        )
    }
    #expect(rawStorage.0 == "text")
    #expect(rawStorage.1 == "2026-07-14 09:00:00.000")

    let reloaded = try #require(try db.schedule(id: schedule.id))
    let expected = scheduleDate(
        2026,
        7,
        14,
        9,
        0,
        timeZoneID: "UTC"
    )
    #expect(reloaded.lastFiredAt == expected)
}

@Test func scheduleDateEncodingChangesOnlyLastFiredAt() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db)
    try db.saveMissionTemplate(fixture.template)
    let lastFiredAt = Date(timeIntervalSince1970: 1_721_034_000.5)
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000.25)
    let schedule = ScheduleRecord(
        id: "schedule-date-encoding-boundary",
        templateId: fixture.template.id,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 3,
        enabled: true,
        lastFiredAt: lastFiredAt,
        createdAt: createdAt
    )

    try db.saveSchedule(schedule)

    let storageClasses = try db.pool.read { database in
        try Row.fetchOne(
            database,
            sql: """
                SELECT
                    typeof(lastFiredAt) AS lastFiredAtType,
                    typeof(createdAt) AS createdAtType
                FROM schedule
                WHERE id = ?
                """,
            arguments: [schedule.id]
        )
    }
    let row = try #require(storageClasses)
    let lastFiredAtType: String = row["lastFiredAtType"]
    let createdAtType: String = row["createdAtType"]
    #expect(
        lastFiredAtType == "integer" || lastFiredAtType == "real"
    )
    #expect(createdAtType == "text")

    let reloaded = try #require(try db.schedule(id: schedule.id))
    #expect(reloaded.lastFiredAt == lastFiredAt)
    #expect(reloaded.createdAt == createdAt)
}

@Test func guideBroadcastLandsInGuideThread() throws {
    let db = try scheduleTempDB()
    let camp = try db.ensureDefaultCamp()
    let messageId = try db.appendGuideBroadcast(campId: camp.id, text: "晨报来了")
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let messages = try db.messages(threadId: thread.id)
    #expect(messages.map(\.id) == [messageId])
    #expect(messages.first?.role == "guide")
    #expect(messages.first?.text == "晨报来了")
}

@Test func scheduleFiredEventMarksScheduledOrigin() throws {
    let fixture = try makeScheduleFireTestFixture(
        scheduleId: "schedule-fired-origin"
    )
    let firedAt = scheduleDate(2026, 7, 14, 9, 0, timeZoneID: "America/Los_Angeles")
    let result = try fixture.database.startScheduledMission(
        scheduleStartCommand(
            fixture,
            context: try scheduleSlotContext(fixture, at: firedAt),
            preparation: scheduleSelectedPreparation(fixture),
            traceId: "trace-scheduled-origin"
        ),
        planningProviderResolver: ScheduleTestResolverRecorder()
    )
    let missionId = try #require(result.missionId)

    let origin = try #require(
        try fixture.database.scheduledOrigin(missionId: missionId)
    )
    #expect(origin.scheduleId == fixture.schedule.id)
    #expect(origin.templateId == fixture.template.id)
    let events = try fixture.database.events(missionId: missionId)
    #expect(events.contains { $0.kind == "schedule_fired" })

    let malformedEventId = try fixture.database.pool.write { database in
        try AppDatabase.appendLegacyEventAndScope(
            database,
            missionId: missionId,
            cardId: nil,
            runId: nil,
            kind: EventKind.scheduleFired,
            payloadJSON: "{}",
            createdAt: Date(timeIntervalSince1970: 2_000_000_000)
        ).id
    }
    do {
        _ = try fixture.database.scheduledOrigin(missionId: missionId)
        Issue.record("malformed scheduled origin was accepted")
    } catch let error as ScheduleStoreProjectionError {
        #expect(error == .invalidScheduledOrigin(eventId: malformedEventId))
    }
}
