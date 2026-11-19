import Foundation
import SwiftUI

enum ScheduleFormat {
    /// macOS capitalizes Russian weekday abbreviations, which read lowercase mid-phrase.
    static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        let symbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        return Locale.current.language.languageCode == .russian ? symbol.lowercased() : symbol
    }

    static func weekdayDayMonth(_ date: Date, now: Date) -> String {
        weekday(date) + ", " + dayMonth(date, now: now)
    }

    static func dayMonth(_ date: Date, now: Date) -> String {
        trimmed(formatter(sameYear(date, now) ? "dMMM" : "dMMMy").string(from: date))
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func monthTitle(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return capitalized(formatter.string(from: month))
    }

    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { capitalized(symbols[(first + $0) % 7]) }
    }

    static func summary(of draft: ScheduleDraft, now: Date) -> Text {
        guard let date = draft.date else { return Text("No Date") }
        let day: Text = switch offset(of: date, from: now) {
        case 0: Text("Today") + Text(verbatim: ", " + dayMonth(date, now: now))
        case 1: Text("Tomorrow") + Text(verbatim: ", " + dayMonth(date, now: now))
        case -1: Text("Yesterday") + Text(verbatim: ", " + dayMonth(date, now: now))
        default: Text(verbatim: capitalized(weekdayDayMonth(date, now: now)))
        }
        return draft.hasTime ? day + Text(verbatim: ", " + time(date)) : day
    }

    static func offset(of date: Date, from now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private static func sameYear(_ date: Date, _ now: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
    }

    private static func trimmed(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: "")
    }

    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(_ template: String) -> DateFormatter {
        if let formatter = formatters[template] {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[template] = formatter
        return formatter
    }
}

enum TaskScheduleLabel {
    /// In Today the day goes without saying, and a time today says enough on its own.
    static func text(date: Date?, hasTime: Bool, isDone: Bool, inToday: Bool, now: Date = .now) -> Text? {
        guard let date else { return nil }
        let offset = ScheduleFormat.offset(of: date, from: now)
        let day: Text? = switch offset {
        case 0: inToday || hasTime ? nil : Text("Today")
        case 1: Text("Tomorrow")
        case -1: Text("Yesterday")
        case 2...6: Text(verbatim: ScheduleFormat.capitalized(ScheduleFormat.weekday(date)))
        default: Text(verbatim: ScheduleFormat.dayMonth(date, now: now))
        }
        let time = hasTime ? Text(verbatim: ScheduleFormat.time(date)) : nil
        switch (day, time) {
        case let (day?, time?): return day + Text(verbatim: ", ") + time
        case let (day?, nil): return day
        case let (nil, time?): return time
        case (nil, nil): return nil
        }
    }
}
