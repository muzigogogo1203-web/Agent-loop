import Foundation
import GRDB
import Testing
import AgentLoopCore

private func scheduleTempDB() throws -> AppDatabase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AppDatabase(path: directory.appendingPathComponent("schedule.sqlite").path)
}

private func scheduleCalendar(_ timeZoneID: String) -> (Calendar, TimeZone) {
    let timeZone = TimeZone(identifier: timeZoneID)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return (calendar, timeZone)
}

private func scheduleDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    timeZoneID: String
) -> Date {
    let (calendar, timeZone) = scheduleCalendar(timeZoneID)
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

private func scheduleStamp(_ date: Date, timeZoneID: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: timeZoneID)!
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}

private func scheduleTemplateFixture(
    db: AppDatabase,
    budgetTokens: Int? = 10_000,
    autonomy: MissionAutonomy = .standard
) throws -> (camp: CampRecord, companion: CompanionRecord, template: MissionTemplateRecord) {
    let camp = try db.ensureDefaultCamp()
    let companion = CompanionRecord.new(
        name: "甲",
        color: "blue",
        rolePrompt: "执行",
        model: "model-a",
        campId: camp.id
    )
    try db.saveCompanion(companion)
    let template = try MissionTemplateRecord.new(
        name: "每日晨报",
        goal: "整理今天的晨报",
        companionIds: [companion.id],
        workspacePath: nil,
        budgetTokens: budgetTokens,
        autonomy: autonomy,
        campId: camp.id
    )
    return (camp, companion, template)
}

@Test func scheduleMathDailyNextFireSameDay() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 8, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 9,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-14 09:30")
}

@Test func scheduleMathDailyNextFireMovesToTomorrowAfterSlot() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 10, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 9,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-15 09:30")
}

@Test func scheduleMathWeeklyNextFireSameWeek() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 8, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 4,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-15 09:00")
}

@Test func scheduleMathWeeklyNextFireWrapsAcrossWeek() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 16, 8, 0, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 4,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-07-22 09:00")
}

@Test func scheduleMathSpringForwardUsesNextValidLocalTime() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 3, 8, 0, 30, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 2,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    // .nextTime 语义:被春令时跳过的 02:30 顺延到首个有效时刻 03:00(而非保留分钟数的 03:30)
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-03-08 03:00")
}

@Test func scheduleMathFallBackChoosesFirstRepeatedLocalTime() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 11, 1, 0, 30, timeZoneID: "America/Los_Angeles")
    let next = try #require(ScheduleMath.nextFireDate(
        after: now,
        frequency: .daily,
        hour: 1,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(next, timeZoneID: "America/Los_Angeles") == "2026-11-01 01:30")
}

@Test func scheduleMathPreviousFireIsInclusive() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 9, 30, timeZoneID: "America/Los_Angeles")
    let previous = try #require(ScheduleMath.previousFireDate(
        onOrBefore: now,
        frequency: .daily,
        hour: 9,
        minute: 30,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(previous, timeZoneID: "America/Los_Angeles") == "2026-07-14 09:30")
}

@Test func scheduleMathMisfireDetectsPreviousUnfiredSlot() throws {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 10, 0, timeZoneID: "America/Los_Angeles")
    let createdAt = scheduleDate(2026, 7, 13, 8, 0, timeZoneID: "America/Los_Angeles")
    let missed = try #require(ScheduleMath.missedFireDate(
        now: now,
        createdAt: createdAt,
        lastFiredAt: nil,
        frequency: .daily,
        hour: 9,
        minute: 0,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(scheduleStamp(missed, timeZoneID: "America/Los_Angeles") == "2026-07-14 09:00")
}

@Test func scheduleMathMisfireIgnoresScheduleCreatedAfterSlot() {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let now = scheduleDate(2026, 7, 14, 10, 0, timeZoneID: "America/Los_Angeles")
    let createdAt = scheduleDate(2026, 7, 14, 9, 45, timeZoneID: "America/Los_Angeles")
    let missed = ScheduleMath.missedFireDate(
        now: now,
        createdAt: createdAt,
        lastFiredAt: nil,
        frequency: .daily,
        hour: 9,
        minute: 0,
        calendar: calendar,
        timeZone: timeZone
    )
    #expect(missed == nil)
}

@Test func scheduleMathSameSlotDedupeCoversDailyAndWeekly() {
    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let fire = scheduleDate(2026, 7, 14, 9, 0, timeZoneID: "America/Los_Angeles")
    let sameDayActual = scheduleDate(2026, 7, 14, 9, 2, timeZoneID: "America/Los_Angeles")
    #expect(ScheduleMath.alreadyFiredSameSlot(
        lastFiredAt: sameDayActual,
        fireDate: fire,
        frequency: .daily,
        calendar: calendar,
        timeZone: timeZone
    ))

    let nextDay = scheduleDate(2026, 7, 15, 9, 2, timeZoneID: "America/Los_Angeles")
    #expect(!ScheduleMath.alreadyFiredSameSlot(
        lastFiredAt: nextDay,
        fireDate: fire,
        frequency: .daily,
        calendar: calendar,
        timeZone: timeZone
    ))

    let sameWeeklySlot = scheduleDate(2026, 7, 14, 12, 0, timeZoneID: "America/Los_Angeles")
    #expect(ScheduleMath.alreadyFiredSameSlot(
        lastFiredAt: sameWeeklySlot,
        fireDate: fire,
        frequency: .weekly,
        calendar: calendar,
        timeZone: timeZone
    ))
}

@Test func scheduledTemplateValidationRejectsMissingBudgetAtSave() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db, budgetTokens: nil)
    #expect(throws: MissionTemplateValidationError.missingBudgetTokens) {
        try db.saveMissionTemplate(fixture.template)
    }
}

@Test func scheduledTemplateValidationRejectsFreeAutonomyAtSaveAndFireTime() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db, autonomy: .free)
    #expect(throws: MissionTemplateValidationError.freeAutonomyNotAllowed) {
        try db.saveMissionTemplate(fixture.template)
    }
    #expect(throws: MissionTemplateValidationError.freeAutonomyNotAllowed) {
        try fixture.template.validateForScheduledMission()
    }
}

@Test func evercampMigrationV9ReplaysFromV8() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pool = try DatabasePool(path: directory.appendingPathComponent("v8.sqlite").path)
    let migrator = AppDatabase.migrator
    #expect(migrator.migrations.contains("v9-evercamp"))
    try migrator.migrate(pool, upTo: "v8-coding-ranch")
    #expect(try pool.read { try !$0.tableExists("mission_template") })
    #expect(try pool.read { try !$0.tableExists("schedule") })

    try migrator.migrate(pool)
    try migrator.migrate(pool)
    #expect(try pool.read { try $0.tableExists("mission_template") })
    #expect(try pool.read { try $0.tableExists("schedule") })
}

@Test func scheduleCRUDAndClaimDedupe() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db)
    try db.saveMissionTemplate(fixture.template)
    var schedule = ScheduleRecord.new(
        templateId: fixture.template.id,
        frequency: .daily,
        hour: 9,
        minute: 0,
        weekday: nil,
        enabled: false
    )
    try db.saveSchedule(schedule)
    #expect(try db.schedules(campId: fixture.camp.id).map(\.id) == [schedule.id])

    schedule = try db.setScheduleEnabled(id: schedule.id, enabled: true)
    #expect(schedule.enabled)
    #expect(try db.enabledSchedules().map(\.schedule.id) == [schedule.id])

    let (calendar, timeZone) = scheduleCalendar("America/Los_Angeles")
    let fire = scheduleDate(2026, 7, 14, 9, 0, timeZoneID: "America/Los_Angeles")
    #expect(try db.claimScheduleFire(
        scheduleId: schedule.id,
        fireDate: fire,
        calendar: calendar,
        timeZone: timeZone
    ))
    #expect(try !db.claimScheduleFire(
        scheduleId: schedule.id,
        fireDate: fire.addingTimeInterval(60),
        calendar: calendar,
        timeZone: timeZone
    ))
}

@Test func guideBroadcastLandsInGuideThread() throws {
    let db = try scheduleTempDB()
    let camp = try db.ensureDefaultCamp()
    let messageId = try db.appendGuideBroadcast(campId: camp.id, text: "晨报来了")
    let thread = try db.findOrCreateGuideThread(campId: camp.id)
    let messages = try db.messages(threadId: thread.id)
    #expect(messages.map(\.id) == [messageId])
    #expect(messages.first?.role == "guide")
    #expect(messages.first?.text == "晨报来了")
}

@Test func scheduleFiredEventMarksScheduledOrigin() throws {
    let db = try scheduleTempDB()
    let fixture = try scheduleTemplateFixture(db: db)
    try db.saveMissionTemplate(fixture.template)
    let schedule = ScheduleRecord.new(
        templateId: fixture.template.id,
        frequency: .weekly,
        hour: 9,
        minute: 0,
        weekday: 3,
        enabled: true
    )
    try db.saveSchedule(schedule)
    let missionId = try db.createMissionShell(
        goal: fixture.template.goal,
        companionIds: [fixture.companion.id],
        workspacePath: nil,
        budgetTokens: 10_000,
        campId: fixture.camp.id,
        autonomy: .standard
    )
    let firedAt = scheduleDate(2026, 7, 14, 9, 0, timeZoneID: "America/Los_Angeles")
    try db.appendScheduleFiredEvent(
        scheduleId: schedule.id,
        templateId: fixture.template.id,
        missionId: missionId,
        firedAt: firedAt
    )

    let origin = try #require(try db.scheduledOrigin(missionId: missionId))
    #expect(origin.scheduleId == schedule.id)
    #expect(origin.templateId == fixture.template.id)
    let events = try db.events(missionId: missionId)
    #expect(events.contains { $0.kind == "schedule_fired" })
}
