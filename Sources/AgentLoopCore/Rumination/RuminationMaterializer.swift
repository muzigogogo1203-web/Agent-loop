import Foundation
import GRDB

public struct RuminationMaterialization: Sendable, Equatable {
    public let noteId: String
    public let candidateIds: [String]
    public let alreadyMaterialized: Bool
}

public struct RuminationMaterializer: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    public func materialize(ingestionId: String, edited: RuminationResult) throws -> RuminationMaterialization {
        try db.pool.write { database in
            guard let ingestion = try IngestionItemRecord.fetchOne(database, key: ingestionId) else {
                throw FeedServiceError.ingestionNotFound(ingestionId)
            }
            _ = try Self.requireActiveLifecycle(
                database,
                campId: ingestion.campId
            )
            guard let ingestionFence = try Row.fetchOne(
                database,
                sql: "SELECT version,terminalReason,redactedAt FROM ingestion_item WHERE id=?",
                arguments: [ingestionId]
            ) else {
                throw FeedServiceError.ingestionNotFound(ingestionId)
            }
            let ingestionVersion: Int = ingestionFence["version"]
            let terminalReason: String? = ingestionFence["terminalReason"]
            let ingestionRedactedAt: Date? = ingestionFence["redactedAt"]
            guard let resultRecord = try RuminationResultRecord
                .filter(Column("ingestionId") == ingestionId).fetchOne(database) else {
                throw FeedServiceError.invalidState(ingestion.status)
            }
            guard let resultFence = try Row.fetchOne(
                database,
                sql: "SELECT version,redactedAt FROM rumination_result WHERE id=? AND ingestionId=?",
                arguments: [resultRecord.id, ingestionId]
            ) else {
                throw FeedServiceError.invalidState(ingestion.status)
            }
            let resultVersion: Int = resultFence["version"]
            let resultRedactedAt: Date? = resultFence["redactedAt"]
            if resultRecord.materializedAt != nil,
               let link = try KnowledgeSourceLinkRecord.filter(Column("ingestionId") == ingestionId).fetchOne(database) {
                guard ingestion.status == .materialized,
                      terminalReason == nil,
                      ingestionRedactedAt == nil,
                      resultRedactedAt == nil
                else {
                    throw FeedServiceError.invalidState(ingestion.status)
                }
                let ids = try ActionCandidateRecord.filter(Column("ingestionId") == ingestionId).fetchAll(database).map(\.id)
                return .init(noteId: link.campNoteId, candidateIds: ids, alreadyMaterialized: true)
            }
            guard ingestion.status == .needsReview,
                  terminalReason == nil,
                  ingestionRedactedAt == nil,
                  resultRecord.materializedAt == nil,
                  resultRedactedAt == nil
            else {
                throw FeedServiceError.invalidState(ingestion.status)
            }

            let now = Date()
            let note = CampNoteRecord(
                id: UUID().uuidString, campId: ingestion.campId, missionId: nil,
                title: edited.suggestedTitle,
                bodyMd: Self.noteBody(edited), pinned: false, createdAt: now, updatedAt: now
            )
            try note.insert(database)
            let locator = try Self.sortedJSON(edited.keyPoints.map { ["quote": $0.sourceQuote, "text": $0.text] })
            try KnowledgeSourceLinkRecord(
                id: UUID().uuidString, campNoteId: note.id, ingestionId: ingestionId,
                locatorJson: locator, createdAt: now
            ).insert(database)

            var candidates: [ActionCandidateRecord] = []
            for (index, requirement) in edited.requirements.enumerated() {
                candidates.append(.init(
                    id: UUID().uuidString, ingestionId: ingestionId, campId: ingestion.campId,
                    type: .requirement, title: requirement.title,
                    detailJson: try Self.sortedJSON(["detail": requirement.detail, "confidence": requirement.confidence.rawValue]),
                    status: .accepted, missionId: nil, idemKey: "\(ingestionId):requirement:\(index)",
                    createdAt: now, updatedAt: now
                ))
            }
            for (index, todo) in edited.todos.enumerated() {
                candidates.append(.init(
                    id: UUID().uuidString, ingestionId: ingestionId, campId: ingestion.campId,
                    type: .todo, title: todo.title,
                    detailJson: try Self.sortedJSON(["owner": todo.owner ?? "", "dueText": todo.dueText ?? ""]),
                    status: .accepted, missionId: nil, idemKey: "\(ingestionId):todo:\(index)",
                    createdAt: now, updatedAt: now
                ))
            }
            if let mission = edited.suggestedMission {
                candidates.append(.init(
                    id: UUID().uuidString, ingestionId: ingestionId, campId: ingestion.campId,
                    type: .mission, title: mission.goal,
                    detailJson: try Self.sortedJSON(MissionDetail(
                        goal: mission.goal, why: mission.why, acceptance: mission.acceptance
                    )),
                    status: .accepted, missionId: nil, idemKey: "\(ingestionId):mission",
                    createdAt: now, updatedAt: now
                ))
            }
            for candidate in candidates { try candidate.insert(database) }

            let (nextResultVersion, resultOverflow) =
                resultVersion.addingReportingOverflow(1)
            guard !resultOverflow else {
                throw InvalidDurableWorkStateError()
            }
            try database.execute(
                sql: """
                    UPDATE rumination_result
                    SET userEditedJson=?,materializedAt=?,updatedAt=?,version=?
                    WHERE id=? AND ingestionId=? AND version=?
                      AND materializedAt IS NULL AND redactedAt IS NULL
                    """,
                arguments: [
                    try RuminationCoding.encode(edited),
                    now,
                    now,
                    nextResultVersion,
                    resultRecord.id,
                    ingestionId,
                    resultVersion,
                ]
            )
            guard database.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
            let (nextIngestionVersion, ingestionOverflow) =
                ingestionVersion.addingReportingOverflow(1)
            guard !ingestionOverflow else {
                throw InvalidDurableWorkStateError()
            }
            try database.execute(
                sql: """
                    UPDATE ingestion_item
                    SET status='materialized',updatedAt=?,version=?
                    WHERE id=? AND campId=? AND version=?
                      AND status='needsReview' AND attempt=?
                      AND terminalReason IS NULL AND redactedAt IS NULL
                    """,
                arguments: [
                    now,
                    nextIngestionVersion,
                    ingestion.id,
                    ingestion.campId,
                    ingestionVersion,
                    ingestion.attempt,
                ]
            )
            guard database.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
            try AppDatabase.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.ruminationMaterialized,
                payload: ["ingestionId": .string(ingestionId), "noteId": .string(note.id)]
            )
            return .init(noteId: note.id, candidateIds: candidates.map(\.id), alreadyMaterialized: false)
        }
    }

    @discardableResult
    private static func requireActiveLifecycle(
        _ database: Database,
        campId: String
    ) throws -> Int {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT lifecycle.state,lifecycle.version,camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let version: Int = row["version"]
        guard let state = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ), state == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: row["state"] as String
                ) ?? .deletedTombstone
            )
        }
        guard (row["archived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        return version
    }

    private static func noteBody(_ value: RuminationResult) -> String {
        var sections = ["AI 整理，可修改", "", value.summary]
        if !value.keyPoints.isEmpty {
            sections += ["", "## 关键点"] + value.keyPoints.map { "- \($0.text)（来源定位：\($0.sourceQuote)）" }
        }
        if !value.uncertainties.isEmpty {
            sections += ["", "## 不确定信息"] + value.uncertainties.map { "- \($0)" }
        }
        return sections.joined(separator: "\n")
    }

    private static func sortedJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private struct MissionDetail: Encodable {
        let goal: String
        let why: String
        let acceptance: [String]
    }
}
