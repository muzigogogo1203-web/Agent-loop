import Foundation

public struct CardRunner: Sendable {
    let db: AppDatabase
    let provider: any LLMProvider
    let artifactStoreRoot: URL
    let retryDelays: [Duration]
    let turnTimeout: Duration

    public init(
        db: AppDatabase,
        provider: any LLMProvider,
        artifactStoreRoot: URL,
        retryDelays: [Duration] = [.seconds(2), .seconds(4)],
        turnTimeout: Duration = KernelDefaults.turnTimeout
    ) {
        self.db = db
        self.provider = provider
        self.artifactStoreRoot = artifactStoreRoot
        self.retryDelays = retryDelays
        self.turnTimeout = turnTimeout
    }

    public func run(
        cardId: String,
        companionName: String,
        rolePrompt: String,
        upstreamHandoffs: [UpstreamHandoff] = [],
        answeredRequests: [(prompt: String, answer: String)] = [],
        campNotes: [NoteSnippet] = [],
        companionNotes: [NoteSnippet] = [],
        toolAccess: ToolAccess = .full,
        searchKey: String? = nil,
        autonomy: MissionAutonomy = .standard
    ) throws -> AsyncThrowingStream<AgentEvent, Error> {
        guard let card = try db.card(id: cardId) else {
            throw RecordNotFoundError(table: "card", id: cardId)
        }
        let squad = try db.squad(forCard: cardId)
        // M5-1：书签优先恢复工作目录权限（沙箱重启场景），path 兜底
        let workspaceAccess = WorkspaceScopedAccess(
            workspacePath: squad?.workspacePath,
            bookmark: squad?.workspaceBookmark)
        let workspace = workspaceAccess.url
        let runId = UUID().uuidString

        try db.startRun(cardId: cardId, runId: runId)

        let board = BoardTools(
            db: db,
            cardId: cardId,
            runId: runId,
            workspaceRoot: workspace,
            artifactStoreRoot: artifactStoreRoot
        )
        let files = FileTools(workspaceRoot: workspace)
        // M6-D4：白名单在此单点收口——handlers、提示词工具区、契约文本三处同源。
        // 板工具四件永远在场（终结契约 + 人工门，spec §5.2-4）。
        var handlers: [String: any ToolHandler] = [
            "complete_card": BoardToolHandler(tools: board, op: .complete),
            "block_card": BoardToolHandler(tools: board, op: .block),
            "add_progress_note": BoardToolHandler(tools: board, op: .note),
            "ask_user": BoardToolHandler(tools: board, op: .askUser),
        ]
        var capabilityHandlers: [String: any ToolHandler] = [
            "list_dir": FileToolHandler(tools: files, op: .list),
            "read_file": FileToolHandler(tools: files, op: .read),
            "write_file": FileToolHandler(tools: files, op: .write),
            "web_fetch": WebFetchTool(),
            "search_camp_notes": CampNotesSearchTool(db: db, campId: squad?.campId),
        ]
        // M6-D8：无 key 时 web_search 根本不装配——白名单 ∩ 可用性
        if let searchKey, !searchKey.isEmpty {
            capabilityHandlers["web_search"] = WebSearchTool(apiKey: searchKey)
        }
        for (name, handler) in capabilityHandlers where toolAccess.allows(name) {
            handlers[name] = handler
        }
        // M7-D3/D4：审批门套在非只读工具上——档位矩阵 + 一次性授权令牌（冷启动重跑时装罐）
        let approvalJar = ApprovalTokenJar((try? db.approvalDecisions(cardId: cardId)) ?? [])
        for (name, handler) in handlers where ToolDef.risk(name) != .readOnly {
            handlers[name] = ApprovalGateHandler(
                inner: handler, toolName: name, autonomy: autonomy,
                jar: approvalJar, db: db, cardId: cardId, runId: runId)
        }
        let executor = ToolExecutor(handlers: handlers)
        // 提示词工具区从 handlers 派生：可见即可用，构造上保证同源（D4/D8）
        let tools = ToolDef.agentTools.filter { handlers.keys.contains($0.name) }
        let packet = ContextPacket(
            companionName: companionName,
            rolePrompt: rolePrompt,
            cardTitle: card.title,
            cardDescription: card.descriptionText,
            expectedOutput: card.expectedOutput,
            workspacePath: workspace?.path,
            upstreamHandoffs: upstreamHandoffs,
            answeredRequests: answeredRequests,
            campNotes: campNotes,
            companionNotes: companionNotes,
            toolNames: tools.map(\.name)
        )
        let loop = AgentLoop(
            provider: provider,
            executor: executor,
            packet: packet,
            tools: tools,
            maxTurns: card.maxTurns,
            tokenBudget: card.tokenBudget,
            maxTokensPerTurn: KernelDefaults.maxTokensPerTurn,
            retryDelays: retryDelays,
            turnTimeout: turnTimeout
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                defer { workspaceAccess.stop() }
                var totalIn = 0
                var totalOut = 0
                var turns = 0
                var finalized = false
                do {
                    var sawFinished = false
                    for try await event in loop.run() {
                        switch event {
                        case .turnEnded(let usage):
                            totalIn += usage.inputTokens
                            totalOut += usage.outputTokens
                            turns += 1
                            continuation.yield(event)

                        case .finished(let outcome):
                            sawFinished = true
                            switch outcome {
                            case .completed:
                                finalized = true
                                try db.finishRun(
                                    id: runId,
                                    outcome: "completed",
                                    turns: turns,
                                    tokensIn: totalIn,
                                    tokensOut: totalOut
                                )
                            case .blocked(let reason, let detail):
                                finalized = true
                                try blockCardIfStillRunning(
                                    cardId: cardId,
                                    runId: runId,
                                    reason: reason,
                                    detail: detail
                                )
                                try db.finishRun(
                                    id: runId,
                                    outcome: "blocked",
                                    turns: turns,
                                    tokensIn: totalIn,
                                    tokensOut: totalOut
                                )
                            }
                            continuation.yield(event)

                        default:
                            continuation.yield(event)
                        }
                    }
                    // If the stream ended without a .finished event, the consumer cancelled us.
                    if !sawFinished && !finalized {
                        finalized = true
                        try? db.finishRun(
                            id: runId,
                            outcome: "canceled",
                            turns: turns,
                            tokensIn: totalIn,
                            tokensOut: totalOut
                        )
                        try? interruptCardIfStillRunning(cardId: cardId, runId: runId)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    if !finalized {
                        finalized = true
                        try? db.finishRun(
                            id: runId,
                            outcome: "canceled",
                            turns: turns,
                            tokensIn: totalIn,
                            tokensOut: totalOut
                        )
                        try? interruptCardIfStillRunning(cardId: cardId, runId: runId)
                    }
                    continuation.finish()
                } catch {
                    if !finalized {
                        finalized = true
                        let detail = Self.readableError(error)
                        try? db.finishRun(
                            id: runId,
                            outcome: "failed",
                            turns: turns,
                            tokensIn: totalIn,
                            tokensOut: totalOut
                        )
                        try? db.appendDiagnosticEvent(
                            cardId: cardId,
                            runId: runId,
                            kind: EventKind.runError,
                            payload: ["error": .string(detail), "turns": .number(Double(turns))]
                        )
                        try? blockCardIfStillRunning(
                            cardId: cardId,
                            runId: runId,
                            reason: "other",
                            detail: "运行错误：\(detail)"
                        )
                    }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func blockCardIfStillRunning(cardId: String, runId: String, reason: String, detail: String) throws {
        guard try db.card(id: cardId)?.status == .running else {
            return
        }
        try db.blockCard(id: cardId, runId: runId, reason: reason, detail: detail)
    }

    /// Transitions running→ready after a consumer cancellation (card_interrupted event).
    private func interruptCardIfStillRunning(cardId: String, runId: String) throws {
        guard try db.card(id: cardId)?.status == .running else {
            return
        }
        try db.transitionCard(
            id: cardId,
            to: .ready,
            eventKind: EventKind.cardInterrupted,
            payload: ["runId": .string(runId), "reason": "canceled"]
        )
    }

    private static func readableError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return String(describing: error)
    }
}
