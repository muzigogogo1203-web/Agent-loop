// Standalone test runner — imports all test suites and runs them via Testing.__swiftPMEntryPoint.
// Use: swift run RunTests
// This bypasses swiftpm-testing-helper for environments without TTY (e.g. Claude Code subshell).
import Testing
import Foundation
import AgentLoopCore

// ── Task 0: Smoke test ───────────────────────────────────────────────────────
@Test func packageBuilds() { #expect(Bool(true)) }

// ── Task 1: JSONValue round-trip ─────────────────────────────────────────────
@Test func jsonRoundTrip() throws {
    let raw = #"{"a":[1,"x",true,null],"b":{"c":2.5}}"#.data(using: .utf8)!
    let v = try JSONDecoder().decode(JSONValue.self, from: raw)
    #expect(v["a"]?[1]?.stringValue == "x")
    #expect(v["b"]?["c"]?.doubleValue == 2.5)
    let re = try JSONEncoder().encode(v)
    let v2 = try JSONDecoder().decode(JSONValue.self, from: re)
    #expect(v == v2)
}

@Test func jsonLiterals() {
    let v: JSONValue = ["name": "read_file", "n": 3, "ok": true]
    #expect(v["name"]?.stringValue == "read_file")
    #expect(v["n"]?.intValue == 3)
}

// ── Main entry point ─────────────────────────────────────────────────────────
@main struct Runner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
