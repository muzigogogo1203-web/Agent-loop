import Foundation
import os

/// OpenAI Responses transport used by ChatGPT/Codex OAuth credentials.
/// API-key based OpenAI-compatible gateways continue to use `OpenAIProvider`.
public struct OpenAIResponsesProvider: LLMProvider, LLMProviderRunDrivingV1 {
    let accessToken: String
    let accountID: String
    let model: String
    let session: URLSession
    let baseURL: URL
    let retryBaseDelay: Duration
    let maxRetries: Int
    let tokenRefresher: (@Sendable () async throws -> String)?

    static let toolErrorMarker = "[tool_error] "
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "provider.openai.responses")
    private static let streamingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AnthropicProvider.streamingTimeoutIntervalForRequest
        configuration.timeoutIntervalForResource = AnthropicProvider.streamingTimeoutIntervalForResource
        return URLSession(configuration: configuration)
    }()

    public init(
        accessToken: String,
        accountID: String,
        model: String,
        baseURL: URL = OpenAIChatGPTAuth.responsesBaseURL,
        retryBaseDelay: Duration = .seconds(1),
        maxRetries: Int = 3,
        tokenRefresher: (@Sendable () async throws -> String)? = nil
    ) {
        self.init(
            accessToken: accessToken,
            accountID: accountID,
            model: model,
            session: Self.streamingSession,
            baseURL: baseURL,
            retryBaseDelay: retryBaseDelay,
            maxRetries: maxRetries,
            tokenRefresher: tokenRefresher
        )
    }

    public init(
        accessToken: String,
        accountID: String,
        model: String,
        session: URLSession,
        baseURL: URL = OpenAIChatGPTAuth.responsesBaseURL,
        retryBaseDelay: Duration = .seconds(1),
        maxRetries: Int = 3,
        tokenRefresher: (@Sendable () async throws -> String)? = nil
    ) {
        self.accessToken = accessToken
        self.accountID = accountID
        self.model = model
        self.session = session
        self.baseURL = baseURL
        self.retryBaseDelay = retryBaseDelay
        self.maxRetries = maxRetries
        self.tokenRefresher = tokenRefresher
    }

    public static func requestBody(
        model: String,
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice = .auto,
        maxTokens _: Int
    ) -> JSONValue {
        // ChatGPT's Codex backend owns the output limit and rejects the public
        // Responses API's `max_output_tokens` field. Keep the argument in this
        // adapter's API to match LLMProvider, but do not serialize it.
        var body: [String: JSONValue] = [
            "model": .string(model),
            "instructions": .string(system),
            "input": .array(inputItems(from: history)),
            "parallel_tool_calls": .bool(true),
            "store": .bool(false),
            "stream": .bool(true),
        ]
        if !tools.isEmpty {
            body["tools"] = .array(tools.map { tool in
                [
                    "type": "function",
                    "name": .string(tool.name),
                    "description": .string(tool.description),
                    "parameters": tool.inputSchema,
                    "strict": false,
                ]
            })
        }
        switch toolChoice {
        case .auto:
            body["tool_choice"] = "auto"
        case .tool(let name):
            body["tool_choice"] = ["type": "function", "name": .string(name)]
        }
        return .object(body)
    }

    public func streamTurn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
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
                Self.logger.error("provider final error: \(String(describing: error), privacy: .public)")
                throw error
            }
        }
    }

    private func run(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice,
        maxTokens: Int,
        continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    ) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(
            Self.requestBody(
                model: model,
                system: system,
                history: history,
                tools: tools,
                toolChoice: toolChoice,
                maxTokens: maxTokens
            )
        )

        var retryAttempt = 0
        var currentAccessToken = accessToken
        var refreshedThisCall = false
        while true {
            let request = makeRequest(accessToken: currentAccessToken, body: body)
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                try await consumeStream(bytes, continuation: continuation)
                return
            case 401, 403:
                guard let tokenRefresher, !refreshedThisCall else {
                    throw ProviderError.unauthorized
                }
                currentAccessToken = try await tokenRefresher()
                refreshedThisCall = true
                continue
            case 429, 500...599:
                retryAttempt += 1
                guard retryAttempt <= maxRetries else { throw ProviderError.overloadedRetriesExhausted }
                let retryAfterSeconds = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "retry-after").flatMap(Double.init)
                let delay: Duration
                if let seconds = retryAfterSeconds, seconds.isFinite, seconds >= 0 {
                    delay = .seconds(min(seconds, 60))
                } else {
                    delay = retryBaseDelay * (1 << (retryAttempt - 1))
                }
                try await Task.sleep(for: delay)
            default:
                var body = ""
                for try await line in bytes.lines {
                    body += line
                    if body.count > 2_000 { break }
                }
                throw ProviderError.http(status: status, body: body)
            }
        }
    }

    private func makeRequest(accessToken: String, body: Data) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "responses"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(OpenAIChatGPTAuth.originator, forHTTPHeaderField: "originator")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        return request
    }

    private func consumeStream(
        _ bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    ) async throws {
        var parser = SSELineParser()
        var accumulator = ResponsesAccumulator()
        for try await line in bytes.lines {
            guard let raw = parser.consume(line: line), !raw.data.isEmpty else { continue }
            let value = try JSONValue.decoded(from: raw.data)
            let eventType = value["type"]?.stringValue ?? raw.event
            if let error = value["error"] {
                throw ProviderError.apiError(
                    type: error["type"]?.stringValue ?? error["code"]?.stringValue ?? "unknown",
                    message: error["message"]?.stringValue ?? ""
                )
            }
            switch eventType {
            case "response.output_text.delta":
                if let delta = value["delta"]?.stringValue, !delta.isEmpty {
                    accumulator.appendText(delta)
                    continuation.yield(.textDelta(delta))
                }
            case "response.output_item.added":
                accumulator.add(item: value["item"])
            case "response.function_call_arguments.delta":
                accumulator.appendArguments(
                    itemID: value["item_id"]?.stringValue,
                    delta: value["delta"]?.stringValue ?? ""
                )
            case "response.output_item.done":
                accumulator.finish(item: value["item"])
            case "response.completed":
                accumulator.setUsage(value["response"]?["usage"])
                continuation.yield(.turn(accumulator.turnResult()))
                return
            case "response.failed", "error":
                let error = value["response"]?["error"] ?? value["error"]
                throw ProviderError.apiError(
                    type: error?["type"]?.stringValue ?? error?["code"]?.stringValue ?? "response_failed",
                    message: error?["message"]?.stringValue ?? "OpenAI Responses request failed"
                )
            default:
                continue
            }
        }
        throw ProviderError.malformedStream("OpenAI Responses stream ended without response.completed")
    }

    private static func inputItems(from history: [APIMessage]) -> [JSONValue] {
        var items: [JSONValue] = []
        for message in history {
            switch message.role {
            case .user:
                let text = message.content.compactMap { block -> String? in
                    if case .text(let text) = block { return text }
                    return nil
                }.joined()
                if !text.isEmpty {
                    items.append([
                        "role": "user",
                        "content": [["type": "input_text", "text": .string(text)]],
                    ])
                }
                for block in message.content {
                    if case .toolResult(let id, let content, let isError) = block {
                        // Responses function_call_output has no native error field; mark text so the model can see failed tool calls.
                        let output = isError ? toolErrorMarker + content : content
                        items.append([
                            "type": "function_call_output",
                            "call_id": .string(id),
                            "output": .string(output),
                        ])
                    }
                }
            case .assistant:
                let text = message.content.compactMap { block -> String? in
                    if case .text(let text) = block { return text }
                    return nil
                }.joined()
                if !text.isEmpty {
                    items.append([
                        "role": "assistant",
                        "content": [["type": "output_text", "text": .string(text)]],
                    ])
                }
                for block in message.content {
                    if case .toolUse(let id, let name, let input) = block {
                        items.append([
                            "type": "function_call",
                            "call_id": .string(id),
                            "name": .string(name),
                            "arguments": .string((try? input.encodedString()) ?? "{}"),
                        ])
                    }
                }
            }
        }
        return items
    }
}

private struct ResponsesAccumulator {
    private struct FunctionCall {
        var callID = ""
        var name = ""
        var arguments = ""
    }

    private var text = ""
    private var calls: [String: FunctionCall] = [:]
    private var callOrder: [String] = []
    private var usage = Usage()

    mutating func appendText(_ delta: String) {
        text += delta
    }

    mutating func add(item: JSONValue?) {
        guard item?["type"]?.stringValue == "function_call" else { return }
        upsert(item: item, replaceArguments: false)
    }

    mutating func appendArguments(itemID: String?, delta: String) {
        guard let itemID, !itemID.isEmpty else { return }
        if calls[itemID] == nil {
            calls[itemID] = FunctionCall()
            callOrder.append(itemID)
        }
        calls[itemID]?.arguments += delta
    }

    mutating func finish(item: JSONValue?) {
        guard let item else { return }
        switch item["type"]?.stringValue {
        case "function_call":
            upsert(item: item, replaceArguments: true)
        case "message":
            if text.isEmpty {
                let completedText = (item["content"]?.arrayValue ?? []).compactMap { content -> String? in
                    guard content["type"]?.stringValue == "output_text" else { return nil }
                    return content["text"]?.stringValue
                }.joined()
                text = completedText
            }
        default:
            break
        }
    }

    mutating func setUsage(_ value: JSONValue?) {
        usage.inputTokens = value?["input_tokens"]?.intValue ?? usage.inputTokens
        usage.outputTokens = value?["output_tokens"]?.intValue ?? usage.outputTokens
        usage.cacheReadTokens = value?["input_tokens_details"]?["cached_tokens"]?.intValue ?? usage.cacheReadTokens
    }

    func turnResult() -> TurnResult {
        var blocks: [ContentBlock] = []
        if !text.isEmpty {
            blocks.append(.text(text))
        }
        for itemID in callOrder {
            guard let call = calls[itemID] else { continue }
            let input = (try? JSONValue.decoded(from: call.arguments.isEmpty ? "{}" : call.arguments)) ?? .object([:])
            blocks.append(.toolUse(
                id: call.callID.isEmpty ? itemID : call.callID,
                name: call.name,
                input: input
            ))
        }
        return TurnResult(
            content: blocks,
            stopReason: calls.isEmpty ? .endTurn : .toolUse,
            usage: usage
        )
    }

    private mutating func upsert(item: JSONValue?, replaceArguments: Bool) {
        guard let item else { return }
        let itemID = item["id"]?.stringValue ?? item["call_id"]?.stringValue ?? UUID().uuidString
        if calls[itemID] == nil {
            calls[itemID] = FunctionCall()
            callOrder.append(itemID)
        }
        if let callID = item["call_id"]?.stringValue, !callID.isEmpty {
            calls[itemID]?.callID = callID
        }
        if let name = item["name"]?.stringValue, !name.isEmpty {
            calls[itemID]?.name = name
        }
        if replaceArguments, let arguments = item["arguments"]?.stringValue, !arguments.isEmpty {
            calls[itemID]?.arguments = arguments
        }
    }
}
