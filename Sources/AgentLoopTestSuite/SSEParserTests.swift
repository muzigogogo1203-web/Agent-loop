import Testing
import AgentLoopCore

@Test func parsesEventDataPairs() {
    var p = SSELineParser()
    #expect(p.consume(line: "event: message_start") == nil)
    let e = p.consume(line: #"data: {"type":"message_start"}"#)
    #expect(e?.event == "message_start")
    #expect(e?.data == #"{"type":"message_start"}"#)
    #expect(p.consume(line: "") == nil)
}

@Test func ignoresCommentsAndPings() {
    var p = SSELineParser()
    #expect(p.consume(line: ": keep-alive") == nil)
    _ = p.consume(line: "event: ping")
    let e = p.consume(line: #"data: {"type":"ping"}"#)
    #expect(e?.event == "ping")
}
