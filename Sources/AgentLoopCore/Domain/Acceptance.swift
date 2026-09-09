import Foundation

package enum AcceptanceDecisionV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case accepted
    case returned
    case revoked
}

package enum AcceptanceSubjectTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case user
    case policy
}

package enum AcceptancePolicyStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case revoked
    case expired
}

package struct AcceptanceSubjectV1: Codable, Sendable, Equatable {
    package let type: AcceptanceSubjectTypeV1
    package let id: String
    package let policy: AcceptancePolicyRefV1?

    package static func user(_ id: String) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(id)
        return Self(type: .user, id: id, policy: nil)
    }

    package static func policy(
        actorId: String,
        ref: AcceptancePolicyRefV1
    ) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(actorId)
        return Self(type: .policy, id: actorId, policy: ref)
    }

    private init(
        type: AcceptanceSubjectTypeV1,
        id: String,
        policy: AcceptancePolicyRefV1?
    ) {
        self.type = type
        self.id = id
        self.policy = policy
    }
}

package struct AcceptancePolicyVersionV1: Codable, Sendable, Equatable {
    package let ref: AcceptancePolicyRefV1
    package let outcomeType: String
    package let maxRiskClass: OutcomeRiskClassV1
    package let policyActorId: String
    package let validFrom: Date
    package let validUntil: Date
    package let maxOutcomeAgeSeconds: Int
    package let requireAllVerification: Bool
    package let status: AcceptancePolicyStatusV1
    package let revokedAt: Date?
    package let createdByActorId: String
    package let createdAt: Date

    package init(
        id: String,
        version: Int,
        outcomeType: String,
        maxRiskClass: OutcomeRiskClassV1,
        policyActorId: String,
        validFrom: Date,
        validUntil: Date,
        maxOutcomeAgeSeconds: Int,
        status: AcceptancePolicyStatusV1,
        revokedAt: Date?,
        createdByActorId: String,
        createdAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateNonempty(outcomeType)
        guard maxRiskClass == .low || maxRiskClass == .normal,
              validUntil > validFrom,
              maxOutcomeAgeSeconds > 0,
              (status == .revoked) == (revokedAt != nil)
        else {
            throw P1ContractValidationError.invalidMembership
        }
        try CanonicalContractCodingV1.validateNonempty(policyActorId)
        try CanonicalContractCodingV1.validateNonempty(createdByActorId)
        try CanonicalContractCodingV1.validateFinite(validFrom)
        try CanonicalContractCodingV1.validateFinite(validUntil)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        if let revokedAt {
            try CanonicalContractCodingV1.validateFinite(revokedAt)
        }
        let content = Content(
            id: id,
            version: version,
            outcomeType: outcomeType,
            maxRiskClass: maxRiskClass,
            policyActorId: policyActorId,
            validFrom: validFrom,
            validUntil: validUntil,
            maxOutcomeAgeSeconds: maxOutcomeAgeSeconds,
            requireAllVerification: true,
            status: status,
            revokedAt: revokedAt,
            createdByActorId: createdByActorId,
            createdAt: createdAt
        )
        ref = try AcceptancePolicyRefV1(
            id: id,
            version: version,
            hash: CanonicalContractCodingV1.hash(content)
        )
        self.outcomeType = outcomeType
        self.maxRiskClass = maxRiskClass
        self.policyActorId = policyActorId
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.maxOutcomeAgeSeconds = maxOutcomeAgeSeconds
        requireAllVerification = true
        self.status = status
        self.revokedAt = revokedAt
        self.createdByActorId = createdByActorId
        self.createdAt = createdAt
    }

    private struct Content: Codable {
        let id: String
        let version: Int
        let outcomeType: String
        let maxRiskClass: OutcomeRiskClassV1
        let policyActorId: String
        let validFrom: Date
        let validUntil: Date
        let maxOutcomeAgeSeconds: Int
        let requireAllVerification: Bool
        let status: AcceptancePolicyStatusV1
        let revokedAt: Date?
        let createdByActorId: String
        let createdAt: Date
    }
}

package struct AcceptanceRecordSnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let commandIdempotencyKey: String
    package let contract: OutcomeContractRef
    package let outcome: OutcomeRefV1
    package let subject: AcceptanceSubjectV1
    package let decision: AcceptanceDecisionV1
    package let reason: String
    package let supersedesAcceptanceId: String?
    package let createdAt: Date
}

package enum OutcomeMetricCreditStateV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case reversed
}

package struct OutcomeMetricCreditSnapshotV1: Codable, Sendable, Equatable {
    package let outcomeId: String
    package let state: OutcomeMetricCreditStateV1
    package let creditedOutcomeVersion: Int
    package let acceptanceId: String
    package let reversedByEventId: String?
    package let version: Int
    package let creditedAt: Date
    package let reversedAt: Date?
}

package struct AcceptanceCommitSnapshotV1: Codable, Sendable, Equatable {
    package let record: AcceptanceRecordSnapshotV1
    package let outcome: OutcomeSnapshotV1
    package let goalStatus: GoalControllerStatusV1
    package let missionStatus: MissionStatus
    package let metric: OutcomeMetricCreditSnapshotV1?
}

package struct AcceptOutcomeCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let acceptanceId: String
    package let outcome: OutcomeRefV1
    package let expectedOutcomeAggregateVersion: Int
    package let subject: AcceptanceSubjectV1
    package let reason: String

    package init(
        envelope: CommandEnvelopeV1,
        acceptanceId: String,
        outcome: OutcomeRefV1,
        expectedOutcomeAggregateVersion: Int,
        subject: AcceptanceSubjectV1,
        reason: String
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(acceptanceId)
        try CanonicalContractCodingV1.validatePositive(
            expectedOutcomeAggregateVersion
        )
        try CanonicalContractCodingV1.validateNonempty(reason)
        self.envelope = envelope
        self.acceptanceId = acceptanceId
        self.outcome = outcome
        self.expectedOutcomeAggregateVersion = expectedOutcomeAggregateVersion
        self.subject = subject
        self.reason = reason
    }
}

package struct ReturnOutcomeCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let acceptanceId: String
    package let outcome: OutcomeRefV1
    package let expectedOutcomeAggregateVersion: Int
    package let subject: AcceptanceSubjectV1
    package let reason: String

    package init(
        envelope: CommandEnvelopeV1,
        acceptanceId: String,
        outcome: OutcomeRefV1,
        expectedOutcomeAggregateVersion: Int,
        subject: AcceptanceSubjectV1,
        reason: String
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(acceptanceId)
        try CanonicalContractCodingV1.validatePositive(
            expectedOutcomeAggregateVersion
        )
        try CanonicalContractCodingV1.validateNonempty(reason)
        self.envelope = envelope
        self.acceptanceId = acceptanceId
        self.outcome = outcome
        self.expectedOutcomeAggregateVersion = expectedOutcomeAggregateVersion
        self.subject = subject
        self.reason = reason
    }
}

package struct RevokeAcceptanceCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let acceptanceId: String
    package let outcome: OutcomeRefV1
    package let expectedOutcomeAggregateVersion: Int
    package let subject: AcceptanceSubjectV1
    package let reason: String

    package init(
        envelope: CommandEnvelopeV1,
        acceptanceId: String,
        outcome: OutcomeRefV1,
        expectedOutcomeAggregateVersion: Int,
        subject: AcceptanceSubjectV1,
        reason: String
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(acceptanceId)
        try CanonicalContractCodingV1.validatePositive(
            expectedOutcomeAggregateVersion
        )
        try CanonicalContractCodingV1.validateNonempty(reason)
        self.envelope = envelope
        self.acceptanceId = acceptanceId
        self.outcome = outcome
        self.expectedOutcomeAggregateVersion = expectedOutcomeAggregateVersion
        self.subject = subject
        self.reason = reason
    }
}

package enum AcceptanceHardGuardReasonV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case firstOnboarding
    case firstOutcomeType
    case subjectiveJudgment
    case publicRelease
    case payment
    case deletion
    case externalSend
    case highRisk
    case irreversibleRisk
    case unverified
}

package struct UserAcceptanceRequiredError: Error, Sendable, Equatable {
    package let reason: AcceptanceHardGuardReasonV1
    package init(reason: AcceptanceHardGuardReasonV1) {
        self.reason = reason
    }
}

package enum AcceptancePolicyEligibilityError: Error, Sendable, Equatable {
    case missingPolicy
    case referenceMismatch
    case wrongActor
    case inactive
    case outsideValidity
    case outcomeTypeMismatch
    case riskExceeded
    case outcomeTooOld
}

package struct AcceptanceAuthorizationError: Error, Sendable, Equatable {
    package init() {}
}

package struct InvalidAcceptanceTransitionError: Error, Sendable, Equatable {
    package init() {}
}

package struct AcceptanceReferenceError: Error, Sendable, Equatable {
    package init() {}
}
