import MapKit
import SwiftData
import SwiftUI

struct PinDetailView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                if let coordinate = pin.captureCoordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200))) {
                        Marker("Your car", systemImage: "car.fill", coordinate: coordinate)
                            .tint(.blue)
                        if let target = pin.targetCoordinate {
                            Marker(pin.displayLabel, systemImage: "scope", coordinate: target)
                                .tint(.orange)
                        }
                    }
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets())
                } else {
                    Label("No location was recorded for this pin. GPS didn't have a usable fix in time, so Passing saved the time only.", systemImage: "location.slash")
                        .foregroundStyle(.orange)
                }
            }

            Section("What was it?") {
                TextField("Label, e.g. large building", text: labelBinding, axis: .vertical)
                Picker("Side", selection: $pin.side) {
                    ForEach(Side.allCases) { side in
                        Text(side.title).tag(side)
                    }
                }
                Picker("Distance", selection: $pin.distance) {
                    ForEach(Distance.allCases) { distance in
                        Text(distance.title).tag(distance)
                    }
                }
                Toggle("Reviewed", isOn: $pin.isReviewed)
            }

            if let apple = pin.appleMapsURL, let google = pin.googleMapsURL {
                Section("Look it up") {
                    Link(destination: apple) {
                        Label("Open in Apple Maps", systemImage: "map")
                    }
                    Link(destination: google) {
                        Label("Open in Google Maps", systemImage: "globe.americas")
                    }
                }
            }

            Section("Details") {
                LabeledContent("Pinned", value: pin.capturedAt.formatted(date: .abbreviated, time: .standard))
                if let latitude = pin.latitude, let longitude = pin.longitude {
                    LabeledContent("Coordinates", value: MapLinks.coordinateString(latitude: latitude, longitude: longitude))
                        .textSelection(.enabled)
                }
                LabeledContent("Accuracy", value: PinFormat.accuracy(of: pin))
                if let fixTimestamp = pin.fixTimestamp {
                    LabeledContent("GPS fix", value: fixOffset(fixTimestamp))
                }
                if let speed = pin.speed {
                    LabeledContent("Speed", value: "\(Int((speed * 2.236_94).rounded())) mph")
                }
                if pin.courseReliable, let course = pin.course {
                    LabeledContent("Heading", value: "\(Int(course.rounded()))° \(compassName(course))")
                }
                LabeledContent("Saved from", value: pin.source.title)
            }

            Section {
                Button("Delete Pin", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                Text("Deleting is permanent for now. Recently Deleted arrives with the retention milestone.")
            }
        }
        .navigationTitle(pin.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this pin?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Pin", role: .destructive) {
                // Leave the screen first so nothing redraws a deleted pin.
                dismiss()
                let doomed = pin
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    context.delete(doomed)
                    try? context.save()
                }
            }
        }
    }

    /// Typing an empty label clears it back to "Unlabeled".
    private var labelBinding: Binding<String> {
        Binding(
            get: { pin.label ?? "" },
            set: { pin.label = $0.isEmpty ? nil : $0 }
        )
    }

    private func fixOffset(_ fixTimestamp: Date) -> String {
        let seconds = fixTimestamp.timeIntervalSince(pin.capturedAt)
        if abs(seconds) < 1 { return "At the moment you tapped" }
        let amount = String(format: "%.0f s", abs(seconds))
        return seconds < 0 ? "\(amount) before you tapped" : "\(amount) after you tapped"
    }

    private func compassName(_ bearing: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized + 22.5) / 45) % 8]
    }
}
