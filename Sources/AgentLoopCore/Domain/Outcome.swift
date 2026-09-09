import Foundation
import GRDB

package enum P1DTimestampV1 {
    private static let persistedMillisecondTolerance = 0.01

    package static func canonical(_ value: Date) throws -> Date {
        try CanonicalContractCodingV1.validateFinite(value)
        let milliseconds = value.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else {
            throw P1ContractValidationError.invalidTime
        }
        return Date(
            timeIntervalSince1970:
                milliseconds.rounded(.down) / 1_000
        )
    }

    package static func validateCanonical(_ value: Date) throws {
        guard try canonical(value) == value else {
            throw P1ContractValidationError.invalidTime
        }
    }

    /// GRDB persists `Date` values as millisecond text. Foundation's text
    /// decoder can return a value a few binary floating-point ulps away from
    /// the original millisecond, so restore the exact contract value at the
    /// database boundary. Values that are not genuine millisecond text still
    /// fail closed instead of being silently rounded.
    package static func restorePersisted(_ value: Date) throws -> Date {
        try CanonicalContractCodingV1.validateFinite(value)
        let milliseconds = value.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else {
            throw P1ContractValidationError.invalidTime
        }
        let restoredMilliseconds = milliseconds.rounded()
        guard abs(milliseconds - restoredMilliseconds)
                <= persistedMillisecondTolerance
        else {
            throw P1ContractValidationError.invalidTime
        }
        return Date(
            timeIntervalSince1970: restoredMilliseconds / 1_000
        )
    }

    package static func restorePersisted(_ value: Date?) throws -> Date? {
        guard let value else { return nil }
        return try restorePersisted(value)
    }
}

package struct P1DCommandEventShapeV1: Sendable, Equatable {
    package let campId: String
    package let aggregateType: String
    package let aggregateId: String
    package let aggregateVersion: Int
    package let eventType: String
    package let payload: JSONValue

    package init(
        campId: String,
        aggregateType: String,
        aggregateId: String,
        aggregateVersion: Int,
        eventType: String,
        payload: JSONValue
    ) throws {
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateNonempty(aggregateType)
        try CanonicalContractCodingV1.validateNonempty(aggregateId)
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateNonempty(eventType)
        self.campId = campId
        self.aggregateType = aggregateType
        self.aggregateId = aggregateId
        self.aggregateVersion = aggregateVersion
        self.eventType = eventType
        self.payload = payload
    }
}

package struct P1DPreparedCommandV1: Sendable, Equatable {
    package let commandType: String
    package let envelope: CommandEnvelopeV1
    package let commandPayloadHash: String
    package let events: [P1DCommandEventShapeV1]

    package static func make<Payload: Encodable>(
        commandType: String,
        envelope: CommandEnvelopeV1,
        payload: Payload,
        events: [P1DCommandEventShapeV1]
    ) throws -> Self {
        try CanonicalContractCodingV1.validateNonempty(commandType)
        let hash = try CanonicalContractCodingV1.wholeCommandHash(
            envelope: envelope,
            payload: payload
        )
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        return Self(
            commandType: commandType,
            envelope: envelope,
            commandPayloadHash: hash,
            events: events
        )
    }
}

package struct GoalMissionLinkRecordV1:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "goal_mission_link"

    package var missionId: String
    package var goalId: String
    package var outcomeContractId: String?
    package var outcomeContractVersion: Int?
    package var state: GoalMissionLinkStateV1
    package var version: Int
    package var createdAt: Date
    package var updatedAt: Date
}

package enum GoalMissionLinkStateV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case detached
}

package struct ActivatedGoalV1: Codable, Sendable, Equatable {
    package let goal: GoalControllerRecord
    package let link: GoalMissionLinkRecordV1
}

package struct ActivateGoalCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let contract: OutcomeContractRef
    package let missionId: String
    package let expectedLinkVersion: Int?

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        contract: OutcomeContractRef,
        missionId: String,
        expectedLinkVersion: Int?
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        if let expectedLinkVersion {
            try CanonicalContractCodingV1.validateNonnegative(expectedLinkVersion)
        }
        self.envelope = envelope
        self.goal = goal
        self.contract = contract
        self.missionId = missionId
        self.expectedLinkVersion = expectedLinkVersion
    }
}

package struct LinkMissionToGoalCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let contract: OutcomeContractRef
    package let missionId: String
    package let expectedLinkVersion: Int?

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        contract: OutcomeContractRef,
        missionId: String,
        expectedLinkVersion: Int?
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        if let expectedLinkVersion {
            try CanonicalContractCodingV1.validateNonnegative(expectedLinkVersion)
        }
        self.envelope = envelope
        self.goal = goal
        self.contract = contract
        self.missionId = missionId
        self.expectedLinkVersion = expectedLinkVersion
    }
}

package enum GoalStatusTransitionV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case pause
    case resume
    case achieve
    case reopen
}

package struct GoalStatusCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let transition: GoalStatusTransitionV1

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        transition: GoalStatusTransitionV1
    ) {
        self.envelope = envelope
        self.goal = goal
        self.transition = transition
    }
}

package enum GoalActivationError: Error, Sendable, Equatable {
    case missingGoal
    case invalidGoalState
    case staleGoal
    case missingContract
    case inactiveContract
    case wrongGoal
    case wrongCamp
    case invalidMission
}

package struct GoalAchievementPreconditionError: Error, Sendable, Equatable {
    package init() {}
}

package struct GoalMissionLinkConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct InvalidGoalTransitionError: Error, Sendable, Equatable {
    package init() {}
}

package struct P1DProjectionConflictError: Error, Sendable, Equatable {
    package init() {}
}

package enum OutcomeArtifactKindV1:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case file
    case externalReceipt
}

package struct OutcomeArtifactRefV1:
    Codable, Sendable, Equatable, Hashable
{
    package let kind: OutcomeArtifactKindV1
    package let locator: String
    package let contentHash: String

    package init(
        kind: OutcomeArtifactKindV1,
        locator: String,
        contentHash: String
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(locator)
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        self.kind = kind
        self.locator = locator
        self.contentHash = contentHash
    }
}

package enum OutcomeStateV1:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case produced
    case verificationPending
    case verificationFailed
    case blocked
    case verified
    case delivered
    case accepted
    case returned
    case revoked
    case invalidated
}

package struct OutcomeRefV1: Codable, Sendable, Equatable, Hashable {
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

package struct OutcomeVersionSnapshotV1: Codable, Sendable, Equatable {
    package let ref: OutcomeRefV1
    package let contract: OutcomeContractRef
    package let producerActorId: String
    package let runIds: [String]
    package let manifest: [OutcomeArtifactRefV1]
    package let createdAt: Date
}

package struct OutcomeSnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let goalId: String
    package let missionId: String
    package let contract: OutcomeContractRef
    package let currentVersion: Int
    package let state: OutcomeStateV1
    package let aggregateVersion: Int
    package let createdAt: Date
    package let updatedAt: Date
    package let version: OutcomeVersionSnapshotV1

    package var currentRef: OutcomeRefV1 { version.ref }
}

package enum OutcomeTransitionCommandV1:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case beginVerification
    case reduceVerification
    case markDelivered
    case acceptOutcome
    case returnOutcome
    case revokeAcceptance
    case invalidateVerification
    case recordNewOutcomeVersion
}

package struct OutcomeTransitionEdgeV1: Sendable, Equatable, Hashable {
    package let command: OutcomeTransitionCommandV1
    package let from: OutcomeStateV1
    package let to: OutcomeStateV1

    package init(
        command: OutcomeTransitionCommandV1,
        from: OutcomeStateV1,
        to: OutcomeStateV1
    ) {
        self.command = command
        self.from = from
        self.to = to
    }
}

package enum OutcomeTransitionPolicyV1 {
    package static func allows(_ edge: OutcomeTransitionEdgeV1) -> Bool {
        switch (edge.command, edge.from, edge.to) {
        case (.beginVerification, .produced, .verificationPending),
             (.beginVerification, .verificationFailed, .verificationPending),
             (.beginVerification, .blocked, .verificationPending),
             (.reduceVerification, .verificationPending,
                 .verificationPending),
             (.reduceVerification, .verificationPending, .verified),
             (.reduceVerification, .verificationPending,
                 .verificationFailed),
             (.reduceVerification, .verificationPending, .blocked),
             (.reduceVerification, .verificationFailed,
                 .verificationPending),
             (.reduceVerification, .verificationFailed, .verified),
             (.reduceVerification, .verificationFailed,
                 .verificationFailed),
             (.reduceVerification, .verificationFailed, .blocked),
             (.reduceVerification, .blocked, .verificationPending),
             (.reduceVerification, .blocked, .verified),
             (.reduceVerification, .blocked, .verificationFailed),
             (.reduceVerification, .blocked, .blocked),
             (.markDelivered, .verified, .delivered),
             (.acceptOutcome, .delivered, .accepted),
             (.returnOutcome, .delivered, .returned),
             (.returnOutcome, .accepted, .returned),
             (.revokeAcceptance, .accepted, .revoked),
             (.invalidateVerification, .verificationPending,
                 .verificationPending),
             (.invalidateVerification, .verificationFailed,
                 .verificationPending),
             (.invalidateVerification, .blocked, .verificationPending),
             (.invalidateVerification, .verified, .verificationPending),
             (.invalidateVerification, .delivered, .verificationPending),
             (.invalidateVerification, .accepted, .invalidated),
             (.recordNewOutcomeVersion, .returned, .verificationPending),
             (.recordNewOutcomeVersion, .revoked, .verificationPending),
             (.recordNewOutcomeVersion, .invalidated,
                 .verificationPending),
             (.recordNewOutcomeVersion, .verificationFailed,
                 .verificationPending),
             (.recordNewOutcomeVersion, .blocked, .verificationPending):
            true
        default:
            false
        }
    }
}

package struct RecordInitialOutcomeCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let outcomeId: String
    package let goal: GoalHeadV1
    package let contract: OutcomeContractRef
    package let missionId: String
    package let producerActorId: String
    package let runIds: [String]
    package let manifest: [OutcomeArtifactRefV1]

    package init(
        envelope: CommandEnvelopeV1,
        outcomeId: String,
        goal: GoalHeadV1,
        contract: OutcomeContractRef,
        missionId: String,
        producerActorId: String,
        runIds: [String],
        manifest: [OutcomeArtifactRefV1]
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(outcomeId)
        try CanonicalContractCodingV1.validateCanonicalUUID(missionId)
        try CanonicalContractCodingV1.validateNonempty(producerActorId)
        for runId in runIds {
            try CanonicalContractCodingV1.validateNonempty(runId)
        }
        guard !manifest.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.outcomeId = outcomeId
        self.goal = goal
        self.contract = contract
        self.missionId = missionId
        self.producerActorId = producerActorId
        self.runIds = runIds
        self.manifest = manifest
    }
}

package struct RecordNewOutcomeVersionCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let outcome: OutcomeRefV1
    package let expectedAggregateVersion: Int
    package let producerActorId: String
    package let runIds: [String]
    package let manifest: [OutcomeArtifactRefV1]

    package init(
        envelope: CommandEnvelopeV1,
        outcome: OutcomeRefV1,
        expectedAggregateVersion: Int,
        producerActorId: String,
        runIds: [String],
        manifest: [OutcomeArtifactRefV1]
    ) throws {
        try CanonicalContractCodingV1.validatePositive(
            expectedAggregateVersion
        )
        try CanonicalContractCodingV1.validateNonempty(producerActorId)
        for runId in runIds {
            try CanonicalContractCodingV1.validateNonempty(runId)
        }
        guard !manifest.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }
        self.envelope = envelope
        self.outcome = outcome
        self.expectedAggregateVersion = expectedAggregateVersion
        self.producerActorId = producerActorId
        self.runIds = runIds
        self.manifest = manifest
    }
}

package struct BeginVerificationCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let outcome: OutcomeRefV1
    package let expectedAggregateVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        outcome: OutcomeRefV1,
        expectedAggregateVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validatePositive(
            expectedAggregateVersion
        )
        self.envelope = envelope
        self.outcome = outcome
        self.expectedAggregateVersion = expectedAggregateVersion
    }
}

package struct MarkDeliveredCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let outcome: OutcomeRefV1
    package let expectedAggregateVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        outcome: OutcomeRefV1,
        expectedAggregateVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validatePositive(
            expectedAggregateVersion
        )
        self.envelope = envelope
        self.outcome = outcome
        self.expectedAggregateVersion = expectedAggregateVersion
    }
}

package struct InvalidInitialOutcomeError: Error, Sendable, Equatable {
    package init() {}
}

package struct InvalidOutcomeTransitionError: Error, Sendable, Equatable {
    package init() {}
}

package struct OutcomeVersionRequiredError: Error, Sendable, Equatable {
    package init() {}
}

package struct OutcomeReferenceMismatchError: Error, Sendable, Equatable {
    package init() {}
}

package struct OutcomeDeliveryError: Error, Sendable, Equatable {
    package init() {}
}
