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
        if let pin {
            WidgetActivity.record(pin)
        }
        // Returning makes WidgetKit reload the widget, which then shows the "Saved" tick.
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
            WidgetActivity.record(pin)
        }
        return .result()
    }
}
