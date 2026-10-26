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

    /// Pins being looked up right now, so the list and a detail screen don't both ask. By pin and
    /// spot (`spotKey`), so a pin moved mid-lookup is looked up again for its new spot.
    private var inFlight: Set<String> = []
    /// Pins Apple had no name for, by pin and spot. Skipped until the next launch or a move.
    private var noName: Set<String> = []
    /// Town names already looked up this launch, by `PlaceNaming.cacheKey`. Memory only.
    private var known: [String: String] = [:]
    /// When the last real request went out, so requests from the list and a pin's screen together
    /// are still spaced out.
    private var lastRequestAt: ContinuousClock.Instant?

    enum Outcome: Equatable {
        case found(String)
        case noName
        /// Offline, throttled or another error: worth trying again later.
        case failed

        /// For the drive log, which never holds the town itself.
        var logName: String {
            switch self {
            case .found: return "found"
            case .noName: return "noName"
            case .failed: return "failed"
            }
        }
    }

    func fillMissing(in pins: [Pin]) async {
        let todo = pins.filter { $0.needsPlaceName && !noName.contains(spotKey($0)) && !inFlight.contains(spotKey($0)) }
            .prefix(Self.maxPerPass)
        for pin in todo {
            // Turned off in Settings → Privacy: pin locations never leave the iPhone for this.
            // Checked for every pin, so turning it off stops a pass already under way.
            guard !Task.isCancelled, AppSettings.lookUpPlaceNames else { return }
            let spot = spotKey(pin)
            guard isWaiting(pin, at: spot), !inFlight.contains(spot), let coordinate = pin.lookUpCoordinate else { continue }

            // Same neighbourhood as a pin already looked up: no request needed.
            let key = PlaceNaming.cacheKey(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let name = known[key] {
                pin.placeName = name
                try? pin.modelContext?.save()
                continue
            }

            // Only real requests are spaced out.
            inFlight.insert(spot)
            defer { inFlight.remove(spot) }
            if let lastRequestAt {
                let wait = Self.spacing - (ContinuousClock.now - lastRequestAt)
                if wait > .zero {
                    try? await Task.sleep(for: wait)
                }
            }
            guard !Task.isCancelled, AppSettings.lookUpPlaceNames else { return }
            // Moved during the wait: the new spot gets its own lookup.
            guard isWaiting(pin, at: spot) else { continue }
            lastRequestAt = .now
            let asked = Date.now
            let outcome = await Self.lookUp(coordinate)
            DriveLog.record(DriveLogEntry(at: .now, kind: .townLookup, outcome: outcome.logName, seconds: Date.now.timeIntervalSince(asked)))
            // Moved, or given a place's town, while the request was out: the answer is for the old spot.
            let stillHere = isWaiting(pin, at: spot)

            switch outcome {
            case .found(let name):
                known[key] = name
                guard stillHere else { continue }
                pin.placeName = name
                try? pin.modelContext?.save()
            case .noName:
                noName.insert(spot)
            case .failed:
                return
            }
        }
    }

    /// A pin and the spot its town is for. Moving the pin changes it.
    private func spotKey(_ pin: Pin) -> String {
        "\(pin.id.uuidString)|\(pin.lookUpKey)"
    }

    /// Still in the store, still at `spot`, and still without a town.
    private func isWaiting(_ pin: Pin, at spot: String) -> Bool {
        pin.modelContext != nil && !pin.isDeleted && pin.needsPlaceName && spotKey(pin) == spot
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
