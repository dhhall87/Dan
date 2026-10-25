import CoreLocation
import Foundation
import SwiftData

/// The single entry point that saves a pin. The phone screen calls it today; Siri, the widget,
/// Control Center and the Action Button will call it in later milestones. Never duplicate save logic.
///
/// Save first: the pin is written synchronously before anything else happens. It never waits on
/// the network, never asks a question, and never substitutes an old coordinate.
@MainActor
final class CaptureService {
    static let shared = CaptureService(
        context: SharedStore.context,
        currentFix: { LocationProvider.shared.freshFix() },
        lateFix: {
            LocationProvider.shared.requestPermissionIfNeeded()
            return await LocationProvider.shared.nextUsableFix(timeout: FixPolicy.lateFixWindow)
        },
        trail: { LocationProvider.shared.breadcrumbs },
        confirm: { CaptureFeedback.shared.confirmCapture(of: $0) }
    )

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

    /// Saves a pin now.
    ///
    /// - Returns: the saved pin, or nil if this was a repeat tap on the same zone within 0.75 s.
    @discardableResult
    func capture(side: Side, distance: Distance, source: CaptureSource, label: String? = nil, now: Date = .now) -> Pin? {
        guard debouncer.shouldAccept("\(source.rawValue)-\(side.rawValue)-\(distance.rawValue)", at: now) else {
            return nil
        }
        bump = nil

        let pin = Pin(capturedAt: now, side: side, distance: distance, source: source)
        pin.label = label
        save(newPin: pin)
        return pin
    }

    /// "+1 mi back": saves a pin 1 mile back along the road just driven. Tapping again within
    /// `bumpWindow` seconds moves that same pin to 2 miles, 3 miles, and so on.
    /// Every tap confirms with the haptic and tone (and "2 miles back" if spoken confirmation is on).
    @discardableResult
    func captureMilesBack(source: CaptureSource, now: Date = .now) -> Pin {
        if let current = bump,
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
        pin.milesBack = 1
        // Snapshot the trail now, so later bumps measure back from this tap, not from wherever the car is by then.
        let snapshot = trail()
        save(newPin: pin) { pin in
            self.estimateTarget(for: pin, along: snapshot)
        }
        bump = (pin, snapshot, now)
        return pin
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
        confirm(pin)

        if !pin.hasLocation {
            Task { await attachLateFix(to: pin) }
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
