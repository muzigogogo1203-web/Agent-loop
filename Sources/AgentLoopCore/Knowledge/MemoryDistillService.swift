import Foundation
import os

/// 记忆沉淀协调（spec §10.1/§10.2，plan D7/D9）：读取未蒸馏增量 → Distiller → 落库 + 推水位 + 事件。
/// 失败静默（留水位下次再试）；skip（模型判定无内容）也推水位，避免琐碎增量反复送蒸。
public struct MemoryDistillService: Sendable {
    /// 切走触发的最小增量条数（D7：防琐碎单句成本）；手动触发用 1。
    public static let autoMinMessages = 4

    let db: AppDatabase
    let provider: any LLMProvider
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "memory")

    public init(db: AppDatabase, provider: any LLMProvider) {
        self.db = db
        self.provider = provider
    }

    /// DM 私聊沉淀 → 伙伴记忆。minMessages：手动=1，切走自动=autoMinMessages。
    /// 返回新记忆；nil = 无增量 / 不足阈值 / skip / 失败（静默留水位）。
    @discardableResult
    public func distillDM(companionId: String, minMessages: Int) async -> CompanionNoteRecord? {
        guard let companion = try? db.companion(id: companionId),
              let thread = try? db.findOrCreateDMThread(companionId: companionId),
              let undistilled = try? db.undistilledMessages(threadId: thread.id),
              undistilled.count >= max(1, minMessages) else {
            return nil
        }
        let distilledIds = undistilled.map(\.id) // 蒸馏期间新到的消息不推水位
        do {
            let note = try await Distiller(provider: provider).distillMemory(
                companionName: companion.name,
                rolePrompt: companion.rolePrompt,
                messages: undistilled.map { (role: $0.role, text: $0.text) }
            )
            try db.markDistilled(messageIds: distilledIds)
            guard let note else { return nil }
            let record = CompanionNoteRecord.new(
                companionId: companionId, sourceThreadId: thread.id,
                title: note.title, bodyMd: note.bodyMd)
            try db.saveCompanionNote(record)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: nil, cardId: nil, runId: nil,
                    kind: "companion_note_created",
                    payload: [
                        "noteId": .string(record.id),
                        "companionId": .string(companionId),
                    ]
                )
            }
            return record
        } catch {
            Self.logger.info("memory distillation failed, watermark kept: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// 向导对话手动沉淀 → 营地笔记（D9）。语义同 distillDM（skip 推水位、失败静默）。
    @discardableResult
    public func distillGuideChat(campId: String) async -> CampNoteRecord? {
        guard let thread = try? db.findOrCreateGuideThread(campId: campId),
              let undistilled = try? db.undistilledMessages(threadId: thread.id),
              !undistilled.isEmpty else {
            return nil
        }
        let distilledIds = undistilled.map(\.id)
        // 提案块以占位文本参与蒸馏（结构化状态对笔记无意义）
        let messages = undistilled.map { message -> (role: String, text: String) in
            if let proposal = message.proposal {
                return (role: message.role, text: proposal.historyPlaceholder)
            }
            return (role: message.role, text: message.text)
        }
        do {
            let note = try await Distiller(provider: provider).distillGuideChat(messages: messages)
            try db.markDistilled(messageIds: distilledIds)
            guard let note else { return nil }
            let record = CampNoteRecord.new(campId: campId, title: note.title, bodyMd: note.bodyMd)
            try db.saveCampNote(record)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: nil, cardId: nil, runId: nil,
                    kind: "camp_note_created",
                    payload: [
                        "noteId": .string(record.id),
                        "source": .string("guide_chat"),
                    ]
                )
            }
            return record
        } catch {
            Self.logger.info("guide chat distillation failed, watermark kept: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
