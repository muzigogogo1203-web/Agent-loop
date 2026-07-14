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

public struct MissionDraftFactory: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    public func draft(candidateId: String) throws -> CodingRanchMissionDraft {
        try db.pool.read { database in
            guard let candidate = try ActionCandidateRecord.fetchOne(database, key: candidateId), candidate.type == .mission,
                  let link = try KnowledgeSourceLinkRecord
                    .filter(Column("ingestionId") == candidate.ingestionId).fetchOne(database) else {
                throw RecordNotFoundError(table: "action_candidate", id: candidateId)
            }
            let detail = try JSONDecoder().decode(MissionDetail.self, from: Data(candidate.detailJson.utf8))
            return .init(
                candidateId: candidate.id, ingestionId: candidate.ingestionId, campId: candidate.campId,
                noteId: link.campNoteId, goal: detail.goal, acceptance: detail.acceptance, why: detail.why
            )
        }
    }

    public func existingMissionId(candidateId: String) throws -> String? {
        try db.pool.read { database in
            try ActionCandidateRecord.fetchOne(database, key: candidateId)?.missionId
        }
    }

    /// Links a Mission created through Orchestrator.startMission back to the candidate.
    /// MainActor callers use this after the existing planner has accepted the mission shell.
    @discardableResult
    public func linkConverted(candidateId: String, missionId: String) throws -> String {
        try db.pool.write { database in
            guard var candidate = try ActionCandidateRecord.fetchOne(database, key: candidateId) else {
                throw RecordNotFoundError(table: "action_candidate", id: candidateId)
            }
            if let existing = candidate.missionId { return existing }
            candidate.status = .converted
            candidate.missionId = missionId
            candidate.updatedAt = Date()
            try candidate.update(database)
            try AppDatabase.appendEvent(
                database, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.actionCandidateConverted,
                payload: ["candidateId": .string(candidate.id), "ingestionId": .string(candidate.ingestionId)]
            )
            return missionId
        }
    }

    /// Atomically creates the existing Mission shell and converts the action candidate.
    /// Repeated calls return the original mission id.
    public func convert(
        _ draft: CodingRanchMissionDraft,
        companionId: String = CowTemplate.baseCowId,
        workspacePath: String? = nil,
        budgetTokens: Int = KernelDefaults.missionBudget
    ) throws -> String {
        try db.pool.write { database in
            guard var candidate = try ActionCandidateRecord.fetchOne(database, key: draft.candidateId) else {
                throw RecordNotFoundError(table: "action_candidate", id: draft.candidateId)
            }
            if candidate.status == .converted, let missionId = candidate.missionId { return missionId }
            guard candidate.status == .accepted, candidate.type == .mission else {
                throw FeedServiceError.invalidState(.materialized)
            }
            guard try CompanionRecord.fetchOne(database, key: companionId) != nil else {
                throw RecordNotFoundError(table: "companion", id: companionId)
            }
            guard let note = try CampNoteRecord.fetchOne(database, key: draft.noteId) else {
                throw RecordNotFoundError(table: "camp_note", id: draft.noteId)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let memberIds = String(decoding: try encoder.encode([companionId]), as: UTF8.self)
            let squad = SquadRecord(
                id: UUID().uuidString, campId: draft.campId,
                name: String(draft.goal.prefix(30)), memberIdsJson: memberIds,
                workspacePath: workspacePath,
                workspaceBookmark: WorkspaceScopedAccess.captureBookmark(forPath: workspacePath),
                createdAt: Date()
            )
            try squad.insert(database)

            let acceptance = draft.acceptance.map { "- [ ] \($0)" }.joined(separator: "\n")
            let sourceBody = String(note.bodyMd.prefix(8_000))
            let goalRaw = """
            \(draft.goal)

            验收清单：
            \(acceptance)

            本次明确引用的营地笔记「\(note.title)」：
            \(sourceBody)
            """
            let mission = MissionRecord(
                id: UUID().uuidString, squadId: squad.id, goalRaw: goalRaw, goalRefined: "",
                status: .planning, budgetTokens: max(1, budgetTokens), spentTokens: 0,
                revision: 1, autonomy: .standard, createdAt: Date()
            )
            try mission.insert(database)
            candidate.status = .converted
            candidate.missionId = mission.id
            candidate.updatedAt = Date()
            try candidate.update(database)
            try AppDatabase.appendEvent(
                database, missionId: mission.id, cardId: nil, runId: nil,
                kind: EventKind.missionCreated,
                payload: ["goal": .string(draft.goal), "sourceNoteId": .string(note.id)]
            )
            try AppDatabase.appendEvent(
                database, missionId: mission.id, cardId: nil, runId: nil,
                kind: EventKind.planStarted, payload: .object([:])
            )
            try AppDatabase.appendEvent(
                database, missionId: mission.id, cardId: nil, runId: nil,
                kind: EventKind.actionCandidateConverted,
                payload: ["candidateId": .string(candidate.id), "ingestionId": .string(candidate.ingestionId)]
            )
            return mission.id
        }
    }

    private struct MissionDetail: Decodable {
        let goal: String
        let why: String
        let acceptance: [String]
    }
}
