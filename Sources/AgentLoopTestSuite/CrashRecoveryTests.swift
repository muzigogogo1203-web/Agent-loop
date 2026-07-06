import Testing
import Foundation
import GRDB
import AgentLoopCore

private func recoveryTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

private func recoveryArtifactRoot() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func recoveryDoneTurn() -> TurnResult {
    TurnResult(
        content: [.toolUse(id: UUID().uuidString, name: "complete_card", input: [
            "outcome": "完成",
            "summary": "续跑完成",
            "artifacts": [],
            "noArtifactReason": "无文件",
            "verification": [],
            "risks": [],
        ])],
        stopReason: .toolUse
    )
}

/// 挂起的 provider：模拟正在真实执行中的卡（流不结束直到取消）。
private actor RecoveryHangingProvider: LLMProvider {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    nonisolated func streamTurn(
        system: String, history: [APIMessage], tools: [ToolDef],
        toolChoice: ToolChoice, maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.markStarted()
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(3600))
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func markStarted() {
        started = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

// MARK: - 杀进程重启续跑（spec §16-M5 验收）

@Test func killRestartAdoptsOrphanAndResumesToDone() async throws {
    let db = try recoveryTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "断电的卡",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)

    // 模拟崩溃现场：卡 running + run 未收口（进程死掉，无人认领）
    let crashedRunId = UUID().uuidString
    try db.startRun(cardId: ids.cardId, runId: crashedRunId)
    #expect(try db.card(id: ids.cardId)?.status == .running)

    // 「重启」：全新 Orchestrator（内存注册表为空）→ 启动恢复
    let orch = Orchestrator(
        db: db,
        makeProvider: { _ in MockProvider(script: [recoveryDoneTurn()]) },
        artifactStoreRoot: try recoveryArtifactRoot(),
        tickInterval: nil
    )
    await orch.recoverAndReconcile()
    await orch.waitUntilIdle()

    // 续跑到 done；崩溃 run 标记 interrupted；领养事件带 crash_recovery
    #expect(try db.card(id: ids.cardId)?.status == .done)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.first { $0.id == crashedRunId }?.outcome == "interrupted")
    #expect(runs.contains { $0.outcome == "completed" })
    let events = try db.events(cardId: ids.cardId)
    #expect(events.contains {
        $0.kind == "card_interrupted" && $0.payloadJson.contains("crash_recovery")
    })
    await orch.shutdown()
}

@Test func adoptionSkipsCardsWithActiveRunners() async throws {
    let db = try recoveryTempDB()
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(name: "甲", color: "blue", rolePrompt: "执行", model: "m", campId: camp.id)
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g", cardTitle: "活着的卡",
        cardDescription: "d", expectedOutput: "o", assigneeId: companion.id, maxTurns: 5)

    let hanging = RecoveryHangingProvider()
    let orch = Orchestrator(
        db: db,
        makeProvider: { _ in hanging },
        artifactStoreRoot: try recoveryArtifactRoot(),
        tickInterval: nil
    )
    // 正常派发（活跑者在注册表里）
    await orch.reconcile()
    await hanging.waitUntilStarted()
    #expect(try db.card(id: ids.cardId)?.status == .running)

    // 再次启动恢复：不得误伤活跑者
    await orch.recoverAndReconcile()
    #expect(try db.card(id: ids.cardId)?.status == .running)
    let openRuns = try db.runs(cardId: ids.cardId).filter { $0.outcome == nil }
    #expect(openRuns.count == 1) // run 仍未收口（没被标 interrupted）

    await orch.shutdown()
}

// MARK: - 提案自愈（M4 评审遗留的崩溃窗口）

@Test func startupHealsConfirmedProposalWithoutMission() async throws {
    let db = try recoveryTempDB()
    let camp = try db.ensureDefaultCamp()
    let thread = try db.findOrCreateGuideThread(campId: camp.id)

    func insert(_ status: SquadProposalBlock.Status, missionId: String?) throws -> String {
        var block = SquadProposalBlock(
            proposalId: UUID().uuidString, name: "队", memberIds: ["c1"],
            goal: "g", budget: nil, status: status)
        block.missionId = missionId
        return try db.appendChatMessage(
            threadId: thread.id, role: "guide", contentJson: try block.encodedString())
    }

    let orphaned = try insert(.confirmed, missionId: nil)      // 崩溃窗口遗留 → 应治愈
    let landed = try insert(.confirmed, missionId: "mi-ok")    // 正常已建队 → 不动
    let dismissed = try insert(.dismissed, missionId: nil)     // 已驳回 → 不动

    let healed = try db.healOrphanedConfirmedProposals()
    #expect(healed == [orphaned])

    let messages = try db.messages(threadId: thread.id)
    #expect(messages.first { $0.id == orphaned }?.proposal?.status == .pending)
    #expect(messages.first { $0.id == landed }?.proposal?.status == .confirmed)
    #expect(messages.first { $0.id == dismissed }?.proposal?.status == .dismissed)

    // 治愈后可正常重新确认（CAS 语义完整）
    _ = try db.confirmProposalBlock(messageId: orphaned)
}

// MARK: - 安全作用域书签（M5-1b）

@Test func workspaceBookmarkCaptureAndResolveRoundtrip() throws {
    let db = try recoveryTempDB()
    _ = try db.ensureDefaultCamp()
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

    // 建行动时捕获书签
    let missionId = try db.createMissionShell(
        goal: "g", companionIds: [], workspacePath: workspace.path)
    let squad = try #require(try db.squad(forMission: missionId))
    #expect(squad.workspaceBookmark != nil)

    // 书签解析回同一目录
    let resolved = WorkspaceScopedAccess(
        workspacePath: squad.workspacePath, bookmark: squad.workspaceBookmark)
    #expect(resolved.url?.standardizedFileURL.path == workspace.standardizedFileURL.path)
    resolved.stop()

    // 损坏书签 → path 兜底
    let corrupt = WorkspaceScopedAccess(
        workspacePath: workspace.path, bookmark: Data([0x00, 0x01, 0x02]))
    #expect(corrupt.url?.path == workspace.path)
    corrupt.stop()

    // 无书签 → path 兜底；无 path → nil
    #expect(WorkspaceScopedAccess(workspacePath: workspace.path, bookmark: nil).url?.path == workspace.path)
    #expect(WorkspaceScopedAccess(workspacePath: nil, bookmark: nil).url == nil)

    // 无工作目录的行动不捕获书签
    let bare = try db.createMissionShell(goal: "g2", companionIds: [], workspacePath: nil)
    #expect(try db.squad(forMission: bare)?.workspaceBookmark == nil)
}
