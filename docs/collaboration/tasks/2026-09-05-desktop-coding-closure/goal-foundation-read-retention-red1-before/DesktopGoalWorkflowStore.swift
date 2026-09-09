import Foundation
import GRDB

// Read/retention integration RED scaffold: no successful snapshot is fabricated.
private enum DesktopGoalReadNotImplemented: Error { case integrationCheckpoint }

package struct DesktopGoalWorkflowStore: Sendable {
    private let database: AppDatabase

    package init(database: AppDatabase) {
        self.database = database
    }

    package func snapshot(inputId: String, campId: String) throws -> DesktopGoalFoundationReadV1 {
        throw DesktopGoalReadNotImplemented.integrationCheckpoint
    }

    package func list(campId: String) throws -> [DesktopGoalFoundationReadV1] {
        throw DesktopGoalReadNotImplemented.integrationCheckpoint
    }

    package static func redact(inputId: String, at: Date, in database: Database) throws {
        throw DesktopGoalReadNotImplemented.integrationCheckpoint
    }

    package func prepareSubmission(_ intent: DesktopGoalCaptureIntentV1) throws -> DesktopGoalCaptureReceiptV1 {
        let requestJSON = try CanonicalContractCodingV1.string(intent)
        let command = try intent.captureCommand()
        return try database.pool.write { db in
            if let row = try Self.operationRow(intent.operationId, in: db) {
                let stored = try Self.loadOperation(row, in: db)
                guard Data(stored.requestJSON.utf8) == Data(requestJSON.utf8) else { throw DesktopGoalFoundationErrorV1.operationConflict }
                // Current context revisions do not reinterpret the sealed original request.
                _ = try Self.requireGraph(intent: stored.intent, in: db)
                _ = try Self.sealCaptureStage(operationId: intent.operationId, expectedVersion: stored.version, intent: intent, in: db)
                // Preserve the existing event store's complete receipt/event/outbox replay checks.
                let receipt = try InputGoalStore(database: database).captureAndEnqueueParsing(command, in: db)
                guard let sealedRow = try Self.operationRow(intent.operationId, in: db) else { throw DesktopGoalFoundationErrorV1.missingCarrier }
                let sealedVersion: Int = sealedRow["version"]
                _ = try appendCaptureReceipt(operationId: intent.operationId, expectedVersion: sealedVersion, receipt: receipt, in: db)
                return try Self.captureReceipt(intent, receipt)
            }

            if let context = try Row.fetchOne(db, sql: "SELECT * FROM desktop_goal_context WHERE inputId=?", arguments: [intent.context.inputId]) {
                try Self.requireLive(context, in: db)
                throw DesktopGoalFoundationErrorV1.contextConflict
            }
            guard try InputEnvelopeRecord.fetchOne(db, key: intent.context.inputId) == nil,
                  try GoalControllerRecord.fetchOne(db, key: intent.context.goalId) == nil,
                  try CoachSessionRecord.fetchOne(db, key: intent.context.sessionId) == nil,
                  try Row.fetchOne(db, sql: "SELECT inputId FROM desktop_goal_context WHERE goalId=?", arguments: [intent.context.goalId]) == nil
            else { throw DesktopGoalFoundationErrorV1.contextConflict }
            for row in try Row.fetchAll(db, sql: "SELECT * FROM desktop_goal_context WHERE retentionState='live'") {
                let context = try Self.decodeContext(row)
                guard context.sessionId != intent.context.sessionId else { throw DesktopGoalFoundationErrorV1.contextConflict }
            }
            _ = try CampLifecycleStore(database: database).requireActiveCampWrite(campId: intent.campId, expectedLifecycleVersion: intent.expectedCampLifecycleVersion, database: db)
            let contextJSON = try CanonicalContractCodingV1.string(intent.context)
            try db.execute(sql: """
                INSERT INTO desktop_goal_context(inputId,goalId,campId,version,contextJson,contextHash,retentionState,createdAt,updatedAt)
                VALUES (?,?,?,1,?,?,'live',?,?)
                """, arguments: [intent.context.inputId, intent.context.goalId, intent.campId, contextJSON,
                                   CanonicalJSONV1.sha256Hex(Data(contextJSON.utf8)), intent.envelope.occurredAt, intent.envelope.occurredAt])
            try db.execute(sql: """
                INSERT INTO desktop_goal_operation(id,inputId,kind,ownerKind,version,requestJson,requestHash,phase,resultJson,safeReceiptJson,safeErrorCode,createdAt,updatedAt)
                VALUES (?,?,'submit','userMutation',1,?,?,'prepared','[]',NULL,NULL,?,?)
                """, arguments: [intent.operationId, intent.context.inputId, requestJSON,
                                   CanonicalJSONV1.sha256Hex(Data(requestJSON.utf8)), intent.envelope.occurredAt, intent.envelope.occurredAt])
            _ = try Self.sealCaptureStage(operationId: intent.operationId, expectedVersion: 1, intent: intent, in: db)
            let receipt = try InputGoalStore(database: database).captureAndEnqueueParsing(command, in: db)
            _ = try appendCaptureReceipt(operationId: intent.operationId, expectedVersion: 2, receipt: receipt, in: db)
            return try Self.captureReceipt(intent, receipt)
        }
    }

    package func sealCaptureStage(
        operationId: String, expectedVersion: Int, intent: DesktopGoalCaptureIntentV1
    ) throws -> DesktopGoalSealedStageV1 {
        try database.pool.write { db in
            try Self.sealCaptureStage(operationId: operationId, expectedVersion: expectedVersion, intent: intent, in: db)
        }
    }

    // Shared by the real capture transaction and direct receipt-CAS callers.
    package func appendCaptureReceipt(
        operationId: String, expectedVersion: Int, receipt: InputCaptureReceiptV1,
        in database: Database
    ) throws -> DesktopGoalStageReceiptV1 {
        guard let row = try Self.operationRow(operationId, in: database) else { throw DesktopGoalFoundationErrorV1.missingCarrier }
        let operation = try Self.loadOperation(row, in: database)
        try Self.requireVersion(expectedVersion, current: operation.version)
        guard let stage = operation.stages.first else { throw DesktopGoalFoundationErrorV1.stageConflict }
        let candidate = try DesktopGoalStageReceiptV1(captureReceipt: receipt)
        // Even the first attachment must come from this exact committed domain command.
        guard let actual = try DomainCommandReceiptRecordV1.fetchOne(database, key: operation.intent.envelope.idempotencyKey),
              actual.commandType == .inputCapture, actual.commandPayloadHash == stage.commandHash,
              actual.eventCount == 1, actual.resultHash == candidate.receiptHash,
              Data(actual.resultJson.utf8) == candidate.receiptBytes,
              candidate.inputId == operation.intent.context.inputId,
              receipt.hashes.first(where: { $0.kind == .commandPayload })?.hash == stage.commandHash
        else { throw DesktopGoalFoundationErrorV1.receiptConflict }
        let command = try operation.intent.captureCommand()
        let replayPlan = try InputGoalStore.captureReplayPlan(
            inputId: command.inputId, auditCampId: command.auditCampId, expectedInputVersion: 0
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputCapture, envelope: command.envelope, payload: command, replayPlan: replayPlan
        )
        // Validate the existing event/scope/outbox graph in this same transaction.
        // A missing receipt must never turn this append into a new domain command.
        let validated = try DomainEventStore(database: self.database).executeCommand(
            command: prepared, replayPlan: replayPlan, database: database
        ) { _ in throw DomainCommandGraphIntegrityError() }
        guard try CanonicalContractCodingV1.encode(validated) == candidate.receiptBytes
        else { throw DesktopGoalFoundationErrorV1.receiptConflict }
        let input = try Self.requireGraph(intent: operation.intent, in: database)
        guard let work = try DurableWorkRecord.fetchOne(database, key: candidate.workId),
              work.kind == .inputParsing, work.aggregateType == "input", work.aggregateId == input.id,
              work.campId == operation.intent.campId, work.version >= candidate.workVersion,
              input.aggregateVersion >= candidate.inputVersion,
              receipt.hashes.first(where: { $0.kind == .inputContent })?.hash == input.contentHash,
              receipt.hashes.first(where: { $0.kind == .durableWorkInput })?.hash == work.inputHash,
              CanonicalJSONV1.sha256Hex(Data(work.inputJson.utf8)) == work.inputHash
        else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        let workInput = try Self.decode(InputParsingWorkInputV1.self, json: work.inputJson)
        guard workInput.inputId == input.id, workInput.contentHash == input.contentHash
        else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        let safe = try Self.captureReceipt(operation.intent, receipt)
        if let existing = stage.receipt {
            guard existing == candidate, operation.safeReceipt == safe
            else { throw DesktopGoalFoundationErrorV1.receiptConflict }
            return existing
        }
        guard expectedVersion == operation.version else { throw DesktopGoalFoundationErrorV1.staleOperationVersion }
        guard operation.safeReceipt == nil else { throw DesktopGoalFoundationErrorV1.receiptConflict }
        let appended = try DesktopGoalSealedStageV1(intent: operation.intent, receipt: candidate)
        let nextVersion = try CanonicalContractCodingV1.checkedIncrement(operation.version)
        try database.execute(sql: """
            UPDATE desktop_goal_operation SET resultJson=?,safeReceiptJson=?,version=?,updatedAt=?
            WHERE id=? AND version=? AND phase='prepared'
            """, arguments: [try CanonicalContractCodingV1.string([appended]), try CanonicalContractCodingV1.string(safe),
                               nextVersion, operation.intent.envelope.occurredAt, operationId, operation.version])
        guard database.changesCount == 1 else { throw DesktopGoalFoundationErrorV1.staleOperationVersion }
        return candidate
    }

    private static func sealCaptureStage(
        operationId: String, expectedVersion: Int, intent: DesktopGoalCaptureIntentV1, in db: Database
    ) throws -> DesktopGoalSealedStageV1 {
        guard let row = try operationRow(operationId, in: db) else { throw DesktopGoalFoundationErrorV1.missingCarrier }
        let operation = try loadOperation(row, in: db)
        try requireVersion(expectedVersion, current: operation.version)
        guard operationId == intent.operationId,
              try Data(operation.requestJSON.utf8) == CanonicalContractCodingV1.encode(intent)
        else { throw DesktopGoalFoundationErrorV1.stageConflict }
        if let stage = operation.stages.first { return stage }
        guard expectedVersion == operation.version else { throw DesktopGoalFoundationErrorV1.staleOperationVersion }
        let stage = try DesktopGoalSealedStageV1(intent: intent)
        let nextVersion = try CanonicalContractCodingV1.checkedIncrement(operation.version)
        try db.execute(sql: """
            UPDATE desktop_goal_operation SET resultJson=?,version=?,updatedAt=? WHERE id=? AND version=? AND phase='prepared'
            """, arguments: [try CanonicalContractCodingV1.string([stage]), nextVersion, intent.envelope.occurredAt, operationId, operation.version])
        guard db.changesCount == 1 else { throw DesktopGoalFoundationErrorV1.staleOperationVersion }
        return stage
    }

    private struct CaptureOperation {
        let intent: DesktopGoalCaptureIntentV1
        let requestJSON: String
        let version: Int
        let stages: [DesktopGoalSealedStageV1]
        let safeReceipt: DesktopGoalCaptureReceiptV1?
    }

    private static func operationRow(_ id: String, in db: Database) throws -> Row? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try Row.fetchOne(db, sql: "SELECT * FROM desktop_goal_operation WHERE id=?", arguments: [id])
    }

    private static func requireVersion(_ expected: Int, current: Int) throws {
        guard expected > 0, expected <= current else { throw DesktopGoalFoundationErrorV1.staleOperationVersion }
    }

    private static func decode<T: Codable>(_ type: T.Type, json: String) throws -> T {
        do { return try CanonicalContractCodingV1.decode(type, from: Data(json.utf8)) }
        catch { throw DesktopGoalFoundationErrorV1.corruptCanonicalPayload }
    }

    // Retention is checked using raw columns before any user payload is decoded.
    private static func requireLive(_ row: Row, in db: Database) throws {
        let inputId: String = row["inputId"]
        let state: String = row["retentionState"]
        let contextJSON: String? = row["contextJson"]
        let input = try Row.fetchOne(db, sql: "SELECT status,retentionState FROM input_envelope WHERE id=?", arguments: [inputId])
        let status: String? = input?["status"]
        let retention: String? = input?["retentionState"]
        if state == "redacted" {
            guard contextJSON == nil else { throw DesktopGoalFoundationErrorV1.retentionIntegrity }
            throw DesktopGoalFoundationErrorV1.inputDeleted
        }
        guard state == "live", contextJSON != nil,
              status != "deletedTombstone", retention != "deletedTombstone"
        else { throw DesktopGoalFoundationErrorV1.retentionIntegrity }
    }

    private static func decodeContext(_ row: Row) throws -> DesktopGoalContextV1 {
        guard let json: String = row["contextJson"] else { throw DesktopGoalFoundationErrorV1.retentionIntegrity }
        let hash: String = row["contextHash"]
        guard CanonicalJSONV1.sha256Hex(Data(json.utf8)) == hash else { throw DesktopGoalFoundationErrorV1.corruptCanonicalPayload }
        let context = try decode(DesktopGoalContextV1.self, json: json)
        let inputId: String = row["inputId"]
        let goalId: String = row["goalId"]
        let version: Int = row["version"]
        guard context.inputId == inputId, context.goalId == goalId, version > 0
        else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        return context
    }

    private static func loadOperation(_ row: Row, in db: Database) throws -> CaptureOperation {
        let inputId: String = row["inputId"]
        guard let contextRow = try Row.fetchOne(db, sql: "SELECT * FROM desktop_goal_context WHERE inputId=?", arguments: [inputId])
        else { throw DesktopGoalFoundationErrorV1.missingCarrier }
        try requireLive(contextRow, in: db)
        let phase: String = row["phase"]
        guard phase != "redacted" else { throw DesktopGoalFoundationErrorV1.retentionIntegrity }
        let context = try decodeContext(contextRow)
        let id: String = row["id"]
        let kind: String = row["kind"]
        let owner: String = row["ownerKind"]
        let version: Int = row["version"]
        let hash: String = row["requestHash"]
        guard let json: String = row["requestJson"], let stagesJSON: String = row["resultJson"],
              kind == "submit", owner == "userMutation", phase == "prepared", version > 0,
              CanonicalJSONV1.sha256Hex(Data(json.utf8)) == hash
        else { throw DesktopGoalFoundationErrorV1.corruptCanonicalPayload }
        let intent = try decode(DesktopGoalCaptureIntentV1.self, json: json)
        let campId: String = contextRow["campId"]
        guard intent.operationId == id, intent.context.inputId == inputId,
              intent.context.goalId == context.goalId, intent.context.sessionId == context.sessionId,
              intent.campId == campId
        else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        let stages = try decode([DesktopGoalSealedStageV1].self, json: stagesJSON)
        guard stages.count <= 1 else { throw DesktopGoalFoundationErrorV1.stageConflict }
        if let stage = stages.first {
            let expected = try DesktopGoalSealedStageV1(intent: intent, receipt: stage.receipt)
            guard stage == expected else { throw DesktopGoalFoundationErrorV1.stageConflict }
        }
        let safeJSON: String? = row["safeReceiptJson"]
        let safe = try safeJSON.map { try decode(DesktopGoalCaptureReceiptV1.self, json: $0) }
        if let safe {
            guard safe.inputId == inputId, safe.goalId == context.goalId, safe.sessionId == context.sessionId,
                  safe.operationId == id, let attached = stages.first?.receipt,
                  try attached == DesktopGoalStageReceiptV1(captureReceipt: safe.captureReceipt)
            else { throw DesktopGoalFoundationErrorV1.receiptConflict }
        } else if stages.first?.receipt != nil { throw DesktopGoalFoundationErrorV1.receiptConflict }
        guard version >= (stages.isEmpty ? 1 : stages.first?.receipt == nil ? 2 : 3)
        else { throw DesktopGoalFoundationErrorV1.stageConflict }
        return CaptureOperation(intent: intent, requestJSON: json, version: version, stages: stages, safeReceipt: safe)
    }

    private static func captureReceipt(_ intent: DesktopGoalCaptureIntentV1, _ receipt: InputCaptureReceiptV1) throws -> DesktopGoalCaptureReceiptV1 {
        try DesktopGoalCaptureReceiptV1(inputId: intent.context.inputId, goalId: intent.context.goalId,
                                       sessionId: intent.context.sessionId, operationId: intent.operationId, captureReceipt: receipt)
    }

    private static func requireGraph(intent: DesktopGoalCaptureIntentV1, in db: Database) throws -> InputEnvelopeRecord {
        guard let input = try InputEnvelopeRecord.fetchOne(db, key: intent.context.inputId)
        else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        guard input.status != .deletedTombstone, input.retentionState != .deletedTombstone
        else { throw DesktopGoalFoundationErrorV1.retentionIntegrity }
        let command = try intent.captureCommand()
        guard input.campId == intent.campId, input.sourceType == .text,
              input.sourceDeviceId == intent.envelope.deviceId, input.idempotencyKey == intent.envelope.idempotencyKey,
              input.connectorId == nil, input.authorId == nil, input.payloadRef == nil, input.parentInputId == nil,
              input.explicitIntent == .createGoal, input.contentHash == command.contentHash,
              input.inlineText.map({ Data($0.utf8) }) == Data(intent.originalText.utf8),
              input.privacyLevel == intent.context.privacyLevel
        else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        let goal = try GoalControllerRecord.fetchOne(db, key: intent.context.goalId)
        if let goal {
            guard goal.sourceInputId == input.id, goal.campId == intent.campId
            else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        } else if input.status == .goalCreated { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        if let session = try CoachSessionRecord.fetchOne(db, key: intent.context.sessionId) {
            guard goal != nil, session.goalId == intent.context.goalId, session.inputId == input.id
            else { throw DesktopGoalFoundationErrorV1.graphScopeMismatch }
        }
        return input
    }
}
