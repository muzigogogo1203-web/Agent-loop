import Foundation

package enum CampResidencyStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case requested
    case authorized
    case active
    case paused
    case left
    case revoked
}

package enum CampResidencyTransitionV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case authorize
    case activate
    case pause
    case resume
    case leave
    case revoke
}

package struct CampResidencySnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let cowId: String
    package let campId: String
    package let role: String
    package let status: CampResidencyStatusV1
    package let idempotencyKey: String
    package let joinedAt: Date?
    package let pausedAt: Date?
    package let leftAt: Date?
    package let revokedAt: Date?
    package let aggregateVersion: Int
    package let createdAt: Date
    package let updatedAt: Date

    package init(
        id: String,
        cowId: String,
        campId: String,
        role: String,
        status: CampResidencyStatusV1,
        idempotencyKey: String,
        joinedAt: Date?,
        pausedAt: Date?,
        leftAt: Date?,
        revokedAt: Date?,
        aggregateVersion: Int,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validateNonempty(cowId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateNonempty(role)
        try CanonicalContractCodingV1.validateNonempty(idempotencyKey)
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        try [joinedAt, pausedAt, leftAt, revokedAt].compactMap { $0 }
            .forEach(CanonicalContractCodingV1.validateFinite)
        guard updatedAt >= createdAt,
              (status == .paused) == (pausedAt != nil),
              (status == .left) == (leftAt != nil),
              (status == .revoked) == (revokedAt != nil),
              !(status == .left || status == .revoked) || joinedAt != nil
        else {
            throw P1ContractValidationError.invalidValue
        }
        self.id = id
        self.cowId = cowId
        self.campId = campId
        self.role = role
        self.status = status
        self.idempotencyKey = idempotencyKey
        self.joinedAt = joinedAt
        self.pausedAt = pausedAt
        self.leftAt = leftAt
        self.revokedAt = revokedAt
        self.aggregateVersion = aggregateVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

package struct RequestCampResidencyCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let residencyId: String
    package let cowId: String
    package let campId: String
    package let role: String
    package let expectedCampLifecycleVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        residencyId: String,
        cowId: String,
        campId: String,
        role: String,
        expectedCampLifecycleVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(residencyId)
        try CanonicalContractCodingV1.validateNonempty(cowId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateNonempty(role)
        try CanonicalContractCodingV1.validatePositive(
            expectedCampLifecycleVersion
        )
        self.envelope = envelope
        self.residencyId = residencyId
        self.cowId = cowId
        self.campId = campId
        self.role = role
        self.expectedCampLifecycleVersion = expectedCampLifecycleVersion
    }
}

package struct ChangeCampResidencyCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let residencyId: String
    package let expectedAggregateVersion: Int
    package let transition: CampResidencyTransitionV1
    package let expectedCampLifecycleVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        residencyId: String,
        expectedAggregateVersion: Int,
        transition: CampResidencyTransitionV1,
        expectedCampLifecycleVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(residencyId)
        try CanonicalContractCodingV1.validatePositive(
            expectedAggregateVersion
        )
        try CanonicalContractCodingV1.validatePositive(
            expectedCampLifecycleVersion
        )
        self.envelope = envelope
        self.residencyId = residencyId
        self.expectedAggregateVersion = expectedAggregateVersion
        self.transition = transition
        self.expectedCampLifecycleVersion = expectedCampLifecycleVersion
    }
}

package struct InvalidCampResidencyTransitionError:
    Error, Sendable, Equatable
{
    package init() {}
}

package struct CampResidencyReferenceMismatchError:
    Error, Sendable, Equatable
{
    package init() {}
}

package enum ResidencyAuthorizationError: Error, Sendable, Equatable {
    case missing
    case inactive(CampResidencyStatusV1)
}
