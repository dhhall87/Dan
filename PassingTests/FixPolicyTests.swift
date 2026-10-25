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

    @Test func parkedFixIsExactEvenIfItIsAFewSecondsOld() {
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-8), horizontalAccuracy: 5, speed: 0))
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(12), horizontalAccuracy: 5, speed: 0))
    }

    @Test func movingFixIsApproximateOnceTheCarCouldHaveMovedTooFar() {
        // 65 mph is about 29 m/s.
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-1), horizontalAccuracy: 5, speed: 29), "29 m")
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-2), horizontalAccuracy: 5, speed: 29), "58 m")
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(3), horizontalAccuracy: 5, speed: 29), "87 m, fix after the tap")
        // 30 mph is about 13 m/s: 3 s is 39 m, 4 s is 52 m.
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-3), horizontalAccuracy: 5, speed: 13))
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-4), horizontalAccuracy: 5, speed: 13))
    }

    @Test func accuracyAndMovementAddUp() {
        // 30 mph (13 m/s) for 3 s is 39 m. With a ±30 m fix that's 49 m in total: exact.
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-3), horizontalAccuracy: 30, speed: 13))
        // With a ±40 m fix it's 56 m: approximate, though neither is over 50 m on its own.
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-3), horizontalAccuracy: 40, speed: 13))
    }

    @Test func unknownSpeedFallsBackToFixAge() {
        for speed in [nil, -1.0] {
            #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-FixPolicy.exactAge), horizontalAccuracy: 5, speed: speed))
            #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap.addingTimeInterval(-3.5), horizontalAccuracy: 5, speed: speed))
        }
    }

    @Test func impreciseFixesAreApproximate() {
        #expect(!FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap, horizontalAccuracy: FixPolicy.exactAccuracy, speed: 0))
        #expect(FixPolicy.isApproximate(capturedAt: tap, fixTimestamp: tap, horizontalAccuracy: FixPolicy.exactAccuracy + 1, speed: 0))
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
