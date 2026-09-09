import Foundation

package enum MemoryLayerV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case rawSource
    case working
    case campKnowledge
    case globalPreference
    case globalSkill
}

package enum MemoryOwnerTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case user
    case goal
    case camp
    case cow
}

package enum MemoryRecordStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case proposed
    case active
    case needsReview
    case invalidated
    case deletedTombstone
}

package enum MemorySourceTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case userConfirmed
    case independentSource
    case outcomeExperience
    case inference
}

package enum MemoryDependencyTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case input
    case outcome
    case verification
    case acceptance
    case memory
}

package enum MemoryRecordContractError: Error, Sendable, Equatable {
    case invalidLayerOwner
    case invalidCampScope
    case invalidCarrier
    case invalidProvenance
}

package enum MemoryPromotionAuthorizationError:
    Error, Sendable, Equatable
{
    case sourceMismatch
    case outcomeNotAccepted
    case verificationInvalid
    case acceptanceInvalid
    case cowUnavailable
}

package struct MemoryRecordRefV1:
    Codable, Sendable, Equatable, Hashable
{
    package let id: String
    package let version: Int
    package let hash: String

    package init(id: String, version: Int, hash: String) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        self.id = id
        self.version = version
        self.hash = hash
    }
}

package struct MemoryRecordDraftV1: Sendable, Equatable {
    package let id: String
    package let layer: MemoryLayerV1
    package let ownerType: MemoryOwnerTypeV1
    package let ownerId: String
    package let campId: String?
    package let title: String
    package let bodyText: String?
    package let contentRef: String?
    package let contentHash: String
    package let sourceType: MemorySourceTypeV1
    package let applicabilityJson: String
    package let createdByActorId: String
    package let confirmedByActorId: String?

    package init(
        id: String,
        layer: MemoryLayerV1,
        ownerType: MemoryOwnerTypeV1,
        ownerId: String,
        campId: String?,
        title: String,
        bodyText: String?,
        contentRef: String?,
        sourceType: MemorySourceTypeV1,
        applicabilityJson: String,
        createdByActorId: String,
        confirmedByActorId: String?
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validateNonempty(ownerId)
        if let campId {
            try CanonicalContractCodingV1.validateCampID(campId)
        }
        try CanonicalContractCodingV1.validateNonempty(title)
        try CanonicalContractCodingV1.validateOptionalNonempty(bodyText)
        try CanonicalContractCodingV1.validateOptionalNonempty(contentRef)
        try CanonicalContractCodingV1.validateNonempty(createdByActorId)
        try CanonicalContractCodingV1.validateOptionalNonempty(
            confirmedByActorId
        )
        guard (bodyText != nil) != (contentRef != nil) else {
            throw MemoryRecordContractError.invalidCarrier
        }
        try Self.validateLayerOwner(
            layer: layer,
            ownerType: ownerType,
            ownerId: ownerId,
            campId: campId
        )
        try Self.validateProvenance(
            layer: layer,
            sourceType: sourceType,
            confirmedByActorId: confirmedByActorId
        )
        let applicabilityBytes = Data(applicabilityJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: applicabilityBytes)
        let applicability = try CanonicalContractCodingV1.decode(
            JSONValue.self,
            from: applicabilityBytes
        )
        guard applicability.objectValue != nil else {
            throw P1ContractValidationError.invalidValue
        }
        let contentHash = try CanonicalContractCodingV1.hash(
            MemoryContentHashMaterialV1(
                bodyText: bodyText,
                contentRef: contentRef
            )
        )
        self.id = id
        self.layer = layer
        self.ownerType = ownerType
        self.ownerId = ownerId
        self.campId = campId
        self.title = title
        self.bodyText = bodyText
        self.contentRef = contentRef
        self.contentHash = contentHash
        self.sourceType = sourceType
        self.applicabilityJson = applicabilityJson
        self.createdByActorId = createdByActorId
        self.confirmedByActorId = confirmedByActorId
    }

    package static func validateLayerOwner(
        layer: MemoryLayerV1,
        ownerType: MemoryOwnerTypeV1,
        ownerId: String,
        campId: String?
    ) throws {
        switch layer {
        case .campKnowledge:
            guard ownerType == .camp, campId == ownerId else {
                if campId == nil {
                    throw MemoryRecordContractError.invalidCampScope
                }
                throw MemoryRecordContractError.invalidLayerOwner
            }
        case .globalPreference:
            guard ownerType == .user else {
                throw MemoryRecordContractError.invalidLayerOwner
            }
            guard campId == nil else {
                throw MemoryRecordContractError.invalidCampScope
            }
        case .globalSkill:
            guard ownerType == .cow else {
                throw MemoryRecordContractError.invalidLayerOwner
            }
            guard campId == nil else {
                throw MemoryRecordContractError.invalidCampScope
            }
        case .rawSource, .working:
            switch ownerType {
            case .camp:
                guard campId == ownerId else {
                    throw MemoryRecordContractError.invalidCampScope
                }
            case .goal:
                guard campId != nil else {
                    throw MemoryRecordContractError.invalidCampScope
                }
            case .user, .cow:
                break
            }
        }
    }

    package static func validateProvenance(
        layer: MemoryLayerV1,
        sourceType: MemorySourceTypeV1,
        confirmedByActorId: String?
    ) throws {
        switch layer {
        case .rawSource, .working:
            return
        case .campKnowledge, .globalPreference:
            guard sourceType == .inference || confirmedByActorId != nil else {
                throw MemoryRecordContractError.invalidProvenance
            }
        case .globalSkill:
            guard sourceType == .outcomeExperience,
                  confirmedByActorId != nil
            else {
                throw MemoryRecordContractError.invalidProvenance
            }
        }
    }
}

package struct MemoryRecordVersionV1: Codable, Sendable, Equatable {
    package let id: String
    package let version: Int
    package let layer: MemoryLayerV1
    package let ownerType: MemoryOwnerTypeV1
    package let ownerId: String
    package let campId: String?
    package let title: String
    package let bodyText: String?
    package let contentRef: String?
    package let contentHash: String
    package let status: MemoryRecordStatusV1
    package let sourceType: MemorySourceTypeV1
    package let applicabilityJson: String
    package let createdByActorId: String
    package let confirmedByActorId: String?
    package let createdAt: Date
    package let updatedAt: Date

    package var ref: MemoryRecordRefV1 {
        get throws {
            try MemoryRecordRefV1(
                id: id,
                version: version,
                hash: contentHash
            )
        }
    }

    package init(
        id: String,
        version: Int,
        layer: MemoryLayerV1,
        ownerType: MemoryOwnerTypeV1,
        ownerId: String,
        campId: String?,
        title: String,
        bodyText: String?,
        contentRef: String?,
        contentHash: String,
        status: MemoryRecordStatusV1,
        sourceType: MemorySourceTypeV1,
        applicabilityJson: String,
        createdByActorId: String,
        confirmedByActorId: String?,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        try CanonicalContractCodingV1.validateNonempty(ownerId)
        try CanonicalContractCodingV1.validateNonempty(title)
        try CanonicalContractCodingV1.validateNonempty(createdByActorId)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        guard updatedAt >= createdAt else {
            throw P1ContractValidationError.invalidTime
        }
        if status == .deletedTombstone {
            guard bodyText == nil, contentRef == nil else {
                throw MemoryRecordContractError.invalidCarrier
            }
        } else {
            guard (bodyText != nil) != (contentRef != nil) else {
                throw MemoryRecordContractError.invalidCarrier
            }
        }
        try MemoryRecordDraftV1.validateLayerOwner(
            layer: layer,
            ownerType: ownerType,
            ownerId: ownerId,
            campId: campId
        )
        try MemoryRecordDraftV1.validateProvenance(
            layer: layer,
            sourceType: sourceType,
            confirmedByActorId: confirmedByActorId
        )
        let applicabilityBytes = Data(applicabilityJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: applicabilityBytes)
        guard try CanonicalContractCodingV1.decode(
            JSONValue.self,
            from: applicabilityBytes
        ).objectValue != nil else {
            throw P1ContractValidationError.invalidValue
        }
        self.id = id
        self.version = version
        self.layer = layer
        self.ownerType = ownerType
        self.ownerId = ownerId
        self.campId = campId
        self.title = title
        self.bodyText = bodyText
        self.contentRef = contentRef
        self.contentHash = contentHash
        self.status = status
        self.sourceType = sourceType
        self.applicabilityJson = applicabilityJson
        self.createdByActorId = createdByActorId
        self.confirmedByActorId = confirmedByActorId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

package struct MemoryDependencyDraftV1: Sendable, Equatable {
    package let id: String
    package let memory: MemoryRecordRefV1
    package let dependencyType: MemoryDependencyTypeV1
    package let dependencyId: String
    package let dependencyVersion: Int?
    package let dependencyHash: String
    package let createdAt: Date

    package init(
        id: String,
        memory: MemoryRecordRefV1,
        dependencyType: MemoryDependencyTypeV1,
        dependencyId: String,
        dependencyVersion: Int?,
        dependencyHash: String,
        createdAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validateNonempty(dependencyId)
        if let dependencyVersion {
            try CanonicalContractCodingV1.validatePositive(dependencyVersion)
        }
        try CanonicalContractCodingV1.validateLowercaseHash(dependencyHash)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        self.id = id
        self.memory = memory
        self.dependencyType = dependencyType
        self.dependencyId = dependencyId
        self.dependencyVersion = dependencyVersion
        self.dependencyHash = dependencyHash
        self.createdAt = createdAt
    }
}

package struct MemoryDependencyV1: Codable, Sendable, Equatable {
    package let id: String
    package let memoryId: String
    package let memoryVersion: Int
    package let dependencyType: MemoryDependencyTypeV1
    package let dependencyId: String
    package let dependencyVersion: Int?
    package let dependencyHash: String
    package let createdAt: Date
}

package enum MemoryInvalidationCauseV1: Sendable, Equatable {
    case outcomeReturned(
        outcomeId: String,
        outcomeVersion: Int,
        acceptanceId: String?
    )
    case acceptanceRevoked(
        outcomeId: String,
        outcomeVersion: Int,
        acceptanceId: String
    )
    case verificationInvalidated(
        outcomeId: String,
        outcomeVersion: Int,
        verificationIds: [String]
    )
    case outcomeSuperseded(outcomeId: String, outcomeVersion: Int)
    case dependencyInvalidated(
        type: MemoryDependencyTypeV1,
        id: String,
        version: Int?,
        hash: String?,
        deleted: Bool
    )
}

package struct MemoryInvalidationMutationV1:
    Sendable, Equatable
{
    package let memoryId: String
    package let memoryVersion: Int
    package let from: MemoryRecordStatusV1
    package let to: MemoryRecordStatusV1
}

private struct MemoryContentHashMaterialV1: Codable {
    let bodyText: String?
    let contentRef: String?
}
