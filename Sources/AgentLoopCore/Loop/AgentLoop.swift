import Foundation

public enum LoopOutcome: Sendable {
    case completed(HandoffPayload)
    case blocked(reason: String, detail: String)
}

public enum AgentEvent: Sendable {
    case textDelta(String)
    case toolStarted(name: String)
    case toolFinished(name: String, isError: Bool)
    case turnEnded(usage: Usage)
    case finished(LoopOutcome)
}

public struct AgentLoop: Sendable {
    let provider: any LLMProvider
    let executor: ToolExecutor
    let packet: ContextPacket
    let tools: [ToolDef]
    let maxTurns: Int
    let maxTokensPerTurn: Int

    public init(
        provider: any LLMProvider,
        executor: ToolExecutor,
        packet: ContextPacket,
        tools: [ToolDef],
        maxTurns: Int,
        maxTokensPerTurn: Int
    ) {
        self.provider = provider
        self.executor = executor
        self.packet = packet
        self.tools = tools
        self.maxTurns = maxTurns
        self.maxTokensPerTurn = maxTokensPerTurn
    }

    public func run() -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let outcome = try await loop(continuation: continuation)
                    continuation.yield(.finished(outcome))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func loop(
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws -> LoopOutcome {
        var history: [APIMessage] = [packet.firstUserMessage]
        var remindedAboutTerminator = false
        var pauseTurnCount = 0
        var strikes: [String: Int] = [:]
        var turns = 0

        while turns < maxTurns {
            turns += 1
            try Task.checkCancellation()

            var turn: TurnResult?
            for try await event in provider.streamTurn(
                system: packet.system,
                history: history,
                tools: tools,
                maxTokens: maxTokensPerTurn
            ) {
                switch event {
                case .textDelta(let text):
                    continuation.yield(.textDelta(text))
                case .turn(let result):
                    turn = result
                }
            }

            guard let result = turn else {
                try Task.checkCancellation()
                throw ProviderError.malformedStream("no turn result")
            }
            history.append(.assistant(result.content))
            continuation.yield(.turnEnded(usage: result.usage))

            switch result.stopReason {
            case .toolUse:
                guard !result.toolUses.isEmpty else {
                    throw ProviderError.malformedStream("stopReason=toolUse but no tool_use blocks in content")
                }
                var toolResults: [ContentBlock] = []
                for use in result.toolUses {
                    continuation.yield(.toolStarted(name: use.name))
                    let outcome = await executor.execute(name: use.name, input: use.input)

                    switch outcome {
                    case .completed(let handoff):
                        continuation.yield(.toolFinished(name: use.name, isError: false))
                        return .completed(handoff)
                    case .blocked(let reason, let detail):
                        continuation.yield(.toolFinished(name: use.name, isError: false))
                        return .blocked(reason: reason, detail: detail)
                    case .result(let content):
                        strikes[use.name] = 0
                        continuation.yield(.toolFinished(name: use.name, isError: false))
                        toolResults.append(.toolResult(toolUseId: use.id, content: content, isError: false))
                    case .error(let message):
                        let count = (strikes[use.name] ?? 0) + 1
                        strikes[use.name] = count
                        continuation.yield(.toolFinished(name: use.name, isError: true))
                        if count >= 3 {
                            return .blocked(
                                reason: "tool_failure",
                                detail: "工具 \(use.name) 连续失败 3 次：\(message)"
                            )
                        }
                        toolResults.append(.toolResult(toolUseId: use.id, content: message, isError: true))
                    }
                }
                history.append(.user(toolResults: toolResults))

            case .endTurn, .maxTokens, .stopSequence, .other:
                if remindedAboutTerminator {
                    return .blocked(
                        reason: "no_terminator",
                        detail: "伙伴结束了发言但没有调用 complete_card / block_card 收尾"
                    )
                }
                remindedAboutTerminator = true
                history.append(.user("你还没有收尾。必须调用 complete_card（工作已完成）或 block_card（无法继续）之一来结束这个小目标。"))

            case .pauseTurn:
                pauseTurnCount += 1
                if pauseTurnCount > 5 {
                    return .blocked(reason: "no_terminator", detail: "pause_turn 续接超过 5 次")
                }

            case .refusal:
                return .blocked(reason: "refusal", detail: "模型拒绝了这个请求，未重试")

            case .contextExceeded:
                return .blocked(reason: "budget_exhausted", detail: "上下文超限（M1 未实现压缩）")
            }
        }

        return .blocked(reason: "budget_exhausted", detail: "达到最大轮数 \(maxTurns)")
    }
}
