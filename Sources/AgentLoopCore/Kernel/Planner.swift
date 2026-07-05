import Foundation

public struct PlanProposal: Sendable, Codable, Equatable {
    public let goalRefined: String
    public let cards: [CardDraft]

    public init(goalRefined: String, cards: [CardDraft]) {
        self.goalRefined = goalRefined
        self.cards = cards
    }

    public struct CardDraft: Sendable, Codable, Equatable {
        public let title: String
        public let description: String
        public let expectedOutput: String
        public let assignee: Int
        public let dependsOn: [Int]

        public init(title: String, description: String, expectedOutput: String, assignee: Int, dependsOn: [Int]) {
            self.title = title
            self.description = description
            self.expectedOutput = expectedOutput
            self.assignee = assignee
            self.dependsOn = dependsOn
        }
    }

    public func validate(rosterCount: Int) -> Result<PlanProposal, String> {
        guard (1...KernelDefaults.planMaxCards).contains(cards.count) else {
            return .failure("cards.count 必须在 1...\(KernelDefaults.planMaxCards)")
        }
        var normalizedCards: [CardDraft] = []
        for (index, card) in cards.enumerated() {
            if card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("cards[\(index)].title 不能为空")
            }
            if card.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("cards[\(index)].description 不能为空")
            }
            if card.expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("cards[\(index)].expectedOutput 不能为空")
            }
            guard card.assignee >= 0 && card.assignee < rosterCount else {
                return .failure("cards[\(index)].assignee 越界")
            }
            var seen = Set<Int>()
            var normalizedDependsOn: [Int] = []
            for dependency in card.dependsOn {
                guard dependency >= 0 && dependency < index else {
                    return .failure("cards[\(index)].dependsOn 只能引用更早的卡")
                }
                if seen.insert(dependency).inserted {
                    normalizedDependsOn.append(dependency)
                }
            }
            normalizedCards.append(
                CardDraft(
                    title: card.title,
                    description: card.description,
                    expectedOutput: card.expectedOutput,
                    assignee: card.assignee,
                    dependsOn: normalizedDependsOn
                )
            )
        }
        return .success(PlanProposal(goalRefined: goalRefined, cards: normalizedCards))
    }
}

public struct PlanResult: Sendable, Equatable {
    public let proposal: PlanProposal
    public let fallbackReason: String?

    public init(proposal: PlanProposal, fallbackReason: String?) {
        self.proposal = proposal
        self.fallbackReason = fallbackReason
    }
}

public struct Planner: Sendable {
    let provider: any LLMProvider
    let retryDelays: [Duration]

    public init(provider: any LLMProvider, retryDelays: [Duration] = [.seconds(2), .seconds(4)]) {
        self.provider = provider
        self.retryDelays = retryDelays
    }

    public func propose(goal: String, roster: [CompanionRecord], workspacePath: String?) async throws -> PlanResult {
        var history: [APIMessage] = [.user(userPrompt(goal: goal, roster: roster, workspacePath: workspacePath))]
        do {
            let first = try await providerTurn(history: history)
            switch parse(first, rosterCount: roster.count) {
            case .valid(let proposal):
                return PlanResult(proposal: proposal, fallbackReason: nil)
            case .invalidToolUse(let toolUseId, let error):
                history.append(.assistant(first.content))
                history.append(.user(toolResults: [.toolResult(toolUseId: toolUseId, content: error, isError: true)]))
            case .noToolUse:
                history.append(.assistant(first.content))
                history.append(.user("必须调用 propose_plan 并给出全部必填参数。"))
            }

            let second = try await providerTurn(history: history)
            switch parse(second, rosterCount: roster.count) {
            case .valid(let proposal):
                return PlanResult(proposal: proposal, fallbackReason: nil)
            case .invalidToolUse, .noToolUse:
                return PlanResult(proposal: Self.fallback(goal: goal), fallbackReason: "invalid_after_retry")
            }
        } catch {
            if error is CancellationError { throw error }
            return PlanResult(proposal: Self.fallback(goal: goal), fallbackReason: "llm_failed")
        }
    }

    private enum ParseResult {
        case valid(PlanProposal)
        case invalidToolUse(toolUseId: String, error: String)
        case noToolUse
    }

    private func parse(_ turn: TurnResult, rosterCount: Int) -> ParseResult {
        guard let toolUse = turn.toolUses.first(where: { $0.name == "propose_plan" }) else {
            return .noToolUse
        }
        do {
            let data = try JSONEncoder().encode(toolUse.input)
            let proposal = try JSONDecoder().decode(PlanProposal.self, from: data)
            switch proposal.validate(rosterCount: rosterCount) {
            case .success(let valid):
                return .valid(valid)
            case .failure(let message):
                return .invalidToolUse(toolUseId: toolUse.id, error: message)
            }
        } catch {
            return .invalidToolUse(toolUseId: toolUse.id, error: "propose_plan 参数格式不正确：\(error)")
        }
    }

    private func providerTurn(history: [APIMessage]) async throws -> TurnResult {
        var retryCount = 0
        while true {
            do {
                var turn: TurnResult?
                for try await event in provider.streamTurn(
                    system: Self.systemPrompt,
                    history: history,
                    tools: [Self.proposePlanTool],
                    toolChoice: .tool(name: "propose_plan"),
                    maxTokens: KernelDefaults.maxTokensPerTurn
                ) {
                    if case .turn(let result) = event {
                        turn = result
                    }
                }
                guard let turn else {
                    throw ProviderError.malformedStream("no planning turn result")
                }
                return turn
            } catch {
                if error is CancellationError { throw error }
                guard retryCount < retryDelays.count, Self.isRetryable(error) else {
                    throw error
                }
                retryCount += 1
                try Task.checkCancellation()
                try await Task.sleep(for: retryDelays[retryCount - 1])
            }
        }
    }

    private func userPrompt(goal: String, roster: [CompanionRecord], workspacePath: String?) -> String {
        let rosterText = roster.enumerated().map { index, companion in
            "\(index). \(companion.name) — \(Self.truncate(Self.firstLine(companion.rolePrompt), max: 40))"
        }.joined(separator: "\n")
        let workspace = workspacePath == nil ? "未绑定工作目录" : "工作目录：\(workspacePath!)"
        return """
        目标原文：
        \(goal)

        名册：
        \(rosterText)

        \(workspace)

        请规划 2–4 张串行依赖的小目标卡。每卡必须有可验证的 expectedOutput，assignee 只能填名册序号，dependsOn 只能引用更早的卡序号。
        """
    }

    private static let systemPrompt = """
    你是 AgentLoop 的行动规划者。你只能通过 propose_plan 工具输出规划，不要用普通文本给规划。
    """

    static let proposePlanTool = ToolDef(
        name: "propose_plan",
        description: "为行动目标提出小目标执行图。assignee 使用名册序号，dependsOn 使用更早卡片的 0-based 序号。",
        inputSchema: ToolDef.objectSchema([
            "goalRefined": ["type": "string"],
            "cards": [
                "type": "array",
                "items": ToolDef.objectSchema([
                    "title": ["type": "string"],
                    "description": ["type": "string"],
                    "expectedOutput": ["type": "string"],
                    "assignee": ["type": "integer"],
                    "dependsOn": ["type": "array", "items": ["type": "integer"]],
                ], required: ["title", "description", "expectedOutput", "assignee", "dependsOn"]),
            ],
        ], required: ["goalRefined", "cards"])
    )

    static func fallback(goal: String) -> PlanProposal {
        let title = truncate(firstLine(goal), max: 60)
        return PlanProposal(
            goalRefined: title,
            cards: [
                .init(
                    title: title,
                    description: goal,
                    expectedOutput: "完成行动目标，交付可验证的产物，并在交接包中说明验证方式",
                    assignee: 0,
                    dependsOn: []
                ),
            ]
        )
    }

    private static func firstLine(_ text: String) -> String {
        String(text.split(whereSeparator: \.isNewline).first ?? Substring(text))
    }

    private static func truncate(_ text: String, max: Int) -> String {
        String(text.prefix(max))
    }

    private static func isRetryable(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        guard let providerError = error as? ProviderError else {
            return false
        }
        switch providerError {
        case .http(let status, _):
            return (500...599).contains(status)
        case .overloadedRetriesExhausted, .malformedStream:
            return true
        case .apiError(let type, _):
            return type == "overloaded_error" || type == "api_error"
        case .unauthorized:
            return false
        }
    }
}
