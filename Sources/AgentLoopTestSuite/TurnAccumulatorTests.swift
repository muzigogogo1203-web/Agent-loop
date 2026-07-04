import Testing
import AgentLoopCore

private func feed(_ acc: inout TurnAccumulator, _ event: String, _ json: String) throws -> [String] {
    var deltas: [String] = []
    try acc.consume(RawSSEEvent(event: event, data: json)) { deltas.append($0) }
    return deltas
}

@Test func accumulatesTextAndToolUse() throws {
    var acc = TurnAccumulator()
    _ = try feed(&acc, "message_start", #"{"type":"message_start","message":{"usage":{"input_tokens":10}}}"#)
    _ = try feed(&acc, "content_block_start", #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#)
    let d1 = try feed(&acc, "content_block_delta", #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"你好"}}"#)
    #expect(d1 == ["你好"])
    _ = try feed(&acc, "content_block_stop", #"{"type":"content_block_stop","index":0}"#)
    _ = try feed(&acc, "content_block_start", #"{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_9","name":"write_file","input":{}}}"#)
    _ = try feed(&acc, "content_block_delta", #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"path\":"}}"#)
    _ = try feed(&acc, "content_block_delta", #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"a.md\"}"}}"#)
    _ = try feed(&acc, "content_block_stop", #"{"type":"content_block_stop","index":1}"#)
    _ = try feed(&acc, "message_delta", #"{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":42}}"#)
    _ = try feed(&acc, "message_stop", #"{"type":"message_stop"}"#)

    let turn = try #require(acc.finishedTurn)
    #expect(turn.stopReason == .toolUse)
    #expect(turn.content[0] == .text("你好"))
    guard case .toolUse(let id, let name, let input) = turn.content[1] else { Issue.record("no toolUse"); return }
    #expect(id == "toolu_9" && name == "write_file" && input["path"]?.stringValue == "a.md")
    #expect(turn.usage.inputTokens == 10 && turn.usage.outputTokens == 42)
}

@Test func emptyToolInputBecomesEmptyObject() throws {
    var acc = TurnAccumulator()
    _ = try feed(&acc, "content_block_start", #"{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"t","name":"list_dir","input":{}}}"#)
    _ = try feed(&acc, "content_block_stop", #"{"type":"content_block_stop","index":0}"#)
    _ = try feed(&acc, "message_delta", #"{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{}}"#)
    _ = try feed(&acc, "message_stop", #"{"type":"message_stop"}"#)
    guard case .toolUse(_, _, let input) = try #require(acc.finishedTurn).content[0] else { return }
    #expect(input == .object([:]))
}

@Test func apiErrorEventThrows() {
    var acc = TurnAccumulator()
    #expect(throws: ProviderError.self) {
        try acc.consume(RawSSEEvent(event: "error", data: #"{"type":"error","error":{"type":"overloaded_error","message":"busy"}}"#)) { _ in }
    }
}
