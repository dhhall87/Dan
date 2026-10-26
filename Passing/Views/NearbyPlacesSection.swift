import MapKit
import SwiftUI

/// "What's here?" on a pin's screen: the businesses and landmarks Apple Maps lists near the pin,
/// closest first. Tap the one you passed and the pin takes its name, moves to it, and links to its
/// own card in Apple Maps, where Add to Guide works. The car's position stays as recorded. The pin's
/// location goes to Apple only when you ask, and nothing is looked up on its own.
struct NearbyPlacesSection: View {
    @Bindable var pin: Pin
    @State private var state: LoadState = .notRequested
    @State private var radius: Double = 0
    /// Where the pin went when a place here was chosen, so that move keeps the list (with its tick)
    /// while a move by hand clears it.
    @State private var chosenKey: String?

    private enum LoadState {
        case notRequested
        case loading
        case found([Found])
        case nothing
        case failed
    }

    private struct Found: Identifiable {
        let id: Int
        let item: MKMapItem
        let meters: Double
    }

    var body: some View {
        Section {
            switch state {
            case .notRequested:
                Button {
                    Task { await search(radius: NearbyPlaces.searchRadius(for: pin.distance)) }
                } label: {
                    Label("Find Places Near This Pin", systemImage: "building.2")
                }
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .found(let places):
                ForEach(places) { place in
                    row(for: place)
                }
                lookFartherButton
            case .nothing:
                Text("Apple Maps lists no places this close. Quiet roads often have none.")
                    .foregroundStyle(.secondary)
                lookFartherButton
            case .failed:
                Text("Couldn't reach Apple Maps. Check your connection and try again.")
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    Task { await search(radius: radius) }
                }
            }
        } header: {
            Text("What's here?")
        } footer: {
            Text("Places from Apple Maps near the pin, closest first. Tap the one you passed: the pin takes its name and **Open in Apple Maps** shows that place, ready for **Add to Guide**. The pin's location is sent to Apple only when you tap Find.")
        }
        .onChange(of: pin.lookUpKey) {
            // Moved by hand: these places were near the old spot.
            if pin.lookUpKey != chosenKey {
                state = .notRequested
                radius = 0
            }
        }
    }

    private func row(for place: Found) -> some View {
        Button {
            choose(place)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.item.name ?? "Unnamed place")
                        .foregroundStyle(.primary)
                    Text(details(for: place))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let chosen = pin.placeID, chosen == place.item.identifier?.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Chosen")
                }
            }
        }
    }

    @ViewBuilder
    private var lookFartherButton: some View {
        if radius < NearbyPlaces.widerRadius {
            Button("Look Farther (about a mile)") {
                Task { await search(radius: NearbyPlaces.widerRadius) }
            }
        }
    }

    private func details(for place: Found) -> String {
        let category = place.item.pointOfInterestCategory.flatMap { NearbyPlaces.categoryTitle(fromRawValue: $0.rawValue) }
        return ([category, NearbyPlaces.distanceText(meters: place.meters)].compactMap { $0 }).joined(separator: " · ")
    }

    private func search(radius: Double) async {
        guard let center = pin.lookUpCoordinate else { return }
        let key = pin.lookUpKey
        self.radius = radius
        state = .loading
        let request = MKLocalPointsOfInterestRequest(center: center, radius: min(radius, MKLocalPointsOfInterestRequest.maxRadius))
        do {
            let response = try await MKLocalSearch(request: request).start()
            // Deleted for good, or moved, while searching: these results aren't for this pin any more.
            guard isStill(at: key) else { return }
            let here = TrailPoint(latitude: center.latitude, longitude: center.longitude)
            let places = response.mapItems
                .map { item in
                    let spot = item.location.coordinate
                    return (item, Geo.distance(here, TrailPoint(latitude: spot.latitude, longitude: spot.longitude)))
                }
                .sorted { $0.1 < $1.1 }
                .prefix(NearbyPlaces.maxShown(radius: radius))
                .enumerated()
                .map { Found(id: $0.offset, item: $0.element.0, meters: $0.element.1) }
            state = places.isEmpty ? .nothing : .found(places)
        } catch {
            guard isStill(at: key) else { return }
            // "Not found" just means Apple Maps has nothing listed there.
            state = (error as? MKError)?.code == .placemarkNotFound ? .nothing : .failed
        }
    }

    /// Still in the store (reading a pin deleted for good crashes) and still at the searched spot.
    private func isStill(at key: String) -> Bool {
        pin.modelContext != nil && !pin.isDeleted && pin.lookUpKey == key
    }

    private func choose(_ place: Found) {
        let item = place.item
        pin.choosePlace(
            name: item.name,
            coordinate: item.location.coordinate,
            placeID: item.identifier?.rawValue,
            town: item.addressRepresentations?.cityWithContext
        )
        chosenKey = pin.lookUpKey
        try? pin.modelContext?.save()
    }
}
