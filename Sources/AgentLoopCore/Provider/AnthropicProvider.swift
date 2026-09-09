import Foundation
import os

public struct AnthropicProvider: LLMProvider, LLMProviderRunDrivingV1 {
    let apiKey: String
    let model: String
    let session: URLSession
    let baseURL: URL
    let authScheme: ProviderAuthScheme
    let retryBaseDelay: Duration
    let maxRetries: Int
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "provider")
    package static let streamingTimeoutIntervalForRequest: TimeInterval = 300
    package static let streamingTimeoutIntervalForResource: TimeInterval = 3600
    private static let streamingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = streamingTimeoutIntervalForRequest
        configuration.timeoutIntervalForResource = streamingTimeoutIntervalForResource
        return URLSession(configuration: configuration)
    }()

    public init(apiKey: String, model: String,
                baseURL: URL = URL(string: "https://api.anthropic.com")!,
                authScheme: ProviderAuthScheme = .xAPIKey,
                retryBaseDelay: Duration = .seconds(1), maxRetries: Int = 3) {
        self.init(apiKey: apiKey, model: model, session: Self.streamingSession,
                  baseURL: baseURL, authScheme: authScheme, retryBaseDelay: retryBaseDelay, maxRetries: maxRetries)
    }

    public init(apiKey: String, model: String, session: URLSession,
                baseURL: URL = URL(string: "https://api.anthropic.com")!,
                authScheme: ProviderAuthScheme = .xAPIKey,
                retryBaseDelay: Duration = .seconds(1), maxRetries: Int = 3) {
        self.apiKey = apiKey; self.model = model; self.session = session
        self.baseURL = baseURL; self.authScheme = authScheme
        self.retryBaseDelay = retryBaseDelay; self.maxRetries = maxRetries
    }

    /// Pure function — directly unit-testable.
    /// system is encoded as a block array with cache_control (spec §6.3 cache-first design).
    public static func requestBody(model: String, system: String, history: [APIMessage],
                                   tools: [ToolDef], toolChoice: ToolChoice = .auto,
                                   maxTokens: Int, stream: Bool = true) -> JSONValue {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(maxTokens)),
            "stream": .bool(stream),
            "system": .array([[
                "type": "text", "text": .string(system),
                "cache_control": ["type": "ephemeral"],
            ]]),
            "messages": .array(history.map { msg in
                ["role": .string(msg.role.rawValue),
                 "content": .array(msg.content.map(\.jsonValue))]
            }),
        ]
        if !tools.isEmpty {
            body["tools"] = .array(tools.map {
                ["name": .string($0.name), "description": .string($0.description),
                 "input_schema": $0.inputSchema]
            })
        }
        switch toolChoice {
        case .auto:
            break
        case .tool(let name):
            body["tool_choice"] = ["type": "tool", "name": .string(name)]
        }
        return .object(body)
    }

    public func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                           toolChoice: ToolChoice, maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        startTurn(
            system: system,
            history: history,
            tools: tools,
            toolChoice: toolChoice,
            maxTokens: maxTokens
        ).events
    }

    package func startTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> LLMProviderTurnRunV1 {
        makeLLMProviderTurnRunV1 { continuation in
            do {
                try await run(
                    system: system,
                    history: history,
                    tools: tools,
                    toolChoice: toolChoice,
                    maxTokens: maxTokens,
                    continuation: continuation
                )
            } catch {
                Self.logger.error("provider final error: \(Self.readableError(error), privacy: .public)")
                throw error
            }
        }
    }

    private func run(system: String, history: [APIMessage], tools: [ToolDef],
                     toolChoice: ToolChoice, maxTokens: Int,
                     continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/v1/messages"))
        request.httpMethod = "POST"
        authScheme.apply(to: &request, credential: apiKey)
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // spec §6.3 requires byte-deterministic prefix across process restarts for prompt-cache hits;
        // Dictionary iteration order is per-process seeded.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var attempt = 0
        // 网关对大体积生成频繁掐断 SSE 流；断流后本轮剩余尝试切换非流式，
        // 避免「重试→再断流→全量重生成」恶性循环。首选路径永远是流式。
        var useNonStreaming = false
        // 断流前已流出过 textDelta 时，兜底不再重发合并全文（消费方按 turn 取权威正文，
        // 重发会让「delta 累积型」消费方拼出重复文本）
        var emittedTextDelta = false
        while true {
            attempt += 1
            request.httpBody = try encoder.encode(
                Self.requestBody(model: model, system: system, history: history,
                                 tools: tools, toolChoice: toolChoice, maxTokens: maxTokens,
                                 stream: !useNonStreaming))
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                if useNonStreaming {
                    var data = Data()
                    for try await byte in bytes { data.append(byte) }
                    try consumeNonStreaming(data, suppressMergedTextDelta: emittedTextDelta,
                                            continuation: continuation)
                    return
                }
                do {
                    try await consumeStream(bytes, continuation: continuation,
                                            onTextDelta: { _ in emittedTextDelta = true })
                    return
                } catch let error as ProviderError {
                    guard case .malformedStream = error, attempt <= maxRetries else { throw error }
                    useNonStreaming = true
                    Self.logger.info("stream malformed at attempt \(attempt, privacy: .public), falling back to non-streaming")
                }
            case 401, 403:
                throw ProviderError.unauthorized
            case 429, 500...599:
                guard attempt <= maxRetries else { throw ProviderError.overloadedRetriesExhausted }
                let retryAfterSeconds = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "retry-after").flatMap(Double.init)
                let delay: Duration
                if let s = retryAfterSeconds, s.isFinite, s >= 0 {
                    delay = .seconds(min(s, 60))
                } else {
                    // Exponential backoff using DurationProtocol multiplication (full-width arithmetic;
                    // the components-decomposition approach traps for base delays >= ~9.3s).
                    delay = retryBaseDelay * (1 << (attempt - 1))
                }
                Self.logger.info("provider retry status \(status, privacy: .public), attempt \(attempt, privacy: .public)")
                try await Task.sleep(for: delay)
            default:
                var body = ""
                for try await line in bytes.lines {
                    body += line
                    if body.count > 2000 { break }
                }
                throw ProviderError.http(status: status, body: body)
            }
        }
    }

    /// 非流式兜底：解析完整 message JSON。断流前无任何增量时，先把全部 text 块合并
    /// yield 一次 textDelta（UI 连续性）；已有部分增量则跳过（防 delta 累积型消费方重复拼接），
    /// 再 yield .turn。仅在流式断流后作为同轮兜底使用。
    package func consumeNonStreaming(_ data: Data,
                                     suppressMergedTextDelta: Bool = false,
                                     continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) throws {
        guard let text = String(data: data, encoding: .utf8),
              let v = try? JSONValue.decoded(from: text) else {
            throw ProviderError.malformedStream("non-streaming response is not valid JSON")
        }
        if v["type"]?.stringValue == "error" {
            throw ProviderError.apiError(type: v["error"]?["type"]?.stringValue ?? "unknown",
                                         message: v["error"]?["message"]?.stringValue ?? "")
        }
        guard let contentArray = v["content"]?.arrayValue else {
            throw ProviderError.malformedStream("non-streaming response missing content")
        }
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let blocks: [ContentBlock] = try contentArray.map {
            try decoder.decode(ContentBlock.self, from: try encoder.encode($0))
        }
        var usage = Usage()
        usage.inputTokens = v["usage"]?["input_tokens"]?.intValue ?? 0
        usage.outputTokens = v["usage"]?["output_tokens"]?.intValue ?? 0
        usage.cacheReadTokens = v["usage"]?["cache_read_input_tokens"]?.intValue ?? 0
        // 缺省对齐 TurnAccumulator 的 `stopReason ?? .endTurn`
        let turn = TurnResult(
            content: blocks,
            stopReason: v["stop_reason"]?.stringValue.map { StopReason(apiValue: $0) } ?? .endTurn,
            usage: usage)
        let mergedText = blocks.compactMap { block -> String? in
            if case .text(let t) = block { return t }
            return nil
        }.joined()
        if !mergedText.isEmpty && !suppressMergedTextDelta {
            continuation.yield(.textDelta(mergedText))
        }
        Self.logger.info("non-streaming fallback stop_reason \(String(describing: turn.stopReason), privacy: .public)")
        continuation.yield(.turn(turn))
    }

    private func consumeStream(_ bytes: URLSession.AsyncBytes,
                               continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation,
                               onTextDelta: (String) -> Void = { _ in }) async throws {
        var parser = SSELineParser()
        var acc = TurnAccumulator()
        for try await line in bytes.lines {
            guard let raw = parser.consume(line: line) else { continue }
            try acc.consume(raw) { delta in
                onTextDelta(delta)
                continuation.yield(.textDelta(delta))
            }
            if let turn = acc.finishedTurn {
                Self.logger.info("provider stop_reason \(String(describing: turn.stopReason), privacy: .public)")
                continuation.yield(.turn(turn))
                return
            }
        }
        // Stream ended without message_stop
        if acc.finishedTurn == nil {
            throw ProviderError.malformedStream("stream ended without message_stop")
        }
    }

    private static func readableError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return String(describing: error)
    }
}

public extension AnthropicProvider {
    /// 规范化用户输入的 API 端点：去空白、去尾部斜杠；仅接受带主机的 http/https。
    /// 支持官方端点、中转网关与本地代理。
    static func normalizedBaseURL(_ raw: String) -> URL? {
        ProviderEndpoint.normalizedBaseURL(raw)
    }
}
