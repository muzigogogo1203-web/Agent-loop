import Foundation
import os

public struct OpenAIProvider: LLMProvider, LLMProviderRunDrivingV1 {
    let apiKey: String
    let model: String
    let session: URLSession
    let baseURL: URL
    let authScheme: ProviderAuthScheme
    let retryBaseDelay: Duration
    let maxRetries: Int
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "provider.openai")
    private static let streamingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AnthropicProvider.streamingTimeoutIntervalForRequest
        configuration.timeoutIntervalForResource = AnthropicProvider.streamingTimeoutIntervalForResource
        return URLSession(configuration: configuration)
    }()

    public init(
        apiKey: String,
        model: String,
        baseURL: URL = URL(string: "https://api.openai.com")!,
        authScheme: ProviderAuthScheme = .bearer,
        retryBaseDelay: Duration = .seconds(1),
        maxRetries: Int = 3
    ) {
        self.init(
            apiKey: apiKey,
            model: model,
            session: Self.streamingSession,
            baseURL: baseURL,
            authScheme: authScheme,
            retryBaseDelay: retryBaseDelay,
            maxRetries: maxRetries
        )
    }

    public init(
        apiKey: String,
        model: String,
        session: URLSession,
        baseURL: URL = URL(string: "https://api.openai.com")!,
        authScheme: ProviderAuthScheme = .bearer,
        retryBaseDelay: Duration = .seconds(1),
        maxRetries: Int = 3
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.baseURL = baseURL
        self.authScheme = authScheme
        self.retryBaseDelay = retryBaseDelay
        self.maxRetries = maxRetries
    }

    public static func requestBody(
        model: String,
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        toolChoice: ToolChoice = .auto,
        maxTokens: Int,
        stream: Bool = true
    ) -> JSONValue {
        var messages: [JSONValue] = [
            ["role": "system", "content": .string(system)],
        ]
        for message in history {
            messages.append(contentsOf: openAIMessages(from: message))
        }

        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(maxTokens)),
            "stream": .bool(stream),
            "messages": .array(messages),
        ]
        if !tools.isEmpty {
            body["tools"] = .array(tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": .string(tool.name),
                        "description": .string(tool.description),
                        "parameters": tool.inputSchema,
                    ],
                ]
            })
        }
        switch toolChoice {
        case .auto:
            break
        case .tool(let name):
            body["tool_choice"] = [
                "type": "function",
                "function": ["name": .string(name)],
            ]
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
        var request = URLRequest(url: baseURL.appending(path: "/v1/chat/completions"))
        request.httpMethod = "POST"
        authScheme.apply(to: &request, credential: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var attempt = 0
        var useNonStreaming = false
        var emittedTextDelta = false
        while true {
            attempt += 1
            request.httpBody = try encoder.encode(
                Self.requestBody(
                    model: model,
                    system: system,
                    history: history,
                    tools: tools,
                    toolChoice: toolChoice,
                    maxTokens: maxTokens,
                    stream: !useNonStreaming
                )
            )
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                if useNonStreaming {
                    var data = Data()
                    for try await byte in bytes { data.append(byte) }
                    try consumeNonStreaming(data, suppressMergedTextDelta: emittedTextDelta, continuation: continuation)
                    return
                }
                do {
                    try await consumeStream(bytes, continuation: continuation) { _ in
                        emittedTextDelta = true
                    }
                    return
                } catch let error as ProviderError {
                    guard case .malformedStream = error, attempt <= maxRetries else { throw error }
                    useNonStreaming = true
                    Self.logger.info("OpenAI stream malformed at attempt \(attempt, privacy: .public), falling back to non-streaming")
                }
            case 401, 403:
                throw ProviderError.unauthorized
            case 429, 500...599:
                guard attempt <= maxRetries else { throw ProviderError.overloadedRetriesExhausted }
                let retryAfterSeconds = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "retry-after").flatMap(Double.init)
                let delay: Duration
                if let seconds = retryAfterSeconds, seconds.isFinite, seconds >= 0 {
                    delay = .seconds(min(seconds, 60))
                } else {
                    delay = retryBaseDelay * (1 << (attempt - 1))
                }
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

    package func consumeNonStreaming(
        _ data: Data,
        suppressMergedTextDelta: Bool = false,
        continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation
    ) throws {
        let value = try Self.decodedJSON(data)
        if let error = value["error"] {
            throw ProviderError.apiError(
                type: error["type"]?.stringValue ?? error["code"]?.stringValue ?? "unknown",
                message: error["message"]?.stringValue ?? ""
            )
        }
        guard let message = value["choices"]?[0]?["message"] else {
            throw ProviderError.malformedStream("OpenAI response missing choices[0].message")
        }
        let content = Self.contentBlocks(fromOpenAIMessage: message)
        let usage = Usage(
            inputTokens: value["usage"]?["prompt_tokens"]?.intValue ?? 0,
            outputTokens: value["usage"]?["completion_tokens"]?.intValue ?? 0,
            cacheReadTokens: 0
        )
        let finish = value["choices"]?[0]?["finish_reason"]?.stringValue
        let turn = TurnResult(content: content, stopReason: Self.stopReason(finishReason: finish, blocks: content), usage: usage)
        let mergedText = content.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }.joined()
        if !mergedText.isEmpty && !suppressMergedTextDelta {
            continuation.yield(.textDelta(mergedText))
        }
        continuation.yield(.turn(turn))
    }

    private func consumeStream(
        _ bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation,
        onTextDelta: (String) -> Void = { _ in }
    ) async throws {
        var parser = SSELineParser()
        var accumulator = OpenAIStreamAccumulator()
        for try await line in bytes.lines {
            guard let raw = parser.consume(line: line) else { continue }
            let data = raw.data.trimmingCharacters(in: .whitespacesAndNewlines)
            if data == "[DONE]" {
                let turn = accumulator.finish()
                continuation.yield(.turn(turn))
                return
            }
            let value = try Self.decodedJSON(Data(data.utf8))
            if let error = value["error"] {
                throw ProviderError.apiError(
                    type: error["type"]?.stringValue ?? error["code"]?.stringValue ?? "unknown",
                    message: error["message"]?.stringValue ?? ""
                )
            }
            if let usage = value["usage"] {
                accumulator.setUsage(usage)
            }
            guard let choice = value["choices"]?[0] else { continue }
            if let delta = choice["delta"] {
                let text = try accumulator.consume(delta: delta)
                if !text.isEmpty {
                    onTextDelta(text)
                    continuation.yield(.textDelta(text))
                }
            }
            if let finish = choice["finish_reason"]?.stringValue {
                accumulator.setFinishReason(finish)
            }
        }
        throw ProviderError.malformedStream("OpenAI stream ended without [DONE]")
    }

    private static func openAIMessages(from message: APIMessage) -> [JSONValue] {
        switch message.role {
        case .user:
            var output: [JSONValue] = []
            let text = message.content.compactMap { block -> String? in
                if case .text(let text) = block { return text }
                return nil
            }.joined()
            if !text.isEmpty {
                output.append(["role": "user", "content": .string(text)])
            }
            for block in message.content {
                if case .toolResult(let id, let content, let isError) = block {
                    let outputContent = isError ? OpenAIResponsesProvider.toolErrorMarker + content : content
                    output.append(["role": "tool", "tool_call_id": .string(id), "content": .string(outputContent)])
                }
            }
            return output.isEmpty ? [["role": "user", "content": ""]] : output
        case .assistant:
            var textParts: [String] = []
            var toolCalls: [JSONValue] = []
            for block in message.content {
                switch block {
                case .text(let text):
                    textParts.append(text)
                case .toolUse(let id, let name, let input):
                    toolCalls.append([
                        "id": .string(id),
                        "type": "function",
                        "function": [
                            "name": .string(name),
                            "arguments": .string((try? input.encodedString()) ?? "{}"),
                        ],
                    ])
                case .toolResult, .unknown:
                    break
                }
            }
            var message: [String: JSONValue] = [
                "role": "assistant",
                "content": textParts.isEmpty ? .null : .string(textParts.joined()),
            ]
            if !toolCalls.isEmpty {
                message["tool_calls"] = .array(toolCalls)
            }
            return [.object(message)]
        }
    }

    private static func contentBlocks(fromOpenAIMessage message: JSONValue) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        if let text = message["content"]?.stringValue, !text.isEmpty {
            blocks.append(.text(text))
        }
        for call in message["tool_calls"]?.arrayValue ?? [] {
            guard call["type"]?.stringValue == "function" else { continue }
            let id = call["id"]?.stringValue ?? UUID().uuidString
            let function = call["function"]
            let name = function?["name"]?.stringValue ?? ""
            let arguments = function?["arguments"]?.stringValue ?? "{}"
            let input = (try? JSONValue.decoded(from: arguments)) ?? .object([:])
            blocks.append(.toolUse(id: id, name: name, input: input))
        }
        return blocks
    }

    fileprivate static func stopReason(finishReason: String?, blocks: [ContentBlock]) -> StopReason {
        if blocks.contains(where: { if case .toolUse = $0 { return true }; return false }) {
            return .toolUse
        }
        switch finishReason {
        case "stop": return .endTurn
        case "length": return .maxTokens
        case "content_filter": return .refusal
        case "tool_calls", "function_call": return .toolUse
        default: return .endTurn
        }
    }

    private static func decodedJSON(_ data: Data) throws -> JSONValue {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ProviderError.malformedStream("OpenAI response is not UTF-8")
        }
        return try JSONValue.decoded(from: text)
    }
}

private struct OpenAIStreamAccumulator {
    private struct ToolCall {
        var id = ""
        var name = ""
        var arguments = ""
    }

    private var text = ""
    private var toolCalls: [Int: ToolCall] = [:]
    private var finishReason: String?
    private var usage = Usage()

    mutating func consume(delta: JSONValue) throws -> String {
        var emitted = ""
        if let content = delta["content"]?.stringValue {
            text += content
            emitted += content
        }
        for callDelta in delta["tool_calls"]?.arrayValue ?? [] {
            let index = callDelta["index"]?.intValue ?? 0
            var call = toolCalls[index] ?? ToolCall()
            if let id = callDelta["id"]?.stringValue {
                call.id = id
            }
            if let name = callDelta["function"]?["name"]?.stringValue {
                call.name += name
            }
            if let arguments = callDelta["function"]?["arguments"]?.stringValue {
                call.arguments += arguments
            }
            toolCalls[index] = call
        }
        return emitted
    }

    mutating func setFinishReason(_ reason: String) {
        finishReason = reason
    }

    mutating func setUsage(_ value: JSONValue) {
        usage.inputTokens = value["prompt_tokens"]?.intValue ?? usage.inputTokens
        usage.outputTokens = value["completion_tokens"]?.intValue ?? usage.outputTokens
    }

    func finish() -> TurnResult {
        var blocks: [ContentBlock] = []
        if !text.isEmpty {
            blocks.append(.text(text))
        }
        for index in toolCalls.keys.sorted() {
            guard let call = toolCalls[index] else { continue }
            let input = (try? JSONValue.decoded(from: call.arguments.isEmpty ? "{}" : call.arguments)) ?? .object([:])
            blocks.append(.toolUse(id: call.id.isEmpty ? UUID().uuidString : call.id, name: call.name, input: input))
        }
        return TurnResult(
            content: blocks,
            stopReason: OpenAIProvider.stopReason(finishReason: finishReason, blocks: blocks),
            usage: usage
        )
    }
}
