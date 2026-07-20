import Testing
import Foundation
import AgentLoopCore

private func catalogDefaults() -> UserDefaults {
    let name = "model-catalog-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func catalogProfile(_ kind: RuntimeProfileKind, id: String = "p", baseURL: String? = nil) -> RuntimeProfileRecord {
    RuntimeProfileRecord(id: id, kind: kind, name: id, baseURL: baseURL,
                         credentialAccount: nil, isDefault: true, createdAt: Date())
}

private func policyTempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("model-catalog.sqlite").path)
}

private func policyCompanion(model: String) -> CompanionRecord {
    CompanionRecord.new(name: "测试牛", color: "blue", rolePrompt: "r", model: model)
}

@Test func modelCatalogManualEntryPolicyMatrix() {
    #expect(RuntimeProfileKind.anthropicAPI.allowsManualModelEntry)
    #expect(RuntimeProfileKind.openAIAPI.allowsManualModelEntry)
    #expect(!RuntimeProfileKind.chatGPTOAuth.allowsManualModelEntry)
    #expect(!RuntimeProfileKind.cliCodex.allowsManualModelEntry)
    #expect(!RuntimeProfileKind.cliClaude.allowsManualModelEntry)
    #expect(!KernelDefaults.chatGPTStaticModels.isEmpty)
    #expect(!KernelDefaults.cliStaticModels.isEmpty)
}

@Test func resolvedCatalogUsesTheCorrectSourceWithoutWrites() {
    let raw = catalogDefaults()
    let defaults = ProfileScopedDefaults(defaults: raw)

    // 网关(非官方 host):scoped + manual,cached 不得混入
    let gateway = catalogProfile(.openAIAPI, id: "gateway", baseURL: "https://gateway.example.com")
    defaults.setStringArray(["scoped"], profileID: gateway.id, suffix: "modelChoices")
    defaults.setManualModels(["manual"], profileID: gateway.id)
    defaults.setCachedCatalog(["cached"], fetchedAt: Date(), profileID: gateway.id)
    let before = raw.dictionaryRepresentation()
    #expect(ModelCatalogService.resolvedCatalog(profile: gateway, defaults: defaults, fallback: ["fallback"]) == ["scoped", "manual"])
    #expect(raw.dictionaryRepresentation() as NSDictionary == before as NSDictionary)

    // 官方 API:cached + manual
    let official = catalogProfile(.openAIAPI, id: "official", baseURL: "https://api.openai.com")
    defaults.setCachedCatalog(["srv-a"], fetchedAt: Date(), profileID: official.id)
    defaults.setManualModels(["manual"], profileID: official.id)
    #expect(ModelCatalogService.resolvedCatalog(profile: official, defaults: defaults, fallback: ["fallback"]) == ["srv-a", "manual"])

    // 受控静态目录
    #expect(ModelCatalogService.resolvedCatalog(profile: catalogProfile(.chatGPTOAuth), defaults: defaults, fallback: ["fallback"]) == KernelDefaults.chatGPTStaticModels)
    #expect(ModelCatalogService.resolvedCatalog(profile: catalogProfile(.cliCodex), defaults: defaults, fallback: ["fallback"]) == KernelDefaults.cliStaticModels)

    // 全空 → fallback
    let empty = catalogProfile(.anthropicAPI, id: "empty", baseURL: "https://gw2.example.com")
    #expect(ModelCatalogService.resolvedCatalog(profile: empty, defaults: defaults, fallback: ["fallback"]) == ["fallback"])
}

@Test func clampModelSelectionsHasUnifiedRules() {
    let defaults = ProfileScopedDefaults(defaults: catalogDefaults())
    defaults.setString("bad", profileID: "p", suffix: "defaultModel")
    defaults.setString("bad2", profileID: "p", suffix: "distillModel")
    defaults.setString("ok", profileID: "p", suffix: "plannerModel")
    #expect(defaults.clampModelSelections(profileID: "p", catalog: ["first", "ok"]))
    #expect(defaults.defaultModel(profileID: "p", fallback: "x") == "first")
    #expect(defaults.distillModel(profileID: "p").isEmpty)
    #expect(defaults.plannerModel(profileID: "p") == "ok")
    #expect(!defaults.clampModelSelections(profileID: "p", catalog: ["first", "ok"]))
    #expect(!defaults.clampModelSelections(profileID: "p", catalog: []))
}

@Test func applyReconciliationFlipsOnlyListedCompanionsAndResetsScopes() throws {
    let db = try policyTempDB()
    let defaults = ProfileScopedDefaults(defaults: catalogDefaults())
    let profile = RuntimeProfileRecord.new(kind: .chatGPTOAuth, name: "OAuth", credentialAccount: "oauth", isDefault: true)
    try db.saveRuntimeProfile(profile)
    let listed = policyCompanion(model: "glm-5.2")
    let unlisted = policyCompanion(model: "glm-5.2")
    try db.saveCompanion(listed)
    try db.saveCompanion(unlisted)
    defaults.setString("bad", profileID: profile.id, suffix: "defaultModel")
    defaults.setString("bad", profileID: profile.id, suffix: "distillModel")

    try db.applyReconciliation(items: [
        ReconciliationItem(scope: .companion(id: listed.id, name: listed.name), model: "glm-5.2", profileId: profile.id, profileName: profile.name),
        ReconciliationItem(scope: .defaultModel, model: "bad", profileId: profile.id, profileName: profile.name),
        ReconciliationItem(scope: .distillModel, model: "bad", profileId: profile.id, profileName: profile.name),
    ], defaults: defaults)

    let flipped = try #require(try db.companion(id: listed.id))
    #expect(flipped.modelPolicy == .inherit)
    #expect(flipped.model == "glm-5.2")
    #expect(try #require(try db.companion(id: unlisted.id)).modelPolicy == .pinned)
    #expect(defaults.defaultModel(profileID: profile.id, fallback: "x") == KernelDefaults.chatGPTStaticModels[0])
    #expect(defaults.distillModel(profileID: profile.id).isEmpty)
}

@Test func applyReconciliationToleratesEmptyItemsAndMissingProfile() throws {
    let db = try policyTempDB()
    let defaults = ProfileScopedDefaults(defaults: catalogDefaults())
    try db.applyReconciliation(items: [], defaults: defaults)
    try db.applyReconciliation(items: [
        ReconciliationItem(scope: .defaultModel, model: "bad", profileId: "ghost", profileName: "ghost"),
        ReconciliationItem(scope: .companion(id: "no-such-cow", name: "?"), model: "bad", profileId: "ghost", profileName: "ghost"),
    ], defaults: defaults)
    #expect(defaults.string(profileID: "ghost", suffix: "defaultModel") == nil)
}

@Test func bootstrapReconcileRunsOnceAndRespectsUserChoices() throws {
    let db = try policyTempDB()
    let defaults = ProfileScopedDefaults(defaults: catalogDefaults())
    var companion = policyCompanion(model: "glm-5.2")
    try db.saveCompanion(companion)
    let bootstrap = RuntimeProfileBootstrap(db: db, defaults: defaults)
    let inputs = RuntimeProfileBootstrap.SeedInputs(
        apiKeyPresent: false,
        apiFormat: .anthropicMessages,
        apiBaseURL: RuntimeProfileBootstrap.defaultAnthropicBaseURL,
        oauthTokenPresent: true,
        preferredSource: .webLogin
    )
    let profile = try #require(try bootstrap.ensureSeeded(inputs: inputs, fallbackModelChoices: ["gpt-5.5"]))
    #expect(try #require(try db.companion(id: companion.id)).modelPolicy == .inherit)
    #expect(defaults.bool(profileID: profile.id, suffix: "oauthReconciled"))

    // 用户显式钉回目录外模型(D3 语义)→ 再次启动不得推翻
    companion = try #require(try db.companion(id: companion.id))
    companion.modelPolicy = .pinned
    try db.saveCompanion(companion)
    defaults.setString("glm-5.2", profileID: profile.id, suffix: "distillModel")
    _ = try bootstrap.ensureSeeded(inputs: inputs, fallbackModelChoices: ["gpt-5.5"])
    #expect(try #require(try db.companion(id: companion.id)).modelPolicy == .pinned)
    #expect(defaults.distillModel(profileID: profile.id) == "glm-5.2")
}

@Suite(.serialized) struct GatewayRefreshTests {
    @Test func refreshGatewayReplacesScopedListWithoutCacheWrites() async throws {
        let defaults = ProfileScopedDefaults(defaults: catalogDefaults())
        let gateway = RuntimeProfileRecord.new(
            kind: .openAIAPI,
            name: "GW",
            baseURL: "https://gateway.example.com",
            credentialAccount: "api",
            isDefault: true
        )
        defaults.setStringArray(["old-a"], profileID: gateway.id, suffix: "modelChoices")
        defaults.setManualModels(["keep"], profileID: gateway.id)
        PolicyCatalogStubProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://gateway.example.com/v1/models")
            return (200, Data(#"{"data":[{"id":"gw-a"},{"id":"gw-b"}]}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PolicyCatalogStubProtocol.self]
        let service = ModelCatalogService(session: URLSession(configuration: configuration), defaults: defaults)

        let refreshed = try await service.refresh(profile: gateway, credential: "key")
        #expect(refreshed == ["gw-a", "gw-b"])
        #expect(defaults.modelChoices(profileID: gateway.id, fallback: []) == ["gw-a", "gw-b"])
        #expect(defaults.cachedCatalog(profileID: gateway.id) == nil)
        #expect(defaults.manualModels(profileID: gateway.id) == ["keep"])
        #expect(ModelCatalogService.resolvedCatalog(profile: gateway, defaults: defaults, fallback: []) == ["gw-a", "gw-b", "keep"])
    }
}

private final class PolicyCatalogStubProtocol: URLProtocol {
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
