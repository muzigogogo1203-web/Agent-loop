import Foundation

package enum CowIdentityStatusV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case active
    case retired
}

package enum CowRetirementBlockedError: Error, Sendable, Equatable {
    case protectedCow
    case unsupportedCompanionKind
    case activeMission
    case enabledSchedule
    case pendingResidency
}

package struct CowRetirementReceiptV1: Sendable, Equatable {
    package let identity: CowIdentitySnapshotV1
    package let revokedResidencyIds: [String]

    package init(
        identity: CowIdentitySnapshotV1,
        revokedResidencyIds: [String]
    ) {
        self.identity = identity
        self.revokedResidencyIds = revokedResidencyIds
    }
}

package struct CowIdentitySnapshotV1: Codable, Sendable, Equatable {
    package let id: String
    package let displayName: String
    package let appearanceRef: String?
    package let personality: String
    package let baseRole: String
    package let defaultEnginePolicyJson: String
    package let status: CowIdentityStatusV1
    package let aggregateVersion: Int
    package let createdAt: Date
    package let updatedAt: Date

    package init(
        id: String,
        displayName: String,
        appearanceRef: String?,
        personality: String,
        baseRole: String,
        defaultEnginePolicyJson: String,
        status: CowIdentityStatusV1,
        aggregateVersion: Int,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(id)
        try CanonicalContractCodingV1.validateNonempty(displayName)
        try CanonicalContractCodingV1.validateOptionalNonempty(appearanceRef)
        try Self.validateMultilineContent(personality)
        try CanonicalContractCodingV1.validateNonempty(baseRole)
        try CanonicalContractCodingV1.validatePositive(aggregateVersion)
        try CanonicalContractCodingV1.validateFinite(createdAt)
        try CanonicalContractCodingV1.validateFinite(updatedAt)
        guard updatedAt >= createdAt else {
            throw P1ContractValidationError.invalidTime
        }
        let policyBytes = Data(defaultEnginePolicyJson.utf8)
        try CanonicalJSONV1.validateCanonical(rawUTF8: policyBytes)
        let policy = try CanonicalContractCodingV1.decode(
            JSONValue.self,
            from: policyBytes
        )
        guard policy.objectValue != nil else {
            throw P1ContractValidationError.invalidValue
        }
        self.id = id
        self.displayName = displayName
        self.appearanceRef = appearanceRef
        self.personality = personality
        self.baseRole = baseRole
        self.defaultEnginePolicyJson = defaultEnginePolicyJson
        self.status = status
        self.aggregateVersion = aggregateVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func validateMultilineContent(_ value: String) throws {
        let safeFormattingScalars: Set<Unicode.Scalar> = ["\t", "\n", "\r"]
        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.unicodeScalars.contains(where: { scalar in
                  CharacterSet.controlCharacters.contains(scalar)
                      && !safeFormattingScalars.contains(scalar)
              })
        else {
            throw P1ContractValidationError.invalidValue
        }
    }
}
