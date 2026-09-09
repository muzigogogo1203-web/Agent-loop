import Testing
import Foundation
import GRDB
import AgentLoopCore

private func tempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func kernelControl(_ appDatabase: AppDatabase) throws -> KernelControlRecord {
    try appDatabase.pool.read { database in
        try #require(try KernelControlRecord.fetchOne(database, key: "global"))
    }
}

private func globalDispatchEvents(_ appDatabase: AppDatabase) throws -> [EventRecord] {
    try appDatabase.pool.read { database in
        try EventRecord
            .filter(
                Column("missionId") == nil
                    && Column("cardId") == nil
                    && Column("runId") == nil
                    && ["camp_halted", "camp_resumed"].contains(Column("kind"))
            )
            .order(Column.rowID)
            .fetchAll(database)
    }
}

@Test func databaseUsesFiveSecondBusyTimeoutAndWAL() throws {
    let appDatabase = try tempDB()
    let (busyTimeout, journalMode) = try appDatabase.pool.writeWithoutTransaction { db in
        let busyTimeout = try #require(try Int.fetchOne(db, sql: "PRAGMA busy_timeout"))
        let journalMode = try #require(try String.fetchOne(db, sql: "PRAGMA journal_mode"))
        return (busyTimeout, journalMode)
    }

    #expect(busyTimeout == 5_000)
    #expect(journalMode.lowercased() == "wal")
}

@Test func durableHaltMigrationCreatesOneRunningSingletonAndReplays() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: dir.appendingPathComponent("v6.sqlite").path)
    let migrator = AppDatabase.migrator

    #expect(migrator.migrations.contains("v6-durable-halt"))
    #expect(migrator.migrations.firstIndex(of: "v6-durable-halt")
            == migrator.migrations.firstIndex(of: "v6").map { $0 + 1 })

    try migrator.migrate(pool, upTo: "v6")
    #expect(try pool.read { try !$0.tableExists("kernel_control") })

    try migrator.migrate(pool, upTo: "v6-durable-halt")
    let first = try pool.read { database in
        try #require(try KernelControlRecord.fetchOne(database, key: "global"))
    }
    #expect(first.dispatchMode == .running)
    #expect(try pool.read { try KernelControlRecord.fetchCount($0) } == 1)

    try migrator.migrate(pool)
    try migrator.migrate(pool)

    let replayed = try pool.read { database in
        try #require(try KernelControlRecord.fetchOne(database, key: "global"))
    }
    #expect(replayed == first)
    #expect(try pool.read { try KernelControlRecord.fetchCount($0) } == 1)
}

@Test func durableHaltCASIsAtomicIdempotentAndGloballyAudited() throws {
    let appDatabase = try tempDB()

    #expect(try appDatabase.dispatchMode() == .running)
    #expect(try appDatabase.transitionDispatchMode(from: .running, to: .halted))
    let haltedAt = try kernelControl(appDatabase).updatedAt
    #expect(try !appDatabase.transitionDispatchMode(from: .running, to: .halted))
    #expect(try kernelControl(appDatabase).updatedAt == haltedAt)

    #expect(try appDatabase.transitionDispatchMode(from: .halted, to: .running))
    let resumedAt = try kernelControl(appDatabase).updatedAt
    #expect(try !appDatabase.transitionDispatchMode(from: .halted, to: .running))
    #expect(try kernelControl(appDatabase).updatedAt == resumedAt)

    let events = try globalDispatchEvents(appDatabase)
    #expect(events.map(\.kind) == ["camp_halted", "camp_resumed"])
    #expect(events.allSatisfy {
        $0.missionId == nil && $0.cardId == nil && $0.runId == nil
    })
}

@Test func durableHaltCASRejectsStaleExpectedMode() throws {
    let appDatabase = try tempDB()

    #expect(throws: StaleKernelControlStateError(expected: .halted, actual: .running)) {
        try appDatabase.transitionDispatchMode(from: .halted, to: .halted)
    }
    #expect(try appDatabase.dispatchMode() == .running)
    #expect(try globalDispatchEvents(appDatabase).isEmpty)
}

@Test func haltEventFailureRollsBackKernelControlProjection() throws {
    let appDatabase = try tempDB()
    try appDatabase.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_camp_halted_event
            BEFORE INSERT ON event
            WHEN NEW.kind = 'camp_halted' BEGIN
                SELECT RAISE(ABORT, 'injected camp_halted failure');
            END
            """)
    }

    #expect(throws: DatabaseError.self) {
        try appDatabase.transitionDispatchMode(from: .running, to: .halted)
    }
    #expect(try appDatabase.dispatchMode() == .running)
    #expect(try globalDispatchEvents(appDatabase).isEmpty)
}

@Test func resumeEventFailureRollsBackKernelControlProjection() throws {
    let appDatabase = try tempDB()
    #expect(try appDatabase.transitionDispatchMode(from: .running, to: .halted))
    try appDatabase.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_camp_resumed_event
            BEFORE INSERT ON event
            WHEN NEW.kind = 'camp_resumed' BEGIN
                SELECT RAISE(ABORT, 'injected camp_resumed failure');
            END
            """)
    }

    #expect(throws: DatabaseError.self) {
        try appDatabase.transitionDispatchMode(from: .halted, to: .running)
    }
    #expect(try appDatabase.dispatchMode() == .halted)
    #expect(try globalDispatchEvents(appDatabase).map(\.kind) == ["camp_halted"])
}

@Test func missingKernelControlSingletonFailsExplicitly() throws {
    let appDatabase = try tempDB()
    try appDatabase.pool.write { database in
        _ = try KernelControlRecord.deleteOne(database, key: "global")
    }

    #expect(throws: RecordNotFoundError(table: "kernel_control", id: "global")) {
        try appDatabase.dispatchMode()
    }
    #expect(throws: RecordNotFoundError(table: "kernel_control", id: "global")) {
        try appDatabase.transitionDispatchMode(from: .running, to: .halted)
    }
}

@Test func invalidKernelControlModeNeverDefaultsToRunning() throws {
    let appDatabase = try tempDB()
    try appDatabase.pool.writeWithoutTransaction { database in
        try database.execute(sql: "PRAGMA ignore_check_constraints = ON")
        try database.execute(
            sql: "UPDATE kernel_control SET dispatchMode = 'corrupt' WHERE id = 'global'"
        )
        try database.execute(sql: "PRAGMA ignore_check_constraints = OFF")
    }

    #expect(throws: (any Error).self) {
        try appDatabase.dispatchMode()
    }
}

@Test func migratesAndBootstraps() throws {
    let db = try tempDB()
    let camp = try db.ensureDefaultCamp()
    #expect(camp.name == "我的营地")
    let guide = try db.guide(campId: camp.id)
    #expect(guide?.kind == .guide)
    // 幂等：再次调用不重复创建
    _ = try db.ensureDefaultCamp()
    let camps = try db.pool.read { try CampRecord.fetchCount($0) }
    #expect(camps == 1)
}

@Test func companionCRUD() throws {
    let db = try tempDB()
    let c = CompanionRecord.new(name: "阿规", color: "purple", rolePrompt: "你是产品伙伴", model: "claude-sonnet-4-6") // Fix 7: let, no &
    try db.saveCompanion(c)
    let all = try db.regularCompanions()
    #expect(all.map(\.name) == ["阿规"])
}

@Test func companionsMissingIdThrows() throws {
    let db = try tempDB()
    #expect(throws: RecordNotFoundError.self) {
        try db.companions(ids: ["missing"])
    }
}

@Test func companionsDedupesDuplicateIds() throws {
    let db = try tempDB()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "model-a")
    let b = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "r", model: "model-b")
    try db.saveCompanion(a)
    try db.saveCompanion(b)

    let companions = try db.companions(ids: [a.id, b.id, a.id])
    #expect(companions.map(\.id) == [a.id, b.id])
}

@Test func eventAppendAndProjectionSameTransaction() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "我的营地", squadName: "试营小队",
        goal: "写清单", cardTitle: "写清单", cardDescription: "…",
        expectedOutput: "一份 md", assigneeId: nil, maxTurns: 30)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: ["by": "test"])
    let card = try db.card(id: ids.cardId)
    #expect(card?.status == .running)
    let events = try db.events(cardId: ids.cardId)
    #expect(events.contains { $0.kind == "card_started" })
}

@Test func illegalTransitionThrows() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e", assigneeId: nil, maxTurns: 30)
    // ready → done 非法（createSingleCardMission 建卡即 ready；done 必须先经 running，spec §5.1）
    #expect(throws: CardTransitionError.self) {
        try db.transitionCard(id: ids.cardId, to: .done, eventKind: "x", payload: .object([:]))
    }
}

@Test func cardStatusTransitionMatrixKeepsReturnForReworkConservative() {
    func key(_ from: CardStatus, _ to: CardStatus) -> String {
        "\(from.rawValue)->\(to.rawValue)"
    }
    let allowed: Set<String> = [
        key(.todo, .ready),
        key(.ready, .running),
        key(.running, .done),
        key(.running, .blocked),
        key(.blocked, .ready),
        key(.blocked, .canceled),
        key(.todo, .canceled),
        key(.ready, .canceled),
        key(.ready, .blocked),
        key(.running, .ready),
        key(.running, .canceled),
        key(.done, .ready),
    ]

    for from in CardStatus.allCases {
        for to in CardStatus.allCases {
            #expect(from.canTransition(to: to) == allowed.contains(key(from, to)))
        }
    }
    #expect(CardStatus.done.canTransition(to: .ready))
}

// Fix 3: unknown ids throw instead of silent no-op
@Test func transitionUnknownCardThrows() throws {
    let db = try tempDB()
    #expect(throws: RecordNotFoundError.self) {
        try db.transitionCard(id: "nope", to: .running, eventKind: "x", payload: .object([:]))
    }
}

@Test func finishUnknownRunThrows() throws {
    let db = try tempDB()
    #expect(throws: RecordNotFoundError.self) {
        try db.finishRun(id: "nope", outcome: "completed", turns: 0, tokensIn: 0, tokensOut: 0)
    }
}

@Test func migrationV2AddsColumnsAndNormalizes() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let path = dir.appendingPathComponent("v1.sqlite").path
    let pool = try DatabasePool(path: path)
    let migrator = AppDatabase.migrator
    try migrator.migrate(pool, upTo: "v1")
    try pool.write { db in
        // v1 时代还没有 archived 列（v7 增），按当时 schema 裸 SQL 插入
        try db.execute(
            sql: "INSERT INTO camp (id, name, createdAt) VALUES (?, ?, ?)",
            arguments: ["camp", "c", Date()]
        )
        // v1 时代还没有 workspaceBookmark 列（v4 增），按当时 schema 裸 SQL 插入
        try db.execute(
            sql: """
                INSERT INTO squad (id, campId, name, memberIdsJson, workspacePath, createdAt)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
            arguments: ["squad", "camp", "s", "[]", nil, Date()]
        )
        try db.execute(
            sql: """
                INSERT INTO mission
                    (id, squadId, goalRaw, goalRefined, status, budgetTokens, spentTokens, revision, createdAt)
                VALUES
                    (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: ["mission", "squad", "g", "g", "weird", 1, 0, 1, Date()]
        )
    }

    try migrator.migrate(pool)
    try migrator.migrate(pool)

    let columns = try pool.read { db in
        try db.columns(in: "card").map(\.name)
    }
    #expect(columns.contains("handoffJson"))
    #expect(columns.contains("stage"))
    let status = try pool.read { db in
        try String.fetchOne(db, sql: "SELECT status FROM mission WHERE id = ?", arguments: ["mission"])
    }
    #expect(status == "executing")
}

@Test func completeCardWritesHandoffProjection() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    let handoff = HandoffPayload(
        outcome: "完成",
        summary: "摘要",
        artifacts: [],
        noArtifactReason: "无文件",
        verification: [.init(method: "检查", passed: true, note: "通过")],
        risks: []
    )
    try db.completeCard(id: ids.cardId, runId: nil, handoff: handoff, durableArtifacts: [])

    let card = try #require(try db.card(id: ids.cardId))
    let projected = try #require(card.handoffJson)
    let decoded = try JSONDecoder().decode(HandoffPayload.self, from: Data(projected.utf8))
    #expect(decoded == handoff)
    #expect(card.stage == 1)
}

@Test func eventsByMissionOrdered() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: ["n": 1])
    try db.blockCard(id: ids.cardId, runId: nil, reason: "other", detail: "blocked")

    let events = try db.events(missionId: ids.missionId, limit: 2)
    #expect(events.map(\.kind) == ["card_started", "card_blocked"])
}

@Test func missionsListOrderedDesc() throws {
    let db = try tempDB()
    let first = try db.createMissionShell(goal: "first", companionIds: [], workspacePath: nil)
    let second = try db.createMissionShell(goal: "second", companionIds: [], workspacePath: nil)

    let missions = try db.missions(limit: 2)
    #expect(missions.map(\.id) == [second, first])
}

@Test func suspendAndAnswerRoundTrip() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    let runId = "run-1"
    try db.startRun(cardId: ids.cardId, runId: runId)

    let requestId = try db.suspendCardForUserRequest(
        cardId: ids.cardId,
        runId: runId,
        kind: .choice,
        prompt: "选哪个？",
        options: ["A", "B"]
    )

    let blocked = try #require(try db.card(id: ids.cardId))
    #expect(blocked.status == .blocked)
    #expect(blocked.blockedReasonJson?.contains(requestId) == true)

    let pending = try db.pendingUserRequests(missionId: ids.missionId)
    #expect(pending.map(\.id) == [requestId])
    #expect(pending[0].humanAnswer() == "")

    try db.answerUserRequest(requestId: requestId, answerJson: #"{"choice":1}"#)

    let ready = try #require(try db.card(id: ids.cardId))
    #expect(ready.status == .ready)
    #expect(ready.blockedReasonJson == nil)
    #expect(try db.pendingUserRequests(missionId: ids.missionId).isEmpty)

    let answered = try db.answeredRequests(cardId: ids.cardId)
    #expect(answered.count == 1)
    #expect(answered[0].humanAnswer() == "B")

    let events = try db.events(missionId: ids.missionId, limit: 20)
    #expect(events.contains { $0.kind == "user_request_created" && $0.payloadJson.contains(requestId) })
    #expect(events.contains { $0.kind == "card_ready" && $0.payloadJson.contains("answeredRequest") })
    #expect(events.contains { $0.kind == "user_request_answered" && $0.payloadJson.contains(requestId) })
}

@Test func pendingRequestsAcrossCards() throws {
    let db = try tempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let missionId = try db.createMissionShell(goal: "g", companionIds: [companion.id], workspacePath: nil)
    try db.planMission(missionId: missionId, goalRefined: "g", drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "B", description: "b", expectedOutput: "ob", assignee: 0, dependsOn: []),
    ])
    let cards = try db.cards(missionId: missionId)
    try db.transitionCard(id: cards[0].id, to: .ready, eventKind: "card_ready", payload: .object([:]))
    try db.startRun(cardId: cards[0].id, runId: "run-a")
    let first = try db.suspendCardForUserRequest(
        cardId: cards[0].id,
        runId: "run-a",
        kind: .confirm,
        prompt: "确认 A？",
        options: nil
    )
    try db.transitionCard(id: cards[1].id, to: .ready, eventKind: "card_ready", payload: .object([:]))
    try db.startRun(cardId: cards[1].id, runId: "run-b")
    let second = try db.suspendCardForUserRequest(
        cardId: cards[1].id,
        runId: "run-b",
        kind: .text,
        prompt: "补充 B",
        options: nil
    )

    #expect(try db.pendingUserRequests(missionId: missionId).map(\.id) == [first, second])
    try db.answerUserRequest(requestId: first, answerJson: #"{"confirm":true}"#)
    #expect(try db.pendingUserRequests(missionId: missionId).map(\.id) == [second])
    #expect(try db.answeredRequests(cardId: cards[0].id).first?.humanAnswer() == "确认")
}

private enum P1MigrationInjectedFailure: Error {
    case afterGuardDrop
}

private func p1TemporaryPool(_ label: String) throws -> DatabasePool {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agentloop-p1-\(label)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return try DatabasePool(
        path: directory.appendingPathComponent("fixture.sqlite").path
    )
}

private func p1SQLiteObjectNames(
    _ database: Database,
    type: String
) throws -> Set<String> {
    Set(try String.fetchAll(
        database,
        sql: """
            SELECT name
            FROM sqlite_master
            WHERE type = ?
            ORDER BY name
            """,
        arguments: [type]
    ))
}

private struct P1ForeignKeyShape: Equatable, Comparable {
    let from: String
    let table: String
    let to: String
    let onDelete: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.from < rhs.from
    }
}

private func p1ForeignKeyShapes(
    _ database: Database,
    table: String
) throws -> [P1ForeignKeyShape] {
    try Row.fetchAll(
        database,
        sql: "PRAGMA foreign_key_list(\(table))"
    ).map { row in
        P1ForeignKeyShape(
            from: row["from"],
            table: row["table"],
            to: row["to"],
            onDelete: row["on_delete"]
        )
    }.sorted()
}

private func p1SQLiteSchemaSnapshot(_ database: Database) throws -> [String] {
    try String.fetchAll(
        database,
        sql: """
            SELECT quote(type) || char(31) || quote(name) || char(31)
                   || quote(tbl_name) || char(31) || COALESCE(quote(sql), 'NULL')
            FROM sqlite_master
            ORDER BY type, name, tbl_name
            """
    )
}

private func p1InsertScheduleFireScopeFixture(_ database: Database) throws {
    let now = 1_700_000_000.0
    try database.execute(
        sql: """
            INSERT INTO camp (id, name, archived, createdAt)
            VALUES ('schedule-fire-camp', 'Schedule Fire', 0, ?)
            """,
        arguments: [now]
    )
    try database.execute(
        sql: """
            INSERT INTO mission_template (
              id, name, goal, companionIdsJson, workspacePath, budgetTokens,
              autonomy, campId, createdAt
            ) VALUES (
              'schedule-fire-template', 'Template', 'Goal', '[]', NULL, 1000,
              'standard', 'schedule-fire-camp', ?
            )
            """,
        arguments: [now]
    )
    try database.execute(
        sql: """
            INSERT INTO schedule (
              id, templateId, frequency, hour, minute, weekday, enabled,
              lastFiredAt, createdAt
            ) VALUES (
              'schedule-fire-schedule', 'schedule-fire-template', 'daily',
              9, 30, NULL, 1, NULL, ?
            )
            """,
        arguments: [now]
    )
    try database.execute(
        sql: """
            INSERT INTO schedule (
              id, templateId, frequency, hour, minute, weekday, enabled,
              lastFiredAt, createdAt
            ) VALUES (
              'schedule-fire-cursor-only', 'schedule-fire-template', 'daily',
              10, 45, NULL, 1, NULL, ?
            )
            """,
        arguments: [now]
    )
    try database.execute(
        sql: """
            INSERT INTO squad (
              id, campId, name, memberIdsJson, workspacePath,
              workspaceBookmark, createdAt
            ) VALUES (
              'schedule-fire-squad', 'schedule-fire-camp', 'Squad', '[]',
              NULL, NULL, ?
            )
            """,
        arguments: [now]
    )
    try database.execute(
        sql: """
            INSERT INTO mission (
              id, squadId, goalRaw, goalRefined, status, budgetTokens,
              spentTokens, revision, autonomy, createdAt
            ) VALUES (
              'schedule-fire-mission', 'schedule-fire-squad', 'Goal', 'Goal',
              'planning', 1000, 0, 1, 'standard', ?
            )
            """,
        arguments: [now]
    )
}

private func p1InsertScheduleFireFixture(
    _ database: Database,
    id: String,
    scheduledAt: Double = 1_700_000_000.0,
    replayOfFireId: String? = nil,
    replayIdempotencyKey: String? = nil,
    replayPayloadHash: String? = nil,
    state: String,
    missionId: String? = nil,
    errorCode: String? = nil,
    errorMessage: String? = nil,
    redactedAt: Double? = nil
) throws {
    try database.execute(
        sql: """
            INSERT INTO schedule_fire (
              id, scheduleId, templateId, slotKey, scheduledAt,
              replayOfFireId, replayIdempotencyKey, replayPayloadHash, state,
              missionId, traceId, errorCode, errorMessage, createdAt,
              redactedAt
            ) VALUES (
              :id, 'schedule-fire-schedule', 'schedule-fire-template',
              :slotKey, :scheduledAt, :replayOfFireId,
              :replayIdempotencyKey, :replayPayloadHash, :state, :missionId,
              :traceId, :errorCode, :errorMessage, :createdAt, :redactedAt
            )
            """,
        arguments: StatementArguments([
            "id": id,
            "slotKey": "slot-\(id)",
            "scheduledAt": scheduledAt,
            "replayOfFireId": replayOfFireId,
            "replayIdempotencyKey": replayIdempotencyKey,
            "replayPayloadHash": replayPayloadHash,
            "state": state,
            "missionId": missionId,
            "traceId": "trace-\(id)",
            "errorCode": errorCode,
            "errorMessage": errorMessage,
            "createdAt": scheduledAt + 1,
            "redactedAt": redactedAt,
        ] as [String: (any DatabaseValueConvertible)?])
    )
}

private func p1InsertValidAttemptEventFixture(_ database: Database) throws {
    let now = Date(timeIntervalSinceReferenceDate: 10_000)
    try database.execute(
        sql: "INSERT INTO camp (id, name, archived, createdAt) VALUES (?, ?, ?, ?)",
        arguments: ["p1-camp", "P1", false, now]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work (
              id, campId, kind, aggregateType, aggregateId, idempotencyKey,
              state, attempt, maxAttempts, notBefore, leaseOwner,
              leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
              errorMessage, traceId, version, createdAt, updatedAt, finishedAt
            ) VALUES (
              ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, NULL, NULL,
              NULL, ?, ?, ?, ?, NULL
            )
            """,
        arguments: [
            "p1-work", "p1-camp", "planning", "mission", "mission-1",
            "idem-1", "running", 1, 4, "worker-1",
            now.addingTimeInterval(30), #"{"value":1}"#,
            String(repeating: "a", count: 64), "trace-1", 2, now, now,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt (
              workId, attempt, id, workerId, startedAt, endedAt, outcome,
              errorCode, errorMessage, traceId, terminalWorkVersion
            ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, NULL)
            """,
        arguments: [
            "p1-work", 1, "p1-attempt", "worker-1", now, "trace-1",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt_event (
              id, workId, attempt, sequence, eventKind, workerId,
              workVersion, resultingWorkState, errorCode, errorMessage,
              occurredAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?)
            """,
        arguments: [
            "p1-event", "p1-work", 1, 0, "claimed", "worker-1", 2,
            "running", now,
        ]
    )
}

@Test func durableWorkMigrationMatrixThroughV12() throws {
    let migrator = AppDatabase.migrator
    #expect(migrator.migrations.contains("v12-p1-durable-work"))

    let predecessors: [(String, String?)] = [
        ("fresh", nil),
        ("v7", "v7"),
        ("v8", "v8-coding-ranch"),
        ("v9", "v9-evercamp"),
        ("v10", "v10-runtime-profiles"),
        ("v11", "v11-cli-kinds"),
    ]

    for (label, predecessor) in predecessors {
        let pool = try p1TemporaryPool(label)
        if let predecessor {
            try migrator.migrate(pool, upTo: predecessor)
            #expect(try pool.read {
                try !$0.tableExists("durable_work")
            })
        }

        try migrator.migrate(pool, upTo: "v12-p1-durable-work")
        try migrator.migrate(pool, upTo: "v12-p1-durable-work")

        try pool.read { database in
            let hasWork = try database.tableExists("durable_work")
            let hasAttempt = try database.tableExists(
                "durable_work_attempt"
            )
            let hasEvent = try database.tableExists(
                "durable_work_attempt_event"
            )
            let hasScheduleFire = try database.tableExists("schedule_fire")
            let foreignKeyViolations = try database.foreignKeyViolations()
            let hasForeignKeyViolation =
                try foreignKeyViolations.next() != nil
            let integrity = try String.fetchOne(
                database,
                sql: "PRAGMA integrity_check"
            )
            #expect(hasWork)
            #expect(hasAttempt)
            #expect(hasEvent)
            #expect(!hasScheduleFire)
            #expect(!hasForeignKeyViolation)
            #expect(integrity == "ok")
        }
    }
}

@Test func durableWorkMigrationHasExactTablesIndexesChecksAndTriggers() throws {
    let pool = try p1TemporaryPool("exact-ddl")
    try AppDatabase.migrator.migrate(
        pool,
        upTo: "v12-p1-durable-work"
    )

    try pool.read { database in
        let tableNames = try p1SQLiteObjectNames(database, type: "table")
        #expect(tableNames.contains("durable_work"))
        #expect(tableNames.contains("durable_work_attempt"))
        #expect(tableNames.contains("durable_work_attempt_event"))
        #expect(!tableNames.contains("schedule_fire"))

        let workColumns = try database.columns(in: "durable_work").map(\.name)
        #expect(workColumns == [
            "id", "campId", "kind", "aggregateType", "aggregateId",
            "idempotencyKey", "state", "attempt", "maxAttempts", "notBefore",
            "leaseOwner", "leaseExpiresAt", "inputJson", "inputHash",
            "outputJson", "errorCode", "errorMessage", "traceId", "version",
            "createdAt", "updatedAt", "finishedAt",
        ])
        let attemptColumns = try database.columns(
            in: "durable_work_attempt"
        ).map(\.name)
        #expect(attemptColumns == [
            "workId", "attempt", "id", "workerId", "startedAt", "endedAt",
            "outcome", "errorCode", "errorMessage", "traceId",
            "terminalWorkVersion",
        ])
        let eventColumns = try database.columns(
            in: "durable_work_attempt_event"
        ).map(\.name)
        #expect(eventColumns == [
            "id", "workId", "attempt", "sequence", "eventKind", "workerId",
            "workVersion", "resultingWorkState", "errorCode", "errorMessage",
            "occurredAt",
        ])

        let indexNames = try p1SQLiteObjectNames(database, type: "index")
        #expect(indexNames.contains("durable_work_one_active_aggregate"))
        #expect(indexNames.contains("durable_work_claimable"))
        #expect(indexNames.contains("durable_work_aggregate_history"))
        #expect(indexNames.contains("durable_work_attempt_one_terminal"))
        #expect(indexNames.contains("durable_work_attempt_event_work"))

        let triggerNames = try p1SQLiteObjectNames(database, type: "trigger")
        #expect(
            triggerNames.contains(
                "durable_work_attempt_event_reject_update"
            )
        )
        #expect(
            triggerNames.contains(
                "durable_work_attempt_event_reject_delete"
            )
        )

        let workDDL = try #require(try String.fetchOne(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name = 'durable_work'
                """
        ))
        #expect(workDDL.contains("CHECK (attempt >= 0)"))
        #expect(workDDL.contains("CHECK (maxAttempts >= 1)"))
        #expect(workDDL.contains("CHECK (outputJson IS NULL OR state = 'succeeded')"))
        #expect(workDDL.contains("errorCode = 'worker_interrupted'"))
        #expect(workDDL.contains("errorCode = 'work_canceled'"))

        let eventDDL = try #require(try String.fetchOne(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table'
                  AND name = 'durable_work_attempt_event'
                """
        ))
        #expect(eventDDL.contains("CHECK ((sequence = 0) = (eventKind = 'claimed'))"))
        #expect(eventDDL.contains("resultingWorkState IN ('retryScheduled','failed')"))
        #expect(eventDDL.contains("resultingWorkState = 'queued'"))
    }
}

@Test func scheduleFireMigrationMatrixAndExactDDL() throws {
    let migrator = AppDatabase.migrator
    let durableIndex = try #require(
        migrator.migrations.firstIndex(of: "v12-p1-durable-work")
    )
    let scheduleFireIndex = try #require(
        migrator.migrations.firstIndex(of: "v12-p1-schedule-fire")
    )
    #expect(scheduleFireIndex == durableIndex + 1)

    let predecessors: [(String, String?)] = [
        ("fresh", nil),
        ("v7", "v7"),
        ("v8", "v8-coding-ranch"),
        ("v9", "v9-evercamp"),
        ("v10", "v10-runtime-profiles"),
        ("v11", "v11-cli-kinds"),
        ("v12-durable", "v12-p1-durable-work"),
    ]

    for (label, predecessor) in predecessors {
        let pool = try p1TemporaryPool("schedule-fire-\(label)")
        if let predecessor {
            try migrator.migrate(pool, upTo: predecessor)
        }
        let predecessorPresence = try pool.read { database in
            (
                try database.tableExists("schedule_fire"),
                try database.tableExists("schedule_evaluation_cursor")
            )
        }
        #expect(!predecessorPresence.0)
        #expect(!predecessorPresence.1)

        try migrator.migrate(pool, upTo: "v12-p1-schedule-fire")
        let firstSchema = try pool.read(p1SQLiteSchemaSnapshot)
        try migrator.migrate(pool, upTo: "v12-p1-schedule-fire")
        let replayedSchema = try pool.read(p1SQLiteSchemaSnapshot)
        #expect(replayedSchema == firstSchema)

        try pool.read { database in
            #expect(try database.tableExists("schedule_fire"))
            #expect(try database.tableExists("schedule_evaluation_cursor"))
            #expect(try p1SQLiteObjectNames(database, type: "table").count == 29)
            #expect(try p1SQLiteObjectNames(database, type: "index").count == 60)
            #expect(try p1SQLiteObjectNames(database, type: "trigger").count == 4)
            #expect(
                try p1SQLiteObjectNames(database, type: "table")
                    .isDisjoint(with: [
                        "failure_record",
                        "context_degradation",
                    ])
            )
            #expect(
                try p1SQLiteObjectNames(database, type: "index")
                    .isDisjoint(with: [
                        "failure_record_open_scope",
                        "context_degradation_mission",
                        "context_degradation_card",
                    ])
            )
            let violations = try database.foreignKeyViolations()
            #expect(try violations.next() == nil)
            #expect(
                try String.fetchOne(database, sql: "PRAGMA integrity_check")
                    == "ok"
            )
        }
    }

    let pool = try p1TemporaryPool("schedule-fire-exact-ddl")
    try migrator.migrate(pool, upTo: "v12-p1-schedule-fire")
    try pool.read { database in
        #expect(try database.columns(in: "schedule_fire").map(\.name) == [
            "id", "scheduleId", "templateId", "slotKey", "scheduledAt",
            "replayOfFireId", "replayIdempotencyKey", "replayPayloadHash",
            "state", "missionId", "traceId", "errorCode", "errorMessage",
            "createdAt", "redactedAt",
        ])
        #expect(
            try database.columns(in: "schedule_evaluation_cursor").map(\.name)
                == [
                    "scheduleId", "lastEvaluatedSlotKey",
                    "lastEvaluatedScheduledAt", "version", "updatedAt",
                ]
        )
        #expect(try p1ForeignKeyShapes(database, table: "schedule_fire") == [
            .init(
                from: "missionId",
                table: "mission",
                to: "id",
                onDelete: "RESTRICT"
            ),
            .init(
                from: "replayOfFireId",
                table: "schedule_fire",
                to: "id",
                onDelete: "RESTRICT"
            ),
            .init(
                from: "scheduleId",
                table: "schedule",
                to: "id",
                onDelete: "RESTRICT"
            ),
            .init(
                from: "templateId",
                table: "mission_template",
                to: "id",
                onDelete: "RESTRICT"
            ),
        ])
        #expect(
            try p1ForeignKeyShapes(
                database,
                table: "schedule_evaluation_cursor"
            ) == [
                .init(
                    from: "scheduleId",
                    table: "schedule",
                    to: "id",
                    onDelete: "CASCADE"
                ),
            ]
        )

        let scheduleIndexNames = Set(try p1SQLiteObjectNames(
            database,
            type: "index"
        ).filter {
            $0.contains("schedule_fire")
                || $0.contains("schedule_evaluation_cursor")
        })
        #expect(scheduleIndexNames == Set([
            "schedule_fire_original_slot",
            "schedule_fire_replay_key",
            "schedule_fire_schedule_time",
            "sqlite_autoindex_schedule_fire_1",
            "sqlite_autoindex_schedule_evaluation_cursor_1",
        ]))

        let originalIndexDDL = try #require(try String.fetchOne(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'index' AND name = 'schedule_fire_original_slot'
                """
        ))
        let replayIndexDDL = try #require(try String.fetchOne(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'index' AND name = 'schedule_fire_replay_key'
                """
        ))
        #expect(originalIndexDDL.contains("WHERE replayOfFireId IS NULL"))
        #expect(
            replayIndexDDL.contains("WHERE replayIdempotencyKey IS NOT NULL")
        )

        let fireDDL = try #require(try String.fetchOne(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name = 'schedule_fire'
                """
        ))
        #expect(fireDDL.contains("state IN ('started','failed')"))
        #expect(!fireDDL.contains("intended"))
        #expect(fireDDL.contains("length(replayPayloadHash) = 64"))
        #expect(fireDDL.contains("length(errorMessage) <= 1000"))
        #expect(fireDDL.contains("redactedAt IS NULL OR errorMessage IS NULL"))

        let triggerNames = try p1SQLiteObjectNames(database, type: "trigger")
        #expect(triggerNames == Set([
            "event_no_delete",
            "event_no_update",
            "durable_work_attempt_event_reject_delete",
            "durable_work_attempt_event_reject_update",
        ]))
        #expect(!triggerNames.contains { $0.contains("schedule_fire") })
    }

    try pool.write { database in
        try p1InsertScheduleFireScopeFixture(database)
        try p1InsertScheduleFireFixture(
            database,
            id: "legal-started-original",
            state: "started",
            missionId: "schedule-fire-mission"
        )
        try p1InsertScheduleFireFixture(
            database,
            id: "legal-failed-original",
            state: "failed",
            errorCode: "schedule_configuration_invalid",
            errorMessage: "定时行动配置无效。"
        )
        try p1InsertScheduleFireFixture(
            database,
            id: "legal-started-replay",
            replayOfFireId: "legal-failed-original",
            replayIdempotencyKey: "schedule-replay:legal",
            replayPayloadHash: String(repeating: "a", count: 64),
            state: "started",
            missionId: "schedule-fire-mission"
        )
        try database.execute(
            sql: """
                INSERT INTO schedule_evaluation_cursor (
                  scheduleId, lastEvaluatedSlotKey,
                  lastEvaluatedScheduledAt, version, updatedAt
                ) VALUES (
                  'schedule-fire-schedule', 'slot-legal-started-replay',
                  1700000000.0, 1, 1700000001.0
                )
                """
        )
    }

    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-intended",
                state: "intended",
                missionId: "schedule-fire-mission"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write { database in
            try database.execute(
                sql: """
                    INSERT INTO schedule_evaluation_cursor (
                      scheduleId, lastEvaluatedSlotKey,
                      lastEvaluatedScheduledAt, version, updatedAt
                    ) VALUES (
                      'schedule-fire-cursor-only', 'slot-invalid-version',
                      1700000000.0, 0, 1700000001.0
                    )
                    """
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-partial-replay",
                replayOfFireId: "legal-failed-original",
                state: "failed",
                errorCode: "schedule_configuration_invalid"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-original-replay-key",
                replayIdempotencyKey: "schedule-replay:orphan",
                replayPayloadHash: String(repeating: "a", count: 64),
                state: "failed",
                errorCode: "schedule_configuration_invalid"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-short-hash",
                replayOfFireId: "legal-failed-original",
                replayIdempotencyKey: "schedule-replay:short-hash",
                replayPayloadHash: String(repeating: "a", count: 63),
                state: "failed",
                errorCode: "schedule_configuration_invalid"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-started-with-error",
                state: "started",
                missionId: "schedule-fire-mission",
                errorCode: "schedule_configuration_invalid"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-started-without-mission",
                state: "started"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-failed-with-mission",
                state: "failed",
                missionId: "schedule-fire-mission",
                errorCode: "schedule_configuration_invalid"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-failed-without-code",
                state: "failed"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-long-message",
                state: "failed",
                errorCode: "schedule_configuration_invalid",
                errorMessage: String(repeating: "x", count: 1_001)
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write {
            try p1InsertScheduleFireFixture(
                $0,
                id: "illegal-redacted-message",
                state: "failed",
                errorCode: "schedule_configuration_invalid",
                errorMessage: "must be absent after redaction",
                redactedAt: 1_700_000_100.0
            )
        }
    }
    #expect(try pool.read {
        try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM schedule_fire")
    } == 3)
}

@Test func scheduleFireSchemaReservesRedactionWithoutAllowingOrdinaryMutation() throws {
    let scheduleStoreSource = try PlanningTestFixtures.source(
        "AgentLoopCore/Database/ScheduleStore.swift"
    )
    for recordName in [
        "ScheduleFireRecord",
        "ScheduleEvaluationCursorRecord",
    ] {
        let start = try #require(
            scheduleStoreSource.range(of: "struct \(recordName)")?.lowerBound
        )
        let openingBrace = try #require(
            scheduleStoreSource[start...].firstIndex(of: "{")
        )
        let declaration = scheduleStoreSource[start..<openingBrace]
        #expect(declaration.contains("FetchableRecord"))
        for forbiddenConformance in ["TableRecord", "PersistableRecord"] {
            #expect(!declaration.contains(forbiddenConformance))
            #expect(
                scheduleStoreSource.range(
                    of: "extension\\s+\(recordName)\\s*:[^{]*"
                        + forbiddenConformance,
                    options: .regularExpression
                ) == nil
            )
        }
    }
    for forbiddenOrdinaryAPI in [
        "saveScheduleFire(",
        "updateScheduleFire(",
        "deleteScheduleFire(",
        "redactScheduleFire(",
        "saveScheduleEvaluationCursor(",
        "updateScheduleEvaluationCursor(",
        "deleteScheduleEvaluationCursor(",
    ] {
        #expect(!scheduleStoreSource.contains(forbiddenOrdinaryAPI))
    }

    let repositoryRoot = PlanningTestFixtures.packageRoot()
        .deletingLastPathComponent()
    let executableURL = try #require(Bundle.main.executableURL)
    let modulesDirectory = executableURL
        .deletingLastPathComponent()
        .appendingPathComponent("Modules")
    let grdbSQLiteModuleMap = repositoryRoot
        .appendingPathComponent(".build/checkouts/GRDB.swift/Sources")
        .appendingPathComponent("GRDBSQLite/module.modulemap")
    #expect(
        FileManager.default.fileExists(atPath: modulesDirectory.path)
    )
    #expect(
        FileManager.default.fileExists(atPath: grdbSQLiteModuleMap.path)
    )

    func typecheckRecordSurface(
        _ source: String
    ) throws -> (status: Int32, diagnostics: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swiftc",
            "-typecheck",
            "-",
            "-I",
            modulesDirectory.path,
            "-package-name",
            "agent_loop",
            "-Xcc",
            "-fmodule-map-file=\(grdbSQLiteModuleMap.path)",
        ]
        let input = Pipe()
        let diagnostics = Pipe()
        process.standardInput = input
        process.standardOutput = diagnostics
        process.standardError = diagnostics
        try process.run()
        try input.fileHandleForWriting.write(
            contentsOf: Data(source.utf8)
        )
        try input.fileHandleForWriting.close()
        let diagnosticData = diagnostics.fileHandleForReading
            .readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: diagnosticData, as: UTF8.self)
        )
    }

    let positiveProbe = try typecheckRecordSurface(
        """
        import GRDB
        import AgentLoopCore
        func readOnlyProbe(_ db: Database) throws {
          _ = try ScheduleFireRecord.fetchOne(
            db,
            sql: "SELECT * FROM schedule_fire WHERE id = ?",
            arguments: ["id"]
          )
          _ = try ScheduleEvaluationCursorRecord.fetchOne(
            db,
            sql: "SELECT * FROM schedule_evaluation_cursor WHERE scheduleId = ?",
            arguments: ["id"]
          )
        }
        """
    )
    #expect(positiveProbe.status == 0)
    #expect(positiveProbe.diagnostics.isEmpty)

    let mutationProbe = try typecheckRecordSurface(
        """
        import GRDB
        import AgentLoopCore
        func forbiddenMutationProbe(_ db: Database) throws {
          _ = try ScheduleFireRecord.deleteAll(db)
          _ = try ScheduleEvaluationCursorRecord.updateAll(
            db,
            Column("version").set(to: 0)
          )
          _ = try ScheduleFireRecord
            .filter(Column("state") == "failed")
            .deleteAll(db)
        }
        """
    )
    #expect(mutationProbe.status != 0)
    for expectedDiagnostic in [
        "type 'ScheduleFireRecord' has no member 'deleteAll'",
        "type 'ScheduleEvaluationCursorRecord' has no member 'updateAll'",
        "type 'ScheduleFireRecord' has no member 'filter'",
    ] {
        #expect(mutationProbe.diagnostics.contains(expectedDiagnostic))
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "agentloop-p1-schedule-fire-records-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let databasePath = directory.appendingPathComponent("fixture.sqlite").path
    let scheduledSeconds = Double(bitPattern: 0x41d954fc40000001)
    let updatedSeconds = Double(bitPattern: 0x41d954fc40000002)
    let redactedSeconds = Double(bitPattern: 0x41d954fc40000003)
    let createdSeconds = scheduledSeconds + 1

    do {
        let pool = try DatabasePool(path: databasePath)
        try AppDatabase.migrator.migrate(pool)
        try pool.write { database in
            try p1InsertScheduleFireScopeFixture(database)
            try p1InsertScheduleFireFixture(
                database,
                id: "numeric-fire",
                scheduledAt: scheduledSeconds,
                state: "started",
                missionId: "schedule-fire-mission"
            )
            try p1InsertScheduleFireFixture(
                database,
                id: "redacted-fire",
                scheduledAt: scheduledSeconds,
                state: "failed",
                errorCode: "schedule_configuration_invalid",
                redactedAt: redactedSeconds
            )
            try database.execute(
                sql: """
                    INSERT INTO schedule_evaluation_cursor (
                      scheduleId, lastEvaluatedSlotKey,
                      lastEvaluatedScheduledAt, version, updatedAt
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "schedule-fire-schedule", "slot-numeric-fire",
                    scheduledSeconds, 1, updatedSeconds,
                ]
            )
        }

        try pool.read { database in
            #expect(try String.fetchOne(
                database,
                sql: """
                    SELECT typeof(scheduledAt) FROM schedule_fire
                    WHERE id = 'numeric-fire'
                    """
            ) == "real")
            #expect(try String.fetchOne(
                database,
                sql: """
                    SELECT typeof(lastEvaluatedScheduledAt)
                    FROM schedule_evaluation_cursor
                    WHERE scheduleId = 'schedule-fire-schedule'
                    """
            ) == "real")
            let fire = try #require(try ScheduleFireRecord.fetchOne(
                database,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: ["numeric-fire"]
            ))
            let cursor = try #require(
                try ScheduleEvaluationCursorRecord.fetchOne(
                    database,
                    sql: """
                        SELECT * FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["schedule-fire-schedule"]
                )
            )
            let redacted = try #require(try ScheduleFireRecord.fetchOne(
                database,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: ["redacted-fire"]
            ))
            #expect(
                fire.scheduledAt.timeIntervalSince1970.bitPattern
                    == scheduledSeconds.bitPattern
            )
            #expect(
                fire.createdAt.timeIntervalSince1970.bitPattern
                    == createdSeconds.bitPattern
            )
            #expect(
                cursor.lastEvaluatedScheduledAt.timeIntervalSince1970.bitPattern
                    == scheduledSeconds.bitPattern
            )
            #expect(
                cursor.updatedAt.timeIntervalSince1970.bitPattern
                    == updatedSeconds.bitPattern
            )
            #expect(
                redacted.redactedAt?.timeIntervalSince1970.bitPattern
                    == redactedSeconds.bitPattern
            )
            #expect(redacted.errorMessage == nil)
        }
    }

    let reopened = try DatabasePool(path: databasePath)
    try reopened.read { database in
        let fire = try #require(try ScheduleFireRecord.fetchOne(
            database,
            sql: "SELECT * FROM schedule_fire WHERE id = ?",
            arguments: ["numeric-fire"]
        ))
        let cursor = try #require(
            try ScheduleEvaluationCursorRecord.fetchOne(
                database,
                sql: """
                    SELECT * FROM schedule_evaluation_cursor
                    WHERE scheduleId = ?
                    """,
                arguments: ["schedule-fire-schedule"]
            )
        )
        #expect(
            fire.scheduledAt.timeIntervalSince1970.bitPattern
                == scheduledSeconds.bitPattern
        )
        #expect(
            fire.createdAt.timeIntervalSince1970.bitPattern
                == createdSeconds.bitPattern
        )
        #expect(
            cursor.lastEvaluatedScheduledAt.timeIntervalSince1970.bitPattern
                == scheduledSeconds.bitPattern
        )
    }

    #expect(throws: DatabaseError.self) {
        try reopened.write { database in
            try database.execute(
                sql: "DELETE FROM mission WHERE id = 'schedule-fire-mission'"
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try reopened.write { database in
            try database.execute(
                sql: """
                    DELETE FROM schedule
                    WHERE id = 'schedule-fire-schedule'
                    """
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try reopened.write { database in
            try database.execute(
                sql: """
                    DELETE FROM mission_template
                    WHERE id = 'schedule-fire-template'
                    """
            )
        }
    }
    let retainedCounts = try reopened.read { database in
        (
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM schedule_fire
                    WHERE id IN ('numeric-fire', 'redacted-fire')
                    """
            ),
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM schedule_evaluation_cursor
                    WHERE scheduleId = 'schedule-fire-schedule'
                    """
            ),
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM mission
                    WHERE id = 'schedule-fire-mission'
                    """
            ),
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM mission_template
                    WHERE id = 'schedule-fire-template'
                    """
            )
        )
    }
    #expect(retainedCounts.0 == 2)
    #expect(retainedCounts.1 == 1)
    #expect(retainedCounts.2 == 1)
    #expect(retainedCounts.3 == 1)

    let historyDatabase = try AppDatabase(path: databasePath)
    func retainedHistoryCounts() throws -> [Int] {
        try historyDatabase.pool.read { database in
            [
                try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM schedule
                        WHERE id = 'schedule-fire-schedule'
                        """
                ) ?? 0,
                try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM mission_template
                        WHERE id = 'schedule-fire-template'
                        """
                ) ?? 0,
                try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM schedule_fire
                        WHERE id IN ('numeric-fire', 'redacted-fire')
                        """
                ) ?? 0,
                try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM schedule_evaluation_cursor
                        WHERE scheduleId = 'schedule-fire-schedule'
                        """
                ) ?? 0,
            ]
        }
    }
    let historyBeforeAPIDeletes = try retainedHistoryCounts()
    #expect(historyBeforeAPIDeletes == [1, 1, 2, 1])
    #expect(throws: DatabaseError.self) {
        try historyDatabase.deleteSchedule(id: "schedule-fire-schedule")
    }
    #expect(try retainedHistoryCounts() == historyBeforeAPIDeletes)
    #expect(throws: DatabaseError.self) {
        try historyDatabase.deleteMissionTemplate(
            id: "schedule-fire-template"
        )
    }
    #expect(try retainedHistoryCounts() == historyBeforeAPIDeletes)

    let noHistoryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "agentloop-p1-schedule-delete-no-history-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: noHistoryDirectory,
        withIntermediateDirectories: true
    )
    let noHistoryDatabase = try AppDatabase(
        path: noHistoryDirectory.appendingPathComponent("fixture.sqlite").path
    )
    try noHistoryDatabase.pool.write {
        try p1InsertScheduleFireScopeFixture($0)
    }
    try noHistoryDatabase.deleteSchedule(id: "schedule-fire-schedule")
    #expect(
        try noHistoryDatabase.schedule(id: "schedule-fire-schedule") == nil
    )
    #expect(
        try noHistoryDatabase.schedule(id: "schedule-fire-cursor-only")
            != nil
    )
    try noHistoryDatabase.deleteMissionTemplate(
        id: "schedule-fire-template"
    )
    #expect(
        try noHistoryDatabase.missionTemplate(
            id: "schedule-fire-template"
        ) == nil
    )
    #expect(
        try noHistoryDatabase.schedule(id: "schedule-fire-cursor-only")
            == nil
    )

    try reopened.write { database in
        try database.execute(
            sql: """
                UPDATE schedule_fire
                SET scheduledAt = '2026-01-01 00:00:00'
                WHERE id = 'numeric-fire'
                """
        )
        try database.execute(
            sql: """
                UPDATE schedule_evaluation_cursor
                SET lastEvaluatedScheduledAt = '2026-01-01 00:00:00'
                WHERE scheduleId = 'schedule-fire-schedule'
                """
        )
    }
    #expect(throws: RowDecodingError.self) {
        try reopened.read { database in
            _ = try ScheduleFireRecord.fetchOne(
                database,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: ["numeric-fire"]
            )
        }
    }
    try reopened.write { database in
        try database.execute(
            sql: """
                UPDATE schedule_fire
                SET scheduledAt = ?, createdAt = '2026-01-01 00:00:00'
                WHERE id = 'numeric-fire'
                """,
            arguments: [scheduledSeconds]
        )
    }
    #expect(throws: RowDecodingError.self) {
        try reopened.read { database in
            _ = try ScheduleFireRecord.fetchOne(
                database,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: ["numeric-fire"]
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try reopened.write { database in
            try database.execute(
                sql: """
                    UPDATE schedule_fire
                    SET createdAt = ?, redactedAt = '2026-01-01 00:00:00'
                    WHERE id = 'redacted-fire'
                    """,
                arguments: [createdSeconds]
            )
        }
    }
    try reopened.read { database in
        let redacted = try #require(try ScheduleFireRecord.fetchOne(
            database,
            sql: "SELECT * FROM schedule_fire WHERE id = ?",
            arguments: ["redacted-fire"]
        ))
        #expect(
            redacted.redactedAt?.timeIntervalSince1970.bitPattern
                == redactedSeconds.bitPattern
        )
    }
    #expect(throws: RowDecodingError.self) {
        try reopened.read { database in
            _ = try ScheduleEvaluationCursorRecord.fetchOne(
                database,
                sql: """
                    SELECT * FROM schedule_evaluation_cursor
                    WHERE scheduleId = ?
                    """,
                arguments: ["schedule-fire-schedule"]
            )
        }
    }
    try reopened.write { database in
        try database.execute(
            sql: """
                UPDATE schedule_evaluation_cursor
                SET lastEvaluatedScheduledAt = ?,
                    updatedAt = '2026-01-01 00:00:00'
                WHERE scheduleId = 'schedule-fire-schedule'
                """,
            arguments: [scheduledSeconds]
        )
    }
    #expect(throws: RowDecodingError.self) {
        try reopened.read { database in
            _ = try ScheduleEvaluationCursorRecord.fetchOne(
                database,
                sql: """
                    SELECT * FROM schedule_evaluation_cursor
                    WHERE scheduleId = ?
                    """,
                arguments: ["schedule-fire-schedule"]
            )
        }
    }
}

@Test func durableWorkAttemptEventIsAppendOnlyFromIntroducingMigration() throws {
    let pool = try p1TemporaryPool("append-only")
    try AppDatabase.migrator.migrate(
        pool,
        upTo: "v12-p1-durable-work"
    )
    try pool.write { try p1InsertValidAttemptEventFixture($0) }

    #expect(throws: DatabaseError.self) {
        try pool.write { database in
            try database.execute(
                sql: """
                    UPDATE durable_work_attempt_event
                    SET workerId = workerId
                    WHERE id = 'p1-event'
                    """
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write { database in
            try database.execute(
                sql: """
                    DELETE FROM durable_work_attempt_event
                    WHERE id = 'p1-event'
                    """
            )
        }
    }

    var failingMigrator = DatabaseMigrator()
    failingMigrator.registerMigration("p1-test-failure-after-guard-drop") {
        database in
        try database.execute(
            sql: "DROP TRIGGER durable_work_attempt_event_reject_update"
        )
        try database.execute(
            sql: "DROP TRIGGER durable_work_attempt_event_reject_delete"
        )
        throw P1MigrationInjectedFailure.afterGuardDrop
    }
    #expect(throws: P1MigrationInjectedFailure.afterGuardDrop) {
        try failingMigrator.migrate(pool)
    }

    try pool.read { database in
        let triggerNames = try p1SQLiteObjectNames(database, type: "trigger")
        #expect(
            triggerNames.contains(
                "durable_work_attempt_event_reject_update"
            )
        )
        #expect(
            triggerNames.contains(
                "durable_work_attempt_event_reject_delete"
            )
        )
        #expect(
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM durable_work_attempt_event
                    WHERE id = 'p1-event'
                    """
            ) == 1
        )
    }

    #expect(throws: DatabaseError.self) {
        try pool.write { database in
            try database.execute(
                sql: """
                    UPDATE durable_work_attempt_event
                    SET workerId = workerId
                    WHERE id = 'p1-event'
                    """
            )
        }
    }
    #expect(throws: DatabaseError.self) {
        try pool.write { database in
            try database.execute(
                sql: """
                    DELETE FROM durable_work_attempt_event
                    WHERE id = 'p1-event'
                    """
            )
        }
    }
}
