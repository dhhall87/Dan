import Foundation
import Testing
@testable import Sunrise

struct SolarCalculatorTests {
    /// Expected times are from the astral library (Python), which uses slightly different
    /// equations, so the two agree to within about a minute; two minutes leaves room.
    private func expectSunrise(
        _ year: Int, _ month: Int, _ day: Int,
        latitude: Double, longitude: Double, timeZone: String,
        at hour: Int, _ minute: Int, _ second: Int
    ) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZone))
        let expected = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)))
        let sunrise = try #require(SolarCalculator.sunrise(year: year, month: month, day: day, latitude: latitude, longitude: longitude))
        #expect(abs(sunrise.timeIntervalSince(expected)) < 120, "\(timeZone) \(year)-\(month)-\(day): got \(sunrise), expected \(expected)")
        #expect(calendar.isDate(sunrise, inSameDayAs: expected), "sunrise lands on the asked-for local day")
    }

    @Test func denverThroughTheYear() throws {
        try expectSunrise(2026, 1, 15, latitude: 39.7392, longitude: -104.9903, timeZone: "America/Denver", at: 7, 19, 25)
        try expectSunrise(2026, 6, 21, latitude: 39.7392, longitude: -104.9903, timeZone: "America/Denver", at: 5, 32, 27)
        try expectSunrise(2026, 10, 30, latitude: 39.7392, longitude: -104.9903, timeZone: "America/Denver", at: 7, 26, 43)
    }

    @Test func londonInSpringAndWinter() throws {
        try expectSunrise(2026, 3, 20, latitude: 51.5074, longitude: -0.1278, timeZone: "Europe/London", at: 6, 3, 39)
        try expectSunrise(2026, 12, 21, latitude: 51.5074, longitude: -0.1278, timeZone: "Europe/London", at: 8, 4, 6)
    }

    @Test func farFromGreenwichStaysOnTheLocalDay() throws {
        // Sunrise in Sydney and Auckland falls on the previous day in UTC.
        try expectSunrise(2026, 6, 21, latitude: -33.8688, longitude: 151.2093, timeZone: "Australia/Sydney", at: 7, 0, 11)
        try expectSunrise(2026, 12, 21, latitude: -36.8485, longitude: 174.7633, timeZone: "Pacific/Auckland", at: 5, 58, 15)
        try expectSunrise(2026, 1, 15, latitude: 21.3069, longitude: -157.8583, timeZone: "Pacific/Honolulu", at: 7, 11, 44)
    }

    @Test func noSunriseInPolarNightOrMidnightSun() {
        #expect(SolarCalculator.sunrise(year: 2026, month: 12, day: 21, latitude: 69.6492, longitude: 18.9553) == nil)
        #expect(SolarCalculator.sunrise(year: 2026, month: 6, day: 21, latitude: 69.6492, longitude: 18.9553) == nil)
    }

    @Test func julianDayMatchesKnownEpochs() {
        #expect(SolarCalculator.julianDay(year: 2000, month: 1, day: 1) == 2_451_544.5)
        #expect(SolarCalculator.julianDay(year: 1970, month: 1, day: 1) == 2_440_587.5)
    }

    @Test func sunriseOnADateUsesThatDaysLocalDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Australia/Sydney"))
        let lateEvening = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 23, minute: 30)))
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 7, minute: 0, second: 11)))
        let sunrise = try #require(SolarCalculator.sunrise(on: lateEvening, latitude: -33.8688, longitude: 151.2093, calendar: calendar))
        #expect(abs(sunrise.timeIntervalSince(expected)) < 120)
    }
}
