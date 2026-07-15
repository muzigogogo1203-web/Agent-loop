import Foundation

public enum ScheduleFrequency: String, Codable, Sendable, CaseIterable, Equatable {
    case daily
    case weekly
}

public enum ScheduleMath {
    public static func nextFireDate(
        after date: Date,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        guard validate(hour: hour, minute: minute, frequency: frequency, weekday: weekday) else {
            return nil
        }
        var cal = calendar
        cal.timeZone = timeZone
        var components = DateComponents()
        components.calendar = cal
        components.timeZone = timeZone
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        if frequency == .weekly {
            components.weekday = weekday
        }
        return cal.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    public static func previousFireDate(
        onOrBefore date: Date,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        guard validate(hour: hour, minute: minute, frequency: frequency, weekday: weekday) else {
            return nil
        }
        var cal = calendar
        cal.timeZone = timeZone
        var components = DateComponents()
        components.calendar = cal
        components.timeZone = timeZone
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        if frequency == .weekly {
            components.weekday = weekday
        }
        let inclusiveAnchor = date.addingTimeInterval(1)
        return cal.nextDate(
            after: inclusiveAnchor,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .backward
        )
    }

    public static func missedFireDate(
        now: Date,
        createdAt: Date,
        lastFiredAt: Date?,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        guard let previous = previousFireDate(
            onOrBefore: now,
            frequency: frequency,
            hour: hour,
            minute: minute,
            weekday: weekday,
            calendar: calendar,
            timeZone: timeZone
        ) else {
            return nil
        }
        let baseline = lastFiredAt ?? createdAt
        guard baseline < previous else { return nil }
        return previous
    }

    public static func alreadyFiredSameSlot(
        lastFiredAt: Date?,
        fireDate: Date,
        frequency: ScheduleFrequency,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Bool {
        guard let lastFiredAt else { return false }
        return slotKey(
            for: lastFiredAt,
            frequency: frequency,
            calendar: calendar,
            timeZone: timeZone
        ) == slotKey(
            for: fireDate,
            frequency: frequency,
            calendar: calendar,
            timeZone: timeZone
        )
    }

    public static func slotKey(
        for date: Date,
        frequency: ScheduleFrequency,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> String {
        var cal = calendar
        cal.timeZone = timeZone
        switch frequency {
        case .daily:
            let components = cal.dateComponents([.era, .year, .month, .day], from: date)
            return "\(components.era ?? 0)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        case .weekly:
            let components = cal.dateComponents([.era, .yearForWeekOfYear, .weekOfYear, .weekday], from: date)
            return "\(components.era ?? 0)-\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)-\(components.weekday ?? 0)"
        }
    }

    private static func validate(
        hour: Int,
        minute: Int,
        frequency: ScheduleFrequency,
        weekday: Int?
    ) -> Bool {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return false
        }
        switch frequency {
        case .daily:
            return weekday == nil
        case .weekly:
            guard let weekday else { return false }
            return (1...7).contains(weekday)
        }
    }
}
