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
    /// 上下文压缩完成（M5-3）：fromMessages → toMessages
    case contextCompacted(fromMessages: Int, toMessages: Int)
    case finished(LoopOutcome)
}

package struct AgentLoopRunHandleV1: Sendable {
    package let events: AsyncThrowingStream<AgentEvent, Error>
    package let completion: Task<Void, Error>
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
    private let idleWatchdogFactory: @Sendable (Duration) -> any IdleWatchdogProtocol
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
        self.idleWatchdogFactory = Self.makeIdleWatchdogFactory { ContinuousClock() }
    }

#if DEBUG
    package init<C: Clock>(
        provider: any LLMProvider,
        executor: ToolExecutor,
        packet: ContextPacket,
        tools: [ToolDef],
        maxTurns: Int,
        tokenBudget: Int,
        maxTokensPerTurn: Int,
        retryDelays: [Duration] = [.seconds(2), .seconds(4)],
        turnTimeout: Duration = KernelDefaults.turnTimeout,
        idleClockForTesting clock: C
    ) where C.Duration == Duration {
        self.provider = provider
        self.executor = executor
        self.packet = packet
        self.tools = tools
        self.maxTurns = maxTurns
        self.tokenBudget = tokenBudget
        self.maxTokensPerTurn = maxTokensPerTurn
        self.retryDelays = retryDelays
        self.turnTimeout = turnTimeout
        self.idleWatchdogFactory = Self.makeIdleWatchdogFactory { clock }
    }
#endif

    public func run() -> AsyncThrowingStream<AgentEvent, Error> {
        makeRunHandle().events
    }

    package func makeRunHandle() -> AgentLoopRunHandleV1 {
        let (events, continuation) =
            AsyncThrowingStream<AgentEvent, Error>.makeStream()
        let completion: Task<Void, Error> = Task {
            do {
                let outcome = try await loop(continuation: continuation)
                continuation.yield(.finished(outcome))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
                throw error
            }
        }
        continuation.onTermination = { termination in
            guard case .cancelled = termination else { return }
            completion.cancel()
        }
        return AgentLoopRunHandleV1(
            events: events,
            completion: completion
        )
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

        var lastInputTokens = 0
        while turns < maxTurns && spentTokens < tokenBudget {
            turns += 1
            try Task.checkCancellation()

            // 上下文压缩（M5-3，spec §6.3）：上一轮 input 已近窗口时，先压缩旧轮次再继续。
            // system/tools 前缀与首条 user 消息不动（缓存纪律）；失败静默跳过，下轮再试。
            if lastInputTokens >= KernelDefaults.contextCompactionThreshold,
               let compacted = await Self.compact(history: history, provider: provider) {
                continuation.yield(.contextCompacted(fromMessages: history.count, toMessages: compacted.count))
                Self.logger.info("context compacted \(history.count, privacy: .public) -> \(compacted.count, privacy: .public) messages")
                history = compacted
                lastInputTokens = 0
            }

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
            lastInputTokens = result.usage.inputTokens
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

    private static func makeIdleWatchdogFactory<C: Clock>(
        _ makeClock: @escaping @Sendable () -> C
    ) -> @Sendable (Duration) -> any IdleWatchdogProtocol where C.Duration == Duration {
        { timeout in
            IdleWatchdog(clock: makeClock(), timeout: timeout)
        }
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
        let watchdog = idleWatchdogFactory(turnTimeout)
        return try await withThrowingTaskGroup(of: TurnResult.self) { group in
            group.addTask {
                var turn: TurnResult?
                let providerRun =
                    (provider as? any LLMProviderRunDrivingV1)?.startTurn(
                        system: packet.system,
                        history: history,
                        tools: tools,
                        toolChoice: .auto,
                        maxTokens: maxTokensPerTurn
                    )
                let events = providerRun?.events ?? provider.streamTurn(
                    system: packet.system,
                    history: history,
                    tools: tools,
                    toolChoice: .auto,
                    maxTokens: maxTokensPerTurn
                )
                var streamFailure: (any Error)?
                do {
                    for try await event in events {
                        await watchdog.beat(timeout: turnTimeout)
                        switch event {
                        case .textDelta(let text):
                            continuation.yield(.textDelta(text))
                        case .turn(let result):
                            turn = result
                        }
                    }
                } catch {
                    streamFailure = error
                    providerRun?.completion.cancel()
                }

                if Task.isCancelled {
                    providerRun?.completion.cancel()
                }
                if let providerRun {
                    let completionResult = await providerRun.completion.result
                    if case let .failure(completionFailure) = completionResult,
                       !(completionFailure is CancellationError)
                    {
                        throw completionFailure
                    }
                    if let streamFailure {
                        throw streamFailure
                    }
                    if case let .failure(completionFailure) = completionResult {
                        throw completionFailure
                    }
                } else if let streamFailure {
                    throw streamFailure
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
                var retainedError: any Error = error
                group.cancelAll()
                while !group.isEmpty {
                    do {
                        _ = try await group.next()
                    } catch {
                        if retainedError is CancellationError,
                           !(error is CancellationError)
                        {
                            retainedError = error
                        }
                    }
                }
                if retainedError is CancellationError {
                    try Task.checkCancellation()
                }
                throw retainedError
            }
        }
    }

    // MARK: - 上下文压缩（M5-3）

    /// 压缩历史：保留首条 user 消息（上下文包）与最近若干消息（后缀从 assistant 边界起，
    /// 保证 tool_use/tool_result 配对不被切断），中段经单轮 LLM 摘要替换为
    /// assistant(摘要) + user(桥接) 两条。不可压缩（太短/找不到边界/摘要失败）返回 nil。
    package static func compact(
        history: [APIMessage], provider: any LLMProvider
    ) async -> [APIMessage]? {
        guard let cut = compactionCutIndex(history: history) else { return nil }
        let middle = Array(history[1..<cut])
        let suffix = Array(history[cut...])

        let summary = await summarize(middle: middle, provider: provider)
        guard let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var compacted: [APIMessage] = [history[0]]
        compacted.append(.assistant([.text("# 此前进展摘要（早期过程已压缩）\n" + summary)]))
        compacted.append(.user("（以上是压缩后的早期进展；最近的往来保持原文。继续完成当前小目标，收尾契约不变。）"))
        compacted.append(contentsOf: suffix)
        return compacted
    }

    /// 选切点：后缀 ≤ keepRecent 条、必须从 assistant 消息开始（tool_result 紧随其 tool_use，
    /// 从 assistant 起步则配对完整落在后缀内）；中段至少 2 条才值得压。
    package static func compactionCutIndex(history: [APIMessage]) -> Int? {
        let keep = KernelDefaults.compactionKeepRecentMessages
        guard history.count > keep + 3 else { return nil }
        var cut = history.count - keep
        while cut < history.count, history[cut].role != .assistant {
            cut += 1
        }
        guard cut < history.count, cut > 2 else { return nil }
        return cut
    }

    private static func summarize(middle: [APIMessage], provider: any LLMProvider) async -> String? {
        let rendered = renderForSummary(middle)
        var text = ""
        var sawTurn = false
        do {
            for try await event in provider.streamTurn(
                system: compactorSystem,
                history: [.user(rendered)],
                tools: [],
                toolChoice: .auto,
                maxTokens: 2048
            ) {
                if case .turn(let result) = event {
                    sawTurn = true
                    text = result.content.compactMap { block -> String? in
                        if case .text(let t) = block { return t }
                        return nil
                    }.joined()
                }
            }
        } catch {
            return nil
        }
        return sawTurn ? text : nil
    }

    package static let compactorSystem = """
    你是执行过程的压缩员。把一段智能体工作过程压缩成要点摘要，供它自己继续工作时回看。
    必须保留：当前进展到哪一步、已经写入/产出的文件路径、关键决定与结论、尚未解决的问题。
    省略：工具调用的原始输出细节、寒暄。直接输出摘要正文（markdown 要点），不要前言。
    """

    package static func renderForSummary(_ messages: [APIMessage]) -> String {
        var lines: [String] = []
        for message in messages {
            for block in message.content {
                switch block {
                case .text(let text):
                    lines.append("\(message.role == .user ? "系统/用户" : "我")：\(String(text.prefix(500)))")
                case .toolUse(_, let name, let input):
                    let inputPreview = (try? input.encodedString()).map { String($0.prefix(200)) } ?? ""
                    lines.append("我调用了工具 \(name)(\(inputPreview))")
                case .toolResult(_, let content, let isError):
                    lines.append("工具返回\(isError ? "（出错）" : "")：\(String(content.prefix(300)))")
                case .unknown:
                    break
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            guard urlError.code != .appTransportSecurityRequiresSecureConnection else {
                return false
            }
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

private protocol IdleWatchdogProtocol: Sendable {
    func beat(timeout: Duration) async
    func waitForTimeout() async throws
}

private actor IdleWatchdog<C: Clock>: IdleWatchdogProtocol where C.Duration == Duration {
    private let clock: C
    private var deadline: C.Instant

    init(clock: C, timeout: Duration) {
        self.clock = clock
        deadline = clock.now.advanced(by: timeout)
    }

    func beat(timeout: Duration) async {
        deadline = clock.now.advanced(by: timeout)
    }

    func waitForTimeout() async throws {
        while true {
            try Task.checkCancellation()
            let target = deadline
            try await clock.sleep(until: target, tolerance: nil)
            try Task.checkCancellation()
            if clock.now >= deadline {
                throw TurnTimeoutError()
            }
        }
    }
}
