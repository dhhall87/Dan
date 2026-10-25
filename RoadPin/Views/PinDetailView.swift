import MapKit
import SwiftData
import SwiftUI

struct PinDetailView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                Map(initialPosition: .region(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 1_500, longitudinalMeters: 1_500))) {
                    Marker(pin.title, systemImage: "mappin", coordinate: pin.coordinate)
                        .tint(.orange)
                    // Dashed line toward the side of the road you tapped.
                    if let toward = pin.lookTowardCoordinate {
                        MapPolyline(coordinates: [pin.coordinate, toward])
                            .stroke(.yellow, style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                    }
                }
                .frame(height: 260)
                .listRowInsets(EdgeInsets())
            }

            Section("What to look up") {
                TextField("e.g. large building, name of that town", text: $pin.note, axis: .vertical)
            }

            Section("Where to look") {
                Text(pin.findItHint)
                if !pin.placeName.isEmpty {
                    LabeledContent("Near", value: pin.placeName)
                }
                LabeledContent("Dropped", value: pin.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Coordinates", value: MapLinks.coordinateString(pin))
                    .textSelection(.enabled)
            }

            Section("Look it up") {
                Link(destination: MapLinks.apple(pin)) {
                    Label("Open in Apple Maps", systemImage: "map")
                }
                Link(destination: MapLinks.google(pin)) {
                    Label("Open in Google Maps", systemImage: "globe.americas")
                }
                ShareLink(item: MapLinks.google(pin), subject: Text(pin.title), message: Text(pin.title)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Toggle(isOn: $pin.isStarred) {
                    Label("Keep this pin", systemImage: "star")
                }
            } footer: {
                Text("Kept pins are never removed by the weekly clear-out.")
            }

            Section {
                Button("Delete Pin", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle(pin.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this pin?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Pin", role: .destructive) {
                // Leave the screen before deleting so nothing redraws a deleted pin.
                dismiss()
                let doomed = pin
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    PinStore.delete(doomed)
                }
            }
        }
        .onDisappear {
            PinStore.save()
        }
    }
}
