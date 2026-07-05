import Testing
import Foundation
import AgentLoopCore

@Test func dmPersistsBothSidesAndFindsThread() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let companion = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "你是审校伙伴", model: "m")
    try db.saveCompanion(companion)

    let mock = MockProvider(script: [TurnResult(content: [.text("你好呀")], stopReason: .endTurn)])
    let chat = ChatService(db: db, provider: mock)
    var reply = ""
    for try await event in try chat.send(companionId: companion.id, userText: "在吗") {
        if case .textDelta(let text) = event {
            reply += text
        }
    }
    #expect(reply == "你好呀")

    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    let messages = try db.messages(threadId: thread.id)
    #expect(messages.count == 2)
    #expect(messages[0].role == "user" && messages[1].role == "companion")

    _ = try? await consume(chat.send(companionId: companion.id, userText: "再聊"))
    #expect(try db.messages(threadId: thread.id).count >= 3)
}

@Test func secondSendIncludesFirstExchangeInHistory() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let companion = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "审校伙伴", model: "m")
    try db.saveCompanion(companion)

    let mock = MockProvider(script: [
        TurnResult(content: [.text("回复一")], stopReason: .endTurn),
        TurnResult(content: [.text("回复二")], stopReason: .endTurn),
    ])
    let chat = ChatService(db: db, provider: mock)

    // First send
    for try await _ in try chat.send(companionId: companion.id, userText: "第一条") {}
    // Second send
    for try await _ in try chat.send(companionId: companion.id, userText: "第二条") {}

    // The second provider call should have received the first exchange in history
    let secondHistory = await mock.recordedHistories[1]
    // Expected: [user("第一条"), assistant("回复一"), user("第二条")]
    #expect(secondHistory.count == 3)
    #expect(secondHistory[0].role == .user)
    if case .text(let t) = secondHistory[0].content.first { #expect(t == "第一条") }
    #expect(secondHistory[1].role == .assistant)
    if case .text(let t) = secondHistory[1].content.first { #expect(t == "回复一") }
    #expect(secondHistory[2].role == .user)
    if case .text(let t) = secondHistory[2].content.first { #expect(t == "第二条") }
}

private func consume(_ stream: AsyncThrowingStream<ProviderEvent, Error>) async throws {
    for try await _ in stream {}
}

// MARK: - 伙伴记忆注入 DM system（M4，spec §10.1）

@Test func dmSystemCarriesCompanionMemory() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let companion = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "审校伙伴", model: "m")
    let other = CompanionRecord.new(name: "别人", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(companion)
    try db.saveCompanion(other)
    try db.saveCompanionNote(.new(companionId: companion.id, title: "用户偏好", bodyMd: "交付物要 markdown"))
    try db.saveCompanionNote(.new(companionId: other.id, title: "别人的记忆", bodyMd: "不该出现"))

    let mock = MockProvider(script: [TurnResult(content: [.text("好")], stopReason: .endTurn)])
    let chat = ChatService(db: db, provider: mock)
    for try await _ in try chat.send(companionId: companion.id, userText: "在吗") {}

    let system = await mock.recordedSystems[0]
    #expect(system.contains("# 你的记忆"))
    #expect(system.contains("交付物要 markdown"))
    // 记忆严格按伙伴隔离
    #expect(!system.contains("别人的记忆"))
}

@Test func dmSystemOmitsMemoryWhenNone() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let companion = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "审校伙伴", model: "m")
    try db.saveCompanion(companion)

    let mock = MockProvider(script: [TurnResult(content: [.text("好")], stopReason: .endTurn)])
    let chat = ChatService(db: db, provider: mock)
    for try await _ in try chat.send(companionId: companion.id, userText: "在吗") {}
    let system = await mock.recordedSystems[0]
    #expect(!system.contains("你的记忆"))
}
