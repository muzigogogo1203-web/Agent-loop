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
    let c = CompanionRecord.new(name: "阿规", color: "purple", rolePrompt: "你是产品伙伴", model: "claude-sonnet-4-6") // Fix 7: let, no &
    try db.saveCompanion(c)
    let all = try db.regularCompanions()
    #expect(all.map(\.name) == ["阿规"])
}

@Test func companionsMissingIdThrows() throws {
    let db = try tempDB()
    #expect(throws: RecordNotFoundError.self) {
        try db.companions(ids: ["missing"])
    }
}

@Test func companionsDedupesDuplicateIds() throws {
    let db = try tempDB()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "model-a")
    let b = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "r", model: "model-b")
    try db.saveCompanion(a)
    try db.saveCompanion(b)

    let companions = try db.companions(ids: [a.id, b.id, a.id])
    #expect(companions.map(\.id) == [a.id, b.id])
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

// Fix 3: unknown ids throw instead of silent no-op
@Test func transitionUnknownCardThrows() throws {
    let db = try tempDB()
    #expect(throws: RecordNotFoundError.self) {
        try db.transitionCard(id: "nope", to: .running, eventKind: "x", payload: .object([:]))
    }
}

@Test func finishUnknownRunThrows() throws {
    let db = try tempDB()
    #expect(throws: RecordNotFoundError.self) {
        try db.finishRun(id: "nope", outcome: "completed", turns: 0, tokensIn: 0, tokensOut: 0)
    }
}

@Test func migrationV2AddsColumnsAndNormalizes() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let path = dir.appendingPathComponent("v1.sqlite").path
    let pool = try DatabasePool(path: path)
    let migrator = AppDatabase.migrator
    try migrator.migrate(pool, upTo: "v1")
    try pool.write { db in
        try CampRecord(id: "camp", name: "c", createdAt: Date()).insert(db)
        try SquadRecord(id: "squad", campId: "camp", name: "s", memberIdsJson: "[]",
                        workspacePath: nil, createdAt: Date()).insert(db)
        try db.execute(
            sql: """
                INSERT INTO mission
                    (id, squadId, goalRaw, goalRefined, status, budgetTokens, spentTokens, revision, createdAt)
                VALUES
                    (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: ["mission", "squad", "g", "g", "weird", 1, 0, 1, Date()]
        )
    }

    try migrator.migrate(pool)
    try migrator.migrate(pool)

    let columns = try pool.read { db in
        try db.columns(in: "card").map(\.name)
    }
    #expect(columns.contains("handoffJson"))
    #expect(columns.contains("stage"))
    let status = try pool.read { db in
        try String.fetchOne(db, sql: "SELECT status FROM mission WHERE id = ?", arguments: ["mission"])
    }
    #expect(status == "executing")
}

@Test func completeCardWritesHandoffProjection() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: KernelDefaults.maxTurns)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    let handoff = HandoffPayload(
        outcome: "完成",
        summary: "摘要",
        artifacts: [],
        noArtifactReason: "无文件",
        verification: [.init(method: "检查", passed: true, note: "通过")],
        risks: []
    )
    try db.completeCard(id: ids.cardId, runId: nil, handoff: handoff, durableArtifacts: [])

    let card = try #require(try db.card(id: ids.cardId))
    let projected = try #require(card.handoffJson)
    let decoded = try JSONDecoder().decode(HandoffPayload.self, from: Data(projected.utf8))
    #expect(decoded == handoff)
    #expect(card.stage == 1)
}
