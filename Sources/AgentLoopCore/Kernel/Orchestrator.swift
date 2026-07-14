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

public struct KernelHaltedError: LocalizedError, Sendable, Equatable {
    public init() {}

    public var errorDescription: String? {
        "全部行动已紧急收哨，请先恢复后再出发。"
    }
}

public struct HaltPersistenceError: LocalizedError, Sendable, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }

    public var errorDescription: String? {
        "当前行动工作已经停止，但持久化收哨状态未能保存。请勿退出 AgentLoop，修复存储问题后重试保存。详情：\(detail)"
    }
}

public struct PlanningHaltCleanupError: LocalizedError, Sendable, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }

    public var errorDescription: String? {
        "当前行动工作已经停止，但被中断的规划未能安全收口。全部行动仍保持暂停；修复存储问题后重试恢复。详情：\(detail)"
    }
}

public struct HaltRecoveryError: LocalizedError, Sendable, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }

    public var errorDescription: String? {
        "恢复前的中断任务收编失败。全部行动仍保持暂停，没有启动新工作；修复存储问题后重试恢复。详情：\(detail)"
    }
}

public struct KernelTransitionInProgressError: LocalizedError, Sendable, Equatable {
    public init() {}

    public var errorDescription: String? {
        "停营或恢复状态正在由另一项操作处理，请确认当前状态后重试。"
    }
}

public actor Orchestrator {
    private enum DispatchPhase: Sendable, Equatable {
        case running
        case halting
        case halted
        case resuming
        case shuttingDown

        var permitsDispatch: Bool {
            self == .running
        }
    }

    private let db: AppDatabase
    private let makeProvider: @Sendable (String) -> any LLMProvider
    /// M6-D7：搜索 key 派发时解析（沿 makeProvider 注入模式），Core 不直连 Keychain 细节
    private let searchKeyProvider: @Sendable () -> String?
    private let artifactStoreRoot: URL
    private let reportStoreRoot: URL
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
    /// Durable dispatch mode is projected in SQLite. Transitional phases stay
    /// fail-closed across actor reentrancy while stop/resume await cleanup.
    private var dispatchPhase: DispatchPhase
    /// Ownership token for actor methods that cross await boundaries. Phase values
    /// can repeat (resuming -> halted -> resuming), so the enum alone cannot prevent ABA.
    private var dispatchTransitionToken = UUID()
    /// App startup can opt into a one-shot bootstrap gate. It closes dispatch in
    /// init, before the asynchronous recovery task has a chance to enter the actor.
    private let enforcesStartupRecovery: Bool
    private var startupRecoveryPending: Bool
    private var startupDispatchModeError: String?
    /// A stop that closed this process but failed to persist may be explicitly retried.
    private var haltPersistencePending = false
    /// M7-D8：429 全局冷却截止点（在途不动，只挡新派发）
    private var cooldownUntil: ContinuousClock.Instant?
    private let rateLimitCooldownDuration: Duration
    /// M8-D4：MCP 驿站管理（nil = 未接驿路，一切照旧）
    private let mcpManager: McpServerManager?
    /// Deterministic test seam for the post-database/pre-dispatch race. Nil in production.
    private let reconcilePostDatabaseGate: (@Sendable () async -> Void)?
    /// Deterministic test seam after a planner response and before its commit gate.
    private let planningPostProviderGate: (@Sendable () async -> Void)?
    /// Deterministic seams for transition-ownership regression tests. Nil in production.
    private let recoveryPostAdoptionGate: (@Sendable () async -> Void)?
    private let resumePreAdoptionGate: (@Sendable () async -> Void)?
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "orchestrator")

    public init(
        db: AppDatabase,
        makeProvider: @escaping @Sendable (String) -> any LLMProvider,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5),
        searchKeyProvider: @escaping @Sendable () -> String? = { nil },
        rateLimitCooldown: Duration = KernelDefaults.rateLimitCooldown,
        mcpManager: McpServerManager? = nil,
        reconcilePostDatabaseGate: (@Sendable () async -> Void)? = nil,
        planningPostProviderGate: (@Sendable () async -> Void)? = nil,
        recoveryPostAdoptionGate: (@Sendable () async -> Void)? = nil,
        resumePreAdoptionGate: (@Sendable () async -> Void)? = nil,
        requiresStartupRecovery: Bool = false
    ) {
        let initialPhase: DispatchPhase
        let initialError: String?
        do {
            let mode = try db.dispatchMode()
            initialPhase = mode == .running
                ? (requiresStartupRecovery ? .resuming : .running)
                : .halted
            initialError = nil
        } catch {
            initialPhase = .halted
            initialError = "读取持久化停营状态失败：\(String(describing: error))"
        }
        self.db = db
        self.makeProvider = makeProvider
        self.artifactStoreRoot = artifactStoreRoot
        self.reportStoreRoot = artifactStoreRoot.deletingLastPathComponent().appendingPathComponent("reports")
        self.tickInterval = tickInterval
        self.searchKeyProvider = searchKeyProvider
        self.rateLimitCooldownDuration = rateLimitCooldown
        self.mcpManager = mcpManager
        self.reconcilePostDatabaseGate = reconcilePostDatabaseGate
        self.planningPostProviderGate = planningPostProviderGate
        self.recoveryPostAdoptionGate = recoveryPostAdoptionGate
        self.resumePreAdoptionGate = resumePreAdoptionGate
        self.enforcesStartupRecovery = requiresStartupRecovery
        self.startupRecoveryPending = requiresStartupRecovery
        self.dispatchPhase = initialPhase
        self.startupDispatchModeError = initialError
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
        try requireDispatchRunning()
        ensureTickStarted()
        let missionId = try db.createMissionShell(
            goal: goal, companionIds: companionIds,
            workspacePath: workspacePath, budgetTokens: budgetTokens, campId: campId,
            autonomy: autonomy)
        emit(.planningStarted(missionId: missionId))
        let task = Task {
            do {
                try Task.checkCancellation()
                guard self.dispatchPhase.permitsDispatch else { throw CancellationError() }
                let roster = try db.companions(ids: companionIds)
                let planner = Planner(provider: makeProvider(plannerModel))
                // 开工带经验（spec §9-2）：规划上下文附带营地笔记
                let campNotes = self.loadCampNotes(campId: try db.squad(forMission: missionId)?.campId)
                let result = try await planner.propose(
                    goal: goal, roster: roster, workspacePath: workspacePath, campNotes: campNotes)
                if let planningPostProviderGate {
                    await planningPostProviderGate()
                }
                // A provider may ignore cancellation. Never let a stale planning result
                // account tokens or create cards after a stop has closed the gate.
                try Task.checkCancellation()
                guard self.dispatchPhase.permitsDispatch else { throw CancellationError() }
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
                emitFromTask(.planCompleted(missionId: missionId, fallback: result.fallbackReason != nil))
                emitFromTask(.missionChanged(missionId: missionId))
                await reconcile()
            } catch is CancellationError {
            } catch {
                let message = String(describing: error)
                db.appendKernelErrorEvent(missionId: missionId, message: message)
                await emitFromTask(.kernelError(missionId: missionId, message: message))
            }
            finishPlanning(missionId)
        }
        planningTasks[missionId] = task
        return missionId
    }

    /// 启动恢复（M5-1，spec §14/§16-M5）：先收编崩溃遗留的孤儿，再照常调度。
    /// 杀进程重启后行动续跑的入口——替代裸 reconcile() 作为 App 启动调用。
    public func recoverAndReconcile() async {
        if enforcesStartupRecovery {
            guard startupRecoveryPending else { return }
            guard dispatchPhase != .halting, dispatchPhase != .shuttingDown else {
                startupRecoveryPending = false
                return
            }
            // Claim the one permitted bootstrap call. stop/resume/shutdown can
            // invalidate its transition token while it is suspended.
            startupRecoveryPending = false
        } else {
            guard !haltPersistencePending,
                  dispatchPhase != .halting,
                  dispatchPhase != .resuming,
                  dispatchPhase != .shuttingDown else {
                return
            }
        }
        let durableMode: DispatchMode?
        let recoveryPhase: DispatchPhase
        do {
            let mode = try db.dispatchMode()
            durableMode = mode
            startupDispatchModeError = nil
            haltPersistencePending = false
            // Keep a running projection temporarily closed until crash residue has
            // been recovered. No start may race through an awaited recovery write.
            recoveryPhase = mode == .running ? .resuming : .halted
            if mode == .halted {
                emit(.haltStateChanged(true))
            }
        } catch {
            durableMode = nil
            recoveryPhase = .halted
            let detail = startupDispatchModeError ?? "读取持久化停营状态失败：\(String(describing: error))"
            let message = "\(detail)，已保持停止"
            startupDispatchModeError = message
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.haltStateChanged(true))
            emit(.kernelError(missionId: "", message: message))
        }
        let recoveryToken = beginTransition(recoveryPhase)
        do {
            try await adoptOrphans()
        } catch {
            guard ownsTransition(recoveryToken, phase: recoveryPhase) else { return }
            dispatchPhase = .halted
            tickTask?.cancel()
            tickTask = nil
            let message = "启动领养失败，已保持停止：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.haltStateChanged(true))
            emit(.kernelError(missionId: "", message: message))
            return
        }
        if let recoveryPostAdoptionGate {
            await recoveryPostAdoptionGate()
        }
        guard ownsTransition(recoveryToken, phase: recoveryPhase) else { return }
        healOrphanedConfirmedProposals()
        guard let durableMode else {
            tickTask?.cancel()
            tickTask = nil
            return
        }
        guard durableMode == .running else {
            tickTask?.cancel()
            tickTask = nil
            do {
                try await terminalizeInterruptedPlanningMissions(
                    limitedTo: nil,
                    excluding: Set(planningTasks.keys)
                )
            } catch {
                guard ownsTransition(recoveryToken, phase: .halted) else { return }
                reportPlanningCleanupFailure(error, prefix: "停营启动恢复")
            }
            return
        }
        guard ownsTransition(recoveryToken, phase: .resuming) else { return }
        dispatchPhase = .running
        emit(.haltStateChanged(false))
        await reconcile()
    }

    /// 收编孤儿：DB 里 running 但不在内存注册表的卡（崩溃/强杀遗留）→ ready 续跑，
    /// 其未收口的 run 标记 interrupted；confirmed-无-missionId 的提案回滚 pending 可重确认。
    private func adoptOrphans() async throws {
        let activeCardIds = Set(running.keys)
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
    }

    private func healOrphanedConfirmedProposals() {
        // 提案自愈（M4 评审遗留的崩溃窗口：CAS 确认后、建队前崩溃）
        do {
            let healed = try db.healOrphanedConfirmedProposals()
            if !healed.isEmpty {
                Self.logger.info("healed \(healed.count, privacy: .public) orphaned confirmed proposals")
            }
        } catch {
            let message = "提案自愈失败：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.kernelError(missionId: "", message: message))
        }
    }

    public func reconcile() async {
        // Check before tick creation: a restored halt must remain completely quiet.
        guard dispatchPhase.permitsDispatch else { return }
        ensureTickStarted()
        guard !reconciling else {
            reconcilePending = true
            return
        }
        reconciling = true
        defer { reconciling = false }

        repeat {
            guard dispatchPhase.permitsDispatch else {
                reconcilePending = false
                break
            }
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

        if let reconcilePostDatabaseGate {
            await reconcilePostDatabaseGate()
        }
        // The database write above suspends. A stop may have committed while it was in flight.
        guard dispatchPhase.permitsDispatch else { return }

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
            guard dispatchPhase.permitsDispatch else { break }
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

    public var isHalted: Bool { !dispatchPhase.permitsDispatch }

    /// 一键停营：取消全部在途（卡片走既有 card_interrupted → ready 领养语义）+
    /// 终止子进程 + 停派发。恢复用 resume()。
    public func emergencyStop() async throws {
        let stopToken = UUID()
        switch dispatchPhase {
        case .halting, .shuttingDown:
            return
        case .halted:
            guard haltPersistencePending else { return }
            startupRecoveryPending = false
            dispatchTransitionToken = stopToken
            dispatchPhase = .halting
            do {
                _ = try db.transitionDispatchMode(from: .running, to: .halted)
                haltPersistencePending = false
            } catch {
                dispatchPhase = .halted
                let message = "持久化停营状态重试失败；当前进程仍保持停止：\(String(describing: error))"
                Self.logger.error("\(message, privacy: .public)")
                db.appendKernelErrorEvent(missionId: "", message: message)
                emit(.kernelError(missionId: "", message: message))
                throw HaltPersistenceError(detail: String(describing: error))
            }
            do {
                try await terminalizeInterruptedPlanningMissions(
                    limitedTo: nil,
                    excluding: Set(planningTasks.keys)
                )
            } catch {
                guard ownsTransition(stopToken, phase: .halting) else { return }
                dispatchPhase = .halted
                reportPlanningCleanupFailure(error, prefix: "重试保存停营后")
                throw PlanningHaltCleanupError(detail: String(describing: error))
            }
            guard ownsTransition(stopToken, phase: .halting) else { return }
            dispatchPhase = .halted
            return
        case .running, .resuming:
            startupRecoveryPending = false
            dispatchTransitionToken = stopToken
            dispatchPhase = .halting
        }

        var persistenceFailure: Error?
        do {
            _ = try db.transitionDispatchMode(from: .running, to: .halted)
        } catch {
            persistenceFailure = error
        }
        haltPersistencePending = persistenceFailure != nil

        let interruptedPlanningIds = Set(planningTasks.keys)
        let planningSnapshot = Array(planningTasks.values)
        let runningSnapshot = running

        // Cancellation requests must fan out before awaiting either group. A planner
        // that ignores cancellation must never delay cancellation of active card work.
        for (_, task) in planningTasks { task.cancel() }
        for (_, entry) in runningSnapshot { entry.task.cancel() }
        tickTask?.cancel()
        tickTask = nil

        // Prioritize external-effecting card cleanup before waiting for planners.
        for (cardId, entry) in runningSnapshot {
            await entry.task.value
            running.removeValue(forKey: cardId)
        }
        for task in planningSnapshot { await task.value }
        guard ownsTransition(stopToken, phase: .halting) else { return }

        var planningCleanupFailure: Error?
        do {
            try await terminalizeInterruptedPlanningMissions(
                limitedTo: interruptedPlanningIds,
                excluding: []
            )
        } catch {
            planningCleanupFailure = error
        }
        guard ownsTransition(stopToken, phase: .halting) else { return }

        // M8：先优雅停驿站（状态回 stopped，恢复后可自动再启），再扫尾杀残余子进程；
        // 直接 terminateAll 会让驿站走「意外死亡」路径卡在 down（down 只能手动重启）。
        await mcpManager?.stopAll()
        guard ownsTransition(stopToken, phase: .halting) else { return }
        ShellProcessRegistry.shared.terminateAll()
        dispatchPhase = .halted
        emit(.haltStateChanged(true))

        if let persistenceFailure {
            var detail = String(describing: persistenceFailure)
            if let planningCleanupFailure {
                detail += "；同时规划收口失败：\(String(describing: planningCleanupFailure))"
                reportPlanningCleanupFailure(planningCleanupFailure, prefix: "紧急收哨")
            }
            let failure = HaltPersistenceError(detail: detail)
            let message = failure.errorDescription ?? detail
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.kernelError(missionId: "", message: message))
            throw failure
        }
        if let planningCleanupFailure {
            reportPlanningCleanupFailure(planningCleanupFailure, prefix: "紧急收哨")
            throw PlanningHaltCleanupError(detail: String(describing: planningCleanupFailure))
        }
    }

    /// 解除收哨并立即调度（中断的卡已在 ready，直接续跑）
    public func resume() async throws {
        switch dispatchPhase {
        case .running:
            return
        case .resuming:
            throw KernelTransitionInProgressError()
        case .halted:
            break
        case .halting, .shuttingDown:
            throw KernelHaltedError()
        }
        startupRecoveryPending = false
        let resumeToken = beginTransition(.resuming)

        do {
            try await terminalizeInterruptedPlanningMissions(
                limitedTo: nil,
                excluding: Set(planningTasks.keys)
            )
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            reportPlanningCleanupFailure(error, prefix: "恢复前")
            emit(.haltStateChanged(true))
            throw PlanningHaltCleanupError(detail: String(describing: error))
        }
        try requireTransition(resumeToken, phase: .resuming)

        if let resumePreAdoptionGate {
            await resumePreAdoptionGate()
        }
        try requireTransition(resumeToken, phase: .resuming)

        // Recover crash residue while the gate is still closed. Opening the durable
        // projection first would let unrelated starts race ahead of failed recovery.
        do {
            try await adoptOrphans()
        } catch {
            guard ownsTransition(resumeToken, phase: .resuming) else {
                throw KernelTransitionInProgressError()
            }
            dispatchPhase = .halted
            let message = "恢复前领养失败，已保持停止：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.haltStateChanged(true))
            emit(.kernelError(missionId: "", message: message))
            throw HaltRecoveryError(detail: String(describing: error))
        }
        try requireTransition(resumeToken, phase: .resuming)
        healOrphanedConfirmedProposals()

        do {
            _ = try db.transitionDispatchMode(from: .halted, to: .running)
        } catch {
            dispatchPhase = .halted
            let message = "恢复全部行动失败，系统仍保持停止：\(String(describing: error))"
            Self.logger.error("\(message, privacy: .public)")
            db.appendKernelErrorEvent(missionId: "", message: message)
            emit(.kernelError(missionId: "", message: message))
            throw error
        }

        startupDispatchModeError = nil
        haltPersistencePending = false
        dispatchPhase = .running
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

    /// M9：用户退回已完成小目标，保留上一版交付作为重做上下文，并立即重新调度。
    public func returnCardForRework(cardId: String, feedback: String) async throws {
        try db.returnCardForRework(cardId: cardId, feedback: feedback)
        if let missionId = try db.card(id: cardId)?.missionId {
            emit(.missionChanged(missionId: missionId))
        }
        await reconcile()
    }

    /// 提案确认（spec §10.2，plan D5/D10）：先 CAS（pending→confirmed）再建队；
    /// 建队失败补偿回滚 pending。重复确认在 CAS 处抛 StaleProposalError——宁可回滚，绝不重复建队。
    public func confirmSquadProposal(
        messageId: String, plannerModel: String,
        fallbackBudget: Int = KernelDefaults.missionBudget,
        autonomy: MissionAutonomy = .standard
    ) async throws -> String {
        try requireDispatchRunning()
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
        writeExpeditionReport(missionId: missionId)
        scheduleCloseoutDistillation(missionId: missionId, model: distillModel)
    }

    /// M9：验收后写入确定性远征报告。报告失败只进入内核错误事件，不反向阻塞收营。
    private func writeExpeditionReport(missionId: String) {
        do {
            let input = try db.expeditionReportInput(missionId: missionId)
            try FileManager.default.createDirectory(at: reportStoreRoot, withIntermediateDirectories: true)
            let url = reportStoreRoot.appendingPathComponent("\(missionId).md")
            try ExpeditionReport.markdown(input).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let message = "远征报告写入失败：\(String(describing: error))"
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    /// 收营蒸馏旁路（spec §9-1，plan D1）：绝不阻塞收营；任何路径都产出一张笔记。
    private func scheduleCloseoutDistillation(missionId: String, model: String) {
        guard distillTasks[missionId] == nil else { return }
        let task = Task {
            await self.runCloseoutDistillation(missionId: missionId, model: model)
            self.finishDistillation(missionId)
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
            await distillCoworkNotes(missionId: missionId, model: model)
        } catch {
            let message = "收营蒸馏落库失败：\(String(describing: error))"
            db.appendKernelErrorEvent(missionId: missionId, message: message)
            emit(.kernelError(missionId: missionId, message: message))
        }
    }

    /// M9：把一次行动中每位伙伴实际完成的小目标沉淀成伙伴记忆。失败静默跳过，留给人工复盘。
    private func distillCoworkNotes(missionId: String, model: String) async {
        let inputs: [CoworkDistillInput]
        let actionName: String
        do {
            (inputs, actionName) = try await db.pool.read { database in
                guard let mission = try MissionRecord.fetchOne(database, key: missionId) else {
                    throw RecordNotFoundError(table: "mission", id: missionId)
                }
                let goal = mission.goalRefined.isEmpty ? mission.goalRaw : mission.goalRefined
                let actionName = String(goal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
                let cards = try CardRecord
                    .filter(Column("missionId") == missionId && Column("status") == CardStatus.done.rawValue)
                    .order(Column("stage"))
                    .fetchAll(database)
                var grouped: [String: [CoworkCardDigest]] = [:]
                for card in cards {
                    guard let assigneeId = card.assigneeId else { continue }
                    let handoff = card.handoffJson.flatMap {
                        try? JSONDecoder().decode(HandoffPayload.self, from: Data($0.utf8))
                    }
                    grouped[assigneeId, default: []].append(
                        CoworkCardDigest(
                            title: card.title,
                            outcome: handoff?.outcome ?? "（无交接包）",
                            summary: handoff?.summary ?? "",
                            risks: handoff?.risks ?? []
                        )
                    )
                }

                var collected: [CoworkDistillInput] = []
                for assigneeId in grouped.keys.sorted() {
                    guard let companion = try CompanionRecord.fetchOne(database, key: assigneeId),
                          let digests = grouped[assigneeId], !digests.isEmpty else {
                        continue
                    }
                    let messages = digests.map { digest in
                        var lines = [
                            "行动目标：\(goal)",
                            "小目标：\(digest.title)",
                            "结果：\(digest.outcome)",
                        ]
                        if !digest.summary.isEmpty {
                            lines.append("摘要：\(digest.summary)")
                        }
                        if !digest.risks.isEmpty {
                            lines.append("风险：" + digest.risks.joined(separator: "；"))
                        }
                        return (role: "companion", text: lines.joined(separator: "\n"))
                    }
                    collected.append(CoworkDistillInput(companion: companion, messages: messages))
                }
                return (collected, actionName)
            }
        } catch {
            return
        }

        guard !inputs.isEmpty else { return }
        let distiller = Distiller(provider: makeProvider(model))
        for input in inputs {
            do {
                guard let note = try await distiller.distillMemory(
                    companionName: input.companion.name,
                    rolePrompt: input.companion.rolePrompt,
                    messages: input.messages
                ) else {
                    continue
                }
                let record = CompanionNoteRecord.new(
                    companionId: input.companion.id,
                    title: "共事·\(actionName):\(note.title)",
                    bodyMd: note.bodyMd
                )
                try await db.pool.write { database in
                    try record.insert(database)
                    try AppDatabase.appendEvent(
                        database, missionId: missionId, cardId: nil, runId: nil,
                        kind: EventKind.companionNoteCreated,
                        payload: [
                            "noteId": .string(record.id),
                            "companionId": .string(input.companion.id),
                            "source": .string("cowork"),
                        ]
                    )
                }
                emit(.missionChanged(missionId: missionId))
            } catch {
                continue
            }
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
        startupRecoveryPending = false
        dispatchTransitionToken = UUID()
        dispatchPhase = .shuttingDown
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
            try Task.checkCancellation()
            guard dispatchPhase.permitsDispatch else { throw CancellationError() }
            let upstream = try loadUpstreamHandoffs(for: candidate.card)
            var answeredRequests = try db.answeredRequests(cardId: candidate.card.id)
                .map { (prompt: $0.prompt, answer: $0.humanAnswer()) }
            if let returned = try db.latestReturnFeedback(cardId: candidate.card.id) {
                let previous = [
                    returned.previousOutcome.isEmpty ? nil : "上次结果：\(returned.previousOutcome)",
                    returned.previousSummary.isEmpty ? nil : "上次摘要：\(returned.previousSummary)",
                ].compactMap { $0 }.joined(separator: "\n")
                answeredRequests.append((
                    prompt: "上次交付被用户退回，请按意见重做。",
                    answer: [returned.feedback, previous].filter { !$0.isEmpty }.joined(separator: "\n")
                ))
            }
            // 知识注入（spec §6.2-5/6）：营地笔记 + 该伙伴的记忆
            let campId = try db.squad(forCard: candidate.card.id)?.campId
            let campNotes = loadCampNotes(campId: campId)
            let companionNotes = loadCompanionNotes(companionId: candidate.assigneeId)
            // M6-D4：白名单解析失败必须 fail-closed，只保留内核板工具并留痕。
            let toolAccess = ToolAccess.parse(toolsJson: candidate.toolsJson)
            let externalTools: [ExternalTool]
            if toolAccess.parseFailed {
                let message = "伙伴「\(candidate.companionName)」工具白名单解析失败，本次仅保留行动板工具"
                Self.logger.error("\(message, privacy: .public)")
                db.appendKernelErrorEvent(
                    missionId: candidate.card.missionId,
                    message: message)
                // MCP server 是进程级能力。配置损坏时连装配都不进入，避免先启动再过滤。
                externalTools = []
            } else {
                externalTools = await assembleMcpTools(
                    campId: campId, missionId: candidate.card.missionId,
                    cardId: candidate.card.id)
            }
            // MCP assembly suspends and may ignore cancellation while a server starts.
            // Re-check before CardRunner atomically claims ready -> running.
            try Task.checkCancellation()
            guard dispatchPhase.permitsDispatch else { throw CancellationError() }
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

    private func requireDispatchRunning() throws {
        guard dispatchPhase.permitsDispatch else {
            throw KernelHaltedError()
        }
    }

    private func beginTransition(_ phase: DispatchPhase) -> UUID {
        let token = UUID()
        dispatchTransitionToken = token
        dispatchPhase = phase
        return token
    }

    private func ownsTransition(_ token: UUID, phase: DispatchPhase) -> Bool {
        dispatchTransitionToken == token && dispatchPhase == phase
    }

    private func requireTransition(_ token: UUID, phase: DispatchPhase) throws {
        guard ownsTransition(token, phase: phase) else {
            throw KernelTransitionInProgressError()
        }
    }

    /// A bounded, honest terminal outcome for planning interrupted by emergency halt.
    /// Exact planning continuation requires a persisted attempt ledger and is intentionally deferred.
    private func terminalizeInterruptedPlanningMissions(
        limitedTo missionIds: Set<String>?,
        excluding liveMissionIds: Set<String>
    ) async throws {
        let changed = try await db.pool.write { database -> [String] in
            let planning = try MissionRecord
                .filter(Column("status") == MissionStatus.planning.rawValue)
                .fetchAll(database)
                .filter { mission in
                    !liveMissionIds.contains(mission.id)
                        && (missionIds?.contains(mission.id) ?? true)
                }
            for var mission in planning {
                let previous = mission.status
                mission.status = .failed
                try mission.update(database)
                try AppDatabase.appendEvent(
                    database,
                    missionId: mission.id,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionFailed,
                    payload: ["reason": "emergency_halt_during_planning"]
                )
                try AppDatabase.appendEvent(
                    database,
                    missionId: mission.id,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: [
                        "from": .string(previous.rawValue),
                        "to": .string(MissionStatus.failed.rawValue),
                    ]
                )
            }
            return planning.map(\.id)
        }
        for missionId in changed {
            emit(.missionChanged(missionId: missionId))
        }
    }

    private func reportPlanningCleanupFailure(_ error: Error, prefix: String) {
        let message = "\(prefix)的规划收口失败，已保持停止：\(String(describing: error))"
        Self.logger.error("\(message, privacy: .public)")
        db.appendKernelErrorEvent(missionId: "", message: message)
        emit(.kernelError(missionId: "", message: message))
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

    private struct CoworkCardDigest: Sendable {
        let title: String
        let outcome: String
        let summary: String
        let risks: [String]
    }

    private struct CoworkDistillInput: Sendable {
        let companion: CompanionRecord
        let messages: [(role: String, text: String)]
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
