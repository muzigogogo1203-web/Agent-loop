import Testing
import Foundation
import AgentLoopCore

/// Thread-safe counter used by stub tests that need call counts across async boundaries.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    @discardableResult func bump() -> Int { lock.withLock { _value += 1; return _value } }
}

@Test func requestBodyShape() throws {
    let body = AnthropicProvider.requestBody(
        model: "claude-sonnet-4-6", system: "你是伙伴",
        history: [.user("hi")],
        tools: [ToolDef(name: "read_file", description: "读文件",
                        inputSchema: ["type": "object", "properties": ["path": ["type": "string"]], "required": ["path"], "additionalProperties": false])],
        maxTokens: 4096)
    #expect(body["model"]?.stringValue == "claude-sonnet-4-6")
    #expect(body["stream"]?.boolValue == true)
    #expect(body["max_tokens"]?.intValue == 4096)
    // system is a block array with cache_control (spec §6.3 cache-first design)
    #expect(body["system"]?[0]?["cache_control"]?["type"]?.stringValue == "ephemeral")
    #expect(body["tools"]?[0]?["input_schema"]?["type"]?.stringValue == "object")
    #expect(body["messages"]?[0]?["role"]?.stringValue == "user")
}

@Test func requestBodyEncodesDeterministically() throws {
    let tools = [ToolDef(name: "t", description: "d",
                         inputSchema: ["type": "object",
                                       "properties": ["a": ["type": "string"], "b": ["type": "string"]],
                                       "required": ["a"],
                                       "additionalProperties": false])]
    let body = AnthropicProvider.requestBody(model: "m", system: "s", history: [.user("hi")],
                                             tools: tools, maxTokens: 10)
    let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
    let a = String(data: try enc.encode(body), encoding: .utf8)!
    let b = String(data: try enc.encode(body), encoding: .utf8)!
    #expect(a == b)
    #expect(a.range(of: #""additionalProperties":false"#) != nil)
}

// URLProtocol stub
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data, [String: String]))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data, headers) = Self.handler!(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func stubbedSession() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [StubProtocol.self]
    return URLSession(configuration: cfg)
}

@Suite(.serialized) struct AnthropicProviderStubTests {

@Test func streamsTextTurnEndToEnd() async throws {
    let sse = """
    event: message_start
    data: {"type":"message_start","message":{"usage":{"input_tokens":5}}}
    event: content_block_start
    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"好的"}}
    event: content_block_stop
    data: {"type":"content_block_stop","index":0}
    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}
    event: message_stop
    data: {"type":"message_stop"}
    """
    StubProtocol.handler = { req in
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(req.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        return (200, Data(sse.utf8), ["Content-Type": "text/event-stream"])
    }
    let p = AnthropicProvider(apiKey: "sk-test", model: "claude-sonnet-4-6", session: stubbedSession())
    var deltas = ""; var turn: TurnResult?
    for try await ev in p.streamTurn(system: "s", history: [.user("hi")], tools: [], maxTokens: 100) {
        switch ev {
        case .textDelta(let t): deltas += t
        case .turn(let t): turn = t
        }
    }
    #expect(deltas == "好的")
    #expect(turn?.stopReason == .endTurn)
    #expect(turn?.usage.outputTokens == 7)
}

@Test func unauthorizedFailsFastNoRetry() async {
    let counter = Counter()
    StubProtocol.handler = { _ in counter.bump(); return (401, Data(#"{"error":{"message":"bad key"}}"#.utf8), [:]) }
    let p = AnthropicProvider(apiKey: "bad", model: "m", session: stubbedSession())
    await #expect(throws: ProviderError.unauthorized) {
        for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    }
    #expect(counter.value == 1)
}

@Test func overloadedRetriesThenSucceeds() async throws {
    let counter = Counter()
    let okSSE = "event: message_stop\ndata: {\"type\":\"message_stop\"}"
    StubProtocol.handler = { _ in
        let n = counter.bump()
        return n < 3 ? (529, Data("overloaded".utf8), [:]) : (200, Data(okSSE.utf8), [:])
    }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(),
                              retryBaseDelay: .milliseconds(1)) // test acceleration
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    #expect(counter.value == 3)
}

@Test func honorsRetryAfterHeader() async throws {
    let counter = Counter()
    let okSSE = "event: message_stop\ndata: {\"type\":\"message_stop\"}"
    StubProtocol.handler = { _ in
        let n = counter.bump()
        return n == 1 ? (429, Data(), ["Retry-After": "0"]) : (200, Data(okSSE.utf8), [:])
    }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(), retryBaseDelay: .seconds(30))
    // base delay 30s: if Retry-After: 0 is not honoured the test would be extremely slow; honouring it completes instantly
    let start = ContinuousClock.now
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    #expect(ContinuousClock.now - start < .seconds(5))
    #expect(counter.value == 2)
}

@Test func malformedRetryAfterFallsBackAndCaps() async throws {
    let counter = Counter()
    let okSSE = "event: message_stop\ndata: {\"type\":\"message_stop\"}"
    StubProtocol.handler = { _ in
        let n = counter.bump()
        return n == 1 ? (429, Data(), ["Retry-After": "inf"]) : (200, Data(okSSE.utf8), [:])
    }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(), retryBaseDelay: .milliseconds(1))
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    #expect(counter.value == 2)  // does not crash; falls back to exponential backoff
}

@Test func retriesExhaustedThrows() async {
    let counter = Counter()
    StubProtocol.handler = { _ in counter.bump(); return (503, Data(), [:]) }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(),
                              retryBaseDelay: .milliseconds(1), maxRetries: 2)
    await #expect(throws: ProviderError.overloadedRetriesExhausted) {
        for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    }
    #expect(counter.value == 3)  // initial attempt + 2 retries
}

}
