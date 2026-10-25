import Foundation

/// Rules for when a GPS fix is good enough to stamp on a pin.
/// Plain values and functions, kept free of Core Location so they're easy to unit test.
enum FixPolicy {
    /// A fix older than this is never used as the current position.
    static let maxAge: TimeInterval = 10
    /// Fixes less accurate than this (meters) are never used.
    static let maxAccuracy: Double = 200

    /// A pin is flagged approximate when its total uncertainty is more than this (meters): the fix's
    /// own accuracy combined with how far the car could have moved between the fix and the tap
    /// (speed × time apart). At 65 mph that's under 2 s; when parked, never.
    static let exactDrift: Double = 50
    /// When the fix has no speed, a fix more than this many seconds from the tap is flagged
    /// approximate instead (at highway speed, 3 s is ~90 m).
    static let exactAge: TimeInterval = 3
    /// Fixes less accurate than this (meters) are flagged approximate.
    static let exactAccuracy: Double = 50

    /// Below this speed (m/s, about 5 mph) the direction of travel is noise.
    static let minSpeedForCourse: Double = 2.5
    /// Course readings less certain than this (degrees) are treated as unreliable.
    static let maxCourseAccuracy: Double = 45

    /// A pin saved before any usable fix keeps waiting this long for one.
    static let lateFixWindow: TimeInterval = 15

    /// Whether a fix may be used as "where the car is right now".
    static func isUsable(fixTimestamp: Date, horizontalAccuracy: Double, now: Date) -> Bool {
        horizontalAccuracy >= 0
            && horizontalAccuracy <= maxAccuracy
            && abs(now.timeIntervalSince(fixTimestamp)) <= maxAge
    }

    /// Whether a fix that arrived after a pin was saved may be attached to it.
    static func acceptsLateFix(capturedAt: Date, fixTimestamp: Date) -> Bool {
        let offset = fixTimestamp.timeIntervalSince(capturedAt)
        return offset >= -maxAge && offset <= lateFixWindow
    }

    /// Whether the pin's position should be shown as approximate. The fix's own accuracy and the
    /// distance the car could have covered between the fix and the tap are separate errors, so they
    /// add up like the two short sides of a right triangle; more than `exactDrift` in total is
    /// approximate. `speed` is in m/s; nil or negative means unknown.
    static func isApproximate(capturedAt: Date, fixTimestamp: Date, horizontalAccuracy: Double, speed: Double?) -> Bool {
        if horizontalAccuracy > exactAccuracy { return true }
        let secondsApart = abs(fixTimestamp.timeIntervalSince(capturedAt))
        guard let speed, speed >= 0 else { return secondsApart > exactAge }
        let drift = speed * secondsApart
        return (horizontalAccuracy * horizontalAccuracy + drift * drift).squareRoot() > exactDrift
    }

    /// Whether the direction of travel means anything. `course`, `courseAccuracy` and `speed`
    /// are Core Location's raw values, where negative means invalid.
    static func isCourseReliable(course: Double, courseAccuracy: Double, speed: Double) -> Bool {
        guard course >= 0, speed >= minSpeedForCourse else { return false }
        // Some fixes (e.g. the Simulator's) report a valid course with no accuracy estimate.
        return courseAccuracy < 0 || courseAccuracy <= maxCourseAccuracy
    }
}
