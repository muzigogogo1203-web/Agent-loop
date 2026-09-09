import Foundation
import GRDB

package enum CampSafeRefKindV1: String, Codable, Sendable, Equatable, CaseIterable, Comparable {
    case input
    case goal
    case coachSession
    case currentCoachQuestion
    case nextCoachQuestion
    case understanding
    case durableWork
    case engineExecution
    case engineTerminalProposal

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .input: 0
        case .goal: 1
        case .coachSession: 2
        case .currentCoachQuestion: 3
        case .nextCoachQuestion: 4
        case .understanding: 5
        case .durableWork: 6
        case .engineExecution: 7
        case .engineTerminalProposal: 8
        }
    }
}

package enum CampSafeHashKindV1: String, Codable, Sendable, Equatable, CaseIterable, Comparable {
    case commandPayload
    case inputContent
    case understandingContent
    case durableWorkInput
    case engineRequest
    case engineTerminalProposal

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .commandPayload: 0
        case .inputContent: 1
        case .understandingContent: 2
        case .durableWorkInput: 3
        case .engineRequest: 4
        case .engineTerminalProposal: 5
        }
    }
}

package enum CampSafeVersionKindV1: String, Codable, Sendable, Equatable, CaseIterable, Comparable {
    case inputProjection
    case goalProjection
    case coachSessionProjection
    case understandingContent
    case durableWork
    case inputEvent
    case goalEvent
    case coachSessionEvent
    case understandingEvent
    case engineExecutionProjection
    case engineTerminalProposalProjection
    case engineExecutionEvent

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .inputProjection: 0
        case .goalProjection: 1
        case .coachSessionProjection: 2
        case .understandingContent: 3
        case .durableWork: 4
        case .inputEvent: 5
        case .goalEvent: 6
        case .coachSessionEvent: 7
        case .understandingEvent: 8
        case .engineExecutionProjection: 9
        case .engineTerminalProposalProjection: 10
        case .engineExecutionEvent: 11
        }
    }
}

package enum CampSafeCountKindV1: String, Codable, Sendable, Equatable, CaseIterable, Comparable {
    case domainEvent
    case outbox
    case candidateCamp
    case coachQuestion
    case attempt

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .domainEvent: 0
        case .outbox: 1
        case .candidateCamp: 2
        case .coachQuestion: 3
        case .attempt: 4
        }
    }
}

package enum CampSafeTimeKindV1: String, Codable, Sendable, Equatable, CaseIterable, Comparable {
    case capturedAt
    case occurredAt
    case deletedAt
    case confirmedAt
    case notBefore

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .capturedAt: 0
        case .occurredAt: 1
        case .deletedAt: 2
        case .confirmedAt: 3
        case .notBefore: 4
        }
    }
}

package struct CampSafeRefV1: Sendable, Equatable, Codable {
    package let kind: CampSafeRefKindV1
    package let id: String

    package init(kind: CampSafeRefKindV1, id: String) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        self.kind = kind
        self.id = id
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case kind
        case id
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            kind: container.decode(CampSafeRefKindV1.self, forKey: .kind),
            id: container.decode(String.self, forKey: .id)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(id, forKey: .id)
    }
}

package struct CampSafeHashV1: Sendable, Equatable, Codable {
    package let kind: CampSafeHashKindV1
    package let hash: String

    package init(kind: CampSafeHashKindV1, hash: String) throws {
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        self.kind = kind
        self.hash = hash
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case kind
        case hash
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            kind: container.decode(CampSafeHashKindV1.self, forKey: .kind),
            hash: container.decode(String.self, forKey: .hash)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(hash, forKey: .hash)
    }
}

package struct CampSafeVersionV1: Sendable, Equatable, Codable {
    package let kind: CampSafeVersionKindV1
    package let value: Int

    package init(kind: CampSafeVersionKindV1, value: Int) throws {
        try CanonicalContractCodingV1.validatePositive(value)
        self.kind = kind
        self.value = value
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case kind
        case value
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            kind: container.decode(CampSafeVersionKindV1.self, forKey: .kind),
            value: container.decode(Int.self, forKey: .value)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(value, forKey: .value)
    }
}

package struct CampSafeCountV1: Sendable, Equatable, Codable {
    package let kind: CampSafeCountKindV1
    package let value: Int

    package init(kind: CampSafeCountKindV1, value: Int) throws {
        try CanonicalContractCodingV1.validateNonnegative(value)
        self.kind = kind
        self.value = value
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case kind
        case value
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            kind: container.decode(CampSafeCountKindV1.self, forKey: .kind),
            value: container.decode(Int.self, forKey: .value)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(value, forKey: .value)
    }
}

package struct CampSafeTimeV1: Sendable, Equatable, Codable {
    package let kind: CampSafeTimeKindV1
    package let value: Date

    package init(kind: CampSafeTimeKindV1, value: Date) throws {
        try CanonicalContractCodingV1.validateFinite(value)
        self.kind = kind
        self.value = value
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case kind
        case value
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            kind: container.decode(CampSafeTimeKindV1.self, forKey: .kind),
            value: container.decode(Date.self, forKey: .value)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(value, forKey: .value)
    }
}

package enum P1ResultBranchV1: String, Sendable, Equatable, CaseIterable {
    case captureInput
    case commitInputParse
    case retryInputParse
    case failInputParse
    case requeueInputParsing
    case cancelInputParsingAndDelete
    case requestCampAssignment
    case recordCampAmbiguity
    case assignCamp
    case archiveInput
    case markInputCoaching
    case convertInputToGoal
    case requestInputDeletion
    case completeInputDeletion
    case openCoachSession
    case recordCoachQuestion
    case answerCoachQuestion
    case proposeUnderstanding
    case requestConfirmation
    case confirmUnderstanding
    case requestRevisionUnconfirmed
    case requestRevisionConfirmed
    case coachFailureRetryClarifying
    case coachFailureRetryReady
    case coachFailureTerminalClarifying
    case coachFailureTerminalReady
    case abandonGoalWithoutSession
    case abandonGoalWithSession
    case failGoalWithoutSession
    case failGoalWithSession
    case beginEngineExecution
    case startEngineDispatch
    case requestEngineCancellation
    case acceptEngineEvent
    case recordEngineTerminalProposal
    case commitEngineTerminal
    case commitEngineTerminalWithAttention
}

package struct P1EventContractV1: Sendable, Equatable {
    package let ordinal: Int
    package let aggregateType: P1AggregateTypeV1
    package let eventType: P1EventTypeV1
    package let auditCode: P1AuditCodeV1
}

package struct P1ResultContractV1: Sendable, Equatable {
    package let branch: P1ResultBranchV1
    package let resultCode: P1ResultCodeV1
    package let refs: [CampSafeRefKindV1]
    package let hashes: [CampSafeHashKindV1]
    package let versions: [CampSafeVersionKindV1]
    package let counts: [CampSafeCountKindV1]
    package let times: [CampSafeTimeKindV1]
    package let events: [P1EventContractV1]

    package var eventCount: Int { events.count }
}

package enum P1CommandContractCatalogV1 {
    package static let allResultContracts: [P1ResultContractV1] = [
        input(.captureInput, .inputCaptured, .inputCaptured, .inputCaptured,
              work: true),
        input(.commitInputParse, .inputParseCommitted, .inputParseCommitted,
              .inputParseCommitted, work: true),
        input(.retryInputParse, .inputParseRetryScheduled,
              .inputParseAttemptFailed, .inputParseRetryScheduled,
              work: true, notBefore: true),
        input(.failInputParse, .inputParseFailed, .inputParseAttemptFailed,
              .inputParseFailed, work: true),
        input(.requeueInputParsing, .inputParsingRequeued,
              .inputParsingRequeued, .inputParsingRequeued, work: true),
        input(.cancelInputParsingAndDelete, .inputDeleted, .inputDeleted,
              .inputDeleted, work: true, deletedAt: true),
        input(.requestCampAssignment, .inputCampAssignmentRequired,
              .inputCampAssignmentRequired, .inputCampAssignmentRequired),
        input(.recordCampAmbiguity, .inputCampAmbiguous,
              .inputCampAmbiguityRecorded, .inputCampAmbiguous),
        input(.assignCamp, .inputCampAssigned, .inputCampAssigned,
              .inputCampAssigned),
        input(.archiveInput, .inputArchived, .inputArchived, .inputArchived),
        input(.markInputCoaching, .inputCoaching, .inputCoachingStarted,
              .inputCoaching),
        contract(
            .convertInputToGoal, .goalCreated,
            refs: [.input, .goal],
            hashes: [.commandPayload, .inputContent],
            versions: [.inputProjection, .goalProjection, .inputEvent, .goalEvent],
            counts: [.domainEvent, .outbox, .candidateCamp],
            times: [.capturedAt, .occurredAt],
            events: [
                (.input, .inputGoalCreated, .inputGoalCreated),
                (.goal, .goalCreated, .goalCreated),
            ]
        ),
        input(.requestInputDeletion, .inputDeletionRequested,
              .inputDeletionRequested, .inputDeletionRequested),
        input(.completeInputDeletion, .inputDeleted, .inputDeleted,
              .inputDeleted, deletedAt: true),
        coach(
            .openCoachSession, .coachSessionOpened,
            refs: [.goal, .coachSession, .nextCoachQuestion, .durableWork],
            work: true, event: .coachSessionOpened, audit: .coachSessionOpened
        ),
        coach(
            .recordCoachQuestion, .coachQuestionRecorded,
            refs: [.goal, .coachSession, .currentCoachQuestion, .durableWork],
            work: true, event: .coachQuestionRecorded, audit: .coachQuestionRecorded
        ),
        coach(
            .answerCoachQuestion, .coachQuestionAnswered,
            refs: [.goal, .coachSession, .currentCoachQuestion,
                   .nextCoachQuestion, .durableWork],
            work: true, event: .coachQuestionAnswered, audit: .coachQuestionAnswered
        ),
        understanding(
            .proposeUnderstanding, .coachUnderstandingProposed,
            work: true,
            nextQuestion: false,
            events: [
                (.coachSession, .coachUnderstandingProposed,
                 .coachUnderstandingProposed),
                (.understanding, .understandingProposed,
                 .coachUnderstandingProposed),
            ]
        ),
        understanding(
            .requestConfirmation, .coachConfirmationRequested,
            work: false,
            events: [
                (.coachSession, .coachConfirmationRequested,
                 .coachConfirmationRequested),
                (.understanding, .understandingConfirmationRequested,
                 .coachConfirmationRequested),
            ]
        ),
        contract(
            .confirmUnderstanding, .goalReady,
            refs: [.goal, .coachSession, .understanding],
            hashes: [.commandPayload, .understandingContent],
            versions: [.goalProjection, .coachSessionProjection,
                       .understandingContent, .goalEvent,
                       .coachSessionEvent, .understandingEvent],
            counts: [.domainEvent, .outbox, .coachQuestion],
            times: [.occurredAt, .confirmedAt],
            events: [
                (.coachSession, .coachUnderstandingConfirmed,
                 .coachUnderstandingConfirmed),
                (.understanding, .understandingConfirmed,
                 .coachUnderstandingConfirmed),
                (.goal, .goalReady, .goalReady),
            ]
        ),
        understanding(
            .requestRevisionUnconfirmed, .coachRevisionRequested,
            work: true,
            nextQuestion: true,
            events: [
                (.coachSession, .coachUnderstandingRevisionRequested,
                 .coachRevisionRequested),
                (.understanding, .understandingWithdrawn,
                 .understandingWithdrawn),
            ]
        ),
        understanding(
            .requestRevisionConfirmed, .coachRevisionRequested,
            work: true,
            nextQuestion: true,
            events: [
                (.coachSession, .coachUnderstandingRevisionRequested,
                 .coachRevisionRequested),
            ]
        ),
        coachFailure(
            .coachFailureRetryClarifying, .coachWorkRetryScheduled,
            ready: false, notBefore: true, terminalGoal: false
        ),
        coachFailure(
            .coachFailureRetryReady, .coachWorkRetryScheduled,
            ready: true, notBefore: true, terminalGoal: false
        ),
        coachFailure(
            .coachFailureTerminalClarifying, .coachWorkFailed,
            ready: false, notBefore: false, terminalGoal: true
        ),
        coachFailure(
            .coachFailureTerminalReady, .coachWorkFailed,
            ready: true, notBefore: false, terminalGoal: false
        ),
        goalTerminal(
            .abandonGoalWithoutSession, .goalAbandoned,
            session: false, failed: false
        ),
        goalTerminal(
            .abandonGoalWithSession, .goalAbandoned,
            session: true, failed: false
        ),
        goalTerminal(
            .failGoalWithoutSession, .goalFailed,
            session: false, failed: true
        ),
        goalTerminal(
            .failGoalWithSession, .goalFailed,
            session: true, failed: true
        ),
        engine(
            .beginEngineExecution, .engineExecutionBegan,
            event: .engineExecutionBegan, audit: .engineExecutionBegan
        ),
        engine(
            .startEngineDispatch, .engineDispatchStarted,
            event: .engineDispatchStarted, audit: .engineDispatchStarted
        ),
        engine(
            .requestEngineCancellation, .engineCancellationRequested,
            event: .engineCancellationRequested,
            audit: .engineCancellationRequested
        ),
        engine(
            .acceptEngineEvent, .engineEventAccepted,
            event: .engineEventAccepted, audit: .engineEventAccepted
        ),
        engine(
            .recordEngineTerminalProposal, .engineTerminalProposed,
            proposal: true,
            event: .engineTerminalProposed, audit: .engineTerminalProposed
        ),
        engine(
            .commitEngineTerminal, .engineTerminalCommitted,
            proposal: true,
            event: .engineTerminalCommitted, audit: .engineTerminalCommitted
        ),
        contract(
            .commitEngineTerminalWithAttention, .engineTerminalCommitted,
            refs: [.engineExecution, .engineTerminalProposal],
            hashes: [
                .commandPayload, .engineRequest, .engineTerminalProposal,
            ],
            versions: [
                .engineExecutionProjection,
                .engineTerminalProposalProjection,
                .engineExecutionEvent,
            ],
            counts: [.domainEvent, .outbox],
            times: [.occurredAt],
            events: [
                (
                    .engineExecution, .engineTerminalCommitted,
                    .engineTerminalCommitted
                ),
                (
                    .engineExecution, .engineAttentionIntent,
                    .engineAttentionIntent
                ),
            ]
        ),
    ]

    package static func contract(
        for branch: P1ResultBranchV1
    ) throws -> P1ResultContractV1 {
        guard let value = allResultContracts.first(where: { $0.branch == branch }) else {
            throw P1ContractValidationError.invalidMembership
        }
        return value
    }

    private static func contract(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        refs: [CampSafeRefKindV1],
        hashes: [CampSafeHashKindV1],
        versions: [CampSafeVersionKindV1],
        counts: [CampSafeCountKindV1],
        times: [CampSafeTimeKindV1],
        events: [(P1AggregateTypeV1, P1EventTypeV1, P1AuditCodeV1)]
    ) -> P1ResultContractV1 {
        P1ResultContractV1(
            branch: branch,
            resultCode: resultCode,
            refs: refs.sorted(),
            hashes: hashes.sorted(),
            versions: versions.sorted(),
            counts: counts.sorted(),
            times: times.sorted(),
            events: events.enumerated().map { index, value in
                P1EventContractV1(
                    ordinal: index,
                    aggregateType: value.0,
                    eventType: value.1,
                    auditCode: value.2
                )
            }
        )
    }

    private static func input(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        _ eventType: P1EventTypeV1,
        _ auditCode: P1AuditCodeV1,
        work: Bool = false,
        deletedAt: Bool = false,
        notBefore: Bool = false
    ) -> P1ResultContractV1 {
        var refs: [CampSafeRefKindV1] = [.input]
        var hashes: [CampSafeHashKindV1] = [.commandPayload, .inputContent]
        var versions: [CampSafeVersionKindV1] = [
            .inputProjection, .inputEvent,
        ]
        var counts: [CampSafeCountKindV1] = [
            .domainEvent, .outbox, .candidateCamp,
        ]
        var times: [CampSafeTimeKindV1] = [.capturedAt, .occurredAt]
        if work {
            refs.append(.durableWork)
            hashes.append(.durableWorkInput)
            versions.append(.durableWork)
            counts.append(.attempt)
        }
        if deletedAt { times.append(.deletedAt) }
        if notBefore { times.append(.notBefore) }
        return contract(
            branch, resultCode, refs: refs, hashes: hashes,
            versions: versions, counts: counts, times: times,
            events: [(.input, eventType, auditCode)]
        )
    }

    private static func coach(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        refs: [CampSafeRefKindV1],
        work: Bool,
        event: P1EventTypeV1,
        audit: P1AuditCodeV1
    ) -> P1ResultContractV1 {
        var hashes: [CampSafeHashKindV1] = [.commandPayload]
        var versions: [CampSafeVersionKindV1] = [
            .goalProjection, .coachSessionProjection, .coachSessionEvent,
        ]
        var counts: [CampSafeCountKindV1] = [
            .domainEvent, .outbox, .coachQuestion,
        ]
        if work {
            hashes.append(.durableWorkInput)
            versions.append(.durableWork)
            counts.append(.attempt)
        }
        return contract(
            branch, resultCode, refs: refs, hashes: hashes,
            versions: versions, counts: counts, times: [.occurredAt],
            events: [(.coachSession, event, audit)]
        )
    }

    private static func understanding(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        work: Bool,
        nextQuestion: Bool = false,
        events: [(P1AggregateTypeV1, P1EventTypeV1, P1AuditCodeV1)]
    ) -> P1ResultContractV1 {
        var refs: [CampSafeRefKindV1] = [
            .goal, .coachSession, .understanding,
        ]
        var hashes: [CampSafeHashKindV1] = [
            .commandPayload, .understandingContent,
        ]
        var versions: [CampSafeVersionKindV1] = [
            .goalProjection, .coachSessionProjection, .understandingContent,
            .coachSessionEvent, .understandingEvent,
        ]
        var counts: [CampSafeCountKindV1] = [
            .domainEvent, .outbox, .coachQuestion,
        ]
        if work {
            refs.append(.durableWork)
            hashes.append(.durableWorkInput)
            versions.append(.durableWork)
            counts.append(.attempt)
        }
        if nextQuestion {
            refs.append(.nextCoachQuestion)
        }
        return contract(
            branch, resultCode, refs: refs, hashes: hashes,
            versions: versions, counts: counts, times: [.occurredAt],
            events: events
        )
    }

    private static func coachFailure(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        ready: Bool,
        notBefore: Bool,
        terminalGoal: Bool
    ) -> P1ResultContractV1 {
        var refs: [CampSafeRefKindV1] = [.goal, .coachSession, .durableWork]
        var hashes: [CampSafeHashKindV1] = [.commandPayload, .durableWorkInput]
        var versions: [CampSafeVersionKindV1] = [
            .goalProjection, .coachSessionProjection, .durableWork,
            .coachSessionEvent,
        ]
        let counts: [CampSafeCountKindV1] = [
            .domainEvent, .outbox, .coachQuestion, .attempt,
        ]
        var times: [CampSafeTimeKindV1] = [.occurredAt]
        if ready {
            refs.append(.understanding)
            hashes.append(.understandingContent)
            versions.append(.understandingContent)
            versions.append(.understandingEvent)
        }
        var events: [(P1AggregateTypeV1, P1EventTypeV1, P1AuditCodeV1)] = [
            (.coachSession, ready || terminalGoal
                ? .coachSessionFailed : .coachWorkAttemptFailed,
             resultCode == .coachWorkRetryScheduled
                ? .coachWorkRetryScheduled : .coachWorkFailed),
        ]
        if resultCode == .coachWorkRetryScheduled {
            events[0] = (
                .coachSession, .coachWorkAttemptFailed,
                .coachWorkRetryScheduled
            )
        }
        if terminalGoal {
            versions.append(.goalEvent)
            events.append((.goal, .goalFailed, .goalFailed))
        }
        if notBefore { times.append(.notBefore) }
        return contract(
            branch, resultCode, refs: refs, hashes: hashes,
            versions: versions, counts: counts, times: times, events: events
        )
    }

    private static func goalTerminal(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        session: Bool,
        failed: Bool
    ) -> P1ResultContractV1 {
        var refs: [CampSafeRefKindV1] = [.goal]
        var versions: [CampSafeVersionKindV1] = [.goalProjection, .goalEvent]
        var counts: [CampSafeCountKindV1] = [.domainEvent, .outbox]
        var events: [(P1AggregateTypeV1, P1EventTypeV1, P1AuditCodeV1)] = []
        if session {
            refs.append(.coachSession)
            versions.append(.coachSessionProjection)
            versions.append(.coachSessionEvent)
            counts.append(.coachQuestion)
            events.append((
                .coachSession,
                failed ? .coachSessionFailed : .coachSessionAbandoned,
                failed ? .goalFailed : .goalAbandoned
            ))
        }
        events.append((
            .goal,
            failed ? .goalFailed : .goalAbandoned,
            failed ? .goalFailed : .goalAbandoned
        ))
        return contract(
            branch, resultCode, refs: refs, hashes: [.commandPayload],
            versions: versions, counts: counts, times: [.occurredAt],
            events: events
        )
    }

    private static func engine(
        _ branch: P1ResultBranchV1,
        _ resultCode: P1ResultCodeV1,
        proposal: Bool = false,
        event: P1EventTypeV1,
        audit: P1AuditCodeV1
    ) -> P1ResultContractV1 {
        var refs: [CampSafeRefKindV1] = [.engineExecution]
        var hashes: [CampSafeHashKindV1] = [
            .commandPayload, .engineRequest,
        ]
        var versions: [CampSafeVersionKindV1] = [
            .engineExecutionProjection, .engineExecutionEvent,
        ]
        if proposal {
            refs.append(.engineTerminalProposal)
            hashes.append(.engineTerminalProposal)
            versions.append(.engineTerminalProposalProjection)
        }
        return contract(
            branch, resultCode,
            refs: refs,
            hashes: hashes,
            versions: versions,
            counts: [.domainEvent, .outbox],
            times: [.occurredAt],
            events: [(.engineExecution, event, audit)]
        )
    }
}

package struct CampSafeResultValuesV1: Sendable {
    package let commandPayloadHash: String
    package let domainEventCount: Int
    package let outboxCount: Int
    package let occurredAt: Date
    package let inputId: String?
    package let goalId: String?
    package let coachSessionId: String?
    package let currentCoachQuestionId: String?
    package let nextCoachQuestionId: String?
    package let understandingId: String?
    package let durableWorkId: String?
    package let engineExecutionId: String?
    package let engineTerminalProposalId: String?
    package let inputContentHash: String?
    package let understandingContentHash: String?
    package let durableWorkInputHash: String?
    package let engineRequestHash: String?
    package let engineTerminalProposalHash: String?
    package let inputProjectionVersion: Int?
    package let goalProjectionVersion: Int?
    package let coachSessionProjectionVersion: Int?
    package let understandingContentVersion: Int?
    package let durableWorkVersion: Int?
    package let inputEventVersion: Int?
    package let goalEventVersion: Int?
    package let coachSessionEventVersion: Int?
    package let understandingEventVersion: Int?
    package let engineExecutionProjectionVersion: Int?
    package let engineTerminalProposalProjectionVersion: Int?
    package let engineExecutionEventVersion: Int?
    package let candidateCampCount: Int?
    package let coachQuestionCount: Int?
    package let attemptCount: Int?
    package let capturedAt: Date?
    package let deletedAt: Date?
    package let confirmedAt: Date?
    package let notBefore: Date?

    package init(
        commandPayloadHash: String,
        domainEventCount: Int,
        outboxCount: Int,
        occurredAt: Date,
        inputId: String? = nil,
        goalId: String? = nil,
        coachSessionId: String? = nil,
        currentCoachQuestionId: String? = nil,
        nextCoachQuestionId: String? = nil,
        understandingId: String? = nil,
        durableWorkId: String? = nil,
        engineExecutionId: String? = nil,
        engineTerminalProposalId: String? = nil,
        inputContentHash: String? = nil,
        understandingContentHash: String? = nil,
        durableWorkInputHash: String? = nil,
        engineRequestHash: String? = nil,
        engineTerminalProposalHash: String? = nil,
        inputProjectionVersion: Int? = nil,
        goalProjectionVersion: Int? = nil,
        coachSessionProjectionVersion: Int? = nil,
        understandingContentVersion: Int? = nil,
        durableWorkVersion: Int? = nil,
        inputEventVersion: Int? = nil,
        goalEventVersion: Int? = nil,
        coachSessionEventVersion: Int? = nil,
        understandingEventVersion: Int? = nil,
        engineExecutionProjectionVersion: Int? = nil,
        engineTerminalProposalProjectionVersion: Int? = nil,
        engineExecutionEventVersion: Int? = nil,
        candidateCampCount: Int? = nil,
        coachQuestionCount: Int? = nil,
        attemptCount: Int? = nil,
        capturedAt: Date? = nil,
        deletedAt: Date? = nil,
        confirmedAt: Date? = nil,
        notBefore: Date? = nil
    ) {
        self.commandPayloadHash = commandPayloadHash
        self.domainEventCount = domainEventCount
        self.outboxCount = outboxCount
        self.occurredAt = occurredAt
        self.inputId = inputId
        self.goalId = goalId
        self.coachSessionId = coachSessionId
        self.currentCoachQuestionId = currentCoachQuestionId
        self.nextCoachQuestionId = nextCoachQuestionId
        self.understandingId = understandingId
        self.durableWorkId = durableWorkId
        self.engineExecutionId = engineExecutionId
        self.engineTerminalProposalId = engineTerminalProposalId
        self.inputContentHash = inputContentHash
        self.understandingContentHash = understandingContentHash
        self.durableWorkInputHash = durableWorkInputHash
        self.engineRequestHash = engineRequestHash
        self.engineTerminalProposalHash = engineTerminalProposalHash
        self.inputProjectionVersion = inputProjectionVersion
        self.goalProjectionVersion = goalProjectionVersion
        self.coachSessionProjectionVersion = coachSessionProjectionVersion
        self.understandingContentVersion = understandingContentVersion
        self.durableWorkVersion = durableWorkVersion
        self.inputEventVersion = inputEventVersion
        self.goalEventVersion = goalEventVersion
        self.coachSessionEventVersion = coachSessionEventVersion
        self.understandingEventVersion = understandingEventVersion
        self.engineExecutionProjectionVersion =
            engineExecutionProjectionVersion
        self.engineTerminalProposalProjectionVersion =
            engineTerminalProposalProjectionVersion
        self.engineExecutionEventVersion = engineExecutionEventVersion
        self.candidateCampCount = candidateCampCount
        self.coachQuestionCount = coachQuestionCount
        self.attemptCount = attemptCount
        self.capturedAt = capturedAt
        self.deletedAt = deletedAt
        self.confirmedAt = confirmedAt
        self.notBefore = notBefore
    }

    fileprivate func ref(_ kind: CampSafeRefKindV1) -> String? {
        switch kind {
        case .input: inputId
        case .goal: goalId
        case .coachSession: coachSessionId
        case .currentCoachQuestion: currentCoachQuestionId
        case .nextCoachQuestion: nextCoachQuestionId
        case .understanding: understandingId
        case .durableWork: durableWorkId
        case .engineExecution: engineExecutionId
        case .engineTerminalProposal: engineTerminalProposalId
        }
    }

    fileprivate func hash(_ kind: CampSafeHashKindV1) -> String? {
        switch kind {
        case .commandPayload: commandPayloadHash
        case .inputContent: inputContentHash
        case .understandingContent: understandingContentHash
        case .durableWorkInput: durableWorkInputHash
        case .engineRequest: engineRequestHash
        case .engineTerminalProposal: engineTerminalProposalHash
        }
    }

    fileprivate func version(_ kind: CampSafeVersionKindV1) -> Int? {
        switch kind {
        case .inputProjection: inputProjectionVersion
        case .goalProjection: goalProjectionVersion
        case .coachSessionProjection: coachSessionProjectionVersion
        case .understandingContent: understandingContentVersion
        case .durableWork: durableWorkVersion
        case .inputEvent: inputEventVersion
        case .goalEvent: goalEventVersion
        case .coachSessionEvent: coachSessionEventVersion
        case .understandingEvent: understandingEventVersion
        case .engineExecutionProjection: engineExecutionProjectionVersion
        case .engineTerminalProposalProjection:
            engineTerminalProposalProjectionVersion
        case .engineExecutionEvent: engineExecutionEventVersion
        }
    }

    fileprivate func count(_ kind: CampSafeCountKindV1) -> Int? {
        switch kind {
        case .domainEvent: domainEventCount
        case .outbox: outboxCount
        case .candidateCamp: candidateCampCount
        case .coachQuestion: coachQuestionCount
        case .attempt: attemptCount
        }
    }

    fileprivate func time(_ kind: CampSafeTimeKindV1) -> Date? {
        switch kind {
        case .capturedAt: capturedAt
        case .occurredAt: occurredAt
        case .deletedAt: deletedAt
        case .confirmedAt: confirmedAt
        case .notBefore: notBefore
        }
    }
}

package struct CampSafeCommandResultV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let code: P1ResultCodeV1
    package let refs: [CampSafeRefV1]
    package let hashes: [CampSafeHashV1]
    package let versions: [CampSafeVersionV1]
    package let counts: [CampSafeCountV1]
    package let times: [CampSafeTimeV1]

    package static func make(
        branch: P1ResultBranchV1,
        values: CampSafeResultValuesV1
    ) throws -> Self {
        let contract = try P1CommandContractCatalogV1.contract(for: branch)
        guard values.domainEventCount == contract.eventCount,
              values.outboxCount == contract.eventCount
        else {
            throw P1ContractValidationError.invalidMembership
        }
        try requireExactPresence(contract.refs, all: CampSafeRefKindV1.allCases) {
            values.ref($0)
        }
        try requireExactPresence(contract.hashes, all: CampSafeHashKindV1.allCases) {
            values.hash($0)
        }
        try requireExactPresence(contract.versions, all: CampSafeVersionKindV1.allCases) {
            values.version($0)
        }
        try requireExactPresence(contract.counts, all: CampSafeCountKindV1.allCases) {
            values.count($0)
        }
        try requireExactPresence(contract.times, all: CampSafeTimeKindV1.allCases) {
            values.time($0)
        }
        return try Self(
            schemaVersion: 1,
            code: contract.resultCode,
            refs: contract.refs.map {
                try CampSafeRefV1(kind: $0, id: require(values.ref($0)))
            },
            hashes: contract.hashes.map {
                try CampSafeHashV1(kind: $0, hash: require(values.hash($0)))
            },
            versions: contract.versions.map {
                try CampSafeVersionV1(kind: $0, value: require(values.version($0)))
            },
            counts: contract.counts.map {
                try CampSafeCountV1(kind: $0, value: require(values.count($0)))
            },
            times: contract.times.map {
                try CampSafeTimeV1(kind: $0, value: require(values.time($0)))
            }
        )
    }

    private init(
        schemaVersion: Int,
        code: P1ResultCodeV1,
        refs: [CampSafeRefV1],
        hashes: [CampSafeHashV1],
        versions: [CampSafeVersionV1],
        counts: [CampSafeCountV1],
        times: [CampSafeTimeV1]
    ) throws {
        guard schemaVersion == 1 else {
            throw P1ContractValidationError.invalidSchemaVersion
        }
        try Self.validateOrderedUnique(refs.map(\.kind))
        try Self.validateOrderedUnique(hashes.map(\.kind))
        try Self.validateOrderedUnique(versions.map(\.kind))
        try Self.validateOrderedUnique(counts.map(\.kind))
        try Self.validateOrderedUnique(times.map(\.kind))
        let matches = P1CommandContractCatalogV1.allResultContracts.filter {
            $0.resultCode == code
                && $0.refs == refs.map(\.kind)
                && $0.hashes == hashes.map(\.kind)
                && $0.versions == versions.map(\.kind)
                && $0.counts == counts.map(\.kind)
                && $0.times == times.map(\.kind)
        }
        guard !matches.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }
        guard count(.domainEvent, in: counts) == count(.outbox, in: counts),
              matches.contains(where: {
                  $0.eventCount == count(.domainEvent, in: counts)
              })
        else {
            throw P1ContractValidationError.invalidMembership
        }
        self.schemaVersion = schemaVersion
        self.code = code
        self.refs = refs
        self.hashes = hashes
        self.versions = versions
        self.counts = counts
        self.times = times
    }

    fileprivate func value(_ kind: CampSafeVersionKindV1) -> Int? {
        versions.first(where: { $0.kind == kind })?.value
    }

    fileprivate func countValue(_ kind: CampSafeCountKindV1) -> Int? {
        counts.first(where: { $0.kind == kind })?.value
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case schemaVersion
        case code
        case refs
        case hashes
        case versions
        case counts
        case times
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases) else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            code: container.decode(P1ResultCodeV1.self, forKey: .code),
            refs: container.decode([CampSafeRefV1].self, forKey: .refs),
            hashes: container.decode([CampSafeHashV1].self, forKey: .hashes),
            versions: container.decode([CampSafeVersionV1].self, forKey: .versions),
            counts: container.decode([CampSafeCountV1].self, forKey: .counts),
            times: container.decode([CampSafeTimeV1].self, forKey: .times)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(code, forKey: .code)
        try container.encode(refs, forKey: .refs)
        try container.encode(hashes, forKey: .hashes)
        try container.encode(versions, forKey: .versions)
        try container.encode(counts, forKey: .counts)
        try container.encode(times, forKey: .times)
    }

    private static func validateOrderedUnique<Kind: Comparable & Hashable>(
        _ values: [Kind]
    ) throws {
        guard values == values.sorted(), Set(values).count == values.count else {
            throw P1ContractValidationError.duplicateKind
        }
    }
}

package struct CampSafeAuditPayloadV1: Sendable, Equatable, Codable {
    package let schemaVersion: Int
    package let code: P1AuditCodeV1
    package let refs: [CampSafeRefV1]
    package let hashes: [CampSafeHashV1]
    package let versions: [CampSafeVersionV1]
    package let counts: [CampSafeCountV1]
    package let times: [CampSafeTimeV1]

    fileprivate init(
        result: CampSafeCommandResultV1,
        code: P1AuditCodeV1
    ) {
        schemaVersion = 1
        self.code = code
        refs = result.refs
        hashes = result.hashes
        versions = result.versions
        counts = result.counts
        times = result.times
    }

    private enum CodingKeys: String, CodingKey, CaseIterable, Hashable {
        case schemaVersion
        case code
        case refs
        case hashes
        case versions
        case counts
        case times
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases),
              try container.decode(Int.self, forKey: .schemaVersion) == 1
        else {
            throw P1ContractValidationError.invalidKeys
        }
        schemaVersion = 1
        code = try container.decode(P1AuditCodeV1.self, forKey: .code)
        refs = try container.decode([CampSafeRefV1].self, forKey: .refs)
        hashes = try container.decode([CampSafeHashV1].self, forKey: .hashes)
        versions = try container.decode([CampSafeVersionV1].self, forKey: .versions)
        counts = try container.decode([CampSafeCountV1].self, forKey: .counts)
        times = try container.decode([CampSafeTimeV1].self, forKey: .times)
        guard refs.map(\.kind) == refs.map(\.kind).sorted(),
              Set(refs.map(\.kind)).count == refs.count,
              hashes.map(\.kind) == hashes.map(\.kind).sorted(),
              Set(hashes.map(\.kind)).count == hashes.count,
              versions.map(\.kind) == versions.map(\.kind).sorted(),
              Set(versions.map(\.kind)).count == versions.count,
              counts.map(\.kind) == counts.map(\.kind).sorted(),
              Set(counts.map(\.kind)).count == counts.count,
              times.map(\.kind) == times.map(\.kind).sorted(),
              Set(times.map(\.kind)).count == times.count,
              let domainEventCount = count(.domainEvent, in: counts),
              domainEventCount == count(.outbox, in: counts),
              P1CommandContractCatalogV1.allResultContracts.contains(where: {
                  $0.refs == refs.map(\.kind)
                      && $0.hashes == hashes.map(\.kind)
                      && $0.versions == versions.map(\.kind)
                      && $0.counts == counts.map(\.kind)
                      && $0.times == times.map(\.kind)
                      && $0.eventCount == domainEventCount
                      && $0.events.contains(where: { $0.auditCode == code })
              })
        else {
            throw P1ContractValidationError.invalidMembership
        }
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(code, forKey: .code)
        try container.encode(refs, forKey: .refs)
        try container.encode(hashes, forKey: .hashes)
        try container.encode(versions, forKey: .versions)
        try container.encode(counts, forKey: .counts)
        try container.encode(times, forKey: .times)
    }
}

private func requireExactPresence<Kind: CaseIterable & Hashable, Value>(
    _ expected: [Kind],
    all: Kind.AllCases,
    value: (Kind) -> Value?
) throws where Kind.AllCases: Collection {
    let expectedSet = Set(expected)
    for kind in all {
        guard (value(kind) != nil) == expectedSet.contains(kind) else {
            throw P1ContractValidationError.invalidMembership
        }
    }
}

private func require<Value>(_ value: Value?) throws -> Value {
    guard let value else {
        throw P1ContractValidationError.invalidMembership
    }
    return value
}

private func count(
    _ kind: CampSafeCountKindV1,
    in values: [CampSafeCountV1]
) -> Int? {
    values.first(where: { $0.kind == kind })?.value
}

package struct DomainEventReplayShapeV1: Sendable, Equatable {
    package let campId: String
    package let aggregateType: P1AggregateTypeV1
    package let aggregateId: String
    package let expectedAggregateVersion: Int
    package let eventType: P1EventTypeV1
    package let auditCode: P1AuditCodeV1

    package var aggregateVersion: Int {
        get throws {
            try CanonicalContractCodingV1.checkedIncrement(
                expectedAggregateVersion
            )
        }
    }
}

package struct DomainCommandReplayPlanV1: Sendable, Equatable {
    package let branch: P1ResultBranchV1
    package let commandType: P1CommandTypeV1
    package let shapes: [DomainEventReplayShapeV1]

    internal init(
        branch: P1ResultBranchV1,
        commandType: P1CommandTypeV1,
        shapes: [DomainEventReplayShapeV1]
    ) throws {
        let contract = try P1CommandContractCatalogV1.contract(for: branch)
        guard branch.commandType == commandType,
              shapes.count == contract.eventCount,
              shapes.count <= 10_000
        else {
            throw P1ContractValidationError.invalidMembership
        }
        var lastVersion: [String: Int] = [:]
        for (index, shape) in shapes.enumerated() {
            let expected = contract.events[index]
            guard shape.aggregateType == expected.aggregateType,
                  shape.eventType == expected.eventType,
                  shape.auditCode == expected.auditCode
            else {
                throw P1ContractValidationError.invalidMembership
            }
            try CanonicalContractCodingV1.validateCampID(shape.campId)
            try CanonicalContractCodingV1.validateCanonicalUUID(
                shape.aggregateId
            )
            try CanonicalContractCodingV1.validateNonnegative(
                shape.expectedAggregateVersion
            )
            _ = try shape.aggregateVersion
            let aggregateKey = "\(shape.aggregateType.rawValue):\(shape.aggregateId)"
            if let previous = lastVersion[aggregateKey] {
                let next = try CanonicalContractCodingV1.checkedIncrement(
                    previous
                )
                guard shape.expectedAggregateVersion == next else {
                    throw P1ContractValidationError.invalidMembership
                }
            }
            lastVersion[aggregateKey] = shape.expectedAggregateVersion
        }
        self.branch = branch
        self.commandType = commandType
        self.shapes = shapes
    }
}

package struct PreparedDomainCommandV1: Sendable, Equatable {
    package let commandType: P1CommandTypeV1
    package let envelope: CommandEnvelopeV1
    package let payloadBytes: Data
    package let commandPayloadHash: String
    package let eventCount: Int

    package static func make<Payload: Encodable>(
        commandType: P1CommandTypeV1,
        envelope: CommandEnvelopeV1,
        payload: Payload,
        replayPlan: DomainCommandReplayPlanV1
    ) throws -> Self {
        guard replayPlan.commandType == commandType else {
            throw P1ContractValidationError.invalidMembership
        }
        try P1CommandAuthorizationV1.validate(
            commandType: commandType,
            envelope: envelope
        )
        switch commandType {
        case .engineExecutionBegin, .engineDispatchStart,
             .engineCancellationRequest, .engineEventAccept,
             .engineTerminalProposalRecord, .engineTerminalCommit:
            guard replayPlan.shapes.allSatisfy({
                $0.aggregateType == .engineExecution
                    && $0.aggregateId == envelope.correlationId
            }) else {
                throw P1CommandAuthorizationError.forbiddenActor
            }
        default:
            break
        }
        let payloadBytes = try CanonicalContractCodingV1.encode(payload)
        let hash = try CanonicalContractCodingV1.wholeCommandHash(
            envelope: envelope,
            payload: payload
        )
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        return Self(
            commandType: commandType,
            envelope: envelope,
            payloadBytes: payloadBytes,
            commandPayloadHash: hash,
            eventCount: replayPlan.shapes.count
        )
    }

    package func resealed(
        occurredAt: Date
    ) throws -> PreparedDomainCommandV1 {
        let envelope = try CommandEnvelopeV1(
            idempotencyKey: self.envelope.idempotencyKey,
            actorType: self.envelope.actorType,
            actorId: self.envelope.actorId,
            deviceId: self.envelope.deviceId,
            correlationId: self.envelope.correlationId,
            causationId: self.envelope.causationId,
            occurredAt: occurredAt
        )
        let envelopeBytes = try CanonicalContractCodingV1.encode(envelope)
        var commandBytes = Data("{\"envelope\":".utf8)
        commandBytes.append(envelopeBytes)
        commandBytes.append(Data(",\"payload\":".utf8))
        commandBytes.append(payloadBytes)
        commandBytes.append(Data("}".utf8))
        try CanonicalJSONV1.validateCanonical(rawUTF8: commandBytes)
        let hash = CanonicalJSONV1.sha256Hex(commandBytes)
        try CanonicalContractCodingV1.validateLowercaseHash(hash)
        return Self(
            commandType: commandType,
            envelope: envelope,
            payloadBytes: payloadBytes,
            commandPayloadHash: hash,
            eventCount: eventCount
        )
    }
}

package struct NewDomainCommandV1: Sendable, Equatable {
    package let result: CampSafeCommandResultV1
    package let auditPayloads: [CampSafeAuditPayloadV1]

    package static func make(
        result: CampSafeCommandResultV1,
        replayPlan: DomainCommandReplayPlanV1
    ) throws -> Self {
        let contract = try P1CommandContractCatalogV1.contract(
            for: replayPlan.branch
        )
        guard result.code == contract.resultCode,
              result.refs.map(\.kind) == contract.refs,
              result.hashes.map(\.kind) == contract.hashes,
              result.versions.map(\.kind) == contract.versions,
              result.counts.map(\.kind) == contract.counts,
              result.times.map(\.kind) == contract.times,
              result.countValue(.domainEvent) == contract.eventCount,
              result.countValue(.outbox) == contract.eventCount
        else {
            throw DomainCommandContractError.invalidResult
        }
        var finalEventVersions: [String: (
            kind: CampSafeVersionKindV1,
            aggregateId: String,
            value: Int
        )] = [:]
        for shape in replayPlan.shapes {
            let kind: CampSafeVersionKindV1
            switch shape.aggregateType {
            case .input: kind = .inputEvent
            case .goal: kind = .goalEvent
            case .coachSession: kind = .coachSessionEvent
            case .understanding: kind = .understandingEvent
            case .engineExecution: kind = .engineExecutionEvent
            }
            let aggregateVersion = try shape.aggregateVersion
            if let existing = finalEventVersions[kind.rawValue],
               existing.aggregateId != shape.aggregateId
            {
                throw DomainCommandContractError.invalidResult
            }
            finalEventVersions[kind.rawValue] = (
                kind, shape.aggregateId, aggregateVersion
            )
        }
        for final in finalEventVersions.values {
            guard result.value(final.kind) == final.value else {
                throw DomainCommandContractError.invalidResult
            }
        }
        return Self(
            result: result,
            auditPayloads: contract.events.map {
                CampSafeAuditPayloadV1(result: result, code: $0.auditCode)
            }
        )
    }
}

package struct DomainCommandExecutionMetadataV1: Sendable, Equatable {
    package let result: CampSafeCommandResultV1
    package let resultHash: String
    package let eventIds: [String]
    package let wasReplay: Bool

    package init(
        result: CampSafeCommandResultV1,
        resultHash: String,
        eventIds: [String],
        wasReplay: Bool
    ) throws {
        try CanonicalContractCodingV1.validateLowercaseHash(resultHash)
        guard result.countValue(.domainEvent) == eventIds.count,
              Set(eventIds).count == eventIds.count
        else {
            throw DomainCommandGraphIntegrityError()
        }
        for eventId in eventIds {
            try CanonicalContractCodingV1.validateCanonicalUUID(eventId)
        }
        self.result = result
        self.resultHash = resultHash
        self.eventIds = eventIds
        self.wasReplay = wasReplay
    }
}

package struct PreparedDomainEventV1: Sendable, Equatable {
    package let campId: String
    package let aggregateType: P1AggregateTypeV1
    package let aggregateId: String
    package let expectedAggregateVersion: Int
    package let eventType: P1EventTypeV1
    package let payloadVersion: Int
    package let payload: CampSafeAuditPayloadV1
}

package enum DomainCommandContractError: Error, Sendable, Equatable {
    case invalidResult
    case invalidEvent
    case invalidTimestamp
}

package struct DomainCommandReplayConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainCommandGraphIntegrityError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainCommandCampUnavailableError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainCommandAggregateVersionError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainCommandReceiptRecordV1:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "domain_command_receipt"

    package var idempotencyKey: String
    package var commandType: P1CommandTypeV1
    package var commandPayloadHash: String
    package var eventCount: Int
    package var resultJson: String
    package var resultHash: String
    package var createdAt: Date
}

package struct DomainEventRecordV1:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "domain_event"

    package var id: String
    package var campId: String
    package var aggregateType: P1AggregateTypeV1
    package var aggregateId: String
    package var aggregateVersion: Int
    package var eventType: P1EventTypeV1
    package var payloadVersion: Int
    package var payloadJson: String
    package var payloadHash: String
    package var actorType: DomainActorType
    package var actorId: String
    package var deviceId: String?
    package var causationId: String?
    package var correlationId: String
    package var commandIdempotencyKey: String
    package var eventOrdinal: Int
    package var eventIdempotencyKey: String
    package var occurredAt: Date
    package var recordedAt: Date
}

package enum EventOutboxStateV1: String, Codable, Sendable, Equatable {
    case pending
    case dispatching
    case sent
    case failed
}

package struct EventOutboxRecordV1:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "event_outbox"

    package var eventId: String
    package var state: EventOutboxStateV1
    package var attempt: Int
    package var notBefore: Date?
    package var leaseOwner: String?
    package var leaseExpiresAt: Date?
    package var lastError: String?
    package var version: Int
    package var createdAt: Date
    package var updatedAt: Date
    package var sentAt: Date?
}

package enum InboxMessageStateV1: String, Codable, Sendable, Equatable {
    case received
    case applied
    case rejected
}

package struct DomainInboxEnvelopeV1: Sendable, Equatable {
    package let id: String
    package let campId: String?
    package let sourceDeviceId: String
    package let idempotencyKey: String
    package let payloadBytes: Data
    package let payloadHash: String
    package let receivedAt: Date

    package init(
        id: String,
        campId: String?,
        sourceDeviceId: String,
        idempotencyKey: String,
        payloadBytes: Data,
        receivedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        if let campId {
            try CanonicalContractCodingV1.validateCampID(campId)
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(sourceDeviceId)
        try CanonicalContractCodingV1.validateNonempty(idempotencyKey)
        try CanonicalJSONV1.validateCanonical(rawUTF8: payloadBytes)
        try CanonicalContractCodingV1.validateFinite(receivedAt)
        let payloadHash = CanonicalJSONV1.sha256Hex(payloadBytes)
        try CanonicalContractCodingV1.validateLowercaseHash(payloadHash)
        self.id = id
        self.campId = campId
        self.sourceDeviceId = sourceDeviceId
        self.idempotencyKey = idempotencyKey
        self.payloadBytes = payloadBytes
        self.payloadHash = payloadHash
        self.receivedAt = receivedAt
    }
}

package struct InboxMessageRecordV1:
    Codable, Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "inbox_message"

    package var id: String
    package var campId: String?
    package var sourceDeviceId: String
    package var idempotencyKey: String
    package var payloadJson: String
    package var payloadHash: String
    package var state: InboxMessageStateV1
    package var receivedAt: Date
    package var appliedAt: Date?
    package var errorCode: String?
    package var version: Int
    package var redactedAt: Date?

    package static func received(
        envelope: DomainInboxEnvelopeV1
    ) -> Self {
        Self(
            id: envelope.id,
            campId: envelope.campId,
            sourceDeviceId: envelope.sourceDeviceId,
            idempotencyKey: envelope.idempotencyKey,
            payloadJson: String(decoding: envelope.payloadBytes, as: UTF8.self),
            payloadHash: envelope.payloadHash,
            state: .received,
            receivedAt: envelope.receivedAt,
            appliedAt: nil,
            errorCode: nil,
            version: 1,
            redactedAt: nil
        )
    }
}

package struct DomainOutboxClaimV1: Sendable, Equatable {
    package var record: EventOutboxRecordV1
    package var workerId: String
    package var claimedVersion: Int
}

package struct DomainOutboxFailureV1: Sendable, Equatable {
    package let code: String
    package let message: String
    package let deterministic: Bool

    package init(code: String, message: String, deterministic: Bool) {
        self.code = code
        self.message = message
        self.deterministic = deterministic
    }
}

package struct DomainOutboxCASConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainInboxHandlerRejection: Error, Sendable, Equatable {
    package let code: String

    package init(code: String) {
        self.code = code
    }
}

package struct DomainInboxIntegrityError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainInboxReplayConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct DomainInboxRedactedError: Error, Sendable, Equatable {
    package init() {}
}

extension P1ResultBranchV1 {
    fileprivate var commandType: P1CommandTypeV1 {
        switch self {
        case .captureInput: .inputCapture
        case .commitInputParse: .inputParseResult
        case .retryInputParse, .failInputParse: .inputParseFailure
        case .requeueInputParsing: .inputRequeueParsing
        case .cancelInputParsingAndDelete: .inputCancelParsingAndDelete
        case .requestCampAssignment: .inputRequestCampAssignment
        case .recordCampAmbiguity: .inputRecordCampAmbiguity
        case .assignCamp: .inputAssignCamp
        case .archiveInput: .inputArchive
        case .markInputCoaching: .inputMarkCoaching
        case .convertInputToGoal: .inputConvertToGoal
        case .requestInputDeletion: .inputRequestDeletion
        case .completeInputDeletion: .inputCompleteDeletion
        case .openCoachSession: .coachOpenSession
        case .recordCoachQuestion: .coachRecordQuestion
        case .answerCoachQuestion: .coachAnswerQuestion
        case .proposeUnderstanding: .coachProposeUnderstanding
        case .requestConfirmation: .coachRequestConfirmation
        case .confirmUnderstanding: .coachConfirmUnderstanding
        case .requestRevisionUnconfirmed, .requestRevisionConfirmed:
            .coachRequestUnderstandingRevision
        case .coachFailureRetryClarifying, .coachFailureRetryReady,
             .coachFailureTerminalClarifying, .coachFailureTerminalReady:
            .coachRecordWorkFailure
        case .abandonGoalWithoutSession, .abandonGoalWithSession:
            .goalAbandon
        case .failGoalWithoutSession, .failGoalWithSession:
            .goalFail
        case .beginEngineExecution:
            .engineExecutionBegin
        case .startEngineDispatch:
            .engineDispatchStart
        case .requestEngineCancellation:
            .engineCancellationRequest
        case .acceptEngineEvent:
            .engineEventAccept
        case .recordEngineTerminalProposal:
            .engineTerminalProposalRecord
        case .commitEngineTerminal, .commitEngineTerminalWithAttention:
            .engineTerminalCommit
        }
    }
}
