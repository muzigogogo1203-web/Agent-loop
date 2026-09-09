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
}

package enum RuntimeLifecycleDiagnostics {
    private static let enabled = ProcessInfo.processInfo.environment[
        "AGENTLOOP_RUNTIME_DIAGNOSTICS"
    ] == "1"
    private static let logger = Logger(
        subsystem: "com.muzi.agentloop", category: "runtime-lifecycle"
    )

    package static func event(
        _ stage: RuntimeLifecycleStage, owner: UUID, value: Int = 0
    ) {
        guard enabled else { return }
        logger.notice("stage=\(stage.rawValue, privacy: .public) owner=\(owner.uuidString, privacy: .public) mono=\(DispatchTime.now().uptimeNanoseconds, privacy: .public) value=\(value, privacy: .public)")
    }
}
