import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

private let p1eHashA = String(repeating: "a", count: 64)
private let p1eHashB = String(repeating: "b", count: 64)
private let p1eHashC = String(repeating: "c", count: 64)
let p1eHashD = String(repeating: "d", count: 64)
private let p1eAcceptanceID = "90000000-0000-4000-8000-000000000001"
let p1eReturnID = "90000000-0000-4000-8000-000000000002"
private let p1eVerificationID = "81000000-0000-4000-8000-000000000001"

struct P1EAcceptedOutcomeFixture {
    let domain: P1DOutcomeFixture
    let delivered: OutcomeSnapshotV1
    let verificationID: String
}

private func p1eGlobalWorkingDraft(
    id: String,
    title: String
) throws -> MemoryRecordDraftV1 {
    try MemoryRecordDraftV1(
        id: id,
        layer: .working,
        ownerType: .user,
        ownerId: "user:local-owner",
        campId: nil,
        title: title,
        bodyText: "body:\(id)",
        contentRef: nil,
        sourceType: .inference,
        applicabilityJson: "{}",
        createdByActorId: "system:memory:test",
        confirmedByActorId: nil
    )
}

func p1eAcceptedOutcomeFixture(
    _ label: String
) throws -> P1EAcceptedOutcomeFixture {
    let base = try p1dOutcomeFixture(label, missionStatus: .delivering)
    let initial = try p1dRecordInitial(
        base,
        key: "p1e:\(label):outcome:initial",
        manifest: [try OutcomeArtifactRefV1(
            kind: .externalReceipt,
            locator: "receipt://\(label)",
            contentHash: p1eHashA
        )]
    )
    let pending = try p1dBeginVerification(
        base,
        outcome: initial,
        key: "p1e:\(label):verification:begin"
    )
    let verificationID = p1eVerificationID
    _ = try p1dRecordVerification(
        base,
        outcome: pending,
        recordId: verificationID,
        key: "p1e:\(label):verification:record"
    )
    let verified = try p1dRequireOutcome(base, id: initial.id)
    let delivered = try base.store.markDelivered(
        MarkDeliveredCommandV1(
            envelope: p1dSystemEnvelope(
                "p1e:\(label):deliver",
                actorId: P1DActorID.delivery
            ),
            outcome: verified.currentRef,
            expectedAggregateVersion: verified.aggregateVersion
        )
    )
    return P1EAcceptedOutcomeFixture(
        domain: P1DOutcomeFixture(
            base: base.base,
            contract: base.contract,
            goal: base.goal,
            store: OutcomeStore(
                database: base.base.database,
                clock: { p1dEpoch.addingTimeInterval(10_000) }
            )
        ),
        delivered: delivered,
        verificationID: verificationID
    )
}

func p1eAcceptOutcome(
    _ fixture: P1EAcceptedOutcomeFixture,
    key: String
) throws -> AcceptanceCommitSnapshotV1 {
    try fixture.domain.store.acceptOutcome(
        AcceptOutcomeCommandV1(
            envelope: p1dUserEnvelope(
                key,
                at: p1dEpoch.addingTimeInterval(1)
            ),
            acceptanceId: p1eAcceptanceID,
            outcome: fixture.delivered.currentRef,
            expectedOutcomeAggregateVersion:
                fixture.delivered.aggregateVersion,
            subject: .user(P1DActorID.localOwner),
            reason: "User accepted"
        )
    )
}

private func p1eSeedSkillCow(
    _ id: String,
    database: AppDatabase
) throws {
    let companion = CompanionRecord(
        id: id,
        name: "Experienced Cow",
        color: "green",
        rolePrompt: "Learns only from accepted verified outcomes",
        model: "test-model",
        toolsJson: "[]",
        kind: .regular,
        campId: nil,
        createdAt: p1dEpoch
    )
    try database.pool.write { try companion.insert($0) }
    _ = try CowResidencyStore(database: database).synchronizeCompanion(
        companion,
        provisionActiveResidency: false
    )
}

private func p1eOutcomeSkillDraft(
    id: String,
    cowID: String
) throws -> MemoryRecordDraftV1 {
    try MemoryRecordDraftV1(
        id: id,
        layer: .globalSkill,
        ownerType: .cow,
        ownerId: cowID,
        campId: nil,
        title: "Verified delivery skill",
        bodyText: "Run the authoritative gate before delivery",
        contentRef: nil,
        sourceType: .outcomeExperience,
        applicabilityJson: "{\"contexts\":[\"coding\"]}",
        createdByActorId: cowID,
        confirmedByActorId: P1DActorID.localOwner
    )
}

@Suite(.serialized)
struct P1EMemoryProvenanceTests {
    @Test func p1e25MemoryRawWorkingPromotionFlow() throws {
        let database = try p1eE2Database("memory-promotion")
        _ = try p1eE2SeedCamp("camp:memory-promotion", database: database)
        _ = try p1eE2SeedCow("cow:memory-promotion", database: database)
        let residency = CowResidencyStore(database: database)
        _ = try p1eE2ActivateResidency(
            store: residency,
            cowID: "cow:memory-promotion",
            campID: "camp:memory-promotion",
            suffix: "memory-promotion"
        )
        let store = MemoryRecordStore(database: database)
        let raw = try store.record(
            try MemoryRecordDraftV1(
                id: "memory:promotion",
                layer: .rawSource,
                ownerType: .camp,
                ownerId: "camp:memory-promotion",
                campId: "camp:memory-promotion",
                title: "Untrusted source",
                bodyText: "observed fact",
                contentRef: nil,
                sourceType: .independentSource,
                applicabilityJson: "{}",
                createdByActorId: "system:distiller:v1",
                confirmedByActorId: nil
            ),
            authorizedCowId: "cow:memory-promotion",
            expectedCampLifecycleVersion: 1,
            at: p1eE2Epoch
        )
        #expect(raw.layer == .rawSource)
        #expect(raw.status == .active)
        #expect(raw.confirmedByActorId == nil)

        let promoted = try store.promote(
            source: raw.ref,
            targetLayer: .campKnowledge,
            targetOwnerType: .camp,
            targetOwnerId: "camp:memory-promotion",
            targetCampId: "camp:memory-promotion",
            sourceType: .independentSource,
            confirmedByActorId: "user:local-owner",
            authorizedCowId: "cow:memory-promotion",
            expectedCampLifecycleVersion: 1,
            at: p1eE2Epoch.addingTimeInterval(1)
        )
        #expect(promoted.id == raw.id)
        #expect(promoted.version == 2)
        #expect(promoted.layer == .campKnowledge)
        #expect(promoted.status == .active)
        #expect(promoted.confirmedByActorId == "user:local-owner")
        let dependencies = try store.dependencies(memory: promoted.ref)
        #expect(dependencies.count == 1)
        #expect(dependencies[0].dependencyType == .memory)
        #expect(dependencies[0].dependencyId == raw.id)
        #expect(dependencies[0].dependencyVersion == raw.version)
        #expect(dependencies[0].dependencyHash == raw.contentHash)
    }

    @Test func p1e26MemoryLayerOwnerAndCarrierInvariants() throws {
        #expect(throws: MemoryRecordContractError.invalidLayerOwner) {
            _ = try MemoryRecordDraftV1(
                id: "memory:bad-owner",
                layer: .campKnowledge,
                ownerType: .cow,
                ownerId: "cow:bad",
                campId: "camp:bad",
                title: "Bad",
                bodyText: "body",
                contentRef: nil,
                sourceType: .userConfirmed,
                applicabilityJson: "{}",
                createdByActorId: "user:local-owner",
                confirmedByActorId: "user:local-owner"
            )
        }
        #expect(throws: MemoryRecordContractError.invalidCampScope) {
            _ = try MemoryRecordDraftV1(
                id: "memory:bad-global",
                layer: .globalPreference,
                ownerType: .user,
                ownerId: "user:local-owner",
                campId: "camp:unexpected",
                title: "Bad",
                bodyText: "body",
                contentRef: nil,
                sourceType: .userConfirmed,
                applicabilityJson: "{}",
                createdByActorId: "user:local-owner",
                confirmedByActorId: "user:local-owner"
            )
        }
        #expect(throws: MemoryRecordContractError.invalidCarrier) {
            _ = try MemoryRecordDraftV1(
                id: "memory:bad-carrier",
                layer: .working,
                ownerType: .user,
                ownerId: "user:local-owner",
                campId: nil,
                title: "Bad",
                bodyText: "body",
                contentRef: "file://duplicate",
                sourceType: .inference,
                applicabilityJson: "{}",
                createdByActorId: "system:test",
                confirmedByActorId: nil
            )
        }
        let valid = try MemoryRecordDraftV1(
            id: "memory:global-preference",
            layer: .globalPreference,
            ownerType: .user,
            ownerId: "user:local-owner",
            campId: nil,
            title: "Preferred style",
            bodyText: nil,
            contentRef: "local-memory://preference/1",
            sourceType: .userConfirmed,
            applicabilityJson: "{\"contexts\":[\"coding\"]}",
            createdByActorId: "user:local-owner",
            confirmedByActorId: "user:local-owner"
        )
        #expect(valid.bodyText == nil)
        #expect(valid.contentRef != nil)
        #expect(valid.layer == .globalPreference)
    }

    @Test func p1e27AcceptedOutcomeSkillPromotion() throws {
        let fixture = try p1eAcceptedOutcomeFixture("skill-accepted")
        let accepted = try p1eAcceptOutcome(
            fixture,
            key: "p1e-skill-accepted:accept"
        )
        let cowID = "cow:p1e:skill:accepted"
        try p1eSeedSkillCow(cowID, database: fixture.domain.base.database)
        let store = MemoryRecordStore(database: fixture.domain.base.database)
        let skill = try store.recordOutcomeSkill(
            try p1eOutcomeSkillDraft(
                id: "memory:p1e:skill:accepted",
                cowID: cowID
            ),
            outcome: accepted.outcome.currentRef,
            verificationId: fixture.verificationID,
            acceptanceId: accepted.record.id,
            at: p1dEpoch.addingTimeInterval(2)
        )
        #expect(skill.layer == .globalSkill)
        #expect(skill.status == .active)
        #expect(skill.sourceType == .outcomeExperience)
        let dependencies = try store.dependencies(memory: skill.ref)
        #expect(dependencies.map(\.dependencyType) == [
            .outcome, .verification, .acceptance,
        ])
        #expect(dependencies.map(\.dependencyId) == [
            accepted.outcome.id, fixture.verificationID, accepted.record.id,
        ])
    }

    @Test func p1e28UnacceptedOrInvalidSkillPromotionRejects() throws {
        let unaccepted = try p1eAcceptedOutcomeFixture("skill-unaccepted")
        let unacceptedCow = "cow:p1e:skill:unaccepted"
        try p1eSeedSkillCow(
            unacceptedCow,
            database: unaccepted.domain.base.database
        )
        let unacceptedStore = MemoryRecordStore(
            database: unaccepted.domain.base.database
        )
        #expect(
            throws: MemoryPromotionAuthorizationError.outcomeNotAccepted
        ) {
            _ = try unacceptedStore.recordOutcomeSkill(
                try p1eOutcomeSkillDraft(
                    id: "memory:p1e:skill:unaccepted",
                    cowID: unacceptedCow
                ),
                outcome: unaccepted.delivered.currentRef,
                verificationId: unaccepted.verificationID,
                acceptanceId: p1eAcceptanceID,
                at: p1dEpoch.addingTimeInterval(2)
            )
        }

        let invalid = try p1eAcceptedOutcomeFixture("skill-invalid")
        let accepted = try p1eAcceptOutcome(
            invalid,
            key: "p1e-skill-invalid:accept"
        )
        let invalidCow = "cow:p1e:skill:invalid"
        try p1eSeedSkillCow(invalidCow, database: invalid.domain.base.database)
        try invalid.domain.base.database.pool.write { db in
            try db.execute(
                sql: """
                    UPDATE verification_result_head SET derivedResult='invalid'
                    WHERE currentVerificationId=?
                    """,
                arguments: [invalid.verificationID]
            )
        }
        let invalidStore = MemoryRecordStore(
            database: invalid.domain.base.database
        )
        #expect(
            throws: MemoryPromotionAuthorizationError.verificationInvalid
        ) {
            _ = try invalidStore.recordOutcomeSkill(
                try p1eOutcomeSkillDraft(
                    id: "memory:p1e:skill:invalid",
                    cowID: invalidCow
                ),
                outcome: accepted.outcome.currentRef,
                verificationId: invalid.verificationID,
                acceptanceId: accepted.record.id,
                at: p1dEpoch.addingTimeInterval(2)
            )
        }
    }

    @Test func p1e29MemoryDependencyAppendOnlyGraph() throws {
        let database = try p1eE2Database("memory-dependency")
        let store = MemoryRecordStore(database: database)
        let memory = try store.record(
            p1eGlobalWorkingDraft(
                id: "memory:dependency",
                title: "Dependency graph"
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch
        )
        let dependency = try store.appendDependency(
            try MemoryDependencyDraftV1(
                id: "memory-dependency:input:1",
                memory: memory.ref,
                dependencyType: .input,
                dependencyId: "input:1",
                dependencyVersion: 1,
                dependencyHash: p1eHashA,
                createdAt: p1eE2Epoch
            )
        )
        #expect(try store.dependencies(memory: memory.ref) == [dependency])
        #expect(throws: DatabaseError.self) {
            try database.pool.write { db in
                try db.execute(
                    sql: "UPDATE memory_dependency SET dependencyId='input:2' WHERE id=?",
                    arguments: [dependency.id]
                )
            }
        }
        #expect(throws: DatabaseError.self) {
            try database.pool.write { db in
                try db.execute(
                    sql: "DELETE FROM memory_dependency WHERE id=?",
                    arguments: [dependency.id]
                )
            }
        }
        #expect(try store.dependencies(memory: memory.ref) == [dependency])
    }

    @Test func p1e30DependencyInvalidationStateMatrix() throws {
        let database = try p1eE2Database("memory-invalidation")
        let store = MemoryRecordStore(database: database)
        let acceptanceMemory = try store.record(
            p1eGlobalWorkingDraft(
                id: "memory:acceptance-dependent",
                title: "Acceptance"
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch
        )
        let verificationMemory = try store.record(
            p1eGlobalWorkingDraft(
                id: "memory:verification-dependent",
                title: "Verification"
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch
        )
        let outcomeMemory = try store.record(
            p1eGlobalWorkingDraft(
                id: "memory:outcome-dependent",
                title: "Outcome"
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch
        )
        let sourceMemory = try store.record(
            p1eGlobalWorkingDraft(
                id: "memory:source-dependent",
                title: "Source"
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch
        )
        let outcomeID = "outcome:memory-matrix"
        let verificationID = "verification:memory-matrix"
        let acceptanceID = "acceptance:memory-matrix"
        let sourceID = "input:memory-matrix"
        let dependencyRows = [
            try MemoryDependencyDraftV1(
                id: "dep:acceptance", memory: acceptanceMemory.ref,
                dependencyType: .acceptance, dependencyId: acceptanceID,
                dependencyVersion: 1, dependencyHash: p1eHashA,
                createdAt: p1eE2Epoch
            ),
            try MemoryDependencyDraftV1(
                id: "dep:verification", memory: verificationMemory.ref,
                dependencyType: .verification, dependencyId: verificationID,
                dependencyVersion: 1, dependencyHash: p1eHashB,
                createdAt: p1eE2Epoch
            ),
            try MemoryDependencyDraftV1(
                id: "dep:outcome", memory: outcomeMemory.ref,
                dependencyType: .outcome, dependencyId: outcomeID,
                dependencyVersion: 1, dependencyHash: p1eHashC,
                createdAt: p1eE2Epoch
            ),
            try MemoryDependencyDraftV1(
                id: "dep:source", memory: sourceMemory.ref,
                dependencyType: .input, dependencyId: sourceID,
                dependencyVersion: 1, dependencyHash: p1eHashA,
                createdAt: p1eE2Epoch
            ),
        ]
        for dependency in dependencyRows {
            _ = try store.appendDependency(dependency)
        }

        try database.pool.write { db in
            _ = try store.applyInvalidation(
                .outcomeReturned(
                    outcomeId: outcomeID,
                    outcomeVersion: 1,
                    acceptanceId: acceptanceID
                ),
                at: p1eE2Epoch.addingTimeInterval(1),
                database: db
            )
        }
        #expect(try store.latest(id: acceptanceMemory.id)?.status == .needsReview)

        try database.pool.write { db in
            _ = try store.applyInvalidation(
                .verificationInvalidated(
                    outcomeId: outcomeID,
                    outcomeVersion: 1,
                    verificationIds: [verificationID]
                ),
                at: p1eE2Epoch.addingTimeInterval(2),
                database: db
            )
        }
        #expect(try store.latest(id: verificationMemory.id)?.status == .invalidated)
        #expect(try store.latest(id: outcomeMemory.id)?.status == .needsReview)

        try database.pool.write { db in
            _ = try store.applyInvalidation(
                .dependencyInvalidated(
                    type: .input,
                    id: sourceID,
                    version: 1,
                    hash: p1eHashA,
                    deleted: false
                ),
                at: p1eE2Epoch.addingTimeInterval(3),
                database: db
            )
        }
        #expect(try store.latest(id: sourceMemory.id)?.status == .invalidated)

        let injectable = try store.injectableMemories(
            ownerType: .user,
            ownerId: "user:local-owner",
            campId: nil
        )
        #expect(injectable.isEmpty)
    }

    @Test func p1e31MemoryTombstoneErasesPrivateCarrier() throws {
        let database = try p1eE2Database("memory-tombstone")
        let store = MemoryRecordStore(database: database)
        let first = try store.record(
            p1eGlobalWorkingDraft(
                id: "memory:tombstone",
                title: "Private body"
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch
        )
        _ = try store.promote(
            source: first.ref,
            targetLayer: .globalPreference,
            targetOwnerType: .user,
            targetOwnerId: "user:local-owner",
            targetCampId: nil,
            sourceType: .userConfirmed,
            confirmedByActorId: "user:local-owner",
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1eE2Epoch.addingTimeInterval(1)
        )
        let tombstone = try store.tombstone(
            memoryId: first.id,
            at: p1eE2Epoch.addingTimeInterval(2)
        )
        #expect(tombstone.status == .deletedTombstone)
        #expect(tombstone.bodyText == nil)
        #expect(tombstone.contentRef == nil)
        let allVersions = try store.versions(id: first.id)
        #expect(allVersions.count == 2)
        #expect(allVersions.allSatisfy { version in
            version.status == .deletedTombstone
                && version.bodyText == nil
                && version.contentRef == nil
        })
    }

}
