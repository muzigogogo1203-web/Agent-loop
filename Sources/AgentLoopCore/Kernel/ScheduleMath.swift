import Foundation

public enum ScheduleFrequency: String, Codable, Sendable, CaseIterable, Equatable {
    case daily
    case weekly
}

package struct InvalidSchedulePlanningFireTimeError:
    Error, Sendable, Equatable
{}

package struct UnsupportedScheduleCalendarError:
    Error, Sendable, Equatable
{}

package struct InvalidScheduleTimeZoneError:
    Error, Sendable, Equatable
{
    package let timeZoneId: String

    package init(timeZoneId: String) {
        self.timeZoneId = timeZoneId
    }
}

package struct ScheduleSlotComponentsUnavailableError:
    Error, Sendable, Equatable
{}

package struct ScheduleSlotComponentsV1: Sendable, Equatable {
    package let era: Int
    package let year: Int
    package let month: Int
    package let day: Int
    package let hour: Int
    package let minute: Int
    package let second: Int
    package let nanosecond: Int

    package init(validating components: DateComponents) throws {
        guard let era = components.era,
              let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute,
              let second = components.second,
              let nanosecond = components.nanosecond
        else {
            throw ScheduleSlotComponentsUnavailableError()
        }
        self.era = era
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.nanosecond = nanosecond
    }
}

package struct ScheduleSlotContextV1: Sendable, Equatable {
    package let contractVersion: Int
    package let calendarId: String
    package let timeZoneId: String
    package let frequency: ScheduleFrequency
    package let hour: Int
    package let minute: Int
    package let weekday: Int?
    package let scheduledAt: Date
    package let scheduledAtInstantBits: String
    package let slotKey: String

    package init(
        calendarId: String,
        timeZoneId: String,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int?,
        scheduledAt: Date,
        scheduledAtInstantBits: String,
        slotKey: String
    ) {
        self.contractVersion = 1
        self.calendarId = calendarId
        self.timeZoneId = timeZoneId
        self.frequency = frequency
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.scheduledAt = scheduledAt
        self.scheduledAtInstantBits = scheduledAtInstantBits
        self.slotKey = slotKey
    }
}

public enum ScheduleMath {
    private static let minimumScheduleSeconds = -62_135_596_800.0
    private static let maximumScheduleSeconds = 253_402_300_800.0
    private static let calendarToken = "gregorian"
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    public static func nextFireDate(
        after date: Date,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        guard validate(
            hour: hour,
            minute: minute,
            frequency: frequency,
            weekday: weekday
        ), let calculationCalendar = calculationCalendar(
            calendar: calendar,
            timeZone: timeZone
        ) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = calculationCalendar
        components.timeZone = calculationCalendar.timeZone
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        if frequency == .weekly {
            components.weekday = weekday
        }
        return calculationCalendar.nextDate(
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
        guard validate(
            hour: hour,
            minute: minute,
            frequency: frequency,
            weekday: weekday
        ), let calculationCalendar = calculationCalendar(
            calendar: calendar,
            timeZone: timeZone
        ) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = calculationCalendar
        components.timeZone = calculationCalendar.timeZone
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        if frequency == .weekly {
            components.weekday = weekday
        }
        let referenceSeconds = date.timeIntervalSinceReferenceDate
        guard referenceSeconds.isFinite else { return nil }
        let inclusiveReferenceSeconds = referenceSeconds.nextUp
        guard inclusiveReferenceSeconds.isFinite else { return nil }
        let inclusiveAnchor = Date(
            timeIntervalSinceReferenceDate: inclusiveReferenceSeconds
        )
        return calculationCalendar.nextDate(
            after: inclusiveAnchor,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .backward
        )
    }

    package static func slotContext(
        for scheduledAt: Date,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        calendar: Calendar,
        timeZone: TimeZone
    ) throws -> ScheduleSlotContextV1 {
        let rawSeconds = scheduledAt.timeIntervalSince1970
        guard rawSeconds.isFinite else {
            throw InvalidSchedulePlanningFireTimeError()
        }
        let normalizedSeconds = rawSeconds == 0 ? 0.0 : rawSeconds
        guard normalizedSeconds >= minimumScheduleSeconds,
              normalizedSeconds < maximumScheduleSeconds
        else {
            throw ScheduleSlotComponentsUnavailableError()
        }
        let normalizedDate = Date(timeIntervalSince1970: normalizedSeconds)
        guard normalizedDate.timeIntervalSince1970.bitPattern
                == normalizedSeconds.bitPattern
        else {
            throw ScheduleSlotComponentsUnavailableError()
        }
        guard calendar.identifier == .gregorian else {
            throw UnsupportedScheduleCalendarError()
        }
        let timeZoneId = timeZone.identifier
        guard !timeZoneId.isEmpty,
              let reconstructedTimeZone = TimeZone(identifier: timeZoneId),
              reconstructedTimeZone.identifier == timeZoneId
        else {
            throw InvalidScheduleTimeZoneError(timeZoneId: timeZoneId)
        }

        var canonicalCalendar = Calendar(identifier: .gregorian)
        canonicalCalendar.locale = posixLocale
        canonicalCalendar.timeZone = reconstructedTimeZone
        let components = try ScheduleSlotComponentsV1(
            validating: canonicalCalendar.dateComponents(
                [
                    .era, .year, .month, .day, .hour, .minute,
                    .second, .nanosecond,
                ],
                from: normalizedDate
            )
        )
        let offsetSeconds = reconstructedTimeZone.secondsFromGMT(
            for: normalizedDate
        )
        let instantBits = fixedWidthHex(normalizedSeconds.bitPattern)
        let configuredWeekday = frequency == .daily ? 0 : (weekday ?? 0)
        let slotKey = "schedule-slot:v1"
            + "|f=\(frequency.rawValue)"
            + "|c=\(calendarToken.utf8.count):\(calendarToken)"
            + "|z=\(timeZoneId.utf8.count):\(timeZoneId)"
            + "|p=\(twoDigits(hour)):\(twoDigits(minute)):\(configuredWeekday)"
            + "|r=\(components.era):\(components.year):"
            + "\(components.month):\(components.day):"
            + "\(twoDigits(components.hour)):"
            + "\(twoDigits(components.minute)):"
            + "\(twoDigits(components.second)):"
            + "\(nineDigits(components.nanosecond))"
            + "|o=\(offsetSeconds)"
            + "|i=\(instantBits)"
        return ScheduleSlotContextV1(
            calendarId: calendarToken,
            timeZoneId: timeZoneId,
            frequency: frequency,
            hour: hour,
            minute: minute,
            weekday: weekday,
            scheduledAt: normalizedDate,
            scheduledAtInstantBits: instantBits,
            slotKey: slotKey
        )
    }

    package static func latestUnevaluatedSlot(
        now: Date,
        createdAt: Date,
        cursor: ScheduleEvaluationCursorRecord?,
        frequency: ScheduleFrequency,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        calendar: Calendar,
        timeZone: TimeZone
    ) throws -> ScheduleSlotContextV1? {
        guard let scheduledAt = previousFireDate(
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
        let context = try slotContext(
            for: scheduledAt,
            frequency: frequency,
            hour: hour,
            minute: minute,
            weekday: weekday,
            calendar: calendar,
            timeZone: timeZone
        )
        guard let cursor else {
            return context.scheduledAt > createdAt ? context : nil
        }
        let candidateSeconds = context.scheduledAt.timeIntervalSince1970
        let cursorSeconds = cursor.lastEvaluatedScheduledAt
            .timeIntervalSince1970
        if candidateSeconds < cursorSeconds {
            return nil
        }
        if candidateSeconds > cursorSeconds {
            return context
        }
        return rawUTF8Precedes(
            cursor.lastEvaluatedSlotKey,
            context.slotKey
        ) ? context : nil
    }

    private static func calculationCalendar(
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Calendar? {
        guard calendar.identifier == .gregorian else { return nil }
        let identifier = timeZone.identifier
        guard !identifier.isEmpty,
              let reconstructed = TimeZone(identifier: identifier),
              reconstructed.identifier == identifier
        else {
            return nil
        }
        var result = Calendar(identifier: .gregorian)
        result.locale = posixLocale
        result.timeZone = reconstructed
        return result
    }

    private static func rawUTF8Precedes(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }

    private static func fixedWidthHex(_ value: UInt64) -> String {
        let digits = String(value, radix: 16, uppercase: false)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }

    private static func twoDigits(_ value: Int) -> String {
        if (0...9).contains(value) {
            return "0\(value)"
        }
        return String(value)
    }

    private static func nineDigits(_ value: Int) -> String {
        let digits = String(value)
        guard value >= 0, digits.count < 9 else { return digits }
        return String(repeating: "0", count: 9 - digits.count) + digits
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
