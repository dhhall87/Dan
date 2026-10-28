import AppIntents
import Foundation

/// A widget button: saves a pin with the button's side and distance and asks nothing.
/// Runs in the widget extension, without opening the app, including from CarPlay.
/// Hidden from Shortcuts and Siri, which have their own intents.
struct WidgetPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Pin from Widget"
    static let description = IntentDescription("Saves where you are right now. Used by the Passing widgets.")
    static let isDiscoverable = false

    @Parameter(title: "Side of the road", default: .unknown)
    var side: Side

    @Parameter(title: "Distance from the road", default: .unknown)
    var distance: Distance

    init() {}

    init(side: Side, distance: Distance) {
        self.side = side
        self.distance = distance
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let pin = await IntentCapture.run(service: .shared, source: .widget, side: side, distance: distance, ask: false) { nil }
        guard let pin else { return .result() }
        let state = CaptureService.shared.saveState(of: pin)
        let note = WidgetActivity.record(pin, state: state)
        if note?.isProblem == false {
            // Keeps the green "Saved" up a moment. Returning makes WidgetKit redraw, and that redraw
            // always shows (in CarPlay too), so the plain buttons come back without a later reload.
            try? await Task.sleep(for: .seconds(WidgetSavedNote.successHold))
        }
        return .result()
    }
}

/// The widgets' Stop button, shown while the app is listening for a label after a tap: turns the
/// microphone off now instead of waiting for listening to time out. Works from CarPlay too.
struct StopListeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Listening"
    static let description = IntentDescription("Stops Passing listening for a label. Used by the Passing widgets.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        ListeningSignal.postStop()
        ListeningSignal.setListening(false)
        return .result()
    }
}

/// The Control Center button (also usable on the Lock Screen and the Action Button).
/// Saves a pin and asks nothing.
struct ControlPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Pin from Control Center"
    static let description = IntentDescription("Saves where you are right now. Used by the Passing control.")
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let pin = await IntentCapture.run(service: .shared, source: .control, ask: false) { nil }
        if let pin {
            WidgetActivity.record(pin, state: CaptureService.shared.saveState(of: pin))
        }
        return .result()
    }
}
