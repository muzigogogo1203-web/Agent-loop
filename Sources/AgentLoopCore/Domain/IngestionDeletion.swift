import Foundation

package enum ActiveIngestionDeletionScopeV1:
    String, Codable, Sendable, Equatable, CaseIterable
{
    case resultOnly
    case sourceAndResult
    case everythingIncludingProjection
}

package struct ActiveIngestionDeletionPrepareRequestV1:
    Sendable, Equatable
{
    package let envelope: CommandEnvelopeV1
    package let campId: String
    package let ingestionId: String
    package let scope: ActiveIngestionDeletionScopeV1

    package init(
        envelope: CommandEnvelopeV1,
        campId: String,
        ingestionId: String,
        scope: ActiveIngestionDeletionScopeV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(campId)
        try CanonicalContractCodingV1.validateNonempty(ingestionId)
        guard envelope.actorType == .user, envelope.deviceId != nil else {
            throw ActiveIngestionDeletionFailureV1.forbiddenActor
        }
        self.envelope = envelope
        self.campId = campId
        self.ingestionId = ingestionId
        self.scope = scope
    }
}

package struct ActiveIngestionDeletionSafePreviewV1:
    Sendable, Equatable
{
    package let campId: String
    package let ingestionId: String
    package let oldIngestionStatus: IngestionStatus
    package let resultId: String?
    package let scope: ActiveIngestionDeletionScopeV1
    package let deletedResultCount: Int
    package let deletedIngestionCount: Int
    package let updatedIngestionCount: Int
    package let knowledgeSourceLinkCount: Int
    package let actionCandidateCount: Int
    package let nonterminalRuminationWorkCount: Int
    package let openRuminationAttemptCount: Int
    package let nonterminalProviderDispatchCount: Int

    package var allBlockerCountsAreZero: Bool {
        knowledgeSourceLinkCount == 0
            && actionCandidateCount == 0
            && nonterminalRuminationWorkCount == 0
            && openRuminationAttemptCount == 0
            && nonterminalProviderDispatchCount == 0
    }
}

package enum ActiveIngestionDeletionFailureV1:
    String, Error, Codable, Sendable, Equatable
{
    case forbiddenActor
    case projectionDeletionUnsupported
    case campUnavailable
    case lifecycleChanged
    case sourceNotFound
    case invalidIngestionState
    case resultRequired
    case resultMaterialized
    case knowledgeSourceLinkBlocker
    case actionCandidateBlocker
    case ruminationWorkBlocker
    case ruminationAttemptBlocker
    case providerDispatchBlocker
    case rowChanged
    case blockersChanged
    case mutationRejected
    case persistedGraphIntegrity
    case notExecuted
}

package enum ActiveIngestionDeletionResolutionDispositionV1:
    String, Codable, Sendable, Equatable
{
    case commitOutcomeUnknown
    case integrityBlocked
    case terminalConflict
}

package enum ActiveIngestionDeletionExecutionResolutionV1:
    Sendable, Equatable
{
    case committed(ActiveIngestionDeletionResultV1)
    case notCommitted(ActiveIngestionDeletionFailureV1)
    case resolutionPending(ActiveIngestionDeletionResolutionDispositionV1)
}

package struct ActiveIngestionDeletionCommandPayloadV1:
    Sendable, Equatable, Codable
{
    package let campId: String
    package let expectedLifecycleVersion: Int
    package let ingestionId: String
    package let oldIngestionVersion: Int
    package let oldIngestionStatus: IngestionStatus
    package let ingestionContentHash: String
    package let ingestionSnapshotHash: String
    package let resultId: String?
    package let resultVersion: Int?
    package let resultHash: String?
    package let scope: ActiveIngestionDeletionScopeV1
    package let deletedResultCount: Int
    package let deletedIngestionCount: Int
    package let updatedIngestionCount: Int
    package let knowledgeSourceLinkCount: Int
    package let actionCandidateCount: Int
    package let nonterminalRuminationWorkCount: Int
    package let openRuminationAttemptCount: Int
    package let nonterminalProviderDispatchCount: Int

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case campId
        case expectedLifecycleVersion
        case ingestionId
        case oldIngestionVersion
        case oldIngestionStatus
        case ingestionContentHash
        case ingestionSnapshotHash
        case resultId
        case resultVersion
        case resultHash
        case scope
        case deletedResultCount
        case deletedIngestionCount
        case updatedIngestionCount
        case knowledgeSourceLinkCount
        case actionCandidateCount
        case nonterminalRuminationWorkCount
        case openRuminationAttemptCount
        case nonterminalProviderDispatchCount
    }

    package init(
        campId: String,
        expectedLifecycleVersion: Int,
        ingestionId: String,
        oldIngestionVersion: Int,
        oldIngestionStatus: IngestionStatus,
        ingestionContentHash: String,
        ingestionSnapshotHash: String,
        resultId: String?,
        resultVersion: Int?,
        resultHash: String?,
        scope: ActiveIngestionDeletionScopeV1,
        deletedResultCount: Int,
        deletedIngestionCount: Int,
        updatedIngestionCount: Int,
        knowledgeSourceLinkCount: Int,
        actionCandidateCount: Int,
        nonterminalRuminationWorkCount: Int,
        openRuminationAttemptCount: Int,
        nonterminalProviderDispatchCount: Int
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(campId)
        try CanonicalContractCodingV1.validateNonempty(ingestionId)
        try CanonicalContractCodingV1.validateLowercaseHash(ingestionContentHash)
        try CanonicalContractCodingV1.validateLowercaseHash(ingestionSnapshotHash)
        if let resultHash {
            try CanonicalContractCodingV1.validateLowercaseHash(resultHash)
        }
        guard expectedLifecycleVersion >= 1,
              oldIngestionVersion >= 1,
              [knowledgeSourceLinkCount, actionCandidateCount,
               nonterminalRuminationWorkCount, openRuminationAttemptCount,
               nonterminalProviderDispatchCount].allSatisfy({ $0 == 0 }),
              [deletedResultCount, deletedIngestionCount,
               updatedIngestionCount].allSatisfy({ $0 == 0 || $0 == 1 }),
              (resultId == nil) == (resultVersion == nil),
              (resultId == nil) == (resultHash == nil),
              resultVersion.map({ $0 >= 1 }) ?? true
        else {
            throw P1ContractValidationError.invalidValue
        }
        switch scope {
        case .resultOnly:
            guard [.needsReview, .failed].contains(oldIngestionStatus),
                  resultId != nil,
                  deletedResultCount == 1,
                  deletedIngestionCount == 0,
                  updatedIngestionCount == 1
            else { throw P1ContractValidationError.invalidValue }
        case .sourceAndResult:
            guard [.queued, .failed, .needsReview, .discarded]
                    .contains(oldIngestionStatus),
                  deletedResultCount == (resultId == nil ? 0 : 1),
                  deletedIngestionCount == 1,
                  updatedIngestionCount == 0
            else { throw P1ContractValidationError.invalidValue }
        case .everythingIncludingProjection:
            throw P1ContractValidationError.invalidValue
        }
        self.campId = campId
        self.expectedLifecycleVersion = expectedLifecycleVersion
        self.ingestionId = ingestionId
        self.oldIngestionVersion = oldIngestionVersion
        self.oldIngestionStatus = oldIngestionStatus
        self.ingestionContentHash = ingestionContentHash
        self.ingestionSnapshotHash = ingestionSnapshotHash
        self.resultId = resultId
        self.resultVersion = resultVersion
        self.resultHash = resultHash
        self.scope = scope
        self.deletedResultCount = deletedResultCount
        self.deletedIngestionCount = deletedIngestionCount
        self.updatedIngestionCount = updatedIngestionCount
        self.knowledgeSourceLinkCount = knowledgeSourceLinkCount
        self.actionCandidateCount = actionCandidateCount
        self.nonterminalRuminationWorkCount = nonterminalRuminationWorkCount
        self.openRuminationAttemptCount = openRuminationAttemptCount
        self.nonterminalProviderDispatchCount = nonterminalProviderDispatchCount
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases),
              container.contains(.resultId),
              container.contains(.resultVersion),
              container.contains(.resultHash)
        else {
            throw P1ContractValidationError.invalidKeys
        }
        try self.init(
            campId: container.decode(String.self, forKey: .campId),
            expectedLifecycleVersion: container.decode(Int.self, forKey: .expectedLifecycleVersion),
            ingestionId: container.decode(String.self, forKey: .ingestionId),
            oldIngestionVersion: container.decode(Int.self, forKey: .oldIngestionVersion),
            oldIngestionStatus: container.decode(IngestionStatus.self, forKey: .oldIngestionStatus),
            ingestionContentHash: container.decode(String.self, forKey: .ingestionContentHash),
            ingestionSnapshotHash: container.decode(String.self, forKey: .ingestionSnapshotHash),
            resultId: container.decodeIfPresent(String.self, forKey: .resultId),
            resultVersion: container.decodeIfPresent(Int.self, forKey: .resultVersion),
            resultHash: container.decodeIfPresent(String.self, forKey: .resultHash),
            scope: container.decode(ActiveIngestionDeletionScopeV1.self, forKey: .scope),
            deletedResultCount: container.decode(Int.self, forKey: .deletedResultCount),
            deletedIngestionCount: container.decode(Int.self, forKey: .deletedIngestionCount),
            updatedIngestionCount: container.decode(Int.self, forKey: .updatedIngestionCount),
            knowledgeSourceLinkCount: container.decode(Int.self, forKey: .knowledgeSourceLinkCount),
            actionCandidateCount: container.decode(Int.self, forKey: .actionCandidateCount),
            nonterminalRuminationWorkCount: container.decode(Int.self, forKey: .nonterminalRuminationWorkCount),
            openRuminationAttemptCount: container.decode(Int.self, forKey: .openRuminationAttemptCount),
            nonterminalProviderDispatchCount: container.decode(Int.self, forKey: .nonterminalProviderDispatchCount)
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(campId, forKey: .campId)
        try container.encode(expectedLifecycleVersion, forKey: .expectedLifecycleVersion)
        try container.encode(ingestionId, forKey: .ingestionId)
        try container.encode(oldIngestionVersion, forKey: .oldIngestionVersion)
        try container.encode(oldIngestionStatus, forKey: .oldIngestionStatus)
        try container.encode(ingestionContentHash, forKey: .ingestionContentHash)
        try container.encode(ingestionSnapshotHash, forKey: .ingestionSnapshotHash)
        try encodeOptional(resultId, key: .resultId, into: &container)
        try encodeOptional(resultVersion, key: .resultVersion, into: &container)
        try encodeOptional(resultHash, key: .resultHash, into: &container)
        try container.encode(scope, forKey: .scope)
        try container.encode(deletedResultCount, forKey: .deletedResultCount)
        try container.encode(deletedIngestionCount, forKey: .deletedIngestionCount)
        try container.encode(updatedIngestionCount, forKey: .updatedIngestionCount)
        try container.encode(knowledgeSourceLinkCount, forKey: .knowledgeSourceLinkCount)
        try container.encode(actionCandidateCount, forKey: .actionCandidateCount)
        try container.encode(nonterminalRuminationWorkCount, forKey: .nonterminalRuminationWorkCount)
        try container.encode(openRuminationAttemptCount, forKey: .openRuminationAttemptCount)
        try container.encode(nonterminalProviderDispatchCount, forKey: .nonterminalProviderDispatchCount)
    }
}

package struct ActiveIngestionDeletionEventPayloadV1:
    Sendable, Equatable, Codable
{
    package static let exactJSONKeys: Set<String> = [
        "commandIdempotencyKey", "commandPayloadHash", "campId",
        "expectedLifecycleVersion", "ingestionId", "oldIngestionVersion",
        "oldIngestionStatus", "ingestionContentHash", "ingestionSnapshotHash",
        "resultId", "resultVersion", "resultHash", "scope",
        "deletedResultCount", "deletedIngestionCount", "updatedIngestionCount",
        "knowledgeSourceLinkCount", "actionCandidateCount",
        "nonterminalRuminationWorkCount", "openRuminationAttemptCount",
        "nonterminalProviderDispatchCount",
    ]

    package let commandIdempotencyKey: String
    package let commandPayloadHash: String
    package let payload: ActiveIngestionDeletionCommandPayloadV1

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case commandIdempotencyKey
        case commandPayloadHash
        case campId
        case expectedLifecycleVersion
        case ingestionId
        case oldIngestionVersion
        case oldIngestionStatus
        case ingestionContentHash
        case ingestionSnapshotHash
        case resultId
        case resultVersion
        case resultHash
        case scope
        case deletedResultCount
        case deletedIngestionCount
        case updatedIngestionCount
        case knowledgeSourceLinkCount
        case actionCandidateCount
        case nonterminalRuminationWorkCount
        case openRuminationAttemptCount
        case nonterminalProviderDispatchCount
    }

    package init(
        commandIdempotencyKey: String,
        commandPayloadHash: String,
        payload: ActiveIngestionDeletionCommandPayloadV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(commandIdempotencyKey)
        try CanonicalContractCodingV1.validateLowercaseHash(commandPayloadHash)
        self.commandIdempotencyKey = commandIdempotencyKey
        self.commandPayloadHash = commandPayloadHash
        self.payload = payload
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases),
              container.contains(.resultId), container.contains(.resultVersion),
              container.contains(.resultHash)
        else { throw P1ContractValidationError.invalidKeys }
        try self.init(
            commandIdempotencyKey: container.decode(String.self, forKey: .commandIdempotencyKey),
            commandPayloadHash: container.decode(String.self, forKey: .commandPayloadHash),
            payload: ActiveIngestionDeletionCommandPayloadV1(
                campId: container.decode(String.self, forKey: .campId),
                expectedLifecycleVersion: container.decode(Int.self, forKey: .expectedLifecycleVersion),
                ingestionId: container.decode(String.self, forKey: .ingestionId),
                oldIngestionVersion: container.decode(Int.self, forKey: .oldIngestionVersion),
                oldIngestionStatus: container.decode(IngestionStatus.self, forKey: .oldIngestionStatus),
                ingestionContentHash: container.decode(String.self, forKey: .ingestionContentHash),
                ingestionSnapshotHash: container.decode(String.self, forKey: .ingestionSnapshotHash),
                resultId: container.decodeIfPresent(String.self, forKey: .resultId),
                resultVersion: container.decodeIfPresent(Int.self, forKey: .resultVersion),
                resultHash: container.decodeIfPresent(String.self, forKey: .resultHash),
                scope: container.decode(ActiveIngestionDeletionScopeV1.self, forKey: .scope),
                deletedResultCount: container.decode(Int.self, forKey: .deletedResultCount),
                deletedIngestionCount: container.decode(Int.self, forKey: .deletedIngestionCount),
                updatedIngestionCount: container.decode(Int.self, forKey: .updatedIngestionCount),
                knowledgeSourceLinkCount: container.decode(Int.self, forKey: .knowledgeSourceLinkCount),
                actionCandidateCount: container.decode(Int.self, forKey: .actionCandidateCount),
                nonterminalRuminationWorkCount: container.decode(Int.self, forKey: .nonterminalRuminationWorkCount),
                openRuminationAttemptCount: container.decode(Int.self, forKey: .openRuminationAttemptCount),
                nonterminalProviderDispatchCount: container.decode(Int.self, forKey: .nonterminalProviderDispatchCount)
            )
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandIdempotencyKey, forKey: .commandIdempotencyKey)
        try container.encode(commandPayloadHash, forKey: .commandPayloadHash)
        try encodePayload(payload, into: &container)
    }
}

package struct ActiveIngestionDeletionResultV1:
    Sendable, Equatable, Codable
{
    package static let exactJSONKeys =
        ActiveIngestionDeletionEventPayloadV1.exactJSONKeys.union([
            "eventId", "eventPayloadHash",
        ])

    package let commandIdempotencyKey: String
    package let commandPayloadHash: String
    package let eventId: String
    package let eventPayloadHash: String
    package let campId: String
    package let expectedLifecycleVersion: Int
    package let ingestionId: String
    package let oldIngestionVersion: Int
    package let oldIngestionStatus: IngestionStatus
    package let ingestionContentHash: String
    package let ingestionSnapshotHash: String
    package let resultId: String?
    package let resultVersion: Int?
    package let resultHash: String?
    package let scope: ActiveIngestionDeletionScopeV1
    package let deletedResultCount: Int
    package let deletedIngestionCount: Int
    package let updatedIngestionCount: Int
    package let knowledgeSourceLinkCount: Int
    package let actionCandidateCount: Int
    package let nonterminalRuminationWorkCount: Int
    package let openRuminationAttemptCount: Int
    package let nonterminalProviderDispatchCount: Int

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case commandIdempotencyKey
        case commandPayloadHash
        case eventId
        case eventPayloadHash
        case campId
        case expectedLifecycleVersion
        case ingestionId
        case oldIngestionVersion
        case oldIngestionStatus
        case ingestionContentHash
        case ingestionSnapshotHash
        case resultId
        case resultVersion
        case resultHash
        case scope
        case deletedResultCount
        case deletedIngestionCount
        case updatedIngestionCount
        case knowledgeSourceLinkCount
        case actionCandidateCount
        case nonterminalRuminationWorkCount
        case openRuminationAttemptCount
        case nonterminalProviderDispatchCount
    }

    package init(
        commandIdempotencyKey: String,
        commandPayloadHash: String,
        eventId: String,
        eventPayloadHash: String,
        payload: ActiveIngestionDeletionCommandPayloadV1
    ) throws {
        try CanonicalContractCodingV1.validateNonempty(commandIdempotencyKey)
        try CanonicalContractCodingV1.validateLowercaseHash(commandPayloadHash)
        try CanonicalContractCodingV1.validateNonempty(eventId)
        try CanonicalContractCodingV1.validateLowercaseHash(eventPayloadHash)
        self.commandIdempotencyKey = commandIdempotencyKey
        self.commandPayloadHash = commandPayloadHash
        self.eventId = eventId
        self.eventPayloadHash = eventPayloadHash
        campId = payload.campId
        expectedLifecycleVersion = payload.expectedLifecycleVersion
        ingestionId = payload.ingestionId
        oldIngestionVersion = payload.oldIngestionVersion
        oldIngestionStatus = payload.oldIngestionStatus
        ingestionContentHash = payload.ingestionContentHash
        ingestionSnapshotHash = payload.ingestionSnapshotHash
        resultId = payload.resultId
        resultVersion = payload.resultVersion
        resultHash = payload.resultHash
        scope = payload.scope
        deletedResultCount = payload.deletedResultCount
        deletedIngestionCount = payload.deletedIngestionCount
        updatedIngestionCount = payload.updatedIngestionCount
        knowledgeSourceLinkCount = payload.knowledgeSourceLinkCount
        actionCandidateCount = payload.actionCandidateCount
        nonterminalRuminationWorkCount = payload.nonterminalRuminationWorkCount
        openRuminationAttemptCount = payload.openRuminationAttemptCount
        nonterminalProviderDispatchCount = payload.nonterminalProviderDispatchCount
    }

    package var payload: ActiveIngestionDeletionCommandPayloadV1 {
        get throws {
            try ActiveIngestionDeletionCommandPayloadV1(
                campId: campId,
                expectedLifecycleVersion: expectedLifecycleVersion,
                ingestionId: ingestionId,
                oldIngestionVersion: oldIngestionVersion,
                oldIngestionStatus: oldIngestionStatus,
                ingestionContentHash: ingestionContentHash,
                ingestionSnapshotHash: ingestionSnapshotHash,
                resultId: resultId,
                resultVersion: resultVersion,
                resultHash: resultHash,
                scope: scope,
                deletedResultCount: deletedResultCount,
                deletedIngestionCount: deletedIngestionCount,
                updatedIngestionCount: updatedIngestionCount,
                knowledgeSourceLinkCount: knowledgeSourceLinkCount,
                actionCandidateCount: actionCandidateCount,
                nonterminalRuminationWorkCount: nonterminalRuminationWorkCount,
                openRuminationAttemptCount: openRuminationAttemptCount,
                nonterminalProviderDispatchCount: nonterminalProviderDispatchCount
            )
        }
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard Set(container.allKeys) == Set(CodingKeys.allCases),
              container.contains(.resultId), container.contains(.resultVersion),
              container.contains(.resultHash)
        else { throw P1ContractValidationError.invalidKeys }
        let payload = try ActiveIngestionDeletionCommandPayloadV1(
            campId: container.decode(String.self, forKey: .campId),
            expectedLifecycleVersion: container.decode(Int.self, forKey: .expectedLifecycleVersion),
            ingestionId: container.decode(String.self, forKey: .ingestionId),
            oldIngestionVersion: container.decode(Int.self, forKey: .oldIngestionVersion),
            oldIngestionStatus: container.decode(IngestionStatus.self, forKey: .oldIngestionStatus),
            ingestionContentHash: container.decode(String.self, forKey: .ingestionContentHash),
            ingestionSnapshotHash: container.decode(String.self, forKey: .ingestionSnapshotHash),
            resultId: container.decodeIfPresent(String.self, forKey: .resultId),
            resultVersion: container.decodeIfPresent(Int.self, forKey: .resultVersion),
            resultHash: container.decodeIfPresent(String.self, forKey: .resultHash),
            scope: container.decode(ActiveIngestionDeletionScopeV1.self, forKey: .scope),
            deletedResultCount: container.decode(Int.self, forKey: .deletedResultCount),
            deletedIngestionCount: container.decode(Int.self, forKey: .deletedIngestionCount),
            updatedIngestionCount: container.decode(Int.self, forKey: .updatedIngestionCount),
            knowledgeSourceLinkCount: container.decode(Int.self, forKey: .knowledgeSourceLinkCount),
            actionCandidateCount: container.decode(Int.self, forKey: .actionCandidateCount),
            nonterminalRuminationWorkCount: container.decode(Int.self, forKey: .nonterminalRuminationWorkCount),
            openRuminationAttemptCount: container.decode(Int.self, forKey: .openRuminationAttemptCount),
            nonterminalProviderDispatchCount: container.decode(Int.self, forKey: .nonterminalProviderDispatchCount)
        )
        try self.init(
            commandIdempotencyKey: container.decode(String.self, forKey: .commandIdempotencyKey),
            commandPayloadHash: container.decode(String.self, forKey: .commandPayloadHash),
            eventId: container.decode(String.self, forKey: .eventId),
            eventPayloadHash: container.decode(String.self, forKey: .eventPayloadHash),
            payload: payload
        )
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandIdempotencyKey, forKey: .commandIdempotencyKey)
        try container.encode(commandPayloadHash, forKey: .commandPayloadHash)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(eventPayloadHash, forKey: .eventPayloadHash)
        try encodePayload(try payload, into: &container)
    }
}

private func encodeOptional<Key: CodingKey, Value: Encodable>(
    _ value: Value?,
    key: Key,
    into container: inout KeyedEncodingContainer<Key>
) throws {
    if let value {
        try container.encode(value, forKey: key)
    } else {
        try container.encodeNil(forKey: key)
    }
}

private func encodePayload<Key: CodingKey>(
    _ payload: ActiveIngestionDeletionCommandPayloadV1,
    into container: inout KeyedEncodingContainer<Key>
) throws {
    func key(_ raw: String) -> Key {
        Key(stringValue: raw)!
    }
    try container.encode(payload.campId, forKey: key("campId"))
    try container.encode(payload.expectedLifecycleVersion, forKey: key("expectedLifecycleVersion"))
    try container.encode(payload.ingestionId, forKey: key("ingestionId"))
    try container.encode(payload.oldIngestionVersion, forKey: key("oldIngestionVersion"))
    try container.encode(payload.oldIngestionStatus, forKey: key("oldIngestionStatus"))
    try container.encode(payload.ingestionContentHash, forKey: key("ingestionContentHash"))
    try container.encode(payload.ingestionSnapshotHash, forKey: key("ingestionSnapshotHash"))
    try encodeOptional(payload.resultId, key: key("resultId"), into: &container)
    try encodeOptional(payload.resultVersion, key: key("resultVersion"), into: &container)
    try encodeOptional(payload.resultHash, key: key("resultHash"), into: &container)
    try container.encode(payload.scope, forKey: key("scope"))
    try container.encode(payload.deletedResultCount, forKey: key("deletedResultCount"))
    try container.encode(payload.deletedIngestionCount, forKey: key("deletedIngestionCount"))
    try container.encode(payload.updatedIngestionCount, forKey: key("updatedIngestionCount"))
    try container.encode(payload.knowledgeSourceLinkCount, forKey: key("knowledgeSourceLinkCount"))
    try container.encode(payload.actionCandidateCount, forKey: key("actionCandidateCount"))
    try container.encode(payload.nonterminalRuminationWorkCount, forKey: key("nonterminalRuminationWorkCount"))
    try container.encode(payload.openRuminationAttemptCount, forKey: key("openRuminationAttemptCount"))
    try container.encode(payload.nonterminalProviderDispatchCount, forKey: key("nonterminalProviderDispatchCount"))
}
