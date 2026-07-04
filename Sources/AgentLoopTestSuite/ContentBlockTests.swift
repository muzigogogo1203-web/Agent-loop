import Testing
import Foundation
import AgentLoopCore

@Test func decodeKnownBlocks() throws {
    let raw = #"[{"type":"text","text":"hi"},{"type":"tool_use","id":"toolu_1","name":"read_file","input":{"path":"a.md"}}]"#
    let blocks = try JSONDecoder().decode([ContentBlock].self, from: Data(raw.utf8))
    #expect(blocks[0] == .text("hi"))
    guard case .toolUse(let id, let name, let input) = blocks[1] else { Issue.record("not toolUse"); return }
    #expect(id == "toolu_1" && name == "read_file" && input["path"]?.stringValue == "a.md")
}

@Test func unknownBlockRoundTripsVerbatim() throws {
    let raw = #"{"type":"thinking","thinking":"...","signature":"sig123"}"#
    let block = try JSONDecoder().decode(ContentBlock.self, from: Data(raw.utf8))
    guard case .unknown = block else { Issue.record("should be unknown"); return }
    let re = try JSONEncoder().encode(block)
    let a = try JSONValue.decoded(from: String(data: re, encoding: .utf8)!)
    let b = try JSONValue.decoded(from: raw)
    #expect(a == b) // 语义级原样透传
}

@Test func toolResultEncoding() throws {
    let block = ContentBlock.toolResult(toolUseId: "toolu_1", content: "ok", isError: false)
    let v = try JSONValue.decoded(from: String(data: JSONEncoder().encode(block), encoding: .utf8)!)
    #expect(v["type"]?.stringValue == "tool_result")
    #expect(v["tool_use_id"]?.stringValue == "toolu_1")
    #expect(v["is_error"]?.boolValue == false)
}

@Test func toolResultArrayContentFallsBackToUnknown() throws {
    let raw = #"{"type":"tool_result","tool_use_id":"t","content":[{"type":"text","text":"x"}]}"#
    let block = try JSONDecoder().decode(ContentBlock.self, from: Data(raw.utf8))
    guard case .unknown = block else { Issue.record("array-content tool_result must pass through verbatim"); return }
    let re = try JSONValue.decoded(from: String(data: JSONEncoder().encode(block), encoding: .utf8)!)
    #expect(re == (try JSONValue.decoded(from: raw)))
}
