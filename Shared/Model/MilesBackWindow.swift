import Foundation

/// When "+1 mi back" applies (Dan's rule, October 2026): it moves the pin just dropped on the capture
/// screen, so it only works within about 10 seconds of that pin, and again within about 5 seconds of
/// each "+1". Drop a pin, wait 6 s, tap "+1", wait 4 s, tap "+1" again: that pin ends up 2 miles back
/// from where it was dropped. Plain values, so the rule is easy to unit test.
struct MilesBackWindow: Equatable {
    /// The first "+1" must come this soon after the pin.
    static let afterPin: TimeInterval = 10
    /// Each further "+1" must come this soon after the one before (or still within `afterPin`).
    static let afterBump: TimeInterval = 5

    var pinnedAt: Date
    var lastBumpAt: Date?

    init(pinnedAt: Date) {
        self.pinnedAt = pinnedAt
    }

    /// The moment "+1" stops applying to this pin.
    var closesAt: Date {
        let afterPin = pinnedAt.addingTimeInterval(Self.afterPin)
        guard let lastBumpAt else { return afterPin }
        return max(afterPin, lastBumpAt.addingTimeInterval(Self.afterBump))
    }

    func isOpen(at now: Date) -> Bool {
        now <= closesAt
    }

    mutating func bumped(at now: Date) {
        lastBumpAt = now
    }
}
