import CryptoKit
import Darwin
import Foundation
import GRDB

package enum UnresolvedArtifactReasonV1: Sendable, Equatable {
    case unknownMissing
    case symlink
    case permissionDenied
    case managedRootUnavailable
    case irregularFile
    case identityDrift
    case contentDrift
    case incompleteRootSet
    case ambiguousHardlink
}

package struct ManagedArtifactRootDescriptorV1: Sendable, Equatable {
    package let rootId: String
    package let campId: String
    package let rootURL: URL

    private init(rootId: String, campId: String, rootURL: URL) {
        self.rootId = rootId
        self.campId = campId
        self.rootURL = rootURL
    }

    package static func registered(
        rootId: String,
        campId: String,
        rootURL: URL
    ) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(rootId)
        try CanonicalContractCodingV1.validateCampID(campId)
        guard rootURL.isFileURL,
              rootURL.baseURL == nil,
              rootURL.path.hasPrefix("/")
        else {
            throw P1ContractValidationError.invalidValue
        }
        return Self(rootId: rootId, campId: campId, rootURL: rootURL)
    }
}

package struct ManagedArtifactRootSnapshotV1: Sendable, Equatable {
    package let generation: Int
    package let rootSetHash: String
    package let roots: [ManagedArtifactRootDescriptorV1]

    private init(
        generation: Int,
        rootSetHash: String,
        roots: [ManagedArtifactRootDescriptorV1]
    ) {
        self.generation = generation
        self.rootSetHash = rootSetHash
        self.roots = roots
    }

    package static func frozen(
        generation: Int,
        rootSetHash: String,
        roots: [ManagedArtifactRootDescriptorV1]
    ) throws -> Self {
        try CanonicalContractCodingV1.validatePositive(generation)
        try CanonicalContractCodingV1.validateLowercaseHash(rootSetHash)

        let pairs = roots.map {
            ManagedArtifactRootPairV1(rootId: $0.rootId, campId: $0.campId)
        }
        guard Set(pairs).count == pairs.count,
              roots == roots.sorted(by: rootOrderPrecedes)
        else {
            throw P1ContractValidationError.invalidMembership
        }

        let material = ManagedArtifactRootSetHashMaterialV1(
            generation: generation,
            roots: roots.map {
                ManagedArtifactRootHashMaterialV1(
                    campId: $0.campId,
                    rootId: $0.rootId,
                    standardizedAbsolutePath: $0.rootURL
                        .standardizedFileURL.path
                )
            }
        )
        guard try CanonicalContractCodingV1.hash(material) == rootSetHash else {
            throw P1ContractValidationError.invalidHash
        }

        return Self(
            generation: generation,
            rootSetHash: rootSetHash,
            roots: roots
        )
    }
}

package struct VerifiedManagedArtifactEvidenceV1: Sendable, Equatable {
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let managedRootId: String
    package let objectId: String
    package let contentHash: String
    package let fileIdentityHash: String
    package let rootSetHash: String
    package let registryGeneration: Int
    package let verifiedAt: Date

    fileprivate init(
        artifactId: String,
        campId: String,
        originVersion: Int,
        managedRootId: String,
        objectId: String,
        contentHash: String,
        fileIdentityHash: String,
        rootSetHash: String,
        registryGeneration: Int,
        verifiedAt: Date
    ) {
        self.artifactId = artifactId
        self.campId = campId
        self.originVersion = originVersion
        self.managedRootId = managedRootId
        self.objectId = objectId
        self.contentHash = contentHash
        self.fileIdentityHash = fileIdentityHash
        self.rootSetHash = rootSetHash
        self.registryGeneration = registryGeneration
        self.verifiedAt = verifiedAt
    }
}

package struct VerifiedManagedArtifactAlreadyAbsentEvidenceV1:
    Sendable, Equatable
{
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let managedRootId: String
    package let objectId: String
    package let contentHash: String
    package let fileIdentityHash: String
    package let rootSetHash: String
    package let registryGeneration: Int
    package let verifiedAt: Date

    fileprivate init(
        artifactId: String,
        campId: String,
        originVersion: Int,
        managedRootId: String,
        objectId: String,
        contentHash: String,
        fileIdentityHash: String,
        rootSetHash: String,
        registryGeneration: Int,
        verifiedAt: Date
    ) {
        self.artifactId = artifactId
        self.campId = campId
        self.originVersion = originVersion
        self.managedRootId = managedRootId
        self.objectId = objectId
        self.contentHash = contentHash
        self.fileIdentityHash = fileIdentityHash
        self.rootSetHash = rootSetHash
        self.registryGeneration = registryGeneration
        self.verifiedAt = verifiedAt
    }
}

package struct VerifiedWorkspaceExternalEvidenceV1: Sendable, Equatable {
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let originalRefHash: String
    package let contentHash: String
    package let fileIdentityHash: String
    package let rootSetHash: String
    package let registryGeneration: Int
    package let verifiedAt: Date

    fileprivate init(
        artifactId: String,
        campId: String,
        originVersion: Int,
        originalRefHash: String,
        contentHash: String,
        fileIdentityHash: String,
        rootSetHash: String,
        registryGeneration: Int,
        verifiedAt: Date
    ) {
        self.artifactId = artifactId
        self.campId = campId
        self.originVersion = originVersion
        self.originalRefHash = originalRefHash
        self.contentHash = contentHash
        self.fileIdentityHash = fileIdentityHash
        self.rootSetHash = rootSetHash
        self.registryGeneration = registryGeneration
        self.verifiedAt = verifiedAt
    }
}

package struct UnresolvedArtifactEvidenceV1: Sendable, Equatable {
    package let artifactId: String
    package let campId: String
    package let originVersion: Int
    package let reason: UnresolvedArtifactReasonV1
    package let rootSetHash: String
    package let registryGeneration: Int
    package let observedAt: Date

    fileprivate init(
        artifactId: String,
        campId: String,
        originVersion: Int,
        reason: UnresolvedArtifactReasonV1,
        rootSetHash: String,
        registryGeneration: Int,
        observedAt: Date
    ) {
        self.artifactId = artifactId
        self.campId = campId
        self.originVersion = originVersion
        self.reason = reason
        self.rootSetHash = rootSetHash
        self.registryGeneration = registryGeneration
        self.observedAt = observedAt
    }
}

package enum ArtifactOwnershipVerificationV1: Sendable, Equatable {
    case managed(VerifiedManagedArtifactEvidenceV1)
    case managedAlreadyAbsent(
        VerifiedManagedArtifactAlreadyAbsentEvidenceV1
    )
    case workspaceExternal(VerifiedWorkspaceExternalEvidenceV1)
    case unresolved(UnresolvedArtifactEvidenceV1)
}

package enum ArtifactOriginUpgradeEvidenceV1: Sendable, Equatable {
    case managed(VerifiedManagedArtifactEvidenceV1)
    case verifiedOutsideAllManagedRoots(
        VerifiedWorkspaceExternalEvidenceV1
    )
}

package final class ArtifactOwnershipVerifier: @unchecked Sendable {
    private let database: AppDatabase
    private let roots: ManagedArtifactRootSnapshotV1
    private let beforeFinalSnapshotValidation:
        (@Sendable () throws -> Void)?

    package init(
        database: AppDatabase,
        roots: ManagedArtifactRootSnapshotV1,
        beforeFinalSnapshotValidation:
            (@Sendable () throws -> Void)? = nil
    ) {
        self.database = database
        self.roots = roots
        self.beforeFinalSnapshotValidation = beforeFinalSnapshotValidation
    }

    package func verify(
        artifactId: String,
        expectedOriginVersion: Int
    ) throws -> ArtifactOwnershipVerificationV1 {
        try CanonicalContractCodingV1.validateNonempty(artifactId)
        try CanonicalContractCodingV1.validatePositive(expectedOriginVersion)

        let databaseSnapshot = try loadDatabaseSnapshot(
            artifactId: artifactId,
            expectedOriginVersion: expectedOriginVersion
        )
        let observedAt = Date()
        guard databaseSnapshot.origin.campId == databaseSnapshot.campId else {
            return unresolved(
                databaseSnapshot,
                reason: .ambiguousHardlink,
                observedAt: observedAt
            )
        }
        guard databaseSnapshot.origin.state == .active else {
            return unresolved(
                databaseSnapshot,
                reason: .identityDrift,
                observedAt: observedAt
            )
        }
        guard try hasValidReferenceAttestation(databaseSnapshot) else {
            return unresolved(
                databaseSnapshot,
                reason: .identityDrift,
                observedAt: observedAt
            )
        }

        let openedRoots: [OpenedManagedArtifactRootV1]
        do {
            openedRoots = try roots.roots.map { descriptor in
                let trustedIntermediateSymlinks = try NoFollowPathV1
                    .registeredRootIntermediateSymlinks(
                        descriptor.rootURL.path
                    )
                let opened = try NoFollowPathV1.openAbsolute(
                    descriptor.rootURL.path,
                    expecting: .directory,
                    trustedIntermediateSymlinks: trustedIntermediateSymlinks
                )
                return OpenedManagedArtifactRootV1(
                    descriptor: descriptor,
                    opened: opened,
                    trustedIntermediateSymlinks:
                        trustedIntermediateSymlinks,
                    treeFingerprint: try NoFollowPathV1.treeFingerprint(
                        directoryFD: opened.fileDescriptor
                    )
                )
            }
        } catch let failure as NoFollowPathFailureV1 {
            return unresolved(
                databaseSnapshot,
                reason: rootFailureReason(failure),
                observedAt: observedAt
            )
        }

        let trustedIntermediateSymlinks = Set(
            openedRoots.flatMap(\.trustedIntermediateSymlinks)
        )

        let openedArtifact: OpenedNoFollowPathV1
        do {
            openedArtifact = try NoFollowPathV1.openAbsolute(
                databaseSnapshot.artifact.path,
                expecting: .regularFile,
                trustedIntermediateSymlinks: trustedIntermediateSymlinks
            )
        } catch let failure as NoFollowPathFailureV1 {
            if failure == .missing,
               let verification = try managedAlreadyAbsentVerification(
                   databaseSnapshot,
                   openedRoots: openedRoots,
                   observedAt: observedAt
               )
            {
                return verification
            }
            return unresolved(
                databaseSnapshot,
                reason: artifactFailureReason(failure),
                observedAt: observedAt
            )
        }

        let initialFileSnapshot = openedArtifact.snapshot
        guard initialFileSnapshot.linkCount == 1 else {
            return unresolved(
                databaseSnapshot,
                reason: .ambiguousHardlink,
                observedAt: observedAt
            )
        }

        let contentHash: String
        do {
            contentHash = try NoFollowPathV1.contentHash(
                fileDescriptor: openedArtifact.fileDescriptor
            )
        } catch let failure as NoFollowPathFailureV1 {
            return unresolved(
                databaseSnapshot,
                reason: artifactFailureReason(failure),
                observedAt: observedAt
            )
        }
        let fileIdentityHash = initialFileSnapshot.identity.hash

        if try hasPendingOrCrossCampIdentity(
            databaseSnapshot,
            contentHash: contentHash,
            fileIdentityHash: fileIdentityHash
        ) {
            return unresolved(
                databaseSnapshot,
                reason: .ambiguousHardlink,
                observedAt: observedAt
            )
        }

        let matchedRoots = openedRoots.compactMap { root -> RootMatchV1? in
            guard let ancestor = openedArtifact.ancestors.first(where: {
                $0.identity == root.opened.snapshot.identity
            }) else {
                return nil
            }
            let objectComponents = openedArtifact.components.dropFirst(
                ancestor.componentCount
            )
            guard !objectComponents.isEmpty else { return nil }
            return RootMatchV1(
                root: root,
                objectId: objectComponents.joined(separator: "/")
            )
        }

        let classification: ArtifactPathClassificationV1
        switch matchedRoots.count {
        case 0:
            guard databaseSnapshot.origin.storageClass != .managed else {
                return unresolved(
                    databaseSnapshot,
                    reason: .identityDrift,
                    observedAt: observedAt
                )
            }
            classification = .workspaceExternal
        case 1:
            let match = matchedRoots[0]
            guard match.root.descriptor.campId == databaseSnapshot.campId else {
                return unresolved(
                    databaseSnapshot,
                    reason: .ambiguousHardlink,
                    observedAt: observedAt
                )
            }
            if databaseSnapshot.origin.storageClass == .workspaceExternal {
                return unresolved(
                    databaseSnapshot,
                    reason: .ambiguousHardlink,
                    observedAt: observedAt
                )
            }
            if databaseSnapshot.origin.storageClass == .managed {
                guard databaseSnapshot.origin.managedRootId
                        == match.root.descriptor.rootId,
                      databaseSnapshot.origin.objectId == match.objectId,
                      databaseSnapshot.origin.fileIdentityHash
                        == fileIdentityHash
                else {
                    return unresolved(
                        databaseSnapshot,
                        reason: .identityDrift,
                        observedAt: observedAt
                    )
                }
                guard databaseSnapshot.origin.contentHash == contentHash else {
                    return unresolved(
                        databaseSnapshot,
                        reason: .contentDrift,
                        observedAt: observedAt
                    )
                }
            }
            classification = .managed(match)
        default:
            let camps = Set(matchedRoots.map(\.root.descriptor.campId))
            return unresolved(
                databaseSnapshot,
                reason: camps.count > 1
                    ? .ambiguousHardlink
                    : .incompleteRootSet,
                observedAt: observedAt
            )
        }

        try beforeFinalSnapshotValidation?()

        if let reason = try finalSnapshotFailure(
            databaseSnapshot,
            openedRoots: openedRoots,
            initialFileSnapshot: initialFileSnapshot,
            contentHash: contentHash,
            fileIdentityHash: fileIdentityHash,
            missingManagedLocator: nil
        ) {
            return unresolved(
                databaseSnapshot,
                reason: reason,
                observedAt: Date()
            )
        }

        let verifiedAt = Date()
        switch classification {
        case .managed(let match):
            return .managed(
                VerifiedManagedArtifactEvidenceV1(
                    artifactId: databaseSnapshot.artifact.id,
                    campId: databaseSnapshot.campId,
                    originVersion: databaseSnapshot.origin.version,
                    managedRootId: match.root.descriptor.rootId,
                    objectId: match.objectId,
                    contentHash: contentHash,
                    fileIdentityHash: fileIdentityHash,
                    rootSetHash: roots.rootSetHash,
                    registryGeneration: roots.generation,
                    verifiedAt: verifiedAt
                )
            )
        case .workspaceExternal:
            return .workspaceExternal(
                VerifiedWorkspaceExternalEvidenceV1(
                    artifactId: databaseSnapshot.artifact.id,
                    campId: databaseSnapshot.campId,
                    originVersion: databaseSnapshot.origin.version,
                    originalRefHash: databaseSnapshot.origin.originalRefHash,
                    contentHash: contentHash,
                    fileIdentityHash: fileIdentityHash,
                    rootSetHash: roots.rootSetHash,
                    registryGeneration: roots.generation,
                    verifiedAt: verifiedAt
                )
            )
        }
    }

    private func loadDatabaseSnapshot(
        artifactId: String,
        expectedOriginVersion: Int
    ) throws -> ArtifactOwnershipDatabaseSnapshotV1 {
        try database.pool.read { database in
            guard let artifact = try ArtifactRecord.fetchOne(
                database,
                key: artifactId
            ) else {
                throw RecordNotFoundError(table: "artifact", id: artifactId)
            }
            guard let origin = try ArtifactStorageOriginRecord.fetchOne(
                database,
                key: artifactId
            ) else {
                throw RecordNotFoundError(
                    table: ArtifactStorageOriginRecord.databaseTableName,
                    id: artifactId
                )
            }
            guard origin.version == expectedOriginVersion else {
                throw P1ContractValidationError.invalidValue
            }
            guard let campId = try String.fetchOne(
                database,
                sql: """
                    SELECT s.campId
                    FROM artifact a
                    JOIN card c ON c.id = a.cardId
                    JOIN mission m ON m.id = c.missionId
                    JOIN squad s ON s.id = m.squadId
                    WHERE a.id = ?
                    """,
                arguments: [artifactId]
            ) else {
                throw P1ContractValidationError.invalidMembership
            }
            return ArtifactOwnershipDatabaseSnapshotV1(
                artifact: artifact,
                origin: origin,
                campId: campId
            )
        }
    }

    private func hasPendingOrCrossCampIdentity(
        _ snapshot: ArtifactOwnershipDatabaseSnapshotV1,
        contentHash: String,
        fileIdentityHash: String
    ) throws -> Bool {
        try database.pool.read { database in
            let pending = try Bool.fetchOne(
                database,
                sql: """
                    SELECT EXISTS(
                      SELECT 1
                      FROM engine_proposal_artifact pa
                      JOIN engine_terminal_proposal p ON p.id = pa.proposalId
                      WHERE p.state = 'pending'
                        AND (pa.artifactId = ? OR pa.contentHash = ?)
                    )
                    """,
                arguments: [snapshot.artifact.id, contentHash]
            ) ?? false
            if pending { return true }

            let conflictingOrigin = try Bool.fetchOne(
                database,
                sql: """
                    SELECT EXISTS(
                      SELECT 1
                      FROM artifact_storage_origin o
                      JOIN artifact a ON a.id = o.artifactId
                      WHERE o.state = 'active'
                        AND o.artifactId <> ?
                        AND (
                          a.path = ?
                          OR o.fileIdentityHash = ?
                        )
                    )
                    """,
                arguments: [
                    snapshot.artifact.id,
                    snapshot.artifact.path,
                    fileIdentityHash,
                ]
            ) ?? false
            if conflictingOrigin { return true }

            return try Bool.fetchOne(
                database,
                sql: """
                    SELECT EXISTS(
                      SELECT 1
                      FROM artifact_blob_reference
                      WHERE state = 'active'
                        AND campId <> ?
                        AND contentHash = ?
                    )
                    """,
                arguments: [snapshot.campId, contentHash]
            ) ?? false
        }
    }

    private func managedAlreadyAbsentVerification(
        _ snapshot: ArtifactOwnershipDatabaseSnapshotV1,
        openedRoots: [OpenedManagedArtifactRootV1],
        observedAt: Date
    ) throws -> ArtifactOwnershipVerificationV1? {
        guard snapshot.origin.storageClass == .managed else { return nil }
        guard snapshot.origin.evidenceKind == .typedPreparedArtifact
                || snapshot.origin.evidenceKind
                    == .verifiedManagedRootCapability,
              let managedRootId = snapshot.origin.managedRootId,
              let objectId = snapshot.origin.objectId,
              let contentHash = snapshot.origin.contentHash,
              let fileIdentityHash = snapshot.origin.fileIdentityHash,
              let root = openedRoots.first(where: {
                $0.descriptor.rootId == managedRootId
                    && $0.descriptor.campId == snapshot.campId
              })
        else {
            return unresolved(
                snapshot,
                reason: .identityDrift,
                observedAt: observedAt
            )
        }

        if try hasPendingOrCrossCampIdentity(
            snapshot,
            contentHash: contentHash,
            fileIdentityHash: fileIdentityHash
        ) {
            return unresolved(
                snapshot,
                reason: .ambiguousHardlink,
                observedAt: observedAt
            )
        }
        do {
            if try openedRoots.contains(where: { openedRoot in
                try NoFollowPathV1.containsFileIdentity(
                    fileIdentityHash,
                    directoryFD: openedRoot.opened.fileDescriptor
                )
            }) {
                return unresolved(
                    snapshot,
                    reason: .ambiguousHardlink,
                    observedAt: observedAt
                )
            }
        } catch let failure as NoFollowPathFailureV1 {
            return unresolved(
                snapshot,
                reason: rootFailureReason(failure),
                observedAt: observedAt
            )
        }

        do {
            _ = try NoFollowPathV1.openRelative(
                objectId,
                beneath: root.opened.fileDescriptor,
                expecting: .regularFile
            )
            return unresolved(
                snapshot,
                reason: .identityDrift,
                observedAt: observedAt
            )
        } catch let failure as NoFollowPathFailureV1 {
            guard failure == .missing else {
                return unresolved(
                    snapshot,
                    reason: artifactFailureReason(failure),
                    observedAt: observedAt
                )
            }
        }

        try beforeFinalSnapshotValidation?()
        if let reason = try finalSnapshotFailure(
            snapshot,
            openedRoots: openedRoots,
            initialFileSnapshot: nil,
            contentHash: contentHash,
            fileIdentityHash: fileIdentityHash,
            missingManagedLocator: MissingManagedLocatorV1(
                managedRootId: managedRootId,
                objectId: objectId
            )
        ) {
            return unresolved(
                snapshot,
                reason: reason,
                observedAt: Date()
            )
        }

        return .managedAlreadyAbsent(
            VerifiedManagedArtifactAlreadyAbsentEvidenceV1(
                artifactId: snapshot.artifact.id,
                campId: snapshot.campId,
                originVersion: snapshot.origin.version,
                managedRootId: managedRootId,
                objectId: objectId,
                contentHash: contentHash,
                fileIdentityHash: fileIdentityHash,
                rootSetHash: roots.rootSetHash,
                registryGeneration: roots.generation,
                verifiedAt: Date()
            )
        )
    }

    private func hasValidReferenceAttestation(
        _ snapshot: ArtifactOwnershipDatabaseSnapshotV1
    ) throws -> Bool {
        let originalRefHash = CanonicalJSONV1.sha256Hex(
            Data(snapshot.artifact.path.utf8)
        )
        guard snapshot.origin.originalRefHash == originalRefHash else {
            return false
        }
        guard snapshot.origin.evidenceKind == .legacyUnknown else {
            return true
        }
        guard snapshot.origin.storageClass == .unresolved else { return false }
        return snapshot.origin.classificationEvidenceHash
            == (try CanonicalContractCodingV1.hash(
                LegacyArtifactVerifierAttestationV1(
                    schemaVersion: 1,
                    artifactId: snapshot.artifact.id,
                    cardId: snapshot.artifact.cardId,
                    campId: snapshot.origin.campId,
                    originalRefHash: originalRefHash
                )
            ))
    }

    private func finalSnapshotFailure(
        _ initial: ArtifactOwnershipDatabaseSnapshotV1,
        openedRoots: [OpenedManagedArtifactRootV1],
        initialFileSnapshot: FileSystemObjectSnapshotV1?,
        contentHash: String,
        fileIdentityHash: String,
        missingManagedLocator: MissingManagedLocatorV1?
    ) throws -> UnresolvedArtifactReasonV1? {
        let finalDatabaseSnapshot: ArtifactOwnershipDatabaseSnapshotV1
        do {
            finalDatabaseSnapshot = try loadDatabaseSnapshot(
                artifactId: initial.artifact.id,
                expectedOriginVersion: initial.origin.version
            )
        } catch {
            return .identityDrift
        }
        guard databaseSnapshotsMatch(initial, finalDatabaseSnapshot),
              try hasValidReferenceAttestation(finalDatabaseSnapshot)
        else {
            return .identityDrift
        }
        if try hasPendingOrCrossCampIdentity(
            finalDatabaseSnapshot,
            contentHash: contentHash,
            fileIdentityHash: fileIdentityHash
        ) {
            return .ambiguousHardlink
        }

        if let initialFileSnapshot {
            let trustedIntermediateSymlinks = Set(
                openedRoots.flatMap(\.trustedIntermediateSymlinks)
            )
            do {
                let reopenedArtifact = try NoFollowPathV1.openAbsolute(
                    finalDatabaseSnapshot.artifact.path,
                    expecting: .regularFile,
                    trustedIntermediateSymlinks: trustedIntermediateSymlinks
                )
                guard reopenedArtifact.snapshot.identity
                        == initialFileSnapshot.identity
                else {
                    return .identityDrift
                }
                guard reopenedArtifact.snapshot.linkCount == 1 else {
                    return .ambiguousHardlink
                }
                guard reopenedArtifact.snapshot == initialFileSnapshot,
                      try NoFollowPathV1.contentHash(
                        fileDescriptor: reopenedArtifact.fileDescriptor
                      ) == contentHash
                else {
                    return .contentDrift
                }
            } catch let failure as NoFollowPathFailureV1 {
                return artifactFailureReason(failure)
            }
        }

        var reopenedRoots: [OpenedManagedArtifactRootV1] = []
        reopenedRoots.reserveCapacity(openedRoots.count)
        for root in openedRoots {
            do {
                let reopened = try NoFollowPathV1.openAbsolute(
                    root.descriptor.rootURL.path,
                    expecting: .directory,
                    trustedIntermediateSymlinks:
                        root.trustedIntermediateSymlinks
                )
                guard reopened.snapshot.identity
                        == root.opened.snapshot.identity,
                      reopened.snapshot == root.opened.snapshot,
                      try NoFollowPathV1.treeFingerprint(
                        directoryFD: reopened.fileDescriptor
                      ) == root.treeFingerprint
                else {
                    return .incompleteRootSet
                }
                reopenedRoots.append(
                    OpenedManagedArtifactRootV1(
                        descriptor: root.descriptor,
                        opened: reopened,
                        trustedIntermediateSymlinks:
                            root.trustedIntermediateSymlinks,
                        treeFingerprint: root.treeFingerprint
                    )
                )
            } catch let failure as NoFollowPathFailureV1 {
                return rootFailureReason(failure)
            }
        }

        if let missingManagedLocator {
            do {
                if try reopenedRoots.contains(where: { root in
                    try NoFollowPathV1.containsFileIdentity(
                        fileIdentityHash,
                        directoryFD: root.opened.fileDescriptor
                    )
                }) {
                    return .ambiguousHardlink
                }
            } catch let failure as NoFollowPathFailureV1 {
                return rootFailureReason(failure)
            }
            guard let owningRoot = reopenedRoots.first(where: {
                $0.descriptor.rootId == missingManagedLocator.managedRootId
                    && $0.descriptor.campId == initial.campId
            }) else {
                return .incompleteRootSet
            }
            do {
                _ = try NoFollowPathV1.openRelative(
                    missingManagedLocator.objectId,
                    beneath: owningRoot.opened.fileDescriptor,
                    expecting: .regularFile
                )
                return .identityDrift
            } catch let failure as NoFollowPathFailureV1 {
                guard failure == .missing else {
                    return artifactFailureReason(failure)
                }
            }
        }
        return nil
    }

    private func databaseSnapshotsMatch(
        _ lhs: ArtifactOwnershipDatabaseSnapshotV1,
        _ rhs: ArtifactOwnershipDatabaseSnapshotV1
    ) -> Bool {
        lhs.campId == rhs.campId
            && lhs.artifact.id == rhs.artifact.id
            && lhs.artifact.cardId == rhs.artifact.cardId
            && lhs.artifact.path == rhs.artifact.path
            && lhs.artifact.kind == rhs.artifact.kind
            && lhs.artifact.label == rhs.artifact.label
            && lhs.artifact.createdAt == rhs.artifact.createdAt
            && lhs.origin == rhs.origin
    }

    private func unresolved(
        _ snapshot: ArtifactOwnershipDatabaseSnapshotV1,
        reason: UnresolvedArtifactReasonV1,
        observedAt: Date
    ) -> ArtifactOwnershipVerificationV1 {
        return .unresolved(
            UnresolvedArtifactEvidenceV1(
                artifactId: snapshot.artifact.id,
                campId: snapshot.campId,
                originVersion: snapshot.origin.version,
                reason: reason,
                rootSetHash: roots.rootSetHash,
                registryGeneration: roots.generation,
                observedAt: observedAt
            )
        )
    }

    private func artifactFailureReason(
        _ failure: NoFollowPathFailureV1
    ) -> UnresolvedArtifactReasonV1 {
        switch failure {
        case .missing:
            return .unknownMissing
        case .symlink:
            return .symlink
        case .permissionDenied:
            return .permissionDenied
        case .irregularFile, .invalidPath:
            return .irregularFile
        case .snapshotDrift, .ioFailure:
            return .identityDrift
        }
    }

    private func rootFailureReason(
        _ failure: NoFollowPathFailureV1
    ) -> UnresolvedArtifactReasonV1 {
        switch failure {
        case .snapshotDrift:
            return .incompleteRootSet
        case .missing, .symlink, .permissionDenied, .irregularFile,
             .invalidPath, .ioFailure:
            return .managedRootUnavailable
        }
    }
}

private struct ManagedArtifactRootPairV1: Hashable {
    let rootId: String
    let campId: String
}

private struct ManagedArtifactRootSetHashMaterialV1: Encodable {
    let generation: Int
    let roots: [ManagedArtifactRootHashMaterialV1]
}

private struct ManagedArtifactRootHashMaterialV1: Encodable {
    let campId: String
    let rootId: String
    let standardizedAbsolutePath: String
}

private func rootOrderPrecedes(
    _ lhs: ManagedArtifactRootDescriptorV1,
    _ rhs: ManagedArtifactRootDescriptorV1
) -> Bool {
    if lhs.rootId != rhs.rootId {
        return lhs.rootId.utf8.lexicographicallyPrecedes(rhs.rootId.utf8)
    }
    return lhs.campId.utf8.lexicographicallyPrecedes(rhs.campId.utf8)
}

private struct ArtifactOwnershipDatabaseSnapshotV1 {
    let artifact: ArtifactRecord
    let origin: ArtifactStorageOriginRecord
    let campId: String
}

private struct MissingManagedLocatorV1 {
    let managedRootId: String
    let objectId: String
}

private struct LegacyArtifactVerifierAttestationV1: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originalRefHash: String
}

private enum ArtifactPathClassificationV1 {
    case managed(RootMatchV1)
    case workspaceExternal
}

private struct RootMatchV1 {
    let root: OpenedManagedArtifactRootV1
    let objectId: String
}

private final class OpenedManagedArtifactRootV1 {
    let descriptor: ManagedArtifactRootDescriptorV1
    let opened: OpenedNoFollowPathV1
    let trustedIntermediateSymlinks: Set<TrustedIntermediateSymlinkV1>
    let treeFingerprint: String

    init(
        descriptor: ManagedArtifactRootDescriptorV1,
        opened: OpenedNoFollowPathV1,
        trustedIntermediateSymlinks: Set<TrustedIntermediateSymlinkV1>,
        treeFingerprint: String
    ) {
        self.descriptor = descriptor
        self.opened = opened
        self.trustedIntermediateSymlinks = trustedIntermediateSymlinks
        self.treeFingerprint = treeFingerprint
    }
}

private struct TrustedIntermediateSymlinkV1: Hashable {
    let rawPrefix: String
    let identity: FileSystemObjectIdentityV1
}

private enum NoFollowExpectedTypeV1 {
    case regularFile
    case directory
}

private enum NoFollowPathFailureV1: Error, Equatable {
    case missing
    case symlink
    case permissionDenied
    case irregularFile
    case invalidPath
    case snapshotDrift
    case ioFailure
}

private struct FileSystemObjectIdentityV1: Hashable {
    let device: UInt64
    let inode: UInt64
    let generation: UInt64
    let birthSeconds: Int64
    let birthNanoseconds: Int64
    let objectType: UInt32

    init(_ status: stat) {
        device = UInt64(bitPattern: Int64(status.st_dev))
        inode = UInt64(status.st_ino)
        generation = UInt64(status.st_gen)
        birthSeconds = Int64(status.st_birthtimespec.tv_sec)
        birthNanoseconds = Int64(status.st_birthtimespec.tv_nsec)
        objectType = UInt32(status.st_mode & mode_t(S_IFMT))
    }

    var hash: String {
        var hasher = SHA256()
        NoFollowHashMaterialV1.update(&hasher, byte: 1)
        NoFollowHashMaterialV1.update(&hasher, integer: device)
        NoFollowHashMaterialV1.update(&hasher, integer: inode)
        NoFollowHashMaterialV1.update(&hasher, integer: generation)
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: birthSeconds)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: birthNanoseconds)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(objectType)
        )
        return NoFollowHashMaterialV1.hex(hasher.finalize())
    }
}

private struct FileSystemObjectSnapshotV1: Equatable {
    let identity: FileSystemObjectIdentityV1
    let mode: UInt32
    let linkCount: UInt64
    let byteCount: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64

    init(_ status: stat) {
        identity = FileSystemObjectIdentityV1(status)
        mode = UInt32(status.st_mode)
        linkCount = UInt64(status.st_nlink)
        byteCount = status.st_size
        modificationSeconds = Int64(status.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(status.st_mtimespec.tv_nsec)
        changeSeconds = Int64(status.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(status.st_ctimespec.tv_nsec)
    }
}

private struct OpenedPathAncestorV1 {
    let identity: FileSystemObjectIdentityV1
    let componentCount: Int
}

private final class OpenedNoFollowPathV1 {
    let fileDescriptor: Int32
    let snapshot: FileSystemObjectSnapshotV1
    let components: [String]
    let ancestors: [OpenedPathAncestorV1]

    init(
        fileDescriptor: Int32,
        snapshot: FileSystemObjectSnapshotV1,
        components: [String],
        ancestors: [OpenedPathAncestorV1]
    ) {
        self.fileDescriptor = fileDescriptor
        self.snapshot = snapshot
        self.components = components
        self.ancestors = ancestors
    }

    deinit {
        Darwin.close(fileDescriptor)
    }
}

private enum NoFollowPathV1 {
    static func openAbsolute(
        _ path: String,
        expecting expectedType: NoFollowExpectedTypeV1,
        trustedIntermediateSymlinks: Set<TrustedIntermediateSymlinkV1> = []
    ) throws -> OpenedNoFollowPathV1 {
        guard path.hasPrefix("/"),
              !path.utf8.contains(0)
        else {
            throw NoFollowPathFailureV1.invalidPath
        }
        let components = try secureComponents(
            path.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        )
        if expectedType == .regularFile, components.isEmpty {
            throw NoFollowPathFailureV1.irregularFile
        }

        if !trustedIntermediateSymlinks.isEmpty {
            return try openThroughTrustedIntermediateSymlinks(
                path,
                expecting: expectedType,
                trustedIntermediateSymlinks: trustedIntermediateSymlinks
            )
        }

        let rootFD = Darwin.open(
            "/",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard rootFD >= 0 else { throw mapErrno(errno) }
        var rootStatus = stat()
        guard Darwin.fstat(rootFD, &rootStatus) == 0 else {
            let failure = mapErrno(errno)
            Darwin.close(rootFD)
            throw failure
        }

        if components.isEmpty {
            return OpenedNoFollowPathV1(
                fileDescriptor: rootFD,
                snapshot: FileSystemObjectSnapshotV1(rootStatus),
                components: [],
                ancestors: [
                    OpenedPathAncestorV1(
                        identity: FileSystemObjectIdentityV1(rootStatus),
                        componentCount: 0
                    ),
                ]
            )
        }

        return try openComponents(
            components,
            initialFD: rootFD,
            initialAncestors: [
                OpenedPathAncestorV1(
                    identity: FileSystemObjectIdentityV1(rootStatus),
                    componentCount: 0
                ),
            ],
            expecting: expectedType,
            closeInitialFD: true
        )
    }

    static func registeredRootIntermediateSymlinks(
        _ path: String
    ) throws -> Set<TrustedIntermediateSymlinkV1> {
        guard path.hasPrefix("/"), !path.utf8.contains(0) else {
            throw NoFollowPathFailureV1.invalidPath
        }
        let components = try secureComponents(
            path.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        )
        var result = Set<TrustedIntermediateSymlinkV1>()
        var prefix = ""
        for (index, component) in components.enumerated() {
            prefix += "/\(component)"
            var status = stat()
            guard Darwin.lstat(prefix, &status) == 0 else {
                throw mapErrno(errno)
            }
            if isSymbolicLink(status) {
                guard index < components.count - 1 else {
                    throw NoFollowPathFailureV1.symlink
                }
                result.insert(
                    TrustedIntermediateSymlinkV1(
                        rawPrefix: prefix,
                        identity: FileSystemObjectIdentityV1(status)
                    )
                )
            }
        }
        return result
    }

    static func openRelative(
        _ path: String,
        beneath rootFD: Int32,
        expecting expectedType: NoFollowExpectedTypeV1
    ) throws -> OpenedNoFollowPathV1 {
        guard !path.hasPrefix("/"), !path.utf8.contains(0) else {
            throw NoFollowPathFailureV1.invalidPath
        }
        let components = try secureComponents(
            path.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        )
        guard !components.isEmpty else {
            throw NoFollowPathFailureV1.invalidPath
        }
        let duplicated = Darwin.dup(rootFD)
        guard duplicated >= 0 else { throw mapErrno(errno) }
        _ = Darwin.fcntl(duplicated, F_SETFD, FD_CLOEXEC)
        return try openComponents(
            components,
            initialFD: duplicated,
            initialAncestors: [],
            expecting: expectedType,
            closeInitialFD: true
        )
    }

    static func contentHash(fileDescriptor: Int32) throws -> String {
        guard Darwin.lseek(fileDescriptor, 0, SEEK_SET) >= 0 else {
            throw mapErrno(errno)
        }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(
                    fileDescriptor,
                    bytes.baseAddress,
                    bytes.count
                )
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw mapErrno(errno)
            }
            hasher.update(data: Data(buffer.prefix(Int(count))))
        }
        return NoFollowHashMaterialV1.hex(hasher.finalize())
    }

    static func treeFingerprint(directoryFD: Int32) throws -> String {
        var rootStatus = stat()
        guard Darwin.fstat(directoryFD, &rootStatus) == 0 else {
            throw mapErrno(errno)
        }
        guard isDirectory(rootStatus) else {
            throw NoFollowPathFailureV1.irregularFile
        }

        var hasher = SHA256()
        var visited = Set<FileSystemObjectIdentityV1>()
        try fingerprintDirectory(
            directoryFD,
            status: rootStatus,
            relativeComponents: [],
            visited: &visited,
            hasher: &hasher
        )
        return NoFollowHashMaterialV1.hex(hasher.finalize())
    }

    static func containsFileIdentity(
        _ expectedIdentityHash: String,
        directoryFD: Int32
    ) throws -> Bool {
        var rootStatus = stat()
        guard Darwin.fstat(directoryFD, &rootStatus) == 0 else {
            throw mapErrno(errno)
        }
        guard isDirectory(rootStatus) else {
            throw NoFollowPathFailureV1.irregularFile
        }
        var visited = Set<FileSystemObjectIdentityV1>()
        return try directoryContainsFileIdentity(
            directoryFD,
            status: rootStatus,
            expectedIdentityHash: expectedIdentityHash,
            visited: &visited
        )
    }

    private static func openThroughTrustedIntermediateSymlinks(
        _ path: String,
        expecting expectedType: NoFollowExpectedTypeV1,
        trustedIntermediateSymlinks: Set<TrustedIntermediateSymlinkV1>
    ) throws -> OpenedNoFollowPathV1 {
        try auditIntermediateSymlinks(
            path,
            trustedIntermediateSymlinks: trustedIntermediateSymlinks
        )
        let resolvedPath = try resolveTrustedIntermediateSymlinks(
            path,
            trustedIntermediateSymlinks: trustedIntermediateSymlinks
        )
        let verified = try openAbsolute(
            resolvedPath,
            expecting: expectedType
        )
        try auditIntermediateSymlinks(
            path,
            trustedIntermediateSymlinks: trustedIntermediateSymlinks
        )
        return verified
    }

    private static func resolveTrustedIntermediateSymlinks(
        _ path: String,
        trustedIntermediateSymlinks: Set<TrustedIntermediateSymlinkV1>
    ) throws -> String {
        let components = try secureComponents(
            path.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        )
        var resolved: [String] = []
        var rawPrefix = ""

        for (index, component) in components.enumerated() {
            rawPrefix += "/\(component)"
            var status = stat()
            guard Darwin.lstat(rawPrefix, &status) == 0 else {
                throw mapErrno(errno)
            }
            guard isSymbolicLink(status) else {
                resolved.append(component)
                continue
            }
            guard index < components.count - 1 else {
                throw NoFollowPathFailureV1.symlink
            }
            let observed = TrustedIntermediateSymlinkV1(
                rawPrefix: rawPrefix,
                identity: FileSystemObjectIdentityV1(status)
            )
            guard trustedIntermediateSymlinks.contains(observed) else {
                throw NoFollowPathFailureV1.symlink
            }

            var targetBuffer = [UInt8](
                repeating: 0,
                count: Int(MAXPATHLEN)
            )
            let byteCount = targetBuffer.withUnsafeMutableBytes { bytes in
                Darwin.readlink(
                    rawPrefix,
                    bytes.baseAddress?.assumingMemoryBound(to: CChar.self),
                    bytes.count
                )
            }
            guard byteCount >= 0 else { throw mapErrno(errno) }
            guard byteCount < targetBuffer.count else {
                throw NoFollowPathFailureV1.invalidPath
            }
            let target = String(
                decoding: targetBuffer.prefix(Int(byteCount)),
                as: UTF8.self
            )
            let targetComponents = target
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
            if target.hasPrefix("/") {
                resolved.removeAll(keepingCapacity: true)
            }
            for targetComponent in targetComponents {
                switch targetComponent {
                case ".":
                    continue
                case "..":
                    guard !resolved.isEmpty else {
                        throw NoFollowPathFailureV1.invalidPath
                    }
                    resolved.removeLast()
                default:
                    guard !targetComponent.utf8.contains(0) else {
                        throw NoFollowPathFailureV1.invalidPath
                    }
                    resolved.append(targetComponent)
                }
            }
        }
        return "/" + resolved.joined(separator: "/")
    }

    private static func auditIntermediateSymlinks(
        _ path: String,
        trustedIntermediateSymlinks: Set<TrustedIntermediateSymlinkV1>
    ) throws {
        let components = try secureComponents(
            path.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        )
        var prefix = ""
        for (index, component) in components.enumerated() {
            prefix += "/\(component)"
            var status = stat()
            guard Darwin.lstat(prefix, &status) == 0 else {
                throw mapErrno(errno)
            }
            guard isSymbolicLink(status) else { continue }
            guard index < components.count - 1 else {
                throw NoFollowPathFailureV1.symlink
            }
            let observed = TrustedIntermediateSymlinkV1(
                rawPrefix: prefix,
                identity: FileSystemObjectIdentityV1(status)
            )
            guard trustedIntermediateSymlinks.contains(observed) else {
                throw NoFollowPathFailureV1.symlink
            }
        }
    }

    private static func openComponents(
        _ components: [String],
        initialFD: Int32,
        initialAncestors: [OpenedPathAncestorV1],
        expecting expectedType: NoFollowExpectedTypeV1,
        closeInitialFD: Bool
    ) throws -> OpenedNoFollowPathV1 {
        var currentFD = initialFD
        var currentIsOwned = closeInitialFD
        var ancestors = initialAncestors
        defer {
            if currentIsOwned { Darwin.close(currentFD) }
        }

        for (index, component) in components.enumerated() {
            let isFinal = index == components.count - 1
            var noFollowStatus = stat()
            let statusResult = component.withCString { name in
                Darwin.fstatat(
                    currentFD,
                    name,
                    &noFollowStatus,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard statusResult == 0 else { throw mapErrno(errno) }
            if isSymbolicLink(noFollowStatus) {
                throw NoFollowPathFailureV1.symlink
            }
            if !isFinal, !isDirectory(noFollowStatus) {
                throw NoFollowPathFailureV1.irregularFile
            }

            let flags: Int32
            if isFinal, expectedType == .regularFile {
                flags = O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW
            } else {
                flags = O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            }
            let nextFD = component.withCString { name in
                Darwin.openat(currentFD, name, flags)
            }
            guard nextFD >= 0 else { throw mapErrno(errno) }

            var openedStatus = stat()
            guard Darwin.fstat(nextFD, &openedStatus) == 0 else {
                let failure = mapErrno(errno)
                Darwin.close(nextFD)
                throw failure
            }
            guard FileSystemObjectIdentityV1(openedStatus)
                    == FileSystemObjectIdentityV1(noFollowStatus)
            else {
                Darwin.close(nextFD)
                throw NoFollowPathFailureV1.snapshotDrift
            }
            if isFinal {
                switch expectedType {
                case .regularFile where !isRegularFile(openedStatus):
                    Darwin.close(nextFD)
                    throw NoFollowPathFailureV1.irregularFile
                case .directory where !isDirectory(openedStatus):
                    Darwin.close(nextFD)
                    throw NoFollowPathFailureV1.irregularFile
                default:
                    break
                }
            }

            if currentIsOwned { Darwin.close(currentFD) }
            currentFD = nextFD
            currentIsOwned = true
            if !isFinal || expectedType == .directory {
                ancestors.append(
                    OpenedPathAncestorV1(
                        identity: FileSystemObjectIdentityV1(openedStatus),
                        componentCount: index + 1
                    )
                )
            }
        }

        var finalStatus = stat()
        guard Darwin.fstat(currentFD, &finalStatus) == 0 else {
            throw mapErrno(errno)
        }
        currentIsOwned = false
        return OpenedNoFollowPathV1(
            fileDescriptor: currentFD,
            snapshot: FileSystemObjectSnapshotV1(finalStatus),
            components: components,
            ancestors: ancestors
        )
    }

    private static func secureComponents(
        _ components: [String]
    ) throws -> [String] {
        guard components.allSatisfy({ component in
            !component.isEmpty
                && component != "."
                && component != ".."
                && !component.utf8.contains(0)
        }) else {
            throw NoFollowPathFailureV1.invalidPath
        }
        return components
    }

    private static func fingerprintDirectory(
        _ directoryFD: Int32,
        status: stat,
        relativeComponents: [[UInt8]],
        visited: inout Set<FileSystemObjectIdentityV1>,
        hasher: inout SHA256
    ) throws {
        let directoryIdentity = FileSystemObjectIdentityV1(status)
        guard visited.insert(directoryIdentity).inserted else {
            throw NoFollowPathFailureV1.snapshotDrift
        }
        appendTreeEntry(
            relativeComponents: relativeComponents,
            status: status,
            hasher: &hasher
        )

        let iteratorFD = Darwin.openat(
            directoryFD,
            ".",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard iteratorFD >= 0 else { throw mapErrno(errno) }
        var iteratorStatus = stat()
        guard Darwin.fstat(iteratorFD, &iteratorStatus) == 0 else {
            let failure = mapErrno(errno)
            Darwin.close(iteratorFD)
            throw failure
        }
        guard FileSystemObjectIdentityV1(iteratorStatus)
                == FileSystemObjectIdentityV1(status)
        else {
            Darwin.close(iteratorFD)
            throw NoFollowPathFailureV1.snapshotDrift
        }
        guard let stream = Darwin.fdopendir(iteratorFD) else {
            let failure = mapErrno(errno)
            Darwin.close(iteratorFD)
            throw failure
        }

        var names: [[UInt8]] = []
        errno = 0
        while let entry = Darwin.readdir(stream) {
            var rawName = entry.pointee.d_name
            let bytes = withUnsafeBytes(of: &rawName) { rawBuffer in
                Array(rawBuffer.prefix(Int(entry.pointee.d_namlen)))
            }
            if bytes != [46], bytes != [46, 46] {
                names.append(bytes)
            }
            errno = 0
        }
        let readError = errno
        Darwin.closedir(stream)
        guard readError == 0 else { throw mapErrno(readError) }
        names.sort { $0.lexicographicallyPrecedes($1) }

        for name in names {
            var childStatus = stat()
            let statusResult = withFileName(name) { pointer in
                Darwin.fstatat(
                    directoryFD,
                    pointer,
                    &childStatus,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard statusResult == 0 else {
                if errno == ENOENT {
                    throw NoFollowPathFailureV1.snapshotDrift
                }
                throw mapErrno(errno)
            }
            let childComponents = relativeComponents + [name]
            if isDirectory(childStatus) {
                let childFD = withFileName(name) { pointer in
                    Darwin.openat(
                        directoryFD,
                        pointer,
                        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                    )
                }
                guard childFD >= 0 else { throw mapErrno(errno) }
                var openedStatus = stat()
                guard Darwin.fstat(childFD, &openedStatus) == 0 else {
                    let failure = mapErrno(errno)
                    Darwin.close(childFD)
                    throw failure
                }
                guard FileSystemObjectIdentityV1(childStatus)
                        == FileSystemObjectIdentityV1(openedStatus)
                else {
                    Darwin.close(childFD)
                    throw NoFollowPathFailureV1.snapshotDrift
                }
                do {
                    try fingerprintDirectory(
                        childFD,
                        status: openedStatus,
                        relativeComponents: childComponents,
                        visited: &visited,
                        hasher: &hasher
                    )
                    Darwin.close(childFD)
                } catch {
                    Darwin.close(childFD)
                    throw error
                }
            } else {
                appendTreeEntry(
                    relativeComponents: childComponents,
                    status: childStatus,
                    hasher: &hasher
                )
            }
        }
    }

    private static func directoryContainsFileIdentity(
        _ directoryFD: Int32,
        status: stat,
        expectedIdentityHash: String,
        visited: inout Set<FileSystemObjectIdentityV1>
    ) throws -> Bool {
        let directoryIdentity = FileSystemObjectIdentityV1(status)
        guard visited.insert(directoryIdentity).inserted else {
            throw NoFollowPathFailureV1.snapshotDrift
        }

        let iteratorFD = Darwin.openat(
            directoryFD,
            ".",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard iteratorFD >= 0 else { throw mapErrno(errno) }
        var iteratorStatus = stat()
        guard Darwin.fstat(iteratorFD, &iteratorStatus) == 0 else {
            let failure = mapErrno(errno)
            Darwin.close(iteratorFD)
            throw failure
        }
        guard FileSystemObjectIdentityV1(iteratorStatus)
                == FileSystemObjectIdentityV1(status)
        else {
            Darwin.close(iteratorFD)
            throw NoFollowPathFailureV1.snapshotDrift
        }
        guard let stream = Darwin.fdopendir(iteratorFD) else {
            let failure = mapErrno(errno)
            Darwin.close(iteratorFD)
            throw failure
        }

        var names: [[UInt8]] = []
        errno = 0
        while let entry = Darwin.readdir(stream) {
            var rawName = entry.pointee.d_name
            let bytes = withUnsafeBytes(of: &rawName) { rawBuffer in
                Array(rawBuffer.prefix(Int(entry.pointee.d_namlen)))
            }
            if bytes != [46], bytes != [46, 46] {
                names.append(bytes)
            }
            errno = 0
        }
        let readError = errno
        Darwin.closedir(stream)
        guard readError == 0 else { throw mapErrno(readError) }
        names.sort { $0.lexicographicallyPrecedes($1) }

        for name in names {
            var childStatus = stat()
            let statusResult = withFileName(name) { pointer in
                Darwin.fstatat(
                    directoryFD,
                    pointer,
                    &childStatus,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard statusResult == 0 else {
                if errno == ENOENT {
                    throw NoFollowPathFailureV1.snapshotDrift
                }
                throw mapErrno(errno)
            }
            if isRegularFile(childStatus),
               FileSystemObjectIdentityV1(childStatus).hash
                == expectedIdentityHash
            {
                return true
            }
            guard isDirectory(childStatus) else { continue }

            let childFD = withFileName(name) { pointer in
                Darwin.openat(
                    directoryFD,
                    pointer,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            guard childFD >= 0 else { throw mapErrno(errno) }
            var openedStatus = stat()
            guard Darwin.fstat(childFD, &openedStatus) == 0 else {
                let failure = mapErrno(errno)
                Darwin.close(childFD)
                throw failure
            }
            guard FileSystemObjectIdentityV1(childStatus)
                    == FileSystemObjectIdentityV1(openedStatus)
            else {
                Darwin.close(childFD)
                throw NoFollowPathFailureV1.snapshotDrift
            }
            do {
                let found = try directoryContainsFileIdentity(
                    childFD,
                    status: openedStatus,
                    expectedIdentityHash: expectedIdentityHash,
                    visited: &visited
                )
                Darwin.close(childFD)
                if found { return true }
            } catch {
                Darwin.close(childFD)
                throw error
            }
        }
        return false
    }

    private static func appendTreeEntry(
        relativeComponents: [[UInt8]],
        status: stat,
        hasher: inout SHA256
    ) {
        NoFollowHashMaterialV1.update(&hasher, byte: 2)
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(relativeComponents.count)
        )
        for component in relativeComponents {
            NoFollowHashMaterialV1.update(&hasher, bytes: component)
        }
        let snapshot = FileSystemObjectSnapshotV1(status)
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: snapshot.identity.device
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: snapshot.identity.inode
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: snapshot.identity.generation
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(snapshot.mode)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: snapshot.linkCount
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: snapshot.byteCount)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: snapshot.modificationSeconds)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: snapshot.modificationNanoseconds)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: snapshot.changeSeconds)
        )
        NoFollowHashMaterialV1.update(
            &hasher,
            integer: UInt64(bitPattern: snapshot.changeNanoseconds)
        )
    }

    private static func withFileName<Result>(
        _ bytes: [UInt8],
        _ body: (UnsafePointer<CChar>) -> Result
    ) -> Result {
        var characters = bytes.map { CChar(bitPattern: $0) }
        characters.append(0)
        return characters.withUnsafeBufferPointer { buffer in
            body(buffer.baseAddress!)
        }
    }

    private static func isRegularFile(_ status: stat) -> Bool {
        (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
    }

    private static func isDirectory(_ status: stat) -> Bool {
        (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
    }

    private static func isSymbolicLink(_ status: stat) -> Bool {
        (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFLNK)
    }

    private static func mapErrno(_ value: Int32) -> NoFollowPathFailureV1 {
        switch value {
        case ENOENT:
            return .missing
        case ELOOP:
            return .symlink
        case EACCES, EPERM:
            return .permissionDenied
        case ENOTDIR:
            return .irregularFile
        default:
            return .ioFailure
        }
    }
}

private enum NoFollowHashMaterialV1 {
    static func update(_ hasher: inout SHA256, byte: UInt8) {
        hasher.update(data: Data([byte]))
    }

    static func update(_ hasher: inout SHA256, integer: UInt64) {
        var bigEndian = integer.bigEndian
        withUnsafeBytes(of: &bigEndian) { bytes in
            hasher.update(data: Data(bytes))
        }
    }

    static func update(_ hasher: inout SHA256, bytes: [UInt8]) {
        update(&hasher, integer: UInt64(bytes.count))
        hasher.update(data: Data(bytes))
    }

    static func hex<Digest: Sequence>(_ digest: Digest) -> String
    where Digest.Element == UInt8 {
        let alphabet = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(64)
        for byte in digest {
            bytes.append(alphabet[Int(byte >> 4)])
            bytes.append(alphabet[Int(byte & 0x0f)])
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
