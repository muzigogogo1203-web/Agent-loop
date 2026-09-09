import Foundation
import GRDB
import Testing
import AgentLoopCore

private let p1cCampID = "p1c-domain-camp"
private let p1cInputID = "11111111-1111-1111-1111-111111111111"
private let p1cGoalID = "22222222-2222-2222-2222-222222222222"
private let p1cWorkID = "33333333-3333-3333-3333-333333333333"
private let p1cDeviceID = "44444444-4444-4444-4444-444444444444"
private let p1cEventID1 = "55555555-5555-5555-5555-555555555555"
private let p1cEventID2 = "66666666-6666-6666-6666-666666666666"
private let p1cHashA = String(repeating: "a", count: 64)
private let p1cHashB = String(repeating: "b", count: 64)
private let p1cHashC = String(repeating: "c", count: 64)

private struct P1CTestPayload: Codable, Sendable, Equatable {
    let inputId: String
    let note: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case inputId
        case note
    }

    init(inputId: String = p1cInputID, note: String?) {
        self.inputId = inputId
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases),
              container.contains(.note)
        else {
            throw P1CTestError.invalidFixture
        }
        inputId = try container.decode(String.self, forKey: .inputId)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputId, forKey: .inputId)
        try container.encode(note, forKey: .note)
    }
}

private enum P1CTestError: Error {
    case invalidFixture
    case projectionFailed
}

private final class P1CLockedBox<Value>: @unchecked Sendable {
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

    var value: Value {
        withValue { $0 }
    }
}

private func p1cDomainDatabase(_ label: String) throws -> AppDatabase {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("p1c-domain-\(label)-\(UUID().uuidString).sqlite")
        .path
    let database = try AppDatabase(path: path)
    try database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO camp (id, name, archived, createdAt)
                VALUES (?, 'P1-C', 0, 1)
                """,
            arguments: [p1cCampID]
        )
        try db.execute(
            sql: """
                INSERT INTO camp_lifecycle(
                  campId,state,version,createdAt,updatedAt,
                  deletionRequestedAt,deletedAt
                ) VALUES (?,'active',1,1,1,NULL,NULL)
                """,
            arguments: [p1cCampID]
        )
    }
    return database
}

private func p1cUserEnvelope(
    key: String = "p1c-command",
    occurredAt: Date = Date(timeIntervalSince1970: 100),
    causationId: String? = nil
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .user,
        actorId: "user:owner",
        deviceId: p1cDeviceID,
        correlationId: "p1c-correlation",
        causationId: causationId,
        occurredAt: occurredAt
    )
}

private func p1cCapturePlan(
    expectedInputVersion: Int = 0
) throws -> DomainCommandReplayPlanV1 {
    try InputGoalStore.captureReplayPlan(
        inputId: p1cInputID,
        auditCampId: p1cCampID,
        expectedInputVersion: expectedInputVersion
    )
}

private func p1cPreparedCapture(
    envelope: CommandEnvelopeV1,
    payload: P1CTestPayload = P1CTestPayload(note: nil),
    plan: DomainCommandReplayPlanV1? = nil
) throws -> (PreparedDomainCommandV1, DomainCommandReplayPlanV1) {
    let resolvedPlan = try plan ?? p1cCapturePlan()
    let prepared = try PreparedDomainCommandV1.make(
        commandType: .inputCapture,
        envelope: envelope,
        payload: payload,
        replayPlan: resolvedPlan
    )
    return (prepared, resolvedPlan)
}

private func p1cCaptureResult(
    commandHash: String,
    occurredAt: Date = Date(timeIntervalSince1970: 100),
    inputProjectionVersion: Int = 1,
    inputEventVersion: Int = 1
) throws -> CampSafeCommandResultV1 {
    try CampSafeCommandResultV1.make(
        branch: .captureInput,
        values: CampSafeResultValuesV1(
            commandPayloadHash: commandHash,
            domainEventCount: 1,
            outboxCount: 1,
            occurredAt: occurredAt,
            inputId: p1cInputID,
            durableWorkId: p1cWorkID,
            inputContentHash: p1cHashA,
            durableWorkInputHash: p1cHashB,
            inputProjectionVersion: inputProjectionVersion,
            durableWorkVersion: 1,
            inputEventVersion: inputEventVersion,
            candidateCampCount: 0,
            attemptCount: 0,
            capturedAt: Date(timeIntervalSince1970: 90)
        )
    )
}

private func p1cInsertInputProjection(
    _ db: Database,
    version: Int = 1
) throws {
    try db.execute(
        sql: """
            INSERT INTO input_envelope (
              id, schemaVersion, aggregateVersion, idempotencyKey, sourceType,
              sourceDeviceId, connectorId, authorId, capturedAt, inlineText,
              payloadRef, contentHash, candidateCampIdsJson, campId,
              explicitIntent, privacyLevel, status, errorCode, errorMessage,
              parentInputId, retentionState, createdAt, updatedAt, deletedAt
            ) VALUES (?, 1, ?, 'projection-key', 'text', NULL, NULL, NULL, 90,
                      'body', NULL, ?, '[]', ?, 'unspecified', 'localOnly',
                      'captured', NULL, NULL, NULL, 'active', 100, 100, NULL)
            """,
        arguments: [p1cInputID, version, p1cHashA, p1cCampID]
    )
}

private func p1cStore(
    database: AppDatabase,
    ids: P1CLockedBox<[String]>? = nil,
    clocks: P1CLockedBox<[Date]>? = nil
) -> DomainEventStore {
    DomainEventStore(
        database: database,
        clock: {
            if let clocks {
                return clocks.withValue { values in values.removeFirst() }
            }
            return Date(timeIntervalSince1970: 101)
        },
        eventIdFactory: {
            if let ids {
                return ids.withValue { values in values.removeFirst() }
            }
            return p1cEventID1
        }
    )
}

private func p1cCommitCapture(
    database: AppDatabase,
    store: DomainEventStore,
    envelope: CommandEnvelopeV1
) throws -> CampSafeCommandResultV1 {
    let (prepared, plan) = try p1cPreparedCapture(envelope: envelope)
    return try database.pool.write { db in
        try store.executeCommand(
            command: prepared,
            replayPlan: plan,
            database: db
        ) { mutationDB in
            try p1cInsertInputProjection(mutationDB)
            return try NewDomainCommandV1.make(
                result: p1cCaptureResult(
                    commandHash: prepared.commandPayloadHash,
                    occurredAt: envelope.occurredAt
                ),
                replayPlan: plan
            )
        }
    }
}

private func p1cCount(
    _ database: AppDatabase,
    table: String
) throws -> Int {
    try database.pool.read { db in
        try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM \(table)"
        ) ?? -1
    }
}

@Suite(.serialized)
struct P1CDomainEventContractTests {
    @Test func persistedControlContractConstantsAndWorkKeyDerivationsAreExact() throws {
        #expect(P1AggregateTypeV1.allCases.map(\.rawValue) == [
            "input", "goal", "coachSession", "understanding",
            "engine_execution",
        ])
        #expect(P1CommandTypeV1.allCases.count == 29)
        #expect(P1EventTypeV1.allCases.count == 37)
        #expect(P1ResultCodeV1.allCases.count == 33)
        #expect(P1AuditCodeV1.allCases.count == 34)
        #expect(P1AuditCodeV1.allCases.map(\.rawValue)
            == P1ResultCodeV1.allCases.map(\.rawValue)
                + ["engine_attention_intent"])
        #expect(try ControlWorkKeyV1.inputParsing(commandHash: p1cHashA)
            == "inputParsing:v1:\(p1cHashA)")
        #expect(try ControlWorkKeyV1.coach(commandHash: p1cHashB)
            == "coach:v1:\(p1cHashB)")
        #expect(throws: P1ContractValidationError.self) {
            _ = try ControlWorkKeyV1.inputParsing(commandHash: "A" + p1cHashA.dropFirst())
        }
    }

    @Test func workerCommandEnvelopeFactoriesAreExactAttemptScopedAndReplayStable() throws {
        for (kind, actorType, actorId) in [
            (DurableWorkKind.inputParsing, DomainActorType.system, "system:input-parser:v1"),
            (.coach, .coach, "system:coach:v1"),
        ] {
            let input = try CanonicalContractCodingV1.encode(P1CTestPayload(note: nil))
            let work = DurableWorkRecord(
                id: p1cWorkID, campId: p1cCampID, kind: kind,
                aggregateType: kind == .coach ? "goal" : "input",
                aggregateId: kind == .coach ? p1cGoalID : p1cInputID,
                idempotencyKey: "origin-key", state: .running, attempt: 2,
                maxAttempts: 4, notBefore: nil, leaseOwner: "worker",
                leaseExpiresAt: Date(timeIntervalSince1970: 200),
                inputJson: String(decoding: input, as: UTF8.self),
                inputHash: CanonicalJSONV1.sha256Hex(input), outputJson: nil,
                errorCode: nil, errorMessage: nil, traceId: "trace",
                version: 7, createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 100), finishedAt: nil
            )
            let attempt = DurableWorkAttemptRecord(
                workId: work.id, attempt: 2, id: p1cEventID2,
                workerId: "worker", startedAt: Date(timeIntervalSince1970: 100),
                endedAt: nil, outcome: nil, errorCode: nil, errorMessage: nil,
                traceId: "trace", terminalWorkVersion: nil
            )
            let claim = DurableWorkClaim(
                workId: work.id, attempt: 2, workerId: "worker", version: 7,
                leaseExpiresAt: Date(timeIntervalSince1970: 200)
            )
            let first = try ControlWorkerCommandEnvelopeFactoryV1.make(
                work: work, attempt: attempt, claim: claim
            )
            let renewed = DurableWorkClaim(
                workId: work.id, attempt: 2, workerId: "worker", version: 7,
                leaseExpiresAt: Date(timeIntervalSince1970: 215)
            )
            let second = try ControlWorkerCommandEnvelopeFactoryV1.make(
                work: work, attempt: attempt, claim: renewed
            )
            #expect(first == second)
            #expect(first.idempotencyKey
                == "control-worker:v1:\(kind.rawValue):\(work.id):2")
            #expect(first.actorType == actorType)
            #expect(first.actorId == actorId)
            #expect(first.deviceId == nil)
            #expect(first.correlationId == work.traceId)
            #expect(first.causationId == work.idempotencyKey)
            #expect(first.occurredAt == attempt.startedAt)

            var invalidWork = work
            invalidWork.leaseOwner = "other"
            #expect(throws: P1WorkerCommandEnvelopeError.self) {
                _ = try ControlWorkerCommandEnvelopeFactoryV1.make(
                    work: invalidWork, attempt: attempt, claim: claim
                )
            }
            var nextAttempt = attempt
            nextAttempt.attempt = 3
            let nextClaim = DurableWorkClaim(
                workId: work.id, attempt: 3, workerId: "worker", version: 7,
                leaseExpiresAt: claim.leaseExpiresAt
            )
            var nextWork = work
            nextWork.attempt = 3
            let adopted = try ControlWorkerCommandEnvelopeFactoryV1.make(
                work: nextWork, attempt: nextAttempt, claim: nextClaim
            )
            #expect(adopted.idempotencyKey != first.idempotencyKey)
        }

        let database = try p1cDomainDatabase("worker-outcome-identity")
        let store = p1cStore(database: database)
        let workerEnvelope = try CommandEnvelopeV1(
            idempotencyKey: "control-worker:v1:inputParsing:\(p1cWorkID):2",
            actorType: .system,
            actorId: "system:input-parser:v1",
            deviceId: nil,
            correlationId: "trace",
            causationId: "origin-key",
            occurredAt: Date(timeIntervalSince1970: 100)
        )
        let successPlan = try InputGoalStore.parseResultReplayPlan(
            inputId: p1cInputID,
            auditCampId: p1cCampID,
            expectedInputVersion: 0
        )
        let success = try PreparedDomainCommandV1.make(
            commandType: .inputParseResult,
            envelope: workerEnvelope,
            payload: P1CTestPayload(note: "success"),
            replayPlan: successPlan
        )
        let successResult = try CampSafeCommandResultV1.make(
            branch: .commitInputParse,
            values: CampSafeResultValuesV1(
                commandPayloadHash: success.commandPayloadHash,
                domainEventCount: 1,
                outboxCount: 1,
                occurredAt: workerEnvelope.occurredAt,
                inputId: p1cInputID,
                durableWorkId: p1cWorkID,
                inputContentHash: p1cHashA,
                durableWorkInputHash: p1cHashB,
                inputProjectionVersion: 1,
                durableWorkVersion: 1,
                inputEventVersion: 1,
                candidateCampCount: 0,
                attemptCount: 2,
                capturedAt: Date(timeIntervalSince1970: 90)
            )
        )
        let first = try database.pool.write { db in
            try store.executeCommand(
                command: success,
                replayPlan: successPlan,
                database: db
            ) { _ in
                try NewDomainCommandV1.make(
                    result: successResult,
                    replayPlan: successPlan
                )
            }
        }
        let replayCalls = P1CLockedBox(0)
        let replay = try database.pool.write { db in
            try store.executeCommand(
                command: success,
                replayPlan: successPlan,
                database: db
            ) { _ in
                replayCalls.withValue { $0 += 1 }
                throw P1CTestError.projectionFailed
            }
        }
        #expect(replay == first)
        #expect(replayCalls.value == 0)

        let failurePlan = try InputGoalStore.parseFailureReplayPlan(
            branch: .failInputParse,
            inputId: p1cInputID,
            auditCampId: p1cCampID,
            expectedInputVersion: 0
        )
        let divergentFailure = try PreparedDomainCommandV1.make(
            commandType: .inputParseFailure,
            envelope: workerEnvelope,
            payload: P1CTestPayload(note: "failure"),
            replayPlan: failurePlan
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: divergentFailure,
                    replayPlan: failurePlan,
                    database: db
                ) { _ in throw P1CTestError.projectionFailed }
            }
        }
    }

    @Test func preparedCommandIsPreReceiptAuthorityAndNewResultIsPostMutationOnly() throws {
        let envelope = try p1cUserEnvelope()
        let (prepared, plan) = try p1cPreparedCapture(envelope: envelope)
        #expect(prepared.commandType == .inputCapture)
        #expect(prepared.envelope == envelope)
        #expect(prepared.eventCount == 1)
        let expectedPayload = try CanonicalContractCodingV1.encode(
            P1CTestPayload(note: nil)
        )
        #expect(prepared.payloadBytes == expectedPayload)
        let result = try p1cCaptureResult(
            commandHash: prepared.commandPayloadHash
        )
        let newCommand = try NewDomainCommandV1.make(
            result: result,
            replayPlan: plan
        )
        #expect(newCommand.result == result)
        #expect(newCommand.auditPayloads.count == 1)
        #expect(newCommand.auditPayloads[0].code == .inputCaptured)
    }

    @Test func commandEnvelopeWholeHashCoversEveryFieldAndNullability() throws {
        let payload = P1CTestPayload(note: nil)
        let base = try p1cUserEnvelope()
        let baseHash = try CanonicalContractCodingV1.wholeCommandHash(
            envelope: base,
            payload: payload
        )
        let variants = [
            try p1cUserEnvelope(key: "other-key"),
            try CommandEnvelopeV1(
                idempotencyKey: base.idempotencyKey, actorType: .user,
                actorId: "user:other", deviceId: base.deviceId,
                correlationId: base.correlationId, causationId: base.causationId,
                occurredAt: base.occurredAt
            ),
            try CommandEnvelopeV1(
                idempotencyKey: base.idempotencyKey, actorType: .user,
                actorId: base.actorId, deviceId: base.deviceId,
                correlationId: "other-correlation", causationId: "cause",
                occurredAt: base.occurredAt
            ),
            try p1cUserEnvelope(occurredAt: Date(timeIntervalSince1970: 101)),
        ]
        for variant in variants {
            #expect(try CanonicalContractCodingV1.wholeCommandHash(
                envelope: variant,
                payload: payload
            ) != baseHash)
        }
        #expect(try CanonicalContractCodingV1.wholeCommandHash(
            envelope: base,
            payload: P1CTestPayload(note: "")
        ) != baseHash)
        let bytes = try CanonicalContractCodingV1.wholeCommandBytes(
            envelope: base,
            payload: payload
        )
        #expect(String(decoding: bytes, as: UTF8.self).contains("\"note\":null"))
        #expect(String(decoding: bytes, as: UTF8.self).contains("\"causationId\":null"))
    }

    @Test func canonicalContractCodingReusesCanonicalJSONV1GoldenBytes() throws {
        let value = P1CTestPayload(note: nil)
        let canonical = try CanonicalJSONV1.encode(value)
        #expect(try CanonicalContractCodingV1.encode(value) == canonical)
        #expect(try CanonicalContractCodingV1.string(value)
            == String(decoding: canonical, as: UTF8.self))
        #expect(try CanonicalContractCodingV1.hash(value)
            == CanonicalJSONV1.sha256Hex(canonical))
        #expect(try CanonicalContractCodingV1.decode(
            P1CTestPayload.self,
            from: canonical
        ) == value)
        #expect(throws: Error.self) {
            _ = try CanonicalContractCodingV1.decode(
                P1CTestPayload.self,
                from: Data("{ \"inputId\":\"x\",\"note\":null}".utf8)
            )
        }
    }

    @Test func campSafeJSONRejectsUnknownForbiddenIdentityAndNoncanonicalBytes() throws {
        let result = try p1cCaptureResult(commandHash: p1cHashC)
        let bytes = try CanonicalContractCodingV1.encode(result)
        #expect(try CanonicalContractCodingV1.decode(
            CampSafeCommandResultV1.self,
            from: bytes
        ) == result)
        let forbidden = Data(String(decoding: bytes, as: UTF8.self)
            .replacingOccurrences(
                of: "{",
                with: "{\"actorId\":\"user:secret\",",
                options: [],
                range: String(decoding: bytes, as: UTF8.self).range(of: "{")
            ).utf8)
        #expect(throws: Error.self) {
            _ = try CanonicalContractCodingV1.decode(
                CampSafeCommandResultV1.self,
                from: forbidden
            )
        }
        let noncanonical = Data((" " + String(decoding: bytes, as: UTF8.self)).utf8)
        #expect(throws: Error.self) {
            _ = try CanonicalContractCodingV1.decode(
                CampSafeCommandResultV1.self,
                from: noncanonical
            )
        }
        let plan = try p1cCapturePlan()
        let newCommand = try NewDomainCommandV1.make(
            result: result,
            replayPlan: plan
        )
        let auditBytes = try CanonicalContractCodingV1.encode(
            newCommand.auditPayloads[0]
        )
        let wrongAuditCode = Data(
            String(decoding: auditBytes, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"input_captured\"",
                    with: "\"goal_failed\""
                ).utf8
        )
        #expect(throws: P1ContractValidationError.self) {
            _ = try CanonicalContractCodingV1.decode(
                CampSafeAuditPayloadV1.self,
                from: wrongAuditCode
            )
        }
    }

    @Test func campSafeJSONRejectsSemanticallyForbiddenReferenceValues() throws {
        #expect(throws: P1ContractValidationError.self) {
            _ = try CampSafeRefV1(kind: .input, id: "not-a-uuid")
        }
        #expect(throws: P1ContractValidationError.self) {
            _ = try CampSafeHashV1(kind: .inputContent, hash: "A" + p1cHashA.dropFirst())
        }
        #expect(throws: P1ContractValidationError.self) {
            _ = try CampSafeVersionV1(kind: .inputProjection, value: 0)
        }
        #expect(throws: P1ContractValidationError.self) {
            _ = try CampSafeCountV1(kind: .attempt, value: -1)
        }
        #expect(throws: P1ContractValidationError.self) {
            _ = try CampSafeTimeV1(
                kind: .occurredAt,
                value: Date(timeIntervalSince1970: .infinity)
            )
        }
    }

    @Test func everyCommandResultAndAuditShapeIsExactAndOrdered() throws {
        let contracts = P1CommandContractCatalogV1.allResultContracts
        #expect(contracts.count == P1ResultBranchV1.allCases.count)
        #expect(Set(contracts.map(\.branch)).count == contracts.count)
        for contract in contracts {
            #expect(contract.refs == contract.refs.sorted())
            #expect(contract.hashes == contract.hashes.sorted())
            #expect(contract.versions == contract.versions.sorted())
            #expect(contract.counts == contract.counts.sorted())
            #expect(contract.times == contract.times.sorted())
            #expect(contract.hashes.contains(.commandPayload))
            #expect(contract.counts.contains(.domainEvent))
            #expect(contract.counts.contains(.outbox))
            #expect(contract.times.contains(.occurredAt))
            #expect(contract.events.count == contract.eventCount)
            for (ordinal, event) in contract.events.enumerated() {
                #expect(event.ordinal == ordinal)
                #expect(event.auditCode.rawValue == contract.resultCode.rawValue
                    || contract.branch == .convertInputToGoal
                    || contract.branch == .confirmUnderstanding
                    || contract.branch == .requestRevisionUnconfirmed
                    || contract.branch == .coachFailureTerminalClarifying
                    || contract.branch == .commitEngineTerminalWithAttention)
            }
        }
    }

    @Test func executeCommandCommitsReceiptProjectionEventsAndOutboxAtomically() throws {
        let database = try p1cDomainDatabase("commit")
        let store = p1cStore(database: database)
        let envelope = try p1cUserEnvelope()
        let result = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: envelope
        )
        #expect(result.code == .inputCaptured)
        #expect(try p1cCount(database, table: "input_envelope") == 1)
        #expect(try p1cCount(database, table: "domain_command_receipt") == 1)
        #expect(try p1cCount(database, table: "domain_event") == 1)
        #expect(try p1cCount(database, table: "event_outbox") == 1)
        try database.pool.read { db in
            let fetchedEvent = try DomainEventRecordV1.fetchOne(db)
            let fetchedOutbox = try EventOutboxRecordV1.fetchOne(db)
            let event = try #require(fetchedEvent)
            let outbox = try #require(fetchedOutbox)
            #expect(event.id == outbox.eventId)
            #expect(event.commandIdempotencyKey == envelope.idempotencyKey)
            #expect(outbox.state == .pending)
        }
    }

    @Test func executeCommandReplayReturnsOldResultWithoutMutation() throws {
        let database = try p1cDomainDatabase("replay")
        let calls = P1CLockedBox(0)
        let store = p1cStore(database: database)
        let envelope = try p1cUserEnvelope()
        let first = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: envelope
        )
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE camp SET archived = 1 WHERE id = ?",
                arguments: [p1cCampID]
            )
        }
        let (prepared, plan) = try p1cPreparedCapture(envelope: envelope)
        let replay = try database.pool.write { db in
            try store.executeCommand(
                command: prepared,
                replayPlan: plan,
                database: db
            ) { _ in
                calls.withValue { $0 += 1 }
                throw P1CTestError.projectionFailed
            }
        }
        #expect(replay == first)
        #expect(calls.value == 0)
        #expect(try p1cCount(database, table: "input_envelope") == 1)
        #expect(try p1cCount(database, table: "domain_event") == 1)
    }

    @Test func creationReplayUsesPersistedResultBeforeIDFactoryOrProjectionBranch() throws {
        let database = try p1cDomainDatabase("factory-replay")
        let ids = P1CLockedBox([p1cEventID1, p1cEventID2])
        let clocks = P1CLockedBox([
            Date(timeIntervalSince1970: 101),
            Date(timeIntervalSince1970: 102),
        ])
        let store = p1cStore(database: database, ids: ids, clocks: clocks)
        let envelope = try p1cUserEnvelope()
        let first = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: envelope
        )
        #expect(ids.value == [p1cEventID2])
        #expect(clocks.value == [Date(timeIntervalSince1970: 102)])
        let branchCalls = P1CLockedBox(0)
        let (prepared, plan) = try p1cPreparedCapture(envelope: envelope)
        let replay = try database.pool.write { db in
            try store.executeCommand(
                command: prepared,
                replayPlan: plan,
                database: db
            ) { _ in
                branchCalls.withValue { $0 += 1 }
                throw P1CTestError.projectionFailed
            }
        }
        #expect(replay == first)
        #expect(branchCalls.value == 0)
        #expect(ids.value == [p1cEventID2])
        #expect(clocks.value == [Date(timeIntervalSince1970: 102)])
        let outboxID = try database.pool.read { db in
            try String.fetchOne(db, sql: "SELECT eventId FROM event_outbox")
        }
        #expect(outboxID == p1cEventID1)
    }

    @Test func replayValidatesCompleteStoredEventAndOutboxGraph() throws {
        for mutation in ["event-payload", "missing-outbox", "extra-event"] {
            let database = try p1cDomainDatabase("graph-\(mutation)")
            let store = p1cStore(database: database)
            let envelope = try p1cUserEnvelope(key: "graph-command")
            _ = try p1cCommitCapture(
                database: database,
                store: store,
                envelope: envelope
            )
            try database.pool.write { db in
                switch mutation {
                case "event-payload":
                    try db.execute(sql: "DROP TRIGGER domain_event_reject_update")
                    try db.execute(
                        sql: "UPDATE domain_event SET payloadHash = ?",
                        arguments: [p1cHashA]
                    )
                case "missing-outbox":
                    try db.execute(sql: "DELETE FROM event_outbox")
                default:
                    try db.execute(sql: "DROP TRIGGER domain_event_reject_update")
                    try db.execute(sql: "DROP TRIGGER domain_event_reject_delete")
                    let fetched = try DomainEventRecordV1.fetchOne(db)
                    let original = try #require(fetched)
                    var extra = original
                    extra.id = p1cEventID2
                    extra.aggregateVersion = 2
                    extra.eventOrdinal = 1
                    extra.eventIdempotencyKey = "graph-command#0001:input:\(p1cInputID)"
                    try db.execute(
                        sql: """
                            INSERT INTO camp_event_scope(
                              sourceTable,eventId,scopeKind,campId,
                              payloadRedactedAt
                            ) VALUES ('domain_event',?,'camp',?,NULL)
                            """,
                        arguments: [extra.id, extra.campId]
                    )
                    try extra.insert(db)
                }
            }
            let (prepared, plan) = try p1cPreparedCapture(envelope: envelope)
            #expect(throws: DomainCommandGraphIntegrityError.self) {
                _ = try database.pool.write { db in
                    try store.executeCommand(
                        command: prepared,
                        replayPlan: plan,
                        database: db
                    ) { _ in
                        throw P1CTestError.projectionFailed
                    }
                }
            }
        }
    }

    @Test func executeCommandRejectsTypeHashOrEventCountDriftTotally() throws {
        let database = try p1cDomainDatabase("drift")
        let store = p1cStore(database: database)
        let envelope = try p1cUserEnvelope(key: "drift-key")
        _ = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: envelope
        )
        let capturePlan = try p1cCapturePlan()
        let hashDrift = try PreparedDomainCommandV1.make(
            commandType: .inputCapture,
            envelope: envelope,
            payload: P1CTestPayload(note: "changed"),
            replayPlan: capturePlan
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: hashDrift,
                    replayPlan: capturePlan,
                    database: db
                ) { _ in throw P1CTestError.projectionFailed }
            }
        }

        let archivePlan = try InputGoalStore.archiveReplayPlan(
            inputId: p1cInputID,
            auditCampId: p1cCampID,
            expectedInputVersion: 1
        )
        let typeDrift = try PreparedDomainCommandV1.make(
            commandType: .inputArchive,
            envelope: envelope,
            payload: P1CTestPayload(note: nil),
            replayPlan: archivePlan
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: typeDrift,
                    replayPlan: archivePlan,
                    database: db
                ) { _ in throw P1CTestError.projectionFailed }
            }
        }

        try database.pool.write { db in
            try db.execute(sql: "DROP TRIGGER domain_command_receipt_reject_update")
            try db.execute(
                sql: "UPDATE domain_command_receipt SET eventCount=2 WHERE idempotencyKey=?",
                arguments: [envelope.idempotencyKey]
            )
        }
        let (countDrift, sameCapturePlan) = try p1cPreparedCapture(
            envelope: envelope,
            plan: capturePlan
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: countDrift,
                    replayPlan: sameCapturePlan,
                    database: db
                ) { _ in throw P1CTestError.projectionFailed }
            }
        }
        #expect(try p1cCount(database, table: "domain_event") == 1)
    }

    @Test func multiAggregateCommandUsesStableOrdinalsAndVersionChains() throws {
        let database = try p1cDomainDatabase("multi")
        let ids = P1CLockedBox([p1cEventID1, p1cEventID2])
        let clocks = P1CLockedBox([
            Date(timeIntervalSince1970: 101),
            Date(timeIntervalSince1970: 102),
        ])
        let store = p1cStore(database: database, ids: ids, clocks: clocks)
        let envelope = try p1cUserEnvelope(key: "multi-command")
        let plan = try InputGoalStore.convertToGoalReplayPlan(
            inputId: p1cInputID,
            goalId: p1cGoalID,
            auditCampId: p1cCampID,
            expectedInputVersion: 0,
            expectedGoalVersion: 0
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputConvertToGoal,
            envelope: envelope,
            payload: P1CTestPayload(note: "goal"),
            replayPlan: plan
        )
        let result = try CampSafeCommandResultV1.make(
            branch: .convertInputToGoal,
            values: CampSafeResultValuesV1(
                commandPayloadHash: prepared.commandPayloadHash,
                domainEventCount: 2, outboxCount: 2,
                occurredAt: envelope.occurredAt,
                inputId: p1cInputID, goalId: p1cGoalID,
                inputContentHash: p1cHashA,
                inputProjectionVersion: 1, goalProjectionVersion: 1,
                inputEventVersion: 1, goalEventVersion: 1,
                candidateCampCount: 0,
                capturedAt: Date(timeIntervalSince1970: 90)
            )
        )
        _ = try database.pool.write { db in
            try store.executeCommand(
                command: prepared, replayPlan: plan, database: db
            ) { _ in
                try NewDomainCommandV1.make(result: result, replayPlan: plan)
            }
        }
        let events = try database.pool.read { db in
            try DomainEventRecordV1.order(Column("eventOrdinal")).fetchAll(db)
        }
        #expect(events.map(\.eventOrdinal) == [0, 1])
        #expect(events.map(\.eventIdempotencyKey) == [
            "multi-command#0000:input:\(p1cInputID)",
            "multi-command#0001:goal:\(p1cGoalID)",
        ])
        #expect(events.map(\.aggregateVersion) == [1, 1])
        #expect(events.map(\.eventType) == [
            .inputGoalCreated, .goalCreated,
        ])
    }

    @Test func eventCountOrdinalOrProjectionFailureRollsBackEverything() throws {
        let database = try p1cDomainDatabase("total-rollback")
        let store = p1cStore(database: database)
        let envelope = try p1cUserEnvelope(key: "rollback-command")
        let (prepared, plan) = try p1cPreparedCapture(envelope: envelope)
        #expect(throws: P1CTestError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: prepared,
                    replayPlan: plan,
                    database: db
                ) { mutationDB in
                    try p1cInsertInputProjection(mutationDB)
                    throw P1CTestError.projectionFailed
                }
            }
        }
        #expect(try p1cCount(database, table: "input_envelope") == 0)
        #expect(try p1cCount(database, table: "domain_command_receipt") == 0)
        #expect(try p1cCount(database, table: "domain_event") == 0)
        #expect(try p1cCount(database, table: "event_outbox") == 0)
        let badResult = try p1cCaptureResult(
            commandHash: prepared.commandPayloadHash,
            inputEventVersion: 2
        )
        #expect(throws: DomainCommandContractError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: prepared,
                    replayPlan: plan,
                    database: db
                ) { mutationDB in
                    try p1cInsertInputProjection(mutationDB)
                    return try NewDomainCommandV1.make(
                        result: badResult,
                        replayPlan: plan
                    )
                }
            }
        }
        #expect(try p1cCount(database, table: "input_envelope") == 0)
    }

    @Test func domainEventCopiesEnvelopeAndOwnsRecordedAt() throws {
        let database = try p1cDomainDatabase("event-envelope")
        let ids = P1CLockedBox([p1cEventID1])
        let recordedAt = Date(timeIntervalSince1970: 150.123456)
        let persistedRecordedAt = try P1DTimestampV1.canonical(
            recordedAt
        )
        let clocks = P1CLockedBox([recordedAt])
        let store = p1cStore(database: database, ids: ids, clocks: clocks)
        let envelope = try p1cUserEnvelope(
            key: "copy-command",
            occurredAt: Date(timeIntervalSince1970: 100),
            causationId: "cause"
        )
        _ = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: envelope
        )
        try database.pool.read { db in
            let fetchedEvent = try DomainEventRecordV1.fetchOne(db)
            let fetchedOutbox = try EventOutboxRecordV1.fetchOne(db)
            let event = try #require(fetchedEvent)
            let outbox = try #require(fetchedOutbox)
            #expect(event.actorType == envelope.actorType)
            #expect(event.actorId == envelope.actorId)
            #expect(event.deviceId == envelope.deviceId)
            #expect(event.causationId == envelope.causationId)
            #expect(event.correlationId == envelope.correlationId)
            #expect(event.occurredAt == envelope.occurredAt)
            #expect(try P1DTimestampV1.restorePersisted(event.recordedAt)
                == persistedRecordedAt)
            #expect(outbox.createdAt == event.recordedAt)
            #expect(outbox.updatedAt == event.recordedAt)
            #expect(event.id == p1cEventID1)
        }
    }

    @Test func domainEventRejectsMissingCampBadTimeAndVersionPreSQL() throws {
        let database = try p1cDomainDatabase("preflight")
        let calls = P1CLockedBox(0)
        let store = DomainEventStore(
            database: database,
            clock: {
                calls.withValue { $0 += 1 }
                return Date(timeIntervalSince1970: 101)
            },
            eventIdFactory: {
                calls.withValue { $0 += 1 }
                return p1cEventID1
            }
        )
        let envelope = try p1cUserEnvelope()
        let missingCampPlan = try InputGoalStore.captureReplayPlan(
            inputId: p1cInputID,
            auditCampId: "missing-camp",
            expectedInputVersion: 0
        )
        let missingCamp = try PreparedDomainCommandV1.make(
            commandType: .inputCapture,
            envelope: envelope,
            payload: P1CTestPayload(note: nil),
            replayPlan: missingCampPlan
        )
        #expect(throws: DomainCommandCampUnavailableError.self) {
            _ = try database.pool.write { db in
                try store.executeCommand(
                    command: missingCamp,
                    replayPlan: missingCampPlan,
                    database: db
                ) { _ in throw P1CTestError.projectionFailed }
            }
        }
        #expect(calls.value == 0)
        #expect(throws: P1ContractValidationError.self) {
            _ = try InputGoalStore.captureReplayPlan(
                inputId: p1cInputID,
                auditCampId: p1cCampID,
                expectedInputVersion: Int.max
            )
        }
        #expect(throws: P1ContractValidationError.self) {
            _ = try CommandEnvelopeV1(
                idempotencyKey: "bad-time", actorType: .user,
                actorId: "user:owner", deviceId: p1cDeviceID,
                correlationId: "trace", causationId: nil,
                occurredAt: Date(timeIntervalSince1970: .infinity)
            )
        }
        #expect(try p1cCount(database, table: "domain_command_receipt") == 0)
    }

    @Test func outboxClaimReleaseSentCASAndReplayAreDeterministic() throws {
        let database = try p1cDomainDatabase("outbox")
        let store = p1cStore(database: database)
        _ = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: p1cUserEnvelope(key: "outbox-command")
        )
        let firstClaims = try store.claimOutbox(
            workerId: "sender", now: Date(timeIntervalSince1970: 200),
            leaseDuration: 60, limit: 1
        )
        let first = try #require(firstClaims.first)
        #expect(first.record.state == .dispatching)
        #expect(first.record.attempt == 1)
        #expect(first.record.version == 2)
        let pending = try store.releaseOutbox(
            claim: first,
            failure: DomainOutboxFailureV1(
                code: "network", message: "retry", deterministic: false
            ),
            notBefore: Date(timeIntervalSince1970: 210),
            now: Date(timeIntervalSince1970: 201)
        )
        #expect(pending.state == .pending)
        #expect(pending.version == 3)
        #expect(try store.releaseOutbox(
            claim: first,
            failure: DomainOutboxFailureV1(
                code: "network", message: "retry", deterministic: false
            ),
            notBefore: Date(timeIntervalSince1970: 210),
            now: Date(timeIntervalSince1970: 201)
        ) == pending)
        #expect(try store.claimOutbox(
            workerId: "sender", now: Date(timeIntervalSince1970: 209),
            leaseDuration: 60, limit: 1
        ).isEmpty)
        let second = try #require(store.claimOutbox(
            workerId: "sender", now: Date(timeIntervalSince1970: 210),
            leaseDuration: 60, limit: 1
        ).first)
        let sent = try store.markOutboxSent(
            claim: second,
            now: Date(timeIntervalSince1970: 211)
        )
        #expect(sent.state == .sent)
        #expect(try store.markOutboxSent(
            claim: second,
            now: Date(timeIntervalSince1970: 999)
        ) == sent)
        var stale = second
        stale.workerId = "other"
        #expect(throws: DomainOutboxCASConflictError.self) {
            _ = try store.markOutboxSent(
                claim: stale,
                now: Date(timeIntervalSince1970: 212)
            )
        }
    }

    @Test func inboxApplyReplayConflictAndTypedRejectionAreDurable() throws {
        let database = try p1cDomainDatabase("inbox-basics")
        let store = p1cStore(database: database)
        let appliedEnvelope = try DomainInboxEnvelopeV1(
            id: p1cEventID1,
            campId: p1cCampID,
            sourceDeviceId: p1cDeviceID,
            idempotencyKey: "inbox-applied",
            payloadBytes: Data("{\"value\":1}".utf8),
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        let calls = P1CLockedBox(0)
        let applied = try store.applyInbox(envelope: appliedEnvelope) { _ in
            calls.withValue { $0 += 1 }
        }
        #expect(applied.state == .applied)
        #expect(applied.appliedAt == appliedEnvelope.receivedAt)
        let replay = try store.applyInbox(envelope: appliedEnvelope) { _ in
            calls.withValue { $0 += 1 }
        }
        #expect(replay == applied)
        #expect(calls.value == 1)

        let rejectedEnvelope = try DomainInboxEnvelopeV1(
            id: p1cEventID2,
            campId: p1cCampID,
            sourceDeviceId: p1cDeviceID,
            idempotencyKey: "inbox-rejected",
            payloadBytes: Data("{\"value\":2}".utf8),
            receivedAt: Date(timeIntervalSince1970: 2)
        )
        let rejected = try store.applyInbox(envelope: rejectedEnvelope) { _ in
            throw DomainInboxHandlerRejection(code: "policy_rejected")
        }
        #expect(rejected.state == .rejected)
        #expect(rejected.errorCode == "policy_rejected")
        #expect(try p1cCount(database, table: "inbox_message") == 2)
    }

    @Test func inboxTypedRejectionRollsBackHandlerSavepointBeforeDurableEvidence() throws {
        let database = try p1cDomainDatabase("inbox-savepoint")
        let store = p1cStore(database: database)
        let envelope = try DomainInboxEnvelopeV1(
            id: p1cEventID1, campId: p1cCampID,
            sourceDeviceId: p1cDeviceID, idempotencyKey: "savepoint-key",
            payloadBytes: Data("{\"value\":1}".utf8),
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        let row = try store.applyInbox(envelope: envelope) { db in
            try db.execute(
                sql: """
                    INSERT INTO camp (id, name, archived, createdAt)
                    VALUES ('savepoint-sentinel', 'must rollback', 0, 1)
                    """
            )
            throw DomainInboxHandlerRejection(code: "typed_rejection")
        }
        #expect(row.state == .rejected)
        #expect(row.errorCode == "typed_rejection")
        let sentinelCount = try database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM camp WHERE id='savepoint-sentinel'"
            ) ?? -1
        }
        #expect(sentinelCount == 0)
        #expect(try p1cCount(database, table: "inbox_message") == 1)
    }

    @Test func inboxSameKeyAndStoredHashButDifferentBytesFailsClosedWithoutHandler() throws {
        let database = try p1cDomainDatabase("inbox-forged")
        let store = p1cStore(database: database)
        let envelope = try DomainInboxEnvelopeV1(
            id: p1cEventID1, campId: p1cCampID,
            sourceDeviceId: p1cDeviceID, idempotencyKey: "forged-key",
            payloadBytes: Data("{\"value\":1}".utf8),
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        _ = try store.applyInbox(envelope: envelope) { _ in }
        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE inbox_message SET payloadJson='{\"value\":2}'"
            )
        }
        let calls = P1CLockedBox(0)
        #expect(throws: DomainInboxIntegrityError.self) {
            _ = try store.applyInbox(envelope: envelope) { _ in
                calls.withValue { $0 += 1 }
            }
        }
        #expect(calls.value == 0)
        let row = try database.pool.read { db in
            let fetched = try InboxMessageRecordV1.fetchOne(db)
            return try #require(fetched)
        }
        #expect(row.state == .applied)
        #expect(row.version == 2)
    }

    @Test func inboxConflictCASPersistsExactRejectedShapeAndThrowsAfterCommit() throws {
        let database = try p1cDomainDatabase("inbox-conflict")
        let store = p1cStore(database: database)
        let original = try DomainInboxEnvelopeV1(
            id: p1cEventID1, campId: p1cCampID,
            sourceDeviceId: p1cDeviceID, idempotencyKey: "conflict-key",
            payloadBytes: Data("{\"value\":1}".utf8),
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        let initial = try store.applyInbox(envelope: original) { _ in }
        let conflict = try DomainInboxEnvelopeV1(
            id: p1cEventID2, campId: p1cCampID,
            sourceDeviceId: p1cDeviceID, idempotencyKey: "conflict-key",
            payloadBytes: Data("{\"value\":2}".utf8),
            receivedAt: Date(timeIntervalSince1970: 2)
        )
        let calls = P1CLockedBox(0)
        #expect(throws: DomainInboxReplayConflictError.self) {
            _ = try store.applyInbox(envelope: conflict) { _ in
                calls.withValue { $0 += 1 }
            }
        }
        let rejected = try database.pool.read { db in
            let fetched = try InboxMessageRecordV1.fetchOne(db)
            return try #require(fetched)
        }
        #expect(rejected.id == initial.id)
        #expect(rejected.campId == initial.campId)
        #expect(rejected.sourceDeviceId == initial.sourceDeviceId)
        #expect(rejected.idempotencyKey == initial.idempotencyKey)
        #expect(rejected.payloadJson == initial.payloadJson)
        #expect(rejected.payloadHash == initial.payloadHash)
        #expect(rejected.receivedAt == initial.receivedAt)
        #expect(rejected.state == .rejected)
        #expect(rejected.appliedAt == nil)
        #expect(rejected.errorCode == "inbox_payload_conflict")
        #expect(rejected.version == initial.version + 1)
        #expect(rejected.redactedAt == nil)
        #expect(calls.value == 0)
        #expect(throws: DomainInboxReplayConflictError.self) {
            _ = try store.applyInbox(envelope: original) { _ in
                calls.withValue { $0 += 1 }
            }
        }
        #expect(throws: DomainInboxReplayConflictError.self) {
            _ = try store.applyInbox(envelope: conflict) { _ in
                calls.withValue { $0 += 1 }
            }
        }
        let repeated = try database.pool.read { db in
            let fetched = try InboxMessageRecordV1.fetchOne(db)
            return try #require(fetched)
        }
        #expect(repeated.version == rejected.version)
        #expect(calls.value == 0)
    }

    @Test func inboxOrdinaryRedactionIsRejectedWithoutCASOrHandler() throws {
        let database = try p1cDomainDatabase("inbox-redacted-conflict")
        let store = p1cStore(database: database)
        let envelope = try DomainInboxEnvelopeV1(
            id: p1cEventID1, campId: p1cCampID,
            sourceDeviceId: p1cDeviceID, idempotencyKey: "redacted-key",
            payloadBytes: Data("{\"value\":1}".utf8),
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        _ = try store.applyInbox(envelope: envelope) { _ in }
        #expect(throws: DatabaseError.self) {
            try database.pool.write { db in
                try db.execute(
                    sql: """
                        UPDATE inbox_message
                        SET sourceDeviceId='[deleted]', payloadJson='{}',
                            state='rejected', errorCode='camp_deleted',
                            redactedAt=3
                        """
                )
            }
        }
        let before = try database.pool.read { db in
            let fetched = try InboxMessageRecordV1.fetchOne(db)
            return try #require(fetched)
        }
        let conflict = try DomainInboxEnvelopeV1(
            id: p1cEventID2, campId: p1cCampID,
            sourceDeviceId: p1cDeviceID, idempotencyKey: "redacted-key",
            payloadBytes: Data("{\"value\":2}".utf8),
            receivedAt: Date(timeIntervalSince1970: 2)
        )
        let calls = P1CLockedBox(0)
        #expect(throws: DomainInboxReplayConflictError.self) {
            _ = try store.applyInbox(envelope: conflict) { _ in
                calls.withValue { $0 += 1 }
            }
        }
        let after = try database.pool.read { db in
            let fetched = try InboxMessageRecordV1.fetchOne(db)
            return try #require(fetched)
        }
        #expect(after.state == .rejected)
        #expect(after.errorCode == "inbox_payload_conflict")
        #expect(after.version == before.version + 1)
        #expect(calls.value == 0)
    }

    @Test func inboxOrdinaryRedactionFencePreservesEveryOrigin() throws {
        for origin in ["received", "applied", "rejected"] {
            let database = try p1cDomainDatabase("tombstone-\(origin)")
            let store = p1cStore(database: database)
            let envelope = try DomainInboxEnvelopeV1(
                id: p1cEventID1, campId: p1cCampID,
                sourceDeviceId: p1cDeviceID,
                idempotencyKey: "tombstone-\(origin)",
                payloadBytes: Data("{\"origin\":\"\(origin)\"}".utf8),
                receivedAt: Date(timeIntervalSince1970: 1)
            )
            switch origin {
            case "received":
                try database.pool.write { db in
                    try InboxMessageRecordV1.received(envelope: envelope)
                        .insert(db)
                }
            case "rejected":
                _ = try store.applyInbox(envelope: envelope) { _ in
                    throw DomainInboxHandlerRejection(code: "policy")
                }
            default:
                _ = try store.applyInbox(envelope: envelope) { _ in }
            }
            let prior = try database.pool.read { db in
                let fetched = try InboxMessageRecordV1.fetchOne(db)
                return try #require(fetched)
            }
            #expect(throws: DatabaseError.self) {
                try database.pool.write { db in
                    try db.execute(
                        sql: """
                            UPDATE inbox_message
                            SET sourceDeviceId='[deleted]', payloadJson='{}',
                                state='rejected', errorCode='camp_deleted',
                                redactedAt=3
                            """
                    )
                }
            }
            let unchanged = try database.pool.read { db in
                let fetched = try InboxMessageRecordV1.fetchOne(db)
                return try #require(fetched)
            }
            #expect(unchanged == prior)
        }
    }

    @Test func domainEventsReadInValidatedAggregateOrder() throws {
        let database = try p1cDomainDatabase("ordered-read")
        let ids = P1CLockedBox([p1cEventID1, p1cEventID2])
        let clocks = P1CLockedBox([
            Date(timeIntervalSince1970: 101),
            Date(timeIntervalSince1970: 102),
        ])
        let store = p1cStore(database: database, ids: ids, clocks: clocks)
        _ = try p1cCommitCapture(
            database: database,
            store: store,
            envelope: p1cUserEnvelope(key: "ordered-capture")
        )
        let envelope = try p1cUserEnvelope(
            key: "ordered-archive",
            occurredAt: Date(timeIntervalSince1970: 102)
        )
        let plan = try InputGoalStore.archiveReplayPlan(
            inputId: p1cInputID,
            auditCampId: p1cCampID,
            expectedInputVersion: 1
        )
        let prepared = try PreparedDomainCommandV1.make(
            commandType: .inputArchive,
            envelope: envelope,
            payload: P1CTestPayload(note: "archive"),
            replayPlan: plan
        )
        let result = try CampSafeCommandResultV1.make(
            branch: .archiveInput,
            values: CampSafeResultValuesV1(
                commandPayloadHash: prepared.commandPayloadHash,
                domainEventCount: 1, outboxCount: 1,
                occurredAt: prepared.envelope.occurredAt,
                inputId: p1cInputID,
                inputContentHash: p1cHashA,
                inputProjectionVersion: 2,
                inputEventVersion: 2, candidateCampCount: 0,
                capturedAt: Date(timeIntervalSince1970: 90)
            )
        )
        _ = try database.pool.write { db in
            try store.executeCommand(
                command: prepared, replayPlan: plan, database: db
            ) { mutationDB in
                try mutationDB.execute(
                    sql: """
                        UPDATE input_envelope
                        SET aggregateVersion=2, status='archived', updatedAt=102
                        WHERE id=?
                    """,
                    arguments: [p1cInputID]
                )
                return try NewDomainCommandV1.make(
                    result: result,
                    replayPlan: plan
                )
            }
        }
        let events = try store.events(aggregateType: .input, id: p1cInputID)
        #expect(events.map(\.aggregateVersion) == [1, 2])
        try database.pool.write { db in
            try db.execute(sql: "DROP TRIGGER domain_event_reject_update")
            try db.execute(
                sql: "UPDATE domain_event SET payloadHash=? WHERE aggregateVersion=2",
                arguments: [p1cHashA]
            )
        }
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try store.events(aggregateType: .input, id: p1cInputID)
        }
    }
}
