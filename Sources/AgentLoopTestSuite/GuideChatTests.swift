import Testing
import Foundation
import GRDB
import AgentLoopCore

private func guideTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func textTurn(_ text: String) -> TurnResult {
    TurnResult(content: [.text(text)], stopReason: .endTurn)
}

private func toolTurn(_ name: String, _ input: JSONValue, id: String = UUID().uuidString) -> TurnResult {
    TurnResult(content: [.toolUse(id: id, name: name, input: input)], stopReason: .toolUse)
}

private struct GuideRun {
    var deltas = ""
    var toolActivities: [String] = []
    var proposalMessageIds: [String] = []
    var finished = false
}

private func runGuideChat(
    _ service: GuideChatService, campId: String, text: String
) async throws -> GuideRun {
    var run = GuideRun()
    for try await event in try service.send(campId: campId, userText: text) {
        switch event {
        case .textDelta(let t): run.deltas += t
        case .toolActivity(let name): run.toolActivities.append(name)
        case .proposalCreated(let messageId): run.proposalMessageIds.append(messageId)
        case .finished: run.finished = true
        }
    }
    return run
}

// MARK: - 工具循环

@Test func guideToolLoopExecutesCampStatusThenReplies() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let mock = MockProvider(script: [
        toolTurn("camp_status", .object([:])),
        textTurn("营地一切安好。"),
    ])
    let service = GuideChatService(db: db, provider: mock)
    let run = try await runGuideChat(service, campId: camp.id, text: "营地情况如何？")

    #expect(run.toolActivities == ["camp_status"])
    #expect(run.deltas.contains("营地一切安好"))
    #expect(run.finished)

    // 第二轮请求的历史里有 tool_result（JSON 全景）
    let secondHistory = await mock.recordedHistories[1]
    let hasToolResult = secondHistory.contains { message in
        message.content.contains { block in
            if case .toolResult(_, let content, let isError) = block {
                return !isError && content.contains("missions")
            }
            return false
        }
    }
    #expect(hasToolResult)

    // 最终文本回复落库（role guide）
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let messages = try db.messages(threadId: thread.id)
    #expect(messages.last?.role == "guide")
    #expect(messages.last?.text == "营地一切安好。")
}

@Test func guideSystemMentionsProposalDiscipline() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let mock = MockProvider(script: [textTurn("你好")])
    _ = try await runGuideChat(GuideChatService(db: db, provider: mock), campId: camp.id, text: "hi")
    let system = await mock.recordedSystems[0]
    #expect(system.contains("向导"))
    #expect(system.contains("用户确认"))
}

// MARK: - 提案（D5）

@Test func proposeSquadCreatesPendingBlockAndToolResult() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
    let b = CompanionRecord.new(name: "乙", color: "green", rolePrompt: "r", model: "m", campId: camp.id)
    try db.saveCompanion(a)
    try db.saveCompanion(b)

    let mock = MockProvider(script: [
        toolTurn("propose_squad", [
            "name": "先遣队",
            "memberIds": .array([.string(a.id), .string(b.id), .string(a.id)]), // 含重复，应去重
            "goal": "探索北岭",
            "budget": 50000,
        ]),
        textTurn("我拉好队了，等你点头。"),
    ])
    let service = GuideChatService(db: db, provider: mock)
    let run = try await runGuideChat(service, campId: camp.id, text: "帮我组个队去北岭")

    #expect(run.proposalMessageIds.count == 1)
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let block = try db.messages(threadId: thread.id)
        .first { $0.id == run.proposalMessageIds[0] }?.proposal
    #expect(block?.status == .pending)
    #expect(block?.name == "先遣队")
    #expect(block?.memberIds == [a.id, b.id]) // 去重
    #expect(block?.budget == 50000)
    #expect(block?.missionId == nil)

    // tool_result 告知等待确认
    let secondHistory = await mock.recordedHistories[1]
    let resultText = secondHistory.flatMap(\.content).compactMap { block -> String? in
        if case .toolResult(_, let content, false) = block { return content }
        return nil
    }.joined()
    #expect(resultText.contains("等待用户确认"))
}

@Test func proposeSquadValidationSelfHeals() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
    try db.saveCompanion(a)

    let mock = MockProvider(script: [
        toolTurn("propose_squad", [
            "name": "坏提案",
            "memberIds": .array([.string("不存在的id")]),
            "goal": "g",
        ]),
        textTurn("抱歉，我重新核对名册。"),
    ])
    let service = GuideChatService(db: db, provider: mock)
    let run = try await runGuideChat(service, campId: camp.id, text: "组队")

    // 校验失败：无提案块、tool_result isError=true、对话仍正常收尾
    #expect(run.proposalMessageIds.isEmpty)
    #expect(run.finished)
    let secondHistory = await mock.recordedHistories[1]
    let hasErrorResult = secondHistory.flatMap(\.content).contains { block in
        if case .toolResult(_, let content, true) = block { return content.contains("不存在") }
        return false
    }
    #expect(hasErrorResult)

    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    #expect(try db.messages(threadId: thread.id).allSatisfy { $0.proposal == nil })
}

@Test func guideRejectsGuideAsSquadMember() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let guide = try #require(try db.guide(campId: camp.id))

    let mock = MockProvider(script: [
        toolTurn("propose_squad", [
            "name": "队",
            "memberIds": .array([.string(guide.id)]),
            "goal": "g",
        ]),
        textTurn("好的。"),
    ])
    let run = try await runGuideChat(GuideChatService(db: db, provider: mock), campId: camp.id, text: "组队")
    #expect(run.proposalMessageIds.isEmpty)
}

// MARK: - 6 轮上限强制收尾（D4）

@Test func guideToolLoopCapsAtSixRoundsThenForcesText() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    // 7 个 tool_use + 最后文本：第 7 次调用应为强制文本轮（tools 为空）
    var script: [TurnResult] = []
    for _ in 0..<6 {
        script.append(toolTurn("camp_status", .object([:])))
    }
    script.append(textTurn("只能先说到这里。"))
    let mock = MockProvider(script: script)
    let run = try await runGuideChat(GuideChatService(db: db, provider: mock), campId: camp.id, text: "查状态")

    #expect(run.toolActivities.count == 6)
    #expect(run.deltas.contains("只能先说到这里"))
    #expect(await mock.callCount == 7)
}

// MARK: - 提案确认（Orchestrator 层，D10）

@Test func confirmSquadProposalStartsMissionWithBudgetAndIsIdempotent() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let a = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "r", model: "m", campId: camp.id)
    try db.saveCompanion(a)
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let block = SquadProposalBlock(
        proposalId: "prop-1", name: "先遣队", memberIds: [a.id],
        goal: "探索北岭", budget: 66_000, status: .pending)
    let messageId = try db.appendChatMessage(
        threadId: thread.id, role: "guide", contentJson: try block.encodedString())

    // 规划走回退（空脚本）也不影响建队
    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )
    // 不等 waitUntilIdle：空脚本 mock 的规划/派发重试链很慢，确认动作的断言全部同步可得，
    // 后台规划任务由 shutdown 取消。
    let missionId = try await orch.confirmSquadProposal(messageId: messageId, plannerModel: "m")

    let mission = try #require(try db.mission(id: missionId))
    #expect(mission.budgetTokens == 66_000) // budget 承接进 mission
    let squad = try #require(try db.squad(forMission: missionId))
    #expect(squad.campId == camp.id)
    #expect(squad.memberIdsJson.contains(a.id))

    let stored = try db.messages(threadId: thread.id).first { $0.id == messageId }?.proposal
    #expect(stored?.status == .confirmed)
    #expect(stored?.missionId == missionId)

    // 事件审计
    let events = try await db.pool.read { database in
        try EventRecord.filter(Column("kind") == "squad_proposal_confirmed").fetchAll(database)
    }
    #expect(events.count == 1)
    #expect(events.first?.payloadJson.contains("prop-1") == true)

    // 幂等：二次确认拒绝，不重复建队
    await #expect(throws: StaleProposalError.self) {
        _ = try await orch.confirmSquadProposal(messageId: messageId, plannerModel: "m")
    }
    let missionCount = try await db.pool.read { try MissionRecord.fetchCount($0) }
    #expect(missionCount == 1)
    await orch.shutdown()
}

// MARK: - 工具单测

@Test func campNotesSearchToolRendersHitsAndEmptyState() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    try db.saveCampNote(.new(campId: camp.id, title: "北岭地形", bodyMd: String(repeating: "岭", count: 300)))

    let tool = CampNotesSearchTool(db: db, campId: camp.id)
    let hit = await tool.execute(input: ["query": "北岭"])
    guard case .result(let rendered) = hit else { Issue.record("expected result"); return }
    #expect(rendered.contains("## 北岭地形"))
    // 正文只取前 200 字
    #expect(rendered.count < 260)

    let miss = await tool.execute(input: ["query": "不存在的词"])
    guard case .result(let empty) = miss else { return }
    #expect(empty.contains("没有找到"))

    let noQuery = await tool.execute(input: .object([:]))
    guard case .error = noQuery else { Issue.record("expected error"); return }

    let noCamp = await CampNotesSearchTool(db: db, campId: nil).execute(input: ["query": "x"])
    guard case .error = noCamp else { Issue.record("expected error"); return }
}

@Test func campStatusToolReportsMissionsAndDeliverables() async throws {
    let db = try guideTempDB()
    let camp = try db.ensureDefaultCamp()
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "修桥", cardTitle: "备料",
        cardDescription: "d", expectedOutput: "o", assigneeId: nil, maxTurns: 3)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: ids.cardId, runId: nil, handoff: HandoffPayload(
        outcome: "done", summary: "s", artifacts: [], noArtifactReason: "无", verification: [], risks: []
    ), durableArtifacts: [(decl: .init(relativePath: "桥料清单.md", kind: "file", label: "桥料清单"), durablePath: "/tmp/x")])

    let tool = CampStatusTool(db: db, campId: camp.id)
    let outcome = await tool.execute(input: .object([:]))
    guard case .result(let json) = outcome else { Issue.record("expected result"); return }
    let value = try JSONValue.decoded(from: json)
    #expect(value["missions"]?.arrayValue?.count == 1)
    #expect(value["missions"]?[0]?["title"]?.stringValue == "修桥")
    #expect(value["missions"]?[0]?["cardsDone"]?.intValue == 1)
    #expect(value["missions"]?[0]?["cardsTotal"]?.intValue == 1)
    #expect(value["recentDeliverables"]?[0]?["label"]?.stringValue == "桥料清单")

    // 确定性：连续两次输出逐字节一致
    let second = await tool.execute(input: .object([:]))
    guard case .result(let json2) = second else { return }
    #expect(json == json2)
}
