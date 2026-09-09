import Foundation
import GRDB

package struct OutcomeStore: Sendable {
    private let database: AppDatabase
    private let clock: @Sendable () -> Date
    private let eventStore: DomainEventStore
    private let memoryStore: MemoryRecordStore

    package init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.database = database
        self.clock = clock
        eventStore = DomainEventStore(database: database, clock: clock)
        memoryStore = MemoryRecordStore(database: database)
    }

    package func createDraft(
        _ command: CreateOutcomeContractDraftCommandV1
    ) throws -> OutcomeContractSnapshotV1 {
        try authorizeUser(command.envelope)
        let payload = CreateContractPayload(
            contractId: command.contractId,
            goal: command.goal,
            understanding: command.understanding,
            body: command.body
        )
        return try database.pool.write { db in
            let eventVersion = try commandEventVersion(
                database: db,
                commandKey: command.envelope.idempotencyKey,
                aggregateType: "outcomeContract",
                aggregateId: command.contractId
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "outcome-contract.create-draft.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try contractEvent(
                    command.goal.campId,
                    command.contractId,
                    eventVersion,
                    "outcome-contract.draft-created.v1",
                    version: 1
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                let goal = try requireGoal(
                    command.goal,
                    database: transaction
                )
                guard goal.status == .ready,
                      goal.currentUnderstandingId == command.understanding.id,
                      goal.currentUnderstandingVersion
                        == command.understanding.version
                else {
                    throw OutcomeContractActivationError.staleUnderstanding
                }
                try requireConfirmedUnderstanding(
                    command.understanding,
                    goalId: goal.id,
                    database: transaction
                )
                guard try Int.fetchOne(
                    transaction,
                    sql: "SELECT COUNT(*) FROM outcome_contract_version WHERE id=?",
                    arguments: [command.contractId]
                ) == 0 else {
                    throw P1DProjectionConflictError()
                }
                return try makeContractSnapshot(
                    id: command.contractId,
                    version: 1,
                    goalId: goal.id,
                    understanding: command.understanding,
                    body: command.body,
                    status: .draft,
                    createdByActorId: command.envelope.actorId,
                    activatedByActorId: nil,
                    createdAt: command.envelope.occurredAt,
                    activatedAt: nil
                )
            }, apply: { transaction, _, result in
                try insertContract(result, database: transaction)
                guard try requireContract(
                    ref: result.ref,
                    database: transaction
                ) == result else {
                    throw P1DProjectionConflictError()
                }
            }, validateProjection: { transaction, _, result in
                try validateContractProjection(result, database: transaction)
            })
        }
    }

    package func reviseContract(
        _ command: ReviseOutcomeContractCommandV1
    ) throws -> OutcomeContractSnapshotV1 {
        try authorizeUser(command.envelope)
        let payload = ReviseContractPayload(
            contract: command.contract,
            body: command.body
        )
        return try database.pool.write { db in
            let resultVersion: Int = try storedResult(
                OutcomeContractSnapshotV1.self,
                commandKey: command.envelope.idempotencyKey,
                database: db
            )?.ref.version ?? nextContractVersion(
                id: command.contract.id,
                database: db
            )
            let eventVersion = try commandEventVersion(
                database: db,
                commandKey: command.envelope.idempotencyKey,
                aggregateType: "outcomeContract",
                aggregateId: command.contract.id
            )
            let campId = try contractCamp(
                command.contract.id,
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "outcome-contract.revise.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try contractEvent(
                    campId,
                    command.contract.id,
                    eventVersion,
                    "outcome-contract.revised.v1",
                    version: resultVersion
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                let current = try requireContract(
                    ref: command.contract,
                    database: transaction
                )
                guard current.status == .draft || current.status == .active else {
                    throw InvalidOutcomeContractTransitionError()
                }
                let version = try nextContractVersion(
                    id: current.ref.id,
                    database: transaction
                )
                return try makeContractSnapshot(
                    id: current.ref.id,
                    version: version,
                    goalId: current.goalId,
                    understanding: current.understanding,
                    body: command.body,
                    status: .draft,
                    createdByActorId: command.envelope.actorId,
                    activatedByActorId: nil,
                    createdAt: command.envelope.occurredAt,
                    activatedAt: nil
                )
            }, apply: { transaction, _, result in
                let current = try requireContract(
                    ref: command.contract,
                    database: transaction
                )
                if current.status == .draft {
                    try transaction.execute(
                        sql: """
                            UPDATE outcome_contract_version SET status='canceled'
                            WHERE id=? AND version=? AND contentHash=? AND status='draft'
                            """,
                        arguments: [
                            current.ref.id, current.ref.version,
                            current.ref.hash,
                        ]
                    )
                    guard transaction.changesCount == 1 else {
                        throw P1DProjectionConflictError()
                    }
                }
                try insertContract(result, database: transaction)
                guard try requireContract(
                    ref: result.ref,
                    database: transaction
                ) == result else {
                    throw P1DProjectionConflictError()
                }
            }, validateProjection: { transaction, _, result in
                try validateContractProjection(result, database: transaction)
            })
        }
    }

    package func activateContract(
        _ command: ActivateOutcomeContractCommandV1
    ) throws -> OutcomeContractSnapshotV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.outcomeContract
        )
        return try changeContract(
            commandType: "outcome-contract.activate.v1",
            eventType: "outcome-contract.activated.v1",
            envelope: command.envelope,
            contract: command.contract,
            targetStatus: .active,
            activatedByActorId: command.envelope.actorId,
            activatedAt: command.envelope.occurredAt
        ) { current, transaction in
            guard current.status == .draft else {
                throw InvalidOutcomeContractTransitionError()
            }
            let goal = try GoalControllerRecord.fetchOne(
                transaction,
                key: current.goalId
            )
            guard let goal,
                  goal.currentUnderstandingId == current.understanding.id,
                  goal.currentUnderstandingVersion
                    == current.understanding.version
            else {
                throw OutcomeContractActivationError.staleUnderstanding
            }
            try requireConfirmedUnderstanding(
                current.understanding,
                goalId: current.goalId,
                database: transaction
            )
            guard !current.body.verificationGroups.isEmpty,
                  current.body.verificationGroups.allSatisfy({
                      !$0.requirements.isEmpty
                  })
            else {
                throw OutcomeContractActivationError.invalidRequirements
            }
            if current.body.outcomeType == "coding" {
                guard current.body.verificationGroups
                    .flatMap({ $0.requirements })
                    .contains(where: { $0.verifierType == .deterministic })
                else {
                    throw OutcomeContractActivationError.invalidRequirements
                }
            }
            if current.body.acceptanceOwner == .policy {
                guard let policy = current.body.acceptancePolicy,
                      try policyExists(policy, database: transaction)
                else {
                    throw OutcomeContractActivationError.invalidPolicy
                }
            }
        }
    }

    package func cancelContract(
        _ command: ChangeOutcomeContractStatusCommandV1
    ) throws -> OutcomeContractSnapshotV1 {
        try authorizeUser(command.envelope)
        return try changeContract(
            commandType: "outcome-contract.cancel.v1",
            eventType: "outcome-contract.canceled.v1",
            envelope: command.envelope,
            contract: command.contract,
            targetStatus: .canceled
        ) { current, _ in
            guard current.status == .draft else {
                throw InvalidOutcomeContractTransitionError()
            }
        }
    }

    package func fulfillContract(
        _ command: ChangeOutcomeContractStatusCommandV1
    ) throws -> OutcomeContractSnapshotV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.outcomeContract
        )
        return try changeContract(
            commandType: "outcome-contract.fulfill.v1",
            eventType: "outcome-contract.fulfilled.v1",
            envelope: command.envelope,
            contract: command.contract,
            targetStatus: .fulfilled
        ) { current, _ in
            guard current.status == .active else {
                throw InvalidOutcomeContractTransitionError()
            }
        }
    }

    package func activateGoal(
        _ command: ActivateGoalCommandV1
    ) throws -> ActivatedGoalV1 {
        try authorizeUser(command.envelope)
        let payload = GoalActivationPayload(
            goal: command.goal,
            contract: command.contract,
            missionId: command.missionId,
            expectedLinkVersion: command.expectedLinkVersion
        )
        return try database.pool.write { db in
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "goal.activate.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try goalEvent(
                    command.goal,
                    version: try CanonicalContractCodingV1.checkedIncrement(
                        command.goal.expectedGoalVersion
                    ),
                    eventType: "goal.activated.v1"
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                let goal = try requireGoal(command.goal, database: transaction)
                guard goal.status == .ready,
                      goal.currentOutcomeContractId == nil,
                      goal.currentOutcomeContractVersion == nil
                else {
                    throw GoalActivationError.invalidGoalState
                }
                let contract = try requireContract(
                    ref: command.contract,
                    database: transaction
                )
                guard contract.status == .active else {
                    throw GoalActivationError.inactiveContract
                }
                guard contract.goalId == goal.id else {
                    throw GoalActivationError.wrongGoal
                }
                guard goal.currentUnderstandingId == contract.understanding.id,
                      goal.currentUnderstandingVersion
                        == contract.understanding.version
                else {
                    throw GoalActivationError.invalidGoalState
                }
                try requireMission(
                    command.missionId,
                    campId: goal.campId,
                    states: [.planning, .executing, .delivering],
                    database: transaction
                )
                let link = try prepareLink(
                    missionId: command.missionId,
                    goalId: goal.id,
                    contract: contract.ref,
                    expectedVersion: command.expectedLinkVersion,
                    now: command.envelope.occurredAt,
                    database: transaction
                )
                let nextVersion = try CanonicalContractCodingV1
                    .checkedIncrement(goal.aggregateVersion)
                var updated = goal
                updated.status = .active
                updated.currentOutcomeContractId = contract.ref.id
                updated.currentOutcomeContractVersion = contract.ref.version
                updated.aggregateVersion = nextVersion
                updated.updatedAt = command.envelope.occurredAt
                return ActivatedGoalV1(goal: updated, link: link)
            }, apply: { transaction, _, result in
                let goal = try requireGoal(
                    command.goal,
                    database: transaction
                )
                try applyPreparedLink(
                    result.link,
                    expectedVersion: command.expectedLinkVersion,
                    database: transaction
                )
                try transaction.execute(
                    sql: """
                        UPDATE goal_controller
                        SET status='active',currentOutcomeContractId=?,
                            currentOutcomeContractVersion=?,aggregateVersion=?,updatedAt=?
                        WHERE id=? AND campId=? AND aggregateVersion=? AND status='ready'
                    """,
                    arguments: [
                        result.goal.currentOutcomeContractId,
                        result.goal.currentOutcomeContractVersion,
                        result.goal.aggregateVersion,
                        result.goal.updatedAt,
                        goal.id,
                        goal.campId,
                        goal.aggregateVersion,
                    ]
                )
                guard transaction.changesCount == 1,
                      let updated = try restoredGoal(
                          id: goal.id,
                          database: transaction
                      ), updated == result.goal
                else {
                    throw P1DProjectionConflictError()
                }
            }, validateProjection: { transaction, _, result in
                try validateActivatedGoalProjection(
                    result,
                    database: transaction
                )
            })
        }
    }

    package func linkMissionToActiveGoal(
        _ command: LinkMissionToGoalCommandV1
    ) throws -> GoalMissionLinkRecordV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.outcomeContract
        )
        let payload = LinkMissionPayload(
            goal: command.goal,
            contract: command.contract,
            missionId: command.missionId,
            expectedLinkVersion: command.expectedLinkVersion
        )
        return try database.pool.write { db in
            let eventVersion = try commandEventVersion(
                database: db,
                commandKey: command.envelope.idempotencyKey,
                aggregateType: "goalMissionLink",
                aggregateId: command.missionId
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "goal.link-mission.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try P1DCommandEventShapeV1(
                    campId: command.goal.campId,
                    aggregateType: "goalMissionLink",
                    aggregateId: command.missionId,
                    aggregateVersion: eventVersion,
                    eventType: "goal.mission-linked.v1",
                    payload: .object([
                        "goalId": .string(command.goal.goalId),
                        "contractId": .string(command.contract.id),
                    ])
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                let goal = try requireGoal(command.goal, database: transaction)
                guard goal.status == .active,
                      goal.currentOutcomeContractId == command.contract.id,
                      goal.currentOutcomeContractVersion
                        == command.contract.version
                else {
                    throw GoalActivationError.invalidGoalState
                }
                let contract = try requireContract(
                    ref: command.contract,
                    database: transaction
                )
                guard contract.status == .active,
                      contract.goalId == goal.id
                else {
                    throw GoalActivationError.inactiveContract
                }
                try requireMission(
                    command.missionId,
                    campId: goal.campId,
                    states: [.planning, .executing, .delivering],
                    database: transaction
                )
                return try prepareLink(
                    missionId: command.missionId,
                    goalId: goal.id,
                    contract: contract.ref,
                    expectedVersion: command.expectedLinkVersion,
                    now: command.envelope.occurredAt,
                    database: transaction
                )
            }, apply: { transaction, _, result in
                try applyPreparedLink(
                    result,
                    expectedVersion: command.expectedLinkVersion,
                    database: transaction
                )
            }, validateProjection: { transaction, _, result in
                guard try restoredLink(
                    missionId: result.missionId,
                    database: transaction
                ) == result else {
                    throw P1DProjectionConflictError()
                }
            })
        }
    }

    package func transitionGoal(
        _ command: GoalStatusCommandV1
    ) throws -> GoalControllerRecord {
        switch command.transition {
        case .pause, .resume, .achieve:
            try authorizeUser(command.envelope)
        case .reopen:
            try authorizeSystem(
                command.envelope,
                actorId: P1DActorID.outcomeReopen
            )
        }
        let payload = GoalTransitionPayload(
            goal: command.goal,
            transition: command.transition
        )
        return try database.pool.write { db in
            let targetVersion = try CanonicalContractCodingV1.checkedIncrement(
                command.goal.expectedGoalVersion
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "goal.\(command.transition.rawValue).v1",
                envelope: command.envelope,
                payload: payload,
                events: [try goalEvent(
                    command.goal,
                    version: targetVersion,
                    eventType: "goal.\(command.transition.rawValue).v1"
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                let goal = try requireGoal(command.goal, database: transaction)
                let next: GoalControllerStatusV1
                switch (goal.status, command.transition) {
                case (.active, .pause): next = .paused
                case (.paused, .resume): next = .active
                case (.active, .achieve):
                    let accepted = try Int.fetchOne(
                        transaction,
                        sql: """
                            SELECT COUNT(*) FROM outcome
                            WHERE goalId=? AND contractId=?
                              AND contractVersion=? AND state='accepted'
                            """,
                        arguments: [
                            goal.id, goal.currentOutcomeContractId,
                            goal.currentOutcomeContractVersion,
                        ]
                    ) ?? 0
                    guard accepted > 0 else {
                        throw GoalAchievementPreconditionError()
                    }
                    next = .achieved
                case (.achieved, .reopen): next = .active
                default: throw InvalidGoalTransitionError()
                }
                var updated = goal
                updated.status = next
                updated.aggregateVersion = targetVersion
                updated.updatedAt = command.envelope.occurredAt
                return updated
            }, apply: { transaction, _, result in
                let goal = try requireGoal(
                    command.goal,
                    database: transaction
                )
                try transaction.execute(
                    sql: """
                        UPDATE goal_controller SET status=?,aggregateVersion=?,updatedAt=?
                        WHERE id=? AND campId=? AND aggregateVersion=? AND status=?
                        """,
                    arguments: [
                        result.status.rawValue,
                        result.aggregateVersion,
                        result.updatedAt,
                        goal.id,
                        goal.campId,
                        goal.aggregateVersion, goal.status.rawValue,
                    ]
                )
                guard transaction.changesCount == 1,
                      let updated = try restoredGoal(
                          id: goal.id,
                          database: transaction
                      ), updated == result
                else {
                    throw P1DProjectionConflictError()
                }
            }, validateProjection: { transaction, _, result in
                guard try restoredGoal(
                    id: result.id,
                    database: transaction
                ) == result else {
                    throw P1DProjectionConflictError()
                }
            })
        }
    }

    package func contract(
        ref: OutcomeContractRef
    ) throws -> OutcomeContractSnapshotV1? {
        try database.pool.read { db in
            guard let snapshot = try contract(
                id: ref.id,
                version: ref.version,
                database: db
            ) else { return nil }
            guard snapshot.ref.hash == ref.hash else {
                throw OutcomeContractIntegrityError()
            }
            return snapshot
        }
    }

    package func contractVersions(
        id: String
    ) throws -> [OutcomeContractSnapshotV1] {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            let versions = try Int.fetchAll(
                db,
                sql: """
                    SELECT version FROM outcome_contract_version
                    WHERE id=? ORDER BY version
                    """,
                arguments: [id]
            )
            return try versions.map {
                try requireContract(id: id, version: $0, database: db)
            }
        }
    }

    private func validateContractProjection(
        _ result: OutcomeContractSnapshotV1,
        database: Database
    ) throws {
        guard try requireContract(
            ref: result.ref,
            database: database
        ) == result else {
            throw P1DProjectionConflictError()
        }
    }

    private func validateActivatedGoalProjection(
        _ result: ActivatedGoalV1,
        database: Database
    ) throws {
        guard try restoredGoal(
            id: result.goal.id,
            database: database
        ) == result.goal,
              try restoredLink(
                  missionId: result.link.missionId,
                  database: database
              ) == result.link
        else {
            throw P1DProjectionConflictError()
        }
    }

    private func changeContract(
        commandType: String,
        eventType: String,
        envelope: CommandEnvelopeV1,
        contract: OutcomeContractRef,
        targetStatus: OutcomeContractStatusV1,
        activatedByActorId: String? = nil,
        activatedAt: Date? = nil,
        validate: (OutcomeContractSnapshotV1, Database) throws -> Void
    ) throws -> OutcomeContractSnapshotV1 {
        let payload = ContractStatusPayload(contract: contract)
        return try database.pool.write { db in
            let eventVersion = try commandEventVersion(
                database: db,
                commandKey: envelope.idempotencyKey,
                aggregateType: "outcomeContract",
                aggregateId: contract.id
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: commandType,
                envelope: envelope,
                payload: payload,
                events: [try contractEvent(
                    contractCamp(contract.id, database: db),
                    contract.id,
                    eventVersion,
                    eventType,
                    version: contract.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                let current = try requireContract(
                    ref: contract,
                    database: transaction
                )
                try validate(current, transaction)
                return OutcomeContractSnapshotV1(
                    ref: current.ref,
                    goalId: current.goalId,
                    understanding: current.understanding,
                    body: current.body,
                    status: targetStatus,
                    createdByActorId: current.createdByActorId,
                    activatedByActorId:
                        activatedByActorId ?? current.activatedByActorId,
                    createdAt: current.createdAt,
                    activatedAt: activatedAt ?? current.activatedAt
                )
            }, apply: { transaction, _, result in
                let current = try requireContract(
                    ref: contract,
                    database: transaction
                )
                if targetStatus == .active {
                    try transaction.execute(
                        sql: """
                            UPDATE outcome_contract_version
                            SET status='superseded'
                            WHERE id=? AND status='active' AND version<>?
                            """,
                        arguments: [current.ref.id, current.ref.version]
                    )
                }
                try transaction.execute(
                    sql: """
                        UPDATE outcome_contract_version
                        SET status=?,activatedByActorId=?,activatedAt=?
                        WHERE id=? AND version=? AND contentHash=? AND status=?
                        """,
                    arguments: [
                        result.status.rawValue,
                        result.activatedByActorId,
                        result.activatedAt,
                        current.ref.id,
                        current.ref.version,
                        current.ref.hash,
                        current.status.rawValue,
                    ]
                )
                guard transaction.changesCount == 1,
                      try requireContract(
                          ref: result.ref,
                          database: transaction
                      ) == result
                else {
                    throw P1DProjectionConflictError()
                }
            }, validateProjection: { transaction, _, result in
                try validateContractProjection(result, database: transaction)
            })
        }
    }

    private func contractEvent(
        _ campId: String,
        _ contractId: String,
        _ aggregateVersion: Int,
        _ eventType: String,
        version: Int
    ) throws -> P1DCommandEventShapeV1 {
        try P1DCommandEventShapeV1(
            campId: campId,
            aggregateType: "outcomeContract",
            aggregateId: contractId,
            aggregateVersion: aggregateVersion,
            eventType: eventType,
            payload: .object([
                "contractId": .string(contractId),
                "contractVersion": .number(Double(version)),
            ])
        )
    }

    private func goalEvent(
        _ head: GoalHeadV1,
        version: Int,
        eventType: String
    ) throws -> P1DCommandEventShapeV1 {
        try P1DCommandEventShapeV1(
            campId: head.campId,
            aggregateType: "goal",
            aggregateId: head.goalId,
            aggregateVersion: version,
            eventType: eventType,
            payload: .object([
                "goalId": .string(head.goalId),
                "goalVersion": .number(Double(version)),
            ])
        )
    }

    private func authorizeUser(_ envelope: CommandEnvelopeV1) throws {
        guard envelope.actorType == .user,
              envelope.actorId == P1DActorID.localOwner,
              envelope.deviceId != nil
        else {
            throw P1DCommandAuthorizationError.forbiddenActor
        }
    }

    private func authorizeSystem(
        _ envelope: CommandEnvelopeV1,
        actorId: String
    ) throws {
        guard envelope.actorType == .system,
              envelope.actorId == actorId,
              envelope.deviceId == nil
        else {
            throw P1DCommandAuthorizationError.forbiddenActor
        }
    }

    private func requireGoal(
        _ head: GoalHeadV1,
        database: Database
    ) throws -> GoalControllerRecord {
        guard let goal = try restoredGoal(
            id: head.goalId,
            database: database
        ) else {
            throw GoalActivationError.missingGoal
        }
        guard goal.campId == head.campId else {
            throw GoalActivationError.wrongCamp
        }
        guard goal.aggregateVersion == head.expectedGoalVersion else {
            throw GoalActivationError.staleGoal
        }
        return goal
    }

    private func requireConfirmedUnderstanding(
        _ ref: UnderstandingVersionRefV1,
        goalId: String,
        database: Database
    ) throws {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT goalId,status,contentHash,confirmedByActorId,confirmedAt
                FROM understanding_card_version WHERE id=? AND version=?
                """,
            arguments: [ref.id, ref.version]
        ) else {
            throw OutcomeContractActivationError.staleUnderstanding
        }
        let confirmedAt: Date? = row["confirmedAt"]
        guard row["goalId"] as String == goalId,
              row["status"] as String == UnderstandingStatusV1.confirmed.rawValue,
              row["contentHash"] as String == ref.hash,
              row["confirmedByActorId"] as String? == P1DActorID.localOwner,
              confirmedAt != nil
        else {
            throw OutcomeContractActivationError.unconfirmedUnderstanding
        }
    }

    private func requireMission(
        _ missionId: String,
        campId: String,
        states: Set<MissionStatus>,
        database: Database
    ) throws {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT m.status,s.campId FROM mission m
                JOIN squad s ON s.id=m.squadId WHERE m.id=?
                """,
            arguments: [missionId]
        ),
        row["campId"] as String == campId,
        let state = MissionStatus(rawValue: row["status"] as String),
        states.contains(state)
        else {
            throw GoalActivationError.invalidMission
        }
    }

    private func prepareLink(
        missionId: String,
        goalId: String,
        contract: OutcomeContractRef,
        expectedVersion: Int?,
        now: Date,
        database: Database
    ) throws -> GoalMissionLinkRecordV1 {
        if let existing = try restoredLink(
            missionId: missionId,
            database: database
        ) {
            guard expectedVersion == existing.version,
                  existing.goalId == goalId
            else {
                throw GoalMissionLinkConflictError()
            }
            let next = try CanonicalContractCodingV1.checkedIncrement(
                existing.version
            )
            var updated = existing
            updated.outcomeContractId = contract.id
            updated.outcomeContractVersion = contract.version
            updated.state = .active
            updated.version = next
            updated.updatedAt = now
            return updated
        }
        guard expectedVersion == nil else {
            throw GoalMissionLinkConflictError()
        }
        let link = GoalMissionLinkRecordV1(
            missionId: missionId,
            goalId: goalId,
            outcomeContractId: contract.id,
            outcomeContractVersion: contract.version,
            state: .active,
            version: 1,
            createdAt: now,
            updatedAt: now
        )
        return link
    }

    private func applyPreparedLink(
        _ link: GoalMissionLinkRecordV1,
        expectedVersion: Int?,
        database: Database
    ) throws {
        if let expectedVersion {
            try database.execute(
                sql: """
                    UPDATE goal_mission_link
                    SET outcomeContractId=?,outcomeContractVersion=?,
                        state=?,version=?,updatedAt=?
                    WHERE missionId=? AND goalId=? AND version=?
                    """,
                arguments: [
                    link.outcomeContractId,
                    link.outcomeContractVersion,
                    link.state.rawValue,
                    link.version,
                    link.updatedAt,
                    link.missionId,
                    link.goalId,
                    expectedVersion,
                ]
            )
            guard database.changesCount == 1 else {
                throw GoalMissionLinkConflictError()
            }
        } else {
            try link.insert(database)
        }
        guard try restoredLink(
            missionId: link.missionId,
            database: database
        ) == link else {
            throw GoalMissionLinkConflictError()
        }
    }

    private func restoredGoal(
        id: String,
        database: Database
    ) throws -> GoalControllerRecord? {
        guard var goal = try GoalControllerRecord.fetchOne(
            database,
            key: id
        ) else { return nil }
        goal.createdAt = try P1DTimestampV1.restorePersisted(goal.createdAt)
        goal.updatedAt = try P1DTimestampV1.restorePersisted(goal.updatedAt)
        return goal
    }

    private func restoredLink(
        missionId: String,
        database: Database
    ) throws -> GoalMissionLinkRecordV1? {
        guard var link = try GoalMissionLinkRecordV1.fetchOne(
            database,
            key: missionId
        ) else { return nil }
        link.createdAt = try P1DTimestampV1.restorePersisted(link.createdAt)
        link.updatedAt = try P1DTimestampV1.restorePersisted(link.updatedAt)
        return link
    }

    private func makeContractSnapshot(
        id: String,
        version: Int,
        goalId: String,
        understanding: UnderstandingVersionRefV1,
        body: OutcomeContractBodyV1,
        status: OutcomeContractStatusV1,
        createdByActorId: String,
        activatedByActorId: String?,
        createdAt: Date,
        activatedAt: Date?
    ) throws -> OutcomeContractSnapshotV1 {
        let contentHash = try contractContentHash(
            id: id,
            version: version,
            goalId: goalId,
            understanding: understanding,
            body: body,
            createdByActorId: createdByActorId,
            createdAt: createdAt
        )
        return OutcomeContractSnapshotV1(
            ref: try OutcomeContractRef(
                id: id,
                version: version,
                hash: contentHash
            ),
            goalId: goalId,
            understanding: understanding,
            body: body,
            status: status,
            createdByActorId: createdByActorId,
            activatedByActorId: activatedByActorId,
            createdAt: createdAt,
            activatedAt: activatedAt
        )
    }

    private func insertContract(
        _ contract: OutcomeContractSnapshotV1,
        database: Database
    ) throws {
        let id = contract.ref.id
        let version = contract.ref.version
        let goalId = contract.goalId
        let understanding = contract.understanding
        let body = contract.body
        let status = contract.status
        let createdByActorId = contract.createdByActorId
        let activatedByActorId = contract.activatedByActorId
        let createdAt = contract.createdAt
        let activatedAt = contract.activatedAt
        guard try contractContentHash(
            id: id,
            version: version,
            goalId: goalId,
            understanding: understanding,
            body: body,
            createdByActorId: createdByActorId,
            createdAt: createdAt
        ) == contract.ref.hash else {
            throw OutcomeContractIntegrityError()
        }
        let contentHash = contract.ref.hash
        let groupsJson = try CanonicalContractCodingV1.string(
            body.verificationGroups
        )
        try database.execute(
            sql: """
                INSERT INTO outcome_contract_version(
                  id,version,goalId,understandingId,understandingVersion,
                  understandingHash,outcomeType,deliverablesJson,
                  acceptanceCriteriaJson,verificationRequirementsJson,
                  unacceptableDeviationsJson,requiredDependencyRefsJson,
                  optionalDependencyRefsJson,requiresSubjectiveJudgment,
                  includesPublicRelease,includesPayment,includesDeletion,
                  includesExternalSend,riskClass,acceptanceOwner,
                  acceptancePolicyId,acceptancePolicyVersion,status,contentHash,
                  createdByActorId,activatedByActorId,createdAt,activatedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                id, version, goalId, understanding.id, understanding.version,
                understanding.hash, body.outcomeType,
                try CanonicalContractCodingV1.string(body.deliverables),
                try CanonicalContractCodingV1.string(body.acceptanceCriteria),
                groupsJson,
                try CanonicalContractCodingV1.string(
                    body.unacceptableDeviations
                ),
                try CanonicalContractCodingV1.string(body.requiredDependencies),
                try CanonicalContractCodingV1.string(body.optionalDependencies),
                body.requiresSubjectiveJudgment, body.includesPublicRelease,
                body.includesPayment, body.includesDeletion,
                body.includesExternalSend, body.riskClass.rawValue,
                body.acceptanceOwner.rawValue, body.acceptancePolicy?.id,
                body.acceptancePolicy?.version, status.rawValue, contentHash,
                createdByActorId, activatedByActorId, createdAt, activatedAt,
            ]
        )
        for (groupOrdinal, group) in body.verificationGroups.enumerated() {
            try database.execute(
                sql: """
                    INSERT INTO verification_requirement_group(
                      contractId,contractVersion,groupId,mode,ordinal
                    ) VALUES (?,?,?,?,?)
                    """,
                arguments: [
                    id, version, group.groupId, group.mode.rawValue,
                    groupOrdinal,
                ]
            )
            for (ordinal, requirement) in group.requirements.enumerated() {
                try database.execute(
                    sql: """
                        INSERT INTO verification_requirement(
                          contractId,contractVersion,groupId,requirementId,
                          requirementVersion,ordinal,verifierType,verifierId,
                          method,ruleId,ruleVersion,configJson,requirementHash
                        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
                        """,
                    arguments: [
                        id, version, group.groupId,
                        requirement.requirementId,
                        requirement.requirementVersion, ordinal,
                        requirement.verifierType.rawValue,
                        requirement.verifierId, requirement.method.rawValue,
                        requirement.ruleId, requirement.ruleVersion,
                        try CanonicalContractCodingV1.string(
                            requirement.config
                        ),
                        requirement.requirementHash,
                    ]
                )
            }
        }
    }

    private func contract(
        id: String,
        version: Int,
        database: Database
    ) throws -> OutcomeContractSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM outcome_contract_version WHERE id=? AND version=?
                """,
            arguments: [id, version]
        ) else { return nil }
        let groups = try verificationGroups(
            contractId: id,
            version: version,
            database: database
        )
        let snapshotJson: String = row["verificationRequirementsJson"]
        guard Data(snapshotJson.utf8)
                == (try CanonicalContractCodingV1.encode(groups))
        else {
            throw OutcomeContractIntegrityError()
        }
        let policyID: String? = row["acceptancePolicyId"]
        let policyVersion: Int? = row["acceptancePolicyVersion"]
        let policy: AcceptancePolicyRefV1?
        if let policyID, let policyVersion {
            guard let hash = try String.fetchOne(
                database,
                sql: """
                    SELECT contentHash FROM acceptance_policy_version
                    WHERE id=? AND version=?
                    """,
                arguments: [policyID, policyVersion]
            ) else {
                throw OutcomeContractIntegrityError()
            }
            policy = try AcceptancePolicyRefV1(
                id: policyID,
                version: policyVersion,
                hash: hash
            )
        } else {
            guard policyID == nil, policyVersion == nil else {
                throw OutcomeContractIntegrityError()
            }
            policy = nil
        }
        guard let risk = OutcomeRiskClassV1(rawValue: row["riskClass"]),
              let owner = OutcomeAcceptanceOwnerV1(
                  rawValue: row["acceptanceOwner"]
              ),
              let status = OutcomeContractStatusV1(rawValue: row["status"])
        else {
            throw OutcomeContractIntegrityError()
        }
        let body = try OutcomeContractBodyV1(
            outcomeType: row["outcomeType"],
            deliverables: decode([String].self, row["deliverablesJson"]),
            acceptanceCriteria: decode(
                [String].self,
                row["acceptanceCriteriaJson"]
            ),
            verificationGroups: groups,
            unacceptableDeviations: decode(
                [String].self,
                row["unacceptableDeviationsJson"]
            ),
            requiredDependencies: decode(
                [String].self,
                row["requiredDependencyRefsJson"]
            ),
            optionalDependencies: decode(
                [String].self,
                row["optionalDependencyRefsJson"]
            ),
            requiresSubjectiveJudgment: row["requiresSubjectiveJudgment"],
            includesPublicRelease: row["includesPublicRelease"],
            includesPayment: row["includesPayment"],
            includesDeletion: row["includesDeletion"],
            includesExternalSend: row["includesExternalSend"],
            riskClass: risk,
            acceptanceOwner: owner,
            acceptancePolicy: policy
        )
        let storedHash: String = row["contentHash"]
        let createdAt = try P1DTimestampV1.restorePersisted(
            row["createdAt"] as Date
        )
        let activatedAt = try P1DTimestampV1.restorePersisted(
            row["activatedAt"] as Date?
        )
        let understanding = try UnderstandingVersionRefV1(
            id: row["understandingId"],
            version: row["understandingVersion"],
            hash: row["understandingHash"]
        )
        guard try contractContentHash(
            id: id,
            version: version,
            goalId: row["goalId"],
            understanding: understanding,
            body: body,
            createdByActorId: row["createdByActorId"],
            createdAt: createdAt
        ) == storedHash else {
            throw OutcomeContractIntegrityError()
        }
        return OutcomeContractSnapshotV1(
            ref: try OutcomeContractRef(
                id: id,
                version: version,
                hash: storedHash
            ),
            goalId: row["goalId"],
            understanding: understanding,
            body: body,
            status: status,
            createdByActorId: row["createdByActorId"],
            activatedByActorId: row["activatedByActorId"],
            createdAt: createdAt,
            activatedAt: activatedAt
        )
    }

    private func verificationGroups(
        contractId: String,
        version: Int,
        database: Database
    ) throws -> [VerificationRequirementGroupV1] {
        let groupRows = try Row.fetchAll(
            database,
            sql: """
                SELECT groupId,mode,ordinal FROM verification_requirement_group
                WHERE contractId=? AND contractVersion=? ORDER BY ordinal
                """,
            arguments: [contractId, version]
        )
        return try groupRows.enumerated().map { expectedOrdinal, groupRow in
            guard groupRow["ordinal"] as Int == expectedOrdinal,
                  let mode = VerificationRequirementGroupModeV1(
                      rawValue: groupRow["mode"] as String
                  )
            else {
                throw OutcomeContractIntegrityError()
            }
            let groupId: String = groupRow["groupId"]
            let rows = try Row.fetchAll(
                database,
                sql: """
                    SELECT * FROM verification_requirement
                    WHERE contractId=? AND contractVersion=? AND groupId=?
                    ORDER BY ordinal
                    """,
                arguments: [contractId, version, groupId]
            )
            let requirements = try rows.enumerated().map {
                expectedRequirementOrdinal, row in
                guard row["ordinal"] as Int == expectedRequirementOrdinal,
                      let actor = VerificationActorTypeV1(
                          rawValue: row["verifierType"] as String
                      ),
                      let method = VerificationMethodV1(
                          rawValue: row["method"] as String
                      )
                else {
                    throw OutcomeContractIntegrityError()
                }
                let requirement = try VerificationRequirementV1(
                    requirementId: row["requirementId"],
                    requirementVersion: row["requirementVersion"],
                    verifierType: actor,
                    verifierId: row["verifierId"],
                    method: method,
                    ruleId: row["ruleId"],
                    ruleVersion: row["ruleVersion"],
                    config: decode(
                        [String: JSONValue].self,
                        row["configJson"]
                    )
                )
                guard requirement.requirementHash
                        == row["requirementHash"] as String
                else {
                    throw OutcomeContractIntegrityError()
                }
                return requirement
            }
            return try VerificationRequirementGroupV1(
                groupId: groupId,
                mode: mode,
                requirements: requirements
            )
        }
    }

    private func contractContentHash(
        id: String,
        version: Int,
        goalId: String,
        understanding: UnderstandingVersionRefV1,
        body: OutcomeContractBodyV1,
        createdByActorId: String,
        createdAt: Date
    ) throws -> String {
        try CanonicalContractCodingV1.hash(
            OutcomeContractContentHashMaterial(
                id: id,
                version: version,
                goalId: goalId,
                understanding: understanding,
                body: body,
                createdByActorId: createdByActorId,
                createdAt: createdAt
            )
        )
    }

    private func requireContract(
        ref: OutcomeContractRef,
        database: Database
    ) throws -> OutcomeContractSnapshotV1 {
        let snapshot = try requireContract(
            id: ref.id,
            version: ref.version,
            database: database
        )
        guard snapshot.ref.hash == ref.hash else {
            throw OutcomeContractIntegrityError()
        }
        return snapshot
    }

    private func requireContract(
        id: String,
        version: Int,
        database: Database
    ) throws -> OutcomeContractSnapshotV1 {
        guard let snapshot = try contract(
            id: id,
            version: version,
            database: database
        ) else {
            throw OutcomeContractActivationError.missingContract
        }
        return snapshot
    }

    private func policyExists(
        _ ref: AcceptancePolicyRefV1,
        database: Database
    ) throws -> Bool {
        try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM acceptance_policy_version
                WHERE id=? AND version=? AND contentHash=?
                """,
            arguments: [ref.id, ref.version, ref.hash]
        ) == 1
    }

    private func contractCamp(
        _ contractId: String,
        database: Database
    ) throws -> String {
        guard let camp = try String.fetchOne(
            database,
            sql: """
                SELECT g.campId FROM outcome_contract_version c
                JOIN goal_controller g ON g.id=c.goalId
                WHERE c.id=? LIMIT 1
                """,
            arguments: [contractId]
        ) else {
            throw OutcomeContractActivationError.missingContract
        }
        return camp
    }

    private func nextContractVersion(
        id: String,
        database: Database
    ) throws -> Int {
        try CanonicalContractCodingV1.checkedIncrement(
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COALESCE(MAX(version),0)
                    FROM outcome_contract_version WHERE id=?
                    """,
                arguments: [id]
            ) ?? 0
        )
    }

    private func commandEventVersion(
        database: Database,
        commandKey: String,
        aggregateType: String,
        aggregateId: String
    ) throws -> Int {
        if let stored = try Int.fetchOne(
            database,
            sql: """
                SELECT aggregateVersion FROM domain_event
                WHERE commandIdempotencyKey=? ORDER BY eventOrdinal LIMIT 1
                """,
            arguments: [commandKey]
        ) {
            return stored
        }
        let current = try Int.fetchOne(
            database,
            sql: """
                SELECT COALESCE(MAX(aggregateVersion),0) FROM domain_event
                WHERE aggregateType=? AND aggregateId=?
                """,
            arguments: [aggregateType, aggregateId]
        ) ?? 0
        return try CanonicalContractCodingV1.checkedIncrement(current)
    }

    private func storedResult<T: Codable>(
        _ type: T.Type,
        commandKey: String,
        database: Database
    ) throws -> T? {
        guard let json = try String.fetchOne(
            database,
            sql: """
                SELECT resultJson FROM domain_command_receipt
                WHERE idempotencyKey=?
                """,
            arguments: [commandKey]
        ) else { return nil }
        return try CanonicalContractCodingV1.decode(
            type,
            from: Data(json.utf8)
        )
    }

    private func decode<T: Codable>(_ type: T.Type, _ json: String) throws -> T {
        try CanonicalContractCodingV1.decode(type, from: Data(json.utf8))
    }
}

package struct OutcomeContractIntegrityError: Error, Sendable, Equatable {
    package init() {}
}

private struct CreateContractPayload: Codable {
    let contractId: String
    let goal: GoalHeadV1
    let understanding: UnderstandingVersionRefV1
    let body: OutcomeContractBodyV1
}

private struct OutcomeContractContentHashMaterial: Codable {
    let id: String
    let version: Int
    let goalId: String
    let understanding: UnderstandingVersionRefV1
    let body: OutcomeContractBodyV1
    let createdByActorId: String
    let createdAt: Date
}

private struct ReviseContractPayload: Codable {
    let contract: OutcomeContractRef
    let body: OutcomeContractBodyV1
}

private struct ContractStatusPayload: Codable {
    let contract: OutcomeContractRef
}

private struct GoalActivationPayload: Codable {
    let goal: GoalHeadV1
    let contract: OutcomeContractRef
    let missionId: String
    let expectedLinkVersion: Int?
}

private struct LinkMissionPayload: Codable {
    let goal: GoalHeadV1
    let contract: OutcomeContractRef
    let missionId: String
    let expectedLinkVersion: Int?
}

private struct GoalTransitionPayload: Codable {
    let goal: GoalHeadV1
    let transition: GoalStatusTransitionV1
}

// MARK: - P1-D Outcome and verification

extension OutcomeStore {
    package func recordInitialOutcome(
        _ command: RecordInitialOutcomeCommandV1
    ) throws -> OutcomeSnapshotV1 {
        try authorizeProducer(
            command.envelope,
            producerActorId: command.producerActorId
        )
        let payload = InitialOutcomePayload(
            outcomeId: command.outcomeId,
            goal: command.goal,
            contract: command.contract,
            missionId: command.missionId,
            producerActorId: command.producerActorId,
            runIds: command.runIds,
            manifest: command.manifest
        )
        return try database.pool.write { db in
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "outcome.record-initial.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: command.goal.campId,
                    outcomeId: command.outcomeId,
                    aggregateVersion: 1,
                    eventType: "outcome.initial-recorded.v1",
                    state: .produced,
                    outcomeVersion: 1
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    guard try Int.fetchOne(
                        transaction,
                        sql: "SELECT COUNT(*) FROM outcome WHERE id=?",
                        arguments: [command.outcomeId]
                    ) == 0 else {
                        throw InvalidInitialOutcomeError()
                    }
                    let goal = try requireGoal(
                        command.goal,
                        database: transaction
                    )
                    guard goal.status == .active,
                          goal.currentOutcomeContractId == command.contract.id,
                          goal.currentOutcomeContractVersion
                            == command.contract.version
                    else {
                        throw InvalidInitialOutcomeError()
                    }
                    let contract = try requireContract(
                        ref: command.contract,
                        database: transaction
                    )
                    guard contract.status == .active,
                          contract.goalId == goal.id
                    else {
                        throw InvalidInitialOutcomeError()
                    }
                    try requireLinkedMissionForOutcome(
                        missionId: command.missionId,
                        goalId: goal.id,
                        campId: goal.campId,
                        contract: contract.ref,
                        database: transaction
                    )
                    let version = try makeOutcomeVersion(
                        outcomeId: command.outcomeId,
                        version: 1,
                        contract: contract.ref,
                        producerActorId: command.producerActorId,
                        runIds: command.runIds,
                        manifest: command.manifest,
                        createdAt: command.envelope.occurredAt
                    )
                    return OutcomeSnapshotV1(
                        id: command.outcomeId,
                        goalId: goal.id,
                        missionId: command.missionId,
                        contract: contract.ref,
                        currentVersion: 1,
                        state: .produced,
                        aggregateVersion: 1,
                        createdAt: command.envelope.occurredAt,
                        updatedAt: command.envelope.occurredAt,
                        version: version
                    )
                },
                apply: { transaction, _, result in
                    try transaction.execute(
                        sql: """
                            INSERT INTO outcome(
                              id,goalId,missionId,contractId,contractVersion,
                              contractHash,currentVersion,state,aggregateVersion,
                              createdAt,updatedAt
                            ) VALUES (?,?,?,?,?,?,1,'produced',1,?,?)
                            """,
                        arguments: [
                            result.id, result.goalId, result.missionId,
                            result.contract.id, result.contract.version,
                            result.contract.hash, result.createdAt,
                            result.updatedAt,
                        ]
                    )
                    try insertOutcomeVersion(result.version, database: transaction)
                },
                validateProjection: { transaction, _, result in
                    try validateOutcomeProjection(result, database: transaction)
                }
            )
        }
    }

    package func recordNewOutcomeVersion(
        _ command: RecordNewOutcomeVersionCommandV1
    ) throws -> OutcomeSnapshotV1 {
        try authorizeProducer(
            command.envelope,
            producerActorId: command.producerActorId
        )
        let payload = NewOutcomeVersionPayload(
            outcome: command.outcome,
            expectedAggregateVersion: command.expectedAggregateVersion,
            producerActorId: command.producerActorId,
            runIds: command.runIds,
            manifest: command.manifest
        )
        return try database.pool.write { db in
            let eventVersion = try storedOutcomeEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    command.expectedAggregateVersion
                ),
                database: db
            )
            let campId = try outcomeCamp(command.outcome.id, database: db)
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "outcome.record-new-version.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: campId,
                    outcomeId: command.outcome.id,
                    aggregateVersion: eventVersion,
                    eventType: "outcome.new-version-recorded.v1",
                    state: .verificationPending,
                    outcomeVersion: try CanonicalContractCodingV1
                        .checkedIncrement(command.outcome.version)
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedAggregateVersion,
                        database: transaction
                    )
                    let edge = OutcomeTransitionEdgeV1(
                        command: .recordNewOutcomeVersion,
                        from: current.state,
                        to: .verificationPending
                    )
                    guard OutcomeTransitionPolicyV1.allows(edge) else {
                        throw InvalidOutcomeTransitionError()
                    }
                    let nextVersion = try CanonicalContractCodingV1
                        .checkedIncrement(current.currentVersion)
                    let nextAggregate = try CanonicalContractCodingV1
                        .checkedIncrement(current.aggregateVersion)
                    let version = try makeOutcomeVersion(
                        outcomeId: current.id,
                        version: nextVersion,
                        contract: current.contract,
                        producerActorId: command.producerActorId,
                        runIds: command.runIds,
                        manifest: command.manifest,
                        createdAt: command.envelope.occurredAt
                    )
                    return OutcomeSnapshotV1(
                        id: current.id,
                        goalId: current.goalId,
                        missionId: current.missionId,
                        contract: current.contract,
                        currentVersion: nextVersion,
                        state: .verificationPending,
                        aggregateVersion: nextAggregate,
                        createdAt: current.createdAt,
                        updatedAt: command.envelope.occurredAt,
                        version: version
                    )
                },
                apply: { transaction, eventIDs, result in
                    let oldHeads = try Row.fetchAll(
                        transaction,
                        sql: """
                            SELECT currentVerificationId
                            FROM verification_result_head
                            WHERE outcomeId=? AND outcomeVersion=?
                            ORDER BY requirementId,requirementVersion
                            """,
                        arguments: [result.id, command.outcome.version]
                    )
                    for row in oldHeads {
                        let verificationId: String = row["currentVerificationId"]
                        try insertInvalidation(
                            verificationId: verificationId,
                            reasonCode: "outcome_version_superseded",
                            dependency: VerificationDependencyRefV1(
                                type: "outcomeVersion",
                                id: result.id,
                                version: result.currentVersion,
                                hash: result.currentRef.hash
                            ),
                            eventId: eventIDs[0],
                            createdAt: command.envelope.occurredAt,
                            database: transaction
                        )
                        try transaction.execute(
                            sql: """
                                UPDATE verification_result_head
                                SET derivedResult='invalid',version=version+1,
                                    updatedAt=?
                                WHERE currentVerificationId=?
                                """,
                            arguments: [
                                command.envelope.occurredAt, verificationId,
                            ]
                        )
                        guard transaction.changesCount == 1 else {
                            throw VerificationHeadConflictError()
                        }
                    }
                    _ = try memoryStore.applyInvalidation(
                        .outcomeSuperseded(
                            outcomeId: result.id,
                            outcomeVersion: command.outcome.version
                        ),
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                    try insertOutcomeVersion(result.version, database: transaction)
                    try transaction.execute(
                        sql: """
                            UPDATE outcome
                            SET currentVersion=?,state='verificationPending',
                                aggregateVersion=?,updatedAt=?
                            WHERE id=? AND currentVersion=? AND aggregateVersion=?
                            """,
                        arguments: [
                            result.currentVersion, result.aggregateVersion,
                            result.updatedAt, result.id, command.outcome.version,
                            command.expectedAggregateVersion,
                        ]
                    )
                    guard transaction.changesCount == 1 else {
                        throw P1DProjectionConflictError()
                    }
                    try reopenGoalAndMissionIfNeeded(
                        outcome: result,
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                    try reverseMetricIfActive(
                        outcomeId: result.id,
                        eventId: eventIDs[0],
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateOutcomeProjection(result, database: transaction)
                }
            )
        }
    }

    package func beginVerification(
        _ command: BeginVerificationCommandV1
    ) throws -> OutcomeSnapshotV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.verification
        )
        let payload = BeginVerificationPayload(
            outcome: command.outcome,
            expectedAggregateVersion: command.expectedAggregateVersion
        )
        return try database.pool.write { db in
            let targetVersion = try storedOutcomeEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    command.expectedAggregateVersion
                ),
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "outcome.begin-verification.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: outcomeCamp(command.outcome.id, database: db),
                    outcomeId: command.outcome.id,
                    aggregateVersion: targetVersion,
                    eventType: "outcome.verification-began.v1",
                    state: .verificationPending,
                    outcomeVersion: command.outcome.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedAggregateVersion,
                        database: transaction
                    )
                    guard OutcomeTransitionPolicyV1.allows(.init(
                        command: .beginVerification,
                        from: current.state,
                        to: .verificationPending
                    )) else {
                        throw InvalidOutcomeTransitionError()
                    }
                    return OutcomeSnapshotV1(
                        id: current.id,
                        goalId: current.goalId,
                        missionId: current.missionId,
                        contract: current.contract,
                        currentVersion: current.currentVersion,
                        state: .verificationPending,
                        aggregateVersion: targetVersion,
                        createdAt: current.createdAt,
                        updatedAt: command.envelope.occurredAt,
                        version: current.version
                    )
                },
                apply: { transaction, _, result in
                    try updateOutcomeHead(
                        result,
                        expectedVersion: command.expectedAggregateVersion,
                        expectedState: nil,
                        database: transaction
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateOutcomeProjection(result, database: transaction)
                }
            )
        }
    }

    package func outcome(id: String) throws -> OutcomeSnapshotV1? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try outcome(id: id, database: db)
        }
    }

    package func outcome(missionId: String) throws -> OutcomeSnapshotV1? {
        try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        return try database.pool.read { db in
            let ids = try String.fetchAll(
                db,
                sql: "SELECT id FROM outcome WHERE missionId=? ORDER BY id",
                arguments: [missionId]
            )
            guard ids.count <= 1 else {
                throw OutcomeReferenceMismatchError()
            }
            guard let id = ids.first else { return nil }
            return try outcome(id: id, database: db)
        }
    }

    package func missionHasActiveContractLink(
        missionId: String
    ) throws -> Bool {
        try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        return try database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM goal_mission_link
                    WHERE missionId=? AND state='active'
                      AND outcomeContractId IS NOT NULL
                      AND outcomeContractVersion IS NOT NULL
                    """,
                arguments: [missionId]
            ) == 1
        }
    }

    package func outcomeVersions(
        id: String
    ) throws -> [OutcomeVersionSnapshotV1] {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            let versions = try Int.fetchAll(
                db,
                sql: "SELECT version FROM outcome_version WHERE outcomeId=? ORDER BY version",
                arguments: [id]
            )
            return try versions.map {
                try requireOutcomeVersion(
                    outcomeId: id,
                    version: $0,
                    database: db
                )
            }
        }
    }

    package func invalidationCount(
        outcomeId: String,
        version: Int
    ) throws -> Int {
        try database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM verification_invalidation i
                    JOIN verification_record r ON r.id=i.verificationId
                    WHERE r.outcomeId=? AND r.outcomeVersion=?
                    """,
                arguments: [outcomeId, version]
            ) ?? 0
        }
    }
}

extension OutcomeStore {
    private func reducedOutcomeState(
        _ outcome: OutcomeSnapshotV1,
        replacing replacement: VerificationRecordSnapshotV1? = nil,
        database: Database
    ) throws -> OutcomeStateV1 {
        let contract = try requireContract(
            ref: outcome.contract,
            database: database
        )
        var anyBlocked = false
        var anyFailed = false
        var deterministicPass = false
        var everyGroupSatisfied = true
        for group in contract.body.verificationGroups {
            var results: [Bool] = []
            for requirement in group.requirements {
                if let replacement,
                   replacement.requirement.contract == outcome.contract,
                   replacement.requirement.requirementId
                    == requirement.requirementId,
                   replacement.requirement.requirementVersion
                    == requirement.requirementVersion,
                   replacement.requirement.requirementHash
                    == requirement.requirementHash,
                   replacement.outcome == outcome.currentRef
                {
                    let passed = replacement.result == .passed
                    results.append(passed)
                    if replacement.result == .blocked {
                        anyBlocked = true
                    }
                    if replacement.result == .failed {
                        anyFailed = true
                    }
                    if passed
                        && requirement.verifierType == .deterministic
                    {
                        deterministicPass = true
                    }
                    continue
                }
                let row = try Row.fetchOne(
                    database,
                    sql: """
                        SELECT h.derivedResult,r.contractHash,
                               r.requirementHash,r.outcomeHash,r.verifierType,
                               r.verifierId,r.method,r.ruleId,r.ruleVersion,
                               r.result,r.id
                        FROM verification_result_head h
                        JOIN verification_record r
                          ON r.id=h.currentVerificationId
                        WHERE h.outcomeId=? AND h.outcomeVersion=?
                          AND h.contractId=? AND h.contractVersion=?
                          AND h.requirementId=? AND h.requirementVersion=?
                        """,
                    arguments: [
                        outcome.id, outcome.currentVersion,
                        outcome.contract.id, outcome.contract.version,
                        requirement.requirementId,
                        requirement.requirementVersion,
                    ]
                )
                guard let row else {
                    results.append(false)
                    continue
                }
                let invalidations = try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM verification_invalidation
                        WHERE verificationId=?
                        """,
                    arguments: [row["id"] as String]
                ) ?? 0
                let derivedRaw: String = row["derivedResult"]
                let exact = row["contractHash"] as String
                        == outcome.contract.hash
                    && row["requirementHash"] as String
                        == requirement.requirementHash
                    && row["outcomeHash"] as String == outcome.currentRef.hash
                    && row["verifierType"] as String
                        == requirement.verifierType.rawValue
                    && row["verifierId"] as String == requirement.verifierId
                    && row["method"] as String == requirement.method.rawValue
                    && row["ruleId"] as String == requirement.ruleId
                    && row["ruleVersion"] as Int == requirement.ruleVersion
                    && invalidations == 0
                let passed = exact
                    && derivedRaw == VerificationResultV1.passed.rawValue
                    && row["result"] as String
                        == VerificationResultV1.passed.rawValue
                results.append(passed)
                if exact,
                   derivedRaw == VerificationResultV1.blocked.rawValue
                {
                    anyBlocked = true
                }
                if exact,
                   derivedRaw == VerificationResultV1.failed.rawValue
                {
                    anyFailed = true
                }
                if passed && requirement.verifierType == .deterministic {
                    deterministicPass = true
                }
            }
            let satisfied: Bool
            switch group.mode {
            case .all: satisfied = results.allSatisfy { $0 }
            case .any: satisfied = results.contains(true)
            }
            if !satisfied { everyGroupSatisfied = false }
        }
        if everyGroupSatisfied
            && (contract.body.outcomeType != "coding" || deterministicPass)
        {
            return .verified
        }
        if anyBlocked { return .blocked }
        if anyFailed { return .verificationFailed }
        return .verificationPending
    }

    private func insertInvalidation(
        verificationId: String,
        reasonCode: String,
        dependency: VerificationDependencyRefV1,
        eventId: String,
        createdAt: Date,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO verification_invalidation(
                  id,verificationId,reasonCode,dependencyType,dependencyId,
                  dependencyVersion,dependencyHash,eventId,createdAt
                ) VALUES (?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                UUID().uuidString, verificationId, reasonCode,
                dependency.type, dependency.id, dependency.version,
                dependency.hash, eventId, createdAt,
            ]
        )
    }

    private func currentInvalidationCount(
        outcome: OutcomeSnapshotV1,
        database: Database
    ) throws -> Int {
        try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM verification_invalidation i
                JOIN verification_result_head h
                  ON h.currentVerificationId=i.verificationId
                WHERE h.outcomeId=? AND h.outcomeVersion=?
                """,
            arguments: [outcome.id, outcome.currentVersion]
        ) ?? 0
    }

    private func manifestIsReadable(
        _ manifest: [OutcomeArtifactRefV1]
    ) throws -> Bool {
        guard !manifest.isEmpty else { return false }
        let verifier = ArtifactHashVerifier()
        for artifact in manifest {
            switch artifact.kind {
            case .file:
                guard try verifier.verify(
                    path: artifact.locator,
                    expectedHash: artifact.contentHash
                ).result == .passed else {
                    return false
                }
            case .externalReceipt:
                try CanonicalContractCodingV1.validateNonempty(
                    artifact.locator
                )
            }
        }
        return true
    }
}

private struct OutcomeVersionHashMaterial: Codable {
    let outcomeId: String
    let version: Int
    let contract: OutcomeContractRef
    let producerActorId: String
    let runIds: [String]
    let manifest: [OutcomeArtifactRefV1]
}

private struct InitialOutcomePayload: Codable {
    let outcomeId: String
    let goal: GoalHeadV1
    let contract: OutcomeContractRef
    let missionId: String
    let producerActorId: String
    let runIds: [String]
    let manifest: [OutcomeArtifactRefV1]
}

private struct NewOutcomeVersionPayload: Codable {
    let outcome: OutcomeRefV1
    let expectedAggregateVersion: Int
    let producerActorId: String
    let runIds: [String]
    let manifest: [OutcomeArtifactRefV1]
}

private struct BeginVerificationPayload: Codable {
    let outcome: OutcomeRefV1
    let expectedAggregateVersion: Int
}

private struct VerificationCommandPayload: Codable {
    let verificationId: String
    let requirement: VerificationRequirementRefV1
    let outcome: OutcomeRefV1
    let expectedOutcomeAggregateVersion: Int
    let expectedCurrentVerificationId: String?
    let environment: [String: JSONValue]
    let commandOrRule: [String: JSONValue]
    let rawResultRef: String?
    let result: VerificationResultV1
    let evidenceHash: String
}

private struct InvalidationCommandPayload: Codable {
    let outcome: OutcomeRefV1
    let expectedOutcomeAggregateVersion: Int
    let verificationIds: [String]
    let reasonCode: String
    let dependency: VerificationDependencyRefV1
}

private struct DependencyInvalidationCommandPayload: Codable {
    let campId: String
    let reasonCode: String
    let dependency: VerificationDependencyRefV1
}

private struct DeliveryCommandPayload: Codable {
    let outcome: OutcomeRefV1
    let expectedAggregateVersion: Int
}

extension OutcomeStore {
    private func authorizeProducer(
        _ envelope: CommandEnvelopeV1,
        producerActorId: String
    ) throws {
        guard (envelope.actorType == .cow || envelope.actorType == .engine),
              envelope.actorId == producerActorId,
              envelope.deviceId == nil
        else {
            throw P1DCommandAuthorizationError.forbiddenActor
        }
    }

    private func authorizeVerifier(
        _ envelope: CommandEnvelopeV1,
        requirement: VerificationRequirementV1
    ) throws {
        switch requirement.verifierType {
        case .deterministic:
            guard envelope.actorType == .system,
                  envelope.actorId == requirement.verifierId,
                  envelope.deviceId == nil
            else {
                throw VerificationActorMismatchError()
            }
        case .cow:
            guard envelope.actorType == .cow,
                  envelope.actorId == requirement.verifierId,
                  envelope.deviceId == nil
            else {
                throw VerificationActorMismatchError()
            }
        }
    }

    private func requireLinkedMissionForOutcome(
        missionId: String,
        goalId: String,
        campId: String,
        contract: OutcomeContractRef,
        database: Database
    ) throws {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT m.status,s.campId,l.goalId,l.outcomeContractId,
                       l.outcomeContractVersion,l.state
                FROM mission m
                JOIN squad s ON s.id=m.squadId
                JOIN goal_mission_link l ON l.missionId=m.id
                WHERE m.id=?
                """,
            arguments: [missionId]
        ),
        row["campId"] as String == campId,
        row["goalId"] as String == goalId,
        row["outcomeContractId"] as String? == contract.id,
        row["outcomeContractVersion"] as Int? == contract.version,
        row["state"] as String == GoalMissionLinkStateV1.active.rawValue,
        let missionState = MissionStatus(rawValue: row["status"] as String),
        missionState == .executing || missionState == .delivering
        else {
            throw InvalidInitialOutcomeError()
        }
    }

    private func makeOutcomeVersion(
        outcomeId: String,
        version: Int,
        contract: OutcomeContractRef,
        producerActorId: String,
        runIds: [String],
        manifest: [OutcomeArtifactRefV1],
        createdAt: Date
    ) throws -> OutcomeVersionSnapshotV1 {
        let material = OutcomeVersionHashMaterial(
            outcomeId: outcomeId,
            version: version,
            contract: contract,
            producerActorId: producerActorId,
            runIds: runIds,
            manifest: manifest
        )
        return OutcomeVersionSnapshotV1(
            ref: try OutcomeRefV1(
                id: outcomeId,
                version: version,
                hash: CanonicalContractCodingV1.hash(material)
            ),
            contract: contract,
            producerActorId: producerActorId,
            runIds: runIds,
            manifest: manifest,
            createdAt: createdAt
        )
    }

    private func insertOutcomeVersion(
        _ version: OutcomeVersionSnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO outcome_version(
                  outcomeId,version,contractId,contractVersion,contractHash,
                  producerActorId,runIdsJson,manifestJson,contentHash,createdAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                version.ref.id, version.ref.version, version.contract.id,
                version.contract.version, version.contract.hash,
                version.producerActorId,
                try CanonicalContractCodingV1.string(version.runIds),
                try CanonicalContractCodingV1.string(version.manifest),
                version.ref.hash, version.createdAt,
            ]
        )
    }

    private func outcome(
        id: String,
        database: Database
    ) throws -> OutcomeSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM outcome WHERE id=?",
            arguments: [id]
        ) else { return nil }
        guard let state = OutcomeStateV1(rawValue: row["state"]) else {
            throw OutcomeReferenceMismatchError()
        }
        let contract = try OutcomeContractRef(
            id: row["contractId"],
            version: row["contractVersion"],
            hash: row["contractHash"]
        )
        let currentVersion: Int = row["currentVersion"]
        let version = try requireOutcomeVersion(
            outcomeId: id,
            version: currentVersion,
            database: database
        )
        guard version.contract == contract else {
            throw OutcomeReferenceMismatchError()
        }
        return OutcomeSnapshotV1(
            id: id,
            goalId: row["goalId"],
            missionId: row["missionId"],
            contract: contract,
            currentVersion: currentVersion,
            state: state,
            aggregateVersion: row["aggregateVersion"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"],
            version: version
        )
    }

    private func validateOutcomeProjection(
        _ result: OutcomeSnapshotV1,
        database: Database
    ) throws {
        guard try outcome(id: result.id, database: database) == result else {
            throw P1DProjectionConflictError()
        }
    }

    private func requireOutcomeVersion(
        outcomeId: String,
        version: Int,
        database: Database
    ) throws -> OutcomeVersionSnapshotV1 {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM outcome_version
                WHERE outcomeId=? AND version=?
                """,
            arguments: [outcomeId, version]
        ) else {
            throw OutcomeReferenceMismatchError()
        }
        let contract = try OutcomeContractRef(
            id: row["contractId"],
            version: row["contractVersion"],
            hash: row["contractHash"]
        )
        let runIds: [String] = try decode(
            [String].self,
            row["runIdsJson"]
        )
        let manifest: [OutcomeArtifactRefV1] = try decode(
            [OutcomeArtifactRefV1].self,
            row["manifestJson"]
        )
        let producer: String = row["producerActorId"]
        let storedHash: String = row["contentHash"]
        let material = OutcomeVersionHashMaterial(
            outcomeId: outcomeId,
            version: version,
            contract: contract,
            producerActorId: producer,
            runIds: runIds,
            manifest: manifest
        )
        guard try CanonicalContractCodingV1.hash(material) == storedHash else {
            throw OutcomeReferenceMismatchError()
        }
        return OutcomeVersionSnapshotV1(
            ref: try OutcomeRefV1(
                id: outcomeId,
                version: version,
                hash: storedHash
            ),
            contract: contract,
            producerActorId: producer,
            runIds: runIds,
            manifest: manifest,
            createdAt: row["createdAt"]
        )
    }

    private func requireOutcome(
        ref: OutcomeRefV1,
        expectedAggregateVersion: Int,
        database: Database
    ) throws -> OutcomeSnapshotV1 {
        guard let current = try outcome(id: ref.id, database: database),
              current.currentRef == ref,
              current.aggregateVersion == expectedAggregateVersion
        else {
            throw OutcomeReferenceMismatchError()
        }
        return current
    }

    private func updateOutcomeHead(
        _ result: OutcomeSnapshotV1,
        expectedVersion: Int,
        expectedState: OutcomeStateV1?,
        database: Database
    ) throws {
        var sql = """
            UPDATE outcome SET state=?,aggregateVersion=?,updatedAt=?
            WHERE id=? AND currentVersion=? AND aggregateVersion=?
            """
        var arguments: StatementArguments = [
            result.state.rawValue, result.aggregateVersion, result.updatedAt,
            result.id, result.currentVersion, expectedVersion,
        ]
        if let expectedState {
            sql += " AND state=?"
            arguments += [expectedState.rawValue]
        }
        try database.execute(sql: sql, arguments: arguments)
        guard database.changesCount == 1 else {
            throw P1DProjectionConflictError()
        }
    }

    private func outcomeCamp(
        _ outcomeId: String,
        database: Database
    ) throws -> String {
        guard let campId = try String.fetchOne(
            database,
            sql: """
                SELECT g.campId FROM outcome o
                JOIN goal_controller g ON g.id=o.goalId WHERE o.id=?
                """,
            arguments: [outcomeId]
        ) else {
            throw OutcomeReferenceMismatchError()
        }
        return campId
    }

    private func storedOutcomeEventVersion(
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

    private func storedVerificationEventState(
        commandKey: String,
        outcome: OutcomeRefV1,
        database: Database
    ) throws -> OutcomeStateV1 {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT aggregateId,eventType,eventOrdinal,payloadJson,payloadHash
                FROM domain_event
                WHERE commandIdempotencyKey=?
                """,
            arguments: [commandKey]
        ), row["aggregateId"] as String == outcome.id,
           row["eventType"] as String == "verification.recorded.v1",
           row["eventOrdinal"] as Int == 0
        else {
            throw DomainCommandGraphIntegrityError()
        }
        let payloadJSON: String = row["payloadJson"]
        let payloadBytes = Data(payloadJSON.utf8)
        let payloadHash: String = row["payloadHash"]
        guard CanonicalJSONV1.sha256Hex(payloadBytes) == payloadHash,
              let payload = try CanonicalContractCodingV1.decode(
                  JSONValue.self,
                  from: payloadBytes
              ).objectValue,
              Set(payload.keys) == ["outcomeId", "outcomeVersion", "state"],
              payload["outcomeId"]?.stringValue == outcome.id,
              payload["outcomeVersion"]?.intValue == outcome.version,
              let stateRaw = payload["state"]?.stringValue,
              let state = OutcomeStateV1(rawValue: stateRaw)
        else {
            throw DomainCommandGraphIntegrityError()
        }
        return state
    }

    private func outcomeEvent(
        campId: String,
        outcomeId: String,
        aggregateVersion: Int,
        eventType: String,
        state: OutcomeStateV1,
        outcomeVersion: Int
    ) throws -> P1DCommandEventShapeV1 {
        try P1DCommandEventShapeV1(
            campId: campId,
            aggregateType: "outcome",
            aggregateId: outcomeId,
            aggregateVersion: aggregateVersion,
            eventType: eventType,
            payload: .object([
                "outcomeId": .string(outcomeId),
                "outcomeVersion": .number(Double(outcomeVersion)),
                "state": .string(state.rawValue),
            ])
        )
    }

    private func requireVerificationRequirement(
        _ ref: VerificationRequirementRefV1,
        database: Database
    ) throws -> VerificationRequirementV1 {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT r.*,c.contentHash AS contractHash
                FROM verification_requirement r
                JOIN outcome_contract_version c
                  ON c.id=r.contractId AND c.version=r.contractVersion
                WHERE r.contractId=? AND r.contractVersion=?
                  AND r.requirementId=? AND r.requirementVersion=?
                """,
            arguments: [
                ref.contract.id, ref.contract.version, ref.requirementId,
                ref.requirementVersion,
            ]
        ),
        row["contractHash"] as String == ref.contract.hash,
        row["requirementHash"] as String == ref.requirementHash,
        let actor = VerificationActorTypeV1(
            rawValue: row["verifierType"] as String
        ),
        let method = VerificationMethodV1(rawValue: row["method"] as String)
        else {
            throw VerificationReferenceMismatchError()
        }
        let requirement = try VerificationRequirementV1(
            requirementId: row["requirementId"],
            requirementVersion: row["requirementVersion"],
            verifierType: actor,
            verifierId: row["verifierId"],
            method: method,
            ruleId: row["ruleId"],
            ruleVersion: row["ruleVersion"],
            config: decode([String: JSONValue].self, row["configJson"])
        )
        guard requirement.requirementHash == ref.requirementHash else {
            throw VerificationReferenceMismatchError()
        }
        return requirement
    }

    private func currentVerificationHead(
        outcomeId: String,
        outcomeVersion: Int,
        requirement: VerificationRequirementRefV1,
        database: Database
    ) throws -> String? {
        try String.fetchOne(
            database,
            sql: """
                SELECT currentVerificationId FROM verification_result_head
                WHERE outcomeId=? AND outcomeVersion=? AND contractId=?
                  AND contractVersion=? AND requirementId=?
                  AND requirementVersion=?
                """,
            arguments: [
                outcomeId, outcomeVersion, requirement.contract.id,
                requirement.contract.version, requirement.requirementId,
                requirement.requirementVersion,
            ]
        )
    }

    private func prepareVerificationRecord(
        _ command: RecordVerificationCommandV1,
        database: Database
    ) throws -> VerificationRecordSnapshotV1 {
        let current: OutcomeSnapshotV1
        do {
            current = try requireOutcome(
                ref: command.outcome,
                expectedAggregateVersion:
                    command.expectedOutcomeAggregateVersion,
                database: database
            )
        } catch is OutcomeReferenceMismatchError {
            throw VerificationReferenceMismatchError()
        }
        let requirement = try requireVerificationRequirement(
            command.requirement,
            database: database
        )
        try authorizeVerifier(
            command.envelope,
            requirement: requirement
        )
        guard current.contract == command.requirement.contract,
              current.currentRef == command.outcome
        else {
            throw VerificationReferenceMismatchError()
        }
        if requirement.verifierType == .cow,
           requirement.verifierId == current.version.producerActorId
        {
            throw VerificationProducerConflictError()
        }
        let currentHead = try currentVerificationHead(
            outcomeId: current.id,
            outcomeVersion: current.currentVersion,
            requirement: command.requirement,
            database: database
        )
        guard currentHead == command.expectedCurrentVerificationId else {
            throw VerificationHeadConflictError()
        }
        guard [.verificationPending, .verificationFailed, .blocked]
            .contains(current.state)
        else {
            throw InvalidOutcomeTransitionError()
        }
        return VerificationRecordSnapshotV1(
            id: command.verificationId,
            commandIdempotencyKey: command.envelope.idempotencyKey,
            requirement: command.requirement,
            outcome: command.outcome,
            verifierType: requirement.verifierType,
            verifierId: requirement.verifierId,
            method: requirement.method,
            ruleId: requirement.ruleId,
            ruleVersion: requirement.ruleVersion,
            environment: command.environment,
            commandOrRule: command.commandOrRule,
            rawResultRef: command.rawResultRef,
            evidenceHash: command.evidenceHash,
            result: command.result,
            supersedesVerificationId: currentHead,
            createdAt: command.envelope.occurredAt
        )
    }

    private func prepareDependencyInvalidation(
        _ command: DeleteOrInvalidateDependencyCommandV1,
        database: Database
    ) throws -> DependencyInvalidationResultV1 {
        let outcomeIds = try String.fetchAll(
            database,
            sql: """
                SELECT DISTINCT o.id
                FROM outcome o
                JOIN goal_controller g ON g.id=o.goalId
                JOIN verification_result_head h
                  ON h.outcomeId=o.id
                 AND h.outcomeVersion=o.currentVersion
                WHERE g.campId=? AND h.derivedResult<>'invalid'
                ORDER BY o.id
                """,
            arguments: [command.campId]
        )
        var verificationIds: [String] = []
        var outcomes: [OutcomeSnapshotV1] = []
        for outcomeId in outcomeIds {
            guard let current = try outcome(
                id: outcomeId,
                database: database
            ), current.id == outcomeId,
               current.currentRef.id == outcomeId
            else {
                throw OutcomeReferenceMismatchError()
            }
            let contract = try requireContract(
                ref: current.contract,
                database: database
            )
            let dependencies = Set(
                contract.body.requiredDependencies
                    + contract.body.optionalDependencies
            )
            guard dependencies.contains(command.dependency.id) else {
                continue
            }
            let currentIds = try String.fetchAll(
                database,
                sql: """
                    SELECT currentVerificationId
                    FROM verification_result_head
                    WHERE outcomeId=? AND outcomeVersion=?
                      AND contractId=? AND contractVersion=?
                      AND derivedResult<>'invalid'
                    ORDER BY requirementId,requirementVersion
                    """,
                arguments: [
                    current.id,
                    current.currentVersion,
                    current.contract.id,
                    current.contract.version,
                ]
            )
            for verificationId in currentIds {
                guard try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM verification_record
                        WHERE id=? AND outcomeId=? AND outcomeVersion=?
                          AND contractId=? AND contractVersion=?
                          AND contractHash=? AND outcomeHash=?
                        """,
                    arguments: [
                        verificationId,
                        current.id,
                        current.currentVersion,
                        current.contract.id,
                        current.contract.version,
                        current.contract.hash,
                        current.currentRef.hash,
                    ]
                ) == 1,
                try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*) FROM verification_invalidation
                        WHERE verificationId=?
                        """,
                    arguments: [verificationId]
                ) == 0 else {
                    throw VerificationReferenceMismatchError()
                }
                verificationIds.append(verificationId)
            }
            guard !currentIds.isEmpty else { continue }
            let target: OutcomeStateV1 = current.state == .accepted
                ? .invalidated : .verificationPending
            guard OutcomeTransitionPolicyV1.allows(.init(
                command: .invalidateVerification,
                from: current.state,
                to: target
            )) else {
                throw InvalidOutcomeTransitionError()
            }
            outcomes.append(OutcomeSnapshotV1(
                id: current.id,
                goalId: current.goalId,
                missionId: current.missionId,
                contract: current.contract,
                currentVersion: current.currentVersion,
                state: target,
                aggregateVersion: try CanonicalContractCodingV1
                    .checkedIncrement(current.aggregateVersion),
                createdAt: current.createdAt,
                updatedAt: command.envelope.occurredAt,
                version: current.version
            ))
        }
        return try DependencyInvalidationResultV1(
            dependency: command.dependency,
            verificationIds: verificationIds.sorted(),
            outcomes: outcomes.sorted { $0.id < $1.id }
        )
    }

    private func dependencyInvalidationEventPayload(
        _ result: DependencyInvalidationResultV1
    ) -> JSONValue {
        .object([
            "dependency": .object([
                "type": .string(result.dependency.type),
                "id": .string(result.dependency.id),
                "version": result.dependency.version.map {
                    .number(Double($0))
                } ?? .null,
                "hash": result.dependency.hash.map(JSONValue.string)
                    ?? .null,
            ]),
            "verificationIds": .array(
                result.verificationIds.map(JSONValue.string)
            ),
            "outcomeIds": .array(
                result.outcomes.map { .string($0.id) }
            ),
        ])
    }

    private func insertVerificationRecord(
        _ record: VerificationRecordSnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO verification_record(
                  id,commandIdempotencyKey,contractId,contractVersion,
                  contractHash,requirementId,requirementVersion,
                  requirementHash,outcomeId,outcomeVersion,outcomeHash,
                  verifierType,verifierId,method,ruleId,ruleVersion,
                  environmentJson,commandOrRuleJson,rawResultRef,evidenceHash,
                  result,supersedesVerificationId,createdAt,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)
                """,
            arguments: [
                record.id, record.commandIdempotencyKey,
                record.requirement.contract.id,
                record.requirement.contract.version,
                record.requirement.contract.hash,
                record.requirement.requirementId,
                record.requirement.requirementVersion,
                record.requirement.requirementHash, record.outcome.id,
                record.outcome.version, record.outcome.hash,
                record.verifierType.rawValue, record.verifierId,
                record.method.rawValue, record.ruleId, record.ruleVersion,
                try CanonicalContractCodingV1.string(record.environment),
                try CanonicalContractCodingV1.string(record.commandOrRule),
                record.rawResultRef, record.evidenceHash,
                record.result.rawValue, record.supersedesVerificationId,
                record.createdAt,
            ]
        )
    }

    private func validateVerificationProjection(
        _ result: VerificationRecordSnapshotV1,
        expectedOutcomeAggregateVersion: Int,
        expectedOutcomeState: OutcomeStateV1,
        database: Database
    ) throws {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM verification_record WHERE id=?",
            arguments: [result.id]
        ),
        row["commandIdempotencyKey"] as String
            == result.commandIdempotencyKey,
        row["contractId"] as String == result.requirement.contract.id,
        row["contractVersion"] as Int == result.requirement.contract.version,
        row["contractHash"] as String == result.requirement.contract.hash,
        row["requirementId"] as String == result.requirement.requirementId,
        row["requirementVersion"] as Int
            == result.requirement.requirementVersion,
        row["requirementHash"] as String
            == result.requirement.requirementHash,
        row["outcomeId"] as String == result.outcome.id,
        row["outcomeVersion"] as Int == result.outcome.version,
        row["outcomeHash"] as String == result.outcome.hash,
        row["verifierType"] as String == result.verifierType.rawValue,
        row["verifierId"] as String == result.verifierId,
        row["method"] as String == result.method.rawValue,
        row["ruleId"] as String == result.ruleId,
        row["ruleVersion"] as Int == result.ruleVersion,
        row["environmentJson"] as String
            == (try CanonicalContractCodingV1.string(result.environment)),
        row["commandOrRuleJson"] as String
            == (try CanonicalContractCodingV1.string(result.commandOrRule)),
        row["rawResultRef"] as String? == result.rawResultRef,
        row["evidenceHash"] as String == result.evidenceHash,
        row["result"] as String == result.result.rawValue,
        row["supersedesVerificationId"] as String?
            == result.supersedesVerificationId,
        row["createdAt"] as Date == result.createdAt,
        row["redactedAt"] as Date? == nil,
        let head = try Row.fetchOne(
            database,
            sql: """
                SELECT currentVerificationId,derivedResult
                FROM verification_result_head
                WHERE outcomeId=? AND outcomeVersion=? AND contractId=?
                  AND contractVersion=? AND requirementId=?
                  AND requirementVersion=?
                """,
            arguments: [
                result.outcome.id, result.outcome.version,
                result.requirement.contract.id,
                result.requirement.contract.version,
                result.requirement.requirementId,
                result.requirement.requirementVersion,
            ]
        ),
        head["currentVerificationId"] as String == result.id,
        head["derivedResult"] as String == result.result.rawValue,
        let committedOutcome = try outcome(
            id: result.outcome.id,
            database: database
        ),
        committedOutcome.currentRef == result.outcome,
        committedOutcome.state == expectedOutcomeState,
        committedOutcome.aggregateVersion
            == (try CanonicalContractCodingV1.checkedIncrement(
                expectedOutcomeAggregateVersion
            ))
        else {
            throw P1DProjectionConflictError()
        }
    }

    private func validateInvalidationProjection(
        outcome: OutcomeSnapshotV1,
        verificationIds: [String],
        reasonCode: String,
        dependency: VerificationDependencyRefV1,
        eventId: String,
        database: Database
    ) throws {
        try validateOutcomeProjection(outcome, database: database)
        for verificationId in verificationIds {
            guard let row = try Row.fetchOne(
                database,
                sql: """
                    SELECT * FROM verification_invalidation
                    WHERE verificationId=? AND eventId=?
                    """,
                arguments: [verificationId, eventId]
            ),
            row["reasonCode"] as String == reasonCode,
            row["dependencyType"] as String == dependency.type,
            row["dependencyId"] as String == dependency.id,
            row["dependencyVersion"] as Int? == dependency.version,
            row["dependencyHash"] as String? == dependency.hash,
            let headResult = try String.fetchOne(
                database,
                sql: """
                    SELECT derivedResult FROM verification_result_head
                    WHERE currentVerificationId=?
                    """,
                arguments: [verificationId]
            ),
            headResult == VerificationResultV1.invalid.rawValue
            else {
                throw P1DProjectionConflictError()
            }
        }
        let activeMetricCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM outcome_metric_credit
                WHERE outcomeId=? AND state='active'
                """,
            arguments: [outcome.id]
        ) ?? 0
        guard activeMetricCount == 0 else {
            throw P1DProjectionConflictError()
        }
        if outcome.state == .invalidated {
            guard let goal = try GoalControllerRecord.fetchOne(
                database,
                key: outcome.goalId
            ), goal.status == .active,
                  let mission = try MissionRecord.fetchOne(
                      database,
                      key: outcome.missionId
                  ), mission.status == .delivering,
                  let metric = try metricCredit(
                      outcomeId: outcome.id,
                      database: database
                  ), metric.state == .reversed,
                  metric.reversedByEventId == eventId
            else {
                throw P1DProjectionConflictError()
            }
        }
    }
}

extension OutcomeStore {
    package func recordVerification(
        _ command: RecordVerificationCommandV1
    ) throws -> VerificationRecordSnapshotV1 {
        let payload = VerificationCommandPayload(
            verificationId: command.verificationId,
            requirement: command.requirement,
            outcome: command.outcome,
            expectedOutcomeAggregateVersion:
                command.expectedOutcomeAggregateVersion,
            expectedCurrentVerificationId:
                command.expectedCurrentVerificationId,
            environment: command.environment,
            commandOrRule: command.commandOrRule,
            rawResultRef: command.rawResultRef,
            result: command.result,
            evidenceHash: command.evidenceHash
        )
        return try database.pool.write { db in
            let previewState: OutcomeStateV1
            if try storedResult(
                VerificationRecordSnapshotV1.self,
                commandKey: command.envelope.idempotencyKey,
                database: db
            ) != nil {
                previewState = try storedVerificationEventState(
                    commandKey: command.envelope.idempotencyKey,
                    outcome: command.outcome,
                    database: db
                )
            } else {
                let previewRecord = try prepareVerificationRecord(
                    command,
                    database: db
                )
                let previewOutcome = try requireOutcome(
                    ref: command.outcome,
                    expectedAggregateVersion:
                        command.expectedOutcomeAggregateVersion,
                    database: db
                )
                previewState = try reducedOutcomeState(
                    previewOutcome,
                    replacing: previewRecord,
                    database: db
                )
            }
            let eventVersion = try storedOutcomeEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    command.expectedOutcomeAggregateVersion
                ),
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "verification.record.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: outcomeCamp(command.outcome.id, database: db),
                    outcomeId: command.outcome.id,
                    aggregateVersion: eventVersion,
                    eventType: "verification.recorded.v1",
                    state: previewState,
                    outcomeVersion: command.outcome.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let result = try prepareVerificationRecord(
                        command,
                        database: transaction
                    )
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedOutcomeAggregateVersion,
                        database: transaction
                    )
                    guard try reducedOutcomeState(
                        current,
                        replacing: result,
                        database: transaction
                    ) == previewState else {
                        throw P1DProjectionConflictError()
                    }
                    return result
                },
                apply: { transaction, _, result in
                    try insertVerificationRecord(result, database: transaction)
                    if let current = result.supersedesVerificationId {
                        try transaction.execute(
                            sql: """
                                UPDATE verification_result_head
                                SET currentVerificationId=?,derivedResult=?,
                                    version=version+1,updatedAt=?
                                WHERE outcomeId=? AND outcomeVersion=?
                                  AND contractId=? AND contractVersion=?
                                  AND requirementId=? AND requirementVersion=?
                                  AND currentVerificationId=?
                                """,
                            arguments: [
                                result.id, result.result.rawValue,
                                result.createdAt, result.outcome.id,
                                result.outcome.version,
                                result.requirement.contract.id,
                                result.requirement.contract.version,
                                result.requirement.requirementId,
                                result.requirement.requirementVersion, current,
                            ]
                        )
                    } else {
                        try transaction.execute(
                            sql: """
                                INSERT INTO verification_result_head(
                                  outcomeId,outcomeVersion,contractId,
                                  contractVersion,requirementId,
                                  requirementVersion,currentVerificationId,
                                  derivedResult,version,updatedAt
                                ) VALUES (?,?,?,?,?,?,?,?,1,?)
                                """,
                            arguments: [
                                result.outcome.id, result.outcome.version,
                                result.requirement.contract.id,
                                result.requirement.contract.version,
                                result.requirement.requirementId,
                                result.requirement.requirementVersion,
                                result.id, result.result.rawValue,
                                result.createdAt,
                            ]
                        )
                    }
                    guard transaction.changesCount == 1 else {
                        throw VerificationHeadConflictError()
                    }
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedOutcomeAggregateVersion,
                        database: transaction
                    )
                    let reduced = try reducedOutcomeState(
                        current,
                        database: transaction
                    )
                    guard reduced == previewState else {
                        throw P1DProjectionConflictError()
                    }
                    let nextVersion = try CanonicalContractCodingV1
                        .checkedIncrement(current.aggregateVersion)
                    guard OutcomeTransitionPolicyV1.allows(.init(
                        command: .reduceVerification,
                        from: current.state,
                        to: reduced
                    )) else {
                        throw InvalidOutcomeTransitionError()
                    }
                    try transaction.execute(
                        sql: """
                            UPDATE outcome SET state=?,aggregateVersion=?,updatedAt=?
                            WHERE id=? AND aggregateVersion=? AND currentVersion=?
                        """,
                        arguments: [
                            reduced.rawValue, nextVersion, result.createdAt,
                            current.id, current.aggregateVersion,
                            current.currentVersion,
                        ]
                    )
                    guard transaction.changesCount == 1 else {
                        throw P1DProjectionConflictError()
                    }
                },
                validateProjection: { transaction, _, result in
                    try validateVerificationProjection(
                        result,
                        expectedOutcomeAggregateVersion:
                            command.expectedOutcomeAggregateVersion,
                        expectedOutcomeState: previewState,
                        database: transaction
                    )
                }
            )
        }
    }

    package func invalidateVerification(
        _ command: InvalidateVerificationCommandV1
    ) throws -> OutcomeSnapshotV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.dependencyInvalidator
        )
        let payload = InvalidationCommandPayload(
            outcome: command.outcome,
            expectedOutcomeAggregateVersion:
                command.expectedOutcomeAggregateVersion,
            verificationIds: command.verificationIds,
            reasonCode: command.reasonCode,
            dependency: command.dependency
        )
        return try database.pool.write { db in
            let targetVersion = try storedOutcomeEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    command.expectedOutcomeAggregateVersion
                ),
                database: db
            )
            let currentState = try requireOutcome(
                ref: command.outcome,
                expectedAggregateVersion:
                    command.expectedOutcomeAggregateVersion,
                database: db
            ).state
            let targetState: OutcomeStateV1 = currentState == .accepted
                ? .invalidated : .verificationPending
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "verification.invalidate.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: outcomeCamp(command.outcome.id, database: db),
                    outcomeId: command.outcome.id,
                    aggregateVersion: targetVersion,
                    eventType: "verification.invalidated.v1",
                    state: targetState,
                    outcomeVersion: command.outcome.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedOutcomeAggregateVersion,
                        database: transaction
                    )
                    let target: OutcomeStateV1 = current.state == .accepted
                        ? .invalidated : .verificationPending
                    guard OutcomeTransitionPolicyV1.allows(.init(
                        command: .invalidateVerification,
                        from: current.state,
                        to: target
                    )) else {
                        throw InvalidOutcomeTransitionError()
                    }
                    for id in command.verificationIds {
                        guard try Int.fetchOne(
                            transaction,
                            sql: """
                                SELECT COUNT(*) FROM verification_record r
                                JOIN verification_result_head h
                                  ON h.currentVerificationId=r.id
                                WHERE r.id=? AND r.outcomeId=?
                                  AND r.outcomeVersion=?
                                """,
                            arguments: [id, current.id, current.currentVersion]
                        ) == 1 else {
                            throw VerificationReferenceMismatchError()
                        }
                    }
                    return OutcomeSnapshotV1(
                        id: current.id,
                        goalId: current.goalId,
                        missionId: current.missionId,
                        contract: current.contract,
                        currentVersion: current.currentVersion,
                        state: target,
                        aggregateVersion: targetVersion,
                        createdAt: current.createdAt,
                        updatedAt: command.envelope.occurredAt,
                        version: current.version
                    )
                },
                apply: { transaction, eventIDs, result in
                    for verificationId in command.verificationIds {
                        try insertInvalidation(
                            verificationId: verificationId,
                            reasonCode: command.reasonCode,
                            dependency: command.dependency,
                            eventId: eventIDs[0],
                            createdAt: command.envelope.occurredAt,
                            database: transaction
                        )
                        try transaction.execute(
                            sql: """
                                UPDATE verification_result_head
                                SET derivedResult='invalid',version=version+1,
                                    updatedAt=?
                                WHERE currentVerificationId=?
                            """,
                            arguments: [
                                command.envelope.occurredAt, verificationId,
                            ]
                        )
                        guard transaction.changesCount == 1 else {
                            throw VerificationHeadConflictError()
                        }
                    }
                    _ = try memoryStore.applyInvalidation(
                        .verificationInvalidated(
                            outcomeId: result.id,
                            outcomeVersion: result.currentVersion,
                            verificationIds: command.verificationIds
                        ),
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                    try updateOutcomeHead(
                        result,
                        expectedVersion:
                            command.expectedOutcomeAggregateVersion,
                        expectedState: nil,
                        database: transaction
                    )
                    try reopenGoalAndMissionIfNeeded(
                        outcome: result,
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                    try reverseMetricIfActive(
                        outcomeId: result.id,
                        eventId: eventIDs[0],
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                },
                validateProjection: { transaction, eventIDs, result in
                    guard eventIDs.count == 1 else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    try validateInvalidationProjection(
                        outcome: result,
                        verificationIds: command.verificationIds,
                        reasonCode: command.reasonCode,
                        dependency: command.dependency,
                        eventId: eventIDs[0],
                        database: transaction
                    )
                }
            )
        }
    }

    package func deleteOrInvalidateDependency(
        _ command: DeleteOrInvalidateDependencyCommandV1
    ) throws -> DependencyInvalidationResultV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.dependencyInvalidator
        )
        let payload = DependencyInvalidationCommandPayload(
            campId: command.campId,
            reasonCode: command.reasonCode,
            dependency: command.dependency
        )
        return try database.pool.write { db in
            let preview = try storedResult(
                DependencyInvalidationResultV1.self,
                commandKey: command.envelope.idempotencyKey,
                database: db
            ) ?? prepareDependencyInvalidation(
                command,
                database: db
            )
            let eventVersion = try commandEventVersion(
                database: db,
                commandKey: command.envelope.idempotencyKey,
                aggregateType: "verificationDependency",
                aggregateId: command.dependency.id
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "dependency.delete-or-invalidate.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try P1DCommandEventShapeV1(
                    campId: command.campId,
                    aggregateType: "verificationDependency",
                    aggregateId: command.dependency.id,
                    aggregateVersion: eventVersion,
                    eventType: "dependency.verification-invalidated.v1",
                    payload: dependencyInvalidationEventPayload(preview)
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let exact = try prepareDependencyInvalidation(
                        command,
                        database: transaction
                    )
                    guard exact == preview else {
                        throw P1DProjectionConflictError()
                    }
                    return exact
                },
                apply: { transaction, eventIDs, result in
                    guard eventIDs.count == 1 else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    for verificationId in result.verificationIds {
                        try insertInvalidation(
                            verificationId: verificationId,
                            reasonCode: command.reasonCode,
                            dependency: command.dependency,
                            eventId: eventIDs[0],
                            createdAt: command.envelope.occurredAt,
                            database: transaction
                        )
                        try transaction.execute(
                            sql: """
                                UPDATE verification_result_head
                                SET derivedResult='invalid',version=version+1,
                                    updatedAt=?
                                WHERE currentVerificationId=?
                                  AND derivedResult<>'invalid'
                                """,
                            arguments: [
                                command.envelope.occurredAt,
                                verificationId,
                            ]
                        )
                        guard transaction.changesCount == 1 else {
                            throw VerificationHeadConflictError()
                        }
                    }
                    for outcome in result.outcomes {
                        guard let current = try self.outcome(
                            id: outcome.id,
                            database: transaction
                        ), current.currentRef == outcome.currentRef,
                           try CanonicalContractCodingV1.checkedIncrement(
                               current.aggregateVersion
                           ) == outcome.aggregateVersion
                        else {
                            throw OutcomeReferenceMismatchError()
                        }
                        try updateOutcomeHead(
                            outcome,
                            expectedVersion: current.aggregateVersion,
                            expectedState: current.state,
                            database: transaction
                        )
                        try reopenGoalAndMissionIfNeeded(
                            outcome: outcome,
                            at: command.envelope.occurredAt,
                            database: transaction
                        )
                        try reverseMetricIfActive(
                            outcomeId: outcome.id,
                            eventId: eventIDs[0],
                            at: command.envelope.occurredAt,
                            database: transaction
                        )
                    }
                    for outcome in result.outcomes {
                        let outcomeVerificationIDs = try String.fetchAll(
                            transaction,
                            sql: """
                                SELECT r.id FROM verification_record r
                                WHERE r.outcomeId=? AND r.outcomeVersion=?
                                  AND r.id IN (
                                    SELECT value FROM json_each(?)
                                  )
                                ORDER BY r.id
                                """,
                            arguments: [
                                outcome.id, outcome.currentVersion,
                                try CanonicalContractCodingV1.string(
                                    result.verificationIds
                                ),
                            ]
                        )
                        _ = try memoryStore.applyInvalidation(
                            .verificationInvalidated(
                                outcomeId: outcome.id,
                                outcomeVersion: outcome.currentVersion,
                                verificationIds: outcomeVerificationIDs
                            ),
                            at: command.envelope.occurredAt,
                            database: transaction
                        )
                    }
                    if let memoryDependencyType = MemoryDependencyTypeV1(
                        rawValue: command.dependency.type
                    ) {
                        _ = try memoryStore.applyInvalidation(
                            .dependencyInvalidated(
                                type: memoryDependencyType,
                                id: command.dependency.id,
                                version: command.dependency.version,
                                hash: command.dependency.hash,
                                deleted: Self.memoryDependencyWasDeleted(
                                    reasonCode: command.reasonCode
                                )
                            ),
                            at: command.envelope.occurredAt,
                            database: transaction
                        )
                    }
                },
                validateProjection: { transaction, eventIDs, result in
                    guard eventIDs.count == 1 else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    for outcome in result.outcomes {
                        let ids = try String.fetchAll(
                            transaction,
                            sql: """
                                SELECT i.verificationId
                                FROM verification_invalidation i
                                JOIN verification_record r
                                  ON r.id=i.verificationId
                                WHERE i.eventId=? AND r.outcomeId=?
                                ORDER BY i.verificationId
                                """,
                            arguments: [eventIDs[0], outcome.id]
                        )
                        try validateInvalidationProjection(
                            outcome: outcome,
                            verificationIds: ids,
                            reasonCode: command.reasonCode,
                            dependency: command.dependency,
                            eventId: eventIDs[0],
                            database: transaction
                        )
                    }
                    let allIDs = try String.fetchAll(
                        transaction,
                        sql: """
                            SELECT verificationId
                            FROM verification_invalidation
                            WHERE eventId=? ORDER BY verificationId
                            """,
                        arguments: [eventIDs[0]]
                    )
                    guard allIDs == result.verificationIds else {
                        throw P1DProjectionConflictError()
                    }
                }
            )
        }
    }

    package func markDelivered(
        _ command: MarkDeliveredCommandV1
    ) throws -> OutcomeSnapshotV1 {
        try authorizeSystem(
            command.envelope,
            actorId: P1DActorID.delivery
        )
        let payload = DeliveryCommandPayload(
            outcome: command.outcome,
            expectedAggregateVersion: command.expectedAggregateVersion
        )
        return try database.pool.write { db in
            let targetVersion = try storedOutcomeEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    command.expectedAggregateVersion
                ),
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "outcome.mark-delivered.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: outcomeCamp(command.outcome.id, database: db),
                    outcomeId: command.outcome.id,
                    aggregateVersion: targetVersion,
                    eventType: "outcome.delivered.v1",
                    state: .delivered,
                    outcomeVersion: command.outcome.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedAggregateVersion,
                        database: transaction
                    )
                    guard current.state == .verified,
                          try reducedOutcomeState(current, database: transaction)
                            == .verified,
                          try currentInvalidationCount(
                              outcome: current,
                              database: transaction
                          ) == 0,
                          try manifestIsReadable(current.version.manifest)
                    else {
                        throw OutcomeDeliveryError()
                    }
                    return OutcomeSnapshotV1(
                        id: current.id,
                        goalId: current.goalId,
                        missionId: current.missionId,
                        contract: current.contract,
                        currentVersion: current.currentVersion,
                        state: .delivered,
                        aggregateVersion: targetVersion,
                        createdAt: current.createdAt,
                        updatedAt: command.envelope.occurredAt,
                        version: current.version
                    )
                },
                apply: { transaction, _, result in
                    try updateOutcomeHead(
                        result,
                        expectedVersion: command.expectedAggregateVersion,
                        expectedState: .verified,
                        database: transaction
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateOutcomeProjection(result, database: transaction)
                }
            )
        }
    }
}

// MARK: - P1-D Acceptance and section 19 projections

extension OutcomeStore {
    package func registerAcceptancePolicy(
        _ policy: AcceptancePolicyVersionV1
    ) throws -> AcceptancePolicyVersionV1 {
        try database.pool.write { db in
            if let stored = try acceptancePolicy(
                id: policy.ref.id,
                version: policy.ref.version,
                database: db
            ) {
                guard stored == policy else {
                    throw AcceptancePolicyEligibilityError.referenceMismatch
                }
                return stored
            }
            try db.execute(
                sql: """
                    INSERT INTO acceptance_policy_version(
                      id,version,outcomeType,maxRiskClass,policyActorId,
                      validFrom,validUntil,maxOutcomeAgeSeconds,
                      requireAllVerification,status,revokedAt,
                      createdByActorId,contentHash,createdAt
                    ) VALUES (?,?,?,?,?,?,?,?,1,?,?,?,?,?)
                    """,
                arguments: [
                    policy.ref.id, policy.ref.version, policy.outcomeType,
                    policy.maxRiskClass.rawValue, policy.policyActorId,
                    policy.validFrom, policy.validUntil,
                    policy.maxOutcomeAgeSeconds, policy.status.rawValue,
                    policy.revokedAt, policy.createdByActorId,
                    policy.ref.hash, policy.createdAt,
                ]
            )
            return policy
        }
    }

    package func acceptancePolicy(
        ref: AcceptancePolicyRefV1
    ) throws -> AcceptancePolicyVersionV1? {
        try database.pool.read { db in
            guard let policy = try acceptancePolicy(
                id: ref.id,
                version: ref.version,
                database: db
            ) else { return nil }
            guard policy.ref == ref else {
                throw AcceptancePolicyEligibilityError.referenceMismatch
            }
            return policy
        }
    }

    package func acceptOutcome(
        _ command: AcceptOutcomeCommandV1
    ) throws -> AcceptanceCommitSnapshotV1 {
        let payload = AcceptOutcomePayload(
            acceptanceId: command.acceptanceId,
            outcome: command.outcome,
            expectedOutcomeAggregateVersion:
                command.expectedOutcomeAggregateVersion,
            subject: command.subject,
            reason: command.reason
        )
        return try database.pool.write { db in
            let targetVersion = try storedOutcomeEventVersion(
                commandKey: command.envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    command.expectedOutcomeAggregateVersion
                ),
                database: db
            )
            let prepared = try P1DPreparedCommandV1.make(
                commandType: "acceptance.accept-outcome.v1",
                envelope: command.envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: outcomeCamp(command.outcome.id, database: db),
                    outcomeId: command.outcome.id,
                    aggregateVersion: targetVersion,
                    eventType: "acceptance.accepted.v1",
                    state: .accepted,
                    outcomeVersion: command.outcome.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, _ in
                    let current = try requireOutcome(
                        ref: command.outcome,
                        expectedAggregateVersion:
                            command.expectedOutcomeAggregateVersion,
                        database: transaction
                    )
                    guard OutcomeTransitionPolicyV1.allows(.init(
                        command: .acceptOutcome,
                        from: current.state,
                        to: .accepted
                    )) else {
                        throw InvalidAcceptanceTransitionError()
                    }
                    let contract = try requireContract(
                        ref: current.contract,
                        database: transaction
                    )
                    let goal = try requireAcceptanceGoal(
                        current,
                        database: transaction
                    )
                    try authorizeAcceptanceSubject(
                        command.subject,
                        envelope: command.envelope,
                        beneficiaryActorId: goal.createdByActorId
                    )
                    let reduced = try reducedOutcomeState(
                        current,
                        database: transaction
                    )
                    if command.subject.type == .policy {
                        try applyPolicyHardGuard(
                            goal: goal,
                            contract: contract,
                            outcome: current,
                            reducedState: reduced,
                            database: transaction
                        )
                        try validateAcceptancePolicy(
                            subject: command.subject,
                            contract: contract,
                            outcome: current,
                            at: command.envelope.occurredAt,
                            database: transaction
                        )
                    } else if reduced != .verified {
                        throw InvalidAcceptanceTransitionError()
                    }
                    let mission = try requireAcceptanceMission(
                        current,
                        database: transaction
                    )
                    guard goal.status == .active,
                          mission.status == .delivering
                    else {
                        throw InvalidAcceptanceTransitionError()
                    }
                    let prior = try latestAcceptanceID(
                        outcomeId: current.id,
                        database: transaction
                    )
                    let record = AcceptanceRecordSnapshotV1(
                        id: command.acceptanceId,
                        commandIdempotencyKey:
                            command.envelope.idempotencyKey,
                        contract: current.contract,
                        outcome: current.currentRef,
                        subject: command.subject,
                        decision: .accepted,
                        reason: command.reason,
                        supersedesAcceptanceId: prior,
                        createdAt: command.envelope.occurredAt
                    )
                    let metric = try nextActiveMetric(
                        outcome: current,
                        acceptanceId: command.acceptanceId,
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                    return AcceptanceCommitSnapshotV1(
                        record: record,
                        outcome: OutcomeSnapshotV1(
                            id: current.id,
                            goalId: current.goalId,
                            missionId: current.missionId,
                            contract: current.contract,
                            currentVersion: current.currentVersion,
                            state: .accepted,
                            aggregateVersion: targetVersion,
                            createdAt: current.createdAt,
                            updatedAt: command.envelope.occurredAt,
                            version: current.version
                        ),
                        goalStatus: .achieved,
                        missionStatus: .accepted,
                        metric: metric
                    )
                },
                apply: { transaction, _, result in
                    try insertAcceptanceRecord(
                        result.record,
                        database: transaction
                    )
                    try updateOutcomeHead(
                        result.outcome,
                        expectedVersion:
                            command.expectedOutcomeAggregateVersion,
                        expectedState: .delivered,
                        database: transaction
                    )
                    try achieveGoal(
                        outcome: result.outcome,
                        at: command.envelope.occurredAt,
                        database: transaction
                    )
                    try acceptMission(
                        outcome: result.outcome,
                        database: transaction
                    )
                    if let metric = result.metric {
                        try writeActiveMetric(metric, database: transaction)
                    }
                },
                validateProjection: { transaction, _, result in
                    try validateAcceptanceProjection(
                        result,
                        database: transaction
                    )
                }
            )
        }
    }

    package func returnOutcome(
        _ command: ReturnOutcomeCommandV1
    ) throws -> AcceptanceCommitSnapshotV1 {
        try acceptanceReversal(
            commandType: "acceptance.return-outcome.v1",
            eventType: "acceptance.returned.v1",
            decision: .returned,
            transition: .returnOutcome,
            acceptanceId: command.acceptanceId,
            outcomeRef: command.outcome,
            expectedVersion: command.expectedOutcomeAggregateVersion,
            subject: command.subject,
            reason: command.reason,
            envelope: command.envelope
        )
    }

    package func revokeAcceptance(
        _ command: RevokeAcceptanceCommandV1
    ) throws -> AcceptanceCommitSnapshotV1 {
        try acceptanceReversal(
            commandType: "acceptance.revoke.v1",
            eventType: "acceptance.revoked.v1",
            decision: .revoked,
            transition: .revokeAcceptance,
            acceptanceId: command.acceptanceId,
            outcomeRef: command.outcome,
            expectedVersion: command.expectedOutcomeAggregateVersion,
            subject: command.subject,
            reason: command.reason,
            envelope: command.envelope
        )
    }

    package func acceptanceRecord(
        id: String
    ) throws -> AcceptanceRecordSnapshotV1? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try acceptanceRecord(id: id, database: db)
        }
    }

    package func metricCredit(
        outcomeId: String
    ) throws -> OutcomeMetricCreditSnapshotV1? {
        try CanonicalContractCodingV1.validateCanonicalUUID(outcomeId)
        return try database.pool.read { db in
            try metricCredit(outcomeId: outcomeId, database: db)
        }
    }

    package func acceptanceCount(outcomeId: String) throws -> Int {
        try database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM acceptance_record WHERE outcomeId=?",
                arguments: [outcomeId]
            ) ?? 0
        }
    }
}

extension OutcomeStore {
    private func acceptanceReversal(
        commandType: String,
        eventType: String,
        decision: AcceptanceDecisionV1,
        transition: OutcomeTransitionCommandV1,
        acceptanceId: String,
        outcomeRef: OutcomeRefV1,
        expectedVersion: Int,
        subject: AcceptanceSubjectV1,
        reason: String,
        envelope: CommandEnvelopeV1
    ) throws -> AcceptanceCommitSnapshotV1 {
        let payload = AcceptanceReversalPayload(
            acceptanceId: acceptanceId,
            outcome: outcomeRef,
            expectedOutcomeAggregateVersion: expectedVersion,
            subject: subject,
            decision: decision,
            reason: reason
        )
        return try database.pool.write { db in
            let targetVersion = try storedOutcomeEventVersion(
                commandKey: envelope.idempotencyKey,
                fallback: try CanonicalContractCodingV1.checkedIncrement(
                    expectedVersion
                ),
                database: db
            )
            let targetState: OutcomeStateV1 = decision == .returned
                ? .returned : .revoked
            let prepared = try P1DPreparedCommandV1.make(
                commandType: commandType,
                envelope: envelope,
                payload: payload,
                events: [try outcomeEvent(
                    campId: outcomeCamp(outcomeRef.id, database: db),
                    outcomeId: outcomeRef.id,
                    aggregateVersion: targetVersion,
                    eventType: eventType,
                    state: targetState,
                    outcomeVersion: outcomeRef.version
                )]
            )
            return try eventStore.executePlannedP1DCommand(
                command: prepared,
                database: db,
                prepare: { transaction, eventIDs in
                    guard eventIDs.count == 1 else {
                        throw DomainCommandGraphIntegrityError()
                    }
                    let current = try requireOutcome(
                        ref: outcomeRef,
                        expectedAggregateVersion: expectedVersion,
                        database: transaction
                    )
                    guard OutcomeTransitionPolicyV1.allows(.init(
                        command: transition,
                        from: current.state,
                        to: targetState
                    )) else {
                        throw InvalidAcceptanceTransitionError()
                    }
                    let goal = try requireAcceptanceGoal(
                        current,
                        database: transaction
                    )
                    try authorizeUserAcceptanceSubject(
                        subject,
                        envelope: envelope,
                        beneficiaryActorId: goal.createdByActorId
                    )
                    let mission = try requireAcceptanceMission(
                        current,
                        database: transaction
                    )
                    guard goal.status == .active || goal.status == .achieved,
                          mission.status == .delivering
                            || mission.status == .accepted
                    else {
                        throw InvalidAcceptanceTransitionError()
                    }
                    let prior = try latestAcceptanceID(
                        outcomeId: current.id,
                        database: transaction
                    )
                    if decision == .revoked, prior == nil {
                        throw AcceptanceReferenceError()
                    }
                    let record = AcceptanceRecordSnapshotV1(
                        id: acceptanceId,
                        commandIdempotencyKey: envelope.idempotencyKey,
                        contract: current.contract,
                        outcome: current.currentRef,
                        subject: subject,
                        decision: decision,
                        reason: reason,
                        supersedesAcceptanceId: prior,
                        createdAt: envelope.occurredAt
                    )
                    let metric = try reversedMetric(
                        outcomeId: current.id,
                        eventId: eventIDs[0],
                        at: envelope.occurredAt,
                        database: transaction
                    )
                    return AcceptanceCommitSnapshotV1(
                        record: record,
                        outcome: OutcomeSnapshotV1(
                            id: current.id,
                            goalId: current.goalId,
                            missionId: current.missionId,
                            contract: current.contract,
                            currentVersion: current.currentVersion,
                            state: targetState,
                            aggregateVersion: targetVersion,
                            createdAt: current.createdAt,
                            updatedAt: envelope.occurredAt,
                            version: current.version
                        ),
                        goalStatus: goal.status == .achieved ? .active : goal.status,
                        missionStatus: mission.status == .accepted
                            ? .delivering : mission.status,
                        metric: metric
                    )
                },
                apply: { transaction, eventIDs, result in
                    try insertAcceptanceRecord(
                        result.record,
                        database: transaction
                    )
                    try updateOutcomeHead(
                        result.outcome,
                        expectedVersion: expectedVersion,
                        expectedState: nil,
                        database: transaction
                    )
                    try reopenGoalAndMissionIfNeeded(
                        outcome: result.outcome,
                        at: envelope.occurredAt,
                        database: transaction
                    )
                    try reverseMetricIfActive(
                        outcomeId: result.outcome.id,
                        eventId: eventIDs[0],
                        at: envelope.occurredAt,
                        database: transaction
                    )
                    let invalidation: MemoryInvalidationCauseV1
                    if decision == .returned {
                        invalidation = .outcomeReturned(
                            outcomeId: result.outcome.id,
                            outcomeVersion: result.outcome.currentVersion,
                            acceptanceId:
                                result.record.supersedesAcceptanceId
                        )
                    } else {
                        guard let superseded =
                            result.record.supersedesAcceptanceId
                        else {
                            throw AcceptanceReferenceError()
                        }
                        invalidation = .acceptanceRevoked(
                            outcomeId: result.outcome.id,
                            outcomeVersion: result.outcome.currentVersion,
                            acceptanceId: superseded
                        )
                    }
                    _ = try memoryStore.applyInvalidation(
                        invalidation,
                        at: envelope.occurredAt,
                        database: transaction
                    )
                },
                validateProjection: { transaction, _, result in
                    try validateAcceptanceProjection(
                        result,
                        database: transaction
                    )
                }
            )
        }
    }

    private func authorizeAcceptanceSubject(
        _ subject: AcceptanceSubjectV1,
        envelope: CommandEnvelopeV1,
        beneficiaryActorId: String
    ) throws {
        switch subject.type {
        case .user:
            try authorizeUserAcceptanceSubject(
                subject,
                envelope: envelope,
                beneficiaryActorId: beneficiaryActorId
            )
        case .policy:
            guard subject.policy != nil,
                  envelope.actorType == .system,
                  envelope.actorId == subject.id
            else {
                throw AcceptanceAuthorizationError()
            }
        }
    }

    private func authorizeUserAcceptanceSubject(
        _ subject: AcceptanceSubjectV1,
        envelope: CommandEnvelopeV1,
        beneficiaryActorId: String
    ) throws {
        guard subject.type == .user,
              subject.policy == nil,
              envelope.actorType == .user,
              envelope.actorId == subject.id,
              subject.id == beneficiaryActorId
        else {
            throw AcceptanceAuthorizationError()
        }
    }

    private func applyPolicyHardGuard(
        goal: GoalControllerRecord,
        contract: OutcomeContractSnapshotV1,
        outcome: OutcomeSnapshotV1,
        reducedState: OutcomeStateV1,
        database: Database
    ) throws {
        let historyCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM acceptance_record a
                JOIN outcome o ON o.id=a.outcomeId
                JOIN goal_controller g ON g.id=o.goalId
                WHERE a.decision='accepted' AND g.createdByActorId=?
                """,
            arguments: [goal.createdByActorId]
        ) ?? 0
        if historyCount == 0 {
            throw UserAcceptanceRequiredError(reason: .firstOnboarding)
        }
        let typeHistoryCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM acceptance_record a
                JOIN outcome o ON o.id=a.outcomeId
                JOIN goal_controller g ON g.id=o.goalId
                JOIN outcome_contract_version c
                  ON c.id=a.contractId AND c.version=a.contractVersion
                WHERE a.decision='accepted' AND g.createdByActorId=?
                  AND c.outcomeType=?
                """,
            arguments: [goal.createdByActorId, contract.body.outcomeType]
        ) ?? 0
        if typeHistoryCount == 0 {
            throw UserAcceptanceRequiredError(reason: .firstOutcomeType)
        }
        if contract.body.requiresSubjectiveJudgment {
            throw UserAcceptanceRequiredError(reason: .subjectiveJudgment)
        }
        if contract.body.includesPublicRelease {
            throw UserAcceptanceRequiredError(reason: .publicRelease)
        }
        if contract.body.includesPayment {
            throw UserAcceptanceRequiredError(reason: .payment)
        }
        if contract.body.includesDeletion {
            throw UserAcceptanceRequiredError(reason: .deletion)
        }
        if contract.body.includesExternalSend {
            throw UserAcceptanceRequiredError(reason: .externalSend)
        }
        if contract.body.riskClass == .high {
            throw UserAcceptanceRequiredError(reason: .highRisk)
        }
        if contract.body.riskClass == .irreversible {
            throw UserAcceptanceRequiredError(reason: .irreversibleRisk)
        }
        if reducedState != .verified {
            throw UserAcceptanceRequiredError(reason: .unverified)
        }
        _ = outcome
    }

    private func validateAcceptancePolicy(
        subject: AcceptanceSubjectV1,
        contract: OutcomeContractSnapshotV1,
        outcome: OutcomeSnapshotV1,
        at now: Date,
        database: Database
    ) throws {
        guard let ref = subject.policy else {
            throw AcceptancePolicyEligibilityError.missingPolicy
        }
        guard contract.body.acceptanceOwner == .policy,
              contract.body.acceptancePolicy == ref
        else {
            throw AcceptancePolicyEligibilityError.referenceMismatch
        }
        guard let policy = try acceptancePolicy(
            id: ref.id,
            version: ref.version,
            database: database
        ) else {
            throw AcceptancePolicyEligibilityError.missingPolicy
        }
        guard policy.ref == ref else {
            throw AcceptancePolicyEligibilityError.referenceMismatch
        }
        guard policy.policyActorId == subject.id else {
            throw AcceptancePolicyEligibilityError.wrongActor
        }
        guard policy.status == .active else {
            throw AcceptancePolicyEligibilityError.inactive
        }
        guard now >= policy.validFrom, now < policy.validUntil else {
            throw AcceptancePolicyEligibilityError.outsideValidity
        }
        guard policy.outcomeType == contract.body.outcomeType else {
            throw AcceptancePolicyEligibilityError.outcomeTypeMismatch
        }
        let riskAllowed = policy.maxRiskClass == .normal
            || contract.body.riskClass == .low
        guard riskAllowed else {
            throw AcceptancePolicyEligibilityError.riskExceeded
        }
        let age = now.timeIntervalSince(outcome.version.createdAt)
        guard age >= 0,
              age <= Double(policy.maxOutcomeAgeSeconds)
        else {
            throw AcceptancePolicyEligibilityError.outcomeTooOld
        }
    }

    private func acceptancePolicy(
        id: String,
        version: Int,
        database: Database
    ) throws -> AcceptancePolicyVersionV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM acceptance_policy_version WHERE id=? AND version=?",
            arguments: [id, version]
        ) else { return nil }
        guard let risk = OutcomeRiskClassV1(rawValue: row["maxRiskClass"]),
              let status = AcceptancePolicyStatusV1(rawValue: row["status"])
        else {
            throw AcceptancePolicyEligibilityError.referenceMismatch
        }
        let policy = try AcceptancePolicyVersionV1(
            id: row["id"],
            version: row["version"],
            outcomeType: row["outcomeType"],
            maxRiskClass: risk,
            policyActorId: row["policyActorId"],
            validFrom: row["validFrom"],
            validUntil: row["validUntil"],
            maxOutcomeAgeSeconds: row["maxOutcomeAgeSeconds"],
            status: status,
            revokedAt: row["revokedAt"],
            createdByActorId: row["createdByActorId"],
            createdAt: row["createdAt"]
        )
        guard policy.ref.hash == row["contentHash"],
              (row["requireAllVerification"] as Int) == 1
        else {
            throw AcceptancePolicyEligibilityError.referenceMismatch
        }
        return policy
    }

    private func requireAcceptanceGoal(
        _ outcome: OutcomeSnapshotV1,
        database: Database
    ) throws -> GoalControllerRecord {
        guard let goal = try GoalControllerRecord.fetchOne(
            database,
            key: outcome.goalId
        ), goal.currentOutcomeContractId == outcome.contract.id,
           goal.currentOutcomeContractVersion == outcome.contract.version
        else {
            throw AcceptanceReferenceError()
        }
        return goal
    }

    private func requireAcceptanceMission(
        _ outcome: OutcomeSnapshotV1,
        database: Database
    ) throws -> MissionRecord {
        guard let mission = try MissionRecord.fetchOne(
            database,
            key: outcome.missionId
        ) else {
            throw AcceptanceReferenceError()
        }
        return mission
    }

    private func latestAcceptanceID(
        outcomeId: String,
        database: Database
    ) throws -> String? {
        try String.fetchOne(
            database,
            sql: """
                SELECT id FROM acceptance_record WHERE outcomeId=?
                ORDER BY createdAt DESC,id DESC LIMIT 1
                """,
            arguments: [outcomeId]
        )
    }

    private func insertAcceptanceRecord(
        _ record: AcceptanceRecordSnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO acceptance_record(
                  id,commandIdempotencyKey,contractId,contractVersion,
                  contractHash,outcomeId,outcomeVersion,outcomeHash,
                  subjectType,subjectId,policyId,policyVersion,decision,
                  reason,supersedesAcceptanceId,createdAt,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)
                """,
            arguments: [
                record.id, record.commandIdempotencyKey,
                record.contract.id, record.contract.version,
                record.contract.hash, record.outcome.id,
                record.outcome.version, record.outcome.hash,
                record.subject.type.rawValue, record.subject.id,
                record.subject.policy?.id, record.subject.policy?.version,
                record.decision.rawValue, record.reason,
                record.supersedesAcceptanceId, record.createdAt,
            ]
        )
    }

    private func acceptanceRecord(
        id: String,
        database: Database
    ) throws -> AcceptanceRecordSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM acceptance_record WHERE id=?",
            arguments: [id]
        ) else { return nil }
        guard let subjectType = AcceptanceSubjectTypeV1(
            rawValue: row["subjectType"]
        ), let decision = AcceptanceDecisionV1(rawValue: row["decision"])
        else {
            throw AcceptanceReferenceError()
        }
        let policy: AcceptancePolicyRefV1?
        if subjectType == .policy {
            guard let policyId: String = row["policyId"],
                  let policyVersion: Int = row["policyVersion"],
                  let stored = try acceptancePolicy(
                      id: policyId,
                      version: policyVersion,
                      database: database
                  )
            else {
                throw AcceptanceReferenceError()
            }
            policy = stored.ref
        } else {
            policy = nil
        }
        let subject = subjectType == .user
            ? try AcceptanceSubjectV1.user(row["subjectId"])
            : try AcceptanceSubjectV1.policy(
                actorId: row["subjectId"], ref: policy!
            )
        return AcceptanceRecordSnapshotV1(
            id: row["id"],
            commandIdempotencyKey: row["commandIdempotencyKey"],
            contract: try OutcomeContractRef(
                id: row["contractId"],
                version: row["contractVersion"],
                hash: row["contractHash"]
            ),
            outcome: try OutcomeRefV1(
                id: row["outcomeId"],
                version: row["outcomeVersion"],
                hash: row["outcomeHash"]
            ),
            subject: subject,
            decision: decision,
            reason: row["reason"],
            supersedesAcceptanceId: row["supersedesAcceptanceId"],
            createdAt: row["createdAt"]
        )
    }

    private func validateAcceptanceProjection(
        _ result: AcceptanceCommitSnapshotV1,
        database: Database
    ) throws {
        guard try acceptanceRecord(
            id: result.record.id,
            database: database
        ) == result.record,
              try outcome(
                  id: result.outcome.id,
                  database: database
              ) == result.outcome,
              let goal = try GoalControllerRecord.fetchOne(
                  database,
                  key: result.outcome.goalId
              ), goal.status == result.goalStatus,
              let mission = try MissionRecord.fetchOne(
                  database,
                  key: result.outcome.missionId
              ), mission.status == result.missionStatus,
              try metricCredit(
                  outcomeId: result.outcome.id,
                  database: database
              ) == result.metric
        else {
            throw P1DProjectionConflictError()
        }
    }

    private func nextActiveMetric(
        outcome: OutcomeSnapshotV1,
        acceptanceId: String,
        at now: Date,
        database: Database
    ) throws -> OutcomeMetricCreditSnapshotV1 {
        let old = try metricCredit(outcomeId: outcome.id, database: database)
        guard old?.state != .active else {
            throw P1DProjectionConflictError()
        }
        return OutcomeMetricCreditSnapshotV1(
            outcomeId: outcome.id,
            state: .active,
            creditedOutcomeVersion: outcome.currentVersion,
            acceptanceId: acceptanceId,
            reversedByEventId: nil,
            version: try CanonicalContractCodingV1.checkedIncrement(
                old?.version ?? 0
            ),
            creditedAt: now,
            reversedAt: nil
        )
    }

    private func writeActiveMetric(
        _ metric: OutcomeMetricCreditSnapshotV1,
        database: Database
    ) throws {
        if metric.version == 1 {
            try database.execute(
                sql: """
                    INSERT INTO outcome_metric_credit(
                      outcomeId,state,creditedOutcomeVersion,acceptanceId,
                      reversedByEventId,version,creditedAt,reversedAt
                    ) VALUES (?,'active',?,?,NULL,1,?,NULL)
                    """,
                arguments: [
                    metric.outcomeId, metric.creditedOutcomeVersion,
                    metric.acceptanceId, metric.creditedAt,
                ]
            )
        } else {
            try database.execute(
                sql: """
                    UPDATE outcome_metric_credit SET state='active',
                      creditedOutcomeVersion=?,acceptanceId=?,
                      reversedByEventId=NULL,version=?,creditedAt=?,reversedAt=NULL
                    WHERE outcomeId=? AND state='reversed' AND version=?
                    """,
                arguments: [
                    metric.creditedOutcomeVersion, metric.acceptanceId,
                    metric.version, metric.creditedAt, metric.outcomeId,
                    metric.version - 1,
                ]
            )
            guard database.changesCount == 1 else {
                throw P1DProjectionConflictError()
            }
        }
    }

    private func reversedMetric(
        outcomeId: String,
        eventId: String?,
        at now: Date,
        database: Database
    ) throws -> OutcomeMetricCreditSnapshotV1? {
        guard let current = try metricCredit(
            outcomeId: outcomeId,
            database: database
        ), current.state == .active else { return nil }
        return OutcomeMetricCreditSnapshotV1(
            outcomeId: current.outcomeId,
            state: .reversed,
            creditedOutcomeVersion: current.creditedOutcomeVersion,
            acceptanceId: current.acceptanceId,
            reversedByEventId: eventId,
            version: try CanonicalContractCodingV1.checkedIncrement(
                current.version
            ),
            creditedAt: current.creditedAt,
            reversedAt: now
        )
    }

    private func metricCredit(
        outcomeId: String,
        database: Database
    ) throws -> OutcomeMetricCreditSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM outcome_metric_credit WHERE outcomeId=?",
            arguments: [outcomeId]
        ) else { return nil }
        guard let state = OutcomeMetricCreditStateV1(rawValue: row["state"])
        else { throw AcceptanceReferenceError() }
        return OutcomeMetricCreditSnapshotV1(
            outcomeId: row["outcomeId"],
            state: state,
            creditedOutcomeVersion: row["creditedOutcomeVersion"],
            acceptanceId: row["acceptanceId"],
            reversedByEventId: row["reversedByEventId"],
            version: row["version"],
            creditedAt: row["creditedAt"],
            reversedAt: row["reversedAt"]
        )
    }

    private func achieveGoal(
        outcome: OutcomeSnapshotV1,
        at now: Date,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE goal_controller SET status='achieved',
                  aggregateVersion=aggregateVersion+1,updatedAt=?
                WHERE id=? AND status='active' AND currentOutcomeContractId=?
                  AND currentOutcomeContractVersion=?
                """,
            arguments: [
                now, outcome.goalId, outcome.contract.id,
                outcome.contract.version,
            ]
        )
        guard database.changesCount == 1 else {
            throw P1DProjectionConflictError()
        }
    }

    private func acceptMission(
        outcome: OutcomeSnapshotV1,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE mission SET status='accepted',revision=revision+1
                WHERE id=? AND status='delivering'
                """,
            arguments: [outcome.missionId]
        )
        guard database.changesCount == 1 else {
            throw P1DProjectionConflictError()
        }
    }

    private func reopenGoalAndMissionIfNeeded(
        outcome: OutcomeSnapshotV1,
        at now: Date,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE goal_controller SET status='active',
                  aggregateVersion=aggregateVersion+1,updatedAt=?
                WHERE id=? AND status='achieved'
                """,
            arguments: [now, outcome.goalId]
        )
        try database.execute(
            sql: """
                UPDATE mission SET status='delivering',revision=revision+1
                WHERE id=? AND status='accepted'
                """,
            arguments: [outcome.missionId]
        )
    }

    private func reverseMetricIfActive(
        outcomeId: String,
        eventId: String,
        at now: Date,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE outcome_metric_credit SET state='reversed',
                  reversedByEventId=?,version=version+1,reversedAt=?
                WHERE outcomeId=? AND state='active'
                """,
            arguments: [eventId, now, outcomeId]
        )
    }

    private static func memoryDependencyWasDeleted(
        reasonCode: String
    ) -> Bool {
        switch reasonCode {
        case "dependency_deleted", "source_deleted", "input_deleted":
            return true
        default:
            return false
        }
    }
}

private struct AcceptOutcomePayload: Codable {
    let acceptanceId: String
    let outcome: OutcomeRefV1
    let expectedOutcomeAggregateVersion: Int
    let subject: AcceptanceSubjectV1
    let reason: String
}

private struct AcceptanceReversalPayload: Codable {
    let acceptanceId: String
    let outcome: OutcomeRefV1
    let expectedOutcomeAggregateVersion: Int
    let subject: AcceptanceSubjectV1
    let decision: AcceptanceDecisionV1
    let reason: String
}
