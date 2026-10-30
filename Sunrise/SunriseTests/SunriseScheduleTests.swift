import Foundation
import Testing
@testable import Sunrise

struct SunriseScheduleTests {
    private func denver() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Denver"))
        return calendar
    }

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    @Test func clockTimesBeforeTheWakeTime() {
        #expect(SunriseSchedule.clockTime(hour: 7, minute: 0, offsetMinutes: -30) == ClockTime(hour: 6, minute: 30, dayShift: 0))
        #expect(SunriseSchedule.clockTime(hour: 6, minute: 15, offsetMinutes: -31) == ClockTime(hour: 5, minute: 44, dayShift: 0))
        #expect(SunriseSchedule.clockTime(hour: 0, minute: 30, offsetMinutes: -30) == ClockTime(hour: 0, minute: 0, dayShift: 0))
    }

    @Test func stepsBeforeMidnightFallOnTheDayBefore() {
        #expect(SunriseSchedule.clockTime(hour: 0, minute: 10, offsetMinutes: -31) == ClockTime(hour: 23, minute: 39, dayShift: -1))
        // Monday and Wednesday wake-ups need Sunday and Tuesday steps.
        let recurrences = SunriseSchedule.recurrences(days: [.monday, .wednesday], dayShift: -1)
        #expect(recurrences.map(\.weekday) == [1, 3])
    }

    @Test func recurrencesAreWeekdaysInOrder() {
        let recurrences = SunriseSchedule.recurrences(days: Weekday.workdays, dayShift: 0)
        #expect(recurrences.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(recurrences.allSatisfy { $0.hour == nil && $0.minute == nil })
    }

    @Test func sunriseOffsetsSplitIntoHoursAndMinutes() {
        #expect(SunriseSchedule.sunriseOffset(minutes: 0) == nil)
        #expect(SunriseSchedule.sunriseOffset(minutes: -45) == DateComponents(minute: -45))
        #expect(SunriseSchedule.sunriseOffset(minutes: -60) == DateComponents(hour: -1, minute: 0))
        #expect(SunriseSchedule.sunriseOffset(minutes: -61) == DateComponents(hour: -1, minute: -1))
    }

    @Test func nextWakeSkipsDaysThatAreOff() throws {
        let calendar = try denver()
        var settings = SunriseSettings()
        settings.days = Weekday.workdays
        // Wednesday 8:00 → Thursday 7:00.
        let wednesday = try date(calendar, 2026, 10, 28, 8, 0)
        let thursdayWake = try date(calendar, 2026, 10, 29, 7, 0)
        #expect(SunriseSchedule.nextWake(after: wednesday, settings: settings, place: nil, calendar: calendar) == thursdayWake)
        // Friday 8:00 → Monday 7:00, after the clocks go back on Sunday.
        let friday = try date(calendar, 2026, 10, 30, 8, 0)
        let mondayWake = try date(calendar, 2026, 11, 2, 7, 0)
        #expect(SunriseSchedule.nextWake(after: friday, settings: settings, place: nil, calendar: calendar) == mondayWake)
    }

    @Test func nextWakeIsTodayBeforeTheWakeTime() throws {
        let calendar = try denver()
        let earlyFriday = try date(calendar, 2026, 10, 30, 6, 45)
        let fridayWake = try date(calendar, 2026, 10, 30, 7, 0)
        #expect(SunriseSchedule.nextWake(after: earlyFriday, settings: SunriseSettings(), place: nil, calendar: calendar) == fridayWake)
    }

    @Test func nextWakeAtSunriseNeedsAPlace() throws {
        let calendar = try denver()
        var settings = SunriseSettings()
        settings.mode = .sunrise
        let early = try date(calendar, 2026, 10, 30, 5, 0)
        #expect(SunriseSchedule.nextWake(after: early, settings: settings, place: nil, calendar: calendar) == nil)

        let place = SavedPlace(latitude: 39.7392, longitude: -104.9903)
        let wake = try #require(SunriseSchedule.nextWake(after: early, settings: settings, place: place, calendar: calendar))
        let expected = try date(calendar, 2026, 10, 30, 7, 26)
        #expect(abs(wake.timeIntervalSince(expected)) < 120)
    }

    @Test func lightsStartTheSunriseLengthBeforeTheWakeTime() throws {
        let calendar = try denver()
        let wake = try date(calendar, 2026, 10, 30, 7, 0)
        let start = try date(calendar, 2026, 10, 30, 6, 30)
        #expect(SunriseSchedule.start(forWake: wake, durationMinutes: 30) == start)
    }
}
