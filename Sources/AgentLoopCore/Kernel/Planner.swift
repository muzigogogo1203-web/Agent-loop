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
    /// 规划全程累计 usage（M6-D13）：含重试轮与 fallback 前已消耗的部分
    public let usage: Usage

    public init(proposal: PlanProposal, fallbackReason: String?, usage: Usage = .init()) {
        self.proposal = proposal
        self.fallbackReason = fallbackReason
        self.usage = usage
    }
}

public struct Planner: Sendable {
    let provider: any LLMProvider
    let retryDelays: [Duration]

    public init(provider: any LLMProvider, retryDelays: [Duration] = [.seconds(2), .seconds(4)]) {
        self.provider = provider
        self.retryDelays = retryDelays
    }

    public func propose(
        goal: String,
        roster: [CompanionRecord],
        workspacePath: String?,
        campNotes: [NoteSnippet] = []
    ) async throws -> PlanResult {
        var history: [APIMessage] = [
            .user(userPrompt(goal: goal, roster: roster, workspacePath: workspacePath, campNotes: campNotes)),
        ]
        // M6-D13：跨轮累计 usage——第一轮成功、第二轮失败时，第一轮的钱也要入账
        var spent = Usage()
        do {
            let first = try await providerTurn(history: history)
            spent.add(first.usage)
            switch parse(first, rosterCount: roster.count) {
            case .valid(let proposal):
                return PlanResult(proposal: proposal, fallbackReason: nil, usage: spent)
            case .invalidToolUse(let toolUseId, let error):
                history.append(.assistant(first.content))
                history.append(.user(toolResults: [.toolResult(toolUseId: toolUseId, content: error, isError: true)]))
            case .noToolUse:
                history.append(.assistant(first.content))
                history.append(.user("必须调用 propose_plan 并给出全部必填参数。"))
            }

            let second = try await providerTurn(history: history)
            spent.add(second.usage)
            switch parse(second, rosterCount: roster.count) {
            case .valid(let proposal):
                return PlanResult(proposal: proposal, fallbackReason: nil, usage: spent)
            case .invalidToolUse, .noToolUse:
                return PlanResult(
                    proposal: Self.fallback(goal: goal),
                    fallbackReason: "invalid_after_retry", usage: spent)
            }
        } catch {
            if error is CancellationError { throw error }
            return PlanResult(proposal: Self.fallback(goal: goal), fallbackReason: "llm_failed", usage: spent)
        }
    }

    package func proposeDurable(
        goal: String,
        roster: [CompanionRecord],
        workspacePath: String?,
        campNotes: [NoteSnippet] = []
    ) async throws -> PlanResult {
        var history: [APIMessage] = [
            .user(
                userPrompt(
                    goal: goal,
                    roster: roster,
                    workspacePath: workspacePath,
                    campNotes: campNotes
                )
            ),
        ]
        var accumulatedUsage = Usage()

        let first = try await durableProviderTurn(
            history: history,
            accumulatedUsage: accumulatedUsage,
            hasCompletedUsage: false
        )
        accumulatedUsage = first.accumulatedUsage
        switch parse(first.turn, rosterCount: roster.count) {
        case .valid(let proposal):
            return PlanResult(
                proposal: proposal,
                fallbackReason: nil,
                usage: accumulatedUsage
            )
        case .invalidToolUse(let toolUseId, let error):
            history.append(.assistant(first.turn.content))
            history.append(
                .user(
                    toolResults: [
                        .toolResult(
                            toolUseId: toolUseId,
                            content: error,
                            isError: true
                        ),
                    ]
                )
            )
        case .noToolUse:
            history.append(.assistant(first.turn.content))
            history.append(
                .user("必须调用 propose_plan 并给出全部必填参数。")
            )
        }

        let correction = try await durableProviderTurn(
            history: history,
            accumulatedUsage: accumulatedUsage,
            hasCompletedUsage: true
        )
        accumulatedUsage = correction.accumulatedUsage
        switch parse(correction.turn, rosterCount: roster.count) {
        case .valid(let proposal):
            return PlanResult(
                proposal: proposal,
                fallbackReason: nil,
                usage: accumulatedUsage
            )
        case .invalidToolUse, .noToolUse:
            let failure = try PlanningAttemptFailure(
                code: "planning_contract_invalid",
                safeMessage: Self.safePlanningMessage(
                    code: "planning_contract_invalid"
                ),
                disposition: .deterministic,
                usage: accumulatedUsage
            )
            throw failure
        }
    }

    private enum ParseResult {
        case valid(PlanProposal)
        case invalidToolUse(toolUseId: String, error: String)
        case noToolUse
    }

    private struct DurableTurn {
        let turn: TurnResult
        let accumulatedUsage: Usage
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

    private func durableProviderTurn(
        history: [APIMessage],
        accumulatedUsage: Usage,
        hasCompletedUsage: Bool
    ) async throws -> DurableTurn {
        let turn: TurnResult
        do {
            turn = try await providerTurnOnce(history: history)
        } catch {
            if error is CancellationError {
                throw error
            }
            throw try Self.mapProviderFailure(
                error,
                usage: hasCompletedUsage ? accumulatedUsage : nil
            )
        }

        guard turn.usage.inputTokens >= 0,
              turn.usage.outputTokens >= 0,
              turn.usage.cacheReadTokens >= 0
        else {
            let failure = try PlanningAttemptFailure(
                code: "planning_usage_invalid",
                safeMessage: Self.safePlanningMessage(
                    code: "planning_usage_invalid"
                ),
                disposition: .deterministic,
                usage: hasCompletedUsage ? accumulatedUsage : nil
            )
            throw failure
        }

        return DurableTurn(
            turn: turn,
            accumulatedUsage: try Self.checkedPlanningUsageSum(
                accumulatedUsage,
                turn.usage
            )
        )
    }

    private func providerTurnOnce(
        history: [APIMessage]
    ) async throws -> TurnResult {
        var turn: TurnResult?
        let stream = await durableProviderStream(history: history)
        for try await event in stream {
            if case .turn(let result) = event {
                turn = result
            }
        }
        guard let turn else {
            throw ProviderError.malformedStream(
                "no planning turn result"
            )
        }
        return turn
    }

    private func durableProviderStream(
        history: [APIMessage]
    ) async -> AsyncThrowingStream<ProviderEvent, Error> {
        let provider = provider
        return await withUnsafeContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(
                    returning: provider.streamTurn(
                        system: Self.systemPrompt,
                        history: history,
                        tools: [Self.proposePlanTool],
                        toolChoice: .tool(name: "propose_plan"),
                        maxTokens: KernelDefaults.maxTokensPerTurn
                    )
                )
            }
        }
    }

    private static func checkedPlanningUsageSum(
        _ prior: Usage,
        _ incoming: Usage
    ) throws -> Usage {
        let priorCounters = try PlanningUsageCountersV1(usage: prior)
        let incomingCounters = try PlanningUsageCountersV1(usage: incoming)

        let (cacheReadTokens, cacheReadOverflow) =
            prior.cacheReadTokens.addingReportingOverflow(
                incoming.cacheReadTokens
            )
        let (inputTokens, inputOverflow) =
            prior.inputTokens.addingReportingOverflow(incoming.inputTokens)
        let (outputTokens, outputOverflow) =
            prior.outputTokens.addingReportingOverflow(
                incoming.outputTokens
            )

        var overflowFields: [PlanningUsageOverflowField] = []
        if cacheReadOverflow {
            overflowFields.append(.cacheReadTokens)
        }
        if inputOverflow {
            overflowFields.append(.inputTokens)
        }
        if outputOverflow {
            overflowFields.append(.outputTokens)
        }
        if !overflowFields.isEmpty {
            overflowFields.sort {
                $0.rawValue.utf8.lexicographicallyPrecedes(
                    $1.rawValue.utf8
                )
            }
            throw UsageOverflowError(
                evidence: .turnAggregate(
                    priorAccumulatedUsage: priorCounters,
                    incomingUsage: incomingCounters,
                    overflowFields: overflowFields
                )
            )
        }

        return Usage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens
        )
    }

    private static func mapProviderFailure(
        _ error: Error,
        usage: Usage?
    ) throws -> PlanningAttemptFailure {
        let code: String
        let disposition: DurableWorkFailureDisposition

        if error is URLError {
            code = "planning_transport_error"
            disposition = .transient
        } else if let providerError = error as? ProviderError {
            switch providerError {
            case .http(let status, _)
                where status == 429 || (500...599).contains(status):
                code = "planning_provider_unavailable"
                disposition = .transient
            case .overloadedRetriesExhausted:
                code = "planning_provider_unavailable"
                disposition = .transient
            case .apiError(let type, _)
                where type == "overloaded_error"
                    || type == "rate_limit_error"
                    || type == "server_error":
                code = "planning_provider_unavailable"
                disposition = .transient
            case .malformedStream:
                code = "planning_provider_malformed_response"
                disposition = .transient
            case .unauthorized:
                code = "planning_provider_unauthorized"
                disposition = .deterministic
            case .http:
                code = "planning_provider_http_error"
                disposition = .deterministic
            case .apiError:
                code = "planning_provider_api_error"
                disposition = .deterministic
            }
        } else {
            code = "planning_provider_failed"
            disposition = .deterministic
        }

        return try PlanningAttemptFailure(
            code: code,
            safeMessage: safePlanningMessage(code: code),
            disposition: disposition,
            usage: usage
        )
    }

    private static func safePlanningMessage(code: String) -> String {
        switch code {
        case "planning_contract_invalid":
            return "规划结果不符合约定格式。"
        case "planning_usage_invalid":
            return "规划模型返回了无效的用量数据。"
        case "planning_transport_error":
            return "规划模型网络连接失败。"
        case "planning_provider_unavailable":
            return "规划模型服务暂时不可用。"
        case "planning_provider_malformed_response":
            return "规划模型响应不完整。"
        case "planning_provider_unauthorized":
            return "规划模型凭据无效或无权限。"
        case "planning_provider_http_error":
            return "规划模型服务返回了无法处理的响应。"
        case "planning_provider_api_error":
            return "规划模型服务拒绝了本次请求。"
        case "planning_provider_failed":
            return "规划模型调用失败。"
        default:
            preconditionFailure("Unknown durable planning failure code")
        }
    }

    private func userPrompt(
        goal: String, roster: [CompanionRecord], workspacePath: String?, campNotes: [NoteSnippet]
    ) -> String {
        let rosterText = roster.enumerated().map { index, companion in
            "\(index). \(companion.name) — \(Self.truncate(Self.firstLine(companion.rolePrompt), max: 40))"
        }.joined(separator: "\n")
        let workspace = workspacePath == nil ? "未绑定工作目录" : "工作目录：\(workspacePath!)"
        var prompt = """
        目标原文：
        \(goal)

        名册：
        \(rosterText)

        \(workspace)
        """
        // 开工带经验（spec §9-2）：营地置顶+最近笔记进规划上下文
        if let notesSection = NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: campNotes) {
            prompt += "\n\n" + notesSection
        }
        prompt += "\n\n请规划 2–4 张串行依赖的小目标卡。每卡必须有可验证的 expectedOutput，assignee 只能填名册序号，dependsOn 只能引用更早的卡序号。"
        return prompt
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
