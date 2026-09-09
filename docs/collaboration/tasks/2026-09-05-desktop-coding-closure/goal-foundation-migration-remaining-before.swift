import Foundation
import GRDB
import Testing
import AgentLoopCore

private struct DesktopGoalCarrierSchemaSnapshot: Equatable {
    let contextDDL: String
    let operationDDL: String
    let pendingIndexDDL: String
    let contextColumns: [String]
    let operationColumns: [String]
    let contextForeignKeys: [String]
    let operationForeignKeys: [String]
    let pendingIndexColumns: [String]
    let pendingIndexIsUnique: Int
    let pendingIndexIsPartial: Int
}

private func desktopGoalMigrationQueue(_ label: String) throws -> DatabaseQueue {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "agentloop-desktop-goal-migration-\(label)-\(UUID().uuidString).sqlite"
    )
    return try DatabaseQueue(path: url.path, configuration: configuration)
}

private func desktopGoalNormalizedSQL(_ sql: String) -> String {
    sql.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func desktopGoalColumnShapes(
    _ database: Database,
    table: String
) throws -> [String] {
    try Row.fetchAll(
        database,
        sql: "PRAGMA table_info(\"\(table)\")"
    ).map { row in
        let name: String = row["name"]
        let type: String = row["type"]
        let notNull: Int = row["notnull"]
        let defaultValue: String? = row["dflt_value"]
        let primaryKey: Int = row["pk"]
        return "\(name)|\(type)|\(notNull)|\(defaultValue ?? "NULL")|\(primaryKey)"
    }
}

private func desktopGoalForeignKeyShapes(
    _ database: Database,
    table: String
) throws -> [String] {
    try Row.fetchAll(
        database,
        sql: "PRAGMA foreign_key_list(\"\(table)\")"
    ).map { row in
        let from: String = row["from"]
        let referencedTable: String = row["table"]
        let to: String = row["to"]
        let onUpdate: String = row["on_update"]
        let onDelete: String = row["on_delete"]
        return "\(from)|\(referencedTable)|\(to)|\(onUpdate)|\(onDelete)"
    }.sorted()
}

private func desktopGoalCarrierSchema(
    _ database: Database
) throws -> DesktopGoalCarrierSchemaSnapshot {
    let objects = Set(try String.fetchAll(
        database,
        sql: """
            SELECT type || ':' || name
            FROM sqlite_master
            WHERE name IN (
              'desktop_goal_context',
              'desktop_goal_operation',
              'desktop_goal_one_pending'
            )
            ORDER BY type,name
            """
    ))
    try #require(objects == Set([
        "table:desktop_goal_context",
        "table:desktop_goal_operation",
        "index:desktop_goal_one_pending",
    ]))

    let contextDDL = try #require(try String.fetchOne(
        database,
        sql: """
            SELECT sql FROM sqlite_master
            WHERE type='table' AND name='desktop_goal_context'
            """
    ))
    let operationDDL = try #require(try String.fetchOne(
        database,
        sql: """
            SELECT sql FROM sqlite_master
            WHERE type='table' AND name='desktop_goal_operation'
            """
    ))
    let pendingIndexDDL = try #require(try String.fetchOne(
        database,
        sql: """
            SELECT sql FROM sqlite_master
            WHERE type='index' AND name='desktop_goal_one_pending'
            """
    ))
    let indexRows = try Row.fetchAll(
        database,
        sql: "PRAGMA index_list(\"desktop_goal_operation\")"
    )
    let pendingIndex = try #require(indexRows.first { row in
        let name: String = row["name"]
        return name == "desktop_goal_one_pending"
    })
    let pendingIndexColumns = try Row.fetchAll(
        database,
        sql: "PRAGMA index_info(\"desktop_goal_one_pending\")"
    ).map { row -> String in
        row["name"]
    }

    return DesktopGoalCarrierSchemaSnapshot(
        contextDDL: desktopGoalNormalizedSQL(contextDDL),
        operationDDL: desktopGoalNormalizedSQL(operationDDL),
        pendingIndexDDL: desktopGoalNormalizedSQL(pendingIndexDDL),
        contextColumns: try desktopGoalColumnShapes(
            database,
            table: "desktop_goal_context"
        ),
        operationColumns: try desktopGoalColumnShapes(
            database,
            table: "desktop_goal_operation"
        ),
        contextForeignKeys: try desktopGoalForeignKeyShapes(
            database,
            table: "desktop_goal_context"
        ),
        operationForeignKeys: try desktopGoalForeignKeyShapes(
            database,
            table: "desktop_goal_operation"
        ),
        pendingIndexColumns: pendingIndexColumns,
        pendingIndexIsUnique: pendingIndex["unique"],
        pendingIndexIsPartial: pendingIndex["partial"]
    )
}

@Suite(.serialized)
struct DesktopGoalMigrationTests {
    @Test func freshAndV17UpgradeProduceSameDesktopCarrierSchema() throws {
        let freshQueue = try desktopGoalMigrationQueue("fresh")
        let upgradeQueue = try desktopGoalMigrationQueue("v17-upgrade")

        try AppDatabase.migrator.migrate(freshQueue)
        try AppDatabase.migrator.migrate(
            upgradeQueue,
            upTo: "v17-p1-engine-coordination"
        )
        try AppDatabase.migrator.migrate(upgradeQueue)

        let registeredHead = try #require(
            AppDatabase.migrator.migrations.last
        )
        let freshMigrations = try freshQueue.read { database in
            try String.fetchAll(
                database,
                sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
            )
        }
        let upgradeMigrations = try upgradeQueue.read { database in
            try String.fetchAll(
                database,
                sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
            )
        }
        let freshHead = try #require(freshMigrations.last)
        let upgradeHead = try #require(upgradeMigrations.last)
        try #require(registeredHead == "desktop-goal-workflow-v1")
        try #require(freshHead == "desktop-goal-workflow-v1")
        try #require(upgradeHead == "desktop-goal-workflow-v1")
        #expect(freshMigrations == upgradeMigrations)

        let freshSchema = try freshQueue.read(desktopGoalCarrierSchema)
        let upgradeSchema = try upgradeQueue.read(desktopGoalCarrierSchema)
        #expect(freshSchema == upgradeSchema)

        let expectedContextDDL = desktopGoalNormalizedSQL("""
            CREATE TABLE desktop_goal_context (
              inputId TEXT PRIMARY KEY NOT NULL,
              goalId TEXT NOT NULL UNIQUE,
              campId TEXT NOT NULL,
              version INTEGER NOT NULL CHECK(version > 0),
              contextJson TEXT,
              contextHash TEXT NOT NULL,
              retentionState TEXT NOT NULL CHECK(retentionState IN ('live','redacted')),
              createdAt DATETIME NOT NULL,
              updatedAt DATETIME NOT NULL,
              CHECK((retentionState='live' AND contextJson IS NOT NULL)
                 OR (retentionState='redacted' AND contextJson IS NULL))
            )
            """)
        let expectedOperationDDL = desktopGoalNormalizedSQL("""
            CREATE TABLE desktop_goal_operation (
              id TEXT PRIMARY KEY NOT NULL,
              inputId TEXT NOT NULL,
              kind TEXT NOT NULL,
              ownerKind TEXT NOT NULL CHECK(ownerKind IN ('userMutation','system','coachAttempt','verificationAttempt')),
              version INTEGER NOT NULL CHECK(version > 0),
              requestJson TEXT,
              requestHash TEXT NOT NULL,
              phase TEXT NOT NULL CHECK(phase IN ('prepared','committed','failed','redacted')),
              resultJson TEXT,
              safeReceiptJson TEXT,
              safeErrorCode TEXT,
              createdAt DATETIME NOT NULL,
              updatedAt DATETIME NOT NULL,
              FOREIGN KEY(inputId) REFERENCES desktop_goal_context(inputId),
              CHECK((phase='redacted' AND requestJson IS NULL AND resultJson IS NULL)
                 OR (phase<>'redacted' AND requestJson IS NOT NULL))
            )
            """)
        let expectedPendingIndexDDL = desktopGoalNormalizedSQL("""
            CREATE UNIQUE INDEX desktop_goal_one_pending
              ON desktop_goal_operation(inputId)
              WHERE phase='prepared' AND ownerKind='userMutation'
            """)

        #expect(freshSchema.contextDDL == expectedContextDDL)
        #expect(freshSchema.operationDDL == expectedOperationDDL)
        #expect(freshSchema.pendingIndexDDL == expectedPendingIndexDDL)
        #expect(freshSchema.contextColumns == [
            "inputId|TEXT|1|NULL|1",
            "goalId|TEXT|1|NULL|0",
            "campId|TEXT|1|NULL|0",
            "version|INTEGER|1|NULL|0",
            "contextJson|TEXT|0|NULL|0",
            "contextHash|TEXT|1|NULL|0",
            "retentionState|TEXT|1|NULL|0",
            "createdAt|DATETIME|1|NULL|0",
            "updatedAt|DATETIME|1|NULL|0",
        ])
        #expect(freshSchema.operationColumns == [
            "id|TEXT|1|NULL|1",
            "inputId|TEXT|1|NULL|0",
            "kind|TEXT|1|NULL|0",
            "ownerKind|TEXT|1|NULL|0",
            "version|INTEGER|1|NULL|0",
            "requestJson|TEXT|0|NULL|0",
            "requestHash|TEXT|1|NULL|0",
            "phase|TEXT|1|NULL|0",
            "resultJson|TEXT|0|NULL|0",
            "safeReceiptJson|TEXT|0|NULL|0",
            "safeErrorCode|TEXT|0|NULL|0",
            "createdAt|DATETIME|1|NULL|0",
            "updatedAt|DATETIME|1|NULL|0",
        ])
        #expect(freshSchema.contextForeignKeys.isEmpty)
        #expect(freshSchema.operationForeignKeys == [
            "inputId|desktop_goal_context|inputId|NO ACTION|NO ACTION",
        ])
        #expect(freshSchema.pendingIndexColumns == ["inputId"])
        #expect(freshSchema.pendingIndexIsUnique == 1)
        #expect(freshSchema.pendingIndexIsPartial == 1)

        for queue in [freshQueue, upgradeQueue] {
            try queue.read { database in
                let foreignKeyViolations = try Row.fetchAll(
                    database,
                    sql: "PRAGMA foreign_key_check"
                )
                let integrityResult = try String.fetchAll(
                    database,
                    sql: "PRAGMA integrity_check"
                )
                #expect(foreignKeyViolations.isEmpty)
                #expect(integrityResult == ["ok"])
            }
        }
    }
}
