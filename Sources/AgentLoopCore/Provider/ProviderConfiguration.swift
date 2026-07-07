import Foundation

public enum ProviderAPIFormat: String, CaseIterable, Sendable {
    case anthropicMessages = "anthropic_messages"
    case openAIChatCompletions = "openai_chat_completions"
}

public enum ProviderAuthScheme: String, CaseIterable, Sendable {
    case automatic = "automatic"
    case xAPIKey = "x_api_key"
    case bearer = "bearer"
    case oauthBearer = "oauth_bearer"

    public func resolved(for format: ProviderAPIFormat) -> ProviderAuthScheme {
        switch self {
        case .automatic:
            switch format {
            case .anthropicMessages:
                return .xAPIKey
            case .openAIChatCompletions:
                return .bearer
            }
        case .xAPIKey, .bearer, .oauthBearer:
            return self
        }
    }

    public func apply(to request: inout URLRequest, credential: String) {
        let trimmed = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .automatic:
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        case .xAPIKey:
            request.setValue(trimmed, forHTTPHeaderField: "x-api-key")
        case .bearer, .oauthBearer:
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
    }
}

public enum ProviderCredentialSource: String, CaseIterable, Sendable {
    case apiKey = "api_key"
    case webLogin = "web_login"
}

public enum ProviderEndpoint {
    /// Normalize user-entered API roots. Users often paste a concrete `/v1` root
    /// while providers append their own protocol-specific path.
    public static func normalizedBaseURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if s.hasSuffix("/v1") {
            s.removeLast(3)
        }
        guard let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil else { return nil }
        return url
    }
}

public enum LLMProviderFactory {
    public static func make(
        format: ProviderAPIFormat,
        authScheme: ProviderAuthScheme,
        credential: String,
        model: String,
        baseURL: URL
    ) -> any LLMProvider {
        let resolvedAuthScheme = authScheme.resolved(for: format)
        switch format {
        case .anthropicMessages:
            return AnthropicProvider(apiKey: credential, model: model, baseURL: baseURL, authScheme: resolvedAuthScheme)
        case .openAIChatCompletions:
            return OpenAIProvider(apiKey: credential, model: model, baseURL: baseURL, authScheme: resolvedAuthScheme)
        }
    }
}
