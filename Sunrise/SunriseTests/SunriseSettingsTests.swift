import Foundation
import Testing
@testable import Sunrise

struct SunriseSettingsTests {
    @Test func roundTripsThroughJSON() throws {
        var settings = SunriseSettings()
        settings.mode = .sunrise
        settings.durationMinutes = 45
        settings.days = [.saturday, .sunday]
        settings.lightIDs = [UUID(), UUID()]
        settings.homeID = UUID()
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SunriseSettings.self, from: data)
        #expect(decoded == settings)
    }

    @Test func missingFieldsGetDefaults() throws {
        let old = Data(#"{"wakeHour": 6, "wakeMinute": 15}"#.utf8)
        let settings = try JSONDecoder().decode(SunriseSettings.self, from: old)
        #expect(settings.wakeHour == 6)
        #expect(settings.wakeMinute == 15)
        #expect(settings.durationMinutes == 30)
        #expect(settings.finalBrightness == 75)
        #expect(settings.days == Weekday.everyDay)
        #expect(settings.mode == .fixedTime)
    }

    @Test func homeShapeIgnoresWhatHomeDoesntUse() {
        var a = SunriseSettings()
        a.mode = .sunrise
        var b = a
        b.wakeHour = 5
        #expect(a.homeShape == b.homeShape, "the wake time doesn't matter at sunrise")

        var c = SunriseSettings()
        c.usesColor = false
        var d = c
        d.finalKelvin = 6500
        #expect(c.homeShape == d.homeShape, "the end color doesn't matter for brightness only")

        var e = SunriseSettings()
        e.finalBrightness = 50
        #expect(e.homeShape != SunriseSettings().homeShape)
    }

    @Test func savedPlaceRoundsToAboutAKilometer() {
        let place = SavedPlace(latitude: 39.739236, longitude: -104.990251)
        #expect(place.latitude == 39.74)
        #expect(place.longitude == -104.99)
    }

    @Test func stepNamesAreRecognised() {
        #expect(HomeSchedule.isSunriseName("Sunrise App Step 07"))
        #expect(HomeSchedule.isSunriseName("Sunrise App Step 16"))
        #expect(!HomeSchedule.isSunriseName("Sunrise App Step "))
        #expect(!HomeSchedule.isSunriseName("Sunrise App Step 7a"))
        #expect(!HomeSchedule.isSunriseName("Good Morning"))
    }
}

struct WeekdayTests {
    @Test func addingWrapsAroundTheWeek() {
        #expect(Weekday.sunday.adding(days: -1) == .saturday)
        #expect(Weekday.saturday.adding(days: 1) == .sunday)
        #expect(Weekday.monday.adding(days: 14) == .monday)
    }

    @Test func weekStartsWhereTheCalendarSays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        #expect(Weekday.ordered(for: calendar).first == .monday)
        calendar.firstWeekday = 1
        #expect(Weekday.ordered(for: calendar) == Weekday.allCases)
    }

    @Test func summaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        #expect(Weekday.everyDay.summary(in: calendar) == "Every day")
        #expect(Weekday.workdays.summary(in: calendar) == "Weekdays")
        #expect(Weekday.weekend.summary(in: calendar) == "Weekends")
        #expect(Set<Weekday>([.monday, .wednesday, .friday]).summary(in: calendar) == "Mon, Wed, Fri")
    }
}
