public enum ToolOutcome: Sendable {
    case result(String)
    case error(String)
    case completed(HandoffPayload)
    case blocked(reason: String, detail: String)
}

public protocol ToolHandler: Sendable {
    func execute(input: JSONValue) async -> ToolOutcome
}

public struct ToolExecutor: Sendable {
    let handlers: [String: any ToolHandler]

    public init(handlers: [String: any ToolHandler]) {
        self.handlers = handlers
    }

    public func execute(name: String, input: JSONValue) async -> ToolOutcome {
        guard let handler = handlers[name] else {
            return .error("未知工具 \(name)。可用工具：\(handlers.keys.sorted().joined(separator: ", "))")
        }
        return await handler.execute(input: input)
    }
}
