import Foundation
import Testing
@testable import Passing

struct FixPolicyTests {
    let tap = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func freshAccurateFixIsUsable() {
        #expect(FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: 8, now: tap.addingTimeInterval(1)))
    }

    @Test func fixOlderThanMaxAgeIsNeverUsedAsCurrent() {
        #expect(FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: 8, now: tap.addingTimeInterval(FixPolicy.maxAge)))
        #expect(!FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: 8, now: tap.addingTimeInterval(FixPolicy.maxAge + 0.5)))
        #expect(!FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: 8, now: tap.addingTimeInterval(3_600)))
    }

    @Test func invalidOrVeryInaccurateFixIsNotUsable() {
        #expect(!FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: -1, now: tap))
        #expect(!FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: FixPolicy.maxAccuracy + 1, now: tap))
        #expect(FixPolicy.isUsable(fixTimestamp: tap, horizontalAccuracy: FixPolicy.maxAccuracy, now: tap))
    }

    @Test func fixesMoreThanAFewSecondsFromTheTapAreApproximate() {
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-1), horizontalAccuracy: 10))
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-FixPolicy.exactAge), horizontalAccuracy: 10))
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-3.5), horizontalAccuracy: 10))
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(4), horizontalAccuracy: 10))
    }

    @Test func impreciseFixesAreApproximate() {
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap, horizontalAccuracy: FixPolicy.exactAccuracy))
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap, horizontalAccuracy: FixPolicy.exactAccuracy + 1))
    }

    @Test func lateFixMustArriveWithinTheWindow() {
        #expect(FixPolicy.acceptsLateFix(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(2)))
        #expect(FixPolicy.acceptsLateFix(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(FixPolicy.lateFixWindow)))
        #expect(!FixPolicy.acceptsLateFix(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(FixPolicy.lateFixWindow + 1)))
        // An old cached fix is never attached.
        #expect(!FixPolicy.acceptsLateFix(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-60)))
    }

    @Test func courseOnlyCountsWhenMoving() {
        #expect(FixPolicy.isCourseReliable(course: 90, courseAccuracy: 5, speed: 25))
        #expect(!FixPolicy.isCourseReliable(course: 90, courseAccuracy: 5, speed: 1), "too slow")
        #expect(!FixPolicy.isCourseReliable(course: -1, courseAccuracy: 5, speed: 25), "no course")
        #expect(!FixPolicy.isCourseReliable(course: 90, courseAccuracy: 90, speed: 25), "too uncertain")
        #expect(FixPolicy.isCourseReliable(course: 90, courseAccuracy: -1, speed: 25), "no accuracy estimate")
    }
}
