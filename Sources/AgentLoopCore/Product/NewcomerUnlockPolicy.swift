import Foundation
import GRDB

public struct NewcomerProgress: Sendable, Equatable {
    public let hasMaterializedKnowledge: Bool
    public let hasReferencedMission: Bool
    public let hasArtifact: Bool
    public let hasUserConfirmation: Bool
    public let hasAcceptedMission: Bool
    public let isTestCowOwned: Bool

    public init(
        hasMaterializedKnowledge: Bool,
        hasReferencedMission: Bool,
        hasArtifact: Bool,
        hasUserConfirmation: Bool,
        hasAcceptedMission: Bool,
        isTestCowOwned: Bool
    ) {
        self.hasMaterializedKnowledge = hasMaterializedKnowledge
        self.hasReferencedMission = hasReferencedMission
        self.hasArtifact = hasArtifact
        self.hasUserConfirmation = hasUserConfirmation
        self.hasAcceptedMission = hasAcceptedMission
        self.isTestCowOwned = isTestCowOwned
    }

    public var eligible: Bool {
        hasMaterializedKnowledge && hasReferencedMission && hasArtifact && hasUserConfirmation && hasAcceptedMission
    }
}

public enum NewcomerUnlockError: Error, Sendable, Equatable { case notEligible }

public struct NewcomerUnlockPolicy: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    public func progress(campId: String) throws -> NewcomerProgress {
        try db.pool.read { database in try Self.progress(database: database, campId: campId) }
    }

    /// Inserts the stable test-cow template and its domain event in one transaction.
    public func unlockTestCow(campId: String) throws -> CompanionRecord {
        try db.pool.write { database in
            if let existing = try CompanionRecord.fetchOne(database, key: CowTemplate.testCowId) { return existing }
            guard try Self.progress(database: database, campId: campId).eligible else {
                throw NewcomerUnlockError.notEligible
            }
            let cow = CowTemplate.testCow(campId: campId)
            try cow.insert(database)
            _ = try CowResidencyStore.synchronizeCompanion(
                cow,
                provisionActiveResidency: true,
                database: database
            )
            try AppDatabase.appendEvent(
                database, missionId: nil, cardId: nil, runId: nil,
                kind: EventKind.cowUnlocked,
                payload: ["campId": .string(campId), "cowId": .string(cow.id)]
            )
            return cow
        }
    }

    package static func progress(
        database: Database,
        campId: String
    ) throws -> NewcomerProgress {
        let materialized = try Bool.fetchOne(database, sql: """
            SELECT EXISTS(
              SELECT 1 FROM knowledge_source_link k
              JOIN ingestion_item i ON i.id = k.ingestionId
              WHERE i.campId = ? AND i.status = 'materialized'
            )
            """, arguments: [campId]) ?? false
        let referenced = try Bool.fetchOne(database, sql: """
            SELECT EXISTS(
              SELECT 1 FROM action_candidate a
              JOIN knowledge_source_link k ON k.ingestionId = a.ingestionId
              WHERE a.campId = ? AND a.status = 'converted' AND a.missionId IS NOT NULL
            )
            """, arguments: [campId]) ?? false
        let artifact = try Bool.fetchOne(database, sql: """
            SELECT EXISTS(
              SELECT 1 FROM action_candidate a
              JOIN card c ON c.missionId = a.missionId
              JOIN artifact x ON x.cardId = c.id
              WHERE a.campId = ? AND a.status = 'converted'
            )
            """, arguments: [campId]) ?? false
        let confirmation = try Bool.fetchOne(database, sql: """
            SELECT EXISTS(
              SELECT 1 FROM event e
              JOIN action_candidate a ON a.missionId = e.missionId
              WHERE a.campId = ? AND e.kind IN ('rumination_materialized', 'mission_accepted')
            ) OR EXISTS(
              SELECT 1 FROM ingestion_item i
              JOIN event e ON e.kind = 'rumination_materialized'
                AND json_extract(e.payloadJson, '$.ingestionId') = i.id
              WHERE i.campId = ?
            )
            """, arguments: [campId, campId]) ?? false
        let accepted = try Bool.fetchOne(database, sql: """
            SELECT EXISTS(
              SELECT 1 FROM action_candidate a
              JOIN mission m ON m.id = a.missionId
              WHERE a.campId = ? AND a.status = 'converted' AND m.status = 'accepted'
            )
            """, arguments: [campId]) ?? false
        let owned = try CompanionRecord.fetchOne(database, key: CowTemplate.testCowId) != nil
        return .init(
            hasMaterializedKnowledge: materialized,
            hasReferencedMission: referenced,
            hasArtifact: artifact,
            hasUserConfirmation: confirmation,
            hasAcceptedMission: accepted,
            isTestCowOwned: owned
        )
    }
}
