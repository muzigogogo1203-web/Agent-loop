import Testing
import Foundation
import Darwin
import GRDB
import AgentLoopCore

func p1f1CanonicalDirectoryURL(_ descriptor: Int32) throws -> URL {
    guard descriptor >= 0 else {
        throw EngineContextValidationErrorV1()
    }
    var pathBytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    guard Darwin.fcntl(descriptor, F_GETPATH, &pathBytes) == 0 else {
        throw EngineContextValidationErrorV1()
    }
    let path = String(cString: pathBytes)
    let url = URL(fileURLWithPath: path, isDirectory: true)
    guard url.path == path else {
        throw EngineContextValidationErrorV1()
    }
    return url
}

let p1f1EngineTestNow = Date(timeIntervalSince1970: 4_000_000)
let p1f1EngineCampID = "00000000-0000-4000-8000-000000000001"
let p1f1EngineGoalID = "00000000-0000-4000-8000-000000000002"
let p1f1EngineMissionID = "00000000-0000-4000-8000-000000000003"
let p1f1EngineCardID = "00000000-0000-4000-8000-000000000004"
let p1f1EngineContractID = "00000000-0000-4000-8000-000000000005"
let p1f1EngineProfileID = "00000000-0000-4000-8000-000000000006"
let p1f1EngineGrantA = "00000000-0000-4000-8000-000000000007"
let p1f1EngineGrantB = "00000000-0000-4000-8000-000000000008"
let p1f1EngineGrantC = "00000000-0000-4000-8000-000000000009"
let p1f1EngineHashA = String(repeating: "a", count: 64)
let p1f1EngineHashB = String(repeating: "b", count: 64)
let p1f1EngineHashC = String(repeating: "c", count: 64)
let p1f1EngineHashD = String(repeating: "d", count: 64)
let p1f1EngineHashE = String(repeating: "e", count: 64)
let p1f1EngineHashF = String(repeating: "f", count: 64)
let p1f1EngineWorkspaceHash = String(repeating: "9", count: 64)

let p1f1ContextGolden = #"{"campId":"00000000-0000-4000-8000-000000000001","cardId":"00000000-0000-4000-8000-000000000004","goalId":"00000000-0000-4000-8000-000000000002","inputRefs":[{"hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","id":"00000000-0000-4000-8000-000000000010","type":"input","version":2}],"instructionBlocks":[{"hash":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","id":"00000000-0000-4000-8000-000000000016","type":"instruction","version":1}],"memoryRefs":[{"hash":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","id":"00000000-0000-4000-8000-000000000011","type":"memory","version":3},{"hash":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","id":"00000000-0000-4000-8000-000000000012","type":"memory","version":1}],"missionId":"00000000-0000-4000-8000-000000000003","outcomeContract":{"hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","id":"00000000-0000-4000-8000-000000000005","version":7},"priorHandoffRefs":[{"hash":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","id":"00000000-0000-4000-8000-000000000015","type":"handoff","version":4}],"resourceRefs":[{"hash":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","id":"00000000-0000-4000-8000-000000000014","type":"resource","version":1}],"schemaVersion":1}"#
let p1f1ContextGoldenHash = "af5055018c39fbfed55641f5a5e3c6f04b5216b7cff1a748ebaa467d198493b3"
let p1f1ScopeGolden = #"{"adapterId":"adapter.codex","adapterVersion":"1.2.3","campId":"00000000-0000-4000-8000-000000000001","contractHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","contractId":"00000000-0000-4000-8000-000000000005","contractVersion":7,"engineKind":"cli","model":"gpt-test","profileId":"00000000-0000-4000-8000-000000000006","schemaVersion":1,"workspaceHash":"9999999999999999999999999999999999999999999999999999999999999999"}"#
let p1f1ScopeGoldenHash = "8104094ecce6b2b3cdbcc17461f25d7fe53f64a6a2cfab04d27aed7b459c3e02"

final class P1F1DeterministicIDs: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    func next(_ kind: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        let next = (counts[kind] ?? 0) + 1
        counts[kind] = next
        let namespace: Int
        switch kind {
        case "execution": namespace = 1
        case "run": namespace = 2
        case "proposal": namespace = 3
        case "artifact": namespace = 4
        case "event": namespace = 5
        case "user-request": namespace = 6
        case "session": namespace = 7
        default: namespace = 9
        }
        return String(
            format: "%d0000000-0000-4000-8000-%012d",
            namespace,
            next
        )
    }

    func count(_ kind: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[kind] ?? 0
    }
}

final class P1F1DispatchProbeAdapter: ExecutionEngineAdapter, @unchecked Sendable {
    private let lock = NSLock()
    private let engineDescriptor: ExecutionEngineDescriptor
    private var starts = 0

    init(descriptor: ExecutionEngineDescriptor) {
        self.engineDescriptor = descriptor
    }

    func descriptor(profile: RuntimeProfileRecord) throws -> ExecutionEngineDescriptor {
        engineDescriptor
    }

    func execute(
        request: EngineExecutionRequest
    ) -> AsyncThrowingStream<EngineExecutionEventPayloadV1, Error> {
        lock.lock()
        starts += 1
        lock.unlock()
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel(executionId: String) async throws {}

    var executeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return starts
    }
}

func p1f1ExecutionDescriptor(
    replayClass: EngineExecutionReplayClassV1 = .idempotencyKeyed,
    sessionResume: EngineCapabilitySupportV1 = .supported,
    profileKind: RuntimeProfileKind = .cliCodex,
    adapterId: String = "adapter.codex",
    adapterVersion: String = "1.2.3"
) -> ExecutionEngineDescriptor {
    ExecutionEngineDescriptor(
        adapterId: adapterId,
        adapterVersion: adapterVersion,
        profileKind: profileKind,
        streamingProgress: .supported,
        boardTerminal: .supported,
        toolBridge: .supported,
        cancellation: .supported,
        sessionResume: sessionResume,
        usageMetering: .supported,
        workspaceRead: .supported,
        workspaceWrite: .supported,
        network: .conditional(reasonCode: "grant_required"),
        replayClassResolver: { _ in replayClass }
    )
}

func p1f1ContextReferences(
    memoryHash: String = p1f1EngineHashC
) throws -> EngineContextReferencesV1 {
    try EngineContextReferencesV1(
        inputRefs: [
            EngineContextReferenceV1(
                type: "input",
                id: "00000000-0000-4000-8000-000000000010",
                version: 2,
                hash: p1f1EngineHashB
            ),
        ],
        memoryRefs: [
            EngineContextReferenceV1(
                type: "memory",
                id: "00000000-0000-4000-8000-000000000012",
                version: 1,
                hash: p1f1EngineHashD
            ),
            EngineContextReferenceV1(
                type: "memory",
                id: "00000000-0000-4000-8000-000000000011",
                version: 3,
                hash: memoryHash
            ),
        ],
        resourceRefs: [
            EngineContextReferenceV1(
                type: "resource",
                id: "00000000-0000-4000-8000-000000000014",
                version: 1,
                hash: p1f1EngineHashE
            ),
        ],
        priorHandoffRefs: [
            EngineContextReferenceV1(
                type: "handoff",
                id: "00000000-0000-4000-8000-000000000015",
                version: 4,
                hash: p1f1EngineHashE
            ),
        ],
        instructionBlocks: [
            EngineContextReferenceV1(
                type: "instruction",
                id: "00000000-0000-4000-8000-000000000016",
                version: 1,
                hash: p1f1EngineHashF
            ),
        ]
    )
}

func p1f1ContextScope(
    campID: String = p1f1EngineCampID,
    cardID: String = p1f1EngineCardID,
    contractHash: String = p1f1EngineHashA
) throws -> EngineContextScopeV1 {
    try EngineContextScopeV1(
        campId: campID,
        goalId: p1f1EngineGoalID,
        missionId: p1f1EngineMissionID,
        cardId: cardID,
        outcomeContract: OutcomeContractRef(
            id: p1f1EngineContractID,
            version: 7,
            hash: contractHash
        )
    )
}

func p1f1ContextPacket(
    rolePrompt: String = "ship the requested change",
    cardDescription: String = "bounded engine task",
    references: EngineContextReferencesV1? = nil
) throws -> ContextPacket {
    ContextPacket(
        companionName: "测试牛",
        rolePrompt: rolePrompt,
        cardTitle: "Engine card",
        cardDescription: cardDescription,
        expectedOutput: "verified result",
        workspacePath: "/workspace",
        upstreamHandoffs: [],
        answeredRequests: [],
        campNotes: [],
        companionNotes: [],
        toolNames: [],
        engineContextReferences: try references ?? p1f1ContextReferences()
    )
}

func p1f1CanonicalEnvelope(
    campID: String = p1f1EngineCampID,
    cardID: String = p1f1EngineCardID,
    contractHash: String = p1f1EngineHashA,
    memoryHash: String = p1f1EngineHashC
) throws -> EngineContextEnvelopeV1 {
    try EngineContextEnvelopeV1.from(
        packet: p1f1ContextPacket(
            references: p1f1ContextReferences(memoryHash: memoryHash)
        ),
        scope: p1f1ContextScope(
            campID: campID,
            cardID: cardID,
            contractHash: contractHash
        )
    )
}

struct P1F1EngineSurfaceCounts: Equatable {
    let executions: Int
    let runs: Int
    let legacyEvents: Int
    let domainEvents: Int
    let eventScopes: Int
    let outbox: Int
    let receipts: Int
    let proposals: Int
    let proposalArtifacts: Int
    let sessions: Int
    let userRequests: Int
}

struct P1F1SafeCommandGraph {
    let result: CampSafeCommandResultV1
    let resultHash: String
    let receiptCreatedAt: Date
    let eventIDs: [String]
    let aggregateVersions: [Int]
}

struct P1F1EngineProjectionSnapshot: Equatable {
    let surfaces: P1F1EngineSurfaceCounts
    let execution: EngineExecutionRecord?
    let proposals: [EngineTerminalProposalRecord]
    let proposalArtifacts: [EngineProposalArtifactRecord]
    let sessions: [EngineSessionRecord]
    let cardStatus: String
    let cardHandoffJSON: String?
    let runOutcome: String?
    let runEndedAt: Date?
    let missionStatus: String
    let missionSpentTokens: Int
}

enum P1F1CampFenceMutation: CaseIterable {
    case lifecycleVersionDrift
    case archived
    case deletionRequested
    case deleting
    case deletedTombstone
    case legacyArchived
}

func p1f1EngineProjectionSnapshot(
    fixture: P1F1EngineFixture,
    executionID: String? = nil,
    cardID: String = p1f1EngineCardID,
    runID: String? = nil
) throws -> P1F1EngineProjectionSnapshot {
    try fixture.db.pool.read { database in
        func count(_ table: String) throws -> Int {
            try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM \(table)") ?? -1
        }
        let card = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT status,handoffJson FROM card WHERE id=?",
                arguments: [cardID]
            )
        )
        let mission = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT status,spentTokens FROM mission WHERE id=?",
                arguments: [p1f1EngineMissionID]
            )
        )
        let run: Row? = if let runID {
            try Row.fetchOne(
                database,
                sql: "SELECT outcome,endedAt FROM run WHERE id=?",
                arguments: [runID]
            )
        } else {
            nil
        }
        return P1F1EngineProjectionSnapshot(
            surfaces: try P1F1EngineSurfaceCounts(
                executions: count("engine_execution"),
                runs: count("run"),
                legacyEvents: count("event"),
                domainEvents: count("domain_event"),
                eventScopes: count("camp_event_scope"),
                outbox: count("event_outbox"),
                receipts: count("domain_command_receipt"),
                proposals: count("engine_terminal_proposal"),
                proposalArtifacts: count("engine_proposal_artifact"),
                sessions: count("engine_session"),
                userRequests: count("user_request")
            ),
            execution: try executionID.flatMap {
                try EngineExecutionRecord.fetchOne(database, key: $0)
            },
            proposals: try EngineTerminalProposalRecord
                .order(Column("id"))
                .fetchAll(database),
            proposalArtifacts: try EngineProposalArtifactRecord
                .order(Column("id"))
                .fetchAll(database),
            sessions: try EngineSessionRecord.order(Column("id")).fetchAll(database),
            cardStatus: card["status"],
            cardHandoffJSON: card["handoffJson"],
            runOutcome: run?["outcome"],
            runEndedAt: run?["endedAt"],
            missionStatus: mission["status"],
            missionSpentTokens: mission["spentTokens"]
        )
    }
}

func p1f1ApplyCampFence(
    _ mutation: P1F1CampFenceMutation,
    fixture: P1F1EngineFixture
) throws {
    try fixture.db.pool.write { database in
        switch mutation {
        case .lifecycleVersionDrift:
            try database.execute(
                sql: "UPDATE camp_lifecycle SET version=version+1,updatedAt=? WHERE campId=?",
                arguments: [p1f1EngineTestNow.addingTimeInterval(20), p1f1EngineCampID]
            )
        case .archived:
            try database.execute(
                sql: "UPDATE camp_lifecycle SET state='archived',updatedAt=? WHERE campId=?",
                arguments: [p1f1EngineTestNow.addingTimeInterval(20), p1f1EngineCampID]
            )
        case .deletionRequested, .deleting:
            try database.execute(
                sql: """
                    UPDATE camp_lifecycle
                    SET state=?,updatedAt=?,deletionRequestedAt=?,deletedAt=NULL
                    WHERE campId=?
                    """,
                arguments: [
                    mutation == .deletionRequested ? "deletionRequested" : "deleting",
                    p1f1EngineTestNow.addingTimeInterval(20),
                    p1f1EngineTestNow.addingTimeInterval(20),
                    p1f1EngineCampID,
                ]
            )
        case .deletedTombstone:
            try database.execute(
                sql: """
                    UPDATE camp_lifecycle
                    SET state='deletedTombstone',updatedAt=?,
                        deletionRequestedAt=?,deletedAt=?
                    WHERE campId=?
                    """,
                arguments: [
                    p1f1EngineTestNow.addingTimeInterval(20),
                    p1f1EngineTestNow.addingTimeInterval(20),
                    p1f1EngineTestNow.addingTimeInterval(21),
                    p1f1EngineCampID,
                ]
            )
        case .legacyArchived:
            try database.execute(
                sql: "UPDATE camp SET archived=1 WHERE id=?",
                arguments: [p1f1EngineCampID]
            )
        }
    }
}

private func p1f1AssertSafeObjectKeys(
    _ json: String,
    expected: Set<String>
) throws {
    let object = try #require(
        JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    #expect(Set(object.keys) == expected)
}

@discardableResult
func p1f1AssertSafeCommandGraph(
    fixture: P1F1EngineFixture,
    commandKey: String,
    executionID: String,
    expectedCommandType: String,
    expectedResultCode: String,
    expectedEventTypes: [String],
    expectedAuditCodes: [String],
    expectedRefKinds: [String] = ["engineExecution"],
    expectedHashKinds: [String] = ["commandPayload", "engineRequest"],
    expectedVersionKinds: [String] = [
        "engineExecutionProjection", "engineExecutionEvent",
    ],
    forbiddenSentinels: [String] = []
) throws -> P1F1SafeCommandGraph {
    try fixture.db.pool.read { database in
        let receipt = try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT * FROM domain_command_receipt WHERE idempotencyKey=?",
                arguments: [commandKey]
            )
        )
        let commandType: String = receipt["commandType"]
        let resultJSON: String = receipt["resultJson"]
        let resultHash: String = receipt["resultHash"]
        let createdAt: Date = receipt["createdAt"]
        let resultBytes = Data(resultJSON.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: resultBytes)
        #expect(commandType == expectedCommandType)
        #expect((receipt["eventCount"] as Int) == expectedEventTypes.count)
        #expect(CanonicalJSONV1.sha256Hex(resultBytes) == resultHash)
        let result = try CanonicalContractCodingV1.decode(
            CampSafeCommandResultV1.self,
            from: resultBytes
        )
        #expect(try CanonicalContractCodingV1.encode(result) == resultBytes)
        #expect(result.code.rawValue == expectedResultCode)
        #expect(result.refs.map { $0.kind.rawValue } == expectedRefKinds)
        #expect(result.hashes.map { $0.kind.rawValue } == expectedHashKinds)
        #expect(result.versions.map { $0.kind.rawValue } == expectedVersionKinds)
        #expect(result.counts.map { "\($0.kind.rawValue)=\($0.value)" } == [
            "domainEvent=\(expectedEventTypes.count)",
            "outbox=\(expectedEventTypes.count)",
        ])
        #expect(result.times.map { $0.kind.rawValue } == ["occurredAt"])
        try p1f1AssertSafeObjectKeys(
            resultJSON,
            expected: [
                "schemaVersion", "code", "refs", "hashes", "versions",
                "counts", "times",
            ]
        )

        let events = try Row.fetchAll(
            database,
            sql: """
                SELECT * FROM domain_event
                WHERE commandIdempotencyKey=? ORDER BY eventOrdinal
                """,
            arguments: [commandKey]
        )
        #expect(events.count == expectedEventTypes.count)
        var payloadJSONs: [String] = []
        var eventIDs: [String] = []
        var aggregateVersions: [Int] = []
        for (ordinal, event) in events.enumerated() {
            let eventID: String = event["id"]
            let aggregateType: String = event["aggregateType"]
            let aggregateID: String = event["aggregateId"]
            let payloadJSON: String = event["payloadJson"]
            let payloadHash: String = event["payloadHash"]
            let payloadBytes = Data(payloadJSON.utf8)
            let payload = try CanonicalContractCodingV1.decode(
                CampSafeAuditPayloadV1.self,
                from: payloadBytes
            )
            #expect((event["campId"] as String) == p1f1EngineCampID)
            #expect(aggregateType == "engine_execution")
            #expect(aggregateID == executionID)
            #expect((event["eventType"] as String) == expectedEventTypes[ordinal])
            #expect((event["eventOrdinal"] as Int) == ordinal)
            #expect((event["eventIdempotencyKey"] as String) ==
                "\(commandKey)#\(String(format: "%04d", ordinal)):engine_execution:\(executionID)")
            #expect((event["actorType"] as String) == "engine")
            #expect((event["actorId"] as String) == "engine:kernel:v1")
            #expect((event["deviceId"] as String?) == nil)
            #expect((event["causationId"] as String?) == nil)
            #expect((event["correlationId"] as String) == executionID)
            #expect(CanonicalJSONV1.sha256Hex(payloadBytes) == payloadHash)
            #expect(payload.code.rawValue == expectedAuditCodes[ordinal])
            #expect(payload.refs == result.refs)
            #expect(payload.hashes == result.hashes)
            #expect(payload.versions == result.versions)
            #expect(payload.counts == result.counts)
            #expect(payload.times == result.times)
            try p1f1AssertSafeObjectKeys(
                payloadJSON,
                expected: [
                    "schemaVersion", "code", "refs", "hashes", "versions",
                    "counts", "times",
                ]
            )
            let outbox = try #require(
                try Row.fetchOne(
                    database,
                    sql: "SELECT * FROM event_outbox WHERE eventId=?",
                    arguments: [eventID]
                )
            )
            #expect((outbox["state"] as String) == "pending")
            #expect((outbox["attempt"] as Int) == 0)
            #expect((outbox["version"] as Int) == 1)
            #expect((outbox["leaseOwner"] as String?) == nil)
            #expect((outbox["leaseExpiresAt"] as Date?) == nil)
            #expect((outbox["lastError"] as String?) == nil)
            eventIDs.append(eventID)
            aggregateVersions.append(event["aggregateVersion"])
            payloadJSONs.append(payloadJSON)
        }
        if aggregateVersions.count > 1 {
            #expect(zip(aggregateVersions, aggregateVersions.dropFirst())
                .allSatisfy { pair in pair.1 == pair.0 + 1 })
        }
        let safeJSON = ([resultJSON] + payloadJSONs).joined(separator: "\n")
        for sentinel in forbiddenSentinels {
            #expect(!safeJSON.contains(sentinel))
        }
        return P1F1SafeCommandGraph(
            result: result,
            resultHash: resultHash,
            receiptCreatedAt: createdAt,
            eventIDs: eventIDs,
            aggregateVersions: aggregateVersions
        )
    }
}

struct P1F1SyntheticTerminalGraph {
    let proposal: EngineTerminalProposalRecord
    let proposalContent: EngineTerminalProposalContentV1
    let proposalCommand: P1F1SafeCommandGraph
    let terminalCommand: P1F1SafeCommandGraph
}

@discardableResult
func p1f1AssertSyntheticTerminalGraph(
    fixture: P1F1EngineFixture,
    request: EngineExecutionRequest,
    terminalKey: String,
    expectedSequence: Int,
    expectedKind: EngineTerminalKindV1,
    expectedSubtype: EngineTerminalSubtypeV1?,
    expectedReasonCode: String,
    expectedDetail: String,
    attention: Bool,
    receipt: EngineTerminalCommitReceiptV1? = nil
) throws -> P1F1SyntheticTerminalGraph {
    let proposalKey = "engine.terminal-proposal.v1:\(terminalKey)"
    let commitKey = "engine.terminal.v1:\(terminalKey)"
    let proposal = try fixture.db.pool.read { database in
        try #require(
            try EngineTerminalProposalRecord
                .filter(Column("terminalIdempotencyKey") == terminalKey)
                .fetchOne(database)
        )
    }
    let proposalBytes = Data(proposal.proposalJson.utf8)
    try CanonicalJSONV1.validateCanonical(rawUTF8: proposalBytes)
    #expect(CanonicalJSONV1.sha256Hex(proposalBytes) == proposal.proposalHash)
    let content = try CanonicalContractCodingV1.decode(
        EngineTerminalProposalContentV1.self,
        from: proposalBytes
    )
    #expect(content.protocolVersion == "agentloop.execution.v1")
    #expect(content.executionId == request.executionId)
    #expect(content.runId == request.runId)
    #expect(content.cardId == request.cardId)
    #expect(content.sequence == expectedSequence)
    #expect(content.terminalIdempotencyKey == terminalKey)
    #expect(content.terminalKind == expectedKind)
    #expect(content.terminalSubtype == expectedSubtype)
    #expect(content.payload.reasonCode == expectedReasonCode)
    #expect(content.payload.detail == expectedDetail)
    #expect(content.artifacts.isEmpty)
    #expect(proposal.artifactManifestJson == "[]")
    #expect(proposal.state == .committed)
    #expect(proposal.version == 2)
    #expect(try fixture.db.pool.read { database in
        try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM engine_proposal_artifact WHERE proposalId=?",
            arguments: [proposal.id]
        )
    } == 0)

    let membershipRefs = ["engineExecution", "engineTerminalProposal"]
    let membershipHashes = [
        "commandPayload", "engineRequest", "engineTerminalProposal",
    ]
    let membershipVersions = [
        "engineExecutionProjection", "engineTerminalProposalProjection",
        "engineExecutionEvent",
    ]
    let forbidden = [
        expectedDetail,
        request.model,
        request.contextJson,
        request.workspace.reference,
    ]
    let proposalGraph = try p1f1AssertSafeCommandGraph(
        fixture: fixture,
        commandKey: proposalKey,
        executionID: request.executionId,
        expectedCommandType: "engine.terminal-proposal-record.v1",
        expectedResultCode: "engine_terminal_proposed",
        expectedEventTypes: ["engine.terminal-proposed.v1"],
        expectedAuditCodes: ["engine_terminal_proposed"],
        expectedRefKinds: membershipRefs,
        expectedHashKinds: membershipHashes,
        expectedVersionKinds: membershipVersions,
        forbiddenSentinels: forbidden
    )
    let terminalEventTypes = attention
        ? ["engine.terminal-committed.v1", "engine.attention-intent.v1"]
        : ["engine.terminal-committed.v1"]
    let terminalAuditCodes = attention
        ? ["engine_terminal_committed", "engine_attention_intent"]
        : ["engine_terminal_committed"]
    let terminalGraph = try p1f1AssertSafeCommandGraph(
        fixture: fixture,
        commandKey: commitKey,
        executionID: request.executionId,
        expectedCommandType: "engine.terminal-commit.v1",
        expectedResultCode: "engine_terminal_committed",
        expectedEventTypes: terminalEventTypes,
        expectedAuditCodes: terminalAuditCodes,
        expectedRefKinds: membershipRefs,
        expectedHashKinds: membershipHashes,
        expectedVersionKinds: membershipVersions,
        forbiddenSentinels: forbidden
    )
    let execution = try p1f1ExecutionRow(fixture.db, id: request.executionId)
    #expect((execution["terminalReceiptIdempotencyKey"] as String?) == commitKey)
    #expect((execution["terminalReceiptHash"] as String?) == terminalGraph.resultHash)
    #expect((execution["nextSequence"] as Int) == expectedSequence)
    if let receipt {
        #expect(receipt.receiptIdempotencyKey == commitKey)
        #expect(receipt.proposalId == proposal.id)
        #expect(receipt.proposalHash == proposal.proposalHash)
        #expect(receipt.disposition == .committedProposal)
        #expect(receipt.terminalKind == expectedKind)
        #expect(receipt.terminalSubtype == expectedSubtype)
        #expect(receipt.reasonCode == expectedReasonCode)
        #expect(receipt.artifactIds.isEmpty)
        #expect(receipt.committedEventIds == terminalGraph.eventIDs)
        #expect(receipt.terminalReceiptHash == terminalGraph.resultHash)
        #expect(receipt.proposalHash != receipt.terminalReceiptHash)
    }
    return P1F1SyntheticTerminalGraph(
        proposal: proposal,
        proposalContent: content,
        proposalCommand: proposalGraph,
        terminalCommand: terminalGraph
    )
}

func p1f1EngineSurfaceCounts(_ db: AppDatabase) throws -> P1F1EngineSurfaceCounts {
    try db.pool.read { database in
        func count(_ table: String) throws -> Int {
            try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM \(table)") ?? -1
        }
        return try P1F1EngineSurfaceCounts(
            executions: count("engine_execution"),
            runs: count("run"),
            legacyEvents: count("event"),
            domainEvents: count("domain_event"),
            eventScopes: count("camp_event_scope"),
            outbox: count("event_outbox"),
            receipts: count("domain_command_receipt"),
            proposals: count("engine_terminal_proposal"),
            proposalArtifacts: count("engine_proposal_artifact"),
            sessions: count("engine_session"),
            userRequests: count("user_request")
        )
    }
}

struct P1F1EngineFixture {
    let db: AppDatabase
    let store: EngineExecutionStore
    let ids: P1F1DeterministicIDs
    let descriptor: ExecutionEngineDescriptor

    init(
        replayClass: EngineExecutionReplayClassV1 = .idempotencyKeyed,
        sessionResume: EngineCapabilitySupportV1 = .supported
    ) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agentloop-p1f1-engine-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let db = try AppDatabase(
            path: directory.appendingPathComponent("engine.sqlite").path
        )
        let ids = P1F1DeterministicIDs()
        let descriptor = p1f1ExecutionDescriptor(
            replayClass: replayClass,
            sessionResume: sessionResume
        )
        try db.pool.write { database in
            try CampRecord(
                id: p1f1EngineCampID,
                name: "P1-F1 Engine Camp",
                createdAt: p1f1EngineTestNow
            ).insert(database)
            try database.execute(
                sql: """
                    INSERT INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?,'active',7,?,?,NULL,NULL)
                    """,
                arguments: [
                    p1f1EngineCampID,
                    p1f1EngineTestNow,
                    p1f1EngineTestNow,
                ]
            )
            try RuntimeProfileRecord(
                id: p1f1EngineProfileID,
                kind: .cliCodex,
                name: "P1-F1 Codex",
                baseURL: nil,
                credentialAccount: nil,
                isDefault: false,
                createdAt: p1f1EngineTestNow
            ).insert(database)
            try SquadRecord(
                id: "p1f1-engine-squad",
                campId: p1f1EngineCampID,
                name: "Engine Squad",
                memberIdsJson: "[]",
                workspacePath: "/workspace",
                workspaceBookmark: nil,
                createdAt: p1f1EngineTestNow
            ).insert(database)
            try MissionRecord(
                id: p1f1EngineMissionID,
                squadId: "p1f1-engine-squad",
                goalRaw: "deliver",
                goalRefined: "deliver",
                status: .executing,
                budgetTokens: 50_000,
                spentTokens: 0,
                revision: 1,
                createdAt: p1f1EngineTestNow
            ).insert(database)
            try CardRecord(
                id: p1f1EngineCardID,
                missionId: p1f1EngineMissionID,
                idemKey: "p1f1-engine-card-idem",
                title: "Engine card",
                descriptionText: "bounded engine task",
                expectedOutput: "verified result",
                assigneeId: nil,
                status: .ready,
                blockedReasonJson: nil,
                dependsOnJson: "[]",
                handoffJson: nil,
                stage: 1,
                maxTurns: 8,
                tokenBudget: 10_000,
                createdAt: p1f1EngineTestNow
            ).insert(database)
        }
        self.db = db
        self.ids = ids
        self.descriptor = descriptor
        self.store = EngineExecutionStore(
            database: db,
            descriptorResolver: { profile, _ in
                guard profile.kind == descriptor.profileKind else {
                    throw EngineDescriptorMismatchErrorV1()
                }
                return descriptor
            },
            clock: { p1f1EngineTestNow },
            executionIdFactory: { ids.next("execution") },
            runIdFactory: { ids.next("run") },
            proposalIdFactory: { ids.next("proposal") },
            artifactIdFactory: { ids.next("artifact") },
            eventIdFactory: { ids.next("event") },
            userRequestIdFactory: { ids.next("user-request") },
            sessionIdFactory: { ids.next("session") }
        )
    }

    func insertReadyCard(_ id: String, idemKey: String) throws {
        try db.pool.write { database in
            try CardRecord(
                id: id,
                missionId: p1f1EngineMissionID,
                idemKey: idemKey,
                title: "Engine card \(id)",
                descriptionText: "bounded engine task",
                expectedOutput: "verified result",
                assigneeId: nil,
                status: .ready,
                blockedReasonJson: nil,
                dependsOnJson: "[]",
                handoffJson: nil,
                stage: 1,
                maxTurns: 8,
                tokenBudget: 10_000,
                createdAt: p1f1EngineTestNow
            ).insert(database)
        }
    }

    func insertProfile(_ id: String) throws {
        try db.pool.write { database in
            try RuntimeProfileRecord(
                id: id,
                kind: .cliCodex,
                name: "Alternate profile",
                baseURL: nil,
                credentialAccount: nil,
                isDefault: false,
                createdAt: p1f1EngineTestNow
            ).insert(database)
        }
    }

    func fields(
        cardID: String = p1f1EngineCardID,
        campID: String = p1f1EngineCampID,
        contractHash: String = p1f1EngineHashA,
        profileID: String = p1f1EngineProfileID,
        model: String = "gpt-test",
        contextJson: String = p1f1ContextGolden,
        contextHash: String = p1f1ContextGoldenHash,
        grantIDs: [String] = [p1f1EngineGrantB, p1f1EngineGrantA],
        budget: EngineExecutionBudgetV1 = EngineExecutionBudgetV1(
            tokenLimit: 10_000,
            costMicrosLimit: 5_000_000,
            wallClockSeconds: 900
        ),
        workspace: EngineWorkspaceRefV1 = EngineWorkspaceRefV1(
            reference: "workspace:primary",
            hash: p1f1EngineWorkspaceHash
        ),
        sessionSelection: EngineSessionSelectionV1? = nil,
        claimedSessionScopeJson: String? = nil,
        claimedSessionScopeHash: String? = nil
    ) throws -> EngineExecutionRequestFieldsV1 {
        try EngineExecutionRequestFieldsV1(
            campId: campID,
            cardId: cardID,
            contract: OutcomeContractRef(
                id: p1f1EngineContractID,
                version: 7,
                hash: contractHash
            ),
            profileId: profileID,
            engineKind: "cli",
            model: model,
            contextJson: contextJson,
            contextHash: contextHash,
            requiredCapabilities: [
                .boardTerminal,
                .streamingProgress,
                .usageMetering,
            ],
            approvalGrantIds: grantIDs,
            budget: budget,
            workspace: workspace,
            sessionSelection: sessionSelection,
            claimedSessionScopeJson: claimedSessionScopeJson,
            claimedSessionScopeHash: claimedSessionScopeHash
        )
    }

    func begin(
        key: String = "p1f1-engine-begin",
        fields: EngineExecutionRequestFieldsV1? = nil
    ) throws -> EngineExecutionRequest {
        try store.beginEngineExecution(
            requestFields: fields ?? self.fields(),
            idempotencyKey: key
        )
    }
}

struct P1F1DCanonicalAnsweredRequestSeed: Sendable, Equatable {
    let id: String
    let kind: UserRequestRecord.Kind
    let prompt: String
    let optionsJSON: String?
    let answerJSON: String
    let createdAt: Date
    let answeredAt: Date

    static let first = P1F1DCanonicalAnsweredRequestSeed(
        id: "00000000-0000-4000-8000-000000000089",
        kind: .text,
        prompt: "Which exact value?",
        optionsJSON: nil,
        answerJSON: #"{"text":"alpha"}"#,
        createdAt: Date(timeIntervalSince1970: 4_000_100),
        answeredAt: Date(timeIntervalSince1970: 4_000_101)
    )

    static let second = P1F1DCanonicalAnsweredRequestSeed(
        id: "00000000-0000-4000-8000-000000000090",
        kind: .text,
        prompt: "Which second exact value?",
        optionsJSON: nil,
        answerJSON: #"{"text":"beta"}"#,
        createdAt: Date(timeIntervalSince1970: 4_000_102),
        answeredAt: Date(timeIntervalSince1970: 4_000_103)
    )
}

struct P1F1DCanonicalCardContextV1: Codable, Sendable, Equatable {
    let id: String
    let missionId: String
    let title: String
    let descriptionText: String
    let expectedOutput: String
    let dependsOnJson: String
    let maxTurns: Int
    let tokenBudget: Int
}

struct P1F1DCanonicalToolDefinitionV1: Codable, Sendable, Equatable {
    let name: String
    let description: String
    let inputSchema: JSONValue
}

struct P1F1DCanonicalCompanionContextV1: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let id: String
    let name: String
    let rolePrompt: String
    let toolsJson: String
    let toolDefinitions: [P1F1DCanonicalToolDefinitionV1]
}

struct P1F1DCanonicalInstructionContextV1: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let outcomeContract: OutcomeContractRef
    let autonomy: MissionAutonomy
    let contextPacketRenderVersion: Int
    let toolNames: [String]
}

struct P1F1DCanonicalToolBindingV2: Codable, Sendable, Equatable {
    let logicalName: String
    let providerVisibleName: String
}

struct P1F1DCanonicalInstructionContextV2: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let outcomeContract: OutcomeContractRef
    let autonomy: MissionAutonomy
    let contextPacketRenderVersion: Int
    let toolBindings: [P1F1DCanonicalToolBindingV2]
}

struct P1F1DCanonicalReferenceGoldens: Sendable, Equatable {
    let cardBytes: Data
    let answeredBytesByID: [String: Data]
    let companionBytes: Data
    let workspaceBytes: Data
    let instructionBytes: Data
    let references: EngineContextReferencesV1
}

struct P1F1DCanonicalExpectedContext: Sendable {
    let packet: ContextPacket
    let envelope: EngineContextEnvelopeV1
    let canonicalJSON: String
    let hash: String
    let contextRequest: EngineContextResolveRequestV1
    let workspaceRequest: EngineWorkspaceResolveRequestV1
    let workspaceReference: EngineWorkspaceRefV1
    let goldens: P1F1DCanonicalReferenceGoldens
}

enum P1F1DispatchContextFixtureError: Error, CustomStringConvertible {
    case missingRecord(table: String, id: String)
    case invalidMissionState(String)
    case inconsistentCamp
    case invalidSquadMembers

    var description: String {
        switch self {
        case let .missingRecord(table, id):
            return "Missing P1-F1 dispatch fixture record: \(table):\(id)"
        case let .invalidMissionState(state):
            return "P1-F1 dispatch fixture mission is not executing: \(state)"
        case .inconsistentCamp:
            return "P1-F1 dispatch fixture camp graph is inconsistent"
        case .invalidSquadMembers:
            return "P1-F1 dispatch fixture squad members are invalid"
        }
    }
}

@discardableResult
func attachP1F1DispatchContext(
    db: AppDatabase,
    missionId: String,
    companionId: String
) throws -> URL {
    let now = try P1DTimestampV1.canonical(Date())
    let workspaceURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "agentloop-p1f1-dispatch-\(UUID().uuidString)",
            isDirectory: true
        )
        .standardizedFileURL
    try FileManager.default.createDirectory(
        at: workspaceURL,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )

    let profile = RuntimeProfileRecord.new(
        kind: .openAIAPI,
        name: "P1-F1 dispatch fixture"
    )
    let graph = try db.pool.write { database in
        guard let mission = try MissionRecord.fetchOne(
            database,
            key: missionId
        ) else {
            throw P1F1DispatchContextFixtureError.missingRecord(
                table: MissionRecord.databaseTableName,
                id: missionId
            )
        }
        guard mission.status == .executing else {
            throw P1F1DispatchContextFixtureError.invalidMissionState(
                mission.status.rawValue
            )
        }
        guard var squad = try SquadRecord.fetchOne(
            database,
            key: mission.squadId
        ) else {
            throw P1F1DispatchContextFixtureError.missingRecord(
                table: SquadRecord.databaseTableName,
                id: mission.squadId
            )
        }
        guard let camp = try CampRecord.fetchOne(
            database,
            key: squad.campId
        ) else {
            throw P1F1DispatchContextFixtureError.missingRecord(
                table: CampRecord.databaseTableName,
                id: squad.campId
            )
        }
        guard var companion = try CompanionRecord.fetchOne(
            database,
            key: companionId
        ) else {
            throw P1F1DispatchContextFixtureError.missingRecord(
                table: CompanionRecord.databaseTableName,
                id: companionId
            )
        }
        guard companion.campId == camp.id else {
            throw P1F1DispatchContextFixtureError.inconsistentCamp
        }

        let memberData = Data(squad.memberIdsJson.utf8)
        var memberIDs: [String]
        do {
            memberIDs = try JSONDecoder().decode(
                [String].self,
                from: memberData
            )
        } catch {
            throw P1F1DispatchContextFixtureError.invalidSquadMembers
        }
        guard Set(memberIDs).count == memberIDs.count else {
            throw P1F1DispatchContextFixtureError.invalidSquadMembers
        }
        if !memberIDs.contains(companion.id) {
            memberIDs.append(companion.id)
        }

        companion.runtimeProfileId = profile.id
        companion.modelPolicy = .pinned
        squad.memberIdsJson = String(
            decoding: try CanonicalJSONV1.encode(memberIDs),
            as: UTF8.self
        )
        squad.workspacePath = workspaceURL.path
        squad.workspaceBookmark = nil

        try profile.insert(database)
        try companion.update(database)
        try squad.update(database)
        return (mission: mission, camp: camp)
    }

    let goalID = UUID().uuidString
    let contractID = UUID().uuidString
    let deviceID = UUID().uuidString
    let understanding = try UnderstandingCardVersionRecord(
        id: goalID,
        version: 1,
        goalId: goalID,
        content: UnderstandingContentV1(
            problem: "Complete the prepared card",
            scenario: "Coding Ranch",
            targetAudience: "Owner",
            goals: ["Complete the card"],
            nonGoals: ["Publish externally"],
            deliverables: ["Verified card result"],
            constraints: ["Use the local workspace"],
            acceptanceCriteria: ["The card reaches done"],
            verificationPlan: ["Run the deterministic test"],
            resourceRefs: [],
            requiredCapabilities: ["coding"],
            budgetPolicy: ["tokens": "10000"],
            assumptions: [],
            acceptedRisks: []
        ),
        status: .confirmed,
        createdByActorId: P1DActorID.coach,
        confirmedByActorId: P1DActorID.localOwner,
        confirmedAt: now,
        createdAt: now
    )
    let readyGoal = try GoalControllerRecord(
        id: goalID,
        campId: graph.camp.id,
        sourceInputId: nil,
        title: "Complete the prepared card",
        rawIntent: graph.mission.goalRaw,
        status: .ready,
        currentUnderstandingId: understanding.id,
        currentUnderstandingVersion: understanding.version,
        currentOutcomeContractId: nil,
        currentOutcomeContractVersion: nil,
        aggregateVersion: 1,
        createdByActorId: P1DActorID.localOwner,
        createdAt: now,
        updatedAt: now
    )
    try db.pool.write { database in
        try readyGoal.insert(database)
        try understanding.insert(database)
    }

    func envelope(
        _ suffix: String,
        actorType: DomainActorType,
        actorID: String
    ) throws -> CommandEnvelopeV1 {
        let key = "p1f1-dispatch:\(missionId):\(suffix)"
        return try CommandEnvelopeV1(
            idempotencyKey: key,
            actorType: actorType,
            actorId: actorID,
            deviceId: actorType == .user ? deviceID : nil,
            correlationId: "trace:\(key)",
            causationId: nil,
            occurredAt: now
        )
    }

    let requirement = try VerificationRequirementV1(
        requirementId: "p1f1-dispatch-tests",
        requirementVersion: 1,
        verifierType: .deterministic,
        verifierId: "system:verifier:tests:v1",
        method: .tests,
        ruleId: "rule:p1f1-dispatch-tests",
        ruleVersion: 1,
        config: ["command": .string("swift run RunTests")]
    )
    let body = try OutcomeContractBodyV1(
        outcomeType: "coding",
        deliverables: ["Verified card result"],
        acceptanceCriteria: ["The card reaches done"],
        verificationGroups: [
            VerificationRequirementGroupV1(
                groupId: "p1f1-dispatch-group",
                mode: .all,
                requirements: [requirement]
            ),
        ],
        unacceptableDeviations: ["Missing card result"],
        requiredDependencies: [],
        optionalDependencies: [],
        requiresSubjectiveJudgment: false,
        includesPublicRelease: false,
        includesPayment: false,
        includesDeletion: false,
        includesExternalSend: false,
        riskClass: .normal,
        acceptanceOwner: .user,
        acceptancePolicy: nil
    )
    let outcomeStore = OutcomeStore(database: db, clock: { now })
    let draft = try outcomeStore.createDraft(
        CreateOutcomeContractDraftCommandV1(
            envelope: try envelope(
                "contract-draft",
                actorType: .user,
                actorID: P1DActorID.localOwner
            ),
            contractId: contractID,
            goal: GoalHeadV1(
                goalId: readyGoal.id,
                campId: readyGoal.campId,
                expectedGoalVersion: readyGoal.aggregateVersion
            ),
            understanding: UnderstandingVersionRefV1(
                id: understanding.id,
                version: understanding.version,
                hash: understanding.contentHash
            ),
            body: body
        )
    )
    let contract = try outcomeStore.activateContract(
        ActivateOutcomeContractCommandV1(
            envelope: try envelope(
                "contract-activate",
                actorType: .system,
                actorID: P1DActorID.outcomeContract
            ),
            contract: draft.ref
        )
    )
    _ = try outcomeStore.activateGoal(
        ActivateGoalCommandV1(
            envelope: try envelope(
                "goal-activate",
                actorType: .user,
                actorID: P1DActorID.localOwner
            ),
            goal: GoalHeadV1(
                goalId: readyGoal.id,
                campId: readyGoal.campId,
                expectedGoalVersion: readyGoal.aggregateVersion
            ),
            contract: contract.ref,
            missionId: graph.mission.id,
            expectedLinkVersion: nil
        )
    )
    return workspaceURL
}

struct P1F1DCanonicalDescriptorAuthority: Sendable {
    let descriptor: ExecutionEngineDescriptor

    func callAsFunction(
        _ profile: RuntimeProfileRecord
    ) throws -> ExecutionEngineDescriptor {
        guard profile.kind == descriptor.profileKind else {
            throw EngineAdapterSelectionErrorV1.descriptorMismatch
        }
        return descriptor
    }

    func callAsFunction(
        _ profile: RuntimeProfileRecord,
        _ requiredCapabilities: [EngineCapabilityV1]
    ) throws -> ExecutionEngineDescriptor {
        let resolved = try callAsFunction(profile)
        for capability in Set(requiredCapabilities).sorted(by: {
            $0.rawValue < $1.rawValue
        }) {
            guard resolved.support(for: capability) == .supported else {
                throw EngineAdapterSelectionErrorV1
                    .unsupportedCapability(capability)
            }
        }
        return resolved
    }
}

final class P1F1DCanonicalExecutionFixture: @unchecked Sendable {
    static let campID = "00000000-0000-4000-8000-000000000081"
    static let squadID = "00000000-0000-4000-8000-000000000082"
    static let missionID = "00000000-0000-4000-8000-000000000083"
    static let cardID = "00000000-0000-4000-8000-000000000084"
    static let companionID = "00000000-0000-4000-8000-000000000085"
    static let profileID = "00000000-0000-4000-8000-000000000086"
    static let goalID = "00000000-0000-4000-8000-000000000087"
    static let contractID = "00000000-0000-4000-8000-000000000088"
    static let deviceID = "00000000-0000-4000-8000-000000000091"
    static let now = Date(timeIntervalSince1970: 4_000_000)

    let root: URL
    let workspaceURL: URL
    let db: AppDatabase
    let ids: P1F1DeterministicIDs
    let descriptor: ExecutionEngineDescriptor
    let descriptorAuthority: P1F1DCanonicalDescriptorAuthority
    let store: EngineExecutionStore
    let camp: CampRecord
    let squad: SquadRecord
    let mission: MissionRecord
    let card: CardRecord
    let companion: CompanionRecord
    let profile: RuntimeProfileRecord
    let goal: GoalControllerRecord
    let contract: OutcomeContractSnapshotV1

    init(
        replayClass: EngineExecutionReplayClassV1 = .nonReplayable,
        sessionResume: EngineCapabilitySupportV1 = .supported,
        answeredRequests: [P1F1DCanonicalAnsweredRequestSeed] = [],
        profileKind: RuntimeProfileKind = .cliCodex,
        toolsJson: String = ToolAccess.explicitJson(allow: []),
        autonomy: MissionAutonomy = .standard
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentloop-p1f1d-canonical-\(UUID().uuidString)"
            )
            .standardizedFileURL
        let workspaceURL = root.appendingPathComponent("workspace")
            .standardizedFileURL
        try FileManager.default.createDirectory(
            at: workspaceURL,
            withIntermediateDirectories: true
        )
        let db = try AppDatabase(
            path: root.appendingPathComponent("engine.sqlite").path
        )
        let profile = RuntimeProfileRecord(
            id: Self.profileID,
            kind: profileKind,
            name: "P1-F1D canonical Codex",
            baseURL: nil,
            credentialAccount: nil,
            isDefault: false,
            createdAt: Self.now
        )
        let camp = CampRecord(
            id: Self.campID,
            name: "P1-F1D Canonical Camp",
            createdAt: Self.now
        )
        let companion = CompanionRecord(
            id: Self.companionID,
            name: "Canonical Cow",
            color: "blue",
            rolePrompt: "Use only the canonical execution context.",
            model: "gpt-test",
            toolsJson: toolsJson,
            kind: .regular,
            campId: Self.campID,
            runtimeProfileId: Self.profileID,
            modelPolicy: .pinned,
            createdAt: Self.now
        )
        let memberIDsJSON = String(
            decoding: try CanonicalJSONV1.encode([Self.companionID]),
            as: UTF8.self
        )
        let squad = SquadRecord(
            id: Self.squadID,
            campId: Self.campID,
            name: "P1-F1D Canonical Squad",
            memberIdsJson: memberIDsJSON,
            workspacePath: workspaceURL.path,
            workspaceBookmark: nil,
            createdAt: Self.now
        )
        let mission = MissionRecord(
            id: Self.missionID,
            squadId: Self.squadID,
            goalRaw: "Deliver a canonical engine result",
            goalRefined: "Deliver a canonical engine result",
            status: .executing,
            budgetTokens: 50_000,
            spentTokens: 0,
            revision: 1,
            autonomy: autonomy,
            createdAt: Self.now
        )
        let card = CardRecord(
            id: Self.cardID,
            missionId: Self.missionID,
            idemKey: "p1f1d-canonical-card",
            title: "Canonical engine card",
            descriptionText: "Resolve the complete canonical graph.",
            expectedOutput: "One verified engine result",
            assigneeId: Self.companionID,
            status: .ready,
            blockedReasonJson: nil,
            dependsOnJson: "[]",
            handoffJson: nil,
            stage: 1,
            maxTurns: 8,
            tokenBudget: 10_000,
            createdAt: Self.now
        )
        let understanding = try UnderstandingCardVersionRecord(
            id: Self.goalID,
            version: 1,
            goalId: Self.goalID,
            content: UnderstandingContentV1(
                problem: "Need a canonical engine result",
                scenario: "Coding Ranch",
                targetAudience: "Owner",
                goals: ["Deliver the result"],
                nonGoals: ["Publish externally"],
                deliverables: ["Verified engine result"],
                constraints: ["Local workspace only"],
                acceptanceCriteria: ["Deterministic tests pass"],
                verificationPlan: ["Run the authoritative tests"],
                resourceRefs: [],
                requiredCapabilities: ["coding"],
                budgetPolicy: ["tokens": "10000"],
                assumptions: [],
                acceptedRisks: []
            ),
            status: .confirmed,
            createdByActorId: P1DActorID.coach,
            confirmedByActorId: P1DActorID.localOwner,
            confirmedAt: Self.now,
            createdAt: Self.now
        )
        let readyGoal = try GoalControllerRecord(
            id: Self.goalID,
            campId: Self.campID,
            sourceInputId: nil,
            title: "Canonical engine goal",
            rawIntent: "Deliver a canonical engine result",
            status: .ready,
            currentUnderstandingId: understanding.id,
            currentUnderstandingVersion: understanding.version,
            currentOutcomeContractId: nil,
            currentOutcomeContractVersion: nil,
            aggregateVersion: 1,
            createdByActorId: P1DActorID.localOwner,
            createdAt: Self.now,
            updatedAt: Self.now
        )
        try db.pool.write { database in
            try camp.insert(database)
            try database.execute(
                sql: """
                    INSERT INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?,'active',7,?,?,NULL,NULL)
                    """,
                arguments: [Self.campID, Self.now, Self.now]
            )
            try profile.insert(database)
            try companion.insert(database)
            try squad.insert(database)
            try mission.insert(database)
            try readyGoal.insert(database)
            try understanding.insert(database)
            try card.insert(database)
        }

        let requirement = try VerificationRequirementV1(
            requirementId: "p1f1d-canonical-tests",
            requirementVersion: 1,
            verifierType: .deterministic,
            verifierId: "system:verifier:tests:v1",
            method: .tests,
            ruleId: "rule:p1f1d-canonical-tests",
            ruleVersion: 1,
            config: ["command": .string("swift run RunTests")]
        )
        let body = try OutcomeContractBodyV1(
            outcomeType: "coding",
            deliverables: ["Verified engine result"],
            acceptanceCriteria: ["Deterministic tests pass"],
            verificationGroups: [
                VerificationRequirementGroupV1(
                    groupId: "p1f1d-canonical-group",
                    mode: .all,
                    requirements: [requirement]
                ),
            ],
            unacceptableDeviations: ["Missing result"],
            requiredDependencies: [],
            optionalDependencies: [],
            requiresSubjectiveJudgment: false,
            includesPublicRelease: false,
            includesPayment: false,
            includesDeletion: false,
            includesExternalSend: false,
            riskClass: .normal,
            acceptanceOwner: .user,
            acceptancePolicy: nil
        )
        let outcomeStore = OutcomeStore(database: db, clock: { Self.now })
        let draft = try outcomeStore.createDraft(
            CreateOutcomeContractDraftCommandV1(
                envelope: Self.commandEnvelope(
                    key: "p1f1d-canonical-contract-draft",
                    actorType: .user,
                    actorID: P1DActorID.localOwner,
                    at: Self.now
                ),
                contractId: Self.contractID,
                goal: GoalHeadV1(
                    goalId: Self.goalID,
                    campId: Self.campID,
                    expectedGoalVersion: readyGoal.aggregateVersion
                ),
                understanding: UnderstandingVersionRefV1(
                    id: understanding.id,
                    version: understanding.version,
                    hash: understanding.contentHash
                ),
                body: body
            )
        )
        let contract = try outcomeStore.activateContract(
            ActivateOutcomeContractCommandV1(
                envelope: Self.commandEnvelope(
                    key: "p1f1d-canonical-contract-activate",
                    actorType: .system,
                    actorID: P1DActorID.outcomeContract,
                    at: Self.now
                ),
                contract: draft.ref
            )
        )
        let activated = try outcomeStore.activateGoal(
            ActivateGoalCommandV1(
                envelope: Self.commandEnvelope(
                    key: "p1f1d-canonical-goal-activate",
                    actorType: .user,
                    actorID: P1DActorID.localOwner,
                    at: Self.now
                ),
                goal: GoalHeadV1(
                    goalId: readyGoal.id,
                    campId: readyGoal.campId,
                    expectedGoalVersion: readyGoal.aggregateVersion
                ),
                contract: contract.ref,
                missionId: mission.id,
                expectedLinkVersion: nil
            )
        )

        let ids = P1F1DeterministicIDs()
        let descriptor = p1f1ExecutionDescriptor(
            replayClass: replayClass,
            sessionResume: sessionResume,
            profileKind: profileKind
        )
        let descriptorAuthority = P1F1DCanonicalDescriptorAuthority(
            descriptor: descriptor
        )
        self.root = root
        self.workspaceURL = workspaceURL
        self.db = db
        self.ids = ids
        self.descriptor = descriptor
        self.descriptorAuthority = descriptorAuthority
        self.store = EngineExecutionStore(
            database: db,
            descriptorResolver: { profile, requiredCapabilities in
                try descriptorAuthority(
                    profile,
                    requiredCapabilities
                )
            },
            clock: { Self.now },
            executionIdFactory: { ids.next("execution") },
            runIdFactory: { ids.next("run") },
            proposalIdFactory: { ids.next("proposal") },
            artifactIdFactory: { ids.next("artifact") },
            eventIdFactory: { ids.next("event") },
            userRequestIdFactory: { ids.next("user-request") },
            sessionIdFactory: { ids.next("session") }
        )
        self.camp = camp
        self.squad = squad
        self.mission = mission
        self.card = card
        self.companion = companion
        self.profile = profile
        self.goal = activated.goal
        self.contract = contract

        for request in answeredRequests {
            try insertAnsweredRequest(request)
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func insertAnsweredRequest(
        _ seed: P1F1DCanonicalAnsweredRequestSeed
    ) throws -> UserRequestRecord {
        let milliseconds = seed.answeredAt.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds.rounded(.towardZero) == milliseconds,
              seed.createdAt <= seed.answeredAt,
              seed.kind != .approval
        else {
            throw EngineContextValidationErrorV1()
        }
        let answer = try JSONValue.decoded(from: seed.answerJSON)
        let canonicalAnswer = try answer.encodedString()
        let canonicalOptions = try seed.optionsJSON.map {
            try JSONValue.decoded(from: $0).encodedString()
        }
        try db.pool.write { database in
            try UserRequestRecord(
                id: seed.id,
                cardId: card.id,
                kind: seed.kind,
                prompt: seed.prompt,
                optionsJson: canonicalOptions,
                answerJson: nil,
                createdAt: seed.createdAt,
                answeredAt: nil,
                lifecycleState: .open,
                terminalReason: nil,
                redactedAt: nil
            ).insert(database)
            try database.execute(
                sql: """
                    UPDATE user_request
                    SET answerJson=?,answeredAt=?,lifecycleState='answered'
                    WHERE id=? AND lifecycleState='open'
                    """,
                arguments: [canonicalAnswer, seed.answeredAt, seed.id]
            )
            guard database.changesCount == 1 else {
                throw EngineContextValidationErrorV1()
            }
        }
        return try #require(
            try db.pool.read { database in
                try UserRequestRecord.fetchOne(database, key: seed.id)
            }
        )
    }

    func expectedContext(
        namespace: EngineContextToolNamespaceV1 = .ranchMCP
    ) throws -> P1F1DCanonicalExpectedContext {
        let answeredRows = try db.answeredRequests(cardId: card.id)
            .sorted { $0.id.utf8.lexicographicallyPrecedes($1.id.utf8) }
        let cardBytes = try CanonicalJSONV1.encode(
            P1F1DCanonicalCardContextV1(
                id: card.id,
                missionId: card.missionId,
                title: card.title,
                descriptionText: card.descriptionText,
                expectedOutput: card.expectedOutput,
                dependsOnJson: card.dependsOnJson,
                maxTurns: card.maxTurns,
                tokenBudget: card.tokenBudget
            )
        )
        let answeredSources = try answeredRows.map { row in
            let source = try EngineAnsweredRequestContextV1(
                userRequestId: row.id,
                cardId: row.cardId,
                kind: row.kind,
                prompt: row.prompt,
                optionsJson: try row.optionsJson.map(JSONValue.decoded(from:)),
                answerJson: try JSONValue.decoded(
                    from: try #require(row.answerJson)
                ),
                answeredAt: try #require(row.answeredAt)
            )
            return (row.id, try CanonicalJSONV1.encode(source))
        }
        let answeredBytesByID = Dictionary(
            uniqueKeysWithValues: answeredSources
        )
        let logicalDefinitions: [ToolDef] = [
            .completeCard,
            .blockCard,
            .addProgressNote,
            .askUser,
        ]
        let toolBindings = logicalDefinitions.map { definition in
            EngineContextToolBindingV1(
                logicalName: definition.name,
                providerVisibleName: namespace == .modelLoop
                    ? definition.name
                    : "mcp__ranchboard__\(definition.name)"
            )
        }
        let canonicalToolBindings = logicalDefinitions.map { definition in
            P1F1DCanonicalToolBindingV2(
                logicalName: definition.name,
                providerVisibleName: namespace == .modelLoop
                    ? definition.name
                    : "mcp__ranchboard__\(definition.name)"
            )
        }
        let toolDefinitions = zip(logicalDefinitions, toolBindings).map {
            definition, binding in
            P1F1DCanonicalToolDefinitionV1(
                name: binding.providerVisibleName,
                description: definition.description,
                inputSchema: definition.inputSchema
            )
        }
        let companionBytes = try CanonicalJSONV1.encode(
            P1F1DCanonicalCompanionContextV1(
                schemaVersion: 1,
                id: companion.id,
                name: companion.name,
                rolePrompt: companion.rolePrompt,
                toolsJson: companion.toolsJson,
                toolDefinitions: toolDefinitions
            )
        )
        let workspaceIdentity = try EngineWorkspaceIdentityV1(
            campId: camp.id,
            squadId: squad.id,
            workspacePath: workspaceURL.path,
            bookmarkHash: nil
        )
        let workspaceBytes = try CanonicalJSONV1.encode(workspaceIdentity)
        let instructionBytes = try CanonicalJSONV1.encode(
            P1F1DCanonicalInstructionContextV2(
                schemaVersion: 2,
                outcomeContract: contract.ref,
                autonomy: mission.autonomy,
                contextPacketRenderVersion: 2,
                toolBindings: canonicalToolBindings
            )
        )
        let references = try EngineContextReferencesV1(
            inputRefs: [
                EngineContextReferenceV1(
                    type: "input",
                    id: card.id,
                    version: 1,
                    hash: CanonicalJSONV1.sha256Hex(cardBytes)
                ),
            ] + answeredSources.map { id, bytes in
                EngineContextReferenceV1(
                    type: "input",
                    id: id,
                    version: 1,
                    hash: CanonicalJSONV1.sha256Hex(bytes)
                )
            },
            memoryRefs: [],
            resourceRefs: [
                EngineContextReferenceV1(
                    type: "resource",
                    id: companion.id,
                    version: 1,
                    hash: CanonicalJSONV1.sha256Hex(companionBytes)
                ),
                EngineContextReferenceV1(
                    type: "resource",
                    id: squad.id,
                    version: 1,
                    hash: CanonicalJSONV1.sha256Hex(workspaceBytes)
                ),
            ],
            priorHandoffRefs: [],
            instructionBlocks: [
                EngineContextReferenceV1(
                    type: "instruction",
                    id: contract.ref.id,
                    version: contract.ref.version,
                    hash: CanonicalJSONV1.sha256Hex(instructionBytes)
                ),
            ]
        )
        let packet = ContextPacket(
            companionName: companion.name,
            rolePrompt: companion.rolePrompt,
            cardTitle: card.title,
            cardDescription: card.descriptionText,
            expectedOutput: card.expectedOutput,
            workspacePath: workspaceURL.path,
            upstreamHandoffs: [],
            answeredRequests: answeredRows.map {
                (prompt: $0.prompt, answer: $0.humanAnswer())
            },
            campNotes: [],
            companionNotes: [],
            toolBindings: toolBindings,
            engineContextReferences: references
        )
        let envelope = try EngineContextEnvelopeV1.from(
            packet: packet,
            scope: EngineContextScopeV1(
                campId: camp.id,
                goalId: goal.id,
                missionId: mission.id,
                cardId: card.id,
                outcomeContract: contract.ref
            )
        )
        let envelopeBytes = try CanonicalJSONV1.encode(envelope)
        let canonicalJSON = String(decoding: envelopeBytes, as: UTF8.self)
        let hash = CanonicalJSONV1.sha256Hex(envelopeBytes)
        let workspaceReference = EngineWorkspaceRefV1(
            reference: "squad-workspace.v1:\(squad.id)",
            hash: CanonicalJSONV1.sha256Hex(workspaceBytes)
        )
        return try P1F1DCanonicalExpectedContext(
            packet: packet,
            envelope: envelope,
            canonicalJSON: canonicalJSON,
            hash: hash,
            contextRequest: EngineContextResolveRequestV1(
                campId: camp.id,
                cardId: card.id,
                companionId: companion.id,
                contextJson: canonicalJSON,
                contextHash: hash
            ),
            workspaceRequest: EngineWorkspaceResolveRequestV1(
                cardId: card.id,
                campId: camp.id,
                expectedWorkspace: workspaceReference
            ),
            workspaceReference: workspaceReference,
            goldens: P1F1DCanonicalReferenceGoldens(
                cardBytes: cardBytes,
                answeredBytesByID: answeredBytesByID,
                companionBytes: companionBytes,
                workspaceBytes: workspaceBytes,
                instructionBytes: instructionBytes,
                references: references
            )
        )
    }

    func fields(
        profileID: String = P1F1DCanonicalExecutionFixture.profileID,
        model: String = "gpt-test",
        workspace: EngineWorkspaceRefV1? = nil,
        predecessorExecutionId: String? = nil,
        context: P1F1DCanonicalExpectedContext? = nil
    ) throws -> EngineExecutionRequestFieldsV1 {
        let resolvedContext = try context ?? expectedContext()
        return try EngineExecutionRequestFieldsV1(
            campId: camp.id,
            cardId: card.id,
            contract: contract.ref,
            profileId: profileID,
            engineKind: descriptor.adapterId,
            model: model,
            contextJson: resolvedContext.canonicalJSON,
            contextHash: resolvedContext.hash,
            requiredCapabilities: [
                .boardTerminal,
                .streamingProgress,
                .usageMetering,
            ],
            approvalGrantIds: [],
            budget: EngineExecutionBudgetV1(
                tokenLimit: card.tokenBudget,
                costMicrosLimit: 5_000_000,
                wallClockSeconds: 900
            ),
            workspace: workspace ?? resolvedContext.workspaceReference,
            sessionSelection: nil,
            predecessorExecutionId: predecessorExecutionId,
            claimedSessionScopeJson: nil,
            claimedSessionScopeHash: nil
        )
    }

    func begin(
        key: String = "p1f1d-canonical-begin",
        fields: EngineExecutionRequestFieldsV1? = nil
    ) throws -> EngineExecutionRequest {
        try store.beginEngineExecution(
            requestFields: fields ?? self.fields(),
            idempotencyKey: key
        )
    }

    func insertProfile(_ id: String) throws {
        try db.pool.write { database in
            try RuntimeProfileRecord(
                id: id,
                kind: .cliCodex,
                name: "P1-F1D alternate profile",
                baseURL: nil,
                credentialAccount: nil,
                isDefault: false,
                createdAt: Self.now
            ).insert(database)
        }
    }

    private static func commandEnvelope(
        key: String,
        actorType: DomainActorType,
        actorID: String,
        at: Date
    ) throws -> CommandEnvelopeV1 {
        try CommandEnvelopeV1(
            idempotencyKey: key,
            actorType: actorType,
            actorId: actorID,
            deviceId: actorType == .user ? Self.deviceID : nil,
            correlationId: "trace:\(key)",
            causationId: nil,
            occurredAt: at
        )
    }
}

func p1f1ExecutionRow(
    _ db: AppDatabase,
    id: String
) throws -> Row {
    try db.pool.read { database in
        try #require(
            try Row.fetchOne(
                database,
                sql: "SELECT * FROM engine_execution WHERE id=?",
                arguments: [id]
            )
        )
    }
}

func p1f1TerminalCompletedProposal(
    request: EngineExecutionRequest,
    key: String = "p1f1-terminal-completed",
    sequence: Int = 0
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
                summary: "engine-owned completion",
                artifacts: [],
                noArtifactReason: "F1B intentionally has no blob artifacts",
                verification: [
                    .init(method: "store", passed: true, note: "atomic"),
                ],
                risks: []
            )
        ),
        artifacts: []
    )
}

@Suite(.serialized)
struct P1F1EngineExecutionStoreTests {
    @Test func p1f1_017ContextEnvelopeCanonicalGoldenBytes() throws {
        let envelope = try p1f1CanonicalEnvelope()
        let bytes = try CanonicalJSONV1.encode(envelope)

        #expect(String(decoding: bytes, as: UTF8.self) == p1f1ContextGolden)
        #expect(CanonicalJSONV1.sha256Hex(bytes) == p1f1ContextGoldenHash)
        #expect(envelope.memoryRefs.map(\.id) == [
            "00000000-0000-4000-8000-000000000011",
            "00000000-0000-4000-8000-000000000012",
        ])
        #expect(envelope.schemaVersion == 1)
        #expect(envelope.outcomeContract.hash == p1f1EngineHashA)
    }

    @Test func p1f1_018ContextEnvelopeRejectsInvalidBeforeWrite() throws {
        let fixture = try P1F1EngineFixture()
        let baseline = try p1f1EngineSurfaceCounts(fixture.db)
        let variants: [(String, String)] = [
            ("{", p1f1ContextGoldenHash),
            ("[]", CanonicalJSONV1.sha256Hex(Data("[]".utf8))),
            ("{ \"schemaVersion\" : 1 }", CanonicalJSONV1.sha256Hex(Data("{ \"schemaVersion\" : 1 }".utf8))),
            (p1f1ContextGolden, p1f1EngineHashF),
        ]

        for (offset, variant) in variants.enumerated() {
            #expect(throws: EngineContextValidationErrorV1.self) {
                _ = try fixture.begin(
                    key: "p1f1-context-reject-\(offset)",
                    fields: fixture.fields(
                        contextJson: variant.0,
                        contextHash: variant.1
                    )
                )
            }
            #expect(try p1f1EngineSurfaceCounts(fixture.db) == baseline)
            #expect(try fixture.db.card(id: p1f1EngineCardID)?.status == .ready)
        }
    }

    @Test func p1f1_019ContextEnvelopePromptRenderingDoesNotChangeIdentity() throws {
        let scope = try p1f1ContextScope()
        let references = try p1f1ContextReferences()
        let terse = try p1f1ContextPacket(
            rolePrompt: "short transport",
            cardDescription: "short",
            references: references
        )
        let verbose = try p1f1ContextPacket(
            rolePrompt: "a substantially different rendered transport prompt",
            cardDescription: "different prompt-only prose",
            references: references
        )
        #expect(terse.system != verbose.system)

        let terseEnvelope = try EngineContextEnvelopeV1.from(
            packet: terse,
            scope: scope
        )
        let verboseEnvelope = try EngineContextEnvelopeV1.from(
            packet: verbose,
            scope: scope
        )
        #expect(try CanonicalJSONV1.encode(terseEnvelope) == CanonicalJSONV1.encode(verboseEnvelope))

        let drifted = try EngineContextEnvelopeV1.from(
            packet: p1f1ContextPacket(
                rolePrompt: "short transport",
                cardDescription: "short",
                references: p1f1ContextReferences(memoryHash: p1f1EngineHashF)
            ),
            scope: scope
        )
        #expect(CanonicalJSONV1.sha256Hex(try CanonicalJSONV1.encode(drifted)) != p1f1ContextGoldenHash)
    }

    @Test func p1f1_020SessionScopeDerivedCanonicalGoldenBytes() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-scope-golden")

        #expect(request.sessionScopeJson == p1f1ScopeGolden)
        #expect(request.sessionScopeHash == p1f1ScopeGoldenHash)
        let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((row["sessionScopeJson"] as String) == p1f1ScopeGolden)
        #expect((row["sessionScopeHash"] as String) == p1f1ScopeGoldenHash)
        #expect((row["replayClass"] as String) == "idempotencyKeyed")
    }

    @Test func p1f1_021SessionScopeSpoofAndDriftZeroWrite() throws {
        let fixture = try P1F1EngineFixture()
        let baseline = try p1f1EngineSurfaceCounts(fixture.db)
        #expect(throws: EngineSessionScopeMismatchError.self) {
            _ = try fixture.begin(
                key: "p1f1-scope-spoof",
                fields: fixture.fields(
                    claimedSessionScopeJson: p1f1ScopeGolden,
                    claimedSessionScopeHash: p1f1EngineHashF
                )
            )
        }
        #expect(try p1f1EngineSurfaceCounts(fixture.db) == baseline)

        let first = try fixture.begin(key: "p1f1-scope-first")
        let secondCard = "00000000-0000-4000-8000-000000000104"
        try fixture.insertReadyCard(secondCard, idemKey: "p1f1-scope-second-card")
        let secondEnvelope = try p1f1CanonicalEnvelope(cardID: secondCard)
        let secondJSON = String(
            decoding: try CanonicalJSONV1.encode(secondEnvelope),
            as: UTF8.self
        )
        let drifted = try fixture.begin(
            key: "p1f1-scope-drift",
            fields: fixture.fields(
                cardID: secondCard,
                model: "gpt-test-new-model",
                contextJson: secondJSON,
                contextHash: CanonicalJSONV1.sha256Hex(Data(secondJSON.utf8))
            )
        )
        #expect(first.sessionScopeHash != drifted.sessionScopeHash)
        #expect(drifted.sessionScopeJson.contains("gpt-test-new-model"))

        let driftVariants: [(String, (P1F1EngineFixture) throws -> EngineExecutionRequestFieldsV1)] = [
            ("model", { candidate in
                try candidate.fields(
                    model: "gpt-scope-spoof",
                    claimedSessionScopeJson: p1f1ScopeGolden,
                    claimedSessionScopeHash: p1f1ScopeGoldenHash
                )
            }),
            ("workspace", { candidate in
                try candidate.fields(
                    workspace: EngineWorkspaceRefV1(
                        reference: "workspace:drift",
                        hash: p1f1EngineHashD
                    ),
                    claimedSessionScopeJson: p1f1ScopeGolden,
                    claimedSessionScopeHash: p1f1ScopeGoldenHash
                )
            }),
            ("contract", { candidate in
                let context = p1f1ContextGolden.replacingOccurrences(
                    of: p1f1EngineHashA,
                    with: p1f1EngineHashB
                )
                return try candidate.fields(
                    contractHash: p1f1EngineHashB,
                    contextJson: context,
                    contextHash: CanonicalJSONV1.sha256Hex(Data(context.utf8)),
                    claimedSessionScopeJson: p1f1ScopeGolden,
                    claimedSessionScopeHash: p1f1ScopeGoldenHash
                )
            }),
        ]
        for (name, makeFields) in driftVariants {
            let candidate = try P1F1EngineFixture()
            let before = try p1f1EngineProjectionSnapshot(fixture: candidate)
            #expect(throws: EngineSessionScopeMismatchError.self) {
                _ = try candidate.begin(
                    key: "p1f1-scope-claimed-old-\(name)",
                    fields: makeFields(candidate)
                )
            }
            #expect(try p1f1EngineProjectionSnapshot(fixture: candidate) == before)
        }
    }

    @Test func p1f1_022BeginAllocatesExecutionRunCardAndLifecycleAtomically() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-atomic-begin")
        let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)

        #expect(request.executionId == "10000000-0000-4000-8000-000000000001")
        #expect(request.runId == "20000000-0000-4000-8000-000000000001")
        #expect(request.campLifecycleVersion == 7)
        #expect((row["requestHash"] as String) == request.requestHash)
        #expect((row["dispatchState"] as String) == "prepared")
        #expect((row["state"] as String) == "running")
        #expect(try fixture.db.card(id: p1f1EngineCardID)?.status == .running)
        let run = try fixture.db.runs(cardId: p1f1EngineCardID)
        #expect(run.count == 1)
        #expect(run.first?.id == request.runId)
        #expect(run.first?.endedAt == nil)
        _ = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: "p1f1-atomic-begin",
            executionID: request.executionId,
            expectedCommandType: "engine.execution-begin.v1",
            expectedResultCode: "engine_execution_began",
            expectedEventTypes: ["engine.execution-began.v1"],
            expectedAuditCodes: ["engine_execution_began"],
            forbiddenSentinels: [
                request.model,
                request.contextJson,
                request.workspace.reference,
                request.profileId,
            ]
        )

        let aborted = try P1F1EngineFixture()
        try aborted.db.pool.write { database in
            try database.execute(sql: """
                CREATE TRIGGER p1f1_abort_begin_outbox
                BEFORE INSERT ON event_outbox
                BEGIN SELECT RAISE(ABORT, 'p1f1 injected outbox failure'); END
                """)
        }
        let before = try p1f1EngineSurfaceCounts(aborted.db)
        #expect(throws: DatabaseError.self) {
            _ = try aborted.begin(key: "p1f1-atomic-begin-abort")
        }
        #expect(try p1f1EngineSurfaceCounts(aborted.db) == before)
        #expect(try aborted.db.card(id: p1f1EngineCardID)?.status == .ready)

        let versionAdvanced = try P1F1EngineFixture()
        try p1f1ApplyCampFence(.lifecycleVersionDrift, fixture: versionAdvanced)
        let versionAdvancedRequest = try versionAdvanced.begin(
            key: "p1f1-begin-current-lifecycle"
        )
        #expect(versionAdvancedRequest.campLifecycleVersion == 8)

        for mutation in P1F1CampFenceMutation.allCases where
            mutation != .lifecycleVersionDrift
        {
            let fenced = try P1F1EngineFixture()
            try p1f1ApplyCampFence(mutation, fixture: fenced)
            let stable = try p1f1EngineProjectionSnapshot(fixture: fenced)
            #expect(throws: CampLifecycleWriteAuthorizationError.self) {
                _ = try fenced.begin(key: "p1f1-begin-fenced-\(mutation)")
            }
            #expect(try p1f1EngineProjectionSnapshot(fixture: fenced) == stable)
            #expect(fenced.ids.count("execution") == 0)
            #expect(fenced.ids.count("run") == 0)
            #expect(fenced.ids.count("event") == 0)
        }
    }

    @Test func p1f1_023BeginReplaySameHashAndConflictMatrix() throws {
        let fixture = try P1F1EngineFixture()
        let original = try fixture.begin(
            key: "p1f1-begin-replay",
            fields: fixture.fields(grantIDs: [p1f1EngineGrantB, p1f1EngineGrantA])
        )
        let afterFirst = try p1f1EngineSurfaceCounts(fixture.db)
        let replay = try fixture.begin(
            key: "p1f1-begin-replay",
            fields: fixture.fields(grantIDs: [p1f1EngineGrantA, p1f1EngineGrantB])
        )
        #expect(replay == original)
        #expect(try p1f1EngineSurfaceCounts(fixture.db) == afterFirst)

        let alternateProfile = "00000000-0000-4000-8000-000000000106"
        let alternateCamp = "00000000-0000-4000-8000-000000000101"
        try fixture.insertProfile(alternateProfile)
        let alternateCampEnvelope = try p1f1CanonicalEnvelope(
            campID: alternateCamp
        )
        let alternateCampJSON = String(
            decoding: try CanonicalJSONV1.encode(alternateCampEnvelope),
            as: UTF8.self
        )
        let alternateContractEnvelope = try p1f1CanonicalEnvelope(
            contractHash: p1f1EngineHashB
        )
        let alternateContractJSON = String(
            decoding: try CanonicalJSONV1.encode(alternateContractEnvelope),
            as: UTF8.self
        )
        let driftedContext = p1f1ContextGolden.replacingOccurrences(
            of: p1f1EngineHashC,
            with: p1f1EngineHashF
        )
        let driftedSession = try EngineSessionSelectionV1(
            sessionId: "70000000-0000-4000-8000-000000000099"
        )
        let variants: [EngineExecutionRequestFieldsV1] = try [
            fixture.fields(
                campID: alternateCamp,
                contextJson: alternateCampJSON,
                contextHash: CanonicalJSONV1.sha256Hex(
                    Data(alternateCampJSON.utf8)
                )
            ),
            fixture.fields(
                contractHash: p1f1EngineHashB,
                contextJson: alternateContractJSON,
                contextHash: CanonicalJSONV1.sha256Hex(
                    Data(alternateContractJSON.utf8)
                )
            ),
            fixture.fields(grantIDs: [p1f1EngineGrantA, p1f1EngineGrantC]),
            fixture.fields(
                budget: EngineExecutionBudgetV1(
                    tokenLimit: 10_001,
                    costMicrosLimit: 5_000_000,
                    wallClockSeconds: 900
                )
            ),
            fixture.fields(
                workspace: EngineWorkspaceRefV1(
                    reference: "workspace:secondary",
                    hash: p1f1EngineHashD
                )
            ),
            fixture.fields(profileID: alternateProfile),
            fixture.fields(model: "gpt-drift"),
            fixture.fields(
                contextJson: driftedContext,
                contextHash: CanonicalJSONV1.sha256Hex(Data(driftedContext.utf8))
            ),
            fixture.fields(sessionSelection: driftedSession),
        ]
        for variant in variants {
            #expect(throws: EngineExecutionReplayConflictError.self) {
                _ = try fixture.begin(
                    key: "p1f1-begin-replay",
                    fields: variant
                )
            }
            #expect(try p1f1EngineSurfaceCounts(fixture.db) == afterFirst)
        }

        try p1f1ApplyCampFence(.deletionRequested, fixture: fixture)
        let lifecycleReplay = try fixture.begin(
            key: "p1f1-begin-replay",
            fields: fixture.fields(grantIDs: [p1f1EngineGrantA, p1f1EngineGrantB])
        )
        #expect(lifecycleReplay == original)
        #expect(try p1f1EngineSurfaceCounts(fixture.db) == afterFirst)
        #expect(throws: EngineExecutionReplayConflictError.self) {
            _ = try fixture.begin(
                key: "p1f1-begin-replay",
                fields: fixture.fields(model: "gpt-drift-after-delete")
            )
        }

        enum Tamper {
            case eventType
            case payload
            case payloadHash
            case ordinal
            case aggregateVersion
            case scope
            case receipt
            case outbox
        }
        for (offset, tamper) in [
            Tamper.eventType, .payload, .payloadHash, .ordinal,
            .aggregateVersion, .scope, .receipt, .outbox,
        ].enumerated() {
            let candidate = try P1F1EngineFixture()
            let key = "p1f1-begin-graph-tamper-\(offset)"
            let first = try candidate.begin(key: key)
            try candidate.db.pool.write { database in
                let eventID = try #require(
                    try String.fetchOne(
                        database,
                        sql: "SELECT id FROM domain_event WHERE commandIdempotencyKey=?",
                        arguments: [key]
                    )
                )
                switch tamper {
                case .eventType:
                    try database.execute(
                        sql: "DROP TRIGGER domain_event_reject_update"
                    )
                    try database.execute(
                        sql: "UPDATE domain_event SET eventType='input.captured.v1' WHERE id=?",
                        arguments: [eventID]
                    )
                case .payload:
                    try database.execute(
                        sql: "DROP TRIGGER domain_event_reject_update"
                    )
                    try database.execute(
                        sql: "UPDATE domain_event SET payloadJson='{}' WHERE id=?",
                        arguments: [eventID]
                    )
                case .payloadHash:
                    try database.execute(
                        sql: "DROP TRIGGER domain_event_reject_update"
                    )
                    try database.execute(
                        sql: "UPDATE domain_event SET payloadHash=? WHERE id=?",
                        arguments: [p1f1EngineHashF, eventID]
                    )
                case .ordinal:
                    try database.execute(
                        sql: "DROP TRIGGER domain_event_reject_update"
                    )
                    try database.execute(
                        sql: "UPDATE domain_event SET eventOrdinal=1 WHERE id=?",
                        arguments: [eventID]
                    )
                case .aggregateVersion:
                    try database.execute(
                        sql: "DROP TRIGGER domain_event_reject_update"
                    )
                    try database.execute(
                        sql: "UPDATE domain_event SET aggregateVersion=aggregateVersion+1 WHERE id=?",
                        arguments: [eventID]
                    )
                case .scope:
                    try database.execute(
                        sql: "DROP TRIGGER camp_event_scope_reject_delete"
                    )
                    try database.execute(
                        sql: "DELETE FROM camp_event_scope WHERE sourceTable='domain_event' AND eventId=?",
                        arguments: [eventID]
                    )
                case .receipt:
                    try database.execute(
                        sql: "DROP TRIGGER domain_command_receipt_reject_update"
                    )
                    try database.execute(
                        sql: "UPDATE domain_command_receipt SET resultHash=? WHERE idempotencyKey=?",
                        arguments: [p1f1EngineHashF, key]
                    )
                case .outbox:
                    try database.execute(
                        sql: "DELETE FROM event_outbox WHERE eventId=?",
                        arguments: [eventID]
                    )
                }
            }
            let tampered = try p1f1EngineProjectionSnapshot(
                fixture: candidate,
                executionID: first.executionId,
                runID: first.runId
            )
            #expect(throws: DomainCommandGraphIntegrityError.self) {
                _ = try candidate.begin(key: key)
            }
            #expect(try p1f1EngineProjectionSnapshot(
                fixture: candidate,
                executionID: first.executionId,
                runID: first.runId
            ) == tampered)
        }
    }

    @Test func p1f1_024DescriptorReplayClassIsDerivedAndPersisted() throws {
        let fixture = try P1F1EngineFixture(replayClass: .replaySafe)
        try fixture.db.pool.write { database in
            try database.execute(
                sql: """
                    INSERT INTO approval_grant(
                      id,version,scopeVersion,grantorActorType,grantorActorId,
                      grantorPolicyId,grantorPolicyVersion,grantorPolicyHash,
                      granteeType,granteeId,capability,campId,cardId,toolId,
                      approvedInputHash,purpose,dataLevel,adapterReplayClass,
                      validFrom,validUntil,maxUses,usedCount,status,revokedAt,
                      createdAt,updatedAt,redactedAt
                    ) VALUES (
                      ?,1,1,'user','user:test',NULL,NULL,NULL,
                      'engine','engine:test','workspace.write',?,?,
                      'write_file',?,'bounded test','workspace','nonReplayable',
                      ?,?,1,0,'active',NULL,?,?,NULL
                    )
                    """,
                arguments: [
                    p1f1EngineGrantA,
                    p1f1EngineCampID,
                    p1f1EngineCardID,
                    p1f1EngineHashA,
                    p1f1EngineTestNow,
                    p1f1EngineTestNow.addingTimeInterval(3600),
                    p1f1EngineTestNow,
                    p1f1EngineTestNow,
                ]
            )
        }
        let request = try fixture.begin(
            key: "p1f1-replay-class",
            fields: fixture.fields(grantIDs: [p1f1EngineGrantA])
        )
        #expect(request.replayClass == .replaySafe)
        let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((row["replayClass"] as String) == "replaySafe")
        #expect(request.requestJson.contains(p1f1EngineGrantA))
    }

    @Test func p1f1_025DispatchCASStartsAdapterExactlyOnce() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-dispatch")
        let prepared = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        let version: Int = prepared["version"]

        let first = try fixture.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: version,
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-dispatch-command",
            now: p1f1EngineTestNow.addingTimeInterval(1)
        )
        guard case let .startNow(persisted) = first else {
            Issue.record("first dispatch CAS must return startNow")
            return
        }
        #expect(persisted == request)
        let adapter = P1F1DispatchProbeAdapter(descriptor: fixture.descriptor)
        _ = adapter.execute(request: persisted)

        let afterStart = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        let startedVersion: Int = afterStart["version"]
        let replay = try fixture.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: startedVersion,
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-dispatch-command",
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        if case let .startNow(replayedRequest) = replay {
            _ = adapter.execute(request: replayedRequest)
        }
        #expect(replay == .alreadyStarted)
        #expect(adapter.executeCount == 1)
        _ = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: "p1f1-dispatch-command",
            executionID: request.executionId,
            expectedCommandType: "engine.dispatch-start.v1",
            expectedResultCode: "engine_dispatch_started",
            expectedEventTypes: ["engine.dispatch-started.v1"],
            expectedAuditCodes: ["engine_dispatch_started"],
            forbiddenSentinels: [
                request.model,
                request.contextJson,
                request.workspace.reference,
                "engine dispatch started",
            ]
        )

        let stable = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect(throws: EngineDispatchConflictErrorV1.self) {
            _ = try fixture.store.markEngineDispatchStarted(
                executionId: request.executionId,
                expectedVersion: version,
                requestHash: request.requestHash,
                commandIdempotencyKey: "p1f1-dispatch-command-stale",
                now: p1f1EngineTestNow.addingTimeInterval(3)
            )
        }
        #expect(throws: EngineDispatchConflictErrorV1.self) {
            _ = try fixture.store.markEngineDispatchStarted(
                executionId: request.executionId,
                expectedVersion: startedVersion,
                requestHash: p1f1EngineHashF,
                commandIdempotencyKey: "p1f1-dispatch-command-hash",
                now: p1f1EngineTestNow.addingTimeInterval(3)
            )
        }
        let afterConflicts = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((afterConflicts["version"] as Int) == (stable["version"] as Int))
        #expect((afterConflicts["dispatchStartedAt"] as Date?) != nil)

        let fenced = try P1F1EngineFixture()
        let fencedRequest = try fenced.begin(key: "p1f1-dispatch-fenced-begin")
        let fencedPrepared = try p1f1ExecutionRow(
            fenced.db,
            id: fencedRequest.executionId
        )
        try p1f1ApplyCampFence(.lifecycleVersionDrift, fixture: fenced)
        let fencedStable = try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        )
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try fenced.store.markEngineDispatchStarted(
                executionId: fencedRequest.executionId,
                expectedVersion: fencedPrepared["version"],
                requestHash: fencedRequest.requestHash,
                commandIdempotencyKey: "p1f1-dispatch-fenced-command",
                now: p1f1EngineTestNow.addingTimeInterval(2)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        ) == fencedStable)

        let tamperedFixture = try P1F1EngineFixture()
        let tamperedRequest = try tamperedFixture.begin(
            key: "p1f1-dispatch-tampered-begin"
        )
        let tamperedPrepared = try p1f1ExecutionRow(
            tamperedFixture.db,
            id: tamperedRequest.executionId
        )
        _ = try tamperedFixture.store.markEngineDispatchStarted(
            executionId: tamperedRequest.executionId,
            expectedVersion: tamperedPrepared["version"],
            requestHash: tamperedRequest.requestHash,
            commandIdempotencyKey: "p1f1-dispatch-tampered-command",
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        try tamperedFixture.db.pool.write { database in
            try database.execute(
                sql: """
                    DELETE FROM event_outbox
                    WHERE eventId=(SELECT id FROM domain_event
                      WHERE commandIdempotencyKey='p1f1-dispatch-tampered-command')
                    """
            )
        }
        let tamperedRow = try p1f1ExecutionRow(
            tamperedFixture.db,
            id: tamperedRequest.executionId
        )
        let tamperedStable = try p1f1EngineProjectionSnapshot(
            fixture: tamperedFixture,
            executionID: tamperedRequest.executionId,
            runID: tamperedRequest.runId
        )
        #expect(throws: DomainCommandGraphIntegrityError.self) {
            _ = try tamperedFixture.store.markEngineDispatchStarted(
                executionId: tamperedRequest.executionId,
                expectedVersion: tamperedRow["version"],
                requestHash: tamperedRequest.requestHash,
                commandIdempotencyKey: "p1f1-dispatch-tampered-command",
                now: p1f1EngineTestNow.addingTimeInterval(3)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: tamperedFixture,
            executionID: tamperedRequest.executionId,
            runID: tamperedRequest.runId
        ) == tamperedStable)
    }

    @Test func p1f1_026PreDispatchFailureTerminalizesWithoutDispatch() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-predispatch-begin")
        let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        let version: Int = row["version"]
        let failure = EnginePreDispatchFailureV1(
            terminalKind: .blocked,
            terminalSubtype: .engineProtocolError,
            reasonCode: "descriptor_capability_mismatch",
            detail: "required capability unavailable"
        )
        let terminalKey = "engine.pre-dispatch-failure.v1:\(request.executionId)"
        let commandKey = "engine.terminal.v1:\(terminalKey)"
        let beforeTerminal = try p1f1EngineSurfaceCounts(fixture.db)
        let receipt = try fixture.store.commitEnginePreDispatchFailure(
            executionId: request.executionId,
            expectedVersion: version,
            failure: failure,
            commandIdempotencyKey: commandKey,
            now: p1f1EngineTestNow.addingTimeInterval(4)
        )
        let terminal = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((terminal["state"] as String) == "blocked")
        #expect((terminal["terminalSubtype"] as String?) == "engineProtocolError")
        #expect((terminal["dispatchStartedAt"] as Date?) == nil)
        #expect(try fixture.db.card(id: p1f1EngineCardID)?.status == .blocked)
        #expect(try fixture.db.runs(cardId: p1f1EngineCardID).first?.outcome == "blocked")
        let afterTerminal = try p1f1EngineSurfaceCounts(fixture.db)
        #expect(afterTerminal.receipts == beforeTerminal.receipts + 2)
        #expect(afterTerminal.domainEvents == beforeTerminal.domainEvents + 2)
        #expect(afterTerminal.outbox == beforeTerminal.outbox + 2)
        #expect(afterTerminal.legacyEvents == beforeTerminal.legacyEvents + 1)
        #expect(afterTerminal.proposals == beforeTerminal.proposals + 1)
        #expect(afterTerminal.proposalArtifacts == beforeTerminal.proposalArtifacts)
        _ = try p1f1AssertSyntheticTerminalGraph(
            fixture: fixture,
            request: request,
            terminalKey: terminalKey,
            expectedSequence: 0,
            expectedKind: .blocked,
            expectedSubtype: .engineProtocolError,
            expectedReasonCode: "descriptor_capability_mismatch",
            expectedDetail: "required capability unavailable",
            attention: false,
            receipt: receipt
        )

        try p1f1ApplyCampFence(.archived, fixture: fixture)
        let replayStable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        let replay = try fixture.store.commitEnginePreDispatchFailure(
            executionId: request.executionId,
            expectedVersion: version,
            failure: failure,
            commandIdempotencyKey: commandKey,
            now: p1f1EngineTestNow.addingTimeInterval(5)
        )
        #expect(replay == receipt)
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == replayStable)
        #expect(throws: EngineTerminalConflictErrorV1.self) {
            _ = try fixture.store.commitEnginePreDispatchFailure(
                executionId: request.executionId,
                expectedVersion: version,
                failure: EnginePreDispatchFailureV1(
                    terminalKind: .failed,
                    terminalSubtype: nil,
                    reasonCode: "different_failure",
                    detail: "must conflict"
                ),
                commandIdempotencyKey: commandKey,
                now: p1f1EngineTestNow.addingTimeInterval(6)
            )
        }

        let fenced = try P1F1EngineFixture()
        let fencedRequest = try fenced.begin(key: "p1f1-predispatch-fenced-begin")
        let fencedRow = try p1f1ExecutionRow(fenced.db, id: fencedRequest.executionId)
        try p1f1ApplyCampFence(.deletionRequested, fixture: fenced)
        let fencedStable = try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        )
        let fencedTerminalKey =
            "engine.pre-dispatch-failure.v1:\(fencedRequest.executionId)"
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            _ = try fenced.store.commitEnginePreDispatchFailure(
                executionId: fencedRequest.executionId,
                expectedVersion: fencedRow["version"],
                failure: failure,
                commandIdempotencyKey: "engine.terminal.v1:\(fencedTerminalKey)",
                now: p1f1EngineTestNow.addingTimeInterval(4)
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        ) == fencedStable)
    }

    @Test func p1f1_027AcceptEventMonotonicSequenceMatrix() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-events")
        let prepared = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        _ = try fixture.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: prepared["version"],
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-events-dispatch",
            now: p1f1EngineTestNow.addingTimeInterval(1)
        )
        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 0,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 0,
                payload: .accepted
            )
        )
        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 1,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 1,
                payload: .progress(message: "halfway")
            )
        )
        let stable = try p1f1EngineSurfaceCounts(fixture.db)
        let invalidEvents: [(Int, EngineExecutionEvent)] = [
            (1, EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 1,
                payload: .progress(message: "duplicate")
            )),
            (3, EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 3,
                payload: .progress(message: "skipped")
            )),
            (0, EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 0,
                payload: .progress(message: "out-of-order")
            )),
            (2, EngineExecutionEvent(
                executionId: "p1f1-wrong-execution",
                sequence: 2,
                payload: .progress(message: "wrong execution")
            )),
        ]
        for invalid in invalidEvents {
            #expect(throws: EngineEventSequenceErrorV1.self) {
                try fixture.store.acceptEngineEvent(
                    executionId: request.executionId,
                    sequence: invalid.0,
                    event: invalid.1
                )
            }
            #expect(try p1f1EngineSurfaceCounts(fixture.db) == stable)
            let row = try p1f1ExecutionRow(fixture.db, id: request.executionId)
            #expect((row["nextSequence"] as Int) == 2)
        }

        for (sequence, forbidden) in [
            (0, "accepted-does-not-carry-a-body"),
            (1, "halfway"),
        ] {
            _ = try p1f1AssertSafeCommandGraph(
                fixture: fixture,
                commandKey: "engine.event.v1:\(request.executionId):\(sequence)",
                executionID: request.executionId,
                expectedCommandType: "engine.event-accept.v1",
                expectedResultCode: "engine_event_accepted",
                expectedEventTypes: ["engine.event-accepted.v1"],
                expectedAuditCodes: ["engine_event_accepted"],
                forbiddenSentinels: [forbidden, request.model, request.workspace.reference]
            )
        }
        let afterProgress = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((afterProgress["state"] as String) == "running")
        #expect((afterProgress["dispatchState"] as String) == "started")

        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 2,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 2,
                payload: .sessionBound(externalSessionId: "codex-thread-six-events")
            )
        )
        let mismatchedSessionStable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        #expect(throws: EngineSessionScopeMismatchError.self) {
            try fixture.store.acceptEngineEvent(
                executionId: request.executionId,
                sequence: 3,
                event: EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 3,
                    payload: .sessionBound(
                        externalSessionId: "codex-thread-six-events-mismatch"
                    )
                )
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == mismatchedSessionStable)
        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 3,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 3,
                payload: .toolActivity(name: "swift-build")
            )
        )
        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 4,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 4,
                payload: .usage(
                    EngineUsageV1(
                        inputTokens: 11,
                        outputTokens: 7,
                        cacheReadTokens: 5,
                        costMicros: 3
                    )
                )
            )
        )
        let terminalContent = try p1f1TerminalCompletedProposal(
            request: request,
            key: "p1f1-six-events-terminal",
            sequence: 5
        )
        try fixture.store.acceptEngineEvent(
            executionId: request.executionId,
            sequence: 5,
            event: EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 5,
                payload: .terminal(terminalContent)
            )
        )
        for (sequence, sentinel) in [
            (2, "codex-thread-six-events"),
            (3, "swift-build"),
            (4, "does-not-appear-in-safe-usage"),
        ] {
            _ = try p1f1AssertSafeCommandGraph(
                fixture: fixture,
                commandKey: "engine.event.v1:\(request.executionId):\(sequence)",
                executionID: request.executionId,
                expectedCommandType: "engine.event-accept.v1",
                expectedResultCode: "engine_event_accepted",
                expectedEventTypes: ["engine.event-accepted.v1"],
                expectedAuditCodes: ["engine_event_accepted"],
                forbiddenSentinels: [sentinel, request.model, request.workspace.reference]
            )
        }
        let proposalKey =
            "engine.terminal-proposal.v1:\(terminalContent.terminalIdempotencyKey)"
        _ = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: proposalKey,
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
                "engine-owned completion",
                request.model,
                request.workspace.reference,
            ]
        )
        #expect(try fixture.db.pool.read { database in
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM domain_command_receipt WHERE idempotencyKey=?",
                arguments: ["engine.event.v1:\(request.executionId):5"]
            )
        } == 0)
        let proposed = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((proposed["dispatchState"] as String) == "terminalProposed")
        #expect((proposed["nextSequence"] as Int) == 6)

        let codecEvents: [(EngineExecutionEvent, String)] = [
            (
                EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 0,
                    payload: .accepted
                ),
                "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"accepted\"},\"sequence\":0}"
            ),
            (
                EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 1,
                    payload: .sessionBound(externalSessionId: "codec-session")
                ),
                "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"externalSessionId\":\"codec-session\",\"kind\":\"sessionBound\"},\"sequence\":1}"
            ),
            (
                EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 2,
                    payload: .progress(message: "codec-progress")
                ),
                "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"progress\",\"message\":\"codec-progress\"},\"sequence\":2}"
            ),
            (
                EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 3,
                    payload: .toolActivity(name: "codec-tool")
                ),
                "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"toolActivity\",\"name\":\"codec-tool\"},\"sequence\":3}"
            ),
            (
                EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 4,
                    payload: .usage(
                        EngineUsageV1(
                            inputTokens: 1,
                            outputTokens: 2,
                            cacheReadTokens: 3,
                            costMicros: 4
                        )
                    )
                ),
                "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"cacheReadTokens\":3,\"costMicros\":4,\"inputTokens\":1,\"kind\":\"usage\",\"outputTokens\":2},\"sequence\":4}"
            ),
            (
                EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 5,
                    payload: .terminal(terminalContent)
                ),
                "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"terminal\",\"proposal\":\(String(decoding: try CanonicalJSONV1.encode(terminalContent), as: UTF8.self))},\"sequence\":5}"
            ),
        ]
        for (event, golden) in codecEvents {
            let bytes = try CanonicalContractCodingV1.encode(event)
            #expect(String(decoding: bytes, as: UTF8.self) == golden)
            #expect(try CanonicalContractCodingV1.decode(
                EngineExecutionEvent.self,
                from: bytes
            ) == event)
        }

        let tooLongSession = String(repeating: "s", count: 513)
        let tooLongTool = String(repeating: "t", count: 129)
        let invalidEventJSON = [
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"accepted\"}}",
            "{\"extra\":true,\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"accepted\"},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"extra\":true,\"kind\":\"accepted\"},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"externalSessionId\":\"\",\"kind\":\"sessionBound\"},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"externalSessionId\":\"\(tooLongSession)\",\"kind\":\"sessionBound\"},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"progress\",\"message\":\"\"},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"kind\":\"toolActivity\",\"name\":\"\(tooLongTool)\"},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"cacheReadTokens\":0,\"costMicros\":0,\"inputTokens\":-1,\"kind\":\"usage\",\"outputTokens\":0},\"sequence\":0}",
            "{\"executionId\":\"\(request.executionId)\",\"payload\":{\"cacheReadTokens\":0,\"costMicros\":0,\"inputTokens\":null,\"kind\":\"usage\",\"outputTokens\":0},\"sequence\":0}",
        ]
        for invalid in invalidEventJSON {
            #expect(throws: Error.self) {
                _ = try CanonicalContractCodingV1.decode(
                    EngineExecutionEvent.self,
                    from: Data(invalid.utf8)
                )
            }
        }
        #expect(throws: Error.self) {
            let mismatched = EngineExecutionEvent(
                executionId: request.executionId,
                sequence: 6,
                payload: .terminal(terminalContent)
            )
            _ = try CanonicalContractCodingV1.decode(
                EngineExecutionEvent.self,
                from: CanonicalContractCodingV1.encode(mismatched)
            )
        }

        let fenced = try P1F1EngineFixture()
        let fencedRequest = try fenced.begin(key: "p1f1-event-fenced-begin")
        let fencedPrepared = try p1f1ExecutionRow(fenced.db, id: fencedRequest.executionId)
        _ = try fenced.store.markEngineDispatchStarted(
            executionId: fencedRequest.executionId,
            expectedVersion: fencedPrepared["version"],
            requestHash: fencedRequest.requestHash,
            commandIdempotencyKey: "p1f1-event-fenced-dispatch",
            now: p1f1EngineTestNow.addingTimeInterval(1)
        )
        try p1f1ApplyCampFence(.legacyArchived, fixture: fenced)
        let fencedStable = try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        )
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            try fenced.store.acceptEngineEvent(
                executionId: fencedRequest.executionId,
                sequence: 0,
                event: EngineExecutionEvent(
                    executionId: fencedRequest.executionId,
                    sequence: 0,
                    payload: .progress(message: "must not persist")
                )
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fenced,
            executionID: fencedRequest.executionId,
            runID: fencedRequest.runId
        ) == fencedStable)
    }

    @Test func p1f1_028UsageOverflowFailsWithoutPartialProjection() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-usage-overflow")
        let prepared = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        _ = try fixture.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: prepared["version"],
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-usage-dispatch",
            now: p1f1EngineTestNow.addingTimeInterval(1)
        )
        try fixture.db.pool.write { database in
            try database.execute(
                sql: "UPDATE engine_execution SET inputTokens=? WHERE id=?",
                arguments: [Int.max, request.executionId]
            )
        }
        let usageEventsBefore = try fixture.db.pool.read { database in
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM event
                    WHERE runId=? AND kind=?
                      AND json_extract(payloadJson, '$.kind')='usage'
                    """,
                arguments: [request.runId, EventKind.progressNote]
            ) ?? -1
        }
        let beforeOverflow = try p1f1EngineSurfaceCounts(fixture.db)
        #expect(throws: EngineUsageV1.UsageOverflowError.self) {
            try fixture.store.acceptEngineEvent(
                executionId: request.executionId,
                sequence: 0,
                event: EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 0,
                    payload: .usage(
                        EngineUsageV1(
                            inputTokens: 1,
                            outputTokens: 0,
                            cacheReadTokens: 0,
                            costMicros: 0
                        )
                    )
                )
            )
        }
        let terminal = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        #expect((terminal["state"] as String) == "failed")
        #expect((terminal["inputTokens"] as Int) == Int.max)
        #expect((terminal["outputTokens"] as Int) == 0)
        #expect((terminal["cacheReadTokens"] as Int) == 0)
        #expect((terminal["costMicros"] as Int) == 0)
        #expect((terminal["nextSequence"] as Int) == 0)
        let usageEventsAfter = try fixture.db.pool.read { database in
            try Int.fetchOne(
                database,
                sql: """
                    SELECT COUNT(*) FROM event
                    WHERE runId=? AND kind=?
                      AND json_extract(payloadJson, '$.kind')='usage'
                    """,
                arguments: [request.runId, EventKind.progressNote]
            ) ?? -1
        }
        #expect(usageEventsAfter == usageEventsBefore)
        let afterOverflow = try p1f1EngineSurfaceCounts(fixture.db)
        #expect(afterOverflow.receipts == beforeOverflow.receipts + 2)
        #expect(afterOverflow.domainEvents == beforeOverflow.domainEvents + 2)
        #expect(afterOverflow.outbox == beforeOverflow.outbox + 2)
        #expect(afterOverflow.legacyEvents == beforeOverflow.legacyEvents + 1)
        #expect(afterOverflow.proposals == beforeOverflow.proposals + 1)
        #expect(afterOverflow.proposalArtifacts == beforeOverflow.proposalArtifacts)
        let terminalKey = "engine.usage-overflow.v1:\(request.executionId)"
        _ = try p1f1AssertSyntheticTerminalGraph(
            fixture: fixture,
            request: request,
            terminalKey: terminalKey,
            expectedSequence: 0,
            expectedKind: .failed,
            expectedSubtype: nil,
            expectedReasonCode: "usage_overflow",
            expectedDetail: "engine usage counter overflow",
            attention: false
        )
        #expect(try fixture.db.pool.read { database in
            try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM domain_command_receipt WHERE idempotencyKey=?",
                arguments: ["engine.event.v1:\(request.executionId):0"]
            )
        } == 0)
        let stable = try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        )
        #expect(throws: EngineEventSequenceErrorV1.self) {
            try fixture.store.acceptEngineEvent(
                executionId: request.executionId,
                sequence: 0,
                event: EngineExecutionEvent(
                    executionId: request.executionId,
                    sequence: 0,
                    payload: .usage(
                        EngineUsageV1(
                            inputTokens: 1,
                            outputTokens: 0,
                            cacheReadTokens: 0,
                            costMicros: 0
                        )
                    )
                )
            )
        }
        #expect(try p1f1EngineProjectionSnapshot(
            fixture: fixture,
            executionID: request.executionId,
            runID: request.runId
        ) == stable)
    }

    @Test func p1f1_029TerminalReceiptLinksDomainResultHashNotProposalHash() throws {
        let fixture = try P1F1EngineFixture()
        let request = try fixture.begin(key: "p1f1-receipt-link")
        let prepared = try p1f1ExecutionRow(fixture.db, id: request.executionId)
        _ = try fixture.store.markEngineDispatchStarted(
            executionId: request.executionId,
            expectedVersion: prepared["version"],
            requestHash: request.requestHash,
            commandIdempotencyKey: "p1f1-receipt-dispatch",
            now: p1f1EngineTestNow.addingTimeInterval(1)
        )
        let recorded = try fixture.store.recordEngineTerminalProposal(
            p1f1TerminalCompletedProposal(request: request)
        )
        let receipt = try fixture.store.commitEngineTerminal(
            proposalId: recorded.proposal.id,
            checkedUsage: .zero,
            now: p1f1EngineTestNow.addingTimeInterval(2)
        )
        let links = try fixture.db.pool.read { database -> (String, String, String, String) in
            let execution = try #require(
                try Row.fetchOne(
                    database,
                    sql: """
                        SELECT terminalReceiptIdempotencyKey,terminalReceiptHash
                        FROM engine_execution WHERE id=?
                        """,
                    arguments: [request.executionId]
                )
            )
            let receiptRow = try #require(
                try Row.fetchOne(
                    database,
                    sql: """
                        SELECT resultHash FROM domain_command_receipt
                        WHERE idempotencyKey=?
                        """,
                    arguments: [receipt.receiptIdempotencyKey]
                )
            )
            let proposalHash: String = try #require(
                try String.fetchOne(
                    database,
                    sql: "SELECT proposalHash FROM engine_terminal_proposal WHERE id=?",
                    arguments: [recorded.proposal.id]
                )
            )
            return (
                execution["terminalReceiptIdempotencyKey"],
                execution["terminalReceiptHash"],
                receiptRow["resultHash"],
                proposalHash
            )
        }
        #expect(links.0 == receipt.receiptIdempotencyKey)
        #expect(links.1 == receipt.terminalReceiptHash)
        #expect(links.1 == links.2)
        #expect(links.1 != links.3)
        #expect(receipt.proposalHash == links.3)
        let proposalKey = "engine.terminal-proposal.v1:p1f1-terminal-completed"
        _ = try p1f1AssertSafeCommandGraph(
            fixture: fixture,
            commandKey: proposalKey,
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
                "engine-owned completion",
                "F1B intentionally has no blob artifacts",
            ]
        )
        let terminalGraph = try p1f1AssertSafeCommandGraph(
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
        #expect(receipt.committedEventIds == terminalGraph.eventIDs)
        #expect(receipt.terminalReceiptHash == terminalGraph.resultHash)
        #expect((try p1f1ExecutionRow(
            fixture.db,
            id: request.executionId
        )["nextSequence"] as Int) == 1)
    }
}
