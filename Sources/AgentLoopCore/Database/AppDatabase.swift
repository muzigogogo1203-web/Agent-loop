import Foundation
import GRDB
import os

// MARK: - AppDatabase

public final class AppDatabase: Sendable {
    public let pool: DatabasePool
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "database")

    public init(path: String) throws {
        var cfg = Configuration()
        cfg.journalMode = .wal
        cfg.busyMode = .timeout(5)
        pool = try DatabasePool(path: path, configuration: cfg)
        try Self.migrator.migrate(pool)
    }

    // MARK: Migration v1 — all spec §4.2 tables (forward-compatible; M1 uses a subset)

    public static var migrator: DatabaseMigrator {
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
        m.registerMigration("v2") { db in
            try db.alter(table: "card") { t in
                t.add(column: "handoffJson", .text)
                t.add(column: "stage", .integer).notNull().defaults(to: 1)
            }
            try db.execute(sql: """
                UPDATE mission SET status = 'executing'
                WHERE status NOT IN ('planning','executing','delivering','accepted','failed')
                """)
        }
        // M4: 伙伴记忆表（v1 只建了 camp_note；companion_note 是 M4 补齐的缺口）
        m.registerMigration("v3") { db in
            try db.create(table: "companion_note") { t in
                t.primaryKey("id", .text)
                t.column("companionId", .text).notNull().references("companion").indexed()
                t.column("sourceThreadId", .text).references("chat_thread")
                t.column("title", .text).notNull()
                t.column("bodyMd", .text).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "camp_note_campId", on: "camp_note", columns: ["campId"])
        }
        // M5-1: 安全作用域书签（沙箱下重启恢复工作目录权限）
        m.registerMigration("v4") { db in
            try db.alter(table: "squad") { t in
                t.add(column: "workspaceBookmark", .blob)
            }
        }
        // M7-D2: 行动自主档位（谨慎/标准/放手），决定工具审批矩阵
        m.registerMigration("v5") { db in
            try db.alter(table: "mission") { t in
                t.add(column: "autonomy", .text).notNull().defaults(to: "standard")
            }
        }
        // M8-D2: MCP 驿站——全局注册表 + 营地级启用关联（频道隔离与 M5-0 一致）。
        // 敏感 env 值不落库（secretEnvKeysJson 只存 key 名，值在 Keychain，M8-D5）。
        m.registerMigration("v6") { db in
            try db.create(table: "mcp_server") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().unique()
                t.column("command", .text).notNull()
                t.column("argsJson", .text).notNull().defaults(to: "[]")
                t.column("envJson", .text).notNull().defaults(to: "{}")
                t.column("secretEnvKeysJson", .text).notNull().defaults(to: "[]")
                t.column("experimental", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "camp_mcp_enable") { t in
                t.column("campId", .text).notNull().references("camp")
                t.column("serverId", .text).notNull().references("mcp_server")
                t.primaryKey(["campId", "serverId"])
            }
        }
        // P0 durable halt: global kernel dispatch gate. This descriptive id is
        // intentionally inserted before the v7 id reserved by M9.
        m.registerMigration("v6-durable-halt") { db in
            try db.create(table: "kernel_control") { t in
                t.primaryKey("id", .text).check(sql: "id = 'global'")
                t.column("dispatchMode", .text).notNull()
                    .check(sql: "dispatchMode IN ('running', 'halted')")
                t.column("updatedAt", .datetime).notNull()
            }
            try KernelControlRecord(
                id: "global",
                dispatchMode: .running,
                updatedAt: Date()
            ).insert(db)
        }
        // M9-D4/D6: done-card review flags + camp archive bit. Both are projections;
        // event history remains append-only.
        m.registerMigration("v7") { db in
            try db.alter(table: "card") { t in
                t.add(column: "reviewFlag", .text)
            }
            try db.alter(table: "camp") { t in
                t.add(column: "archived", .boolean).notNull().defaults(to: false)
            }
        }
        return m
    }

    // MARK: Bootstrap (idempotent)

    @discardableResult
    public func ensureDefaultCamp() throws -> CampRecord {
        try pool.write { db in
            try Self.ensureDefaultCamp(db)
        }
    }

    private static func ensureDefaultCamp(_ db: Database) throws -> CampRecord {
        if let camp = try CampRecord.fetchOne(db) { return camp }
        let camp = CampRecord(id: UUID().uuidString, name: "我的营地", createdAt: Date())
        try camp.insert(db)
        var guide = CompanionRecord.new(
            name: "向导", color: "amber",
            rolePrompt: "你是这个营地的向导，熟悉营地里的一切。",
            model: KernelDefaults.defaultGuideModel, kind: .guide, campId: camp.id)
        guide.toolsJson = "[]"
        try guide.insert(db)
        return camp
    }

    public func guide(campId: String) throws -> CompanionRecord? {
        try pool.read { db in
            try CompanionRecord
                .filter(Column("campId") == campId && Column("kind") == "guide")
                .fetchOne(db)
        }
    }

    // MARK: 营地 CRUD（M5-0：营地=频道，可多建）

    public func camps() throws -> [CampRecord] {
        try pool.read { db in
            try CampRecord.order(Column("createdAt"), Column.rowID).fetchAll(db)
        }
    }

    public func camp(id: String) throws -> CampRecord? {
        try pool.read { db in try CampRecord.fetchOne(db, key: id) }
    }

    /// 建营地并自动配备向导（spec §10.2：每营地创建时自动配一位向导）。
    @discardableResult
    public func createCamp(name: String, guidePrompt: String? = nil) throws -> CampRecord {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = guidePrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return try pool.write { db in
            let camp = CampRecord(
                id: UUID().uuidString,
                name: trimmedName.isEmpty ? "新营地" : trimmedName,
                createdAt: Date())
            try camp.insert(db)
            var guide = CompanionRecord.new(
                name: "向导", color: "amber",
                rolePrompt: trimmedPrompt.isEmpty ? "你是这个营地的向导，熟悉营地里的一切。" : trimmedPrompt,
                model: KernelDefaults.defaultGuideModel, kind: .guide, campId: camp.id)
            guide.toolsJson = "[]"
            try guide.insert(db)
            return camp
        }
    }

    public func renameCamp(id: String, name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try pool.write { db in
            guard var camp = try CampRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "camp", id: id)
            }
            camp.name = trimmed
            try camp.update(db)
        }
    }

    public func setCampArchived(id: String, archived: Bool) throws {
        try pool.write { db in
            guard var camp = try CampRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "camp", id: id)
            }
            guard camp.archived != archived else { return }
            camp.archived = archived
            try camp.update(db)
            try Self.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.campArchived,
                payload: ["campId": .string(id), "archived": .bool(archived)]
            )
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
        tokenBudget: Int = KernelDefaults.cardTokenBudget,
        campId: String? = nil
    ) throws -> SingleCardIds {
        let camp = try resolveCamp(id: campId)
        return try pool.write { db in
            let squad = SquadRecord(
                id: UUID().uuidString, campId: camp.id, name: squadName,
                memberIdsJson: "[]", workspacePath: workspacePath,
                workspaceBookmark: WorkspaceScopedAccess.captureBookmark(forPath: workspacePath),
                createdAt: Date())
            try squad.insert(db)

            let mission = MissionRecord(
                id: UUID().uuidString, squadId: squad.id, goalRaw: goal,
                goalRefined: goal, status: .executing,
                budgetTokens: tokenBudget, spentTokens: 0, revision: 1, createdAt: Date())
            try mission.insert(db)

            let card = CardRecord(
                id: UUID().uuidString, missionId: mission.id,
                idemKey: "mission:\(mission.id):stage-1",
                title: cardTitle, descriptionText: cardDescription,
                expectedOutput: expectedOutput, assigneeId: assigneeId,
                status: .ready, blockedReasonJson: nil, dependsOnJson: "[]",
                handoffJson: nil, stage: 1,
                maxTurns: maxTurns, tokenBudget: tokenBudget, createdAt: Date())
            try card.insert(db)

            try Self.appendEvent(db, missionId: mission.id, cardId: card.id, runId: nil,
                                 kind: EventKind.missionCreated, payload: ["goal": .string(goal)])

            return SingleCardIds(missionId: mission.id, cardId: card.id, squadId: squad.id)
        }
    }

    /// campId 为 nil 时落默认营地（兼容既有调用）；给定 campId 必须存在。
    public func createMissionShell(
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int = KernelDefaults.missionBudget,
        campId: String? = nil,
        autonomy: MissionAutonomy = .standard
    ) throws -> String {
        let camp = try resolveCamp(id: campId)
        return try pool.write { db in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let memberIdsJson = String(data: try encoder.encode(companionIds), encoding: .utf8)!
            let squad = SquadRecord(
                id: UUID().uuidString,
                campId: camp.id,
                name: Self.truncatedFirstLine(goal, max: 30),
                memberIdsJson: memberIdsJson,
                workspacePath: workspacePath,
                workspaceBookmark: WorkspaceScopedAccess.captureBookmark(forPath: workspacePath),
                createdAt: Date()
            )
            try squad.insert(db)

            let mission = MissionRecord(
                id: UUID().uuidString,
                squadId: squad.id,
                goalRaw: goal,
                goalRefined: "",
                status: .planning,
                budgetTokens: max(1, budgetTokens),
                spentTokens: 0,
                revision: 1,
                autonomy: autonomy,
                createdAt: Date()
            )
            try mission.insert(db)
            try Self.appendEvent(db, missionId: mission.id, cardId: nil, runId: nil,
                                 kind: EventKind.missionCreated, payload: ["goal": .string(goal)])
            try Self.appendEvent(db, missionId: mission.id, cardId: nil, runId: nil,
                                 kind: EventKind.planStarted, payload: .object([:]))
            return mission.id
        }
    }

    private func resolveCamp(id: String?) throws -> CampRecord {
        guard let id else { return try ensureDefaultCamp() }
        guard let camp = try camp(id: id) else {
            throw RecordNotFoundError(table: "camp", id: id)
        }
        if camp.archived {
            throw CampArchivedError(campId: id)
        }
        return camp
    }

    /// 预算追加（M5-2 三选之「加预算」）；饱和加法防溢出。
    public func addBudget(missionId: String, tokens: Int) throws {
        try pool.write { db in
            guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            let (sum, overflow) = mission.budgetTokens.addingReportingOverflow(max(0, tokens))
            mission.budgetTokens = overflow ? Int.max : sum
            try mission.update(db)
            try Self.appendEvent(
                db, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.budgetAdded,
                payload: ["tokens": .number(Double(max(0, tokens)))]
            )
        }
    }

    public func recordPlanFallback(missionId: String, reason: String) throws {
        try pool.write { db in
            try Self.appendEvent(db, missionId: missionId, cardId: nil, runId: nil,
                                 kind: EventKind.planFallback, payload: ["reason": .string(reason)])
        }
    }

    public func planMission(missionId: String, goalRefined: String, drafts: [PlanProposal.CardDraft]) throws {
        try pool.write { db in
            guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            let existingCount = try CardRecord
                .filter(Column("missionId") == missionId)
                .fetchCount(db)
            if existingCount > 0 {
                try Self.appendEvent(db, missionId: missionId, cardId: nil, runId: nil,
                                     kind: EventKind.planNoop, payload: ["reason": "cards_exist"])
                return
            }
            guard mission.status == .planning else {
                try Self.appendEvent(db, missionId: missionId, cardId: nil, runId: nil,
                                     kind: EventKind.planNoop, payload: ["reason": "not_planning"])
                return
            }
            guard let squad = try SquadRecord.fetchOne(db, key: mission.squadId) else {
                throw RecordNotFoundError(table: "squad", id: mission.squadId)
            }
            let memberIds = try JSONDecoder().decode([String].self, from: Data(squad.memberIdsJson.utf8))
            let cardIds = drafts.map { _ in UUID().uuidString }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            for (index, draft) in drafts.enumerated() {
                let dependencyIds = draft.dependsOn.map { cardIds[$0] }
                let dependsOnJson = String(data: try encoder.encode(dependencyIds), encoding: .utf8)!
                let card = CardRecord(
                    id: cardIds[index],
                    missionId: missionId,
                    idemKey: "mission:\(missionId):stage-\(index + 1)",
                    title: draft.title,
                    descriptionText: draft.description,
                    expectedOutput: draft.expectedOutput,
                    assigneeId: memberIds[draft.assignee],
                    status: .todo,
                    blockedReasonJson: nil,
                    dependsOnJson: dependsOnJson,
                    handoffJson: nil,
                    stage: index + 1,
                    maxTurns: KernelDefaults.maxTurns,
                    tokenBudget: KernelDefaults.cardTokenBudget,
                    createdAt: Date()
                )
                try card.insert(db)
            }

            mission.goalRefined = goalRefined
            try mission.update(db)
            try Self.appendEvent(
                db,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.planCompleted,
                payload: [
                    "goalRefined": .string(goalRefined),
                    "cardIds": .array(cardIds.map(JSONValue.string)),
                    "titles": .array(drafts.map { .string($0.title) }),
                ]
            )
            try rollupMission(db, missionId: missionId)
        }
    }

    // MARK: Card queries

    public func card(id: String) throws -> CardRecord? {
        try pool.read { db in try CardRecord.fetchOne(db, key: id) }
    }

    public func clearCardReviewFlag(cardId: String) throws {
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            guard card.reviewFlag != nil else { return }
            card.reviewFlag = nil
            try card.update(db)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReviewCleared,
                payload: .object([:])
            )
        }
    }

    public func returnCardForRework(cardId: String, feedback: String) throws {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            guard var mission = try MissionRecord.fetchOne(db, key: card.missionId) else {
                throw RecordNotFoundError(table: "mission", id: card.missionId)
            }
            guard mission.status == .executing || mission.status == .delivering else {
                throw MissionStateError(missionId: mission.id, from: mission.status, expected: .executing)
            }
            guard card.status.canTransition(to: .ready) else {
                throw CardTransitionError(from: card.status, to: .ready)
            }

            let handoff = card.handoffJson.flatMap {
                try? JSONDecoder().decode(HandoffPayload.self, from: Data($0.utf8))
            }
            let payload: JSONValue = [
                "feedback": .string(trimmed),
                "previousOutcome": .string(handoff?.outcome ?? ""),
                "previousSummary": .string(handoff?.summary ?? ""),
            ]

            card.status = .ready
            card.blockedReasonJson = nil
            card.reviewFlag = nil
            try card.update(db)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReturned,
                payload: payload
            )

            let downstream = try CardRecord
                .filter(Column("missionId") == card.missionId && Column("status") == CardStatus.done.rawValue)
                .fetchAll(db)
            for var dependent in downstream where Self.dependsOn(card.id, dependsOnJson: dependent.dependsOnJson) {
                dependent.reviewFlag = "stale_upstream"
                try dependent.update(db)
            }

            let statuses = try CardRecord
                .filter(Column("missionId") == mission.id)
                .fetchAll(db)
                .map(\.status)
            let next = MissionStatus.rollup(current: mission.status, cards: statuses)
            if next != mission.status {
                let previous = mission.status
                mission.status = next
                try mission.update(db)
                try Self.appendEvent(
                    db,
                    missionId: mission.id,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: ["from": .string(previous.rawValue), "to": .string(next.rawValue)]
                )
            }
        }
    }

    public func latestReturnFeedback(cardId: String) throws -> (feedback: String, previousOutcome: String, previousSummary: String)? {
        try pool.read { db in
            guard let event = try EventRecord
                .filter(Column("cardId") == cardId && Column("kind") == EventKind.cardReturned)
                .order(Column("createdAt").desc, Column.rowID.desc)
                .fetchOne(db),
                  let payload = try? JSONValue.decoded(from: event.payloadJson),
                  let feedback = payload["feedback"]?.stringValue,
                  !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (
                feedback,
                payload["previousOutcome"]?.stringValue ?? "",
                payload["previousSummary"]?.stringValue ?? ""
            )
        }
    }

    public func squad(forCard cardId: String) throws -> SquadRecord? {
        try pool.read { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId),
                  let mission = try MissionRecord.fetchOne(db, key: card.missionId) else { return nil }
            return try SquadRecord.fetchOne(db, key: mission.squadId)
        }
    }

    private static func dependsOn(_ upstreamId: String, dependsOnJson: String) -> Bool {
        guard let ids = try? JSONDecoder().decode([String].self, from: Data(dependsOnJson.utf8)) else {
            return false
        }
        return ids.contains(upstreamId)
    }

    public func squad(forMission missionId: String) throws -> SquadRecord? {
        try pool.read { db in
            guard let mission = try MissionRecord.fetchOne(db, key: missionId) else { return nil }
            return try SquadRecord.fetchOne(db, key: mission.squadId)
        }
    }

    public func mission(id: String) throws -> MissionRecord? {
        try pool.read { db in try MissionRecord.fetchOne(db, key: id) }
    }

    public func cards(missionId: String) throws -> [CardRecord] {
        try pool.read { db in
            try CardRecord
                .filter(Column("missionId") == missionId)
                .order(Column("stage"))
                .fetchAll(db)
        }
    }

    public func companions(ids: [String]) throws -> [CompanionRecord] {
        var seen = Set<String>()
        let uniqueIds = ids.filter { seen.insert($0).inserted }
        return try pool.read { db in
            var companions: [CompanionRecord] = []
            for id in uniqueIds {
                guard let companion = try CompanionRecord.fetchOne(db, key: id) else {
                    throw RecordNotFoundError(table: "companion", id: id)
                }
                companions.append(companion)
            }
            return companions
        }
    }

    public func missionArtifacts(missionId: String) throws -> [ArtifactRecord] {
        try pool.read { db in
            try ArtifactRecord
                .fetchAll(
                    db,
                    sql: """
                        SELECT artifact.*
                        FROM artifact
                        JOIN card ON card.id = artifact.cardId
                        WHERE card.missionId = ?
                        ORDER BY card.stage, artifact.createdAt
                        """,
                    arguments: [missionId]
                )
        }
    }

    // MARK: Card state machine (exhaustive; event appended in SAME transaction — spec §4.2/§5.1)

    public func transitionCard(id: String, to next: CardStatus, eventKind: String,
                               payload: JSONValue, blockedReasonJson: String? = nil) throws {
        try pool.write { db in
            try transitionCard(db, id: id, to: next, eventKind: eventKind,
                               payload: payload, blockedReasonJson: blockedReasonJson)
        }
    }

    func transitionCard(_ db: Database, id: String, to next: CardStatus, eventKind: String,
                        payload: JSONValue, blockedReasonJson: String? = nil) throws {
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
        try rollupMission(db, missionId: card.missionId)
    }

    func rollupMission(_ db: Database, missionId: String) throws {
        guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
            throw RecordNotFoundError(table: "mission", id: missionId)
        }
        let statuses = try CardRecord
            .filter(Column("missionId") == missionId)
            .fetchAll(db)
            .map(\.status)
        let next = MissionStatus.rollup(current: mission.status, cards: statuses)
        guard next != mission.status else { return }
        let previous = mission.status
        mission.status = next
        try mission.update(db)
        try Self.appendEvent(
            db,
            missionId: missionId,
            cardId: nil,
            runId: nil,
            kind: EventKind.missionStatusChanged,
            payload: ["from": .string(previous.rawValue), "to": .string(next.rawValue)]
        )
        if next == .failed && previous != .accepted && previous != .failed {
            try Self.appendEvent(
                db,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.missionFailed,
                payload: ["reason": "defensive_rollup"]
            )
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

    public func events(missionId: String, limit: Int = 200) throws -> [EventRecord] {
        try pool.read { db in
            let rows = try EventRecord.fetchAll(
                db,
                sql: """
                    SELECT *
                    FROM event
                    WHERE missionId = ?
                    ORDER BY createdAt DESC, rowid DESC
                    LIMIT ?
                    """,
                arguments: [missionId, limit]
            )
            return rows.reversed()
        }
    }

    public func missions(limit: Int = 20) throws -> [MissionRecord] {
        try pool.read { db in
            try MissionRecord
                .order(Column("createdAt").desc, Column.rowID.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// 某营地的行动（M5-0：侧栏按频道分组 + 营地首页往期区）。
    public func missions(campId: String, limit: Int = 50) throws -> [MissionRecord] {
        try pool.read { db in
            try MissionRecord.fetchAll(
                db,
                sql: """
                    SELECT mission.*
                    FROM mission
                    JOIN squad ON squad.id = mission.squadId
                    WHERE squad.campId = ?
                    ORDER BY mission.createdAt DESC, mission.rowid DESC
                    LIMIT ?
                    """,
                arguments: [campId, limit]
            )
        }
    }

    public func suspendCardForUserRequest(
        cardId: String,
        runId: String?,
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]?
    ) throws -> String {
        try pool.write { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }

            let requestId = UUID().uuidString
            let optionsJson: String?
            if let options {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                optionsJson = String(data: try encoder.encode(options), encoding: .utf8)
            } else {
                optionsJson = nil
            }

            try UserRequestRecord(
                id: requestId,
                cardId: cardId,
                kind: kind,
                prompt: prompt,
                optionsJson: optionsJson,
                answerJson: nil,
                createdAt: Date(),
                answeredAt: nil
            ).insert(db)

            let blockedPayload: JSONValue = [
                "detail": .string(prompt),
                "reason": "needs_human_input",
                "userRequestId": .string(requestId),
            ]
            try blockCard(
                db,
                id: cardId,
                runId: runId,
                reason: "needs_human_input",
                detail: prompt,
                payload: blockedPayload,
                reasonJson: try blockedPayload.encodedString()
            )
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: cardId,
                runId: runId,
                kind: EventKind.userRequestCreated,
                payload: [
                    "kind": .string(kind.rawValue),
                    "prompt": .string(prompt),
                    "userRequestId": .string(requestId),
                ]
            )
            return requestId
        }
    }

    public func answerUserRequest(requestId: String, answerJson: String) throws {
        try pool.write { db in
            guard var request = try UserRequestRecord.fetchOne(db, key: requestId),
                  request.answerJson == nil,
                  let card = try CardRecord.fetchOne(db, key: request.cardId),
                  card.status == .blocked,
                  let blockedReasonJson = card.blockedReasonJson,
                  let blockedReason = try? JSONValue.decoded(from: blockedReasonJson),
                  blockedReason["userRequestId"]?.stringValue == requestId
            else {
                throw StaleUserRequestError(requestId: requestId)
            }

            request.answerJson = answerJson
            request.answeredAt = Date()
            try request.update(db)

            try transitionCard(
                db,
                id: card.id,
                to: .ready,
                eventKind: EventKind.cardReady,
                payload: ["answeredRequest": .string(requestId)]
            )
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.userRequestAnswered,
                payload: ["userRequestId": .string(requestId)]
            )
            // M7-D4：审批答复额外落 decided 事件（含决定，feed 可渲染）
            if request.kind == .approval,
               let answer = try? JSONValue.decoded(from: answerJson),
               let decision = answer["decision"]?.stringValue {
                try Self.appendEvent(
                    db,
                    missionId: card.missionId,
                    cardId: card.id,
                    runId: nil,
                    kind: EventKind.approvalDecided,
                    payload: ["userRequestId": .string(requestId), "decision": .string(decision)]
                )
            }
        }
    }

    /// M7-D3：审批挂起（复用 ask_user 持久门语义）。optionsJson 存 {tool, input, inputHash} 全文，
    /// UI 从中渲染动作实体内容（命令全文/写入路径与内容）。
    public func suspendCardForApproval(
        cardId: String,
        runId: String?,
        prompt: String,
        tool: String,
        input: JSONValue,
        inputHash: String
    ) throws -> String {
        try pool.write { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            let requestId = UUID().uuidString
            let payload: JSONValue = [
                "tool": .string(tool),
                "input": input,
                "inputHash": .string(inputHash),
            ]
            try UserRequestRecord(
                id: requestId,
                cardId: cardId,
                kind: .approval,
                prompt: prompt,
                optionsJson: try payload.encodedString(),
                answerJson: nil,
                createdAt: Date(),
                answeredAt: nil
            ).insert(db)

            let blockedPayload: JSONValue = [
                "detail": .string(prompt),
                "reason": "needs_human_input",
                "userRequestId": .string(requestId),
            ]
            try blockCard(
                db,
                id: cardId,
                runId: runId,
                reason: "needs_human_input",
                detail: prompt,
                payload: blockedPayload,
                reasonJson: try blockedPayload.encodedString()
            )
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: cardId,
                runId: runId,
                kind: EventKind.approvalRequested,
                payload: [
                    "tool": .string(tool),
                    "prompt": .string(prompt),
                    "userRequestId": .string(requestId),
                ]
            )
            return requestId
        }
    }

    /// 本卡已决的审批记录 → 授权令牌快照（M7-D4，冷启动重跑时装入令牌罐）
    public func approvalDecisions(cardId: String) throws -> [ApprovalDecision] {
        let answered = try answeredRequests(cardId: cardId).filter { $0.kind == .approval }
        return answered.compactMap { request in
            guard let optionsJson = request.optionsJson,
                  let payload = try? JSONValue.decoded(from: optionsJson),
                  let tool = payload["tool"]?.stringValue,
                  let hash = payload["inputHash"]?.stringValue,
                  let answerJson = request.answerJson,
                  let answer = try? JSONValue.decoded(from: answerJson),
                  let decision = answer["decision"]?.stringValue else {
                return nil
            }
            return ApprovalDecision(
                tool: tool,
                inputHash: hash,
                approved: decision == "approve",
                reason: answer["reason"]?.stringValue
            )
        }
    }

    public func answeredRequests(cardId: String) throws -> [UserRequestRecord] {
        try pool.read { db in
            try UserRequestRecord
                .filter(Column("cardId") == cardId && Column("answerJson") != nil)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    public func pendingUserRequests(missionId: String) throws -> [UserRequestRecord] {
        try pool.read { db in
            try UserRequestRecord.fetchAll(
                db,
                sql: """
                    SELECT user_request.*
                    FROM user_request
                    JOIN card ON card.id = user_request.cardId
                    WHERE card.missionId = ? AND user_request.answerJson IS NULL
                    ORDER BY user_request.createdAt, user_request.rowid
                    """,
                arguments: [missionId]
            )
        }
    }

    public func appendKernelErrorEvent(missionId: String, message: String) {
        do {
            try pool.write { db in
                try Self.appendEvent(
                    db,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.kernelError,
                    payload: ["message": .string(message)]
                )
            }
        } catch {
            Self.logger.error(
                "failed to persist kernel error event for mission \(missionId, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
    }

    public func appendDiagnosticEvent(cardId: String, runId: String, kind: String, payload: JSONValue) throws {
        try pool.write { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: cardId,
                runId: runId,
                kind: kind,
                payload: payload
            )
        }
    }

    // MARK: Run lifecycle

    public func runs(cardId: String) throws -> [RunRecord] {
        try pool.read { db in
            try RunRecord.filter(Column("cardId") == cardId).order(Column("startedAt")).fetchAll(db)
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
                                 kind: EventKind.cardStarted, payload: ["runId": .string(runId)])
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
            if let card = try CardRecord.fetchOne(db, key: run.cardId),
               var mission = try MissionRecord.fetchOne(db, key: card.missionId) {
                Self.addSpentSaturating(&mission, tokensIn: tokensIn, tokensOut: tokensOut)
                try mission.update(db)
            }
        }
    }

    /// 规划轮 token 入账（M6-D13）：规划没有 run 行，走独立入账；
    /// 投影更新与 planning_tokens 事件在同一写事务（事件溯源纪律）。
    public func recordPlanningTokens(
        missionId: String, inputTokens: Int, outputTokens: Int, cacheReadTokens: Int
    ) throws {
        try pool.write { db in
            guard var mission = try MissionRecord.fetchOne(db, key: missionId) else { return }
            Self.addSpentSaturating(&mission, tokensIn: inputTokens, tokensOut: outputTokens)
            try mission.update(db)
            try Self.appendEvent(
                db, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.planningTokens,
                payload: [
                    "inputTokens": .number(Double(max(0, inputTokens))),
                    "outputTokens": .number(Double(max(0, outputTokens))),
                    "cacheReadTokens": .number(Double(max(0, cacheReadTokens))),
                ])
        }
    }

    /// 行动花销分账（M7-D7，本地估算口径）：按伙伴聚合 run 表 + 规划轮事件求和
    public func missionSpendBreakdown(missionId: String) throws -> MissionSpendBreakdown {
        try pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT card.assigneeId AS assigneeId,
                           companion.name AS name,
                           SUM(COALESCE(run.tokensIn, 0) + COALESCE(run.tokensOut, 0)) AS tokens
                    FROM run
                    JOIN card ON card.id = run.cardId
                    LEFT JOIN companion ON companion.id = card.assigneeId
                    WHERE card.missionId = ?
                    GROUP BY card.assigneeId
                    ORDER BY tokens DESC
                    """,
                arguments: [missionId]
            )
            let companions: [MissionSpendBreakdown.CompanionSpend] = rows.map { row in
                .init(
                    companionId: row["assigneeId"],
                    name: row["name"] ?? "（未指派）",
                    tokens: row["tokens"] ?? 0
                )
            }
            let planningEvents = try EventRecord
                .filter(Column("missionId") == missionId && Column("kind") == EventKind.planningTokens)
                .fetchAll(db)
            let planning = planningEvents.reduce(0) { total, event in
                guard let payload = try? JSONValue.decoded(from: event.payloadJson) else { return total }
                let input = payload["inputTokens"]?.intValue ?? 0
                let output = payload["outputTokens"]?.intValue ?? 0
                return total + input + output
            }
            return MissionSpendBreakdown(planningTokens: planning, companions: companions)
        }
    }

    /// 行动自主档位中途可改（M7-D2）：更新与 autonomy_changed 事件同事务
    public func setMissionAutonomy(missionId: String, to autonomy: MissionAutonomy) throws {
        try pool.write { db in
            guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            guard mission.autonomy != autonomy else { return }
            let previous = mission.autonomy
            mission.autonomy = autonomy
            try mission.update(db)
            try Self.appendEvent(
                db, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.autonomyChanged,
                payload: ["from": .string(previous.rawValue), "to": .string(autonomy.rawValue)])
        }
    }

    /// 饱和加法（原内联于 finishRun）：溢出封顶 Int.max，预算执法不许翻车
    private static func addSpentSaturating(_ mission: inout MissionRecord, tokensIn: Int, tokensOut: Int) {
        let (total, totalOverflow) = max(0, tokensIn).addingReportingOverflow(max(0, tokensOut))
        let (newSpent, overflow) = mission.spentTokens.addingReportingOverflow(totalOverflow ? Int.max : total)
        mission.spentTokens = (overflow || totalOverflow) ? Int.max : newSpent
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

    private static func truncatedFirstLine(_ text: String, max: Int) -> String {
        let first = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return String(first.prefix(max))
    }
}
