import Testing
import Foundation
import AgentLoopCore

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
    baseEnv: [String: String] = [:],
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

    let tools = await manager.assembledTools(campId: camp.id)
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
    #expect(error.isDown)
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
    #expect(await manager.assembledTools(campId: camp.id).count == 2)
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
    #expect(await manager.assembledTools(campId: camp.id).isEmpty)
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
    let tools = await manager.assembledTools(campId: camp.id)
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
    let mock = MockProvider(script: [
        TurnResult(
            content: [.toolUse(id: "b1", name: "block_card", input: ["reason": "other", "detail": "测试终结"])],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 1, outputTokens: 1)
        ),
    ])
    let runner = CardRunner(db: db, provider: mock, artifactStoreRoot: base.appendingPathComponent("store"))
    for try await _ in try runner.run(
        cardId: cardId, companionName: "n", rolePrompt: "r",
        toolAccess: toolAccess, externalTools: externalTools
    ) {}
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
    #expect(message.contains("停摆"))
    #expect(message.contains("block_card"))
    let kinds = try cardDb.events(cardId: cardId).map(\.kind)
    #expect(kinds.contains("mcp_server_down")) // 裸字符串钉住持久化值
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
