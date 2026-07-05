import Foundation
import GRDB

public enum KernelEvent: Sendable {
    case planningStarted(missionId: String)
    case planCompleted(missionId: String, fallback: Bool)
    case missionChanged(missionId: String)
    case cardEvent(cardId: String, AgentEvent)
    case kernelError(missionId: String, message: String)
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
    private var running: [String: Task<Void, Never>] = [:]
    private var planningTasks: [String: Task<Void, Never>] = [:]
    private var continuations: [UUID: AsyncStream<KernelEvent>.Continuation] = [:]
    private let tickInterval: Duration?
    private var tickTask: Task<Void, Never>?
    private var reconciling = false
    private var reconcilePending = false
    private var cancelling: Set<String> = []

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
        plannerModel: String
    ) async throws -> String {
        ensureTickStarted()
        let missionId = try db.createMissionShell(goal: goal, companionIds: companionIds, workspacePath: workspacePath)
        emit(.planningStarted(missionId: missionId))
        let task = Task {
            do {
                let roster = try db.companions(ids: companionIds)
                let planner = Planner(provider: makeProvider(plannerModel))
                let result = try await planner.propose(goal: goal, roster: roster, workspacePath: workspacePath)
                if let reason = result.fallbackReason {
                    try db.recordPlanFallback(missionId: missionId, reason: reason)
                }
                try db.planMission(missionId: missionId, goalRefined: result.proposal.goalRefined, drafts: result.proposal.cards)
                await emitFromTask(.planCompleted(missionId: missionId, fallback: result.fallbackReason != nil))
                await emitFromTask(.missionChanged(missionId: missionId))
                await reconcile()
            } catch is CancellationError {
            } catch {
                await emitFromTask(.kernelError(missionId: missionId, message: String(describing: error)))
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
        let action: ReconcileAction
        let hasRunning = !running.isEmpty
        do {
            action = try await db.pool.write { database in
                let missions = try MissionRecord
                    .filter(Column("status") == MissionStatus.executing.rawValue)
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

                guard !hasRunning else { return .none }
                guard let ready = try CardRecord
                    .fetchOne(
                        database,
                        sql: """
                            SELECT card.*
                            FROM card
                            JOIN mission ON mission.id = card.missionId
                            WHERE mission.status = ? AND card.status = ?
                            ORDER BY card.stage
                            LIMIT 1
                        """,
                        arguments: [MissionStatus.executing.rawValue, CardStatus.ready.rawValue]
                    ) else {
                    return .none
                }
                guard let assigneeId = ready.assigneeId,
                      let companion = try CompanionRecord.fetchOne(database, key: assigneeId) else {
                    try db.blockCard(
                        database,
                        id: ready.id,
                        runId: nil,
                        reason: "other",
                        detail: "负责伙伴不存在或未指派"
                    )
                    return .kernelError(missionId: ready.missionId, message: "负责伙伴不存在或未指派")
                }
                return .dispatch(DispatchCandidate(
                    card: ready,
                    companionName: companion.name,
                    rolePrompt: companion.rolePrompt,
                    model: companion.model
                ))
            }
        } catch {
            emit(.kernelError(missionId: "", message: String(describing: error)))
            return
        }

        guard case .dispatch(let candidate) = action else {
            if case .kernelError(let missionId, let message) = action {
                emit(.kernelError(missionId: missionId, message: message))
                emit(.missionChanged(missionId: missionId))
            }
            return
        }
        guard !cancelling.contains(candidate.card.missionId) else { return }
        let provider = makeProvider(candidate.model)
        let task = Task {
            await self.run(candidate: candidate, provider: provider)
        }
        running[candidate.card.id] = task
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

        let missionCardIds = (try? db.cards(missionId: missionId).map(\.id)) ?? []
        let runningForMission = running.filter { missionCardIds.contains($0.key) }
        for (_, task) in runningForMission {
            task.cancel()
        }
        for (cardId, task) in runningForMission {
            await task.value
            running.removeValue(forKey: cardId)
        }

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
            emit(.kernelError(missionId: missionId, message: String(describing: error)))
        }
    }

    public func retryCard(_ cardId: String) async throws {
        try db.transitionCard(id: cardId, to: .ready, eventKind: "card_ready", payload: .object([:]))
        await reconcile()
    }

    public func closeout(_ missionId: String) async throws {
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
    }

    public func waitUntilIdle() async {
        while true {
            if running.isEmpty && planningTasks.isEmpty && !reconciling {
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
        for (_, task) in running {
            task.cancel()
        }
        for (_, task) in planningTasks {
            await task.value
        }
        for (_, task) in running {
            await task.value
        }
        planningTasks.removeAll()
        running.removeAll()
        for (_, continuation) in continuations {
            continuation.finish()
        }
        continuations.removeAll()
    }

    private func run(candidate: DispatchCandidate, provider: any LLMProvider) async {
        do {
            let upstream = try loadUpstreamHandoffs(for: candidate.card)
            let stream = try CardRunner(
                db: db,
                provider: provider,
                artifactStoreRoot: artifactStoreRoot
            ).run(
                cardId: candidate.card.id,
                companionName: candidate.companionName,
                rolePrompt: candidate.rolePrompt,
                upstreamHandoffs: upstream
            )
            for try await event in stream {
                await emitFromTask(.cardEvent(cardId: candidate.card.id, event))
            }
        } catch is CancellationError {
        } catch {
            await emitFromTask(.kernelError(missionId: candidate.card.missionId, message: String(describing: error)))
        }
        await runnerFinished(cardId: candidate.card.id, missionId: candidate.card.missionId)
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
        let companionName: String
        let rolePrompt: String
        let model: String
    }

    private enum ReconcileAction: Sendable {
        case none
        case dispatch(DispatchCandidate)
        case kernelError(missionId: String, message: String)
    }
}
