import Testing
import Foundation
import GRDB
import AgentLoopCore

private func memoryTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func noteTurn(title: String, body: String) -> TurnResult {
    TurnResult(content: [.text("{\"title\":\"\(title)\",\"body\":\"\(body)\"}")], stopReason: .endTurn)
}

private func seedDM(_ db: AppDatabase, count: Int) throws -> CompanionRecord {
    let companion = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "审校", model: "m")
    try db.saveCompanion(companion)
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    for index in 0..<count {
        try db.appendChatMessage(threadId: thread.id, role: index % 2 == 0 ? "user" : "companion", text: "消息\(index)")
    }
    return companion
}

private actor MemoryGatedProvider: LLMProvider {
    private var pending: AsyncThrowingStream<ProviderEvent, Error>.Continuation?
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.enqueue(continuation) }
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release(_ turn: TurnResult) {
        guard let pending else { return }
        self.pending = nil
        for block in turn.content {
            if case .text(let text) = block {
                pending.yield(.textDelta(text))
            }
        }
        pending.yield(.turn(turn))
        pending.finish()
    }

    private func enqueue(_ continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) {
        pending = continuation
        started = true
        let current = waiters
        waiters.removeAll()
        for waiter in current { waiter.resume() }
    }
}

private struct MemoryThrowingProvider: LLMProvider, Sendable {
    let error: ProviderError

    func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

private func seedGuide(
    _ db: AppDatabase,
    count: Int
) throws -> (camp: CampRecord, thread: ChatThreadRecord) {
    let camp = try db.ensureDefaultCamp()
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    for index in 0..<count {
        try db.appendChatMessage(
            threadId: thread.id,
            role: index % 2 == 0 ? "user" : "guide",
            text: "向导消息\(index)"
        )
    }
    return (camp, thread)
}

@discardableResult
private func requireMemoryFailure<Record: Sendable>(
    _ terminal: MemoryDistillTerminal<Record>,
    database: AppDatabase,
    code: FailureCode,
    operation: FailureOperation,
    scopeID: String
) throws -> UserVisibleFailure {
    guard case .failed(let failure) = terminal else {
        Issue.record("expected failed memory terminal")
        throw MemoryDistillError.invalidPayload
    }
    #expect(failure.operation == operation)
    #expect(failure.scope.type == .application)
    #expect(failure.scope.id == scopeID)
    #expect(failure.message.contains(failure.traceId))
    let record = try database.failureRecord(id: failure.traceId)
    #expect(record?.errorCode == code)
    #expect(record?.operation == operation)
    #expect(record?.scope == failure.scope)
    return failure
}

private func requireCaptureViolation(
    _ expected: MemoryDistillCaptureViolation,
    _ operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("expected invalid captured messages")
    } catch let error as MemoryDistillError {
        #expect(error == .invalidCapturedMessages(expected))
    } catch {
        Issue.record("unexpected capture validation error")
    }
}

// MARK: - DM 沉淀（D7）

@Test func manualDistillCreatesMemoryAndAdvancesWatermark() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 2)
    let service = MemoryDistillService(
        db: db, provider: MockProvider(script: [noteTurn(title: "用户偏好", body: "- markdown")]))

    let terminal = await service.distillDM(companionId: companion.id, minMessages: 1)
    guard case .created(let record) = terminal else {
        Issue.record("expected created memory terminal")
        return
    }
    #expect(record.title == "用户偏好")
    #expect(record.sourceThreadId != nil)

    let notes = try db.companionNotes(companionId: companion.id)
    #expect(notes.count == 1)

    // 水位已推进
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    #expect(try db.undistilledMessages(threadId: thread.id).isEmpty)

    // 事件审计
    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "companion_note_created").fetchAll(database)
    }
    #expect(events.count == 1)
}

@Test func autoDistillRespectsMinMessagesThreshold() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 3) // 少于阈值 4
    let service = MemoryDistillService(
        db: db, provider: MockProvider(script: [noteTurn(title: "不该产出", body: "x")]))

    let terminal = await service.distillDM(
        companionId: companion.id, minMessages: MemoryDistillService.autoMinMessages)
    guard case .noEligibleInput = terminal else {
        Issue.record("expected no-eligible-input terminal")
        return
    }
    // 未触发：水位不动、无记忆
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    #expect(try db.undistilledMessages(threadId: thread.id).count == 3)
    #expect(try db.companionNotes(companionId: companion.id).isEmpty)
}

@Test func skipStillAdvancesWatermarkButNoNote() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 4)
    let service = MemoryDistillService(
        db: db, provider: MockProvider(script: [
            TurnResult(content: [.text("{\"skip\":true}")], stopReason: .endTurn),
        ]))

    let terminal = await service.distillDM(companionId: companion.id, minMessages: 1)
    guard case .skipped = terminal else {
        Issue.record("expected skipped terminal")
        return
    }
    #expect(try db.companionNotes(companionId: companion.id).isEmpty)
    // skip 也推水位：琐碎增量不会反复送蒸
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    #expect(try db.undistilledMessages(threadId: thread.id).isEmpty)
}

@Test func failureKeepsWatermarkForRetry() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 4)
    let service = MemoryDistillService(db: db, provider: MockProvider(script: [])) // 必失败

    let terminal = await service.distillDM(companionId: companion.id, minMessages: 1)
    guard case .failed = terminal else {
        Issue.record("expected failed memory terminal")
        return
    }
    // 失败静默留水位，下次触发重试（spec §10.1）
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    #expect(try db.undistilledMessages(threadId: thread.id).count == 4)
}

@Test func dmNoteInsertFailureRollsBackWatermarkAndEvent() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 2)
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_companion_note_insert
            BEFORE INSERT ON companion_note BEGIN
                SELECT RAISE(ABORT, 'injected companion note failure');
            END
            """)
    }
    let service = MemoryDistillService(
        db: db,
        provider: MockProvider(script: [noteTurn(title: "不应落库", body: "x")])
    )

    let terminal = await service.distillDM(companionId: companion.id, minMessages: 1)

    guard case .failed = terminal else {
        Issue.record("expected failed memory terminal")
        return
    }
    #expect(try db.undistilledMessages(threadId: thread.id).count == 2)
    #expect(try db.companionNotes(companionId: companion.id).isEmpty)
    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "companion_note_created").fetchAll(database)
    }
    #expect(events.isEmpty)
}

@Test func distillationEventInsertFailureRollsBackNoteAndWatermark() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 2)
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_companion_note_event_insert
            BEFORE INSERT ON event
            WHEN NEW.kind = 'companion_note_created' BEGIN
                SELECT RAISE(ABORT, 'injected companion note event failure');
            END
            """)
    }
    let service = MemoryDistillService(
        db: db,
        provider: MockProvider(script: [noteTurn(title: "不应落库", body: "x")])
    )

    let terminal = await service.distillDM(companionId: companion.id, minMessages: 1)

    guard case .failed = terminal else {
        Issue.record("expected failed memory terminal")
        return
    }
    #expect(try db.undistilledMessages(threadId: thread.id).count == 2)
    #expect(try db.companionNotes(companionId: companion.id).isEmpty)
    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "companion_note_created").fetchAll(database)
    }
    #expect(events.isEmpty)
}

@Test func staleDistillationCASRollsBackWithoutDuplicateNote() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 2)
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    let capturedIds = try db.undistilledMessages(threadId: thread.id).map(\.id)
    // 模型工作期间新到的消息不属于本次水位。
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "模型工作期间到达")

    let winner = CompanionNoteRecord.new(
        companionId: companion.id,
        sourceThreadId: thread.id,
        title: "赢家",
        bodyMd: "first"
    )
    let loser = CompanionNoteRecord.new(
        companionId: companion.id,
        sourceThreadId: thread.id,
        title: "输家",
        bodyMd: "second"
    )

    #expect(try db.persistCompanionDistillation(
        note: winner,
        capturedMessageIds: capturedIds
    ))
    #expect(throws: MemoryDistillRaceLostError.self) {
        try db.persistCompanionDistillation(
            note: loser,
            capturedMessageIds: capturedIds
        )
    }

    let notes = try db.companionNotes(companionId: companion.id)
    #expect(notes.map(\.title) == ["赢家"])
    #expect(try db.undistilledMessages(threadId: thread.id).map(\.text) == ["模型工作期间到达"])
    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "companion_note_created").fetchAll(database)
    }
    #expect(events.count == 1)
    #expect(events.first?.payloadJson.contains(winner.id) == true)
}

@Test func messageArrivingDuringModelWorkRemainsUndistilled() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 2)
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    let provider = MemoryGatedProvider()
    let service = MemoryDistillService(db: db, provider: provider)

    let distillation = Task {
        await service.distillDM(companionId: companion.id, minMessages: 1)
    }
    await provider.waitUntilStarted()
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "模型工作期间到达")
    await provider.release(noteTurn(title: "已捕获增量", body: "旧消息"))

    let terminal = await distillation.value
    guard case .created(let record) = terminal else {
        Issue.record("expected created memory terminal")
        return
    }
    #expect(record.title == "已捕获增量")
    #expect(try db.undistilledMessages(threadId: thread.id).map(\.text) == ["模型工作期间到达"])
}

// MARK: - 向导对话沉淀（D9）

@Test func guideChatDistillCreatesCampNote() async throws {
    let db = try memoryTempDB()
    let camp = try db.ensureDefaultCamp()
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "我们决定先修桥再探岭")
    try db.appendChatMessage(threadId: thread.id, role: "guide", text: "记下了，桥优先")

    let service = MemoryDistillService(
        db: db, provider: MockProvider(script: [noteTurn(title: "营地决策：桥优先", body: "- 先修桥")]))
    let terminal = await service.distillGuideChat(campId: camp.id)
    guard case .created(let record) = terminal else {
        Issue.record("expected created guide terminal")
        return
    }
    #expect(record.title == "营地决策：桥优先")
    #expect(record.missionId == nil)

    let notes = try db.campNotes(campId: camp.id)
    #expect(notes.count == 1)
    #expect(try db.undistilledMessages(threadId: thread.id).isEmpty)

    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "camp_note_created").fetchAll(database)
    }
    #expect(events.first?.payloadJson.contains("guide_chat") == true)
}

@Test func guideChatDistillNoopWhenNoBacklog() async throws {
    let db = try memoryTempDB()
    let camp = try db.ensureDefaultCamp()
    let service = MemoryDistillService(db: db, provider: MockProvider(script: []))
    let terminal = await service.distillGuideChat(campId: camp.id)
    guard case .noEligibleInput = terminal else {
        Issue.record("expected no-eligible-input guide terminal")
        return
    }
    #expect(try db.campNotes(campId: camp.id).isEmpty)
}

@Test func guideNoteInsertFailureRollsBackWatermarkAndEvent() async throws {
    let db = try memoryTempDB()
    let camp = try db.ensureDefaultCamp()
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "需要沉淀")
    try await db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_camp_note_insert
            BEFORE INSERT ON camp_note BEGIN
                SELECT RAISE(ABORT, 'injected camp note failure');
            END
            """)
    }
    let service = MemoryDistillService(
        db: db,
        provider: MockProvider(script: [noteTurn(title: "不应落库", body: "x")])
    )

    let terminal = await service.distillGuideChat(campId: camp.id)

    guard case .failed = terminal else {
        Issue.record("expected failed guide terminal")
        return
    }
    #expect(try db.undistilledMessages(threadId: thread.id).count == 1)
    #expect(try db.campNotes(campId: camp.id).isEmpty)
    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "camp_note_created").fetchAll(database)
    }
    #expect(events.isEmpty)
}

// MARK: - P1-B observable Memory terminals

@Test func memoryDistillNoEligibleInputIsDistinct() async throws {
    let dmDatabase = try memoryTempDB()
    let companion = try seedDM(dmDatabase, count: 0)
    let dmProvider = MockProvider(script: [])
    let dmTerminal = await MemoryDistillService(
        db: dmDatabase,
        provider: dmProvider
    ).distillDM(companionId: companion.id, minMessages: 1)
    guard case .noEligibleInput = dmTerminal else {
        Issue.record("DM no-input was not distinct")
        return
    }
    #expect(await dmProvider.callCount == 0)

    let guideDatabase = try memoryTempDB()
    let guide = try seedGuide(guideDatabase, count: 0)
    let guideProvider = MockProvider(script: [])
    let guideTerminal = await MemoryDistillService(
        db: guideDatabase,
        provider: guideProvider
    ).distillGuideChat(campId: guide.camp.id)
    guard case .noEligibleInput = guideTerminal else {
        Issue.record("guide no-input was not distinct")
        return
    }
    #expect(await guideProvider.callCount == 0)

    let invalidProvider = MockProvider(script: [])
    let invalid = await MemoryDistillService(
        db: dmDatabase,
        provider: invalidProvider
    ).distillDM(companionId: companion.id, minMessages: 0)
    try requireMemoryFailure(
        invalid,
        database: dmDatabase,
        code: .projectionContractFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
    #expect(await invalidProvider.callCount == 0)
}

@Test func memoryDistillProviderSkipAdvancesWatermarkAndReturnsSkipped()
    async throws
{
    let dmDatabase = try memoryTempDB()
    let companion = try seedDM(dmDatabase, count: 2)
    let dmThread = try dmDatabase.findOrCreateDMThread(
        companionId: companion.id
    )
    let dmTerminal = await MemoryDistillService(
        db: dmDatabase,
        provider: MockProvider(script: [
            TurnResult(
                content: [.text(#"{"skip":true}"#)],
                stopReason: .endTurn
            ),
        ])
    ).distillDM(companionId: companion.id, minMessages: 1)
    guard case .skipped = dmTerminal else {
        Issue.record("DM provider skip was not distinct")
        return
    }
    #expect(try dmDatabase.undistilledMessages(threadId: dmThread.id).isEmpty)
    #expect(try dmDatabase.companionNotes(companionId: companion.id).isEmpty)

    let guideDatabase = try memoryTempDB()
    let guide = try seedGuide(guideDatabase, count: 2)
    let guideTerminal = await MemoryDistillService(
        db: guideDatabase,
        provider: MockProvider(script: [
            TurnResult(
                content: [.text(#"{"skip":true}"#)],
                stopReason: .endTurn
            ),
        ])
    ).distillGuideChat(campId: guide.camp.id)
    guard case .skipped = guideTerminal else {
        Issue.record("guide provider skip was not distinct")
        return
    }
    #expect(try guideDatabase.undistilledMessages(
        threadId: guide.thread.id
    ).isEmpty)
    #expect(try guideDatabase.campNotes(campId: guide.camp.id).isEmpty)

    let validationDatabase = try memoryTempDB()
    requireCaptureViolation(.empty) {
        try validationDatabase.advanceDistillationWatermark(
            capturedMessageIds: []
        )
    }
    requireCaptureViolation(.blankMessageID) {
        try validationDatabase.advanceDistillationWatermark(
            capturedMessageIds: ["valid", " \n "]
        )
    }
    requireCaptureViolation(.blankMessageID) {
        try validationDatabase.advanceDistillationWatermark(
            capturedMessageIds: [" ", " "]
        )
    }
    requireCaptureViolation(.duplicateMessageID) {
        try validationDatabase.advanceDistillationWatermark(
            capturedMessageIds: ["id", "id"]
        )
    }
    try validationDatabase.markDistilled(messageIds: [])
    requireCaptureViolation(.duplicateMessageID) {
        try validationDatabase.markDistilled(messageIds: ["id", "id"])
    }
}

@Test func memoryDistillCreatedReturnsRecord() async throws {
    let dmDatabase = try memoryTempDB()
    let companion = try seedDM(dmDatabase, count: 2)
    let dmTerminal = await MemoryDistillService(
        db: dmDatabase,
        provider: MockProvider(script: [
            noteTurn(title: "DM 创建", body: "记录"),
        ])
    ).distillDM(companionId: companion.id, minMessages: 1)
    guard case .created(let dmRecord) = dmTerminal else {
        Issue.record("expected created DM record")
        return
    }
    #expect(dmRecord.title == "DM 创建")
    #expect(try dmDatabase.companionNotes(
        companionId: companion.id
    ).map(\.id) == [dmRecord.id])

    let guideDatabase = try memoryTempDB()
    let guide = try seedGuide(guideDatabase, count: 2)
    let guideTerminal = await MemoryDistillService(
        db: guideDatabase,
        provider: MockProvider(script: [
            noteTurn(title: "Guide 创建", body: "记录"),
        ])
    ).distillGuideChat(campId: guide.camp.id)
    guard case .created(let guideRecord) = guideTerminal else {
        Issue.record("expected created guide record")
        return
    }
    #expect(guideRecord.title == "Guide 创建")
    #expect(try guideDatabase.campNotes(
        campId: guide.camp.id
    ).map(\.id) == [guideRecord.id])

    let validationDatabase = try memoryTempDB()
    let companionNote = CompanionNoteRecord.new(
        companionId: "capture-owner",
        title: "invalid",
        bodyMd: "invalid"
    )
    let guideNote = CampNoteRecord.new(
        campId: "capture-camp",
        title: "invalid",
        bodyMd: "invalid"
    )
    for violation in MemoryDistillCaptureViolation.allTestValues {
        let ids = violation.testMessageIDs
        requireCaptureViolation(violation) {
            _ = try validationDatabase.persistCompanionDistillation(
                note: companionNote,
                capturedMessageIds: ids
            )
        }
        requireCaptureViolation(violation) {
            _ = try validationDatabase.persistGuideDistillation(
                note: guideNote,
                capturedMessageIds: ids
            )
        }
    }

    let rawDatabase = try memoryTempDB()
    let rawCompanion = try seedDM(rawDatabase, count: 2)
    let rawThread = try rawDatabase.findOrCreateDMThread(
        companionId: rawCompanion.id
    )
    let capturedIDs = try rawDatabase.undistilledMessages(
        threadId: rawThread.id
    ).map(\.id)
    #expect(try rawDatabase.persistCompanionDistillation(
        note: .new(
            companionId: rawCompanion.id,
            sourceThreadId: rawThread.id,
            title: "raw winner",
            bodyMd: "ok"
        ),
        capturedMessageIds: capturedIDs
    ))
}

@Test func memoryDistillProviderFailureReturnsFailedWithTrace() async throws {
    for status in [100, 599, 99, 600] {
        let database = try memoryTempDB()
        let companion = try seedDM(database, count: 1)
        let terminal = await MemoryDistillService(
            db: database,
            provider: MemoryThrowingProvider(
                error: .http(status: status, body: "secret-external-body")
            )
        ).distillDM(companionId: companion.id, minMessages: 1)
        let failure = try requireMemoryFailure(
            terminal,
            database: database,
            code: .memoryProviderFailed,
            operation: .memoryDMDistill,
            scopeID: "memory_dm"
        )
        let diagnostics = try database.failureRecord(
            id: failure.traceId
        )?.diagnosticJson ?? ""
        #expect(!diagnostics.contains("secret-external-body"))
        if (100...599).contains(status) {
            #expect(diagnostics.contains("\"httpStatus\":\(status)"))
        } else {
            #expect(!diagnostics.contains("httpStatus"))
        }
    }

    let guideDatabase = try memoryTempDB()
    let guide = try seedGuide(guideDatabase, count: 1)
    let guideFailure = await MemoryDistillService(
        db: guideDatabase,
        provider: MockProvider(script: [])
    ).distillGuideChat(campId: guide.camp.id)
    try requireMemoryFailure(
        guideFailure,
        database: guideDatabase,
        code: .memoryProviderFailed,
        operation: .memoryGuideDistill,
        scopeID: "memory_guide"
    )

    let invalidDatabase = try memoryTempDB()
    let invalidCompanion = try seedDM(invalidDatabase, count: 1)
    let invalid = await MemoryDistillService(
        db: invalidDatabase,
        provider: MockProvider(script: [
            TurnResult(content: [.text("not JSON")], stopReason: .endTurn),
        ])
    ).distillDM(companionId: invalidCompanion.id, minMessages: 1)
    try requireMemoryFailure(
        invalid,
        database: invalidDatabase,
        code: .projectionDecodeFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
}

@Test func memoryDistillReadFailureReturnsFailedWithTrace() async throws {
    let missingDM = try memoryTempDB()
    let missingDMTerminal = await MemoryDistillService(
        db: missingDM,
        provider: MockProvider(script: [])
    ).distillDM(companionId: "missing", minMessages: 1)
    try requireMemoryFailure(
        missingDMTerminal,
        database: missingDM,
        code: .memoryOwnerNotFound,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )

    let missingGuide = try memoryTempDB()
    let missingGuideTerminal = await MemoryDistillService(
        db: missingGuide,
        provider: MockProvider(script: [])
    ).distillGuideChat(campId: "missing")
    try requireMemoryFailure(
        missingGuideTerminal,
        database: missingGuide,
        code: .memoryOwnerNotFound,
        operation: .memoryGuideDistill,
        scopeID: "memory_guide"
    )

    let invalidRoleDatabase = try memoryTempDB()
    let invalidRoleCompanion = try seedDM(invalidRoleDatabase, count: 0)
    let invalidRoleThread = try invalidRoleDatabase.findOrCreateDMThread(
        companionId: invalidRoleCompanion.id
    )
    try invalidRoleDatabase.appendChatMessage(
        threadId: invalidRoleThread.id,
        role: "system",
        text: "must not be projected"
    )
    let invalidRole = await MemoryDistillService(
        db: invalidRoleDatabase,
        provider: MockProvider(script: [])
    ).distillDM(companionId: invalidRoleCompanion.id, minMessages: 1)
    try requireMemoryFailure(
        invalidRole,
        database: invalidRoleDatabase,
        code: .projectionDecodeFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )

    let duplicateDatabase = try memoryTempDB()
    let duplicateCompanion = try seedDM(duplicateDatabase, count: 1)
    let duplicateThread = try duplicateDatabase.findOrCreateDMThread(
        companionId: duplicateCompanion.id
    )
    try await duplicateDatabase.pool.write { database in
        let duplicateID = UUID().uuidString
        let createdAt = Date()
        try database.execute(sql: "PRAGMA defer_foreign_keys=ON")
        try database.execute(
            sql: """
                INSERT INTO legacy_chat_scope(
                  threadId,scopeKind,campId,cowId,evidenceKind,createdAt
                ) VALUES (?,'globalCow',NULL,?,'dmThread',?)
                """,
            arguments: [duplicateID, duplicateCompanion.id, createdAt]
        )
        try ChatThreadRecord(
            id: duplicateID,
            kind: .dm,
            companionId: duplicateCompanion.id,
            campId: nil,
            createdAt: createdAt
        ).insert(database)
    }
    let duplicate = await MemoryDistillService(
        db: duplicateDatabase,
        provider: MockProvider(script: [])
    ).distillDM(companionId: duplicateCompanion.id, minMessages: 1)
    try requireMemoryFailure(
        duplicate,
        database: duplicateDatabase,
        code: .memoryThreadInvariantFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
    #expect(try duplicateDatabase.undistilledMessages(
        threadId: duplicateThread.id
    ).count == 1)

    let readDatabase = try memoryTempDB()
    let readCompanion = try seedDM(readDatabase, count: 1)
    try await readDatabase.pool.write { database in
        try database.execute(
            sql: "ALTER TABLE chat_message RENAME TO unavailable_chat_message"
        )
    }
    let readFailure = await MemoryDistillService(
        db: readDatabase,
        provider: MockProvider(script: [])
    ).distillDM(companionId: readCompanion.id, minMessages: 1)
    try requireMemoryFailure(
        readFailure,
        database: readDatabase,
        code: .memoryReadFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
}

@Test func memoryDistillPersistenceFailureReturnsFailedWithTrace()
    async throws
{
    let dmDatabase = try memoryTempDB()
    let dmCompanion = try seedDM(dmDatabase, count: 2)
    let dmThread = try dmDatabase.findOrCreateDMThread(
        companionId: dmCompanion.id
    )
    try await dmDatabase.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_p1b_memory_note
            BEFORE INSERT ON companion_note BEGIN
                SELECT RAISE(ABORT, 'injected memory note failure');
            END
            """)
    }
    let dmTerminal = await MemoryDistillService(
        db: dmDatabase,
        provider: MockProvider(script: [noteTurn(title: "fail", body: "fail")])
    ).distillDM(companionId: dmCompanion.id, minMessages: 1)
    try requireMemoryFailure(
        dmTerminal,
        database: dmDatabase,
        code: .memoryWriteFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
    #expect(try dmDatabase.undistilledMessages(threadId: dmThread.id).count == 2)
    #expect(try dmDatabase.companionNotes(companionId: dmCompanion.id).isEmpty)

    let guideDatabase = try memoryTempDB()
    let guide = try seedGuide(guideDatabase, count: 2)
    try await guideDatabase.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_p1b_guide_event
            BEFORE INSERT ON event
            WHEN NEW.kind = 'camp_note_created' BEGIN
                SELECT RAISE(ABORT, 'injected guide event failure');
            END
            """)
    }
    let guideTerminal = await MemoryDistillService(
        db: guideDatabase,
        provider: MockProvider(script: [noteTurn(title: "fail", body: "fail")])
    ).distillGuideChat(campId: guide.camp.id)
    try requireMemoryFailure(
        guideTerminal,
        database: guideDatabase,
        code: .memoryWriteFailed,
        operation: .memoryGuideDistill,
        scopeID: "memory_guide"
    )
    #expect(try guideDatabase.undistilledMessages(
        threadId: guide.thread.id
    ).count == 2)
    #expect(try guideDatabase.campNotes(campId: guide.camp.id).isEmpty)

    let watermarkDatabase = try memoryTempDB()
    let watermarkCompanion = try seedDM(watermarkDatabase, count: 1)
    let watermarkThread = try watermarkDatabase.findOrCreateDMThread(
        companionId: watermarkCompanion.id
    )
    try await watermarkDatabase.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_p1b_watermark
            BEFORE UPDATE OF distilled ON chat_message
            WHEN NEW.distilled = 1 BEGIN
                SELECT RAISE(ABORT, 'injected watermark failure');
            END
            """)
    }
    let watermarkTerminal = await MemoryDistillService(
        db: watermarkDatabase,
        provider: MockProvider(script: [
            TurnResult(
                content: [.text(#"{"skip":true}"#)],
                stopReason: .endTurn
            ),
        ])
    ).distillDM(companionId: watermarkCompanion.id, minMessages: 1)
    try requireMemoryFailure(
        watermarkTerminal,
        database: watermarkDatabase,
        code: .memoryWriteFailed,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
    #expect(try watermarkDatabase.undistilledMessages(
        threadId: watermarkThread.id
    ).count == 1)
}

private func runDMMemoryRace(created: Bool) async throws {
    let database = try memoryTempDB()
    let companion = try seedDM(database, count: 2)
    let thread = try database.findOrCreateDMThread(companionId: companion.id)
    let capturedIDs = try database.undistilledMessages(
        threadId: thread.id
    ).map(\.id)
    let provider = MemoryGatedProvider()
    let service = MemoryDistillService(db: database, provider: provider)
    let loser = Task {
        await service.distillDM(companionId: companion.id, minMessages: 1)
    }
    await provider.waitUntilStarted()
    try database.appendChatMessage(
        threadId: thread.id,
        role: "user",
        text: "new arrival"
    )
    if created {
        #expect(try database.persistCompanionDistillation(
            note: .new(
                companionId: companion.id,
                sourceThreadId: thread.id,
                title: "winner",
                bodyMd: "winner"
            ),
            capturedMessageIds: capturedIDs
        ))
        await provider.release(noteTurn(title: "loser", body: "loser"))
    } else {
        try database.advanceDistillationWatermark(
            capturedMessageIds: capturedIDs
        )
        await provider.release(
            TurnResult(
                content: [.text(#"{"skip":true}"#)],
                stopReason: .endTurn
            )
        )
    }
    let terminal = await loser.value
    try requireMemoryFailure(
        terminal,
        database: database,
        code: .memoryRaceLost,
        operation: .memoryDMDistill,
        scopeID: "memory_dm"
    )
    #expect(try database.undistilledMessages(
        threadId: thread.id
    ).map(\.text) == ["new arrival"])
    #expect(try database.companionNotes(
        companionId: companion.id
    ).map(\.title) == (created ? ["winner"] : []))
    if created {
        #expect(throws: MemoryDistillRaceLostError.self) {
            try database.persistCompanionDistillation(
                note: .new(
                    companionId: companion.id,
                    sourceThreadId: thread.id,
                    title: "raw loser",
                    bodyMd: "raw loser"
                ),
                capturedMessageIds: capturedIDs
            )
        }
    } else {
        #expect(throws: MemoryDistillRaceLostError.self) {
            try database.advanceDistillationWatermark(
                capturedMessageIds: capturedIDs
            )
        }
    }
}

private func runGuideMemoryRace(created: Bool) async throws {
    let database = try memoryTempDB()
    let guide = try seedGuide(database, count: 2)
    let capturedIDs = try database.undistilledMessages(
        threadId: guide.thread.id
    ).map(\.id)
    let provider = MemoryGatedProvider()
    let service = MemoryDistillService(db: database, provider: provider)
    let loser = Task {
        await service.distillGuideChat(campId: guide.camp.id)
    }
    await provider.waitUntilStarted()
    try database.appendChatMessage(
        threadId: guide.thread.id,
        role: "user",
        text: "new arrival"
    )
    if created {
        #expect(try database.persistGuideDistillation(
            note: .new(
                campId: guide.camp.id,
                title: "winner",
                bodyMd: "winner"
            ),
            capturedMessageIds: capturedIDs
        ))
        await provider.release(noteTurn(title: "loser", body: "loser"))
    } else {
        try database.advanceDistillationWatermark(
            capturedMessageIds: capturedIDs
        )
        await provider.release(
            TurnResult(
                content: [.text(#"{"skip":true}"#)],
                stopReason: .endTurn
            )
        )
    }
    let terminal = await loser.value
    try requireMemoryFailure(
        terminal,
        database: database,
        code: .memoryRaceLost,
        operation: .memoryGuideDistill,
        scopeID: "memory_guide"
    )
    #expect(try database.undistilledMessages(
        threadId: guide.thread.id
    ).map(\.text) == ["new arrival"])
    #expect(try database.campNotes(
        campId: guide.camp.id
    ).map(\.title) == (created ? ["winner"] : []))
    if created {
        #expect(throws: MemoryDistillRaceLostError.self) {
            try database.persistGuideDistillation(
                note: .new(
                    campId: guide.camp.id,
                    title: "raw loser",
                    bodyMd: "raw loser"
                ),
                capturedMessageIds: capturedIDs
            )
        }
    } else {
        #expect(throws: MemoryDistillRaceLostError.self) {
            try database.advanceDistillationWatermark(
                capturedMessageIds: capturedIDs
            )
        }
    }
}

@Test func memoryDistillWatermarkRaceReturnsFailedWithTrace() async throws {
    try await runDMMemoryRace(created: false)
    try await runDMMemoryRace(created: true)
    try await runGuideMemoryRace(created: false)
    try await runGuideMemoryRace(created: true)
}

private extension MemoryDistillCaptureViolation {
    static let allTestValues: [Self] = [
        .empty,
        .blankMessageID,
        .duplicateMessageID,
    ]

    var testMessageIDs: [String] {
        switch self {
        case .empty:
            return []
        case .blankMessageID:
            return ["valid", " \n "]
        case .duplicateMessageID:
            return ["id", "id"]
        }
    }
}
