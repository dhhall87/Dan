import Foundation
import Testing
@testable import Passing

struct SpokenConfirmationTests {
    private let phrases = ["Got it boss", "I'll look this up later", "Writing this down for you now"]

    @Test func saysTheSideFirstThenAPhrase() {
        let text = SpokenConfirmation.text(side: .left, distance: .far, milesBack: 0, phrases: phrases, sayClueFirst: true, pick: { _ in 0 })
        #expect(text == "Left, far. Got it boss")
    }

    @Test func canSkipTheSide() {
        let text = SpokenConfirmation.text(side: .left, distance: .far, milesBack: 0, phrases: phrases, sayClueFirst: false, pick: { _ in 2 })
        #expect(text == "Writing this down for you now")
    }

    @Test func unknownSideJustSaysThePhrase() {
        let text = SpokenConfirmation.text(side: .unknown, distance: .unknown, milesBack: 0, phrases: phrases, sayClueFirst: true, pick: { _ in 1 })
        #expect(text == "I'll look this up later")
    }

    @Test func noPhrasesFallsBackToSaved() {
        #expect(SpokenConfirmation.text(side: .right, distance: .near, milesBack: 0, phrases: [], sayClueFirst: true) == "Right, near. Saved")
    }

    @Test func milesBackAlwaysSaysTheDistance() {
        #expect(SpokenConfirmation.text(side: .unknown, distance: .unknown, milesBack: 1, phrases: phrases, sayClueFirst: true) == "1 mile back")
        #expect(SpokenConfirmation.text(side: .left, distance: .far, milesBack: 2, phrases: phrases, sayClueFirst: true) == "2 miles back")
    }

    @Test func pickingIsAlwaysInRange() {
        for pick in [-5, 0, 2, 99] {
            let text = SpokenConfirmation.text(side: .unknown, distance: .unknown, milesBack: 0, phrases: phrases, sayClueFirst: false, pick: { _ in pick })
            #expect(phrases.contains(text))
        }
    }

    @Test func phrasesAreStoredOnePerLineAndCapped() {
        let long = String(repeating: "a", count: 80)
        let stored = SpokenConfirmation.stored(["  Got it boss ", "", long])
        #expect(stored == "Got it boss\n" + String(repeating: "a", count: SpokenConfirmation.maxPhraseLength))
        #expect(SpokenConfirmation.phrases(from: stored).count == 2)
        #expect(SpokenConfirmation.phrases(from: "\n\n").isEmpty)
    }
}

struct MilesBackHintTests {
    @Test func breadcrumbPinsPointAtTheMap() throws {
        let hint = try #require(PinDescription.milesBackHint(milesBack: 2, targetSource: .breadcrumb, course: 225, courseReliable: true))
        #expect(hint.hasPrefix("Placed 2 miles back along the road you drove."))
    }

    @Test func movedPinsSayYouPlacedThem() throws {
        let hint = try #require(PinDescription.milesBackHint(milesBack: 2, targetSource: .manual, course: 225, courseReliable: true))
        #expect(hint == "You moved this pin to the spot yourself. It was saved about 2 miles back.")
    }

    @Test func textOnlyPinsSayWhichWayToLook() throws {
        let hint = try #require(PinDescription.milesBackHint(milesBack: 2, targetSource: .textOnly, course: 225, courseReliable: true))
        #expect(hint.contains("About 2 miles back the way you came."))
        #expect(hint.contains("You were heading southwest, so look northeast of this spot."))
    }

    @Test func textOnlyWithoutAReliableHeadingSkipsTheDirection() throws {
        let hint = try #require(PinDescription.milesBackHint(milesBack: 1, targetSource: .textOnly, course: 225, courseReliable: false))
        #expect(!hint.contains("heading"))
    }

    @Test func ordinaryPinsHaveNoHint() {
        #expect(PinDescription.milesBackHint(milesBack: 0, targetSource: .direct, course: nil, courseReliable: false) == nil)
    }
}
