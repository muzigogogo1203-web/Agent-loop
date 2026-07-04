import Testing
import Foundation
import AgentLoopCore

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

@Test func jsonWireSafety() throws {
    let v = try JSONValue.decoded(from: #"{"one":1,"big":1e300,"frac":2.7,"t":true}"#)
    #expect(v["one"]?.intValue == 1)
    #expect(v["one"]?.boolValue == nil)      // 数字不会被吞成布尔
    #expect(v["t"]?.boolValue == true)
    #expect(v["big"]?.intValue == nil)        // 超范围返回 nil 而非崩溃
    #expect(v["frac"]?.intValue == nil)       // 非整数不静默截断
    let re = try JSONValue.object(["n": .number(3)]).encodedString()
    #expect(re.contains("3") && !re.contains("3.0"))  // 整数无 .0 后缀
}
