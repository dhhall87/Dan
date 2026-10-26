import Foundation

/// The watch's pins until the iPhone says it has saved them, oldest first. Save first: a pin goes in
/// here the moment its button is tapped. It waits up to `FixPolicy.lateFixWindow` for the watch's
/// GPS, then it's sent. Nothing leaves until the iPhone confirms it's on disk, so a pin that's lost
/// on the way, or that arrived while the iPhone couldn't save it, is simply sent again.
/// Plain values, kept in a small file on the watch.
struct WatchOutbox: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var pin: WatchPin
        /// Still waiting for a GPS reading, so not sent yet.
        var waitingForFix: Bool
        /// When it reached the iPhone, which hasn't said it's saved yet (Passing there may not have
        /// run since). Not sent again until `resendAfter` has passed.
        var deliveredAt: Date?
    }

    /// A pin that reached the iPhone but was never confirmed is sent again after this long, the next
    /// time Passing starts on the watch. That covers a save that failed on the iPhone, without
    /// sending every waiting pin again on every tap.
    static let resendAfter: TimeInterval = 60 * 60

    private(set) var entries: [Entry] = []

    /// Pins the iPhone doesn't have yet.
    var count: Int { entries.count }

    var isWaitingForFix: Bool { entries.contains { $0.waitingForFix } }

    /// A pin just tapped. With no reading yet, it waits for one (if GPS can give one at all).
    mutating func add(_ pin: WatchPin, waitForFix: Bool) {
        guard !entries.contains(where: { $0.pin.id == pin.id }) else { return }
        entries.append(Entry(pin: pin, waitingForFix: waitForFix && pin.fix == nil))
    }

    /// Gives a reading to every pin still waiting that it suits: usable now, and taken no more than
    /// 10 s before the tap or 15 s after it (`FixPolicy.acceptsLateFix`). Returns those pins' ids.
    @discardableResult
    mutating func attach(_ fix: WatchFix, now: Date) -> [UUID] {
        guard fix.isUsable(now: now) else { return [] }
        var attached: [UUID] = []
        for index in entries.indices where entries[index].waitingForFix {
            guard FixPolicy.acceptsLateFix(capturedAt: entries[index].pin.capturedAt, fixTimestamp: fix.timestamp) else { continue }
            entries[index].pin.fix = fix
            entries[index].waitingForFix = false
            attached.append(entries[index].pin.id)
        }
        return attached
    }

    /// Stops waiting on pins whose GPS window has passed, or on all of them (the app is closing, so
    /// no reading can come): they go to the iPhone with no location rather than a late one.
    /// Returns those pins' ids.
    @discardableResult
    mutating func stopWaiting(now: Date, all: Bool = false) -> [UUID] {
        var stopped: [UUID] = []
        for index in entries.indices where entries[index].waitingForFix {
            let waited = now.timeIntervalSince(entries[index].pin.capturedAt)
            guard all || waited > FixPolicy.lateFixWindow else { continue }
            entries[index].waitingForFix = false
            stopped.append(entries[index].pin.id)
        }
        return stopped
    }

    /// Pins to send to the iPhone, oldest first: those done waiting for GPS that aren't already on
    /// their way. Pins it has received but not confirmed are included only when `resendingAt` is
    /// given (as Passing starts) and they reached it over `resendAfter` ago.
    func readyToSend(excluding inFlight: Set<UUID>, resendingAt now: Date? = nil) -> [WatchPin] {
        entries.filter { entry in
            guard !entry.waitingForFix, !inFlight.contains(entry.pin.id) else { return false }
            guard let deliveredAt = entry.deliveredAt else { return true }
            guard let now else { return false }
            return now.timeIntervalSince(deliveredAt) > Self.resendAfter
        }
        .map(\.pin)
    }

    /// The pin reached the iPhone, which will confirm once it's saved.
    mutating func markDelivered(_ id: UUID, at now: Date) {
        guard let index = entries.firstIndex(where: { $0.pin.id == id }) else { return }
        entries[index].deliveredAt = now
    }

    /// The iPhone has saved these: let them go.
    mutating func confirmSaved(_ ids: [UUID]) {
        let saved = Set(ids)
        entries.removeAll { saved.contains($0.pin.id) }
    }
}
