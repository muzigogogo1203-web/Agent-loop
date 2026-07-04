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

public protocol LLMProvider: Sendable {
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef], maxTokens: Int)
        -> AsyncThrowingStream<ProviderEvent, Error>
}
