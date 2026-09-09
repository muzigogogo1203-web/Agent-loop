import Darwin
import Foundation
import GRDB
import AgentLoopCore

private enum MatrixError: Error, CustomStringConvertible {
    case usage(String)
    case assertion(String)
    case expectedFailureDidNotOccur(String)

    var description: String {
        switch self {
        case let .usage(message):
            return "usage error: \(message)"
        case let .assertion(message):
            return "matrix assertion failed: \(message)"
        case let .expectedFailureDidNotOccur(message):
            return "expected failure did not occur: \(message)"
        }
    }
}

private struct Arguments {
    let expectedSQLiteVersion: String
    let fixtures: [Fixture]
    let literalSchema: URL
    let literalObservabilitySchema: URL
    let literalControlSchema: URL
    let literalOutcomeSchema: URL
    let literalIdentityMemorySchema: URL
    let literalEngineCoordinationSchema: URL
    let outputRoot: URL

    init(commandLine: [String]) throws {
        var expectedSQLiteVersion: String?
        var fixtureNames: String?
        var literalSchema: String?
        var literalObservabilitySchema: String?
        var literalControlSchema: String?
        var literalOutcomeSchema: String?
        var literalIdentityMemorySchema: String?
        var literalEngineCoordinationSchema: String?
        var outputRoot: String?
        var index = 1

        while index < commandLine.count {
            let argument = commandLine[index]
            guard index + 1 < commandLine.count else {
                throw MatrixError.usage("missing value for \(argument)")
            }
            let value = commandLine[index + 1]
            switch argument {
            case "--expected-sqlite-version":
                guard expectedSQLiteVersion == nil else {
                    throw MatrixError.usage(
                        "duplicate --expected-sqlite-version"
                    )
                }
                expectedSQLiteVersion = value
            case "--fixtures":
                guard fixtureNames == nil else {
                    throw MatrixError.usage("duplicate --fixtures")
                }
                fixtureNames = value
            case "--literal-schema":
                guard literalSchema == nil else {
                    throw MatrixError.usage("duplicate --literal-schema")
                }
                literalSchema = value
            case "--literal-observability-schema":
                guard literalObservabilitySchema == nil else {
                    throw MatrixError.usage(
                        "duplicate --literal-observability-schema"
                    )
                }
                literalObservabilitySchema = value
            case "--literal-control-schema":
                guard literalControlSchema == nil else {
                    throw MatrixError.usage(
                        "duplicate --literal-control-schema"
                    )
                }
                literalControlSchema = value
            case "--literal-outcome-schema":
                guard literalOutcomeSchema == nil else {
                    throw MatrixError.usage(
                        "duplicate --literal-outcome-schema"
                    )
                }
                literalOutcomeSchema = value
            case "--literal-identity-memory-schema":
                guard literalIdentityMemorySchema == nil else {
                    throw MatrixError.usage(
                        "duplicate --literal-identity-memory-schema"
                    )
                }
                literalIdentityMemorySchema = value
            case "--literal-engine-coordination-schema":
                guard literalEngineCoordinationSchema == nil else {
                    throw MatrixError.usage(
                        "duplicate --literal-engine-coordination-schema"
                    )
                }
                literalEngineCoordinationSchema = value
            case "--output-root":
                guard outputRoot == nil else {
                    throw MatrixError.usage("duplicate --output-root")
                }
                outputRoot = value
            default:
                throw MatrixError.usage("unknown argument \(argument)")
            }
            index += 2
        }

        guard let expectedSQLiteVersion,
              !expectedSQLiteVersion.isEmpty
        else {
            throw MatrixError.usage(
                "--expected-sqlite-version is required"
            )
        }
        guard let fixtureNames, !fixtureNames.isEmpty else {
            throw MatrixError.usage("--fixtures is required")
        }
        guard let literalSchema, !literalSchema.isEmpty else {
            throw MatrixError.usage("--literal-schema is required")
        }
        guard let literalObservabilitySchema,
              !literalObservabilitySchema.isEmpty
        else {
            throw MatrixError.usage(
                "--literal-observability-schema is required"
            )
        }
        guard let literalControlSchema,
              !literalControlSchema.isEmpty
        else {
            throw MatrixError.usage(
                "--literal-control-schema is required"
            )
        }
        guard let literalOutcomeSchema,
              !literalOutcomeSchema.isEmpty
        else {
            throw MatrixError.usage(
                "--literal-outcome-schema is required"
            )
        }
        guard let literalIdentityMemorySchema,
              !literalIdentityMemorySchema.isEmpty
        else {
            throw MatrixError.usage(
                "--literal-identity-memory-schema is required"
            )
        }
        guard let literalEngineCoordinationSchema,
              !literalEngineCoordinationSchema.isEmpty
        else {
            throw MatrixError.usage(
                "--literal-engine-coordination-schema is required"
            )
        }
        guard let outputRoot, !outputRoot.isEmpty else {
            throw MatrixError.usage("--output-root is required")
        }

        let requestedNames = fixtureNames.split(
            separator: ",",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard !requestedNames.contains(where: \.isEmpty) else {
            throw MatrixError.usage("fixture list contains an empty item")
        }
        guard Set(requestedNames).count == requestedNames.count else {
            throw MatrixError.usage("fixture list contains duplicates")
        }
        let fixtures = try requestedNames.map { name in
            guard let fixture = Fixture(rawValue: name) else {
                throw MatrixError.usage("unknown fixture \(name)")
            }
            return fixture
        }
        guard fixtures == Fixture.allCases else {
            throw MatrixError.usage(
                "fixtures must be exactly \(Fixture.allCases.map(\.rawValue).joined(separator: ","))"
            )
        }

        self.expectedSQLiteVersion = expectedSQLiteVersion
        self.fixtures = fixtures
        self.literalSchema = URL(fileURLWithPath: literalSchema)
            .standardizedFileURL
        self.literalObservabilitySchema = URL(
            fileURLWithPath: literalObservabilitySchema
        ).standardizedFileURL
        self.literalControlSchema = URL(
            fileURLWithPath: literalControlSchema
        ).standardizedFileURL
        self.literalOutcomeSchema = URL(
            fileURLWithPath: literalOutcomeSchema
        ).standardizedFileURL
        self.literalIdentityMemorySchema = URL(
            fileURLWithPath: literalIdentityMemorySchema
        ).standardizedFileURL
        self.literalEngineCoordinationSchema = URL(
            fileURLWithPath: literalEngineCoordinationSchema
        ).standardizedFileURL
        self.outputRoot = URL(fileURLWithPath: outputRoot)
            .standardizedFileURL
    }
}

private enum Fixture: String, CaseIterable {
    case fresh
    case v7
    case v8 = "v8-coding-ranch"
    case v9 = "v9-evercamp"
    case v10 = "v10-runtime-profiles"
    case v11 = "v11-cli-kinds"
    case v12Durable = "v12-durable"
    case v12Schedule = "v12-schedule"
    case v13Observability = "v13-observability"
    case v14Control = "v14-control-contracts"
    case v15Empty = "v15-empty"
    case v15Populated = "v15-populated"
    case v16IdentityMemory = "v16-identity-memory"
    case v17EngineCoordination = "v17-engine-coordination"

    var predecessorMigration: String? {
        switch self {
        case .fresh:
            return nil
        case .v7:
            return "v7"
        case .v8:
            return "v8-coding-ranch"
        case .v9:
            return "v9-evercamp"
        case .v10:
            return "v10-runtime-profiles"
        case .v11:
            return "v11-cli-kinds"
        case .v12Durable:
            return "v12-p1-durable-work"
        case .v12Schedule:
            return "v12-p1-schedule-fire"
        case .v13Observability:
            return "v13-p1-observability"
        case .v14Control:
            return "v14-p1-control-contracts"
        case .v15Empty, .v15Populated:
            return "v15-p1-outcome-contracts"
        case .v16IdentityMemory:
            return "v16-p1-identity-memory"
        case .v17EngineCoordination:
            return "v17-p1-engine-coordination"
        }
    }
}

private enum MatrixDiagnosticCode: CaseIterable {
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

private enum MatrixDiagnosticMessage: CaseIterable {
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

private enum MatrixDiagnosticWorkShape: String, CaseIterable {
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

private enum MatrixDiagnosticAttemptShape: String, CaseIterable {
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

private enum MatrixDiagnosticEventKind: String, CaseIterable {
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

private enum MatrixDiagnosticEventState: String, CaseIterable {
    case running
    case retryScheduled
    case succeeded
    case failed
    case canceled
    case queued
}

private enum MatrixDiagnosticTable {
    case work
    case attempt
    case event
}

private enum MatrixDiagnosticCandidate {
    case work(
        MatrixDiagnosticWorkShape,
        MatrixDiagnosticCode,
        MatrixDiagnosticMessage
    )
    case attempt(
        MatrixDiagnosticAttemptShape,
        MatrixDiagnosticCode,
        MatrixDiagnosticMessage
    )
    case event(
        MatrixDiagnosticEventKind,
        MatrixDiagnosticEventState,
        MatrixDiagnosticCode,
        MatrixDiagnosticMessage
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

    var table: MatrixDiagnosticTable {
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

private enum MatrixDiagnosticVerdict: Equatable {
    case accepted
    case checkRejected
}

private struct MatrixDiagnosticRowCounts: Equatable {
    let work: Int
    let attempt: Int
    let event: Int
}

private struct MatrixDiagnosticHealth: Equatable {
    let rowCounts: MatrixDiagnosticRowCounts
    let foreignKeysEnabled: Int
    let foreignKeyViolations: [String]
    let integrityResults: [String]
}

private struct SQLiteObjectSet: Equatable {
    let tables: Set<String>
    let indexes: Set<String>
    let triggers: Set<String>
}

private struct OutcomeContractSchemaReference {
    let finalObjects: SQLiteObjectSet
    let introducedIndexes: Set<String>
    let introducedTriggers: Set<String>
    let schemaShape: String
}

private struct EngineCoordinationSchemaReference {
    let finalObjects: SQLiteObjectSet
    let introducedIndexes: Set<String>
    let schemaShape: String
}

private struct CanonicalSchemaShapes {
    let throughV16: String
    let throughV17: String
}

private let v16MigrationSuffix = [
    "v12-p1-durable-work",
    "v12-p1-schedule-fire",
    "v13-p1-observability",
    "v14-p1-control-contracts",
    "v15-p1-outcome-contracts",
    "v16-p1-identity-memory",
]

private let v17MigrationSuffix = v16MigrationSuffix + [
    "v17-p1-engine-coordination",
]

private let engineCoordinationTables: Set<String> = [
    "engine_session",
    "engine_execution",
    "engine_terminal_proposal",
    "artifact_blob",
    "engine_proposal_artifact",
    "camp_deletion_proposal_blob",
    "artifact_blob_reference",
    "artifact_storage_origin",
    "discussion",
    "discussion_turn",
    "attention_item",
    "growth_evidence",
]

private let engineCoordinationExplicitIndexes: Set<String> = [
    "engine_session_external_identity",
    "engine_session_resume",
    "engine_execution_recovery",
    "engine_execution_card",
    "engine_terminal_proposal_pending",
    "artifact_blob_path",
    "artifact_blob_gc",
    "engine_proposal_artifact_gc_root",
    "camp_deletion_proposal_blob_recovery",
    "artifact_blob_reference_live",
    "artifact_blob_reference_camp",
    "artifact_storage_origin_camp",
    "discussion_turn_round",
    "attention_item_open",
    "growth_evidence_subject",
]

private let engineCoordinationTriggers: Set<String> = [
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

private let outcomeContractTables: Set<String> = [
    "acceptance_policy_version",
    "outcome_contract_version",
    "verification_requirement_group",
    "verification_requirement",
    "outcome",
    "outcome_version",
    "verification_record",
    "verification_result_head",
    "verification_invalidation",
    "acceptance_record",
    "outcome_metric_credit",
    "approval_grant",
    "approval_grant_use",
    "external_operation_receipt",
]

private let outcomeAppendOnlyTables: Set<String> = [
    "verification_record",
    "verification_invalidation",
    "acceptance_record",
    "external_operation_receipt",
]

private let controlContractTables: Set<String> = [
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

private let controlContractIndexes: Set<String> = [
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

private let controlContractTriggers: Set<String> = [
    "domain_command_receipt_reject_update",
    "domain_command_receipt_reject_delete",
    "domain_event_reject_update",
    "domain_event_reject_delete",
]

private struct MatrixRunner {
    let arguments: Arguments

    func run() throws {
        let finalMigration =
            AppDatabase.migrator.migrations.last ?? "<none>"
        try require(
            finalMigration == "v17-p1-engine-coordination",
            "real AppDatabase migrator must end at v17-p1-engine-coordination; actual final migration is \(finalMigration)"
        )
        try require(
            Array(AppDatabase.migrator.migrations.suffix(7))
                == v17MigrationSuffix,
            "real AppDatabase migration suffix is not v12-durable/v12-schedule/v13-observability/v14-control/v15-outcome/v16-identity-memory/v17-engine-coordination"
        )
        try prepareOutputRoot()
        try emitRuntimeEvidence()
        let canonicalSchemaShapes =
            try prepareLiteralScheduleSchemaShape()
        let canonicalControlSchemaShape =
            try prepareLiteralControlSchemaShape()
        let v13Objects = try prepareV13ObjectSet()
        let outcomeReference =
            try prepareLiteralOutcomeContractSchemaReference()
        let engineReference =
            try prepareLiteralEngineCoordinationSchemaReference(
                v16Objects: outcomeReference.finalObjects
            )

        for fixture in arguments.fixtures {
            try runFixture(
                fixture,
                canonicalScheduleSchemaShape: canonicalSchemaShapes.throughV17,
                canonicalControlSchemaShape: canonicalControlSchemaShape,
                v13Objects: v13Objects,
                outcomeReference: outcomeReference,
                engineReference: engineReference
            )
        }

        try runV16DiagnosticSentinelContract()

        try prepareLiteralV12DurableBaseline()
        try prepareLiteralV11Baseline()
        try prepareLiteralV15OutcomeBaseline()
        try prepareLiteralV16IdentityMemoryBaseline()
        try runLiteralDiagnostics(
            canonicalScheduleSchemaShape: canonicalSchemaShapes.throughV16,
            canonicalControlSchemaShape: canonicalControlSchemaShape,
            v13Objects: v13Objects,
            outcomeReference: outcomeReference
        )
        try runLiteralEngineCoordinationDiagnostics(
            engineReference: engineReference
        )
        try runRealDurableMigrationRollback()
        try runRealScheduleMigrationRollback()
        try runRealObservabilityMigrationRollback()
        try runLiteralObservabilityMigrationRollback()
        try runRealControlContractMigrationRollback()
        try runLiteralControlContractMigrationRollback()
        try runRealOutcomeContractMigrationRollback()
        try runLiteralOutcomeContractMigrationRollback()
        try runIntroductionGuardRollback()
        try runRealEngineCoordinationTriggerRollback(
            v16Objects: outcomeReference.finalObjects
        )
        try runLiteralEngineCoordinationTriggerRollback(
            v16Objects: outcomeReference.finalObjects
        )
        print("matrix.result=pass")
    }

    private func prepareOutputRoot() throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(
            atPath: arguments.outputRoot.path,
            isDirectory: &isDirectory
        ) {
            guard isDirectory.boolValue else {
                throw MatrixError.assertion(
                    "output root is not a directory"
                )
            }
            let contents = try FileManager.default.contentsOfDirectory(
                atPath: arguments.outputRoot.path
            )
            guard contents.isEmpty else {
                throw MatrixError.assertion(
                    "output root must start empty"
                )
            }
        } else {
            try FileManager.default.createDirectory(
                at: arguments.outputRoot,
                withIntermediateDirectories: true
            )
        }
    }

    private func runDiscussionRedactionSentinelContract() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("v17-discussion-redaction.sqlite")
        let appDatabase = try AppDatabase(path: databaseURL.path)
        let pool = appDatabase.pool
        try assertRuntime(in: pool)
        let before = try pool.read(stableSnapshot)
        try pool.writeWithoutTransaction { database in
            try database.inSavepoint {
                let prefix = "v17_discussion"
                let timestamp = 1_700_000_000.25
                try insertOutcomeContractFixture(database, prefix: prefix)
                try database.execute(
                    sql: """
                        UPDATE camp
                        SET archived=1
                        WHERE id=?
                        """,
                    arguments: ["\(prefix)-camp"]
                )
                try database.execute(
                    sql: """
                        UPDATE camp_lifecycle
                        SET state='deleting',version=2,updatedAt=?,
                            deletionRequestedAt=?,deletedAt=NULL
                        WHERE campId=? AND state='active' AND version=1
                        """,
                    arguments: [timestamp + 1, timestamp + 1, "\(prefix)-camp"]
                )
                try require(
                    database.changesCount == 1,
                    "discussion fixture failed to enter deleting lifecycle"
                )
                try database.execute(
                    sql: """
                        INSERT INTO durable_work(
                          id,campId,campLifecycleVersion,kind,aggregateType,
                          aggregateId,idempotencyKey,state,attempt,maxAttempts,
                          notBefore,leaseOwner,leaseExpiresAt,inputJson,inputHash,
                          outputJson,errorCode,errorMessage,traceId,version,
                          createdAt,updatedAt,finishedAt
                        ) VALUES (
                          ?,?,2,'campDeletion','camp',?,?,'queued',0,4,
                          NULL,NULL,NULL,'{}',?,NULL,NULL,NULL,?,1,?,?,NULL
                        )
                        """,
                    arguments: [
                        "\(prefix)-deletion-work",
                        "\(prefix)-camp",
                        "\(prefix)-camp",
                        "\(prefix)-deletion-work-key",
                        "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
                        "\(prefix)-deletion-trace",
                        timestamp + 1,
                        timestamp + 1,
                    ]
                )
                try database.execute(
                    sql: """
                        INSERT INTO camp_deletion_job(
                          id,campId,workId,requestIdempotencyKey,
                          confirmationId,confirmationHash,
                          unknownArtifactDisposition,requestedByActorId,state,
                          phaseCursorJson,lastErrorCode,version,createdAt,
                          updatedAt,completedAt
                        ) VALUES (
                          ?,?,?,?, ?,?,'detachOnlyNeverUnlink','user:matrix',
                          'erasing','{}',NULL,1,?,?,NULL
                        )
                        """,
                    arguments: [
                        "\(prefix)-deletion-job",
                        "\(prefix)-camp",
                        "\(prefix)-deletion-work",
                        "\(prefix)-delete-command",
                        "\(prefix)-confirmation",
                        String(repeating: "c", count: 64),
                        timestamp + 1,
                        timestamp + 1,
                    ]
                )
                try database.execute(
                    sql: """
                        INSERT INTO discussion(
                          id,campId,goalId,missionId,cardId,purpose,
                          participantActorIdsJson,maxRounds,tokenBudget,
                          spentTokens,status,requiredMaterialization,
                          materializationType,materializationId,aggregateVersion,
                          createdAt,updatedAt
                        ) VALUES (
                          ?,?,?,?,?,?,'["cow:a","cow:b"]',2,1000,0,
                          'running','decision',NULL,NULL,1,?,?
                        )
                        """,
                    arguments: [
                        "\(prefix)-discussion",
                        "\(prefix)-camp",
                        "\(prefix)-goal",
                        "\(prefix)-mission",
                        "\(prefix)-card",
                        "redaction contract",
                        timestamp + 2,
                        timestamp + 2,
                    ]
                )
                for (id, sequence) in [("turn-a", 0), ("turn-b", 1)] {
                    try database.execute(
                        sql: """
                            INSERT INTO discussion_turn(
                              id,discussionId,round,sequence,speakerActorId,
                              contentRef,contentHash,inputTokens,outputTokens,
                              createdAt,redactedAt
                            ) VALUES (?, ?,1,?,'cow:a','memory://turn',?,1,1,?,NULL)
                            """,
                        arguments: [
                            "\(prefix)-\(id)",
                            "\(prefix)-discussion",
                            sequence,
                            String(repeating: "d", count: 64),
                            timestamp + 2,
                        ]
                    )
                }
                try expectDatabaseFailure(
                    "discussion wrong-phase redaction"
                ) {
                    try database.execute(
                        sql: "UPDATE discussion_turn SET contentRef='',redactedAt=? WHERE id=?",
                        arguments: [timestamp + 3, "\(prefix)-turn-a"]
                    )
                }
                try expectDatabaseFailure("discussion no-op update") {
                    try database.execute(
                        sql: "UPDATE discussion_turn SET id=id WHERE id=?",
                        arguments: ["\(prefix)-turn-a"]
                    )
                }
                try database.execute(
                    sql: """
                        UPDATE camp_deletion_job
                        SET state='finalizing',version=2,updatedAt=?
                        WHERE id=? AND state='erasing' AND version=1
                        """,
                    arguments: [timestamp + 3, "\(prefix)-deletion-job"]
                )
                try require(
                    database.changesCount == 1,
                    "discussion fixture failed to enter finalizing"
                )
                try database.execute(
                    sql: "UPDATE discussion_turn SET contentRef='',redactedAt=? WHERE id=?",
                    arguments: [timestamp + 4, "\(prefix)-turn-a"]
                )
                try require(
                    database.changesCount == 1,
                    "discussion first exact redaction did not update one row"
                )
                try expectDatabaseFailure("discussion second redaction") {
                    try database.execute(
                        sql: "UPDATE discussion_turn SET redactedAt=? WHERE id=?",
                        arguments: [timestamp + 5, "\(prefix)-turn-a"]
                    )
                }
                try expectDatabaseFailure("discussion redaction extra diff") {
                    try database.execute(
                        sql: "UPDATE discussion_turn SET contentRef='',redactedAt=?,outputTokens=2 WHERE id=?",
                        arguments: [timestamp + 5, "\(prefix)-turn-b"]
                    )
                }
                try expectDatabaseFailure("discussion turn delete") {
                    try database.execute(
                        sql: "DELETE FROM discussion_turn WHERE id=?",
                        arguments: ["\(prefix)-turn-a"]
                    )
                }
                try requireDatabaseHealthy(
                    database,
                    scope: "v17 discussion redaction sentinel"
                )
                return .rollback
            }
        }
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "discussion redaction sentinel did not roll back exactly"
        )
        try pool.close()
        print("discussion.redaction.first_wrong_second_noop_extra_delete=pass")
    }

    private func runV16DiagnosticSentinelContract() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("v16-diagnostic-sentinels.sqlite")
        let appDatabase = try AppDatabase(path: databaseURL.path)
        try assertRuntime(in: appDatabase.pool)
        try require(
            poisonedV12Diagnostics == matrixDiagnosticSentinelIDs(),
            "v12 poisoned diagnostic sentinel set drifted"
        )
        try require(
            poisonedV15Diagnostics == matrixDiagnosticSentinelIDs(),
            "v15 poisoned diagnostic sentinel set drifted"
        )
        try validateV12Diagnostics(in: appDatabase.pool, scope: "v16")
        try appDatabase.pool.close()
    }

    private func emitRuntimeEvidence() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("runtime-probe.sqlite")
        let pool = try openPool(at: databaseURL)
        let version = try sqliteVersion(in: pool)
        let sourceID = try pool.read { database in
            try requiredString(
                database,
                sql: "SELECT sqlite_source_id()",
                label: "sqlite_source_id"
            )
        }
        try require(
            version == arguments.expectedSQLiteVersion,
            "runtime sqlite_version \(version) != expected \(arguments.expectedSQLiteVersion)"
        )
        print("lane.sqlite_version=\(version)")
        print("lane.sqlite_source_id=\(sourceID)")
        try pool.close()
    }

    private func runFixture(
        _ fixture: Fixture,
        canonicalScheduleSchemaShape: String,
        canonicalControlSchemaShape: String,
        v13Objects: SQLiteObjectSet,
        outcomeReference: OutcomeContractSchemaReference,
        engineReference: EngineCoordinationSchemaReference
    ) throws {
        let fixtureRoot = arguments.outputRoot
            .appendingPathComponent("fixture-\(fixture.rawValue)")
        try FileManager.default.createDirectory(
            at: fixtureRoot,
            withIntermediateDirectories: false
        )
        let databaseURL = fixtureRoot.appendingPathComponent("matrix.sqlite")

        let predecessorPool = try openPool(at: databaseURL)
        try assertRuntime(in: predecessorPool)
        if let predecessor = fixture.predecessorMigration {
            try AppDatabase.migrator.migrate(
                predecessorPool,
                upTo: predecessor
            )
        }
        if fixture == .v12Durable {
            try validateDurableWorkSchema(
                in: predecessorPool,
                fixture: fixture,
                expectedDurableRowCount: 0
            )
            try predecessorPool.write { database in
                try insertValidAttemptEvent(
                    database,
                    prefix: "v12_durable_seed"
                )
            }
        } else if fixture == .v12Schedule {
            try predecessorPool.write { database in
                try insertV12SchedulePredecessor(
                    database,
                    prefix: "v12_schedule_seed"
                )
            }
        } else if fixture == .v13Observability {
            try predecessorPool.write { database in
                try insertV13ObservabilityPredecessor(
                    database,
                    prefix: "v13_observability_seed"
                )
            }
        } else if fixture == .v14Control {
            try predecessorPool.write { database in
                try insertControlContractFixture(
                    database,
                    prefix: "v14_control_seed"
                )
            }
        } else if fixture == .v15Populated {
            try predecessorPool.write { database in
                try insertV15PopulatedIdentityMemoryPredecessor(database)
            }
        } else if fixture == .v15Empty {
            // Exact empty v15 predecessor: migration only, zero user rows.
        } else if fixture == .v16IdentityMemory {
            try validateIdentityMemoryMigration(
                in: predecessorPool,
                scope: "predecessor.v16-identity-memory",
                expectedObjects: outcomeReference.finalObjects,
                expectedMigrationCount: 1,
                expectedMigrationSuffix: v16MigrationSuffix
            )
            try predecessorPool.write { database in
                try insertV16IdentityMemoryArtifactPredecessor(database)
            }
        } else if fixture == .v17EngineCoordination {
            // Exact empty v17 predecessor: migration only, zero user rows.
        } else if fixture != .fresh {
            try predecessorPool.read { database in
                let hasWork = try database.tableExists("durable_work")
                let hasAttempt = try database.tableExists(
                    "durable_work_attempt"
                )
                let hasEvent = try database.tableExists(
                    "durable_work_attempt_event"
                )
                try require(
                    !hasWork,
                    "\(fixture.rawValue) unexpectedly already has durable_work"
                )
                try require(
                    !hasAttempt,
                    "\(fixture.rawValue) unexpectedly already has durable_work_attempt"
                )
                try require(
                    !hasEvent,
                    "\(fixture.rawValue) unexpectedly already has durable_work_attempt_event"
                )
            }
        }
        let predecessorSnapshot = try predecessorPool.read { database in
            switch fixture {
            case .v13Observability, .v14Control, .v15Empty, .v15Populated,
                 .v16IdentityMemory, .v17EngineCoordination:
                break
            default:
                try requireObservabilityObjectsAbsent(database)
            }
            let tableProjections = try predecessorUserTableProjections(
                database
            )
            return (
                tableProjections,
                try stableRowsSnapshot(
                    database,
                    tableProjections: tableProjections
                )
            )
        }
        try predecessorPool.close()

        let migrationDatabase = try AppDatabase(path: databaseURL.path)
        let migrationPool = migrationDatabase.pool
        try assertRuntime(in: migrationPool)
        let migratedRowsSnapshot = try migrationPool.read {
            try stableRowsSnapshot(
                $0,
                tableProjections: predecessorSnapshot.0
            )
        }
        if fixture == .v15Populated {
            try validateV15PopulatedV16Backfill(in: migrationPool)
        } else {
            try require(
                migratedRowsSnapshot == predecessorSnapshot.1,
                "\(fixture.rawValue) final migration changed predecessor user-table data"
            )
        }
        if fixture == .v16IdentityMemory {
            try validateV16IdentityMemoryArtifactBackfill(in: migrationPool)
            print("fixture.v16-identity-memory.engine_coordination.predecessor_snapshot=pass")
            print("fixture.v16-identity-memory.engine_coordination.legacy_artifact_backfill=pass")
            print("artifact_origin.count_camp_path_hash=pass")
        }
        if fixture == .v12Durable {
            print("fixture.v12-durable.predecessor_snapshot=pass")
            print("fixture.v12-durable.snapshot=pass")
        } else if fixture == .v12Schedule {
            print("fixture.v12-schedule.predecessor_snapshot=pass")
        } else if fixture == .v13Observability {
            print("fixture.v13-observability.predecessor_snapshot=pass")
        } else if fixture == .v14Control {
            print("fixture.v14-control-contracts.predecessor_snapshot=pass")
        }
        let firstFinalSnapshot = try migrationPool.read(stableSnapshot)
        try migrationPool.close()

        let replayDatabase = try AppDatabase(path: databaseURL.path)
        let replayPool = replayDatabase.pool
        try assertRuntime(in: replayPool)
        let replayedSnapshot = try replayPool.read(stableSnapshot)
        try require(
            replayedSnapshot == firstFinalSnapshot,
            "\(fixture.rawValue) second migrate changed final schema/data snapshot"
        )
        if fixture == .v12Durable {
            print("fixture.v12-durable.final_idempotent_snapshot=pass")
            print("fixture.v12-durable.double_replay=pass")
        } else if fixture == .v12Schedule {
            print("fixture.v12-schedule.final_idempotent_snapshot=pass")
        } else if fixture == .v13Observability {
            print("fixture.v13-observability.final_idempotent_snapshot=pass")
        } else if fixture == .v14Control {
            print("fixture.v14-control-contracts.final_idempotent_snapshot=pass")
        }
        let expectedDurableCounts: MatrixDiagnosticRowCounts = {
            switch fixture {
            case .v12Durable, .v12Schedule, .v13Observability:
                return MatrixDiagnosticRowCounts(work: 1, attempt: 1, event: 1)
            case .v15Populated:
                return MatrixDiagnosticRowCounts(work: 1, attempt: 1, event: 2)
            default:
                return MatrixDiagnosticRowCounts(work: 0, attempt: 0, event: 0)
            }
        }()
        try validateScheduleFireSchema(
            in: replayPool,
            scope: fixture.rawValue,
            expectedDurableRowCounts: expectedDurableCounts,
            expectedScheduleFireRowCount:
                fixture == .v12Schedule || fixture == .v13Observability
                    ? 1 : 0,
            expectedScheduleCursorRowCount:
                fixture == .v12Schedule || fixture == .v13Observability
                    ? 1 : 0,
            expectedScheduleMigrationCount: 1,
            expectedObservabilityMigrationCount: 1,
            expectedFailureRecordCount:
                fixture == .v13Observability ? 1 : 0,
            expectedContextDegradationCount:
                fixture == .v13Observability ? 1 : 0,
            canonicalScheduleSchemaShape: canonicalScheduleSchemaShape
        )
        try validateScheduleFireContract(
            in: replayPool,
            scope: "real.\(fixture.rawValue)"
        )
        try validateV12Diagnostics(
            in: replayPool,
            scope: "real.\(fixture.rawValue)"
        )
        try validateObservabilityContract(
            in: replayPool,
            scope: "real.\(fixture.rawValue)"
        )
        try validateControlContract(
            in: replayPool,
            scope: "real.\(fixture.rawValue)",
            canonicalSchemaShape: canonicalControlSchemaShape,
            v13Objects: v13Objects,
            expectedMigrationCount: 1,
            expectedMigrationSuffix: v17MigrationSuffix
        )
        try validateOutcomeContract(
            in: replayPool,
            scope: "real.\(fixture.rawValue)",
            reference: outcomeReference,
            expectedObjects: engineReference.finalObjects,
            expectedMigrationCount: 1,
            expectedMigrationSuffix: v17MigrationSuffix
        )
        try validateIdentityMemoryMigration(
            in: replayPool,
            scope: "real.\(fixture.rawValue)",
            expectedObjects: engineReference.finalObjects,
            expectedMigrationCount: 1,
            expectedMigrationSuffix: v17MigrationSuffix
        )
        try validateEngineCoordinationMigration(
            in: replayPool,
            scope: "real.\(fixture.rawValue)",
            reference: engineReference,
            expectedMigrationCount: 1
        )
        try validateRegisteredIdentityMemoryUDF(
            appDatabase: replayDatabase,
            scope: "real.\(fixture.rawValue)"
        )
        try insertAndValidateAttemptEvent(in: replayPool, label: fixture.rawValue)
        let finalHealth = try replayPool.read(matrixDiagnosticHealth)
        try requireMatrixDiagnosticHealth(
            finalHealth,
            scope: "real.\(fixture.rawValue)",
            phase: "after append-only checks"
        )
        try replayPool.close()
        print("fixture.\(fixture.rawValue).replay=pass")
        print("fixture.\(fixture.rawValue).fk=pass")
        print("fixture.\(fixture.rawValue).integrity=pass")
        print("fixture.\(fixture.rawValue).ddl=pass")
        print("fixture.\(fixture.rawValue).append_only=pass")
        print("observability_contract.real.\(fixture.rawValue)=pass")
        print("control_contract.real.\(fixture.rawValue)=pass")
        print("outcome_contract.real.\(fixture.rawValue)=pass")
        print("identity_memory_contract.real.\(fixture.rawValue)=pass")
        print("engine_coordination_contract.real.\(fixture.rawValue)=pass")
        if fixture == .v15Empty {
            print("fixture.v15Empty.replay=pass")
        } else if fixture == .v15Populated {
            print("fixture.v15Populated.backfill=pass")
        }
        if fixture == .v12Schedule {
            print("fixture.v12-schedule.observability.predecessor_snapshot=pass")
            print("fixture.v12-schedule.observability.failure_record=pass")
            print("fixture.v12-schedule.observability.context_degradation=pass")
            print("fixture.v12-schedule.observability.rollback=pass")
            print("fixture.v12-schedule.observability.replay=pass")
            print("fixture.v12-schedule.observability.fk=pass")
            print("fixture.v12-schedule.observability.integrity=pass")
            print("fixture.v12-schedule.observability.ddl=pass")
            print("fixture.v12-schedule.observability.append_only=pass")
            print("fixture.v12-schedule.observability.final_checkpoint=31/65/4")
        } else if fixture == .v13Observability {
            print("fixture.v13-observability.control.predecessor_snapshot=pass")
            print("fixture.v13-observability.control.replay=pass")
            print("fixture.v13-observability.control.fk=pass")
            print("fixture.v13-observability.control.integrity=pass")
            print("fixture.v13-observability.control.ddl=pass")
            print("fixture.v13-observability.control.append_only=pass")
            print("fixture.v13-observability.control.final_checkpoint=41/94/8")
        } else if fixture == .v14Control {
            print("fixture.v14-control-contracts.outcome.predecessor_snapshot=pass")
            print("fixture.v14-control-contracts.outcome.replay=pass")
            print("fixture.v14-control-contracts.outcome.fk=pass")
            print("fixture.v14-control-contracts.outcome.integrity=pass")
            print("fixture.v14-control-contracts.outcome.ddl=pass")
            print("fixture.v14-control-contracts.outcome.append_only=pass")
            print("fixture.v14-control-contracts.outcome.final_checkpoint=55/134/16")
        }
    }

    private func validateIdentityMemoryMigration(
        in pool: DatabasePool,
        scope: String,
        expectedObjects: SQLiteObjectSet,
        expectedMigrationCount: Int,
        expectedMigrationSuffix: [String]
    ) throws {
        try pool.read { database in
            let objects = try sqliteObjectSet(database)
            try require(
                objects == expectedObjects,
                "\(scope) final object set is \(objects.tables.count)/\(objects.indexes.count)/\(objects.triggers.count), expected \(expectedObjects.tables.count)/\(expectedObjects.indexes.count)/\(expectedObjects.triggers.count)"
            )
            let requiredTables: Set<String> = [
                "camp_lifecycle", "camp_provider_dispatch",
                "camp_deletion_job", "camp_deletion_artifact",
                "legacy_chat_scope", "legacy_companion_note_scope",
                "camp_event_scope", "cow_identity", "camp_residency",
                "camp_bridge", "memory_record_version", "memory_dependency",
            ]
            try require(
                requiredTables.isSubset(of: objects.tables),
                "\(scope) missing v16 tables: \(requiredTables.subtracting(objects.tables).sorted())"
            )
            let migrationCount = try requiredInt(
                database,
                sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v16-p1-identity-memory'",
                label: "\(scope) v16 migration count"
            )
            try require(
                migrationCount == expectedMigrationCount,
                "\(scope) v16 migration count is \(migrationCount), expected \(expectedMigrationCount)"
            )
            if expectedMigrationCount == 1 {
                let suffix = Array(try String.fetchAll(
                    database,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
                ).suffix(expectedMigrationSuffix.count))
                try require(
                    suffix == expectedMigrationSuffix,
                    "\(scope) migration suffix drifted: \(suffix)"
                )
            }
            for (source, projection, label) in [
                ("camp", "camp_lifecycle", "Camp lifecycle"),
                ("companion", "cow_identity", "Cow identity"),
                ("chat_thread", "legacy_chat_scope", "legacy chat scope"),
                ("companion_note", "legacy_companion_note_scope", "legacy note scope"),
            ] {
                let sourceCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM \(quotedIdentifier(source))",
                    label: "\(scope) \(label) source count"
                )
                let projectionCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM \(quotedIdentifier(projection))",
                    label: "\(scope) \(label) projection count"
                )
                try require(
                    sourceCount == projectionCount,
                    "\(scope) \(label) count mismatch \(sourceCount)/\(projectionCount)"
                )
            }
            for (source, sourceTable) in [
                ("event", "event"),
                ("domain_event", "domain_event"),
            ] {
                let sourceCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM \(quotedIdentifier(source))",
                    label: "\(scope) \(source) count"
                )
                let scopeCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM camp_event_scope WHERE sourceTable=?",
                    arguments: [sourceTable],
                    label: "\(scope) \(sourceTable) scope count"
                )
                try require(
                    sourceCount == scopeCount,
                    "\(scope) \(sourceTable) scope count mismatch \(sourceCount)/\(scopeCount)"
                )
            }
            let unboundWork = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM durable_work w
                    LEFT JOIN camp_lifecycle l ON l.campId=w.campId
                    WHERE l.campId IS NULL OR w.campLifecycleVersion<>l.version
                    """,
                label: "\(scope) unbound durable work"
            )
            try require(unboundWork == 0, "\(scope) has \(unboundWork) unbound work rows")
            let archivedActiveWork = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM durable_work w
                    JOIN camp c ON c.id=w.campId
                    WHERE c.archived=1
                      AND w.state IN ('queued','running','retryScheduled')
                    """,
                label: "\(scope) archived active work"
            )
            try require(
                archivedActiveWork == 0,
                "\(scope) retained \(archivedActiveWork) archived active work rows"
            )
            for (table, requiredTarget) in [
                ("durable_work_attempt", "durable_work"),
                ("durable_work_attempt_event", "durable_work_attempt"),
            ] {
                let targets = Set(try String.fetchAll(
                    database,
                    sql: "SELECT \"table\" FROM pragma_foreign_key_list(?)",
                    arguments: [table]
                ))
                try require(
                    targets.contains(requiredTarget)
                        && !targets.contains(where: {
                            $0.contains("_v16") || $0.contains("_legacy")
                        }),
                    "\(scope) \(table) does not target final \(requiredTarget)"
                )
            }
            let deleteGuardSQL = try requiredString(
                database,
                sql: "SELECT sql FROM sqlite_master WHERE type='trigger' AND name='ingestion_item_reject_delete'",
                label: "\(scope) ingestion delete guard"
            )
            let resultGuardSQL = try requiredString(
                database,
                sql: "SELECT sql FROM sqlite_master WHERE type='trigger' AND name='rumination_result_reject_delete'",
                label: "\(scope) result delete guard"
            )
            try require(
                deleteGuardSQL.contains("agentloop_active_ingestion_deletion_permit_v1")
                    && resultGuardSQL.contains("agentloop_active_ingestion_deletion_permit_v1"),
                "\(scope) v16 deletion guards lack the raw permit UDF"
            )
            try requireDatabaseHealthy(database, scope: "\(scope) v16 identity-memory")
        }
    }

    private func validateEngineCoordinationMigration(
        in pool: DatabasePool,
        scope: String,
        reference: EngineCoordinationSchemaReference,
        expectedMigrationCount: Int
    ) throws {
        try pool.read { database in
            let objects = try sqliteObjectSet(database)
            try require(
                objects == reference.finalObjects,
                "\(scope) v17 sqlite_master name sets differ from literal Stage §18.7"
            )
            try require(
                objects.tables.count == 79
                    && objects.indexes.count == 208
                    && objects.triggers.count == 84,
                "\(scope) v17 checkpoint is \(objects.tables.count)/\(objects.indexes.count)/\(objects.triggers.count), expected 79/208/84"
            )
            try require(
                engineCoordinationTables.isSubset(of: objects.tables),
                "\(scope) missing v17 tables: \(engineCoordinationTables.subtracting(objects.tables).sorted())"
            )
            try require(
                engineCoordinationExplicitIndexes.isSubset(of: objects.indexes),
                "\(scope) missing v17 indexes: \(engineCoordinationExplicitIndexes.subtracting(objects.indexes).sorted())"
            )
            try require(
                engineCoordinationTriggers.isSubset(of: objects.triggers),
                "\(scope) missing v17 triggers: \(engineCoordinationTriggers.subtracting(objects.triggers).sorted())"
            )
            let schemaShape = try selectedSchemaShape(
                database,
                tables: engineCoordinationTables,
                indexes: reference.introducedIndexes,
                triggers: engineCoordinationTriggers
            )
            try require(
                schemaShape == reference.schemaShape,
                "\(scope) v17 schema differs from literal Stage §18.7"
            )
            let migrationCount = try requiredInt(
                database,
                sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v17-p1-engine-coordination'",
                label: "\(scope) v17 migration count"
            )
            try require(
                migrationCount == expectedMigrationCount,
                "\(scope) v17 migration count is \(migrationCount), expected \(expectedMigrationCount)"
            )
            if expectedMigrationCount == 1 {
                let suffix = Array(try String.fetchAll(
                    database,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
                ).suffix(v17MigrationSuffix.count))
                try require(
                    suffix == v17MigrationSuffix,
                    "\(scope) v17 migration suffix drifted: \(suffix)"
                )
            }
            try requireDatabaseHealthy(
                database,
                scope: "\(scope) v17 engine-coordination"
            )
        }
    }

    private func validateV15PopulatedV16Backfill(
        in pool: DatabasePool
    ) throws {
        try pool.read { database in
            let lifecycles = try String.fetchAll(
                database,
                sql: "SELECT campId || ':' || state || ':' || version FROM camp_lifecycle ORDER BY campId"
            )
            try require(
                lifecycles == [
                    "v15_populated-archived-camp:archived:1",
                    "v15_populated-camp:active:1",
                ],
                "v15 populated lifecycle backfill drifted: \(lifecycles)"
            )
            try require(
                try requiredInt(database, sql: "SELECT COUNT(*) FROM cow_identity", label: "v15 populated cows") == 2,
                "v15 populated Cow backfill count drifted"
            )
            try require(
                try requiredInt(database, sql: "SELECT COUNT(*) FROM camp_residency", label: "v15 populated residencies") == 1,
                "v15 populated residency backfill count drifted"
            )
            try require(
                try requiredInt(database, sql: "SELECT COUNT(*) FROM legacy_chat_scope", label: "v15 populated chat scopes") == 2,
                "v15 populated chat scope count drifted"
            )
            try require(
                try requiredInt(database, sql: "SELECT COUNT(*) FROM legacy_companion_note_scope", label: "v15 populated note scopes") == 2,
                "v15 populated note scope count drifted"
            )
            let eventScopes = try String.fetchAll(
                database,
                sql: "SELECT eventId || ':' || scopeKind || ':' || COALESCE(campId,'-') FROM camp_event_scope WHERE sourceTable='event' ORDER BY eventId"
            )
            try require(
                eventScopes == [
                    "v15_populated-event-camp:camp:v15_populated-camp",
                    "v15_populated-event-global:global:-",
                ],
                "v15 populated event scopes drifted: \(eventScopes)"
            )
            let work = try requiredString(
                database,
                sql: "SELECT state || ':' || errorCode || ':' || errorMessage || ':' || campLifecycleVersion FROM durable_work WHERE id='v15_populated-archived-work'",
                label: "v15 populated archived work"
            )
            try require(
                work == "canceled:work_canceled:camp_archived_backfill:1",
                "v15 populated archived work closure drifted: \(work)"
            )
            let attempt = try requiredString(
                database,
                sql: "SELECT outcome || ':' || errorCode || ':' || terminalWorkVersion FROM durable_work_attempt WHERE workId='v15_populated-archived-work'",
                label: "v15 populated archived attempt"
            )
            try require(
                attempt == "canceled:work_canceled:2",
                "v15 populated archived attempt closure drifted: \(attempt)"
            )
            try require(
                try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM durable_work_attempt_event WHERE workId='v15_populated-archived-work'",
                    label: "v15 populated archived events"
                ) == 2,
                "v15 populated archived work did not append one cancellation event"
            )
        }
    }

    private func validateRegisteredIdentityMemoryUDF(
        appDatabase: AppDatabase,
        scope: String
    ) throws {
        let invocationArguments = (["'deleteIngestion'"]
            + Array(repeating: "NULL", count: 52)).joined(separator: ",")
        let sql = "SELECT agentloop_active_ingestion_deletion_permit_v1(\(invocationArguments))"

        func requireStableRejection(_ database: Database, role: String) throws {
            do {
                _ = try Int.fetchOne(database, sql: sql)
            } catch let error as DatabaseError {
                try require(
                    error.message?.contains(
                        "agentloop_active_ingestion_deletion_permit_rejected"
                    ) == true,
                    "\(scope) \(role) UDF rejected with \(error.message ?? "<none>")"
                )
                return
            }
            throw MatrixError.expectedFailureDidNotOccur(
                "\(scope) \(role) UDF without an active generation"
            )
        }

        try appDatabase.pool.read { database in
            try requireStableRejection(database, role: "reader")
        }
        try appDatabase.pool.write { database in
            _ = try appDatabase.activeIngestionDeletionSQLPermitRegistry
                .requireWriterCell(for: database)
            try requireStableRejection(database, role: "writer transaction")
        }
        try appDatabase.pool.writeWithoutTransaction { database in
            try appDatabase.activeIngestionDeletionSQLPermitRegistry
                .assertNoActiveGenerationForResolution(for: database)
            try requireStableRejection(database, role: "writer autocommit")
        }
        print("fixture.v16.real_grdb.result=pass")
        print("udf.\(scope).registration_and_fail_closed=pass")
    }

    private func validateDurableWorkSchema(
        in pool: DatabasePool,
        fixture: Fixture,
        expectedDurableRowCount: Int
    ) throws {
        try pool.read { database in
            let v12Count = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v12-p1-durable-work'
                    """,
                label: "v12 migration count"
            )
            try require(
                v12Count == 1,
                "\(fixture.rawValue) records v12 \(v12Count) times"
            )

            let tableNames = try sqliteObjectNames(
                database,
                type: "table"
            )
            for table in [
                "durable_work",
                "durable_work_attempt",
                "durable_work_attempt_event",
            ] {
                try require(
                    tableNames.contains(table),
                    "\(fixture.rawValue) missing table \(table)"
                )
            }
            try require(
                !tableNames.contains("schedule_fire"),
                "\(fixture.rawValue) must not create schedule_fire in A1a"
            )
            try require(
                tableNames.count == 27,
                "\(fixture.rawValue) table checkpoint \(tableNames.count) != 27"
            )

            let indexNames = try sqliteObjectNames(
                database,
                type: "index"
            )
            let expectedIndexes: Set<String> = [
                "durable_work_one_active_aggregate",
                "durable_work_claimable",
                "durable_work_aggregate_history",
                "durable_work_attempt_one_terminal",
                "durable_work_attempt_event_work",
            ]
            try require(
                expectedIndexes.isSubset(of: indexNames),
                "\(fixture.rawValue) missing durable indexes: \(expectedIndexes.subtracting(indexNames).sorted())"
            )
            try require(
                indexNames.count == 55,
                "\(fixture.rawValue) index checkpoint \(indexNames.count) != 55"
            )

            let triggerNames = try sqliteObjectNames(
                database,
                type: "trigger"
            )
            let expectedTriggers: Set<String> = [
                "durable_work_attempt_event_reject_update",
                "durable_work_attempt_event_reject_delete",
            ]
            try require(
                expectedTriggers.isSubset(of: triggerNames),
                "\(fixture.rawValue) missing append-only triggers"
            )
            try require(
                triggerNames.count == 4,
                "\(fixture.rawValue) trigger checkpoint \(triggerNames.count) != 4"
            )

            try requireColumns(
                database,
                table: "durable_work",
                expected: [
                    "id", "campId", "kind", "aggregateType", "aggregateId",
                    "idempotencyKey", "state", "attempt", "maxAttempts",
                    "notBefore", "leaseOwner", "leaseExpiresAt", "inputJson",
                    "inputHash", "outputJson", "errorCode", "errorMessage",
                    "traceId", "version", "createdAt", "updatedAt",
                    "finishedAt",
                ]
            )
            try requireColumns(
                database,
                table: "durable_work_attempt",
                expected: [
                    "workId", "attempt", "id", "workerId", "startedAt",
                    "endedAt", "outcome", "errorCode", "errorMessage",
                    "traceId", "terminalWorkVersion",
                ]
            )
            try requireColumns(
                database,
                table: "durable_work_attempt_event",
                expected: [
                    "id", "workId", "attempt", "sequence", "eventKind",
                    "workerId", "workVersion", "resultingWorkState",
                    "errorCode", "errorMessage", "occurredAt",
                ]
            )

            for table in [
                "durable_work",
                "durable_work_attempt",
                "durable_work_attempt_event",
            ] {
                let rowCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM \(quotedIdentifier(table))",
                    label: "\(table) initial count"
                )
                try require(
                    rowCount == expectedDurableRowCount,
                    "\(fixture.rawValue) \(table) row count \(rowCount) != \(expectedDurableRowCount)"
                )
            }

            let foreignKeyCursor = try database.foreignKeyViolations()
            let hasForeignKeyViolation =
                try foreignKeyCursor.next() != nil
            try require(
                !hasForeignKeyViolation,
                "\(fixture.rawValue) has a foreign-key violation"
            )
            let integrity = try requiredString(
                database,
                sql: "PRAGMA integrity_check",
                label: "integrity_check"
            )
            try require(
                integrity == "ok",
                "\(fixture.rawValue) integrity_check = \(integrity)"
            )
        }
    }

    private func validateScheduleFireSchema(
        in pool: DatabasePool,
        scope: String,
        expectedDurableRowCounts: MatrixDiagnosticRowCounts,
        expectedScheduleFireRowCount: Int,
        expectedScheduleCursorRowCount: Int,
        expectedScheduleMigrationCount: Int,
        expectedObservabilityMigrationCount: Int,
        expectedFailureRecordCount: Int,
        expectedContextDegradationCount: Int,
        canonicalScheduleSchemaShape: String
    ) throws {
        try pool.read { database in
            let durableMigrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v12-p1-durable-work'
                    """,
                label: "\(scope) v12-p1-durable-work count"
            )
            try require(
                durableMigrationCount == 1,
                "\(scope) records v12-p1-durable-work \(durableMigrationCount) times"
            )
            let scheduleMigrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v12-p1-schedule-fire'
                    """,
                label: "\(scope) v12-p1-schedule-fire count"
            )
            try require(
                scheduleMigrationCount == expectedScheduleMigrationCount,
                "\(scope) records v12-p1-schedule-fire \(scheduleMigrationCount) times; expected \(expectedScheduleMigrationCount)"
            )
            let observabilityMigrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v13-p1-observability'
                    """,
                label: "\(scope) v13-p1-observability count"
            )
            try require(
                observabilityMigrationCount == expectedObservabilityMigrationCount,
                "\(scope) records v13-p1-observability \(observabilityMigrationCount) times; expected \(expectedObservabilityMigrationCount)"
            )
            let actualScheduleSchemaShape = try scheduleSchemaShape(database)
            try require(
                actualScheduleSchemaShape == canonicalScheduleSchemaShape,
                "\(scope) final schema differs from canonical Stage §18.1-§18.6 shape"
            )

            let tableNames = try sqliteObjectNames(database, type: "table")
            let requiredTables: Set<String> = [
                "durable_work",
                "durable_work_attempt",
                "durable_work_attempt_event",
                "schedule_fire",
                "schedule_evaluation_cursor",
                "failure_record",
                "context_degradation",
            ]
            try require(
                requiredTables.isSubset(of: tableNames),
                "\(scope) missing A4 tables: \(requiredTables.subtracting(tableNames).sorted())"
            )

            let indexNames = try sqliteObjectNames(database, type: "index")
            let requiredIndexes: Set<String> = [
                "durable_work_one_active_aggregate",
                "durable_work_claimable",
                "durable_work_aggregate_history",
                "durable_work_attempt_one_terminal",
                "durable_work_attempt_event_work",
                "schedule_fire_original_slot",
                "schedule_fire_replay_key",
                "schedule_fire_schedule_time",
                "sqlite_autoindex_schedule_fire_1",
                "sqlite_autoindex_schedule_evaluation_cursor_1",
                "failure_record_open_scope",
                "context_degradation_mission",
                "context_degradation_card",
                "sqlite_autoindex_failure_record_1",
                "sqlite_autoindex_context_degradation_1",
            ]
            try require(
                requiredIndexes.isSubset(of: indexNames),
                "\(scope) missing A4 indexes: \(requiredIndexes.subtracting(indexNames).sorted())"
            )
            let scheduleIndexNames = Set(indexNames.filter {
                $0.contains("schedule_fire")
                    || $0.contains("schedule_evaluation_cursor")
            })
            try require(
                scheduleIndexNames == Set([
                    "schedule_fire_original_slot",
                    "schedule_fire_replay_key",
                    "schedule_fire_schedule_time",
                    "sqlite_autoindex_schedule_fire_1",
                    "sqlite_autoindex_schedule_evaluation_cursor_1",
                ]),
                "\(scope) schedule index set drifted: \(scheduleIndexNames.sorted())"
            )

            let triggerNames = try sqliteObjectNames(database, type: "trigger")
            let expectedTriggerNames = Set([
                "event_no_delete",
                "event_reject_update_except_camp_redaction",
                "durable_work_attempt_event_reject_delete",
                "durable_work_attempt_event_reject_update_except_camp_redaction",
            ]).union(controlContractTriggers)
            try require(
                expectedTriggerNames.isSubset(of: triggerNames),
                "\(scope) missing pre-v15 triggers: \(expectedTriggerNames.subtracting(triggerNames).sorted())"
            )
            let scheduleTriggers = Set(triggerNames.filter {
                $0.hasPrefix("schedule_fire_")
                    || $0.hasPrefix("schedule_evaluation_cursor_")
            })
            try require(
                scheduleTriggers == [
                    "schedule_fire_first_redaction_exact",
                    "schedule_fire_post_redaction_lock",
                    "schedule_fire_reject_delete",
                ],
                "\(scope) v16 schedule trigger set drifted: \(scheduleTriggers.sorted())"
            )
            let scheduleTriggerCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM sqlite_master
                    WHERE type = 'trigger'
                      AND tbl_name IN (
                        'schedule_fire',
                        'schedule_evaluation_cursor'
                      )
                    """,
                label: "\(scope) schedule trigger count"
            )
            try require(
                scheduleTriggerCount == 3,
                "\(scope) v16 schedule trigger count is \(scheduleTriggerCount), expected 3"
            )

            try requireColumns(
                database,
                table: "schedule_fire",
                expected: [
                    "id", "scheduleId", "templateId", "slotKey",
                    "scheduledAt", "replayOfFireId",
                    "replayIdempotencyKey", "replayPayloadHash", "state",
                    "missionId", "traceId", "errorCode", "errorMessage",
                    "createdAt", "redactedAt",
                ]
            )
            try requireColumns(
                database,
                table: "schedule_evaluation_cursor",
                expected: [
                    "scheduleId", "lastEvaluatedSlotKey",
                    "lastEvaluatedScheduledAt", "version", "updatedAt",
                ]
            )

            let scheduleFireForeignKeys = try foreignKeyShapes(
                database,
                table: "schedule_fire"
            )
            try require(
                scheduleFireForeignKeys == [
                    "missionId|mission|id|RESTRICT",
                    "replayOfFireId|schedule_fire|id|RESTRICT",
                    "scheduleId|schedule|id|RESTRICT",
                    "templateId|mission_template|id|RESTRICT",
                ],
                "\(scope) schedule_fire foreign keys drifted"
            )
            let cursorForeignKeys = try foreignKeyShapes(
                database,
                table: "schedule_evaluation_cursor"
            )
            try require(
                cursorForeignKeys == ["scheduleId|schedule|id|CASCADE"],
                "\(scope) cursor foreign key drifted"
            )

            let originalIndex = try requiredString(
                database,
                sql: """
                    SELECT sql FROM sqlite_master
                    WHERE type = 'index'
                      AND name = 'schedule_fire_original_slot'
                    """,
                label: "\(scope) original slot index"
            )
            let replayIndex = try requiredString(
                database,
                sql: """
                    SELECT sql FROM sqlite_master
                    WHERE type = 'index'
                      AND name = 'schedule_fire_replay_key'
                    """,
                label: "\(scope) replay key index"
            )
            try require(
                originalIndex.contains("WHERE replayOfFireId IS NULL"),
                "\(scope) original slot predicate drifted"
            )
            try require(
                replayIndex.contains(
                    "WHERE replayIdempotencyKey IS NOT NULL"
                ),
                "\(scope) replay key predicate drifted"
            )

            let fireDDL = try requiredString(
                database,
                sql: """
                    SELECT sql FROM sqlite_master
                    WHERE type = 'table' AND name = 'schedule_fire'
                    """,
                label: "\(scope) schedule_fire DDL"
            )
            for fragment in [
                "state IN ('started','failed')",
                "length(replayPayloadHash) = 64",
                "length(errorMessage) <= 1000",
                "redactedAt IS NULL OR errorMessage IS NULL",
            ] {
                try require(
                    fireDDL.contains(fragment),
                    "\(scope) schedule_fire DDL missing \(fragment)"
                )
            }
            try require(
                !fireDDL.contains("intended"),
                "\(scope) schedule_fire retained intended state"
            )

            for (table, expectedCount) in [
                ("durable_work", expectedDurableRowCounts.work),
                ("durable_work_attempt", expectedDurableRowCounts.attempt),
                ("durable_work_attempt_event", expectedDurableRowCounts.event),
            ] {
                let rowCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM \(quotedIdentifier(table))",
                    label: "\(scope) \(table) preserved count"
                )
                try require(
                    rowCount == expectedCount,
                    "\(scope) \(table) count \(rowCount) != \(expectedCount)"
                )
            }
            for (table, expectedCount) in [
                ("schedule_fire", expectedScheduleFireRowCount),
                ("schedule_evaluation_cursor", expectedScheduleCursorRowCount),
                ("failure_record", expectedFailureRecordCount),
                ("context_degradation", expectedContextDegradationCount),
            ] {
                let rowCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM \(quotedIdentifier(table))",
                    label: "\(scope) \(table) initial count"
                )
                try require(
                    rowCount == expectedCount,
                    "\(scope) \(table) row count \(rowCount) != \(expectedCount)"
                )
            }

            let foreignKeyCursor = try database.foreignKeyViolations()
            let foreignKeyViolation = try foreignKeyCursor.next()
            try require(
                foreignKeyViolation == nil,
                "\(scope) has a foreign-key violation"
            )
            let integrity = try requiredString(
                database,
                sql: "PRAGMA integrity_check",
                label: "\(scope) integrity_check"
            )
            try require(
                integrity == "ok",
                "\(scope) integrity_check failed"
            )
        }
    }

    private func validateScheduleFireContract(
        in pool: DatabasePool,
        scope: String
    ) throws {
        let prefix = scope
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        let scheduledSeconds = Double(bitPattern: 0x41d954fc40000001)
        let cursorSeconds = Double(bitPattern: 0x41d954fc40000002)
        let updatedSeconds = Double(bitPattern: 0x41d954fc40000003)
        let redactedSeconds = Double(bitPattern: 0x41d954fc40000004)
        let before = try pool.read(stableSnapshot)
        let baselineCounts = try pool.read { database in
            (
                try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM schedule_fire",
                    label: "\(scope) baseline schedule fire count"
                ),
                try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM schedule_evaluation_cursor",
                    label: "\(scope) baseline schedule cursor count"
                )
            )
        }

        try pool.writeWithoutTransaction { database in
            try database.inTransaction {
                try insertScheduleFireScopeFixture(
                    database,
                    prefix: prefix,
                    timestamp: scheduledSeconds
                )
                try insertScheduleFireFixture(
                    database,
                    prefix: prefix,
                    id: "legal-started-original",
                    scheduledAt: scheduledSeconds,
                    createdAt: cursorSeconds,
                    state: "started",
                    missionID: "\(prefix)-mission"
                )
                try insertScheduleFireFixture(
                    database,
                    prefix: prefix,
                    id: "legal-failed-original",
                    scheduledAt: cursorSeconds,
                    createdAt: updatedSeconds,
                    state: "failed",
                    errorCode: "schedule_configuration_invalid",
                    errorMessage: String(repeating: "x", count: 1_000)
                )
                try insertScheduleFireFixture(
                    database,
                    prefix: prefix,
                    id: "legal-started-replay",
                    scheduledAt: scheduledSeconds,
                    createdAt: updatedSeconds,
                    replayOfFireID: "\(prefix)-legal-failed-original",
                    replayIdempotencyKey: "\(prefix)-replay-key",
                    replayPayloadHash: String(repeating: "a", count: 64),
                    state: "started",
                    missionID: "\(prefix)-mission"
                )
                try insertScheduleFireFixture(
                    database,
                    prefix: prefix,
                    id: "legal-redacted-failed",
                    scheduledAt: scheduledSeconds,
                    createdAt: updatedSeconds,
                    state: "failed",
                    errorCode: "schedule_configuration_invalid",
                    redactedAt: redactedSeconds
                )
                try database.execute(
                    sql: """
                        INSERT INTO schedule_evaluation_cursor (
                          scheduleId, lastEvaluatedSlotKey,
                          lastEvaluatedScheduledAt, version, updatedAt
                        ) VALUES (?, ?, ?, 1, ?)
                        """,
                    arguments: [
                        "\(prefix)-schedule",
                        "slot-legal-started-replay",
                        cursorSeconds,
                        updatedSeconds,
                    ]
                )

                let legalFireCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM schedule_fire",
                    label: "\(scope) legal schedule fire count"
                )
                try require(
                    legalFireCount == baselineCounts.0 + 4,
                    "\(scope) legal schedule fire truth table did not persist"
                )
                let legalCursorCount = try requiredInt(
                    database,
                    sql: "SELECT COUNT(*) FROM schedule_evaluation_cursor",
                    label: "\(scope) legal cursor count"
                )
                try require(
                    legalCursorCount == baselineCounts.1 + 1,
                    "\(scope) legal cursor did not persist"
                )
                let boundaryMessageLength = try requiredInt(
                    database,
                    sql: """
                        SELECT length(errorMessage) FROM schedule_fire
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-legal-failed-original"],
                    label: "\(scope) legal error message boundary"
                )
                try require(
                    boundaryMessageLength == 1_000,
                    "\(scope) legal 1000-character error message drifted"
                )
                let storageClasses = try requiredString(
                    database,
                    sql: """
                        SELECT typeof(scheduledAt) || '|' || typeof(createdAt)
                          || '|' || typeof(redactedAt)
                        FROM schedule_fire
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-legal-redacted-failed"],
                    label: "\(scope) fire date storage classes"
                )
                try require(
                    storageClasses == "real|real|real",
                    "\(scope) fire dates are not numeric REAL values: \(storageClasses)"
                )
                let cursorStorageClasses = try requiredString(
                    database,
                    sql: """
                        SELECT typeof(lastEvaluatedScheduledAt) || '|'
                          || typeof(updatedAt)
                        FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["\(prefix)-schedule"],
                    label: "\(scope) cursor date storage classes"
                )
                try require(
                    cursorStorageClasses == "real|real",
                    "\(scope) cursor dates are not numeric REAL values: \(cursorStorageClasses)"
                )
                let storedScheduledAt = try requiredDouble(
                    database,
                    sql: """
                        SELECT scheduledAt FROM schedule_fire
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-legal-started-original"],
                    label: "\(scope) scheduledAt"
                )
                let storedCreatedAt = try requiredDouble(
                    database,
                    sql: """
                        SELECT createdAt FROM schedule_fire
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-legal-started-original"],
                    label: "\(scope) createdAt"
                )
                let storedCursorAt = try requiredDouble(
                    database,
                    sql: """
                        SELECT lastEvaluatedScheduledAt
                        FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["\(prefix)-schedule"],
                    label: "\(scope) lastEvaluatedScheduledAt"
                )
                let storedUpdatedAt = try requiredDouble(
                    database,
                    sql: """
                        SELECT updatedAt FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["\(prefix)-schedule"],
                    label: "\(scope) cursor updatedAt"
                )
                let storedRedactedAt = try requiredDouble(
                    database,
                    sql: """
                        SELECT redactedAt FROM schedule_fire
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-legal-redacted-failed"],
                    label: "\(scope) redactedAt"
                )
                try require(
                    storedScheduledAt.bitPattern == scheduledSeconds.bitPattern
                        && storedCreatedAt.bitPattern == cursorSeconds.bitPattern
                        && storedCursorAt.bitPattern == cursorSeconds.bitPattern
                        && storedUpdatedAt.bitPattern == updatedSeconds.bitPattern
                        && storedRedactedAt.bitPattern == redactedSeconds.bitPattern,
                    "\(scope) numeric date values did not round-trip exactly"
                )

                try expectDatabaseFailure(
                    "\(scope) intended state",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-intended",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "intended",
                        missionID: "\(prefix)-mission"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) partial replay",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-partial-replay",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        replayOfFireID: "\(prefix)-legal-failed-original",
                        state: "failed",
                        errorCode: "schedule_configuration_invalid"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) original with replay key",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-orphan-replay-key",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        replayIdempotencyKey: "\(prefix)-orphan-key",
                        replayPayloadHash: String(repeating: "a", count: 64),
                        state: "failed",
                        errorCode: "schedule_configuration_invalid"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) short replay hash",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-short-hash",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        replayOfFireID: "\(prefix)-legal-failed-original",
                        replayIdempotencyKey: "\(prefix)-short-hash-key",
                        replayPayloadHash: String(repeating: "a", count: 63),
                        state: "failed",
                        errorCode: "schedule_configuration_invalid"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) started with error",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-started-error",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "started",
                        missionID: "\(prefix)-mission",
                        errorCode: "schedule_configuration_invalid"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) started without mission",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-started-no-mission",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "started"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) failed with mission",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-failed-mission",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "failed",
                        missionID: "\(prefix)-mission",
                        errorCode: "schedule_configuration_invalid"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) failed without code",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-failed-no-code",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "failed"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) overlong error message",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-long-message",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "failed",
                        errorCode: "schedule_configuration_invalid",
                        errorMessage: String(repeating: "x", count: 1_001)
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) redacted error message",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-redacted-message",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "failed",
                        errorCode: "schedule_configuration_invalid",
                        errorMessage: "must be absent after redaction",
                        redactedAt: redactedSeconds
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) cursor version zero",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try database.execute(
                        sql: """
                            INSERT INTO schedule_evaluation_cursor (
                              scheduleId, lastEvaluatedSlotKey,
                              lastEvaluatedScheduledAt, version, updatedAt
                            ) VALUES (?, 'slot-version-zero', ?, 0, ?)
                            """,
                        arguments: [
                            "\(prefix)-cursor-only-schedule",
                            cursorSeconds,
                            updatedSeconds,
                        ]
                    )
                }
                try database.execute(
                    sql: """
                        INSERT INTO schedule_evaluation_cursor (
                          scheduleId, lastEvaluatedSlotKey,
                          lastEvaluatedScheduledAt, version, updatedAt
                        ) VALUES (?, 'slot-cursor-only', ?, 1, ?)
                        """,
                    arguments: [
                        "\(prefix)-cursor-only-schedule",
                        cursorSeconds,
                        updatedSeconds,
                    ]
                )
                try expectDatabaseFailure(
                    "\(scope) duplicate original slot",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_UNIQUE
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-duplicate-original-slot",
                        slotKey: "slot-legal-started-original",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        state: "failed",
                        errorCode: "schedule_configuration_invalid"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) duplicate replay key",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_UNIQUE
                ) {
                    try insertScheduleFireFixture(
                        database,
                        prefix: prefix,
                        id: "illegal-duplicate-replay-key",
                        scheduledAt: scheduledSeconds,
                        createdAt: updatedSeconds,
                        replayOfFireID: "\(prefix)-legal-failed-original",
                        replayIdempotencyKey: "\(prefix)-replay-key",
                        replayPayloadHash: String(repeating: "b", count: 64),
                        state: "failed",
                        errorCode: "schedule_configuration_invalid"
                    )
                }

                for (label, sql, argument) in [
                    (
                        "mission",
                        "DELETE FROM mission WHERE id = ?",
                        "\(prefix)-mission"
                    ),
                    (
                        "schedule",
                        "DELETE FROM schedule WHERE id = ?",
                        "\(prefix)-schedule"
                    ),
                    (
                        "template",
                        "DELETE FROM mission_template WHERE id = ?",
                        "\(prefix)-template"
                    ),
                ] {
                    try expectDatabaseFailure(
                        "\(scope) restricted \(label) deletion",
                        expectedExtendedResultCodes: [
                            .SQLITE_CONSTRAINT_TRIGGER,
                            .SQLITE_CONSTRAINT_FOREIGNKEY,
                        ]
                    ) {
                        try database.execute(sql: sql, arguments: [argument])
                    }
                }
                let retainedCursorCount = try requiredInt(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["\(prefix)-schedule"],
                    label: "\(scope) restricted cursor retention"
                )
                try require(
                    retainedCursorCount == 1,
                    "\(scope) failed parent deletion removed the cursor"
                )
                let cursorOnlyCount = try requiredInt(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["\(prefix)-cursor-only-schedule"],
                    label: "\(scope) cursor-only pre-delete count"
                )
                try require(
                    cursorOnlyCount == 1,
                    "\(scope) cursor-only cascade fixture is missing"
                )
                try database.execute(
                    sql: "DELETE FROM schedule WHERE id = ?",
                    arguments: ["\(prefix)-cursor-only-schedule"]
                )
                let cascadedCursorCount = try requiredInt(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM schedule_evaluation_cursor
                        WHERE scheduleId = ?
                        """,
                    arguments: ["\(prefix)-cursor-only-schedule"],
                    label: "\(scope) cursor cascade count"
                )
                try require(
                    cascadedCursorCount == 0,
                    "\(scope) cursor did not cascade with an unreferenced schedule"
                )

                let foreignKeyCursor = try database.foreignKeyViolations()
                let foreignKeyViolation = try foreignKeyCursor.next()
                try require(
                    foreignKeyViolation == nil,
                    "\(scope) schedule contract has a foreign-key violation"
                )
                let integrity = try requiredString(
                    database,
                    sql: "PRAGMA integrity_check",
                    label: "\(scope) contract integrity_check"
                )
                try require(
                    integrity == "ok",
                    "\(scope) schedule contract integrity_check failed"
                )
                return .rollback
            }
        }

        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "\(scope) schedule contract transaction did not roll back exactly"
        )
        print("schedule_contract.\(scope)=pass")
    }

    private func insertAndValidateAttemptEvent(
        in pool: DatabasePool,
        label: String
    ) throws {
        let prefix = "append_only_" + label.replacingOccurrences(
            of: "-",
            with: "_"
        )
        try pool.write { database in
            try insertValidAttemptEvent(database, prefix: prefix)
        }

        try expectDatabaseFailure("\(label) ordinary UPDATE") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        UPDATE durable_work_attempt_event
                        SET workerId = 'other-worker'
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-event"]
                )
            }
        }
        try expectDatabaseFailure("\(label) no-op UPDATE") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        UPDATE durable_work_attempt_event
                        SET workerId = workerId
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-event"]
                )
            }
        }
        try expectDatabaseFailure("\(label) DELETE") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        DELETE FROM durable_work_attempt_event
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-event"]
                )
            }
        }
        try expectDatabaseFailure("\(label) output outside succeeded") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        UPDATE durable_work
                        SET outputJson = '{"illegal":true}'
                        WHERE id = ?
                        """,
                    arguments: ["\(prefix)-work"]
                )
            }
        }
        try expectDatabaseFailure("\(label) open attempt error") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        UPDATE durable_work_attempt
                        SET errorCode = 'illegal'
                        WHERE workId = ? AND attempt = 1
                        """,
                    arguments: ["\(prefix)-work"]
                )
            }
        }
        try expectDatabaseFailure("\(label) claimed nonzero sequence") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        INSERT INTO durable_work_attempt_event (
                          id, workId, attempt, sequence, eventKind, workerId,
                          workVersion, resultingWorkState, errorCode,
                          errorMessage, occurredAt
                        ) VALUES (?, ?, 1, 1, 'claimed', 'worker', 3,
                                  'running', NULL, NULL, 1000001)
                        """,
                    arguments: [
                        "\(prefix)-invalid-event",
                        "\(prefix)-work",
                    ]
                )
            }
        }

        try pool.read { database in
            let eventCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM durable_work_attempt_event
                    WHERE id = ?
                    """,
                arguments: ["\(prefix)-event"],
                label: "\(label) event count"
            )
            let workerID = try requiredString(
                database,
                sql: """
                    SELECT workerId FROM durable_work_attempt_event
                    WHERE id = ?
                    """,
                arguments: ["\(prefix)-event"],
                label: "\(label) event worker"
            )
            try require(
                eventCount == 1 && workerID == "worker",
                "\(label) append-only event changed"
            )
        }
    }

    private func runRealDurableMigrationRollback() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-real-v12-durable.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(pool, upTo: "v11-cli-kinds")
        try pool.write { database in
            try database.execute(
                sql: "CREATE TABLE durable_work_attempt(sentinel TEXT)"
            )
            try database.execute(
                sql: """
                    INSERT INTO durable_work_attempt(sentinel)
                    VALUES ('preserve-me')
                    """
            )
        }
        let before = try pool.read(stableSnapshot)

        var didFail = false
        do {
            try AppDatabase.migrator.migrate(pool)
        } catch {
            didFail = true
            print("rollback.real_v12_durable.error_type=\(type(of: error))")
        }
        try require(didFail, "real v12 conflict migration succeeded")
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "real v12 failure did not restore byte-stable schema/data snapshot"
        )
        try pool.read { database in
            let hasWork = try database.tableExists("durable_work")
            try require(
                !hasWork,
                "real v12 rollback left durable_work"
            )
            let sentinel = try requiredString(
                database,
                sql: "SELECT sentinel FROM durable_work_attempt",
                label: "rollback sentinel"
            )
            try require(
                sentinel == "preserve-me",
                "real v12 rollback damaged sentinel"
            )
            let v12Count = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v12-p1-durable-work'
                    """,
                label: "rollback v12 count"
            )
            try require(v12Count == 0, "failed v12 was recorded")
        }
        try pool.close()
        print("rollback.real_v12=pass")
        print("rollback.real_v12_durable=pass")
    }

    private func runRealScheduleMigrationRollback() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-real-v12-schedule-fire.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v12-p1-durable-work"
        )
        try pool.write { database in
            try database.execute(
                sql: "CREATE TABLE schedule_fire(sentinel TEXT)"
            )
            try database.execute(
                sql: "INSERT INTO schedule_fire(sentinel) VALUES (?)",
                arguments: ["preserve-me"]
            )
        }
        let before = try pool.read(stableSnapshot)

        var didFail = false
        do {
            try AppDatabase.migrator.migrate(pool)
        } catch {
            didFail = true
            print(
                "rollback.real_v12_schedule_fire.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "real v12 schedule-fire conflict migration succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "real v12 schedule-fire failure changed schema/data snapshot"
        )
        try pool.read { database in
            let hasCursorTable = try database.tableExists(
                "schedule_evaluation_cursor"
            )
            try require(
                !hasCursorTable,
                "real v12 schedule-fire rollback left cursor table"
            )
            let scheduleIndexes = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM sqlite_master
                    WHERE type = 'index'
                      AND name IN (
                        'schedule_fire_original_slot',
                        'schedule_fire_replay_key',
                        'schedule_fire_schedule_time'
                      )
                    """,
                label: "schedule-fire rollback index count"
            )
            try require(
                scheduleIndexes == 0,
                "real v12 schedule-fire rollback left named indexes"
            )
            let sentinel = try requiredString(
                database,
                sql: "SELECT sentinel FROM schedule_fire",
                label: "schedule-fire rollback sentinel"
            )
            try require(
                sentinel == "preserve-me",
                "real v12 schedule-fire rollback damaged sentinel"
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v12-p1-schedule-fire'
                    """,
                label: "schedule-fire rollback migration count"
            )
            try require(
                migrationCount == 0,
                "failed v12 schedule-fire migration was recorded"
            )
            let durableMigrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v12-p1-durable-work'
                    """,
                label: "schedule-fire rollback durable migration count"
            )
            try require(
                durableMigrationCount == 1,
                "schedule-fire rollback damaged durable predecessor"
            )
            let foreignKeyCursor = try database.foreignKeyViolations()
            let foreignKeyViolation = try foreignKeyCursor.next()
            try require(
                foreignKeyViolation == nil,
                "schedule-fire rollback has a foreign-key violation"
            )
            let integrity = try requiredString(
                database,
                sql: "PRAGMA integrity_check",
                label: "schedule-fire rollback integrity_check"
            )
            try require(
                integrity == "ok",
                "schedule-fire rollback integrity_check failed"
            )
        }
        try pool.close()
        print("rollback.real_v12_schedule_fire=pass")
    }

    private func runRealObservabilityMigrationRollback() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-real-v13-observability.sqlite")
        let predecessorPool = try openPool(at: databaseURL)
        try assertRuntime(in: predecessorPool)
        try AppDatabase.migrator.migrate(
            predecessorPool,
            upTo: "v12-p1-schedule-fire"
        )
        try predecessorPool.write { database in
            try insertV12SchedulePredecessor(
                database,
                prefix: "real_v13_rollback"
            )
        }
        try predecessorPool.close()

        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try pool.write { database in
            try database.execute(
                sql: "CREATE INDEX context_degradation_mission ON mission(id)"
            )
        }
        let before = try pool.read(stableSnapshot)
        var didFail = false
        do {
            try AppDatabase.migrator.migrate(
                pool,
                upTo: "v13-p1-observability"
            )
        } catch {
            didFail = true
            print(
                "rollback.real_v13_observability.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "real v13 conflicting-index migration unexpectedly succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "real v13 failure changed the v12-schedule logical snapshot"
        )
        try pool.read { database in
            try requireObservabilityObjectsAbsent(
                database,
                allowedNames: ["context_degradation_mission"]
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v13-p1-observability'
                    """,
                label: "real v13 rollback migration count"
            )
            try require(
                migrationCount == 0,
                "failed v13 migration was recorded"
            )
            try require(
                try indexColumns(
                    database,
                    index: "context_degradation_mission"
                ) == ["id"],
                "real v13 rollback sentinel no longer targets mission(id)"
            )
            try requireDatabaseHealthy(
                database,
                scope: "real v13 rollback"
            )
        }
        try pool.close()
        print("rollback.real_v13_observability=pass")
    }

    private func runLiteralObservabilityMigrationRollback() throws {
        let literalSQL = try loadLiteralObservabilitySQL()
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-literal-v13-observability.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v12-p1-schedule-fire"
        )
        try pool.write { database in
            try insertV12SchedulePredecessor(
                database,
                prefix: "literal_v13_rollback"
            )
        }
        let before = try pool.read(stableSnapshot)
        var didFail = false
        do {
            try pool.writeWithoutTransaction { database in
                try database.inTransaction {
                    try database.execute(sql: literalSQL)
                    try database.execute(
                        sql: "SELECT * FROM __agentloop_forced_missing_table__"
                    )
                    return .commit
                }
            }
        } catch {
            didFail = true
            print(
                "rollback.literal_v13_observability.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "literal v13 forced rollback unexpectedly succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "literal v13 forced rollback changed the v12-schedule snapshot"
        )
        try pool.read { database in
            try requireObservabilityObjectsAbsent(database)
            try requireDatabaseHealthy(
                database,
                scope: "literal v13 rollback"
            )
        }
        try pool.close()
        print("rollback.literal_v13_observability=pass")
    }

    private func runRealControlContractMigrationRollback() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-real-v14-control.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v13-p1-observability"
        )
        try pool.write { database in
            try insertV13ObservabilityPredecessor(
                database,
                prefix: "real_v14_rollback"
            )
            try database.execute(
                sql: "CREATE INDEX domain_event_correlation ON camp(id)"
            )
        }
        let before = try pool.read(stableSnapshot)
        var didFail = false
        do {
            try AppDatabase.migrator.migrate(
                pool,
                upTo: "v14-p1-control-contracts"
            )
        } catch {
            didFail = true
            print(
                "rollback.real_v14_control_contracts.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "real v14 conflicting-index migration unexpectedly succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "real v14 failure changed the v13 logical snapshot"
        )
        try pool.read { database in
            let remainingTables = try sqliteObjectNames(
                database,
                type: "table"
            ).intersection(controlContractTables)
            try require(
                remainingTables.isEmpty,
                "real v14 rollback left control tables \(remainingTables.sorted())"
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v14-p1-control-contracts'
                    """,
                label: "real v14 rollback migration count"
            )
            try require(
                migrationCount == 0,
                "failed real v14 migration was recorded"
            )
            try require(
                try indexColumns(
                    database,
                    index: "domain_event_correlation"
                ) == ["id"],
                "real v14 rollback sentinel no longer targets camp(id)"
            )
            try requireDatabaseHealthy(
                database,
                scope: "real v14 rollback"
            )
        }
        try pool.close()
        print("rollback.real_v14_control_contracts=pass")
    }

    private func runLiteralControlContractMigrationRollback() throws {
        let literalSQL = try loadLiteralControlSQL()
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-literal-v14-control.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v13-p1-observability"
        )
        try pool.write { database in
            try insertV13ObservabilityPredecessor(
                database,
                prefix: "literal_v14_rollback"
            )
            try database.execute(
                sql: "CREATE INDEX domain_event_correlation ON camp(id)"
            )
        }
        let before = try pool.read(stableSnapshot)
        var didFail = false
        do {
            try pool.write { database in
                try database.execute(sql: literalSQL)
            }
        } catch {
            didFail = true
            print(
                "rollback.literal_v14_control_contracts.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "literal v14 conflicting-index migration unexpectedly succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "literal v14 failure changed the v13 logical snapshot"
        )
        try pool.read { database in
            let remainingTables = try sqliteObjectNames(
                database,
                type: "table"
            ).intersection(controlContractTables)
            try require(
                remainingTables.isEmpty,
                "literal v14 rollback left control tables \(remainingTables.sorted())"
            )
            try require(
                try indexColumns(
                    database,
                    index: "domain_event_correlation"
                ) == ["id"],
                "literal v14 rollback sentinel no longer targets camp(id)"
            )
            try requireDatabaseHealthy(
                database,
                scope: "literal v14 rollback"
            )
        }
        try pool.close()
        print("rollback.literal_v14_control_contracts=pass")
    }

    private func runRealOutcomeContractMigrationRollback() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-real-v15-outcome.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v14-p1-control-contracts"
        )
        try pool.write { database in
            try database.execute(
                sql: "CREATE TABLE acceptance_policy_version(id TEXT PRIMARY KEY)"
            )
            try database.execute(
                sql: "INSERT INTO acceptance_policy_version(id) VALUES ('sentinel')"
            )
        }
        let before = try pool.read(stableSnapshot)
        var didFail = false
        do {
            try AppDatabase.migrator.migrate(pool)
        } catch {
            didFail = true
            print(
                "rollback.real_v15_outcome_contracts.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "real v15 conflicting-table migration unexpectedly succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "real v15 failure changed the v14 logical snapshot"
        )
        try validateOutcomeRollbackState(
            in: pool,
            scope: "real v15 rollback"
        )
        try pool.close()
        print("rollback.real_v15_outcome_contracts=pass")
    }

    private func runLiteralOutcomeContractMigrationRollback() throws {
        let literalSQL = try loadLiteralOutcomeSQL()
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-literal-v15-outcome.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v14-p1-control-contracts"
        )
        try pool.write { database in
            try database.execute(
                sql: "CREATE TABLE acceptance_policy_version(id TEXT PRIMARY KEY)"
            )
            try database.execute(
                sql: "INSERT INTO acceptance_policy_version(id) VALUES ('sentinel')"
            )
        }
        let before = try pool.read(stableSnapshot)
        var didFail = false
        do {
            try pool.writeWithoutTransaction { database in
                try database.inTransaction {
                    try database.execute(sql: literalSQL)
                    return .commit
                }
            }
        } catch {
            didFail = true
            print(
                "rollback.literal_v15_outcome_contracts.error_type=\(type(of: error))"
            )
        }
        try require(
            didFail,
            "literal v15 conflicting-table migration unexpectedly succeeded"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "literal v15 failure changed the v14 logical snapshot"
        )
        try validateOutcomeRollbackState(
            in: pool,
            scope: "literal v15 rollback"
        )
        try pool.close()
        print("rollback.literal_v15_outcome_contracts=pass")
    }

    private func validateOutcomeRollbackState(
        in pool: DatabasePool,
        scope: String
    ) throws {
        try pool.read { database in
            let remainingTables = try sqliteObjectNames(
                database,
                type: "table"
            ).intersection(outcomeContractTables)
            try require(
                remainingTables == ["acceptance_policy_version"],
                "\(scope) left outcome tables \(remainingTables.sorted())"
            )
            let sentinelRows = try String.fetchAll(
                database,
                sql: "SELECT id FROM acceptance_policy_version ORDER BY id"
            )
            try require(
                sentinelRows == ["sentinel"],
                "\(scope) changed the sentinel table"
            )
            let introducedObjectCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM sqlite_master
                    WHERE (type = 'index' OR type = 'trigger')
                      AND tbl_name IN (
                        'outcome_contract_version',
                        'verification_requirement_group',
                        'verification_requirement',
                        'outcome', 'outcome_version', 'verification_record',
                        'verification_result_head',
                        'verification_invalidation', 'acceptance_record',
                        'outcome_metric_credit', 'approval_grant',
                        'approval_grant_use', 'external_operation_receipt'
                      )
                    """,
                label: "\(scope) introduced object count"
            )
            try require(
                introducedObjectCount == 0,
                "\(scope) left \(introducedObjectCount) v15 indexes/triggers"
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v15-p1-outcome-contracts'
                    """,
                label: "\(scope) v15 migration count"
            )
            try require(
                migrationCount == 0,
                "\(scope) recorded the failed v15 migration"
            )
            try requireDatabaseHealthy(database, scope: scope)
        }
    }

    private func runIntroductionGuardRollback() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-introduction-guard.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(pool)
        try pool.write { database in
            try insertValidAttemptEvent(database, prefix: "guard_rollback")
        }
        let before = try pool.read(stableSnapshot)

        var failingMigrator = AppDatabase.migrator
        failingMigrator.registerMigration(
            "p1-matrix-injected-append-only-failure"
        ) { database in
            try database.execute(
                sql: "CREATE TABLE p1_matrix_must_rollback(value TEXT)"
            )
            try database.execute(
                sql: """
                    UPDATE durable_work_attempt_event
                    SET workerId = workerId
                    WHERE id = 'guard_rollback-event'
                    """
            )
        }

        var didFail = false
        do {
            try failingMigrator.migrate(pool)
        } catch {
            didFail = true
            print("rollback.introduction_guard.error_type=\(type(of: error))")
        }
        try require(
            didFail,
            "append-only guard did not abort injected migration"
        )
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "guard-triggered migration failure changed schema/data snapshot"
        )
        try pool.read { database in
            let hasInjectedTable = try database.tableExists(
                "p1_matrix_must_rollback"
            )
            try require(
                !hasInjectedTable,
                "guard rollback left injected table"
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier =
                      'p1-matrix-injected-append-only-failure'
                    """,
                label: "injected migration count"
            )
            try require(
                migrationCount == 0,
                "failed injected migration was recorded"
            )
        }
        try expectDatabaseFailure("guard retained after rollback") {
            try pool.write { database in
                try database.execute(
                    sql: """
                        DELETE FROM durable_work_attempt_event
                        WHERE id = 'guard_rollback-event'
                        """
                )
            }
        }
        try pool.close()
        print("rollback.introduction_guard=pass")
    }

    private func runRealEngineCoordinationTriggerRollback(
        v16Objects: SQLiteObjectSet
    ) throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-real-v17-engine-coordination.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v16-p1-identity-memory"
        )
        try installV17LastTriggerConflict(in: pool)
        let before = try pool.read(stableSnapshot)
        var failed = false
        do {
            try AppDatabase.migrator.migrate(pool)
        } catch {
            failed = true
            print("rollback.real_v17_engine_coordination.error_type=\(type(of: error))")
        }
        try require(
            failed,
            "real v17 last-trigger rollback unexpectedly succeeded"
        )
        try validateV17LastTriggerRollbackState(
            in: pool,
            scope: "real v17 last-trigger rollback",
            before: before,
            v16Objects: v16Objects
        )
        try pool.close()
        print("rollback.real_v17_engine_coordination=pass")
    }

    private func runLiteralEngineCoordinationTriggerRollback(
        v16Objects: SQLiteObjectSet
    ) throws {
        let literalSQL = try loadLiteralEngineCoordinationSQL()
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("rollback-literal-v17-engine-coordination.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v16-p1-identity-memory"
        )
        try installV17LastTriggerConflict(in: pool)
        let before = try pool.read(stableSnapshot)
        var failed = false
        do {
            try pool.write { database in
                try database.execute(sql: literalSQL)
            }
        } catch {
            failed = true
            print("rollback.literal_v17_engine_coordination.error_type=\(type(of: error))")
        }
        try require(
            failed,
            "literal v17 last-trigger rollback unexpectedly succeeded"
        )
        try validateV17LastTriggerRollbackState(
            in: pool,
            scope: "literal v17 last-trigger rollback",
            before: before,
            v16Objects: v16Objects
        )
        try pool.close()
        print("rollback.literal_v17_engine_coordination=pass")
    }

    private func installV17LastTriggerConflict(
        in pool: DatabasePool
    ) throws {
        try pool.write { database in
            try database.execute(
                sql: """
                    CREATE TRIGGER discussion_turn_reject_delete
                    BEFORE DELETE ON camp
                    BEGIN
                      SELECT 1;
                    END;
                    """
            )
        }
    }

    private func validateV17LastTriggerRollbackState(
        in pool: DatabasePool,
        scope: String,
        before: String,
        v16Objects: SQLiteObjectSet
    ) throws {
        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "\(scope) changed the v16 logical snapshot"
        )
        try pool.read { database in
            let objects = try sqliteObjectSet(database)
            let expectedObjects = SQLiteObjectSet(
                tables: v16Objects.tables,
                indexes: v16Objects.indexes,
                triggers: v16Objects.triggers.union([
                    "discussion_turn_reject_delete",
                ])
            )
            try require(
                objects == expectedObjects,
                "\(scope) retained partial v17 objects"
            )
            let sentinelTable = try requiredString(
                database,
                sql: "SELECT tbl_name FROM sqlite_master WHERE type='trigger' AND name='discussion_turn_reject_delete'",
                label: "\(scope) conflict sentinel table"
            )
            try require(
                sentinelTable == "camp",
                "\(scope) conflict sentinel was replaced"
            )
            let v17MigrationCount = try requiredInt(
                database,
                sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v17-p1-engine-coordination'",
                label: "\(scope) v17 migration count"
            )
            try require(
                v17MigrationCount == 0,
                "\(scope) retained the v17 migration record"
            )
            try require(
                engineCoordinationTables.intersection(objects.tables).isEmpty,
                "\(scope) retained v17 tables"
            )
            try require(
                engineCoordinationExplicitIndexes
                    .intersection(objects.indexes).isEmpty,
                "\(scope) retained v17 indexes"
            )
            let nonSentinelTriggers = engineCoordinationTriggers.subtracting([
                "discussion_turn_reject_delete",
            ])
            try require(
                nonSentinelTriggers.intersection(objects.triggers).isEmpty,
                "\(scope) retained pre-conflict v17 triggers"
            )
            try requireDatabaseHealthy(database, scope: scope)
        }
    }

    private func loadLiteralScheduleSQL() throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: arguments.literalSchema.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw MatrixError.assertion(
                "literal schema is missing: \(arguments.literalSchema.path)"
            )
        }
        let literalSQL = try String(
            contentsOf: arguments.literalSchema,
            encoding: .utf8
        )
        try require(!literalSQL.isEmpty, "literal schema is empty")
        return literalSQL
    }

    private func loadLiteralObservabilitySQL() throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: arguments.literalObservabilitySchema.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw MatrixError.assertion(
                "literal observability schema is missing: \(arguments.literalObservabilitySchema.path)"
            )
        }
        let literalSQL = try String(
            contentsOf: arguments.literalObservabilitySchema,
            encoding: .utf8
        )
        try require(
            !literalSQL.isEmpty,
            "literal observability schema is empty"
        )
        return literalSQL
    }

    private func loadLiteralControlSQL() throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: arguments.literalControlSchema.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw MatrixError.assertion(
                "literal control schema is missing: \(arguments.literalControlSchema.path)"
            )
        }
        let literalSQL = try String(
            contentsOf: arguments.literalControlSchema,
            encoding: .utf8
        )
        try require(!literalSQL.isEmpty, "literal control schema is empty")
        return literalSQL
    }

    private func loadLiteralOutcomeSQL() throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: arguments.literalOutcomeSchema.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw MatrixError.assertion(
                "literal outcome schema is missing: \(arguments.literalOutcomeSchema.path)"
            )
        }
        let literalSQL = try String(
            contentsOf: arguments.literalOutcomeSchema,
            encoding: .utf8
        )
        try require(!literalSQL.isEmpty, "literal outcome schema is empty")
        return literalSQL
    }

    private func loadLiteralIdentityMemorySQL() throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: arguments.literalIdentityMemorySchema.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw MatrixError.assertion(
                "literal identity-memory schema is missing: \(arguments.literalIdentityMemorySchema.path)"
            )
        }
        let literalSQL = try String(
            contentsOf: arguments.literalIdentityMemorySchema,
            encoding: .utf8
        )
        try require(!literalSQL.isEmpty, "literal identity-memory schema is empty")
        return literalSQL
    }

    private func loadLiteralEngineCoordinationSQL() throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: arguments.literalEngineCoordinationSchema.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw MatrixError.assertion(
                "literal engine-coordination schema is missing: \(arguments.literalEngineCoordinationSchema.path)"
            )
        }
        let literalSQL = try String(
            contentsOf: arguments.literalEngineCoordinationSchema,
            encoding: .utf8
        )
        try require(
            !literalSQL.isEmpty,
            "literal engine-coordination schema is empty"
        )
        try require(
            literalSQL == p1F1EngineCoordinationMigrationSQL,
            "runtime v17 SQL differs from literal Stage §18.7"
        )
        return literalSQL
    }

    private func prepareLiteralScheduleSchemaShape() throws
        -> CanonicalSchemaShapes
    {
        let literalSQL = try loadLiteralScheduleSQL()
        let observabilitySQL = try loadLiteralObservabilitySQL()
        let controlSQL = try loadLiteralControlSQL()
        let outcomeSQL = try loadLiteralOutcomeSQL()
        let identityMemorySQL = try loadLiteralIdentityMemorySQL()
        let engineCoordinationSQL = try loadLiteralEngineCoordinationSQL()
        let queue = try DatabaseQueue()
        let version = try queue.read { database in
            try requiredString(
                database,
                sql: "SELECT sqlite_version()",
                label: "literal schema reference sqlite_version"
            )
        }
        try require(
            version == arguments.expectedSQLiteVersion,
            "literal schema reference sqlite_version \(version) != expected \(arguments.expectedSQLiteVersion)"
        )
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "v12-p1-durable-work"
        )
        try queue.write { database in
            try database.execute(sql: literalSQL)
            try database.execute(sql: observabilitySQL)
            try database.execute(sql: controlSQL)
            try database.execute(sql: outcomeSQL)
            try database.execute(sql: identityMemorySQL)
        }
        let throughV16 = try queue.read(scheduleSchemaShape)
        try queue.write { database in
            try database.execute(sql: engineCoordinationSQL)
        }
        let throughV17 = try queue.read(scheduleSchemaShape)
        try queue.close()
        print("literal_schedule_schema_shape=bound")
        return CanonicalSchemaShapes(
            throughV16: throughV16,
            throughV17: throughV17
        )
    }

    private func prepareLiteralControlSchemaShape() throws -> String {
        let scheduleSQL = try loadLiteralScheduleSQL()
        let observabilitySQL = try loadLiteralObservabilitySQL()
        let controlSQL = try loadLiteralControlSQL()
        let queue = try DatabaseQueue()
        let version = try queue.read { database in
            try requiredString(
                database,
                sql: "SELECT sqlite_version()",
                label: "literal control reference sqlite_version"
            )
        }
        try require(
            version == arguments.expectedSQLiteVersion,
            "literal control reference sqlite_version \(version) != expected \(arguments.expectedSQLiteVersion)"
        )
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "v12-p1-durable-work"
        )
        try queue.write { database in
            try database.execute(sql: scheduleSQL)
            try database.execute(sql: observabilitySQL)
            try database.execute(sql: controlSQL)
        }
        let shape = try queue.read(controlSchemaShape)
        try queue.close()
        print("literal_control_schema_shape=bound")
        return shape
    }

    private func prepareV13ObjectSet() throws -> SQLiteObjectSet {
        let queue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "v13-p1-observability"
        )
        let objects = try queue.read(sqliteObjectSet)
        try queue.close()
        return objects
    }

    private func prepareLiteralOutcomeContractSchemaReference() throws
        -> OutcomeContractSchemaReference
    {
        let literalSQL = try loadLiteralOutcomeSQL()
        let identityMemorySQL = try loadLiteralIdentityMemorySQL()
        let queue = try DatabaseQueue()
        let version = try queue.read { database in
            try requiredString(
                database,
                sql: "SELECT sqlite_version()",
                label: "literal outcome reference sqlite_version"
            )
        }
        try require(
            version == arguments.expectedSQLiteVersion,
            "literal outcome reference sqlite_version \(version) != expected \(arguments.expectedSQLiteVersion)"
        )
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "v14-p1-control-contracts"
        )
        let v14Objects = try queue.read(sqliteObjectSet)
        try queue.write { database in
            try database.execute(sql: literalSQL)
        }
        let v15Objects = try queue.read(sqliteObjectSet)
        try require(
            v15Objects.tables == v14Objects.tables.union(outcomeContractTables),
            "literal v15 table name set drifted: \(v15Objects.tables.subtracting(v14Objects.tables).sorted())"
        )
        let introducedIndexes = v15Objects.indexes.subtracting(
            v14Objects.indexes
        )
        let introducedTriggers = v15Objects.triggers.subtracting(
            v14Objects.triggers
        )
        try require(
            v15Objects.tables.count == 55
                && v15Objects.indexes.count == 134
                && v15Objects.triggers.count == 16,
            "literal v15 checkpoint is \(v15Objects.tables.count)/\(v15Objects.indexes.count)/\(v15Objects.triggers.count), expected 55/134/16"
        )
        try require(
            introducedIndexes.count == 40,
            "literal v15 introduced \(introducedIndexes.count) indexes including autoindexes, expected 40"
        )
        try require(
            introducedTriggers.count == 8,
            "literal v15 introduced \(introducedTriggers.count) triggers, expected 8"
        )
        try queue.write { database in
            try database.execute(sql: identityMemorySQL)
        }
        let finalObjects = try queue.read(sqliteObjectSet)
        try require(
            finalObjects.tables.count == 67
                && finalObjects.indexes.count == 171
                && finalObjects.triggers.count == 67,
            "literal v16 checkpoint is \(finalObjects.tables.count)/\(finalObjects.indexes.count)/\(finalObjects.triggers.count), expected 67/171/67"
        )
        let v16OutcomeTriggers = introducedTriggers
            .subtracting([
                "verification_record_reject_update",
                "acceptance_record_reject_update",
                "external_operation_receipt_reject_update",
            ])
            .union([
                "verification_record_reject_update_except_camp_redaction",
                "acceptance_record_reject_update_except_camp_redaction",
                "external_operation_receipt_reject_update_except_camp_redaction",
            ])
        try require(
            v16OutcomeTriggers.count == 8
                && v16OutcomeTriggers.isSubset(of: finalObjects.triggers),
            "literal v16 mapped outcome trigger set drifted"
        )
        let schemaShape = try queue.read { database in
            try selectedSchemaShape(
                database,
                tables: outcomeContractTables,
                indexes: introducedIndexes,
                triggers: v16OutcomeTriggers
            )
        }
        try queue.close()
        print("literal_outcome_schema_shape=bound")
        return OutcomeContractSchemaReference(
            finalObjects: finalObjects,
            introducedIndexes: introducedIndexes,
            introducedTriggers: v16OutcomeTriggers,
            schemaShape: schemaShape
        )
    }

    private func prepareLiteralEngineCoordinationSchemaReference(
        v16Objects: SQLiteObjectSet
    ) throws -> EngineCoordinationSchemaReference {
        let literalSQL = try loadLiteralEngineCoordinationSQL()
        let queue = try DatabaseQueue()
        let version = try queue.read { database in
            try requiredString(
                database,
                sql: "SELECT sqlite_version()",
                label: "literal engine-coordination reference sqlite_version"
            )
        }
        try require(
            version == arguments.expectedSQLiteVersion,
            "literal engine-coordination reference sqlite_version \(version) != expected \(arguments.expectedSQLiteVersion)"
        )
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "v16-p1-identity-memory"
        )
        let actualV16Objects = try queue.read(sqliteObjectSet)
        try require(
            actualV16Objects == v16Objects,
            "real v16 object set differs from literal Stage §18.6"
        )
        try queue.write { database in
            let artifactCount = try requiredInt(
                database,
                sql: "SELECT COUNT(*) FROM artifact",
                label: "literal v17 reference legacy artifact count"
            )
            try require(
                artifactCount == 0,
                "literal v17 reference must begin with zero legacy artifacts"
            )
            try database.execute(sql: literalSQL)
        }
        let finalObjects = try queue.read(sqliteObjectSet)
        let introducedIndexes = finalObjects.indexes.subtracting(
            actualV16Objects.indexes
        )
        let introducedTriggers = finalObjects.triggers.subtracting(
            actualV16Objects.triggers
        )
        try require(
            finalObjects.tables
                == actualV16Objects.tables.union(engineCoordinationTables),
            "literal v17 table name set drifted"
        )
        try require(
            finalObjects.tables.count == 79
                && finalObjects.indexes.count == 208
                && finalObjects.triggers.count == 84,
            "literal v17 checkpoint is \(finalObjects.tables.count)/\(finalObjects.indexes.count)/\(finalObjects.triggers.count), expected 79/208/84"
        )
        try require(
            introducedIndexes.count == 37,
            "literal v17 introduced \(introducedIndexes.count) indexes including autoindexes, expected 37"
        )
        try require(
            engineCoordinationExplicitIndexes.isSubset(of: introducedIndexes),
            "literal v17 missing named indexes: \(engineCoordinationExplicitIndexes.subtracting(introducedIndexes).sorted())"
        )
        try require(
            introducedTriggers == engineCoordinationTriggers,
            "literal v17 trigger set drifted: \(introducedTriggers.sorted())"
        )
        let schemaShape = try queue.read { database in
            try selectedSchemaShape(
                database,
                tables: engineCoordinationTables,
                indexes: introducedIndexes,
                triggers: engineCoordinationTriggers
            )
        }
        try queue.read { database in
            try requireDatabaseHealthy(
                database,
                scope: "literal v17 engine-coordination reference"
            )
        }
        try queue.close()
        print("literal_engine_coordination_schema_shape=bound")
        return EngineCoordinationSchemaReference(
            finalObjects: finalObjects,
            introducedIndexes: introducedIndexes,
            schemaShape: schemaShape
        )
    }

    private func prepareLiteralV12DurableBaseline() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("literal-v12-durable.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v12-p1-durable-work"
        )
        _ = try pool.writeWithoutTransaction { database in
            try database.checkpoint(.truncate)
        }
        try pool.close()
        print("literal_v12_durable.path=\(databaseURL.path)")
    }

    private func prepareLiteralV11Baseline() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("literal-v11-cli-kinds.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v11-cli-kinds"
        )
        _ = try pool.writeWithoutTransaction { database in
            try database.checkpoint(.truncate)
        }
        try pool.close()

        let reopenedPool = try openPool(at: databaseURL)
        try assertRuntime(in: reopenedPool)
        try reopenedPool.read { database in
            try requireObservabilityObjectsAbsent(database)
        }
        try reopenedPool.close()
        print("literal_v11_cli_kinds.path=\(databaseURL.path)")
    }

    private func prepareLiteralV15OutcomeBaseline() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("literal-v15-outcome.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v15-p1-outcome-contracts"
        )
        _ = try pool.writeWithoutTransaction { database in
            try database.checkpoint(.truncate)
        }
        try pool.close()
        print("literal_v15_outcome.path=\(databaseURL.path)")
    }

    private func prepareLiteralV16IdentityMemoryBaseline() throws {
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("literal-v16-identity-memory.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v16-p1-identity-memory"
        )
        try pool.read { database in
            let objects = try sqliteObjectSet(database)
            try require(
                objects.tables.count == 67
                    && objects.indexes.count == 171
                    && objects.triggers.count == 67,
                "literal v16 baseline is \(objects.tables.count)/\(objects.indexes.count)/\(objects.triggers.count), expected 67/171/67"
            )
            let artifactCount = try requiredInt(
                database,
                sql: "SELECT COUNT(*) FROM artifact",
                label: "literal v16 baseline artifact count"
            )
            try require(
                artifactCount == 0,
                "literal v16 baseline contains legacy artifacts"
            )
            try requireDatabaseHealthy(
                database,
                scope: "literal v16 identity-memory baseline"
            )
        }
        _ = try pool.writeWithoutTransaction { database in
            try database.checkpoint(.truncate)
        }
        try pool.close()
        print("literal_v16_identity_memory.path=\(databaseURL.path)")
    }

    private func runLiteralDiagnostics(
        canonicalScheduleSchemaShape: String,
        canonicalControlSchemaShape: String,
        v13Objects: SQLiteObjectSet,
        outcomeReference: OutcomeContractSchemaReference
    ) throws {
        let literalSQL = try loadLiteralScheduleSQL()
        let observabilitySQL = try loadLiteralObservabilitySQL()
        let controlSQL = try loadLiteralControlSQL()
        let outcomeSQL = try loadLiteralOutcomeSQL()
        let identityMemorySQL = try loadLiteralIdentityMemorySQL()
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("literal-diagnostics.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v12-p1-durable-work"
        )
        try pool.write { database in
            try database.execute(sql: literalSQL)
            try database.execute(sql: observabilitySQL)
            try database.execute(sql: controlSQL)
            try database.execute(sql: outcomeSQL)
            try database.execute(sql: identityMemorySQL)
        }
        try validateScheduleFireSchema(
            in: pool,
            scope: "literal",
            expectedDurableRowCounts: MatrixDiagnosticRowCounts(
                work: 0,
                attempt: 0,
                event: 0
            ),
            expectedScheduleFireRowCount: 0,
            expectedScheduleCursorRowCount: 0,
            expectedScheduleMigrationCount: 0,
            expectedObservabilityMigrationCount: 0,
            expectedFailureRecordCount: 0,
            expectedContextDegradationCount: 0,
            canonicalScheduleSchemaShape: canonicalScheduleSchemaShape
        )
        try validateScheduleFireContract(in: pool, scope: "literal")
        try validateV12Diagnostics(in: pool, scope: "literal")
        try validateObservabilityContract(in: pool, scope: "literal")
        try validateControlContract(
            in: pool,
            scope: "literal",
            canonicalSchemaShape: canonicalControlSchemaShape,
            v13Objects: v13Objects,
            expectedMigrationCount: 0,
            expectedMigrationSuffix: []
        )
        try validateOutcomeContract(
            in: pool,
            scope: "literal",
            reference: outcomeReference,
            expectedObjects: outcomeReference.finalObjects,
            expectedMigrationCount: 0,
            expectedMigrationSuffix: []
        )
        try validateIdentityMemoryMigration(
            in: pool,
            scope: "literal",
            expectedObjects: outcomeReference.finalObjects,
            expectedMigrationCount: 0,
            expectedMigrationSuffix: []
        )
        let finalHealth = try pool.read(matrixDiagnosticHealth)
        try requireMatrixDiagnosticHealth(
            finalHealth,
            scope: "literal",
            phase: "final"
        )
        try pool.close()
        print("literal_observability_schema_shape=bound")
        print("observability_contract.literal=pass")
        print("control_contract.literal=pass")
        print("outcome_contract.literal=pass")
        print("identity_memory_contract.literal=pass")
    }

    private func runLiteralEngineCoordinationDiagnostics(
        engineReference: EngineCoordinationSchemaReference
    ) throws {
        let literalSQL = try loadLiteralEngineCoordinationSQL()
        let databaseURL = arguments.outputRoot
            .appendingPathComponent("literal-engine-coordination.sqlite")
        let pool = try openPool(at: databaseURL)
        try assertRuntime(in: pool)
        try AppDatabase.migrator.migrate(
            pool,
            upTo: "v16-p1-identity-memory"
        )
        try pool.write { database in
            let artifactCount = try requiredInt(
                database,
                sql: "SELECT COUNT(*) FROM artifact",
                label: "literal engine-coordination artifact count"
            )
            try require(
                artifactCount == 0,
                "literal engine-coordination carrier requires an empty artifact predecessor"
            )
            try database.execute(sql: literalSQL)
        }
        try validateEngineCoordinationMigration(
            in: pool,
            scope: "literal",
            reference: engineReference,
            expectedMigrationCount: 0
        )
        try pool.close()
        print("engine_coordination_contract.literal=pass")
    }

    private func validateObservabilityContract(
        in pool: DatabasePool,
        scope: String
    ) throws {
        let prefix = "observability_" + scope
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        let firstSeenAt = Double(bitPattern: 0x41d954fc40000001)
        let lastSeenAt = Double(bitPattern: 0x41d954fc40000002)
        let resolvedAt = Double(bitPattern: 0x41d954fc40000003)
        let redactedAt = Double(bitPattern: 0x41d954fc40000004)
        let before = try pool.read(stableSnapshot)

        try pool.writeWithoutTransaction { database in
            try database.inSavepoint {
                try requireColumns(
                    database,
                    table: "failure_record",
                    expected: [
                        "id", "operation", "scopeKind", "campId",
                        "scopeType", "scopeId", "severity", "errorCode",
                        "userMessage", "diagnosticJson", "state",
                        "firstSeenAt", "lastSeenAt", "occurrenceCount",
                        "resolvedAt", "redactedAt",
                    ]
                )
                try requireColumns(
                    database,
                    table: "context_degradation",
                    expected: [
                        "id", "missionId", "cardId", "dependencyType",
                        "dependencyId", "policy", "traceId", "detail",
                        "createdAt", "redactedAt",
                    ]
                )
                try require(
                    try foreignKeyShapes(
                        database,
                        table: "failure_record"
                    ) == ["campId|camp|id|RESTRICT"],
                    "\(scope) failure_record foreign keys drifted"
                )
                try require(
                    try foreignKeyShapes(
                        database,
                        table: "context_degradation"
                    ) == [
                        "cardId|card|id|RESTRICT",
                        "missionId|mission|id|RESTRICT",
                    ],
                    "\(scope) context_degradation foreign keys drifted"
                )
                try require(
                    try indexColumns(
                        database,
                        index: "failure_record_open_scope"
                    ) == [
                        "scopeKind", "campId", "state", "scopeType",
                        "scopeId", "lastSeenAt",
                    ],
                    "\(scope) failure_record_open_scope drifted"
                )
                try require(
                    try indexColumns(
                        database,
                        index: "context_degradation_mission"
                    ) == ["missionId", "createdAt"],
                    "\(scope) context_degradation_mission drifted"
                )
                try require(
                    try indexColumns(
                        database,
                        index: "context_degradation_card"
                    ) == ["cardId", "createdAt"],
                    "\(scope) context_degradation_card drifted"
                )

                let failureDDL = try requiredString(
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
                    try require(
                        failureDDL.contains(fragment),
                        "\(scope) failure_record DDL missing \(fragment)"
                    )
                }
                let degradationDDL = try requiredString(
                    database,
                    sql: """
                        SELECT sql FROM sqlite_master
                        WHERE type = 'table'
                          AND name = 'context_degradation'
                        """,
                    label: "\(scope) context_degradation DDL"
                )
                for fragment in [
                    "policy IN ('required','optionalApproved')",
                    "length(detail) <= 1000",
                    "missionId IS NOT NULL OR cardId IS NOT NULL",
                    "redactedAt IS NULL OR detail = '[deleted]'",
                ] {
                    try require(
                        degradationDDL.contains(fragment),
                        "\(scope) context_degradation DDL missing \(fragment)"
                    )
                }
                try require(
                    !degradationDDL.contains(
                        "missionId IS NULL OR cardId IS NULL"
                    ),
                    "\(scope) context_degradation added a forbidden XOR"
                )

                try insertScheduleFireScopeFixture(
                    database,
                    prefix: prefix,
                    timestamp: firstSeenAt
                )
                try database.execute(
                    sql: """
                        INSERT INTO card (
                          id, missionId, idemKey, title, descriptionText,
                          expectedOutput, assigneeId, status,
                          blockedReasonJson, dependsOnJson, handoffJson,
                          stage, reviewFlag, maxTurns, tokenBudget, createdAt
                        ) VALUES (?, ?, ?, 'Card', 'Description', 'Output',
                                  NULL, 'pending', NULL, '[]', NULL, 1, NULL,
                                  10, 1000, ?)
                        """,
                    arguments: [
                        "\(prefix)-card",
                        "\(prefix)-mission",
                        "\(prefix)-card-idempotency",
                        firstSeenAt,
                    ]
                )

                for (tag, scopeKind, campID, state) in [
                    ("camp-open", "camp", "\(prefix)-camp", "open"),
                    ("camp-resolved", "camp", "\(prefix)-camp", "resolved"),
                    ("global-open", "global", nil, "open"),
                    ("global-resolved", "global", nil, "resolved"),
                ] as [(String, String, String?, String)] {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-\(tag)",
                        scopeKind: scopeKind,
                        campID: campID,
                        userMessage: tag == "camp-open"
                            ? String(repeating: "界", count: 1_000)
                            : tag,
                        state: state,
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt,
                        resolvedAt: state == "resolved" ? resolvedAt : nil
                    )
                }
                for severity in ["info", "warning", "error", "critical"] {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-severity-\(severity)",
                        scopeKind: "camp",
                        campID: "\(prefix)-camp",
                        severity: severity,
                        userMessage: severity,
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
                try insertObservabilityFailure(
                    database,
                    id: "\(prefix)-redacted",
                    scopeKind: "camp",
                    campID: "\(prefix)-camp",
                    userMessage: "[deleted]",
                    diagnosticJSON: "{}",
                    state: "resolved",
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt,
                    resolvedAt: resolvedAt,
                    redactedAt: redactedAt
                )

                try insertObservabilityDegradation(
                    database,
                    id: "\(prefix)-mission-required",
                    missionID: "\(prefix)-mission",
                    policy: "required",
                    detail: String(repeating: "界", count: 1_000),
                    createdAt: firstSeenAt
                )
                try insertObservabilityDegradation(
                    database,
                    id: "\(prefix)-card-optional",
                    cardID: "\(prefix)-card",
                    policy: "optionalApproved",
                    detail: "card optional",
                    createdAt: lastSeenAt
                )
                try insertObservabilityDegradation(
                    database,
                    id: "\(prefix)-both-required",
                    missionID: "\(prefix)-mission",
                    cardID: "\(prefix)-card",
                    policy: "required",
                    detail: "both legal",
                    createdAt: resolvedAt
                )
                try insertObservabilityDegradation(
                    database,
                    id: "\(prefix)-degradation-redacted",
                    cardID: "\(prefix)-card",
                    policy: "optionalApproved",
                    detail: "[deleted]",
                    createdAt: resolvedAt,
                    redactedAt: redactedAt
                )

                let dateRow = try Row.fetchOne(
                    database,
                    sql: """
                        SELECT firstSeenAt, lastSeenAt, resolvedAt, redactedAt
                        FROM failure_record WHERE id = ?
                        """,
                    arguments: ["\(prefix)-redacted"]
                )
                guard let dateRow else {
                    throw MatrixError.assertion(
                        "\(scope) missing observability date row"
                    )
                }
                let storedFirst: Double = dateRow["firstSeenAt"]
                let storedLast: Double = dateRow["lastSeenAt"]
                let storedResolved: Double = dateRow["resolvedAt"]
                let storedRedacted: Double = dateRow["redactedAt"]
                try require(
                    storedFirst.bitPattern == firstSeenAt.bitPattern
                        && storedLast.bitPattern == lastSeenAt.bitPattern
                        && storedResolved.bitPattern == resolvedAt.bitPattern
                        && storedRedacted.bitPattern == redactedAt.bitPattern,
                    "\(scope) observability dates did not round-trip"
                )

                try expectDatabaseFailure(
                    "\(scope) invalid failure scope",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-invalid-scope",
                        scopeKind: "owner",
                        userMessage: "invalid",
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) camp without id",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-camp-without-id",
                        scopeKind: "camp",
                        userMessage: "invalid",
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) global with id",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-global-with-id",
                        scopeKind: "global",
                        campID: "\(prefix)-camp",
                        userMessage: "invalid",
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
                for (tag, severity, state, count) in [
                    ("severity", "fatal", "open", 1),
                    ("state", "error", "closed", 1),
                    ("occurrence", "error", "open", 0),
                ] {
                    try expectDatabaseFailure(
                        "\(scope) invalid \(tag)",
                        expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                    ) {
                        try insertObservabilityFailure(
                            database,
                            id: "\(prefix)-invalid-\(tag)",
                            scopeKind: "camp",
                            campID: "\(prefix)-camp",
                            severity: severity,
                            userMessage: "invalid",
                            state: state,
                            occurrenceCount: count,
                            firstSeenAt: firstSeenAt,
                            lastSeenAt: lastSeenAt
                        )
                    }
                }
                try expectDatabaseFailure(
                    "\(scope) overlong failure message",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-overlong-failure",
                        scopeKind: "camp",
                        campID: "\(prefix)-camp",
                        userMessage: String(repeating: "界", count: 1_001),
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) global redaction",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-global-redacted",
                        scopeKind: "global",
                        userMessage: "[deleted]",
                        diagnosticJSON: "{}",
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt,
                        redactedAt: redactedAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) invalid failure camp foreign key",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_FOREIGNKEY
                ) {
                    try insertObservabilityFailure(
                        database,
                        id: "\(prefix)-missing-camp",
                        scopeKind: "camp",
                        campID: "\(prefix)-missing-camp",
                        userMessage: "invalid",
                        firstSeenAt: firstSeenAt,
                        lastSeenAt: lastSeenAt
                    )
                }

                try expectDatabaseFailure(
                    "\(scope) degradation without owner",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityDegradation(
                        database,
                        id: "\(prefix)-no-owner",
                        policy: "required",
                        detail: "invalid",
                        createdAt: firstSeenAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) invalid degradation policy",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityDegradation(
                        database,
                        id: "\(prefix)-invalid-policy",
                        missionID: "\(prefix)-mission",
                        policy: "optional",
                        detail: "invalid",
                        createdAt: firstSeenAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) overlong degradation detail",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityDegradation(
                        database,
                        id: "\(prefix)-overlong-degradation",
                        missionID: "\(prefix)-mission",
                        policy: "required",
                        detail: String(repeating: "界", count: 1_001),
                        createdAt: firstSeenAt
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) invalid degradation redaction",
                    expectedExtendedResultCode: .SQLITE_CONSTRAINT_CHECK
                ) {
                    try insertObservabilityDegradation(
                        database,
                        id: "\(prefix)-bad-redaction",
                        missionID: "\(prefix)-mission",
                        policy: "required",
                        detail: "visible",
                        createdAt: firstSeenAt,
                        redactedAt: redactedAt
                    )
                }
                for (tag, missionID, cardID) in [
                    ("mission", "\(prefix)-missing-mission", nil),
                    ("card", nil, "\(prefix)-missing-card"),
                ] as [(String, String?, String?)] {
                    try expectDatabaseFailure(
                        "\(scope) invalid degradation \(tag) foreign key",
                        expectedExtendedResultCode:
                            .SQLITE_CONSTRAINT_FOREIGNKEY
                    ) {
                        try insertObservabilityDegradation(
                            database,
                            id: "\(prefix)-missing-\(tag)",
                            missionID: missionID,
                            cardID: cardID,
                            policy: "required",
                            detail: "invalid",
                            createdAt: firstSeenAt
                        )
                    }
                }
                try requireDatabaseHealthy(
                    database,
                    scope: "\(scope) observability contract"
                )
                return .rollback
            }
        }

        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "\(scope) observability contract did not roll back exactly"
        )
    }

    private func validateOutcomeContract(
        in pool: DatabasePool,
        scope: String,
        reference: OutcomeContractSchemaReference,
        expectedObjects: SQLiteObjectSet,
        expectedMigrationCount: Int,
        expectedMigrationSuffix: [String]
    ) throws {
        let prefix = "outcome_" + scope
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        let before = try pool.read(stableSnapshot)

        try pool.read { database in
            let objects = try sqliteObjectSet(database)
            try require(
                objects == expectedObjects,
                "\(scope) final sqlite_master name sets differ from the expected literal checkpoint"
            )
            try require(
                outcomeContractTables.isSubset(of: objects.tables),
                "\(scope) missing v15 tables: \(outcomeContractTables.subtracting(objects.tables).sorted())"
            )
            try require(
                reference.introducedIndexes.isSubset(of: objects.indexes),
                "\(scope) missing v15 indexes"
            )
            try require(
                reference.introducedTriggers.isSubset(of: objects.triggers),
                "\(scope) missing v15 triggers"
            )
            let schemaShape = try selectedSchemaShape(
                database,
                tables: outcomeContractTables,
                indexes: reference.introducedIndexes,
                triggers: reference.introducedTriggers
            )
            try require(
                schemaShape == reference.schemaShape,
                "\(scope) v15 schema differs from literal Stage §18.5"
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v15-p1-outcome-contracts'
                    """,
                label: "\(scope) v15 migration count"
            )
            try require(
                migrationCount == expectedMigrationCount,
                "\(scope) v15 migration count is \(migrationCount), expected \(expectedMigrationCount)"
            )
            if expectedMigrationCount == 1 {
                let suffix = Array(try String.fetchAll(
                    database,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
                ).suffix(expectedMigrationSuffix.count))
                try require(
                    suffix == expectedMigrationSuffix,
                    "\(scope) migration suffix drifted: \(suffix)"
                )
            }
            try requireDatabaseHealthy(
                database,
                scope: "\(scope) outcome schema"
            )
        }

        try pool.writeWithoutTransaction { database in
            try database.inSavepoint {
                try insertOutcomeContractFixture(
                    database,
                    prefix: prefix
                )
                let ids: [String: String] = [
                    "verification_record": "\(prefix)-verification",
                    "verification_invalidation": "\(prefix)-invalidation",
                    "acceptance_record": "\(prefix)-acceptance",
                    "external_operation_receipt": "\(prefix)-receipt",
                ]
                try require(
                    Set(ids.keys) == outcomeAppendOnlyTables,
                    "\(scope) append-only fixture map drifted"
                )
                for table in outcomeAppendOnlyTables.sorted() {
                    guard let id = ids[table] else {
                        throw MatrixError.assertion(
                            "\(scope) missing append-only fixture id for \(table)"
                        )
                    }
                    try expectDatabaseFailure(
                        "\(scope) \(table) no-op update"
                    ) {
                        try database.execute(
                            sql: "UPDATE \(quotedIdentifier(table)) SET id = id WHERE id = ?",
                            arguments: [id]
                        )
                    }
                    try expectDatabaseFailure(
                        "\(scope) \(table) delete"
                    ) {
                        try database.execute(
                            sql: "DELETE FROM \(quotedIdentifier(table)) WHERE id = ?",
                            arguments: [id]
                        )
                    }
                }
                try requireDatabaseHealthy(
                    database,
                    scope: "\(scope) outcome contract"
                )
                return .rollback
            }
        }

        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "\(scope) outcome contract did not roll back exactly"
        )
    }

    private func validateControlContract(
        in pool: DatabasePool,
        scope: String,
        canonicalSchemaShape: String,
        v13Objects: SQLiteObjectSet,
        expectedMigrationCount: Int,
        expectedMigrationSuffix: [String]
    ) throws {
        let prefix = "control_" + scope
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        let before = try pool.read(stableSnapshot)

        try pool.read { database in
            let objects = try sqliteObjectSet(database)
            try require(
                v13Objects.tables.union(controlContractTables)
                    .isSubset(of: objects.tables),
                "\(scope) missing pre-v15 control tables"
            )
            try require(
                v13Objects.indexes.union(controlContractIndexes)
                    .isSubset(of: objects.indexes),
                "\(scope) missing pre-v15 control indexes"
            )
            let inheritedV16Triggers = v13Objects.triggers
                .subtracting([
                    "event_no_update",
                    "durable_work_attempt_event_reject_update",
                ])
                .union([
                    "event_reject_update_except_camp_redaction",
                    "durable_work_attempt_event_reject_update_except_camp_redaction",
                ])
            try require(
                inheritedV16Triggers.union(controlContractTriggers)
                    .isSubset(of: objects.triggers),
                "\(scope) missing mapped v16 control triggers"
            )
            try require(
                try controlSchemaShape(database) == canonicalSchemaShape,
                "\(scope) control schema differs from literal Stage §18.4"
            )
            let migrationCount = try requiredInt(
                database,
                sql: """
                    SELECT COUNT(*) FROM grdb_migrations
                    WHERE identifier = 'v14-p1-control-contracts'
                    """,
                label: "\(scope) v14 migration count"
            )
            try require(
                migrationCount == expectedMigrationCount,
                "\(scope) v14 migration count is \(migrationCount), expected \(expectedMigrationCount)"
            )
            if expectedMigrationCount == 1 {
                let suffix = Array(try String.fetchAll(
                    database,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
                ).suffix(expectedMigrationSuffix.count))
                try require(
                    suffix == expectedMigrationSuffix,
                    "\(scope) migration suffix drifted: \(suffix)"
                )
            }
            try requireDatabaseHealthy(
                database,
                scope: "\(scope) control schema"
            )
        }

        try pool.writeWithoutTransaction { database in
            try database.inSavepoint {
                try insertControlContractFixture(
                    database,
                    prefix: prefix
                )

                try expectDatabaseFailure(
                    "\(scope) receipt no-op update"
                ) {
                    try database.execute(
                        sql: """
                            UPDATE domain_command_receipt
                            SET commandType = commandType
                            WHERE idempotencyKey = ?
                            """,
                        arguments: ["\(prefix)-command"]
                    )
                }
                try expectDatabaseFailure("\(scope) receipt delete") {
                    try database.execute(
                        sql: """
                            DELETE FROM domain_command_receipt
                            WHERE idempotencyKey = ?
                            """,
                        arguments: ["\(prefix)-command"]
                    )
                }
                try expectDatabaseFailure("\(scope) event no-op update") {
                    try database.execute(
                        sql: """
                            UPDATE domain_event SET eventType = eventType
                            WHERE id = ?
                            """,
                        arguments: ["\(prefix)-event"]
                    )
                }
                try expectDatabaseFailure("\(scope) event delete") {
                    try database.execute(
                        sql: "DELETE FROM domain_event WHERE id = ?",
                        arguments: ["\(prefix)-event"]
                    )
                }
                try require(
                    try requiredInt(
                        database,
                        sql: """
                            SELECT COUNT(*) FROM domain_command_receipt
                            WHERE idempotencyKey = ?
                            """,
                        arguments: ["\(prefix)-command"],
                        label: "\(scope) retained receipt"
                    ) == 1,
                    "\(scope) append-only receipt did not survive"
                )
                try require(
                    try requiredInt(
                        database,
                        sql: "SELECT COUNT(*) FROM domain_event WHERE id = ?",
                        arguments: ["\(prefix)-event"],
                        label: "\(scope) retained event"
                    ) == 1,
                    "\(scope) append-only event did not survive"
                )

                try expectDatabaseFailure(
                    "\(scope) duplicate aggregate version"
                ) {
                    try insertControlEvent(
                        database,
                        prefix: prefix,
                        id: "duplicate-aggregate",
                        eventOrdinal: 1,
                        eventIdempotencyKey:
                            "\(prefix)-duplicate-aggregate-key"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) duplicate command ordinal"
                ) {
                    try insertControlEvent(
                        database,
                        prefix: prefix,
                        id: "duplicate-ordinal",
                        aggregateVersion: 2,
                        eventOrdinal: 0,
                        eventIdempotencyKey:
                            "\(prefix)-duplicate-ordinal-key"
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) malformed inbox redaction"
                ) {
                    try database.execute(
                        sql: """
                            INSERT INTO inbox_message (
                              id, campId, sourceDeviceId, idempotencyKey,
                              payloadJson, payloadHash, state, receivedAt,
                              appliedAt, errorCode, version, redactedAt
                            ) VALUES (?, ?, 'visible-device', ?, '{}', ?,
                                      'rejected', 1, NULL, 'camp_deleted', 1,
                                      2)
                            """,
                        arguments: [
                            "\(prefix)-bad-inbox",
                            "\(prefix)-camp",
                            "\(prefix)-bad-inbox-key",
                            String(repeating: "a", count: 64),
                        ]
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) deleted status with active retention"
                ) {
                    try insertControlInput(
                        database,
                        prefix: prefix,
                        id: "bad-deleted-status",
                        inlineText: "visible",
                        payloadRef: nil,
                        status: "deletedTombstone",
                        retentionState: "active",
                        deletedAt: nil
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) active input with two bodies"
                ) {
                    try insertControlInput(
                        database,
                        prefix: prefix,
                        id: "bad-two-bodies",
                        inlineText: "visible",
                        payloadRef: "payload://visible",
                        status: "captured",
                        retentionState: "active",
                        deletedAt: nil
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) tombstone retention with live status"
                ) {
                    try insertControlInput(
                        database,
                        prefix: prefix,
                        id: "bad-tombstone-status",
                        inlineText: nil,
                        payloadRef: nil,
                        status: "captured",
                        retentionState: "deletedTombstone",
                        deletedAt: 2
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) invalid goal understanding pair"
                ) {
                    try database.execute(
                        sql: """
                            INSERT INTO goal_controller (
                              id, campId, sourceInputId, title, rawIntent,
                              status, currentUnderstandingId,
                              currentUnderstandingVersion,
                              currentOutcomeContractId,
                              currentOutcomeContractVersion,
                              aggregateVersion, createdByActorId, createdAt,
                              updatedAt
                            ) VALUES (?, ?, NULL, 'Bad', 'Bad', 'clarifying',
                                      'understanding', 0, NULL, NULL, 1,
                                      'user:matrix', 1, 1)
                            """,
                        arguments: [
                            "\(prefix)-bad-goal",
                            "\(prefix)-camp",
                        ]
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) invalid coach actor"
                ) {
                    try database.execute(
                        sql: """
                            INSERT INTO coach_session (
                              id, goalId, inputId, actorId, status,
                              currentUnderstandingVersion, pendingQuestionId,
                              traceId, aggregateVersion, createdAt, updatedAt
                            ) VALUES (?, ?, NULL, 'system:coach:v2',
                                      'interviewing', NULL, NULL, ?, 1, 1, 1)
                            """,
                        arguments: [
                            "\(prefix)-bad-session",
                            "\(prefix)-goal",
                            "\(prefix)-bad-trace",
                        ]
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) duplicate open coach question"
                ) {
                    try database.execute(
                        sql: """
                            INSERT INTO coach_question (
                              id, sessionId, decisionKey, prompt,
                              recommendation, reason, answerJson, state,
                              createdAt, answeredAt
                            ) VALUES (?, ?, 'second-decision', 'Prompt',
                                      'Recommendation', 'Reason', NULL,
                                      'open', 1, NULL)
                            """,
                        arguments: [
                            "\(prefix)-second-question",
                            "\(prefix)-session",
                        ]
                    )
                }
                try expectDatabaseFailure(
                    "\(scope) confirmed understanding without confirmer"
                ) {
                    try insertControlUnderstanding(
                        database,
                        prefix: prefix,
                        id: "bad-understanding",
                        status: "confirmed",
                        confirmedByActorID: nil,
                        confirmedAt: nil
                    )
                }
                try requireDatabaseHealthy(
                    database,
                    scope: "\(scope) control contract"
                )
                return .rollback
            }
        }

        let after = try pool.read(stableSnapshot)
        try require(
            after == before,
            "\(scope) control contract did not roll back exactly"
        )
    }

    private func validateV12Diagnostics(
        in pool: DatabasePool,
        scope: String
    ) throws {
        try validateDurableDiagnosticWrappers(in: pool, scope: scope)
        try runDurableDiagnosticCatalog(in: pool, scope: scope)
    }

    private func openPool(at url: URL) throws -> DatabasePool {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return try DatabasePool(
            path: url.path,
            configuration: configuration
        )
    }

    private func sqliteVersion(in pool: DatabasePool) throws -> String {
        try pool.read { database in
            try requiredString(
                database,
                sql: "SELECT sqlite_version()",
                label: "sqlite_version"
            )
        }
    }

    private func assertRuntime(in pool: DatabasePool) throws {
        let version = try sqliteVersion(in: pool)
        try require(
            version == arguments.expectedSQLiteVersion,
            "connection sqlite_version \(version) != expected \(arguments.expectedSQLiteVersion)"
        )
    }
}

private func require(
    _ condition: @autoclosure () throws -> Bool,
    _ message: String
)
    throws
{
    guard try condition() else {
        throw MatrixError.assertion(message)
    }
}

private func requiredString(
    _ database: Database,
    sql: String,
    arguments: StatementArguments = [],
    label: String
) throws -> String {
    guard let value = try String.fetchOne(
        database,
        sql: sql,
        arguments: arguments
    ) else {
        throw MatrixError.assertion("\(label) returned no row")
    }
    return value
}

private func requiredInt(
    _ database: Database,
    sql: String,
    arguments: StatementArguments = [],
    label: String
) throws -> Int {
    guard let value = try Int.fetchOne(
        database,
        sql: sql,
        arguments: arguments
    ) else {
        throw MatrixError.assertion("\(label) returned no row")
    }
    return value
}

private func requiredDouble(
    _ database: Database,
    sql: String,
    arguments: StatementArguments = [],
    label: String
) throws -> Double {
    guard let value = try Double.fetchOne(
        database,
        sql: sql,
        arguments: arguments
    ) else {
        throw MatrixError.assertion("\(label) returned no row")
    }
    return value
}

private func sqliteObjectNames(
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

private func sqliteObjectSet(
    _ database: Database
) throws -> SQLiteObjectSet {
    SQLiteObjectSet(
        tables: try sqliteObjectNames(database, type: "table"),
        indexes: try sqliteObjectNames(database, type: "index"),
        triggers: try sqliteObjectNames(database, type: "trigger")
    )
}

private func controlSchemaShape(_ database: Database) throws -> String {
    let names = controlContractTables
        .union(controlContractIndexes)
        .union(controlContractTriggers)
        .sorted()
    let quotedNames = names
        .map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
        .joined(separator: ",")
    var sections = try String.fetchAll(
        database,
        sql: """
            SELECT quote(type) || char(31) || quote(name) || char(31)
                   || quote(tbl_name) || char(31)
                   || COALESCE(quote(sql), 'NULL')
            FROM sqlite_master
            WHERE name IN (\(quotedNames))
            ORDER BY type, name, tbl_name
            """
    )
    for table in controlContractTables.sorted() {
        sections.append("TABLE_INFO \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT cid || char(31) || name || char(31) || type
                       || char(31) || "notnull" || char(31)
                       || COALESCE(dflt_value, 'NULL') || char(31) || pk
                FROM pragma_table_info(?) ORDER BY cid
                """,
            arguments: [table]
        ))
        sections.append("FOREIGN_KEYS \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT id || char(31) || seq || char(31) || "table"
                       || char(31) || "from" || char(31) || "to"
                       || char(31) || on_update || char(31) || on_delete
                       || char(31) || "match"
                FROM pragma_foreign_key_list(?)
                ORDER BY id, seq
                """,
            arguments: [table]
        ))
    }
    for index in controlContractIndexes.sorted() {
        sections.append("INDEX_INFO \(index)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT seqno || char(31) || cid || char(31) || name
                FROM pragma_index_info(?) ORDER BY seqno
                """,
            arguments: [index]
        ))
    }
    return sections.joined(separator: "\n")
}

private func selectedSchemaShape(
    _ database: Database,
    tables: Set<String>,
    indexes: Set<String>,
    triggers: Set<String>
) throws -> String {
    let names = tables.union(indexes).union(triggers).sorted()
    let quotedNames = names
        .map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
        .joined(separator: ",")
    var sections = try String.fetchAll(
        database,
        sql: """
            SELECT quote(type) || char(31) || quote(name) || char(31)
                   || quote(tbl_name) || char(31)
                   || COALESCE(quote(sql), 'NULL')
            FROM sqlite_master
            WHERE name IN (\(quotedNames))
            ORDER BY type, name, tbl_name
            """
    )
    for table in tables.sorted() {
        sections.append("TABLE_INFO \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT cid || char(31) || name || char(31) || type
                       || char(31) || "notnull" || char(31)
                       || COALESCE(dflt_value, 'NULL') || char(31) || pk
                FROM pragma_table_info(?) ORDER BY cid
                """,
            arguments: [table]
        ))
        sections.append("FOREIGN_KEYS \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT id || char(31) || seq || char(31) || "table"
                       || char(31) || "from" || char(31) || "to"
                       || char(31) || on_update || char(31) || on_delete
                       || char(31) || "match"
                FROM pragma_foreign_key_list(?)
                ORDER BY id, seq
                """,
            arguments: [table]
        ))
    }
    for index in indexes.sorted() {
        sections.append("INDEX_INFO \(index)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT seqno || char(31) || cid || char(31) || name
                FROM pragma_index_info(?) ORDER BY seqno
                """,
            arguments: [index]
        ))
    }
    return sections.joined(separator: "\n")
}

private func requireColumns(
    _ database: Database,
    table: String,
    expected: [String]
) throws {
    let actual = try database.columns(in: table).map(\.name)
    try require(
        actual == expected,
        "\(table) columns \(actual) != \(expected)"
    )
}

private func foreignKeyShapes(
    _ database: Database,
    table: String
) throws -> [String] {
    try Row.fetchAll(
        database,
        sql: "PRAGMA foreign_key_list(\(quotedIdentifier(table)))"
    ).map { row in
        let from: String = row["from"]
        let referencedTable: String = row["table"]
        let to: String = row["to"]
        let onDelete: String = row["on_delete"]
        return "\(from)|\(referencedTable)|\(to)|\(onDelete)"
    }.sorted()
}

private func indexColumns(
    _ database: Database,
    index: String
) throws -> [String] {
    try String.fetchAll(
        database,
        sql: "SELECT name FROM pragma_index_info(?) ORDER BY seqno",
        arguments: [index]
    )
}

private func requireDatabaseHealthy(
    _ database: Database,
    scope: String
) throws {
    let foreignKeyCursor = try database.foreignKeyViolations()
    try require(
        try foreignKeyCursor.next() == nil,
        "\(scope) has a foreign-key violation"
    )
    let integrity = try requiredString(
        database,
        sql: "PRAGMA integrity_check",
        label: "\(scope) integrity_check"
    )
    try require(
        integrity == "ok",
        "\(scope) integrity_check = \(integrity)"
    )
}

private func requireObservabilityObjectsAbsent(
    _ database: Database,
    allowedNames: Set<String> = []
) throws {
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
            ORDER BY name
            """
    ))
    try require(
        names == allowedNames,
        "unexpected observability objects: \(names.sorted()); allowed \(allowedNames.sorted())"
    )
}

private func insertV12SchedulePredecessor(
    _ database: Database,
    prefix: String
) throws {
    let timestamp = 1_700_000_000.25
    try insertScheduleFireScopeFixture(
        database,
        prefix: prefix,
        timestamp: timestamp
    )
    try insertScheduleFireFixture(
        database,
        prefix: prefix,
        id: "started",
        scheduledAt: timestamp,
        createdAt: timestamp + 0.25,
        state: "started",
        missionID: "\(prefix)-mission"
    )
    try database.execute(
        sql: """
            INSERT INTO schedule_evaluation_cursor (
              scheduleId, lastEvaluatedSlotKey, lastEvaluatedScheduledAt,
              version, updatedAt
            ) VALUES (?, 'slot-started', ?, 1, ?)
            """,
        arguments: [
            "\(prefix)-schedule",
            timestamp,
            timestamp + 0.25,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work (
              id, campId, kind, aggregateType, aggregateId, idempotencyKey,
              state, attempt, maxAttempts, notBefore, leaseOwner,
              leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
              errorMessage, traceId, version, createdAt, updatedAt, finishedAt
            ) VALUES (
              ?, ?, 'planning', 'mission', ?, ?, 'running', 1, 4, NULL,
              'worker', ?, '{"value":1}', ?, NULL, NULL, NULL, ?, 2, ?, ?,
              NULL
            )
            """,
        arguments: [
            "\(prefix)-work",
            "\(prefix)-camp",
            "\(prefix)-mission",
            "\(prefix)-work-idempotency",
            timestamp + 60,
            String(repeating: "a", count: 64),
            "\(prefix)-work-trace",
            timestamp,
            timestamp,
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
            timestamp,
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
            timestamp,
        ]
    )
}

private func insertV13ObservabilityPredecessor(
    _ database: Database,
    prefix: String
) throws {
    let timestamp = 1_700_000_000.25
    try insertV12SchedulePredecessor(database, prefix: prefix)
    try insertObservabilityFailure(
        database,
        id: "\(prefix)-failure",
        scopeKind: "camp",
        campID: "\(prefix)-camp",
        userMessage: "preserve v13 failure",
        firstSeenAt: timestamp,
        lastSeenAt: timestamp + 0.25
    )
    try insertObservabilityDegradation(
        database,
        id: "\(prefix)-degradation",
        missionID: "\(prefix)-mission",
        policy: "required",
        detail: "preserve v13 degradation",
        createdAt: timestamp
    )
}

private func insertV15PopulatedIdentityMemoryPredecessor(
    _ database: Database
) throws {
    let prefix = "v15_populated"
    let timestamp = 1_700_000_000.25
    let date = Date(timeIntervalSince1970: timestamp)
    try insertOutcomeContractFixture(database, prefix: prefix)

    try CompanionRecord(
        id: "\(prefix)-cow-global",
        name: "Global Cow",
        color: "#ffffff",
        rolePrompt: "global",
        model: "matrix-model",
        toolsJson: "[]",
        kind: .regular,
        campId: nil,
        createdAt: date
    ).insert(database)
    try CompanionRecord(
        id: "\(prefix)-cow-guide",
        name: "Guide Cow",
        color: "#000000",
        rolePrompt: "guide",
        model: "matrix-model",
        toolsJson: "[]",
        kind: .guide,
        campId: "\(prefix)-camp",
        createdAt: date
    ).insert(database)
    try ChatThreadRecord(
        id: "\(prefix)-thread-dm",
        kind: .dm,
        companionId: "\(prefix)-cow-global",
        campId: nil,
        createdAt: date
    ).insert(database)
    try ChatThreadRecord(
        id: "\(prefix)-thread-guide",
        kind: .guide,
        companionId: "\(prefix)-cow-guide",
        campId: "\(prefix)-camp",
        createdAt: date
    ).insert(database)
    try ChatMessageRecord(
        id: "\(prefix)-message-dm",
        threadId: "\(prefix)-thread-dm",
        role: "user",
        contentJson: "{\"text\":\"global\"}",
        distilled: false,
        createdAt: date
    ).insert(database)
    try ChatMessageRecord(
        id: "\(prefix)-message-guide",
        threadId: "\(prefix)-thread-guide",
        role: "user",
        contentJson: "{\"text\":\"camp\"}",
        distilled: false,
        createdAt: date
    ).insert(database)
    try CompanionNoteRecord(
        id: "\(prefix)-note-dm",
        companionId: "\(prefix)-cow-global",
        sourceThreadId: "\(prefix)-thread-dm",
        title: "DM",
        bodyMd: "global memory",
        pinned: false,
        createdAt: date,
        updatedAt: date
    ).insert(database)
    try CompanionNoteRecord(
        id: "\(prefix)-note-guide",
        companionId: "\(prefix)-cow-guide",
        sourceThreadId: "\(prefix)-thread-guide",
        title: "Guide",
        bodyMd: "camp memory",
        pinned: false,
        createdAt: date,
        updatedAt: date
    ).insert(database)
    try EventRecord(
        id: "\(prefix)-event-global",
        missionId: nil,
        cardId: nil,
        runId: nil,
        kind: EventKind.campHalted,
        payloadJson: "{}",
        createdAt: date
    ).insert(database)
    try EventRecord(
        id: "\(prefix)-event-camp",
        missionId: nil,
        cardId: nil,
        runId: nil,
        kind: EventKind.campArchived,
        payloadJson: "{\"campId\":\"\(prefix)-camp\"}",
        createdAt: date
    ).insert(database)

    try database.execute(
        sql: """
            INSERT INTO camp(id,name,archived,createdAt)
            VALUES (?, 'Archived matrix Camp', 1, ?)
            """,
        arguments: ["\(prefix)-archived-camp", timestamp]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work(
              id,campId,kind,aggregateType,aggregateId,idempotencyKey,state,
              attempt,maxAttempts,notBefore,leaseOwner,leaseExpiresAt,inputJson,
              inputHash,outputJson,errorCode,errorMessage,traceId,version,
              createdAt,updatedAt,finishedAt
            ) VALUES (
              ?,?,'planning','mission',?,?, 'running',1,4,NULL,'worker',?,
              '{}',?,NULL,NULL,NULL,?,1,?,?,NULL
            )
            """,
        arguments: [
            "\(prefix)-archived-work",
            "\(prefix)-archived-camp",
            "\(prefix)-archived-aggregate",
            "\(prefix)-archived-key",
            timestamp + 60,
            String(repeating: "a", count: 64),
            "\(prefix)-archived-trace",
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt(
              workId,attempt,id,workerId,startedAt,endedAt,outcome,errorCode,
              errorMessage,traceId,terminalWorkVersion
            ) VALUES (?,1,?,'worker',?,NULL,NULL,NULL,NULL,?,NULL)
            """,
        arguments: [
            "\(prefix)-archived-work",
            "\(prefix)-archived-attempt",
            timestamp,
            "\(prefix)-archived-trace",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt_event(
              id,workId,attempt,sequence,eventKind,workerId,workVersion,
              resultingWorkState,errorCode,errorMessage,occurredAt
            ) VALUES (?, ?,1,0,'claimed','worker',1,'running',NULL,NULL,?)
            """,
        arguments: [
            "\(prefix)-archived-attempt-event",
            "\(prefix)-archived-work",
            timestamp,
        ]
    )
}

private func insertV16IdentityMemoryArtifactPredecessor(
    _ database: Database
) throws {
    let prefix = "v16_identity_memory"
    let timestamp = 1_700_000_000.25
    try insertOutcomeContractFixture(database, prefix: prefix)
    try database.execute(
        sql: """
            INSERT INTO artifact(id,cardId,path,kind,label,createdAt)
            VALUES (?, ?, ?, 'report', 'Legacy matrix artifact', ?)
            """,
        arguments: [
            "\(prefix)-artifact",
            "\(prefix)-card",
            "workspace/../Artifacts/牧场 result.txt",
            timestamp,
        ]
    )
}

private func validateV16IdentityMemoryArtifactBackfill(
    in pool: DatabasePool
) throws {
    try pool.read { database in
        let sourceCount = try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM artifact",
            label: "v16 artifact source count"
        )
        let joinedCount = try requiredInt(
            database,
            sql: """
                SELECT COUNT(*)
                FROM artifact AS a
                JOIN card AS c ON c.id=a.cardId
                JOIN mission AS m ON m.id=c.missionId
                JOIN squad AS s ON s.id=m.squadId
                JOIN camp ON camp.id=s.campId
                """,
            label: "v16 artifact joined count"
        )
        let originCount = try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM artifact_storage_origin",
            label: "v17 artifact origin count"
        )
        try require(
            sourceCount == 1 && joinedCount == 1 && originCount == 1,
            "v17 legacy origin counts are \(sourceCount)/\(joinedCount)/\(originCount), expected 1/1/1"
        )
        let row = try Row.fetchOne(
            database,
            sql: """
                SELECT o.artifactId,o.campId,o.state,o.storageClass,
                       o.evidenceKind,o.managedRootId,o.objectId,o.contentHash,
                       o.fileIdentityHash,o.originalRefHash,
                       o.classificationEvidenceHash,o.terminalDisposition,
                       o.terminalAuthorityHash,o.version,o.classifiedAt,
                       o.redactedAt,a.cardId,a.path,a.createdAt
                FROM artifact_storage_origin AS o
                JOIN artifact AS a ON a.id=o.artifactId
                WHERE o.artifactId='v16_identity_memory-artifact'
                """
        )
        guard let row else {
            throw MatrixError.assertion(
                "v17 legacy artifact origin row is missing"
            )
        }
        let artifactID: String = row["artifactId"]
        let cardID: String = row["cardId"]
        let campID: String = row["campId"]
        let persistedPath: String = row["path"]
        let state: String = row["state"]
        let storageClass: String = row["storageClass"]
        let evidenceKind: String = row["evidenceKind"]
        let originalRefHash: String = row["originalRefHash"]
        let classificationEvidenceHash: String =
            row["classificationEvidenceHash"]
        let version: Int = row["version"]
        let classifiedAt: Double = row["classifiedAt"]
        let createdAt: Double = row["createdAt"]
        try require(
            artifactID == "v16_identity_memory-artifact"
                && cardID == "v16_identity_memory-card"
                && campID == "v16_identity_memory-camp"
                && persistedPath == "workspace/../Artifacts/牧场 result.txt"
                && state == "active"
                && storageClass == "unresolved"
                && evidenceKind == "legacyUnknown"
                && originalRefHash == "01552f0a0795d988076903f21495f2742ae442206ff7c0f5b1e81128b466bea8"
                && classificationEvidenceHash == "68c9ea7c461b72c038f883b9e3a9a3ead73abc836d47b9fe1d23861d6feceba1"
                && version == 1
                && classifiedAt == createdAt,
            "v17 legacy artifact origin identity/hash/shape drifted"
        )
        for column in [
            "managedRootId", "objectId", "contentHash", "fileIdentityHash",
            "terminalDisposition", "terminalAuthorityHash", "redactedAt",
        ] {
            let value: DatabaseValue = row[column]
            try require(
                value.isNull,
                "v17 legacy artifact origin \(column) is not NULL"
            )
        }
        try requireDatabaseHealthy(
            database,
            scope: "v17 legacy artifact origin backfill"
        )
    }
}

private func insertControlContractFixture(
    _ database: Database,
    prefix: String
) throws {
    let timestamp = 1_700_000_000.25
    try insertScheduleFireScopeFixture(
        database,
        prefix: prefix,
        timestamp: timestamp
    )
    try database.execute(
        sql: """
            INSERT INTO domain_command_receipt (
              idempotencyKey, commandType, commandPayloadHash, eventCount,
              resultJson, resultHash, createdAt
            ) VALUES (?, 'matrix.control', ?, 1, '{}', ?, ?)
            """,
        arguments: [
            "\(prefix)-command",
            String(repeating: "a", count: 64),
            String(repeating: "b", count: 64),
            timestamp,
        ]
    )
    try insertControlEvent(
        database,
        prefix: prefix,
        id: "event",
        eventOrdinal: 0,
        eventIdempotencyKey: "\(prefix)-event-key"
    )
    try database.execute(
        sql: """
            INSERT INTO event_outbox (
              eventId, state, attempt, notBefore, leaseOwner,
              leaseExpiresAt, lastError, version, createdAt, updatedAt, sentAt
            ) VALUES (?, 'pending', 0, NULL, NULL, NULL, NULL, 1, ?, ?, NULL)
            """,
        arguments: ["\(prefix)-event", timestamp, timestamp]
    )
    try database.execute(
        sql: """
            INSERT INTO inbox_message (
              id, campId, sourceDeviceId, idempotencyKey, payloadJson,
              payloadHash, state, receivedAt, appliedAt, errorCode, version,
              redactedAt
            ) VALUES (?, ?, 'device:matrix', ?, '{}', ?, 'received', ?, NULL,
                      NULL, 1, NULL)
            """,
        arguments: [
            "\(prefix)-inbox",
            "\(prefix)-camp",
            "\(prefix)-inbox-key",
            String(repeating: "c", count: 64),
            timestamp,
        ]
    )
    try insertControlInput(
        database,
        prefix: prefix,
        id: "input",
        inlineText: "matrix input",
        payloadRef: nil,
        status: "captured",
        retentionState: "active",
        deletedAt: nil
    )
    try database.execute(
        sql: """
            INSERT INTO goal_controller (
              id, campId, sourceInputId, title, rawIntent, status,
              currentUnderstandingId, currentUnderstandingVersion,
              currentOutcomeContractId, currentOutcomeContractVersion,
              aggregateVersion, createdByActorId, createdAt, updatedAt
            ) VALUES (?, ?, ?, 'Matrix goal', 'Matrix intent', 'clarifying',
                      NULL, NULL, NULL, NULL, 1, 'user:matrix', ?, ?)
            """,
        arguments: [
            "\(prefix)-goal",
            "\(prefix)-camp",
            "\(prefix)-input",
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO goal_mission_link (
              missionId, goalId, outcomeContractId, outcomeContractVersion,
              state, version, createdAt, updatedAt
            ) VALUES (?, ?, NULL, NULL, 'active', 1, ?, ?)
            """,
        arguments: [
            "\(prefix)-mission",
            "\(prefix)-goal",
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO coach_session (
              id, goalId, inputId, actorId, status,
              currentUnderstandingVersion, pendingQuestionId, traceId,
              aggregateVersion, createdAt, updatedAt
            ) VALUES (?, ?, ?, 'system:coach:v1', 'interviewing', NULL, NULL,
                      ?, 1, ?, ?)
            """,
        arguments: [
            "\(prefix)-session",
            "\(prefix)-goal",
            "\(prefix)-input",
            "\(prefix)-trace",
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO coach_question (
              id, sessionId, decisionKey, prompt, recommendation, reason,
              answerJson, state, createdAt, answeredAt
            ) VALUES (?, ?, 'first-decision', 'Prompt', 'Recommendation',
                      'Reason', NULL, 'open', ?, NULL)
            """,
        arguments: [
            "\(prefix)-question",
            "\(prefix)-session",
            timestamp,
        ]
    )
    try insertControlUnderstanding(
        database,
        prefix: prefix,
        id: "understanding",
        status: "draft",
        confirmedByActorID: nil,
        confirmedAt: nil
    )
}

private func insertOutcomeContractFixture(
    _ database: Database,
    prefix: String
) throws {
    let timestamp = 1_700_000_000.25
    let hashA = String(repeating: "a", count: 64)
    let hashB = String(repeating: "b", count: 64)
    let hashC = String(repeating: "c", count: 64)
    let hashD = String(repeating: "d", count: 64)
    let hashE = String(repeating: "e", count: 64)
    let hashF = String(repeating: "f", count: 64)
    try insertControlContractFixture(database, prefix: prefix)
    try database.execute(
        sql: """
            INSERT INTO card (
              id, missionId, idemKey, title, descriptionText, expectedOutput,
              assigneeId, status, blockedReasonJson, dependsOnJson, maxTurns,
              tokenBudget, createdAt, reviewFlag
            ) VALUES (?, ?, ?, 'Matrix card', 'Description', 'Output', NULL,
                      'todo', NULL, '[]', 8, 1000, ?, NULL)
            """,
        arguments: [
            "\(prefix)-card",
            "\(prefix)-mission",
            "\(prefix)-card-key",
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO acceptance_policy_version (
              id, version, outcomeType, maxRiskClass, policyActorId,
              validFrom, validUntil, maxOutcomeAgeSeconds,
              requireAllVerification, status, revokedAt, createdByActorId,
              contentHash, createdAt
            ) VALUES (?, 1, 'code', 'normal', 'policy:matrix', ?, ?, 3600,
                      1, 'active', NULL, 'system:matrix', ?, ?)
            """,
        arguments: [
            "\(prefix)-policy",
            timestamp - 60,
            timestamp + 3600,
            hashA,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO outcome_contract_version (
              id, version, goalId, understandingId, understandingVersion,
              understandingHash, outcomeType, deliverablesJson,
              acceptanceCriteriaJson, verificationRequirementsJson,
              unacceptableDeviationsJson, requiredDependencyRefsJson,
              optionalDependencyRefsJson, requiresSubjectiveJudgment,
              includesPublicRelease, includesPayment, includesDeletion,
              includesExternalSend, riskClass, acceptanceOwner,
              acceptancePolicyId, acceptancePolicyVersion, status,
              contentHash, createdByActorId, activatedByActorId, createdAt,
              activatedAt
            ) VALUES (?, 1, ?, ?, 1, ?, 'code', '[]', '[]', '[]', '[]',
                      '[]', '[]', 0, 0, 0, 0, 0, 'normal', 'user', NULL,
                      NULL, 'active', ?, 'user:matrix', 'user:matrix', ?, ?)
            """,
        arguments: [
            "\(prefix)-contract",
            "\(prefix)-goal",
            "\(prefix)-understanding",
            hashF,
            hashB,
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO verification_requirement_group (
              contractId, contractVersion, groupId, mode, ordinal
            ) VALUES (?, 1, 'primary', 'all', 0)
            """,
        arguments: ["\(prefix)-contract"]
    )
    try database.execute(
        sql: """
            INSERT INTO verification_requirement (
              contractId, contractVersion, groupId, requirementId,
              requirementVersion, ordinal, verifierType, verifierId, method,
              ruleId, ruleVersion, configJson, requirementHash
            ) VALUES (?, 1, 'primary', 'tests', 1, 0, 'deterministic',
                      'matrix:tests', 'tests', 'matrix-rule', 1, '{}', ?)
            """,
        arguments: ["\(prefix)-contract", hashC]
    )
    try database.execute(
        sql: """
            UPDATE goal_controller
            SET status = 'active', currentUnderstandingId = ?,
                currentUnderstandingVersion = 1, currentOutcomeContractId = ?,
                currentOutcomeContractVersion = 1, aggregateVersion = 2,
                updatedAt = ?
            WHERE id = ?
            """,
        arguments: [
            "\(prefix)-understanding",
            "\(prefix)-contract",
            timestamp,
            "\(prefix)-goal",
        ]
    )
    try database.execute(
        sql: """
            UPDATE goal_mission_link
            SET outcomeContractId = ?, outcomeContractVersion = 1,
                version = 2, updatedAt = ?
            WHERE missionId = ?
            """,
        arguments: [
            "\(prefix)-contract",
            timestamp,
            "\(prefix)-mission",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO outcome (
              id, goalId, missionId, contractId, contractVersion,
              contractHash, currentVersion, state, aggregateVersion,
              createdAt, updatedAt
            ) VALUES (?, ?, ?, ?, 1, ?, 1, 'verified', 1, ?, ?)
            """,
        arguments: [
            "\(prefix)-outcome",
            "\(prefix)-goal",
            "\(prefix)-mission",
            "\(prefix)-contract",
            hashB,
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO outcome_version (
              outcomeId, version, contractId, contractVersion, contractHash,
              producerActorId, runIdsJson, manifestJson, contentHash, createdAt
            ) VALUES (?, 1, ?, 1, ?, 'cow:matrix', '[]', '{}', ?, ?)
            """,
        arguments: [
            "\(prefix)-outcome",
            "\(prefix)-contract",
            hashB,
            hashD,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO verification_record (
              id, commandIdempotencyKey, contractId, contractVersion,
              contractHash, requirementId, requirementVersion,
              requirementHash, outcomeId, outcomeVersion, outcomeHash,
              verifierType, verifierId, method, ruleId, ruleVersion,
              environmentJson, commandOrRuleJson, rawResultRef, evidenceHash,
              result, supersedesVerificationId, createdAt, redactedAt
            ) VALUES (?, ?, ?, 1, ?, 'tests', 1, ?, ?, 1, ?,
                      'deterministic', 'matrix:tests', 'tests', 'matrix-rule',
                      1, '{}', '{}', NULL, ?, 'passed', NULL, ?, NULL)
            """,
        arguments: [
            "\(prefix)-verification",
            "\(prefix)-verification-command",
            "\(prefix)-contract",
            hashB,
            hashC,
            "\(prefix)-outcome",
            hashD,
            hashE,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO verification_result_head (
              outcomeId, outcomeVersion, contractId, contractVersion,
              requirementId, requirementVersion, currentVerificationId,
              derivedResult, version, updatedAt
            ) VALUES (?, 1, ?, 1, 'tests', 1, ?, 'invalid', 2, ?)
            """,
        arguments: [
            "\(prefix)-outcome",
            "\(prefix)-contract",
            "\(prefix)-verification",
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO verification_invalidation (
              id, verificationId, reasonCode, dependencyType, dependencyId,
              dependencyVersion, dependencyHash, eventId, createdAt
            ) VALUES (?, ?, 'dependency_changed', 'understanding', ?, 1, ?,
                      ?, ?)
            """,
        arguments: [
            "\(prefix)-invalidation",
            "\(prefix)-verification",
            "\(prefix)-understanding",
            hashF,
            "\(prefix)-event",
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO acceptance_record (
              id, commandIdempotencyKey, contractId, contractVersion,
              contractHash, outcomeId, outcomeVersion, outcomeHash,
              subjectType, subjectId, policyId, policyVersion, decision,
              reason, supersedesAcceptanceId, createdAt, redactedAt
            ) VALUES (?, ?, ?, 1, ?, ?, 1, ?, 'user', 'user:matrix', NULL,
                      NULL, 'accepted', 'matrix acceptance', NULL, ?, NULL)
            """,
        arguments: [
            "\(prefix)-acceptance",
            "\(prefix)-acceptance-command",
            "\(prefix)-contract",
            hashB,
            "\(prefix)-outcome",
            hashD,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO outcome_metric_credit (
              outcomeId, state, creditedOutcomeVersion, acceptanceId,
              reversedByEventId, version, creditedAt, reversedAt
            ) VALUES (?, 'active', 1, ?, NULL, 1, ?, NULL)
            """,
        arguments: [
            "\(prefix)-outcome",
            "\(prefix)-acceptance",
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO approval_grant (
              id, version, scopeVersion, grantorActorType, grantorActorId,
              grantorPolicyId, grantorPolicyVersion, grantorPolicyHash,
              granteeType, granteeId, capability, campId, cardId, toolId,
              approvedInputHash, purpose, dataLevel, adapterReplayClass,
              validFrom, validUntil, maxUses, usedCount, status, revokedAt,
              createdAt, updatedAt, redactedAt
            ) VALUES (?, 1, 1, 'user', 'user:matrix', NULL, NULL, NULL,
                      'cow', 'cow:matrix', 'tool.execute', ?, ?, 'matrix-tool',
                      ?, 'matrix purpose', 'workspace', 'nonReplayable', ?, ?,
                      1, 1, 'exhausted', NULL, ?, ?, NULL)
            """,
        arguments: [
            "\(prefix)-grant",
            "\(prefix)-camp",
            "\(prefix)-card",
            hashA,
            timestamp - 60,
            timestamp + 3600,
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO approval_grant_use (
              id, grantId, idempotencyKey, toolId, inputHash, adapterId,
              adapterReplayClass, state, adapterOperationId, version,
              reservedAt, dispatchIntentAt, adapterAcceptedAt, finishedAt
            ) VALUES (?, ?, ?, 'matrix-tool', ?, 'adapter:matrix',
                      'nonReplayable', 'dispatching', NULL, 2, ?, ?, NULL, NULL)
            """,
        arguments: [
            "\(prefix)-use",
            "\(prefix)-grant",
            "\(prefix)-use-key",
            hashA,
            timestamp,
            timestamp,
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO external_operation_receipt (
              id, grantUseId, receiptIdempotencyKey, ordinal, phase, result,
              adapterOperationId, receiptRef, receiptJson, receiptHash,
              authorityKind, authorityId, createdAt, redactedAt
            ) VALUES (?, ?, ?, 0, 'dispatchIntent', 'pending', NULL, NULL,
                      '{}', ?, 'system', 'system:matrix', ?, NULL)
            """,
        arguments: [
            "\(prefix)-receipt",
            "\(prefix)-use",
            "external-receipt:v1:\(prefix)-use:0:dispatchIntent",
            hashA,
            timestamp,
        ]
    )
}

private func insertControlEvent(
    _ database: Database,
    prefix: String,
    id: String,
    aggregateVersion: Int = 1,
    eventOrdinal: Int,
    eventIdempotencyKey: String
) throws {
    if try database.tableExists("camp_event_scope") {
        try database.execute(
            sql: """
                INSERT INTO camp_event_scope(
                  sourceTable,eventId,scopeKind,campId,payloadRedactedAt
                ) VALUES ('domain_event',?,'camp',?,NULL)
                """,
            arguments: ["\(prefix)-\(id)", "\(prefix)-camp"]
        )
    }
    try database.execute(
        sql: """
            INSERT INTO domain_event (
              id, campId, aggregateType, aggregateId, aggregateVersion,
              eventType, payloadVersion, payloadJson, payloadHash, actorType,
              actorId, deviceId, causationId, correlationId,
              commandIdempotencyKey, eventOrdinal, eventIdempotencyKey,
              occurredAt, recordedAt
            ) VALUES (?, ?, 'goal', ?, ?, 'matrix.event', 1, '{}', ?,
                      'system', 'system:matrix', NULL, NULL, ?, ?, ?, ?, 1, 1)
            """,
        arguments: [
            "\(prefix)-\(id)",
            "\(prefix)-camp",
            "\(prefix)-aggregate",
            aggregateVersion,
            String(repeating: "d", count: 64),
            "\(prefix)-correlation",
            "\(prefix)-command",
            eventOrdinal,
            eventIdempotencyKey,
        ]
    )
}

private func insertControlInput(
    _ database: Database,
    prefix: String,
    id: String,
    inlineText: String?,
    payloadRef: String?,
    status: String,
    retentionState: String,
    deletedAt: Double?
) throws {
    try database.execute(
        sql: """
            INSERT INTO input_envelope (
              id, schemaVersion, aggregateVersion, idempotencyKey, sourceType,
              sourceDeviceId, connectorId, authorId, capturedAt, inlineText,
              payloadRef, contentHash, candidateCampIdsJson, campId,
              explicitIntent, privacyLevel, status, errorCode, errorMessage,
              parentInputId, retentionState, createdAt, updatedAt, deletedAt
            ) VALUES (?, 1, 1, ?, 'text', NULL, NULL, NULL, 1, ?, ?, ?, '[]',
                      ?, 'unspecified', 'localOnly', ?, NULL, NULL, NULL, ?, 1,
                      COALESCE(?, 1), ?)
            """,
        arguments: [
            "\(prefix)-\(id)",
            "\(prefix)-input-key-\(id)",
            inlineText,
            payloadRef,
            String(repeating: "e", count: 64),
            "\(prefix)-camp",
            status,
            retentionState,
            deletedAt,
            deletedAt,
        ]
    )
}

private func insertControlUnderstanding(
    _ database: Database,
    prefix: String,
    id: String,
    status: String,
    confirmedByActorID: String?,
    confirmedAt: Double?
) throws {
    try database.execute(
        sql: """
            INSERT INTO understanding_card_version (
              id, version, goalId, problem, scenario, targetAudience,
              goalsJson, nonGoalsJson, deliverablesJson, constraintsJson,
              acceptanceCriteriaJson, verificationPlanJson, resourceRefsJson,
              requiredCapabilitiesJson, budgetPolicyJson, assumptionsJson,
              acceptedRisksJson, status, contentHash, createdByActorId,
              confirmedByActorId, confirmedAt, createdAt
            ) VALUES (?, 1, ?, 'Problem', 'Scenario', 'Audience', '[]', '[]',
                      '[]', '[]', '[]', '[]', '[]', '[]', '{}', '[]', '[]',
                      ?, ?, 'user:matrix', ?, ?, 1)
            """,
        arguments: [
            "\(prefix)-\(id)",
            "\(prefix)-goal",
            status,
            String(repeating: "f", count: 64),
            confirmedByActorID,
            confirmedAt,
        ]
    )
}

private func insertObservabilityFailure(
    _ database: Database,
    id: String,
    scopeKind: String,
    campID: String? = nil,
    severity: String = "error",
    userMessage: String,
    diagnosticJSON: String = "{}",
    state: String = "open",
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
            ) VALUES (?, 'matrix_operation', ?, ?, 'matrix_scope',
                      'matrix_scope_id', ?, 'matrix_error', ?, ?, ?, ?, ?,
                      ?, ?, ?)
            """,
        arguments: [
            id, scopeKind, campID, severity, userMessage, diagnosticJSON,
            state, firstSeenAt, lastSeenAt, occurrenceCount, resolvedAt,
            redactedAt,
        ]
    )
}

private func insertObservabilityDegradation(
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
            ) VALUES (?, ?, ?, 'knowledge', 'matrix_dependency', ?, ?, ?,
                      ?, ?)
            """,
        arguments: [
            id, missionID, cardID, policy, "trace-\(id)", detail, createdAt,
            redactedAt,
        ]
    )
}

private func insertScheduleFireScopeFixture(
    _ database: Database,
    prefix: String,
    timestamp: Double
) throws {
    try database.execute(
        sql: """
            INSERT INTO camp (id, name, archived, createdAt)
            VALUES (?, ?, 0, ?)
            """,
        arguments: ["\(prefix)-camp", "Schedule Fire \(prefix)", timestamp]
    )
    try insertActiveCampLifecycleIfV16(
        database,
        campID: "\(prefix)-camp",
        timestamp: timestamp
    )
    try database.execute(
        sql: """
            INSERT INTO mission_template (
              id, name, goal, companionIdsJson, workspacePath, budgetTokens,
              autonomy, campId, createdAt
            ) VALUES (?, 'Template', 'Goal', '[]', NULL, 1000,
                      'standard', ?, ?)
            """,
        arguments: [
            "\(prefix)-template",
            "\(prefix)-camp",
            timestamp,
        ]
    )
    for (id, hour, minute) in [
        ("\(prefix)-schedule", 9, 30),
        ("\(prefix)-cursor-only-schedule", 10, 45),
    ] {
        try database.execute(
            sql: """
                INSERT INTO schedule (
                  id, templateId, frequency, hour, minute, weekday, enabled,
                  lastFiredAt, createdAt
                ) VALUES (?, ?, 'daily', ?, ?, NULL, 1, NULL, ?)
                """,
            arguments: [
                id,
                "\(prefix)-template",
                hour,
                minute,
                timestamp,
            ]
        )
    }
    try database.execute(
        sql: """
            INSERT INTO squad (
              id, campId, name, memberIdsJson, workspacePath,
              workspaceBookmark, createdAt
            ) VALUES (?, ?, 'Squad', '[]', NULL, NULL, ?)
            """,
        arguments: ["\(prefix)-squad", "\(prefix)-camp", timestamp]
    )
    try database.execute(
        sql: """
            INSERT INTO mission (
              id, squadId, goalRaw, goalRefined, status, budgetTokens,
              spentTokens, revision, autonomy, createdAt
            ) VALUES (?, ?, 'Goal', 'Goal', 'planning', 1000, 0, 1,
                      'standard', ?)
            """,
        arguments: ["\(prefix)-mission", "\(prefix)-squad", timestamp]
    )
}

private func insertScheduleFireFixture(
    _ database: Database,
    prefix: String,
    id: String,
    slotKey: String? = nil,
    scheduledAt: Double,
    createdAt: Double,
    replayOfFireID: String? = nil,
    replayIdempotencyKey: String? = nil,
    replayPayloadHash: String? = nil,
    state: String,
    missionID: String? = nil,
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
              :id, :scheduleId, :templateId, :slotKey, :scheduledAt,
              :replayOfFireId, :replayIdempotencyKey, :replayPayloadHash,
              :state, :missionId, :traceId, :errorCode, :errorMessage,
              :createdAt, :redactedAt
            )
            """,
        arguments: StatementArguments([
            "id": "\(prefix)-\(id)",
            "scheduleId": "\(prefix)-schedule",
            "templateId": "\(prefix)-template",
            "slotKey": slotKey ?? "slot-\(id)",
            "scheduledAt": scheduledAt,
            "replayOfFireId": replayOfFireID,
            "replayIdempotencyKey": replayIdempotencyKey,
            "replayPayloadHash": replayPayloadHash,
            "state": state,
            "missionId": missionID,
            "traceId": "\(prefix)-trace-\(id)",
            "errorCode": errorCode,
            "errorMessage": errorMessage,
            "createdAt": createdAt,
            "redactedAt": redactedAt,
        ] as [String: (any DatabaseValueConvertible)?])
    )
}

private func expectDatabaseFailure(
    _ label: String,
    expectedExtendedResultCode: ResultCode? = nil,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as DatabaseError {
        if let expectedExtendedResultCode {
            try require(
                error.extendedResultCode == expectedExtendedResultCode,
                "\(label) failed with \(error.extendedResultCode) instead of \(expectedExtendedResultCode)"
            )
        }
        return
    }
    throw MatrixError.expectedFailureDidNotOccur(label)
}

private func expectDatabaseFailure(
    _ label: String,
    expectedExtendedResultCodes: [ResultCode],
    operation: () throws -> Void
) throws {
    try require(
        !expectedExtendedResultCodes.isEmpty,
        "\(label) has no accepted extended result code"
    )
    do {
        try operation()
    } catch let error as DatabaseError {
        try require(
            expectedExtendedResultCodes.contains(error.extendedResultCode),
            "\(label) failed with \(error.extendedResultCode) outside accepted codes \(expectedExtendedResultCodes)"
        )
        return
    }
    throw MatrixError.expectedFailureDidNotOccur(label)
}

private func makeMatrixDiagnosticCatalog()
    -> [MatrixDiagnosticCandidate]
{
    var catalog: [MatrixDiagnosticCandidate] = []
    for shape in MatrixDiagnosticWorkShape.allCases {
        for code in MatrixDiagnosticCode.allCases {
            for message in MatrixDiagnosticMessage.allCases {
                catalog.append(.work(shape, code, message))
            }
        }
    }
    for shape in MatrixDiagnosticAttemptShape.allCases {
        for code in MatrixDiagnosticCode.allCases {
            for message in MatrixDiagnosticMessage.allCases {
                catalog.append(.attempt(shape, code, message))
            }
        }
    }
    for kind in MatrixDiagnosticEventKind.allCases {
        for state in MatrixDiagnosticEventState.allCases {
            for code in MatrixDiagnosticCode.allCases {
                for message in MatrixDiagnosticMessage.allCases {
                    catalog.append(.event(kind, state, code, message))
                }
            }
        }
    }
    return catalog
}

private func matrixDiagnosticSentinelIDs() -> Set<String> {
    Set([
        MatrixDiagnosticCandidate.work(
            .canceled,
            .null,
            .present
        ).id,
        MatrixDiagnosticCandidate.attempt(
            .open,
            .otherError,
            .null
        ).id,
        MatrixDiagnosticCandidate.attempt(
            .open,
            .null,
            .present
        ).id,
        MatrixDiagnosticCandidate.attempt(
            .canceled,
            .null,
            .present
        ).id,
        MatrixDiagnosticCandidate.attempt(
            .interrupted,
            .null,
            .null
        ).id,
        MatrixDiagnosticCandidate.event(
            .canceled,
            .canceled,
            .null,
            .present
        ).id,
        MatrixDiagnosticCandidate.event(
            .interrupted,
            .queued,
            .null,
            .null
        ).id,
    ])
}

private let poisonedV12Diagnostics = matrixDiagnosticSentinelIDs()
private let poisonedV15Diagnostics = matrixDiagnosticSentinelIDs()

private func matrixDiagnosticControlIDs() -> Set<String> {
    Set([
        MatrixDiagnosticCandidate.work(.queued, .null, .null).id,
        MatrixDiagnosticCandidate.work(
            .queued,
            .workerInterrupted,
            .null
        ).id,
        MatrixDiagnosticCandidate.work(.running, .null, .null).id,
        MatrixDiagnosticCandidate.work(
            .retryScheduled,
            .otherError,
            .present
        ).id,
        MatrixDiagnosticCandidate.work(
            .succeededWithOutput,
            .null,
            .null
        ).id,
        MatrixDiagnosticCandidate.work(
            .failed,
            .otherError,
            .present
        ).id,
        MatrixDiagnosticCandidate.work(
            .canceled,
            .workCanceled,
            .present
        ).id,
        MatrixDiagnosticCandidate.attempt(.open, .null, .null).id,
        MatrixDiagnosticCandidate.attempt(.succeeded, .null, .null).id,
        MatrixDiagnosticCandidate.attempt(
            .failed,
            .otherError,
            .present
        ).id,
        MatrixDiagnosticCandidate.attempt(
            .canceled,
            .workCanceled,
            .present
        ).id,
        MatrixDiagnosticCandidate.attempt(
            .interrupted,
            .workerInterrupted,
            .null
        ).id,
        MatrixDiagnosticCandidate.event(
            .claimed,
            .running,
            .null,
            .null
        ).id,
        MatrixDiagnosticCandidate.event(
            .leaseRenewed,
            .running,
            .null,
            .null
        ).id,
        MatrixDiagnosticCandidate.event(
            .succeeded,
            .succeeded,
            .null,
            .null
        ).id,
        MatrixDiagnosticCandidate.event(
            .failed,
            .retryScheduled,
            .otherError,
            .present
        ).id,
        MatrixDiagnosticCandidate.event(
            .failed,
            .failed,
            .otherError,
            .present
        ).id,
        MatrixDiagnosticCandidate.event(
            .canceled,
            .canceled,
            .workCanceled,
            .present
        ).id,
        MatrixDiagnosticCandidate.event(
            .interrupted,
            .queued,
            .workerInterrupted,
            .null
        ).id,
    ])
}

private func insertMatrixDiagnosticWork(
    _ database: Database,
    id: String,
    campID: String,
    shape: MatrixDiagnosticWorkShape,
    code: MatrixDiagnosticCode,
    message: MatrixDiagnosticMessage
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
              id, campId, campLifecycleVersion, kind, aggregateType, aggregateId, idempotencyKey,
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

private func insertMatrixDiagnosticHarness(
    _ database: Database,
    campID: String
) throws {
    try insertMatrixDiagnosticWork(
        database,
        id: "diagnostic-attempt-parent",
        campID: campID,
        shape: .running,
        code: .null,
        message: .null
    )
    try insertMatrixDiagnosticWork(
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

private func insertMatrixDiagnosticCandidate(
    _ candidate: MatrixDiagnosticCandidate,
    database: Database,
    campID: String
) throws {
    switch candidate {
    case let .work(shape, code, message):
        try insertMatrixDiagnosticWork(
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

private func requireMatrixDiagnosticCandidateWasInserted(
    _ candidate: MatrixDiagnosticCandidate,
    database: Database
) throws {
    let count: Int
    switch candidate {
    case .work:
        count = try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM durable_work WHERE id = ?",
            arguments: [candidate.id],
            label: "\(candidate.id) work insert"
        )
    case .attempt:
        count = try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt WHERE id = ?",
            arguments: [candidate.id],
            label: "\(candidate.id) attempt insert"
        )
    case .event:
        count = try requiredInt(
            database,
            sql: """
                SELECT COUNT(*) FROM durable_work_attempt_event WHERE id = ?
                """,
            arguments: [candidate.id],
            label: "\(candidate.id) event insert"
        )
    }
    try require(count == 1, "\(candidate.id) did not insert exactly one row")
}

private func evaluateMatrixDiagnosticCandidate(
    _ candidate: MatrixDiagnosticCandidate,
    database: Database,
    campID: String
) throws -> MatrixDiagnosticVerdict {
    do {
        try database.inSavepoint {
            try insertMatrixDiagnosticCandidate(
                candidate,
                database: database,
                campID: campID
            )
            try requireMatrixDiagnosticCandidateWasInserted(
                candidate,
                database: database
            )
            return .rollback
        }
        return .accepted
    } catch let error as DatabaseError {
        guard error.extendedResultCode == .SQLITE_CONSTRAINT_CHECK else {
            throw MatrixError.assertion(
                "\(candidate.id) failed with \(error.extendedResultCode) instead of SQLITE_CONSTRAINT_CHECK"
            )
        }
        return .checkRejected
    }
}

private func matrixDiagnosticRowCounts(
    _ database: Database
) throws -> MatrixDiagnosticRowCounts {
    MatrixDiagnosticRowCounts(
        work: try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM durable_work",
            label: "diagnostic work row count"
        ),
        attempt: try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt",
            label: "diagnostic attempt row count"
        ),
        event: try requiredInt(
            database,
            sql: "SELECT COUNT(*) FROM durable_work_attempt_event",
            label: "diagnostic event row count"
        )
    )
}

private func matrixDiagnosticHealth(
    _ database: Database
) throws -> MatrixDiagnosticHealth {
    MatrixDiagnosticHealth(
        rowCounts: try matrixDiagnosticRowCounts(database),
        foreignKeysEnabled: try requiredInt(
            database,
            sql: "PRAGMA foreign_keys",
            label: "diagnostic foreign_keys"
        ),
        foreignKeyViolations: try String.fetchAll(
            database,
            sql: """
                SELECT quote("table") || char(31) || quote(rowid)
                       || char(31) || quote(parent) || char(31) || quote(fkid)
                FROM pragma_foreign_key_check
                ORDER BY "table", rowid, parent, fkid
                """
        ),
        integrityResults: try String.fetchAll(
            database,
            sql: "PRAGMA integrity_check"
        )
    )
}

private func requireMatrixDiagnosticHealth(
    _ health: MatrixDiagnosticHealth,
    scope: String,
    phase: String
) throws {
    try require(
        health.foreignKeysEnabled == 1,
        "\(scope) \(phase) foreign_keys is disabled"
    )
    try require(
        health.foreignKeyViolations.isEmpty,
        "\(scope) \(phase) foreign_key_check = \(health.foreignKeyViolations)"
    )
    try require(
        health.integrityResults == ["ok"],
        "\(scope) \(phase) integrity_check = \(health.integrityResults)"
    )
}

private func validateDurableDiagnosticWrappers(
    in pool: DatabasePool,
    scope: String
) throws {
    try pool.read { database in
        let foreignKeys = try requiredInt(
            database,
            sql: "PRAGMA foreign_keys",
            label: "\(scope) foreign_keys"
        )
        try require(foreignKeys == 1, "\(scope) foreign_keys is disabled")
        for table in [
            "durable_work",
            "durable_work_attempt",
            "durable_work_attempt_event",
        ] {
            let schema = try requiredString(
                database,
                sql: """
                    SELECT sql FROM sqlite_master
                    WHERE type = 'table' AND name = ?
                    """,
                arguments: [table],
                label: "\(scope) \(table) schema"
            )
            let wrapperCount = schema.components(
                separatedBy: "CHECK (COALESCE(("
            ).count - 1
            try require(
                wrapperCount == 1,
                "\(scope) \(table) diagnostics wrapper count \(wrapperCount) != 1"
            )
        }
    }
}

private func runDurableDiagnosticCatalog(
    in pool: DatabasePool,
    scope: String
) throws {
    let catalog = makeMatrixDiagnosticCatalog()
    let sentinelIDs = matrixDiagnosticSentinelIDs()
    let controlIDs = matrixDiagnosticControlIDs()
    let allIDs = Set(catalog.map(\.id))
    try require(catalog.count == 384, "\(scope) catalog count != 384")
    try require(allIDs.count == 384, "\(scope) catalog IDs are not unique")
    try require(
        sentinelIDs.count == 7 && sentinelIDs.isSubset(of: allIDs),
        "\(scope) sentinel catalog is incomplete"
    )
    try require(
        controlIDs.count == 19 && controlIDs.isSubset(of: allIDs),
        "\(scope) control catalog is incomplete"
    )

    let workCases = catalog.filter { $0.table == .work }
    let attemptCases = catalog.filter { $0.table == .attempt }
    let eventCases = catalog.filter { $0.table == .event }
    try require(
        workCases.count == 56
            && workCases.filter(\.expectedAccepted).count == 18,
        "\(scope) work oracle count drifted"
    )
    try require(
        attemptCases.count == 40
            && attemptCases.filter(\.expectedAccepted).count == 10,
        "\(scope) attempt oracle count drifted"
    )
    try require(
        eventCases.count == 288
            && eventCases.filter(\.expectedAccepted).count == 17,
        "\(scope) event oracle count drifted"
    )
    for id in sentinelIDs {
        try require(
            catalog.first { $0.id == id }?.expectedAccepted == false,
            "\(scope) sentinel oracle accepted \(id)"
        )
    }
    for id in controlIDs {
        try require(
            catalog.first { $0.id == id }?.expectedAccepted == true,
            "\(scope) control oracle rejected \(id)"
        )
    }

    let before = try pool.read(matrixDiagnosticHealth)
    try requireMatrixDiagnosticHealth(
        before,
        scope: scope,
        phase: "before catalog"
    )
    var verdicts: [String: MatrixDiagnosticVerdict] = [:]
    let campID = "diagnostics-\(scope)-camp"
    try pool.writeWithoutTransaction { database in
        try database.inTransaction {
            try database.execute(
                sql: """
                    INSERT INTO camp (id, name, archived, createdAt)
                    VALUES (?, ?, 0, 1000000)
                    """,
                arguments: [campID, "Diagnostics \(scope)"]
            )
            try insertActiveCampLifecycleIfV16(
                database,
                campID: campID,
                timestamp: 1_000_000
            )
            try insertMatrixDiagnosticHarness(database, campID: campID)
            for candidate in catalog {
                let verdict = try evaluateMatrixDiagnosticCandidate(
                    candidate,
                    database: database,
                    campID: campID
                )
                try require(
                    verdicts.updateValue(
                        verdict,
                        forKey: candidate.id
                    ) == nil,
                    "\(scope) duplicate verdict for \(candidate.id)"
                )
            }
            return .rollback
        }
    }
    let after = try pool.read(matrixDiagnosticHealth)
    try requireMatrixDiagnosticHealth(
        after,
        scope: scope,
        phase: "after catalog"
    )
    try require(
        after == before,
        "\(scope) catalog changed rows/FK/integrity state"
    )
    try require(verdicts.count == 384, "\(scope) verdict count != 384")

    for candidate in catalog {
        let expected: MatrixDiagnosticVerdict = candidate.expectedAccepted
            ? .accepted
            : .checkRejected
        try require(
            verdicts[candidate.id] == expected,
            "\(scope) verdict mismatch for \(candidate.id)"
        )
    }
    for id in sentinelIDs {
        try require(
            verdicts[id] == .checkRejected,
            "\(scope) NULL/UNKNOWN sentinel passed: \(id)"
        )
    }
    for id in controlIDs {
        try require(
            verdicts[id] == .accepted,
            "\(scope) legal control failed: \(id)"
        )
    }

    let workAccepted = workCases.filter {
        verdicts[$0.id] == .accepted
    }.count
    let workRejected = workCases.filter {
        verdicts[$0.id] == .checkRejected
    }.count
    let attemptAccepted = attemptCases.filter {
        verdicts[$0.id] == .accepted
    }.count
    let attemptRejected = attemptCases.filter {
        verdicts[$0.id] == .checkRejected
    }.count
    let eventAccepted = eventCases.filter {
        verdicts[$0.id] == .accepted
    }.count
    let eventRejected = eventCases.filter {
        verdicts[$0.id] == .checkRejected
    }.count
    try require(
        workAccepted == 18 && workRejected == 38,
        "\(scope) actual work counts \(workAccepted)/\(workRejected)"
    )
    try require(
        attemptAccepted == 10 && attemptRejected == 30,
        "\(scope) actual attempt counts \(attemptAccepted)/\(attemptRejected)"
    )
    try require(
        eventAccepted == 17 && eventRejected == 271,
        "\(scope) actual event counts \(eventAccepted)/\(eventRejected)"
    )

    print(
        "diagnostics.\(scope).work.total=56 accepted=18 check_rejected=38"
    )
    print(
        "diagnostics.\(scope).attempt.total=40 accepted=10 check_rejected=30"
    )
    print(
        "diagnostics.\(scope).event.total=288 accepted=17 check_rejected=271"
    )
    print(scope == "v16"
        ? "diagnostics.v16.sentinels.total=7 accepted=0 check_rejected=7"
        : "diagnostics.\(scope).sentinels.total=7 accepted=0 check_rejected=7")
    print(
        "diagnostics.\(scope).controls.total=19 accepted=19 check_rejected=0"
    )
    print("diagnostics.\(scope).result=pass")
}

private func insertValidAttemptEvent(
    _ database: Database,
    prefix: String
) throws {
    try database.execute(
        sql: """
            INSERT INTO camp (id, name, archived, createdAt)
            VALUES (?, ?, 0, 1000000)
            """,
        arguments: ["\(prefix)-camp", "Matrix \(prefix)"]
    )
    try insertActiveCampLifecycleIfV16(
        database,
        campID: "\(prefix)-camp",
        timestamp: 1_000_000
    )
    let hasLifecycleVersion = try database.columns(in: "durable_work")
        .contains { $0.name == "campLifecycleVersion" }
    let lifecycleColumn = hasLifecycleVersion ? ", campLifecycleVersion" : ""
    let lifecycleValue = hasLifecycleVersion ? ", 1" : ""
    try database.execute(
        sql: """
            INSERT INTO durable_work (
              id, campId\(lifecycleColumn), kind, aggregateType, aggregateId, idempotencyKey,
              state, attempt, maxAttempts, notBefore, leaseOwner,
              leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
              errorMessage, traceId, version, createdAt, updatedAt, finishedAt
            ) VALUES (
              ?, ?\(lifecycleValue), 'planning', 'mission', ?, ?, 'running', 1, 4, NULL,
              'worker', 1000060, '{"value":1}', ?, NULL, NULL, NULL, ?,
              2, 1000000, 1000000, NULL
            )
            """,
        arguments: [
            "\(prefix)-work",
            "\(prefix)-camp",
            "\(prefix)-aggregate",
            "\(prefix)-idempotency",
            String(repeating: "a", count: 64),
            "\(prefix)-trace",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt (
              workId, attempt, id, workerId, startedAt, endedAt, outcome,
              errorCode, errorMessage, traceId, terminalWorkVersion
            ) VALUES (?, 1, ?, 'worker', 1000000, NULL, NULL, NULL, NULL,
                      ?, NULL)
            """,
        arguments: [
            "\(prefix)-work",
            "\(prefix)-attempt",
            "\(prefix)-trace",
        ]
    )
    try database.execute(
        sql: """
            INSERT INTO durable_work_attempt_event (
              id, workId, attempt, sequence, eventKind, workerId,
              workVersion, resultingWorkState, errorCode, errorMessage,
              occurredAt
            ) VALUES (?, ?, 1, 0, 'claimed', 'worker', 2, 'running',
                      NULL, NULL, 1000000)
            """,
        arguments: [
            "\(prefix)-event",
            "\(prefix)-work",
        ]
    )
}

private func insertActiveCampLifecycleIfV16(
    _ database: Database,
    campID: String,
    timestamp: Double
) throws {
    guard try database.tableExists("camp_lifecycle") else { return }
    try database.execute(
        sql: """
            INSERT INTO camp_lifecycle(
              campId,state,version,createdAt,updatedAt,
              deletionRequestedAt,deletedAt
            ) VALUES (?,'active',1,?,?,NULL,NULL)
            """,
        arguments: [campID, timestamp, timestamp]
    )
}

private func quotedIdentifier(_ identifier: String) -> String {
    "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func scheduleSchemaShape(_ database: Database) throws -> String {
    var sections = try String.fetchAll(
        database,
        sql: """
            SELECT quote(type) || char(31) || quote(name) || char(31)
                   || quote(tbl_name) || char(31) || COALESCE(quote(sql), 'NULL')
            FROM sqlite_master
            ORDER BY type, name, tbl_name
            """
    )
    for table in ["schedule_evaluation_cursor", "schedule_fire"] {
        sections.append("TABLE_INFO \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT CAST(cid AS TEXT) || char(31) || quote(name)
                       || char(31) || quote(type) || char(31)
                       || CAST("notnull" AS TEXT) || char(31)
                       || quote(dflt_value) || char(31) || CAST(pk AS TEXT)
                FROM pragma_table_info(?)
                ORDER BY cid
                """,
            arguments: [table]
        ))
        sections.append("FOREIGN_KEY_LIST \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT CAST(id AS TEXT) || char(31) || CAST(seq AS TEXT)
                       || char(31) || quote("table") || char(31)
                       || quote("from") || char(31) || quote("to")
                       || char(31) || quote(on_update) || char(31)
                       || quote(on_delete) || char(31) || quote("match")
                FROM pragma_foreign_key_list(?)
                ORDER BY id, seq
                """,
            arguments: [table]
        ))
        let indexNames = try String.fetchAll(
            database,
            sql: """
                SELECT name FROM pragma_index_list(?)
                ORDER BY name
                """,
            arguments: [table]
        )
        sections.append("INDEX_LIST \(table)")
        sections.append(contentsOf: try String.fetchAll(
            database,
            sql: """
                SELECT quote(name) || char(31) || CAST("unique" AS TEXT)
                       || char(31) || quote(origin) || char(31)
                       || CAST(partial AS TEXT)
                FROM pragma_index_list(?)
                ORDER BY name
                """,
            arguments: [table]
        ))
        for index in indexNames {
            sections.append("INDEX_XINFO \(index)")
            sections.append(contentsOf: try String.fetchAll(
                database,
                sql: """
                    SELECT CAST(seqno AS TEXT) || char(31)
                           || CAST(cid AS TEXT) || char(31) || quote(name)
                           || char(31) || CAST("desc" AS TEXT) || char(31)
                           || quote(coll) || char(31) || CAST("key" AS TEXT)
                    FROM pragma_index_xinfo(?)
                    ORDER BY seqno
                    """,
                arguments: [index]
            ))
        }
    }
    return sections.joined(separator: "\n")
}

private struct StableTableProjection {
    let table: String
    let columns: [String]
}

private func predecessorUserTableProjections(
    _ database: Database
) throws -> [StableTableProjection] {
    let tableNames = try String.fetchAll(
        database,
        sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table'
              AND name NOT LIKE 'sqlite_%'
              AND name <> 'grdb_migrations'
            ORDER BY name
            """
    )
    return try tableNames.map { table in
        StableTableProjection(
            table: table,
            columns: try database.columns(in: table).map(\.name)
        )
    }
}

private func stableRowsSnapshot(
    _ database: Database,
    tableProjections: [StableTableProjection]
) throws -> String {
    var sections: [String] = []
    for tableProjection in tableProjections.sorted(
        by: { $0.table < $1.table }
    ) {
        let table = tableProjection.table
        let tableExists = try database.tableExists(table)
        try require(
            tableExists,
            "stable row snapshot is missing table \(table)"
        )
        let currentColumns = Set(
            try database.columns(in: table).map(\.name)
        )
        let columns = tableProjection.columns
        try require(
            columns.allSatisfy(currentColumns.contains),
            "stable row snapshot is missing predecessor columns in \(table)"
        )
        let quotedColumns = columns.map(quotedIdentifier)
        let projection = quotedColumns
            .map { "quote(\($0))" }
            .joined(separator: " || char(31) || ")
        let order = quotedColumns.joined(separator: ", ")
        let rows = try String.fetchAll(
            database,
            sql: """
                SELECT \(projection)
                FROM \(quotedIdentifier(table))
                ORDER BY \(order)
                """
        )
        sections.append("TABLE \(table)")
        sections.append("COLUMNS \(columns.joined(separator: "|"))")
        sections.append(contentsOf: rows)
    }
    return sections.joined(separator: "\n")
}

private func stableSnapshot(_ database: Database) throws -> String {
    var sections = try String.fetchAll(
        database,
        sql: """
            SELECT quote(type) || char(31) || quote(name) || char(31)
                   || quote(tbl_name) || char(31) || COALESCE(quote(sql), 'NULL')
            FROM sqlite_master
            ORDER BY type, name, tbl_name
            """
    )
    let tableNames = try String.fetchAll(
        database,
        sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name
            """
    )
    for table in tableNames {
        let columns = try database.columns(in: table).map(\.name)
        let quotedColumns = columns.map(quotedIdentifier)
        let projection = quotedColumns
            .map { "quote(\($0))" }
            .joined(separator: " || char(31) || ")
        let order = quotedColumns.joined(separator: ", ")
        let rows = try String.fetchAll(
            database,
            sql: """
                SELECT \(projection)
                FROM \(quotedIdentifier(table))
                ORDER BY \(order)
                """
        )
        sections.append("TABLE \(table)")
        sections.append(contentsOf: rows)
    }
    return sections.joined(separator: "\n")
}

do {
    let arguments = try Arguments(commandLine: CommandLine.arguments)
    try MatrixRunner(arguments: arguments).run()
} catch {
    let message = "P1MigrationMatrixRunner: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
