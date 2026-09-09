import Foundation
import GRDB
import Testing
@testable import AgentLoopApplication
@testable import AgentLoopCore

private let p1dAcceptanceID = "90000000-0000-4000-8000-000000000001"
private let p1dReturnID = "90000000-0000-4000-8000-000000000002"
private let p1dRevokeID = "90000000-0000-4000-8000-000000000003"
private let p1dPolicyID = "92000000-0000-4000-8000-000000000001"
private let p1dPolicyActor = "policy:acceptance:test:v1"

private struct P1DAcceptanceFixture {
    let domain: P1DOutcomeFixture
    let delivered: OutcomeSnapshotV1
    let verificationId: String
}

private func p1dAcceptancePolicy(
    id: String = p1dPolicyID,
    outcomeType: String = "coding",
    maxRisk: OutcomeRiskClassV1 = .normal,
    actorId: String = p1dPolicyActor,
    validFrom: Date = p1dEpoch.addingTimeInterval(-100),
    validUntil: Date = p1dEpoch.addingTimeInterval(1_000),
    maxAge: Int = 500,
    status: AcceptancePolicyStatusV1 = .active
) throws -> AcceptancePolicyVersionV1 {
    try AcceptancePolicyVersionV1(
        id: id,
        version: 1,
        outcomeType: outcomeType,
        maxRiskClass: maxRisk,
        policyActorId: actorId,
        validFrom: validFrom,
        validUntil: validUntil,
        maxOutcomeAgeSeconds: maxAge,
        status: status,
        revokedAt: status == .revoked ? p1dEpoch : nil,
        createdByActorId: P1DActorID.localOwner,
        createdAt: p1dEpoch.addingTimeInterval(-200)
    )
}

private func p1dAcceptanceBody(
    outcomeType: String = "coding",
    policy: AcceptancePolicyRefV1? = nil,
    subjective: Bool = false,
    publicRelease: Bool = false,
    payment: Bool = false,
    deletion: Bool = false,
    externalSend: Bool = false,
    risk: OutcomeRiskClassV1 = .normal
) throws -> OutcomeContractBodyV1 {
    try OutcomeContractBodyV1(
        outcomeType: outcomeType,
        deliverables: ["Artifact"],
        acceptanceCriteria: ["Tests pass"],
        verificationGroups: [try VerificationRequirementGroupV1(
            groupId: "group-tests",
            mode: .all,
            requirements: [p1dRequirement()]
        )],
        unacceptableDeviations: ["Missing artifact"],
        requiredDependencies: [],
        optionalDependencies: [],
        requiresSubjectiveJudgment: subjective,
        includesPublicRelease: publicRelease,
        includesPayment: payment,
        includesDeletion: deletion,
        includesExternalSend: externalSend,
        riskClass: risk,
        acceptanceOwner: policy == nil ? .user : .policy,
        acceptancePolicy: policy
    )
}

private func p1dAcceptanceFixture(
    _ label: String,
    base suppliedBase: P1DContractFixture? = nil,
    contractId: String = "60000000-0000-4000-8000-000000000001",
    outcomeId: String = p1dOutcomeID,
    verificationId: String = "81000000-0000-4000-8000-000000000001",
    body: OutcomeContractBodyV1? = nil,
    policy: AcceptancePolicyVersionV1? = nil
) throws -> P1DAcceptanceFixture {
    let base = try suppliedBase ?? p1dContractFixture(
        label,
        goalStatus: .ready,
        missionStatus: .delivering
    )
    if let policy {
        _ = try base.store.registerAcceptancePolicy(policy)
    }
    let draft = try p1dCreateDraft(
        base,
        contractID: contractId,
        key: "p1d:\(label):contract:create",
        body: body ?? p1dAcceptanceBody()
    )
    let contract = try p1dActivateContract(
        base,
        draft: draft,
        key: "p1d:\(label):contract:activate"
    )
    let activated = try base.store.activateGoal(
        ActivateGoalCommandV1(
            envelope: p1dUserEnvelope("p1d:\(label):goal:activate"),
            goal: GoalHeadV1(
                goalId: base.goal.id,
                campId: base.goal.campId,
                expectedGoalVersion: base.goal.aggregateVersion
            ),
            contract: contract.ref,
            missionId: base.mission.id,
            expectedLinkVersion: nil
        )
    )
    let domain = P1DOutcomeFixture(
        base: base,
        contract: contract,
        goal: activated.goal,
        store: base.store
    )
    let initial = try p1dRecordInitial(
        domain,
        outcomeId: outcomeId,
        key: "p1d:\(label):outcome:initial",
        manifest: [try OutcomeArtifactRefV1(
            kind: .externalReceipt,
            locator: "receipt://\(label)",
            contentHash: String(repeating: "a", count: 64)
        )]
    )
    let pending = try p1dBeginVerification(
        domain,
        outcome: initial,
        key: "p1d:\(label):verification:begin"
    )
    _ = try p1dRecordVerification(
        domain,
        outcome: pending,
        recordId: verificationId,
        key: "p1d:\(label):verification:record"
    )
    let verified = try p1dRequireOutcome(domain, id: outcomeId)
    let delivered = try base.store.markDelivered(
        MarkDeliveredCommandV1(
            envelope: p1dSystemEnvelope(
                "p1d:\(label):deliver",
                actorId: P1DActorID.delivery
            ),
            outcome: verified.currentRef,
            expectedAggregateVersion: verified.aggregateVersion
        )
    )
    let acceptanceDomain = P1DOutcomeFixture(
        base: base,
        contract: contract,
        goal: activated.goal,
        store: OutcomeStore(
            database: base.database,
            clock: { p1dEpoch.addingTimeInterval(10_000) }
        )
    )
    return P1DAcceptanceFixture(
        domain: acceptanceDomain,
        delivered: delivered,
        verificationId: verificationId
    )
}

private func p1dAdditionalBase(
    from original: P1DContractFixture,
    ordinal: Int
) throws -> P1DContractFixture {
    let tail = String(format: "%012d", ordinal + 1)
    let missionId = "30000000-0000-4000-8000-\(tail)"
    let goalId = "50000000-0000-4000-8000-\(tail)"
    let mission = MissionRecord(
        id: missionId,
        squadId: original.mission.squadId,
        goalRaw: "Additional acceptance goal",
        goalRefined: "Additional acceptance goal",
        status: .delivering,
        budgetTokens: 10_000,
        spentTokens: 0,
        revision: 1,
        createdAt: p1dEpoch
    )
    let goal = try GoalControllerRecord(
        id: goalId,
        campId: original.camp.id,
        sourceInputId: nil,
        title: "Additional goal",
        rawIntent: "Additional acceptance goal",
        status: .ready,
        currentUnderstandingId: goalId,
        currentUnderstandingVersion: 1,
        currentOutcomeContractId: nil,
        currentOutcomeContractVersion: nil,
        aggregateVersion: 1,
        createdByActorId: P1DActorID.localOwner,
        createdAt: p1dEpoch,
        updatedAt: p1dEpoch
    )
    let understanding = try UnderstandingCardVersionRecord(
        id: goalId,
        version: 1,
        goalId: goalId,
        content: original.understanding.content,
        status: .confirmed,
        createdByActorId: P1DActorID.coach,
        confirmedByActorId: P1DActorID.localOwner,
        confirmedAt: p1dEpoch,
        createdAt: p1dEpoch
    )
    try original.database.pool.write { db in
        try mission.insert(db)
        try goal.insert(db)
        try understanding.insert(db)
    }
    return P1DContractFixture(
        database: original.database,
        store: original.store,
        camp: original.camp,
        goal: goal,
        understanding: understanding,
        mission: mission
    )
}

private func p1dUserAcceptance(
    _ fixture: P1DAcceptanceFixture,
    id: String = p1dAcceptanceID,
    key: String = "p1d:accept:user",
    at: Date = p1dEpoch.addingTimeInterval(1)
) throws -> AcceptanceCommitSnapshotV1 {
    try fixture.domain.store.acceptOutcome(
        AcceptOutcomeCommandV1(
            envelope: p1dUserEnvelope(key, at: at),
            acceptanceId: id,
            outcome: fixture.delivered.currentRef,
            expectedOutcomeAggregateVersion:
                fixture.delivered.aggregateVersion,
            subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
            reason: "User accepted"
        )
    )
}

private func p1dPolicyCommand(
    _ fixture: P1DAcceptanceFixture,
    subject: AcceptanceSubjectV1,
    id: String = p1dAcceptanceID,
    key: String = "p1d:accept:policy",
    at: Date = p1dEpoch.addingTimeInterval(1)
) throws -> AcceptOutcomeCommandV1 {
    try AcceptOutcomeCommandV1(
        envelope: p1dSystemEnvelope(key, actorId: subject.id, at: at),
        acceptanceId: id,
        outcome: fixture.delivered.currentRef,
        expectedOutcomeAggregateVersion: fixture.delivered.aggregateVersion,
        subject: subject,
        reason: "Policy accepted"
    )
}

private func p1dSeedAcceptedHistory(
    _ fixture: P1DAcceptanceFixture,
    id: String = "93000000-0000-4000-8000-000000000001"
) throws {
    try fixture.domain.base.database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO acceptance_record(
                  id,commandIdempotencyKey,contractId,contractVersion,
                  contractHash,outcomeId,outcomeVersion,outcomeHash,
                  subjectType,subjectId,policyId,policyVersion,decision,
                  reason,supersedesAcceptanceId,createdAt,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,'user',?,NULL,NULL,'accepted',?,NULL,?,NULL)
                """,
            arguments: [
                id, "seed:\(id)", fixture.delivered.contract.id,
                fixture.delivered.contract.version,
                fixture.delivered.contract.hash, fixture.delivered.id,
                fixture.delivered.currentVersion,
                fixture.delivered.currentRef.hash,
                P1DActorID.localOwner, "Seeded prior acceptance", p1dEpoch,
            ]
        )
    }
}

private func p1dExpectHardGuard(
    _ expected: AcceptanceHardGuardReasonV1,
    command: AcceptOutcomeCommandV1,
    store: OutcomeStore
) {
    do {
        _ = try store.acceptOutcome(command)
        Issue.record("Expected user_acceptance_required")
    } catch let error as UserAcceptanceRequiredError {
        #expect(error.reason == expected)
    } catch {
        Issue.record("Wrong error before policy lookup: \(error)")
    }
}

private func p1dGoalAndMission(
    _ fixture: P1DAcceptanceFixture
) throws -> (GoalControllerRecord, MissionRecord) {
    try fixture.domain.base.database.pool.read { db in
        let goal = try GoalControllerRecord.fetchOne(
            db, key: fixture.delivered.goalId
        )
        let mission = try MissionRecord.fetchOne(
            db, key: fixture.delivered.missionId
        )
        return (try #require(goal), try #require(mission))
    }
}

@Suite(.serialized)
struct P1DAcceptanceWorkflowTests {
    @Test func firstOnboardingRequiresUserBeforePolicyLookup() throws {
        let policy = try p1dAcceptancePolicy()
        let fixture = try p1dAcceptanceFixture(
            "first-onboarding",
            body: p1dAcceptanceBody(policy: policy.ref),
            policy: policy
        )
        let missing = try AcceptancePolicyRefV1(
            id: "92000000-0000-4000-8000-000000000099",
            version: 1,
            hash: String(repeating: "f", count: 64)
        )
        let subject = try AcceptanceSubjectV1.policy(
            actorId: p1dPolicyActor,
            ref: missing
        )
        p1dExpectHardGuard(
            .firstOnboarding,
            command: try p1dPolicyCommand(fixture, subject: subject),
            store: fixture.domain.store
        )
    }

    @Test func firstOutcomeTypeRequiresUserBeforePolicyLookup() throws {
        let seedBase = try p1dContractFixture(
            "first-type",
            goalStatus: .ready,
            missionStatus: .delivering
        )
        let seed = try p1dAcceptanceFixture(
            "first-type-seed",
            base: seedBase,
            body: p1dAcceptanceBody(outcomeType: "other")
        )
        _ = try p1dUserAcceptance(seed, key: "first-type:user-seed")
        let targetBase = try p1dAdditionalBase(from: seedBase, ordinal: 1)
        let policy = try p1dAcceptancePolicy(outcomeType: "coding")
        let target = try p1dAcceptanceFixture(
            "first-type-target",
            base: targetBase,
            contractId: "60000000-0000-4000-8000-000000000002",
            outcomeId: "80000000-0000-4000-8000-000000000002",
            verificationId: "81000000-0000-4000-8000-000000000002",
            body: p1dAcceptanceBody(policy: policy.ref),
            policy: policy
        )
        let missing = try AcceptancePolicyRefV1(
            id: "92000000-0000-4000-8000-000000000099",
            version: 1,
            hash: String(repeating: "f", count: 64)
        )
        let subject = try AcceptanceSubjectV1.policy(
            actorId: p1dPolicyActor,
            ref: missing
        )
        p1dExpectHardGuard(
            .firstOutcomeType,
            command: try p1dPolicyCommand(target, subject: subject),
            store: target.domain.store
        )
    }

    @Test func eachContractHardGuardRequiresUserBeforePolicyLookup() throws {
        let cases: [(String, AcceptanceHardGuardReasonV1,
            (AcceptancePolicyRefV1) throws -> OutcomeContractBodyV1)] = [
            ("subjective", .subjectiveJudgment, { try p1dAcceptanceBody(policy: $0, subjective: true) }),
            ("public", .publicRelease, { try p1dAcceptanceBody(policy: $0, publicRelease: true) }),
            ("payment", .payment, { try p1dAcceptanceBody(policy: $0, payment: true) }),
            ("deletion", .deletion, { try p1dAcceptanceBody(policy: $0, deletion: true) }),
            ("external", .externalSend, { try p1dAcceptanceBody(policy: $0, externalSend: true) }),
        ]
        for (label, expected, makeBody) in cases {
            let policy = try p1dAcceptancePolicy()
            let fixture = try p1dAcceptanceFixture(
                "guard-\(label)",
                body: makeBody(policy.ref),
                policy: policy
            )
            try p1dSeedAcceptedHistory(fixture)
            let missing = try AcceptancePolicyRefV1(
                id: "92000000-0000-4000-8000-000000000099",
                version: 1,
                hash: String(repeating: "f", count: 64)
            )
            p1dExpectHardGuard(
                expected,
                command: try p1dPolicyCommand(
                    fixture,
                    subject: AcceptanceSubjectV1.policy(
                        actorId: p1dPolicyActor,
                        ref: missing
                    )
                ),
                store: fixture.domain.store
            )
        }
    }

    @Test func highIrreversibleAndUnverifiedRequireUserBeforePolicyLookup() throws {
        for (label, risk, expected) in [
            ("high", OutcomeRiskClassV1.high, AcceptanceHardGuardReasonV1.highRisk),
            ("irreversible", .irreversible, .irreversibleRisk),
        ] {
            let policy = try p1dAcceptancePolicy()
            let fixture = try p1dAcceptanceFixture(
                "guard-\(label)",
                body: p1dAcceptanceBody(policy: policy.ref, risk: risk),
                policy: policy
            )
            try p1dSeedAcceptedHistory(fixture)
            let missing = try AcceptancePolicyRefV1(
                id: "92000000-0000-4000-8000-000000000099",
                version: 1,
                hash: String(repeating: "f", count: 64)
            )
            p1dExpectHardGuard(
                expected,
                command: try p1dPolicyCommand(
                    fixture,
                    subject: AcceptanceSubjectV1.policy(
                        actorId: p1dPolicyActor, ref: missing
                    )
                ),
                store: fixture.domain.store
            )
        }
        let policy = try p1dAcceptancePolicy()
        let unverified = try p1dAcceptanceFixture(
            "guard-unverified",
            body: p1dAcceptanceBody(policy: policy.ref),
            policy: policy
        )
        try p1dSeedAcceptedHistory(unverified)
        try unverified.domain.base.database.pool.write { db in
            try db.execute(
                sql: "UPDATE verification_result_head SET derivedResult='invalid' WHERE currentVerificationId=?",
                arguments: [unverified.verificationId]
            )
        }
        let missing = try AcceptancePolicyRefV1(
            id: "92000000-0000-4000-8000-000000000099",
            version: 1,
            hash: String(repeating: "f", count: 64)
        )
        p1dExpectHardGuard(
            .unverified,
            command: try p1dPolicyCommand(
                unverified,
                subject: AcceptanceSubjectV1.policy(
                    actorId: p1dPolicyActor, ref: missing
                )
            ),
            store: unverified.domain.store
        )
    }

    @Test func eligiblePolicyRequiresExactActiveVersionHashActorRiskAgeAndTime() throws {
        struct Case {
            let label: String
            let policy: AcceptancePolicyVersionV1
            let bodyRisk: OutcomeRiskClassV1
            let subjectActor: String
            let subjectRef: (AcceptancePolicyVersionV1) throws -> AcceptancePolicyRefV1
            let at: Date
            let shouldPass: Bool
        }
        let active = try p1dAcceptancePolicy()
        let cases = [
            Case(label: "valid", policy: active, bodyRisk: .normal,
                 subjectActor: p1dPolicyActor, subjectRef: { $0.ref },
                 at: p1dEpoch.addingTimeInterval(1), shouldPass: true),
            Case(label: "hash", policy: active, bodyRisk: .normal,
                 subjectActor: p1dPolicyActor, subjectRef: { try .init(
                    id: $0.ref.id, version: $0.ref.version,
                    hash: String(repeating: "f", count: 64)) },
                 at: p1dEpoch.addingTimeInterval(1), shouldPass: false),
            Case(label: "actor", policy: active, bodyRisk: .normal,
                 subjectActor: "policy:wrong:v1", subjectRef: { $0.ref },
                 at: p1dEpoch.addingTimeInterval(1), shouldPass: false),
            Case(label: "revoked", policy: try p1dAcceptancePolicy(status: .revoked),
                 bodyRisk: .normal, subjectActor: p1dPolicyActor,
                 subjectRef: { $0.ref }, at: p1dEpoch.addingTimeInterval(1), shouldPass: false),
            Case(label: "time", policy: try p1dAcceptancePolicy(
                    validFrom: p1dEpoch.addingTimeInterval(-200),
                    validUntil: p1dEpoch.addingTimeInterval(-1)),
                 bodyRisk: .normal, subjectActor: p1dPolicyActor,
                 subjectRef: { $0.ref }, at: p1dEpoch, shouldPass: false),
            Case(label: "type", policy: try p1dAcceptancePolicy(outcomeType: "writing"),
                 bodyRisk: .normal, subjectActor: p1dPolicyActor,
                 subjectRef: { $0.ref }, at: p1dEpoch.addingTimeInterval(1), shouldPass: false),
            Case(label: "risk", policy: try p1dAcceptancePolicy(maxRisk: .low),
                 bodyRisk: .normal, subjectActor: p1dPolicyActor,
                 subjectRef: { $0.ref }, at: p1dEpoch.addingTimeInterval(1), shouldPass: false),
            Case(label: "age", policy: try p1dAcceptancePolicy(maxAge: 10),
                 bodyRisk: .normal, subjectActor: p1dPolicyActor,
                 subjectRef: { $0.ref }, at: p1dEpoch.addingTimeInterval(20), shouldPass: false),
        ]
        for item in cases {
            let fixture = try p1dAcceptanceFixture(
                "policy-\(item.label)",
                body: p1dAcceptanceBody(
                    outcomeType: "coding",
                    policy: item.policy.ref,
                    risk: item.bodyRisk
                ),
                policy: item.policy
            )
            try p1dSeedAcceptedHistory(fixture)
            let subject = try AcceptanceSubjectV1.policy(
                actorId: item.subjectActor,
                ref: item.subjectRef(item.policy)
            )
            let command = try p1dPolicyCommand(
                fixture,
                subject: subject,
                key: "policy:\(item.label)",
                at: item.at
            )
            if item.shouldPass {
                let result = try fixture.domain.store.acceptOutcome(command)
                #expect(result.record.subject == subject)
                #expect(result.outcome.state == .accepted)
            } else {
                #expect(throws: (any Error).self) {
                    try fixture.domain.store.acceptOutcome(command)
                }
                let acceptanceCount = try fixture.domain.store
                    .acceptanceCount(outcomeId: fixture.delivered.id)
                #expect(acceptanceCount == 1)
            }
        }
    }

    @Test func acceptanceCommitAtomicallyUpdatesRecordOutcomeGoalMissionMetricEvents() throws {
        let fixture = try p1dAcceptanceFixture("accept-atomic")
        let result = try p1dUserAcceptance(fixture)
        let (goal, mission) = try p1dGoalAndMission(fixture)
        let storedMetric = try fixture.domain.store.metricCredit(
            outcomeId: fixture.delivered.id
        )
        let metric = try #require(storedMetric)
        #expect(result.outcome.state == .accepted)
        #expect(goal.status == .achieved)
        #expect(mission.status == .accepted)
        #expect(metric.state == .active)
        #expect(metric.creditedOutcomeVersion == 1)
        let storedRecord = try fixture.domain.store.acceptanceRecord(
            id: p1dAcceptanceID
        )
        #expect(storedRecord == result.record)
        try fixture.domain.base.database.pool.read { db in
            let receiptCount = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM domain_command_receipt WHERE idempotencyKey='p1d:accept:user'")
            let eventCount = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM domain_event WHERE commandIdempotencyKey='p1d:accept:user'")
            let outboxCount = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM event_outbox o JOIN domain_event e ON e.id=o.eventId WHERE e.commandIdempotencyKey='p1d:accept:user'")
            #expect(receiptCount == 1)
            #expect(eventCount == 1)
            #expect(outboxCount == 1)
        }
    }

    @Test func acceptanceFailureLeavesProjectionAndNavigationUnchangedWithTrace() throws {
        let fixture = try p1dAcceptanceFixture("accept-failure")
        try fixture.domain.base.database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER p1d_fail_metric BEFORE INSERT ON outcome_metric_credit
                BEGIN SELECT RAISE(ABORT, 'injected metric failure'); END
                """)
        }
        let command = try AcceptOutcomeCommandV1(
            envelope: p1dUserEnvelope("accept-failure", at: p1dEpoch.addingTimeInterval(1)),
            acceptanceId: p1dAcceptanceID,
            outcome: fixture.delivered.currentRef,
            expectedOutcomeAggregateVersion: fixture.delivered.aggregateVersion,
            subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
            reason: "User accepted"
        )
        let result = AcceptanceWorkflowController
            .live(store: fixture.domain.store)
            .accept(command)
        #expect(result.mayNavigate == false)
        guard case .notCommitted(let failure) = result else {
            Issue.record("Expected notCommitted")
            return
        }
        #expect(failure.traceId == "trace:accept-failure")
        #expect(failure.message.contains("trace:accept-failure"))
        let storedOutcome = try fixture.domain.store.outcome(
            id: fixture.delivered.id
        )
        let unchanged = try #require(storedOutcome)
        let (goal, mission) = try p1dGoalAndMission(fixture)
        #expect(unchanged == fixture.delivered)
        #expect(goal.status == .active)
        #expect(mission.status == .delivering)
        let acceptanceCount = try fixture.domain.store.acceptanceCount(
            outcomeId: fixture.delivered.id
        )
        let metric = try fixture.domain.store.metricCredit(
            outcomeId: fixture.delivered.id
        )
        #expect(acceptanceCount == 0)
        #expect(metric == nil)
        try fixture.domain.base.database.pool.read { db in
            let count = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM domain_event WHERE commandIdempotencyKey='accept-failure'")
            #expect(count == 0)
        }
    }

    @Test func duplicateAcceptanceCountsOneCreditAndReplaysOneGraph() throws {
        let fixture = try p1dAcceptanceFixture("accept-replay")
        let command = try AcceptOutcomeCommandV1(
            envelope: p1dUserEnvelope("accept-replay", at: p1dEpoch.addingTimeInterval(1)),
            acceptanceId: p1dAcceptanceID,
            outcome: fixture.delivered.currentRef,
            expectedOutcomeAggregateVersion: fixture.delivered.aggregateVersion,
            subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
            reason: "User accepted"
        )
        let first = try fixture.domain.store.acceptOutcome(command)
        let replay = try fixture.domain.store.acceptOutcome(command)
        #expect(replay == first)
        let acceptanceCount = try fixture.domain.store.acceptanceCount(
            outcomeId: fixture.delivered.id
        )
        #expect(acceptanceCount == 1)
        try fixture.domain.base.database.pool.read { db in
            let metricCount = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM outcome_metric_credit WHERE outcomeId=?",
                arguments: [fixture.delivered.id])
            let eventCount = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM domain_event WHERE commandIdempotencyKey='accept-replay'")
            #expect(metricCount == 1)
            #expect(eventCount == 1)
        }
    }

    @Test func returnFromDeliveredOrAcceptedReopensGoalMissionAndReversesCredit() throws {
        let deliveredFixture = try p1dAcceptanceFixture("return-delivered")
        let deliveredReturn = try deliveredFixture.domain.store.returnOutcome(
            ReturnOutcomeCommandV1(
                envelope: p1dUserEnvelope("return-delivered", at: p1dEpoch.addingTimeInterval(2)),
                acceptanceId: p1dReturnID,
                outcome: deliveredFixture.delivered.currentRef,
                expectedOutcomeAggregateVersion: deliveredFixture.delivered.aggregateVersion,
                subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                reason: "Needs changes"
            )
        )
        #expect(deliveredReturn.outcome.state == .returned)
        #expect(deliveredReturn.metric == nil)
        let deliveredProjection = try p1dGoalAndMission(deliveredFixture)
        #expect(deliveredProjection.0.status == .active)
        #expect(deliveredProjection.1.status == .delivering)

        let acceptedFixture = try p1dAcceptanceFixture("return-accepted")
        let accepted = try p1dUserAcceptance(
            acceptedFixture,
            key: "return-accepted:accept"
        )
        let returned = try acceptedFixture.domain.store.returnOutcome(
            ReturnOutcomeCommandV1(
                envelope: p1dUserEnvelope("return-accepted:return", at: p1dEpoch.addingTimeInterval(2)),
                acceptanceId: p1dReturnID,
                outcome: accepted.outcome.currentRef,
                expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                reason: "Needs changes"
            )
        )
        let projection = try p1dGoalAndMission(acceptedFixture)
        #expect(returned.outcome.state == .returned)
        #expect(projection.0.status == .active)
        #expect(projection.1.status == .delivering)
        let returnedMetric = try acceptedFixture.domain.store.metricCredit(
            outcomeId: returned.outcome.id
        )
        #expect(returnedMetric?.state == .reversed)
    }

    @Test func revokeAcceptanceReopensGoalMissionAndReversesCredit() throws {
        let fixture = try p1dAcceptanceFixture("revoke")
        let accepted = try p1dUserAcceptance(fixture, key: "revoke:accept")
        let revoked = try fixture.domain.store.revokeAcceptance(
            RevokeAcceptanceCommandV1(
                envelope: p1dUserEnvelope("revoke:command", at: p1dEpoch.addingTimeInterval(2)),
                acceptanceId: p1dRevokeID,
                outcome: accepted.outcome.currentRef,
                expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                reason: "Acceptance withdrawn"
            )
        )
        let projection = try p1dGoalAndMission(fixture)
        #expect(revoked.outcome.state == .revoked)
        #expect(revoked.record.supersedesAcceptanceId == p1dAcceptanceID)
        #expect(projection.0.status == .active)
        #expect(projection.1.status == .delivering)
        let metric = try fixture.domain.store.metricCredit(
            outcomeId: revoked.outcome.id
        )
        #expect(metric?.state == .reversed)
    }

    @Test func invalidationReopensAcceptedAndReversesCredit() throws {
        let fixture = try p1dAcceptanceFixture("invalidate-accepted")
        let accepted = try p1dUserAcceptance(
            fixture,
            key: "invalidate-accepted:accept"
        )
        let invalidated = try fixture.domain.store.invalidateVerification(
            InvalidateVerificationCommandV1(
                envelope: p1dSystemEnvelope(
                    "invalidate-accepted:command",
                    actorId: P1DActorID.dependencyInvalidator,
                    at: p1dEpoch.addingTimeInterval(2)
                ),
                outcome: accepted.outcome.currentRef,
                expectedOutcomeAggregateVersion:
                    accepted.outcome.aggregateVersion,
                verificationIds: [fixture.verificationId],
                reasonCode: "dependency_changed",
                dependency: VerificationDependencyRefV1(
                    type: "artifact",
                    id: "artifact:changed",
                    version: nil,
                    hash: nil
                )
            )
        )
        let projection = try p1dGoalAndMission(fixture)
        #expect(invalidated.state == .invalidated)
        #expect(projection.0.status == .active)
        #expect(projection.1.status == .delivering)
        let metric = try fixture.domain.store.metricCredit(
            outcomeId: invalidated.id
        )
        #expect(metric?.state == .reversed)
    }

    @Test func newVersionReacceptRestoresSameCreditWithoutDuplicate() throws {
        let fixture = try p1dAcceptanceFixture("reaccept")
        let accepted = try p1dUserAcceptance(fixture, key: "reaccept:first")
        let returned = try fixture.domain.store.returnOutcome(
            ReturnOutcomeCommandV1(
                envelope: p1dUserEnvelope("reaccept:return", at: p1dEpoch.addingTimeInterval(2)),
                acceptanceId: p1dReturnID,
                outcome: accepted.outcome.currentRef,
                expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                reason: "Rework"
            )
        )
        let next = try fixture.domain.store.recordNewOutcomeVersion(
            RecordNewOutcomeVersionCommandV1(
                envelope: p1dCowEnvelope("reaccept:new-version", at: p1dEpoch.addingTimeInterval(3)),
                outcome: returned.outcome.currentRef,
                expectedAggregateVersion: returned.outcome.aggregateVersion,
                producerActorId: "cow:producer",
                runIds: ["run:2"],
                manifest: [try OutcomeArtifactRefV1(
                    kind: .externalReceipt,
                    locator: "receipt://reaccept-v2",
                    contentHash: String(repeating: "b", count: 64)
                )]
            )
        )
        _ = try p1dRecordVerification(
            fixture.domain,
            outcome: next,
            recordId: "81000000-0000-4000-8000-000000000002",
            key: "reaccept:verify-v2"
        )
        let verified = try p1dRequireOutcome(fixture.domain, id: next.id)
        let delivered = try fixture.domain.store.markDelivered(
            MarkDeliveredCommandV1(
                envelope: p1dSystemEnvelope(
                    "reaccept:deliver-v2",
                    actorId: P1DActorID.delivery,
                    at: p1dEpoch.addingTimeInterval(4)
                ),
                outcome: verified.currentRef,
                expectedAggregateVersion: verified.aggregateVersion
            )
        )
        let reaccepted = try fixture.domain.store.acceptOutcome(
            AcceptOutcomeCommandV1(
                envelope: p1dUserEnvelope("reaccept:second", at: p1dEpoch.addingTimeInterval(5)),
                acceptanceId: "90000000-0000-4000-8000-000000000004",
                outcome: delivered.currentRef,
                expectedOutcomeAggregateVersion: delivered.aggregateVersion,
                subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                reason: "Reaccepted"
            )
        )
        let storedMetric = try fixture.domain.store.metricCredit(
            outcomeId: next.id
        )
        let metric = try #require(storedMetric)
        #expect(reaccepted.outcome.currentVersion == 2)
        #expect(metric.state == .active)
        #expect(metric.creditedOutcomeVersion == 2)
        #expect(metric.version == 3)
        try fixture.domain.base.database.pool.read { db in
            let count = try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM outcome_metric_credit WHERE outcomeId=?",
                arguments: [next.id])
            #expect(count == 1)
        }
    }

    @Test func downstreamTransitionRollbackIsTotalForEverySection19Command() throws {
        for operation in ["return", "revoke", "invalidate"] {
            let fixture = try p1dAcceptanceFixture("rollback-\(operation)")
            let accepted = try p1dUserAcceptance(
                fixture,
                key: "rollback:\(operation):accept"
            )
            try fixture.domain.base.database.pool.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER p1d_fail_reopen BEFORE UPDATE ON goal_controller
                    WHEN OLD.status='achieved' AND NEW.status='active'
                    BEGIN SELECT RAISE(ABORT, 'injected reopen failure'); END
                    """)
            }
            switch operation {
            case "return":
                #expect(throws: (any Error).self) {
                    try fixture.domain.store.returnOutcome(
                        ReturnOutcomeCommandV1(
                            envelope: p1dUserEnvelope("rollback:return"),
                            acceptanceId: p1dReturnID,
                            outcome: accepted.outcome.currentRef,
                            expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                            subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                            reason: "rollback"
                        )
                    )
                }
            case "revoke":
                #expect(throws: (any Error).self) {
                    try fixture.domain.store.revokeAcceptance(
                        RevokeAcceptanceCommandV1(
                            envelope: p1dUserEnvelope("rollback:revoke"),
                            acceptanceId: p1dRevokeID,
                            outcome: accepted.outcome.currentRef,
                            expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                            subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                            reason: "rollback"
                        )
                    )
                }
            default:
                #expect(throws: (any Error).self) {
                    try fixture.domain.store.invalidateVerification(
                        InvalidateVerificationCommandV1(
                            envelope: p1dSystemEnvelope(
                                "rollback:invalidate",
                                actorId: P1DActorID.dependencyInvalidator
                            ),
                            outcome: accepted.outcome.currentRef,
                            expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                            verificationIds: [fixture.verificationId],
                            reasonCode: "dependency_changed",
                            dependency: VerificationDependencyRefV1(
                                type: "test", id: "rollback", version: nil, hash: nil
                            )
                        )
                    )
                }
            }
            let stored = try fixture.domain.store.outcome(
                id: accepted.outcome.id
            )
            let current = try #require(stored)
            let projection = try p1dGoalAndMission(fixture)
            #expect(current == accepted.outcome)
            #expect(projection.0.status == .achieved)
            #expect(projection.1.status == .accepted)
            let metric = try fixture.domain.store.metricCredit(
                outcomeId: current.id
            )
            #expect(metric?.state == .active)
        }

        let newVersion = try p1dAcceptanceFixture("rollback-new-version")
        let accepted = try p1dUserAcceptance(
            newVersion,
            key: "rollback:new:accept"
        )
        let returned = try newVersion.domain.store.returnOutcome(
            ReturnOutcomeCommandV1(
                envelope: p1dUserEnvelope("rollback:new:return"),
                acceptanceId: p1dReturnID,
                outcome: accepted.outcome.currentRef,
                expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
                subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
                reason: "rework"
            )
        )
        try newVersion.domain.base.database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER p1d_fail_new_version BEFORE INSERT ON outcome_version
                BEGIN SELECT RAISE(ABORT, 'injected version failure'); END
                """)
        }
        #expect(throws: (any Error).self) {
            try newVersion.domain.store.recordNewOutcomeVersion(
                RecordNewOutcomeVersionCommandV1(
                    envelope: p1dCowEnvelope("rollback:new:command"),
                    outcome: returned.outcome.currentRef,
                    expectedAggregateVersion: returned.outcome.aggregateVersion,
                    producerActorId: "cow:producer",
                    runIds: ["run:2"],
                    manifest: [try OutcomeArtifactRefV1(
                        kind: .externalReceipt,
                        locator: "receipt://rollback-v2",
                        contentHash: String(repeating: "b", count: 64)
                    )]
                )
            )
        }
        let versions = try newVersion.domain.store.outcomeVersions(
            id: returned.outcome.id
        )
        #expect(versions.count == 1)
    }

    @Test func legacyAcceptanceNeverCreatesOutcomeMetricAndKnowledgeTruthStaysUnknown() throws {
        let base = try p1dContractFixture(
            "legacy-truth",
            goalStatus: .ready,
            missionStatus: .delivering
        )
        let linked = try base.store.missionHasActiveContractLink(
            missionId: base.mission.id
        )
        #expect(linked == false)
        try base.database.pool.read { db in
            let outcomes = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM outcome"
            )
            let metrics = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM outcome_metric_credit"
            )
            let acceptances = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM acceptance_record"
            )
            #expect(outcomes == 0)
            #expect(metrics == 0)
            #expect(acceptances == 0)
        }
        let truth = LegacyReturnTruthV1()
        #expect(truth.usedKnowledge == .notConnected)
        #expect(truth.writtenBackKnowledge == .notConnected)
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let adapter = try String(contentsOf:
            repo.appendingPathComponent("Sources/AgentLoopApp/CodingRanchStoreAdapter.swift"),
            encoding: .utf8)
        #expect(adapter.contains("usedKnowledge: []"))
        #expect(adapter.contains("writtenBackNotes: []"))
    }

    @Test func artifactViewedIsExplicitSessionEventAndLiveHostNavigatesOnlyAfterCommit() throws {
        var session = ArtifactViewSessionV1()
        #expect(session.hasViewed(artifactId: "artifact:1") == false)
        try session.recordReveal(artifactId: "artifact:1")
        #expect(session.hasViewed(artifactId: "artifact:1"))

        let fixture = try p1dAcceptanceFixture("ui-order")
        let command = try AcceptOutcomeCommandV1(
            envelope: p1dUserEnvelope("ui-order", at: p1dEpoch.addingTimeInterval(1)),
            acceptanceId: p1dAcceptanceID,
            outcome: fixture.delivered.currentRef,
            expectedOutcomeAggregateVersion: fixture.delivered.aggregateVersion,
            subject: AcceptanceSubjectV1.user(P1DActorID.localOwner),
            reason: "UI acceptance"
        )
        let failed = AcceptanceWorkflowController(
            readOutcome: { _ in fixture.delivered },
            commit: { _ in throw P1DProjectionConflictError() }
        ).accept(command)
        #expect(failed.mayNavigate == false)
        let committed = AcceptanceWorkflowController
            .live(store: fixture.domain.store)
            .accept(command)
        #expect(committed.mayNavigate)

        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let host = try String(contentsOf:
            repo.appendingPathComponent(
                "Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift"
            ), encoding: .utf8)
        let adapter = try String(contentsOf:
            repo.appendingPathComponent(
                "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift"
            ), encoding: .utf8)
        #expect(host.contains("let committed = await store"))
        #expect(host.contains("if committed {\n                                    onAccepted()"))
        #expect(adapter.contains("hasViewedReturnArtifact(id: $0.id)"))
        #expect(!adapter.contains("let viewed = !snapshot.artifacts.isEmpty"))
    }
}
