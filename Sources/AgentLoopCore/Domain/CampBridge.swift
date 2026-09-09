import Foundation

package enum CampBridgeModeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case reference
    case copy
    case searchGrant
}

package enum CampBridgeStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case revoked
}

package struct CampBridgeContentScopeV1:
    Codable, Sendable, Equatable
{
    package let memoryIds: [String]

    package init(memoryIds: [String]) throws {
        guard !memoryIds.isEmpty,
              memoryIds == memoryIds.sorted(),
              Set(memoryIds).count == memoryIds.count
        else {
            throw P1ContractValidationError.invalidMembership
        }
        for id in memoryIds {
            try CanonicalContractCodingV1.validateNonempty(id)
        }
        self.memoryIds = memoryIds
    }
}

package struct CampBridgeReadV1: Sendable, Equatable {
    package let sourceCampId: String
    package let memoryIds: [String]

    package init(sourceCampId: String, memoryIds: [String]) {
        self.sourceCampId = sourceCampId
        self.memoryIds = memoryIds
    }
}

package struct CampBridgeSnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let sourceCampId: String
    package let targetCampId: String
    package let mode: CampBridgeModeV1
    package let contentScope: CampBridgeContentScopeV1
    package let grantedByActorId: String
    package let validUntil: Date?
    package let status: CampBridgeStatusV1
    package let revokedAt: Date?
    package let aggregateVersion: Int
    package let createdAt: Date
    package let updatedAt: Date

    package init(
        id: String,
        sourceCampId: String,
        targetCampId: String,
        mode: CampBridgeModeV1,
        contentScope: CampBridgeContentScopeV1,
        grantedByActorId: String,
        validUntil: Date?,
        status: CampBridgeStatusV1,
        revokedAt: Date?,
        aggregateVersion: Int,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validateCampID(sourceCampId)
        try CanonicalContractCodingV1.validateCampID(targetCampId)
        try CanonicalContractCodingV1.validateNonempty(grantedByActorId)
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        if let validUntil {
            try CanonicalContractCodingV1.validateFinite(validUntil)
        }
        if let revokedAt {
            try CanonicalContractCodingV1.validateFinite(revokedAt)
        }
        guard sourceCampId != targetCampId,
              updatedAt >= createdAt,
              (status == .revoked) == (revokedAt != nil)
        else {
            throw P1ContractValidationError.invalidValue
        }
        self.id = id
        self.sourceCampId = sourceCampId
        self.targetCampId = targetCampId
        self.mode = mode
        self.contentScope = contentScope
        self.grantedByActorId = grantedByActorId
        self.validUntil = validUntil
        self.status = status
        self.revokedAt = revokedAt
        self.aggregateVersion = aggregateVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

package struct CreateCampBridgeCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let bridgeId: String
    package let sourceCampId: String
    package let targetCampId: String
    package let mode: CampBridgeModeV1
    package let contentScope: CampBridgeContentScopeV1
    package let grantedByActorId: String
    package let validUntil: Date?
    package let expectedSourceLifecycleVersion: Int
    package let expectedTargetLifecycleVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        bridgeId: String,
        sourceCampId: String,
        targetCampId: String,
        mode: CampBridgeModeV1,
        contentScope: CampBridgeContentScopeV1,
        grantedByActorId: String,
        validUntil: Date?,
        expectedSourceLifecycleVersion: Int,
        expectedTargetLifecycleVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(bridgeId)
        try CanonicalContractCodingV1.validateCampID(sourceCampId)
        try CanonicalContractCodingV1.validateCampID(targetCampId)
        try CanonicalContractCodingV1.validateNonempty(grantedByActorId)
        try CanonicalContractCodingV1.validatePositive(
            expectedSourceLifecycleVersion
        )
        try CanonicalContractCodingV1.validatePositive(
            expectedTargetLifecycleVersion
        )
        if let validUntil {
            try CanonicalContractCodingV1.validateFinite(validUntil)
            guard validUntil > envelope.occurredAt else {
                throw P1ContractValidationError.invalidTime
            }
        }
        guard sourceCampId != targetCampId else {
            throw P1ContractValidationError.invalidValue
        }
        self.envelope = envelope
        self.bridgeId = bridgeId
        self.sourceCampId = sourceCampId
        self.targetCampId = targetCampId
        self.mode = mode
        self.contentScope = contentScope
        self.grantedByActorId = grantedByActorId
        self.validUntil = validUntil
        self.expectedSourceLifecycleVersion = expectedSourceLifecycleVersion
        self.expectedTargetLifecycleVersion = expectedTargetLifecycleVersion
    }
}

package struct RevokeCampBridgeCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let bridgeId: String
    package let expectedAggregateVersion: Int
    package let expectedSourceLifecycleVersion: Int
    package let expectedTargetLifecycleVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        bridgeId: String,
        expectedAggregateVersion: Int,
        expectedSourceLifecycleVersion: Int,
        expectedTargetLifecycleVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(bridgeId)
        try CanonicalContractCodingV1.validatePositive(
            expectedAggregateVersion
        )
        try CanonicalContractCodingV1.validatePositive(
            expectedSourceLifecycleVersion
        )
        try CanonicalContractCodingV1.validatePositive(
            expectedTargetLifecycleVersion
        )
        self.envelope = envelope
        self.bridgeId = bridgeId
        self.expectedAggregateVersion = expectedAggregateVersion
        self.expectedSourceLifecycleVersion = expectedSourceLifecycleVersion
        self.expectedTargetLifecycleVersion = expectedTargetLifecycleVersion
    }
}

package struct CampBridgeAuthorizationError: Error, Sendable, Equatable {
    package init() {}
}

package struct CampBridgeReferenceMismatchError:
    Error, Sendable, Equatable
{
    package init() {}
}
