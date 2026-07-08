import Testing
import Foundation
import AgentLoopCore

/// Manager 全路径活体探针（诊断用，env 门控）：走与 App 完全相同的
/// McpServerManager 默认工厂路径拉起真实 playwright server。
@Test func mcpManagerSpikeAgainstRealPlaywright() async throws {
    guard ProcessInfo.processInfo.environment["AGENTLOOP_MCP_MANAGER_SPIKE"] == "1" else {
        return
    }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let db = try AppDatabase(path: dir.appendingPathComponent("t.sqlite").path)
    let camp = try db.createCamp(name: "spike")
    let server = McpServerRecord.new(
        name: "playwright", command: "npx", args: ["-y", "@playwright/mcp@latest"])
    try db.addMcpServer(server)
    try db.setMcpServerEnabled(campId: camp.id, serverId: server.id, enabled: true)

    let manager = McpServerManager(db: db)
    print("spike: ensureRunning start \(Date())")
    await manager.ensureRunning(serverIds: [server.id])
    print("spike: ensureRunning done \(Date()) status=\(await manager.status(serverId: server.id))")
    let tools = await manager.assembledTools(campId: camp.id)
    print("spike: tools=\(tools.map(\.def.name))")
    #expect(!tools.isEmpty)
    await manager.stopAll()
}
