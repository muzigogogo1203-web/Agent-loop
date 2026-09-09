import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

let p1dOutcomeID = "80000000-0000-4000-8000-000000000001"

struct P1DOutcomeFixture {
    let base: P1DContractFixture
    let contract: OutcomeContractSnapshotV1
    let goal: GoalControllerRecord
    let store: OutcomeStore
}

func p1dCowEnvelope(
    _ key: String,
    actorId: String = "cow:producer",
    at: Date = p1dEpoch
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .cow,
        actorId: actorId,
        deviceId: nil,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

func p1dVerificationEnvelope(
    _ key: String,
    actorType: DomainActorType = .system,
    actorId: String = "system:verifier:tests:v1",
    at: Date = p1dEpoch
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: actorType,
        actorId: actorId,
        deviceId: nil,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

func p1dManifest(
    path: String = "/tmp/p1d-artifact",
    hash: String = String(repeating: "a", count: 64)
) throws -> [OutcomeArtifactRefV1] {
    [try OutcomeArtifactRefV1(kind: .file, locator: path, contentHash: hash)]
}

func p1dOutcomeFixture(
    _ label: String,
    body: OutcomeContractBodyV1? = nil,
    missionStatus: MissionStatus = .executing
) throws -> P1DOutcomeFixture {
    let base = try p1dContractFixture(
        label,
        goalStatus: .ready,
        missionStatus: missionStatus
    )
    let draft = try p1dCreateDraft(base, body: body)
    let contract = try p1dActivateContract(base, draft: draft)
    let activated = try base.store.activateGoal(
        ActivateGoalCommandV1(
            envelope: p1dUserEnvelope("p1d:\(label):activate-goal"),
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
    return P1DOutcomeFixture(
        base: base,
        contract: contract,
        goal: activated.goal,
        store: base.store
    )
}

func p1dRecordInitial(
    _ fixture: P1DOutcomeFixture,
    outcomeId: String = p1dOutcomeID,
    key: String = "p1d:initial-outcome:1",
    producer: String = "cow:producer",
    manifest: [OutcomeArtifactRefV1]? = nil
) throws -> OutcomeSnapshotV1 {
    try fixture.store.recordInitialOutcome(
        RecordInitialOutcomeCommandV1(
            envelope: p1dCowEnvelope(key, actorId: producer),
            outcomeId: outcomeId,
            goal: GoalHeadV1(
                goalId: fixture.goal.id,
                campId: fixture.goal.campId,
                expectedGoalVersion: fixture.goal.aggregateVersion
            ),
            contract: fixture.contract.ref,
            missionId: fixture.base.mission.id,
            producerActorId: producer,
            runIds: ["run:1"],
            manifest: manifest ?? p1dManifest()
        )
    )
}

func p1dBeginVerification(
    _ fixture: P1DOutcomeFixture,
    outcome: OutcomeSnapshotV1,
    key: String = "p1d:begin-verification:1"
) throws -> OutcomeSnapshotV1 {
    try fixture.store.beginVerification(
        BeginVerificationCommandV1(
            envelope: p1dSystemEnvelope(
                key,
                actorId: P1DActorID.verification
            ),
            outcome: outcome.currentRef,
            expectedAggregateVersion: outcome.aggregateVersion
        )
    )
}

func p1dRequirementRef(
    _ fixture: P1DOutcomeFixture,
    id: String = "requirement-tests"
) throws -> VerificationRequirementRefV1 {
    let requirement = try #require(
        fixture.contract.body.verificationGroups
            .flatMap(\.requirements)
            .first(where: { $0.requirementId == id })
    )
    return try VerificationRequirementRefV1(
        contract: fixture.contract.ref,
        requirementId: requirement.requirementId,
        requirementVersion: requirement.requirementVersion,
        requirementHash: requirement.requirementHash
    )
}

func p1dRecordVerification(
    _ fixture: P1DOutcomeFixture,
    outcome: OutcomeSnapshotV1,
    requirementId: String = "requirement-tests",
    recordId: String = "81000000-0000-4000-8000-000000000001",
    key: String = "p1d:verification:1",
    result: VerificationResultV1 = .passed,
    expectedHead: String? = nil,
    actorType: DomainActorType = .system,
    actorId: String = "system:verifier:tests:v1"
) throws -> VerificationRecordSnapshotV1 {
    try fixture.store.recordVerification(
        RecordVerificationCommandV1(
            envelope: p1dVerificationEnvelope(
                key,
                actorType: actorType,
                actorId: actorId
            ),
            verificationId: recordId,
            requirement: p1dRequirementRef(fixture, id: requirementId),
            outcome: outcome.currentRef,
            expectedOutcomeAggregateVersion: outcome.aggregateVersion,
            expectedCurrentVerificationId: expectedHead,
            environment: ["platform": .string("macos")],
            commandOrRule: ["command": .string("swift run RunTests")],
            rawResultRef: "evidence://\(recordId)",
            result: result
        )
    )
}

func p1dSetOutcomeState(
    _ fixture: P1DOutcomeFixture,
    outcome: OutcomeSnapshotV1,
    state: OutcomeStateV1
) throws -> OutcomeSnapshotV1 {
    try fixture.base.database.pool.write { db in
        try db.execute(
            sql: "UPDATE outcome SET state=? WHERE id=?",
            arguments: [state.rawValue, outcome.id]
        )
    }
    return try p1dRequireOutcome(fixture, id: outcome.id)
}

func p1dRequireOutcome(
    _ fixture: P1DOutcomeFixture,
    id: String
) throws -> OutcomeSnapshotV1 {
    let stored = try fixture.store.outcome(id: id)
    return try #require(stored)
}

private func p1dTwoRequirementBody(
    firstMode: VerificationRequirementGroupModeV1 = .all,
    dependencyId: String? = nil
) throws -> OutcomeContractBodyV1 {
    try p1dBody(
        groups: [
            VerificationRequirementGroupV1(
                groupId: "primary",
                mode: firstMode,
                requirements: [
                    p1dRequirement(id: "requirement-tests"),
                    p1dRequirement(
                        id: "requirement-build",
                        verifierType: .deterministic,
                        method: .build
                    ),
                ]
            ),
        ],
        requiredDependencies: dependencyId.map { [$0] } ?? []
    )
}

private struct StubProcessRunner: P1DProcessRunner {
    let result: P1DProcessResultV1

    func run(_ request: P1DProcessRequestV1) async throws -> P1DProcessResultV1 {
        result
    }
}

@Suite(.serialized)
struct P1DOutcomeVerificationTests {
    @Test func initialOutcomeCreatesOnlyV1FromLinkedExecutingOrDeliveringMission() throws {
        for (index, state) in [MissionStatus.executing, .delivering].enumerated() {
            let fixture = try p1dOutcomeFixture("initial-\(state.rawValue)", missionStatus: state)
            let id = String(format: "80000000-0000-4000-8000-%012d", index + 1)
            let first = try p1dRecordInitial(fixture, outcomeId: id, key: "initial:\(state.rawValue)")
            let replay = try p1dRecordInitial(fixture, outcomeId: id, key: "initial:\(state.rawValue)")
            #expect(first == replay)
            #expect(first.currentVersion == 1)
            #expect(first.state == .produced)
            let versions = try fixture.store.outcomeVersions(id: id)
            #expect(versions.count == 1)
        }
        for state in [MissionStatus.planning, .accepted, .failed] {
            let fixture = try p1dOutcomeFixture("initial-bad-\(state.rawValue)")
            try fixture.base.database.pool.write { db in
                try db.execute(
                    sql: "UPDATE mission SET status=? WHERE id=?",
                    arguments: [state.rawValue, fixture.base.mission.id]
                )
            }
            #expect(throws: InvalidInitialOutcomeError.self) {
                _ = try p1dRecordInitial(fixture, key: "bad:\(state.rawValue)")
            }
        }
    }

    @Test func newOutcomeVersionAcceptsOnlyFiveFrozenSourcesAndIncrementsOnce() throws {
        let allowed: [OutcomeStateV1] = [
            .returned, .revoked, .invalidated, .verificationFailed, .blocked,
        ]
        for (index, source) in allowed.enumerated() {
            let fixture = try p1dOutcomeFixture("new-version-\(source.rawValue)")
            var outcome = try p1dRecordInitial(fixture)
            outcome = try p1dSetOutcomeState(fixture, outcome: outcome, state: source)
            let updated = try fixture.store.recordNewOutcomeVersion(
                RecordNewOutcomeVersionCommandV1(
                    envelope: p1dCowEnvelope("new-version:\(source.rawValue)"),
                    outcome: outcome.currentRef,
                    expectedAggregateVersion: outcome.aggregateVersion,
                    producerActorId: "cow:producer",
                    runIds: ["run:\(index + 2)"],
                    manifest: p1dManifest(path: "/tmp/new-\(index)")
                )
            )
            #expect(updated.currentVersion == 2)
            #expect(updated.state == .verificationPending)
            let versions = try fixture.store.outcomeVersions(id: outcome.id)
            #expect(versions.count == 2)
        }
        for source in OutcomeStateV1.allCases where !allowed.contains(source) {
            let fixture = try p1dOutcomeFixture("new-version-bad-\(source.rawValue)")
            var outcome = try p1dRecordInitial(fixture)
            outcome = try p1dSetOutcomeState(fixture, outcome: outcome, state: source)
            #expect(throws: InvalidOutcomeTransitionError.self) {
                _ = try fixture.store.recordNewOutcomeVersion(
                    RecordNewOutcomeVersionCommandV1(
                        envelope: p1dCowEnvelope("new-bad:\(source.rawValue)"),
                        outcome: outcome.currentRef,
                        expectedAggregateVersion: outcome.aggregateVersion,
                        producerActorId: "cow:producer",
                        runIds: ["run:bad"],
                        manifest: p1dManifest()
                    )
                )
            }
        }
    }

    @Test func initialAndSubsequentOutcomeKeysCannotAlias() throws {
        let fixture = try p1dOutcomeFixture("key-space")
        var outcome = try p1dRecordInitial(fixture, key: "same-key")
        outcome = try p1dSetOutcomeState(fixture, outcome: outcome, state: .returned)
        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try fixture.store.recordNewOutcomeVersion(
                RecordNewOutcomeVersionCommandV1(
                    envelope: p1dCowEnvelope("same-key"),
                    outcome: outcome.currentRef,
                    expectedAggregateVersion: outcome.aggregateVersion,
                    producerActorId: "cow:producer",
                    runIds: ["run:2"],
                    manifest: p1dManifest()
                )
            )
        }
    }

    @Test func everyOutcomeTransitionPairMatchesCanonicalStateTable() {
        let expected: Set<OutcomeTransitionEdgeV1> = [
            .init(command: .beginVerification, from: .produced, to: .verificationPending),
            .init(command: .beginVerification, from: .verificationFailed, to: .verificationPending),
            .init(command: .beginVerification, from: .blocked, to: .verificationPending),
            .init(command: .reduceVerification, from: .verificationPending, to: .verificationPending),
            .init(command: .reduceVerification, from: .verificationPending, to: .verified),
            .init(command: .reduceVerification, from: .verificationPending, to: .verificationFailed),
            .init(command: .reduceVerification, from: .verificationPending, to: .blocked),
            .init(command: .reduceVerification, from: .verificationFailed, to: .verificationPending),
            .init(command: .reduceVerification, from: .verificationFailed, to: .verified),
            .init(command: .reduceVerification, from: .verificationFailed, to: .verificationFailed),
            .init(command: .reduceVerification, from: .verificationFailed, to: .blocked),
            .init(command: .reduceVerification, from: .blocked, to: .verificationPending),
            .init(command: .reduceVerification, from: .blocked, to: .verified),
            .init(command: .reduceVerification, from: .blocked, to: .verificationFailed),
            .init(command: .reduceVerification, from: .blocked, to: .blocked),
            .init(command: .markDelivered, from: .verified, to: .delivered),
            .init(command: .acceptOutcome, from: .delivered, to: .accepted),
            .init(command: .returnOutcome, from: .delivered, to: .returned),
            .init(command: .returnOutcome, from: .accepted, to: .returned),
            .init(command: .revokeAcceptance, from: .accepted, to: .revoked),
            .init(command: .invalidateVerification, from: .verificationPending, to: .verificationPending),
            .init(command: .invalidateVerification, from: .verificationFailed, to: .verificationPending),
            .init(command: .invalidateVerification, from: .blocked, to: .verificationPending),
            .init(command: .invalidateVerification, from: .verified, to: .verificationPending),
            .init(command: .invalidateVerification, from: .delivered, to: .verificationPending),
            .init(command: .invalidateVerification, from: .accepted, to: .invalidated),
            .init(command: .recordNewOutcomeVersion, from: .returned, to: .verificationPending),
            .init(command: .recordNewOutcomeVersion, from: .revoked, to: .verificationPending),
            .init(command: .recordNewOutcomeVersion, from: .invalidated, to: .verificationPending),
            .init(command: .recordNewOutcomeVersion, from: .verificationFailed, to: .verificationPending),
            .init(command: .recordNewOutcomeVersion, from: .blocked, to: .verificationPending),
        ]
        for command in OutcomeTransitionCommandV1.allCases {
            for from in OutcomeStateV1.allCases {
                for to in OutcomeStateV1.allCases {
                    let edge = OutcomeTransitionEdgeV1(command: command, from: from, to: to)
                    #expect(OutcomeTransitionPolicyV1.allows(edge) == expected.contains(edge))
                }
            }
        }
    }

    @Test func outcomeManifestOrContractDriftRequiresNewVersionAndInvalidatesOldHeads() throws {
        let fixture = try p1dOutcomeFixture("drift")
        var outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        _ = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        outcome = try p1dSetOutcomeState(fixture, outcome: outcome, state: .returned)
        let changed = try fixture.store.recordNewOutcomeVersion(
            RecordNewOutcomeVersionCommandV1(
                envelope: p1dCowEnvelope("drift:new"),
                outcome: outcome.currentRef,
                expectedAggregateVersion: outcome.aggregateVersion,
                producerActorId: "cow:producer",
                runIds: ["run:2"],
                manifest: p1dManifest(path: "/tmp/changed")
            )
        )
        #expect(changed.currentVersion == 2)
        let invalidationCount = try fixture.store.invalidationCount(
            outcomeId: outcome.id,
            version: 1
        )
        #expect(invalidationCount == 1)
        let versions = try fixture.store.outcomeVersions(id: outcome.id)
        #expect(versions[0].manifest != versions[1].manifest)
    }

    @Test func recordVerificationRequiresExactContractRequirementOutcomeHashes() throws {
        let fixture = try p1dOutcomeFixture("verification-hashes")
        let outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        let good = try p1dRequirementRef(fixture)
        let badRefs = [
            try VerificationRequirementRefV1(
                contract: OutcomeContractRef(id: good.contract.id, version: good.contract.version, hash: String(repeating: "0", count: 64)),
                requirementId: good.requirementId,
                requirementVersion: good.requirementVersion,
                requirementHash: good.requirementHash
            ),
            try VerificationRequirementRefV1(
                contract: good.contract,
                requirementId: good.requirementId,
                requirementVersion: good.requirementVersion,
                requirementHash: String(repeating: "0", count: 64)
            ),
        ]
        for (index, reference) in badRefs.enumerated() {
            #expect(throws: VerificationReferenceMismatchError.self) {
                _ = try fixture.store.recordVerification(
                    RecordVerificationCommandV1(
                        envelope: p1dVerificationEnvelope("bad-ref:\(index)"),
                        verificationId: String(format: "81000000-0000-4000-8000-%012d", index + 20),
                        requirement: reference,
                        outcome: outcome.currentRef,
                        expectedOutcomeAggregateVersion: outcome.aggregateVersion,
                        expectedCurrentVerificationId: nil,
                        environment: [:], commandOrRule: [:], rawResultRef: nil,
                        result: .passed
                    )
                )
            }
        }
        let badOutcome = try OutcomeRefV1(
            id: outcome.id,
            version: outcome.currentVersion,
            hash: String(repeating: "0", count: 64)
        )
        #expect(throws: VerificationReferenceMismatchError.self) {
            _ = try fixture.store.recordVerification(
                RecordVerificationCommandV1(
                    envelope: p1dVerificationEnvelope("bad-outcome"),
                    verificationId: "81000000-0000-4000-8000-000000000099",
                    requirement: good,
                    outcome: badOutcome,
                    expectedOutcomeAggregateVersion: outcome.aggregateVersion,
                    expectedCurrentVerificationId: nil,
                    environment: [:], commandOrRule: [:], rawResultRef: nil,
                    result: .passed
                )
            )
        }
    }

    @Test func duplicateVerificationReplaysAndSupersedeCASRejectsStaleHead() throws {
        let fixture = try p1dOutcomeFixture("verification-cas")
        let outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        let first = try p1dRecordVerification(
            fixture,
            outcome: outcome,
            result: .failed
        )
        let replay = try p1dRecordVerification(
            fixture,
            outcome: outcome,
            result: .failed
        )
        #expect(first == replay)
        let current = try p1dRequireOutcome(fixture, id: outcome.id)
        let second = try p1dRecordVerification(
            fixture,
            outcome: current,
            recordId: "81000000-0000-4000-8000-000000000002",
            key: "p1d:verification:2",
            expectedHead: first.id
        )
        let latest = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(throws: VerificationHeadConflictError.self) {
            _ = try p1dRecordVerification(
                fixture,
                outcome: latest,
                recordId: "81000000-0000-4000-8000-000000000003",
                key: "p1d:verification:3",
                expectedHead: first.id
            )
        }
        #expect(second.supersedesVerificationId == first.id)
    }

    @Test func allGroupRequiresEveryCurrentPass() throws {
        let fixture = try p1dOutcomeFixture("all-group", body: p1dTwoRequirementBody())
        var outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        _ = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(outcome.state == .verificationPending)
        _ = try p1dRecordVerification(
            fixture,
            outcome: outcome,
            requirementId: "requirement-build",
            recordId: "81000000-0000-4000-8000-000000000004",
            key: "p1d:verification:build",
            actorId: "system:verifier:tests:v1"
        )
        let finalOutcome = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(finalOutcome.state == .verified)
    }

    @Test func anyGroupAllowsOneAlternativeButEveryGroupRemainsRequired() throws {
        let body = try p1dBody(groups: [
            VerificationRequirementGroupV1(
                groupId: "alternatives", mode: .any,
                requirements: [
                    p1dRequirement(id: "requirement-tests"),
                    p1dRequirement(id: "requirement-build", method: .build),
                ]
            ),
            VerificationRequirementGroupV1(
                groupId: "required", mode: .all,
                requirements: [p1dRequirement(id: "requirement-hash", method: .artifactHash)]
            ),
        ])
        let fixture = try p1dOutcomeFixture("any-group", body: body)
        var outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        _ = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(outcome.state == .verificationPending)
        _ = try p1dRecordVerification(
            fixture, outcome: outcome, requirementId: "requirement-hash",
            recordId: "81000000-0000-4000-8000-000000000005",
            key: "p1d:verification:hash"
        )
        let finalOutcome = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(finalOutcome.state == .verified)
    }

    @Test func failedBlockedMissingAndInvalidHeadsReduceExactly() throws {
        let expected: [(VerificationResultV1?, OutcomeStateV1)] = [
            (nil, .verificationPending),
            (.failed, .verificationFailed),
            (.blocked, .blocked),
            (.invalid, .verificationPending),
        ]
        for (index, pair) in expected.enumerated() {
            let fixture = try p1dOutcomeFixture("reduce-\(index)")
            let outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
            if let result = pair.0 {
                _ = try p1dRecordVerification(
                    fixture, outcome: outcome,
                    recordId: String(format: "81000000-0000-4000-8000-%012d", index + 30),
                    key: "reduce:\(index)", result: result
                )
            }
            let reduced = try p1dRequireOutcome(fixture, id: outcome.id)
            #expect(reduced.state == pair.1)
        }
    }

    @Test func currentInvalidationReopensVerifiedDeliveredAndAcceptedExactly() throws {
        let expected: [(OutcomeStateV1, OutcomeStateV1)] = [
            (.verified, .verificationPending),
            (.delivered, .verificationPending),
            (.accepted, .invalidated),
        ]
        for (index, pair) in expected.enumerated() {
            let fixture = try p1dOutcomeFixture("invalidate-\(index)")
            var outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
            let verification = try p1dRecordVerification(fixture, outcome: outcome)
            outcome = try p1dRequireOutcome(fixture, id: outcome.id)
            outcome = try p1dSetOutcomeState(fixture, outcome: outcome, state: pair.0)
            if pair.0 == .accepted {
                let acceptanceId = "90000000-0000-4000-8000-000000000099"
                try fixture.base.database.pool.write { db in
                    try db.execute(
                        sql: """
                            UPDATE goal_controller SET status='achieved'
                            WHERE id=?
                            """,
                        arguments: [outcome.goalId]
                    )
                    try db.execute(
                        sql: "UPDATE mission SET status='accepted' WHERE id=?",
                        arguments: [outcome.missionId]
                    )
                    try db.execute(
                        sql: """
                            INSERT INTO acceptance_record(
                              id,commandIdempotencyKey,contractId,
                              contractVersion,contractHash,outcomeId,
                              outcomeVersion,outcomeHash,subjectType,subjectId,
                              policyId,policyVersion,decision,reason,
                              supersedesAcceptanceId,createdAt,redactedAt
                            ) VALUES (?,?,?,?,?,?,?,?,? ,?,NULL,NULL,
                                      'accepted','fixture',NULL,?,NULL)
                            """,
                        arguments: [
                            acceptanceId, "fixture:accepted:\(index)",
                            outcome.contract.id, outcome.contract.version,
                            outcome.contract.hash, outcome.id,
                            outcome.currentVersion, outcome.currentRef.hash,
                            "user", P1DActorID.localOwner, p1dEpoch,
                        ]
                    )
                    try db.execute(
                        sql: """
                            INSERT INTO outcome_metric_credit(
                              outcomeId,state,creditedOutcomeVersion,
                              acceptanceId,reversedByEventId,version,
                              creditedAt,reversedAt
                            ) VALUES (?,'active',?,?,NULL,1,?,NULL)
                            """,
                        arguments: [
                            outcome.id, outcome.currentVersion,
                            acceptanceId, p1dEpoch,
                        ]
                    )
                }
            }
            _ = try fixture.store.invalidateVerification(
                InvalidateVerificationCommandV1(
                    envelope: p1dSystemEnvelope("invalidate:\(index)", actorId: P1DActorID.dependencyInvalidator),
                    outcome: outcome.currentRef,
                    expectedOutcomeAggregateVersion: outcome.aggregateVersion,
                    verificationIds: [verification.id],
                    reasonCode: "dependency_changed",
                    dependency: VerificationDependencyRefV1(type: "file", id: "artifact", version: 1, hash: String(repeating: "b", count: 64))
                )
            )
            let invalidated = try p1dRequireOutcome(fixture, id: outcome.id)
            #expect(invalidated.state == pair.1)
        }
    }

    @Test func cowVerifierCannotEqualProducerAndModelOnlyCodingNeverPasses() throws {
        let body = try p1dBody(groups: [
            VerificationRequirementGroupV1(
                groupId: "mixed", mode: .any,
                requirements: [
                    p1dRequirement(id: "requirement-tests"),
                    VerificationRequirementV1(
                        requirementId: "requirement-model-producer",
                        requirementVersion: 1,
                        verifierType: .cow,
                        verifierId: "cow:producer",
                        method: .modelSupplement,
                        ruleId: "rule:model-producer",
                        ruleVersion: 1,
                        config: [:]
                    ),
                    VerificationRequirementV1(
                        requirementId: "requirement-model-reviewer",
                        requirementVersion: 1,
                        verifierType: .cow,
                        verifierId: "cow:reviewer:v1",
                        method: .modelSupplement,
                        ruleId: "rule:model-reviewer",
                        ruleVersion: 1,
                        config: [:]
                    ),
                ]
            ),
        ])
        let fixture = try p1dOutcomeFixture("independence", body: body)
        let outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        #expect(throws: VerificationProducerConflictError.self) {
            _ = try p1dRecordVerification(
                fixture, outcome: outcome,
                requirementId: "requirement-model-producer",
                key: "producer-conflict", actorType: .cow, actorId: "cow:producer"
            )
        }
        _ = try p1dRecordVerification(
            fixture, outcome: outcome,
            requirementId: "requirement-model-reviewer",
            key: "model-only", actorType: .cow, actorId: "cow:reviewer:v1"
        )
        let reduced = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(reduced.state == .verificationPending)
    }

    @Test func commandExitVerifierPassesOnlyZeroExitWithCompleteEvidence() async throws {
        let verifier = CommandExitVerifier(
            runner: StubProcessRunner(result: P1DProcessResultV1(exitCode: 0, stdout: "ok", stderr: "", timedOut: false))
        )
        let result = try await verifier.verify(
            P1DCommandVerificationRequestV1(
                command: ["swift", "run", "RunTests"],
                environment: ["PATH": "/usr/bin"], timeoutSeconds: 30,
                ruleVersion: 1
            )
        )
        #expect(result.result == .passed)
        #expect(result.evidenceHash.count == 64)
    }

    @Test func commandExitVerifierTimeoutNonzeroMissingEnvironmentAndParseFailClosed() async throws {
        let cases = [
            P1DProcessResultV1(exitCode: 0, stdout: "ok", stderr: "", timedOut: true),
            P1DProcessResultV1(exitCode: 2, stdout: "", stderr: "bad", timedOut: false),
            P1DProcessResultV1(exitCode: nil, stdout: "", stderr: "", timedOut: false),
        ]
        for value in cases {
            let verifier = CommandExitVerifier(runner: StubProcessRunner(result: value))
            let result = try await verifier.verify(
                P1DCommandVerificationRequestV1(
                    command: ["tool"], environment: ["PATH": "/usr/bin"],
                    timeoutSeconds: 1, ruleVersion: 1
                )
            )
            #expect(result.result != .passed)
        }
        let verifier = CommandExitVerifier(runner: StubProcessRunner(result: cases[0]))
        await #expect(throws: DeterministicVerificationInputError.self) {
            _ = try await verifier.verify(
                P1DCommandVerificationRequestV1(
                    command: ["tool"], environment: [:], timeoutSeconds: 1,
                    ruleVersion: 1
                )
            )
        }
    }

    @Test func artifactHashVerifierRejectsMissingUnreadableSymlinkAndHashDrift() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("p1d-artifact-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("artifact.txt")
        try Data("expected".utf8).write(to: file)
        let expectedHash = CanonicalJSONV1.sha256Hex(Data("expected".utf8))
        let verifier = ArtifactHashVerifier()
        #expect(try verifier.verify(path: file.path, expectedHash: expectedHash).result == .passed)
        let missing = root.appendingPathComponent("missing").path
        #expect(try verifier.verify(path: missing, expectedHash: expectedHash).result != .passed)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        #expect(try verifier.verify(path: link.path, expectedHash: expectedHash).result != .passed)
        #expect(try verifier.verify(path: file.path, expectedHash: String(repeating: "0", count: 64)).result != .passed)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
        #expect(try verifier.verify(path: file.path, expectedHash: expectedHash).result != .passed)
    }

    @Test func deterministicVerifiersExposeNoWorkspaceWriteCapability() {
        #expect(CommandExitVerifier<StubProcessRunner>.capabilities == [.runProcess])
        #expect(ArtifactHashVerifier.capabilities == [.readArtifact])
        #expect(!CommandExitVerifier<StubProcessRunner>.capabilities.contains(.workspaceWrite))
        #expect(!ArtifactHashVerifier.capabilities.contains(.workspaceWrite))
    }

    @Test func deliveryOnlySystemDeliveryV1CanMarkDelivered() throws {
        let fixture = try p1dOutcomeFixture("delivery-actor")
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("p1d-delivery-actor-\(UUID().uuidString)")
        let bytes = Data("deliver".utf8)
        try bytes.write(to: path)
        var outcome = try p1dBeginVerification(
            fixture,
            outcome: p1dRecordInitial(
                fixture,
                manifest: p1dManifest(
                    path: path.path,
                    hash: CanonicalJSONV1.sha256Hex(bytes)
                )
            )
        )
        _ = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        for envelope in [
            try p1dUserEnvelope("delivery:user"),
            try p1dCowEnvelope("delivery:cow"),
            try p1dSystemEnvelope("delivery:wrong", actorId: "system:wrong"),
        ] {
            #expect(throws: P1DCommandAuthorizationError.self) {
                _ = try fixture.store.markDelivered(
                    MarkDeliveredCommandV1(envelope: envelope, outcome: outcome.currentRef, expectedAggregateVersion: outcome.aggregateVersion)
                )
            }
        }
        let delivered = try fixture.store.markDelivered(
            MarkDeliveredCommandV1(
                envelope: p1dSystemEnvelope("delivery:good", actorId: P1DActorID.delivery),
                outcome: outcome.currentRef,
                expectedAggregateVersion: outcome.aggregateVersion
            )
        )
        #expect(delivered.state == .delivered)
    }

    @Test func deliveryRerunsReducerAndManifestReadabilityInSameTransaction() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("p1d-delivery-\(UUID().uuidString)")
        try Data("artifact".utf8).write(to: root)
        let hash = CanonicalJSONV1.sha256Hex(Data("artifact".utf8))
        let fixture = try p1dOutcomeFixture("delivery-read")
        var outcome = try p1dBeginVerification(
            fixture,
            outcome: p1dRecordInitial(fixture, manifest: p1dManifest(path: root.path, hash: hash))
        )
        _ = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        try FileManager.default.removeItem(at: root)
        #expect(throws: OutcomeDeliveryError.self) {
            _ = try fixture.store.markDelivered(
                MarkDeliveredCommandV1(
                    envelope: p1dSystemEnvelope("delivery:missing", actorId: P1DActorID.delivery),
                    outcome: outcome.currentRef,
                    expectedAggregateVersion: outcome.aggregateVersion
                )
            )
        }
        let unchanged = try p1dRequireOutcome(fixture, id: outcome.id)
        #expect(unchanged.state == .verified)
    }

    @Test func recordNewVersionAppendsSupersededInvalidationsForEveryOldHead() throws {
        let fixture = try p1dOutcomeFixture("supersede-heads", body: p1dTwoRequirementBody())
        var outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        _ = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        _ = try p1dRecordVerification(
            fixture, outcome: outcome, requirementId: "requirement-build",
            recordId: "81000000-0000-4000-8000-000000000006",
            key: "supersede:build"
        )
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        outcome = try p1dSetOutcomeState(fixture, outcome: outcome, state: .returned)
        _ = try fixture.store.recordNewOutcomeVersion(
            RecordNewOutcomeVersionCommandV1(
                envelope: p1dCowEnvelope("supersede:new"), outcome: outcome.currentRef,
                expectedAggregateVersion: outcome.aggregateVersion,
                producerActorId: "cow:producer", runIds: ["run:2"], manifest: p1dManifest()
            )
        )
        let invalidationCount = try fixture.store.invalidationCount(
            outcomeId: outcome.id,
            version: 1
        )
        #expect(invalidationCount == 2)
        let invalidHeads = try fixture.base.database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM verification_result_head
                    WHERE outcomeId=? AND outcomeVersion=1
                      AND derivedResult='invalid'
                    """,
                arguments: [outcome.id]
            ) ?? 0
        }
        #expect(invalidHeads == 2)
    }

    @Test func dependencyInvalidationWritesOneEventAndAllAffectedRowsAtomically() throws {
        let fixture = try p1dOutcomeFixture(
            "invalidate-atomic",
            body: p1dTwoRequirementBody(dependencyId: "shared")
        )
        var outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        let first = try p1dRecordVerification(fixture, outcome: outcome)
        outcome = try p1dRequireOutcome(fixture, id: outcome.id)
        let second = try p1dRecordVerification(
            fixture, outcome: outcome, requirementId: "requirement-build",
            recordId: "81000000-0000-4000-8000-000000000007",
            key: "atomic:build"
        )
        try fixture.base.database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER p1d_abort_second_invalidation
                BEFORE INSERT ON verification_invalidation
                WHEN NEW.verificationId='\(second.id)'
                BEGIN SELECT RAISE(ABORT,'injected'); END
                """)
        }
        let dependency = try VerificationDependencyRefV1(
            type: "file",
            id: "shared",
            version: 1,
            hash: String(repeating: "c", count: 64)
        )
        let command = try DeleteOrInvalidateDependencyCommandV1(
            envelope: p1dSystemEnvelope(
                "atomic:invalidate",
                actorId: P1DActorID.dependencyInvalidator
            ),
            campId: fixture.base.camp.id,
            reasonCode: "dependency_changed",
            dependency: dependency
        )
        #expect(throws: (any Error).self) {
            _ = try fixture.store.deleteOrInvalidateDependency(command)
        }
        let invalidationCount = try fixture.store.invalidationCount(
            outcomeId: outcome.id,
            version: 1
        )
        #expect(invalidationCount == 0)
        let eventCount = try fixture.base.database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM domain_event WHERE commandIdempotencyKey='atomic:invalidate'") ?? 0
        }
        #expect(eventCount == 0)
        try fixture.base.database.pool.write { db in
            try db.execute(sql: "DROP TRIGGER p1d_abort_second_invalidation")
        }
        let committed = try fixture.store.deleteOrInvalidateDependency(command)
        #expect(committed.verificationIds == [first.id, second.id].sorted())
        #expect(committed.outcomes.map(\.id) == [outcome.id])
        #expect(committed.outcomes.first?.state == .verificationPending)
        #expect(try fixture.store.invalidationCount(
            outcomeId: outcome.id,
            version: 1
        ) == 2)
        let committedEvents = try fixture.base.database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM domain_event
                    WHERE commandIdempotencyKey='atomic:invalidate'
                      AND eventType='dependency.verification-invalidated.v1'
                    """
            ) ?? 0
        }
        #expect(committedEvents == 1)
    }

    @Test func verificationReceiptEventAndOutboxReplayGraphDetectsTampering() throws {
        let fixture = try p1dOutcomeFixture("graph")
        let outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        let record = try p1dRecordVerification(fixture, outcome: outcome)
        try fixture.base.database.pool.write { db in
            try db.execute(sql: """
                DELETE FROM event_outbox WHERE eventId IN (
                  SELECT id FROM domain_event WHERE commandIdempotencyKey='p1d:verification:1'
                )
                """)
        }
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try p1dRecordVerification(fixture, outcome: outcome)
        }
        #expect(record.id == "81000000-0000-4000-8000-000000000001")
    }

    @Test func concurrentVerificationHeadsHaveOneCASWinner() async throws {
        let fixture = try p1dOutcomeFixture("concurrent-head")
        let outcome = try p1dBeginVerification(fixture, outcome: p1dRecordInitial(fixture))
        let commands = try (0..<2).map { index in
            try RecordVerificationCommandV1(
                envelope: p1dVerificationEnvelope("concurrent:\(index)"),
                verificationId: String(format: "81000000-0000-4000-8000-%012d", index + 80),
                requirement: p1dRequirementRef(fixture), outcome: outcome.currentRef,
                expectedOutcomeAggregateVersion: outcome.aggregateVersion,
                expectedCurrentVerificationId: nil,
                environment: ["platform": .string("macos")], commandOrRule: [:],
                rawResultRef: nil, result: .passed
            )
        }
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for command in commands {
                group.addTask {
                    do {
                        _ = try fixture.store.recordVerification(command)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var count = 0
            for await success in group where success { count += 1 }
            return count
        }
        #expect(successes == 1)
    }
}
