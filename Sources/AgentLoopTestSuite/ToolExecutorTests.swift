import Testing
import AgentLoopCore

@Test func m1ToolDefsComplete() {
    let names = ToolDef.m1Tools.map(\.name)
    #expect(names == ["complete_card", "block_card", "add_progress_note",
                      "list_dir", "read_file", "write_file", "web_fetch"])
    for def in ToolDef.m1Tools {
        #expect(def.inputSchema["type"]?.stringValue == "object")
        #expect(def.inputSchema["additionalProperties"]?.boolValue == false)
        #expect(!def.description.isEmpty)
    }
}

@Test func unknownToolReturnsError() async {
    let exec = ToolExecutor(handlers: [:])
    let outcome = await exec.execute(name: "no_such_tool", input: .object([:]))
    guard case .error(let msg) = outcome else { Issue.record("expected error"); return }
    #expect(msg.contains("no_such_tool"))
}
