import Foundation

package enum EngineBlockedIntentSubtypeV1: Sendable, Equatable {
    case ordinary
    case engineProtocolError
    case externalEffectUnknown
}

package enum EngineTerminalIntentV1: Sendable, Equatable {
    case completed(handoff: HandoffPayload)
    case blocked(
        subtype: EngineBlockedIntentSubtypeV1,
        reasonCode: String,
        detail: String
    )
    case needsHumanInput(
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]
    )
    case failed(code: String, detail: String)
    case canceled(reasonCode: String, detail: String)
}

package enum EngineBoardTerminalIntentV1: Sendable, Equatable {
    case completed(handoff: HandoffPayload)
    case blocked(reasonCode: String, detail: String)
    case needsHumanInput(
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]
    )
}

package struct EngineTerminalConflictErrorV1: Error, Sendable, Equatable {
    package init() {}
}

package struct EngineTerminalProposalValidationErrorV1:
    Error, Sendable, Equatable
{
    package init() {}
}

package enum EngineTerminalKindV1:
    String, Sendable, Equatable, Codable, CaseIterable
{
    case completed
    case blocked
    case failed
    case canceled
}

package enum EngineTerminalSubtypeV1:
    String, Sendable, Equatable, Codable, CaseIterable
{
    case ordinary
    case needsHumanInput
    case engineProtocolError
    case externalEffectUnknown
}

package enum EngineTerminalPayloadV1: Sendable, Equatable, Codable {
    case completed(handoff: HandoffPayload)
    case blocked(reasonCode: String, detail: String)
    case failed(code: String, detail: String)
    case canceled(reasonCode: String, detail: String)
    case needsHumanInput(
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]
    )

    private enum CodingKeys: String, CodingKey {
        case kind
        case handoff
        case reasonCode
        case code
        case detail
        case requestKind
        case prompt
        case options
    }

    private enum PayloadKind: String, Codable {
        case completed
        case blocked
        case failed
        case canceled
        case needsHumanInput
    }

    package var completedHandoff: HandoffPayload? {
        guard case let .completed(handoff) = self else { return nil }
        return handoff
    }

    package var reasonCode: String? {
        switch self {
        case .completed, .needsHumanInput:
            nil
        case let .blocked(reasonCode, _), let .canceled(reasonCode, _):
            reasonCode
        case let .failed(code, _):
            code
        }
    }

    package var detail: String? {
        switch self {
        case .completed, .needsHumanInput:
            nil
        case let .blocked(_, detail),
             let .failed(_, detail),
             let .canceled(_, detail):
            detail
        }
    }

    package var humanInput:
        (kind: UserRequestRecord.Kind, prompt: String, options: [String])?
    {
        guard case let .needsHumanInput(kind, prompt, options) = self else {
            return nil
        }
        return (kind, prompt, options)
    }

    package func encode(to encoder: any Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .completed(handoff):
            try container.encode(PayloadKind.completed, forKey: .kind)
            try container.encode(handoff, forKey: .handoff)
        case let .blocked(reasonCode, detail):
            try container.encode(PayloadKind.blocked, forKey: .kind)
            try container.encode(reasonCode, forKey: .reasonCode)
            try container.encode(detail, forKey: .detail)
        case let .failed(code, detail):
            try container.encode(PayloadKind.failed, forKey: .kind)
            try container.encode(code, forKey: .code)
            try container.encode(detail, forKey: .detail)
        case let .canceled(reasonCode, detail):
            try container.encode(PayloadKind.canceled, forKey: .kind)
            try container.encode(reasonCode, forKey: .reasonCode)
            try container.encode(detail, forKey: .detail)
        case let .needsHumanInput(kind, prompt, options):
            try container.encode(PayloadKind.needsHumanInput, forKey: .kind)
            try container.encode(kind, forKey: .requestKind)
            try container.encode(prompt, forKey: .prompt)
            try container.encode(options, forKey: .options)
        }
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(PayloadKind.self, forKey: .kind) {
        case .completed:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["handoff", "kind"]
            )
            self = .completed(
                handoff: try container.decode(HandoffPayload.self, forKey: .handoff)
            )
        case .blocked:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["detail", "kind", "reasonCode"]
            )
            self = .blocked(
                reasonCode: try container.decode(String.self, forKey: .reasonCode),
                detail: try container.decode(String.self, forKey: .detail)
            )
        case .failed:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["code", "detail", "kind"]
            )
            self = .failed(
                code: try container.decode(String.self, forKey: .code),
                detail: try container.decode(String.self, forKey: .detail)
            )
        case .canceled:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["detail", "kind", "reasonCode"]
            )
            self = .canceled(
                reasonCode: try container.decode(String.self, forKey: .reasonCode),
                detail: try container.decode(String.self, forKey: .detail)
            )
        case .needsHumanInput:
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                ["kind", "options", "prompt", "requestKind"]
            )
            self = .needsHumanInput(
                kind: try container.decode(
                    UserRequestRecord.Kind.self,
                    forKey: .requestKind
                ),
                prompt: try container.decode(String.self, forKey: .prompt),
                options: try container.decode([String].self, forKey: .options)
            )
        }
        try validate()
    }

    fileprivate func validate() throws {
        switch self {
        case .completed:
            return
        case let .blocked(reasonCode, detail),
             let .canceled(reasonCode, detail):
            try EngineContractValidationV1.validateReasonCode(reasonCode)
            try EngineContractValidationV1.validateDetail(detail)
        case let .failed(code, detail):
            try EngineContractValidationV1.validateReasonCode(code)
            try EngineContractValidationV1.validateDetail(detail)
        case let .needsHumanInput(kind, prompt, options):
            try EngineContractValidationV1.validateDetail(prompt)
            switch kind {
            case .approval:
                throw EngineTerminalProposalValidationErrorV1()
            case .choice:
                guard (2...6).contains(options.count),
                      Set(options.map { Data($0.utf8) }).count == options.count
                else {
                    throw EngineTerminalProposalValidationErrorV1()
                }
                for option in options {
                    try EngineContractValidationV1.validateChoiceOption(option)
                }
            case .confirm, .text:
                guard options.isEmpty else {
                    throw EngineTerminalProposalValidationErrorV1()
                }
            }
        }
    }
}

package struct EngineTerminalArtifactDeclarationV1:
    Sendable, Equatable, Codable
{
    package let ordinal: Int
    package let sourceRelativePath: String
    package let kind: String
    package let label: String
    package let byteCount: Int
    package let contentHash: String

    package init(
        ordinal: Int,
        sourceRelativePath: String,
        kind: String,
        label: String,
        byteCount: Int,
        contentHash: String
    ) {
        self.ordinal = ordinal
        self.sourceRelativePath = sourceRelativePath
        self.kind = kind
        self.label = label
        self.byteCount = byteCount
        self.contentHash = contentHash
    }

    private enum CodingKeys: String, CodingKey {
        case ordinal
        case sourceRelativePath
        case kind
        case label
        case byteCount
        case contentHash
    }

    package init(from decoder: any Decoder) throws {
        try EngineContractValidationV1.requireExactKeys(
            decoder,
            [
                "byteCount", "contentHash", "kind", "label", "ordinal",
                "sourceRelativePath",
            ]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ordinal: try container.decode(Int.self, forKey: .ordinal),
            sourceRelativePath: try container.decode(
                String.self,
                forKey: .sourceRelativePath
            ),
            kind: try container.decode(String.self, forKey: .kind),
            label: try container.decode(String.self, forKey: .label),
            byteCount: try container.decode(Int.self, forKey: .byteCount),
            contentHash: try container.decode(String.self, forKey: .contentHash)
        )
        try validate()
    }

    package func encode(to encoder: any Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ordinal, forKey: .ordinal)
        try container.encode(sourceRelativePath, forKey: .sourceRelativePath)
        try container.encode(kind, forKey: .kind)
        try container.encode(label, forKey: .label)
        try container.encode(byteCount, forKey: .byteCount)
        try container.encode(contentHash, forKey: .contentHash)
    }

    fileprivate func validate() throws {
        try CanonicalContractCodingV1.validateNonnegative(ordinal)
        try CanonicalContractCodingV1.validateNonnegative(byteCount)
        try CanonicalContractCodingV1.validateNonempty(kind)
        try CanonicalContractCodingV1.validateNonempty(label)
        try CanonicalContractCodingV1.validateLowercaseHash(contentHash)
        guard EngineTerminalProposalContentV1.isNormalizedRelativePath(
            sourceRelativePath
        ) else {
            throw EngineTerminalProposalValidationErrorV1()
        }
    }
}

package struct EngineTerminalProposalContentV1: Sendable, Equatable, Codable {
    package let protocolVersion: String
    package let executionId: String
    package let runId: String
    package let cardId: String
    package let sequence: Int
    package let terminalIdempotencyKey: String
    package let terminalKind: EngineTerminalKindV1
    package let terminalSubtype: EngineTerminalSubtypeV1?
    package let payload: EngineTerminalPayloadV1
    package let artifacts: [EngineTerminalArtifactDeclarationV1]

    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case executionId
        case runId
        case cardId
        case sequence
        case terminalIdempotencyKey
        case terminalKind
        case terminalSubtype
        case payload
        case artifacts
    }

    package init(
        protocolVersion: String,
        executionId: String,
        runId: String,
        cardId: String,
        sequence: Int,
        terminalIdempotencyKey: String,
        terminalKind: EngineTerminalKindV1,
        terminalSubtype: EngineTerminalSubtypeV1?,
        payload: EngineTerminalPayloadV1,
        artifacts: [EngineTerminalArtifactDeclarationV1]
    ) throws {
        guard protocolVersion == engineExecutionProtocolVersionV1,
              sequence >= 0,
              artifacts.count <= 256
        else {
            throw EngineTerminalProposalValidationErrorV1()
        }
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
            try CanonicalContractCodingV1.validateCanonicalUUID(runId)
            try CanonicalContractCodingV1.validateCanonicalUUID(cardId)
            try EngineContractValidationV1.validateIdempotencyKey(
                terminalIdempotencyKey
            )
            try payload.validate()
            for artifact in artifacts {
                try artifact.validate()
            }
        } catch {
            throw EngineTerminalProposalValidationErrorV1()
        }

        let normalized = artifacts.sorted { lhs, rhs in
            if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
            if lhs.sourceRelativePath != rhs.sourceRelativePath {
                return lhs.sourceRelativePath < rhs.sourceRelativePath
            }
            if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
            if lhs.label != rhs.label { return lhs.label < rhs.label }
            if lhs.byteCount != rhs.byteCount { return lhs.byteCount < rhs.byteCount }
            return lhs.contentHash < rhs.contentHash
        }
        guard normalized.enumerated().allSatisfy({ index, artifact in
            artifact.ordinal == index
        }) else {
            throw EngineTerminalProposalValidationErrorV1()
        }

        guard Self.matchesTaxonomy(
            kind: terminalKind,
            subtype: terminalSubtype,
            payload: payload
        ) else {
            throw EngineTerminalProposalValidationErrorV1()
        }
        if terminalKind != .completed, !normalized.isEmpty {
            throw EngineTerminalProposalValidationErrorV1()
        }
        if case let .completed(handoff) = payload {
            let outcome = handoff.outcome.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = handoff.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !outcome.isEmpty, !summary.isEmpty else {
                throw EngineTerminalProposalValidationErrorV1()
            }
            if normalized.isEmpty {
                guard handoff.artifacts.isEmpty,
                      let reason = handoff.noArtifactReason?.trimmingCharacters(
                          in: .whitespacesAndNewlines
                      ),
                      !reason.isEmpty
                else {
                    throw EngineTerminalProposalValidationErrorV1()
                }
            }
        }

        self.protocolVersion = protocolVersion
        self.executionId = executionId
        self.runId = runId
        self.cardId = cardId
        self.sequence = sequence
        self.terminalIdempotencyKey = terminalIdempotencyKey
        self.terminalKind = terminalKind
        self.terminalSubtype = terminalSubtype
        self.payload = payload
        self.artifacts = normalized
    }

    package func encode(to encoder: any Encoder) throws {
        _ = try EngineTerminalProposalContentV1(
            protocolVersion: protocolVersion,
            executionId: executionId,
            runId: runId,
            cardId: cardId,
            sequence: sequence,
            terminalIdempotencyKey: terminalIdempotencyKey,
            terminalKind: terminalKind,
            terminalSubtype: terminalSubtype,
            payload: payload,
            artifacts: artifacts
        )
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(executionId, forKey: .executionId)
        try container.encode(runId, forKey: .runId)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(terminalIdempotencyKey, forKey: .terminalIdempotencyKey)
        try container.encode(terminalKind, forKey: .terminalKind)
        if let terminalSubtype {
            try container.encode(terminalSubtype, forKey: .terminalSubtype)
        }
        try container.encode(payload, forKey: .payload)
        try container.encode(artifacts, forKey: .artifacts)
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let requiredKeys = [
            "artifacts", "cardId", "executionId", "payload",
            "protocolVersion", "runId", "sequence", "terminalIdempotencyKey",
            "terminalKind",
        ]
        let terminalSubtype: EngineTerminalSubtypeV1?
        if container.contains(.terminalSubtype) {
            guard try !container.decodeNil(forKey: .terminalSubtype) else {
                throw P1ContractValidationError.invalidKeys
            }
            try EngineContractValidationV1.requireExactKeys(
                decoder,
                requiredKeys + ["terminalSubtype"]
            )
            terminalSubtype = try container.decode(
                EngineTerminalSubtypeV1.self,
                forKey: .terminalSubtype
            )
        } else {
            try EngineContractValidationV1.requireExactKeys(decoder, requiredKeys)
            terminalSubtype = nil
        }
        try self.init(
            protocolVersion: container.decode(String.self, forKey: .protocolVersion),
            executionId: container.decode(String.self, forKey: .executionId),
            runId: container.decode(String.self, forKey: .runId),
            cardId: container.decode(String.self, forKey: .cardId),
            sequence: container.decode(Int.self, forKey: .sequence),
            terminalIdempotencyKey: container.decode(
                String.self,
                forKey: .terminalIdempotencyKey
            ),
            terminalKind: container.decode(
                EngineTerminalKindV1.self,
                forKey: .terminalKind
            ),
            terminalSubtype: terminalSubtype,
            payload: container.decode(
                EngineTerminalPayloadV1.self,
                forKey: .payload
            ),
            artifacts: container.decode(
                [EngineTerminalArtifactDeclarationV1].self,
                forKey: .artifacts
            )
        )
    }

    package func validateCompletedHandoffManifest() throws {
        guard case let .completed(handoff) = payload else { return }
        let declarations = artifacts.map {
            HandoffPayload.ArtifactDecl(
                relativePath: $0.sourceRelativePath,
                kind: $0.kind,
                label: $0.label
            )
        }
        guard handoff.artifacts == declarations else {
            throw EngineTerminalProposalValidationErrorV1()
        }
        if artifacts.isEmpty {
            guard let reason = handoff.noArtifactReason?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !reason.isEmpty else {
                throw EngineTerminalProposalValidationErrorV1()
            }
        } else if let reason = handoff.noArtifactReason,
                  !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            throw EngineTerminalProposalValidationErrorV1()
        }
    }

    private static func matchesTaxonomy(
        kind: EngineTerminalKindV1,
        subtype: EngineTerminalSubtypeV1?,
        payload: EngineTerminalPayloadV1
    ) -> Bool {
        switch (kind, subtype, payload) {
        case (.completed, nil, .completed):
            true
        case (.blocked, .ordinary, .blocked),
             (.blocked, .engineProtocolError, .blocked),
             (.blocked, .externalEffectUnknown, .blocked):
            true
        case (.blocked, .needsHumanInput, .needsHumanInput):
            true
        case (.failed, nil, .failed), (.canceled, nil, .canceled):
            true
        default:
            false
        }
    }

    fileprivate static func isNormalizedRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasSuffix("/"),
              !path.contains("\\"),
              !path.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { component in
            !component.isEmpty && component != "." && component != ".."
        }
    }
}

package struct EnginePreDispatchFailureV1: Sendable, Equatable, Codable {
    package let terminalKind: EngineTerminalKindV1
    package let terminalSubtype: EngineTerminalSubtypeV1?
    package let reasonCode: String
    package let detail: String

    package init(
        terminalKind: EngineTerminalKindV1,
        terminalSubtype: EngineTerminalSubtypeV1?,
        reasonCode: String,
        detail: String
    ) {
        self.terminalKind = terminalKind
        self.terminalSubtype = terminalSubtype
        self.reasonCode = reasonCode
        self.detail = detail
    }
}

package struct EngineTerminalPreparationFailure: Sendable, Equatable, Codable {
    package let reasonCode: String
    package let detail: String

    package init(reasonCode: String, detail: String) {
        self.reasonCode = reasonCode
        self.detail = detail
    }
}

package struct EngineTerminalProposalSnapshotV1: Sendable, Equatable {
    package let proposal: EngineTerminalProposalRecord
    package let artifacts: [EngineProposalArtifactRecord]

    package init(
        proposal: EngineTerminalProposalRecord,
        artifacts: [EngineProposalArtifactRecord]
    ) {
        self.proposal = proposal
        self.artifacts = artifacts
    }
}

package typealias EngineTerminalProposalRecordResult =
    EngineTerminalProposalSnapshotV1

package enum EngineTerminalDispositionV1:
    String, Sendable, Equatable, Codable, CaseIterable
{
    case committedProposal
    case invalidProtocolError
    case invalidCampDeletion
}

package typealias EngineTerminalCommitDispositionV1 =
    EngineTerminalDispositionV1

package struct EngineTerminalCommitReceiptV1: Sendable, Equatable, Codable {
    package let receiptIdempotencyKey: String
    package let executionId: String
    package let proposalId: String
    package let proposalHash: String
    package let disposition: EngineTerminalDispositionV1
    package let terminalKind: EngineTerminalKindV1
    package let terminalSubtype: EngineTerminalSubtypeV1?
    package let reasonCode: String?
    package let artifactIds: [String]
    package let committedEventIds: [String]
    package let finishedAt: Date
    package let terminalReceiptHash: String

    private enum CodingKeys: String, CodingKey {
        case receiptIdempotencyKey
        case executionId
        case proposalId
        case proposalHash
        case disposition
        case terminalKind
        case terminalSubtype
        case reasonCode
        case artifactIds
        case committedEventIds
        case finishedAt
        case terminalReceiptHash
    }

    package init(
        receiptIdempotencyKey: String,
        executionId: String,
        proposalId: String,
        proposalHash: String,
        disposition: EngineTerminalDispositionV1,
        terminalKind: EngineTerminalKindV1,
        terminalSubtype: EngineTerminalSubtypeV1?,
        reasonCode: String?,
        artifactIds: [String],
        committedEventIds: [String],
        finishedAt: Date,
        terminalReceiptHash: String
    ) throws {
        try EngineContractValidationV1.validateIdempotencyKey(
            receiptIdempotencyKey
        )
        try CanonicalContractCodingV1.validateCanonicalUUID(executionId)
        try CanonicalContractCodingV1.validateCanonicalUUID(proposalId)
        try CanonicalContractCodingV1.validateLowercaseHash(proposalHash)
        try CanonicalContractCodingV1.validateLowercaseHash(
            terminalReceiptHash
        )
        try CanonicalContractCodingV1.validateFinite(finishedAt)
        guard artifactIds.count <= 256,
              Set(artifactIds).count == artifactIds.count,
              (1...2).contains(committedEventIds.count),
              Set(committedEventIds).count == committedEventIds.count
        else {
            throw EngineTerminalProposalValidationErrorV1()
        }
        for artifactId in artifactIds {
            try CanonicalContractCodingV1.validateCanonicalUUID(artifactId)
        }
        for eventId in committedEventIds {
            try CanonicalContractCodingV1.validateCanonicalUUID(eventId)
        }
        switch (disposition, terminalKind, terminalSubtype, reasonCode) {
        case (.committedProposal, .completed, nil, nil):
            guard committedEventIds.count == 1 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
        case let (.committedProposal, .failed, nil, .some(code)),
             let (.committedProposal, .canceled, nil, .some(code)):
            guard artifactIds.isEmpty, committedEventIds.count == 1 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
            try EngineContractValidationV1.validateReasonCode(code)
        case let (
            .committedProposal,
            .blocked,
            .some(.ordinary),
            .some(code)
        ):
            guard artifactIds.isEmpty, committedEventIds.count == 1 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
            try EngineContractValidationV1.validateReasonCode(code)
        case (
            .committedProposal,
            .blocked,
            .some(.needsHumanInput),
            .some("needs_human_input")
        ):
            guard artifactIds.isEmpty, committedEventIds.count == 1 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
        case let (
            .committedProposal,
            .blocked,
            .some(.engineProtocolError),
            .some(code)
        ):
            guard artifactIds.isEmpty else {
                throw EngineTerminalProposalValidationErrorV1()
            }
            try EngineContractValidationV1.validateReasonCode(code)
        case let (
            .committedProposal,
            .blocked,
            .some(.externalEffectUnknown),
            .some(code)
        ):
            guard artifactIds.isEmpty, committedEventIds.count == 2 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
            try EngineContractValidationV1.validateReasonCode(code)
        case let (
            .invalidProtocolError,
            .blocked,
            .some(.engineProtocolError),
            .some(code)
        ):
            guard artifactIds.isEmpty, committedEventIds.count == 2 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
            try EngineContractValidationV1.validateReasonCode(code)
        case (
            .invalidCampDeletion,
            .canceled,
            nil,
            .some("camp_deleted")
        ):
            guard artifactIds.isEmpty, committedEventIds.count == 1 else {
                throw EngineTerminalProposalValidationErrorV1()
            }
        default:
            throw EngineTerminalProposalValidationErrorV1()
        }
        self.receiptIdempotencyKey = receiptIdempotencyKey
        self.executionId = executionId
        self.proposalId = proposalId
        self.proposalHash = proposalHash
        self.disposition = disposition
        self.terminalKind = terminalKind
        self.terminalSubtype = terminalSubtype
        self.reasonCode = reasonCode
        self.artifactIds = artifactIds
        self.committedEventIds = committedEventIds
        self.finishedAt = finishedAt
        self.terminalReceiptHash = terminalReceiptHash
    }

    package func encode(to encoder: any Encoder) throws {
        _ = try EngineTerminalCommitReceiptV1(
            receiptIdempotencyKey: receiptIdempotencyKey,
            executionId: executionId,
            proposalId: proposalId,
            proposalHash: proposalHash,
            disposition: disposition,
            terminalKind: terminalKind,
            terminalSubtype: terminalSubtype,
            reasonCode: reasonCode,
            artifactIds: artifactIds,
            committedEventIds: committedEventIds,
            finishedAt: finishedAt,
            terminalReceiptHash: terminalReceiptHash
        )
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(receiptIdempotencyKey, forKey: .receiptIdempotencyKey)
        try container.encode(executionId, forKey: .executionId)
        try container.encode(proposalId, forKey: .proposalId)
        try container.encode(proposalHash, forKey: .proposalHash)
        try container.encode(disposition, forKey: .disposition)
        try container.encode(terminalKind, forKey: .terminalKind)
        if let terminalSubtype {
            try container.encode(terminalSubtype, forKey: .terminalSubtype)
        }
        if let reasonCode {
            try container.encode(reasonCode, forKey: .reasonCode)
        }
        try container.encode(artifactIds, forKey: .artifactIds)
        try container.encode(committedEventIds, forKey: .committedEventIds)
        try container.encode(finishedAt, forKey: .finishedAt)
        try container.encode(terminalReceiptHash, forKey: .terminalReceiptHash)
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var expectedKeys = [
            "artifactIds", "committedEventIds", "disposition", "executionId",
            "finishedAt", "proposalHash", "proposalId", "receiptIdempotencyKey",
            "terminalKind", "terminalReceiptHash",
        ]
        let terminalSubtype: EngineTerminalSubtypeV1?
        if container.contains(.terminalSubtype) {
            guard try !container.decodeNil(forKey: .terminalSubtype) else {
                throw P1ContractValidationError.invalidKeys
            }
            expectedKeys.append("terminalSubtype")
            terminalSubtype = try container.decode(
                EngineTerminalSubtypeV1.self,
                forKey: .terminalSubtype
            )
        } else {
            terminalSubtype = nil
        }
        let reasonCode: String?
        if container.contains(.reasonCode) {
            guard try !container.decodeNil(forKey: .reasonCode) else {
                throw P1ContractValidationError.invalidKeys
            }
            expectedKeys.append("reasonCode")
            reasonCode = try container.decode(String.self, forKey: .reasonCode)
        } else {
            reasonCode = nil
        }
        try EngineContractValidationV1.requireExactKeys(decoder, expectedKeys)
        try self.init(
            receiptIdempotencyKey: container.decode(
                String.self,
                forKey: .receiptIdempotencyKey
            ),
            executionId: container.decode(String.self, forKey: .executionId),
            proposalId: container.decode(String.self, forKey: .proposalId),
            proposalHash: container.decode(String.self, forKey: .proposalHash),
            disposition: container.decode(
                EngineTerminalDispositionV1.self,
                forKey: .disposition
            ),
            terminalKind: container.decode(
                EngineTerminalKindV1.self,
                forKey: .terminalKind
            ),
            terminalSubtype: terminalSubtype,
            reasonCode: reasonCode,
            artifactIds: container.decode([String].self, forKey: .artifactIds),
            committedEventIds: container.decode(
                [String].self,
                forKey: .committedEventIds
            ),
            finishedAt: container.decode(Date.self, forKey: .finishedAt),
            terminalReceiptHash: container.decode(
                String.self,
                forKey: .terminalReceiptHash
            )
        )
    }
}

package enum EngineRecoveryActionV1: Sendable, Equatable {
    case prepareAndCommitProposal(proposalId: String)
    case deferCampDeletion(proposalId: String?)
    case cancelAndReconcile
    case startPrepared
    case resumeSession(sessionId: String, externalSessionId: String)
    case replayExecution
}

package struct EngineExecutionRecoverySnapshotV1: Sendable, Equatable {
    package let execution: EngineExecutionRecord
    package let request: EngineExecutionRequest
    package let proposal: EngineTerminalProposalSnapshotV1?
    package let session: EngineSessionRecord?
    package let campLifecycleState: CampLifecycleStateV1
    package let campLifecycleVersion: Int

    package init(
        execution: EngineExecutionRecord,
        request: EngineExecutionRequest,
        proposal: EngineTerminalProposalSnapshotV1?,
        session: EngineSessionRecord?,
        campLifecycleState: CampLifecycleStateV1,
        campLifecycleVersion: Int
    ) {
        self.execution = execution
        self.request = request
        self.proposal = proposal
        self.session = session
        self.campLifecycleState = campLifecycleState
        self.campLifecycleVersion = campLifecycleVersion
    }
}

package struct EngineRecoveryDirectiveV1: Sendable, Equatable {
    package let executionId: String
    package let request: EngineExecutionRequest?
    package let action: EngineRecoveryActionV1

    package init(
        executionId: String,
        request: EngineExecutionRequest?,
        action: EngineRecoveryActionV1
    ) {
        self.executionId = executionId
        self.request = request
        self.action = action
    }
}

package struct EngineRecoverySummaryV1: Sendable, Equatable {
    package let scannedCount: Int
    package let terminalReceipts: [EngineTerminalCommitReceiptV1]
    package let directives: [EngineRecoveryDirectiveV1]

    package init(
        scannedCount: Int,
        terminalReceipts: [EngineTerminalCommitReceiptV1],
        directives: [EngineRecoveryDirectiveV1]
    ) {
        self.scannedCount = scannedCount
        self.terminalReceipts = terminalReceipts
        self.directives = directives
    }
}
