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

public enum MemoryDistillOwnerKind: String, Sendable, Equatable {
    case companion, guide
}

public enum MemoryDistillCaptureViolation: String, Sendable, Equatable {
    case empty, blankMessageID, duplicateMessageID
}

public enum MemoryDistillError: Error, Sendable, Equatable {
    case invalidMinimumMessages(Int)
    case invalidCapturedMessages(MemoryDistillCaptureViolation)
    case ownerNotFound(MemoryDistillOwnerKind)
    case threadInvariant(MemoryDistillOwnerKind)
    case read(grdbResultCode: Int32?)
    case provider(httpStatus: ValidatedHTTPStatus?)
    case invalidPayload
    case write(grdbResultCode: Int32?)
}

public struct MemoryDistillRaceLostError: Error, Sendable, Equatable {
    public init() {}
}

package struct ValidatedDistillationCapture: Sendable, Equatable {
    package let messageIds: [String]

    package init(validating messageIds: [String]) throws {
        if messageIds.isEmpty {
            throw MemoryDistillError.invalidCapturedMessages(.empty)
        }
        for messageId in messageIds {
            if messageId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MemoryDistillError.invalidCapturedMessages(.blankMessageID)
            }
        }
        var seen: Set<String> = []
        for messageId in messageIds {
            if !seen.insert(messageId).inserted {
                throw MemoryDistillError.invalidCapturedMessages(.duplicateMessageID)
            }
        }
        self.messageIds = messageIds
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

    package func deleteCampNoteWithPreimage(
        id: String
    ) throws -> CampNoteRecord {
        try pool.write { database in
            guard let record = try CampNoteRecord.fetchOne(
                database,
                key: id
            ) else {
                throw RecordNotFoundError(
                    table: CampNoteRecord.databaseTableName,
                    id: id
                )
            }
            guard try CampNoteRecord.deleteOne(database, key: id) else {
                throw RecordNotFoundError(
                    table: CampNoteRecord.databaseTableName,
                    id: id
                )
            }
            return record
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
        let requestedScope: LegacyCompanionNoteScopeV1 = note.sourceThreadId
            .map(LegacyCompanionNoteScopeV1.sourceThread)
            ?? .manualCow
        try pool.write { database in
            if let existing = try CompanionNoteRecord.fetchOne(
                database,
                key: note.id
            ) {
                guard existing.companionId == note.companionId,
                      existing.sourceThreadId == note.sourceThreadId,
                      existing.createdAt == note.createdAt,
                      let scope = try LegacyContentScopeStore.noteScope(
                          id: note.id,
                          in: database
                      ),
                      scope.cowId == note.companionId,
                      scope.sourceThreadId == note.sourceThreadId
                else {
                    throw LegacyContentScopeError.malformedScope(note.id)
                }
                switch requestedScope {
                case .sourceThread:
                    guard scope.evidenceKind == .dmThread
                            || scope.evidenceKind == .guideThread
                    else {
                        throw LegacyContentScopeError.malformedScope(note.id)
                    }
                case .manualCow:
                    guard scope.scopeKind == .globalCow,
                          scope.evidenceKind == .manualCow
                    else {
                        throw LegacyContentScopeError.malformedScope(note.id)
                    }
                case .cowork:
                    throw LegacyContentScopeError.malformedScope(note.id)
                }
                try note.update(database)
            } else {
                try LegacyContentScopeStore.recordCompanionNote(
                    note,
                    scope: requestedScope,
                    expectedCampLifecycleVersion: nil,
                    in: database
                )
            }
        }
    }

    public func deleteCompanionNote(id: String) throws {
        try pool.write { db in
            _ = try Self.deleteCompanionNote(
                id: id,
                companionId: nil,
                in: db
            )
        }
    }

    package func deleteCompanionNoteWithPreimage(
        id: String,
        companionId: String
    ) throws -> CompanionNoteRecord {
        try pool.write { database in
            try Self.deleteCompanionNote(
                id: id,
                companionId: companionId,
                in: database
            )
        }
    }

    private static func deleteCompanionNote(
        id: String,
        companionId: String?,
        in database: Database
    ) throws -> CompanionNoteRecord {
        guard let record = try CompanionNoteRecord.fetchOne(
            database,
            key: id
        ), companionId == nil || record.companionId == companionId,
              let scope = try LegacyContentScopeStore.noteScope(
                  id: id,
                  in: database
              ),
              scope.cowId == record.companionId,
              scope.sourceThreadId == record.sourceThreadId
        else {
            throw RecordNotFoundError(
                table: CompanionNoteRecord.databaseTableName,
                id: id
            )
        }
        try database.execute(
            sql: "DELETE FROM legacy_companion_note_scope WHERE noteId=?",
            arguments: [id]
        )
        guard database.changesCount == 1 else {
            throw RecordNotFoundError(
                table: CompanionNoteRecord.databaseTableName,
                id: id
            )
        }
        guard try CompanionNoteRecord.deleteOne(database, key: id) else {
            throw RecordNotFoundError(
                table: CompanionNoteRecord.databaseTableName,
                id: id
            )
        }
        return record
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
        try pool.read {
            try Self.pinnedAndRecentCompanionNotes(
                companionId: companionId,
                recent: recent,
                in: $0
            )
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
        try advanceDistillationWatermark(capturedMessageIds: messageIds)
    }

    package func advanceDistillationWatermark(
        capturedMessageIds: [String]
    ) throws {
        let capture = try ValidatedDistillationCapture(
            validating: capturedMessageIds
        )
        try pool.write { database in
            try Self.consumeCapturedDistillationMessages(
                capture,
                database: database
            )
        }
    }

    /// 原子持久化伙伴记忆：仅当所有捕获消息仍未蒸馏时，推进水位、写入记忆与审计事件。
    /// 成功只返回 true；非法捕获、竞争失败或任一写入失败都抛错并完整回滚。
    @discardableResult
    public func persistCompanionDistillation(
        note: CompanionNoteRecord,
        capturedMessageIds: [String]
    ) throws -> Bool {
        let capture = try ValidatedDistillationCapture(
            validating: capturedMessageIds
        )
        return try pool.write { database in
            try Self.consumeCapturedDistillationMessages(
                capture,
                database: database
            )
            guard let sourceThreadID = note.sourceThreadId else {
                throw MemoryDistillError.invalidPayload
            }
            try LegacyContentScopeStore.recordCompanionNote(
                note,
                scope: .sourceThread(sourceThreadID),
                expectedCampLifecycleVersion: nil,
                in: database
            )
            try Self.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.companionNoteCreated,
                payload: [
                    "noteId": .string(note.id),
                    "companionId": .string(note.companionId),
                ]
            )
            return true
        }
    }

    /// 原子持久化向导沉淀：仅当所有捕获消息仍未蒸馏时，推进水位、写入营地笔记与审计事件。
    /// 成功只返回 true；非法捕获、竞争失败或任一写入失败都抛错并完整回滚。
    @discardableResult
    public func persistGuideDistillation(
        note: CampNoteRecord,
        capturedMessageIds: [String]
    ) throws -> Bool {
        let capture = try ValidatedDistillationCapture(
            validating: capturedMessageIds
        )
        return try pool.write { database in
            try Self.consumeCapturedDistillationMessages(
                capture,
                database: database
            )
            try note.insert(database)
            try Self.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.campNoteCreated,
                payload: [
                    "noteId": .string(note.id),
                    "source": .string("guide_chat"),
                ]
            )
            return true
        }
    }

    // MARK: - 向导线程与消息

    /// 对齐 findOrCreateDMThread：每营地一条 guide 线程，companionId = 该营地向导。
    public func findOrCreateGuideThread(campId: String) throws -> ChatThreadRecord {
        try pool.write {
            try Self.findOrCreateGuideThread(campId: campId, in: $0)
        }
    }

    /// 类型化内容消息（提案块等）；返回消息 id。
    @discardableResult
    public func appendChatMessage(threadId: String, role: String, contentJson: String) throws -> String {
        try pool.write {
            try Self.appendChatMessage(
                threadId: threadId,
                role: role,
                contentJson: contentJson,
                in: $0
            )
        }
    }

    // MARK: - Typed chat aggregates

    package static func companion(
        id: String,
        in database: Database
    ) throws -> CompanionRecord? {
        try CompanionRecord.fetchOne(database, key: id)
    }

    package static func guide(
        campId: String,
        in database: Database
    ) throws -> CompanionRecord? {
        let matches = try CompanionRecord
            .filter(
                Column("campId") == campId
                    && Column("kind") == CompanionRecord.Kind.guide.rawValue
            )
            .order(Column("createdAt"), Column.rowID)
            .limit(2)
            .fetchAll(database)
        guard matches.count <= 1 else {
            throw ProjectionContractError.invalidPayload
        }
        return matches.first
    }

    package static func findOrCreateDMThread(
        companionId: String,
        in database: Database
    ) throws -> ChatThreadRecord {
        try LegacyContentScopeStore.findOrCreateDMThread(
            cowId: companionId,
            in: database
        )
    }

    package static func findOrCreateGuideThread(
        campId: String,
        in database: Database
    ) throws -> ChatThreadRecord {
        try LegacyContentScopeStore
            .findOrCreateGuideThreadResolvingLifecycle(
                campId: campId,
                in: database
            )
    }

    package static func chatMessages(
        threadId: String,
        in database: Database
    ) throws -> [ChatMessageRecord] {
        try ChatMessageRecord
            .filter(Column("threadId") == threadId)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
    }

    @discardableResult
    package static func appendChatMessage(
        threadId: String,
        role: String,
        contentJson: String,
        in database: Database
    ) throws -> String {
        try LegacyContentScopeStore.appendMessageResolvingScope(
            threadId: threadId,
            role: role,
            contentJson: contentJson,
            in: database
        )
    }

    package static func pinnedAndRecentCompanionNotes(
        companionId: String,
        recent: Int,
        in database: Database
    ) throws -> (
        pinned: [CompanionNoteRecord],
        recent: [CompanionNoteRecord]
    ) {
        let pinned = try CompanionNoteRecord
            .filter(
                Column("companionId") == companionId
                    && Column("pinned") == true
            )
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
        let recentNotes = try CompanionNoteRecord
            .filter(
                Column("companionId") == companionId
                    && Column("pinned") == false
            )
            .order(Column("createdAt").desc, Column.rowID.desc)
            .limit(recent)
            .fetchAll(database)
        return (pinned, recentNotes)
    }

    package func loadOrCreateDMHistoryBundle(
        companionId: String
    ) throws -> ChatHistoryReadBundle {
        try pool.write { database in
            guard try Self.companion(id: companionId, in: database) != nil
            else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: companionId
                )
            }
            let thread = try Self.findOrCreateDMThread(
                companionId: companionId,
                in: database
            )
            return ChatHistoryReadBundle(
                thread: thread,
                messages: try Self.projectChatMessages(
                    try Self.chatMessages(threadId: thread.id, in: database),
                    mode: .dm
                )
            )
        }
    }

    package func loadOrCreateGuideHistoryBundle(
        campId: String
    ) throws -> ChatHistoryReadBundle {
        try pool.write { database in
            guard try Self.guide(campId: campId, in: database) != nil else {
                throw RecordNotFoundError(
                    table: "companion(guide)",
                    id: campId
                )
            }
            let thread = try Self.findOrCreateGuideThread(
                campId: campId,
                in: database
            )
            return ChatHistoryReadBundle(
                thread: thread,
                messages: try Self.projectChatMessages(
                    try Self.chatMessages(threadId: thread.id, in: database),
                    mode: .guide
                )
            )
        }
    }

    package func prepareDMChatTurn(
        companionId: String,
        userText: String
    ) throws -> DMChatTurnPreparation {
        let contentJson = try Self.textContentJSON(userText)
        return try pool.write { database in
            guard let owner = try Self.companion(
                id: companionId,
                in: database
            ) else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: companionId
                )
            }
            let thread = try Self.findOrCreateDMThread(
                companionId: companionId,
                in: database
            )
            _ = try Self.appendChatMessage(
                threadId: thread.id,
                role: "user",
                contentJson: contentJson,
                in: database
            )
            let messages = try Self.projectChatMessages(
                try Self.chatMessages(threadId: thread.id, in: database),
                mode: .dm
            )
            let notes = try Self.pinnedAndRecentCompanionNotes(
                companionId: companionId,
                recent: 3,
                in: database
            )
            return DMChatTurnPreparation(
                companion: owner,
                thread: thread,
                history: messages.map {
                    APIMessage(
                        role: $0.role == "user" ? .user : .assistant,
                        content: [.text($0.text)]
                    )
                },
                pinnedNotes: notes.pinned,
                recentNotes: notes.recent
            )
        }
    }

    package func prepareGuideChatTurn(
        campId: String,
        userText: String
    ) throws -> GuideChatTurnPreparation {
        let contentJson = try Self.textContentJSON(userText)
        return try pool.write { database in
            guard let owner = try Self.guide(campId: campId, in: database)
            else {
                throw RecordNotFoundError(
                    table: "companion(guide)",
                    id: campId
                )
            }
            let thread = try Self.findOrCreateGuideThread(
                campId: campId,
                in: database
            )
            _ = try Self.appendChatMessage(
                threadId: thread.id,
                role: "user",
                contentJson: contentJson,
                in: database
            )
            let messages = try Self.projectChatMessages(
                try Self.chatMessages(threadId: thread.id, in: database),
                mode: .guide
            )
            return GuideChatTurnPreparation(
                guide: owner,
                thread: thread,
                history: messages.map { message in
                    if let proposal = message.proposal {
                        return .assistant([.text(proposal.historyPlaceholder)])
                    }
                    return APIMessage(
                        role: message.role == "user" ? .user : .assistant,
                        content: [.text(message.text)]
                    )
                }
            )
        }
    }

    /// 系统播报进营地管家线程：纯本地注入 role=guide 消息，不走 LLM。
    @discardableResult
    public func appendGuideBroadcast(campId: String, text: String) throws -> String {
        let thread = try findOrCreateGuideThread(campId: campId)
        return try appendChatMessage(
            threadId: thread.id,
            role: "guide",
            contentJson: try JSONValue.object(["text": .string(text)]).encodedString()
        )
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

    /// 消息所在线程（M5-0：提案确认时据此推导归属营地）。
    public func chatThread(forMessage messageId: String) throws -> ChatThreadRecord? {
        try pool.read { db in
            guard let message = try ChatMessageRecord.fetchOne(db, key: messageId) else { return nil }
            return try ChatThreadRecord.fetchOne(db, key: message.threadId)
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

    /// 崩溃自愈（M5-1）：confirmed 但没有 missionId 的提案 = CAS 确认后、建队前崩溃的遗留
    /// → 回滚 pending 可重新确认（D10 语义的启动侧收口）。返回被治愈的消息 id。
    public func healOrphanedConfirmedProposals() throws -> [String] {
        let candidates = try pool.read { db in
            try ChatMessageRecord.fetchAll(
                db,
                sql: """
                    SELECT * FROM chat_message
                    WHERE contentJson LIKE '%"type":"squad_proposal"%'
                      AND contentJson LIKE '%"status":"confirmed"%'
                    """
            )
        }
        var healed: [String] = []
        for message in candidates {
            guard let block = message.proposal,
                  block.status == .confirmed,
                  block.missionId == nil else { continue }
            try revertProposalToPending(messageId: message.id)
            healed.append(message.id)
        }
        return healed
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

    private enum TypedChatMode {
        case dm, guide
    }

    private static func textContentJSON(_ text: String) throws -> String {
        try JSONValue.object(["text": .string(text)]).encodedString()
    }

    private static func projectChatMessages(
        _ records: [ChatMessageRecord],
        mode: TypedChatMode
    ) throws -> [ChatMessageProjection] {
        try records.map { record in
            switch mode {
            case .dm:
                guard record.role == "user" || record.role == "companion"
                else {
                    throw ProjectionContractError.invalidPayload
                }
            case .guide:
                guard record.role == "user" || record.role == "guide" else {
                    throw ProjectionContractError.invalidPayload
                }
            }

            let decoded = try JSONDecoder().decode(
                JSONValue.self,
                from: Data(record.contentJson.utf8)
            )
            guard case .object(let object) = decoded else {
                throw ProjectionContractError.invalidPayload
            }
            if object["type"] != nil {
                guard mode == .guide,
                      record.role == "guide",
                      Self.validProposalKeys(Set(object.keys))
                else {
                    throw ProjectionContractError.invalidPayload
                }
                let proposal = try JSONDecoder().decode(
                    SquadProposalBlock.self,
                    from: Data(record.contentJson.utf8)
                )
                guard proposal.type == SquadProposalBlock.typeName else {
                    throw ProjectionContractError.invalidPayload
                }
                return ChatMessageProjection(
                    id: record.id,
                    role: record.role,
                    text: proposal.historyPlaceholder,
                    proposal: proposal,
                    createdAt: record.createdAt
                )
            }
            guard Set(object.keys) == ["text"],
                  case .string(let text) = object["text"]
            else {
                throw ProjectionContractError.invalidPayload
            }
            return ChatMessageProjection(
                id: record.id,
                role: record.role,
                text: text,
                proposal: nil,
                createdAt: record.createdAt
            )
        }
    }

    private static func validProposalKeys(_ keys: Set<String>) -> Bool {
        let required: Set<String> = [
            "type", "proposalId", "name", "memberIds", "goal", "status",
        ]
        let allowed = required.union(["budget", "missionId"])
        return required.isSubset(of: keys) && keys.isSubset(of: allowed)
    }

    package static func consumeCapturedDistillationMessages(
        _ capture: ValidatedDistillationCapture,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                UPDATE chat_message SET distilled = 1
                WHERE id IN (\(databaseQuestionMarks(count: capture.messageIds.count)))
                  AND distilled = 0
                """,
            arguments: StatementArguments(capture.messageIds)
        )
        if database.changesCount != capture.messageIds.count {
            throw MemoryDistillRaceLostError()
        }
    }

    /// LIKE 通配符转义（\ % _），配合 ESCAPE '\' 使用。
    static func escapedForLike(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
