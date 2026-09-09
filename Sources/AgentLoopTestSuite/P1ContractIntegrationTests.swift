import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

@Suite(.serialized)
struct P1EContractIntegrationTests {
    @Test func p1e32P1DInvalidationAndMemoryRollbackAtomically() throws {
        let fixture = try p1eAcceptedOutcomeFixture("memory-atomic")
        let accepted = try p1eAcceptOutcome(
            fixture,
            key: "p1e-memory-atomic:accept"
        )
        let memoryStore = MemoryRecordStore(
            database: fixture.domain.base.database
        )
        let memory = try memoryStore.record(
            try MemoryRecordDraftV1(
                id: "memory:p1e:atomic",
                layer: .working,
                ownerType: .user,
                ownerId: P1DActorID.localOwner,
                campId: nil,
                title: "Atomic dependent memory",
                bodyText: "Must move with the Outcome",
                contentRef: nil,
                sourceType: .inference,
                applicabilityJson: "{}",
                createdByActorId: "system:memory:test",
                confirmedByActorId: nil
            ),
            authorizedCowId: nil,
            expectedCampLifecycleVersion: nil,
            at: p1dEpoch.addingTimeInterval(1)
        )
        _ = try memoryStore.appendDependency(MemoryDependencyDraftV1(
            id: "dependency:p1e:atomic:outcome",
            memory: memory.ref,
            dependencyType: .outcome,
            dependencyId: accepted.outcome.id,
            dependencyVersion: accepted.outcome.currentVersion,
            dependencyHash: accepted.outcome.currentRef.hash,
            createdAt: p1dEpoch.addingTimeInterval(1)
        ))
        _ = try memoryStore.appendDependency(MemoryDependencyDraftV1(
            id: "dependency:p1e:atomic:acceptance",
            memory: memory.ref,
            dependencyType: .acceptance,
            dependencyId: accepted.record.id,
            dependencyVersion: 1,
            dependencyHash: p1eHashD,
            createdAt: p1dEpoch.addingTimeInterval(1)
        ))
        try fixture.domain.base.database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER p1e_memory_atomic_abort
                BEFORE UPDATE ON memory_record_version
                WHEN OLD.id='memory:p1e:atomic'
                BEGIN
                  SELECT RAISE(ABORT, 'p1e injected memory failure');
                END
                """)
        }
        let command = try ReturnOutcomeCommandV1(
            envelope: p1dUserEnvelope(
                "p1e-memory-atomic:return",
                at: p1dEpoch.addingTimeInterval(2)
            ),
            acceptanceId: p1eReturnID,
            outcome: accepted.outcome.currentRef,
            expectedOutcomeAggregateVersion: accepted.outcome.aggregateVersion,
            subject: .user(P1DActorID.localOwner),
            reason: "Needs rework"
        )
        #expect(throws: DatabaseError.self) {
            _ = try fixture.domain.store.returnOutcome(command)
        }
        #expect(
            try fixture.domain.store.outcome(id: accepted.outcome.id)?.state
                == .accepted
        )
        #expect(
            try fixture.domain.store.acceptanceCount(
                outcomeId: accepted.outcome.id
            ) == 1
        )
        #expect(try memoryStore.latest(id: memory.id)?.status == .active)

        try fixture.domain.base.database.pool.write { db in
            try db.execute(sql: "DROP TRIGGER p1e_memory_atomic_abort")
        }
        let returned = try fixture.domain.store.returnOutcome(command)
        #expect(returned.outcome.state == .returned)
        #expect(try memoryStore.latest(id: memory.id)?.status == .needsReview)
    }
}
