import Foundation

/// A day of the week, numbered like `Calendar` and HomeKit's recurrences (1 = Sunday).
enum Weekday: Int, CaseIterable, Codable, Comparable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    static let everyDay = Set(Weekday.allCases)
    static let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]

    var id: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The day `days` later (negative for earlier), wrapping around the week.
    func adding(days: Int) -> Weekday {
        let index = ((rawValue - 1 + days) % 7 + 7) % 7
        return Weekday(rawValue: index + 1) ?? .sunday
    }

    /// The week in the order the calendar shows it (Sunday first in the US, Monday first in much of Europe).
    static func ordered(for calendar: Calendar) -> [Weekday] {
        let first = Weekday(rawValue: calendar.firstWeekday) ?? .sunday
        return (0..<7).map { first.adding(days: $0) }
    }

    /// "Mon", "Tue", …
    func shortName(in calendar: Calendar) -> String {
        calendar.shortStandaloneWeekdaySymbols[rawValue - 1]
    }
}

extension Set where Element == Weekday {
    /// The same days moved by `days`, for steps that fall before midnight on the day before the wake time.
    func shifted(by days: Int) -> Set<Weekday> {
        Set(map { $0.adding(days: days) })
    }

    /// "Every day", "Weekdays", "Weekends", or the days in calendar order ("Mon, Wed, Fri").
    func summary(in calendar: Calendar) -> String {
        if self == Weekday.everyDay { return "Every day" }
        if self == Weekday.workdays { return "Weekdays" }
        if self == Weekday.weekend { return "Weekends" }
        if isEmpty { return "Never" }
        return Weekday.ordered(for: calendar)
            .filter { contains($0) }
            .map { $0.shortName(in: calendar) }
            .joined(separator: ", ")
    }
}
