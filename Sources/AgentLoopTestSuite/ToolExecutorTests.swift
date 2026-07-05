import Testing
import AgentLoopCore

@Test func agentToolDefsComplete() {
    let names = ToolDef.agentTools.map(\.name)
    #expect(names == ["complete_card", "block_card", "add_progress_note",
                      "ask_user", "list_dir", "read_file", "write_file", "web_fetch"])
    for def in ToolDef.agentTools {
        #expect(def.inputSchema["type"]?.stringValue == "object")
        #expect(def.inputSchema["additionalProperties"]?.boolValue == false)
        #expect(!def.description.isEmpty)
    }
}

@Test func writeFileSchemaHasOptionalAppend() {
    let schema = ToolDef.writeFile.inputSchema
    #expect(schema["properties"]?["append"]?["type"]?.stringValue == "boolean")
    // append 是可选参数：不在 required 里
    let required = schema["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
    #expect(required == ["path", "content"])
    #expect(ToolDef.writeFile.description.contains("append"))
}

@Test func unknownToolReturnsError() async {
    let exec = ToolExecutor(handlers: [:])
    let outcome = await exec.execute(name: "no_such_tool", input: .object([:]))
    guard case .error(let msg) = outcome else { Issue.record("expected error"); return }
    #expect(msg.contains("no_such_tool"))
}
