import Foundation
import GRDB

package struct DomainEventStore: Sendable {
    private let database: AppDatabase
    private let clock: @Sendable () -> Date
    private let eventIdFactory: @Sendable () -> String

    package init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = { Date() },
        eventIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        }
    ) {
        self.database = database
        self.clock = clock
        self.eventIdFactory = eventIdFactory
    }

    package func executeCommand(
        command: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1,
        database transactionDatabase: Database,
        makeNew: (Database) throws -> NewDomainCommandV1
    ) throws -> CampSafeCommandResultV1 {
        try executeStrictCommand(
            command: command,
            replayPlan: replayPlan,
            explicitRecordedAt: nil,
            database: transactionDatabase,
            makeNew: makeNew
        ).result
    }

    package func executeCommand(
        command: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1,
        recordedAt: Date,
        database transactionDatabase: Database,
        makeNew: (Database) throws -> NewDomainCommandV1
    ) throws -> DomainCommandExecutionMetadataV1 {
        try CanonicalContractCodingV1.validateFinite(recordedAt)
        return try executeStrictCommand(
            command: command,
            replayPlan: replayPlan,
            explicitRecordedAt: recordedAt,
            database: transactionDatabase,
            makeNew: makeNew
        )
    }

    private func executeStrictCommand(
        command: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1,
        explicitRecordedAt: Date?,
        database transactionDatabase: Database,
        makeNew: (Database) throws -> NewDomainCommandV1
    ) throws -> DomainCommandExecutionMetadataV1 {
        guard command.commandType == replayPlan.commandType,
              command.eventCount == replayPlan.shapes.count
        else {
            throw DomainCommandContractError.invalidEvent
        }
        try CanonicalContractCodingV1.validateLowercaseHash(
            command.commandPayloadHash
        )

        if let receipt = try DomainCommandReceiptRecordV1.fetchOne(
            transactionDatabase,
            key: command.envelope.idempotencyKey
        ) {
            let sealedCommand: PreparedDomainCommandV1
            switch command.commandType {
            case .engineExecutionBegin, .engineDispatchStart,
                 .engineCancellationRequest, .engineEventAccept,
                 .engineTerminalProposalRecord, .engineTerminalCommit:
                do {
                    sealedCommand = try command.resealed(
                        occurredAt: P1DTimestampV1.restorePersisted(
                            receipt.createdAt
                        )
                    )
                } catch {
                    throw DomainCommandGraphIntegrityError()
                }
            default:
                sealedCommand = command
            }
            guard receipt.idempotencyKey
                    == sealedCommand.envelope.idempotencyKey,
                  receipt.commandType == sealedCommand.commandType,
                  receipt.commandPayloadHash
                    == sealedCommand.commandPayloadHash,
                  receipt.eventCount == sealedCommand.eventCount
            else {
                throw DomainCommandReplayConflictError()
            }
            return try validateStoredGraph(
                receipt: receipt,
                command: sealedCommand,
                replayPlan: replayPlan,
                database: transactionDatabase,
                wasReplay: true
            )
        }

        try validateAvailableCamps(
            replayPlan: replayPlan,
            database: transactionDatabase
        )
        try preflightAggregateVersions(
            replayPlan: replayPlan,
            database: transactionDatabase
        )

        let newCommand = try makeNew(transactionDatabase)
        try validateNewCommand(
            newCommand,
            command: command,
            replayPlan: replayPlan
        )
        let resultBytes = try CanonicalContractCodingV1.encode(newCommand.result)
        let resultHash = CanonicalJSONV1.sha256Hex(resultBytes)
        let receipt = DomainCommandReceiptRecordV1(
            idempotencyKey: command.envelope.idempotencyKey,
            commandType: command.commandType,
            commandPayloadHash: command.commandPayloadHash,
            eventCount: command.eventCount,
            resultJson: String(decoding: resultBytes, as: UTF8.self),
            resultHash: resultHash,
            createdAt: command.envelope.occurredAt
        )
        try receipt.insert(transactionDatabase)

        var eventIds: [String] = []
        for (ordinal, shape) in replayPlan.shapes.enumerated() {
            let eventId = eventIdFactory()
            try CanonicalContractCodingV1.validateCanonicalUUID(eventId)
            eventIds.append(eventId)
            let recordedAt = explicitRecordedAt ?? clock()
            try CanonicalContractCodingV1.validateFinite(recordedAt)
            guard recordedAt >= command.envelope.occurredAt else {
                throw DomainCommandContractError.invalidTimestamp
            }
            let payload = newCommand.auditPayloads[ordinal]
            let payloadBytes = try CanonicalContractCodingV1.encode(payload)
            let payloadHash = CanonicalJSONV1.sha256Hex(payloadBytes)
            let event = DomainEventRecordV1(
                id: eventId,
                campId: shape.campId,
                aggregateType: shape.aggregateType,
                aggregateId: shape.aggregateId,
                aggregateVersion: try shape.aggregateVersion,
                eventType: shape.eventType,
                payloadVersion: 1,
                payloadJson: String(decoding: payloadBytes, as: UTF8.self),
                payloadHash: payloadHash,
                actorType: command.envelope.actorType,
                actorId: command.envelope.actorId,
                deviceId: command.envelope.deviceId,
                causationId: command.envelope.causationId,
                correlationId: command.envelope.correlationId,
                commandIdempotencyKey: command.envelope.idempotencyKey,
                eventOrdinal: ordinal,
                eventIdempotencyKey: eventKey(
                    commandKey: command.envelope.idempotencyKey,
                    ordinal: ordinal,
                    aggregateType: shape.aggregateType,
                    aggregateId: shape.aggregateId
                ),
                occurredAt: command.envelope.occurredAt,
                recordedAt: recordedAt
            )
            try insertDomainEventScope(
                eventId: eventId,
                campId: shape.campId,
                database: transactionDatabase
            )
            try event.insert(transactionDatabase)
            let outbox = EventOutboxRecordV1(
                eventId: eventId,
                state: .pending,
                attempt: 0,
                notBefore: nil,
                leaseOwner: nil,
                leaseExpiresAt: nil,
                lastError: nil,
                version: 1,
                createdAt: recordedAt,
                updatedAt: recordedAt,
                sentAt: nil
            )
            try outbox.insert(transactionDatabase)
        }

        return try validateStoredGraph(
            receipt: receipt,
            command: command,
            replayPlan: replayPlan,
            database: transactionDatabase,
            wasReplay: false,
            expectedEventIds: eventIds
        )
    }

    // P1-D-BEGIN GenericCommandExecutor
    private func validateP1DStoredGraph<Result: Codable>(
        receipt: Row,
        command: P1DPreparedCommandV1,
        database: Database
    ) throws -> Result {
        do {
            let storedKey: String = receipt["idempotencyKey"]
            let storedType: String = receipt["commandType"]
            let storedPayloadHash: String = receipt["commandPayloadHash"]
            let storedEventCount: Int = receipt["eventCount"]
            let resultJson: String = receipt["resultJson"]
            let resultHash: String = receipt["resultHash"]
            let createdAt = try P1DTimestampV1.restorePersisted(
                receipt["createdAt"] as Date
            )
            guard storedKey == command.envelope.idempotencyKey,
                  storedType == command.commandType,
                  storedPayloadHash == command.commandPayloadHash,
                  storedEventCount == command.events.count,
                  createdAt == command.envelope.occurredAt
            else {
                throw DomainCommandReplayConflictError()
            }
            try CanonicalContractCodingV1.validateLowercaseHash(resultHash)
            let resultBytes = Data(resultJson.utf8)
            guard CanonicalJSONV1.sha256Hex(resultBytes) == resultHash else {
                throw DomainCommandGraphIntegrityError()
            }
            let result = try CanonicalContractCodingV1.decode(
                Result.self,
                from: resultBytes
            )
            let rows = try Row.fetchAll(
                database,
                sql: """
                    SELECT * FROM domain_event
                    WHERE commandIdempotencyKey=? ORDER BY eventOrdinal
                    """,
                arguments: [command.envelope.idempotencyKey]
            )
            guard rows.count == command.events.count else {
                throw DomainCommandGraphIntegrityError()
            }
            for (ordinal, row) in rows.enumerated() {
                let shape = command.events[ordinal]
                let id: String = row["id"]
                let payloadJson: String = row["payloadJson"]
                let payloadHash: String = row["payloadHash"]
                let occurredAt = try P1DTimestampV1.restorePersisted(
                    row["occurredAt"] as Date
                )
                let recordedAt: Date = row["recordedAt"]
                try CanonicalContractCodingV1.validateFinite(recordedAt)
                let expectedPayload = try CanonicalContractCodingV1.encode(
                    shape.payload
                )
                guard let outbox = try EventOutboxRecordV1.fetchOne(
                    database,
                    key: id
                ) else {
                    throw DomainCommandGraphIntegrityError()
                }
                try CanonicalContractCodingV1.validateCanonicalUUID(id)
                try validateDomainEventScope(
                    eventId: id,
                    campId: shape.campId,
                    database: database
                )
                guard row["campId"] as String == shape.campId,
                      row["aggregateType"] as String == shape.aggregateType,
                      row["aggregateId"] as String == shape.aggregateId,
                      row["aggregateVersion"] as Int == shape.aggregateVersion,
                      row["eventType"] as String == shape.eventType,
                      row["payloadVersion"] as Int == 1,
                      Data(payloadJson.utf8) == expectedPayload,
                      payloadHash == CanonicalJSONV1.sha256Hex(expectedPayload),
                      row["actorType"] as String
                        == command.envelope.actorType.rawValue,
                      row["actorId"] as String == command.envelope.actorId,
                      row["deviceId"] as String? == command.envelope.deviceId,
                      row["causationId"] as String?
                        == command.envelope.causationId,
                      row["correlationId"] as String
                        == command.envelope.correlationId,
                      row["eventOrdinal"] as Int == ordinal,
                      row["eventIdempotencyKey"] as String == p1dEventKey(
                          commandKey: command.envelope.idempotencyKey,
                          ordinal: ordinal,
                          aggregateType: shape.aggregateType,
                          aggregateId: shape.aggregateId
                      ),
                      occurredAt == command.envelope.occurredAt,
                      recordedAt >= command.envelope.occurredAt
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                try validateP1DOutboxRow(
                    outbox,
                    eventId: id,
                    recordedAt: recordedAt
                )
            }
            return result
        } catch is DomainCommandReplayConflictError {
            throw DomainCommandReplayConflictError()
        } catch is DomainCommandGraphIntegrityError {
            throw DomainCommandGraphIntegrityError()
        } catch {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateP1DOutboxRow(
        _ outbox: EventOutboxRecordV1,
        eventId: String,
        recordedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateFinite(outbox.createdAt)
        try CanonicalContractCodingV1.validateFinite(outbox.updatedAt)
        for timestamp in [
            outbox.notBefore,
            outbox.leaseExpiresAt,
            outbox.sentAt,
        ].compactMap({ $0 }) {
            try CanonicalContractCodingV1.validateFinite(timestamp)
        }
        guard outbox.eventId == eventId,
              outbox.attempt >= 0,
              outbox.version > 0,
              outbox.createdAt == recordedAt,
              outbox.updatedAt >= outbox.createdAt
        else {
            throw DomainCommandGraphIntegrityError()
        }
        let dispatching = outbox.state == .dispatching
        guard dispatching == (outbox.leaseOwner != nil),
              dispatching == (outbox.leaseExpiresAt != nil),
              (outbox.state == .sent) == (outbox.sentAt != nil)
        else {
            throw DomainCommandGraphIntegrityError()
        }
    }

    package func executePlannedP1DCommand<Result: Codable>(
        command: P1DPreparedCommandV1,
        database transactionDatabase: Database,
        prepare: (Database, [String]) throws -> Result,
        apply: (Database, [String], Result) throws -> Void,
        validateProjection: (Database, [String], Result) throws -> Void
    ) throws -> Result {
        try P1DTimestampV1.validateCanonical(
            command.envelope.occurredAt
        )
        try CanonicalContractCodingV1.validateLowercaseHash(
            command.commandPayloadHash
        )
        if let receipt = try Row.fetchOne(
            transactionDatabase,
            sql: """
                SELECT idempotencyKey,commandType,commandPayloadHash,eventCount,
                       resultJson,resultHash,createdAt
                FROM domain_command_receipt WHERE idempotencyKey=?
                """,
            arguments: [command.envelope.idempotencyKey]
        ) {
            return try validateP1DStoredGraph(
                receipt: receipt,
                command: command,
                database: transactionDatabase
            )
        }
        for campId in Set(command.events.map(\.campId)) {
            let archived = try Int.fetchOne(
                transactionDatabase,
                sql: "SELECT archived FROM camp WHERE id=?",
                arguments: [campId]
            )
            guard archived == 0 else {
                throw DomainCommandCampUnavailableError()
            }
        }

        let eventIDs = try command.events.map { _ -> String in
            let eventID = eventIdFactory()
            try CanonicalContractCodingV1.validateCanonicalUUID(eventID)
            return eventID
        }
        let result = try prepare(transactionDatabase, eventIDs)
        let resultBytes = try CanonicalContractCodingV1.encode(result)
        let resultHash = CanonicalJSONV1.sha256Hex(resultBytes)
        let recordedTimes = try command.events.map { _ -> Date in
            let recordedAt = clock()
            try CanonicalContractCodingV1.validateFinite(recordedAt)
            guard recordedAt >= command.envelope.occurredAt else {
                throw DomainCommandContractError.invalidTimestamp
            }
            return recordedAt
        }
        try transactionDatabase.execute(
            sql: """
                INSERT INTO domain_command_receipt(
                  idempotencyKey,commandType,commandPayloadHash,eventCount,
                  resultJson,resultHash,createdAt
                ) VALUES (?,?,?,?,?,?,?)
                """,
            arguments: [
                command.envelope.idempotencyKey, command.commandType,
                command.commandPayloadHash, command.events.count,
                String(decoding: resultBytes, as: UTF8.self), resultHash,
                command.envelope.occurredAt.timeIntervalSince1970,
            ]
        )
        for (ordinal, shape) in command.events.enumerated() {
            let payloadBytes = try CanonicalContractCodingV1.encode(
                shape.payload
            )
            let payloadHash = CanonicalJSONV1.sha256Hex(payloadBytes)
            try insertDomainEventScope(
                eventId: eventIDs[ordinal],
                campId: shape.campId,
                database: transactionDatabase
            )
            try transactionDatabase.execute(
                sql: """
                    INSERT INTO domain_event(
                      id,campId,aggregateType,aggregateId,aggregateVersion,
                      eventType,payloadVersion,payloadJson,payloadHash,
                      actorType,actorId,deviceId,causationId,correlationId,
                      commandIdempotencyKey,eventOrdinal,eventIdempotencyKey,
                      occurredAt,recordedAt
                    ) VALUES (?,?,?,?,?,?,1,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                arguments: [
                    eventIDs[ordinal], shape.campId, shape.aggregateType,
                    shape.aggregateId, shape.aggregateVersion,
                    shape.eventType,
                    String(decoding: payloadBytes, as: UTF8.self),
                    payloadHash, command.envelope.actorType.rawValue,
                    command.envelope.actorId, command.envelope.deviceId,
                    command.envelope.causationId,
                    command.envelope.correlationId,
                    command.envelope.idempotencyKey, ordinal,
                    p1dEventKey(
                        commandKey: command.envelope.idempotencyKey,
                        ordinal: ordinal,
                        aggregateType: shape.aggregateType,
                        aggregateId: shape.aggregateId
                    ),
                    command.envelope.occurredAt.timeIntervalSince1970,
                    recordedTimes[ordinal].timeIntervalSince1970,
                ]
            )
            try transactionDatabase.execute(
                sql: """
                    INSERT INTO event_outbox(
                      eventId,state,attempt,notBefore,leaseOwner,leaseExpiresAt,
                      lastError,version,createdAt,updatedAt,sentAt
                    ) VALUES (?,'pending',0,NULL,NULL,NULL,NULL,1,?,?,NULL)
                    """,
                arguments: [
                    eventIDs[ordinal],
                    recordedTimes[ordinal].timeIntervalSince1970,
                    recordedTimes[ordinal].timeIntervalSince1970,
                ]
            )
        }
        try apply(transactionDatabase, eventIDs, result)
        guard let receipt = try Row.fetchOne(
            transactionDatabase,
            sql: """
                SELECT idempotencyKey,commandType,commandPayloadHash,eventCount,
                       resultJson,resultHash,createdAt
                FROM domain_command_receipt WHERE idempotencyKey=?
                """,
            arguments: [command.envelope.idempotencyKey]
        ) else {
            throw DomainCommandGraphIntegrityError()
        }
        let committed: Result = try validateP1DStoredGraph(
            receipt: receipt,
            command: command,
            database: transactionDatabase
        )
        try validateProjection(transactionDatabase, eventIDs, committed)
        return committed
    }
    // P1-D-END GenericCommandExecutor

    package func events(
        aggregateType: P1AggregateTypeV1,
        id: String
    ) throws -> [DomainEventRecordV1] {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            let rows = try DomainEventRecordV1
                .filter(Column("aggregateType") == aggregateType.rawValue)
                .filter(Column("aggregateId") == id)
                .order(Column("aggregateVersion"))
                .fetchAll(db)
            do {
                var expectedVersion = 1
                for row in rows {
                    guard row.aggregateType == aggregateType,
                          row.aggregateId == id,
                          row.aggregateVersion == expectedVersion
                    else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    try validateEventRow(row)
                    expectedVersion = try CanonicalContractCodingV1
                        .checkedIncrement(expectedVersion)
                }
                return rows
            } catch {
                throw DomainCommandGraphIntegrityError()
            }
        }
    }

    package func claimOutbox(
        workerId: String,
        now: Date,
        leaseDuration: TimeInterval,
        limit: Int
    ) throws -> [DomainOutboxClaimV1] {
        try CanonicalContractCodingV1.validateNonempty(workerId)
        try CanonicalContractCodingV1.validateFinite(now)
        try CanonicalContractCodingV1.validateFiniteInterval(leaseDuration)
        guard leaseDuration > 0, limit > 0 else {
            throw P1ContractValidationError.invalidValue
        }
        let leaseExpiresAt = now.addingTimeInterval(leaseDuration)
        try CanonicalContractCodingV1.validateFinite(leaseExpiresAt)
        return try database.pool.write { db in
            let candidates = try EventOutboxRecordV1
                .filter(Column("state") == EventOutboxStateV1.pending.rawValue)
                .filter(Column("notBefore") == nil || Column("notBefore") <= now)
                .order(Column("createdAt"), Column("eventId"))
                .limit(limit)
                .fetchAll(db)
            var claims: [DomainOutboxClaimV1] = []
            claims.reserveCapacity(candidates.count)
            for candidate in candidates {
                let attempt = try CanonicalContractCodingV1.checkedIncrement(
                    candidate.attempt
                )
                let version = try CanonicalContractCodingV1.checkedIncrement(
                    candidate.version
                )
                try db.execute(
                    sql: """
                        UPDATE event_outbox
                        SET state='dispatching', attempt=?, notBefore=NULL,
                            leaseOwner=?, leaseExpiresAt=?, lastError=NULL,
                            version=?, updatedAt=?, sentAt=NULL
                        WHERE eventId=? AND state='pending' AND version=?
                        """,
                    arguments: [
                        attempt, workerId, leaseExpiresAt, version, now,
                        candidate.eventId, candidate.version,
                    ]
                )
                guard db.changesCount == 1,
                      let updated = try EventOutboxRecordV1.fetchOne(
                          db, key: candidate.eventId
                      )
                else {
                    throw DomainOutboxCASConflictError()
                }
                claims.append(DomainOutboxClaimV1(
                    record: updated,
                    workerId: workerId,
                    claimedVersion: updated.version
                ))
            }
            return claims
        }
    }

    package func releaseOutbox(
        claim: DomainOutboxClaimV1,
        failure: DomainOutboxFailureV1,
        notBefore: Date,
        now: Date
    ) throws -> EventOutboxRecordV1 {
        try validateClaim(claim)
        try CanonicalContractCodingV1.validateCode(failure.code)
        try CanonicalContractCodingV1.validateNonempty(failure.message)
        try CanonicalContractCodingV1.validateFinite(notBefore)
        try CanonicalContractCodingV1.validateFinite(now)
        guard notBefore >= now else {
            throw P1ContractValidationError.invalidTime
        }
        let error = "\(failure.code): \(failure.message)"
        guard error.utf8.count <= 1_000 else {
            throw P1ContractValidationError.invalidValue
        }
        return try database.pool.write { db in
            guard let current = try EventOutboxRecordV1.fetchOne(
                db, key: claim.record.eventId
            ) else {
                throw DomainOutboxCASConflictError()
            }
            let terminal = failure.deterministic || claim.record.attempt >= 4
            let replayVersion = try CanonicalContractCodingV1.checkedIncrement(
                claim.claimedVersion
            )
            if current.version == replayVersion,
               current.attempt == claim.record.attempt,
               current.state == (terminal ? .failed : .pending),
               current.notBefore == (terminal ? nil : notBefore),
               current.leaseOwner == nil,
               current.leaseExpiresAt == nil,
               current.lastError == error,
               current.updatedAt == now,
               current.sentAt == nil
            {
                return current
            }
            guard current.state == .dispatching,
                current.version == claim.claimedVersion,
                current.leaseOwner == claim.workerId
            else {
                throw DomainOutboxCASConflictError()
            }
            let isTerminal = failure.deterministic || current.attempt >= 4
            let version = try CanonicalContractCodingV1.checkedIncrement(
                current.version
            )
            try db.execute(
                sql: """
                    UPDATE event_outbox
                    SET state=?, notBefore=?, leaseOwner=NULL,
                        leaseExpiresAt=NULL, lastError=?, version=?,
                        updatedAt=?, sentAt=NULL
                    WHERE eventId=? AND state='dispatching'
                      AND version=? AND leaseOwner=?
                    """,
                arguments: [
                    isTerminal ? EventOutboxStateV1.failed.rawValue
                        : EventOutboxStateV1.pending.rawValue,
                    isTerminal ? nil : notBefore,
                    error, version, now, current.eventId,
                    current.version, claim.workerId,
                ]
            )
            guard db.changesCount == 1,
                  let updated = try EventOutboxRecordV1.fetchOne(
                      db, key: current.eventId
                  )
            else {
                throw DomainOutboxCASConflictError()
            }
            return updated
        }
    }

    package func markOutboxSent(
        claim: DomainOutboxClaimV1,
        now: Date
    ) throws -> EventOutboxRecordV1 {
        try validateClaim(claim)
        try CanonicalContractCodingV1.validateFinite(now)
        return try database.pool.write { db in
            guard let current = try EventOutboxRecordV1.fetchOne(
                db, key: claim.record.eventId
            ) else {
                throw DomainOutboxCASConflictError()
            }
            if current.state == .sent {
                guard claim.workerId == claim.record.leaseOwner else {
                    throw DomainOutboxCASConflictError()
                }
                return current
            }
            guard current.state == .dispatching,
                  current.version == claim.claimedVersion,
                  current.leaseOwner == claim.workerId
            else {
                throw DomainOutboxCASConflictError()
            }
            let version = try CanonicalContractCodingV1.checkedIncrement(
                current.version
            )
            try db.execute(
                sql: """
                    UPDATE event_outbox
                    SET state='sent', notBefore=NULL, leaseOwner=NULL,
                        leaseExpiresAt=NULL, lastError=NULL, version=?,
                        updatedAt=?, sentAt=?
                    WHERE eventId=? AND state='dispatching'
                      AND version=? AND leaseOwner=?
                    """,
                arguments: [
                    version, now, now, current.eventId,
                    current.version, claim.workerId,
                ]
            )
            guard db.changesCount == 1,
                  let updated = try EventOutboxRecordV1.fetchOne(
                      db, key: current.eventId
                  )
            else {
                throw DomainOutboxCASConflictError()
            }
            return updated
        }
    }

    package func applyInbox(
        envelope: DomainInboxEnvelopeV1,
        handler: (Database) throws -> Void
    ) throws -> InboxMessageRecordV1 {
        try CanonicalJSONV1.validateCanonical(rawUTF8: envelope.payloadBytes)
        guard CanonicalJSONV1.sha256Hex(envelope.payloadBytes)
                == envelope.payloadHash
        else {
            throw DomainInboxIntegrityError()
        }
        let outcome = try database.pool.write { db -> InboxApplyOutcome in
            if let existing = try InboxMessageRecordV1
                .filter(Column("idempotencyKey") == envelope.idempotencyKey)
                .fetchOne(db)
            {
                if existing.redactedAt != nil {
                    try validateRedactedInbox(existing)
                    throw DomainInboxRedactedError()
                }
                try validateLiveInbox(existing)
                if existing.state == .rejected,
                   existing.errorCode == "inbox_payload_conflict",
                   existing.appliedAt == nil
                {
                    return .conflict
                }
                if inboxMatches(existing, envelope: envelope) {
                    return .row(existing)
                }
                _ = try CanonicalContractCodingV1.checkedIncrement(
                    existing.version
                )
                try db.execute(
                    sql: """
                        UPDATE inbox_message
                        SET state='rejected', appliedAt=NULL,
                            errorCode='inbox_payload_conflict',
                            version=version + 1
                        WHERE id=? AND version=? AND redactedAt IS NULL
                        """,
                    arguments: [existing.id, existing.version]
                )
                guard db.changesCount == 1 else {
                    throw DomainInboxIntegrityError()
                }
                return .conflict
            }

            var row = InboxMessageRecordV1.received(envelope: envelope)
            try row.insert(db)
            var rejectionCode: String?
            try db.inSavepoint {
                do {
                    try handler(db)
                    return .commit
                } catch let rejection as DomainInboxHandlerRejection {
                    rejectionCode = rejection.code
                    return .rollback
                }
            }
            let nextVersion = try CanonicalContractCodingV1.checkedIncrement(
                row.version
            )
            if let rejectionCode {
                try CanonicalContractCodingV1.validateCode(rejectionCode)
                row.state = .rejected
                row.appliedAt = nil
                row.errorCode = rejectionCode
            } else {
                row.state = .applied
                row.appliedAt = envelope.receivedAt
                row.errorCode = nil
            }
            row.version = nextVersion
            try db.execute(
                sql: """
                    UPDATE inbox_message
                    SET state=?, appliedAt=?, errorCode=?, version=?
                    WHERE id=? AND version=1 AND redactedAt IS NULL
                    """,
                arguments: [
                    row.state.rawValue, row.appliedAt, row.errorCode,
                    row.version, row.id,
                ]
            )
            guard db.changesCount == 1 else {
                throw DomainInboxIntegrityError()
            }
            return .row(row)
        }
        switch outcome {
        case let .row(row): return row
        case .conflict: throw DomainInboxReplayConflictError()
        }
    }

    private func validateNewCommand(
        _ newCommand: NewDomainCommandV1,
        command: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1
    ) throws {
        guard newCommand.auditPayloads.count == replayPlan.shapes.count,
              newCommand.result.hashes.first(where: {
                  $0.kind == .commandPayload
              })?.hash == command.commandPayloadHash,
              newCommand.result.times.first(where: {
                  $0.kind == .occurredAt
              })?.value == command.envelope.occurredAt
        else {
            throw DomainCommandContractError.invalidResult
        }
        let rebuilt = try NewDomainCommandV1.make(
            result: newCommand.result,
            replayPlan: replayPlan
        )
        guard rebuilt == newCommand else {
            throw DomainCommandContractError.invalidResult
        }
    }

    private func validateAvailableCamps(
        replayPlan: DomainCommandReplayPlanV1,
        database: Database
    ) throws {
        for campId in Set(replayPlan.shapes.map(\.campId)) {
            let archived = try Int.fetchOne(
                database,
                sql: "SELECT archived FROM camp WHERE id=?",
                arguments: [campId]
            )
            guard archived == 0 else {
                throw DomainCommandCampUnavailableError()
            }
        }
    }

    private func preflightAggregateVersions(
        replayPlan: DomainCommandReplayPlanV1,
        database: Database
    ) throws {
        var checked = Set<String>()
        for shape in replayPlan.shapes {
            let key = "\(shape.aggregateType.rawValue):\(shape.aggregateId)"
            guard checked.insert(key).inserted else { continue }
            let current = try Int.fetchOne(
                database,
                sql: """
                    SELECT MAX(aggregateVersion) FROM domain_event
                    WHERE aggregateType=? AND aggregateId=?
                    """,
                arguments: [shape.aggregateType.rawValue, shape.aggregateId]
            ) ?? 0
            guard current == shape.expectedAggregateVersion else {
                throw DomainCommandAggregateVersionError()
            }
        }
    }

    private func validateStoredGraph(
        receipt: DomainCommandReceiptRecordV1,
        command: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1,
        database: Database,
        wasReplay: Bool,
        expectedEventIds: [String]? = nil
    ) throws -> DomainCommandExecutionMetadataV1 {
        do {
            let receiptCreatedAt = try P1DTimestampV1.restorePersisted(
                receipt.createdAt
            )
            guard receipt.idempotencyKey
                    == command.envelope.idempotencyKey,
                  receipt.commandType == command.commandType,
                  receipt.commandPayloadHash == command.commandPayloadHash,
                  receipt.eventCount == command.eventCount,
                  receiptCreatedAt == command.envelope.occurredAt
            else {
                throw DomainCommandGraphIntegrityError()
            }
            try CanonicalContractCodingV1.validateLowercaseHash(
                receipt.commandPayloadHash
            )
            try CanonicalContractCodingV1.validateLowercaseHash(
                receipt.resultHash
            )
            let resultBytes = Data(receipt.resultJson.utf8)
            guard CanonicalJSONV1.sha256Hex(resultBytes) == receipt.resultHash else {
                throw DomainCommandGraphIntegrityError()
            }
            let result = try CanonicalContractCodingV1.decode(
                CampSafeCommandResultV1.self,
                from: resultBytes
            )
            let rebuilt = try NewDomainCommandV1.make(
                result: result,
                replayPlan: replayPlan
            )
            try validateNewCommand(
                rebuilt,
                command: command,
                replayPlan: replayPlan
            )
            let events = try DomainEventRecordV1
                .filter(Column("commandIdempotencyKey")
                    == command.envelope.idempotencyKey)
                .order(Column("eventOrdinal"))
                .fetchAll(database)
            guard events.count == replayPlan.shapes.count else {
                throw DomainCommandGraphIntegrityError()
            }
            let eventIds = events.map(\.id)
            if let expectedEventIds, expectedEventIds != eventIds {
                throw DomainCommandGraphIntegrityError()
            }
            for (ordinal, event) in events.enumerated() {
                let shape = replayPlan.shapes[ordinal]
                let expectedPayload = rebuilt.auditPayloads[ordinal]
                let aggregateVersion = try shape.aggregateVersion
                let eventOccurredAt = try P1DTimestampV1.restorePersisted(
                    event.occurredAt
                )
                try validateEventRow(event)
                try validateDomainEventScope(
                    eventId: event.id,
                    campId: event.campId,
                    database: database
                )
                let expectedPayloadBytes = try CanonicalContractCodingV1.encode(
                    expectedPayload
                )
                guard event.campId == shape.campId,
                      event.aggregateType == shape.aggregateType,
                      event.aggregateId == shape.aggregateId,
                      event.aggregateVersion == aggregateVersion,
                      event.eventType == shape.eventType,
                      event.payloadVersion == 1,
                      Data(event.payloadJson.utf8) == expectedPayloadBytes,
                      event.payloadHash
                        == CanonicalJSONV1.sha256Hex(expectedPayloadBytes),
                      event.actorType == command.envelope.actorType,
                      event.actorId == command.envelope.actorId,
                      event.deviceId == command.envelope.deviceId,
                      event.causationId == command.envelope.causationId,
                      event.correlationId == command.envelope.correlationId,
                      event.commandIdempotencyKey
                        == command.envelope.idempotencyKey,
                      event.eventOrdinal == ordinal,
                      event.eventIdempotencyKey == eventKey(
                          commandKey: command.envelope.idempotencyKey,
                          ordinal: ordinal,
                          aggregateType: shape.aggregateType,
                          aggregateId: shape.aggregateId
                      ),
                      eventOccurredAt == command.envelope.occurredAt,
                      let outbox = try EventOutboxRecordV1.fetchOne(
                          database, key: event.id
                      )
                else {
                    throw DomainCommandGraphIntegrityError()
                }
                try validateOutboxRow(outbox, event: event)
            }
            let outboxCount = try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*)
                    FROM event_outbox o
                    JOIN domain_event e ON e.id=o.eventId
                    WHERE e.commandIdempotencyKey=?
                    """,
                arguments: [command.envelope.idempotencyKey]
            )
            guard outboxCount == replayPlan.shapes.count else {
                throw DomainCommandGraphIntegrityError()
            }
            return try DomainCommandExecutionMetadataV1(
                result: result,
                resultHash: receipt.resultHash,
                eventIds: eventIds,
                wasReplay: wasReplay
            )
        } catch is DomainCommandReplayConflictError {
            throw DomainCommandReplayConflictError()
        } catch {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateEventRow(_ event: DomainEventRecordV1) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(event.id)
        try CanonicalContractCodingV1.validateCampID(event.campId)
        try CanonicalContractCodingV1.validateCanonicalUUID(event.aggregateId)
        try CanonicalContractCodingV1.validatePositive(event.aggregateVersion)
        guard event.payloadVersion == 1, event.eventOrdinal >= 0 else {
            throw DomainCommandGraphIntegrityError()
        }
        let payloadBytes = Data(event.payloadJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: payloadBytes)
        try CanonicalContractCodingV1.validateLowercaseHash(event.payloadHash)
        guard CanonicalJSONV1.sha256Hex(payloadBytes) == event.payloadHash else {
            throw DomainCommandGraphIntegrityError()
        }
        _ = try CanonicalContractCodingV1.decode(
            CampSafeAuditPayloadV1.self,
            from: payloadBytes
        )
        let occurredAt = try P1DTimestampV1.restorePersisted(event.occurredAt)
        let recordedAt = try P1DTimestampV1.restorePersisted(
            event.recordedAt
        )
        guard recordedAt >= occurredAt,
              event.eventIdempotencyKey == eventKey(
                  commandKey: event.commandIdempotencyKey,
                  ordinal: event.eventOrdinal,
                  aggregateType: event.aggregateType,
                  aggregateId: event.aggregateId
              )
        else {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func insertDomainEventScope(
        eventId: String,
        campId: String,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO camp_event_scope(
                  sourceTable,eventId,scopeKind,campId,payloadRedactedAt
                ) VALUES ('domain_event',?,'camp',?,NULL)
                """,
            arguments: [eventId, campId]
        )
    }

    private func validateDomainEventScope(
        eventId: String,
        campId: String,
        database: Database
    ) throws {
        let total = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM camp_event_scope
                WHERE sourceTable='domain_event' AND eventId=?
                """,
            arguments: [eventId]
        )
        let exact = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM camp_event_scope
                WHERE sourceTable='domain_event' AND eventId=?
                  AND scopeKind='camp' AND campId=?
                  AND payloadRedactedAt IS NULL
                """,
            arguments: [eventId, campId]
        )
        guard total == 1, exact == 1 else {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateOutboxRow(
        _ outbox: EventOutboxRecordV1,
        event: DomainEventRecordV1
    ) throws {
        let outboxCreatedAt = outbox.createdAt
        let outboxUpdatedAt = outbox.updatedAt
        let eventRecordedAt = event.recordedAt
        try CanonicalContractCodingV1.validateFinite(outboxCreatedAt)
        try CanonicalContractCodingV1.validateFinite(outboxUpdatedAt)
        try CanonicalContractCodingV1.validateFinite(eventRecordedAt)
        guard outbox.eventId == event.id,
              outbox.attempt >= 0,
              outbox.version > 0,
              outboxCreatedAt == eventRecordedAt,
              outboxUpdatedAt >= outboxCreatedAt
        else {
            throw DomainCommandGraphIntegrityError()
        }
        for timestamp in [
            outbox.notBefore,
            outbox.leaseExpiresAt,
            outbox.sentAt,
        ].compactMap({ $0 }) {
            try CanonicalContractCodingV1.validateFinite(timestamp)
        }
        let dispatching = outbox.state == .dispatching
        guard dispatching == (outbox.leaseOwner != nil),
              dispatching == (outbox.leaseExpiresAt != nil),
              (outbox.state == .sent) == (outbox.sentAt != nil)
        else {
            throw DomainCommandGraphIntegrityError()
        }
    }

    private func validateClaim(_ claim: DomainOutboxClaimV1) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(
            claim.record.eventId
        )
        try CanonicalContractCodingV1.validateNonempty(claim.workerId)
        guard claim.record.state == .dispatching,
              claim.record.leaseOwner == claim.workerId,
              claim.record.version == claim.claimedVersion,
              claim.record.leaseExpiresAt != nil
        else {
            throw DomainOutboxCASConflictError()
        }
    }

    private func validateLiveInbox(_ row: InboxMessageRecordV1) throws {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(row.id)
            if let campId = row.campId {
                try CanonicalContractCodingV1.validateCampID(campId)
            }
            try CanonicalContractCodingV1.validateCanonicalUUID(
                row.sourceDeviceId
            )
            try CanonicalContractCodingV1.validateNonempty(row.idempotencyKey)
            try CanonicalContractCodingV1.validatePositive(row.version)
            try CanonicalContractCodingV1.validateFinite(row.receivedAt)
            if let appliedAt = row.appliedAt {
                try CanonicalContractCodingV1.validateFinite(appliedAt)
            }
            let bytes = Data(row.payloadJson.utf8)
            try CanonicalJSONV1.validateCanonical(rawUTF8: bytes)
            try CanonicalContractCodingV1.validateLowercaseHash(row.payloadHash)
            guard CanonicalJSONV1.sha256Hex(bytes) == row.payloadHash else {
                throw DomainInboxIntegrityError()
            }
            switch row.state {
            case .received:
                guard row.appliedAt == nil, row.errorCode == nil else {
                    throw DomainInboxIntegrityError()
                }
            case .applied:
                guard row.appliedAt != nil, row.errorCode == nil else {
                    throw DomainInboxIntegrityError()
                }
            case .rejected:
                guard row.errorCode != nil else {
                    throw DomainInboxIntegrityError()
                }
            }
        } catch {
            throw DomainInboxIntegrityError()
        }
    }

    private func validateRedactedInbox(_ row: InboxMessageRecordV1) throws {
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(row.id)
            guard let campId = row.campId else {
                throw DomainInboxIntegrityError()
            }
            try CanonicalContractCodingV1.validateCampID(campId)
            try CanonicalContractCodingV1.validateNonempty(row.idempotencyKey)
            try CanonicalContractCodingV1.validateLowercaseHash(row.payloadHash)
            try CanonicalContractCodingV1.validatePositive(row.version)
            try CanonicalContractCodingV1.validateFinite(row.receivedAt)
            if let appliedAt = row.appliedAt {
                try CanonicalContractCodingV1.validateFinite(appliedAt)
            }
            guard let redactedAt = row.redactedAt else {
                throw DomainInboxIntegrityError()
            }
            try CanonicalContractCodingV1.validateFinite(redactedAt)
            guard row.sourceDeviceId == "[deleted]",
                  row.payloadJson == "{}",
                  row.state == .rejected,
                  row.errorCode == "camp_deleted"
            else {
                throw DomainInboxIntegrityError()
            }
        } catch is DomainInboxIntegrityError {
            throw DomainInboxIntegrityError()
        } catch {
            throw DomainInboxIntegrityError()
        }
    }

    private func inboxMatches(
        _ row: InboxMessageRecordV1,
        envelope: DomainInboxEnvelopeV1
    ) -> Bool {
        row.id == envelope.id
            && row.campId == envelope.campId
            && row.sourceDeviceId == envelope.sourceDeviceId
            && row.idempotencyKey == envelope.idempotencyKey
            && Data(row.payloadJson.utf8) == envelope.payloadBytes
            && row.payloadHash == envelope.payloadHash
    }

    private func eventKey(
        commandKey: String,
        ordinal: Int,
        aggregateType: P1AggregateTypeV1,
        aggregateId: String
    ) -> String {
        let padded = String(format: "%04d", ordinal)
        return "\(commandKey)#\(padded):\(aggregateType.rawValue):\(aggregateId)"
    }

    private func p1dEventKey(
        commandKey: String,
        ordinal: Int,
        aggregateType: String,
        aggregateId: String
    ) -> String {
        let commandKeyHash = CanonicalJSONV1.sha256Hex(
            Data(commandKey.utf8)
        )
        return "p1d:event:v1:\(commandKeyHash):\(ordinal):\(aggregateType):\(aggregateId)"
    }
}

private enum InboxApplyOutcome {
    case row(InboxMessageRecordV1)
    case conflict
}
