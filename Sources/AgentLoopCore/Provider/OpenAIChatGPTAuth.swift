import Foundation

public enum OpenAIChatGPTAuth {
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    public static let callbackPort: UInt16 = 1455
    public static let redirectURI = "http://localhost:1455/auth/callback"
    public static let authorizationEndpoint = URL(string: "https://auth.openai.com/oauth/authorize")!
    public static let tokenEndpoint = URL(string: "https://auth.openai.com/oauth/token")!
    public static let responsesBaseURL = URL(string: "https://chatgpt.com/backend-api/codex")!
    public static let scope = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    public static let originator = "codex_cli_rs"

    public static func authorizationURL(state: String, codeChallenge: String) -> URL? {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "originator", value: originator),
        ]
        return components?.url
    }

    public static func tokenRequestBody(code: String, codeVerifier: String) -> Data? {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
        ]
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    public static func refreshTokenRequestBody(refreshToken: String) -> Data? {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "scope", value: "openid profile email"),
        ]
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    public static func chatGPTAccountID(idToken: String, accessToken: String? = nil) -> String? {
        accountID(in: idToken) ?? accessToken.flatMap(accountID(in:))
    }

    private static func accountID(in token: String) -> String? {
        guard let claims = jwtClaims(token) else { return nil }
        if let accountID = nonEmptyString(claims["chatgpt_account_id"]) {
            return accountID
        }
        for namespace in ["https://api.openai.com/auth", "https://openai.com/auth"] {
            if let nested = claims[namespace] as? [String: Any],
               let accountID = nonEmptyString(nested["chatgpt_account_id"]) {
                return accountID
            }
        }
        return nil
    }

    private static func jwtClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data),
              let claims = object as? [String: Any] else { return nil }
        return claims
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
