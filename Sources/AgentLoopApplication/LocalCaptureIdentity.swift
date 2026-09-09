import Foundation
import AgentLoopCore

package protocol LocalCaptureIdentityStore: Sendable {
    func getOrCreateCanonicalUUID(
        forKey key: String,
        makeUUID: @Sendable () -> UUID
    ) throws -> String
}

package final class LockedUserDefaultsCaptureIdentityStore:
    LocalCaptureIdentityStore, @unchecked Sendable
{
    private static let lock = NSLock()
    private let defaults: UserDefaults

    package init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    package func getOrCreateCanonicalUUID(
        forKey key: String,
        makeUUID: @Sendable () -> UUID
    ) throws -> String {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        if let existing = defaults.object(forKey: key) {
            guard let stored = existing as? String else {
                throw P1ContractValidationError.invalidIdentifier
            }
            try CanonicalContractCodingV1.validateCanonicalUUID(stored)
            return stored
        }

        let generated = makeUUID().uuidString
        try CanonicalContractCodingV1.validateCanonicalUUID(generated)
        defaults.set(generated, forKey: key)
        guard let persisted = defaults.object(forKey: key) as? String,
              persisted == generated
        else {
            throw P1ContractValidationError.invalidIdentifier
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(persisted)
        return persisted
    }
}

package struct LocalCaptureIdentity: Sendable {
    private static let storageKey = "agentloop.localCaptureInstallationId"

    private let store: any LocalCaptureIdentityStore
    private let makeUUID: @Sendable () -> UUID

    package init(
        store: any LocalCaptureIdentityStore,
        makeUUID: @escaping @Sendable () -> UUID
    ) {
        self.store = store
        self.makeUUID = makeUUID
    }

    package static func live() -> Self {
        Self(
            store: LockedUserDefaultsCaptureIdentityStore(
                defaults: .standard
            ),
            makeUUID: { UUID() }
        )
    }

    package func installationID() throws -> String {
        try store.getOrCreateCanonicalUUID(
            forKey: Self.storageKey,
            makeUUID: makeUUID
        )
    }
}
