import Foundation
import Testing
import AgentLoopCore

private final class MemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    init(_ values: [String: String] = [:]) {
        self.values = values
    }

    func set(_ value: String, account: String) throws {
        lock.withLock {
            values[account] = value
        }
    }

    func get(account: String) throws -> String? {
        lock.withLock {
            values[account]
        }
    }

    func delete(account: String) throws {
        lock.withLock {
            values[account] = nil
        }
    }
}

private enum OAuthTestAccounts {
    static let access = "oauth-access-token"
    static let refresh = "oauth-refresh-token"
    static let id = "oauth-id-token"
    static let accountID = "oauth-chatgpt-account-id"
}

private func makeOAuthSession<P: URLProtocol>(
    store: MemoryCredentialStore,
    protocolClass: P.Type,
    permanentFailureCounter: Counter? = nil
) -> OpenAIOAuthSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [protocolClass]
    return OpenAIOAuthSession(
        store: store,
        accessTokenAccount: OAuthTestAccounts.access,
        refreshTokenAccount: OAuthTestAccounts.refresh,
        idTokenAccount: OAuthTestAccounts.id,
        chatGPTAccountIDAccount: OAuthTestAccounts.accountID,
        tokenEndpoint: URL(string: "https://auth.test/token")!,
        session: URLSession(configuration: configuration),
        onPermanentFailure: {
            permanentFailureCounter?.bump()
        }
    )
}

private func tokenResponse(accessToken: String, refreshToken: String? = nil, idToken: String? = nil) throws -> Data {
    var object: [String: Any] = ["access_token": accessToken]
    if let refreshToken {
        object["refresh_token"] = refreshToken
    }
    if let idToken {
        object["id_token"] = idToken
    }
    return try JSONSerialization.data(withJSONObject: object)
}

private func oauthJWT(accountID: String) throws -> String {
    let header = try oauthJWTPart(["alg": "none"])
    let payload = try oauthJWTPart([
        "https://api.openai.com/auth": ["chatgpt_account_id": accountID]
    ])
    return "\(header).\(payload).signature"
}

private func oauthJWTPart(_ object: [String: Any]) throws -> String {
    try JSONSerialization.data(withJSONObject: object)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func formValues(from request: URLRequest) -> [String: String] {
    let data: Data
    if let body = request.httpBody {
        data = body
    } else if let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var collected = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            collected.append(buffer, count: read)
        }
        data = collected
    } else {
        data = Data()
    }
    let encoded = String(data: data, encoding: .utf8) ?? ""
    let items = URLComponents(string: "https://local.invalid/?\(encoded)")?.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.compactMap { item in
        item.value.map { (item.name, $0) }
    })
}

private final class OAuthSuccessRefreshProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let form = formValues(from: request)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "codex-cli")
        #expect(form["grant_type"] == "refresh_token")
        #expect(form["refresh_token"] == "refresh-old")
        #expect(form["client_id"] == OpenAIChatGPTAuth.clientID)
        #expect(form["scope"] == "openid profile email")
        let data = try! tokenResponse(
            accessToken: "access-new",
            refreshToken: "refresh-new",
            idToken: oauthJWT(accountID: "account-new")
        )
        respond(status: 200, data: data)
    }

    override func stopLoading() {}

    private func respond(status: Int, data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class OAuthRotationRefreshProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let data = try! tokenResponse(accessToken: "access-new", refreshToken: "refresh-rotated")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class OAuthInvalidGrantProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"error":"invalid_grant"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class OAuthNetworkErrorProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
    }

    override func stopLoading() {}
}

private final class OAuthSingleFlightProtocol: URLProtocol {
    static let counter = Counter()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.counter.bump()
        Thread.sleep(forTimeInterval: 0.05)
        let data = try! tokenResponse(accessToken: "access-new")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class OAuthUnusedProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Issue.record("network should not be used without refresh_token")
    }
    override func stopLoading() {}
}

@Test func openAIOAuthSessionRefreshSuccessUpdatesStoredTokensAndAccountID() async throws {
    let store = MemoryCredentialStore([
        OAuthTestAccounts.access: "access-old",
        OAuthTestAccounts.refresh: "refresh-old",
        OAuthTestAccounts.id: "id-old",
        OAuthTestAccounts.accountID: "account-old",
    ])
    let session = makeOAuthSession(store: store, protocolClass: OAuthSuccessRefreshProtocol.self)

    let accessToken = try await session.refreshedAccessToken()

    #expect(accessToken == "access-new")
    #expect(try store.get(account: OAuthTestAccounts.access) == "access-new")
    #expect(try store.get(account: OAuthTestAccounts.refresh) == "refresh-new")
    #expect(try store.get(account: OAuthTestAccounts.id) != "id-old")
    #expect(try store.get(account: OAuthTestAccounts.accountID) == "account-new")
}

@Test func openAIOAuthSessionWritesRotatedRefreshToken() async throws {
    let store = MemoryCredentialStore([
        OAuthTestAccounts.access: "access-old",
        OAuthTestAccounts.refresh: "refresh-old",
    ])
    let session = makeOAuthSession(store: store, protocolClass: OAuthRotationRefreshProtocol.self)

    let accessToken = try await session.refreshedAccessToken()

    #expect(accessToken == "access-new")
    #expect(try store.get(account: OAuthTestAccounts.refresh) == "refresh-rotated")
}

@Test func openAIOAuthSessionInvalidGrantIsPermanentFailure() async throws {
    let permanentFailures = Counter()
    let store = MemoryCredentialStore([
        OAuthTestAccounts.access: "access-old",
        OAuthTestAccounts.refresh: "refresh-old",
        OAuthTestAccounts.id: "id-old",
    ])
    let session = makeOAuthSession(
        store: store,
        protocolClass: OAuthInvalidGrantProtocol.self,
        permanentFailureCounter: permanentFailures
    )

    await #expect(throws: ProviderError.unauthorized) {
        try await session.refreshedAccessToken()
    }

    #expect(try store.get(account: OAuthTestAccounts.access) == nil)
    #expect(try store.get(account: OAuthTestAccounts.refresh) == "refresh-old")
    #expect(try store.get(account: OAuthTestAccounts.id) == "id-old")
    #expect(permanentFailures.value == 1)
}

@Test func openAIOAuthSessionNetworkErrorIsTransient() async throws {
    let permanentFailures = Counter()
    let store = MemoryCredentialStore([
        OAuthTestAccounts.access: "access-old",
        OAuthTestAccounts.refresh: "refresh-old",
    ])
    let session = makeOAuthSession(
        store: store,
        protocolClass: OAuthNetworkErrorProtocol.self,
        permanentFailureCounter: permanentFailures
    )

    await #expect(throws: URLError.self) {
        try await session.refreshedAccessToken()
    }

    #expect(try store.get(account: OAuthTestAccounts.access) == "access-old")
    #expect(try store.get(account: OAuthTestAccounts.refresh) == "refresh-old")
    #expect(permanentFailures.value == 0)
}

@Test func openAIOAuthSessionSingleFlightsConcurrentRefreshes() async throws {
    let store = MemoryCredentialStore([
        OAuthTestAccounts.access: "access-old",
        OAuthTestAccounts.refresh: "refresh-old",
    ])
    let session = makeOAuthSession(store: store, protocolClass: OAuthSingleFlightProtocol.self)

    let tokens = try await withThrowingTaskGroup(of: String.self) { group in
        for _ in 0..<5 {
            group.addTask {
                try await session.refreshedAccessToken()
            }
        }
        var tokens: [String] = []
        for try await token in group {
            tokens.append(token)
        }
        return tokens
    }

    #expect(tokens == Array(repeating: "access-new", count: 5))
    #expect(OAuthSingleFlightProtocol.counter.value == 1)
}

@Test func openAIOAuthSessionWithoutRefreshTokenIsPermanentFailure() async {
    let permanentFailures = Counter()
    let store = MemoryCredentialStore([
        OAuthTestAccounts.access: "access-old",
    ])
    let session = makeOAuthSession(
        store: store,
        protocolClass: OAuthUnusedProtocol.self,
        permanentFailureCounter: permanentFailures
    )

    await #expect(throws: ProviderError.unauthorized) {
        try await session.refreshedAccessToken()
    }

    #expect(permanentFailures.value == 1)
}
