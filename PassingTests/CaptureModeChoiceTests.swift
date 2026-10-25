import Foundation
import Testing
@testable import Passing

struct CaptureModeChoiceTests {
    @Test func opensOnTheSettingsLayout() {
        let choice = CaptureModeChoice()
        #expect(choice.mode(default: .quick) == .quick)
        #expect(choice.mode(default: .fourZone) == .fourZone)
    }

    @Test func titleButtonFlipsBackAndForth() {
        var choice = CaptureModeChoice()
        choice.toggle(default: .quick)
        #expect(choice.mode(default: .quick) == .fourZone)
        choice.toggle(default: .quick)
        #expect(choice.mode(default: .quick) == .quick)
        #expect(choice.switchedTo == nil, "Back on the Settings layout, so a later Settings change still shows")
    }

    @Test func settingsChangeShowsStraightAway() {
        var choice = CaptureModeChoice()
        choice.toggle(default: .quick)
        choice.defaultChanged()
        #expect(choice.mode(default: .quick) == .quick)
    }

    @Test func shortBreakKeepsTheSwitch() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var choice = CaptureModeChoice()
        choice.toggle(default: .quick)
        choice.wentToBackground(at: start)
        choice.cameBack(at: start.addingTimeInterval(CaptureModeChoice.resetAfter - 1))
        #expect(choice.mode(default: .quick) == .fourZone)
    }

    @Test func longBreakStartsOnTheSettingsLayout() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var choice = CaptureModeChoice()
        choice.toggle(default: .quick)
        choice.wentToBackground(at: start)
        choice.cameBack(at: start.addingTimeInterval(CaptureModeChoice.resetAfter + 1))
        #expect(choice.mode(default: .quick) == .quick)
    }

    @Test func becomingActiveWithoutLeavingKeepsTheSwitch() {
        // Control Center or a Siri request makes Passing inactive, not backgrounded.
        var choice = CaptureModeChoice()
        choice.toggle(default: .fourZone)
        choice.cameBack(at: .now)
        #expect(choice.mode(default: .fourZone) == .quick)
    }
}
