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

// MARK: - DM 沉淀（D7）

@Test func manualDistillCreatesMemoryAndAdvancesWatermark() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 2)
    let service = MemoryDistillService(
        db: db, provider: MockProvider(script: [noteTurn(title: "用户偏好", body: "- markdown")]))

    let record = await service.distillDM(companionId: companion.id, minMessages: 1)
    #expect(record?.title == "用户偏好")
    #expect(record?.sourceThreadId != nil)

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

    let record = await service.distillDM(
        companionId: companion.id, minMessages: MemoryDistillService.autoMinMessages)
    #expect(record == nil)
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

    let record = await service.distillDM(companionId: companion.id, minMessages: 1)
    #expect(record == nil)
    #expect(try db.companionNotes(companionId: companion.id).isEmpty)
    // skip 也推水位：琐碎增量不会反复送蒸
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    #expect(try db.undistilledMessages(threadId: thread.id).isEmpty)
}

@Test func failureKeepsWatermarkForRetry() async throws {
    let db = try memoryTempDB()
    let companion = try seedDM(db, count: 4)
    let service = MemoryDistillService(db: db, provider: MockProvider(script: [])) // 必失败

    let record = await service.distillDM(companionId: companion.id, minMessages: 1)
    #expect(record == nil)
    // 失败静默留水位，下次触发重试（spec §10.1）
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    #expect(try db.undistilledMessages(threadId: thread.id).count == 4)
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
    let record = await service.distillGuideChat(campId: camp.id)
    #expect(record?.title == "营地决策：桥优先")
    #expect(record?.missionId == nil)

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
    let record = await service.distillGuideChat(campId: camp.id)
    #expect(record == nil)
    #expect(try db.campNotes(campId: camp.id).isEmpty)
}
