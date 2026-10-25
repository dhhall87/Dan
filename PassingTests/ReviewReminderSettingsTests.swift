import Foundation
import Testing
@testable import Passing

struct ReviewReminderSettingsTests {
    let work = SavedPlace(name: "Work", latitude: 37.97, longitude: -100.87)

    @Test func offByDefault() {
        #expect(ReviewReminderSettings().planned.isEmpty)
    }

    @Test func turnedOnItRemindsAtEightTheNextMorning() {
        var settings = ReviewReminderSettings()
        settings.isOn = true
        #expect(settings.planned == [.init(id: ReviewReminderSettings.timeID, trigger: .time(hour: 8, minute: 0))])
    }

    @Test func workRemindsOnlyOnceItsPlaceIsSet() {
        var settings = ReviewReminderSettings()
        settings.isOn = true
        settings.atTime = false
        #expect(settings.planned.isEmpty, "Work is on by default but has no place yet")
        settings.work = work
        #expect(settings.planned == [.init(id: ReviewReminderSettings.workID, trigger: .arrival(work))])
    }

    @Test func savesAndLoads() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReviewReminderSettingsTests"))
        defaults.removeObject(forKey: ReviewReminderSettings.key)
        #expect(ReviewReminderSettings.load(from: defaults) == ReviewReminderSettings())

        var settings = ReviewReminderSettings()
        settings.isOn = true
        settings.hour = 7
        settings.minute = 30
        settings.work = work
        settings.save(to: defaults)
        #expect(ReviewReminderSettings.load(from: defaults) == settings)
        defaults.removeObject(forKey: ReviewReminderSettings.key)
    }

    @Test func messageCountsPins() {
        #expect(ReviewReminderSettings.message(waiting: 1).hasPrefix("1 pin to review"))
        #expect(ReviewReminderSettings.message(waiting: 3).hasPrefix("3 pins to review"))
    }
}
