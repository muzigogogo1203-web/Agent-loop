import Foundation
import GRDB
import Testing
import AgentLoopCore

private func codingRanchDB() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AppDatabase(path: directory.appendingPathComponent("coding-ranch.sqlite").path)
}

private func codingRanchSource(_ relativePath: String) throws -> String {
    let sourcesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = sourcesDirectory.appendingPathComponent(relativePath)
    return String(decoding: try Data(contentsOf: url), as: UTF8.self)
}

private func convertCodingRanchCandidate(
    database: AppDatabase,
    draft: CodingRanchMissionDraft,
    companionId: String = CowTemplate.baseCowId
) throws -> CandidatePlanningStartResult {
    let profile = try seedTestPlanningProfile(
        database,
        profileId: "coding-ranch-planning-profile"
    )
    let model = "coding-ranch-planner"
    return try database.convertCandidateAndEnqueuePlanning(
        CandidatePlanningStartCommand(
            draft: draft,
            goal: draft.goal,
            companionId: companionId,
            workspacePath: nil,
            budgetTokens: KernelDefaults.missionBudget,
            autonomy: .standard,
            planningInput: try PlanningWorkInput(
                plannerModel: model,
                runtimeProfileId: profile.id
            ),
            idempotencyKey:
                "mission-start:candidate:\(draft.candidateId):v1",
            traceId: "coding-ranch-candidate:\(draft.candidateId):v1"
        ),
        planningProviderResolver: TestPlanningProviderResolver(
            profileId: profile.id,
            model: model,
            provider: MockProvider(script: [])
        )
    )
}

private enum CodingRanchSourceProbeError: Error {
    case missingMarker(owner: String, marker: String)
    case outOfOrder(owner: String, marker: String)
    case malformedConditional(String)
}

private func codingRanchSourceRange(
    _ source: String,
    from startMarker: String,
    to endMarker: String,
    owner: String
) throws -> String {
    guard let start = source.range(of: startMarker) else {
        throw CodingRanchSourceProbeError.missingMarker(
            owner: owner,
            marker: startMarker
        )
    }
    guard let end = source.range(
        of: endMarker,
        range: start.upperBound..<source.endIndex
    ) else {
        throw CodingRanchSourceProbeError.missingMarker(
            owner: owner,
            marker: endMarker
        )
    }
    return String(source[start.lowerBound..<end.lowerBound])
}

private func codingRanchOccurrenceCount(
    _ needle: String,
    in source: String
) -> Int {
    guard !needle.isEmpty else {
        return 0
    }
    var count = 0
    var cursor = source.startIndex
    while let range = source.range(
        of: needle,
        range: cursor..<source.endIndex
    ) {
        count += 1
        cursor = range.upperBound
    }
    return count
}

private func codingRanchRequireOrdered(
    _ markers: [String],
    in source: String,
    owner: String
) throws {
    var cursor = source.startIndex
    for marker in markers {
        guard let range = source.range(
            of: marker,
            range: cursor..<source.endIndex
        ) else {
            throw CodingRanchSourceProbeError.outOfOrder(
                owner: owner,
                marker: marker
            )
        }
        cursor = range.upperBound
    }
}

private struct CodingRanchDebugPartition {
    let guarded: String
    let release: String
}

private func codingRanchDebugPartition(
    _ source: String
) throws -> CodingRanchDebugPartition {
    enum ConditionalKind {
        case debug
        case other
    }

    let masked =
        PlanningTestFixtures.maskCommentsAndStrings(in: source)
    var stack: [ConditionalKind] = []
    var guarded = ""
    var release = ""
    var cursor = masked.startIndex

    while cursor < masked.endIndex {
        let newline = masked[cursor...].firstIndex(of: "\n")
        let end = newline.map { masked.index(after: $0) }
            ?? masked.endIndex
        let line = String(masked[cursor..<end])
        let directive = line.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let wasGuarded = stack.contains {
            if case .debug = $0 { return true }
            return false
        }

        if directive == "#if DEBUG" {
            stack.append(.debug)
        } else if directive.hasPrefix("#if ") {
            stack.append(.other)
        } else if directive == "#else"
                    || directive.hasPrefix("#elseif ")
        {
            guard let current = stack.last else {
                throw CodingRanchSourceProbeError
                    .malformedConditional(directive)
            }
            if case .debug = current {
                throw CodingRanchSourceProbeError
                    .malformedConditional(
                        "matching #if DEBUG must not contain \(directive)"
                    )
            }
        } else if directive == "#endif" {
            guard !stack.isEmpty else {
                throw CodingRanchSourceProbeError
                    .malformedConditional(directive)
            }
        }

        let isGuarded = wasGuarded || stack.contains {
            if case .debug = $0 { return true }
            return false
        }
        if isGuarded {
            guarded.append(line)
        } else {
            release.append(line)
        }

        if directive == "#endif" {
            stack.removeLast()
        }
        cursor = end
    }
    guard stack.isEmpty else {
        throw CodingRanchSourceProbeError
            .malformedConditional("unterminated conditional")
    }
    return CodingRanchDebugPartition(
        guarded: guarded,
        release: release
    )
}

private actor CodingRanchEventProvider: LLMProvider {
    private let events: [ProviderEvent]
    private(set) var callCount = 0
    private(set) var recordedTools: [[ToolDef]] = []
    private(set) var recordedMaxTokens: [Int] = []

    init(events: [ProviderEvent]) {
        self.events = events
    }

    nonisolated func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let events = await self.beginCall(
                    tools: tools,
                    maxTokens: maxTokens
                )
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    private func beginCall(
        tools: [ToolDef],
        maxTokens: Int
    ) -> [ProviderEvent] {
        callCount += 1
        recordedTools.append(tools)
        recordedMaxTokens.append(maxTokens)
        return events
    }
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

private func seedRuminationResult(
    database: AppDatabase,
    ingestionId: String,
    result: RuminationResult = sampleRumination()
) async throws {
    try await database.pool.write { db in
        guard var item = try IngestionItemRecord.fetchOne(
            db,
            key: ingestionId
        ) else {
            throw FeedServiceError.ingestionNotFound(ingestionId)
        }
        let now = Date()
        try RuminationResultRecord(
            id: UUID().uuidString,
            ingestionId: ingestionId,
            pipelineVersion:
                RuminationWorkInput.pipelineVersion,
            resultJson: try RuminationCoding.encode(result),
            userEditedJson: nil,
            materializedAt: nil,
            createdAt: now,
            updatedAt: now
        ).insert(db)
        item.status = .needsReview
        item.updatedAt = now
        try item.update(db)
    }
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
    let service = RuminationService(provider: provider)
    let first = try service.parseValidatedTurn(
        await service.produceValidatedTurn(ingestion: item)
    )
    let second = try service.parseValidatedTurn(
        await service.produceValidatedTurn(ingestion: item)
    )
    #expect(first.result == second.result)
    #expect(await provider.recordedTools.allSatisfy(\.isEmpty))
    #expect(await provider.callCount == 2)
    #expect(
        try FeedService(db: db).item(id: item.id)?.status
            == .queued
    )
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
    let service = RuminationService(provider: provider)
    #expect(await provider.callCount == 0)
    let turn = try await service.produceValidatedTurn(
        ingestion: item
    )
    _ = try service.parseValidatedTurn(turn)
    #expect(await provider.callCount == 1)
    #expect(
        try FeedService(db: db).item(id: item.id)?.status
            == .queued
    )
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
    let service = RuminationService(provider: provider)
    let invalid = try await service.produceValidatedTurn(
        ingestion: item
    )
    #expect(throws: RuminationParseError.self) {
        _ = try service.parseValidatedTurn(invalid)
    }
    #expect(try FeedService(db: db).item(id: item.id)?.rawText == "原文不会丢")
    #expect(try FeedService(db: db).item(id: item.id)?.status == .queued)
    let valid = try await service.produceValidatedTurn(
        ingestion: item
    )
    _ = try service.parseValidatedTurn(valid)
}

@Test func materializationAndMissionConversionAreIdempotent() async throws {
    let db = try codingRanchDB()
    let bootstrap = try ProductBootstrapService(db: db).ensureBootstrap()
    guard case .created(let item) = try FeedService(db: db).submit(campId: bootstrap.camp.id, rawText: "报名页资料") else {
        Issue.record("feed failed"); return
    }
    try await seedRuminationResult(
        database: db,
        ingestionId: item.id
    )
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
    let firstConversion = try convertCodingRanchCandidate(
        database: db,
        draft: draft
    )
    let replayedConversion = try convertCodingRanchCandidate(
        database: db,
        draft: draft
    )
    #expect(firstConversion.disposition == .inserted)
    #expect(replayedConversion.disposition == .replayed)
    #expect(firstConversion.missionId == replayedConversion.missionId)
    #expect(firstConversion.workId == replayedConversion.workId)

    let counts = try await db.pool.read { database in
        (
            try CampNoteRecord.filter(Column("id") == first.noteId).fetchCount(database),
            try MissionRecord.filter(Column("id") == firstConversion.missionId).fetchCount(database),
            try DurableWorkRecord.filter(Column("id") == firstConversion.workId).fetchCount(database),
            try EventRecord.filter(Column("kind") == "action_candidate_converted").fetchCount(database)
        )
    }
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
    #expect(counts.2 == 1)
    #expect(counts.3 == 1)
}

@Test func testCowRequiresAcceptedMissionWithRealArtifactAndUnlocksOnce() async throws {
    let db = try codingRanchDB()
    let bootstrap = try ProductBootstrapService(db: db).ensureBootstrap()
    guard case .created(let item) = try FeedService(db: db).submit(campId: bootstrap.camp.id, rawText: "报名页资料") else {
        Issue.record("feed failed"); return
    }
    try await seedRuminationResult(
        database: db,
        ingestionId: item.id
    )
    _ = try RuminationMaterializer(db: db).materialize(ingestionId: item.id, edited: sampleRumination())
    let candidate = try await db.pool.read { database in
        try #require(try ActionCandidateRecord.filter(Column("ingestionId") == item.id && Column("type") == "mission").fetchOne(database))
    }
    let factory = MissionDraftFactory(db: db)
    let missionId = try convertCodingRanchCandidate(
        database: db,
        draft: factory.draft(candidateId: candidate.id)
    ).missionId
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

@Suite(.serialized)
struct A2CodingRanchTests {
@Test func ruminationSanitizesPersistedAndVisibleDiagnostics() throws {
    let leakedSecret =
        "raw-body token=sk-test account=acct-private oauth=callback"
    #expect(throws: InvalidRuminationPayloadError.self) {
        _ = try RuminationAttemptFailure(
            code: "rumination_provider_http_error",
            safeMessage: leakedSecret,
            disposition: .deterministic,
            usage: nil
        )
    }

    let safeFailure = try RuminationAttemptFailure(
        code: "rumination_provider_http_error",
        safeMessage: "反刍服务请求失败。",
        disposition: .deterministic,
        usage: nil
    )
    #expect(
        safeFailure.failure.code
            == "rumination_provider_http_error"
    )
    #expect(safeFailure.failure.message == "反刍服务请求失败。")
    let encodedFailure = String(
        decoding: try JSONEncoder().encode(safeFailure.failure),
        as: UTF8.self
    )
    #expect(!encodedFailure.contains(leakedSecret))

    let supervisor = try codingRanchSource(
        "AgentLoopCore/Work/DurableWorkSupervisor.swift"
    )
    let providerClassifier = try codingRanchSourceRange(
        supervisor,
        from: "    private static func ruminationProviderFailure(",
        to: "    private static func executeRuminationProvider(",
        owner: "DurableWorkSupervisor.ruminationProviderFailure"
    )
    #expect(providerClassifier.contains("case let .http(status, _)"))
    #expect(providerClassifier.contains("case let .apiError(type, _)"))
    #expect(!providerClassifier.contains("String(describing: error)"))
    #expect(!providerClassifier.contains("error.localizedDescription"))

    let logOwner = try codingRanchSourceRange(
        supervisor,
        from: "    private func logErrorType(",
        to: "    private func logExpectedOwnershipLoss(",
        owner: "DurableWorkSupervisor.logErrorType"
    )
    #expect(logOwner.contains("type(of: error)"))
    #expect(!logOwner.contains("String(describing: error)"))
    #expect(!logOwner.contains("error.localizedDescription"))

    let store = try codingRanchSource(
        "AgentLoopCore/Database/DurableWorkStore.swift"
    )
    let persistenceOwner = try codingRanchSourceRange(
        store,
        from: """
            static func recordFailure(
                _ database: Database,
                claim: DurableWorkClaim,
                failure: RuminationAttemptFailure,
        """,
        to: "    static func cancelActive(",
        owner: "RuminationDurableWorkLedgerOwner.recordFailure"
    )
    #expect(
        codingRanchOccurrenceCount(
            "failure.failure.message",
            in: persistenceOwner
        ) >= 4
    )
    #expect(
        persistenceOwner.contains(
            "SET status=?,errorText=?,updatedAt=?,version=?"
        )
    )
    #expect(
        persistenceOwner.contains(
            "state == .failed ? failure.failure.message : nil"
        )
    )
    #expect(persistenceOwner.contains("context.ingestionVersion"))
    #expect(persistenceOwner.contains("database.changesCount == 1"))
    #expect(!persistenceOwner.contains("ProviderError"))
    #expect(!persistenceOwner.contains("localizedDescription"))

    let adapter = try codingRanchSource(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let visibleOwner = try codingRanchSourceRange(
        adapter,
        from: "    private func inboxItem(",
        to: "    private func cowViewState(",
        owner: "CodingRanchStoreAdapter.inboxItem"
    )
    #expect(
        visibleOwner.contains(
            "message: item.errorText ?? \"反刍失败\""
        )
    )
    #expect(!visibleOwner.contains("ProviderError"))
    #expect(!visibleOwner.contains("message: item.rawText"))
    #expect(!visibleOwner.contains("error: item.rawText"))

    let appStore = try codingRanchSource(
        "AgentLoopApp/AppStore.swift"
    )
    let views = try codingRanchSource(
        "AgentLoopApp/Views/CodingRanch/RuminationViews.swift"
    )
    let actionBoundary = try codingRanchSourceRange(
        adapter,
        from: "    func recordCodingRanchDiagnostic(",
        to: "    func loadDashboard(campId: String) async {",
        owner: "CodingRanchStoreAdapter.safeDiagnostics"
    )
    #expect(actionBoundary.contains("type(of: error)"))
    #expect(
        actionBoundary.contains(
            "error as? RuminationAttemptFailure"
        )
    )
    #expect(!actionBoundary.contains("localizedDescription"))
    #expect(!actionBoundary.contains("String(describing: error)"))
    #expect(!actionBoundary.contains("failureReporter.capture("))
    #expect(!adapter.contains("error.localizedDescription"))

    let startBoundary = try PlanningTestFixtures.uniqueFunction(
        in: appStore,
        signature: "func executeRuminationCommand("
    )
    try startBoundary.requireTokensInOrder([
        "operationTraceFactory.generated(",
        "operation: .inputRuminationStart",
        "inputWorkflowController.startRumination(",
        "case .notCommitted(let failure)",
        "globalVisibleFailure = failure",
        "throw UserVisibleOperationError(failure: failure)",
        "case .committed(let receipt)",
        "applyRuminationStartReceipt(receipt)",
        "case .committedWithVisibilityFailure(let receipt, let failure)",
    ])
    for forbidden in [
        "localizedDescription",
        "String(describing:",
        "failureReporter.capture(",
        "recordCodingRanchDiagnostic(",
        "db.",
        "orchestrator.",
    ] {
        try startBoundary.requireAbsent(forbidden)
    }
    #expect(!views.contains("error.localizedDescription"))
}

@Test func ruminationInvalidOutputIsDeterministicAndPreservesSource()
    async throws
{
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    let originalSource =
        "原始资料 source-marker-30：必须在无效模型输出后逐字保留。"
    guard case .created(let item) = try FeedService(db: db).submit(
        campId: camp.id,
        rawText: originalSource
    ) else {
        Issue.record("feed failed")
        return
    }
    let provider = MockProvider(script: [
        TurnResult(
            content: [.text("not-json and no repairable object")],
            stopReason: .endTurn,
            usage: .init(
                inputTokens: 11,
                outputTokens: 7,
                cacheReadTokens: 3
            )
        ),
    ])
    let service = RuminationService(provider: provider)
    let turn = try await service.produceValidatedTurn(
        ingestion: item
    )
    let expectedUsage = try RuminationUsageCountersV1(
        cacheReadTokens: 3,
        inputTokens: 11,
        outputTokens: 7
    )
    #expect(turn.usage == expectedUsage)
    #expect(throws: RuminationParseError.invalidJSON) {
        _ = try service.parseValidatedTurn(turn)
    }
    #expect(throws: RuminationParseError.invalidJSON) {
        _ = try service.parseValidatedTurn(turn)
    }
    #expect(await provider.callCount == 1)

    let persisted = try await db.pool.read { database in
        (
            try IngestionItemRecord.fetchOne(
                database,
                key: item.id
            ),
            try RuminationResultRecord
                .filter(Column("ingestionId") == item.id)
                .fetchCount(database)
        )
    }
    #expect(persisted.0?.rawText == originalSource)
    #expect(persisted.0?.status == .queued)
    #expect(persisted.1 == 0)
}

@Test func ruminationProviderUsesNoToolsAndProducesOneCanonicalResult()
    async throws
{
    let db = try codingRanchDB()
    let camp = try db.ensureDefaultCamp()
    guard case .created(let item) = try FeedService(db: db).submit(
        campId: camp.id,
        rawText: "验证单轮 canonical result"
    ) else {
        Issue.record("feed failed")
        return
    }
    let usage = Usage(
        inputTokens: 19,
        outputTokens: 13,
        cacheReadTokens: 5
    )
    let validTurn = TurnResult(
        content: [
            .text(try RuminationCoding.encode(sampleRumination())),
        ],
        stopReason: .endTurn,
        usage: usage
    )
    let provider = CodingRanchEventProvider(
        events: [.turn(validTurn)]
    )
    let service = RuminationService(provider: provider)
    let opaqueTurn = try await service.produceValidatedTurn(
        ingestion: item
    )
    #expect(await provider.callCount == 1)
    #expect(await provider.recordedTools == [[]])
    #expect(await provider.recordedMaxTokens == [3072])
    let production = try service.parseValidatedTurn(opaqueTurn)
    #expect(production.result == sampleRumination())
    #expect(
        production.usage
            == (try RuminationUsageCountersV1(usage: usage))
    )
    #expect(await provider.callCount == 1)

    let zeroTurnProvider = CodingRanchEventProvider(
        events: [.textDelta("ignored")]
    )
    let zeroTurnService = RuminationService(
        provider: zeroTurnProvider
    )
    await #expect(
        throws: ProviderError.malformedStream(
            "durable rumination requires exactly one turn"
        )
    ) {
        _ = try await zeroTurnService.produceValidatedTurn(
            ingestion: item
        )
    }
    #expect(await zeroTurnProvider.callCount == 1)
    #expect(await zeroTurnProvider.recordedTools.allSatisfy(\.isEmpty))
    #expect(await zeroTurnProvider.recordedMaxTokens == [3072])

    let multiTurnProvider = CodingRanchEventProvider(
        events: [.turn(validTurn), .turn(validTurn)]
    )
    let multiTurnService = RuminationService(
        provider: multiTurnProvider
    )
    await #expect(
        throws: ProviderError.malformedStream(
            "durable rumination requires exactly one turn"
        )
    ) {
        _ = try await multiTurnService.produceValidatedTurn(
            ingestion: item
        )
    }
    #expect(await multiTurnProvider.callCount == 1)
    #expect(
        await multiTurnProvider.recordedTools.allSatisfy(\.isEmpty)
    )
    #expect(await multiTurnProvider.recordedMaxTokens == [3072])

    let invalidUsageProvider = CodingRanchEventProvider(
        events: [
            .turn(
                TurnResult(
                    content: [
                        .text(
                            try RuminationCoding.encode(
                                sampleRumination()
                            )
                        ),
                    ],
                    stopReason: .endTurn,
                    usage: .init(inputTokens: -1)
                )
            ),
        ]
    )
    let invalidUsageService = RuminationService(
        provider: invalidUsageProvider
    )
    await #expect(throws: InvalidRuminationPayloadError.self) {
        _ = try await invalidUsageService.produceValidatedTurn(
            ingestion: item
        )
    }
    #expect(await invalidUsageProvider.callCount == 1)
    #expect(await invalidUsageProvider.recordedMaxTokens == [3072])

    let boundaryUsage = Usage(
        inputTokens: Int.max,
        outputTokens: Int.max,
        cacheReadTokens: Int.max
    )
    let boundaryProvider = CodingRanchEventProvider(
        events: [
            .turn(
                TurnResult(
                    content: [
                        .text(
                            try RuminationCoding.encode(
                                sampleRumination()
                            )
                        ),
                    ],
                    stopReason: .endTurn,
                    usage: boundaryUsage
                )
            ),
        ]
    )
    let boundaryService = RuminationService(
        provider: boundaryProvider
    )
    let boundaryTurn = try await boundaryService.produceValidatedTurn(
        ingestion: item
    )
    let boundaryProduction =
        try boundaryService.parseValidatedTurn(boundaryTurn)
    let exactIntBoundary = try #require(Int64(exactly: Int.max))
    #expect(
        boundaryProduction.usage
            == (try RuminationUsageCountersV1(
                cacheReadTokens: exactIntBoundary,
                inputTokens: exactIntBoundary,
                outputTokens: exactIntBoundary
            ))
    )
    #expect(boundaryProduction.result == sampleRumination())
    #expect(await boundaryProvider.callCount == 1)
    #expect(await boundaryProvider.recordedTools == [[]])
    #expect(await boundaryProvider.recordedMaxTokens == [3072])

    let serviceSource = try codingRanchSource(
        "AgentLoopCore/Rumination/RuminationService.swift"
    )
    #expect(
        codingRanchOccurrenceCount(
            "provider.streamTurn(",
            in: serviceSource
        ) == 1
    )
    let produceOwner = try PlanningTestFixtures.uniqueFunction(
        in: serviceSource,
        signature: "package func produceValidatedTurn("
    )
    try produceOwner.requireTokensInOrder(
        [
            "provider.streamTurn(",
            "tools: []",
            "maxTokens: Self.maxTokens",
            "guard turns.count == 1",
            "RuminationUsageCountersV1(usage: turn.usage)",
            "return RuminationValidatedTurn(",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "provider.streamTurn(",
            in: String(produceOwner.maskedBody)
        ) == 1
    )
    #expect(serviceSource.contains("private static let maxTokens = 3072"))
    #expect(!serviceSource.contains("maxTokens: Int ="))
    let parseOwner = try PlanningTestFixtures.uniqueFunction(
        in: serviceSource,
        signature: "package func parseValidatedTurn("
    )
    #expect(
        codingRanchOccurrenceCount(
            "RuminationParser.parse(",
            in: String(parseOwner.maskedBody)
        ) == 1
    )
    try parseOwner.requireAbsent("provider")
    try parseOwner.requireAbsent("streamTurn")
    try parseOwner.requireAbsent("await")
    #expect(serviceSource.contains("fileprivate let rawText: String"))
    #expect(
        codingRanchOccurrenceCount(
            "fileprivate init(",
            in: serviceSource
        ) == 1
    )

    let supervisorSource = try codingRanchSource(
        "AgentLoopCore/Work/DurableWorkSupervisor.swift"
    )
    let providerOwner = try PlanningTestFixtures.uniqueFunction(
        in: supervisorSource,
        signature: "private static func executeRuminationProvider("
    )
    try providerOwner.requireTokensInOrder(
        [
            "let service = RuminationService(provider: provider)",
            "bindRuminationServiceAndSetExtracting(",
            "service.produceValidatedTurn(",
            "supervisor.handleValidatedRuminationTurn(",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "produceValidatedTurn(",
            in: String(providerOwner.maskedBody)
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "produceValidatedTurn(",
            in: PlanningTestFixtures.maskCommentsAndStrings(
                in: supervisorSource
            )
        ) == 1
    )
    let validatedTurnOwner =
        try PlanningTestFixtures.uniqueFunction(
            in: supervisorSource,
            signature: "private func handleValidatedRuminationTurn("
        )
    try validatedTurnOwner.requireTokensInOrder(
        [
            "checkpoint: .second",
            "guard let service = current.ruminationService",
            "service.parseValidatedTurn(turn)",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "parseValidatedTurn(",
            in: String(validatedTurnOwner.maskedBody)
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "parseValidatedTurn(",
            in: PlanningTestFixtures.maskCommentsAndStrings(
                in: supervisorSource
            )
        ) == 1
    )
    #expect(
        !PlanningTestFixtures.maskCommentsAndStrings(
            in: supervisorSource
        ).contains("rawText")
    )
}

@Test func singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle()
    throws
{
    let orchestrator = try codingRanchSource(
        "AgentLoopCore/Kernel/Orchestrator.swift"
    )
    let supervisor = try codingRanchSource(
        "AgentLoopCore/Work/DurableWorkSupervisor.swift"
    )
    let adapter = try codingRanchSource(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let appStore = try codingRanchSource(
        "AgentLoopApp/AppStore.swift"
    )
    let service = try codingRanchSource(
        "AgentLoopCore/Rumination/RuminationService.swift"
    )

    #expect(
        codingRanchOccurrenceCount(
            "private lazy var planningSupervisor:",
            in: orchestrator
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "DurableWorkSupervisor.makeForOrchestrator(",
            in: orchestrator
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "DurableWorkSupervisor(",
            in: orchestrator
        ) == 0
    )
    #expect(!adapter.contains("DurableWorkSupervisor"))
    #expect(!appStore.contains("DurableWorkSupervisor"))
    #expect(!service.contains("DurableWorkSupervisor"))
    #expect(!service.contains("DurableWorkStore"))
    #expect(!service.contains("AppDatabase"))

    let owner = try codingRanchSourceRange(
        orchestrator,
        from:
            "    private lazy var planningSupervisor: DurableWorkSupervisor = {",
        to: "    public init(",
        owner: "Orchestrator.planningSupervisor"
    )
    #expect(owner.contains("ruminationEnabled: ruminationEnabled"))
    let phaseSink = try codingRanchSourceRange(
        owner,
        from:
            "            onRuminationPhase: { [unowned self] command in",
        to: "        )\n    }()",
        owner: "Orchestrator.onRuminationPhase"
    )
    #expect(
        phaseSink.contains(
            "await self.handleRuminationPhaseCommand(command)"
        )
    )
    #expect(!phaseSink.contains("Task {"))
    #expect(!phaseSink.contains("[weak self]"))

    let startOwner = try codingRanchSourceRange(
        orchestrator,
        from: "    package func startRumination(",
        to: "    package func cancelRumination(",
        owner: "Orchestrator.startRumination"
    )
    #expect(
        startOwner.contains(
            "planningSupervisor.startRumination("
        )
    )
    #expect(!startOwner.contains("DurableWorkStore"))
    #expect(!startOwner.contains("RuminationService"))
    let cancelOwner = try codingRanchSourceRange(
        orchestrator,
        from: "    package func cancelRumination(",
        to: "    public func startMission(",
        owner: "Orchestrator.cancelRumination"
    )
    #expect(
        cancelOwner.contains(
            "planningSupervisor.cancelRumination("
        )
    )
    #expect(!cancelOwner.contains("DurableWorkStore"))

    for lifecycleCall in [
        "planningSupervisor.recoverOnStartup(",
        "planningSupervisor.suppressForEmergencyStop()",
        "planningSupervisor.resumeAfterDurableRunning()",
        "planningSupervisor.waitUntilIdle()",
        "planningSupervisor.shutdown()",
    ] {
        #expect(orchestrator.contains(lifecycleCall))
    }

    let factoryOwner = try codingRanchSourceRange(
        supervisor,
        from: "    package static func makeForOrchestrator(",
        to: "    public func recoverOnStartup(",
        owner: "DurableWorkSupervisor.makeForOrchestrator"
    )
    try codingRanchRequireOrdered(
        [
            "if ruminationEnabled",
            "onRuminationPhase: onRuminationPhase",
            "return DurableWorkSupervisor(",
        ],
        in: factoryOwner,
        owner: "DurableWorkSupervisor.makeForOrchestrator"
    )
}

@Test func ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask()
    throws
{
    let adapter = try codingRanchSource(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let appStore = try codingRanchSource(
        "AgentLoopApp/AppStore.swift"
    )
    let inputController = try codingRanchSource(
        "AgentLoopApplication/InputWorkflowController.swift"
    )
    let ruminationViews = try codingRanchSource(
        "AgentLoopApp/Views/CodingRanch/RuminationViews.swift"
    )
    let liveHosts = try codingRanchSource(
        "AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift"
    )
    let startOwner = try codingRanchSourceRange(
        adapter,
        from:
            "    func startRumination(ingestionId: String) async {",
        to:
            "    func retryRumination(ingestionId: String) async {",
        owner: "CodingRanchStoreAdapter.startRumination"
    )
    try codingRanchRequireOrdered(
        [
            "ruminationActionInFlightIds.insert(ingestionId)",
            "defer { ruminationActionInFlightIds.remove(ingestionId) }",
            "executeRuminationCommand(",
        ],
        in: startOwner,
        owner: "CodingRanchStoreAdapter.startRumination"
    )
    #expect(!startOwner.contains("Task {"))
    #expect(!startOwner.contains("RuminationService"))
    #expect(!startOwner.contains("Provider"))
    #expect(!startOwner.contains("defaultModel"))
    #expect(!startOwner.contains("loadDashboard"))
    #expect(!startOwner.contains("reload("))

    let retryOwner = try codingRanchSourceRange(
        adapter,
        from:
            "    func retryRumination(ingestionId: String) async {",
        to:
            "    func cancelRumination(ingestionId: String) async throws {",
        owner: "CodingRanchStoreAdapter.retryRumination"
    )
    #expect(
        retryOwner.contains(
            "await startRumination(ingestionId: ingestionId)"
        )
    )
    #expect(!retryOwner.contains("Task {"))
    #expect(!retryOwner.contains("loadDashboard"))
    #expect(!retryOwner.contains("reload("))

    let cancelOwner = try codingRanchSourceRange(
        adapter,
        from:
            "    func cancelRumination(ingestionId: String) async throws {",
        to:
            "    func loadRuminationReview(ingestionId: String) async throws",
        owner: "CodingRanchStoreAdapter.cancelRumination"
    )
    #expect(
        cancelOwner.contains(
            "inputWorkflowController.cancelRumination("
        )
    )
    #expect(!cancelOwner.contains("Task {"))
    #expect(!cancelOwner.contains("loadDashboard"))
    #expect(!cancelOwner.contains("reload("))
    #expect(!cancelOwner.contains("try? await"))
    #expect(!cancelOwner.contains("orchestrator."))

    let commandOwner = try PlanningTestFixtures.uniqueFunction(
        in: appStore,
        signature: "func executeRuminationCommand("
    )
    try commandOwner.requireTokensInOrder(
        [
            "codingRanchIngestionCampIds[ingestionId]",
            "runtimeProjection.lastLoadedValue",
            "inputWorkflowController.startRumination(",
            "case .notCommitted(let failure)",
            "case .committed(let receipt)",
            "applyRuminationStartReceipt(receipt)",
            "case .committedWithVisibilityFailure(let receipt, let failure)",
        ]
    )
    for forbidden in [
        "Task {",
        "RuminationService",
        "provider(",
        "codingRanchPersistedSnapshot(",
        "prepareRuminationStart(",
        "orchestrator.",
        "db.",
    ] {
        try commandOwner.requireAbsent(forbidden)
    }

    let controllerStartOwner = try codingRanchSourceRange(
        inputController,
        from: "    package func startRumination(\n",
        to: "    package func cancelRumination(\n",
        owner: "InputWorkflowController.startRumination"
    )
    try codingRanchRequireOrdered(
        [
            "let started = await captureAsyncOperation(",
            "case .committed(let work)",
            "let read = reads.camp",
            "let bundle = try read(expectedCampId)",
            "InputRuminationStartReceipt(",
            "refreshedCamp:",
        ],
        in: controllerStartOwner,
        owner: "InputWorkflowController.startRumination"
    )
    #expect(
        controllerStartOwner.contains(
            ".committedWithVisibilityFailure("
        )
    )

    #expect(ruminationViews.contains("isStarting: Bool"))
    #expect(ruminationViews.contains("ProgressView()"))
    #expect(ruminationViews.contains("正在开始…"))
    #expect(
        liveHosts.contains(
            "startingIds: store.ruminationActionInFlightIds"
        )
    )

    let livePortsOwner = try PlanningTestFixtures.uniqueFunction(
        in: inputController,
        signature: "package static func live(\n        database: AppDatabase,"
    )
    try livePortsOwner.requireTokensInOrder(
        [
            "startRumination: { command in",
            "database.readInputCampBundle(",
            "database.prepareRuminationStart(",
            "switch preparation",
            "case .replay",
            "orchestrator.startRumination(",
            "case .new",
            "RuminationStartCommand(",
            "orchestrator.startRumination(",
            "cancelRumination: {",
            "orchestrator.cancelRumination(",
        ]
    )
}

@Test func ruminationUnknownRestartRendersRecoveringWithoutInventingReading()
    throws
{
    let adapter = try codingRanchSource(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let contracts = try codingRanchSource(
        "AgentLoopApp/CodingRanchContracts.swift"
    )
    let views = try codingRanchSource(
        "AgentLoopApp/Views/CodingRanch/RuminationViews.swift"
    )
    let appStore = try codingRanchSource(
        "AgentLoopApp/AppStore.swift"
    )

    let stageContract = try codingRanchSourceRange(
        contracts,
        from: "enum RuminationStage: Sendable, Equatable {",
        to: "enum RuminationStatusViewState:",
        owner: "RuminationStage"
    )
    #expect(
        stageContract.contains(
            """
                case saved
                case recovering
                case reading
                case extracting
                case organizing
            """
        )
    )

    let visibleStages = try codingRanchSourceRange(
        views,
        from:
            "    private var visibleStages: [RuminationStage] {",
        to: "    private func stagePosition(",
        owner: "RuminationProgressView.visibleStages"
    )
    #expect(
        visibleStages.contains(
            "? [.saved, .recovering]\n            : [.saved, .reading, .extracting, .organizing]"
        )
    )
    let displayCopy = try codingRanchSourceRange(
        views,
        from: "private extension RuminationStage {",
        to: "struct RuminationReviewView:",
        owner: "RuminationStage.displayText"
    )
    #expect(displayCopy.contains("case .recovering: \"正在恢复\""))

    let inboxOwner = try codingRanchSourceRange(
        adapter,
        from: "    private func inboxItem(",
        to: "    private func cowViewState(",
        owner: "CodingRanchStoreAdapter.inboxItem"
    )
    try codingRanchRequireOrdered(
        [
            "case .ruminating:",
            "if let live = ruminationPhases[item.id]",
            "activeWork.state == .running",
            "activeWork.id == live.identity.workId",
            "activeWork.attempt == live.identity.attempt",
            "status = .ruminating(stage: stage)",
            "status = .ruminating(stage: .recovering)",
        ],
        in: inboxOwner,
        owner: "CodingRanchStoreAdapter.inboxItem"
    )
    #expect(!adapter.contains("?? .reading"))

    let recoveryOwner = try PlanningTestFixtures.uniqueFunction(
        in: adapter,
        signature: "private func loadRuminationCampProjection("
    )
    try recoveryOwner.requireTokensInOrder(
        [
            "codingRanchIngestionCampIds[ingestionId]",
            "if requireFreshReview || targetCampId == nil",
            "refreshInputReviewProjection(",
            "guard case .loaded(let snapshot)",
            "snapshot.ingestion.campId",
            "codingRanchIngestionCampIds[ingestionId] =",
            "refreshInputCampProjection(",
            "guard case .loaded(let snapshot)",
        ]
    )
    for forbidden in [
        "?? .reading",
        "FeedService",
        "AppDatabase",
        "codingRanchPersistedSnapshot(",
        "orchestrator.",
        "db.",
    ] {
        try recoveryOwner.requireAbsent(forbidden)
    }

    let reviewProjection = try PlanningTestFixtures.uniqueFunction(
        in: appStore,
        signature: "func refreshInputReviewProjection("
    )
    try reviewProjection.requireTokensInOrder([
        "operation: .inputReviewLoad",
        "inputWorkflowController.loadReview(",
        "case .loaded",
        "case .failed(let failure)",
    ])
    let campProjection = try PlanningTestFixtures.uniqueFunction(
        in: appStore,
        signature: "func refreshInputCampProjection("
    )
    try campProjection.requireTokensInOrder([
        "operation: .inputCampLoad",
        "inputWorkflowController.loadCamp(",
        "case .loaded(let snapshot)",
        "case .failed(let failure)",
    ])

    let dashboardLoad = try codingRanchSourceRange(
        adapter,
        from: "    func loadDashboard(campId: String) async {",
        to: "    func loadRuminationInbox(campId: String) async {",
        owner: "CodingRanchStoreAdapter.loadDashboard"
    )
    #expect(
        dashboardLoad.contains(
            "refreshInputCampProjection("
        )
    )
    #expect(!dashboardLoad.contains("FeedService"))
    #expect(!dashboardLoad.contains("AppDatabase"))
    #expect(!dashboardLoad.contains("db."))
}

#if DEBUG
@Test func ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents()
    async throws
{
    let checkpoints =
        A2RuminationAuthorizationCheckpointForTesting.allCases
    let losses = A2RuminationAuthorizationLossForTesting.allCases
    #expect(checkpoints == [.first, .second])
    #expect(losses.count == 23)

    var executedCells = 0
    for checkpoint in checkpoints {
        for loss in losses {
            executedCells += 1
            let observation =
                try await a2RunRuminationAuthorizationMatrixCell(
                    checkpoint: checkpoint,
                    loss: loss
                )
            #expect(observation.checkpoint == checkpoint)
            #expect(observation.loss == loss)
            #expect(observation.providerCallCount == 1)
            #expect(observation.before == observation.after)
            #expect(observation.before.persistedWorkState == .running)
            #expect(
                observation.before.persistedWorkAttempt
                    == observation.identity.attempt
            )
            #expect(observation.before.persistedWorkVersion != nil)
            #expect(
                observation.before.persistedWorkErrorCode == nil
            )
            #expect(
                observation.before.persistedItemStatus == .ruminating
            )
            #expect(
                observation.before.persistedItemAttempt
                    == observation.identity.attempt
            )
            #expect(observation.before.resultCount == 0)
            #expect(observation.before.completedEventCount == 0)
            #expect(observation.before.failedEventCount == 0)

            var phases: [RuminationPhase] = []
            var invalidationReasons:
                [RuminationPhaseInvalidationReason] = []
            var startProjectionCommits:
                [RuminationProjectionCommitIdentity] = []
            var visiblePhase: RuminationPhase?
            for command in observation.commands {
                switch command {
                case let .set(identity, phase):
                    #expect(identity == observation.identity)
                    phases.append(phase)
                    visiblePhase = phase
                case let .invalidate(.phase(identity, reason)):
                    #expect(identity == observation.identity)
                    invalidationReasons.append(reason)
                    if identity == observation.identity {
                        visiblePhase = nil
                    }
                case let .invalidate(.projectionCommitted(commit)):
                    #expect(
                        commit.phaseIdentity.ingestionId
                            == observation.identity.ingestionId
                    )
                    #expect(
                        commit.phaseIdentity.workId
                            == observation.identity.workId
                    )
                    startProjectionCommits.append(commit)
                    if commit.phaseIdentity == observation.identity {
                        visiblePhase = nil
                    }
                }
            }
            let expectedPhases: [RuminationPhase] =
                checkpoint == .first
                    ? [.reading, .extracting]
                    : [.reading, .extracting, .organizing]
            #expect(phases == expectedPhases)
            let expectedReason:
                RuminationPhaseInvalidationReason
            switch loss {
            case .fatal,
                 .durableReadFailure,
                 .durableInvariantCorruption:
                expectedReason = .globalFatal
            default:
                expectedReason = .controlLoss
            }
            #expect(invalidationReasons == [expectedReason])
            #expect(visiblePhase == nil)
            #expect(startProjectionCommits.count == 1)
            #expect(
                startProjectionCommits.first?.phaseIdentity.attempt
                    == 0
            )
            #expect(
                startProjectionCommits.first?.workVersion == 1
            )
            #expect(observation.lateCommands.isEmpty)

            for command in observation.lateCommands {
                if case let .set(identity, _) = command {
                    #expect(identity != observation.identity)
                }
            }
        }
    }
    #expect(executedCells == 46)

    let supervisor = try codingRanchSource(
        "AgentLoopCore/Work/DurableWorkSupervisor.swift"
    )
    let durableStore = try codingRanchSource(
        "AgentLoopCore/Database/DurableWorkStore.swift"
    )
    let durableTypes = try codingRanchSource(
        "AgentLoopCore/Work/DurableWork.swift"
    )
    let orchestrator = try codingRanchSource(
        "AgentLoopCore/Kernel/Orchestrator.swift"
    )
    let appStore = try codingRanchSource(
        "AgentLoopApp/AppStore.swift"
    )
    let adapter = try codingRanchSource(
        "AgentLoopApp/CodingRanchStoreAdapter.swift"
    )
    let inputController = try codingRanchSource(
        "AgentLoopApplication/InputWorkflowController.swift"
    )
    let ingestionDeletionStore = try codingRanchSource(
        "AgentLoopCore/Database/IngestionDeletionStore.swift"
    )

    let actorGate = try PlanningTestFixtures.uniqueFunction(
        in: supervisor,
        signature: "private func validatedRuminationHandlerEntry("
    )
    try actorGate.requireTokensInOrder(
        [
            "guard lifecycle == .running",
            "guard !dispatchSuppressed",
            "guard fatalError == nil",
            "guard self.generation == generation",
            "guard let tokenEntry = owned.values.first(",
            "$0.token == token && $0.generation == generation",
            "guard tokenEntry.latestClaim.workId == workId",
            "let entry = owned[workId]",
            "entry.token == token",
            "guard entry.kind == .rumination",
            "recoverRuminationPhaseIdentity(",
            "guard entry.aggregateId == identity.ingestionId",
            "guard entry.latestClaim.attempt == attempt",
            "guard !entry.providerExited",
            "guard entry.pendingRuminationTerminalProposal == nil",
            "entry.terminalCommitPermitted",
            "let latestClaim = entry.latestClaim",
            "guard latestClaim.workId == workId",
            "latestClaim.workerId == workerId",
        ]
    )

    let validatorFacade =
        try PlanningTestFixtures.uniqueFunction(
            in: durableStore,
            signature:
                "package func validateRuminationPhaseOwnership("
        )
    try validatorFacade.requireTokensInOrder(
        [
            "RuminationDurableWorkLedgerOwner.validateNow(now)",
            "pool.read",
            "RuminationDurableWorkLedgerOwner",
            ".executionContext(",
            "claim: claim",
            "expectedIngestionId: ingestionId",
            "now: now",
        ]
    )
    try validatorFacade.requireAbsent("pool.write")

    let durableGate = try PlanningTestFixtures.uniqueFunction(
        in: durableStore,
        signature: "static func executionContext("
    )
    try durableGate.requireTokensInOrder(
        [
            "requireDispatchMode(database, runningRequired: true)",
            "let work = try requireWork(database, id: claim.workId)",
            "guard work.state == .running",
            "guard work.kind == .rumination",
            "guard work.aggregateType ==",
            "if let expectedIngestionId",
            "work.aggregateId != expectedIngestionId",
            "let lifecycleVersion = try requireActiveLifecycle(",
            "campId: work.campId",
            "workId: work.id",
            "IngestionItemRecord.fetchOne(",
            "key: work.aggregateId",
            "ingestion.campId == work.campId",
            "guard ingestion.status == .ruminating",
            "requireIngestionWriteFence(",
            "ingestionFence.terminalReason == nil",
            "ingestionFence.redactedAt == nil",
            "guard work.attempt == claim.attempt",
            "DurableWorkAttemptRecord.fetchOne(",
            "attempt.workerId == claim.workerId",
            "attempt.endedAt == nil",
            "attempt.outcome == nil",
            "attempt.terminalWorkVersion == nil",
            "guard work.version == claim.version",
            "guard work.leaseOwner == claim.workerId",
            "guard work.leaseExpiresAt == claim.leaseExpiresAt",
            "let leaseExpiresAt = work.leaseExpiresAt",
            "leaseExpiresAt > now",
        ]
    )

    let validatedTurnHandler =
        try PlanningTestFixtures.uniqueFunction(
            in: supervisor,
            signature: "private func handleValidatedRuminationTurn("
        )
    try validatedTurnHandler.requireTokensInOrder(
        [
            "validatedRuminationHandlerEntry(",
            "first = validated.entry",
            "identity = validated.identity",
            "database.validateRuminationPhaseOwnership(",
            "claim: first.latestClaim",
            "checkpoint: .first",
            "emitRuminationPhase(",
            "phase: .organizing",
            "validatedRuminationHandlerEntry(",
            "guard validated.identity == identity",
            "current = validated.entry",
            "database.validateRuminationPhaseOwnership(",
            "claim: current.latestClaim",
            "checkpoint: .second",
            "guard let service = current.ruminationService",
            "service.parseValidatedTurn(turn)",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "validatedRuminationHandlerEntry(",
            in: String(validatedTurnHandler.maskedBody)
        ) == 2
    )
    #expect(
        codingRanchOccurrenceCount(
            "database.validateRuminationPhaseOwnership(",
            in: String(validatedTurnHandler.maskedBody)
        ) == 2
    )
    #expect(
        codingRanchOccurrenceCount(
            "consumeA2RuminationAuthorizationScenarioForTesting(",
            in: String(validatedTurnHandler.maskedBody)
        ) == 2
    )

    let providerOwner = try PlanningTestFixtures.uniqueFunction(
        in: supervisor,
        signature: "private static func executeRuminationProvider("
    )
    try providerOwner.requireTokensInOrder(
        [
            "service.produceValidatedTurn(",
            "ruminationProviderFailure(error)",
            "supervisor.handleValidatedRuminationTurn(",
            "catch is RuminationPreParseAuthorizationLostError",
            "return",
            "catch let fatal as SupervisorFatalError",
            "catch",
            "ruminationProviderInvariantFailed(",
        ]
    )

    let authorizationFailureOwner =
        try PlanningTestFixtures.uniqueFunction(
            in: supervisor,
            signature:
                "private func handleRuminationAuthorizationFailure("
        )
    try authorizationFailureOwner.requireTokensInOrder(
        [
            "if fatalError != nil",
            "invalidateRuminationPhaseIfNeeded(",
            "reason: .globalFatal",
            "loseRuminationOwnershipAfterInvalidation(",
            "throw RuminationPreParseAuthorizationLostError()",
            "if isExpectedRuminationAuthorizationLoss(error)",
            "invalidateRuminationPhaseIfNeeded(",
            "reason: .controlLoss",
            "loseRuminationOwnershipAfterInvalidation(",
            "throw RuminationPreParseAuthorizationLostError()",
            "let code: SupervisorFatalCode",
            "let fatal = makeFatal(",
            "latchFatalAndInvalidateRumination(",
            "throw RuminationPreParseAuthorizationLostError()",
        ]
    )
    try authorizationFailureOwner.requireAbsent(
        "ruminationProviderFailure("
    )
    try authorizationFailureOwner.requireAbsent(
        "RuminationAttemptFailure("
    )

    let invalidator = try PlanningTestFixtures.uniqueFunction(
        in: supervisor,
        signature: "private func invalidateRuminationPhaseIfNeeded("
    )
    try invalidator.requireTokensInOrder(
        [
            "reserveRuminationPhaseInvalidation(",
            "publishReservedRuminationPhaseInvalidation(",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "private func invalidateRuminationPhaseIfNeeded(",
            in: PlanningTestFixtures.maskCommentsAndStrings(
                in: supervisor
            )
        ) == 1
    )

    let fatalOwner = try PlanningTestFixtures.uniqueFunction(
        in: supervisor,
        signature: "private func latchFatalAndInvalidateRumination("
    )
    try fatalOwner.requireTokensInOrder(
        [
            "if let existing = fatalError",
            "await waitForFatalInvalidation()",
            "fatalError = fatal",
            "fatalInvalidationInFlight = true",
            "dispatchSuppressed = true",
            "let identities = activeRuminationPhaseIdentities()",
            "generation.addingReportingOverflow(1)",
            "revokeAllOwnedEntriesWithoutCancel()",
            "reserveRuminationPhaseInvalidations(",
            "reason: .globalFatal",
            "await publishReservedRuminationPhaseInvalidations(",
            "cancelPumpAndNextDue()",
            "cancelAllOwnedTasksAfterInvalidation()",
            "fatalInvalidationInFlight = false",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "private func latchFatalAndInvalidateRumination(",
            in: PlanningTestFixtures.maskCommentsAndStrings(
                in: supervisor
            )
        ) == 1
    )

    let commandHandler = try PlanningTestFixtures.uniqueFunction(
        in: orchestrator,
        signature: "private func handleRuminationPhaseCommand("
    )
    try commandHandler.requireTokensInOrder(
        [
            "case let .set(identity, phase)",
            "ruminationPhaseTombstones",
            ".contains(identity)",
            "liveRuminationPhases[identity.ingestionId]",
            "current.identity == identity",
            "liveRuminationPhases[identity.ingestionId] =",
            "emit(",
            ".ruminationPhase(",
            "case let .invalidate(milestone)",
            "case let .phase(identity, _)",
            "current.identity == identity",
            "liveRuminationPhases.removeValue(",
            "ruminationPhaseTombstones.insert(identity)",
            ".phaseInvalidated(identity)",
            "case let .projectionCommitted(identity)",
            "ruminationProjectionReceipts",
            ".contains(identity)",
            "highestRuminationProjectionByWork[workId]",
            "current.identity == identity.phaseIdentity",
            "liveRuminationPhases.removeValue(",
            "ruminationPhaseTombstones.insert(",
            "invalidated = identity.phaseIdentity",
            "highestRuminationProjectionByWork[workId] =",
            "ruminationProjectionReceipts.insert(identity)",
            ".projectionCommitted(",
            "invalidatedPhaseIdentity:",
        ]
    )
    try commandHandler.requireAbsent("Task")
    try commandHandler.requireAbsent("await")
    try commandHandler.requireAbsent("CancellationError")

    let maskedDurableTypes =
        PlanningTestFixtures.maskCommentsAndStrings(in: durableTypes)
    #expect(
        codingRanchOccurrenceCount(
            "package enum RuminationPhaseCommand",
            in: maskedDurableTypes
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "case set(",
            in: maskedDurableTypes
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "case invalidate(",
            in: maskedDurableTypes
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "case projectionCommitted(",
            in: maskedDurableTypes
        ) == 1
    )

    let listener = try PlanningTestFixtures.uniqueFunction(
        in: appStore,
        signature: "private func startKernelEventListener("
    )
    try listener.requireTokensInOrder(
        [
            "kernelEventsTask = Task",
            "let stream = await orchestrator.events()",
            "for await event in stream",
            "await handleKernelEvent(event)",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "for await event in stream",
            in: String(listener.maskedBody)
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "await handleKernelEvent(event)",
            in: String(listener.maskedBody)
        ) == 1
    )

    let eventConsumer = try PlanningTestFixtures.uniqueFunction(
        in: appStore,
        signature: "private func handleKernelEvent("
    )
    try eventConsumer.requireTokensInOrder(
        [
            "case let .ruminationPhase(",
            "RuminationPhaseIdentity(",
            "await applyRuminationPhase(",
            "case let .ruminationChanged(change)",
            "await applyRuminationChange(change)",
        ]
    )

    let phaseProjection =
        try PlanningTestFixtures.uniqueFunction(
            in: adapter,
            signature: "func applyRuminationPhase("
        )
    try phaseProjection.requireTokensInOrder(
        [
            "ingestionId: identity.ingestionId",
            "requireFreshReview: false",
            "let campId = snapshot.camp.id",
            "let matchesPersistedOwner",
            "item.status == .ruminating",
            "work.state == .running",
            "work.id == identity.workId",
            "work.attempt == identity.attempt",
            "ruminationPhases[identity.ingestionId] =",
            "applyInputCampSnapshot(",
            "makeVisible: self.campId == campId",
        ]
    )
    try phaseProjection.requireAbsent("self.campId = campId")
    for forbidden in [
        "FeedService",
        "AppDatabase",
        "codingRanchPersistedSnapshot(",
        "orchestrator.",
        "db.",
    ] {
        try phaseProjection.requireAbsent(forbidden)
    }

    let changeProjection =
        try PlanningTestFixtures.uniqueFunction(
            in: adapter,
            signature: "func applyRuminationChange("
        )
    try changeProjection.requireTokensInOrder(
        [
            "switch change",
            "case let .phaseInvalidated(identity)",
            "== identity",
            "ruminationPhases.removeValue(",
            "case let .projectionCommitted(",
            "if let invalidatedPhaseIdentity",
            "== invalidatedPhaseIdentity",
            "ruminationPhases.removeValue(",
            "ingestionId: ingestionId",
            "requireFreshReview: true",
        ]
    )
    for forbidden in [
        "self.campId =",
        "Task",
        "FeedService",
        "AppDatabase",
        "codingRanchPersistedSnapshot(",
        "orchestrator.",
        "db.",
    ] {
        try changeProjection.requireAbsent(forbidden)
    }

    let projectionLoader = try PlanningTestFixtures.uniqueFunction(
        in: adapter,
        signature: "private func loadRuminationCampProjection("
    )
    try projectionLoader.requireTokensInOrder([
        "codingRanchIngestionCampIds[ingestionId]",
        "refreshInputReviewProjection(",
        "snapshot.ingestion.campId",
        "codingRanchIngestionCampIds[ingestionId] =",
        "refreshInputCampProjection(",
    ])
    for forbidden in [
        "FeedService",
        "AppDatabase",
        "codingRanchPersistedSnapshot(",
        "orchestrator.",
        "db.",
    ] {
        try projectionLoader.requireAbsent(forbidden)
    }

    let prepareDeletion = try PlanningTestFixtures.uniqueFunction(
        in: adapter,
        signature: "func prepareIngestionDeletion("
    )
    try prepareDeletion.requireTokensInOrder([
        "codingRanchIngestionCampIds[ingestionId]",
        ".prepareActiveIngestionDeletion(",
        "applyPendingIngestionDeletion(pending)",
    ])
    let executeDeletion = try PlanningTestFixtures.uniqueFunction(
        in: adapter,
        signature: "func executeIngestionDeletion() async -> Bool"
    )
    try executeDeletion.requireTokensInOrder([
        "executePendingActiveIngestionDeletion()",
        "applyPendingIngestionDeletion(",
        "completeCommittedIngestionDeletionRefresh()",
    ])
    let resolveDeletion = try PlanningTestFixtures.uniqueFunction(
        in: adapter,
        signature: "func resolveIngestionDeletion() async -> Bool"
    )
    try resolveDeletion.requireTokensInOrder([
        "resolvePendingActiveIngestionDeletion()",
        "applyPendingIngestionDeletion(pending)",
        "completeCommittedIngestionDeletionRefresh()",
    ])
    for forbidden in [
        "db.pool.write",
        "IngestionItemRecord.fetchOne(",
        "RuminationResultRecord.filter(",
    ] {
        try prepareDeletion.requireAbsent(forbidden)
        try executeDeletion.requireAbsent(forbidden)
        try resolveDeletion.requireAbsent(forbidden)
    }

    let livePorts = try PlanningTestFixtures.uniqueFunction(
        in: inputController,
        signature:
            "private static func configured(\n"
                + "        store: IngestionDeletionStore,\n"
                + "        beforeCommittedRefresh:\n"
                + "            @escaping @Sendable () async throws -> Void = {}"
    )
    try livePorts.requireTokensInOrder([
        "makeEnvelope:",
        "prepare:",
        "try store.prepareActiveIngestionDeletion(request: $0)",
        "execute:",
        "store.executeActiveIngestionDeletion(preparedCommand: $0)",
        "resolve:",
        "store.resolveActiveIngestionDeletionExecution(",
    ])
    try livePorts.requireAbsent("deleteIngestionAtomically")

    let executeFacade = try PlanningTestFixtures.uniqueFunction(
        in: ingestionDeletionStore,
        signature: "package func executeActiveIngestionDeletion("
    )
    try executeFacade.requireTokensInOrder(
        [
            "database.pool.write",
            "try execute(",
            "catch let failure as ActiveIngestionDeletionFailureV1",
            "resolveActiveIngestionDeletionExecution(",
        ]
    )
    #expect(
        codingRanchOccurrenceCount(
            "database.pool.write",
            in: String(executeFacade.maskedBody)
        ) == 1
    )
    let deleteTransaction = try PlanningTestFixtures.uniqueFunction(
        in: ingestionDeletionStore,
        signature: "func execute(\n        _ command: ActiveIngestionDeletionCommandV1,"
    )
    try deleteTransaction.requireTokensInOrder([
        "validateAllPersistedGraphs(in: transaction)",
        "snapshot = try readSnapshot(",
        "livePayload == command.payload",
        "registry.requireWriterCell(for: transaction)",
        "registry.beginGeneration(",
        "transaction.afterNextTransaction(",
        "registry.advanceEvidence(\n            .receipt",
        "registry.advanceEvidence(.scope",
        "registry.advanceEvidence(.event",
        "registry.advanceEvidence(.outbox",
        "invocation: .deleteResult",
        "switch command.payload.scope",
        "invocation: .deleteIngestion",
        "registry.finishGeneration(",
    ])
    let rawDeleteTransaction = String(deleteTransaction.body)
    for persistedMutation in [
        "INSERT INTO domain_command_receipt(",
        "INSERT INTO camp_event_scope(",
        "INSERT INTO domain_event(",
        "INSERT INTO event_outbox(",
        "DELETE FROM rumination_result",
        "DELETE FROM ingestion_item",
        "UPDATE ingestion_item",
    ] {
        #expect(rawDeleteTransaction.contains(persistedMutation))
    }

    let corePartition = try codingRanchDebugPartition(supervisor)
    let codingTestSource = try codingRanchSource(
        "AgentLoopTestSuite/CodingRanchTests.swift"
    )
    let durableTestSource = try codingRanchSource(
        "AgentLoopTestSuite/DurableWorkTests.swift"
    )
    let codingTestPartition =
        try codingRanchDebugPartition(codingTestSource)
    let durableTestPartition =
        try codingRanchDebugPartition(durableTestSource)
    let seamTokens = [
        "A2RuminationAuthorizationCheckpointForTesting",
        "A2RuminationAuthorizationLossForTesting",
        "A2RuminationAuthorizationScenarioForTesting",
        "a2RuminationAuthorizationScenarioForTesting",
        "armA2RuminationAuthorizationScenarioForTesting",
        "consumeA2RuminationAuthorizationScenarioForTesting",
    ]
    for token in seamTokens {
        #expect(corePartition.guarded.contains(token))
        #expect(!corePartition.release.contains(token))
        #expect(!codingTestPartition.release.contains(token))
        #expect(!durableTestPartition.release.contains(token))
    }
    #expect(
        codingRanchOccurrenceCount(
            "consumeA2RuminationAuthorizationScenarioForTesting(",
            in: corePartition.guarded
        ) == 3
    )
    #expect(
        codingRanchOccurrenceCount(
            "armA2RuminationAuthorizationScenarioForTesting(",
            in: corePartition.guarded
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "armA2RuminationAuthorizationScenarioForTesting(",
            in: durableTestPartition.guarded
        ) == 1
    )
    #expect(
        codingRanchOccurrenceCount(
            "armA2RuminationAuthorizationScenarioForTesting(",
            in: codingTestPartition.guarded
        ) == 0
    )

    let guardedScenarioSources = [
        corePartition.guarded,
        codingTestPartition.guarded,
        durableTestPartition.guarded,
    ].joined(separator: "\n")
    for forbidden in [
        "Mirror(",
        "unsafeBitCast(",
        "withUnsafe",
        "DurableWorkStore(",
        "database.execute(",
        ".pool.write",
        "handleValidatedRuminationTurn(",
        "validateRuminationPhaseOwnership(",
        "invalidateRuminationPhaseIfNeeded(",
        "latchFatalAndInvalidateRumination(",
        "deliverRuminationCommand(",
        "onRuminationPhase(",
        "RuminationParser.parse(",
        "parseValidatedTurn(",
        "produceValidatedTurn(",
        "Fake",
    ] {
        #expect(!guardedScenarioSources.contains(forbidden))
    }
}
#endif
}
