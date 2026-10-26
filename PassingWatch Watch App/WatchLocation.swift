import CoreLocation
import Foundation
import Observation

/// The watch's own GPS. Runs while Passing is on screen (so a tap usually finds a fresh reading
/// waiting), plus while a pin is still waiting for one. When In Use only, no background location,
/// and the same freshness rules as the iPhone (`FixPolicy`).
@MainActor
@Observable
final class WatchLocation: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// True when Precise Location is off for Passing. Those readings are only good to a few
    /// kilometers, which `FixPolicy` never puts on a pin.
    private(set) var isPreciseLocationOff = false
    /// The most recent reading of any age. `WatchFix.isUsable` decides whether a pin may have it.
    private(set) var latestFix: WatchFix?

    /// Called with each new reading.
    @ObservationIgnored var onFix: (@MainActor (WatchFix) -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var isOnScreen = false
    @ObservationIgnored private var pinsWaiting = false
    @ObservationIgnored private var isUpdating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        authorization = manager.authorizationStatus
        isPreciseLocationOff = manager.accuracyAuthorization == .reducedAccuracy
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    /// Whether a reading may still come, so a pin tapped now should wait for one. Not yet asked
    /// counts, since the question may be answered in time.
    var mayGetFix: Bool {
        authorization == .notDetermined
            || (isAuthorized && FixPolicy.permitsFixes(isDenied: isDenied, isReducedAccuracy: isPreciseLocationOff))
    }

    /// The latest reading if a pin tapped now may have it, otherwise nil. Never one from before
    /// location or Precise Location was turned off.
    func freshFix(now: Date = .now) -> WatchFix? {
        guard FixPolicy.permitsFixes(isDenied: isDenied, isReducedAccuracy: isPreciseLocationOff),
              let fix = latestFix, fix.isUsable(now: now)
        else { return nil }
        return fix
    }

    /// Asks for When In Use permission the first time Passing opens on the watch. Asking on the
    /// first tap instead would cost that pin its location while the question is up.
    func requestPermissionIfNeeded() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Passing came on screen or went off it.
    func setOnScreen(_ onScreen: Bool) {
        isOnScreen = onScreen
        updateRunning()
    }

    /// Whether any pin is still waiting for a reading. GPS keeps going for them after the screen
    /// goes off, until they have one or their 15 s are up.
    func setPinsWaiting(_ waiting: Bool) {
        pinsWaiting = waiting
        updateRunning()
    }

    /// Passing is going to the background: no reading can be used now.
    func stopAll() {
        isOnScreen = false
        pinsWaiting = false
        updateRunning()
    }

    // MARK: Private

    private func updateRunning() {
        let wanted = (isOnScreen || pinsWaiting) && isAuthorized
            && FixPolicy.permitsFixes(isDenied: isDenied, isReducedAccuracy: isPreciseLocationOff)
        guard wanted != isUpdating else { return }
        isUpdating = wanted
        if wanted {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    private func authorizationChanged(to status: CLAuthorizationStatus, reduced: Bool) {
        authorization = status
        isPreciseLocationOff = reduced
        if !FixPolicy.permitsFixes(isDenied: isDenied, isReducedAccuracy: reduced) {
            // Nothing taken before the change may be used.
            latestFix = nil
        }
        updateRunning()
    }

    private func handle(_ locations: [CLLocation]) {
        guard FixPolicy.permitsFixes(isDenied: isDenied, isReducedAccuracy: isPreciseLocationOff) else { return }
        for location in locations {
            let fix = WatchFix(location)
            latestFix = fix
            onFix?(fix)
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        Task { @MainActor in
            self.authorizationChanged(to: status, reduced: reduced)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // `locationUnknown` is temporary and Core Location keeps trying; waiting pins time out on their own.
    }
}

extension WatchFix {
    init(_ location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            speed: location.speed,
            course: location.course,
            courseAccuracy: location.courseAccuracy
        )
    }
}
