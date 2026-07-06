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
        // 伙伴记忆注入（spec §10.1）：置顶全部 + 最近 3，严格按伙伴隔离
        let (pinned, recent) = try db.pinnedAndRecentCompanionNotes(companionId: companionId)
        let memorySection = NoteSnippet.renderSection(
            header: "你的记忆", snippets: NoteSnippet.from(pinned: pinned, recent: recent))
        let system = """
        你的名字是\(companion.name)。\(companion.rolePrompt)
        你正在与你的用户一对一聊天，语气自然、有人情味，回答简洁。
        """ + (memorySection.map { "\n\n" + $0 } ?? "")

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // 落库正文以 TurnResult 为权威（delta 只管显示）——
                    // 传输层断流兜底可能让 delta 序列不完整或不连续，累积 delta 会失真
                    var deltaAccum = ""
                    var turnText: String?
                    for try await event in provider.streamTurn(
                        system: system,
                        history: history,
                        tools: [],
                        toolChoice: .auto,
                        maxTokens: 4096
                    ) {
                        switch event {
                        case .textDelta(let text):
                            deltaAccum += text
                        case .turn(let result):
                            turnText = result.content.compactMap { block -> String? in
                                if case .text(let t) = block { return t }
                                return nil
                            }.joined()
                        }
                        continuation.yield(event)
                    }
                    let fullReply = turnText ?? deltaAccum
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
