import MapKit
import SwiftData
import SwiftUI

struct PinDetailView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false
    @Query(sort: \PinGroup.name) private var groups: [PinGroup]
    @State private var lookAround: LookAroundState = .notRequested
    @State private var addingGroup = false
    @State private var movingPin = false

    private enum LookAroundState {
        /// Nothing is fetched until asked: it sends the spot to Apple and downloads imagery.
        case notRequested
        case loading
        case ready(MKLookAroundScene)
        case unavailable
    }

    var body: some View {
        Form {
            if !pin.isNote {
            Section {
                if let coordinate = pin.lookUpCoordinate {
                    Map(initialPosition: mapPosition(around: coordinate)) {
                        if let car = pin.captureCoordinate {
                            Marker("Your car", systemImage: "car.fill", coordinate: car)
                                .tint(.blue)
                        }
                        if pin.trailCoordinates.count > 1 {
                            MapPolyline(coordinates: pin.trailCoordinates)
                                .stroke(.blue, lineWidth: 4)
                        }
                        if let target = pin.targetCoordinate {
                            Marker(pin.milesBack > 0 && pin.targetSource != .manual ? "About here" : pin.displayLabel, systemImage: "scope", coordinate: target)
                                .tint(.orange)
                        }
                    }
                    // A new map after a move, so it frames the new spot.
                    .id("\(pin.targetLatitude ?? 0),\(pin.targetLongitude ?? 0)")
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets())
                } else {
                    Label("No location was recorded for this pin. GPS didn't have a usable fix in time, so Passing saved the time only. You can place it on the map yourself.", systemImage: "location.slash")
                        .foregroundStyle(.orange)
                }
                Button {
                    movingPin = true
                } label: {
                    Label(pin.lookUpCoordinate == nil ? "Place on Map" : "Move Pin", systemImage: "hand.point.up.left")
                }
                if let hint = pin.milesBackHint {
                    Text(hint)
                        .font(.callout)
                }
            }
            }

            if !pin.isNote, pin.lookUpCoordinate != nil {
                NearbyPlacesSection(pin: pin)
            }

            Section(pin.isNote ? "Note" : "What was it?") {
                TextField(pin.isNote ? "Note" : "Label, e.g. large building", text: labelBinding, axis: .vertical)
                if !pin.isNote {
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
                }
                Picker("Group", selection: groupSelection) {
                    Text("None").tag(UUID?.none)
                    ForEach(groups) { group in
                        Text(group.name).tag(UUID?.some(group.id))
                    }
                }
                Button("New Group…") {
                    addingGroup = true
                }
                Toggle("Reviewed", isOn: $pin.isReviewed)
            }

            if pin.lookUpCoordinate != nil {
                Section {
                    switch lookAround {
                    case .notRequested:
                        Button {
                            lookAround = .loading
                            Task { await loadLookAround() }
                        } label: {
                            Label("Show Look Around", systemImage: "binoculars")
                        }
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 60)
                    case .ready(let scene):
                        LookAroundPreview(initialScene: scene)
                            .frame(height: 220)
                            .listRowInsets(EdgeInsets())
                    case .unavailable:
                        Text("No Look Around imagery here, or you're offline.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Look Around")
                } footer: {
                    Text(pin.targetCoordinate != nil ? "At the estimated spot. Loads from Apple Maps when you ask." : "Where your car was. Loads from Apple Maps when you ask.")
                }
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
                    // With a label but no place chosen yet: let Apple Maps find "diner" right there.
                    if pin.placeID == nil, let label = pin.label, !label.isEmpty, let spot = pin.lookUpCoordinate {
                        Link(destination: MapLinks.appleSearch(query: label, latitude: spot.latitude, longitude: spot.longitude)) {
                            Label("Search “\(label)” Here in Apple Maps", systemImage: "magnifyingglass")
                        }
                    }
                    Link(destination: google) {
                        Label("Open in Google Maps", systemImage: "globe.americas")
                    }
                }
            }

            Section("Details") {
                LabeledContent(pin.isNote ? "Written" : "Pinned", value: pin.capturedAt.formatted(date: .abbreviated, time: .standard))
                if pin.lookUpCoordinate != nil {
                    LabeledContent("Town", value: pin.placeName ?? "Not looked up yet")
                }
                if let latitude = pin.latitude, let longitude = pin.longitude {
                    LabeledContent("Coordinates", value: MapLinks.coordinateString(latitude: latitude, longitude: longitude))
                        .textSelection(.enabled)
                }
                if pin.targetSource == .manual, let latitude = pin.targetLatitude, let longitude = pin.targetLongitude {
                    LabeledContent("Moved to", value: MapLinks.coordinateString(latitude: latitude, longitude: longitude))
                        .textSelection(.enabled)
                }
                if !pin.isNote {
                    LabeledContent("Accuracy", value: PinFormat.accuracy(of: pin))
                }
                if let fixTimestamp = pin.fixTimestamp {
                    LabeledContent("GPS fix", value: fixOffset(fixTimestamp))
                }
                if let speed = pin.speed {
                    LabeledContent("Speed", value: "\(Int((speed * 2.236_94).rounded())) mph")
                }
                if pin.courseReliable, let course = pin.course {
                    LabeledContent("Heading", value: "\(Int(course.rounded()))° \(Geo.compassName(for: course, short: true))")
                }
                LabeledContent("Saved from", value: pin.source.title)
            }

            Section {
                Button(pin.isNote ? "Delete Note" : "Delete Pin", role: .destructive) {
                    RetentionService.shared.moveToRecentlyDeleted(pin)
                    dismiss()
                }
            } footer: {
                Text("Moves it to Recently Deleted, where you can recover it for 30 days.")
            }
        }
        .navigationTitle(pin.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $movingPin) {
            MovePinView(pin: pin)
        }
        .newGroupAlert(isPresented: $addingGroup, message: "This pin goes into the new group.") { group in
            PinGroups.move(pin, to: group, in: context)
        }
        .task {
            await PlaceNameService.shared.fillMissing(in: [pin])
        }
    }

    private var groupSelection: Binding<UUID?> {
        Binding(
            get: { pin.group?.id },
            set: { id in
                PinGroups.move(pin, to: groups.first { $0.id == id }, in: context)
            }
        )
    }

    /// Look Around needs the network and only exists where Apple has driven, so it's often missing
    /// on rural roads. The pin itself never depends on it.
    private func loadLookAround() async {
        guard let coordinate = pin.lookUpCoordinate else { return }
        let scene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene
        lookAround = scene.map(LookAroundState.ready) ?? .unavailable
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
}
