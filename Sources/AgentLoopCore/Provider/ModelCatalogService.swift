import Foundation

public enum ModelCatalogError: LocalizedError, Sendable, Equatable {
    case invalidBaseURL(profileId: String)
    case unsupportedProfileKind(RuntimeProfileKind)
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let profileId):
            return "供给线 \(profileId) 的 API 端点无效"
        case .unsupportedProfileKind(let kind):
            return "供给线类型 \(kind.rawValue) 没有可刷新的模型目录"
        case .malformedResponse:
            return "模型目录响应缺少 data[].id"
        }
    }
}

public actor ModelCatalogService {
    private let session: URLSession
    private let defaults: ProfileScopedDefaults
    private let now: @Sendable () -> Date

    public init(
        session: URLSession = .shared,
        defaults: ProfileScopedDefaults = ProfileScopedDefaults(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.defaults = defaults
        self.now = now
    }

    public func catalog(profile: RuntimeProfileRecord) -> [String]? {
        Self.trustedCatalog(profile: profile, defaults: defaults)
    }

    @discardableResult
    public func refresh(profile: RuntimeProfileRecord, credential: String) async throws -> [String] {
        switch profile.kind {
        case .chatGPTOAuth, .cliCodex, .cliClaude:
            return Self.staticCatalog(profile: profile)
        case .anthropicAPI, .openAIAPI:
            let models = try await fetchModels(profile: profile, credential: credential)
            if Self.isOfficialCatalogProfile(profile) {
                defaults.setCachedCatalog(models, fetchedAt: now(), profileID: profile.id)
            } else {
                defaults.setStringArray(ProfileScopedDefaults.uniqueModels(models), profileID: profile.id, suffix: "modelChoices")
            }
            return models
        }
    }

    public static func resolvedCatalog(profile: RuntimeProfileRecord, defaults: ProfileScopedDefaults, fallback: [String]) -> [String] {
        if let trusted = trustedCatalog(profile: profile, defaults: defaults) { return trusted }
        let scoped = defaults.modelChoices(profileID: profile.id, fallback: fallback)
        let resolved = ProfileScopedDefaults.uniqueModels(scoped + defaults.manualModels(profileID: profile.id))
        return resolved.isEmpty ? fallback : resolved
    }

    public static func trustedCatalog(
        profile: RuntimeProfileRecord,
        defaults: ProfileScopedDefaults = ProfileScopedDefaults()
    ) -> [String]? {
        switch profile.kind {
        case .chatGPTOAuth, .cliCodex, .cliClaude:
            return staticCatalog(profile: profile)
        case .anthropicAPI, .openAIAPI:
            guard isOfficialCatalogProfile(profile),
                  let cached = defaults.cachedCatalog(profileID: profile.id),
                  !cached.isEmpty else {
                return nil
            }
            return ProfileScopedDefaults.uniqueModels(cached + defaults.manualModels(profileID: profile.id))
        }
    }

    public static func isOfficialCatalogProfile(_ profile: RuntimeProfileRecord) -> Bool {
        guard let rawBaseURL = profile.baseURL,
              let baseURL = ProviderEndpoint.normalizedBaseURL(rawBaseURL),
              let host = baseURL.host()?.lowercased() else {
            return false
        }
        switch profile.kind {
        case .anthropicAPI:
            return host == "api.anthropic.com"
        case .openAIAPI:
            return host == "api.openai.com"
        case .chatGPTOAuth, .cliCodex, .cliClaude:
            return true
        }
    }

    private static func staticCatalog(profile: RuntimeProfileRecord) -> [String] {
        profile.kind.isCLI ? KernelDefaults.cliStaticModels : KernelDefaults.chatGPTStaticModels
    }

    private func fetchModels(profile: RuntimeProfileRecord, credential: String) async throws -> [String] {
        guard let rawBaseURL = profile.baseURL,
              let baseURL = ProviderEndpoint.normalizedBaseURL(rawBaseURL) else {
            throw ModelCatalogError.invalidBaseURL(profileId: profile.id)
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1").appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch profile.kind {
        case .anthropicAPI:
            request.setValue(credential.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .openAIAPI:
            request.setValue("Bearer \(credential.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        case .chatGPTOAuth, .cliCodex, .cliClaude:
            throw ModelCatalogError.unsupportedProfileKind(profile.kind)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let body = String(data: Data(data.prefix(400)), encoding: .utf8) ?? ""
            throw ProviderError.http(status: status, body: body)
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rows = object?["data"] as? [[String: Any]] ?? []
        let models = ProfileScopedDefaults.uniqueModels(rows.compactMap { $0["id"] as? String })
        guard !models.isEmpty else {
            throw ModelCatalogError.malformedResponse
        }
        return models
    }
}
