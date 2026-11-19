import Foundation

struct ScheduleDraft: Equatable {
    var date: Date?
    var hasTime = false
}

enum ScheduleDates {
    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func adding(days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func adding(months: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: months, to: startOfMonth(date, calendar: calendar)) ?? date
    }

    static func weekend(after day: Date, calendar: Calendar = .current) -> Date {
        next(weekday: 7, after: day, calendar: calendar)
    }

    static func nextWeek(after day: Date, calendar: Calendar = .current) -> Date {
        next(weekday: 2, after: day, calendar: calendar)
    }

    /// Six full weeks, so the grid never changes height between months.
    static func grid(for month: Date, calendar: Calendar = .current) -> [Date] {
        let first = startOfMonth(month, calendar: calendar)
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let start = adding(days: -lead, to: first, calendar: calendar)
        return (0..<42).map { adding(days: $0, to: start, calendar: calendar) }
    }

    static func day(_ day: Date, keepingTimeOf draft: ScheduleDraft, calendar: Calendar = .current) -> Date {
        guard draft.hasTime, let time = draft.date else { return calendar.startOfDay(for: day) }
        return self.day(day, at: time, calendar: calendar)
    }

    static func day(_ day: Date, at time: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }

    static func suggestedTime(on day: Date, now: Date = .now, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        if calendar.isDate(day, inSameDayAs: now),
           let next = calendar.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime),
           calendar.isDate(next, inSameDayAs: start) {
            return next
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: start) ?? start
    }

    private static func next(weekday: Int, after day: Date, calendar: Calendar) -> Date {
        calendar.nextDate(
            after: calendar.startOfDay(for: day),
            matching: DateComponents(hour: 0, minute: 0, weekday: weekday),
            matchingPolicy: .nextTime
        ) ?? day
    }
}
