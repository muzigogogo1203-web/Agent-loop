import Foundation
import GRDB

public struct MissionTemplateRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "mission_template"

    public var id: String
    public var name: String
    public var goal: String
    public var companionIdsJson: String
    public var workspacePath: String?
    public var budgetTokens: Int?
    public var autonomy: MissionAutonomy
    public var campId: String
    public var createdAt: Date

    public init(
        id: String,
        name: String,
        goal: String,
        companionIdsJson: String,
        workspacePath: String?,
        budgetTokens: Int?,
        autonomy: MissionAutonomy,
        campId: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.companionIdsJson = companionIdsJson
        self.workspacePath = workspacePath
        self.budgetTokens = budgetTokens
        self.autonomy = autonomy
        self.campId = campId
        self.createdAt = createdAt
    }

    public static func new(
        name: String,
        goal: String,
        companionIds: [String],
        workspacePath: String?,
        budgetTokens: Int?,
        autonomy: MissionAutonomy,
        campId: String
    ) throws -> MissionTemplateRecord {
        .init(
            id: UUID().uuidString,
            name: name,
            goal: goal,
            companionIdsJson: try companionIdsJSON(companionIds),
            workspacePath: workspacePath,
            budgetTokens: budgetTokens,
            autonomy: autonomy,
            campId: campId,
            createdAt: Date()
        )
    }

    public func companionIds() throws -> [String] {
        try JSONDecoder().decode([String].self, from: Data(companionIdsJson.utf8))
    }

    public static func companionIdsJSON(_ companionIds: [String]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let json = String(data: try encoder.encode(companionIds), encoding: .utf8) else {
            throw EncodingError.invalidValue(
                companionIds,
                .init(codingPath: [], debugDescription: "UTF-8 encoding failed")
            )
        }
        return json
    }
}

public struct ScheduleRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "schedule"

    public var id: String
    public var templateId: String
    public var frequency: ScheduleFrequency
    public var hour: Int
    public var minute: Int
    public var weekday: Int?
    public var enabled: Bool
    public var lastFiredAt: Date?
    public var createdAt: Date

    public init(
        id: String,
        templateId: String,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int?,
        enabled: Bool,
        lastFiredAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.templateId = templateId
        self.frequency = frequency
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.enabled = enabled
        self.lastFiredAt = lastFiredAt
        self.createdAt = createdAt
    }

    public static func new(
        templateId: String,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int?,
        enabled: Bool = false
    ) -> ScheduleRecord {
        .init(
            id: UUID().uuidString,
            templateId: templateId,
            frequency: frequency,
            hour: hour,
            minute: minute,
            weekday: weekday,
            enabled: enabled,
            lastFiredAt: nil,
            createdAt: Date()
        )
    }
}

public struct EnabledScheduleRecord: Sendable, Equatable {
    public let schedule: ScheduleRecord
    public let template: MissionTemplateRecord

    public init(schedule: ScheduleRecord, template: MissionTemplateRecord) {
        self.schedule = schedule
        self.template = template
    }
}

public enum MissionTemplateValidationError: Error, Equatable, Sendable, LocalizedError {
    case emptyName
    case emptyGoal
    case invalidCompanionIds
    case missingBudgetTokens
    case invalidBudgetTokens(Int)
    case freeAutonomyNotAllowed

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "定时行动模板缺少名称"
        case .emptyGoal:
            return "定时行动模板缺少行动目标"
        case .invalidCompanionIds:
            return "定时行动模板缺少可用伙伴"
        case .missingBudgetTokens:
            return "定时行动模板必须显式设置预算"
        case .invalidBudgetTokens(let value):
            return "定时行动模板预算必须是正整数，当前为 \(value)"
        case .freeAutonomyNotAllowed:
            return "定时行动不能使用放手档"
        }
    }
}

public enum ScheduleValidationError: Error, Equatable, Sendable, LocalizedError {
    case invalidTime(hour: Int, minute: Int)
    case missingWeekday
    case unexpectedWeekday(Int)
    case invalidWeekday(Int)
    case missingTemplate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTime(let hour, let minute):
            return "日程时间无效：\(hour):\(minute)"
        case .missingWeekday:
            return "每周日程必须指定 weekday"
        case .unexpectedWeekday(let weekday):
            return "每日日程不能指定 weekday，当前为 \(weekday)"
        case .invalidWeekday(let weekday):
            return "weekday 必须在 1...7，当前为 \(weekday)"
        case .missingTemplate(let id):
            return "日程引用的模板不存在：\(id)"
        }
    }
}

extension MissionTemplateRecord {
    public func validateForScheduledMission() throws -> Int {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw MissionTemplateValidationError.emptyName }
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else { throw MissionTemplateValidationError.emptyGoal }
        let companionIds = try companionIds()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !companionIds.isEmpty else { throw MissionTemplateValidationError.invalidCompanionIds }
        guard let budgetTokens else { throw MissionTemplateValidationError.missingBudgetTokens }
        guard budgetTokens > 0 else { throw MissionTemplateValidationError.invalidBudgetTokens(budgetTokens) }
        guard autonomy != .free else { throw MissionTemplateValidationError.freeAutonomyNotAllowed }
        return budgetTokens
    }
}

extension ScheduleRecord {
    public func validate() throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ScheduleValidationError.invalidTime(hour: hour, minute: minute)
        }
        switch frequency {
        case .daily:
            if let weekday {
                throw ScheduleValidationError.unexpectedWeekday(weekday)
            }
        case .weekly:
            guard let weekday else { throw ScheduleValidationError.missingWeekday }
            guard (1...7).contains(weekday) else {
                throw ScheduleValidationError.invalidWeekday(weekday)
            }
        }
    }
}

extension AppDatabase {
    // MARK: - Mission templates

    public func missionTemplate(id: String) throws -> MissionTemplateRecord? {
        try pool.read { db in try MissionTemplateRecord.fetchOne(db, key: id) }
    }

    public func missionTemplates(campId: String) throws -> [MissionTemplateRecord] {
        try pool.read { db in
            try MissionTemplateRecord
                .filter(Column("campId") == campId)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    public func saveMissionTemplate(_ template: MissionTemplateRecord) throws {
        _ = try template.validateForScheduledMission()
        try pool.write { db in
            guard try CampRecord.fetchOne(db, key: template.campId) != nil else {
                throw RecordNotFoundError(table: "camp", id: template.campId)
            }
            try template.save(db)
        }
    }

    public func deleteMissionTemplate(id: String) throws {
        try pool.write { db in
            try ScheduleRecord
                .filter(Column("templateId") == id)
                .deleteAll(db)
            _ = try MissionTemplateRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - Schedules

    public func schedule(id: String) throws -> ScheduleRecord? {
        try pool.read { db in try ScheduleRecord.fetchOne(db, key: id) }
    }

    public func schedules(campId: String) throws -> [ScheduleRecord] {
        try pool.read { db in
            try ScheduleRecord.fetchAll(
                db,
                sql: """
                    SELECT schedule.*
                    FROM schedule
                    JOIN mission_template ON mission_template.id = schedule.templateId
                    WHERE mission_template.campId = ?
                    ORDER BY schedule.createdAt, schedule.rowid
                    """,
                arguments: [campId]
            )
        }
    }

    public func enabledSchedules() throws -> [EnabledScheduleRecord] {
        try pool.read { db in
            let schedules = try ScheduleRecord
                .filter(Column("enabled") == true)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
            var result: [EnabledScheduleRecord] = []
            result.reserveCapacity(schedules.count)
            for schedule in schedules {
                guard let template = try MissionTemplateRecord.fetchOne(db, key: schedule.templateId) else {
                    throw ScheduleValidationError.missingTemplate(schedule.templateId)
                }
                result.append(EnabledScheduleRecord(schedule: schedule, template: template))
            }
            return result
        }
    }

    public func saveSchedule(_ schedule: ScheduleRecord) throws {
        try schedule.validate()
        try pool.write { db in
            guard try MissionTemplateRecord.fetchOne(db, key: schedule.templateId) != nil else {
                throw ScheduleValidationError.missingTemplate(schedule.templateId)
            }
            try schedule.save(db)
        }
    }

    @discardableResult
    public func setScheduleEnabled(id: String, enabled: Bool) throws -> ScheduleRecord {
        try pool.write { db in
            guard var schedule = try ScheduleRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "schedule", id: id)
            }
            guard try MissionTemplateRecord.fetchOne(db, key: schedule.templateId) != nil else {
                throw ScheduleValidationError.missingTemplate(schedule.templateId)
            }
            schedule.enabled = enabled
            try schedule.validate()
            try schedule.update(db)
            return schedule
        }
    }

    public func deleteSchedule(id: String) throws {
        try pool.write { db in
            _ = try ScheduleRecord.deleteOne(db, key: id)
        }
    }

    @discardableResult
    public func claimScheduleFire(
        scheduleId: String,
        fireDate: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) throws -> Bool {
        try pool.write { db in
            guard var schedule = try ScheduleRecord.fetchOne(db, key: scheduleId) else {
                throw RecordNotFoundError(table: "schedule", id: scheduleId)
            }
            guard schedule.enabled else { return false }
            try schedule.validate()
            if ScheduleMath.alreadyFiredSameSlot(
                lastFiredAt: schedule.lastFiredAt,
                fireDate: fireDate,
                frequency: schedule.frequency,
                calendar: calendar,
                timeZone: timeZone
            ) {
                return false
            }
            schedule.lastFiredAt = fireDate
            try schedule.update(db)
            return true
        }
    }

    public func appendScheduleFiredEvent(
        scheduleId: String,
        templateId: String,
        missionId: String,
        firedAt: Date
    ) throws {
        try pool.write { db in
            try Self.appendEvent(
                db,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.scheduleFired,
                payload: [
                    "scheduleId": .string(scheduleId),
                    "templateId": .string(templateId),
                    "firedAt": .number(firedAt.timeIntervalSince1970),
                ]
            )
        }
    }

    public func recordScheduleMissed(
        scheduleId: String,
        templateId: String?,
        missedFireDate: Date,
        reason: String
    ) throws {
        try pool.write { db in
            try Self.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.scheduleMissed,
                payload: [
                    "scheduleId": .string(scheduleId),
                    "templateId": templateId.map(JSONValue.string) ?? .null,
                    "missedFireDate": .number(missedFireDate.timeIntervalSince1970),
                    "reason": .string(reason),
                ]
            )
        }
    }

    public func scheduledOrigin(missionId: String) throws -> (scheduleId: String, templateId: String)? {
        try pool.read { db in
            guard let event = try EventRecord
                .filter(Column("missionId") == missionId && Column("kind") == EventKind.scheduleFired)
                .order(Column("createdAt").desc, Column.rowID.desc)
                .fetchOne(db),
                  let payload = try? JSONValue.decoded(from: event.payloadJson),
                  let scheduleId = payload["scheduleId"]?.stringValue,
                  let templateId = payload["templateId"]?.stringValue else {
                return nil
            }
            return (scheduleId, templateId)
        }
    }

    public func scheduleMissedEvents() throws -> [EventRecord] {
        try pool.read { db in
            try EventRecord
                .filter(Column("kind") == EventKind.scheduleMissed)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }
}
