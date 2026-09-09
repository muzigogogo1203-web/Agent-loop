import CryptoKit
import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

private struct P1EProcessResult {
    let status: Int32
    let output: String
}

private enum P1ESQLiteCompatibilityError: Error, CustomStringConvertible {
    case missingAuthority
    case processFailure(String)

    var description: String {
        switch self {
        case .missingAuthority:
            return "P1-E Stage §18.6 SQL authority is missing"
        case let .processFailure(message):
            return "P1-E SQLite process failure: \(message)"
        }
    }
}

private func p1eCompatibilitySource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func p1eCompatibilityStageSQL() throws -> String {
    let source = try p1eCompatibilitySource(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"
    )
    guard let heading = source.range(of: "### 18.6 `v16-p1-identity-memory`"),
          let opening = source.range(
            of: "```sql\n",
            range: heading.upperBound..<source.endIndex
          ),
          let closing = source.range(
            of: "\n```",
            range: opening.upperBound..<source.endIndex
          )
    else {
        throw P1ESQLiteCompatibilityError.missingAuthority
    }
    return String(source[opening.upperBound..<closing.lowerBound])
}

private func p1eRunProcess(
    executable: String,
    arguments: [String],
    input: String? = nil
) throws -> P1EProcessResult {
    let process = Process()
    let diagnostics = Pipe()
    let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "agentloop-p1e-process-input-\(UUID().uuidString).sql"
    )
    var inputHandle: FileHandle?
    defer {
        try? inputHandle?.close()
        try? FileManager.default.removeItem(at: inputURL)
    }
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = diagnostics
    process.standardError = diagnostics
    if let input {
        try input.write(to: inputURL, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forReadingFrom: inputURL)
        inputHandle = handle
        process.standardInput = handle
    }
    try process.run()
    let data = diagnostics.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return P1EProcessResult(
        status: process.terminationStatus,
        output: String(decoding: data, as: UTF8.self)
    )
}

private func p1eLiteralFence(
    sqlite: String,
    expectedVersionPrefix: String,
    label: String
) throws {
    let version = try p1eRunProcess(
        executable: sqlite,
        arguments: ["--version"]
    )
    #expect(version.status == 0)
    #expect(version.output.hasPrefix(expectedVersionPrefix))

    let temporaryPath = FileManager.default.temporaryDirectory.path
    let physicalTemporaryPath = temporaryPath.hasPrefix("/var/")
        ? "/private\(temporaryPath)"
        : temporaryPath
    let databaseURL = URL(fileURLWithPath: physicalTemporaryPath, isDirectory: true)
        .appendingPathComponent("agentloop-p1e-literal-\(label)-\(UUID().uuidString).sqlite")
    let queue = try DatabaseQueue(path: databaseURL.path)
    try AppDatabase.migrator.migrate(queue, upTo: "v15-p1-outcome-contracts")
    try queue.close()

    let input = """
        .bail on
        PRAGMA foreign_keys=ON;
        BEGIN IMMEDIATE;
        \(try p1eCompatibilityStageSQL())
        COMMIT;
        SELECT
          (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%')
          || '/' ||
          (SELECT COUNT(*) FROM sqlite_master WHERE type='index')
          || '/' ||
          (SELECT COUNT(*) FROM sqlite_master WHERE type='trigger');
        PRAGMA foreign_key_check;
        PRAGMA integrity_check;
        """
    let result = try p1eRunProcess(
        executable: sqlite,
        arguments: ["-init", "/dev/null", "-batch", "-bail", "-nofollow", databaseURL.path],
        input: input
    )
    guard result.status == 0 else {
        throw P1ESQLiteCompatibilityError.processFailure(
            "\(label) exited \(result.status): \(result.output)"
        )
    }
    let lines = result.output.split(separator: "\n").map(String.init)
    #expect(lines.contains("67/171/67"))
    #expect(lines.last == "ok")
    #expect(!lines.contains { $0.contains("foreign key constraint failed") })
}

@Suite(.serialized)
struct P1ESQLiteMigrationCompatibilityTests {
    @Test func p1e14LiteralSQLite351V16Fence() throws {
        try p1eLiteralFence(
            sqlite: "/usr/bin/sqlite3",
            expectedVersionPrefix: "3.51.",
            label: "sqlite-351"
        )
    }

    @Test func p1e15LiteralSQLite352V16Fence() throws {
        try p1eLiteralFence(
            sqlite: "/opt/homebrew/opt/sqlite/bin/sqlite3",
            expectedVersionPrefix: "3.52.",
            label: "sqlite-352"
        )
    }

    @Test func p1e16RealSQLiteDualLaneV16Contract() throws {
        let package = try p1eCompatibilitySource("Package.swift")
        let script = try p1eCompatibilitySource(
            "scripts/verify-p1-migrations-sqlite-matrix.sh"
        )
        let runner = try p1eCompatibilitySource(
            "Sources/P1MigrationMatrixRunner/main.swift"
        )
        let checks: [(String, Bool)] = [
            ("Package direct GRDBSQLite", package.contains(
                ".product(name: \"GRDBSQLite\", package: \"GRDB.swift\")"
            )),
            ("script v16 literal variable", script.contains("literal_identity_memory_sql")),
            ("script v16 literal argument", script.contains("--literal-identity-memory-schema")),
            ("script SQLite 3.51", script.contains("/usr/bin/sqlite3")),
            ("script SQLite 3.52", script.contains("/opt/homebrew/opt/sqlite/bin/sqlite3")),
            ("script v16 checkpoint", script.contains("67/171/67")),
            ("runner v15 empty fixture", runner.contains("v15Empty")),
            ("runner v15 populated fixture", runner.contains("v15Populated")),
            ("runner v16 migration", runner.contains("v16-p1-identity-memory")),
            ("runner UDF", runner.contains("agentloop_active_ingestion_deletion_permit_v1")),
            ("runner real GRDB sentinel", runner.contains("fixture.v16.real_grdb.result=pass")),
        ]
        for (label, passed) in checks {
            #expect(passed, Comment(rawValue: label))
        }
    }
}

private let p1f1V16Migration = "v16-p1-identity-memory"
private let p1f1V17Migration = "v17-p1-engine-coordination"
private let p1f1Epoch = Date(timeIntervalSince1970: 3_000_000)
private let p1f1HashA = String(repeating: "a", count: 64)
private let p1f1HashB = String(repeating: "b", count: 64)
private let p1f1HashC = String(repeating: "c", count: 64)
private let p1f1HashD = String(repeating: "d", count: 64)

private enum P1F1SQLiteTestError: Error, CustomStringConvertible {
    case missingAuthority
    case missingMigration
    case expectedFailure(String)
    case wrongMigrationError(String)

    var description: String {
        switch self {
        case .missingAuthority:
            return "P1-F1 Stage §18.7 SQL authority is missing"
        case .missingMigration:
            return "P1-F1 v17 migration is missing"
        case let .expectedFailure(label):
            return "P1-F1 expected database failure did not occur: \(label)"
        case let .wrongMigrationError(error):
            return "P1-F1 migration failed with the wrong error: \(error)"
        }
    }
}

private struct P1F1LegacyArtifactGraph {
    let campID: String
    let squadID: String
    let missionID: String
    let cardID: String
    let artifactID: String
    let path: String
    let createdAt: Date
}

private struct P1F1EngineGraph {
    let legacy: P1F1LegacyArtifactGraph
    let profileID: String
    let runID: String
    let sessionID: String
    let executionID: String
    let proposalID: String
    let proposalArtifactID: String
    let discussionID: String
    let discussionTurnID: String
    let eventID: String
}

private let p1f1TriggerNames = [
    "engine_session_first_redaction_exact",
    "engine_session_post_redaction_lock",
    "engine_session_reject_delete",
    "engine_execution_first_redaction_exact",
    "engine_execution_post_redaction_lock",
    "engine_execution_reject_delete",
    "engine_terminal_proposal_first_redaction_exact",
    "engine_terminal_proposal_post_redaction_lock",
    "engine_terminal_proposal_reject_delete",
    "engine_proposal_artifact_reject_private_field_update",
    "engine_proposal_artifact_post_redaction_lock",
    "engine_proposal_artifact_reject_delete",
    "artifact_storage_origin_first_redaction_exact",
    "artifact_storage_origin_post_redaction_lock",
    "artifact_storage_origin_reject_delete",
    "discussion_turn_reject_update_except_camp_redaction",
    "discussion_turn_reject_delete",
]

private func p1f1StageV17SQL() throws -> String {
    let source = try p1eCompatibilitySource(
        "docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"
    )
    guard let heading = source.range(
        of: "### 18.7 `v17-p1-engine-coordination`"
    ), let opening = source.range(
        of: "```sql\n",
        range: heading.upperBound..<source.endIndex
    ), let closing = source.range(
        of: "\n```",
        range: opening.upperBound..<source.endIndex
    ) else {
        throw P1F1SQLiteTestError.missingAuthority
    }
    return String(source[opening.upperBound..<closing.lowerBound])
}

private func p1f1SHA256(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8)).map {
        String(format: "%02x", $0)
    }.joined()
}

private func p1f1Queue(
    _ label: String,
    foreignKeysEnabled: Bool = true
) throws -> DatabaseQueue {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = foreignKeysEnabled
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "agentloop-p1f1-\(label)-\(UUID().uuidString).sqlite"
    )
    return try DatabaseQueue(path: url.path, configuration: configuration)
}

private func p1f1RequireV17() throws {
    guard AppDatabase.migrator.migrations.contains(p1f1V17Migration) else {
        throw P1F1SQLiteTestError.missingMigration
    }
}

private func p1f1MigrateToV16(_ queue: DatabaseQueue) throws {
    try AppDatabase.migrator.migrate(queue, upTo: p1f1V16Migration)
}

private func p1f1MigrateToV17(_ queue: DatabaseQueue) throws {
    try p1f1RequireV17()
    try AppDatabase.migrator.migrate(queue, upTo: p1f1V17Migration)
}

private func p1f1QuotedIdentifier(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func p1f1LogicalSnapshot(_ database: Database) throws -> [String] {
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
            "quote(\(p1f1QuotedIdentifier($0)))"
        }.joined(separator: " || char(31) || ")
        let rows = try String.fetchAll(
            database,
            sql: "SELECT \(projection) FROM \(p1f1QuotedIdentifier(table)) ORDER BY 1"
        )
        result.append(contentsOf: rows.map { "row:\(table):\($0)" })
    }
    return result
}

@discardableResult
private func p1f1ExpectDatabaseFailure(
    _ label: String,
    _ operation: () throws -> Void
) throws -> any Error {
    do {
        try operation()
    } catch {
        return error
    }
    throw P1F1SQLiteTestError.expectedFailure(label)
}

private func p1f1SchemaCheckpoint(
    _ database: Database
) throws -> (tables: Int, indexes: Int, triggers: Int) {
    (
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        ) ?? -1,
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='index'"
        ) ?? -1,
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger'"
        ) ?? -1
    )
}

private func p1f1ExpectHealthyDatabase(_ database: Database) throws {
    #expect(try Row.fetchAll(database, sql: "PRAGMA foreign_key_check").isEmpty)
    #expect(try String.fetchAll(database, sql: "PRAGMA integrity_check") == ["ok"])
}

@discardableResult
private func p1f1InsertLegacyArtifactGraph(
    _ suffix: String,
    path: String,
    createdAt: Date = p1f1Epoch,
    in database: Database
) throws -> P1F1LegacyArtifactGraph {
    let graph = P1F1LegacyArtifactGraph(
        campID: "p1f1-camp-\(suffix)",
        squadID: "p1f1-squad-\(suffix)",
        missionID: "p1f1-mission-\(suffix)",
        cardID: "p1f1-card-\(suffix)",
        artifactID: "p1f1-artifact-\(suffix)",
        path: path,
        createdAt: createdAt
    )
    try CampRecord(
        id: graph.campID,
        name: "P1-F1 \(suffix)",
        createdAt: createdAt
    ).insert(database)
    if try database.tableExists("camp_lifecycle") {
        try database.execute(
            sql: """
                INSERT INTO camp_lifecycle(
                  campId,state,version,createdAt,updatedAt,
                  deletionRequestedAt,deletedAt
                ) VALUES (?,'active',1,?,?,NULL,NULL)
                """,
            arguments: [graph.campID, createdAt, createdAt]
        )
    }
    try SquadRecord(
        id: graph.squadID,
        campId: graph.campID,
        name: "P1-F1 Squad",
        memberIdsJson: "[]",
        workspacePath: nil,
        workspaceBookmark: nil,
        createdAt: createdAt
    ).insert(database)
    try MissionRecord(
        id: graph.missionID,
        squadId: graph.squadID,
        goalRaw: "P1-F1 goal",
        goalRefined: "P1-F1 goal",
        status: .planning,
        budgetTokens: 10_000,
        spentTokens: 0,
        revision: 1,
        createdAt: createdAt
    ).insert(database)
    try CardRecord(
        id: graph.cardID,
        missionId: graph.missionID,
        idemKey: "p1f1-card-idem-\(suffix)",
        title: "P1-F1 Card",
        descriptionText: "P1-F1",
        expectedOutput: "artifact",
        assigneeId: nil,
        status: .todo,
        blockedReasonJson: nil,
        dependsOnJson: "[]",
        handoffJson: nil,
        stage: 1,
        maxTurns: 1,
        tokenBudget: 1_000,
        createdAt: createdAt
    ).insert(database)
    try ArtifactRecord(
        id: graph.artifactID,
        cardId: graph.cardID,
        path: path,
        kind: "file",
        label: "artifact-\(suffix)",
        createdAt: createdAt
    ).insert(database)
    return graph
}

private func p1f1InsertDomainEvent(
    _ suffix: String,
    campID: String,
    in database: Database
) throws -> String {
    let key = "p1f1-event-command-\(suffix)"
    let eventID = "p1f1-domain-event-\(suffix)"
    try database.execute(
        sql: """
            INSERT INTO domain_command_receipt(
              idempotencyKey,commandType,commandPayloadHash,eventCount,
              resultJson,resultHash,createdAt
            ) VALUES (?,'p1f1_fixture',?,1,'{}',?,?)
            """,
        arguments: [key, p1f1HashA, p1f1HashB, p1f1Epoch]
    )
    try database.execute(
        sql: """
            INSERT INTO camp_event_scope(
              sourceTable,eventId,scopeKind,campId,payloadRedactedAt
            ) VALUES ('domain_event',?,'camp',?,NULL)
            """,
        arguments: [eventID, campID]
    )
    try database.execute(
        sql: """
            INSERT INTO domain_event(
              id,campId,aggregateType,aggregateId,aggregateVersion,eventType,
              payloadVersion,payloadJson,payloadHash,actorType,actorId,deviceId,
              causationId,correlationId,commandIdempotencyKey,eventOrdinal,
              eventIdempotencyKey,occurredAt,recordedAt
            ) VALUES (?,?,'p1f1Fixture',?,1,'p1f1_fixture',1,'{}',?,
              'system','system:p1f1',NULL,NULL,?,?,0,?,?,?)
            """,
        arguments: [
            eventID, campID, suffix, p1f1HashC, "trace:\(suffix)", key,
            "p1f1-event-idem-\(suffix)", p1f1Epoch, p1f1Epoch,
        ]
    )
    return eventID
}

@discardableResult
private func p1f1InsertEngineGraph(
    _ suffix: String,
    in database: Database
) throws -> P1F1EngineGraph {
    let legacy = try p1f1InsertLegacyArtifactGraph(
        suffix,
        path: "/tmp/p1f1-engine-\(suffix).bin",
        in: database
    )
    let profileID = "p1f1-profile-\(suffix)"
    let runID = "p1f1-run-\(suffix)"
    let sessionID = "p1f1-session-\(suffix)"
    let executionID = "p1f1-execution-\(suffix)"
    let proposalID = "p1f1-proposal-\(suffix)"
    let proposalArtifactID = "p1f1-proposal-artifact-\(suffix)"
    let discussionID = "p1f1-discussion-\(suffix)"
    let discussionTurnID = "p1f1-discussion-turn-\(suffix)"
    let terminalReceipt = "p1f1-terminal-receipt-\(suffix)"
    try RuntimeProfileRecord(
        id: profileID,
        kind: .cliCodex,
        name: "P1-F1 CLI",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: p1f1Epoch
    ).insert(database)
    try RunRecord(
        id: runID,
        cardId: legacy.cardID,
        attempt: 1,
        outcome: "completed",
        turns: 1,
        tokensIn: 1,
        tokensOut: 1,
        startedAt: p1f1Epoch,
        endedAt: p1f1Epoch.addingTimeInterval(1)
    ).insert(database)
    try database.execute(
        sql: """
            INSERT INTO domain_command_receipt(
              idempotencyKey,commandType,commandPayloadHash,eventCount,
              resultJson,resultHash,createdAt
            ) VALUES (?,'engine_terminal',?,0,'{}',?,?)
            """,
        arguments: [terminalReceipt, p1f1HashA, p1f1HashB, p1f1Epoch]
    )
    try database.execute(
        sql: """
            INSERT INTO engine_session(
              id,campId,adapterId,adapterVersion,profileId,externalSessionId,
              workspaceHash,sessionScopeJson,sessionScopeHash,state,version,
              createdAt,updatedAt,redactedAt
            ) VALUES (?,?,'codex','1',?, ?,?,'{}',?,'active',1,?,?,NULL)
            """,
        arguments: [
            sessionID, legacy.campID, profileID, "external:\(suffix)",
            p1f1HashA, p1f1HashB, p1f1Epoch, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO engine_execution(
              id,campId,campLifecycleVersion,idempotencyKey,runId,cardId,
              adapterId,adapterVersion,profileId,engineKind,model,requestJson,
              requestHash,contextJson,contextHash,sessionScopeJson,
              sessionScopeHash,sessionId,replayClass,dispatchState,state,
              terminalSubtype,nextSequence,terminalReceiptIdempotencyKey,
              terminalReceiptHash,inputTokens,outputTokens,cacheReadTokens,
              costMicros,version,createdAt,updatedAt,dispatchStartedAt,
              cancellationRequestedAt,cancellationReason,finishedAt,redactedAt
            ) VALUES (
              ?,?,1,?,?,?,'codex','1',?,'cli','test-model','{}',?,'{}',?,
              '{}',?,?,'idempotencyKeyed','terminal','completed',NULL,1,?,?,
              1,1,0,0,1,?,?,?,NULL,NULL,?,NULL
            )
            """,
        arguments: [
            executionID, legacy.campID, "p1f1-execution-idem-\(suffix)",
            runID, legacy.cardID, profileID, p1f1HashA, p1f1HashB,
            p1f1HashC, sessionID, terminalReceipt, p1f1HashD,
            p1f1Epoch, p1f1Epoch.addingTimeInterval(1), p1f1Epoch,
            p1f1Epoch.addingTimeInterval(1),
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO engine_terminal_proposal(
              id,executionId,terminalIdempotencyKey,sequence,terminalKind,
              terminalSubtype,proposalJson,proposalHash,payloadJson,payloadHash,
              artifactManifestJson,artifactManifestHash,state,version,createdAt,
              committedAt,invalidReason,invalidatedAt,redactedAt
            ) VALUES (?,?,?,1,'completed',NULL,'{}',?,'{}',?,'[]',?,
              'committed',1,?,?,NULL,NULL,NULL)
            """,
        arguments: [
            proposalID, executionID, "p1f1-terminal-idem-\(suffix)",
            p1f1HashA, p1f1HashB, p1f1HashC, p1f1Epoch,
            p1f1Epoch.addingTimeInterval(1),
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO artifact_blob(
              contentHash,byteCount,relativePath,state,version,createdAt,
              verifiedAt,deletedAt
            ) VALUES (?,1,?,'available',1,?,?,NULL)
            """,
        arguments: [
            p1f1HashA, "objects/aa/\(p1f1HashA)", p1f1Epoch, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO engine_proposal_artifact(
              id,proposalId,artifactId,ordinal,sourceRelativePath,kind,label,
              byteCount,contentHash,state,preparedAt,version,redactedAt
            ) VALUES (?,?,?,0,'result.bin','file','Result',1,?,
              'prepared',?,1,NULL)
            """,
        arguments: [
            proposalArtifactID, proposalID, legacy.artifactID, p1f1HashA,
            p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO artifact_blob_reference(
              artifactId,proposalArtifactId,executionId,campId,contentHash,
              state,createdAt,tombstonedAt
            ) VALUES (?,?,?,?,?,'active',?,NULL)
            """,
        arguments: [
            legacy.artifactID, proposalArtifactID, executionID, legacy.campID,
            p1f1HashA, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO artifact_storage_origin(
              artifactId,campId,state,storageClass,evidenceKind,managedRootId,
              objectId,contentHash,fileIdentityHash,originalRefHash,
              classificationEvidenceHash,terminalDisposition,
              terminalAuthorityHash,version,classifiedAt,redactedAt
            ) VALUES (?,?,'active','managed','typedPreparedArtifact',
              'root:test',?, ?,?,?,?,NULL,NULL,1,?,NULL)
            """,
        arguments: [
            legacy.artifactID, legacy.campID, "object:\(suffix)", p1f1HashA,
            p1f1HashB, p1f1SHA256(legacy.path), p1f1HashC, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO discussion(
              id,campId,goalId,missionId,cardId,purpose,
              participantActorIdsJson,maxRounds,tokenBudget,spentTokens,status,
              requiredMaterialization,materializationType,materializationId,
              aggregateVersion,createdAt,updatedAt
            ) VALUES (?, ?,NULL,?,?,'fixture','["cow:a","cow:b"]',2,100,1,
              'running','outcome',NULL,NULL,1,?,?)
            """,
        arguments: [
            discussionID, legacy.campID, legacy.missionID, legacy.cardID,
            p1f1Epoch, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO discussion_turn(
              id,discussionId,round,sequence,speakerActorId,contentRef,
              contentHash,inputTokens,outputTokens,createdAt,redactedAt
            ) VALUES (?,?,1,0,'cow:a','content://fixture',?,1,1,?,NULL)
            """,
        arguments: [discussionTurnID, discussionID, p1f1HashA, p1f1Epoch]
    )
    let eventID = try p1f1InsertDomainEvent(
        suffix,
        campID: legacy.campID,
        in: database
    )
    return P1F1EngineGraph(
        legacy: legacy,
        profileID: profileID,
        runID: runID,
        sessionID: sessionID,
        executionID: executionID,
        proposalID: proposalID,
        proposalArtifactID: proposalArtifactID,
        discussionID: discussionID,
        discussionTurnID: discussionTurnID,
        eventID: eventID
    )
}

private func p1f1EnterFinalizing(
    _ graph: P1F1EngineGraph,
    in database: Database
) throws {
    let workID = "p1f1-deletion-work-\(graph.legacy.campID)"
    try database.execute(
        sql: """
            INSERT INTO durable_work(
              id,campId,campLifecycleVersion,kind,aggregateType,aggregateId,
              idempotencyKey,state,attempt,maxAttempts,notBefore,leaseOwner,
              leaseExpiresAt,inputJson,inputHash,outputJson,errorCode,
              errorMessage,traceId,version,createdAt,updatedAt,finishedAt
            ) VALUES (?, ?,1,'campDeletion','camp',?,?,'queued',0,4,NULL,NULL,
              NULL,'{}',?,NULL,NULL,NULL,?,1,?,?,NULL)
            """,
        arguments: [
            workID, graph.legacy.campID, graph.legacy.campID,
            "p1f1-delete-idem-\(graph.legacy.campID)", p1f1HashA,
            "trace:delete:\(graph.legacy.campID)", p1f1Epoch, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO camp_deletion_job(
              id,campId,workId,requestIdempotencyKey,confirmationId,
              confirmationHash,unknownArtifactDisposition,requestedByActorId,
              state,phaseCursorJson,lastErrorCode,version,createdAt,updatedAt,
              completedAt
            ) VALUES (?, ?,?,?,?,?,'detachOnlyNeverUnlink','user:test',
              'finalizing','{}',NULL,1,?,?,NULL)
            """,
        arguments: [
            "p1f1-deletion-job-\(graph.legacy.campID)", graph.legacy.campID,
            workID, "request:\(graph.legacy.campID)",
            "confirmation:\(graph.legacy.campID)", p1f1HashB,
            p1f1Epoch, p1f1Epoch,
        ]
    )
    try database.execute(
        sql: """
            UPDATE camp_lifecycle
            SET state='deleting',version=version+1,updatedAt=?,
                deletionRequestedAt=?
            WHERE campId=?
            """,
        arguments: [p1f1Epoch, p1f1Epoch, graph.legacy.campID]
    )
}

private func p1f1ExpectCheckpointAndHealth(_ queue: DatabaseQueue) throws {
    try queue.read { database in
        let checkpoint = try p1f1SchemaCheckpoint(database)
        #expect(checkpoint.tables == 79)
        #expect(checkpoint.indexes == 208)
        #expect(checkpoint.triggers == 84)
        #expect(try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier=?",
            arguments: [p1f1V17Migration]
        ) == 1)
        try p1f1ExpectHealthyDatabase(database)
    }
}

@Suite(.serialized)
struct P1F1SQLiteMigrationCompatibilityTests {
    @Test func p1f1_001V17CanonicalLiteralMatchesStageAuthority() throws {
        let authority = try p1f1StageV17SQL()
        let runtime = p1F1EngineCoordinationMigrationSQL
        #expect(runtime == authority)
        #expect(Data(runtime.utf8).count == 29_934)
        let newlineCount = runtime.reduce(into: 0) { count, character in
            if character == Character("\n") {
                count += 1
            }
        }
        let nonblankCount = runtime
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter {
                !$0.trimmingCharacters(
                    in: CharacterSet.whitespaces
                ).isEmpty
            }
            .count
        #expect(newlineCount == 770)
        #expect(nonblankCount == 757)
        #expect(p1f1SHA256(runtime) == "a6ef8747ee3e8ffeb0856827f6cf8f858c681a70748cd373783ae1d23d2b4e99")
        let lines = runtime.split(separator: "\n").map(String.init)
        #expect(lines.filter { $0.hasPrefix("CREATE TABLE ") }.count == 12)
        #expect(lines.filter {
            $0.hasPrefix("CREATE INDEX ") || $0.hasPrefix("CREATE UNIQUE INDEX ")
        }.count == 15)
        #expect(lines.filter { $0.hasPrefix("CREATE TRIGGER ") }.count == 17)
        #expect(runtime.components(
            separatedBy: "CREATE TRIGGER engine_session_first_redaction_exact"
        ).count - 1 == 1)
    }

    @Test func p1f1_002V17FreshAndEveryPredecessorReplayToExactCheckpoint() throws {
        let fixtures: [(String, String?, Bool)] = [
            ("fresh", nil, false),
            ("v7", "v7", false),
            ("v8", "v8-coding-ranch", false),
            ("v9", "v9-evercamp", false),
            ("v10", "v10-runtime-profiles", false),
            ("v11", "v11-cli-kinds", false),
            ("v12-durable", "v12-p1-durable-work", false),
            ("v12-schedule", "v12-p1-schedule-fire", false),
            ("v13", "v13-p1-observability", false),
            ("v14", "v14-p1-control-contracts", false),
            ("v15-empty", "v15-p1-outcome-contracts", false),
            ("v15-populated", "v15-p1-outcome-contracts", true),
            ("v16", p1f1V16Migration, false),
            ("v17-replay", p1f1V17Migration, false),
        ]
        for (label, predecessor, populated) in fixtures {
            let queue = try p1f1Queue("replay-\(label)")
            if let predecessor {
                try AppDatabase.migrator.migrate(queue, upTo: predecessor)
            }
            if populated {
                try queue.write { database in
                    _ = try p1f1InsertLegacyArtifactGraph(
                        "replay-populated",
                        path: "/missing/replay-populated.bin",
                        in: database
                    )
                }
            }
            try p1f1MigrateToV17(queue)
            let first = try queue.read(p1f1LogicalSnapshot)
            try p1f1MigrateToV17(queue)
            let replay = try queue.read(p1f1LogicalSnapshot)
            #expect(replay == first, Comment(rawValue: label))
            try p1f1ExpectCheckpointAndHealth(queue)
        }
    }

    @Test func p1f1_003V17LegacyArtifactsBackfillUnresolvedWithoutFilesystem() throws {
        let queue = try p1f1Queue("legacy-no-filesystem")
        try p1f1MigrateToV16(queue)
        let path = "/definitely/missing/managed/sha256/not-real"
        let graph = try queue.write { database in
            try p1f1InsertLegacyArtifactGraph("missing", path: path, in: database)
        }
        try p1f1MigrateToV17(queue)
        try queue.read { database in
            let row = try #require(try Row.fetchOne(
                database,
                sql: "SELECT * FROM artifact_storage_origin WHERE artifactId=?",
                arguments: [graph.artifactID]
            ))
            #expect(row["campId"] as String == graph.campID)
            #expect(row["state"] as String == "active")
            #expect(row["storageClass"] as String == "unresolved")
            #expect(row["evidenceKind"] as String == "legacyUnknown")
            #expect(row["originalRefHash"] as String == "5f922f02d8f9f71dde34a22e03d7d534a435c21526b5eaeb6e7d7167f18aac8d")
            #expect(row["managedRootId"] as String? == nil)
            #expect(row["objectId"] as String? == nil)
            #expect(row["contentHash"] as String? == nil)
            #expect(row["fileIdentityHash"] as String? == nil)
        }
    }

    @Test func p1f1_004V17LegacyOriginCountCampAndAttestationHashes() throws {
        let queue = try p1f1Queue("legacy-hashes")
        try AppDatabase.migrator.migrate(queue, upTo: "v15-p1-outcome-contracts")
        let a = try queue.write { database in
            try p1f1InsertLegacyArtifactGraph(
                "a",
                path: "/tmp/p1f1-a/../managed-looking/object-a.bin",
                createdAt: p1f1Epoch,
                in: database
            )
        }
        let b = try queue.write { database in
            try p1f1InsertLegacyArtifactGraph(
                "b",
                path: "/Volumes/External Workspace/object-b.txt",
                createdAt: p1f1Epoch.addingTimeInterval(10),
                in: database
            )
        }
        try p1f1MigrateToV17(queue)
        try queue.read { database in
            #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM artifact") == 2)
            #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM artifact_storage_origin") == 2)
            let rows = try Row.fetchAll(
                database,
                sql: "SELECT * FROM artifact_storage_origin ORDER BY artifactId"
            )
            let first = rows[0]
            let second = rows[1]
            #expect(first["artifactId"] as String == a.artifactID)
            #expect(first["campId"] as String == a.campID)
            #expect(first["classifiedAt"] as Date == a.createdAt)
            #expect(first["originalRefHash"] as String == "17fd5702c4ac714caeb1637b5e786e238b35895ab9d4eb668b230db5523231ef")
            #expect(first["classificationEvidenceHash"] as String == "0cdacb743b2ba8446668577d09a9d2dc42a98b2cc101f77b0d3673881f472d44")
            #expect(second["artifactId"] as String == b.artifactID)
            #expect(second["campId"] as String == b.campID)
            #expect(second["classifiedAt"] as Date == b.createdAt)
            #expect(second["originalRefHash"] as String == "9d41e1585cf74015416bae7ec30f9f7f1d42b950527f2f5e7e1320574bddbc49")
            #expect(second["classificationEvidenceHash"] as String == "e278b962d042cce66cf61c5a999b4d70065bdf547925e536e4a1ce463f45ec1b")
            for row in rows {
                #expect(row["state"] as String == "active")
                #expect(row["storageClass"] as String == "unresolved")
                #expect(row["evidenceKind"] as String == "legacyUnknown")
                #expect(row["managedRootId"] as String? == nil)
                #expect(row["objectId"] as String? == nil)
                #expect(row["contentHash"] as String? == nil)
                #expect(row["fileIdentityHash"] as String? == nil)
                #expect(row["terminalDisposition"] as String? == nil)
                #expect(row["terminalAuthorityHash"] as String? == nil)
                #expect(row["redactedAt"] as Date? == nil)
                #expect(row["version"] as Int == 1)
            }
        }
    }

    @Test func p1f1_005V17BackfillPhaseBarrierFailureRollsBack() throws {
        let queue = try p1f1Queue("barrier-rollback", foreignKeysEnabled: false)
        try p1f1MigrateToV16(queue)
        try queue.write { database in
            try database.execute(
                sql: """
                    INSERT INTO artifact(id,cardId,path,kind,label,createdAt)
                    VALUES ('p1f1-dangling-artifact','missing-card','/missing','file','dangling',?)
                    """,
                arguments: [p1f1Epoch]
            )
        }
        let before = try queue.read(p1f1LogicalSnapshot)
        do {
            try p1f1MigrateToV17(queue)
            throw P1F1SQLiteTestError.expectedFailure("dangling legacy artifact")
        } catch is P1F1MigrationIntegrityError {
            // The typed barrier error is the contract.
        } catch {
            throw P1F1SQLiteTestError.wrongMigrationError(String(describing: error))
        }
        let after = try queue.read(p1f1LogicalSnapshot)
        #expect(after == before)
        try queue.read { database in
            let migrationCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier=?",
                arguments: [p1f1V17Migration]
            )
            let tableCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='engine_session'"
            )
            let triggerCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name LIKE 'engine_%'"
            )
            #expect(migrationCount == 0)
            #expect(tableCount == 0)
            #expect(triggerCount == 0)
        }
    }

    @Test func p1f1_006V17EngineExecutionConstraintMatrix() throws {
        let queue = try p1f1Queue("execution-checks")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("execution-checks", in: database)
        }
        try queue.write { database in
            let failures = [
                "UPDATE engine_execution SET requestHash='x' WHERE id=?",
                "UPDATE engine_execution SET contextHash='x' WHERE id=?",
                "UPDATE engine_execution SET sessionScopeHash='x' WHERE id=?",
                "UPDATE engine_execution SET terminalReceiptHash='A234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' WHERE id=?",
                "UPDATE engine_execution SET replayClass='unsafe' WHERE id=?",
                "UPDATE engine_execution SET nextSequence=-1 WHERE id=?",
                "UPDATE engine_execution SET inputTokens=-1 WHERE id=?",
                "UPDATE engine_execution SET outputTokens=-1 WHERE id=?",
                "UPDATE engine_execution SET cacheReadTokens=-1 WHERE id=?",
                "UPDATE engine_execution SET costMicros=-1 WHERE id=?",
                "UPDATE engine_execution SET version=0 WHERE id=?",
                "UPDATE engine_execution SET state='running' WHERE id=?",
                "UPDATE engine_execution SET dispatchState='prepared' WHERE id=?",
                "UPDATE engine_execution SET terminalSubtype='ordinary' WHERE id=?",
                "UPDATE engine_execution SET dispatchStartedAt=NULL WHERE id=?",
                "UPDATE engine_execution SET cancellationRequestedAt=?,cancellationReason=NULL WHERE id=?",
                "UPDATE engine_execution SET sessionId=NULL,dispatchState='sessionBound' WHERE id=?",
                "UPDATE engine_execution SET campId='missing-camp' WHERE id=?",
            ]
            for (ordinal, sql) in failures.enumerated() {
                let arguments: StatementArguments = sql.contains("cancellationRequestedAt")
                    ? [p1f1Epoch, graph.executionID]
                    : [graph.executionID]
                _ = try p1f1ExpectDatabaseFailure("execution \(ordinal)") {
                    try database.execute(sql: sql, arguments: arguments)
                }
            }
            _ = try p1f1ExpectDatabaseFailure("redaction without finalizing") {
                try database.execute(
                    sql: """
                        UPDATE engine_execution
                        SET requestJson='{}',contextJson='{}',sessionScopeJson='{}',
                            version=version+1,updatedAt=?,redactedAt=?
                        WHERE id=?
                        """,
                    arguments: [p1f1Epoch, p1f1Epoch, graph.executionID]
                )
            }
        }
    }

    @Test func p1f1_007V17EngineSessionProposalAndArtifactConstraintMatrix() throws {
        let queue = try p1f1Queue("session-proposal-checks")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("session-proposal-checks", in: database)
        }
        try queue.write { database in
            let statements: [(String, StatementArguments)] = [
                ("UPDATE engine_session SET workspaceHash='x' WHERE id=?", [graph.sessionID]),
                ("UPDATE engine_session SET state='active',externalSessionId=NULL WHERE id=?", [graph.sessionID]),
                ("UPDATE engine_session SET state='unknown' WHERE id=?", [graph.sessionID]),
                ("UPDATE engine_session SET version=0 WHERE id=?", [graph.sessionID]),
                ("INSERT INTO engine_session SELECT ? || '-duplicate',campId,adapterId,adapterVersion,profileId,externalSessionId,workspaceHash,sessionScopeJson,sessionScopeHash,state,version,createdAt,updatedAt,redactedAt FROM engine_session WHERE id=?", [graph.sessionID, graph.sessionID]),
                ("UPDATE engine_terminal_proposal SET sequence=-1 WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_terminal_proposal SET terminalKind='blocked',terminalSubtype=NULL WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_terminal_proposal SET terminalKind='completed',terminalSubtype='ordinary' WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_terminal_proposal SET proposalHash='x' WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_terminal_proposal SET state='pending' WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_terminal_proposal SET state='invalid',invalidReason=NULL,invalidatedAt=NULL,committedAt=NULL WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_terminal_proposal SET version=0 WHERE id=?", [graph.proposalID]),
                ("UPDATE engine_proposal_artifact SET ordinal=-1 WHERE id=?", [graph.proposalArtifactID]),
                ("UPDATE engine_proposal_artifact SET contentHash='x' WHERE id=?", [graph.proposalArtifactID]),
                ("UPDATE engine_proposal_artifact SET state='declared' WHERE id=?", [graph.proposalArtifactID]),
                ("UPDATE engine_proposal_artifact SET version=0 WHERE id=?", [graph.proposalArtifactID]),
                ("INSERT INTO engine_proposal_artifact SELECT ? || '-duplicate-artifact',proposalId,artifactId,ordinal+1,sourceRelativePath,kind,label,byteCount,contentHash,state,preparedAt,version,redactedAt FROM engine_proposal_artifact WHERE id=?", [graph.proposalArtifactID, graph.proposalArtifactID]),
                ("INSERT INTO engine_proposal_artifact SELECT ? || '-duplicate-ordinal',proposalId,artifactId || '-other',ordinal,sourceRelativePath,kind,label,byteCount,contentHash,state,preparedAt,version,redactedAt FROM engine_proposal_artifact WHERE id=?", [graph.proposalArtifactID, graph.proposalArtifactID]),
            ]
            for (ordinal, entry) in statements.enumerated() {
                _ = try p1f1ExpectDatabaseFailure("session/proposal \(ordinal)") {
                    try database.execute(sql: entry.0, arguments: entry.1)
                }
            }
        }
    }

    @Test func p1f1_008V17OriginConstraintAndRedactionMatrix() throws {
        let queue = try p1f1Queue("origin-checks")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("origin-checks", in: database)
        }
        try queue.write { database in
            for suffix in [
                "external-active", "unresolved-active", "managed-deleted",
                "external-deleted", "unresolved-deleted", "bad-origin-1",
                "bad-origin-2", "bad-origin-3",
            ] {
                try ArtifactRecord(
                    id: "p1f1-origin-\(suffix)",
                    cardId: graph.legacy.cardID,
                    path: "/tmp/\(suffix)",
                    kind: "file",
                    label: suffix,
                    createdAt: p1f1Epoch
                ).insert(database)
            }
            try database.execute(
                sql: """
                    INSERT INTO artifact_storage_origin VALUES
                    ('p1f1-origin-external-active',?,'active','workspaceExternal','explicitWorkspaceExternal',NULL,NULL,NULL,NULL,?,?,NULL,NULL,1,?,NULL),
                    ('p1f1-origin-unresolved-active',?,'active','unresolved','legacyUnknown',NULL,NULL,NULL,NULL,?,?,NULL,NULL,1,?,NULL),
                    ('p1f1-origin-managed-deleted',?,'tombstoned','managed','typedPreparedArtifact',NULL,NULL,?,?,?,?,'managedDeleted',?,2,?,?),
                    ('p1f1-origin-external-deleted',?,'tombstoned','workspaceExternal','verifiedOutsideAllManagedRoots',NULL,NULL,NULL,NULL,?,?,'workspaceExternalDetached',?,2,?,?),
                    ('p1f1-origin-unresolved-deleted',?,'tombstoned','unresolved','legacyUnknown',NULL,NULL,NULL,NULL,?,?,'unresolvedDetached',?,2,?,?)
                    """,
                arguments: [
                    graph.legacy.campID, p1f1HashA, p1f1HashB, p1f1Epoch,
                    graph.legacy.campID, p1f1HashA, p1f1HashB, p1f1Epoch,
                    graph.legacy.campID, p1f1HashA, p1f1HashB, p1f1HashC,
                    p1f1HashD, p1f1HashA, p1f1Epoch, p1f1Epoch,
                    graph.legacy.campID, p1f1HashA, p1f1HashB, p1f1HashC,
                    p1f1Epoch, p1f1Epoch,
                    graph.legacy.campID, p1f1HashA, p1f1HashB, p1f1HashC,
                    p1f1Epoch, p1f1Epoch,
                ]
            )
            #expect(try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM artifact_storage_origin") == 6)
            let invalidSQL = [
                "INSERT INTO artifact_storage_origin(artifactId,campId,state,storageClass,evidenceKind,originalRefHash,classificationEvidenceHash,version,classifiedAt) VALUES ('p1f1-origin-bad-origin-1',?,'active','managed','legacyUnknown',?,?,1,?)",
                "INSERT INTO artifact_storage_origin(artifactId,campId,state,storageClass,evidenceKind,originalRefHash,classificationEvidenceHash,version,classifiedAt) VALUES ('p1f1-origin-bad-origin-2',?,'active','workspaceExternal','legacyUnknown',?,?,1,?)",
                "INSERT INTO artifact_storage_origin(artifactId,campId,state,storageClass,evidenceKind,originalRefHash,classificationEvidenceHash,version,classifiedAt) VALUES ('p1f1-origin-bad-origin-3',?,'tombstoned','unresolved','legacyUnknown',?,?,1,?)",
            ]
            for (ordinal, sql) in invalidSQL.enumerated() {
                let error = try p1f1ExpectDatabaseFailure(
                    "origin shape \(ordinal)"
                ) {
                    try database.execute(
                        sql: sql,
                        arguments: [graph.legacy.campID, p1f1HashA, p1f1HashB, p1f1Epoch]
                    )
                }
                #expect(
                    String(describing: error).contains(
                        "CHECK constraint failed"
                    )
                )
            }
            _ = try p1f1ExpectDatabaseFailure("origin nonfinalizing redaction") {
                try database.execute(
                    sql: """
                        UPDATE artifact_storage_origin
                        SET state='tombstoned',managedRootId=NULL,objectId=NULL,
                            terminalDisposition='managedDeleted',terminalAuthorityHash=?,
                            version=version+1,redactedAt=? WHERE artifactId=?
                        """,
                    arguments: [p1f1HashD, p1f1Epoch, graph.legacy.artifactID]
                )
            }
            try p1f1EnterFinalizing(graph, in: database)
            _ = try p1f1ExpectDatabaseFailure("origin wrong first redaction") {
                try database.execute(
                    sql: """
                        UPDATE artifact_storage_origin
                        SET state='tombstoned',managedRootId=NULL,objectId=NULL,
                            terminalDisposition='workspaceExternalDetached',
                            terminalAuthorityHash=?,version=version+1,redactedAt=?
                        WHERE artifactId=?
                        """,
                    arguments: [p1f1HashD, p1f1Epoch, graph.legacy.artifactID]
                )
            }
            try database.execute(
                sql: """
                    UPDATE artifact_storage_origin
                    SET state='tombstoned',managedRootId=NULL,objectId=NULL,
                        terminalDisposition='managedDeleted',terminalAuthorityHash=?,
                        version=version+1,redactedAt=? WHERE artifactId=?
                    """,
                arguments: [p1f1HashD, p1f1Epoch, graph.legacy.artifactID]
            )
            _ = try p1f1ExpectDatabaseFailure("origin second redaction") {
                try database.execute(
                    sql: "UPDATE artifact_storage_origin SET artifactId=artifactId WHERE artifactId=?",
                    arguments: [graph.legacy.artifactID]
                )
            }
        }
    }

    @Test func p1f1_009V17DiscussionAttentionGrowthConstraintMatrix() throws {
        let queue = try p1f1Queue("coordination-checks")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("coordination-checks", in: database)
        }
        try queue.write { database in
            let discussionFailures = [
                "UPDATE discussion SET goalId=NULL,missionId=NULL,cardId=NULL WHERE id=?",
                "UPDATE discussion SET maxRounds=0 WHERE id=?",
                "UPDATE discussion SET maxRounds=4 WHERE id=?",
                "UPDATE discussion SET tokenBudget=0 WHERE id=?",
                "UPDATE discussion SET spentTokens=tokenBudget+1 WHERE id=?",
                "UPDATE discussion SET status='unknown' WHERE id=?",
                "UPDATE discussion SET status='completed' WHERE id=?",
                "UPDATE discussion SET materializationType='outcome',materializationId='x' WHERE id=?",
            ]
            for (ordinal, sql) in discussionFailures.enumerated() {
                _ = try p1f1ExpectDatabaseFailure("discussion \(ordinal)") {
                    try database.execute(sql: sql, arguments: [graph.discussionID])
                }
            }
            try database.execute(
                sql: """
                    INSERT INTO attention_item(
                      id,sourceEventId,level,dedupeKey,status,campId,goalId,
                      missionId,dueAt,escalationAt,aggregateVersion,createdAt,updatedAt
                    ) VALUES ('p1f1-attention',?,'needsAction','dedupe:one','open',?,
                      NULL,?,NULL,NULL,1,?,?)
                    """,
                arguments: [
                    graph.eventID, graph.legacy.campID, graph.legacy.missionID,
                    p1f1Epoch, p1f1Epoch,
                ]
            )
            for (label, sql) in [
                ("level", "UPDATE attention_item SET level='alarm' WHERE id='p1f1-attention'"),
                ("status", "UPDATE attention_item SET status='gone' WHERE id='p1f1-attention'"),
                ("dedupe", "INSERT INTO attention_item SELECT 'p1f1-attention-2',sourceEventId,level,dedupeKey,status,campId,goalId,missionId,dueAt,escalationAt,aggregateVersion,createdAt,updatedAt FROM attention_item WHERE id='p1f1-attention'"),
            ] {
                _ = try p1f1ExpectDatabaseFailure("attention \(label)") {
                    try database.execute(sql: sql)
                }
            }
            try database.execute(
                sql: """
                    INSERT INTO growth_evidence(
                      id,campId,track,subjectType,subjectId,outcomeId,outcomeVersion,
                      verificationId,acceptanceId,sourceEventId,evidenceHash,status,
                      invalidatedByEventId,createdAt,invalidatedAt
                    ) VALUES ('p1f1-growth-relationship',?,'relationship','cow','cow:a',
                      NULL,NULL,NULL,NULL,?,?, 'active',NULL,?,NULL)
                    """,
                arguments: [graph.legacy.campID, graph.eventID, p1f1HashA, p1f1Epoch]
            )
            try database.execute(
                sql: """
                    INSERT INTO growth_evidence(
                      id,campId,track,subjectType,subjectId,outcomeId,outcomeVersion,
                      verificationId,acceptanceId,sourceEventId,evidenceHash,status,
                      invalidatedByEventId,createdAt,invalidatedAt
                    ) VALUES ('p1f1-growth-world',?,'world','world','world:test',
                      NULL,NULL,NULL,NULL,?,?, 'proposed',NULL,?,NULL)
                    """,
                arguments: [graph.legacy.campID, graph.eventID, p1f1HashB, p1f1Epoch]
            )
            _ = try p1f1ExpectDatabaseFailure("growth capability missing evidence graph") {
                try database.execute(
                    sql: """
                        INSERT INTO growth_evidence(
                          id,campId,track,subjectType,subjectId,evidenceHash,status,createdAt
                        ) VALUES ('p1f1-growth-bad-capability',?,'capability','cow','cow:a',
                          ?,'active',?)
                        """,
                    arguments: [graph.legacy.campID, p1f1HashC, p1f1Epoch]
                )
            }
            _ = try p1f1ExpectDatabaseFailure("growth relationship missing event") {
                try database.execute(
                    sql: """
                        INSERT INTO growth_evidence(
                          id,campId,track,subjectType,subjectId,sourceEventId,
                          evidenceHash,status,createdAt
                        ) VALUES ('p1f1-growth-bad-event',?,'relationship','cow','cow:a',
                          'missing-event',?,'active',?)
                        """,
                    arguments: [graph.legacy.campID, p1f1HashC, p1f1Epoch]
                )
            }
            try database.execute(
                sql: """
                    UPDATE growth_evidence
                    SET status='invalidated',invalidatedByEventId=?,invalidatedAt=?
                    WHERE id='p1f1-growth-relationship'
                    """,
                arguments: [graph.eventID, p1f1Epoch]
            )
            _ = try p1f1ExpectDatabaseFailure("growth invalidation shape") {
                try database.execute(
                    sql: """
                        UPDATE growth_evidence
                        SET invalidatedByEventId=NULL
                        WHERE id='p1f1-growth-relationship'
                        """
                )
            }
        }

        let capability = try p1dOutcomeFixture(
            "p1f1-growth-capability",
            missionStatus: .delivering
        )
        let capabilityOutcomeID =
            "81000000-0000-4000-8000-000000000001"
        let capabilityArtifactURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "p1f1-growth-capability-\(UUID().uuidString).bin"
            )
        let capabilityArtifactBytes = Data("p1f1-growth".utf8)
        try capabilityArtifactBytes.write(to: capabilityArtifactURL)
        defer { try? FileManager.default.removeItem(at: capabilityArtifactURL) }
        let initial = try p1dRecordInitial(
            capability,
            outcomeId: capabilityOutcomeID,
            key: "p1f1:growth:initial",
            manifest: p1dManifest(
                path: capabilityArtifactURL.path,
                hash: CanonicalJSONV1.sha256Hex(capabilityArtifactBytes)
            )
        )
        let pending = try p1dBeginVerification(
            capability,
            outcome: initial,
            key: "p1f1:growth:begin"
        )
        let verificationID = "81000000-0000-4000-8000-000000000002"
        _ = try p1dRecordVerification(
            capability,
            outcome: pending,
            recordId: verificationID,
            key: "p1f1:growth:verify"
        )
        let verified = try p1dRequireOutcome(
            capability,
            id: capabilityOutcomeID
        )
        let delivered = try capability.store.markDelivered(
            MarkDeliveredCommandV1(
                envelope: p1dSystemEnvelope(
                    "p1f1:growth:deliver",
                    actorId: P1DActorID.delivery
                ),
                outcome: verified.currentRef,
                expectedAggregateVersion: verified.aggregateVersion
            )
        )
        let acceptanceID = "81000000-0000-4000-8000-000000000003"
        let accepted = try capability.store.acceptOutcome(
            AcceptOutcomeCommandV1(
                envelope: p1dUserEnvelope(
                    "p1f1:growth:accept"
                ),
                acceptanceId: acceptanceID,
                outcome: delivered.currentRef,
                expectedOutcomeAggregateVersion: delivered.aggregateVersion,
                subject: .user(P1DActorID.localOwner),
                reason: "P1-F1 capability accepted"
            )
        )
        try capability.base.database.pool.write { database in
            let invalidatingEventID = try #require(try String.fetchOne(
                database,
                sql: """
                    SELECT id FROM domain_event WHERE campId=?
                    ORDER BY recordedAt DESC,rowid DESC LIMIT 1
                    """,
                arguments: [capability.base.camp.id]
            ))
            try database.execute(
                sql: """
                    INSERT INTO growth_evidence(
                      id,campId,track,subjectType,subjectId,outcomeId,outcomeVersion,
                      verificationId,acceptanceId,sourceEventId,evidenceHash,status,
                      invalidatedByEventId,createdAt,invalidatedAt
                    ) VALUES ('p1f1-growth-capability',?,'capability','cow','cow:a',
                      ?,?,?,?,NULL,?,'active',NULL,?,NULL)
                    """,
                arguments: [
                    capability.base.camp.id, accepted.outcome.id,
                    accepted.outcome.currentVersion, verificationID,
                    acceptanceID, p1f1HashD, p1f1Epoch,
                ]
            )
            _ = try p1f1ExpectDatabaseFailure("capability acceptance FK") {
                try database.execute(
                    sql: """
                        INSERT INTO growth_evidence(
                          id,campId,track,subjectType,subjectId,outcomeId,
                          outcomeVersion,verificationId,acceptanceId,evidenceHash,
                          status,createdAt
                        ) VALUES ('p1f1-growth-bad-acceptance',?,'capability',
                          'cow','cow:a',?,?,?,'missing-acceptance',?,'active',?)
                        """,
                    arguments: [
                        capability.base.camp.id, accepted.outcome.id,
                        accepted.outcome.currentVersion, verificationID,
                        p1f1HashD, p1f1Epoch,
                    ]
                )
            }
            try database.execute(
                sql: """
                    UPDATE growth_evidence
                    SET status='invalidated',invalidatedByEventId=?,invalidatedAt=?
                    WHERE id='p1f1-growth-capability'
                    """,
                arguments: [invalidatingEventID, p1f1Epoch]
            )
            _ = try p1f1ExpectDatabaseFailure("capability invalidation event FK") {
                try database.execute(
                    sql: """
                        UPDATE growth_evidence
                        SET invalidatedByEventId='missing-event'
                        WHERE id='p1f1-growth-capability'
                        """
                )
            }
        }
    }

    @Test func p1f1_010V17ProposalArtifactRedactionGuardMatrix() throws {
        let queue = try p1f1Queue("proposal-redaction")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("proposal-redaction", in: database)
        }
        try queue.write { database in
            let exact = """
                UPDATE engine_proposal_artifact
                SET sourceRelativePath='',kind='tombstone',label='[deleted]',
                    redactedAt=? WHERE id=?
                """
            _ = try p1f1ExpectDatabaseFailure("proposal artifact nonfinalizing") {
                try database.execute(
                    sql: exact,
                    arguments: [p1f1Epoch, graph.proposalArtifactID]
                )
            }
            try p1f1EnterFinalizing(graph, in: database)
            _ = try p1f1ExpectDatabaseFailure("proposal artifact wrong tombstone") {
                try database.execute(
                    sql: "UPDATE engine_proposal_artifact SET sourceRelativePath='',kind='tombstone',label='wrong',redactedAt=? WHERE id=?",
                    arguments: [p1f1Epoch, graph.proposalArtifactID]
                )
            }
            try database.execute(
                sql: exact,
                arguments: [p1f1Epoch, graph.proposalArtifactID]
            )
            _ = try p1f1ExpectDatabaseFailure("proposal artifact second redaction") {
                try database.execute(
                    sql: "UPDATE engine_proposal_artifact SET id=id WHERE id=?",
                    arguments: [graph.proposalArtifactID]
                )
            }
            _ = try p1f1ExpectDatabaseFailure("proposal artifact delete") {
                try database.execute(
                    sql: "DELETE FROM engine_proposal_artifact WHERE id=?",
                    arguments: [graph.proposalArtifactID]
                )
            }
        }
    }

    @Test func p1f1_011V17DiscussionTurnRedactionGuardMatrix() throws {
        let queue = try p1f1Queue("turn-redaction")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("turn-redaction", in: database)
        }
        try queue.write { database in
            _ = try p1f1ExpectDatabaseFailure("turn wrong first redaction") {
                try database.execute(
                    sql: "UPDATE discussion_turn SET contentRef='wrong',redactedAt=? WHERE id=?",
                    arguments: [p1f1Epoch, graph.discussionTurnID]
                )
            }
            _ = try p1f1ExpectDatabaseFailure("turn nonfinalizing") {
                try database.execute(
                    sql: "UPDATE discussion_turn SET contentRef='',redactedAt=? WHERE id=?",
                    arguments: [p1f1Epoch, graph.discussionTurnID]
                )
            }
            try p1f1EnterFinalizing(graph, in: database)
            try database.execute(
                sql: "UPDATE discussion_turn SET contentRef='',redactedAt=? WHERE id=?",
                arguments: [p1f1Epoch, graph.discussionTurnID]
            )
            _ = try p1f1ExpectDatabaseFailure("turn second no-op") {
                try database.execute(
                    sql: "UPDATE discussion_turn SET id=id WHERE id=?",
                    arguments: [graph.discussionTurnID]
                )
            }
            _ = try p1f1ExpectDatabaseFailure("turn extra update") {
                try database.execute(
                    sql: "UPDATE discussion_turn SET outputTokens=outputTokens+1 WHERE id=?",
                    arguments: [graph.discussionTurnID]
                )
            }
            _ = try p1f1ExpectDatabaseFailure("turn delete") {
                try database.execute(
                    sql: "DELETE FROM discussion_turn WHERE id=?",
                    arguments: [graph.discussionTurnID]
                )
            }
        }
    }

    @Test func p1f1_012V17RejectDeleteAndAppendOnlyGuardMatrix() throws {
        let queue = try p1f1Queue("append-only")
        try p1f1MigrateToV17(queue)
        let graph = try queue.write { database in
            try p1f1InsertEngineGraph("append-only", in: database)
        }
        try queue.write { database in
            let triggers = Set(try String.fetchAll(
                database,
                sql: "SELECT name FROM sqlite_master WHERE type='trigger'"
            ))
            #expect(Set(p1f1TriggerNames).isSubset(of: triggers))
            #expect(p1f1TriggerNames.count == 17)
            let deletes: [(String, String, String)] = [
                ("engine_session", "id", graph.sessionID),
                ("engine_execution", "id", graph.executionID),
                ("engine_terminal_proposal", "id", graph.proposalID),
                ("engine_proposal_artifact", "id", graph.proposalArtifactID),
                ("artifact_storage_origin", "artifactId", graph.legacy.artifactID),
                ("discussion_turn", "id", graph.discussionTurnID),
            ]
            for (table, key, value) in deletes {
                _ = try p1f1ExpectDatabaseFailure("delete \(table)") {
                    try database.execute(
                        sql: "DELETE FROM \(p1f1QuotedIdentifier(table)) WHERE \(p1f1QuotedIdentifier(key))=?",
                        arguments: [value]
                    )
                }
            }
            try p1f1EnterFinalizing(graph, in: database)
            try database.execute(
                sql: """
                    UPDATE engine_session
                    SET externalSessionId=NULL,sessionScopeJson='{}',state='invalid',
                        version=version+1,updatedAt=?,redactedAt=? WHERE id=?
                    """,
                arguments: [p1f1Epoch, p1f1Epoch, graph.sessionID]
            )
            _ = try p1f1ExpectDatabaseFailure("session post-redaction no-op") {
                try database.execute(
                    sql: "UPDATE engine_session SET id=id WHERE id=?",
                    arguments: [graph.sessionID]
                )
            }
        }
    }

    @Test func p1f1_013V17ProposalBlobCleanupGraphForeignKeys() throws {
        let queue = try p1f1Queue("foreign-keys")
        try p1f1MigrateToV17(queue)
        try queue.read { database in
            func foreignKeys(_ table: String) throws -> [Row] {
                try Row.fetchAll(
                    database,
                    sql: "SELECT * FROM pragma_foreign_key_list(?)",
                    arguments: [table]
                )
            }
            let expectedTargets: [String: Set<String>] = [
                "engine_session": ["camp", "runtime_profile"],
                "engine_execution": ["camp", "run", "card", "runtime_profile", "engine_session", "domain_command_receipt"],
                "engine_terminal_proposal": ["engine_execution"],
                "engine_proposal_artifact": ["engine_terminal_proposal"],
                "camp_deletion_proposal_blob": ["camp_deletion_job", "camp", "engine_proposal_artifact"],
                "artifact_blob_reference": ["artifact", "engine_proposal_artifact", "engine_execution", "camp", "artifact_blob"],
                "artifact_storage_origin": ["artifact", "camp"],
                "discussion": ["camp", "goal_controller", "mission", "card"],
                "discussion_turn": ["discussion"],
                "attention_item": ["domain_event", "camp", "goal_controller", "mission"],
                "growth_evidence": ["camp", "outcome", "verification_record", "acceptance_record", "domain_event"],
            ]
            for (table, expected) in expectedTargets {
                let rows = try foreignKeys(table)
                let actual = Set(rows.map { $0["table"] as String })
                #expect(actual == expected, Comment(rawValue: table))
                for row in rows {
                    #expect((row["on_delete"] as String).uppercased() == "RESTRICT")
                }
            }
            let proposalFields = Set(try foreignKeys("engine_proposal_artifact").map {
                $0["from"] as String
            })
            let deletionFields = Set(try foreignKeys("camp_deletion_proposal_blob").map {
                $0["from"] as String
            })
            let referenceFields = Set(try foreignKeys("artifact_blob_reference").map {
                $0["from"] as String
            })
            #expect(!proposalFields.contains("contentHash"))
            #expect(!deletionFields.contains("contentHash"))
            #expect(referenceFields.contains("contentHash"))
            try p1f1ExpectHealthyDatabase(database)
        }
    }

    @Test func p1f1_014V17TriggerOrdinalFailureRollsBackV16Snapshot() throws {
        for (ordinal, trigger) in p1f1TriggerNames.enumerated() {
            let queue = try p1f1Queue("trigger-rollback-\(ordinal)")
            try p1f1MigrateToV16(queue)
            try queue.write { database in
                try database.execute(
                    sql: """
                        CREATE TRIGGER \(p1f1QuotedIdentifier(trigger))
                        BEFORE INSERT ON camp BEGIN SELECT 1; END
                        """
                )
            }
            let before = try queue.read(p1f1LogicalSnapshot)
            _ = try p1f1ExpectDatabaseFailure("trigger ordinal \(ordinal)") {
                try p1f1MigrateToV17(queue)
            }
            let after = try queue.read(p1f1LogicalSnapshot)
            #expect(after == before, Comment(rawValue: trigger))
            try queue.read { database in
                let migrationCount = try Int.fetchOne(
                    database,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier=?",
                    arguments: [p1f1V17Migration]
                )
                let tableCount = try Int.fetchOne(
                    database,
                    sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='engine_session'"
                )
                let triggerCount = try Int.fetchOne(
                    database,
                    sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name=?",
                    arguments: [trigger]
                )
                #expect(migrationCount == 0)
                #expect(tableCount == 0)
                #expect(triggerCount == 1)
            }
        }
    }

    @Test func p1f1_015V17RepeatedMigrateIsByteStable() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agentloop-p1f1-reopen-\(UUID().uuidString).sqlite"
        )
        let queue = try DatabaseQueue(path: url.path)
        try p1f1MigrateToV16(queue)
        try queue.write { database in
            _ = try p1f1InsertLegacyArtifactGraph(
                "reopen",
                path: "/tmp/reopen-artifact",
                in: database
            )
        }
        try p1f1MigrateToV17(queue)
        let first = try queue.read(p1f1LogicalSnapshot)
        try p1f1MigrateToV17(queue)
        let second = try queue.read(p1f1LogicalSnapshot)
        #expect(second == first)
        try queue.close()
        let reopened = try DatabaseQueue(path: url.path)
        try p1f1MigrateToV17(reopened)
        let third = try reopened.read(p1f1LogicalSnapshot)
        #expect(third == first)
        try reopened.read { database in
            let migrationCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier=?",
                arguments: [p1f1V17Migration]
            )
            let originCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM artifact_storage_origin"
            )
            #expect(migrationCount == 1)
            #expect(originCount == 1)
        }
    }

    @Test func p1f1_016V17DualSQLiteCarrierSentinels() throws {
        let lanes = [
            ("/usr/bin/sqlite3", "3.51.", "sqlite-351"),
            ("/opt/homebrew/opt/sqlite/bin/sqlite3", "3.52.", "sqlite-352"),
        ]
        for (sqlite, versionPrefix, label) in lanes {
            let version = try p1eRunProcess(executable: sqlite, arguments: ["--version"])
            #expect(version.status == 0)
            #expect(version.output.hasPrefix(versionPrefix))
            let temporaryPath = FileManager.default.temporaryDirectory.path
            let physicalTemporaryPath = temporaryPath.hasPrefix("/var/")
                ? "/private\(temporaryPath)"
                : temporaryPath
            let databaseURL = URL(
                fileURLWithPath: physicalTemporaryPath,
                isDirectory: true
            ).appendingPathComponent("agentloop-p1f1-literal-\(label)-\(UUID().uuidString).sqlite")
            let queue = try DatabaseQueue(path: databaseURL.path)
            try p1f1MigrateToV16(queue)
            try queue.close()
            let input = """
                .bail on
                PRAGMA foreign_keys=ON;
                BEGIN IMMEDIATE;
                \(p1F1EngineCoordinationMigrationSQL)
                COMMIT;
                SELECT
                  (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%')
                  || '/' ||
                  (SELECT COUNT(*) FROM sqlite_master WHERE type='index')
                  || '/' ||
                  (SELECT COUNT(*) FROM sqlite_master WHERE type='trigger');
                SELECT
                  (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN
                    ('engine_session','engine_execution','engine_terminal_proposal','artifact_blob',
                     'engine_proposal_artifact','camp_deletion_proposal_blob','artifact_blob_reference',
                     'artifact_storage_origin','discussion','discussion_turn','attention_item','growth_evidence'))
                  || '/' ||
                  (SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name IN
                    ('engine_session_external_identity','engine_session_resume','engine_execution_recovery',
                     'engine_execution_card','engine_terminal_proposal_pending','artifact_blob_path',
                     'artifact_blob_gc','engine_proposal_artifact_gc_root',
                     'camp_deletion_proposal_blob_recovery','artifact_blob_reference_live',
                     'artifact_blob_reference_camp','artifact_storage_origin_camp',
                     'discussion_turn_round','attention_item_open','growth_evidence_subject'))
                  || '/' ||
                  (SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name IN
                    ('engine_session_first_redaction_exact','engine_session_post_redaction_lock',
                     'engine_session_reject_delete','engine_execution_first_redaction_exact',
                     'engine_execution_post_redaction_lock','engine_execution_reject_delete',
                     'engine_terminal_proposal_first_redaction_exact',
                     'engine_terminal_proposal_post_redaction_lock',
                     'engine_terminal_proposal_reject_delete',
                     'engine_proposal_artifact_reject_private_field_update',
                     'engine_proposal_artifact_post_redaction_lock',
                     'engine_proposal_artifact_reject_delete',
                     'artifact_storage_origin_first_redaction_exact',
                     'artifact_storage_origin_post_redaction_lock',
                     'artifact_storage_origin_reject_delete',
                     'discussion_turn_reject_update_except_camp_redaction',
                     'discussion_turn_reject_delete'));
                PRAGMA foreign_key_check;
                PRAGMA integrity_check;
                """
            let result = try p1eRunProcess(
                executable: sqlite,
                arguments: [
                    "-init", "/dev/null", "-batch", "-bail", "-nofollow",
                    databaseURL.path,
                ],
                input: input
            )
            #expect(result.status == 0, Comment(rawValue: result.output))
            let lines = result.output.split(separator: "\n").map(String.init)
            #expect(lines.contains("79/208/84"), Comment(rawValue: label))
            #expect(lines.contains("12/15/17"), Comment(rawValue: label))
            #expect(lines.last == "ok", Comment(rawValue: label))
            #expect(!lines.contains { $0.contains("foreign key constraint failed") })
        }
    }
}
