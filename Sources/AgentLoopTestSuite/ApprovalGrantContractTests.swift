import Foundation
import GRDB
import Testing
import AgentLoopCore
import AgentLoopApplication

private let approvalGrantTestNow = Date(timeIntervalSince1970: 1_800_000_000)
private let approvalGrantRecordedAt = approvalGrantTestNow
    .addingTimeInterval(10_000)
private let approvalGrantDeviceID = "00000000-0000-4000-8000-0000000000D4"

private struct ApprovalGrantFixture {
    let database: AppDatabase
    let store: ApprovalGrantStore
    let ids: AppDatabase.SingleCardIds
    let campId: String
    let input: JSONValue
    let inputHash: String
    let adapter: ExternalOperationAdapterDescriptorV1
    let grant: ApprovalGrantSnapshotV1
}

private func grantHash(_ value: String) -> String {
    CanonicalJSONV1.sha256Hex(Data(value.utf8))
}

private func grantUserEnvelope(
    _ key: String,
    at: Date = approvalGrantTestNow
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .user,
        actorId: P1DActorID.localOwner,
        deviceId: approvalGrantDeviceID,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

private func grantSystemEnvelope(
    _ key: String,
    at: Date = approvalGrantTestNow,
    actorId: String = P1DActorID.externalOperation
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .system,
        actorId: actorId,
        deviceId: nil,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

private func makeApprovalGrantFixture(
    replayClass: ExternalAdapterReplayClassV1 = .nonReplayable,
    maxUses: Int = 1,
    authority: ApprovalGrantPolicyAuthorityV1? = nil,
    grantorOverride: ApprovalGrantorV1? = nil,
    toolId: String = "write_file",
    input: JSONValue = ["content": "hello", "path": "out.txt"]
) throws -> ApprovalGrantFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: root.appendingPathComponent("grant.sqlite").path
    )
    let ids = try database.createSingleCardMission(
        campName: "D4",
        squadName: "Grant",
        goal: "execute one external operation",
        cardTitle: "external operation",
        cardDescription: "exercise grant ledger",
        expectedOutput: "durable receipt",
        assigneeId: nil,
        maxTurns: 4
    )
    let campId = try database.pool.read { db in
        try String.fetchOne(
            db,
            sql: """
                SELECT s.campId FROM card c
                JOIN mission m ON m.id=c.missionId
                JOIN squad s ON s.id=m.squadId
                WHERE c.id=?
                """,
            arguments: [ids.cardId]
        )!
    }
    let registry = try ApprovalGrantPolicyRegistryV1(
        authority.map { [$0] } ?? []
    )
    let store = ApprovalGrantStore(
        database: database,
        clock: { approvalGrantRecordedAt },
        policyRegistry: registry
    )
    let inputHash = try ApprovalToken.hash(input: input)
    let descriptor = try ExternalOperationAdapterDescriptorV1(
        adapterId: "adapter:\(toolId):v1",
        toolId: toolId,
        replayClass: replayClass
    )
    let grantor = try grantorOverride ?? ApprovalGrantorV1.user(
        P1DActorID.localOwner
    )
    let envelope: CommandEnvelopeV1
    switch grantor.type {
    case .user:
        envelope = try grantUserEnvelope("grant.create:\(UUID().uuidString)")
    case .policy, .system:
        envelope = try grantSystemEnvelope(
            "grant.create:\(UUID().uuidString)",
            actorId: grantor.id
        )
    }
    let grant = try store.createGrant(try CreateApprovalGrantCommandV1(
        envelope: envelope,
        grantId: UUID().uuidString,
        grantor: grantor,
        grantee: ApprovalGranteeV1(
            type: .system,
            id: "system:card-runner:v1"
        ),
        capability: "tool.execute:\(toolId)",
        campId: campId,
        cardId: ids.cardId,
        toolId: toolId,
        approvedInputHash: inputHash,
        purpose: "test:grant-contract",
        dataLevel: toolId.hasPrefix("mcp__") ? .external : .workspace,
        adapterReplayClass: replayClass,
        validFrom: approvalGrantTestNow.addingTimeInterval(-30),
        validUntil: approvalGrantTestNow.addingTimeInterval(900),
        maxUses: maxUses
    ))
    return ApprovalGrantFixture(
        database: database,
        store: store,
        ids: ids,
        campId: campId,
        input: input,
        inputHash: inputHash,
        adapter: descriptor,
        grant: grant
    )
}

private func reserveGrantUse(
    _ fixture: ApprovalGrantFixture,
    useId: String? = nil,
    key: String? = nil,
    expectedGrantVersion: Int? = nil,
    capability: String? = nil,
    campId: String? = nil,
    cardId: String? = nil,
    toolId: String? = nil,
    inputHash: String? = nil,
    adapter: ExternalOperationAdapterDescriptorV1? = nil,
    at: Date = approvalGrantTestNow
) throws -> (ApprovalGrantUseSnapshotV1, ReserveApprovalGrantUseCommandV1) {
    let resolvedUseID = try useId
        ?? fixture.store.nextUseIdentity(grantId: fixture.grant.id)
    let envelope = try grantSystemEnvelope(key ?? resolvedUseID, at: at)
    let command = try ReserveApprovalGrantUseCommandV1(
        envelope: envelope,
        useId: resolvedUseID,
        grantId: fixture.grant.id,
        expectedGrantVersion: expectedGrantVersion ?? fixture.grant.version,
        capability: capability ?? fixture.grant.capability,
        campId: campId ?? fixture.campId,
        cardId: cardId ?? fixture.ids.cardId,
        toolId: toolId ?? fixture.grant.toolId,
        inputHash: inputHash ?? fixture.inputHash,
        adapter: adapter ?? fixture.adapter
    )
    return (try fixture.store.reserveUse(command), command)
}

private func dispatchGrantUse(
    _ fixture: ApprovalGrantFixture,
    use: ApprovalGrantUseSnapshotV1,
    grantVersion: Int? = nil,
    key: String? = nil,
    at: Date = approvalGrantTestNow
) throws -> ApprovalGrantDispatchSnapshotV1 {
    try fixture.store.commitDispatchIntent(
        ApprovalGrantUseTransitionCommandV1(
            envelope: grantSystemEnvelope(
                key ?? "\(use.id):dispatch",
                at: at
            ),
            useId: use.id,
            expectedUseVersion: use.version,
            expectedGrantVersion: grantVersion ?? fixture.grant.version
        )
    )
}

private func adapterAcceptance(
    use: ApprovalGrantUseSnapshotV1,
    adapterId: String? = nil,
    key: String? = nil,
    operationId: String = "operation:d4:1"
) throws -> AdapterAcceptanceAttestationV1 {
    try AdapterAcceptanceAttestationV1(
        adapterId: adapterId ?? use.adapterId,
        useId: use.id,
        useIdempotencyKey: key ?? use.idempotencyKey,
        operationId: operationId,
        evidenceHash: grantHash("accepted:\(use.id):\(operationId)")
    )
}

private func adapterEffect(
    use: ApprovalGrantUseSnapshotV1,
    result: ExternalOperationReceiptResultV1,
    adapterId: String? = nil,
    key: String? = nil,
    operationId: String? = "operation:d4:1"
) throws -> AdapterEffectAttestationV1 {
    try AdapterEffectAttestationV1(
        adapterId: adapterId ?? use.adapterId,
        useId: use.id,
        useIdempotencyKey: key ?? use.idempotencyKey,
        operationId: operationId,
        result: result,
        receiptRef: "receipt:d4",
        evidenceHash: grantHash("effect:\(use.id):\(result.rawValue)")
    )
}

private func recordAdapterAccepted(
    _ fixture: ApprovalGrantFixture,
    use: ApprovalGrantUseSnapshotV1,
    operationId: String = "operation:d4:1"
) throws -> ApprovalGrantDispatchSnapshotV1 {
    try fixture.store.recordAdapterAccepted(
        ApprovalGrantUseTransitionCommandV1(
            envelope: grantSystemEnvelope("\(use.id):accepted"),
            useId: use.id,
            expectedUseVersion: use.version
        ),
        attestation: adapterAcceptance(
            use: use,
            operationId: operationId
        )
    )
}

private func confirmNoEffect(
    _ fixture: ApprovalGrantFixture,
    use: ApprovalGrantUseSnapshotV1,
    grantVersion: Int,
    key: String? = nil,
    at: Date = approvalGrantTestNow
) throws -> ApprovalGrantDispatchSnapshotV1 {
    let attestation = try AdapterNoEffectAttestationV1(
        adapterId: use.adapterId,
        useId: use.id,
        useIdempotencyKey: use.idempotencyKey,
        operationId: use.adapterOperationId,
        evidenceHash: grantHash("no-effect:\(use.id)"),
        receiptRef: "receipt:no-effect"
    )
    return try fixture.store.confirmAdapterNoEffect(
        ApprovalGrantUseTransitionCommandV1(
            envelope: grantSystemEnvelope(
                key ?? "\(use.id):no-effect",
                at: at
            ),
            useId: use.id,
            expectedUseVersion: use.version,
            expectedGrantVersion: grantVersion
        ),
        attestation: attestation
    )
}

private func rawInsertGrant(
    _ db: Database,
    fixture: ApprovalGrantFixture,
    grantorType: String,
    policyId: String?,
    policyVersion: Int?,
    policyHash: String?,
    replayClass: String,
    maxUses: Int
) throws {
    try db.execute(
        sql: """
            INSERT INTO approval_grant(
              id,version,scopeVersion,grantorActorType,grantorActorId,
              grantorPolicyId,grantorPolicyVersion,grantorPolicyHash,
              granteeType,granteeId,capability,campId,cardId,toolId,
              approvedInputHash,purpose,dataLevel,adapterReplayClass,
              validFrom,validUntil,maxUses,usedCount,status,revokedAt,
              createdAt,updatedAt,redactedAt
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,'active',NULL,?,?,NULL)
            """,
        arguments: [
            UUID().uuidString, 1, 1, grantorType, P1DActorID.localOwner,
            policyId, policyVersion, policyHash,
            "system", "system:card-runner:v1",
            fixture.grant.capability, fixture.campId, fixture.ids.cardId,
            fixture.grant.toolId, fixture.inputHash, "raw-test", "workspace",
            replayClass, approvalGrantTestNow.addingTimeInterval(-30),
            approvalGrantTestNow.addingTimeInterval(900), maxUses,
            approvalGrantTestNow, approvalGrantTestNow,
        ]
    )
}

private func rawInsertReceipt(
    _ db: Database,
    useId: String,
    ordinal: Int,
    phase: ExternalOperationReceiptPhaseV1,
    result: ExternalOperationReceiptResultV1,
    authority: ExternalOperationReceiptAuthorityV1
) throws {
    try db.execute(
        sql: """
            INSERT INTO external_operation_receipt(
              id,grantUseId,receiptIdempotencyKey,ordinal,phase,result,
              adapterOperationId,receiptRef,receiptJson,receiptHash,
              authorityKind,authorityId,createdAt,redactedAt
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)
            """,
        arguments: [
            UUID().uuidString, useId,
            "raw-receipt:\(UUID().uuidString)", ordinal,
            phase.rawValue, result.rawValue, nil, nil, "{}",
            String(repeating: "a", count: 64), authority.rawValue,
            "raw-authority", approvalGrantTestNow,
        ]
    )
}

private enum AdapterTestMode: Sendable {
    case terminal(operationId: String, result: ExternalOperationReceiptResultV1)
    case failure
}

private enum AdapterRecoveryTestMode: Sendable {
    case terminal(operationId: String, result: ExternalOperationReceiptResultV1)
    case noEffect(operationId: String?)
    case unresolved
}

private struct ApprovalGrantAdapterTestError: Error, Sendable, Equatable {}

private actor RecordingExternalOperationAdapter: ExternalOperationAdapterV1 {
    nonisolated let descriptor: ExternalOperationAdapterDescriptorV1
    private let executeMode: AdapterTestMode
    private let recoveryMode: AdapterRecoveryTestMode
    private var executeCalls: [(String, String)] = []
    private var recoveryCalls: [(String, String, String?)] = []

    init(
        descriptor: ExternalOperationAdapterDescriptorV1,
        executeMode: AdapterTestMode,
        recoveryMode: AdapterRecoveryTestMode
    ) {
        self.descriptor = descriptor
        self.executeMode = executeMode
        self.recoveryMode = recoveryMode
    }

    func execute(
        input: JSONValue,
        useId: String,
        idempotencyKey: String
    ) async throws -> ExternalOperationAdapterResultV1 {
        executeCalls.append((useId, idempotencyKey))
        guard case let .terminal(operationId, result) = executeMode else {
            throw ApprovalGrantAdapterTestError()
        }
        return try makeAdapterResult(
            useId: useId,
            key: idempotencyKey,
            operationId: operationId,
            result: result
        )
    }

    func recoverPending(
        useId: String,
        idempotencyKey: String,
        operationId: String?
    ) async throws -> ExternalOperationRecoveryResultV1 {
        recoveryCalls.append((useId, idempotencyKey, operationId))
        switch recoveryMode {
        case let .terminal(resolvedOperationID, result):
            return try .completed(makeAdapterResult(
                useId: useId,
                key: idempotencyKey,
                operationId: resolvedOperationID,
                result: result
            ))
        case let .noEffect(resolvedOperationID):
            return try .noEffect(AdapterNoEffectAttestationV1(
                adapterId: descriptor.adapterId,
                useId: useId,
                useIdempotencyKey: idempotencyKey,
                operationId: resolvedOperationID,
                evidenceHash: grantHash("adapter-no-effect:\(useId)"),
                receiptRef: "receipt:adapter-no-effect"
            ))
        case .unresolved:
            return .unresolved(evidenceHash: grantHash("unresolved:\(useId)"))
        }
    }

    func calls() -> (
        execute: [(String, String)],
        recovery: [(String, String, String?)]
    ) {
        (executeCalls, recoveryCalls)
    }

    private func makeAdapterResult(
        useId: String,
        key: String,
        operationId: String,
        result: ExternalOperationReceiptResultV1
    ) throws -> ExternalOperationAdapterResultV1 {
        try ExternalOperationAdapterResultV1(
            acceptance: AdapterAcceptanceAttestationV1(
                adapterId: descriptor.adapterId,
                useId: useId,
                useIdempotencyKey: key,
                operationId: operationId,
                evidenceHash: grantHash("adapter-accepted:\(useId)")
            ),
            effect: AdapterEffectAttestationV1(
                adapterId: descriptor.adapterId,
                useId: useId,
                useIdempotencyKey: key,
                operationId: operationId,
                result: result,
                receiptRef: "receipt:adapter-effect",
                evidenceHash: grantHash("adapter-effect:\(useId):\(result.rawValue)")
            )
        )
    }
}

@Suite(.serialized)
struct P1DApprovalGrantContractTests {
    @Test func approvalInputHashIsCanonicalInputOnlyAndToolRemainsSeparateScope() throws {
        let first: JSONValue = ["path": "x", "content": "y"]
        let reordered: JSONValue = ["content": "y", "path": "x"]
        let changed: JSONValue = ["path": "x", "content": "z"]
        #expect(try ApprovalToken.hash(input: first) == ApprovalToken.hash(input: reordered))
        #expect(try ApprovalToken.hash(input: first) != ApprovalToken.hash(input: changed))

        let fixture = try makeApprovalGrantFixture(input: first)
        let wrongTool = try ExternalOperationAdapterDescriptorV1(
            adapterId: "adapter:run-shell:v1",
            toolId: "run_shell",
            replayClass: .nonReplayable
        )
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(
                fixture,
                toolId: "run_shell",
                adapter: wrongTool
            )
        }
    }

    @Test func approvalAnswerCreatesTypedSingleUseGrantWithRecomputedCamp() throws {
        let fixture = try makeApprovalGrantFixture()
        let requestID = try fixture.database.suspendCardForApproval(
            cardId: fixture.ids.cardId,
            runId: nil,
            prompt: "write file?",
            tool: fixture.grant.toolId,
            input: fixture.input,
            inputHash: fixture.inputHash
        )
        let result = try fixture.store.answerApprovalRequest(
            requestId: requestID,
            answerJson: #"{"decision":"approve"}"#,
            deviceId: approvalGrantDeviceID
        )
        let grant = try #require(result.grant)
        #expect(result.approved)
        #expect(grant.id == requestID)
        #expect(grant.campId == fixture.campId)
        #expect(grant.cardId == fixture.ids.cardId)
        #expect(grant.maxUses == 1)
        #expect(grant.adapterReplayClass == .nonReplayable)
        #expect(grant.grantor.type == .user)
        #expect(grant.validFrom == approvalGrantRecordedAt)
        #expect(grant.validUntil == approvalGrantRecordedAt.addingTimeInterval(900))
        #expect(try fixture.database.card(id: fixture.ids.cardId)?.status == .ready)
        let cardEvents = try fixture.database.events(cardId: fixture.ids.cardId)
        let cardEventIDs = cardEvents.map(\.id)
        #expect(cardEvents.suffix(3).map(\.kind) == [
            "user_request_answered", "approval_decided", "card_ready",
        ])
        #expect(cardEvents.last?.payloadJson == "{}")

        let replay = try fixture.store.answerApprovalRequest(
            requestId: requestID,
            answerJson: #"{"decision":"approve"}"#,
            deviceId: approvalGrantDeviceID
        )
        #expect(replay == result)
        #expect(try fixture.database.events(cardId: fixture.ids.cardId).map(\.id) == cardEventIDs)

        let commandKey = "approval-answer:v1:\(requestID)"
        let graph = try fixture.database.pool.read { db in
            let receiptCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM domain_command_receipt
                    WHERE idempotencyKey=? AND commandType='approval-answer.v1'
                    """,
                arguments: [commandKey]
            )
            let eventCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM domain_event
                    WHERE commandIdempotencyKey=?
                      AND aggregateId=?
                      AND eventType='approval-grant.created.v1'
                    """,
                arguments: [commandKey, requestID]
            )
            let outboxCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM event_outbox o
                    JOIN domain_event e ON e.id=o.eventId
                    WHERE e.commandIdempotencyKey=? AND o.state='pending'
                    """,
                arguments: [commandKey]
            )
            return (receiptCount, eventCount, outboxCount)
        }
        #expect(graph.0 == 1)
        #expect(graph.1 == 1)
        #expect(graph.2 == 1)
    }

    @Test func rejectionCreatesNoGrantAndExpiredRevokedMismatchFailClosed() throws {
        let fixture = try makeApprovalGrantFixture()
        let requestID = try fixture.database.suspendCardForApproval(
            cardId: fixture.ids.cardId,
            runId: nil,
            prompt: "write file?",
            tool: fixture.grant.toolId,
            input: fixture.input,
            inputHash: fixture.inputHash
        )
        let denied = try fixture.store.answerApprovalRequest(
            requestId: requestID,
            answerJson: #"{"decision":"deny","reason":"no"}"#,
            deviceId: approvalGrantDeviceID
        )
        #expect(!denied.approved)
        #expect(denied.grant == nil)
        #expect(try fixture.store.grant(id: requestID) == nil)

        let revokedFixture = try makeApprovalGrantFixture()
        let revoked = try revokedFixture.store.revokeGrant(
            id: revokedFixture.grant.id,
            expectedVersion: revokedFixture.grant.version,
            envelope: grantUserEnvelope("grant.revoke:\(revokedFixture.grant.id)")
        )
        #expect(revoked.state == .revoked)
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(
                revokedFixture,
                expectedGrantVersion: revoked.version
            )
        }

        let expiredFixture = try makeApprovalGrantFixture()
        let expiredAt = approvalGrantTestNow.addingTimeInterval(901)
        let expired = try expiredFixture.store.expireGrant(
            id: expiredFixture.grant.id,
            expectedVersion: expiredFixture.grant.version,
            envelope: grantSystemEnvelope(
                "grant.expire:\(expiredFixture.grant.id)",
                at: expiredAt
            )
        )
        #expect(expired.state == .expired)
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(
                expiredFixture,
                expectedGrantVersion: expired.version,
                at: expiredAt
            )
        }
    }

    @Test func policyGrantRequiresExactImmutableRegistryTuple() throws {
        let authority = try ApprovalGrantPolicyAuthorityV1(
            id: UUID().uuidString,
            version: 3,
            actorId: "system:grant-policy:v1"
        )
        let exactGrantor = try ApprovalGrantorV1.policy(
            actorId: authority.actorId,
            policyId: authority.id,
            policyVersion: authority.version,
            policyHash: authority.contentHash
        )
        let exact = try makeApprovalGrantFixture(
            replayClass: .replaySafe,
            maxUses: 4,
            authority: authority,
            grantorOverride: exactGrantor
        )
        #expect(exact.grant.grantor == exactGrantor)

        let wrongHashGrantor = try ApprovalGrantorV1.policy(
            actorId: authority.actorId,
            policyId: authority.id,
            policyVersion: authority.version,
            policyHash: String(repeating: "a", count: 64)
        )
        #expect(throws: ApprovalGrantAuthorizationError.self) {
            _ = try makeApprovalGrantFixture(
                replayClass: .replaySafe,
                maxUses: 4,
                authority: authority,
                grantorOverride: wrongHashGrantor
            )
        }
    }

    @Test func nonReplayableGrantRequiresUserAndOneUseInSwiftAndRawSQL() throws {
        let authority = try ApprovalGrantPolicyAuthorityV1(
            id: UUID().uuidString,
            version: 1,
            actorId: "system:grant-policy:v1"
        )
        let policyGrantor = try ApprovalGrantorV1.policy(
            actorId: authority.actorId,
            policyId: authority.id,
            policyVersion: authority.version,
            policyHash: authority.contentHash
        )
        #expect(throws: ApprovalGrantAuthorizationError.self) {
            _ = try makeApprovalGrantFixture(
                replayClass: .nonReplayable,
                authority: authority,
                grantorOverride: policyGrantor
            )
        }
        #expect(throws: ApprovalGrantAuthorizationError.self) {
            _ = try makeApprovalGrantFixture(
                replayClass: .nonReplayable,
                maxUses: 2
            )
        }

        let fixture = try makeApprovalGrantFixture()
        try fixture.database.pool.write { db in
            #expect(throws: DatabaseError.self) {
                try rawInsertGrant(
                    db,
                    fixture: fixture,
                    grantorType: "user",
                    policyId: nil,
                    policyVersion: nil,
                    policyHash: nil,
                    replayClass: "nonReplayable",
                    maxUses: 2
                )
            }
            #expect(throws: DatabaseError.self) {
                try rawInsertGrant(
                    db,
                    fixture: fixture,
                    grantorType: "policy",
                    policyId: UUID().uuidString,
                    policyVersion: 1,
                    policyHash: String(repeating: "b", count: 64),
                    replayClass: "nonReplayable",
                    maxUses: 1
                )
            }
        }
    }

    @Test func reserveValidatesCapabilityScopeTimeCampAndWholePayloadReplay() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, command) = try reserveGrantUse(fixture)
        #expect(reserved.state == .reserved)
        #expect(try fixture.store.reserveUse(command) == reserved)

        let changedHash = grantHash("changed-input")
        let replayConflict = try ReserveApprovalGrantUseCommandV1(
            envelope: command.envelope,
            useId: command.useId,
            grantId: command.grantId,
            expectedGrantVersion: command.expectedGrantVersion,
            capability: command.capability,
            campId: command.campId,
            cardId: command.cardId,
            toolId: command.toolId,
            inputHash: changedHash,
            adapter: command.adapter
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try fixture.store.reserveUse(replayConflict)
        }

        let separate = try makeApprovalGrantFixture()
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(separate, capability: "tool.execute:other")
        }
        #expect(throws: DomainCommandCampUnavailableError.self) {
            _ = try reserveGrantUse(separate, campId: "other-camp")
        }
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(separate, cardId: UUID().uuidString)
        }
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(separate, inputHash: changedHash)
        }
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(
                separate,
                at: approvalGrantTestNow.addingTimeInterval(901)
            )
        }
        let wrongReplay = try ExternalOperationAdapterDescriptorV1(
            adapterId: separate.adapter.adapterId,
            toolId: separate.adapter.toolId,
            replayClass: .replaySafe
        )
        #expect(throws: ApprovalGrantScopeError.self) {
            _ = try reserveGrantUse(separate, adapter: wrongReplay)
        }
    }

    @Test func concurrentSingleUseReservationHasOneWinner() async throws {
        let fixture = try makeApprovalGrantFixture()
        let useID = try fixture.store.nextUseIdentity(grantId: fixture.grant.id)
        let command = try reserveGrantUse(
            fixture,
            useId: useID,
            key: useID
        ).1
        let results = await withTaskGroup(
            of: Result<ApprovalGrantUseSnapshotV1, Error>.self
        ) { group in
            for _ in 0..<2 {
                group.addTask {
                    Result { try fixture.store.reserveUse(command) }
                }
            }
            var values: [Result<ApprovalGrantUseSnapshotV1, Error>] = []
            for await value in group { values.append(value) }
            return values
        }
        let successes = results.compactMap { try? $0.get() }
        #expect(successes.count == 2)
        #expect(successes[0] == successes[1])
        let count = try await fixture.database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM approval_grant_use WHERE grantId=?",
                arguments: [fixture.grant.id]
            )
        }
        #expect(count == 1)
    }

    @Test func reservedWithoutDispatchIntentReleasesWithoutConsuming() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let released = try fixture.store.releaseReservedUse(
            ApprovalGrantUseTransitionCommandV1(
                envelope: grantSystemEnvelope("\(reserved.id):release"),
                useId: reserved.id,
                expectedUseVersion: reserved.version
            )
        )
        #expect(released.state == .released)
        #expect(released.finishedAt == approvalGrantTestNow)
        #expect(try fixture.store.grant(id: fixture.grant.id)?.usedCount == 0)
        #expect(try fixture.store.receipts(useId: reserved.id).isEmpty)
        #expect(
            try fixture.store.nextUseIdentity(grantId: fixture.grant.id)
                == "grant-use:v1:\(fixture.grant.id):2"
        )
    }

    @Test func dispatchIntentAtomicallyConsumesAndWritesFirstReceipt() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        let receipt = try #require(dispatched.receipt)
        #expect(dispatched.use.state == .dispatching)
        #expect(dispatched.use.version == 2)
        #expect(dispatched.grant.usedCount == 1)
        #expect(dispatched.grant.state == .exhausted)
        #expect(receipt.ordinal == 0)
        #expect(receipt.phase == .dispatchIntent)
        #expect(receipt.result == .pending)
        #expect(receipt.authority == .system)
        #expect(receipt.receiptIdempotencyKey == "external-receipt:v1:\(reserved.id):0:dispatchIntent")
        #expect(try fixture.store.receipts(useId: reserved.id) == [receipt])
    }

    @Test func adapterAcceptedCannotBeRecordedBeforeAdapterReturnAttestation() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        let wrongKey = try adapterAcceptance(
            use: dispatched.use,
            key: "wrong-use-key"
        )
        #expect(throws: ExternalOperationAttestationError.self) {
            _ = try fixture.store.recordAdapterAccepted(
                ApprovalGrantUseTransitionCommandV1(
                    envelope: grantSystemEnvelope("\(reserved.id):bad-accepted"),
                    useId: dispatched.use.id,
                    expectedUseVersion: dispatched.use.version
                ),
                attestation: wrongKey
            )
        }
        let accepted = try recordAdapterAccepted(fixture, use: dispatched.use)
        #expect(accepted.use.state == .accepted)
        #expect(accepted.use.adapterOperationId == "operation:d4:1")
        #expect(accepted.receipt?.phase == .adapterAccepted)
    }

    @Test func effectSuccessAndFailureReachConsumedTerminalsExactly() throws {
        for terminal in [
            ExternalOperationReceiptResultV1.succeeded,
            .failedFinal,
        ] {
            let fixture = try makeApprovalGrantFixture()
            let (reserved, _) = try reserveGrantUse(fixture)
            let dispatched = try dispatchGrantUse(fixture, use: reserved)
            let accepted = try recordAdapterAccepted(fixture, use: dispatched.use)
            let completed = try fixture.store.recordEffect(
                ApprovalGrantUseTransitionCommandV1(
                    envelope: grantSystemEnvelope("\(reserved.id):effect:\(terminal.rawValue)"),
                    useId: accepted.use.id,
                    expectedUseVersion: accepted.use.version
                ),
                attestation: adapterEffect(
                    use: accepted.use,
                    result: terminal
                )
            )
            #expect(completed.use.state == (terminal == .succeeded ? .succeeded : .failedFinal))
            #expect(completed.use.finishedAt == approvalGrantTestNow)
            #expect(completed.grant.usedCount == 1)
            #expect(completed.grant.state == .exhausted)
            #expect(completed.receipt?.phase == .effectConfirmed)
            #expect(completed.receipt?.result == terminal)
        }
    }

    @Test func receiptCanonicalHashKeyOrdinalReplayAndConflictAreExact() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let command = try ApprovalGrantUseTransitionCommandV1(
            envelope: grantSystemEnvelope("\(reserved.id):dispatch-exact"),
            useId: reserved.id,
            expectedUseVersion: reserved.version,
            expectedGrantVersion: fixture.grant.version
        )
        let first = try fixture.store.commitDispatchIntent(command)
        let replay = try fixture.store.commitDispatchIntent(command)
        #expect(first == replay)
        let receipt = try #require(first.receipt)
        #expect(receipt.ordinal == 0)
        #expect(receipt.receiptIdempotencyKey == "external-receipt:v1:\(reserved.id):0:dispatchIntent")
        #expect(
            receipt.receiptHash
                == CanonicalJSONV1.sha256Hex(
                    try CanonicalContractCodingV1.encode(receipt.receiptJSON)
                )
        )
        let conflict = try ApprovalGrantUseTransitionCommandV1(
            envelope: command.envelope,
            useId: command.useId,
            expectedUseVersion: command.expectedUseVersion + 1,
            expectedGrantVersion: command.expectedGrantVersion
        )
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try fixture.store.commitDispatchIntent(conflict)
        }
    }

    @Test func receiptPhaseResultAuthorityRawMatrixRejectsInvalidTuples() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let valid: Set<String> = [
            "dispatchIntent|pending|system",
            "adapterAccepted|pending|adapter",
            "effectConfirmed|succeeded|adapter",
            "effectConfirmed|failedFinal|adapter",
            "noEffectConfirmed|noEffect|adapter",
            "reconciliationFailed|unknown|adapter",
            "userResolved|succeeded|user",
            "userResolved|abandonedUnknown|user",
        ]
        try fixture.database.pool.write { db in
            for phase in ExternalOperationReceiptPhaseV1.allCases {
                for result in ExternalOperationReceiptResultV1.allCases {
                    for authority in ExternalOperationReceiptAuthorityV1.allCases {
                        let tuple = "\(phase.rawValue)|\(result.rawValue)|\(authority.rawValue)"
                        let inserted: Bool
                        do {
                            try db.inSavepoint {
                                try rawInsertReceipt(
                                    db,
                                    useId: reserved.id,
                                    ordinal: 0,
                                    phase: phase,
                                    result: result,
                                    authority: authority
                                )
                                return .rollback
                            }
                            inserted = true
                        } catch {
                            inserted = false
                        }
                        #expect(
                            inserted == valid.contains(tuple),
                            Comment(rawValue: tuple)
                        )
                    }
                }
            }
        }
    }

    @Test func dispatchAcceptanceAndTerminalPartialUniqueGuardsAreExact() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        let accepted = try recordAdapterAccepted(fixture, use: dispatched.use)
        _ = try fixture.store.recordEffect(
            ApprovalGrantUseTransitionCommandV1(
                envelope: grantSystemEnvelope("\(reserved.id):effect"),
                useId: accepted.use.id,
                expectedUseVersion: accepted.use.version
            ),
            attestation: adapterEffect(use: accepted.use, result: .succeeded)
        )
        try fixture.database.pool.write { db in
            #expect(throws: DatabaseError.self) {
                try rawInsertReceipt(
                    db,
                    useId: reserved.id,
                    ordinal: 3,
                    phase: .dispatchIntent,
                    result: .pending,
                    authority: .system
                )
            }
            #expect(throws: DatabaseError.self) {
                try rawInsertReceipt(
                    db,
                    useId: reserved.id,
                    ordinal: 3,
                    phase: .adapterAccepted,
                    result: .pending,
                    authority: .adapter
                )
            }
            #expect(throws: DatabaseError.self) {
                try rawInsertReceipt(
                    db,
                    useId: reserved.id,
                    ordinal: 3,
                    phase: .userResolved,
                    result: .succeeded,
                    authority: .user
                )
            }
        }
    }

    @Test func reconciliationFailureMayRepeatOnlyWithNextOrdinalAndNewKey() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        let first = try fixture.store.recordReconciliationFailure(
            ApprovalGrantUseTransitionCommandV1(
                envelope: grantSystemEnvelope("\(reserved.id):reconcile:1"),
                useId: dispatched.use.id,
                expectedUseVersion: dispatched.use.version
            ),
            adapterId: fixture.adapter.adapterId,
            evidenceHash: grantHash("reconcile:1")
        )
        let second = try fixture.store.recordReconciliationFailure(
            ApprovalGrantUseTransitionCommandV1(
                envelope: grantSystemEnvelope("\(reserved.id):reconcile:2"),
                useId: first.use.id,
                expectedUseVersion: first.use.version
            ),
            adapterId: fixture.adapter.adapterId,
            evidenceHash: grantHash("reconcile:2")
        )
        let receipts = try fixture.store.receipts(useId: reserved.id)
        #expect(receipts.map(\.ordinal) == [0, 1, 2])
        #expect(receipts.map(\.phase) == [.dispatchIntent, .reconciliationFailed, .reconciliationFailed])
        #expect(Set(receipts.map(\.receiptIdempotencyKey)).count == 3)
        #expect(second.use.state == .dispatching)
    }

    @Test func adapterNoEffectAttestationRefundsExactlyOnce() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        let refunded = try confirmNoEffect(
            fixture,
            use: dispatched.use,
            grantVersion: dispatched.grant.version
        )
        #expect(refunded.use.state == .released)
        #expect(refunded.grant.usedCount == 0)
        #expect(refunded.grant.state == .active)
        #expect(refunded.receipt?.phase == .noEffectConfirmed)
        #expect(throws: ApprovalGrantConflictError.self) {
            _ = try confirmNoEffect(
                fixture,
                use: refunded.use,
                grantVersion: refunded.grant.version,
                key: "\(reserved.id):no-effect-again"
            )
        }
    }

    @Test func userCannotAttestNoEffectReleaseOrRefund() throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        let attestation = try AdapterNoEffectAttestationV1(
            adapterId: fixture.adapter.adapterId,
            useId: dispatched.use.id,
            useIdempotencyKey: dispatched.use.idempotencyKey,
            operationId: nil,
            evidenceHash: grantHash("no-effect:user"),
            receiptRef: nil
        )
        #expect(throws: ApprovalGrantAuthorizationError.self) {
            _ = try fixture.store.confirmAdapterNoEffect(
                ApprovalGrantUseTransitionCommandV1(
                    envelope: grantUserEnvelope("user:no-effect"),
                    useId: dispatched.use.id,
                    expectedUseVersion: dispatched.use.version,
                    expectedGrantVersion: dispatched.grant.version
                ),
                attestation: attestation
            )
        }
        #expect(throws: ApprovalGrantAuthorizationError.self) {
            _ = try fixture.store.releaseReservedUse(
                ApprovalGrantUseTransitionCommandV1(
                    envelope: grantUserEnvelope("user:release"),
                    useId: dispatched.use.id,
                    expectedUseVersion: dispatched.use.version
                )
            )
        }
        #expect(try fixture.store.grant(id: fixture.grant.id)?.usedCount == 1)
    }

    @Test func userResolutionAllowsOnlySucceededOrAbandonedUnknownAndKeepsConsumed() throws {
        for resolution in [
            ExternalOperationUserResolutionV1.succeeded,
            .abandonedUnknown,
        ] {
            let fixture = try makeApprovalGrantFixture()
            let (reserved, _) = try reserveGrantUse(fixture)
            let dispatched = try dispatchGrantUse(fixture, use: reserved)
            let result = try fixture.store.resolveExternalOperation(
                ResolveExternalOperationCommandV1(
                    envelope: grantUserEnvelope("\(reserved.id):user:\(resolution.rawValue)"),
                    useId: dispatched.use.id,
                    expectedUseVersion: dispatched.use.version,
                    resolution: resolution,
                    reason: "owner-confirmed"
                )
            )
            #expect(result.use.state == (resolution == .succeeded ? .succeeded : .abandonedUnknown))
            #expect(result.grant.usedCount == 1)
            #expect(result.grant.state == .exhausted)
            #expect(result.receipt?.authority == .user)
        }
    }

    @Test func noEffectAndUserResolutionCASHaveOneWinner() async throws {
        let fixture = try makeApprovalGrantFixture()
        let (reserved, _) = try reserveGrantUse(fixture)
        let dispatched = try dispatchGrantUse(fixture, use: reserved)
        async let noEffect: Bool = {
            do {
                _ = try confirmNoEffect(
                    fixture,
                    use: dispatched.use,
                    grantVersion: dispatched.grant.version,
                    key: "\(reserved.id):race:no-effect"
                )
                return true
            } catch { return false }
        }()
        async let user: Bool = {
            do {
                _ = try fixture.store.resolveExternalOperation(
                    ResolveExternalOperationCommandV1(
                        envelope: grantUserEnvelope("\(reserved.id):race:user"),
                        useId: dispatched.use.id,
                        expectedUseVersion: dispatched.use.version,
                        resolution: .succeeded,
                        reason: "owner-confirmed"
                    )
                )
                return true
            } catch { return false }
        }()
        let winners = await [noEffect, user].filter { $0 }
        #expect(winners.count == 1)
        let use = try #require(try fixture.store.use(id: reserved.id))
        #expect(use.state == .released || use.state == .succeeded)
        #expect(try fixture.store.receipts(useId: reserved.id).filter {
            $0.phase == .noEffectConfirmed || $0.phase == .userResolved
        }.count == 1)
    }

    @Test func refundReducerPreservesRevokedExpiredAndUnderusedRules() throws {
        let activeFixture = try makeApprovalGrantFixture(
            replayClass: .replaySafe,
            maxUses: 2
        )
        let (activeReserved, _) = try reserveGrantUse(activeFixture)
        let activeDispatch = try dispatchGrantUse(activeFixture, use: activeReserved)
        let activeRefund = try confirmNoEffect(
            activeFixture,
            use: activeDispatch.use,
            grantVersion: activeDispatch.grant.version
        )
        #expect(activeRefund.grant.state == .active)
        #expect(activeRefund.grant.usedCount == 0)

        let revokedFixture = try makeApprovalGrantFixture()
        let (revokedReserved, _) = try reserveGrantUse(revokedFixture)
        let revokedDispatch = try dispatchGrantUse(revokedFixture, use: revokedReserved)
        let revokedGrant = try revokedFixture.store.revokeGrant(
            id: revokedFixture.grant.id,
            expectedVersion: revokedDispatch.grant.version,
            envelope: grantUserEnvelope("\(revokedReserved.id):revoke")
        )
        let revokedRefund = try confirmNoEffect(
            revokedFixture,
            use: revokedDispatch.use,
            grantVersion: revokedGrant.version
        )
        #expect(revokedRefund.grant.state == .revoked)
        #expect(revokedRefund.grant.usedCount == 0)

        let expiredFixture = try makeApprovalGrantFixture()
        let (expiredReserved, _) = try reserveGrantUse(expiredFixture)
        let expiredDispatch = try dispatchGrantUse(expiredFixture, use: expiredReserved)
        let expiredAt = approvalGrantTestNow.addingTimeInterval(901)
        let expiredGrant = try expiredFixture.store.expireGrant(
            id: expiredFixture.grant.id,
            expectedVersion: expiredDispatch.grant.version,
            envelope: grantSystemEnvelope(
                "\(expiredReserved.id):expire",
                at: expiredAt
            )
        )
        let expiredRefund = try confirmNoEffect(
            expiredFixture,
            use: expiredDispatch.use,
            grantVersion: expiredGrant.version,
            at: expiredAt
        )
        #expect(expiredRefund.grant.state == .expired)
        #expect(expiredRefund.grant.usedCount == 0)
    }

    @Test func refundVersusRevokeAndExpiryRacesNeverResurrectOrDoubleDecrement() async throws {
        let revokeFixture = try makeApprovalGrantFixture()
        let (revokeReserved, _) = try reserveGrantUse(revokeFixture)
        let revokeDispatch = try dispatchGrantUse(revokeFixture, use: revokeReserved)
        async let refundWon: Bool = {
            do {
                _ = try confirmNoEffect(
                    revokeFixture,
                    use: revokeDispatch.use,
                    grantVersion: revokeDispatch.grant.version,
                    key: "\(revokeReserved.id):refund-race"
                )
                return true
            } catch { return false }
        }()
        async let revokeWon: Bool = {
            do {
                _ = try revokeFixture.store.revokeGrant(
                    id: revokeFixture.grant.id,
                    expectedVersion: revokeDispatch.grant.version,
                    envelope: grantUserEnvelope("\(revokeReserved.id):revoke-race")
                )
                return true
            } catch { return false }
        }()
        #expect(await [refundWon, revokeWon].filter { $0 }.count == 1)
        let revokeFinal = try #require(try revokeFixture.store.grant(id: revokeFixture.grant.id))
        #expect(revokeFinal.usedCount == 0 || revokeFinal.usedCount == 1)
        #expect(
            (revokeFinal.usedCount == 0 && revokeFinal.state == .active)
                || (revokeFinal.usedCount == 1 && revokeFinal.state == .revoked)
        )

        let expiryFixture = try makeApprovalGrantFixture()
        let (expiryReserved, _) = try reserveGrantUse(expiryFixture)
        let expiryDispatch = try dispatchGrantUse(expiryFixture, use: expiryReserved)
        let expiredAt = approvalGrantTestNow.addingTimeInterval(901)
        async let expiryRefundWon: Bool = {
            do {
                _ = try confirmNoEffect(
                    expiryFixture,
                    use: expiryDispatch.use,
                    grantVersion: expiryDispatch.grant.version,
                    key: "\(expiryReserved.id):expiry-refund-race",
                    at: expiredAt
                )
                return true
            } catch { return false }
        }()
        async let expiryWon: Bool = {
            do {
                _ = try expiryFixture.store.expireGrant(
                    id: expiryFixture.grant.id,
                    expectedVersion: expiryDispatch.grant.version,
                    envelope: grantSystemEnvelope(
                        "\(expiryReserved.id):expiry-race",
                        at: expiredAt
                    )
                )
                return true
            } catch { return false }
        }()
        #expect(await [expiryRefundWon, expiryWon].filter { $0 }.count == 1)
        let expiryFinal = try #require(try expiryFixture.store.grant(id: expiryFixture.grant.id))
        #expect(expiryFinal.state == .expired)
        #expect(expiryFinal.usedCount == 0 || expiryFinal.usedCount == 1)
    }

    @Test func lateReconcileCannotChangeSucceededOrAbandonedUnknown() throws {
        for resolution in [
            ExternalOperationUserResolutionV1.succeeded,
            .abandonedUnknown,
        ] {
            let fixture = try makeApprovalGrantFixture()
            let (reserved, _) = try reserveGrantUse(fixture)
            let dispatched = try dispatchGrantUse(fixture, use: reserved)
            let resolved = try fixture.store.resolveExternalOperation(
                ResolveExternalOperationCommandV1(
                    envelope: grantUserEnvelope("\(reserved.id):resolve"),
                    useId: dispatched.use.id,
                    expectedUseVersion: dispatched.use.version,
                    resolution: resolution,
                    reason: "owner-final"
                )
            )
            #expect(throws: ApprovalGrantConflictError.self) {
                _ = try confirmNoEffect(
                    fixture,
                    use: resolved.use,
                    grantVersion: resolved.grant.version,
                    key: "\(reserved.id):late-no-effect"
                )
            }
            #expect(try fixture.store.use(id: reserved.id)?.state == resolved.use.state)
        }
    }

    @Test func nonReplayableCrashAtEveryAmbiguousWindowStopsCrashUnknown() async throws {
        for checkpoint in ExternalOperationWorkflowCheckpointV1.allCases {
            let fixture = try makeApprovalGrantFixture()
            let adapter = RecordingExternalOperationAdapter(
                descriptor: fixture.adapter,
                executeMode: .terminal(operationId: "op:crash", result: .succeeded),
                recoveryMode: .terminal(operationId: "op:crash", result: .succeeded)
            )
            let coordinator = ExternalOperationWorkflowCoordinator(
                store: fixture.store,
                clock: { approvalGrantTestNow },
                registeredAdapters: [adapter],
                checkpoint: { reached, _ in
                    if reached == checkpoint {
                        throw ExternalOperationInjectedCrashV1(checkpoint: reached)
                    }
                }
            )
            await #expect(throws: ExternalOperationInjectedCrashV1.self) {
                _ = try await coordinator.execute(
                    grantId: fixture.grant.id,
                    expectedGrantVersion: fixture.grant.version,
                    capability: fixture.grant.capability,
                    campId: fixture.campId,
                    cardId: fixture.ids.cardId,
                    toolId: fixture.grant.toolId,
                    input: fixture.input,
                    adapter: adapter
                )
            }
            let uses = try fixture.store.uses(grantId: fixture.grant.id)
            let use = try #require(uses.first)
            if checkpoint == .beforeDispatchIntent {
                #expect(use.state == .reserved)
            } else {
                let recovery = ExternalOperationWorkflowCoordinator(
                    store: fixture.store,
                    clock: { approvalGrantTestNow }
                )
                await #expect(throws: ExternalOperationUserResolutionRequiredV1.self) {
                    try await recovery.recoverPending()
                }
                #expect(try fixture.store.use(id: use.id)?.state == .crashUnknown)
            }
        }
    }

    @Test func replaySafeAndIdempotencyKeyedRecoveryReuseExactKeyAndOperation() async throws {
        for replayClass in [
            ExternalAdapterReplayClassV1.replaySafe,
            .idempotencyKeyed,
        ] {
            let fixture = try makeApprovalGrantFixture(
                replayClass: replayClass,
                maxUses: 2
            )
            let operationID = "operation:\(replayClass.rawValue)"
            let adapter = RecordingExternalOperationAdapter(
                descriptor: fixture.adapter,
                executeMode: .terminal(operationId: operationID, result: .succeeded),
                recoveryMode: .terminal(operationId: operationID, result: .succeeded)
            )
            let crashPoint: ExternalOperationWorkflowCheckpointV1 = replayClass == .replaySafe
                ? .afterDispatchIntentBeforeAdapter
                : .afterAdapterAcceptedBeforeTerminal
            let crashing = ExternalOperationWorkflowCoordinator(
                store: fixture.store,
                clock: { approvalGrantTestNow },
                registeredAdapters: [adapter],
                checkpoint: { reached, _ in
                    if reached == crashPoint {
                        throw ExternalOperationInjectedCrashV1(checkpoint: reached)
                    }
                }
            )
            await #expect(throws: ExternalOperationInjectedCrashV1.self) {
                _ = try await crashing.execute(
                    grantId: fixture.grant.id,
                    expectedGrantVersion: fixture.grant.version,
                    capability: fixture.grant.capability,
                    campId: fixture.campId,
                    cardId: fixture.ids.cardId,
                    toolId: fixture.grant.toolId,
                    input: fixture.input,
                    adapter: adapter
                )
            }
            let recovering = ExternalOperationWorkflowCoordinator(
                store: fixture.store,
                clock: { approvalGrantTestNow },
                registeredAdapters: [adapter]
            )
            try await recovering.recoverPending()
            let use = try #require(try fixture.store.uses(grantId: fixture.grant.id).first)
            #expect(use.state == .succeeded)
            let calls = await adapter.calls()
            let recovery = try #require(calls.recovery.last)
            #expect(recovery.0 == use.id)
            #expect(recovery.1 == use.idempotencyKey)
            if replayClass == .idempotencyKeyed {
                #expect(recovery.2 == operationID)
            }
        }
    }

    @Test func coordinatorOwnsReserveDispatchAdapterReceiptOrderAndConvergesExternalSuccessCrash() async throws {
        let fixture = try makeApprovalGrantFixture()
        let adapter = RecordingExternalOperationAdapter(
            descriptor: fixture.adapter,
            executeMode: .terminal(operationId: "operation:normal", result: .succeeded),
            recoveryMode: .terminal(operationId: "operation:normal", result: .succeeded)
        )
        let coordinator = ExternalOperationWorkflowCoordinator(
            store: fixture.store,
            clock: { approvalGrantTestNow },
            registeredAdapters: [adapter]
        )
        let acknowledgment = try await coordinator.execute(
            grantId: fixture.grant.id,
            expectedGrantVersion: fixture.grant.version,
            capability: fixture.grant.capability,
            campId: fixture.campId,
            cardId: fixture.ids.cardId,
            toolId: fixture.grant.toolId,
            input: fixture.input,
            adapter: adapter
        )
        #expect(acknowledgment.state == .succeeded)
        #expect(acknowledgment.useId == "grant-use:v1:\(fixture.grant.id):1")
        let receipts = try fixture.store.receipts(useId: acknowledgment.useId)
        #expect(receipts.map(\.ordinal) == [0, 1, 2])
        #expect(receipts.map(\.phase) == [.dispatchIntent, .adapterAccepted, .effectConfirmed])
        #expect(receipts.map(\.authority) == [.system, .adapter, .adapter])
        let calls = await adapter.calls()
        #expect(calls.execute.count == 1)
        #expect(calls.execute[0].0 == acknowledgment.useId)
        #expect(calls.execute[0].1 == "grant-use:v1:\(fixture.grant.id):1")
        #expect(try fixture.store.grant(id: fixture.grant.id)?.usedCount == 1)
    }
}
