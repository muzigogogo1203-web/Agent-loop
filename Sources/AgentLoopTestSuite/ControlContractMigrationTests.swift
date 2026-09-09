import Foundation
import GRDB
import Testing
import AgentLoopCore

private enum P1CControlMigrationTestError: Error, CustomStringConvertible {
    case assertion(String)
    case expectedDatabaseFailure(String)
    case missingV14(finalMigration: String)

    var description: String {
        switch self {
        case let .assertion(message):
            return "P1-C migration assertion failed: \(message)"
        case let .expectedDatabaseFailure(label):
            return "P1-C expected database failure did not occur: \(label)"
        case let .missingV14(finalMigration):
            return "missing v14-p1-control-contracts; final migration is \(finalMigration)"
        }
    }
}

private let p1cV14Tables: Set<String> = [
    "domain_command_receipt",
    "domain_event",
    "event_outbox",
    "inbox_message",
    "input_envelope",
    "goal_controller",
    "goal_mission_link",
    "coach_session",
    "coach_question",
    "understanding_card_version",
]

private let p1cV14Indexes: Set<String> = [
    "domain_event_correlation",
    "domain_event_camp",
    "domain_event_aggregate",
    "event_outbox_pending",
    "inbox_message_camp_state",
    "input_envelope_status",
    "input_envelope_camp",
    "goal_controller_camp_status",
    "goal_mission_link_goal",
    "coach_session_goal",
    "coach_question_one_open",
    "coach_question_decision",
    "understanding_goal",
    "sqlite_autoindex_domain_command_receipt_1",
    "sqlite_autoindex_domain_event_1",
    "sqlite_autoindex_domain_event_2",
    "sqlite_autoindex_domain_event_3",
    "sqlite_autoindex_domain_event_4",
    "sqlite_autoindex_event_outbox_1",
    "sqlite_autoindex_inbox_message_1",
    "sqlite_autoindex_inbox_message_2",
    "sqlite_autoindex_input_envelope_1",
    "sqlite_autoindex_input_envelope_2",
    "sqlite_autoindex_goal_controller_1",
    "sqlite_autoindex_goal_mission_link_1",
    "sqlite_autoindex_coach_session_1",
    "sqlite_autoindex_coach_question_1",
    "sqlite_autoindex_understanding_card_version_1",
    "sqlite_autoindex_understanding_card_version_2",
]

private let p1cV14Triggers: Set<String> = [
    "domain_command_receipt_reject_update",
    "domain_command_receipt_reject_delete",
    "domain_event_reject_update",
    "domain_event_reject_delete",
]

private let p1cExpectedColumnShapes: [String: [String]] = [
    "domain_command_receipt": [
        "idempotencyKey|TEXT|1|NULL|1",
        "commandType|TEXT|1|NULL|0",
        "commandPayloadHash|TEXT|1|NULL|0",
        "eventCount|INTEGER|1|NULL|0",
        "resultJson|TEXT|1|NULL|0",
        "resultHash|TEXT|1|NULL|0",
        "createdAt|DATETIME|1|NULL|0",
    ],
    "domain_event": [
        "id|TEXT|1|NULL|1",
        "campId|TEXT|1|NULL|0",
        "aggregateType|TEXT|1|NULL|0",
        "aggregateId|TEXT|1|NULL|0",
        "aggregateVersion|INTEGER|1|NULL|0",
        "eventType|TEXT|1|NULL|0",
        "payloadVersion|INTEGER|1|NULL|0",
        "payloadJson|TEXT|1|NULL|0",
        "payloadHash|TEXT|1|NULL|0",
        "actorType|TEXT|1|NULL|0",
        "actorId|TEXT|1|NULL|0",
        "deviceId|TEXT|0|NULL|0",
        "causationId|TEXT|0|NULL|0",
        "correlationId|TEXT|1|NULL|0",
        "commandIdempotencyKey|TEXT|1|NULL|0",
        "eventOrdinal|INTEGER|1|NULL|0",
        "eventIdempotencyKey|TEXT|1|NULL|0",
        "occurredAt|DATETIME|1|NULL|0",
        "recordedAt|DATETIME|1|NULL|0",
    ],
    "event_outbox": [
        "eventId|TEXT|1|NULL|1",
        "state|TEXT|1|NULL|0",
        "attempt|INTEGER|1|0|0",
        "notBefore|DATETIME|0|NULL|0",
        "leaseOwner|TEXT|0|NULL|0",
        "leaseExpiresAt|DATETIME|0|NULL|0",
        "lastError|TEXT|0|NULL|0",
        "version|INTEGER|1|1|0",
        "createdAt|DATETIME|1|NULL|0",
        "updatedAt|DATETIME|1|NULL|0",
        "sentAt|DATETIME|0|NULL|0",
    ],
    "inbox_message": [
        "id|TEXT|1|NULL|1",
        "campId|TEXT|0|NULL|0",
        "sourceDeviceId|TEXT|1|NULL|0",
        "idempotencyKey|TEXT|1|NULL|0",
        "payloadJson|TEXT|1|NULL|0",
        "payloadHash|TEXT|1|NULL|0",
        "state|TEXT|1|NULL|0",
        "receivedAt|DATETIME|1|NULL|0",
        "appliedAt|DATETIME|0|NULL|0",
        "errorCode|TEXT|0|NULL|0",
        "version|INTEGER|1|1|0",
        "redactedAt|DATETIME|0|NULL|0",
    ],
    "input_envelope": [
        "id|TEXT|1|NULL|1",
        "schemaVersion|INTEGER|1|1|0",
        "aggregateVersion|INTEGER|1|1|0",
        "idempotencyKey|TEXT|1|NULL|0",
        "sourceType|TEXT|1|NULL|0",
        "sourceDeviceId|TEXT|0|NULL|0",
        "connectorId|TEXT|0|NULL|0",
        "authorId|TEXT|0|NULL|0",
        "capturedAt|DATETIME|1|NULL|0",
        "inlineText|TEXT|0|NULL|0",
        "payloadRef|TEXT|0|NULL|0",
        "contentHash|TEXT|1|NULL|0",
        "candidateCampIdsJson|TEXT|1|NULL|0",
        "campId|TEXT|0|NULL|0",
        "explicitIntent|TEXT|1|NULL|0",
        "privacyLevel|TEXT|1|NULL|0",
        "status|TEXT|1|NULL|0",
        "errorCode|TEXT|0|NULL|0",
        "errorMessage|TEXT|0|NULL|0",
        "parentInputId|TEXT|0|NULL|0",
        "retentionState|TEXT|1|NULL|0",
        "createdAt|DATETIME|1|NULL|0",
        "updatedAt|DATETIME|1|NULL|0",
        "deletedAt|DATETIME|0|NULL|0",
    ],
    "goal_controller": [
        "id|TEXT|1|NULL|1",
        "campId|TEXT|1|NULL|0",
        "sourceInputId|TEXT|0|NULL|0",
        "title|TEXT|1|NULL|0",
        "rawIntent|TEXT|1|NULL|0",
        "status|TEXT|1|NULL|0",
        "currentUnderstandingId|TEXT|0|NULL|0",
        "currentUnderstandingVersion|INTEGER|0|NULL|0",
        "currentOutcomeContractId|TEXT|0|NULL|0",
        "currentOutcomeContractVersion|INTEGER|0|NULL|0",
        "aggregateVersion|INTEGER|1|1|0",
        "createdByActorId|TEXT|1|NULL|0",
        "createdAt|DATETIME|1|NULL|0",
        "updatedAt|DATETIME|1|NULL|0",
    ],
    "goal_mission_link": [
        "missionId|TEXT|1|NULL|1",
        "goalId|TEXT|1|NULL|0",
        "outcomeContractId|TEXT|0|NULL|0",
        "outcomeContractVersion|INTEGER|0|NULL|0",
        "state|TEXT|1|NULL|0",
        "version|INTEGER|1|1|0",
        "createdAt|DATETIME|1|NULL|0",
        "updatedAt|DATETIME|1|NULL|0",
    ],
    "coach_session": [
        "id|TEXT|1|NULL|1",
        "goalId|TEXT|1|NULL|0",
        "inputId|TEXT|0|NULL|0",
        "actorId|TEXT|1|NULL|0",
        "status|TEXT|1|NULL|0",
        "currentUnderstandingVersion|INTEGER|0|NULL|0",
        "pendingQuestionId|TEXT|0|NULL|0",
        "traceId|TEXT|1|NULL|0",
        "aggregateVersion|INTEGER|1|1|0",
        "createdAt|DATETIME|1|NULL|0",
        "updatedAt|DATETIME|1|NULL|0",
    ],
    "coach_question": [
        "id|TEXT|1|NULL|1",
        "sessionId|TEXT|1|NULL|0",
        "decisionKey|TEXT|1|NULL|0",
        "prompt|TEXT|1|NULL|0",
        "recommendation|TEXT|1|NULL|0",
        "reason|TEXT|1|NULL|0",
        "answerJson|TEXT|0|NULL|0",
        "state|TEXT|1|NULL|0",
        "createdAt|DATETIME|1|NULL|0",
        "answeredAt|DATETIME|0|NULL|0",
    ],
    "understanding_card_version": [
        "id|TEXT|1|NULL|1",
        "version|INTEGER|1|NULL|2",
        "goalId|TEXT|1|NULL|0",
        "problem|TEXT|1|NULL|0",
        "scenario|TEXT|1|NULL|0",
        "targetAudience|TEXT|1|NULL|0",
        "goalsJson|TEXT|1|NULL|0",
        "nonGoalsJson|TEXT|1|NULL|0",
        "deliverablesJson|TEXT|1|NULL|0",
        "constraintsJson|TEXT|1|NULL|0",
        "acceptanceCriteriaJson|TEXT|1|NULL|0",
        "verificationPlanJson|TEXT|1|NULL|0",
        "resourceRefsJson|TEXT|1|NULL|0",
        "requiredCapabilitiesJson|TEXT|1|NULL|0",
        "budgetPolicyJson|TEXT|1|NULL|0",
        "assumptionsJson|TEXT|1|NULL|0",
        "acceptedRisksJson|TEXT|1|NULL|0",
        "status|TEXT|1|NULL|0",
        "contentHash|TEXT|1|NULL|0",
        "createdByActorId|TEXT|1|NULL|0",
        "confirmedByActorId|TEXT|0|NULL|0",
        "confirmedAt|DATETIME|0|NULL|0",
        "createdAt|DATETIME|1|NULL|0",
    ],
]

private let p1cExpectedForeignKeys: [String: [String]] = [
    "domain_command_receipt": [],
    "domain_event": [
        "campId|camp|id|RESTRICT",
        "commandIdempotencyKey|domain_command_receipt|idempotencyKey|RESTRICT",
    ],
    "event_outbox": ["eventId|domain_event|id|RESTRICT"],
    "inbox_message": ["campId|camp|id|RESTRICT"],
    "input_envelope": [
        "campId|camp|id|RESTRICT",
        "parentInputId|input_envelope|id|RESTRICT",
    ],
    "goal_controller": [
        "campId|camp|id|RESTRICT",
        "sourceInputId|input_envelope|id|RESTRICT",
    ],
    "goal_mission_link": [
        "goalId|goal_controller|id|RESTRICT",
        "missionId|mission|id|RESTRICT",
    ],
    "coach_session": [
        "goalId|goal_controller|id|RESTRICT",
        "inputId|input_envelope|id|RESTRICT",
    ],
    "coach_question": ["sessionId|coach_session|id|RESTRICT"],
    "understanding_card_version": ["goalId|goal_controller|id|RESTRICT"],
]

@Suite(.serialized)
struct P1CControlContractMigrationTests {
    @Test func controlContractMigrationExactDDLAndConstraints() throws {
        let migrator = AppDatabase.migrator
        try p1cRequireV14(migrator)

        let predecessor = try p1cOpenPool("exact-predecessor")
        try migrator.migrate(predecessor, upTo: "v13-p1-observability")
        let predecessorTables = try predecessor.read {
            try p1cSQLiteObjectNames($0, type: "table")
        }
        let predecessorIndexes = try predecessor.read {
            try p1cSQLiteObjectNames($0, type: "index")
        }
        let predecessorTriggers = try predecessor.read {
            try p1cSQLiteObjectNames($0, type: "trigger")
        }
        try predecessor.close()

        let pool = try p1cOpenV14Pool("exact-final")
        try pool.read { database in
            let migrationSuffix = Array(try String.fetchAll(
                database,
                sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
            ).suffix(4))
            try p1cRequire(migrationSuffix == [
                "v12-p1-durable-work",
                "v12-p1-schedule-fire",
                "v13-p1-observability",
                "v14-p1-control-contracts",
            ], "final migration suffix drifted: \(migrationSuffix)")

            let tables = try p1cSQLiteObjectNames(database, type: "table")
            let indexes = try p1cSQLiteObjectNames(database, type: "index")
            let triggers = try p1cSQLiteObjectNames(database, type: "trigger")
            try p1cRequire(
                tables == predecessorTables.union(p1cV14Tables),
                "final table name set drifted"
            )
            try p1cRequire(
                indexes == predecessorIndexes.union(p1cV14Indexes),
                "final index name set drifted"
            )
            try p1cRequire(
                triggers == predecessorTriggers.union(p1cV14Triggers),
                "final trigger name set drifted"
            )
            try p1cRequire(tables.count == 41, "final table count is not 41")
            try p1cRequire(indexes.count == 94, "final index count is not 94")
            try p1cRequire(triggers.count == 8, "final trigger count is not 8")

            for table in p1cV14Tables.sorted() {
                let actualColumns = try p1cColumnShapes(database, table: table)
                try p1cRequire(
                    actualColumns == p1cExpectedColumnShapes[table],
                    "\(table) column shape drifted: \(actualColumns)"
                )
                let actualForeignKeys = try p1cForeignKeyShapes(
                    database,
                    table: table
                )
                try p1cRequire(
                    actualForeignKeys == p1cExpectedForeignKeys[table],
                    "\(table) foreign keys drifted: \(actualForeignKeys)"
                )
            }

            try p1cRequireDDLFragments(database)
            let violations = try database.foreignKeyViolations()
            try p1cRequire(
                try violations.next() == nil,
                "foreign_key_check reported a violation"
            )
            try p1cRequire(
                try String.fetchOne(database, sql: "PRAGMA integrity_check")
                    == "ok",
                "integrity_check is not ok"
            )
        }
        try pool.close()
    }

    @Test func controlContractMigrationReplaysFromFreshAndV11Twice() throws {
        let migrator = AppDatabase.migrator
        try p1cRequireV14(migrator)

        for (label, predecessor) in [
            ("fresh", Optional<String>.none),
            ("v11", Optional("v11-cli-kinds")),
        ] {
            let pool = try p1cOpenPool("replay-\(label)")
            if let predecessor {
                try migrator.migrate(pool, upTo: predecessor)
                try pool.write { database in
                    try p1cInsertCamp(database, id: "replay-v11-camp")
                }
            }
            let oldTables = try pool.read(p1cUserTableNames)
            let oldRows = try pool.read {
                try p1cRowsSnapshot($0, tables: oldTables)
            }

            try migrator.migrate(pool, upTo: "v14-p1-control-contracts")
            let first = try pool.read(p1cStableSnapshot)
            let migratedOldRows = try pool.read {
                try p1cRowsSnapshot($0, tables: oldTables)
            }
            try p1cRequire(
                migratedOldRows == oldRows,
                "\(label) predecessor rows changed"
            )
            try migrator.migrate(pool, upTo: "v14-p1-control-contracts")
            let second = try pool.read(p1cStableSnapshot)
            try p1cRequire(second == first, "\(label) replay changed database")
            try pool.close()
        }
    }

    @Test func controlContractMigrationRollbackLeavesV13Untouched() throws {
        let migrator = AppDatabase.migrator
        try p1cRequireV14(migrator)
        let pool = try p1cOpenPool("rollback")
        try migrator.migrate(pool, upTo: "v13-p1-observability")
        try pool.write { database in
            try p1cInsertCamp(database, id: "rollback-camp")
            try database.execute(
                sql: "CREATE INDEX domain_event_correlation ON camp(id)"
            )
        }
        let before = try pool.read(p1cStableSnapshot)

        var failed = false
        do {
            try migrator.migrate(pool, upTo: "v14-p1-control-contracts")
        } catch {
            failed = true
        }
        try p1cRequire(failed, "conflicting v14 index did not fail migration")
        let after = try pool.read(p1cStableSnapshot)
        try p1cRequire(after == before, "failed v14 changed v13 snapshot")

        try pool.read { database in
            for table in p1cV14Tables {
                try p1cRequire(
                    try !database.tableExists(table),
                    "failed v14 left table \(table)"
                )
            }
            let migrationCount = try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v14-p1-control-contracts'
                    """
            ) ?? -1
            try p1cRequire(migrationCount == 0, "failed v14 was recorded")
            let sentinelSQL = try String.fetchOne(
                database,
                sql: """
                    SELECT sql FROM sqlite_master
                    WHERE type = 'index' AND name = 'domain_event_correlation'
                    """
            )
            try p1cRequire(
                sentinelSQL == "CREATE INDEX domain_event_correlation ON camp(id)",
                "rollback sentinel changed"
            )
        }
        try pool.close()
    }

    @Test func controlContractAppendOnlyTablesRejectNoopUpdateAndDelete() throws {
        let pool = try p1cOpenV14Pool("append-only")
        try pool.write { database in
            try p1cInsertCamp(database, id: "append-camp")
            try p1cInsertReceipt(database, key: "append-command")
            try p1cInsertEvent(
                database,
                id: "append-event",
                campID: "append-camp",
                commandKey: "append-command"
            )

            try p1cExpectDatabaseFailure("receipt no-op update") {
                try database.execute(sql: """
                    UPDATE domain_command_receipt
                    SET commandType = commandType
                    WHERE idempotencyKey = 'append-command'
                    """)
            }
            try p1cExpectDatabaseFailure("receipt delete") {
                try database.execute(sql: """
                    DELETE FROM domain_command_receipt
                    WHERE idempotencyKey = 'append-command'
                    """)
            }
            try p1cExpectDatabaseFailure("event no-op update") {
                try database.execute(sql: """
                    UPDATE domain_event SET eventType = eventType
                    WHERE id = 'append-event'
                    """)
            }
            try p1cExpectDatabaseFailure("event delete") {
                try database.execute(
                    sql: "DELETE FROM domain_event WHERE id = 'append-event'"
                )
            }
            try p1cRequire(
                try Int.fetchOne(
                    database,
                    sql: "SELECT COUNT(*) FROM domain_command_receipt"
                ) == 1,
                "receipt row did not survive trigger checks"
            )
            try p1cRequire(
                try Int.fetchOne(
                    database,
                    sql: "SELECT COUNT(*) FROM domain_event"
                ) == 1,
                "event row did not survive trigger checks"
            )
        }
        try pool.close()
    }

    @Test func controlContractSchemaHasExactInboxRedactionShape() throws {
        let pool = try p1cOpenV14Pool("inbox-redaction")
        try pool.read { database in
            try p1cRequire(
                try database.columns(in: "inbox_message").map(\.name) == [
                    "id", "campId", "sourceDeviceId", "idempotencyKey",
                    "payloadJson", "payloadHash", "state", "receivedAt",
                    "appliedAt", "errorCode", "version", "redactedAt",
                ],
                "inbox columns drifted"
            )
            let ddl = try p1cRequiredDDL(database, table: "inbox_message")
            try p1cRequire(
                p1cNormalizeSQL(ddl).contains(p1cNormalizeSQL("""
                    redactedAt IS NULL OR (campId IS NOT NULL
                    AND sourceDeviceId = '[deleted]'
                    AND payloadJson = '{}'
                    AND state = 'rejected'
                    AND errorCode = 'camp_deleted')
                    """)),
                "inbox redaction CHECK drifted"
            )
        }

        try pool.write { database in
            try p1cInsertCamp(database, id: "inbox-camp")
            try p1cInsertInbox(
                database,
                id: "valid-redacted",
                campID: "inbox-camp",
                sourceDeviceID: "[deleted]",
                payloadJSON: "{}",
                state: "rejected",
                errorCode: "camp_deleted",
                redactedAt: 1_700_000_010
            )
            try p1cInsertInbox(
                database,
                id: "valid-global",
                campID: nil,
                sourceDeviceID: "device-local",
                payloadJSON: #"{"value":1}"#,
                state: "received",
                errorCode: nil,
                redactedAt: nil
            )
            for invalid in [
                ("null-camp", nil, "[deleted]", "{}", "rejected", "camp_deleted"),
                ("device", "inbox-camp", "device", "{}", "rejected", "camp_deleted"),
                ("payload", "inbox-camp", "[deleted]", #"{"x":1}"#, "rejected", "camp_deleted"),
                ("state", "inbox-camp", "[deleted]", "{}", "received", "camp_deleted"),
                ("code", "inbox-camp", "[deleted]", "{}", "rejected", "other"),
            ] {
                try p1cExpectDatabaseFailure("invalid inbox \(invalid.0)") {
                    try p1cInsertInbox(
                        database,
                        id: "invalid-\(invalid.0)",
                        campID: invalid.1,
                        sourceDeviceID: invalid.2,
                        payloadJSON: invalid.3,
                        state: invalid.4,
                        errorCode: invalid.5,
                        redactedAt: 1_700_000_020
                    )
                }
            }
        }
        try pool.close()
    }

    @Test func inputSchemaHasNoParseAttemptColumn() throws {
        let pool = try p1cOpenV14Pool("input-no-attempt")
        try pool.read { database in
            let names = try database.columns(in: "input_envelope").map(\.name)
            let expectedNames = p1cExpectedColumnShapes["input_envelope"]?
                .map { $0.split(separator: "|").first.map(String.init) ?? "" }
                ?? []
            try p1cRequire(names == expectedNames,
                "input columns drifted"
            )
            try p1cRequire(
                !names.contains("parseAttempt") && !names.contains("attempt"),
                "input schema contains parse attempt state"
            )
            let ddl = try p1cRequiredDDL(database, table: "input_envelope")
            try p1cRequire(
                !ddl.lowercased().contains("parseattempt"),
                "input DDL contains parseAttempt"
            )
        }
        try pool.close()
    }

    @Test func inputSchemaRejectsDeletedStatusWithActiveRetention() throws {
        let pool = try p1cOpenV14Pool("deleted-active")
        try pool.write { database in
            try p1cInsertCamp(database, id: "input-camp")
            try p1cExpectDatabaseFailure("deleted status with active retention") {
                try p1cInsertInput(
                    database,
                    id: "deleted-active",
                    campID: "input-camp",
                    inlineText: "body",
                    payloadRef: nil,
                    status: "deletedTombstone",
                    retentionState: "active",
                    deletedAt: nil
                )
            }
        }
        try pool.close()
    }

    @Test func activeInputRequiresExactlyOneInlineOrPayloadRef() throws {
        let pool = try p1cOpenV14Pool("input-body-xor")
        try pool.write { database in
            try p1cInsertCamp(database, id: "input-camp")
            try p1cInsertInput(
                database,
                id: "valid-inline",
                campID: "input-camp",
                inlineText: "body",
                payloadRef: nil,
                status: "captured",
                retentionState: "active",
                deletedAt: nil
            )
            try p1cInsertInput(
                database,
                id: "valid-payload",
                campID: "input-camp",
                inlineText: nil,
                payloadRef: "payload:v1:local",
                status: "captured",
                retentionState: "deletionRequested",
                deletedAt: nil
            )
            try p1cExpectDatabaseFailure("active input missing both bodies") {
                try p1cInsertInput(
                    database,
                    id: "invalid-neither",
                    campID: "input-camp",
                    inlineText: nil,
                    payloadRef: nil,
                    status: "captured",
                    retentionState: "active",
                    deletedAt: nil
                )
            }
            try p1cExpectDatabaseFailure("active input has both bodies") {
                try p1cInsertInput(
                    database,
                    id: "invalid-both",
                    campID: "input-camp",
                    inlineText: "body",
                    payloadRef: "payload:v1:local",
                    status: "captured",
                    retentionState: "active",
                    deletedAt: nil
                )
            }
        }
        try pool.close()
    }

    @Test func inputSchemaRejectsTombstoneRetentionWithLiveStatus() throws {
        let pool = try p1cOpenV14Pool("tombstone-live")
        try pool.write { database in
            try p1cInsertCamp(database, id: "input-camp")
            try p1cExpectDatabaseFailure("tombstone retention with live status") {
                try p1cInsertInput(
                    database,
                    id: "tombstone-live",
                    campID: "input-camp",
                    inlineText: nil,
                    payloadRef: nil,
                    status: "captured",
                    retentionState: "deletedTombstone",
                    deletedAt: 1_700_000_100
                )
            }
        }
        try pool.close()
    }
}

private func p1cRequireV14(_ migrator: DatabaseMigrator) throws {
    guard let v14 = migrator.migrations.firstIndex(
        of: "v14-p1-control-contracts"
    ) else {
        throw P1CControlMigrationTestError.missingV14(
            finalMigration: migrator.migrations.last ?? "<none>"
        )
    }
    guard let v13 = migrator.migrations.firstIndex(
        of: "v13-p1-observability"
    ), v14 == v13 + 1
    else {
        throw P1CControlMigrationTestError.assertion(
            "v14 is not the immediate successor of v13"
        )
    }
}

private func p1cRequire(
    _ condition: @autoclosure () throws -> Bool,
    _ message: String
) throws {
    guard try condition() else {
        throw P1CControlMigrationTestError.assertion(message)
    }
}

private func p1cExpectDatabaseFailure(
    _ label: String,
    _ operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch is DatabaseError {
        return
    }
    throw P1CControlMigrationTestError.expectedDatabaseFailure(label)
}

private func p1cOpenPool(_ label: String) throws -> DatabasePool {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agentloop-p1c-\(label)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    return try DatabasePool(
        path: directory.appendingPathComponent("fixture.sqlite").path,
        configuration: configuration
    )
}

private func p1cOpenV14Pool(_ label: String) throws -> DatabasePool {
    let migrator = AppDatabase.migrator
    try p1cRequireV14(migrator)
    let pool = try p1cOpenPool(label)
    try migrator.migrate(pool, upTo: "v14-p1-control-contracts")
    return pool
}

private func p1cSQLiteObjectNames(
    _ database: Database,
    type: String
) throws -> Set<String> {
    Set(try String.fetchAll(
        database,
        sql: """
            SELECT name FROM sqlite_master
            WHERE type = ?
            ORDER BY name
            """,
        arguments: [type]
    ))
}

private func p1cColumnShapes(
    _ database: Database,
    table: String
) throws -> [String] {
    try Row.fetchAll(
        database,
        sql: "PRAGMA table_info(\(p1cQuotedIdentifier(table)))"
    ).map { row in
        let name: String = row["name"]
        let type: String = row["type"]
        let notNull: Int = row["notnull"]
        let defaultValue: String? = row["dflt_value"]
        let primaryKey: Int = row["pk"]
        return "\(name)|\(type)|\(notNull)|\(defaultValue ?? "NULL")|\(primaryKey)"
    }
}

private func p1cForeignKeyShapes(
    _ database: Database,
    table: String
) throws -> [String] {
    try Row.fetchAll(
        database,
        sql: "PRAGMA foreign_key_list(\(p1cQuotedIdentifier(table)))"
    ).map { row in
        let from: String = row["from"]
        let referencedTable: String = row["table"]
        let to: String = row["to"]
        let onDelete: String = row["on_delete"]
        return "\(from)|\(referencedTable)|\(to)|\(onDelete)"
    }.sorted()
}

private func p1cRequiredDDL(
    _ database: Database,
    table: String
) throws -> String {
    guard let ddl = try String.fetchOne(
        database,
        sql: """
            SELECT sql FROM sqlite_master
            WHERE type = 'table' AND name = ?
            """,
        arguments: [table]
    ) else {
        throw P1CControlMigrationTestError.assertion("missing DDL for \(table)")
    }
    return ddl
}

private func p1cNormalizeSQL(_ sql: String) -> String {
    sql.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func p1cRequireDDLFragments(_ database: Database) throws {
    let fragments: [String: [String]] = [
        "domain_command_receipt": [
            "length(commandPayloadHash) = 64",
            "eventCount >= 0",
            "length(resultHash) = 64",
        ],
        "domain_event": [
            "aggregateVersion >= 1",
            "payloadVersion >= 1",
            "actorType IN ('user','system','coach','cow','engine','device')",
            "eventOrdinal >= 0",
            "UNIQUE(aggregateType, aggregateId, aggregateVersion)",
            "UNIQUE(commandIdempotencyKey, eventOrdinal)",
        ],
        "event_outbox": [
            "state IN ('pending','dispatching','sent','failed')",
            "state = 'dispatching' AND leaseOwner IS NOT NULL",
            "state <> 'dispatching' AND leaseOwner IS NULL",
            "state = 'sent' AND sentAt IS NOT NULL",
        ],
        "inbox_message": [
            "state IN ('received','applied','rejected')",
            "campId IS NOT NULL AND sourceDeviceId = '[deleted]'",
            "payloadJson = '{}' AND state = 'rejected'",
            "errorCode = 'camp_deleted'",
        ],
        "input_envelope": [
            "schemaVersion = 1",
            "status IN ('captured','parseFailed','campAssignmentRequired'",
            "retentionState IN ('active','deletionRequested','deletedTombstone')",
            "status = 'deletedTombstone' AND retentionState = 'deletedTombstone'",
            "sourceDeviceId IS NULL AND connectorId IS NULL",
            "candidateCampIdsJson = '[]'",
            "((inlineText IS NOT NULL) <> (payloadRef IS NOT NULL))",
        ],
        "goal_controller": [
            "status IN ('clarifying','ready','active','paused','achieved'",
            "currentUnderstandingId IS NULL AND currentUnderstandingVersion IS NULL",
            "currentOutcomeContractId IS NULL AND currentOutcomeContractVersion IS NULL",
        ],
        "goal_mission_link": [
            "state IN ('active','detached')",
            "outcomeContractId IS NULL AND outcomeContractVersion IS NULL",
        ],
        "coach_session": [
            "actorId = 'system:coach:v1'",
            "status IN ('interviewing','waitingForUser','readyForConfirmation'",
        ],
        "coach_question": [
            "state IN ('open','answered','withdrawn')",
        ],
        "understanding_card_version": [
            "status IN ('draft','awaitingConfirmation','confirmed','superseded','withdrawn')",
            "status IN ('confirmed','superseded') AND confirmedByActorId IS NOT NULL",
            "status NOT IN ('confirmed','superseded') AND confirmedByActorId IS NULL",
        ],
    ]
    for table in p1cV14Tables.sorted() {
        let normalized = p1cNormalizeSQL(try p1cRequiredDDL(database, table: table))
        for fragment in fragments[table] ?? [] {
            try p1cRequire(
                normalized.contains(p1cNormalizeSQL(fragment)),
                "\(table) DDL missing \(fragment)"
            )
        }
    }

    for trigger in p1cV14Triggers {
        let ddl = try String.fetchOne(
            database,
            sql: "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = ?",
            arguments: [trigger]
        )
        try p1cRequire(
            ddl?.contains("is append-only") == true,
            "trigger \(trigger) is missing append-only failure"
        )
    }
}

private func p1cUserTableNames(_ database: Database) throws -> [String] {
    try String.fetchAll(
        database,
        sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table'
              AND name NOT LIKE 'sqlite_%'
              AND name <> 'grdb_migrations'
            ORDER BY name
            """
    )
}

private func p1cRowsSnapshot(
    _ database: Database,
    tables: [String]
) throws -> String {
    var result: [String] = []
    for table in tables.sorted() {
        let columns = try database.columns(in: table).map(\.name)
        let quoted = columns.map(p1cQuotedIdentifier)
        let projection = quoted
            .map { "quote(\($0))" }
            .joined(separator: " || char(31) || ")
        let order = quoted.joined(separator: ", ")
        let rows = try String.fetchAll(
            database,
            sql: """
                SELECT \(projection)
                FROM \(p1cQuotedIdentifier(table))
                ORDER BY \(order)
                """
        )
        result.append("TABLE \(table)")
        result.append(contentsOf: rows)
    }
    return result.joined(separator: "\n")
}

private func p1cStableSnapshot(_ database: Database) throws -> String {
    var result = try String.fetchAll(
        database,
        sql: """
            SELECT quote(type) || char(31) || quote(name) || char(31)
                   || quote(tbl_name) || char(31)
                   || COALESCE(quote(sql), 'NULL')
            FROM sqlite_master
            ORDER BY type, name, tbl_name
            """
    )
    let tables = try String.fetchAll(
        database,
        sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
    )
    result.append(try p1cRowsSnapshot(database, tables: tables))
    return result.joined(separator: "\n")
}

private func p1cQuotedIdentifier(_ identifier: String) -> String {
    "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func p1cInsertCamp(_ database: Database, id: String) throws {
    try database.execute(
        sql: """
            INSERT INTO camp (id, name, archived, createdAt)
            VALUES (?, ?, 0, ?)
            """,
        arguments: [id, "Camp \(id)", 1_700_000_000.0]
    )
}

private func p1cInsertReceipt(_ database: Database, key: String) throws {
    try database.execute(
        sql: """
            INSERT INTO domain_command_receipt (
              idempotencyKey, commandType, commandPayloadHash, eventCount,
              resultJson, resultHash, createdAt
            ) VALUES (?, 'input.capture.v1', ?, 1, '{}', ?, ?)
            """,
        arguments: [
            key,
            String(repeating: "a", count: 64),
            String(repeating: "b", count: 64),
            1_700_000_001.0,
        ]
    )
}

private func p1cInsertEvent(
    _ database: Database,
    id: String,
    campID: String,
    commandKey: String
) throws {
    try database.execute(
        sql: """
            INSERT INTO domain_event (
              id, campId, aggregateType, aggregateId, aggregateVersion,
              eventType, payloadVersion, payloadJson, payloadHash,
              actorType, actorId, deviceId, causationId, correlationId,
              commandIdempotencyKey, eventOrdinal, eventIdempotencyKey,
              occurredAt, recordedAt
            ) VALUES (
              ?, ?, 'input', 'input-aggregate', 1, 'input.captured.v1',
              1, '{}', ?, 'user', 'user:local-owner', NULL, NULL,
              'trace-append', ?, 0, 'append-event-key', ?, ?
            )
            """,
        arguments: [
            id,
            campID,
            String(repeating: "c", count: 64),
            commandKey,
            1_700_000_001.0,
            1_700_000_002.0,
        ]
    )
}

private func p1cInsertInbox(
    _ database: Database,
    id: String,
    campID: String?,
    sourceDeviceID: String,
    payloadJSON: String,
    state: String,
    errorCode: String?,
    redactedAt: Double?
) throws {
    try database.execute(
        sql: """
            INSERT INTO inbox_message (
              id, campId, sourceDeviceId, idempotencyKey,
              payloadJson, payloadHash, state, receivedAt,
              appliedAt, errorCode, version, redactedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, 1, ?)
            """,
        arguments: [
            id,
            campID,
            sourceDeviceID,
            "inbox-key-\(id)",
            payloadJSON,
            String(repeating: "d", count: 64),
            state,
            1_700_000_005.0,
            errorCode,
            redactedAt,
        ]
    )
}

private func p1cInsertInput(
    _ database: Database,
    id: String,
    campID: String,
    inlineText: String?,
    payloadRef: String?,
    status: String,
    retentionState: String,
    deletedAt: Double?
) throws {
    let updatedAt = deletedAt ?? 1_700_000_101.0
    try database.execute(
        sql: """
            INSERT INTO input_envelope (
              id, idempotencyKey, sourceType, sourceDeviceId, connectorId,
              authorId, capturedAt, inlineText, payloadRef, contentHash,
              candidateCampIdsJson, campId, explicitIntent, privacyLevel,
              status, errorCode, errorMessage, parentInputId, retentionState,
              createdAt, updatedAt, deletedAt
            ) VALUES (
              ?, ?, 'text', NULL, NULL, NULL, ?, ?, ?, ?, '[]', ?,
              'unspecified', 'localOnly', ?, NULL, NULL, NULL, ?, ?, ?, ?
            )
            """,
        arguments: [
            id,
            "input-key-\(id)",
            1_700_000_100.0,
            inlineText,
            payloadRef,
            String(repeating: "e", count: 64),
            campID,
            status,
            retentionState,
            1_700_000_100.0,
            updatedAt,
            deletedAt,
        ]
    )
}
