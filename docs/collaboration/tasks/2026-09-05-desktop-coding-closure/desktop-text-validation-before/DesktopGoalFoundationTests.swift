import Foundation
import Testing
import AgentLoopCore

private let desktopGoalInputID = "10000000-0000-4000-8000-000000000001"
private let desktopGoalGoalID = "10000000-0000-4000-8000-000000000002"
private let desktopGoalSessionID = "10000000-0000-4000-8000-000000000003"
private let desktopGoalOperationID = "10000000-0000-4000-8000-000000000004"
private let desktopGoalDeviceID = "10000000-0000-4000-8000-000000000005"
private let desktopGoalProfileID = "10000000-0000-4000-8000-000000000006"

private func desktopGoalContext(
    runtime: DesktopCoachRuntimeV1 = .unconfigured,
    maximumDispatches: Int = 8
) throws -> DesktopGoalContextV1 {
    let policy = try DesktopCoachPolicyV1(maximumDispatches: maximumDispatches)
    return try DesktopGoalContextV1(
        inputId: desktopGoalInputID,
        goalId: desktopGoalGoalID,
        sessionId: desktopGoalSessionID,
        coachRuntime: runtime,
        coachPolicy: policy,
        budgetTokens: 100_000
    )
}

private func desktopGoalEnvelope(
    key: String = "desktop-goal:10000000-0000-4000-8000-000000000004:capture:v1",
    actorId: String = "user:local-owner"
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: .user,
        actorId: actorId,
        deviceId: desktopGoalDeviceID,
        correlationId: "desktop-goal-test",
        causationId: nil,
        occurredAt: Date(timeIntervalSince1970: 100)
    )
}

private func desktopGoalIntent(
    text: String = "hello",
    context: DesktopGoalContextV1,
    envelope: CommandEnvelopeV1
) throws -> DesktopGoalCaptureIntentV1 {
    try DesktopGoalCaptureIntentV1(
        operationId: desktopGoalOperationID,
        campId: "desktop-camp-a",
        expectedCampLifecycleVersion: 1,
        context: context,
        originalText: text,
        envelope: envelope
    )
}

@Suite(.serialized)
struct DesktopGoalFoundationTests {
    // Catches synthesized enum encoding, omitted policy, or rejection of valid V1.
    @Test func desktopDomainOutputPolicyHasExactCanonicalWireShape() throws {
        #expect(throws: Never.self) {
            let policy = DesktopCoachOutputPolicyV1.providerAware(apiRequestedTokens: 4_096)
            let encoded = try CanonicalContractCodingV1.string(policy)
            #expect(encoded == "{\"apiRequestedTokens\":4096,\"kind\":\"providerAware\"}")
            let decoded = try CanonicalContractCodingV1.decode(
                DesktopCoachOutputPolicyV1.self,
                from: Data("{\"apiRequestedTokens\":4096,\"kind\":\"providerAware\"}".utf8)
            )
            #expect(decoded == .providerAware(apiRequestedTokens: 4_096))
        }
    }

    // Catches lost runtime selection, policy limits, explicit nil fields and hash drift.
    @Test func desktopDomainContextBindsPolicyAndUnresolvedRuntime() throws {
        #expect(throws: Never.self) {
            for runtime in [DesktopCoachRuntimeV1.unconfigured,
                            .selected(profileId: desktopGoalProfileID, model: "unresolved-model")] {
                let context = try desktopGoalContext(runtime: runtime)
                let bytes = try CanonicalContractCodingV1.encode(context)
                let object = try JSONSerialization.jsonObject(with: bytes)
                let dictionary = try #require(object as? [String: Any])
                let coach = try #require(dictionary["coachPolicy"] as? [String: Any])
                let policy = try #require(coach["outputPolicy"] as? [String: Any])
                #expect(Set(policy.keys) == Set(["apiRequestedTokens", "kind"]))
                #expect(policy["kind"] as? String == "providerAware")
                #expect(policy["apiRequestedTokens"] as? Int == 4_096)
                #expect(coach["maximumDispatches"] as? Int == 8)
                #expect(coach["reportedTokenStopThreshold"] as? Int == 32_768)
                #expect(coach["maximumRequestUTF8Bytes"] as? Int == 49_152)
                #expect(coach["timeoutSeconds"] as? Int == 120)
                #expect(dictionary["remoteConsentReceiptId"] is NSNull)
                #expect(dictionary["workspacePath"] is NSNull)
                #expect(dictionary["workspaceBookmark"] is NSNull)
                let decoded = try CanonicalContractCodingV1.decode(DesktopGoalContextV1.self, from: bytes)
                #expect(decoded == context)
                #expect(decoded.coachRuntime == runtime)
                let changed = try desktopGoalContext(runtime: runtime, maximumDispatches: 7)
                let originalHash = try CanonicalContractCodingV1.hash(context)
                let changedHash = try CanonicalContractCodingV1.hash(changed)
                #expect(originalHash != changedHash)
                let envelope = try desktopGoalEnvelope()
                let originalIntent = try desktopGoalIntent(context: context, envelope: envelope)
                let changedIntent = try desktopGoalIntent(context: changed, envelope: envelope)
                let originalIntentHash = try CanonicalContractCodingV1.hash(originalIntent)
                let changedIntentHash = try CanonicalContractCodingV1.hash(changedIntent)
                #expect(originalIntentHash != changedIntentHash)
            }
        }
    }

    // Catches trimming/replacing interior text, generated identities and incorrect capture ownership.
    @Test func desktopDomainCaptureIntentSealsNormalizedCallerOwnedCommand() throws {
        #expect(throws: Never.self) {
            let context = try desktopGoalContext()
            let envelope = try desktopGoalEnvelope()
            let intent = try desktopGoalIntent(text: " \nhello\t ", context: context, envelope: envelope)
            #expect(intent.originalText == "hello")
            let command = try intent.captureCommand()
            #expect(command.inputId == desktopGoalInputID)
            #expect(command.auditCampId == "desktop-camp-a")
            #expect(command.initialCampId == "desktop-camp-a")
            #expect(command.sourceType == .text)
            #expect(command.sourceDeviceId == desktopGoalDeviceID)
            #expect(command.connectorId == nil)
            #expect(command.authorId == nil)
            #expect(command.payloadRef == nil)
            #expect(command.parentInputId == nil)
            #expect(command.candidateCampIds.isEmpty)
            #expect(command.explicitIntent == .createGoal)
            #expect(command.privacyLevel == .localOnly)
            #expect(command.inlineText == "hello")
            #expect(command.capturedAt == Date(timeIntervalSince1970: 100))
            #expect(command.contentHash == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
            #expect(command.envelope == envelope)
            let bytes = try CanonicalContractCodingV1.encode(intent)
            let decoded = try CanonicalContractCodingV1.decode(DesktopGoalCaptureIntentV1.self, from: bytes)
            let replayCommand = try decoded.captureCommand()
            let commandBytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: command.envelope, payload: command)
            let replayBytes = try CanonicalContractCodingV1.wholeCommandBytes(envelope: replayCommand.envelope, payload: replayCommand)
            #expect(decoded == intent)
            #expect(commandBytes == replayBytes)
            let spaced = try desktopGoalIntent(text: "  hello  world  ", context: context, envelope: envelope)
            #expect(spaced.originalText == "hello  world")
        }
    }

    // Catches permissive decoding that discards extra keys or accepts a legacy cap.
    @Test func desktopDomainOutputPolicyRejectsUnsupportedWirePayloads() throws {
        let unsupported = [
            "{}",
            "{\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":4096}",
            "{\"apiRequestedTokens\":4096,\"extra\":true,\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":4096,\"kind\":\"fixed\"}",
            "{\"apiRequestedTokens\":\"4096\",\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":true,\"kind\":\"providerAware\"}",
            "{\"apiRequestedTokens\":4095,\"kind\":\"providerAware\"}",
            "{\"kind\":\"providerAware\",\"maximumOutputTokens\":4096}",
        ]
        for json in unsupported {
            #expect(throws: (any Error).self) {
                _ = try CanonicalContractCodingV1.decode(DesktopCoachOutputPolicyV1.self, from: Data(json.utf8))
            }
        }
    }

    // Catches wrong gesture key, non-owner submission and an empty normalized gesture.
    @Test func desktopDomainCaptureIntentRejectsWrongIdentityAndEmptyText() throws {
        let context = try desktopGoalContext()
        let envelope = try desktopGoalEnvelope()
        let wrongKey = try desktopGoalEnvelope(key: "different-key")
        let wrongOwner = try desktopGoalEnvelope(actorId: "user:someone-else")
        for candidate in [wrongKey, wrongOwner] {
            #expect(throws: DesktopGoalFoundationErrorV1.invalidIntent) {
                _ = try desktopGoalIntent(context: context, envelope: candidate)
            }
        }
        #expect(throws: DesktopGoalFoundationErrorV1.invalidIntent) {
            _ = try desktopGoalIntent(text: " \n\t ", context: context, envelope: envelope)
        }
    }

    // Catches the identifier validator incorrectly rejecting ordinary text formatting.
    @Test func desktopTextCapturePreservesInteriorFormatting() throws {
        let cases: [(text: String, sha256: String)] = [
            ("first\nsecond", "4252f8d56b4bb236d0b1bc95a1202e392ca84ce0644bf628398fbb9517287da8"),
            ("first\r\nsecond", "d930e679a8ca94308fb7400eea7b82500cc7ea08eff0c1484e065e4a5f6145d0"),
            ("first\tsecond", "8718839ad8d16514fe1c77498f204280c1c5c4d6d669ea746816c35b6301f5e4"),
        ]
        let context = try desktopGoalContext()
        let envelope = try desktopGoalEnvelope()
        for item in cases {
            let intent = try desktopGoalIntent(text: item.text, context: context, envelope: envelope)
            #expect(Array(intent.originalText.utf8) == Array(item.text.utf8))
            #expect(throws: Never.self) {
                let command = try intent.captureCommand()
                let inlineText = try #require(command.inlineText)
                #expect(Array(inlineText.utf8) == Array(item.text.utf8))
                #expect(command.contentHash == item.sha256)
                #expect(command.inputId == desktopGoalInputID)
                #expect(command.sourceType == .text)
                #expect(command.sourceDeviceId == desktopGoalDeviceID)
                #expect(command.auditCampId == "desktop-camp-a")
                #expect(command.initialCampId == "desktop-camp-a")
                #expect(command.explicitIntent == .createGoal)
                #expect(command.envelope == envelope)
            }
        }
    }
}
