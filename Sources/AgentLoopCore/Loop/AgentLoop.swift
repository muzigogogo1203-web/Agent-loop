import Foundation
import os

public enum LoopOutcome: Sendable {
    case completed(HandoffPayload)
    case blocked(reason: String, detail: String)
}

public struct TurnTimeoutError: Error, Sendable, Equatable {}

public enum AgentEvent: Sendable {
    /// Emitted before every provider attempt, including retried attempts for the same turn.
    case turnStarted
    case textDelta(String)
    case toolStarted(name: String)
    case toolFinished(name: String, isError: Bool)
    case turnEnded(usage: Usage)
    case turnRetrying(attempt: Int, reason: String)
    case finished(LoopOutcome)
}

public struct AgentLoop: Sendable {
    let provider: any LLMProvider
    let executor: ToolExecutor
    let packet: ContextPacket
    let tools: [ToolDef]
    let maxTurns: Int
    let tokenBudget: Int
    let maxTokensPerTurn: Int
    let retryDelays: [Duration]
    let turnTimeout: Duration
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "loop")

    public init(
        provider: any LLMProvider,
        executor: ToolExecutor,
        packet: ContextPacket,
        tools: [ToolDef],
        maxTurns: Int,
        tokenBudget: Int,
        maxTokensPerTurn: Int,
        retryDelays: [Duration] = [.seconds(2), .seconds(4)],
        turnTimeout: Duration = KernelDefaults.turnTimeout
    ) {
        self.provider = provider
        self.executor = executor
        self.packet = packet
        self.tools = tools
        self.maxTurns = maxTurns
        self.tokenBudget = tokenBudget
        self.maxTokensPerTurn = maxTokensPerTurn
        self.retryDelays = retryDelays
        self.turnTimeout = turnTimeout
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
        var spentTokens = 0

        while turns < maxTurns && spentTokens < tokenBudget {
            turns += 1
            try Task.checkCancellation()

            let result: TurnResult
            do {
                result = try await providerTurnWithRetry(
                    history: history,
                    turnNumber: turns,
                    continuation: continuation
                )
            } catch is TurnTimeoutError {
                return .blocked(reason: "tool_failure", detail: "本轮连续两次超时，已暂停等待处理")
            }
            history.append(.assistant(result.content))
            spentTokens = Self.saturatingTokenSum(
                spentTokens,
                result.usage.inputTokens,
                result.usage.outputTokens
            )
            continuation.yield(.turnEnded(usage: result.usage))
            Self.logger.info("turn \(turns, privacy: .public) stop_reason \(String(describing: result.stopReason), privacy: .public)")

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

        if spentTokens >= tokenBudget {
            return .blocked(reason: "budget_exhausted", detail: "已用 \(spentTokens)/\(tokenBudget) tokens")
        }
        return .blocked(reason: "budget_exhausted", detail: "达到最大轮数 \(maxTurns)")
    }

    private static func saturatingTokenSum(_ current: Int, _ input: Int, _ output: Int) -> Int {
        let safeInput = max(0, input)
        let safeOutput = max(0, output)
        let (partial, overflowA) = current.addingReportingOverflow(safeInput)
        let (total, overflowB) = partial.addingReportingOverflow(safeOutput)
        return (overflowA || overflowB) ? Int.max : total
    }

    private func providerTurnWithRetry(
        history: [APIMessage],
        turnNumber: Int,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws -> TurnResult {
        var retryCount = 0
        // Counts idle timeouts within this provider turn only; transport retries stay separate.
        var timeoutCount = 0
        while true {
            continuation.yield(.turnStarted)
            Self.logger.info("turn \(turnNumber, privacy: .public) started")
            do {
                return try await providerTurnAttempt(history: history, continuation: continuation)
            } catch is TurnTimeoutError {
                try Task.checkCancellation()
                timeoutCount += 1
                guard timeoutCount < 2 else {
                    throw TurnTimeoutError()
                }
                continuation.yield(.turnRetrying(attempt: timeoutCount, reason: "本轮超时"))
                Self.logger.info("turn \(turnNumber, privacy: .public) idle timeout retry \(timeoutCount, privacy: .public)")
            } catch {
                if error is CancellationError {
                    throw error
                }
                guard retryCount < retryDelays.count, Self.isRetryable(error) else {
                    Self.logger.error("turn \(turnNumber, privacy: .public) final error: \(Self.readableError(error), privacy: .public)")
                    throw error
                }

                retryCount += 1
                let reason = Self.readableError(error)
                continuation.yield(.turnRetrying(attempt: retryCount, reason: reason))
                Self.logger.info("turn \(turnNumber, privacy: .public) retry \(retryCount, privacy: .public): \(reason, privacy: .public)")
                try Task.checkCancellation()
                try await Task.sleep(for: retryDelays[retryCount - 1])
            }
        }
    }

    private func providerTurnAttempt(
        history: [APIMessage],
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws -> TurnResult {
        let watchdog = IdleWatchdog(timeout: turnTimeout)
        return try await withThrowingTaskGroup(of: TurnResult.self) { group in
            group.addTask {
                var turn: TurnResult?
                for try await event in provider.streamTurn(
                    system: packet.system,
                    history: history,
                    tools: tools,
                    toolChoice: .auto,
                    maxTokens: maxTokensPerTurn
                ) {
                    await watchdog.beat(timeout: turnTimeout)
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
                return result
            }
            group.addTask {
                try await watchdog.waitForTimeout()
                throw TurnTimeoutError()
            }

            do {
                guard let result = try await group.next() else {
                    throw ProviderError.malformedStream("no turn result")
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                try Task.checkCancellation()
                throw error
            }
        }
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

    private static func readableError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return String(describing: error)
    }
}

private actor IdleWatchdog {
    private let clock: ContinuousClock
    private var deadline: ContinuousClock.Instant

    init(timeout: Duration) {
        let clock = ContinuousClock()
        self.clock = clock
        deadline = clock.now.advanced(by: timeout)
    }

    func beat(timeout: Duration) {
        deadline = clock.now.advanced(by: timeout)
    }

    func waitForTimeout() async throws {
        while !Task.isCancelled {
            let target = deadline
            try await clock.sleep(until: target)
            try Task.checkCancellation()
            if clock.now >= deadline {
                throw TurnTimeoutError()
            }
        }
    }
}
