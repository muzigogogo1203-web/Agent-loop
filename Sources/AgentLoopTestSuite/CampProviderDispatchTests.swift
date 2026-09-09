import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

private struct P1EProviderFixture {
    let database: AppDatabase
    let store: CampProviderDispatchStore
    let work: DurableWorkRecord
    let claim: DurableWorkClaim
    let threadId: String
}

private func p1eE3ProviderSeedGuide(
    campID: String,
    database: AppDatabase
) throws {
    let guide = CompanionRecord(
        id: "guide:\(campID)",
        name: "Provider Guide",
        color: "amber",
        rolePrompt: "Guide safely",
        model: "test-model",
        toolsJson: "[]",
        kind: .guide,
        campId: campID,
        createdAt: p1eE2Epoch
    )
    try database.pool.write { try guide.insert($0) }
    _ = try CowResidencyStore(database: database).synchronizeCompanion(
        guide,
        provisionActiveResidency: true
    )
}

private func p1eE3ProviderFixture(
    _ label: String
) throws -> P1EProviderFixture {
    let database = try p1eE2Database("provider-\(label)")
    let campID = "camp:provider:\(label)"
    _ = try p1eE2SeedCamp(campID, database: database)
    try p1eE3ProviderSeedGuide(campID: campID, database: database)
    let store = CampProviderDispatchStore(database: database)
    let queued = try store.enqueueGuideTurn(
        campId: campID,
        userText: "Question \(label)",
        idempotencyKey: "p1e:provider:\(label):enqueue",
        traceId: "trace:p1e:provider:\(label)",
        at: p1eE2Epoch
    )
    let claimed = try DurableWorkStore(database: database).claimNext(
        kinds: [.guideChat],
        workerId: "worker:p1e:provider",
        now: p1eE2Epoch.addingTimeInterval(1),
        leaseDuration: 60
    )
    let claim = try #require(claimed)
    return P1EProviderFixture(
        database: database,
        store: store,
        work: queued.work,
        claim: claim,
        threadId: queued.thread.id
    )
}

private func p1eE3PreparedDispatch(
    _ fixture: P1EProviderFixture,
    suffix: String = "turn"
) throws -> CampProviderDispatchSnapshotV1 {
    try fixture.store.prepare(
        claim: fixture.claim,
        operationKind: .guideChat,
        turnOrdinal: 0,
        requestJson: "{\"messages\":[],\"model\":\"test-model\"}",
        idempotencyKey: "p1e:provider:\(suffix):prepare",
        at: p1eE2Epoch.addingTimeInterval(2)
    )
}

private func p1eE3ReturnedDispatch(
    _ fixture: P1EProviderFixture,
    suffix: String = "turn"
) throws -> CampProviderDispatchSnapshotV1 {
    let prepared = try p1eE3PreparedDispatch(fixture, suffix: suffix)
    let started = try fixture.store.start(
        dispatchId: prepared.id,
        expectedVersion: prepared.version,
        claim: fixture.claim,
        at: p1eE2Epoch.addingTimeInterval(3)
    )
    return try fixture.store.recordReturned(
        dispatchId: started.id,
        expectedVersion: started.version,
        claim: fixture.claim,
        responseJson: "{\"text\":\"hello\"}",
        at: p1eE2Epoch.addingTimeInterval(4)
    )
}

private func p1eE3PackageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Suite(.serialized)
struct P1ECampProviderDispatchTests {
    @Test func p1e37ProviderMessageAndWorkCommitAtomically() throws {
        let database = try p1eE2Database("provider-atomic")
        let campID = "camp:provider:atomic"
        _ = try p1eE2SeedCamp(campID, database: database)
        try p1eE3ProviderSeedGuide(campID: campID, database: database)
        let store = CampProviderDispatchStore(database: database)
        try database.pool.write { db in
            try db.execute(sql: """
                CREATE TRIGGER p1e_provider_enqueue_abort
                BEFORE INSERT ON durable_work WHEN NEW.kind='guideChat'
                BEGIN SELECT RAISE(ABORT, 'p1e injected work failure'); END
                """)
        }
        #expect(throws: DatabaseError.self) {
            _ = try store.enqueueGuideTurn(
                campId: campID,
                userText: "Atomic question",
                idempotencyKey: "p1e:provider:atomic:enqueue",
                traceId: "trace:p1e:provider:atomic",
                at: p1eE2Epoch
            )
        }
        let failedCounts = try database.pool.read { db in
            (
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chat_thread"),
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chat_message"),
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM durable_work")
            )
        }
        #expect(failedCounts.0 == 0)
        #expect(failedCounts.1 == 0)
        #expect(failedCounts.2 == 0)
        try database.pool.write { db in
            try db.execute(sql: "DROP TRIGGER p1e_provider_enqueue_abort")
        }
        let committed = try store.enqueueGuideTurn(
            campId: campID,
            userText: "Atomic question",
            idempotencyKey: "p1e:provider:atomic:enqueue",
            traceId: "trace:p1e:provider:atomic",
            at: p1eE2Epoch
        )
        #expect(committed.work.kind == .guideChat)
        #expect(committed.work.state == .queued)
        #expect(try database.messages(threadId: committed.thread.id).count == 1)
    }

    @Test func p1e38ProviderPrepareStartReturnConsumeSuccess() throws {
        let fixture = try p1eE3ProviderFixture("success")
        let prepared = try p1eE3PreparedDispatch(fixture, suffix: "success")
        #expect(prepared.state == .prepared)
        #expect(prepared.replayClass == .replaySafeInference)
        let started = try fixture.store.start(
            dispatchId: prepared.id,
            expectedVersion: prepared.version,
            claim: fixture.claim,
            at: p1eE2Epoch.addingTimeInterval(3)
        )
        #expect(started.state == .started)
        let returned = try fixture.store.recordReturned(
            dispatchId: started.id,
            expectedVersion: started.version,
            claim: fixture.claim,
            responseJson: "{\"text\":\"hello\"}",
            at: p1eE2Epoch.addingTimeInterval(4)
        )
        #expect(returned.state == .returned)
        #expect(
            try fixture.store.nextAction(dispatchId: returned.id)
                == .consumeReturned(responseJson: "{\"text\":\"hello\"}")
        )
        let completion = try fixture.store.consume(
            dispatchId: returned.id,
            expectedVersion: returned.version,
            claim: fixture.claim,
            outputJson: "{\"replyMessageId\":\"message:reply\"}",
            at: p1eE2Epoch.addingTimeInterval(5)
        )
        #expect(completion.dispatch.state == .consumed)
        #expect(completion.work.state == .succeeded)
        let eventKinds = try fixture.database.pool.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT eventKind FROM durable_work_attempt_event
                    WHERE workId=? ORDER BY sequence
                    """,
                arguments: [fixture.work.id]
            )
        }
        #expect(eventKinds == [
            "claimed", "providerDispatchStarted",
            "providerResponseReturned", "succeeded",
        ])
    }

    @Test func p1e39ReturnedCheckpointNeverRecallsProvider() throws {
        let fixture = try p1eE3ProviderFixture("returned-restart")
        let returned = try p1eE3ReturnedDispatch(
            fixture,
            suffix: "returned-restart"
        )
        let restarted = CampProviderDispatchStore(database: fixture.database)
        #expect(
            try restarted.nextAction(dispatchId: returned.id)
                == .consumeReturned(responseJson: "{\"text\":\"hello\"}")
        )
        let fetchedReloaded = try restarted.dispatch(id: returned.id)
        let reloaded = try #require(fetchedReloaded)
        #expect(reloaded.responseHash == returned.responseHash)
        #expect(reloaded.state == .returned)
    }

    @Test func p1e40StartedDispatchAbandonAndExactReplay() throws {
        let fixture = try p1eE3ProviderFixture("replay")
        let prepared = try p1eE3PreparedDispatch(fixture, suffix: "replay")
        let started = try fixture.store.start(
            dispatchId: prepared.id,
            expectedVersion: prepared.version,
            claim: fixture.claim,
            at: p1eE2Epoch.addingTimeInterval(3)
        )
        #expect(
            try fixture.store.nextAction(dispatchId: started.id)
                == .requiresAbandonBeforeReplay
        )
        let replay = try fixture.store.abandonStartedAndPrepareReplay(
            dispatchId: started.id,
            expectedVersion: started.version,
            claim: fixture.claim,
            at: p1eE2Epoch.addingTimeInterval(4)
        )
        let fetchedAbandoned = try fixture.store.dispatch(id: started.id)
        let abandoned = try #require(fetchedAbandoned)
        #expect(abandoned.state == .abandoned)
        #expect(replay.state == .prepared)
        #expect(replay.dispatchAttempt == 2)
        #expect(replay.replayOfDispatchId == started.id)
        #expect(replay.requestJson == started.requestJson)
        #expect(replay.requestHash == started.requestHash)
    }

    @Test func p1e41ProviderLifecycleFenceRace() throws {
        let fixture = try p1eE3ProviderFixture("lifecycle-race")
        let prepared = try p1eE3PreparedDispatch(
            fixture,
            suffix: "lifecycle-race"
        )
        let started = try fixture.store.start(
            dispatchId: prepared.id,
            expectedVersion: prepared.version,
            claim: fixture.claim,
            at: p1eE2Epoch.addingTimeInterval(3)
        )
        try fixture.database.pool.write { db in
            try db.execute(
                sql: "UPDATE camp SET archived=1 WHERE id=?",
                arguments: [started.campId]
            )
            try db.execute(
                sql: """
                    UPDATE camp_lifecycle
                    SET state='archived',version=2,updatedAt=? WHERE campId=?
                    """,
                arguments: [p1eE2Epoch.addingTimeInterval(4), started.campId]
            )
        }
        #expect(
            throws: CampLifecycleWriteAuthorizationError
                .lifecycleVersionMismatch(expected: 1, actual: 2)
        ) {
            _ = try fixture.store.recordReturned(
                dispatchId: started.id,
                expectedVersion: started.version,
                claim: fixture.claim,
                responseJson: "{\"text\":\"late\"}",
                at: p1eE2Epoch.addingTimeInterval(5)
            )
        }
        let fetchedPersisted = try fixture.store.dispatch(id: started.id)
        let persisted = try #require(fetchedPersisted)
        #expect(persisted.state == .started)
        #expect(persisted.responseJson == nil)
    }

    @Test func p1e42GuideAndCampDistillReplayClass() throws {
        #expect(
            try CampProviderRoutePolicyV1.resolve(.guideChat(campId: "camp:a"))
                == .camp(
                    campId: "camp:a",
                    operationKind: .guideChat,
                    replayClass: .replaySafeInference
                )
        )
        for route in [
            CampProviderRouteV1.guideDistillation(campId: "camp:a"),
            .closeoutDistillation(campId: "camp:a"),
            .coworkDistillation(campId: "camp:a"),
        ] {
            #expect(
                try CampProviderRoutePolicyV1.resolve(route)
                    == .camp(
                        campId: "camp:a",
                        operationKind: .memoryPromotion,
                        replayClass: .replaySafeInference
                    )
            )
        }
    }

    @Test func p1e43GlobalProviderRoutesAvoidCampDispatch() throws {
        let database = try p1eE2Database("provider-global-routes")
        let store = CampProviderDispatchStore(database: database)
        for route in [
            CampProviderRouteV1.dmDistillation(cowId: "cow:global"),
            .globalDistillation(ownerId: "user:local-owner"),
            .connectionTest,
        ] {
            #expect(try CampProviderRoutePolicyV1.resolve(route) == .global)
        }
        #expect(try store.dispatchCount() == 0)
    }

    @Test func p1e44UnknownExternalWriteRouteRejects() throws {
        let database = try p1eE2Database("provider-external-reject")
        let store = CampProviderDispatchStore(database: database)
        #expect(
            throws: CampProviderRouteError.unregisteredExternalWrite
        ) {
            _ = try CampProviderRoutePolicyV1.resolve(
                .externalWrite(name: "send_webhook", campId: "camp:a")
            )
        }
        #expect(try store.dispatchCount() == 0)
    }

    @Test func p1e45GuideToolAllowlistAndReceiptDedupe() throws {
        let fixture = try p1eE3ProviderFixture("guide-tool")
        let returned = try p1eE3ReturnedDispatch(
            fixture,
            suffix: "guide-tool"
        )
        #expect(CampProviderRoutePolicyV1.guideToolNames == [
            "camp_status", "propose_squad", "search_camp_notes",
        ])
        #expect(throws: GuideToolAuthorizationError.unregisteredTool) {
            try CampProviderRoutePolicyV1.requireGuideTool("send_webhook")
        }
        let block = SquadProposalBlock(
            proposalId: "proposal:p1e:dedupe",
            name: "Safe squad",
            memberIds: ["cow:member"],
            goal: "Work safely",
            budget: 500,
            status: .pending
        )
        let first = try fixture.store.recordGuideProposal(
            dispatchId: returned.id,
            workId: fixture.work.id,
            turnOrdinal: 0,
            toolUseId: "tool-use:p1e:1",
            threadId: fixture.threadId,
            block: block,
            at: p1eE2Epoch.addingTimeInterval(5)
        )
        let replay = try fixture.store.recordGuideProposal(
            dispatchId: returned.id,
            workId: fixture.work.id,
            turnOrdinal: 0,
            toolUseId: "tool-use:p1e:1",
            threadId: fixture.threadId,
            block: block,
            at: p1eE2Epoch.addingTimeInterval(5)
        )
        #expect(replay == first)
        let counts = try fixture.database.pool.read { db in
            (
                try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM chat_message WHERE id=?",
                    arguments: [first]
                ),
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM domain_command_receipt
                        WHERE commandType='p1e.guide-proposal.v1'
                        """
                )
            )
        }
        #expect(counts.0 == 1)
        #expect(counts.1 == 1)
    }

    @Test func p1e46HistoricUnsafeStartedFailsObservably() throws {
        let fixture = try p1eE3ProviderFixture("historic-started")
        let prepared = try p1eE3PreparedDispatch(
            fixture,
            suffix: "historic-started"
        )
        let started = try fixture.store.start(
            dispatchId: prepared.id,
            expectedVersion: prepared.version,
            claim: fixture.claim,
            at: p1eE2Epoch.addingTimeInterval(3)
        )
        let intent = try fixture.store.reconcileHistoricUnsafeStarted(
            dispatchId: started.id,
            at: p1eE2Epoch.addingTimeInterval(4)
        )
        #expect(intent.errorCode == "provider_effect_unknown")
        #expect(intent.requiresUrgentAttention)
        #expect(intent.workId == fixture.work.id)
        #expect(try fixture.store.dispatch(id: started.id)?.state == .abandoned)
        let work = try fixture.database.pool.read { db in
            try DurableWorkRecord.fetchOne(db, key: fixture.work.id)
        }
        #expect(work?.state == .failed)
        #expect(work?.errorCode == "provider_effect_unknown")
    }

    @Test func p1e47ServicesHaveNoUnregisteredProviderAuthority() throws {
        let root = p1eE3PackageRoot()
        let serviceSources = try [
            "Sources/AgentLoopCore/Chat/GuideChatService.swift",
            "Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift",
            "Sources/AgentLoopCore/Knowledge/Distiller.swift",
        ].map { path in
            try String(contentsOf: root.appendingPathComponent(path))
        }
        for source in serviceSources {
            #expect(!source.contains("let provider: any LLMProvider"))
            #expect(!source.contains("provider.streamTurn"))
            #expect(!source.contains("Distiller(provider:"))
        }
        let guideSource = serviceSources[0]
        #expect(!guideSource.contains("Task {"))
        let orchestrator = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/AgentLoopCore/Kernel/Orchestrator.swift"
            )
        )
        #expect(!orchestrator.contains("distillTasks"))
        #expect(!orchestrator.contains("runCloseoutDistillation"))
        #expect(!orchestrator.contains("distillCoworkNotes"))
        #expect(!orchestrator.contains("Distiller(provider:"))
    }

    @Test func p1e48P1EProviderScopeIntegrationFailsClosed() throws {
        let fixture = try p1eE3ProviderFixture("integration-fail-closed")
        let prepared = try p1eE3PreparedDispatch(
            fixture,
            suffix: "integration-fail-closed"
        )
        let started = try fixture.store.start(
            dispatchId: prepared.id,
            expectedVersion: prepared.version,
            claim: fixture.claim,
            at: p1eE2Epoch.addingTimeInterval(3)
        )
        let messageCount = try fixture.database.messages(
            threadId: fixture.threadId
        ).count
        try fixture.database.pool.write { db in
            try db.execute(
                sql: "UPDATE camp SET archived=1 WHERE id=?",
                arguments: [started.campId]
            )
            try db.execute(
                sql: """
                    UPDATE camp_lifecycle
                    SET state='archived',version=2,updatedAt=? WHERE campId=?
                    """,
                arguments: [p1eE2Epoch.addingTimeInterval(4), started.campId]
            )
        }
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try fixture.store.recordReturned(
                dispatchId: started.id,
                expectedVersion: started.version,
                claim: fixture.claim,
                responseJson: "{\"text\":\"late\"}",
                at: p1eE2Epoch.addingTimeInterval(5)
            )
        }
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try LegacyContentScopeStore(database: fixture.database)
                .appendMessage(
                    threadId: fixture.threadId,
                    role: "guide",
                    contentJson: "{\"text\":\"late\"}",
                    expectedCampLifecycleVersion: 1
                )
        }
        #expect(
            try fixture.database.messages(threadId: fixture.threadId).count
                == messageCount
        )
        #expect(try fixture.store.dispatch(id: started.id)?.state == .started)
        #expect(try fixture.store.dispatchCount() == 1)
    }
}
