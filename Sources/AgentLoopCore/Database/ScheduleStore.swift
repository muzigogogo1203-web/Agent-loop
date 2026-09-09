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

    public static func databaseDateEncodingStrategy(
        for column: String
    ) -> DatabaseDateEncodingStrategy {
        column == "lastFiredAt" ? .timeIntervalSince1970 : .deferredToDate
    }

    public static func databaseDateDecodingStrategy(
        for column: String
    ) -> DatabaseDateDecodingStrategy {
        .deferredToDate
    }

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

package enum ScheduleFireState: String, Codable, Sendable, Equatable {
    case started
    case failed
}

package enum ScheduleFireDisposition: Sendable, Equatable {
    case inserted
    case replayed
}

package struct ScheduleFireRecord:
    Codable, Sendable, Equatable, FetchableRecord
{
    package static let databaseTableName = "schedule_fire"

    package static func databaseDateDecodingStrategy(
        for column: String
    ) -> DatabaseDateDecodingStrategy {
        scheduleNumericDateDecodingStrategy()
    }

    package let id: String
    package let scheduleId: String
    package let templateId: String
    package let slotKey: String
    package let scheduledAt: Date
    package let replayOfFireId: String?
    package let replayIdempotencyKey: String?
    package let replayPayloadHash: String?
    package let state: ScheduleFireState
    package let missionId: String?
    package let traceId: String
    package let errorCode: String?
    package let errorMessage: String?
    package let createdAt: Date
    package let redactedAt: Date?

    package init(
        id: String,
        scheduleId: String,
        templateId: String,
        slotKey: String,
        scheduledAt: Date,
        replayOfFireId: String?,
        replayIdempotencyKey: String?,
        replayPayloadHash: String?,
        state: ScheduleFireState,
        missionId: String?,
        traceId: String,
        errorCode: String?,
        errorMessage: String?,
        createdAt: Date,
        redactedAt: Date?
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.templateId = templateId
        self.slotKey = slotKey
        self.scheduledAt = scheduledAt
        self.replayOfFireId = replayOfFireId
        self.replayIdempotencyKey = replayIdempotencyKey
        self.replayPayloadHash = replayPayloadHash
        self.state = state
        self.missionId = missionId
        self.traceId = traceId
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.redactedAt = redactedAt
    }
}

package struct ScheduleEvaluationCursorRecord:
    Codable, Sendable, Equatable, FetchableRecord
{
    package static let databaseTableName = "schedule_evaluation_cursor"

    package static func databaseDateDecodingStrategy(
        for column: String
    ) -> DatabaseDateDecodingStrategy {
        scheduleNumericDateDecodingStrategy()
    }

    package let scheduleId: String
    package let lastEvaluatedSlotKey: String
    package let lastEvaluatedScheduledAt: Date
    package let version: Int
    package let updatedAt: Date

    package init(
        scheduleId: String,
        lastEvaluatedSlotKey: String,
        lastEvaluatedScheduledAt: Date,
        version: Int,
        updatedAt: Date
    ) {
        self.scheduleId = scheduleId
        self.lastEvaluatedSlotKey = lastEvaluatedSlotKey
        self.lastEvaluatedScheduledAt = lastEvaluatedScheduledAt
        self.version = version
        self.updatedAt = updatedAt
    }
}

package struct ScheduleFireCommitResult: Sendable, Equatable {
    package let fire: ScheduleFireRecord
    package let disposition: ScheduleFireDisposition
    package let missionId: String?
    package let workId: String?

    package init(
        fire: ScheduleFireRecord,
        disposition: ScheduleFireDisposition,
        missionId: String?,
        workId: String?
    ) {
        self.fire = fire
        self.disposition = disposition
        self.missionId = missionId
        self.workId = workId
    }
}

private func scheduleNumericDateDecodingStrategy()
    -> DatabaseDateDecodingStrategy
{
    .custom { databaseValue in
        let seconds: Double
        switch databaseValue.storage {
        case .double(let value)
            where value.isFinite
                && value >= -62_135_596_800
                && value < 253_402_300_800:
            seconds = value
        case .int64(let integerSeconds):
            let value = Double(integerSeconds)
            guard Int64(exactly: value) == integerSeconds,
                  value >= -62_135_596_800,
                  value < 253_402_300_800
            else {
                return nil
            }
            seconds = value
        default:
            return nil
        }
        let date = Date(timeIntervalSince1970: seconds)
        guard date.timeIntervalSince1970.bitPattern == seconds.bitPattern else {
            return nil
        }
        return date
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
    case inactiveCompanion(String)
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
        case .inactiveCompanion(let id):
            return "定时行动模板引用了已移出牛群的伙伴：\(id)"
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

package enum ScheduleStoreProjectionError: Error, Sendable, Equatable {
    case invalidScheduledOrigin(eventId: String)
    case duplicateEvaluationCursor(scheduleId: String)
}

extension MissionTemplateRecord {
public func validateForScheduledMission() throws -> Int {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw MissionTemplateValidationError.emptyName }
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else { throw MissionTemplateValidationError.emptyGoal }
        let companionIds = try companionIds()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !companionIds.isEmpty,
              companionIds.allSatisfy({ !$0.isEmpty })
        else {
            throw MissionTemplateValidationError.invalidCompanionIds
        }
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
        try pool.read { database in
            try Self.missionTemplate(id: id, in: database)
        }
    }

    public func missionTemplates(campId: String) throws -> [MissionTemplateRecord] {
        try pool.read { database in
            try Self.missionTemplates(campId: campId, in: database)
        }
    }

    package static func missionTemplate(
        id: String,
        in database: Database
    ) throws -> MissionTemplateRecord? {
        try MissionTemplateRecord.fetchOne(database, key: id)
    }

    package static func missionTemplates(
        campId: String,
        in database: Database
    ) throws -> [MissionTemplateRecord] {
        try MissionTemplateRecord
            .filter(Column("campId") == campId)
            .order(Column("createdAt"), Column("id"))
            .fetchAll(database)
    }

    public func saveMissionTemplate(_ template: MissionTemplateRecord) throws {
        _ = try template.validateForScheduledMission()
        try pool.write { db in
            guard try CampRecord.fetchOne(db, key: template.campId) != nil else {
                throw RecordNotFoundError(table: "camp", id: template.campId)
            }
            try Self.requireActiveTemplateCompanions(
                template,
                database: db
            )
            try template.save(db)
        }
    }

    public func deleteMissionTemplate(id: String) throws {
        _ = try deleteMissionTemplateWithPreimage(id: id)
    }

    package func deleteMissionTemplateWithPreimage(
        id: String
    ) throws -> (
        template: MissionTemplateRecord,
        deletedSchedules: [ScheduleRecord]
    ) {
        try pool.write { database in
            guard let template = try Self.missionTemplate(
                id: id,
                in: database
            ) else {
                throw RecordNotFoundError(
                    table: MissionTemplateRecord.databaseTableName,
                    id: id
                )
            }
            let schedules = try ScheduleRecord
                .filter(Column("templateId") == id)
                .order(Column("createdAt"), Column("id"))
                .fetchAll(database)
            let deletedSchedules = try ScheduleRecord
                .filter(Column("templateId") == id)
                .deleteAll(database)
            guard deletedSchedules == schedules.count else {
                throw ProjectionContractError.invalidTerminal
            }
            guard try MissionTemplateRecord.deleteOne(
                database,
                key: id
            ) else {
                throw RecordNotFoundError(
                    table: MissionTemplateRecord.databaseTableName,
                    id: id
                )
            }
            return (template, schedules)
        }
    }

    // MARK: - Schedules

    public func schedule(id: String) throws -> ScheduleRecord? {
        try pool.read { db in try ScheduleRecord.fetchOne(db, key: id) }
    }

    public func schedules(campId: String) throws -> [ScheduleRecord] {
        try pool.read { database in
            try Self.schedules(campId: campId, in: database)
        }
    }

    package static func schedules(
        campId: String,
        in database: Database
    ) throws -> [ScheduleRecord] {
        try ScheduleRecord.fetchAll(
                database,
                sql: """
                    SELECT schedule.*
                    FROM schedule
                    JOIN mission_template ON mission_template.id = schedule.templateId
                    WHERE mission_template.campId = ?
                    ORDER BY schedule.createdAt, schedule.id
                    """,
                arguments: [campId]
            )
    }

    public func enabledSchedules() throws -> [EnabledScheduleRecord] {
        try pool.read { database in
            try Self.enabledSchedules(in: database)
        }
    }

    package static func enabledSchedules(
        in database: Database
    ) throws -> [EnabledScheduleRecord] {
        let schedules = try ScheduleRecord
            .filter(Column("enabled") == true)
            .order(Column("createdAt"), Column("id"))
            .fetchAll(database)
        var result: [EnabledScheduleRecord] = []
        result.reserveCapacity(schedules.count)
        for schedule in schedules {
            try schedule.validate()
            guard let template = try Self.missionTemplate(
                id: schedule.templateId,
                in: database
            ) else {
                throw ScheduleValidationError.missingTemplate(
                    schedule.templateId
                )
            }
            _ = try template.validateForScheduledMission()
            try Self.requireActiveTemplateCompanions(
                template,
                database: database
            )
            result.append(EnabledScheduleRecord(
                schedule: schedule,
                template: template
            ))
        }
        return result
    }

    public func saveSchedule(_ schedule: ScheduleRecord) throws {
        try schedule.validate()
        try pool.write { db in
            guard let template = try MissionTemplateRecord.fetchOne(
                db,
                key: schedule.templateId
            ) else {
                throw ScheduleValidationError.missingTemplate(schedule.templateId)
            }
            if schedule.enabled {
                try Self.requireActiveTemplateCompanions(
                    template,
                    database: db
                )
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
            guard let template = try MissionTemplateRecord.fetchOne(
                db,
                key: schedule.templateId
            ) else {
                throw ScheduleValidationError.missingTemplate(schedule.templateId)
            }
            if enabled {
                try Self.requireActiveTemplateCompanions(
                    template,
                    database: db
                )
            }
            schedule.enabled = enabled
            try schedule.validate()
            try schedule.update(db)
            return schedule
        }
    }

    private static func requireActiveTemplateCompanions(
        _ template: MissionTemplateRecord,
        database: Database
    ) throws {
        for companionId in try template.companionIds() {
            let normalizedId = companionId.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let status = try String.fetchOne(
                database,
                sql: "SELECT status FROM cow_identity WHERE id=?",
                arguments: [normalizedId]
            )
            guard status == CowIdentityStatusV1.active.rawValue else {
                throw MissionTemplateValidationError.inactiveCompanion(
                    normalizedId
                )
            }
        }
    }

    public func deleteSchedule(id: String) throws {
        _ = try deleteScheduleWithPreimage(id: id)
    }

    package func deleteScheduleWithPreimage(
        id: String
    ) throws -> ScheduleRecord {
        try pool.write { database in
            guard let schedule = try ScheduleRecord.fetchOne(
                database,
                key: id
            ) else {
                throw RecordNotFoundError(
                    table: ScheduleRecord.databaseTableName,
                    id: id
                )
            }
            guard try ScheduleRecord.deleteOne(database, key: id) else {
                throw RecordNotFoundError(
                    table: ScheduleRecord.databaseTableName,
                    id: id
                )
            }
            return schedule
        }
    }

    package func scheduleFire(id: String) throws -> ScheduleFireRecord? {
        try pool.read { database in
            try ScheduleFireRecord.fetchOne(
                database,
                sql: "SELECT * FROM schedule_fire WHERE id = ?",
                arguments: [id]
            )
        }
    }

    package func scheduleFires(
        scheduleId: String
    ) throws -> [ScheduleFireRecord] {
        try pool.read { database in
            try ScheduleFireRecord.fetchAll(
                database,
                sql: """
                    SELECT * FROM schedule_fire
                    WHERE scheduleId = ?
                    ORDER BY scheduledAt, createdAt, rowid
                    """,
                arguments: [scheduleId]
            )
        }
    }

    package func scheduleEvaluationCursor(
        scheduleId: String
    ) throws -> ScheduleEvaluationCursorRecord? {
        try pool.read { database in
            try Self.scheduleEvaluationCursor(
                scheduleId: scheduleId,
                in: database
            )
        }
    }

    package static func scheduleEvaluationCursor(
        scheduleId: String,
        in database: Database
    ) throws -> ScheduleEvaluationCursorRecord? {
        let rows = try ScheduleEvaluationCursorRecord.fetchAll(
            database,
            sql: """
                SELECT * FROM schedule_evaluation_cursor
                WHERE scheduleId = ?
                LIMIT 2
                """,
            arguments: [scheduleId]
        )
        guard rows.count <= 1 else {
            throw ScheduleStoreProjectionError
                .duplicateEvaluationCursor(scheduleId: scheduleId)
        }
        return rows.first
    }

    public func scheduledOrigin(missionId: String) throws -> (scheduleId: String, templateId: String)? {
        try pool.read { database in
            try Self.scheduledOrigin(
                missionId: missionId,
                in: database
            )
        }
    }

    package static func scheduledOrigin(
        missionId: String,
        in database: Database
    ) throws -> (scheduleId: String, templateId: String)? {
        guard let event = try EventRecord
            .filter(
                Column("missionId") == missionId
                    && Column("kind") == EventKind.scheduleFired
            )
            .order(Column("createdAt").desc, Column("id").desc)
            .fetchOne(database)
        else {
            return nil
        }
        let payload: JSONValue
        do {
            payload = try JSONValue.decoded(from: event.payloadJson)
        } catch {
            throw ScheduleStoreProjectionError.invalidScheduledOrigin(
                eventId: event.id
            )
        }
        guard let scheduleId = payload["scheduleId"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !scheduleId.isEmpty,
              let templateId = payload["templateId"]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !templateId.isEmpty
        else {
            throw ScheduleStoreProjectionError.invalidScheduledOrigin(
                eventId: event.id
            )
        }
        return (scheduleId, templateId)
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
