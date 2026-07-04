import Testing
import AgentLoopCore

@Test func handoffParsesFromToolInput() throws {
    let input: JSONValue = [
        "outcome": "清单已完成",
        "summary": "整理了 12 件装备",
        "artifacts": [["relativePath": "清单.md", "kind": "markdown", "label": "装备清单"]],
        "verification": [["method": "重读检查完整性", "passed": true, "note": "分类齐全"]],
        "risks": [],
    ]
    let handoff = try HandoffPayload.parse(from: input).get()
    #expect(handoff.outcome == "清单已完成")
    #expect(handoff.artifacts.count == 1)
}

@Test func handoffRequiresArtifactsOrReason() {
    let input: JSONValue = [
        "outcome": "x",
        "summary": "y",
        "artifacts": [],
        "verification": [],
        "risks": [],
    ]
    guard case .failure(let message) = HandoffPayload.parse(from: input) else {
        Issue.record("should fail")
        return
    }
    #expect(message.contains("noArtifactReason"))
}

@Test func handoffRequiresNonEmptyCoreFields() {
    let input: JSONValue = [
        "outcome": "",
        "summary": "y",
        "noArtifactReason": "纯讨论",
        "artifacts": [],
        "verification": [],
        "risks": [],
    ]
    guard case .failure = HandoffPayload.parse(from: input) else {
        Issue.record("should fail")
        return
    }
}
