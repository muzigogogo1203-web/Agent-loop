import Dispatch
import Foundation
import os

package enum RuntimeLifecycleStage: String, Sendable {
    case boardAcceptQueued, boardAcceptStarted, boardAcceptFinished
    case boardConnectionAccepted, boardHandlerQueued, boardHandlerStarted, boardHandlerFinished
    case boardStopStarted, boardAcceptJoined, boardHandlersJoined
    case drainQueued, drainStarted, drainEOF, drainFinished
    case drainJoinStarted, drainJoinCompleted, drainJoinTimedOut
    case probeCompositionStarted, probeCompositionCompleted
    case cliFinalizeStarted, cliStdinFinished, cliReaped, cliStdoutFinished, cliStderrFinished
    case cliServerStopStarted, cliServerStopFinished, cliFinalizeFinished
    case cliRunQueued, cliRunStarted, cliLaunchInputsValidated
    case cliEnvironmentRequested, cliEnvironmentReady, cliEnvironmentValidated
    case cliBoardStartCalled, cliBoardStartReturned
    case cliSpawnPreparationStarted, cliPosixSpawnCalled, cliSpawned, cliSpawnFailed
    case cliSuspendedValidationCalled, cliSuspendedValidationReturned
    case cliReapTaskQueued, cliReapTaskStarted, cliWaitpidReturned, cliWaitpidError
    case cliStdoutTaskQueued, cliStdoutTaskStarted, cliStdoutDrainEntered
    case cliStdoutFirstBytes, cliStdoutFirstLineYielded
    case cliStderrTaskQueued, cliStderrTaskStarted
    case cliSIGCONTCalled, cliSIGCONTReturned
    case cliFixtureLaunchCalled, cliFixtureLaunchReturned
    case cliFixtureConsumerQueued, cliFixtureConsumerStarted
    case cliFixtureBodyStarted, cliFixtureFirstStdoutReceived
    case cliFixtureFirstStdoutRecorded, cliFixtureStreamFinished
    case cliFixtureReadyAwaitQueued, cliFixtureReadyWaitStarted, cliFixtureReadyWaitEnded
    case cliFixtureConsumerJoined
    case processSignalPath, processSignalTarget, processSignalNumber
    case processSignalResult, processSignalErrno
    case cliFixtureCancellationState, cliFixtureCancellationPID, cliFixtureCancellationGroup
    case cliFixtureCancellationStatus, cliFixtureTermSent, cliFixtureKillSent
    case cliFixtureChildReaped, cliFixtureStdoutEOF, cliFixtureStderrEOF
    case cliFixtureExitFrameCount, cliFixtureExitFrameStatus
    case haltStopEntered, haltSuppressCalled, haltSuppressReturned, haltTransitionPublished
    case haltPersistenceCalled, haltPersistenceReturned, haltPersistenceFailed
    case haltRunningSnapshot, haltRuntimeResolved, haltRuntimeResolveFailed
    case haltRuntimeCancelCalled, haltRuntimeCancelReturned, haltRuntimeCancelFailed
    case haltRuntimeEntered, haltProfileReadCalled, haltProfileReadReturned
    case haltCompositionCalled, haltCompositionReturned, haltCoordinatorCalled, haltCoordinatorReturned
    case haltCancellationPersistenceCalled, haltCancellationPersistenceReturned
    case haltActiveCancelCalled, haltActiveCancelReturned, haltActiveTaskQueued, haltActiveTaskStarted
    case haltConsumptionCancelCalled, haltConsumptionJoined
    case haltEntryTaskCancelCalled, haltEntryTaskJoinCalled, haltEntryTaskJoinReturned, haltEntryUnbound
    case haltPlanningCleanupCalled, haltPlanningCleanupReturned, haltStopReachedEnd
    case haltFixtureIdentityMissing, haltFixtureStopQueued, haltFixtureStopTaskStarted
    case haltFixtureHaltedObserved, haltFixtureCancelObserveQueued, haltFixtureCancelObserveReturned
    case haltFixtureGateOpenQueued, haltFixtureStopJoined
    case haltProviderTermination, haltProviderTaskCancelReturned
    case haltProviderCancellationCaught, haltProviderCancellationRecorded
    case haltProviderWaitStarted, haltProviderWaitEnded
    case haltPlannerGateEntered, haltPlannerGateOpened
}

package enum RuntimeLifecycleDiagnostics {
    private static let enabled = ProcessInfo.processInfo.environment[
        "AGENTLOOP_RUNTIME_DIAGNOSTICS"
    ] == "1"
    private static let logger = Logger(
        subsystem: "com.muzi.agentloop", category: "runtime-lifecycle"
    )

    package static var isEnabled: Bool { enabled }

    package static func signalWillSend(
        target: Int32, signal: Int32, path: Int
    ) -> UUID? {
        guard isEnabled else { return nil }
        let owner = UUID()
        event(.processSignalPath, owner: owner, value: path)
        event(.processSignalTarget, owner: owner, value: Int(target))
        event(.processSignalNumber, owner: owner, value: Int(signal))
        return owner
    }

    package static func signalDidSend(
        owner: UUID?, result: Int32, errorNumber: Int32
    ) {
        guard let owner else { return }
        event(.processSignalResult, owner: owner, value: Int(result))
        event(
            .processSignalErrno, owner: owner,
            value: result == 0 ? 0 : Int(errorNumber)
        )
    }

    package static func event(
        _ stage: RuntimeLifecycleStage, owner: UUID, value: Int = 0
    ) {
        guard enabled else { return }
        logger.notice("stage=\(stage.rawValue, privacy: .public) owner=\(owner.uuidString, privacy: .public) mono=\(DispatchTime.now().uptimeNanoseconds, privacy: .public) value=\(value, privacy: .public)")
    }
}
