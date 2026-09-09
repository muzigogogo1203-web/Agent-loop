import Testing
import Foundation
import GRDB
import AgentLoopCore

private func askTempRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func askTempDB(root: URL) throws -> AppDatabase {
    try AppDatabase(path: root.appendingPathComponent("test.sqlite").path)
}

private struct AskMissionFixture {
    let canonical: P1F1DCanonicalExecutionFixture
    let companions: [CompanionRecord]

    var root: URL { canonical.root }
    var db: AppDatabase { canonical.db }
    var missionId: String { canonical.mission.id }
}

private func askCompanions(
    _ fixture: P1F1DCanonicalExecutionFixture,
    count: Int
) throws -> [CompanionRecord] {
    var companions: [CompanionRecord] = []
    for index in 0..<count {
        var companion = index == 0
            ? fixture.companion
            : CompanionRecord.new(
                name: "伙伴 \(index + 1)",
                color: "blue",
                rolePrompt: "执行",
                model: "ask-model-\(index)",
                campId: fixture.camp.id
            )
        companion.name = "伙伴 \(index + 1)"
        companion.rolePrompt = "执行"
        companion.model = "ask-model-\(index)"
        companion.campId = fixture.camp.id
        companion.runtimeProfileId = fixture.profile.id
        companion.modelPolicy = .pinned
        try fixture.db.saveCompanion(companion)
        companions.append(companion)
    }
    return companions
}

private func askMission(
    companionCount: Int = 1,
    drafts: [PlanProposal.CardDraft]
) throws -> AskMissionFixture {
    guard companionCount > 0, !drafts.isEmpty else {
        throw EngineContextValidationErrorV1()
    }
    let canonical = try P1F1DCanonicalExecutionFixture(
        profileKind: .openAIAPI
    )
    let companions = try askCompanions(
        canonical,
        count: companionCount
    )
    let cardIDs = drafts.indices.map { index in
        index == 0 ? canonical.card.id : UUID().uuidString
    }
    try canonical.db.pool.write { database in
        var squad = canonical.squad
        squad.memberIdsJson = String(
            decoding: try CanonicalJSONV1.encode(companions.map(\.id)),
            as: UTF8.self
        )
        try squad.update(database)

        for (index, draft) in drafts.enumerated() {
            let dependencyIDs = try draft.dependsOn.map { dependency in
                guard cardIDs.indices.contains(dependency), dependency < index
                else {
                    throw EngineContextValidationErrorV1()
                }
                return cardIDs[dependency]
            }
            let dependsOnJSON = String(
                decoding: try CanonicalJSONV1.encode(dependencyIDs),
                as: UTF8.self
            )
            guard companions.indices.contains(draft.assignee) else {
                throw EngineContextValidationErrorV1()
            }
            let assignee = companions[draft.assignee]
            if index == 0 {
                var card = canonical.card
                card.title = draft.title
                card.descriptionText = draft.description
                card.expectedOutput = draft.expectedOutput
                card.assigneeId = assignee.id
                card.status = .todo
                card.dependsOnJson = dependsOnJSON
                try card.update(database)
            } else {
                try CardRecord(
                    id: cardIDs[index],
                    missionId: canonical.mission.id,
                    idemKey: "ask-card-\(index)",
                    title: draft.title,
                    descriptionText: draft.description,
                    expectedOutput: draft.expectedOutput,
                    assigneeId: assignee.id,
                    status: .todo,
                    blockedReasonJson: nil,
                    dependsOnJson: dependsOnJSON,
                    handoffJson: nil,
                    stage: index + 1,
                    maxTurns: 8,
                    tokenBudget: 10_000,
                    createdAt: canonical.card.createdAt.addingTimeInterval(
                        Double(index)
                    )
                ).insert(database)
            }
        }
    }
    return AskMissionFixture(
        canonical: canonical,
        companions: companions
    )
}

private func askOrchestrator(
    db: AppDatabase,
    root: URL,
    providers: [String: any LLMProvider]
) -> Orchestrator {
    Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver {
            _, model in
            providers[model] ?? MockProvider(script: [])
        },
        makeProvider: { model, _ in providers[model] ?? MockProvider(script: []) },
        artifactStoreRoot: root.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
}

private func askReadyCauseSurfaceSnapshot(_ db: AppDatabase) throws -> [String] {
    try db.pool.read { database in
        let tables = [
            "event", "run", "engine_execution", "engine_session",
            "domain_command_receipt", "engine_terminal_proposal", "domain_event",
            "event_outbox", "camp_event_scope",
        ]
        func value(_ databaseValue: DatabaseValue) -> String {
            switch databaseValue.storage {
            case .null: return "null"
            case let .int64(integer): return "int:\(integer)"
            case let .double(double): return "double:\(double.bitPattern)"
            case let .string(string): return "string:\(string.utf8.count):\(string)"
            case let .blob(data): return "blob:\(data.base64EncodedString())"
            }
        }
        return try tables.map { table in
            let rows = try Row.fetchAll(
                database,
                sql: "SELECT rowid, * FROM \(table) ORDER BY rowid"
            )
            let renderedRows = rows.map { row in
                Array(row.databaseValues).map(value).joined(separator: "|")
            }.joined(separator: "\\n")
            return table + "=" + renderedRows
        }
    }
}

private func askReadyCauseError(
    _ db: AppDatabase,
    cardID: String
) throws -> EngineCardReadyCauseErrorV1? {
    do {
        try db.pool.read { database in
            let card = try #require(try CardRecord.fetchOne(database, key: cardID))
            _ = try db.resolveEngineCardReadyCause(for: card, in: database)
        }
        return nil
    } catch let error as EngineCardReadyCauseErrorV1 {
        return error
    }
}

private func askInsertInvalidReadyEvent(
    _ db: AppDatabase,
    missionID: String,
    cardID: String,
    payloadJSON: String
) throws {
    try askInsertRawScopedEvent(
        db,
        missionID: missionID,
        cardID: cardID,
        runID: nil,
        kind: EventKind.cardReady,
        payloadJSON: payloadJSON
    )
}

@discardableResult
private func askInsertRawScopedEvent(
    _ db: AppDatabase,
    missionID: String,
    cardID: String?,
    runID: String?,
    kind: String,
    payloadJSON: String
) throws -> EventRecord {
    let event = EventRecord(
        id: UUID().uuidString,
        missionId: missionID,
        cardId: cardID,
        runId: runID,
        kind: kind,
        payloadJson: payloadJSON,
        createdAt: Date()
    )
    try db.pool.write { database in
        guard let campID = try String.fetchOne(
            database,
            sql: """
                SELECT squad.campId
                FROM mission JOIN squad ON squad.id = mission.squadId
                WHERE mission.id = ?
                """,
            arguments: [missionID]
        ) else {
            throw RecordNotFoundError(table: "mission", id: missionID)
        }
        try database.execute(
            sql: """
                INSERT INTO camp_event_scope(
                  sourceTable,eventId,scopeKind,campId,payloadRedactedAt
                ) VALUES ('event',?,'camp',?,NULL)
                """,
            arguments: [event.id, campID]
        )
        try event.insert(database)
    }
    return event
}

private actor AskReadyCauseKernelErrors {
    private var count = 0

    func record(_ event: KernelEvent) {
        if case let .kernelError(_, message) = event,
           message == "卡片当前就绪事件无效，已暂停本次派发"
        {
            count += 1
        }
    }

    func snapshot() -> Int { count }
}

private struct AskReadyCauseListenerSignalTimeout: Error {}
private struct AskReadyCauseListenerSignalClosed: Error {}

private func askListenerSignal() -> (
    stream: AsyncStream<Void>,
    continuation: AsyncStream<Void>.Continuation
) {
    var continuation: AsyncStream<Void>.Continuation?
    let stream = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) {
        continuation = $0
    }
    return (stream, continuation!)
}

private func askWaitForListenerSignal(
    _ stream: AsyncStream<Void>,
    listener: Task<Void, Never>
) async throws {
    do {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                guard await iterator.next() != nil else {
                    throw AskReadyCauseListenerSignalClosed()
                }
            }
            group.addTask {
                try await ContinuousClock().sleep(for: .seconds(2))
                throw AskReadyCauseListenerSignalTimeout()
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    } catch {
        listener.cancel()
        throw error
    }
}

private func askUserTurn(
    kind: String = "choice",
    prompt: String = "选哪个？",
    options: [JSONValue] = ["A", "B"],
    id: String = UUID().uuidString
) -> TurnResult {
    var input: JSONValue = [
        "kind": .string(kind),
        "prompt": .string(prompt),
    ]
    if !options.isEmpty {
        input = [
            "kind": .string(kind),
            "prompt": .string(prompt),
            "options": .array(options),
        ]
    }
    return TurnResult(
        content: [.toolUse(id: id, name: "ask_user", input: input)],
        stopReason: .toolUse
    )
}

private func askCompleteTurn(summary: String = "done") -> TurnResult {
    TurnResult(
        content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
            "outcome": .string(summary),
            "summary": .string(summary),
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])],
        stopReason: .toolUse
    )
}

private func firstText(_ message: APIMessage) -> String {
    guard case .text(let text) = message.content.first else { return "" }
    return text
}

@Test func askUserSubmitsNeedsHumanInputThroughBoardSink() async throws {
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let tools = BoardTools(
        boardTerminalSink: board,
        progressSink: progress
    )

    let outcome = try await tools.askUser(input: [
        "kind": "choice",
        "prompt": "选哪个？",
        "options": ["A", "B"],
    ])
    guard case let .blocked(reason, detail) = outcome else {
        Issue.record("ask_user must stop the loop for human input")
        return
    }
    #expect(reason == "needs_human_input")
    #expect(detail == "选哪个？")
    #expect(await board.snapshot() == [.needsHumanInput(
        kind: .choice,
        prompt: "选哪个？",
        options: ["A", "B"]
    )])
    #expect(await progress.snapshot().isEmpty)
}

@Test func askUserValidationErrorsSelfHeal() async throws {
    let fixture = try makeAskBoardFixture()

    let badKind = try await fixture.tools.askUser(input: ["kind": "number", "prompt": "p"])
    guard case .error = badKind else {
        Issue.record("invalid kind should self-heal as tool error")
        return
    }
    let missingOptions = try await fixture.tools.askUser(input: ["kind": "choice", "prompt": "p"])
    guard case .error = missingOptions else {
        Issue.record("choice without options should self-heal as tool error")
        return
    }
    let oneOption = try await fixture.tools.askUser(input: [
        "kind": "choice",
        "prompt": "p",
        "options": ["only"],
    ])
    guard case .error = oneOption else {
        Issue.record("choice with one option should self-heal as tool error")
        return
    }

    #expect(await fixture.board.snapshot().isEmpty)
    #expect(await fixture.progress.snapshot().isEmpty)
}

@Test func answerResumesWithQAInContext() async throws {
    let fixture = try askMission(drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    defer { withExtendedLifetime(fixture) {} }
    let root = fixture.root
    let db = fixture.db
    let missionId = fixture.missionId
    let companions = fixture.companions
    let provider = MockProvider(script: [
        askUserTurn(prompt: "请选择执行路线", options: ["北线-唯一选项", "南线-唯一选项"]),
        askCompleteTurn(summary: "answered"),
    ])
    let orch = askOrchestrator(db: db, root: root, providers: [companions[0].model: provider])

    await orch.recoverAndReconcile()
    try await orch.waitUntilIdle()
    let request = try #require(
        try db.pendingUserRequests(missionId: missionId).first
    )
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":1}"#)
    try await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.done])
    let histories = await provider.recordedHistories
    #expect(histories.count == 2)
    guard let resumedHistory = histories.dropFirst().first,
          let resumedMessage = resumedHistory.first
    else {
        Issue.record("expected resumed provider history")
        await orch.shutdown()
        return
    }
    let resumed = firstText(resumedMessage)
    #expect(resumed.contains("# 此前你向用户提问的记录"))
    #expect(resumed.contains("请选择执行路线"))
    #expect(resumed.contains("南线-唯一选项"))
    await orch.shutdown()
}

@Test func answerStaleRequestThrows() async throws {
    let fixture = try askMission(drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    defer { withExtendedLifetime(fixture) {} }
    let root = fixture.root
    let db = fixture.db
    let missionId = fixture.missionId
    let companions = fixture.companions
    let provider = MockProvider(script: [askUserTurn()])
    let orch = askOrchestrator(db: db, root: root, providers: [companions[0].model: provider])

    await orch.recoverAndReconcile()
    try await orch.waitUntilIdle()
    let request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    await orch.cancelMission(missionId)

    await #expect(throws: StaleUserRequestError.self) {
        try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":0}"#)
    }
    #expect(try db.cards(missionId: missionId).map(\.status) == [.canceled])
    await orch.shutdown()
}

@Test func answerGuardRejectsMismatchedRequest() async throws {
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 10)
    try db.startRun(cardId: ids.cardId, runId: "run-1")
    let requestId = try db.suspendCardForUserRequest(
        cardId: ids.cardId,
        runId: "run-1",
        kind: .choice,
        prompt: "选？",
        options: ["A", "B"]
    )
    try db.transitionCard(id: ids.cardId, to: .ready, eventKind: "card_ready", payload: .object([:]))
    try db.blockCard(id: ids.cardId, runId: nil, reason: "tool_failure", detail: "工具失败")

    #expect(throws: StaleUserRequestError.self) {
        try db.answerUserRequest(requestId: requestId, answerJson: #"{"choice":0}"#)
    }
    let card = try #require(try db.card(id: ids.cardId))
    #expect(card.status == .blocked)
    #expect(card.blockedReasonJson?.contains("tool_failure") == true)
}

@Test func currentReadyCauseUsesOnlyTheFinalCanonicalReadyEvent() throws {
    // Mutation caught: deriving dispatch identity from Card status or a prior
    // transition rather than the rowid-current canonical card_ready event.
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "ready cause",
        squadName: "answer cause",
        goal: "answer only",
        cardTitle: "ask",
        cardDescription: "ask",
        expectedOutput: "answer",
        assigneeId: nil,
        maxTurns: 1
    )
    try db.startRun(cardId: ids.cardId, runId: "ready-cause-run")
    let requestID = try db.suspendCardForUserRequest(
        cardId: ids.cardId,
        runId: "ready-cause-run",
        kind: .choice,
        prompt: "choose",
        options: ["one", "two"]
    )
    try db.answerUserRequest(requestId: requestID, answerJson: #"{"choice":1}"#)

    let cause = try db.pool.read { database in
        let card = try #require(try CardRecord.fetchOne(database, key: ids.cardId))
        return try db.resolveEngineCardReadyCause(for: card, in: database)
    }
    let events = try db.events(cardId: ids.cardId)
    let ready = try #require(events.last)
    #expect(events.suffix(2).map(\.kind) == ["user_request_answered", "card_ready"])
    #expect(ready.kind == "card_ready")
    #expect(ready.payloadJson == #"{"answeredRequest":"\#(requestID)"}"#)
    #expect(cause.eventId == ready.id)
    #expect(cause.idempotencyKey == "engine.execution.v1:\(ready.id)")
    #expect(cause.answeredRequestId == requestID)
    #expect(cause.causalPredecessorExecutionId == nil)
}

@Test func approvalAnswerReadyPayloadIsEmptyAndReplayDoesNotAppendEvent() throws {
    // Mutation caught: a direct approval answer inheriting the nonapproval
    // answeredRequest cause, or a replay that appends a second ready event.
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "approval ready",
        squadName: "approval ready",
        goal: "approval",
        cardTitle: "approval",
        cardDescription: "approval",
        expectedOutput: "approval",
        assigneeId: nil,
        maxTurns: 1
    )
    let requestID = try db.suspendCardForApproval(
        cardId: ids.cardId,
        runId: nil,
        prompt: "approve?",
        tool: "write_file",
        input: ["path": "note.txt", "content": "ok"],
        inputHash: "hash"
    )
    try db.answerUserRequest(
        requestId: requestID,
        answerJson: #"{"decision":"approve"}"#
    )
    let beforeReplay = try db.events(cardId: ids.cardId)
    #expect(beforeReplay.suffix(3).map(\.kind) == [
        "user_request_answered", "approval_decided", "card_ready",
    ])
    #expect(beforeReplay.last?.payloadJson == "{}")
    let cause = try db.pool.read { database in
        let card = try #require(try CardRecord.fetchOne(database, key: ids.cardId))
        return try db.resolveEngineCardReadyCause(for: card, in: database)
    }
    #expect(cause.answeredRequestId == nil)
    #expect(cause.causalPredecessorExecutionId == nil)
    #expect(throws: StaleUserRequestError.self) {
        try db.answerUserRequest(
            requestId: requestID,
            answerJson: #"{"decision":"approve"}"#
        )
    }
    #expect(try db.events(cardId: ids.cardId).map(\.id) == beforeReplay.map(\.id))
}

@Test func readyCauseRejectsNoncanonicalMatchingRequestCreation() throws {
    // Mutation caught: treating a malformed matching user_request_created row
    // as a legacy question and silently returning a nil predecessor.
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "cause negative",
        squadName: "cause negative",
        goal: "cause negative",
        cardTitle: "cause negative",
        cardDescription: "cause negative",
        expectedOutput: "cause negative",
        assigneeId: nil,
        maxTurns: 1
    )
    try db.startRun(cardId: ids.cardId, runId: "cause-negative-run")
    let requestID = try db.suspendCardForUserRequest(
        cardId: ids.cardId,
        runId: "cause-negative-run",
        kind: .choice,
        prompt: "choose",
        options: ["one", "two"]
    )
    try db.answerUserRequest(requestId: requestID, answerJson: #"{"choice":1}"#)
    try askInsertRawScopedEvent(
        db,
        missionID: ids.missionId,
        cardID: ids.cardId,
        runID: "cause-negative-run",
        kind: EventKind.userRequestCreated,
        payloadJSON: #"{"userRequestId":"\#(requestID)","kind":"choice","prompt":"choose"}"#
    )
    let before = try askReadyCauseSurfaceSnapshot(db)
    let error = try #require(try askReadyCauseError(db, cardID: ids.cardId))
    guard case .brokenPredecessorGraph = error else {
        Issue.record("noncanonical matching creation must break the predecessor graph")
        return
    }
    #expect(try askReadyCauseSurfaceSnapshot(db) == before)
}

@Test func readyCauseIsStablePerEventAndChangesForNextReadyCycle() throws {
    // Mutation caught: Card-ID/status-derived idempotency that reuses a key
    // across ready cycles or changes when the same current event is reread.
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "cycle",
        squadName: "cycle",
        goal: "cycle",
        cardTitle: "cycle",
        cardDescription: "cycle",
        expectedOutput: "cycle",
        assigneeId: nil,
        maxTurns: 1
    )
    let first = try db.pool.read { database in
        let card = try #require(try CardRecord.fetchOne(database, key: ids.cardId))
        return try db.resolveEngineCardReadyCause(for: card, in: database)
    }
    let firstReplay = try db.pool.read { database in
        let card = try #require(try CardRecord.fetchOne(database, key: ids.cardId))
        return try db.resolveEngineCardReadyCause(for: card, in: database)
    }
    #expect(first == firstReplay)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.transitionCard(id: ids.cardId, to: .blocked, eventKind: "card_blocked", payload: .object([:]))
    try db.transitionCard(id: ids.cardId, to: .ready, eventKind: "card_ready", payload: .object([:]))
    let second = try db.pool.read { database in
        let card = try #require(try CardRecord.fetchOne(database, key: ids.cardId))
        return try db.resolveEngineCardReadyCause(for: card, in: database)
    }
    #expect(second.eventId != first.eventId)
    #expect(second.idempotencyKey != first.idempotencyKey)
}

@Test func readyCauseUsesExactOlderEngineNeedsHumanPredecessorDespiteNewerUnrelatedSession() throws {
    // Mutation caught: resolving a ready answer from the newest engine session
    // or execution instead of the exact engine-owned user_request_created row.
    let fixture = try P1F1EngineFixture()
    let target = try fixture.begin(key: "r9-a-target-engine")
    let prepared = try fixture.db.pool.read { database in
        try #require(try EngineExecutionRecord.fetchOne(database, key: target.executionId))
    }
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: target.executionId,
        expectedVersion: prepared.version,
        requestHash: target.requestHash,
        commandIdempotencyKey: "r9-a-target-engine-dispatch",
        now: p1f1EngineTestNow.addingTimeInterval(1)
    )
    let proposal = try fixture.store.recordEngineTerminalProposal(
        EngineTerminalProposalContentV1(
            protocolVersion: "agentloop.execution.v1",
            executionId: target.executionId,
            runId: target.runId,
            cardId: target.cardId,
            sequence: 0,
            terminalIdempotencyKey: "r9-a-target-needs-human",
            terminalKind: .blocked,
            terminalSubtype: .needsHumanInput,
            payload: .needsHumanInput(
                kind: .choice,
                prompt: "Choose the exact predecessor",
                options: ["older", "newer"]
            ),
            artifacts: []
        )
    )
    _ = try fixture.store.commitEngineAskUser(
        proposalId: proposal.proposal.id,
        checkedUsage: .zero,
        now: p1f1EngineTestNow.addingTimeInterval(2)
    )
    let request = try #require(
        try fixture.db.pendingUserRequests(missionId: p1f1EngineMissionID).first
    )
    try fixture.db.answerUserRequest(
        requestId: request.id,
        answerJson: #"{"choice":0}"#
    )

    // This is a real, later engine session on another card. It must not be
    // substituted for the target request's older, exact predecessor.
    let unrelatedCardID = "00000000-0000-4000-8000-000000009901"
    try fixture.insertReadyCard(unrelatedCardID, idemKey: "r9-a-unrelated")
    let unrelatedContextJSON = p1f1ContextGolden.replacingOccurrences(
        of: p1f1EngineCardID,
        with: unrelatedCardID
    )
    let unrelatedContextHash = CanonicalJSONV1.sha256Hex(
        Data(unrelatedContextJSON.utf8)
    )
    let unrelated = try fixture.begin(
        key: "r9-a-newer-unrelated",
        fields: try fixture.fields(
            cardID: unrelatedCardID,
            contextJson: unrelatedContextJSON,
            contextHash: unrelatedContextHash
        )
    )
    let unrelatedPrepared = try fixture.db.pool.read { database in
        try #require(try EngineExecutionRecord.fetchOne(database, key: unrelated.executionId))
    }
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: unrelated.executionId,
        expectedVersion: unrelatedPrepared.version,
        requestHash: unrelated.requestHash,
        commandIdempotencyKey: "r9-a-newer-unrelated-dispatch",
        now: p1f1EngineTestNow.addingTimeInterval(3)
    )
    try fixture.store.acceptEngineEvent(
        executionId: unrelated.executionId,
        sequence: 0,
        event: EngineExecutionEvent(
            executionId: unrelated.executionId,
            sequence: 0,
            payload: .sessionBound(externalSessionId: "r9-a-newer-session")
        )
    )
    let unrelatedSession = try fixture.db.pool.read { database in
        try #require(try EngineExecutionRecord.fetchOne(database, key: unrelated.executionId))
    }
    #expect(unrelatedSession.sessionId != nil)

    let cause = try fixture.db.pool.read { database in
        let card = try #require(try CardRecord.fetchOne(database, key: target.cardId))
        return try fixture.db.resolveEngineCardReadyCause(for: card, in: database)
    }
    #expect(cause.answeredRequestId == request.id)
    #expect(cause.causalPredecessorExecutionId == target.executionId)
    #expect(cause.causalPredecessorExecutionId != unrelated.executionId)
}

@Test func readyCauseInvalidGraphVariantsPerformZeroWrites() throws {
    // Mutation caught: a malformed/missing/ambiguous/broken predecessor graph
    // dispatching, appending diagnostics, or otherwise mutating persistent state.
    for variant in ["missing", "malformed", "ambiguous", "broken"] {
        let root = try askTempRoot()
        let db = try askTempDB(root: root)
        let ids = try db.createSingleCardMission(
            campName: "negative \(variant)", squadName: "negative \(variant)",
            goal: "negative \(variant)", cardTitle: "negative \(variant)",
            cardDescription: "negative", expectedOutput: "negative",
            assigneeId: nil, maxTurns: 1
        )

        switch variant {
        case "missing":
            // A ready Card whose rowid-current transition is card_started has
            // no current ready/interrupted/returned dispatch cause at all.
            try askInsertRawScopedEvent(
                db,
                missionID: ids.missionId,
                cardID: ids.cardId,
                runID: nil,
                kind: EventKind.cardStarted,
                payloadJSON: "{}"
            )
        case "malformed":
            try askInsertInvalidReadyEvent(
                db, missionID: ids.missionId, cardID: ids.cardId,
                payloadJSON: "{"
            )
        case "ambiguous":
            try db.startRun(cardId: ids.cardId, runId: "negative-\(variant)-run")
            let requestID = try db.suspendCardForUserRequest(
                cardId: ids.cardId, runId: "negative-\(variant)-run",
                kind: .choice, prompt: "choose", options: ["one", "two"]
            )
            try db.answerUserRequest(requestId: requestID, answerJson: #"{"choice":1}"#)
            let created = try #require(
                try db.events(cardId: ids.cardId).first { $0.kind == "user_request_created" }
            )
            try askInsertRawScopedEvent(
                db,
                missionID: ids.missionId,
                cardID: ids.cardId,
                runID: created.runId,
                kind: EventKind.userRequestCreated,
                payloadJSON: created.payloadJson
            )
        case "broken":
            try askInsertInvalidReadyEvent(
                db,
                missionID: ids.missionId,
                cardID: ids.cardId,
                payloadJSON:
                    #"{"answeredRequest":"00000000-0000-4000-8000-00000000BADD"}"#
            )
        default:
            Issue.record("uncovered ready-cause negative variant")
        }

        let before = try askReadyCauseSurfaceSnapshot(db)
        let error = try #require(try askReadyCauseError(db, cardID: ids.cardId))
        switch (variant, error) {
        case ("missing", .missingCurrentReadyEvent):
            break
        case ("malformed", .malformedReadyEvent):
            break
        case ("ambiguous", .ambiguousAnsweredRequest):
            break
        case ("broken", .brokenPredecessorGraph):
            break
        default:
            Issue.record("negative fixture produced the wrong closed ready-cause error")
        }
        #expect(try askReadyCauseSurfaceSnapshot(db) == before)
    }
}

@Test func readyCauseSuppressionRetriesForNewObservationAndFreshOrchestrator() async throws {
    // Mutation caught: persisting suppression, suppressing all future ready
    // observations, or failing to retry after an in-memory App restart.
    let root = try askTempRoot()
    let db = try askTempDB(root: root)
    let ids = try db.createSingleCardMission(
        campName: "suppression", squadName: "suppression", goal: "suppression",
        cardTitle: "suppression", cardDescription: "suppression",
        expectedOutput: "suppression", assigneeId: nil, maxTurns: 1
    )
    try askInsertInvalidReadyEvent(
        db, missionID: ids.missionId, cardID: ids.cardId, payloadJSON: "{"
    )
    let first = askOrchestrator(db: db, root: root, providers: [:])
    let firstRecorder = AskReadyCauseKernelErrors()
    let firstStarted = askListenerSignal()
    let firstFinished = askListenerSignal()
    let firstStream = await first.events()
    let firstListener = Task {
        firstStarted.continuation.yield(())
        firstStarted.continuation.finish()
        defer {
            firstFinished.continuation.yield(())
            firstFinished.continuation.finish()
        }
        for await event in firstStream {
            await firstRecorder.record(event)
            if await firstRecorder.snapshot() == 2 { break }
        }
    }
    defer { firstListener.cancel() }
    try await askWaitForListenerSignal(firstStarted.stream, listener: firstListener)
    await first.reconcile()

    // Manufacture a different malformed row after a genuine state transition;
    // the new observation must invalidate this actor's old suppression entry.
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try await db.pool.write { database in
        try database.execute(sql: "UPDATE card SET status='ready' WHERE id=?", arguments: [ids.cardId])
    }
    try askInsertInvalidReadyEvent(
        db, missionID: ids.missionId, cardID: ids.cardId, payloadJSON: "{"
    )
    let beforeSecond = try askReadyCauseSurfaceSnapshot(db)
    await first.reconcile()
    try await askWaitForListenerSignal(firstFinished.stream, listener: firstListener)
    #expect(await firstRecorder.snapshot() == 2)
    #expect(try askReadyCauseSurfaceSnapshot(db) == beforeSecond)

    let restarted = askOrchestrator(db: db, root: root, providers: [:])
    let restartRecorder = AskReadyCauseKernelErrors()
    let restartStarted = askListenerSignal()
    let restartFinished = askListenerSignal()
    let restartStream = await restarted.events()
    let restartListener = Task {
        restartStarted.continuation.yield(())
        restartStarted.continuation.finish()
        defer {
            restartFinished.continuation.yield(())
            restartFinished.continuation.finish()
        }
        for await event in restartStream {
            await restartRecorder.record(event)
            if await restartRecorder.snapshot() == 1 { break }
        }
    }
    defer { restartListener.cancel() }
    try await askWaitForListenerSignal(restartStarted.stream, listener: restartListener)
    let beforeRestart = try askReadyCauseSurfaceSnapshot(db)
    await restarted.reconcile()
    try await askWaitForListenerSignal(restartFinished.stream, listener: restartListener)
    #expect(await restartRecorder.snapshot() == 1)
    #expect(try askReadyCauseSurfaceSnapshot(db) == beforeRestart)
}

@Test func askingCompanionDoesNotBlockOthers() async throws {
    let fixture = try askMission(companionCount: 2, drafts: [
        .init(title: "Ask", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
        .init(title: "Done", description: "b", expectedOutput: "ob", assignee: 1, dependsOn: []),
    ])
    defer { withExtendedLifetime(fixture) {} }
    let root = fixture.root
    let db = fixture.db
    let missionId = fixture.missionId
    let companions = fixture.companions
    let asker = MockProvider(script: [askUserTurn()])
    let finisher = MockProvider(script: [askCompleteTurn()])
    let orch = askOrchestrator(db: db, root: root, providers: [
        companions[0].model: asker,
        companions[1].model: finisher,
    ])

    await orch.recoverAndReconcile()
    try await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.blocked, .done])
    #expect(try db.pendingUserRequests(missionId: missionId).count == 1)
    await orch.shutdown()
}

@Test func multipleQARoundsAccumulate() async throws {
    let fixture = try askMission(drafts: [
        .init(title: "A", description: "a", expectedOutput: "oa", assignee: 0, dependsOn: []),
    ])
    defer { withExtendedLifetime(fixture) {} }
    let root = fixture.root
    let db = fixture.db
    let missionId = fixture.missionId
    let companions = fixture.companions
    let provider = MockProvider(script: [
        askUserTurn(prompt: "第一题？", options: ["红队-唯一选项", "蓝队-唯一选项"]),
        askUserTurn(kind: "text", prompt: "第二题？", options: []),
        askCompleteTurn(summary: "answered twice"),
    ])
    let orch = askOrchestrator(db: db, root: root, providers: [companions[0].model: provider])

    await orch.recoverAndReconcile()
    try await orch.waitUntilIdle()
    var request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"choice":0}"#)
    try await orch.waitUntilIdle()
    request = try #require(try db.pendingUserRequests(missionId: missionId).first)
    try await orch.answerUserRequest(requestId: request.id, answerJson: #"{"text":"补充信息"}"#)
    try await orch.waitUntilIdle()

    #expect(try db.cards(missionId: missionId).map(\.status) == [.done])
    let histories = await provider.recordedHistories
    #expect(histories.count == 3)
    guard let finalHistory = histories.dropFirst(2).first,
          let finalMessage = finalHistory.first
    else {
        Issue.record("expected final provider history")
        await orch.shutdown()
        return
    }
    let finalUser = firstText(finalMessage)
    let firstRange = finalUser.range(of: "第一题？")
    let secondRange = finalUser.range(of: "第二题？")
    #expect(firstRange != nil && secondRange != nil)
    if let firstRange, let secondRange {
        #expect(firstRange.lowerBound < secondRange.lowerBound)
    }
    #expect(finalUser.contains("红队-唯一选项"))
    #expect(finalUser.contains("补充信息"))
    await orch.shutdown()
}

private struct AskBoardFixture {
    let tools: BoardTools
    let board: CardRunnerTestBoardRecorder
    let progress: CardRunnerTestProgressRecorder
}

private func makeAskBoardFixture() throws -> AskBoardFixture {
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    return AskBoardFixture(
        tools: BoardTools(
            boardTerminalSink: board,
            progressSink: progress
        ),
        board: board,
        progress: progress
    )
}
