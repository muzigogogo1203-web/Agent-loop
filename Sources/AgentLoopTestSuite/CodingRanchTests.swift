import Foundation
import GRDB
import Testing
import AgentLoopCore

private func codingRanchDB() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AppDatabase(path: directory.appendingPathComponent("coding-ranch.sqlite").path)
}

private func sampleRumination() -> RuminationResult {
    .init(
        suggestedTitle: "报名页需求",
        summary: "需要制作一个可验证的单页报名表。",
        keyPoints: [.init(text: "需要姓名和联系方式", sourceQuote: "收集姓名、手机号")],
        requirements: [.init(title: "基础字段", detail: "包含姓名和手机号", confidence: .high)],
        todos: [.init(title: "生成 HTML")],
        suggestedMission: .init(
            goal: "制作一个单页报名表",
            acceptance: ["可以填写姓名", "手机号有必填提示"],
            why: "把资料转成可操作成果"
        ),
        uncertainties: []
    )
}

@Test func codingRanchMigrationAndBootstrapAreIdempotent() throws {
    let db = try codingRanchDB()
    #expect(AppDatabase.migrator.migrations.contains("v8-coding-ranch"))

    let first = try ProductBootstrapService(db: db).ensureBootstrap()
    let second = try ProductBootstrapService(db: db).ensureBootstrap()
    #expect(first.camp.id == second.camp.id)
    #expect(first.baseCow?.id == CowTemplate.baseCowId)
    #expect(second.baseCow?.id == CowTemplate.baseCowId)

    let counts = try db.pool.read { database in
        (
            try CompanionRecord.filter(Column("id") == CowTemplate.baseCowId).fetchCount(database),
            try EventRecord.filter(Column("kind") == "base_cow_provisioned").fetchCount(database),
            try database.tableExists("ingestion_item"),
            try database.tableExists("rumination_result"),
            try database.tableExists("knowledge_source_link"),
            try database.tableExists("action_candidate")
        )
    }
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
    #expect(counts.2 && counts.3 && counts.4 && counts.5)
}

@Test func codingRanchMigrationReplaysFromV7() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: directory.appendingPathComponent("v7.sqlite").path)
    let migrator = AppDatabase.migrator
    try migrator.migrate(pool, upTo: "v7")
    #expect(try pool.read { try !$0.tableExists("ingestion_item") })
    try migrator.migrate(pool)
    try migrator.migrate(pool)
    #expect(try pool.read { try $0.tableExists("ingestion_item") })
    #expect(try pool.read { try $0.tableExists("rumination_result") })
    #expect(try pool.read { try $0.tableExists("knowledge_source_link") })
    #expect(try pool.read { try $0.tableExists("action_candidate") })
}

@Test func codingRanchBootstrapPreservesExistingExpertRoster() throws {
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    let expert = CompanionRecord.new(
        name: "已有伙伴", color: "blue", rolePrompt: "专家", model: "test",
        kind: .regular, campId: camp.id
    )
    try db.saveCompanion(expert)

    let result = try ProductBootstrapService(db: db).ensureBootstrap()
    #expect(!result.newcomerMode)
    #expect(result.baseCow == nil)
    #expect(try db.companion(id: expert.id)?.name == "已有伙伴")
    #expect(try db.companion(id: CowTemplate.baseCowId) == nil)
}

@Test func feedDetectsDuplicatesButCanSaveAgain() throws {
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    let service = FeedService(db: db)
    let first = try service.submit(campId: camp.id, rawText: "  同一段资料\r\n", title: "第一次")
    guard case .created(let firstItem) = first else { Issue.record("expected created"); return }

    let duplicate = try service.submit(campId: camp.id, rawText: "同一段资料", title: "第二次")
    guard case .duplicate(let existing) = duplicate else { Issue.record("expected duplicate"); return }
    #expect(existing.id == firstItem.id)

    let forced = try service.submit(campId: camp.id, rawText: "同一段资料", title: "第二次", allowDuplicate: true)
    guard case .created(let secondItem) = forced else { Issue.record("expected forced create"); return }
    #expect(secondItem.id != firstItem.id)
    #expect(try service.items(campId: camp.id).count == 2)
}

@Test func ruminationUsesNoToolsAndRetryUpdatesOneResult() async throws {
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    let feed = FeedService(db: db)
    guard case .created(let item) = try feed.submit(campId: camp.id, rawText: "收集姓名、手机号，做一个报名页") else {
        Issue.record("feed failed"); return
    }
    let json = try RuminationCoding.encode(sampleRumination())
    let provider = MockProvider(script: [
        TurnResult(content: [.text(json)], stopReason: .endTurn),
        TurnResult(content: [.text("```json\n\(json)\n```")], stopReason: .endTurn),
    ])
    let service = RuminationService(db: db, provider: provider)
    let first = try await service.process(ingestionId: item.id)
    let second = try await service.process(ingestionId: item.id)
    #expect(first.id == second.id)
    #expect(await provider.recordedTools.allSatisfy(\.isEmpty))
    #expect(await provider.callCount == 2)
    let counts = try await db.pool.read { database in
        (
            try RuminationResultRecord.filter(Column("ingestionId") == item.id).fetchCount(database),
            try #require(try IngestionItemRecord.fetchOne(database, key: item.id)).attempt
        )
    }
    #expect(counts.0 == 1)
    #expect(counts.1 == 2)
}

@Test func ruminationCanExposeProgressBeforeBackgroundProcessing() async throws {
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    guard case .created(let item) = try FeedService(db: db).submit(campId: camp.id, rawText: "一段足够长的产品资料，用于验证后台反刍进度") else {
        Issue.record("feed failed"); return
    }
    let provider = MockProvider(script: [
        TurnResult(content: [.text(try RuminationCoding.encode(sampleRumination()))], stopReason: .endTurn),
    ])
    let service = RuminationService(db: db, provider: provider)
    _ = try service.start(ingestionId: item.id)
    #expect(try FeedService(db: db).item(id: item.id)?.status == .ruminating)
    #expect(await provider.callCount == 0)
    _ = try await service.processStarted(ingestionId: item.id)
    #expect(try FeedService(db: db).item(id: item.id)?.status == .needsReview)
    #expect(await provider.callCount == 1)
}

@Test func ruminationFailureKeepsSourceAndCanRetry() async throws {
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    guard case .created(let item) = try FeedService(db: db).submit(campId: camp.id, rawText: "原文不会丢") else {
        Issue.record("feed failed"); return
    }
    let provider = MockProvider(script: [
        TurnResult(content: [.text("not json")], stopReason: .endTurn),
        TurnResult(content: [.text(try RuminationCoding.encode(sampleRumination()))], stopReason: .endTurn),
    ])
    let service = RuminationService(db: db, provider: provider)
    await #expect(throws: RuminationParseError.self) { try await service.process(ingestionId: item.id) }
    #expect(try FeedService(db: db).item(id: item.id)?.rawText == "原文不会丢")
    #expect(try FeedService(db: db).item(id: item.id)?.status == .failed)
    _ = try await service.process(ingestionId: item.id)
    #expect(try FeedService(db: db).item(id: item.id)?.status == .needsReview)
}

@Test func materializationAndMissionConversionAreIdempotent() async throws {
    let db = try codingRanchDB()
    let bootstrap = try ProductBootstrapService(db: db).ensureBootstrap()
    guard case .created(let item) = try FeedService(db: db).submit(campId: bootstrap.camp.id, rawText: "报名页资料") else {
        Issue.record("feed failed"); return
    }
    let provider = MockProvider(script: [
        TurnResult(content: [.text(try RuminationCoding.encode(sampleRumination()))], stopReason: .endTurn),
    ])
    _ = try await RuminationService(db: db, provider: provider).process(ingestionId: item.id)
    let materializer = RuminationMaterializer(db: db)
    let first = try materializer.materialize(ingestionId: item.id, edited: sampleRumination())
    let second = try materializer.materialize(ingestionId: item.id, edited: sampleRumination())
    #expect(!first.alreadyMaterialized)
    #expect(second.alreadyMaterialized)
    #expect(first.noteId == second.noteId)

    let missionCandidate = try await db.pool.read { database in
        try #require(try ActionCandidateRecord
            .filter(Column("ingestionId") == item.id && Column("type") == ActionCandidateType.mission.rawValue)
            .fetchOne(database))
    }
    let factory = MissionDraftFactory(db: db)
    let draft = try factory.draft(candidateId: missionCandidate.id)
    let mission1 = try factory.convert(draft)
    let mission2 = try factory.convert(draft)
    #expect(mission1 == mission2)

    let counts = try await db.pool.read { database in
        (
            try CampNoteRecord.filter(Column("id") == first.noteId).fetchCount(database),
            try MissionRecord.filter(Column("id") == mission1).fetchCount(database),
            try EventRecord.filter(Column("kind") == "action_candidate_converted").fetchCount(database)
        )
    }
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
    #expect(counts.2 == 1)
}

@Test func testCowRequiresAcceptedMissionWithRealArtifactAndUnlocksOnce() async throws {
    let db = try codingRanchDB()
    let bootstrap = try ProductBootstrapService(db: db).ensureBootstrap()
    guard case .created(let item) = try FeedService(db: db).submit(campId: bootstrap.camp.id, rawText: "报名页资料") else {
        Issue.record("feed failed"); return
    }
    let provider = MockProvider(script: [
        TurnResult(content: [.text(try RuminationCoding.encode(sampleRumination()))], stopReason: .endTurn),
    ])
    _ = try await RuminationService(db: db, provider: provider).process(ingestionId: item.id)
    _ = try RuminationMaterializer(db: db).materialize(ingestionId: item.id, edited: sampleRumination())
    let candidate = try await db.pool.read { database in
        try #require(try ActionCandidateRecord.filter(Column("ingestionId") == item.id && Column("type") == "mission").fetchOne(database))
    }
    let factory = MissionDraftFactory(db: db)
    let missionId = try factory.convert(factory.draft(candidateId: candidate.id))
    let policy = NewcomerUnlockPolicy(db: db)
    #expect(!(try policy.progress(campId: bootstrap.camp.id).eligible))
    #expect(throws: NewcomerUnlockError.notEligible) { try policy.unlockTestCow(campId: bootstrap.camp.id) }

    try await db.pool.write { database in
        guard var mission = try MissionRecord.fetchOne(database, key: missionId) else { return }
        mission.status = .accepted
        try mission.update(database)
        let card = CardRecord(
            id: UUID().uuidString, missionId: missionId, idemKey: "test-artifact-card",
            title: "实现", descriptionText: "实现页面", expectedOutput: "HTML",
            assigneeId: CowTemplate.baseCowId, status: .done, blockedReasonJson: nil,
            dependsOnJson: "[]", handoffJson: nil, stage: 1,
            maxTurns: 1, tokenBudget: 100, createdAt: Date()
        )
        try card.insert(database)
        try ArtifactRecord(
            id: UUID().uuidString, cardId: card.id, path: "/tmp/index.html",
            kind: "file", label: "index.html", createdAt: Date()
        ).insert(database)
        try AppDatabase.appendEvent(
            database, missionId: missionId, cardId: nil, runId: nil,
            kind: EventKind.missionAccepted, payload: .object([:])
        )
    }

    #expect(try policy.progress(campId: bootstrap.camp.id).eligible)
    let first = try policy.unlockTestCow(campId: bootstrap.camp.id)
    let second = try policy.unlockTestCow(campId: bootstrap.camp.id)
    #expect(first.id == CowTemplate.testCowId)
    #expect(second.id == first.id)
    #expect(try await db.pool.read { try EventRecord.filter(Column("kind") == "cow_unlocked").fetchCount($0) } == 1)
}
