import CoreLocation
import Foundation
import Observation

/// Keeps GPS running while RoadPin is in use and records the last stretch of road for "miles back" pins.
@MainActor
@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTracker()

    private(set) var lastLocation: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var isUpdating = false

    @ObservationIgnored private(set) var trail = BreadcrumbTrail()
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var wantsUpdates = false
    @ObservationIgnored private var waiters: [CheckedContinuation<CLLocation?, Never>] = []

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .automotiveNavigation
        // Lets iOS switch GPS off after you've been parked for a while.
        manager.pausesLocationUpdatesAutomatically = true
        authorization = manager.authorizationStatus
    }

    /// Ask for permission if needed and start following the drive.
    func start() {
        wantsUpdates = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            resolveWaiters()
        }
    }

    /// Lets Siri save pins while RoadPin isn't open.
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    /// The best current location, waiting up to `timeout` seconds for a fix if we don't have one yet.
    func currentLocation(timeout: TimeInterval = 8) async -> CLLocation? {
        // While updates are running, no new fix just means we haven't moved 10 m.
        if let lastLocation, isUpdating || abs(lastLocation.timestamp.timeIntervalSinceNow) < 20 {
            return lastLocation
        }
        start()
        if isDenied { return nil }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.resolveWaiters()
            }
        }
    }

    private func beginUpdates() {
        guard !isUpdating else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isUpdating = true
    }

    private func resolveWaiters() {
        let pending = waiters
        waiters = []
        for waiter in pending {
            waiter.resume(returning: lastLocation)
        }
    }

    private func handle(_ locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 {
            lastLocation = location
            // Skip poor fixes for the trail; a jumpy trail makes "miles back" pins land in odd places.
            if location.horizontalAccuracy <= 65 {
                trail.append(TrailPoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: location.timestamp
                ))
            }
        }
        if lastLocation != nil {
            resolveWaiters()
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.wantsUpdates { self.beginUpdates() }
            case .denied, .restricted:
                self.resolveWaiters()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.handle(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor in
            if denied {
                self.resolveWaiters()
            }
        }
    }

    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.isUpdating = false
        }
    }

    nonisolated func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.isUpdating = true
        }
    }
}
