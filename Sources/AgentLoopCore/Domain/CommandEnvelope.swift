import Foundation

package enum DomainActorType: String, Codable, Sendable, Equatable, CaseIterable {
    case user
    case system
    case coach
    case cow
    case engine
    case device
}

package struct CommandEnvelopeV1: Sendable, Equatable, Codable {
    package let idempotencyKey: String
    package let actorType: DomainActorType
    package let actorId: String
    package let deviceId: String?
    package let correlationId: String
    package let causationId: String?
    package let occurredAt: Date

    package init(
        idempotencyKey: String,
        actorType: DomainActorType,
        actorId: String,
        deviceId: String?,
        correlationId: String,
        causationId: String?,
        occurredAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(idempotencyKey)
        try CanonicalContractCodingV1.validateNonempty(actorId)
        try CanonicalContractCodingV1.validateNonempty(correlationId)
        try CanonicalContractCodingV1.validateOptionalNonempty(causationId)
        if let deviceId {
            try CanonicalContractCodingV1.validateCanonicalUUID(deviceId)
        }
        guard actorType != .user || deviceId != nil else {
            throw P1ContractValidationError.invalidIdentifier
        }
        try CanonicalContractCodingV1.validateFinite(occurredAt)
        self.idempotencyKey = idempotencyKey
        self.actorType = actorType
        self.actorId = actorId
        self.deviceId = deviceId
        self.correlationId = correlationId
        self.causationId = causationId
        self.occurredAt = occurredAt
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case idempotencyKey
        case actorType
        case actorId
        case deviceId
        case correlationId
        case causationId
        case occurredAt
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases),
              container.contains(.deviceId),
              container.contains(.causationId)
        else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            idempotencyKey: container.decode(String.self, forKey: .idempotencyKey),
            actorType: container.decode(DomainActorType.self, forKey: .actorType),
            actorId: container.decode(String.self, forKey: .actorId),
            deviceId: container.decodeIfPresent(String.self, forKey: .deviceId),
            correlationId: container.decode(String.self, forKey: .correlationId),
            causationId: container.decodeIfPresent(String.self, forKey: .causationId),
            occurredAt: container.decode(Date.self, forKey: .occurredAt)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(idempotencyKey, forKey: .idempotencyKey)
        try container.encode(actorType, forKey: .actorType)
        try container.encode(actorId, forKey: .actorId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(correlationId, forKey: .correlationId)
        try container.encode(causationId, forKey: .causationId)
        try container.encode(occurredAt, forKey: .occurredAt)
    }
}

package enum P1CommandAuthorizationError: Error, Sendable, Equatable {
    case forbiddenActor
    case forbiddenDevice
}

package enum P1CommandAuthorizationV1 {
    package static func validate(
        commandType: P1CommandTypeV1,
        envelope: CommandEnvelopeV1
    ) throws {
        let userCommands: Set<P1CommandTypeV1> = [
            .inputCapture, .inputRequeueParsing, .inputCancelParsingAndDelete,
            .inputRequestCampAssignment, .inputRecordCampAmbiguity,
            .inputAssignCamp, .inputArchive, .inputMarkCoaching,
            .inputConvertToGoal, .inputRequestDeletion, .inputCompleteDeletion,
            .coachOpenSession, .coachAnswerQuestion,
            .coachConfirmUnderstanding, .coachRequestUnderstandingRevision,
            .goalAbandon,
        ]
        let parserCommands: Set<P1CommandTypeV1> = [
            .inputParseResult, .inputParseFailure,
        ]
        let coachCommands: Set<P1CommandTypeV1> = [
            .coachRecordQuestion, .coachProposeUnderstanding,
            .coachRequestConfirmation, .coachRecordWorkFailure, .goalFail,
        ]
        let engineCommands: Set<P1CommandTypeV1> = [
            .engineExecutionBegin, .engineDispatchStart,
            .engineCancellationRequest, .engineEventAccept,
            .engineTerminalProposalRecord, .engineTerminalCommit,
        ]

        if userCommands.contains(commandType) {
            guard envelope.actorType == .user,
                  envelope.deviceId != nil
            else {
                throw P1CommandAuthorizationError.forbiddenActor
            }
            return
        }
        if parserCommands.contains(commandType) {
            guard envelope.actorType == .system,
                  envelope.actorId == "system:input-parser:v1",
                  envelope.deviceId == nil
            else {
                throw P1CommandAuthorizationError.forbiddenActor
            }
            return
        }
        if coachCommands.contains(commandType) {
            guard envelope.actorType == .coach,
                  envelope.actorId == "system:coach:v1",
                  envelope.deviceId == nil
            else {
                throw P1CommandAuthorizationError.forbiddenActor
            }
            return
        }
        if engineCommands.contains(commandType) {
            guard envelope.actorType == .engine,
                  envelope.actorId == "engine:kernel:v1",
                  envelope.deviceId == nil,
                  envelope.causationId == nil
            else {
                throw P1CommandAuthorizationError.forbiddenActor
            }
            return
        }
        throw P1CommandAuthorizationError.forbiddenActor
    }
}

package enum ControlWorkKeyV1 {
    package static func inputParsing(commandHash: String) throws -> String {
        try CanonicalContractCodingV1.validateLowercaseHash(commandHash)
        return "inputParsing:v1:\(commandHash)"
    }

    package static func coach(commandHash: String) throws -> String {
        try CanonicalContractCodingV1.validateLowercaseHash(commandHash)
        return "coach:v1:\(commandHash)"
    }
}

package enum P1WorkerCommandEnvelopeError: Error, Sendable, Equatable {
    case invalidGraph
}

package enum ControlWorkerCommandEnvelopeFactoryV1 {
    package static func make(
        work: DurableWorkRecord,
        attempt: DurableWorkAttemptRecord,
        claim: DurableWorkClaim
    ) throws -> CommandEnvelopeV1 {
        guard work.kind == .inputParsing || work.kind == .coach,
              work.state == .running,
              work.id == attempt.workId,
              work.id == claim.workId,
              work.attempt == attempt.attempt,
              work.attempt == claim.attempt,
              work.attempt > 0,
              work.maxAttempts > 0,
              work.attempt <= work.maxAttempts,
              work.version == claim.version,
              work.leaseOwner == claim.workerId,
              attempt.workerId == claim.workerId,
              attempt.endedAt == nil,
              attempt.outcome == nil,
              attempt.errorCode == nil,
              attempt.errorMessage == nil,
              attempt.traceId == work.traceId,
              work.finishedAt == nil,
              work.leaseExpiresAt != nil
        else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(work.id)
        try CanonicalContractCodingV1.validateCanonicalUUID(attempt.id)
        try CanonicalContractCodingV1.validateCampID(work.campId)
        try CanonicalContractCodingV1.validateNonempty(work.idempotencyKey)
        try CanonicalContractCodingV1.validateNonempty(work.traceId)
        try CanonicalContractCodingV1.validateNonempty(claim.workerId)
        try CanonicalContractCodingV1.validateCanonicalUUID(work.aggregateId)
        let expectedAggregate = work.kind == .coach ? "goal" : "input"
        guard work.aggregateType == expectedAggregate else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }
        try CanonicalContractCodingV1.validateFinite(work.createdAt)
        try CanonicalContractCodingV1.validateFinite(work.updatedAt)
        try CanonicalContractCodingV1.validateFinite(attempt.startedAt)
        try CanonicalContractCodingV1.validateFinite(claim.leaseExpiresAt)
        if let leaseExpiresAt = work.leaseExpiresAt {
            try CanonicalContractCodingV1.validateFinite(leaseExpiresAt)
        }
        let inputBytes = Data(work.inputJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: inputBytes)
        try CanonicalContractCodingV1.validateLowercaseHash(work.inputHash)
        guard CanonicalJSONV1.sha256Hex(inputBytes) == work.inputHash else {
            throw P1WorkerCommandEnvelopeError.invalidGraph
        }

        return try CommandEnvelopeV1(
            idempotencyKey: "control-worker:v1:\(work.kind.rawValue):\(work.id):\(work.attempt)",
            actorType: work.kind == .coach ? .coach : .system,
            actorId: work.kind == .coach
                ? "system:coach:v1"
                : "system:input-parser:v1",
            deviceId: nil,
            correlationId: work.traceId,
            causationId: work.idempotencyKey,
            occurredAt: attempt.startedAt
        )
    }
}
