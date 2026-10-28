import Foundation

/// A pin made on Apple Watch, as it travels to the iPhone. Plain values, so the watch can keep its
/// pins in a small file until the iPhone has them, and the rules are easy to unit test.
struct WatchPin: Codable, Equatable, Identifiable {
    /// Also the pin's id on the iPhone, so a pin that arrives twice is saved once.
    var id: UUID
    /// When the button was tapped.
    var capturedAt: Date
    var side: Side
    var distance: Distance
    /// The watch's own GPS reading. Nil if none was usable in time; the iPhone never fills in its own.
    var fix: WatchFix?
}

/// A GPS reading taken on the watch, with Core Location's raw values (negative means unknown).
struct WatchFix: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// Meters.
    var horizontalAccuracy: Double
    var timestamp: Date
    /// Meters per second.
    var speed: Double
    /// Degrees from north.
    var course: Double
    var courseAccuracy: Double

    /// Whether the reading may go on a pin tapped now: fresh and accurate enough (`FixPolicy`).
    func isUsable(now: Date) -> Bool {
        latitude.isFinite && longitude.isFinite
            && FixPolicy.isUsable(fixTimestamp: timestamp, horizontalAccuracy: horizontalAccuracy, now: now)
    }
}

/// The dictionaries the watch and the iPhone send each other with WatchConnectivity's
/// `transferUserInfo`, which queues them, delivers them in order, and keeps going while either app
/// is closed. Only property-list values are allowed, so a pin travels as JSON data.
enum WatchMessage {
    /// Watch → iPhone: one pin.
    static let pinKey = "pin"
    /// iPhone → watch: pins now saved on the iPhone, so the watch can let them go.
    static let savedKey = "savedPinIDs"

    static func userInfo(for pin: WatchPin) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(pin) else { return nil }
        return [pinKey: data]
    }

    static func pin(from userInfo: [String: Any]) -> WatchPin? {
        guard let data = userInfo[pinKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchPin.self, from: data)
    }

    static func userInfo(saved ids: [UUID]) -> [String: Any] {
        [savedKey: ids.map(\.uuidString)]
    }

    static func savedIDs(from userInfo: [String: Any]) -> [UUID] {
        (userInfo[savedKey] as? [String] ?? []).compactMap(UUID.init(uuidString:))
    }

    /// The newest `limit` saved ids, oldest first, with `new` added. The iPhone keeps these in its
    /// application context as well as answering each pin, because the watch reads that context
    /// every time Passing starts there, so an answer that's slow or lost still gets through.
    static func recentlySaved(_ existing: [UUID], adding new: [UUID], limit: Int = 100) -> [UUID] {
        var ids = existing.filter { !new.contains($0) } + new
        if ids.count > limit {
            ids.removeFirst(ids.count - limit)
        }
        return ids
    }
}
