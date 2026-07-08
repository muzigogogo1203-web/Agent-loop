import Foundation

/// MCP 驿站生命周期（M8-D3）：按需启动、一 server 一连接、tools/list 缓存。
/// 失败语义保守：启动失败/进程死亡 → down + 绝不自动重试，设置页手动「重启」复活
/// （挂死比失败更可怕）。子进程 PID 由 StdioProcessTransport 登记 ShellProcessRegistry，
/// 收哨/退出统一清理。
public actor McpServerManager {
    public enum ServerStatus: Sendable, Equatable {
        case stopped
        case starting
        case running(toolCount: Int)
        case down(String)

        public var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    /// 装配成品：ToolDef（composed 名 + 截断后的描述 + schema 透传）
    /// + 调用路径需要的原始坐标（不依赖名字反解析）。
    public struct AssembledTool: Sendable {
        public let def: ToolDef
        public let serverId: String
        public let serverName: String
        public let originalToolName: String
    }

    private struct Handle {
        var record: McpServerRecord
        var client: MiniMcpClient?
        var status: ServerStatus = .stopped
        var tools: [MiniMcpClient.ToolInfo] = []
        /// 重启代际：旧连接的死亡回调不得覆盖新连接的状态
        var generation = 0
    }

    /// 传输工厂：生产 StdioProcessTransport（真）或 FakeTransport（测试）。
    public typealias TransportFactory = @Sendable (McpServerRecord, [String: String]) -> any McpTransport
    /// 敏感 env 解析（M8-D5）：(serverId, key) → Keychain 值。Core 不直连 Keychain（M6-D7 惯例）。
    public typealias SecretProvider = @Sendable (String, String) -> String?

    private let db: AppDatabase
    private let transportFactory: TransportFactory
    private let secretProvider: SecretProvider
    private let baseEnvironment: @Sendable () async -> [String: String]
    private let initTimeout: Duration
    private let callTimeout: Duration
    private var handles: [String: Handle] = [:]
    private var startTasks: [String: Task<Void, Never>] = [:]

    public init(
        db: AppDatabase,
        transportFactory: @escaping TransportFactory = { record, env in
            StdioProcessTransport(command: record.command, args: record.args, environment: env)
        },
        secretProvider: @escaping SecretProvider = { _, _ in nil },
        baseEnvironment: @escaping @Sendable () async -> [String: String] = {
            await LoginShellEnvironment.shared.environment()
        },
        initTimeout: Duration = KernelDefaults.mcpInitTimeout,
        callTimeout: Duration = KernelDefaults.mcpCallTimeout
    ) {
        self.db = db
        self.transportFactory = transportFactory
        self.secretProvider = secretProvider
        self.baseEnvironment = baseEnvironment
        self.initTimeout = initTimeout
        self.callTimeout = callTimeout
    }

    // MARK: - 生命周期

    /// 确保一批 server 在跑（营地行动派发前调用）。stopped → 启动；
    /// down 保持 down（绝不自动重试，M8-D3）；starting 等待完成。
    public func ensureRunning(serverIds: [String]) async {
        for id in serverIds {
            if let task = startTasks[id] {
                await task.value
                continue
            }
            let status = handles[id]?.status ?? .stopped
            guard case .stopped = status else { continue }
            await startServer(id: id)
        }
    }

    /// 手动重启（设置页按钮，down 复活的唯一途径）：停旧连接 + 清缓存 + 重新启动。
    public func restart(serverId: String) async {
        if let task = startTasks[serverId] {
            await task.value
        }
        await stopConnection(serverId: serverId)
        handles[serverId]?.status = .stopped
        await startServer(id: serverId)
    }

    public func stop(serverId: String) async {
        if let task = startTasks[serverId] {
            await task.value
        }
        await stopConnection(serverId: serverId)
        handles[serverId]?.status = .stopped
    }

    public func stopAll() async {
        for task in startTasks.values {
            await task.value
        }
        for id in handles.keys {
            await stopConnection(serverId: id)
            handles[id]?.status = .stopped
        }
    }

    public func status(serverId: String) -> ServerStatus {
        handles[serverId]?.status ?? .stopped
    }

    public func statuses() -> [String: ServerStatus] {
        handles.mapValues(\.status)
    }

    // MARK: - 工具装配

    /// 该营地已启用且在跑的 server 的工具清单（缓存），组合名冲突/超长的工具跳过。
    /// 描述截断 ~600B：外部描述不挤占提示词。
    public func assembledTools(campId: String) -> [AssembledTool] {
        guard let servers = try? db.enabledMcpServers(campId: campId) else { return [] }
        var used = Set<String>()
        var result: [AssembledTool] = []
        for server in servers {
            guard let handle = handles[server.id], handle.status.isRunning else { continue }
            for tool in handle.tools {
                guard let name = McpToolNaming.compose(server: server.name, tool: tool.name),
                      !used.contains(name) else { continue }
                used.insert(name)
                let description = TextTruncation.truncateUTF8(
                    tool.description, maxBytes: 600, suffix: "…")
                result.append(AssembledTool(
                    def: ToolDef(name: name, description: description, inputSchema: tool.inputSchema),
                    serverId: server.id,
                    serverName: server.name,
                    originalToolName: tool.name
                ))
            }
        }
        return result
    }

    // MARK: - 调用

    public func call(serverId: String, toolName: String, arguments: JSONValue) async -> Result<MiniMcpClient.CallResult, McpClientError> {
        guard let handle = handles[serverId], let client = handle.client,
              handle.status.isRunning else {
            return .failure(.connectionClosed)
        }
        do {
            return .success(try await client.callTool(
                name: toolName, arguments: arguments, timeout: callTimeout))
        } catch let error as McpClientError {
            return .failure(error)
        } catch {
            return .failure(.malformed(String(describing: error)))
        }
    }

    // MARK: - 内部

    private func startServer(id: String) async {
        guard let record = try? db.mcpServer(id: id) else {
            handles[id]?.status = .down("驿站记录不存在")
            return
        }
        var handle = handles[id] ?? Handle(record: record)
        handle.record = record
        handle.generation += 1
        handle.status = .starting
        handles[id] = handle
        let generation = handle.generation

        let task = Task { await self.performStart(record: record, generation: generation) }
        startTasks[id] = task
        await task.value
        startTasks[id] = nil
    }

    private func performStart(record: McpServerRecord, generation: Int) async {
        // env 合成（M8-D5）：登录 shell 底座 < envJson 明文 < Keychain 敏感值
        var env = await baseEnvironment()
        for (key, value) in record.env {
            env[key] = value
        }
        for key in record.secretEnvKeys {
            if let value = secretProvider(record.id, key), !value.isEmpty {
                env[key] = value
            }
        }
        let transport = transportFactory(record, env)
        let serverId = record.id
        let client = MiniMcpClient(transport: transport) { [weak self] in
            Task { await self?.markDown(serverId: serverId, generation: generation, detail: "进程已退出") }
        }
        do {
            try await client.connect(timeout: initTimeout)
            let tools = try await client.listTools(timeout: initTimeout)
            guard handles[serverId]?.generation == generation else {
                await client.close()
                return
            }
            handles[serverId]?.client = client
            handles[serverId]?.tools = tools
            handles[serverId]?.status = .running(toolCount: tools.count)
        } catch {
            await client.close()
            guard handles[serverId]?.generation == generation else { return }
            let stderr = (transport as? StdioProcessTransport)?.stderrSnapshot ?? ""
            let detail = Self.readableStartFailure(error: error, stderr: stderr)
            handles[serverId]?.client = nil
            handles[serverId]?.tools = []
            handles[serverId]?.status = .down(detail)
        }
    }

    private func markDown(serverId: String, generation: Int, detail: String) {
        guard var handle = handles[serverId], handle.generation == generation else { return }
        // 主动 stop/restart 已把状态改走时不覆盖
        guard handle.status.isRunning || handle.status == .starting else { return }
        handle.client = nil
        handle.tools = []
        handle.status = .down(detail)
        handles[serverId] = handle
    }

    private func stopConnection(serverId: String) async {
        guard var handle = handles[serverId] else { return }
        handle.generation += 1 // 使旧死亡回调失效
        let client = handle.client
        handle.client = nil
        handle.tools = []
        handles[serverId] = handle
        await client?.close()
    }

    private static func readableStartFailure(error: Error, stderr: String) -> String {
        let base = (error as? McpClientError)?.readable ?? String(describing: error)
        let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tail.isEmpty else { return base }
        return "\(base)\n启动日志尾部：\(String(tail.suffix(500)))"
    }
}
