import AppIntents
import Foundation

/// "Hey Siri, pin that in Passing" → saves the pin → "What did you see?" → "a red barn".
/// The pin is saved before Siri asks, so ignoring or cancelling the question keeps it.
struct CapturePinIntent: AppIntent {
    static let title: LocalizedStringResource = "Pin That"
    static let description = IntentDescription("Saves where you are right now, then asks what you saw. The pin is saved first, so it's kept even if you don't answer.")

    @Parameter(title: "What you saw")
    var label: String?

    @Parameter(title: "Side of the road")
    var side: Side?

    @Parameter(title: "Distance from the road")
    var distance: Distance?

    @Parameter(title: "Miles back")
    var milesBack: Int?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pin = await IntentCapture.run(
            service: .shared,
            source: .siri,
            side: side ?? .unknown,
            distance: distance ?? .unknown,
            milesBack: min(max(milesBack ?? 0, 0), 25),
            label: label,
            ask: true
        ) {
            try await $label.requestValue("What did you see?")
        }
        return .result(dialog: "\(IntentCapture.dialog(for: pin))")
    }
}

/// "Hey Siri, I missed something in Passing" → a pin 1 mile back along the road → "What did you see?"
struct PinMilesBackIntent: AppIntent {
    static let title: LocalizedStringResource = "Pin Something I Passed"
    static let description = IntentDescription("Saves a pin a mile (or more) back along the road you just drove, then asks what you saw.")

    @Parameter(title: "Miles back", default: 1)
    var miles: Int

    @Parameter(title: "What you saw")
    var label: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pin = await IntentCapture.run(
            service: .shared,
            source: .siri,
            milesBack: min(max(miles, 1), 25),
            label: label,
            ask: true
        ) {
            try await $label.requestValue("What did you see?")
        }
        return .result(dialog: "\(IntentCapture.dialog(for: pin))")
    }
}

/// Saves a pin and asks nothing. For the Action Button, Back Tap and the Shortcuts app, where a
/// question would pop up on screen and need typing.
struct QuickPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Pin"
    static let description = IntentDescription("Saves where you are right now without asking anything. Made for the Action Button and Back Tap.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pin = await IntentCapture.run(service: .shared, source: .actionButton, ask: false) { nil }
        return .result(dialog: "\(IntentCapture.dialog(for: pin))")
    }
}

/// Phrases must include the app name. They work from CarPlay's voice button, AirPods and "Hey Siri".
struct PassingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CapturePinIntent(),
            phrases: [
                "Pin that in \(.applicationName)",
                "Pin this in \(.applicationName)",
                "Mark that in \(.applicationName)",
                "Mark this in \(.applicationName)",
            ],
            shortTitle: "Pin That",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: PinMilesBackIntent(),
            phrases: [
                "I missed something in \(.applicationName)",
                "Pin that a mile back in \(.applicationName)",
            ],
            shortTitle: "Pin a Mile Back",
            systemImageName: "arrow.uturn.backward"
        )
        AppShortcut(
            intent: QuickPinIntent(),
            phrases: [
                "Quick pin in \(.applicationName)",
            ],
            shortTitle: "Quick Pin",
            systemImageName: "mappin"
        )
    }
}
