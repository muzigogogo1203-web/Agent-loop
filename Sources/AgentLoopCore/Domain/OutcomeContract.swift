import Foundation

package enum P1DActorID {
    package static let localOwner = "user:local-owner"
    package static let coach = "system:coach:v1"
    package static let outcomeContract = "system:outcome-contract:v1"
    package static let outcomeReopen = "system:outcome-reopen:v1"
    package static let verification = "system:verification:v1"
    package static let dependencyInvalidator = "system:dependency-invalidator:v1"
    package static let delivery = "system:delivery:v1"
    package static let externalOperation = "system:external-operation:v1"
}

package enum VerificationActorTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case cow
    case deterministic
}

package enum VerificationMethodV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case command
    case tests
    case build
    case artifactHash
    case externalReceipt
    case modelSupplement
}

package enum VerificationRequirementGroupModeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case all
    case any
}

package struct VerificationRequirementV1: Codable, Sendable, Equatable {
    package let requirementId: String
    package let requirementVersion: Int
    package let verifierType: VerificationActorTypeV1
    package let verifierId: String
    package let method: VerificationMethodV1
    package let ruleId: String
    package let ruleVersion: Int
    package let config: [String: JSONValue]
    package let requirementHash: String

    package init(
        requirementId: String,
        requirementVersion: Int,
        verifierType: VerificationActorTypeV1,
        verifierId: String,
        method: VerificationMethodV1,
        ruleId: String,
        ruleVersion: Int,
        config: [String: JSONValue]
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(requirementId)
        try CanonicalContractCodingV1.validatePositive(requirementVersion)
        try CanonicalContractCodingV1.validateNonempty(verifierId)
        try CanonicalContractCodingV1.validateNonempty(ruleId)
        try CanonicalContractCodingV1.validatePositive(ruleVersion)
        for key in config.keys {
            try CanonicalContractCodingV1.validateNonempty(key)
        }
        let material = HashMaterial(
            requirementId: requirementId,
            requirementVersion: requirementVersion,
            verifierType: verifierType,
            verifierId: verifierId,
            method: method,
            ruleId: ruleId,
            ruleVersion: ruleVersion,
            config: config
        )
        let requirementHash = try CanonicalContractCodingV1.hash(material)
        self.requirementId = requirementId
        self.requirementVersion = requirementVersion
        self.verifierType = verifierType
        self.verifierId = verifierId
        self.method = method
        self.ruleId = ruleId
        self.ruleVersion = ruleVersion
        self.config = config
        self.requirementHash = requirementHash
    }

    private struct HashMaterial: Codable {
        let requirementId: String
        let requirementVersion: Int
        let verifierType: VerificationActorTypeV1
        let verifierId: String
        let method: VerificationMethodV1
        let ruleId: String
        let ruleVersion: Int
        let config: [String: JSONValue]
    }
}

package struct VerificationRequirementGroupV1:
    Codable, Sendable, Equatable
{
    package let groupId: String
    package let mode: VerificationRequirementGroupModeV1
    package let requirements: [VerificationRequirementV1]

    package init(
        groupId: String,
        mode: VerificationRequirementGroupModeV1,
        requirements: [VerificationRequirementV1]
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(groupId)
        guard !requirements.isEmpty,
              Set(requirements.map(\.requirementId)).count == requirements.count
        else {
            throw P1ContractValidationError.invalidMembership
        }
        self.groupId = groupId
        self.mode = mode
        self.requirements = requirements
    }
}

package enum OutcomeRiskClassV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case low
    case normal
    case high
    case irreversible
}

package enum OutcomeAcceptanceOwnerV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case user
    case policy
}

package struct AcceptancePolicyRefV1: Codable, Sendable, Equatable {
    package let id: String
    package let version: Int
    package let hash: String

    package init(id: String, version: Int, hash: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        self.id = id
        self.version = version
        self.hash = hash
    }
}

package struct OutcomeContractBodyV1: Codable, Sendable, Equatable {
    package let outcomeType: String
    package let deliverables: [String]
    package let acceptanceCriteria: [String]
    package let verificationGroups: [VerificationRequirementGroupV1]
    package let unacceptableDeviations: [String]
    package let requiredDependencies: [String]
    package let optionalDependencies: [String]
    package let requiresSubjectiveJudgment: Bool
    package let includesPublicRelease: Bool
    package let includesPayment: Bool
    package let includesDeletion: Bool
    package let includesExternalSend: Bool
    package let riskClass: OutcomeRiskClassV1
    package let acceptanceOwner: OutcomeAcceptanceOwnerV1
    package let acceptancePolicy: AcceptancePolicyRefV1?

    package init(
        outcomeType: String,
        deliverables: [String],
        acceptanceCriteria: [String],
        verificationGroups: [VerificationRequirementGroupV1],
        unacceptableDeviations: [String],
        requiredDependencies: [String],
        optionalDependencies: [String],
        requiresSubjectiveJudgment: Bool,
        includesPublicRelease: Bool,
        includesPayment: Bool,
        includesDeletion: Bool,
        includesExternalSend: Bool,
        riskClass: OutcomeRiskClassV1,
        acceptanceOwner: OutcomeAcceptanceOwnerV1,
        acceptancePolicy: AcceptancePolicyRefV1?
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(outcomeType)
        for value in deliverables + acceptanceCriteria
            + unacceptableDeviations + requiredDependencies
            + optionalDependencies
        {
            try CanonicalContractCodingV1.validateNonempty(value)
        }
        guard !deliverables.isEmpty,
              !acceptanceCriteria.isEmpty,
              !verificationGroups.isEmpty,
              Set(verificationGroups.map(\.groupId)).count
                == verificationGroups.count,
              Set(verificationGroups.flatMap { $0.requirements }
                .map(\.requirementId)).count
                == verificationGroups.flatMap({ $0.requirements }).count,
              (acceptanceOwner == .policy) == (acceptancePolicy != nil)
        else {
            throw P1ContractValidationError.invalidMembership
        }
        self.outcomeType = outcomeType
        self.deliverables = deliverables
        self.acceptanceCriteria = acceptanceCriteria
        self.verificationGroups = verificationGroups
        self.unacceptableDeviations = unacceptableDeviations
        self.requiredDependencies = requiredDependencies
        self.optionalDependencies = optionalDependencies
        self.requiresSubjectiveJudgment = requiresSubjectiveJudgment
        self.includesPublicRelease = includesPublicRelease
        self.includesPayment = includesPayment
        self.includesDeletion = includesDeletion
        self.includesExternalSend = includesExternalSend
        self.riskClass = riskClass
        self.acceptanceOwner = acceptanceOwner
        self.acceptancePolicy = acceptancePolicy
    }
}

package struct UnderstandingVersionRefV1: Codable, Sendable, Equatable {
    package let id: String
    package let version: Int
    package let hash: String

    package init(id: String, version: Int, hash: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        self.id = id
        self.version = version
        self.hash = hash
    }
}

package struct OutcomeContractRef: Codable, Sendable, Equatable, Hashable {
    package let id: String
    package let version: Int
    package let hash: String

    package init(id: String, version: Int, hash: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        self.id = id
        self.version = version
        self.hash = hash
    }
}

package enum OutcomeContractStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case draft
    case active
    case superseded
    case fulfilled
    case canceled
}

package struct OutcomeContractSnapshotV1: Codable, Sendable, Equatable {
    package let ref: OutcomeContractRef
    package let goalId: String
    package let understanding: UnderstandingVersionRefV1
    package let body: OutcomeContractBodyV1
    package let status: OutcomeContractStatusV1
    package let createdByActorId: String
    package let activatedByActorId: String?
    package let createdAt: Date
    package let activatedAt: Date?

    package var contentHash: String { ref.hash }
}

package struct CreateOutcomeContractDraftCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let contractId: String
    package let goal: GoalHeadV1
    package let understanding: UnderstandingVersionRefV1
    package let body: OutcomeContractBodyV1

    package init(
        envelope: CommandEnvelopeV1,
        contractId: String,
        goal: GoalHeadV1,
        understanding: UnderstandingVersionRefV1,
        body: OutcomeContractBodyV1
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(contractId)
        self.envelope = envelope
        self.contractId = contractId
        self.goal = goal
        self.understanding = understanding
        self.body = body
    }
}

package struct ReviseOutcomeContractCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let contract: OutcomeContractRef
    package let body: OutcomeContractBodyV1

    package init(
        envelope: CommandEnvelopeV1,
        contract: OutcomeContractRef,
        body: OutcomeContractBodyV1
    ) {
        self.envelope = envelope
        self.contract = contract
        self.body = body
    }
}

package struct ActivateOutcomeContractCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let contract: OutcomeContractRef

    package init(envelope: CommandEnvelopeV1, contract: OutcomeContractRef) {
        self.envelope = envelope
        self.contract = contract
    }
}

package struct ChangeOutcomeContractStatusCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let contract: OutcomeContractRef

    package init(envelope: CommandEnvelopeV1, contract: OutcomeContractRef) {
        self.envelope = envelope
        self.contract = contract
    }
}

package enum P1DCommandAuthorizationError: Error, Sendable, Equatable {
    case forbiddenActor
    case forbiddenDevice
}

package enum OutcomeContractActivationError: Error, Sendable, Equatable {
    case missingContract
    case staleUnderstanding
    case unconfirmedUnderstanding
    case invalidRequirements
    case invalidPolicy
}

package struct InvalidOutcomeContractTransitionError:
    Error, Sendable, Equatable
{
    package init() {}
}
