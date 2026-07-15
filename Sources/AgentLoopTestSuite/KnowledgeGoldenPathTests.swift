import Testing
import Foundation
import GRDB
import AgentLoopCore

private func knowledgeTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func knowledgeArtifactRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func completeTurn(summary: String) -> TurnResult {
    TurnResult(
        content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
            "outcome": .string(summary),
            "summary": .string(summary),
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])],
        stopReason: .toolUse
    )
}

private func planTurn(cardTitle: String) -> TurnResult {
    TurnResult(
        content: [.toolUse(id: "p1", name: "propose_plan", input: [
            "goalRefined": "再探北岭",
            "cards": .array([
                .object([
                    "title": .string(cardTitle),
                    "description": "按往期经验执行",
                    "expectedOutput": "一份结论",
                    "assignee": 0,
                    "dependsOn": [],
                ]),
            ]),
        ])],
        stopReason: .toolUse
    )
}

private func firstUserText(_ histories: [[APIMessage]]) -> String {
    guard case .text(let text) = histories.first?.first?.content.first else { return "" }
    return text
}

/// 验收 ③ 离线版（spec §15-6）：行动 A 收营 → 蒸馏笔记 → 行动 B 的规划消息与卡片上下文均含 A 笔记。
@Test func crossMissionExperienceReuseGoldenPath() async throws {
    let db = try knowledgeTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "执行", model: "model-a", campId: camp.id)
    try db.saveCompanion(companion)

    let distillJSON = ###"{"title":"北岭探索复盘","body":"## 做了什么\n画了地图\n## 什么做法有效\n先看等高线\n## 关键产物在哪\n工作目录\n## 踩了什么坑\n雨天路滑"}"###
    let distillProvider = MockProvider(script: [
        TurnResult(content: [.text(distillJSON)], stopReason: .endTurn),
    ])
    let plannerProvider = MockProvider(script: [planTurn(cardTitle: "再画一张图")])
    let cardProvider = MockProvider(script: [completeTurn(summary: "完成")])

    let orch = Orchestrator(
        db: db,
        makeProvider: { model, _ in
            switch model {
            case "distill-model": distillProvider
            case "planner-model": plannerProvider
            default: cardProvider
            }
        },
        artifactStoreRoot: try knowledgeArtifactRoot(),
        tickInterval: nil
    )

    // 行动 A：直接构造到 delivering，收营触发蒸馏
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "探索北岭", cardTitle: "画地图",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 3)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    try db.completeCard(id: ids.cardId, runId: nil, handoff: HandoffPayload(
        outcome: "完成", summary: "地图画好了", artifacts: [], noArtifactReason: "无", verification: [], risks: []
    ), durableArtifacts: [])
    try await orch.closeout(ids.missionId, distillModel: "distill-model")
    await orch.waitUntilIdle()
    #expect(try db.campNotes(campId: camp.id).first?.title == "北岭探索复盘")

    // 行动 B：规划 + 执行都应带上 A 的笔记
    _ = try await orch.startMission(
        goal: "再探北岭", companionIds: [companion.id], workspacePath: nil, plannerModel: "planner-model")
    await orch.waitUntilIdle()

    let plannerPrompt = firstUserText(await plannerProvider.recordedHistories)
    #expect(plannerPrompt.contains("# 营地笔记（往期经验）"))
    #expect(plannerPrompt.contains("北岭探索复盘"))
    #expect(plannerPrompt.contains("先看等高线"))

    let cardPrompt = firstUserText(await cardProvider.recordedHistories)
    #expect(cardPrompt.contains("# 营地笔记（往期经验）"))
    #expect(cardPrompt.contains("北岭探索复盘"))
    await orch.shutdown()
}

/// 验收 ① 离线版（spec §15-6）：私聊蒸馏 → 伙伴记忆 → 该伙伴下一张卡的上下文含记忆。
@Test func dmMemoryReachesNextCardContextGoldenPath() async throws {
    let db = try knowledgeTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "审校", model: "model-x", campId: camp.id)
    try db.saveCompanion(companion)

    // 私聊两句 → 手动沉淀
    let thread = try db.findOrCreateDMThread(companionId: companion.id)
    try db.appendChatMessage(threadId: thread.id, role: "user", text: "以后交付物都用 markdown")
    try db.appendChatMessage(threadId: thread.id, role: "companion", text: "记住了")
    let memoryJSON = ###"{"title":"交付物格式偏好","body":"- 用户要求交付物一律 markdown"}"###
    let distillService = MemoryDistillService(
        db: db,
        provider: MockProvider(script: [TurnResult(content: [.text(memoryJSON)], stopReason: .endTurn)]))
    let memory = await distillService.distillDM(companionId: companion.id, minMessages: 1)
    #expect(memory?.title == "交付物格式偏好")

    // 给该伙伴派下一张卡
    let cardProvider = MockProvider(script: [completeTurn(summary: "校对完成")])
    let orch = Orchestrator(
        db: db,
        makeProvider: { _, _ in cardProvider },
        artifactStoreRoot: try knowledgeArtifactRoot(),
        tickInterval: nil
    )
    _ = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "校对文稿", cardTitle: "校对",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 3)
    await orch.reconcile()
    await orch.waitUntilIdle()

    let cardPrompt = firstUserText(await cardProvider.recordedHistories)
    #expect(cardPrompt.contains("# 你的记忆"))
    #expect(cardPrompt.contains("交付物格式偏好"))
    #expect(cardPrompt.contains("markdown"))
    await orch.shutdown()
}
