import Foundation
import AgentLoopCore

var forcedArguments = CommandLine.arguments
if !forcedArguments.contains("--board-server") {
    forcedArguments.append("--board-server")
}
BoardServerBridgeMain.exitIfRequested(
    arguments: forcedArguments,
    environment: ProcessInfo.processInfo.environment
)
FileHandle.standardError.write(
    Data("board-server bridge returned without handling forced mode\n".utf8)
)
Foundation.exit(1)
