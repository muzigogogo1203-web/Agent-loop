import Foundation
import GRDB

extension AppDatabase {
    public func completeCard(
        id: String,
        runId: String?,
        handoff: HandoffPayload,
        durableArtifacts: [(decl: HandoffPayload.ArtifactDecl, durablePath: String)]
    ) throws {
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "card", id: id)
            }
            guard card.status.canTransition(to: .done) else {
                throw CardTransitionError(from: card.status, to: .done)
            }

            for (decl, durablePath) in durableArtifacts {
                try ArtifactRecord(
                    id: UUID().uuidString,
                    cardId: id,
                    path: durablePath,
                    kind: decl.kind,
                    label: decl.label,
                    createdAt: Date()
                ).insert(db)
            }

            card.status = .done
            card.blockedReasonJson = nil
            try card.update(db)

            let payloadData = try JSONEncoder().encode(handoff)
            let payload = try JSONDecoder().decode(JSONValue.self, from: payloadData)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: id,
                runId: runId,
                kind: "card_completed",
                payload: payload
            )
        }
    }

    public func blockCard(id: String, runId: String?, reason: String, detail: String) throws {
        let payload: JSONValue = ["reason": .string(reason), "detail": .string(detail)]
        let reasonJson = try payload.encodedString()
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "card", id: id)
            }
            guard card.status.canTransition(to: .blocked) else {
                throw CardTransitionError(from: card.status, to: .blocked)
            }

            card.status = .blocked
            card.blockedReasonJson = reasonJson
            try card.update(db)

            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: id,
                runId: runId,
                kind: "card_blocked",
                payload: payload
            )
        }
    }
}
