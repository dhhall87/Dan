import Foundation

/// Which capture layout is showing. Settings picks the one Passing opens with; tapping the title
/// switches between Simple and Four zones for the drive. Coming back after a long break counts as
/// opening Passing again, so the next drive starts on the Settings layout.
struct CaptureModeChoice: Equatable {
    /// Away longer than this and Passing comes back on the Settings layout.
    static let resetAfter: TimeInterval = 30 * 60

    /// The title button's choice, or nil for the Settings layout.
    private(set) var switchedTo: CaptureMode?
    private var leftAt: Date?

    func mode(default defaultMode: CaptureMode) -> CaptureMode {
        switchedTo ?? defaultMode
    }

    /// The title button: flip to the other layout.
    mutating func toggle(default defaultMode: CaptureMode) {
        let next: CaptureMode = mode(default: defaultMode) == .quick ? .fourZone : .quick
        switchedTo = next == defaultMode ? nil : next
    }

    /// A new choice in Settings shows straight away.
    mutating func defaultChanged() {
        switchedTo = nil
    }

    mutating func wentToBackground(at date: Date) {
        leftAt = date
    }

    mutating func cameBack(at date: Date) {
        if let leftAt, date.timeIntervalSince(leftAt) > Self.resetAfter {
            switchedTo = nil
        }
        leftAt = nil
    }
}
