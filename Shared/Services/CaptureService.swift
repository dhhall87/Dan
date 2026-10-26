import CoreLocation
import Foundation
import SwiftData

/// The single entry point that saves a pin. The phone screen, Siri, the Action Button, the widget
/// and Control Center all call it. Never duplicate save logic.
///
/// Save first: the pin is written synchronously before anything else happens. It never waits on
/// the network, never asks a question, and never substitutes an old coordinate.
///
/// `CaptureService.shared` is defined once per target, because the app and the widget extension
/// wire it up differently: see `CaptureService+App.swift` and `CaptureService+Widget.swift`.
@MainActor
final class CaptureService {
    /// Tapping "+1 mi back" again within this many seconds bumps the same pin another mile back.
    static let bumpWindow: TimeInterval = 4

    private let context: ModelContext
    private let currentFix: @MainActor () -> CLLocation?
    private let lateFix: @MainActor () async -> CLLocation?
    private let trail: @MainActor () -> BreadcrumbBuffer
    private let confirm: @MainActor (Pin) -> Void
    /// The "Precise location" setting. Off rounds each pin's position as it's saved.
    private let isPrecise: @MainActor () -> Bool
    /// Called after a pin that goes into Needs Review is saved, with how many are now waiting.
    private let reviewWaiting: @MainActor (Int) -> Void
    /// A tap in the app whose save failed: a different haptic, never the success tone.
    private let failed: @MainActor (Pin) -> Void
    /// Writes the context to disk. Injectable so tests can make it fail.
    private let persistStore: @MainActor (ModelContext) throws -> Void
    /// Pins whose save hasn't succeeded yet. Any later successful save writes them too.
    private var unsavedPinIDs: Set<UUID> = []
    private var debouncer = TapDebouncer<String>(interval: 0.75)
    /// The miles-back pin that further "+1" taps will bump, with the trail and the car's exact
    /// position as they were at the first tap (in memory only, even with precise location off).
    private var bump: (pin: Pin, trail: BreadcrumbBuffer, lastTap: Date, start: TrailPoint?)?
    /// Pins still waiting for their first usable fix, so Siri can wait for them before finishing.
    private var lateFixTasks: [UUID: Task<Void, Never>] = [:]

    /// The dependencies are injectable so tests can use an in-memory store, fake GPS and a fake trail.
    init(
        context: ModelContext,
        currentFix: @escaping @MainActor () -> CLLocation?,
        lateFix: @escaping @MainActor () async -> CLLocation?,
        trail: @escaping @MainActor () -> BreadcrumbBuffer,
        confirm: @escaping @MainActor (Pin) -> Void,
        isPrecise: @escaping @MainActor () -> Bool = { true },
        reviewWaiting: @escaping @MainActor (Int) -> Void = { _ in },
        failed: @escaping @MainActor (Pin) -> Void = { _ in },
        persist: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.currentFix = currentFix
        self.lateFix = lateFix
        self.trail = trail
        self.confirm = confirm
        self.isPrecise = isPrecise
        self.reviewWaiting = reviewWaiting
        self.failed = failed
        self.persistStore = persist
    }

    /// Whether this pin has been written to disk. Success feedback (the tone, Siri's "Saved", the
    /// widget's green tick) depends on this, never just on the pin existing in memory.
    func isSaved(_ pin: Pin) -> Bool {
        !unsavedPinIDs.contains(pin.id)
    }

    /// Tries the write again, for an intent that's about to report back. True if everything is saved.
    @discardableResult
    func retrySave() -> Bool {
        unsavedPinIDs.isEmpty || persist()
    }

    /// Saves a pin now. Taps in the app get the haptic and tone; Siri and shortcuts confirm out loud
    /// themselves, and widget and Control Center captures are silent.
    ///
    /// - Returns: the saved pin, or nil if this was a repeat tap on the same button within 0.75 s.
    @discardableResult
    func capture(side: Side, distance: Distance, source: CaptureSource, label: String? = nil, now: Date = .now) -> Pin? {
        if source.isTap {
            guard debouncer.shouldAccept("\(source.rawValue)-\(side.rawValue)-\(distance.rawValue)", at: now) else {
                return nil
            }
        }
        if source == .app {
            bump = nil
        }

        let pin = Pin(capturedAt: now, side: side, distance: distance, source: source)
        pin.label = label
        save(newPin: pin)
        return pin
    }

    /// "+1 mi back": saves a pin `miles` back along the road just driven. In the app, tapping again
    /// within `bumpWindow` seconds moves that same pin to 2 miles, 3 miles, and so on, and every tap
    /// confirms with the haptic and tone (and "2 miles back" if spoken confirmation is on).
    @discardableResult
    func captureMilesBack(source: CaptureSource, miles: Double = 1, now: Date = .now) -> Pin {
        if source == .app, let current = bump,
           now.timeIntervalSince(current.lastTap) <= Self.bumpWindow,
           current.pin.modelContext != nil, !current.pin.isDeleted, current.pin.deletedAt == nil {
            let pin = current.pin
            pin.milesBack += 1
            estimateTarget(for: pin, from: current.start ?? pin.captureTrailPoint, along: current.trail)
            if !isPrecise() {
                pin.coarsenLocation()
            }
            bump?.lastTap = now
            let saved = persist()
            if saved {
                confirm(pin)
            } else {
                unsavedPinIDs.insert(pin.id)
                failed(pin)
            }
            var entry = DriveLogEntry(at: .now, kind: .bump, source: pin.source.rawValue, outcome: pin.targetSource.rawValue, saved: saved, miles: pin.milesBack)
            entry.trailMiles = current.trail.length / Geo.metersPerMile
            DriveLog.record(entry)
            return pin
        }

        let pin = Pin(capturedAt: now, side: .unknown, distance: .unknown, source: source)
        pin.milesBack = max(miles, 1)
        // Snapshot the trail now, so later bumps measure back from this tap, not from wherever the car is by then.
        let snapshot = trail()
        var start: TrailPoint?
        save(newPin: pin, trailMeters: snapshot.length) { pin in
            start = pin.captureTrailPoint
            self.estimateTarget(for: pin, from: start, along: snapshot)
        }
        if source == .app {
            bump = (pin, snapshot, now, start)
        }
        return pin
    }

    /// How many pins are in Needs Review: active widget and Control Center pins not marked Reviewed.
    func needsReviewCount() -> Int {
        let widget = CaptureSource.widget.rawValue
        let control = CaptureSource.control.rawValue
        let descriptor = FetchDescriptor<Pin>(predicate: #Predicate {
            $0.deletedAt == nil && !$0.isReviewed && ($0.sourceRaw == widget || $0.sourceRaw == control)
        })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Saves a note: text only, no location and no GPS. It shows in Pins by day like a pin, and
    /// expires, can be kept, grouped and deleted the same way.
    @discardableResult
    func addNote(_ text: String?, source: CaptureSource = .app, now: Date = .now) -> Pin {
        let note = Pin(capturedAt: now, side: .unknown, distance: .unknown, source: source)
        note.isNote = true
        note.label = text
        context.insert(note)
        if !persist() {
            unsavedPinIDs.insert(note.id)
        }
        return note
    }

    /// Removes a spoken note that ended up with nothing said, so no empty notes pile up.
    func discardEmptyNote(_ note: Pin) {
        guard note.isNote, note.label?.isEmpty ?? true, note.modelContext != nil else { return }
        context.delete(note)
        persist()
    }

    /// Adds or replaces a pin's label (e.g. Siri's answer to "What did you see?").
    func setLabel(_ label: String?, on pin: Pin) {
        guard pin.modelContext != nil, !pin.isDeleted else { return }
        pin.label = label
        persist()
    }

    /// Waits until a pin that was saved without a location has picked one up or given up.
    /// Siri waits on this so iOS doesn't suspend Passing before the fix arrives.
    func waitForLocation(of pin: Pin) async {
        await lateFixTasks[pin.id]?.value
    }

    /// For a pin saved before any usable fix: attach the first usable fix that arrives within
    /// `FixPolicy.lateFixWindow`. If none arrives, the pin stays saved with no location.
    func attachLateFix(to pin: Pin) async {
        let fix = await lateFix()
        var entry = DriveLogEntry(at: .now, kind: .lateFix, source: pin.source.rawValue)
        // From the tap until the fix arrived, or until the wait gave up.
        entry.seconds = Date.now.timeIntervalSince(pin.capturedAt)
        defer { DriveLog.record(entry) }

        guard let fix else {
            entry.outcome = "none"
            return
        }
        guard pin.modelContext != nil, !pin.isDeleted, !pin.hasLocation else {
            entry.outcome = "pinChanged"
            return
        }
        guard FixPolicy.acceptsLateFix(capturedAt: pin.capturedAt, fixTimestamp: fix.timestamp) else {
            entry.outcome = "tooLate"
            return
        }
        pin.applyFix(fix)
        if !isPrecise() {
            pin.coarsenLocation()
        }
        entry.saved = persist()
        entry.outcome = "attached"
        entry.add(fixOf: pin)
    }

    // MARK: Private

    /// Stamps the current fix (if fresh), runs `prepare`, saves, confirms, and waits for a late fix if needed.
    private func save(newPin pin: Pin, trailMeters: Double? = nil, prepare: (Pin) -> Void = { _ in }) {
        if let fix = currentFix() {
            pin.applyFix(fix)
        }
        prepare(pin)
        if !isPrecise() {
            pin.coarsenLocation()
        }
        context.insert(pin)
        let saved = persist()
        if !saved {
            // Kept in memory so a later save (autosave, the late GPS fix, a retry) can still write it.
            unsavedPinIDs.insert(pin.id)
        }
        if pin.source == .app {
            if saved {
                confirm(pin)
            } else {
                failed(pin)
            }
        }
        if pin.needsReview {
            reviewWaiting(needsReviewCount())
        }
        // After the feedback, so logging never delays it.
        DriveLog.record(.capture(pin, saved: saved, trailMeters: trailMeters))

        if !pin.hasLocation {
            let id = pin.id
            lateFixTasks[id] = Task {
                await self.attachLateFix(to: pin)
                self.lateFixTasks[id] = nil
            }
        }
    }

    /// Walks back `pin.milesBack` miles from where the car was. Keeps the car's position and the
    /// estimate separate, and never claims a target the trail can't support.
    private func estimateTarget(for pin: Pin, from start: TrailPoint?, along trail: BreadcrumbBuffer) {
        if let start, let walk = trail.walkBack(from: start, meters: pin.milesBack * Geo.metersPerMile) {
            pin.targetLatitude = walk.target.latitude
            pin.targetLongitude = walk.target.longitude
            pin.targetSource = .breadcrumb
            pin.trail = TrailCoding.encode(walk.segment)
        } else {
            // Not enough trail (app just opened, or no location): describe it in words instead.
            pin.targetLatitude = nil
            pin.targetLongitude = nil
            pin.targetSource = .textOnly
            pin.trail = nil
        }
    }

    /// Saves everything pending. A success also covers any pin whose own save failed earlier.
    @discardableResult
    private func persist() -> Bool {
        do {
            try persistStore(context)
            unsavedPinIDs.removeAll()
            return true
        } catch {
            print("Passing: save failed: \(error)")
            DriveLog.record(DriveLogEntry(at: .now, kind: .saveFailed, outcome: "\(type(of: error))"))
            return false
        }
    }
}
