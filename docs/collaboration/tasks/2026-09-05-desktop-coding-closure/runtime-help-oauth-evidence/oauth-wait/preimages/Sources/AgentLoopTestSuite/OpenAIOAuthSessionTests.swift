import Foundation
import Testing
import AgentLoopCore

private enum OAuthStoreAction: String, Hashable, Sendable {
    case get, set, delete
}

private struct OAuthStoreCall: Equatable, Sendable {
    let action: OAuthStoreAction
    let account: String
}

private struct OAuthStoreFailureKey: Hashable, Sendable {
    let action: OAuthStoreAction
    let account: String
    let occurrence: Int
}

private final class OAuthRecordingFailureWriter:
    FailureRecordWriting, @unchecked Sendable
{
    private let lock = NSLock()
    private var storedRecords: [FailureRecord] = []

    func persistFailureRecord(_ record: FailureRecord) throws {
        lock.withLock { storedRecords.append(record) }
    }

    var records: [FailureRecord] {
        lock.withLock { storedRecords }
    }
}

private final class OAuthRecordingFailureLogSink:
    FailureLogSink, @unchecked Sendable
{
    private let lock = NSLock()
    private var storedEntries: [FailureLogEntry] = []

    func write(_ entry: FailureLogEntry) {
        lock.withLock { storedEntries.append(entry) }
    }

    var entries: [FailureLogEntry] {
        lock.withLock { storedEntries }
    }
}

private final class MemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]
    private var calls: [OAuthStoreCall] = []
    private var occurrences: [String: Int] = [:]
    private var failures: [OAuthStoreFailureKey: Int32] = [:]
    let backendNamespace: CredentialStoreBackendNamespace

    init(
        _ values: [String: String] = [:],
        backendNamespace: CredentialStoreBackendNamespace = .isolated(UUID())
    ) {
        self.values = values
        self.backendNamespace = backendNamespace
    }

    func set(_ value: String, account: String) throws {
        try lock.withLock {
            try recordAndThrowIfInjected(.set, account: account)
            values[account] = value
        }
    }

    func get(account: String) throws -> String? {
        try get(account: account, interactionPolicy: .allow)
    }

    func get(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String? {
        try lock.withLock {
            try recordAndThrowIfInjected(.get, account: account)
            return values[account]
        }
    }

    func delete(account: String) throws {
        try lock.withLock {
            try recordAndThrowIfInjected(.delete, account: account)
            values[account] = nil
        }
    }

    func injectFailure(
        _ action: OAuthStoreAction,
        account: String,
        occurrence: Int = 1,
        status: Int32
    ) {
        lock.withLock {
            failures[
                OAuthStoreFailureKey(
                    action: action,
                    account: account,
                    occurrence: occurrence
                )
            ] = status
        }
    }

    func resetAudit() {
        lock.withLock {
            calls = []
            occurrences = [:]
            failures = [:]
        }
    }

    var recordedCalls: [OAuthStoreCall] {
        lock.withLock { calls }
    }

    var snapshot: [String: String] {
        lock.withLock { values }
    }

    func rawValue(account: String) -> String? {
        lock.withLock { values[account] }
    }

    private func recordAndThrowIfInjected(
        _ action: OAuthStoreAction,
        account: String
    ) throws {
        calls.append(OAuthStoreCall(action: action, account: account))
        let occurrenceKey = "\(action.rawValue)\u{1F}\(account)"
        let occurrence = (occurrences[occurrenceKey] ?? 0) + 1
        occurrences[occurrenceKey] = occurrence
        let key = OAuthStoreFailureKey(
            action: action,
            account: account,
            occurrence: occurrence
        )
        if let status = failures[key] {
            throw KeychainError(status: status)
        }
    }
}

private final class LegacyOAuthCredentialStore:
    CredentialStore, @unchecked Sendable
{
    private let backing: MemoryCredentialStore

    init(_ values: [String: String] = [:]) {
        backing = MemoryCredentialStore(values)
    }

    func set(_ value: String, account: String) throws {
        try backing.set(value, account: account)
    }

    func get(account: String) throws -> String? {
        try backing.get(account: account)
    }

    func get(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String? {
        try backing.get(
            account: account,
            interactionPolicy: interactionPolicy
        )
    }

    func delete(account: String) throws {
        try backing.delete(account: account)
    }

    func resetAudit() {
        backing.resetAudit()
    }

    var recordedCalls: [OAuthStoreCall] {
        backing.recordedCalls
    }

    func rawValue(account: String) -> String? {
        backing.rawValue(account: account)
    }
}

private enum OAuthEnvelopeFixturePhase: String, CaseIterable {
    case prepared
    case recoveryPrepared
    case initialCommitting
    case refreshCommitting
    case unauthorizedDeleteCommitting

    var carriesAuthorizationSecrets: Bool {
        switch self {
        case .prepared, .recoveryPrepared, .initialCommitting:
            true
        case .refreshCommitting, .unauthorizedDeleteCommitting:
            false
        }
    }
}

private enum OAuthTestAccounts {
    static let access = "oauth-access-token"
    static let refresh = "oauth-refresh-token"
    static let id = "oauth-id-token"
    static let accountID = "oauth-chatgpt-account-id"
}

private enum OAuthCredentialTestError: Error {
    case preparationDidNotCommit
}

private func oauthCredentialAccounts(
    suffix: String = "main",
    verifier: String? = nil
) -> OAuthCredentialAccounts {
    OAuthCredentialAccounts(
        access: "oauth-access-\(suffix)",
        refresh: "oauth-refresh-\(suffix)",
        id: "oauth-id-\(suffix)",
        accountID: "oauth-account-\(suffix)",
        verifier: verifier ?? "oauth-envelope-\(suffix)"
    )
}

private func oauthCredentialValues(
    accounts: OAuthCredentialAccounts,
    access: String = "access-old",
    refresh: String? = "refresh-old",
    id: String? = "id-old",
    accountID: String? = "account-old"
) -> [String: String] {
    var values = [accounts.access: access]
    if let refresh { values[accounts.refresh] = refresh }
    if let id { values[accounts.id] = id }
    if let accountID { values[accounts.accountID] = accountID }
    return values
}

private func oauthEnvelopeFixture(
    phase: OAuthEnvelopeFixturePhase,
    owner: OAuthCredentialAccounts,
    flow: OAuthCredentialFlow = .chatGPT,
    state: String = "fixture-state",
    verifier: String = "fixture-verifier"
) throws -> String {
    let ownerObject: [String: Any] = [
        "accessAccount": owner.access,
        "refreshAccount": owner.refresh,
        "idTokenAccount": owner.id,
        "accountIDAccount": owner.accountID,
        "envelopeAccount": owner.verifier,
    ]
    let flowValue: String
    switch flow {
    case .chatGPT: flowValue = "chatGPT"
    case .generic: flowValue = "generic"
    }
    var object: [String: Any] = [
        "version": 1,
        "phase": phase.rawValue,
        "owner": ownerObject,
        "flow": flowValue,
    ]
    if phase.carriesAuthorizationSecrets {
        object["state"] = state
        object["verifier"] = verifier
    }
    let data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
    return try #require(String(data: data, encoding: .utf8))
}

private func oauthMutatingCalls(
    _ calls: [OAuthStoreCall]
) -> [OAuthStoreCall] {
    calls.filter { $0.action != .get }
}

private func secret(_ raw: String) throws -> SecretValue {
    try SecretValue(raw)
}

private func oauthBundle(
    flow: OAuthCredentialFlow = .chatGPT,
    access: String,
    refresh: String?,
    id: String?,
    accountID: String?
) throws -> OAuthCredentialBundle {
    try OAuthCredentialBundle(
        flow: flow,
        accessToken: secret(access),
        refreshToken: refresh.map(secret),
        idToken: id.map(secret),
        accountID: accountID.map(secret)
    )
}

private func committedPreparation(
    coordinator: CredentialBundleCoordinator,
    accounts: OAuthCredentialAccounts,
    flow: OAuthCredentialFlow = .chatGPT,
    state: String = "oauth-state",
    verifier: String = "oauth-verifier"
) async throws -> OAuthAuthorizationPreparation {
    let outcome = await coordinator.commitAuthorizationPreparation(
        flow: flow,
        state: try secret(state),
        verifier: try secret(verifier),
        accounts: accounts,
        interactionPolicy: .failIfInteractionRequired
    )
    guard case .committed(let receipt) = outcome else {
        throw OAuthCredentialTestError.preparationDidNotCommit
    }
    #expect(receipt.mutationCount == 1)
    return try await coordinator.readAuthorizationPreparation(
        flow: flow,
        accounts: accounts,
        interactionPolicy: .failIfInteractionRequired
    )
}

private func mutationCalls(
    _ store: MemoryCredentialStore
) -> [OAuthStoreCall] {
    store.recordedCalls.filter { $0.action != .get }
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

private final class OAuthControlledProtocolState: @unchecked Sendable {
    private let condition = NSCondition()
    private var pendingByKey: [String: OAuthControlledProtocol] = [:]
    private var startsByKey: [String: Int] = [:]

    func register(_ value: OAuthControlledProtocol, key: String) {
        condition.lock()
        pendingByKey[key] = value
        startsByKey[key, default: 0] += 1
        condition.broadcast()
        condition.unlock()
    }

    func waitUntilPending(_ key: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while pendingByKey[key] == nil {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }

    func take(_ key: String) -> OAuthControlledProtocol? {
        condition.lock()
        defer { condition.unlock() }
        return pendingByKey.removeValue(forKey: key)
    }

    func startCount(_ key: String) -> Int {
        condition.lock()
        defer { condition.unlock() }
        return startsByKey[key] ?? 0
    }
}

private final class OAuthControlledProtocol: URLProtocol {
    private static let state = OAuthControlledProtocolState()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.state.register(self, key: Self.key(for: request))
    }

    override func stopLoading() {}

    static func waitUntilPending(
        _ key: String,
        timeout: TimeInterval = 5
    ) -> Bool {
        state.waitUntilPending(key, timeout: timeout)
    }

    static func startCount(_ key: String) -> Int {
        state.startCount(key)
    }

    static func respond(key: String, status: Int, data: Data) {
        guard let source = state.take(key) else {
            Issue.record("missing controlled OAuth request for \(key)")
            return
        }
        let response = HTTPURLResponse(
            url: source.request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        source.client?.urlProtocol(
            source,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        source.client?.urlProtocol(source, didLoad: data)
        source.client?.urlProtocolDidFinishLoading(source)
    }

    private static func key(for request: URLRequest) -> String {
        request.url?.lastPathComponent ?? "missing"
    }
}

private func oauthRecordingReporter(
    writer: OAuthRecordingFailureWriter,
    sink: OAuthRecordingFailureLogSink
) -> FailureReporter {
    FailureReporter(writer: writer, logSink: sink)
}

private func oauthCountingTraceFactory(
    _ counter: Counter
) -> OperationTraceFactory {
    OperationTraceFactory(
        makeID: {
            counter.bump()
            return UUID()
        },
        now: { Date(timeIntervalSince1970: 1_725_000_000) }
    )
}

private func oauthControlledSession(
    coordinator: CredentialBundleCoordinator,
    accounts: OAuthCredentialAccounts,
    writer: OAuthRecordingFailureWriter,
    sink: OAuthRecordingFailureLogSink,
    traceCounter: Counter,
    requestKey: String,
    permanentFailureCounter: Counter? = nil
) -> OpenAIOAuthSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OAuthControlledProtocol.self]
    return OpenAIOAuthSession(
        coordinator: coordinator,
        accounts: accounts,
        failureReporter: oauthRecordingReporter(writer: writer, sink: sink),
        traceFactory: oauthCountingTraceFactory(traceCounter),
        tokenEndpoint: URL(string: "https://auth.test/\(requestKey)")!,
        session: URLSession(configuration: configuration),
        onPermanentFailure: { permanentFailureCounter?.bump() }
    )
}

private func expectOAuthTaskSuccess(
    _ task: Task<String, Error>,
    value: String
) async {
    switch await task.result {
    case .success(let actual): #expect(actual == value)
    case .failure:
        Issue.record("expected OAuth success")
    }
}

private func expectOAuthTaskFailure(
    _ task: Task<String, Error>,
    _ expected: CredentialBundleError
) async {
    switch await task.result {
    case .success:
        Issue.record("expected OAuth credential failure")
    case .failure(let error):
        #expect(error as? CredentialBundleError == expected)
    }
}

private func expectOAuthUnauthorizedTask(
    _ task: Task<String, Error>
) async {
    switch await task.result {
    case .success:
        Issue.record("expected permanent OAuth unauthorized failure")
    case .failure(let error):
        #expect(error as? ProviderError == .unauthorized)
    }
}

private func verifyOAuthEnvelopeReadMatrix() async throws {
    let accounts = oauthCredentialAccounts(suffix: "envelope-matrix")
    let expected = OAuthCredentialReadSnapshot(
        accessToken: try secret("access-old"),
        refreshToken: try secret("refresh-old"),
        idToken: try secret("id-old"),
        accountID: try secret("account-old")
    )

    do {
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts)
        )
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        #expect(read.refreshToken == expected.refreshToken)
        #expect(
            store.recordedCalls == [
                OAuthStoreCall(action: .get, account: accounts.verifier),
                OAuthStoreCall(action: .get, account: accounts.access),
                OAuthStoreCall(action: .get, account: accounts.refresh),
                OAuthStoreCall(action: .get, account: accounts.id),
                OAuthStoreCall(action: .get, account: accounts.accountID),
            ]
        )
    }

    do {
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts, refresh: nil)
        )
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try await coordinator.readRefreshCredential(
            accounts: accounts,
            interactionPolicy: .failIfInteractionRequired
        )
        #expect(read == nil)
        #expect(
            store.recordedCalls == [
                OAuthStoreCall(action: .get, account: accounts.verifier),
                OAuthStoreCall(action: .get, account: accounts.access),
                OAuthStoreCall(action: .get, account: accounts.refresh),
            ]
        )
    }

    for phase in OAuthEnvelopeFixturePhase.allCases {
        var values = oauthCredentialValues(accounts: accounts)
        values[accounts.verifier] = try oauthEnvelopeFixture(
            phase: phase,
            owner: accounts
        )
        let store = MemoryCredentialStore(values)
        let access = SynchronizedCredentialAccess(store: store)
        let coordinator = CredentialBundleCoordinator(access: access)

        await #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(
            store.recordedCalls == [
                OAuthStoreCall(action: .get, account: accounts.verifier),
            ],
            "refresh phase \(phase.rawValue)"
        )

        store.resetAudit()
        if phase == .prepared {
            let snapshot = try access.readOAuthCredentials(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
            #expect(snapshot == expected)
            #expect(store.recordedCalls.count == 5)
        } else {
            #expect(throws: OAuthCredentialBundleUnavailableError.self) {
                try access.readOAuthCredentials(
                    accounts: accounts,
                    interactionPolicy: .failIfInteractionRequired
                )
            }
            #expect(
                store.recordedCalls == [
                    OAuthStoreCall(action: .get, account: accounts.verifier),
                ],
                "consumer phase \(phase.rawValue)"
            )
        }
    }

    do {
        let otherOwner = oauthCredentialAccounts(
            suffix: "other-owner",
            verifier: accounts.verifier
        )
        var values = oauthCredentialValues(accounts: accounts)
        values[accounts.verifier] = try oauthEnvelopeFixture(
            phase: .prepared,
            owner: otherOwner
        )
        let store = MemoryCredentialStore(values)
        let access = SynchronizedCredentialAccess(store: store)
        #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try access.readOAuthCredentials(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(
            store.recordedCalls == [
                OAuthStoreCall(action: .get, account: accounts.verifier),
            ]
        )
    }

    for raw in [
        "{not-json",
        try oauthEnvelopeFixture(
            phase: .prepared,
            owner: accounts
        ) + " ",
    ] {
        var values = oauthCredentialValues(accounts: accounts)
        values[accounts.verifier] = raw
        let store = MemoryCredentialStore(values)
        let access = SynchronizedCredentialAccess(store: store)
        #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try access.readOAuthCredentials(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(
            store.recordedCalls == [
                OAuthStoreCall(action: .get, account: accounts.verifier),
            ]
        )
    }
}

private func verifyOAuthRevisionNamespaceMatrix() async throws {
    do {
        let accounts = oauthCredentialAccounts(suffix: "same-backend")
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts)
        )
        let coordinatorA = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let coordinatorB = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let readA = try #require(
            try await coordinatorA.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let readB = try #require(
            try await coordinatorB.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        _ = try await coordinatorA.commitRefresh(
            oauthBundle(
                access: "access-winner",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readA,
            interactionPolicy: .failIfInteractionRequired
        )
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinatorB.commitRefresh(
                oauthBundle(
                    access: "access-stale",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: readB,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.recordedCalls.isEmpty)
        #expect(store.rawValue(account: accounts.access) == "access-winner")
    }

    do {
        let accountsA = oauthCredentialAccounts(suffix: "disjoint-a")
        let accountsB = oauthCredentialAccounts(suffix: "disjoint-b")
        var values = oauthCredentialValues(accounts: accountsA)
        for (account, value) in oauthCredentialValues(accounts: accountsB) {
            values[account] = value
        }
        let namespace = CredentialStoreBackendNamespace.isolated(UUID())
        let store = MemoryCredentialStore(
            values,
            backendNamespace: namespace
        )
        let coordinatorA = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let coordinatorB = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let readA = try #require(
            try await coordinatorA.readRefreshCredential(
                accounts: accountsA,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let readB = try #require(
            try await coordinatorB.readRefreshCredential(
                accounts: accountsB,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        _ = try await coordinatorA.commitRefresh(
            oauthBundle(
                access: "access-a-new",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readA,
            interactionPolicy: .failIfInteractionRequired
        )
        _ = try await coordinatorB.commitRefresh(
            oauthBundle(
                access: "access-b-new",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readB,
            interactionPolicy: .failIfInteractionRequired
        )
        #expect(store.rawValue(account: accountsA.access) == "access-a-new")
        #expect(store.rawValue(account: accountsB.access) == "access-b-new")
    }

    do {
        let sharedEnvelope = OAuthCredentialAccounts.live.verifier
        let accountsA = oauthCredentialAccounts(
            suffix: "compat-a",
            verifier: sharedEnvelope
        )
        let accountsB = oauthCredentialAccounts(
            suffix: "compat-b",
            verifier: sharedEnvelope
        )
        var values = oauthCredentialValues(accounts: accountsA)
        for (account, value) in oauthCredentialValues(accounts: accountsB) {
            values[account] = value
        }
        let store = MemoryCredentialStore(values)
        let coordinatorA = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let coordinatorB = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let readA = try #require(
            try await coordinatorA.readRefreshCredential(
                accounts: accountsA,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let readB = try #require(
            try await coordinatorB.readRefreshCredential(
                accounts: accountsB,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        _ = try await coordinatorA.commitRefresh(
            oauthBundle(
                access: "compat-a-new",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readA,
            interactionPolicy: .failIfInteractionRequired
        )
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinatorB.commitRefresh(
                oauthBundle(
                    access: "compat-b-stale",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: readB,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.recordedCalls.isEmpty)
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "legacy-domain")
        let values = oauthCredentialValues(accounts: accounts)
        let storeA = LegacyOAuthCredentialStore(values)
        let storeB = LegacyOAuthCredentialStore(values)
        let accessA = SynchronizedCredentialAccess(store: storeA)
        let accessB = SynchronizedCredentialAccess(store: storeB)
        #expect(accessA.backendNamespace == .legacyShared)
        #expect(accessB.backendNamespace == .legacyShared)
        let coordinatorA = CredentialBundleCoordinator(access: accessA)
        let coordinatorB = CredentialBundleCoordinator(access: accessB)
        let readA = try #require(
            try await coordinatorA.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let readB = try #require(
            try await coordinatorB.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        _ = try await coordinatorA.commitRefresh(
            oauthBundle(
                access: "legacy-a-new",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readA,
            interactionPolicy: .failIfInteractionRequired
        )
        storeB.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinatorB.commitRefresh(
                oauthBundle(
                    access: "legacy-b-stale",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: readB,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(storeB.recordedCalls.isEmpty)
        #expect(storeB.rawValue(account: accounts.access) == "access-old")
    }
}

private func verifyOAuthProofGuardMatrix() async throws {
    do {
        let accounts = oauthCredentialAccounts(suffix: "initial-cross-flow")
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts)
        )
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let preparation = try await committedPreparation(
            coordinator: coordinator,
            accounts: accounts,
            flow: .generic
        )
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .generic)
        ) {
            try await coordinator.commitInitial(
                oauthBundle(
                    flow: .chatGPT,
                    access: "access-new",
                    refresh: nil,
                    id: nil,
                    accountID: "account-new"
                ),
                basedOn: preparation,
                interactionPolicy: .allow
            )
        }
        #expect(store.recordedCalls.isEmpty)
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "snapshot-change")
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts)
        )
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        try store.set("external-access", account: accounts.access)
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinator.commitRefresh(
                oauthBundle(
                    access: "stale-access",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(oauthMutatingCalls(store.recordedCalls).isEmpty)
        #expect(store.rawValue(account: accounts.access) == "external-access")
    }

    do {
        let status: Int32 = -34_018
        let accounts = oauthCredentialAccounts(suffix: "failed-invalidates")
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts)
        )
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let staleRead = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let failingRead = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        store.resetAudit()
        store.injectFailure(
            .set,
            account: accounts.verifier,
            status: status
        )
        await #expect(
            throws: CredentialBundleError.commit(
                flow: .chatGPT,
                mutation: .oauthTransactionEnvelope,
                status: status
            )
        ) {
            try await coordinator.commitRefresh(
                oauthBundle(
                    access: "failed-attempt",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: failingRead,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinator.commitRefresh(
                oauthBundle(
                    access: "old-attempt",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: staleRead,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.recordedCalls.isEmpty)
    }

    let invalidRows = [
        OAuthCredentialAccounts(
            access: "",
            refresh: "refresh",
            id: "id",
            accountID: "account",
            verifier: "envelope"
        ),
        OAuthCredentialAccounts(
            access: "duplicate",
            refresh: "duplicate",
            id: "id",
            accountID: "account",
            verifier: "envelope"
        ),
        OAuthCredentialAccounts(
            access: OAuthCredentialAccounts.live.verifier,
            refresh: "refresh",
            id: "id",
            accountID: "account",
            verifier: OAuthCredentialAccounts.live.verifier
        ),
    ]
    for accounts in invalidRows {
        let store = MemoryCredentialStore()
        let access = SynchronizedCredentialAccess(store: store)
        let coordinator = CredentialBundleCoordinator(access: access)
        #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try access.readOAuthCredentials(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        await #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        let outcome = await coordinator.commitAuthorizationPreparation(
            flow: .chatGPT,
            state: try secret("state"),
            verifier: try secret("verifier"),
            accounts: accounts,
            interactionPolicy: .failIfInteractionRequired
        )
        #expect(
            outcome == .unavailable(OAuthCredentialBundleUnavailableError())
        )
        #expect(store.recordedCalls.isEmpty)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthUnusedProtocol.self]
        let session = OpenAIOAuthSession(
            store: store,
            accessTokenAccount: accounts.access,
            refreshTokenAccount: accounts.refresh,
            idTokenAccount: accounts.id,
            chatGPTAccountIDAccount: accounts.accountID,
            tokenEndpoint: URL(string: "https://auth.test/invalid")!,
            session: URLSession(configuration: configuration)
        )
        await #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try await session.refreshedAccessToken()
        }
        #expect(store.recordedCalls.isEmpty)
    }
}

private func verifyOAuthCompatibilityQuarantineMatrix() async throws {
    let liveEnvelope = OAuthCredentialAccounts.live.verifier
    let coordinateRows: [[String]] = [
        ["shared-access", "refresh-a", "id-a", "account-a"],
        ["访问令牌", "刷新令牌", "身份令牌", "账户标识"],
        ["access|a", "refresh:a", "id/a", "account?a"],
        [
            "access-" + String(repeating: "a", count: 256),
            "refresh-" + String(repeating: "b", count: 256),
            "id-" + String(repeating: "c", count: 256),
            "account-" + String(repeating: "d", count: 256),
        ],
    ]

    for (index, coordinates) in coordinateRows.enumerated() {
        let accountsA = OAuthCredentialAccounts(
            access: coordinates[0],
            refresh: coordinates[1],
            id: coordinates[2],
            accountID: coordinates[3],
            verifier: liveEnvelope
        )
        let accountsB = OAuthCredentialAccounts(
            access: accountsA.access,
            refresh: "refresh-b-\(index)",
            id: "id-b-\(index)",
            accountID: "account-b-\(index)",
            verifier: liveEnvelope
        )
        let accountsC = OAuthCredentialAccounts(
            access: "access-c-\(index)",
            refresh: "refresh-c-\(index)",
            id: "id-c-\(index)",
            accountID: "account-c-\(index)",
            verifier: liveEnvelope
        )
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accountsA)
        )
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accountsA,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        store.resetAudit()

        let primaryAccount: String
        let primaryAction: OAuthStoreAction
        let rollbackAccount: String
        switch index {
        case 0:
            primaryAccount = accountsA.refresh
            primaryAction = .set
            rollbackAccount = accountsA.access
        case 1:
            primaryAccount = accountsA.id
            primaryAction = .set
            rollbackAccount = accountsA.refresh
        case 2:
            primaryAccount = accountsA.accountID
            primaryAction = .set
            rollbackAccount = accountsA.id
        default:
            primaryAccount = accountsA.verifier
            primaryAction = .delete
            rollbackAccount = accountsA.accountID
        }
        store.injectFailure(
            primaryAction,
            account: primaryAccount,
            status: -34_018
        )
        store.injectFailure(
            .set,
            account: rollbackAccount,
            occurrence: 2,
            status: -25_293
        )
        await #expect(
            throws: CredentialBundleError.rollback(
                flow: .chatGPT,
                status: -25_293
            )
        ) {
            try await coordinator.commitRefresh(
                oauthBundle(
                    access: "access-new-\(index)",
                    refresh: "refresh-new-\(index)",
                    id: "id-new-\(index)",
                    accountID: "account-new-\(index)"
                ),
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        let retainedEnvelope = try #require(
            store.rawValue(account: liveEnvelope)
        )
        #expect(retainedEnvelope.contains(#""phase":"refreshCommitting""#))

        let preparationB = await CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        ).commitAuthorizationPreparation(
            flow: .chatGPT,
            state: try secret("state-b"),
            verifier: try secret("verifier-b"),
            accounts: accountsB,
            interactionPolicy: .failIfInteractionRequired
        )
        #expect(
            preparationB
                == .unavailable(OAuthCredentialBundleUnavailableError())
        )
        #expect(store.rawValue(account: liveEnvelope) == retainedEnvelope)

        for blocked in [accountsB, accountsC] {
            store.resetAudit()
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [OAuthUnusedProtocol.self]
            let session = OpenAIOAuthSession(
                store: store,
                accessTokenAccount: blocked.access,
                refreshTokenAccount: blocked.refresh,
                idTokenAccount: blocked.id,
                chatGPTAccountIDAccount: blocked.accountID,
                tokenEndpoint: URL(string: "https://auth.test/quarantine")!,
                session: URLSession(configuration: configuration)
            )
            await #expect(throws: OAuthCredentialBundleUnavailableError.self) {
                try await session.refreshedAccessToken()
            }
            #expect(
                store.recordedCalls == [
                    OAuthStoreCall(action: .get, account: liveEnvelope),
                ]
            )
            #expect(store.rawValue(account: liveEnvelope) == retainedEnvelope)
        }
    }
}

private func verifyOAuthSessionFlightMatrix() async throws {
    do {
        let accounts = oauthCredentialAccounts(suffix: "session-single-flight")
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts, id: nil, accountID: nil)
        )
        let writer = OAuthRecordingFailureWriter()
        let sink = OAuthRecordingFailureLogSink()
        let traceCounter = Counter()
        let requestKey = "single-\(UUID().uuidString)"
        let session = oauthControlledSession(
            coordinator: CredentialBundleCoordinator(
                access: SynchronizedCredentialAccess(store: store)
            ),
            accounts: accounts,
            writer: writer,
            sink: sink,
            traceCounter: traceCounter,
            requestKey: requestKey
        )
        let tasks: [Task<String, Error>] = (0..<5).map { _ in
            Task { try await session.refreshedAccessToken() }
        }
        #expect(OAuthControlledProtocol.waitUntilPending(requestKey))
        OAuthControlledProtocol.respond(
            key: requestKey,
            status: 200,
            data: try tokenResponse(accessToken: "single-access-new")
        )
        for task in tasks {
            await expectOAuthTaskSuccess(task, value: "single-access-new")
        }
        #expect(OAuthControlledProtocol.startCount(requestKey) == 1)
        #expect(traceCounter.value == 1)
        #expect(writer.records.isEmpty)
        #expect(sink.entries.isEmpty)
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "session-refresh-race")
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts, id: nil, accountID: nil)
        )
        let writerA = OAuthRecordingFailureWriter()
        let writerB = OAuthRecordingFailureWriter()
        let sinkA = OAuthRecordingFailureLogSink()
        let sinkB = OAuthRecordingFailureLogSink()
        let traceA = Counter()
        let traceB = Counter()
        let keyA = "refresh-a-\(UUID().uuidString)"
        let keyB = "refresh-b-\(UUID().uuidString)"
        let sessionA = oauthControlledSession(
            coordinator: CredentialBundleCoordinator(
                access: SynchronizedCredentialAccess(store: store)
            ),
            accounts: accounts,
            writer: writerA,
            sink: sinkA,
            traceCounter: traceA,
            requestKey: keyA
        )
        let sessionB = oauthControlledSession(
            coordinator: CredentialBundleCoordinator(
                access: SynchronizedCredentialAccess(store: store)
            ),
            accounts: accounts,
            writer: writerB,
            sink: sinkB,
            traceCounter: traceB,
            requestKey: keyB
        )
        let taskA = Task { try await sessionA.refreshedAccessToken() }
        let taskB = Task { try await sessionB.refreshedAccessToken() }
        #expect(OAuthControlledProtocol.waitUntilPending(keyA))
        #expect(OAuthControlledProtocol.waitUntilPending(keyB))
        OAuthControlledProtocol.respond(
            key: keyA,
            status: 200,
            data: try tokenResponse(accessToken: "race-access-a")
        )
        await expectOAuthTaskSuccess(taskA, value: "race-access-a")
        store.resetAudit()
        OAuthControlledProtocol.respond(
            key: keyB,
            status: 200,
            data: try tokenResponse(accessToken: "race-access-b")
        )
        await expectOAuthTaskFailure(
            taskB,
            .preimageChanged(flow: .chatGPT)
        )
        #expect(store.recordedCalls.isEmpty)
        #expect(store.rawValue(account: accounts.access) == "race-access-a")
        #expect(traceA.value == 1)
        #expect(traceB.value == 1)
        #expect(writerA.records.isEmpty)
        #expect(writerB.records.count == 1)
        #expect(writerB.records.first?.operation == .oauthRefreshCommit)
        #expect(
            writerB.records.first?.errorCode == .oauthCredentialCommitFailed
        )
        #expect(sinkA.entries.isEmpty)
        #expect(sinkB.entries.count == 1)
    }

    for refreshWins in [true, false] {
        let suffix = refreshWins ? "refresh-first" : "delete-first"
        let accounts = oauthCredentialAccounts(suffix: suffix)
        let store = MemoryCredentialStore(
            oauthCredentialValues(accounts: accounts, id: nil, accountID: nil)
        )
        let refreshWriter = OAuthRecordingFailureWriter()
        let deleteWriter = OAuthRecordingFailureWriter()
        let refreshSink = OAuthRecordingFailureLogSink()
        let deleteSink = OAuthRecordingFailureLogSink()
        let refreshTrace = Counter()
        let deleteTrace = Counter()
        let permanentFailures = Counter()
        let refreshKey = "refresh-\(suffix)-\(UUID().uuidString)"
        let deleteKey = "delete-\(suffix)-\(UUID().uuidString)"
        let refreshSession = oauthControlledSession(
            coordinator: CredentialBundleCoordinator(
                access: SynchronizedCredentialAccess(store: store)
            ),
            accounts: accounts,
            writer: refreshWriter,
            sink: refreshSink,
            traceCounter: refreshTrace,
            requestKey: refreshKey
        )
        let deleteSession = oauthControlledSession(
            coordinator: CredentialBundleCoordinator(
                access: SynchronizedCredentialAccess(store: store)
            ),
            accounts: accounts,
            writer: deleteWriter,
            sink: deleteSink,
            traceCounter: deleteTrace,
            requestKey: deleteKey,
            permanentFailureCounter: permanentFailures
        )
        let refreshTask = Task {
            try await refreshSession.refreshedAccessToken()
        }
        let deleteTask = Task {
            try await deleteSession.refreshedAccessToken()
        }
        #expect(OAuthControlledProtocol.waitUntilPending(refreshKey))
        #expect(OAuthControlledProtocol.waitUntilPending(deleteKey))

        if refreshWins {
            OAuthControlledProtocol.respond(
                key: refreshKey,
                status: 200,
                data: try tokenResponse(accessToken: "refresh-winner")
            )
            await expectOAuthTaskSuccess(refreshTask, value: "refresh-winner")
            store.resetAudit()
            OAuthControlledProtocol.respond(
                key: deleteKey,
                status: 400,
                data: Data(#"{"error":"invalid_grant"}"#.utf8)
            )
            await expectOAuthTaskFailure(
                deleteTask,
                .preimageChanged(flow: .chatGPT)
            )
            #expect(store.recordedCalls.isEmpty)
            #expect(
                store.rawValue(account: accounts.access) == "refresh-winner"
            )
            #expect(permanentFailures.value == 0)
            #expect(refreshWriter.records.isEmpty)
            #expect(deleteWriter.records.count == 1)
            #expect(
                deleteWriter.records.first?.operation
                    == .oauthUnauthorizedDelete
            )
            #expect(
                deleteWriter.records.first?.errorCode
                    == .oauthCredentialCommitFailed
            )
        } else {
            OAuthControlledProtocol.respond(
                key: deleteKey,
                status: 400,
                data: Data(#"{"error":"invalid_grant"}"#.utf8)
            )
            await expectOAuthUnauthorizedTask(deleteTask)
            store.resetAudit()
            OAuthControlledProtocol.respond(
                key: refreshKey,
                status: 200,
                data: try tokenResponse(accessToken: "refresh-stale")
            )
            await expectOAuthTaskFailure(
                refreshTask,
                .preimageChanged(flow: .chatGPT)
            )
            #expect(store.recordedCalls.isEmpty)
            #expect(store.rawValue(account: accounts.access) == nil)
            #expect(permanentFailures.value == 1)
            #expect(deleteWriter.records.count == 1)
            #expect(
                deleteWriter.records.first?.operation == .oauthRefreshCommit
            )
            #expect(refreshWriter.records.count == 1)
            #expect(
                refreshWriter.records.first?.operation == .oauthRefreshCommit
            )
            #expect(
                refreshWriter.records.first?.errorCode
                    == .oauthCredentialCommitFailed
            )
        }
        #expect(refreshTrace.value == 1)
        #expect(deleteTrace.value == 2)
        #expect(refreshSink.entries.count == refreshWriter.records.count)
        #expect(deleteSink.entries.count == deleteWriter.records.count)
    }
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

@Test func oauthCredentialCommitFailureRollsBackEarlierWrites() async throws {
    let status: Int32 = -34_018

    do {
        let accounts = oauthCredentialAccounts(suffix: "initial-rollback")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let preparation = try await committedPreparation(
            coordinator: coordinator,
            accounts: accounts
        )
        let before = store.snapshot
        store.resetAudit()
        store.injectFailure(
            .set,
            account: accounts.refresh,
            status: status
        )

        let replacement = try oauthBundle(
            access: "access-new",
            refresh: "refresh-new",
            id: "id-new",
            accountID: "account-new"
        )
        await #expect(
            throws: CredentialBundleError.commit(
                flow: .chatGPT,
                mutation: .refresh,
                status: status
            )
        ) {
            try await coordinator.commitInitial(
                replacement,
                basedOn: preparation,
                interactionPolicy: .allow
            )
        }

        #expect(store.snapshot == before)
        #expect(
            mutationCalls(store) == [
                OAuthStoreCall(action: .set, account: accounts.verifier),
                OAuthStoreCall(action: .set, account: accounts.access),
                OAuthStoreCall(action: .set, account: accounts.refresh),
                OAuthStoreCall(action: .set, account: accounts.access),
                OAuthStoreCall(action: .set, account: accounts.verifier),
            ]
        )
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "refresh-rollback")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let before = store.snapshot
        store.resetAudit()
        store.injectFailure(.set, account: accounts.id, status: status)

        let replacement = try oauthBundle(
            access: "access-new",
            refresh: "refresh-new",
            id: "id-new",
            accountID: "account-new"
        )
        await #expect(
            throws: CredentialBundleError.commit(
                flow: .chatGPT,
                mutation: .id,
                status: status
            )
        ) {
            try await coordinator.commitRefresh(
                replacement,
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }

        #expect(store.snapshot == before)
        #expect(
            mutationCalls(store) == [
                OAuthStoreCall(action: .set, account: accounts.verifier),
                OAuthStoreCall(action: .set, account: accounts.access),
                OAuthStoreCall(action: .set, account: accounts.refresh),
                OAuthStoreCall(action: .set, account: accounts.id),
                OAuthStoreCall(action: .set, account: accounts.refresh),
                OAuthStoreCall(action: .set, account: accounts.access),
                OAuthStoreCall(action: .delete, account: accounts.verifier),
            ]
        )
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "generic-replacement")
        let store = MemoryCredentialStore([
            accounts.access: "chatgpt-access",
            accounts.refresh: "chatgpt-refresh",
            accounts.id: "chatgpt-id",
            accounts.accountID: "chatgpt-account",
        ])
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let preparation = try await committedPreparation(
            coordinator: coordinator,
            accounts: accounts,
            flow: .generic
        )
        let generic = try oauthBundle(
            flow: .generic,
            access: "generic-access",
            refresh: nil,
            id: nil,
            accountID: nil
        )

        let receipt = try await coordinator.commitInitial(
            generic,
            basedOn: preparation,
            interactionPolicy: .allow
        )
        #expect(receipt.mutationCount == 6)
        #expect(store.rawValue(account: accounts.access) == "generic-access")
        #expect(store.rawValue(account: accounts.refresh) == nil)
        #expect(store.rawValue(account: accounts.id) == nil)
        #expect(store.rawValue(account: accounts.accountID) == nil)
        #expect(store.rawValue(account: accounts.verifier) == nil)
    }
}

@Test func oauthCredentialRollbackFailureIsExplicitAndCritical() async throws {
    let primaryStatus: Int32 = -34_018
    let rollbackStatus: Int32 = -25_293

    do {
        let accounts = oauthCredentialAccounts(suffix: "initial-quarantine")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        let access = SynchronizedCredentialAccess(store: store)
        let coordinator = CredentialBundleCoordinator(access: access)
        let preparation = try await committedPreparation(
            coordinator: coordinator,
            accounts: accounts
        )
        store.resetAudit()
        store.injectFailure(
            .set,
            account: accounts.refresh,
            status: primaryStatus
        )
        store.injectFailure(
            .set,
            account: accounts.access,
            occurrence: 2,
            status: rollbackStatus
        )

        await #expect(
            throws: CredentialBundleError.rollback(
                flow: .chatGPT,
                status: rollbackStatus
            )
        ) {
            try await coordinator.commitInitial(
                oauthBundle(
                    access: "access-new",
                    refresh: "refresh-new",
                    id: "id-new",
                    accountID: "account-new"
                ),
                basedOn: preparation,
                interactionPolicy: .allow
            )
        }
        let envelope = try #require(
            store.rawValue(account: accounts.verifier)
        )
        #expect(envelope.contains(#""phase":"initialCommitting""#))
        #expect(
            !mutationCalls(store).contains(
                OAuthStoreCall(action: .delete, account: accounts.verifier)
            )
        )

        store.resetAudit()
        #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try access.readOAuthCredentials(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(
            store.recordedCalls == [
                OAuthStoreCall(action: .get, account: accounts.verifier)
            ]
        )
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "refresh-quarantine")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        store.resetAudit()
        store.injectFailure(.set, account: accounts.id, status: primaryStatus)
        store.injectFailure(
            .set,
            account: accounts.refresh,
            occurrence: 2,
            status: rollbackStatus
        )

        await #expect(
            throws: CredentialBundleError.rollback(
                flow: .chatGPT,
                status: rollbackStatus
            )
        ) {
            try await coordinator.commitRefresh(
                oauthBundle(
                    access: "access-new",
                    refresh: "refresh-new",
                    id: "id-new",
                    accountID: "account-new"
                ),
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        let envelope = try #require(
            store.rawValue(account: accounts.verifier)
        )
        #expect(envelope.contains(#""phase":"refreshCommitting""#))
        #expect(
            !mutationCalls(store).contains(
                OAuthStoreCall(action: .delete, account: accounts.verifier)
            )
        )
    }

    do {
        #expect(throws: (any Error).self) { try SecretValue("") }
        #expect(throws: (any Error).self) { try SecretValue(" \n\t") }
        let exact = try SecretValue(" current-state ")
        let same = try #require(SecretValue.validated(" current-state "))
        let trimmed = try #require(SecretValue.validated("current-state"))
        #expect(exact.constantTimeEquals(same))
        #expect(exact == same)
        #expect(!exact.constantTimeEquals(trimmed))
        let baseline = try secret("abcdef")
        let firstMismatch = try secret("xbcdef")
        let middleMismatch = try secret("abcxef")
        let lastMismatch = try secret("abcdex")
        let lengthMismatch = try secret("abcdefg")
        #expect(!baseline.constantTimeEquals(firstMismatch))
        #expect(!baseline.constantTimeEquals(middleMismatch))
        #expect(!baseline.constantTimeEquals(lastMismatch))
        #expect(!baseline.constantTimeEquals(lengthMismatch))

        let invalidStore = MemoryCredentialStore()
        let invalidAccess = SynchronizedCredentialAccess(store: invalidStore)
        let empty = OAuthCredentialAccounts(
            access: "",
            refresh: "refresh",
            id: "id",
            accountID: "account",
            verifier: "envelope"
        )
        #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try invalidAccess.readOAuthCredentials(
                accounts: empty,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        let duplicate = OAuthCredentialAccounts(
            access: "same",
            refresh: "same",
            id: "id",
            accountID: "account",
            verifier: "envelope"
        )
        #expect(throws: OAuthCredentialBundleUnavailableError.self) {
            try invalidAccess.readOAuthCredentials(
                accounts: duplicate,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(invalidStore.recordedCalls.isEmpty)
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "proof-owner")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        let access = SynchronizedCredentialAccess(store: store)
        let coordinatorA = CredentialBundleCoordinator(access: access)
        let coordinatorB = CredentialBundleCoordinator(access: access)
        let read = try #require(
            try await coordinatorA.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinatorB.commitRefresh(
                oauthBundle(
                    access: "access-new",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.recordedCalls.isEmpty)

        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinatorA.commitRefresh(
                oauthBundle(
                    flow: .generic,
                    access: "access-new",
                    refresh: nil,
                    id: nil,
                    accountID: nil
                ),
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.recordedCalls.isEmpty)

        let preparation = try await committedPreparation(
            coordinator: coordinatorA,
            accounts: accounts
        )
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinatorB.commitInitial(
                oauthBundle(
                    access: "access-new",
                    refresh: nil,
                    id: nil,
                    accountID: "account-new"
                ),
                basedOn: preparation,
                interactionPolicy: .allow
            )
        }
        #expect(store.recordedCalls.isEmpty)
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "namespace")
        let namespaceA = CredentialStoreBackendNamespace.isolated(UUID())
        let namespaceB = CredentialStoreBackendNamespace.isolated(UUID())
        let values = [
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
        ]
        let storeA = MemoryCredentialStore(values, backendNamespace: namespaceA)
        let storeB = MemoryCredentialStore(values, backendNamespace: namespaceB)
        let coordinatorA = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: storeA)
        )
        let coordinatorB = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: storeB)
        )
        let readA = try #require(
            try await coordinatorA.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let readB = try #require(
            try await coordinatorB.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        _ = try await coordinatorA.commitRefresh(
            oauthBundle(
                access: "access-a",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readA,
            interactionPolicy: .failIfInteractionRequired
        )
        _ = try await coordinatorB.commitRefresh(
            oauthBundle(
                access: "access-b",
                refresh: nil,
                id: nil,
                accountID: nil
            ),
            basedOn: readB,
            interactionPolicy: .failIfInteractionRequired
        )
        #expect(storeA.rawValue(account: accounts.access) == "access-a")
        #expect(storeB.rawValue(account: accounts.access) == "access-b")
        #expect(
            KeychainStore(service: "service-a").backendNamespace
                == KeychainStore(service: "service-a").backendNamespace
        )
        #expect(
            KeychainStore(service: "service-a").backendNamespace
                != KeychainStore(service: "service-b").backendNamespace
        )
    }

    try await verifyOAuthEnvelopeReadMatrix()
    try await verifyOAuthRevisionNamespaceMatrix()
    try await verifyOAuthProofGuardMatrix()
    try await verifyOAuthCompatibilityQuarantineMatrix()
}

@Test func oauthPermanentUnauthorizedDeleteFailureNeverReportsCleanRelogin() async throws {
    let status: Int32 = -34_018

    do {
        let accounts = oauthCredentialAccounts(suffix: "delete-primary")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let read = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let before = store.snapshot
        store.resetAudit()
        store.injectFailure(.delete, account: accounts.access, status: status)

        await #expect(
            throws: CredentialBundleError.unauthorizedDelete(status: status)
        ) {
            try await coordinator.deleteUnauthorizedAccess(
                basedOn: read,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.snapshot == before)
        #expect(
            mutationCalls(store) == [
                OAuthStoreCall(action: .set, account: accounts.verifier),
                OAuthStoreCall(action: .delete, account: accounts.access),
                OAuthStoreCall(action: .delete, account: accounts.verifier),
            ]
        )
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "delete-session")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
            accounts.id: "id-old",
            accounts.accountID: "account-old",
        ])
        store.injectFailure(.delete, account: accounts.access, status: status)
        let access = SynchronizedCredentialAccess(store: store)
        let coordinator = CredentialBundleCoordinator(access: access)
        let writer = OAuthRecordingFailureWriter()
        let sink = OAuthRecordingFailureLogSink()
        let reporter = FailureReporter(writer: writer, logSink: sink)
        let traceSequence = Counter()
        let traceFactory = OperationTraceFactory(
            makeID: {
                let value = traceSequence.bump()
                let suffix = String(format: "%012d", value)
                return UUID(
                    uuidString: "00000000-0000-0000-0000-\(suffix)"
                )!
            },
            now: { Date(timeIntervalSince1970: 1_725_000_000) }
        )
        let permanentFailures = Counter()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthInvalidGrantProtocol.self]
        let session = OpenAIOAuthSession(
            coordinator: coordinator,
            accounts: accounts,
            failureReporter: reporter,
            traceFactory: traceFactory,
            tokenEndpoint: URL(string: "https://auth.test/token")!,
            session: URLSession(configuration: configuration),
            onPermanentFailure: { permanentFailures.bump() }
        )

        await #expect(
            throws: CredentialBundleError.unauthorizedDelete(status: status)
        ) {
            try await session.refreshedAccessToken()
        }
        #expect(store.rawValue(account: accounts.access) == "access-old")
        #expect(permanentFailures.value == 0)
        #expect(writer.records.count == 1)
        #expect(writer.records.first?.operation == .oauthUnauthorizedDelete)
        #expect(
            writer.records.first?.errorCode == .oauthCredentialDeleteFailed
        )
        #expect(writer.records.first?.severity == .error)
        #expect(!(writer.records.first?.diagnosticJson.contains("access-old") ?? true))
        #expect(!(writer.records.first?.diagnosticJson.contains("invalid_grant") ?? true))
        #expect(sink.entries.count == 1)
        #expect(sink.entries.first?.traceId == writer.records.first?.id)
        #expect(traceSequence.value == 2)
    }

    do {
        let accounts = oauthCredentialAccounts(suffix: "delete-stale")
        let store = MemoryCredentialStore([
            accounts.access: "access-old",
            accounts.refresh: "refresh-old",
        ])
        let coordinator = CredentialBundleCoordinator(
            access: SynchronizedCredentialAccess(store: store)
        )
        let oldRead = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        let winningRead = try #require(
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        )
        _ = try await coordinator.commitRefresh(
            oauthBundle(
                access: "access-winner",
                refresh: "refresh-winner",
                id: nil,
                accountID: nil
            ),
            basedOn: winningRead,
            interactionPolicy: .failIfInteractionRequired
        )
        store.resetAudit()
        await #expect(
            throws: CredentialBundleError.preimageChanged(flow: .chatGPT)
        ) {
            try await coordinator.deleteUnauthorizedAccess(
                basedOn: oldRead,
                interactionPolicy: .failIfInteractionRequired
            )
        }
        #expect(store.recordedCalls.isEmpty)
        #expect(store.rawValue(account: accounts.access) == "access-winner")
        #expect(store.rawValue(account: accounts.refresh) == "refresh-winner")
    }

    try await verifyOAuthSessionFlightMatrix()
}
