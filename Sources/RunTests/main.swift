// Standalone test runner — force-links AgentLoopTestSuite so swift-testing
// runtime discovers all @Test functions declared there.
// Use: swift run RunTests
// This bypasses swiftpm-testing-helper for environments without TTY (e.g. Claude Code subshell).
import Testing
import AgentLoopTestSuite  // force-link: runtime discovers @Test functions from the library image

// __swiftPMEntryPoint is underscored SPI verified against Swift 6.2.3.
@main struct Runner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
