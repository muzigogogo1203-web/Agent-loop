import Foundation
import Testing
import AgentLoopCore

@Test func openAIChatGPTAuthorizationURLMatchesCodexFlow() throws {
    let url = try #require(OpenAIChatGPTAuth.authorizationURL(
        state: "state-123",
        codeChallenge: "challenge-456"
    ))
    let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    let query = Dictionary(uniqueKeysWithValues: items.compactMap { item in
        item.value.map { (item.name, $0) }
    })

    #expect(url.host == "auth.openai.com")
    #expect(query["client_id"] == OpenAIChatGPTAuth.clientID)
    #expect(query["redirect_uri"] == OpenAIChatGPTAuth.redirectURI)
    #expect(query["scope"] == OpenAIChatGPTAuth.scope)
    #expect(query["code_challenge"] == "challenge-456")
    #expect(query["code_challenge_method"] == "S256")
    #expect(query["id_token_add_organizations"] == "true")
    #expect(query["codex_cli_simplified_flow"] == "true")
    #expect(query["originator"] == OpenAIChatGPTAuth.originator)
    #expect(query["codex_streamlined_login"] == nil)
}

@Test func openAIChatGPTTokenRequestUsesPKCE() throws {
    let body = try #require(OpenAIChatGPTAuth.tokenRequestBody(
        code: "auth-code",
        codeVerifier: "verifier"
    ))
    let encoded = try #require(String(data: body, encoding: .utf8))
    let items = try #require(URLComponents(string: "https://local.invalid/?\(encoded)")?.queryItems)
    let form = Dictionary(uniqueKeysWithValues: items.compactMap { item in
        item.value.map { (item.name, $0) }
    })

    #expect(form["grant_type"] == "authorization_code")
    #expect(form["code"] == "auth-code")
    #expect(form["redirect_uri"] == OpenAIChatGPTAuth.redirectURI)
    #expect(form["client_id"] == OpenAIChatGPTAuth.clientID)
    #expect(form["code_verifier"] == "verifier")
}

@Test func openAIChatGPTRefreshTokenRequestUsesCodexScope() throws {
    let body = try #require(OpenAIChatGPTAuth.refreshTokenRequestBody(refreshToken: "refresh token"))
    let encoded = try #require(String(data: body, encoding: .utf8))
    let items = try #require(URLComponents(string: "https://local.invalid/?\(encoded)")?.queryItems)
    let form = Dictionary(uniqueKeysWithValues: items.compactMap { item in
        item.value.map { (item.name, $0) }
    })

    #expect(form["grant_type"] == "refresh_token")
    #expect(form["client_id"] == OpenAIChatGPTAuth.clientID)
    #expect(form["refresh_token"] == "refresh token")
    #expect(form["scope"] == "openid profile email")
    #expect(encoded.contains("%20"))
    #expect(!encoded.contains("refresh token"))
}

@Test func openAIChatGPTAccountIDComesFromIDTokenClaims() throws {
    let header = try jwtPart(["alg": "none"])
    let payload = try jwtPart([
        "https://api.openai.com/auth": ["chatgpt_account_id": "account-123"]
    ])
    let token = "\(header).\(payload).signature"

    #expect(OpenAIChatGPTAuth.chatGPTAccountID(idToken: token) == "account-123")
}

@Test func openAIResponsesRequestPreservesConversationAndTools() throws {
    let body = OpenAIResponsesProvider.requestBody(
        model: "gpt-5.4",
        system: "system",
        history: [
            .user("build it"),
            .assistant([.toolUse(id: "call-1", name: "read_file", input: ["path": "a.md"])]),
            .user(toolResults: [.toolResult(toolUseId: "call-1", content: "done", isError: false)]),
        ],
        tools: [ToolDef(name: "read_file", description: "Read", inputSchema: ["type": "object"])],
        toolChoice: .tool(name: "read_file"),
        maxTokens: 500
    )

    #expect(body["model"]?.stringValue == "gpt-5.4")
    #expect(body["instructions"]?.stringValue == "system")
    #expect(body["stream"]?.boolValue == true)
    #expect(body["store"]?.boolValue == false)
    #expect(body["input"]?[0]?["content"]?[0]?["type"]?.stringValue == "input_text")
    #expect(body["input"]?[1]?["type"]?.stringValue == "function_call")
    #expect(body["input"]?[2]?["type"]?.stringValue == "function_call_output")
    #expect(body["tools"]?[0]?["name"]?.stringValue == "read_file")
    #expect(body["tool_choice"]?["name"]?.stringValue == "read_file")
}

@Test func openAIResponsesRequestMarksToolResultErrors() throws {
    let body = OpenAIResponsesProvider.requestBody(
        model: "gpt-5.4",
        system: "system",
        history: [
            .assistant([.toolUse(id: "call-1", name: "read_file", input: ["path": "a.md"])]),
            .user(toolResults: [.toolResult(toolUseId: "call-1", content: "failed", isError: true)]),
        ],
        tools: [],
        maxTokens: 500
    )

    #expect(body["input"]?[1]?["output"]?.stringValue == "[tool_error] failed")
}

private final class OpenAIResponsesStubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data, [String: String]))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, data, headers) = Self.handler!(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class HeaderRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String?) {
        lock.withLock {
            values.append(value ?? "")
        }
    }

    var snapshot: [String] {
        lock.withLock { values }
    }
}

private func openAIResponsesStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OpenAIResponsesStubProtocol.self]
    return URLSession(configuration: configuration)
}

@Suite(.serialized) struct OpenAIResponsesProviderRefreshTests {
    @Test func openAIResponsesRefreshesOnceAfterUnauthorizedAndRetriesWithNewToken() async throws {
        let requestCounter = Counter()
        let refreshCounter = Counter()
        let headers = HeaderRecorder()
        let okSSE = """
        data: {"type":"response.completed","response":{"usage":{"input_tokens":1,"output_tokens":2}}}
        """
        OpenAIResponsesStubProtocol.handler = { request in
            headers.append(request.value(forHTTPHeaderField: "Authorization"))
            let count = requestCounter.bump()
            return count == 1
                ? (401, Data(), [:])
                : (200, Data(okSSE.utf8), ["Content-Type": "text/event-stream"])
        }
        let provider = OpenAIResponsesProvider(
            accessToken: "old-token",
            accountID: "account-1",
            model: "gpt-5.4",
            session: openAIResponsesStubbedSession(),
            retryBaseDelay: .milliseconds(1),
            tokenRefresher: {
                refreshCounter.bump()
                return "new-token"
            }
        )

        for try await _ in provider.streamTurn(system: "s", history: [.user("hi")], tools: [], toolChoice: .auto, maxTokens: 10) {}

        #expect(requestCounter.value == 2)
        #expect(refreshCounter.value == 1)
        #expect(headers.snapshot == ["Bearer old-token", "Bearer new-token"])
    }

    @Test func openAIResponsesThrowsUnauthorizedWhenRefreshRetryIsStillUnauthorized() async {
        let requestCounter = Counter()
        let refreshCounter = Counter()
        OpenAIResponsesStubProtocol.handler = { _ in
            requestCounter.bump()
            return (401, Data(), [:])
        }
        let provider = OpenAIResponsesProvider(
            accessToken: "old-token",
            accountID: "account-1",
            model: "gpt-5.4",
            session: openAIResponsesStubbedSession(),
            retryBaseDelay: .milliseconds(1),
            tokenRefresher: {
                refreshCounter.bump()
                return "new-token"
            }
        )

        await #expect(throws: ProviderError.unauthorized) {
            for try await _ in provider.streamTurn(system: "s", history: [.user("hi")], tools: [], toolChoice: .auto, maxTokens: 10) {}
        }
        #expect(requestCounter.value == 2)
        #expect(refreshCounter.value == 1)
    }
}

private func jwtPart(_ object: [String: Any]) throws -> String {
    try JSONSerialization.data(withJSONObject: object)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
