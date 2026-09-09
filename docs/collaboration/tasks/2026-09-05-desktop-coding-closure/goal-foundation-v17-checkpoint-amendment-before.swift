import CryptoKit
import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

private let p1eV16Migration = "v16-p1-identity-memory"
private let p1eV15Migration = "v15-p1-outcome-contracts"
private let p1eV17Migration = "v17-p1-engine-coordination"
private let p1eEpoch = Date(timeIntervalSince1970: 1_000_000)

private enum P1EMigrationTestError: Error, CustomStringConvertible {
    case missingMigration
    case expectedFailure(String)
    case malformedAuthority(String)

    var description: String {
        switch self {
        case .missingMigration:
            return "P1-E v16 migration is missing"
        case let .expectedFailure(label):
            return "P1-E expected migration failure did not occur: \(label)"
        case let .malformedAuthority(message):
            return "P1-E authority extraction failed: \(message)"
        }
    }
}

private func p1eQueue(
    _ label: String,
    foreignKeysEnabled: Bool = true
) throws -> DatabaseQueue {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = foreignKeysEnabled
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "agentloop-p1e-\(label)-\(UUID().uuidString).sqlite"
    )
    return try DatabaseQueue(path: url.path, configuration: configuration)
}

private func p1eRequireV16() throws {
    guard AppDatabase.migrator.migrations.contains(p1eV16Migration) else {
        throw P1EMigrationTestError.missingMigration
    }
}

private func p1eMigrateToV15(_ queue: DatabaseQueue) throws {
    try AppDatabase.migrator.migrate(queue, upTo: p1eV15Migration)
}

private func p1eMigrateToV16(_ queue: DatabaseQueue) throws {
    try p1eRequireV16()
    try AppDatabase.migrator.migrate(queue, upTo: p1eV16Migration)
}

private func p1eInsertCamp(
    _ id: String,
    archived: Bool = false,
    in database: Database
) throws {
    try CampRecord(
        id: id,
        name: "P1-E \(id)",
        archived: archived,
        createdAt: p1eEpoch
    ).insert(database)
}

private func p1eInsertCompanion(
    _ id: String,
    kind: CompanionRecord.Kind = .regular,
    campID: String?,
    in database: Database
) throws {
    try CompanionRecord(
        id: id,
        name: "Cow \(id)",
        color: "#ffffff",
        rolePrompt: "role:\(id)",
        model: "test-model",
        toolsJson: "[]",
        kind: kind,
        campId: campID,
        createdAt: p1eEpoch
    ).insert(database)
}

private func p1eInsertDurableWork(
    id: String,
    campID: String,
    state: String,
    version: Int = 1,
    in database: Database
) throws {
    let isRunning = state == "running"
    let isRetry = state == "retryScheduled"
    let isTerminal = ["succeeded", "failed", "canceled"].contains(state)
    let output = state == "succeeded" ? "{}" : nil
    let errorCode: String? = {
        switch state {
        case "retryScheduled", "failed": return "test_failure"
        case "canceled": return "work_canceled"
        default: return nil
        }
    }()
    let errorMessage: String? = state == "canceled" ? "fixture canceled" : nil
    let values: [(any DatabaseValueConvertible)?] = [
        id, campID, id, id, state, isRunning ? 1 : 0,
        isRetry ? p1eEpoch.addingTimeInterval(60) : nil,
        isRunning ? "worker:\(id)" : nil,
        isRunning ? p1eEpoch.addingTimeInterval(60) : nil,
        String(repeating: "a", count: 64), output, errorCode, errorMessage,
        "trace:\(id)", version, p1eEpoch, p1eEpoch,
        isTerminal ? p1eEpoch : nil,
    ]
    try database.execute(
        sql: """
            INSERT INTO durable_work(
              id,campId,kind,aggregateType,aggregateId,idempotencyKey,state,
              attempt,maxAttempts,notBefore,leaseOwner,leaseExpiresAt,inputJson,
              inputHash,outputJson,errorCode,errorMessage,traceId,version,
              createdAt,updatedAt,finishedAt
            ) VALUES (
              ?,?,'planning','mission',?,?,?, ?,4,?,?,?,'{}',?,?,?,?,?,?,?, ?,?
            )
            """,
        arguments: StatementArguments(values)
    )
}

private func p1eInsertOpenAttempt(
    workID: String,
    in database: Database
) throws {
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt(
              workId,attempt,id,workerId,startedAt,endedAt,outcome,errorCode,
              errorMessage,traceId,terminalWorkVersion
            ) VALUES (?,1,?,?,?,NULL,NULL,NULL,NULL,?,NULL)
            """,
        arguments: [
            workID, "attempt:\(workID)", "worker:\(workID)", p1eEpoch,
            "trace:\(workID)",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt_event(
              id,workId,attempt,sequence,eventKind,workerId,workVersion,
              resultingWorkState,errorCode,errorMessage,occurredAt
            ) VALUES (?, ?,1,0,'claimed',?,1,'running',NULL,NULL,?)
            """,
        arguments: [
            "event:\(workID):claimed", workID, "worker:\(workID)", p1eEpoch,
        ]
    )
}

private func p1eQuotedIdentifier(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func p1eLogicalSnapshot(_ database: Database) throws -> [String] {
    var result = try String.fetchAll(
        database,
        sql: """
            SELECT type || char(31) || name || char(31) || tbl_name || char(31)
                   || COALESCE(sql, 'NULL')
            FROM sqlite_master
            ORDER BY type,name
            """
    ).map { "schema:\($0)" }
    let tables = try String.fetchAll(
        database,
        sql: """
            SELECT name FROM sqlite_master
            WHERE type='table' AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            """
    )
    for table in tables {
        let columns = try database.columns(in: table).map(\.name)
        let projection = columns.map {
            "quote(\(p1eQuotedIdentifier($0)))"
        }.joined(separator: " || char(31) || ")
        let tableName = p1eQuotedIdentifier(table)
        let rows = try String.fetchAll(
            database,
            sql: "SELECT \(projection) AS row_value FROM \(tableName) ORDER BY row_value"
        )
        result.append(contentsOf: rows.map { "row:\(table):\($0)" })
    }
    return result
}

private func p1eExpectV16Failure(
    _ label: String,
    queue: DatabaseQueue
) throws {
    try p1eRequireV16()
    do {
        try AppDatabase.migrator.migrate(queue, upTo: p1eV16Migration)
    } catch {
        return
    }
    throw P1EMigrationTestError.expectedFailure(label)
}

private func p1eSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func p1eStageV16SQL() throws -> String {
    let source = try p1eSource(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"
    )
    guard let heading = source.range(
        of: "### 18.6 `v16-p1-identity-memory`"
    ), let opening = source.range(
        of: "```sql\n",
        range: heading.upperBound..<source.endIndex
    ), let closing = source.range(
        of: "\n```",
        range: opening.upperBound..<source.endIndex
    ) else {
        throw P1EMigrationTestError.malformedAuthority("missing §18.6 fence")
    }
    return String(source[opening.upperBound..<closing.lowerBound])
}

private func p1eSHA256(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8)).map {
        String(format: "%02x", $0)
    }.joined()
}

private func p1eRuntimeV16LiteralFromSource() throws -> String {
    let source = try p1eSource("Sources/AgentLoopCore/Database/AppDatabase.swift")
    let openingToken = "// P1-E-BEGIN V16IdentityMemorySQL\npackage let p1EIdentityMemoryMigrationSQL = \"\"\"\n"
    let closingToken = "\n\"\"\"\n// P1-E-END V16IdentityMemorySQL"
    guard let opening = source.range(of: openingToken),
          let closing = source.range(
            of: closingToken,
            range: opening.upperBound..<source.endIndex
          )
    else {
        throw P1EMigrationTestError.malformedAuthority(
            "missing runtime v16 literal markers"
        )
    }
    return String(source[opening.upperBound..<closing.lowerBound])
}

private let p1ePersistedEventKinds: Set<String> = [
    "card_started", "card_completed", "card_blocked", "card_ready",
    "card_canceled", "card_interrupted", "mission_created",
    "mission_status_changed", "mission_accepted", "mission_failed",
    "mission_budget_exhausted", "plan_started", "plan_completed",
    "plan_noop", "plan_fallback", "planning_tokens",
    "planning_usage_overflow", "run_error", "progress_note", "kernel_error",
    "budget_added", "approval_requested", "approval_decided",
    "autonomy_changed", "camp_halted", "camp_resumed",
    "rate_limit_cooldown", "user_request_created", "user_request_answered",
    "squad_proposal_confirmed", "camp_note_created",
    "companion_note_created", "base_cow_provisioned", "ingestion_created",
    "rumination_completed", "rumination_failed", "rumination_materialized",
    "action_candidate_converted", "cow_unlocked", "mcp_server_down",
    "card_returned", "card_review_cleared", "camp_archived",
    "schedule_fired", "schedule_missed",
]

@Suite(.serialized)
struct P1ECampLifecycleMigrationTests {
    @Test func p1e01V16MigrationIsImmediateSuccessor() throws {
        let migrations = AppDatabase.migrator.migrations
        let v15 = try #require(migrations.firstIndex(of: p1eV15Migration))
        let v16 = try #require(migrations.firstIndex(of: p1eV16Migration))
        let v17 = try #require(migrations.firstIndex(of: p1eV17Migration))
        #expect(v16 == v15 + 1)
        #expect(v17 == v16 + 1)
        #expect(v17 == migrations.count - 1)
    }

    @Test func p1e02V16SchemaObjectCountsAndDDL() throws {
        let queue = try p1eQueue("schema")
        try p1eMigrateToV16(queue)
        try queue.read { database in
            let counts = (
                try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")!,
                try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='index'")!,
                try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger'")!
            )
            #expect(counts.0 == 67)
            #expect(counts.1 == 171)
            #expect(counts.2 == 67)
            let requiredTables: Set<String> = [
                "camp_lifecycle", "camp_provider_dispatch",
                "camp_deletion_job", "camp_deletion_artifact",
                "legacy_chat_scope", "legacy_companion_note_scope",
                "camp_event_scope", "cow_identity", "camp_residency",
                "camp_bridge", "memory_record_version", "memory_dependency",
            ]
            let actual = Set(try String.fetchAll(
                database,
                sql: "SELECT name FROM sqlite_master WHERE type='table'"
            ))
            #expect(requiredTables.isSubset(of: actual))
            let workColumns = try database.columns(in: "durable_work").map(\.name)
            #expect(workColumns.contains("campLifecycleVersion"))
            #expect(!workColumns.contains("campLifecycleVersion_v16"))
        }
    }

    @Test func p1e03CompanionCowResidencyBackfillReplay() throws {
        let queue = try p1eQueue("cow-backfill")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try p1eInsertCamp("camp:cow", in: database)
            try p1eInsertCompanion("cow:resident", campID: "camp:cow", in: database)
            try p1eInsertCompanion("cow:global", campID: nil, in: database)
        }
        try p1eMigrateToV16(queue)
        try p1eMigrateToV16(queue)
        try queue.read { database in
            #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM cow_identity") == 2)
            #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM camp_residency") == 1)
            let row = try #require(try Row.fetchOne(
                database,
                sql: "SELECT id,cowId,campId,status,idempotencyKey FROM camp_residency"
            ))
            #expect(row["id"] as String == "legacy-residency:cow:resident:camp:cow")
            #expect(row["cowId"] as String == "cow:resident")
            #expect(row["campId"] as String == "camp:cow")
            #expect(row["status"] as String == "active")
            #expect(row["idempotencyKey"] as String == "legacy:cow:resident:camp:cow")
        }
    }

    @Test func p1e04NilAndCorruptCampBackfillMatrix() throws {
        let nilQueue = try p1eQueue("nil-camp")
        try p1eMigrateToV15(nilQueue)
        try nilQueue.write { database in
            try p1eInsertCompanion("cow:nil", campID: nil, in: database)
        }
        try p1eMigrateToV16(nilQueue)
        #expect(try nilQueue.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM camp_residency")
        } == 0)

        let corrupt = try p1eQueue("corrupt-camp", foreignKeysEnabled: false)
        try p1eMigrateToV15(corrupt)
        try corrupt.write { database in
            try p1eInsertCompanion("cow:corrupt", campID: "camp:missing", in: database)
        }
        let before = try corrupt.read(p1eLogicalSnapshot)
        try p1eExpectV16Failure("dangling companion.campId", queue: corrupt)
        let after = try corrupt.read(p1eLogicalSnapshot)
        #expect(after == before)
    }

    @Test func p1e05ArchivedWorkClosureAndLifecycleBinding() throws {
        let queue = try p1eQueue("archived-work")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try p1eInsertCamp("camp:archived", archived: true, in: database)
            try p1eInsertCamp("camp:active", in: database)
            for state in ["queued", "running", "retryScheduled", "succeeded"] {
                try p1eInsertDurableWork(
                    id: "archived:\(state)",
                    campID: "camp:archived",
                    state: state,
                    in: database
                )
            }
            try p1eInsertOpenAttempt(workID: "archived:running", in: database)
            try p1eInsertDurableWork(
                id: "active:queued", campID: "camp:active", state: "queued",
                in: database
            )
        }
        try p1eMigrateToV16(queue)
        try queue.read { database in
            let lifecycle = try String.fetchAll(
                database,
                sql: "SELECT campId || ':' || state || ':' || version FROM camp_lifecycle ORDER BY campId"
            )
            #expect(lifecycle == ["camp:active:active:1", "camp:archived:archived:1"])
            for state in ["queued", "running", "retryScheduled"] {
                let row = try #require(try Row.fetchOne(
                    database,
                    sql: "SELECT state,campLifecycleVersion,errorCode,errorMessage,finishedAt FROM durable_work WHERE id=?",
                    arguments: ["archived:\(state)"]
                ))
                #expect(row["state"] as String == "canceled")
                #expect(row["campLifecycleVersion"] as Int == 1)
                #expect(row["errorCode"] as String == "work_canceled")
                #expect(row["errorMessage"] as String == "camp_archived_backfill")
                #expect((row["finishedAt"] as Date?) != nil)
            }
            #expect(try String.fetchOne(database, sql: "SELECT state FROM durable_work WHERE id='active:queued'") == "queued")
            #expect(try String.fetchOne(database, sql: "SELECT state FROM durable_work WHERE id='archived:succeeded'") == "succeeded")
            #expect(try String.fetchOne(database, sql: "SELECT outcome FROM durable_work_attempt WHERE workId='archived:running'") == "canceled")
            #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM durable_work_attempt_event WHERE workId='archived:running'") == 2)
        }
    }

    @Test func p1e06LegacyPoisonDiagnosticsRollback() throws {
        let sql = try p1eStageV16SQL()
        #expect(sql.components(separatedBy: "CHECK (COALESCE((").count - 1 == 3)
        let runner = try p1eSource("Sources/P1MigrationMatrixRunner/main.swift")
        let hasV12Poison = runner.contains("poisonedV12Diagnostics")
        let hasV15Poison = runner.contains("poisonedV15Diagnostics")
        let hasV16Sentinel = runner.contains(
            "diagnostics.v16.sentinels.total=7 accepted=0 check_rejected=7"
        )
        #expect(hasV12Poison)
        #expect(hasV15Poison)
        #expect(hasV16Sentinel)
    }

    @Test func p1e07DurableChildFKRebuildUsesFinalNames() throws {
        let queue = try p1eQueue("final-fks")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try p1eInsertCamp("camp:fk", in: database)
            try p1eInsertDurableWork(
                id: "work:fk", campID: "camp:fk", state: "running",
                in: database
            )
            try p1eInsertOpenAttempt(workID: "work:fk", in: database)
        }
        try p1eMigrateToV16(queue)
        try queue.read { database in
            for table in ["durable_work_attempt", "durable_work_attempt_event"] {
                let targets = try String.fetchAll(
                    database,
                    sql: "SELECT \"table\" FROM pragma_foreign_key_list(?)",
                    arguments: [table]
                )
                #expect(!targets.isEmpty)
                #expect(!targets.contains { $0.contains("_v16") || $0.contains("_legacy") || $0.contains("stage") })
            }
            let attemptTargets = try String.fetchAll(
                database,
                sql: "SELECT \"table\" FROM pragma_foreign_key_list('durable_work_attempt')"
            )
            #expect(attemptTargets.contains("durable_work"))
        }
    }

    @Test func p1e08LegacyChatNoteScopeBackfill() throws {
        let queue = try p1eQueue("legacy-content")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try p1eInsertCamp("camp:guide", in: database)
            try p1eInsertCompanion("cow:dm", campID: nil, in: database)
            try p1eInsertCompanion(
                "cow:guide", kind: .guide, campID: "camp:guide", in: database
            )
            try ChatThreadRecord(
                id: "thread:dm", kind: .dm, companionId: "cow:dm",
                campId: nil, createdAt: p1eEpoch
            ).insert(database)
            try ChatThreadRecord(
                id: "thread:guide", kind: .guide, companionId: "cow:guide",
                campId: "camp:guide", createdAt: p1eEpoch
            ).insert(database)
            try CompanionNoteRecord(
                id: "note:dm", companionId: "cow:dm",
                sourceThreadId: "thread:dm", title: "DM", bodyMd: "private",
                pinned: false, createdAt: p1eEpoch, updatedAt: p1eEpoch
            ).insert(database)
            try CompanionNoteRecord(
                id: "note:guide", companionId: "cow:guide",
                sourceThreadId: "thread:guide", title: "Guide", bodyMd: "camp",
                pinned: false, createdAt: p1eEpoch, updatedAt: p1eEpoch
            ).insert(database)
            try CompanionNoteRecord(
                id: "note:manual", companionId: "cow:dm", sourceThreadId: nil,
                title: "Manual", bodyMd: "global", pinned: false,
                createdAt: p1eEpoch, updatedAt: p1eEpoch
            ).insert(database)
        }
        try p1eMigrateToV16(queue)
        try queue.read { database in
            let chats = try String.fetchAll(
                database,
                sql: "SELECT threadId || ':' || scopeKind || ':' || evidenceKind || ':' || COALESCE(campId,'-') FROM legacy_chat_scope ORDER BY threadId"
            )
            #expect(chats == [
                "thread:dm:globalCow:dmThread:-",
                "thread:guide:camp:guideThread:camp:guide",
            ])
            let notes = try String.fetchAll(
                database,
                sql: "SELECT noteId || ':' || scopeKind || ':' || evidenceKind FROM legacy_companion_note_scope ORDER BY noteId"
            )
            #expect(notes == [
                "note:dm:globalCow:dmThread",
                "note:guide:camp:guideThread",
                "note:manual:globalCow:manualCow",
            ])
        }
    }

    @Test func p1e09LegacyEventScopeExhaustiveBackfill() throws {
        #expect(p1ePersistedEventKinds.count == 45)
        let vocabulary = try p1eSource("Sources/AgentLoopCore/Database/EventKind.swift")
        #expect(vocabulary.components(separatedBy: "public static let").count - 1 == 46)
        for kind in p1ePersistedEventKinds {
            #expect(vocabulary.contains("\"\(kind)\""), Comment(rawValue: kind))
        }
        #expect(EventKind.allPersistedKinds == p1ePersistedEventKinds)
        #expect(
            LegacyEventScopeResolverV1.resolverKeys
                == EventKind.allPersistedKinds
        )
        let resolverSource = try p1eSource(
            "Sources/AgentLoopCore/Database/LegacyEventScopeResolver.swift"
        )
        let hasDefault = resolverSource.contains("default:")
        #expect(!hasDefault)

        let queue = try p1eQueue("global-kernel-event")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try EventRecord(
                id: "event:global-kernel",
                missionId: "",
                cardId: nil,
                runId: nil,
                kind: EventKind.kernelError,
                payloadJson: "{\"message\":\"legacy startup failure\"}",
                createdAt: p1eEpoch
            ).insert(database)
        }
        try p1eMigrateToV16(queue)
        try queue.read { database in
            let scope = try #require(try Row.fetchOne(
                database,
                sql: "SELECT scopeKind,campId FROM camp_event_scope WHERE eventId=?",
                arguments: ["event:global-kernel"]
            ))
            #expect(scope["scopeKind"] as String == "global")
            #expect(scope["campId"] as String? == nil)
        }
    }

    @Test func p1e10LegacyScopeMalformedRollback() throws {
        let queue = try p1eQueue("malformed-scope")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try p1eInsertCamp("camp:scope", in: database)
            try p1eInsertCompanion(
                "cow:scope", kind: .guide, campID: "camp:scope", in: database
            )
            try ChatThreadRecord(
                id: "thread:malformed", kind: .guide, companionId: "cow:scope",
                campId: nil, createdAt: p1eEpoch
            ).insert(database)
        }
        let before = try queue.read(p1eLogicalSnapshot)
        try p1eExpectV16Failure("guide thread without camp", queue: queue)
        let after = try queue.read(p1eLogicalSnapshot)
        #expect(after == before)
    }

    @Test func p1e11V16GuardDropOrdering() throws {
        let authority = try p1eStageV16SQL()
        let runtime = try p1eRuntimeV16LiteralFromSource()
        let literalMatchesAuthority = runtime == authority
        #expect(literalMatchesAuthority)
        #expect(Data(runtime.utf8).count == 80_830)
        let lineCount = runtime.reduce(0) { count, character in
            character == "\n" ? count + 1 : count
        }
        #expect(lineCount == 1_998)
        #expect(p1eSHA256(runtime) == "3a86de973a0feff2a5a26bbd6d721464382f6cd13c667b062501808a5325fd71")

        let executableLines = runtime.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("--") }
        let fixedDrops = [
            "DROP TRIGGER event_no_update;",
            "DROP TRIGGER verification_record_reject_update;",
            "DROP TRIGGER acceptance_record_reject_update;",
            "DROP TRIGGER external_operation_receipt_reject_update;",
        ]
        let dropIndices = try fixedDrops.map { line in
            try #require(executableLines.firstIndex(of: line))
        }
        #expect(dropIndices == dropIndices.sorted())
        #expect(executableLines.filter { $0.hasPrefix("DROP TRIGGER ") }.count == 5)
        let firstTrigger = try #require(executableLines.firstIndex {
            $0.hasPrefix("CREATE TRIGGER ")
        })
        let structural = executableLines.indices.filter { index in
            let line = executableLines[index]
            return line.hasPrefix("CREATE TABLE ")
                || line.hasPrefix("CREATE INDEX ")
                || line.hasPrefix("CREATE UNIQUE INDEX ")
                || line.hasPrefix("ALTER TABLE ")
                || line.hasPrefix("DROP TABLE ")
                || line.hasPrefix("DROP TRIGGER ")
        }
        #expect(try #require(structural.max()) < firstTrigger)
        #expect(dropIndices.last! < firstTrigger)
        for line in executableLines[(dropIndices.last! + 1)..<firstTrigger] {
            #expect(!line.hasPrefix("INSERT "))
            #expect(!line.hasPrefix("UPDATE "))
            #expect(!line.hasPrefix("DELETE "))
            #expect(!line.hasPrefix("SELECT "))
        }
    }

    @Test func p1e12V16FailureBoundaryRestoresV15() throws {
        for trigger in [
            "event_no_update", "verification_record_reject_update",
            "acceptance_record_reject_update",
            "external_operation_receipt_reject_update",
        ] {
            let queue = try p1eQueue("rollback-\(trigger)")
            try p1eMigrateToV15(queue)
            try queue.write { database in
                try database.execute(sql: "DROP TRIGGER \(trigger)")
            }
            let before = try queue.read(p1eLogicalSnapshot)
            try p1eExpectV16Failure("missing \(trigger)", queue: queue)
            let after = try queue.read(p1eLogicalSnapshot)
            #expect(after == before, Comment(rawValue: trigger))
        }
    }

    @Test func p1e13V16RedactionAndAppendOnlyGuards() throws {
        let queue = try p1eQueue("guards")
        try p1eMigrateToV15(queue)
        try queue.write { database in
            try p1eInsertCamp("camp:guards", in: database)
        }
        try p1eMigrateToV16(queue)
        try queue.write { database in
            let triggers = Set(try String.fetchAll(
                database,
                sql: "SELECT name FROM sqlite_master WHERE type='trigger'"
            ))
            for required in [
                "memory_dependency_reject_update",
                "memory_dependency_reject_delete",
                "ingestion_item_first_redaction_exact",
                "rumination_result_first_redaction_exact",
                "action_candidate_first_redaction_exact",
                "knowledge_source_link_first_redaction_exact",
                "durable_work_attempt_event_reject_delete",
                "verification_record_reject_update_except_camp_redaction",
                "acceptance_record_reject_update_except_camp_redaction",
                "external_operation_receipt_reject_update_except_camp_redaction",
            ] {
                #expect(triggers.contains(required), Comment(rawValue: required))
            }
            try database.execute(
                sql: """
                    INSERT INTO memory_record_version(
                      id,version,layer,ownerType,ownerId,campId,title,bodyText,
                      contentRef,contentHash,status,sourceType,applicabilityJson,
                      createdByActorId,confirmedByActorId,createdAt,updatedAt
                    ) VALUES (
                      'memory:guard',1,'working','camp','camp:guards','camp:guards',
                      'Guard','body',NULL,?,'active','inference','{}',
                      'system:test',NULL,?,?
                    )
                    """,
                arguments: [String(repeating: "b", count: 64), p1eEpoch, p1eEpoch]
            )
            try database.execute(
                sql: """
                    INSERT INTO memory_dependency(
                      id,memoryId,memoryVersion,dependencyType,dependencyId,
                      dependencyVersion,dependencyHash,createdAt
                    ) VALUES ('dependency:guard','memory:guard',1,'input',
                      'input:guard',1,?,?)
                    """,
                arguments: [String(repeating: "c", count: 64), p1eEpoch]
            )
            #expect(throws: (any Error).self) {
                try database.execute(
                    sql: "UPDATE memory_dependency SET id=id WHERE id='dependency:guard'"
                )
            }
            #expect(throws: (any Error).self) {
                try database.execute(
                    sql: "DELETE FROM memory_dependency WHERE id='dependency:guard'"
                )
            }
        }
    }
}
