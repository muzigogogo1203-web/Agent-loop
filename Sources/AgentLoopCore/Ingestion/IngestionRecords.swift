import Foundation
import GRDB

public enum IngestionSourceType: String, Codable, Sendable, CaseIterable {
    case text, url, file, manual
}

public enum IngestionStatus: String, Codable, Sendable, CaseIterable {
    case queued, ruminating, needsReview, materialized, failed, discarded
}

package enum RuminationStartPreparation: Sendable, Equatable {
    case replay(ingestionId: String, workId: String)
    case new(
        ingestionId: String,
        expectedPreviousAttempt: Int,
        generation: Int,
        idempotencyKey: String
    )
}

package struct RuminationStartCommand: Sendable, Equatable {
    package let ingestionId: String
    package let expectedPreviousAttempt: Int
    package let generation: Int
    package let idempotencyKey: String
    package let traceId: String
    package let input: RuminationWorkInput

    package init(
        preparation: RuminationStartPreparation,
        traceId: String,
        input: RuminationWorkInput
    ) throws {
        guard case let .new(
            ingestionId,
            expectedPreviousAttempt,
            generation,
            idempotencyKey
        ) = preparation,
              generation >= 1,
              expectedPreviousAttempt >= 0,
              expectedPreviousAttempt.addingReportingOverflow(1)
                  == (generation, false),
              !traceId.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty
        else {
            throw InvalidDurableWorkStateError()
        }
        self.ingestionId = ingestionId
        self.expectedPreviousAttempt = expectedPreviousAttempt
        self.generation = generation
        self.idempotencyKey = idempotencyKey
        self.traceId = traceId
        self.input = input
    }
}

package enum LegacyRuminationStartupSnapshot:
    Sendable, Equatable
{
    case valid(runtimeProfileId: String, model: String)
    case legacyProfileUnresolved
    case legacyModelUnavailable
    case legacyProfileCLIUnsupported
}

public struct RuminationStartRecoveryRequiredError:
    Error, Sendable, Equatable
{
    public let ingestionId: String

    public init(ingestionId: String) {
        self.ingestionId = ingestionId
    }
}

public struct IngestionItemRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ingestion_item"

    public var id: String
    public var campId: String
    public var sourceType: IngestionSourceType
    public var title: String?
    public var rawText: String
    public var sourceURL: String?
    public var author: String?
    public var userIntent: String?
    public var contentHash: String
    public var status: IngestionStatus
    public var attempt: Int
    public var errorText: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        campId: String,
        sourceType: IngestionSourceType,
        title: String?,
        rawText: String,
        sourceURL: String?,
        author: String?,
        userIntent: String?,
        contentHash: String,
        status: IngestionStatus,
        attempt: Int,
        errorText: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.campId = campId
        self.sourceType = sourceType
        self.title = title
        self.rawText = rawText
        self.sourceURL = sourceURL
        self.author = author
        self.userIntent = userIntent
        self.contentHash = contentHash
        self.status = status
        self.attempt = attempt
        self.errorText = errorText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RuminationResultRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "rumination_result"

    public var id: String
    public var ingestionId: String
    public var pipelineVersion: String
    public var resultJson: String
    public var userEditedJson: String?
    public var materializedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        ingestionId: String,
        pipelineVersion: String,
        resultJson: String,
        userEditedJson: String?,
        materializedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ingestionId = ingestionId
        self.pipelineVersion = pipelineVersion
        self.resultJson = resultJson
        self.userEditedJson = userEditedJson
        self.materializedAt = materializedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct KnowledgeSourceLinkRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "knowledge_source_link"

    public var id: String
    public var campNoteId: String
    public var ingestionId: String
    public var locatorJson: String?
    public var createdAt: Date

    public init(id: String, campNoteId: String, ingestionId: String, locatorJson: String?, createdAt: Date) {
        self.id = id
        self.campNoteId = campNoteId
        self.ingestionId = ingestionId
        self.locatorJson = locatorJson
        self.createdAt = createdAt
    }
}

public enum ActionCandidateType: String, Codable, Sendable, CaseIterable {
    case requirement, todo, mission
}

public enum ActionCandidateStatus: String, Codable, Sendable, CaseIterable {
    case proposed, accepted, dismissed, converted
}

public struct ActionCandidateRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "action_candidate"

    public var id: String
    public var ingestionId: String
    public var campId: String
    public var type: ActionCandidateType
    public var title: String
    public var detailJson: String
    public var status: ActionCandidateStatus
    public var missionId: String?
    public var idemKey: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        ingestionId: String,
        campId: String,
        type: ActionCandidateType,
        title: String,
        detailJson: String,
        status: ActionCandidateStatus,
        missionId: String?,
        idemKey: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ingestionId = ingestionId
        self.campId = campId
        self.type = type
        self.title = title
        self.detailJson = detailJson
        self.status = status
        self.missionId = missionId
        self.idemKey = idemKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
