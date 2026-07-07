public enum ToolOutcome: Sendable {
    case result(String)
    case error(String)
    case completed(HandoffPayload)
    case blocked(reason: String, detail: String)
}

public protocol ToolHandler: Sendable {
    func execute(input: JSONValue) async -> ToolOutcome
}

/// 闭包式 handler（M6-D1）：让需要捕获调用上下文（threadId/continuation 等）的工具
/// 也能走 ToolExecutor 单一分发，而不必为每种上下文形状扩协议。
public struct ClosureToolHandler: ToolHandler {
    let body: @Sendable (JSONValue) async -> ToolOutcome

    public init(_ body: @escaping @Sendable (JSONValue) async -> ToolOutcome) {
        self.body = body
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        await body(input)
    }
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
