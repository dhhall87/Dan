import CoreLocation
import MapKit
import SwiftData

/// Fills in each pin's town ("what town was that?") from Apple's reverse geocoding. It's lazy: it
/// only runs while you're looking at pins, one lookup at a time, and stops at the first network
/// error to try again next time. Capture never waits on it.
@MainActor
final class PlaceNameService {
    static let shared = PlaceNameService()

    /// Apple limits how often an app can geocode, so lookups are spaced out.
    static let spacing: Duration = .seconds(1.5)
    /// At most this many lookups each time the list opens.
    static let maxPerPass = 20

    /// Pins being looked up right now, so the list and a detail screen don't both ask.
    private var inFlight: Set<UUID> = []
    /// Pins Apple had no name for. Skipped until the next launch.
    private var noName: Set<UUID> = []
    /// Town names already looked up this launch, by `PlaceNaming.cacheKey`. Memory only.
    private var known: [String: String] = [:]

    enum Outcome: Equatable {
        case found(String)
        case noName
        /// Offline, throttled or another error: worth trying again later.
        case failed
    }

    func fillMissing(in pins: [Pin]) async {
        // Turned off in Settings → Privacy: pin locations never leave the iPhone for this.
        guard AppSettings.lookUpPlaceNames else { return }
        let todo = pins.filter { $0.needsPlaceName && !noName.contains($0.id) && !inFlight.contains($0.id) }
            .prefix(Self.maxPerPass)
        var asked = false
        for pin in todo {
            guard !Task.isCancelled else { return }
            guard pin.modelContext != nil, !pin.isDeleted, pin.needsPlaceName,
                  let coordinate = pin.lookUpCoordinate, !inFlight.contains(pin.id)
            else { continue }

            // Same neighbourhood as a pin already looked up: no request needed.
            let key = PlaceNaming.cacheKey(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let name = known[key] {
                pin.placeName = name
                try? pin.modelContext?.save()
                continue
            }

            // Only real requests are spaced out.
            if asked {
                try? await Task.sleep(for: Self.spacing)
                guard !Task.isCancelled else { return }
            }
            asked = true
            inFlight.insert(pin.id)
            let outcome = await Self.lookUp(coordinate)
            inFlight.remove(pin.id)

            switch outcome {
            case .found(let name):
                known[key] = name
                guard pin.modelContext != nil, !pin.isDeleted else { continue }
                pin.placeName = name
                try? pin.modelContext?.save()
            case .noName:
                noName.insert(pin.id)
            case .failed:
                return
            }
        }
    }

    /// One reverse-geocoding request. Uses the iOS 26 MapKit request; `CLGeocoder` is the older way.
    static func lookUp(_ coordinate: CLLocationCoordinate2D) async -> Outcome {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return .noName }
        do {
            let items = try await request.mapItems
            guard let item = items.first else { return .noName }
            let name = PlaceNaming.name(
                cityWithContext: item.addressRepresentations?.cityWithContext,
                cityName: item.addressRepresentations?.cityName,
                fallback: item.name
            )
            return name.map(Outcome.found) ?? .noName
        } catch {
            if (error as? MKError)?.code == .placemarkNotFound {
                return .noName
            }
            return .failed
        }
    }
}
