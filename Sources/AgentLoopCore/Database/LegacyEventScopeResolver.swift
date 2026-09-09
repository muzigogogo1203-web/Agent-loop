import Foundation
import GRDB

package enum LegacyEventScopeResolverV1 {
    private enum Rule {
        case globalKernel
        case payloadCamp
        case cowInCamp
        case ingestion
        case rumination
        case materialized
        case campNote
        case companionNote
        case scheduleMissed
        case kernelError
        case referenceGraph
    }

    private static let rules: [String: Rule] = [
        EventKind.campHalted: .globalKernel,
        EventKind.campResumed: .globalKernel,
        EventKind.campArchived: .payloadCamp,
        EventKind.baseCowProvisioned: .cowInCamp,
        EventKind.cowUnlocked: .cowInCamp,
        EventKind.ingestionCreated: .ingestion,
        EventKind.ruminationCompleted: .rumination,
        EventKind.ruminationFailed: .rumination,
        EventKind.ruminationMaterialized: .materialized,
        EventKind.campNoteCreated: .campNote,
        EventKind.companionNoteCreated: .companionNote,
        EventKind.scheduleMissed: .scheduleMissed,
        EventKind.cardStarted: .referenceGraph,
        EventKind.cardCompleted: .referenceGraph,
        EventKind.cardBlocked: .referenceGraph,
        EventKind.cardReady: .referenceGraph,
        EventKind.cardCanceled: .referenceGraph,
        EventKind.cardInterrupted: .referenceGraph,
        EventKind.missionCreated: .referenceGraph,
        EventKind.missionStatusChanged: .referenceGraph,
        EventKind.missionAccepted: .referenceGraph,
        EventKind.missionFailed: .referenceGraph,
        EventKind.missionBudgetExhausted: .referenceGraph,
        EventKind.planStarted: .referenceGraph,
        EventKind.planCompleted: .referenceGraph,
        EventKind.planNoop: .referenceGraph,
        EventKind.planFallback: .referenceGraph,
        EventKind.planningTokens: .referenceGraph,
        EventKind.planningUsageOverflow: .referenceGraph,
        EventKind.runError: .referenceGraph,
        EventKind.progressNote: .referenceGraph,
        EventKind.kernelError: .kernelError,
        EventKind.budgetAdded: .referenceGraph,
        EventKind.approvalRequested: .referenceGraph,
        EventKind.approvalDecided: .referenceGraph,
        EventKind.autonomyChanged: .referenceGraph,
        EventKind.rateLimitCooldown: .referenceGraph,
        EventKind.userRequestCreated: .referenceGraph,
        EventKind.userRequestAnswered: .referenceGraph,
        EventKind.squadProposalConfirmed: .referenceGraph,
        EventKind.actionCandidateConverted: .referenceGraph,
        EventKind.mcpServerDown: .referenceGraph,
        EventKind.cardReturned: .referenceGraph,
        EventKind.cardReviewCleared: .referenceGraph,
        EventKind.scheduleFired: .referenceGraph,
    ]

    package static var resolverKeys: Set<String> {
        Set(rules.keys)
    }

    package static func backfill(in database: Database) throws {
        guard resolverKeys == EventKind.allPersistedKinds else {
            throw P1EMigrationIntegrityError(
                code: "event_vocabulary_mismatch",
                subject: "persisted=\(EventKind.allPersistedKinds.count),resolver=\(resolverKeys.count)"
            )
        }
        let events = try EventRecord
            .order(Column("createdAt"), Column("id"))
            .fetchAll(database)
        for event in events {
            let scope = try resolve(event, in: database)
            try database.execute(
                sql: """
                    INSERT INTO camp_event_scope(
                      sourceTable,eventId,scopeKind,campId,payloadRedactedAt
                    ) VALUES ('event',?,?,?,NULL)
                    """,
                arguments: [event.id, scope.kind, scope.campID]
            )
        }
    }

    package static func resolve(
        _ event: EventRecord,
        in database: Database
    ) throws -> (kind: String, campID: String?) {
        guard let rule = rules[event.kind] else {
            throw P1EMigrationIntegrityError(
                code: "legacy_event_unknown_kind",
                subject: "\(event.id):\(event.kind)"
            )
        }
        let payload = try payloadObject(event)
        if case .globalKernel = rule {
            let forbiddenKeys = [
                "campId", "missionId", "cardId", "runId", "ingestionId",
                "noteId", "scheduleId", "templateId",
            ]
            guard event.missionId == nil,
                  event.cardId == nil,
                  event.runId == nil,
                  forbiddenKeys.allSatisfy({ payload[$0] == nil })
            else {
                throw P1EMigrationIntegrityError(
                    code: "global_event_has_camp_evidence",
                    subject: event.id
                )
            }
            return ("global", nil)
        }

        if case .kernelError = rule {
            let scopeEvidenceKeys = [
                "campId", "missionId", "cardId", "runId", "ingestionId",
                "noteId", "scheduleId", "templateId",
            ]
            let hasReferenceEvidence = event.cardId != nil
                || event.runId != nil
                || scopeEvidenceKeys.contains { payload[$0] != nil }
            if event.missionId == "" {
                guard !hasReferenceEvidence else {
                    throw P1EMigrationIntegrityError(
                        code: "global_event_has_camp_evidence",
                        subject: event.id
                    )
                }
                return ("global", nil)
            }
            if event.missionId == nil, !hasReferenceEvidence {
                return ("global", nil)
            }
        }

        var candidates = Set<String>()
        switch rule {
        case .payloadCamp:
            try addRequiredPayloadCamp(
                payload,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        case .cowInCamp:
            try addRequiredPayloadCamp(
                payload,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
            let cowID = try requiredPayloadString(
                payload,
                keys: ["companionId", "cowId"],
                eventID: event.id
            )
            let cowCamp = try String.fetchOne(
                database,
                sql: "SELECT campId FROM companion WHERE id=?",
                arguments: [cowID]
            )
            guard let cowCamp else {
                throw P1EMigrationIntegrityError(
                    code: "event_cow_missing_camp",
                    subject: event.id
                )
            }
            candidates.insert(cowCamp)
        case .ingestion, .rumination:
            let ingestionID = try requiredPayloadString(
                payload,
                keys: ["ingestionId"],
                eventID: event.id
            )
            try addIngestionCamp(
                ingestionID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
            try addOptionalPayloadCamp(
                payload,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        case .materialized:
            let ingestionID = try requiredPayloadString(
                payload,
                keys: ["ingestionId"],
                eventID: event.id
            )
            try addIngestionCamp(
                ingestionID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
            let noteID = try requiredPayloadString(
                payload,
                keys: ["noteId"],
                eventID: event.id
            )
            try addCampNoteCamp(
                noteID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        case .campNote:
            let noteID = try requiredPayloadString(
                payload,
                keys: ["noteId"],
                eventID: event.id
            )
            try addCampNoteCamp(
                noteID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        case .companionNote:
            let noteID = try requiredPayloadString(
                payload,
                keys: ["noteId"],
                eventID: event.id
            )
            let scope = try Row.fetchOne(
                database,
                sql: "SELECT scopeKind,campId FROM legacy_companion_note_scope WHERE noteId=?",
                arguments: [noteID]
            )
            guard let scope else {
                throw P1EMigrationIntegrityError(
                    code: "event_note_scope_missing",
                    subject: event.id
                )
            }
            let scopeKind: String = scope["scopeKind"]
            let campID: String? = scope["campId"]
            if scopeKind == "globalCow" {
                guard event.missionId == nil,
                      event.cardId == nil,
                      event.runId == nil,
                      campID == nil
                else {
                    throw P1EMigrationIntegrityError(
                        code: "global_note_event_has_camp_evidence",
                        subject: event.id
                    )
                }
                return ("global", nil)
            }
            guard scopeKind == "camp", let campID else {
                throw P1EMigrationIntegrityError(
                    code: "event_note_scope_malformed",
                    subject: event.id
                )
            }
            candidates.insert(campID)
        case .scheduleMissed:
            let templateID = try requiredPayloadString(
                payload,
                keys: ["templateId"],
                eventID: event.id
            )
            try addTemplateCamp(
                templateID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
            if let scheduleID = try optionalPayloadString(
                payload,
                key: "scheduleId",
                eventID: event.id
            ) {
                let scheduleTemplate = try String.fetchOne(
                    database,
                    sql: "SELECT templateId FROM schedule WHERE id=?",
                    arguments: [scheduleID]
                )
                guard scheduleTemplate == templateID else {
                    throw P1EMigrationIntegrityError(
                        code: "event_schedule_template_mismatch",
                        subject: event.id
                    )
                }
            }
        case .kernelError, .referenceGraph:
            try addReferenceGraphCamps(
                event,
                payload: payload,
                candidates: &candidates,
                database: database
            )
        case .globalKernel:
            preconditionFailure("global kernel handled before Camp resolution")
        }
        guard candidates.count == 1, let campID = candidates.first else {
            throw P1EMigrationIntegrityError(
                code: candidates.isEmpty
                    ? "legacy_event_missing_camp"
                    : "legacy_event_cross_camp",
                subject: event.id
            )
        }
        return ("camp", campID)
    }

    private static func addReferenceGraphCamps(
        _ event: EventRecord,
        payload: [String: Any],
        candidates: inout Set<String>,
        database: Database
    ) throws {
        if let missionID = event.missionId {
            try addMissionCamp(
                missionID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        }
        if let cardID = event.cardId {
            let missionID = try String.fetchOne(
                database,
                sql: "SELECT missionId FROM card WHERE id=?",
                arguments: [cardID]
            )
            guard let missionID else {
                throw P1EMigrationIntegrityError(
                    code: "event_card_dangling",
                    subject: event.id
                )
            }
            try addMissionCamp(
                missionID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        }
        if let runID = event.runId {
            let missionID = try String.fetchOne(
                database,
                sql: """
                    SELECT card.missionId FROM run
                    JOIN card ON card.id=run.cardId WHERE run.id=?
                    """,
                arguments: [runID]
            )
            guard let missionID else {
                throw P1EMigrationIntegrityError(
                    code: "event_run_dangling",
                    subject: event.id
                )
            }
            try addMissionCamp(
                missionID,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        }
        if let payloadMission = try optionalPayloadString(
            payload,
            key: "missionId",
            eventID: event.id
        ) {
            try addMissionCamp(
                payloadMission,
                eventID: event.id,
                candidates: &candidates,
                database: database
            )
        }
        try addOptionalPayloadCamp(
            payload,
            eventID: event.id,
            candidates: &candidates,
            database: database
        )
    }

    private static func addMissionCamp(
        _ missionID: String,
        eventID: String,
        candidates: inout Set<String>,
        database: Database
    ) throws {
        let campID = try String.fetchOne(
            database,
            sql: """
                SELECT squad.campId FROM mission
                JOIN squad ON squad.id=mission.squadId WHERE mission.id=?
                """,
            arguments: [missionID]
        )
        guard let campID else {
            throw P1EMigrationIntegrityError(
                code: "event_mission_dangling",
                subject: eventID
            )
        }
        candidates.insert(campID)
    }

    private static func addIngestionCamp(
        _ ingestionID: String,
        eventID: String,
        candidates: inout Set<String>,
        database: Database
    ) throws {
        let campID = try String.fetchOne(
            database,
            sql: "SELECT campId FROM ingestion_item WHERE id=?",
            arguments: [ingestionID]
        )
        guard let campID else {
            throw P1EMigrationIntegrityError(
                code: "event_ingestion_dangling",
                subject: eventID
            )
        }
        candidates.insert(campID)
    }

    private static func addCampNoteCamp(
        _ noteID: String,
        eventID: String,
        candidates: inout Set<String>,
        database: Database
    ) throws {
        let campID = try String.fetchOne(
            database,
            sql: "SELECT campId FROM camp_note WHERE id=?",
            arguments: [noteID]
        )
        guard let campID else {
            throw P1EMigrationIntegrityError(
                code: "event_camp_note_dangling",
                subject: eventID
            )
        }
        candidates.insert(campID)
    }

    private static func addTemplateCamp(
        _ templateID: String,
        eventID: String,
        candidates: inout Set<String>,
        database: Database
    ) throws {
        let campID = try String.fetchOne(
            database,
            sql: "SELECT campId FROM mission_template WHERE id=?",
            arguments: [templateID]
        )
        guard let campID else {
            throw P1EMigrationIntegrityError(
                code: "event_template_dangling",
                subject: eventID
            )
        }
        candidates.insert(campID)
    }

    private static func addRequiredPayloadCamp(
        _ payload: [String: Any],
        eventID: String,
        candidates: inout Set<String>,
        database: Database
    ) throws {
        let campID = try requiredPayloadString(
            payload,
            keys: ["campId"],
            eventID: eventID
        )
        let exists = try Bool.fetchOne(
            database,
            sql: "SELECT EXISTS(SELECT 1 FROM camp WHERE id=?)",
            arguments: [campID]
        ) ?? false
        guard exists else {
            throw P1EMigrationIntegrityError(
                code: "event_camp_dangling",
                subject: eventID
            )
        }
        candidates.insert(campID)
    }

    private static func addOptionalPayloadCamp(
        _ payload: [String: Any],
        eventID: String,
        candidates: inout Set<String>,
        database: Database
    ) throws {
        guard let campID = try optionalPayloadString(
            payload,
            key: "campId",
            eventID: eventID
        ) else { return }
        let exists = try Bool.fetchOne(
            database,
            sql: "SELECT EXISTS(SELECT 1 FROM camp WHERE id=?)",
            arguments: [campID]
        ) ?? false
        guard exists else {
            throw P1EMigrationIntegrityError(
                code: "event_camp_dangling",
                subject: eventID
            )
        }
        candidates.insert(campID)
    }

    private static func payloadObject(
        _ event: EventRecord
    ) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(
            with: Data(event.payloadJson.utf8)
        ) as? [String: Any] else {
            throw P1EMigrationIntegrityError(
                code: "legacy_event_payload_not_object",
                subject: event.id
            )
        }
        return object
    }

    private static func requiredPayloadString(
        _ payload: [String: Any],
        keys: [String],
        eventID: String
    ) throws -> String {
        let values = try keys.compactMap {
            try optionalPayloadString(payload, key: $0, eventID: eventID)
        }
        guard values.count == 1, let value = values.first else {
            throw P1EMigrationIntegrityError(
                code: "event_payload_required_ref",
                subject: eventID
            )
        }
        return value
    }

    private static func optionalPayloadString(
        _ payload: [String: Any],
        key: String,
        eventID: String
    ) throws -> String? {
        guard let value = payload[key] else { return nil }
        guard let string = value as? String, !string.isEmpty else {
            throw P1EMigrationIntegrityError(
                code: "event_payload_ref_malformed",
                subject: "\(eventID):\(key)"
            )
        }
        return string
    }
}

extension AppDatabase {
    @discardableResult
    package static func appendLegacyEventAndScope(
        _ database: Database,
        missionId: String?,
        cardId: String?,
        runId: String?,
        kind: String,
        payload: JSONValue
    ) throws -> EventRecord {
        let payloadJSON = String(
            decoding: try CanonicalJSONV1.encode(payload),
            as: UTF8.self
        )
        return try appendLegacyEventAndScope(
            database,
            missionId: missionId,
            cardId: cardId,
            runId: runId,
            kind: kind,
            payloadJSON: payloadJSON,
            createdAt: Date()
        )
    }

    @discardableResult
    package static func appendLegacyEventAndScope(
        _ database: Database,
        missionId: String?,
        cardId: String?,
        runId: String?,
        kind: String,
        payloadJSON: String,
        createdAt: Date
    ) throws -> EventRecord {
        try CanonicalJSONV1.validateCanonical(
            rawUTF8: Data(payloadJSON.utf8)
        )
        try CanonicalContractCodingV1.validateFinite(createdAt)
        let event = EventRecord(
            id: UUID().uuidString,
            missionId: missionId,
            cardId: cardId,
            runId: runId,
            kind: kind,
            payloadJson: payloadJSON,
            createdAt: createdAt
        )
        let scope = try LegacyEventScopeResolverV1.resolve(
            event,
            in: database
        )
        try database.execute(
            sql: """
                INSERT INTO camp_event_scope(
                  sourceTable,eventId,scopeKind,campId,payloadRedactedAt
                ) VALUES ('event',?,?,?,NULL)
                """,
            arguments: [event.id, scope.kind, scope.campID]
        )
        try event.insert(database)
        return event
    }
}
