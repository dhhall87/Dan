import CoreLocation
import Observation

/// Finds roughly where Dan is, once, when he asks for sunrise times. Never tracks.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var place: SavedPlace? = SavedPlace.load()
    private(set) var isLocating = false
    private(set) var problem: String?

    /// Made on first use, so nothing location-related happens until Dan asks.
    @ObservationIgnored private var manager: CLLocationManager?

    func locate() {
        problem = nil
        let manager = self.manager ?? makeManager()
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            problem = "Location is off for Sunrise. To see sunrise times, turn it on in Settings → Apps → Sunrise → Location."
        default:
            isLocating = true
            manager.requestLocation()
        }
    }

    private func makeManager() -> CLLocationManager {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = self
        self.manager = manager
        return manager
    }

    private func authorizationChanged() {
        guard isLocating, let manager else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .denied, .restricted:
            isLocating = false
            problem = "Without location, Sunrise can't show the times. The lights still follow the sunrise."
        default:
            manager.requestLocation()
        }
    }

    private func found(latitude: Double, longitude: Double) {
        let place = SavedPlace(latitude: latitude, longitude: longitude)
        place.save()
        self.place = place
        isLocating = false
    }

    private func failed() {
        guard isLocating else { return }
        isLocating = false
        problem = "Couldn't find where you are just now. Try again in a moment."
    }

    // Core Location calls these on the main thread here (the manager is made on it), but they
    // hop explicitly so that never matters.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationChanged() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor in self.found(latitude: latitude, longitude: longitude) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.failed() }
    }
}
