public enum StopReason: Sendable, Equatable {
    case endTurn, toolUse, maxTokens, refusal, pauseTurn, stopSequence, contextExceeded
    case other(String)

    public init(apiValue: String?) {
        switch apiValue {
        case "end_turn": self = .endTurn
        case "tool_use": self = .toolUse
        case "max_tokens": self = .maxTokens
        case "refusal": self = .refusal
        case "pause_turn": self = .pauseTurn
        case "stop_sequence": self = .stopSequence
        case "model_context_window_exceeded": self = .contextExceeded
        default: self = .other(apiValue ?? "nil")
        }
    }
}
