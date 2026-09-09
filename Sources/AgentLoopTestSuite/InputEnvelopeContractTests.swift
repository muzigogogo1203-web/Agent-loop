import Foundation
import GRDB
import Testing
import AgentLoopCore
import AgentLoopApplication

private let p1cInputCampID = "p1c-input-camp"
private let p1cInputOtherCampID = "p1c-input-other-camp"
private let p1cInputID = "77777777-7777-7777-7777-777777777777"
private let p1cInputParentID = "88888888-8888-8888-8888-888888888888"
private let p1cInputDeviceID = "99999999-9999-9999-9999-999999999999"
private let p1cInputWorkID = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
private let p1cInputHash = String(repeating: "d", count: 64)

private enum P1CInputTestError: Error {
    case renewalFailed
    case forcedMutationFailure
}

private final class P1CInputLockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    func withValue<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&storage)
    }

    var value: Value { withValue { $0 } }
}

private final class P1CInputIdentityMemoryStore:
    LocalCaptureIdentityStore, @unchecked Sendable
{
    private let lock = NSLock()
    private var stored: String?
    private(set) var generationCount = 0
    private(set) var writeCount = 0

    init(stored: String? = nil) {
        self.stored = stored
    }

    func getOrCreateCanonicalUUID(
        forKey key: String,
        makeUUID: @Sendable () -> UUID
    ) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        #expect(key == "agentloop.localCaptureInstallationId")
        if let stored {
            guard let uuid = UUID(uuidString: stored), uuid.uuidString == stored else {
                throw P1ContractValidationError.invalidIdentifier
            }
            return stored
        }
        generationCount += 1
        let generated = makeUUID().uuidString
        stored = generated
        writeCount += 1
        return generated
    }

    func snapshot() -> (String?, Int, Int) {
        lock.lock()
        defer { lock.unlock() }
        return (stored, generationCount, writeCount)
    }
}

private func p1cInputDatabase(_ label: String) throws -> AppDatabase {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("p1c-input-\(label)-\(UUID().uuidString).sqlite")
        .path
    let database = try AppDatabase(path: path)
    try database.pool.write { db in
        for id in [p1cInputCampID, p1cInputOtherCampID] {
            try db.execute(
                sql: """
                    INSERT INTO camp (id, name, archived, createdAt)
                    VALUES (?, ?, 0, 1)
                    """,
                arguments: [id, id]
            )
            try db.execute(
                sql: """
                    INSERT INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?,'active',1,1,1,NULL,NULL)
                    """,
                arguments: [id]
            )
        }
    }
    return database
}

private func p1cInputUserEnvelope(
    key: String,
    occurredAt: Date = Date(timeIntervalSince1970: 100),
    deviceId: String? = p1cInputDeviceID,
    actorType: DomainActorType = .user,
    actorId: String = "user:local-owner"
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: actorType,
        actorId: actorId,
        deviceId: deviceId,
        correlationId: "input-trace",
        causationId: nil,
        occurredAt: occurredAt
    )
}

private func p1cCaptureCommand(
    key: String = "input-capture",
    inputId: String = p1cInputID,
    auditCampId: String = p1cInputCampID,
    initialCampId: String? = p1cInputCampID,
    inlineText: String? = "capture body",
    payloadRef: String? = nil,
    sourceDeviceId: String? = p1cInputDeviceID,
    candidateCampIds: [String] = []
) throws -> CaptureInputCommandV1 {
    try CaptureInputCommandV1(
        envelope: p1cInputUserEnvelope(key: key),
        inputId: inputId,
        auditCampId: auditCampId,
        initialCampId: initialCampId,
        sourceType: .text,
        sourceDeviceId: sourceDeviceId,
        connectorId: nil,
        authorId: "user:local-owner",
        capturedAt: Date(timeIntervalSince1970: 90),
        inlineText: inlineText,
        payloadRef: payloadRef,
        contentHash: p1cInputHash,
        candidateCampIds: candidateCampIds,
        explicitIntent: .unspecified,
        privacyLevel: .localOnly,
        parentInputId: nil
    )
}

private func p1cCaptured(
    _ database: AppDatabase,
    command suppliedCommand: CaptureInputCommandV1? = nil
) throws -> (InputGoalStore, InputCaptureReceiptV1, InputEnvelopeRecord, DurableWorkRecord) {
    let command: CaptureInputCommandV1
    if let suppliedCommand {
        command = suppliedCommand
    } else {
        command = try p1cCaptureCommand()
    }
    let store = InputGoalStore(database: database)
    let receipt = try store.captureAndEnqueueParsing(command)
    let fetchedInput = try store.input(id: command.inputId)
    let input = try #require(fetchedInput)
    let fetchedWork = try DurableWorkStore(database: database).activeWork(
        kind: .inputParsing,
        aggregateType: "input",
        aggregateId: command.inputId
    )
    let work = try #require(fetchedWork)
    return (store, receipt, input, work)
}

private func p1cClaimInputWork(
    _ database: AppDatabase,
    workerId: String = "input-worker",
    now: Date = Date(timeIntervalSince1970: 110)
) throws -> DurableWorkClaim {
    let claim = try DurableWorkStore(database: database).claimNext(
        kinds: [.inputParsing],
        workerId: workerId,
        now: now,
        leaseDuration: 60
    )
    return try #require(claim)
}

private func p1cWorkerEnvelope(
    _ database: AppDatabase,
    claim: DurableWorkClaim
) throws -> CommandEnvelopeV1 {
    try database.pool.read { db in
        let fetchedWork = try DurableWorkRecord.fetchOne(
            db,
            key: claim.workId
        )
        let work = try #require(fetchedWork)
        let fetchedAttempt = try DurableWorkAttemptRecord.fetchOne(
            db,
            key: ["workId": claim.workId, "attempt": claim.attempt]
        )
        let attempt = try #require(fetchedAttempt)
        return try ControlWorkerCommandEnvelopeFactoryV1.make(
            work: work,
            attempt: attempt,
            claim: claim
        )
    }
}

private func p1cInputHead(
    version: Int = 1,
    campId: String = p1cInputCampID
) throws -> InputHeadV1 {
    try InputHeadV1(
        inputId: p1cInputID,
        auditCampId: campId,
        expectedInputVersion: version
    )
}

private func p1cParseResult(
    _ database: AppDatabase,
    claim: DurableWorkClaim,
    route: InputParseRouteV1 = .coaching,
    assignedCampId: String? = p1cInputCampID,
    candidateCampIds: [String] = [],
    terminalNow: Date = Date(timeIntervalSince1970: 120)
) throws -> InputCaptureReceiptV1 {
    let command = try CommitInputParseResultCommandV1(
        envelope: p1cWorkerEnvelope(database, claim: claim),
        input: p1cInputHead(),
        claim: WorkClaimV1(claim: claim),
        result: InputParseResultV1(
            route: route,
            candidateCampIds: candidateCampIds,
            assignedCampId: assignedCampId
        )
    )
    return try InputGoalStore(database: database).commitParseResult(
        command,
        terminalNow: terminalNow
    )
}

private func p1cRecordTransientFailure(
    _ database: AppDatabase,
    claim: DurableWorkClaim,
    terminalNow: Date
) throws -> InputCaptureReceiptV1 {
    let currentInput = try InputGoalStore(database: database)
        .input(id: p1cInputID)
    let expectedVersion = try #require(currentInput).aggregateVersion
    let failure = try ControlWorkerProviderFailureV1(
        code: "provider_unavailable",
        safeMessage: "retry",
        disposition: .transient
    )
    let command = try RecordInputParseFailureCommandV1(
        envelope: p1cWorkerEnvelope(database, claim: claim),
        input: p1cInputHead(version: expectedVersion),
        claim: WorkClaimV1(claim: claim),
        failure: failure,
        terminalDisposition: InputParseFailureTerminalDispositionV1.derive(
            failure: failure,
            attempt: claim.attempt,
            maxAttempts: 4
        )
    )
    return try InputGoalStore(database: database).recordParseFailure(
        command,
        terminalNow: terminalNow
    )
}

private func p1cInputCounts(_ database: AppDatabase) throws -> [String: Int] {
    try database.pool.read { db in
        var result: [String: Int] = [:]
        for table in [
            "input_envelope", "goal_controller", "durable_work",
            "domain_command_receipt", "domain_event", "event_outbox",
        ] {
            result[table] = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM \(table)"
            ) ?? -1
        }
        return result
    }
}

@Suite(.serialized)
struct P1CInputEnvelopeContractTests {
    @Test func captureAndInputParsingWorkCommitAtomically() throws {
        let database = try p1cInputDatabase("capture-atomic")
        let (_, receipt, input, work) = try p1cCaptured(database)
        #expect(receipt.code == .inputCaptured)
        #expect(input.id == p1cInputID)
        #expect(input.status == .captured)
        #expect(input.aggregateVersion == 1)
        #expect(work.kind == .inputParsing)
        #expect(work.aggregateId == input.id)
        #expect(work.campId == p1cInputCampID)
        #expect(work.maxAttempts == 4)
        #expect(try p1cInputCounts(database) == [
            "input_envelope": 1, "goal_controller": 0, "durable_work": 1,
            "domain_command_receipt": 1, "domain_event": 1,
            "event_outbox": 1,
        ])
    }

    @Test func inputCaptureReplayAndPayloadDriftConflict() throws {
        let database = try p1cInputDatabase("capture-replay")
        let store = InputGoalStore(database: database)
        let command = try p1cCaptureCommand()
        let first = try store.captureAndEnqueueParsing(command)
        let before = try p1cInputCounts(database)
        #expect(try store.captureAndEnqueueParsing(command) == first)
        #expect(try p1cInputCounts(database) == before)
        let drift = try p1cCaptureCommand(inlineText: "changed")
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try store.captureAndEnqueueParsing(drift)
        }
        #expect(try p1cInputCounts(database) == before)
    }

    @Test func inputCaptureReplayUsesCallerOwnedIDAndExistingWorkResult() throws {
        let database = try p1cInputDatabase("caller-id")
        let (store, first, input, work) = try p1cCaptured(database)
        let replay = try store.captureAndEnqueueParsing(p1cCaptureCommand())
        #expect(replay == first)
        #expect(input.id == p1cInputID)
        #expect(replay.refs.first(where: { $0.kind == .input })?.id == input.id)
        #expect(replay.refs.first(where: { $0.kind == .durableWork })?.id == work.id)
        #expect(try DurableWorkStore(database: database).latestWork(
            kind: .inputParsing,
            aggregateType: "input",
            aggregateId: p1cInputID
        )?.id == work.id)
    }

    @Test func inputParsingCrashIsAdopted() throws {
        let database = try p1cInputDatabase("crash-adopt")
        _ = try p1cCaptured(database)
        let claim = try p1cClaimInputWork(database)
        let durable = DurableWorkStore(database: database)
        #expect(try durable.adoptExpiredControlWork(
            kind: .inputParsing,
            currentWorkerId: claim.workerId,
            now: claim.leaseExpiresAt.addingTimeInterval(-0.001)
        ).isEmpty)
        let adopted = try durable.adoptExpiredControlWork(
            kind: .inputParsing,
            currentWorkerId: "replacement",
            now: claim.leaseExpiresAt
        )
        #expect(adopted.count == 1)
        #expect(adopted[0].state == .queued)
        let fetchedNext = try durable.claimNext(
            kinds: [.inputParsing], workerId: "replacement",
            now: claim.leaseExpiresAt, leaseDuration: 60
        )
        let next = try #require(fetchedNext)
        #expect(next.attempt == claim.attempt + 1)
    }

    @Test func controlWorkAdoptionRequiresExpiredLeaseAndRecoversSameOwnerAcrossKinds() throws {
        for (kind, recoveryWorker) in [
            (DurableWorkKind.inputParsing, "owner"),
            (.coach, "replacement"),
        ] {
            let database = try p1cInputDatabase("adopt-\(kind.rawValue)")
            let durable = DurableWorkStore(database: database)
            if kind == .inputParsing {
                _ = try p1cCaptured(database)
            } else {
                let bytes = Data("{}".utf8)
                _ = try durable.enqueue(
                    campId: p1cInputCampID, kind: .coach,
                    aggregateType: "goal", aggregateId: p1cInputID,
                    inputJson: "{}",
                    claimedInputHash: CanonicalJSONV1.sha256Hex(bytes),
                    idempotencyKey: "coach-control", maxAttempts: 4,
                    traceId: "coach-trace", now: Date(timeIntervalSince1970: 100)
                )
            }
            let fetchedClaim = try durable.claimNext(
                kinds: [kind], workerId: "owner",
                now: Date(timeIntervalSince1970: 110), leaseDuration: 60
            )
            let claim = try #require(fetchedClaim)
            #expect(try durable.adoptExpiredControlWork(
                kind: kind, currentWorkerId: recoveryWorker,
                now: Date(timeIntervalSince1970: 169.999)
            ).isEmpty)
            let adopted = try durable.adoptExpiredControlWork(
                kind: kind, currentWorkerId: recoveryWorker,
                now: Date(timeIntervalSince1970: 170)
            )
            #expect(adopted.count == 1)
            #expect(adopted[0].attempt == claim.attempt)
            #expect(adopted[0].errorCode == "worker_interrupted")
        }
    }

    @Test func inputParsingRenewalHandsLatestClaimToTerminalCommit() throws {
        let database = try p1cInputDatabase("latest-claim")
        _ = try p1cCaptured(database)
        let durable = DurableWorkStore(database: database)
        let initial = try p1cClaimInputWork(database)
        let renewed = try durable.renewLease(
            claim: initial,
            now: Date(timeIntervalSince1970: 115),
            leaseDuration: 60
        )
        _ = try p1cParseResult(
            database,
            claim: renewed,
            terminalNow: Date(timeIntervalSince1970: 120)
        )
        let fetchedWork = try durable.work(id: renewed.workId)
        let work = try #require(fetchedWork)
        #expect(work.state == .succeeded)
        #expect(work.version == renewed.version + 1)
    }

    @Test func inputParsingTerminalTimeIsMonotonicAndRetryBackoffStartsAtFailure() throws {
        let database = try p1cInputDatabase("terminal-time")
        _ = try p1cCaptured(database)
        let claim = try p1cClaimInputWork(database)
        #expect(throws: ControlWorkerTerminalTimeError.self) {
            _ = try p1cRecordTransientFailure(
                database,
                claim: claim,
                terminalNow: Date(timeIntervalSince1970: 109)
            )
        }
        let fetchedRunning = try DurableWorkStore(database: database)
            .work(id: claim.workId)
        let running = try #require(fetchedRunning)
        #expect(running.state == .running)
        _ = try p1cRecordTransientFailure(
            database,
            claim: claim,
            terminalNow: Date(timeIntervalSince1970: 200)
        )
        let fetchedRetry = try DurableWorkStore(database: database)
            .work(id: claim.workId)
        let retry = try #require(fetchedRetry)
        #expect(retry.state == .retryScheduled)
        #expect(retry.updatedAt == Date(timeIntervalSince1970: 200))
        #expect(retry.notBefore == Date(timeIntervalSince1970: 205))
    }

    @Test func inputParsingRenewalFailureCancelsParserWithoutProjectionCommit() async throws {
        let database = try p1cInputDatabase("renewal-failure")
        _ = try p1cCaptured(database)
        let parserCancelled = P1CInputLockedBox(false)
        let worker = try InputParsingWorker(
            database: database,
            workerId: "worker",
            clock: { Date(timeIntervalSince1970: 110) },
            sleep: { _ in throw P1CInputTestError.renewalFailed },
            parser: { _ in
                do {
                    try await Task.sleep(for: .seconds(30))
                    return .canceled
                } catch {
                    parserCancelled.withValue { $0 = true }
                    return .canceled
                }
            }
        )
        await #expect(throws: P1CInputTestError.self) {
            _ = try await worker.runNext()
        }
        #expect(parserCancelled.value)
        let fetchedInput = try InputGoalStore(database: database)
            .input(id: p1cInputID)
        let input = try #require(fetchedInput)
        #expect(input.status == .captured)
        #expect(try p1cInputCounts(database)["domain_event"] == 1)
    }

    @Test func inputParsingRetriesBoundedlyThenParseFailed() throws {
        let database = try p1cInputDatabase("bounded-retry")
        _ = try p1cCaptured(database)
        let durable = DurableWorkStore(database: database)
        var now = Date(timeIntervalSince1970: 110)
        for attempt in 1 ... 4 {
            let fetchedClaim = try durable.claimNext(
                kinds: [.inputParsing], workerId: "worker",
                now: now, leaseDuration: 60
            )
            let claim = try #require(fetchedClaim)
            #expect(claim.attempt == attempt)
            _ = try p1cRecordTransientFailure(
                database,
                claim: claim,
                terminalNow: now.addingTimeInterval(1)
            )
            let fetchedWork = try durable.work(id: claim.workId)
            let work = try #require(fetchedWork)
            if attempt < 4 {
                #expect(work.state == .retryScheduled)
                now = try #require(work.notBefore)
            } else {
                #expect(work.state == .failed)
                #expect(try InputGoalStore(database: database)
                    .input(id: p1cInputID)?.status == .parseFailed)
            }
        }
    }

    @Test func inputParsingCancelRejectsStaleResult() throws {
        let database = try p1cInputDatabase("stale-cancel")
        let (store, _, _, work) = try p1cCaptured(database)
        let command = try CancelInputParsingAndDeleteCommandV1(
            envelope: p1cInputUserEnvelope(key: "cancel"),
            input: p1cInputHead(),
            activeParsingBranch: .expected(
                workId: work.id,
                expectedVersion: work.version + 1
            )
        )
        #expect(throws: StaleDurableWorkClaimError.self) {
            _ = try store.cancelParsingAndDelete(command)
        }
        #expect(try store.input(id: p1cInputID)?.status == .captured)
        #expect(try DurableWorkStore(database: database).work(id: work.id)?.state == .queued)
    }

    @Test func cancelParsingAndDeleteRejectsNoActiveBranchBeforeMutation() throws {
        #expect(throws: P1ContractValidationError.self) {
            _ = try CancelInputParsingAndDeleteCommandV1(
                envelope: p1cInputUserEnvelope(key: "cancel-none"),
                input: p1cInputHead(),
                activeParsingBranch: .none
            )
        }
    }

    @Test func inputParsingTerminalMutationRollbackIsTotal() throws {
        let database = try p1cInputDatabase("terminal-rollback")
        _ = try p1cCaptured(database)
        let claim = try p1cClaimInputWork(database)
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE input_envelope SET aggregateVersion=2 WHERE id=?",
                arguments: [p1cInputID]
            )
        }
        #expect(throws: InputProjectionVersionConflictError.self) {
            _ = try p1cParseResult(database, claim: claim)
        }
        let fetchedWork = try DurableWorkStore(database: database)
            .work(id: claim.workId)
        let work = try #require(fetchedWork)
        #expect(work.state == .running)
        #expect(try p1cInputCounts(database)["domain_event"] == 1)
        #expect(try p1cInputCounts(database)["domain_command_receipt"] == 1)
    }

    @Test func inputTransitionMatrixAcceptsOnlyStageSpecEdges() throws {
        let legal: Set<InputTransitionEdgeV1> = [
            .init(from: .captured, to: .campAssignmentRequired),
            .init(from: .captured, to: .campAmbiguous),
            .init(from: .captured, to: .coaching),
            .init(from: .captured, to: .archived),
            .init(from: .captured, to: .goalCreated),
            .init(from: .parseFailed, to: .captured),
            .init(from: .campAssignmentRequired, to: .coaching),
            .init(from: .campAssignmentRequired, to: .archived),
            .init(from: .campAssignmentRequired, to: .goalCreated),
            .init(from: .campAmbiguous, to: .coaching),
            .init(from: .campAmbiguous, to: .archived),
            .init(from: .campAmbiguous, to: .goalCreated),
            .init(from: .coaching, to: .archived),
            .init(from: .coaching, to: .goalCreated),
        ]
        for source in InputEnvelopeStatusV1.allCases {
            for target in InputEnvelopeStatusV1.allCases {
                let edge = InputTransitionEdgeV1(from: source, to: target)
                #expect(InputTransitionPolicyV1.allows(edge) == legal.contains(edge))
            }
        }
    }

    @Test func ordinaryInputTransitionsRejectEveryActiveParsingStateWithoutWrites() throws {
        for state in [
            DurableWorkState.queued, .running, .retryScheduled,
        ] {
            let database = try p1cInputDatabase("active-\(state.rawValue)")
            let (store, _, _, originalWork) = try p1cCaptured(database)
            let durable = DurableWorkStore(database: database)
            switch state {
            case .running:
                _ = try p1cClaimInputWork(database)
            case .retryScheduled:
                let claim = try p1cClaimInputWork(database)
                let failure = try DurableWorkFailure(
                    code: "retry", message: "retry",
                    disposition: .transient, usageJson: nil
                )
                _ = try durable.retryOrFail(
                    claim: claim,
                    failure: failure,
                    now: Date(timeIntervalSince1970: 120),
                    terminalBusinessMutation: { _, _ in }
                )
            default:
                break
            }
            let fetchedWork = try durable.work(id: originalWork.id)
            let work = try #require(fetchedWork)
            #expect(work.state == state)
            let before = try p1cInputCounts(database)
            let input = try p1cInputHead()
            let envelope = try p1cInputUserEnvelope(
                key: "ordinary-\(state.rawValue)"
            )
            let operations: [() throws -> Void] = [
                { _ = try store.requestCampAssignment(
                    RequestInputCampAssignmentCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none,
                        candidateCampIds: [p1cInputCampID]
                    )
                ) },
                { _ = try store.recordCampAmbiguity(
                    RecordInputCampAmbiguityCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none,
                        candidateCampIds: [p1cInputCampID, p1cInputOtherCampID]
                    )
                ) },
                { _ = try store.assignCamp(
                    AssignInputCampCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none,
                        targetCampId: p1cInputCampID, targetStatus: .coaching
                    )
                ) },
                { _ = try store.archive(
                    ArchiveInputCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none
                    )
                ) },
                { _ = try store.markCoaching(
                    MarkInputCoachingCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none
                    )
                ) },
                { _ = try store.convertToGoal(
                    ConvertInputToGoalCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none,
                        goalId: p1cInputParentID,
                        title: "Goal", rawIntent: "Intent"
                    )
                ) },
                { _ = try store.requestDeletion(
                    RequestInputDeletionCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none
                    )
                ) },
                { _ = try store.completeDeletion(
                    CompleteInputDeletionCommandV1(
                        envelope: envelope, input: input,
                        activeParsingBranch: .none
                    )
                ) },
            ]
            for operation in operations {
                #expect(throws: InputActiveParsingConflictError.self) {
                    try operation()
                }
                #expect(try p1cInputCounts(database) == before)
            }
        }
    }

    @Test func everyInputCommandEnforcesExactActorAndDeviceMatrixBeforeSQL() throws {
        let database = try p1cInputDatabase("authorization")
        let before = try p1cInputCounts(database)
        let userCommands: [P1CommandTypeV1] = [
            .inputCapture, .inputRequeueParsing,
            .inputCancelParsingAndDelete, .inputRequestCampAssignment,
            .inputRecordCampAmbiguity, .inputAssignCamp, .inputArchive,
            .inputMarkCoaching, .inputConvertToGoal,
            .inputRequestDeletion, .inputCompleteDeletion,
        ]
        let parserCommands: [P1CommandTypeV1] = [
            .inputParseResult, .inputParseFailure,
        ]
        for command in userCommands {
            let bad = try CommandEnvelopeV1(
                idempotencyKey: "bad-\(command.rawValue)",
                actorType: .system, actorId: "system:input-parser:v1",
                deviceId: nil, correlationId: "trace", causationId: nil,
                occurredAt: Date(timeIntervalSince1970: 1)
            )
            #expect(throws: P1CommandAuthorizationError.self) {
                try P1CommandAuthorizationV1.validate(
                    commandType: command, envelope: bad
                )
            }
        }
        for command in parserCommands {
            let bad = try p1cInputUserEnvelope(key: "bad-\(command.rawValue)")
            #expect(throws: P1CommandAuthorizationError.self) {
                try P1CommandAuthorizationV1.validate(
                    commandType: command, envelope: bad
                )
            }
        }
        #expect(try p1cInputCounts(database) == before)
    }

    @Test func inputParserInterfaceUsesOnePersistedPreAwaitSnapshotAndClosedOutcome() async throws {
        let database = try p1cInputDatabase("provider-snapshot")
        _ = try p1cCaptured(database)
        let requestBox = P1CInputLockedBox<InputParsingProviderRequestV1?>(nil)
        let parsed = try InputParseResultV1(
            route: .coaching,
            candidateCampIds: [],
            assignedCampId: p1cInputCampID
        )
        let worker = try InputParsingWorker(
            database: database,
            workerId: "worker",
            clock: {
                requestBox.value == nil
                    ? Date(timeIntervalSince1970: 110)
                    : Date(timeIntervalSince1970: 120)
            },
            sleep: { _ in try await Task.sleep(for: .seconds(30)) },
            parser: { request in
                requestBox.withValue { $0 = request }
                do {
                    try database.pool.write { db in
                        try db.execute(
                            sql: "UPDATE input_envelope SET inlineText='mutated-after-snapshot' WHERE id=?",
                            arguments: [p1cInputID]
                        )
                    }
                } catch {
                    Issue.record("provider test mutation failed: \(error)")
                    return .canceled
                }
                return .parsed(parsed)
            }
        )
        #expect(try await worker.runNext())
        let request = try #require(requestBox.value)
        #expect(request.inputId == p1cInputID)
        #expect(request.inlineText == "capture body")
        #expect(request.auditCampId == p1cInputCampID)
        #expect(request.sourceType == .text)
        #expect(request.contentHash == p1cInputHash)
    }

    @Test func inputParserInvalidOutputFailsDeterministicallyExactlyOnce() async throws {
        let database = try p1cInputDatabase("invalid-output")
        _ = try p1cCaptured(database)
        let calls = P1CInputLockedBox(0)
        let invalidResult = try InputParseResultV1(
            route: .coaching,
            candidateCampIds: [],
            assignedCampId: p1cInputOtherCampID
        )
        let worker = try InputParsingWorker(
            database: database,
            workerId: "worker",
            clock: { Date(timeIntervalSince1970: 120) },
            sleep: { _ in try await Task.sleep(for: .seconds(30)) },
            parser: { _ in
                calls.withValue { $0 += 1 }
                return .parsed(invalidResult)
            }
        )
        #expect(try await worker.runNext())
        let fetchedWork = try DurableWorkStore(database: database).latestWork(
            kind: .inputParsing,
            aggregateType: "input",
            aggregateId: p1cInputID
        )
        let work = try #require(fetchedWork)
        #expect(work.state == .failed)
        #expect(work.errorCode == "input_parser_invalid_output")
        #expect(calls.value == 1)
        let before = try p1cInputCounts(database)
        #expect(!(try await worker.runNext()))
        #expect(calls.value == 1)
        #expect(try p1cInputCounts(database) == before)
    }

    @Test func crossCampAmbiguityNeverSelectsDefaultCamp() throws {
        let database = try p1cInputDatabase("ambiguity")
        _ = try p1cCaptured(
            database,
            command: p1cCaptureCommand(initialCampId: nil)
        )
        let claim = try p1cClaimInputWork(database)
        _ = try p1cParseResult(
            database,
            claim: claim,
            route: .campAmbiguous,
            assignedCampId: nil,
            candidateCampIds: [p1cInputCampID, p1cInputOtherCampID]
        )
        let fetchedInput = try InputGoalStore(database: database)
            .input(id: p1cInputID)
        let input = try #require(fetchedInput)
        #expect(input.status == .campAmbiguous)
        #expect(input.campId == nil)
        #expect(input.candidateCampIds == [p1cInputCampID, p1cInputOtherCampID])
    }

    @Test func inputCampScopeIsStableFromCaptureThroughAssignment() throws {
        let database = try p1cInputDatabase("camp-stable")
        let (store, _, _, _) = try p1cCaptured(
            database,
            command: p1cCaptureCommand(initialCampId: nil)
        )
        let claim = try p1cClaimInputWork(database)
        _ = try p1cParseResult(
            database,
            claim: claim,
            route: .campAssignmentRequired,
            assignedCampId: nil,
            candidateCampIds: [p1cInputCampID]
        )
        let head = try p1cInputHead(version: 2)
        _ = try store.assignCamp(AssignInputCampCommandV1(
            envelope: p1cInputUserEnvelope(key: "assign"),
            input: head,
            activeParsingBranch: .none,
            targetCampId: p1cInputCampID,
            targetStatus: .coaching
        ))
        let fetchedInput = try store.input(id: p1cInputID)
        let input = try #require(fetchedInput)
        #expect(input.campId == p1cInputCampID)
        let camps = try database.pool.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT DISTINCT campId FROM domain_event WHERE aggregateType='input'"
            )
        }
        #expect(camps == [p1cInputCampID])
    }

    @Test func inputRejectsInitialOrAssignedCampDifferentFromAuditCamp() throws {
        #expect(throws: InputCampScopeError.self) {
            _ = try p1cCaptureCommand(initialCampId: p1cInputOtherCampID)
        }
        let database = try p1cInputDatabase("cross-assign")
        let (store, _, _, _) = try p1cCaptured(
            database,
            command: p1cCaptureCommand(initialCampId: nil)
        )
        let claim = try p1cClaimInputWork(database)
        _ = try p1cParseResult(
            database,
            claim: claim,
            route: .campAssignmentRequired,
            assignedCampId: nil,
            candidateCampIds: [p1cInputCampID]
        )
        #expect(throws: InputCampScopeError.self) {
            _ = try store.assignCamp(AssignInputCampCommandV1(
                envelope: p1cInputUserEnvelope(key: "bad-assign"),
                input: p1cInputHead(version: 2),
                activeParsingBranch: .none,
                targetCampId: p1cInputOtherCampID,
                targetStatus: .coaching
            ))
        }
    }

    @Test func inputParsingWorkAlwaysUsesAuditCampAndArchivedCampFailsClosed() throws {
        let database = try p1cInputDatabase("archived-camp")
        let (store, receipt, _, work) = try p1cCaptured(
            database,
            command: p1cCaptureCommand(initialCampId: nil)
        )
        #expect(work.campId == p1cInputCampID)
        let claim = try p1cClaimInputWork(database)
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE camp SET archived=1 WHERE id=?",
                arguments: [p1cInputCampID]
            )
        }
        #expect(try store.captureAndEnqueueParsing(p1cCaptureCommand(initialCampId: nil)) == receipt)
        #expect(throws: DomainCommandCampUnavailableError.self) {
            _ = try p1cParseResult(database, claim: claim)
        }
    }

    @Test func inputTombstoneRetainsOnlyExactIdentityHashAndTimes() throws {
        let database = try p1cInputDatabase("tombstone-retain")
        let (store, _, before, work) = try p1cCaptured(database)
        let deletedAt = Date(timeIntervalSince1970: 130)
        _ = try store.cancelParsingAndDelete(
            CancelInputParsingAndDeleteCommandV1(
                envelope: p1cInputUserEnvelope(
                    key: "delete", occurredAt: deletedAt
                ),
                input: p1cInputHead(),
                activeParsingBranch: .expected(
                    workId: work.id, expectedVersion: work.version
                )
            )
        )
        let fetchedRow = try store.input(id: p1cInputID)
        let row = try #require(fetchedRow)
        #expect(row.id == before.id)
        #expect(row.schemaVersion == before.schemaVersion)
        #expect(row.aggregateVersion == before.aggregateVersion + 1)
        #expect(row.idempotencyKey == before.idempotencyKey)
        #expect(row.sourceType == before.sourceType)
        #expect(row.capturedAt == before.capturedAt)
        #expect(row.contentHash == before.contentHash)
        #expect(row.campId == before.campId)
        #expect(row.createdAt == before.createdAt)
        #expect(row.updatedAt == deletedAt)
        #expect(row.deletedAt == deletedAt)
    }

    @Test func inputTombstoneNullsDeviceConnectorAuthorBodyRefErrorAndParent() throws {
        let database = try p1cInputDatabase("tombstone-null")
        let (store, _, _, work) = try p1cCaptured(database)
        _ = try store.cancelParsingAndDelete(
            CancelInputParsingAndDeleteCommandV1(
                envelope: p1cInputUserEnvelope(key: "delete-null"),
                input: p1cInputHead(),
                activeParsingBranch: .expected(
                    workId: work.id, expectedVersion: work.version
                )
            )
        )
        let fetchedRow = try store.input(id: p1cInputID)
        let row = try #require(fetchedRow)
        #expect(row.sourceDeviceId == nil)
        #expect(row.connectorId == nil)
        #expect(row.authorId == nil)
        #expect(row.inlineText == nil)
        #expect(row.payloadRef == nil)
        #expect(row.errorCode == nil)
        #expect(row.errorMessage == nil)
        #expect(row.parentInputId == nil)
    }

    @Test func inputTombstoneForcesEmptyCandidatesUnspecifiedIntentLocalOnlyAndEqualDeleteTime() throws {
        let database = try p1cInputDatabase("tombstone-force")
        let (store, _, _, work) = try p1cCaptured(database)
        _ = try store.cancelParsingAndDelete(
            CancelInputParsingAndDeleteCommandV1(
                envelope: p1cInputUserEnvelope(key: "delete-force"),
                input: p1cInputHead(),
                activeParsingBranch: .expected(
                    workId: work.id, expectedVersion: work.version
                )
            )
        )
        let fetchedRow = try store.input(id: p1cInputID)
        let row = try #require(fetchedRow)
        #expect(row.candidateCampIds == [])
        #expect(row.explicitIntent == .unspecified)
        #expect(row.privacyLevel == .localOnly)
        #expect(row.status == .deletedTombstone)
        #expect(row.retentionState == .deletedTombstone)
        #expect(row.updatedAt == row.deletedAt)
    }

    @Test func localCaptureIdentityPersistsOnceAndFailsOnCorruption() throws {
        let generated = UUID(uuidString: p1cInputDeviceID)!
        let store = P1CInputIdentityMemoryStore()
        let identity = LocalCaptureIdentity(
            store: store,
            makeUUID: { generated }
        )
        #expect(try identity.installationID() == p1cInputDeviceID)
        #expect(try identity.installationID() == p1cInputDeviceID)
        let snapshot = store.snapshot()
        #expect(snapshot.0 == p1cInputDeviceID)
        #expect(snapshot.1 == 1)
        #expect(snapshot.2 == 1)

        let corrupt = P1CInputIdentityMemoryStore(stored: "corrupt")
        let calls = P1CInputLockedBox(0)
        let invalid = LocalCaptureIdentity(
            store: corrupt,
            makeUUID: {
                calls.withValue { $0 += 1 }
                return generated
            }
        )
        #expect(throws: P1ContractValidationError.self) {
            _ = try invalid.installationID()
        }
        #expect(calls.value == 0)
        #expect(corrupt.snapshot().2 == 0)
    }

    @Test func localCaptureIdentityConcurrentFirstUseAcrossCopiesIsAtomic() async throws {
        let store = P1CInputIdentityMemoryStore()
        let identity = LocalCaptureIdentity(
            store: store,
            makeUUID: { UUID(uuidString: p1cInputDeviceID)! }
        )
        let copy = identity
        let values = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0 ..< 32 {
                group.addTask {
                    try (index.isMultiple(of: 2) ? identity : copy)
                        .installationID()
                }
            }
            var values: [String] = []
            for try await value in group { values.append(value) }
            return values
        }
        #expect(Set(values) == [p1cInputDeviceID])
        #expect(store.snapshot().1 == 1)
        #expect(store.snapshot().2 == 1)
    }

    @Test func localCaptureIdentityConcurrentFirstUseAcrossIndependentAdaptersIsAtomic() async throws {
        let suite = "p1c.identity.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = LocalCaptureIdentity(
            store: LockedUserDefaultsCaptureIdentityStore(defaults: defaults),
            makeUUID: { UUID(uuidString: p1cInputDeviceID)! }
        )
        let alternateID = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
        let second = LocalCaptureIdentity(
            store: LockedUserDefaultsCaptureIdentityStore(defaults: defaults),
            makeUUID: { UUID(uuidString: alternateID)! }
        )
        let values = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0 ..< 32 {
                group.addTask {
                    try (index.isMultiple(of: 2) ? first : second)
                        .installationID()
                }
            }
            var values: [String] = []
            for try await value in group { values.append(value) }
            return values
        }
        #expect(Set(values).count == 1)
        #expect(values[0] == p1cInputDeviceID || values[0] == alternateID)
        #expect(defaults.string(
            forKey: "agentloop.localCaptureInstallationId"
        ) == values[0])
    }

    @Test func localCaptureUsesLocalOwnerAndInstallationDeviceWithoutAccountIdentity() async throws {
        let database = try p1cInputDatabase("local-owner")
        let controller = InputCaptureWorkflowController(
            database: database,
            reporter: FailureReporter(database: database),
            localCaptureIdentity: LocalCaptureIdentity(
                store: P1CInputIdentityMemoryStore(),
                makeUUID: { UUID(uuidString: p1cInputDeviceID)! }
            )
        )
        let trace = OperationTraceFactory(
            makeID: { UUID(uuidString: p1cInputParentID)! },
            now: { Date(timeIntervalSince1970: 80) }
        ).generated(operation: .inputFeedSubmit, scope: .fixed(.application))
        let outcome = await controller.captureLocalInput(
            p1cLocalCaptureRequest(),
            trace: trace
        )
        guard case .committed = outcome else {
            Issue.record("local capture did not commit")
            return
        }
        let event = try await database.pool.read { db in
            let fetched = try DomainEventRecordV1.fetchOne(db)
            return try #require(fetched)
        }
        #expect(event.actorType == .user)
        #expect(event.actorId == "user:local-owner")
        #expect(event.deviceId == p1cInputDeviceID)
        let fetchedInput = try InputGoalStore(database: database)
            .input(id: p1cInputID)
        let input = try #require(fetchedInput)
        #expect(input.sourceDeviceId == p1cInputDeviceID)
    }

    @Test func localCapturePortAndInitializerRemainSourceCompatible() throws {
        let database = try p1cInputDatabase("capture-ports")
        let store = InputGoalStore(database: database)
        let ports = InputCapturePorts(
            capture: { try store.captureAndEnqueueParsing($0) },
            read: { try store.input(id: $0) }
        )
        _ = InputCaptureWorkflowController(
            database: database,
            reporter: FailureReporter(database: database),
            capturePorts: ports,
            localCaptureIdentity: LocalCaptureIdentity(
                store: P1CInputIdentityMemoryStore(),
                makeUUID: { UUID(uuidString: p1cInputDeviceID)! }
            )
        )
        #expect(try ports.read(p1cInputID) == nil)
    }

    @Test func localCaptureTraceCorrelationAndRequestIDsAreExact() async throws {
        let database = try p1cInputDatabase("capture-trace")
        let store = InputGoalStore(database: database)
        let captured = P1CInputLockedBox<CaptureInputCommandV1?>(nil)
        let ports = InputCapturePorts(
            capture: { command in
                captured.withValue { $0 = command }
                return try store.captureAndEnqueueParsing(command)
            },
            read: { try store.input(id: $0) }
        )
        let controller = InputCaptureWorkflowController(
            database: database,
            reporter: FailureReporter(database: database),
            capturePorts: ports,
            localCaptureIdentity: LocalCaptureIdentity(
                store: P1CInputIdentityMemoryStore(),
                makeUUID: { UUID(uuidString: p1cInputDeviceID)! }
            )
        )
        let trace = OperationTraceFactory(
            makeID: { UUID(uuidString: p1cInputParentID)! },
            now: { Date(timeIntervalSince1970: 80) }
        ).generated(operation: .inputFeedSubmit, scope: .fixed(.application))
        _ = await controller.captureLocalInput(
            p1cLocalCaptureRequest(causationId: "parent-command"),
            trace: trace
        )
        let command = try #require(captured.value)
        #expect(command.inputId == p1cInputID)
        #expect(command.envelope.idempotencyKey == "local-input-command")
        #expect(command.envelope.correlationId == trace.traceId)
        #expect(command.envelope.causationId == "parent-command")
        #expect(command.envelope.occurredAt == command.capturedAt)
    }

    @Test func loadInputUsesReadPortAndMapsMissingRecordToFailure() async throws {
        let database = try p1cInputDatabase("load-missing")
        let reads = P1CInputLockedBox(0)
        let ports = InputCapturePorts(
            capture: { _ in throw P1CInputTestError.forcedMutationFailure },
            read: { _ in
                reads.withValue { $0 += 1 }
                return nil
            }
        )
        let controller = InputCaptureWorkflowController(
            database: database,
            reporter: FailureReporter(database: database),
            capturePorts: ports,
            localCaptureIdentity: LocalCaptureIdentity(
                store: P1CInputIdentityMemoryStore(),
                makeUUID: { UUID(uuidString: p1cInputDeviceID)! }
            )
        )
        let trace = OperationTraceFactory.live.generated(
            operation: .inputCampLoad,
            scope: .fixed(.application)
        )
        let state = await controller.loadInput(id: p1cInputID, trace: trace)
        guard case .failed(let failure) = state else {
            Issue.record("missing Input did not map to failed load")
            return
        }
        #expect(reads.value == 1)
        #expect(failure.traceId == trace.traceId)
    }

    @Test func legacyIngestionAdapterIsDisplayOnlyAndCreatesNoInputOrGoal() throws {
        let database = try p1cInputDatabase("legacy-display")
        let record = IngestionItemRecord(
            id: "legacy-id", campId: p1cInputCampID, sourceType: .text,
            title: "Legacy", rawText: "body", sourceURL: nil,
            author: "author", userIntent: nil, contentHash: p1cInputHash,
            status: .needsReview, attempt: 1, errorText: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let before = try p1cInputCounts(database)
        let display = LegacyIngestionAdapter.project(record)
        #expect(display.legacyIngestionId == record.id)
        #expect(display.title == record.title)
        #expect(display.body == record.rawText)
        #expect(try p1cInputCounts(database) == before)
    }

    @Test func nilInputCampNeverInfersAuthority() throws {
        let database = try p1cInputDatabase("nil-camp")
        let (store, _, _, _) = try p1cCaptured(
            database,
            command: p1cCaptureCommand(initialCampId: nil)
        )
        let claim = try p1cClaimInputWork(database)
        _ = try p1cParseResult(
            database,
            claim: claim,
            route: .campAmbiguous,
            assignedCampId: nil,
            candidateCampIds: [p1cInputCampID, p1cInputOtherCampID]
        )
        _ = try store.archive(ArchiveInputCommandV1(
            envelope: p1cInputUserEnvelope(key: "archive-nil"),
            input: p1cInputHead(version: 2),
            activeParsingBranch: .none
        ))
        let fetchedInput = try store.input(id: p1cInputID)
        let input = try #require(fetchedInput)
        #expect(input.campId == nil)
        let camps = try database.pool.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT DISTINCT campId FROM domain_event WHERE aggregateType='input'"
            )
        }
        #expect(camps == [p1cInputCampID])
    }
}

private func p1cLocalCaptureRequest(
    causationId: String? = nil
) -> LocalInputCaptureRequestV1 {
    LocalInputCaptureRequestV1(
        inputId: p1cInputID,
        idempotencyKey: "local-input-command",
        auditCampId: p1cInputCampID,
        initialCampId: p1cInputCampID,
        sourceType: .text,
        connectorId: nil,
        authorId: nil,
        capturedAt: Date(timeIntervalSince1970: 100),
        inlineText: "local body",
        payloadRef: nil,
        contentHash: p1cInputHash,
        candidateCampIds: [],
        explicitIntent: .unspecified,
        privacyLevel: .localOnly,
        parentInputId: nil,
        causationId: causationId
    )
}
