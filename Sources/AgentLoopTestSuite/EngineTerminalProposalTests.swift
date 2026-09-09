import Testing
import Foundation
import GRDB
import AgentLoopCore

private struct P1F1TerminalArtifactShape: Sendable, Equatable {
    let ordinal: Int
    let sourceRelativePath: String
    let kind: String
    let label: String
    let byteCount: Int
    let contentHash: String
}

private let p1f1TerminalArtifactA = P1F1TerminalArtifactShape(
    ordinal: 0,
    sourceRelativePath: "reports/result.md",
    kind: "report",
    label: "Result report",
    byteCount: 17,
    contentHash: p1f1EngineHashA
)

private let p1f1TerminalArtifactB = P1F1TerminalArtifactShape(
    ordinal: 1,
    sourceRelativePath: "logs/verify.txt",
    kind: "verification",
    label: "Verification log",
    byteCount: 29,
    contentHash: p1f1EngineHashB
)

private let p1f1TerminalArtifacts = [
    p1f1TerminalArtifactA,
    p1f1TerminalArtifactB,
]

private let p1f1TerminalProposalGolden = #"{"artifacts":[{"byteCount":17,"contentHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","kind":"report","label":"Result report","ordinal":0,"sourceRelativePath":"reports/result.md"},{"byteCount":29,"contentHash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","kind":"verification","label":"Verification log","ordinal":1,"sourceRelativePath":"logs/verify.txt"}],"cardId":"00000000-0000-4000-8000-000000000004","executionId":"10000000-0000-4000-8000-000000000001","payload":{"handoff":{"artifacts":[{"kind":"report","label":"Result report","relativePath":"reports/result.md"},{"kind":"verification","label":"Verification log","relativePath":"logs/verify.txt"}],"outcome":"implemented","risks":[],"summary":"engine-owned artifact proposal","verification":[{"method":"terminal-store","note":"atomic","passed":true}]},"kind":"completed"},"protocolVersion":"agentloop.execution.v1","runId":"20000000-0000-4000-8000-000000000001","sequence":0,"terminalIdempotencyKey":"p1f1-whole-proposal-terminal","terminalKind":"completed"}"#
private let p1f1TerminalProposalGoldenHash = "0b0d8f08d078ffe12b58634f601ef481189cbdb5a49b81ce2589b3fe62e6f6d8"

private func p1f1StartForTerminal(
    fixture: P1F1EngineFixture,
    key: String
) throws -> EngineExecutionRequest {
    let request = try fixture.begin(key: key)
    let prepared = try p1f1ExecutionRow(fixture.db, id: request.executionId)
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: request.executionId,
        expectedVersion: prepared["version"],
        requestHash: request.requestHash,
        commandIdempotencyKey: "\(key)-dispatch",
        now: p1f1EngineTestNow.addingTimeInterval(1)
    )
    return request
}

private func p1f1StandaloneTerminalReceipt(
    key: String = "p1f1-standalone-terminal-receipt",
    subtype: EngineTerminalSubtypeV1 = .ordinary,
    reasonCode: String = "dependency_blocked",
    eventIDs: [String]
) throws -> EngineTerminalCommitReceiptV1 {
    try EngineTerminalCommitReceiptV1(
        receiptIdempotencyKey: key,
        executionId: "10000000-0000-4000-8000-000000000001",
        proposalId: "30000000-0000-4000-8000-000000000001",
        proposalHash: p1f1EngineHashA,
        disposition: .committedProposal,
        terminalKind: .blocked,
        terminalSubtype: subtype,
        reasonCode: reasonCode,
        artifactIds: [],
        committedEventIds: eventIDs,
        finishedAt: p1f1EngineTestNow,
        terminalReceiptHash: p1f1EngineHashB
    )
}

private func p1f1ArtifactProposal(
    request: EngineExecutionRequest,
    key: String,
    sequence: Int = 0,
    declarations: [P1F1TerminalArtifactShape] = p1f1TerminalArtifacts,
    handoffDeclarations: [P1F1TerminalArtifactShape] = p1f1TerminalArtifacts
) throws -> EngineTerminalProposalContentV1 {
    try EngineTerminalProposalContentV1(
        protocolVersion: "agentloop.execution.v1",
        executionId: request.executionId,
        runId: request.runId,
        cardId: request.cardId,
        sequence: sequence,
        terminalIdempotencyKey: key,
        terminalKind: .completed,
        terminalSubtype: nil,
        payload: .completed(
            handoff: HandoffPayload(
                outcome: "implemented",
                summary: "engine-owned artifact proposal",
                artifacts: handoffDeclarations.sorted { $0.ordinal < $1.ordinal }.map {
                    HandoffPayload.ArtifactDecl(
                        relativePath: $0.sourceRelativePath,
                        kind: $0.kind,
                        label: $0.label
                    )
                },
                verification: [
                    .init(method: "terminal-store", passed: true, note: "atomic"),
                ],
                risks: []
            )
        ),
        artifacts: declarations.map {
            .init(
                ordinal: $0.ordinal,
                sourceRelativePath: $0.sourceRelativePath,
                kind: $0.kind,
                label: $0.label,
                byteCount: $0.byteCount,
                contentHash: $0.contentHash
            )
        }
    )
}

private func p1f1TerminalProposalRows(
    _ db: AppDatabase,
    proposalID: String
) throws -> [Row] {
    try db.pool.read { database in
        try Row.fetchAll(
            database,
            sql: """
                SELECT artifactId,ordinal,sourceRelativePath,kind,label,
                       byteCount,contentHash,state
                FROM engine_proposal_artifact
                WHERE proposalId=?
                ORDER BY ordinal
                """,
            arguments: [proposalID]
        )
    }
}

private struct P1F1TerminalAtomicSnapshot: Equatable {
    let proposalState: String
    let proposalVersion: Int
    let executionState: String
    let dispatchState: String
    let executionVersion: Int
    let runOutcome: String?
    let runEndedAt: Date?
    let cardStatus: String
    let cardHandoffJSON: String?
    let missionStatus: String
    let legacyEvents: Int
    let domainEvents: Int
    let outbox: Int
    let receipts: Int
    let userRequests: Int
}

private func p1f1TerminalAtomicSnapshot(
    fixture: P1F1EngineFixture,
    request: EngineExecutionRequest,
    proposalID: String
) throws -> P1F1TerminalAtomicSnapshot {
    try fixture.db.pool.read { database in
        func count(_ table: String) throws -> Int {
            try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM \(table)") ?? -1
        }
        let proposal = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT state,version FROM engine_terminal_proposal WHERE id=?",
                arguments: [proposalID]
            )
        )
        let execution = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT state,dispatchState,version FROM engine_execution WHERE id=?",
                arguments: [request.executionId]
            )
        )
        let run = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT outcome,endedAt FROM run WHERE id=?",
                arguments: [request.runId]
            )
        )
        let card = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT status,handoffJson FROM card WHERE id=?",
                arguments: [request.cardId]
            )
        )
        let mission = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT status FROM mission WHERE id=?",
                arguments: [p1f1EngineMissionID]
            )
        )
        return try P1F1TerminalAtomicSnapshot(
            proposalState: proposal["state"],
            proposalVersion: proposal["version"],
            executionState: execution["state"],
            dispatchState: execution["dispatchState"],
            executionVersion: execution["version"],
            runOutcome: run["outcome"],
            runEndedAt: run["endedAt"],
            cardStatus: card["status"],
            cardHandoffJSON: card["handoffJson"],
            missionStatus: mission["status"],
            legacyEvents: count("event"),
            domainEvents: count("domain_event"),
            outbox: count("event_outbox"),
            receipts: count("domain_command_receipt"),
            userRequests: count("user_request")
        )
    }
}

@Suite(.serialized)
struct P1F1EngineTerminalProposalTests {
    @Test func p1f1_030WholeProposalCanonicalIdentityIncludesArtifacts() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-whole-proposal"
        )
        let proposal = try p1f1ArtifactProposal(
            request: request,
            key: "p1f1-whole-proposal-terminal",
            declarations: [p1f1TerminalArtifactB, p1f1TerminalArtifactA]
        )
        let canonicalBytes = try CanonicalJSONV1.encode(proposal)
        let canonicalJSON = String(decoding: canonicalBytes, as: UTF8.self)
        #expect(canonicalJSON == p1f1TerminalProposalGolden)
        #expect(CanonicalJSONV1.sha256Hex(canonicalBytes) == p1f1TerminalProposalGoldenHash)
        let object = try #require(
            JSONSerialization.jsonObject(with: canonicalBytes) as? [String: Any]
        )
        let artifacts = try #require(object["artifacts"] as? [[String: Any]])

        #expect(artifacts.count == 2)
        #expect((artifacts[0]["ordinal"] as? Int) == 0)
        #expect((artifacts[0]["sourceRelativePath"] as? String) == "reports/result.md")
        #expect((artifacts[0]["label"] as? String) == "Result report")
        #expect((artifacts[0]["byteCount"] as? Int) == 17)
        #expect((artifacts[0]["contentHash"] as? String) == p1f1EngineHashA)
        #expect((artifacts[1]["ordinal"] as? Int) == 1)
        #expect((artifacts[1]["sourceRelativePath"] as? String) == "logs/verify.txt")
        #expect((object["terminalKind"] as? String) == "completed")

        let recorded = try fixture.store.recordEngineTerminalProposal(proposal)
        let stored = try fixture.db.pool.read { database in
            try #require(
                try Row.fetchOne(
                    database,
                    sql: """
                        SELECT proposalJson,proposalHash,payloadHash,
                               artifactManifestHash
                        FROM engine_terminal_proposal WHERE id=?
                        """,
                    arguments: [recorded.proposal.id]
                )
            )
        }
        #expect((stored["proposalJson"] as String) == p1f1TerminalProposalGolden)
        #expect((stored["proposalHash"] as String) == p1f1TerminalProposalGoldenHash)
        #expect((stored["proposalHash"] as String) != (stored["payloadHash"] as String))
        #expect((stored["proposalHash"] as String) != (stored["artifactManifestHash"] as String))
        let normalized = try p1f1TerminalProposalRows(
            fixture.db,
            proposalID: recorded.proposal.id
        )
        #expect(normalized.map { $0["ordinal"] as Int } == [0, 1])
        #expect(normalized.map { $0["contentHash"] as String } == [
            p1f1EngineHashA,
            p1f1EngineHashB,
        ])

        let exactKeys = try #require(
            JSONSerialization.jsonObject(with: canonicalBytes) as? [String: Any]
        )
        #expect(Set(exactKeys.keys) == [
            "artifacts", "cardId", "executionId", "payload",
            "protocolVersion", "runId", "sequence",
            "terminalIdempotencyKey", "terminalKind",
        ])
        var extraKeyObject = exactKeys
        extraKeyObject["extra"] = true
        let extraKeyBytes = try JSONSerialization.data(
            withJSONObject: extraKeyObject,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        #expect(throws: Error.self) {
            _ = try CanonicalContractCodingV1.decode(
                EngineTerminalProposalContentV1.self,
                from: extraKeyBytes
            )
        }

        for invalidID in [
            "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            "not-a-canonical-uuid",
        ] {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: invalidID,
                    runId: request.runId,
                    cardId: request.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: "p1f1-invalid-id",
                    terminalKind: .failed,
                    terminalSubtype: nil,
                    payload: .failed(code: "adapter_failure", detail: "bounded"),
                    artifacts: []
                )
            }
        }
        for invalidKey in ["", " key", String(repeating: "k", count: 257)] {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: request.executionId,
                    runId: request.runId,
                    cardId: request.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: invalidKey,
                    terminalKind: .failed,
                    terminalSubtype: nil,
                    payload: .failed(code: "adapter_failure", detail: "bounded"),
                    artifacts: []
                )
            }
        }
        let invalidHashes = [
            String(repeating: "A", count: 64),
            String(repeating: "a", count: 63),
        ]
        for invalidHash in invalidHashes {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try p1f1ArtifactProposal(
                    request: request,
                    key: "p1f1-invalid-hash",
                    declarations: [
                        P1F1TerminalArtifactShape(
                            ordinal: 0,
                            sourceRelativePath: "reports/result.md",
                            kind: "report",
                            label: "Result report",
                            byteCount: 17,
                            contentHash: invalidHash
                        ),
                    ],
                    handoffDeclarations: [
                        P1F1TerminalArtifactShape(
                            ordinal: 0,
                            sourceRelativePath: "reports/result.md",
                            kind: "report",
                            label: "Result report",
                            byteCount: 17,
                            contentHash: invalidHash
                        ),
                    ]
                )
            }
        }

        let tooMany = (0...256).map { ordinal in
            P1F1TerminalArtifactShape(
                ordinal: ordinal,
                sourceRelativePath: "reports/\(ordinal).txt",
                kind: "report",
                label: "Report \(ordinal)",
                byteCount: ordinal,
                contentHash: p1f1EngineHashA
            )
        }
        #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
            _ = try p1f1ArtifactProposal(
                request: request,
                key: "p1f1-too-many-artifacts",
                declarations: tooMany,
                handoffDeclarations: tooMany
            )
        }
    }

    @Test func p1f1_031ProposalReplayReturnsGeneratedArtifactIds() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-proposal-replay"
        )
        let key = "p1f1-proposal-replay-terminal"
        let first = try fixture.store.recordEngineTerminalProposal(
            p1f1ArtifactProposal(
                request: request,
                key: key,
                declarations: [p1f1TerminalArtifactB, p1f1TerminalArtifactA]
            )
        )
        let firstRows = try p1f1TerminalProposalRows(
            fixture.db,
            proposalID: first.proposal.id
        )
        let firstIDs = firstRows.map { $0["artifactId"] as String }
        #expect(firstIDs == [
            "40000000-0000-4000-8000-000000000001",
            "40000000-0000-4000-8000-000000000002",
        ])
        #expect(firstRows.map { $0["state"] as String } == ["declared", "declared"])
        let proposalCommandKey = "engine.terminal-proposal.v1:\(key)"
        _ = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: proposalCommandKey,
            executionID: request.executionId,
            expectedCommandType: "engine.terminal-proposal-record.v1",
            expectedResultCode: "engine_terminal_proposed",
            expectedEventTypes: ["engine.terminal-proposed.v1"],
            expectedAuditCodes: ["engine_terminal_proposed"],
            expectedRefKinds: ["engineExecution", "engineTerminalProposal"],
            expectedHashKinds: [
                "commandPayload", "engineRequest", "engineTerminalProposal",
            ],
            expectedVersionKinds: [
                "engineExecutionProjection", "engineTerminalProposalProjection",
                "engineExecutionEvent",
            ],
            forbiddenSentinels: [
                "reports/result.md", "logs/verify.txt",
                "Result report", "Verification log",
            ]
        )
        let afterFirst = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )

        let replay = try fixture.store.recordEngineTerminalProposal(
            p1f1ArtifactProposal(
                request: request,
                key: key,
                declarations: [p1f1TerminalArtifactA, p1f1TerminalArtifactB]
            )
        )
        let replayRows = try p1f1TerminalProposalRows(
            fixture.db,
            proposalID: replay.proposal.id
        )
        #expect(replay.proposal.id == first.proposal.id)
        #expect(replayRows.map { $0["artifactId"] as String } == firstIDs)
        #expect(fixture.ids.count("artifact") == 2)
        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM engine_terminal_proposal")
        } == 1)
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == afterFirst)

        let fenced = try P1F1EngineFixture()
        let fencedRequest = try p1f1StartForTerminal(
            fixture: fenced,
            key: "p1f1-proposal-fenced"
        )
        try p1f1ApplyCampFence(.deleting, fixture: fenced)
        let fencedStable = try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        )
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try fenced.store.recordEngineTerminalProposal(
                p1f1ArtifactProposal(
                    request: fencedRequest,
                    key: "p1f1-proposal-fenced-terminal"
                )
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        ) == fencedStable)
    }

    @Test func p1f1_032TerminalKeyManifestAndOrdinalConflictMatrix() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-manifest-conflict"
        )
        let key = "p1f1-manifest-conflict-terminal"
        _ = try fixture.store.recordEngineTerminalProposal(
            p1f1ArtifactProposal(request: request, key: key)
        )
        let stable = try p1f1EngineSurfaceCounts(fixture.db)
        let variants: [[P1F1TerminalArtifactShape]] = [
            [
                P1F1TerminalArtifactShape(
                    ordinal: 0,
                    sourceRelativePath: "reports/result.md",
                    kind: "report",
                    label: "Result report",
                    byteCount: 18,
                    contentHash: p1f1EngineHashA
                ),
                p1f1TerminalArtifactB,
            ],
            [
                P1F1TerminalArtifactShape(
                    ordinal: 0,
                    sourceRelativePath: "reports/result.md",
                    kind: "report",
                    label: "Result report",
                    byteCount: 17,
                    contentHash: p1f1EngineHashC
                ),
                p1f1TerminalArtifactB,
            ],
            [
                P1F1TerminalArtifactShape(
                    ordinal: 0,
                    sourceRelativePath: "reports/renamed.md",
                    kind: "report",
                    label: "Result report",
                    byteCount: 17,
                    contentHash: p1f1EngineHashA
                ),
                p1f1TerminalArtifactB,
            ],
            [
                P1F1TerminalArtifactShape(
                    ordinal: 0,
                    sourceRelativePath: "reports/result.md",
                    kind: "report",
                    label: "Renamed report",
                    byteCount: 17,
                    contentHash: p1f1EngineHashA
                ),
                p1f1TerminalArtifactB,
            ],
            [
                P1F1TerminalArtifactShape(
                    ordinal: 1,
                    sourceRelativePath: "reports/result.md",
                    kind: "report",
                    label: "Result report",
                    byteCount: 17,
                    contentHash: p1f1EngineHashA
                ),
                P1F1TerminalArtifactShape(
                    ordinal: 0,
                    sourceRelativePath: "logs/verify.txt",
                    kind: "verification",
                    label: "Verification log",
                    byteCount: 29,
                    contentHash: p1f1EngineHashB
                ),
            ],
        ]
        for declarations in variants {
            #expect(throws: EngineTerminalConflictErrorV1.self) {
                _ = try fixture.store.recordEngineTerminalProposal(
                    p1f1ArtifactProposal(
                        request: request,
                        key: key,
                        declarations: declarations,
                        handoffDeclarations: declarations
                    )
                )
            }
            #expect(try p1f1EngineSurfaceCounts(fixture.db) == stable)
            #expect(fixture.ids.count("artifact") == 2)
        }
        #expect(throws: EngineTerminalConflictErrorV1.self) {
            _ = try fixture.store.recordEngineTerminalProposal(
                p1f1ArtifactProposal(
                    request: request,
                    key: "p1f1-manifest-conflict-second-key"
                )
            )
        }
        #expect(try p1f1EngineSurfaceCounts(fixture.db) == stable)

        let invalidOrdinals: [[P1F1TerminalArtifactShape]] = [
            [
                P1F1TerminalArtifactShape(
                    ordinal: -1,
                    sourceRelativePath: "reports/result.md",
                    kind: "report",
                    label: "Result report",
                    byteCount: 17,
                    contentHash: p1f1EngineHashA
                ),
            ],
            [p1f1TerminalArtifactA, p1f1TerminalArtifactA],
            [
                p1f1TerminalArtifactA,
                P1F1TerminalArtifactShape(
                    ordinal: 2,
                    sourceRelativePath: "logs/verify.txt",
                    kind: "verification",
                    label: "Verification log",
                    byteCount: 29,
                    contentHash: p1f1EngineHashB
                ),
            ],
        ]
        for declarations in invalidOrdinals {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try p1f1ArtifactProposal(
                    request: request,
                    key: "p1f1-invalid-ordinal",
                    declarations: declarations
                )
            }
            #expect(try p1f1EngineSurfaceCounts(fixture.db) == stable)
        }
        #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
            _ = try EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: request.executionId,
                runId: request.runId,
                cardId: request.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-empty-artifacts-no-reason",
                terminalKind: .completed,
                terminalSubtype: nil,
                payload: .completed(
                    handoff: HandoffPayload(
                        outcome: "implemented",
                        summary: "missing no-artifact reason",
                        artifacts: [],
                        noArtifactReason: nil,
                        verification: [],
                        risks: []
                    )
                ),
                artifacts: []
            )
        }
        #expect(try p1f1EngineSurfaceCounts(fixture.db) == stable)
    }

    @Test func p1f1_033CompletedTerminalCommitsAllProjectionsAtomically() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-completed-atomic"
        )
        let recorded = try fixture.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(
                request: request,
                key: "p1f1-completed-atomic-terminal"
            )
        )
        let before = try p1f1TerminalAtomicSnapshot(
            fixture: fixture,
            request: request,
            proposalID: recorded.proposal.id
        )
        let receipt = try fixture.store.commitEngineTerminal(
            proposalId: recorded.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        let after = try p1f1TerminalAtomicSnapshot(
            fixture: fixture,
            request: request,
            proposalID: recorded.proposal.id
        )

        #expect(receipt.disposition == .committedProposal)
        #expect(receipt.terminalKind == .completed)
        #expect(receipt.terminalSubtype == nil)
        #expect(receipt.artifactIds.isEmpty)
        #expect(Set(receipt.committedEventIds).count == receipt.committedEventIds.count)
        #expect(after.proposalState == "committed")
        #expect(after.proposalVersion == before.proposalVersion + 1)
        #expect(after.executionState == "completed")
        #expect(after.dispatchState == "terminal")
        #expect(after.runOutcome == "completed")
        #expect(after.runEndedAt != nil)
        #expect(after.cardStatus == "done")
        let handoffJSON = try #require(after.cardHandoffJSON)
        let handoff = try JSONDecoder().decode(
            HandoffPayload.self,
            from: Data(handoffJSON.utf8)
        )
        #expect(handoff.outcome == "implemented")
        #expect(handoff.artifacts.isEmpty)
        #expect(handoff.noArtifactReason == "F1B intentionally has no blob artifacts")
        #expect(after.missionStatus == "delivering")
        #expect(after.receipts == before.receipts + 1)
        // Card completion and the deterministic Mission rollup each emit their
        // established legacy compatibility event in the same transaction.
        #expect(after.legacyEvents == before.legacyEvents + 2)
        #expect(after.domainEvents == before.domainEvents + 1)
        #expect(after.outbox == before.outbox + 1)
        let graph = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: receipt.receiptIdempotencyKey,
            executionID: request.executionId,
            expectedCommandType: "engine.terminal-commit.v1",
            expectedResultCode: "engine_terminal_committed",
            expectedEventTypes: ["engine.terminal-committed.v1"],
            expectedAuditCodes: ["engine_terminal_committed"],
            expectedRefKinds: ["engineExecution", "engineTerminalProposal"],
            expectedHashKinds: [
                "commandPayload", "engineRequest", "engineTerminalProposal",
            ],
            expectedVersionKinds: [
                "engineExecutionProjection", "engineTerminalProposalProjection",
                "engineExecutionEvent",
            ],
            forbiddenSentinels: [
                "engine-owned completion",
                "F1B intentionally has no blob artifacts",
            ]
        )
        #expect(receipt.committedEventIds == graph.eventIDs)
        #expect(receipt.terminalReceiptHash == graph.resultHash)
        #expect(receipt.proposalHash != receipt.terminalReceiptHash)
        #expect((try p1f1ExecutionRow(
            fixture.db,
            id: request.executionId
        )["nextSequence"] as Int) == 1)
        #expect(try fixture.db.pool.read { database in
            let artifactCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM artifact"
            ) ?? -1
            let originCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM artifact_storage_origin"
            ) ?? -1
            let referenceCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM artifact_blob_reference"
            ) ?? -1
            return artifactCount + originCount + referenceCount
        } == 0)

        let fenced = try P1F1EngineFixture()
        let fencedRequest = try p1f1StartForTerminal(
            fixture: fenced,
            key: "p1f1-terminal-fenced"
        )
        let fencedProposal = try fenced.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(
                request: fencedRequest,
                key: "p1f1-terminal-fenced-key"
            )
        )
        try p1f1ApplyCampFence(.archived, fixture: fenced)
        let fencedStable = try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        )
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try fenced.store.commitEngineTerminal(
                proposalId: fencedProposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1EngineTestNow.addingTimeInterval(2)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        ) == fencedStable)
    }

    @Test func p1f1_034BlockedFailedCanceledTerminalTaxonomy() throws {
        let blocked = try P1F1EngineFixture()
        let blockedRequest = try p1f1StartForTerminal(
            fixture: blocked,
            key: "p1f1-taxonomy-blocked"
        )
        let blockedProposal = try EngineTerminalProposalContentV1(
            protocolVersion: "agentloop.execution.v1",
            executionId: blockedRequest.executionId,
            runId: blockedRequest.runId,
            cardId: blockedRequest.cardId,
            sequence: 0,
            terminalIdempotencyKey: "p1f1-taxonomy-blocked-terminal",
            terminalKind: .blocked,
            terminalSubtype: .ordinary,
            payload: .blocked(
                reasonCode: "dependency_blocked",
                detail: "bounded dependency is unavailable"
            ),
            artifacts: []
        )
        let blockedRecord = try blocked.store.recordEngineTerminalProposal(blockedProposal)
        let blockedReceipt = try blocked.store.commitEngineTerminal(
            proposalId: blockedRecord.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        #expect(blockedReceipt.terminalKind == .blocked)
        #expect(blockedReceipt.terminalSubtype == .ordinary)
        #expect(blockedReceipt.reasonCode == "dependency_blocked")
        #expect((try p1f1ExecutionRow(
            blocked.db,
            id: blockedRequest.executionId
        )["state"] as String) == "blocked")
        #expect(try blocked.db.card(id: blockedRequest.cardId)?.status == .blocked)

        let failed = try P1F1EngineFixture()
        let failedRequest = try p1f1StartForTerminal(
            fixture: failed,
            key: "p1f1-taxonomy-failed"
        )
        let failedRecord = try failed.store.recordEngineTerminalProposal(
            EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: failedRequest.executionId,
                runId: failedRequest.runId,
                cardId: failedRequest.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-taxonomy-failed-terminal",
                terminalKind: .failed,
                terminalSubtype: nil,
                payload: .failed(
                    code: "adapter_failure",
                    detail: "sanitized adapter failure"
                ),
                artifacts: []
            )
        )
        let failedReceipt = try failed.store.commitEngineTerminal(
            proposalId: failedRecord.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        #expect(failedReceipt.terminalKind == .failed)
        #expect(failedReceipt.terminalSubtype == nil)
        #expect(failedReceipt.reasonCode == "adapter_failure")
        #expect((try p1f1ExecutionRow(
            failed.db,
            id: failedRequest.executionId
        )["state"] as String) == "failed")

        let canceled = try P1F1EngineFixture()
        let canceledRequest = try p1f1StartForTerminal(
            fixture: canceled,
            key: "p1f1-taxonomy-canceled"
        )
        let canceledRecord = try canceled.store.recordEngineTerminalProposal(
            EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: canceledRequest.executionId,
                runId: canceledRequest.runId,
                cardId: canceledRequest.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-taxonomy-canceled-terminal",
                terminalKind: .canceled,
                terminalSubtype: nil,
                payload: .canceled(
                    reasonCode: "user_canceled",
                    detail: "user requested cancellation"
                ),
                artifacts: []
            )
        )
        let canceledReceipt = try canceled.store.commitEngineTerminal(
            proposalId: canceledRecord.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        #expect(canceledReceipt.terminalKind == .canceled)
        #expect(canceledReceipt.terminalSubtype == nil)
        #expect(canceledReceipt.reasonCode == "user_canceled")
        #expect((try p1f1ExecutionRow(
            canceled.db,
            id: canceledRequest.executionId
        )["state"] as String) == "canceled")
        #expect(try canceled.db.card(id: canceledRequest.cardId)?.status == .ready)

        let invalidTaxonomy: [(
            EngineTerminalKindV1,
            EngineTerminalSubtypeV1?,
            EngineTerminalPayloadV1
        )] = [
            (.completed, .ordinary, .completed(handoff: HandoffPayload(
                outcome: "implemented",
                summary: "invalid subtype",
                artifacts: [],
                noArtifactReason: "none",
                verification: [],
                risks: []
            ))),
            (.failed, .ordinary, .failed(code: "adapter_failure", detail: "bounded")),
            (.canceled, .engineProtocolError, .canceled(
                reasonCode: "user_cancel",
                detail: "bounded"
            )),
            (.blocked, nil, .blocked(reasonCode: "dependency", detail: "bounded")),
            (.blocked, .ordinary, .failed(code: "adapter_failure", detail: "bounded")),
            (.blocked, .needsHumanInput, .blocked(
                reasonCode: "needs_human_input",
                detail: "wrong payload"
            )),
        ]
        for (offset, variant) in invalidTaxonomy.enumerated() {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: canceledRequest.executionId,
                    runId: canceledRequest.runId,
                    cardId: canceledRequest.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: "p1f1-invalid-taxonomy-\(offset)",
                    terminalKind: variant.0,
                    terminalSubtype: variant.1,
                    payload: variant.2,
                    artifacts: []
                )
            }
        }
        let invalidCodes = [
            "", " blank", String(repeating: "r", count: 129),
        ]
        for (offset, code) in invalidCodes.enumerated() {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: canceledRequest.executionId,
                    runId: canceledRequest.runId,
                    cardId: canceledRequest.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: "p1f1-invalid-code-\(offset)",
                    terminalKind: .failed,
                    terminalSubtype: nil,
                    payload: .failed(code: code, detail: "bounded"),
                    artifacts: []
                )
            }
        }
        let invalidDetails = [
            "", " padded ", String(repeating: "d", count: 1001),
            String(repeating: "🐄", count: 1001),
        ]
        for (offset, detail) in invalidDetails.enumerated() {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: canceledRequest.executionId,
                    runId: canceledRequest.runId,
                    cardId: canceledRequest.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: "p1f1-invalid-detail-\(offset)",
                    terminalKind: .failed,
                    terminalSubtype: nil,
                    payload: .failed(code: "adapter_failure", detail: detail),
                    artifacts: []
                )
            }
        }

        let eventA = "60000000-0000-4000-8000-000000000001"
        let eventB = "60000000-0000-4000-8000-000000000002"
        #expect(throws: Error.self) {
            _ = try p1f1StandaloneTerminalReceipt(
                key: String(repeating: "k", count: 257),
                eventIDs: [eventA]
            )
        }
        #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
            _ = try p1f1StandaloneTerminalReceipt(eventIDs: [eventA, eventB])
        }
        #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
            _ = try p1f1StandaloneTerminalReceipt(
                subtype: .externalEffectUnknown,
                reasonCode: "external_effect_unknown",
                eventIDs: [eventA]
            )
        }
        let ordinaryReceipt = try p1f1StandaloneTerminalReceipt(
            eventIDs: [eventA]
        )
        let attentionReceipt = try p1f1StandaloneTerminalReceipt(
            subtype: .externalEffectUnknown,
            reasonCode: "external_effect_unknown",
            eventIDs: [eventA, eventB]
        )
        #expect(ordinaryReceipt.committedEventIds == [eventA])
        #expect(attentionReceipt.committedEventIds == [eventA, eventB])

        let sqlGuard = try P1F1EngineFixture()
        let sqlRequest = try p1f1StartForTerminal(
            fixture: sqlGuard,
            key: "p1f1-taxonomy-sql"
        )
        #expect(throws: DatabaseError.self) {
            try sqlGuard.db.pool.write { database in
                try database.execute(
                    sql: """
                        INSERT INTO engine_terminal_proposal(
                          id,executionId,terminalIdempotencyKey,sequence,
                          terminalKind,terminalSubtype,proposalJson,proposalHash,
                          payloadJson,payloadHash,artifactManifestJson,
                          artifactManifestHash,state,version,createdAt,
                          committedAt,invalidReason,invalidatedAt,redactedAt
                        ) VALUES (
                          'p1f1-waiting-proposal',?, 'p1f1-waiting-key',0,
                          'waitingForUser',NULL,'{}',?,'{}',?,'[]',?,
                          'pending',1,?,NULL,NULL,NULL,NULL
                        )
                        """,
                    arguments: [
                        sqlRequest.executionId,
                        p1f1EngineHashA,
                        p1f1EngineHashB,
                        p1f1EngineHashC,
                        p1f1EngineTestNow,
                    ]
                )
            }
        }
        #expect(try sqlGuard.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM engine_terminal_proposal")
        } == 0)
    }

    @Test func p1f1_035AskUserCommitsBlockedNeedsHumanInputAtomically() throws {
        let needsHumanEvent = "60000000-0000-4000-8000-000000000003"
        #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
            _ = try p1f1StandaloneTerminalReceipt(
                subtype: .needsHumanInput,
                reasonCode: "wrong_reason",
                eventIDs: [needsHumanEvent]
            )
        }
        let standaloneNeedsHuman = try p1f1StandaloneTerminalReceipt(
            subtype: .needsHumanInput,
            reasonCode: "needs_human_input",
            eventIDs: [needsHumanEvent]
        )
        #expect(standaloneNeedsHuman.reasonCode == "needs_human_input")

        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-ask-user"
        )
        let recorded = try fixture.store.recordEngineTerminalProposal(
            EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: request.executionId,
                runId: request.runId,
                cardId: request.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-ask-user-terminal",
                terminalKind: .blocked,
                terminalSubtype: .needsHumanInput,
                payload: .needsHumanInput(
                    kind: .choice,
                    prompt: "Choose the invariant to preserve",
                    options: ["preserve_atomicity", "reduce_scope"]
                ),
                artifacts: []
            )
        )
        let before = try p1f1TerminalAtomicSnapshot(
            fixture: fixture,
            request: request,
            proposalID: recorded.proposal.id
        )
        let receipt = try fixture.store.commitEngineAskUser(
            proposalId: recorded.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        let after = try p1f1TerminalAtomicSnapshot(
            fixture: fixture,
            request: request,
            proposalID: recorded.proposal.id
        )
        let userRequest = try fixture.db.pool.read { database in
            try #require(
                try UserRequestRecord
                    .filter(Column("cardId") == request.cardId)
                    .fetchOne(database)
            )
        }
        #expect(receipt.disposition == .committedProposal)
        #expect(receipt.terminalKind == .blocked)
        #expect(receipt.terminalSubtype == .needsHumanInput)
        #expect(receipt.reasonCode == "needs_human_input")
        #expect(userRequest.kind == .choice)
        #expect(userRequest.prompt == "Choose the invariant to preserve")
        #expect(userRequest.optionsJson == #"["preserve_atomicity","reduce_scope"]"#)
        #expect(userRequest.answerJson == nil)
        #expect(userRequest.lifecycleState == .open)
        #expect(after.userRequests == before.userRequests + 1)
        #expect(after.proposalState == "committed")
        #expect(after.executionState == "blocked")
        #expect(after.dispatchState == "terminal")
        #expect(after.runOutcome == "blocked")
        #expect(after.cardStatus == "blocked")
        #expect(after.receipts == before.receipts + 1)
        let askGraph = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: receipt.receiptIdempotencyKey,
            executionID: request.executionId,
            expectedCommandType: "engine.terminal-commit.v1",
            expectedResultCode: "engine_terminal_committed",
            expectedEventTypes: ["engine.terminal-committed.v1"],
            expectedAuditCodes: ["engine_terminal_committed"],
            expectedRefKinds: ["engineExecution", "engineTerminalProposal"],
            expectedHashKinds: ["commandPayload", "engineRequest", "engineTerminalProposal"],
            expectedVersionKinds: ["engineExecutionProjection", "engineTerminalProposalProjection", "engineExecutionEvent"],
            forbiddenSentinels: [
                "Choose the invariant to preserve",
                "preserve_atomicity", "reduce_scope",
            ]
        )
        #expect(receipt.committedEventIds == askGraph.eventIDs)
        #expect(receipt.terminalReceiptHash == askGraph.resultHash)

        let invalidRequests: [(UserRequestRecord.Kind, String, [String])] = [
            (.approval, "Approve tool", []),
            (.choice, "Choose", ["only_one"]),
            (.choice, "Choose", ["same", "same"]),
            (.choice, "Choose", (0..<7).map { "option_\($0)" }),
            (.confirm, "Confirm", ["unexpected"]),
            (.text, "Text", ["unexpected"]),
            (.choice, "", ["a", "b"]),
            (.choice, " padded ", ["a", "b"]),
            (.choice, "Choose", [String(repeating: "x", count: 257), "b"]),
        ]
        for (offset, invalid) in invalidRequests.enumerated() {
            #expect(throws: EngineTerminalProposalValidationErrorV1.self) {
                _ = try EngineTerminalProposalContentV1(
                    protocolVersion: "agentloop.execution.v1",
                    executionId: request.executionId,
                    runId: request.runId,
                    cardId: request.cardId,
                    sequence: 0,
                    terminalIdempotencyKey: "p1f1-invalid-ask-\(offset)",
                    terminalKind: .blocked,
                    terminalSubtype: .needsHumanInput,
                    payload: .needsHumanInput(
                        kind: invalid.0,
                        prompt: invalid.1,
                        options: invalid.2
                    ),
                    artifacts: []
                )
            }
        }

        let aborted = try P1F1EngineFixture()
        let abortedRequest = try p1f1StartForTerminal(
            fixture: aborted,
            key: "p1f1-ask-user-abort"
        )
        let abortedProposal = try aborted.store.recordEngineTerminalProposal(
            EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: abortedRequest.executionId,
                runId: abortedRequest.runId,
                cardId: abortedRequest.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-ask-user-abort-terminal",
                terminalKind: .blocked,
                terminalSubtype: .needsHumanInput,
                payload: .needsHumanInput(
                    kind: .text,
                    prompt: "Need one answer",
                    options: []
                ),
                artifacts: []
            )
        )
        let abortedBefore = try p1f1TerminalAtomicSnapshot(
            fixture: aborted,
            request: abortedRequest,
            proposalID: abortedProposal.proposal.id
        )
        try aborted.db.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER p1f1_abort_ask_user
                BEFORE INSERT ON user_request
                BEGIN SELECT RAISE(ABORT, 'p1f1 injected user request failure'); END
                """)
        }
        #expect(throws: DatabaseError.self) {
            _ = try aborted.store.commitEngineAskUser(
                proposalId: abortedProposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1EngineTestNow.addingTimeInterval(2)
            )
        }
        #expect(try p1f1TerminalAtomicSnapshot(
            fixture: aborted,
            request: abortedRequest,
            proposalID: abortedProposal.proposal.id
        ) == abortedBefore)
    }

    @Test func p1f1_036InvalidPreparationCommitsOneProtocolErrorReceipt() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-invalid-preparation"
        )
        let recorded = try fixture.store.recordEngineTerminalProposal(
            p1f1ArtifactProposal(
                request: request,
                key: "p1f1-invalid-preparation-terminal"
            )
        )
        let proposalVersion = try fixture.db.pool.read { database in
            try #require(
                try Int.fetchOne(
                    database,
                    sql: "SELECT version FROM engine_terminal_proposal WHERE id=?",
                    arguments: [recorded.proposal.id]
                )
            )
        }
        let failure = EngineTerminalPreparationFailure(
            reasonCode: "artifact_path_escape",
            detail: "normalized source escaped the execution workspace"
        )
        let receiptCountBefore = try p1f1EngineSurfaceCounts(fixture.db)
            .receipts
        let receipt = try fixture.store.invalidateProposalAndCommitProtocolError(
            proposalId: recorded.proposal.id,
            expectedVersion: proposalVersion,
            failure: failure,
            commandIdempotencyKey: "p1f1-invalid-preparation-command",
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        let proposal = try fixture.db.pool.read { database in
            try #require(
                try Row.fetchOne(
                    database,
                    sql: "SELECT state,invalidReason,invalidatedAt FROM engine_terminal_proposal WHERE id=?",
                    arguments: [recorded.proposal.id]
                )
            )
        }
        #expect(receipt.disposition == .invalidProtocolError)
        #expect(receipt.proposalId == recorded.proposal.id)
        #expect(receipt.proposalHash == recorded.proposal.proposalHash)
        #expect(receipt.terminalKind == .blocked)
        #expect(receipt.terminalSubtype == .engineProtocolError)
        #expect(receipt.reasonCode == "artifact_path_escape")
        #expect(receipt.artifactIds.isEmpty)
        #expect((proposal["state"] as String) == "invalid")
        #expect((proposal["invalidReason"] as String?) == "artifact_path_escape")
        #expect((proposal["invalidatedAt"] as Date?) != nil)
        let execution = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((execution["state"] as String) == "blocked")
        #expect((execution["terminalSubtype"] as String?) == "engineProtocolError")
        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM artifact")
        } == 0)
        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM domain_command_receipt")
        } == receiptCountBefore + 1)
        #expect(try fixture.db.pool.read {
            try Int.fetchOne(
                $0,
                sql: "SELECT COUNT(*) FROM attention_item WHERE level='urgent'"
            )
        } == 0)
        let attentionGraph = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: "p1f1-invalid-preparation-command",
            executionID: request.executionId,
            expectedCommandType: "engine.terminal-commit.v1",
            expectedResultCode: "engine_terminal_committed",
            expectedEventTypes: [
                "engine.terminal-committed.v1", "engine.attention-intent.v1",
            ],
            expectedAuditCodes: [
                "engine_terminal_committed", "engine_attention_intent",
            ],
            expectedRefKinds: ["engineExecution", "engineTerminalProposal"],
            expectedHashKinds: ["commandPayload", "engineRequest", "engineTerminalProposal"],
            expectedVersionKinds: ["engineExecutionProjection", "engineTerminalProposalProjection", "engineExecutionEvent"],
            forbiddenSentinels: [
                "artifact_path_escape",
                "normalized source escaped the execution workspace",
                "reports/result.md", "Result report",
            ]
        )
        #expect(receipt.committedEventIds == attentionGraph.eventIDs)
        #expect(receipt.terminalReceiptHash == attentionGraph.resultHash)
        #expect(attentionGraph.aggregateVersions.count == 2)
        #expect((try p1f1ExecutionRow(
            fixture.db,
            id: request.executionId
        )["nextSequence"] as Int) == 1)

        let replay = try fixture.store.invalidateProposalAndCommitProtocolError(
            proposalId: recorded.proposal.id,
            expectedVersion: proposalVersion,
            failure: failure,
            commandIdempotencyKey: "p1f1-invalid-preparation-command",
            now: p1f1EngineTestNow.addingTimeInterval(3)
        )
        #expect(replay == receipt)
        #expect(throws: EngineTerminalConflictErrorV1.self) {
            _ = try fixture.store.invalidateProposalAndCommitProtocolError(
                proposalId: recorded.proposal.id,
                expectedVersion: proposalVersion,
                failure: EngineTerminalPreparationFailure(
                    reasonCode: "artifact_hash_mismatch",
                    detail: "different deterministic failure"
                ),
                commandIdempotencyKey: "p1f1-invalid-preparation-command",
                now: p1f1EngineTestNow.addingTimeInterval(4)
            )
        }
        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM domain_command_receipt")
        } == receiptCountBefore + 1)
    }

    @Test func p1f1_037TerminalMutationFailureRollsBackEveryProjection() throws {
        let injectedMutations: [(String, String)] = [
            ("proposal", "BEFORE UPDATE OF state ON engine_terminal_proposal"),
            ("execution", "BEFORE UPDATE OF state ON engine_execution"),
            ("run", "BEFORE UPDATE OF outcome ON run"),
            ("card", "BEFORE UPDATE OF status ON card"),
            ("mission", "BEFORE UPDATE OF status ON mission"),
            ("legacy_event", "BEFORE INSERT ON event"),
            ("domain_event", "BEFORE INSERT ON domain_event"),
            ("outbox", "BEFORE INSERT ON event_outbox"),
            ("receipt", "BEFORE INSERT ON domain_command_receipt"),
        ]

        for (offset, injection) in injectedMutations.enumerated() {
            let fixture = try P1F1EngineFixture()
            let request = try p1f1StartForTerminal(
                fixture: fixture,
                key: "p1f1-terminal-rollback-\(offset)"
            )
            let recorded = try fixture.store.recordEngineTerminalProposal(
                p1f1TerminalCompletedProposal(
                    request: request,
                    key: "p1f1-terminal-rollback-terminal-\(offset)"
                )
            )
            let before = try p1f1TerminalAtomicSnapshot(
                fixture: fixture,
                request: request,
                proposalID: recorded.proposal.id
            )
            try fixture.db.pool.write { database in
                try database.execute(sql: """
                    CREATE TRIGGER p1f1_abort_terminal_\(offset)
                    \(injection.1)
                    BEGIN SELECT RAISE(ABORT, 'p1f1 injected \(injection.0) failure'); END
                    """)
            }
            do {
                _ = try fixture.store.commitEngineTerminal(
                    proposalId: recorded.proposal.id,
                    checkedUsage: .zero,
                    now: p1f1EngineTestNow.addingTimeInterval(2)
                )
                Issue.record("terminal mutation injection unexpectedly succeeded")
            } catch let error as DatabaseError {
                #expect(String(describing: error).contains(
                    "p1f1 injected \(injection.0) failure"
                ))
            } catch {
                Issue.record("unexpected terminal mutation error: \(error)")
            }
            #expect(try p1f1TerminalAtomicSnapshot(
                fixture: fixture,
                request: request,
                proposalID: recorded.proposal.id
            ) == before)
        }
    }

    @Test func p1f1_038DuplicateTerminalReplaysAndSecondTerminalRejects() throws {
        let fixture = try P1F1EngineFixture()
        let request = try p1f1StartForTerminal(
            fixture: fixture,
            key: "p1f1-terminal-exactly-once"
        )
        let content = try p1f1TerminalCompletedProposal(
            request: request,
            key: "p1f1-terminal-exactly-once-key"
        )
        let recorded = try fixture.store.recordEngineTerminalProposal(content)
        let receipt = try fixture.store.commitEngineTerminal(
            proposalId: recorded.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        let stable = try p1f1TerminalAtomicSnapshot(
            fixture: fixture,
            request: request,
            proposalID: recorded.proposal.id
        )

        try p1f1ApplyCampFence(.deletionRequested, fixture: fixture)
        let proposalReplay = try fixture.store.recordEngineTerminalProposal(content)
        let receiptReplay = try fixture.store.commitEngineTerminal(
            proposalId: proposalReplay.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(3)
        )
        #expect(proposalReplay.proposal.id == recorded.proposal.id)
        #expect(receiptReplay == receipt)
        #expect(try p1f1TerminalAtomicSnapshot(
            fixture: fixture,
            request: request,
            proposalID: recorded.proposal.id
        ) == stable)

        let conflicts = try [
            EngineTerminalProposalContentV1(
                protocolVersion: "agentloop.execution.v1",
                executionId: request.executionId,
                runId: request.runId,
                cardId: request.cardId,
                sequence: 0,
                terminalIdempotencyKey: "p1f1-terminal-second-key",
                terminalKind: .failed,
                terminalSubtype: nil,
                payload: .failed(
                    code: "late_failure",
                    detail: "must not overwrite completion"
                ),
                artifacts: []
            ),
            p1f1TerminalCompletedProposal(
                request: request,
                key: "p1f1-terminal-exactly-once-key",
                sequence: 1
            ),
        ]
        for conflict in conflicts {
            #expect(throws: EngineTerminalConflictErrorV1.self) {
                _ = try fixture.store.recordEngineTerminalProposal(conflict)
            }
            #expect(try p1f1TerminalAtomicSnapshot(
                fixture: fixture,
                request: request,
                proposalID: recorded.proposal.id
            ) == stable)
        }
        #expect(fixture.ids.count("proposal") == 1)
        #expect(try fixture.db.pool.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM domain_command_receipt")
        } == stable.receipts)

        let tampered = try P1F1EngineFixture()
        let tamperedRequest = try p1f1StartForTerminal(
            fixture: tampered,
            key: "p1f1-terminal-graph-tamper"
        )
        let tamperedProposal = try tampered.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(
                request: tamperedRequest,
                key: "p1f1-terminal-graph-tamper-key"
            )
        )
        let tamperedReceipt = try tampered.store.commitEngineTerminal(
            proposalId: tamperedProposal.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        try tampered.db.pool.write { database in
            try database.execute(
                sql: "DROP TRIGGER domain_event_reject_update"
            )
            try database.execute(
                sql: """
                    UPDATE domain_event SET payloadHash=?
                    WHERE commandIdempotencyKey=? AND eventOrdinal=0
                    """,
                arguments: [p1f1EngineHashF, tamperedReceipt.receiptIdempotencyKey]
            )
        }
        let tamperedStable = try p1f1EngineProjectionSnapshot(
            fixture: tampered,
            executionID: tamperedRequest.executionId,
            runID: tamperedRequest.runId
        )
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try tampered.store.commitEngineTerminal(
                proposalId: tamperedProposal.proposal.id,
                checkedUsage: .zero,
                now: p1f1EngineTestNow.addingTimeInterval(3)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: tampered,
            executionID: tamperedRequest.executionId,
            runID: tamperedRequest.runId
        ) == tamperedStable)
    }
}
