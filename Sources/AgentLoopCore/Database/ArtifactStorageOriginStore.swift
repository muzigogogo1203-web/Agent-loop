import Foundation
import GRDB

package struct WorkspaceExternalArtifactReferenceV1: Sendable, Equatable {
    package let cardId: String
    package let path: String
    package let kind: String
    package let label: String
    package let classifiedAt: Date

    private init(
        cardId: String,
        path: String,
        kind: String,
        label: String,
        classifiedAt: Date
    ) {
        self.cardId = cardId
        self.path = path
        self.kind = kind
        self.label = label
        self.classifiedAt = classifiedAt
    }

    package static func explicit(
        cardId: String,
        path: String,
        kind: String,
        label: String,
        classifiedAt: Date
    ) throws -> Self {
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateNonempty(path)
        guard path.hasPrefix("/") else {
            throw P1ContractValidationError.invalidValue
        }
        try CanonicalContractCodingV1.validateNonempty(kind)
        try CanonicalContractCodingV1.validateNonempty(label)
        try CanonicalContractCodingV1.validateFinite(classifiedAt)
        return Self(
            cardId: cardId,
            path: path,
            kind: kind,
            label: label,
            classifiedAt: classifiedAt
        )
    }
}

package struct ArtifactStorageOriginSnapshotV1: Sendable {
    package let artifact: ArtifactRecord
    package let origin: ArtifactStorageOriginRecord
    package let blobReference: ArtifactBlobReferenceRecord?
}

package final class ArtifactStorageOriginStore: Sendable {
    private let database: AppDatabase
    private let artifactIdFactory: @Sendable () -> String

    package init(
        database: AppDatabase,
        artifactIdFactory: @escaping @Sendable () -> String = {
            UUID().uuidString
        }
    ) {
        self.database = database
        self.artifactIdFactory = artifactIdFactory
    }

    package func insertPreparedArtifacts(
        _ prepared: [PreparedArtifactV1],
        proposalId: String,
        database: Database
    ) throws -> [ArtifactRecord] {
        try CanonicalContractCodingV1.validateCanonicalUUID(proposalId)
        guard !prepared.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }

        let ordered = prepared.sorted { lhs, rhs in
            if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
            return lhs.artifactId.utf8.lexicographicallyPrecedes(
                rhs.artifactId.utf8
            )
        }
        guard ordered.enumerated().allSatisfy({ index, artifact in
            artifact.ordinal == index
        }), Set(ordered.map(\.artifactId)).count == ordered.count,
           Set(ordered.map(\.proposalArtifactId)).count == ordered.count
        else {
            throw P1ContractValidationError.invalidMembership
        }

        guard let proposal = try EngineTerminalProposalRecord.fetchOne(
            database,
            key: proposalId
        ), proposal.state == .pending,
           proposal.redactedAt == nil,
           let execution = try EngineExecutionRecord.fetchOne(
               database,
               key: proposal.executionId
           ), execution.id == proposal.executionId,
           execution.state == .running,
           execution.redactedAt == nil,
           try activeCampID(for: execution.cardId, database: database)
                == execution.campId
        else {
            throw P1ContractValidationError.invalidValue
        }

        let proposalArtifacts = try EngineProposalArtifactRecord
            .filter(Column("proposalId") == proposalId)
            .order(Column("ordinal"))
            .fetchAll(database)
        guard proposalArtifacts.count == ordered.count else {
            throw P1ContractValidationError.invalidMembership
        }

        var artifacts: [ArtifactRecord] = []
        var origins: [ArtifactStorageOriginRecord] = []
        var references: [ArtifactBlobReferenceRecord] = []
        artifacts.reserveCapacity(ordered.count)
        origins.reserveCapacity(ordered.count)
        references.reserveCapacity(ordered.count)

        for (artifact, proposalArtifact) in zip(ordered, proposalArtifacts) {
            try validatePreparedArtifact(
                artifact,
                proposalId: proposalId,
                proposalArtifact: proposalArtifact,
                execution: execution,
                database: database
            )
            guard try ArtifactRecord.fetchOne(
                database,
                key: artifact.artifactId
            ) == nil,
            try ArtifactStorageOriginRecord.fetchOne(
                database,
                key: artifact.artifactId
            ) == nil,
            try ArtifactBlobReferenceRecord.fetchOne(
                database,
                key: artifact.artifactId
            ) == nil
            else {
                throw P1ContractValidationError.invalidMembership
            }

            let originalRefHash = CanonicalJSONV1.sha256Hex(
                Data(artifact.blobRelativePath.utf8)
            )
            let classificationEvidenceHash = try CanonicalContractCodingV1
                .hash(
                    PreparedArtifactClassificationMaterialV1(
                        schemaVersion: 1,
                        proposalId: proposalId,
                        proposalArtifactId: artifact.proposalArtifactId,
                        artifactId: artifact.artifactId,
                        executionId: artifact.executionId,
                        cardId: artifact.cardId,
                        campId: artifact.campId,
                        ordinal: artifact.ordinal,
                        contentHash: artifact.contentHash,
                        managedRootId: artifact.managedRootId,
                        objectId: artifact.objectId,
                        fileIdentityHash: artifact.fileIdentityHash,
                        originalRefHash: originalRefHash,
                        preparedAt: artifact.preparedAt
                    )
                )
            artifacts.append(
                ArtifactRecord(
                    id: artifact.artifactId,
                    cardId: artifact.cardId,
                    path: artifact.blobRelativePath,
                    kind: artifact.kind,
                    label: artifact.label,
                    createdAt: artifact.preparedAt
                )
            )
            origins.append(
                ArtifactStorageOriginRecord(
                    artifactId: artifact.artifactId,
                    campId: artifact.campId,
                    state: .active,
                    storageClass: .managed,
                    evidenceKind: .typedPreparedArtifact,
                    managedRootId: artifact.managedRootId,
                    objectId: artifact.objectId,
                    contentHash: artifact.contentHash,
                    fileIdentityHash: artifact.fileIdentityHash,
                    originalRefHash: originalRefHash,
                    classificationEvidenceHash: classificationEvidenceHash,
                    terminalDisposition: nil,
                    terminalAuthorityHash: nil,
                    version: 1,
                    classifiedAt: artifact.preparedAt,
                    redactedAt: nil
                )
            )
            references.append(
                ArtifactBlobReferenceRecord(
                    artifactId: artifact.artifactId,
                    proposalArtifactId: artifact.proposalArtifactId,
                    executionId: artifact.executionId,
                    campId: artifact.campId,
                    contentHash: artifact.contentHash,
                    state: .active,
                    createdAt: artifact.preparedAt,
                    tombstonedAt: nil
                )
            )
        }

        var inserted: [ArtifactRecord]?
        try database.inSavepoint {
            for index in artifacts.indices {
                try artifacts[index].insert(database)
                try origins[index].insert(database)
                try references[index].insert(database)
            }
            inserted = artifacts
            return .commit
        }
        guard let inserted else {
            throw P1ContractValidationError.invalidValue
        }
        return inserted
    }

    package func insertWorkspaceExternalArtifact(
        _ reference: WorkspaceExternalArtifactReferenceV1,
        database: Database
    ) throws -> ArtifactRecord {
        try validateExternalReference(reference)
        let campId = try activeCampID(
            for: reference.cardId,
            database: database
        )
        let artifactId = artifactIdFactory()
        try CanonicalContractCodingV1.validateCanonicalUUID(artifactId)
        guard try ArtifactRecord.fetchOne(database, key: artifactId) == nil,
              try ArtifactStorageOriginRecord.fetchOne(
                  database,
                  key: artifactId
              ) == nil,
              try ArtifactBlobReferenceRecord.fetchOne(
                  database,
                  key: artifactId
              ) == nil
        else {
            throw P1ContractValidationError.invalidMembership
        }

        let originalRefHash = CanonicalJSONV1.sha256Hex(
            Data(reference.path.utf8)
        )
        let classificationEvidenceHash = try CanonicalContractCodingV1.hash(
            ExplicitExternalClassificationMaterialV1(
                schemaVersion: 1,
                artifactId: artifactId,
                cardId: reference.cardId,
                campId: campId,
                kind: reference.kind,
                label: reference.label,
                originalRefHash: originalRefHash,
                classifiedAt: reference.classifiedAt
            )
        )
        let artifact = ArtifactRecord(
            id: artifactId,
            cardId: reference.cardId,
            path: reference.path,
            kind: reference.kind,
            label: reference.label,
            createdAt: reference.classifiedAt
        )
        let origin = ArtifactStorageOriginRecord(
            artifactId: artifactId,
            campId: campId,
            state: .active,
            storageClass: .workspaceExternal,
            evidenceKind: .explicitWorkspaceExternal,
            managedRootId: nil,
            objectId: nil,
            contentHash: nil,
            fileIdentityHash: nil,
            originalRefHash: originalRefHash,
            classificationEvidenceHash: classificationEvidenceHash,
            terminalDisposition: nil,
            terminalAuthorityHash: nil,
            version: 1,
            classifiedAt: reference.classifiedAt,
            redactedAt: nil
        )

        var inserted = false
        try database.inSavepoint {
            try artifact.insert(database)
            try origin.insert(database)
            inserted = true
            return .commit
        }
        guard inserted else {
            throw P1ContractValidationError.invalidValue
        }
        return artifact
    }

    package func upgradeLegacyOrigin(
        artifactId: String,
        expectedVersion: Int,
        evidence: ArtifactOriginUpgradeEvidenceV1,
        at: Date,
        database: Database
    ) throws -> ArtifactStorageOriginSnapshotV1 {
        try CanonicalContractCodingV1.validateCanonicalUUID(artifactId)
        try CanonicalContractCodingV1.validatePositive(expectedVersion)
        try CanonicalContractCodingV1.validateFinite(at)
        let nextVersion = try CanonicalContractCodingV1.checkedIncrement(
            expectedVersion
        )
        guard let artifact = try ArtifactRecord.fetchOne(
            database,
            key: artifactId
        ), let origin = try ArtifactStorageOriginRecord.fetchOne(
            database,
            key: artifactId
        ), origin.artifactId == artifact.id,
           origin.campId == (try activeCampID(
               for: artifact.cardId,
               database: database
           )), origin.state == .active,
           origin.storageClass == .unresolved,
           origin.evidenceKind == .legacyUnknown,
           origin.managedRootId == nil,
           origin.objectId == nil,
           origin.contentHash == nil,
           origin.fileIdentityHash == nil,
           origin.terminalDisposition == nil,
           origin.terminalAuthorityHash == nil,
           origin.version == expectedVersion,
           origin.redactedAt == nil,
           try ArtifactBlobReferenceRecord.fetchOne(
               database,
               key: artifactId
           ) == nil
        else {
            throw P1ContractValidationError.invalidValue
        }
        try validateLegacyAttestation(artifact: artifact, origin: origin)

        let classification = try upgradedClassification(
            evidence,
            artifact: artifact,
            origin: origin,
            expectedVersion: expectedVersion,
            at: at
        )
        var snapshot: ArtifactStorageOriginSnapshotV1?
        try database.inSavepoint {
            try validateLegacyUpgradeConsumptionSnapshot(
                artifact: artifact,
                origin: origin,
                expectedVersion: expectedVersion,
                evidence: evidence,
                database: database
            )
            try database.execute(
                sql: """
                    UPDATE artifact_storage_origin
                    SET storageClass=?,evidenceKind=?,managedRootId=?,objectId=?,
                        contentHash=?,fileIdentityHash=?,
                        classificationEvidenceHash=?,version=?,classifiedAt=?
                    WHERE artifactId=? AND version=? AND state='active'
                      AND storageClass='unresolved'
                      AND evidenceKind='legacyUnknown' AND redactedAt IS NULL
                    """,
                arguments: [
                    classification.storageClass.rawValue,
                    classification.evidenceKind.rawValue,
                    classification.managedRootId,
                    classification.objectId,
                    classification.contentHash,
                    classification.fileIdentityHash,
                    classification.evidenceHash,
                    nextVersion,
                    at,
                    artifactId,
                    expectedVersion,
                ]
            )
            guard database.changesCount == 1,
                  let updated = try ArtifactStorageOriginRecord.fetchOne(
                      database,
                      key: artifactId
                  )
            else {
                throw P1ContractValidationError.invalidValue
            }
            snapshot = ArtifactStorageOriginSnapshotV1(
                artifact: artifact,
                origin: updated,
                blobReference: nil
            )
            return .commit
        }
        guard let snapshot else {
            throw P1ContractValidationError.invalidValue
        }
        return snapshot
    }

    private func validatePreparedArtifact(
        _ artifact: PreparedArtifactV1,
        proposalId: String,
        proposalArtifact: EngineProposalArtifactRecord,
        execution: EngineExecutionRecord,
        database: Database
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(
            artifact.proposalId
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(
            artifact.proposalArtifactId
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(
            artifact.artifactId
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(
            artifact.executionId
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(artifact.cardId)
        try CanonicalContractCodingV1.validateCampID(artifact.campId)
        try CanonicalContractCodingV1.validateNonnegative(artifact.ordinal)
        try CanonicalContractCodingV1.validateNonempty(artifact.kind)
        try CanonicalContractCodingV1.validateNonempty(artifact.label)
        try CanonicalContractCodingV1.validateNonnegative(artifact.byteCount)
        try CanonicalContractCodingV1.validateLowercaseHash(
            artifact.contentHash
        )
        try validateBlobRelativePath(artifact.blobRelativePath)
        try CanonicalContractCodingV1.validateNonempty(artifact.managedRootId)
        try CanonicalContractCodingV1.validateNonempty(artifact.objectId)
        try CanonicalContractCodingV1.validateLowercaseHash(
            artifact.fileIdentityHash
        )
        try CanonicalContractCodingV1.validatePositive(
            artifact.proposalArtifactVersion
        )
        try CanonicalContractCodingV1.validatePositive(artifact.blobVersion)
        try CanonicalContractCodingV1.validateFinite(artifact.preparedAt)

        guard artifact.proposalId == proposalId,
              artifact.proposalArtifactId == proposalArtifact.id,
              artifact.artifactId == proposalArtifact.artifactId,
              artifact.executionId == execution.id,
              artifact.cardId == execution.cardId,
              artifact.campId == execution.campId,
              artifact.ordinal == proposalArtifact.ordinal,
              artifact.kind == proposalArtifact.kind,
              artifact.label == proposalArtifact.label,
              artifact.byteCount == proposalArtifact.byteCount,
              artifact.contentHash == proposalArtifact.contentHash,
              proposalArtifact.proposalId == proposalId,
              proposalArtifact.state == .prepared,
              proposalArtifact.preparedAt == artifact.preparedAt,
              proposalArtifact.version == artifact.proposalArtifactVersion,
              proposalArtifact.redactedAt == nil,
              let blob = try ArtifactBlobRecord.fetchOne(
                  database,
                  key: artifact.contentHash
              ), blob.contentHash == artifact.contentHash,
              blob.byteCount == artifact.byteCount,
              blob.relativePath == artifact.blobRelativePath,
              blob.state == .available,
              blob.version == artifact.blobVersion,
              blob.deletedAt == nil
        else {
            throw P1ContractValidationError.invalidValue
        }
    }

    private func validateLegacyUpgradeConsumptionSnapshot(
        artifact: ArtifactRecord,
        origin: ArtifactStorageOriginRecord,
        expectedVersion: Int,
        evidence: ArtifactOriginUpgradeEvidenceV1,
        database: Database
    ) throws {
        guard let currentArtifact = try ArtifactRecord.fetchOne(
            database,
            key: artifact.id
        ), currentArtifact.id == artifact.id,
           currentArtifact.cardId == artifact.cardId,
           currentArtifact.path == artifact.path,
           currentArtifact.kind == artifact.kind,
           currentArtifact.label == artifact.label,
           currentArtifact.createdAt == artifact.createdAt,
           let currentOrigin = try ArtifactStorageOriginRecord.fetchOne(
               database,
               key: artifact.id
           ), currentOrigin == origin,
           currentOrigin.version == expectedVersion,
           currentOrigin.campId == (try activeCampID(
               for: currentArtifact.cardId,
               database: database
           )), try ArtifactBlobReferenceRecord.fetchOne(
               database,
               key: artifact.id
           ) == nil
        else {
            throw P1ContractValidationError.invalidValue
        }

        let contentHash: String
        let fileIdentityHash: String
        switch evidence {
        case let .managed(proof):
            contentHash = proof.contentHash
            fileIdentityHash = proof.fileIdentityHash
        case let .verifiedOutsideAllManagedRoots(proof):
            contentHash = proof.contentHash
            fileIdentityHash = proof.fileIdentityHash
        }

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
            arguments: [artifact.id, contentHash]
        ) ?? false
        guard !pending else {
            throw P1ContractValidationError.invalidValue
        }

        let conflictingOrigin = try Bool.fetchOne(
            database,
            sql: """
                SELECT EXISTS(
                  SELECT 1
                  FROM artifact_storage_origin o
                  JOIN artifact a ON a.id = o.artifactId
                  WHERE o.state = 'active'
                    AND o.artifactId <> ?
                    AND (a.path = ? OR o.fileIdentityHash = ?)
                )
                """,
            arguments: [
                artifact.id,
                artifact.path,
                fileIdentityHash,
            ]
        ) ?? false
        guard !conflictingOrigin else {
            throw P1ContractValidationError.invalidValue
        }

        let crossCampReference = try Bool.fetchOne(
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
            arguments: [currentOrigin.campId, contentHash]
        ) ?? false
        guard !crossCampReference else {
            throw P1ContractValidationError.invalidValue
        }
    }

    private func validateExternalReference(
        _ reference: WorkspaceExternalArtifactReferenceV1
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(reference.cardId)
        try CanonicalContractCodingV1.validateNonempty(reference.path)
        guard reference.path.hasPrefix("/") else {
            throw P1ContractValidationError.invalidValue
        }
        try CanonicalContractCodingV1.validateNonempty(reference.kind)
        try CanonicalContractCodingV1.validateNonempty(reference.label)
        try CanonicalContractCodingV1.validateFinite(reference.classifiedAt)
    }

    private func activeCampID(
        for cardId: String,
        database: Database
    ) throws -> String {
        guard let campId = try String.fetchOne(
            database,
            sql: """
                SELECT s.campId
                FROM card c
                JOIN mission m ON m.id=c.missionId
                JOIN squad s ON s.id=m.squadId
                JOIN camp_lifecycle l ON l.campId=s.campId
                WHERE c.id=? AND l.state='active'
                """,
            arguments: [cardId]
        ) else {
            throw P1ContractValidationError.invalidValue
        }
        try CanonicalContractCodingV1.validateCampID(campId)
        return campId
    }

    private func validateBlobRelativePath(_ path: String) throws {
        try CanonicalContractCodingV1.validateNonempty(path)
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !path.hasSuffix("/"),
              !path.contains("\\"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw P1ContractValidationError.invalidValue
        }
    }

    private func validateLegacyAttestation(
        artifact: ArtifactRecord,
        origin: ArtifactStorageOriginRecord
    ) throws {
        let originalRefHash = CanonicalJSONV1.sha256Hex(
            Data(artifact.path.utf8)
        )
        guard origin.originalRefHash == originalRefHash,
              origin.classificationEvidenceHash
                == (try CanonicalContractCodingV1.hash(
                    LegacyArtifactClassificationMaterialV1(
                        schemaVersion: 1,
                        artifactId: artifact.id,
                        cardId: artifact.cardId,
                        campId: origin.campId,
                        originalRefHash: originalRefHash
                    )
                ))
        else {
            throw P1ContractValidationError.invalidHash
        }
    }

    private func upgradedClassification(
        _ evidence: ArtifactOriginUpgradeEvidenceV1,
        artifact: ArtifactRecord,
        origin: ArtifactStorageOriginRecord,
        expectedVersion: Int,
        at: Date
    ) throws -> UpgradedArtifactClassificationV1 {
        switch evidence {
        case let .managed(proof):
            try validateManagedProof(
                proof,
                artifactId: artifact.id,
                campId: origin.campId,
                expectedVersion: expectedVersion
            )
            let evidenceHash = try CanonicalContractCodingV1.hash(
                ManagedUpgradeClassificationMaterialV1(
                    schemaVersion: 1,
                    artifactId: proof.artifactId,
                    cardId: artifact.cardId,
                    campId: proof.campId,
                    originVersion: proof.originVersion,
                    managedRootId: proof.managedRootId,
                    objectId: proof.objectId,
                    contentHash: proof.contentHash,
                    fileIdentityHash: proof.fileIdentityHash,
                    originalRefHash: origin.originalRefHash,
                    rootSetHash: proof.rootSetHash,
                    registryGeneration: proof.registryGeneration,
                    verifiedAt: proof.verifiedAt,
                    classifiedAt: at
                )
            )
            return UpgradedArtifactClassificationV1(
                storageClass: .managed,
                evidenceKind: .verifiedManagedRootCapability,
                managedRootId: proof.managedRootId,
                objectId: proof.objectId,
                contentHash: proof.contentHash,
                fileIdentityHash: proof.fileIdentityHash,
                evidenceHash: evidenceHash
            )
        case let .verifiedOutsideAllManagedRoots(proof):
            try validateExternalProof(
                proof,
                artifactId: artifact.id,
                campId: origin.campId,
                expectedVersion: expectedVersion,
                originalRefHash: origin.originalRefHash
            )
            let evidenceHash = try CanonicalContractCodingV1.hash(
                VerifiedExternalUpgradeClassificationMaterialV1(
                    schemaVersion: 1,
                    artifactId: proof.artifactId,
                    cardId: artifact.cardId,
                    campId: proof.campId,
                    originVersion: proof.originVersion,
                    originalRefHash: proof.originalRefHash,
                    observedContentHash: proof.contentHash,
                    observedFileIdentityHash: proof.fileIdentityHash,
                    rootSetHash: proof.rootSetHash,
                    registryGeneration: proof.registryGeneration,
                    verifiedAt: proof.verifiedAt,
                    classifiedAt: at
                )
            )
            return UpgradedArtifactClassificationV1(
                storageClass: .workspaceExternal,
                evidenceKind: .verifiedOutsideAllManagedRoots,
                managedRootId: nil,
                objectId: nil,
                contentHash: nil,
                fileIdentityHash: nil,
                evidenceHash: evidenceHash
            )
        }
    }

    private func validateManagedProof(
        _ proof: VerifiedManagedArtifactEvidenceV1,
        artifactId: String,
        campId: String,
        expectedVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(proof.managedRootId)
        try CanonicalContractCodingV1.validateNonempty(proof.objectId)
        try CanonicalContractCodingV1.validateLowercaseHash(proof.contentHash)
        try CanonicalContractCodingV1.validateLowercaseHash(
            proof.fileIdentityHash
        )
        try CanonicalContractCodingV1.validateLowercaseHash(proof.rootSetHash)
        try CanonicalContractCodingV1.validatePositive(proof.registryGeneration)
        try CanonicalContractCodingV1.validateFinite(proof.verifiedAt)
        guard proof.artifactId == artifactId,
              proof.campId == campId,
              proof.originVersion == expectedVersion
        else {
            throw P1ContractValidationError.invalidValue
        }
    }

    private func validateExternalProof(
        _ proof: VerifiedWorkspaceExternalEvidenceV1,
        artifactId: String,
        campId: String,
        expectedVersion: Int,
        originalRefHash: String
    ) throws {
        try CanonicalContractCodingV1.validateLowercaseHash(
            proof.originalRefHash
        )
        try CanonicalContractCodingV1.validateLowercaseHash(proof.contentHash)
        try CanonicalContractCodingV1.validateLowercaseHash(
            proof.fileIdentityHash
        )
        try CanonicalContractCodingV1.validateLowercaseHash(proof.rootSetHash)
        try CanonicalContractCodingV1.validatePositive(proof.registryGeneration)
        try CanonicalContractCodingV1.validateFinite(proof.verifiedAt)
        guard proof.artifactId == artifactId,
              proof.campId == campId,
              proof.originVersion == expectedVersion,
              proof.originalRefHash == originalRefHash
        else {
            throw P1ContractValidationError.invalidValue
        }
    }
}

private struct UpgradedArtifactClassificationV1 {
    let storageClass: ArtifactStorageClassV1
    let evidenceKind: ArtifactStorageEvidenceKindV1
    let managedRootId: String?
    let objectId: String?
    let contentHash: String?
    let fileIdentityHash: String?
    let evidenceHash: String
}

private struct LegacyArtifactClassificationMaterialV1: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originalRefHash: String
}

private struct PreparedArtifactClassificationMaterialV1: Encodable {
    let schemaVersion: Int
    let proposalId: String
    let proposalArtifactId: String
    let artifactId: String
    let executionId: String
    let cardId: String
    let campId: String
    let ordinal: Int
    let contentHash: String
    let managedRootId: String
    let objectId: String
    let fileIdentityHash: String
    let originalRefHash: String
    let preparedAt: Date
}

private struct ExplicitExternalClassificationMaterialV1: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let kind: String
    let label: String
    let originalRefHash: String
    let classifiedAt: Date
}

private struct ManagedUpgradeClassificationMaterialV1: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originVersion: Int
    let managedRootId: String
    let objectId: String
    let contentHash: String
    let fileIdentityHash: String
    let originalRefHash: String
    let rootSetHash: String
    let registryGeneration: Int
    let verifiedAt: Date
    let classifiedAt: Date
}

private struct VerifiedExternalUpgradeClassificationMaterialV1: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originVersion: Int
    let originalRefHash: String
    let observedContentHash: String
    let observedFileIdentityHash: String
    let rootSetHash: String
    let registryGeneration: Int
    let verifiedAt: Date
    let classifiedAt: Date
}
