import Foundation
import Testing
@testable import Passing

struct WatchOutboxTests {
    let tap = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func fix(at timestamp: Date, accuracy: Double = 6) -> WatchFix {
        WatchFix(latitude: 40.7128, longitude: -74.006, horizontalAccuracy: accuracy, timestamp: timestamp, speed: 1.4, course: 90, courseAccuracy: 20)
    }

    private func pin(at time: Date, fix: WatchFix? = nil) -> WatchPin {
        WatchPin(id: UUID(), capturedAt: time, side: .left, distance: .far, fix: fix)
    }

    @Test func aTapWithAFreshReadingIsReadyAtOnce() {
        var outbox = WatchOutbox()
        let ready = pin(at: tap, fix: fix(at: tap.addingTimeInterval(-2)))
        outbox.add(ready, waitForFix: true)
        #expect(!outbox.isWaitingForFix, "it already has its reading")
        #expect(outbox.readyToSend(excluding: []).map(\.id) == [ready.id])
        #expect(outbox.entries.first?.pin.gps == .atTap)
        #expect(outbox.entries.first?.pin.gpsWait == 0)
    }

    @Test func aPinWaitsForItsReadingBeforeItsSent() throws {
        var outbox = WatchOutbox()
        let waiting = pin(at: tap)
        outbox.add(waiting, waitForFix: true)
        #expect(outbox.isWaitingForFix)
        #expect(outbox.readyToSend(excluding: []).isEmpty, "saved on the watch, but not sent without its reading")

        let reading = fix(at: tap.addingTimeInterval(3))
        #expect(outbox.attach(reading, now: tap.addingTimeInterval(3)) == [waiting.id])
        let sent = try #require(outbox.readyToSend(excluding: []).first)
        #expect(sent.fix == reading)
        #expect(sent.capturedAt == tap, "the tap time never changes")
        #expect(sent.gps == .afterTap)
        #expect(sent.gpsWait == 3)
    }

    @Test func aReadingTooLateTooOldOrTooRoughIsRefused() {
        var outbox = WatchOutbox()
        outbox.add(pin(at: tap), waitForFix: true)
        #expect(outbox.attach(fix(at: tap.addingTimeInterval(16)), now: tap.addingTimeInterval(16)).isEmpty, "over 15 s after the tap")
        #expect(outbox.attach(fix(at: tap.addingTimeInterval(2)), now: tap.addingTimeInterval(14)).isEmpty, "12 s old when it arrived")
        #expect(outbox.attach(fix(at: tap.addingTimeInterval(2), accuracy: 500), now: tap.addingTimeInterval(2)).isEmpty, "500 m accuracy")
        #expect(outbox.isWaitingForFix)
    }

    @Test func afterFifteenSecondsAPinGoesWithoutALocation() throws {
        var outbox = WatchOutbox()
        let waiting = pin(at: tap)
        outbox.add(waiting, waitForFix: true)
        #expect(outbox.stopWaiting(now: tap.addingTimeInterval(10)).isEmpty, "still inside its 15 s")
        #expect(outbox.stopWaiting(now: tap.addingTimeInterval(16)) == [waiting.id])
        let sent = try #require(outbox.readyToSend(excluding: []).first)
        #expect(sent.fix == nil, "no location rather than a late one")
        #expect(sent.gps == .gaveUp)
        #expect(sent.gpsWait == 16)
    }

    @Test func goingToTheBackgroundStopsEveryWait() {
        var outbox = WatchOutbox()
        outbox.add(pin(at: tap), waitForFix: true)
        outbox.stopWaiting(now: tap.addingTimeInterval(2), all: true)
        #expect(!outbox.isWaitingForFix)
        #expect(outbox.entries.first?.pin.gps == .closed)
        #expect(outbox.readyToSend(excluding: []).count == 1)
    }

    @Test func withNoWayToGetALocationAPinDoesntWait() {
        var outbox = WatchOutbox()
        outbox.add(pin(at: tap), waitForFix: false)
        #expect(outbox.readyToSend(excluding: []).count == 1)
        #expect(outbox.entries.first?.pin.gps == .off)
    }

    @Test func pinsOnTheirWayAreNotQueuedTwice() {
        var outbox = WatchOutbox()
        let first = pin(at: tap, fix: fix(at: tap))
        let second = pin(at: tap.addingTimeInterval(5), fix: fix(at: tap.addingTimeInterval(5)))
        outbox.add(first, waitForFix: true)
        outbox.add(second, waitForFix: true)
        #expect(outbox.readyToSend(excluding: [first.id]).map(\.id) == [second.id])
    }

    @Test func aPinThatReachedTheiPhoneIsResentOnlyWhenPassingStartsAnHourLater() {
        var outbox = WatchOutbox()
        let sent = pin(at: tap, fix: fix(at: tap))
        outbox.add(sent, waitForFix: true)
        outbox.markDelivered(sent.id, at: tap.addingTimeInterval(10))
        #expect(outbox.readyToSend(excluding: []).isEmpty, "a tap doesn't send it again")
        #expect(outbox.readyToSend(excluding: [], resendingAt: tap.addingTimeInterval(30 * 60)).isEmpty, "too soon")
        #expect(outbox.readyToSend(excluding: [], resendingAt: tap.addingTimeInterval(2 * 60 * 60)).map(\.id) == [sent.id])
        #expect(outbox.count == 1, "kept until the iPhone says it's saved")
    }

    @Test func aPinStillUnansweredAfterItsResendGoesAgainAnHourLater() {
        var outbox = WatchOutbox()
        let sent = pin(at: tap, fix: fix(at: tap))
        outbox.add(sent, waitForFix: true)
        outbox.markDelivered(sent.id, at: tap)
        let resendAt = tap.addingTimeInterval(2 * 60 * 60)
        _ = outbox.markSent(outbox.readyToSend(excluding: [], resendingAt: resendAt).map(\.id), at: resendAt)
        #expect(outbox.readyToSend(excluding: [], resendingAt: resendAt.addingTimeInterval(10 * 60)).isEmpty, "not on every visit")
        #expect(outbox.readyToSend(excluding: [], resendingAt: resendAt.addingTimeInterval(61 * 60)).map(\.id) == [sent.id], "Passing stayed launched, and it still goes again")
    }

    @Test func eachSendIsCountedAndTheFirstIsTimed() {
        var outbox = WatchOutbox()
        let one = pin(at: tap, fix: fix(at: tap))
        outbox.add(one, waitForFix: true)
        let first = outbox.markSent([one.id], at: tap.addingTimeInterval(1))
        #expect(first.first?.sentAt == tap.addingTimeInterval(1))
        #expect(first.first?.sends == 1)
        let again = outbox.markSent([one.id], at: tap.addingTimeInterval(4_000))
        #expect(again.first?.sentAt == tap.addingTimeInterval(1), "the first send's time is kept")
        #expect(again.first?.sends == 2)
        #expect(outbox.markSent([UUID()], at: tap).isEmpty)
    }

    @Test func onlyPinsTheiPhoneHasSavedLeave() {
        var outbox = WatchOutbox()
        let saved = pin(at: tap, fix: fix(at: tap))
        let notYet = pin(at: tap.addingTimeInterval(5))
        outbox.add(saved, waitForFix: true)
        outbox.add(notYet, waitForFix: false)
        outbox.confirmSaved([saved.id, UUID()])
        #expect(outbox.entries.map(\.pin.id) == [notYet.id])
    }

    @Test func theSamePinIsKeptOnce() {
        var outbox = WatchOutbox()
        let once = pin(at: tap)
        outbox.add(once, waitForFix: false)
        outbox.add(once, waitForFix: false)
        #expect(outbox.count == 1)
    }

    @Test func theOutboxSurvivesBeingWrittenToDisk() throws {
        var outbox = WatchOutbox()
        let delivered = pin(at: tap, fix: fix(at: tap))
        outbox.add(delivered, waitForFix: true)
        outbox.add(pin(at: tap.addingTimeInterval(1)), waitForFix: true)
        outbox.markDelivered(delivered.id, at: tap.addingTimeInterval(4))
        let data = try JSONEncoder().encode(outbox)
        #expect(try JSONDecoder().decode(WatchOutbox.self, from: data) == outbox)
    }
}

struct WatchMessageTests {
    @Test func aPinTravelsIntactAsPropertyListData() throws {
        let fix = WatchFix(latitude: 51.5, longitude: -0.12, horizontalAccuracy: 9, timestamp: .now, speed: -1, course: -1, courseAccuracy: -1)
        let pin = WatchPin(id: UUID(), capturedAt: .now, side: .right, distance: .near, fix: fix)
        let userInfo = try #require(WatchMessage.userInfo(for: pin))
        #expect(userInfo[WatchMessage.pinKey] is Data, "transferUserInfo only takes property-list values")
        #expect(WatchMessage.pin(from: userInfo) == pin)
        #expect(WatchMessage.pinID(from: userInfo) == pin.id)
        #expect(WatchMessage.pinID(from: [WatchMessage.pinKey: userInfo[WatchMessage.pinKey] as Any]) == pin.id, "older messages without the id beside them")
    }

    @Test func savedAnswersCarryTheirIDs() {
        let ids = [UUID(), UUID()]
        #expect(WatchMessage.savedIDs(from: WatchMessage.userInfo(saved: ids)) == ids)
    }

    @Test func theiPhoneKeepsItsNewestSavedIDs() {
        let old = (0..<100).map { _ in UUID() }
        let new = UUID()
        let kept = WatchMessage.recentlySaved(old, adding: [new])
        #expect(kept.count == 100)
        #expect(kept.last == new)
        #expect(kept.first == old[1], "the oldest one makes room")
        #expect(WatchMessage.recentlySaved([new], adding: [new]) == [new], "no duplicates")
    }

    @Test func otherMessagesAreIgnored() {
        #expect(WatchMessage.pin(from: ["something": "else"]) == nil)
        #expect(WatchMessage.pin(from: [WatchMessage.pinKey: Data("not a pin".utf8)]) == nil)
        #expect(WatchMessage.savedIDs(from: [WatchMessage.savedKey: ["not-a-uuid"]]).isEmpty)
    }

    @Test func aReadingIsOnlyUsableWhileFreshAndAccurate() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let fresh = WatchFix(latitude: 1, longitude: 2, horizontalAccuracy: 10, timestamp: now.addingTimeInterval(-3), speed: 0, course: -1, courseAccuracy: -1)
        #expect(fresh.isUsable(now: now))
        #expect(!fresh.isUsable(now: now.addingTimeInterval(20)), "a stale reading is never the current position")
        var rough = fresh
        rough.horizontalAccuracy = 800
        #expect(!rough.isUsable(now: now))
        var invalid = fresh
        invalid.horizontalAccuracy = -1
        #expect(!invalid.isUsable(now: now))
    }
}
