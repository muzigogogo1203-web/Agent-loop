import Foundation

package enum ApprovalGrantStateV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case exhausted
    case revoked
    case expired
}

package enum ApprovalGrantorTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case user
    case policy
    case system
}

package enum ApprovalGranteeTypeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case cow
    case engine
    case system
}

package enum ApprovalDataLevelV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case local
    case workspace
    case external
    case sensitive
}

package enum ExternalAdapterReplayClassV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case replaySafe
    case idempotencyKeyed
    case nonReplayable
}

package struct ApprovalGrantorV1: Codable, Sendable, Equatable {
    package let type: ApprovalGrantorTypeV1
    package let id: String
    package let policyId: String?
    package let policyVersion: Int?
    package let policyHash: String?

    package static func user(_ id: String) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(id)
        return Self(
            type: .user, id: id, policyId: nil,
            policyVersion: nil, policyHash: nil
        )
    }

    package static func system(_ id: String) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(id)
        return Self(
            type: .system, id: id, policyId: nil,
            policyVersion: nil, policyHash: nil
        )
    }

    package static func policy(
        actorId: String,
        policyId: String,
        policyVersion: Int,
        policyHash: String
    ) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(actorId)
        try CanonicalContractCodingV1.validateCanonicalUUID(policyId)
        try CanonicalContractCodingV1.validatePositive(policyVersion)
        try CanonicalContractCodingV1.validateLowercaseHash(policyHash)
        return Self(
            type: .policy, id: actorId, policyId: policyId,
            policyVersion: policyVersion, policyHash: policyHash
        )
    }

    private init(
        type: ApprovalGrantorTypeV1,
        id: String,
        policyId: String?,
        policyVersion: Int?,
        policyHash: String?
    ) {
        self.type = type
        self.id = id
        self.policyId = policyId
        self.policyVersion = policyVersion
        self.policyHash = policyHash
    }
}

package struct ApprovalGranteeV1: Codable, Sendable, Equatable {
    package let type: ApprovalGranteeTypeV1
    package let id: String

    package init(type: ApprovalGranteeTypeV1, id: String) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        self.type = type
        self.id = id
    }
}

package struct ExternalOperationAdapterDescriptorV1:
    Codable, Sendable, Equatable, Hashable
{
    package let adapterId: String
    package let toolId: String
    package let replayClass: ExternalAdapterReplayClassV1

    package init(
        adapterId: String,
        toolId: String,
        replayClass: ExternalAdapterReplayClassV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(adapterId)
        try CanonicalContractCodingV1.validateNonempty(toolId)
        self.adapterId = adapterId
        self.toolId = toolId
        self.replayClass = replayClass
    }
}

package struct ApprovalGrantSnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let version: Int
    package let scopeVersion: Int
    package let grantor: ApprovalGrantorV1
    package let grantee: ApprovalGranteeV1
    package let capability: String
    package let campId: String
    package let cardId: String
    package let toolId: String
    package let approvedInputHash: String
    package let purpose: String
    package let dataLevel: ApprovalDataLevelV1
    package let adapterReplayClass: ExternalAdapterReplayClassV1
    package let validFrom: Date
    package let validUntil: Date
    package let maxUses: Int
    package let usedCount: Int
    package let state: ApprovalGrantStateV1
    package let revokedAt: Date?
    package let createdAt: Date
    package let updatedAt: Date
}

package struct ApprovalAnswerSnapshotV1: Codable, Sendable, Equatable {
    package let requestId: String
    package let approved: Bool
    package let answeredAt: Date
    package let grant: ApprovalGrantSnapshotV1?

    package init(
        requestId: String,
        approved: Bool,
        answeredAt: Date,
        grant: ApprovalGrantSnapshotV1?
    ) {
        self.requestId = requestId
        self.approved = approved
        self.answeredAt = answeredAt
        self.grant = grant
    }
}

package enum ApprovalGrantMatchV1: Sendable, Equatable {
    case authorized(ApprovalGrantSnapshotV1)
    case denied(reason: String?)
    case unavailable
    case absent
}

package struct CreateApprovalGrantCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let grantId: String
    package let grantor: ApprovalGrantorV1
    package let grantee: ApprovalGranteeV1
    package let capability: String
    package let campId: String
    package let cardId: String
    package let toolId: String
    package let approvedInputHash: String
    package let purpose: String
    package let dataLevel: ApprovalDataLevelV1
    package let adapterReplayClass: ExternalAdapterReplayClassV1
    package let validFrom: Date
    package let validUntil: Date
    package let maxUses: Int

    package init(
        envelope: CommandEnvelopeV1,
        grantId: String,
        grantor: ApprovalGrantorV1,
        grantee: ApprovalGranteeV1,
        capability: String,
        campId: String,
        cardId: String,
        toolId: String,
        approvedInputHash: String,
        purpose: String,
        dataLevel: ApprovalDataLevelV1,
        adapterReplayClass: ExternalAdapterReplayClassV1,
        validFrom: Date,
        validUntil: Date,
        maxUses: Int
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(grantId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateNonempty(capability)
        try CanonicalContractCodingV1.validateNonempty(toolId)
        try CanonicalContractCodingV1.validateLowercaseHash(approvedInputHash)
        try CanonicalContractCodingV1.validateNonempty(purpose)
        try CanonicalContractCodingV1.validateFinite(validFrom)
        try CanonicalContractCodingV1.validateFinite(validUntil)
        guard validUntil > validFrom, maxUses > 0 else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.grantId = grantId
        self.grantor = grantor
        self.grantee = grantee
        self.capability = capability
        self.campId = campId
        self.cardId = cardId
        self.toolId = toolId
        self.approvedInputHash = approvedInputHash
        self.purpose = purpose
        self.dataLevel = dataLevel
        self.adapterReplayClass = adapterReplayClass
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.maxUses = maxUses
    }
}

package enum ApprovalGrantUseStateV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case reserved
    case dispatching
    case accepted
    case succeeded
    case failedFinal
    case released
    case crashUnknown
    case abandonedUnknown
}

package struct ApprovalGrantUseSnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let grantId: String
    package let idempotencyKey: String
    package let toolId: String
    package let inputHash: String
    package let adapterId: String
    package let adapterReplayClass: ExternalAdapterReplayClassV1
    package let state: ApprovalGrantUseStateV1
    package let adapterOperationId: String?
    package let version: Int
    package let reservedAt: Date
    package let dispatchIntentAt: Date?
    package let adapterAcceptedAt: Date?
    package let finishedAt: Date?
}

package struct ReserveApprovalGrantUseCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let useId: String
    package let grantId: String
    package let expectedGrantVersion: Int
    package let capability: String
    package let campId: String
    package let cardId: String
    package let toolId: String
    package let inputHash: String
    package let adapter: ExternalOperationAdapterDescriptorV1

    package init(
        envelope: CommandEnvelopeV1,
        useId: String,
        grantId: String,
        expectedGrantVersion: Int,
        capability: String,
        campId: String,
        cardId: String,
        toolId: String,
        inputHash: String,
        adapter: ExternalOperationAdapterDescriptorV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(useId)
        try CanonicalContractCodingV1.validateCanonicalUUID(grantId)
        try CanonicalContractCodingV1.validatePositive(expectedGrantVersion)
        try CanonicalContractCodingV1.validateNonempty(capability)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
        try CanonicalContractCodingV1.validateNonempty(toolId)
        try CanonicalContractCodingV1.validateLowercaseHash(inputHash)
        self.envelope = envelope
        self.useId = useId
        self.grantId = grantId
        self.expectedGrantVersion = expectedGrantVersion
        self.capability = capability
        self.campId = campId
        self.cardId = cardId
        self.toolId = toolId
        self.inputHash = inputHash
        self.adapter = adapter
    }
}

package struct ApprovalGrantUseTransitionCommandV1:
    Sendable, Equatable
{
    package let envelope: CommandEnvelopeV1
    package let useId: String
    package let expectedUseVersion: Int
    package let expectedGrantVersion: Int?

    package init(
        envelope: CommandEnvelopeV1,
        useId: String,
        expectedUseVersion: Int,
        expectedGrantVersion: Int? = nil
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(useId)
        try CanonicalContractCodingV1.validatePositive(expectedUseVersion)
        if let expectedGrantVersion {
            try CanonicalContractCodingV1.validatePositive(
                expectedGrantVersion
            )
        }
        self.envelope = envelope
        self.useId = useId
        self.expectedUseVersion = expectedUseVersion
        self.expectedGrantVersion = expectedGrantVersion
    }
}

package enum ExternalOperationReceiptPhaseV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case dispatchIntent
    case adapterAccepted
    case effectConfirmed
    case noEffectConfirmed
    case reconciliationFailed
    case userResolved
}

package enum ExternalOperationReceiptResultV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case pending
    case succeeded
    case failedFinal
    case noEffect
    case unknown
    case abandonedUnknown
}

package enum ExternalOperationReceiptAuthorityV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case system
    case adapter
    case user
}

package struct ExternalOperationReceiptSnapshotV1:
    Codable, Sendable, Equatable
{
    package let id: String
    package let grantUseId: String
    package let receiptIdempotencyKey: String
    package let ordinal: Int
    package let phase: ExternalOperationReceiptPhaseV1
    package let result: ExternalOperationReceiptResultV1
    package let adapterOperationId: String?
    package let receiptRef: String?
    package let receiptJSON: JSONValue
    package let receiptHash: String
    package let authority: ExternalOperationReceiptAuthorityV1
    package let authorityId: String
    package let createdAt: Date
}

package struct ApprovalGrantDispatchSnapshotV1:
    Codable, Sendable, Equatable
{
    package let grant: ApprovalGrantSnapshotV1
    package let use: ApprovalGrantUseSnapshotV1
    package let receipt: ExternalOperationReceiptSnapshotV1?
}

package struct AdapterAcceptanceAttestationV1: Sendable, Equatable {
    package let adapterId: String
    package let useId: String
    package let useIdempotencyKey: String
    package let operationId: String
    package let evidenceHash: String

    package init(
        adapterId: String,
        useId: String,
        useIdempotencyKey: String,
        operationId: String,
        evidenceHash: String
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(adapterId)
        try CanonicalContractCodingV1.validateNonempty(useId)
        try CanonicalContractCodingV1.validateNonempty(useIdempotencyKey)
        try CanonicalContractCodingV1.validateNonempty(operationId)
        try CanonicalContractCodingV1.validateLowercaseHash(evidenceHash)
        self.adapterId = adapterId
        self.useId = useId
        self.useIdempotencyKey = useIdempotencyKey
        self.operationId = operationId
        self.evidenceHash = evidenceHash
    }
}

package struct AdapterEffectAttestationV1: Sendable, Equatable {
    package let adapterId: String
    package let useId: String
    package let useIdempotencyKey: String
    package let operationId: String?
    package let result: ExternalOperationReceiptResultV1
    package let receiptRef: String?
    package let evidenceHash: String

    package init(
        adapterId: String,
        useId: String,
        useIdempotencyKey: String,
        operationId: String?,
        result: ExternalOperationReceiptResultV1,
        receiptRef: String?,
        evidenceHash: String
    ) throws {
        guard result == .succeeded || result == .failedFinal else {
            throw P1ContractValidationError.invalidMembership
        }
        try CanonicalContractCodingV1.validateNonempty(adapterId)
        try CanonicalContractCodingV1.validateNonempty(useId)
        try CanonicalContractCodingV1.validateNonempty(useIdempotencyKey)
        try CanonicalContractCodingV1.validateOptionalNonempty(operationId)
        try CanonicalContractCodingV1.validateOptionalNonempty(receiptRef)
        try CanonicalContractCodingV1.validateLowercaseHash(evidenceHash)
        self.adapterId = adapterId
        self.useId = useId
        self.useIdempotencyKey = useIdempotencyKey
        self.operationId = operationId
        self.result = result
        self.receiptRef = receiptRef
        self.evidenceHash = evidenceHash
    }
}

package struct AdapterNoEffectAttestationV1: Sendable, Equatable {
    package let adapterId: String
    package let useId: String
    package let useIdempotencyKey: String
    package let operationId: String?
    package let evidenceHash: String
    package let receiptRef: String?

    package init(
        adapterId: String,
        useId: String,
        useIdempotencyKey: String,
        operationId: String?,
        evidenceHash: String,
        receiptRef: String?
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(adapterId)
        try CanonicalContractCodingV1.validateNonempty(useId)
        try CanonicalContractCodingV1.validateNonempty(useIdempotencyKey)
        try CanonicalContractCodingV1.validateOptionalNonempty(operationId)
        try CanonicalContractCodingV1.validateLowercaseHash(evidenceHash)
        try CanonicalContractCodingV1.validateOptionalNonempty(receiptRef)
        self.adapterId = adapterId
        self.useId = useId
        self.useIdempotencyKey = useIdempotencyKey
        self.operationId = operationId
        self.evidenceHash = evidenceHash
        self.receiptRef = receiptRef
    }
}

package enum ExternalOperationUserResolutionV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case succeeded
    case abandonedUnknown
}

package struct ResolveExternalOperationCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let useId: String
    package let expectedUseVersion: Int
    package let resolution: ExternalOperationUserResolutionV1
    package let reason: String

    package init(
        envelope: CommandEnvelopeV1,
        useId: String,
        expectedUseVersion: Int,
        resolution: ExternalOperationUserResolutionV1,
        reason: String
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(useId)
        try CanonicalContractCodingV1.validatePositive(expectedUseVersion)
        try CanonicalContractCodingV1.validateNonempty(reason)
        self.envelope = envelope
        self.useId = useId
        self.expectedUseVersion = expectedUseVersion
        self.resolution = resolution
        self.reason = reason
    }
}

package struct ApprovalGrantScopeError: Error, Sendable, Equatable {
    package init() {}
}

package struct ApprovalGrantAuthorizationError: Error, Sendable, Equatable {
    package init() {}
}

package struct ApprovalGrantConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct ApprovalGrantTransitionError: Error, Sendable, Equatable {
    package init() {}
}

package struct ExternalOperationAttestationError:
    Error, Sendable, Equatable
{
    package init() {}
}

package struct ApprovalAnswerContractError: Error, Sendable, Equatable {
    package init() {}
}
