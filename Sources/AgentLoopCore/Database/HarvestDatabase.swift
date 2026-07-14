import Foundation
import GRDB

public struct ArtifactLedgerItem: Sendable, Identifiable {
    public var id: String { artifact.id }
    public let artifact: ArtifactRecord
    public let card: CardRecord
    public let mission: MissionRecord
    public let camp: CampRecord

    public init(
        artifact: ArtifactRecord,
        card: CardRecord,
        mission: MissionRecord,
        camp: CampRecord
    ) {
        self.artifact = artifact
        self.card = card
        self.mission = mission
        self.camp = camp
    }
}

public struct ExpeditionReportInput: Sendable {
    public let mission: MissionRecord
    public let squad: SquadRecord
    public let camp: CampRecord
    public let cards: [CardRecord]
    public let artifacts: [ArtifactRecord]
    public let events: [EventRecord]
    public let companions: [String: CompanionRecord]
    public let spend: MissionSpendBreakdown

    public init(
        mission: MissionRecord,
        squad: SquadRecord,
        camp: CampRecord,
        cards: [CardRecord],
        artifacts: [ArtifactRecord],
        events: [EventRecord],
        companions: [String: CompanionRecord],
        spend: MissionSpendBreakdown
    ) {
        self.mission = mission
        self.squad = squad
        self.camp = camp
        self.cards = cards
        self.artifacts = artifacts
        self.events = events
        self.companions = companions
        self.spend = spend
    }
}

extension AppDatabase {
    public func artifactLedger(includeArchived: Bool = true) throws -> [ArtifactLedgerItem] {
        try pool.read { db in
            let artifacts = try ArtifactRecord
                .order(Column("createdAt").desc, Column.rowID.desc)
                .fetchAll(db)
            var items: [ArtifactLedgerItem] = []
            items.reserveCapacity(artifacts.count)

            for artifact in artifacts {
                guard let card = try CardRecord.fetchOne(db, key: artifact.cardId),
                      let mission = try MissionRecord.fetchOne(db, key: card.missionId),
                      let squad = try SquadRecord.fetchOne(db, key: mission.squadId),
                      let camp = try CampRecord.fetchOne(db, key: squad.campId) else {
                    continue
                }
                if !includeArchived && camp.archived { continue }
                items.append(.init(artifact: artifact, card: card, mission: mission, camp: camp))
            }
            return items
        }
    }

    public func expeditionReportInput(missionId: String) throws -> ExpeditionReportInput {
        let spend = try missionSpendBreakdown(missionId: missionId)
        return try pool.read { db in
            guard let mission = try MissionRecord.fetchOne(db, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            guard let squad = try SquadRecord.fetchOne(db, key: mission.squadId) else {
                throw RecordNotFoundError(table: "squad", id: mission.squadId)
            }
            guard let camp = try CampRecord.fetchOne(db, key: squad.campId) else {
                throw RecordNotFoundError(table: "camp", id: squad.campId)
            }

            let cards = try CardRecord
                .filter(Column("missionId") == missionId)
                .order(Column("stage"), Column.rowID)
                .fetchAll(db)
            let artifacts = try ArtifactRecord.fetchAll(
                db,
                sql: """
                    SELECT artifact.*
                    FROM artifact
                    JOIN card ON card.id = artifact.cardId
                    WHERE card.missionId = ?
                    ORDER BY card.stage, artifact.createdAt, artifact.rowid
                    """,
                arguments: [missionId]
            )
            let events = try EventRecord
                .filter(Column("missionId") == missionId)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)

            var companions: [String: CompanionRecord] = [:]
            for companionId in Set(cards.compactMap(\.assigneeId)).sorted() {
                if let companion = try CompanionRecord.fetchOne(db, key: companionId) {
                    companions[companionId] = companion
                }
            }
            return ExpeditionReportInput(
                mission: mission,
                squad: squad,
                camp: camp,
                cards: cards,
                artifacts: artifacts,
                events: events,
                companions: companions,
                spend: spend
            )
        }
    }
}
