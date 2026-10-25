import Foundation

/// The retention rules as plain values and functions, so they're easy to unit test.
/// Everything uses absolute time intervals, never calendar days, so time zones and daylight
/// saving can't move the boundaries.
enum RetentionPolicy {
    static let day: TimeInterval = 24 * 60 * 60
    /// Active pins move to Recently Deleted this long after they were captured.
    static let activeLifetime: TimeInterval = 7 * day
    /// Pins in Recently Deleted are removed for good this long after they arrived there.
    static let recentlyDeletedLifetime: TimeInterval = 30 * day

    static func expiryDate(capturedAt: Date) -> Date {
        capturedAt.addingTimeInterval(activeLifetime)
    }

    static func purgeDate(deletedAt: Date) -> Date {
        deletedAt.addingTimeInterval(recentlyDeletedLifetime)
    }

    /// Whether an active pin should move to Recently Deleted. Exactly 7 days old counts as expired.
    static func shouldExpire(capturedAt: Date, isKept: Bool, keepIndefinitely: Bool, now: Date) -> Bool {
        !isKept && !keepIndefinitely && now >= expiryDate(capturedAt: capturedAt)
    }

    /// Whether a pin in Recently Deleted should be removed for good. "Keep records indefinitely"
    /// doesn't affect this. Exactly 30 days counts as due.
    static func shouldPurge(deletedAt: Date, now: Date) -> Bool {
        now >= purgeDate(deletedAt: deletedAt)
    }

    /// Recovering a pin that's already past its 7 days would just expire it again on the next
    /// clean-up, so it's kept (starred) instead.
    static func keepOnRecover(capturedAt: Date, now: Date) -> Bool {
        now >= expiryDate(capturedAt: capturedAt)
    }

    /// Whole days left before `deadline`, rounded up: 6.2 days left reads as 7.
    static func daysLeft(until deadline: Date, now: Date) -> Int {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else { return 0 }
        return Int((remaining / day).rounded(.up))
    }

    /// "Expires in 3 days", "Expires in under a day", or nil when the pin won't expire.
    static func expiryText(capturedAt: Date, isKept: Bool, keepIndefinitely: Bool, now: Date) -> String? {
        guard !isKept, !keepIndefinitely else { return nil }
        return countdown("Expires", until: expiryDate(capturedAt: capturedAt), now: now)
    }

    /// "Deleted for good in 29 days" for a pin in Recently Deleted.
    static func purgeText(deletedAt: Date, now: Date) -> String {
        countdown("Deleted for good", until: purgeDate(deletedAt: deletedAt), now: now)
    }

    private static func countdown(_ prefix: String, until deadline: Date, now: Date) -> String {
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 0 { return "\(prefix) soon" }
        if remaining < day { return "\(prefix) in under a day" }
        let days = daysLeft(until: deadline, now: now)
        return "\(prefix) in \(days) \(days == 1 ? "day" : "days")"
    }
}
