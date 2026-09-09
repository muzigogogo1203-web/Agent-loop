import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

private func p1eE3SeedGuide(
    campID: String,
    database: AppDatabase
) throws -> CompanionRecord {
    let guide = CompanionRecord(
        id: "guide:\(campID)",
        name: "Guide",
        color: "amber",
        rolePrompt: "Guide the Camp",
        model: "test-model",
        toolsJson: "[]",
        kind: .guide,
        campId: campID,
        createdAt: p1eE2Epoch
    )
    try database.pool.write { try guide.insert($0) }
    _ = try CowResidencyStore(database: database).synchronizeCompanion(
        guide,
        provisionActiveResidency: true
    )
    return guide
}

private func p1eE3SeedMission(
    suffix: String,
    campID: String,
    database: AppDatabase
) throws -> MissionRecord {
    let squad = SquadRecord(
        id: "squad:\(suffix)",
        campId: campID,
        name: "Squad \(suffix)",
        memberIdsJson: "[]",
        workspacePath: nil,
        createdAt: p1eE2Epoch
    )
    let mission = MissionRecord(
        id: "mission:\(suffix)",
        squadId: squad.id,
        goalRaw: "Goal \(suffix)",
        goalRefined: "Goal \(suffix)",
        status: .executing,
        budgetTokens: 1_000,
        spentTokens: 0,
        revision: 1,
        createdAt: p1eE2Epoch
    )
    try database.pool.write { db in
        try squad.insert(db)
        try mission.insert(db)
    }
    return mission
}

@Suite(.serialized)
struct P1ELegacyScopeMigrationTests {
    @Test func p1e33LegacyContentWritesScopeFirst() throws {
        let database = try p1eE2Database("legacy-content-scope-first")
        _ = try p1eE2SeedCamp("camp:scope", database: database)
        let guide = try p1eE3SeedGuide(
            campID: "camp:scope",
            database: database
        )
        _ = try p1eE2SeedCow("cow:scope", database: database)
        let store = LegacyContentScopeStore(database: database)

        let dm = try store.findOrCreateDMThread(cowId: "cow:scope")
        let guideThread = try store.findOrCreateGuideThread(
            campId: "camp:scope",
            expectedLifecycleVersion: 1
        )
        #expect(guideThread.companionId == guide.id)
        let dmMessage = try store.appendMessage(
            threadId: dm.id,
            role: "user",
            contentJson: "{\"text\":\"private\"}",
            expectedCampLifecycleVersion: nil
        )
        let guideMessage = try store.appendMessage(
            threadId: guideThread.id,
            role: "guide",
            contentJson: "{\"text\":\"camp\"}",
            expectedCampLifecycleVersion: 1
        )
        let note = CompanionNoteRecord(
            id: "note:scope:dm",
            companionId: "cow:scope",
            sourceThreadId: dm.id,
            title: "Preference",
            bodyMd: "Private preference",
            pinned: false,
            createdAt: p1eE2Epoch,
            updatedAt: p1eE2Epoch
        )
        try store.recordCompanionNote(
            note,
            scope: .sourceThread(dm.id),
            expectedCampLifecycleVersion: nil
        )

        let fetchedDMScope = try store.threadScope(id: dm.id)
        let dmScope = try #require(fetchedDMScope)
        #expect(dmScope.scopeKind == .globalCow)
        #expect(dmScope.campId == nil)
        #expect(dmScope.cowId == "cow:scope")
        #expect(dmScope.evidenceKind == .dmThread)
        let fetchedGuideScope = try store.threadScope(id: guideThread.id)
        let guideScope = try #require(fetchedGuideScope)
        #expect(guideScope.scopeKind == .camp)
        #expect(guideScope.campId == "camp:scope")
        #expect(guideScope.evidenceKind == .guideThread)
        let fetchedNoteScope = try store.noteScope(id: note.id)
        let noteScope = try #require(fetchedNoteScope)
        #expect(noteScope.scopeKind == .globalCow)
        #expect(noteScope.sourceThreadId == dm.id)
        #expect(try database.messages(threadId: dm.id).map(\.id) == [dmMessage])
        #expect(
            try database.messages(threadId: guideThread.id).map(\.id)
                == [guideMessage]
        )
    }

    @Test func p1e34LegacyContentRawWriteRejected() throws {
        let database = try p1eE2Database("legacy-content-raw")
        _ = try p1eE2SeedCamp("camp:raw-content", database: database)
        _ = try p1eE3SeedGuide(
            campID: "camp:raw-content",
            database: database
        )
        _ = try p1eE2SeedCow("cow:raw-content", database: database)

        #expect(throws: DatabaseError.self) {
            try database.pool.write { db in
                try ChatThreadRecord(
                    id: "thread:raw:dm",
                    kind: .dm,
                    companionId: "cow:raw-content",
                    campId: nil,
                    createdAt: p1eE2Epoch
                ).insert(db)
            }
        }
        #expect(throws: DatabaseError.self) {
            try database.pool.write { db in
                try CompanionNoteRecord(
                    id: "note:raw",
                    companionId: "cow:raw-content",
                    sourceThreadId: nil,
                    title: "Raw",
                    bodyMd: "Must not bypass typed scope",
                    pinned: false,
                    createdAt: p1eE2Epoch,
                    updatedAt: p1eE2Epoch
                ).insert(db)
            }
        }
        let store = LegacyContentScopeStore(database: database)
        #expect(
            throws: LegacyContentScopeError.lifecycleVersionRequired
        ) {
            _ = try store.findOrCreateGuideThread(
                campId: "camp:raw-content",
                expectedLifecycleVersion: nil
            )
        }
    }

    @Test func p1e35LegacyEventAppendScopeFirst() throws {
        let database = try p1eE2Database("legacy-event-scope-first")
        _ = try p1eE2SeedCamp("camp:event", database: database)
        try database.pool.write { db in
            try AppDatabase.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.campArchived,
                payload: ["campId": .string("camp:event")]
            )
            try AppDatabase.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.campHalted,
                payload: [:]
            )
            try AppDatabase.appendEvent(
                db,
                missionId: "",
                cardId: nil,
                runId: nil,
                kind: EventKind.kernelError,
                payload: ["message": .string("global startup failure")]
            )
            try AppDatabase.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.kernelError,
                payload: [
                    "large": .number(Double(Int.max)),
                    "message": .string("complete_card / block_card"),
                ]
            )
        }
        let rows = try database.pool.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT event.kind,event.payloadJson,
                           scope.scopeKind,scope.campId
                    FROM event
                    JOIN camp_event_scope AS scope
                      ON scope.sourceTable='event' AND scope.eventId=event.id
                    ORDER BY event.createdAt,event.rowid
                    """
            )
        }
        #expect(rows.count == 4)
        #expect(rows[0]["kind"] as String == EventKind.campArchived)
        #expect(rows[0]["scopeKind"] as String == "camp")
        #expect(rows[0]["campId"] as String? == "camp:event")
        #expect(rows[1]["kind"] as String == EventKind.campHalted)
        #expect(rows[1]["scopeKind"] as String == "global")
        #expect(rows[1]["campId"] as String? == nil)
        #expect(rows[2]["kind"] as String == EventKind.kernelError)
        #expect(rows[2]["scopeKind"] as String == "global")
        #expect(rows[2]["campId"] as String? == nil)
        #expect(rows[3]["kind"] as String == EventKind.kernelError)
        #expect(
            rows[3]["payloadJson"] as String
                == #"{"large":9223372036854776000,"message":"complete_card / block_card"}"#
        )
        #expect(rows[3]["scopeKind"] as String == "global")
        #expect(rows[3]["campId"] as String? == nil)
        #expect(LegacyEventScopeResolverV1.resolverKeys == EventKind.allPersistedKinds)
        #expect(LegacyEventScopeResolverV1.resolverKeys.count == 45)
    }

    @Test func p1e36LegacyEventMissingMismatchRejected() throws {
        let database = try p1eE2Database("legacy-event-reject")
        _ = try p1eE2SeedCamp("camp:event:a", database: database)
        _ = try p1eE2SeedCamp("camp:event:b", database: database)
        let missionA = try p1eE3SeedMission(
            suffix: "event-a",
            campID: "camp:event:a",
            database: database
        )
        let missionB = try p1eE3SeedMission(
            suffix: "event-b",
            campID: "camp:event:b",
            database: database
        )
        #expect(throws: DatabaseError.self) {
            try database.pool.write { db in
                try EventRecord(
                    id: "event:missing-scope",
                    missionId: missionA.id,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payloadJson: "{}",
                    createdAt: p1eE2Epoch
                ).insert(db)
            }
        }
        #expect(throws: P1EMigrationIntegrityError.self) {
            try database.pool.write { db in
                _ = try AppDatabase.appendLegacyEventAndScope(
                    db,
                    missionId: missionA.id,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: ["missionId": .string(missionB.id)]
                )
            }
        }
        let count = try database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event")
        }
        #expect(count == 0)
    }
}
