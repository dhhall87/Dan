import CoreLocation
import Foundation
import Observation

/// Supplies fresh GPS fixes. Runs continuous updates only while the capture screen is showing
/// (When In Use only, no background location), and never hands out a stale fix as current.
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

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
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
            stopUpdates()
        }
    }

    /// Asks for When In Use permission. Called on the first capture, per the privacy rules.
    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Waits for the next usable fix, up to `timeout` seconds. Returns nil rather than an old fix.
    func nextUsableFix(timeout: TimeInterval) async -> CLLocation? {
        if isUpdating {
            // Restarting makes Core Location deliver a new fix right away, even if we aren't moving.
            manager.stopUpdatingLocation()
            manager.startUpdatingLocation()
        } else if isAuthorized {
            manager.requestLocation()
        }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            waiters[id] = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.resolveWaiter(id, with: nil)
            }
        }
    }

    // MARK: Private

    private func startUpdatesIfAuthorized() {
        guard captureScreenVisible, isAuthorized, !isUpdating else { return }
        manager.startUpdatingLocation()
        isUpdating = true
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
                manager.requestLocation()
            }
        } else if isDenied {
            stopUpdates()
            resolveAllWaiters(with: nil)
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(to: status) }
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
