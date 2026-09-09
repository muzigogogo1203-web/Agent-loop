import Foundation
import AgentLoopCore

package struct RuntimeWorkflowSnapshot: Sendable {
    package let profiles: [RuntimeProfileRecord]
    package let defaultProfile: RuntimeProfileRecord
    package let companions: [CompanionRecord]
    package let camps: [CampRecord]
    package let credentials: RuntimeCredentialPresence
    package let legacyRuminationSnapshot: LegacyRuminationStartupSnapshot

    package init(
        profiles: [RuntimeProfileRecord],
        defaultProfile: RuntimeProfileRecord,
        companions: [CompanionRecord],
        camps: [CampRecord],
        credentials: RuntimeCredentialPresence,
        legacyRuminationSnapshot: LegacyRuminationStartupSnapshot
    ) {
        self.profiles = profiles
        self.defaultProfile = defaultProfile
        self.companions = companions
        self.camps = camps
        self.credentials = credentials
        self.legacyRuminationSnapshot = legacyRuminationSnapshot
    }
}

package struct RuntimeWorkflowReads: Sendable {
    package let load: @Sendable () throws -> RuntimeWorkflowReadBundle

    package init(
        load: @escaping @Sendable () throws -> RuntimeWorkflowReadBundle
    ) {
        self.load = load
    }

    package static func live(database: AppDatabase) -> Self {
        Self(load: { try database.readRuntimeWorkflowBundle() })
    }
}

package struct RuntimeCredentialPresencePort: Sendable {
    package let load: @Sendable (KeychainInteractionPolicy) throws
        -> RuntimeCredentialPresence

    package init(
        load: @escaping @Sendable (KeychainInteractionPolicy) throws
            -> RuntimeCredentialPresence
    ) {
        self.load = load
    }

    package static func live(resolver: RuntimeCredentialResolver) -> Self {
        Self(load: { policy in
            try resolver.presence(interactionPolicy: policy)
        })
    }

#if DEBUG
    package static func preview(
        _ presence: RuntimeCredentialPresence
    ) -> Self {
        Self(load: { _ in presence })
    }
#endif
}

package struct RuntimeBootstrapRequest: Sendable {
    package let apiFormat: ProviderAPIFormat
    package let apiBaseURL: String
    package let preferredSource: ProviderCredentialSource
    package let fallbackModelChoices: [String]
    package let interactionPolicy: KeychainInteractionPolicy

    package init(
        apiFormat: ProviderAPIFormat,
        apiBaseURL: String,
        preferredSource: ProviderCredentialSource,
        fallbackModelChoices: [String],
        interactionPolicy: KeychainInteractionPolicy
    ) {
        self.apiFormat = apiFormat
        self.apiBaseURL = apiBaseURL
        self.preferredSource = preferredSource
        self.fallbackModelChoices = fallbackModelChoices
        self.interactionPolicy = interactionPolicy
    }
}

package struct SynchronousRuntimeBootstrap: Sendable {
    private let database: AppDatabase
    private let defaults: ProfileScopedDefaults
    private let presence: RuntimeCredentialPresencePort
    private let reads: RuntimeWorkflowReads

    package init(
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        resolver: RuntimeCredentialResolver,
        reporter: FailureReporter,
        presence: RuntimeCredentialPresencePort,
        reads: RuntimeWorkflowReads? = nil
    ) {
        self.database = database
        self.defaults = defaults
        self.presence = presence
        self.reads = reads ?? .live(database: database)
        _ = resolver
        _ = reporter
    }

    package func run(
        _ request: RuntimeBootstrapRequest,
        trace: OperationTrace
    ) throws -> RuntimeWorkflowSnapshot {
        precondition(trace.operation == .runtimeBootstrap)
        let credentials = try presence.load(request.interactionPolicy)
        _ = try RuntimeProfileBootstrap(
            db: database,
            defaults: defaults
        ).ensureSeeded(
            inputs: RuntimeProfileBootstrap.SeedInputs(
                apiKeyPresent: credentials.apiKeyPresent,
                apiFormat: request.apiFormat,
                apiBaseURL: request.apiBaseURL,
                oauthTokenPresent: credentials.oauthAccessTokenPresent,
                preferredSource: request.preferredSource
            ),
            fallbackModelChoices: request.fallbackModelChoices
        )
        let bundle = try reads.load()
        return RuntimeWorkflowSnapshot(
            profiles: bundle.profiles,
            defaultProfile: bundle.defaultProfile,
            companions: bundle.companions,
            camps: bundle.camps,
            credentials: credentials,
            legacyRuminationSnapshot: legacySnapshot(
                defaultProfile: bundle.defaultProfile
            )
        )
    }

    private func legacySnapshot(
        defaultProfile: RuntimeProfileRecord
    ) -> LegacyRuminationStartupSnapshot {
        if defaultProfile.kind.isCLI {
            return .legacyProfileCLIUnsupported
        }
        let distill = defaults.distillModel(
            profileID: defaultProfile.id
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = distill.isEmpty
            ? defaults.defaultModel(
                profileID: defaultProfile.id,
                fallback: ""
            )
            : distill
        guard !selected.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return .legacyModelUnavailable
        }
        return .valid(
            runtimeProfileId: defaultProfile.id,
            model: selected
        )
    }
}

package struct RuntimeProfileSwitchCommand: Sendable {
    package let profileId: String
    package let inheritCompanionIds: Set<String>
    package let resetSettingScopes: Set<String>

    package init(
        profileId: String,
        inheritCompanionIds: Set<String>,
        resetSettingScopes: Set<String>
    ) {
        self.profileId = profileId
        self.inheritCompanionIds = inheritCompanionIds
        self.resetSettingScopes = resetSettingScopes
    }
}

package enum RuntimeCredentialSlot: Sendable, Equatable {
    case apiKey
    case searchKey
}

package struct RuntimeCredentialSetReceipt: Sendable, Equatable {
    package let slot: RuntimeCredentialSlot
    package let attachedProfileId: String?
    fileprivate let trace: OperationTrace

    fileprivate init(
        slot: RuntimeCredentialSlot,
        attachedProfileId: String?,
        trace: OperationTrace
    ) {
        self.slot = slot
        self.attachedProfileId = attachedProfileId
        self.trace = trace
    }
}

fileprivate enum RuntimeCredentialAttachmentRecoveryStep:
    Sendable, Equatable
{
    case resolveDefault
    case attach(RuntimeCredentialAttachmentTarget)
}

package struct RuntimeCredentialAttachmentPending: Sendable, Equatable {
    package let slot: RuntimeCredentialSlot
    fileprivate let committed: RuntimeCredentialSetReceipt
    fileprivate let step: RuntimeCredentialAttachmentRecoveryStep

    fileprivate init(
        committed: RuntimeCredentialSetReceipt,
        step: RuntimeCredentialAttachmentRecoveryStep
    ) {
        precondition(committed.slot == .apiKey)
        slot = .apiKey
        self.committed = committed
        self.step = step
    }
}

package enum RuntimeCredentialSetOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case committed(RuntimeCredentialSetReceipt)
    case attachmentPending(
        RuntimeCredentialAttachmentPending,
        failure: UserVisibleFailure
    )
    case committedWithVisibilityFailure(
        receipt: RuntimeCredentialSetReceipt,
        failure: UserVisibleFailure
    )
}

package enum RuntimeCredentialAttachmentRecoveryOutcome: Sendable {
    case recovered(RuntimeCredentialSetReceipt)
    case pending(
        RuntimeCredentialAttachmentPending,
        failure: UserVisibleFailure
    )
    case recoveredWithVisibilityFailure(
        receipt: RuntimeCredentialSetReceipt,
        failure: UserVisibleFailure
    )
    case superseded
}

package struct RuntimeCatalogRefreshReceipt: Sendable, Equatable {
    package let profileId: String
    package let models: [String]

    package init(profileId: String, models: [String]) {
        self.profileId = profileId
        self.models = models
    }
}

package struct RuntimeProviderTestReceipt: Sendable, Equatable {
    package let model: String

    package init(model: String) {
        self.model = model
    }
}

package struct RuntimeOAuthConfiguration: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let authorizationEndpoint: URL
    package let tokenEndpoint: URL
    package let redirectURI: String
    package let clientID: String
    package let requiresAccountID: Bool
    package let requiresLocalListener: Bool

    package init(
        flow: OAuthCredentialFlow,
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        redirectURI: String,
        clientID: String,
        requiresAccountID: Bool,
        requiresLocalListener: Bool
    ) {
        self.flow = flow
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.redirectURI = redirectURI
        self.clientID = clientID
        self.requiresAccountID = requiresAccountID
        self.requiresLocalListener = requiresLocalListener
    }
}

package struct RuntimeOAuthAuthorizationCommand: Sendable, Equatable {
    package let configuration: RuntimeOAuthConfiguration

    package init(configuration: RuntimeOAuthConfiguration) {
        self.configuration = configuration
    }
}

fileprivate struct OAuthAuthorizationURL: Sendable, Equatable {
    let raw: URL

    init(_ raw: URL) {
        self.raw = raw
    }
}

package struct RuntimeOAuthAuthorizationReceipt: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let configuration: RuntimeOAuthConfiguration
    fileprivate let url: OAuthAuthorizationURL
    fileprivate let expectedState: SecretValue
    fileprivate let trace: OperationTrace
    fileprivate let requiresLocalListener: Bool

    fileprivate init(
        configuration: RuntimeOAuthConfiguration,
        url: OAuthAuthorizationURL,
        expectedState: SecretValue,
        trace: OperationTrace,
        requiresLocalListener: Bool
    ) {
        flow = configuration.flow
        self.configuration = configuration
        self.url = url
        self.expectedState = expectedState
        self.trace = trace
        self.requiresLocalListener = requiresLocalListener
    }

    package func withAuthorizationURL<T>(
        _ body: (URL) throws -> T
    ) rethrows -> T {
        try body(url.raw)
    }
}

package struct RuntimeOAuthListenerLease: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let reservationId: UUID
    fileprivate let leaseId: UUID

    fileprivate init(
        flow: OAuthCredentialFlow,
        reservationId: UUID,
        leaseId: UUID
    ) {
        self.flow = flow
        self.reservationId = reservationId
        self.leaseId = leaseId
    }

    package func belongs(
        to reservation: RuntimeOAuthAuthorizationReservation
    ) -> Bool {
        flow == reservation.flow
            && reservationId == reservation.reservationId
    }
}

fileprivate enum RuntimeOAuthAuthorizationRecoveryStage:
    Sendable, Equatable
{
    case listenerRestart
    case browserReopen
    case listenerThenBrowser
}

package struct RuntimeOAuthAuthorizationRecoveryPending:
    Sendable, Equatable
{
    package let flow: OAuthCredentialFlow
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let stage: RuntimeOAuthAuthorizationRecoveryStage
    fileprivate let listenerLease: RuntimeOAuthListenerLease?

    fileprivate init(
        authorization: RuntimeOAuthAuthorizationReceipt,
        stage: RuntimeOAuthAuthorizationRecoveryStage,
        listenerLease: RuntimeOAuthListenerLease?
    ) {
        flow = authorization.flow
        self.authorization = authorization
        self.stage = stage
        self.listenerLease = listenerLease
    }

    package func ownsAuthorization(
        _ receipt: RuntimeOAuthAuthorizationReceipt
    ) -> Bool {
        authorization == receipt
    }

    package func sameAuthorization(
        as other: RuntimeOAuthAuthorizationRecoveryPending
    ) -> Bool {
        authorization == other.authorization
    }

    package func ownsListenerLease(
        _ lease: RuntimeOAuthListenerLease
    ) -> Bool {
        listenerLease == lease
    }
}

package enum RuntimeOAuthAuthorizationOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case prepared(RuntimeOAuthAuthorizationReceipt)
    case recoveryPending(
        RuntimeOAuthAuthorizationRecoveryPending,
        failure: UserVisibleFailure
    )
    case superseded
}

package struct RuntimeOAuthAuthorizationOpenCommand: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let reservation: RuntimeOAuthAuthorizationReservation

    package static func prepared(
        _ authorization: RuntimeOAuthAuthorizationReceipt,
        reservation: RuntimeOAuthAuthorizationReservation
    ) -> Self {
        Self(
            flow: authorization.flow,
            authorization: authorization,
            reservation: reservation
        )
    }
}

package enum RuntimeOAuthAuthorizationOpenOutcome: Sendable {
    case opened(RuntimeOAuthAuthorizationReceipt)
    case retainedRecovery(RuntimeOAuthAuthorizationRecoveryPending)
    case recoveryPending(
        RuntimeOAuthAuthorizationRecoveryPending,
        failure: UserVisibleFailure
    )
    case superseded
}

package struct RuntimeOAuthAuthorizationReservation: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let reservationId: UUID
    fileprivate let trace: OperationTrace

    fileprivate init(
        flow: OAuthCredentialFlow,
        reservationId: UUID,
        trace: OperationTrace
    ) {
        self.flow = flow
        self.reservationId = reservationId
        self.trace = trace
    }
}

package enum RuntimeOAuthAuthorizationReservationOutcome: Sendable {
    case reserved(RuntimeOAuthAuthorizationReservation)
    case rejected(UserVisibleFailure)
}

package enum RuntimeOAuthAuthorizationRejectionOutcome: Sendable {
    case rejected(UserVisibleFailure)
    case superseded
}

package enum RuntimeOAuthAuthorizationRecoveryOutcome: Sendable {
    case ready(RuntimeOAuthAuthorizationReceipt)
    case pending(
        RuntimeOAuthAuthorizationRecoveryPending,
        failure: UserVisibleFailure
    )
    case deferredToCallback(failure: UserVisibleFailure)
    case deferredToPreparation(failure: UserVisibleFailure)
    case superseded
}

package enum RuntimeOAuthCallbackIngress: Sendable, Equatable {
    case localListener
    case customScheme
}

fileprivate enum RuntimeOAuthCallbackIngressSource: Sendable, Equatable {
    case localListener(RuntimeOAuthListenerLease)
    case customScheme
}

package struct RuntimeOAuthCustomSchemeCallbackCommand:
    Sendable, Equatable
{
    package let callbackURL: URL

    package init(callbackURL: URL) {
        self.callbackURL = callbackURL
    }
}

package struct RuntimeOAuthCallbackCommand: Sendable, Equatable {
    fileprivate enum Owner: Sendable, Equatable {
        case authorization(RuntimeOAuthAuthorizationReceipt)
        case recovery(RuntimeOAuthAuthorizationRecoveryPending)
    }

    fileprivate let owner: Owner
    fileprivate let reservation: RuntimeOAuthAuthorizationReservation
    fileprivate let listenerLease: RuntimeOAuthListenerLease
    package let callbackURL: URL

    fileprivate init(
        owner: Owner,
        reservation: RuntimeOAuthAuthorizationReservation,
        listenerLease: RuntimeOAuthListenerLease,
        callbackURL: URL
    ) {
        self.owner = owner
        self.reservation = reservation
        self.listenerLease = listenerLease
        self.callbackURL = callbackURL
    }

    package static func authorization(
        _ authorization: RuntimeOAuthAuthorizationReceipt,
        reservation: RuntimeOAuthAuthorizationReservation,
        listenerLease: RuntimeOAuthListenerLease,
        callbackURL: URL
    ) -> Self {
        Self(
            owner: .authorization(authorization),
            reservation: reservation,
            listenerLease: listenerLease,
            callbackURL: callbackURL
        )
    }

    package static func recovery(
        _ pending: RuntimeOAuthAuthorizationRecoveryPending,
        reservation: RuntimeOAuthAuthorizationReservation,
        listenerLease: RuntimeOAuthListenerLease,
        callbackURL: URL
    ) -> Self {
        Self(
            owner: .recovery(pending),
            reservation: reservation,
            listenerLease: listenerLease,
            callbackURL: callbackURL
        )
    }
}

package enum RuntimeOAuthCallbackClaimOrigin: Sendable, Equatable {
    case ready(RuntimeOAuthAuthorizationReceipt)
    case authorizationRecovery(RuntimeOAuthAuthorizationRecoveryPending)
}

package struct RuntimeOAuthCallbackClaim: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let origin: RuntimeOAuthCallbackClaimOrigin
    fileprivate let claimId: UUID
    fileprivate let reservation: RuntimeOAuthAuthorizationReservation
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let ingressSource: RuntimeOAuthCallbackIngressSource
    fileprivate let callbackURL: URL
    fileprivate let callbackTrace: OperationTrace

    fileprivate init(
        flow: OAuthCredentialFlow,
        origin: RuntimeOAuthCallbackClaimOrigin,
        claimId: UUID,
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt,
        ingressSource: RuntimeOAuthCallbackIngressSource,
        callbackURL: URL,
        callbackTrace: OperationTrace
    ) {
        self.flow = flow
        self.origin = origin
        self.claimId = claimId
        self.reservation = reservation
        self.authorization = authorization
        self.ingressSource = ingressSource
        self.callbackURL = callbackURL
        self.callbackTrace = callbackTrace
    }

    package var ingress: RuntimeOAuthCallbackIngress {
        switch ingressSource {
        case .localListener: return .localListener
        case .customScheme: return .customScheme
        }
    }

    package func belongs(
        to reservation: RuntimeOAuthAuthorizationReservation
    ) -> Bool {
        self.reservation == reservation
    }

    package func ownsAuthorization(
        _ authorization: RuntimeOAuthAuthorizationReceipt
    ) -> Bool {
        self.authorization == authorization
    }

    package func ownsListenerLease(
        _ lease: RuntimeOAuthListenerLease
    ) -> Bool {
        switch ingressSource {
        case .localListener(let owned): return owned == lease
        case .customScheme: return false
        }
    }
}

package enum RuntimeOAuthCallbackClaimOutcome: Sendable {
    case claimed(RuntimeOAuthCallbackClaim)
    case currentAuthorizationRejected
    case superseded
}

package enum RuntimeOAuthCustomSchemeCallbackClaimOutcome: Sendable {
    case claimed(RuntimeOAuthCallbackClaim)
    case superseded
}

package enum RuntimeOAuthCallbackAbandonOutcome: Sendable {
    case ready(RuntimeOAuthAuthorizationReceipt)
    case authorizationRecovery(RuntimeOAuthAuthorizationRecoveryPending)
    case superseded(RuntimeOAuthCallbackSupersedingOwner)
}

package enum RuntimeOAuthCallbackPayload: Sendable, Equatable {
    case authorizationCode(
        code: SecretValue,
        returnedState: SecretValue
    )
    case credentialBundle(
        OAuthCredentialBundle,
        returnedState: SecretValue
    )
}

package struct RuntimeOAuthCallbackCommitReceipt: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    fileprivate let authorization: RuntimeOAuthAuthorizationReceipt
    fileprivate let callbackTrace: OperationTrace

    fileprivate init(
        authorization: RuntimeOAuthAuthorizationReceipt,
        callbackTrace: OperationTrace
    ) {
        flow = authorization.flow
        self.authorization = authorization
        self.callbackTrace = callbackTrace
    }
}

package enum RuntimeOAuthCallbackOutcome: Sendable {
    case notCommitted(UserVisibleFailure)
    case authorizationRecoveryPending(
        RuntimeOAuthAuthorizationRecoveryPending,
        failure: UserVisibleFailure
    )
    case committed(RuntimeOAuthCallbackCommitReceipt)
    case committedWithVisibilityFailure(
        receipt: RuntimeOAuthCallbackCommitReceipt,
        failure: UserVisibleFailure
    )
    case superseded(RuntimeOAuthCallbackSupersedingOwner)
}

package enum RuntimeOAuthCallbackSupersedingOwner: Sendable, Equatable {
    case none
    case transientAuthorizationOwner
    case ready(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt
    )
    case authorizationRecovery(
        reservation: RuntimeOAuthAuthorizationReservation,
        pending: RuntimeOAuthAuthorizationRecoveryPending
    )
}

package actor RuntimeOAuthListenerFailureSink {
    private weak var controller: RuntimeProfileWorkflowController?

    fileprivate init(controller: RuntimeProfileWorkflowController) {
        self.controller = controller
    }

    package func handle(
        _ failure: RuntimeOAuthListenerFailure,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome {
        guard let controller else { return .superseded }
        return await controller.handleOAuthListenerFailure(
            failure,
            authorization: authorization,
            lease: lease
        )
    }
}

package enum RuntimeOAuthListenerStartOutcome: Sendable, Equatable {
    case started
    case ownerShuttingDown
}

package enum RuntimeOAuthListenerStopOutcome: Sendable, Equatable {
    case stopped
    case ownerShuttingDown
}

package struct RuntimeOAuthPlatformPort: Sendable {
    package let startListener:
        @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt,
            RuntimeOAuthListenerLease
        ) async throws -> RuntimeOAuthListenerStartOutcome
    package let stopListenerIfOwned:
        @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt,
            RuntimeOAuthListenerLease
        ) async -> RuntimeOAuthListenerStopOutcome
    package let openAuthorization:
        @MainActor @Sendable (RuntimeOAuthAuthorizationReceipt) throws -> Void

    package init(
        startListener: @escaping @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt,
            RuntimeOAuthListenerLease
        ) async throws -> RuntimeOAuthListenerStartOutcome,
        stopListenerIfOwned: @escaping @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt,
            RuntimeOAuthListenerLease
        ) async -> RuntimeOAuthListenerStopOutcome,
        openAuthorization: @escaping @MainActor @Sendable (
            RuntimeOAuthAuthorizationReceipt
        ) throws -> Void
    ) {
        self.startListener = startListener
        self.stopListenerIfOwned = stopListenerIfOwned
        self.openAuthorization = openAuthorization
    }
}

package struct RuntimeOAuthPlatformFactory: Sendable {
    package let make: @Sendable (RuntimeOAuthListenerFailureSink)
        -> RuntimeOAuthPlatformPort

    package init(
        make: @escaping @Sendable (RuntimeOAuthListenerFailureSink)
            -> RuntimeOAuthPlatformPort
    ) {
        self.make = make
    }
}

package struct RuntimeOAuthCodec: Sendable {
    package let randomSecret: @Sendable (Int) throws -> SecretValue
    package let authorizationURL: @Sendable (
        RuntimeOAuthConfiguration,
        SecretValue,
        SecretValue
    ) throws -> URL
    package let callbackPayload: @Sendable (
        RuntimeOAuthConfiguration,
        URL
    ) throws -> RuntimeOAuthCallbackPayload
    package let callbackStateMatches: @Sendable (
        RuntimeOAuthConfiguration,
        URL,
        SecretValue
    ) -> Bool
    package let exchange: @Sendable (
        RuntimeOAuthConfiguration,
        SecretValue,
        SecretValue
    ) async throws -> OAuthCredentialBundle

    package init(
        randomSecret: @escaping @Sendable (Int) throws -> SecretValue,
        authorizationURL: @escaping @Sendable (
            RuntimeOAuthConfiguration,
            SecretValue,
            SecretValue
        ) throws -> URL,
        callbackPayload: @escaping @Sendable (
            RuntimeOAuthConfiguration,
            URL
        ) throws -> RuntimeOAuthCallbackPayload,
        callbackStateMatches: @escaping @Sendable (
            RuntimeOAuthConfiguration,
            URL,
            SecretValue
        ) -> Bool,
        exchange: @escaping @Sendable (
            RuntimeOAuthConfiguration,
            SecretValue,
            SecretValue
        ) async throws -> OAuthCredentialBundle
    ) {
        self.randomSecret = randomSecret
        self.authorizationURL = authorizationURL
        self.callbackPayload = callbackPayload
        self.callbackStateMatches = callbackStateMatches
        self.exchange = exchange
    }

    package static let live = RuntimeOAuthCodec(
        randomSecret: RuntimeOAuthCodecLive.randomSecret,
        authorizationURL: RuntimeOAuthCodecLive.authorizationURL,
        callbackPayload: RuntimeOAuthCodecLive.callbackPayload,
        callbackStateMatches: RuntimeOAuthCodecLive.callbackStateMatches,
        exchange: RuntimeOAuthCodecLive.exchange
    )
}

private enum RuntimeOAuthCodecLive {
    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
        }
    }

    static func randomSecret(byteCount: Int) throws -> SecretValue {
        do {
            return try OAuthPKCEPrimitives.randomSecret(byteCount: byteCount)
        } catch {
            throw RuntimeOAuthBoundaryError.randomGeneration
        }
    }

    static func authorizationURL(
        configuration: RuntimeOAuthConfiguration,
        state: SecretValue,
        verifier: SecretValue
    ) throws -> URL {
        guard var components = URLComponents(
            url: configuration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        let challenge = OAuthPKCEPrimitives.codeChallenge(for: verifier)
        let stateValue = state.use { $0 }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(
                name: "redirect_uri",
                value: configuration.redirectURI
            ),
            URLQueryItem(name: "state", value: stateValue),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(
                name: "scope",
                value: "openid profile email offline_access"
            )
        ]
        guard let url = components.url else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        return url
    }

    static func callbackStateMatches(
        configuration: RuntimeOAuthConfiguration,
        callbackURL: URL,
        expectedState: SecretValue
    ) -> Bool {
        guard routeMatches(configuration, callbackURL),
              let values = callbackValues(callbackURL),
              values.count(name: "state") == 1,
              let raw = values.first(name: "state"),
              let returned = SecretValue.validated(raw)
        else {
            return false
        }
        return returned.constantTimeEquals(expectedState)
    }

    static func callbackPayload(
        configuration: RuntimeOAuthConfiguration,
        callbackURL: URL
    ) throws -> RuntimeOAuthCallbackPayload {
        guard routeMatches(configuration, callbackURL),
              let values = callbackValues(callbackURL)
        else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        if values.count(name: "error") > 0 {
            guard values.count(name: "error") == 1 else {
                throw RuntimeOAuthBoundaryError.callbackMalformed
            }
            throw RuntimeOAuthBoundaryError.callbackDenied
        }
        let returnedState = try requiredSecret(
            "state",
            values: values
        )
        let code = try optionalSecret("code", values: values)
        let access = try optionalSecret("access_token", values: values)
        guard (code == nil) != (access == nil) else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        if let code {
            return .authorizationCode(
                code: code,
                returnedState: returnedState
            )
        }
        guard let access else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        let refresh = try optionalSecret("refresh_token", values: values)
        let id = try optionalSecret("id_token", values: values)
        let account = try accountID(
            configuration: configuration,
            access: access,
            id: id
        )
        return .credentialBundle(
            OAuthCredentialBundle(
                flow: configuration.flow,
                accessToken: access,
                refreshToken: refresh,
                idToken: id,
                accountID: account
            ),
            returnedState: returnedState
        )
    }

    static func exchange(
        configuration: RuntimeOAuthConfiguration,
        code: SecretValue,
        verifier: SecretValue
    ) async throws -> OAuthCredentialBundle {
        let fields = [
            ("grant_type", "authorization_code"),
            ("code", code.use { $0 }),
            ("redirect_uri", configuration.redirectURI),
            ("client_id", configuration.clientID),
            ("code_verifier", verifier.use { $0 })
        ]
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        request.httpBody = try formEncoded(fields)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeOAuthBoundaryError.nonHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            guard let status = ValidatedHTTPStatus.recognizingDiagnostic(
                http.statusCode
            ) else {
                throw RuntimeOAuthBoundaryError.nonHTTPResponse
            }
            throw RuntimeOAuthBoundaryError.httpStatus(status)
        }
        let decoded: TokenResponse
        let result: Result<TokenResponse, any Error> = await Task {
            try JSONDecoder().decode(TokenResponse.self, from: data)
        }.result
        switch result {
        case .success(let value):
            decoded = value
        case .failure:
            throw RuntimeOAuthBoundaryError.malformedTokenResponse
        }
        guard let access = SecretValue.validated(decoded.accessToken) else {
            throw RuntimeOAuthBoundaryError.malformedTokenResponse
        }
        let refresh = try validatedOptional(decoded.refreshToken)
        let id = try validatedOptional(decoded.idToken)
        let account = try accountID(
            configuration: configuration,
            access: access,
            id: id
        )
        return OAuthCredentialBundle(
            flow: configuration.flow,
            accessToken: access,
            refreshToken: refresh,
            idToken: id,
            accountID: account
        )
    }

    private struct CallbackValues {
        let items: [URLQueryItem]

        func count(name: String) -> Int {
            items.filter { $0.name == name }.count
        }

        func first(name: String) -> String? {
            items.first { $0.name == name }?.value
        }
    }

    private static func callbackValues(_ url: URL) -> CallbackValues? {
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        var items: [URLQueryItem] = []
        if let queryItems = components.queryItems {
            items.append(contentsOf: queryItems)
        }
        if let fragment = components.fragment, !fragment.isEmpty {
            guard let fragmentComponents = URLComponents(
                string: "agentloop://oauth/callback?\(fragment)"
            ), let fragmentItems = fragmentComponents.queryItems else {
                return nil
            }
            items.append(contentsOf: fragmentItems)
        }
        return CallbackValues(items: items)
    }

    private static func routeMatches(
        _ configuration: RuntimeOAuthConfiguration,
        _ callbackURL: URL
    ) -> Bool {
        guard let expected = URL(string: configuration.redirectURI) else {
            return false
        }
        return expected.scheme?.lowercased()
                == callbackURL.scheme?.lowercased()
            && expected.host()?.lowercased()
                == callbackURL.host()?.lowercased()
            && expected.port == callbackURL.port
            && expected.path == callbackURL.path
    }

    private static func requiredSecret(
        _ name: String,
        values: CallbackValues
    ) throws -> SecretValue {
        guard values.count(name: name) == 1,
              let raw = values.first(name: name),
              let value = SecretValue.validated(raw)
        else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        return value
    }

    private static func optionalSecret(
        _ name: String,
        values: CallbackValues
    ) throws -> SecretValue? {
        let count = values.count(name: name)
        if count == 0 { return nil }
        guard count == 1,
              let raw = values.first(name: name),
              let value = SecretValue.validated(raw)
        else {
            throw RuntimeOAuthBoundaryError.callbackMalformed
        }
        return value
    }

    private static func validatedOptional(
        _ raw: String?
    ) throws -> SecretValue? {
        guard let raw else { return nil }
        guard let value = SecretValue.validated(raw) else {
            throw RuntimeOAuthBoundaryError.malformedTokenResponse
        }
        return value
    }

    private static func accountID(
        configuration: RuntimeOAuthConfiguration,
        access: SecretValue,
        id: SecretValue?
    ) throws -> SecretValue? {
        guard configuration.requiresAccountID else { return nil }
        guard let id else {
            throw RuntimeOAuthBoundaryError.accountIDMissing
        }
        let raw = id.use { idToken in
            access.use { accessToken in
                OpenAIChatGPTAuth.chatGPTAccountID(
                    idToken: idToken,
                    accessToken: accessToken
                )
            }
        }
        guard let raw, let value = SecretValue.validated(raw) else {
            throw RuntimeOAuthBoundaryError.accountIDMissing
        }
        return value
    }

    private static func formEncoded(
        _ fields: [(String, String)]
    ) throws -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        var encoded: [String] = []
        for (key, value) in fields {
            guard let encodedKey = key.addingPercentEncoding(
                withAllowedCharacters: allowed
            ), let encodedValue = value.addingPercentEncoding(
                withAllowedCharacters: allowed
            ) else {
                throw RuntimeOAuthBoundaryError.formEncoding
            }
            encoded.append("\(encodedKey)=\(encodedValue)")
        }
        return Data(encoded.joined(separator: "&").utf8)
    }

}

package struct RuntimeWorkflowPorts: Sendable {
    package let refreshCatalog:
        @Sendable (String) async throws -> RuntimeCatalogRefreshReceipt
    package let testProvider:
        @Sendable (String, String?) async throws
            -> RuntimeProviderTestReceipt
    package let oauthPlatformFactory: RuntimeOAuthPlatformFactory
    package let oauthCodec: RuntimeOAuthCodec

    package init(
        refreshCatalog:
            @escaping @Sendable (String) async throws
                -> RuntimeCatalogRefreshReceipt,
        testProvider:
            @escaping @Sendable (String, String?) async throws
                -> RuntimeProviderTestReceipt,
        oauthPlatformFactory: RuntimeOAuthPlatformFactory,
        oauthCodec: RuntimeOAuthCodec
    ) {
        self.refreshCatalog = refreshCatalog
        self.testProvider = testProvider
        self.oauthPlatformFactory = oauthPlatformFactory
        self.oauthCodec = oauthCodec
    }

    package static func live(
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        resolver: RuntimeCredentialResolver,
        coordinator: CredentialBundleCoordinator,
        credentialAccounts: RuntimeCredentialAccounts,
        oauthPlatformFactory: RuntimeOAuthPlatformFactory,
        oauthCodec: RuntimeOAuthCodec = .live
    ) -> Self {
        let catalog = ModelCatalogService(defaults: defaults)
        return Self(
            refreshCatalog: { profileId in
                guard let profile = try database.runtimeProfile(id: profileId)
                else {
                    throw RuntimeProfileStoreError.profileNotFound(profileId)
                }
                let credential: String
                switch profile.kind {
                case .anthropicAPI, .openAIAPI:
                    guard let account = profile.credentialAccount,
                          !account.trimmingCharacters(
                            in: .whitespacesAndNewlines
                          ).isEmpty,
                          let value = try coordinator.synchronizedAccess.read(
                            account: account,
                            interactionPolicy: .allow
                          )
                    else {
                        throw RuntimeCredentialResolutionError(
                            .credentialAccountMissing
                        )
                    }
                    credential = value
                case .chatGPTOAuth, .cliCodex, .cliClaude:
                    credential = ""
                }
                let models = try await catalog.refresh(
                    profile: profile,
                    credential: credential
                )
                let verification = try database.readRuntimeWorkflowBundle()
                guard verification.profiles.contains(where: {
                    $0.id == profileId
                }) else {
                    throw RuntimeProfileReadError()
                }
                return RuntimeCatalogRefreshReceipt(
                    profileId: profileId,
                    models: models
                )
            },
            testProvider: { model, companionId in
                guard let provider = try resolver.provider(
                    model: model,
                    companionId: companionId
                ) else {
                    throw RuntimeCredentialResolutionError(
                        .credentialAccountMissing
                    )
                }
                var receivedTurn = false
                for try await event in provider.streamTurn(
                    system: "AgentLoop provider connectivity check.",
                    history: [APIMessage(role: .user, content: [
                        .text("Reply with one short acknowledgement.")
                    ])],
                    tools: [],
                    toolChoice: .auto,
                    maxTokens: 16
                ) {
                    if case .turn = event {
                        receivedTurn = true
                        break
                    }
                }
                guard receivedTurn else {
                    throw ProjectionContractError.invalidPayload
                }
                return RuntimeProviderTestReceipt(model: model)
            },
            oauthPlatformFactory: oauthPlatformFactory,
            oauthCodec: oauthCodec
        )
    }
}

fileprivate struct RuntimeOAuthDeferredListenerFailure:
    Sendable, Equatable
{
    let failure: UserVisibleFailure
    let lease: RuntimeOAuthListenerLease
}

fileprivate struct RuntimeOAuthPreparedMaterial: Sendable {
    let state: SecretValue
    let verifier: SecretValue
    let authorizationURL: URL
}

fileprivate struct RuntimeOAuthClaimContext: Sendable, Equatable {
    let reservation: RuntimeOAuthAuthorizationReservation
    let authorization: RuntimeOAuthAuthorizationReceipt
    let origin: RuntimeOAuthCallbackClaimOrigin
}

fileprivate enum RuntimeOAuthControllerOwner: Sendable, Equatable {
    case reserved(RuntimeOAuthAuthorizationReservation)
    case preparing(
        reservation: RuntimeOAuthAuthorizationReservation,
        attempt: UUID,
        authorization: RuntimeOAuthAuthorizationReceipt?,
        lease: RuntimeOAuthListenerLease?,
        deferredListenerFailure: RuntimeOAuthDeferredListenerFailure?
    )
    case postPreparation(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease?
    )
    case browserOpening(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease?,
        attempt: UUID
    )
    case ready(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease?
    )
    case authorizationRecovery(
        reservation: RuntimeOAuthAuthorizationReservation,
        pending: RuntimeOAuthAuthorizationRecoveryPending,
        attempt: UUID?
    )
    case callbackClaimAwaitingApp(
        reservation: RuntimeOAuthAuthorizationReservation,
        claim: RuntimeOAuthCallbackClaim
    )
    case callbackProcessing(
        reservation: RuntimeOAuthAuthorizationReservation,
        claim: RuntimeOAuthCallbackClaim,
        credentialCommitted: Bool
    )
}

package actor RuntimeProfileWorkflowController {
    private let database: AppDatabase
    private let defaults: ProfileScopedDefaults
    private let resolver: RuntimeCredentialResolver
    private let credentialAccounts: RuntimeCredentialAccounts
    private let credentialCoordinator: CredentialBundleCoordinator
    private let reporter: FailureReporter
    private let reads: RuntimeWorkflowReads
    private let ports: RuntimeWorkflowPorts
    private let traceFactory: OperationTraceFactory
    private var credentialAttachmentPending:
        RuntimeCredentialAttachmentPending?
    private var credentialAttachmentAttempt: UUID?
    private var oauthOwner: RuntimeOAuthControllerOwner?
    private var oauthPlatform: RuntimeOAuthPlatformPort?
    private var oauthListenerFailureRecordedLease:
        RuntimeOAuthListenerLease?

    package init(
        database: AppDatabase,
        defaults: ProfileScopedDefaults,
        resolver: RuntimeCredentialResolver,
        credentialAccounts: RuntimeCredentialAccounts,
        credentialCoordinator: CredentialBundleCoordinator,
        reporter: FailureReporter,
        reads: RuntimeWorkflowReads? = nil,
        ports: RuntimeWorkflowPorts,
        traceFactory: OperationTraceFactory = .live
    ) {
        self.database = database
        self.defaults = defaults
        self.resolver = resolver
        self.credentialAccounts = credentialAccounts
        self.credentialCoordinator = credentialCoordinator
        self.reporter = reporter
        self.reads = reads ?? .live(database: database)
        self.ports = ports
        self.traceFactory = traceFactory
    }

    package func load(
        interactionPolicy: KeychainInteractionPolicy,
        trace: OperationTrace
    ) async -> WorkflowLoadState<RuntimeWorkflowSnapshot> {
        let read = reads.load
        let resolver = resolver
        let defaults = defaults
        return await captureAsyncLoad(reporter: reporter, trace: trace) {
            let bundle = try read()
            let credentials = try resolver.presence(
                interactionPolicy: interactionPolicy
            )
            return Self.snapshot(
                bundle: bundle,
                credentials: credentials,
                defaults: defaults
            )
        }
    }

    package func saveProfile(
        _ profile: RuntimeProfileRecord,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<RuntimeProfileRecord> {
        switch captureSynchronous(reporter: reporter, trace: trace, {
            try database.saveRuntimeProfile(profile)
            return profile
        }) {
        case .failed(let failure):
            return .notCommitted(failure)
        case .value:
            break
        }
        switch captureSynchronous(reporter: reporter, trace: trace, {
            let bundle = try reads.load()
            guard bundle.profiles.contains(profile) else {
                throw RuntimeProfileReadError()
            }
            return profile
        }) {
        case .value(let visible):
            return .committed(visible)
        case .failed(let failure):
            return .committedWithVisibilityFailure(
                value: profile,
                failure: failure
            )
        }
    }

    package func deleteProfile(
        id: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<Void> {
        switch captureSynchronous(reporter: reporter, trace: trace, {
            try database.deleteRuntimeProfile(id: id)
        }) {
        case .failed(let failure):
            return .notCommitted(failure)
        case .value:
            break
        }
        switch captureSynchronous(reporter: reporter, trace: trace, {
            let bundle = try reads.load()
            guard !bundle.profiles.contains(where: { $0.id == id }) else {
                throw RuntimeProfileReadError()
            }
        }) {
        case .value:
            return .committed(())
        case .failed(let failure):
            return .committedWithVisibilityFailure(
                value: (),
                failure: failure
            )
        }
    }

    package func switchDefault(
        _ command: RuntimeProfileSwitchCommand,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<RuntimeProfileRecord> {
        let committed: RuntimeProfileRecord
        switch captureSynchronous(reporter: reporter, trace: trace, {
            let report = try database.reconciliationReport(
                switchingTo: command.profileId,
                defaults: defaults
            )
            let selected = report.filter { item in
                switch item.scope {
                case .companion(let id, _):
                    return command.inheritCompanionIds.contains(id)
                case .defaultModel:
                    return command.resetSettingScopes.contains("defaultModel")
                case .distillModel:
                    return command.resetSettingScopes.contains("distillModel")
                case .plannerModel:
                    return command.resetSettingScopes.contains("plannerModel")
                }
            }
            try database.applyReconciliation(
                items: selected,
                defaults: defaults
            )
            return try database.setDefaultProfileReturningRecord(
                id: command.profileId
            )
        }) {
        case .value(let value):
            committed = value
        case .failed(let failure):
            return .notCommitted(failure)
        }
        switch captureSynchronous(reporter: reporter, trace: trace, {
            let bundle = try reads.load()
            guard bundle.defaultProfile.id == committed.id else {
                throw RuntimeProfileReadError()
            }
            return committed
        }) {
        case .value(let visible):
            return .committed(visible)
        case .failed(let failure):
            return .committedWithVisibilityFailure(
                value: committed,
                failure: failure
            )
        }
    }

    package func setCredential(
        slot: RuntimeCredentialSlot,
        value: SecretValue,
        trace: OperationTrace
    ) async -> RuntimeCredentialSetOutcome {
        let account = credentialAccount(for: slot)
        switch captureSynchronous(reporter: reporter, trace: trace, {
            try credentialCoordinator.setRuntimeCredential(
                value,
                account: account
            )
        }) {
        case .failed(let failure):
            return .notCommitted(failure)
        case .value:
            break
        }
        let receipt = RuntimeCredentialSetReceipt(
            slot: slot,
            attachedProfileId: nil,
            trace: trace
        )
        if slot == .searchKey {
            return verifyCredentialSet(receipt, trace: trace)
        }
        let outcome = finishInitialCredentialAttachment(
            receipt,
            step: .resolveDefault,
            trace: trace
        )
        applyInitialCredentialAttachment(outcome)
        return outcome
    }

    package func retryCredentialAttachment(
        _ pending: RuntimeCredentialAttachmentPending
    ) async -> RuntimeCredentialAttachmentRecoveryOutcome {
        guard credentialAttachmentPending == pending,
              credentialAttachmentAttempt == nil
        else {
            return .superseded
        }
        let attempt = UUID()
        credentialAttachmentAttempt = attempt
        let trace = traceFactory.generated(
            operation: .runtimeCredentialSet,
            scope: pending.committed.trace.traceScope
        )
        let outcome = finishCredentialAttachmentRecovery(
            pending,
            trace: trace
        )
        guard credentialAttachmentPending == pending,
              credentialAttachmentAttempt == attempt
        else {
            return .superseded
        }
        credentialAttachmentAttempt = nil
        switch outcome {
        case .recovered, .recoveredWithVisibilityFailure:
            credentialAttachmentPending = nil
        case .pending(let next, _):
            credentialAttachmentPending = next
        case .superseded:
            break
        }
        return outcome
    }

    package func deleteCredential(
        slot: RuntimeCredentialSlot,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<Void> {
        switch captureSynchronous(reporter: reporter, trace: trace, {
            try credentialCoordinator.deleteRuntimeCredential(
                account: credentialAccount(for: slot)
            )
        }) {
        case .failed(let failure):
            return .notCommitted(failure)
        case .value:
            break
        }
        if slot == .apiKey {
            credentialAttachmentPending = nil
            credentialAttachmentAttempt = nil
        }
        switch captureSynchronous(reporter: reporter, trace: trace, {
            _ = try strictSnapshot()
        }) {
        case .value:
            return .committed(())
        case .failed(let failure):
            return .committedWithVisibilityFailure(
                value: (),
                failure: failure
            )
        }
    }

    package func refreshCatalog(
        profileId: String,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<RuntimeCatalogRefreshReceipt> {
        let refresh = ports.refreshCatalog
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try await refresh(profileId))
        }
    }

    package func testProvider(
        model: String,
        companionId: String?,
        trace: OperationTrace
    ) async -> OperationCommitOutcome<RuntimeProviderTestReceipt> {
        let test = ports.testProvider
        return await captureAsyncOperation(
            reporter: reporter,
            trace: trace,
            onFailure: { .notCommitted($0) }
        ) {
            .committed(try await test(model, companionId))
        }
    }

    package func reserveOAuthAuthorizationAttempt(
        flow: OAuthCredentialFlow,
        trace: OperationTrace
    ) async -> RuntimeOAuthAuthorizationReservationOutcome {
        guard Self.isOAuthTrace(trace, operation: .oauthAuthorization) else {
            return .rejected(reporter.capture(
                TraceIdentityConflictError(),
                trace: trace
            ))
        }
        guard oauthOwner == nil else {
            return .rejected(reporter.capture(
                RuntimeOAuthBoundaryError.authorizationAlreadyActive,
                trace: trace
            ))
        }
        oauthListenerFailureRecordedLease = nil
        let reservation = RuntimeOAuthAuthorizationReservation(
            flow: flow,
            reservationId: UUID(),
            trace: trace
        )
        oauthOwner = .reserved(reservation)
        return .reserved(reservation)
    }

    package func prepareOAuthAuthorization(
        _ command: RuntimeOAuthAuthorizationCommand,
        reservation: RuntimeOAuthAuthorizationReservation
    ) async -> RuntimeOAuthAuthorizationOutcome {
        guard command.configuration.flow == reservation.flow,
              oauthOwner == .reserved(reservation)
        else {
            return .superseded
        }
        let attempt = UUID()
        oauthOwner = .preparing(
            reservation: reservation,
            attempt: attempt,
            authorization: nil,
            lease: nil,
            deferredListenerFailure: nil
        )
        let platform = oauthPlatformPort()
        let codec = ports.oauthCodec
        let materialResult = captureSynchronous(
            reporter: reporter,
            trace: reservation.trace
        ) {
            let state = try codec.randomSecret(24)
            let verifier = try codec.randomSecret(32)
            return RuntimeOAuthPreparedMaterial(
                state: state,
                verifier: verifier,
                authorizationURL: try codec.authorizationURL(
                    command.configuration,
                    state,
                    verifier
                )
            )
        }
        let material: RuntimeOAuthPreparedMaterial
        switch materialResult {
        case .value(let value):
            material = value
        case .failed(let failure):
            clearPreparingOwner(
                reservation: reservation,
                attempt: attempt
            )
            return .notCommitted(failure)
        }
        guard matchesPreparing(
            reservation: reservation,
            attempt: attempt
        ) else {
            return .superseded
        }
        let authorization = RuntimeOAuthAuthorizationReceipt(
            configuration: command.configuration,
            url: OAuthAuthorizationURL(material.authorizationURL),
            expectedState: material.state,
            trace: reservation.trace,
            requiresLocalListener:
                command.configuration.requiresLocalListener
        )
        let lease: RuntimeOAuthListenerLease?
        if authorization.requiresLocalListener {
            let value = RuntimeOAuthListenerLease(
                flow: authorization.flow,
                reservationId: reservation.reservationId,
                leaseId: UUID()
            )
            oauthListenerFailureRecordedLease = nil
            lease = value
            oauthOwner = .preparing(
                reservation: reservation,
                attempt: attempt,
                authorization: authorization,
                lease: value,
                deferredListenerFailure: nil
            )
            let startResult: Result<RuntimeOAuthListenerStartOutcome, any Error>
                = await Task { @MainActor in
                    try await platform.startListener(authorization, value)
                }.result
            guard matchesPreparing(
                reservation: reservation,
                attempt: attempt,
                authorization: authorization,
                lease: value
            ) else {
                return .superseded
            }
            switch startResult {
            case .success(.started):
                break
            case .success(.ownerShuttingDown):
                clearPreparingOwner(
                    reservation: reservation,
                    attempt: attempt
                )
                return .superseded
            case .failure(let error):
                let failure = reporter.capture(
                    error,
                    trace: reservation.trace
                )
                _ = await platform.stopListenerIfOwned(
                    authorization,
                    value
                )
                clearPreparingOwner(
                    reservation: reservation,
                    attempt: attempt
                )
                return .notCommitted(failure)
            }
        } else {
            lease = nil
            oauthOwner = .preparing(
                reservation: reservation,
                attempt: attempt,
                authorization: authorization,
                lease: nil,
                deferredListenerFailure: nil
            )
        }
        let preparationOutcome = await credentialCoordinator
            .commitAuthorizationPreparation(
                flow: authorization.flow,
                state: material.state,
                verifier: material.verifier,
                accounts: credentialAccounts.oauth,
                interactionPolicy: .allow
            )
        guard case .preparing(
            let currentReservation,
            let currentAttempt,
            let currentAuthorization?,
            let currentLease,
            let deferred
        ) = oauthOwner,
        currentReservation == reservation,
        currentAttempt == attempt,
        currentAuthorization == authorization,
        currentLease == lease
        else {
            return .superseded
        }
        switch preparationOutcome {
        case .committed:
            if let deferred {
                let pending = RuntimeOAuthAuthorizationRecoveryPending(
                    authorization: authorization,
                    stage: .listenerThenBrowser,
                    listenerLease: deferred.lease
                )
                oauthOwner = .authorizationRecovery(
                    reservation: reservation,
                    pending: pending,
                    attempt: nil
                )
                return .recoveryPending(
                    pending,
                    failure: deferred.failure
                )
            }
            oauthOwner = .postPreparation(
                reservation: reservation,
                authorization: authorization,
                lease: lease
            )
            return .prepared(authorization)
        case .failed(let error):
            let failure = reporter.capture(error, trace: reservation.trace)
            let stopped = await stopOAuthListener(
                platform: platform,
                authorization: authorization,
                lease: lease
            )
            clearPreparingOwner(
                reservation: reservation,
                attempt: attempt
            )
            return stopped ? .notCommitted(failure) : .superseded
        case .unavailable(let error):
            let failure = reporter.capture(error, trace: reservation.trace)
            let stopped = await stopOAuthListener(
                platform: platform,
                authorization: authorization,
                lease: lease
            )
            clearPreparingOwner(
                reservation: reservation,
                attempt: attempt
            )
            return stopped ? .notCommitted(failure) : .superseded
        }
    }

    package func openOAuthAuthorization(
        _ command: RuntimeOAuthAuthorizationOpenCommand
    ) async -> RuntimeOAuthAuthorizationOpenOutcome {
        let reservation = command.reservation
        let authorization = command.authorization
        guard command.flow == reservation.flow,
              authorization.flow == reservation.flow
        else {
            return .superseded
        }
        let lease: RuntimeOAuthListenerLease?
        switch oauthOwner {
        case .postPreparation(
            let currentReservation,
            let currentAuthorization,
            let currentLease
        ) where currentReservation == reservation
            && currentAuthorization == authorization:
            lease = currentLease
        case .authorizationRecovery(
            let currentReservation,
            let pending,
            _
        ) where currentReservation == reservation
            && pending.ownsAuthorization(authorization):
            return .retainedRecovery(pending)
        case .ready(
            let currentReservation,
            let currentAuthorization,
            _
        ) where currentReservation == reservation
            && currentAuthorization == authorization:
            return .opened(authorization)
        default:
            return .superseded
        }
        let attempt = UUID()
        oauthOwner = .browserOpening(
            reservation: reservation,
            authorization: authorization,
            lease: lease,
            attempt: attempt
        )
        let platform = oauthPlatformPort()
        let openResult: Result<Void, any Error> = await Task { @MainActor in
            try platform.openAuthorization(authorization)
        }.result
        switch openResult {
        case .success:
            guard oauthOwner == .browserOpening(
                reservation: reservation,
                authorization: authorization,
                lease: lease,
                attempt: attempt
            ) else {
                if let pending = currentRecovery(
                    reservation: reservation,
                    authorization: authorization
                ) {
                    return .retainedRecovery(pending)
                }
                return .superseded
            }
            oauthOwner = .ready(
                reservation: reservation,
                authorization: authorization,
                lease: lease
            )
            return .opened(authorization)
        case .failure(let error):
            let failure = reporter.capture(error, trace: authorization.trace)
            guard oauthOwner == .browserOpening(
                reservation: reservation,
                authorization: authorization,
                lease: lease,
                attempt: attempt
            ) else {
                if let pending = currentRecovery(
                    reservation: reservation,
                    authorization: authorization
                ) {
                    return .recoveryPending(pending, failure: failure)
                }
                return .superseded
            }
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .browserReopen,
                listenerLease: lease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: pending,
                attempt: nil
            )
            return .recoveryPending(pending, failure: failure)
        }
    }

    package func rejectOAuthAuthorizationAttempt(
        _ reservation: RuntimeOAuthAuthorizationReservation,
        trace: OperationTrace
    ) async -> RuntimeOAuthAuthorizationRejectionOutcome {
        guard Self.isOAuthTrace(trace, operation: .oauthAuthorization),
              ownerReservation == reservation
        else {
            return .superseded
        }
        return .rejected(reporter.capture(
            RuntimeOAuthBoundaryError.authorizationAlreadyActive,
            trace: trace
        ))
    }

    package func handleOAuthListenerFailure(
        _ failure: RuntimeOAuthListenerFailure,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome {
        guard authorization.flow == lease.flow,
              leaseMatchesCurrentOwner(
                authorization: authorization,
                lease: lease
              )
        else {
            return .superseded
        }
        if listenerRecoveryAlreadyRecorded(
            authorization: authorization,
            lease: lease
        ) {
            return .superseded
        }
        oauthListenerFailureRecordedLease = lease
        let trace = traceFactory.generated(
            operation: .oauthAuthorization,
            scope: authorization.trace.traceScope
        )
        let visible = reporter.capture(failure, trace: trace)
        switch oauthOwner {
        case .preparing(
            let reservation,
            let attempt,
            let currentAuthorization?,
            let currentLease?,
            nil
        ) where currentAuthorization == authorization
            && currentLease == lease:
            oauthOwner = .preparing(
                reservation: reservation,
                attempt: attempt,
                authorization: authorization,
                lease: lease,
                deferredListenerFailure:
                    RuntimeOAuthDeferredListenerFailure(
                        failure: visible,
                        lease: lease
                    )
            )
            return .deferredToPreparation(failure: visible)
        case .postPreparation(
            let reservation,
            let currentAuthorization,
            _
        ) where currentAuthorization == authorization:
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .listenerThenBrowser,
                listenerLease: lease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: pending,
                attempt: nil
            )
            return .pending(pending, failure: visible)
        case .browserOpening(
            let reservation,
            let currentAuthorization,
            _, _
        ) where currentAuthorization == authorization:
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .listenerThenBrowser,
                listenerLease: lease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: pending,
                attempt: nil
            )
            return .pending(pending, failure: visible)
        case .ready(
            let reservation,
            let currentAuthorization,
            _
        ) where currentAuthorization == authorization:
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .listenerRestart,
                listenerLease: lease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: pending,
                attempt: nil
            )
            return .pending(pending, failure: visible)
        case .authorizationRecovery(
            let reservation,
            let current,
            _
        ) where current.ownsAuthorization(authorization):
            let pending = mergedListenerRecovery(
                current,
                lease: lease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: pending,
                attempt: nil
            )
            return .pending(pending, failure: visible)
        case .callbackClaimAwaitingApp(
            let reservation,
            let claim
        ) where claim.ownsAuthorization(authorization):
            let updated = claimMergingListenerRecovery(
                claim,
                lease: lease
            )
            oauthOwner = .callbackClaimAwaitingApp(
                reservation: reservation,
                claim: updated
            )
            return .deferredToCallback(failure: visible)
        case .callbackProcessing(
            let reservation,
            let claim,
            let committed
        ) where claim.ownsAuthorization(authorization):
            guard !committed else {
                return .deferredToCallback(failure: visible)
            }
            let updated = claimMergingListenerRecovery(
                claim,
                lease: lease
            )
            oauthOwner = .callbackProcessing(
                reservation: reservation,
                claim: updated,
                credentialCommitted: committed
            )
            return .deferredToCallback(failure: visible)
        default:
            return .superseded
        }
    }

    package func retryOAuthAuthorization(
        _ pending: RuntimeOAuthAuthorizationRecoveryPending
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome {
        guard case .authorizationRecovery(
            let reservation,
            let current,
            nil
        ) = oauthOwner,
        current == pending
        else {
            return .superseded
        }
        let attempt = UUID()
        let trace = traceFactory.generated(
            operation: .oauthAuthorization,
            scope: pending.authorization.trace.traceScope
        )
        oauthOwner = .authorizationRecovery(
            reservation: reservation,
            pending: pending,
            attempt: attempt
        )
        return await performOAuthAuthorizationRecovery(
            reservation: reservation,
            pending: pending,
            attempt: attempt,
            trace: trace
        )
    }

    package func claimOAuthCallback(
        _ command: RuntimeOAuthCallbackCommand,
        trace: OperationTrace
    ) async -> RuntimeOAuthCallbackClaimOutcome {
        guard Self.isOAuthTrace(
            trace,
            operation: .oauthCallbackExchange
        ), command.listenerLease.belongs(to: command.reservation)
        else {
            return .superseded
        }
        let suppliedAuthorization: RuntimeOAuthAuthorizationReceipt
        switch command.owner {
        case .authorization(let authorization):
            suppliedAuthorization = authorization
        case .recovery(let pending):
            suppliedAuthorization = pending.authorization
        }
        guard let context = physicalClaimContext(
            reservation: command.reservation,
            authorization: suppliedAuthorization,
            lease: command.listenerLease
        ) else {
            return .superseded
        }
        guard ports.oauthCodec.callbackStateMatches(
            context.authorization.configuration,
            command.callbackURL,
            context.authorization.expectedState
        ) else {
            return .currentAuthorizationRejected
        }
        let claim = RuntimeOAuthCallbackClaim(
            flow: context.authorization.flow,
            origin: context.origin,
            claimId: UUID(),
            reservation: context.reservation,
            authorization: context.authorization,
            ingressSource: .localListener(command.listenerLease),
            callbackURL: command.callbackURL,
            callbackTrace: trace
        )
        oauthOwner = .callbackClaimAwaitingApp(
            reservation: context.reservation,
            claim: claim
        )
        return .claimed(claim)
    }

    package func claimOAuthCustomSchemeCallback(
        _ command: RuntimeOAuthCustomSchemeCallbackCommand,
        trace: OperationTrace
    ) async -> RuntimeOAuthCustomSchemeCallbackClaimOutcome {
        guard Self.isOAuthTrace(
            trace,
            operation: .oauthCallbackExchange
        ), let context = customSchemeClaimContext(),
        context.authorization.flow == .generic,
        !context.authorization.requiresLocalListener,
        ports.oauthCodec.callbackStateMatches(
            context.authorization.configuration,
            command.callbackURL,
            context.authorization.expectedState
        ) else {
            return .superseded
        }
        let claim = RuntimeOAuthCallbackClaim(
            flow: context.authorization.flow,
            origin: context.origin,
            claimId: UUID(),
            reservation: context.reservation,
            authorization: context.authorization,
            ingressSource: .customScheme,
            callbackURL: command.callbackURL,
            callbackTrace: trace
        )
        oauthOwner = .callbackClaimAwaitingApp(
            reservation: context.reservation,
            claim: claim
        )
        return .claimed(claim)
    }

    package func handleOAuthCallback(
        _ claim: RuntimeOAuthCallbackClaim
    ) async -> RuntimeOAuthCallbackOutcome {
        guard oauthOwner == .callbackClaimAwaitingApp(
            reservation: claim.reservation,
            claim: claim
        ) else {
            return .superseded(sealedOAuthOwner())
        }
        oauthOwner = .callbackProcessing(
            reservation: claim.reservation,
            claim: claim,
            credentialCommitted: false
        )
        let preparationResult: Result<OAuthAuthorizationPreparation, any Error>
            = await Task {
                try await credentialCoordinator.readAuthorizationPreparation(
                    flow: claim.flow,
                    accounts: credentialAccounts.oauth,
                    interactionPolicy: .allow
                )
            }.result
        guard isProcessing(claim, credentialCommitted: false) else {
            return .superseded(sealedOAuthOwner())
        }
        let preparation: OAuthAuthorizationPreparation
        switch preparationResult {
        case .success(let value):
            preparation = value
        case .failure(let error):
            return callbackFailure(error, claim: claim)
        }
        guard preparation.flow == claim.flow,
              preparation.state.constantTimeEquals(
                claim.authorization.expectedState
              )
        else {
            return callbackFailure(
                RuntimeOAuthBoundaryError.stateMismatch,
                claim: claim
            )
        }
        let payloadResult: Result<RuntimeOAuthCallbackPayload, any Error> =
            await Task {
                try ports.oauthCodec.callbackPayload(
                    claim.authorization.configuration,
                    claim.callbackURL
                )
            }.result
        guard isProcessing(claim, credentialCommitted: false) else {
            return .superseded(sealedOAuthOwner())
        }
        let payload: RuntimeOAuthCallbackPayload
        switch payloadResult {
        case .success(let value):
            payload = value
        case .failure(let error):
            return callbackFailure(error, claim: claim)
        }
        let bundle: OAuthCredentialBundle
        let returnedState: SecretValue
        switch payload {
        case .credentialBundle(let value, let state):
            bundle = value
            returnedState = state
        case .authorizationCode(let code, let state):
            returnedState = state
            let exchangeResult: Result<OAuthCredentialBundle, any Error> =
                await Task {
                    try await ports.oauthCodec.exchange(
                        claim.authorization.configuration,
                        code,
                        preparation.verifier
                    )
                }.result
            guard isProcessing(claim, credentialCommitted: false) else {
                return .superseded(sealedOAuthOwner())
            }
            switch exchangeResult {
            case .success(let value):
                bundle = value
            case .failure(let error):
                return callbackFailure(error, claim: claim)
            }
        }
        guard returnedState.constantTimeEquals(
            claim.authorization.expectedState
        ), bundle.flow == claim.flow,
        !claim.authorization.configuration.requiresAccountID
            || bundle.accountID != nil
        else {
            return callbackFailure(
                RuntimeOAuthBoundaryError.stateMismatch,
                claim: claim
            )
        }
        let commitResult: Result<CredentialMutationReceipt, any Error> =
            await Task {
                try await credentialCoordinator.commitInitial(
                    bundle,
                    basedOn: preparation,
                    interactionPolicy: .allow
                )
            }.result
        guard isProcessing(claim, credentialCommitted: false) else {
            return .superseded(sealedOAuthOwner())
        }
        let committedClaim: RuntimeOAuthCallbackClaim
        switch commitResult {
        case .failure(let error):
            return callbackFailure(error, claim: claim)
        case .success:
            guard let current = currentProcessingClaim(
                claim,
                credentialCommitted: false
            ) else {
                return .superseded(sealedOAuthOwner())
            }
            committedClaim = current
            oauthOwner = .callbackProcessing(
                reservation: current.reservation,
                claim: current,
                credentialCommitted: true
            )
        }
        var cleanupClaim = committedClaim
        if case .localListener(let lease) = cleanupClaim.ingressSource {
            let stopped = await oauthPlatformPort().stopListenerIfOwned(
                cleanupClaim.authorization,
                lease
            )
            guard let current = currentProcessingClaim(
                cleanupClaim,
                credentialCommitted: true
            ) else {
                return .superseded(sealedOAuthOwner())
            }
            cleanupClaim = current
            if stopped == .ownerShuttingDown {
                clearOAuthOwner()
                return .superseded(.none)
            }
        }
        let visibility = captureSynchronous(
            reporter: reporter,
            trace: cleanupClaim.callbackTrace
        ) {
            _ = try strictSnapshot()
        }
        guard let current = currentProcessingClaim(
            cleanupClaim,
            credentialCommitted: true
        ) else {
            return .superseded(sealedOAuthOwner())
        }
        let receipt = RuntimeOAuthCallbackCommitReceipt(
            authorization: current.authorization,
            callbackTrace: current.callbackTrace
        )
        clearOAuthOwner()
        switch visibility {
        case .value:
            return .committed(receipt)
        case .failed(let failure):
            return .committedWithVisibilityFailure(
                receipt: receipt,
                failure: failure
            )
        }
    }

    package func abandonOAuthCallbackClaim(
        _ claim: RuntimeOAuthCallbackClaim
    ) async -> RuntimeOAuthCallbackAbandonOutcome {
        guard oauthOwner == .callbackClaimAwaitingApp(
            reservation: claim.reservation,
            claim: claim
        ) else {
            return .superseded(sealedOAuthOwner())
        }
        switch claim.origin {
        case .ready(let authorization):
            if case .localListener(let lease) = claim.ingressSource {
                let pending = RuntimeOAuthAuthorizationRecoveryPending(
                    authorization: authorization,
                    stage: .listenerRestart,
                    listenerLease: lease
                )
                oauthOwner = .authorizationRecovery(
                    reservation: claim.reservation,
                    pending: pending,
                    attempt: nil
                )
                return .authorizationRecovery(pending)
            }
            oauthOwner = .ready(
                reservation: claim.reservation,
                authorization: authorization,
                lease: nil
            )
            return .ready(authorization)
        case .authorizationRecovery(let pending):
            let restored: RuntimeOAuthAuthorizationRecoveryPending
            switch claim.ingressSource {
            case .localListener(let lease):
                restored = mergedListenerRecovery(
                    pending,
                    lease: lease
                )
            case .customScheme:
                restored = pending
            }
            oauthOwner = .authorizationRecovery(
                reservation: claim.reservation,
                pending: restored,
                attempt: nil
            )
            return .authorizationRecovery(restored)
        }
    }

    private func oauthPlatformPort() -> RuntimeOAuthPlatformPort {
        if let oauthPlatform {
            return oauthPlatform
        }
        let sink = RuntimeOAuthListenerFailureSink(controller: self)
        let platform = ports.oauthPlatformFactory.make(sink)
        oauthPlatform = platform
        return platform
    }

    private var ownerReservation: RuntimeOAuthAuthorizationReservation? {
        switch oauthOwner {
        case .reserved(let reservation),
             .preparing(let reservation, _, _, _, _),
             .postPreparation(let reservation, _, _),
             .browserOpening(let reservation, _, _, _),
             .ready(let reservation, _, _),
             .authorizationRecovery(let reservation, _, _),
             .callbackClaimAwaitingApp(let reservation, _),
             .callbackProcessing(let reservation, _, _):
            return reservation
        case nil:
            return nil
        }
    }

    private static func isOAuthTrace(
        _ trace: OperationTrace,
        operation: FailureOperation
    ) -> Bool {
        trace.operation == operation
            && trace.traceScope == .fixed(.oauth)
    }

    private func matchesPreparing(
        reservation: RuntimeOAuthAuthorizationReservation,
        attempt: UUID,
        authorization: RuntimeOAuthAuthorizationReceipt? = nil,
        lease: RuntimeOAuthListenerLease? = nil
    ) -> Bool {
        guard case .preparing(
            let currentReservation,
            let currentAttempt,
            let currentAuthorization,
            let currentLease,
            _
        ) = oauthOwner else {
            return false
        }
        if currentReservation != reservation || currentAttempt != attempt {
            return false
        }
        if let authorization, currentAuthorization != authorization {
            return false
        }
        if let lease, currentLease != lease {
            return false
        }
        return true
    }

    private func clearPreparingOwner(
        reservation: RuntimeOAuthAuthorizationReservation,
        attempt: UUID
    ) {
        if matchesPreparing(reservation: reservation, attempt: attempt) {
            clearOAuthOwner()
        }
    }

    private func clearOAuthOwner() {
        oauthOwner = nil
        oauthListenerFailureRecordedLease = nil
    }

    private func stopOAuthListener(
        platform: RuntimeOAuthPlatformPort,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease?
    ) async -> Bool {
        guard let lease else { return true }
        return await platform.stopListenerIfOwned(
            authorization,
            lease
        ) == .stopped
    }

    private func currentRecovery(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt
    ) -> RuntimeOAuthAuthorizationRecoveryPending? {
        guard case .authorizationRecovery(
            let currentReservation,
            let pending,
            _
        ) = oauthOwner,
        currentReservation == reservation,
        pending.ownsAuthorization(authorization)
        else {
            return nil
        }
        return pending
    }

    private func leaseMatchesCurrentOwner(
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) -> Bool {
        switch oauthOwner {
        case .preparing(_, _, let currentAuthorization?, let currentLease?, _):
            return currentAuthorization == authorization
                && currentLease == lease
        case .postPreparation(_, let currentAuthorization, let currentLease?),
             .browserOpening(
                _, let currentAuthorization, let currentLease?, _
             ),
             .ready(_, let currentAuthorization, let currentLease?):
            return currentAuthorization == authorization
                && currentLease == lease
        case .authorizationRecovery(_, let pending, _):
            return pending.ownsAuthorization(authorization)
                && pending.ownsListenerLease(lease)
        case .callbackClaimAwaitingApp(_, let claim),
             .callbackProcessing(_, let claim, _):
            return claim.ownsAuthorization(authorization)
                && claim.ownsListenerLease(lease)
        default:
            return false
        }
    }

    private func listenerRecoveryAlreadyRecorded(
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) -> Bool {
        authorization.flow == lease.flow
            && oauthListenerFailureRecordedLease == lease
    }

    private func mergedListenerRecovery(
        _ pending: RuntimeOAuthAuthorizationRecoveryPending,
        lease: RuntimeOAuthListenerLease
    ) -> RuntimeOAuthAuthorizationRecoveryPending {
        let stage: RuntimeOAuthAuthorizationRecoveryStage
        switch pending.stage {
        case .browserReopen:
            stage = .listenerThenBrowser
        case .listenerRestart, .listenerThenBrowser:
            stage = pending.stage
        }
        return RuntimeOAuthAuthorizationRecoveryPending(
            authorization: pending.authorization,
            stage: stage,
            listenerLease: lease
        )
    }

    private func claimMergingListenerRecovery(
        _ claim: RuntimeOAuthCallbackClaim,
        lease: RuntimeOAuthListenerLease
    ) -> RuntimeOAuthCallbackClaim {
        let pending: RuntimeOAuthAuthorizationRecoveryPending
        switch claim.origin {
        case .ready(let authorization):
            pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .listenerRestart,
                listenerLease: lease
            )
        case .authorizationRecovery(let current):
            pending = mergedListenerRecovery(current, lease: lease)
        }
        return RuntimeOAuthCallbackClaim(
            flow: claim.flow,
            origin: .authorizationRecovery(pending),
            claimId: claim.claimId,
            reservation: claim.reservation,
            authorization: claim.authorization,
            ingressSource: claim.ingressSource,
            callbackURL: claim.callbackURL,
            callbackTrace: claim.callbackTrace
        )
    }

    private func performOAuthAuthorizationRecovery(
        reservation: RuntimeOAuthAuthorizationReservation,
        pending: RuntimeOAuthAuthorizationRecoveryPending,
        attempt: UUID,
        trace: OperationTrace
    ) async -> RuntimeOAuthAuthorizationRecoveryOutcome {
        let platform = oauthPlatformPort()
        var current = pending
        switch pending.stage {
        case .listenerRestart, .listenerThenBrowser:
            guard let oldLease = pending.listenerLease else {
                let failure = reporter.capture(
                    RuntimeOAuthListenerFailure.cancelled,
                    trace: trace
                )
                oauthOwner = .authorizationRecovery(
                    reservation: reservation,
                    pending: pending,
                    attempt: nil
                )
                return .pending(pending, failure: failure)
            }
            let stop = await platform.stopListenerIfOwned(
                pending.authorization,
                oldLease
            )
            guard oauthOwner == .authorizationRecovery(
                reservation: reservation,
                pending: pending,
                attempt: attempt
            ) else {
                return .superseded
            }
            guard stop == .stopped else {
                clearOAuthOwner()
                return .superseded
            }
            let newLease = RuntimeOAuthListenerLease(
                flow: pending.flow,
                reservationId: reservation.reservationId,
                leaseId: UUID()
            )
            oauthListenerFailureRecordedLease = nil
            current = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: pending.authorization,
                stage: pending.stage,
                listenerLease: newLease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: current,
                attempt: attempt
            )
            let listenerAuthorization = current.authorization
            let start: Result<RuntimeOAuthListenerStartOutcome, any Error> =
                await Task { @MainActor in
                    try await platform.startListener(
                        listenerAuthorization,
                        newLease
                    )
                }.result
            guard oauthOwner == .authorizationRecovery(
                reservation: reservation,
                pending: current,
                attempt: attempt
            ) else {
                return .superseded
            }
            switch start {
            case .success(.started):
                break
            case .success(.ownerShuttingDown):
                clearOAuthOwner()
                return .superseded
            case .failure(let error):
                oauthListenerFailureRecordedLease = newLease
                let failure = reporter.capture(error, trace: trace)
                oauthOwner = .authorizationRecovery(
                    reservation: reservation,
                    pending: current,
                    attempt: nil
                )
                return .pending(current, failure: failure)
            }
            if pending.stage == .listenerRestart {
                oauthOwner = .ready(
                    reservation: reservation,
                    authorization: pending.authorization,
                    lease: newLease
                )
                return .ready(pending.authorization)
            }
            current = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: pending.authorization,
                stage: .browserReopen,
                listenerLease: newLease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: current,
                attempt: attempt
            )
        case .browserReopen:
            break
        }
        let opened: Result<Void, any Error> = await Task { @MainActor in
            try platform.openAuthorization(current.authorization)
        }.result
        guard oauthOwner == .authorizationRecovery(
            reservation: reservation,
            pending: current,
            attempt: attempt
        ) else {
            return .superseded
        }
        switch opened {
        case .success:
            oauthOwner = .ready(
                reservation: reservation,
                authorization: current.authorization,
                lease: current.listenerLease
            )
            return .ready(current.authorization)
        case .failure(let error):
            let failure = reporter.capture(error, trace: trace)
            let next = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: current.authorization,
                stage: .browserReopen,
                listenerLease: current.listenerLease
            )
            oauthOwner = .authorizationRecovery(
                reservation: reservation,
                pending: next,
                attempt: nil
            )
            return .pending(next, failure: failure)
        }
    }

    private func physicalClaimContext(
        reservation: RuntimeOAuthAuthorizationReservation,
        authorization: RuntimeOAuthAuthorizationReceipt,
        lease: RuntimeOAuthListenerLease
    ) -> RuntimeOAuthClaimContext? {
        switch oauthOwner {
        case .postPreparation(
            let currentReservation,
            let currentAuthorization,
            let currentLease?
        ) where currentReservation == reservation
            && currentAuthorization == authorization
            && currentLease == lease:
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .browserReopen,
                listenerLease: lease
            )
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: authorization,
                origin: .authorizationRecovery(pending)
            )
        case .browserOpening(
            let currentReservation,
            let currentAuthorization,
            let currentLease?, _
        ) where currentReservation == reservation
            && currentAuthorization == authorization
            && currentLease == lease:
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .browserReopen,
                listenerLease: lease
            )
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: authorization,
                origin: .authorizationRecovery(pending)
            )
        case .ready(
            let currentReservation,
            let currentAuthorization,
            let currentLease?
        ) where currentReservation == reservation
            && currentAuthorization == authorization
            && currentLease == lease:
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: authorization,
                origin: .ready(authorization)
            )
        case .authorizationRecovery(
            let currentReservation,
            let pending,
            _
        ) where currentReservation == reservation
            && pending.ownsAuthorization(authorization)
            && pending.ownsListenerLease(lease):
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: authorization,
                origin: .authorizationRecovery(pending)
            )
        default:
            return nil
        }
    }

    private func customSchemeClaimContext() -> RuntimeOAuthClaimContext? {
        switch oauthOwner {
        case .postPreparation(
            let reservation,
            let authorization,
            nil
        ), .browserOpening(
            let reservation,
            let authorization,
            nil, _
        ):
            let pending = RuntimeOAuthAuthorizationRecoveryPending(
                authorization: authorization,
                stage: .browserReopen,
                listenerLease: nil
            )
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: authorization,
                origin: .authorizationRecovery(pending)
            )
        case .ready(let reservation, let authorization, nil):
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: authorization,
                origin: .ready(authorization)
            )
        case .authorizationRecovery(
            let reservation,
            let pending,
            _
        ) where pending.listenerLease == nil:
            return RuntimeOAuthClaimContext(
                reservation: reservation,
                authorization: pending.authorization,
                origin: .authorizationRecovery(pending)
            )
        default:
            return nil
        }
    }

    private func currentProcessingClaim(
        _ claim: RuntimeOAuthCallbackClaim,
        credentialCommitted: Bool
    ) -> RuntimeOAuthCallbackClaim? {
        guard case .callbackProcessing(
            let reservation,
            let current,
            let committed
        ) = oauthOwner,
        reservation == claim.reservation,
        current.claimId == claim.claimId,
        current.authorization == claim.authorization,
        current.callbackTrace == claim.callbackTrace,
        committed == credentialCommitted
        else {
            return nil
        }
        return current
    }

    private func isProcessing(
        _ claim: RuntimeOAuthCallbackClaim,
        credentialCommitted: Bool
    ) -> Bool {
        currentProcessingClaim(
            claim,
            credentialCommitted: credentialCommitted
        ) != nil
    }

    private func callbackFailure(
        _ error: any Error,
        claim: RuntimeOAuthCallbackClaim
    ) -> RuntimeOAuthCallbackOutcome {
        guard let current = currentProcessingClaim(
            claim,
            credentialCommitted: false
        ) else {
            return .superseded(sealedOAuthOwner())
        }
        let failure = reporter.capture(error, trace: current.callbackTrace)
        switch current.origin {
        case .ready(let authorization):
            switch current.ingressSource {
            case .localListener(let lease):
                let pending = RuntimeOAuthAuthorizationRecoveryPending(
                    authorization: authorization,
                    stage: .listenerRestart,
                    listenerLease: lease
                )
                oauthOwner = .authorizationRecovery(
                    reservation: current.reservation,
                    pending: pending,
                    attempt: nil
                )
                return .authorizationRecoveryPending(
                    pending,
                    failure: failure
                )
            case .customScheme:
                oauthOwner = .ready(
                    reservation: current.reservation,
                    authorization: authorization,
                    lease: nil
                )
                return .notCommitted(failure)
            }
        case .authorizationRecovery(let pending):
            let restored: RuntimeOAuthAuthorizationRecoveryPending
            switch current.ingressSource {
            case .localListener(let lease):
                restored = mergedListenerRecovery(
                    pending,
                    lease: lease
                )
            case .customScheme:
                restored = pending
            }
            oauthOwner = .authorizationRecovery(
                reservation: current.reservation,
                pending: restored,
                attempt: nil
            )
            return .authorizationRecoveryPending(
                restored,
                failure: failure
            )
        }
    }

    private func sealedOAuthOwner() -> RuntimeOAuthCallbackSupersedingOwner {
        switch oauthOwner {
        case .ready(let reservation, let authorization, _):
            return .ready(
                reservation: reservation,
                authorization: authorization
            )
        case .authorizationRecovery(let reservation, let pending, _):
            return .authorizationRecovery(
                reservation: reservation,
                pending: pending
            )
        case nil:
            return .none
        default:
            return .transientAuthorizationOwner
        }
    }

    private func credentialAccount(
        for slot: RuntimeCredentialSlot
    ) -> String {
        switch slot {
        case .apiKey: credentialAccounts.apiKey
        case .searchKey: credentialAccounts.searchKey
        }
    }

    private func finishInitialCredentialAttachment(
        _ base: RuntimeCredentialSetReceipt,
        step: RuntimeCredentialAttachmentRecoveryStep,
        trace: OperationTrace
    ) -> RuntimeCredentialSetOutcome {
        switch resolveCredentialAttachment(base, step: step, trace: trace) {
        case .success(let receipt):
            return verifyCredentialSet(receipt, trace: trace)
        case .pending(let pending, let failure):
            return .attachmentPending(pending, failure: failure)
        }
    }

    private func finishCredentialAttachmentRecovery(
        _ pending: RuntimeCredentialAttachmentPending,
        trace: OperationTrace
    ) -> RuntimeCredentialAttachmentRecoveryOutcome {
        switch resolveCredentialAttachment(
            pending.committed,
            step: pending.step,
            trace: trace
        ) {
        case .success(let receipt):
            switch captureSynchronous(reporter: reporter, trace: trace, {
                _ = try strictSnapshot()
            }) {
            case .value:
                return .recovered(receipt)
            case .failed(let failure):
                return .recoveredWithVisibilityFailure(
                    receipt: receipt,
                    failure: failure
                )
            }
        case .pending(let next, let failure):
            return .pending(next, failure: failure)
        }
    }

    private enum AttachmentResolution {
        case success(RuntimeCredentialSetReceipt)
        case pending(
            RuntimeCredentialAttachmentPending,
            UserVisibleFailure
        )
    }

    private func resolveCredentialAttachment(
        _ base: RuntimeCredentialSetReceipt,
        step: RuntimeCredentialAttachmentRecoveryStep,
        trace: OperationTrace
    ) -> AttachmentResolution {
        let target: RuntimeCredentialAttachmentTarget?
        switch step {
        case .resolveDefault:
            switch captureSynchronous(reporter: reporter, trace: trace, {
                try database.prepareDefaultAPIKeyAttachment()
            }) {
            case .value(let prepared):
                target = prepared
            case .failed(let failure):
                return .pending(
                    RuntimeCredentialAttachmentPending(
                        committed: base,
                        step: .resolveDefault
                    ),
                    failure
                )
            }
        case .attach(let existing):
            target = existing
        }
        guard let target else { return .success(base) }
        do {
            let profile = try database.commitDefaultAPIKeyAttachment(
                target,
                account: credentialAccounts.apiKey
            )
            return .success(RuntimeCredentialSetReceipt(
                slot: base.slot,
                attachedProfileId: profile.id,
                trace: base.trace
            ))
        } catch let conflict as RuntimeProfileStoreError {
            let nextStep: RuntimeCredentialAttachmentRecoveryStep
            if case .credentialAttachmentConflict = conflict {
                nextStep = .resolveDefault
            } else {
                nextStep = .attach(target)
            }
            return .pending(
                RuntimeCredentialAttachmentPending(
                    committed: base,
                    step: nextStep
                ),
                reporter.capture(conflict, trace: trace)
            )
        } catch {
            return .pending(
                RuntimeCredentialAttachmentPending(
                    committed: base,
                    step: .attach(target)
                ),
                reporter.capture(error, trace: trace)
            )
        }
    }

    private func verifyCredentialSet(
        _ receipt: RuntimeCredentialSetReceipt,
        trace: OperationTrace
    ) -> RuntimeCredentialSetOutcome {
        switch captureSynchronous(reporter: reporter, trace: trace, {
            _ = try strictSnapshot()
        }) {
        case .value:
            return .committed(receipt)
        case .failed(let failure):
            return .committedWithVisibilityFailure(
                receipt: receipt,
                failure: failure
            )
        }
    }

    private func applyInitialCredentialAttachment(
        _ outcome: RuntimeCredentialSetOutcome
    ) {
        switch outcome {
        case .attachmentPending(let pending, _):
            credentialAttachmentPending = pending
            credentialAttachmentAttempt = nil
        case .committed, .committedWithVisibilityFailure:
            credentialAttachmentPending = nil
            credentialAttachmentAttempt = nil
        case .notCommitted:
            break
        }
    }

    private func strictSnapshot() throws -> RuntimeWorkflowSnapshot {
        let bundle = try reads.load()
        let credentials = try resolver.presence(
            interactionPolicy: .failIfInteractionRequired
        )
        return Self.snapshot(
            bundle: bundle,
            credentials: credentials,
            defaults: defaults
        )
    }

    private static func snapshot(
        bundle: RuntimeWorkflowReadBundle,
        credentials: RuntimeCredentialPresence,
        defaults: ProfileScopedDefaults
    ) -> RuntimeWorkflowSnapshot {
        RuntimeWorkflowSnapshot(
            profiles: bundle.profiles,
            defaultProfile: bundle.defaultProfile,
            companions: bundle.companions,
            camps: bundle.camps,
            credentials: credentials,
            legacyRuminationSnapshot: legacySnapshot(
                defaultProfile: bundle.defaultProfile,
                defaults: defaults
            )
        )
    }

    private static func legacySnapshot(
        defaultProfile: RuntimeProfileRecord,
        defaults: ProfileScopedDefaults
    ) -> LegacyRuminationStartupSnapshot {
        if defaultProfile.kind.isCLI {
            return .legacyProfileCLIUnsupported
        }
        let distill = defaults.distillModel(
            profileID: defaultProfile.id
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = distill.isEmpty
            ? defaults.defaultModel(
                profileID: defaultProfile.id,
                fallback: ""
            )
            : distill
        guard !selected.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return .legacyModelUnavailable
        }
        return .valid(
            runtimeProfileId: defaultProfile.id,
            model: selected
        )
    }
}
