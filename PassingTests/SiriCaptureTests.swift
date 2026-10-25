import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import Passing

@MainActor
struct SiriCaptureTests {
    let container: ModelContainer
    let now = Date()

    init() throws {
        container = try ModelContainer(for: Pin.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
        let pin = await SiriCapture.run(service: capture, source: .siri, ask: true) {
            pinsSavedWhenAsked = (try? self.savedPins().count) ?? -1
            return "  red barn "
        }

        #expect(pinsSavedWhenAsked == 1, "the pin is saved before Siri asks")
        #expect(pin?.label == "red barn")
        #expect(pin?.source == .siri)
        #expect(SiriCapture.dialog(for: pin) == "Saved “red barn”.")
    }

    @Test func cancellingTheQuestionKeepsThePin() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await SiriCapture.run(service: capture, source: .siri, ask: true) {
            throw Cancelled()
        }
        #expect(try savedPins().count == 1)
        #expect(pin?.label == nil)
        #expect(SiriCapture.dialog(for: pin) == "Saved.")
    }

    @Test func aBlankAnswerLeavesThePinUnlabeled() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await SiriCapture.run(service: capture, source: .siri, ask: true) { "   " }
        #expect(pin?.label == nil)
    }

    @Test func aLabelSaidUpFrontIsUsedWithoutAsking() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await SiriCapture.run(service: capture, source: .siri, side: .left, distance: .far, label: "water tower", ask: true) {
            Issue.record("Siri shouldn't ask when the label was already given")
            return nil
        }
        #expect(pin?.label == "water tower")
        #expect(pin?.side == .left && pin?.distance == .far)
    }

    @Test func quickPinNeverAsks() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await SiriCapture.run(service: capture, source: .actionButton, ask: false) {
            Issue.record("Quick Pin must never ask a question")
            return nil
        }
        #expect(pin?.source == .actionButton)
        #expect(try savedPins().count == 1)
    }

    @Test func siriCapturesSkipTheInAppTapFeedbackAndDebounce() async throws {
        let confirmations = Confirmations()
        let capture = service(currentFix: fix(at: now), confirmations: confirmations)
        await SiriCapture.run(service: capture, source: .siri, ask: false) { nil }
        await SiriCapture.run(service: capture, source: .siri, ask: false) { nil }
        #expect(try savedPins().count == 2, "two quick Siri pins are both kept")
        #expect(confirmations.count == 0, "Siri confirms out loud itself")
    }

    @Test func waitsForTheLocationBeforeFinishing() async throws {
        let capture = service(currentFix: nil, lateFix: fix(at: now.addingTimeInterval(2), speed: 0))
        let pin = await SiriCapture.run(service: capture, source: .siri, ask: false) { nil }
        #expect(pin?.hasLocation == true)
        #expect(SiriCapture.dialog(for: pin) == "Saved.")
    }

    @Test func saysSoWhenThereIsNoLocation() async throws {
        let capture = service(currentFix: nil, lateFix: nil)
        let pin = await SiriCapture.run(service: capture, source: .siri, ask: false) { nil }
        #expect(pin?.hasLocation == false)
        #expect(SiriCapture.dialog(for: pin) == "Saved. I couldn't get your location, so it has the time only.")
    }

    @Test func milesBackFromSiri() async throws {
        let capture = service(currentFix: fix(at: now))
        let pin = await SiriCapture.run(service: capture, source: .siri, milesBack: 2, ask: true) { "diner" }
        #expect(pin?.milesBack == 2)
        #expect(pin?.label == "diner")
        #expect(pin?.targetSource == .textOnly, "no trail in this test")
        #expect(SiriCapture.dialog(for: pin) == "Saved, 2 miles back.")
    }
}
