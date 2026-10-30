import Foundation
import Testing
@testable import Sunrise

struct SunriseCurveTests {
    @Test(arguments: SunriseCurve.durations)
    func stepsRunFromTheStartToTheWakeTime(minutes: Int) {
        let offsets = SunriseCurve.offsets(durationMinutes: minutes)
        #expect(offsets.first == -minutes)
        #expect(offsets.last == 0)
        #expect(offsets.count == min(minutes, SunriseCurve.maxIntervals) + 1)
        #expect(zip(offsets, offsets.dropFirst()).allSatisfy { $0 < $1 }, "every step is at least a minute after the last")
        #expect(SunriseCurve.prepOffset(durationMinutes: minutes) == -minutes - 1)
    }

    @Test func unevenDurationsSpreadTheSteps() {
        #expect(SunriseCurve.offsets(durationMinutes: 20) == [-20, -19, -18, -16, -15, -14, -12, -11, -10, -8, -7, -6, -4, -3, -2, 0])
        #expect(SunriseCurve.offsets(durationMinutes: 10) == Array(-10...0))
    }

    @Test func brightnessStartsAtOnePercentAndSwellsLate() {
        let levels = SunriseCurve.levels(durationMinutes: 30, finalBrightness: 75, finalKelvin: 4000)
        #expect(levels.map(\.brightness) == [1, 1, 2, 4, 6, 9, 13, 17, 22, 28, 34, 41, 48, 57, 65, 75])
    }

    @Test func colorWarmsFromAmberToTheChosenWhite() {
        let kelvins = SunriseCurve.levels(durationMinutes: 30, finalBrightness: 75, finalKelvin: 4000).compactMap(\.kelvin)
        #expect(kelvins.first == 1500)
        #expect(kelvins.last == 4000)
        #expect(kelvins[6] == 2000, "still amber 40% of the way in")
        #expect(zip(kelvins, kelvins.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func brightnessOnlyHasNoColor() {
        let levels = SunriseCurve.levels(durationMinutes: 15, finalBrightness: 60, finalKelvin: nil)
        #expect(levels.allSatisfy { $0.kelvin == nil })
        #expect(levels.last?.brightness == 60)
    }

    @Test func levelsStayInRange() {
        #expect(SunriseCurve.level(at: -1, finalBrightness: 150, finalKelvin: 1000) == SunriseLevel(brightness: 1, kelvin: 1500))
        #expect(SunriseCurve.level(at: 2, finalBrightness: 150, finalKelvin: 1000) == SunriseLevel(brightness: 100, kelvin: 1500))
    }

    @Test func settingsMakeAPrepStepThenTheSunrise() throws {
        var settings = SunriseSettings()
        settings.durationMinutes = 30
        let steps = settings.steps
        #expect(steps.count == 17)
        let prep = try #require(steps.first)
        #expect(prep.number == 0)
        #expect(prep.offsetMinutes == -31)
        #expect(!prep.turnsOn, "the prep step only sets the level")
        #expect(prep.level == steps[1].level, "and sets the first step's level")
        #expect(steps.dropFirst().allSatisfy(\.turnsOn))
        #expect(steps.map(\.name).first == "Sunrise App Step 00")
        #expect(steps.map(\.name).last == "Sunrise App Step 16")
    }

    @Test func colorNames() {
        #expect(SunriseCurve.colorName(kelvin: 2700) == "warm white")
        #expect(SunriseCurve.colorName(kelvin: 4000) == "soft daylight")
        #expect(SunriseCurve.colorName(kelvin: 6500) == "daylight")
    }
}
