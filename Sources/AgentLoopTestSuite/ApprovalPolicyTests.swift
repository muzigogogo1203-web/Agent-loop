import Testing
import Foundation
import GRDB
import AgentLoopCore

// M7-D1/D2：工具风险分级 × 行动自主档位 放行矩阵

@Test func toolRiskMappingSingleSource() {
    // 板工具 + 只读五件 = readOnly（终结契约不可被门挡）
    for name in ["complete_card", "block_card", "add_progress_note", "ask_user",
                 "list_dir", "read_file", "web_fetch", "web_search", "search_camp_notes"] {
        #expect(ToolDef.risk(name) == .readOnly, "\(name) 应为只读级")
    }
    #expect(ToolDef.risk("write_file") == .write)
    #expect(ToolDef.risk("run_shell") == .dangerous)
    // M8 预留：MCP 外部工具默认 write 级
    #expect(ToolDef.risk("mcp__github__list_issues") == .write)
    // 未知内置名兜底只读（不会被装配，防御性）
    #expect(ToolDef.risk("no_such_tool") == .readOnly)
}

@Test func autonomyApprovalMatrix() {
    // 谨慎=write 即审；标准=dangerous 才审；放手=预算内全放行
    #expect(!MissionAutonomy.careful.requiresApproval(risk: .readOnly))
    #expect(MissionAutonomy.careful.requiresApproval(risk: .write))
    #expect(MissionAutonomy.careful.requiresApproval(risk: .dangerous))

    #expect(!MissionAutonomy.standard.requiresApproval(risk: .readOnly))
    #expect(!MissionAutonomy.standard.requiresApproval(risk: .write))
    #expect(MissionAutonomy.standard.requiresApproval(risk: .dangerous))

    #expect(!MissionAutonomy.free.requiresApproval(risk: .readOnly))
    #expect(!MissionAutonomy.free.requiresApproval(risk: .write))
    #expect(!MissionAutonomy.free.requiresApproval(risk: .dangerous))
}

@Test func migrationV5AutonomyDefaultsToStandard() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let db = try AppDatabase(path: dir.appendingPathComponent("t.sqlite").path)

    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: nil
    )
    let mission = try #require(try db.mission(id: ids.missionId))
    #expect(mission.autonomy == .standard)
}

@Test func setMissionAutonomyPersistsAndAppendsEvent() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let db = try AppDatabase(path: dir.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 5, workspacePath: nil
    )

    try db.setMissionAutonomy(missionId: ids.missionId, to: .free)
    #expect(try db.mission(id: ids.missionId)?.autonomy == .free)

    let events = try db.pool.read { database in
        try EventRecord.filter(Column("missionId") == ids.missionId)
            .order(Column.rowID).fetchAll(database)
    }
    // 事件 kind 是持久化契约：钉裸字符串（D2 纪律）
    let changed = events.filter { $0.kind == "autonomy_changed" }
    #expect(changed.count == 1)
    #expect(changed.first?.payloadJson.contains("free") == true)
}
