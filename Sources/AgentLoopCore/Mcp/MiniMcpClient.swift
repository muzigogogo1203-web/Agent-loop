import Foundation

/// MCP 客户端错误（M8-D1）。isDown = 连接层死亡（进程退出/管道断），
/// 与工具自身报错（CallResult.isError）分开——后者是资料，前者要引导用户重启驿站。
public enum McpClientError: Error, Sendable, Equatable {
    case connectionClosed
    case timeout(Duration)
    case rpcError(code: Int, message: String)
    case malformed(String)

    public var isDown: Bool {
        if case .connectionClosed = self { return true }
        return false
    }

    public var readable: String {
        switch self {
        case .connectionClosed: return "连接已断开（进程可能已退出）"
        case .timeout(let d): return "调用超时（\(d)）"
        case .rpcError(let code, let message): return "协议错误 \(code)：\(message)"
        case .malformed(let detail): return "响应格式异常：\(detail)"
        }
    }
}

/// MiniMCP：stdio JSON-RPC 2.0 客户端，协议面只取三方法
/// （initialize / tools/list / tools/call，M8-D1 自写兜底路线）。
/// 消息路由：响应按 id 配对唤醒等待方；对端主动请求一律 -32601；通知忽略。
/// 连接死亡（读流结束）→ 挂起请求全部失败 + onUnexpectedClose 回调（Manager 标 down）。
public actor MiniMcpClient {
    public struct ToolInfo: Sendable, Equatable {
        public let name: String
        public let description: String
        public let inputSchema: JSONValue

        public init(name: String, description: String, inputSchema: JSONValue) {
            self.name = name
            self.description = description
            self.inputSchema = inputSchema
        }
    }

    public struct CallResult: Sendable, Equatable {
        /// content 数组的文本拼接；图片/资源替换为占位（文本-only 是 M8-D4 的刀法）
        public let text: String
        public let isError: Bool

        public init(text: String, isError: Bool) {
            self.text = text
            self.isError = isError
        }
    }

    private let transport: any McpTransport
    private let onUnexpectedClose: @Sendable () -> Void
    private var nextId = 0
    private var pending: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var closed = false
    private var explicitClose = false
    private var readTask: Task<Void, Never>?

    public init(transport: any McpTransport, onUnexpectedClose: @escaping @Sendable () -> Void = {}) {
        self.transport = transport
        self.onUnexpectedClose = onUnexpectedClose
    }

    /// initialize 握手 + initialized 通知。协议版本发我们支持的，对端返回什么就接受什么
    /// （版本内容差异对三方法子集无影响；记录留给日志层）。
    public func connect(timeout: Duration) async throws {
        try await transport.start()
        readTask = Task { await self.readLoop() }
        _ = try await request(
            method: "initialize",
            params: [
                "protocolVersion": "2025-06-18",
                "capabilities": [:],
                "clientInfo": ["name": "AgentLoop", "version": "0.8.0"],
            ],
            timeout: timeout
        )
        try await notify(method: "notifications/initialized", params: [:])
    }

    /// tools/list（跟随 nextCursor 翻页拿全量）。
    public func listTools(timeout: Duration) async throws -> [ToolInfo] {
        var tools: [ToolInfo] = []
        var cursor: String?
        repeat {
            var params: [String: JSONValue] = [:]
            if let cursor { params["cursor"] = .string(cursor) }
            let result = try await request(method: "tools/list", params: .object(params), timeout: timeout)
            guard let items = result["tools"]?.arrayValue else {
                throw McpClientError.malformed("tools/list 缺 tools 数组")
            }
            for item in items {
                guard let name = item["name"]?.stringValue, !name.isEmpty else { continue }
                tools.append(ToolInfo(
                    name: name,
                    description: item["description"]?.stringValue ?? "",
                    inputSchema: item["inputSchema"] ?? ToolDef.objectSchema([:], required: [])
                ))
            }
            cursor = result["nextCursor"]?.stringValue
        } while cursor != nil
        return tools
    }

    public func callTool(name: String, arguments: JSONValue, timeout: Duration) async throws -> CallResult {
        let result = try await request(
            method: "tools/call",
            params: ["name": .string(name), "arguments": arguments],
            timeout: timeout
        )
        guard let content = result["content"]?.arrayValue else {
            throw McpClientError.malformed("tools/call 缺 content 数组")
        }
        let text = content.map(Self.flattenContentItem).joined(separator: "\n")
        return CallResult(text: text, isError: result["isError"]?.boolValue ?? false)
    }

    /// 主动关闭：挂起请求失败，不触发 onUnexpectedClose（区别于进程死亡）。
    public func close() async {
        explicitClose = true
        markClosed()
        readTask?.cancel()
        await transport.close()
    }

    // MARK: - 内部

    private static func flattenContentItem(_ item: JSONValue) -> String {
        switch item["type"]?.stringValue {
        case "text":
            return item["text"]?.stringValue ?? ""
        case "image":
            return "［图片内容，V2 暂不支持］"
        case "audio":
            return "［音频内容，V2 暂不支持］"
        case "resource", "resource_link":
            return "［资源内容，V2 暂不支持］"
        default:
            return "［未知内容类型，已忽略］"
        }
    }

    private func request(method: String, params: JSONValue, timeout: Duration) async throws -> JSONValue {
        guard !closed else { throw McpClientError.connectionClosed }
        nextId += 1
        let id = nextId
        let message: JSONValue = [
            "jsonrpc": "2.0",
            "id": .number(Double(id)),
            "method": .string(method),
            "params": params,
        ]
        let data = Data(try message.encodedString().utf8)

        let watchdog = Task {
            try? await Task.sleep(for: timeout)
            self.fail(id: id, error: McpClientError.timeout(timeout))
        }
        defer { watchdog.cancel() }

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                do {
                    try await transport.send(data)
                } catch {
                    self.fail(id: id, error: error)
                }
            }
        }
    }

    private func notify(method: String, params: JSONValue) async throws {
        guard !closed else { throw McpClientError.connectionClosed }
        let message: JSONValue = [
            "jsonrpc": "2.0",
            "method": .string(method),
            "params": params,
        ]
        try await transport.send(Data(try message.encodedString().utf8))
    }

    private func readLoop() async {
        do {
            for try await raw in transport.messages {
                handle(raw)
            }
        } catch {
            // 读流抛错与正常结束同等对待：连接已死
        }
        let wasExplicit = explicitClose
        markClosed()
        if !wasExplicit {
            onUnexpectedClose()
        }
    }

    private func handle(_ raw: Data) {
        guard let message = try? JSONDecoder().decode(JSONValue.self, from: raw) else {
            return // 非 JSON 行（server 把日志写到 stdout 的常见违规）：忽略
        }
        if let id = message["id"]?.intValue, message["method"] == nil {
            // 响应：按 id 配对
            guard let continuation = pending.removeValue(forKey: id) else { return }
            if let error = message["error"] {
                continuation.resume(throwing: McpClientError.rpcError(
                    code: error["code"]?.intValue ?? -1,
                    message: error["message"]?.stringValue ?? "未知错误"
                ))
            } else {
                continuation.resume(returning: message["result"] ?? .null)
            }
        } else if let id = message["id"], message["method"] != nil {
            // 对端主动请求（roots/sampling 等）：一律 method not found，V2 不支持
            let reply: JSONValue = [
                "jsonrpc": "2.0",
                "id": id,
                "error": ["code": -32601, "message": "method not supported by AgentLoop"],
            ]
            if let data = try? reply.encodedString() {
                Task { try? await transport.send(Data(data.utf8)) }
            }
        }
        // 通知（method、无 id）：忽略
    }

    private func fail(id: Int, error: Error) {
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func markClosed() {
        closed = true
        let waiting = pending
        pending.removeAll()
        for (_, continuation) in waiting {
            continuation.resume(throwing: McpClientError.connectionClosed)
        }
    }
}
