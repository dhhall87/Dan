import CoreLocation
import Foundation
import Observation

/// Supplies fresh GPS fixes. Runs continuous updates while the capture screen is showing, plus a
/// short burst when a capture happens elsewhere (Siri, Shortcuts) or before the first fix.
/// The widget extension has its own copy, which only ever runs the short burst.
/// When In Use only, no background location, and never hands out a stale fix as current.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// The most recent fix of any age, for display. Use `freshFix()` for capturing.
    private(set) var latestFix: CLLocation?
    /// The last ~25 miles driven while the capture screen was open, for "+1 mi back". Memory only.
    @ObservationIgnored private(set) var breadcrumbs = BreadcrumbBuffer()

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var captureScreenVisible = false
    @ObservationIgnored private var isUpdating = false
    @ObservationIgnored private var waiters: [UUID: CheckedContinuation<CLLocation?, Never>] = [:]

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    /// True when Precise Location is off for Passing. Those fixes are only good to a few kilometers,
    /// which `FixPolicy` never stamps on a pin, so pins save without a position.
    private(set) var isPreciseLocationOff = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        isPreciseLocationOff = manager.accuracyAuthorization == .reducedAccuracy
    }

    /// The latest fix if it passes `FixPolicy`, otherwise nil. Never a stale coordinate.
    func freshFix(now: Date = .now) -> CLLocation? {
        guard let fix = latestFix,
              FixPolicy.isUsable(fixTimestamp: fix.timestamp, horizontalAccuracy: fix.horizontalAccuracy, now: now)
        else { return nil }
        return fix
    }

    /// Called by the capture screen as it appears and disappears.
    func setCaptureScreenVisible(_ visible: Bool) {
        captureScreenVisible = visible
        if visible {
            startUpdatesIfAuthorized()
        } else {
            stopIfIdle()
        }
    }

    /// Asks for When In Use permission. Called on the first capture, per the privacy rules.
    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Waits for the next usable fix, up to `timeout` seconds. Returns nil rather than an old fix.
    /// If GPS isn't running (a Siri capture, say), it runs a short burst and stops again afterwards.
    func nextUsableFix(timeout: TimeInterval) async -> CLLocation? {
        // Location off, or Precise Location off (those fixes never pass `FixPolicy`): no usable fix
        // is coming, so Siri and the widget don't wait the full time for nothing. Not asked yet is
        // different: the app may be showing the permission prompt right now.
        if isDenied || (isAuthorized && isPreciseLocationOff) {
            return nil
        }
        if isUpdating {
            // Restarting makes Core Location deliver a new fix right away, even if we aren't moving.
            manager.stopUpdatingLocation()
            manager.startUpdatingLocation()
        } else if isAuthorized {
            manager.startUpdatingLocation()
            isUpdating = true
        }
        let id = UUID()
        let fix = await withCheckedContinuation { continuation in
            waiters[id] = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.resolveWaiter(id, with: nil)
            }
        }
        stopIfIdle()
        return fix
    }

    // MARK: Private

    private func startUpdatesIfAuthorized() {
        guard captureScreenVisible, isAuthorized, !isUpdating else { return }
        manager.startUpdatingLocation()
        isUpdating = true
    }

    /// Stops GPS unless the capture screen is showing or a capture is still waiting for a fix.
    private func stopIfIdle() {
        guard !captureScreenVisible, waiters.isEmpty else { return }
        stopUpdates()
    }

    private func stopUpdates() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    private func resolveWaiter(_ id: UUID, with fix: CLLocation?) {
        waiters.removeValue(forKey: id)?.resume(returning: fix)
    }

    private func resolveAllWaiters(with fix: CLLocation?) {
        for id in Array(waiters.keys) {
            resolveWaiter(id, with: fix)
        }
    }

    private func handle(_ locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 {
            if latestFix == nil || location.timestamp >= latestFix!.timestamp {
                latestFix = location
            }
            // Only precise fixes go on the trail, so miles-back estimates don't zigzag.
            if location.horizontalAccuracy <= FixPolicy.exactAccuracy {
                breadcrumbs.add(
                    TrailPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                    at: location.timestamp
                )
            }
        }
        if let fix = freshFix() {
            resolveAllWaiters(with: fix)
        }
    }

    private func authorizationChanged(to status: CLAuthorizationStatus) {
        authorization = status
        if isAuthorized {
            startUpdatesIfAuthorized()
            // Someone is waiting on a fix (e.g. the very first capture, made before permission was granted).
            if !waiters.isEmpty && !isUpdating {
                manager.startUpdatingLocation()
                isUpdating = true
            }
        } else if isDenied {
            stopUpdates()
            resolveAllWaiters(with: nil)
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        Task { @MainActor in
            self.isPreciseLocationOff = reduced
            self.authorizationChanged(to: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // `locationUnknown` is temporary and Core Location keeps trying; waiters time out on their own.
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor in
            if denied { self.resolveAllWaiters(with: nil) }
        }
    }
}
