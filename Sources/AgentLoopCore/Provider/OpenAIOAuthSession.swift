import CryptoKit
import Foundation
import Security

package struct SecretValue: Sendable, Equatable {
    private let rawValue: String

    private init(validatedRaw raw: String) {
        rawValue = raw
    }

    package init(_ raw: String) throws {
        guard !Self.isBlank(raw) else {
            throw CredentialValueInvalidError()
        }
        self.init(validatedRaw: raw)
    }

    package static func validated(_ raw: String) -> SecretValue? {
        guard !isBlank(raw) else { return nil }
        return SecretValue(validatedRaw: raw)
    }

    package func use<T>(_ body: (String) throws -> T) rethrows -> T {
        try body(rawValue)
    }

    package func constantTimeEquals(_ other: SecretValue) -> Bool {
        use { lhs in
            other.use { rhs in
                let lhsBytes = Array(lhs.utf8)
                let rhsBytes = Array(rhs.utf8)
                let workCount = max(lhsBytes.count, rhsBytes.count)
                var difference = UInt(lhsBytes.count ^ rhsBytes.count)
                for index in 0..<workCount {
                    let lhsByte = index < lhsBytes.count ? lhsBytes[index] : 0
                    let rhsByte = index < rhsBytes.count ? rhsBytes[index] : 0
                    difference |= UInt(lhsByte ^ rhsByte)
                }
                return difference == 0
            }
        }
    }

    package static func == (lhs: SecretValue, rhs: SecretValue) -> Bool {
        lhs.constantTimeEquals(rhs)
    }

    private static func isBlank(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

package enum OAuthPKCEPrimitives {
    package static func randomSecret(byteCount: Int) throws -> SecretValue {
        guard byteCount > 0 else {
            throw CredentialValueInvalidError()
        }
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(
            kSecRandomDefault,
            bytes.count,
            &bytes
        ) == errSecSuccess else {
            throw CredentialValueInvalidError()
        }
        return try SecretValue(base64URL(Data(bytes)))
    }

    package static func codeChallenge(for verifier: SecretValue) -> String {
        verifier.use { value in
            base64URL(Data(SHA256.hash(data: Data(value.utf8))))
        }
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

package enum OAuthCredentialFlow: Sendable, Equatable, Hashable {
    case chatGPT
    case generic

    fileprivate var envelopeValue: String {
        switch self {
        case .chatGPT: "chatGPT"
        case .generic: "generic"
        }
    }

    fileprivate init?(envelopeValue: String) {
        switch envelopeValue {
        case "chatGPT": self = .chatGPT
        case "generic": self = .generic
        default: return nil
        }
    }
}

package struct OAuthCredentialBundle: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let accessToken: SecretValue
    package let refreshToken: SecretValue?
    package let idToken: SecretValue?
    package let accountID: SecretValue?

    package init(
        flow: OAuthCredentialFlow,
        accessToken: SecretValue,
        refreshToken: SecretValue?,
        idToken: SecretValue?,
        accountID: SecretValue?
    ) {
        self.flow = flow
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountID = accountID
    }
}

package struct OAuthCredentialAccounts: Sendable, Equatable {
    package static let live = OAuthCredentialAccounts(
        access: "oauth-access-token",
        refresh: "oauth-refresh-token",
        id: "oauth-id-token",
        accountID: "oauth-chatgpt-account-id",
        verifier: "oauth-code-verifier"
    )

    package let access: String
    package let refresh: String
    package let id: String
    package let accountID: String
    package let verifier: String

    package init(
        access: String,
        refresh: String,
        id: String,
        accountID: String,
        verifier: String
    ) {
        self.access = access
        self.refresh = refresh
        self.id = id
        self.accountID = accountID
        self.verifier = verifier
    }

    fileprivate static func compatibility(
        access: String,
        refresh: String,
        id: String,
        accountID: String
    ) -> OAuthCredentialAccounts {
        OAuthCredentialAccounts(
            access: access,
            refresh: refresh,
            id: id,
            accountID: accountID,
            verifier: OAuthCredentialAccounts.live.verifier
        )
    }

    fileprivate var orderedCoordinates: [String] {
        [access, refresh, id, accountID, verifier]
    }

    fileprivate func validate() throws {
        guard isValid else {
            throw OAuthCredentialBundleUnavailableError()
        }
    }

    fileprivate var isValid: Bool {
        orderedCoordinates.allSatisfy { !$0.utf8.isEmpty }
            && Set(orderedCoordinates).count == orderedCoordinates.count
    }
}

fileprivate enum OAuthCredentialEnvelopePhase:
    String, Codable, Sendable, Equatable
{
    case prepared
    case recoveryPrepared
    case initialCommitting
    case refreshCommitting
    case unauthorizedDeleteCommitting
}

fileprivate struct OAuthCredentialEnvelopeOwnerV1:
    Codable, Sendable, Equatable
{
    let accessAccount: String
    let refreshAccount: String
    let idTokenAccount: String
    let accountIDAccount: String
    let envelopeAccount: String

    init(accounts: OAuthCredentialAccounts) {
        accessAccount = accounts.access
        refreshAccount = accounts.refresh
        idTokenAccount = accounts.id
        accountIDAccount = accounts.accountID
        envelopeAccount = accounts.verifier
    }

    var accounts: OAuthCredentialAccounts {
        OAuthCredentialAccounts(
            access: accessAccount,
            refresh: refreshAccount,
            id: idTokenAccount,
            accountID: accountIDAccount,
            verifier: envelopeAccount
        )
    }
}

fileprivate struct OAuthAuthorizationPreparationEnvelopeV1:
    Codable, Sendable, Equatable
{
    let version: Int
    let phase: OAuthCredentialEnvelopePhase
    let owner: OAuthCredentialEnvelopeOwnerV1
    let flow: String
    let state: String
    let verifier: String
}

fileprivate struct OAuthCredentialMutationEnvelopeV1:
    Codable, Sendable, Equatable
{
    let version: Int
    let phase: OAuthCredentialEnvelopePhase
    let owner: OAuthCredentialEnvelopeOwnerV1
    let flow: String
}

fileprivate struct OAuthEnvelopeDiscriminator: Decodable {
    let phase: OAuthCredentialEnvelopePhase
}

fileprivate struct DecodedOAuthPreparationEnvelope: Sendable, Equatable {
    let phase: OAuthCredentialEnvelopePhase
    let owner: OAuthCredentialEnvelopeOwnerV1
    let flow: OAuthCredentialFlow
    let state: SecretValue
    let verifier: SecretValue
    let canonicalRaw: SecretValue
}

fileprivate struct DecodedOAuthMutationEnvelope: Sendable, Equatable {
    let phase: OAuthCredentialEnvelopePhase
    let owner: OAuthCredentialEnvelopeOwnerV1
    let flow: OAuthCredentialFlow
    let canonicalRaw: SecretValue
}

fileprivate enum DecodedOAuthEnvelope: Sendable, Equatable {
    case preparation(DecodedOAuthPreparationEnvelope)
    case mutation(DecodedOAuthMutationEnvelope)
}

fileprivate enum OAuthEnvelopeDecodeOutcome: Sendable {
    case value(DecodedOAuthEnvelope)
    case invalid
}

fileprivate enum OAuthEnvelopeCodec {
    static func encodePreparation(
        phase: OAuthCredentialEnvelopePhase,
        owner: OAuthCredentialEnvelopeOwnerV1,
        flow: OAuthCredentialFlow,
        state: SecretValue,
        verifier: SecretValue
    ) throws -> SecretValue {
        let value = OAuthAuthorizationPreparationEnvelopeV1(
            version: 1,
            phase: phase,
            owner: owner,
            flow: flow.envelopeValue,
            state: state.use { $0 },
            verifier: verifier.use { $0 }
        )
        return try SecretValue(canonicalData(for: value))
    }

    static func encodeMutation(
        phase: OAuthCredentialEnvelopePhase,
        owner: OAuthCredentialEnvelopeOwnerV1,
        flow: OAuthCredentialFlow
    ) throws -> SecretValue {
        let value = OAuthCredentialMutationEnvelopeV1(
            version: 1,
            phase: phase,
            owner: owner,
            flow: flow.envelopeValue
        )
        return try SecretValue(canonicalData(for: value))
    }

    static func decode(_ raw: SecretValue) -> OAuthEnvelopeDecodeOutcome {
        let attempt = Result {
            try raw.use { string in
                try decodeThrowing(string)
            }
        }
        switch attempt {
        case .success(let value): return .value(value)
        case .failure: return .invalid
        }
    }

    private static func decodeThrowing(
        _ raw: String
    ) throws -> DecodedOAuthEnvelope {
        let data = Data(raw.utf8)
        let discriminator = try JSONDecoder().decode(
            OAuthEnvelopeDiscriminator.self,
            from: data
        )
        switch discriminator.phase {
        case .prepared, .recoveryPrepared, .initialCommitting:
            let value = try JSONDecoder().decode(
                OAuthAuthorizationPreparationEnvelopeV1.self,
                from: data
            )
            guard value.version == 1,
                  value.phase == discriminator.phase,
                  let flow = OAuthCredentialFlow(
                    envelopeValue: value.flow
                  ),
                  try canonicalData(for: value) == raw
            else {
                throw OAuthCredentialBundleUnavailableError()
            }
            try value.owner.accounts.validate()
            return .preparation(
                DecodedOAuthPreparationEnvelope(
                    phase: value.phase,
                    owner: value.owner,
                    flow: flow,
                    state: try SecretValue(value.state),
                    verifier: try SecretValue(value.verifier),
                    canonicalRaw: try SecretValue(raw)
                )
            )
        case .refreshCommitting, .unauthorizedDeleteCommitting:
            let value = try JSONDecoder().decode(
                OAuthCredentialMutationEnvelopeV1.self,
                from: data
            )
            guard value.version == 1,
                  value.phase == discriminator.phase,
                  let flow = OAuthCredentialFlow(
                    envelopeValue: value.flow
                  ),
                  try canonicalData(for: value) == raw
            else {
                throw OAuthCredentialBundleUnavailableError()
            }
            try value.owner.accounts.validate()
            return .mutation(
                DecodedOAuthMutationEnvelope(
                    phase: value.phase,
                    owner: value.owner,
                    flow: flow,
                    canonicalRaw: try SecretValue(raw)
                )
            )
        }
    }

    private static func canonicalData<Value: Encodable>(
        for value: Value
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CredentialValueInvalidError()
        }
        return string
    }
}

package struct OAuthAuthorizationPreparation: Sendable, Equatable {
    package let flow: OAuthCredentialFlow
    package let state: SecretValue
    package let verifier: SecretValue
    fileprivate let coordinatorID: UUID
    fileprivate let accounts: OAuthCredentialAccounts
    fileprivate let envelopePhase: OAuthCredentialEnvelopePhase

    fileprivate init(
        flow: OAuthCredentialFlow,
        state: SecretValue,
        verifier: SecretValue,
        coordinatorID: UUID,
        accounts: OAuthCredentialAccounts,
        envelopePhase: OAuthCredentialEnvelopePhase
    ) {
        self.flow = flow
        self.state = state
        self.verifier = verifier
        self.coordinatorID = coordinatorID
        self.accounts = accounts
        self.envelopePhase = envelopePhase
    }
}

package struct OAuthCredentialReadSnapshot: Sendable, Equatable {
    package let accessToken: SecretValue?
    package let refreshToken: SecretValue?
    package let idToken: SecretValue?
    package let accountID: SecretValue?

    package init(
        accessToken: SecretValue?,
        refreshToken: SecretValue?,
        idToken: SecretValue?,
        accountID: SecretValue?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountID = accountID
    }
}

fileprivate struct OAuthCredentialRevision: Sendable, Equatable {
    let valueByAccount: [String: UUID]
}

package struct OAuthRefreshCredentialRead: Sendable, Equatable {
    package let refreshToken: SecretValue
    fileprivate let coordinatorID: UUID
    fileprivate let accounts: OAuthCredentialAccounts
    fileprivate let revision: OAuthCredentialRevision
    fileprivate let snapshot: OAuthCredentialReadSnapshot

    fileprivate init(
        refreshToken: SecretValue,
        coordinatorID: UUID,
        accounts: OAuthCredentialAccounts,
        revision: OAuthCredentialRevision,
        snapshot: OAuthCredentialReadSnapshot
    ) {
        self.refreshToken = refreshToken
        self.coordinatorID = coordinatorID
        self.accounts = accounts
        self.revision = revision
        self.snapshot = snapshot
    }
}

package struct RuntimeCredentialPresenceReadSnapshot: Sendable, Equatable {
    package let apiKey: String?
    package let searchKey: String?
    package let oauth: OAuthCredentialReadSnapshot

    fileprivate init(
        apiKey: String?,
        searchKey: String?,
        oauth: OAuthCredentialReadSnapshot
    ) {
        self.apiKey = apiKey
        self.searchKey = searchKey
        self.oauth = oauth
    }
}

package enum OAuthAuthorizationPreparationCommitOutcome:
    Sendable, Equatable
{
    case committed(CredentialMutationReceipt)
    case failed(CredentialBundleError)
    case unavailable(OAuthCredentialBundleUnavailableError)
}

package enum CredentialMutationKind: String, Sendable, Equatable {
    case access
    case refresh
    case id
    case accountID
    case oauthTransactionEnvelope
    case unauthorizedAccess
    case mcpSecret
    case mcpDatabaseRow
}

package enum McpDeletionMutationKind: String, Sendable, Equatable {
    case secret
    case databaseRow
}

package struct CredentialMutationReceipt: Sendable, Equatable {
    package let mutationCount: Int

    package init(mutationCount: Int) {
        self.mutationCount = mutationCount
    }
}

package enum CredentialBundleError: Error, Sendable, Equatable {
    case preimageRead(flow: OAuthCredentialFlow, status: Int32?)
    case commit(
        flow: OAuthCredentialFlow,
        mutation: CredentialMutationKind,
        status: Int32?
    )
    case rollback(flow: OAuthCredentialFlow, status: Int32?)
    case preimageChanged(flow: OAuthCredentialFlow)
    case unauthorizedDelete(status: Int32?)
    case authorizationPreparationCommit(status: Int32?)
}

package enum McpCredentialDeletionError: Error, Sendable, Equatable {
    case preimageRead(status: Int32?)
    case commit(mutation: McpDeletionMutationKind, status: Int32?)
    case rollback(status: Int32?)
}

package struct McpCredentialAccount: Sendable, Equatable, Comparable {
    package let rawValue: String

    package init(
        server: McpServerRecord,
        secretEnvironmentKey: String
    ) throws {
        let decoded = Result {
            try JSONDecoder().decode(
                [String].self,
                from: Data(server.secretEnvKeysJson.utf8)
            )
        }
        guard case .success(let keys) = decoded else {
            throw McpOperationError.invalidConfig(
                serverId: server.id,
                field: .secretEnvKeys
            )
        }
        guard FailureMetadataGrammar.isSafeID(server.id),
              keys.contains(secretEnvironmentKey),
              Self.isValidEnvironmentKey(secretEnvironmentKey)
        else {
            throw McpOperationError.invalidConfig(
                serverId: server.id,
                field: .secretEnvKeys
            )
        }
        rawValue = "mcp-\(server.id)-\(secretEnvironmentKey)"
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue.utf8.lexicographicallyPrecedes(rhs.rawValue.utf8)
    }

    private static func isValidEnvironmentKey(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...128).contains(bytes.count),
              let first = bytes.first,
              isASCIIAlpha(first) || first == 95
        else {
            return false
        }
        return bytes.dropFirst().allSatisfy {
            isASCIIAlpha($0) || (48...57).contains($0) || $0 == 95
        }
    }

    private static func isASCIIAlpha(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte)
    }
}

public enum CredentialStoreBackendNamespace: Hashable, Sendable {
    case legacyShared
    case keychainService(String)
    case isolated(UUID)
}

public protocol CredentialStore: Sendable {
    var backendNamespace: CredentialStoreBackendNamespace { get }
    func set(_ value: String, account: String) throws
    func get(account: String) throws -> String?
    func get(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String?
    func delete(account: String) throws
}

public extension CredentialStore {
    var backendNamespace: CredentialStoreBackendNamespace { .legacyShared }

    func get(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String? {
        try get(account: account)
    }
}

fileprivate final class CredentialMutationScopeToken {}

fileprivate final class CredentialAccessProcessState: @unchecked Sendable {
    let lock = NSLock()

    struct OAuthRevisionKey: Hashable, Sendable {
        let backendNamespace: CredentialStoreBackendNamespace
        let account: String
    }

    var oauthRevisionByBackendAccount: [OAuthRevisionKey: UUID] = [:]
}

fileprivate struct CredentialMutationStore {
    private let store: any CredentialStore
    private let processState: CredentialAccessProcessState
    private let scopeToken: CredentialMutationScopeToken
    private let backendNamespace: CredentialStoreBackendNamespace

    fileprivate init(
        store: any CredentialStore,
        processState: CredentialAccessProcessState,
        scopeToken: CredentialMutationScopeToken,
        backendNamespace: CredentialStoreBackendNamespace
    ) {
        self.store = store
        self.processState = processState
        self.scopeToken = scopeToken
        self.backendNamespace = backendNamespace
    }

    fileprivate func read(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String? {
        _ = scopeToken
        return try store.get(
            account: account,
            interactionPolicy: interactionPolicy
        )
    }

    fileprivate func readSecret(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> SecretValue? {
        guard let raw = try read(
            account: account,
            interactionPolicy: interactionPolicy
        ) else {
            return nil
        }
        return try SecretValue(raw)
    }

    fileprivate func set(_ value: SecretValue, account: String) throws {
        _ = scopeToken
        try value.use { raw in
            try store.set(raw, account: account)
        }
    }

    fileprivate func delete(account: String) throws {
        _ = scopeToken
        try store.delete(account: account)
    }

    fileprivate func oauthCredentialRevision(
        accounts: OAuthCredentialAccounts
    ) -> OAuthCredentialRevision {
        var snapshot: [String: UUID] = [:]
        for account in accounts.orderedCoordinates {
            let key = CredentialAccessProcessState.OAuthRevisionKey(
                backendNamespace: backendNamespace,
                account: account
            )
            let value: UUID
            if let existing = processState.oauthRevisionByBackendAccount[key] {
                value = existing
            } else {
                let created = UUID()
                processState.oauthRevisionByBackendAccount[key] = created
                value = created
            }
            snapshot[account] = value
        }
        return OAuthCredentialRevision(valueByAccount: snapshot)
    }

    @discardableResult
    fileprivate func advanceOAuthCredentialRevision(
        accounts: OAuthCredentialAccounts
    ) -> OAuthCredentialRevision {
        var snapshot: [String: UUID] = [:]
        for account in accounts.orderedCoordinates {
            let key = CredentialAccessProcessState.OAuthRevisionKey(
                backendNamespace: backendNamespace,
                account: account
            )
            let value = UUID()
            processState.oauthRevisionByBackendAccount[key] = value
            snapshot[account] = value
        }
        return OAuthCredentialRevision(valueByAccount: snapshot)
    }
}

package final class SynchronizedCredentialAccess: @unchecked Sendable {
    private static let processState = CredentialAccessProcessState()
    private let store: any CredentialStore
    package let backendNamespace: CredentialStoreBackendNamespace

    package init(store: any CredentialStore) {
        self.store = store
        backendNamespace = store.backendNamespace
    }

    package func read(
        account: String,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> String? {
        try withExclusiveAccess { mutationStore in
            guard let value = try mutationStore.readSecret(
                account: account,
                interactionPolicy: interactionPolicy
            ) else {
                return nil
            }
            return value.use { $0 }
        }
    }

    package func read(
        accounts: [String],
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> [String?] {
        try withExclusiveAccess { mutationStore in
            try accounts.map { account in
                try mutationStore.readSecret(
                    account: account,
                    interactionPolicy: interactionPolicy
                )?.use { $0 }
            }
        }
    }

    package func readOAuthCredentials(
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthCredentialReadSnapshot {
        try accounts.validate()
        return try withExclusiveAccess { mutationStore in
            try Self.requireReadableEnvelope(
                mutationStore: mutationStore,
                accounts: accounts,
                interactionPolicy: interactionPolicy,
                permitsPrepared: true
            )
            return try Self.readSnapshot(
                mutationStore: mutationStore,
                accounts: accounts,
                interactionPolicy: interactionPolicy
            )
        }
    }

    package func readRuntimeCredentialPresence(
        apiKeyAccount: String,
        searchKeyAccount: String,
        oauthAccounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> RuntimeCredentialPresenceReadSnapshot {
        try oauthAccounts.validate()
        return try withExclusiveAccess { mutationStore in
            let apiKey = try mutationStore.readSecret(
                account: apiKeyAccount,
                interactionPolicy: interactionPolicy
            )?.use { $0 }
            let searchKey = try mutationStore.readSecret(
                account: searchKeyAccount,
                interactionPolicy: interactionPolicy
            )?.use { $0 }
            try Self.requireReadableEnvelope(
                mutationStore: mutationStore,
                accounts: oauthAccounts,
                interactionPolicy: interactionPolicy,
                permitsPrepared: true
            )
            let oauth = try Self.readSnapshot(
                mutationStore: mutationStore,
                accounts: oauthAccounts,
                interactionPolicy: interactionPolicy
            )
            return RuntimeCredentialPresenceReadSnapshot(
                apiKey: apiKey,
                searchKey: searchKey,
                oauth: oauth
            )
        }
    }

    fileprivate func withExclusiveAccess<T: Sendable>(
        _ body: (CredentialMutationStore) throws -> T
    ) rethrows -> T {
        Self.processState.lock.lock()
        defer { Self.processState.lock.unlock() }
        return try body(
            CredentialMutationStore(
                store: store,
                processState: Self.processState,
                scopeToken: CredentialMutationScopeToken(),
                backendNamespace: backendNamespace
            )
        )
    }

    private static func requireReadableEnvelope(
        mutationStore: CredentialMutationStore,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy,
        permitsPrepared: Bool
    ) throws {
        guard let raw = try mutationStore.readSecret(
            account: accounts.verifier,
            interactionPolicy: interactionPolicy
        ) else {
            return
        }
        switch OAuthEnvelopeCodec.decode(raw) {
        case .invalid:
            throw OAuthCredentialBundleUnavailableError()
        case .value(.mutation):
            throw OAuthCredentialBundleUnavailableError()
        case .value(.preparation(let envelope)):
            guard permitsPrepared,
                  envelope.phase == .prepared,
                  envelope.owner
                    == OAuthCredentialEnvelopeOwnerV1(accounts: accounts)
            else {
                throw OAuthCredentialBundleUnavailableError()
            }
        }
    }

    private static func readSnapshot(
        mutationStore: CredentialMutationStore,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthCredentialReadSnapshot {
        let access = try mutationStore.readSecret(
            account: accounts.access,
            interactionPolicy: interactionPolicy
        )
        let refresh = try mutationStore.readSecret(
            account: accounts.refresh,
            interactionPolicy: interactionPolicy
        )
        let id = try mutationStore.readSecret(
            account: accounts.id,
            interactionPolicy: interactionPolicy
        )
        let accountID = try mutationStore.readSecret(
            account: accounts.accountID,
            interactionPolicy: interactionPolicy
        )
        return OAuthCredentialReadSnapshot(
            accessToken: access,
            refreshToken: refresh,
            idToken: id,
            accountID: accountID
        )
    }
}

fileprivate enum CredentialStoreAttempt<Value: Sendable>: Sendable {
    case value(Value)
    case failure(osStatus: Int32?)
}

fileprivate struct CredentialFieldMutation: Sendable {
    let account: String
    let kind: CredentialMutationKind
    let preimage: SecretValue?
    let replacement: SecretValue?
}

fileprivate struct McpCredentialPreimage: Sendable {
    let account: McpCredentialAccount
    let value: SecretValue?
}

fileprivate enum CredentialTransactionOutcome: Sendable {
    case committed(CredentialMutationReceipt)
    case failed(CredentialBundleError)
}

fileprivate enum OAuthRefreshReadOutcome: Sendable {
    case value(OAuthRefreshCredentialRead?)
    case failure(CredentialBundleError)
    case unavailable
}

fileprivate enum OAuthPreparationReadOutcome: Sendable {
    case value(OAuthAuthorizationPreparation)
    case failure(CredentialBundleError)
    case missing
    case mismatch
}

package actor CredentialBundleCoordinator {
    nonisolated package let synchronizedAccess: SynchronizedCredentialAccess
    private let coordinatorID: UUID

    package init(access: SynchronizedCredentialAccess) {
        synchronizedAccess = access
        coordinatorID = UUID()
    }

    nonisolated package func setRuntimeCredential(
        _ value: SecretValue,
        account: String
    ) throws {
        try synchronizedAccess.withExclusiveAccess { mutationStore in
            try mutationStore.set(value, account: account)
        }
    }

    nonisolated package func deleteRuntimeCredential(account: String) throws {
        try synchronizedAccess.withExclusiveAccess { mutationStore in
            try mutationStore.delete(account: account)
        }
    }

    nonisolated package func setMcpCredential(
        _ value: SecretValue,
        account: McpCredentialAccount
    ) throws {
        try synchronizedAccess.withExclusiveAccess { mutationStore in
            try mutationStore.set(value, account: account.rawValue)
        }
    }

    nonisolated package func deleteMcpCredential(
        account: McpCredentialAccount
    ) throws {
        try synchronizedAccess.withExclusiveAccess { mutationStore in
            try mutationStore.delete(account: account.rawValue)
        }
    }

    package func commitAuthorizationPreparation(
        flow: OAuthCredentialFlow,
        state: SecretValue,
        verifier: SecretValue,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) -> OAuthAuthorizationPreparationCommitOutcome {
        guard accounts.isValid else {
            return .unavailable(OAuthCredentialBundleUnavailableError())
        }
        return synchronizedAccess.withExclusiveAccess { mutationStore in
            mutationStore.advanceOAuthCredentialRevision(accounts: accounts)
            let preimageAttempt = Self.primaryAttempt {
                try mutationStore.readSecret(
                    account: accounts.verifier,
                    interactionPolicy: interactionPolicy
                )
            }
            let selectedPhase: OAuthCredentialEnvelopePhase
            switch preimageAttempt {
            case .failure(let status):
                return .failed(.preimageRead(flow: flow, status: status))
            case .value(nil):
                selectedPhase = .prepared
            case .value(.some(let raw)):
                switch OAuthEnvelopeCodec.decode(raw) {
                case .invalid:
                    return .unavailable(
                        OAuthCredentialBundleUnavailableError()
                    )
                case .value(.preparation(let envelope)):
                    if envelope.phase == .prepared {
                        selectedPhase = .prepared
                    } else if envelope.owner
                        == OAuthCredentialEnvelopeOwnerV1(accounts: accounts)
                    {
                        selectedPhase = .recoveryPrepared
                    } else {
                        return .unavailable(
                            OAuthCredentialBundleUnavailableError()
                        )
                    }
                case .value(.mutation(let envelope)):
                    guard envelope.owner
                        == OAuthCredentialEnvelopeOwnerV1(accounts: accounts)
                    else {
                        return .unavailable(
                            OAuthCredentialBundleUnavailableError()
                        )
                    }
                    selectedPhase = .recoveryPrepared
                }
            }
            let encodedAttempt = Self.primaryAttempt {
                try OAuthEnvelopeCodec.encodePreparation(
                    phase: selectedPhase,
                    owner: OAuthCredentialEnvelopeOwnerV1(accounts: accounts),
                    flow: flow,
                    state: state,
                    verifier: verifier
                )
            }
            let encoded: SecretValue
            switch encodedAttempt {
            case .failure(let status):
                return .failed(
                    .authorizationPreparationCommit(status: status)
                )
            case .value(let value):
                encoded = value
            }
            switch Self.primaryAttempt({
                try mutationStore.set(encoded, account: accounts.verifier)
            }) {
            case .failure(let status):
                return .failed(
                    .authorizationPreparationCommit(status: status)
                )
            case .value:
                return .committed(CredentialMutationReceipt(mutationCount: 1))
            }
        }
    }

    package func readAuthorizationPreparation(
        flow: OAuthCredentialFlow,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthAuthorizationPreparation {
        try accounts.validate()
        let outcome: OAuthPreparationReadOutcome =
            synchronizedAccess.withExclusiveAccess { mutationStore in
            switch Self.primaryAttempt({
                try mutationStore.readSecret(
                    account: accounts.verifier,
                    interactionPolicy: interactionPolicy
                )
            }) {
            case .failure(let status):
                return OAuthPreparationReadOutcome.failure(
                    .preimageRead(flow: flow, status: status)
                )
            case .value(nil):
                return .missing
            case .value(.some(let raw)):
                switch OAuthEnvelopeCodec.decode(raw) {
                case .invalid:
                    return .mismatch
                case .value(.mutation):
                    return .mismatch
                case .value(.preparation(let envelope)):
                    guard envelope.phase == .prepared
                            || envelope.phase == .recoveryPrepared,
                          envelope.owner
                            == OAuthCredentialEnvelopeOwnerV1(
                                accounts: accounts
                            ),
                          envelope.flow == flow
                    else {
                        return .mismatch
                    }
                    return .value(
                        OAuthAuthorizationPreparation(
                            flow: flow,
                            state: envelope.state,
                            verifier: envelope.verifier,
                            coordinatorID: coordinatorID,
                            accounts: accounts,
                            envelopePhase: envelope.phase
                        )
                    )
                }
            }
        }
        switch outcome {
        case .value(let preparation): return preparation
        case .failure(let error): throw error
        case .missing: throw RuntimeOAuthBoundaryError.stateMissing
        case .mismatch: throw RuntimeOAuthBoundaryError.stateMismatch
        }
    }

    package func commitInitial(
        _ bundle: OAuthCredentialBundle,
        basedOn preparation: OAuthAuthorizationPreparation,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> CredentialMutationReceipt {
        guard preparation.coordinatorID == coordinatorID,
              bundle.flow == preparation.flow,
              bundle.flow != .chatGPT || bundle.accountID != nil
        else {
            throw CredentialBundleError.preimageChanged(
                flow: preparation.flow
            )
        }
        try preparation.accounts.validate()
        let owner = OAuthCredentialEnvelopeOwnerV1(
            accounts: preparation.accounts
        )
        let expectedAttempt = Self.primaryAttempt {
            try OAuthEnvelopeCodec.encodePreparation(
                phase: preparation.envelopePhase,
                owner: owner,
                flow: preparation.flow,
                state: preparation.state,
                verifier: preparation.verifier
            )
        }
        let committingAttempt = Self.primaryAttempt {
            try OAuthEnvelopeCodec.encodePreparation(
                phase: .initialCommitting,
                owner: owner,
                flow: preparation.flow,
                state: preparation.state,
                verifier: preparation.verifier
            )
        }
        let expected: SecretValue
        let committing: SecretValue
        switch (expectedAttempt, committingAttempt) {
        case (.value(let expectedValue), .value(let committingValue)):
            expected = expectedValue
            committing = committingValue
        case (.failure(let status), _), (_, .failure(let status)):
            throw CredentialBundleError.commit(
                flow: preparation.flow,
                mutation: .oauthTransactionEnvelope,
                status: status
            )
        }

        let outcome: CredentialTransactionOutcome =
            synchronizedAccess.withExclusiveAccess { mutationStore in
            mutationStore.advanceOAuthCredentialRevision(
                accounts: preparation.accounts
            )
            let snapshotOutcome = Self.readSnapshotAttempt(
                mutationStore: mutationStore,
                accounts: preparation.accounts,
                interactionPolicy: interactionPolicy,
                flow: preparation.flow
            )
            let snapshot: OAuthCredentialReadSnapshot
            switch snapshotOutcome {
            case .failure(let error): return .failed(error)
            case .success(let value): snapshot = value
            }
            let envelopeAttempt = Self.primaryAttempt {
                try mutationStore.readSecret(
                    account: preparation.accounts.verifier,
                    interactionPolicy: interactionPolicy
                )
            }
            switch envelopeAttempt {
            case .failure(let status):
                return .failed(
                    .preimageRead(flow: preparation.flow, status: status)
                )
            case .value(let current):
                guard current == expected else {
                    return .failed(
                        .preimageChanged(flow: preparation.flow)
                    )
                }
            }

            let fields = Self.initialMutations(
                bundle: bundle,
                accounts: preparation.accounts,
                snapshot: snapshot
            )
            return Self.performTransaction(
                mutationStore: mutationStore,
                flow: preparation.flow,
                envelopeAccount: preparation.accounts.verifier,
                preimageEnvelope: expected,
                committingEnvelope: committing,
                fields: fields,
                primaryError: { mutation, status in
                    .commit(
                        flow: preparation.flow,
                        mutation: mutation,
                        status: status
                    )
                }
            )
        }
        return try Self.unwrap(outcome)
    }

    package func readRefreshCredential(
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> OAuthRefreshCredentialRead? {
        try accounts.validate()
        let outcome: OAuthRefreshReadOutcome =
            synchronizedAccess.withExclusiveAccess { mutationStore in
            switch Self.primaryAttempt({
                try mutationStore.readSecret(
                    account: accounts.verifier,
                    interactionPolicy: interactionPolicy
                )
            }) {
            case .failure(let status):
                return OAuthRefreshReadOutcome.failure(
                    .preimageRead(flow: .chatGPT, status: status)
                )
            case .value(.some):
                return .unavailable
            case .value(nil):
                break
            }

            let accessAttempt = Self.primaryAttempt {
                try mutationStore.readSecret(
                    account: accounts.access,
                    interactionPolicy: interactionPolicy
                )
            }
            let access: SecretValue?
            switch accessAttempt {
            case .failure(let status):
                return .failure(.preimageRead(flow: .chatGPT, status: status))
            case .value(let value): access = value
            }
            let refreshAttempt = Self.primaryAttempt {
                try mutationStore.readSecret(
                    account: accounts.refresh,
                    interactionPolicy: interactionPolicy
                )
            }
            let refresh: SecretValue
            switch refreshAttempt {
            case .failure(let status):
                return .failure(.preimageRead(flow: .chatGPT, status: status))
            case .value(nil):
                return .value(nil)
            case .value(.some(let value)):
                refresh = value
            }
            let idAttempt = Self.primaryAttempt {
                try mutationStore.readSecret(
                    account: accounts.id,
                    interactionPolicy: interactionPolicy
                )
            }
            let id: SecretValue?
            switch idAttempt {
            case .failure(let status):
                return .failure(.preimageRead(flow: .chatGPT, status: status))
            case .value(let value): id = value
            }
            let accountAttempt = Self.primaryAttempt {
                try mutationStore.readSecret(
                    account: accounts.accountID,
                    interactionPolicy: interactionPolicy
                )
            }
            let accountID: SecretValue?
            switch accountAttempt {
            case .failure(let status):
                return .failure(.preimageRead(flow: .chatGPT, status: status))
            case .value(let value): accountID = value
            }
            let revision = mutationStore.oauthCredentialRevision(
                accounts: accounts
            )
            let snapshot = OAuthCredentialReadSnapshot(
                accessToken: access,
                refreshToken: refresh,
                idToken: id,
                accountID: accountID
            )
            return .value(
                OAuthRefreshCredentialRead(
                    refreshToken: refresh,
                    coordinatorID: coordinatorID,
                    accounts: accounts,
                    revision: revision,
                    snapshot: snapshot
                )
            )
        }
        switch outcome {
        case .value(let read): return read
        case .failure(let error): throw error
        case .unavailable: throw OAuthCredentialBundleUnavailableError()
        }
    }

    package func commitRefresh(
        _ bundle: OAuthCredentialBundle,
        basedOn read: OAuthRefreshCredentialRead,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> CredentialMutationReceipt {
        guard read.coordinatorID == coordinatorID,
              bundle.flow == .chatGPT
        else {
            throw CredentialBundleError.preimageChanged(flow: .chatGPT)
        }
        try read.accounts.validate()
        let committingAttempt = Self.primaryAttempt {
            try OAuthEnvelopeCodec.encodeMutation(
                phase: .refreshCommitting,
                owner: OAuthCredentialEnvelopeOwnerV1(
                    accounts: read.accounts
                ),
                flow: .chatGPT
            )
        }
        let committing: SecretValue
        switch committingAttempt {
        case .failure(let status):
            throw CredentialBundleError.commit(
                flow: .chatGPT,
                mutation: .oauthTransactionEnvelope,
                status: status
            )
        case .value(let value): committing = value
        }

        let outcome: CredentialTransactionOutcome =
            synchronizedAccess.withExclusiveAccess { mutationStore in
            let currentRevision = mutationStore.oauthCredentialRevision(
                accounts: read.accounts
            )
            guard currentRevision == read.revision else {
                return .failed(.preimageChanged(flow: .chatGPT))
            }
            mutationStore.advanceOAuthCredentialRevision(accounts: read.accounts)
            let snapshotOutcome = Self.readAbsentEnvelopeAndSnapshot(
                mutationStore: mutationStore,
                accounts: read.accounts,
                interactionPolicy: interactionPolicy
            )
            let snapshot: OAuthCredentialReadSnapshot
            switch snapshotOutcome {
            case .failure(let error): return .failed(error)
            case .success(let value): snapshot = value
            }
            guard snapshot == read.snapshot else {
                return .failed(.preimageChanged(flow: .chatGPT))
            }
            let fields = Self.refreshMutations(
                bundle: bundle,
                accounts: read.accounts,
                snapshot: snapshot
            )
            return Self.performTransaction(
                mutationStore: mutationStore,
                flow: .chatGPT,
                envelopeAccount: read.accounts.verifier,
                preimageEnvelope: nil,
                committingEnvelope: committing,
                fields: fields,
                primaryError: { mutation, status in
                    .commit(
                        flow: .chatGPT,
                        mutation: mutation,
                        status: status
                    )
                }
            )
        }
        return try Self.unwrap(outcome)
    }

    package func deleteUnauthorizedAccess(
        basedOn read: OAuthRefreshCredentialRead,
        interactionPolicy: KeychainInteractionPolicy
    ) throws -> CredentialMutationReceipt {
        guard read.coordinatorID == coordinatorID else {
            throw CredentialBundleError.preimageChanged(flow: .chatGPT)
        }
        try read.accounts.validate()
        let committingAttempt = Self.primaryAttempt {
            try OAuthEnvelopeCodec.encodeMutation(
                phase: .unauthorizedDeleteCommitting,
                owner: OAuthCredentialEnvelopeOwnerV1(
                    accounts: read.accounts
                ),
                flow: .chatGPT
            )
        }
        let committing: SecretValue
        switch committingAttempt {
        case .failure(let status):
            throw CredentialBundleError.unauthorizedDelete(status: status)
        case .value(let value): committing = value
        }

        let outcome: CredentialTransactionOutcome =
            synchronizedAccess.withExclusiveAccess { mutationStore in
            let currentRevision = mutationStore.oauthCredentialRevision(
                accounts: read.accounts
            )
            guard currentRevision == read.revision else {
                return .failed(.preimageChanged(flow: .chatGPT))
            }
            mutationStore.advanceOAuthCredentialRevision(accounts: read.accounts)
            let snapshotOutcome = Self.readAbsentEnvelopeAndSnapshot(
                mutationStore: mutationStore,
                accounts: read.accounts,
                interactionPolicy: interactionPolicy
            )
            let snapshot: OAuthCredentialReadSnapshot
            switch snapshotOutcome {
            case .failure(let error): return .failed(error)
            case .success(let value): snapshot = value
            }
            guard snapshot == read.snapshot else {
                return .failed(.preimageChanged(flow: .chatGPT))
            }
            let fields = [
                CredentialFieldMutation(
                    account: read.accounts.access,
                    kind: .unauthorizedAccess,
                    preimage: snapshot.accessToken,
                    replacement: nil
                ),
            ]
            return Self.performTransaction(
                mutationStore: mutationStore,
                flow: .chatGPT,
                envelopeAccount: read.accounts.verifier,
                preimageEnvelope: nil,
                committingEnvelope: committing,
                fields: fields,
                primaryError: { _, status in
                    .unauthorizedDelete(status: status)
                }
            )
        }
        return try Self.unwrap(outcome)
    }

    package func commitMcpServerDeletion(
        secretAccounts: [McpCredentialAccount],
        interactionPolicy: KeychainInteractionPolicy,
        deleteDatabaseRow: @escaping @Sendable () throws -> Void
    ) -> Result<CredentialMutationReceipt, McpCredentialDeletionError> {
        let ordered = secretAccounts.sorted()
        guard zip(ordered, ordered.dropFirst()).allSatisfy({
            $0.0.rawValue != $0.1.rawValue
        }) else {
            return .failure(.preimageRead(status: nil))
        }
        return synchronizedAccess.withExclusiveAccess { mutationStore in
            var preimages: [McpCredentialPreimage] = []
            preimages.reserveCapacity(ordered.count)
            for account in ordered {
                switch Self.primaryAttempt({
                    try mutationStore.readSecret(
                        account: account.rawValue,
                        interactionPolicy: interactionPolicy
                    )
                }) {
                case .failure(let status):
                    return .failure(.preimageRead(status: status))
                case .value(let value):
                    preimages.append(McpCredentialPreimage(
                        account: account,
                        value: value
                    ))
                }
            }

            var changed: [McpCredentialPreimage] = []
            changed.reserveCapacity(preimages.count)
            for preimage in preimages {
                switch Self.primaryAttempt({
                    try mutationStore.delete(
                        account: preimage.account.rawValue
                    )
                }) {
                case .failure(let status):
                    return Self.rollbackMcpDeletion(
                        mutationStore: mutationStore,
                        changed: changed,
                        primary: .commit(
                            mutation: .secret,
                            status: status
                        )
                    )
                case .value:
                    changed.append(preimage)
                }
            }

            switch Self.primaryAttempt(deleteDatabaseRow) {
            case .failure(let status):
                return Self.rollbackMcpDeletion(
                    mutationStore: mutationStore,
                    changed: changed,
                    primary: .commit(
                        mutation: .databaseRow,
                        status: status
                    )
                )
            case .value:
                return .success(CredentialMutationReceipt(
                    mutationCount: changed.count + 1
                ))
            }
        }
    }
}

fileprivate extension CredentialBundleCoordinator {
    nonisolated static func primaryAttempt<Value: Sendable>(
        _ body: () throws -> Value
    ) -> CredentialStoreAttempt<Value> {
        do {
            return .value(try body())
        } catch {
            return .failure(osStatus: osStatus(error))
        }
    }

    nonisolated static func rollbackAttempt<Value: Sendable>(
        _ body: () throws -> Value
    ) -> CredentialStoreAttempt<Value> {
        do {
            return .value(try body())
        } catch {
            return .failure(osStatus: osStatus(error))
        }
    }

    nonisolated static func osStatus(_ error: any Error) -> Int32? {
        guard let keychain = error as? KeychainError else { return nil }
        return Int32(keychain.status)
    }

    nonisolated static func rollbackMcpDeletion(
        mutationStore: CredentialMutationStore,
        changed: [McpCredentialPreimage],
        primary: McpCredentialDeletionError
    ) -> Result<CredentialMutationReceipt, McpCredentialDeletionError> {
        var rollbackFailed = false
        var rollbackStatus: Int32?
        for preimage in changed.reversed() {
            let attempt: CredentialStoreAttempt<Void>
            if let value = preimage.value {
                attempt = rollbackAttempt {
                    try mutationStore.set(
                        value,
                        account: preimage.account.rawValue
                    )
                }
            } else {
                attempt = rollbackAttempt {
                    try mutationStore.delete(
                        account: preimage.account.rawValue
                    )
                }
            }
            if case .failure(let status) = attempt, !rollbackFailed {
                rollbackFailed = true
                rollbackStatus = status
            }
        }
        if rollbackFailed {
            return .failure(.rollback(status: rollbackStatus))
        }
        return .failure(primary)
    }

    nonisolated static func readSnapshotAttempt(
        mutationStore: CredentialMutationStore,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy,
        flow: OAuthCredentialFlow
    ) -> Result<OAuthCredentialReadSnapshot, CredentialBundleError> {
        let access = primaryAttempt {
            try mutationStore.readSecret(
                account: accounts.access,
                interactionPolicy: interactionPolicy
            )
        }
        let refresh = primaryAttempt {
            try mutationStore.readSecret(
                account: accounts.refresh,
                interactionPolicy: interactionPolicy
            )
        }
        let id = primaryAttempt {
            try mutationStore.readSecret(
                account: accounts.id,
                interactionPolicy: interactionPolicy
            )
        }
        let accountID = primaryAttempt {
            try mutationStore.readSecret(
                account: accounts.accountID,
                interactionPolicy: interactionPolicy
            )
        }
        switch (access, refresh, id, accountID) {
        case let (.value(a), .value(r), .value(i), .value(account)):
            return .success(
                OAuthCredentialReadSnapshot(
                    accessToken: a,
                    refreshToken: r,
                    idToken: i,
                    accountID: account
                )
            )
        case (.failure(let status), _, _, _):
            return .failure(.preimageRead(flow: flow, status: status))
        case (_, .failure(let status), _, _):
            return .failure(.preimageRead(flow: flow, status: status))
        case (_, _, .failure(let status), _):
            return .failure(.preimageRead(flow: flow, status: status))
        case (_, _, _, .failure(let status)):
            return .failure(.preimageRead(flow: flow, status: status))
        }
    }

    nonisolated static func readAbsentEnvelopeAndSnapshot(
        mutationStore: CredentialMutationStore,
        accounts: OAuthCredentialAccounts,
        interactionPolicy: KeychainInteractionPolicy
    ) -> Result<OAuthCredentialReadSnapshot, CredentialBundleError> {
        switch primaryAttempt({
            try mutationStore.readSecret(
                account: accounts.verifier,
                interactionPolicy: interactionPolicy
            )
        }) {
        case .failure(let status):
            return .failure(.preimageRead(flow: .chatGPT, status: status))
        case .value(.some):
            return .failure(.preimageChanged(flow: .chatGPT))
        case .value(nil):
            return readSnapshotAttempt(
                mutationStore: mutationStore,
                accounts: accounts,
                interactionPolicy: interactionPolicy,
                flow: .chatGPT
            )
        }
    }

    nonisolated static func initialMutations(
        bundle: OAuthCredentialBundle,
        accounts: OAuthCredentialAccounts,
        snapshot: OAuthCredentialReadSnapshot
    ) -> [CredentialFieldMutation] {
        let idReplacement: SecretValue?
        let accountReplacement: SecretValue?
        switch bundle.flow {
        case .chatGPT:
            idReplacement = bundle.idToken
            accountReplacement = bundle.accountID
        case .generic:
            idReplacement = nil
            accountReplacement = nil
        }
        return [
            CredentialFieldMutation(
                account: accounts.access,
                kind: .access,
                preimage: snapshot.accessToken,
                replacement: bundle.accessToken
            ),
            CredentialFieldMutation(
                account: accounts.refresh,
                kind: .refresh,
                preimage: snapshot.refreshToken,
                replacement: bundle.refreshToken
            ),
            CredentialFieldMutation(
                account: accounts.id,
                kind: .id,
                preimage: snapshot.idToken,
                replacement: idReplacement
            ),
            CredentialFieldMutation(
                account: accounts.accountID,
                kind: .accountID,
                preimage: snapshot.accountID,
                replacement: accountReplacement
            ),
        ]
    }

    nonisolated static func refreshMutations(
        bundle: OAuthCredentialBundle,
        accounts: OAuthCredentialAccounts,
        snapshot: OAuthCredentialReadSnapshot
    ) -> [CredentialFieldMutation] {
        var fields = [
            CredentialFieldMutation(
                account: accounts.access,
                kind: .access,
                preimage: snapshot.accessToken,
                replacement: bundle.accessToken
            ),
        ]
        if let refresh = bundle.refreshToken {
            fields.append(
                CredentialFieldMutation(
                    account: accounts.refresh,
                    kind: .refresh,
                    preimage: snapshot.refreshToken,
                    replacement: refresh
                )
            )
        }
        if let id = bundle.idToken {
            fields.append(
                CredentialFieldMutation(
                    account: accounts.id,
                    kind: .id,
                    preimage: snapshot.idToken,
                    replacement: id
                )
            )
        }
        if let accountID = bundle.accountID {
            fields.append(
                CredentialFieldMutation(
                    account: accounts.accountID,
                    kind: .accountID,
                    preimage: snapshot.accountID,
                    replacement: accountID
                )
            )
        }
        return fields
    }

    nonisolated static func performTransaction(
        mutationStore: CredentialMutationStore,
        flow: OAuthCredentialFlow,
        envelopeAccount: String,
        preimageEnvelope: SecretValue?,
        committingEnvelope: SecretValue,
        fields: [CredentialFieldMutation],
        primaryError: (CredentialMutationKind, Int32?) -> CredentialBundleError
    ) -> CredentialTransactionOutcome {
        switch primaryAttempt({
            try mutationStore.set(
                committingEnvelope,
                account: envelopeAccount
            )
        }) {
        case .failure(let status):
            return .failed(
                primaryError(.oauthTransactionEnvelope, status)
            )
        case .value:
            break
        }

        var changed: [CredentialFieldMutation] = []
        for field in fields {
            let attempt: CredentialStoreAttempt<Void>
            if let replacement = field.replacement {
                attempt = primaryAttempt {
                    try mutationStore.set(
                        replacement,
                        account: field.account
                    )
                }
            } else {
                attempt = primaryAttempt {
                    try mutationStore.delete(account: field.account)
                }
            }
            switch attempt {
            case .value:
                changed.append(field)
            case .failure(let status):
                return rollbackAfterFailure(
                    mutationStore: mutationStore,
                    flow: flow,
                    envelopeAccount: envelopeAccount,
                    preimageEnvelope: preimageEnvelope,
                    changed: changed,
                    primary: primaryError(field.kind, status)
                )
            }
        }

        switch primaryAttempt({
            try mutationStore.delete(account: envelopeAccount)
        }) {
        case .failure(let status):
            return rollbackAfterFailure(
                mutationStore: mutationStore,
                flow: flow,
                envelopeAccount: envelopeAccount,
                preimageEnvelope: preimageEnvelope,
                changed: changed,
                primary: primaryError(.oauthTransactionEnvelope, status)
            )
        case .value:
            return .committed(
                CredentialMutationReceipt(
                    mutationCount: fields.count + 2
                )
            )
        }
    }

    nonisolated static func rollbackAfterFailure(
        mutationStore: CredentialMutationStore,
        flow: OAuthCredentialFlow,
        envelopeAccount: String,
        preimageEnvelope: SecretValue?,
        changed: [CredentialFieldMutation],
        primary: CredentialBundleError
    ) -> CredentialTransactionOutcome {
        var rollbackFailed = false
        var rollbackStatus: Int32?
        for field in changed.reversed() {
            let attempt: CredentialStoreAttempt<Void>
            if let preimage = field.preimage {
                attempt = rollbackAttempt {
                    try mutationStore.set(preimage, account: field.account)
                }
            } else {
                attempt = rollbackAttempt {
                    try mutationStore.delete(account: field.account)
                }
            }
            if case .failure(let status) = attempt, !rollbackFailed {
                rollbackFailed = true
                rollbackStatus = status
            }
        }
        if rollbackFailed {
            return .failed(.rollback(flow: flow, status: rollbackStatus))
        }

        let envelopeAttempt: CredentialStoreAttempt<Void>
        if let preimageEnvelope {
            envelopeAttempt = rollbackAttempt {
                try mutationStore.set(
                    preimageEnvelope,
                    account: envelopeAccount
                )
            }
        } else {
            envelopeAttempt = rollbackAttempt {
                try mutationStore.delete(account: envelopeAccount)
            }
        }
        switch envelopeAttempt {
        case .failure(let status):
            return .failed(.rollback(flow: flow, status: status))
        case .value:
            return .failed(primary)
        }
    }

    nonisolated static func unwrap(
        _ outcome: CredentialTransactionOutcome
    ) throws -> CredentialMutationReceipt {
        switch outcome {
        case .committed(let receipt): return receipt
        case .failed(let error): throw error
        }
    }
}

fileprivate enum OAuthRefreshResponseParser {
    static func parse(_ data: Data) -> Result<OAuthCredentialBundle, Error> {
        let objectAttempt = Result {
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        let object: [String: Any]
        switch objectAttempt {
        case .failure:
            return .failure(RuntimeOAuthBoundaryError.malformedTokenResponse)
        case .success(.none):
            return .failure(RuntimeOAuthBoundaryError.malformedTokenResponse)
        case .success(.some(let value)):
            object = value
        }
        guard let accessRaw = object["access_token"] as? String,
              let access = SecretValue.validated(accessRaw)
        else {
            return .failure(RuntimeOAuthBoundaryError.malformedTokenResponse)
        }
        let refresh: SecretValue?
        if let raw = object["refresh_token"] as? String {
            guard let value = SecretValue.validated(raw) else {
                return .failure(
                    RuntimeOAuthBoundaryError.malformedTokenResponse
                )
            }
            refresh = value
        } else {
            refresh = nil
        }
        let id: SecretValue?
        if let raw = object["id_token"] as? String {
            guard let value = SecretValue.validated(raw) else {
                return .failure(
                    RuntimeOAuthBoundaryError.malformedTokenResponse
                )
            }
            id = value
        } else {
            id = nil
        }
        let accountID: SecretValue?
        if let id {
            let value = id.use { idToken in
                access.use { accessToken in
                    OpenAIChatGPTAuth.chatGPTAccountID(
                        idToken: idToken,
                        accessToken: accessToken
                    )
                }
            }
            if let value, let secret = SecretValue.validated(value) {
                accountID = secret
            } else {
                return .failure(RuntimeOAuthBoundaryError.accountIDMissing)
            }
        } else {
            accountID = nil
        }
        return .success(
            OAuthCredentialBundle(
                flow: .chatGPT,
                accessToken: access,
                refreshToken: refresh,
                idToken: id,
                accountID: accountID
            )
        )
    }
}

public actor OpenAIOAuthSession {
    private let coordinator: CredentialBundleCoordinator
    private let accounts: OAuthCredentialAccounts
    private let failureReporter: FailureReporter?
    private let traceFactory: OperationTraceFactory?
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
        let access = SynchronizedCredentialAccess(store: store)
        coordinator = CredentialBundleCoordinator(access: access)
        accounts = OAuthCredentialAccounts.compatibility(
            access: accessTokenAccount,
            refresh: refreshTokenAccount,
            id: idTokenAccount,
            accountID: chatGPTAccountIDAccount
        )
        failureReporter = nil
        traceFactory = nil
        self.tokenEndpoint = tokenEndpoint
        self.session = session
        self.onPermanentFailure = onPermanentFailure
    }

    package init(
        coordinator: CredentialBundleCoordinator,
        accounts: OAuthCredentialAccounts,
        failureReporter: FailureReporter,
        traceFactory: OperationTraceFactory,
        tokenEndpoint: URL = OpenAIChatGPTAuth.tokenEndpoint,
        session: URLSession = .shared,
        onPermanentFailure: (@Sendable () -> Void)? = nil
    ) {
        self.coordinator = coordinator
        self.accounts = accounts
        self.failureReporter = failureReporter
        self.traceFactory = traceFactory
        self.tokenEndpoint = tokenEndpoint
        self.session = session
        self.onPermanentFailure = onPermanentFailure
    }

    public func refreshedAccessToken() async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }
        let refreshTrace = traceFactory?.generated(
            operation: .oauthRefreshCommit,
            scope: .fixed(.oauth)
        )
        let task = Task<String, Error> {
            try await self.refreshAccessTokenResult(
                refreshTrace: refreshTrace
            ).get()
        }
        inFlight = task
        let result = await task.result
        inFlight = nil
        return try result.get()
    }

    private func refreshAccessTokenResult(
        refreshTrace: OperationTrace?
    ) async -> Result<String, Error> {
        let readResult = await Task {
            try await coordinator.readRefreshCredential(
                accounts: accounts,
                interactionPolicy: .failIfInteractionRequired
            )
        }.result
        let read: OAuthRefreshCredentialRead
        switch readResult {
        case .failure(let error):
            return capturedFailure(error, trace: refreshTrace)
        case .success(nil):
            onPermanentFailure?()
            return capturedFailure(
                ProviderError.unauthorized,
                trace: refreshTrace
            )
        case .success(.some(let value)):
            read = value
        }

        let refreshRaw = read.refreshToken.use { $0 }
        guard let body = OpenAIChatGPTAuth.refreshTokenRequestBody(
            refreshToken: refreshRaw
        ) else {
            return capturedFailure(
                RuntimeOAuthBoundaryError.formEncoding,
                trace: refreshTrace
            )
        }
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let networkResult = await Task {
            try await session.data(for: request)
        }.result
        let data: Data
        let response: URLResponse
        switch networkResult {
        case .failure(let error):
            return capturedFailure(error, trace: refreshTrace)
        case .success(let value):
            (data, response) = value
        }
        guard let http = response as? HTTPURLResponse else {
            return capturedFailure(
                RuntimeOAuthBoundaryError.nonHTTPResponse,
                trace: refreshTrace
            )
        }
        switch http.statusCode {
        case 200..<300:
            let bundleResult = OAuthRefreshResponseParser.parse(data)
            let bundle: OAuthCredentialBundle
            switch bundleResult {
            case .failure(let error):
                return capturedFailure(error, trace: refreshTrace)
            case .success(let value):
                bundle = value
            }
            let commitResult = await Task {
                try await coordinator.commitRefresh(
                    bundle,
                    basedOn: read,
                    interactionPolicy: .failIfInteractionRequired
                )
            }.result
            switch commitResult {
            case .failure(let error):
                return capturedFailure(error, trace: refreshTrace)
            case .success:
                return .success(bundle.accessToken.use { $0 })
            }
        case 400, 401, 403:
            let deleteTrace = traceFactory?.generated(
                operation: .oauthUnauthorizedDelete,
                scope: .fixed(.oauth)
            )
            let deleteResult = await Task {
                try await coordinator.deleteUnauthorizedAccess(
                    basedOn: read,
                    interactionPolicy: .failIfInteractionRequired
                )
            }.result
            switch deleteResult {
            case .failure(let error):
                return capturedFailure(error, trace: deleteTrace)
            case .success:
                onPermanentFailure?()
                return capturedFailure(
                    ProviderError.unauthorized,
                    trace: refreshTrace
                )
            }
        default:
            let error: RuntimeOAuthBoundaryError
            if let status = ValidatedHTTPStatus.recognizingDiagnostic(
                http.statusCode
            ) {
                error = .httpStatus(status)
            } else {
                error = .nonHTTPResponse
            }
            return capturedFailure(error, trace: refreshTrace)
        }
    }

    private func capturedFailure(
        _ error: any Error,
        trace: OperationTrace?
    ) -> Result<String, Error> {
        if let failureReporter, let trace {
            _ = failureReporter.capture(error, trace: trace)
        }
        return .failure(error)
    }
}
