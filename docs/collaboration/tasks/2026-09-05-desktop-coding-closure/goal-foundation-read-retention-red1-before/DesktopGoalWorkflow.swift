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

package enum DesktopCoachOutputPolicyV1: Codable, Sendable, Equatable {
    case providerAware(apiRequestedTokens: Int)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, apiRequestedTokens
    }

    fileprivate func validate() throws {
        guard case .providerAware(apiRequestedTokens: 4_096) = self else {
            throw DesktopGoalFoundationErrorV1.invalidIntent
        }
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .kind) == "providerAware" else {
            throw DesktopGoalFoundationErrorV1.invalidIntent
        }
        self = .providerAware(apiRequestedTokens: try container.decode(Int.self, forKey: .apiRequestedTokens))
        try validate()
    }

    package func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("providerAware", forKey: .kind)
        try container.encode(4_096, forKey: .apiRequestedTokens)
    }
}

package enum DesktopCoachRuntimeV1: Codable, Sendable, Equatable {
    case unconfigured
    case selected(profileId: String, model: String)

    private enum CodingKeys: String, CodingKey {
        case kind, profileId, model
    }

    fileprivate func validate() throws {
        if case let .selected(profileId, model) = self {
            try CanonicalContractCodingV1.validateCanonicalUUID(profileId)
            try CanonicalContractCodingV1.validateNonempty(model)
        }
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "unconfigured":
            try InputContractValidationV1.requireExactKeys(decoder, ["kind"])
            self = .unconfigured
        case "selected":
            try InputContractValidationV1.requireExactKeys(decoder, ["kind", "profileId", "model"])
            self = .selected(
                profileId: try container.decode(String.self, forKey: .profileId),
                model: try container.decode(String.self, forKey: .model)
            )
        default:
            throw DesktopGoalFoundationErrorV1.invalidIntent
        }
        try validate()
    }

    package func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unconfigured:
            try container.encode("unconfigured", forKey: .kind)
        case let .selected(profileId, model):
            try container.encode("selected", forKey: .kind)
            try container.encode(profileId, forKey: .profileId)
            try container.encode(model, forKey: .model)
        }
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
        try CanonicalContractCodingV1.validatePositive(maximumDispatches)
        try CanonicalContractCodingV1.validatePositive(reportedTokenStopThreshold)
        try CanonicalContractCodingV1.validatePositive(maximumRequestUTF8Bytes)
        try CanonicalContractCodingV1.validatePositive(timeoutSeconds)
        try outputPolicy.validate()
        self.maximumDispatches = maximumDispatches
        self.reportedTokenStopThreshold = reportedTokenStopThreshold
        self.maximumRequestUTF8Bytes = maximumRequestUTF8Bytes
        self.outputPolicy = outputPolicy
        self.timeoutSeconds = timeoutSeconds
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case maximumDispatches, reportedTokenStopThreshold, maximumRequestUTF8Bytes
        case outputPolicy, timeoutSeconds
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            maximumDispatches: container.decode(Int.self, forKey: .maximumDispatches),
            reportedTokenStopThreshold: container.decode(Int.self, forKey: .reportedTokenStopThreshold),
            maximumRequestUTF8Bytes: container.decode(Int.self, forKey: .maximumRequestUTF8Bytes),
            outputPolicy: container.decode(DesktopCoachOutputPolicyV1.self, forKey: .outputPolicy),
            timeoutSeconds: container.decode(Int.self, forKey: .timeoutSeconds)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(maximumDispatches, forKey: .maximumDispatches)
        try container.encode(reportedTokenStopThreshold, forKey: .reportedTokenStopThreshold)
        try container.encode(maximumRequestUTF8Bytes, forKey: .maximumRequestUTF8Bytes)
        try container.encode(outputPolicy, forKey: .outputPolicy)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
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
        guard schemaVersion == 1 else {
            throw P1ContractValidationError.invalidSchemaVersion
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(inputId)
        try CanonicalContractCodingV1.validateCanonicalUUID(goalId)
        try CanonicalContractCodingV1.validateCanonicalUUID(sessionId)
        try coachRuntime.validate()
        if let remoteConsentReceiptId {
            try CanonicalContractCodingV1.validateCanonicalUUID(remoteConsentReceiptId)
        }
        try CanonicalContractCodingV1.validateOptionalNonempty(workspacePath)
        if let workspaceBookmark {
            guard workspacePath != nil, !workspaceBookmark.isEmpty else {
                throw DesktopGoalFoundationErrorV1.invalidIntent
            }
        }
        guard Set(companionIds).count == companionIds.count else {
            throw P1ContractValidationError.duplicateKind
        }
        for id in companionIds {
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
        }
        try CanonicalContractCodingV1.validatePositive(budgetTokens)
        self.schemaVersion = schemaVersion
        self.inputId = inputId
        self.goalId = goalId
        self.sessionId = sessionId
        self.coachRuntime = coachRuntime
        self.coachPolicy = coachPolicy
        self.remoteConsentReceiptId = remoteConsentReceiptId
        self.workspacePath = workspacePath
        self.workspaceBookmark = workspaceBookmark
        self.companionIds = companionIds
        self.budgetTokens = budgetTokens
        self.autonomy = autonomy
        self.privacyLevel = privacyLevel
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, inputId, goalId, sessionId, coachRuntime, coachPolicy
        case remoteConsentReceiptId, workspacePath, workspaceBookmark, companionIds
        case budgetTokens, autonomy, privacyLevel
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            inputId: container.decode(String.self, forKey: .inputId),
            goalId: container.decode(String.self, forKey: .goalId),
            sessionId: container.decode(String.self, forKey: .sessionId),
            coachRuntime: container.decode(DesktopCoachRuntimeV1.self, forKey: .coachRuntime),
            coachPolicy: container.decode(DesktopCoachPolicyV1.self, forKey: .coachPolicy),
            remoteConsentReceiptId: container.decodeIfPresent(String.self, forKey: .remoteConsentReceiptId),
            workspacePath: container.decodeIfPresent(String.self, forKey: .workspacePath),
            workspaceBookmark: container.decodeIfPresent(Data.self, forKey: .workspaceBookmark),
            companionIds: container.decode([String].self, forKey: .companionIds),
            budgetTokens: container.decode(Int.self, forKey: .budgetTokens),
            autonomy: container.decode(MissionAutonomy.self, forKey: .autonomy),
            privacyLevel: container.decode(InputPrivacyLevelV1.self, forKey: .privacyLevel)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(inputId, forKey: .inputId)
        try container.encode(goalId, forKey: .goalId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(coachRuntime, forKey: .coachRuntime)
        try container.encode(coachPolicy, forKey: .coachPolicy)
        try container.encode(remoteConsentReceiptId, forKey: .remoteConsentReceiptId)
        try container.encode(workspacePath, forKey: .workspacePath)
        try container.encode(workspaceBookmark, forKey: .workspaceBookmark)
        try container.encode(companionIds, forKey: .companionIds)
        try container.encode(budgetTokens, forKey: .budgetTokens)
        try container.encode(autonomy, forKey: .autonomy)
        try container.encode(privacyLevel, forKey: .privacyLevel)
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
        try self.init(
            operationId: operationId,
            campId: campId,
            expectedCampLifecycleVersion: expectedCampLifecycleVersion,
            context: context,
            sealedText: originalText.trimmingCharacters(in: .whitespacesAndNewlines),
            envelope: envelope
        )
    }

    // Decoding uses already-sealed text and must never normalize persisted bytes.
    private init(
        operationId: String,
        campId: String,
        expectedCampLifecycleVersion: Int,
        context: DesktopGoalContextV1,
        sealedText: String,
        envelope: CommandEnvelopeV1
    ) throws {
        try CanonicalContractCodingV1.validateCanonicalUUID(operationId)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validatePositive(expectedCampLifecycleVersion)
        guard !sealedText.isEmpty,
              sealedText == sealedText.trimmingCharacters(in: .whitespacesAndNewlines),
              envelope.actorType == .user,
              envelope.actorId == "user:local-owner",
              let deviceId = envelope.deviceId,
              envelope.idempotencyKey == "desktop-goal:\(operationId):capture:v1",
              context.remoteConsentReceiptId == nil
        else {
            throw DesktopGoalFoundationErrorV1.invalidIntent
        }
        try CanonicalContractCodingV1.validateCanonicalUUID(deviceId)
        self.operationId = operationId
        self.campId = campId
        self.expectedCampLifecycleVersion = expectedCampLifecycleVersion
        self.context = context
        self.originalText = sealedText
        self.envelope = envelope
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case operationId, campId, expectedCampLifecycleVersion, context, originalText, envelope
    }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let envelopeDecoder = try container.superDecoder(forKey: .envelope)
        try InputContractValidationV1.requireExactKeys(envelopeDecoder, [
            "idempotencyKey", "actorType", "actorId", "deviceId",
            "correlationId", "causationId", "occurredAt",
        ])
        let envelope = try CommandEnvelopeV1(from: envelopeDecoder)
        try self.init(
            operationId: container.decode(String.self, forKey: .operationId),
            campId: container.decode(String.self, forKey: .campId),
            expectedCampLifecycleVersion: container.decode(Int.self, forKey: .expectedCampLifecycleVersion),
            context: container.decode(DesktopGoalContextV1.self, forKey: .context),
            sealedText: container.decode(String.self, forKey: .originalText),
            envelope: envelope
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operationId, forKey: .operationId)
        try container.encode(campId, forKey: .campId)
        try container.encode(expectedCampLifecycleVersion, forKey: .expectedCampLifecycleVersion)
        try container.encode(context, forKey: .context)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(envelope, forKey: .envelope)
    }

    package func captureCommand() throws -> CaptureInputCommandV1 {
        try CaptureInputCommandV1(
            envelope: envelope,
            inputId: context.inputId,
            auditCampId: campId,
            initialCampId: campId,
            sourceType: .text,
            sourceDeviceId: envelope.deviceId,
            connectorId: nil,
            authorId: nil,
            capturedAt: envelope.occurredAt,
            inlineText: originalText,
            payloadRef: nil,
            contentHash: CanonicalJSONV1.sha256Hex(Data(originalText.utf8)),
            candidateCampIds: [],
            explicitIntent: .createGoal,
            privacyLevel: context.privacyLevel,
            parentInputId: nil
        )
    }
}

package enum DesktopGoalOperationOwnerV1: String, Codable, Sendable, Equatable {
    case userMutation, system, coachAttempt, verificationAttempt
}

package enum DesktopGoalOperationPhaseV1: String, Codable, Sendable, Equatable {
    case prepared, committed, failed, redacted
}

package enum DesktopGoalContextRetentionV1: String, Codable, Sendable, Equatable {
    case live, redacted
}

package enum DesktopGoalStageCommandTypeV1: String, Codable, Sendable, Equatable {
    case inputCapture
}

package struct DesktopGoalCaptureReceiptV1: Codable, Sendable, Equatable {
    package let inputId: String
    package let goalId: String
    package let sessionId: String
    package let operationId: String
    package let captureReceipt: InputCaptureReceiptV1

    package init(inputId: String, goalId: String, sessionId: String, operationId: String,
                 captureReceipt: InputCaptureReceiptV1) throws {
        for id in [inputId, goalId, sessionId, operationId] {
            try CanonicalContractCodingV1.validateCanonicalUUID(id)
        }
        let receipt = try DesktopGoalStageReceiptV1(captureReceipt: captureReceipt)
        guard receipt.inputId == inputId else { throw DesktopGoalFoundationErrorV1.receiptConflict }
        self.inputId = inputId
        self.goalId = goalId
        self.sessionId = sessionId
        self.operationId = operationId
        self.captureReceipt = captureReceipt
    }

    private enum CodingKeys: String, CodingKey { case inputId, goalId, sessionId, operationId, captureReceipt }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, ["inputId", "goalId", "sessionId", "operationId", "captureReceipt"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(inputId: values.decode(String.self, forKey: .inputId),
                      goalId: values.decode(String.self, forKey: .goalId),
                      sessionId: values.decode(String.self, forKey: .sessionId),
                      operationId: values.decode(String.self, forKey: .operationId),
                      captureReceipt: values.decode(InputCaptureReceiptV1.self, forKey: .captureReceipt))
    }
}

package struct DesktopGoalStageReceiptV1: Codable, Sendable, Equatable {
    package let receiptBytes: Data
    package let receiptHash: String
    package let inputId: String
    package let inputVersion: Int
    package let workId: String
    package let workVersion: Int

    package init(captureReceipt: InputCaptureReceiptV1) throws {
        let bytes = try CanonicalContractCodingV1.encode(captureReceipt)
        let validated = try CanonicalContractCodingV1.decode(InputCaptureReceiptV1.self, from: bytes)
        guard validated.code == .inputCaptured,
              let input = validated.refs.first(where: { $0.kind == .input }),
              let work = validated.refs.first(where: { $0.kind == .durableWork }),
              let inputVersion = validated.versions.first(where: { $0.kind == .inputProjection }),
              let workVersion = validated.versions.first(where: { $0.kind == .durableWork }),
              inputVersion.value == 1, workVersion.value == 1
        else { throw DesktopGoalFoundationErrorV1.receiptConflict }
        receiptBytes = bytes
        receiptHash = CanonicalJSONV1.sha256Hex(bytes)
        inputId = input.id
        self.inputVersion = inputVersion.value
        workId = work.id
        self.workVersion = workVersion.value
    }

    private enum CodingKeys: String, CodingKey { case receiptBytes, receiptHash, inputId, inputVersion, workId, workVersion }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, ["receiptBytes", "receiptHash", "inputId", "inputVersion", "workId", "workVersion"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let bytes = try values.decode(Data.self, forKey: .receiptBytes)
        try self.init(captureReceipt: CanonicalContractCodingV1.decode(InputCaptureReceiptV1.self, from: bytes))
        guard try receiptHash == values.decode(String.self, forKey: .receiptHash),
              try inputId == values.decode(String.self, forKey: .inputId),
              try inputVersion == values.decode(Int.self, forKey: .inputVersion),
              try workId == values.decode(String.self, forKey: .workId),
              try workVersion == values.decode(Int.self, forKey: .workVersion)
        else { throw DesktopGoalFoundationErrorV1.receiptConflict }
    }
}

package struct DesktopGoalSealedStageV1: Codable, Sendable, Equatable {
    package let ordinal: Int
    package let commandType: DesktopGoalStageCommandTypeV1
    package let commandBytes: Data
    package let commandHash: String
    package let envelope: CommandEnvelopeV1
    package let predecessorReceiptHash: String?
    package let receipt: DesktopGoalStageReceiptV1?

    package init(intent: DesktopGoalCaptureIntentV1, receipt: DesktopGoalStageReceiptV1? = nil) throws {
        let command = try intent.captureCommand()
        try self.init(ordinal: 0, commandType: .inputCapture,
                      commandBytes: CanonicalContractCodingV1.wholeCommandBytes(envelope: intent.envelope, payload: command),
                      envelope: intent.envelope, receipt: receipt)
    }

    private init(ordinal: Int, commandType: DesktopGoalStageCommandTypeV1, commandBytes: Data,
                 envelope: CommandEnvelopeV1, receipt: DesktopGoalStageReceiptV1?) throws {
        guard ordinal == 0 else { throw DesktopGoalFoundationErrorV1.stageConflict }
        try CanonicalJSONV1.validateCanonical(rawUTF8: commandBytes)
        guard let object = try JSONSerialization.jsonObject(with: commandBytes) as? [String: Any],
              Set(object.keys) == Set(["envelope", "payload"]), let encodedEnvelope = object["envelope"]
        else { throw DesktopGoalFoundationErrorV1.stageConflict }
        let envelopeBytes = try CanonicalJSONV1.canonicalize(rawUTF8: JSONSerialization.data(withJSONObject: encodedEnvelope, options: [.sortedKeys, .withoutEscapingSlashes]))
        guard try envelopeBytes == CanonicalContractCodingV1.encode(envelope)
        else { throw DesktopGoalFoundationErrorV1.stageConflict }
        self.ordinal = ordinal
        self.commandType = commandType
        self.commandBytes = commandBytes
        commandHash = CanonicalJSONV1.sha256Hex(commandBytes)
        self.envelope = envelope
        predecessorReceiptHash = nil
        self.receipt = receipt
    }

    private enum CodingKeys: String, CodingKey { case ordinal, commandType, commandBytes, commandHash, envelope, predecessorReceiptHash, receipt }

    package init(from decoder: Decoder) throws {
        try InputContractValidationV1.requireExactKeys(decoder, ["ordinal", "commandType", "commandBytes", "commandHash", "envelope", "predecessorReceiptHash", "receipt"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decodeNil(forKey: .predecessorReceiptHash) else { throw DesktopGoalFoundationErrorV1.stageConflict }
        try self.init(ordinal: values.decode(Int.self, forKey: .ordinal),
                      commandType: values.decode(DesktopGoalStageCommandTypeV1.self, forKey: .commandType),
                      commandBytes: values.decode(Data.self, forKey: .commandBytes),
                      envelope: values.decode(CommandEnvelopeV1.self, forKey: .envelope),
                      receipt: values.decodeIfPresent(DesktopGoalStageReceiptV1.self, forKey: .receipt))
        guard try commandHash == values.decode(String.self, forKey: .commandHash)
        else { throw DesktopGoalFoundationErrorV1.stageConflict }
    }

    package func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(ordinal, forKey: .ordinal)
        try values.encode(commandType, forKey: .commandType)
        try values.encode(commandBytes, forKey: .commandBytes)
        try values.encode(commandHash, forKey: .commandHash)
        try values.encode(envelope, forKey: .envelope)
        try values.encode(predecessorReceiptHash, forKey: .predecessorReceiptHash)
        try values.encode(receipt, forKey: .receipt)
    }
}

package struct DesktopGoalOperationSnapshotV1: Sendable, Equatable {
    package let operationId: String
    package let inputId: String
    package let owner: DesktopGoalOperationOwnerV1
    package let kind: String
    package let version: Int
    package let phase: DesktopGoalOperationPhaseV1
    package let requestHash: String
    package let intent: DesktopGoalCaptureIntentV1?
    package let stages: [DesktopGoalSealedStageV1]
    package let safeReceipt: DesktopGoalCaptureReceiptV1?
}

package struct DesktopGoalFoundationSnapshotV1: Sendable, Equatable {
    package let context: DesktopGoalContextV1
    package let contextVersion: Int
    package let input: InputEnvelopeRecord
    package let goal: GoalControllerRecord?
    package let session: CoachSessionRecord?
    package let operations: [DesktopGoalOperationSnapshotV1]
    package let work: [DurableWorkRecord]
}

package enum DesktopGoalFoundationReadV1: Sendable, Equatable {
    case live(DesktopGoalFoundationSnapshotV1)
    case deleted(inputId: String, goalId: String)
}
