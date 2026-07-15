import Foundation
import GRDB

public struct RuntimeProfileBootstrap: Sendable {
    public struct SeedInputs: Sendable, Equatable {
        public var apiKeyPresent: Bool
        public var apiFormat: ProviderAPIFormat
        public var apiBaseURL: String
        public var oauthTokenPresent: Bool
        public var preferredSource: ProviderCredentialSource

        public init(
            apiKeyPresent: Bool,
            apiFormat: ProviderAPIFormat,
            apiBaseURL: String,
            oauthTokenPresent: Bool,
            preferredSource: ProviderCredentialSource
        ) {
            self.apiKeyPresent = apiKeyPresent
            self.apiFormat = apiFormat
            self.apiBaseURL = apiBaseURL
            self.oauthTokenPresent = oauthTokenPresent
            self.preferredSource = preferredSource
        }
    }

    public static let apiKeyCredentialAccount = "anthropic-api-key"
    public static let oauthAccessTokenCredentialAccount = "oauth-access-token"
    public static let defaultAnthropicBaseURL = "https://api.anthropic.com"

    private let db: AppDatabase
    private let defaults: ProfileScopedDefaults

    public init(db: AppDatabase, defaults: ProfileScopedDefaults = ProfileScopedDefaults()) {
        self.db = db
        self.defaults = defaults
    }

    @discardableResult
    public func ensureSeeded(
        inputs: SeedInputs,
        fallbackDefaultModel: String = KernelDefaults.defaultGuideModel,
        fallbackModelChoices: [String]
    ) throws -> RuntimeProfileRecord? {
        let profile = try db.pool.write { database -> RuntimeProfileRecord? in
            let existingCount = try RuntimeProfileRecord.fetchCount(database)
            if existingCount > 0 {
                return try RuntimeProfileRecord
                    .filter(Column("isDefault") == true)
                    .order(Column("createdAt"), Column.rowID)
                    .fetchOne(database)
            }

            let profiles = Self.seedProfiles(inputs: inputs)
            for profile in profiles {
                try profile.insert(database)
            }
            return profiles.first(where: \.isDefault)
        }
        if let profile {
            defaults.copyLegacyModelDefaults(
                to: profile.id,
                fallbackDefaultModel: fallbackDefaultModel,
                fallbackModelChoices: fallbackModelChoices
            )
        }
        return profile
    }

    private static func seedProfiles(inputs: SeedInputs) -> [RuntimeProfileRecord] {
        var profiles: [RuntimeProfileRecord] = []
        if inputs.apiKeyPresent {
            profiles.append(
                RuntimeProfileRecord.new(
                    kind: apiKind(for: inputs.apiFormat),
                    name: apiName(for: inputs.apiFormat),
                    baseURL: normalizedBaseString(inputs.apiBaseURL),
                    credentialAccount: apiKeyCredentialAccount
                )
            )
        }
        if inputs.oauthTokenPresent {
            profiles.append(
                RuntimeProfileRecord.new(
                    kind: .chatGPTOAuth,
                    name: "ChatGPT 登录",
                    baseURL: nil,
                    credentialAccount: oauthAccessTokenCredentialAccount
                )
            )
        }
        if profiles.isEmpty {
            profiles.append(
                RuntimeProfileRecord.new(
                    kind: .anthropicAPI,
                    name: "未配置 API",
                    baseURL: normalizedBaseString(inputs.apiBaseURL),
                    credentialAccount: nil
                )
            )
        }

        let defaultIndex: Int
        switch inputs.preferredSource {
        case .apiKey:
            defaultIndex = profiles.firstIndex { $0.kind == .anthropicAPI || $0.kind == .openAIAPI } ?? 0
        case .webLogin:
            defaultIndex = profiles.firstIndex { $0.kind == .chatGPTOAuth } ?? 0
        }
        profiles[defaultIndex].isDefault = true
        return profiles
    }

    private static func apiKind(for format: ProviderAPIFormat) -> RuntimeProfileKind {
        switch format {
        case .anthropicMessages:
            return .anthropicAPI
        case .openAIChatCompletions:
            return .openAIAPI
        }
    }

    private static func apiName(for format: ProviderAPIFormat) -> String {
        switch format {
        case .anthropicMessages:
            return "Anthropic API"
        case .openAIChatCompletions:
            return "OpenAI API"
        }
    }

    private static func normalizedBaseString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? defaultAnthropicBaseURL : trimmed
        return ProviderEndpoint.normalizedBaseURL(source)?.absoluteString ?? source
    }
}
