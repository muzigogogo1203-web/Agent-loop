import Foundation
import GRDB
import Testing
import AgentLoopCore

private enum P1BMigrationContractError: Error, CustomStringConvertible {
    case missingV13(finalMigration: String)
    case assertion(String)
    case expectedDatabaseFailure(String)

    var description: String {
        switch self {
        case let .missingV13(finalMigration):
            return "missing required migration v13-p1-observability; actual final migration is \(finalMigration)"
        case let .assertion(message):
            return "P1-B migration assertion failed: \(message)"
        case let .expectedDatabaseFailure(label):
            return "P1-B expected database failure did not occur: \(label)"
        }
    }
}

private struct P1BForeignKeyShape: Equatable, Comparable {
    let from: String
    let table: String
    let to: String
    let onDelete: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.from < rhs.from
    }
}

@Test func observabilityMigrationExactDDLAndConstraints() throws {
    let migrator = AppDatabase.migrator
    try p1bRequireV13Migration(migrator)

    let predecessors: [(label: String, migration: String?)] = [
        ("fresh", nil),
        ("v7", "v7"),
        ("v8-coding-ranch", "v8-coding-ranch"),
        ("v9-evercamp", "v9-evercamp"),
        ("v10-runtime-profiles", "v10-runtime-profiles"),
        ("v11-cli-kinds", "v11-cli-kinds"),
        ("v12-durable", "v12-p1-durable-work"),
        ("v12-schedule", "v12-p1-schedule-fire"),
    ]

    for predecessor in predecessors {
        let databaseURL = try p1bTemporaryDatabaseURL(
            "observability-\(predecessor.label)"
        )
        let pool = try p1bOpenPool(at: databaseURL)
        if let migration = predecessor.migration {
            try migrator.migrate(pool, upTo: migration)
        }
        if predecessor.label == "v12-schedule" {
            try pool.write {
                try p1bInsertV12SchedulePredecessor(
                    $0,
                    prefix: "v12_schedule_seed"
                )
            }
        }

        let predecessorState = try pool.read { database in
            let tables = try p1bUserTableNames(database)
            try p1bRequireV13ObjectsAbsent(database)
            return (
                tables,
                try p1bStableRowsSnapshot(database, tables: tables)
            )
        }

        try migrator.migrate(pool, upTo: "v13-p1-observability")
        try pool.read { database in
            let migratedPredecessorRows = try p1bStableRowsSnapshot(
                database,
                tables: predecessorState.0
            )
            try p1bRequire(
                migratedPredecessorRows == predecessorState.1,
                "\(predecessor.label) predecessor rows changed"
            )
        }
        try p1bValidateObservabilitySchema(
            in: pool,
            scope: predecessor.label
        )
        try p1bValidateObservabilityContract(
            in: pool,
            scope: predecessor.label
        )

        let firstFinalSnapshot = try pool.read(p1bStableSnapshot)
        try migrator.migrate(pool, upTo: "v13-p1-observability")
        let replayedFinalSnapshot = try pool.read(p1bStableSnapshot)
        try p1bRequire(
            replayedFinalSnapshot == firstFinalSnapshot,
            "\(predecessor.label) second v13 migration changed schema or data"
        )
        try pool.close()
    }
}

@Test func observabilityMigrationRollbackLeavesV12ScheduleUntouched() throws {
    let migrator = AppDatabase.migrator
    try p1bRequireV13Migration(migrator)

    let databaseURL = try p1bTemporaryDatabaseURL(
        "observability-real-rollback"
    )
    let predecessorPool = try p1bOpenPool(at: databaseURL)
    try migrator.migrate(
        predecessorPool,
        upTo: "v12-p1-schedule-fire"
    )
    try predecessorPool.write {
        try p1bInsertV12SchedulePredecessor(
            $0,
            prefix: "rollback_seed"
        )
    }
    try predecessorPool.close()

    let rollbackPool = try p1bOpenPool(at: databaseURL)
    try rollbackPool.write { database in
        try database.execute(
            sql: "CREATE INDEX context_degradation_mission ON mission(id)"
        )
    }
    let before = try rollbackPool.read(p1bStableSnapshot)

    var migrationFailed = false
    do {
        try migrator.migrate(
            rollbackPool,
            upTo: "v13-p1-observability"
        )
    } catch {
        migrationFailed = true
    }
    try p1bRequire(
        migrationFailed,
        "conflicting v13 sentinel index did not fail the real migration"
    )

    let after = try rollbackPool.read(p1bStableSnapshot)
    try p1bRequire(
        after == before,
        "failed v13 migration changed the v12-schedule logical snapshot"
    )
    try rollbackPool.read { database in
        try p1bRequire(
            try !database.tableExists("failure_record"),
            "failed v13 migration left failure_record"
        )
        try p1bRequire(
            try !database.tableExists("context_degradation"),
            "failed v13 migration left context_degradation"
        )
        let v13MigrationCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM grdb_migrations
                WHERE identifier = 'v13-p1-observability'
                """
        ) ?? -1
        try p1bRequire(
            v13MigrationCount == 0,
            "failed v13 migration recorded its migration identifier"
        )
        let retainedIndexSQL = try String.fetchOne(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'index'
                  AND name = 'context_degradation_mission'
                """
        )
        try p1bRequire(
            retainedIndexSQL ==
                "CREATE INDEX context_degradation_mission ON mission(id)",
            "rollback sentinel index changed"
        )
        let absentV13Indexes = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM sqlite_master
                WHERE type = 'index'
                  AND name IN (
                    'failure_record_open_scope',
                    'context_degradation_card'
                  )
                """
        ) ?? -1
        try p1bRequire(
            absentV13Indexes == 0,
            "failed v13 migration left a non-sentinel v13 index"
        )
        try p1bRequire(
            try p1bIndexColumns(
                database,
                index: "context_degradation_mission"
            ) == ["id"],
            "rollback sentinel no longer points to mission(id)"
        )
        try p1bRequireHealthy(database, scope: "real-v13-rollback")
    }
    try rollbackPool.close()
}

@Test func failureRecordInsertUsesTraceAsPrimaryKey() throws {
    let database = try p1bFailureDatabase("trace-primary-key")
    let sink = P1BRecordingFailureLogSink()
    let reporter = FailureReporter(writer: database, logSink: sink)
    let trace = try p1bOperationTrace(
        id: "trace-primary-key",
        operation: .missionDetailLoad,
        scope: .fixed(.database)
    )

    let visible = reporter.capture(
        RecordNotFoundError(table: "mission", id: "secret-record-id"),
        trace: trace
    )
    let stored = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "trace-primary-key"
    )

    try p1bRequire(stored.id == trace.traceId, "trace is not the primary key")
    try p1bRequire(stored.operation == trace.operation, "operation changed")
    try p1bRequire(stored.scope == trace.scope, "scope changed")
    try p1bRequire(stored.errorCode == .recordNotFound, "wrong stable code")
    try p1bRequire(stored.state == .open, "new record is not open")
    try p1bRequire(stored.occurrenceCount == 1, "new count is not one")
    try p1bRequire(stored.firstSeenAt == stored.lastSeenAt, "first/last differ")
    try p1bRequire(stored.resolvedAt == nil, "new record is resolved")
    try p1bRequire(stored.redactedAt == nil, "new record is redacted")
    try p1bRequire(visible.traceId == trace.traceId, "visible trace changed")
    try p1bRequire(visible.message == stored.userMessage, "UI/DB message split")
    try p1bRequire(
        sink.entries == [
            FailureLogEntry(
                traceId: trace.traceId,
                operation: trace.operation,
                scope: trace.scope,
                errorCode: .recordNotFound,
                persistence: .stored
            )
        ],
        "stored capture did not emit one matching safe log"
    )
}

@Test func failureRecordSameIdentityUpsertIncrementsOccurrence() throws {
    let database = try p1bFailureDatabase("same-identity")
    let sink = P1BRecordingFailureLogSink()
    let reporter = FailureReporter(writer: database, logSink: sink)
    let trace = try p1bOperationTrace(
        id: "same-identity",
        operation: .missionDetailLoad,
        scope: .fixed(.database)
    )
    let error = RecordNotFoundError(table: "mission", id: "not-persisted")

    _ = reporter.capture(error, trace: trace)
    let first = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "same-identity first"
    )
    _ = reporter.capture(error, trace: trace)
    let second = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "same-identity second"
    )

    try p1bRequire(second.id == first.id, "upsert changed trace identity")
    try p1bRequire(second.firstSeenAt == first.firstSeenAt, "firstSeen changed")
    try p1bRequire(second.lastSeenAt >= first.lastSeenAt, "lastSeen regressed")
    try p1bRequire(second.occurrenceCount == 2, "count did not increment")
    try p1bRequire(second.state == .open, "upsert did not remain open")
    try p1bRequire(sink.entries.count == 2, "capture did not log twice")
    try p1bRequire(
        sink.entries.allSatisfy { $0.persistence == .stored },
        "same-identity upsert became unavailable"
    )
}

@Test func failureRecordTraceConflictDoesNotOverwrite() throws {
    let database = try p1bFailureDatabase("trace-conflict")
    let sink = P1BRecordingFailureLogSink()
    let reporter = FailureReporter(writer: database, logSink: sink)
    let firstTrace = try p1bOperationTrace(
        id: "trace-conflict",
        operation: .missionDetailLoad,
        scope: .fixed(.database)
    )
    let conflictingTrace = try p1bOperationTrace(
        id: firstTrace.traceId,
        operation: .missionStart,
        scope: .fixed(.database)
    )

    _ = reporter.capture(
        RecordNotFoundError(table: "mission", id: "hidden"),
        trace: firstTrace
    )
    let before = try p1bRequiredFailureRecord(
        database.failureRecord(id: firstTrace.traceId),
        label: "trace-conflict before"
    )
    let conflictingVisible = reporter.capture(
        CancellationError(),
        trace: conflictingTrace
    )
    let after = try p1bRequiredFailureRecord(
        database.failureRecord(id: firstTrace.traceId),
        label: "trace-conflict after"
    )

    try p1bRequire(after == before, "trace conflict overwrote stored evidence")
    try p1bRequire(
        conflictingVisible.operation == .missionStart,
        "current operation lost its safe terminal"
    )
    try p1bRequire(
        sink.entries.map(\.persistence) == [
            .stored,
            .unavailable(reason: .failureRecordWriteFailed),
        ],
        "trace conflict did not fail closed as persistence-unavailable"
    )
}

@Test func failureRecordResolveReopenAndOverflowAreChecked() throws {
    let database = try p1bFailureDatabase("resolve-reopen")
    let sink = P1BRecordingFailureLogSink()
    let reporter = FailureReporter(writer: database, logSink: sink)
    let trace = try p1bOperationTrace(
        id: "resolve-reopen",
        operation: .missionDetailLoad,
        scope: .fixed(.database)
    )
    let source = RecordNotFoundError(table: "mission", id: "hidden")

    _ = reporter.capture(source, trace: trace)
    let resolvedAt = Date(timeIntervalSince1970: 1_725_000_000)
    let resolved = try database.resolveFailureRecord(
        id: trace.traceId,
        resolvedAt: resolvedAt
    )
    try p1bRequire(resolved.state == .resolved, "resolve did not set state")
    try p1bRequire(resolved.resolvedAt == resolvedAt, "resolve time changed")
    let resolvedAgain = try database.resolveFailureRecord(
        id: trace.traceId,
        resolvedAt: resolvedAt.addingTimeInterval(50)
    )
    try p1bRequire(resolvedAgain == resolved, "resolved row was not idempotent")

    _ = reporter.capture(source, trace: trace)
    let reopened = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "reopened"
    )
    try p1bRequire(reopened.state == .open, "capture did not reopen")
    try p1bRequire(reopened.resolvedAt == nil, "reopen retained resolvedAt")
    try p1bRequire(reopened.occurrenceCount == 2, "reopen count is wrong")

    try database.pool.write { db in
        try db.execute(
            sql: "UPDATE failure_record SET occurrenceCount = ? WHERE id = ?",
            arguments: [Int64.max, trace.traceId]
        )
    }
    let overflowBefore = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "overflow before"
    )
    _ = reporter.capture(source, trace: trace)
    let overflowAfter = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "overflow after"
    )
    try p1bRequire(
        overflowAfter == overflowBefore,
        "occurrence overflow changed the stored row"
    )
    try p1bRequire(
        sink.entries.last?.persistence ==
            .unavailable(reason: .failureRecordWriteFailed),
        "occurrence overflow did not remain visible"
    )

    #expect(throws: RecordNotFoundError.self) {
        _ = try database.resolveFailureRecord(
            id: "absent-trace",
            resolvedAt: resolvedAt
        )
    }

    let camp = CampRecord(
        id: "redacted-camp",
        name: "Redaction",
        createdAt: resolvedAt
    )
    try database.pool.write { db in
        try camp.insert(db)
    }
    let campID = try FailureRecordID.camp(camp)
    let campNoteID = try FailureRecordID.campNote(
        CampNoteRecord(
            id: "redacted-note",
            campId: camp.id,
            missionId: nil,
            title: "not persisted",
            bodyMd: "not persisted",
            pinned: false,
            createdAt: resolvedAt,
            updatedAt: resolvedAt
        )
    )
    let redactedTrace = try p1bOperationTrace(
        id: "redacted-trace",
        operation: .campNoteSave,
        scope: try .camp(
            campId: campID,
            recordId: campNoteID,
            as: .campNote
        )
    )
    _ = reporter.capture(P1BSecretBearingError(raw: "erase-me"), trace: redactedTrace)
    let beforeRejectedRedaction = try p1bRequiredFailureRecord(
        database.failureRecord(id: redactedTrace.traceId),
        label: "before rejected redaction"
    )
    #expect(throws: DatabaseError.self) {
        try database.pool.write { db in
            try db.execute(
                sql: """
                    UPDATE failure_record
                    SET userMessage = '[deleted]', diagnosticJson = '{}',
                        redactedAt = ?
                    WHERE id = ?
                    """,
                arguments: [resolvedAt, redactedTrace.traceId]
            )
        }
    }
    let afterRejectedRedaction = try p1bRequiredFailureRecord(
        database.failureRecord(id: redactedTrace.traceId),
        label: "after rejected redaction"
    )
    try p1bRequire(
        afterRejectedRedaction == beforeRejectedRedaction,
        "ordinary redaction bypassed the v16 deletion-phase fence"
    )
}

@Test func failureReporterScrubsSecretsAndRawExternalResponses() throws {
    let database = try p1bFailureDatabase("scrub")
    let sink = P1BRecordingFailureLogSink()
    let reporter = FailureReporter(writer: database, logSink: sink)
    let trace = try p1bOperationTrace(
        id: "scrub-trace",
        operation: .runtimeProviderResolve,
        scope: .fixed(.runtime)
    )
    let canaries = [
        "sk-secret-account",
        "/Users/private/workspace",
        "oauth-callback?code=raw",
        "provider-response-body",
        "stderr-private-token",
        "P1BSecretBearingError",
        "组合e\u{301}",
        "多标量👨‍👩‍👧‍👦",
    ]
    let raw = canaries.joined(separator: "|")

    let visible = reporter.capture(P1BSecretBearingError(raw: raw), trace: trace)
    let stored = try p1bRequiredFailureRecord(
        database.failureRecord(id: trace.traceId),
        label: "scrubbed record"
    )
    let renderedEvidence = [
        visible.message,
        stored.userMessage,
        stored.diagnosticJson,
        String(describing: sink.entries),
    ].joined(separator: "\n")
    for canary in canaries {
        try p1bRequire(
            !renderedEvidence.contains(canary),
            "raw canary escaped: \(canary)"
        )
    }
    try p1bRequire(stored.errorCode == .unexpectedFailure, "wrong unknown code")
    try p1bRequire(
        stored.diagnosticJson ==
            "{\"category\":\"unknown\",\"domain\":\"unknown\",\"retryable\":false}",
        "unknown diagnostics contain an unapproved field"
    )
    for operation in FailureOperation.allCases {
        try p1bRequire(!operation.rawValue.isEmpty, "empty operation raw")
        try p1bRequire(
            operation.rawValue.utf8.count <= 64,
            "operation raw exceeds 64 bytes"
        )
        try p1bRequire(
            !operation.accessibilityLabel.isEmpty,
            "operation accessibility label is empty"
        )
    }
    try p1bRequire(
        Set(FailureCode.allCases.map(\.rawValue)).count ==
            FailureCode.allCases.count,
        "failure code raw values are not unique"
    )
    try p1bRequire(
        Set(FailureScopeType.allCases.map(\.rawValue)).count ==
            FailureScopeType.allCases.count,
        "scope type raw values are not unique"
    )
}

@Test func failureReporterDatabaseUnwritableLogsAndReturnsSameTrace() throws {
    let writer = P1BThrowingFailureWriter()
    let sink = P1BRecordingFailureLogSink()
    let reporter = FailureReporter(writer: writer, logSink: sink)
    let trace = try p1bOperationTrace(
        id: "unwritable-trace",
        operation: .missionStart,
        scope: .fixed(.database)
    )

    let visible = reporter.capture(P1BSecretBearingError(raw: "db-secret"), trace: trace)
    try p1bRequire(writer.callCount == 1, "unwritable writer retried")
    try p1bRequire(visible.traceId == trace.traceId, "trace changed on outage")
    try p1bRequire(visible.operation == trace.operation, "operation changed on outage")
    try p1bRequire(visible.scope == trace.scope, "scope changed on outage")
    try p1bRequire(sink.entries.count == 1, "outage log count is not one")
    try p1bRequire(
        sink.entries[0].persistence ==
            .unavailable(reason: .failureRecordWriteFailed),
        "outage log did not record unavailable persistence"
    )

    let bootstrapSink = P1BRecordingFailureLogSink()
    let bootstrapFactory = OperationTraceFactory(
        makeID: {
            UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
        },
        now: { Date(timeIntervalSince1970: 1_725_000_008) }
    )
    let boundary = ApplicationBootstrapFailureBoundary(
        traceFactory: bootstrapFactory,
        logSink: bootstrapSink
    )
    let expected: [(ApplicationBootstrapStage, String, FailureCode)] = [
        (.previewUserDefaults, "应用预览偏好存储不可用。", .unexpectedFailure),
        (.stateDirectory, "应用状态目录不可用。", .unexpectedFailure),
        (.databaseOpen, "应用数据库无法打开。", .databaseReadFailed),
    ]
    for item in expected {
        let bootstrapTrace = boundary.makeTrace()
        let failure = boundary.capture(stage: item.0, trace: bootstrapTrace)
        try p1bRequire(
            failure.message ==
                "操作失败：\(item.1)\n追踪 ID：\(bootstrapTrace.traceId)",
            "bootstrap safe message changed for \(item.0)"
        )
        try p1bRequire(
            bootstrapSink.entries.last?.errorCode == item.2,
            "bootstrap safe code changed for \(item.0)"
        )
        try p1bRequire(
            bootstrapSink.entries.last?.persistence ==
                .unavailable(reason: .failureRecordWriteFailed),
            "bootstrap persistence was not unavailable"
        )
    }
    try p1bRequire(bootstrapSink.entries.count == 3, "bootstrap log count changed")
}

@Test func userVisibleFailureContainsExactFullTrace() throws {
    let database = try p1bFailureDatabase("full-trace")
    let reporter = FailureReporter(database: database)
    let fullTrace = String(repeating: "a", count: 128)
    let trace = try p1bOperationTrace(
        id: fullTrace,
        operation: .projectionApply,
        scope: .fixed(.projection)
    )
    let raw = String(repeating: "x", count: 1_001)
        + "e\u{301}👨‍👩‍👧‍👦"
    let visible = reporter.capture(P1BSecretBearingError(raw: raw), trace: trace)
    let expected = "操作失败：发生未预期的错误。\n追踪 ID：\(fullTrace)"

    try p1bRequire(visible.message == expected, "full safe formatter changed")
    try p1bRequire(
        visible.message.unicodeScalars.count <= 1_000,
        "visible message exceeds SQLite scalar budget"
    )
    try p1bRequire(
        visible.message.components(separatedBy: fullTrace).count == 2,
        "full trace is missing or duplicated"
    )
    try p1bRequire(!visible.message.contains(raw), "raw long body escaped")
    let wrapped = UserVisibleOperationError(failure: visible)
    try p1bRequire(wrapped.errorDescription == visible.message, "LocalizedError split")
    try p1bRequire(
        "\(visible.operation.accessibilityLabel)。\(visible.message)" ==
            "界面状态更新。\(expected)",
        "accessibility terminal label changed"
    )
}

@Test func operationTraceGeneratesAndAdoptsSafeDurableIdentity() throws {
    let generatedID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000010"
    )!
    let now = Date(timeIntervalSince1970: 1_725_000_010)
    let factory = OperationTraceFactory(
        makeID: { generatedID },
        now: { now }
    )
    let generated = factory.generated(
        operation: .applicationBootstrap,
        scope: .fixed(.application)
    )
    try p1bRequire(generated.traceId == generatedID.uuidString, "UUID changed")
    try p1bRequire(generated.startedAt == now, "generated start time changed")
    try p1bRequire(generated.scope.type == .application, "fixed type changed")
    try p1bRequire(generated.scope.id == "application", "fixed ID changed")

    let adopted = try factory.adopting(
        "trace._:-09",
        operation: .missionStart,
        scope: .fixed(.missionIndex)
    )
    try p1bRequire(adopted.traceId == "trace._:-09", "adopted ID normalized")
    try p1bRequire(adopted.startedAt == now, "adopted start time changed")

    for invalid in [
        "",
        "contains space",
        "e\u{301}",
        "👨‍👩‍👧‍👦",
        String(repeating: "a", count: 129),
    ] {
        #expect(throws: FailureMetadataValidationError.self) {
            _ = try factory.adopting(
                invalid,
                operation: .missionStart,
                scope: .fixed(.missionIndex)
            )
        }
    }

    let camp = CampRecord(
        id: "camp-coordinate",
        name: "Coordinate",
        createdAt: now
    )
    let mission = MissionRecord(
        id: "mission-coordinate",
        squadId: "squad-coordinate",
        goalRaw: "g",
        goalRefined: "g",
        status: .planning,
        budgetTokens: 1,
        spentTokens: 0,
        revision: 1,
        createdAt: now
    )
    let campID = try FailureRecordID.camp(camp)
    let missionID = try FailureRecordID.mission(mission)
    let campScope = try FailureTraceScope.camp(
        campId: campID,
        recordId: missionID,
        as: .mission
    )
    let scoped = factory.generated(operation: .missionStart, scope: campScope)
    try p1bRequire(scoped.scope.campId == camp.id, "Camp provenance changed")
    try p1bRequire(scoped.scope.id == mission.id, "Mission provenance changed")
    #expect(throws: FailureMetadataValidationError.self) {
        _ = try FailureTraceScope.camp(
            campId: missionID,
            recordId: campID,
            as: .mission
        )
    }
}

@Test func requiredKnowledgeFailureAtomicallyBlocksAndRecordsDegradation()
throws {
    let fixture = try p1bContextFixture("required-atomic-success")
    let request = try fixture.request()
    guard let scope = request.campScope else {
        throw P1BMigrationContractError.assertion("missing Camp scope")
    }
    let trace = try p1bOperationTrace(
        id: "required-context-trace",
        operation: .contextCampNotes,
        scope: scope
    )
    let reporter = FailureReporter(database: fixture.database)
    let prepared = reporter.prepare(
        ContextDependencyLoadError.knowledgeRead(
            dependencyType: .campNote,
            grdbResultCode: nil
        ),
        trace: trace
    )
    let degradation = try ContextDegradationRecord(
        id: "required-context-degradation",
        missionId: fixture.mission.id,
        cardId: fixture.card.id,
        dependencyType: .campNote,
        dependencyId: fixture.camp.id,
        policy: .required,
        traceId: trace.traceId,
        detail: prepared.visible.message,
        createdAt: Date(timeIntervalSince1970: 1_725_000_011),
        redactedAt: nil
    )
    try fixture.database.persistContextFailure(
        prepared,
        degradation: degradation,
        cardId: fixture.card.id,
        disposition: .block
    )
    try p1bRequire(
        try fixture.database.card(id: fixture.card.id)?.status == .blocked,
        "required context did not block Card"
    )
    try p1bRequire(
        try fixture.database.failureRecord(id: trace.traceId) != nil,
        "required context failure was not recorded"
    )
    try p1bRequire(
        try fixture.database.contextDegradations(
            missionId: fixture.mission.id,
            cardId: fixture.card.id
        ).map(\.id) == [degradation.id],
        "required degradation was not recorded exactly once"
    )

    let rollback = try p1bContextFixture("required-atomic-rollback")
    let rollbackRequest = try rollback.request()
    guard let rollbackScope = rollbackRequest.campScope else {
        throw P1BMigrationContractError.assertion("missing rollback scope")
    }
    let rollbackTrace = try p1bOperationTrace(
        id: "required-context-rollback-trace",
        operation: .contextCampNotes,
        scope: rollbackScope
    )
    let rollbackPrepared = FailureReporter(database: rollback.database)
        .prepare(
            ContextDependencyLoadError.knowledgeRead(
                dependencyType: .campNote,
                grdbResultCode: nil
            ),
            trace: rollbackTrace
        )
    let rollbackDegradation = try ContextDegradationRecord(
        id: "required-context-rollback-degradation",
        missionId: rollback.mission.id,
        cardId: rollback.card.id,
        dependencyType: .campNote,
        dependencyId: rollback.camp.id,
        policy: .required,
        traceId: rollbackTrace.traceId,
        detail: rollbackPrepared.visible.message,
        createdAt: Date(timeIntervalSince1970: 1_725_000_012),
        redactedAt: nil
    )
    try rollback.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER p1b_required_context_abort
            BEFORE INSERT ON context_degradation
            BEGIN
              SELECT RAISE(ABORT, 'required context abort');
            END
            """)
    }
    var didThrow = false
    do {
        try rollback.database.persistContextFailure(
            rollbackPrepared,
            degradation: rollbackDegradation,
            cardId: rollback.card.id,
            disposition: .block
        )
    } catch {
        didThrow = true
    }
    try p1bRequire(didThrow, "required context abort did not throw")
    try p1bRequire(
        try rollback.database.card(id: rollback.card.id)?.status == .ready,
        "required context rollback left Card blocked"
    )
    try p1bRequire(
        try rollback.database.failureRecord(id: rollbackTrace.traceId) == nil,
        "required context rollback left failure row"
    )
    try p1bRequire(
        try rollback.database.contextDegradations(
            missionId: rollback.mission.id,
            cardId: rollback.card.id
        ).isEmpty,
        "required context rollback left degradation"
    )
}

@Test func optionalKnowledgeFailureRecordsBeforeContinuingWithMarker()
async throws {
    let fixture = try p1bContextFixture("optional-success")
    let ledger = P1BEventLedger()
    let loader = ContextDependencyLoader(
        database: fixture.database,
        manager: nil,
        reporter: FailureReporter(database: fixture.database),
        searchCredential: { nil },
        knowledge: ContextKnowledgeReaders(
            camp: { _ in
                ledger.append("camp-read")
                throw P1BSecretBearingError(raw: "camp-read-canary")
            },
            companion: { _ in
                ledger.append("companion-read")
                return [NoteSnippet(title: "companion", body: "retained")]
            }
        ),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
    let result = await loader.load(try fixture.request()) { notice in
        ledger.append("degradation-event")
        #expect(notice.policy == .optionalApproved)
    }
    guard case .ready(let ready) = result else {
        Issue.record("optional context failure must continue after commit")
        return
    }
    #expect(ready.campNotes.count == 1)
    #expect(ready.campNotes[0].title == "上下文降级")
    #expect(ready.campNotes[0].body.contains("追踪 ID："))
    #expect(ready.companionNotes == [
        NoteSnippet(title: "companion", body: "retained"),
    ])
    #expect(ready.degradations.count == 1)
    #expect(ledger.snapshot == [
        "camp-read",
        "degradation-event",
        "companion-read",
    ])
    #expect(try fixture.database.card(id: fixture.card.id)?.status == .ready)
    let records = try fixture.database.contextDegradations(
        missionId: fixture.mission.id,
        cardId: fixture.card.id
    )
    #expect(records.count == 1)
    #expect(records[0].dependencyType == .campNote)
    #expect(records[0].policy == .optionalApproved)
    #expect(try fixture.database.failureRecord(id: records[0].traceId)?
        .errorCode == .knowledgeReadFailed)
}

@Test func optionalDegradationPersistenceFailureDoesNotContinue()
async throws {
    let fixture = try p1bContextFixture("optional-rollback")
    try await fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER p1b_optional_context_abort
            BEFORE INSERT ON context_degradation
            BEGIN
              SELECT RAISE(ABORT, 'optional context abort');
            END
            """)
    }
    let ledger = P1BEventLedger()
    let loader = ContextDependencyLoader(
        database: fixture.database,
        manager: nil,
        reporter: FailureReporter(database: fixture.database),
        searchCredential: { nil },
        knowledge: ContextKnowledgeReaders(
            camp: { _ in
                ledger.append("camp-read")
                throw P1BSecretBearingError(raw: "optional-read-canary")
            },
            companion: { _ in
                ledger.append("companion-read")
                return []
            }
        ),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
    let result = await loader.load(try fixture.request()) { _ in
        ledger.append("degradation-event")
    }
    let fallbackFailure: UserVisibleFailure
    switch result {
    case .ready:
        Issue.record("rolled-back optional degradation must not continue")
        return
    case .blocked(let failure, let suppressForSession):
        fallbackFailure = failure
        #expect(suppressForSession)
    }
    #expect(ledger.snapshot == ["camp-read"])
    #expect(try fixture.database.card(id: fixture.card.id)?.status == .ready)
    #expect(try fixture.database.contextDegradations(
        missionId: fixture.mission.id,
        cardId: fixture.card.id
    ).isEmpty)
    #expect(try fixture.database.failureRecord(id: fallbackFailure.traceId)?
        .errorCode == .knowledgeReadFailed)
    let failureCount = try await fixture.database.pool.read { database in
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM failure_record"
        ) ?? -1
    }
    #expect(failureCount == 1)

    let suppression = try p1bContextFixture("optional-suppression")
    let dispatchWorkspace = try attachP1F1DispatchContext(
        db: suppression.database,
        missionId: suppression.mission.id,
        companionId: suppression.companion.id
    )
    defer { try? FileManager.default.removeItem(at: dispatchWorkspace) }
    let suppressTrace = try p1bOperationTrace(
        id: "context-suppression-trace",
        operation: .contextCampNotes,
        scope: .fixed(.database)
    )
    let suppressFailure = FailureReporter(database: suppression.database)
        .capture(
            ContextDependencyLoadError.knowledgeRead(
                dependencyType: .campNote,
                grdbResultCode: nil
            ),
            trace: suppressTrace
        )
    let firstLoader = P1BFixedContextLoader(failure: suppressFailure)
    let provider = MockProvider(script: [])
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "optional-degradation-state-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: stateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: stateRoot) }
    let artifactRoot = stateRoot.appendingPathComponent(
        "artifacts",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: artifactRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    do {
        let first = Orchestrator(
            db: suppression.database,
            planningProviderResolver: TestPlanningProviderResolver(
                provider: provider
            ),
            makeProvider: { _, _ in provider },
            artifactStoreRoot: artifactRoot,
            tickInterval: nil,
            requiresStartupRecovery: false,
            legacyRuminationSnapshot: .legacyProfileUnresolved,
            contextDependencyLoader: firstLoader
        )
        await first.recoverAndReconcile()
        try await first.waitUntilIdle()
        #expect(firstLoader.callCount == 1)
        await first.reconcile()
        try await first.waitUntilIdle()
        #expect(firstLoader.callCount == 1)
        try await suppression.database.pool.write { database in
            try AppDatabase.appendEvent(
                database,
                missionId: suppression.mission.id,
                cardId: suppression.card.id,
                runId: nil,
                kind: EventKind.cardReady,
                payload: .object([:])
            )
        }
        try await first.retryContext(cardId: suppression.card.id)
        try await first.waitUntilIdle()
        #expect(firstLoader.callCount == 2)
        _ = await first.shutdown()
    }

    // A process restart releases the process-owned state-directory lock.
    // This in-process successor uses a fresh runtime root while keeping the
    // same database, which is the durable suppression boundary under test.
    let secondStateRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "optional-degradation-restart-state-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(
        at: secondStateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: secondStateRoot) }
    let secondArtifactRoot = secondStateRoot.appendingPathComponent(
        "artifacts",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: secondArtifactRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )

    let secondLoader = P1BFixedContextLoader(failure: suppressFailure)
    let second = Orchestrator(
        db: suppression.database,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: provider
        ),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: secondArtifactRoot,
        tickInterval: nil,
        requiresStartupRecovery: false,
        legacyRuminationSnapshot: .legacyProfileUnresolved,
        contextDependencyLoader: secondLoader
    )
    await second.recoverAndReconcile()
    try await second.waitUntilIdle()
    #expect(secondLoader.callCount == 1)
    _ = await second.shutdown()
}

@Test func malformedRequiredMcpSelectionBlocksCard() async throws {
    let fixture = try p1bContextFixture("required-mcp-registry")
    let selected = "mcp__github__list issues"
    let toolsJson = ToolAccess.explicitJson(allow: [selected])
    let searchReads = LockedBox(0)
    let noteReads = LockedBox(0)
    let loader = ContextDependencyLoader(
        database: fixture.database,
        manager: nil,
        reporter: FailureReporter(database: fixture.database),
        searchCredential: {
            searchReads.set(searchReads.get() + 1)
            return nil
        },
        knowledge: ContextKnowledgeReaders(
            camp: { _ in
                noteReads.set(noteReads.get() + 1)
                return []
            },
            companion: { _ in
                noteReads.set(noteReads.get() + 1)
                return []
            }
        ),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
    let result = await loader.load(
        try fixture.request(toolsJson: toolsJson)
    ) { _ in
        Issue.record("required MCP failure emitted optional degradation")
    }
    let failure: UserVisibleFailure
    switch result {
    case .ready:
        Issue.record("malformed required MCP selection must block")
        return
    case .blocked(let blocked, let suppressForSession):
        failure = blocked
        #expect(!suppressForSession)
    }
    #expect(searchReads.get() == 0)
    #expect(noteReads.get() == 0)
    #expect(try fixture.database.card(id: fixture.card.id)?.status == .blocked)
    #expect(try fixture.database.failureRecord(id: failure.traceId)?.errorCode
        == .projectionDecodeFailed)
    let degradations = try fixture.database.contextDegradations(
        missionId: fixture.mission.id,
        cardId: fixture.card.id
    )
    #expect(degradations.count == 1)
    #expect(degradations[0].dependencyType == .mcpServer)
    #expect(degradations[0].dependencyId == "mcpRegistry")
    #expect(degradations[0].policy == .required)
}

@Test func mcpSecretAbsentAndReadFailureHaveDifferentCodes() throws {
    let database = try p1bFailureDatabase("mcp-secret-codes")
    let reporter = FailureReporter(database: database)
    let missingTrace = try p1bOperationTrace(
        id: "mcp-secret-missing-trace",
        operation: .contextMcpServer,
        scope: .fixed(.mcpRegistry)
    )
    let readTrace = try p1bOperationTrace(
        id: "mcp-secret-read-trace",
        operation: .contextMcpServer,
        scope: .fixed(.mcpRegistry)
    )
    _ = reporter.capture(
        McpOperationError.secretMissing(serverId: "server-canary"),
        trace: missingTrace
    )
    _ = reporter.capture(
        McpOperationError.secretRead(
            serverId: "server-canary",
            osStatus: -25_293
        ),
        trace: readTrace
    )
    let missing = try p1bRequiredFailureRecord(
        database.failureRecord(id: missingTrace.traceId),
        label: "MCP secret missing"
    )
    let read = try p1bRequiredFailureRecord(
        database.failureRecord(id: readTrace.traceId),
        label: "MCP secret read"
    )
    try p1bRequire(
        missing.errorCode == .mcpSecretMissing,
        "missing secret code changed"
    )
    try p1bRequire(
        read.errorCode == .mcpSecretReadFailed,
        "secret read code changed"
    )
    try p1bRequire(
        !missing.diagnosticJson.contains("osStatus"),
        "missing secret invented OSStatus"
    )
    try p1bRequire(
        read.diagnosticJson.contains("\"osStatus\":-25293"),
        "secret read lost OSStatus"
    )
    try p1bRequire(
        !missing.userMessage.contains("server-canary")
            && !read.userMessage.contains("server-canary"),
        "server identifier escaped into user message"
    )
}

@Test func mcpConnectAndToolListFailuresHaveDifferentCodes() throws {
    let database = try p1bFailureDatabase("mcp-connect-list-codes")
    let reporter = FailureReporter(database: database)
    let startTrace = try p1bOperationTrace(
        id: "mcp-start-trace",
        operation: .contextMcpServer,
        scope: .fixed(.mcpRegistry)
    )
    let listTrace = try p1bOperationTrace(
        id: "mcp-list-trace",
        operation: .contextMcpTool,
        scope: .fixed(.mcpRegistry)
    )
    _ = reporter.capture(
        McpOperationError.transportStart(serverId: "server-canary"),
        trace: startTrace
    )
    _ = reporter.capture(
        McpOperationError.toolList(serverId: "server-canary"),
        trace: listTrace
    )
    let start = try p1bRequiredFailureRecord(
        database.failureRecord(id: startTrace.traceId),
        label: "MCP start"
    )
    let list = try p1bRequiredFailureRecord(
        database.failureRecord(id: listTrace.traceId),
        label: "MCP tool list"
    )
    try p1bRequire(start.errorCode == .mcpStartFailed, "start code changed")
    try p1bRequire(
        list.errorCode == .mcpToolListFailed,
        "tool list code changed"
    )
    try p1bRequire(
        start.errorCode != list.errorCode,
        "start and list failures collapsed"
    )
    try p1bRequire(
        !start.userMessage.contains("server-canary")
            && !list.userMessage.contains("server-canary"),
        "server identifier escaped into user message"
    )
}

@Test func contextDegradationKernelEventOccursOnlyAfterCommit()
async throws {
    let fixture = try p1bContextFixture("event-order")
    let ledger = P1BEventLedger()
    let loader = ContextDependencyLoader(
        database: fixture.database,
        manager: nil,
        reporter: FailureReporter(database: fixture.database),
        searchCredential: { nil },
        knowledge: ContextKnowledgeReaders(
            camp: { _ in
                ledger.append("read")
                throw P1BSecretBearingError(raw: "event-order-canary")
            },
            companion: { _ in
                ledger.append("companion")
                return []
            }
        ),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
    let result = await loader.load(try fixture.request()) { notice in
        do {
            let committed = try fixture.database.contextDegradations(
                missionId: fixture.mission.id,
                cardId: fixture.card.id
            )
            #expect(committed.map(\.id) == [notice.degradationId])
            #expect(try fixture.database.failureRecord(
                id: notice.failure.traceId
            ) != nil)
            ledger.append("event-after-commit")
        } catch {
            Issue.record("post-commit event could not observe durable row")
        }
    }
    guard case .ready = result else {
        Issue.record("committed optional degradation did not return ready")
        return
    }
    ledger.append("ready-return")
    #expect(ledger.snapshot == [
        "read",
        "event-after-commit",
        "companion",
        "ready-return",
    ])
}

@Test func invalidProjectionCasesAreTraceableAndNeverDefault() throws {
    let database = try p1bFailureDatabase("invalid-projection")
    let reporter = FailureReporter(database: database)
    let projectionCases: [(ProjectionContractError, FailureCode)] = [
        (.invalidPayload, .projectionDecodeFailed),
        (.generationOverflow, .projectionContractFailed),
        (.invalidTerminal, .projectionContractFailed),
        (.alreadyCompleted, .projectionContractFailed),
    ]
    for (index, item) in projectionCases.enumerated() {
        let trace = try p1bOperationTrace(
            id: "invalid-projection-\(index)",
            operation: .projectionApply,
            scope: .fixed(.projection)
        )
        let visible = reporter.capture(item.0, trace: trace)
        let record = try p1bRequiredFailureRecord(
            database.failureRecord(id: trace.traceId),
            label: "projection case \(index)"
        )
        try p1bRequire(record.errorCode == item.1, "projection code defaulted")
        try p1bRequire(
            visible.traceId == trace.traceId,
            "projection trace changed"
        )
        try p1bRequire(
            record.errorCode != .unexpectedFailure,
            "projection case became unexpected failure"
        )
    }

    let fixture = try p1bContextFixture("invalid-request")
    var mismatchedCard = fixture.card
    mismatchedCard.missionId = "different-mission"
    #expect(throws: FailureMetadataValidationError.self) {
        _ = try ContextDependencyRequest(
            mission: fixture.mission,
            card: mismatchedCard,
            camp: fixture.camp,
            companion: fixture.companion,
            runtimeProfileKind: .openAIAPI,
            toolAccess: ToolAccess.parse(toolsJson: "[]"),
            toolsJson: "[]"
        )
    }
    var mismatchedCompanion = fixture.companion
    mismatchedCompanion.campId = "different-camp"
    #expect(throws: FailureMetadataValidationError.self) {
        _ = try ContextDependencyRequest(
            mission: fixture.mission,
            card: fixture.card,
            camp: fixture.camp,
            companion: mismatchedCompanion,
            runtimeProfileKind: .openAIAPI,
            toolAccess: ToolAccess.parse(toolsJson: "[]"),
            toolsJson: "[]"
        )
    }
    let failureCount = try database.pool.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM failure_record") ?? -1
    }
    try p1bRequire(
        failureCount == projectionCases.count,
        "invalid request performed failure I/O"
    )
}

private struct P1BContextFixture {
    let database: AppDatabase
    let camp: CampRecord
    let companion: CompanionRecord
    let mission: MissionRecord
    let card: CardRecord

    func request(
        toolsJson: String = "[]",
        runtimeProfileKind: RuntimeProfileKind = .openAIAPI
    ) throws -> ContextDependencyRequest {
        try ContextDependencyRequest(
            mission: mission,
            card: card,
            camp: camp,
            companion: companion,
            runtimeProfileKind: runtimeProfileKind,
            toolAccess: ToolAccess.parse(toolsJson: toolsJson),
            toolsJson: toolsJson
        )
    }
}

private func p1bContextFixture(_ label: String) throws -> P1BContextFixture {
    let database = try p1bFailureDatabase("context-\(label)")
    let camp = try database.createCamp(name: "Context \(label)")
    let companion = CompanionRecord.new(
        name: "Context companion",
        color: "blue",
        rolePrompt: "Execute",
        model: "model",
        campId: camp.id
    )
    try database.saveCompanion(companion)
    let ids = try database.createSingleCardMission(
        campName: camp.name,
        squadName: "Context squad",
        goal: "Context goal",
        cardTitle: "Context card",
        cardDescription: "Context description",
        expectedOutput: "Context output",
        assigneeId: companion.id,
        maxTurns: 5,
        campId: camp.id
    )
    guard let mission = try database.mission(id: ids.missionId),
          let card = try database.card(id: ids.cardId)
    else {
        throw P1BMigrationContractError.assertion(
            "missing context fixture records"
        )
    }
    return P1BContextFixture(
        database: database,
        camp: camp,
        companion: companion,
        mission: mission,
        card: card
    )
}

private final class P1BEventLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.withLock { values.append(value) }
    }

    var snapshot: [String] {
        lock.withLock { values }
    }
}

private final class P1BFixedContextLoader:
    ContextDependencyLoading, @unchecked Sendable
{
    private let lock = NSLock()
    private var count = 0
    private let failure: UserVisibleFailure

    init(failure: UserVisibleFailure) {
        self.failure = failure
    }

    var callCount: Int {
        lock.withLock { count }
    }

    package func load(
        _ request: ContextDependencyRequest,
        onOptionalDegradation: @escaping @Sendable
            (ContextDegradationNotice) async -> Void
    ) async -> ContextDependencyResult {
        lock.withLock { count += 1 }
        return .blocked(failure: failure, suppressForSession: true)
    }
}

private struct P1BSecretBearingError: LocalizedError, Sendable {
    let raw: String
    var errorDescription: String? { raw }
}

private final class P1BRecordingFailureLogSink:
    FailureLogSink, @unchecked Sendable
{
    private let lock = NSLock()
    private var storage: [FailureLogEntry] = []

    var entries: [FailureLogEntry] {
        lock.withLock { storage }
    }

    func write(_ entry: FailureLogEntry) {
        lock.withLock { storage.append(entry) }
    }
}

private final class P1BThrowingFailureWriter:
    FailureRecordWriting, @unchecked Sendable
{
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int {
        lock.withLock { calls }
    }

    func persistFailureRecord(_ record: FailureRecord) throws {
        lock.withLock { calls += 1 }
        throw P1BSecretBearingError(raw: "secondary-write-secret")
    }
}

private func p1bFailureDatabase(_ label: String) throws -> AppDatabase {
    try AppDatabase(path: p1bTemporaryDatabaseURL(label).path)
}

private func p1bOperationTrace(
    id: String,
    operation: FailureOperation,
    scope: FailureTraceScope,
    now: Date = Date(timeIntervalSince1970: 1_725_000_000)
) throws -> OperationTrace {
    let factory = OperationTraceFactory(
        makeID: {
            UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        },
        now: { now }
    )
    return try factory.adopting(id, operation: operation, scope: scope)
}

private func p1bRequiredFailureRecord(
    _ record: FailureRecord?,
    label: String
) throws -> FailureRecord {
    guard let record else {
        throw P1BMigrationContractError.assertion(
            "missing failure record \(label)"
        )
    }
    return record
}

private func p1bRequireV13Migration(
    _ migrator: DatabaseMigrator
) throws {
    let finalMigration = migrator.migrations.last ?? "<none>"
    guard let v13Index = migrator.migrations.firstIndex(
        of: "v13-p1-observability"
    ) else {
        throw P1BMigrationContractError.missingV13(
            finalMigration: finalMigration
        )
    }
    guard let scheduleIndex = migrator.migrations.firstIndex(
        of: "v12-p1-schedule-fire"
    ), v13Index == scheduleIndex + 1
    else {
        throw P1BMigrationContractError.assertion(
            "v13-p1-observability is not the immediate successor of v12-p1-schedule-fire"
        )
    }
}

private func p1bRequire(
    _ condition: @autoclosure () throws -> Bool,
    _ message: String
) throws {
    guard try condition() else {
        throw P1BMigrationContractError.assertion(message)
    }
}

private func p1bTemporaryDatabaseURL(_ label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "agentloop-p1b-\(label)-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return directory.appendingPathComponent("fixture.sqlite")
}

private func p1bOpenPool(at url: URL) throws -> DatabasePool {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    return try DatabasePool(path: url.path, configuration: configuration)
}

private func p1bRequireV13ObjectsAbsent(_ database: Database) throws {
    let names = Set(try String.fetchAll(
        database,
        sql: """
            SELECT name FROM sqlite_master
            WHERE name IN (
              'failure_record',
              'failure_record_open_scope',
              'context_degradation',
              'context_degradation_mission',
              'context_degradation_card'
            )
            """
    ))
    try p1bRequire(
        names.isEmpty,
        "predecessor already contains v13 objects: \(names.sorted())"
    )
}

private func p1bValidateObservabilitySchema(
    in pool: DatabasePool,
    scope: String
) throws {
    try pool.read { database in
        let migrationCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM grdb_migrations
                WHERE identifier = 'v13-p1-observability'
                """
        ) ?? -1
        try p1bRequire(
            migrationCount == 1,
            "\(scope) v13 migration count is \(migrationCount)"
        )
        try p1bRequire(
            try p1bSQLiteObjectNames(database, type: "table").count == 31,
            "\(scope) final table checkpoint is not 31"
        )
        try p1bRequire(
            try p1bSQLiteObjectNames(database, type: "index").count == 65,
            "\(scope) final index checkpoint is not 65"
        )
        try p1bRequire(
            try p1bSQLiteObjectNames(database, type: "trigger").count == 4,
            "\(scope) final trigger checkpoint is not 4"
        )

        try p1bRequire(
            try database.columns(in: "failure_record").map(\.name) == [
                "id", "operation", "scopeKind", "campId", "scopeType",
                "scopeId", "severity", "errorCode", "userMessage",
                "diagnosticJson", "state", "firstSeenAt", "lastSeenAt",
                "occurrenceCount", "resolvedAt", "redactedAt",
            ],
            "\(scope) failure_record columns drifted"
        )
        try p1bRequire(
            try database.columns(in: "context_degradation").map(\.name) == [
                "id", "missionId", "cardId", "dependencyType",
                "dependencyId", "policy", "traceId", "detail",
                "createdAt", "redactedAt",
            ],
            "\(scope) context_degradation columns drifted"
        )

        try p1bRequire(
            try p1bForeignKeyShapes(database, table: "failure_record") == [
                .init(
                    from: "campId",
                    table: "camp",
                    to: "id",
                    onDelete: "RESTRICT"
                ),
            ],
            "\(scope) failure_record foreign keys drifted"
        )
        try p1bRequire(
            try p1bForeignKeyShapes(
                database,
                table: "context_degradation"
            ) == [
                .init(
                    from: "cardId",
                    table: "card",
                    to: "id",
                    onDelete: "RESTRICT"
                ),
                .init(
                    from: "missionId",
                    table: "mission",
                    to: "id",
                    onDelete: "RESTRICT"
                ),
            ],
            "\(scope) context_degradation foreign keys drifted"
        )

        let v13IndexNames = Set(try String.fetchAll(
            database,
            sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'index'
                  AND tbl_name IN ('failure_record', 'context_degradation')
                ORDER BY name
                """
        ))
        try p1bRequire(
            v13IndexNames == Set([
                "failure_record_open_scope",
                "context_degradation_mission",
                "context_degradation_card",
                "sqlite_autoindex_failure_record_1",
                "sqlite_autoindex_context_degradation_1",
            ]),
            "\(scope) v13 index set drifted: \(v13IndexNames.sorted())"
        )
        try p1bRequire(
            try p1bIndexColumns(
                database,
                index: "failure_record_open_scope"
            ) == [
                "scopeKind", "campId", "state", "scopeType", "scopeId",
                "lastSeenAt",
            ],
            "\(scope) failure_record_open_scope column order drifted"
        )
        try p1bRequire(
            try p1bIndexColumns(
                database,
                index: "context_degradation_mission"
            ) == ["missionId", "createdAt"],
            "\(scope) context_degradation_mission column order drifted"
        )
        try p1bRequire(
            try p1bIndexColumns(
                database,
                index: "context_degradation_card"
            ) == ["cardId", "createdAt"],
            "\(scope) context_degradation_card column order drifted"
        )

        let failureDDL = try p1bRequiredString(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name = 'failure_record'
                """,
            label: "\(scope) failure_record DDL"
        )
        for fragment in [
            "scopeKind IN ('camp','global')",
            "severity IN ('info','warning','error','critical')",
            "length(userMessage) <= 1000",
            "state IN ('open','resolved')",
            "occurrenceCount >= 1",
            "scopeKind = 'camp' AND campId IS NOT NULL",
            "scopeKind = 'global' AND campId IS NULL",
            "scopeKind = 'camp' AND userMessage = '[deleted]'",
            "diagnosticJson = '{}'",
        ] {
            try p1bRequire(
                failureDDL.contains(fragment),
                "\(scope) failure_record DDL is missing \(fragment)"
            )
        }
        let degradationDDL = try p1bRequiredString(
            database,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name = 'context_degradation'
                """,
            label: "\(scope) context_degradation DDL"
        )
        for fragment in [
            "policy IN ('required','optionalApproved')",
            "length(detail) <= 1000",
            "missionId IS NOT NULL OR cardId IS NOT NULL",
            "redactedAt IS NULL OR detail = '[deleted]'",
        ] {
            try p1bRequire(
                degradationDDL.contains(fragment),
                "\(scope) context_degradation DDL is missing \(fragment)"
            )
        }
        try p1bRequire(
            !degradationDDL.contains(
                "missionId IS NULL OR cardId IS NULL"
            ),
            "\(scope) context_degradation added a forbidden XOR"
        )

        for table in ["failure_record", "context_degradation"] {
            let count = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM \(table)"
            ) ?? -1
            try p1bRequire(
                count == 0,
                "\(scope) \(table) did not start empty"
            )
        }
        try p1bRequireHealthy(database, scope: scope)
    }
}

private func p1bValidateObservabilityContract(
    in pool: DatabasePool,
    scope: String
) throws {
    let prefix = "contract_" + scope
        .replacingOccurrences(of: ".", with: "_")
        .replacingOccurrences(of: "-", with: "_")
    let firstSeenAt = Double(bitPattern: 0x41d954fc40000001)
    let lastSeenAt = Double(bitPattern: 0x41d954fc40000002)
    let resolvedAt = Double(bitPattern: 0x41d954fc40000003)
    let redactedAt = Double(bitPattern: 0x41d954fc40000004)
    let before = try pool.read(p1bStableSnapshot)

    try pool.writeWithoutTransaction { database in
        try database.inSavepoint {
            try p1bInsertScopeGraph(database, prefix: prefix)

            for severity in ["info", "warning", "error", "critical"] {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-camp-open-\(severity)",
                    scopeKind: "camp",
                    campID: "\(prefix)-camp",
                    severity: severity,
                    userMessage: severity == "info"
                        ? String(repeating: "界", count: 1_000)
                        : "visible \(severity)",
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }
            try p1bInsertFailureRecord(
                database,
                id: "\(prefix)-camp-resolved",
                scopeKind: "camp",
                campID: "\(prefix)-camp",
                severity: "error",
                userMessage: "resolved camp",
                state: "resolved",
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                resolvedAt: resolvedAt
            )
            try p1bInsertFailureRecord(
                database,
                id: "\(prefix)-global-open",
                scopeKind: "global",
                severity: "warning",
                userMessage: "global open",
                state: "open",
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt
            )
            try p1bInsertFailureRecord(
                database,
                id: "\(prefix)-global-resolved",
                scopeKind: "global",
                severity: "critical",
                userMessage: "global resolved",
                state: "resolved",
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                resolvedAt: resolvedAt
            )
            try p1bInsertFailureRecord(
                database,
                id: "\(prefix)-camp-redacted",
                scopeKind: "camp",
                campID: "\(prefix)-camp",
                severity: "error",
                userMessage: "[deleted]",
                diagnosticJSON: "{}",
                state: "resolved",
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                resolvedAt: resolvedAt,
                redactedAt: redactedAt
            )

            try p1bInsertContextDegradation(
                database,
                id: "\(prefix)-mission-required",
                missionID: "\(prefix)-mission",
                policy: "required",
                detail: String(repeating: "界", count: 1_000),
                createdAt: firstSeenAt
            )
            try p1bInsertContextDegradation(
                database,
                id: "\(prefix)-card-optional",
                cardID: "\(prefix)-card",
                policy: "optionalApproved",
                detail: "optional card",
                createdAt: lastSeenAt
            )
            try p1bInsertContextDegradation(
                database,
                id: "\(prefix)-both-required",
                missionID: "\(prefix)-mission",
                cardID: "\(prefix)-card",
                policy: "required",
                detail: "both are intentionally legal",
                createdAt: resolvedAt
            )
            try p1bInsertContextDegradation(
                database,
                id: "\(prefix)-redacted",
                cardID: "\(prefix)-card",
                policy: "optionalApproved",
                detail: "[deleted]",
                createdAt: resolvedAt,
                redactedAt: redactedAt
            )

            let failureCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM failure_record"
            ) ?? -1
            try p1bRequire(
                failureCount == 8,
                "\(scope) legal failure_record shapes did not all persist"
            )
            let degradationCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM context_degradation"
            ) ?? -1
            try p1bRequire(
                degradationCount == 4,
                "\(scope) legal context_degradation shapes did not all persist"
            )
            let scalarBoundary = try Int.fetchOne(
                database,
                sql: """
                    SELECT length(userMessage) FROM failure_record
                    WHERE id = ?
                    """,
                arguments: ["\(prefix)-camp-open-info"]
            ) ?? -1
            try p1bRequire(
                scalarBoundary == 1_000,
                "\(scope) failure message scalar boundary drifted"
            )
            let dateValues = try Row.fetchOne(
                database,
                sql: """
                    SELECT firstSeenAt, lastSeenAt, resolvedAt, redactedAt
                    FROM failure_record WHERE id = ?
                    """,
                arguments: ["\(prefix)-camp-redacted"]
            )
            let dateRow = try p1bRequireRow(
                dateValues,
                label: "\(scope) failure date row"
            )
            let storedFirst: Double = dateRow["firstSeenAt"]
            let storedLast: Double = dateRow["lastSeenAt"]
            let storedResolved: Double = dateRow["resolvedAt"]
            let storedRedacted: Double = dateRow["redactedAt"]
            try p1bRequire(
                storedFirst.bitPattern == firstSeenAt.bitPattern
                    && storedLast.bitPattern == lastSeenAt.bitPattern
                    && storedResolved.bitPattern == resolvedAt.bitPattern
                    && storedRedacted.bitPattern == redactedAt.bitPattern,
                "\(scope) failure dates did not round-trip numerically"
            )

            try p1bExpectConstraint("\(scope) invalid scope kind") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-invalid-scope",
                    scopeKind: "owner",
                    severity: "error",
                    userMessage: "invalid",
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }
            try p1bExpectConstraint("\(scope) camp without campId") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-camp-without-id",
                    scopeKind: "camp",
                    severity: "error",
                    userMessage: "invalid",
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }
            try p1bExpectConstraint("\(scope) global with campId") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-global-with-id",
                    scopeKind: "global",
                    campID: "\(prefix)-camp",
                    severity: "error",
                    userMessage: "invalid",
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }
            for requiredColumn in [
                "id", "operation", "scopeKind", "scopeType", "scopeId",
                "severity", "errorCode", "userMessage", "diagnosticJson",
                "state", "firstSeenAt", "lastSeenAt", "occurrenceCount",
            ] {
                try p1bExpectConstraint(
                    "\(scope) NULL failure_record.\(requiredColumn)"
                ) {
                    try p1bInsertFailureRecordWithRequiredNull(
                        database,
                        id: "\(prefix)-null-\(requiredColumn)",
                        campID: "\(prefix)-camp",
                        nullColumn: requiredColumn,
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
            }
            for (tag, severity, state, occurrenceCount) in [
                ("severity", "fatal", "open", 1),
                ("state", "error", "closed", 1),
                ("occurrence", "error", "open", 0),
            ] {
                try p1bExpectConstraint("\(scope) invalid \(tag)") {
                    try p1bInsertFailureRecord(
                        database,
                        id: "\(prefix)-invalid-\(tag)",
                        scopeKind: "camp",
                        campID: "\(prefix)-camp",
                        severity: severity,
                        userMessage: "invalid",
                        state: state,
                        occurrenceCount: occurrenceCount,
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
            }
            try p1bExpectConstraint("\(scope) overlong failure message") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-long-message",
                    scopeKind: "camp",
                    campID: "\(prefix)-camp",
                    severity: "error",
                    userMessage: String(repeating: "界", count: 1_001),
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }
            try p1bExpectConstraint("\(scope) global redaction") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-global-redacted",
                    scopeKind: "global",
                    severity: "error",
                    userMessage: "[deleted]",
                    diagnosticJSON: "{}",
                    state: "resolved",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt,
                    redactedAt: redactedAt
                )
            }
            for (tag, message, diagnosticJSON) in [
                ("message", "still visible", "{}"),
                ("diagnostic", "[deleted]", "{\"raw\":true}"),
            ] {
                try p1bExpectConstraint("\(scope) invalid redacted \(tag)") {
                    try p1bInsertFailureRecord(
                        database,
                        id: "\(prefix)-redacted-\(tag)",
                        scopeKind: "camp",
                        campID: "\(prefix)-camp",
                        severity: "error",
                        userMessage: message,
                        diagnosticJSON: diagnosticJSON,
                        state: "resolved",
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt,
                        redactedAt: redactedAt
                    )
                }
            }
            try p1bExpectForeignKey("\(scope) missing failure camp") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-missing-camp",
                    scopeKind: "camp",
                    campID: "\(prefix)-absent-camp",
                    severity: "error",
                    userMessage: "invalid",
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }
            try p1bExpectConstraint("\(scope) duplicate failure trace") {
                try p1bInsertFailureRecord(
                    database,
                    id: "\(prefix)-global-open",
                    scopeKind: "global",
                    severity: "error",
                    userMessage: "duplicate",
                    state: "open",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )
            }

            try p1bExpectConstraint("\(scope) degradation without owner") {
                try p1bInsertContextDegradation(
                    database,
                    id: "\(prefix)-no-owner",
                    policy: "required",
                    detail: "invalid",
                    createdAt: firstSeenAt
                )
            }
            try p1bExpectConstraint("\(scope) invalid degradation policy") {
                try p1bInsertContextDegradation(
                    database,
                    id: "\(prefix)-invalid-policy",
                    missionID: "\(prefix)-mission",
                    policy: "optional",
                    detail: "invalid",
                    createdAt: firstSeenAt
                )
            }
            for requiredColumn in [
                "id", "dependencyType", "dependencyId", "policy", "traceId",
                "detail", "createdAt",
            ] {
                try p1bExpectConstraint(
                    "\(scope) NULL context_degradation.\(requiredColumn)"
                ) {
                    try p1bInsertContextDegradationWithRequiredNull(
                        database,
                        id: "\(prefix)-null-\(requiredColumn)",
                        missionID: "\(prefix)-mission",
                        nullColumn: requiredColumn,
                        createdAt: firstSeenAt
                    )
                }
            }
            try p1bExpectConstraint("\(scope) overlong degradation detail") {
                try p1bInsertContextDegradation(
                    database,
                    id: "\(prefix)-long-detail",
                    missionID: "\(prefix)-mission",
                    policy: "required",
                    detail: String(repeating: "界", count: 1_001),
                    createdAt: firstSeenAt
                )
            }
            try p1bExpectConstraint("\(scope) invalid degradation redaction") {
                try p1bInsertContextDegradation(
                    database,
                    id: "\(prefix)-invalid-redaction",
                    missionID: "\(prefix)-mission",
                    policy: "required",
                    detail: "still visible",
                    createdAt: firstSeenAt,
                    redactedAt: redactedAt
                )
            }
            try p1bExpectForeignKey("\(scope) missing degradation mission") {
                try p1bInsertContextDegradation(
                    database,
                    id: "\(prefix)-missing-mission",
                    missionID: "\(prefix)-absent-mission",
                    policy: "required",
                    detail: "invalid",
                    createdAt: firstSeenAt
                )
            }
            try p1bExpectForeignKey("\(scope) missing degradation card") {
                try p1bInsertContextDegradation(
                    database,
                    id: "\(prefix)-missing-card",
                    cardID: "\(prefix)-absent-card",
                    policy: "required",
                    detail: "invalid",
                    createdAt: firstSeenAt
                )
            }

            try p1bRequireHealthy(database, scope: "\(scope)-contract")
            return .rollback
        }
    }

    let after = try pool.read(p1bStableSnapshot)
    try p1bRequire(
        after == before,
        "\(scope) observability contract savepoint did not roll back exactly"
    )
}

private func p1bInsertScopeGraph(
    _ database: Database,
    prefix: String
) throws {
    try database.execute(
        sql: """
            INSERT INTO camp (id, name, archived, createdAt)
            VALUES (?, ?, 0, ?)
            """,
        arguments: ["\(prefix)-camp", "P1-B \(prefix)", 1_700_000_000.25]
    )
    try database.execute(
        sql: """
            INSERT INTO squad (
              id, campId, name, memberIdsJson, workspacePath,
              workspaceBookmark, createdAt
            ) VALUES (?, ?, ?, '[]', NULL, NULL, ?)
            """,
        arguments: [
            "\(prefix)-squad",
            "\(prefix)-camp",
            "Squad \(prefix)",
            1_700_000_000.25,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO mission (
              id, squadId, goalRaw, goalRefined, status, budgetTokens,
              spentTokens, revision, autonomy, createdAt
            ) VALUES (?, ?, 'Goal', 'Goal', 'planning', 1000, 0, 1,
                      'standard', ?)
            """,
        arguments: [
            "\(prefix)-mission",
            "\(prefix)-squad",
            1_700_000_000.25,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO card (
              id, missionId, idemKey, title, descriptionText, expectedOutput,
              assigneeId, status, blockedReasonJson, dependsOnJson,
              handoffJson, stage, reviewFlag, maxTurns, tokenBudget, createdAt
            ) VALUES (?, ?, ?, 'Card', 'Description', 'Output', NULL,
                      'pending', NULL, '[]', NULL, 1, NULL, 10, 1000, ?)
            """,
        arguments: [
            "\(prefix)-card",
            "\(prefix)-mission",
            "\(prefix)-idem",
            1_700_000_000.25,
        ]
    )
}

private func p1bInsertV12SchedulePredecessor(
    _ database: Database,
    prefix: String
) throws {
    try p1bInsertScopeGraph(database, prefix: prefix)
    try database.execute(
        sql: """
            INSERT INTO mission_template (
              id, name, goal, companionIdsJson, workspacePath, budgetTokens,
              autonomy, campId, createdAt
            ) VALUES (?, 'Template', 'Goal', '[]', NULL, 1000, 'standard',
                      ?, ?)
            """,
        arguments: [
            "\(prefix)-template",
            "\(prefix)-camp",
            1_700_000_000.25,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO schedule (
              id, templateId, frequency, hour, minute, weekday, enabled,
              lastFiredAt, createdAt
            ) VALUES (?, ?, 'daily', 9, 30, NULL, 1, ?, ?)
            """,
        arguments: [
            "\(prefix)-schedule",
            "\(prefix)-template",
            1_700_000_000.25,
            1_700_000_000.0,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO schedule_fire (
              id, scheduleId, templateId, slotKey, scheduledAt,
              replayOfFireId, replayIdempotencyKey, replayPayloadHash, state,
              missionId, traceId, errorCode, errorMessage, createdAt,
              redactedAt
            ) VALUES (?, ?, ?, 'seed-slot', ?, NULL, NULL, NULL, 'started',
                      ?, ?, NULL, NULL, ?, NULL)
            """,
        arguments: [
            "\(prefix)-fire",
            "\(prefix)-schedule",
            "\(prefix)-template",
            1_700_000_000.25,
            "\(prefix)-mission",
            "\(prefix)-fire-trace",
            1_700_000_000.5,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO schedule_evaluation_cursor (
              scheduleId, lastEvaluatedSlotKey, lastEvaluatedScheduledAt,
              version, updatedAt
            ) VALUES (?, 'seed-slot', ?, 1, ?)
            """,
        arguments: [
            "\(prefix)-schedule",
            1_700_000_000.25,
            1_700_000_000.5,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work (
              id, campId, kind, aggregateType, aggregateId, idempotencyKey,
              state, attempt, maxAttempts, notBefore, leaseOwner,
              leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
              errorMessage, traceId, version, createdAt, updatedAt, finishedAt
            ) VALUES (?, ?, 'planning', 'mission', ?, ?, 'running', 1, 4,
                      NULL, 'worker', ?, '{"value":1}', ?, NULL, NULL, NULL,
                      ?, 2, ?, ?, NULL)
            """,
        arguments: [
            "\(prefix)-work",
            "\(prefix)-camp",
            "\(prefix)-mission",
            "\(prefix)-work-idem",
            1_700_000_060.0,
            String(repeating: "a", count: 64),
            "\(prefix)-work-trace",
            1_700_000_000.0,
            1_700_000_000.0,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt (
              workId, attempt, id, workerId, startedAt, endedAt, outcome,
              errorCode, errorMessage, traceId, terminalWorkVersion
            ) VALUES (?, 1, ?, 'worker', ?, NULL, NULL, NULL, NULL, ?, NULL)
            """,
        arguments: [
            "\(prefix)-work",
            "\(prefix)-attempt",
            1_700_000_000.0,
            "\(prefix)-work-trace",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt_event (
              id, workId, attempt, sequence, eventKind, workerId,
              workVersion, resultingWorkState, errorCode, errorMessage,
              occurredAt
            ) VALUES (?, ?, 1, 0, 'claimed', 'worker', 2, 'running', NULL,
                      NULL, ?)
            """,
        arguments: [
            "\(prefix)-attempt-event",
            "\(prefix)-work",
            1_700_000_000.0,
        ]
    )
}

private func p1bInsertFailureRecord(
    _ database: Database,
    id: String,
    scopeKind: String,
    campID: String? = nil,
    severity: String,
    userMessage: String,
    diagnosticJSON: String = "{}",
    state: String,
    occurrenceCount: Int = 1,
    firstSeenAt: Double,
    lastSeenAt: Double,
    resolvedAt: Double? = nil,
    redactedAt: Double? = nil
) throws {
    try database.execute(
        sql: """
            INSERT INTO failure_record (
              id, operation, scopeKind, campId, scopeType, scopeId, severity,
              errorCode, userMessage, diagnosticJson, state, firstSeenAt,
              lastSeenAt, occurrenceCount, resolvedAt, redactedAt
            ) VALUES (?, 'test_operation', ?, ?, 'test_scope', 'scope-id', ?,
                      'test_error', ?, ?, ?, ?, ?, ?, ?, ?)
            """,
        arguments: [
            id, scopeKind, campID, severity, userMessage, diagnosticJSON,
            state, firstSeenAt, lastSeenAt, occurrenceCount, resolvedAt,
            redactedAt,
        ]
    )
}

private func p1bInsertContextDegradation(
    _ database: Database,
    id: String,
    missionID: String? = nil,
    cardID: String? = nil,
    policy: String,
    detail: String,
    createdAt: Double,
    redactedAt: Double? = nil
) throws {
    try database.execute(
        sql: """
            INSERT INTO context_degradation (
              id, missionId, cardId, dependencyType, dependencyId, policy,
              traceId, detail, createdAt, redactedAt
            ) VALUES (?, ?, ?, 'knowledge', 'dependency-id', ?, ?, ?, ?, ?)
            """,
        arguments: [
            id, missionID, cardID, policy, "trace-\(id)", detail, createdAt,
            redactedAt,
        ]
    )
}

private func p1bInsertFailureRecordWithRequiredNull(
    _ database: Database,
    id: String,
    campID: String,
    nullColumn: String,
    firstSeenAt: Double,
    lastSeenAt: Double
) throws {
    let requiredColumns = Set([
        "id", "operation", "scopeKind", "scopeType", "scopeId", "severity",
        "errorCode", "userMessage", "diagnosticJson", "state",
        "firstSeenAt", "lastSeenAt", "occurrenceCount",
    ])
    try p1bRequire(
        requiredColumns.contains(nullColumn),
        "unknown failure_record required column \(nullColumn)"
    )
    var values: [String: (any DatabaseValueConvertible)?] = [
        "id": id,
        "operation": "test_operation",
        "scopeKind": "camp",
        "campId": campID,
        "scopeType": "test_scope",
        "scopeId": "scope-id",
        "severity": "error",
        "errorCode": "test_error",
        "userMessage": "visible",
        "diagnosticJson": "{}",
        "state": "open",
        "firstSeenAt": firstSeenAt,
        "lastSeenAt": lastSeenAt,
        "occurrenceCount": 1,
    ]
    values[nullColumn] = DatabaseValue.null
    try database.execute(
        sql: """
            INSERT INTO failure_record (
              id, operation, scopeKind, campId, scopeType, scopeId, severity,
              errorCode, userMessage, diagnosticJson, state, firstSeenAt,
              lastSeenAt, occurrenceCount, resolvedAt, redactedAt
            ) VALUES (
              :id, :operation, :scopeKind, :campId, :scopeType, :scopeId,
              :severity, :errorCode, :userMessage, :diagnosticJson, :state,
              :firstSeenAt, :lastSeenAt, :occurrenceCount, NULL, NULL
            )
            """,
        arguments: StatementArguments(values)
    )
}

private func p1bInsertContextDegradationWithRequiredNull(
    _ database: Database,
    id: String,
    missionID: String,
    nullColumn: String,
    createdAt: Double
) throws {
    let requiredColumns = Set([
        "id", "dependencyType", "dependencyId", "policy", "traceId",
        "detail", "createdAt",
    ])
    try p1bRequire(
        requiredColumns.contains(nullColumn),
        "unknown context_degradation required column \(nullColumn)"
    )
    var values: [String: (any DatabaseValueConvertible)?] = [
        "id": id,
        "missionId": missionID,
        "dependencyType": "knowledge",
        "dependencyId": "dependency-id",
        "policy": "required",
        "traceId": "trace-\(id)",
        "detail": "visible",
        "createdAt": createdAt,
    ]
    values[nullColumn] = DatabaseValue.null
    try database.execute(
        sql: """
            INSERT INTO context_degradation (
              id, missionId, cardId, dependencyType, dependencyId, policy,
              traceId, detail, createdAt, redactedAt
            ) VALUES (
              :id, :missionId, NULL, :dependencyType, :dependencyId, :policy,
              :traceId, :detail, :createdAt, NULL
            )
            """,
        arguments: StatementArguments(values)
    )
}

private func p1bExpectConstraint(
    _ label: String,
    operation: () throws -> Void
) throws {
    try p1bExpectDatabaseFailure(
        label,
        extendedCodes: [
            .SQLITE_CONSTRAINT_CHECK,
            .SQLITE_CONSTRAINT_NOTNULL,
            .SQLITE_CONSTRAINT_PRIMARYKEY,
            .SQLITE_CONSTRAINT_UNIQUE,
        ],
        operation: operation
    )
}

private func p1bExpectForeignKey(
    _ label: String,
    operation: () throws -> Void
) throws {
    try p1bExpectDatabaseFailure(
        label,
        extendedCodes: [.SQLITE_CONSTRAINT_FOREIGNKEY],
        operation: operation
    )
}

private func p1bExpectDatabaseFailure(
    _ label: String,
    extendedCodes: [ResultCode],
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as DatabaseError {
        try p1bRequire(
            extendedCodes.contains(error.extendedResultCode),
            "\(label) failed with \(error.extendedResultCode)"
        )
        return
    }
    throw P1BMigrationContractError.expectedDatabaseFailure(label)
}

private func p1bSQLiteObjectNames(
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

private func p1bForeignKeyShapes(
    _ database: Database,
    table: String
) throws -> [P1BForeignKeyShape] {
    try Row.fetchAll(
        database,
        sql: "SELECT * FROM pragma_foreign_key_list(?)",
        arguments: [table]
    ).map { row in
        P1BForeignKeyShape(
            from: row["from"],
            table: row["table"],
            to: row["to"],
            onDelete: row["on_delete"]
        )
    }.sorted()
}

private func p1bIndexColumns(
    _ database: Database,
    index: String
) throws -> [String] {
    try String.fetchAll(
        database,
        sql: "SELECT name FROM pragma_index_info(?) ORDER BY seqno",
        arguments: [index]
    )
}

private func p1bRequiredString(
    _ database: Database,
    sql: String,
    label: String
) throws -> String {
    guard let value = try String.fetchOne(database, sql: sql) else {
        throw P1BMigrationContractError.assertion("missing \(label)")
    }
    return value
}

private func p1bRequireRow(_ row: Row?, label: String) throws -> Row {
    guard let row else {
        throw P1BMigrationContractError.assertion("missing \(label)")
    }
    return row
}

private func p1bRequireHealthy(
    _ database: Database,
    scope: String
) throws {
    let foreignKeyCursor = try database.foreignKeyViolations()
    try p1bRequire(
        try foreignKeyCursor.next() == nil,
        "\(scope) has a foreign-key violation"
    )
    let integrity = try String.fetchOne(
        database,
        sql: "PRAGMA integrity_check"
    )
    try p1bRequire(
        integrity == "ok",
        "\(scope) integrity_check failed: \(integrity ?? "<nil>")"
    )
}

private func p1bUserTableNames(_ database: Database) throws -> [String] {
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

private func p1bStableRowsSnapshot(
    _ database: Database,
    tables: [String]
) throws -> String {
    var sections: [String] = []
    for table in tables.sorted() {
        try p1bRequire(
            try database.tableExists(table),
            "stable snapshot is missing table \(table)"
        )
        let columns = try database.columns(in: table).map(\.name)
        let quotedColumns = columns.map(p1bQuotedIdentifier)
        let projection = quotedColumns
            .map { "quote(\($0))" }
            .joined(separator: " || char(31) || ")
        let order = quotedColumns.joined(separator: ", ")
        let rows = try String.fetchAll(
            database,
            sql: """
                SELECT \(projection)
                FROM \(p1bQuotedIdentifier(table))
                ORDER BY \(order)
                """
        )
        sections.append("TABLE \(table)")
        sections.append(contentsOf: rows)
    }
    return sections.joined(separator: "\n")
}

private func p1bStableSnapshot(_ database: Database) throws -> String {
    var sections = try String.fetchAll(
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
        sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name
            """
    )
    sections.append(try p1bStableRowsSnapshot(database, tables: tables))
    return sections.joined(separator: "\n")
}

private func p1bQuotedIdentifier(_ identifier: String) -> String {
    "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
}
