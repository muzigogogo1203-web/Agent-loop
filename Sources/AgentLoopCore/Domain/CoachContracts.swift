import Foundation
import GRDB

package let p1CCoachActorId = "system:coach:v1"

package enum CoachSessionStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case interviewing
    case waitingForUser
    case readyForConfirmation
    case confirmed
    case canceled
    case failed
}

package enum CoachQuestionStateV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case open
    case answered
    case withdrawn
}

package struct CoachSessionRecord:
    Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "coach_session"

    package var id: String
    package var goalId: String
    package var inputId: String?
    package var actorId: String
    package var status: CoachSessionStatusV1
    package var currentUnderstandingVersion: Int?
    package var pendingQuestionId: String?
    package var traceId: String
    package var aggregateVersion: Int
    package var createdAt: Date
    package var updatedAt: Date

    package init(
        id: String,
        goalId: String,
        inputId: String?,
        status: CoachSessionStatusV1,
        currentUnderstandingVersion: Int?,
        pendingQuestionId: String?,
        traceId: String,
        aggregateVersion: Int,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        if let inputId {
            try CanonicalContractCodingV1.validateCanonicalUUID(inputId)
        }
        if let currentUnderstandingVersion {
            try CanonicalContractCodingV1.validatePositive(
                currentUnderstandingVersion
            )
        }
        if let pendingQuestionId {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                pendingQuestionId
            )
        }
        try CanonicalContractCodingV1.validateNonempty(traceId)
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        guard (status == .waitingForUser) == (pendingQuestionId != nil) else {
            throw P1ContractValidationError.invalidMembership
        }
        self.id = id
        self.goalId = goalId
        self.inputId = inputId
        actorId = p1CCoachActorId
        self.status = status
        self.currentUnderstandingVersion = currentUnderstandingVersion
        self.pendingQuestionId = pendingQuestionId
        self.traceId = traceId
        self.aggregateVersion = aggregateVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    package init(row: Row) throws {
        let statusRaw: String = row["status"]
        let storedActor: String = row["actorId"]
        guard let status = CoachSessionStatusV1(rawValue: statusRaw),
              storedActor == p1CCoachActorId
        else {
            throw P1ContractValidationError.invalidMembership
        }
        try self.init(
            id: row["id"],
            goalId: row["goalId"],
            inputId: row["inputId"],
            status: status,
            currentUnderstandingVersion: row["currentUnderstandingVersion"],
            pendingQuestionId: row["pendingQuestionId"],
            traceId: row["traceId"],
            aggregateVersion: row["aggregateVersion"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    package func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["goalId"] = goalId
        container["inputId"] = inputId
        container["actorId"] = actorId
        container["status"] = status.rawValue
        container["currentUnderstandingVersion"] = currentUnderstandingVersion
        container["pendingQuestionId"] = pendingQuestionId
        container["traceId"] = traceId
        container["aggregateVersion"] = aggregateVersion
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }
}

package struct CoachQuestionRecord:
    Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "coach_question"

    package var id: String
    package var sessionId: String
    package var decisionKey: String
    package var prompt: String
    package var recommendation: String
    package var reason: String
    package var answer: CoachAnswerV1?
    package var state: CoachQuestionStateV1
    package var createdAt: Date
    package var answeredAt: Date?

    package init(
        id: String,
        sessionId: String,
        decisionKey: String,
        prompt: String,
        recommendation: String,
        reason: String,
        answer: CoachAnswerV1?,
        state: CoachQuestionStateV1,
        createdAt: Date,
        answeredAt: Date?
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        guard decisionKey == (try CoachTurnWorkInputV1.decisionKey(
            nextQuestionId: id
        )) else {
            throw P1ContractValidationError.invalidMembership
        }
        try CanonicalContractCodingV1.validateNarrativeText(prompt)
        try CanonicalContractCodingV1.validateNarrativeText(recommendation)
        try CanonicalContractCodingV1.validateNarrativeText(reason)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        guard (state == .answered) == (answer != nil),
              (state == .answered) == (answeredAt != nil)
        else {
            throw P1ContractValidationError.invalidMembership
        }
        if let answeredAt {
            try CanonicalContractCodingV1.validateFinite(answeredAt)
        }
        self.id = id
        self.sessionId = sessionId
        self.decisionKey = decisionKey
        self.prompt = prompt
        self.recommendation = recommendation
        self.reason = reason
        self.answer = answer
        self.state = state
        self.createdAt = createdAt
        self.answeredAt = answeredAt
    }

    package init(row: Row) throws {
        let stateRaw: String = row["state"]
        guard let state = CoachQuestionStateV1(rawValue: stateRaw) else {
            throw P1ContractValidationError.invalidMembership
        }
        let answerJSON: String? = row["answerJson"]
        let answer: CoachAnswerV1?
        if let answerJSON {
            answer = try CanonicalContractCodingV1.decode(
                CoachAnswerV1.self,
                from: Data(answerJSON.utf8)
            )
        } else {
            answer = nil
        }
        try self.init(
            id: row["id"],
            sessionId: row["sessionId"],
            decisionKey: row["decisionKey"],
            prompt: row["prompt"],
            recommendation: row["recommendation"],
            reason: row["reason"],
            answer: answer,
            state: state,
            createdAt: row["createdAt"],
            answeredAt: row["answeredAt"]
        )
    }

    package func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["sessionId"] = sessionId
        container["decisionKey"] = decisionKey
        container["prompt"] = prompt
        container["recommendation"] = recommendation
        container["reason"] = reason
        container["answerJson"] = try answer.map {
            try CanonicalContractCodingV1.string($0)
        }
        container["state"] = state.rawValue
        container["createdAt"] = createdAt
        container["answeredAt"] = answeredAt
    }
}

package struct CoachHeadV1: Sendable, Equatable, Codable {
    package let sessionId: String
    package let expectedSessionVersion: Int

    package init(sessionId: String, expectedSessionVersion: Int) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try CanonicalContractCodingV1.validatePositive(expectedSessionVersion)
        self.sessionId = sessionId
        self.expectedSessionVersion = expectedSessionVersion
    }
}

package enum SessionBranchV1: Sendable, Equatable, Codable {
    case none
    case expected(sessionId: String, expectedSessionVersion: Int)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, sessionId, expectedSessionVersion
    }
    private enum Kind: String, Codable { case none, expected }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard values.contains(.sessionId), values.contains(.expectedSessionVersion) else {
            throw P1ContractValidationError.invalidKeys
        }
        switch try values.decode(Kind.self, forKey: .kind) {
        case .none:
            guard try values.decodeIfPresent(String.self, forKey: .sessionId) == nil,
                  try values.decodeIfPresent(Int.self, forKey: .expectedSessionVersion) == nil
            else { throw P1ContractValidationError.invalidMembership }
            self = .none
        case .expected:
            let id = try values.decode(String.self, forKey: .sessionId)
            let version = try values.decode(Int.self, forKey: .expectedSessionVersion)
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
            try CanonicalContractCodingV1.validatePositive(version)
            self = .expected(sessionId: id, expectedSessionVersion: version)
        }
    }

    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try values.encode(Kind.none, forKey: .kind)
            try values.encodeNil(forKey: .sessionId)
            try values.encodeNil(forKey: .expectedSessionVersion)
        case let .expected(id, version):
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
            try CanonicalContractCodingV1.validatePositive(version)
            try values.encode(Kind.expected, forKey: .kind)
            try values.encode(id, forKey: .sessionId)
            try values.encode(version, forKey: .expectedSessionVersion)
        }
    }
}

package enum CoachFailureScopeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case clarifyingGoal
    case readyRevisionSessionOnly
}

package enum CoachWorkFailureBranchV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case retryScheduledClarifyingGoal
    case retryScheduledReadyRevision
    case terminalClarifyingGoal
    case terminalReadyGoalPreserved

    package static func derive(
        scope: CoachFailureScopeV1,
        failure: ControlWorkerProviderFailureV1,
        attempt: Int,
        maxAttempts: Int
    ) throws -> Self {
        guard maxAttempts == 4, (1...4).contains(attempt) else {
            throw P1ContractValidationError.invalidInteger
        }
        let retry = failure.disposition == .transient && attempt < maxAttempts
        switch (scope, retry) {
        case (.clarifyingGoal, true):
            return .retryScheduledClarifyingGoal
        case (.readyRevisionSessionOnly, true):
            return .retryScheduledReadyRevision
        case (.clarifyingGoal, false):
            return .terminalClarifyingGoal
        case (.readyRevisionSessionOnly, false):
            return .terminalReadyGoalPreserved
        }
    }
}

package struct CoachTurnWorkInputV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let goalId: String
    package let sessionId: String
    package let nextQuestionId: String
    package let decisionKey: String
    package let turnCommandHash: String
    package let expectedUnderstandingEventVersion: Int
    package let failureScope: CoachFailureScopeV1
    package let confirmedUnderstanding: UnderstandingHeadV1?

    package init(
        goalId: String,
        sessionId: String,
        nextQuestionId: String,
        turnCommandHash: String,
        expectedUnderstandingEventVersion: Int,
        failureScope: CoachFailureScopeV1,
        confirmedUnderstanding: UnderstandingHeadV1?
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try CanonicalContractCodingV1.validateCanonicalUUID(nextQuestionId)
        try CanonicalContractCodingV1.validateLowercaseHash(turnCommandHash)
        try CanonicalContractCodingV1.validateNonnegative(
            expectedUnderstandingEventVersion
        )
        if failureScope == .clarifyingGoal {
            guard confirmedUnderstanding == nil
            else { throw P1ContractValidationError.invalidMembership }
        } else {
            guard let confirmedUnderstanding,
                  confirmedUnderstanding.understandingId == goalId,
                  confirmedUnderstanding.expectedUnderstandingEventVersion
                    == expectedUnderstandingEventVersion
            else { throw P1ContractValidationError.invalidMembership }
        }
        schemaVersion = 1
        self.goalId = goalId
        self.sessionId = sessionId
        self.nextQuestionId = nextQuestionId
        decisionKey = try Self.decisionKey(nextQuestionId: nextQuestionId)
        self.turnCommandHash = turnCommandHash
        self.expectedUnderstandingEventVersion = expectedUnderstandingEventVersion
        self.failureScope = failureScope
        self.confirmedUnderstanding = confirmedUnderstanding
    }

    package static func decisionKey(nextQuestionId: String) throws -> String {
        try CanonicalContractCodingV1.validateCanonicalUUID(nextQuestionId)
        return "decision:v1:\(nextQuestionId)"
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, goalId, sessionId, nextQuestionId, decisionKey
        case turnCommandHash, expectedUnderstandingEventVersion, failureScope
        case confirmedUnderstanding
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1,
              values.contains(.confirmedUnderstanding)
        else { throw P1ContractValidationError.invalidSchemaVersion }
        let nextQuestionId = try values.decode(String.self, forKey: .nextQuestionId)
        try self.init(
            goalId: values.decode(String.self, forKey: .goalId),
            sessionId: values.decode(String.self, forKey: .sessionId),
            nextQuestionId: nextQuestionId,
            turnCommandHash: values.decode(String.self, forKey: .turnCommandHash),
            expectedUnderstandingEventVersion: values.decode(
                Int.self,
                forKey: .expectedUnderstandingEventVersion
            ),
            failureScope: values.decode(CoachFailureScopeV1.self, forKey: .failureScope),
            confirmedUnderstanding: values.decodeIfPresent(
                UnderstandingHeadV1.self,
                forKey: .confirmedUnderstanding
            )
        )
        guard decisionKey == (try values.decode(String.self, forKey: .decisionKey)) else {
            throw P1ContractValidationError.invalidMembership
        }
    }

    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(goalId, forKey: .goalId)
        try values.encode(sessionId, forKey: .sessionId)
        try values.encode(nextQuestionId, forKey: .nextQuestionId)
        try values.encode(decisionKey, forKey: .decisionKey)
        try values.encode(turnCommandHash, forKey: .turnCommandHash)
        try values.encode(
            expectedUnderstandingEventVersion,
            forKey: .expectedUnderstandingEventVersion
        )
        try values.encode(failureScope, forKey: .failureScope)
        try values.encode(confirmedUnderstanding, forKey: .confirmedUnderstanding)
    }
}

package struct CoachAnswerV1: Sendable, Equatable, Codable {
    package let text: String
    package init(text: String) throws {
        try CanonicalContractCodingV1.validateNarrativeText(text)
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case text
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, ["text"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(text: values.decode(String.self, forKey: .text))
    }
}

package struct OpenCoachSessionCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let sourceInputId: String?
    package let sessionId: String
    package let nextQuestionId: String

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        sourceInputId: String?,
        sessionId: String,
        nextQuestionId: String
    ) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachOpenSession, envelope: envelope)
        if let sourceInputId {
            try CanonicalContractCodingV1.validateCanonicalUUID(sourceInputId)
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try CanonicalContractCodingV1.validateCanonicalUUID(nextQuestionId)
        self.envelope = envelope
        self.goal = goal
        self.sourceInputId = sourceInputId
        self.sessionId = sessionId
        self.nextQuestionId = nextQuestionId
    }

    private enum CodingKeys: String, CodingKey { case goal, sourceInputId, sessionId, nextQuestionId }
    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(goal, forKey: .goal)
        try values.encode(sourceInputId, forKey: .sourceInputId)
        try values.encode(sessionId, forKey: .sessionId)
        try values.encode(nextQuestionId, forKey: .nextQuestionId)
    }
}

package struct RecordCoachQuestionCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let claim: WorkClaimV1
    package let decisionKey: String
    package let prompt: String
    package let recommendation: String
    package let reason: String

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        coach: CoachHeadV1,
        claim: WorkClaimV1,
        decisionKey: String,
        prompt: String,
        recommendation: String,
        reason: String
    ) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachRecordQuestion, envelope: envelope)
        try CanonicalContractCodingV1.validateNonempty(decisionKey)
        try CanonicalContractCodingV1.validateNarrativeText(prompt)
        try CanonicalContractCodingV1.validateNarrativeText(recommendation)
        try CanonicalContractCodingV1.validateNarrativeText(reason)
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.claim = claim
        self.decisionKey = decisionKey
        self.prompt = prompt
        self.recommendation = recommendation
        self.reason = reason
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, claim, decisionKey, prompt, recommendation, reason }
}

package struct AnswerCoachQuestionCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let currentQuestionId: String
    package let answer: CoachAnswerV1
    package let nextQuestionId: String
    package let expectedUnderstandingEventVersion: Int

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        coach: CoachHeadV1,
        currentQuestionId: String,
        answer: CoachAnswerV1,
        nextQuestionId: String,
        expectedUnderstandingEventVersion: Int
    ) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachAnswerQuestion, envelope: envelope)
        try CanonicalContractCodingV1.validateCanonicalUUID(currentQuestionId)
        try CanonicalContractCodingV1.validateCanonicalUUID(nextQuestionId)
        try CanonicalContractCodingV1.validateNonnegative(expectedUnderstandingEventVersion)
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.currentQuestionId = currentQuestionId
        self.answer = answer
        self.nextQuestionId = nextQuestionId
        self.expectedUnderstandingEventVersion = expectedUnderstandingEventVersion
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, currentQuestionId, answer, nextQuestionId, expectedUnderstandingEventVersion }
}

package struct ProposeUnderstandingCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let claim: WorkClaimV1
    package let expectedUnderstandingEventVersion: Int
    package let content: UnderstandingContentV1

    package init(
        envelope: CommandEnvelopeV1,
        goal: GoalHeadV1,
        coach: CoachHeadV1,
        claim: WorkClaimV1,
        expectedUnderstandingEventVersion: Int,
        content: UnderstandingContentV1
    ) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachProposeUnderstanding, envelope: envelope)
        try CanonicalContractCodingV1.validateNonnegative(expectedUnderstandingEventVersion)
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.claim = claim
        self.expectedUnderstandingEventVersion = expectedUnderstandingEventVersion
        self.content = content
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, claim, expectedUnderstandingEventVersion, content }
}

package struct RequestCoachConfirmationCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let understanding: UnderstandingHeadV1
    package init(envelope: CommandEnvelopeV1, goal: GoalHeadV1, coach: CoachHeadV1, understanding: UnderstandingHeadV1) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachRequestConfirmation, envelope: envelope)
        guard understanding.understandingId == goal.goalId else { throw P1ContractValidationError.invalidMembership }
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.understanding = understanding
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, understanding }
}

package struct ConfirmUnderstandingCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let understanding: UnderstandingHeadV1
    package init(envelope: CommandEnvelopeV1, goal: GoalHeadV1, coach: CoachHeadV1, understanding: UnderstandingHeadV1) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachConfirmUnderstanding, envelope: envelope)
        guard understanding.understandingId == goal.goalId else { throw P1ContractValidationError.invalidMembership }
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.understanding = understanding
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, understanding }
}

package struct RequestUnderstandingRevisionCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let understanding: UnderstandingHeadV1
    package let revisionBranch: UnderstandingRevisionBranchV1
    package let nextQuestionId: String
    package init(envelope: CommandEnvelopeV1, goal: GoalHeadV1, coach: CoachHeadV1, understanding: UnderstandingHeadV1, revisionBranch: UnderstandingRevisionBranchV1, nextQuestionId: String) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachRequestUnderstandingRevision, envelope: envelope)
        guard understanding.understandingId == goal.goalId else { throw P1ContractValidationError.invalidMembership }
        try CanonicalContractCodingV1.validateCanonicalUUID(nextQuestionId)
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.understanding = understanding
        self.revisionBranch = revisionBranch
        self.nextQuestionId = nextQuestionId
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, understanding, revisionBranch, nextQuestionId }
}

package struct RecordCoachWorkFailureCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let coach: CoachHeadV1
    package let claim: WorkClaimV1
    package let expectedUnderstandingEventVersion: Int
    package let failure: ControlWorkerProviderFailureV1
    package let failureScope: CoachFailureScopeV1
    package let confirmedUnderstanding: UnderstandingHeadV1?
    package let failureBranch: CoachWorkFailureBranchV1
    package init(envelope: CommandEnvelopeV1, goal: GoalHeadV1, coach: CoachHeadV1, claim: WorkClaimV1, expectedUnderstandingEventVersion: Int, failure: ControlWorkerProviderFailureV1, failureScope: CoachFailureScopeV1, confirmedUnderstanding: UnderstandingHeadV1?, failureBranch: CoachWorkFailureBranchV1) throws {
        try P1CommandAuthorizationV1.validate(commandType: .coachRecordWorkFailure, envelope: envelope)
        try CanonicalContractCodingV1.validateNonnegative(expectedUnderstandingEventVersion)
        let derived = try CoachWorkFailureBranchV1.derive(scope: failureScope, failure: failure, attempt: claim.attempt, maxAttempts: 4)
        guard derived == failureBranch,
              (failureScope == .clarifyingGoal) == (confirmedUnderstanding == nil)
        else { throw P1ContractValidationError.invalidMembership }
        if let confirmedUnderstanding {
            guard confirmedUnderstanding.understandingId == goal.goalId,
                  confirmedUnderstanding.expectedUnderstandingEventVersion == expectedUnderstandingEventVersion
            else { throw P1ContractValidationError.invalidMembership }
        }
        self.envelope = envelope
        self.goal = goal
        self.coach = coach
        self.claim = claim
        self.expectedUnderstandingEventVersion = expectedUnderstandingEventVersion
        self.failure = failure
        self.failureScope = failureScope
        self.confirmedUnderstanding = confirmedUnderstanding
        self.failureBranch = failureBranch
    }
    private enum CodingKeys: String, CodingKey { case goal, coach, claim, expectedUnderstandingEventVersion, failure, failureScope, confirmedUnderstanding, failureBranch }
    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(goal, forKey: .goal)
        try values.encode(coach, forKey: .coach)
        try values.encode(claim, forKey: .claim)
        try values.encode(expectedUnderstandingEventVersion, forKey: .expectedUnderstandingEventVersion)
        try values.encode(failure, forKey: .failure)
        try values.encode(failureScope, forKey: .failureScope)
        try values.encode(confirmedUnderstanding, forKey: .confirmedUnderstanding)
        try values.encode(failureBranch, forKey: .failureBranch)
    }
}

package struct AbandonGoalCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let sessionBranch: SessionBranchV1
    package init(envelope: CommandEnvelopeV1, goal: GoalHeadV1, sessionBranch: SessionBranchV1) throws {
        try P1CommandAuthorizationV1.validate(commandType: .goalAbandon, envelope: envelope)
        self.envelope = envelope
        self.goal = goal
        self.sessionBranch = sessionBranch
    }
    private enum CodingKeys: String, CodingKey { case goal, sessionBranch }
}

package struct FailGoalCommandV1: Sendable, Equatable, Encodable {
    package let envelope: CommandEnvelopeV1
    package let goal: GoalHeadV1
    package let sessionBranch: SessionBranchV1
    package init(envelope: CommandEnvelopeV1, goal: GoalHeadV1, sessionBranch: SessionBranchV1) throws {
        try P1CommandAuthorizationV1.validate(commandType: .goalFail, envelope: envelope)
        self.envelope = envelope
        self.goal = goal
        self.sessionBranch = sessionBranch
    }
    private enum CodingKeys: String, CodingKey { case goal, sessionBranch }
}

package struct CoachSessionSnapshotV1: Sendable, Equatable {
    package let goal: GoalControllerRecord
    package let session: CoachSessionRecord
    package let openQuestion: CoachQuestionRecord?
    package let currentUnderstanding: UnderstandingCardVersionRecord?
}

package struct CoachQuestionHistoryEntryV1: Sendable, Equatable {
    package let questionId: String
    package let decisionKey: String
    package let prompt: String
    package let recommendation: String
    package let reason: String
    package let answer: CoachAnswerV1?
    package let state: CoachQuestionStateV1
    package let createdAt: Date
    package let answeredAt: Date?
}

package struct CoachUnderstandingHistoryEntryV1: Sendable, Equatable {
    package let understandingId: String
    package let version: Int
    package let content: UnderstandingContentV1
    package let status: UnderstandingStatusV1
    package let contentHash: String
    package let createdAt: Date
    package let confirmedAt: Date?
}

package struct CoachTurnProviderRequestV1: Sendable, Equatable {
    package let schemaVersion: Int
    package let workId: String
    package let attempt: Int
    package let goalId: String
    package let sessionId: String
    package let nextQuestionId: String
    package let decisionKey: String
    package let failureScope: CoachFailureScopeV1
    package let goalTitle: String
    package let goalRawIntent: String
    package let confirmedUnderstanding: UnderstandingHeadV1?
    package let understandingHistory: [CoachUnderstandingHistoryEntryV1]
    package let questionHistory: [CoachQuestionHistoryEntryV1]
}

package enum CoachTurnProviderOutcomeV1: Sendable, Equatable {
    case question(prompt: String, recommendation: String, reason: String)
    case understanding(UnderstandingContentV1)
    case failed(ControlWorkerProviderFailureV1)
    case canceled
}

package typealias CoachTurnProviderV1 =
    @Sendable (CoachTurnProviderRequestV1) async -> CoachTurnProviderOutcomeV1

package struct CoachSessionAlreadyExistsError: Error, Sendable, Equatable {
    package init() {}
}
package struct CoachSessionIntegrityError: Error, Sendable, Equatable {
    package init() {}
}
package struct CoachSessionNotFoundError: Error, Sendable, Equatable {
    package init() {}
}
package struct CoachProjectionVersionConflictError: Error, Sendable, Equatable {
    package init() {}
}
