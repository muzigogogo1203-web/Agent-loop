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
