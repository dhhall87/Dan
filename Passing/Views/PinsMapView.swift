import MapKit
import SwiftUI

/// The pins from the list, on a map. Each one sits at its estimated spot if it has one (miles
/// back), otherwise where the car was. Tap a pin to see it, then tap the card to open it.
struct PinsMapView: View {
    let pins: [Pin]
    @State private var selectedID: UUID?

    private struct MappedPin: Identifiable {
        let pin: Pin
        let coordinate: CLLocationCoordinate2D
        var id: UUID { pin.id }
    }

    private var mapped: [MappedPin] {
        pins.compactMap { pin in
            pin.lookUpCoordinate.map { MappedPin(pin: pin, coordinate: $0) }
        }
    }

    private var selected: Pin? {
        mapped.first { $0.id == selectedID }?.pin
    }

    var body: some View {
        Map(initialPosition: .automatic, selection: $selectedID) {
            ForEach(mapped) { item in
                Marker(item.pin.displayLabel, systemImage: item.pin.milesBack > 0 ? "arrow.uturn.backward" : "mappin", coordinate: item.coordinate)
                    .tint(item.pin.isKept ? Color.yellow : Color.orange)
                    .tag(item.id)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let selected {
                NavigationLink(value: selected) {
                    PinRow(pin: selected)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding()
            } else if mapped.count < pins.count {
                Text(unmappedNote)
                    .font(.footnote)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom)
            }
        }
        .overlay {
            if mapped.isEmpty {
                ContentUnavailableView(
                    "Nothing to map",
                    systemImage: "map",
                    description: Text("None of these pins has a location.")
                )
            }
        }
    }

    private var unmappedNote: String {
        let missing = pins.count - mapped.count
        return missing == 1 ? "1 pin has no location, so it isn't on the map." : "\(missing) pins have no location, so they aren't on the map."
    }
}
