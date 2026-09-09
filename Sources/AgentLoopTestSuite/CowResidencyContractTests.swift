import Foundation
import GRDB
import Testing
@testable import AgentLoopCore

let p1eE2Epoch = Date(timeIntervalSince1970: 3_000)
private let p1eE2DeviceID = "31000000-0000-4000-8000-000000000001"

func p1eE2Database(_ label: String) throws -> AppDatabase {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "agentloop-p1e-e2-\(label)-\(UUID().uuidString)"
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return try AppDatabase(path: root.appendingPathComponent("db.sqlite").path)
}

func p1eE2Envelope(
    _ key: String,
    actorType: DomainActorType = .user,
    actorID: String = "user:local-owner",
    at: Date = p1eE2Epoch
) throws -> CommandEnvelopeV1 {
    try CommandEnvelopeV1(
        idempotencyKey: key,
        actorType: actorType,
        actorId: actorID,
        deviceId: actorType == .user ? p1eE2DeviceID : nil,
        correlationId: "trace:\(key)",
        causationId: nil,
        occurredAt: at
    )
}

@discardableResult
func p1eE2SeedCamp(
    _ id: String,
    database: AppDatabase,
    archived: Bool = false
) throws -> CampRecord {
    let camp = CampRecord(
        id: id,
        name: "P1-E \(id)",
        archived: archived,
        createdAt: p1eE2Epoch
    )
    try database.pool.write { db in
        try camp.insert(db)
        try db.execute(
            sql: """
                INSERT INTO camp_lifecycle(
                  campId,state,version,createdAt,updatedAt,
                  deletionRequestedAt,deletedAt
                ) VALUES (?,?,1,?,?,NULL,NULL)
                """,
            arguments: [
                id, archived ? "archived" : "active",
                p1eE2Epoch, p1eE2Epoch,
            ]
        )
    }
    return camp
}

@discardableResult
func p1eE2SeedCow(
    _ id: String,
    database: AppDatabase,
    campID: String? = nil
) throws -> CowIdentitySnapshotV1 {
    let companion = CompanionRecord(
        id: id,
        name: "Cow \(id)",
        color: "amber",
        rolePrompt: "Careful builder",
        model: "test-model",
        toolsJson: "[]",
        kind: .regular,
        campId: campID,
        createdAt: p1eE2Epoch
    )
    try database.pool.write { db in
        try companion.insert(db)
    }
    return try CowResidencyStore(database: database).synchronizeCompanion(
        companion,
        provisionActiveResidency: false
    )
}

@discardableResult
func p1eE2ActivateResidency(
    store: CowResidencyStore,
    cowID: String,
    campID: String,
    suffix: String
) throws -> CampResidencySnapshotV1 {
    let requested = try store.request(
        RequestCampResidencyCommandV1(
            envelope: p1eE2Envelope("p1e:\(suffix):request"),
            residencyId: "residency:\(suffix)",
            cowId: cowID,
            campId: campID,
            role: "builder",
            expectedCampLifecycleVersion: 1
        )
    )
    let authorized = try store.transition(
        ChangeCampResidencyCommandV1(
            envelope: p1eE2Envelope("p1e:\(suffix):authorize"),
            residencyId: requested.id,
            expectedAggregateVersion: requested.aggregateVersion,
            transition: .authorize,
            expectedCampLifecycleVersion: 1
        )
    )
    return try store.transition(
        ChangeCampResidencyCommandV1(
            envelope: p1eE2Envelope("p1e:\(suffix):activate"),
            residencyId: authorized.id,
            expectedAggregateVersion: authorized.aggregateVersion,
            transition: .activate,
            expectedCampLifecycleVersion: 1
        )
    )
}

private func p1eE2PackageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Suite(.serialized)
struct P1ECowResidencyContractTests {
    @Test func p1e17CowIdentityContractValidation() throws {
        let valid = try CowIdentitySnapshotV1(
            id: "cow:identity:1",
            displayName: "Builder",
            appearanceRef: "amber",
            personality: "Patient and precise",
            baseRole: "builder",
            defaultEnginePolicyJson: "{}",
            status: .active,
            aggregateVersion: 1,
            createdAt: p1eE2Epoch,
            updatedAt: p1eE2Epoch
        )
        #expect(valid.id == "cow:identity:1")
        #expect(valid.defaultEnginePolicyJson == "{}")

        #expect(throws: P1ContractValidationError.self) {
            _ = try CowIdentitySnapshotV1(
                id: valid.id,
                displayName: " Builder ",
                appearanceRef: valid.appearanceRef,
                personality: valid.personality,
                baseRole: valid.baseRole,
                defaultEnginePolicyJson: valid.defaultEnginePolicyJson,
                status: .active,
                aggregateVersion: 1,
                createdAt: p1eE2Epoch,
                updatedAt: p1eE2Epoch
            )
        }
        #expect(throws: CanonicalJSONNotCanonicalError.self) {
            _ = try CowIdentitySnapshotV1(
                id: valid.id,
                displayName: valid.displayName,
                appearanceRef: valid.appearanceRef,
                personality: valid.personality,
                baseRole: valid.baseRole,
                defaultEnginePolicyJson: "{ \"model\" : \"x\" }",
                status: .active,
                aggregateVersion: 1,
                createdAt: p1eE2Epoch,
                updatedAt: p1eE2Epoch
            )
        }

        let database = try p1eE2Database("cow-sync")
        let companion = CompanionRecord(
            id: "cow:sync:1",
            name: "Synced Cow",
            color: "blue",
            rolePrompt: "Reviewer",
            model: "test-model",
            toolsJson: "[]",
            kind: .regular,
            campId: nil,
            createdAt: p1eE2Epoch
        )
        try database.pool.write { try companion.insert($0) }
        let synced = try CowResidencyStore(database: database)
            .synchronizeCompanion(
                companion,
                provisionActiveResidency: false
            )
        #expect(synced.id == companion.id)
        #expect(synced.displayName == companion.name)
        #expect(synced.personality == companion.rolePrompt)
    }

    @Test func p1e18ResidencyTransitionsReplayAndRejoin() throws {
        let database = try p1eE2Database("residency-transitions")
        _ = try p1eE2SeedCamp("camp:residency", database: database)
        _ = try p1eE2SeedCow("cow:residency", database: database)
        let store = CowResidencyStore(database: database)
        let request = try RequestCampResidencyCommandV1(
            envelope: p1eE2Envelope("residency:request"),
            residencyId: "residency:first",
            cowId: "cow:residency",
            campId: "camp:residency",
            role: "builder",
            expectedCampLifecycleVersion: 1
        )
        let first = try store.request(request)
        #expect(first.status == .requested)
        #expect(try store.request(request) == first)

        #expect(throws: DomainCommandReplayConflictError.self) {
            _ = try store.request(RequestCampResidencyCommandV1(
                envelope: request.envelope,
                residencyId: request.residencyId,
                cowId: request.cowId,
                campId: request.campId,
                role: "reviewer",
                expectedCampLifecycleVersion: 1
            ))
        }

        func change(
            _ current: CampResidencySnapshotV1,
            _ transition: CampResidencyTransitionV1,
            _ key: String
        ) throws -> CampResidencySnapshotV1 {
            let command = try ChangeCampResidencyCommandV1(
                envelope: p1eE2Envelope(key),
                residencyId: current.id,
                expectedAggregateVersion: current.aggregateVersion,
                transition: transition,
                expectedCampLifecycleVersion: 1
            )
            let result = try store.transition(command)
            #expect(try store.transition(command) == result)
            return result
        }

        let authorized = try change(first, .authorize, "residency:authorize")
        let active = try change(authorized, .activate, "residency:activate")
        let paused = try change(active, .pause, "residency:pause")
        let resumed = try change(paused, .resume, "residency:resume")
        let left = try change(resumed, .leave, "residency:leave")
        #expect(left.status == .left)
        #expect(throws: InvalidCampResidencyTransitionError.self) {
            _ = try change(left, .resume, "residency:illegal-resume")
        }

        let rejoin = try store.request(RequestCampResidencyCommandV1(
            envelope: p1eE2Envelope("residency:rejoin"),
            residencyId: "residency:second",
            cowId: first.cowId,
            campId: first.campId,
            role: first.role,
            expectedCampLifecycleVersion: 1
        ))
        #expect(rejoin.id != left.id)
        #expect(rejoin.status == .requested)
    }

    @Test func p1e19RequireActiveResidencyAuthorization() throws {
        let database = try p1eE2Database("active-authorization")
        _ = try p1eE2SeedCamp("camp:authorization", database: database)
        _ = try p1eE2SeedCow("cow:authorization", database: database)
        let store = CowResidencyStore(database: database)
        let active = try p1eE2ActivateResidency(
            store: store,
            cowID: "cow:authorization",
            campID: "camp:authorization",
            suffix: "authorization"
        )
        #expect(
            try store.requireActiveResidency(
                cowId: active.cowId,
                campId: active.campId
            ) == active
        )

        let paused = try store.transition(ChangeCampResidencyCommandV1(
            envelope: p1eE2Envelope("authorization:pause"),
            residencyId: active.id,
            expectedAggregateVersion: active.aggregateVersion,
            transition: .pause,
            expectedCampLifecycleVersion: 1
        ))
        #expect(paused.status == .paused)
        #expect(throws: ResidencyAuthorizationError.inactive(.paused)) {
            _ = try store.requireActiveResidency(
                cowId: active.cowId,
                campId: active.campId
            )
        }
        #expect(throws: ResidencyAuthorizationError.missing) {
            _ = try store.requireActiveResidency(
                cowId: "cow:missing",
                campId: active.campId
            )
        }
    }

    @Test func p1e22BridgeDirectionScopeAndRevocation() throws {
        let database = try p1eE2Database("bridge")
        _ = try p1eE2SeedCamp("camp:source", database: database)
        _ = try p1eE2SeedCamp("camp:target", database: database)
        _ = try p1eE2SeedCow("cow:bridge", database: database)
        let residency = CowResidencyStore(database: database)
        _ = try p1eE2ActivateResidency(
            store: residency,
            cowID: "cow:bridge",
            campID: "camp:source",
            suffix: "bridge-source"
        )
        _ = try p1eE2ActivateResidency(
            store: residency,
            cowID: "cow:bridge",
            campID: "camp:target",
            suffix: "bridge-target"
        )
        let memoryStore = MemoryRecordStore(database: database)
        let sourceMemory = try memoryStore.record(
            try MemoryRecordDraftV1(
                id: "memory:source",
                layer: .working,
                ownerType: .cow,
                ownerId: "cow:bridge",
                campId: "camp:source",
                title: "Source-only",
                bodyText: "source body",
                contentRef: nil,
                sourceType: .inference,
                applicabilityJson: "{}",
                createdByActorId: "cow:bridge",
                confirmedByActorId: nil
            ),
            authorizedCowId: "cow:bridge",
            expectedCampLifecycleVersion: 1,
            at: p1eE2Epoch
        )
        let bridge = try residency.createBridge(CreateCampBridgeCommandV1(
            envelope: p1eE2Envelope("bridge:create"),
            bridgeId: "bridge:source-target",
            sourceCampId: "camp:source",
            targetCampId: "camp:target",
            mode: .reference,
            contentScope: try CampBridgeContentScopeV1(
                memoryIds: [sourceMemory.id]
            ),
            grantedByActorId: "user:local-owner",
            validUntil: p1eE2Epoch.addingTimeInterval(600),
            expectedSourceLifecycleVersion: 1,
            expectedTargetLifecycleVersion: 1
        ))
        let bridged = try residency.authorizedMemory(
            cowId: "cow:bridge",
            campId: "camp:target",
            bridges: [CampBridgeReadV1(
                sourceCampId: "camp:source",
                memoryIds: [sourceMemory.id]
            )],
            at: p1eE2Epoch
        )
        #expect(bridged.contains(where: { $0.id == sourceMemory.id }))

        #expect(throws: CampBridgeAuthorizationError.self) {
            _ = try residency.authorizedMemory(
                cowId: "cow:bridge",
                campId: "camp:source",
                bridges: [CampBridgeReadV1(
                    sourceCampId: "camp:target",
                    memoryIds: [sourceMemory.id]
                )],
                at: p1eE2Epoch
            )
        }
        _ = try residency.revokeBridge(RevokeCampBridgeCommandV1(
            envelope: p1eE2Envelope("bridge:revoke"),
            bridgeId: bridge.id,
            expectedAggregateVersion: bridge.aggregateVersion,
            expectedSourceLifecycleVersion: 1,
            expectedTargetLifecycleVersion: 1
        ))
        #expect(throws: CampBridgeAuthorizationError.self) {
            _ = try residency.authorizedMemory(
                cowId: "cow:bridge",
                campId: "camp:target",
                bridges: [CampBridgeReadV1(
                    sourceCampId: "camp:source",
                    memoryIds: [sourceMemory.id]
                )],
                at: p1eE2Epoch
            )
        }
    }

    @Test func p1e23RequireActiveCampWriteFence() throws {
        let database = try p1eE2Database("lifecycle-fence")
        _ = try p1eE2SeedCamp("camp:lifecycle", database: database)
        let store = CampLifecycleStore(database: database)
        try database.pool.read { db in
            let lifecycle = try store.requireActiveCampWrite(
                campId: "camp:lifecycle",
                expectedLifecycleVersion: 1,
                database: db
            )
            #expect(lifecycle.state == .active)
            #expect(lifecycle.version == 1)
        }
        #expect(throws: CampLifecycleWriteAuthorizationError.self) {
            try database.pool.read { db in
                _ = try store.requireActiveCampWrite(
                    campId: "camp:lifecycle",
                    expectedLifecycleVersion: 2,
                    database: db
                )
            }
        }

        try database.pool.write { db in
            try db.execute(
                sql: "UPDATE camp SET archived=1 WHERE id='camp:lifecycle'"
            )
        }
        #expect(throws: CampLifecycleWriteAuthorizationError.legacyArchived) {
            try database.pool.read { db in
                _ = try store.requireActiveCampWrite(
                    campId: "camp:lifecycle",
                    expectedLifecycleVersion: 1,
                    database: db
                )
            }
        }
    }

    @Test func p1e24CampArchiveBlocksLiveWorkAndPreservesHistory() throws {
        let database = try p1eE2Database("camp-archive")
        let camp = try p1eE2SeedCamp(
            "camp:archive",
            database: database
        )
        let squad = SquadRecord(
            id: "squad:archive",
            campId: camp.id,
            name: "Archive blockers",
            memberIdsJson: "[]",
            workspacePath: nil,
            createdAt: p1eE2Epoch
        )
        var mission = MissionRecord(
            id: "mission:archive",
            squadId: squad.id,
            goalRaw: "Finish before archive",
            goalRefined: "Finish before archive",
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

        #expect(throws: CampArchiveBlockedError.activeMission) {
            try database.setCampArchived(id: camp.id, archived: true)
        }
        #expect(try database.camp(id: camp.id)?.archived == false)

        mission.status = .accepted
        try database.pool.write { try mission.update($0) }
        let scheduledCow = try p1eE2SeedCow(
            "cow:archive-schedule",
            database: database
        )
        let template = try MissionTemplateRecord.new(
            name: "Archive schedule",
            goal: "Run later",
            companionIds: [scheduledCow.id],
            workspacePath: nil,
            budgetTokens: 1_000,
            autonomy: .standard,
            campId: camp.id
        )
        try database.saveMissionTemplate(template)
        var schedule = ScheduleRecord.new(
            templateId: template.id,
            frequency: .daily,
            hour: 9,
            minute: 0,
            weekday: nil,
            enabled: true
        )
        try database.saveSchedule(schedule)

        #expect(throws: CampArchiveBlockedError.enabledSchedule) {
            try database.setCampArchived(id: camp.id, archived: true)
        }
        #expect(try database.camp(id: camp.id)?.archived == false)

        schedule.enabled = false
        try database.saveSchedule(schedule)
        try database.setCampArchived(id: camp.id, archived: true)
        #expect(try database.camp(id: camp.id)?.archived == true)
        #expect(try database.pool.read {
            try MissionRecord.fetchOne($0, key: mission.id) != nil
        })

        try database.setCampArchived(id: camp.id, archived: false)
        #expect(try database.camp(id: camp.id)?.archived == false)
        let lifecycleState = try database.pool.read {
            try String.fetchOne(
                $0,
                sql: "SELECT state FROM camp_lifecycle WHERE campId=?",
                arguments: [camp.id]
            )
        }
        #expect(lifecycleState == "active")
    }

    @Test func p1e25CustomCowRetirementPreservesHistoryAndLeavesRoster()
        throws
    {
        let database = try p1eE2Database("cow-retire")
        let camp = try p1eE2SeedCamp(
            "camp:cow-retire",
            database: database
        )
        let identity = try p1eE2SeedCow(
            "cow:custom-retire",
            database: database
        )
        let residency = try p1eE2ActivateResidency(
            store: CowResidencyStore(database: database),
            cowID: identity.id,
            campID: camp.id,
            suffix: "custom-retire"
        )
        let disabledTemplate = try MissionTemplateRecord.new(
            name: "Retired cow must stay retired",
            goal: "Never dispatch after retirement",
            companionIds: [identity.id],
            workspacePath: nil,
            budgetTokens: 1_000,
            autonomy: .standard,
            campId: camp.id
        )
        try database.saveMissionTemplate(disabledTemplate)
        let disabledSchedule = ScheduleRecord.new(
            templateId: disabledTemplate.id,
            frequency: .daily,
            hour: 11,
            minute: 0,
            weekday: nil,
            enabled: false
        )
        try database.saveSchedule(disabledSchedule)

        let receipt = try CowResidencyStore(database: database).retireCow(
            cowId: identity.id,
            at: p1eE2Epoch.addingTimeInterval(60)
        )

        #expect(receipt.identity.status == .retired)
        #expect(receipt.revokedResidencyIds == [residency.id])
        #expect(try database.companion(id: identity.id) != nil)
        #expect(!((try database.regularCompanions()).contains {
            $0.id == identity.id
        }))
        let residencyRow = try database.pool.read {
            try Row.fetchOne(
                $0,
                sql: "SELECT status,revokedAt FROM camp_residency WHERE id=?",
                arguments: [residency.id]
            )
        }
        #expect(residencyRow?["status"] as String? == "revoked")
        #expect(residencyRow?["revokedAt"] as Date? != nil)

        let replay = try CowResidencyStore(database: database).retireCow(
            cowId: identity.id,
            at: p1eE2Epoch.addingTimeInterval(120)
        )
        #expect(replay.identity == receipt.identity)
        #expect(replay.revokedResidencyIds.isEmpty)

        let staleTemplate = try MissionTemplateRecord.new(
            name: "Stale retired cow selection",
            goal: "Must fail before persistence",
            companionIds: [identity.id],
            workspacePath: nil,
            budgetTokens: 1_000,
            autonomy: .standard,
            campId: camp.id
        )
        #expect(
            throws: MissionTemplateValidationError.inactiveCompanion(
                identity.id
            )
        ) {
            try database.saveMissionTemplate(staleTemplate)
        }
        #expect(
            throws: MissionTemplateValidationError.inactiveCompanion(
                identity.id
            )
        ) {
            _ = try database.setScheduleEnabled(
                id: disabledSchedule.id,
                enabled: true
            )
        }
    }

    @Test func p1e27CowRetirementAcceptsRuntimeTimestampPrecision() throws {
        let database = try p1eE2Database("cow-retire-runtime-time")
        let identity = try p1eE2SeedCow(
            "cow:runtime-time-retire",
            database: database
        )
        let runtimeTime = p1eE2Epoch.addingTimeInterval(60.123_456)

        let receipt = try CowResidencyStore(database: database).retireCow(
            cowId: identity.id,
            at: runtimeTime
        )

        #expect(receipt.identity.status == .retired)
        let persistedUpdatedAt = try #require(try database.pool.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT updatedAt FROM cow_identity WHERE id=?",
                arguments: [identity.id]
            )
        })
        #expect(receipt.identity.updatedAt == persistedUpdatedAt)
        #expect(abs(runtimeTime.timeIntervalSince(persistedUpdatedAt)) < 0.001)
    }

    @Test func p1e26CowRetirementProtectsSystemAndScheduledCows() throws {
        let database = try p1eE2Database("cow-retire-blockers")
        let camp = try p1eE2SeedCamp(
            "camp:cow-retire-blockers",
            database: database
        )
        _ = try p1eE2SeedCow(CowTemplate.baseCowId, database: database)
        #expect(throws: CowRetirementBlockedError.protectedCow) {
            try CowResidencyStore(database: database).retireCow(
                cowId: CowTemplate.baseCowId,
                at: p1eE2Epoch.addingTimeInterval(60)
            )
        }

        let busyCow = try p1eE2SeedCow(
            "cow:busy-retire",
            database: database
        )
        let busySquad = SquadRecord(
            id: "squad:busy-retire",
            campId: camp.id,
            name: "Busy cow",
            memberIdsJson: try MissionTemplateRecord.companionIdsJSON(
                [busyCow.id]
            ),
            workspacePath: nil,
            createdAt: p1eE2Epoch
        )
        let busyMission = MissionRecord(
            id: "mission:busy-retire",
            squadId: busySquad.id,
            goalRaw: "Keep working",
            goalRefined: "Keep working",
            status: .executing,
            budgetTokens: 1_000,
            spentTokens: 0,
            revision: 1,
            createdAt: p1eE2Epoch
        )
        try database.pool.write { db in
            try busySquad.insert(db)
            try busyMission.insert(db)
        }
        #expect(throws: CowRetirementBlockedError.activeMission) {
            try CowResidencyStore(database: database).retireCow(
                cowId: busyCow.id,
                at: p1eE2Epoch.addingTimeInterval(60)
            )
        }

        let custom = try p1eE2SeedCow(
            "cow:scheduled-retire",
            database: database
        )
        let template = try MissionTemplateRecord.new(
            name: "Cow schedule",
            goal: "Use this cow later",
            companionIds: [custom.id],
            workspacePath: nil,
            budgetTokens: 1_000,
            autonomy: .standard,
            campId: camp.id
        )
        try database.saveMissionTemplate(template)
        let schedule = ScheduleRecord.new(
            templateId: template.id,
            frequency: .daily,
            hour: 10,
            minute: 0,
            weekday: nil,
            enabled: true
        )
        try database.saveSchedule(schedule)

        #expect(throws: CowRetirementBlockedError.enabledSchedule) {
            try CowResidencyStore(database: database).retireCow(
                cowId: custom.id,
                at: p1eE2Epoch.addingTimeInterval(60)
            )
        }
        #expect((try database.regularCompanions()).contains {
            $0.id == custom.id
        })
    }
}
