import Foundation

public struct ChatService: Sendable {
    let db: AppDatabase
    let provider: any LLMProvider

    public init(db: AppDatabase, provider: any LLMProvider) {
        self.db = db
        self.provider = provider
    }

    public func send(companionId: String, userText: String) throws -> AsyncThrowingStream<ProviderEvent, Error> {
        guard let companion = try db.companion(id: companionId) else {
            throw ProviderError.malformedStream("no companion")
        }
        let thread = try db.findOrCreateDMThread(companionId: companionId)
        try db.appendChatMessage(threadId: thread.id, role: "user", text: userText)
        let history: [APIMessage] = try db.messages(threadId: thread.id).map { message in
            APIMessage(
                role: message.role == "user" ? .user : .assistant,
                content: [.text(message.text)]
            )
        }
        let system = """
        你的名字是\(companion.name)。\(companion.rolePrompt)
        你正在与你的用户一对一聊天，语气自然、有人情味，回答简洁。
        """

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var fullReply = ""
                    for try await event in provider.streamTurn(
                        system: system,
                        history: history,
                        tools: [],
                        toolChoice: .auto,
                        maxTokens: 4096
                    ) {
                        if case .textDelta(let text) = event {
                            fullReply += text
                        }
                        continuation.yield(event)
                    }
                    // Only persist when there is a full reply and we were not cancelled.
                    if !fullReply.isEmpty && !Task.isCancelled {
                        try db.appendChatMessage(threadId: thread.id, role: "companion", text: fullReply)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
