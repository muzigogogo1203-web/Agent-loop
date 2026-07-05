import Foundation
import GRDB

// MARK: - AppDatabase

public final class AppDatabase: Sendable {
    public let pool: DatabasePool

    public init(path: String) throws {
        var cfg = Configuration()
        cfg.journalMode = .wal
        pool = try DatabasePool(path: path, configuration: cfg)
        try migrator.migrate(pool)
    }

    // MARK: Migration v1 — all spec §4.2 tables (forward-compatible; M1 uses a subset)

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            // camp
            try db.create(table: "camp") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // companion
            try db.create(table: "companion") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("color", .text).notNull()
                t.column("rolePrompt", .text).notNull()
                t.column("model", .text).notNull()
                t.column("toolsJson", .text).notNull()
                t.column("kind", .text).notNull().defaults(to: "regular")
                t.column("campId", .text).references("camp")
                t.column("createdAt", .datetime).notNull()
            }
            // squad
            try db.create(table: "squad") { t in
                t.primaryKey("id", .text)
                t.column("campId", .text).notNull().references("camp")
                t.column("name", .text).notNull()
                t.column("memberIdsJson", .text).notNull()
                t.column("workspacePath", .text)
                t.column("createdAt", .datetime).notNull()
            }
            // mission
            try db.create(table: "mission") { t in
                t.primaryKey("id", .text)
                t.column("squadId", .text).notNull().references("squad")
                t.column("goalRaw", .text).notNull()
                t.column("goalRefined", .text).notNull()
                t.column("status", .text).notNull()
                t.column("budgetTokens", .integer).notNull()
                t.column("spentTokens", .integer).notNull().defaults(to: 0)
                t.column("revision", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull()
            }
            // card
            try db.create(table: "card") { t in
                t.primaryKey("id", .text)
                t.column("missionId", .text).notNull().references("mission")
                t.column("idemKey", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("descriptionText", .text).notNull()
                t.column("expectedOutput", .text).notNull()
                t.column("assigneeId", .text)
                t.column("status", .text).notNull()
                t.column("blockedReasonJson", .text)
                t.column("dependsOnJson", .text).notNull().defaults(to: "[]")
                t.column("maxTurns", .integer).notNull()
                t.column("tokenBudget", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // run
            try db.create(table: "run") { t in
                t.primaryKey("id", .text)
                t.column("cardId", .text).notNull().references("card")
                t.column("attempt", .integer).notNull()
                t.column("outcome", .text)
                t.column("turns", .integer).notNull().defaults(to: 0)
                t.column("tokensIn", .integer).notNull().defaults(to: 0)
                t.column("tokensOut", .integer).notNull().defaults(to: 0)
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
            }
            // event (append-only — never UPDATE/DELETE)
            try db.create(table: "event") { t in
                t.primaryKey("id", .text)
                t.column("missionId", .text)
                t.column("cardId", .text)
                t.column("runId", .text)
                t.column("kind", .text).notNull()
                t.column("payloadJson", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // artifact
            try db.create(table: "artifact") { t in
                t.primaryKey("id", .text)
                t.column("cardId", .text).notNull().references("card")
                t.column("path", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("label", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // camp_note (M1 schema-only — not read/written in M1)
            try db.create(table: "camp_note") { t in
                t.primaryKey("id", .text)
                t.column("campId", .text).notNull().references("camp")
                t.column("missionId", .text).references("mission") // FK Fix 5
                t.column("title", .text).notNull()
                t.column("bodyMd", .text).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            // user_request (M1 schema-only — not read/written in M1)
            try db.create(table: "user_request") { t in
                t.primaryKey("id", .text)
                t.column("cardId", .text).notNull().references("card")
                t.column("kind", .text).notNull()
                t.column("prompt", .text).notNull()
                t.column("optionsJson", .text)
                t.column("answerJson", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("answeredAt", .datetime)
            }
            // chat_thread (Fix 5: campId FK)
            try db.create(table: "chat_thread") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("companionId", .text).notNull().references("companion")
                t.column("campId", .text).references("camp") // FK Fix 5
                t.column("createdAt", .datetime).notNull()
            }
            // chat_message
            try db.create(table: "chat_message") { t in
                t.primaryKey("id", .text)
                t.column("threadId", .text).notNull().references("chat_thread").indexed() // Fix 5: index
                t.column("role", .text).notNull()
                t.column("contentJson", .text).notNull()
                t.column("distilled", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }

            // Fix 5: additional indexes for hot query paths
            try db.create(index: "event_cardId", on: "event", columns: ["cardId"])
            try db.create(index: "run_cardId", on: "run", columns: ["cardId"])
            try db.create(index: "artifact_cardId", on: "artifact", columns: ["cardId"])

            // Fix 5: append-only enforcement for event table via SQLite triggers
            try db.execute(sql: """
                CREATE TRIGGER event_no_update BEFORE UPDATE ON event BEGIN
                    SELECT RAISE(ABORT, 'event is append-only');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER event_no_delete BEFORE DELETE ON event BEGIN
                    SELECT RAISE(ABORT, 'event is append-only');
                END
                """)
        }
        return m
    }

    // MARK: Bootstrap (idempotent)

    @discardableResult
    public func ensureDefaultCamp() throws -> CampRecord {
        try pool.write { db in
            if let camp = try CampRecord.fetchOne(db) { return camp }
            let camp = CampRecord(id: UUID().uuidString, name: "我的营地", createdAt: Date())
            try camp.insert(db)
            var guide = CompanionRecord.new(
                name: "向导", color: "amber",
                rolePrompt: "你是这个营地的向导，熟悉营地里的一切。",
                model: "claude-sonnet-4-6", kind: .guide, campId: camp.id)
            guide.toolsJson = "[]"
            try guide.insert(db)
            return camp
        }
    }

    public func guide(campId: String) throws -> CompanionRecord? {
        try pool.read { db in
            try CompanionRecord
                .filter(Column("campId") == campId && Column("kind") == "guide")
                .fetchOne(db)
        }
    }

    // MARK: Companion CRUD

    public func saveCompanion(_ c: CompanionRecord) throws { // Fix 7: drop inout
        try pool.write { db in try c.save(db) }
    }

    public func companion(id: String) throws -> CompanionRecord? {
        try pool.read { db in try CompanionRecord.fetchOne(db, key: id) }
    }

    public func regularCompanions() throws -> [CompanionRecord] {
        try pool.read { db in
            try CompanionRecord
                .filter(Column("kind") == "regular")
                .order(Column("createdAt"))
                .fetchAll(db)
        }
    }

    // MARK: Single-card mission (camp + squad + mission + card + event in one write tx)

    public struct SingleCardIds: Sendable {
        public let missionId: String
        public let cardId: String
        public let squadId: String
    }

    public func createSingleCardMission(
        campName: String,
        squadName: String,
        goal: String,
        cardTitle: String,
        cardDescription: String,
        expectedOutput: String,
        assigneeId: String?,
        maxTurns: Int,
        workspacePath: String? = nil,
        tokenBudget: Int = 200_000
    ) throws -> SingleCardIds {
        let camp = try ensureDefaultCamp()
        return try pool.write { db in
            let squad = SquadRecord(
                id: UUID().uuidString, campId: camp.id, name: squadName,
                memberIdsJson: "[]", workspacePath: workspacePath, createdAt: Date())
            try squad.insert(db)

            let mission = MissionRecord(
                id: UUID().uuidString, squadId: squad.id, goalRaw: goal,
                goalRefined: goal, status: "executing",
                budgetTokens: tokenBudget, spentTokens: 0, revision: 1, createdAt: Date())
            try mission.insert(db)

            let card = CardRecord(
                id: UUID().uuidString, missionId: mission.id,
                idemKey: "mission:\(mission.id):stage-1",
                title: cardTitle, descriptionText: cardDescription,
                expectedOutput: expectedOutput, assigneeId: assigneeId,
                status: .ready, blockedReasonJson: nil, dependsOnJson: "[]",
                maxTurns: maxTurns, tokenBudget: tokenBudget, createdAt: Date())
            try card.insert(db)

            try Self.appendEvent(db, missionId: mission.id, cardId: card.id, runId: nil,
                                 kind: "mission_created", payload: ["goal": .string(goal)])

            return SingleCardIds(missionId: mission.id, cardId: card.id, squadId: squad.id)
        }
    }

    // MARK: Card queries

    public func card(id: String) throws -> CardRecord? {
        try pool.read { db in try CardRecord.fetchOne(db, key: id) }
    }

    public func squad(forCard cardId: String) throws -> SquadRecord? {
        try pool.read { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId),
                  let mission = try MissionRecord.fetchOne(db, key: card.missionId) else { return nil }
            return try SquadRecord.fetchOne(db, key: mission.squadId)
        }
    }

    // MARK: Card state machine (exhaustive; event appended in SAME transaction — spec §4.2/§5.1)

    public func transitionCard(id: String, to next: CardStatus, eventKind: String,
                               payload: JSONValue, blockedReasonJson: String? = nil) throws {
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "card", id: id)
            }
            guard card.status.canTransition(to: next) else {
                throw CardTransitionError(from: card.status, to: next)
            }
            card.status = next
            card.blockedReasonJson = (next == .blocked) ? blockedReasonJson : nil
            try card.update(db)
            try Self.appendEvent(db, missionId: card.missionId, cardId: card.id, runId: nil,
                                 kind: eventKind, payload: payload)
        }
    }

    // MARK: Event helpers (event table is APPEND-ONLY — no update/delete paths)

    public static func appendEvent(_ db: Database, missionId: String?, cardId: String?,
                                   runId: String?, kind: String, payload: JSONValue) throws {
        try EventRecord(
            id: UUID().uuidString, missionId: missionId, cardId: cardId, runId: runId,
            kind: kind, payloadJson: try payload.encodedString(), // Fix 6: encoding failure throws
            createdAt: Date()
        ).insert(db)
    }

    public func events(cardId: String) throws -> [EventRecord] {
        try pool.read { db in
            try EventRecord
                .filter(Column("cardId") == cardId)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    // MARK: Run lifecycle

    public func runs(cardId: String) throws -> [RunRecord] {
        try pool.read { db in
            try RunRecord.filter(Column("cardId") == cardId).order(Column("startedAt")).fetchAll(db)
        }
    }

    public func insertRun(id: String, cardId: String) throws {
        try pool.write { db in
            let attempt = try RunRecord.filter(Column("cardId") == cardId).fetchCount(db)
            try RunRecord(
                id: id, cardId: cardId, attempt: attempt + 1, outcome: nil,
                turns: 0, tokensIn: 0, tokensOut: 0, startedAt: Date(), endedAt: nil
            ).insert(db)
        }
    }

    /// Atomically inserts a run row AND transitions the card ready→running in one write transaction.
    /// A failed transition (e.g. card not ready) rolls back the run insert, preventing orphaned run rows.
    public func startRun(cardId: String, runId: String) throws {
        try pool.write { db in
            let attempt = try RunRecord.filter(Column("cardId") == cardId).fetchCount(db)
            try RunRecord(
                id: runId, cardId: cardId, attempt: attempt + 1, outcome: nil,
                turns: 0, tokensIn: 0, tokensOut: 0, startedAt: Date(), endedAt: nil
            ).insert(db)

            guard var card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            guard card.status.canTransition(to: .running) else {
                throw CardTransitionError(from: card.status, to: .running)
            }
            card.status = .running
            card.blockedReasonJson = nil
            try card.update(db)
            try Self.appendEvent(db, missionId: card.missionId, cardId: cardId, runId: runId,
                                 kind: "card_started", payload: ["runId": .string(runId)])
        }
    }

    public func finishRun(id: String, outcome: String, turns: Int, tokensIn: Int, tokensOut: Int) throws {
        try pool.write { db in
            guard var run = try RunRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "run", id: id)
            }
            run.outcome = outcome
            run.turns = turns
            run.tokensIn = tokensIn
            run.tokensOut = tokensOut
            run.endedAt = Date()
            try run.update(db)
        }
    }

    // MARK: Artifacts

    public func artifacts(cardId: String) throws -> [ArtifactRecord] {
        try pool.read { db in
            try ArtifactRecord.filter(Column("cardId") == cardId).order(Column("createdAt")).fetchAll(db)
        }
    }

    // MARK: Chat

    public func findOrCreateDMThread(companionId: String) throws -> ChatThreadRecord {
        try pool.write { db in
            if let existing = try ChatThreadRecord
                .filter(Column("companionId") == companionId && Column("kind") == "dm")
                .fetchOne(db) {
                return existing
            }
            let thread = ChatThreadRecord(
                id: UUID().uuidString, kind: .dm, companionId: companionId,
                campId: nil, createdAt: Date())
            try thread.insert(db)
            return thread
        }
    }

    public func messages(threadId: String) throws -> [ChatMessageRecord] {
        try pool.read { db in
            try ChatMessageRecord
                .filter(Column("threadId") == threadId)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
    }

    public func appendChatMessage(threadId: String, role: String, text: String) throws {
        // Fix 6: encoding failure throws — no fallback to empty JSON
        let data = try JSONEncoder().encode(["text": text])
        guard let contentJson = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(text, .init(codingPath: [], debugDescription: "UTF-8 encoding failed"))
        }
        try pool.write { db in
            try ChatMessageRecord(
                id: UUID().uuidString, threadId: threadId, role: role,
                contentJson: contentJson, distilled: false, createdAt: Date()
            ).insert(db)
        }
    }
}
