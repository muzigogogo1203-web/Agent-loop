import Foundation
import os

public enum GuideChatEvent: Sendable {
    case textDelta(String)
    case toolActivity(name: String)
    case proposalCreated(messageId: String)
    case finished
}

/// 营地向导对话（spec §10.2，plan D4）：带工具的多轮聊天循环。
/// 与 AgentLoop 的区别：聊天无终结契约、无预算契约；工具往返 ≤6 轮，超限强制文本收尾。
/// 流模式对齐 ChatService：AsyncThrowingStream + 内部 Task + onTermination 取消；
/// 完整回复且未取消才落库；提案块在生成时即落库（重启后仍可确认）。
public struct GuideChatService: Sendable {
    package static let maxToolRounds = 6

    let db: AppDatabase
    let provider: any LLMProvider
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "guide")

    public init(db: AppDatabase, provider: any LLMProvider) {
        self.db = db
        self.provider = provider
    }

    public func send(campId: String, userText: String) throws -> AsyncThrowingStream<GuideChatEvent, Error> {
        guard let guide = try db.guide(campId: campId) else {
            throw RecordNotFoundError(table: "companion(guide)", id: campId)
        }
        let thread = try db.findOrCreateGuideThread(campId: campId)
        try db.appendChatMessage(threadId: thread.id, role: "user", text: userText)
        let initialHistory: [APIMessage] = try db.messages(threadId: thread.id).map { message in
            // 提案块进历史时渲染为占位文本（类型化块只给 UI 与确认动作消费）
            if let proposal = message.proposal {
                return .assistant([.text(proposal.historyPlaceholder)])
            }
            return APIMessage(
                role: message.role == "user" ? .user : .assistant,
                content: [.text(message.text)]
            )
        }
        let system = """
        你的名字是\(guide.name)。\(guide.rolePrompt)
        你是这个营地的常驻向导，与用户对话。你可以：
        - 用 search_camp_notes 检索营地笔记（往期经验）；
        - 用 camp_status 查看营地全景（行动进展、最近交付物）；
        - 用 propose_squad 提出组队开工提案。提案只是建议，用户确认后系统才会建队开工——不要替用户做决定，也不要重复提交相同提案。
        语气自然、有人情味，回答简洁。
        """

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var history = initialHistory
                    var fullReply = ""
                    var toolRounds = 0
                    while true {
                        let forceText = toolRounds >= Self.maxToolRounds
                        let turn = try await streamOneTurn(
                            system: system,
                            history: history,
                            tools: forceText ? [] : ToolDef.guideTools,
                            continuation: continuation
                        ) { delta in
                            fullReply += delta
                        }
                        let turnText = turn.content.compactMap { block -> String? in
                            if case .text(let t) = block { return t }
                            return nil
                        }.joined()

                        if turn.stopReason == .toolUse, !turn.toolUses.isEmpty, !forceText {
                            toolRounds += 1
                            history.append(.assistant(turn.content))
                            var results: [ContentBlock] = []
                            for use in turn.toolUses {
                                continuation.yield(.toolActivity(name: use.name))
                                let outcome = await execute(
                                    use: use, campId: campId, threadId: thread.id, continuation: continuation)
                                switch outcome {
                                case .result(let content):
                                    results.append(.toolResult(toolUseId: use.id, content: content, isError: false))
                                case .error(let message):
                                    results.append(.toolResult(toolUseId: use.id, content: message, isError: true))
                                case .completed, .blocked:
                                    // 向导工具不会产生终结语义；防御性兜底
                                    results.append(.toolResult(toolUseId: use.id, content: "工具返回了未知结果", isError: true))
                                }
                            }
                            history.append(.user(toolResults: results))
                            continue
                        }

                        _ = turnText
                        break
                    }

                    if !fullReply.isEmpty && !Task.isCancelled {
                        try db.appendChatMessage(threadId: thread.id, role: "guide", text: fullReply)
                    }
                    continuation.yield(.finished)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - 单轮流式

    private func streamOneTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        continuation: AsyncThrowingStream<GuideChatEvent, Error>.Continuation,
        onDelta: (String) -> Void
    ) async throws -> TurnResult {
        var turn: TurnResult?
        for try await event in provider.streamTurn(
            system: system,
            history: history,
            tools: tools,
            toolChoice: .auto,
            maxTokens: 4096
        ) {
            switch event {
            case .textDelta(let text):
                onDelta(text)
                continuation.yield(.textDelta(text))
            case .turn(let result):
                turn = result
            }
        }
        guard let turn else {
            throw ProviderError.malformedStream("no guide chat turn result")
        }
        return turn
    }

    // MARK: - 工具执行

    private func execute(
        use: (id: String, name: String, input: JSONValue),
        campId: String,
        threadId: String,
        continuation: AsyncThrowingStream<GuideChatEvent, Error>.Continuation
    ) async -> ToolOutcome {
        switch use.name {
        case "search_camp_notes":
            return await CampNotesSearchTool(db: db, campId: campId).execute(input: use.input)
        case "camp_status":
            return await CampStatusTool(db: db, campId: campId).execute(input: use.input)
        case "propose_squad":
            return proposeSquad(input: use.input, threadId: threadId, continuation: continuation)
        default:
            return .error("未知工具 \(use.name)")
        }
    }

    /// propose_squad（plan D5）：校验 → pending 提案块落库 → 通知 UI；
    /// tool_result 只告知「等待用户确认」，向导永不静默建队。
    private func proposeSquad(
        input: JSONValue,
        threadId: String,
        continuation: AsyncThrowingStream<GuideChatEvent, Error>.Continuation
    ) -> ToolOutcome {
        guard let name = input["name"]?.stringValue,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .error("提案缺少小队名 name")
        }
        guard let goal = input["goal"]?.stringValue,
              !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .error("提案缺少行动目标 goal")
        }
        guard let rawMemberIds = input["memberIds"]?.arrayValue?.compactMap(\.stringValue),
              !rawMemberIds.isEmpty else {
            return .error("提案缺少成员 memberIds（至少 1 位）")
        }
        var seen = Set<String>()
        let memberIds = rawMemberIds.filter { seen.insert($0).inserted }
        guard memberIds.count <= 6 else {
            return .error("成员最多 6 位，当前 \(memberIds.count) 位")
        }
        do {
            let members = try db.companions(ids: memberIds)
            if let guide = members.first(where: { $0.kind != .regular }) {
                return .error("成员 \(guide.name) 不在名册里（向导不能被指派小目标），请只从名册伙伴中选择")
            }
        } catch let error as RecordNotFoundError {
            return .error("成员 id 不存在：\(error.id)。请用名册里的伙伴 id 重新提案")
        } catch {
            return .error("成员校验失败：\(error.localizedDescription)")
        }
        let budget = input["budget"]?.intValue
        if let budget, budget <= 0 {
            return .error("budget 必须是正整数（token 数）")
        }

        let block = SquadProposalBlock(
            proposalId: UUID().uuidString,
            name: name,
            memberIds: memberIds,
            goal: goal,
            budget: budget,
            status: .pending
        )
        do {
            let messageId = try db.appendChatMessage(
                threadId: threadId, role: "guide", contentJson: try block.encodedString())
            continuation.yield(.proposalCreated(messageId: messageId))
            return .result("提案已生成，等待用户确认。不要重复提交相同提案；用户确认后系统会自动建队开工。")
        } catch {
            return .error("提案写入失败：\(error.localizedDescription)")
        }
    }
}
