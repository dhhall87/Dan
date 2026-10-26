import MapKit
import SwiftUI

/// What Select mode hands to the route screen: the picked pins with a location, in the order
/// they were picked, and how many picked pins had to be left out.
struct RouteSelection: Identifiable {
    let id = UUID()
    let stops: [RouteStop]
    /// Notes and pins with no location: nowhere to go.
    let withoutLocation: Int
    /// Pins past `RoutePlan.maxPins`.
    let overLimit: Int
}

/// Pins → Select → Route: the picked pins as a route to drive or walk later, in the order they were
/// picked (drag to change it). Straight lines show at once; a road route comes from Apple's
/// directions on request, one request per leg. Open in Apple Maps sends the whole route as one
/// multi-stop trip; Google Maps takes fewer stops per link, so long routes open in parts.
struct RoutePlannerView: View {
    @Environment(\.dismiss) private var dismiss
    let selection: RouteSelection
    @State private var pins: [RouteStop]
    @State private var start: EndChoice = .pin
    @State private var end: EndChoice = .pin
    @State private var mode: RouteMode = .driving
    @State private var startAddress = AddressPick()
    @State private var endAddress = AddressPick()
    @State private var road: RoadRoute = .none
    /// Home and Work, if they've been set for review reminders.
    private let places = ReviewReminderSettings.load(from: AppGroup.defaults)

    init(selection: RouteSelection) {
        self.selection = selection
        _pins = State(initialValue: selection.stops)
    }

    enum EndChoice: Hashable {
        case pin, currentLocation, home, work, address
    }

    struct AddressPick {
        var text = ""
        var found: RouteStop?
        var isSearching = false
        var problem: String?
    }

    enum RoadRoute {
        case none
        case loading
        case shown([MKRoute], failedLegs: Int)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    map
                        .frame(height: 280)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text(mapFooter)
                }
                stopsSection
                startAndEndSection
                roadSection
                openSection
            }
            .navigationTitle("Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: plan) {
                // A different route: the road route drawn for the old one no longer fits.
                road = .none
            }
        }
    }

    // MARK: Plan

    var plan: RoutePlan {
        RoutePlan(pins: pins, start: endpoint(for: start, address: startAddress), end: endpoint(for: end, address: endAddress), mode: mode)
    }

    private func endpoint(for choice: EndChoice, address: AddressPick) -> RouteEndpoint {
        switch choice {
        case .pin: return .pin
        case .currentLocation: return .currentLocation
        case .home: return places.home.map { .place(RouteStop(name: "Home", latitude: $0.latitude, longitude: $0.longitude)) } ?? .pin
        case .work: return places.work.map { .place(RouteStop(name: "Work", latitude: $0.latitude, longitude: $0.longitude)) } ?? .pin
        case .address: return address.found.map { .place($0) } ?? .pin
        }
    }

    // MARK: Map

    private var map: some View {
        let points = plan.points
        return Map(initialPosition: .automatic) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, stop in
                Annotation(stop.name, coordinate: coordinate(stop)) {
                    Text(badge(for: index, of: points.count))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Color.orange, in: Circle())
                }
            }
            if case .shown(let routes, _) = road {
                ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            } else {
                MapPolyline(coordinates: points.map(coordinate))
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
            }
        }
        // A new map when the stops change, so it frames them all again.
        .id(points.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";"))
    }

    /// "S" and "E" for a start or end place, numbers for the pins.
    private func badge(for index: Int, of count: Int) -> String {
        let startsAtPlace = isPlace(plan.start)
        let endsAtPlace = isPlace(plan.end)
        if startsAtPlace, index == 0 { return "S" }
        if endsAtPlace, index == count - 1 { return "E" }
        return "\(index - (startsAtPlace ? 1 : 0) + 1)"
    }

    private func isPlace(_ endpoint: RouteEndpoint) -> Bool {
        if case .place = endpoint { return true }
        return false
    }

    private var mapFooter: String {
        let miles = plan.straightMeters / Geo.metersPerMile
        var text = "About \(Geo.milesText(miles)) in straight lines."
        if start == .currentLocation {
            text += " The map starts at the first pin; the road route and the Maps apps start from where you are."
        }
        return text
    }

    private func coordinate(_ stop: RouteStop) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
    }

    // MARK: Sections

    private var stopsSection: some View {
        Section {
            ForEach(Array(pins.enumerated()), id: \.offset) { index, stop in
                LabeledContent {
                    Text("\(index + 1)")
                        .monospacedDigit()
                } label: {
                    Text(stop.name)
                }
            }
            .onMove { source, destination in
                pins.move(fromOffsets: source, toOffset: destination)
            }
        } header: {
            Text("Stops, in order")
        } footer: {
            Text(stopsFooter)
        }
    }

    private var stopsFooter: String {
        var notes = ["In the order you picked them. Tap Edit to drag them into a different order."]
        if selection.withoutLocation > 0 {
            notes.append(selection.withoutLocation == 1
                ? "1 picked item has no location, so it isn't on the route."
                : "\(selection.withoutLocation) picked items have no location, so they aren't on the route.")
        }
        if selection.overLimit > 0 {
            notes.append("A route takes up to \(RoutePlan.maxPins) pins; the last \(selection.overLimit) picked were left off.")
        }
        return notes.joined(separator: " ")
    }

    private var startAndEndSection: some View {
        Section {
            Picker("Start", selection: $start) {
                Text("First pin").tag(EndChoice.pin)
                Text("Where you are").tag(EndChoice.currentLocation)
                endChoices
            }
            if start == .address {
                addressField(for: $startAddress)
            }
            Picker("End", selection: $end) {
                Text("Last pin").tag(EndChoice.pin)
                endChoices
            }
            if end == .address {
                addressField(for: $endAddress)
            }
            Picker("Travel", selection: $mode) {
                ForEach(RouteMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Start and end")
        } footer: {
            Text("Home and Work are the places set in Settings → Review Reminders.")
        }
    }

    @ViewBuilder
    private var endChoices: some View {
        if places.home != nil {
            Text("Home").tag(EndChoice.home)
        }
        if places.work != nil {
            Text("Work").tag(EndChoice.work)
        }
        Text("An address…").tag(EndChoice.address)
    }

    private func addressField(for pick: Binding<AddressPick>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Address or place", text: pick.text)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.search)
                    .onSubmit { Task { await find(pick) } }
                if pick.wrappedValue.isSearching {
                    ProgressView()
                } else {
                    Button("Find") { Task { await find(pick) } }
                        .disabled(pick.wrappedValue.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let found = pick.wrappedValue.found {
                Label(found.name, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else if let problem = pick.wrappedValue.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// Looks the address up with Apple Maps (the typed text goes to Apple) and keeps the best match.
    private func find(_ pick: Binding<AddressPick>) async {
        let text = pick.wrappedValue.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        pick.wrappedValue.isSearching = true
        pick.wrappedValue.problem = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = [.address, .pointOfInterest]
        let item = try? await MKLocalSearch(request: request).start().mapItems.first
        pick.wrappedValue.isSearching = false
        if let item {
            let spot = item.location.coordinate
            pick.wrappedValue.found = RouteStop(name: item.name ?? text, latitude: spot.latitude, longitude: spot.longitude)
        } else {
            pick.wrappedValue.found = nil
            pick.wrappedValue.problem = "Nothing found. Check the address, or you may be offline."
        }
    }

    private var roadSection: some View {
        Section {
            switch road {
            case .none:
                Button {
                    Task { await showRoadRoute() }
                } label: {
                    Label("Show Road Route", systemImage: "road.lanes")
                }
                .disabled(plan.legs == nil)
            case .loading:
                HStack {
                    ProgressView()
                    Text("Finding the route…")
                        .foregroundStyle(.secondary)
                }
            case .shown(let routes, let failed):
                LabeledContent("Distance", value: Geo.milesText(routes.reduce(0) { $0 + $1.distance } / Geo.metersPerMile))
                LabeledContent("Time", value: Duration.seconds(routes.reduce(0) { $0 + $1.expectedTravelTime })
                    .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                if failed > 0 {
                    Text(failed == 1 ? "1 part couldn't be routed, so it isn't counted or drawn." : "\(failed) parts couldn't be routed, so they aren't counted or drawn.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Road route")
        } footer: {
            Text("From Apple Maps, by road or on foot. It needs a connection, and sends the stops to Apple when you tap it.")
        }
    }

    private var openSection: some View {
        let googleURLs = plan.googleURLs
        return Section {
            if let apple = plan.appleURL {
                Link(destination: apple) {
                    Label("Open in Apple Maps", systemImage: "map")
                }
            }
            ForEach(Array(googleURLs.enumerated()), id: \.offset) { index, url in
                Link(destination: url) {
                    Label(googleURLs.count == 1 ? "Open in Google Maps" : "Google Maps, part \(index + 1) of \(googleURLs.count)",
                          systemImage: "globe.americas")
                }
            }
        } header: {
            Text("Open the route")
        } footer: {
            Text(googleURLs.count > 1
                 ? "Apple Maps takes the whole route. Google Maps takes up to \(RoutePlan.googleMaxWaypoints) stops between its start and end, so this route opens in parts, each starting where the last ended."
                 : "The stops go to the Maps app you choose when you tap it.")
        }
    }

    // MARK: Road route

    /// One directions request per leg, in order. A leg that fails is skipped rather than failing
    /// the lot. Stops if the route changes meanwhile.
    private func showRoadRoute() async {
        let requested = plan
        guard let legs = requested.legs else { return }
        road = .loading
        var from = legs.source.map(mapItem) ?? MKMapItem.forCurrentLocation()
        var routes: [MKRoute] = []
        var failed = 0
        for stop in legs.waypoints + [legs.destination] {
            let to = mapItem(stop)
            let request = MKDirections.Request()
            request.source = from
            request.destination = to
            request.transportType = requested.mode == .walking ? .walking : .automobile
            if let route = try? await MKDirections(request: request).calculate().routes.first {
                routes.append(route)
            } else {
                failed += 1
            }
            guard plan == requested else { return }
            from = to
        }
        road = .shown(routes, failedLegs: failed)
    }

    private func mapItem(_ stop: RouteStop) -> MKMapItem {
        MKMapItem(location: CLLocation(latitude: stop.latitude, longitude: stop.longitude), address: nil)
    }
}
