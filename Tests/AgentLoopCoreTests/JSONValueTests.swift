import Testing
import Foundation
@testable import AgentLoopCore

@Test func jsonRoundTrip() throws {
    let raw = #"{"a":[1,"x",true,null],"b":{"c":2.5}}"#.data(using: .utf8)!
    let v = try JSONDecoder().decode(JSONValue.self, from: raw)
    #expect(v["a"]?[1]?.stringValue == "x")
    #expect(v["b"]?["c"]?.doubleValue == 2.5)
    let re = try JSONEncoder().encode(v)
    let v2 = try JSONDecoder().decode(JSONValue.self, from: re)
    #expect(v == v2) // 语义等价往返
}

@Test func jsonLiterals() {
    let v: JSONValue = ["name": "read_file", "n": 3, "ok": true]
    #expect(v["name"]?.stringValue == "read_file")
    #expect(v["n"]?.intValue == 3)
}
