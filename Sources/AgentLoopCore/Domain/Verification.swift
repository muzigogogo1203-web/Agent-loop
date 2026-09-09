import Darwin
import Foundation

package enum VerificationResultV1:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case passed
    case failed
    case blocked
    case invalid
}

package struct VerificationRequirementRefV1:
    Codable, Sendable, Equatable, Hashable
{
    package let contract: OutcomeContractRef
    package let requirementId: String
    package let requirementVersion: Int
    package let requirementHash: String

    package init(
        contract: OutcomeContractRef,
        requirementId: String,
        requirementVersion: Int,
        requirementHash: String
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(requirementId)
        try CanonicalContractCodingV1.validatePositive(requirementVersion)
        try CanonicalContractCodingV1.validateLowercaseHash(requirementHash)
        self.contract = contract
        self.requirementId = requirementId
        self.requirementVersion = requirementVersion
        self.requirementHash = requirementHash
    }
}

package struct VerificationRecordSnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let commandIdempotencyKey: String
    package let requirement: VerificationRequirementRefV1
    package let outcome: OutcomeRefV1
    package let verifierType: VerificationActorTypeV1
    package let verifierId: String
    package let method: VerificationMethodV1
    package let ruleId: String
    package let ruleVersion: Int
    package let environment: [String: JSONValue]
    package let commandOrRule: [String: JSONValue]
    package let rawResultRef: String?
    package let evidenceHash: String
    package let result: VerificationResultV1
    package let supersedesVerificationId: String?
    package let createdAt: Date
}

package struct RecordVerificationCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let verificationId: String
    package let requirement: VerificationRequirementRefV1
    package let outcome: OutcomeRefV1
    package let expectedOutcomeAggregateVersion: Int
    package let expectedCurrentVerificationId: String?
    package let environment: [String: JSONValue]
    package let commandOrRule: [String: JSONValue]
    package let rawResultRef: String?
    package let result: VerificationResultV1
    package let evidenceHash: String

    package init(
        envelope: CommandEnvelopeV1,
        verificationId: String,
        requirement: VerificationRequirementRefV1,
        outcome: OutcomeRefV1,
        expectedOutcomeAggregateVersion: Int,
        expectedCurrentVerificationId: String?,
        environment: [String: JSONValue],
        commandOrRule: [String: JSONValue],
        rawResultRef: String?,
        result: VerificationResultV1
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(verificationId)
        try CanonicalContractCodingV1.validatePositive(
            expectedOutcomeAggregateVersion
        )
        if let expectedCurrentVerificationId {
            try CanonicalContractCodingV1.validateCanonicalUUID(
                expectedCurrentVerificationId
            )
        }
        try CanonicalContractCodingV1.validateOptionalNonempty(rawResultRef)
        let evidence = VerificationEvidenceHashMaterial(
            environment: environment,
            commandOrRule: commandOrRule,
            rawResultRef: rawResultRef,
            result: result
        )
        self.envelope = envelope
        self.verificationId = verificationId
        self.requirement = requirement
        self.outcome = outcome
        self.expectedOutcomeAggregateVersion = expectedOutcomeAggregateVersion
        self.expectedCurrentVerificationId = expectedCurrentVerificationId
        self.environment = environment
        self.commandOrRule = commandOrRule
        self.rawResultRef = rawResultRef
        self.result = result
        evidenceHash = try CanonicalContractCodingV1.hash(evidence)
    }
}

package struct VerificationDependencyRefV1:
    Codable, Sendable, Equatable, Hashable
{
    package let type: String
    package let id: String
    package let version: Int?
    package let hash: String?

    package init(
        type: String,
        id: String,
        version: Int?,
        hash: String?
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(type)
        try CanonicalContractCodingV1.validateNonempty(id)
        if let version {
            try CanonicalContractCodingV1.validatePositive(version)
        }
        if let hash {
            try CanonicalContractCodingV1.validateLowercaseHash(hash)
        }
        self.type = type
        self.id = id
        self.version = version
        self.hash = hash
    }
}

package struct InvalidateVerificationCommandV1: Sendable, Equatable {
    package let envelope: CommandEnvelopeV1
    package let outcome: OutcomeRefV1
    package let expectedOutcomeAggregateVersion: Int
    package let verificationIds: [String]
    package let reasonCode: String
    package let dependency: VerificationDependencyRefV1

    package init(
        envelope: CommandEnvelopeV1,
        outcome: OutcomeRefV1,
        expectedOutcomeAggregateVersion: Int,
        verificationIds: [String],
        reasonCode: String,
        dependency: VerificationDependencyRefV1
    ) throws {
        try CanonicalContractCodingV1.validatePositive(
            expectedOutcomeAggregateVersion
        )
        guard !verificationIds.isEmpty,
              Set(verificationIds).count == verificationIds.count
        else {
            throw P1ContractValidationError.invalidMembership
        }
        for id in verificationIds {
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
        }
        try CanonicalContractCodingV1.validateCode(reasonCode)
        self.envelope = envelope
        self.outcome = outcome
        self.expectedOutcomeAggregateVersion = expectedOutcomeAggregateVersion
        self.verificationIds = verificationIds.sorted()
        self.reasonCode = reasonCode
        self.dependency = dependency
    }
}

package struct DeleteOrInvalidateDependencyCommandV1:
    Sendable, Equatable
{
    package let envelope: CommandEnvelopeV1
    package let campId: String
    package let reasonCode: String
    package let dependency: VerificationDependencyRefV1

    package init(
        envelope: CommandEnvelopeV1,
        campId: String,
        reasonCode: String,
        dependency: VerificationDependencyRefV1
    ) throws {
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateCode(reasonCode)
        self.envelope = envelope
        self.campId = campId
        self.reasonCode = reasonCode
        self.dependency = dependency
    }
}

package struct DependencyInvalidationResultV1:
    Codable, Sendable, Equatable
{
    package let dependency: VerificationDependencyRefV1
    package let verificationIds: [String]
    package let outcomes: [OutcomeSnapshotV1]

    package init(
        dependency: VerificationDependencyRefV1,
        verificationIds: [String],
        outcomes: [OutcomeSnapshotV1]
    ) throws {
        guard verificationIds == verificationIds.sorted(),
              Set(verificationIds).count == verificationIds.count,
              outcomes.map(\.id) == outcomes.map(\.id).sorted(),
              Set(outcomes.map(\.id)).count == outcomes.count
        else {
            throw P1ContractValidationError.invalidMembership
        }
        for id in verificationIds {
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
        }
        self.dependency = dependency
        self.verificationIds = verificationIds
        self.outcomes = outcomes
    }
}

package struct VerificationReferenceMismatchError:
    Error, Sendable, Equatable
{
    package init() {}
}

package struct VerificationHeadConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct VerificationProducerConflictError: Error, Sendable, Equatable {
    package init() {}
}

package struct VerificationActorMismatchError: Error, Sendable, Equatable {
    package init() {}
}

package enum DeterministicVerifierCapabilityV1:
    String, Sendable, Equatable, Hashable
{
    case runProcess
    case readArtifact
    case workspaceWrite
}

package struct DeterministicVerificationResultV1:
    Codable, Sendable, Equatable
{
    package let result: VerificationResultV1
    package let evidenceHash: String
}

package struct P1DProcessRequestV1: Codable, Sendable, Equatable {
    package let command: [String]
    package let environment: [String: String]
    package let timeoutSeconds: TimeInterval
}

package struct P1DProcessResultV1: Codable, Sendable, Equatable {
    package let exitCode: Int?
    package let stdout: String
    package let stderr: String
    package let timedOut: Bool

    package init(
        exitCode: Int?,
        stdout: String,
        stderr: String,
        timedOut: Bool
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.timedOut = timedOut
    }
}

package protocol P1DProcessRunner: Sendable {
    func run(_ request: P1DProcessRequestV1) async throws
        -> P1DProcessResultV1
}

package struct P1DCommandVerificationRequestV1: Sendable, Equatable {
    package let command: [String]
    package let environment: [String: String]
    package let timeoutSeconds: TimeInterval
    package let ruleVersion: Int

    package init(
        command: [String],
        environment: [String: String],
        timeoutSeconds: TimeInterval,
        ruleVersion: Int
    ) {
        self.command = command
        self.environment = environment
        self.timeoutSeconds = timeoutSeconds
        self.ruleVersion = ruleVersion
    }
}

package struct CommandExitVerifier<Runner: P1DProcessRunner>: Sendable {
    package static var capabilities: Set<DeterministicVerifierCapabilityV1> {
        [.runProcess]
    }

    private let runner: Runner

    package init(runner: Runner) {
        self.runner = runner
    }

    package func verify(
        _ request: P1DCommandVerificationRequestV1
    ) async throws -> DeterministicVerificationResultV1 {
        guard request.ruleVersion == 1,
              !request.command.isEmpty,
              request.command.allSatisfy({ !$0.isEmpty }),
              request.environment["PATH"]?.isEmpty == false,
              request.timeoutSeconds.isFinite,
              request.timeoutSeconds > 0
        else {
            throw DeterministicVerificationInputError()
        }
        let processRequest = P1DProcessRequestV1(
            command: request.command,
            environment: request.environment,
            timeoutSeconds: request.timeoutSeconds
        )
        let result = try await runner.run(processRequest)
        let derived: VerificationResultV1
        if result.timedOut {
            derived = .blocked
        } else if let exitCode = result.exitCode {
            derived = exitCode == 0 ? .passed : .failed
        } else {
            derived = .invalid
        }
        return DeterministicVerificationResultV1(
            result: derived,
            evidenceHash: try CanonicalContractCodingV1.hash(
                CommandEvidence(request: processRequest, result: result)
            )
        )
    }
}

package struct ArtifactHashVerifier: Sendable {
    package static let capabilities: Set<DeterministicVerifierCapabilityV1>
        = [.readArtifact]

    package init() {}

    package func verify(
        path: String,
        expectedHash: String
    ) throws -> DeterministicVerificationResultV1 {
        try CanonicalContractCodingV1.validateNonempty(path)
        try CanonicalContractCodingV1.validateLowercaseHash(expectedHash)
        let evidence: ArtifactEvidence
        var info = stat()
        if lstat(path, &info) != 0
            || (info.st_mode & S_IFMT) != S_IFREG
            || !FileManager.default.isReadableFile(atPath: path)
        {
            evidence = ArtifactEvidence(
                path: path,
                expectedHash: expectedHash,
                actualHash: nil,
                readableRegularFile: false
            )
            return DeterministicVerificationResultV1(
                result: .failed,
                evidenceHash: try CanonicalContractCodingV1.hash(evidence)
            )
        }
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        } catch {
            evidence = ArtifactEvidence(
                path: path,
                expectedHash: expectedHash,
                actualHash: nil,
                readableRegularFile: false
            )
            return DeterministicVerificationResultV1(
                result: .failed,
                evidenceHash: try CanonicalContractCodingV1.hash(evidence)
            )
        }
        let actual = CanonicalJSONV1.sha256Hex(data)
        evidence = ArtifactEvidence(
            path: path,
            expectedHash: expectedHash,
            actualHash: actual,
            readableRegularFile: true
        )
        return DeterministicVerificationResultV1(
            result: actual == expectedHash ? .passed : .failed,
            evidenceHash: try CanonicalContractCodingV1.hash(evidence)
        )
    }
}

package struct DeterministicVerificationInputError:
    Error, Sendable, Equatable
{
    package init() {}
}

private struct VerificationEvidenceHashMaterial: Codable {
    let environment: [String: JSONValue]
    let commandOrRule: [String: JSONValue]
    let rawResultRef: String?
    let result: VerificationResultV1
}

private struct CommandEvidence: Codable {
    let request: P1DProcessRequestV1
    let result: P1DProcessResultV1
}

private struct ArtifactEvidence: Codable {
    let path: String
    let expectedHash: String
    let actualHash: String?
    let readableRegularFile: Bool
}
