import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import Passing

@MainActor
struct IntentCaptureTests {
    let container: ModelContainer
    let now = Date()

    init() throws {
        container = try ModelContainer(for: Pin.self, PinGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private final class Confirmations {
        var count = 0
    }

    private struct Cancelled: Error {}

    private func fix(at timestamp: Date, speed: Double = 27) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.006),
            altitude: 10, horizontalAccuracy: 8, verticalAccuracy: 5,
            course: 225, speed: speed, timestamp: timestamp
        )
    }

    private func service(currentFix: CLLocation?, lateFix: CLLocation? = nil, confirmations: Confirmations = Confirmations()) -> CaptureService {
        CaptureService(
            context: container.mainContext,
            currentFix: { currentFix },
            lateFix: { lateFix },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in confirmations.count += 1 }
        )
    }

    private func savedPins() throws -> [Pin] {
        try container.mainContext.fetch(FetchDescriptor<Pin>())
    }

    @Test func savesFirstThenAsksAndKeepsTheAnswer() async throws {
        let capture = service(currentFix: fix(at: now))
        var pinsSavedWhenAsked = -1
        let pin = await IntentCapture.run(service: capture, source: .siri, ask: true) {
            pinsSavedWhenAsked = (try? self.savedPins().count) ?? -1
            return "  red barn "
        }

        #expect(pinsSavedWhenAsked == 1, "the pin is saved before Siri asks")
        #expect(pin?.label == "red barn")
        #expect(pin?.source == .siri)
        #expect(IntentCapture.dialog(for: pin, service: capture) == "Saved “red barn”.")
    }

    @Test func cancellingTheQuestionKeepsThePin() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await IntentCapture.run(service: capture, source: .siri, ask: true) {
            throw Cancelled()
        }
        #expect(try savedPins().count == 1)
        #expect(pin?.label == nil)
        #expect(IntentCapture.dialog(for: pin, service: capture) == "Saved.")
    }

    @Test func aBlankAnswerLeavesThePinUnlabeled() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await IntentCapture.run(service: capture, source: .siri, ask: true) { "   " }
        #expect(pin?.label == nil)
    }

    @Test func aLabelSaidUpFrontIsUsedWithoutAsking() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await IntentCapture.run(service: capture, source: .siri, side: .left, distance: .far, label: "water tower", ask: true) {
            Issue.record("Siri shouldn't ask when the label was already given")
            return nil
        }
        #expect(pin?.label == "water tower")
        #expect(pin?.side == .left && pin?.distance == .far)
    }

    @Test func quickPinNeverAsks() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await IntentCapture.run(service: capture, source: .actionButton, ask: false) {
            Issue.record("Quick Pin must never ask a question")
            return nil
        }
        #expect(pin?.source == .actionButton)
        #expect(try savedPins().count == 1)
    }

    @Test func siriCapturesSkipTheInAppTapFeedbackAndDebounce() async throws {
        let confirmations = Confirmations()
        let capture = service(currentFix: fix(at: now), confirmations: confirmations)
        await IntentCapture.run(service: capture, source: .siri, ask: false) { nil }
        await IntentCapture.run(service: capture, source: .siri, ask: false) { nil }
        #expect(try savedPins().count == 2, "two quick Siri pins are both kept")
        #expect(confirmations.count == 0, "Siri confirms out loud itself")
    }

    @Test func waitsForTheLocationBeforeFinishing() async throws {
        let capture = service(currentFix: nil, lateFix: fix(at: now.addingTimeInterval(2), speed: 0))
        let pin = await IntentCapture.run(service: capture, source: .siri, ask: false) { nil }
        #expect(pin?.hasLocation == true)
        #expect(IntentCapture.dialog(for: pin, service: capture) == "Saved.")
    }

    @Test func saysSoWhenThereIsNoLocation() async throws {
        let capture = service(currentFix: nil, lateFix: nil)
        let pin = await IntentCapture.run(service: capture, source: .siri, ask: false) { nil }
        #expect(pin?.hasLocation == false)
        #expect(IntentCapture.dialog(for: pin, service: capture) == "Saved. I couldn't get your location, so it has the time only.")
    }

    @Test func widgetButtonSavesItsSideAndDistanceAndWaitsForTheFix() async throws {
        let capture = service(currentFix: nil, lateFix: fix(at: now.addingTimeInterval(1), speed: 0))
        let pin = await IntentCapture.run(service: capture, source: .widget, side: .right, distance: .near, ask: false) {
            Issue.record("the widget must never ask a question")
            return nil
        }
        #expect(pin?.source == .widget)
        #expect(pin?.side == .right && pin?.distance == .near)
        #expect(pin?.hasLocation == true, "the widget waits for the GPS burst before finishing")
    }

    @Test func milesBackFromSiri() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await IntentCapture.run(service: capture, source: .siri, milesBack: 2, ask: true) { "diner" }
        #expect(pin?.milesBack == 2)
        #expect(pin?.label == "diner")
        #expect(pin?.targetSource == .textOnly, "no trail in this test")
        #expect(IntentCapture.dialog(for: pin, service: capture) == "Saved, 2 miles back.")
    }

    @Test func neverSaysSavedWhenItWasNot() {
        let pin = Pin(capturedAt: now, side: .left, distance: .far, source: .siri)
        #expect(IntentCapture.dialog(for: pin, state: .notSaved) == "Sorry, I couldn't save that pin.")
        #expect(IntentCapture.dialog(for: pin, state: .changesPending) == "I saved the pin, but not all of its details. Check it in Passing later.")
    }

    private struct DiskFull: Error {}

    private final class Writes {
        var allowed = 1
    }

    @Test func aLabelThatDidNotSaveIsNotReadBack() async throws {
        // The pin's first write works; the label's write (and the retry) fail.
        let writes = Writes()
        let capture = CaptureService(
            context: container.mainContext,
            currentFix: { self.fix(at: self.now) },
            lateFix: { nil },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in },
            persist: { context in
                guard writes.allowed > 0 else { throw DiskFull() }
                writes.allowed -= 1
                try context.save()
            }
        )
        let result = await IntentCapture.run(service: capture, source: .siri, ask: true) { "red barn" }
        let pin = try #require(result)
        #expect(capture.saveState(of: pin) == .changesPending)
        #expect(IntentCapture.dialog(for: pin, service: capture) == "I saved the pin, but not all of its details. Check it in Passing later.")

        // The next write that works saves the label too.
        writes.allowed = 1
        #expect(capture.retrySave())
        #expect(capture.saveState(of: pin) == .saved)
    }
}
