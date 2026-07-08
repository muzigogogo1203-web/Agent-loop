import Testing
import AgentLoopCore

// M6-D3/D5b：伙伴工具白名单语义

@Test func legacyEmptyArrayMeansFullBuiltins() {
    // 存量兼容："[]" = 内置能力工具全量
    let access = ToolAccess.parse(toolsJson: "[]")
    #expect(access.capabilities == Set(ToolAccess.builtinCapabilityNames))
    #expect(!access.parseFailed)
}

@Test func legacyExplicitArrayIntersectsBuiltins() {
    let access = ToolAccess.parse(toolsJson: #"["read_file", "no_such_tool"]"#)
    #expect(access.capabilities == ["read_file"])
    #expect(!access.parseFailed)
}

@Test func explicitV2AllowListIsLiteral() {
    let access = ToolAccess.parse(toolsJson: #"{"v":2,"allow":["read_file","web_fetch"]}"#)
    #expect(access.capabilities == ["read_file", "web_fetch"])
    #expect(!access.parseFailed)
}

@Test func explicitV2EmptyAllowMeansNoCapabilities() {
    // D5b：显式零能力工具是合法选择（纯推理伙伴）；与存量 "[]" 语义不同
    let access = ToolAccess.parse(toolsJson: #"{"v":2,"allow":[]}"#)
    #expect(access.capabilities.isEmpty)
    #expect(!access.parseFailed)
}

@Test func garbageJsonFallsBackToFullWithFlag() {
    // D4：解析失败回退全量，调用方记 kernel_error 事件；卡片不因坏白名单瘫痪
    let access = ToolAccess.parse(toolsJson: "not json at all")
    #expect(access.capabilities == Set(ToolAccess.builtinCapabilityNames))
    #expect(access.parseFailed)
}

@Test func boardToolsAreNeverDeniable() {
    // D3：终结契约 + 人工门 + 进展汇报永不可剥夺
    let none = ToolAccess.parse(toolsJson: #"{"v":2,"allow":[]}"#)
    for board in ["complete_card", "block_card", "add_progress_note", "ask_user"] {
        #expect(none.allows(board))
    }
    #expect(!none.allows("write_file"))
}

@Test func explicitJsonRoundTripsAndIsDeterministic() {
    // D5b：编辑器保存永远写显式 v2 列表；排序保证字节确定
    let json = ToolAccess.explicitJson(allow: ["write_file", "read_file"])
    #expect(json == #"{"allow":["read_file","write_file"],"v":2}"#)
    let parsed = ToolAccess.parse(toolsJson: json)
    #expect(parsed.capabilities == ["read_file", "write_file"])
}
