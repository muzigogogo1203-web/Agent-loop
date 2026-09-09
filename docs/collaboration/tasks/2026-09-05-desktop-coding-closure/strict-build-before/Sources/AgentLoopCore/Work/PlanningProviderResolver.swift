import Foundation

public protocol PlanningProviderResolver: Sendable {
    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider
}

package struct PlanningProviderResolutionError:
    LocalizedError, Sendable, Equatable
{
    package let code: String
    package let safeMessage: String

    package var errorDescription: String? {
        safeMessage
    }

    fileprivate init(_ failure: PlanningProviderResolutionFailure) {
        self.code = failure.rawValue
        self.safeMessage = failure.safeMessage
    }
}

package protocol PlanningRuntimeProfileSource: Sendable {
    func planningRuntimeProfile(
        id: String
    ) throws -> RuntimeProfileRecord?
}

package protocol PlanningModelCatalogSource: Sendable {
    func planningCachedCatalog(profileId: String) throws -> [String]?
    func planningModelChoices(profileId: String) throws -> [String]?
    func planningManualModels(profileId: String) throws -> [String]
}

package protocol PlanningCredentialSource: Sendable {
    func planningCredential(account: String) throws -> String?
}

package protocol PlanningProviderFactory: Sendable {
    func makePlanningAPIProvider(
        format: ProviderAPIFormat,
        credential: String,
        model: String,
        baseURL: URL
    ) throws -> any LLMProvider

    func makePlanningOAuthProvider(
        accessToken: String,
        accountId: String,
        model: String
    ) throws -> any LLMProvider
}

package struct StrictPlanningProviderResolver:
    PlanningProviderResolver, Sendable
{
    private static let oauthAccountIdCredentialAccount =
        "oauth-chatgpt-account-id"

    private let profiles: any PlanningRuntimeProfileSource
    private let catalogs: any PlanningModelCatalogSource
    private let credentials: any PlanningCredentialSource
    private let factory: any PlanningProviderFactory

    package init(
        profiles: any PlanningRuntimeProfileSource,
        catalogs: any PlanningModelCatalogSource,
        credentials: any PlanningCredentialSource,
        factory: any PlanningProviderFactory
    ) {
        self.profiles = profiles
        self.catalogs = catalogs
        self.credentials = credentials
        self.factory = factory
    }

    package func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider {
        guard let profile = try profiles.planningRuntimeProfile(id: profileId)
        else {
            throw Self.error(.runtimeProfileNotFound)
        }
        guard profile.id == profileId else {
            throw Self.error(.runtimeProfileNotFound)
        }

        switch profile.kind {
        case .cliCodex, .cliClaude:
            throw Self.error(.planningProfileCLIUnsupported)
        case .anthropicAPI, .openAIAPI:
            return try resolveAPIProvider(profile: profile, model: model)
        case .chatGPTOAuth:
            return try resolveOAuthProvider(profile: profile, model: model)
        }
    }

    private func resolveAPIProvider(
        profile: RuntimeProfileRecord,
        model: String
    ) throws -> any LLMProvider {
        let catalog: [String]
        do {
            let manual = try catalogs.planningManualModels(
                profileId: profile.id
            )
            if ModelCatalogService.isOfficialCatalogProfile(profile) {
                catalog =
                    (try catalogs.planningCachedCatalog(profileId: profile.id)
                        ?? []) + manual
            } else {
                catalog =
                    (try catalogs.planningModelChoices(profileId: profile.id)
                        ?? []) + manual
            }
        } catch {
            throw Self.error(.modelCatalogUnavailable)
        }

        let trustedModels = ProfileScopedDefaults.uniqueModels(catalog)
        guard !trustedModels.isEmpty else {
            throw Self.error(.modelCatalogUnavailable)
        }
        guard trustedModels.contains(model) else {
            throw Self.error(.planningModelUnsupported)
        }

        let credentialAccount = try Self.requiredAccount(
            profile.credentialAccount
        )
        let credential: String
        do {
            guard let resolved = Self.nonEmpty(
                try credentials.planningCredential(
                    account: credentialAccount
                )
            ) else {
                throw Self.error(.credentialNotFound)
            }
            credential = resolved
        } catch let error as PlanningProviderResolutionError {
            throw error
        } catch {
            throw Self.error(.credentialReadFailed)
        }

        guard let rawBaseURL = profile.baseURL,
              let baseURL = ProviderEndpoint.normalizedBaseURL(rawBaseURL)
        else {
            throw Self.error(.endpointInvalid)
        }

        let format: ProviderAPIFormat
        switch profile.kind {
        case .anthropicAPI:
            format = .anthropicMessages
        case .openAIAPI:
            format = .openAIChatCompletions
        case .chatGPTOAuth, .cliCodex, .cliClaude:
            preconditionFailure("Non-API profile reached API resolver")
        }

        do {
            return try factory.makePlanningAPIProvider(
                format: format,
                credential: credential,
                model: model,
                baseURL: baseURL
            )
        } catch {
            throw Self.error(.providerConstructionFailed)
        }
    }

    private func resolveOAuthProvider(
        profile: RuntimeProfileRecord,
        model: String
    ) throws -> any LLMProvider {
        let trustedModels = ProfileScopedDefaults.uniqueModels(
            KernelDefaults.chatGPTStaticModels
        )
        guard !trustedModels.isEmpty else {
            throw Self.error(.modelCatalogUnavailable)
        }
        guard trustedModels.contains(model) else {
            throw Self.error(.planningModelUnsupported)
        }

        let credentialAccount = try Self.requiredAccount(
            profile.credentialAccount
        )
        let accessToken: String
        do {
            guard let resolved = Self.nonEmpty(
                try credentials.planningCredential(
                    account: credentialAccount
                )
            ) else {
                throw Self.error(.credentialNotFound)
            }
            accessToken = resolved
        } catch let error as PlanningProviderResolutionError {
            throw error
        } catch {
            throw Self.error(.credentialReadFailed)
        }

        let accountId: String
        do {
            guard let resolved = Self.nonEmpty(
                try credentials.planningCredential(
                    account: Self.oauthAccountIdCredentialAccount
                )
            ) else {
                throw Self.error(.oauthAccountIdNotFound)
            }
            accountId = resolved
        } catch let error as PlanningProviderResolutionError {
            throw error
        } catch {
            throw Self.error(.oauthAccountIdReadFailed)
        }

        do {
            return try factory.makePlanningOAuthProvider(
                accessToken: accessToken,
                accountId: accountId,
                model: model
            )
        } catch {
            throw Self.error(.providerConstructionFailed)
        }
    }

    private static func requiredAccount(
        _ account: String?
    ) throws -> String {
        guard let account = nonEmpty(account) else {
            throw error(.credentialAccountMissing)
        }
        return account
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ),
        !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private static func error(
        _ failure: PlanningProviderResolutionFailure
    ) -> PlanningProviderResolutionError {
        PlanningProviderResolutionError(failure)
    }
}

private enum PlanningProviderResolutionFailure: String {
    case runtimeProfileNotFound = "runtime_profile_not_found"
    case modelCatalogUnavailable = "model_catalog_unavailable"
    case planningModelUnsupported = "planning_model_unsupported"
    case credentialAccountMissing = "credential_account_missing"
    case credentialNotFound = "credential_not_found"
    case credentialReadFailed = "credential_read_failed"
    case endpointInvalid = "endpoint_invalid"
    case providerConstructionFailed = "provider_construction_failed"
    case oauthAccountIdNotFound = "oauth_account_id_not_found"
    case oauthAccountIdReadFailed = "oauth_account_id_read_failed"
    case planningProfileCLIUnsupported =
        "planning_profile_cli_unsupported"

    var safeMessage: String {
        switch self {
        case .runtimeProfileNotFound:
            return "规划供给线不存在。"
        case .modelCatalogUnavailable:
            return "规划供给线的模型目录不可用。"
        case .planningModelUnsupported:
            return "所选规划模型不受当前供给线支持。"
        case .credentialAccountMissing:
            return "规划供给线缺少凭据账户配置。"
        case .credentialNotFound:
            return "规划供给线凭据不存在。"
        case .credentialReadFailed:
            return "无法读取规划供给线凭据。"
        case .endpointInvalid:
            return "规划供给线的 API 端点无效。"
        case .providerConstructionFailed:
            return "无法创建规划模型服务。"
        case .oauthAccountIdNotFound:
            return "ChatGPT 账户标识不存在。"
        case .oauthAccountIdReadFailed:
            return "无法读取 ChatGPT 账户标识。"
        case .planningProfileCLIUnsupported:
            return "CLI 供给线暂不支持耐久规划。"
        }
    }
}

package struct RuntimeCredentialAccounts: Sendable, Equatable {
    package let apiKey: String
    package let searchKey: String
    package let oauth: OAuthCredentialAccounts

    package init(
        apiKey: String,
        searchKey: String,
        oauth: OAuthCredentialAccounts
    ) {
        self.apiKey = apiKey
        self.searchKey = searchKey
        self.oauth = oauth
    }
}

package struct RuntimeCredentialPresence: Sendable, Equatable {
    package let apiKeyPresent: Bool
    package let searchKeyPresent: Bool
    package let oauthAccessTokenPresent: Bool
    package let chatGPTAccountIdPresent: Bool

    package init(
        apiKeyPresent: Bool,
        searchKeyPresent: Bool,
        oauthAccessTokenPresent: Bool,
        chatGPTAccountIdPresent: Bool
    ) {
        self.apiKeyPresent = apiKeyPresent
        self.searchKeyPresent = searchKeyPresent
        self.oauthAccessTokenPresent = oauthAccessTokenPresent
        self.chatGPTAccountIdPresent = chatGPTAccountIdPresent
    }
}

package struct RuntimeCredentialResolver: Sendable {
    private let database: AppDatabase
    private let defaults: ProfileScopedDefaults
    private let credentialAccess: SynchronizedCredentialAccess
    private let accounts: RuntimeCredentialAccounts
    private let defaultBaseURL: String
    private let tokenRefresher: (@Sendable () async throws -> String)?

    package init(
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        credentialAccess: SynchronizedCredentialAccess,
        accounts: RuntimeCredentialAccounts,
        defaultBaseURL: String,
        tokenRefresher: (@Sendable () async throws -> String)?
    ) {
        self.database = database
        self.defaults = defaults
        self.credentialAccess = credentialAccess
        self.accounts = accounts
        self.defaultBaseURL = defaultBaseURL
        self.tokenRefresher = tokenRefresher
    }

    package func provider(
        model requestedModel: String,
        companionId: String?
    ) throws -> (any LLMProvider)? {
        let bundle = try Self.mapProfileSourceFailure {
            try database.readRuntimeProviderResolutionBundle(
                companionId: companionId
            )
        }
        guard bundle.defaultProfile != nil else {
            throw RuntimeCredentialResolutionError(
                .defaultProfileNotFound
            )
        }
        if companionId != nil, bundle.companion == nil {
            throw RuntimeCredentialResolutionError(.companionNotFound)
        }
        guard let profile = bundle.selectedProfile else {
            throw RuntimeCredentialResolutionError(
                .selectedProfileNotFound
            )
        }
        guard !profile.kind.isCLI else { return nil }

        let endpointRaw = profile.baseURL ?? defaultBaseURL
        guard let endpoint = ProviderEndpoint.normalizedBaseURL(endpointRaw)
        else {
            throw RuntimeCredentialResolutionError(.endpointInvalid)
        }

        let requested = requestedModel.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let selectedModel: String
        if bundle.companion?.modelPolicy == .inherit || requested.isEmpty {
            selectedModel = defaults.defaultModel(
                profileID: profile.id,
                fallback: KernelDefaults.defaultGuideModel
            )
        } else {
            selectedModel = requested
        }
        guard !selectedModel.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw RuntimeCredentialResolutionError(
                .modelCatalogUnavailable
            )
        }
        let trustedCatalog = try Self.mapCatalogSourceFailure {
            try ModelCatalogService.trustedCatalog(
                profile: profile,
                defaults: defaults
            )
        }
        if let trustedCatalog,
           !trustedCatalog.contains(selectedModel)
        {
            throw RuntimeCredentialResolutionError(
                .runtimeModelUnsupported
            )
        }

        switch profile.kind {
        case .anthropicAPI, .openAIAPI:
            guard let account = Self.nonblank(profile.credentialAccount)
            else {
                throw RuntimeCredentialResolutionError(
                    .credentialAccountMissing
                )
            }
            let loadedCredential: String? = try Self
                .mapCredentialSourceFailure {
                guard let raw = try credentialAccess.read(
                    account: account,
                    interactionPolicy: .allow
                ) else {
                    return nil
                }
                return try Self.validCredential(raw)
            }
            guard let credential = loadedCredential else {
                return nil
            }
            let format: ProviderAPIFormat = profile.kind == .anthropicAPI
                ? .anthropicMessages
                : .openAIChatCompletions
            return LLMProviderFactory.make(
                format: format,
                authScheme: .automatic,
                credential: credential,
                model: selectedModel,
                baseURL: endpoint
            )
        case .chatGPTOAuth:
            let snapshot = try Self.mapCredentialSourceFailure {
                try credentialAccess.readOAuthCredentials(
                    accounts: accounts.oauth,
                    interactionPolicy: .allow
                )
            }
            guard let access = snapshot.accessToken else { return nil }
            guard let accountID = snapshot.accountID else {
                throw RuntimeCredentialResolutionError(
                    .oauthAccountIdNotFound
                )
            }
            return OpenAIResponsesProvider(
                accessToken: access.use { $0 },
                accountID: accountID.use { $0 },
                model: selectedModel,
                tokenRefresher: tokenRefresher
            )
        case .cliCodex, .cliClaude:
            return nil
        }
    }

    package func searchKey() throws -> String? {
        try Self.mapCredentialSourceFailure {
            guard let value = try credentialAccess.read(
                account: accounts.searchKey,
                interactionPolicy: .allow
            ) else {
                return nil
            }
            return try Self.validCredential(value)
        }
    }

    package func presence(
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> RuntimeCredentialPresence {
        try Self.mapCredentialSourceFailure {
            let snapshot = try credentialAccess.readRuntimeCredentialPresence(
                apiKeyAccount: accounts.apiKey,
                searchKeyAccount: accounts.searchKey,
                oauthAccounts: accounts.oauth,
                interactionPolicy: interactionPolicy
            )
            if let apiKey = snapshot.apiKey {
                _ = try Self.validCredential(apiKey)
            }
            if let searchKey = snapshot.searchKey {
                _ = try Self.validCredential(searchKey)
            }
            return RuntimeCredentialPresence(
                apiKeyPresent: snapshot.apiKey != nil,
                searchKeyPresent: snapshot.searchKey != nil,
                oauthAccessTokenPresent: snapshot.oauth.accessToken != nil,
                chatGPTAccountIdPresent: snapshot.oauth.accountID != nil
            )
        }
    }

    private static func nonblank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func validCredential(_ value: String) throws -> String {
        guard !value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw CredentialValueInvalidError()
        }
        return value
    }

    private static func mapProfileSourceFailure<Value>(
        _ body: () throws -> Value
    ) throws -> Value {
        do {
            return try body()
        } catch {
            // P1-B-CATCH typed N[.runtimeProfileSourceFailure]
            throw RuntimeCredentialResolutionError(
                .runtimeProfileReadFailed
            )
        }
    }

    private static func mapCatalogSourceFailure<Value>(
        _ body: () throws -> Value
    ) throws -> Value {
        do {
            return try body()
        } catch {
            // P1-B-CATCH typed N[.runtimeCatalogSourceFailure]
            throw RuntimeCredentialResolutionError(
                .modelCatalogUnavailable
            )
        }
    }

    private static func mapCredentialSourceFailure<Value>(
        _ body: () throws -> Value
    ) throws -> Value {
        do {
            return try body()
        } catch {
            // P1-B-CATCH typed N[.runtimeCredentialSourceFailure]
            switch error {
            case is CredentialValueInvalidError:
                throw RuntimeCredentialResolutionError(
                    .credentialValueInvalid
                )
            case let keychain as KeychainError:
                throw RuntimeCredentialResolutionError(
                    .keychainReadFailed(osStatus: keychain.status)
                )
            case _:
                throw RuntimeCredentialResolutionError(
                    .credentialReadFailed
                )
            }
        }
    }
}
