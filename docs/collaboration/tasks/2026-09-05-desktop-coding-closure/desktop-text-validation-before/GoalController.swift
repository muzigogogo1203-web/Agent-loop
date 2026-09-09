import Foundation
import GRDB

package enum GoalControllerStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case clarifying
    case ready
    case active
    case paused
    case achieved
    case abandoned
    case failed
    case deletedTombstone
}

package struct GoalControllerRecord:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "goal_controller"

    package var id: String
    package var campId: String
    package var sourceInputId: String?
    package var title: String
    package var rawIntent: String
    package var status: GoalControllerStatusV1
    package var currentUnderstandingId: String?
    package var currentUnderstandingVersion: Int?
    package var currentOutcomeContractId: String?
    package var currentOutcomeContractVersion: Int?
    package var aggregateVersion: Int
    package var createdByActorId: String
    package var createdAt: Date
    package var updatedAt: Date

    package init(
        id: String,
        campId: String,
        sourceInputId: String?,
        title: String,
        rawIntent: String,
        status: GoalControllerStatusV1,
        currentUnderstandingId: String?,
        currentUnderstandingVersion: Int?,
        currentOutcomeContractId: String?,
        currentOutcomeContractVersion: Int?,
        aggregateVersion: Int,
        createdByActorId: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validateCampID(campId)
        if let sourceInputId {
            try CanonicalContractCodingV1.validateCanonicalUUID(sourceInputId)
        }
        try CanonicalContractCodingV1.validateNonempty(title)
        try CanonicalContractCodingV1.validateNonempty(rawIntent)
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateNonempty(createdByActorId)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        guard (currentUnderstandingId == nil)
                == (currentUnderstandingVersion == nil),
              currentOutcomeContractId == nil,
              currentOutcomeContractVersion == nil
        else {
            throw P1ContractValidationError.invalidMembership
        }
        if let currentUnderstandingId, let currentUnderstandingVersion {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                currentUnderstandingId
            )
            try CanonicalContractCodingV1.validatePositive(
                currentUnderstandingVersion
            )
        }
        if status == .ready {
            guard currentUnderstandingId != nil,
                  currentUnderstandingVersion != nil
            else {
                throw P1ContractValidationError.invalidMembership
            }
        }
        self.id = id
        self.campId = campId
        self.sourceInputId = sourceInputId
        self.title = title
        self.rawIntent = rawIntent
        self.status = status
        self.currentUnderstandingId = currentUnderstandingId
        self.currentUnderstandingVersion = currentUnderstandingVersion
        self.currentOutcomeContractId = currentOutcomeContractId
        self.currentOutcomeContractVersion = currentOutcomeContractVersion
        self.aggregateVersion = aggregateVersion
        self.createdByActorId = createdByActorId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

package struct GoalHeadV1: Sendable, Equatable, Codable {
    package let goalId: String
    package let campId: String
    package let expectedGoalVersion: Int

    package init(
        goalId: String,
        campId: String,
        expectedGoalVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validatePositive(expectedGoalVersion)
        self.goalId = goalId
        self.campId = campId
        self.expectedGoalVersion = expectedGoalVersion
    }
}

package enum GoalControllerTransitionPolicyV1 {
    package static let p1CWritableStatuses: Set<GoalControllerStatusV1> = [
        .clarifying, .ready, .abandoned, .failed,
    ]

    package static func allows(
        from: GoalControllerStatusV1,
        to: GoalControllerStatusV1
    ) -> Bool {
        switch (from, to) {
        case (.clarifying, .ready),
             (.clarifying, .abandoned),
             (.clarifying, .failed),
             (.ready, .ready),
             (.ready, .abandoned),
             (.ready, .failed):
            true
        default:
            false
        }
    }

    package static func createFromInput(
        input: InputEnvelopeRecord,
        goalId: String,
        title: String,
        rawIntent: String,
        actorId: String,
        now: Date
    ) throws -> GoalControllerRecord {
        guard input.retentionState != .deletionRequested,
              input.retentionState != .deletedTombstone,
              input.status != .campAssignmentRequired,
              input.status != .campAmbiguous,
              input.status != .deletedTombstone,
              let campId = input.campId,
              input.candidateCampIds.isEmpty
        else {
            throw GoalCampResolutionError()
        }
        return try GoalControllerRecord(
            id: goalId,
            campId: campId,
            sourceInputId: input.id,
            title: title,
            rawIntent: rawIntent,
            status: .clarifying,
            currentUnderstandingId: nil,
            currentUnderstandingVersion: nil,
            currentOutcomeContractId: nil,
            currentOutcomeContractVersion: nil,
            aggregateVersion: 1,
            createdByActorId: actorId,
            createdAt: now,
            updatedAt: now
        )
    }
}

package struct GoalCampResolutionError: Error, Sendable, Equatable {
    package init() {}
}

package struct GoalProjectionVersionConflictError: Error, Sendable, Equatable {
    package init() {}
}

// P1-D-GOAL-EXTENSION-BEGIN
package enum P1DGoalTransitionPolicyV1 {
    package static func allows(
        from: GoalControllerStatusV1,
        transition: GoalStatusTransitionV1,
        actorType: DomainActorType,
        actorId: String
    ) -> Bool {
        switch (from, transition, actorType, actorId) {
        case (.active, .pause, .user, P1DActorID.localOwner),
             (.paused, .resume, .user, P1DActorID.localOwner),
             (.active, .achieve, .user, P1DActorID.localOwner),
             (.achieved, .reopen, .system, P1DActorID.outcomeReopen):
            true
        default:
            false
        }
    }
}
// P1-D-GOAL-EXTENSION-END
