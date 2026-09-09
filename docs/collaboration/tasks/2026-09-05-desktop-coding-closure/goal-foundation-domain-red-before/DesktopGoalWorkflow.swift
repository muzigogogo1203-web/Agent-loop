import Foundation

package enum DesktopGoalFoundationErrorV1: Error, Sendable, Equatable {
    case invalidIntent
    case contextConflict
    case operationConflict
    case stageConflict
    case receiptConflict
    case staleOperationVersion
    case missingCarrier
    case graphScopeMismatch
    case corruptCanonicalPayload
    case retentionIntegrity
    case inputDeleted
}

// Temporary RED-only scaffold. Every behavior below fails explicitly until the
// parent observes the domain tests fail and admits the corresponding implementation.
private enum DesktopGoalDomainNotImplemented: Error {
    case checkpoint2
}

package enum DesktopCoachOutputPolicyV1: Codable, Sendable, Equatable {
    case providerAware(apiRequestedTokens: Int)

    package init(from decoder: Decoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package func encode(to encoder: Encoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }
}

package enum DesktopCoachRuntimeV1: Codable, Sendable, Equatable {
    case unconfigured
    case selected(profileId: String, model: String)

    package init(from decoder: Decoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package func encode(to encoder: Encoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }
}

package struct DesktopCoachPolicyV1: Codable, Sendable, Equatable {
    package let maximumDispatches: Int
    package let reportedTokenStopThreshold: Int
    package let maximumRequestUTF8Bytes: Int
    package let outputPolicy: DesktopCoachOutputPolicyV1
    package let timeoutSeconds: Int

    package init(
        maximumDispatches: Int = 8,
        reportedTokenStopThreshold: Int = 32_768,
        maximumRequestUTF8Bytes: Int = 49_152,
        outputPolicy: DesktopCoachOutputPolicyV1 = .providerAware(apiRequestedTokens: 4_096),
        timeoutSeconds: Int = 120
    ) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package init(from decoder: Decoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package func encode(to encoder: Encoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }
}

package struct DesktopGoalContextV1: Codable, Sendable, Equatable {
    package let schemaVersion: Int
    package let inputId: String
    package let goalId: String
    package let sessionId: String
    package let coachRuntime: DesktopCoachRuntimeV1
    package let coachPolicy: DesktopCoachPolicyV1
    package let remoteConsentReceiptId: String?
    package let workspacePath: String?
    package let workspaceBookmark: Data?
    package let companionIds: [String]
    package let budgetTokens: Int
    package let autonomy: MissionAutonomy
    package let privacyLevel: InputPrivacyLevelV1

    package init(
        schemaVersion: Int = 1,
        inputId: String,
        goalId: String,
        sessionId: String,
        coachRuntime: DesktopCoachRuntimeV1,
        coachPolicy: DesktopCoachPolicyV1,
        remoteConsentReceiptId: String? = nil,
        workspacePath: String? = nil,
        workspaceBookmark: Data? = nil,
        companionIds: [String] = [],
        budgetTokens: Int,
        autonomy: MissionAutonomy = .standard,
        privacyLevel: InputPrivacyLevelV1 = .localOnly
    ) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package init(from decoder: Decoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package func encode(to encoder: Encoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }
}

package struct DesktopGoalCaptureIntentV1: Codable, Sendable, Equatable {
    package let operationId: String
    package let campId: String
    package let expectedCampLifecycleVersion: Int
    package let context: DesktopGoalContextV1
    package let originalText: String
    package let envelope: CommandEnvelopeV1

    package init(
        operationId: String,
        campId: String,
        expectedCampLifecycleVersion: Int,
        context: DesktopGoalContextV1,
        originalText: String,
        envelope: CommandEnvelopeV1
    ) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package init(from decoder: Decoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package func encode(to encoder: Encoder) throws {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }

    package func captureCommand() throws -> CaptureInputCommandV1 {
        throw DesktopGoalDomainNotImplemented.checkpoint2
    }
}
