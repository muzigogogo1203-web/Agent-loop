import Foundation

/// MCP 工具 → ToolHandler 桥（M8-D4）：调用 Manager，结果过 ExternalContent 包裹
/// （外部内容是资料不是指令，M6-D9 信任边界）。连接层死亡时记 mcp_server_down
/// 事件（挂在行动上，UI 渲染受阻引导）并给伙伴人话错误——由伙伴自行决定
/// 改道或 block_card(tool_failure)，与既有工具错误语义一致。
public struct McpToolBridge: ToolHandler {
    let manager: McpServerManager
    let db: AppDatabase
    let missionId: String
    let cardId: String
    let serverId: String
    let serverName: String
    let toolName: String

    public init(manager: McpServerManager, db: AppDatabase, missionId: String, cardId: String,
                serverId: String, serverName: String, toolName: String) {
        self.manager = manager
        self.db = db
        self.missionId = missionId
        self.cardId = cardId
        self.serverId = serverId
        self.serverName = serverName
        self.toolName = toolName
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        let outcome = await manager.call(serverId: serverId, toolName: toolName, arguments: input)
        switch outcome {
        case .success(let call):
            let wrapped = ExternalContent.wrap(source: "MCP·\(serverName)", body: call.text)
            return call.isError ? .error(wrapped) : .result(wrapped)
        case .failure(let error):
            if error.isDown {
                try? db.appendMissionEvent(
                    missionId: missionId,
                    cardId: cardId,
                    kind: EventKind.mcpServerDown,
                    payload: [
                        "serverId": .string(serverId),
                        "serverName": .string(serverName),
                        "tool": .string(toolName),
                        "detail": .string(error.readable),
                    ]
                )
                return .error("驿站「\(serverName)」已停摆（\(error.readable)）。它不会自动重启——用户需在设置页手动重启。若无法绕开该工具，请用 block_card（reason=tool_failure）挂起并说明。")
            }
            return .error("驿站「\(serverName)」工具 \(toolName) 调用失败：\(error.readable)")
        }
    }
}
