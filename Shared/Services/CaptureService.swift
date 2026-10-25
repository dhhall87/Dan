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
    private var debouncer = TapDebouncer<String>(interval: 0.75)
    /// The miles-back pin that further "+1" taps will bump, with the trail as it was at the first tap.
    private var bump: (pin: Pin, trail: BreadcrumbBuffer, lastTap: Date)?
    /// Pins still waiting for their first usable fix, so Siri can wait for them before finishing.
    private var lateFixTasks: [UUID: Task<Void, Never>] = [:]

    /// The dependencies are injectable so tests can use an in-memory store, fake GPS and a fake trail.
    init(
        context: ModelContext,
        currentFix: @escaping @MainActor () -> CLLocation?,
        lateFix: @escaping @MainActor () async -> CLLocation?,
        trail: @escaping @MainActor () -> BreadcrumbBuffer,
        confirm: @escaping @MainActor (Pin) -> Void
    ) {
        self.context = context
        self.currentFix = currentFix
        self.lateFix = lateFix
        self.trail = trail
        self.confirm = confirm
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
            estimateTarget(for: pin, along: current.trail)
            bump?.lastTap = now
            persist()
            confirm(pin)
            return pin
        }

        let pin = Pin(capturedAt: now, side: .unknown, distance: .unknown, source: source)
        pin.milesBack = max(miles, 1)
        // Snapshot the trail now, so later bumps measure back from this tap, not from wherever the car is by then.
        let snapshot = trail()
        save(newPin: pin) { pin in
            self.estimateTarget(for: pin, along: snapshot)
        }
        if source == .app {
            bump = (pin, snapshot, now)
        }
        return pin
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
        guard let fix = await lateFix(),
              pin.modelContext != nil, !pin.isDeleted, !pin.hasLocation,
              FixPolicy.acceptsLateFix(capturedAt: pin.capturedAt, fixTimestamp: fix.timestamp)
        else { return }
        pin.applyFix(fix)
        persist()
    }

    // MARK: Private

    /// Stamps the current fix (if fresh), runs `prepare`, saves, confirms, and waits for a late fix if needed.
    private func save(newPin pin: Pin, prepare: (Pin) -> Void = { _ in }) {
        if let fix = currentFix() {
            pin.applyFix(fix)
        }
        prepare(pin)
        context.insert(pin)
        persist()
        if pin.source == .app {
            confirm(pin)
        }

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
    private func estimateTarget(for pin: Pin, along trail: BreadcrumbBuffer) {
        if let latitude = pin.latitude, let longitude = pin.longitude,
           let walk = trail.walkBack(from: TrailPoint(latitude: latitude, longitude: longitude),
                                     meters: pin.milesBack * Geo.metersPerMile) {
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

    private func persist() {
        do {
            try context.save()
        } catch {
            // The pin is still in the context, and autosave will retry.
            print("Passing: save failed: \(error)")
        }
    }
}
