import Testing
import Foundation
import GRDB
import AgentLoopCore

private func tempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

@Test func migratesAndBootstraps() throws {
    let db = try tempDB()
    let camp = try db.ensureDefaultCamp()
    #expect(camp.name == "我的营地")
    let guide = try db.guide(campId: camp.id)
    #expect(guide?.kind == .guide)
    // 幂等：再次调用不重复创建
    _ = try db.ensureDefaultCamp()
    let camps = try db.pool.read { try CampRecord.fetchCount($0) }
    #expect(camps == 1)
}

@Test func companionCRUD() throws {
    let db = try tempDB()
    var c = CompanionRecord.new(name: "阿规", color: "purple", rolePrompt: "你是产品伙伴", model: "claude-sonnet-4-6")
    try db.saveCompanion(&c)
    let all = try db.regularCompanions()
    #expect(all.map(\.name) == ["阿规"])
}

@Test func eventAppendAndProjectionSameTransaction() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "我的营地", squadName: "试营小队",
        goal: "写清单", cardTitle: "写清单", cardDescription: "…",
        expectedOutput: "一份 md", assigneeId: nil, maxTurns: 30)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: ["by": "test"])
    let card = try db.card(id: ids.cardId)
    #expect(card?.status == .running)
    let events = try db.events(cardId: ids.cardId)
    #expect(events.contains { $0.kind == "card_started" })
}

@Test func illegalTransitionThrows() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e", assigneeId: nil, maxTurns: 30)
    // ready → done 非法（createSingleCardMission 建卡即 ready；done 必须先经 running，spec §5.1）
    #expect(throws: CardTransitionError.self) {
        try db.transitionCard(id: ids.cardId, to: .done, eventKind: "x", payload: .object([:]))
    }
}
