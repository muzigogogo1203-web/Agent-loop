import Foundation
import GRDB
import os

private let activeIngestionDeletionCommandTypeV1 =
    "activeIngestionDeletion.v1"
private let activeIngestionDeletedEventTypeV1 =
    "active_ingestion_deleted_v1"
private let activeIngestionDeletionLogger = Logger(
    subsystem: "com.muzi.agentloop",
    category: "ingestion-deletion"
)

private func recordActiveIngestionDeletionExecutionFailure(
    _ error: any Error
) {
    let errorType = String(reflecting: type(of: error))
    let failureCode = (error as? ActiveIngestionDeletionFailureV1)?.rawValue
        ?? "none"
    let databaseError = error as? DatabaseError
    let sqliteExtendedResult = databaseError?.extendedResultCode.rawValue ?? 0
    let sqliteMessage = databaseError?.message ?? "none"
    activeIngestionDeletionLogger.error(
        "execution_rejected error_type=\(errorType, privacy: .public) failure_code=\(failureCode, privacy: .public) sqlite_extended_result=\(sqliteExtendedResult, privacy: .public) sqlite_message=\(sqliteMessage, privacy: .public)"
    )
}

package struct PreparedActiveIngestionDeletionV1:
    Sendable, Equatable
{
    fileprivate let command: ActiveIngestionDeletionCommandV1

    package var envelope: CommandEnvelopeV1 { command.envelope }
    package var commandPayloadHash: String { command.commandPayloadHash }
    package var preview: ActiveIngestionDeletionSafePreviewV1 {
        command.preview
    }
}

private struct ActiveIngestionDeletionCommandV1:
    Sendable, Equatable
{
    let envelope: CommandEnvelopeV1
    let payload: ActiveIngestionDeletionCommandPayloadV1
    let commandPayloadHash: String
    let preview: ActiveIngestionDeletionSafePreviewV1

    fileprivate init(
        envelope: CommandEnvelopeV1,
        payload: ActiveIngestionDeletionCommandPayloadV1,
        commandPayloadHash: String,
        preview: ActiveIngestionDeletionSafePreviewV1
    ) {
        self.envelope = envelope
        self.payload = payload
        self.commandPayloadHash = commandPayloadHash
        self.preview = preview
    }
}

private struct ActiveIngestionDeletionIngestionSnapshotV1:
    Codable, Sendable, Equatable
{
    let id: String
    let campId: String
    let sourceType: IngestionSourceType
    let title: String?
    let rawText: String
    let sourceURL: String?
    let author: String?
    let userIntent: String?
    let contentHash: String
    let status: IngestionStatus
    let attempt: Int
    let errorText: String?
    let createdAt: Date
    let updatedAt: Date
    let version: Int
    let terminalReason: String?
    let redactedAt: Date?

    init(row: Row) throws {
        guard let sourceType = IngestionSourceType(
            rawValue: row["sourceType"] as String
        ), let status = IngestionStatus(rawValue: row["status"] as String)
        else { throw ActiveIngestionDeletionFailureV1.rowChanged }
        id = row["id"]
        campId = row["campId"]
        self.sourceType = sourceType
        title = row["title"]
        rawText = row["rawText"]
        sourceURL = row["sourceURL"]
        author = row["author"]
        userIntent = row["userIntent"]
        contentHash = row["contentHash"]
        self.status = status
        attempt = row["attempt"]
        errorText = row["errorText"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
        version = row["version"]
        terminalReason = row["terminalReason"]
        redactedAt = row["redactedAt"]
    }

    var hash: String {
        get throws { try CanonicalContractCodingV1.hash(self) }
    }
}

private struct ActiveIngestionDeletionResultSnapshotV1:
    Codable, Sendable, Equatable
{
    let id: String
    let ingestionId: String
    let pipelineVersion: String
    let resultJson: String
    let userEditedJson: String?
    let materializedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let version: Int
    let redactedAt: Date?

    init(row: Row) {
        id = row["id"]
        ingestionId = row["ingestionId"]
        pipelineVersion = row["pipelineVersion"]
        resultJson = row["resultJson"]
        userEditedJson = row["userEditedJson"]
        materializedAt = row["materializedAt"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
        version = row["version"]
        redactedAt = row["redactedAt"]
    }

    var hash: String {
        get throws { try CanonicalContractCodingV1.hash(self) }
    }
}

private struct ActiveIngestionDeletionReadSnapshotV1 {
    let lifecycleVersion: Int
    let ingestion: ActiveIngestionDeletionIngestionSnapshotV1
    let result: ActiveIngestionDeletionResultSnapshotV1?
    let blockerCounts: ActiveIngestionDeletionPermitExpectedCountsV1
}

private enum ActiveIngestionDeletionInternalResolutionV1: Error {
    case pending(ActiveIngestionDeletionResolutionDispositionV1)
}

#if DEBUG
package enum ActiveIngestionDeletionPreviewCheckpointV1:
    String, Sendable, Equatable
{
    case beforeEvidenceWrites
}

private struct ActiveIngestionDeletionPreviewFailureV1: Error, Sendable {}
#endif

package struct IngestionDeletionStore: Sendable {
    private let database: AppDatabase
    private let clock: @Sendable () -> Date
#if DEBUG
    private let previewCheckpoint:
        ActiveIngestionDeletionPreviewCheckpointV1?
#endif

    package init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.database = database
        self.clock = clock
#if DEBUG
        previewCheckpoint = nil
#endif
    }

#if DEBUG
    package init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        previewCheckpoint: ActiveIngestionDeletionPreviewCheckpointV1?
    ) {
        self.database = database
        self.clock = clock
        self.previewCheckpoint = previewCheckpoint
    }
#endif

    package func prepareActiveIngestionDeletion(
        request: ActiveIngestionDeletionPrepareRequestV1
    ) throws -> PreparedActiveIngestionDeletionV1 {
        guard request.scope != .everythingIncludingProjection else {
            throw ActiveIngestionDeletionFailureV1.projectionDeletionUnsupported
        }
        return try database.pool.read { transaction in
            try validateAllPersistedGraphs(in: transaction)
            let snapshot = try readSnapshot(
                campId: request.campId,
                ingestionId: request.ingestionId,
                in: transaction
            )
            let payload = try commandPayload(
                scope: request.scope,
                snapshot: snapshot
            )
            let commandHash = try CanonicalContractCodingV1.wholeCommandHash(
                envelope: request.envelope,
                payload: payload
            )
            let preview = ActiveIngestionDeletionSafePreviewV1(
                campId: payload.campId,
                ingestionId: payload.ingestionId,
                oldIngestionStatus: payload.oldIngestionStatus,
                resultId: payload.resultId,
                scope: payload.scope,
                deletedResultCount: payload.deletedResultCount,
                deletedIngestionCount: payload.deletedIngestionCount,
                updatedIngestionCount: payload.updatedIngestionCount,
                knowledgeSourceLinkCount: payload.knowledgeSourceLinkCount,
                actionCandidateCount: payload.actionCandidateCount,
                nonterminalRuminationWorkCount:
                    payload.nonterminalRuminationWorkCount,
                openRuminationAttemptCount: payload.openRuminationAttemptCount,
                nonterminalProviderDispatchCount:
                    payload.nonterminalProviderDispatchCount
            )
            return PreparedActiveIngestionDeletionV1(
                command: ActiveIngestionDeletionCommandV1(
                    envelope: request.envelope,
                    payload: payload,
                    commandPayloadHash: commandHash,
                    preview: preview
                )
            )
        }
    }

    package func executeActiveIngestionDeletion(
        preparedCommand: PreparedActiveIngestionDeletionV1
    ) -> ActiveIngestionDeletionExecutionResolutionV1 {
        do {
            return try database.pool.write { transaction in
                try execute(
                    preparedCommand.command,
                    in: transaction
                )
            }
        } catch let failure as ActiveIngestionDeletionFailureV1 {
            recordActiveIngestionDeletionExecutionFailure(failure)
            let resolved = resolveActiveIngestionDeletionExecution(
                preparedCommand: preparedCommand
            )
            if case .notCommitted = resolved {
                return .notCommitted(failure)
            }
            return resolved
        } catch let resolution as ActiveIngestionDeletionInternalResolutionV1 {
            switch resolution {
            case .pending(let disposition):
                return .resolutionPending(disposition)
            }
        } catch {
            recordActiveIngestionDeletionExecutionFailure(error)
            let resolved = resolveActiveIngestionDeletionExecution(
                preparedCommand: preparedCommand
            )
            if case .notCommitted = resolved {
                return .notCommitted(.mutationRejected)
            }
            return resolved
        }
    }

    package func resolveActiveIngestionDeletionExecution(
        preparedCommand: PreparedActiveIngestionDeletionV1
    ) -> ActiveIngestionDeletionExecutionResolutionV1 {
        do {
            return try database.pool.writeWithoutTransaction { transaction in
                try database.activeIngestionDeletionSQLPermitRegistry
                    .assertNoActiveGenerationForResolution(for: transaction)
                guard let receipt = try Row.fetchOne(
                    transaction,
                    sql: "SELECT * FROM domain_command_receipt WHERE idempotencyKey=?",
                    arguments: [preparedCommand.envelope.idempotencyKey]
                ) else {
                    return .notCommitted(.notExecuted)
                }
                guard receipt["commandType"] as String
                        == activeIngestionDeletionCommandTypeV1,
                      receipt["commandPayloadHash"] as String
                        == preparedCommand.commandPayloadHash,
                      receipt["eventCount"] as Int == 1
                else {
                    return .resolutionPending(.terminalConflict)
                }
                do {
                    let result = try validateCommittedGraph(
                        receipt: receipt,
                        expectedCommand: preparedCommand.command,
                        in: transaction
                    )
                    return .committed(result)
                } catch {
                    return .resolutionPending(.integrityBlocked)
                }
            }
        } catch {
            return .resolutionPending(.commitOutcomeUnknown)
        }
    }
}

private extension IngestionDeletionStore {
    func execute(
        _ command: ActiveIngestionDeletionCommandV1,
        in transaction: Database
    ) throws -> ActiveIngestionDeletionExecutionResolutionV1 {
        if let receipt = try Row.fetchOne(
            transaction,
            sql: "SELECT * FROM domain_command_receipt WHERE idempotencyKey=?",
            arguments: [command.envelope.idempotencyKey]
        ) {
            guard receipt["commandType"] as String
                    == activeIngestionDeletionCommandTypeV1,
                  receipt["commandPayloadHash"] as String
                    == command.commandPayloadHash,
                  receipt["eventCount"] as Int == 1
            else {
                throw ActiveIngestionDeletionInternalResolutionV1.pending(
                    .terminalConflict
                )
            }
            do {
                return .committed(try validateCommittedGraph(
                    receipt: receipt,
                    expectedCommand: command,
                    in: transaction
                ))
            } catch {
                throw ActiveIngestionDeletionInternalResolutionV1.pending(
                    .integrityBlocked
                )
            }
        }

        try validateAllPersistedGraphs(in: transaction)
        let snapshot: ActiveIngestionDeletionReadSnapshotV1
        do {
            snapshot = try readSnapshot(
                campId: command.payload.campId,
                ingestionId: command.payload.ingestionId,
                in: transaction
            )
        } catch ActiveIngestionDeletionFailureV1.campUnavailable {
            throw ActiveIngestionDeletionFailureV1.lifecycleChanged
        }
        guard snapshot.lifecycleVersion
                == command.payload.expectedLifecycleVersion
        else { throw ActiveIngestionDeletionFailureV1.lifecycleChanged }
        let livePayload: ActiveIngestionDeletionCommandPayloadV1
        do {
            livePayload = try commandPayload(
                scope: command.payload.scope,
                snapshot: snapshot
            )
        } catch ActiveIngestionDeletionFailureV1.knowledgeSourceLinkBlocker,
                ActiveIngestionDeletionFailureV1.actionCandidateBlocker,
                ActiveIngestionDeletionFailureV1.ruminationWorkBlocker,
                ActiveIngestionDeletionFailureV1.ruminationAttemptBlocker,
                ActiveIngestionDeletionFailureV1.providerDispatchBlocker
        {
            throw ActiveIngestionDeletionFailureV1.blockersChanged
        } catch ActiveIngestionDeletionFailureV1.invalidIngestionState,
                ActiveIngestionDeletionFailureV1.resultRequired,
                ActiveIngestionDeletionFailureV1.resultMaterialized
        {
            throw ActiveIngestionDeletionFailureV1.rowChanged
        }
        guard livePayload == command.payload,
              try CanonicalContractCodingV1.wholeCommandHash(
                envelope: command.envelope,
                payload: livePayload
              ) == command.commandPayloadHash
        else { throw ActiveIngestionDeletionFailureV1.rowChanged }

        let eventID = UUID().uuidString
        let recordedAt = max(clock(), command.envelope.occurredAt)
        let eventPayload = try ActiveIngestionDeletionEventPayloadV1(
            commandIdempotencyKey: command.envelope.idempotencyKey,
            commandPayloadHash: command.commandPayloadHash,
            payload: command.payload
        )
        let eventPayloadBytes = try CanonicalJSONV1.encode(eventPayload)
        let eventPayloadJSON = String(
            decoding: eventPayloadBytes,
            as: UTF8.self
        )
        let eventPayloadHash = CanonicalJSONV1.sha256Hex(eventPayloadBytes)
        let safeResult = try ActiveIngestionDeletionResultV1(
            commandIdempotencyKey: command.envelope.idempotencyKey,
            commandPayloadHash: command.commandPayloadHash,
            eventId: eventID,
            eventPayloadHash: eventPayloadHash,
            payload: command.payload
        )
        let resultBytes = try CanonicalJSONV1.encode(safeResult)
        let resultJSON = String(decoding: resultBytes, as: UTF8.self)
        let resultHash = CanonicalJSONV1.sha256Hex(resultBytes)

#if DEBUG
        if previewCheckpoint == .beforeEvidenceWrites {
            throw ActiveIngestionDeletionPreviewFailureV1()
        }
#endif

        let registry = database.activeIngestionDeletionSQLPermitRegistry
        let cell = try registry.requireWriterCell(for: transaction)
        let generation = try registry.beginGeneration(
            on: cell,
            expectedCounts: ActiveIngestionDeletionPermitExpectedCountsV1(
                payload: command.payload
            )
        )
        transaction.afterNextTransaction(
            onCommit: { _ in
                registry.observeTransactionBoundary(
                    token: generation,
                    cell: cell
                )
            },
            onRollback: { _ in
                registry.observeTransactionBoundary(
                    token: generation,
                    cell: cell
                )
            }
        )
        defer {
            registry.clearGeneration(token: generation, cell: cell)
        }

        try transaction.execute(
            sql: """
                INSERT INTO domain_command_receipt(
                  idempotencyKey,commandType,commandPayloadHash,eventCount,
                  resultJson,resultHash,createdAt
                ) VALUES (?,?,?,?,?,?,?)
                """,
            arguments: [
                command.envelope.idempotencyKey,
                activeIngestionDeletionCommandTypeV1,
                command.commandPayloadHash, 1, resultJSON, resultHash,
                recordedAt,
            ]
        )
        try requireSingleChange(transaction)
        try registry.advanceEvidence(
            .receipt, token: generation, cell: cell
        )

        try transaction.execute(
            sql: """
                INSERT INTO camp_event_scope(
                  sourceTable,eventId,scopeKind,campId,payloadRedactedAt
                ) VALUES ('domain_event',?,'camp',?,NULL)
                """,
            arguments: [eventID, command.payload.campId]
        )
        try requireSingleChange(transaction)
        try registry.advanceEvidence(.scope, token: generation, cell: cell)

        try transaction.execute(
            sql: """
                INSERT INTO domain_event(
                  id,campId,aggregateType,aggregateId,aggregateVersion,
                  eventType,payloadVersion,payloadJson,payloadHash,
                  actorType,actorId,deviceId,causationId,correlationId,
                  commandIdempotencyKey,eventOrdinal,eventIdempotencyKey,
                  occurredAt,recordedAt
                ) VALUES (?,?, 'ingestion',?,?,?,1,?,?,?,?,?,?,?,?,0,?,?,?)
                """,
            arguments: [
                eventID, command.payload.campId,
                command.payload.ingestionId,
                try checkedIncrement(command.payload.oldIngestionVersion),
                activeIngestionDeletedEventTypeV1,
                eventPayloadJSON, eventPayloadHash,
                command.envelope.actorType.rawValue,
                command.envelope.actorId,
                command.envelope.deviceId,
                command.envelope.causationId,
                command.envelope.correlationId,
                command.envelope.idempotencyKey,
                "\(command.envelope.idempotencyKey)#0000:ingestion:\(command.payload.ingestionId)",
                command.envelope.occurredAt, recordedAt,
            ]
        )
        try requireSingleChange(transaction)
        try registry.advanceEvidence(.event, token: generation, cell: cell)

        try transaction.execute(
            sql: """
                INSERT INTO event_outbox(
                  eventId,state,attempt,notBefore,leaseOwner,leaseExpiresAt,
                  lastError,version,createdAt,updatedAt,sentAt
                ) VALUES (?,'pending',0,NULL,NULL,NULL,NULL,1,?,?,NULL)
                """,
            arguments: [eventID, recordedAt, recordedAt]
        )
        try requireSingleChange(transaction)
        try registry.advanceEvidence(.outbox, token: generation, cell: cell)

        var observedDeletedResult = 0
        if command.payload.deletedResultCount == 1 {
            let values = try invocationValues(
                .deleteResult,
                eventID: eventID,
                ingestionID: command.payload.ingestionId,
                resultID: command.payload.resultId,
                in: transaction
            )
            try registry.registerExpectedInvocation(
                values,
                invocation: .deleteResult,
                token: generation,
                cell: cell
            )
            try transaction.execute(
                sql: "DELETE FROM rumination_result WHERE id=? AND ingestionId=? AND version=?",
                arguments: [
                    command.payload.resultId,
                    command.payload.ingestionId,
                    command.payload.resultVersion,
                ]
            )
            observedDeletedResult = transaction.changesCount
            guard observedDeletedResult == 1 else {
                throw ActiveIngestionDeletionFailureV1.mutationRejected
            }
        } else {
            try transaction.execute(
                sql: "DELETE FROM rumination_result WHERE ingestionId=?",
                arguments: [command.payload.ingestionId]
            )
            observedDeletedResult = transaction.changesCount
            guard observedDeletedResult == 0 else {
                throw ActiveIngestionDeletionFailureV1.mutationRejected
            }
            try registry.consumeStoreMutation(
                .resultMutation,
                token: generation,
                cell: cell
            )
        }

        var observedDeletedIngestion = 0
        var observedUpdatedIngestion = 0
        switch command.payload.scope {
        case .sourceAndResult:
            let values = try invocationValues(
                .deleteIngestion,
                eventID: eventID,
                ingestionID: command.payload.ingestionId,
                resultID: nil,
                in: transaction
            )
            try registry.registerExpectedInvocation(
                values,
                invocation: .deleteIngestion,
                token: generation,
                cell: cell
            )
            try transaction.execute(
                sql: "DELETE FROM ingestion_item WHERE id=? AND campId=? AND version=?",
                arguments: [
                    command.payload.ingestionId,
                    command.payload.campId,
                    command.payload.oldIngestionVersion,
                ]
            )
            observedDeletedIngestion = transaction.changesCount
            guard observedDeletedIngestion == 1 else {
                throw ActiveIngestionDeletionFailureV1.mutationRejected
            }
        case .resultOnly:
            let nextIngestionVersion = try checkedIncrement(
                command.payload.oldIngestionVersion
            )
            try transaction.execute(
                sql: """
                    UPDATE ingestion_item
                    SET status='queued',errorText=NULL,updatedAt=?,version=version+1
                    WHERE id=? AND campId=? AND version=? AND status=?
                      AND terminalReason IS NULL AND redactedAt IS NULL
                    """,
                arguments: [
                    command.envelope.occurredAt,
                    command.payload.ingestionId,
                    command.payload.campId,
                    command.payload.oldIngestionVersion,
                    command.payload.oldIngestionStatus.rawValue,
                ]
            )
            observedUpdatedIngestion = transaction.changesCount
            guard observedUpdatedIngestion == 1,
                  let post = try Row.fetchOne(
                    transaction,
                    sql: "SELECT status,errorText,version FROM ingestion_item WHERE id=?",
                    arguments: [command.payload.ingestionId]
                  ),
                  post["status"] as String == IngestionStatus.queued.rawValue,
                  (post["errorText"] as String?) == nil,
                  post["version"] as Int == nextIngestionVersion
            else { throw ActiveIngestionDeletionFailureV1.mutationRejected }
            try registry.consumeStoreMutation(
                .ingestionMutation,
                token: generation,
                cell: cell
            )
        case .everythingIncludingProjection:
            throw ActiveIngestionDeletionFailureV1.projectionDeletionUnsupported
        }

        let liveBlockers = try blockerCounts(
            campId: command.payload.campId,
            ingestionId: command.payload.ingestionId,
            in: transaction
        )
        let observed = ActiveIngestionDeletionPermitExpectedCountsV1(
            deletedResultCount: observedDeletedResult,
            deletedIngestionCount: observedDeletedIngestion,
            updatedIngestionCount: observedUpdatedIngestion,
            knowledgeSourceLinkCount: liveBlockers.knowledgeSourceLinkCount,
            actionCandidateCount: liveBlockers.actionCandidateCount,
            nonterminalRuminationWorkCount:
                liveBlockers.nonterminalRuminationWorkCount,
            openRuminationAttemptCount:
                liveBlockers.openRuminationAttemptCount,
            nonterminalProviderDispatchCount:
                liveBlockers.nonterminalProviderDispatchCount
        )
        try registry.finishGeneration(
            token: generation,
            cell: cell,
            observedCounts: observed
        )
        guard let receipt = try Row.fetchOne(
            transaction,
            sql: "SELECT * FROM domain_command_receipt WHERE idempotencyKey=?",
            arguments: [command.envelope.idempotencyKey]
        ) else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }
        return .committed(try validateCommittedGraph(
            receipt: receipt,
            expectedCommand: command,
            in: transaction
        ))
    }

    func requireSingleChange(_ transaction: Database) throws {
        guard transaction.changesCount == 1 else {
            throw ActiveIngestionDeletionFailureV1.mutationRejected
        }
    }

    func checkedIncrement(_ value: Int) throws -> Int {
        let (incremented, overflow) = value.addingReportingOverflow(1)
        guard !overflow else {
            throw ActiveIngestionDeletionFailureV1.rowChanged
        }
        return incremented
    }

    func invocationValues(
        _ invocation: ActiveIngestionDeletionPermitInvocationV1,
        eventID: String,
        ingestionID: String,
        resultID: String?,
        in transaction: Database
    ) throws -> [DatabaseValue] {
        let resultColumns = invocation == .deleteResult
            ? """
              , result.id, result.ingestionId, result.pipelineVersion,
                result.resultJson, result.userEditedJson, result.materializedAt,
                result.createdAt, result.updatedAt, result.version,
                result.redactedAt
              """
            : ""
        let resultJoin = invocation == .deleteResult
            ? "JOIN rumination_result AS result ON result.id=? AND result.ingestionId=ingestion.id"
            : ""
        let sql = """
            SELECT
              ?, event.commandIdempotencyKey, receipt.commandPayloadHash,
              event.id, event.payloadHash, event.actorType, event.actorId,
              event.deviceId, event.correlationId, event.causationId,
              event.occurredAt, event.recordedAt, ingestion.campId,
              lifecycle.version, json_extract(event.payloadJson,'$.scope'),
              json_extract(event.payloadJson,'$.ingestionSnapshotHash'),
              json_extract(event.payloadJson,'$.resultHash'),
              json_extract(event.payloadJson,'$.deletedResultCount'),
              json_extract(event.payloadJson,'$.deletedIngestionCount'),
              json_extract(event.payloadJson,'$.updatedIngestionCount'),
              json_extract(event.payloadJson,'$.knowledgeSourceLinkCount'),
              json_extract(event.payloadJson,'$.actionCandidateCount'),
              json_extract(event.payloadJson,'$.nonterminalRuminationWorkCount'),
              json_extract(event.payloadJson,'$.openRuminationAttemptCount'),
              json_extract(event.payloadJson,'$.nonterminalProviderDispatchCount'),
              outbox.eventId, outbox.state, outbox.attempt, outbox.notBefore,
              outbox.leaseOwner, outbox.leaseExpiresAt, outbox.lastError,
              outbox.version, outbox.createdAt, outbox.updatedAt, outbox.sentAt,
              ingestion.id, ingestion.campId, ingestion.sourceType,
              ingestion.title, ingestion.rawText, ingestion.sourceURL,
              ingestion.author, ingestion.userIntent, ingestion.contentHash,
              ingestion.status, ingestion.attempt, ingestion.errorText,
              ingestion.createdAt, ingestion.updatedAt, ingestion.version,
              ingestion.terminalReason, ingestion.redactedAt
              \(resultColumns)
            FROM domain_event AS event
            JOIN domain_command_receipt AS receipt
              ON receipt.idempotencyKey=event.commandIdempotencyKey
            JOIN event_outbox AS outbox ON outbox.eventId=event.id
            JOIN ingestion_item AS ingestion ON ingestion.id=?
            JOIN camp_lifecycle AS lifecycle
              ON lifecycle.campId=ingestion.campId
            \(resultJoin)
            WHERE event.id=?
            """
        var arguments: [DatabaseValueConvertible?] = [
            invocation.rawValue, ingestionID,
        ]
        if invocation == .deleteResult { arguments.append(resultID) }
        arguments.append(eventID)
        guard let row = try Row.fetchOne(
            transaction,
            sql: sql,
            arguments: StatementArguments(arguments)
        ) else { throw ActiveIngestionDeletionFailureV1.rowChanged }
        let values = Array(row.databaseValues)
        guard values.count == (invocation == .deleteResult ? 63 : 53) else {
            throw ActiveIngestionDeletionFailureV1.rowChanged
        }
        return values
    }

    func validateAllPersistedGraphs(in transaction: Database) throws {
        let receipts = try Row.fetchAll(
            transaction,
            sql: """
                SELECT * FROM domain_command_receipt
                WHERE commandType=? ORDER BY createdAt,idempotencyKey
                """,
            arguments: [activeIngestionDeletionCommandTypeV1]
        )
        for receipt in receipts {
            do {
                _ = try validateCommittedGraph(
                    receipt: receipt,
                    expectedCommand: nil,
                    in: transaction
                )
            } catch {
                throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity
            }
        }
    }

    func validateCommittedGraph(
        receipt: Row,
        expectedCommand: ActiveIngestionDeletionCommandV1?,
        in transaction: Database
    ) throws -> ActiveIngestionDeletionResultV1 {
        let key: String = receipt["idempotencyKey"]
        let commandType: String = receipt["commandType"]
        let commandHash: String = receipt["commandPayloadHash"]
        let eventCount: Int = receipt["eventCount"]
        let resultJSON: String = receipt["resultJson"]
        let persistedResultHash: String = receipt["resultHash"]
        let persistedReceiptCreatedAt: Date = receipt["createdAt"]
        let receiptCreatedAt = try P1DTimestampV1.restorePersisted(
            persistedReceiptCreatedAt
        )
        guard commandType == activeIngestionDeletionCommandTypeV1,
              eventCount == 1,
              commandHash.count == 64,
              persistedResultHash.count == 64
        else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }
        let resultBytes = Data(resultJSON.utf8)
        let result = try CanonicalContractCodingV1.decode(
            ActiveIngestionDeletionResultV1.self,
            from: resultBytes
        )
        guard CanonicalJSONV1.sha256Hex(resultBytes) == persistedResultHash,
              result.commandIdempotencyKey == key,
              result.commandPayloadHash == commandHash
        else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }

        let scopes = try Row.fetchAll(
            transaction,
            sql: """
                SELECT * FROM camp_event_scope
                WHERE sourceTable='domain_event' AND eventId=?
                """,
            arguments: [result.eventId]
        )
        guard scopes.count == 1,
              scopes[0]["scopeKind"] as String == "camp",
              scopes[0]["campId"] as String? == result.campId,
              (scopes[0]["payloadRedactedAt"] as Date?) == nil
        else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }

        let events = try Row.fetchAll(
            transaction,
            sql: "SELECT * FROM domain_event WHERE commandIdempotencyKey=?",
            arguments: [key]
        )
        guard events.count == 1 else {
            throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity
        }
        let event = events[0]
        let eventID: String = event["id"]
        let eventPayloadJSON: String = event["payloadJson"]
        let eventPayloadHash: String = event["payloadHash"]
        let actorTypeRaw: String = event["actorType"]
        let actorID: String = event["actorId"]
        let deviceID: String? = event["deviceId"]
        let correlationID: String = event["correlationId"]
        let causationID: String? = event["causationId"]
        let persistedOccurredAt: Date = event["occurredAt"]
        let occurredAt = try P1DTimestampV1.restorePersisted(
            persistedOccurredAt
        )
        let persistedRecordedAt: Date = event["recordedAt"]
        let recordedAt = try P1DTimestampV1.restorePersisted(
            persistedRecordedAt
        )
        let expectedAggregateVersion = try checkedIncrement(
            result.oldIngestionVersion
        )
        guard let actorType = DomainActorType(rawValue: actorTypeRaw),
              actorType == .user,
              deviceID != nil,
              !actorID.isEmpty,
              !correlationID.isEmpty,
              recordedAt >= occurredAt,
              receiptCreatedAt == recordedAt,
              eventID == result.eventId,
              eventPayloadHash == result.eventPayloadHash,
              event["campId"] as String == result.campId,
              event["aggregateType"] as String == "ingestion",
              event["aggregateId"] as String == result.ingestionId,
              event["aggregateVersion"] as Int == expectedAggregateVersion,
              event["eventType"] as String
                == activeIngestionDeletedEventTypeV1,
              event["payloadVersion"] as Int == 1,
              event["commandIdempotencyKey"] as String == key,
              event["eventOrdinal"] as Int == 0,
              event["eventIdempotencyKey"] as String
                == "\(key)#0000:ingestion:\(result.ingestionId)"
        else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }
        let eventPayloadBytes = Data(eventPayloadJSON.utf8)
        let eventPayload = try CanonicalContractCodingV1.decode(
            ActiveIngestionDeletionEventPayloadV1.self,
            from: eventPayloadBytes
        )
        guard CanonicalJSONV1.sha256Hex(eventPayloadBytes) == eventPayloadHash,
              eventPayload.commandIdempotencyKey == key,
              eventPayload.commandPayloadHash == commandHash,
              eventPayload.payload == (try result.payload)
        else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }

        let envelope = try CommandEnvelopeV1(
            idempotencyKey: key,
            actorType: actorType,
            actorId: actorID,
            deviceId: deviceID,
            correlationId: correlationID,
            causationId: causationID,
            occurredAt: occurredAt
        )
        let reconstructedHash = try CanonicalContractCodingV1.wholeCommandHash(
            envelope: envelope,
            payload: eventPayload.payload
        )
        guard reconstructedHash == commandHash else {
            throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity
        }

        let outboxes = try Row.fetchAll(
            transaction,
            sql: "SELECT * FROM event_outbox WHERE eventId=?",
            arguments: [eventID]
        )
        guard outboxes.count == 1,
              try validOutbox(outboxes[0], eventRecordedAt: recordedAt)
        else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }

        if let expectedCommand {
            guard expectedCommand.envelope == envelope,
                  expectedCommand.payload == eventPayload.payload,
                  expectedCommand.commandPayloadHash == reconstructedHash
            else { throw ActiveIngestionDeletionFailureV1.persistedGraphIntegrity }
        }
        return result
    }

    func validOutbox(_ row: Row, eventRecordedAt: Date) throws -> Bool {
        let state: String = row["state"]
        let attempt: Int = row["attempt"]
        let persistedNotBefore: Date? = row["notBefore"]
        let notBefore = try P1DTimestampV1.restorePersisted(
            persistedNotBefore
        )
        let leaseOwner: String? = row["leaseOwner"]
        let persistedLeaseExpiresAt: Date? = row["leaseExpiresAt"]
        let leaseExpiresAt = try P1DTimestampV1.restorePersisted(
            persistedLeaseExpiresAt
        )
        let lastError: String? = row["lastError"]
        let version: Int = row["version"]
        let persistedCreatedAt: Date = row["createdAt"]
        let createdAt = try P1DTimestampV1.restorePersisted(
            persistedCreatedAt
        )
        let persistedUpdatedAt: Date = row["updatedAt"]
        let updatedAt = try P1DTimestampV1.restorePersisted(
            persistedUpdatedAt
        )
        let persistedSentAt: Date? = row["sentAt"]
        let sentAt = try P1DTimestampV1.restorePersisted(
            persistedSentAt
        )
        guard attempt >= 0, version >= 1,
              createdAt == eventRecordedAt,
              updatedAt >= createdAt
        else { return false }
        switch state {
        case "pending":
            guard leaseOwner == nil, leaseExpiresAt == nil, sentAt == nil else {
                return false
            }
            if attempt == 0 {
                return version == 1 && notBefore == nil && lastError == nil
                    && updatedAt == createdAt
            }
            return version > 1
        case "dispatching":
            return leaseOwner?.isEmpty == false && leaseExpiresAt != nil
                && sentAt == nil && version > 1
        case "sent":
            return leaseOwner == nil && leaseExpiresAt == nil
                && sentAt != nil && version > 1
        case "failed":
            return leaseOwner == nil && leaseExpiresAt == nil
                && sentAt == nil && lastError?.isEmpty == false && version > 1
        default:
            return false
        }
    }

    func readSnapshot(
        campId: String,
        ingestionId: String,
        in transaction: Database
    ) throws -> ActiveIngestionDeletionReadSnapshotV1 {
        guard let lifecycle = try Row.fetchOne(
            transaction,
            sql: """
                SELECT lifecycle.state,lifecycle.version,camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [campId]
        ) else { throw ActiveIngestionDeletionFailureV1.campUnavailable }
        guard lifecycle["state"] as String == "active",
              lifecycle["archived"] as Int == 0
        else { throw ActiveIngestionDeletionFailureV1.campUnavailable }
        let lifecycleVersion: Int = lifecycle["version"]
        guard let ingestionRow = try Row.fetchOne(
            transaction,
            sql: "SELECT * FROM ingestion_item WHERE id=? AND campId=?",
            arguments: [ingestionId, campId]
        ) else { throw ActiveIngestionDeletionFailureV1.sourceNotFound }
        let ingestion = try ActiveIngestionDeletionIngestionSnapshotV1(
            row: ingestionRow
        )
        guard ingestion.terminalReason == nil, ingestion.redactedAt == nil else {
            throw ActiveIngestionDeletionFailureV1.sourceNotFound
        }
        let result = try Row.fetchOne(
            transaction,
            sql: "SELECT * FROM rumination_result WHERE ingestionId=?",
            arguments: [ingestionId]
        ).map(ActiveIngestionDeletionResultSnapshotV1.init(row:))
        let counts = try blockerCounts(
            campId: campId,
            ingestionId: ingestionId,
            in: transaction
        )
        return ActiveIngestionDeletionReadSnapshotV1(
            lifecycleVersion: lifecycleVersion,
            ingestion: ingestion,
            result: result,
            blockerCounts: counts
        )
    }

    func commandPayload(
        scope: ActiveIngestionDeletionScopeV1,
        snapshot: ActiveIngestionDeletionReadSnapshotV1
    ) throws -> ActiveIngestionDeletionCommandPayloadV1 {
        let ingestion = snapshot.ingestion
        let result = snapshot.result
        guard snapshot.blockerCounts.knowledgeSourceLinkCount == 0 else {
            throw ActiveIngestionDeletionFailureV1.knowledgeSourceLinkBlocker
        }
        guard snapshot.blockerCounts.actionCandidateCount == 0 else {
            throw ActiveIngestionDeletionFailureV1.actionCandidateBlocker
        }
        guard snapshot.blockerCounts.nonterminalRuminationWorkCount == 0 else {
            throw ActiveIngestionDeletionFailureV1.ruminationWorkBlocker
        }
        guard snapshot.blockerCounts.openRuminationAttemptCount == 0 else {
            throw ActiveIngestionDeletionFailureV1.ruminationAttemptBlocker
        }
        guard snapshot.blockerCounts.nonterminalProviderDispatchCount == 0 else {
            throw ActiveIngestionDeletionFailureV1.providerDispatchBlocker
        }

        let counts: (deletedResult: Int, deletedIngestion: Int, updated: Int)
        switch scope {
        case .resultOnly:
            guard ingestion.status == .needsReview
                    || ingestion.status == .failed
            else { throw ActiveIngestionDeletionFailureV1.invalidIngestionState }
            guard let result else {
                throw ActiveIngestionDeletionFailureV1.resultRequired
            }
            guard result.materializedAt == nil, result.redactedAt == nil else {
                throw ActiveIngestionDeletionFailureV1.resultMaterialized
            }
            counts = (1, 0, 1)
        case .sourceAndResult:
            guard [.queued, .failed, .needsReview, .discarded]
                .contains(ingestion.status)
            else { throw ActiveIngestionDeletionFailureV1.invalidIngestionState }
            if let result {
                guard result.materializedAt == nil, result.redactedAt == nil else {
                    throw ActiveIngestionDeletionFailureV1.resultMaterialized
                }
            }
            counts = (result == nil ? 0 : 1, 1, 0)
        case .everythingIncludingProjection:
            throw ActiveIngestionDeletionFailureV1.projectionDeletionUnsupported
        }
        return try ActiveIngestionDeletionCommandPayloadV1(
            campId: ingestion.campId,
            expectedLifecycleVersion: snapshot.lifecycleVersion,
            ingestionId: ingestion.id,
            oldIngestionVersion: ingestion.version,
            oldIngestionStatus: ingestion.status,
            ingestionContentHash: ingestion.contentHash,
            ingestionSnapshotHash: ingestion.hash,
            resultId: result?.id,
            resultVersion: result?.version,
            resultHash: try result?.hash,
            scope: scope,
            deletedResultCount: counts.deletedResult,
            deletedIngestionCount: counts.deletedIngestion,
            updatedIngestionCount: counts.updated,
            knowledgeSourceLinkCount: 0,
            actionCandidateCount: 0,
            nonterminalRuminationWorkCount: 0,
            openRuminationAttemptCount: 0,
            nonterminalProviderDispatchCount: 0
        )
    }

    func blockerCounts(
        campId: String,
        ingestionId: String,
        in transaction: Database
    ) throws -> ActiveIngestionDeletionPermitExpectedCountsV1 {
        func count(_ sql: String) throws -> Int {
            try Int.fetchOne(
                transaction,
                sql: sql,
                arguments: [campId, ingestionId]
            ) ?? 0
        }
        let links = try Int.fetchOne(
            transaction,
            sql: "SELECT COUNT(*) FROM knowledge_source_link WHERE ingestionId=?",
            arguments: [ingestionId]
        ) ?? 0
        let candidates = try Int.fetchOne(
            transaction,
            sql: "SELECT COUNT(*) FROM action_candidate WHERE ingestionId=?",
            arguments: [ingestionId]
        ) ?? 0
        let works = try count("""
            SELECT COUNT(*) FROM durable_work
            WHERE campId=? AND kind='rumination' AND aggregateType='ingestion'
              AND aggregateId=? AND state IN ('queued','running','retryScheduled')
            """)
        let attempts = try count("""
            SELECT COUNT(*) FROM durable_work_attempt AS attempt
            JOIN durable_work AS work ON work.id=attempt.workId
            WHERE work.campId=? AND work.kind='rumination'
              AND work.aggregateType='ingestion' AND work.aggregateId=?
              AND attempt.endedAt IS NULL
            """)
        let dispatches = try count("""
            SELECT COUNT(*) FROM camp_provider_dispatch AS dispatch
            JOIN durable_work AS work ON work.id=dispatch.workId
            WHERE work.campId=? AND work.kind='rumination'
              AND work.aggregateType='ingestion' AND work.aggregateId=?
              AND dispatch.state IN ('prepared','started','returned')
            """)
        return ActiveIngestionDeletionPermitExpectedCountsV1(
            deletedResultCount: 0,
            deletedIngestionCount: 0,
            updatedIngestionCount: 0,
            knowledgeSourceLinkCount: links,
            actionCandidateCount: candidates,
            nonterminalRuminationWorkCount: works,
            openRuminationAttemptCount: attempts,
            nonterminalProviderDispatchCount: dispatches
        )
    }
}
