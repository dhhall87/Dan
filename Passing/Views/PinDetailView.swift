import MapKit
import SwiftData
import SwiftUI

struct PinDetailView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false

    var body: some View {
        Form {
            Section {
                if let coordinate = pin.captureCoordinate {
                    Map(initialPosition: mapPosition(around: coordinate)) {
                        Marker("Your car", systemImage: "car.fill", coordinate: coordinate)
                            .tint(.blue)
                        if pin.trailCoordinates.count > 1 {
                            MapPolyline(coordinates: pin.trailCoordinates)
                                .stroke(.blue, lineWidth: 4)
                        }
                        if let target = pin.targetCoordinate {
                            Marker(pin.milesBack > 0 ? "About here" : pin.displayLabel, systemImage: "scope", coordinate: target)
                                .tint(.orange)
                        }
                    }
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets())
                } else {
                    Label("No location was recorded for this pin. GPS didn't have a usable fix in time, so Passing saved the time only.", systemImage: "location.slash")
                        .foregroundStyle(.orange)
                }
                if let hint = pin.milesBackHint {
                    Text(hint)
                        .font(.callout)
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

            Section {
                Toggle(isOn: $pin.isKept) {
                    Label("Keep", systemImage: pin.isKept ? "star.fill" : "star")
                }
            } footer: {
                Text(keepFooter)
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
                    RetentionService.shared.moveToRecentlyDeleted(pin)
                    dismiss()
                }
            } footer: {
                Text("Moves the pin to Recently Deleted, where you can recover it for 30 days.")
            }
        }
        .navigationTitle(pin.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Close in on an ordinary pin; fit the car, the estimate and the route for a miles-back pin.
    private func mapPosition(around coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        if pin.targetCoordinate != nil || pin.trailCoordinates.count > 1 {
            return .automatic
        }
        return .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200))
    }

    private var keepFooter: String {
        if pin.isKept { return "Kept pins never expire." }
        if keepIndefinitely { return "“Keep records indefinitely” is on, so this pin won't expire." }
        return RetentionPolicy.expiryText(capturedAt: pin.capturedAt, isKept: false, keepIndefinitely: false, now: AppClock.now)
            .map { "\($0). Keep it to stop that." } ?? ""
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
