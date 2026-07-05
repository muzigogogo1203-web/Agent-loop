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

@Test func requestBodyToolChoiceForcesNamedTool() throws {
    let body = AnthropicProvider.requestBody(
        model: "m",
        system: "s",
        history: [.user("hi")],
        tools: [ToolDef(name: "propose_plan", description: "d", inputSchema: ["type": "object"])],
        toolChoice: .tool(name: "propose_plan"),
        maxTokens: 10
    )
    #expect(body["tool_choice"]?["type"]?.stringValue == "tool")
    #expect(body["tool_choice"]?["name"]?.stringValue == "propose_plan")
}

@Test func requestBodyAutoOmitsToolChoice() throws {
    let defaultBody = AnthropicProvider.requestBody(
        model: "m",
        system: "s",
        history: [.user("hi")],
        tools: [ToolDef(name: "t", description: "d", inputSchema: ["type": "object"])],
        maxTokens: 10
    )
    let explicitAuto = AnthropicProvider.requestBody(
        model: "m",
        system: "s",
        history: [.user("hi")],
        tools: [ToolDef(name: "t", description: "d", inputSchema: ["type": "object"])],
        toolChoice: .auto,
        maxTokens: 10
    )
    #expect(explicitAuto["tool_choice"] == nil)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    #expect(try encoder.encode(defaultBody) == encoder.encode(explicitAuto))
}

@Test func streamingSessionTimeoutDefaultsSupportSlowRelays() {
    #expect(AnthropicProvider.streamingTimeoutIntervalForRequest == 300)
    #expect(AnthropicProvider.streamingTimeoutIntervalForResource == 3600)

    let provider = AnthropicProvider(apiKey: "k", model: "m")
    let session = Mirror(reflecting: provider).children.first { $0.label == "session" }?.value as? URLSession
    #expect(session?.configuration.timeoutIntervalForRequest == AnthropicProvider.streamingTimeoutIntervalForRequest)
    #expect(session?.configuration.timeoutIntervalForResource == AnthropicProvider.streamingTimeoutIntervalForResource)
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

    /// URLSession 把 httpBody 转成 bodyStream 后再交给 URLProtocol，读回完整 body 供断言用。
    static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
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
    for try await ev in p.streamTurn(system: "s", history: [.user("hi")], tools: [], toolChoice: .auto, maxTokens: 100) {
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
        for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], toolChoice: .auto, maxTokens: 10) {}
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
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], toolChoice: .auto, maxTokens: 10) {}
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
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], toolChoice: .auto, maxTokens: 10) {}
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
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], toolChoice: .auto, maxTokens: 10) {}
    #expect(counter.value == 2)  // does not crash; falls back to exponential backoff
}

@Test func fallsBackToNonStreamingAfterMalformedStream() async throws {
    let counter = Counter()
    // 第一次：截断的 SSE（无 message_stop）→ malformedStream；
    // 第二次：断言请求体 stream==false，返回完整 message JSON。
    let truncatedSSE = """
    event: message_start
    data: {"type":"message_start","message":{"usage":{"input_tokens":5}}}
    event: content_block_start
    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"写到一半"}}
    """
    let fullMessage = """
    {"type":"message","content":[{"type":"text","text":"完整回复"}],"stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":9}}
    """
    StubProtocol.handler = { req in
        let n = counter.bump()
        let body = try? JSONValue.decoded(from: String(data: StubProtocol.bodyData(of: req), encoding: .utf8) ?? "")
        if n == 1 {
            #expect(body?["stream"]?.boolValue == true)
            return (200, Data(truncatedSSE.utf8), ["Content-Type": "text/event-stream"])
        }
        #expect(body?["stream"]?.boolValue == false)
        return (200, Data(fullMessage.utf8), ["Content-Type": "application/json"])
    }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(), retryBaseDelay: .milliseconds(1))
    var deltas: [String] = []; var turn: TurnResult?
    for try await ev in p.streamTurn(system: "s", history: [.user("hi")], tools: [], toolChoice: .auto, maxTokens: 100) {
        switch ev {
        case .textDelta(let t): deltas.append(t)
        case .turn(let t): turn = t
        }
    }
    #expect(counter.value == 2)
    #expect(deltas.contains("完整回复"))
    #expect(turn?.content == [.text("完整回复")])
    #expect(turn?.stopReason == .endTurn)
    #expect(turn?.usage.inputTokens == 5)
    #expect(turn?.usage.outputTokens == 9)
}

@Test func nonStreamingParsesToolUse() async throws {
    let counter = Counter()
    let truncatedSSE = "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":1}}}"
    let fullMessage = """
    {"type":"message","content":[{"type":"tool_use","id":"tu_1","name":"write_file","input":{"path":"a.md","content":"x"}}],"stop_reason":"tool_use","usage":{"input_tokens":3,"output_tokens":4}}
    """
    StubProtocol.handler = { _ in
        let n = counter.bump()
        return n == 1
            ? (200, Data(truncatedSSE.utf8), ["Content-Type": "text/event-stream"])
            : (200, Data(fullMessage.utf8), ["Content-Type": "application/json"])
    }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(), retryBaseDelay: .milliseconds(1))
    var turn: TurnResult?
    for try await ev in p.streamTurn(system: "s", history: [.user("hi")], tools: [], toolChoice: .auto, maxTokens: 100) {
        if case .turn(let t) = ev { turn = t }
    }
    #expect(turn?.stopReason == .toolUse)
    #expect(turn?.toolUses.count == 1)
    #expect(turn?.toolUses.first?.name == "write_file")
    #expect(turn?.toolUses.first?.input["path"]?.stringValue == "a.md")
}

@Test func retriesExhaustedThrows() async {
    let counter = Counter()
    StubProtocol.handler = { _ in counter.bump(); return (503, Data(), [:]) }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(),
                              retryBaseDelay: .milliseconds(1), maxRetries: 2)
    await #expect(throws: ProviderError.overloadedRetriesExhausted) {
        for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], toolChoice: .auto, maxTokens: 10) {}
    }
    #expect(counter.value == 3)  // initial attempt + 2 retries
}

}

@Test func normalizesBaseURL() {
    #expect(AnthropicProvider.normalizedBaseURL(" https://api.z.ai/api/anthropic/ ")?.absoluteString == "https://api.z.ai/api/anthropic")
    #expect(AnthropicProvider.normalizedBaseURL("http://127.0.0.1:8080")?.absoluteString == "http://127.0.0.1:8080")
    #expect(AnthropicProvider.normalizedBaseURL("api.anthropic.com") == nil)
    #expect(AnthropicProvider.normalizedBaseURL("ftp://x.com") == nil)
    #expect(AnthropicProvider.normalizedBaseURL("https://") == nil)
}
