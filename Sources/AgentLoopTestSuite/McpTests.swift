import Testing
import Foundation
import AgentLoopCore
import GRDB

// M8 驿路：MiniMCP 客户端 / 命名 / Manager 生命周期 / CRUD / 注入 / 桥接

// MARK: - FakeTransport

/// 脚本化 MCP 传输（M8-D3 测试路线）：send 进来的请求经 responder 产出应答；
/// die() 模拟进程死亡（读流结束）。
final class FakeMcpTransport: McpTransport, @unchecked Sendable {
    let messages: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let lock = NSLock()
    private var sentMessages: [JSONValue] = []
    private var startCalls = 0
    private let failOnStart: Bool
    private let responder: @Sendable (JSONValue) -> [JSONValue]

    init(
        failOnStart: Bool = false,
        responder: @escaping @Sendable (JSONValue) -> [JSONValue] = FakeMcpTransport.defaultResponder(tools: FakeMcpTransport.defaultTools)
    ) {
        self.failOnStart = failOnStart
        self.responder = responder
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messages = AsyncThrowingStream { continuation = $0 }
        self.continuation = continuation
    }

    func start() async throws {
        recordStart()
        if failOnStart {
            throw McpClientError.malformed("启动失败（测试脚本）")
        }
    }

    func send(_ data: Data) async throws {
        guard let message = try? JSONDecoder().decode(JSONValue.self, from: data) else { return }
        recordSent(message)
        for reply in responder(message) {
            continuation.yield(Data(try reply.encodedString().utf8))
        }
    }

    private func recordStart() {
        lock.lock()
        defer { lock.unlock() }
        startCalls += 1
    }

    private func recordSent(_ message: JSONValue) {
        lock.lock()
        defer { lock.unlock() }
        sentMessages.append(message)
    }

    func close() async {
        continuation.finish()
    }

    /// 模拟进程意外死亡
    func die() {
        continuation.finish()
    }

    /// 模拟对端主动推送一条原始消息
    func push(_ value: JSONValue) {
        continuation.yield(Data(((try? value.encodedString()) ?? "{}").utf8))
    }

    /// 推送原始字节（模拟 server 把日志打到 stdout 的违规行）
    func pushRaw(_ text: String) {
        continuation.yield(Data(text.utf8))
    }

    var sent: [JSONValue] {
        lock.lock()
        defer { lock.unlock() }
        return sentMessages
    }

    var startCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return startCalls
    }

    static let defaultTools: [JSONValue] = [
        [
            "name": "list_issues",
            "description": "列 issue",
            "inputSchema": ["type": "object", "properties": ["repo": ["type": "string"]], "required": ["repo"]],
        ],
        [
            "name": "screenshot",
            "description": "截图",
            "inputSchema": ["type": "object", "properties": [:], "required": []],
        ],
    ]

    static func defaultResponder(tools: [JSONValue]) -> @Sendable (JSONValue) -> [JSONValue] {
        { message in
            guard let id = message["id"], message["method"]?.stringValue != nil else { return [] }
            switch message["method"]?.stringValue {
            case "initialize":
                return [[
                    "jsonrpc": "2.0", "id": id,
                    "result": [
                        "protocolVersion": "2025-06-18",
                        "capabilities": ["tools": [:]],
                        "serverInfo": ["name": "fake", "version": "1.0"],
                    ],
                ]]
            case "tools/list":
                return [["jsonrpc": "2.0", "id": id, "result": ["tools": .array(tools)]]]
            case "tools/call":
                let name = message["params"]?["name"]?.stringValue ?? "?"
                return [[
                    "jsonrpc": "2.0", "id": id,
                    "result": ["content": [["type": "text", "text": .string("called:\(name)")]], "isError": false],
                ]]
            default:
                return [["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "unknown"]]]
            }
        }
    }
}

private func tempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private enum McpCredentialStoreAction: Hashable, Sendable {
    case get, set, delete
}

private struct McpCredentialStoreCall: Equatable, Sendable {
    let action: McpCredentialStoreAction
    let account: String
}

private struct McpCredentialStoreFailureKey: Hashable, Sendable {
    let action: McpCredentialStoreAction
    let account: String
    let occurrence: Int
}

private final class McpRecordingCredentialStore:
    CredentialStore, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [String: String]
    private var calls: [McpCredentialStoreCall] = []
    private var occurrences: [McpCredentialStoreFailureKey: Int] = [:]
    private var failures: [McpCredentialStoreFailureKey: Int32] = [:]
    let backendNamespace = CredentialStoreBackendNamespace.isolated(UUID())

    init(_ values: [String: String] = [:]) {
        self.values = values
    }

    func set(_ value: String, account: String) throws {
        try lock.withLock {
            try record(.set, account: account)
            values[account] = value
        }
    }

    func get(account: String) throws -> String? {
        try get(account: account, interactionPolicy: .allow)
    }

    func get(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String? {
        try lock.withLock {
            try record(.get, account: account)
            return values[account]
        }
    }

    func delete(account: String) throws {
        try lock.withLock {
            try record(.delete, account: account)
            values[account] = nil
        }
    }

    func injectFailure(
        _ action: McpCredentialStoreAction,
        account: String,
        occurrence: Int = 1,
        status: Int32
    ) {
        lock.withLock {
            failures[
                McpCredentialStoreFailureKey(
                    action: action,
                    account: account,
                    occurrence: occurrence
                )
            ] = status
        }
    }

    func resetAudit() {
        lock.withLock {
            calls = []
            occurrences = [:]
            failures = [:]
        }
    }

    var recordedCalls: [McpCredentialStoreCall] {
        lock.withLock { calls }
    }

    var snapshot: [String: String] {
        lock.withLock { values }
    }

    private func record(
        _ action: McpCredentialStoreAction,
        account: String
    ) throws {
        let base = McpCredentialStoreFailureKey(
            action: action,
            account: account,
            occurrence: 0
        )
        let occurrence = (occurrences[base] ?? 0) + 1
        occurrences[base] = occurrence
        calls.append(McpCredentialStoreCall(action: action, account: account))
        if let status = failures[
            McpCredentialStoreFailureKey(
                action: action,
                account: account,
                occurrence: occurrence
            )
        ] {
            throw KeychainError(status: status)
        }
    }
}

private enum McpFixtureError: Error {
    case databaseDelete
    case secretRead
}

private final class McpRecordingFailureWriter:
    FailureRecordWriting, @unchecked Sendable
{
    private let lock = NSLock()
    private var stored: [FailureRecord] = []

    func persistFailureRecord(_ record: FailureRecord) throws {
        lock.withLock { stored.append(record) }
    }

    var records: [FailureRecord] {
        lock.withLock { stored }
    }
}

private final class McpRecordingFailureSink:
    FailureLogSink, @unchecked Sendable
{
    private let lock = NSLock()
    private var stored: [FailureLogEntry] = []

    func write(_ entry: FailureLogEntry) {
        lock.withLock { stored.append(entry) }
    }

    var entries: [FailureLogEntry] {
        lock.withLock { stored }
    }
}

// MARK: - MiniMcpClient

@Test func mcpHandshakeSendsInitializeThenInitializedNotification() async throws {
    let transport = FakeMcpTransport()
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    let methods = transport.sent.compactMap { $0["method"]?.stringValue }
    #expect(methods == ["initialize", "notifications/initialized"])
    // initialize 请求形状：协议版本 + clientInfo
    let initMsg = transport.sent[0]
    #expect(initMsg["params"]?["protocolVersion"]?.stringValue == "2025-06-18")
    #expect(initMsg["params"]?["clientInfo"]?["name"]?.stringValue == "AgentLoop")
    await client.close()
}

@Test func mcpListToolsFollowsPaginationCursor() async throws {
    let transport = FakeMcpTransport(responder: { message in
        guard let id = message["id"] else { return [] }
        switch message["method"]?.stringValue {
        case "initialize":
            return [["jsonrpc": "2.0", "id": id, "result": ["protocolVersion": "2025-06-18", "capabilities": [:], "serverInfo": ["name": "f", "version": "1"]]]]
        case "tools/list":
            if message["params"]?["cursor"]?.stringValue == "p2" {
                return [["jsonrpc": "2.0", "id": id, "result": ["tools": [["name": "b", "description": "", "inputSchema": ["type": "object"]]]]]]
            }
            return [["jsonrpc": "2.0", "id": id, "result": [
                "tools": [["name": "a", "description": "", "inputSchema": ["type": "object"]]],
                "nextCursor": "p2",
            ]]]
        default: return []
        }
    })
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    let tools = try await client.listTools(timeout: .seconds(2))
    #expect(tools.map(\.name) == ["a", "b"])
    await client.close()
}

@Test func mcpCallFlattensNonTextContentToPlaceholders() async throws {
    let transport = FakeMcpTransport(responder: { message in
        guard let id = message["id"] else { return [] }
        switch message["method"]?.stringValue {
        case "initialize":
            return [["jsonrpc": "2.0", "id": id, "result": ["protocolVersion": "2025-06-18", "capabilities": [:], "serverInfo": ["name": "f", "version": "1"]]]]
        case "tools/call":
            return [["jsonrpc": "2.0", "id": id, "result": ["content": [
                ["type": "text", "text": "正文"],
                ["type": "image", "data": "xxx", "mimeType": "image/png"],
                ["type": "resource", "resource": ["uri": "file:///x"]],
            ]]]]
        default: return []
        }
    })
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    let result = try await client.callTool(name: "t", arguments: .object([:]), timeout: .seconds(2))
    #expect(result.text.contains("正文"))
    #expect(result.text.contains("图片内容"))
    #expect(result.text.contains("资源内容"))
    #expect(!result.isError)
    await client.close()
}

@Test func mcpCallPropagatesIsErrorFlag() async throws {
    let transport = FakeMcpTransport(responder: { message in
        guard let id = message["id"] else { return [] }
        switch message["method"]?.stringValue {
        case "initialize":
            return [["jsonrpc": "2.0", "id": id, "result": ["protocolVersion": "2025-06-18", "capabilities": [:], "serverInfo": ["name": "f", "version": "1"]]]]
        case "tools/call":
            return [["jsonrpc": "2.0", "id": id, "result": [
                "content": [["type": "text", "text": "工具报错了"]], "isError": true,
            ]]]
        default: return []
        }
    })
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    let result = try await client.callTool(name: "t", arguments: .object([:]), timeout: .seconds(2))
    #expect(result.isError)
    await client.close()
}

@Test func mcpRpcErrorResponseThrows() async throws {
    let transport = FakeMcpTransport(responder: { message in
        guard let id = message["id"] else { return [] }
        switch message["method"]?.stringValue {
        case "initialize":
            return [["jsonrpc": "2.0", "id": id, "result": ["protocolVersion": "2025-06-18", "capabilities": [:], "serverInfo": ["name": "f", "version": "1"]]]]
        default:
            return [["jsonrpc": "2.0", "id": id, "error": ["code": -32602, "message": "bad params"]]]
        }
    })
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    do {
        _ = try await client.callTool(name: "t", arguments: .object([:]), timeout: .seconds(2))
        Issue.record("应当抛 rpcError")
    } catch let error as McpClientError {
        #expect(error == .rpcError(code: -32602, message: "bad params"))
    }
    await client.close()
}

@Test func mcpRequestTimesOutWhenNoResponse() async throws {
    let transport = FakeMcpTransport(responder: { message in
        guard let id = message["id"] else { return [] }
        if message["method"]?.stringValue == "initialize" {
            return [["jsonrpc": "2.0", "id": id, "result": ["protocolVersion": "2025-06-18", "capabilities": [:], "serverInfo": ["name": "f", "version": "1"]]]]
        }
        return [] // tools/call 永不应答
    })
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    do {
        _ = try await client.callTool(name: "t", arguments: .object([:]), timeout: .milliseconds(80))
        Issue.record("应当超时")
    } catch let error as McpClientError {
        guard case .timeout = error else {
            Issue.record("期待 timeout，实得 \(error)")
            return
        }
    }
    await client.close()
}

@Test func mcpDeathFailsPendingAndFiresUnexpectedClose() async throws {
    let closeFlag = LockedBox(false)
    let transport = FakeMcpTransport(responder: { message in
        guard let id = message["id"] else { return [] }
        if message["method"]?.stringValue == "initialize" {
            return [["jsonrpc": "2.0", "id": id, "result": ["protocolVersion": "2025-06-18", "capabilities": [:], "serverInfo": ["name": "f", "version": "1"]]]]
        }
        return []
    })
    let client = MiniMcpClient(transport: transport) { closeFlag.set(true) }
    try await client.connect(timeout: .seconds(2))

    let pending = Task {
        try await client.callTool(name: "t", arguments: .object([:]), timeout: .seconds(10))
    }
    try await Task.sleep(for: .milliseconds(50))
    transport.die()
    do {
        _ = try await pending.value
        Issue.record("挂起请求应随连接死亡失败")
    } catch let error as McpClientError {
        #expect(error == .connectionClosed)
    }
    // 死亡回调（轮询等待读取循环收尾）
    var fired = false
    for _ in 0..<40 {
        if closeFlag.get() { fired = true; break }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(fired)
}

@Test func mcpExplicitCloseDoesNotFireUnexpectedClose() async throws {
    let closeFlag = LockedBox(false)
    let transport = FakeMcpTransport()
    let client = MiniMcpClient(transport: transport) { closeFlag.set(true) }
    try await client.connect(timeout: .seconds(2))
    await client.close()
    try await Task.sleep(for: .milliseconds(100))
    #expect(!closeFlag.get())
}

@Test func mcpServerInitiatedRequestGetsMethodNotFound() async throws {
    let transport = FakeMcpTransport()
    let client = MiniMcpClient(transport: transport)
    try await client.connect(timeout: .seconds(2))
    transport.push(["jsonrpc": "2.0", "id": "srv-1", "method": "roots/list", "params": [:]])
    var replied = false
    for _ in 0..<40 {
        if let reply = transport.sent.first(where: { $0["id"]?.stringValue == "srv-1" }) {
            #expect(reply["error"]?["code"]?.intValue == -32601)
            replied = true
            break
        }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(replied)
    await client.close()
}

@Test func mcpIgnoresNonJsonNoiseLines() async throws {
    let transport = FakeMcpTransport()
    let client = MiniMcpClient(transport: transport)
    transport.pushRaw("server 把日志打到 stdout 的违规行为 [INFO] booting...")
    try await client.connect(timeout: .seconds(2))
    let tools = try await client.listTools(timeout: .seconds(2))
    #expect(tools.count == 2)
    await client.close()
}

// MARK: - 命名

@Test func mcpNamingSanitizesComposesAndParses() {
    // 非法字符 → "-"；server 段 "__" 压缩保护分隔符
    #expect(McpToolNaming.sanitizeComponent("浏览器 v2!") == "----v2-")
    #expect(McpToolNaming.serverComponent("a__b___c") == "a_b_c")
    #expect(McpToolNaming.compose(server: "github", tool: "list_issues") == "mcp__github__list_issues")
    // tool 段的点号清洗
    #expect(McpToolNaming.compose(server: "pw", tool: "browser.navigate") == "mcp__pw__browser-navigate")
    // 全非法字符的 server 段清洗后非空（映射为 "-"），仍可组合
    #expect(McpToolNaming.compose(server: "！！", tool: "t") == "mcp__--__t")
    // 超长 → nil
    #expect(McpToolNaming.compose(server: "s", tool: String(repeating: "x", count: 130)) == nil)
    // 解析（display 用）
    let parsed = McpToolNaming.parse("mcp__github__list_issues")
    #expect(parsed?.server == "github")
    #expect(parsed?.tool == "list_issues")
    #expect(McpToolNaming.parse("web_fetch") == nil)
    #expect(ToolDef.displayName("mcp__github__list_issues") == "驿站·github / list_issues")
    #expect(ToolDef.risk("mcp__github__list_issues") == .write)
}

// MARK: - CRUD（迁移 v6）

@Test func mcpServerCRUDAndCampEnableToggle() throws {
    let db = try tempDB()
    let campA = try db.createCamp(name: "A")
    let campB = try db.createCamp(name: "B")
    let server = McpServerRecord.new(
        name: "github", command: "npx",
        args: ["-y", "@modelcontextprotocol/server-github"],
        secretEnvKeys: ["GITHUB_PERSONAL_ACCESS_TOKEN"])
    try db.addMcpServer(server)
    #expect(try db.mcpServers().map(\.name) == ["github"])
    #expect(try db.mcpServer(id: server.id)?.secretEnvKeys == ["GITHUB_PERSONAL_ACCESS_TOKEN"])

    // 更新：command/env 可改，name 不可改（工具名组成部分）
    var edited = server
    edited.name = "renamed"
    edited.command = "node"
    try db.updateMcpServer(edited)
    let after = try db.mcpServer(id: server.id)
    #expect(after?.name == "github")
    #expect(after?.command == "node")

    // 营地级启用：隔离 + 幂等
    try db.setMcpServerEnabled(campId: campA.id, serverId: server.id, enabled: true)
    try db.setMcpServerEnabled(campId: campA.id, serverId: server.id, enabled: true)
    #expect(try db.enabledMcpServers(campId: campA.id).map(\.id) == [server.id])
    #expect(try db.enabledMcpServers(campId: campB.id).isEmpty)
    try db.setMcpServerEnabled(campId: campA.id, serverId: server.id, enabled: false)
    #expect(try db.enabledMcpServers(campId: campA.id).isEmpty)

    // 删除级联清启用关联
    try db.setMcpServerEnabled(campId: campB.id, serverId: server.id, enabled: true)
    try db.deleteMcpServer(id: server.id)
    #expect(try db.mcpServers().isEmpty)
    #expect(try db.enabledMcpServerIds(campId: campB.id).isEmpty)
}

// MARK: - Manager

private func makeManagerFixture(
    transportBox: LockedArrayBox<FakeMcpTransport>,
    makeTransport: @escaping @Sendable (McpServerRecord, [String: String]) -> FakeMcpTransport = { _, _ in FakeMcpTransport() },
    secretProvider: @escaping McpServerManager.SecretProvider = { _, _ in nil },
    baseEnv: [String: String] = ["SECRET_KEY": "fixture-secret"],
    callTimeout: Duration = .seconds(2)
) throws -> (db: AppDatabase, manager: McpServerManager, camp: CampRecord, server: McpServerRecord) {
    let db = try tempDB()
    let camp = try db.createCamp(name: "驿站营地")
    let server = McpServerRecord.new(
        name: "github", command: "npx", args: ["-y", "x"],
        env: ["FROM_JSON": "json"], secretEnvKeys: ["SECRET_KEY"])
    try db.addMcpServer(server)
    try db.setMcpServerEnabled(campId: camp.id, serverId: server.id, enabled: true)
    let manager = McpServerManager(
        db: db,
        transportFactory: { record, env in
            let t = makeTransport(record, env)
            transportBox.append(t)
            return t
        },
        secretProvider: secretProvider,
        baseEnvironment: { baseEnv },
        initTimeout: .seconds(2),
        callTimeout: callTimeout
    )
    return (db, manager, camp, server)
}

@Test func managerStartsCachesToolsAndAssembles() async throws {
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, camp, server) = try makeManagerFixture(transportBox: box)
    await manager.ensureRunning(serverIds: [server.id])
    #expect(await manager.status(serverId: server.id) == .running(toolCount: 2))

    let tools = try await manager.assembledTools(campId: camp.id)
    #expect(tools.map(\.def.name) == ["mcp__github__list_issues", "mcp__github__screenshot"])
    #expect(tools[0].originalToolName == "list_issues")
    // schema 原样透传
    #expect(tools[0].def.inputSchema["properties"]?["repo"]?["type"]?.stringValue == "string")

    // 再次 ensureRunning：不重启、不重复握手（清单缓存）
    await manager.ensureRunning(serverIds: [server.id])
    #expect(box.values.count == 1)
    let handshakes = box.values[0].sent.filter { $0["method"]?.stringValue == "initialize" }
    #expect(handshakes.count == 1)
}

@Test func managerStartFailureIsDownAndNeverAutoRetries() async throws {
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, _, server) = try makeManagerFixture(
        transportBox: box,
        makeTransport: { _, _ in FakeMcpTransport(failOnStart: true) })
    await manager.ensureRunning(serverIds: [server.id])
    guard case .down = await manager.status(serverId: server.id) else {
        Issue.record("启动失败应标 down")
        return
    }
    // 绝不自动重试（M8-D3）：再多次 ensureRunning 都不再造新传输
    await manager.ensureRunning(serverIds: [server.id])
    await manager.ensureRunning(serverIds: [server.id])
    #expect(box.values.count == 1)
    // call 直接失败且 isDown
    let result = await manager.call(serverId: server.id, toolName: "t", arguments: .object([:]))
    guard case .failure(let error) = result else {
        Issue.record("down server 的调用应失败")
        return
    }
    #expect(error == .connectionDown(serverId: server.id))
}

@Test func managerRestartRevivesDownServer() async throws {
    let flag = LockedBox(true) // 第一次失败，重启后成功
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, camp, server) = try makeManagerFixture(
        transportBox: box,
        makeTransport: { _, _ in FakeMcpTransport(failOnStart: flag.get()) })
    await manager.ensureRunning(serverIds: [server.id])
    guard case .down = await manager.status(serverId: server.id) else {
        Issue.record("第一次启动应失败")
        return
    }
    flag.set(false)
    await manager.restart(serverId: server.id)
    #expect(await manager.status(serverId: server.id) == .running(toolCount: 2))
    #expect(try await manager.assembledTools(campId: camp.id).count == 2)
}

@Test func managerProcessDeathMarksDown() async throws {
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, camp, server) = try makeManagerFixture(transportBox: box)
    await manager.ensureRunning(serverIds: [server.id])
    #expect(await manager.status(serverId: server.id) == .running(toolCount: 2))

    box.values[0].die()
    var down = false
    for _ in 0..<40 {
        if case .down = await manager.status(serverId: server.id) { down = true; break }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(down)
    // down 后工具不再装配
    #expect(try await manager.assembledTools(campId: camp.id).isEmpty)
}

@Test func managerEnvMergePrecedenceBaseJsonSecret() async throws {
    let envBox = LockedArrayBox<[String: String]>()
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, _, server) = try makeManagerFixture(
        transportBox: box,
        makeTransport: { _, env in
            envBox.append(env)
            return FakeMcpTransport()
        },
        secretProvider: { _, key in key == "SECRET_KEY" ? "keychain-value" : nil },
        baseEnv: ["PATH": "/login/path", "FROM_JSON": "base-should-lose", "SECRET_KEY": "base-should-lose"])
    await manager.ensureRunning(serverIds: [server.id])
    let env = envBox.values[0]
    #expect(env["PATH"] == "/login/path")
    #expect(env["FROM_JSON"] == "json")           // envJson 覆盖登录底座
    #expect(env["SECRET_KEY"] == "keychain-value") // Keychain 覆盖一切
}

@Test func managerToolNameCollisionKeepsFirstDeterministically() async throws {
    let collidingTools: [JSONValue] = [
        ["name": "a.b", "description": "第一个", "inputSchema": ["type": "object"]],
        ["name": "a-b", "description": "撞名的第二个", "inputSchema": ["type": "object"]],
    ]
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, camp, server) = try makeManagerFixture(
        transportBox: box,
        makeTransport: { _, _ in
            FakeMcpTransport(responder: FakeMcpTransport.defaultResponder(tools: collidingTools))
        })
    await manager.ensureRunning(serverIds: [server.id])
    let tools = try await manager.assembledTools(campId: camp.id)
    #expect(tools.map(\.def.name) == ["mcp__github__a-b"])
    #expect(tools[0].originalToolName == "a.b") // 先到先得
}

// MARK: - 注入（CardRunner 三处同源）

private func makeCardFixture() throws -> (db: AppDatabase, cardId: String, base: URL) {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let workspace = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: workspace.path)
    return (db, ids.cardId, base)
}

private func runCardCollectingTools(
    db: AppDatabase, cardId: String, base: URL,
    toolAccess: ToolAccess, externalTools: [ExternalTool]
) async throws -> [ToolDef] {
    let workspace = base.appendingPathComponent("ws")
    let squad = try #require(try db.squad(forCard: cardId))
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "b1", name: "block_card", input: ["reason": "other", "detail": "测试终结"])],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 1, outputTokens: 1)
        ),
    ])
    let files = FileTools(workspaceRoot: workspace)
    var candidates: [ExternalTool] = [
        ExternalTool(
            def: .listDir,
            handler: FileToolHandler(tools: files, op: .list)
        ),
        ExternalTool(
            def: .readFile,
            handler: FileToolHandler(tools: files, op: .read)
        ),
        ExternalTool(
            def: .writeFile,
            handler: FileToolHandler(tools: files, op: .write)
        ),
        ExternalTool(def: .webFetch, handler: WebFetchTool()),
        ExternalTool(
            def: .runShell,
            handler: ShellTool(workspaceRoot: workspace)
        ),
        ExternalTool(
            def: .searchCampNotes,
            handler: CampNotesSearchTool(db: db, campId: squad.campId)
        ),
    ]
    candidates.append(contentsOf: externalTools)
    let authorizedCandidates = candidates.filter {
        toolAccess.allows($0.def.name)
    }
    let runner = CardRunner(
        provider: mock,
        capabilityToolsResolver: { _, _ in authorizedCandidates },
        maxTurns: 5,
        retryDelays: []
    )
    let terminal = CardRunnerTestTerminalRecorder()
    let board = CardRunnerTestBoardRecorder()
    let progress = CardRunnerTestProgressRecorder()
    let request = try cardRunnerTestRequest(
        campId: squad.campId,
        cardId: cardId,
        squadId: squad.id
    )
    _ = try await cardRunnerTestExecute(
        runner,
        workspaceURL: workspace,
        request: request,
        terminal: terminal,
        board: board,
        progress: progress
    )
    #expect(await terminal.snapshot().isEmpty)
    #expect(await board.snapshot().count == 1)
    return await mock.recordedTools.first ?? []
}

@Test func mcpToolRequiresExplicitAllowNotInheritedByLegacyFull() async throws {
    let (db, cardId, base) = try makeCardFixture()
    let external = ExternalTool(
        def: ToolDef(name: "mcp__github__list_issues", description: "列 issue", inputSchema: ["type": "object"]),
        handler: ClosureToolHandler { _ in .result("ok") })

    // 存量 "[]"（=内置全量）：MCP 不被继承（M6-D5b 地基螺栓）
    let legacyTools = try await runCardCollectingTools(
        db: db, cardId: cardId, base: base,
        toolAccess: ToolAccess.parse(toolsJson: "[]"), externalTools: [external])
    #expect(!legacyTools.map(\.name).contains("mcp__github__list_issues"))
    #expect(legacyTools.map(\.name).contains("web_fetch"))
}

@Test func mcpToolInjectedWithExplicitV2Allow() async throws {
    let (db, cardId, base) = try makeCardFixture()
    let external = ExternalTool(
        def: ToolDef(name: "mcp__github__list_issues", description: "列 issue", inputSchema: ["type": "object"]),
        handler: ClosureToolHandler { _ in .result("ok") })
    let access = ToolAccess.parse(
        toolsJson: ToolAccess.explicitJson(allow: ["read_file", "mcp__github__list_issues"]))
    let tools = try await runCardCollectingTools(
        db: db, cardId: cardId, base: base, toolAccess: access, externalTools: [external])
    let names = tools.map(\.name)
    #expect(names.contains("mcp__github__list_issues"))
    #expect(names.contains("read_file"))
    #expect(!names.contains("web_fetch")) // 显式名单是字面语义
    // 板工具永在
    #expect(names.contains("complete_card"))
}

@Test func malformedToolAccessSkipsMcpStartupAndRecordsKernelDiagnostic() async throws {
    let transports = LockedArrayBox<FakeMcpTransport>()
    let (db, manager, camp, _) = try makeManagerFixture(transportBox: transports)

    var companion = CompanionRecord.new(
        name: "坏配置伙伴", color: "red", rolePrompt: "执行", model: "m", campId: camp.id)
    companion.toolsJson = #"{"v":2,"allow":"not-an-array"}"#
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: camp.name, squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: companion.id, maxTurns: 5, campId: camp.id)
    let workspaceRoot = try attachP1F1DispatchContext(
        db: db,
        missionId: ids.missionId,
        companionId: companion.id
    )
    defer { try? FileManager.default.removeItem(at: workspaceRoot) }

    let provider = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "done", name: "complete_card", input: [
                "outcome": "完成",
                "summary": "仅使用行动板工具完成",
                "artifacts": [],
                "noArtifactReason": "无文件",
                "verification": [],
                "risks": [],
            ])],
            stopReason: .toolUse
        ),
    ])
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "malformed-tool-access-state-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: stateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: stateRoot) }
    let artifactRoot = stateRoot.appendingPathComponent(
        "artifacts",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: artifactRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let orchestrator = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil,
        mcpManager: manager
    )

    await orchestrator.recoverAndReconcile()
    try await orchestrator.waitUntilIdle()

    #expect(try db.card(id: ids.cardId)?.status == .blocked)
    #expect(transports.values.isEmpty)
    let degradations = try db.contextDegradations(
        missionId: ids.missionId,
        cardId: ids.cardId
    )
    #expect(degradations.count == 1)
    let degradation = try #require(degradations.first)
    #expect(degradation.dependencyType == .mcpServer)
    #expect(degradation.dependencyId == "mcpRegistry")
    #expect(degradation.policy == .required)
    #expect(try db.failureRecord(id: degradation.traceId)?.errorCode
        == .projectionDecodeFailed)
    let kernelErrors = try db.events(missionId: ids.missionId).filter {
        $0.kind == EventKind.kernelError
    }
    #expect(kernelErrors.count == 1)
    let diagnostic = try #require(kernelErrors.first)
    let diagnosticPayload = try JSONValue.decoded(from: diagnostic.payloadJson)
    #expect(diagnosticPayload.objectValue == [
        "message": .string("Engine execution context preflight failed."),
    ])
    await orchestrator.shutdown()
}

// MARK: - 桥接

@Test func mcpBridgeWrapsSuccessInExternalContentEnvelope() async throws {
    let box = LockedArrayBox<FakeMcpTransport>()
    let (db, manager, _, server) = try makeManagerFixture(transportBox: box)
    let (cardDb, cardId, _) = try makeCardFixture()
    _ = db // manager 的 db 与卡片 db 分开无碍——桥只用 manager 调用 + cardDb 记事件
    await manager.ensureRunning(serverIds: [server.id])
    guard let card = try cardDb.card(id: cardId) else {
        Issue.record("fixture 卡片缺失")
        return
    }
    let bridge = McpToolBridge(
        manager: manager, db: cardDb, missionId: card.missionId, cardId: cardId,
        serverId: server.id, serverName: "github", toolName: "list_issues")
    let outcome = await bridge.execute(input: ["repo": "a/b"])
    guard case .result(let text) = outcome else {
        Issue.record("应为 result")
        return
    }
    #expect(text.contains("以下内容来自外部来源：MCP·github"))
    #expect(text.contains("called:list_issues"))
}

@Test func mcpBridgeDownEmitsEventAndGuidesBlockCard() async throws {
    let box = LockedArrayBox<FakeMcpTransport>()
    let (_, manager, _, server) = try makeManagerFixture(
        transportBox: box,
        makeTransport: { _, _ in FakeMcpTransport(failOnStart: true) })
    let (cardDb, cardId, _) = try makeCardFixture()
    await manager.ensureRunning(serverIds: [server.id]) // down
    guard let card = try cardDb.card(id: cardId) else {
        Issue.record("fixture 卡片缺失")
        return
    }
    let bridge = McpToolBridge(
        manager: manager, db: cardDb, missionId: card.missionId, cardId: cardId,
        serverId: server.id, serverName: "github", toolName: "list_issues")
    let outcome = await bridge.execute(input: .object([:]))
    guard case .error(let message) = outcome else {
        Issue.record("down 应为 error")
        return
    }
    #expect(message.contains("连接已中断"))
    #expect(message.contains("block_card"))
    let kinds = try cardDb.events(cardId: cardId).map(\.kind)
    #expect(kinds.contains("mcp_server_down")) // 裸字符串钉住持久化值
}

@Test func secretProviderAbsentAndThrowsAreDistinct() async throws {
    let missingTransports = LockedArrayBox<FakeMcpTransport>()
    let (_, missingManager, _, missingServer) = try makeManagerFixture(
        transportBox: missingTransports,
        secretProvider: { _, _ in nil },
        baseEnv: [:]
    )
    let missing = await missingManager.ensureRunning(
        serverIds: [missingServer.id]
    )
    #expect(missing.count == 1)
    switch missing[0].result {
    case .failure(.secretMissing(let serverId)):
        #expect(serverId == missingServer.id)
    default:
        Issue.record("缺失声明 secret 必须返回 secretMissing")
    }
    #expect(missingTransports.values.isEmpty)

    let readFailureTransports = LockedArrayBox<FakeMcpTransport>()
    let (_, readFailureManager, _, readFailureServer) =
        try makeManagerFixture(
            transportBox: readFailureTransports,
            secretProvider: { _, _ in
                throw KeychainError(status: -25_293)
            },
            baseEnv: ["SECRET_KEY": "must-not-fallback"]
        )
    let readFailure = await readFailureManager.ensureRunning(
        serverIds: [readFailureServer.id]
    )
    switch readFailure[0].result {
    case .failure(.secretRead(let serverId, let status)):
        #expect(serverId == readFailureServer.id)
        #expect(status == -25_293)
    default:
        Issue.record("Keychain 读取错误必须返回 secretRead，且不得回退")
    }
    #expect(readFailureTransports.values.isEmpty)

    for providerValue in [String?.none, String?.some("")] {
        let environment = LockedArrayBox<[String: String]>()
        let fallbackTransports = LockedArrayBox<FakeMcpTransport>()
        let (_, fallbackManager, _, fallbackServer) = try makeManagerFixture(
            transportBox: fallbackTransports,
            makeTransport: { _, env in
                environment.append(env)
                return FakeMcpTransport()
            },
            secretProvider: { _, _ in providerValue },
            baseEnv: ["SECRET_KEY": "compatible-existing-value"]
        )
        let fallback = await fallbackManager.ensureRunning(
            serverIds: [fallbackServer.id]
        )
        switch fallback[0].result {
        case .success(let ready):
            #expect(ready == McpServerReady(
                serverId: fallbackServer.id,
                toolCount: 2
            ))
        case .failure(let error):
            Issue.record("已有非空 env 应保持兼容，实得 \(error)")
        }
        #expect(environment.values == [[
            "SECRET_KEY": "compatible-existing-value",
            "FROM_JSON": "json",
        ]])
    }

    let startTransports = LockedArrayBox<FakeMcpTransport>()
    let (_, startManager, _, startServer) = try makeManagerFixture(
        transportBox: startTransports,
        makeTransport: { _, _ in FakeMcpTransport(failOnStart: true) },
        baseEnv: ["SECRET_KEY": "present"]
    )
    let start = await startManager.ensureRunning(serverIds: [startServer.id])
    #expect(start[0].result == .failure(
        .transportStart(serverId: startServer.id)
    ))

    let listTransports = LockedArrayBox<FakeMcpTransport>()
    let (_, listManager, _, listServer) = try makeManagerFixture(
        transportBox: listTransports,
        makeTransport: { _, _ in
            FakeMcpTransport(responder: { message in
                guard let id = message["id"] else { return [] }
                switch message["method"]?.stringValue {
                case "initialize":
                    return [[
                        "jsonrpc": "2.0", "id": id,
                        "result": [
                            "protocolVersion": "2025-06-18",
                            "capabilities": [:],
                            "serverInfo": ["name": "f", "version": "1"],
                        ],
                    ]]
                case "tools/list":
                    return [[
                        "jsonrpc": "2.0", "id": id,
                        "error": ["code": -32_603, "message": "list failed"],
                    ]]
                default:
                    return []
                }
            })
        },
        baseEnv: ["SECRET_KEY": "present"]
    )
    let list = await listManager.ensureRunning(serverIds: [listServer.id])
    #expect(list[0].result == .failure(.toolList(serverId: listServer.id)))
}

@Test func assembledToolsRegistryFailureThrows() async throws {
    let closedTransports = LockedArrayBox<FakeMcpTransport>()
    let closed = try makeManagerFixture(transportBox: closedTransports)
    try closed.db.pool.close()
    do {
        _ = try await closed.manager.assembledTools(campId: closed.camp.id)
        Issue.record("关闭的 registry 必须抛 registryRead")
    } catch let error as McpOperationError {
        #expect(error == .registryRead(serverId: nil))
    }

    let missingTransports = LockedArrayBox<FakeMcpTransport>()
    let missing = try makeManagerFixture(transportBox: missingTransports)
    do {
        _ = try await missing.manager.assembledTools(serverId: "missing-server")
        Issue.record("缺失 server 必须抛 serverMissing")
    } catch let error as McpOperationError {
        #expect(error == .serverMissing(serverId: "missing-server"))
    }

    let malformed: [(ConfigField, (inout McpServerRecord) -> Void)] = [
        (.args, { $0.argsJson = #"{"broken":true}"# }),
        (.env, { $0.envJson = #"["not-an-object"]"# }),
        (.secretEnvKeys, { $0.secretEnvKeysJson = #"{"not":"array"}"# }),
    ]
    for (field, mutate) in malformed {
        let transports = LockedArrayBox<FakeMcpTransport>()
        let fixture = try makeManagerFixture(transportBox: transports)
        var record = fixture.server
        mutate(&record)
        try fixture.db.updateMcpServer(record)
        do {
            _ = try await fixture.manager.assembledTools(serverId: record.id)
            Issue.record("非法 \(field.rawValue) 不得退化为空清单")
        } catch let error as McpOperationError {
            #expect(error == .invalidConfig(
                serverId: record.id,
                field: field
            ))
        }
        #expect(transports.values.isEmpty)
    }

    let canonicalRecords = LockedArrayBox<McpServerRecord>()
    let canonicalTransports = LockedArrayBox<FakeMcpTransport>()
    let canonical = try makeManagerFixture(
        transportBox: canonicalTransports,
        makeTransport: { record, _ in
            canonicalRecords.append(record)
            return FakeMcpTransport()
        },
        baseEnv: ["SECRET_KEY": "present"]
    )
    var noncanonical = canonical.server
    noncanonical.argsJson = #"[ "-y", "x" ]"#
    noncanonical.envJson = #"{"z":"2", "a":"1"}"#
    noncanonical.secretEnvKeysJson = #"[ "SECRET_KEY" ]"#
    try canonical.db.updateMcpServer(noncanonical)
    let outcome = await canonical.manager.ensureRunning(
        serverIds: [noncanonical.id]
    )
    guard case .success = outcome[0].result,
          let canonicalRecord = canonicalRecords.values.first
    else {
        Issue.record("合法配置应启动并传给 factory")
        return
    }
    #expect(canonicalRecord.id == noncanonical.id)
    #expect(canonicalRecord.argsJson == #"["-y","x"]"#)
    #expect(canonicalRecord.envJson == #"{"a":"1","z":"2"}"#)
    #expect(canonicalRecord.secretEnvKeysJson == #"["SECRET_KEY"]"#)
}

@Test func selectedMcpToolIsLocalUnavailableWithoutManagerEffects() async throws {
    let transports = LockedArrayBox<FakeMcpTransport>()
    let fixture = try makeManagerFixture(
        transportBox: transports,
        makeTransport: { _, _ in
            FakeMcpTransport(
                responder: FakeMcpTransport.defaultResponder(tools: [[
                    "name": "screenshot",
                    "description": "只有另一个工具",
                    "inputSchema": ["type": "object"],
                ]])
            )
        },
        baseEnv: ["SECRET_KEY": "present"]
    )
    let selected = "mcp__github__list_issues"
    let toolsJson = ToolAccess.explicitJson(allow: [selected])
    var companion = CompanionRecord.new(
        name: "工具伙伴",
        color: "blue",
        rolePrompt: "执行",
        model: "model",
        campId: fixture.camp.id
    )
    companion.toolsJson = toolsJson
    try fixture.db.saveCompanion(companion)
    let ids = try fixture.db.createSingleCardMission(
        campName: fixture.camp.name,
        squadName: "s",
        goal: "g",
        cardTitle: "t",
        cardDescription: "d",
        expectedOutput: "e",
        assigneeId: companion.id,
        maxTurns: 5,
        campId: fixture.camp.id
    )
    guard let mission = try fixture.db.mission(id: ids.missionId),
          let card = try fixture.db.card(id: ids.cardId)
    else {
        Issue.record("上下文 fixture 缺失")
        return
    }
    let searchReads = LockedBox(0)
    let campReads = LockedBox(0)
    let companionReads = LockedBox(0)
    let loader = ContextDependencyLoader(
        database: fixture.db,
        manager: fixture.manager,
        reporter: FailureReporter(database: fixture.db),
        searchCredential: {
            searchReads.set(searchReads.get() + 1)
            return nil
        },
        knowledge: ContextKnowledgeReaders(
            camp: { _ in
                campReads.set(campReads.get() + 1)
                return []
            },
            companion: { _ in
                companionReads.set(companionReads.get() + 1)
                return []
            }
        ),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
    for kind: RuntimeProfileKind in [.openAIAPI, .cliCodex] {
        let request = try ContextDependencyRequest(
            mission: mission,
            card: card,
            camp: fixture.camp,
            companion: companion,
            runtimeProfileKind: kind,
            toolAccess: ToolAccess.parse(toolsJson: toolsJson),
            toolsJson: toolsJson
        )
        let result = await loader.load(request) { _ in
            Issue.record("selected MCP must not emit optional degradation")
        }
        guard case .ready(let ready) = result else {
            Issue.record("selected MCP must prepare its fixed local F1D tool")
            return
        }
        let tool = try #require(ready.externalTools.first)

        // Mutation caught: profile-kind rejection, manager start/list/call,
        // wrapped MCP handler capture, or drift from the exact local definition.
        #expect(ready.externalTools.count == 1)
        #expect(tool.def.name == selected)
        #expect(tool.def.description == "Unavailable in F1D engine execution.")
        #expect(
            tool.def.inputSchema == JSONValue.object([
                "additionalProperties": true,
                "properties": .object([:]),
                "type": "object",
            ])
        )
        guard case .error(let message) = await tool.handler.execute(input: [
            "must-not-reach-manager": true,
        ]) else {
            Issue.record("selected MCP handler must be fixed unavailable")
            return
        }
        #expect(message == "engine_approval_required")
        #expect(ready.degradations.isEmpty)
    }
    #expect(searchReads.get() == 0)
    #expect(campReads.get() == 2)
    #expect(companionReads.get() == 2)
    #expect(transports.values.isEmpty)
    #expect(try fixture.db.card(id: ids.cardId)?.status == .ready)
    let degradations = try fixture.db.contextDegradations(
        missionId: ids.missionId,
        cardId: ids.cardId
    )
    #expect(degradations.isEmpty)
}

@Test func mcpServerDeletePreimageAndReverseRollbackAreAtomic() async throws {
    let server = McpServerRecord.new(
        name: "delete-fixture",
        command: "fixture",
        args: [],
        secretEnvKeys: ["TOKEN_A", "TOKEN_B"]
    )
    let accounts = try ["TOKEN_A", "TOKEN_B"]
        .map {
            try McpCredentialAccount(
                server: server,
                secretEnvironmentKey: $0
            )
        }
        .sorted()
    #expect(accounts.map(\.rawValue) == accounts.map(\.rawValue).sorted {
        Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8))
    })

    func makeValues() -> [String: String] {
        Dictionary(uniqueKeysWithValues: accounts.enumerated().map {
            ($0.element.rawValue, "secret-\($0.offset)")
        })
    }

    let preimageStore = McpRecordingCredentialStore(makeValues())
    preimageStore.injectFailure(
        .get,
        account: accounts[0].rawValue,
        status: -25_291
    )
    let preimageCoordinator = CredentialBundleCoordinator(
        access: SynchronizedCredentialAccess(store: preimageStore)
    )
    let preimageDBCalls = LockedArrayBox<String>()
    let preimage = await preimageCoordinator.commitMcpServerDeletion(
        secretAccounts: accounts,
        interactionPolicy: .allow,
        deleteDatabaseRow: { preimageDBCalls.append("db") }
    )
    #expect(preimage == .failure(.preimageRead(status: -25_291)))
    #expect(preimageStore.snapshot == makeValues())
    #expect(preimageStore.recordedCalls == [
        McpCredentialStoreCall(
            action: .get,
            account: accounts[0].rawValue
        ),
    ])
    #expect(preimageDBCalls.values.isEmpty)

    let deleteStore = McpRecordingCredentialStore(makeValues())
    deleteStore.injectFailure(
        .delete,
        account: accounts[1].rawValue,
        status: -25_292
    )
    let deleteCoordinator = CredentialBundleCoordinator(
        access: SynchronizedCredentialAccess(store: deleteStore)
    )
    let deleteDBCalls = LockedArrayBox<String>()
    let delete = await deleteCoordinator.commitMcpServerDeletion(
        secretAccounts: accounts,
        interactionPolicy: .allow,
        deleteDatabaseRow: { deleteDBCalls.append("db") }
    )
    #expect(delete == .failure(.commit(
        mutation: .secret,
        status: -25_292
    )))
    #expect(deleteStore.snapshot == makeValues())
    #expect(deleteDBCalls.values.isEmpty)
    #expect(deleteStore.recordedCalls.suffix(3) == [
        McpCredentialStoreCall(
            action: .delete,
            account: accounts[0].rawValue
        ),
        McpCredentialStoreCall(
            action: .delete,
            account: accounts[1].rawValue
        ),
        McpCredentialStoreCall(
            action: .set,
            account: accounts[0].rawValue
        ),
    ])

    let databaseStore = McpRecordingCredentialStore(makeValues())
    let databaseCoordinator = CredentialBundleCoordinator(
        access: SynchronizedCredentialAccess(store: databaseStore)
    )
    let databaseDBCalls = LockedArrayBox<String>()
    let databaseFailure = await databaseCoordinator.commitMcpServerDeletion(
        secretAccounts: accounts,
        interactionPolicy: .allow,
        deleteDatabaseRow: {
            databaseDBCalls.append("db")
            throw McpFixtureError.databaseDelete
        }
    )
    #expect(databaseFailure == .failure(.commit(
        mutation: .databaseRow,
        status: nil
    )))
    #expect(databaseDBCalls.values == ["db"])
    #expect(databaseStore.snapshot == makeValues())
    #expect(databaseStore.recordedCalls.suffix(2) == [
        McpCredentialStoreCall(
            action: .set,
            account: accounts[1].rawValue
        ),
        McpCredentialStoreCall(
            action: .set,
            account: accounts[0].rawValue
        ),
    ])

    let rollbackStore = McpRecordingCredentialStore(makeValues())
    rollbackStore.injectFailure(
        .delete,
        account: accounts[1].rawValue,
        status: -25_293
    )
    rollbackStore.injectFailure(
        .set,
        account: accounts[0].rawValue,
        status: -25_294
    )
    let rollbackCoordinator = CredentialBundleCoordinator(
        access: SynchronizedCredentialAccess(store: rollbackStore)
    )
    let rollback = await rollbackCoordinator.commitMcpServerDeletion(
        secretAccounts: accounts,
        interactionPolicy: .allow,
        deleteDatabaseRow: {}
    )
    #expect(rollback == .failure(.rollback(status: -25_294)))
    #expect(rollbackStore.snapshot[accounts[0].rawValue] == nil)
    #expect(rollbackStore.snapshot[accounts[1].rawValue] == "secret-1")

    let successDB = try tempDB()
    try successDB.addMcpServer(server)
    let successStore = McpRecordingCredentialStore(makeValues())
    let successCoordinator = CredentialBundleCoordinator(
        access: SynchronizedCredentialAccess(store: successStore)
    )
    let success = await successCoordinator.commitMcpServerDeletion(
        secretAccounts: accounts,
        interactionPolicy: .allow,
        deleteDatabaseRow: {
            try successDB.deleteMcpServer(id: server.id)
        }
    )
    #expect(success == .success(CredentialMutationReceipt(
        mutationCount: accounts.count + 1
    )))
    #expect(try successDB.mcpServer(id: server.id) == nil)
    #expect(successStore.snapshot.isEmpty)

    let maintenanceTransports = LockedArrayBox<FakeMcpTransport>()
    let maintenance = try makeManagerFixture(
        transportBox: maintenanceTransports,
        baseEnv: ["SECRET_KEY": "present"]
    )
    let lease: McpMaintenanceLease
    switch await maintenance.manager.acquireMaintenance(
        serverId: maintenance.server.id
    ) {
    case .success(let acquired):
        lease = acquired
    case .failure(let error):
        Issue.record("maintenance 获取失败：\(error)")
        return
    }
    let during = await maintenance.manager.ensureRunning(
        serverIds: [maintenance.server.id]
    )
    #expect(during[0].result == .failure(
        .serverMaintenance(serverId: maintenance.server.id)
    ))
    #expect(await maintenance.manager.restart(serverId: maintenance.server.id)
        == .failure(.serverMaintenance(serverId: maintenance.server.id)))
    do {
        _ = try await maintenance.manager.assembledTools(
            serverId: maintenance.server.id
        )
        Issue.record("maintenance 中不得装配工具")
    } catch let error as McpOperationError {
        #expect(error == .serverMaintenance(serverId: maintenance.server.id))
    }
    #expect(await maintenance.manager.call(
        serverId: maintenance.server.id,
        toolName: "list_issues",
        arguments: .object([:])
    ) == .failure(.serverMaintenance(serverId: maintenance.server.id)))
    switch await maintenance.manager.finishMaintenance(
        lease,
        completion: .keepStopped
    ) {
    case .success:
        break
    case .failure(let error):
        Issue.record("合法 lease 应成功释放：\(error)")
    }
    switch await maintenance.manager.finishMaintenance(
        lease,
        completion: .keepStopped
    ) {
    case .success:
        Issue.record("已消费 lease 不得再次成功")
    case .failure(let error):
        #expect(error == .invalidLease(serverId: maintenance.server.id))
    }

#if DEBUG
    let failFinish = LockedBox(true)
    let finishTransports = LockedArrayBox<FakeMcpTransport>()
    let finishDB = try tempDB()
    let finishServer = McpServerRecord.new(
        name: "finish",
        command: "fixture",
        args: []
    )
    try finishDB.addMcpServer(finishServer)
    let finishManager = McpServerManager(
        db: finishDB,
        transportFactory: { _, _ in
            let transport = FakeMcpTransport()
            finishTransports.append(transport)
            return transport
        },
        secretProvider: { _, _ in nil },
        baseEnvironment: { [:] },
        initTimeout: .seconds(2),
        callTimeout: .seconds(2),
        auditHooks: McpManagerAuditHooks(
            onStart: {},
            finishMaintenanceFailure: { serverId, _ in
                guard failFinish.get() else { return nil }
                failFinish.set(false)
                return .finishFailed(serverId: serverId)
            }
        )
    )
    let finishLease: McpMaintenanceLease
    switch await finishManager.acquireMaintenance(serverId: finishServer.id) {
    case .success(let acquired):
        finishLease = acquired
    case .failure(let error):
        Issue.record("finish fixture 获取失败：\(error)")
        return
    }
    switch await finishManager.finishMaintenance(
        finishLease,
        completion: .removeHandle
    ) {
    case .success:
        Issue.record("注入的 finish failure 不得成功")
    case .failure(let error):
        #expect(error == .finishFailed(serverId: finishServer.id))
    }
    #expect(await finishManager.lastError(serverId: finishServer.id) == nil)
    #expect(await finishManager.ensureRunning(serverIds: [finishServer.id])[0]
        .result == .failure(.serverMaintenance(serverId: finishServer.id)))
    switch await finishManager.finishMaintenance(
        finishLease,
        completion: .removeHandle
    ) {
    case .success:
        break
    case .failure(let error):
        Issue.record("相同 lease 重试应成功：\(error)")
    }
#endif
}

@Test func toolBridgeEventWriteFailureRemainsVisibleWithTrace() async throws {
#if DEBUG
    let downTransports = LockedArrayBox<FakeMcpTransport>()
    let down = try makeManagerFixture(
        transportBox: downTransports,
        makeTransport: { _, _ in FakeMcpTransport(failOnStart: true) },
        baseEnv: ["SECRET_KEY": "present"]
    )
    let ids = try down.db.createSingleCardMission(
        campName: down.camp.name,
        squadName: "bridge",
        goal: "bridge",
        cardTitle: "bridge",
        cardDescription: "bridge",
        expectedOutput: "bridge",
        assigneeId: nil,
        maxTurns: 5,
        campId: down.camp.id
    )
    try await down.db.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER abort_mcp_server_down_event
            BEFORE INSERT ON event
            WHEN NEW.kind = 'mcp_server_down'
            BEGIN
              SELECT RAISE(ABORT, 'event-write-failed');
            END
            """)
    }
    _ = await down.manager.ensureRunning(serverIds: [down.server.id])
    let downWriter = McpRecordingFailureWriter()
    let downSink = McpRecordingFailureSink()
    let downCalls = LockedBox(0)
    let downTraceID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let downBridge = McpToolBridge(
        manager: down.manager,
        db: down.db,
        missionId: ids.missionId,
        cardId: ids.cardId,
        serverId: down.server.id,
        serverName: "secret-display-name",
        toolName: "secret-tool-name",
        campId: down.camp.id,
        reporter: FailureReporter(writer: downWriter, logSink: downSink),
        makeTrace: OperationTraceFactory(
            makeID: { downTraceID },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        ),
        auditHooks: McpBridgeAuditHooks(onCall: {
            downCalls.set(downCalls.get() + 1)
        })
    )
    let downOutcome = await downBridge.execute(input: ["private": "argument"])
    guard case .error(let downMessage) = downOutcome else {
        Issue.record("connectionDown 必须返回 error")
        return
    }
    #expect(downCalls.get() == 1)
    #expect(downMessage.contains(downTraceID.uuidString))
    #expect(!downMessage.contains("secret-display-name"))
    #expect(!downMessage.contains("secret-tool-name"))
    #expect(downWriter.records.count == 1)
    #expect(downWriter.records[0].id == downTraceID.uuidString)
    #expect(downWriter.records[0].errorCode == .mcpConnectionDown)
    #expect(!downWriter.records[0].userMessage.contains("secret-display-name"))
    #expect(!downWriter.records[0].diagnosticJson.contains("secret-tool-name"))
    #expect(downSink.entries.count == 1)
    #expect(downSink.entries[0].traceId == downTraceID.uuidString)
    #expect(downSink.entries[0].errorCode == .mcpConnectionDown)
    #expect(try down.db.failureRecord(id: downTraceID.uuidString) == nil)
    #expect(try down.db.events(cardId: ids.cardId)
        .filter { $0.kind == EventKind.mcpServerDown }.isEmpty)

    let toolTransports = LockedArrayBox<FakeMcpTransport>()
    let tool = try makeManagerFixture(
        transportBox: toolTransports,
        makeTransport: { _, _ in
            FakeMcpTransport(responder: { message in
                guard let id = message["id"] else { return [] }
                switch message["method"]?.stringValue {
                case "initialize":
                    return [[
                        "jsonrpc": "2.0", "id": id,
                        "result": [
                            "protocolVersion": "2025-06-18",
                            "capabilities": [:],
                            "serverInfo": ["name": "f", "version": "1"],
                        ],
                    ]]
                case "tools/list":
                    return [[
                        "jsonrpc": "2.0", "id": id,
                        "result": [
                            "tools": .array(FakeMcpTransport.defaultTools),
                        ],
                    ]]
                case "tools/call":
                    return [[
                        "jsonrpc": "2.0", "id": id,
                        "result": [
                            "content": [[
                                "type": "text",
                                "text": "raw external failure",
                            ]],
                            "isError": true,
                        ],
                    ]]
                default:
                    return []
                }
            })
        },
        baseEnv: ["SECRET_KEY": "present"]
    )
    let toolIDs = try tool.db.createSingleCardMission(
        campName: tool.camp.name,
        squadName: "tool",
        goal: "tool",
        cardTitle: "tool",
        cardDescription: "tool",
        expectedOutput: "tool",
        assigneeId: nil,
        maxTurns: 5,
        campId: tool.camp.id
    )
    _ = await tool.manager.ensureRunning(serverIds: [tool.server.id])
    let toolWriter = McpRecordingFailureWriter()
    let toolSink = McpRecordingFailureSink()
    let toolTraceID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    let toolBridge = McpToolBridge(
        manager: tool.manager,
        db: tool.db,
        missionId: toolIDs.missionId,
        cardId: toolIDs.cardId,
        serverId: tool.server.id,
        serverName: "raw-server",
        toolName: "list_issues",
        campId: tool.camp.id,
        reporter: FailureReporter(writer: toolWriter, logSink: toolSink),
        makeTrace: OperationTraceFactory(
            makeID: { toolTraceID },
            now: { Date(timeIntervalSince1970: 1_700_000_001) }
        ),
        auditHooks: McpBridgeAuditHooks(onCall: {})
    )
    guard case .error(let toolMessage) = await toolBridge.execute(input: [:])
    else {
        Issue.record("tool-level isError 必须返回 error")
        return
    }
    #expect(toolMessage.contains(toolTraceID.uuidString))
    #expect(!toolMessage.contains("raw external failure"))
    #expect(toolWriter.records.count == 1)
    #expect(toolWriter.records[0].errorCode == .mcpToolCallFailed)
    #expect(toolWriter.records[0].id == toolTraceID.uuidString)
    #expect(try tool.db.events(cardId: toolIDs.cardId)
        .filter { $0.kind == EventKind.mcpServerDown }.isEmpty)
#else
    Issue.record("MCP bridge audit fixture requires DEBUG")
#endif
}

// MARK: - 测试小工具

final class LockedBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ value: T) { self.value = value }
    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    func set(_ new: T) {
        lock.lock()
        defer { lock.unlock() }
        value = new
    }
}

final class LockedArrayBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []
    func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        items.append(item)
    }
    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}
