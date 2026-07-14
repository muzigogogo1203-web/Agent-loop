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

private func jwtPart(_ object: [String: Any]) throws -> String {
    try JSONSerialization.data(withJSONObject: object)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
