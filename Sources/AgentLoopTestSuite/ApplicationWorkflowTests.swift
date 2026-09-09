import Foundation
import Testing
import AgentLoopCore
import AgentLoopApplication
import GRDB

private enum ApplicationWorkflowFixtureError: Error {
    case forcedReadFailure
    case barrierTimedOut
    case missingOAuthFixtureState
    case missingScheduleFixtureState
    case scheduleStage(String)
}

private struct ApplicationWorkflowEmptyCredentialStore:
    CredentialStore, Sendable
{
    let backendNamespace: CredentialStoreBackendNamespace =
        .isolated(UUID())

    func set(_ value: String, account: String) throws {
        _ = value
        _ = account
    }

    func get(account: String) throws -> String? {
        _ = account
        return nil
    }

    func delete(account: String) throws {
        _ = account
    }
}

private final class ApplicationWorkflowCredentialStore:
    CredentialStore, @unchecked Sendable
{
    let backendNamespace: CredentialStoreBackendNamespace =
        .isolated(UUID())

    private let lock = NSLock()
    private var values: [String: String] = [:]
    private var readFailureByAccount: [String: Int32] = [:]
    private var writeFailureByAccount: [String: Int32] = [:]
    private var deleteFailureByAccount: [String: Int32] = [:]
    private var setCallsByAccount: [String: Int] = [:]

    func set(_ value: String, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        setCallsByAccount[account, default: 0] += 1
        if let status = writeFailureByAccount[account] {
            throw KeychainError(status: status)
        }
        values[account] = value
    }

    func get(account: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let status = readFailureByAccount[account] {
            throw KeychainError(status: status)
        }
        return values[account]
    }

    func delete(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        if let status = deleteFailureByAccount[account] {
            throw KeychainError(status: status)
        }
        values[account] = nil
    }

    func failReads(account: String, status: Int32) {
        lock.lock()
        readFailureByAccount[account] = status
        lock.unlock()
    }

    func failWrites(account: String, status: Int32) {
        lock.lock()
        writeFailureByAccount[account] = status
        lock.unlock()
    }

    func storedValue(account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[account]
    }

    func setCallCount(account: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return setCallsByAccount[account, default: 0]
    }
}

private final class ApplicationWorkflowToggle: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false

    func setEnabled(_ value: Bool) {
        lock.lock()
        enabled = value
        lock.unlock()
    }

    func isEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return enabled
    }
}

private struct ApplicationRuntimeFixture {
    let database: AppDatabase
    let defaults: ProfileScopedDefaults
    let store: ApplicationWorkflowCredentialStore
    let access: SynchronizedCredentialAccess
    let coordinator: CredentialBundleCoordinator
    let resolver: RuntimeCredentialResolver
    let accounts: RuntimeCredentialAccounts
    let controller: RuntimeProfileWorkflowController
    let defaultProfile: RuntimeProfileRecord
}

private final class ApplicationOAuthCodecHarness: @unchecked Sendable {
    enum PayloadMode {
        case valid
        case failed
    }

    let state = "application-oauth-state"
    let verifier = "application-oauth-verifier"
    let accessToken = "application-oauth-access"
    let refreshToken = "application-oauth-refresh"
    let idToken = "application-oauth-id"
    let accountID = "application-oauth-account"

    private let lock = NSLock()
    private var randomIndex = 0
    private var payloadMode: PayloadMode = .valid

    func setPayloadMode(_ mode: PayloadMode) {
        lock.lock()
        payloadMode = mode
        lock.unlock()
    }

    func makeCodec() -> RuntimeOAuthCodec {
        RuntimeOAuthCodec(
            randomSecret: { [self] _ in try nextSecret() },
            authorizationURL: { [self] configuration, state, _ in
                try authorizationURL(
                    configuration: configuration,
                    state: state
                )
            },
            callbackPayload: { [self] configuration, callbackURL in
                try callbackPayload(
                    configuration: configuration,
                    callbackURL: callbackURL
                )
            },
            callbackStateMatches: { configuration, callbackURL, expected in
                guard let components = URLComponents(
                    url: callbackURL,
                    resolvingAgainstBaseURL: false
                ), let expectedRedirect = URL(
                    string: configuration.redirectURI
                ), callbackURL.scheme == expectedRedirect.scheme,
                callbackURL.host == expectedRedirect.host,
                callbackURL.path == expectedRedirect.path
                else {
                    return false
                }
                let states = (components.queryItems ?? []).filter {
                    $0.name == "state"
                }
                guard states.count == 1,
                      let raw = states[0].value,
                      let returned = SecretValue.validated(raw)
                else {
                    return false
                }
                return returned.constantTimeEquals(expected)
            },
            exchange: { [self] configuration, _, _ in
                try bundle(flow: configuration.flow)
            }
        )
    }

    private func nextSecret() throws -> SecretValue {
        lock.lock()
        let index = randomIndex
        randomIndex += 1
        lock.unlock()
        switch index {
        case 0: return try SecretValue(state)
        case 1: return try SecretValue(verifier)
        default:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
    }

    private func authorizationURL(
        configuration: RuntimeOAuthConfiguration,
        state: SecretValue
    ) throws -> URL {
        guard var components = URLComponents(
            url: configuration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        components.queryItems = [
            URLQueryItem(name: "state", value: state.use { $0 }),
        ]
        guard let url = components.url else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        return url
    }

    private func callbackPayload(
        configuration: RuntimeOAuthConfiguration,
        callbackURL: URL
    ) throws -> RuntimeOAuthCallbackPayload {
        lock.lock()
        let mode = payloadMode
        lock.unlock()
        guard mode == .valid,
              let components = URLComponents(
                url: callbackURL,
                resolvingAgainstBaseURL: false
              ), let rawState = components.queryItems?.first(where: {
                $0.name == "state"
              })?.value
        else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        return .credentialBundle(
            try bundle(flow: configuration.flow),
            returnedState: try SecretValue(rawState)
        )
    }

    private func bundle(
        flow: OAuthCredentialFlow
    ) throws -> OAuthCredentialBundle {
        try OAuthCredentialBundle(
            flow: flow,
            accessToken: SecretValue(accessToken),
            refreshToken: SecretValue(refreshToken),
            idToken: SecretValue(idToken),
            accountID: SecretValue(accountID)
        )
    }
}

private final class ApplicationOAuthPlatformHarness: @unchecked Sendable {
    private let lock = NSLock()
    private var failureSink: RuntimeOAuthListenerFailureSink?
    private var starts: [(
        RuntimeOAuthAuthorizationReceipt,
        RuntimeOAuthListenerLease
    )] = []
    private var stopCountValue = 0
    private var openCountValue = 0
    private var injectFailureOnNextStart = false
    private var injectedPending:
        RuntimeOAuthAuthorizationRecoveryPending?

    func makeFactory() -> RuntimeOAuthPlatformFactory {
        RuntimeOAuthPlatformFactory { [self] sink in
            install(sink)
            return RuntimeOAuthPlatformPort(
                startListener: { [self] authorization, lease in
                    let injection = recordStart(
                        authorization: authorization,
                        lease: lease
                    )
                    if injection {
                        let outcome = await sink.handle(
                            .accept,
                            authorization: authorization,
                            lease: lease
                        )
                        recordInjected(outcome)
                    }
                    return .started
                },
                stopListenerIfOwned: { [self] _, _ in
                    recordStop()
                    return .stopped
                },
                openAuthorization: { [self] _ in recordOpen() }
            )
        }
    }

    func failNextStartThroughSink() {
        lock.lock()
        injectFailureOnNextStart = true
        lock.unlock()
    }

    func sink() -> RuntimeOAuthListenerFailureSink? {
        lock.lock()
        defer { lock.unlock() }
        return failureSink
    }

    func latestStart() -> (
        RuntimeOAuthAuthorizationReceipt,
        RuntimeOAuthListenerLease
    )? {
        lock.lock()
        defer { lock.unlock() }
        return starts.last
    }

    func injectedRecoveryPending()
        -> RuntimeOAuthAuthorizationRecoveryPending?
    {
        lock.lock()
        defer { lock.unlock() }
        return injectedPending
    }

    func counts() -> (starts: Int, stops: Int, opens: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (starts.count, stopCountValue, openCountValue)
    }

    private func install(_ sink: RuntimeOAuthListenerFailureSink) {
        lock.lock()
        failureSink = sink
        lock.unlock()
    }

    private func recordStart(
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        starts.append((authorization, lease))
        let shouldInject = injectFailureOnNextStart
        injectFailureOnNextStart = false
        return shouldInject
    }

    private func recordInjected(
        _ outcome: RuntimeOAuthAuthorizationRecoveryOutcome
    ) {
        lock.lock()
        defer { lock.unlock() }
        if case .pending(let pending, _) = outcome {
            injectedPending = pending
        }
    }

    private func recordStop() {
        lock.lock()
        stopCountValue += 1
        lock.unlock()
    }

    private func recordOpen() {
        lock.lock()
        openCountValue += 1
        lock.unlock()
    }
}

private func applicationRuntimeFixture(
    _ label: String,
    oauthPlatformFactory: RuntimeOAuthPlatformFactory? = nil,
    oauthCodec: RuntimeOAuthCodec = .live,
    strictReadFailure: ApplicationWorkflowToggle? = nil
) throws -> ApplicationRuntimeFixture {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-runtime-\(label)-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let defaultProfile = RuntimeProfileRecord(
        id: "runtime-default-\(UUID().uuidString)",
        kind: .anthropicAPI,
        name: "Application default",
        baseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
        credentialAccount: nil,
        isDefault: true,
        createdAt: Date(timeIntervalSince1970: 1_780_000_000)
    )
    try database.saveRuntimeProfile(defaultProfile)

    let defaultsName =
        "application-runtime-defaults-\(label)-\(UUID().uuidString)"
    let rawDefaults = try #require(
        UserDefaults(suiteName: defaultsName)
    )
    rawDefaults.removePersistentDomain(forName: defaultsName)
    let defaults = ProfileScopedDefaults(defaults: rawDefaults)
    let store = ApplicationWorkflowCredentialStore()
    let access = SynchronizedCredentialAccess(store: store)
    let coordinator = CredentialBundleCoordinator(access: access)
    let prefix = "application-runtime-\(UUID().uuidString)"
    let accounts = RuntimeCredentialAccounts(
        apiKey: "\(prefix)-api",
        searchKey: "\(prefix)-search",
        oauth: OAuthCredentialAccounts(
            access: "\(prefix)-oauth-access",
            refresh: "\(prefix)-oauth-refresh",
            id: "\(prefix)-oauth-id",
            accountID: "\(prefix)-oauth-account",
            verifier: "\(prefix)-oauth-verifier"
        )
    )
    let resolver = RuntimeCredentialResolver(
        database: database,
        defaults: defaults,
        credentialAccess: access,
        accounts: accounts,
        defaultBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
        tokenRefresher: nil
    )
    let selectedOAuthPlatformFactory: RuntimeOAuthPlatformFactory
    if let oauthPlatformFactory {
        selectedOAuthPlatformFactory = oauthPlatformFactory
    } else {
        selectedOAuthPlatformFactory = RuntimeOAuthPlatformFactory { _ in
            RuntimeOAuthPlatformPort(
                startListener: { _, _ in .started },
                stopListenerIfOwned: { _, _ in .stopped },
                openAuthorization: { _ in }
            )
        }
    }
    let ports = RuntimeWorkflowPorts(
        refreshCatalog: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        testProvider: { _, _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        oauthPlatformFactory: selectedOAuthPlatformFactory,
        oauthCodec: oauthCodec
    )
    let workflowReads: RuntimeWorkflowReads?
    if let strictReadFailure {
        workflowReads = RuntimeWorkflowReads(load: {
            if strictReadFailure.isEnabled() {
                throw ApplicationWorkflowFixtureError.forcedReadFailure
            }
            return try database.readRuntimeWorkflowBundle()
        })
    } else {
        workflowReads = nil
    }
    let controller = RuntimeProfileWorkflowController(
        database: database,
        defaults: defaults,
        resolver: resolver,
        credentialAccounts: accounts,
        credentialCoordinator: coordinator,
        reporter: FailureReporter(database: database),
        reads: workflowReads,
        ports: ports
    )
    return ApplicationRuntimeFixture(
        database: database,
        defaults: defaults,
        store: store,
        access: access,
        coordinator: coordinator,
        resolver: resolver,
        accounts: accounts,
        controller: controller,
        defaultProfile: defaultProfile
    )
}

private func applicationRuntimeTrace(
    operation: FailureOperation,
    profile: RuntimeProfileRecord
) throws -> OperationTrace {
    try OperationTraceFactory.live.generated(
        operation: operation,
        scope: .global(
            recordId: FailureRecordID.runtimeProfile(profile),
            as: .runtimeProfile
        )
    )
}

private struct ApplicationPreparedOAuth {
    let reservation: RuntimeOAuthAuthorizationReservation
    let authorization: RuntimeOAuthAuthorizationReceipt
    let lease: RuntimeOAuthListenerLease
}

private func applicationOAuthTrace(
    _ operation: FailureOperation
) -> OperationTrace {
    OperationTraceFactory.live.generated(
        operation: operation,
        scope: .fixed(.oauth)
    )
}

private func applicationOAuthConfiguration()
    throws -> RuntimeOAuthConfiguration
{
    RuntimeOAuthConfiguration(
        flow: .chatGPT,
        authorizationEndpoint: try #require(
            URL(string: "https://oauth.example/authorize")
        ),
        tokenEndpoint: try #require(
            URL(string: "https://oauth.example/token")
        ),
        redirectURI: "http://127.0.0.1:1455/oauth/callback",
        clientID: "application-test-client",
        requiresAccountID: true,
        requiresLocalListener: true
    )
}

private func applicationOAuthCallbackURL(
    state: String
) throws -> URL {
    try #require(URL(
        string: "http://127.0.0.1:1455/oauth/callback?state=\(state)"
    ))
}

private func applicationPrepareOAuth(
    fixture: ApplicationRuntimeFixture,
    platform: ApplicationOAuthPlatformHarness,
    openBrowser: Bool = true
) async throws -> ApplicationPreparedOAuth {
    let reserve = await fixture.controller.reserveOAuthAuthorizationAttempt(
        flow: .chatGPT,
        trace: applicationOAuthTrace(.oauthAuthorization)
    )
    let reservation: RuntimeOAuthAuthorizationReservation
    switch reserve {
    case .reserved(let value):
        reservation = value
    case .rejected:
        throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
    }
    let prepared = await fixture.controller.prepareOAuthAuthorization(
        RuntimeOAuthAuthorizationCommand(
            configuration: try applicationOAuthConfiguration()
        ),
        reservation: reservation
    )
    let authorization: RuntimeOAuthAuthorizationReceipt
    switch prepared {
    case .prepared(let value):
        authorization = value
    case .notCommitted, .recoveryPending, .superseded:
        throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
    }
    let start = try #require(platform.latestStart())
    #expect(start.0 == authorization)
    if openBrowser {
        let opened = await fixture.controller.openOAuthAuthorization(
            .prepared(authorization, reservation: reservation)
        )
        switch opened {
        case .opened(let current):
            #expect(current == authorization)
        case .retainedRecovery, .recoveryPending, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
    }
    return ApplicationPreparedOAuth(
        reservation: reservation,
        authorization: authorization,
        lease: start.1
    )
}

private final class ApplicationInputReadHarness:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let database: AppDatabase
    private var campFailureEnabled = false

    init(database: AppDatabase) {
        self.database = database
    }

    func setCampFailureEnabled(_ enabled: Bool) {
        lock.lock()
        campFailureEnabled = enabled
        lock.unlock()
    }

    func readCamp(_ campId: String) throws -> InputCampReadBundle {
        lock.lock()
        let shouldFail = campFailureEnabled
        lock.unlock()
        if shouldFail {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        return try database.readInputCampBundle(campId: campId)
    }
}

private final class ApplicationWALReadBarrier: @unchecked Sendable {
    private let anchorReached = DispatchSemaphore(value: 0)
    private let writerCommitted = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var writerTimedOut = false

    func afterAnchorRead() {
        anchorReached.signal()
        if writerCommitted.wait(timeout: .now() + 60) != .success {
            lock.lock()
            writerTimedOut = true
            lock.unlock()
        }
    }

    func waitUntilAnchor() throws {
        guard anchorReached.wait(timeout: .now() + 60) == .success
        else {
            writerCommitted.signal()
            throw ApplicationWorkflowFixtureError.barrierTimedOut
        }
    }

    func signalWriterCommitted() {
        writerCommitted.signal()
    }

    func requireWriterWasObserved() throws {
        lock.lock()
        let timedOut = writerTimedOut
        lock.unlock()
        if timedOut {
            throw ApplicationWorkflowFixtureError.barrierTimedOut
        }
    }
}

private final class ApplicationThreadResultBox<Value: Sendable>:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var result: Result<Value, Error>?

    func store(_ result: Result<Value, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func take() -> Result<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let stored = result
        result = nil
        return stored
    }
}

private func applicationReadWhileWriterCommits<Value: Sendable>(
    read: @escaping @Sendable (@Sendable () -> Void) throws -> Value,
    writer: @escaping @Sendable () throws -> Void
) throws -> Value {
    let barrier = ApplicationWALReadBarrier()
    let readerResult = ApplicationThreadResultBox<Value>()
    let writerResult = ApplicationThreadResultBox<Void>()
    let readerFinished = DispatchSemaphore(value: 0)
    let writerFinished = DispatchSemaphore(value: 0)
    let reader = Thread {
        let result: Result<Value, Error> = Result {
            try read { barrier.afterAnchorRead() }
        }
        readerResult.store(result)
        readerFinished.signal()
    }
    reader.name = "ApplicationWorkflowTests.WALReader"
    reader.start()
    do {
        try barrier.waitUntilAnchor()
    } catch {
        barrier.signalWriterCommitted()
        _ = readerFinished.wait(timeout: .now() + 60)
        throw error
    }
    let writerThread = Thread {
        let result: Result<Void, Error> = Result {
            try writer()
        }
        writerResult.store(result)
        barrier.signalWriterCommitted()
        writerFinished.signal()
    }
    writerThread.name = "ApplicationWorkflowTests.WALWriter"
    writerThread.start()
    guard readerFinished.wait(timeout: .now() + 60) == .success,
          writerFinished.wait(timeout: .now() + 60) == .success,
          let readerResult = readerResult.take(),
          let writerResult = writerResult.take()
    else {
        throw ApplicationWorkflowFixtureError.barrierTimedOut
    }
    try barrier.requireWriterWasObserved()
    try writerResult.get()
    return try readerResult.get()
}

private func applicationCloneDatabase(
    from source: AppDatabase,
    directory: URL,
    label: String
) throws -> AppDatabase {
    let clone = try AppDatabase(
        path: directory
            .appendingPathComponent(
                "application-clone-\(label)-\(UUID().uuidString).sqlite"
            )
            .path
    )
    try source.pool.backup(to: clone.pool)
    return clone
}

private func applicationInputRuminationResult(
    _ label: String
) -> RuminationResult {
    RuminationResult(
        suggestedTitle: "title-\(label)",
        summary: "summary-\(label)",
        keyPoints: [
            .init(
                text: "point-\(label)",
                sourceQuote: "quote-\(label)"
            ),
        ],
        requirements: [
            .init(
                title: "requirement-\(label)",
                detail: "detail-\(label)",
                confidence: .high
            ),
        ],
        todos: [.init(title: "todo-\(label)")],
        suggestedMission: .init(
            goal: "goal-\(label)",
            acceptance: ["acceptance-\(label)"],
            why: "why-\(label)"
        ),
        uncertainties: []
    )
}

private func applicationExpectInvalidPayload(
    _ operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("expected invalid aggregate payload")
    } catch let error as ProjectionContractError {
        #expect(error == .invalidPayload)
    } catch {
        Issue.record("unexpected aggregate error: \(type(of: error))")
    }
}

private func applicationExpectNotFound(
    _ expected: RecordNotFoundError,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("expected aggregate record-not-found")
    } catch let error as RecordNotFoundError {
        #expect(error == expected)
    } catch {
        Issue.record("unexpected aggregate error: \(type(of: error))")
    }
}

private func applicationWorkflowFailure(
    _ label: String
) throws -> UserVisibleFailure {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-workflow-\(label)-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let trace = OperationTraceFactory.live.generated(
        operation: .memoryNoteLoad,
        scope: .fixed(.memoryDM)
    )
    return FailureReporter(database: database).capture(
        ApplicationWorkflowFixtureError.forcedReadFailure,
        trace: trace
    )
}

@Test func databaseReadFailureIsFailedNotLoadedEmpty() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-read-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let reporter = FailureReporter(database: database)
    let trace = OperationTraceFactory.live.generated(
        operation: .memoryNoteLoad,
        scope: .fixed(.memoryDM)
    )
    let terminal: WorkflowLoadState<[String]> = captureSynchronousLoad(
        reporter: reporter,
        trace: trace
    ) {
        throw ApplicationWorkflowFixtureError.forcedReadFailure
    }
    switch terminal {
    case .failed(let failure):
        #expect(failure.traceId == trace.traceId)
        #expect(failure.operation == .memoryNoteLoad)
    case .loaded, .idle, .loading:
        Issue.record("read failure was projected as a success-like state")
    }

    let bootstrap = try ProductBootstrapService(db: database)
        .ensureBootstrap()
    let baseCow = try #require(bootstrap.baseCow)
    let template = MissionTemplateRecord(
        id: "wal-schedule-template",
        name: "template-pre",
        goal: "schedule WAL snapshot",
        companionIdsJson: try MissionTemplateRecord.companionIdsJSON([
            baseCow.id,
        ]),
        workspacePath: nil,
        budgetTokens: 1_000,
        autonomy: .standard,
        campId: bootstrap.camp.id,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    try database.saveMissionTemplate(template)
    let schedule = ScheduleRecord(
        id: "wal-schedule",
        templateId: template.id,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        enabled: true,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 101)
    )
    try database.saveSchedule(schedule)
    try await database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO schedule_evaluation_cursor(
                  scheduleId, lastEvaluatedSlotKey,
                  lastEvaluatedScheduledAt, version, updatedAt
                ) VALUES (?, ?, ?, ?, ?)
                """,
            arguments: [
                schedule.id,
                "slot-pre",
                102.0,
                1,
                103.0,
            ]
        )
    }

    let workflowDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readScheduleWorkflowBundleForTesting(
                campId: bootstrap.camp.id,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                guard var changedTemplate = try MissionTemplateRecord
                    .fetchOne(db, key: template.id),
                      var changedSchedule = try ScheduleRecord.fetchOne(
                        db,
                        key: schedule.id
                      )
                else {
                    throw ProjectionContractError.invalidPayload
                }
                changedTemplate.name = "template-post"
                changedSchedule.hour = 10
                try changedTemplate.update(db)
                try changedSchedule.update(db)
            }
        }
    )
    #expect(workflowDuringWrite.templates.map(\.name) == ["template-pre"])
    #expect(workflowDuringWrite.schedules.map(\.hour) == [9])
    let workflowAfterWrite = try database.readScheduleWorkflowBundle(
        campId: bootstrap.camp.id
    )
    #expect(workflowAfterWrite.templates.map(\.name) == ["template-post"])
    #expect(workflowAfterWrite.schedules.map(\.hour) == [10])

    let runtimeDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readScheduleRuntimeBundleForTesting(
                templateId: template.id,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                try db.execute(
                    sql: """
                        UPDATE schedule_evaluation_cursor
                        SET lastEvaluatedSlotKey = ?, version = ?, updatedAt = ?
                        WHERE scheduleId = ?
                        """,
                    arguments: [
                        "slot-post",
                        2,
                        104.0,
                        schedule.id,
                    ]
                )
                guard var changedTemplate = try MissionTemplateRecord
                    .fetchOne(db, key: template.id)
                else {
                    throw ProjectionContractError.invalidPayload
                }
                changedTemplate.goal = "runtime-post"
                try changedTemplate.update(db)
            }
        }
    )
    #expect(
        runtimeDuringWrite.cursorByScheduleId[schedule.id]?
            .lastEvaluatedSlotKey == "slot-pre"
    )
    #expect(runtimeDuringWrite.requestedTemplate?.goal == template.goal)
    let runtimeAfterWrite = try database.readScheduleRuntimeBundle(
        templateId: template.id
    )
    #expect(
        runtimeAfterWrite.cursorByScheduleId[schedule.id]?
            .lastEvaluatedSlotKey == "slot-post"
    )
    #expect(runtimeAfterWrite.requestedTemplate?.goal == "runtime-post")

    let missionIds = try database.createSingleCardMission(
        campName: bootstrap.camp.name,
        squadName: "notification-pre",
        goal: "notification-pre",
        cardTitle: "notification-card",
        cardDescription: "notification-description",
        expectedOutput: "notification-output",
        assigneeId: baseCow.id,
        maxTurns: 2,
        campId: bootstrap.camp.id
    )
    try await database.pool.write { db in
        try AppDatabase.appendEvent(
            db,
            missionId: missionIds.missionId,
            cardId: nil,
            runId: nil,
            kind: EventKind.scheduleFired,
            payload: [
                "scheduleId": .string(schedule.id),
                "templateId": .string(template.id),
            ]
        )
    }
    let notificationDuringWrite = try
        applicationReadWhileWriterCommits(
            read: { hook in
                try database
                    .readScheduledMissionNotificationBundleForTesting(
                        missionId: missionIds.missionId,
                        afterAnchorRead: hook
                    )
            },
            writer: {
                try database.pool.write { db in
                    guard var mission = try MissionRecord.fetchOne(
                        db,
                        key: missionIds.missionId
                    ), var squad = try SquadRecord.fetchOne(
                        db,
                        key: missionIds.squadId
                    ) else {
                        throw ProjectionContractError.invalidPayload
                    }
                    mission.goalRefined = "notification-post"
                    squad.name = "notification-post"
                    try mission.update(db)
                    try squad.update(db)
                    try AppDatabase.appendEvent(
                        db,
                        missionId: mission.id,
                        cardId: nil,
                        runId: nil,
                        kind: EventKind.progressNote,
                        payload: ["source": .string("post")]
                    )
                }
            }
        )
    let notificationSnapshot = try #require(notificationDuringWrite)
    #expect(notificationSnapshot.mission.goalRefined == "notification-pre")
    #expect(notificationSnapshot.squad.name == "notification-pre")
    #expect(
        !notificationSnapshot.events.contains {
            $0.kind == EventKind.progressNote
        }
    )
    let notificationAfterRead = try database
        .readScheduledMissionNotificationBundle(
            missionId: missionIds.missionId
        )
    let notificationAfterWrite = try #require(
        notificationAfterRead
    )
    #expect(notificationAfterWrite.mission.goalRefined == "notification-post")
    #expect(notificationAfterWrite.squad.name == "notification-post")
    #expect(
        notificationAfterWrite.events.contains {
            $0.kind == EventKind.progressNote
        }
    )
}

@Test func workflowProjectionPreservesPriorValueOnRefreshFailure()
    async throws
{
    let failure = try applicationWorkflowFailure("refresh-preserves")
    var projection = WorkflowProjection(loaded: ["prior"])
    let generation = try projection.beginRefresh()
    let applied = try projection.applyTerminal(
        WorkflowLoadState<[String]>.failed(failure),
        for: generation
    )
    #expect(applied)
    #expect(projection.lastLoadedValue == ["prior"])
    if case .failed(let visible) = projection.state {
        #expect(visible.traceId == failure.traceId)
    } else {
        Issue.record("refresh failure was not visible")
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-mission-wal-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let bootstrap = try ProductBootstrapService(db: database)
        .ensureBootstrap()
    let baseCow = try #require(bootstrap.baseCow)
    let ids = try database.createSingleCardMission(
        campName: bootstrap.camp.name,
        squadName: "WAL Squad",
        goal: "mission-pre",
        cardTitle: "card-pre",
        cardDescription: "description-pre",
        expectedOutput: "output-pre",
        assigneeId: baseCow.id,
        maxTurns: 2,
        campId: bootstrap.camp.id
    )
    try await database.pool.write { db in
        guard var squad = try SquadRecord.fetchOne(db, key: ids.squadId)
        else {
            throw RecordNotFoundError(
                table: SquadRecord.databaseTableName,
                id: ids.squadId
            )
        }
        squad.memberIdsJson = String(
            decoding: try JSONEncoder().encode([baseCow.id]),
            as: UTF8.self
        )
        try squad.update(db)
    }

    let detailDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readMissionDetailBundleForTesting(
                missionId: ids.missionId,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                guard var mission = try MissionRecord.fetchOne(
                    db,
                    key: ids.missionId
                ), var card = try CardRecord.fetchOne(
                    db,
                    key: ids.cardId
                ) else {
                    throw ProjectionContractError.invalidPayload
                }
                mission.goalRefined = "mission-post"
                card.title = "card-post"
                try mission.update(db)
                try card.update(db)
                try ArtifactRecord(
                    id: "artifact-post",
                    cardId: ids.cardId,
                    path: "/tmp/artifact-post",
                    kind: "file",
                    label: "artifact-post",
                    createdAt: Date(timeIntervalSince1970: 20)
                ).insert(db)
            }
        }
    )
    #expect(detailDuringWrite.mission.goalRefined == "mission-pre")
    #expect(detailDuringWrite.cards.map(\.title) == ["card-pre"])
    #expect(detailDuringWrite.artifacts.isEmpty)
    #expect(detailDuringWrite.squadMemberIds == [baseCow.id])
    #expect(detailDuringWrite.companionsById[baseCow.id]?.id == baseCow.id)
    let detailAfterWrite = try database.readMissionDetailBundle(
        missionId: ids.missionId
    )
    #expect(detailAfterWrite.mission.goalRefined == "mission-post")
    #expect(detailAfterWrite.cards.map(\.title) == ["card-post"])
    #expect(detailAfterWrite.artifacts.map(\.id) == ["artifact-post"])

    let indexDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readMissionIndexBundleForTesting(
                includeArchived: true,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                let camp = CampRecord(
                    id: "camp-index-post",
                    name: "Index Post Camp",
                    createdAt: Date(timeIntervalSince1970: 30)
                )
                try camp.insert(db)
                let squad = SquadRecord(
                    id: "squad-index-post",
                    campId: camp.id,
                    name: "Index Post Squad",
                    memberIdsJson: "[]",
                    workspacePath: nil,
                    createdAt: Date(timeIntervalSince1970: 31)
                )
                try squad.insert(db)
                try MissionRecord(
                    id: "mission-index-post",
                    squadId: squad.id,
                    goalRaw: "index-post",
                    goalRefined: "index-post",
                    status: .planning,
                    budgetTokens: 1_000,
                    spentTokens: 0,
                    revision: 1,
                    createdAt: Date(timeIntervalSince1970: 32)
                ).insert(db)
                try ArtifactRecord(
                    id: "artifact-index-post",
                    cardId: ids.cardId,
                    path: "/tmp/artifact-index-post",
                    kind: "file",
                    label: "artifact-index-post",
                    createdAt: Date(timeIntervalSince1970: 33)
                ).insert(db)
            }
        }
    )
    #expect(!indexDuringWrite.camps.contains { $0.id == "camp-index-post" })
    #expect(
        !indexDuringWrite.missions.contains {
            $0.id == "mission-index-post"
        }
    )
    #expect(
        !indexDuringWrite.artifactLedger.contains {
            $0.id == "artifact-index-post"
        }
    )
    let indexAfterWrite = try database.readMissionIndexBundle(
        includeArchived: true
    )
    #expect(indexAfterWrite.camps.contains { $0.id == "camp-index-post" })
    #expect(
        indexAfterWrite.missions.contains {
            $0.id == "mission-index-post"
        }
    )
    #expect(
        indexAfterWrite.missionsByCamp["camp-index-post"]?.map(\.id)
            == ["mission-index-post"]
    )
    #expect(
        indexAfterWrite.artifactLedger.contains {
            $0.id == "artifact-index-post"
        }
    )
}

@Test func workflowGenerationRejectsStaleTerminalCompletion() throws {
    var projection = WorkflowProjection(loaded: ["initial"])
    let stale = try projection.beginRefresh()
    let current = try projection.beginRefresh()
    let staleApplied = try projection.applyTerminal(
        WorkflowLoadState<[String]>.loaded(["stale"]),
        for: stale
    )
    #expect(!staleApplied)
    #expect(projection.lastLoadedValue == ["initial"])
    let currentApplied = try projection.applyTerminal(
        WorkflowLoadState<[String]>.loaded(["current"]),
        for: current
    )
    #expect(currentApplied)
    #expect(projection.lastLoadedValue == ["current"])
}

@Test func workflowCancellationCannotMasqueradeAsLoaded() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("application-cancel-(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let reporter = FailureReporter(database: database)
    let trace = OperationTraceFactory.live.generated(
        operation: .memoryNoteLoad,
        scope: .fixed(.memoryDM)
    )
    let terminal: WorkflowLoadState<[String]> = await captureAsyncLoad(
        reporter: reporter,
        trace: trace
    ) {
        throw CancellationError()
    }
    switch terminal {
    case .failed(let failure):
        #expect(failure.traceId == trace.traceId)
    case .loaded, .idle, .loading:
        Issue.record("cancellation was projected as a success-like state")
    }
}

@Test func missionStartPreservesCallerDurableTrace() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-mission-start-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let bootstrap = try ProductBootstrapService(db: database)
        .ensureBootstrap()
    let baseCow = try #require(bootstrap.baseCow)
    _ = try seedTestPlanningProfile(
        database,
        profileId: "fixture-runtime"
    )
    let reporter = FailureReporter(database: database)
    let orchestrator = Orchestrator(
        db: database,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: MockProvider(script: [])
        ),
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: directory.appendingPathComponent("artifacts"),
        tickInterval: nil,
        failureReporter: reporter
    )
    await orchestrator.recoverAndReconcile()
    let planningCoordinator = await PlanningEntryCoordinator(
        db: database,
        orchestrator: orchestrator
    )
    let controller = await MissionWorkflowController(
        database: database,
        orchestrator: orchestrator,
        planningCoordinator: planningCoordinator,
        reportStoreRoot: directory.appendingPathComponent("reports"),
        selectRuntime: {
            PlanningEntryRuntimeSelection(
                runtimeProfileId: "fixture-runtime",
                plannerModel: "fixture-planner"
            )
        },
        reporter: reporter,
        traceFactory: .live,
        registrationEvaluation: {
            ScheduleRegistrationEvaluation(
                now: Date(timeIntervalSince1970: 1_780_000_000),
                timeZone: TimeZone(secondsFromGMT: 0)!
            )
        }
    )
    let traceFactory = OperationTraceFactory(
        makeID: { UUID() },
        now: { Date(timeIntervalSince1970: 1_780_000_000) }
    )
    let durableTrace = "application-mission-caller-trace"
    let request = MissionStartRequest(
        goal: "produce an observable artifact",
        companionIds: [baseCow.id],
        workspacePath: nil,
        plannerModel: "fixture-planner",
        runtimeProfileId: "fixture-runtime",
        budgetTokens: 1_000,
        campId: bootstrap.camp.id,
        autonomy: .standard,
        idempotencyKey: "mission-start:application-trace:v1",
        durableTraceId: durableTrace
    )
    let mismatchedTrace = try traceFactory.adopting(
        "application-mission-other-trace",
        operation: .missionStart,
        scope: .fixed(.missionIndex)
    )
    let beforeCounts = try await database.pool.read { db in
        (
            missions: try MissionRecord.fetchCount(db),
            work: try DurableWorkRecord.fetchCount(db)
        )
    }
    switch await controller.start(request, trace: mismatchedTrace) {
    case .notCommitted(let failure):
        #expect(failure.traceId == mismatchedTrace.traceId)
        #expect(failure.operation == .missionStart)
    case .committed, .committedWithVisibilityFailure:
        Issue.record("trace mismatch committed Mission work")
    }
    let afterMismatchCounts = try await database.pool.read { db in
        (
            missions: try MissionRecord.fetchCount(db),
            work: try DurableWorkRecord.fetchCount(db)
        )
    }
    #expect(afterMismatchCounts.missions == beforeCounts.missions)
    #expect(afterMismatchCounts.work == beforeCounts.work)

    let matchingTrace = try traceFactory.adopting(
        durableTrace,
        operation: .missionStart,
        scope: .fixed(.missionIndex)
    )
    let missionId: String
    switch await controller.start(request, trace: matchingTrace) {
    case .notCommitted(let failure):
        Issue.record("matching Mission start failed: \(failure.message)")
        await orchestrator.shutdown()
        return
    case .committed(let value):
        missionId = value
    case .committedWithVisibilityFailure(let value, let failure):
        #expect(failure.traceId == durableTrace)
        missionId = value
    }
    let persisted = try await database.pool.read { db in
        try DurableWorkRecord
            .filter(
                Column("kind") == DurableWorkKind.planning.rawValue
                    && Column("aggregateId") == missionId
            )
            .fetchOne(db)
    }
    #expect(try #require(persisted).traceId == durableTrace)
    #expect(try database.mission(id: missionId)?.id == missionId)
    await orchestrator.shutdown()
}

@Test func runtimeProfileWriteFailureNeverProjectsSuccess() async throws {
    let fixture = try applicationRuntimeFixture("profile-write")
    let profile = RuntimeProfileRecord(
        id: "runtime-profile-write-failure",
        kind: .openAIAPI,
        name: "Must not persist",
        baseURL: "https://api.openai.com/v1",
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 1_780_000_001)
    )
    try await fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_runtime_profile_insert
            BEFORE INSERT ON runtime_profile
            WHEN NEW.id = 'runtime-profile-write-failure'
            BEGIN
              SELECT RAISE(ABORT, 'forced runtime profile insert failure');
            END
            """)
    }
    let trace = try applicationRuntimeTrace(
        operation: .runtimeProfileSave,
        profile: profile
    )
    switch await fixture.controller.saveProfile(profile, trace: trace) {
    case .notCommitted(let failure):
        #expect(failure.traceId == trace.traceId)
        #expect(failure.operation == .runtimeProfileSave)
    case .committed, .committedWithVisibilityFailure:
        Issue.record("failed Runtime profile write projected success")
    }
    #expect(try fixture.database.runtimeProfile(id: profile.id) == nil)
    #expect(try fixture.database.defaultProfile() == fixture.defaultProfile)
}

@Test func runtimeProfileDeleteFailureNeverProjectsSuccess() async throws {
    let fixture = try applicationRuntimeFixture("profile-delete")
    let profile = RuntimeProfileRecord(
        id: "runtime-profile-delete-failure",
        kind: .openAIAPI,
        name: "Must remain",
        baseURL: "https://api.openai.com/v1",
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 1_780_000_002)
    )
    try fixture.database.saveRuntimeProfile(profile)
    try await fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_runtime_profile_delete
            BEFORE DELETE ON runtime_profile
            WHEN OLD.id = 'runtime-profile-delete-failure'
            BEGIN
              SELECT RAISE(ABORT, 'forced runtime profile delete failure');
            END
            """)
    }
    let trace = try applicationRuntimeTrace(
        operation: .runtimeProfileDelete,
        profile: profile
    )
    switch await fixture.controller.deleteProfile(
        id: profile.id,
        trace: trace
    ) {
    case .notCommitted(let failure):
        #expect(failure.traceId == trace.traceId)
        #expect(failure.operation == .runtimeProfileDelete)
    case .committed, .committedWithVisibilityFailure:
        Issue.record("failed Runtime profile delete projected success")
    }
    #expect(try fixture.database.runtimeProfile(id: profile.id) == profile)
    #expect(try fixture.database.defaultProfile() == fixture.defaultProfile)
}

@Test func runtimeReconcileFailureNeverChangesDefault() async throws {
    let fixture = try applicationRuntimeFixture("reconcile")
    let target = RuntimeProfileRecord(
        id: "runtime-profile-reconcile-target",
        kind: .chatGPTOAuth,
        name: "Reconcile target",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: false,
        createdAt: Date(timeIntervalSince1970: 1_780_000_003)
    )
    try fixture.database.saveRuntimeProfile(target)
    var companion = CompanionRecord.new(
        name: "Pinned companion",
        color: "blue",
        rolePrompt: "test",
        model: "unsupported-pinned-model"
    )
    companion.id = "runtime-reconcile-companion"
    companion.runtimeProfileId = target.id
    companion.modelPolicy = .pinned
    try fixture.database.saveCompanion(companion)
    try await fixture.database.pool.write { database in
        try database.execute(sql: """
            CREATE TRIGGER fail_runtime_reconciliation
            BEFORE UPDATE ON companion
            WHEN OLD.id = 'runtime-reconcile-companion'
            BEGIN
              SELECT RAISE(ABORT, 'forced reconciliation failure');
            END
            """)
    }
    let trace = try applicationRuntimeTrace(
        operation: .runtimeProfileSwitch,
        profile: target
    )
    let command = RuntimeProfileSwitchCommand(
        profileId: target.id,
        inheritCompanionIds: [companion.id],
        resetSettingScopes: []
    )
    switch await fixture.controller.switchDefault(command, trace: trace) {
    case .notCommitted(let failure):
        #expect(failure.traceId == trace.traceId)
        #expect(failure.operation == .runtimeProfileSwitch)
    case .committed, .committedWithVisibilityFailure:
        Issue.record("failed reconciliation changed the default profile")
    }
    #expect(try fixture.database.defaultProfile() == fixture.defaultProfile)
    #expect(try fixture.database.runtimeProfile(id: target.id)?.isDefault == false)
    let storedCompanion = try #require(
        try fixture.database.companion(id: companion.id)
    )
    #expect(storedCompanion.modelPolicy == .pinned)
    #expect(storedCompanion.model == companion.model)
}

@Test func keychainReadDistinguishesNotFoundFromFailure() throws {
    let store = ApplicationWorkflowCredentialStore()
    let access = SynchronizedCredentialAccess(store: store)
    let account = "application-keychain-read"
    #expect(
        try access.read(
            account: account,
            interactionPolicy: .failIfInteractionRequired
        ) == nil
    )

    let status: Int32 = -34_018
    store.failReads(account: account, status: status)
    do {
        _ = try access.read(
            account: account,
            interactionPolicy: .failIfInteractionRequired
        )
        Issue.record("Keychain read failure became item-not-found")
    } catch let error as KeychainError {
        #expect(error.status == status)
    } catch {
        Issue.record("unexpected credential read error: \(type(of: error))")
    }
}

@Test func keychainMutationFailureNeverProjectsSuccess() async throws {
    let fixture = try applicationRuntimeFixture("credential-write")
    let status: Int32 = -50
    fixture.store.failWrites(
        account: fixture.accounts.searchKey,
        status: status
    )
    let trace = OperationTraceFactory.live.generated(
        operation: .runtimeCredentialSet,
        scope: .fixed(.credential)
    )
    let value = try SecretValue("application-search-secret")
    switch await fixture.controller.setCredential(
        slot: .searchKey,
        value: value,
        trace: trace
    ) {
    case .notCommitted(let failure):
        #expect(failure.traceId == trace.traceId)
        #expect(failure.operation == .runtimeCredentialSet)
    case .committed, .attachmentPending,
         .committedWithVisibilityFailure:
        Issue.record("failed credential mutation projected success")
    }
    #expect(
        fixture.store.storedValue(
            account: fixture.accounts.searchKey
        ) == nil
    )
}

@Test func mcpRegistryRefreshFailurePreservesPriorRegistry() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-mcp-registry-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let manager = McpServerManager(db: database)
    let access = SynchronizedCredentialAccess(
        store: ApplicationWorkflowEmptyCredentialStore()
    )
    let coordinator = CredentialBundleCoordinator(access: access)
    let priorServer = McpServerRecord.new(
        name: "Prior MCP",
        command: "/usr/bin/true",
        args: []
    )
    let prior = McpRegistrySnapshot(
        servers: [priorServer],
        statuses: [priorServer.id: .running(toolCount: 2)]
    )
    let reads = McpWorkflowReads(
        registry: {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        enabled: { _ in [] },
        tools: { _ in [] },
        secret: { _, _ in false },
        companionEditor: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
    )
    let ports = McpWorkflowPorts(
        addServer: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        startServer: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        restartServer: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        setEnabled: { _, _, _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        mutateSecret: { _, _, _, _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        deleteServer: { serverId, _, _ in
            .notCommitted(.maintenance(
                .serverMissing(serverId: serverId)
            ))
        },
        finishServerCleanup: { pending in
            .failure(.invalidLease(serverId: pending.serverId))
        },
        saveCompanion: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
    )
    let controller = McpWorkflowController(
        database: database,
        manager: manager,
        credentialCoordinator: coordinator,
        reporter: FailureReporter(database: database),
        reads: reads,
        ports: ports
    )
    var projection = WorkflowProjection(loaded: prior)
    let generation = try projection.beginRefresh()
    let trace = OperationTraceFactory.live.generated(
        operation: .mcpRegistryLoad,
        scope: .fixed(.mcpRegistry)
    )
    let terminal = await controller.loadRegistry(trace: trace)
    #expect(try projection.applyTerminal(terminal, for: generation))
    let preserved = try #require(projection.lastLoadedValue)
    #expect(preserved.servers.map(\.id) == [priorServer.id])
    #expect(
        preserved.statuses[priorServer.id] == .running(toolCount: 2)
    )
    switch projection.state {
    case .failed(let failure):
        #expect(failure.traceId == trace.traceId)
        #expect(failure.operation == .mcpRegistryLoad)
    case .idle, .loading, .loaded:
        Issue.record("MCP registry refresh failure became success-like state")
    }
}

@Test func inputRefreshFailurePreservesDashboardAndInbox() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-input-refresh-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let bootstrap = try ProductBootstrapService(db: database)
        .ensureBootstrap()
    guard case .created(let ingestion) = try FeedService(db: database)
        .submit(
            campId: bootstrap.camp.id,
            rawText: "需要保留在失败刷新后的输入资料",
            title: "输入投影"
        )
    else {
        Issue.record("input fixture was unexpectedly deduplicated")
        return
    }

    let defaultsName =
        "application-input-defaults-\(UUID().uuidString)"
    let rawDefaults = try #require(
        UserDefaults(suiteName: defaultsName)
    )
    rawDefaults.removePersistentDomain(forName: defaultsName)
    let scopedDefaults = ProfileScopedDefaults(defaults: rawDefaults)
    let access = SynchronizedCredentialAccess(
        store: ApplicationWorkflowEmptyCredentialStore()
    )
    let accounts = RuntimeCredentialAccounts(
        apiKey: "application-input-api",
        searchKey: "application-input-search",
        oauth: .live
    )
    let resolver = RuntimeCredentialResolver(
        database: database,
        defaults: scopedDefaults,
        credentialAccess: access,
        accounts: accounts,
        defaultBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
        tokenRefresher: nil
    )
    let orchestrator = Orchestrator(
        db: database,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: MockProvider(script: [])
        ),
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: directory.appendingPathComponent("artifacts"),
        tickInterval: nil
    )
    let harness = ApplicationInputReadHarness(database: database)
    let reporter = FailureReporter(database: database)
    let controller = InputWorkflowController(
        database: database,
        orchestrator: orchestrator,
        resolver: resolver,
        reporter: reporter,
        reads: InputWorkflowReads(
            camp: { try harness.readCamp($0) },
            review: { _ in
                throw ApplicationWorkflowFixtureError.forcedReadFailure
            }
        )
    )

    var projection = WorkflowProjection<InputCampSnapshot>()
    let firstGeneration = try projection.beginRefresh()
    let firstTrace = OperationTraceFactory.live.generated(
        operation: .inputCampLoad,
        scope: .fixed(.application)
    )
    let firstTerminal = await controller.loadCamp(
        campId: bootstrap.camp.id,
        trace: firstTrace
    )
    #expect(
        try projection.applyTerminal(
            firstTerminal,
            for: firstGeneration
        )
    )
    let prior = try #require(projection.lastLoadedValue)
    #expect(prior.camp.id == bootstrap.camp.id)
    #expect(prior.ingestionItems.map(\.id) == [ingestion.id])
    #expect(prior.guide.kind == .guide)

    harness.setCampFailureEnabled(true)
    let failedGeneration = try projection.beginRefresh()
    let failedTrace = OperationTraceFactory.live.generated(
        operation: .inputCampLoad,
        scope: .fixed(.application)
    )
    let failedTerminal = await controller.loadCamp(
        campId: bootstrap.camp.id,
        trace: failedTrace
    )
    #expect(
        try projection.applyTerminal(
            failedTerminal,
            for: failedGeneration
        )
    )
    let preserved = try #require(projection.lastLoadedValue)
    #expect(preserved.camp.id == prior.camp.id)
    #expect(preserved.ingestionItems.map(\.id) == [ingestion.id])
    switch projection.state {
    case .failed(let failure):
        #expect(failure.traceId == failedTrace.traceId)
        #expect(failure.operation == .inputCampLoad)
    case .idle, .loading, .loaded:
        Issue.record("input refresh failure became success-like state")
    }

    let campBefore = try database.readInputCampBundle(
        campId: bootstrap.camp.id
    )
    let guideBeforeName = campBefore.guide.name
    let itemBeforeTitle = try #require(
        campBefore.ingestionItems.first(where: { $0.id == ingestion.id })
    ).title
    let campDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readInputCampBundleForTesting(
                campId: bootstrap.camp.id,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                guard var camp = try CampRecord.fetchOne(
                    db,
                    key: bootstrap.camp.id
                ), var guide = try CompanionRecord.fetchOne(
                    db,
                    key: campBefore.guide.id
                ), var item = try IngestionItemRecord.fetchOne(
                    db,
                    key: ingestion.id
                ) else {
                    throw ApplicationWorkflowFixtureError
                        .forcedReadFailure
                }
                camp.name = "camp-post"
                guide.name = "guide-post"
                item.title = "input-camp-post"
                try camp.update(db)
                try guide.update(db)
                try item.update(db)
            }
        }
    )
    #expect(campDuringWrite.camp.name == campBefore.camp.name)
    #expect(campDuringWrite.guide.name == guideBeforeName)
    #expect(
        campDuringWrite.ingestionItems.first(
            where: { $0.id == ingestion.id }
        )?.title == itemBeforeTitle
    )
    let campAfter = try database.readInputCampBundle(
        campId: bootstrap.camp.id
    )
    #expect(campAfter.camp.name == "camp-post")
    #expect(campAfter.guide.name == "guide-post")
    #expect(
        campAfter.ingestionItems.first(
            where: { $0.id == ingestion.id }
        )?.title == "input-camp-post"
    )

    let reviewBeforeResult = applicationInputRuminationResult("review-pre")
    try await database.pool.write { db in
        guard var item = try IngestionItemRecord.fetchOne(
            db,
            key: ingestion.id
        ) else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        let now = Date()
        try RuminationResultRecord(
            id: UUID().uuidString,
            ingestionId: ingestion.id,
            pipelineVersion: RuminationWorkInput.pipelineVersion,
            resultJson: try RuminationCoding.encode(reviewBeforeResult),
            userEditedJson: nil,
            materializedAt: nil,
            createdAt: now,
            updatedAt: now
        ).insert(db)
        item.status = .needsReview
        item.updatedAt = now
        try item.update(db)
    }
    let reviewBefore = try database.readInputReviewBundle(
        ingestionId: ingestion.id
    )
    let reviewAfterResult = applicationInputRuminationResult("review-post")
    let reviewDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readInputReviewBundleForTesting(
                ingestionId: ingestion.id,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                guard var item = try IngestionItemRecord.fetchOne(
                    db,
                    key: ingestion.id
                ), var stored = try RuminationResultRecord
                    .filter(Column("ingestionId") == ingestion.id)
                    .fetchOne(db)
                else {
                    throw ApplicationWorkflowFixtureError
                        .forcedReadFailure
                }
                item.title = "input-review-post"
                stored.resultJson = try RuminationCoding.encode(
                    reviewAfterResult
                )
                stored.userEditedJson = nil
                try item.update(db)
                try stored.update(db)
            }
        }
    )
    #expect(reviewDuringWrite.ingestion.title == reviewBefore.ingestion.title)
    #expect(
        reviewDuringWrite.result.suggestedTitle
            == reviewBefore.result.suggestedTitle
    )
    let reviewAfter = try database.readInputReviewBundle(
        ingestionId: ingestion.id
    )
    #expect(reviewAfter.ingestion.title == "input-review-post")
    #expect(reviewAfter.result.suggestedTitle == "title-review-post")
    #expect(reviewAfter.baseCow?.id == CowTemplate.baseCowId)

    _ = try RuminationMaterializer(db: database).materialize(
        ingestionId: ingestion.id,
        edited: reviewAfterResult
    )
    let candidateId = try await database.pool.read { db in
        try #require(
            try ActionCandidateRecord
                .filter(
                    Column("ingestionId") == ingestion.id
                        && Column("type")
                            == ActionCandidateType.mission.rawValue
                )
                .fetchOne(db)
        ).id
    }
    let candidateBefore = try database
        .readInputMissionDraftBundle(candidateId: candidateId)
    #expect(
        try MissionDraftFactory(db: database).draft(
            candidateId: candidateId
        ) == candidateBefore.draft
    )
    let candidateDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readInputMissionDraftBundleForTesting(
                candidateId: candidateId,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                guard var candidate = try ActionCandidateRecord.fetchOne(
                    db,
                    key: candidateId
                ), var note = try CampNoteRecord.fetchOne(
                    db,
                    key: candidateBefore.sourceNote.id
                ) else {
                    throw ApplicationWorkflowFixtureError
                        .forcedReadFailure
                }
                candidate.detailJson = """
                    {"goal":"goal-candidate-post","why":"why-candidate-post","acceptance":["acceptance-candidate-post"]}
                    """
                note.title = "note-candidate-post"
                try candidate.update(db)
                try note.update(db)
            }
        }
    )
    #expect(candidateDuringWrite.draft.goal == candidateBefore.draft.goal)
    #expect(
        candidateDuringWrite.sourceNote.title
            == candidateBefore.sourceNote.title
    )
    let candidateAfter = try database
        .readInputMissionDraftBundle(candidateId: candidateId)
    #expect(candidateAfter.draft.goal == "goal-candidate-post")
    #expect(candidateAfter.sourceNote.title == "note-candidate-post")
    #expect(candidateAfter.baseCow?.id == CowTemplate.baseCowId)

    let ingestionDuringWrite = try applicationReadWhileWriterCommits(
        read: { hook in
            try database.readInputMissionDraftBundleForTesting(
                ingestionId: ingestion.id,
                afterAnchorRead: hook
            )
        },
        writer: {
            try database.pool.write { db in
                guard var candidate = try ActionCandidateRecord.fetchOne(
                    db,
                    key: candidateId
                ), var note = try CampNoteRecord.fetchOne(
                    db,
                    key: candidateAfter.sourceNote.id
                ) else {
                    throw ApplicationWorkflowFixtureError
                        .forcedReadFailure
                }
                candidate.detailJson = """
                    {"goal":"goal-ingestion-post","why":"why-ingestion-post","acceptance":["acceptance-ingestion-post"]}
                    """
                note.title = "note-ingestion-post"
                try candidate.update(db)
                try note.update(db)
            }
        }
    )
    #expect(ingestionDuringWrite.draft.goal == candidateAfter.draft.goal)
    #expect(
        ingestionDuringWrite.sourceNote.title
            == candidateAfter.sourceNote.title
    )
    let ingestionAfter = try database
        .readInputMissionDraftBundle(ingestionId: ingestion.id)
    #expect(ingestionAfter.draft.goal == "goal-ingestion-post")
    #expect(ingestionAfter.sourceNote.title == "note-ingestion-post")
    #expect(ingestionAfter.baseCow?.id == CowTemplate.baseCowId)

    let candidateConflictDatabase = try applicationCloneDatabase(
        from: database,
        directory: directory,
        label: "duplicate-candidate"
    )
    let originalCandidate = try await candidateConflictDatabase.pool.read { db in
        try #require(
            try ActionCandidateRecord.fetchOne(db, key: candidateId)
        )
    }
    let duplicateCandidate = ActionCandidateRecord(
        id: UUID().uuidString,
        ingestionId: originalCandidate.ingestionId,
        campId: originalCandidate.campId,
        type: .mission,
        title: "duplicate mission",
        detailJson: originalCandidate.detailJson,
        status: .proposed,
        missionId: nil,
        idemKey: UUID().uuidString,
        createdAt: originalCandidate.createdAt.addingTimeInterval(1),
        updatedAt: originalCandidate.updatedAt.addingTimeInterval(1)
    )
    try await candidateConflictDatabase.pool.write { db in
        try duplicateCandidate.insert(db)
    }
    applicationExpectInvalidPayload {
        _ = try candidateConflictDatabase.readInputMissionDraftBundle(
            ingestionId: ingestion.id
        )
    }
    let candidateRowsBeforeDelete = try await candidateConflictDatabase.pool
        .read { db in
            try ActionCandidateRecord
                .filter(Column("ingestionId") == ingestion.id)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    await #expect(throws: DatabaseError.self) {
        try await candidateConflictDatabase.pool.write { db in
            guard try ActionCandidateRecord.deleteOne(
                db,
                key: duplicateCandidate.id
            ) else {
                throw ApplicationWorkflowFixtureError.forcedReadFailure
            }
        }
    }
    let candidateRowsAfterDelete = try await candidateConflictDatabase.pool
        .read { db in
            try ActionCandidateRecord
                .filter(Column("ingestionId") == ingestion.id)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    #expect(candidateRowsAfterDelete == candidateRowsBeforeDelete)

    let linkConflictDatabase = try applicationCloneDatabase(
        from: database,
        directory: directory,
        label: "duplicate-link"
    )
    let originalLink = try await linkConflictDatabase.pool.read { db in
        try #require(
            try KnowledgeSourceLinkRecord
                .filter(Column("ingestionId") == ingestion.id)
                .fetchOne(db)
        )
    }
    let secondNote = CampNoteRecord(
        id: UUID().uuidString,
        campId: bootstrap.camp.id,
        missionId: nil,
        title: "duplicate link note",
        bodyMd: "duplicate link body",
        pinned: false,
        createdAt: Date(),
        updatedAt: Date()
    )
    let secondLink = KnowledgeSourceLinkRecord(
        id: UUID().uuidString,
        campNoteId: secondNote.id,
        ingestionId: ingestion.id,
        locatorJson: nil,
        createdAt: originalLink.createdAt.addingTimeInterval(1)
    )
    try await linkConflictDatabase.pool.write { db in
        try secondNote.insert(db)
        try secondLink.insert(db)
    }
    applicationExpectInvalidPayload {
        _ = try linkConflictDatabase.readInputMissionDraftBundle(
            candidateId: candidateId
        )
    }
    let linkRowsBeforeDelete = try await linkConflictDatabase.pool.read { db in
        try KnowledgeSourceLinkRecord
            .filter(Column("ingestionId") == ingestion.id)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(db)
    }
    await #expect(throws: DatabaseError.self) {
        try await linkConflictDatabase.pool.write { db in
            guard try KnowledgeSourceLinkRecord.deleteOne(
                db,
                key: secondLink.id
            ) else {
                throw ApplicationWorkflowFixtureError.forcedReadFailure
            }
        }
    }
    let linkRowsAfterDelete = try await linkConflictDatabase.pool.read { db in
        try KnowledgeSourceLinkRecord
            .filter(Column("ingestionId") == ingestion.id)
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(db)
    }
    #expect(linkRowsAfterDelete == linkRowsBeforeDelete)

    let missingNoteDatabase = try applicationCloneDatabase(
        from: database,
        directory: directory,
        label: "missing-note"
    )
    let missingNote = ingestionAfter.sourceNote
    try await missingNoteDatabase.pool.writeWithoutTransaction { db in
        try db.execute(sql: "PRAGMA foreign_keys = OFF")
        try db.execute(
            sql: "DELETE FROM camp_note WHERE id = ?",
            arguments: [missingNote.id]
        )
        try db.execute(sql: "PRAGMA foreign_keys = ON")
    }
    applicationExpectNotFound(
        RecordNotFoundError(
            table: CampNoteRecord.databaseTableName,
            id: missingNote.id
        )
    ) {
        _ = try missingNoteDatabase.readInputMissionDraftBundle(
            candidateId: candidateId
        )
    }

    let crossCampDatabase = try applicationCloneDatabase(
        from: database,
        directory: directory,
        label: "cross-camp-note"
    )
    let otherCamp = try crossCampDatabase.createCamp(name: "other camp")
    try await crossCampDatabase.pool.write { db in
        guard var note = try CampNoteRecord.fetchOne(
            db,
            key: ingestionAfter.sourceNote.id
        ) else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        note.campId = otherCamp.id
        try note.update(db)
    }
    applicationExpectNotFound(
        RecordNotFoundError(
            table: CampNoteRecord.databaseTableName,
            id: ingestionAfter.sourceNote.id
        )
    ) {
        _ = try crossCampDatabase.readInputMissionDraftBundle(
            candidateId: candidateId
        )
    }

    let malformedCandidateDatabase = try applicationCloneDatabase(
        from: database,
        directory: directory,
        label: "malformed-candidate"
    )
    try await malformedCandidateDatabase.pool.write { db in
        guard var candidate = try ActionCandidateRecord.fetchOne(
            db,
            key: candidateId
        ) else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        candidate.detailJson = "{"
        try candidate.update(db)
    }
    applicationExpectInvalidPayload {
        _ = try malformedCandidateDatabase.readInputMissionDraftBundle(
            candidateId: candidateId
        )
    }

    let _: ShutdownReport = await orchestrator.shutdown()
    rawDefaults.removePersistentDomain(forName: defaultsName)
}

@MainActor
private func applicationOAuthLifecycleRows() async throws {
    do {
        let codec = ApplicationOAuthCodecHarness()
        let platform = ApplicationOAuthPlatformHarness()
        let fixture = try applicationRuntimeFixture(
            "oauth-callback-failure",
            oauthPlatformFactory: platform.makeFactory(),
            oauthCodec: codec.makeCodec()
        )
        let prepared = try await applicationPrepareOAuth(
            fixture: fixture,
            platform: platform
        )
        let invalidCommand = RuntimeOAuthCallbackCommand.authorization(
            prepared.authorization,
            reservation: prepared.reservation,
            listenerLease: prepared.lease,
            callbackURL: try applicationOAuthCallbackURL(state: "wrong")
        )
        let invalid = await fixture.controller.claimOAuthCallback(
            invalidCommand,
            trace: applicationOAuthTrace(.oauthCallbackExchange)
        )
        guard case .currentAuthorizationRejected = invalid else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }

        let command = RuntimeOAuthCallbackCommand.authorization(
            prepared.authorization,
            reservation: prepared.reservation,
            listenerLease: prepared.lease,
            callbackURL: try applicationOAuthCallbackURL(state: codec.state)
        )
        let claimed = await fixture.controller.claimOAuthCallback(
            command,
            trace: applicationOAuthTrace(.oauthCallbackExchange)
        )
        let claim: RuntimeOAuthCallbackClaim
        switch claimed {
        case .claimed(let value):
            claim = value
        case .currentAuthorizationRejected, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let duplicateClaim = await fixture.controller.claimOAuthCallback(
            command,
            trace: applicationOAuthTrace(.oauthCallbackExchange)
        )
        guard case .superseded = duplicateClaim else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }

        codec.setPayloadMode(.failed)
        let callbackFailure = await fixture.controller.handleOAuthCallback(
            claim
        )
        let pending: RuntimeOAuthAuthorizationRecoveryPending
        switch callbackFailure {
        case .authorizationRecoveryPending(let value, _):
            pending = value
        case .notCommitted, .committed,
             .committedWithVisibilityFailure, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect(pending.ownsAuthorization(prepared.authorization))
        #expect(pending.ownsListenerLease(prepared.lease))

        let recovered = await fixture.controller.retryOAuthAuthorization(
            pending
        )
        guard case .ready(let authorization) = recovered else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect(authorization == prepared.authorization)
        #expect(platform.counts() == (starts: 2, stops: 1, opens: 1))
        let staleRetry = await fixture.controller.retryOAuthAuthorization(
            pending
        )
        guard case .superseded = staleRetry else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect(platform.counts() == (starts: 2, stops: 1, opens: 1))
    }

    do {
        let codec = ApplicationOAuthCodecHarness()
        let platform = ApplicationOAuthPlatformHarness()
        let fixture = try applicationRuntimeFixture(
            "oauth-preopen-callback-failure",
            oauthPlatformFactory: platform.makeFactory(),
            oauthCodec: codec.makeCodec()
        )
        let prepared = try await applicationPrepareOAuth(
            fixture: fixture,
            platform: platform,
            openBrowser: false
        )
        let command = RuntimeOAuthCallbackCommand.authorization(
            prepared.authorization,
            reservation: prepared.reservation,
            listenerLease: prepared.lease,
            callbackURL: try applicationOAuthCallbackURL(state: codec.state)
        )
        let claimed = await fixture.controller.claimOAuthCallback(
            command,
            trace: applicationOAuthTrace(.oauthCallbackExchange)
        )
        let claim: RuntimeOAuthCallbackClaim
        switch claimed {
        case .claimed(let value):
            claim = value
        case .currentAuthorizationRejected, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        codec.setPayloadMode(.failed)
        let failed = await fixture.controller.handleOAuthCallback(claim)
        let pending: RuntimeOAuthAuthorizationRecoveryPending
        switch failed {
        case .authorizationRecoveryPending(let value, _):
            pending = value
        case .notCommitted, .committed,
             .committedWithVisibilityFailure, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let recovered = await fixture.controller.retryOAuthAuthorization(
            pending
        )
        guard case .ready = recovered else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect(platform.counts() == (starts: 2, stops: 1, opens: 1))
    }

    do {
        let codec = ApplicationOAuthCodecHarness()
        let platform = ApplicationOAuthPlatformHarness()
        let fixture = try applicationRuntimeFixture(
            "oauth-preopen-abandon",
            oauthPlatformFactory: platform.makeFactory(),
            oauthCodec: codec.makeCodec()
        )
        let prepared = try await applicationPrepareOAuth(
            fixture: fixture,
            platform: platform,
            openBrowser: false
        )
        let command = RuntimeOAuthCallbackCommand.authorization(
            prepared.authorization,
            reservation: prepared.reservation,
            listenerLease: prepared.lease,
            callbackURL: try applicationOAuthCallbackURL(state: codec.state)
        )
        let claimed = await fixture.controller.claimOAuthCallback(
            command,
            trace: applicationOAuthTrace(.oauthCallbackExchange)
        )
        let claim: RuntimeOAuthCallbackClaim
        switch claimed {
        case .claimed(let value):
            claim = value
        case .currentAuthorizationRejected, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let abandoned = await fixture.controller.abandonOAuthCallbackClaim(
            claim
        )
        let pending: RuntimeOAuthAuthorizationRecoveryPending
        switch abandoned {
        case .authorizationRecovery(let value):
            pending = value
        case .ready, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let recovered = await fixture.controller.retryOAuthAuthorization(
            pending
        )
        guard case .ready = recovered else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect(platform.counts() == (starts: 2, stops: 1, opens: 1))
    }

    do {
        let codec = ApplicationOAuthCodecHarness()
        let platform = ApplicationOAuthPlatformHarness()
        let fixture = try applicationRuntimeFixture(
            "oauth-listener-retry",
            oauthPlatformFactory: platform.makeFactory(),
            oauthCodec: codec.makeCodec()
        )
        let prepared = try await applicationPrepareOAuth(
            fixture: fixture,
            platform: platform
        )
        let sink = try #require(platform.sink())
        let firstFailure = await sink.handle(
            .accept,
            authorization: prepared.authorization,
            lease: prepared.lease
        )
        let firstPending: RuntimeOAuthAuthorizationRecoveryPending
        switch firstFailure {
        case .pending(let value, _):
            firstPending = value
        case .ready, .deferredToCallback, .deferredToPreparation,
             .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let duplicateFirst = await sink.handle(
            .accept,
            authorization: prepared.authorization,
            lease: prepared.lease
        )
        guard case .superseded = duplicateFirst else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }

        platform.failNextStartThroughSink()
        let interruptedRetry = await fixture.controller
            .retryOAuthAuthorization(firstPending)
        guard case .superseded = interruptedRetry else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let secondPending = try #require(
            platform.injectedRecoveryPending()
        )
        let secondStart = try #require(platform.latestStart())
        #expect(secondPending.ownsAuthorization(prepared.authorization))
        #expect(secondPending.ownsListenerLease(secondStart.1))
        #expect(!secondPending.ownsListenerLease(prepared.lease))
        let duplicateSecond = await sink.handle(
            .accept,
            authorization: secondStart.0,
            lease: secondStart.1
        )
        guard case .superseded = duplicateSecond else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let failureCount = try await fixture.database.pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM failure_record"
            ) ?? -1
        }
        #expect(failureCount == 2)

        let recovered = await fixture.controller.retryOAuthAuthorization(
            secondPending
        )
        guard case .ready = recovered else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect(platform.counts() == (starts: 3, stops: 2, opens: 1))
    }

    do {
        let codec = ApplicationOAuthCodecHarness()
        let platform = ApplicationOAuthPlatformHarness()
        let strictReadFailure = ApplicationWorkflowToggle()
        let fixture = try applicationRuntimeFixture(
            "oauth-committed-visibility",
            oauthPlatformFactory: platform.makeFactory(),
            oauthCodec: codec.makeCodec(),
            strictReadFailure: strictReadFailure
        )
        let prepared = try await applicationPrepareOAuth(
            fixture: fixture,
            platform: platform
        )
        let command = RuntimeOAuthCallbackCommand.authorization(
            prepared.authorization,
            reservation: prepared.reservation,
            listenerLease: prepared.lease,
            callbackURL: try applicationOAuthCallbackURL(state: codec.state)
        )
        let claimed = await fixture.controller.claimOAuthCallback(
            command,
            trace: applicationOAuthTrace(.oauthCallbackExchange)
        )
        let claim: RuntimeOAuthCallbackClaim
        switch claimed {
        case .claimed(let value):
            claim = value
        case .currentAuthorizationRejected, .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        strictReadFailure.setEnabled(true)
        let committed = await fixture.controller.handleOAuthCallback(claim)
        switch committed {
        case .committedWithVisibilityFailure(let receipt, _):
            #expect(receipt.flow == .chatGPT)
        case .notCommitted, .authorizationRecoveryPending, .committed,
             .superseded:
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        let oauth = fixture.accounts.oauth
        #expect(fixture.store.storedValue(account: oauth.access) == codec.accessToken)
        #expect(fixture.store.storedValue(account: oauth.refresh) == codec.refreshToken)
        #expect(fixture.store.storedValue(account: oauth.id) == codec.idToken)
        #expect(fixture.store.storedValue(account: oauth.accountID) == codec.accountID)
        let committedSetCounts = [
            fixture.store.setCallCount(account: oauth.access),
            fixture.store.setCallCount(account: oauth.refresh),
            fixture.store.setCallCount(account: oauth.id),
            fixture.store.setCallCount(account: oauth.accountID),
        ]
        #expect(committedSetCounts == [1, 1, 1, 1])

        let duplicate = await fixture.controller.handleOAuthCallback(claim)
        guard case .superseded(.none) = duplicate else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect([
            fixture.store.setCallCount(account: oauth.access),
            fixture.store.setCallCount(account: oauth.refresh),
            fixture.store.setCallCount(account: oauth.id),
            fixture.store.setCallCount(account: oauth.accountID),
        ] == committedSetCounts)

        strictReadFailure.setEnabled(false)
        let refreshed = await fixture.controller.load(
            interactionPolicy: .failIfInteractionRequired,
            trace: try applicationRuntimeTrace(
                operation: .runtimeBootstrap,
                profile: fixture.defaultProfile
            )
        )
        guard case .loaded = refreshed else {
            throw ApplicationWorkflowFixtureError.missingOAuthFixtureState
        }
        #expect([
            fixture.store.setCallCount(account: oauth.access),
            fixture.store.setCallCount(account: oauth.refresh),
            fixture.store.setCallCount(account: oauth.id),
            fixture.store.setCallCount(account: oauth.accountID),
        ] == committedSetCounts)
        #expect(platform.counts() == (starts: 1, stops: 1, opens: 1))
    }
}

private enum ApplicationScheduleAuthorizationStep: Sendable {
    case receipt(ScheduleAuthorizationReceipt)
    case failure
}

private enum ApplicationScheduleRegistrationStep: Sendable {
    case receipt(ScheduleRegistrationReceipt)
    case failure
}

private actor ApplicationScheduleRegistrationBarrier {
    private var callCount = 0
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var entryContinuations: [CheckedContinuation<Void, Never>] = []

    func replaceAll(
        _ registrations: [ScheduleActivityRegistration]
    ) async -> ScheduleRegistrationReceipt {
        _ = registrations
        callCount += 1
        let entries = entryContinuations
        entryContinuations.removeAll()
        for continuation in entries {
            continuation.resume()
        }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return ScheduleRegistrationReceipt(registeredScheduleIds: [])
    }

    func waitUntilEntered() async {
        if callCount > 0 {
            return
        }
        await withCheckedContinuation { continuation in
            entryContinuations.append(continuation)
        }
    }

    func release() {
        let continuation = releaseContinuation
        releaseContinuation = nil
        continuation?.resume()
    }

    func calls() -> Int { callCount }
}

private actor ApplicationScheduleStartSignal {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        started = true
        let continuations = waiters
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

private final class ApplicationSchedulePortProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var authorizationSteps: [ApplicationScheduleAuthorizationStep] = []
    private var registrationSteps: [ApplicationScheduleRegistrationStep] = []
    private var _authorizationCalls = 0
    private var _registrationCalls = 0
    private var _evaluationCalls = 0
    private var _saveTemplateCalls = 0
    private var _saveScheduleCalls = 0
    private var _enableCalls = 0
    private var _deleteTemplateCalls = 0
    private var _deleteScheduleCalls = 0
    private var _fireCalls = 0
    private var _recordMissedCalls = 0
    private var _replayCalls = 0
    private var _wakeCalls = 0
    private var _broadcastFireCalls = 0
    private var _broadcastOutcomeCalls = 0
    private var fireResult: ScheduleFireCommitResult?
    private var missedResult: ScheduleFireCommitResult?
    private var replayResult: ScheduleFireCommitResult?
    private var wakeFailure = false
    private var broadcastFireFailure = false
    private var broadcastOutcomeFailure = false
    private var _fireTraces: [OperationTrace] = []
    private var _missedTraces: [OperationTrace] = []
    private var _replayTraces: [OperationTrace] = []

    func setAuthorizationSteps(
        _ steps: [ApplicationScheduleAuthorizationStep]
    ) {
        lock.lock()
        authorizationSteps = steps
        lock.unlock()
    }

    func setRegistrationSteps(
        _ steps: [ApplicationScheduleRegistrationStep]
    ) {
        lock.lock()
        registrationSteps = steps
        lock.unlock()
    }

    func requestAuthorization() throws -> ScheduleAuthorizationReceipt {
        lock.lock()
        defer { lock.unlock() }
        _authorizationCalls += 1
        guard !authorizationSteps.isEmpty else {
            throw SchedulePlatformFailure.authorization
        }
        switch authorizationSteps.removeFirst() {
        case .receipt(let receipt):
            return receipt
        case .failure:
            throw SchedulePlatformFailure.authorization
        }
    }

    func replaceAll(
        _ registrations: [ScheduleActivityRegistration]
    ) throws -> ScheduleRegistrationReceipt {
        _ = registrations
        lock.lock()
        defer { lock.unlock() }
        _registrationCalls += 1
        guard !registrationSteps.isEmpty else {
            throw SchedulePlatformFailure.registration
        }
        switch registrationSteps.removeFirst() {
        case .receipt(let receipt):
            return receipt
        case .failure:
            throw SchedulePlatformFailure.registration
        }
    }

    func evaluation() -> ScheduleRegistrationEvaluation {
        lock.lock()
        _evaluationCalls += 1
        lock.unlock()
        return ScheduleRegistrationEvaluation(
            now: Date(timeIntervalSince1970: 1_780_000_000),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
    }

    func savedTemplate(_ template: MissionTemplateRecord) {
        _ = template
        lock.lock()
        _saveTemplateCalls += 1
        lock.unlock()
    }

    func savedSchedule(_ schedule: ScheduleRecord) {
        _ = schedule
        lock.lock()
        _saveScheduleCalls += 1
        lock.unlock()
    }

    func enabledSchedule(id: String, enabled: Bool) -> ScheduleRecord {
        lock.lock()
        _enableCalls += 1
        lock.unlock()
        return ApplicationSchedulePortProbe.schedule(
            id: id,
            enabled: enabled
        )
    }

    func deletedTemplate(id: String) -> ScheduleTemplateDeletionReceipt {
        lock.lock()
        _deleteTemplateCalls += 1
        lock.unlock()
        return ScheduleTemplateDeletionReceipt(
            template: Self.template(id: id),
            deletedSchedules: []
        )
    }

    func deletedSchedule(id: String) -> ScheduleDeletionReceipt {
        lock.lock()
        _deleteScheduleCalls += 1
        lock.unlock()
        return ScheduleDeletionReceipt(
            schedule: Self.schedule(id: id, enabled: false)
        )
    }

    func setOperationalResults(
        fire: ScheduleFireCommitResult,
        missed: ScheduleFireCommitResult,
        replay: ScheduleFireCommitResult
    ) {
        lock.lock()
        fireResult = fire
        missedResult = missed
        replayResult = replay
        lock.unlock()
    }

    func setOperationalFailures(
        wake: Bool = false,
        broadcastFire: Bool = false,
        broadcastOutcome: Bool = false
    ) {
        lock.lock()
        wakeFailure = wake
        broadcastFireFailure = broadcastFire
        broadcastOutcomeFailure = broadcastOutcome
        lock.unlock()
    }

    func fire(
        _ request: ScheduleFireRequest,
        trace: OperationTrace
    ) throws -> ScheduleFireCommitResult {
        _ = request
        lock.lock()
        defer { lock.unlock() }
        _fireCalls += 1
        _fireTraces.append(trace)
        guard let fireResult else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        return fireResult
    }

    func recordMissed(
        _ request: ScheduleFireRequest,
        trace: OperationTrace
    ) throws -> ScheduleFireCommitResult {
        _ = request
        lock.lock()
        defer { lock.unlock() }
        _recordMissedCalls += 1
        _missedTraces.append(trace)
        guard let missedResult else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        return missedResult
    }

    func replay(
        _ request: ScheduleReplayRequest,
        trace: OperationTrace
    ) throws -> ScheduleFireCommitResult {
        _ = request
        lock.lock()
        defer { lock.unlock() }
        _replayCalls += 1
        _replayTraces.append(trace)
        guard let replayResult else {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        return replayResult
    }

    func wake(_ result: ScheduleFireCommitResult) throws {
        _ = result
        lock.lock()
        defer { lock.unlock() }
        _wakeCalls += 1
        if wakeFailure {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
    }

    func broadcastFire(
        _ result: ScheduleFireCommitResult
    ) throws -> ScheduleBroadcastReceipt? {
        lock.lock()
        defer { lock.unlock() }
        _broadcastFireCalls += 1
        if broadcastFireFailure {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        guard result.disposition == .inserted else { return nil }
        return ScheduleBroadcastReceipt(
            effectKey: "schedule-fire:\(result.fire.id):broadcast:v1",
            campId: "fixture-camp",
            messageId: "fixture-fire-message"
        )
    }

    func broadcastOutcome(
        _ plan: ScheduledMissionOutcomePlan
    ) throws -> ScheduleBroadcastReceipt? {
        lock.lock()
        defer { lock.unlock() }
        _broadcastOutcomeCalls += 1
        if broadcastOutcomeFailure {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
        guard let campId = plan.broadcastCampId else { return nil }
        return ScheduleBroadcastReceipt(
            effectKey: plan.effectKey,
            campId: campId,
            messageId: "fixture-outcome-message"
        )
    }

    func operationalObservations() -> (
        fire: Int,
        missed: Int,
        replay: Int,
        wake: Int,
        broadcastFire: Int,
        broadcastOutcome: Int,
        fireTraces: [OperationTrace],
        missedTraces: [OperationTrace],
        replayTraces: [OperationTrace]
    ) {
        lock.lock()
        defer { lock.unlock() }
        return (
            _fireCalls,
            _recordMissedCalls,
            _replayCalls,
            _wakeCalls,
            _broadcastFireCalls,
            _broadcastOutcomeCalls,
            _fireTraces,
            _missedTraces,
            _replayTraces
        )
    }

    func counts() -> (
        authorization: Int,
        registration: Int,
        evaluation: Int,
        saveTemplate: Int,
        saveSchedule: Int,
        enable: Int,
        deleteTemplate: Int,
        deleteSchedule: Int
    ) {
        lock.lock()
        defer { lock.unlock() }
        return (
            _authorizationCalls,
            _registrationCalls,
            _evaluationCalls,
            _saveTemplateCalls,
            _saveScheduleCalls,
            _enableCalls,
            _deleteTemplateCalls,
            _deleteScheduleCalls
        )
    }

    static func template(id: String) -> MissionTemplateRecord {
        MissionTemplateRecord(
            id: id,
            name: "Fixture Template",
            goal: "Exercise schedule repair",
            companionIdsJson: "[\"fixture-companion\"]",
            workspacePath: nil,
            budgetTokens: 1_000,
            autonomy: .standard,
            campId: "fixture-camp",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    static func schedule(id: String, enabled: Bool) -> ScheduleRecord {
        ScheduleRecord(
            id: id,
            templateId: "fixture-template",
            frequency: .daily,
            hour: 9,
            minute: 0,
            weekday: nil,
            enabled: enabled,
            lastFiredAt: nil,
            createdAt: Date(timeIntervalSince1970: 2)
        )
    }
}

@MainActor
private func applicationScheduleControllerFixture(
    probe: ApplicationSchedulePortProbe
) throws -> (controller: MissionWorkflowController, database: AppDatabase) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "application-schedule-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
    let reporter = FailureReporter(database: database)
    let orchestrator = Orchestrator(
        db: database,
        planningProviderResolver: TestPlanningProviderResolver(
            provider: MockProvider(script: [])
        ),
        makeProvider: { _, _ in MockProvider(script: []) },
        artifactStoreRoot: directory.appendingPathComponent("artifacts"),
        tickInterval: nil,
        failureReporter: reporter
    )
    let planningCoordinator = PlanningEntryCoordinator(
        db: database,
        orchestrator: orchestrator
    )
    let emptyPresentation = SchedulePresentationSnapshot(
        enabled: [],
        requestedTemplate: nil
    )
    let ports = MissionWorkflowPorts(
        retryCard: { _ in },
        returnForRework: { _, _ in },
        addBudget: { _, _ in },
        clearReview: { _ in },
        setAutonomy: { _, _ in },
        dismissProposal: { _ in },
        ensureReport: { _ in directory.appendingPathComponent("report.md") },
        loadSchedules: { campId in
            ScheduleWorkflowSnapshot(
                campId: campId,
                templates: [],
                schedules: []
            )
        },
        loadSchedulePresentation: { _, _, _ in emptyPresentation },
        saveTemplate: { probe.savedTemplate($0) },
        deleteTemplate: { probe.deletedTemplate(id: $0) },
        saveSchedule: { probe.savedSchedule($0) },
        setScheduleEnabled: {
            probe.enabledSchedule(id: $0, enabled: $1)
        },
        deleteSchedule: { probe.deletedSchedule(id: $0) },
        fire: { try probe.fire($0, trace: $1) },
        recordMissed: { try probe.recordMissed($0, trace: $1) },
        replay: { try probe.replay($0, trace: $1) },
        wake: { try probe.wake($0) },
        broadcastFire: { try probe.broadcastFire($0) },
        broadcastOutcome: { try probe.broadcastOutcome($0) }
    )
    let controller = MissionWorkflowController(
        database: database,
        orchestrator: orchestrator,
        planningCoordinator: planningCoordinator,
        reportStoreRoot: directory.appendingPathComponent("reports"),
        selectRuntime: {
            PlanningEntryRuntimeSelection(
                runtimeProfileId: "fixture-runtime",
                plannerModel: "fixture-model"
            )
        },
        reporter: reporter,
        traceFactory: OperationTraceFactory(
            makeID: { UUID() },
            now: { Date(timeIntervalSince1970: 1_780_000_000) }
        ),
        registrationEvaluation: { probe.evaluation() },
        ports: ports
    )
    return (controller, database)
}

private func applicationScheduleRepair(
    from decision: SchedulePostCommitApplicationDecision
) throws -> SchedulePostCommitRepairReceipt {
    let program = decision.fold(
        apply: { Optional($0) },
        mutationSuperseded: { nil },
        alreadyConsumed: { nil }
    )
    for operation in try #require(program).operations {
        if case .installRepair(_, let repair, _) = operation {
            return repair
        }
    }
    throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
}

@MainActor
private func applicationSchedulePostCommitRows() async throws {
    let probe = ApplicationSchedulePortProbe()
    let fixture = try applicationScheduleControllerFixture(probe: probe)
    let controller = fixture.controller
    let traceFactory = OperationTraceFactory(
        makeID: { UUID() },
        now: { Date(timeIntervalSince1970: 1_780_000_000) }
    )
    let registration = ScheduleRegistrationPort { registrations in
        try probe.replaceAll(registrations)
    }
    let notifications = ScheduleNotificationPort(
        requestAuthorization: { try probe.requestAuthorization() },
        submit: { request in
            ScheduleNotificationReceipt(
                notificationId: request.notificationId,
                disposition: .submitted
            )
        }
    )

    probe.setRegistrationSteps([
        .receipt(ScheduleRegistrationReceipt(registeredScheduleIds: [])),
    ])
    let template = ApplicationSchedulePortProbe.template(
        id: "fixture-template-success"
    )
    let templateTrace = traceFactory.generated(
        operation: .scheduleTemplateSave,
        scope: .fixed(.scheduleIndex)
    )
    let templateOutcome = await controller.saveTemplate(
        template,
        registration: registration,
        trace: templateTrace
    )
    guard case .committed(let committed) = templateOutcome else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let templateDecision = controller.consumeSchedulePostCommitApplication(
        committed.application
    )
    let projectedTemplate = templateDecision.fold(
        apply: { program in
            program.operations.contains {
                if case .project(.templateSaved(let saved)) = $0 {
                    return saved == template
                }
                return false
            }
        },
        mutationSuperseded: { false },
        alreadyConsumed: { false }
    )
    #expect(projectedTemplate)

    let enabledSchedule = ApplicationSchedulePortProbe.schedule(
        id: "fixture-enabled",
        enabled: true
    )
    probe.setAuthorizationSteps([.failure])
    let enabledTrace = traceFactory.generated(
        operation: .scheduleSave,
        scope: .fixed(.scheduleIndex)
    )
    let initialFailure = await controller.saveSchedule(
        enabledSchedule,
        registration: registration,
        notifications: notifications,
        trace: enabledTrace
    )
    guard case .committedWithVisibilityFailure(let failedTerminal)
        = initialFailure
    else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let initialDecision = controller.consumeSchedulePostCommitApplication(
        failedTerminal.application
    )
    let authorizationRepair = try applicationScheduleRepair(
        from: initialDecision
    )
    let mutationCountsBeforeRetry = probe.counts()

    probe.setAuthorizationSteps([
        .receipt(ScheduleAuthorizationReceipt(disposition: .granted)),
    ])
    probe.setRegistrationSteps([.failure])
    let transitionedOutcome = await controller.retrySchedulePostCommit(
        authorizationRepair,
        registration: registration,
        notifications: notifications
    )
    guard case .stillPending(let pendingTerminal) = transitionedOutcome else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let transitionedDecision = controller.consumeSchedulePostCommitApplication(
        pendingTerminal.application
    )
    let registrationRepair = try applicationScheduleRepair(
        from: transitionedDecision
    )
    #expect(registrationRepair.isSameRepairOwner(as: authorizationRepair))
    let afterTransitionCounts = probe.counts()
    #expect(afterTransitionCounts.authorization == 2)
    #expect(afterTransitionCounts.registration == 2)
    #expect(afterTransitionCounts.evaluation == 2)
    #expect(
        afterTransitionCounts.saveSchedule
            == mutationCountsBeforeRetry.saveSchedule
    )

    probe.setRegistrationSteps([
        .receipt(ScheduleRegistrationReceipt(registeredScheduleIds: [])),
    ])
    let repairedOutcome = await controller.retrySchedulePostCommit(
        registrationRepair,
        registration: registration,
        notifications: notifications
    )
    guard case .repaired(let repairedTerminal) = repairedOutcome else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let repairedDecision = controller.consumeSchedulePostCommitApplication(
        repairedTerminal.application
    )
    #expect(repairedDecision.fold(
        apply: { program in
            program.operations.contains {
                if case .clearRepair(let cleared) = $0 {
                    return cleared.isSameRepairOwner(as: registrationRepair)
                }
                return false
            }
        },
        mutationSuperseded: { false },
        alreadyConsumed: { false }
    ))
    let afterRepairCounts = probe.counts()
    #expect(afterRepairCounts.authorization == 2)
    #expect(afterRepairCounts.registration == 3)
    #expect(afterRepairCounts.evaluation == 3)
    #expect(
        afterRepairCounts.saveSchedule
            == mutationCountsBeforeRetry.saveSchedule
    )

    let staleSchedule = ApplicationSchedulePortProbe.schedule(
        id: "fixture-stale",
        enabled: false
    )
    probe.setRegistrationSteps([.failure])
    let staleInitial = await controller.saveSchedule(
        staleSchedule,
        registration: registration,
        notifications: notifications,
        trace: traceFactory.generated(
            operation: .scheduleSave,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .committedWithVisibilityFailure(let staleTerminal)
        = staleInitial
    else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let staleRepair = try applicationScheduleRepair(
        from: controller.consumeSchedulePostCommitApplication(
            staleTerminal.application
        )
    )
    probe.setRegistrationSteps([
        .receipt(ScheduleRegistrationReceipt(registeredScheduleIds: [])),
    ])
    let successor = await controller.saveSchedule(
        staleSchedule,
        registration: registration,
        notifications: notifications,
        trace: traceFactory.generated(
            operation: .scheduleSave,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .committed(let successorTerminal) = successor else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    _ = controller.consumeSchedulePostCommitApplication(
        successorTerminal.application
    )
    let beforeStaleRetry = probe.counts()
    #expect(await controller.retrySchedulePostCommit(
        staleRepair,
        registration: registration,
        notifications: notifications
    ) == .superseded)
    let afterStaleRetry = probe.counts()
    #expect(afterStaleRetry.authorization == beforeStaleRetry.authorization)
    #expect(afterStaleRetry.registration == beforeStaleRetry.registration)
    #expect(afterStaleRetry.evaluation == beforeStaleRetry.evaluation)
    #expect(afterStaleRetry.saveSchedule == beforeStaleRetry.saveSchedule)

    let globalSchedule = ApplicationSchedulePortProbe.schedule(
        id: "fixture-global",
        enabled: false
    )
    probe.setRegistrationSteps([.failure])
    let globalInitial = await controller.saveSchedule(
        globalSchedule,
        registration: registration,
        notifications: notifications,
        trace: traceFactory.generated(
            operation: .scheduleSave,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .committedWithVisibilityFailure(let globalTerminal)
        = globalInitial
    else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let globalRepair = try applicationScheduleRepair(
        from: controller.consumeSchedulePostCommitApplication(
            globalTerminal.application
        )
    )
    probe.setRegistrationSteps([
        .receipt(ScheduleRegistrationReceipt(registeredScheduleIds: [])),
    ])
    let refreshed = await controller.refreshSchedules(
        registration: registration,
        trace: traceFactory.generated(
            operation: .scheduleRefresh,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .refreshed(_, let globallyCleared) = refreshed else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    #expect(globallyCleared.count == 1)
    #expect(
        globallyCleared.first?.isSameRepairOwner(as: globalRepair) == true
    )
    let beforeGlobalStaleRetry = probe.counts()
    let globalStaleRetry = await controller.retrySchedulePostCommit(
        globalRepair,
        registration: registration,
        notifications: notifications
    )
    #expect(globalStaleRetry == .superseded)
    let afterGlobalStaleRetry = probe.counts()
    #expect(
        afterGlobalStaleRetry.authorization
            == beforeGlobalStaleRetry.authorization
    )
    #expect(
        afterGlobalStaleRetry.registration
            == beforeGlobalStaleRetry.registration
    )
    #expect(
        afterGlobalStaleRetry.evaluation
            == beforeGlobalStaleRetry.evaluation
    )

    let duplicateSchedule = ApplicationSchedulePortProbe.schedule(
        id: "fixture-duplicate",
        enabled: false
    )
    probe.setRegistrationSteps([.failure])
    let duplicateInitial = await controller.saveSchedule(
        duplicateSchedule,
        registration: registration,
        notifications: notifications,
        trace: traceFactory.generated(
            operation: .scheduleSave,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .committedWithVisibilityFailure(let duplicateTerminal)
        = duplicateInitial
    else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let duplicateRepair = try applicationScheduleRepair(
        from: controller.consumeSchedulePostCommitApplication(
            duplicateTerminal.application
        )
    )
    let duplicateBarrier = ApplicationScheduleRegistrationBarrier()
    let suspendingRegistration = ScheduleRegistrationPort { registrations in
        await duplicateBarrier.replaceAll(registrations)
    }
    let mutationCountsBeforeDuplicate = probe.counts()
    let firstDuplicate = Task { @MainActor in
        await controller.retrySchedulePostCommit(
            duplicateRepair,
            registration: suspendingRegistration,
            notifications: notifications
        )
    }
    await duplicateBarrier.waitUntilEntered()
    let secondStarted = ApplicationScheduleStartSignal()
    let secondDuplicate = Task { @MainActor in
        await secondStarted.markStarted()
        return await controller.retrySchedulePostCommit(
            duplicateRepair,
            registration: suspendingRegistration,
            notifications: notifications
        )
    }
    await secondStarted.waitUntilStarted()
    await Task.yield()
    await duplicateBarrier.release()
    let firstDuplicateOutcome = await firstDuplicate.value
    let secondDuplicateOutcome = await secondDuplicate.value
    #expect(firstDuplicateOutcome == secondDuplicateOutcome)
    #expect(await duplicateBarrier.calls() == 1)
    guard case .repaired(let duplicateRepairedTerminal)
        = firstDuplicateOutcome
    else {
        throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
    }
    let firstDuplicateDecision = controller
        .consumeSchedulePostCommitApplication(
            duplicateRepairedTerminal.application
        )
    #expect(firstDuplicateDecision.fold(
        apply: { _ in true },
        mutationSuperseded: { false },
        alreadyConsumed: { false }
    ))
    let secondDuplicateDecision = controller
        .consumeSchedulePostCommitApplication(
            duplicateRepairedTerminal.application
        )
    #expect(secondDuplicateDecision.fold(
        apply: { _ in false },
        mutationSuperseded: { false },
        alreadyConsumed: { true }
    ))
    let mutationCountsAfterDuplicate = probe.counts()
    #expect(
        mutationCountsAfterDuplicate.saveSchedule
            == mutationCountsBeforeDuplicate.saveSchedule
    )

    for (index, disposition) in [
        ScheduleAuthorizationDisposition.unavailable,
        .alreadyRequested,
        .granted,
        .denied,
    ].enumerated() {
        probe.setAuthorizationSteps([
            .receipt(ScheduleAuthorizationReceipt(
                disposition: disposition
            )),
        ])
        probe.setRegistrationSteps([
            .receipt(ScheduleRegistrationReceipt(
                registeredScheduleIds: ["authorization-\(index)"]
            )),
        ])
        let schedule = ApplicationSchedulePortProbe.schedule(
            id: "authorization-\(index)",
            enabled: true
        )
        let outcome = await controller.saveSchedule(
            schedule,
            registration: registration,
            notifications: notifications,
            trace: traceFactory.generated(
                operation: .scheduleSave,
                scope: .fixed(.scheduleIndex)
            )
        )
        guard case .committed(let terminal) = outcome else {
            throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
        }
        let decision = controller.consumeSchedulePostCommitApplication(
            terminal.application
        )
        #expect(decision.fold(
            apply: { program in
                program.operations.contains {
                    if case .authorizationEvidence(let receipt) = $0 {
                        return receipt.disposition == disposition
                    }
                    return false
                }
            },
            mutationSuperseded: { false },
            alreadyConsumed: { false }
        ))
    }
}

private func applicationScheduleFireResult(
    id: String,
    scheduleId: String,
    templateId: String,
    context: ScheduleSlotContextV1,
    trace: OperationTrace,
    disposition: ScheduleFireDisposition,
    state: ScheduleFireState,
    missionId: String?,
    replayOfFireId: String? = nil,
    errorCode: String? = nil,
    errorMessage: String? = nil
) -> ScheduleFireCommitResult {
    ScheduleFireCommitResult(
        fire: ScheduleFireRecord(
            id: id,
            scheduleId: scheduleId,
            templateId: templateId,
            slotKey: context.slotKey,
            scheduledAt: context.scheduledAt,
            replayOfFireId: replayOfFireId,
            replayIdempotencyKey: replayOfFireId.map {
                "schedule-replay:\($0):v1"
            },
            replayPayloadHash: replayOfFireId.map { _ in
                String(repeating: "a", count: 64)
            },
            state: state,
            missionId: missionId,
            traceId: trace.traceId,
            errorCode: errorCode,
            errorMessage: errorMessage,
            createdAt: context.scheduledAt,
            redactedAt: nil
        ),
        disposition: disposition,
        missionId: missionId,
        workId: state == .started ? "work-\(id)" : nil
    )
}

@MainActor
private func applicationScheduleOperationalRows() async throws {
    let probe = ApplicationSchedulePortProbe()
    let fixture = try applicationScheduleControllerFixture(probe: probe)
    let controller = fixture.controller
    let database = fixture.database
    let bootstrap = try ProductBootstrapService(db: database)
        .ensureBootstrap()
    let baseCow = try #require(bootstrap.baseCow)
    let template = MissionTemplateRecord(
        id: "application-operational-template",
        name: "运行期定时行动",
        goal: "验证运行期端口隔离",
        companionIdsJson: try MissionTemplateRecord.companionIdsJSON([
            baseCow.id,
        ]),
        workspacePath: nil,
        budgetTokens: 1_000,
        autonomy: .standard,
        campId: bootstrap.camp.id,
        createdAt: Date(timeIntervalSince1970: 1_779_800_000)
    )
    try database.saveMissionTemplate(template)
    let schedule = ScheduleRecord(
        id: "application-operational-schedule",
        templateId: template.id,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        enabled: true,
        lastFiredAt: nil,
        createdAt: Date(timeIntervalSince1970: 1_779_800_001)
    )
    try database.saveSchedule(schedule)

    let now = Date(timeIntervalSince1970: 1_780_000_000)
    let timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let traceFactory = OperationTraceFactory(
        makeID: { UUID() },
        now: { now }
    )
    let initialMissed = await controller.loadStartupMissedFires(
        now: now,
        timeZone: timeZone,
        trace: traceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .loaded(let initialRequests) = initialMissed,
          let missedRequest = initialRequests.first,
          initialRequests.count == 1
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-initial-missed-load"
        )
    }
    #expect(missedRequest.scheduleId == schedule.id)
    try await database.pool.write { db in
        try db.execute(
            sql: """
                INSERT INTO schedule_evaluation_cursor(
                  scheduleId, lastEvaluatedSlotKey,
                  lastEvaluatedScheduledAt, version, updatedAt
                ) VALUES (?, ?, ?, ?, ?)
                """,
            arguments: [
                schedule.id,
                missedRequest.context.slotKey,
                missedRequest.context.scheduledAt.timeIntervalSince1970,
                1,
                now.timeIntervalSince1970,
            ]
        )
    }
    let caughtUp = await controller.loadStartupMissedFires(
        now: now,
        timeZone: timeZone,
        trace: traceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .loaded(let caughtUpRequests) = caughtUp else {
        if case .failed(let failure) = caughtUp {
            throw ApplicationWorkflowFixtureError.scheduleStage(
                "operational-cursor-suppression-load: \(failure.message)"
            )
        }
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-cursor-suppression-load"
        )
    }
    #expect(caughtUpRequests.isEmpty)

    let runNow = await controller.prepareRunNow(
        scheduleId: schedule.id,
        now: now,
        timeZone: timeZone,
        trace: traceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .loaded(let runNowRequest) = runNow else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-run-now-load"
        )
    }
    #expect(runNowRequest.scheduleId == schedule.id)

    let fireTrace = traceFactory.generated(
        operation: .scheduleFire,
        scope: .fixed(.scheduleIndex)
    )
    let missedTrace = traceFactory.generated(
        operation: .scheduleFire,
        scope: .fixed(.scheduleIndex)
    )
    let replayTrace = traceFactory.generated(
        operation: .scheduleReplay,
        scope: .fixed(.scheduleIndex)
    )
    let fireResult = applicationScheduleFireResult(
        id: "application-fire",
        scheduleId: schedule.id,
        templateId: template.id,
        context: runNowRequest.context,
        trace: fireTrace,
        disposition: .inserted,
        state: .started,
        missionId: "application-fire-mission"
    )
    let missedResult = applicationScheduleFireResult(
        id: "application-missed",
        scheduleId: schedule.id,
        templateId: template.id,
        context: missedRequest.context,
        trace: missedTrace,
        disposition: .inserted,
        state: .failed,
        missionId: nil,
        errorCode: "schedule_missed_while_offline",
        errorMessage: "定时行动在应用离线期间错过了触发时间。"
    )
    let replayResult = applicationScheduleFireResult(
        id: "application-replay",
        scheduleId: schedule.id,
        templateId: template.id,
        context: missedRequest.context,
        trace: replayTrace,
        disposition: .replayed,
        state: .started,
        missionId: "application-replay-mission",
        replayOfFireId: missedResult.fire.id
    )
    probe.setOperationalResults(
        fire: fireResult,
        missed: missedResult,
        replay: replayResult
    )

    guard case .committed(let committedFire) = await controller.fireSchedule(
        runNowRequest,
        trace: fireTrace
    ) else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-fire-terminal"
        )
    }
    #expect(committedFire == fireResult)
    guard case .committed(let committedMissed) = await controller
        .recordMissedSchedule(missedRequest, trace: missedTrace)
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-missed-terminal"
        )
    }
    #expect(committedMissed == missedResult)
    guard case .committed(let committedReplay) = await controller
        .replaySchedule(
            ScheduleReplayRequest(originalFireId: missedResult.fire.id),
            trace: replayTrace
        )
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-replay-terminal"
        )
    }
    #expect(committedReplay == replayResult)
    var observations = probe.operationalObservations()
    #expect(observations.fire == 1)
    #expect(observations.missed == 1)
    #expect(observations.replay == 1)
    #expect(observations.fireTraces == [fireTrace])
    #expect(observations.missedTraces == [missedTrace])
    #expect(observations.replayTraces == [replayTrace])

    probe.setOperationalFailures(wake: true, broadcastFire: true)
    let wakeTrace = traceFactory.generated(
        operation: .scheduleWake,
        scope: .fixed(.scheduleIndex)
    )
    guard case .committedWithVisibilityFailure(
        let wakeValue,
        let wakeFailure
    ) = await controller.publishScheduleWake(fireResult, trace: wakeTrace)
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-wake-terminal"
        )
    }
    #expect(wakeValue == fireResult)
    #expect(wakeFailure.traceId == wakeTrace.traceId)
    let broadcastTrace = traceFactory.generated(
        operation: .scheduleBroadcast,
        scope: .fixed(.scheduleIndex)
    )
    guard case .committedWithVisibilityFailure(
        let broadcastValue,
        let broadcastFailure
    ) = await controller.publishScheduleBroadcast(
        fireResult,
        trace: broadcastTrace
    ) else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-fire-broadcast-terminal"
        )
    }
    #expect(broadcastValue == fireResult)
    #expect(broadcastFailure.traceId == broadcastTrace.traceId)
    observations = probe.operationalObservations()
    #expect(observations.fire == 1)
    #expect(observations.missed == 1)
    #expect(observations.replay == 1)
    #expect(observations.wake == 1)
    #expect(observations.broadcastFire == 1)

    for disposition in [
        ScheduleAuthorizationDisposition.unavailable,
        .alreadyRequested,
        .granted,
        .denied,
    ] {
        let notifications = ScheduleNotificationPort(
            requestAuthorization: {
                ScheduleAuthorizationReceipt(disposition: disposition)
            },
            submit: { request in
                ScheduleNotificationReceipt(
                    notificationId: request.notificationId,
                    disposition: .submitted
                )
            }
        )
        let trace = traceFactory.generated(
            operation: .scheduleNotification,
            scope: .fixed(.notification)
        )
        guard case .committed(let receipt) = await controller
            .requestScheduleAuthorization(
                notifications: notifications,
                trace: trace
            )
        else {
            throw ApplicationWorkflowFixtureError.scheduleStage(
                "operational-notification-terminal"
            )
        }
        #expect(receipt.disposition == disposition)
    }

    let notificationRequest = ScheduleNotificationRequest(
        notificationId: "application-notification",
        missionId: "application-outcome-mission",
        title: "定时行动完成",
        body: "请查看结果",
        kind: .closeout
    )
    for disposition in [
        ScheduleNotificationDisposition.unavailable,
        .notAuthorized,
        .submitted,
    ] {
        let notifications = ScheduleNotificationPort(
            requestAuthorization: {
                ScheduleAuthorizationReceipt(disposition: .granted)
            },
            submit: { request in
                ScheduleNotificationReceipt(
                    notificationId: request.notificationId,
                    disposition: disposition
                )
            }
        )
        let trace = traceFactory.generated(
            operation: .scheduleNotification,
            scope: .fixed(.notification)
        )
        guard case .committed(let receipt) = await controller
            .submitScheduleNotification(
                notificationRequest,
                notifications: notifications,
                trace: trace
            )
        else {
            throw ApplicationWorkflowFixtureError
                .missingScheduleFixtureState
        }
        #expect(receipt.notificationId == notificationRequest.notificationId)
        #expect(receipt.disposition == disposition)
    }
    let throwingNotifications = ScheduleNotificationPort(
        requestAuthorization: {
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        },
        submit: { _ in
            throw ApplicationWorkflowFixtureError.forcedReadFailure
        }
    )
    let authorizationFailureTrace = traceFactory.generated(
        operation: .scheduleNotification,
        scope: .fixed(.notification)
    )
    guard case .notCommitted(let authorizationFailure) = await controller
        .requestScheduleAuthorization(
            notifications: throwingNotifications,
            trace: authorizationFailureTrace
        )
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-authorization-failure-terminal"
        )
    }
    #expect(authorizationFailure.traceId == authorizationFailureTrace.traceId)
    let submissionFailureTrace = traceFactory.generated(
        operation: .scheduleNotification,
        scope: .fixed(.notification)
    )
    guard case .notCommitted(let submissionFailure) = await controller
        .submitScheduleNotification(
            notificationRequest,
            notifications: throwingNotifications,
            trace: submissionFailureTrace
        )
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-submission-failure-terminal"
        )
    }
    #expect(submissionFailure.traceId == submissionFailureTrace.traceId)

    let missionIds = try database.createSingleCardMission(
        campName: bootstrap.camp.name,
        squadName: "application-outcome-squad",
        goal: "application-outcome",
        cardTitle: "application-outcome-card",
        cardDescription: "application-outcome-card",
        expectedOutput: "application-outcome-output",
        assigneeId: baseCow.id,
        maxTurns: 2,
        campId: bootstrap.camp.id
    )
    try await database.pool.write { db in
        guard var mission = try MissionRecord.fetchOne(
            db,
            key: missionIds.missionId
        ) else {
            throw ApplicationWorkflowFixtureError.missingScheduleFixtureState
        }
        mission.status = .accepted
        try mission.update(db)
        try AppDatabase.appendEvent(
            db,
            missionId: mission.id,
            cardId: nil,
            runId: nil,
            kind: EventKind.scheduleFired,
            payload: [
                "scheduleId": .string(schedule.id),
                "templateId": .string(template.id),
            ]
        )
        try AppDatabase.appendEvent(
            db,
            missionId: mission.id,
            cardId: nil,
            runId: nil,
            kind: EventKind.missionBudgetExhausted,
            payload: ["source": .string("application-test")]
        )
    }
    let outcomePlans = await controller.loadScheduledMissionOutcomePlans(
        missionId: missionIds.missionId,
        trace: traceFactory.generated(
            operation: .scheduleLoad,
            scope: .fixed(.scheduleIndex)
        )
    )
    guard case .loaded(let plans) = outcomePlans else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-outcome-plan-load"
        )
    }
    #expect(plans.map(\.notification.kind) == [.budgetExhausted, .closeout])
    #expect(plans.allSatisfy { $0.missionId == missionIds.missionId })
    #expect(plans.allSatisfy { $0.broadcastCampId == bootstrap.camp.id })

    probe.setOperationalFailures()
    for plan in plans {
        guard case .committed(let publishedPlan) = await controller
            .publishScheduledMissionOutcomeBroadcast(
                plan,
                trace: traceFactory.generated(
                    operation: .scheduleBroadcast,
                    scope: .fixed(.scheduleIndex)
                )
            )
        else {
            throw ApplicationWorkflowFixtureError.scheduleStage(
                "operational-outcome-broadcast-terminal"
            )
        }
        #expect(publishedPlan == plan)
    }
    probe.setOperationalFailures(broadcastOutcome: true)
    let failedPlan = try #require(plans.first)
    let outcomeBroadcastTrace = traceFactory.generated(
        operation: .scheduleBroadcast,
        scope: .fixed(.scheduleIndex)
    )
    guard case .notCommitted(let outcomeBroadcastFailure) = await controller
        .publishScheduledMissionOutcomeBroadcast(
            failedPlan,
            trace: outcomeBroadcastTrace
        )
    else {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational-outcome-broadcast-failure-terminal"
        )
    }
    #expect(outcomeBroadcastFailure.traceId == outcomeBroadcastTrace.traceId)
    observations = probe.operationalObservations()
    #expect(observations.broadcastOutcome == plans.count + 1)
}

@MainActor
@Test func committedVisibilityFailureCannotRepeatMutation() async throws {
    let companionA = CompanionNoteRecord(
        id: "memory-a",
        companionId: "companion-a",
        sourceThreadId: "thread-a",
        title: "A",
        bodyMd: "A body",
        pinned: false,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
    let companionB1 = CompanionNoteRecord(
        id: "memory-b-1",
        companionId: "companion-b",
        sourceThreadId: "thread-b",
        title: "B1",
        bodyMd: "B1 body",
        pinned: false,
        createdAt: Date(timeIntervalSince1970: 2),
        updatedAt: Date(timeIntervalSince1970: 2)
    )
    let companionB2 = CompanionNoteRecord(
        id: "memory-b-2",
        companionId: "companion-b",
        sourceThreadId: "thread-b",
        title: "B2",
        bodyMd: "B2 body",
        pinned: false,
        createdAt: Date(timeIntervalSince1970: 3),
        updatedAt: Date(timeIntervalSince1970: 3)
    )
    let guide1 = CampNoteRecord(
        id: "guide-1",
        campId: "camp-a",
        missionId: nil,
        title: "G1",
        bodyMd: "G1 body",
        pinned: false,
        createdAt: Date(timeIntervalSince1970: 4),
        updatedAt: Date(timeIntervalSince1970: 4)
    )
    let guide2 = CampNoteRecord(
        id: "guide-2",
        campId: "camp-a",
        missionId: nil,
        title: "G2",
        bodyMd: "G2 body",
        pinned: false,
        createdAt: Date(timeIntervalSince1970: 5),
        updatedAt: Date(timeIntervalSince1970: 5)
    )
    let failure1 = try applicationWorkflowFailure("one")
    let failure2 = try applicationWorkflowFailure("two")

    var projection = MemoryKnowledgeProjectionCoordinator()

    let loadA = projection.selectCompanion("companion-a")
    let appliedA = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.loaded([companionA]),
        for: loadA
    )
    #expect(appliedA)
    #expect(projection.visibleMemoryNotes.map(\.id) == ["memory-a"])

    let staleB = projection.selectCompanion("companion-b")
    let currentB = projection.beginCompanionRefresh(
        companionId: "companion-b"
    )
    let staleApplied = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.loaded([companionB1]),
        for: staleB
    )
    #expect(!staleApplied)
    let failedB = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.failed(failure1),
        for: currentB
    )
    #expect(failedB)
    #expect(projection.visibleMemoryNotes.isEmpty)
    if case .failed(let failure) = projection.visibleMemoryState {
        #expect(failure.traceId == failure1.traceId)
    } else {
        Issue.record("companion B read failure was not projected")
    }

    let returnToA = projection.selectCompanion("companion-a")
    let returnedToA = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.loaded([companionA]),
        for: returnToA
    )
    #expect(returnedToA)
    let hiddenB = projection.beginCompanionRefresh(
        companionId: "companion-b"
    )
    let loadedHiddenB = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.loaded([companionB1]),
        for: hiddenB
    )
    #expect(loadedHiddenB)
    #expect(projection.visibleMemoryNotes.map(\.id) == ["memory-a"])

    _ = projection.selectCompanion("companion-b")
    let committedB1 = projection.beginCommittedRefresh(companionB1)
    let failedCommittedB1 = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.failed(failure1),
        for: committedB1
    )
    #expect(failedCommittedB1)
    let firstCard = try #require(projection.visibilityCards.first)
    #expect(firstCard.ownerKind == .companion)
    #expect(firstCard.committedRecordIds == ["memory-b-1"])

    let committedB2 = projection.beginCommittedRefresh(companionB2)
    let failedCommittedB2 = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.failed(failure2),
        for: committedB2
    )
    #expect(failedCommittedB2)
    let secondCard = try #require(projection.visibilityCards.first)
    #expect(secondCard.id == firstCard.id)
    #expect(secondCard.failure.traceId == failure2.traceId)
    #expect(secondCard.committedRecordCount == 2)
    #expect(secondCard.committedRecordIds == ["memory-b-1", "memory-b-2"])

    let unknownRetry = projection.beginVisibilityRetry(cardId: UUID())
    #expect(unknownRetry == nil)
    let retryBOptional = projection.beginVisibilityRetry(
        cardId: secondCard.id
    )
    let retryB = try #require(retryBOptional)
    let failedRetryB = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.failed(failure1),
        for: retryB
    )
    #expect(failedRetryB)
    let retriedCard = try #require(projection.visibilityCards.first)
    #expect(retriedCard.id == secondCard.id)
    #expect(retriedCard.failure.traceId == failure1.traceId)
    #expect(retriedCard.committedRecordIds == ["memory-b-1", "memory-b-2"])

    let retrySuccessOptional = projection.beginVisibilityRetry(
        cardId: retriedCard.id
    )
    let retrySuccess = try #require(retrySuccessOptional)
    let appliedRetrySuccess = projection.apply(
        WorkflowReadTerminal<[CompanionNoteRecord]>.loaded(
            [companionB1, companionB2]
        ),
        for: retrySuccess
    )
    #expect(appliedRetrySuccess)
    #expect(projection.visibilityCards.isEmpty)

    let committedGuide1 = projection.beginCommittedRefresh(guide1)
    let failedGuide1 = projection.apply(
        WorkflowReadTerminal<[CampNoteRecord]>.failed(failure1),
        for: committedGuide1
    )
    #expect(failedGuide1)
    let committedGuide2 = projection.beginCommittedRefresh(guide2)
    let failedGuide2 = projection.apply(
        WorkflowReadTerminal<[CampNoteRecord]>.failed(failure2),
        for: committedGuide2
    )
    #expect(failedGuide2)
    let guideCard = try #require(projection.visibilityCards.first)
    #expect(guideCard.ownerKind == .guide)
    #expect(guideCard.id == projection.visibilityCards.first?.id)
    #expect(guideCard.committedRecordIds == ["guide-1", "guide-2"])

    let guideRetryOptional = projection.beginVisibilityRetry(
        cardId: guideCard.id
    )
    let guideRetry = try #require(guideRetryOptional)
    let appliedGuideRetry = projection.apply(
        WorkflowReadTerminal<[CampNoteRecord]>.loaded([guide1, guide2]),
        for: guideRetry
    )
    #expect(appliedGuideRetry)
    #expect(projection.visibilityCards.isEmpty)

    try await applicationOAuthLifecycleRows()
    do {
        try await applicationSchedulePostCommitRows()
    } catch {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "post-commit: \(error)"
        )
    }
    do {
        try await applicationScheduleOperationalRows()
    } catch {
        throw ApplicationWorkflowFixtureError.scheduleStage(
            "operational: \(error)"
        )
    }
}

private struct CodingRanchBootstrapSnapshot: Equatable {
    let camps: Data
    let companions: Data
    let provisioningEvents: Data
}

private enum CodingRanchBootstrapFault: CaseIterable {
    case guideInsert
    case guideUpdate
    case baseCowInsert
    case provisioningEventInsert

    var triggerName: String {
        switch self {
        case .guideInsert:
            return "application_workflow_abort_guide_insert"
        case .guideUpdate:
            return "application_workflow_abort_guide_update"
        case .baseCowInsert:
            return "application_workflow_abort_base_cow_insert"
        case .provisioningEventInsert:
            return "application_workflow_abort_provisioning_event_insert"
        }
    }

    var triggerSQL: String {
        switch self {
        case .guideInsert:
            return """
                CREATE TRIGGER \(triggerName)
                BEFORE INSERT ON companion
                WHEN NEW.kind = 'guide'
                BEGIN
                  SELECT RAISE(ABORT, 'forced guide insert failure');
                END
                """
        case .guideUpdate:
            return """
                CREATE TRIGGER \(triggerName)
                BEFORE UPDATE ON companion
                WHEN OLD.kind = 'guide' AND OLD.name = '向导'
                BEGIN
                  SELECT RAISE(ABORT, 'forced guide update failure');
                END
                """
        case .baseCowInsert:
            return """
                CREATE TRIGGER \(triggerName)
                BEFORE INSERT ON companion
                WHEN NEW.id = '\(CowTemplate.baseCowId)'
                BEGIN
                  SELECT RAISE(ABORT, 'forced base cow insert failure');
                END
                """
        case .provisioningEventInsert:
            return """
                CREATE TRIGGER \(triggerName)
                BEFORE INSERT ON event
                WHEN NEW.kind = '\(EventKind.baseCowProvisioned)'
                BEGIN
                  SELECT RAISE(ABORT, 'forced provisioning event failure');
                END
                """
        }
    }
}

private func codingRanchBootstrapTestDatabase(
    label: String
) throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "coding-ranch-bootstrap-\(label)-\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return try AppDatabase(
        path: directory.appendingPathComponent("test.sqlite").path
    )
}

private func codingRanchBootstrapSnapshot(
    _ database: AppDatabase
) throws -> CodingRanchBootstrapSnapshot {
    try database.pool.read { db in
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let camps = try CampRecord
            .order(Column("createdAt"), Column("id"))
            .fetchAll(db)
        let companions = try CompanionRecord
            .order(Column("createdAt"), Column("id"))
            .fetchAll(db)
        let events = try EventRecord
            .filter(Column("kind") == EventKind.baseCowProvisioned)
            .order(Column("createdAt"), Column("id"))
            .fetchAll(db)
        return CodingRanchBootstrapSnapshot(
            camps: try encoder.encode(camps),
            companions: try encoder.encode(companions),
            provisioningEvents: try encoder.encode(events)
        )
    }
}

@MainActor
@Test func codingRanchBootstrapIsAtomicAcrossEveryWriteBoundary() throws {
    for fault in CodingRanchBootstrapFault.allCases {
        let database = try codingRanchBootstrapTestDatabase(
            label: fault.triggerName
        )
        if fault == .guideUpdate {
            _ = try database.ensureDefaultCamp()
        }
        let before = try codingRanchBootstrapSnapshot(database)
        try database.pool.write { db in
            try db.execute(sql: fault.triggerSQL)
        }

        let reporter = FailureReporter(database: database)
        let boundary = ApplicationPostDatabaseBootstrapBoundary(
            reporter: reporter
        )
        let service = ProductBootstrapService(db: database)
        let trace = OperationTraceFactory.live.generated(
            operation: .applicationBootstrap,
            scope: .fixed(.application)
        )
        let failed = boundary.ensureCodingRanchBootstrap(trace: trace) {
            try service.ensureBootstrap()
        }
        switch failed {
        case .notCommitted(let failure):
            #expect(failure.traceId == trace.traceId)
            #expect(failure.operation == .applicationBootstrap)
            #expect(failure.scope.type == .application)
            #expect(failure.scope.id == "application")
        case .committed, .committedWithVisibilityFailure:
            Issue.record("\(fault) unexpectedly committed")
        }
        #expect(try codingRanchBootstrapSnapshot(database) == before)

        try database.pool.write { db in
            try db.execute(sql: "DROP TRIGGER \(fault.triggerName)")
            let remaining = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM sqlite_master
                    WHERE type = 'trigger' AND name = ?
                    """,
                arguments: [fault.triggerName]
            )
            #expect(remaining == 0)
        }

        let retryTrace = OperationTraceFactory.live.generated(
            operation: .applicationBootstrap,
            scope: .fixed(.application)
        )
        let retried = boundary.ensureCodingRanchBootstrap(
            trace: retryTrace
        ) {
            try service.ensureBootstrap()
        }
        let result: CodingRanchBootstrapResult
        switch retried {
        case .committed(let value):
            result = value
        case .notCommitted, .committedWithVisibilityFailure:
            Issue.record("\(fault) retry did not commit")
            continue
        }
        #expect(result.camp.id.isEmpty == false)
        #expect(result.baseCow?.id == CowTemplate.baseCowId)

        let postconditions = try database.pool.read { db in
            let camps = try CampRecord.fetchAll(db)
            let guides = try CompanionRecord
                .filter(Column("kind") == CompanionRecord.Kind.guide.rawValue)
                .fetchAll(db)
            let baseCows = try CompanionRecord
                .filter(Column("id") == CowTemplate.baseCowId)
                .fetchAll(db)
            let events = try EventRecord
                .filter(Column("kind") == EventKind.baseCowProvisioned)
                .fetchAll(db)
            return (camps, guides, baseCows, events)
        }
        #expect(postconditions.0.count == 1)
        #expect(postconditions.1.count == 1)
        #expect(postconditions.1.first?.name == "营地管家")
        #expect(postconditions.2.count == 1)
        #expect(postconditions.3.count == 1)
    }

    var profile = RuntimeProfileRecord.new(
        kind: .anthropicAPI,
        name: "Test Runtime"
    )
    profile.isDefault = true
    let gateCamp = CampRecord(
        id: "gate-camp",
        name: "Gate Camp",
        createdAt: Date(timeIntervalSince1970: 1)
    )
    let runtimeSnapshot = RuntimeWorkflowSnapshot(
        profiles: [profile],
        defaultProfile: profile,
        companions: [],
        camps: [gateCamp],
        credentials: RuntimeCredentialPresence(
            apiKeyPresent: false,
            searchKeyPresent: false,
            oauthAccessTokenPresent: false,
            chatGPTAccountIdPresent: false
        ),
        legacyRuminationSnapshot: .legacyModelUnavailable
    )
    let ranchResult = CodingRanchBootstrapResult(
        camp: gateCamp,
        baseCow: nil,
        newcomerMode: false
    )
    let gateFailure = try applicationWorkflowFailure("startup-gate")

    var bothLoaded = ApplicationStartupGate(
        runtime: .loaded(runtimeSnapshot),
        codingRanch: .loaded(ranchResult)
    )
    #expect(bothLoaded.claimStartIfReady() == .startNow)
    #expect(bothLoaded.claimStartIfReady() == .alreadyStarted)

    var runtimeFirst = ApplicationStartupGate(
        runtime: .loaded(runtimeSnapshot),
        codingRanch: .failed(gateFailure)
    )
    #expect(runtimeFirst.claimStartIfReady() == .waitingForOther)
    #expect(
        runtimeFirst.acceptCodingRanchLoaded(ranchResult) == .startNow
    )
    #expect(
        runtimeFirst.acceptRuntimeLoaded(runtimeSnapshot) == .alreadyStarted
    )

    var ranchFirst = ApplicationStartupGate(
        runtime: .failed(gateFailure),
        codingRanch: .loaded(ranchResult)
    )
    #expect(ranchFirst.claimStartIfReady() == .waitingForOther)
    #expect(
        ranchFirst.acceptRuntimeLoaded(runtimeSnapshot) == .startNow
    )
    #expect(
        ranchFirst.acceptCodingRanchLoaded(ranchResult) == .alreadyStarted
    )

    var runtimeThenRanch = ApplicationStartupGate(
        runtime: .failed(gateFailure),
        codingRanch: .failed(gateFailure)
    )
    #expect(
        runtimeThenRanch.acceptRuntimeLoaded(runtimeSnapshot)
            == .waitingForOther
    )
    #expect(
        runtimeThenRanch.acceptCodingRanchLoaded(ranchResult) == .startNow
    )

    var ranchThenRuntime = ApplicationStartupGate(
        runtime: .failed(gateFailure),
        codingRanch: .failed(gateFailure)
    )
    #expect(
        ranchThenRuntime.acceptCodingRanchLoaded(ranchResult)
            == .waitingForOther
    )
    #expect(
        ranchThenRuntime.acceptRuntimeLoaded(runtimeSnapshot) == .startNow
    )
}
