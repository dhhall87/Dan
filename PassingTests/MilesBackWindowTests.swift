import Foundation
import Testing
@testable import Passing

struct MilesBackWindowTests {
    let pinned = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func opensForTenSecondsAfterThePin() {
        let window = MilesBackWindow(pinnedAt: pinned)
        #expect(window.isOpen(at: pinned.addingTimeInterval(6)))
        #expect(window.isOpen(at: pinned.addingTimeInterval(10)))
        #expect(!window.isOpen(at: pinned.addingTimeInterval(10.5)))
    }

    @Test func eachPlusOneKeepsItOpenFiveSecondsMore() {
        var window = MilesBackWindow(pinnedAt: pinned)
        window.bumped(at: pinned.addingTimeInterval(6))
        #expect(window.isOpen(at: pinned.addingTimeInterval(10)), "Dan's example: 6 s, then 4 s")
        window.bumped(at: pinned.addingTimeInterval(10))
        #expect(window.closesAt == pinned.addingTimeInterval(15))
        #expect(!window.isOpen(at: pinned.addingTimeInterval(15.5)))
    }

    @Test func anEarlyPlusOneDoesntShortenTheTenSeconds() {
        var window = MilesBackWindow(pinnedAt: pinned)
        window.bumped(at: pinned.addingTimeInterval(1))
        #expect(window.closesAt == pinned.addingTimeInterval(10))
    }
}
