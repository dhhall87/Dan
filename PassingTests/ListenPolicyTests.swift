import Foundation
import Testing
@testable import Passing

struct ListenPolicyTests {
    let chime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let policy = ListenPolicy()

    private func at(_ seconds: TimeInterval) -> Date { chime.addingTimeInterval(seconds) }

    @Test func givesUpWhenNothingIsSaid() {
        #expect(!policy.shouldStop(startedAt: chime, lastHeardAt: nil, now: at(5.9)), "about 5 seconds of silence is fine")
        #expect(policy.shouldStop(startedAt: chime, lastHeardAt: nil, now: at(6)))
    }

    @Test func stopsShortlyAfterTheDriverStopsTalking() {
        #expect(!policy.shouldStop(startedAt: chime, lastHeardAt: at(2), now: at(3.4)))
        #expect(policy.shouldStop(startedAt: chime, lastHeardAt: at(2), now: at(3.5)))
    }

    @Test func talkingPastTheFirstWaitKeepsListening() {
        #expect(!policy.shouldStop(startedAt: chime, lastHeardAt: at(7), now: at(8)), "still talking at 7 s")
    }

    @Test func neverListensLongerThanTheMaximum() {
        #expect(policy.shouldStop(startedAt: chime, lastHeardAt: at(14.9), now: at(15)))
    }

    @Test func tidiesWhatWasSaidIntoALabel() {
        #expect(ListenPolicy.label(from: "  red barn. ") == "red barn")
        #expect(ListenPolicy.label(from: "Water tower?") == "Water tower")
        #expect(ListenPolicy.label(from: String(repeating: "a", count: 150))?.count == ListenPolicy.maxLabelLength)
    }

    @Test func nothingOrCancelMeansNoLabel() {
        #expect(ListenPolicy.label(from: nil) == nil)
        #expect(ListenPolicy.label(from: "   ") == nil)
        #expect(ListenPolicy.label(from: "Cancel.") == nil)
        #expect(ListenPolicy.label(from: "never mind") == nil)
        #expect(ListenPolicy.label(from: "no barn") == "no barn", "only the whole phrase cancels")
    }

    @Test func stopAndCancelEndListeningSooner() {
        #expect(policy.shouldStop(startedAt: chime, lastHeardAt: at(2), heard: "Stop", now: at(2.7)))
        #expect(!policy.shouldStop(startedAt: chime, lastHeardAt: at(2), heard: "Stop", now: at(2.5)),
                "a short grace in case it's the start of \"stop sign\"")
        #expect(!policy.shouldStop(startedAt: chime, lastHeardAt: at(2), heard: "stop sign", now: at(2.6)))
        #expect(ListenPolicy.isStopCommand("Stop"))
        #expect(ListenPolicy.isStopCommand("stop listening."))
        #expect(ListenPolicy.isStopCommand("Cancel"))
        #expect(!ListenPolicy.isStopCommand("stop sign"), "a label that starts with stop is still a label")
        #expect(!ListenPolicy.isStopCommand(nil))
        #expect(ListenPolicy.label(from: "stop") == nil)
    }
}
