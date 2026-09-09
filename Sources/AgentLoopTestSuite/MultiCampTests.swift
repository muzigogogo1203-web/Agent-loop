import Testing
import Foundation
import GRDB
import AgentLoopCore

private func multiCampDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func multiCampArtifactRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func planTurn(goal: String) -> TurnResult {
    TurnResult(
        content: [.toolUse(id: "p1", name: "propose_plan", input: [
            "goalRefined": .string(goal),
            "cards": .array([
                .object([
                    "title": "唯一卡",
                    "description": "d",
                    "expectedOutput": "o",
                    "assignee": 0,
                    "dependsOn": [],
                ]),
            ]),
        ])],
        stopReason: .toolUse
    )
}

// MARK: - 营地 CRUD（C2/C3）

@Test func createCampProvisionsGuideAndIsListable() throws {
    let db = try multiCampDB()
    let home = try db.ensureDefaultCamp()
    let north = try db.createCamp(name: "北岭前哨", guidePrompt: "你熟悉北岭的每条山路。")

    // 自动配向导（spec §10.2），人设可自定义
    let guide = try db.guide(campId: north.id)
    #expect(guide?.kind == .guide)
    #expect(guide?.rolePrompt == "你熟悉北岭的每条山路。")
    // 向导不进全局名册
    #expect(try db.regularCompanions().isEmpty)

    // 每营地独立向导线程
    let homeThread = try db.findOrCreateGuideThread(campId: home.id)
    let northThread = try db.findOrCreateGuideThread(campId: north.id)
    #expect(homeThread.id != northThread.id)

    // 列表按创建序（默认营地在前）
    let camps = try db.camps()
    #expect(camps.map(\.id) == [home.id, north.id])

    // 空名回退
    let unnamed = try db.createCamp(name: "  ")
    #expect(try db.camp(id: unnamed.id)?.name == "新营地")
}

@Test func renameCampSemantics() throws {
    let db = try multiCampDB()
    let camp = try db.createCamp(name: "旧名")
    try db.renameCamp(id: camp.id, name: "  新名  ")
    #expect(try db.camp(id: camp.id)?.name == "新名")
    // 空名 no-op
    try db.renameCamp(id: camp.id, name: "   ")
    #expect(try db.camp(id: camp.id)?.name == "新名")
    #expect(throws: RecordNotFoundError.self) {
        try db.renameCamp(id: "missing", name: "x")
    }
}

// MARK: - 归属链路（C4/C6）

@Test func missionCreationHonorsCampIdWithDefaultFallback() throws {
    let db = try multiCampDB()
    let home = try db.ensureDefaultCamp()
    let north = try db.createCamp(name: "北岭前哨")

    // 指定营地
    let inNorth = try db.createMissionShell(goal: "探北岭", companionIds: [], workspacePath: nil, campId: north.id)
    #expect(try db.squad(forMission: inNorth)?.campId == north.id)

    // 缺省 → 默认营地（兼容既有调用）
    let inHome = try db.createMissionShell(goal: "守家", companionIds: [], workspacePath: nil)
    #expect(try db.squad(forMission: inHome)?.campId == home.id)

    // 单卡路径同语义
    let single = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "t",
        cardDescription: "d", expectedOutput: "o", assigneeId: nil, maxTurns: 3, campId: north.id)
    #expect(try db.squad(forMission: single.missionId)?.campId == north.id)

    // 不存在的营地拒绝
    #expect(throws: RecordNotFoundError.self) {
        _ = try db.createMissionShell(goal: "g", companionIds: [], workspacePath: nil, campId: "missing")
    }

    // 按营地查询行动
    #expect(try db.missions(campId: north.id).map(\.id).sorted() == [inNorth, single.missionId].sorted())
    #expect(try db.missions(campId: home.id).map(\.id) == [inHome])
}

// MARK: - 知识隔离（C5：频道的核心承诺）

@Test func campNotesNeverLeakAcrossCamps() async throws {
    let db = try multiCampDB()
    let home = try db.ensureDefaultCamp()
    let north = try db.createCamp(name: "北岭前哨")
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: home.id)
    try db.saveCompanion(companion)

    // 只有「家」营地有笔记
    try db.saveCampNote(.new(campId: home.id, title: "家的秘密", bodyMd: "别告诉北岭"))

    let plannerHome = MockProvider(script: [planTurn(goal: "家务")])
    let plannerNorth = MockProvider(script: [planTurn(goal: "探路")])
    let cardProvider = MockProvider(script: [])
    let northIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "multi-camp-north-notes-isolation",
        model: "planner-north"
    )
    let homeIdentity = try testPlanningCommandIdentity(
        db: db,
        command: "multi-camp-home-notes-isolation",
        model: "planner-home"
    )
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "multi-camp-notes-state-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: stateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: stateRoot) }
    let artifactRoot = stateRoot.appendingPathComponent(
        "artifacts",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: artifactRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let orch = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver {
            profileId,
            model in
            guard profileId == northIdentity.runtimeProfileId else {
                throw TestPlanningProviderResolverError.unexpectedProfile(
                    expected: northIdentity.runtimeProfileId,
                    actual: profileId
                )
            }
            switch model {
            case northIdentity.plannerModel:
                return plannerNorth
            case homeIdentity.plannerModel:
                return plannerHome
            default:
                throw TestPlanningProviderResolverError.unexpectedModel(
                    expected: "\(northIdentity.plannerModel)|\(homeIdentity.plannerModel)",
                    actual: model
                )
            }
        },
        makeProvider: { model, _ in
            switch model {
            case "planner-home": plannerHome
            case "planner-north": plannerNorth
            default: cardProvider
            }
        },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil
    )

    await orch.recoverAndReconcile()
    // 北岭的规划不得携带家的笔记
    _ = try await orch.startMission(
        goal: "探路", companionIds: [companion.id], workspacePath: nil,
        plannerModel: northIdentity.plannerModel,
        runtimeProfileId: northIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: north.id,
        autonomy: .standard,
        idempotencyKey: northIdentity.idempotencyKey,
        traceId: northIdentity.traceId
    )
    // 家的规划应携带
    _ = try await orch.startMission(
        goal: "家务", companionIds: [companion.id], workspacePath: nil,
        plannerModel: homeIdentity.plannerModel,
        runtimeProfileId: homeIdentity.runtimeProfileId,
        budgetTokens: KernelDefaults.missionBudget,
        campId: home.id,
        autonomy: .standard,
        idempotencyKey: homeIdentity.idempotencyKey,
        traceId: homeIdentity.traceId
    )
    let planningDeadline =
        ContinuousClock.now.advanced(by: .seconds(5))
    var bothPlannersStarted = false
    while ContinuousClock.now < planningDeadline {
        let northStarted =
            !(await plannerNorth.recordedHistories).isEmpty
        let homeStarted =
            !(await plannerHome.recordedHistories).isEmpty
        if northStarted && homeStarted {
            bothPlannersStarted = true
            break
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(bothPlannersStarted)
    await orch.shutdown() // 取消后台执行（cardProvider 空脚本会慢重试，无需等）

    guard case .text(let northPrompt) = (await plannerNorth.recordedHistories.first)?.first?.content.first else {
        Issue.record("expected north planner prompt")
        return
    }
    #expect(!northPrompt.contains("家的秘密"))
    guard case .text(let homePrompt) = (await plannerHome.recordedHistories.first)?.first?.content.first else {
        Issue.record("expected home planner prompt")
        return
    }
    #expect(homePrompt.contains("家的秘密"))
}

@Test func searchAndStatusToolsAreCampScoped() async throws {
    let db = try multiCampDB()
    let home = try db.ensureDefaultCamp()
    let north = try db.createCamp(name: "北岭前哨")
    try db.saveCampNote(.new(campId: home.id, title: "家的秘密", bodyMd: "x"))
    _ = try db.createMissionShell(goal: "家务行动", companionIds: [], workspacePath: nil, campId: home.id)

    // 检索隔离
    let northSearch = await CampNotesSearchTool(db: db, campId: north.id).execute(input: ["query": "秘密"])
    guard case .result(let miss) = northSearch else { Issue.record("expected result"); return }
    #expect(miss.contains("没有找到"))

    // 全景隔离
    let northStatus = await CampStatusTool(db: db, campId: north.id).execute(input: .object([:]))
    guard case .result(let json) = northStatus else { Issue.record("expected result"); return }
    #expect(!json.contains("家务行动"))
    #expect(try JSONValue.decoded(from: json)["missions"]?.arrayValue?.isEmpty == true)
}

// MARK: - 提案建队归属向导所在营地

@MainActor
@Test func confirmedProposalLandsInGuidesCamp() async throws {
    let db = try multiCampDB()
    _ = try db.ensureDefaultCamp()
    let north = try db.createCamp(name: "北岭前哨")
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m")
    try db.saveCompanion(companion)

    let thread = try db.findOrCreateGuideThread(campId: north.id)
    let block = SquadProposalBlock(
        proposalId: "p-north", name: "北岭队", memberIds: [companion.id],
        goal: "探北岭", budget: nil, status: .pending)
    let messageId = try db.appendChatMessage(
        threadId: thread.id, role: "guide", contentJson: try block.encodedString())

    let provider = MockProvider(script: [])
    let runtime = try testPlanningRuntimeSelection(db: db, model: "m")
    let stateRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
        "multi-camp-proposal-state-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: stateRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: stateRoot) }
    let artifactRoot = stateRoot.appendingPathComponent(
        "artifacts",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: artifactRoot,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let orch = Orchestrator(
        db: db,
        planningProviderResolver: TestPlanningProviderResolver(provider: provider),
        makeProvider: { _, _ in provider },
        artifactStoreRoot: artifactRoot,
        tickInterval: nil
    )
    let coordinator = PlanningEntryCoordinator(
        db: db,
        orchestrator: orch,
        makeUUIDString: { "multi-camp-confirmed-proposal-trace" }
    )
    let captured = try coordinator.captureConfirmedProposal(
        messageId: messageId,
        runtime: runtime,
        fallbackBudget: KernelDefaults.missionBudget,
        autonomy: .standard
    )
    await orch.recoverAndReconcile()
    let missionId = try await coordinator.startConfirmedProposal(captured)
    // 归属北岭而非默认营地
    #expect(try db.squad(forMission: missionId)?.campId == north.id)
    await orch.shutdown()
}
