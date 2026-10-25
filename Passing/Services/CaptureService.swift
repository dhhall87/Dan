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
        confirm: { CaptureFeedback.shared.confirmCapture(of: $0) }
    )

    private let context: ModelContext
    private let currentFix: @MainActor () -> CLLocation?
    private let lateFix: @MainActor () async -> CLLocation?
    private let confirm: @MainActor (Pin) -> Void
    private var debouncer = TapDebouncer<String>(interval: 0.75)

    /// The dependencies are injectable so tests can use an in-memory store and fake GPS.
    init(
        context: ModelContext,
        currentFix: @escaping @MainActor () -> CLLocation?,
        lateFix: @escaping @MainActor () async -> CLLocation?,
        confirm: @escaping @MainActor (Pin) -> Void
    ) {
        self.context = context
        self.currentFix = currentFix
        self.lateFix = lateFix
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

        let pin = Pin(capturedAt: now, side: side, distance: distance, source: source)
        pin.label = label
        if let fix = currentFix() {
            pin.applyFix(fix)
        }
        context.insert(pin)
        save()
        confirm(pin)

        if !pin.hasLocation {
            Task { await attachLateFix(to: pin) }
        }
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
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // The pin is still in the context, and autosave will retry.
            print("Passing: save failed: \(error)")
        }
    }
}
