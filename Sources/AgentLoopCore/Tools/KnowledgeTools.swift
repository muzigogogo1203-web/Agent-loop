import Foundation
import GRDB

/// search_camp_notes 工具（spec §8/§9-3）：关键词 + 最近优先，返回「标题 + 前 200 字」。
/// 伙伴执行卡片与向导对话共用；只读、parallel-safe。
public struct CampNotesSearchTool: ToolHandler {
    static let bodyPreviewLimit = 200

    let db: AppDatabase
    let campId: String?

    public init(db: AppDatabase, campId: String?) {
        self.db = db
        self.campId = campId
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        guard let query = input["query"]?.stringValue,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .error("缺少 query 参数")
        }
        guard let campId else {
            return .error("当前没有营地上下文，无法检索营地笔记")
        }
        let hits: [CampNoteRecord]
        do {
            hits = try db.searchCampNotes(campId: campId, query: query)
        } catch {
            return .error("检索营地笔记失败：\(error.localizedDescription)")
        }
        guard !hits.isEmpty else {
            return .result("没有找到与「\(query)」相关的营地笔记。")
        }
        let rendered = hits.map { note in
            "## \(note.title)\n\(String(note.bodyMd.prefix(Self.bodyPreviewLimit)))"
        }.joined(separator: "\n---\n")
        return .result(rendered)
    }
}

/// camp_status 工具（spec §8/§10.2，plan D6）：只读全景，确定性 JSON 文本，不走 LLM。
public struct CampStatusTool: ToolHandler {
    let db: AppDatabase
    let campId: String

    public init(db: AppDatabase, campId: String) {
        self.db = db
        self.campId = campId
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        do {
            let report = try Self.report(db: db, campId: campId)
            return .result(try report.encodedString())
        } catch {
            return .error("查询营地状态失败：\(error.localizedDescription)")
        }
    }

    /// 各行动（标题/状态/卡片完成比）+ 最近 5 个交付物（label + 卡题）。sortedKeys 编码保证确定性。
    static func report(db: AppDatabase, campId: String) throws -> JSONValue {
        try db.pool.read { database in
            let missions = try MissionRecord.fetchAll(
                database,
                sql: """
                    SELECT mission.*
                    FROM mission
                    JOIN squad ON squad.id = mission.squadId
                    WHERE squad.campId = ?
                    ORDER BY mission.createdAt DESC, mission.rowid DESC
                    LIMIT 20
                    """,
                arguments: [campId]
            )
            let missionValues: [JSONValue] = try missions.map { mission in
                let cards = try CardRecord
                    .filter(Column("missionId") == mission.id)
                    .fetchAll(database)
                let done = cards.filter { $0.status == .done }.count
                let title = (mission.goalRefined.isEmpty ? mission.goalRaw : mission.goalRefined)
                    .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                return .object([
                    "title": .string(String(title.prefix(60))),
                    "status": .string(mission.status.rawValue),
                    "cardsDone": .number(Double(done)),
                    "cardsTotal": .number(Double(cards.count)),
                ])
            }
            let deliverables = try Row.fetchAll(
                database,
                sql: """
                    SELECT artifact.label AS label, card.title AS cardTitle
                    FROM artifact
                    JOIN card ON card.id = artifact.cardId
                    JOIN mission ON mission.id = card.missionId
                    JOIN squad ON squad.id = mission.squadId
                    WHERE squad.campId = ?
                    ORDER BY artifact.createdAt DESC, artifact.rowid DESC
                    LIMIT 5
                    """,
                arguments: [campId]
            ).map { row -> JSONValue in
                .object([
                    "label": .string(row["label"] ?? ""),
                    "cardTitle": .string(row["cardTitle"] ?? ""),
                ])
            }
            return .object([
                "missions": .array(missionValues),
                "recentDeliverables": .array(deliverables),
            ])
        }
    }
}
