import Testing
import Foundation
import AgentLoopCore

/// M8-D1 活体探针：对真实 filesystem MCP server（npx 拉起）跑通
/// initialize → tools/list → tools/call 全链路。
/// 依赖本机 Node + 网络（npx 首跑会下包），默认跳过——
/// 设 AGENTLOOP_MCP_SPIKE=1 手动执行（套件保持确定性）。
@Test func mcpSpikeAgainstRealFilesystemServer() async throws {
    guard ProcessInfo.processInfo.environment["AGENTLOOP_MCP_SPIKE"] == "1" else {
        return
    }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try "驿路联通".write(to: dir.appendingPathComponent("hello.txt"), atomically: true, encoding: .utf8)

    let env = await LoginShellEnvironment.shared.environment()
    let transport = StdioProcessTransport(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", dir.path],
        environment: env)
    let client = MiniMcpClient(transport: transport)
    // npx 首跑可能要下载包，握手给宽限
    try await client.connect(timeout: .seconds(60))
    let tools = try await client.listTools(timeout: .seconds(30))
    #expect(!tools.isEmpty)
    #expect(tools.contains { $0.name == "read_text_file" || $0.name == "read_file" })

    let readTool = tools.first { $0.name == "read_text_file" }?.name ?? "read_file"
    let result = try await client.callTool(
        name: readTool,
        arguments: ["path": .string(dir.appendingPathComponent("hello.txt").path)],
        timeout: .seconds(30))
    #expect(result.text.contains("驿路联通"))
    #expect(!result.isError)
    await client.close()
}
