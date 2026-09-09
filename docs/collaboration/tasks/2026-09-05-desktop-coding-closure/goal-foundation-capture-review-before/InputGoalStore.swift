import Foundation
import GRDB

package struct InputGoalStore: Sendable {
    private let database: AppDatabase
    private let eventStore: DomainEventStore

    package init(database: AppDatabase) {
        self.database = database
        eventStore = DomainEventStore(database: database)
    }

    package func input(id: String) throws -> InputEnvelopeRecord? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try InputEnvelopeRecord.fetchOne(db, key: id)
        }
    }

    package func goal(id: String) throws -> GoalControllerRecord? {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        return try database.pool.read { db in
            try GoalControllerRecord.fetchOne(db, key: id)
        }
    }

    package func captureAndEnqueueParsing(
        _ command: CaptureInputCommandV1
    ) throws -> InputCaptureReceiptV1 {
        try database.pool.write { db in
            try captureAndEnqueueParsing(command, in: db)
        }
    }

    package func captureAndEnqueueParsing(
        _ command: CaptureInputCommandV1, in transaction: Database
    ) throws -> InputCaptureReceiptV1 {
        let replayPlan = try Self.captureReplayPlan(
            inputId: command.inputId,
            auditCampId: command.auditCampId,
            expectedInputVersion: 0
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputCapture,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: transaction
            ) { db in
                try Self.requireAvailableCampIDs(
                    command.candidateCampIds,
                    in: db
                )
                let input = try InputEnvelopeRecord(
                    id: command.inputId,
                    schemaVersion: 1,
                    aggregateVersion: 1,
                    idempotencyKey: command.envelope.idempotencyKey,
                    sourceType: command.sourceType,
                    sourceDeviceId: command.sourceDeviceId,
                    connectorId: command.connectorId,
                    authorId: command.authorId,
                    capturedAt: command.capturedAt,
                    inlineText: command.inlineText,
                    payloadRef: command.payloadRef,
                    contentHash: command.contentHash,
                    candidateCampIds: command.candidateCampIds,
                    campId: command.initialCampId,
                    explicitIntent: command.explicitIntent,
                    privacyLevel: command.privacyLevel,
                    status: .captured,
                    errorCode: nil,
                    errorMessage: nil,
                    parentInputId: command.parentInputId,
                    retentionState: .active,
                    createdAt: command.envelope.occurredAt,
                    updatedAt: command.envelope.occurredAt,
                    deletedAt: nil
                )
                try input.insert(db)
                let workInput = try InputParsingWorkInputV1(
                    inputId: input.id,
                    contentHash: input.contentHash
                )
                let workJSON = try CanonicalContractCodingV1.string(workInput)
                let workHash = CanonicalJSONV1.sha256Hex(Data(workJSON.utf8))
                let enqueued = try DurableWorkStore.enqueue(
                    campId: command.auditCampId,
                    kind: .inputParsing,
                    aggregateType: "input",
                    aggregateId: input.id,
                    inputJson: workJSON,
                    claimedInputHash: workHash,
                    idempotencyKey: try ControlWorkKeyV1.inputParsing(
                        commandHash: prepared.commandPayloadHash
                    ),
                    maxAttempts: 4,
                    traceId: command.envelope.correlationId,
                    now: command.envelope.occurredAt,
                    in: db
                )
                guard enqueued.disposition == .inserted else {
                    throw DomainCommandReplayConflictError()
                }
                return try Self.makeInputCommand(
                    branch: .captureInput,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    input: input,
                    work: enqueued.work,
                    workInputHash: workHash
                )
            }
    }

    package func commitParseResult(
        _ command: CommitInputParseResultCommandV1,
        terminalNow: Date
    ) throws -> InputCaptureReceiptV1 {
        let replayPlan = try Self.parseResultReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputParseResult,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                var input = try Self.requireInput(
                    command.input,
                    in: db
                )
                guard input.retentionState == .active,
                      input.status == .captured
                else {
                    throw P1ContractValidationError.invalidMembership
                }
                let graph = try Self.requireClaimGraph(
                    command.claim,
                    input: input,
                    auditCampId: command.input.auditCampId,
                    envelope: command.envelope,
                    in: db
                )
                try Self.validateTerminalTime(
                    terminalNow,
                    work: graph.work,
                    attempt: graph.attempt
                )
                try Self.validateParseResult(
                    command.result,
                    input: input,
                    auditCampId: command.input.auditCampId,
                    in: db
                )
                input.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(input.aggregateVersion)
                input.status = command.result.route.status
                input.candidateCampIds = command.result.candidateCampIds
                input.campId = command.result.assignedCampId
                input.errorCode = nil
                input.errorMessage = nil
                input.updatedAt = terminalNow
                let outputJSON = try CanonicalContractCodingV1.string(
                    command.result
                )
                let resultingWork = try DurableWorkStore.complete(
                    claim: command.claim.durableClaim,
                    outputJson: outputJSON,
                    now: terminalNow,
                    businessMutation: { db, _ in
                        try input.update(db)
                    },
                    in: db
                )
                let persisted = try Self.fetchInput(input.id, in: db)
                return try Self.makeInputCommand(
                    branch: .commitInputParse,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    input: persisted,
                    work: resultingWork,
                    workInputHash: graph.work.inputHash
                )
            }
        }
    }

    package func recordParseFailure(
        _ command: RecordInputParseFailureCommandV1,
        terminalNow: Date
    ) throws -> InputCaptureReceiptV1 {
        let branch: P1ResultBranchV1 = command.terminalDisposition
            == .retryScheduled ? .retryInputParse : .failInputParse
        let replayPlan = try Self.parseFailureReplayPlan(
            branch: branch,
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputParseFailure,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                var input = try Self.requireInput(command.input, in: db)
                guard input.retentionState == .active,
                      input.status == .captured
                else {
                    throw P1ContractValidationError.invalidMembership
                }
                let graph = try Self.requireClaimGraph(
                    command.claim,
                    input: input,
                    auditCampId: command.input.auditCampId,
                    envelope: command.envelope,
                    in: db
                )
                try Self.validateTerminalTime(
                    terminalNow,
                    work: graph.work,
                    attempt: graph.attempt
                )
                let derived = try InputParseFailureTerminalDispositionV1
                    .derive(
                        failure: command.failure,
                        attempt: graph.work.attempt,
                        maxAttempts: graph.work.maxAttempts
                    )
                guard derived == command.terminalDisposition else {
                    throw P1ContractValidationError.invalidMembership
                }
                let resolution = try DurableWorkStore.retryOrFail(
                    claim: command.claim.durableClaim,
                    failure: command.failure.durableFailure(),
                    now: terminalNow,
                    terminalBusinessMutation: { _, _ in },
                    in: db
                )
                let resultingWork: DurableWorkRecord
                let notBefore: Date?
                switch resolution {
                case let .retryScheduled(work, date):
                    guard derived == .retryScheduled else {
                        throw P1ContractValidationError.invalidMembership
                    }
                    resultingWork = work
                    notBefore = date
                    input.status = .captured
                case let .failed(work):
                    guard derived == .parseFailed else {
                        throw P1ContractValidationError.invalidMembership
                    }
                    resultingWork = work
                    notBefore = nil
                    input.status = .parseFailed
                }
                input.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(input.aggregateVersion)
                input.errorCode = command.failure.code
                input.errorMessage = command.failure.safeMessage
                input.updatedAt = terminalNow
                try input.update(db)
                let persisted = try Self.fetchInput(input.id, in: db)
                return try Self.makeInputCommand(
                    branch: branch,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    input: persisted,
                    work: resultingWork,
                    workInputHash: graph.work.inputHash,
                    notBefore: notBefore
                )
            }
        }
    }

    package func requeueParsing(
        _ command: RequeueInputParsingCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let replayPlan = try Self.requeueParsingReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputRequeueParsing,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                try Self.requireNoActiveParsing(
                    inputId: command.input.inputId,
                    in: db
                )
                var input = try Self.requireInput(command.input, in: db)
                guard input.status == .parseFailed,
                      input.retentionState == .active
                else {
                    throw P1ContractValidationError.invalidMembership
                }
                input.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(input.aggregateVersion)
                input.status = .captured
                input.errorCode = nil
                input.errorMessage = nil
                input.updatedAt = command.envelope.occurredAt
                try input.update(db)
                let workInput = try InputParsingWorkInputV1(
                    inputId: input.id,
                    contentHash: input.contentHash
                )
                let workJSON = try CanonicalContractCodingV1.string(workInput)
                let workHash = CanonicalJSONV1.sha256Hex(Data(workJSON.utf8))
                let enqueued = try DurableWorkStore.enqueue(
                    campId: command.input.auditCampId,
                    kind: .inputParsing,
                    aggregateType: "input",
                    aggregateId: input.id,
                    inputJson: workJSON,
                    claimedInputHash: workHash,
                    idempotencyKey: try ControlWorkKeyV1.inputParsing(
                        commandHash: prepared.commandPayloadHash
                    ),
                    maxAttempts: 4,
                    traceId: command.envelope.correlationId,
                    now: command.envelope.occurredAt,
                    in: db
                )
                guard enqueued.disposition == .inserted else {
                    throw DomainCommandReplayConflictError()
                }
                return try Self.makeInputCommand(
                    branch: .requeueInputParsing,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    input: try Self.fetchInput(input.id, in: db),
                    work: enqueued.work,
                    workInputHash: workHash
                )
            }
        }
    }

    package func cancelParsingAndDelete(
        _ command: CancelInputParsingAndDeleteCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let replayPlan = try Self.cancelParsingAndDeleteReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputCancelParsingAndDelete,
            envelope: command.envelope,
            payload: command,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                var input = try Self.requireInput(command.input, in: db)
                guard case let .expected(workId, expectedVersion) =
                        command.activeParsingBranch,
                      let work = try DurableWorkRecord.fetchOne(db, key: workId),
                      work.kind == .inputParsing,
                      work.aggregateType == "input",
                      work.aggregateId == input.id,
                      work.campId == command.input.auditCampId,
                      work.version == expectedVersion,
                      [.queued, .running, .retryScheduled].contains(work.state)
                else {
                    throw StaleDurableWorkClaimError()
                }
                input = try Self.tombstone(
                    input,
                    at: command.envelope.occurredAt
                )
                let canceled = try DurableWorkStore.cancel(
                    workId: work.id,
                    expectedVersion: expectedVersion,
                    reason: "input_deleted",
                    now: command.envelope.occurredAt,
                    businessMutation: { db, _ in
                        try input.update(db)
                    },
                    in: db
                )
                let resultingWork: DurableWorkRecord
                switch canceled {
                case let .canceled(work): resultingWork = work
                case .alreadyCanceled: throw StaleDurableWorkClaimError()
                }
                return try Self.makeInputCommand(
                    branch: .cancelInputParsingAndDelete,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    input: try Self.fetchInput(input.id, in: db),
                    work: resultingWork,
                    workInputHash: work.inputHash,
                    deletedAt: command.envelope.occurredAt
                )
            }
        }
    }

    package func requestCampAssignment(
        _ command: RequestInputCampAssignmentCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.requestCampAssignmentReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputRequestCampAssignment,
            branch: .requestCampAssignment,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan
        ) { input, db in
            guard input.status == .captured, input.campId == nil else {
                throw P1ContractValidationError.invalidMembership
            }
            try Self.requireAvailableCampIDs(command.candidateCampIds, in: db)
            input.status = .campAssignmentRequired
            input.candidateCampIds = command.candidateCampIds
        }
    }

    package func recordCampAmbiguity(
        _ command: RecordInputCampAmbiguityCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.recordCampAmbiguityReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputRecordCampAmbiguity,
            branch: .recordCampAmbiguity,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan
        ) { input, db in
            guard input.status == .captured, input.campId == nil else {
                throw P1ContractValidationError.invalidMembership
            }
            try Self.requireAvailableCampIDs(command.candidateCampIds, in: db)
            input.status = .campAmbiguous
            input.candidateCampIds = command.candidateCampIds
        }
    }

    package func assignCamp(
        _ command: AssignInputCampCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.assignCampReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputAssignCamp,
            branch: .assignCamp,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan
        ) { input, db in
            guard input.status == .campAssignmentRequired
                    || input.status == .campAmbiguous,
                  command.targetCampId == command.input.auditCampId
            else {
                throw InputCampScopeError()
            }
            try Self.requireAvailableCampIDs([command.targetCampId], in: db)
            input.status = command.targetStatus
            input.campId = command.targetCampId
            input.candidateCampIds = []
        }
    }

    package func archive(
        _ command: ArchiveInputCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.archiveReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputArchive,
            branch: .archiveInput,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan
        ) { input, _ in
            try Self.requireTransition(input.status, to: .archived)
            input.status = .archived
        }
    }

    package func markCoaching(
        _ command: MarkInputCoachingCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.markCoachingReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputMarkCoaching,
            branch: .markInputCoaching,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan
        ) { input, _ in
            try Self.requireTransition(input.status, to: .coaching)
            input.status = .coaching
            input.campId = command.input.auditCampId
            input.candidateCampIds = []
        }
    }

    package func convertToGoal(
        _ command: ConvertInputToGoalCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.convertToGoalReplayPlan(
            inputId: command.input.inputId,
            goalId: command.goalId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion,
            expectedGoalVersion: 0
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputConvertToGoal,
            envelope: command.envelope,
            payload: command,
            replayPlan: plan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: plan,
                database: db
            ) { db in
                try Self.requireNoActiveParsing(
                    inputId: command.input.inputId,
                    in: db
                )
                var input = try Self.requireInput(command.input, in: db)
                try Self.requireTransition(input.status, to: .goalCreated)
                let goal = try GoalControllerTransitionPolicyV1.createFromInput(
                    input: input,
                    goalId: command.goalId,
                    title: command.title,
                    rawIntent: command.rawIntent,
                    actorId: command.envelope.actorId,
                    now: command.envelope.occurredAt
                )
                input.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(input.aggregateVersion)
                input.status = .goalCreated
                input.candidateCampIds = []
                input.updatedAt = command.envelope.occurredAt
                try input.update(db)
                try goal.insert(db)
                let persistedInput = try Self.fetchInput(input.id, in: db)
                let result = try CampSafeCommandResultV1.make(
                    branch: .convertInputToGoal,
                    values: CampSafeResultValuesV1(
                        commandPayloadHash: prepared.commandPayloadHash,
                        domainEventCount: plan.shapes.count,
                        outboxCount: plan.shapes.count,
                        occurredAt: prepared.envelope.occurredAt,
                        inputId: persistedInput.id,
                        goalId: goal.id,
                        inputContentHash: persistedInput.contentHash,
                        inputProjectionVersion: persistedInput.aggregateVersion,
                        goalProjectionVersion: goal.aggregateVersion,
                        inputEventVersion: persistedInput.aggregateVersion,
                        goalEventVersion: goal.aggregateVersion,
                        candidateCampCount: persistedInput.candidateCampIds.count,
                        capturedAt: persistedInput.capturedAt
                    )
                )
                return try NewDomainCommandV1.make(
                    result: result,
                    replayPlan: plan
                )
            }
        }
    }

    package func requestDeletion(
        _ command: RequestInputDeletionCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.requestDeletionReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputRequestDeletion,
            branch: .requestInputDeletion,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan
        ) { input, _ in
            guard input.retentionState == .active,
                  input.status != .goalCreated,
                  input.status != .deletedTombstone
            else {
                throw P1ContractValidationError.invalidMembership
            }
            input.retentionState = .deletionRequested
        }
    }

    package func completeDeletion(
        _ command: CompleteInputDeletionCommandV1
    ) throws -> InputCaptureReceiptV1 {
        let plan = try Self.completeDeletionReplayPlan(
            inputId: command.input.inputId,
            auditCampId: command.input.auditCampId,
            expectedInputVersion: command.input.expectedInputVersion
        )
        return try executeOrdinary(
            commandType: .inputCompleteDeletion,
            branch: .completeInputDeletion,
            envelope: command.envelope,
            payload: command,
            inputHead: command.input,
            replayPlan: plan,
            deletedAt: command.envelope.occurredAt
        ) { input, _ in
            guard input.retentionState == .deletionRequested else {
                throw P1ContractValidationError.invalidMembership
            }
            input = try Self.tombstone(
                input,
                at: command.envelope.occurredAt,
                incrementVersion: false
            )
        }
    }

    private func executeOrdinary<Payload: Encodable>(
        commandType: P1CommandTypeV1,
        branch: P1ResultBranchV1,
        envelope: CommandEnvelopeV1,
        payload: Payload,
        inputHead: InputHeadV1,
        replayPlan: DomainCommandReplayPlanV1,
        deletedAt: Date? = nil,
        mutation: (inout InputEnvelopeRecord, Database) throws -> Void
    ) throws -> InputCaptureReceiptV1 {
        let prepared = try PreparedDomainCommandV1.make(
            commandType: commandType,
            envelope: envelope,
            payload: payload,
            replayPlan: replayPlan
        )
        return try database.pool.write { db in
            try eventStore.executeCommand(
                command: prepared,
                replayPlan: replayPlan,
                database: db
            ) { db in
                try Self.requireNoActiveParsing(
                    inputId: inputHead.inputId,
                    in: db
                )
                var input = try Self.requireInput(inputHead, in: db)
                try mutation(&input, db)
                input.aggregateVersion = try CanonicalContractCodingV1
                    .checkedIncrement(input.aggregateVersion)
                input.updatedAt = envelope.occurredAt
                try input.update(db)
                return try Self.makeInputCommand(
                    branch: branch,
                    prepared: prepared,
                    replayPlan: replayPlan,
                    input: try Self.fetchInput(input.id, in: db),
                    deletedAt: deletedAt
                )
            }
        }
    }

    private static func requireInput(
        _ head: InputHeadV1,
        in db: Database
    ) throws -> InputEnvelopeRecord {
        guard let input = try InputEnvelopeRecord.fetchOne(
            db,
            key: head.inputId
        ) else {
            throw RecordNotFoundError(
                table: InputEnvelopeRecord.databaseTableName,
                id: head.inputId
            )
        }
        guard input.aggregateVersion == head.expectedInputVersion else {
            throw InputProjectionVersionConflictError()
        }
        let captured = try DomainEventRecordV1
            .filter(Column("aggregateType") == P1AggregateTypeV1.input.rawValue)
            .filter(Column("aggregateId") == head.inputId)
            .filter(Column("aggregateVersion") == 1)
            .fetchAll(db)
        guard captured.count == 1,
              captured[0].eventType == .inputCaptured,
              captured[0].campId == head.auditCampId,
              input.campId == nil || input.campId == head.auditCampId
        else {
            throw InputCampScopeError()
        }
        return input
    }

    private static func requireClaimGraph(
        _ claim: WorkClaimV1,
        input: InputEnvelopeRecord,
        auditCampId: String,
        envelope: CommandEnvelopeV1,
        in db: Database
    ) throws -> InputClaimGraph {
        guard let work = try DurableWorkRecord.fetchOne(db, key: claim.workId),
              let attempt = try DurableWorkAttemptRecord.fetchOne(
                db,
                key: ["workId": claim.workId, "attempt": claim.attempt]
              ),
              work.kind == .inputParsing,
              work.aggregateType == "input",
              work.aggregateId == input.id,
              work.campId == auditCampId,
              work.state == .running,
              work.version == claim.version,
              work.attempt == claim.attempt,
              work.maxAttempts == 4,
              work.leaseOwner == claim.workerId,
              work.leaseExpiresAt == claim.leaseExpiresAt
        else {
            throw StaleDurableWorkClaimError()
        }
        let expectedEnvelope = try ControlWorkerCommandEnvelopeFactoryV1.make(
            work: work,
            attempt: attempt,
            claim: claim.durableClaim
        )
        guard expectedEnvelope == envelope else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        let workInput = try CanonicalContractCodingV1.decode(
            InputParsingWorkInputV1.self,
            from: Data(work.inputJson.utf8)
        )
        guard workInput.inputId == input.id,
              workInput.contentHash == input.contentHash,
              CanonicalJSONV1.sha256Hex(Data(work.inputJson.utf8))
                == work.inputHash
        else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        return InputClaimGraph(work: work, attempt: attempt)
    }

    private static func validateTerminalTime(
        _ terminalNow: Date,
        work: DurableWorkRecord,
        attempt: DurableWorkAttemptRecord
    ) throws {
        do {
            try CanonicalContractCodingV1.validateFinite(terminalNow)
        } catch {
            throw ControlWorkerTerminalTimeError()
        }
        guard terminalNow >= work.updatedAt,
              terminalNow >= attempt.startedAt
        else {
            throw ControlWorkerTerminalTimeError()
        }
    }

    private static func validateParseResult(
        _ result: InputParseResultV1,
        input: InputEnvelopeRecord,
        auditCampId: String,
        in db: Database
    ) throws {
        switch result.route {
        case .campAssignmentRequired, .campAmbiguous:
            guard input.campId == nil, result.assignedCampId == nil else {
                throw InputCampScopeError()
            }
        case .coaching, .archived:
            guard result.assignedCampId == auditCampId else {
                throw InputCampScopeError()
            }
        }
        var camps = result.candidateCampIds
        if let assignedCampId = result.assignedCampId {
            camps.append(assignedCampId)
        }
        try requireAvailableCampIDs(camps.sorted(), in: db)
    }

    private static func requireAvailableCampIDs(
        _ campIds: [String],
        in db: Database
    ) throws {
        try InputContractValidationV1.validateCampIDs(campIds)
        for campId in campIds {
            let archived = try Int.fetchOne(
                db,
                sql: "SELECT archived FROM camp WHERE id=?",
                arguments: [campId]
            )
            guard archived == 0 else {
                throw DomainCommandCampUnavailableError()
            }
        }
    }

    private static func requireNoActiveParsing(
        inputId: String,
        in db: Database
    ) throws {
        let count = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*) FROM durable_work
                WHERE kind='inputParsing'
                  AND aggregateType='input'
                  AND aggregateId=?
                  AND state IN ('queued','running','retryScheduled')
                """,
            arguments: [inputId]
        )
        guard count == 0 else {
            throw InputActiveParsingConflictError()
        }
    }

    private static func requireTransition(
        _ from: InputEnvelopeStatusV1,
        to: InputEnvelopeStatusV1
    ) throws {
        guard InputTransitionPolicyV1.allows(.init(from: from, to: to)) else {
            throw P1ContractValidationError.invalidMembership
        }
    }

    private static func tombstone(
        _ current: InputEnvelopeRecord,
        at deletedAt: Date,
        incrementVersion: Bool = true
    ) throws -> InputEnvelopeRecord {
        try CanonicalContractCodingV1.validateFinite(deletedAt)
        var input = current
        if incrementVersion {
            input.aggregateVersion = try CanonicalContractCodingV1
                .checkedIncrement(input.aggregateVersion)
        }
        input.sourceDeviceId = nil
        input.connectorId = nil
        input.authorId = nil
        input.inlineText = nil
        input.payloadRef = nil
        input.candidateCampIds = []
        input.explicitIntent = .unspecified
        input.privacyLevel = .localOnly
        input.status = .deletedTombstone
        input.errorCode = nil
        input.errorMessage = nil
        input.parentInputId = nil
        input.retentionState = .deletedTombstone
        input.updatedAt = deletedAt
        input.deletedAt = deletedAt
        return input
    }

    private static func fetchInput(
        _ id: String,
        in db: Database
    ) throws -> InputEnvelopeRecord {
        guard let input = try InputEnvelopeRecord.fetchOne(db, key: id) else {
            throw RecordNotFoundError(
                table: InputEnvelopeRecord.databaseTableName,
                id: id
            )
        }
        return input
    }

    private static func makeInputCommand(
        branch: P1ResultBranchV1,
        prepared: PreparedDomainCommandV1,
        replayPlan: DomainCommandReplayPlanV1,
        input: InputEnvelopeRecord,
        work: DurableWorkRecord? = nil,
        workInputHash: String? = nil,
        deletedAt: Date? = nil,
        notBefore: Date? = nil
    ) throws -> NewDomainCommandV1 {
        let result = try CampSafeCommandResultV1.make(
            branch: branch,
            values: CampSafeResultValuesV1(
                commandPayloadHash: prepared.commandPayloadHash,
                domainEventCount: replayPlan.shapes.count,
                outboxCount: replayPlan.shapes.count,
                occurredAt: prepared.envelope.occurredAt,
                inputId: input.id,
                durableWorkId: work?.id,
                inputContentHash: input.contentHash,
                durableWorkInputHash: workInputHash,
                inputProjectionVersion: input.aggregateVersion,
                durableWorkVersion: work?.version,
                inputEventVersion: input.aggregateVersion,
                candidateCampCount: input.candidateCampIds.count,
                attemptCount: work?.attempt,
                capturedAt: input.capturedAt,
                deletedAt: deletedAt,
                notBefore: notBefore
            )
        )
        return try NewDomainCommandV1.make(
            result: result,
            replayPlan: replayPlan
        )
    }

    package static func captureReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .captureInput,
            commandType: .inputCapture,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputCaptured,
            auditCode: .inputCaptured
        )
    }

    package static func parseResultReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .commitInputParse,
            commandType: .inputParseResult,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputParseCommitted,
            auditCode: .inputParseCommitted
        )
    }

    package static func parseFailureReplayPlan(
        branch: P1ResultBranchV1,
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        guard branch == .retryInputParse || branch == .failInputParse else {
            throw P1ContractValidationError.invalidMembership
        }
        return try inputPlan(
            branch: branch,
            commandType: .inputParseFailure,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputParseAttemptFailed,
            auditCode: branch == .retryInputParse
                ? .inputParseRetryScheduled : .inputParseFailed
        )
    }

    package static func requeueParsingReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .requeueInputParsing,
            commandType: .inputRequeueParsing,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputParsingRequeued,
            auditCode: .inputParsingRequeued
        )
    }

    package static func cancelParsingAndDeleteReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .cancelInputParsingAndDelete,
            commandType: .inputCancelParsingAndDelete,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputDeleted,
            auditCode: .inputDeleted
        )
    }

    package static func requestCampAssignmentReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .requestCampAssignment,
            commandType: .inputRequestCampAssignment,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputCampAssignmentRequired,
            auditCode: .inputCampAssignmentRequired
        )
    }

    package static func recordCampAmbiguityReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .recordCampAmbiguity,
            commandType: .inputRecordCampAmbiguity,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputCampAmbiguityRecorded,
            auditCode: .inputCampAmbiguous
        )
    }

    package static func assignCampReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .assignCamp,
            commandType: .inputAssignCamp,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputCampAssigned,
            auditCode: .inputCampAssigned
        )
    }

    package static func archiveReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .archiveInput,
            commandType: .inputArchive,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputArchived,
            auditCode: .inputArchived
        )
    }

    package static func markCoachingReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .markInputCoaching,
            commandType: .inputMarkCoaching,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputCoachingStarted,
            auditCode: .inputCoaching
        )
    }

    package static func convertToGoalReplayPlan(
        inputId: String,
        goalId: String,
        auditCampId: String,
        expectedInputVersion: Int,
        expectedGoalVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try DomainCommandReplayPlanV1(
            branch: .convertInputToGoal,
            commandType: .inputConvertToGoal,
            shapes: [
                shape(
                    campId: auditCampId,
                    aggregateType: .input,
                    aggregateId: inputId,
                    expectedVersion: expectedInputVersion,
                    eventType: .inputGoalCreated,
                    auditCode: .inputGoalCreated
                ),
                shape(
                    campId: auditCampId,
                    aggregateType: .goal,
                    aggregateId: goalId,
                    expectedVersion: expectedGoalVersion,
                    eventType: .goalCreated,
                    auditCode: .goalCreated
                ),
            ]
        )
    }

    package static func requestDeletionReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .requestInputDeletion,
            commandType: .inputRequestDeletion,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputDeletionRequested,
            auditCode: .inputDeletionRequested
        )
    }

    package static func completeDeletionReplayPlan(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws -> DomainCommandReplayPlanV1 {
        try inputPlan(
            branch: .completeInputDeletion,
            commandType: .inputCompleteDeletion,
            inputId: inputId,
            auditCampId: auditCampId,
            expectedInputVersion: expectedInputVersion,
            eventType: .inputDeleted,
            auditCode: .inputDeleted
        )
    }

    private static func inputPlan(
        branch: P1ResultBranchV1,
        commandType: P1CommandTypeV1,
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int,
        eventType: P1EventTypeV1,
        auditCode: P1AuditCodeV1
    ) throws -> DomainCommandReplayPlanV1 {
        try DomainCommandReplayPlanV1(
            branch: branch,
            commandType: commandType,
            shapes: [
                shape(
                    campId: auditCampId,
                    aggregateType: .input,
                    aggregateId: inputId,
                    expectedVersion: expectedInputVersion,
                    eventType: eventType,
                    auditCode: auditCode
                ),
            ]
        )
    }

    private static func shape(
        campId: String,
        aggregateType: P1AggregateTypeV1,
        aggregateId: String,
        expectedVersion: Int,
        eventType: P1EventTypeV1,
        auditCode: P1AuditCodeV1
    ) -> DomainEventReplayShapeV1 {
        DomainEventReplayShapeV1(
            campId: campId,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            expectedAggregateVersion: expectedVersion,
            eventType: eventType,
            auditCode: auditCode
        )
    }
}

private struct InputClaimGraph {
    let work: DurableWorkRecord
    let attempt: DurableWorkAttemptRecord
}
