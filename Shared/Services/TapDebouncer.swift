import Foundation

/// Ignores a repeat tap on the same target that comes too soon after the last accepted one,
/// so a bump in the road doesn't drop two pins.
struct TapDebouncer<Key: Hashable> {
    var interval: TimeInterval = 0.75
    private var lastAccepted: [Key: Date] = [:]

    init(interval: TimeInterval = 0.75) {
        self.interval = interval
    }

    mutating func shouldAccept(_ key: Key, at now: Date) -> Bool {
        if let last = lastAccepted[key], now.timeIntervalSince(last) < interval {
            return false
        }
        lastAccepted[key] = now
        return true
    }
}
