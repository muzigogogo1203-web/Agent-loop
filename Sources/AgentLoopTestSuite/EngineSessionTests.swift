import Testing
import Foundation
import GRDB
import AgentLoopCore

private func p1f1SessionStore(
    ids: P1F1DeterministicIDs
) -> EngineSessionStore {
    EngineSessionStore(
        sessionIdFactory: { ids.next("session") }
    )
}

private func p1f1StartedExecution(
    fixture: P1F1EngineFixture,
    key: String,
    fields: EngineExecutionRequestFieldsV1? = nil
) throws -> EngineExecutionRequest {
    let request = try fixture.begin(key: key, fields: fields)
    let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: request.executionId,
        expectedVersion: row["version"],
        requestHash: request.requestHash,
        commandIdempotencyKey: "\(key)-dispatch",
        now: p1f1EngineTestNow.addingTimeInterval(1)
    )
    return request
}

private func p1f1ExecutionRecord(
    fixture: P1F1EngineFixture,
    id: String
) throws -> EngineExecutionRecord {
    try fixture.db.pool.read { database in
        try #require(try EngineExecutionRecord.fetchOne(database, key: id))
    }
}

private func p1f1NeedsHumanProposal(
    request: EngineExecutionRequest,
    key: String,
    sequence: Int = 0
) throws -> EngineTerminalProposalContentV1 {
    try EngineTerminalProposalContentV1(
        protocolVersion: "agentloop.execution.v1",
        executionId: request.executionId,
        runId: request.runId,
        cardId: request.cardId,
        sequence: sequence,
        terminalIdempotencyKey: key,
        terminalKind: .blocked,
        terminalSubtype: .needsHumanInput,
        payload: .needsHumanInput(
            kind: .text,
            prompt: "Which invariant should be preserved?",
            options: []
        ),
        artifacts: []
    )
}

@Suite(.serialized)
struct P1F1EngineSessionTests {
    @Test func p1f1_039BindResumeRequiresExactScopeAndWorkspace() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartedExecution(
            fixture: fixture,
            key: "p1f1-session-bind"
        )
        let beforeBind = try p1f1EngineSurfaceCounts(fixture.db)
        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 0,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 0,
                payload: .sessionBound(
                    externalSessionId: "codex-thread-exact-1"
                )
            )
        )
        let boundExecution = try p1f1ExecutionRecord(
            fixture: fixture,
            id: request.executionId
        )
        let boundSessionID = try #require(boundExecution.sessionId)
        let session = try fixture.db.pool.read { database in
            try #require(
                try EngineSessionRecord.fetchOne(
                    database,
                    key: boundSessionID
                )
            )
        }
        let afterBind = try p1f1EngineSurfaceCounts(fixture.db)

        #expect(boundExecution.sessionId == session.id)
        #expect(boundExecution.dispatchState == .sessionBound)
        #expect(boundExecution.nextSequence == 1)
        #expect(session.campId == boundExecution.campId)
        #expect(session.profileId == boundExecution.profileId)
        #expect(session.adapterId == boundExecution.adapterId)
        #expect(session.adapterVersion == boundExecution.adapterVersion)
        #expect(session.sessionScopeHash == boundExecution.sessionScopeHash)
        #expect(session.workspaceHash == request.workspace.hash)
        #expect(session.externalSessionId == "codex-thread-exact-1")
        #expect(session.state == .active)
        #expect(afterBind.sessions == beforeBind.sessions + 1)
        #expect(afterBind.legacyEvents == beforeBind.legacyEvents + 1)
        #expect(afterBind.domainEvents == beforeBind.domainEvents + 1)
        #expect(afterBind.outbox == beforeBind.outbox + 1)

        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM engine_session")
        } == 1)
        _ = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: "engine.event.v1:\(request.executionId):0",
            executionID: request.executionId,
            expectedCommandType: "engine.event-accept.v1",
            expectedResultCode: "engine_event_accepted",
            expectedEventTypes: ["engine.event-accepted.v1"],
            expectedAuditCodes: ["engine_event_accepted"],
            forbiddenSentinels: ["codex-thread-exact-1"]
        )

        let aborted = try P1F1EngineFixture()
        let abortedRequest = try p1f1StartedExecution(
            fixture: aborted,
            key: "p1f1-session-bind-abort"
        )
        try aborted.db.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER p1f1_abort_session_event_outbox
                BEFORE INSERT ON event_outbox
                BEGIN SELECT RAISE(ABORT, 'p1f1 injected session event failure'); END
                """)
        }
        let before = try p1f1EngineSurfaceCounts(aborted.db)
        #expect(throws: DatabaseError.self) {
            try aborted.store.acceptEngineEvent(
                executionId: abortedRequest.executionId,
                sequence: 0,
                event: EngineExecutionEvent(
                    executionId: abortedRequest.executionId,
                    sequence: 0,
                    payload: .sessionBound(
                        externalSessionId: "codex-thread-abort"
                    )
                )
            )
        }
        #expect(try p1f1EngineSurfaceCounts(aborted.db) == before)
        let stillStarted = try p1f1ExecutionRecord(
            fixture: aborted,
            id: abortedRequest.executionId
        )
        #expect(stillStarted.sessionId == nil)
        #expect(stillStarted.dispatchState == .started)
    }

    @Test func p1f1_040UserAnswerNewContextSameScopeResumes() throws {
        let fixture = try P1F1EngineFixture()
        let first = try p1f1StartedExecution(
            fixture: fixture,
            key: "p1f1-answer-first"
        )
        try fixture.store.acceptEngineEvent(
            executionId: first.executionId,
            sequence: 0,
            event: EngineExecutionEvent(
                executionId: first.executionId,
                sequence: 0,
                payload: .sessionBound(
                    externalSessionId: "codex-thread-answer"
                )
            )
        )
        let firstBound = try p1f1ExecutionRecord(
            fixture: fixture,
            id: first.executionId
        )
        let firstSessionID = try #require(firstBound.sessionId)
        let session = try fixture.db.pool.read { database in
            try #require(
                try EngineSessionRecord.fetchOne(
                    database,
                    key: firstSessionID
                )
            )
        }
        let proposal = try fixture.store.recordEngineTerminalProposal(
            p1f1NeedsHumanProposal(
                request: first,
                key: "p1f1-answer-terminal",
                sequence: 1
            )
        )
        _ = try fixture.store.commitEngineAskUser(
            proposalId: proposal.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(3)
        )
        let openRequest = try fixture.db.pool.read { database in
            try #require(
                try UserRequestRecord
                    .filter(Column("cardId") == p1f1EngineCardID)
                    .filter(Column("lifecycleState") == "open")
                    .fetchOne(database)
            )
        }
        try fixture.db.answerUserRequest(
            requestId: openRequest.id,
            answerJson: #"{"text":"keep atomicity"}"#
        )
        #expect(try fixture.db.card(id: p1f1EngineCardID)?.status == .ready)

        let answeredEnvelope = try p1f1CanonicalEnvelope(
            memoryHash: p1f1EngineHashF
        )
        let answeredJSON = String(
            decoding: try CanonicalJSONV1.encode(answeredEnvelope),
            as: UTF8.self
        )
        let next = try p1f1StartedExecution(
            fixture: fixture,
            key: "p1f1-answer-next",
            fields: fixture.fields(
                contextJson: answeredJSON,
                contextHash: CanonicalJSONV1.sha256Hex(Data(answeredJSON.utf8)),
                sessionSelection: try EngineSessionSelectionV1(sessionId: session.id)
            )
        )
        #expect(next.contextHash != first.contextHash)
        #expect(next.sessionScopeHash == first.sessionScopeHash)
        #expect(next.runId != first.runId)
        let expectedSessionReference = try EngineSessionReferenceV1(
            sessionId: session.id,
            externalSessionId: "codex-thread-answer"
        )
        #expect(next.sessionRef == expectedSessionReference)
        #expect(next.requestJson.contains(
            #""externalSessionId":"codex-thread-answer""#
        ))

        let wrongIDStable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: next.executionId,
            runID: next.runId
        )
        #expect(throws: EngineSessionScopeMismatchError.self) {
            try fixture.store.acceptEngineEvent(
                executionId: next.executionId,
                sequence: 0,
                event: EngineExecutionEvent(
                    executionId: next.executionId,
                    sequence: 0,
                    payload: .sessionBound(externalSessionId: "wrong-thread")
                )
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: next.executionId,
            runID: next.runId
        ) == wrongIDStable)

        try fixture.store.acceptEngineEvent(
            executionId: next.executionId,
            sequence: 0,
            event: EngineExecutionEvent(
                executionId: next.executionId,
                sequence: 0,
                payload: .sessionBound(
                    externalSessionId: "codex-thread-answer"
                )
            )
        )
        let resumed = try p1f1ExecutionRecord(
            fixture: fixture,
            id: next.executionId
        )
        #expect(resumed.sessionId == session.id)
        #expect(resumed.dispatchState == .sessionBound)
        #expect(resumed.nextSequence == 1)
        let oldRun = try #require(
            try fixture.db.runs(cardId: p1f1EngineCardID)
                .first { $0.id == first.runId }
        )
        #expect(oldRun.endedAt != nil)
        #expect(oldRun.outcome == "blocked")
        let activeRunIDs = try fixture.db.runs(cardId: p1f1EngineCardID)
            .filter { $0.endedAt == nil }
            .map(\.id)
        #expect(activeRunIDs == [next.runId])
    }

    @Test func p1f1_041ScopeDriftStartsNewSessionAndMismatchZeroWrite() throws {
        let fixture = try P1F1EngineFixture()
        let sessionStore = p1f1SessionStore(ids: fixture.ids)
        let first = try p1f1StartedExecution(
            fixture: fixture,
            key: "p1f1-session-drift-first"
        )
        try fixture.store.acceptEngineEvent(
            executionId: first.executionId,
            sequence: 0,
            event: EngineExecutionEvent(
                executionId: first.executionId,
                sequence: 0,
                payload: .sessionBound(
                    externalSessionId: "codex-thread-scope-1"
                )
            )
        )
        let firstBound = try p1f1ExecutionRecord(
            fixture: fixture,
            id: first.executionId
        )
        let firstSessionID = try #require(firstBound.sessionId)
        let firstSession = try fixture.db.pool.read { database in
            try #require(
                try EngineSessionRecord.fetchOne(
                    database,
                    key: firstSessionID
                )
            )
        }

        let contract = try OutcomeContractRef(
            id: p1f1EngineContractID,
            version: 7,
            hash: p1f1EngineHashA
        )
        func scopeHash(
            campId: String = p1f1EngineCampID,
            profileId: String = p1f1EngineProfileID,
            descriptor: ExecutionEngineDescriptor? = nil,
            engineKind: String = "cli",
            model: String = "gpt-test",
            workspaceHash: String = p1f1EngineWorkspaceHash,
            contractOverride: OutcomeContractRef? = nil
        ) throws -> String {
            let scope = try EngineSessionScopeV1.derived(
                campId: campId,
                profileId: profileId,
                descriptor: descriptor ?? fixture.descriptor,
                engineKind: engineKind,
                model: model,
                workspaceHash: workspaceHash,
                contract: contractOverride ?? contract
            )
            return CanonicalJSONV1.sha256Hex(try CanonicalJSONV1.encode(scope))
        }
        let baseScopeHash = try scopeHash()
        let driftHashes = try [
            scopeHash(campId: "00000000-0000-4000-8000-000000000301"),
            scopeHash(profileId: "00000000-0000-4000-8000-000000000306"),
            scopeHash(descriptor: p1f1ExecutionDescriptor(
                adapterId: "adapter.claude"
            )),
            scopeHash(descriptor: p1f1ExecutionDescriptor(
                adapterVersion: "1.2.4"
            )),
            scopeHash(engineKind: "api"),
            scopeHash(model: "gpt-scope-drift"),
            scopeHash(workspaceHash: p1f1EngineHashD),
            scopeHash(contractOverride: OutcomeContractRef(
                id: p1f1EngineContractID,
                version: 8,
                hash: p1f1EngineHashB
            )),
        ]
        #expect(driftHashes.allSatisfy { $0 != baseScopeHash })
        #expect(Set(driftHashes).count == driftHashes.count)

        let secondCard = "00000000-0000-4000-8000-000000000204"
        try fixture.insertReadyCard(
            secondCard,
            idemKey: "p1f1-session-drift-card"
        )
        let secondEnvelope = try p1f1CanonicalEnvelope(cardID: secondCard)
        let secondJSON = String(
            decoding: try CanonicalJSONV1.encode(secondEnvelope),
            as: UTF8.self
        )
        let second = try p1f1StartedExecution(
            fixture: fixture,
            key: "p1f1-session-drift-second",
            fields: fixture.fields(
                cardID: secondCard,
                model: "gpt-scope-drift",
                contextJson: secondJSON,
                contextHash: CanonicalJSONV1.sha256Hex(Data(secondJSON.utf8))
            )
        )
        #expect(second.sessionScopeHash != first.sessionScopeHash)
        let beforeMismatch = try p1f1EngineSurfaceCounts(fixture.db)
        #expect(throws: EngineSessionScopeMismatchError.self) {
            _ = try fixture.db.pool.write { database in
                try sessionStore.requireExactResume(
                    execution: try #require(
                        try EngineExecutionRecord.fetchOne(
                            database,
                            key: second.executionId
                        )
                    ),
                    sessionId: firstSession.id,
                    externalSessionId: "codex-thread-scope-1",
                    descriptor: fixture.descriptor,
                    database: database,
                    now: p1f1EngineTestNow.addingTimeInterval(4)
                )
            }
        }
        #expect(try p1f1EngineSurfaceCounts(fixture.db) == beforeMismatch)

        try fixture.store.acceptEngineEvent(
            executionId: second.executionId,
            sequence: 0,
            event: EngineExecutionEvent(
                executionId: second.executionId,
                sequence: 0,
                payload: .sessionBound(
                    externalSessionId: "codex-thread-scope-2"
                )
            )
        )
        let secondBound = try p1f1ExecutionRecord(
            fixture: fixture,
            id: second.executionId
        )
        let secondSessionID = try #require(secondBound.sessionId)
        let secondSession = try fixture.db.pool.read { database in
            try #require(
                try EngineSessionRecord.fetchOne(
                    database,
                    key: secondSessionID
                )
            )
        }
        #expect(secondSession.id != firstSession.id)
        #expect(secondSession.sessionScopeHash == second.sessionScopeHash)
        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM engine_session")
        } == 2)

        let invalidated = try fixture.db.pool.write { database in
            try sessionStore.closeOrInvalidate(
                sessionId: firstSession.id,
                expectedVersion: firstSession.version,
                disposition: .invalid,
                database: database,
                now: p1f1EngineTestNow.addingTimeInterval(10)
            )
        }
        #expect(invalidated.state == .invalid)
        #expect(invalidated.version == firstSession.version + 1)
        #expect(invalidated.externalSessionId == firstSession.externalSessionId)
        #expect(invalidated.sessionScopeHash == firstSession.sessionScopeHash)
        #expect(invalidated.redactedAt == nil)
        let invalidReplay = try fixture.db.pool.write { database in
            try sessionStore.closeOrInvalidate(
                sessionId: firstSession.id,
                expectedVersion: firstSession.version,
                disposition: .invalid,
                database: database,
                now: p1f1EngineTestNow.addingTimeInterval(11)
            )
        }
        #expect(invalidReplay == invalidated)
        #expect(throws: Error.self) {
            _ = try fixture.db.pool.write { database in
                try sessionStore.closeOrInvalidate(
                    sessionId: firstSession.id,
                    expectedVersion: firstSession.version,
                    disposition: .closed,
                    database: database,
                    now: p1f1EngineTestNow.addingTimeInterval(12)
                )
            }
        }

        let closed = try fixture.db.pool.write { database in
            try sessionStore.closeOrInvalidate(
                sessionId: secondSession.id,
                expectedVersion: secondSession.version,
                disposition: .closed,
                database: database,
                now: p1f1EngineTestNow.addingTimeInterval(10)
            )
        }
        #expect(closed.state == .closed)
        #expect(closed.version == secondSession.version + 1)
        #expect(closed.externalSessionId == secondSession.externalSessionId)
        #expect(closed.sessionScopeJson == secondSession.sessionScopeJson)
        #expect(closed.redactedAt == nil)
    }
}
