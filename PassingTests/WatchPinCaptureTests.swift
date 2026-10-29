import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import Passing

/// Pins arriving from Apple Watch go through the same `CaptureService` as every other pin.
@MainActor
struct WatchPinCaptureTests {
    let container: ModelContainer
    let tap = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelContainer(for: Pin.self, PinGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private struct DiskFull: Error {}

    private final class Store {
        var failing = false
        var confirmations = 0
        var reviewCounts: [Int] = []
    }

    /// The iPhone is somewhere else by the time the pin arrives, and its GPS would answer at once.
    private func service(_ store: Store = Store()) -> CaptureService {
        let elsewhere = CLLocation(latitude: 34.05, longitude: -118.24)
        return CaptureService(
            context: container.mainContext,
            currentFix: { elsewhere },
            lateFix: { elsewhere },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in store.confirmations += 1 },
            reviewWaiting: { store.reviewCounts.append($0) },
            persist: { context in
                if store.failing { throw DiskFull() }
                try context.save()
            }
        )
    }

    private func watchPin(fix: WatchFix?) -> WatchPin {
        WatchPin(id: UUID(), capturedAt: tap, side: .right, distance: .near, fix: fix)
    }

    private func reading(secondsAfterTap: Double, accuracy: Double = 7) -> WatchFix {
        WatchFix(latitude: 40.7128, longitude: -74.006, horizontalAccuracy: accuracy, timestamp: tap.addingTimeInterval(secondsAfterTap), speed: 1.3, course: 180, courseAccuracy: 30)
    }

    private func savedPins() throws -> [Pin] {
        try container.mainContext.fetch(FetchDescriptor<Pin>())
    }

    @Test func aWatchPinKeepsTheWatchsPositionAndTapTime() throws {
        let store = Store()
        let capture = service(store)
        let sent = watchPin(fix: reading(secondsAfterTap: 1))
        #expect(capture.saveWatchPin(sent, now: tap.addingTimeInterval(90)))

        let pin = try #require(try savedPins().first)
        #expect(pin.id == sent.id, "the same id as on the watch, so a resend is recognized")
        #expect(pin.source == .watch)
        #expect(pin.capturedAt == tap)
        #expect(pin.side == .right && pin.distance == .near)
        #expect(pin.latitude == 40.7128 && pin.longitude == -74.006, "the watch's reading, not where the iPhone is now")
        #expect(pin.horizontalAccuracy == 7)
        #expect(!pin.courseReliable, "walking pace is too slow for a direction")
        #expect(store.confirmations == 0, "the watch gave its own wrist tap; the iPhone stays silent")
    }

    @Test func aWatchPinWithNoReadingNeverTakesTheiPhonesPosition() async throws {
        let capture = service()
        #expect(capture.saveWatchPin(watchPin(fix: nil), now: tap.addingTimeInterval(5)))
        let pin = try #require(try savedPins().first)
        await capture.waitForLocation(of: pin)
        #expect(!pin.hasLocation, "no late fix from the iPhone, which may be miles away")
    }

    @Test func aReadingOutsideTheRulesIsDropped() throws {
        let capture = service()
        capture.saveWatchPin(watchPin(fix: reading(secondsAfterTap: 40)))
        capture.saveWatchPin(watchPin(fix: reading(secondsAfterTap: 1, accuracy: 900)))
        #expect(try savedPins().allSatisfy { !$0.hasLocation })
    }

    @Test func aPinThatArrivesTwiceIsSavedOnce() throws {
        let capture = service()
        let sent = watchPin(fix: reading(secondsAfterTap: 0))
        #expect(capture.saveWatchPin(sent))
        #expect(capture.saveWatchPin(sent), "still answered as saved, so the watch lets it go")
        #expect(try savedPins().count == 1)
    }

    @Test func aPinTheiPhoneCouldntWriteIsNotAnsweredAsSaved() throws {
        let store = Store()
        store.failing = true
        let capture = service(store)
        let sent = watchPin(fix: reading(secondsAfterTap: 0))
        #expect(!capture.saveWatchPin(sent), "the watch keeps it and sends it again")

        store.failing = false
        #expect(capture.saveWatchPin(sent), "the resend writes it")
        #expect(try savedPins().count == 1)
    }

    @Test func theWatchIsToldAboutEveryWatchPinOnDisk() throws {
        let store = Store()
        let capture = service(store)
        let first = watchPin(fix: nil)
        var second = watchPin(fix: nil)
        second.capturedAt = tap.addingTimeInterval(60)
        capture.saveWatchPin(second)
        capture.saveWatchPin(first)
        capture.capture(side: .left, distance: .far, source: .widget, now: tap)
        #expect(capture.savedWatchPinIDs() == [first.id, second.id], "watch pins only, oldest first")

        let pin = try #require(try savedPins().first(where: { $0.id == first.id }))
        pin.deletedAt = tap
        #expect(capture.savedWatchPinIDs().contains(first.id), "Recently Deleted still counts: the iPhone has it")

        store.failing = true
        let notWritten = watchPin(fix: nil)
        capture.saveWatchPin(notWritten)
        #expect(!capture.savedWatchPinIDs().contains(notWritten.id), "not on disk yet, so the watch keeps it")
        #expect(capture.savedWatchPinIDs(limit: 1) == [second.id], "the newest when there are more than fit")
    }

    @Test func watchPinsWaitInNeedsReview() throws {
        let store = Store()
        let capture = service(store)
        capture.saveWatchPin(watchPin(fix: nil))
        #expect(try #require(try savedPins().first).needsReview)
        #expect(store.reviewCounts == [1], "review reminders are armed")
        #expect(capture.needsReviewCount() == 1)
    }
}
