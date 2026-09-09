import Foundation
import GRDB

package struct P1EMigrationIntegrityError: Error, Equatable, Sendable,
    CustomStringConvertible
{
    package let code: String
    package let subject: String

    package init(code: String, subject: String) {
        self.code = code
        self.subject = subject
    }

    package var description: String {
        "P1-E migration integrity failure [\(code)]: \(subject)"
    }
}

package enum LegacyContentScopeKindV1: String, Sendable, Equatable {
    case camp
    case globalCow
}

package enum LegacyContentEvidenceKindV1: String, Sendable, Equatable {
    case dmThread
    case guideThread
    case coworkEvent
    case manualCow
}

package struct LegacyContentScopeSnapshotV1: Sendable, Equatable {
    package let id: String
    package let scopeKind: LegacyContentScopeKindV1
    package let campId: String?
    package let cowId: String
    package let sourceThreadId: String?
    package let evidenceKind: LegacyContentEvidenceKindV1
    package let createdAt: Date
}

package enum LegacyCompanionNoteScopeV1: Sendable, Equatable {
    case sourceThread(String)
    case cowork(missionId: String)
    case manualCow
}

package enum LegacyContentScopeError: Error, Sendable, Equatable {
    case lifecycleVersionRequired
    case lifecycleVersionUnexpected
    case missingCow(String)
    case missingGuide(String)
    case missingThreadScope(String)
    case malformedScope(String)
    case cowMismatch
    case sourceThreadMismatch
    case missionEvidenceMissing(String)
    case noncanonicalContent
}

package struct LegacyContentScopeStore: Sendable {
    private let database: AppDatabase

    package init(database: AppDatabase) {
        self.database = database
    }

    package static func installConnectionGuards(on database: Database) throws {
        let required = [
            "chat_thread", "chat_message", "companion_note",
            "legacy_chat_scope", "legacy_companion_note_scope",
        ]
        let count = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM sqlite_master
                WHERE type='table' AND name IN (?,?,?,?,?)
                """,
            arguments: StatementArguments(required)
        ) ?? 0
        guard count == required.count else { return }
        try database.execute(sql: """
            CREATE TEMP TRIGGER IF NOT EXISTS p1e_chat_thread_require_scope
            AFTER INSERT ON main.chat_thread
            WHEN NOT EXISTS (
              SELECT 1 FROM main.legacy_chat_scope WHERE threadId=NEW.id
            )
            BEGIN
              SELECT RAISE(ABORT, 'chat thread requires typed scope');
            END;
            CREATE TEMP TRIGGER IF NOT EXISTS p1e_chat_message_require_scope
            BEFORE INSERT ON main.chat_message
            WHEN NOT EXISTS (
              SELECT 1 FROM main.legacy_chat_scope WHERE threadId=NEW.threadId
            )
            BEGIN
              SELECT RAISE(ABORT, 'chat message requires typed thread scope');
            END;
            CREATE TEMP TRIGGER IF NOT EXISTS p1e_companion_note_require_scope
            AFTER INSERT ON main.companion_note
            WHEN NOT EXISTS (
              SELECT 1 FROM main.legacy_companion_note_scope WHERE noteId=NEW.id
            )
            BEGIN
              SELECT RAISE(ABORT, 'companion note requires typed scope');
            END;
            """)
    }

    package func findOrCreateDMThread(
        cowId: String
    ) throws -> ChatThreadRecord {
        try database.pool.write { transaction in
            try Self.findOrCreateDMThread(cowId: cowId, in: transaction)
        }
    }

    package func findOrCreateGuideThread(
        campId: String,
        expectedLifecycleVersion: Int?
    ) throws -> ChatThreadRecord {
        try database.pool.write { transaction in
            try Self.findOrCreateGuideThread(
                campId: campId,
                expectedLifecycleVersion: expectedLifecycleVersion,
                in: transaction
            )
        }
    }

    @discardableResult
    package func appendMessage(
        threadId: String,
        role: String,
        contentJson: String,
        expectedCampLifecycleVersion: Int?
    ) throws -> String {
        try database.pool.write { transaction in
            try Self.appendMessage(
                threadId: threadId,
                role: role,
                contentJson: contentJson,
                expectedCampLifecycleVersion: expectedCampLifecycleVersion,
                in: transaction
            )
        }
    }

    package func recordCompanionNote(
        _ note: CompanionNoteRecord,
        scope: LegacyCompanionNoteScopeV1,
        expectedCampLifecycleVersion: Int?
    ) throws {
        try database.pool.write { transaction in
            try Self.recordCompanionNote(
                note,
                scope: scope,
                expectedCampLifecycleVersion: expectedCampLifecycleVersion,
                in: transaction
            )
        }
    }

    package func threadScope(
        id: String
    ) throws -> LegacyContentScopeSnapshotV1? {
        try database.pool.read { transaction in
            try Self.threadScope(id: id, in: transaction)
        }
    }

    package func noteScope(
        id: String
    ) throws -> LegacyContentScopeSnapshotV1? {
        try database.pool.read { transaction in
            try Self.noteScope(id: id, in: transaction)
        }
    }

    package static func findOrCreateDMThread(
        cowId: String,
        in database: Database
    ) throws -> ChatThreadRecord {
        try CanonicalContractCodingV1.validateNonempty(cowId)
        guard try CompanionRecord.fetchOne(database, key: cowId) != nil else {
            throw LegacyContentScopeError.missingCow(cowId)
        }
        let matches = try ChatThreadRecord
            .filter(
                Column("companionId") == cowId
                    && Column("kind") == ChatThreadRecord.Kind.dm.rawValue
            )
            .order(Column("createdAt"), Column.rowID)
            .limit(2)
            .fetchAll(database)
        guard matches.count <= 1 else {
            throw LegacyContentScopeError.malformedScope(cowId)
        }
        if let existing = matches.first {
            let scope = try requireThreadScope(
                id: existing.id,
                in: database
            )
            guard existing.campId == nil,
                  scope.scopeKind == .globalCow,
                  scope.campId == nil,
                  scope.cowId == cowId,
                  scope.evidenceKind == .dmThread
            else {
                throw LegacyContentScopeError.malformedScope(existing.id)
            }
            return existing
        }
        let now = Date()
        let thread = ChatThreadRecord(
            id: UUID().uuidString,
            kind: .dm,
            companionId: cowId,
            campId: nil,
            createdAt: now
        )
        try database.execute(sql: "PRAGMA defer_foreign_keys=ON")
        try insertThreadScope(
            id: thread.id,
            scopeKind: .globalCow,
            campId: nil,
            cowId: cowId,
            evidenceKind: .dmThread,
            createdAt: now,
            in: database
        )
        try thread.insert(database)
        return thread
    }

    package static func findOrCreateGuideThread(
        campId: String,
        expectedLifecycleVersion: Int?,
        in database: Database
    ) throws -> ChatThreadRecord {
        try CanonicalContractCodingV1.validateCampID(campId)
        guard let expectedLifecycleVersion else {
            throw LegacyContentScopeError.lifecycleVersionRequired
        }
        _ = try requireActiveCamp(
            campId: campId,
            expectedLifecycleVersion: expectedLifecycleVersion,
            in: database
        )
        let guides = try CompanionRecord
            .filter(
                Column("campId") == campId
                    && Column("kind") == CompanionRecord.Kind.guide.rawValue
            )
            .order(Column("createdAt"), Column.rowID)
            .limit(2)
            .fetchAll(database)
        guard guides.count == 1, let guide = guides.first else {
            throw LegacyContentScopeError.missingGuide(campId)
        }
        let matches = try ChatThreadRecord
            .filter(
                Column("campId") == campId
                    && Column("kind") == ChatThreadRecord.Kind.guide.rawValue
            )
            .order(Column("createdAt"), Column.rowID)
            .limit(2)
            .fetchAll(database)
        guard matches.count <= 1 else {
            throw LegacyContentScopeError.malformedScope(campId)
        }
        if let existing = matches.first {
            let scope = try requireThreadScope(
                id: existing.id,
                in: database
            )
            guard existing.companionId == guide.id,
                  scope.scopeKind == .camp,
                  scope.campId == campId,
                  scope.cowId == guide.id,
                  scope.evidenceKind == .guideThread
            else {
                throw LegacyContentScopeError.malformedScope(existing.id)
            }
            return existing
        }
        let now = Date()
        let thread = ChatThreadRecord(
            id: UUID().uuidString,
            kind: .guide,
            companionId: guide.id,
            campId: campId,
            createdAt: now
        )
        try database.execute(sql: "PRAGMA defer_foreign_keys=ON")
        try insertThreadScope(
            id: thread.id,
            scopeKind: .camp,
            campId: campId,
            cowId: guide.id,
            evidenceKind: .guideThread,
            createdAt: now,
            in: database
        )
        try thread.insert(database)
        return thread
    }

    package static func findOrCreateGuideThreadResolvingLifecycle(
        campId: String,
        in database: Database
    ) throws -> ChatThreadRecord {
        let version = try currentActiveLifecycleVersion(
            campId: campId,
            in: database
        )
        return try findOrCreateGuideThread(
            campId: campId,
            expectedLifecycleVersion: version,
            in: database
        )
    }

    @discardableResult
    package static func appendMessage(
        threadId: String,
        role: String,
        contentJson: String,
        expectedCampLifecycleVersion: Int?,
        in database: Database
    ) throws -> String {
        try validateCanonicalObject(contentJson)
        guard !role.isEmpty,
              role == role.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            throw LegacyContentScopeError.noncanonicalContent
        }
        guard try ChatThreadRecord.fetchOne(database, key: threadId) != nil
        else {
            throw LegacyContentScopeError.missingThreadScope(threadId)
        }
        let scope = try requireThreadScope(id: threadId, in: database)
        try authorize(scope: scope, expected: expectedCampLifecycleVersion,
                      in: database)
        let id = UUID().uuidString
        try ChatMessageRecord(
            id: id,
            threadId: threadId,
            role: role,
            contentJson: contentJson,
            distilled: false,
            createdAt: Date()
        ).insert(database)
        return id
    }

    @discardableResult
    package static func appendMessageResolvingScope(
        threadId: String,
        role: String,
        contentJson: String,
        in database: Database
    ) throws -> String {
        let scope = try requireThreadScope(id: threadId, in: database)
        let version: Int?
        switch scope.scopeKind {
        case .globalCow:
            version = nil
        case .camp:
            guard let campID = scope.campId else {
                throw LegacyContentScopeError.malformedScope(threadId)
            }
            version = try currentActiveLifecycleVersion(
                campId: campID,
                in: database
            )
        }
        return try appendMessage(
            threadId: threadId,
            role: role,
            contentJson: contentJson,
            expectedCampLifecycleVersion: version,
            in: database
        )
    }

    package static func recordCompanionNote(
        _ note: CompanionNoteRecord,
        scope requestedScope: LegacyCompanionNoteScopeV1,
        expectedCampLifecycleVersion: Int?,
        in database: Database
    ) throws {
        guard try CompanionRecord.fetchOne(
            database,
            key: note.companionId
        ) != nil else {
            throw LegacyContentScopeError.missingCow(note.companionId)
        }
        let scope: LegacyContentScopeSnapshotV1
        switch requestedScope {
        case .sourceThread(let threadID):
            guard note.sourceThreadId == threadID else {
                throw LegacyContentScopeError.sourceThreadMismatch
            }
            let threadScope = try requireThreadScope(
                id: threadID,
                in: database
            )
            guard threadScope.cowId == note.companionId else {
                throw LegacyContentScopeError.cowMismatch
            }
            scope = LegacyContentScopeSnapshotV1(
                id: note.id,
                scopeKind: threadScope.scopeKind,
                campId: threadScope.campId,
                cowId: threadScope.cowId,
                sourceThreadId: threadID,
                evidenceKind: threadScope.evidenceKind,
                createdAt: note.createdAt
            )
        case .cowork(let missionID):
            guard note.sourceThreadId == nil,
                  let campID = try String.fetchOne(
                      database,
                      sql: """
                          SELECT squad.campId FROM mission
                          JOIN squad ON squad.id=mission.squadId
                          WHERE mission.id=?
                          """,
                      arguments: [missionID]
                  )
            else {
                throw LegacyContentScopeError
                    .missionEvidenceMissing(missionID)
            }
            scope = LegacyContentScopeSnapshotV1(
                id: note.id,
                scopeKind: .camp,
                campId: campID,
                cowId: note.companionId,
                sourceThreadId: nil,
                evidenceKind: .coworkEvent,
                createdAt: note.createdAt
            )
        case .manualCow:
            guard note.sourceThreadId == nil else {
                throw LegacyContentScopeError.sourceThreadMismatch
            }
            scope = LegacyContentScopeSnapshotV1(
                id: note.id,
                scopeKind: .globalCow,
                campId: nil,
                cowId: note.companionId,
                sourceThreadId: nil,
                evidenceKind: .manualCow,
                createdAt: note.createdAt
            )
        }
        try authorize(scope: scope, expected: expectedCampLifecycleVersion,
                      in: database)
        try database.execute(sql: "PRAGMA defer_foreign_keys=ON")
        try database.execute(
            sql: """
                INSERT INTO legacy_companion_note_scope(
                  noteId,scopeKind,campId,cowId,sourceThreadId,evidenceKind,
                  createdAt
                ) VALUES (?,?,?,?,?,?,?)
                """,
            arguments: [
                note.id, scope.scopeKind.rawValue, scope.campId, scope.cowId,
                scope.sourceThreadId, scope.evidenceKind.rawValue,
                scope.createdAt,
            ]
        )
        try note.insert(database)
    }

    package static func threadScope(
        id: String,
        in database: Database
    ) throws -> LegacyContentScopeSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT threadId,scopeKind,campId,cowId,evidenceKind,createdAt
                FROM legacy_chat_scope WHERE threadId=?
                """,
            arguments: [id]
        ) else { return nil }
        return try decodeScope(row: row, idColumn: "threadId",
                               sourceThreadId: nil)
    }

    package static func noteScope(
        id: String,
        in database: Database
    ) throws -> LegacyContentScopeSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT noteId,scopeKind,campId,cowId,sourceThreadId,
                       evidenceKind,createdAt
                FROM legacy_companion_note_scope WHERE noteId=?
                """,
            arguments: [id]
        ) else { return nil }
        return try decodeScope(
            row: row,
            idColumn: "noteId",
            sourceThreadId: row["sourceThreadId"]
        )
    }

    private static func requireThreadScope(
        id: String,
        in database: Database
    ) throws -> LegacyContentScopeSnapshotV1 {
        guard let scope = try threadScope(id: id, in: database) else {
            throw LegacyContentScopeError.missingThreadScope(id)
        }
        return scope
    }

    private static func authorize(
        scope: LegacyContentScopeSnapshotV1,
        expected: Int?,
        in database: Database
    ) throws {
        switch scope.scopeKind {
        case .globalCow:
            guard expected == nil else {
                throw LegacyContentScopeError.lifecycleVersionUnexpected
            }
        case .camp:
            guard let campID = scope.campId,
                  let expected
            else {
                throw LegacyContentScopeError.lifecycleVersionRequired
            }
            _ = try requireActiveCamp(
                campId: campID,
                expectedLifecycleVersion: expected,
                in: database
            )
        }
    }

    private static func requireActiveCamp(
        campId: String,
        expectedLifecycleVersion: Int,
        in database: Database
    ) throws -> CampLifecycleSnapshotV1 {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT lifecycle.campId,lifecycle.state,lifecycle.version,
                       lifecycle.createdAt,lifecycle.updatedAt,
                       lifecycle.deletionRequestedAt,lifecycle.deletedAt,
                       camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let actual: Int = row["version"]
        guard actual == expectedLifecycleVersion else {
            throw CampLifecycleWriteAuthorizationError
                .lifecycleVersionMismatch(
                    expected: expectedLifecycleVersion,
                    actual: actual
                )
        }
        guard let state = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ), state == .active else {
            let state = CampLifecycleStateV1(
                rawValue: row["state"] as String
            ) ?? .deletedTombstone
            throw CampLifecycleWriteAuthorizationError.inactive(state)
        }
        guard (row["archived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        return CampLifecycleSnapshotV1(
            campId: row["campId"],
            state: state,
            version: actual,
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"],
            deletionRequestedAt: row["deletionRequestedAt"],
            deletedAt: row["deletedAt"]
        )
    }

    private static func currentActiveLifecycleVersion(
        campId: String,
        in database: Database
    ) throws -> Int {
        guard let version = try Int.fetchOne(
            database,
            sql: "SELECT version FROM camp_lifecycle WHERE campId=?",
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        _ = try requireActiveCamp(
            campId: campId,
            expectedLifecycleVersion: version,
            in: database
        )
        return version
    }

    private static func insertThreadScope(
        id: String,
        scopeKind: LegacyContentScopeKindV1,
        campId: String?,
        cowId: String,
        evidenceKind: LegacyContentEvidenceKindV1,
        createdAt: Date,
        in database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO legacy_chat_scope(
                  threadId,scopeKind,campId,cowId,evidenceKind,createdAt
                ) VALUES (?,?,?,?,?,?)
                """,
            arguments: [
                id, scopeKind.rawValue, campId, cowId,
                evidenceKind.rawValue, createdAt,
            ]
        )
    }

    private static func decodeScope(
        row: Row,
        idColumn: String,
        sourceThreadId: String?
    ) throws -> LegacyContentScopeSnapshotV1 {
        guard let kind = LegacyContentScopeKindV1(
            rawValue: row["scopeKind"] as String
        ), let evidence = LegacyContentEvidenceKindV1(
            rawValue: row["evidenceKind"] as String
        ) else {
            throw LegacyContentScopeError.malformedScope(row[idColumn])
        }
        let campID: String? = row["campId"]
        guard (kind == .camp && campID != nil)
                || (kind == .globalCow && campID == nil)
        else {
            throw LegacyContentScopeError.malformedScope(row[idColumn])
        }
        return LegacyContentScopeSnapshotV1(
            id: row[idColumn],
            scopeKind: kind,
            campId: campID,
            cowId: row["cowId"],
            sourceThreadId: sourceThreadId,
            evidenceKind: evidence,
            createdAt: row["createdAt"]
        )
    }

    private static func validateCanonicalObject(_ json: String) throws {
        do {
            let canonical = try CanonicalJSONV1.canonicalizeWithRootKind(
                rawUTF8: Data(json.utf8)
            )
            guard canonical.rootKind == .object,
                  canonical.data == Data(json.utf8)
            else {
                throw LegacyContentScopeError.noncanonicalContent
            }
        } catch is LegacyContentScopeError {
            throw LegacyContentScopeError.noncanonicalContent
        } catch {
            throw LegacyContentScopeError.noncanonicalContent
        }
    }
}

package enum LegacyContentScopeMigrationV1 {
    package static func backfill(in database: Database) throws {
        try backfillCowIdentityAndResidency(in: database)
        try backfillThreads(in: database)
        try backfillNotes(in: database)
    }

    private static func backfillCowIdentityAndResidency(
        in database: Database
    ) throws {
        let dangling = try String.fetchAll(
            database,
            sql: """
                SELECT companion.id
                FROM companion
                LEFT JOIN camp ON camp.id = companion.campId
                WHERE companion.campId IS NOT NULL AND camp.id IS NULL
                ORDER BY companion.id
                """
        )
        guard dangling.isEmpty else {
            throw P1EMigrationIntegrityError(
                code: "dangling_companion_camp",
                subject: dangling.joined(separator: ",")
            )
        }

        try database.execute(
            sql: """
                INSERT INTO cow_identity(
                  id,displayName,appearanceRef,personality,baseRole,
                  defaultEnginePolicyJson,status,aggregateVersion,createdAt,
                  updatedAt
                )
                SELECT id,name,color,rolePrompt,kind,'{}','active',1,createdAt,
                       createdAt
                FROM companion
                ORDER BY id
                """
        )
        try database.execute(
            sql: """
                INSERT INTO camp_residency(
                  id,cowId,campId,role,status,idempotencyKey,joinedAt,pausedAt,
                  leftAt,revokedAt,aggregateVersion,createdAt,updatedAt
                )
                SELECT 'legacy-residency:' || companion.id || ':' || camp.id,
                       companion.id,camp.id,companion.kind,'active',
                       'legacy:' || companion.id || ':' || camp.id,
                       companion.createdAt,NULL,NULL,NULL,1,
                       companion.createdAt,companion.createdAt
                FROM companion
                JOIN camp ON camp.id = companion.campId
                ORDER BY companion.id,camp.id
                """
        )

        let companionCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM companion"
        ) ?? -1
        let cowCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM cow_identity"
        ) ?? -1
        let expectedResidencies = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM companion WHERE campId IS NOT NULL"
        ) ?? -1
        let residencyCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM camp_residency"
        ) ?? -1
        guard companionCount == cowCount,
              expectedResidencies == residencyCount
        else {
            throw P1EMigrationIntegrityError(
                code: "identity_backfill_count_mismatch",
                subject: "companion=\(companionCount),cow=\(cowCount),expectedResidency=\(expectedResidencies),residency=\(residencyCount)"
            )
        }
    }

    private static func backfillThreads(in database: Database) throws {
        let rows = try Row.fetchAll(
            database,
            sql: """
                SELECT thread.id,thread.kind,thread.companionId,
                       thread.campId,thread.createdAt,
                       companion.campId AS companionCampId
                FROM chat_thread AS thread
                LEFT JOIN companion ON companion.id = thread.companionId
                ORDER BY thread.id
                """
        )
        for row in rows {
            let threadID: String = row["id"]
            let kind: String = row["kind"]
            let cowID: String = row["companionId"]
            let campID: String? = row["campId"]
            let companionCampID: String? = row["companionCampId"]
            let createdAt: Date = row["createdAt"]
            let companionExists = try Bool.fetchOne(
                database,
                sql: "SELECT EXISTS(SELECT 1 FROM companion WHERE id=?)",
                arguments: [cowID]
            ) ?? false
            guard companionExists else {
                throw P1EMigrationIntegrityError(
                    code: "legacy_thread_missing_cow",
                    subject: threadID
                )
            }

            let scopeKind: String
            let evidenceKind: String
            switch (kind, campID, companionCampID) {
            case ("dm", nil, nil):
                scopeKind = "globalCow"
                evidenceKind = "dmThread"
            case let ("guide", .some(threadCamp), .some(cowCamp))
                where threadCamp == cowCamp:
                scopeKind = "camp"
                evidenceKind = "guideThread"
            case ("dm", _, _), ("guide", _, _):
                throw P1EMigrationIntegrityError(
                    code: "legacy_thread_scope_mismatch",
                    subject: threadID
                )
            case let (unknown, _, _):
                throw P1EMigrationIntegrityError(
                    code: "legacy_thread_unknown_kind",
                    subject: "\(threadID):\(unknown)"
                )
            }
            try database.execute(
                sql: """
                    INSERT INTO legacy_chat_scope(
                      threadId,scopeKind,campId,cowId,evidenceKind,createdAt
                    ) VALUES (?,?,?,?,?,?)
                    """,
                arguments: [
                    threadID, scopeKind, campID, cowID, evidenceKind, createdAt,
                ]
            )
        }
    }

    private static func backfillNotes(in database: Database) throws {
        let notes = try CompanionNoteRecord
            .order(Column("id"))
            .fetchAll(database)
        let creatorEvents = try EventRecord
            .filter(Column("kind") == EventKind.companionNoteCreated)
            .order(Column("createdAt"), Column("id"))
            .fetchAll(database)
        for note in notes {
            if let threadID = note.sourceThreadId {
                let scope = try Row.fetchOne(
                    database,
                    sql: """
                        SELECT scopeKind,campId,cowId,evidenceKind,createdAt
                        FROM legacy_chat_scope WHERE threadId=?
                        """,
                    arguments: [threadID]
                )
                guard let scope else {
                    throw P1EMigrationIntegrityError(
                        code: "legacy_note_missing_thread_scope",
                        subject: note.id
                    )
                }
                let cowID: String = scope["cowId"]
                guard cowID == note.companionId else {
                    throw P1EMigrationIntegrityError(
                        code: "legacy_note_thread_cow_mismatch",
                        subject: note.id
                    )
                }
                try insertNoteScope(
                    note: note,
                    scopeKind: scope["scopeKind"],
                    campID: scope["campId"],
                    evidenceKind: scope["evidenceKind"],
                    in: database
                )
                continue
            }

            let matchingCreators = try creatorEvents.filter { event in
                try payloadString(event.payloadJson, key: "noteId") == note.id
            }
            guard matchingCreators.count <= 1 else {
                throw P1EMigrationIntegrityError(
                    code: "legacy_note_multiple_creators",
                    subject: note.id
                )
            }
            guard let creator = matchingCreators.first else {
                try insertNoteScope(
                    note: note,
                    scopeKind: "globalCow",
                    campID: nil,
                    evidenceKind: "manualCow",
                    in: database
                )
                continue
            }
            if let payloadCow = try payloadString(
                creator.payloadJson,
                key: "companionId"
            ), payloadCow != note.companionId {
                throw P1EMigrationIntegrityError(
                    code: "legacy_note_creator_cow_mismatch",
                    subject: note.id
                )
            }
            guard let missionID = creator.missionId,
                  let campID = try missionCampID(
                    missionID,
                    in: database
                  )
            else {
                throw P1EMigrationIntegrityError(
                    code: "legacy_note_creator_missing_mission",
                    subject: note.id
                )
            }
            try insertNoteScope(
                note: note,
                scopeKind: "camp",
                campID: campID,
                evidenceKind: "coworkEvent",
                in: database
            )
        }
    }

    private static func insertNoteScope(
        note: CompanionNoteRecord,
        scopeKind: String,
        campID: String?,
        evidenceKind: String,
        in database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO legacy_companion_note_scope(
                  noteId,scopeKind,campId,cowId,sourceThreadId,evidenceKind,
                  createdAt
                ) VALUES (?,?,?,?,?,?,?)
                """,
            arguments: [
                note.id, scopeKind, campID, note.companionId,
                note.sourceThreadId, evidenceKind, note.createdAt,
            ]
        )
    }

    private static func missionCampID(
        _ missionID: String,
        in database: Database
    ) throws -> String? {
        try String.fetchOne(
            database,
            sql: """
                SELECT squad.campId
                FROM mission JOIN squad ON squad.id=mission.squadId
                WHERE mission.id=?
                """,
            arguments: [missionID]
        )
    }

    private static func payloadString(
        _ json: String,
        key: String
    ) throws -> String? {
        guard let object = try JSONSerialization.jsonObject(
            with: Data(json.utf8)
        ) as? [String: Any] else {
            throw P1EMigrationIntegrityError(
                code: "legacy_payload_not_object",
                subject: key
            )
        }
        guard let value = object[key] else { return nil }
        guard let string = value as? String, !string.isEmpty else {
            throw P1EMigrationIntegrityError(
                code: "legacy_payload_value_malformed",
                subject: key
            )
        }
        return string
    }
}
