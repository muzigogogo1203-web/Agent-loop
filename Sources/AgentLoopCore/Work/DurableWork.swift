import Foundation
import GRDB

public enum DurableWorkKind: String, Codable, Sendable, CaseIterable {
    case planning
    case rumination
    case coach
    case guideChat
    case memoryPromotion
    case inputParsing
    case campDeletion
}

public enum DurableWorkState: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case retryScheduled
    case succeeded
    case failed
    case canceled
}

public enum DurableWorkAttemptOutcome: String, Codable, Sendable {
    case succeeded
    case failed
    case canceled
    case interrupted
}

public enum DurableWorkAttemptEventKind: String, Codable, Sendable {
    case claimed
    case leaseRenewed
    case succeeded
    case failed
    case canceled
    case interrupted
}

public struct DurableWorkRecord:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    public static let databaseTableName = "durable_work"

    public var id: String
    public var campId: String
    public var kind: DurableWorkKind
    public var aggregateType: String
    public var aggregateId: String
    public var idempotencyKey: String
    public var state: DurableWorkState
    public var attempt: Int
    public var maxAttempts: Int
    public var notBefore: Date?
    public var leaseOwner: String?
    public var leaseExpiresAt: Date?
    public var inputJson: String
    public var inputHash: String
    public var outputJson: String?
    public var errorCode: String?
    public var errorMessage: String?
    public var traceId: String
    public var version: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var finishedAt: Date?

    public init(
        id: String,
        campId: String,
        kind: DurableWorkKind,
        aggregateType: String,
        aggregateId: String,
        idempotencyKey: String,
        state: DurableWorkState,
        attempt: Int,
        maxAttempts: Int,
        notBefore: Date?,
        leaseOwner: String?,
        leaseExpiresAt: Date?,
        inputJson: String,
        inputHash: String,
        outputJson: String?,
        errorCode: String?,
        errorMessage: String?,
        traceId: String,
        version: Int,
        createdAt: Date,
        updatedAt: Date,
        finishedAt: Date?
    ) {
        self.id = id
        self.campId = campId
        self.kind = kind
        self.aggregateType = aggregateType
        self.aggregateId = aggregateId
        self.idempotencyKey = idempotencyKey
        self.state = state
        self.attempt = attempt
        self.maxAttempts = maxAttempts
        self.notBefore = notBefore
        self.leaseOwner = leaseOwner
        self.leaseExpiresAt = leaseExpiresAt
        self.inputJson = inputJson
        self.inputHash = inputHash
        self.outputJson = outputJson
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.traceId = traceId
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finishedAt = finishedAt
    }
}

public struct DurableWorkAttemptRecord:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    public static let databaseTableName = "durable_work_attempt"

    public var workId: String
    public var attempt: Int
    public var id: String
    public var workerId: String
    public var startedAt: Date
    public var endedAt: Date?
    public var outcome: DurableWorkAttemptOutcome?
    public var errorCode: String?
    public var errorMessage: String?
    public var traceId: String
    public var terminalWorkVersion: Int?

    public init(
        workId: String,
        attempt: Int,
        id: String,
        workerId: String,
        startedAt: Date,
        endedAt: Date?,
        outcome: DurableWorkAttemptOutcome?,
        errorCode: String?,
        errorMessage: String?,
        traceId: String,
        terminalWorkVersion: Int?
    ) {
        self.workId = workId
        self.attempt = attempt
        self.id = id
        self.workerId = workerId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.outcome = outcome
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.traceId = traceId
        self.terminalWorkVersion = terminalWorkVersion
    }
}

public struct DurableWorkAttemptEventRecord:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    public static let databaseTableName = "durable_work_attempt_event"

    public var id: String
    public var workId: String
    public var attempt: Int
    public var sequence: Int
    public var eventKind: DurableWorkAttemptEventKind
    public var workerId: String
    public var workVersion: Int
    public var resultingWorkState: DurableWorkState
    public var errorCode: String?
    public var errorMessage: String?
    public var occurredAt: Date

    public init(
        id: String,
        workId: String,
        attempt: Int,
        sequence: Int,
        eventKind: DurableWorkAttemptEventKind,
        workerId: String,
        workVersion: Int,
        resultingWorkState: DurableWorkState,
        errorCode: String?,
        errorMessage: String?,
        occurredAt: Date
    ) {
        self.id = id
        self.workId = workId
        self.attempt = attempt
        self.sequence = sequence
        self.eventKind = eventKind
        self.workerId = workerId
        self.workVersion = workVersion
        self.resultingWorkState = resultingWorkState
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.occurredAt = occurredAt
    }
}

public struct DurableWorkClaim: Sendable, Equatable {
    public let workId: String
    public let attempt: Int
    public let workerId: String
    public let version: Int
    public let leaseExpiresAt: Date

    public init(
        workId: String,
        attempt: Int,
        workerId: String,
        version: Int,
        leaseExpiresAt: Date
    ) {
        self.workId = workId
        self.attempt = attempt
        self.workerId = workerId
        self.version = version
        self.leaseExpiresAt = leaseExpiresAt
    }
}

public enum DurableWorkEnqueueDisposition: Sendable, Equatable {
    case inserted
    case replayed
}

public struct DurableWorkEnqueueResult: Sendable, Equatable {
    public let work: DurableWorkRecord
    public let disposition: DurableWorkEnqueueDisposition

    public init(
        work: DurableWorkRecord,
        disposition: DurableWorkEnqueueDisposition
    ) {
        self.work = work
        self.disposition = disposition
    }
}

package struct CandidatePlanningStartCommand: Sendable, Equatable {
    package let draft: CodingRanchMissionDraft
    package let goal: String
    package let companionId: String
    package let workspacePath: String?
    package let budgetTokens: Int
    package let autonomy: MissionAutonomy
    package let planningInput: PlanningWorkInput
    package let idempotencyKey: String
    package let traceId: String

    package init(
        draft: CodingRanchMissionDraft,
        goal: String,
        companionId: String,
        workspacePath: String?,
        budgetTokens: Int,
        autonomy: MissionAutonomy,
        planningInput: PlanningWorkInput,
        idempotencyKey: String,
        traceId: String
    ) {
        self.draft = draft
        self.goal = goal
        self.companionId = companionId
        self.workspacePath = workspacePath
        self.budgetTokens = budgetTokens
        self.autonomy = autonomy
        self.planningInput = planningInput
        self.idempotencyKey = idempotencyKey
        self.traceId = traceId
    }
}

package struct CandidatePlanningStartResult: Sendable, Equatable {
    package let missionId: String
    package let workId: String
    package let disposition: DurableWorkEnqueueDisposition

    package init(
        missionId: String,
        workId: String,
        disposition: DurableWorkEnqueueDisposition
    ) {
        self.missionId = missionId
        self.workId = workId
        self.disposition = disposition
    }
}

package enum ScheduleFirePreparation: Sendable, Equatable {
    case selected(runtimeProfileId: String, plannerModel: String)
    case forcedFailure
    case unavailable
}

package struct SchedulePlanningStartCommand: Sendable, Equatable {
    package let scheduleId: String
    package let context: ScheduleSlotContextV1
    package let preparation: ScheduleFirePreparation
    package let traceId: String

    package init(
        scheduleId: String,
        context: ScheduleSlotContextV1,
        preparation: ScheduleFirePreparation,
        traceId: String
    ) {
        self.scheduleId = scheduleId
        self.context = context
        self.preparation = preparation
        self.traceId = traceId
    }
}

private struct SchedulePayloadCodingKey: CodingKey, Hashable, Sendable {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }

    static let contractVersion = Self(stringValue: "contractVersion")!
    static let originalFireId = Self(stringValue: "originalFireId")!
    static let scheduleId = Self(stringValue: "scheduleId")!
    static let originalTemplateId =
        Self(stringValue: "originalTemplateId")!
    static let effectiveTemplateId =
        Self(stringValue: "effectiveTemplateId")!
    static let templateId = Self(stringValue: "templateId")!
    static let slotKey = Self(stringValue: "slotKey")!
    static let scheduledAt = Self(stringValue: "scheduledAt")!
    static let scheduledAtInstantBits =
        Self(stringValue: "scheduledAtInstantBits")!
    static let runtimeState = Self(stringValue: "runtimeState")!
    static let runtimeProfileId = Self(stringValue: "runtimeProfileId")!
    static let plannerModel = Self(stringValue: "plannerModel")!
    static let preflightFailureCode =
        Self(stringValue: "preflightFailureCode")!
    static let fireId = Self(stringValue: "fireId")!
    static let replayOfFireId = Self(stringValue: "replayOfFireId")!
    static let traceId = Self(stringValue: "traceId")!
    static let errorCode = Self(stringValue: "errorCode")!
    static let errorMessage = Self(stringValue: "errorMessage")!
}

private func schedulePayloadIsNonBlank(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func schedulePayloadNormalizedSeconds(_ seconds: Double) -> Double {
    seconds == 0 ? 0 : seconds
}

private func schedulePayloadInstantBits(_ seconds: Double) -> String {
    let digits = String(
        schedulePayloadNormalizedSeconds(seconds).bitPattern,
        radix: 16,
        uppercase: false
    )
    return String(repeating: "0", count: 16 - digits.count) + digits
}

package struct ScheduleReplayPayloadV1:
    Codable, Sendable, Equatable
{
    package let contractVersion: Int
    package let originalFireId: String
    package let scheduleId: String
    package let originalTemplateId: String
    package let effectiveTemplateId: String
    package let slotKey: String
    package let scheduledAtInstantBits: String
    package let runtimeState: String
    package let runtimeProfileId: String?
    package let plannerModel: String?
    package let preflightFailureCode: String?

    private typealias CodingKeys = SchedulePayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .contractVersion,
        .originalFireId,
        .scheduleId,
        .originalTemplateId,
        .effectiveTemplateId,
        .slotKey,
        .scheduledAtInstantBits,
        .runtimeState,
        .runtimeProfileId,
        .plannerModel,
        .preflightFailureCode,
    ]

    package init(
        originalFire: ScheduleFireRecord,
        effectiveTemplateId: String,
        preparation: ScheduleFirePreparation
    ) throws {
        let runtimeState: String
        let runtimeProfileId: String?
        let plannerModel: String?
        let preflightFailureCode: String?
        switch preparation {
        case let .selected(selectedProfileId, selectedPlannerModel):
            runtimeState = "selected"
            runtimeProfileId = selectedProfileId
            plannerModel = selectedPlannerModel
            preflightFailureCode = nil
        case .unavailable:
            runtimeState = "unavailable"
            runtimeProfileId = nil
            plannerModel = nil
            preflightFailureCode = "schedule_runtime_unavailable"
        case .forcedFailure:
            throw DurableWorkReplayConflictError()
        }

        try self.init(
            contractVersion: 1,
            originalFireId: originalFire.id,
            scheduleId: originalFire.scheduleId,
            originalTemplateId: originalFire.templateId,
            effectiveTemplateId: effectiveTemplateId,
            slotKey: originalFire.slotKey,
            scheduledAtInstantBits: schedulePayloadInstantBits(
                originalFire.scheduledAt.timeIntervalSince1970
            ),
            runtimeState: runtimeState,
            runtimeProfileId: runtimeProfileId,
            plannerModel: plannerModel,
            preflightFailureCode: preflightFailureCode
        )
    }

    package init(
        contractVersion: Int = 1,
        originalFireId: String,
        scheduleId: String,
        originalTemplateId: String,
        effectiveTemplateId: String,
        slotKey: String,
        scheduledAtInstantBits: String,
        runtimeState: String,
        runtimeProfileId: String?,
        plannerModel: String?,
        preflightFailureCode: String?
    ) throws {
        guard contractVersion == 1,
              schedulePayloadIsNonBlank(originalFireId),
              schedulePayloadIsNonBlank(scheduleId),
              schedulePayloadIsNonBlank(originalTemplateId),
              schedulePayloadIsNonBlank(effectiveTemplateId),
              schedulePayloadIsNonBlank(slotKey),
              Self.isLowercaseInstantBits(scheduledAtInstantBits)
        else {
            throw DurableWorkReplayConflictError()
        }

        switch runtimeState {
        case "selected":
            guard let runtimeProfileId,
                  let plannerModel,
                  schedulePayloadIsNonBlank(runtimeProfileId),
                  schedulePayloadIsNonBlank(plannerModel),
                  preflightFailureCode == nil
            else {
                throw DurableWorkReplayConflictError()
            }
        case "unavailable":
            guard runtimeProfileId == nil,
                  plannerModel == nil,
                  preflightFailureCode ==
                    "schedule_runtime_unavailable"
            else {
                throw DurableWorkReplayConflictError()
            }
        default:
            throw DurableWorkReplayConflictError()
        }

        self.contractVersion = contractVersion
        self.originalFireId = originalFireId
        self.scheduleId = scheduleId
        self.originalTemplateId = originalTemplateId
        self.effectiveTemplateId = effectiveTemplateId
        self.slotKey = slotKey
        self.scheduledAtInstantBits = scheduledAtInstantBits
        self.runtimeState = runtimeState
        self.runtimeProfileId = runtimeProfileId
        self.plannerModel = plannerModel
        self.preflightFailureCode = preflightFailureCode
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw DurableWorkReplayConflictError()
        }
        try self.init(
            contractVersion: container.decode(
                Int.self,
                forKey: .contractVersion
            ),
            originalFireId: container.decode(
                String.self,
                forKey: .originalFireId
            ),
            scheduleId: container.decode(String.self, forKey: .scheduleId),
            originalTemplateId: container.decode(
                String.self,
                forKey: .originalTemplateId
            ),
            effectiveTemplateId: container.decode(
                String.self,
                forKey: .effectiveTemplateId
            ),
            slotKey: container.decode(String.self, forKey: .slotKey),
            scheduledAtInstantBits: container.decode(
                String.self,
                forKey: .scheduledAtInstantBits
            ),
            runtimeState: container.decode(
                String.self,
                forKey: .runtimeState
            ),
            runtimeProfileId: container.decode(
                String?.self,
                forKey: .runtimeProfileId
            ),
            plannerModel: container.decode(
                String?.self,
                forKey: .plannerModel
            ),
            preflightFailureCode: container.decode(
                String?.self,
                forKey: .preflightFailureCode
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractVersion, forKey: .contractVersion)
        try container.encode(originalFireId, forKey: .originalFireId)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(
            originalTemplateId,
            forKey: .originalTemplateId
        )
        try container.encode(
            effectiveTemplateId,
            forKey: .effectiveTemplateId
        )
        try container.encode(slotKey, forKey: .slotKey)
        try container.encode(
            scheduledAtInstantBits,
            forKey: .scheduledAtInstantBits
        )
        try container.encode(runtimeState, forKey: .runtimeState)
        try container.encode(runtimeProfileId, forKey: .runtimeProfileId)
        try container.encode(plannerModel, forKey: .plannerModel)
        try container.encode(
            preflightFailureCode,
            forKey: .preflightFailureCode
        )
    }

    package func canonicalData() throws -> Data {
        try CanonicalJSONV1.encode(self)
    }

    package func canonicalHash() throws -> String {
        CanonicalJSONV1.sha256Hex(try canonicalData())
    }

    private static func isLowercaseInstantBits(_ value: String) -> Bool {
        value.utf8.count == 16
            && value.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
    }
}

package struct ScheduleReplayStartCommand: Sendable, Equatable {
    package let originalFireId: String
    package let replayIdempotencyKey: String
    package let payload: ScheduleReplayPayloadV1
    package let replayPayloadHash: String
    package let traceId: String

    package init(
        originalFireId: String,
        replayIdempotencyKey: String,
        payload: ScheduleReplayPayloadV1,
        replayPayloadHash: String,
        traceId: String
    ) {
        self.originalFireId = originalFireId
        self.replayIdempotencyKey = replayIdempotencyKey
        self.payload = payload
        self.replayPayloadHash = replayPayloadHash
        self.traceId = traceId
    }
}

package struct ScheduleFiredPayloadV1: Codable, Sendable, Equatable {
    package let contractVersion: Int
    package let fireId: String
    package let scheduleId: String
    package let templateId: String
    package let slotKey: String
    package let scheduledAt: Double
    package let scheduledAtInstantBits: String
    package let replayOfFireId: String?
    package let traceId: String

    private typealias CodingKeys = SchedulePayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .contractVersion,
        .fireId,
        .scheduleId,
        .templateId,
        .slotKey,
        .scheduledAt,
        .scheduledAtInstantBits,
        .replayOfFireId,
        .traceId,
    ]

    package init(
        fireId: String,
        scheduleId: String,
        templateId: String,
        slotKey: String,
        scheduledAt: Double,
        replayOfFireId: String?,
        traceId: String
    ) {
        let normalizedScheduledAt =
            schedulePayloadNormalizedSeconds(scheduledAt)
        self.contractVersion = 1
        self.fireId = fireId
        self.scheduleId = scheduleId
        self.templateId = templateId
        self.slotKey = slotKey
        self.scheduledAt = normalizedScheduledAt
        self.scheduledAtInstantBits = schedulePayloadInstantBits(
            normalizedScheduledAt
        )
        self.replayOfFireId = replayOfFireId
        self.traceId = traceId
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ScheduleFiredPayloadV1 shape"
                )
            )
        }
        contractVersion = try container.decode(
            Int.self,
            forKey: .contractVersion
        )
        fireId = try container.decode(String.self, forKey: .fireId)
        scheduleId = try container.decode(String.self, forKey: .scheduleId)
        templateId = try container.decode(String.self, forKey: .templateId)
        slotKey = try container.decode(String.self, forKey: .slotKey)
        scheduledAt = try container.decode(Double.self, forKey: .scheduledAt)
        scheduledAtInstantBits = try container.decode(
            String.self,
            forKey: .scheduledAtInstantBits
        )
        replayOfFireId = try container.decode(
            String?.self,
            forKey: .replayOfFireId
        )
        traceId = try container.decode(String.self, forKey: .traceId)
        guard isValid else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ScheduleFiredPayloadV1 value"
                )
            )
        }
    }

    package func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw EncodingError.invalidValue(
                self,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "Invalid ScheduleFiredPayloadV1 value"
                )
            )
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractVersion, forKey: .contractVersion)
        try container.encode(fireId, forKey: .fireId)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(slotKey, forKey: .slotKey)
        try container.encode(scheduledAt, forKey: .scheduledAt)
        try container.encode(
            scheduledAtInstantBits,
            forKey: .scheduledAtInstantBits
        )
        try container.encode(replayOfFireId, forKey: .replayOfFireId)
        try container.encode(traceId, forKey: .traceId)
    }

    private var isValid: Bool {
        contractVersion == 1
            && schedulePayloadIsNonBlank(fireId)
            && schedulePayloadIsNonBlank(scheduleId)
            && schedulePayloadIsNonBlank(templateId)
            && schedulePayloadIsNonBlank(slotKey)
            && scheduledAt.isFinite
            && scheduledAt.bitPattern
                == schedulePayloadNormalizedSeconds(scheduledAt).bitPattern
            && scheduledAtInstantBits
                == schedulePayloadInstantBits(scheduledAt)
            && replayOfFireId.map(schedulePayloadIsNonBlank) != false
            && schedulePayloadIsNonBlank(traceId)
    }
}

package struct ScheduleMissedPayloadV1: Codable, Sendable, Equatable {
    package let contractVersion: Int
    package let fireId: String
    package let scheduleId: String
    package let templateId: String
    package let slotKey: String
    package let scheduledAt: Double
    package let scheduledAtInstantBits: String
    package let replayOfFireId: String?
    package let traceId: String
    package let errorCode: String
    package let errorMessage: String

    private typealias CodingKeys = SchedulePayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .contractVersion,
        .fireId,
        .scheduleId,
        .templateId,
        .slotKey,
        .scheduledAt,
        .scheduledAtInstantBits,
        .replayOfFireId,
        .traceId,
        .errorCode,
        .errorMessage,
    ]

    package init(
        fireId: String,
        scheduleId: String,
        templateId: String,
        slotKey: String,
        scheduledAt: Double,
        replayOfFireId: String?,
        traceId: String,
        errorCode: String,
        errorMessage: String
    ) {
        let normalizedScheduledAt =
            schedulePayloadNormalizedSeconds(scheduledAt)
        self.contractVersion = 1
        self.fireId = fireId
        self.scheduleId = scheduleId
        self.templateId = templateId
        self.slotKey = slotKey
        self.scheduledAt = normalizedScheduledAt
        self.scheduledAtInstantBits = schedulePayloadInstantBits(
            normalizedScheduledAt
        )
        self.replayOfFireId = replayOfFireId
        self.traceId = traceId
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ScheduleMissedPayloadV1 shape"
                )
            )
        }
        contractVersion = try container.decode(
            Int.self,
            forKey: .contractVersion
        )
        fireId = try container.decode(String.self, forKey: .fireId)
        scheduleId = try container.decode(String.self, forKey: .scheduleId)
        templateId = try container.decode(String.self, forKey: .templateId)
        slotKey = try container.decode(String.self, forKey: .slotKey)
        scheduledAt = try container.decode(Double.self, forKey: .scheduledAt)
        scheduledAtInstantBits = try container.decode(
            String.self,
            forKey: .scheduledAtInstantBits
        )
        replayOfFireId = try container.decode(
            String?.self,
            forKey: .replayOfFireId
        )
        traceId = try container.decode(String.self, forKey: .traceId)
        errorCode = try container.decode(String.self, forKey: .errorCode)
        errorMessage = try container.decode(
            String.self,
            forKey: .errorMessage
        )
        guard isValid else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ScheduleMissedPayloadV1 value"
                )
            )
        }
    }

    package func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw EncodingError.invalidValue(
                self,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "Invalid ScheduleMissedPayloadV1 value"
                )
            )
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractVersion, forKey: .contractVersion)
        try container.encode(fireId, forKey: .fireId)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(slotKey, forKey: .slotKey)
        try container.encode(scheduledAt, forKey: .scheduledAt)
        try container.encode(
            scheduledAtInstantBits,
            forKey: .scheduledAtInstantBits
        )
        try container.encode(replayOfFireId, forKey: .replayOfFireId)
        try container.encode(traceId, forKey: .traceId)
        try container.encode(errorCode, forKey: .errorCode)
        try container.encode(errorMessage, forKey: .errorMessage)
    }

    private var isValid: Bool {
        contractVersion == 1
            && schedulePayloadIsNonBlank(fireId)
            && schedulePayloadIsNonBlank(scheduleId)
            && schedulePayloadIsNonBlank(templateId)
            && schedulePayloadIsNonBlank(slotKey)
            && scheduledAt.isFinite
            && scheduledAt.bitPattern
                == schedulePayloadNormalizedSeconds(scheduledAt).bitPattern
            && scheduledAtInstantBits
                == schedulePayloadInstantBits(scheduledAt)
            && replayOfFireId.map(schedulePayloadIsNonBlank) != false
            && schedulePayloadIsNonBlank(traceId)
            && DurableWorkFailure.isValidErrorCode(errorCode)
            && !errorMessage.isEmpty
            && errorMessage.unicodeScalars.count <= 1_000
            && !DurableWorkFailure.containsControlScalar(errorMessage)
    }
}

public enum DurableWorkFailureResolution: Sendable, Equatable {
    case retryScheduled(work: DurableWorkRecord, notBefore: Date)
    case failed(work: DurableWorkRecord)
}

public enum DurableWorkCancelResult: Sendable, Equatable {
    case canceled(work: DurableWorkRecord)
    case alreadyCanceled(work: DurableWorkRecord)
}

public enum DurableWorkCancelActiveResult: Sendable, Equatable {
    case canceled(work: DurableWorkRecord)
    case noActiveWork
}

public typealias DurableWorkBusinessMutation =
    (_ db: Database, _ resultingWork: DurableWorkRecord) throws -> Void

public enum DurableWorkFailureDisposition: String, Codable, Sendable, Equatable {
    case transient
    case deterministic
}

public enum InvalidDurableWorkFailureError: Error, Sendable, Equatable {
    case invalidCode
    case emptyMessage
    case messageTooLong
    case messageContainsControlScalar
    case invalidUsageJson
}

public struct DurableWorkFailure: Sendable, Equatable, Codable {
    public let code: String
    public let message: String?
    public let disposition: DurableWorkFailureDisposition
    public let usageJson: String?

    private struct CodingKeyValue: CodingKey, Hashable, Sendable {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }

        static let code = CodingKeyValue(stringValue: "code")!
        static let message = CodingKeyValue(stringValue: "message")!
        static let disposition = CodingKeyValue(stringValue: "disposition")!
        static let usageJson = CodingKeyValue(stringValue: "usageJson")!

        static let expected: Set<CodingKeyValue> = [
            .code, .message, .disposition, .usageJson,
        ]
    }

    public init(
        code: String,
        message: String?,
        disposition: DurableWorkFailureDisposition,
        usageJson: String?
    ) throws {
        guard Self.isValidErrorCode(code) else {
            throw InvalidDurableWorkFailureError.invalidCode
        }
        if let message {
            guard !message.isEmpty else {
                throw InvalidDurableWorkFailureError.emptyMessage
            }
            guard message.unicodeScalars.count <= 1_000 else {
                throw InvalidDurableWorkFailureError.messageTooLong
            }
            guard !Self.containsControlScalar(message) else {
                throw InvalidDurableWorkFailureError.messageContainsControlScalar
            }
        }
        if let usageJson {
            do {
                let raw = Data(usageJson.utf8)
                let canonical = try CanonicalJSONV1.canonicalizeWithRootKind(
                    rawUTF8: raw
                )
                guard canonical.rootKind == .object,
                      canonical.data == raw
                else {
                    throw InvalidDurableWorkFailureError.invalidUsageJson
                }
                try CanonicalJSONV1.validateDurableWorkUsageObject(
                    rawUTF8: raw
                )
            } catch {
                throw InvalidDurableWorkFailureError.invalidUsageJson
            }
        }
        self.code = code
        self.message = message
        self.disposition = disposition
        self.usageJson = usageJson
    }

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeyValue.self)
            guard Set(container.allKeys) == CodingKeyValue.expected else {
                throw InvalidDurableWorkFailureError.invalidUsageJson
            }
            let code = try container.decode(String.self, forKey: .code)
            let message = try Self.decodeExplicitOptional(
                String.self,
                from: container,
                forKey: .message
            )
            let disposition = try container.decode(
                DurableWorkFailureDisposition.self,
                forKey: .disposition
            )
            let usageJson = try Self.decodeExplicitOptional(
                String.self,
                from: container,
                forKey: .usageJson
            )
            try self.init(
                code: code,
                message: message,
                disposition: disposition,
                usageJson: usageJson
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid DurableWorkFailure payload"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeyValue.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encode(disposition, forKey: .disposition)
        try container.encode(usageJson, forKey: .usageJson)
    }

    private static func decodeExplicitOptional<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeyValue>,
        forKey key: CodingKeyValue
    ) throws -> T? {
        guard container.contains(key) else {
            throw InvalidDurableWorkFailureError.invalidUsageJson
        }
        if try container.decodeNil(forKey: key) {
            return nil
        }
        return try container.decode(type, forKey: key)
    }

    static func isValidErrorCode(_ code: String) -> Bool {
        guard (1...64).contains(code.utf8.count),
              let first = code.utf8.first,
              (97...122).contains(first)
        else {
            return false
        }
        return code.utf8.allSatisfy {
            (97...122).contains($0)
                || (48...57).contains($0)
                || $0 == 95
        }
    }

    static func containsControlScalar(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            $0.value <= 0x1F || (0x7F...0x9F).contains($0.value)
        }
    }
}

package enum InvalidPlanningPayloadError: Error, Sendable, Equatable {
    case invalidContractVersion
    case emptyPlannerModel
    case emptyRuntimeProfileId
    case emptyGoal
    case emptyCompanionId(index: Int)
    case emptyCampId
    case invalidBudgetTokens
    case invalidLegacyTerminalCode
    case negativeUsage
    case invalidOverflowFields
    case nonCanonicalOverflowFields
    case invalidOverflowShape
}

private struct PlanningPayloadCodingKey: CodingKey, Hashable, Sendable {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }

    static let plannerModel = Self(stringValue: "plannerModel")!
    static let runtimeProfileId = Self(stringValue: "runtimeProfileId")!
    static let promptContractVersion =
        Self(stringValue: "promptContractVersion")!
    static let contractVersion = Self(stringValue: "contractVersion")!
    static let goal = Self(stringValue: "goal")!
    static let companionIds = Self(stringValue: "companionIds")!
    static let workspacePath = Self(stringValue: "workspacePath")!
    static let budgetTokens = Self(stringValue: "budgetTokens")!
    static let campId = Self(stringValue: "campId")!
    static let autonomy = Self(stringValue: "autonomy")!
    static let planningInput = Self(stringValue: "planningInput")!
    static let terminalCode = Self(stringValue: "terminalCode")!
    static let cacheReadTokens = Self(stringValue: "cacheReadTokens")!
    static let inputTokens = Self(stringValue: "inputTokens")!
    static let outputTokens = Self(stringValue: "outputTokens")!
    static let reason = Self(stringValue: "reason")!
    static let priorAccumulatedUsage =
        Self(stringValue: "priorAccumulatedUsage")!
    static let incomingUsage = Self(stringValue: "incomingUsage")!
    static let overflowFields = Self(stringValue: "overflowFields")!
    static let existingSpentTokens =
        Self(stringValue: "existingSpentTokens")!
    static let attemptUsage = Self(stringValue: "attemptUsage")!
}

public struct PlanningWorkInput: Codable, Sendable, Equatable {
    public let plannerModel: String
    public let runtimeProfileId: String
    public let promptContractVersion: Int

    private typealias CodingKeys = PlanningPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .plannerModel,
        .runtimeProfileId,
        .promptContractVersion,
    ]

    public init(
        plannerModel: String,
        runtimeProfileId: String,
        promptContractVersion: Int = 1
    ) throws {
        guard promptContractVersion == 1 else {
            throw InvalidPlanningPayloadError.invalidContractVersion
        }
        guard Self.isNonBlank(plannerModel) else {
            throw InvalidPlanningPayloadError.emptyPlannerModel
        }
        guard Self.isNonBlank(runtimeProfileId) else {
            throw InvalidPlanningPayloadError.emptyRuntimeProfileId
        }
        self.plannerModel = plannerModel
        self.runtimeProfileId = runtimeProfileId
        self.promptContractVersion = promptContractVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidPlanningPayloadError.invalidOverflowShape
        }
        try self.init(
            plannerModel: container.decode(
                String.self,
                forKey: .plannerModel
            ),
            runtimeProfileId: container.decode(
                String.self,
                forKey: .runtimeProfileId
            ),
            promptContractVersion: container.decode(
                Int.self,
                forKey: .promptContractVersion
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(plannerModel, forKey: .plannerModel)
        try container.encode(runtimeProfileId, forKey: .runtimeProfileId)
        try container.encode(
            promptContractVersion,
            forKey: .promptContractVersion
        )
    }

    fileprivate static func isNonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

package struct MissionPlanningStartIdentityV1:
    Codable, Sendable, Equatable
{
    package let contractVersion: Int
    package let goal: String
    package let companionIds: [String]
    package let workspacePath: String?
    package let budgetTokens: Int
    package let campId: String
    package let autonomy: MissionAutonomy
    package let planningInput: PlanningWorkInput

    private typealias CodingKeys = PlanningPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .contractVersion,
        .goal,
        .companionIds,
        .workspacePath,
        .budgetTokens,
        .campId,
        .autonomy,
        .planningInput,
    ]

    package init(
        contractVersion: Int = 1,
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int,
        campId: String,
        autonomy: MissionAutonomy,
        planningInput: PlanningWorkInput
    ) throws {
        guard contractVersion == 1 else {
            throw InvalidPlanningPayloadError.invalidContractVersion
        }
        guard PlanningWorkInput.isNonBlank(goal) else {
            throw InvalidPlanningPayloadError.emptyGoal
        }
        for (index, companionId) in companionIds.enumerated() {
            guard PlanningWorkInput.isNonBlank(companionId) else {
                throw InvalidPlanningPayloadError.emptyCompanionId(
                    index: index
                )
            }
        }
        guard PlanningWorkInput.isNonBlank(campId) else {
            throw InvalidPlanningPayloadError.emptyCampId
        }
        self.contractVersion = contractVersion
        self.goal = goal
        self.companionIds = companionIds
        self.workspacePath = workspacePath
        self.budgetTokens = max(1, budgetTokens)
        self.campId = campId
        self.autonomy = autonomy
        self.planningInput = planningInput
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidPlanningPayloadError.invalidOverflowShape
        }
        guard container.contains(.workspacePath) else {
            throw InvalidPlanningPayloadError.invalidOverflowShape
        }
        let budgetTokens = try container.decode(
            Int.self,
            forKey: .budgetTokens
        )
        guard budgetTokens >= 1 else {
            throw InvalidPlanningPayloadError.invalidBudgetTokens
        }
        try self.init(
            contractVersion: container.decode(
                Int.self,
                forKey: .contractVersion
            ),
            goal: container.decode(String.self, forKey: .goal),
            companionIds: container.decode(
                [String].self,
                forKey: .companionIds
            ),
            workspacePath: container.decodeIfPresent(
                String.self,
                forKey: .workspacePath
            ),
            budgetTokens: budgetTokens,
            campId: container.decode(String.self, forKey: .campId),
            autonomy: container.decode(
                MissionAutonomy.self,
                forKey: .autonomy
            ),
            planningInput: container.decode(
                PlanningWorkInput.self,
                forKey: .planningInput
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractVersion, forKey: .contractVersion)
        try container.encode(goal, forKey: .goal)
        try container.encode(companionIds, forKey: .companionIds)
        try container.encode(workspacePath, forKey: .workspacePath)
        try container.encode(budgetTokens, forKey: .budgetTokens)
        try container.encode(campId, forKey: .campId)
        try container.encode(autonomy, forKey: .autonomy)
        try container.encode(planningInput, forKey: .planningInput)
    }
}

package struct LegacyPlanningTerminalInputV1:
    Codable, Sendable, Equatable
{
    package let contractVersion: Int
    package let terminalCode: String

    private typealias CodingKeys = PlanningPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .contractVersion,
        .terminalCode,
    ]

    private static let allowedTerminalCodes: Set<String> = [
        "emergency_halt_during_planning",
        "legacy_planning_profile_unresolved",
        "legacy_planning_model_unavailable",
        "legacy_planning_profile_cli_unsupported",
    ]

    package init(
        contractVersion: Int = 1,
        terminalCode: String
    ) throws {
        guard contractVersion == 1 else {
            throw InvalidPlanningPayloadError.invalidContractVersion
        }
        guard Self.allowedTerminalCodes.contains(terminalCode) else {
            throw InvalidPlanningPayloadError.invalidLegacyTerminalCode
        }
        self.contractVersion = contractVersion
        self.terminalCode = terminalCode
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidPlanningPayloadError.invalidOverflowShape
        }
        try self.init(
            contractVersion: container.decode(
                Int.self,
                forKey: .contractVersion
            ),
            terminalCode: container.decode(
                String.self,
                forKey: .terminalCode
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractVersion, forKey: .contractVersion)
        try container.encode(terminalCode, forKey: .terminalCode)
    }
}

package struct PlanningUsageCountersV1:
    Codable, Sendable, Equatable
{
    package let cacheReadTokens: Int64
    package let inputTokens: Int64
    package let outputTokens: Int64

    private typealias CodingKeys = PlanningPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .cacheReadTokens,
        .inputTokens,
        .outputTokens,
    ]

    package init(
        cacheReadTokens: Int64,
        inputTokens: Int64,
        outputTokens: Int64
    ) throws {
        guard cacheReadTokens >= 0,
              inputTokens >= 0,
              outputTokens >= 0
        else {
            throw InvalidPlanningPayloadError.negativeUsage
        }
        self.cacheReadTokens = cacheReadTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    package init(usage: Usage) throws {
        guard usage.cacheReadTokens >= 0,
              usage.inputTokens >= 0,
              usage.outputTokens >= 0,
              let cacheReadTokens = Int64(exactly: usage.cacheReadTokens),
              let inputTokens = Int64(exactly: usage.inputTokens),
              let outputTokens = Int64(exactly: usage.outputTokens)
        else {
            throw InvalidPlanningPayloadError.negativeUsage
        }
        try self.init(
            cacheReadTokens: cacheReadTokens,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidPlanningPayloadError.invalidOverflowShape
        }
        try self.init(
            cacheReadTokens: container.decode(
                Int64.self,
                forKey: .cacheReadTokens
            ),
            inputTokens: container.decode(
                Int64.self,
                forKey: .inputTokens
            ),
            outputTokens: container.decode(
                Int64.self,
                forKey: .outputTokens
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cacheReadTokens, forKey: .cacheReadTokens)
        try container.encode(inputTokens, forKey: .inputTokens)
        try container.encode(outputTokens, forKey: .outputTokens)
    }

    package var usage: Usage {
        Usage(
            inputTokens: Int(inputTokens),
            outputTokens: Int(outputTokens),
            cacheReadTokens: Int(cacheReadTokens)
        )
    }
}

package struct PlanningAttemptFailure: Error, Sendable, Equatable {
    package let failure: DurableWorkFailure
    package let usage: Usage?

    package init(
        code: String,
        safeMessage: String?,
        disposition: DurableWorkFailureDisposition,
        usage: Usage?
    ) throws {
        let usageJson: String?
        if let usage {
            let counters = try PlanningUsageCountersV1(usage: usage)
            usageJson = String(
                decoding: try CanonicalJSONV1.encode(counters),
                as: UTF8.self
            )
        } else {
            usageJson = nil
        }
        self.failure = try DurableWorkFailure(
            code: code,
            message: safeMessage,
            disposition: disposition,
            usageJson: usageJson
        )
        self.usage = usage
    }
}

package enum InvalidRuminationPayloadError:
    Error, Sendable, Equatable
{
    case invalidShape
    case emptyModel
    case emptyRuntimeProfileId
    case invalidPipelineVersion
    case invalidContractVersion
    case invalidLegacyTerminalCode
    case negativeUsage
    case emptyIngestionId
    case emptyWorkId
    case negativeAttempt
    case invalidWorkVersion
    case invalidFailure
}

private struct RuminationPayloadCodingKey:
    CodingKey, Hashable, Sendable
{
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }

    static let model = Self(stringValue: "model")!
    static let runtimeProfileId =
        Self(stringValue: "runtimeProfileId")!
    static let pipelineVersion =
        Self(stringValue: "pipelineVersion")!
    static let contractVersion =
        Self(stringValue: "contractVersion")!
    static let terminalCode = Self(stringValue: "terminalCode")!
    static let cacheReadTokens =
        Self(stringValue: "cacheReadTokens")!
    static let inputTokens = Self(stringValue: "inputTokens")!
    static let outputTokens = Self(stringValue: "outputTokens")!
}

public struct RuminationWorkInput: Codable, Sendable, Equatable {
    public static let pipelineVersion = "coding-ranch-v1"

    public let model: String
    public let runtimeProfileId: String
    public let pipelineVersion: String

    private typealias CodingKeys = RuminationPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .model,
        .runtimeProfileId,
        .pipelineVersion,
    ]

    public init(
        model: String,
        runtimeProfileId: String,
        pipelineVersion: String = Self.pipelineVersion
    ) throws {
        guard Self.isNonBlank(model) else {
            throw InvalidRuminationPayloadError.emptyModel
        }
        guard Self.isNonBlank(runtimeProfileId) else {
            throw InvalidRuminationPayloadError.emptyRuntimeProfileId
        }
        guard pipelineVersion == Self.pipelineVersion else {
            throw InvalidRuminationPayloadError.invalidPipelineVersion
        }
        self.model = model
        self.runtimeProfileId = runtimeProfileId
        self.pipelineVersion = pipelineVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidRuminationPayloadError.invalidShape
        }
        try self.init(
            model: container.decode(String.self, forKey: .model),
            runtimeProfileId: container.decode(
                String.self,
                forKey: .runtimeProfileId
            ),
            pipelineVersion: container.decode(
                String.self,
                forKey: .pipelineVersion
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(
            runtimeProfileId,
            forKey: .runtimeProfileId
        )
        try container.encode(
            pipelineVersion,
            forKey: .pipelineVersion
        )
    }

    fileprivate static func isNonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }
}

package struct LegacyRuminationTerminalInputV1:
    Codable, Sendable, Equatable
{
    package let contractVersion: Int
    package let terminalCode: String

    private typealias CodingKeys = RuminationPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .contractVersion,
        .terminalCode,
    ]
    private static let allowedTerminalCodes: Set<String> = [
        "emergency_halt_during_rumination",
        "legacy_rumination_profile_unresolved",
        "legacy_rumination_model_unavailable",
        "legacy_rumination_profile_cli_unsupported",
    ]

    package init(
        contractVersion: Int = 1,
        terminalCode: String
    ) throws {
        guard contractVersion == 1 else {
            throw InvalidRuminationPayloadError.invalidContractVersion
        }
        guard Self.allowedTerminalCodes.contains(terminalCode) else {
            throw InvalidRuminationPayloadError
                .invalidLegacyTerminalCode
        }
        self.contractVersion = contractVersion
        self.terminalCode = terminalCode
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidRuminationPayloadError.invalidShape
        }
        try self.init(
            contractVersion: container.decode(
                Int.self,
                forKey: .contractVersion
            ),
            terminalCode: container.decode(
                String.self,
                forKey: .terminalCode
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            contractVersion,
            forKey: .contractVersion
        )
        try container.encode(terminalCode, forKey: .terminalCode)
    }
}

package struct RuminationUsageCountersV1:
    Codable, Sendable, Equatable
{
    package let cacheReadTokens: Int64
    package let inputTokens: Int64
    package let outputTokens: Int64

    private typealias CodingKeys = RuminationPayloadCodingKey
    private static let expectedKeys: Set<CodingKeys> = [
        .cacheReadTokens,
        .inputTokens,
        .outputTokens,
    ]

    package init(
        cacheReadTokens: Int64,
        inputTokens: Int64,
        outputTokens: Int64
    ) throws {
        guard cacheReadTokens >= 0,
              inputTokens >= 0,
              outputTokens >= 0
        else {
            throw InvalidRuminationPayloadError.negativeUsage
        }
        self.cacheReadTokens = cacheReadTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    package init(usage: Usage) throws {
        guard usage.cacheReadTokens >= 0,
              usage.inputTokens >= 0,
              usage.outputTokens >= 0,
              let cacheReadTokens = Int64(
                  exactly: usage.cacheReadTokens
              ),
              let inputTokens = Int64(exactly: usage.inputTokens),
              let outputTokens = Int64(exactly: usage.outputTokens)
        else {
            throw InvalidRuminationPayloadError.negativeUsage
        }
        try self.init(
            cacheReadTokens: cacheReadTokens,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Self.expectedKeys else {
            throw InvalidRuminationPayloadError.invalidShape
        }
        try self.init(
            cacheReadTokens: container.decode(
                Int64.self,
                forKey: .cacheReadTokens
            ),
            inputTokens: container.decode(
                Int64.self,
                forKey: .inputTokens
            ),
            outputTokens: container.decode(
                Int64.self,
                forKey: .outputTokens
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            cacheReadTokens,
            forKey: .cacheReadTokens
        )
        try container.encode(inputTokens, forKey: .inputTokens)
        try container.encode(outputTokens, forKey: .outputTokens)
    }
}

package struct RuminationAttemptFailure:
    LocalizedError, Sendable, Equatable
{
    package let failure: DurableWorkFailure
    package let usage: RuminationUsageCountersV1?

    package init(
        code: String,
        safeMessage: String?,
        disposition: DurableWorkFailureDisposition,
        usage: RuminationUsageCountersV1?
    ) throws {
        let expected:
            (
                message: String,
                disposition: DurableWorkFailureDisposition,
                usageRequired: Bool
            )
        switch code {
        case "rumination_profile_not_found":
            expected = (
                "反刍所用运行配置不存在。",
                .deterministic,
                false
            )
        case "rumination_model_catalog_unavailable":
            expected = (
                "反刍所用模型目录不可用。",
                .deterministic,
                false
            )
        case "rumination_model_unsupported":
            expected = (
                "反刍所用模型不受该运行配置支持。",
                .deterministic,
                false
            )
        case "rumination_credential_account_missing":
            expected = (
                "反刍运行配置缺少凭据账户。",
                .deterministic,
                false
            )
        case "rumination_credential_not_found":
            expected = (
                "反刍所需凭据不存在。",
                .deterministic,
                false
            )
        case "rumination_credential_read_failed":
            expected = (
                "反刍所需凭据读取失败。",
                .deterministic,
                false
            )
        case "rumination_endpoint_invalid":
            expected = (
                "反刍运行配置的服务地址无效。",
                .deterministic,
                false
            )
        case "rumination_provider_construction_failed":
            expected = (
                "反刍服务初始化失败。",
                .deterministic,
                false
            )
        case "rumination_oauth_account_id_not_found":
            expected = (
                "反刍所需 OAuth 账户信息不存在。",
                .deterministic,
                false
            )
        case "rumination_oauth_account_id_read_failed":
            expected = (
                "反刍所需 OAuth 账户信息读取失败。",
                .deterministic,
                false
            )
        case "rumination_profile_cli_unsupported":
            expected = (
                "当前 CLI 运行配置不支持耐久反刍。",
                .deterministic,
                false
            )
        case "rumination_transport_error":
            expected = (
                "反刍服务网络连接失败。",
                .transient,
                false
            )
        case "rumination_provider_unavailable":
            expected = (
                "反刍服务暂时不可用。",
                .transient,
                false
            )
        case "rumination_provider_malformed_response":
            expected = (
                "反刍服务返回了无效响应。",
                .transient,
                false
            )
        case "rumination_provider_unauthorized":
            expected = (
                "反刍服务认证失败。",
                .deterministic,
                false
            )
        case "rumination_provider_http_error":
            expected = (
                "反刍服务请求失败。",
                .deterministic,
                false
            )
        case "rumination_provider_api_error":
            expected = (
                "反刍服务返回错误。",
                .deterministic,
                false
            )
        case "rumination_contract_invalid":
            expected = (
                "反刍结果格式无效。",
                .deterministic,
                true
            )
        case "rumination_provider_failed":
            expected = (
                "反刍服务执行失败。",
                .deterministic,
                false
            )
        case "rumination_usage_invalid":
            expected = (
                "反刍用量数据无效。",
                .deterministic,
                false
            )
        default:
            throw InvalidRuminationPayloadError.invalidFailure
        }
        guard safeMessage == expected.message,
              disposition == expected.disposition,
              expected.usageRequired
                ? usage != nil
                : usage == nil
        else {
            throw InvalidRuminationPayloadError.invalidFailure
        }
        let usageJson = try usage.map {
            String(
                decoding: try CanonicalJSONV1.encode($0),
                as: UTF8.self
            )
        }
        self.failure = try DurableWorkFailure(
            code: code,
            message: safeMessage,
            disposition: disposition,
            usageJson: usageJson
        )
        self.usage = usage
    }

    package var errorDescription: String? {
        failure.message
    }
}

package struct RuminationProduction: Sendable, Equatable {
    package let result: RuminationResult
    package let usage: RuminationUsageCountersV1

    package init(
        result: RuminationResult,
        usage: RuminationUsageCountersV1
    ) {
        self.result = result
        self.usage = usage
    }
}

public enum RuminationPhase: Sendable, Equatable {
    case reading
    case extracting
    case organizing
}

public struct RuminationPhaseIdentity:
    Sendable, Hashable, Equatable
{
    public let ingestionId: String
    public let workId: String
    public let attempt: Int

    public init(
        ingestionId: String,
        workId: String,
        attempt: Int
    ) throws {
        guard RuminationWorkInput.isNonBlank(ingestionId) else {
            throw InvalidRuminationPayloadError.emptyIngestionId
        }
        guard RuminationWorkInput.isNonBlank(workId) else {
            throw InvalidRuminationPayloadError.emptyWorkId
        }
        guard attempt >= 0 else {
            throw InvalidRuminationPayloadError.negativeAttempt
        }
        self.ingestionId = ingestionId
        self.workId = workId
        self.attempt = attempt
    }
}

public struct RuminationProjectionCommitIdentity:
    Sendable, Hashable, Equatable
{
    public let phaseIdentity: RuminationPhaseIdentity
    public let workVersion: Int

    public init(
        phaseIdentity: RuminationPhaseIdentity,
        workVersion: Int
    ) throws {
        guard workVersion >= 1 else {
            throw InvalidRuminationPayloadError.invalidWorkVersion
        }
        self.phaseIdentity = phaseIdentity
        self.workVersion = workVersion
    }
}

public enum RuminationPhaseInvalidationReason:
    Sendable, Equatable
{
    case controlLoss
    case globalFatal
}

public enum RuminationInvalidationMilestone: Sendable, Equatable {
    case phase(
        identity: RuminationPhaseIdentity,
        reason: RuminationPhaseInvalidationReason
    )
    case projectionCommitted(RuminationProjectionCommitIdentity)
}

package enum RuminationPhaseCommand: Sendable, Equatable {
    case set(
        identity: RuminationPhaseIdentity,
        phase: RuminationPhase
    )
    case invalidate(RuminationInvalidationMilestone)
}

package struct RuminationPreParseAuthorizationLostError:
    Error, Sendable, Equatable
{
    package init() {}
}

package enum PlanningUsageOverflowField:
    String, Codable, Sendable, Equatable
{
    case cacheReadTokens
    case inputTokens
    case outputTokens
    case attemptBillableTokens
    case spentTokens
}

package enum PlanningUsageOverflowEvidenceV1:
    Codable, Sendable, Equatable
{
    case turnAggregate(
        priorAccumulatedUsage: PlanningUsageCountersV1,
        incomingUsage: PlanningUsageCountersV1,
        overflowFields: [PlanningUsageOverflowField]
    )
    case missionProjection(
        existingSpentTokens: Int64,
        attemptUsage: PlanningUsageCountersV1,
        overflowFields: [PlanningUsageOverflowField]
    )

    private typealias CodingKeys = PlanningPayloadCodingKey

    private static let turnKeys: Set<CodingKeys> = [
        .contractVersion,
        .reason,
        .priorAccumulatedUsage,
        .incomingUsage,
        .overflowFields,
    ]

    private static let missionKeys: Set<CodingKeys> = [
        .contractVersion,
        .reason,
        .existingSpentTokens,
        .attemptUsage,
        .overflowFields,
    ]

    private static let turnFields: Set<PlanningUsageOverflowField> = [
        .cacheReadTokens,
        .inputTokens,
        .outputTokens,
    ]

    private static let missionFields: Set<PlanningUsageOverflowField> = [
        .attemptBillableTokens,
        .spentTokens,
    ]

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let contractVersion = try container.decode(
            Int.self,
            forKey: .contractVersion
        )
        guard contractVersion == 1 else {
            throw InvalidPlanningPayloadError.invalidContractVersion
        }

        let reason = try container.decode(String.self, forKey: .reason)
        let fields = try container.decode(
            [PlanningUsageOverflowField].self,
            forKey: .overflowFields
        )
        switch reason {
        case "turn_aggregate":
            guard Set(container.allKeys) == Self.turnKeys else {
                throw InvalidPlanningPayloadError.invalidOverflowShape
            }
            try Self.validateCanonical(
                fields,
                allowed: Self.turnFields
            )
            self = .turnAggregate(
                priorAccumulatedUsage: try container.decode(
                    PlanningUsageCountersV1.self,
                    forKey: .priorAccumulatedUsage
                ),
                incomingUsage: try container.decode(
                    PlanningUsageCountersV1.self,
                    forKey: .incomingUsage
                ),
                overflowFields: fields
            )
        case "mission_projection":
            guard Set(container.allKeys) == Self.missionKeys else {
                throw InvalidPlanningPayloadError.invalidOverflowShape
            }
            try Self.validateCanonical(
                fields,
                allowed: Self.missionFields
            )
            let existingSpentTokens = try container.decode(
                Int64.self,
                forKey: .existingSpentTokens
            )
            guard existingSpentTokens >= 0 else {
                throw InvalidPlanningPayloadError.negativeUsage
            }
            self = .missionProjection(
                existingSpentTokens: existingSpentTokens,
                attemptUsage: try container.decode(
                    PlanningUsageCountersV1.self,
                    forKey: .attemptUsage
                ),
                overflowFields: fields
            )
        default:
            throw InvalidPlanningPayloadError.invalidOverflowShape
        }
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(1, forKey: .contractVersion)
        switch self {
        case let .turnAggregate(
            priorAccumulatedUsage,
            incomingUsage,
            overflowFields
        ):
            let fields = try Self.normalized(
                overflowFields,
                allowed: Self.turnFields
            )
            try container.encode("turn_aggregate", forKey: .reason)
            try container.encode(
                priorAccumulatedUsage,
                forKey: .priorAccumulatedUsage
            )
            try container.encode(incomingUsage, forKey: .incomingUsage)
            try container.encode(fields, forKey: .overflowFields)
        case let .missionProjection(
            existingSpentTokens,
            attemptUsage,
            overflowFields
        ):
            guard existingSpentTokens >= 0 else {
                throw InvalidPlanningPayloadError.negativeUsage
            }
            let fields = try Self.normalized(
                overflowFields,
                allowed: Self.missionFields
            )
            try container.encode("mission_projection", forKey: .reason)
            try container.encode(
                existingSpentTokens,
                forKey: .existingSpentTokens
            )
            try container.encode(attemptUsage, forKey: .attemptUsage)
            try container.encode(fields, forKey: .overflowFields)
        }
    }

    private static func normalized(
        _ fields: [PlanningUsageOverflowField],
        allowed: Set<PlanningUsageOverflowField>
    ) throws -> [PlanningUsageOverflowField] {
        guard !fields.isEmpty,
              fields.allSatisfy(allowed.contains)
        else {
            throw InvalidPlanningPayloadError.invalidOverflowFields
        }
        return Array(Set(fields)).sorted(by: utf8LessThan)
    }

    private static func validateCanonical(
        _ fields: [PlanningUsageOverflowField],
        allowed: Set<PlanningUsageOverflowField>
    ) throws {
        let canonical = try normalized(fields, allowed: allowed)
        guard fields == canonical else {
            throw InvalidPlanningPayloadError.nonCanonicalOverflowFields
        }
    }

    private static func utf8LessThan(
        _ lhs: PlanningUsageOverflowField,
        _ rhs: PlanningUsageOverflowField
    ) -> Bool {
        lhs.rawValue.utf8.lexicographicallyPrecedes(rhs.rawValue.utf8)
    }
}

package struct UsageOverflowError: Error, Sendable, Equatable {
    package let evidence: PlanningUsageOverflowEvidenceV1

    package init(evidence: PlanningUsageOverflowEvidenceV1) {
        self.evidence = evidence
    }
}

public struct PlanningRequiresDurablePlanningCapabilityError:
    Error, Sendable, Equatable
{
    public init() {}
}

public struct RuminationRequiresDurableRuminationCapabilityError:
    Error, Sendable, Equatable
{
    public init() {}
}

public struct DurableWorkReplayConflictError: Error, Sendable, Equatable {
    public init() {}
}

package struct StaleScheduleConfigurationError:
    Error, Sendable, Equatable
{
    package let scheduleId: String

    package init(scheduleId: String) {
        self.scheduleId = scheduleId
    }
}

package struct StaleScheduleReplayPreparationError:
    Error, Sendable, Equatable
{
    package let originalFireId: String
    package let expectedTemplateId: String
    package let actualTemplateId: String

    package init(
        originalFireId: String,
        expectedTemplateId: String,
        actualTemplateId: String
    ) {
        self.originalFireId = originalFireId
        self.expectedTemplateId = expectedTemplateId
        self.actualTemplateId = actualTemplateId
    }
}

package struct InvalidScheduleReplaySourceError:
    Error, Sendable, Equatable
{
    package let originalFireId: String

    package init(originalFireId: String) {
        self.originalFireId = originalFireId
    }
}

package struct ScheduleFireReplayIntegrityError:
    Error, Sendable, Equatable
{
    package let fireId: String

    package init(fireId: String) {
        self.fireId = fireId
    }
}

package struct ScheduleFireScopeIntegrityError:
    Error, Sendable, Equatable
{
    package let scheduleId: String

    package init(scheduleId: String) {
        self.scheduleId = scheduleId
    }
}

package struct StaleScheduleEvaluationError:
    Error, Sendable, Equatable
{
    package let scheduleId: String
    package let slotKey: String

    package init(scheduleId: String, slotKey: String) {
        self.scheduleId = scheduleId
        self.slotKey = slotKey
    }
}

package struct ScheduleEvaluationIntegrityError:
    Error, Sendable, Equatable
{
    package let scheduleId: String
    package let slotKey: String

    package init(scheduleId: String, slotKey: String) {
        self.scheduleId = scheduleId
        self.slotKey = slotKey
    }
}

package struct ScheduleEvaluationVersionOverflowError:
    Error, Sendable, Equatable
{
    package let scheduleId: String
    package let version: Int

    package init(scheduleId: String, version: Int) {
        self.scheduleId = scheduleId
        self.version = version
    }
}

public struct StaleDurableWorkClaimError: Error, Sendable, Equatable {
    public init() {}
}

public struct AttemptAlreadyClosedError: Error, Sendable, Equatable {
    public init() {}
}

public struct DurableWorkNotFoundError: Error, Sendable, Equatable {
    public let workId: String

    public init(workId: String) {
        self.workId = workId
    }
}

public struct DurableWorkInvalidCanonicalJSONError:
    Error, Sendable, Equatable
{
    public init() {}
}

public enum InvalidDurableWorkOutputJSONError: Error, Sendable, Equatable {
    case invalidJSON
    case rootMustBeObject
    case notCanonical
}

public struct DurableWorkInputHashMismatchError:
    Error, Sendable, Equatable
{
    public init() {}
}

public struct InvalidDurableWorkStateError: Error, Sendable, Equatable {
    public init() {}
}

public struct BackoffOverflowError: Error, Sendable, Equatable {
    public init() {}
}

public enum InvalidDurableWorkTimeError: Error, Sendable, Equatable {
    case nonFiniteNow
    case nonFiniteLeaseDuration
    case nonPositiveLeaseDuration
    case nonFiniteLeaseExpiration
    case nonAdvancingLeaseExpiration
}

public enum InvalidDurableWorkCancellationReasonError:
    Error, Sendable, Equatable
{
    case empty
    case tooLong
    case containsControlScalar
}

public struct CampDeletionRequiresRetirementCapabilityError:
    Error, Sendable, Equatable
{
    public init() {}
}
