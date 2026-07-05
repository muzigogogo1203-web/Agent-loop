import Testing
import Foundation
import GRDB
import AgentLoopCore

private func tempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func makeCamp(_ db: AppDatabase) throws -> CampRecord {
    try db.ensureDefaultCamp()
}

// MARK: - 营地笔记 CRUD 与排序

@Test func campNoteCRUDAndOrdering() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)

    var early = CampNoteRecord.new(campId: camp.id, title: "早", bodyMd: "第一篇")
    early.createdAt = Date(timeIntervalSinceNow: -200)
    var late = CampNoteRecord.new(campId: camp.id, title: "晚", bodyMd: "第二篇")
    late.createdAt = Date(timeIntervalSinceNow: -100)
    var pinned = CampNoteRecord.new(campId: camp.id, title: "钉", bodyMd: "置顶的")
    pinned.createdAt = Date(timeIntervalSinceNow: -300)
    pinned.pinned = true
    try db.saveCampNote(early)
    try db.saveCampNote(late)
    try db.saveCampNote(pinned)

    // 列表：置顶优先，其余最近优先
    let listed = try db.campNotes(campId: camp.id)
    #expect(listed.map(\.title) == ["钉", "晚", "早"])

    // 编辑（update title/bodyMd/pinned/updatedAt）
    var edited = early
    edited.title = "早（改）"
    edited.bodyMd = "改过的正文"
    edited.updatedAt = Date()
    try db.saveCampNote(edited)
    #expect(try db.campNotes(campId: camp.id).first { $0.id == early.id }?.title == "早（改）")

    // 硬删
    try db.deleteCampNote(id: late.id)
    #expect(try db.campNotes(campId: camp.id).count == 2)
}

@Test func companionNoteCRUDIsolatedPerCompanion() throws {
    let db = try tempDB()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    let b = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "r", model: "m")
    try db.saveCompanion(a)
    try db.saveCompanion(b)

    try db.saveCompanionNote(.new(companionId: a.id, title: "甲的记忆", bodyMd: "只属于甲"))
    try db.saveCompanionNote(.new(companionId: b.id, title: "乙的记忆", bodyMd: "只属于乙"))

    // 严格按伙伴隔离（spec §10.1）
    #expect(try db.companionNotes(companionId: a.id).map(\.title) == ["甲的记忆"])
    #expect(try db.companionNotes(companionId: b.id).map(\.title) == ["乙的记忆"])

    let note = try db.companionNotes(companionId: a.id)[0]
    try db.deleteCompanionNote(id: note.id)
    #expect(try db.companionNotes(companionId: a.id).isEmpty)
}

// MARK: - 检索（D3）

@Test func searchCampNotesLikeSemantics() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)

    try db.saveCampNote(.new(campId: camp.id, title: "露营装备清单", bodyMd: "帐篷、睡袋"))
    try db.saveCampNote(.new(campId: camp.id, title: "别的", bodyMd: "正文里有装备两个字"))
    try db.saveCampNote(.new(campId: camp.id, title: "无关", bodyMd: "什么都没有"))

    // title 与 body 都参与匹配
    let hits = try db.searchCampNotes(campId: camp.id, query: "装备")
    #expect(hits.count == 2)

    // 空白查询返回空
    #expect(try db.searchCampNotes(campId: camp.id, query: "  ").isEmpty)

    // LIKE 通配符按字面匹配，不当通配符用
    #expect(try db.searchCampNotes(campId: camp.id, query: "100%").isEmpty)
    try db.saveCampNote(.new(campId: camp.id, title: "进度 100% 达成", bodyMd: "x"))
    #expect(try db.searchCampNotes(campId: camp.id, query: "100%").count == 1)
}

@Test func searchCampNotesPinnedFirstAndCapped() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)

    for i in 0..<7 {
        var note = CampNoteRecord.new(campId: camp.id, title: "打猎笔记 \(i)", bodyMd: "b")
        note.createdAt = Date(timeIntervalSinceNow: Double(i - 10))
        if i == 0 { note.pinned = true }
        try db.saveCampNote(note)
    }
    let hits = try db.searchCampNotes(campId: camp.id, query: "打猎")
    #expect(hits.count == 5) // top 5
    #expect(hits[0].title == "打猎笔记 0") // 置顶优先
    #expect(hits[1].createdAt > hits[2].createdAt) // 其余最近优先
}

// MARK: - 注入源（D2）

@Test func pinnedAndRecentSplitAndOrder() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)

    var pinnedOld = CampNoteRecord.new(campId: camp.id, title: "钉-老", bodyMd: "x")
    pinnedOld.pinned = true
    pinnedOld.createdAt = Date(timeIntervalSinceNow: -500)
    var pinnedNew = CampNoteRecord.new(campId: camp.id, title: "钉-新", bodyMd: "x")
    pinnedNew.pinned = true
    pinnedNew.createdAt = Date(timeIntervalSinceNow: -100)
    try db.saveCampNote(pinnedOld)
    try db.saveCampNote(pinnedNew)
    for i in 0..<5 {
        var note = CampNoteRecord.new(campId: camp.id, title: "普通\(i)", bodyMd: "x")
        note.createdAt = Date(timeIntervalSinceNow: Double(-400 + i * 10))
        try db.saveCampNote(note)
    }

    let (pinned, recent) = try db.pinnedAndRecentCampNotes(campId: camp.id, recent: 3)
    #expect(pinned.map(\.title) == ["钉-老", "钉-新"]) // 置顶全部，createdAt ASC
    #expect(recent.count == 3) // 最近 3
    #expect(recent.map(\.title) == ["普通4", "普通3", "普通2"]) // DESC
    #expect(!recent.contains { $0.pinned }) // 不与置顶重复
}

@Test func pinnedAndRecentCompanionNotes() throws {
    let db = try tempDB()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(a)
    var pinnedNote = CompanionNoteRecord.new(companionId: a.id, title: "钉", bodyMd: "x")
    pinnedNote.pinned = true
    try db.saveCompanionNote(pinnedNote)
    try db.saveCompanionNote(.new(companionId: a.id, title: "近", bodyMd: "x"))

    let (pinned, recent) = try db.pinnedAndRecentCompanionNotes(companionId: a.id, recent: 3)
    #expect(pinned.map(\.title) == ["钉"])
    #expect(recent.map(\.title) == ["近"])
}

// MARK: - 蒸馏水位

@Test func undistilledWatermarkAndMark() throws {
    let db = try tempDB()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(a)
    let thread = try db.findOrCreateDMThread(companionId: a.id)
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "一")
    try db.appendChatMessage(threadId: thread.id, role: "companion", text: "二")
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "三")

    let undistilled = try db.undistilledMessages(threadId: thread.id)
    #expect(undistilled.count == 3)
    #expect(undistilled.map(\.text) == ["一", "二", "三"]) // 时序稳定

    try db.markDistilled(messageIds: undistilled.prefix(2).map(\.id))
    let rest = try db.undistilledMessages(threadId: thread.id)
    #expect(rest.map(\.text) == ["三"])

    // 空数组是 no-op
    try db.markDistilled(messageIds: [])
}

// MARK: - 向导线程

@Test func guideThreadFindOrCreateIdempotent() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)
    let first = try db.findOrCreateGuideThread(campId: camp.id)
    let second = try db.findOrCreateGuideThread(campId: camp.id)
    #expect(first.id == second.id)
    #expect(first.kind == .guide)
    #expect(first.campId == camp.id)
    let guide = try db.guide(campId: camp.id)
    #expect(first.companionId == guide?.id)
}

// MARK: - 提案块（D5/D10）

private func insertProposal(_ db: AppDatabase, threadId: String,
                            status: SquadProposalBlock.Status = .pending) throws -> String {
    let block = SquadProposalBlock(
        proposalId: UUID().uuidString, name: "先遣小队", memberIds: ["c1", "c2"],
        goal: "探索北岭", budget: 100_000, status: status)
    return try db.appendChatMessage(threadId: threadId, role: "guide", contentJson: try block.encodedString())
}

@Test func proposalBlockRoundTripAndAccessor() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let messageId = try insertProposal(db, threadId: thread.id)

    let messages = try db.messages(threadId: thread.id)
    let message = messages.first { $0.id == messageId }
    let block = message?.proposal
    #expect(block?.name == "先遣小队")
    #expect(block?.memberIds == ["c1", "c2"])
    #expect(block?.budget == 100_000)
    #expect(block?.status == .pending)
    #expect(block?.historyPlaceholder.contains("先遣小队") == true)

    // 普通文本消息不解析为提案
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "你好")
    let textMessage = try db.messages(threadId: thread.id).last
    #expect(textMessage?.proposal == nil)
}

@Test func proposalConfirmIsIdempotentCAS() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let messageId = try insertProposal(db, threadId: thread.id)

    let confirmed = try db.confirmProposalBlock(messageId: messageId)
    #expect(confirmed.status == .confirmed)

    // 二次确认幂等拒绝
    #expect(throws: StaleProposalError.self) {
        _ = try db.confirmProposalBlock(messageId: messageId)
    }

    // 回写 missionId
    try db.attachMissionToProposal(messageId: messageId, missionId: "m-1")
    let stored = try db.messages(threadId: thread.id).first { $0.id == messageId }?.proposal
    #expect(stored?.status == .confirmed)
    #expect(stored?.missionId == "m-1")
}

@Test func proposalDismissAndRevert() throws {
    let db = try tempDB()
    let camp = try makeCamp(db)
    let thread = try db.findOrCreateGuideThread(campId: camp.id)

    // 驳回后不可再确认
    let dismissedId = try insertProposal(db, threadId: thread.id)
    try db.dismissProposalBlock(messageId: dismissedId)
    #expect(throws: StaleProposalError.self) {
        _ = try db.confirmProposalBlock(messageId: dismissedId)
    }

    // 补偿回滚：confirmed→pending 且清 missionId，可再确认
    let revertId = try insertProposal(db, threadId: thread.id)
    _ = try db.confirmProposalBlock(messageId: revertId)
    try db.attachMissionToProposal(messageId: revertId, missionId: "m-x")
    try db.revertProposalToPending(messageId: revertId)
    let reverted = try db.messages(threadId: thread.id).first { $0.id == revertId }?.proposal
    #expect(reverted?.status == .pending)
    #expect(reverted?.missionId == nil)
    _ = try db.confirmProposalBlock(messageId: revertId)
}

@Test func updateChatMessageContentRoundTrip() throws {
    let db = try tempDB()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(a)
    let thread = try db.findOrCreateDMThread(companionId: a.id)
    let id = try db.appendChatMessage(threadId: thread.id, role: "user", contentJson: #"{"text":"原文"}"#)
    try db.updateChatMessageContent(id: id, contentJson: #"{"text":"改后"}"#)
    #expect(try db.messages(threadId: thread.id).first { $0.id == id }?.text == "改后")
    #expect(throws: RecordNotFoundError.self) {
        try db.updateChatMessageContent(id: "missing", contentJson: "{}")
    }
}
