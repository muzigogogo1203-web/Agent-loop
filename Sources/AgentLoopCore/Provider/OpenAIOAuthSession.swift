import Foundation

public protocol CredentialStore: Sendable {
    func set(_ value: String, account: String) throws
    func get(account: String) throws -> String?
    func delete(account: String) throws
}

public actor OpenAIOAuthSession {
    private let store: any CredentialStore
    private let accessTokenAccount: String
    private let refreshTokenAccount: String
    private let idTokenAccount: String
    private let chatGPTAccountIDAccount: String
    private let tokenEndpoint: URL
    private let session: URLSession
    private let onPermanentFailure: (@Sendable () -> Void)?
    private var inFlight: Task<String, Error>?

    public init(
        store: any CredentialStore,
        accessTokenAccount: String,
        refreshTokenAccount: String,
        idTokenAccount: String,
        chatGPTAccountIDAccount: String,
        tokenEndpoint: URL = OpenAIChatGPTAuth.tokenEndpoint,
        session: URLSession = .shared,
        onPermanentFailure: (@Sendable () -> Void)? = nil
    ) {
        self.store = store
        self.accessTokenAccount = accessTokenAccount
        self.refreshTokenAccount = refreshTokenAccount
        self.idTokenAccount = idTokenAccount
        self.chatGPTAccountIDAccount = chatGPTAccountIDAccount
        self.tokenEndpoint = tokenEndpoint
        self.session = session
        self.onPermanentFailure = onPermanentFailure
    }

    public func refreshedAccessToken() async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task<String, Error> {
            try await refreshAccessToken()
        }
        inFlight = task
        do {
            let accessToken = try await task.value
            inFlight = nil
            return accessToken
        } catch {
            inFlight = nil
            throw error
        }
    }

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = Self.nonEmpty(try store.get(account: refreshTokenAccount)) else {
            onPermanentFailure?()
            throw ProviderError.unauthorized
        }
        guard let body = OpenAIChatGPTAuth.refreshTokenRequestBody(refreshToken: refreshToken) else {
            throw ProviderError.malformedStream("OpenAI refresh token request body could not be encoded")
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let accessToken = Self.nonEmpty(object?["access_token"] as? String) else {
                throw ProviderError.malformedStream("OpenAI refresh response missing access_token")
            }
            try store.set(accessToken, account: accessTokenAccount)
            if let refreshToken = Self.nonEmpty(object?["refresh_token"] as? String) {
                try store.set(refreshToken, account: refreshTokenAccount)
            }
            if let idToken = Self.nonEmpty(object?["id_token"] as? String) {
                try store.set(idToken, account: idTokenAccount)
                if let accountID = OpenAIChatGPTAuth.chatGPTAccountID(idToken: idToken, accessToken: accessToken) {
                    try store.set(accountID, account: chatGPTAccountIDAccount)
                }
            }
            return accessToken
        case 400, 401, 403:
            try store.delete(account: accessTokenAccount)
            onPermanentFailure?()
            throw ProviderError.unauthorized
        default:
            let body = String(data: Data(data.prefix(2_000)), encoding: .utf8) ?? ""
            throw ProviderError.http(status: status, body: body)
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
