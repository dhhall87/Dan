import CoreLocation
import Foundation
import SwiftData

/// The single entry point that saves a pin. The phone screen, Siri, the Action Button, the widget,
/// Control Center and pins from Apple Watch all go through it. Never duplicate save logic.
///
/// Save first: the pin is written synchronously before anything else happens. It never waits on
/// the network, never asks a question, and never substitutes an old coordinate.
///
/// `CaptureService.shared` is defined once per target, because the app and the widget extension
/// wire it up differently: see `CaptureService+App.swift` and `CaptureService+Widget.swift`.
@MainActor
final class CaptureService {
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
    /// Pins whose first save hasn't succeeded yet. Any later successful save writes them too.
    private var unsavedPinIDs: Set<UUID> = []
    /// Pins that are on disk, but whose later change (a label, a late GPS fix, a bump) isn't yet.
    private var unsavedChangeIDs: Set<UUID> = []
    private var debouncer = TapDebouncer<String>(interval: 0.75)
    /// The pin just dropped on the capture screen, which "+1 mi back" moves, with the trail and the
    /// car's exact position as they were at that tap (in memory only, even with precise location off).
    private var recent: (pin: Pin, trail: BreadcrumbBuffer, start: TrailPoint?, window: MilesBackWindow)?
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

    enum SaveState: Equatable {
        /// The pin and every change to it are on disk.
        case saved
        /// The pin is on disk, but a later change (its label, a late GPS fix) isn't yet.
        case changesPending
        /// The pin itself isn't on disk yet.
        case notSaved
    }

    /// Success feedback (the tone, Siri's "Saved", the widget's green tick) depends on this, never
    /// just on the pin existing in memory. Unsaved pins and changes stay in memory, and the next
    /// save that works writes them too, so nothing is dropped.
    func saveState(of pin: Pin) -> SaveState {
        if unsavedPinIDs.contains(pin.id) { return .notSaved }
        if unsavedChangeIDs.contains(pin.id) { return .changesPending }
        return .saved
    }

    /// Whether the pin and all its changes are on disk.
    func isSaved(_ pin: Pin) -> Bool {
        saveState(of: pin) == .saved
    }

    /// Tries the write again, for an intent that's about to report back. True if everything is saved.
    @discardableResult
    func retrySave() -> Bool {
        (unsavedPinIDs.isEmpty && unsavedChangeIDs.isEmpty) || persist()
    }

    /// Takes back a pin whose first save failed, so it isn't written later. For a typed note, whose
    /// text stays in the New Note box to try again: otherwise the retry would save it twice.
    func discardUnsaved(_ pin: Pin) {
        guard pin.modelContext != nil, !pin.isDeleted, unsavedPinIDs.contains(pin.id) else { return }
        unsavedPinIDs.remove(pin.id)
        context.delete(pin)
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
        let pin = Pin(capturedAt: now, side: side, distance: distance, source: source)
        pin.label = label
        guard source == .app else {
            save(newPin: pin)
            return pin
        }
        // Snapshot the trail now, so "+1" measures back from where this pin was dropped, not from
        // wherever the car is by then.
        let snapshot = trail()
        var start: TrailPoint?
        save(newPin: pin) { start = $0.captureTrailPoint }
        recent = (pin, snapshot, start, MilesBackWindow(pinnedAt: now))
        return pin
    }

    /// When "+1 mi back" stops applying to the pin just dropped on the capture screen, or nil if
    /// there's no such pin (none yet, too long ago, or deleted). The button is dimmed meanwhile.
    func milesBackClosesAt(now: Date = .now) -> Date? {
        guard let current = recent, current.window.isOpen(at: now),
              current.pin.modelContext != nil, !current.pin.isDeleted, current.pin.deletedAt == nil
        else { return nil }
        return current.window.closesAt
    }

    /// The capture screen's "+1 mi back": moves the pin just dropped a mile further back along the
    /// road driven, measured from where it was dropped (`MilesBackWindow`: within about 10 s of the
    /// pin, then within about 5 s of each "+1"). It keeps its side and distance, and every tap
    /// confirms with the haptic and tone (and "2 miles back" if spoken confirmation is on).
    ///
    /// - Returns: the pin, or nil when there's no pin just dropped to move, so the caller can say so
    ///   with a different haptic. It never makes a pin of its own.
    @discardableResult
    func milesBackTap(now: Date = .now) -> Pin? {
        guard milesBackClosesAt(now: now) != nil, let current = recent else {
            var entry = DriveLogEntry(at: .now, kind: .bump, source: CaptureSource.app.rawValue, outcome: "noPin")
            // How long after the last pin, to tune the window (nothing is read from the pin itself).
            entry.seconds = recent.map { now.timeIntervalSince($0.window.pinnedAt) }
            DriveLog.record(entry)
            return nil
        }
        let pin = current.pin
        pin.milesBack += 1
        // A pin dropped before GPS was ready may have its position by now.
        estimateTarget(for: pin, from: current.start ?? pin.captureTrailPoint, along: current.trail)
        if !isPrecise() {
            pin.coarsenLocation()
        }
        recent?.window.bumped(at: now)
        let saved = persistChange(to: pin)
        if saved {
            confirm(pin)
        } else {
            failed(pin)
        }
        var entry = DriveLogEntry(at: .now, kind: .bump, source: pin.source.rawValue, outcome: pin.targetSource.rawValue, saved: saved, miles: pin.milesBack)
        entry.trailMiles = current.trail.length / Geo.metersPerMile
        entry.seconds = now.timeIntervalSince(current.window.pinnedAt)
        DriveLog.record(entry)
        return pin
    }

    /// Siri and Shortcuts ("pin that 2 miles back"): saves a new pin `miles` back along the road
    /// just driven. The capture screen's "+1 mi back" moves a pin instead (`milesBackTap`).
    @discardableResult
    func captureMilesBack(source: CaptureSource, miles: Double = 1, now: Date = .now) -> Pin {
        let pin = Pin(capturedAt: now, side: .unknown, distance: .unknown, source: source)
        pin.milesBack = max(miles, 1)
        let snapshot = trail()
        save(newPin: pin, trailMeters: snapshot.length) { pin in
            self.estimateTarget(for: pin, from: pin.captureTrailPoint, along: snapshot)
        }
        return pin
    }

    /// A pin made on Apple Watch, arriving through `WatchLink`, often a while after the tap. It keeps
    /// the watch's own GPS reading, or no location if the watch had none: never the iPhone's position,
    /// which may be somewhere else by now. A pin that arrives twice is saved once.
    ///
    /// `byMessage` says it came as a message (sent straight away) rather than a queued transfer,
    /// for the drive log.
    ///
    /// - Returns: whether the pin is on disk, so the watch only lets go of pins that are saved here.
    @discardableResult
    func saveWatchPin(_ watchPin: WatchPin, now: Date = .now, byMessage: Bool = false) -> Bool {
        if let existing = storedPin(id: watchPin.id) {
            // Sent again before the watch heard back. Already here: just make sure it's written.
            return saveState(of: existing) != .notSaved || persist()
        }
        let pin = Pin(capturedAt: watchPin.capturedAt, side: watchPin.side, distance: watchPin.distance, source: .watch)
        pin.id = watchPin.id
        var fix: CLLocation?
        if let reading = watchPin.fix,
           reading.horizontalAccuracy >= 0, reading.horizontalAccuracy <= FixPolicy.maxAccuracy,
           FixPolicy.acceptsLateFix(capturedAt: watchPin.capturedAt, fixTimestamp: reading.timestamp) {
            fix = CLLocation(reading)
        }
        save(newPin: pin, fix: .supplied(fix), fromWatch: (watchPin, now, byMessage))
        return saveState(of: pin) != .notSaved
    }

    /// How many pins are in Needs Review: active widget, Control Center and Apple Watch pins not
    /// marked Reviewed.
    func needsReviewCount() -> Int {
        let widget = CaptureSource.widget.rawValue
        let control = CaptureSource.control.rawValue
        let watch = CaptureSource.watch.rawValue
        let descriptor = FetchDescriptor<Pin>(predicate: #Predicate {
            $0.deletedAt == nil && !$0.isReviewed && ($0.sourceRaw == widget || $0.sourceRaw == control || $0.sourceRaw == watch)
        })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// The newest Apple Watch pins on disk here, oldest first, Recently Deleted included: the ones
    /// the watch can let go of. Read from the database rather than from answers sent, so pins that
    /// arrived before an answer could get back to the watch are covered too.
    func savedWatchPinIDs(limit: Int = WatchMessage.savedLimit) -> [UUID] {
        let watch = CaptureSource.watch.rawValue
        var descriptor = FetchDescriptor<Pin>(
            predicate: #Predicate { $0.sourceRaw == watch },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let pins = (try? context.fetch(descriptor)) ?? []
        return Array(pins.map(\.id).filter { !unsavedPinIDs.contains($0) }.reversed())
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
        // Still in the store first: reading a pin that was deleted for good crashes.
        guard note.modelContext != nil, !note.isDeleted, note.isNote, note.label?.isEmpty ?? true else { return }
        unsavedPinIDs.remove(note.id)
        unsavedChangeIDs.remove(note.id)
        context.delete(note)
        persist()
    }

    /// Adds or replaces a pin's label (e.g. Siri's answer to "What did you see?").
    /// - Returns: whether the label is on disk, so nothing reads back a label that isn't saved.
    @discardableResult
    func setLabel(_ label: String?, on pin: Pin) -> Bool {
        guard pin.modelContext != nil, !pin.isDeleted else { return false }
        pin.label = label
        return persistChange(to: pin)
    }

    /// Waits until a pin that was saved without a location has picked one up or given up.
    /// Siri waits on this so iOS doesn't suspend Passing before the fix arrives.
    func waitForLocation(of pin: Pin) async {
        await lateFixTasks[pin.id]?.value
    }

    /// For a pin saved before any usable fix: attach the first usable fix that arrives within
    /// `FixPolicy.lateFixWindow`. If none arrives, the pin stays saved with no location.
    func attachLateFix(to pin: Pin) async {
        await attachLateFix(to: pin, source: pin.source, capturedAt: pin.capturedAt)
    }

    /// `source` and `capturedAt` are read before the wait, because afterwards the pin may be gone
    /// (deleted, or in tests its whole store closed), and reading a gone pin crashes. After the wait
    /// nothing is read from the pin until it's known to still be in the store.
    private func attachLateFix(to pin: Pin, source: CaptureSource, capturedAt: Date) async {
        let fix = await lateFix()
        var entry = DriveLogEntry(at: .now, kind: .lateFix, source: source.rawValue)
        // From the tap until the fix arrived, or until the wait gave up.
        entry.seconds = Date.now.timeIntervalSince(capturedAt)
        defer { DriveLog.record(entry) }

        guard let fix else {
            entry.outcome = "none"
            return
        }
        guard pin.modelContext != nil, !pin.isDeleted, !pin.hasLocation else {
            entry.outcome = "pinChanged"
            return
        }
        guard FixPolicy.acceptsLateFix(capturedAt: capturedAt, fixTimestamp: fix.timestamp) else {
            entry.outcome = "tooLate"
            return
        }
        pin.applyFix(fix)
        if !isPrecise() {
            pin.coarsenLocation()
        }
        entry.saved = persistChange(to: pin)
        entry.outcome = "attached"
        entry.add(fixOf: pin)
    }

    // MARK: Private

    /// Where a new pin's position comes from.
    private enum FixSource {
        /// The iPhone's GPS: the current fix if it's fresh, otherwise the first usable one to arrive
        /// within `FixPolicy.lateFixWindow`.
        case phone
        /// A reading taken elsewhere (Apple Watch), or none. Never replaced by the iPhone's position.
        case supplied(CLLocation?)
    }

    /// Stamps the fix, runs `prepare`, saves, confirms, and waits for a late fix if needed.
    /// `fromWatch` is a watch pin as it arrived, whose trip goes in the drive log.
    private func save(newPin pin: Pin, fix fixSource: FixSource = .phone, trailMeters: Double? = nil, fromWatch: (pin: WatchPin, arrivedAt: Date, byMessage: Bool)? = nil, prepare: (Pin) -> Void = { _ in }) {
        switch fixSource {
        case .phone:
            if let fix = currentFix() {
                pin.applyFix(fix)
            }
        case .supplied(let fix):
            if let fix {
                pin.applyFix(fix)
            }
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
        var entry = DriveLogEntry.capture(pin, saved: saved, trailMeters: trailMeters)
        if let fromWatch {
            entry.add(watchTrip: fromWatch.pin, arrivedAt: fromWatch.arrivedAt, byMessage: fromWatch.byMessage)
        }
        DriveLog.record(entry)

        guard case .phone = fixSource else { return }
        if !pin.hasLocation {
            // Read now, while the pin is certainly there; the task runs later.
            let id = pin.id
            let source = pin.source
            let capturedAt = pin.capturedAt
            lateFixTasks[id] = Task {
                await self.attachLateFix(to: pin, source: source, capturedAt: capturedAt)
                self.lateFixTasks[id] = nil
            }
        }
    }

    /// Walks back `pin.milesBack` miles from where the car was. Keeps the car's position and the
    /// estimate separate, and never claims a target the trail can't support.
    private func estimateTarget(for pin: Pin, from start: TrailPoint?, along trail: BreadcrumbBuffer) {
        // The direction of travel at the tap, for when there's too little trail to follow.
        let heading = pin.courseReliable ? pin.course : nil
        if let start, let estimate = trail.estimateBack(from: start, meters: pin.milesBack * Geo.metersPerMile, heading: heading) {
            pin.targetLatitude = estimate.target.latitude
            pin.targetLongitude = estimate.target.longitude
            pin.targetSource = estimate.straightMeters > 0 ? .heading : .breadcrumb
            pin.trail = estimate.segment.count > 1 ? TrailCoding.encode(estimate.segment) : nil
        } else {
            // No location, or no trail and no direction of travel (stopped): describe it in words instead.
            pin.targetLatitude = nil
            pin.targetLongitude = nil
            pin.targetSource = .textOnly
            pin.trail = nil
        }
    }

    /// The pin with this id, wherever it is (Pins or Recently Deleted), including one not yet written.
    private func storedPin(id: UUID) -> Pin? {
        var descriptor = FetchDescriptor<Pin>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Saves a change to a pin that may already be on disk. If the write fails, the pin is marked as
    /// having a change pending (or stays marked unsaved, if its first save never worked).
    private func persistChange(to pin: Pin) -> Bool {
        let saved = persist()
        if !saved, !unsavedPinIDs.contains(pin.id) {
            unsavedChangeIDs.insert(pin.id)
        }
        return saved
    }

    /// Saves everything pending. A success also covers any pin or change whose save failed earlier.
    @discardableResult
    private func persist() -> Bool {
        do {
            try persistStore(context)
            unsavedPinIDs.removeAll()
            unsavedChangeIDs.removeAll()
            return true
        } catch {
            print("Passing: save failed: \(error)")
            DriveLog.record(DriveLogEntry(at: .now, kind: .saveFailed, outcome: "\(type(of: error))"))
            return false
        }
    }
}

private extension CLLocation {
    /// A reading taken on Apple Watch, so `Pin.applyFix` can stamp it like any other.
    convenience init(_ fix: WatchFix) {
        self.init(
            coordinate: CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude),
            altitude: 0,
            horizontalAccuracy: fix.horizontalAccuracy,
            verticalAccuracy: -1,
            course: fix.course,
            courseAccuracy: fix.courseAccuracy,
            speed: fix.speed,
            speedAccuracy: -1,
            timestamp: fix.timestamp
        )
    }
}
