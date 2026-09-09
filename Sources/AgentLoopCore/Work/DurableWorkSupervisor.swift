import Foundation
import GRDB
import os

public struct ShutdownReport: Sendable, Equatable {
    public let uncooperativeWorkIds: [String]
}

public struct SupervisorRecoveryRequiredError:
    LocalizedError, Sendable, Equatable
{
    public init() {}

    public var errorDescription: String? {
        "规划恢复尚未完成，暂不能派发。"
    }
}

public struct SupervisorDispatchSuppressedError:
    LocalizedError, Sendable, Equatable
{
    public init() {}

    public var errorDescription: String? {
        "牧场当前已停营，规划派发已关闭。"
    }
}

public struct SupervisorAlreadyShutDownError:
    LocalizedError, Sendable, Equatable
{
    public init() {}

    public var errorDescription: String? {
        "规划监督器已经关闭。"
    }
}

public struct SupervisorGenerationExpiredError:
    LocalizedError, Sendable, Equatable
{
    public let workId: String

    public var errorDescription: String? {
        "规划任务所有权已经失效。"
    }
}

public enum SupervisorFatalCode:
    String, Sendable, Equatable
{
    case generationOverflow = "generation_overflow"
    case storeFailure = "store_failure"
    case invalidLifecycle = "invalid_lifecycle"
}

public struct SupervisorFatalError:
    LocalizedError, Sendable, Equatable
{
    public let code: SupervisorFatalCode
    public let safeMessage: String

    public var errorDescription: String? {
        safeMessage
    }
}

#if DEBUG
package enum A2RuminationAuthorizationCheckpointForTesting:
    Sendable, Equatable, CaseIterable
{
    case first
    case second
}

package enum A2RuminationAuthorizationLossForTesting:
    Sendable, Equatable, CaseIterable
{
    case lifecycle
    case suppression
    case fatal
    case generation
    case token
    case workId
    case ingestion
    case actorAttempt
    case providerExited
    case pendingProposal
    case latestClaim
    case durableMode
    case durableWork
    case durableKind
    case durableAggregate
    case durableCamp
    case durableItem
    case durableAttempt
    case durableVersion
    case durableLeaseOwner
    case durableExpiry
    case durableReadFailure
    case durableInvariantCorruption
}

package enum A2RuminationAuthorizationScenarioForTesting:
    Sendable, Equatable
{
    case inject(
        checkpoint: A2RuminationAuthorizationCheckpointForTesting,
        loss: A2RuminationAuthorizationLossForTesting
    )
}
#endif

public actor DurableWorkSupervisor {
    private enum Lifecycle: String, Sendable {
        case initialized
        case recovering
        case recoveryReady
        case running
        case shuttingDown
        case shutDown
    }

    private enum ProviderCompletion: Sendable {
        case proposal(PlanningTerminalProposal)
        case canceled
        case invalidLifecycle
    }

    private enum CommitDisposition {
        case terminal
        case retryScheduled(Date)
    }

    private enum DispatchErrorDisposition {
        case stale
        case halted
        case retryable
        case fatal(SupervisorFatalError)
    }

    private struct ExecutionContext: Sendable {
        let planningInput: PlanningWorkInput
        let goal: String
        let roster: [CompanionRecord]
        let workspacePath: String?
        let campNotes: [NoteSnippet]
    }

    private struct OwnedEntry {
        let token: UUID
        let generation: Int
        let kind: DurableWorkKind
        let aggregateType: String
        let aggregateId: String
        var latestClaim: DurableWorkClaim
        var providerTask: Task<Void, Never>?
        var renewalTask: Task<Void, Never>?
        var terminalCommitPermitted: Bool
        var pendingTerminalProposal: PlanningTerminalProposal?
        var pendingRuminationTerminalProposal:
            RuminationTerminalProposal?
        var ruminationService: RuminationService?
        var providerExited: Bool
        var terminalResolved: Bool
    }

    private struct RuminationPhaseCoordinator {
        var deliveredPhase: RuminationPhase?
        var setInFlight: RuminationPhase?
        var setWaiters: [CheckedContinuation<Void, Never>] = []
        var setRevoked = false
        var invalidationReason:
            RuminationPhaseInvalidationReason?
        var invalidationInFlight = false
        var invalidationDelivered = false
        var invalidationWaitsForProjection = false
        var invalidationWaiters:
            [CheckedContinuation<Void, Never>] = []
    }

    private enum ProjectionDeliveryState: Equatable {
        case reserved
        case delivering
        case delivered
    }

    private enum ProjectionReservation: Equatable {
        case owner
        case duplicate
    }

    private enum PhaseInvalidationReservation: Equatable {
        case owner
        case duplicate
    }

    private static let leaseDuration: TimeInterval = 60
    private static let renewalInterval: Duration = .seconds(15)
    private static let emergencyHaltReason =
        "emergency_halt_during_planning"
    private static let logger = Logger(
        subsystem: "com.muzi.agentloop",
        category: "durable-planning-supervisor"
    )

    private let database: AppDatabase
    private let store: DurableWorkStore
    private let planningProviderResolver: any PlanningProviderResolver
    private let workerId: String
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void
    private let onMissionChanged: @Sendable (String) -> Void
    private let onRuminationPhase:
        @Sendable (RuminationPhaseCommand) async -> Void
    private let ruminationEnabled: Bool

    private var lifecycle: Lifecycle = .initialized
    private var dispatchSuppressed = true
    private var generation = 0
    private var fatalError: SupervisorFatalError?
    private var haltCleanupPending = false

    private var owned: [String: OwnedEntry] = [:]
    private var startProjectionBarriers: Set<String> = []
    private var startProjectionWaiters:
        [String: [CheckedContinuation<Void, Never>]] = [:]
    private var ruminationPhaseCoordinators:
        [RuminationPhaseIdentity: RuminationPhaseCoordinator] = [:]
#if DEBUG
    private var a2RuminationAuthorizationScenarioForTesting: (
        scenario: A2RuminationAuthorizationScenarioForTesting,
        identity: RuminationPhaseIdentity,
        token: UUID,
        generation: Int
    )?
#endif
    private var projectionDeliveryStates:
        [RuminationProjectionCommitIdentity: ProjectionDeliveryState] = [:]
    private var projectionDeliveryWaiters:
        [
            RuminationProjectionCommitIdentity:
                [CheckedContinuation<Void, Never>]
        ] = [:]
    private var highestProjectionByWork:
        [String: RuminationProjectionCommitIdentity] = [:]
    private var ruminationSinkInFlight = false
    private var ruminationSinkWaiters:
        [CheckedContinuation<Void, Never>] = []
    private var fatalInvalidationInFlight = false
    private var fatalInvalidationWaiters:
        [CheckedContinuation<Void, Never>] = []
    private var pumpToken: UUID?
    private var pumpTask: Task<Void, Never>?
    private var nextDueToken: UUID?
    private var nextDueDate: Date?
    private var nextDueTask: Task<Void, Never>?

    private var idleWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var terminalWaiters:
        [String: [UUID: CheckedContinuation<Void, Error>]] = [:]

    private var shutdownDeadlineTask: Task<Void, Never>?
    private var shutdownReport: ShutdownReport?
    private var shutdownWaiters:
        [UUID: CheckedContinuation<ShutdownReport, Never>] = [:]

    package init(
        database: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        workerId: String,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        onMissionChanged: @escaping @Sendable (String) -> Void
    ) {
        self.database = database
        self.store = DurableWorkStore(database: database)
        self.planningProviderResolver = planningProviderResolver
        self.workerId = workerId
        self.now = now
        self.sleep = sleep
        self.onMissionChanged = onMissionChanged
        self.onRuminationPhase = { _ in }
        self.ruminationEnabled = false
    }

    @_disfavoredOverload
    package init(
        database: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        workerId: String,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        onMissionChanged: @escaping @Sendable (String) -> Void,
        onRuminationPhase: @escaping @Sendable (
            RuminationPhaseCommand
        ) async -> Void = { _ in }
    ) {
        self.database = database
        self.store = DurableWorkStore(database: database)
        self.planningProviderResolver = planningProviderResolver
        self.workerId = workerId
        self.now = now
        self.sleep = sleep
        self.onMissionChanged = onMissionChanged
        self.onRuminationPhase = onRuminationPhase
        self.ruminationEnabled = true
    }

    package static func makeForOrchestrator(
        database: AppDatabase,
        planningProviderResolver: any PlanningProviderResolver,
        workerId: String,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        onMissionChanged: @escaping @Sendable (String) -> Void,
        ruminationEnabled: Bool,
        onRuminationPhase: @escaping @Sendable (
            RuminationPhaseCommand
        ) async -> Void
    ) -> DurableWorkSupervisor {
        if ruminationEnabled {
            return DurableWorkSupervisor(
                database: database,
                planningProviderResolver: planningProviderResolver,
                workerId: workerId,
                now: now,
                sleep: sleep,
                onMissionChanged: onMissionChanged,
                onRuminationPhase: onRuminationPhase
            )
        }
        return DurableWorkSupervisor(
            database: database,
            planningProviderResolver: planningProviderResolver,
            workerId: workerId,
            now: now,
            sleep: sleep,
            onMissionChanged: onMissionChanged
        )
    }

#if DEBUG
    package func armA2RuminationAuthorizationScenarioForTesting(
        _ scenario: A2RuminationAuthorizationScenarioForTesting,
        identity: RuminationPhaseIdentity
    ) throws {
        guard a2RuminationAuthorizationScenarioForTesting == nil,
              ruminationEnabled,
              lifecycle == .running,
              !dispatchSuppressed,
              fatalError == nil,
              identity.attempt >= 1,
              let entry = owned[identity.workId],
              self.generation == entry.generation,
              entry.kind == .rumination,
              entry.aggregateType == "ingestion",
              entry.aggregateId == identity.ingestionId,
              entry.latestClaim.workId == identity.workId,
              entry.latestClaim.attempt == identity.attempt,
              entry.latestClaim.workerId == workerId,
              let coordinator =
                  ruminationPhaseCoordinators[identity],
              coordinator.deliveredPhase != nil
                  || coordinator.setInFlight != nil,
              !coordinator.setRevoked,
              !coordinator.invalidationInFlight,
              !coordinator.invalidationDelivered,
              !entry.providerExited,
              entry.pendingTerminalProposal == nil,
              entry.pendingRuminationTerminalProposal == nil,
              entry.terminalCommitPermitted,
              !entry.terminalResolved
        else {
            throw InvalidDurableWorkStateError()
        }
        a2RuminationAuthorizationScenarioForTesting = (
            scenario: scenario,
            identity: identity,
            token: entry.token,
            generation: entry.generation
        )
    }
#endif

    public func recoverOnStartup(
        profileModels: [String: String]
    ) async throws {
        _ = try await recoverOnStartupCore(
            profileModels: profileModels,
            legacyRuminationSnapshot: .legacyProfileUnresolved
        )
    }

    package func recoverOnStartup(
        profileModels: [String: String],
        legacyRuminationSnapshot:
            LegacyRuminationStartupSnapshot
    ) async throws -> DispatchMode {
        try await recoverOnStartupCore(
            profileModels: profileModels,
            legacyRuminationSnapshot: legacyRuminationSnapshot
        )
    }

    private func recoverOnStartupCore(
        profileModels: [String: String],
        legacyRuminationSnapshot:
            LegacyRuminationStartupSnapshot
    ) async throws -> DispatchMode {
        try requireNotShutDown()
        if let fatalError {
            throw fatalError
        }
        try requireRuminationCompatibilitySafe()
        guard lifecycle == .initialized else {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "规划监督器恢复顺序无效。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "recover",
                workId: nil
            )
        }

        lifecycle = .recovering
        dispatchSuppressed = true
        haltCleanupPending = false
        var observedHaltedMode = false
        do {
            try database.repairLegacyPlanningMissions(
                profileModels: profileModels,
                now: now()
            )
            _ = try database.adoptInterruptedPlanning(
                currentWorkerId: workerId,
                now: now()
            )
            if ruminationEnabled {
                try database.repairLegacyRumination(
                    snapshot: legacyRuminationSnapshot,
                    now: now()
                )
                _ = try database.adoptInterruptedRumination(
                    currentWorkerId: workerId,
                    now: now()
                )
            }

            let recoveredMode = try database.dispatchMode()
            switch recoveredMode {
            case .running:
                lifecycle = .recoveryReady
                dispatchSuppressed = true
            case .halted:
                observedHaltedMode = true
                haltCleanupPending = true
                let missionIds =
                    try database.cancelAllPlanningForEmergencyHalt(
                        reason: Self.emergencyHaltReason,
                        now: now()
                    )
                if ruminationEnabled {
                    let commits =
                        try database
                            .cancelAllRuminationForEmergencyHalt(
                                reason:
                                    "emergency_halt_during_rumination",
                                now: now()
                            )
                    for commit in commits {
                        let reservation =
                            try reserveRuminationProjectionCommit(
                                commit,
                                revokePhase: true
                            )
                        try await publishReservedRuminationProjection(
                            commit,
                            reservation: reservation
                        )
                    }
                }
                haltCleanupPending = false
                lifecycle = .running
                dispatchSuppressed = true
                for missionId in missionIds {
                    onMissionChanged(missionId)
                }
            }
            await wakeIdleWaitersIfPossible()
            return recoveredMode
        } catch {
            lifecycle = .initialized
            dispatchSuppressed = true
            haltCleanupPending = observedHaltedMode
            logErrorType(
                error,
                operation: "recover",
                workId: nil,
                level: .error
            )
            throw error
        }
    }

    public func startIfNeeded() throws {
        try requireDispatchable()
        launchPumpIfNeeded()
    }

    public func kick() async throws {
        try requireDispatchable()
        try requireRuminationCompatibilitySafe()
        guard startProjectionBarriers.isEmpty else {
            return
        }
        let priorDueDate = nextDueDate
        cancelNextDueTimer()
        do {
            try await retryPendingTerminalProposals()
        } catch {
            if let priorDueDate {
                await scheduleNextDue(priorDueDate)
            }
            throw error
        }
        try requireDispatchable()
        launchPumpIfNeeded()
    }

    public func cancelPlanning(
        missionId: String,
        reason: String
    ) async throws {
        try requireNotShutDown()
        try requireRuminationCompatibilitySafe()
        if lifecycle == .initialized || lifecycle == .recovering {
            throw SupervisorRecoveryRequiredError()
        }
        if let fatalError {
            Self.logger.notice(
                "control cancel continues under fatal latch code=\(fatalError.code.rawValue, privacy: .public) mission=\(missionId, privacy: .private(mask: .hash))"
            )
        }

        let active = try store.activeWork(
            kind: .planning,
            aggregateType: "mission",
            aggregateId: missionId
        )
        let candidate = try active ?? store.latestWork(
            kind: .planning,
            aggregateType: "mission",
            aggregateId: missionId
        )
        guard let candidate else {
            return
        }
        guard active != nil || candidate.state == .canceled else {
            return
        }

        do {
            let result = try database.cancelPlanning(
                workId: candidate.id,
                expectedVersion: candidate.version,
                reason: reason,
                now: now()
            )
            switch result {
            case let .canceled(work), let .alreadyCanceled(work):
                await handleCommittedControlTerminal(
                    workId: work.id,
                    missionId: missionId
                )
            }
        } catch is StaleDurableWorkClaimError {
            if let current = try store.latestWork(
                kind: .planning,
                aggregateType: "mission",
                aggregateId: missionId
            ), Self.isTerminal(current.state) {
                await handleCommittedControlTerminal(
                    workId: current.id,
                    missionId: missionId
                )
                return
            }
            throw StaleDurableWorkClaimError()
        }
    }

    package func convertCandidateAndEnqueuePlanning(
        _ command: CandidatePlanningStartCommand
    ) throws -> CandidatePlanningStartResult {
        try requireDispatchable()
        try requireRuminationCompatibilitySafe()
        return try database.convertCandidateAndEnqueuePlanning(
            command,
            planningProviderResolver: planningProviderResolver
        )
    }

    package func startScheduledMission(
        _ command: SchedulePlanningStartCommand
    ) throws -> ScheduleFireCommitResult {
        try requireDispatchable()
        try requireRuminationCompatibilitySafe()
        return try database.startScheduledMission(
            command,
            planningProviderResolver: planningProviderResolver
        )
    }

    package func replayMissedScheduleFire(
        _ command: ScheduleReplayStartCommand
    ) throws -> ScheduleFireCommitResult {
        try requireDispatchable()
        try requireRuminationCompatibilitySafe()
        return try database.replayMissedScheduleFire(
            command,
            planningProviderResolver: planningProviderResolver
        )
    }

    package func startRumination(
        preparation: RuminationStartPreparation,
        command: RuminationStartCommand?
    ) async throws -> DurableWorkRecord {
        guard ruminationEnabled else {
            throw RuminationRequiresDurableRuminationCapabilityError()
        }
        try requireDispatchable()
        switch preparation {
        case let .replay(ingestionId, workId):
            guard command == nil else {
                throw DurableWorkReplayConflictError()
            }
            return try await finishRuminationStartReplay(
                ingestionId: ingestionId,
                workId: workId
            )
        case .new:
            guard let command else {
                throw DurableWorkReplayConflictError()
            }
            guard try RuminationStartCommand(
                preparation: preparation,
                traceId: command.traceId,
                input: command.input
            ) == command
            else {
                throw DurableWorkReplayConflictError()
            }

            if let replay = try database.ruminationStartReplay(
                command: command
            ) {
                return try await finishRuminationStartReplay(
                    ingestionId: command.ingestionId,
                    workId: replay.id
                )
            }
            do {
                _ = try planningProviderResolver
                    .resolvePlanningProvider(
                        profileId:
                            command.input.runtimeProfileId,
                        model: command.input.model
                    )
            } catch let error as PlanningProviderResolutionError {
                throw try Self.ruminationResolutionFailure(error)
            } catch {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage: "反刍运行配置预检返回了未知错误。"
                )
                logErrorType(
                    error,
                    operation: "rumination-start-resolver",
                    workId: nil,
                    level: .fault
                )
                throw await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "rumination-start-resolver",
                    workId: nil
                )
            }

            let result = try database.startRumination(
                command: command,
                now: now()
            )
            switch result.disposition {
            case .replayed:
                return try await finishRuminationStartReplay(
                    ingestionId: command.ingestionId,
                    workId: result.work.id
                )
            case .inserted:
                let reserved = try reserveInsertedRuminationStart(
                    ingestionId: command.ingestionId,
                    work: result.work
                )
                return try await finishInsertedRuminationStart(
                    ingestionId: command.ingestionId,
                    work: result.work,
                    projection: reserved.projection,
                    reservation: reserved.reservation
                )
            }
        }
    }

    private func finishRuminationStartReplay(
        ingestionId: String,
        workId: String
    ) async throws -> DurableWorkRecord {
        await waitForStartProjectionIfNeeded(workId: workId)
        let lifecycleAllowsDispatch =
            lifecycle == .running
                && !dispatchSuppressed
                && fatalError == nil
        let durableMode: DispatchMode
        do {
            durableMode = try database.dispatchMode()
        } catch {
            throw await latchReadFailure(
                error,
                operation: "rumination-start-replay-mode",
                workId: workId
            )
        }
        let work: DurableWorkRecord
        do {
            work = try requiredWork(id: workId)
        } catch {
            throw await latchReadFailure(
                error,
                operation: "rumination-start-replay-work",
                workId: workId
            )
        }
        guard work.kind == .rumination,
              work.aggregateType == "ingestion",
              work.aggregateId == ingestionId
        else {
            throw DurableWorkReplayConflictError()
        }
        if lifecycleAllowsDispatch,
           durableMode == .running,
           Self.isActive(work.state)
        {
            try await kick()
        }
        return work
    }

    private func reserveInsertedRuminationStart(
        ingestionId: String,
        work: DurableWorkRecord
    ) throws -> (
        projection: RuminationProjectionCommitIdentity,
        reservation: ProjectionReservation
    ) {
        guard work.kind == .rumination,
              work.aggregateType == "ingestion",
              work.aggregateId == ingestionId,
              work.state == .queued,
              work.attempt == 0,
              work.version == 1
        else {
            throw InvalidDurableWorkStateError()
        }
        let projection = try RuminationProjectionCommitIdentity(
            phaseIdentity: RuminationPhaseIdentity(
                ingestionId: ingestionId,
                workId: work.id,
                attempt: 0
            ),
            workVersion: work.version
        )
        let reservation = try reserveRuminationProjectionCommit(
            projection,
            revokePhase: false
        )
        guard reservation == .owner,
              startProjectionBarriers.insert(work.id).inserted
        else {
            throw InvalidDurableWorkStateError()
        }
        return (projection, reservation)
    }

    private func finishInsertedRuminationStart(
        ingestionId: String,
        work: DurableWorkRecord,
        projection: RuminationProjectionCommitIdentity,
        reservation: ProjectionReservation
    ) async throws -> DurableWorkRecord {
        try await publishReservedRuminationProjection(
            projection,
            reservation: reservation
        )
        releaseStartProjectionBarrier(workId: work.id)

        let lifecycleAllowsDispatch =
            lifecycle == .running
                && !dispatchSuppressed
                && fatalError == nil
        let durableMode: DispatchMode
        do {
            durableMode = try database.dispatchMode()
        } catch {
            throw await latchReadFailure(
                error,
                operation: "rumination-start-inserted-mode",
                workId: work.id
            )
        }
        let persisted: DurableWorkRecord
        do {
            persisted = try requiredWork(id: work.id)
        } catch {
            throw await latchReadFailure(
                error,
                operation: "rumination-start-inserted-work",
                workId: work.id
            )
        }
        guard persisted.kind == .rumination,
              persisted.aggregateType == "ingestion",
              persisted.aggregateId == ingestionId
        else {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage:
                    "反刍开始后的持久任务身份已损坏。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "rumination-start-inserted-identity",
                workId: work.id
            )
        }
        if lifecycleAllowsDispatch,
           durableMode == .running,
           Self.isActive(persisted.state)
        {
            try await kick()
        }
        return persisted
    }

    package func cancelRumination(
        ingestionId: String
    ) async throws {
        guard ruminationEnabled else {
            throw RuminationRequiresDurableRuminationCapabilityError()
        }
        try requireNotShutDown()
        guard let active = try store.activeWork(
            kind: .rumination,
            aggregateType: "ingestion",
            aggregateId: ingestionId
        ) else {
            return
        }
        do {
            guard let resulting = try database.cancelRumination(
                ingestionId: ingestionId,
                workId: active.id,
                expectedVersion: active.version,
                reason: "rumination_deferred_by_user",
                now: now()
            ) else {
                return
            }
            let phaseIdentity = try RuminationPhaseIdentity(
                ingestionId: ingestionId,
                workId: resulting.id,
                attempt: resulting.attempt
            )
            let projection =
                try RuminationProjectionCommitIdentity(
                    phaseIdentity: phaseIdentity,
                    workVersion: resulting.version
                )
            let reservation =
                try reserveRuminationProjectionCommit(
                    projection,
                    revokePhase: true
                )
            try await publishReservedRuminationProjection(
                projection,
                reservation: reservation
            )
            await finishCommittedRuminationControl(
                workId: resulting.id
            )
        } catch is StaleDurableWorkClaimError {
            return
        }
    }

    public func waitUntilIdle() async throws {
        try requireWaitableLifecycle()
        if let fatalError {
            throw fatalError
        }
        do {
            if try isIdleNow() {
                return
            }
        } catch {
            throw await latchReadFailure(
                error,
                operation: "wait-idle",
                workId: nil
            )
        }

        let waiterId = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                if let fatalError {
                    continuation.resume(throwing: fatalError)
                } else if lifecycle == .shuttingDown
                            || lifecycle == .shutDown
                {
                    continuation.resume(
                        throwing: SupervisorAlreadyShutDownError()
                    )
                } else {
                    idleWaiters[waiterId] = continuation
                }
            }
        } onCancel: {
            Task {
                await self.cancelIdleWaiter(waiterId)
            }
        }
    }

    public func waitUntilTerminal(workId: String) async throws {
        do {
            guard let work = try store.work(id: workId) else {
                throw DurableWorkNotFoundError(workId: workId)
            }
            if Self.isTerminal(work.state) {
                return
            }
        } catch let error as DurableWorkNotFoundError {
            throw error
        } catch {
            throw await latchReadFailure(
                error,
                operation: "wait-terminal",
                workId: workId
            )
        }

        try requireWaitableLifecycle()
        if let fatalError {
            throw fatalError
        }

        let waiterId = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                if let fatalError {
                    continuation.resume(throwing: fatalError)
                } else if lifecycle == .shuttingDown
                            || lifecycle == .shutDown
                {
                    continuation.resume(
                        throwing: SupervisorAlreadyShutDownError()
                    )
                } else {
                    terminalWaiters[workId, default: [:]][waiterId] =
                        continuation
                }
            }
        } onCancel: {
            Task {
                await self.cancelTerminalWaiter(
                    workId: workId,
                    waiterId: waiterId
                )
            }
        }
    }

    public func shutdown(
        gracePeriod: Duration = .seconds(2)
    ) async -> ShutdownReport {
        if let shutdownReport {
            return shutdownReport
        }
        if lifecycle == .shuttingDown {
            return await waitForShutdownReport()
        }

        lifecycle = .shuttingDown
        dispatchSuppressed = true
        let identities = activeRuminationPhaseIdentities()
        let (nextGeneration, overflow) =
            generation.addingReportingOverflow(1)
        if !overflow {
            generation = nextGeneration
        }
        revokeAllOwnedEntriesWithoutCancel()
        let invalidations = reserveRuminationPhaseInvalidations(
            identities: identities,
            reason: .controlLoss
        )
        await publishReservedRuminationPhaseInvalidations(
            invalidations
        )
        cancelPumpAndNextDue()
        cancelAllOwnedTasksAfterInvalidation()
        failOperationalWaiters(with: SupervisorAlreadyShutDownError())

        if uncooperativeWorkIds().isEmpty {
            return finalizeShutdown()
        }

        let delay = gracePeriod < .zero ? Duration.zero : gracePeriod
        let sleep = self.sleep
        shutdownDeadlineTask = Task.detached {
            do {
                try await sleep(delay)
            } catch {
                let errorType = String(reflecting: type(of: error))
                await self.shutdownDeadlineSleepFailed(
                    errorType: errorType
                )
                return
            }
            await self.shutdownDeadlineReached()
        }
        return await waitForShutdownReport()
    }

    package func suppressForEmergencyStop() async throws {
        try requireNotShutDown()
        switch lifecycle {
        case .initialized, .recovering:
            throw SupervisorRecoveryRequiredError()
        case .recoveryReady:
            guard dispatchSuppressed else {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage: "规划恢复待激活状态已损坏。"
                )
                throw await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "suppress-for-emergency-stop",
                    workId: nil
                )
            }
            lifecycle = .running
            haltCleanupPending = true
        case .running:
            dispatchSuppressed = true
            haltCleanupPending = true
        case .shuttingDown, .shutDown:
            throw SupervisorAlreadyShutDownError()
        }
        let identities = activeRuminationPhaseIdentities()
        let (nextGeneration, overflow) =
            generation.addingReportingOverflow(1)
        guard !overflow else {
            let fatal = makeFatal(
                .generationOverflow,
                safeMessage: "规划监督器世代计数已耗尽。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "emergency-advance-generation",
                workId: nil
            )
        }
        generation = nextGeneration
        revokeAllOwnedEntriesWithoutCancel()
        let invalidations = reserveRuminationPhaseInvalidations(
            identities: identities,
            reason: .controlLoss
        )
        await publishReservedRuminationPhaseInvalidations(
            invalidations
        )
        cancelPumpAndNextDue()
        cancelAllOwnedTasksAfterInvalidation()
    }

    package func activateAfterOrchestratorRecovery() throws {
        try requireNotShutDown()
        if let fatalError {
            throw fatalError
        }
        guard lifecycle == .recoveryReady else {
            switch lifecycle {
            case .initialized, .recovering:
                throw SupervisorRecoveryRequiredError()
            case .recoveryReady:
                break
            case .running:
                throw SupervisorDispatchSuppressedError()
            case .shuttingDown, .shutDown:
                throw SupervisorAlreadyShutDownError()
            }
            throw SupervisorDispatchSuppressedError()
        }
        guard dispatchSuppressed, !haltCleanupPending else {
            throw SupervisorDispatchSuppressedError()
        }
        lifecycle = .running
        dispatchSuppressed = false
        launchPumpIfNeeded()
    }

    #if DEBUG
    package func injectOwnedSuccessProposalForTesting(
        workId: String,
        result: PlanResult
    ) async throws {
        guard let entry = owned[workId] else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        try await acceptProviderProposal(
            workId: workId,
            token: entry.token,
            generation: entry.generation,
            proposal: .success(result)
        )
    }
    #endif

    package func didCommitEmergencyPlanningCleanup(
        missionIds: [String]
    ) async throws {
        try requireNotShutDown()
        guard lifecycle == .running, dispatchSuppressed else {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "停营规划清理提交顺序无效。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "halt-cleanup-committed",
                workId: nil
            )
        }

        let ruminationCommits: [
            RuminationProjectionCommitIdentity
        ]
        if ruminationEnabled {
            ruminationCommits =
                try database.cancelAllRuminationForEmergencyHalt(
                    reason: "emergency_halt_during_rumination",
                    now: now()
                )
        } else {
            try requireRuminationCompatibilitySafe()
            ruminationCommits = []
        }
        for commit in ruminationCommits {
            let reservation =
                try reserveRuminationProjectionCommit(
                    commit,
                    revokePhase: true
                )
            try await publishReservedRuminationProjection(
                commit,
                reservation: reservation
            )
        }

        let changedMissionIds = Array(Set(missionIds)).sorted()
        let changedSet = Set(changedMissionIds)
        for workId in owned.keys.sorted() {
            guard var entry = owned[workId] else {
                continue
            }
            let work = try requiredWork(id: workId)
            let valid: Bool
            switch entry.kind {
            case .planning:
                valid = changedSet.contains(entry.aggregateId)
                    || Self.isTerminal(work.state)
            case .rumination:
                valid = Self.isTerminal(work.state)
            default:
                valid = false
            }
            guard valid else {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage: "停营清理提交后仍存在活动规划任务。"
                )
                throw await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "halt-cleanup-verify",
                    workId: workId
                )
            }
            entry.terminalCommitPermitted = false
            entry.pendingTerminalProposal = nil
            entry.pendingRuminationTerminalProposal = nil
            entry.terminalResolved = true
            entry.renewalTask?.cancel()
            entry.providerTask?.cancel()
            owned[workId] = entry
            if entry.providerExited {
                owned.removeValue(forKey: workId)
            }
        }
        haltCleanupPending = false
        try refreshTerminalWaitersFromStore()
        for missionId in changedMissionIds {
            onMissionChanged(missionId)
        }
        await wakeIdleWaitersIfPossible()
    }

    package func resumeAfterDurableRunning() async throws {
        try requireNotShutDown()
        if let fatalError {
            throw fatalError
        }
        guard lifecycle == .running else {
            if lifecycle == .initialized || lifecycle == .recovering {
                throw SupervisorRecoveryRequiredError()
            }
            if lifecycle == .recoveryReady {
                throw SupervisorDispatchSuppressedError()
            }
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "规划监督器恢复派发顺序无效。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "resume",
                workId: nil
            )
        }
        guard dispatchSuppressed, !haltCleanupPending else {
            if !dispatchSuppressed {
                return
            }
            throw SupervisorDispatchSuppressedError()
        }
        do {
            guard try database.dispatchMode() == .running else {
                throw SupervisorDispatchSuppressedError()
            }
        } catch let error as SupervisorDispatchSuppressedError {
            throw error
        } catch {
            throw await latchReadFailure(
                error,
                operation: "resume-dispatch-mode",
                workId: nil
            )
        }

        dispatchSuppressed = false
        launchPumpIfNeeded()
    }

    private func requireNotShutDown() throws {
        switch lifecycle {
        case .shuttingDown, .shutDown:
            throw SupervisorAlreadyShutDownError()
        case .initialized, .recovering, .recoveryReady, .running:
            return
        }
    }

    private func requireWaitableLifecycle() throws {
        switch lifecycle {
        case .initialized:
            throw SupervisorRecoveryRequiredError()
        case .recovering:
            throw SupervisorRecoveryRequiredError()
        case .recoveryReady:
            return
        case .running:
            return
        case .shuttingDown, .shutDown:
            throw SupervisorAlreadyShutDownError()
        }
    }

    private func requireDispatchable() throws {
        try requireNotShutDown()
        if let fatalError {
            throw fatalError
        }
        switch lifecycle {
        case .initialized, .recovering:
            throw SupervisorRecoveryRequiredError()
        case .recoveryReady:
            throw SupervisorDispatchSuppressedError()
        case .running:
            guard !dispatchSuppressed else {
                throw SupervisorDispatchSuppressedError()
            }
        case .shuttingDown, .shutDown:
            throw SupervisorAlreadyShutDownError()
        }
    }

    private func requireRuminationCompatibilitySafe() throws {
        guard !ruminationEnabled else {
            return
        }
        let ownsRumination = owned.values.contains {
            $0.kind == .rumination
        }
        let hasSetInFlight = ruminationPhaseCoordinators.values
            .contains { $0.setInFlight != nil }
        let hasLiveObligation = ruminationPhaseCoordinators.values
            .contains {
                $0.deliveredPhase != nil
                    || $0.invalidationInFlight
                    || $0.invalidationDelivered
            }
        guard try !database.hasActiveRuminationWork(),
              !ownsRumination,
              !hasSetInFlight,
              !hasLiveObligation,
              startProjectionBarriers.isEmpty
        else {
            throw RuminationRequiresDurableRuminationCapabilityError()
        }
    }

    private func acquireRuminationSink() async {
        if !ruminationSinkInFlight {
            ruminationSinkInFlight = true
            return
        }
        await withCheckedContinuation { continuation in
            ruminationSinkWaiters.append(continuation)
        }
    }

    private func releaseRuminationSink() {
        if ruminationSinkWaiters.isEmpty {
            ruminationSinkInFlight = false
            return
        }
        let continuation = ruminationSinkWaiters.removeFirst()
        continuation.resume()
    }

    private func deliverRuminationCommand(
        _ command: RuminationPhaseCommand
    ) async {
        await acquireRuminationSink()
        await onRuminationPhase(command)
        releaseRuminationSink()
    }

    private func matchingReservedProjection(
        for identity: RuminationPhaseIdentity
    ) -> RuminationProjectionCommitIdentity? {
        projectionDeliveryStates.keys
            .filter { $0.phaseIdentity == identity }
            .sorted { $0.workVersion < $1.workVersion }
            .first
    }

    private func waitForRuminationSetDelivery(
        identity: RuminationPhaseIdentity
    ) async {
        guard ruminationPhaseCoordinators[identity]?.setInFlight != nil
        else {
            return
        }
        await withCheckedContinuation { continuation in
            var coordinator =
                ruminationPhaseCoordinators[identity]
                ?? RuminationPhaseCoordinator()
            if coordinator.setInFlight == nil {
                continuation.resume()
            } else {
                coordinator.setWaiters.append(continuation)
                ruminationPhaseCoordinators[identity] = coordinator
            }
        }
    }

    private func emitRuminationPhase(
        identity: RuminationPhaseIdentity,
        phase: RuminationPhase
    ) async throws {
        guard identity.attempt >= 1 else {
            throw InvalidDurableWorkStateError()
        }
        var coordinator =
            ruminationPhaseCoordinators[identity]
            ?? RuminationPhaseCoordinator()
        guard !coordinator.setRevoked,
              !coordinator.invalidationInFlight,
              !coordinator.invalidationDelivered,
              matchingReservedProjection(for: identity) == nil
        else {
            throw RuminationPreParseAuthorizationLostError()
        }
        if coordinator.deliveredPhase == phase {
            return
        }
        if let inFlight = coordinator.setInFlight {
            guard inFlight == phase else {
                throw InvalidDurableWorkStateError()
            }
            ruminationPhaseCoordinators[identity] = coordinator
            await waitForRuminationSetDelivery(identity: identity)
            guard ruminationPhaseCoordinators[identity]?
                .deliveredPhase == phase
            else {
                throw RuminationPreParseAuthorizationLostError()
            }
            return
        }
        switch (coordinator.deliveredPhase, phase) {
        case (nil, .reading),
             (.reading?, .extracting),
             (.extracting?, .organizing):
            break
        default:
            throw InvalidDurableWorkStateError()
        }
        coordinator.setInFlight = phase
        ruminationPhaseCoordinators[identity] = coordinator
        await deliverRuminationCommand(
            .set(identity: identity, phase: phase)
        )
        guard var delivered =
            ruminationPhaseCoordinators[identity],
              delivered.setInFlight == phase
        else {
            preconditionFailure(
                "rumination phase coordinator lost in-flight set"
            )
        }
        delivered.setInFlight = nil
        delivered.deliveredPhase = phase
        let waiters = delivered.setWaiters
        delivered.setWaiters.removeAll()
        ruminationPhaseCoordinators[identity] = delivered
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func waitForRuminationInvalidation(
        identity: RuminationPhaseIdentity
    ) async {
        guard let coordinator =
            ruminationPhaseCoordinators[identity],
              coordinator.invalidationInFlight,
              !coordinator.invalidationDelivered
        else {
            return
        }
        await withCheckedContinuation { continuation in
            var current =
                ruminationPhaseCoordinators[identity]
                ?? RuminationPhaseCoordinator()
            if current.invalidationDelivered
                || !current.invalidationInFlight
            {
                continuation.resume()
            } else {
                current.invalidationWaiters.append(continuation)
                ruminationPhaseCoordinators[identity] = current
            }
        }
    }

    private func finishRuminationInvalidation(
        identity: RuminationPhaseIdentity
    ) {
        guard var coordinator =
            ruminationPhaseCoordinators[identity]
        else {
            preconditionFailure(
                "rumination invalidation coordinator disappeared"
            )
        }
        coordinator.invalidationInFlight = false
        coordinator.invalidationDelivered = true
        let waiters = coordinator.invalidationWaiters
        coordinator.invalidationWaiters.removeAll()
        ruminationPhaseCoordinators[identity] = coordinator
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func reserveRuminationPhaseInvalidation(
        identity: RuminationPhaseIdentity,
        reason: RuminationPhaseInvalidationReason
    ) -> PhaseInvalidationReservation {
        var coordinator =
            ruminationPhaseCoordinators[identity]
            ?? RuminationPhaseCoordinator()
        coordinator.setRevoked = true
        if coordinator.invalidationDelivered {
            ruminationPhaseCoordinators[identity] = coordinator
            return .duplicate
        }
        if coordinator.invalidationInFlight {
            ruminationPhaseCoordinators[identity] = coordinator
            return .duplicate
        }
        coordinator.invalidationReason =
            coordinator.invalidationReason ?? reason
        coordinator.invalidationInFlight = true
        coordinator.invalidationWaitsForProjection =
            matchingReservedProjection(for: identity) != nil
        ruminationPhaseCoordinators[identity] = coordinator
        return .owner
    }

    private func publishReservedRuminationPhaseInvalidation(
        identity: RuminationPhaseIdentity,
        reservation: PhaseInvalidationReservation
    ) async {
        if reservation == .duplicate {
            await waitForRuminationInvalidation(identity: identity)
            return
        }
        guard let coordinator =
            ruminationPhaseCoordinators[identity],
              coordinator.invalidationInFlight,
              !coordinator.invalidationDelivered,
              let chosenReason = coordinator.invalidationReason
        else {
            preconditionFailure(
                "rumination phase invalidation was not reserved"
            )
        }
        let waitsForProjection =
            coordinator.invalidationWaitsForProjection

        if coordinator.setInFlight != nil {
            await waitForRuminationSetDelivery(identity: identity)
        }
        if waitsForProjection,
           let projection = matchingReservedProjection(
               for: identity
           )
        {
            await waitForRuminationProjectionDelivery(projection)
            finishRuminationInvalidation(identity: identity)
            return
        }
        await deliverRuminationCommand(
            .invalidate(
                .phase(identity: identity, reason: chosenReason)
            )
        )
        finishRuminationInvalidation(identity: identity)
    }

    private func invalidateRuminationPhaseIfNeeded(
        identity: RuminationPhaseIdentity,
        reason: RuminationPhaseInvalidationReason
    ) async {
        let reservation = reserveRuminationPhaseInvalidation(
            identity: identity,
            reason: reason
        )
        await publishReservedRuminationPhaseInvalidation(
            identity: identity,
            reservation: reservation
        )
    }

    private func reserveRuminationPhaseInvalidations(
        identities: [RuminationPhaseIdentity],
        reason: RuminationPhaseInvalidationReason
    ) -> [
        (
            identity: RuminationPhaseIdentity,
            reservation: PhaseInvalidationReservation
        )
    ] {
        identities.map { identity in
            (
                identity,
                reserveRuminationPhaseInvalidation(
                    identity: identity,
                    reason: reason
                )
            )
        }
    }

    private func publishReservedRuminationPhaseInvalidations(
        _ reservations: [
            (
                identity: RuminationPhaseIdentity,
                reservation: PhaseInvalidationReservation
            )
        ]
    ) async {
        for reserved in reservations {
            await publishReservedRuminationPhaseInvalidation(
                identity: reserved.identity,
                reservation: reserved.reservation
            )
        }
    }

    private func reserveRuminationProjectionCommit(
        _ identity: RuminationProjectionCommitIdentity,
        revokePhase: Bool
    ) throws -> ProjectionReservation {
        if projectionDeliveryStates[identity] != nil {
            return .duplicate
        }
        let workId = identity.phaseIdentity.workId
        if let highest = highestProjectionByWork[workId] {
            guard identity.workVersion > highest.workVersion else {
                throw InvalidDurableWorkStateError()
            }
        }
        highestProjectionByWork[workId] = identity
        projectionDeliveryStates[identity] = .reserved
        if revokePhase, identity.phaseIdentity.attempt >= 1 {
            var coordinator =
                ruminationPhaseCoordinators[
                    identity.phaseIdentity
                ] ?? RuminationPhaseCoordinator()
            coordinator.setRevoked = true
            ruminationPhaseCoordinators[
                identity.phaseIdentity
            ] = coordinator
            if var entry = owned[workId],
               entry.kind == .rumination,
               entry.latestClaim.attempt
                    == identity.phaseIdentity.attempt
            {
                entry.terminalCommitPermitted = false
                owned[workId] = entry
            }
        }
        return .owner
    }

    private func waitForRuminationProjectionDelivery(
        _ identity: RuminationProjectionCommitIdentity
    ) async {
        if projectionDeliveryStates[identity] == .delivered {
            return
        }
        await withCheckedContinuation { continuation in
            if projectionDeliveryStates[identity] == .delivered {
                continuation.resume()
            } else {
                projectionDeliveryWaiters[
                    identity,
                    default: []
                ].append(continuation)
            }
        }
    }

    private func publishReservedRuminationProjection(
        _ identity: RuminationProjectionCommitIdentity,
        reservation: ProjectionReservation
    ) async throws {
        switch reservation {
        case .duplicate:
            await waitForRuminationProjectionDelivery(identity)
            return
        case .owner:
            break
        }
        guard projectionDeliveryStates[identity] == .reserved else {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "反刍投影发布状态已损坏。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "rumination-projection-reservation",
                workId: identity.phaseIdentity.workId
            )
        }
        let phaseIdentity = identity.phaseIdentity
        if ruminationPhaseCoordinators[phaseIdentity]?
            .setInFlight != nil
        {
            await waitForRuminationSetDelivery(
                identity: phaseIdentity
            )
        }
        if let coordinator =
            ruminationPhaseCoordinators[phaseIdentity],
           coordinator.invalidationInFlight,
           !coordinator.invalidationWaitsForProjection
        {
            await waitForRuminationInvalidation(
                identity: phaseIdentity
            )
        }
        projectionDeliveryStates[identity] = .delivering
        await deliverRuminationCommand(
            .invalidate(.projectionCommitted(identity))
        )
        projectionDeliveryStates[identity] = .delivered
        let waiters =
            projectionDeliveryWaiters.removeValue(
                forKey: identity
            ) ?? []
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func waitForStartProjectionIfNeeded(
        workId: String
    ) async {
        guard startProjectionBarriers.contains(workId) else {
            return
        }
        await withCheckedContinuation { continuation in
            if startProjectionBarriers.contains(workId) {
                startProjectionWaiters[
                    workId,
                    default: []
                ].append(continuation)
            } else {
                continuation.resume()
            }
        }
    }

    private func releaseStartProjectionBarrier(workId: String) {
        guard startProjectionBarriers.remove(workId) != nil else {
            preconditionFailure(
                "rumination start projection barrier was not reserved"
            )
        }
        let waiters =
            startProjectionWaiters.removeValue(forKey: workId) ?? []
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func validatedRuminationEntry(
        identity: RuminationPhaseIdentity,
        token: UUID,
        generation: Int
    ) throws -> OwnedEntry {
        guard lifecycle == .running else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard !dispatchSuppressed else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard fatalError == nil else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard self.generation == generation else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard let tokenEntry = owned.values.first(
            where: {
                $0.token == token && $0.generation == generation
            }
        ) else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard tokenEntry.latestClaim.workId == identity.workId,
              let entry = owned[identity.workId],
              entry.token == token
        else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard entry.kind == .rumination,
              entry.aggregateType == "ingestion",
              entry.aggregateId == identity.ingestionId
        else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard entry.latestClaim.attempt == identity.attempt else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard !entry.providerExited else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        guard entry.pendingRuminationTerminalProposal == nil,
              entry.terminalCommitPermitted
        else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        let latestClaim = entry.latestClaim
        guard latestClaim.workId == identity.workId,
              latestClaim.workerId == workerId
        else {
            throw SupervisorGenerationExpiredError(
                workId: identity.workId
            )
        }
        return entry
    }

    private func validatedRuminationHandlerEntry(
        workId: String,
        attempt: Int,
        token: UUID,
        generation: Int
    ) throws -> (
        entry: OwnedEntry,
        identity: RuminationPhaseIdentity
    ) {
        guard lifecycle == .running else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard !dispatchSuppressed else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard fatalError == nil else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard self.generation == generation else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard let tokenEntry = owned.values.first(
            where: {
                $0.token == token && $0.generation == generation
            }
        ) else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard tokenEntry.latestClaim.workId == workId,
              let entry = owned[workId],
              entry.token == token
        else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard entry.kind == .rumination,
              entry.aggregateType == "ingestion"
        else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard let identity = recoverRuminationPhaseIdentity(
            workId: workId,
            attempt: attempt
        ) else {
            throw InvalidDurableWorkStateError()
        }
        guard entry.aggregateId == identity.ingestionId else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard entry.latestClaim.attempt == attempt else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard !entry.providerExited else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        guard entry.pendingRuminationTerminalProposal == nil,
              entry.terminalCommitPermitted
        else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        let latestClaim = entry.latestClaim
        guard latestClaim.workId == workId,
              latestClaim.workerId == workerId
        else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        return (entry, identity)
    }

    private func recoverRuminationPhaseIdentity(
        workId: String,
        attempt: Int
    ) -> RuminationPhaseIdentity? {
        let matches = ruminationPhaseCoordinators.keys.filter {
            $0.workId == workId && $0.attempt == attempt
        }
        guard matches.count == 1 else {
            return nil
        }
        return matches[0]
    }

#if DEBUG
    private func consumeA2RuminationAuthorizationScenarioForTesting(
        checkpoint: A2RuminationAuthorizationCheckpointForTesting,
        identity: RuminationPhaseIdentity,
        token: UUID,
        generation: Int
    ) throws {
        guard let armed =
            a2RuminationAuthorizationScenarioForTesting
        else {
            return
        }
        guard case let .inject(armedCheckpoint, loss) =
            armed.scenario,
              armedCheckpoint == checkpoint,
              armed.identity == identity
        else {
            return
        }
        a2RuminationAuthorizationScenarioForTesting = nil
        guard armed.token == token,
              armed.generation == generation,
              self.generation == generation,
              let entry = owned[identity.workId],
              entry.token == token,
              entry.generation == generation,
              entry.kind == .rumination,
              entry.aggregateType == "ingestion",
              entry.aggregateId == identity.ingestionId,
              entry.latestClaim.workId == identity.workId,
              entry.latestClaim.attempt == identity.attempt,
              entry.latestClaim.workerId == workerId,
              !entry.providerExited,
              entry.pendingTerminalProposal == nil,
              entry.pendingRuminationTerminalProposal == nil,
              entry.terminalCommitPermitted,
              !entry.terminalResolved
        else {
            throw InvalidDurableWorkStateError()
        }
        switch loss {
        case .fatal, .durableInvariantCorruption:
            throw InvalidDurableWorkStateError()
        case .durableReadFailure:
            throw DatabaseError(
                message:
                    "injected rumination authorization read failure"
            )
        case .lifecycle,
             .suppression,
             .generation,
             .token,
             .workId,
             .ingestion,
             .actorAttempt,
             .providerExited,
             .pendingProposal,
             .latestClaim,
             .durableMode,
             .durableWork,
             .durableKind,
             .durableAggregate,
             .durableCamp,
             .durableItem,
             .durableAttempt,
             .durableVersion,
             .durableLeaseOwner,
             .durableExpiry:
            throw RuminationPreParseAuthorizationLostError()
        }
    }
#endif

    private func isExpectedRuminationAuthorizationLoss(
        _ error: Error
    ) -> Bool {
        error is SupervisorGenerationExpiredError
            || error is StaleDurableWorkClaimError
            || error is RuminationDurableDispatchNotRunningError
            || error is RuminationPreParseAuthorizationLostError
            || error is CancellationError
    }

    private func loseRuminationOwnershipAfterInvalidation(
        workId: String,
        token: UUID
    ) async {
        guard var entry = owned[workId],
              entry.token == token,
              entry.kind == .rumination
        else {
            return
        }
        entry.terminalCommitPermitted = false
        entry.pendingRuminationTerminalProposal = nil
        entry.renewalTask?.cancel()
        entry.renewalTask = nil
        entry.providerTask?.cancel()
        owned[workId] = entry
        if entry.providerExited && fatalError == nil
            && !haltCleanupPending
        {
            owned.removeValue(forKey: workId)
        }
        await wakeIdleWaitersIfPossible()
    }

    private func handleRuminationAuthorizationFailure(
        _ error: Error,
        identity: RuminationPhaseIdentity,
        token: UUID,
        operation: String
    ) async throws {
        if fatalError != nil {
            await invalidateRuminationPhaseIfNeeded(
                identity: identity,
                reason: .globalFatal
            )
            await loseRuminationOwnershipAfterInvalidation(
                workId: identity.workId,
                token: token
            )
            throw RuminationPreParseAuthorizationLostError()
        }
        if isExpectedRuminationAuthorizationLoss(error) {
            await invalidateRuminationPhaseIfNeeded(
                identity: identity,
                reason: .controlLoss
            )
            await loseRuminationOwnershipAfterInvalidation(
                workId: identity.workId,
                token: token
            )
            throw RuminationPreParseAuthorizationLostError()
        }
        let code: SupervisorFatalCode =
            Self.isLifecycleInvariantError(error)
                ? .invalidLifecycle
                : .storeFailure
        let fatal = makeFatal(
            code,
            safeMessage: code == .invalidLifecycle
                ? "反刍持久化状态不满足生命周期不变量。"
                : "反刍持久化读取失败，派发已停止。"
        )
        logErrorType(
            error,
            operation: operation,
            workId: identity.workId,
            level: .fault
        )
        _ = await latchFatalAndInvalidateRumination(
            fatal,
            operation: operation,
            workId: identity.workId
        )
        throw RuminationPreParseAuthorizationLostError()
    }

    private func setRuminationPhaseForOwned(
        identity: RuminationPhaseIdentity,
        phase: RuminationPhase,
        token: UUID,
        generation: Int
    ) async throws {
        let entry: OwnedEntry
        do {
            entry = try validatedRuminationEntry(
                identity: identity,
                token: token,
                generation: generation
            )
            try database.validateRuminationPhaseOwnership(
                claim: entry.latestClaim,
                ingestionId: identity.ingestionId,
                now: now()
            )
        } catch {
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: token,
                operation: "rumination-phase-preflight"
            )
            return
        }
        do {
            try await emitRuminationPhase(
                identity: identity,
                phase: phase
            )
        } catch {
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: token,
                operation: "rumination-phase-delivery"
            )
            return
        }
        do {
            let current = try validatedRuminationEntry(
                identity: identity,
                token: token,
                generation: generation
            )
            try database.validateRuminationPhaseOwnership(
                claim: current.latestClaim,
                ingestionId: identity.ingestionId,
                now: now()
            )
        } catch {
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: token,
                operation: "rumination-phase-revalidate"
            )
        }
    }

    private func markOwnedProviderNeverStarted(
        workId: String,
        token: UUID
    ) async {
        guard var entry = owned[workId],
              entry.token == token
        else {
            return
        }
        entry.providerExited = true
        entry.providerTask = nil
        entry.renewalTask?.cancel()
        entry.renewalTask = nil
        owned[workId] = entry
        if !entry.terminalCommitPermitted {
            owned.removeValue(forKey: workId)
        }
        await wakeIdleWaitersIfPossible()
    }

    private func activeRuminationPhaseIdentities()
        -> [RuminationPhaseIdentity]
    {
        var identities = Set(
            ruminationPhaseCoordinators.compactMap {
                identity, coordinator in
                if coordinator.deliveredPhase != nil
                    || coordinator.setInFlight != nil
                    || coordinator.invalidationInFlight
                {
                    return identity
                }
                return nil
            }
        )
        for entry in owned.values where entry.kind == .rumination {
            guard entry.latestClaim.attempt >= 1 else {
                continue
            }
            identities.insert(
                requiredRuminationIdentity(for: entry)
            )
        }
        return identities.sorted {
            if $0.workId != $1.workId {
                return $0.workId < $1.workId
            }
            if $0.ingestionId != $1.ingestionId {
                return $0.ingestionId < $1.ingestionId
            }
            return $0.attempt < $1.attempt
        }
    }

    private func requiredRuminationIdentity(
        for entry: OwnedEntry
    ) -> RuminationPhaseIdentity {
        guard entry.kind == .rumination,
              entry.aggregateType == "ingestion",
              entry.latestClaim.attempt >= 1
        else {
            preconditionFailure(
                "invalid owned rumination identity"
            )
        }
        do {
            return try RuminationPhaseIdentity(
                ingestionId: entry.aggregateId,
                workId: entry.latestClaim.workId,
                attempt: entry.latestClaim.attempt
            )
        } catch {
            preconditionFailure(
                "invalid owned rumination identity payload"
            )
        }
    }

    private func revokeAllOwnedEntriesWithoutCancel() {
        for workId in owned.keys.sorted() {
            guard var entry = owned[workId] else {
                continue
            }
            entry.terminalCommitPermitted = false
            if entry.kind == .rumination,
               entry.latestClaim.attempt >= 1
            {
                let identity =
                    requiredRuminationIdentity(for: entry)
                var coordinator =
                    ruminationPhaseCoordinators[identity]
                    ?? RuminationPhaseCoordinator()
                coordinator.setRevoked = true
                ruminationPhaseCoordinators[identity] = coordinator
            }
            owned[workId] = entry
        }
    }

    private func cancelAllOwnedTasksAfterInvalidation() {
        for workId in owned.keys.sorted() {
            guard var entry = owned[workId] else {
                continue
            }
            entry.renewalTask?.cancel()
            entry.renewalTask = nil
            entry.providerTask?.cancel()
            owned[workId] = entry
        }
    }

    private func waitForFatalInvalidation() async {
        guard fatalInvalidationInFlight else {
            return
        }
        await withCheckedContinuation { continuation in
            if fatalInvalidationInFlight {
                fatalInvalidationWaiters.append(continuation)
            } else {
                continuation.resume()
            }
        }
    }

    @discardableResult
    private func latchFatalAndInvalidateRumination(
        _ fatal: SupervisorFatalError,
        operation: String,
        workId: String?
    ) async -> SupervisorFatalError {
        if let existing = fatalError {
            if fatalInvalidationInFlight {
                await waitForFatalInvalidation()
            }
            return existing
        }
        fatalError = fatal
        fatalInvalidationInFlight = true
        dispatchSuppressed = true
        let identities = activeRuminationPhaseIdentities()
        let (nextGeneration, overflow) =
            generation.addingReportingOverflow(1)
        if !overflow {
            generation = nextGeneration
        }
        revokeAllOwnedEntriesWithoutCancel()
        let invalidations = reserveRuminationPhaseInvalidations(
            identities: identities,
            reason: .globalFatal
        )
        await publishReservedRuminationPhaseInvalidations(
            invalidations
        )
        cancelPumpAndNextDue()
        cancelAllOwnedTasksAfterInvalidation()
        Self.logger.fault(
            "fatal code=\(fatal.code.rawValue, privacy: .public) operation=\(operation, privacy: .public) lifecycle=\(self.lifecycle.rawValue, privacy: .public) work=\(workId ?? "-", privacy: .private(mask: .hash))"
        )
        failOperationalWaiters(with: fatal)
        fatalInvalidationInFlight = false
        let waiters = fatalInvalidationWaiters
        fatalInvalidationWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        return fatal
    }

    private func advanceGeneration() async throws {
        let (next, overflow) = generation.addingReportingOverflow(1)
        guard !overflow else {
            let fatal = makeFatal(
                .generationOverflow,
                safeMessage: "规划监督器世代计数已耗尽。"
            )
            throw await latchFatalAndInvalidateRumination(
                fatal,
                operation: "advance-generation",
                workId: nil
            )
        }
        generation = next
    }

    private func launchPumpIfNeeded() {
        guard lifecycle == .running,
              !dispatchSuppressed,
              fatalError == nil,
              startProjectionBarriers.isEmpty,
              pumpTask == nil
        else {
            return
        }
        let token = UUID()
        let capturedGeneration = generation
        pumpToken = token
        pumpTask = Task {
            await self.runPump(
                token: token,
                generation: capturedGeneration
            )
        }
    }

    private func runPump(token: UUID, generation: Int) async {
        while isPumpCurrent(token: token, generation: generation) {
            if Task.isCancelled {
                await finishPump(token: token, generation: generation)
                return
            }
            guard startProjectionBarriers.isEmpty else {
                await finishPump(token: token, generation: generation)
                return
            }

            let claim: DurableWorkClaim?
            do {
                if ruminationEnabled {
                    claim = try database.claimNextSupervisedWork(
                        workerId: workerId,
                        now: now(),
                        leaseDuration: Self.leaseDuration
                    )
                } else {
                    try requireRuminationCompatibilitySafe()
                    claim = try database.claimNextPlanning(
                        workerId: workerId,
                        now: now(),
                        leaseDuration: Self.leaseDuration
                    )
                }
            } catch {
                switch await classifyDispatchPathError(
                    error,
                    operation: "claim",
                    workId: nil
                ) {
                case .stale:
                    await Task.yield()
                    continue
                case .halted, .retryable, .fatal:
                    await finishPump(
                        token: token,
                        generation: generation
                    )
                    return
                }
            }

            guard let claim else {
                await finishPumpAndScheduleNextDue(
                    token: token,
                    generation: generation
                )
                return
            }

            do {
                try await startOwnedAttempt(
                    claim: claim,
                    generation: generation
                )
            } catch {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage: "规划任务持久化输入已损坏。"
                )
                logErrorType(
                    error,
                    operation: "load-execution-input",
                    workId: claim.workId,
                    level: .fault
                )
                _ = await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "load-execution-input",
                    workId: claim.workId
                )
                await finishPump(
                    token: token,
                    generation: generation
                )
                return
            }

            await Task.yield()
        }
        await finishPump(token: token, generation: generation)
    }

    private func isPumpCurrent(token: UUID, generation: Int) -> Bool {
        lifecycle == .running
            && !dispatchSuppressed
            && fatalError == nil
            && startProjectionBarriers.isEmpty
            && self.generation == generation
            && pumpToken == token
    }

    private func finishPump(
        token: UUID,
        generation: Int
    ) async {
        guard pumpToken == token else {
            return
        }
        pumpToken = nil
        pumpTask = nil
        if self.generation == generation {
            await wakeIdleWaitersIfPossible()
        }
    }

    private func finishPumpAndScheduleNextDue(
        token: UUID,
        generation: Int
    ) async {
        guard pumpToken == token else {
            return
        }
        pumpToken = nil
        pumpTask = nil
        guard isLocallyDispatchable(generation: generation) else {
            await wakeIdleWaitersIfPossible()
            return
        }
        guard startProjectionBarriers.isEmpty else {
            await wakeIdleWaitersIfPossible()
            return
        }

        do {
            let due: Date?
            if ruminationEnabled {
                due = try database.nextClaimableSupervisedWorkDate(
                    now: now()
                )
            } else {
                due = try database.nextClaimablePlanningDate(now: now())
            }
            if let due {
                await scheduleNextDue(due)
            } else {
                cancelNextDueTimer()
            }
        } catch {
            switch await classifyDispatchPathError(
                error,
                operation: "next-due",
                workId: nil,
                staleIsExpected: false
            ) {
            case .stale:
                let fatal = makeFatal(
                    .storeFailure,
                    safeMessage: "读取下一条规划派发时间失败。"
                )
                _ = await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "next-due",
                    workId: nil
                )
            case .halted, .retryable, .fatal:
                break
            }
        }
        await wakeIdleWaitersIfPossible()
    }

    private func scheduleNextDue(_ due: Date) async {
        guard lifecycle == .running,
              !dispatchSuppressed,
              fatalError == nil,
              startProjectionBarriers.isEmpty
        else {
            return
        }
        if let existing = nextDueDate,
           existing <= due,
           nextDueTask != nil
        {
            return
        }

        cancelNextDueTimer()
        let token = UUID()
        let capturedGeneration = generation
        let interval = due.timeIntervalSince(now())
        guard interval.isFinite else {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "下一条规划派发时间无效。"
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "schedule-next-due",
                workId: nil
            )
            return
        }
        let delay = Duration.seconds(interval > 0 ? interval : 0)
        let sleep = self.sleep
        nextDueToken = token
        nextDueDate = due
        nextDueTask = Task.detached {
            do {
                try await sleep(delay)
            } catch is CancellationError {
                return
            } catch {
                await self.backgroundSleepFailed(
                    error,
                    operation: "next-due-sleep",
                    workId: nil,
                    token: token,
                    generation: capturedGeneration
                )
                return
            }
            await self.nextDueTimerFired(
                token: token,
                generation: capturedGeneration
            )
        }
    }

    private func nextDueTimerFired(token: UUID, generation: Int) {
        guard nextDueToken == token,
              startProjectionBarriers.isEmpty,
              isLocallyDispatchable(generation: generation)
        else {
            return
        }
        nextDueToken = nil
        nextDueDate = nil
        nextDueTask = nil
        launchPumpIfNeeded()
    }

    private func cancelNextDueTimer() {
        nextDueTask?.cancel()
        nextDueTask = nil
        nextDueToken = nil
        nextDueDate = nil
    }

    private func startOwnedAttempt(
        claim: DurableWorkClaim,
        generation: Int
    ) async throws {
        guard owned[claim.workId] == nil else {
            throw InvalidDurableWorkStateError()
        }
        let work = try requiredWork(id: claim.workId)
        let planningContext: ExecutionContext?
        let ruminationContext: RuminationExecutionContext?
        switch work.kind {
        case .planning:
            planningContext = try planningExecutionContext(for: claim)
            ruminationContext = nil
        case .rumination:
            guard ruminationEnabled else {
                throw RuminationRequiresDurableRuminationCapabilityError()
            }
            planningContext = nil
            ruminationContext = try database.ruminationExecutionContext(
                claim: claim,
                now: now()
            )
        default:
            throw InvalidDurableWorkStateError()
        }
        let token = UUID()

        owned[claim.workId] = OwnedEntry(
            token: token,
            generation: generation,
            kind: work.kind,
            aggregateType: work.aggregateType,
            aggregateId: work.aggregateId,
            latestClaim: claim,
            providerTask: nil,
            renewalTask: nil,
            terminalCommitPermitted: true,
            pendingTerminalProposal: nil,
            pendingRuminationTerminalProposal: nil,
            ruminationService: nil,
            providerExited: false,
            terminalResolved: false
        )

        let resolver = planningProviderResolver
        let providerTask: Task<Void, Never>
        if let planningContext {
            providerTask = Task.detached {
                let completion = await Self.executeProvider(
                    resolver: resolver,
                    context: planningContext
                )
                await self.providerCompleted(
                    workId: claim.workId,
                    token: token,
                    generation: generation,
                    completion: completion
                )
                await self.providerTaskExited(
                    workId: claim.workId,
                    token: token
                )
            }
        } else if let ruminationContext {
            let identity = try RuminationPhaseIdentity(
                ingestionId: ruminationContext.ingestion.id,
                workId: claim.workId,
                attempt: claim.attempt
            )
            do {
                try await setRuminationPhaseForOwned(
                    identity: identity,
                    phase: .reading,
                    token: token,
                    generation: generation
                )
            } catch is RuminationPreParseAuthorizationLostError {
                await markOwnedProviderNeverStarted(
                    workId: claim.workId,
                    token: token
                )
                return
            }
            providerTask = Task.detached {
                await Self.executeRuminationProvider(
                    resolver: resolver,
                    context: ruminationContext,
                    workId: claim.workId,
                    token: token,
                    generation: generation,
                    supervisor: self
                )
                await self.providerTaskExited(
                    workId: claim.workId,
                    token: token
                )
            }
        } else {
            throw InvalidDurableWorkStateError()
        }
        let sleep = self.sleep
        let renewalTask = Task.detached {
            while !Task.isCancelled {
                do {
                    try await sleep(Self.renewalInterval)
                } catch is CancellationError {
                    return
                } catch {
                    await self.backgroundSleepFailed(
                        error,
                        operation: "lease-renewal-sleep",
                        workId: claim.workId,
                        token: token,
                        generation: generation
                    )
                    return
                }
                guard !Task.isCancelled else {
                    return
                }
                guard await self.renewalTimerFired(
                    workId: claim.workId,
                    token: token,
                    generation: generation
                ) else {
                    return
                }
            }
        }

        guard var entry = owned[claim.workId],
              entry.token == token
        else {
            providerTask.cancel()
            renewalTask.cancel()
            throw SupervisorGenerationExpiredError(workId: claim.workId)
        }
        entry.providerTask = providerTask
        entry.renewalTask = renewalTask
        owned[claim.workId] = entry
    }

    private func planningExecutionContext(
        for claim: DurableWorkClaim
    ) throws -> ExecutionContext {
        let work = try requiredWork(id: claim.workId)
        guard work.kind == .planning,
              work.aggregateType == "mission",
              work.state == .running,
              work.attempt == claim.attempt,
              work.version == claim.version,
              work.leaseOwner == claim.workerId,
              work.leaseExpiresAt == claim.leaseExpiresAt
        else {
            throw InvalidDurableWorkStateError()
        }

        let rawInput = Data(work.inputJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: rawInput)
        guard CanonicalJSONV1.sha256Hex(rawInput) == work.inputHash else {
            throw DurableWorkInputHashMismatchError()
        }
        let planningInput = try JSONDecoder().decode(
            PlanningWorkInput.self,
            from: rawInput
        )
        guard try CanonicalJSONV1.encode(planningInput) == rawInput else {
            throw CanonicalJSONNotCanonicalError()
        }

        guard let mission = try database.mission(id: work.aggregateId),
              mission.status == .planning,
              let squad = try database.squad(forMission: mission.id),
              squad.id == mission.squadId,
              squad.campId == work.campId
        else {
            throw InvalidDurableWorkStateError()
        }
        let companionIds = try JSONDecoder().decode(
            [String].self,
            from: Data(squad.memberIdsJson.utf8)
        )
        let roster = try database.companions(ids: companionIds)
        guard roster.map(\.id) == companionIds else {
            throw InvalidDurableWorkStateError()
        }
        let notes = try database.pinnedAndRecentCampNotes(
            campId: squad.campId
        )
        return ExecutionContext(
            planningInput: planningInput,
            goal: mission.goalRaw,
            roster: roster,
            workspacePath: squad.workspacePath,
            campNotes: NoteSnippet.from(
                pinned: notes.pinned,
                recent: notes.recent
            )
        )
    }

    private static func executeProvider(
        resolver: any PlanningProviderResolver,
        context: ExecutionContext
    ) async -> ProviderCompletion {
        do {
            try Task.checkCancellation()
            let provider = try resolver.resolvePlanningProvider(
                profileId: context.planningInput.runtimeProfileId,
                model: context.planningInput.plannerModel
            )
            try Task.checkCancellation()
            let result = try await Planner(provider: provider).proposeDurable(
                goal: context.goal,
                roster: context.roster,
                workspacePath: context.workspacePath,
                campNotes: context.campNotes
            )
            return .proposal(.success(result))
        } catch is CancellationError {
            return .canceled
        } catch let error as PlanningProviderResolutionError {
            do {
                return .proposal(
                    .failure(
                        try PlanningAttemptFailure(
                            code: error.code,
                            safeMessage: error.safeMessage,
                            disposition: .deterministic,
                            usage: nil
                        )
                    )
                )
            } catch {
                return .invalidLifecycle
            }
        } catch let error as PlanningAttemptFailure {
            return .proposal(.failure(error))
        } catch let error as UsageOverflowError {
            return .proposal(.usageOverflow(error.evidence))
        } catch {
            return .invalidLifecycle
        }
    }

    private static func ruminationResolutionFailure(
        _ error: PlanningProviderResolutionError
    ) throws -> RuminationAttemptFailure {
        let mapped: (String, String)
        switch error.code {
        case "runtime_profile_not_found":
            mapped = (
                "rumination_profile_not_found",
                "反刍所用运行配置不存在。"
            )
        case "model_catalog_unavailable":
            mapped = (
                "rumination_model_catalog_unavailable",
                "反刍所用模型目录不可用。"
            )
        case "planning_model_unsupported":
            mapped = (
                "rumination_model_unsupported",
                "反刍所用模型不受该运行配置支持。"
            )
        case "credential_account_missing":
            mapped = (
                "rumination_credential_account_missing",
                "反刍运行配置缺少凭据账户。"
            )
        case "credential_not_found":
            mapped = (
                "rumination_credential_not_found",
                "反刍所需凭据不存在。"
            )
        case "credential_read_failed":
            mapped = (
                "rumination_credential_read_failed",
                "反刍所需凭据读取失败。"
            )
        case "endpoint_invalid":
            mapped = (
                "rumination_endpoint_invalid",
                "反刍运行配置的服务地址无效。"
            )
        case "provider_construction_failed":
            mapped = (
                "rumination_provider_construction_failed",
                "反刍服务初始化失败。"
            )
        case "oauth_account_id_not_found":
            mapped = (
                "rumination_oauth_account_id_not_found",
                "反刍所需 OAuth 账户信息不存在。"
            )
        case "oauth_account_id_read_failed":
            mapped = (
                "rumination_oauth_account_id_read_failed",
                "反刍所需 OAuth 账户信息读取失败。"
            )
        case "planning_profile_cli_unsupported":
            mapped = (
                "rumination_profile_cli_unsupported",
                "当前 CLI 运行配置不支持耐久反刍。"
            )
        default:
            throw InvalidDurableWorkStateError()
        }
        return try RuminationAttemptFailure(
            code: mapped.0,
            safeMessage: mapped.1,
            disposition: .deterministic,
            usage: nil
        )
    }

    private static func ruminationProviderFailure(
        _ error: Error
    ) throws -> RuminationAttemptFailure {
        let code: String
        let safeMessage: String
        let disposition: DurableWorkFailureDisposition
        if error is URLError {
            code = "rumination_transport_error"
            safeMessage = "反刍服务网络连接失败。"
            disposition = .transient
        } else if error
            is InvalidRuminationPayloadError
        {
            code = "rumination_usage_invalid"
            safeMessage = "反刍用量数据无效。"
            disposition = .deterministic
        } else if let providerError = error as? ProviderError {
            switch providerError {
            case let .http(status, _)
                where status == 408
                    || status == 429
                    || (500...599).contains(status):
                code = "rumination_provider_unavailable"
                safeMessage = "反刍服务暂时不可用。"
                disposition = .transient
            case .overloadedRetriesExhausted:
                code = "rumination_provider_unavailable"
                safeMessage = "反刍服务暂时不可用。"
                disposition = .transient
            case let .apiError(type, _)
                where type == "overloaded_error"
                    || type == "rate_limit_error"
                    || type == "server_error":
                code = "rumination_provider_unavailable"
                safeMessage = "反刍服务暂时不可用。"
                disposition = .transient
            case .malformedStream:
                code = "rumination_provider_malformed_response"
                safeMessage = "反刍服务返回了无效响应。"
                disposition = .transient
            case .unauthorized:
                code = "rumination_provider_unauthorized"
                safeMessage = "反刍服务认证失败。"
                disposition = .deterministic
            case .http:
                code = "rumination_provider_http_error"
                safeMessage = "反刍服务请求失败。"
                disposition = .deterministic
            case .apiError:
                code = "rumination_provider_api_error"
                safeMessage = "反刍服务返回错误。"
                disposition = .deterministic
            }
        } else {
            code = "rumination_provider_failed"
            safeMessage = "反刍服务执行失败。"
            disposition = .deterministic
        }
        return try RuminationAttemptFailure(
            code: code,
            safeMessage: safeMessage,
            disposition: disposition,
            usage: nil
        )
    }

    private static func executeRuminationProvider(
        resolver: any PlanningProviderResolver,
        context: RuminationExecutionContext,
        workId: String,
        token: UUID,
        generation: Int,
        supervisor: DurableWorkSupervisor
    ) async {
        let provider: any LLMProvider
        do {
            try Task.checkCancellation()
            provider = try resolver.resolvePlanningProvider(
                profileId: context.input.runtimeProfileId,
                model: context.input.model
            )
        } catch is CancellationError {
            await supervisor.ruminationProviderCanceled(
                workId: workId,
                token: token,
                generation: generation
            )
            return
        } catch let error as PlanningProviderResolutionError {
            do {
                let failure = try ruminationResolutionFailure(error)
                try await supervisor.acceptRuminationProviderFailure(
                    workId: workId,
                    token: token,
                    generation: generation,
                    failure: failure
                )
            } catch is RuminationPreParseAuthorizationLostError {
                return
            } catch {
                await supervisor.ruminationProviderInvariantFailed(
                    error,
                    workId: workId
                )
            }
            return
        } catch {
            await supervisor.ruminationResolverInvariantFailed(
                error,
                workId: workId
            )
            return
        }

        let service = RuminationService(provider: provider)
        do {
            try await supervisor.bindRuminationServiceAndSetExtracting(
                service,
                workId: workId,
                ingestionId: context.ingestion.id,
                attempt: context.claim.attempt,
                token: token,
                generation: generation
            )
        } catch is RuminationPreParseAuthorizationLostError {
            return
        } catch let fatal as SupervisorFatalError {
            await supervisor.ruminationSupervisorFatalObserved(fatal)
            return
        } catch {
            await supervisor.ruminationProviderInvariantFailed(
                error,
                workId: workId
            )
            return
        }

        let turn: RuminationValidatedTurn
        do {
            turn = try await service.produceValidatedTurn(
                ingestion: context.ingestion
            )
        } catch is CancellationError {
            await supervisor.ruminationProviderCanceled(
                workId: workId,
                token: token,
                generation: generation
            )
            return
        } catch {
            do {
                let failure = try ruminationProviderFailure(error)
                try await supervisor.acceptRuminationProviderFailure(
                    workId: workId,
                    token: token,
                    generation: generation,
                    failure: failure
                )
            } catch is RuminationPreParseAuthorizationLostError {
                return
            } catch let fatal as SupervisorFatalError {
                await supervisor.ruminationSupervisorFatalObserved(
                    fatal
                )
            } catch {
                await supervisor.ruminationProviderInvariantFailed(
                    error,
                    workId: workId
                )
            }
            return
        }

        do {
            try await supervisor.handleValidatedRuminationTurn(
                workId: workId,
                attempt: context.claim.attempt,
                ownershipToken: token,
                generation: generation,
                turn: turn
            )
        } catch is RuminationPreParseAuthorizationLostError {
            return
        } catch let fatal as SupervisorFatalError {
            await supervisor.ruminationSupervisorFatalObserved(fatal)
        } catch {
            await supervisor.ruminationProviderInvariantFailed(
                error,
                workId: workId
            )
        }
    }

    private func bindRuminationServiceAndSetExtracting(
        _ service: RuminationService,
        workId: String,
        ingestionId: String,
        attempt: Int,
        token: UUID,
        generation: Int
    ) async throws {
        let identity = try RuminationPhaseIdentity(
            ingestionId: ingestionId,
            workId: workId,
            attempt: attempt
        )
        _ = try validatedRuminationEntry(
            identity: identity,
            token: token,
            generation: generation
        )
        guard var entry = owned[workId],
              entry.token == token,
              entry.generation == generation
        else {
            throw RuminationPreParseAuthorizationLostError()
        }
        entry.ruminationService = service
        owned[workId] = entry
        try await setRuminationPhaseForOwned(
            identity: identity,
            phase: .extracting,
            token: token,
            generation: generation
        )
    }

    private func handleValidatedRuminationTurn(
        workId: String,
        attempt: Int,
        ownershipToken: UUID,
        generation: Int,
        turn: RuminationValidatedTurn
    ) async throws {
        var authorizationIdentity: RuminationPhaseIdentity?
        let first: OwnedEntry
        let identity: RuminationPhaseIdentity
        do {
            let validated = try validatedRuminationHandlerEntry(
                workId: workId,
                attempt: attempt,
                token: ownershipToken,
                generation: generation
            )
            first = validated.entry
            identity = validated.identity
            authorizationIdentity = identity
            try database.validateRuminationPhaseOwnership(
                claim: first.latestClaim,
                ingestionId: identity.ingestionId,
                now: now()
            )
#if DEBUG
            try consumeA2RuminationAuthorizationScenarioForTesting(
                checkpoint: .first,
                identity: identity,
                token: ownershipToken,
                generation: generation
            )
#endif
        } catch {
            guard let failedIdentity =
                authorizationIdentity
                    ?? recoverRuminationPhaseIdentity(
                        workId: workId,
                        attempt: attempt
                    )
            else {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage:
                        "反刍解析前无法恢复唯一的运行身份。"
                )
                _ = await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "rumination-pre-parse-identity",
                    workId: workId
                )
                throw RuminationPreParseAuthorizationLostError()
            }
            try await handleRuminationAuthorizationFailure(
                error,
                identity: failedIdentity,
                token: ownershipToken,
                operation: "rumination-pre-organizing"
            )
            return
        }
        do {
            try await emitRuminationPhase(
                identity: identity,
                phase: .organizing
            )
        } catch {
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: ownershipToken,
                operation: "rumination-organizing-delivery"
            )
            return
        }

        let current: OwnedEntry
        do {
            let validated = try validatedRuminationHandlerEntry(
                workId: workId,
                attempt: attempt,
                token: ownershipToken,
                generation: generation
            )
            guard validated.identity == identity else {
                throw SupervisorGenerationExpiredError(
                    workId: workId
                )
            }
            current = validated.entry
            try database.validateRuminationPhaseOwnership(
                claim: current.latestClaim,
                ingestionId: identity.ingestionId,
                now: now()
            )
#if DEBUG
            try consumeA2RuminationAuthorizationScenarioForTesting(
                checkpoint: .second,
                identity: identity,
                token: ownershipToken,
                generation: generation
            )
#endif
        } catch {
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: ownershipToken,
                operation: "rumination-pre-parse"
            )
            return
        }
        guard let service = current.ruminationService else {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "反刍解析器缺少对应的已验证 Provider。"
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "rumination-parse-service",
                workId: workId
            )
            throw RuminationPreParseAuthorizationLostError()
        }
        let proposal: RuminationTerminalProposal
        do {
            proposal = .success(
                try service.parseValidatedTurn(turn)
            )
        } catch is RuminationParseError {
            proposal = .failure(
                try RuminationAttemptFailure(
                    code: "rumination_contract_invalid",
                    safeMessage: "反刍结果格式无效。",
                    disposition: .deterministic,
                    usage: turn.usage
                )
            )
        } catch {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "反刍解析器返回了未分类错误。"
            )
            logErrorType(
                error,
                operation: "rumination-parse",
                workId: workId,
                level: .fault
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "rumination-parse",
                workId: workId
            )
            throw RuminationPreParseAuthorizationLostError()
        }
        try await acceptRuminationProposal(
            workId: workId,
            token: ownershipToken,
            generation: generation,
            proposal: proposal
        )
    }

    private func acceptRuminationProviderFailure(
        workId: String,
        token: UUID,
        generation: Int,
        failure: RuminationAttemptFailure
    ) async throws {
        try await acceptRuminationProposal(
            workId: workId,
            token: token,
            generation: generation,
            proposal: .failure(failure)
        )
    }

    private func acceptRuminationProposal(
        workId: String,
        token: UUID,
        generation: Int,
        proposal: RuminationTerminalProposal
    ) async throws {
        guard let entry = owned[workId],
              entry.kind == .rumination
        else {
            throw RuminationPreParseAuthorizationLostError()
        }
        let identity = try RuminationPhaseIdentity(
            ingestionId: entry.aggregateId,
            workId: workId,
            attempt: entry.latestClaim.attempt
        )
        do {
            _ = try validatedRuminationEntry(
                identity: identity,
                token: token,
                generation: generation
            )
        } catch {
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: token,
                operation: "rumination-provider-terminal"
            )
            return
        }
        guard var current = owned[workId],
              current.token == token,
              current.generation == generation
        else {
            throw RuminationPreParseAuthorizationLostError()
        }
        current.pendingRuminationTerminalProposal = proposal
        owned[workId] = current
        try await attemptPendingRuminationTerminalProposal(
            workId: workId,
            token: token,
            generation: generation
        )
    }

    private func attemptPendingRuminationTerminalProposal(
        workId: String,
        token: UUID,
        generation: Int
    ) async throws {
        let entry: OwnedEntry
        do {
            entry = try validatedEntry(
                workId: workId,
                token: token,
                generation: generation
            )
        } catch {
            guard let stale = owned[workId],
                  stale.kind == .rumination
            else {
                throw RuminationPreParseAuthorizationLostError()
            }
            let identity = try RuminationPhaseIdentity(
                ingestionId: stale.aggregateId,
                workId: workId,
                attempt: stale.latestClaim.attempt
            )
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: token,
                operation: "rumination-terminal-validate"
            )
            return
        }
        guard entry.kind == .rumination,
              let proposal =
                entry.pendingRuminationTerminalProposal
        else {
            return
        }

        do {
            let resultingWork: DurableWorkRecord
            let disposition: CommitDisposition
            switch proposal {
            case let .success(production):
                resultingWork =
                    try database.commitRuminationSuccess(
                        claim: entry.latestClaim,
                        production: production,
                        now: now()
                    )
                disposition = .terminal
            case let .failure(failure):
                switch try database.recordRuminationAttemptFailure(
                    claim: entry.latestClaim,
                    failure: failure,
                    now: now()
                ) {
                case let .retryScheduled(work, notBefore):
                    resultingWork = work
                    disposition = .retryScheduled(notBefore)
                case let .failed(work):
                    resultingWork = work
                    disposition = .terminal
                }
            }
            let phaseIdentity = try RuminationPhaseIdentity(
                ingestionId: entry.aggregateId,
                workId: workId,
                attempt: resultingWork.attempt
            )
            let projection =
                try RuminationProjectionCommitIdentity(
                    phaseIdentity: phaseIdentity,
                    workVersion: resultingWork.version
                )
            let reservation =
                try reserveRuminationProjectionCommit(
                    projection,
                    revokePhase: true
                )
            try await publishReservedRuminationProjection(
                projection,
                reservation: reservation
            )
            await finishCommittedRuminationProposal(
                workId: workId,
                token: token,
                disposition: disposition
            )
        } catch let error as DatabaseError {
            logErrorType(
                error,
                operation: "rumination-terminal-commit-retained",
                workId: workId,
                level: .error
            )
        } catch let error
            as RuminationDurableDispatchNotRunningError
        {
            let identity = try RuminationPhaseIdentity(
                ingestionId: entry.aggregateId,
                workId: workId,
                attempt: entry.latestClaim.attempt
            )
            try await handleRuminationAuthorizationFailure(
                error,
                identity: identity,
                token: token,
                operation: "rumination-terminal-halted"
            )
        } catch is StaleDurableWorkClaimError {
            let identity = try RuminationPhaseIdentity(
                ingestionId: entry.aggregateId,
                workId: workId,
                attempt: entry.latestClaim.attempt
            )
            try await handleRuminationAuthorizationFailure(
                StaleDurableWorkClaimError(),
                identity: identity,
                token: token,
                operation: "rumination-terminal-stale"
            )
        } catch {
            let code: SupervisorFatalCode =
                Self.isLifecycleInvariantError(error)
                    ? .invalidLifecycle
                    : .storeFailure
            let fatal = makeFatal(
                code,
                safeMessage: code == .invalidLifecycle
                    ? "反刍终态事务检测到损坏的生命周期状态。"
                    : "反刍终态事务失败，派发已停止。"
            )
            logErrorType(
                error,
                operation: "rumination-terminal-commit",
                workId: workId,
                level: .fault
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "rumination-terminal-commit",
                workId: workId
            )
            throw fatal
        }
    }

    private func finishCommittedRuminationProposal(
        workId: String,
        token: UUID,
        disposition: CommitDisposition
    ) async {
        guard var entry = owned[workId],
              entry.token == token,
              entry.kind == .rumination
        else {
            return
        }
        entry.pendingRuminationTerminalProposal = nil
        entry.terminalCommitPermitted = false
        entry.terminalResolved = true
        entry.renewalTask?.cancel()
        entry.renewalTask = nil
        entry.providerTask?.cancel()
        owned[workId] = entry
        switch disposition {
        case .terminal:
            wakeTerminalWaiters(workId: workId)
        case let .retryScheduled(notBefore):
            await scheduleNextDue(notBefore)
        }
        if entry.providerExited {
            owned.removeValue(forKey: workId)
        }
        await wakeIdleWaitersIfPossible()
    }

    private func finishCommittedRuminationControl(
        workId: String
    ) async {
        if var entry = owned[workId] {
            guard entry.kind == .rumination else {
                preconditionFailure(
                    "rumination control matched non-rumination owner"
                )
            }
            entry.terminalCommitPermitted = false
            entry.pendingRuminationTerminalProposal = nil
            entry.terminalResolved = true
            entry.renewalTask?.cancel()
            entry.renewalTask = nil
            entry.providerTask?.cancel()
            owned[workId] = entry
            if entry.providerExited {
                owned.removeValue(forKey: workId)
            }
        }
        wakeTerminalWaiters(workId: workId)
        await wakeIdleWaitersIfPossible()
    }

    private func ruminationProviderCanceled(
        workId: String,
        token: UUID,
        generation: Int
    ) async {
        guard let entry = owned[workId],
              entry.kind == .rumination
        else {
            return
        }
        let identity = requiredRuminationIdentity(for: entry)
        do {
            _ = try validatedRuminationEntry(
                identity: identity,
                token: token,
                generation: generation
            )
        } catch {
            await invalidateRuminationPhaseIfNeeded(
                identity: identity,
                reason: .controlLoss
            )
            return
        }
        let fatal = makeFatal(
            .invalidLifecycle,
            safeMessage: "反刍 Provider 在有效所有权期间意外取消。"
        )
        _ = await latchFatalAndInvalidateRumination(
            fatal,
            operation: "rumination-provider-canceled",
            workId: workId
        )
    }

    private func ruminationResolverInvariantFailed(
        _ error: Error,
        workId: String
    ) async {
        let fatal = makeFatal(
            .invalidLifecycle,
            safeMessage: "反刍运行配置解析返回了未知错误。"
        )
        logErrorType(
            error,
            operation: "rumination-resolver",
            workId: workId,
            level: .fault
        )
        _ = await latchFatalAndInvalidateRumination(
            fatal,
            operation: "rumination-resolver",
            workId: workId
        )
    }

    private func ruminationSupervisorFatalObserved(
        _ fatal: SupervisorFatalError
    ) async {
        _ = await latchFatalAndInvalidateRumination(
            fatal,
            operation: "rumination-supervisor-fatal-observed",
            workId: nil
        )
    }

    private func ruminationProviderInvariantFailed(
        _ error: Error,
        workId: String
    ) async {
        let fatal = makeFatal(
            .invalidLifecycle,
            safeMessage: "反刍 Provider 结果无法转换为持久终态。"
        )
        logErrorType(
            error,
            operation: "rumination-provider-result",
            workId: workId,
            level: .fault
        )
        _ = await latchFatalAndInvalidateRumination(
            fatal,
            operation: "rumination-provider-result",
            workId: workId
        )
    }

    private func providerCompleted(
        workId: String,
        token: UUID,
        generation: Int,
        completion: ProviderCompletion
    ) async {
        do {
            _ = try validatedEntry(
                workId: workId,
                token: token,
                generation: generation
            )
        } catch {
            logExpectedOwnershipLoss(
                operation: "provider-completed",
                workId: workId
            )
            return
        }

        switch completion {
        case .canceled:
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "规划 Provider 在有效所有权期间意外取消。"
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "provider-canceled",
                workId: workId
            )
        case .invalidLifecycle:
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "规划 Provider 返回了未映射的结果。"
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "provider-result",
                workId: workId
            )
        case let .proposal(proposal):
            do {
                try await acceptProviderProposal(
                    workId: workId,
                    token: token,
                    generation: generation,
                    proposal: proposal
                )
            } catch is SupervisorGenerationExpiredError {
                logExpectedOwnershipLoss(
                    operation: "provider-terminal",
                    workId: workId
                )
            } catch {
                logErrorType(
                    error,
                    operation: "provider-terminal",
                    workId: workId,
                    level: .error
                )
            }
        }
    }

    private func acceptProviderProposal(
        workId: String,
        token: UUID,
        generation: Int,
        proposal: PlanningTerminalProposal
    ) async throws {
        _ = try validatedEntry(
            workId: workId,
            token: token,
            generation: generation
        )
        guard var entry = owned[workId],
              entry.token == token,
              entry.generation == generation
        else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        entry.pendingTerminalProposal = proposal
        owned[workId] = entry
        try await attemptPendingTerminalProposal(
            workId: workId,
            token: token,
            generation: generation
        )
    }

    private func providerTaskExited(
        workId: String,
        token: UUID
    ) async {
        guard var entry = owned[workId],
              entry.token == token
        else {
            return
        }
        entry.providerExited = true
        entry.providerTask = nil
        owned[workId] = entry

        if fatalError == nil,
           !haltCleanupPending,
           entry.pendingTerminalProposal == nil,
           entry.pendingRuminationTerminalProposal == nil,
           (!entry.terminalCommitPermitted || entry.terminalResolved)
        {
            entry.renewalTask?.cancel()
            owned.removeValue(forKey: workId)
        }

        do {
            try refreshTerminalWaitersFromStore(workId: workId)
        } catch {
            _ = await latchReadFailure(
                error,
                operation: "provider-exited-terminal-read",
                workId: workId
            )
        }
        await wakeIdleWaitersIfPossible()
        finishShutdownIfProvidersExited()
    }

    private func renewalTimerFired(
        workId: String,
        token: UUID,
        generation: Int
    ) async -> Bool {
        let entry: OwnedEntry
        do {
            entry = try validatedEntry(
                workId: workId,
                token: token,
                generation: generation
            )
        } catch {
            return false
        }

        do {
            let renewed: DurableWorkClaim
            switch entry.kind {
            case .planning:
                renewed = try database.renewPlanningLease(
                    claim: entry.latestClaim,
                    now: now(),
                    leaseDuration: Self.leaseDuration
                )
            case .rumination:
                renewed = try database.renewRuminationLease(
                    claim: entry.latestClaim,
                    now: now(),
                    leaseDuration: Self.leaseDuration
                )
            default:
                throw InvalidDurableWorkStateError()
            }
            guard var current = owned[workId],
                  current.token == token,
                  current.generation == generation
            else {
                return false
            }
            current.latestClaim = renewed
            owned[workId] = current

            if current.pendingTerminalProposal != nil {
                do {
                    try await attemptPendingTerminalProposal(
                        workId: workId,
                        token: token,
                        generation: generation
                    )
                } catch is SupervisorGenerationExpiredError {
                    return false
                } catch {
                    logErrorType(
                        error,
                        operation: "terminal-after-renew",
                        workId: workId,
                        level: .error
                    )
                }
            }
            if current.pendingRuminationTerminalProposal != nil {
                do {
                    try await
                        attemptPendingRuminationTerminalProposal(
                            workId: workId,
                            token: token,
                            generation: generation
                        )
                } catch is
                    RuminationPreParseAuthorizationLostError
                {
                    return false
                } catch {
                    logErrorType(
                        error,
                        operation:
                            "rumination-terminal-after-renew",
                        workId: workId,
                        level: .error
                    )
                }
            }
            guard let latest = owned[workId] else {
                return false
            }
            return latest.token == token
                && latest.generation == generation
                && latest.terminalCommitPermitted
        } catch {
            if entry.kind == .rumination {
                let identity: RuminationPhaseIdentity
                do {
                    identity = try RuminationPhaseIdentity(
                        ingestionId: entry.aggregateId,
                        workId: workId,
                        attempt: entry.latestClaim.attempt
                    )
                } catch {
                    let fatal = makeFatal(
                        .invalidLifecycle,
                        safeMessage: "反刍租约身份已损坏。"
                    )
                    _ = await latchFatalAndInvalidateRumination(
                        fatal,
                        operation: "rumination-renew-identity",
                        workId: workId
                    )
                    return false
                }
                do {
                    try await handleRuminationAuthorizationFailure(
                        error,
                        identity: identity,
                        token: token,
                        operation: "rumination-renew"
                    )
                } catch {
                    return false
                }
                return false
            }
            switch await classifyDispatchPathError(
                error,
                operation: "renew",
                workId: workId
            ) {
            case .stale:
                await loseOwnership(workId: workId, token: token)
            case .halted, .retryable, .fatal:
                break
            }
            return false
        }
    }

    private func retryPendingTerminalProposals() async throws {
        for workId in owned.keys.sorted() {
            guard let entry = owned[workId] else {
                continue
            }
            if entry.pendingTerminalProposal != nil {
                try await attemptPendingTerminalProposal(
                    workId: workId,
                    token: entry.token,
                    generation: entry.generation
                )
            } else if entry
                .pendingRuminationTerminalProposal != nil
            {
                try await
                    attemptPendingRuminationTerminalProposal(
                        workId: workId,
                        token: entry.token,
                        generation: entry.generation
                    )
            } else {
                continue
            }
            try requireDispatchable()
        }
    }

    private func attemptPendingTerminalProposal(
        workId: String,
        token: UUID,
        generation: Int
    ) async throws {
        let entry = try validatedEntry(
            workId: workId,
            token: token,
            generation: generation
        )
        guard let proposal = entry.pendingTerminalProposal else {
            return
        }

        do {
            let disposition: CommitDisposition
            switch proposal {
            case let .success(result):
                switch try database.commitPlanningSuccess(
                    claim: entry.latestClaim,
                    result: result,
                    now: now()
                ) {
                case .succeeded:
                    disposition = .terminal
                case .usageOverflow:
                    disposition = .terminal
                }
            case let .failure(failure):
                switch try database.recordPlanningAttemptFailure(
                    claim: entry.latestClaim,
                    failure: failure,
                    now: now()
                ) {
                case let .retryScheduled(_, notBefore):
                    disposition = .retryScheduled(notBefore)
                case .failed, .usageOverflow:
                    disposition = .terminal
                }
            case let .usageOverflow(evidence):
                _ = try database.recordPlanningUsageOverflow(
                    claim: entry.latestClaim,
                    evidence: evidence,
                    now: now()
                )
                disposition = .terminal
            }
            await finishCommittedProposal(
                workId: workId,
                token: token,
                disposition: disposition
            )
        } catch is UnexpectedPlanningFallbackError {
            guard case let .success(result) = proposal else {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage: "规划终态校验返回了不匹配的错误。"
                )
                throw await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "unexpected-fallback",
                    workId: workId
                )
            }
            let failure: PlanningAttemptFailure
            do {
                failure = try PlanningAttemptFailure(
                    code: "unexpected_planning_fallback",
                    safeMessage: "规划器返回了不允许的兜底结果。",
                    disposition: .deterministic,
                    usage: result.usage
                )
            } catch {
                let fatal = makeFatal(
                    .invalidLifecycle,
                    safeMessage: "规划兜底结果无法转换为持久失败。"
                )
                logErrorType(
                    error,
                    operation: "convert-unexpected-fallback",
                    workId: workId,
                    level: .fault
                )
                throw await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "convert-unexpected-fallback",
                    workId: workId
                )
            }
            guard var current = owned[workId],
                  current.token == token,
                  current.generation == generation
            else {
                throw SupervisorGenerationExpiredError(workId: workId)
            }
            current.pendingTerminalProposal = .failure(failure)
            owned[workId] = current
            try await attemptPendingTerminalProposal(
                workId: workId,
                token: token,
                generation: generation
            )
        } catch {
            switch await classifyTerminalCommitError(
                error,
                workId: workId,
                token: token
            ) {
            case .stale:
                return
            case .halted:
                throw SupervisorDispatchSuppressedError()
            case .retryable:
                throw error
            case let .fatal(fatal):
                throw fatal
            }
        }
    }

    private func finishCommittedProposal(
        workId: String,
        token: UUID,
        disposition: CommitDisposition
    ) async {
        guard var entry = owned[workId],
              entry.token == token
        else {
            return
        }
        entry.pendingTerminalProposal = nil
        entry.terminalCommitPermitted = false
        entry.terminalResolved = true
        entry.renewalTask?.cancel()
        entry.renewalTask = nil
        owned[workId] = entry

        switch disposition {
        case .terminal:
            wakeTerminalWaiters(workId: workId)
        case let .retryScheduled(notBefore):
            await scheduleNextDue(notBefore)
        }
        guard entry.kind == .planning else {
            preconditionFailure(
                "planning proposal committed for non-planning work"
            )
        }
        onMissionChanged(entry.aggregateId)

        if entry.providerExited {
            owned.removeValue(forKey: workId)
        }
        await wakeIdleWaitersIfPossible()
    }

    private func validatedEntry(
        workId: String,
        token: UUID,
        generation: Int
    ) throws -> OwnedEntry {
        guard lifecycle == .running,
              !dispatchSuppressed,
              fatalError == nil,
              self.generation == generation,
              let entry = owned[workId],
              entry.token == token,
              entry.generation == generation,
              entry.terminalCommitPermitted,
              entry.latestClaim.workId == workId,
              entry.latestClaim.workerId == workerId
        else {
            throw SupervisorGenerationExpiredError(workId: workId)
        }
        return entry
    }

    private func loseOwnership(
        workId: String,
        token: UUID
    ) async {
        guard var entry = owned[workId],
              entry.token == token
        else {
            return
        }
        entry.terminalCommitPermitted = false
        entry.pendingTerminalProposal = nil
        entry.renewalTask?.cancel()
        entry.renewalTask = nil
        entry.providerTask?.cancel()
        owned[workId] = entry
        if entry.providerExited && fatalError == nil && !haltCleanupPending {
            owned.removeValue(forKey: workId)
        }
        do {
            try refreshTerminalWaitersFromStore(workId: workId)
        } catch {
            _ = await latchReadFailure(
                error,
                operation: "ownership-loss-terminal-read",
                workId: workId
            )
        }
        await wakeIdleWaitersIfPossible()
    }

    private func handleCommittedControlTerminal(
        workId: String,
        missionId: String
    ) async {
        if var entry = owned[workId] {
            entry.terminalCommitPermitted = false
            entry.pendingTerminalProposal = nil
            entry.terminalResolved = true
            entry.renewalTask?.cancel()
            entry.renewalTask = nil
            entry.providerTask?.cancel()
            owned[workId] = entry
            if entry.providerExited {
                owned.removeValue(forKey: workId)
            }
        }
        wakeTerminalWaiters(workId: workId)
        onMissionChanged(missionId)
        await wakeIdleWaitersIfPossible()
    }

    private func classifyDispatchPathError(
        _ error: Error,
        operation: String,
        workId: String?,
        staleIsExpected: Bool = true
    ) async -> DispatchErrorDisposition {
        do {
            if try database.dispatchMode() == .halted {
                await suppressAfterObservedDurableHalt(
                    operation: operation,
                    workId: workId
                )
                return .halted
            }
        } catch {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "持久化派发控制记录缺失或损坏。"
            )
            logErrorType(
                error,
                operation: "\(operation)-dispatch-mode",
                workId: workId,
                level: .fault
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "\(operation)-dispatch-mode",
                workId: workId
            )
            return .fatal(fatal)
        }

        if staleIsExpected, error is StaleDurableWorkClaimError {
            logExpectedOwnershipLoss(
                operation: operation,
                workId: workId
            )
            return .stale
        }
        let code: SupervisorFatalCode =
            Self.isLifecycleInvariantError(error)
            ? .invalidLifecycle
            : .storeFailure
        let message = code == .invalidLifecycle
            ? "规划持久化状态不满足生命周期不变量。"
            : "规划持久化存储失败，派发已停止。"
        let fatal = makeFatal(code, safeMessage: message)
        logErrorType(
            error,
            operation: operation,
            workId: workId,
            level: .fault
        )
        return .fatal(
            await latchFatalAndInvalidateRumination(
                fatal,
                operation: operation,
                workId: workId
            )
        )
    }

    private func classifyTerminalCommitError(
        _ error: Error,
        workId: String,
        token: UUID
    ) async -> DispatchErrorDisposition {
        do {
            if try database.dispatchMode() == .halted {
                await suppressAfterObservedDurableHalt(
                    operation: "terminal-commit",
                    workId: workId
                )
                return .halted
            }
        } catch {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "持久化派发控制记录缺失或损坏。"
            )
            logErrorType(
                error,
                operation: "terminal-dispatch-mode",
                workId: workId,
                level: .fault
            )
            _ = await latchFatalAndInvalidateRumination(
                fatal,
                operation: "terminal-dispatch-mode",
                workId: workId
            )
            return .fatal(fatal)
        }

        if error is StaleDurableWorkClaimError {
            await loseOwnership(workId: workId, token: token)
            logExpectedOwnershipLoss(
                operation: "terminal-commit",
                workId: workId
            )
            return .stale
        }
        if Self.isLifecycleInvariantError(error) {
            let fatal = makeFatal(
                .invalidLifecycle,
                safeMessage: "规划终态事务检测到损坏的生命周期状态。"
            )
            logErrorType(
                error,
                operation: "terminal-commit",
                workId: workId,
                level: .fault
            )
            return .fatal(
                await latchFatalAndInvalidateRumination(
                    fatal,
                    operation: "terminal-commit",
                    workId: workId
                )
            )
        }

        // A rollback-safe terminal transaction failure retains the exact
        // proposal and latest claim. Renewal or an explicit kick is the only
        // path that retries it; the provider is never invoked again.
        if error is DatabaseError {
            logErrorType(
                error,
                operation: "terminal-commit-retained",
                workId: workId,
                level: .error
            )
            return .retryable
        }

        let fatal = makeFatal(
            .invalidLifecycle,
            safeMessage: "规划终态事务返回了未知错误类型。"
        )
        logErrorType(
            error,
            operation: "terminal-commit-unknown",
            workId: workId,
            level: .fault
        )
        return .fatal(
            await latchFatalAndInvalidateRumination(
                fatal,
                operation: "terminal-commit-unknown",
                workId: workId
            )
        )
    }

    private func suppressAfterObservedDurableHalt(
        operation: String,
        workId: String?
    ) async {
        let identities = activeRuminationPhaseIdentities()
        if !dispatchSuppressed {
            dispatchSuppressed = true
            haltCleanupPending = true
            do {
                try await advanceGeneration()
            } catch {
                return
            }
        }
        cancelPumpAndNextDue()
        revokeAllOwnedEntriesWithoutCancel()
        let invalidations = reserveRuminationPhaseInvalidations(
            identities: identities,
            reason: .controlLoss
        )
        await publishReservedRuminationPhaseInvalidations(
            invalidations
        )
        cancelAllOwnedTasksAfterInvalidation()
        Self.logger.notice(
            "durable halt observed operation=\(operation, privacy: .public) work=\(workId ?? "-", privacy: .private(mask: .hash))"
        )
    }

    private func isLocallyDispatchable(generation: Int) -> Bool {
        lifecycle == .running
            && !dispatchSuppressed
            && fatalError == nil
            && startProjectionBarriers.isEmpty
            && self.generation == generation
    }

    private func requiredWork(id: String) throws -> DurableWorkRecord {
        guard let work = try store.work(id: id) else {
            throw DurableWorkNotFoundError(workId: id)
        }
        return work
    }

    private static func isTerminal(_ state: DurableWorkState) -> Bool {
        switch state {
        case .succeeded, .failed, .canceled:
            return true
        case .queued, .running, .retryScheduled:
            return false
        }
    }

    private static func isActive(_ state: DurableWorkState) -> Bool {
        switch state {
        case .queued, .running, .retryScheduled:
            return true
        case .succeeded, .failed, .canceled:
            return false
        }
    }

    private static func isLifecycleInvariantError(
        _ error: Error
    ) -> Bool {
        error is InvalidDurableWorkStateError
            || error is DurableWorkNotFoundError
            || error is RecordNotFoundError
            || error is InvalidPlanningPayloadError
            || error is InvalidRuminationPayloadError
            || error is InvalidDurableWorkTimeError
            || error is InvalidDurableWorkFailureError
            || error is InvalidDurableWorkOutputJSONError
            || error is BackoffOverflowError
            || error is AttemptAlreadyClosedError
            || error is DurableWorkInputHashMismatchError
            || error is CanonicalJSONNotCanonicalError
            || error is CanonicalJSONNumberOutOfRangeError
            || error is DecodingError
    }

    private func makeFatal(
        _ code: SupervisorFatalCode,
        safeMessage: String
    ) -> SupervisorFatalError {
        SupervisorFatalError(code: code, safeMessage: safeMessage)
    }

    private func latchReadFailure(
        _ error: Error,
        operation: String,
        workId: String?
    ) async -> SupervisorFatalError {
        if let fatalError {
            if fatalInvalidationInFlight {
                await waitForFatalInvalidation()
            }
            return fatalError
        }
        let code: SupervisorFatalCode =
            Self.isLifecycleInvariantError(error)
            ? .invalidLifecycle
            : .storeFailure
        let fatal = makeFatal(
            code,
            safeMessage: code == .invalidLifecycle
                ? "规划持久化读取发现损坏状态。"
                : "规划持久化读取失败，派发已停止。"
        )
        logErrorType(
            error,
            operation: operation,
            workId: workId,
            level: .fault
        )
        return await latchFatalAndInvalidateRumination(
            fatal,
            operation: operation,
            workId: workId
        )
    }

    private func cancelPumpAndNextDue() {
        pumpTask?.cancel()
        pumpTask = nil
        pumpToken = nil
        cancelNextDueTimer()
    }

    private func backgroundSleepFailed(
        _ error: Error,
        operation: String,
        workId: String?,
        token: UUID,
        generation: Int
    ) async {
        if let workId {
            guard let entry = owned[workId],
                  entry.token == token,
                  entry.generation == generation
            else {
                return
            }
        } else {
            guard nextDueToken == token,
                  self.generation == generation
            else {
                return
            }
        }
        let fatal = makeFatal(
            .invalidLifecycle,
            safeMessage: "规划监督器时钟等待失败。"
        )
        logErrorType(
            error,
            operation: operation,
            workId: workId,
            level: .fault
        )
        _ = await latchFatalAndInvalidateRumination(
            fatal,
            operation: operation,
            workId: workId
        )
    }

    private func isIdleNow() throws -> Bool {
        guard owned.isEmpty,
              pumpTask == nil,
              !haltCleanupPending
        else {
            return false
        }
        guard lifecycle == .recoveryReady || lifecycle == .running else {
            return false
        }
        if dispatchSuppressed,
           try database.dispatchMode() == .halted
        {
            return true
        }
        let current = now()
        let due: Date?
        if ruminationEnabled {
            due = try database.nextClaimableSupervisedWorkDate(
                now: current
            )
        } else {
            due = try database.nextClaimablePlanningDate(now: current)
        }
        guard let due
        else {
            return true
        }
        return due > current
    }

    private func wakeIdleWaitersIfPossible() async {
        guard !idleWaiters.isEmpty else {
            return
        }
        if let fatalError {
            let waiters = Array(idleWaiters.values)
            idleWaiters.removeAll()
            for waiter in waiters {
                waiter.resume(throwing: fatalError)
            }
            return
        }
        do {
            guard try isIdleNow() else {
                return
            }
            let waiters = Array(idleWaiters.values)
            idleWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        } catch {
            _ = await latchReadFailure(
                error,
                operation: "wake-idle",
                workId: nil
            )
        }
    }

    private func wakeTerminalWaiters(workId: String) {
        guard let waiters = terminalWaiters.removeValue(forKey: workId)
        else {
            return
        }
        for waiter in waiters.values {
            waiter.resume()
        }
    }

    private func refreshTerminalWaitersFromStore(
        workId: String? = nil
    ) throws {
        let workIds: [String]
        if let workId {
            workIds = terminalWaiters[workId] == nil ? [] : [workId]
        } else {
            workIds = terminalWaiters.keys.sorted()
        }
        for candidate in workIds {
            guard let work = try store.work(id: candidate) else {
                throw DurableWorkNotFoundError(workId: candidate)
            }
            if Self.isTerminal(work.state) {
                wakeTerminalWaiters(workId: candidate)
            }
        }
    }

    private func cancelIdleWaiter(_ waiterId: UUID) {
        guard let waiter = idleWaiters.removeValue(forKey: waiterId) else {
            return
        }
        waiter.resume(throwing: CancellationError())
    }

    private func cancelTerminalWaiter(
        workId: String,
        waiterId: UUID
    ) {
        guard var waiters = terminalWaiters[workId],
              let waiter = waiters.removeValue(forKey: waiterId)
        else {
            return
        }
        if waiters.isEmpty {
            terminalWaiters.removeValue(forKey: workId)
        } else {
            terminalWaiters[workId] = waiters
        }
        waiter.resume(throwing: CancellationError())
    }

    private func failOperationalWaiters(with error: Error) {
        let idle = Array(idleWaiters.values)
        idleWaiters.removeAll()
        for waiter in idle {
            waiter.resume(throwing: error)
        }
        let terminal = terminalWaiters.values.flatMap(\.values)
        terminalWaiters.removeAll()
        for waiter in terminal {
            waiter.resume(throwing: error)
        }
    }

    private func uncooperativeWorkIds() -> [String] {
        owned.compactMap { workId, entry in
            entry.providerExited ? nil : workId
        }.sorted()
    }

    private func waitForShutdownReport() async -> ShutdownReport {
        if let shutdownReport {
            return shutdownReport
        }
        let waiterId = UUID()
        return await withCheckedContinuation { continuation in
            if let shutdownReport {
                continuation.resume(returning: shutdownReport)
            } else {
                shutdownWaiters[waiterId] = continuation
            }
        }
    }

    private func shutdownDeadlineReached() {
        guard lifecycle == .shuttingDown else {
            return
        }
        _ = finalizeShutdown()
    }

    private func shutdownDeadlineSleepFailed(errorType: String) {
        guard lifecycle == .shuttingDown else {
            return
        }
        Self.logger.error(
            "operation=shutdown-deadline-sleep lifecycle=\(self.lifecycle.rawValue, privacy: .public) errorType=\(errorType, privacy: .public)"
        )
        _ = finalizeShutdown()
    }

    private func finishShutdownIfProvidersExited() {
        guard lifecycle == .shuttingDown,
              uncooperativeWorkIds().isEmpty
        else {
            return
        }
        _ = finalizeShutdown()
    }

    private func finalizeShutdown() -> ShutdownReport {
        if let shutdownReport {
            return shutdownReport
        }
        let report = ShutdownReport(
            uncooperativeWorkIds: uncooperativeWorkIds()
        )
        shutdownReport = report
        lifecycle = .shutDown
        shutdownDeadlineTask?.cancel()
        shutdownDeadlineTask = nil
        let waiters = Array(shutdownWaiters.values)
        shutdownWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: report)
        }
        return report
    }

    private enum LogLevel {
        case error
        case fault
    }

    private func logErrorType(
        _ error: Error,
        operation: String,
        workId: String?,
        level: LogLevel
    ) {
        let errorType = String(reflecting: type(of: error))
        switch level {
        case .error:
            Self.logger.error(
                "operation=\(operation, privacy: .public) lifecycle=\(self.lifecycle.rawValue, privacy: .public) work=\(workId ?? "-", privacy: .private(mask: .hash)) errorType=\(errorType, privacy: .public)"
            )
        case .fault:
            Self.logger.fault(
                "operation=\(operation, privacy: .public) lifecycle=\(self.lifecycle.rawValue, privacy: .public) work=\(workId ?? "-", privacy: .private(mask: .hash)) errorType=\(errorType, privacy: .public)"
            )
        }
    }

    private func logExpectedOwnershipLoss(
        operation: String,
        workId: String?
    ) {
        Self.logger.debug(
            "expected ownership loss operation=\(operation, privacy: .public) work=\(workId ?? "-", privacy: .private(mask: .hash))"
        )
    }
}
// P1-C-BEGIN CoachTurnProcessor
package struct CoachTurnProcessor: Sendable {
    private let database: AppDatabase
    private let workerId: String
    private let clock: @Sendable () -> Date
    private let sleep: ControlWorkerSleepV1
    private let provider: CoachTurnProviderV1

    package init(
        database: AppDatabase,
        workerId: String,
        clock: @escaping @Sendable () -> Date,
        sleep: @escaping ControlWorkerSleepV1,
        provider: @escaping CoachTurnProviderV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(workerId)
        self.database = database
        self.workerId = workerId
        self.clock = clock
        self.sleep = sleep
        self.provider = provider
    }

    package func recoverInterrupted() throws -> [DurableWorkRecord] {
        let now = clock()
        try CanonicalContractCodingV1.validateFinite(now)
        return try DurableWorkStore(database: database)
            .adoptExpiredControlWork(
                kind: .coach,
                currentWorkerId: workerId,
                now: now
            )
    }

    package func runNext() async throws -> Bool {
        try Task.checkCancellation()
        let claimNow = clock()
        try CanonicalContractCodingV1.validateFinite(claimNow)
        let durable = DurableWorkStore(database: database)
        guard let initialClaim = try durable.claimNext(
            kinds: [.coach],
            workerId: workerId,
            now: claimNow,
            leaseDuration: ControlWorkerLeasePolicyV1.leaseDuration
        ) else {
            return false
        }
        let snapshot = try loadSnapshot(claim: initialClaim)
        let latestClaim = LatestControlWorkClaim(initialClaim)
        let outcome = try await runProviderAndRenewal(
            request: snapshot.request,
            durable: durable,
            latestClaim: latestClaim
        )
        try Task.checkCancellation()
        let terminalClaim = try await latestClaim.closeAndTakeLatest()
        switch outcome {
        case .canceled:
            throw CancellationError()
        case let .question(prompt, recommendation, reason):
            guard isValidText(prompt),
                  isValidText(recommendation),
                  isValidText(reason)
            else {
                try terminalizeInvalidProviderOutput(
                    snapshot: snapshot,
                    claim: terminalClaim
                )
                return true
            }
            let terminalNow = clock()
            let command = try RecordCoachQuestionCommandV1(
                envelope: snapshot.envelope,
                goal: snapshot.goal,
                coach: snapshot.coach,
                claim: WorkClaimV1(claim: terminalClaim),
                decisionKey: snapshot.workInput.decisionKey,
                prompt: prompt,
                recommendation: recommendation,
                reason: reason
            )
            _ = try CoachUnderstandingStore(database: database).recordQuestion(
                command,
                terminalNow: terminalNow
            )
        case let .understanding(content):
            let terminalNow = clock()
            let command = try ProposeUnderstandingCommandV1(
                envelope: snapshot.envelope,
                goal: snapshot.goal,
                coach: snapshot.coach,
                claim: WorkClaimV1(claim: terminalClaim),
                expectedUnderstandingEventVersion:
                    snapshot.workInput.expectedUnderstandingEventVersion,
                content: content
            )
            _ = try CoachUnderstandingStore(database: database)
                .proposeUnderstanding(command, terminalNow: terminalNow)
        case let .failed(failure):
            try terminalizeFailure(
                failure,
                snapshot: snapshot,
                claim: terminalClaim
            )
        }
        return true
    }

    private func runProviderAndRenewal(
        request: CoachTurnProviderRequestV1,
        durable: DurableWorkStore,
        latestClaim: LatestControlWorkClaim
    ) async throws -> CoachTurnProviderOutcomeV1 {
        var providerOutcome: CoachTurnProviderOutcomeV1?
        try await withThrowingTaskGroup(
            of: CoachTurnProviderOutcomeV1.self
        ) { group in
            group.addTask {
                await provider(request)
            }
            group.addTask {
                while true {
                    try await sleep(ControlWorkerLeasePolicyV1.renewalInterval)
                    try Task.checkCancellation()
                    let current = try await latestClaim.current()
                    let renewalNow = clock()
                    try CanonicalContractCodingV1.validateFinite(renewalNow)
                    let renewed = try durable.renewLease(
                        claim: current,
                        now: renewalNow,
                        leaseDuration: ControlWorkerLeasePolicyV1.leaseDuration
                    )
                    try await latestClaim.replace(
                        expected: current,
                        renewed: renewed
                    )
                }
            }
            do {
                while let child = try await group.next() {
                    providerOutcome = child
                    group.cancelAll()
                }
            } catch is CancellationError {
                guard providerOutcome != nil, !Task.isCancelled else {
                    throw CancellationError()
                }
            }
        }
        guard let providerOutcome else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        return providerOutcome
    }

    private func loadSnapshot(
        claim: DurableWorkClaim
    ) throws -> (
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        coach: CoachHeadV1,
        workInput: CoachTurnWorkInputV1,
        request: CoachTurnProviderRequestV1,
        maxAttempts: Int
    ) {
        try database.pool.read { db in
            guard let work = try DurableWorkRecord.fetchOne(db, key: claim.workId),
                  let attempt = try DurableWorkAttemptRecord.fetchOne(
                    db,
                    key: ["workId": claim.workId, "attempt": claim.attempt]
                  )
            else { throw P1WorkerCommandEnvelopeError.invalidGraph }
            let envelope = try ControlWorkerCommandEnvelopeFactoryV1.make(
                work: work,
                attempt: attempt,
                claim: claim
            )
            let workInput = try CanonicalContractCodingV1.decode(
                CoachTurnWorkInputV1.self,
                from: Data(work.inputJson.utf8)
            )
            let expectedWorkKey = try ControlWorkKeyV1.coach(
                commandHash: workInput.turnCommandHash
            )
            let sessions = try CoachSessionRecord
                .filter(Column("goalId") == work.aggregateId)
                .order(Column("createdAt"), Column("id"))
                .fetchAll(db)
            guard work.kind == .coach,
                  work.aggregateType == "goal",
                  work.maxAttempts == 4,
                  work.idempotencyKey == expectedWorkKey,
                  sessions.count == 1,
                  let goal = try GoalControllerRecord.fetchOne(
                    db,
                    key: work.aggregateId
                  ),
                  goal.campId == work.campId,
                  workInput.goalId == goal.id,
                  workInput.sessionId == sessions[0].id,
                  sessions[0].status == .interviewing,
                  sessions[0].pendingQuestionId == nil
            else { throw P1WorkerCommandEnvelopeError.invalidGraph }
            let session = sessions[0]
            let eventVersion = try Int.fetchOne(
                db,
                sql: "SELECT MAX(aggregateVersion) FROM domain_event WHERE aggregateType='understanding' AND aggregateId=?",
                arguments: [goal.id]
            ) ?? 0
            guard eventVersion == workInput.expectedUnderstandingEventVersion else {
                throw P1WorkerCommandEnvelopeError.invalidGraph
            }
            switch workInput.failureScope {
            case .clarifyingGoal:
                guard .clarifying == goal.status,
                      goal.currentUnderstandingId == nil,
                      goal.currentUnderstandingVersion == nil,
                      workInput.confirmedUnderstanding == nil
                else { throw P1WorkerCommandEnvelopeError.invalidGraph }
            case .readyRevisionSessionOnly:
                guard .ready == goal.status,
                      let sealed = workInput.confirmedUnderstanding,
                      goal.currentUnderstandingId == sealed.understandingId,
                      goal.currentUnderstandingVersion
                        == sealed.expectedContentVersion,
                      let confirmed = try UnderstandingCardVersionRecord
                        .fetchOne(
                            db,
                            key: [
                                "id": sealed.understandingId,
                                "version": sealed.expectedContentVersion,
                            ]
                        ),
                      confirmed.goalId == goal.id,
                      confirmed.status == .confirmed,
                      confirmed.contentHash == sealed.contentHash,
                      confirmed.contentHash == (try CanonicalContractCodingV1
                        .hash(confirmed.content))
                else { throw P1WorkerCommandEnvelopeError.invalidGraph }
            }
            let understandings = try UnderstandingCardVersionRecord
                .filter(Column("goalId") == goal.id)
                .order(Column("version"))
                .fetchAll(db)
            guard understandings.map(\.version)
                    == understandings.map(\.version).sorted(),
                  Set(understandings.map { "\($0.id)#\($0.version)" }).count
                    == understandings.count
            else { throw P1WorkerCommandEnvelopeError.invalidGraph }
            let questions = try CoachQuestionRecord
                .filter(Column("sessionId") == session.id)
                .order(Column("createdAt"), Column("id"))
                .fetchAll(db)
            guard Set(questions.map(\.decisionKey)).count == questions.count else {
                throw P1WorkerCommandEnvelopeError.invalidGraph
            }
            let understandingHistory = understandings.map {
                CoachUnderstandingHistoryEntryV1(
                    understandingId: $0.id,
                    version: $0.version,
                    content: $0.content,
                    status: $0.status,
                    contentHash: $0.contentHash,
                    createdAt: $0.createdAt,
                    confirmedAt: $0.confirmedAt
                )
            }
            let questionHistory = questions.map {
                CoachQuestionHistoryEntryV1(
                    questionId: $0.id,
                    decisionKey: $0.decisionKey,
                    prompt: $0.prompt,
                    recommendation: $0.recommendation,
                    reason: $0.reason,
                    answer: $0.answer,
                    state: $0.state,
                    createdAt: $0.createdAt,
                    answeredAt: $0.answeredAt
                )
            }
            let request = CoachTurnProviderRequestV1(
                schemaVersion: 1,
                workId: work.id,
                attempt: work.attempt,
                goalId: goal.id,
                sessionId: session.id,
                nextQuestionId: workInput.nextQuestionId,
                decisionKey: workInput.decisionKey,
                failureScope: workInput.failureScope,
                goalTitle: goal.title,
                goalRawIntent: goal.rawIntent,
                confirmedUnderstanding: workInput.confirmedUnderstanding,
                understandingHistory: understandingHistory,
                questionHistory: questionHistory
            )
            return (
                envelope: envelope,
                goal: try GoalHeadV1(
                    goalId: goal.id,
                    campId: goal.campId,
                    expectedGoalVersion: goal.aggregateVersion
                ),
                coach: try CoachHeadV1(
                    sessionId: session.id,
                    expectedSessionVersion: session.aggregateVersion
                ),
                workInput: workInput,
                request: request,
                maxAttempts: work.maxAttempts
            )
        }
    }

    private func terminalizeInvalidProviderOutput(
        snapshot: (
            envelope: CommandEnvelopeV1,
            goal: GoalHeadV1,
            coach: CoachHeadV1,
            workInput: CoachTurnWorkInputV1,
            request: CoachTurnProviderRequestV1,
            maxAttempts: Int
        ),
        claim: DurableWorkClaim
    ) throws {
        let failure = try ControlWorkerProviderFailureV1(
            code: "coach_provider_invalid_output",
            safeMessage: nil,
            disposition: .deterministic
        )
        try terminalizeFailure(failure, snapshot: snapshot, claim: claim)
    }

    private func terminalizeFailure(
        _ failure: ControlWorkerProviderFailureV1,
        snapshot: (
            envelope: CommandEnvelopeV1,
            goal: GoalHeadV1,
            coach: CoachHeadV1,
            workInput: CoachTurnWorkInputV1,
            request: CoachTurnProviderRequestV1,
            maxAttempts: Int
        ),
        claim: DurableWorkClaim
    ) throws {
        let branch = try CoachWorkFailureBranchV1.derive(
            scope: snapshot.workInput.failureScope,
            failure: failure,
            attempt: claim.attempt,
            maxAttempts: snapshot.maxAttempts
        )
        let command = try RecordCoachWorkFailureCommandV1(
            envelope: snapshot.envelope,
            goal: snapshot.goal,
            coach: snapshot.coach,
            claim: WorkClaimV1(claim: claim),
            expectedUnderstandingEventVersion:
                snapshot.workInput.expectedUnderstandingEventVersion,
            failure: failure,
            failureScope: snapshot.workInput.failureScope,
            confirmedUnderstanding: snapshot.workInput.confirmedUnderstanding,
            failureBranch: branch
        )
        let terminalNow = clock()
        _ = try CoachUnderstandingStore(database: database)
            .recordCoachWorkFailure(command, terminalNow: terminalNow)
    }

    private func isValidText(_ value: String) -> Bool {
        do {
            try CanonicalContractCodingV1.validateNonempty(value)
            return true
        } catch {
            return false
        }
    }
}
// P1-C-END CoachTurnProcessor
