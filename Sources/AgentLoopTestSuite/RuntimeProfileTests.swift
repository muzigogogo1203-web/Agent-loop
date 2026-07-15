import Testing
import Foundation
import GRDB
import AgentLoopCore

private func runtimeProfileTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("runtime-profile.sqlite").path)
}

private func runtimeProfileDefaults() -> UserDefaults {
    let name = "runtime-profile-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func runtimeCompanion(model: String = "model-a", profileId: String? = nil) -> CompanionRecord {
    var companion = CompanionRecord.new(name: "测试牛", color: "blue", rolePrompt: "r", model: model)
    companion.runtimeProfileId = profileId
    return companion
}

@Test func runtimeProfileMigrationV10ReplaysFromV9AndPreservesCompanions() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: directory.appendingPathComponent("v9.sqlite").path)
    let migrator = AppDatabase.migrator
    #expect(migrator.migrations.contains("v10-runtime-profiles"))

    try migrator.migrate(pool, upTo: "v9-evercamp")
    #expect(try pool.read { try !$0.tableExists("runtime_profile") })
    try pool.write { db in
        try db.execute(sql: """
            INSERT INTO camp(id, name, createdAt) VALUES ('camp-a', 'Camp', CURRENT_TIMESTAMP)
            """)
        try db.execute(sql: """
            INSERT INTO companion(
                id, name, color, rolePrompt, model, toolsJson, kind, campId, createdAt
            ) VALUES (
                'cow-a', 'Cow', 'blue', 'r', 'model-old', '[]', 'regular', 'camp-a', CURRENT_TIMESTAMP
            )
            """)
    }

    try migrator.migrate(pool)
    try migrator.migrate(pool)

    let companion = try pool.read { db in
        try #require(try CompanionRecord.fetchOne(db, key: "cow-a"))
    }
    #expect(companion.runtimeProfileId == nil)
    #expect(companion.modelPolicy == .pinned)
    #expect(try pool.read { try $0.tableExists("runtime_profile") })
    let indexes = try pool.read { db in
        try String.fetchAll(db, sql: "SELECT name FROM pragma_index_list('runtime_profile')")
    }
    #expect(indexes.contains("runtime_profile_one_default"))
}

@Test func runtimeProfileMigrationV11AllowsCliKindsAndPreservesExistingRows() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: directory.appendingPathComponent("v10.sqlite").path)
    let migrator = AppDatabase.migrator
    #expect(migrator.migrations.contains("v11-cli-kinds"))

    try migrator.migrate(pool, upTo: "v10-runtime-profiles")
    try pool.write { db in
        try db.execute(sql: """
            INSERT INTO camp(id, name, createdAt) VALUES ('camp-a', 'Camp', CURRENT_TIMESTAMP)
            """)
        try db.execute(sql: """
            INSERT INTO runtime_profile(
                id, kind, name, baseURL, credentialAccount, isDefault, createdAt
            ) VALUES (
                'profile-a', 'anthropic_api', 'API', 'https://api.anthropic.com', 'api-key', 1, CURRENT_TIMESTAMP
            )
            """)
        try db.execute(sql: """
            INSERT INTO companion(
                id, name, color, rolePrompt, model, toolsJson, kind, campId, createdAt,
                runtimeProfileId, modelPolicy
            ) VALUES (
                'cow-a', 'Cow', 'blue', 'r', 'model-old', '[]', 'regular', 'camp-a', CURRENT_TIMESTAMP,
                'profile-a', 'pinned'
            )
            """)
    }

    try migrator.migrate(pool)
    try migrator.migrate(pool)

    try pool.write { db in
        try db.execute(sql: """
            INSERT INTO runtime_profile(
                id, kind, name, baseURL, credentialAccount, isDefault, createdAt
            ) VALUES (
                'cli-codex', 'cli_codex', 'Codex CLI', NULL, NULL, 0, CURRENT_TIMESTAMP
            )
            """)
        try db.execute(sql: """
            INSERT INTO runtime_profile(
                id, kind, name, baseURL, credentialAccount, isDefault, createdAt
            ) VALUES (
                'cli-claude', 'cli_claude', 'Claude CLI', NULL, NULL, 0, CURRENT_TIMESTAMP
            )
            """)
    }

    let kinds = try pool.read { db in
        try String.fetchAll(db, sql: "SELECT kind FROM runtime_profile ORDER BY id")
    }
    #expect(kinds == ["cli_claude", "cli_codex", "anthropic_api"])
    let companionProfileId = try pool.read { db in
        try String.fetchOne(db, sql: "SELECT runtimeProfileId FROM companion WHERE id = 'cow-a'")
    }
    #expect(companionProfileId == "profile-a")
    #expect(throws: DatabaseError.self) {
        try pool.write { db in
            try db.execute(sql: """
                INSERT INTO runtime_profile(
                    id, kind, name, baseURL, credentialAccount, isDefault, createdAt
                ) VALUES (
                    'bad', 'not_allowed', 'Bad', NULL, NULL, 0, CURRENT_TIMESTAMP
                )
                """)
        }
    }
}

@Test func runtimeProfileBootstrapSeedsAPIOnly() throws {
    let db = try runtimeProfileTempDB()
    let defaults = ProfileScopedDefaults(defaults: runtimeProfileDefaults())
    let seeded = try RuntimeProfileBootstrap(db: db, defaults: defaults).ensureSeeded(
        inputs: .init(
            apiKeyPresent: true,
            apiFormat: .anthropicMessages,
            apiBaseURL: "https://api.anthropic.com/v1",
            oauthTokenPresent: false,
            preferredSource: .apiKey
        ),
        fallbackModelChoices: ["claude-a"]
    )
    let profile = try #require(seeded)
    #expect(profile.kind == .anthropicAPI)
    #expect(profile.credentialAccount == RuntimeProfileBootstrap.apiKeyCredentialAccount)
    #expect(profile.isDefault)
    #expect(profile.baseURL == "https://api.anthropic.com")
    #expect(try db.runtimeProfiles().count == 1)
}

@Test func runtimeProfileBootstrapSeedsOAuthOnly() throws {
    let db = try runtimeProfileTempDB()
    let seeded = try RuntimeProfileBootstrap(db: db).ensureSeeded(
        inputs: .init(
            apiKeyPresent: false,
            apiFormat: .anthropicMessages,
            apiBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
            oauthTokenPresent: true,
            preferredSource: .webLogin
        ),
        fallbackModelChoices: ["gpt-5.5"]
    )
    let profile = try #require(seeded)
    #expect(profile.kind == .chatGPTOAuth)
    #expect(profile.credentialAccount == RuntimeProfileBootstrap.oauthAccessTokenCredentialAccount)
    #expect(profile.isDefault)
}

@Test func runtimeProfileBootstrapSeedsBothAndHonorsPreferredSource() throws {
    let db = try runtimeProfileTempDB()
    _ = try RuntimeProfileBootstrap(db: db).ensureSeeded(
        inputs: .init(
            apiKeyPresent: true,
            apiFormat: .openAIChatCompletions,
            apiBaseURL: "https://api.openai.com",
            oauthTokenPresent: true,
            preferredSource: .webLogin
        ),
        fallbackModelChoices: ["gpt-5.5"]
    )
    let profiles = try db.runtimeProfiles()
    #expect(profiles.map(\.kind) == [.openAIAPI, .chatGPTOAuth])
    #expect(try db.defaultProfile()?.kind == .chatGPTOAuth)
}

@Test func runtimeProfileBootstrapSeedsEmptyAnthropicProfileWhenNoCredentials() throws {
    let db = try runtimeProfileTempDB()
    let profile = try #require(try RuntimeProfileBootstrap(db: db).ensureSeeded(
        inputs: .init(
            apiKeyPresent: false,
            apiFormat: .anthropicMessages,
            apiBaseURL: "",
            oauthTokenPresent: false,
            preferredSource: .apiKey
        ),
        fallbackModelChoices: ["claude-a"]
    ))
    #expect(profile.kind == .anthropicAPI)
    #expect(profile.credentialAccount == nil)
    #expect(profile.isDefault)
}

@Test func runtimeProfileBootstrapIsIdempotentAndCopiesLegacyDefaultsOnce() throws {
    let db = try runtimeProfileTempDB()
    let rawDefaults = runtimeProfileDefaults()
    rawDefaults.set("legacy-default", forKey: "defaultModel")
    rawDefaults.set("legacy-distill", forKey: "distillModel")
    rawDefaults.set("legacy-planner", forKey: "plannerModel")
    rawDefaults.set(["legacy-default", "legacy-extra"], forKey: "modelChoices")
    let defaults = ProfileScopedDefaults(defaults: rawDefaults)
    let bootstrap = RuntimeProfileBootstrap(db: db, defaults: defaults)
    let first = try #require(try bootstrap.ensureSeeded(
        inputs: .init(
            apiKeyPresent: true,
            apiFormat: .anthropicMessages,
            apiBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
            oauthTokenPresent: false,
            preferredSource: .apiKey
        ),
        fallbackModelChoices: ["fallback"]
    ))
    rawDefaults.set("changed", forKey: "defaultModel")
    let second = try #require(try bootstrap.ensureSeeded(
        inputs: .init(
            apiKeyPresent: true,
            apiFormat: .anthropicMessages,
            apiBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
            oauthTokenPresent: false,
            preferredSource: .apiKey
        ),
        fallbackModelChoices: ["fallback"]
    ))

    #expect(first.id == second.id)
    #expect(try db.runtimeProfiles().count == 1)
    #expect(defaults.defaultModel(profileID: first.id, fallback: "fallback") == "legacy-default")
    #expect(defaults.distillModel(profileID: first.id) == "legacy-distill")
    #expect(defaults.plannerModel(profileID: first.id) == "legacy-planner")
    #expect(defaults.modelChoices(profileID: first.id, fallback: []) == ["legacy-default", "legacy-extra"])
}

@Test func runtimeProfileStoreSetDefaultMaintainsSingleDefault() throws {
    let db = try runtimeProfileTempDB()
    let a = RuntimeProfileRecord.new(
        kind: .anthropicAPI,
        name: "A",
        baseURL: "https://api.anthropic.com",
        credentialAccount: "a",
        isDefault: true
    )
    let b = RuntimeProfileRecord.new(
        kind: .chatGPTOAuth,
        name: "B",
        baseURL: nil,
        credentialAccount: "b"
    )
    try db.saveRuntimeProfile(a)
    try db.saveRuntimeProfile(b)
    try db.setDefaultProfile(id: b.id)

    let profiles = try db.runtimeProfiles()
    #expect(profiles.filter(\.isDefault).map(\.id) == [b.id])
    #expect(try db.defaultProfile()?.id == b.id)
}

@Test func runtimeProfileStoreDeleteGuardsDefaultAndReferencedProfiles() throws {
    let db = try runtimeProfileTempDB()
    let defaultProfile = RuntimeProfileRecord.new(
        kind: .anthropicAPI,
        name: "Default",
        baseURL: "https://api.anthropic.com",
        credentialAccount: "a",
        isDefault: true
    )
    let referenced = RuntimeProfileRecord.new(
        kind: .chatGPTOAuth,
        name: "OAuth",
        baseURL: nil,
        credentialAccount: "oauth"
    )
    try db.saveRuntimeProfile(defaultProfile)
    try db.saveRuntimeProfile(referenced)
    var companion = runtimeCompanion(profileId: referenced.id)
    try db.saveCompanion(companion)

    #expect(throws: RuntimeProfileStoreError.self) {
        try db.deleteRuntimeProfile(id: defaultProfile.id)
    }
    #expect(throws: RuntimeProfileStoreError.self) {
        try db.deleteRuntimeProfile(id: referenced.id)
    }
    companion.runtimeProfileId = nil
    try db.saveCompanion(companion)
    try db.deleteRuntimeProfile(id: referenced.id)
    #expect(try db.runtimeProfile(id: referenced.id) == nil)
}

@Test func reconciliationReportsPinnedModelsOutsideTrustedCatalog() throws {
    let db = try runtimeProfileTempDB()
    let rawDefaults = runtimeProfileDefaults()
    let defaults = ProfileScopedDefaults(defaults: rawDefaults)
    let profile = RuntimeProfileRecord.new(
        kind: .chatGPTOAuth,
        name: "ChatGPT 登录",
        baseURL: nil,
        credentialAccount: "oauth",
        isDefault: true
    )
    try db.saveRuntimeProfile(profile)
    try db.saveCompanion(runtimeCompanion(model: "glm-5.2"))
    defaults.setString("gpt-5.5", profileID: profile.id, suffix: "defaultModel")
    defaults.setString("bad-distill", profileID: profile.id, suffix: "distillModel")

    let report = try db.reconciliationReport(switchingTo: profile.id, defaults: defaults)
    #expect(report.map(\.model).sorted() == ["bad-distill", "glm-5.2"])
}

@Test func reconciliationReturnsEmptyForGatewayProfiles() throws {
    let db = try runtimeProfileTempDB()
    let defaults = ProfileScopedDefaults(defaults: runtimeProfileDefaults())
    let profile = RuntimeProfileRecord.new(
        kind: .openAIAPI,
        name: "Gateway",
        baseURL: "https://gateway.example.com",
        credentialAccount: "api",
        isDefault: true
    )
    try db.saveRuntimeProfile(profile)
    try db.saveCompanion(runtimeCompanion(model: "custom-gateway-model"))
    defaults.setCachedCatalog(["other"], fetchedAt: Date(), profileID: profile.id)

    #expect(try db.reconciliationReport(switchingTo: profile.id, defaults: defaults).isEmpty)
}

@Test func reconciliationSkipsModelJudgementForCliProfiles() throws {
    let db = try runtimeProfileTempDB()
    let defaults = ProfileScopedDefaults(defaults: runtimeProfileDefaults())
    let profile = RuntimeProfileRecord.new(
        kind: .cliCodex,
        name: "Codex CLI",
        baseURL: nil,
        credentialAccount: nil,
        isDefault: true
    )
    try db.saveRuntimeProfile(profile)
    try db.saveCompanion(runtimeCompanion(model: "glm-5.2", profileId: profile.id))
    defaults.setString("bad-default", profileID: profile.id, suffix: "defaultModel")
    defaults.setString("bad-distill", profileID: profile.id, suffix: "distillModel")
    defaults.setString("bad-planner", profileID: profile.id, suffix: "plannerModel")

    #expect(try db.reconciliationReport(switchingTo: profile.id, defaults: defaults).isEmpty)
}

@Suite(.serialized) struct RuntimeProfileCatalogTests {
    @Test func catalogRefreshParsesModelsAndCachesForOfficialProfiles() async throws {
        let defaults = ProfileScopedDefaults(defaults: runtimeProfileDefaults())
        let profile = RuntimeProfileRecord.new(
            kind: .openAIAPI,
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            credentialAccount: "api",
            isDefault: true
        )
        ModelCatalogStubProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/models")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer key")
            return (200, Data(#"{"data":[{"id":"gpt-5.5"},{"id":"gpt-4.1"}]}"#.utf8))
        }
        let service = ModelCatalogService(
            session: Self.stubbedSession(),
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let refreshed = try await service.refresh(profile: profile, credential: "key")
        #expect(refreshed == ["gpt-5.5", "gpt-4.1"])
        #expect(await service.catalog(profile: profile) == ["gpt-5.5", "gpt-4.1"])
    }

    @Test func catalogRefreshFailureKeepsPreviousCache() async throws {
        let defaults = ProfileScopedDefaults(defaults: runtimeProfileDefaults())
        let profile = RuntimeProfileRecord.new(
            kind: .anthropicAPI,
            name: "Anthropic",
            baseURL: "https://api.anthropic.com",
            credentialAccount: "api",
            isDefault: true
        )
        let service = ModelCatalogService(session: Self.stubbedSession(), defaults: defaults)
        ModelCatalogStubProtocol.handler = { _ in
            (200, Data(#"{"data":[{"id":"claude-sonnet-4-6"}]}"#.utf8))
        }
        _ = try await service.refresh(profile: profile, credential: "key")
        ModelCatalogStubProtocol.handler = { _ in
            (503, Data("down".utf8))
        }
        await #expect(throws: ProviderError.self) {
            try await service.refresh(profile: profile, credential: "key")
        }
        #expect(await service.catalog(profile: profile) == ["claude-sonnet-4-6"])
    }

    @Test func cliProfilesUseStaticPlaceholderCatalog() async throws {
        let defaults = ProfileScopedDefaults(defaults: runtimeProfileDefaults())
        let codex = RuntimeProfileRecord.new(kind: .cliCodex, name: "Codex CLI")
        let claude = RuntimeProfileRecord.new(kind: .cliClaude, name: "Claude CLI")
        let oauth = RuntimeProfileRecord.new(kind: .chatGPTOAuth, name: "ChatGPT")
        let service = ModelCatalogService(session: Self.stubbedSession(), defaults: defaults)

        #expect(try await service.refresh(profile: codex, credential: "") == ["cli-default"])
        #expect(await service.catalog(profile: claude) == ["cli-default"])
        #expect(await service.catalog(profile: oauth) == ["gpt-5.5"])
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModelCatalogStubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class ModelCatalogStubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.handler!(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class RuntimeProviderCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [(model: String, companionId: String?)] = []

    func record(model: String, companionId: String?) {
        lock.withLock { calls.append((model, companionId)) }
    }

    var snapshot: [(model: String, companionId: String?)] {
        lock.withLock { calls }
    }
}

@Test func orchestratorPassesCompanionIdToProviderFactory() async throws {
    let db = try runtimeProfileTempDB()
    let companion = runtimeCompanion(model: "model-a")
    try db.saveCompanion(companion)
    let ids = try db.createSingleCardMission(
        campName: "Camp",
        squadName: "Squad",
        goal: "g",
        cardTitle: "card",
        cardDescription: "d",
        expectedOutput: "o",
        assigneeId: companion.id,
        maxTurns: 2
    )
    let recorder = RuntimeProviderCallRecorder()
    let orch = Orchestrator(
        db: db,
        makeProvider: { model, companionId in
            recorder.record(model: model, companionId: companionId)
            return MockProvider(script: [TurnResult(
                content: [.toolUse(id: "t1", name: "complete_card", input: [
                    "outcome": .string("done"),
                    "summary": .string("ok"),
                    "artifacts": .array([]),
                    "risks": .array([]),
                ])],
                stopReason: .toolUse
            )])
        },
        artifactStoreRoot: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
        tickInterval: nil
    )

    await orch.reconcile()
    for _ in 0..<20 {
        if try db.card(id: ids.cardId)?.status == .done {
            break
        }
        try await Task.sleep(for: .milliseconds(50))
    }

    #expect(recorder.snapshot.contains { $0.model == "model-a" && $0.companionId == companion.id })
}
