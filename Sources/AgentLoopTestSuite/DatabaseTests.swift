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
        try CampRecord(id: "camp", name: "c", createdAt: Date()).insert(db)
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
