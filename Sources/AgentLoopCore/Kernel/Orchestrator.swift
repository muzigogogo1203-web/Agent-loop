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
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "orchestrator")

    public init(
        db: AppDatabase,
        makeProvider: @escaping @Sendable (String) -> any LLMProvider,
        artifactStoreRoot: URL,
        tickInterval: Duration? = .seconds(5)
    ) {
        self.db = db
        self.makeProvider = makeProvider
        self.artifactStoreRoot = artifactStoreRoot
        self.tickInterval = tickInterval
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
        budgetTokens: Int = KernelDefaults.missionBudget
    ) async throws -> String {
        ensureTickStarted()
        let missionId = try db.createMissionShell(
            goal: goal, companionIds: companionIds,
            workspacePath: workspacePath, budgetTokens: budgetTokens)
        emit(.planningStarted(missionId: missionId))
        let task = Task {
            do {
                let roster = try db.companions(ids: companionIds)
                let planner = Planner(provider: makeProvider(plannerModel))
                // 开工带经验（spec §9-2）：规划上下文附带营地笔记
                let campNotes = self.loadCampNotes(campId: try db.squad(forMission: missionId)?.campId)
                let result = try await planner.propose(
                    goal: goal, roster: roster, workspacePath: workspacePath, campNotes: campNotes)
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

    public func reconcile() async {
        ensureTickStarted()
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
                                eventKind: "card_ready",
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
                var candidates: [DispatchCandidate] = []
                var errors: [KernelErrorRecord] = []
                for ready in readyCards {
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
                            model: companion.model
                        )
                    )
                }
                return ReconcilePlan(candidates: candidates, kernelErrors: errors)
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

        var busy = Set(running.values.map(\.assigneeId))
        for candidate in plan.candidates {
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
                    kind: "mission_failed",
                    payload: ["reason": "abandoned"]
                )
                try AppDatabase.appendEvent(
                    database,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: "mission_status_changed",
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
                        eventKind: "card_canceled",
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
        try db.transitionCard(id: cardId, to: .ready, eventKind: "card_ready", payload: .object([:]))
        await reconcile()
    }

    /// 提案确认（spec §10.2，plan D5/D10）：先 CAS（pending→confirmed）再建队；
    /// 建队失败补偿回滚 pending。重复确认在 CAS 处抛 StaleProposalError——宁可回滚，绝不重复建队。
    public func confirmSquadProposal(messageId: String, plannerModel: String) async throws -> String {
        let block = try db.confirmProposalBlock(messageId: messageId)
        do {
            let missionId = try await startMission(
                goal: block.goal,
                companionIds: block.memberIds,
                workspacePath: nil,
                plannerModel: plannerModel,
                budgetTokens: block.budget ?? KernelDefaults.missionBudget
            )
            try db.attachMissionToProposal(messageId: messageId, missionId: missionId)
            try? await db.pool.write { database in
                try AppDatabase.appendEvent(
                    database, missionId: missionId, cardId: nil, runId: nil,
                    kind: "squad_proposal_confirmed",
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
                                        kind: "mission_accepted", payload: .object([:]))
            try AppDatabase.appendEvent(
                database,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: "mission_status_changed",
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
                    kind: "camp_note_created",
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
            let campNotes = loadCampNotes(campId: try db.squad(forCard: candidate.card.id)?.campId)
            let companionNotes = loadCompanionNotes(companionId: candidate.assigneeId)
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
                companionNotes: companionNotes
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
            let message = String(describing: error)
            db.appendKernelErrorEvent(missionId: candidate.card.missionId, message: message)
            await emitFromTask(.kernelError(missionId: candidate.card.missionId, message: message))
        }
        await runnerFinished(cardId: candidate.card.id, missionId: candidate.card.missionId)
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
    }
}
