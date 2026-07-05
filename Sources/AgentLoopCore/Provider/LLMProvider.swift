public struct Usage: Sendable, Equatable {
    public var inputTokens: Int, outputTokens: Int, cacheReadTokens: Int
    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheReadTokens: Int = 0) {
        self.inputTokens = inputTokens; self.outputTokens = outputTokens; self.cacheReadTokens = cacheReadTokens
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
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef], maxTokens: Int)
        -> AsyncThrowingStream<ProviderEvent, Error>
}
