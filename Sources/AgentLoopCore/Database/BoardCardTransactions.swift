import Foundation
import GRDB

extension AppDatabase {
    public func completeCard(
        id: String,
        runId: String?,
        handoff: HandoffPayload
    ) throws {
        try pool.write { db in
            try completeCard(db, id: id, runId: runId, handoff: handoff)
        }
    }

    public func completeCard(
        id: String,
        runId: String?,
        handoff: HandoffPayload,
        durableArtifacts: [Never]
    ) throws {
        guard durableArtifacts.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }
        try completeCard(id: id, runId: runId, handoff: handoff)
    }

    package func completeCard(
        id: String,
        runId: String?,
        handoff: HandoffPayload,
        workspaceExternalArtifacts: [WorkspaceExternalArtifactReferenceV1]
    ) throws {
        try pool.write { db in
            try completeCard(
                db,
                id: id,
                runId: runId,
                handoff: handoff,
                workspaceExternalArtifacts: workspaceExternalArtifacts
            )
        }
    }

    func completeCard(
        _ db: Database,
        id: String,
        runId: String?,
        handoff: HandoffPayload
    ) throws {
        guard handoff.artifacts.isEmpty else {
            throw P1ContractValidationError.invalidMembership
        }
        let card = try cardForCompletion(db, id: id)
        try finishCardCompletion(
            db,
            card: card,
            runId: runId,
            handoff: handoff
        )
    }

    func completeCard(
        _ db: Database,
        id: String,
        runId: String?,
        handoff: HandoffPayload,
        workspaceExternalArtifacts: [WorkspaceExternalArtifactReferenceV1]
    ) throws {
        guard !handoff.artifacts.isEmpty,
              handoff.artifacts.count == workspaceExternalArtifacts.count
        else {
            throw P1ContractValidationError.invalidMembership
        }
        for (declaration, reference) in zip(
            handoff.artifacts,
            workspaceExternalArtifacts
        ) {
            guard reference.cardId == id,
                  reference.kind == declaration.kind,
                  reference.label == declaration.label
            else {
                throw P1ContractValidationError.invalidValue
            }
        }

        let card = try cardForCompletion(db, id: id)
        let isRework = try EventRecord
            .filter(Column("cardId") == id && Column("kind") == EventKind.cardReturned)
            .fetchCount(db) > 0
        let originStore = ArtifactStorageOriginStore(database: self)

        for (declaration, reference) in zip(
            handoff.artifacts,
            workspaceExternalArtifacts
        ) {
            let label = isRework && !declaration.label.contains("重做")
                ? "\(declaration.label) (重做)"
                : declaration.label
            let classifiedReference = try WorkspaceExternalArtifactReferenceV1
                .explicit(
                    cardId: id,
                    path: reference.path,
                    kind: declaration.kind,
                    label: label,
                    classifiedAt: reference.classifiedAt
                )
            _ = try originStore.insertWorkspaceExternalArtifact(
                classifiedReference,
                database: db
            )
        }

        try finishCardCompletion(
            db,
            card: card,
            runId: runId,
            handoff: handoff
        )
    }

    private func cardForCompletion(
        _ db: Database,
        id: String
    ) throws -> CardRecord {
        guard let card = try CardRecord.fetchOne(db, key: id) else {
            throw RecordNotFoundError(table: "card", id: id)
        }
        guard card.status.canTransition(to: .done) else {
            throw CardTransitionError(from: card.status, to: .done)
        }
        return card
    }

    private func finishCardCompletion(
        _ db: Database,
        card originalCard: CardRecord,
        runId: String?,
        handoff: HandoffPayload
    ) throws {
        var card = originalCard
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        card.handoffJson = String(data: try encoder.encode(handoff), encoding: .utf8)
        card.status = .done
        card.blockedReasonJson = nil
        try card.update(db)

        let payloadData = try encoder.encode(handoff)
        let payload = try JSONDecoder().decode(JSONValue.self, from: payloadData)
        try Self.appendEvent(
            db,
            missionId: card.missionId,
            cardId: card.id,
            runId: runId,
            kind: EventKind.cardCompleted,
            payload: payload
        )
        try rollupMission(db, missionId: card.missionId)
    }

    public func blockCard(id: String, runId: String?, reason: String, detail: String) throws {
        let payload: JSONValue = ["reason": .string(reason), "detail": .string(detail)]
        let reasonJson = try payload.encodedString()
        try pool.write { db in
            try blockCard(db, id: id, runId: runId, reason: reason,
                          detail: detail, payload: payload, reasonJson: reasonJson)
        }
    }

    func blockCard(_ db: Database, id: String, runId: String?, reason: String, detail: String,
                   payload: JSONValue? = nil, reasonJson: String? = nil) throws {
        let payload = payload ?? ["reason": .string(reason), "detail": .string(detail)]
        let reasonJson = try reasonJson ?? payload.encodedString()
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
            kind: EventKind.cardBlocked,
            payload: payload
        )
        try rollupMission(db, missionId: card.missionId)
    }
}
