import Foundation
import Testing
@testable import Passing

struct CoarseLocationTests {
    @Test func roundsToAboutAKilometer() {
        #expect(CoarseLocation.round(37.97456) == 37.97)
        #expect(CoarseLocation.round(-100.87612) == -100.88)
        #expect(abs(CoarseLocation.round(37.975) - 37.98) < 0.000_001 || abs(CoarseLocation.round(37.975) - 37.97) < 0.000_001,
                "a value halfway between can go either way")
    }

    @Test func keepsOnlyTheCompassDirection() {
        #expect(CoarseLocation.roundCourse(10) == 0)
        #expect(CoarseLocation.roundCourse(30) == 45)
        #expect(CoarseLocation.roundCourse(225) == 225)
        #expect(CoarseLocation.roundCourse(350) == 0, "nearly north is north")
    }
}
