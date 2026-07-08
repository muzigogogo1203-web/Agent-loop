import Foundation
import GRDB
import os

public enum KernelEvent: Sendable {
    case planningStarted(missionId: String)
    case planCompleted(missionId: String, fallback: Bool)
    case missionChanged(missionId: String)
    case cardEvent(cardId: String, AgentEvent)
    case kernelError(missionId: String, message: String)
    /// 收营蒸馏产出营地笔记（source: "closeout" | "fallback"）
    case campNoteCreated(missionId: String, noteId: String)
    /// M7-D5：紧急收哨状态翻转（true=已收哨）
    case haltStateChanged(Bool)
}

public struct MissionStateError: Error, Sendable, Equatable {
    public let missionId: String
    public let from: MissionStatus
    public let expected: MissionStatus

    public init(missionId: String, from: MissionStatus, expected: MissionStatus) {
        self.missionId = missionId
        self.from = from
        self.expected = expected
    }
}

public actor Orchestrator {
    private let db: AppDatabase
    private let makeProvider: @Sendable (String) -> any LLMProvider
    /// M6-D7：搜索 key 派发时解析（沿 makeProvider 注入模式），Core 不直连 Keychain 细节
    private let searchKeyProvider: @Sendable () -> String?
    private let artifactStoreRoot: URL
    private var running: [String: RunningEntry] = [:]
    private var planningTasks: [String: Task<Void, Never>] = [:]
    private var distillTasks: [String: Task<Void, Never>] = [:]
    private var continuations: [UUID: AsyncStream<KernelEvent>.Continuation] = [:]
    private let tickInterval: Duration?
    private var tickTask: Task<Void, Never>?
    private var reconciling = false
    private var reconcilePending = false
    private var cancelling: Set<String> = []
    /// 预算耗尽已通知的行动（加预算后移除，避免每次 reconcile 重复发事件）
    private var budgetNotified: Set<String> = []
    /// M7-D5：紧急收哨标志——reconcile 全停，直到 resume
    private var halted = false
    /// M7-D8：429 全局冷却截止点（在途不动，只挡新派发）
    private var cooldownUntil: ContinuousClock.Instant?
    private let rateLimitCooldownDuration: Duration
    /// M8-D4：MCP 驿站管理（nil = 未接驿路，一切照旧）
    private let mcpManager: McpServerManager?
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "orchestrator")

    public init(
        db: AppDatabase,
        makeProvider: @escaping @Sendable (String) -> any LLMProvider,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5),
        searchKeyProvider: @escaping @Sendable () -> String? = { nil },
        rateLimitCooldown: Duration = KernelDefaults.rateLimitCooldown,
        mcpManager: McpServerManager? = nil
    ) {
        self.db = db
        self.makeProvider = makeProvider
        self.artifactStoreRoot = artifactStoreRoot
        self.tickInterval = tickInterval
        self.searchKeyProvider = searchKeyProvider
        self.rateLimitCooldownDuration = rateLimitCooldown
        self.mcpManager = mcpManager
    }

    public func events() -> AsyncStream<KernelEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            continuations[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id) }
            }
        }
    }

    public func startMission(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        plannerModel: String,
        budgetTokens: Int = KernelDefaults.missionBudget,
        campId: String? = nil,
        autonomy: MissionAutonomy = .standard
    ) async throws -> String {
        ensureTickStarted()
        let missionId = try db.createMissionShell(
            goal: goal, companionIds: companionIds,
            workspacePath: workspacePath, budgetTokens: budgetTokens, campId: campId,
            autonomy: autonomy)
        emit(.planningStarted(missionId: missionId))
        let task = Task {
            do {
                let roster = try db.companions(ids: companionIds)
                let planner = Planner(provider: makeProvider(plannerModel))
                // 开工带经验（spec §9-2）：规划上下文附带营地笔记
                let campNotes = self.loadCampNotes(campId: try db.squad(forMission: missionId)?.campId)
                let result = try await planner.propose(
                    goal: goal, roster: roster, workspacePath: workspacePath, campNotes: campNotes)
                // M6-D13：规划轮入账（fallback 路径已消耗的部分也在 result.usage 里）
                if result.usage.inputTokens + result.usage.outputTokens > 0 {
                    try db.recordPlanningTokens(
                        missionId: missionId,
                        inputTokens: result.usage.inputTokens,
                        outputTokens: result.usage.outputTokens,
                        cacheReadTokens: result.usage.cacheReadTokens)
                }
                if let reason = result.fallbackReason {
                    try db.recordPlanFallback(missionId: missionId, reason: reason)
                }
                try db.planMission(missionId: missionId, goalRefined: result.proposal.goalRefined, drafts: result.proposal.cards)
                await emitFromTask(.planCompleted(missionId: missionId, fallback: result.fallbackReason != nil))
                await emitFromTask(.missionChanged(missionId: missionId))
                await reconcile()
            } catch is CancellationError {
            } catch {
                let message = String(describing: error)
                db.appendKernelErrorEvent(missionId: missionId, message: message)
                await emitFromTask(.kernelError(missionId: missionId, message: message))
            }
            await finishPlanning(missionId)
        }
        planningTasks[missionId] = task
        return missionId
    }

    /// 启动恢复（M5-1，spec §14/§16-M5）：先收编崩溃遗留的孤儿，再照常调度。
    /// 杀进程重启后行动续跑的入口——替代裸 reconcile() 作为 App 启动调用。
    public func recoverAndReconcile() async {
        await adoptOrphans()
        await reconcile()
    }

    /// 收编孤儿：DB 里 running 但不在内存注册表的卡（崩溃/强杀遗留）→ ready 续跑，
    /// 其未收口的 run 标记 interrupted；confirmed-无-missionId 的提案回滚 pending 可重确认。
    private func adoptOrphans() async {
        let activeCardIds = Set(running.keys)
        do {
            let adopted = try await db.pool.write { database -> [(cardId: String, missionId: String)] in
                let stuck = try CardRecord
                    .filter(Column("status") == CardStatus.running.rawValue)
                    .fetchAll(database)
                    .filter { !activeCardIds.contains($0.id) }
                for card in stuck {
                    try database.execute(
                        sql: """
                            UPDATE run SET outcome = 'interrupted', endedAt = ?
                            WHERE cardId = ? AND outcome IS NULL
                            """,
                        arguments: [Date(), card.id]
                    )
                    try self.db.transitionCard(
                        database,
                        id: card.id,
                        to: .ready,
                        eventKind: EventKind.cardInterrupted,
                        payload: ["reason": "crash_recovery"]
                    )
                }
                return stuck.map { (cardId: $0.id, missionId: $0.missionId) }
            }
            for orphan in adopted {
                Self.logger.info("adopted orphaned running card \(orphan.cardId, privacy: .public)")
                emit(.missionChanged(missionId: orphan.missionId))
            }
        } catch {
            emit(.kernelError(missionId: "", message: "启动领养失败：\(String(describing: error))"))
        }

        // 提案自愈（M4 评审遗留的崩溃窗口：CAS 确认后、建队前崩溃）
        if let healed = try? await db.healOrphanedConfirmedProposals(), !healed.isEmpty {
            Self.logger.info("healed \(healed.count, privacy: .public) orphaned confirmed proposals")
        }
    }

    public func reconcile() async {
        ensureTickStarted()
        // M7-D5：收哨期间不做任何调度（含 todo→ready 提升）
        guard !halted else { return }
        guard !reconciling else {
            reconcilePending = true
            return
        }
        reconciling = true
        defer { reconciling = false }

        repeat {
            reconcilePending = false
            await reconcileOnce()
        } while reconcilePending
    }

    private func reconcileOnce() async {
        let plan: ReconcilePlan
        do {
            plan = try await db.pool.write { database in
                let missions = try MissionRecord
                    .filter(Column("status") == MissionStatus.executing.rawValue)
                    .order(Column("createdAt"), Column.rowID)
                    .fetchAll(database)
                for mission in missions {
                    let cards = try CardRecord
                        .filter(Column("missionId") == mission.id)
                        .order(Column("stage"))
                        .fetchAll(database)
                    let statusById = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.status) })
                    for card in cards where card.status == .todo {
                        let dependencyIds = try Self.decodeStringArray(card.dependsOnJson)
                        if dependencyIds.allSatisfy({ statusById[$0] == .done }) {
                            try db.transitionCard(
                                database,
                                id: card.id,
                                to: .ready,
                                eventKind: EventKind.cardReady,
                                payload: .object([:])
                            )
                        }
                    }
                }

                let readyCards = try CardRecord.fetchAll(
                    database,
                    sql: """
                        SELECT card.*
                        FROM card
                        JOIN mission ON mission.id = card.missionId
                        WHERE mission.status = ? AND card.status = ?
                        ORDER BY mission.createdAt, mission.rowid, card.stage, card.createdAt, card.rowid
                        """,
                    arguments: [MissionStatus.executing.rawValue, CardStatus.ready.rawValue]
                )
                // 预算收尾线（M5-2，spec §13）：耗尽的行动停止派发，等用户三选
                let executingMissions = try MissionRecord
                    .filter(keys: Set(readyCards.map(\.missionId)))
                    .fetchAll(database)
                let exhaustedMissionIds = Set(
                    executingMissions.filter { $0.spentTokens >= $0.budgetTokens }.map(\.id)
                )
                // M7-D2：档位随候选下发（审批矩阵在 CardRunner 装门时消费）
                let autonomyByMission = Dictionary(
                    uniqueKeysWithValues: executingMissions.map { ($0.id, $0.autonomy) })
                var candidates: [DispatchCandidate] = []
                var errors: [KernelErrorRecord] = []
                for ready in readyCards where !exhaustedMissionIds.contains(ready.missionId) {
                    guard let assigneeId = ready.assigneeId,
                          let companion = try CompanionRecord.fetchOne(database, key: assigneeId) else {
                        let message = "负责伙伴不存在或未指派"
                        try db.blockCard(
                            database,
                            id: ready.id,
                            runId: nil,
                            reason: "other",
                            detail: message
                        )
                        errors.append(KernelErrorRecord(missionId: ready.missionId, message: message))
                        continue
                    }
                    candidates.append(
                        DispatchCandidate(
                            card: ready,
                            assigneeId: assigneeId,
                            companionName: companion.name,
                            rolePrompt: companion.rolePrompt,
                            model: companion.model,
                            toolsJson: companion.toolsJson,
                            autonomy: autonomyByMission[ready.missionId] ?? .standard
                        )
                    )
                }
                return ReconcilePlan(
                    candidates: candidates,
                    kernelErrors: errors,
                    budgetExhaustedMissionIds: exhaustedMissionIds)
            }
        } catch {
            emit(.kernelError(missionId: "", message: String(describing: error)))
            return
        }

        for error in plan.kernelErrors {
            db.appendKernelErrorEvent(missionId: error.missionId, message: error.message)
            emit(.kernelError(missionId: error.missionId, message: error.message))
            emit(.missionChanged(missionId: error.missionId))
        }

        for missionId in plan.budgetExhaustedMissionIds where !budgetNotified.contains(missionId) {
            budgetNotified.insert(missionId)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: missionId, cardId: nil, runId: nil,
                    kind: EventKind.missionBudgetExhausted, payload: .object([:]))
            }
            emit(.missionChanged(missionId: missionId))
        }

        // M7-D8：429 冷却期不派发新卡（在途不动）；到点自然恢复
        if let cooldownUntil, ContinuousClock.now < cooldownUntil {
            return
        }

        var busy = Set(running.values.map(\.assigneeId))
        for candidate in plan.candidates {
            // 全局并发节流（M5-2）
            guard running.count < KernelDefaults.maxConcurrentCardRuns else { break }
            guard !busy.contains(candidate.assigneeId),
                  !cancelling.contains(candidate.card.missionId),
                  running[candidate.card.id] == nil else {
                continue
            }
            let provider = makeProvider(candidate.model)
            let task = Task {
                await self.run(candidate: candidate, provider: provider)
            }
            running[candidate.card.id] = RunningEntry(
                task: task,
                assigneeId: candidate.assigneeId,
                missionId: candidate.card.missionId
            )
            busy.insert(candidate.assigneeId)
        }
    }

    // MARK: - 紧急收哨（M7-D5）

    public var isHalted: Bool { halted }

    /// 一键停营：取消全部在途（卡片走既有 card_interrupted → ready 领养语义）+
    /// 终止子进程 + 停派发。恢复用 resume()。
    public func emergencyStop() async {
        guard !halted else { return }
        halted = true

        for (_, task) in planningTasks { task.cancel() }
        let planningSnapshot = planningTasks.values
        planningTasks.removeAll()
        for task in planningSnapshot { await task.value }

        let runningSnapshot = running
        for (_, entry) in runningSnapshot { entry.task.cancel() }
        for (cardId, entry) in runningSnapshot {
            await entry.task.value
            running.removeValue(forKey: cardId)
        }

        // M8：先优雅停驿站（状态回 stopped，恢复后可自动再启），再扫尾杀残余子进程；
        // 直接 terminateAll 会让驿站走「意外死亡」路径卡在 down（down 只能手动重启）。
        await mcpManager?.stopAll()
        ShellProcessRegistry.shared.terminateAll()
        try? await db.pool.write { database in
            try AppDatabase.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.campHalted, payload: .object([:]))
        }
        emit(.haltStateChanged(true))
    }

    /// 解除收哨并立即调度（中断的卡已在 ready，直接续跑）
    public func resume() async {
        guard halted else { return }
        halted = false
        try? await db.pool.write { database in
            try AppDatabase.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.campResumed, payload: .object([:]))
        }
        emit(.haltStateChanged(false))
        await reconcile()
    }

    // MARK: - 限流冷却（M7-D8）

    private static func isRateLimit(_ error: ProviderError) -> Bool {
        switch error {
        case .http(let status, _): return status == 429
        case .overloadedRetriesExhausted: return true
        default: return false
        }
    }

    private func startRateLimitCooldown(missionId: String) {
        cooldownUntil = ContinuousClock.now + rateLimitCooldownDuration
        try? db.pool.write { database in
            try AppDatabase.appendEvent(
                database, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.rateLimitCooldown,
                payload: ["seconds": .number(15)])
        }
    }

    public func cancelMission(_ missionId: String) async {
        guard let mission = try? db.mission(id: missionId),
              mission.status != .accepted,
              mission.status != .failed else {
            return
        }
        cancelling.insert(missionId)
        defer { cancelling.remove(missionId) }

        if let planning = planningTasks.removeValue(forKey: missionId) {
            planning.cancel()
            await planning.value
        }

        let runningForMission = running.filter { $0.value.missionId == missionId }
        for (_, entry) in runningForMission {
            entry.task.cancel()
        }
        for (cardId, entry) in runningForMission {
            await entry.task.value
            running.removeValue(forKey: cardId)
        }
        await markOpenRunsCanceled(missionId: missionId)

        do {
            try await db.pool.write { database in
                guard var mission = try MissionRecord.fetchOne(database, key: missionId),
                      mission.status != .accepted,
                      mission.status != .failed else {
                    return
                }
                let previous = mission.status
                mission.status = .failed
                try mission.update(database)
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionFailed,
                    payload: ["reason": "abandoned"]
                )
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: ["from": .string(previous.rawValue), "to": .string(MissionStatus.failed.rawValue)]
                )
                let cards = try CardRecord
                    .filter(Column("missionId") == missionId)
                    .order(Column("stage"))
                    .fetchAll(database)
                for card in cards where card.status != .done && card.status != .canceled {
                    try db.transitionCard(
                        database,
                        id: card.id,
                        to: .canceled,
                        eventKind: EventKind.cardCanceled,
                        payload: ["reason": "mission_abandoned"]
                    )
                }
            }
            emit(.missionChanged(missionId: missionId))
        } catch {
            let message = String(describing: error)
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    private func markOpenRunsCanceled(missionId: String) async {
        try? await db.pool.write { database in
            let runs = try RunRecord.fetchAll(
                database,
                sql: """
                    SELECT r.*
                    FROM run r
                    JOIN card c ON c.id = r.cardId
                    WHERE c.missionId = ? AND r.outcome IS NULL
                    """,
                arguments: [missionId]
            )
            for var run in runs {
                run.outcome = "canceled"
                run.endedAt = Date()
                try run.update(database)
            }
        }
    }

    public func answerUserRequest(requestId: String, answerJson: String) async throws {
        try db.answerUserRequest(requestId: requestId, answerJson: answerJson)
        let missionId = try? await db.pool.read { database -> String in
            guard let request = try UserRequestRecord.fetchOne(database, key: requestId),
                  let card = try CardRecord.fetchOne(database, key: request.cardId) else {
                throw RecordNotFoundError(table: "user_request/card", id: requestId)
            }
            return card.missionId
        }
        if let missionId {
            emit(.missionChanged(missionId: missionId))
        }
        await reconcile()
    }

    public func retryCard(_ cardId: String) async throws {
        try db.transitionCard(id: cardId, to: .ready, eventKind: EventKind.cardReady, payload: .object([:]))
        await reconcile()
    }

    /// 提案确认（spec §10.2，plan D5/D10）：先 CAS（pending→confirmed）再建队；
    /// 建队失败补偿回滚 pending。重复确认在 CAS 处抛 StaleProposalError——宁可回滚，绝不重复建队。
    public func confirmSquadProposal(
        messageId: String, plannerModel: String,
        fallbackBudget: Int = KernelDefaults.missionBudget,
        autonomy: MissionAutonomy = .standard
    ) async throws -> String {
        let block = try db.confirmProposalBlock(messageId: messageId)
        do {
            // 提案建队归属向导所在营地（M5-0：从提案消息所在线程推导）
            let campId = try db.chatThread(forMessage: messageId)?.campId
            let missionId = try await startMission(
                goal: block.goal,
                companionIds: block.memberIds,
                workspacePath: nil,
                plannerModel: plannerModel,
                budgetTokens: block.budget ?? fallbackBudget,
                campId: campId,
                autonomy: autonomy
            )
            try db.attachMissionToProposal(messageId: messageId, missionId: missionId)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: missionId, cardId: nil, runId: nil,
                    kind: EventKind.squadProposalConfirmed,
                    payload: [
                        "proposalId": .string(block.proposalId),
                        "missionId": .string(missionId),
                    ]
                )
            }
            return missionId
        } catch {
            try? db.revertProposalToPending(messageId: messageId)
            throw error
        }
    }

    /// 三选之「加预算」（M5-2）：追加后解除通知去重并立刻恢复调度。
    public func addBudget(missionId: String, tokens: Int) async throws {
        try db.addBudget(missionId: missionId, tokens: tokens)
        budgetNotified.remove(missionId)
        emit(.missionChanged(missionId: missionId))
        await reconcile()
    }

    /// 三选之「就地收成果」（M5-2）：取消未完成的卡，保留已完成的——
    /// rollup 自然落位：有 done → delivering（可正常收营蒸馏）；全军覆没 → failed。
    public func harvestMission(_ missionId: String) async {
        guard let mission = try? db.mission(id: missionId),
              mission.status == .executing else {
            return
        }
        cancelling.insert(missionId)
        defer { cancelling.remove(missionId) }

        let runningForMission = running.filter { $0.value.missionId == missionId }
        for (_, entry) in runningForMission {
            entry.task.cancel()
        }
        for (cardId, entry) in runningForMission {
            await entry.task.value
            running.removeValue(forKey: cardId)
        }
        await markOpenRunsCanceled(missionId: missionId)

        do {
            try await db.pool.write { database in
                let cards = try CardRecord
                    .filter(Column("missionId") == missionId)
                    .order(Column("stage"))
                    .fetchAll(database)
                for card in cards where card.status != .done && card.status != .canceled {
                    try self.db.transitionCard(
                        database,
                        id: card.id,
                        to: .canceled,
                        eventKind: EventKind.cardCanceled,
                        payload: ["reason": "budget_harvest"]
                    )
                }
            }
            emit(.missionChanged(missionId: missionId))
        } catch {
            let message = String(describing: error)
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    public func closeout(_ missionId: String, distillModel: String) async throws {
        try await db.pool.write { database in
            guard var mission = try MissionRecord.fetchOne(database, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            guard mission.status == .delivering else {
                throw MissionStateError(missionId: missionId, from: mission.status, expected: .delivering)
            }
            let previous = mission.status
            mission.status = .accepted
            try mission.update(database)
            try AppDatabase.appendEvent(database, missionId: missionId, cardId: nil, runId: nil,
                                        kind: EventKind.missionAccepted, payload: .object([:]))
            try AppDatabase.appendEvent(
                database,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.missionStatusChanged,
                payload: ["from": .string(previous.rawValue), "to": .string(MissionStatus.accepted.rawValue)]
            )
        }
        emit(.missionChanged(missionId: missionId))
        scheduleCloseoutDistillation(missionId: missionId, model: distillModel)
    }

    /// 收营蒸馏旁路（spec §9-1，plan D1）：绝不阻塞收营；任何路径都产出一张笔记。
    private func scheduleCloseoutDistillation(missionId: String, model: String) {
        guard distillTasks[missionId] == nil else { return }
        let task = Task {
            await self.runCloseoutDistillation(missionId: missionId, model: model)
            await self.finishDistillation(missionId)
        }
        distillTasks[missionId] = task
    }

    private func runCloseoutDistillation(missionId: String, model: String) async {
        do {
            let input = try await db.pool.read { database -> (campId: String, goal: String, cards: [Distiller.CardDigest]) in
                guard let mission = try MissionRecord.fetchOne(database, key: missionId),
                      let squad = try SquadRecord.fetchOne(database, key: mission.squadId) else {
                    throw RecordNotFoundError(table: "mission/squad", id: missionId)
                }
                let doneCards = try CardRecord
                    .filter(Column("missionId") == missionId && Column("status") == CardStatus.done.rawValue)
                    .order(Column("stage"))
                    .fetchAll(database)
                let digests = doneCards.map { card -> Distiller.CardDigest in
                    let handoff = card.handoffJson.flatMap {
                        try? JSONDecoder().decode(HandoffPayload.self, from: Data($0.utf8))
                    }
                    return Distiller.CardDigest(
                        title: card.title,
                        outcome: handoff?.outcome ?? "（无交接包）",
                        summary: handoff?.summary ?? "",
                        risks: handoff?.risks ?? []
                    )
                }
                let goal = mission.goalRefined.isEmpty ? mission.goalRaw : mission.goalRefined
                return (squad.campId, goal, digests)
            }

            let distiller = Distiller(provider: makeProvider(model))
            let (note, fallback) = await distiller.distillCloseout(goal: input.goal, cards: input.cards)
            let record = CampNoteRecord.new(
                campId: input.campId, missionId: missionId,
                title: note.title, bodyMd: note.bodyMd)
            try await db.pool.write { database in
                try record.insert(database)
                try AppDatabase.appendEvent(
                    database, missionId: missionId, cardId: nil, runId: nil,
                    kind: EventKind.campNoteCreated,
                    payload: [
                        "noteId": .string(record.id),
                        "source": .string(fallback ? "fallback" : "closeout"),
                    ]
                )
            }
            emit(.campNoteCreated(missionId: missionId, noteId: record.id))
            emit(.missionChanged(missionId: missionId))
        } catch {
            let message = "收营蒸馏落库失败：\(String(describing: error))"
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    private func finishDistillation(_ missionId: String) {
        distillTasks.removeValue(forKey: missionId)
    }

    public func waitUntilIdle() async {
        while true {
            if running.isEmpty && planningTasks.isEmpty && distillTasks.isEmpty && !reconciling {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    public func shutdown() async {
        tickTask?.cancel()
        tickTask = nil
        for (_, task) in planningTasks {
            task.cancel()
        }
        for (_, entry) in running {
            entry.task.cancel()
        }
        for (_, task) in distillTasks {
            task.cancel()
        }
        for (_, task) in planningTasks {
            await task.value
        }
        for (_, entry) in running {
            await entry.task.value
        }
        for (_, task) in distillTasks {
            await task.value
        }
        planningTasks.removeAll()
        running.removeAll()
        distillTasks.removeAll()
        await mcpManager?.stopAll()
        for (_, continuation) in continuations {
            continuation.finish()
        }
        continuations.removeAll()
    }

    private func run(candidate: DispatchCandidate, provider: any LLMProvider) async {
        do {
            let upstream = try loadUpstreamHandoffs(for: candidate.card)
            let answeredRequests = try db.answeredRequests(cardId: candidate.card.id)
                .map { (prompt: $0.prompt, answer: $0.humanAnswer()) }
            // 知识注入（spec §6.2-5/6）：营地笔记 + 该伙伴的记忆
            let campId = try db.squad(forCard: candidate.card.id)?.campId
            let campNotes = loadCampNotes(campId: campId)
            let companionNotes = loadCompanionNotes(companionId: candidate.assigneeId)
            // M6-D4：白名单解析失败回退全量并留痕，坏 JSON 不瘫痪卡片
            let toolAccess = ToolAccess.parse(toolsJson: candidate.toolsJson)
            if toolAccess.parseFailed {
                db.appendKernelErrorEvent(
                    missionId: candidate.card.missionId,
                    message: "伙伴「\(candidate.companionName)」工具白名单解析失败，本次按全量工具执行")
            }
            let externalTools = await assembleMcpTools(
                campId: campId, missionId: candidate.card.missionId, cardId: candidate.card.id)
            let stream = try CardRunner(
                db: db,
                provider: provider,
                artifactStoreRoot: artifactStoreRoot,
                retryDelays: KernelDefaults.transportRetryDelays
            ).run(
                cardId: candidate.card.id,
                companionName: candidate.companionName,
                rolePrompt: candidate.rolePrompt,
                upstreamHandoffs: upstream,
                answeredRequests: answeredRequests,
                campNotes: campNotes,
                companionNotes: companionNotes,
                toolAccess: toolAccess,
                searchKey: searchKeyProvider(),
                autonomy: candidate.autonomy,
                externalTools: externalTools
            )
            for try await event in stream {
                await emitFromTask(.cardEvent(cardId: candidate.card.id, event))
            }
        } catch is CancellationError {
        } catch let error as CardTransitionError where error.to == .running {
            Self.logger.debug(
                "ignored stale dispatch candidate for card \(candidate.card.id, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        } catch {
            // M7-D8：重试耗尽的限流错误 → 全局冷却，reconcile 期间不派发新卡
            if let providerError = error as? ProviderError, Self.isRateLimit(providerError) {
                startRateLimitCooldown(missionId: candidate.card.missionId)
            }
            let message = String(describing: error)
            db.appendKernelErrorEvent(missionId: candidate.card.missionId, message: message)
            await emitFromTask(.kernelError(missionId: candidate.card.missionId, message: message))
        }
        await runnerFinished(cardId: candidate.card.id, missionId: candidate.card.missionId)
    }

    /// MCP 外部工具装配（M8-D4）：按卡所在营地取启用驿站 → 确保在跑（down 不自动重试）
    /// → 工具清单（缓存）→ 桥接为 ExternalTool。旁路增强：任何失败静默为空，不阻塞派发。
    private func assembleMcpTools(campId: String?, missionId: String, cardId: String) async -> [ExternalTool] {
        guard let mcpManager, let campId else { return [] }
        guard let enabled = try? db.enabledMcpServers(campId: campId), !enabled.isEmpty else {
            return []
        }
        await mcpManager.ensureRunning(serverIds: enabled.map(\.id))
        let assembled = await mcpManager.assembledTools(campId: campId)
        return assembled.map { tool in
            ExternalTool(
                def: tool.def,
                handler: McpToolBridge(
                    manager: mcpManager, db: db, missionId: missionId, cardId: cardId,
                    serverId: tool.serverId, serverName: tool.serverName,
                    toolName: tool.originalToolName))
        }
    }

    /// 知识注入是旁路增强：读取失败不阻塞规划/派发，静默为空。
    private func loadCampNotes(campId: String?) -> [NoteSnippet] {
        guard let campId,
              let notes = try? db.pinnedAndRecentCampNotes(campId: campId) else { return [] }
        return NoteSnippet.from(pinned: notes.pinned, recent: notes.recent)
    }

    private func loadCompanionNotes(companionId: String) -> [NoteSnippet] {
        guard let notes = try? db.pinnedAndRecentCompanionNotes(companionId: companionId) else { return [] }
        return NoteSnippet.from(pinned: notes.pinned, recent: notes.recent)
    }

    private func loadUpstreamHandoffs(for card: CardRecord) throws -> [UpstreamHandoff] {
        let dependencyIds = try Self.decodeStringArray(card.dependsOnJson)
        guard !dependencyIds.isEmpty else { return [] }
        let upstreamCards = try db.pool.read { database in
            try CardRecord
                .filter(keys: dependencyIds)
                .order(Column("stage"))
                .fetchAll(database)
        }
        var upstream: [UpstreamHandoff] = []
        for upstreamCard in upstreamCards {
            guard let handoffJson = upstreamCard.handoffJson else {
                throw ProviderError.malformedStream("upstream handoff missing for card \(upstreamCard.id)")
            }
            let handoff = try JSONDecoder().decode(HandoffPayload.self, from: Data(handoffJson.utf8))
            let artifacts = try db.artifacts(cardId: upstreamCard.id)
            upstream.append(
                UpstreamHandoff(
                    cardTitle: upstreamCard.title,
                    handoff: handoff,
                    workspaceRelativePaths: handoff.artifacts.map(\.relativePath),
                    durablePaths: artifacts.map(\.path)
                )
            )
        }
        return upstream
    }

    private func runnerFinished(cardId: String, missionId: String) async {
        running.removeValue(forKey: cardId)
        emit(.missionChanged(missionId: missionId))
        await reconcile()
    }

    private func finishPlanning(_ missionId: String) {
        planningTasks.removeValue(forKey: missionId)
    }

    private func ensureTickStarted() {
        guard tickTask == nil, let tickInterval else { return }
        tickTask = Task { [tickInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                if Task.isCancelled { break }
                await self.reconcile()
            }
        }
    }

    private func emit(_ event: KernelEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func emitFromTask(_ event: KernelEvent) {
        emit(event)
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private static func decodeStringArray(_ json: String) throws -> [String] {
        try JSONDecoder().decode([String].self, from: Data(json.utf8))
    }

    private struct DispatchCandidate: Sendable {
        let card: CardRecord
        let assigneeId: String
        let companionName: String
        let rolePrompt: String
        let model: String
        let toolsJson: String
        let autonomy: MissionAutonomy
    }

    private struct RunningEntry: Sendable {
        // Single in-memory dispatch authority for M3. The DB transition guard remains the
        // persistence backstop; M5 can revisit crash recovery for this registry.
        let task: Task<Void, Never>
        let assigneeId: String
        let missionId: String
    }

    private struct KernelErrorRecord: Sendable {
        let missionId: String
        let message: String
    }

    private struct ReconcilePlan: Sendable {
        let candidates: [DispatchCandidate]
        let kernelErrors: [KernelErrorRecord]
        let budgetExhaustedMissionIds: Set<String>
    }
}
