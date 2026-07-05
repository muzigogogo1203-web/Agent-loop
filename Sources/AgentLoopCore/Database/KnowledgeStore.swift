import Foundation
import GRDB

/// M4 知识与对话层的持久化 API：营地笔记、伙伴记忆、蒸馏水位、向导线程与提案块。
/// 排序约定（spec §9/§10.1 + plan D2/D3）：列表 = 置顶优先 + 最近优先；注入 = 置顶(createdAt ASC) + 最近(DESC)。

public struct StaleProposalError: Error, Equatable, Sendable {
    public let messageId: String
    public init(messageId: String) {
        self.messageId = messageId
    }
}

extension AppDatabase {
    // MARK: - 营地笔记 CRUD

    public func campNotes(campId: String) throws -> [CampNoteRecord] {
        try pool.read { db in
            try CampNoteRecord
                .filter(Column("campId") == campId)
                .order(Column("pinned").desc, Column("createdAt").desc, Column.rowID.desc)
                .fetchAll(db)
        }
    }

    public func saveCampNote(_ note: CampNoteRecord) throws {
        try pool.write { db in try note.save(db) }
    }

    public func deleteCampNote(id: String) throws {
        try pool.write { db in
            _ = try CampNoteRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - 伙伴记忆 CRUD

    public func companionNotes(companionId: String) throws -> [CompanionNoteRecord] {
        try pool.read { db in
            try CompanionNoteRecord
                .filter(Column("companionId") == companionId)
                .order(Column("pinned").desc, Column("createdAt").desc, Column.rowID.desc)
                .fetchAll(db)
        }
    }

    public func saveCompanionNote(_ note: CompanionNoteRecord) throws {
        try pool.write { db in try note.save(db) }
    }

    public func deleteCompanionNote(id: String) throws {
        try pool.write { db in
            _ = try CompanionNoteRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - 检索与注入源（D2/D3）

    /// 关键词检索：title/bodyMd LIKE 匹配（大小写不敏感），置顶优先 + 最近优先，top `limit`。
    public func searchCampNotes(campId: String, query: String, limit: Int = 5) throws -> [CampNoteRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let pattern = "%" + Self.escapedForLike(trimmed) + "%"
        return try pool.read { db in
            try CampNoteRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM camp_note
                    WHERE campId = ?
                      AND (title LIKE ? ESCAPE '\\' OR bodyMd LIKE ? ESCAPE '\\')
                    ORDER BY pinned DESC, createdAt DESC, rowid DESC
                    LIMIT ?
                    """,
                arguments: [campId, pattern, pattern, limit]
            )
        }
    }

    /// 注入源：置顶全部（createdAt ASC，老经验在前）+ 非置顶最近 `recent` 条（createdAt DESC）。
    public func pinnedAndRecentCampNotes(
        campId: String, recent: Int = 3
    ) throws -> (pinned: [CampNoteRecord], recent: [CampNoteRecord]) {
        try pool.read { db in
            let pinned = try CampNoteRecord
                .filter(Column("campId") == campId && Column("pinned") == true)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
            let recentNotes = try CampNoteRecord
                .filter(Column("campId") == campId && Column("pinned") == false)
                .order(Column("createdAt").desc, Column.rowID.desc)
                .limit(recent)
                .fetchAll(db)
            return (pinned, recentNotes)
        }
    }

    public func pinnedAndRecentCompanionNotes(
        companionId: String, recent: Int = 3
    ) throws -> (pinned: [CompanionNoteRecord], recent: [CompanionNoteRecord]) {
        try pool.read { db in
            let pinned = try CompanionNoteRecord
                .filter(Column("companionId") == companionId && Column("pinned") == true)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
            let recentNotes = try CompanionNoteRecord
                .filter(Column("companionId") == companionId && Column("pinned") == false)
                .order(Column("createdAt").desc, Column.rowID.desc)
                .limit(recent)
                .fetchAll(db)
            return (pinned, recentNotes)
        }
    }

    // MARK: - 蒸馏水位（chat_message.distilled）

    public func undistilledMessages(threadId: String) throws -> [ChatMessageRecord] {
        try pool.read { db in
            try ChatMessageRecord
                .filter(Column("threadId") == threadId && Column("distilled") == false)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    public func markDistilled(messageIds: [String]) throws {
        guard !messageIds.isEmpty else { return }
        try pool.write { db in
            try db.execute(
                sql: """
                    UPDATE chat_message SET distilled = 1
                    WHERE id IN (\(databaseQuestionMarks(count: messageIds.count)))
                    """,
                arguments: StatementArguments(messageIds)
            )
        }
    }

    // MARK: - 向导线程与消息

    /// 对齐 findOrCreateDMThread：每营地一条 guide 线程，companionId = 该营地向导。
    public func findOrCreateGuideThread(campId: String) throws -> ChatThreadRecord {
        try pool.write { db in
            if let existing = try ChatThreadRecord
                .filter(Column("campId") == campId && Column("kind") == "guide")
                .fetchOne(db) {
                return existing
            }
            guard let guide = try CompanionRecord
                .filter(Column("campId") == campId && Column("kind") == "guide")
                .fetchOne(db) else {
                throw RecordNotFoundError(table: "companion(guide)", id: campId)
            }
            let thread = ChatThreadRecord(
                id: UUID().uuidString, kind: .guide, companionId: guide.id,
                campId: campId, createdAt: Date())
            try thread.insert(db)
            return thread
        }
    }

    /// 类型化内容消息（提案块等）；返回消息 id。
    @discardableResult
    public func appendChatMessage(threadId: String, role: String, contentJson: String) throws -> String {
        let id = UUID().uuidString
        try pool.write { db in
            try ChatMessageRecord(
                id: id, threadId: threadId, role: role,
                contentJson: contentJson, distilled: false, createdAt: Date()
            ).insert(db)
        }
        return id
    }

    public func updateChatMessageContent(id: String, contentJson: String) throws {
        try pool.write { db in
            guard var message = try ChatMessageRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "chat_message", id: id)
            }
            message.contentJson = contentJson
            try message.update(db)
        }
    }

    // MARK: - 提案块状态机（D5/D10：CAS 幂等，永不静默建队）

    /// 确认：事务内 pending→confirmed。已处理过（confirmed/dismissed）抛 StaleProposalError。
    public func confirmProposalBlock(messageId: String) throws -> SquadProposalBlock {
        try transitionProposal(messageId: messageId, to: .confirmed)
    }

    /// 驳回：事务内 pending→dismissed。
    @discardableResult
    public func dismissProposalBlock(messageId: String) throws -> SquadProposalBlock {
        try transitionProposal(messageId: messageId, to: .dismissed)
    }

    /// 建队成功后回写 missionId（confirmed 态）。
    public func attachMissionToProposal(messageId: String, missionId: String) throws {
        try pool.write { db in
            guard var message = try ChatMessageRecord.fetchOne(db, key: messageId),
                  var block = message.proposal else {
                throw RecordNotFoundError(table: "chat_message(proposal)", id: messageId)
            }
            block.missionId = missionId
            message.contentJson = try block.encodedString()
            try message.update(db)
        }
    }

    /// 补偿：startMission 失败时 confirmed→pending 回滚（清 missionId），提案可重新确认。
    public func revertProposalToPending(messageId: String) throws {
        try pool.write { db in
            guard var message = try ChatMessageRecord.fetchOne(db, key: messageId),
                  var block = message.proposal else {
                throw RecordNotFoundError(table: "chat_message(proposal)", id: messageId)
            }
            guard block.status == .confirmed else { return }
            block.status = .pending
            block.missionId = nil
            message.contentJson = try block.encodedString()
            try message.update(db)
        }
    }

    private func transitionProposal(
        messageId: String, to next: SquadProposalBlock.Status
    ) throws -> SquadProposalBlock {
        try pool.write { db in
            guard var message = try ChatMessageRecord.fetchOne(db, key: messageId),
                  var block = message.proposal else {
                throw RecordNotFoundError(table: "chat_message(proposal)", id: messageId)
            }
            guard block.status == .pending else {
                throw StaleProposalError(messageId: messageId)
            }
            block.status = next
            message.contentJson = try block.encodedString()
            try message.update(db)
            return block
        }
    }

    // MARK: - Helpers

    /// LIKE 通配符转义（\ % _），配合 ESCAPE '\' 使用。
    static func escapedForLike(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
