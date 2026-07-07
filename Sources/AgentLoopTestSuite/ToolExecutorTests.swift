import Testing
import AgentLoopCore

@Test func agentToolDefsComplete() {
    let names = ToolDef.agentTools.map(\.name)
    #expect(names == ["complete_card", "block_card", "add_progress_note",
                      "ask_user", "list_dir", "read_file", "write_file", "web_fetch",
                      "search_camp_notes"])
    for def in ToolDef.agentTools {
        #expect(def.inputSchema["type"]?.stringValue == "object")
        #expect(def.inputSchema["additionalProperties"]?.boolValue == false)
        #expect(!def.description.isEmpty)
    }
}

@Test func guideToolDefsFixedTrio() {
    // 向导工具固定三件（spec §8），普通伙伴不可用向导专属工具
    #expect(ToolDef.guideTools.map(\.name) == ["search_camp_notes", "camp_status", "propose_squad"])
    #expect(!ToolDef.agentTools.contains { $0.name == "camp_status" })
    #expect(!ToolDef.agentTools.contains { $0.name == "propose_squad" })
    let proposeRequired = ToolDef.proposeSquad.inputSchema["required"]?.arrayValue?.compactMap(\.stringValue)
    #expect(proposeRequired == ["name", "memberIds", "goal"])
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

@Test func closureToolHandlerDispatchesThroughExecutor() async {
    // M6-D1：闭包式 handler 让需要捕获调用上下文的工具（如 propose_squad）
    // 也能走 ToolExecutor 单一分发
    let exec = ToolExecutor(handlers: [
        "echo": ClosureToolHandler { input in
            .result("echo:\(input["text"]?.stringValue ?? "")")
        },
    ])
    let outcome = await exec.execute(name: "echo", input: ["text": "hi"])
    guard case .result(let content) = outcome else { Issue.record("expected result"); return }
    #expect(content == "echo:hi")
}
