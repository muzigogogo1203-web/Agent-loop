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

private func consume(_ stream: AsyncThrowingStream<ProviderEvent, Error>) async throws {
    for try await _ in stream {}
}
