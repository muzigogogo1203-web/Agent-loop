import Foundation
import Testing
@testable import AgentLoopApplication
@testable import AgentLoopCore

@Suite(.serialized)
struct P1ECampIsolationTests {
    @Test func p1e20SameCowTwoCampsMemoryIsolation() throws {
        let database = try p1eE2Database("same-cow-two-camps")
        _ = try p1eE2SeedCamp("camp:isolation:a", database: database)
        _ = try p1eE2SeedCamp("camp:isolation:b", database: database)
        _ = try p1eE2SeedCow("cow:isolation", database: database)
        let residency = CowResidencyStore(database: database)
        _ = try p1eE2ActivateResidency(
            store: residency,
            cowID: "cow:isolation",
            campID: "camp:isolation:a",
            suffix: "isolation-a"
        )
        _ = try p1eE2ActivateResidency(
            store: residency,
            cowID: "cow:isolation",
            campID: "camp:isolation:b",
            suffix: "isolation-b"
        )
        let controller = CampMemoryWorkflowController.live(database: database)
        _ = try controller.record(
            try MemoryRecordDraftV1(
                id: "memory:isolation:a",
                layer: .working,
                ownerType: .cow,
                ownerId: "cow:isolation",
                campId: "camp:isolation:a",
                title: "Only A",
                bodyText: "camp A",
                contentRef: nil,
                sourceType: .inference,
                applicabilityJson: "{}",
                createdByActorId: "cow:isolation",
                confirmedByActorId: nil
            ),
            authorizedCowId: "cow:isolation",
            expectedCampLifecycleVersion: 1,
            at: p1eE2Epoch
        )
        _ = try controller.record(
            try MemoryRecordDraftV1(
                id: "memory:isolation:b",
                layer: .working,
                ownerType: .cow,
                ownerId: "cow:isolation",
                campId: "camp:isolation:b",
                title: "Only B",
                bodyText: "camp B",
                contentRef: nil,
                sourceType: .inference,
                applicabilityJson: "{}",
                createdByActorId: "cow:isolation",
                confirmedByActorId: nil
            ),
            authorizedCowId: "cow:isolation",
            expectedCampLifecycleVersion: 1,
            at: p1eE2Epoch
        )

        let campA = try controller.authorizedMemory(
            cowId: "cow:isolation",
            campId: "camp:isolation:a",
            bridges: [],
            at: p1eE2Epoch
        )
        let campB = try controller.authorizedMemory(
            cowId: "cow:isolation",
            campId: "camp:isolation:b",
            bridges: [],
            at: p1eE2Epoch
        )
        #expect(campA.map(\.id) == ["memory:isolation:a"])
        #expect(campB.map(\.id) == ["memory:isolation:b"])
    }

    @Test func p1e21InactiveResidencyBlocksReadWrite() throws {
        let database = try p1eE2Database("inactive-blocks")
        _ = try p1eE2SeedCamp("camp:inactive", database: database)
        _ = try p1eE2SeedCow("cow:inactive", database: database)
        let residency = CowResidencyStore(database: database)
        let active = try p1eE2ActivateResidency(
            store: residency,
            cowID: "cow:inactive",
            campID: "camp:inactive",
            suffix: "inactive"
        )
        _ = try residency.transition(ChangeCampResidencyCommandV1(
            envelope: p1eE2Envelope("inactive:pause"),
            residencyId: active.id,
            expectedAggregateVersion: active.aggregateVersion,
            transition: .pause,
            expectedCampLifecycleVersion: 1
        ))
        let controller = CampMemoryWorkflowController.live(database: database)
        let draft = try MemoryRecordDraftV1(
            id: "memory:inactive",
            layer: .working,
            ownerType: .cow,
            ownerId: "cow:inactive",
            campId: "camp:inactive",
            title: "Must not write",
            bodyText: "blocked",
            contentRef: nil,
            sourceType: .inference,
            applicabilityJson: "{}",
            createdByActorId: "cow:inactive",
            confirmedByActorId: nil
        )
        #expect(throws: ResidencyAuthorizationError.inactive(.paused)) {
            _ = try controller.record(
                draft,
                authorizedCowId: "cow:inactive",
                expectedCampLifecycleVersion: 1,
                at: p1eE2Epoch
            )
        }
        #expect(throws: ResidencyAuthorizationError.inactive(.paused)) {
            _ = try controller.authorizedMemory(
                cowId: "cow:inactive",
                campId: "camp:inactive",
                bridges: [],
                at: p1eE2Epoch
            )
        }
        let count = try database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM memory_record_version"
            ) ?? -1
        }
        #expect(count == 0)
    }
}
