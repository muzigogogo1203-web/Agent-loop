import Foundation

public struct ChatService: Sendable {
    let db: AppDatabase
    let provider: any LLMProvider

    public init(db: AppDatabase, provider: any LLMProvider) {
        self.db = db
        self.provider = provider
    }

    public func send(companionId: String, userText: String) throws -> AsyncThrowingStream<ProviderEvent, Error> {
        let preparation = try db.prepareDMChatTurn(
            companionId: companionId,
            userText: userText
        )
        let memorySection = NoteSnippet.renderSection(
            header: "你的记忆",
            snippets: NoteSnippet.from(
                pinned: preparation.pinnedNotes,
                recent: preparation.recentNotes
            )
        )
        let system = """
        你的名字是\(preparation.companion.name)。\(preparation.companion.rolePrompt)
        你正在与你的用户一对一聊天，语气自然、有人情味，回答简洁。
        """ + (memorySection.map { "\n\n" + $0 } ?? "")

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var authoritativeTurn: TurnResult?
                    for try await event in provider.streamTurn(
                        system: system,
                        history: preparation.history,
                        tools: [],
                        toolChoice: .auto,
                        maxTokens: 4096
                    ) {
                        switch event {
                        case .textDelta:
                            break
                        case .turn(let result):
                            guard authoritativeTurn == nil else {
                                throw ProviderError.malformedStream(
                                    "multiple DM turn results"
                                )
                            }
                            authoritativeTurn = result
                        }
                        continuation.yield(event)
                    }
                    guard let turn = authoritativeTurn else {
                        throw ProviderError.malformedStream(
                            "missing DM turn result"
                        )
                    }
                    let parts = try turn.content.map { block -> String in
                        guard case .text(let text) = block else {
                            throw ProviderError.malformedStream(
                                "non-text DM turn result"
                            )
                        }
                        return text
                    }
                    let fullReply = parts.joined()
                    guard !fullReply.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty else {
                        throw ProviderError.malformedStream(
                            "empty DM turn result"
                        )
                    }
                    try Task.checkCancellation()
                    try db.appendChatMessage(
                        threadId: preparation.thread.id,
                        role: "companion",
                        text: fullReply
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
