import Foundation
import GRDB

package struct UnderstandingContentV1: Sendable, Equatable, Codable {
    package let problem: String
    package let scenario: String
    package let targetAudience: String
    package let goals: [String]
    package let nonGoals: [String]
    package let deliverables: [String]
    package let constraints: [String]
    package let acceptanceCriteria: [String]
    package let verificationPlan: [String]
    package let resourceRefs: [String]
    package let requiredCapabilities: [String]
    package let budgetPolicy: [String: String]
    package let assumptions: [String]
    package let acceptedRisks: [String]

    package init(
        problem: String,
        scenario: String,
        targetAudience: String,
        goals: [String],
        nonGoals: [String],
        deliverables: [String],
        constraints: [String],
        acceptanceCriteria: [String],
        verificationPlan: [String],
        resourceRefs: [String],
        requiredCapabilities: [String],
        budgetPolicy: [String: String],
        assumptions: [String],
        acceptedRisks: [String]
    ) throws {
        try CanonicalContractCodingV1.validateNarrativeText(problem)
        try CanonicalContractCodingV1.validateNarrativeText(scenario)
        try CanonicalContractCodingV1.validateNarrativeText(targetAudience)
        for value in goals + nonGoals + deliverables + constraints
            + acceptanceCriteria + verificationPlan + assumptions + acceptedRisks
        {
            try CanonicalContractCodingV1.validateNarrativeText(value)
        }
        for value in resourceRefs + requiredCapabilities
        {
            try CanonicalContractCodingV1.validateNonempty(value)
        }
        for (key, value) in budgetPolicy {
            try CanonicalContractCodingV1.validateNonempty(key)
            try CanonicalContractCodingV1.validateNonempty(value)
        }
        self.problem = problem
        self.scenario = scenario
        self.targetAudience = targetAudience
        self.goals = goals
        self.nonGoals = nonGoals
        self.deliverables = deliverables
        self.constraints = constraints
        self.acceptanceCriteria = acceptanceCriteria
        self.verificationPlan = verificationPlan
        self.resourceRefs = resourceRefs
        self.requiredCapabilities = requiredCapabilities
        self.budgetPolicy = budgetPolicy
        self.assumptions = assumptions
        self.acceptedRisks = acceptedRisks
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case problem, scenario, targetAudience, goals, nonGoals, deliverables
        case constraints, acceptanceCriteria, verificationPlan, resourceRefs
        case requiredCapabilities, budgetPolicy, assumptions, acceptedRisks
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(
            decoder,
            CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            problem: values.decode(String.self, forKey: .problem),
            scenario: values.decode(String.self, forKey: .scenario),
            targetAudience: values.decode(String.self, forKey: .targetAudience),
            goals: values.decode([String].self, forKey: .goals),
            nonGoals: values.decode([String].self, forKey: .nonGoals),
            deliverables: values.decode([String].self, forKey: .deliverables),
            constraints: values.decode([String].self, forKey: .constraints),
            acceptanceCriteria: values.decode([String].self, forKey: .acceptanceCriteria),
            verificationPlan: values.decode([String].self, forKey: .verificationPlan),
            resourceRefs: values.decode([String].self, forKey: .resourceRefs),
            requiredCapabilities: values.decode([String].self, forKey: .requiredCapabilities),
            budgetPolicy: values.decode([String: String].self, forKey: .budgetPolicy),
            assumptions: values.decode([String].self, forKey: .assumptions),
            acceptedRisks: values.decode([String].self, forKey: .acceptedRisks)
        )
    }
}

package enum UnderstandingStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case draft
    case awaitingConfirmation
    case confirmed
    case superseded
    case withdrawn
}

package struct UnderstandingCardVersionRecord:
    Sendable, Equatable, FetchableRecord, PersistableRecord
{
    package static let databaseTableName = "understanding_card_version"

    package var id: String
    package var version: Int
    package var goalId: String
    package var content: UnderstandingContentV1
    package var status: UnderstandingStatusV1
    package var contentHash: String
    package var createdByActorId: String
    package var confirmedByActorId: String?
    package var confirmedAt: Date?
    package var createdAt: Date

    package init(
        id: String,
        version: Int,
        goalId: String,
        content: UnderstandingContentV1,
        status: UnderstandingStatusV1,
        createdByActorId: String,
        confirmedByActorId: String?,
        confirmedAt: Date?,
        createdAt: Date
    ) throws {
        let contentHash = try CanonicalContractCodingV1.hash(content)
        try Self.validate(
            id: id,
            version: version,
            goalId: goalId,
            status: status,
            contentHash: contentHash,
            createdByActorId: createdByActorId,
            confirmedByActorId: confirmedByActorId,
            confirmedAt: confirmedAt,
            createdAt: createdAt
        )
        self.id = id
        self.version = version
        self.goalId = goalId
        self.content = content
        self.status = status
        self.contentHash = contentHash
        self.createdByActorId = createdByActorId
        self.confirmedByActorId = confirmedByActorId
        self.confirmedAt = confirmedAt
        self.createdAt = createdAt
    }

    package init(row: Row) throws {
        let statusRaw: String = row["status"]
        guard let status = UnderstandingStatusV1(rawValue: statusRaw) else {
            throw P1ContractValidationError.invalidMembership
        }
        let content = try UnderstandingContentV1(
            problem: row["problem"],
            scenario: row["scenario"],
            targetAudience: row["targetAudience"],
            goals: Self.decodeArray(row["goalsJson"]),
            nonGoals: Self.decodeArray(row["nonGoalsJson"]),
            deliverables: Self.decodeArray(row["deliverablesJson"]),
            constraints: Self.decodeArray(row["constraintsJson"]),
            acceptanceCriteria: Self.decodeArray(row["acceptanceCriteriaJson"]),
            verificationPlan: Self.decodeArray(row["verificationPlanJson"]),
            resourceRefs: Self.decodeArray(row["resourceRefsJson"]),
            requiredCapabilities: Self.decodeArray(row["requiredCapabilitiesJson"]),
            budgetPolicy: Self.decodeMap(row["budgetPolicyJson"]),
            assumptions: Self.decodeArray(row["assumptionsJson"]),
            acceptedRisks: Self.decodeArray(row["acceptedRisksJson"])
        )
        let storedHash: String = row["contentHash"]
        guard try CanonicalContractCodingV1.hash(content) == storedHash else {
            throw UnderstandingIntegrityError()
        }
        try Self.validate(
            id: row["id"],
            version: row["version"],
            goalId: row["goalId"],
            status: status,
            contentHash: storedHash,
            createdByActorId: row["createdByActorId"],
            confirmedByActorId: row["confirmedByActorId"],
            confirmedAt: row["confirmedAt"],
            createdAt: row["createdAt"]
        )
        id = row["id"]
        version = row["version"]
        goalId = row["goalId"]
        self.content = content
        self.status = status
        contentHash = storedHash
        createdByActorId = row["createdByActorId"]
        confirmedByActorId = row["confirmedByActorId"]
        confirmedAt = row["confirmedAt"]
        createdAt = row["createdAt"]
    }

    package func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["version"] = version
        container["goalId"] = goalId
        container["problem"] = content.problem
        container["scenario"] = content.scenario
        container["targetAudience"] = content.targetAudience
        container["goalsJson"] = try CanonicalContractCodingV1.string(content.goals)
        container["nonGoalsJson"] = try CanonicalContractCodingV1.string(content.nonGoals)
        container["deliverablesJson"] = try CanonicalContractCodingV1.string(content.deliverables)
        container["constraintsJson"] = try CanonicalContractCodingV1.string(content.constraints)
        container["acceptanceCriteriaJson"] = try CanonicalContractCodingV1.string(content.acceptanceCriteria)
        container["verificationPlanJson"] = try CanonicalContractCodingV1.string(content.verificationPlan)
        container["resourceRefsJson"] = try CanonicalContractCodingV1.string(content.resourceRefs)
        container["requiredCapabilitiesJson"] = try CanonicalContractCodingV1.string(content.requiredCapabilities)
        container["budgetPolicyJson"] = try CanonicalContractCodingV1.string(content.budgetPolicy)
        container["assumptionsJson"] = try CanonicalContractCodingV1.string(content.assumptions)
        container["acceptedRisksJson"] = try CanonicalContractCodingV1.string(content.acceptedRisks)
        container["status"] = status.rawValue
        container["contentHash"] = contentHash
        container["createdByActorId"] = createdByActorId
        container["confirmedByActorId"] = confirmedByActorId
        container["confirmedAt"] = confirmedAt
        container["createdAt"] = createdAt
    }

    private static func decodeArray(_ value: String) throws -> [String] {
        try CanonicalContractCodingV1.decode(
            [String].self,
            from: Data(value.utf8)
        )
    }

    private static func decodeMap(_ value: String) throws -> [String: String] {
        try CanonicalContractCodingV1.decode(
            [String: String].self,
            from: Data(value.utf8)
        )
    }

    private static func validate(
        id: String,
        version: Int,
        goalId: String,
        status: UnderstandingStatusV1,
        contentHash: String,
        createdByActorId: String,
        confirmedByActorId: String?,
        confirmedAt: Date?,
        createdAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(id)
        try CanonicalContractCodingV1.validatePositive(version)
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        guard id == goalId else {
            throw P1ContractValidationError.invalidMembership
        }
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        try CanonicalContractCodingV1.validateNonempty(createdByActorId)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        let terminalConfirmation = status == .confirmed || status == .superseded
        guard terminalConfirmation == (confirmedByActorId != nil),
              terminalConfirmation == (confirmedAt != nil)
        else {
            throw P1ContractValidationError.invalidMembership
        }
        if let confirmedByActorId {
            try CanonicalContractCodingV1.validateNonempty(confirmedByActorId)
        }
        if let confirmedAt {
            try CanonicalContractCodingV1.validateFinite(confirmedAt)
        }
    }
}

package struct UnderstandingHeadV1: Sendable, Equatable, Codable {
    package let understandingId: String
    package let expectedContentVersion: Int
    package let contentHash: String
    package let expectedUnderstandingEventVersion: Int

    package init(
        understandingId: String,
        expectedContentVersion: Int,
        contentHash: String,
        expectedUnderstandingEventVersion: Int
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(understandingId)
        try CanonicalContractCodingV1.validatePositive(expectedContentVersion)
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        try CanonicalContractCodingV1.validateNonnegative(
            expectedUnderstandingEventVersion
        )
        self.understandingId = understandingId
        self.expectedContentVersion = expectedContentVersion
        self.contentHash = contentHash
        self.expectedUnderstandingEventVersion = expectedUnderstandingEventVersion
    }
}

package enum UnderstandingRevisionBranchV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case withdrawDraft
    case withdrawAwaitingConfirmation
    case reopenConfirmed
}

package struct UnderstandingIntegrityError: Error, Sendable, Equatable {
    package init() {}
}
