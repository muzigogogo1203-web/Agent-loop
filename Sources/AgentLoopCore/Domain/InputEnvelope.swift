import Foundation
import GRDB

package enum InputSourceTypeV1: String, Codable, Sendable, Equatable, CaseIterable {
    case text
    case url
    case file
    case image
    case audio
    case device
    case connector
}

package enum InputExplicitIntentV1: String, Codable, Sendable, Equatable, CaseIterable {
    case unspecified
    case archiveOnly
    case organize
    case createGoal
    case startNow
}

package enum InputPrivacyLevelV1: String, Codable, Sendable, Equatable, CaseIterable {
    case localOnly
    case encryptedSync
    case cloudExecution
}

package enum InputEnvelopeStatusV1: String, Codable, Sendable, Equatable, CaseIterable {
    case captured
    case parseFailed
    case campAssignmentRequired
    case campAmbiguous
    case coaching
    case archived
    case goalCreated
    case deletedTombstone
}

package enum InputRetentionStateV1: String, Codable, Sendable, Equatable, CaseIterable {
    case active
    case deletionRequested
    case deletedTombstone
}

package struct InputEnvelopeRecord:
    Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "input_envelope"

    package var id: String
    package var schemaVersion: Int
    package var aggregateVersion: Int
    package var idempotencyKey: String
    package var sourceType: InputSourceTypeV1
    package var sourceDeviceId: String?
    package var connectorId: String?
    package var authorId: String?
    package var capturedAt: Date
    package var inlineText: String?
    package var payloadRef: String?
    package var contentHash: String
    package var candidateCampIds: [String]
    package var campId: String?
    package var explicitIntent: InputExplicitIntentV1
    package var privacyLevel: InputPrivacyLevelV1
    package var status: InputEnvelopeStatusV1
    package var errorCode: String?
    package var errorMessage: String?
    package var parentInputId: String?
    package var retentionState: InputRetentionStateV1
    package var createdAt: Date
    package var updatedAt: Date
    package var deletedAt: Date?

    package init(
        id: String,
        schemaVersion: Int,
        aggregateVersion: Int,
        idempotencyKey: String,
        sourceType: InputSourceTypeV1,
        sourceDeviceId: String?,
        connectorId: String?,
        authorId: String?,
        capturedAt: Date,
        inlineText: String?,
        payloadRef: String?,
        contentHash: String,
        candidateCampIds: [String],
        campId: String?,
        explicitIntent: InputExplicitIntentV1,
        privacyLevel: InputPrivacyLevelV1,
        status: InputEnvelopeStatusV1,
        errorCode: String?,
        errorMessage: String?,
        parentInputId: String?,
        retentionState: InputRetentionStateV1,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date?
    ) throws {
        try InputContractValidationV1.validateRecordFields(
            id: id,
            schemaVersion: schemaVersion,
            aggregateVersion: aggregateVersion,
            idempotencyKey: idempotencyKey,
            sourceDeviceId: sourceDeviceId,
            connectorId: connectorId,
            authorId: authorId,
            capturedAt: capturedAt,
            inlineText: inlineText,
            payloadRef: payloadRef,
            contentHash: contentHash,
            candidateCampIds: candidateCampIds,
            campId: campId,
            errorCode: errorCode,
            errorMessage: errorMessage,
            parentInputId: parentInputId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            status: status,
            retentionState: retentionState,
            explicitIntent: explicitIntent,
            privacyLevel: privacyLevel
        )
        self.id = id
        self.schemaVersion = schemaVersion
        self.aggregateVersion = aggregateVersion
        self.idempotencyKey = idempotencyKey
        self.sourceType = sourceType
        self.sourceDeviceId = sourceDeviceId
        self.connectorId = connectorId
        self.authorId = authorId
        self.capturedAt = capturedAt
        self.inlineText = inlineText
        self.payloadRef = payloadRef
        self.contentHash = contentHash
        self.candidateCampIds = candidateCampIds
        self.campId = campId
        self.explicitIntent = explicitIntent
        self.privacyLevel = privacyLevel
        self.status = status
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.parentInputId = parentInputId
        self.retentionState = retentionState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    package init(row: Row) throws {
        let candidateJSON: String = row["candidateCampIdsJson"]
        let candidates = try CanonicalContractCodingV1.decode(
            [String].self,
            from: Data(candidateJSON.utf8)
        )
        let sourceTypeRaw: String = row["sourceType"]
        let explicitIntentRaw: String = row["explicitIntent"]
        let privacyLevelRaw: String = row["privacyLevel"]
        let statusRaw: String = row["status"]
        let retentionStateRaw: String = row["retentionState"]
        guard let sourceType = InputSourceTypeV1(rawValue: sourceTypeRaw),
              let explicitIntent = InputExplicitIntentV1(
                rawValue: explicitIntentRaw
              ),
              let privacyLevel = InputPrivacyLevelV1(rawValue: privacyLevelRaw),
              let status = InputEnvelopeStatusV1(rawValue: statusRaw),
              let retentionState = InputRetentionStateV1(
                rawValue: retentionStateRaw
              )
        else {
            throw P1ContractValidationError.invalidMembership
        }
        try self.init(
            id: row["id"],
            schemaVersion: row["schemaVersion"],
            aggregateVersion: row["aggregateVersion"],
            idempotencyKey: row["idempotencyKey"],
            sourceType: sourceType,
            sourceDeviceId: row["sourceDeviceId"],
            connectorId: row["connectorId"],
            authorId: row["authorId"],
            capturedAt: row["capturedAt"],
            inlineText: row["inlineText"],
            payloadRef: row["payloadRef"],
            contentHash: row["contentHash"],
            candidateCampIds: candidates,
            campId: row["campId"],
            explicitIntent: explicitIntent,
            privacyLevel: privacyLevel,
            status: status,
            errorCode: row["errorCode"],
            errorMessage: row["errorMessage"],
            parentInputId: row["parentInputId"],
            retentionState: retentionState,
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"],
            deletedAt: row["deletedAt"]
        )
    }

    package func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["schemaVersion"] = schemaVersion
        container["aggregateVersion"] = aggregateVersion
        container["idempotencyKey"] = idempotencyKey
        container["sourceType"] = sourceType.rawValue
        container["sourceDeviceId"] = sourceDeviceId
        container["connectorId"] = connectorId
        container["authorId"] = authorId
        container["capturedAt"] = capturedAt
        container["inlineText"] = inlineText
        container["payloadRef"] = payloadRef
        container["contentHash"] = contentHash
        container["candidateCampIdsJson"] = try CanonicalContractCodingV1.string(
            candidateCampIds
        )
        container["campId"] = campId
        container["explicitIntent"] = explicitIntent.rawValue
        container["privacyLevel"] = privacyLevel.rawValue
        container["status"] = status.rawValue
        container["errorCode"] = errorCode
        container["errorMessage"] = errorMessage
        container["parentInputId"] = parentInputId
        container["retentionState"] = retentionState.rawValue
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
        container["deletedAt"] = deletedAt
    }
}

package struct InputParsingWorkInputV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let inputId: String
    package let contentHash: String

    package init(inputId: String, contentHash: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(inputId)
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        schemaVersion = 1
        self.inputId = inputId
        self.contentHash = contentHash
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case inputId
        case contentHash
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw P1ContractValidationError.invalidSchemaVersion
        }
        try self.init(
            inputId: values.decode(String.self, forKey: .inputId),
            contentHash: values.decode(String.self, forKey: .contentHash)
        )
    }
}

package struct InputHeadV1: Sendable, Equatable, Codable {
    package let inputId: String
    package let auditCampId: String
    package let expectedInputVersion: Int

    package init(
        inputId: String,
        auditCampId: String,
        expectedInputVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(inputId)
        try CanonicalContractCodingV1.validateCampID(auditCampId)
        try CanonicalContractCodingV1.validatePositive(expectedInputVersion)
        self.inputId = inputId
        self.auditCampId = auditCampId
        self.expectedInputVersion = expectedInputVersion
    }
}

package struct WorkClaimV1: Sendable, Equatable, Codable {
    package let workId: String
    package let attempt: Int
    package let workerId: String
    package let version: Int
    package let leaseExpiresAt: Date

    package init(claim: DurableWorkClaim) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(claim.workId)
        try CanonicalContractCodingV1.validatePositive(claim.attempt)
        try CanonicalContractCodingV1.validateNonempty(claim.workerId)
        try CanonicalContractCodingV1.validatePositive(claim.version)
        try CanonicalContractCodingV1.validateFinite(claim.leaseExpiresAt)
        workId = claim.workId
        attempt = claim.attempt
        workerId = claim.workerId
        version = claim.version
        leaseExpiresAt = claim.leaseExpiresAt
    }

    package var durableClaim: DurableWorkClaim {
        DurableWorkClaim(
            workId: workId,
            attempt: attempt,
            workerId: workerId,
            version: version,
            leaseExpiresAt: leaseExpiresAt
        )
    }
}

package enum ActiveWorkBranchV1: Sendable, Equatable, Codable {
    case none
    case expected(workId: String, expectedVersion: Int)

    private enum Kind: String, Codable {
        case none
        case expected
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case workId
        case expectedVersion
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .none:
            guard try values.decodeIfPresent(String.self, forKey: .workId) == nil,
                  try values.decodeIfPresent(Int.self, forKey: .expectedVersion) == nil
            else {
                throw P1ContractValidationError.invalidMembership
            }
            self = .none
        case .expected:
            let workId = try values.decode(String.self, forKey: .workId)
            let version = try values.decode(Int.self, forKey: .expectedVersion)
            try CanonicalContractCodingV1.validateCanonicalUUID(workId)
            try CanonicalContractCodingV1.validatePositive(version)
            self = .expected(workId: workId, expectedVersion: version)
        }
    }

    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try values.encode(Kind.none, forKey: .kind)
            try values.encodeNil(forKey: .workId)
            try values.encodeNil(forKey: .expectedVersion)
        case let .expected(workId, expectedVersion):
            try CanonicalContractCodingV1.validateCanonicalUUID(workId)
            try CanonicalContractCodingV1.validatePositive(expectedVersion)
            try values.encode(Kind.expected, forKey: .kind)
            try values.encode(workId, forKey: .workId)
            try values.encode(expectedVersion, forKey: .expectedVersion)
        }
    }
}

package enum InputParseRouteV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case campAssignmentRequired
    case campAmbiguous
    case coaching
    case archived

    package var status: InputEnvelopeStatusV1 {
        switch self {
        case .campAssignmentRequired: .campAssignmentRequired
        case .campAmbiguous: .campAmbiguous
        case .coaching: .coaching
        case .archived: .archived
        }
    }
}

package struct InputParseResultV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let route: InputParseRouteV1
    package let candidateCampIds: [String]
    package let assignedCampId: String?

    package init(
        route: InputParseRouteV1,
        candidateCampIds: [String],
        assignedCampId: String?
    ) throws {
        try InputContractValidationV1.validateCampIDs(candidateCampIds)
        switch route {
        case .campAssignmentRequired:
            guard !candidateCampIds.isEmpty, assignedCampId == nil else {
                throw P1ContractValidationError.invalidMembership
            }
        case .campAmbiguous:
            guard candidateCampIds.count >= 2, assignedCampId == nil else {
                throw P1ContractValidationError.invalidMembership
            }
        case .coaching, .archived:
            guard candidateCampIds.isEmpty, let assignedCampId else {
                throw P1ContractValidationError.invalidMembership
            }
            try CanonicalContractCodingV1.validateCampID(assignedCampId)
        }
        schemaVersion = 1
        self.route = route
        self.candidateCampIds = candidateCampIds
        self.assignedCampId = assignedCampId
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case route
        case candidateCampIds
        case assignedCampId
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1,
              values.contains(.assignedCampId)
        else {
            throw P1ContractValidationError.invalidSchemaVersion
        }
        try self.init(
            route: values.decode(InputParseRouteV1.self, forKey: .route),
            candidateCampIds: values.decode([String].self, forKey: .candidateCampIds),
            assignedCampId: values.decodeIfPresent(String.self, forKey: .assignedCampId)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(route, forKey: .route)
        try values.encode(candidateCampIds, forKey: .candidateCampIds)
        try values.encode(assignedCampId, forKey: .assignedCampId)
    }
}

package enum InputParseFailureTerminalDispositionV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case retryScheduled
    case parseFailed

    package static func derive(
        failure: ControlWorkerProviderFailureV1,
        attempt: Int,
        maxAttempts: Int
    ) throws -> Self {
        guard maxAttempts == 4, (1 ... 4).contains(attempt) else {
            throw P1ContractValidationError.invalidInteger
        }
        if failure.disposition == .transient, attempt < maxAttempts {
            return .retryScheduled
        }
        return .parseFailed
    }
}

package typealias InputCaptureReceiptV1 = CampSafeCommandResultV1

package struct CaptureInputCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let inputId: String
    package let auditCampId: String
    package let initialCampId: String?
    package let sourceType: InputSourceTypeV1
    package let sourceDeviceId: String?
    package let connectorId: String?
    package let authorId: String?
    package let capturedAt: Date
    package let inlineText: String?
    package let payloadRef: String?
    package let contentHash: String
    package let candidateCampIds: [String]
    package let explicitIntent: InputExplicitIntentV1
    package let privacyLevel: InputPrivacyLevelV1
    package let parentInputId: String?

    package init(
        envelope: CommandEnvelopeV1,
        inputId: String,
        auditCampId: String,
        initialCampId: String?,
        sourceType: InputSourceTypeV1,
        sourceDeviceId: String?,
        connectorId: String?,
        authorId: String?,
        capturedAt: Date,
        inlineText: String?,
        payloadRef: String?,
        contentHash: String,
        candidateCampIds: [String],
        explicitIntent: InputExplicitIntentV1,
        privacyLevel: InputPrivacyLevelV1,
        parentInputId: String?
    ) throws {
        try P1CommandAuthorizationV1.validate(
            commandType: .inputCapture,
            envelope: envelope
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(inputId)
        try CanonicalContractCodingV1.validateCampID(auditCampId)
        if let initialCampId {
            try CanonicalContractCodingV1.validateCampID(initialCampId)
            guard initialCampId == auditCampId else {
                throw InputCampScopeError()
            }
        }
        if let sourceDeviceId {
            try CanonicalContractCodingV1.validateCanonicalUUID(sourceDeviceId)
        }
        try CanonicalContractCodingV1.validateOptionalNonempty(connectorId)
        try CanonicalContractCodingV1.validateOptionalNonempty(authorId)
        try CanonicalContractCodingV1.validateFinite(capturedAt)
        try InputContractValidationV1.validateBody(
            inlineText: inlineText,
            payloadRef: payloadRef
        )
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        try InputContractValidationV1.validateCampIDs(candidateCampIds)
        if let parentInputId {
            try CanonicalContractCodingV1.validateCanonicalUUID(parentInputId)
        }
        self.envelope = envelope
        self.inputId = inputId
        self.auditCampId = auditCampId
        self.initialCampId = initialCampId
        self.sourceType = sourceType
        self.sourceDeviceId = sourceDeviceId
        self.connectorId = connectorId
        self.authorId = authorId
        self.capturedAt = capturedAt
        self.inlineText = inlineText
        self.payloadRef = payloadRef
        self.contentHash = contentHash
        self.candidateCampIds = candidateCampIds
        self.explicitIntent = explicitIntent
        self.privacyLevel = privacyLevel
        self.parentInputId = parentInputId
    }

    private enum CodingKeys: String, CodingKey {
        case inputId, auditCampId, initialCampId, sourceType, sourceDeviceId
        case connectorId, authorId, capturedAt, inlineText, payloadRef
        case contentHash, candidateCampIds, explicitIntent, privacyLevel
        case parentInputId
    }
}

package struct CommitInputParseResultCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let claim: WorkClaimV1
    package let result: InputParseResultV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        claim: WorkClaimV1,
        result: InputParseResultV1
    ) throws {
        try P1CommandAuthorizationV1.validate(
            commandType: .inputParseResult,
            envelope: envelope
        )
        self.envelope = envelope
        self.input = input
        self.claim = claim
        self.result = result
    }

    private enum CodingKeys: String, CodingKey { case input, claim, result }
}

package struct RecordInputParseFailureCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let claim: WorkClaimV1
    package let failure: ControlWorkerProviderFailureV1
    package let terminalDisposition: InputParseFailureTerminalDispositionV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        claim: WorkClaimV1,
        failure: ControlWorkerProviderFailureV1,
        terminalDisposition: InputParseFailureTerminalDispositionV1
    ) throws {
        try P1CommandAuthorizationV1.validate(
            commandType: .inputParseFailure,
            envelope: envelope
        )
        self.envelope = envelope
        self.input = input
        self.claim = claim
        self.failure = failure
        self.terminalDisposition = terminalDisposition
    }

    private enum CodingKeys: String, CodingKey {
        case input, claim, failure, terminalDisposition
    }
}

package struct RequeueInputParsingCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1

    package init(envelope: CommandEnvelopeV1, input: InputHeadV1) throws {
        try P1CommandAuthorizationV1.validate(
            commandType: .inputRequeueParsing,
            envelope: envelope
        )
        self.envelope = envelope
        self.input = input
    }

    private enum CodingKeys: String, CodingKey { case input }
}

package struct CancelInputParsingAndDeleteCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1
    ) throws {
        try P1CommandAuthorizationV1.validate(
            commandType: .inputCancelParsingAndDelete,
            envelope: envelope
        )
        guard case .expected = activeParsingBranch else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
    }

    private enum CodingKeys: String, CodingKey { case input, activeParsingBranch }
}

package struct RequestInputCampAssignmentCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1
    package let candidateCampIds: [String]

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1,
        candidateCampIds: [String]
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputRequestCampAssignment,
            envelope: envelope,
            branch: activeParsingBranch
        )
        try InputContractValidationV1.validateCampIDs(candidateCampIds)
        guard !candidateCampIds.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
        self.candidateCampIds = candidateCampIds
    }

    private enum CodingKeys: String, CodingKey {
        case input, activeParsingBranch, candidateCampIds
    }
}

package struct RecordInputCampAmbiguityCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1
    package let candidateCampIds: [String]

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1,
        candidateCampIds: [String]
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputRecordCampAmbiguity,
            envelope: envelope,
            branch: activeParsingBranch
        )
        try InputContractValidationV1.validateCampIDs(candidateCampIds)
        guard candidateCampIds.count >= 2 else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
        self.candidateCampIds = candidateCampIds
    }

    private enum CodingKeys: String, CodingKey {
        case input, activeParsingBranch, candidateCampIds
    }
}

package struct AssignInputCampCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1
    package let targetCampId: String
    package let targetStatus: InputEnvelopeStatusV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1,
        targetCampId: String,
        targetStatus: InputEnvelopeStatusV1
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputAssignCamp,
            envelope: envelope,
            branch: activeParsingBranch
        )
        try CanonicalContractCodingV1.validateCampID(targetCampId)
        guard targetCampId == input.auditCampId else {
            throw InputCampScopeError()
        }
        guard targetStatus == .coaching || targetStatus == .archived else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
        self.targetCampId = targetCampId
        self.targetStatus = targetStatus
    }

    private enum CodingKeys: String, CodingKey {
        case input, activeParsingBranch, targetCampId, targetStatus
    }
}

package struct ArchiveInputCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputArchive,
            envelope: envelope,
            branch: activeParsingBranch
        )
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
    }

    private enum CodingKeys: String, CodingKey { case input, activeParsingBranch }
}

package struct MarkInputCoachingCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputMarkCoaching,
            envelope: envelope,
            branch: activeParsingBranch
        )
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
    }

    private enum CodingKeys: String, CodingKey { case input, activeParsingBranch }
}

package struct ConvertInputToGoalCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1
    package let goalId: String
    package let title: String
    package let rawIntent: String

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1,
        goalId: String,
        title: String,
        rawIntent: String
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputConvertToGoal,
            envelope: envelope,
            branch: activeParsingBranch
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        try CanonicalContractCodingV1.validateNonempty(title)
        try CanonicalContractCodingV1.validateNarrativeText(rawIntent)
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
        self.goalId = goalId
        self.title = title
        self.rawIntent = rawIntent
    }

    private enum CodingKeys: String, CodingKey {
        case input, activeParsingBranch, goalId, title, rawIntent
    }
}

package struct RequestInputDeletionCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputRequestDeletion,
            envelope: envelope,
            branch: activeParsingBranch
        )
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
    }

    private enum CodingKeys: String, CodingKey { case input, activeParsingBranch }
}

package struct CompleteInputDeletionCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let input: InputHeadV1
    package let activeParsingBranch: ActiveWorkBranchV1

    package init(
        envelope: CommandEnvelopeV1,
        input: InputHeadV1,
        activeParsingBranch: ActiveWorkBranchV1
    ) throws {
        try InputContractValidationV1.validateOrdinary(
            commandType: .inputCompleteDeletion,
            envelope: envelope,
            branch: activeParsingBranch
        )
        self.envelope = envelope
        self.input = input
        self.activeParsingBranch = activeParsingBranch
    }

    private enum CodingKeys: String, CodingKey { case input, activeParsingBranch }
}

package struct InputTransitionEdgeV1: Sendable, Equatable, Hashable {
    package let from: InputEnvelopeStatusV1
    package let to: InputEnvelopeStatusV1

    package init(from: InputEnvelopeStatusV1, to: InputEnvelopeStatusV1) {
        self.from = from
        self.to = to
    }
}

package enum InputTransitionPolicyV1 {
    package static func allows(_ edge: InputTransitionEdgeV1) -> Bool {
        legal.contains(edge)
    }

    private static let legal: Set<InputTransitionEdgeV1> = [
        .init(from: .captured, to: .campAssignmentRequired),
        .init(from: .captured, to: .campAmbiguous),
        .init(from: .captured, to: .coaching),
        .init(from: .captured, to: .archived),
        .init(from: .captured, to: .goalCreated),
        .init(from: .parseFailed, to: .captured),
        .init(from: .campAssignmentRequired, to: .coaching),
        .init(from: .campAssignmentRequired, to: .archived),
        .init(from: .campAssignmentRequired, to: .goalCreated),
        .init(from: .campAmbiguous, to: .coaching),
        .init(from: .campAmbiguous, to: .archived),
        .init(from: .campAmbiguous, to: .goalCreated),
        .init(from: .coaching, to: .archived),
        .init(from: .coaching, to: .goalCreated),
    ]
}

package struct InputCampScopeError: Error, Sendable, Equatable {
    package init() {}
}

package struct InputActiveParsingConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct InputProjectionVersionConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct ControlWorkerTerminalTimeError: Error, Sendable, Equatable {
    package init() {}
}

package struct LegacyIngestionDisplayV1: Sendable, Equatable {
    package let legacyIngestionId: String
    package let title: String?
    package let body: String
}

package enum LegacyIngestionAdapter {
    package static func project(_ record: IngestionItemRecord) -> LegacyIngestionDisplayV1 {
        LegacyIngestionDisplayV1(
            legacyIngestionId: record.id,
            title: record.title,
            body: record.rawText
        )
    }
}

private struct InputExactCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

package enum InputContractValidationV1 {
    static func requireExactKeys(
        _ decoder: Decoder,
        _ expected: [String]
    ) throws {
        let values = try decoder.container(keyedBy: InputExactCodingKey.self)
        guard Set(values.allKeys.map(\.stringValue)) == Set(expected),
              values.allKeys.count == expected.count
        else {
            throw P1ContractValidationError.invalidKeys
        }
    }

    static func validateCampIDs(_ values: [String]) throws {
        guard values == values.sorted(), Set(values).count == values.count else {
            throw P1ContractValidationError.invalidMembership
        }
        for value in values {
            try CanonicalContractCodingV1.validateCampID(value)
        }
    }

    static func validateBody(
        inlineText: String?,
        payloadRef: String?
    ) throws {
        guard (inlineText != nil) != (payloadRef != nil) else {
            throw P1ContractValidationError.invalidMembership
        }
        if let inlineText {
            try CanonicalContractCodingV1.validateNarrativeText(inlineText)
        }
        try CanonicalContractCodingV1.validateOptionalNonempty(payloadRef)
    }

    static func validateOrdinary(
        commandType: P1CommandTypeV1,
        envelope: CommandEnvelopeV1,
        branch: ActiveWorkBranchV1
    ) throws {
        try P1CommandAuthorizationV1.validate(
            commandType: commandType,
            envelope: envelope
        )
        guard branch == .none else {
            throw P1ContractValidationError.invalidMembership
        }
    }

    static func validateRecordFields(
        id: String,
        schemaVersion: Int,
        aggregateVersion: Int,
        idempotencyKey: String,
        sourceDeviceId: String?,
        connectorId: String?,
        authorId: String?,
        capturedAt: Date,
        inlineText: String?,
        payloadRef: String?,
        contentHash: String,
        candidateCampIds: [String],
        campId: String?,
        errorCode: String?,
        errorMessage: String?,
        parentInputId: String?,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date?,
        status: InputEnvelopeStatusV1,
        retentionState: InputRetentionStateV1,
        explicitIntent: InputExplicitIntentV1,
        privacyLevel: InputPrivacyLevelV1
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        guard schemaVersion == 1 else {
            throw P1ContractValidationError.invalidSchemaVersion
        }
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateNonempty(idempotencyKey)
        if let sourceDeviceId {
            try CanonicalContractCodingV1.validateCanonicalUUID(sourceDeviceId)
        }
        try CanonicalContractCodingV1.validateOptionalNonempty(connectorId)
        try CanonicalContractCodingV1.validateOptionalNonempty(authorId)
        try CanonicalContractCodingV1.validateFinite(capturedAt)
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        try validateCampIDs(candidateCampIds)
        if let campId { try CanonicalContractCodingV1.validateCampID(campId) }
        if let errorCode { try CanonicalContractCodingV1.validateCode(errorCode) }
        if let errorMessage {
            try CanonicalContractCodingV1.validateNonempty(errorMessage)
            guard errorMessage.unicodeScalars.count <= 1_000 else {
                throw P1ContractValidationError.invalidValue
            }
        }
        if let parentInputId {
            try CanonicalContractCodingV1.validateCanonicalUUID(parentInputId)
        }
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        if let deletedAt { try CanonicalContractCodingV1.validateFinite(deletedAt) }
        if retentionState == .deletedTombstone {
            guard status == .deletedTombstone,
                  sourceDeviceId == nil,
                  connectorId == nil,
                  authorId == nil,
                  inlineText == nil,
                  payloadRef == nil,
                  candidateCampIds.isEmpty,
                  explicitIntent == .unspecified,
                  privacyLevel == .localOnly,
                  errorCode == nil,
                  errorMessage == nil,
                  parentInputId == nil,
                  deletedAt == updatedAt
            else {
                throw P1ContractValidationError.invalidMembership
            }
        } else {
            guard status != .deletedTombstone, deletedAt == nil else {
                throw P1ContractValidationError.invalidMembership
            }
            try validateBody(inlineText: inlineText, payloadRef: payloadRef)
        }
    }
}
