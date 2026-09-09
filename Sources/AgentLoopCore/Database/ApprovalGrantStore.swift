import Foundation
import GRDB

package struct ApprovalGrantStore: Sendable {
    private let database: AppDatabase
    private let clock: @Sendable () -> Date
    private let eventStore: DomainEventStore
    private let policyRegistry: ApprovalGrantPolicyRegistryV1

    package init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = { Date() },
        policyRegistry: ApprovalGrantPolicyRegistryV1 = .empty
    ) {
        self.database = database
        self.clock = clock
        self.policyRegistry = policyRegistry
        eventStore = DomainEventStore(database: database, clock: clock)
    }

    package func createGrant(
        _ command: CreateApprovalGrantCommandV1
    ) throws -> ApprovalGrantSnapshotV1 {
        try authorizeGrantCreation(command)
        if command.adapterReplayClass == .nonReplayable {
            guard command.grantor.type == .user, command.maxUses == 1 else {
                throw ApprovalGrantAuthorizationError()
            }
        }
        let payload = CreateGrantPayload(command: command)
        return try database.pool.write { db in
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-grant.create.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try grantEvent(
                    campId: command.campId,
                    aggregateId: command.grantId,
                    aggregateVersion: 1,
                    eventType: "approval-grant.created.v1",
                    state: .active
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    try requireExactCardScope(
                        campId: command.campId,
                        cardId: command.cardId,
                        grantee: command.grantee,
                        database: transaction
                    )
                    guard try Int.fetchOne(
                        transaction,
                        sql: "SELECT COUNT(*) FROM approval_grant WHERE id=?",
                        arguments: [command.grantId]
                    ) == 0 else {
                        throw ApprovalGrantConflictError()
                    }
                    return ApprovalGrantSnapshotV1(
                        id: command.grantId,
                        version: 1,
                        scopeVersion: 1,
                        grantor: command.grantor,
                        grantee: command.grantee,
                        capability: command.capability,
                        campId: command.campId,
                        cardId: command.cardId,
                        toolId: command.toolId,
                        approvedInputHash: command.approvedInputHash,
                        purpose: command.purpose,
                        dataLevel: command.dataLevel,
                        adapterReplayClass: command.adapterReplayClass,
                        validFrom: command.validFrom,
                        validUntil: command.validUntil,
                        maxUses: command.maxUses,
                        usedCount: 0,
                        state: .active,
                        revokedAt: nil,
                        createdAt: command.envelope.occurredAt,
                        updatedAt: command.envelope.occurredAt
                    )
                },
                apply: { transaction, _, result in
                    try insertGrant(result, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    try validateGrantProjection(result, database: transaction)
                }
            )
        }
    }

    package func answerApprovalRequest(
        requestId: String,
        answerJson: String,
        deviceId: String
    ) throws -> ApprovalAnswerSnapshotV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(requestId)
        try CanonicalContractCodingV1.validateCanonicalUUID(deviceId)
        let answer = try parseApprovalAnswer(answerJson)
        let firstAnsweredAt = try P1DTimestampV1.canonical(clock())
        try CanonicalContractCodingV1.validateFinite(firstAnsweredAt)

        return try database.pool.write { db in
            guard let request = try UserRequestRecord.fetchOne(
                db,
                key: requestId
            ), request.kind == .approval,
                  let card = try CardRecord.fetchOne(db, key: request.cardId),
                  let row = try Row.fetchOne(
                      db,
                      sql: """
                          SELECT s.campId,c.assigneeId,c.missionId,cp.archived
                          FROM card c
                          JOIN mission m ON m.id=c.missionId
                          JOIN squad s ON s.id=m.squadId
                          JOIN camp cp ON cp.id=s.campId
                          WHERE c.id=?
                          """,
                      arguments: [request.cardId]
                  ), row["archived"] as Bool == false
            else {
                throw ApprovalAnswerContractError()
            }
            let options = try parseApprovalOptions(request.optionsJson)
            let answeredAt = try P1DTimestampV1.restorePersisted(
                request.answeredAt
            ) ?? firstAnsweredAt
            let campId: String = row["campId"]
            let missionId: String = row["missionId"]
            try CanonicalContractCodingV1.validateCampID(campId)
            let grantee: ApprovalGranteeV1
            let assigneeId: String? = row["assigneeId"]
            if let assigneeId {
                grantee = try ApprovalGranteeV1(
                    type: .cow,
                    id: assigneeId
                )
            } else {
                grantee = try ApprovalGranteeV1(
                    type: .system,
                    id: "system:card-runner:v1"
                )
            }
            let grant = answer.approved
                ? ApprovalGrantSnapshotV1(
                    id: requestId,
                    version: 1,
                    scopeVersion: 1,
                    grantor: try ApprovalGrantorV1.user(P1DActorID.localOwner),
                    grantee: grantee,
                    capability: "tool.execute:\(options.toolId)",
                    campId: campId,
                    cardId: card.id,
                    toolId: options.toolId,
                    approvedInputHash: options.inputHash,
                    purpose: "user_request:\(requestId)",
                    dataLevel: options.toolId.hasPrefix("mcp__")
                        ? .external : .workspace,
                    adapterReplayClass: .nonReplayable,
                    validFrom: answeredAt,
                    validUntil: answeredAt.addingTimeInterval(900),
                    maxUses: 1,
                    usedCount: 0,
                    state: .active,
                    revokedAt: nil,
                    createdAt: answeredAt,
                    updatedAt: answeredAt
                )
                : nil
            if let grant {
                try CanonicalContractCodingV1.validateFinite(grant.validUntil)
            }
            let payload = ApprovalAnswerPayload(
                requestId: requestId,
                cardId: card.id,
                campId: campId,
                answer: answer,
                options: options,
                answeredAt: answeredAt
            )
            let event: P1DCommandEventShapeV1
            if let grant {
                event = try grantEvent(
                    campId: campId,
                    aggregateId: grant.id,
                    aggregateVersion: 1,
                    eventType: "approval-grant.created.v1",
                    state: .active
                )
            } else {
                event = try P1DCommandEventShapeV1(
                    campId: campId,
                    aggregateType: "approvalRequest",
                    aggregateId: requestId,
                    aggregateVersion: 1,
                    eventType: "approval-grant.denied.v1",
                    payload: .object([
                        "requestId": .string(requestId),
                        "state": .string("denied"),
                    ])
                )
            }
            let envelope = try CommandEnvelopeV1(
                idempotencyKey: "approval-answer:v1:\(requestId)",
                actorType: .user,
                actorId: P1DActorID.localOwner,
                deviceId: deviceId,
                correlationId: "approval-answer:v1:\(requestId)",
                causationId: nil,
                occurredAt: answeredAt
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-answer.v1",
                envelope: envelope,
                payload: payload,
                events: [event]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    guard request.answerJson == nil,
                          request.answeredAt == nil,
                          request.lifecycleState == .open,
                          request.terminalReason == nil,
                          request.redactedAt == nil,
                          card.status == .blocked,
                          let blockedReasonJson = card.blockedReasonJson
                    else {
                        throw StaleUserRequestError(requestId: requestId)
                    }
                    let blockedReason = try JSONValue.decoded(
                        from: blockedReasonJson
                    )
                    guard blockedReason["userRequestId"]?.stringValue
                            == requestId,
                          try Int.fetchOne(
                              transaction,
                              sql: "SELECT COUNT(*) FROM approval_grant WHERE id=?",
                              arguments: [requestId]
                          ) == 0
                    else {
                        throw StaleUserRequestError(requestId: requestId)
                    }
                    try requireExactCardScope(
                        campId: campId,
                        cardId: card.id,
                        grantee: grantee,
                        database: transaction
                    )
                    return ApprovalAnswerSnapshotV1(
                        requestId: requestId,
                        approved: answer.approved,
                        answeredAt: answeredAt,
                        grant: grant
                    )
                },
                apply: { transaction, _, result in
                    var updatedRequest = request
                    updatedRequest.answerJson = answer.canonicalJSON
                    updatedRequest.answeredAt = result.answeredAt
                    updatedRequest.lifecycleState = .answered
                    try updatedRequest.update(transaction)

                    var updatedCard = card
                    updatedCard.status = .ready
                    updatedCard.blockedReasonJson = nil
                    try updatedCard.update(transaction)
                    if let committedGrant = result.grant {
                        try insertGrant(
                            committedGrant,
                            database: transaction
                        )
                    }
                    try AppDatabase.appendEvent(
                        transaction,
                        missionId: missionId,
                        cardId: card.id,
                        runId: nil,
                        kind: EventKind.userRequestAnswered,
                        payload: ["userRequestId": .string(requestId)]
                    )
                    try AppDatabase.appendEvent(
                        transaction,
                        missionId: missionId,
                        cardId: card.id,
                        runId: nil,
                        kind: EventKind.approvalDecided,
                        payload: [
                            "decision": .string(
                                answer.approved ? "approve" : "deny"
                            ),
                            "userRequestId": .string(requestId),
                        ]
                    )
                    try database.rollupMission(
                        transaction,
                        missionId: missionId
                    )
                    try AppDatabase.appendEvent(
                        transaction,
                        missionId: missionId,
                        cardId: card.id,
                        runId: nil,
                        kind: EventKind.cardReady,
                        payload: .object([:])
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateApprovalAnswerProjection(
                        result,
                        canonicalAnswerJSON: answer.canonicalJSON,
                        database: transaction
                    )
                }
            )
        }
    }

    package func reserveUse(
        _ command: ReserveApprovalGrantUseCommandV1
    ) throws -> ApprovalGrantUseSnapshotV1 {
        let payload = ReserveUsePayload(command: command)
        return try database.pool.write { db in
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-grant.reserve-use.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try useEvent(
                    campId: command.campId,
                    useId: command.useId,
                    aggregateVersion: 1,
                    eventType: "approval-grant.use-reserved.v1",
                    state: .reserved
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let grant = try requireGrant(
                        id: command.grantId,
                        version: command.expectedGrantVersion,
                        database: transaction
                    )
                    try validateReserve(
                        command,
                        grant: grant,
                        database: transaction
                    )
                    return ApprovalGrantUseSnapshotV1(
                        id: command.useId,
                        grantId: grant.id,
                        idempotencyKey: command.envelope.idempotencyKey,
                        toolId: command.toolId,
                        inputHash: command.inputHash,
                        adapterId: command.adapter.adapterId,
                        adapterReplayClass: command.adapter.replayClass,
                        state: .reserved,
                        adapterOperationId: nil,
                        version: 1,
                        reservedAt: command.envelope.occurredAt,
                        dispatchIntentAt: nil,
                        adapterAcceptedAt: nil,
                        finishedAt: nil
                    )
                },
                apply: { transaction, _, result in
                    try insertUse(result, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    try validateUseProjection(result, database: transaction)
                }
            )
        }
    }

    package func releaseReservedUse(
        _ command: ApprovalGrantUseTransitionCommandV1
    ) throws -> ApprovalGrantUseSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        return try transitionUseWithoutReceipt(
            command,
            commandType: "approval-grant.release-reserved.v1",
            eventType: "approval-grant.use-released.v1",
            expectedStates: [.reserved],
            target: .released,
            requireNoReceipt: true
        )
    }

    package func commitDispatchIntent(
        _ command: ApprovalGrantUseTransitionCommandV1
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        guard let expectedGrantVersion = command.expectedGrantVersion else {
            throw ApprovalGrantConflictError()
        }
        let payload = UseTransitionPayload(
            useId: command.useId,
            expectedUseVersion: command.expectedUseVersion,
            expectedGrantVersion: expectedGrantVersion,
            target: .dispatching
        )
        return try database.pool.write { db in
            let use = try requireUse(
                id: command.useId,
                database: db
            )
            let campId = try grantCamp(use.grantId, database: db)
            let eventVersion = try storedEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: command.expectedUseVersion + 1,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-grant.dispatch-intent.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try useEvent(
                    campId: campId,
                    useId: command.useId,
                    aggregateVersion: eventVersion,
                    eventType: "approval-grant.dispatch-intent.v1",
                    state: .dispatching
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let current = try requireUse(
                        id: command.useId,
                        version: command.expectedUseVersion,
                        states: [.reserved],
                        database: transaction
                    )
                    let grant = try requireGrant(
                        id: current.grantId,
                        version: expectedGrantVersion,
                        database: transaction
                    )
                    guard grant.state == .active,
                          grant.usedCount < grant.maxUses,
                          command.envelope.occurredAt >= grant.validFrom,
                          command.envelope.occurredAt < grant.validUntil
                    else {
                        throw ApprovalGrantTransitionError()
                    }
                    let nextCount = grant.usedCount + 1
                    let nextGrant = replacing(
                        grant,
                        version: grant.version + 1,
                        usedCount: nextCount,
                        state: nextCount == grant.maxUses
                            ? .exhausted : .active,
                        updatedAt: command.envelope.occurredAt
                    )
                    let nextUse = replacing(
                        current,
                        state: .dispatching,
                        version: current.version + 1,
                        dispatchIntentAt: command.envelope.occurredAt
                    )
                    let receipt = try makeReceipt(
                        use: nextUse,
                        ordinal: 0,
                        phase: .dispatchIntent,
                        result: .pending,
                        operationId: nil,
                        receiptRef: nil,
                        evidenceHash: CanonicalJSONV1.sha256Hex(
                            Data("dispatch-intent:\(current.id)".utf8)
                        ),
                        authority: .system,
                        authorityId: command.envelope.actorId,
                        at: command.envelope.occurredAt
                    )
                    return ApprovalGrantDispatchSnapshotV1(
                        grant: nextGrant,
                        use: nextUse,
                        receipt: receipt
                    )
                },
                apply: { transaction, _, result in
                    try updateGrant(
                        result.grant,
                        expectedVersion: expectedGrantVersion,
                        database: transaction
                    )
                    try updateUse(
                        result.use,
                        expectedVersion: command.expectedUseVersion,
                        database: transaction
                    )
                    if let receipt = result.receipt {
                        try insertReceipt(receipt, database: transaction)
                    }
                },
                validateProjection: { transaction, _, result in
                    try validateDispatchProjection(
                        result,
                        database: transaction
                    )
                }
            )
        }
    }

    package func grant(id: String) throws -> ApprovalGrantSnapshotV1? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try grant(id: id, database: db)
        }
    }

    package func use(id: String) throws -> ApprovalGrantUseSnapshotV1? {
        try CanonicalContractCodingV1.validateNonempty(id)
        return try database.pool.read { db in
            try use(id: id, database: db)
        }
    }

    package func receipts(
        useId: String
    ) throws -> [ExternalOperationReceiptSnapshotV1] {
        try CanonicalContractCodingV1.validateNonempty(useId)
        return try database.pool.read { db in
            let ids = try String.fetchAll(
                db,
                sql: """
                    SELECT id FROM external_operation_receipt
                    WHERE grantUseId=? ORDER BY ordinal
                    """,
                arguments: [useId]
            )
            return try ids.map { try requireReceipt(id: $0, database: db) }
        }
    }

    package func uses(
        grantId: String
    ) throws -> [ApprovalGrantUseSnapshotV1] {
        try CanonicalContractCodingV1.validateCanonicalUUID(grantId)
        return try database.pool.read { db in
            guard try grant(id: grantId, database: db) != nil else {
                throw ApprovalGrantConflictError()
            }
            let ids = try String.fetchAll(
                db,
                sql: """
                    SELECT id FROM approval_grant_use
                    WHERE grantId=? ORDER BY rowid
                    """,
                arguments: [grantId]
            )
            return try ids.map { try requireUse(id: $0, database: db) }
        }
    }

    package func nextUseIdentity(grantId: String) throws -> String {
        try CanonicalContractCodingV1.validateCanonicalUUID(grantId)
        return try database.pool.read { db in
            guard try grant(id: grantId, database: db) != nil else {
                throw ApprovalGrantConflictError()
            }
            return try expectedNextUseIdentity(
                grantId: grantId,
                database: db
            )
        }
    }

    package func matchGrant(
        cardId: String,
        toolId: String,
        inputHash: String,
        at: Date
    ) throws -> ApprovalGrantMatchV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateNonempty(toolId)
        try CanonicalContractCodingV1.validateLowercaseHash(inputHash)
        try CanonicalContractCodingV1.validateFinite(at)
        return try database.pool.read { db in
            let requests = try UserRequestRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM user_request
                    WHERE cardId=? AND kind='approval'
                      AND lifecycleState='answered'
                    ORDER BY createdAt,rowid
                    """,
                arguments: [cardId]
            )
            var match = ApprovalGrantMatchV1.absent
            for request in requests {
                let options = try parseApprovalOptions(request.optionsJson)
                guard let answerJSON = request.answerJson,
                      let rawAnsweredAt = request.answeredAt
                else {
                    throw ApprovalAnswerContractError()
                }
                let answeredAt = try P1DTimestampV1.restorePersisted(
                    rawAnsweredAt
                )
                let answer = try parseApprovalAnswer(answerJSON)
                let storedGrant = try grant(id: request.id, database: db)
                if answer.approved {
                    guard let storedGrant,
                          storedGrant.id == request.id,
                          storedGrant.cardId == request.cardId,
                          storedGrant.toolId == options.toolId,
                          storedGrant.approvedInputHash == options.inputHash,
                          storedGrant.capability
                            == "tool.execute:\(options.toolId)",
                          storedGrant.purpose
                            == "user_request:\(request.id)",
                          storedGrant.grantor.type == .user,
                          storedGrant.grantor.id == P1DActorID.localOwner,
                          storedGrant.adapterReplayClass == .nonReplayable,
                          storedGrant.maxUses == 1,
                          storedGrant.validFrom == answeredAt,
                          storedGrant.validUntil
                            == answeredAt.addingTimeInterval(900)
                    else {
                        throw ApprovalGrantConflictError()
                    }
                    try requireExactCardScope(
                        campId: storedGrant.campId,
                        cardId: storedGrant.cardId,
                        grantee: storedGrant.grantee,
                        database: db
                    )
                } else if storedGrant != nil {
                    throw ApprovalGrantConflictError()
                }

                guard options.toolId == toolId,
                      options.inputHash == inputHash
                else { continue }
                if !answer.approved {
                    match = .denied(reason: answer.reason)
                    continue
                }
                guard let storedGrant else {
                    throw ApprovalGrantConflictError()
                }
                let useIDs = try String.fetchAll(
                    db,
                    sql: """
                        SELECT id FROM approval_grant_use
                        WHERE grantId=? ORDER BY rowid
                        """,
                    arguments: [storedGrant.id]
                )
                for useID in useIDs {
                    let use = try requireUse(id: useID, database: db)
                    guard use.grantId == storedGrant.id,
                          use.toolId == storedGrant.toolId,
                          use.inputHash == storedGrant.approvedInputHash,
                          use.adapterReplayClass
                            == storedGrant.adapterReplayClass
                    else {
                        throw ApprovalGrantConflictError()
                    }
                }
                if !useIDs.isEmpty {
                    match = .authorized(storedGrant)
                } else if storedGrant.state == .active,
                          storedGrant.usedCount == 0,
                          at >= storedGrant.validFrom,
                          at < storedGrant.validUntil
                {
                    match = .authorized(storedGrant)
                } else if storedGrant.state == .revoked
                    || storedGrant.state == .expired
                    || at >= storedGrant.validUntil
                {
                    match = .unavailable
                } else {
                    throw ApprovalGrantConflictError()
                }
            }
            return match
        }
    }
}

extension ApprovalGrantStore {
    private func validateApprovalAnswerProjection(
        _ result: ApprovalAnswerSnapshotV1,
        canonicalAnswerJSON: String,
        database: Database
    ) throws {
        guard let request = try UserRequestRecord.fetchOne(
            database,
            key: result.requestId
        ), request.answerJson == canonicalAnswerJSON,
           request.lifecycleState == .answered,
           request.terminalReason == nil,
           request.redactedAt == nil,
           try P1DTimestampV1.restorePersisted(request.answeredAt)
                == result.answeredAt,
           let card = try CardRecord.fetchOne(
               database,
               key: request.cardId
           ), card.status == .ready,
           card.blockedReasonJson == nil,
           result.approved == (result.grant != nil),
           try grant(
               id: result.requestId,
               database: database
           ) == result.grant
        else {
            throw ApprovalGrantConflictError()
        }
    }

    private func parseApprovalAnswer(
        _ raw: String
    ) throws -> ApprovalAnswerMaterial {
        let value = try JSONValue.decoded(from: raw)
        guard let object = value.objectValue,
              let decision = object["decision"]?.stringValue,
              decision == "approve" || decision == "deny"
        else {
            throw ApprovalAnswerContractError()
        }
        let reason = object["reason"]?.stringValue
        if decision == "approve" {
            guard Set(object.keys) == ["decision"] else {
                throw ApprovalAnswerContractError()
            }
        } else {
            guard Set(object.keys) == ["decision"]
                    || Set(object.keys) == ["decision", "reason"]
            else {
                throw ApprovalAnswerContractError()
            }
            if object.keys.contains("reason") {
                guard let reason, !reason.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty else {
                    throw ApprovalAnswerContractError()
                }
            }
        }
        return ApprovalAnswerMaterial(
            decision: decision,
            reason: reason,
            canonicalJSON: try value.encodedString()
        )
    }

    private func parseApprovalOptions(
        _ raw: String?
    ) throws -> ApprovalOptionsMaterial {
        guard let raw,
              let object = try JSONValue.decoded(from: raw).objectValue,
              Set(object.keys) == ["input", "inputHash", "tool"],
              let input = object["input"],
              let inputHash = object["inputHash"]?.stringValue,
              let toolId = object["tool"]?.stringValue,
              toolId == "write_file" || toolId == "run_shell"
                || toolId.hasPrefix("mcp__")
        else {
            throw ApprovalAnswerContractError()
        }
        try CanonicalContractCodingV1.validateLowercaseHash(inputHash)
        guard try ApprovalToken.hash(input: input) == inputHash else {
            throw ApprovalAnswerContractError()
        }
        return ApprovalOptionsMaterial(
            toolId: toolId,
            input: input,
            inputHash: inputHash
        )
    }

    private func authorizeGrantCreation(
        _ command: CreateApprovalGrantCommandV1
    ) throws {
        switch command.grantor.type {
        case .user:
            guard command.envelope.actorType == .user,
                  command.envelope.actorId == command.grantor.id,
                  command.grantor.policyId == nil,
                  command.grantor.policyVersion == nil,
                  command.grantor.policyHash == nil
            else { throw ApprovalGrantAuthorizationError() }
        case .policy:
            guard command.envelope.actorType == .system,
                  command.envelope.actorId == command.grantor.id,
                  policyRegistry.contains(command.grantor)
            else { throw ApprovalGrantAuthorizationError() }
        case .system:
            guard command.envelope.actorType == .system,
                  command.envelope.actorId == command.grantor.id,
                  command.grantor.policyId == nil,
                  command.grantor.policyVersion == nil,
                  command.grantor.policyHash == nil
            else { throw ApprovalGrantAuthorizationError() }
        }
    }

    private func authorizeCoordinator(
        _ envelope: CommandEnvelopeV1
    ) throws {
        guard envelope.actorType == .system,
              envelope.actorId == P1DActorID.externalOperation
        else {
            throw ApprovalGrantAuthorizationError()
        }
    }

    private func requireExactCardScope(
        campId: String,
        cardId: String,
        grantee: ApprovalGranteeV1,
        database: Database
    ) throws {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT s.campId,c.assigneeId,cp.archived
                FROM card c
                JOIN mission m ON m.id=c.missionId
                JOIN squad s ON s.id=m.squadId
                JOIN camp cp ON cp.id=s.campId
                WHERE c.id=?
                """,
            arguments: [cardId]
        ), row["campId"] as String == campId,
           row["archived"] as Bool == false
        else {
            throw ApprovalGrantScopeError()
        }
        let assignee: String? = row["assigneeId"]
        if let assignee {
            guard grantee.type == .cow, grantee.id == assignee else {
                throw ApprovalGrantScopeError()
            }
        } else {
            guard grantee.type == .system,
                  grantee.id == "system:card-runner:v1"
            else {
                throw ApprovalGrantScopeError()
            }
        }
    }

    private func validateReserve(
        _ command: ReserveApprovalGrantUseCommandV1,
        grant: ApprovalGrantSnapshotV1,
        database: Database
    ) throws {
        try authorizeCoordinator(command.envelope)
        try requireExactCardScope(
            campId: command.campId,
            cardId: command.cardId,
            grantee: grant.grantee,
            database: database
        )
        guard grant.state == .active,
              grant.campId == command.campId,
              grant.cardId == command.cardId,
              grant.capability == command.capability,
              grant.toolId == command.toolId,
              grant.approvedInputHash == command.inputHash,
              grant.adapterReplayClass == command.adapter.replayClass,
              command.adapter.toolId == command.toolId,
              command.envelope.occurredAt >= grant.validFrom,
              command.envelope.occurredAt < grant.validUntil,
              grant.usedCount < grant.maxUses
        else {
            throw ApprovalGrantScopeError()
        }
        guard command.useId == (try expectedNextUseIdentity(
            grantId: grant.id,
            database: database
        )) else {
            throw ApprovalGrantConflictError()
        }
        let reservedCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM approval_grant_use
                WHERE grantId=? AND state='reserved'
                """,
            arguments: [grant.id]
        ) ?? 0
        guard grant.usedCount + reservedCount < grant.maxUses else {
            throw ApprovalGrantConflictError()
        }
    }

    private func expectedNextUseIdentity(
        grantId: String,
        database: Database
    ) throws -> String {
        let priorCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM approval_grant_use WHERE grantId=?",
            arguments: [grantId]
        ) ?? 0
        let ordinal = try CanonicalContractCodingV1.checkedIncrement(priorCount)
        return "grant-use:v1:\(grantId):\(ordinal)"
    }

    private func insertGrant(
        _ grant: ApprovalGrantSnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO approval_grant(
                  id,version,scopeVersion,grantorActorType,grantorActorId,
                  grantorPolicyId,grantorPolicyVersion,grantorPolicyHash,
                  granteeType,granteeId,capability,campId,cardId,toolId,
                  approvedInputHash,purpose,dataLevel,adapterReplayClass,
                  validFrom,validUntil,maxUses,usedCount,status,revokedAt,
                  createdAt,updatedAt,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)
                """,
            arguments: [
                grant.id, grant.version, grant.scopeVersion,
                grant.grantor.type.rawValue, grant.grantor.id,
                grant.grantor.policyId, grant.grantor.policyVersion,
                grant.grantor.policyHash, grant.grantee.type.rawValue,
                grant.grantee.id, grant.capability, grant.campId,
                grant.cardId, grant.toolId, grant.approvedInputHash,
                grant.purpose, grant.dataLevel.rawValue,
                grant.adapterReplayClass.rawValue, grant.validFrom,
                grant.validUntil, grant.maxUses, grant.usedCount,
                grant.state.rawValue, grant.revokedAt, grant.createdAt,
                grant.updatedAt,
            ]
        )
    }

    private func insertUse(
        _ use: ApprovalGrantUseSnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO approval_grant_use(
                  id,grantId,idempotencyKey,toolId,inputHash,adapterId,
                  adapterReplayClass,state,adapterOperationId,version,
                  reservedAt,dispatchIntentAt,adapterAcceptedAt,finishedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                use.id, use.grantId, use.idempotencyKey, use.toolId,
                use.inputHash, use.adapterId,
                use.adapterReplayClass.rawValue, use.state.rawValue,
                use.adapterOperationId, use.version, use.reservedAt,
                use.dispatchIntentAt, use.adapterAcceptedAt, use.finishedAt,
            ]
        )
    }

    private func updateGrant(
        _ grant: ApprovalGrantSnapshotV1,
        expectedVersion: Int,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE approval_grant SET version=?,usedCount=?,status=?,
                  revokedAt=?,updatedAt=? WHERE id=? AND version=?
                """,
            arguments: [
                grant.version, grant.usedCount, grant.state.rawValue,
                grant.revokedAt, grant.updatedAt, grant.id, expectedVersion,
            ]
        )
        guard database.changesCount == 1 else {
            throw ApprovalGrantConflictError()
        }
    }

    private func updateUse(
        _ use: ApprovalGrantUseSnapshotV1,
        expectedVersion: Int,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE approval_grant_use SET state=?,adapterOperationId=?,
                  version=?,dispatchIntentAt=?,adapterAcceptedAt=?,finishedAt=?
                WHERE id=? AND version=?
                """,
            arguments: [
                use.state.rawValue, use.adapterOperationId, use.version,
                use.dispatchIntentAt, use.adapterAcceptedAt, use.finishedAt,
                use.id, expectedVersion,
            ]
        )
        guard database.changesCount == 1 else {
            throw ApprovalGrantConflictError()
        }
    }

    private func insertReceipt(
        _ receipt: ExternalOperationReceiptSnapshotV1,
        database: Database
    ) throws {
        let bytes = try CanonicalContractCodingV1.encode(receipt.receiptJSON)
        guard CanonicalJSONV1.sha256Hex(bytes) == receipt.receiptHash else {
            throw ExternalOperationAttestationError()
        }
        try database.execute(
            sql: """
                INSERT INTO external_operation_receipt(
                  id,grantUseId,receiptIdempotencyKey,ordinal,phase,result,
                  adapterOperationId,receiptRef,receiptJson,receiptHash,
                  authorityKind,authorityId,createdAt,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)
                """,
            arguments: [
                receipt.id, receipt.grantUseId,
                receipt.receiptIdempotencyKey, receipt.ordinal,
                receipt.phase.rawValue, receipt.result.rawValue,
                receipt.adapterOperationId, receipt.receiptRef,
                String(decoding: bytes, as: UTF8.self), receipt.receiptHash,
                receipt.authority.rawValue, receipt.authorityId,
                receipt.createdAt,
            ]
        )
    }

    private func makeReceipt(
        use: ApprovalGrantUseSnapshotV1,
        ordinal: Int,
        phase: ExternalOperationReceiptPhaseV1,
        result: ExternalOperationReceiptResultV1,
        operationId: String?,
        receiptRef: String?,
        evidenceHash: String,
        authority: ExternalOperationReceiptAuthorityV1,
        authorityId: String,
        at: Date
    ) throws -> ExternalOperationReceiptSnapshotV1 {
        try CanonicalContractCodingV1.validateLowercaseHash(evidenceHash)
        let json: JSONValue = .object([
            "evidenceHash": .string(evidenceHash),
            "phase": .string(phase.rawValue),
            "result": .string(result.rawValue),
            "useId": .string(use.id),
        ])
        let bytes = try CanonicalContractCodingV1.encode(json)
        return ExternalOperationReceiptSnapshotV1(
            id: UUID().uuidString,
            grantUseId: use.id,
            receiptIdempotencyKey:
                "external-receipt:v1:\(use.id):\(ordinal):\(phase.rawValue)",
            ordinal: ordinal,
            phase: phase,
            result: result,
            adapterOperationId: operationId,
            receiptRef: receiptRef,
            receiptJSON: json,
            receiptHash: CanonicalJSONV1.sha256Hex(bytes),
            authority: authority,
            authorityId: authorityId,
            createdAt: at
        )
    }

    private func nextReceiptOrdinal(
        useId: String,
        database: Database
    ) throws -> Int {
        let current = try Int.fetchOne(
            database,
            sql: """
                SELECT COALESCE(MAX(ordinal),-1)
                FROM external_operation_receipt WHERE grantUseId=?
                """,
            arguments: [useId]
        ) ?? -1
        return try CanonicalContractCodingV1.checkedIncrement(current)
    }
}

extension ApprovalGrantStore {
    private func replacing(
        _ grant: ApprovalGrantSnapshotV1,
        version: Int,
        usedCount: Int,
        state: ApprovalGrantStateV1,
        revokedAt: Date? = nil,
        updatedAt: Date
    ) -> ApprovalGrantSnapshotV1 {
        ApprovalGrantSnapshotV1(
            id: grant.id,
            version: version,
            scopeVersion: grant.scopeVersion,
            grantor: grant.grantor,
            grantee: grant.grantee,
            capability: grant.capability,
            campId: grant.campId,
            cardId: grant.cardId,
            toolId: grant.toolId,
            approvedInputHash: grant.approvedInputHash,
            purpose: grant.purpose,
            dataLevel: grant.dataLevel,
            adapterReplayClass: grant.adapterReplayClass,
            validFrom: grant.validFrom,
            validUntil: grant.validUntil,
            maxUses: grant.maxUses,
            usedCount: usedCount,
            state: state,
            revokedAt: revokedAt ?? grant.revokedAt,
            createdAt: grant.createdAt,
            updatedAt: updatedAt
        )
    }

    private func replacing(
        _ grant: ApprovalGrantSnapshotV1,
        version: Int,
        state: ApprovalGrantStateV1,
        revokedAt: Date?,
        updatedAt: Date
    ) -> ApprovalGrantSnapshotV1 {
        replacing(
            grant,
            version: version,
            usedCount: grant.usedCount,
            state: state,
            revokedAt: revokedAt,
            updatedAt: updatedAt
        )
    }

    private func replacing(
        _ use: ApprovalGrantUseSnapshotV1,
        state: ApprovalGrantUseStateV1,
        operationId: String? = nil,
        version: Int,
        dispatchIntentAt: Date? = nil,
        adapterAcceptedAt: Date? = nil,
        finishedAt: Date? = nil
    ) -> ApprovalGrantUseSnapshotV1 {
        ApprovalGrantUseSnapshotV1(
            id: use.id,
            grantId: use.grantId,
            idempotencyKey: use.idempotencyKey,
            toolId: use.toolId,
            inputHash: use.inputHash,
            adapterId: use.adapterId,
            adapterReplayClass: use.adapterReplayClass,
            state: state,
            adapterOperationId: operationId ?? use.adapterOperationId,
            version: version,
            reservedAt: use.reservedAt,
            dispatchIntentAt: dispatchIntentAt ?? use.dispatchIntentAt,
            adapterAcceptedAt: adapterAcceptedAt ?? use.adapterAcceptedAt,
            finishedAt: finishedAt
        )
    }
}

private struct CreateGrantPayload: Codable {
    let grantId: String
    let grantor: ApprovalGrantorV1
    let grantee: ApprovalGranteeV1
    let capability: String
    let campId: String
    let cardId: String
    let toolId: String
    let approvedInputHash: String
    let purpose: String
    let dataLevel: ApprovalDataLevelV1
    let adapterReplayClass: ExternalAdapterReplayClassV1
    let validFrom: Date
    let validUntil: Date
    let maxUses: Int

    init(command: CreateApprovalGrantCommandV1) {
        grantId = command.grantId
        grantor = command.grantor
        grantee = command.grantee
        capability = command.capability
        campId = command.campId
        cardId = command.cardId
        toolId = command.toolId
        approvedInputHash = command.approvedInputHash
        purpose = command.purpose
        dataLevel = command.dataLevel
        adapterReplayClass = command.adapterReplayClass
        validFrom = command.validFrom
        validUntil = command.validUntil
        maxUses = command.maxUses
    }
}

private struct ApprovalAnswerMaterial: Codable {
    let decision: String
    let reason: String?
    let canonicalJSON: String

    var approved: Bool { decision == "approve" }
}

private struct ApprovalOptionsMaterial: Codable {
    let toolId: String
    let input: JSONValue
    let inputHash: String
}

private struct ApprovalAnswerPayload: Codable {
    let requestId: String
    let cardId: String
    let campId: String
    let answer: ApprovalAnswerMaterial
    let options: ApprovalOptionsMaterial
    let answeredAt: Date
}

private struct ReserveUsePayload: Codable {
    let useId: String
    let grantId: String
    let expectedGrantVersion: Int
    let capability: String
    let campId: String
    let cardId: String
    let toolId: String
    let inputHash: String
    let adapter: ExternalOperationAdapterDescriptorV1

    init(command: ReserveApprovalGrantUseCommandV1) {
        useId = command.useId
        grantId = command.grantId
        expectedGrantVersion = command.expectedGrantVersion
        capability = command.capability
        campId = command.campId
        cardId = command.cardId
        toolId = command.toolId
        inputHash = command.inputHash
        adapter = command.adapter
    }
}

private struct UseTransitionPayload: Codable {
    let useId: String
    let expectedUseVersion: Int
    let expectedGrantVersion: Int?
    let target: ApprovalGrantUseStateV1
}

private struct AdapterTransitionPayload: Codable {
    let useId: String
    let useIdempotencyKey: String
    let expectedUseVersion: Int
    let target: ApprovalGrantUseStateV1
    let phase: ExternalOperationReceiptPhaseV1
    let receiptResult: ExternalOperationReceiptResultV1
    let adapterId: String
    let operationId: String?
    let receiptRef: String?
    let evidenceHash: String
}

private struct NoEffectPayload: Codable {
    let useId: String
    let expectedUseVersion: Int
    let expectedGrantVersion: Int
    let attestation: AdapterNoEffectAttestationMaterial

    init(
        useId: String,
        expectedUseVersion: Int,
        expectedGrantVersion: Int,
        attestation: AdapterNoEffectAttestationV1
    ) {
        self.useId = useId
        self.expectedUseVersion = expectedUseVersion
        self.expectedGrantVersion = expectedGrantVersion
        self.attestation = AdapterNoEffectAttestationMaterial(attestation)
    }
}

private struct AdapterNoEffectAttestationMaterial: Codable {
    let adapterId: String
    let useId: String
    let useIdempotencyKey: String
    let operationId: String?
    let evidenceHash: String
    let receiptRef: String?

    init(_ value: AdapterNoEffectAttestationV1) {
        adapterId = value.adapterId
        useId = value.useId
        useIdempotencyKey = value.useIdempotencyKey
        operationId = value.operationId
        evidenceHash = value.evidenceHash
        receiptRef = value.receiptRef
    }
}

private struct UserResolutionPayload: Codable {
    let useId: String
    let expectedUseVersion: Int
    let resolution: ExternalOperationUserResolutionV1
    let reason: String

    init(command: ResolveExternalOperationCommandV1) {
        useId = command.useId
        expectedUseVersion = command.expectedUseVersion
        resolution = command.resolution
        reason = command.reason
    }
}

private struct GrantStatePayload: Codable {
    let grantId: String
    let expectedVersion: Int
    let target: ApprovalGrantStateV1
}

extension ApprovalGrantStore {
    private func grant(
        id: String,
        database: Database
    ) throws -> ApprovalGrantSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM approval_grant WHERE id=?",
            arguments: [id]
        ) else { return nil }
        guard let grantorType = ApprovalGrantorTypeV1(
            rawValue: row["grantorActorType"]
        ), let granteeType = ApprovalGranteeTypeV1(
            rawValue: row["granteeType"]
        ), let dataLevel = ApprovalDataLevelV1(
            rawValue: row["dataLevel"]
        ), let replayClass = ExternalAdapterReplayClassV1(
            rawValue: row["adapterReplayClass"]
        ), let state = ApprovalGrantStateV1(rawValue: row["status"])
        else { throw ApprovalGrantConflictError() }
        let grantor: ApprovalGrantorV1
        switch grantorType {
        case .user:
            grantor = try .user(row["grantorActorId"])
        case .system:
            grantor = try .system(row["grantorActorId"])
        case .policy:
            guard let policyId: String = row["grantorPolicyId"],
                  let policyVersion: Int = row["grantorPolicyVersion"],
                  let policyHash: String = row["grantorPolicyHash"]
            else { throw ApprovalGrantConflictError() }
            grantor = try .policy(
                actorId: row["grantorActorId"],
                policyId: policyId,
                policyVersion: policyVersion,
                policyHash: policyHash
            )
        }
        return ApprovalGrantSnapshotV1(
            id: row["id"],
            version: row["version"],
            scopeVersion: row["scopeVersion"],
            grantor: grantor,
            grantee: try ApprovalGranteeV1(
                type: granteeType,
                id: row["granteeId"]
            ),
            capability: row["capability"],
            campId: row["campId"],
            cardId: row["cardId"],
            toolId: row["toolId"],
            approvedInputHash: row["approvedInputHash"],
            purpose: row["purpose"],
            dataLevel: dataLevel,
            adapterReplayClass: replayClass,
            validFrom: try P1DTimestampV1.restorePersisted(
                row["validFrom"] as Date
            ),
            validUntil: try P1DTimestampV1.restorePersisted(
                row["validUntil"] as Date
            ),
            maxUses: row["maxUses"],
            usedCount: row["usedCount"],
            state: state,
            revokedAt: try P1DTimestampV1.restorePersisted(
                row["revokedAt"] as Date?
            ),
            createdAt: try P1DTimestampV1.restorePersisted(
                row["createdAt"] as Date
            ),
            updatedAt: try P1DTimestampV1.restorePersisted(
                row["updatedAt"] as Date
            )
        )
    }

    private func requireGrant(
        id: String,
        version: Int? = nil,
        database: Database
    ) throws -> ApprovalGrantSnapshotV1 {
        guard let grant = try grant(id: id, database: database),
              version == nil || grant.version == version
        else { throw ApprovalGrantConflictError() }
        return grant
    }

    private func validateGrantProjection(
        _ result: ApprovalGrantSnapshotV1,
        database: Database
    ) throws {
        guard try grant(id: result.id, database: database) == result else {
            throw ApprovalGrantConflictError()
        }
    }

    private func use(
        id: String,
        database: Database
    ) throws -> ApprovalGrantUseSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM approval_grant_use WHERE id=?",
            arguments: [id]
        ) else { return nil }
        guard let replayClass = ExternalAdapterReplayClassV1(
            rawValue: row["adapterReplayClass"]
        ), let state = ApprovalGrantUseStateV1(rawValue: row["state"])
        else { throw ApprovalGrantConflictError() }
        return ApprovalGrantUseSnapshotV1(
            id: row["id"],
            grantId: row["grantId"],
            idempotencyKey: row["idempotencyKey"],
            toolId: row["toolId"],
            inputHash: row["inputHash"],
            adapterId: row["adapterId"],
            adapterReplayClass: replayClass,
            state: state,
            adapterOperationId: row["adapterOperationId"],
            version: row["version"],
            reservedAt: try P1DTimestampV1.restorePersisted(
                row["reservedAt"] as Date
            ),
            dispatchIntentAt: try P1DTimestampV1.restorePersisted(
                row["dispatchIntentAt"] as Date?
            ),
            adapterAcceptedAt: try P1DTimestampV1.restorePersisted(
                row["adapterAcceptedAt"] as Date?
            ),
            finishedAt: try P1DTimestampV1.restorePersisted(
                row["finishedAt"] as Date?
            )
        )
    }

    private func requireUse(
        id: String,
        version: Int? = nil,
        states: Set<ApprovalGrantUseStateV1>? = nil,
        database: Database
    ) throws -> ApprovalGrantUseSnapshotV1 {
        guard let use = try use(id: id, database: database),
              version == nil || use.version == version,
              states == nil || states!.contains(use.state)
        else { throw ApprovalGrantConflictError() }
        return use
    }

    private func validateUseProjection(
        _ result: ApprovalGrantUseSnapshotV1,
        database: Database
    ) throws {
        guard try use(id: result.id, database: database) == result else {
            throw ApprovalGrantConflictError()
        }
    }

    private func requireReceipt(
        id: String,
        database: Database
    ) throws -> ExternalOperationReceiptSnapshotV1 {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM external_operation_receipt WHERE id=?",
            arguments: [id]
        ), let phase = ExternalOperationReceiptPhaseV1(
            rawValue: row["phase"]
        ), let result = ExternalOperationReceiptResultV1(
            rawValue: row["result"]
        ), let authority = ExternalOperationReceiptAuthorityV1(
            rawValue: row["authorityKind"]
        ) else { throw ExternalOperationAttestationError() }
        let jsonString: String = row["receiptJson"]
        let bytes = Data(jsonString.utf8)
        let hash: String = row["receiptHash"]
        guard CanonicalJSONV1.sha256Hex(bytes) == hash else {
            throw ExternalOperationAttestationError()
        }
        let json = try CanonicalContractCodingV1.decode(
            JSONValue.self,
            from: bytes
        )
        let ordinal: Int = row["ordinal"]
        let useId: String = row["grantUseId"]
        guard row["receiptIdempotencyKey"] as String
                == "external-receipt:v1:\(useId):\(ordinal):\(phase.rawValue)"
        else { throw ExternalOperationAttestationError() }
        return ExternalOperationReceiptSnapshotV1(
            id: row["id"],
            grantUseId: useId,
            receiptIdempotencyKey: row["receiptIdempotencyKey"],
            ordinal: ordinal,
            phase: phase,
            result: result,
            adapterOperationId: row["adapterOperationId"],
            receiptRef: row["receiptRef"],
            receiptJSON: json,
            receiptHash: hash,
            authority: authority,
            authorityId: row["authorityId"],
            createdAt: try P1DTimestampV1.restorePersisted(
                row["createdAt"] as Date
            )
        )
    }

    private func validateDispatchProjection(
        _ result: ApprovalGrantDispatchSnapshotV1,
        database: Database
    ) throws {
        try validateGrantProjection(result.grant, database: database)
        try validateUseProjection(result.use, database: database)
        if let receipt = result.receipt {
            guard try requireReceipt(
                id: receipt.id,
                database: database
            ) == receipt else {
                throw ExternalOperationAttestationError()
            }
        }
    }

    private func grantCamp(
        _ id: String,
        database: Database
    ) throws -> String {
        guard let camp = try String.fetchOne(
            database,
            sql: "SELECT campId FROM approval_grant WHERE id=?",
            arguments: [id]
        ) else { throw ApprovalGrantConflictError() }
        return camp
    }

    private func storedEventVersion(
        commandKey: String,
        fallback: Int,
        database: Database
    ) throws -> Int {
        try Int.fetchOne(
            database,
            sql: """
                SELECT aggregateVersion FROM domain_event
                WHERE commandIdempotencyKey=? ORDER BY eventOrdinal LIMIT 1
                """,
            arguments: [commandKey]
        ) ?? fallback
    }

    private func grantEvent(
        campId: String,
        aggregateId: String,
        aggregateVersion: Int,
        eventType: String,
        state: ApprovalGrantStateV1
    ) throws -> P1DCommandEventShapeV1 {
        try P1DCommandEventShapeV1(
            campId: campId,
            aggregateType: "approvalGrant",
            aggregateId: aggregateId,
            aggregateVersion: aggregateVersion,
            eventType: eventType,
            payload: .object([
                "grantId": .string(aggregateId),
                "state": .string(state.rawValue),
            ])
        )
    }

    private func useEvent(
        campId: String,
        useId: String,
        aggregateVersion: Int,
        eventType: String,
        state: ApprovalGrantUseStateV1
    ) throws -> P1DCommandEventShapeV1 {
        try P1DCommandEventShapeV1(
            campId: campId,
            aggregateType: "approvalGrantUse",
            aggregateId: useId,
            aggregateVersion: aggregateVersion,
            eventType: eventType,
            payload: .object([
                "state": .string(state.rawValue),
                "useId": .string(useId),
            ])
        )
    }

    private func validateAttestationIdentity(
        useId: String,
        attestationUseId: String
    ) throws {
        guard useId == attestationUseId else {
            throw ExternalOperationAttestationError()
        }
    }

    private func refundState(
        grant: ApprovalGrantSnapshotV1,
        newUsedCount: Int,
        now: Date
    ) -> ApprovalGrantStateV1 {
        if grant.state == .revoked { return .revoked }
        if grant.state == .expired || now >= grant.validUntil {
            return .expired
        }
        return newUsedCount < grant.maxUses ? .active : .exhausted
    }
}

extension ApprovalGrantStore {
    package func recordAdapterAccepted(
        _ command: ApprovalGrantUseTransitionCommandV1,
        attestation: AdapterAcceptanceAttestationV1
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        try validateAttestationIdentity(
            useId: command.useId,
            attestationUseId: attestation.useId
        )
        return try transitionWithAdapterReceipt(
            command,
            commandType: "approval-grant.adapter-accepted.v1",
            eventType: "approval-grant.adapter-accepted.v1",
            expectedStates: [.dispatching],
            target: .accepted,
            phase: .adapterAccepted,
            receiptResult: .pending,
            adapterId: attestation.adapterId,
            useIdempotencyKey: attestation.useIdempotencyKey,
            operationId: attestation.operationId,
            receiptRef: nil,
            evidenceHash: attestation.evidenceHash
        )
    }

    package func recordEffect(
        _ command: ApprovalGrantUseTransitionCommandV1,
        attestation: AdapterEffectAttestationV1
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        try validateAttestationIdentity(
            useId: command.useId,
            attestationUseId: attestation.useId
        )
        let state: ApprovalGrantUseStateV1 = attestation.result == .succeeded
            ? .succeeded : .failedFinal
        return try transitionWithAdapterReceipt(
            command,
            commandType: "approval-grant.effect-confirmed.v1",
            eventType: "approval-grant.effect-confirmed.v1",
            expectedStates: [.dispatching, .accepted],
            target: state,
            phase: .effectConfirmed,
            receiptResult: attestation.result,
            adapterId: attestation.adapterId,
            useIdempotencyKey: attestation.useIdempotencyKey,
            operationId: attestation.operationId,
            receiptRef: attestation.receiptRef,
            evidenceHash: attestation.evidenceHash
        )
    }

    package func recordReconciliationFailure(
        _ command: ApprovalGrantUseTransitionCommandV1,
        adapterId: String,
        evidenceHash: String
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        try CanonicalContractCodingV1.validateNonempty(adapterId)
        try CanonicalContractCodingV1.validateLowercaseHash(evidenceHash)
        let current = try database.pool.read { db in
            try requireUse(id: command.useId, database: db)
        }
        return try transitionWithAdapterReceipt(
            command,
            commandType: "approval-grant.reconciliation-failed.v1",
            eventType: "approval-grant.reconciliation-failed.v1",
            expectedStates: [.dispatching, .accepted],
            target: current.state,
            phase: .reconciliationFailed,
            receiptResult: .unknown,
            adapterId: adapterId,
            useIdempotencyKey: current.idempotencyKey,
            operationId: current.adapterOperationId,
            receiptRef: nil,
            evidenceHash: evidenceHash
        )
    }

    package func markCrashUnknown(
        _ command: ApprovalGrantUseTransitionCommandV1
    ) throws -> ApprovalGrantUseSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        return try transitionUseWithoutReceipt(
            command,
            commandType: "approval-grant.crash-unknown.v1",
            eventType: "approval-grant.crash-unknown-urgent.v1",
            expectedStates: [.dispatching, .accepted],
            target: .crashUnknown,
            requireNoReceipt: false
        )
    }

    package func confirmAdapterNoEffect(
        _ command: ApprovalGrantUseTransitionCommandV1,
        attestation: AdapterNoEffectAttestationV1
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        try authorizeCoordinator(command.envelope)
        guard let expectedGrantVersion = command.expectedGrantVersion else {
            throw ApprovalGrantConflictError()
        }
        try validateAttestationIdentity(
            useId: command.useId,
            attestationUseId: attestation.useId
        )
        let payload = NoEffectPayload(
            useId: command.useId,
            expectedUseVersion: command.expectedUseVersion,
            expectedGrantVersion: expectedGrantVersion,
            attestation: attestation
        )
        return try database.pool.write { db in
            let existing = try requireUse(id: command.useId, database: db)
            let campId = try grantCamp(existing.grantId, database: db)
            let eventVersion = try storedEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: command.expectedUseVersion + 1,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-grant.no-effect.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try useEvent(
                    campId: campId,
                    useId: command.useId,
                    aggregateVersion: eventVersion,
                    eventType: "approval-grant.no-effect-confirmed.v1",
                    state: .released
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let use = try requireUse(
                        id: command.useId,
                        version: command.expectedUseVersion,
                        states: [.dispatching, .accepted, .crashUnknown],
                        database: transaction
                    )
                    guard use.adapterId == attestation.adapterId,
                          use.idempotencyKey
                            == attestation.useIdempotencyKey,
                          use.adapterOperationId == attestation.operationId
                            || use.adapterOperationId == nil
                    else {
                        throw ExternalOperationAttestationError()
                    }
                    let grant = try requireGrant(
                        id: use.grantId,
                        version: expectedGrantVersion,
                        database: transaction
                    )
                    guard grant.usedCount > 0 else {
                        throw ApprovalGrantTransitionError()
                    }
                    let nextUse = replacing(
                        use,
                        state: .released,
                        version: use.version + 1,
                        finishedAt: command.envelope.occurredAt
                    )
                    let nextCount = grant.usedCount - 1
                    let state = refundState(
                        grant: grant,
                        newUsedCount: nextCount,
                        now: command.envelope.occurredAt
                    )
                    let nextGrant = replacing(
                        grant,
                        version: grant.version + 1,
                        usedCount: nextCount,
                        state: state,
                        updatedAt: command.envelope.occurredAt
                    )
                    let receipt = try makeReceipt(
                        use: nextUse,
                        ordinal: try nextReceiptOrdinal(
                            useId: use.id,
                            database: transaction
                        ),
                        phase: .noEffectConfirmed,
                        result: .noEffect,
                        operationId: attestation.operationId,
                        receiptRef: attestation.receiptRef,
                        evidenceHash: attestation.evidenceHash,
                        authority: .adapter,
                        authorityId: attestation.adapterId,
                        at: command.envelope.occurredAt
                    )
                    return ApprovalGrantDispatchSnapshotV1(
                        grant: nextGrant,
                        use: nextUse,
                        receipt: receipt
                    )
                },
                apply: { transaction, _, result in
                    try updateGrant(
                        result.grant,
                        expectedVersion: expectedGrantVersion,
                        database: transaction
                    )
                    try updateUse(
                        result.use,
                        expectedVersion: command.expectedUseVersion,
                        database: transaction
                    )
                    guard let receipt = result.receipt else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    try insertReceipt(receipt, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    try validateDispatchProjection(
                        result,
                        database: transaction
                    )
                }
            )
        }
    }

    package func resolveExternalOperation(
        _ command: ResolveExternalOperationCommandV1
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        guard command.envelope.actorType == .user,
              command.envelope.actorId == P1DActorID.localOwner
        else {
            throw ApprovalGrantAuthorizationError()
        }
        let target: ApprovalGrantUseStateV1 = command.resolution == .succeeded
            ? .succeeded : .abandonedUnknown
        let receiptResult: ExternalOperationReceiptResultV1 =
            command.resolution == .succeeded ? .succeeded : .abandonedUnknown
        return try transitionWithUserReceipt(
            command,
            target: target,
            receiptResult: receiptResult
        )
    }

    package func revokeGrant(
        id: String,
        expectedVersion: Int,
        envelope: CommandEnvelopeV1
    ) throws -> ApprovalGrantSnapshotV1 {
        try changeGrantState(
            id: id,
            expectedVersion: expectedVersion,
            envelope: envelope,
            target: .revoked
        )
    }

    package func expireGrant(
        id: String,
        expectedVersion: Int,
        envelope: CommandEnvelopeV1
    ) throws -> ApprovalGrantSnapshotV1 {
        try changeGrantState(
            id: id,
            expectedVersion: expectedVersion,
            envelope: envelope,
            target: .expired
        )
    }

    package func pendingUses() throws -> [ApprovalGrantUseSnapshotV1] {
        try database.pool.read { db in
            let ids = try String.fetchAll(
                db,
                sql: """
                    SELECT id FROM approval_grant_use
                    WHERE state IN ('dispatching','accepted','crashUnknown')
                    ORDER BY reservedAt,id
                    """
            )
            return try ids.map { try requireUse(id: $0, database: db) }
        }
    }
}

extension ApprovalGrantStore {
    private func transitionUseWithoutReceipt(
        _ command: ApprovalGrantUseTransitionCommandV1,
        commandType: String,
        eventType: String,
        expectedStates: Set<ApprovalGrantUseStateV1>,
        target: ApprovalGrantUseStateV1,
        requireNoReceipt: Bool
    ) throws -> ApprovalGrantUseSnapshotV1 {
        let payload = UseTransitionPayload(
            useId: command.useId,
            expectedUseVersion: command.expectedUseVersion,
            expectedGrantVersion: command.expectedGrantVersion,
            target: target
        )
        return try database.pool.write { db in
            let existing = try requireUse(id: command.useId, database: db)
            let campId = try grantCamp(existing.grantId, database: db)
            let eventVersion = try storedEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: command.expectedUseVersion + 1,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: commandType,
                envelope: command.envelope,
                payload: payload,
                events: [try useEvent(
                    campId: campId,
                    useId: command.useId,
                    aggregateVersion: eventVersion,
                    eventType: eventType,
                    state: target
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let use = try requireUse(
                        id: command.useId,
                        version: command.expectedUseVersion,
                        states: expectedStates,
                        database: transaction
                    )
                    if requireNoReceipt {
                        guard try Int.fetchOne(
                            transaction,
                            sql: "SELECT COUNT(*) FROM external_operation_receipt WHERE grantUseId=?",
                            arguments: [use.id]
                        ) == 0, use.dispatchIntentAt == nil else {
                            throw ApprovalGrantTransitionError()
                        }
                    }
                    if target == .crashUnknown {
                        guard use.dispatchIntentAt != nil,
                              use.adapterReplayClass == .nonReplayable
                        else {
                            throw ApprovalGrantTransitionError()
                        }
                    }
                    return replacing(
                        use,
                        state: target,
                        version: use.version + 1,
                        finishedAt: target == .released
                            ? command.envelope.occurredAt : nil
                    )
                },
                apply: { transaction, _, result in
                    try updateUse(
                        result,
                        expectedVersion: command.expectedUseVersion,
                        database: transaction
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateUseProjection(result, database: transaction)
                }
            )
        }
    }

    private func transitionWithAdapterReceipt(
        _ command: ApprovalGrantUseTransitionCommandV1,
        commandType: String,
        eventType: String,
        expectedStates: Set<ApprovalGrantUseStateV1>,
        target: ApprovalGrantUseStateV1,
        phase: ExternalOperationReceiptPhaseV1,
        receiptResult: ExternalOperationReceiptResultV1,
        adapterId: String,
        useIdempotencyKey: String,
        operationId: String?,
        receiptRef: String?,
        evidenceHash: String
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        let payload = AdapterTransitionPayload(
            useId: command.useId,
            useIdempotencyKey: useIdempotencyKey,
            expectedUseVersion: command.expectedUseVersion,
            target: target,
            phase: phase,
            receiptResult: receiptResult,
            adapterId: adapterId,
            operationId: operationId,
            receiptRef: receiptRef,
            evidenceHash: evidenceHash
        )
        return try database.pool.write { db in
            let existing = try requireUse(id: command.useId, database: db)
            let campId = try grantCamp(existing.grantId, database: db)
            let eventVersion = try storedEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: command.expectedUseVersion + 1,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: commandType,
                envelope: command.envelope,
                payload: payload,
                events: [try useEvent(
                    campId: campId,
                    useId: command.useId,
                    aggregateVersion: eventVersion,
                    eventType: eventType,
                    state: target
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let use = try requireUse(
                        id: command.useId,
                        version: command.expectedUseVersion,
                        states: expectedStates,
                        database: transaction
                    )
                    guard use.adapterId == adapterId,
                          use.idempotencyKey == useIdempotencyKey
                    else {
                        throw ExternalOperationAttestationError()
                    }
                    if phase == .adapterAccepted {
                        guard operationId != nil,
                              use.adapterOperationId == nil
                        else {
                            throw ExternalOperationAttestationError()
                        }
                    } else if use.adapterOperationId != nil,
                              operationId != use.adapterOperationId
                    {
                        throw ExternalOperationAttestationError()
                    }
                    let terminal = target == .succeeded
                        || target == .failedFinal
                    let nextUse = replacing(
                        use,
                        state: target,
                        operationId: operationId ?? use.adapterOperationId,
                        version: use.version + 1,
                        adapterAcceptedAt: phase == .adapterAccepted
                            ? command.envelope.occurredAt
                            : use.adapterAcceptedAt,
                        finishedAt: terminal
                            ? command.envelope.occurredAt : nil
                    )
                    let receipt = try makeReceipt(
                        use: nextUse,
                        ordinal: try nextReceiptOrdinal(
                            useId: use.id,
                            database: transaction
                        ),
                        phase: phase,
                        result: receiptResult,
                        operationId: operationId,
                        receiptRef: receiptRef,
                        evidenceHash: evidenceHash,
                        authority: .adapter,
                        authorityId: adapterId,
                        at: command.envelope.occurredAt
                    )
                    let grant = try requireGrant(
                        id: use.grantId,
                        database: transaction
                    )
                    return ApprovalGrantDispatchSnapshotV1(
                        grant: grant,
                        use: nextUse,
                        receipt: receipt
                    )
                },
                apply: { transaction, _, result in
                    try updateUse(
                        result.use,
                        expectedVersion: command.expectedUseVersion,
                        database: transaction
                    )
                    guard let receipt = result.receipt else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    try insertReceipt(receipt, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    try validateDispatchProjection(
                        result,
                        database: transaction
                    )
                }
            )
        }
    }

    private func transitionWithUserReceipt(
        _ command: ResolveExternalOperationCommandV1,
        target: ApprovalGrantUseStateV1,
        receiptResult: ExternalOperationReceiptResultV1
    ) throws -> ApprovalGrantDispatchSnapshotV1 {
        let payload = UserResolutionPayload(command: command)
        return try database.pool.write { db in
            let existing = try requireUse(id: command.useId, database: db)
            let campId = try grantCamp(existing.grantId, database: db)
            let eventVersion = try storedEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: command.expectedUseVersion + 1,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-grant.user-resolve.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try useEvent(
                    campId: campId,
                    useId: command.useId,
                    aggregateVersion: eventVersion,
                    eventType: "approval-grant.user-resolved.v1",
                    state: target
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let use = try requireUse(
                        id: command.useId,
                        version: command.expectedUseVersion,
                        states: [.dispatching, .accepted, .crashUnknown],
                        database: transaction
                    )
                    let nextUse = replacing(
                        use,
                        state: target,
                        version: use.version + 1,
                        finishedAt: command.envelope.occurredAt
                    )
                    let receipt = try makeReceipt(
                        use: nextUse,
                        ordinal: try nextReceiptOrdinal(
                            useId: use.id,
                            database: transaction
                        ),
                        phase: .userResolved,
                        result: receiptResult,
                        operationId: use.adapterOperationId,
                        receiptRef: nil,
                        evidenceHash: CanonicalJSONV1.sha256Hex(
                            Data(command.reason.utf8)
                        ),
                        authority: .user,
                        authorityId: command.envelope.actorId,
                        at: command.envelope.occurredAt
                    )
                    return ApprovalGrantDispatchSnapshotV1(
                        grant: try requireGrant(
                            id: use.grantId,
                            database: transaction
                        ),
                        use: nextUse,
                        receipt: receipt
                    )
                },
                apply: { transaction, _, result in
                    try updateUse(
                        result.use,
                        expectedVersion: command.expectedUseVersion,
                        database: transaction
                    )
                    guard let receipt = result.receipt else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    try insertReceipt(receipt, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    try validateDispatchProjection(
                        result,
                        database: transaction
                    )
                }
            )
        }
    }

    private func changeGrantState(
        id: String,
        expectedVersion: Int,
        envelope: CommandEnvelopeV1,
        target: ApprovalGrantStateV1
    ) throws -> ApprovalGrantSnapshotV1 {
        guard envelope.actorType == .user || envelope.actorType == .system,
              target == .revoked || target == .expired
        else {
            throw ApprovalGrantAuthorizationError()
        }
        let payload = GrantStatePayload(
            grantId: id,
            expectedVersion: expectedVersion,
            target: target
        )
        return try database.pool.write { db in
            let campId = try grantCamp(id, database: db)
            let eventVersion = try storedEventVersion(
                commandKey: envelope.idempotencyKey,
                fallback: expectedVersion + 1,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "approval-grant.\(target.rawValue).v1",
                envelope: envelope,
                payload: payload,
                events: [try grantEvent(
                    campId: campId,
                    aggregateId: id,
                    aggregateVersion: eventVersion,
                    eventType: "approval-grant.\(target.rawValue).v1",
                    state: target
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let grant = try requireGrant(
                        id: id,
                        version: expectedVersion,
                        database: transaction
                    )
                    if target == .expired {
                        guard envelope.occurredAt >= grant.validUntil else {
                            throw ApprovalGrantTransitionError()
                        }
                    }
                    return replacing(
                        grant,
                        version: grant.version + 1,
                        state: target,
                        revokedAt: target == .revoked
                            ? envelope.occurredAt : grant.revokedAt,
                        updatedAt: envelope.occurredAt
                    )
                },
                apply: { transaction, _, result in
                    try updateGrant(
                        result,
                        expectedVersion: expectedVersion,
                        database: transaction
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateGrantProjection(result, database: transaction)
                }
            )
        }
    }
}
