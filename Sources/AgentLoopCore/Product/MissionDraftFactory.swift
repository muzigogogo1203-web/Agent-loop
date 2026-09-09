import Foundation
import GRDB

public struct CodingRanchMissionDraft: Sendable, Equatable {
    public let candidateId: String
    public let ingestionId: String
    public let campId: String
    public let noteId: String
    public var goal: String
    public var acceptance: [String]
    public var why: String

    public init(candidateId: String, ingestionId: String, campId: String, noteId: String,
                goal: String, acceptance: [String], why: String) {
        self.candidateId = candidateId; self.ingestionId = ingestionId; self.campId = campId
        self.noteId = noteId; self.goal = goal; self.acceptance = acceptance; self.why = why
    }
}

package struct InputMissionDraftReadBundle: Sendable {
    package let draft: CodingRanchMissionDraft
    package let sourceNote: CampNoteRecord
    package let baseCow: CompanionRecord?

    package init(
        draft: CodingRanchMissionDraft,
        sourceNote: CampNoteRecord,
        baseCow: CompanionRecord?
    ) {
        self.draft = draft
        self.sourceNote = sourceNote
        self.baseCow = baseCow
    }
}

public struct MissionDraftFactory: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    public func draft(candidateId: String) throws -> CodingRanchMissionDraft {
        try db.readInputMissionDraftBundle(candidateId: candidateId).draft
    }

    fileprivate struct MissionDetail: Decodable {
        let goal: String
        let why: String
        let acceptance: [String]
    }
}

extension AppDatabase {
    package func readInputMissionDraftBundle(
        candidateId: String
    ) throws -> InputMissionDraftReadBundle {
        try pool.read { database in
            try Self.inputMissionDraftBundle(
                candidateId: candidateId,
                in: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readInputMissionDraftBundleForTesting(
        candidateId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputMissionDraftReadBundle {
        try pool.read { database in
            try Self.inputMissionDraftBundle(
                candidateId: candidateId,
                in: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    package func readInputMissionDraftBundle(
        ingestionId: String
    ) throws -> InputMissionDraftReadBundle {
        try pool.read { database in
            try Self.inputMissionDraftBundle(
                ingestionId: ingestionId,
                in: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readInputMissionDraftBundleForTesting(
        ingestionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputMissionDraftReadBundle {
        try pool.read { database in
            try Self.inputMissionDraftBundle(
                ingestionId: ingestionId,
                in: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func inputMissionDraftBundle(
        ingestionId: String,
        in database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputMissionDraftReadBundle {
        guard try IngestionItemRecord.fetchOne(
            database,
            key: ingestionId
        ) != nil else {
            throw RecordNotFoundError(
                table: IngestionItemRecord.databaseTableName,
                id: ingestionId
            )
        }
        afterAnchorRead()
        let candidates = try ActionCandidateRecord
            .filter(
                Column("ingestionId") == ingestionId
                    && Column("type") == ActionCandidateType.mission.rawValue
            )
            .order(Column("createdAt"), Column.rowID)
            .limit(2)
            .fetchAll(database)
        guard candidates.count == 1, let candidate = candidates.first
        else {
            if candidates.isEmpty {
                throw RecordNotFoundError(
                    table: "action_candidate(mission)",
                    id: ingestionId
                )
            }
            throw ProjectionContractError.invalidPayload
        }
        return try inputMissionDraftBundle(
            candidateId: candidate.id,
            in: database,
            afterAnchorRead: {}
        )
    }

    private static func inputMissionDraftBundle(
        candidateId: String,
        in database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputMissionDraftReadBundle {
        guard let candidate = try ActionCandidateRecord.fetchOne(
            database,
            key: candidateId
        ), candidate.type == .mission else {
            throw RecordNotFoundError(
                table: "action_candidate",
                id: candidateId
            )
        }
        afterAnchorRead()
        let links = try KnowledgeSourceLinkRecord
            .filter(Column("ingestionId") == candidate.ingestionId)
            .order(Column("createdAt"), Column.rowID)
            .limit(2)
            .fetchAll(database)
        guard links.count == 1, let link = links.first else {
            if links.isEmpty {
                throw RecordNotFoundError(
                    table: KnowledgeSourceLinkRecord.databaseTableName,
                    id: candidate.ingestionId
                )
            }
            throw ProjectionContractError.invalidPayload
        }
        guard let sourceNote = try CampNoteRecord.fetchOne(
            database,
            key: link.campNoteId
        ), sourceNote.campId == candidate.campId else {
            throw RecordNotFoundError(
                table: CampNoteRecord.databaseTableName,
                id: link.campNoteId
            )
        }
        let detail: MissionDraftFactory.MissionDetail
        do {
            detail = try JSONDecoder().decode(
                MissionDraftFactory.MissionDetail.self,
                from: Data(candidate.detailJson.utf8)
            )
        } catch {
            throw ProjectionContractError.invalidPayload
        }
        guard !detail.goal.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        !detail.acceptance.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw ProjectionContractError.invalidPayload
        }
        let draft = CodingRanchMissionDraft(
            candidateId: candidate.id,
            ingestionId: candidate.ingestionId,
            campId: candidate.campId,
            noteId: link.campNoteId,
            goal: detail.goal,
            acceptance: detail.acceptance,
            why: detail.why
        )
        return InputMissionDraftReadBundle(
            draft: draft,
            sourceNote: sourceNote,
            baseCow: try CompanionRecord.fetchOne(
                database,
                key: CowTemplate.baseCowId
            )
        )
    }
}
