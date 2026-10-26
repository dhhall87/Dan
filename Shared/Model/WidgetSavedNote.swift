import Foundation

/// The widget's short confirmation after a tap: a tick on the button that was tapped for a few
/// seconds, so a glance (never required) shows it worked. Widget captures make no sound.
struct WidgetSavedNote: Codable, Equatable {
    static let duration: TimeInterval = 5

    var savedAt: Date
    var side: Side
    var distance: Distance
    var hasLocation: Bool
    /// False when the pin couldn't be written to disk: the button shows "Not saved" instead of a tick.
    var saved: Bool = true

    var hidesAt: Date { savedAt.addingTimeInterval(Self.duration) }

    func isShowing(at now: Date) -> Bool {
        savedAt <= now && now < hidesAt
    }

    /// Whether this note belongs to the widget button that saves `side` and `distance`.
    func matches(side: Side, distance: Distance) -> Bool {
        self.side == side && self.distance == distance
    }

    /// Fits under the tick on a small button.
    var shortMessage: String {
        if !saved { return "Not saved" }
        return hasLocation ? "Saved" : "No location"
    }
}
