public struct Usage: Sendable, Equatable {
    public var inputTokens: Int, outputTokens: Int, cacheReadTokens: Int
    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheReadTokens: Int = 0) {
        self.inputTokens = inputTokens; self.outputTokens = outputTokens; self.cacheReadTokens = cacheReadTokens
    }

    /// 跨轮累计（M6-D13：规划两轮 + fallback 路径的 usage 求和）
    public mutating func add(_ other: Usage) {
        inputTokens += other.inputTokens
        outputTokens += other.outputTokens
        cacheReadTokens += other.cacheReadTokens
    }
}

public struct TurnResult: Sendable, Equatable {
    public var content: [ContentBlock]
    public var stopReason: StopReason
    public var usage: Usage
    public init(content: [ContentBlock], stopReason: StopReason, usage: Usage = .init()) {
        self.content = content; self.stopReason = stopReason; self.usage = usage
    }
    public var toolUses: [(id: String, name: String, input: JSONValue)] {
        content.compactMap { if case .toolUse(let i, let n, let inp) = $0 { return (i, n, inp) }; return nil }
    }
}

public enum ProviderEvent: Sendable {
    case textDelta(String)
    case turn(TurnResult)
}

public enum ToolChoice: Sendable, Equatable {
    case auto
    case tool(name: String)
}

public enum ProviderError: Error, Sendable, Equatable {
    case http(status: Int, body: String)
    case unauthorized
    case overloadedRetriesExhausted
    case apiError(type: String, message: String)
    case malformedStream(String)
}

extension ProviderError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unauthorized:
            return "API key 无效或无权限（401/403）"
        case .http(let status, let body):
            let preview = String(body.prefix(120))
            return preview.isEmpty ? "服务端返回 \(status)" : "服务端返回 \(status)：\(preview)"
        case .overloadedRetriesExhausted:
            return "服务持续过载，已多次重试"
        case .apiError(let type, let message):
            return "API 错误 \(type)：\(message)"
        case .malformedStream(let detail):
            return "响应流异常中断：\(detail)"
        }
    }
}

public protocol LLMProvider: Sendable {
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                    toolChoice: ToolChoice, maxTokens: Int)
        -> AsyncThrowingStream<ProviderEvent, Error>
}

package struct LLMProviderTurnRunV1: Sendable {
    package let events: AsyncThrowingStream<ProviderEvent, Error>
    package let completion: Task<Void, Error>
}

package protocol LLMProviderRunDrivingV1: LLMProvider {
    func startTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> LLMProviderTurnRunV1
}

package func makeLLMProviderTurnRunV1(
    operation: @escaping @Sendable (
        AsyncThrowingStream<ProviderEvent, Error>.Continuation
    ) async throws -> Void
) -> LLMProviderTurnRunV1 {
    let (events, continuation) =
        AsyncThrowingStream<ProviderEvent, Error>.makeStream()
    let completion: Task<Void, Error> = Task {
        do {
            try await operation(continuation)
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
    return LLMProviderTurnRunV1(
        events: events,
        completion: completion
    )
}
