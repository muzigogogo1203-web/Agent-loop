// Standalone test runner — imports all test suites and runs them via Testing.__swiftPMEntryPoint.
// Use: swift run RunTests
// This bypasses swiftpm-testing-helper for environments without TTY.
import Testing

// Re-export the AgentLoopCore test suite by importing all test modules
// Tests must be declared here or in the same module for discovery.
// For Task 0 smoke test and Task 1 JSONValue tests, they are declared below.

import AgentLoopCore

// ── Smoke test (Task 0) ──────────────────────────────────────────────────────
@Test func packageBuilds() { #expect(Bool(true)) }

// ── Main entry point ─────────────────────────────────────────────────────────
@main struct Runner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
