import Foundation
import Testing
@testable import Passing

struct WidgetSavedNoteTests {
    let saved = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func note(hasLocation: Bool = true) -> WidgetSavedNote {
        WidgetSavedNote(savedAt: saved, side: .left, distance: .far, hasLocation: hasLocation)
    }

    @Test func showsForFiveSecondsAfterTheTap() {
        #expect(note().isShowing(at: saved))
        #expect(note().isShowing(at: saved.addingTimeInterval(4.9)))
        #expect(!note().isShowing(at: saved.addingTimeInterval(5)))
        #expect(!note().isShowing(at: saved.addingTimeInterval(-1)), "a note from the future isn't shown")
        #expect(note().hidesAt == saved.addingTimeInterval(5))
    }

    @Test func onlyTheTappedButtonGetsTheTick() {
        #expect(note().matches(side: .left, distance: .far))
        #expect(!note().matches(side: .left, distance: .near))
        #expect(!note().matches(side: .right, distance: .far))
        #expect(!note().matches(side: .unknown, distance: .unknown), "the single Pin widget ignores grid taps")
    }

    @Test func saysWhenThereWasNoLocation() {
        #expect(note().shortMessage == "Saved")
        #expect(note(hasLocation: false).shortMessage == "No location")
    }

    @Test func saysWhenItWasNotSaved() {
        var failed = note()
        failed.saved = false
        #expect(failed.shortMessage == "Not saved")
    }

    @Test func survivesTheTripThroughSharedSettings() throws {
        let data = try JSONEncoder().encode(note())
        #expect(try JSONDecoder().decode(WidgetSavedNote.self, from: data) == note())
    }
}

struct CaptureSourceTests {
    @Test func buttonTapsAreDebouncedButSpokenRequestsAreNot() {
        #expect(CaptureSource.app.isTap)
        #expect(CaptureSource.widget.isTap)
        #expect(CaptureSource.control.isTap)
        #expect(!CaptureSource.siri.isTap)
        #expect(!CaptureSource.actionButton.isTap)
        #expect(!CaptureSource.watch.isTap, "the watch debounces its own buttons")
    }

    @Test func onlyWidgetControlCenterAndWatchPinsNeedReview() {
        #expect(CaptureSource.widget.needsReviewUntilReviewed)
        #expect(CaptureSource.control.needsReviewUntilReviewed)
        #expect(CaptureSource.watch.needsReviewUntilReviewed)
        #expect(!CaptureSource.app.needsReviewUntilReviewed)
        #expect(!CaptureSource.siri.needsReviewUntilReviewed)
        #expect(!CaptureSource.actionButton.needsReviewUntilReviewed)
    }
}
