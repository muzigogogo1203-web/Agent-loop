import Foundation
import os

public struct AnthropicProvider: LLMProvider {
    let apiKey: String
    let model: String
    let session: URLSession
    let baseURL: URL
    let retryBaseDelay: Duration
    let maxRetries: Int
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "provider")

    public init(apiKey: String, model: String, session: URLSession = .shared,
                baseURL: URL = URL(string: "https://api.anthropic.com")!,
                retryBaseDelay: Duration = .seconds(1), maxRetries: Int = 3) {
        self.apiKey = apiKey; self.model = model; self.session = session
        self.baseURL = baseURL; self.retryBaseDelay = retryBaseDelay; self.maxRetries = maxRetries
    }

    /// Pure function — directly unit-testable.
    /// system is encoded as a block array with cache_control (spec §6.3 cache-first design).
    public static func requestBody(model: String, system: String, history: [APIMessage],
                                   tools: [ToolDef], maxTokens: Int) -> JSONValue {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(maxTokens)),
            "stream": .bool(true),
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
        return .object(body)
    }

    public func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                           maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, history: history, tools: tools,
                                  maxTokens: maxTokens, continuation: continuation)
                    continuation.finish()
                } catch {
                    Self.logger.error("provider final error: \(Self.readableError(error), privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, history: [APIMessage], tools: [ToolDef], maxTokens: Int,
                     continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/v1/messages"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // spec §6.3 requires byte-deterministic prefix across process restarts for prompt-cache hits;
        // Dictionary iteration order is per-process seeded.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(
            Self.requestBody(model: model, system: system, history: history,
                             tools: tools, maxTokens: maxTokens))

        var attempt = 0
        while true {
            attempt += 1
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                try await consumeStream(bytes, continuation: continuation)
                return
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

    private func consumeStream(_ bytes: URLSession.AsyncBytes,
                               continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) async throws {
        var parser = SSELineParser()
        var acc = TurnAccumulator()
        for try await line in bytes.lines {
            guard let raw = parser.consume(line: line) else { continue }
            try acc.consume(raw) { continuation.yield(.textDelta($0)) }
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
    /// 支持官方端点、Anthropic Messages API 兼容的中转网关与本地代理。
    static func normalizedBaseURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil else { return nil }
        return url
    }
}
