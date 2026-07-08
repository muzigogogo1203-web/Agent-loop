import Foundation
import GRDB

// MARK: - MCP 驿站 CRUD（M8-D2）

extension AppDatabase {
    public func mcpServers() throws -> [McpServerRecord] {
        try pool.read { db in
            try McpServerRecord.order(Column("createdAt"), Column.rowID).fetchAll(db)
        }
    }

    public func mcpServer(id: String) throws -> McpServerRecord? {
        try pool.read { db in
            try McpServerRecord.fetchOne(db, key: id)
        }
    }

    public func addMcpServer(_ record: McpServerRecord) throws {
        try pool.write { db in
            try record.insert(db)
        }
    }

    /// 只允许改 command/args/env/secretKeys/experimental——name 是工具名的组成部分，
    /// 建后不可改（改名会使伙伴白名单失配，见 McpServerRecord.name 注释）。
    public func updateMcpServer(_ record: McpServerRecord) throws {
        try pool.write { db in
            guard let existing = try McpServerRecord.fetchOne(db, key: record.id) else {
                throw RecordNotFoundError(table: "mcp_server", id: record.id)
            }
            var next = record
            next.name = existing.name
            next.createdAt = existing.createdAt
            try next.update(db)
        }
    }

    /// 删除驿站及其全部营地启用关联（enable 行是纯关联非事实，随删无碍）。
    public func deleteMcpServer(id: String) throws {
        _ = try pool.write { db in
            try CampMcpEnableRecord.filter(Column("serverId") == id).deleteAll(db)
            try McpServerRecord.deleteOne(db, key: id)
        }
    }

    public func enabledMcpServers(campId: String) throws -> [McpServerRecord] {
        try pool.read { db in
            try McpServerRecord.fetchAll(
                db,
                sql: """
                    SELECT mcp_server.*
                    FROM mcp_server
                    JOIN camp_mcp_enable ON camp_mcp_enable.serverId = mcp_server.id
                    WHERE camp_mcp_enable.campId = ?
                    ORDER BY mcp_server.createdAt, mcp_server.rowid
                    """,
                arguments: [campId]
            )
        }
    }

    public func enabledMcpServerIds(campId: String) throws -> Set<String> {
        try pool.read { db in
            let rows = try CampMcpEnableRecord.filter(Column("campId") == campId).fetchAll(db)
            return Set(rows.map(\.serverId))
        }
    }

    public func setMcpServerEnabled(campId: String, serverId: String, enabled: Bool) throws {
        try pool.write { db in
            if enabled {
                // 幂等：重复启用不报错
                try CampMcpEnableRecord(campId: campId, serverId: serverId)
                    .insert(db, onConflict: .ignore)
            } else {
                try CampMcpEnableRecord
                    .filter(Column("campId") == campId && Column("serverId") == serverId)
                    .deleteAll(db)
            }
        }
    }

    /// 行动级事件追加（M8：mcp_server_down 等无 runId 上下文的诊断事件）。
    public func appendMissionEvent(missionId: String, cardId: String?, kind: String, payload: JSONValue) throws {
        try pool.write { db in
            try Self.appendEvent(db, missionId: missionId, cardId: cardId, runId: nil,
                                 kind: kind, payload: payload)
        }
    }
}
