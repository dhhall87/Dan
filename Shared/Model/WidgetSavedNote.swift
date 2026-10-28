import Foundation

/// What the widget shows after a tap. Widget captures make no sound, so a glance (never required)
/// shows it worked. A good save is the green "Saved" across the whole widget while the button's work
/// runs, held `successHold` seconds, then the plain buttons again. Only a problem ("No location",
/// "Not saved") stays on the tapped button afterwards, for `duration` seconds.
///
/// Why: in CarPlay (Dan, October 2026, on both the Pin and the 2x2 widget) the redraw right after a
/// tap always shows, but the switch to a later entry, or a reload asked for seconds later, doesn't
/// happen until the widget is touched again, so a tick drawn after the tap stayed up.
struct WidgetSavedNote: Codable, Equatable {
    static let duration: TimeInterval = 5
    /// How long the green "Saved" stays up after a good save, before the buttons come back.
    static let successHold: TimeInterval = 1.5

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

    /// The pin isn't fully saved: it has no location, or it isn't on disk.
    var isProblem: Bool {
        !saved || !hasLocation
    }

    /// Whether the tapped button shows this after the redraw. Only problems do: a good save has
    /// already shown its green "Saved" while the button's work ran.
    func showsOnButton(at now: Date) -> Bool {
        isProblem && isShowing(at: now)
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
