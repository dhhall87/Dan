import MapKit
import SwiftUI
import UIKit

/// Settings → Review Reminders: when Passing reminds you about pins waiting in Needs Review.
struct ReviewRemindersView: View {
    @Environment(\.openURL) private var openURL
    @State private var settings = ReviewReminders.settings
    @State private var notificationsAllowed = true

    var body: some View {
        Form {
            Section {
                Toggle("Remind me", isOn: $settings.isOn)
            } footer: {
                Text("After you save a pin from the widget, CarPlay, Control Center or Apple Watch, Passing reminds you to look at Needs Review. It only reminds you while something is waiting there, and reviewing everything cancels the reminder.")
            }

            if settings.isOn {
                if !notificationsAllowed {
                    Section {
                        Label("Notifications are off for Passing, so reminders can't appear.", systemImage: "bell.slash")
                            .foregroundStyle(.orange)
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }

                Section {
                    Toggle("At a time", isOn: $settings.atTime)
                    if settings.atTime {
                        DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("The next \(timeText) after a widget pin: the next morning, for a drive the evening before.")
                }

                Section {
                    PlaceRow(title: "Work", isOn: $settings.atWork, place: $settings.work)
                    PlaceRow(title: "Home", isOn: $settings.atHome, place: $settings.home)
                } header: {
                    Text("When I arrive")
                } footer: {
                    Text("iOS watches for your arrival itself, so Passing doesn't track you or run in the background. It may take a few minutes after you arrive. Needs Passing's location set to While Using and Precise Location on in iOS Settings. Places stay on this iPhone.")
                }
            }
        }
        .navigationTitle("Review Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if settings.isOn {
                notificationsAllowed = await ReviewReminders.requestPermission()
            }
        }
        .onChange(of: settings) { old, new in
            ReviewReminders.settings = new
            if !new.isOn {
                ReviewReminders.cancel()
                return
            }
            if !old.isOn {
                // Asked here, never on the capture screen.
                Task { notificationsAllowed = await ReviewReminders.requestPermission() }
            }
            // Pins already waiting follow the new choices straight away.
            ReviewReminders.arm(waiting: CaptureService.shared.needsReviewCount())
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: settings.hour, minute: settings.minute)) ?? .now },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.hour = parts.hour ?? 8
                settings.minute = parts.minute ?? 0
            }
        )
    }

    private var timeText: String {
        timeBinding.wrappedValue.formatted(date: .omitted, time: .shortened)
    }
}

/// A saved place with its on/off switch, and a link to set or change it.
private struct PlaceRow: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var place: SavedPlace?

    var body: some View {
        // Shown off until a place is set, since there's nowhere to arrive at yet.
        Toggle(isOn: place == nil ? .constant(false) : $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(place?.name ?? "Not set yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(place == nil)
        NavigationLink(place == nil ? "Set \(title)…" : "Change \(title)…") {
            PlacePickerView(title: title, place: $place, isOn: $isOn)
        }
    }
}

/// Sets a reminder place from where you are now, or from an address search.
struct PlacePickerView: View {
    let title: String
    @Binding var place: SavedPlace?
    @Binding var isOn: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isLocating = false
    @State private var isSearching = false
    @State private var problem: String?

    private let location = LocationProvider.shared

    var body: some View {
        List {
            Section {
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    Label(isLocating ? "Finding where you are…" : "Use My Current Location", systemImage: "location")
                }
                .disabled(isLocating)
            } footer: {
                Text("Easiest while you're at \(title.lowercased()). Uses this iPhone's GPS only.")
            }

            Section {
                TextField("Address", text: $query)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if isSearching {
                    ProgressView()
                }
                ForEach(results, id: \.self) { item in
                    Button {
                        choose(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unnamed place")
                                .foregroundStyle(.primary)
                            if let area = item.addressRepresentations?.cityWithContext {
                                Text(area)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Or search for an address")
            } footer: {
                Text("The search goes to Apple Maps. Only the place you pick is saved, on this iPhone.")
            }

            if let problem {
                Section {
                    Text(problem)
                        .foregroundStyle(.orange)
                }
            }

            if place != nil {
                Section {
                    Button("Remove \(title)", role: .destructive) {
                        place = nil
                        isOn = false
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func useCurrentLocation() async {
        problem = nil
        guard location.isAuthorized else {
            problem = "Passing doesn't have location access yet. It asks the first time you save a pin, or you can allow it in iOS Settings."
            return
        }
        guard !location.isPreciseLocationOff else {
            problem = "Precise Location is off for Passing in iOS Settings, so it can't tell exactly where you are."
            return
        }
        isLocating = true
        let fix: CLLocation?
        if let fresh = location.freshFix() {
            fix = fresh
        } else {
            fix = await location.nextUsableFix(timeout: 15)
        }
        isLocating = false
        guard let fix else {
            problem = "Couldn't get a GPS reading. Try again, or search for the address."
            return
        }
        let day = Date.now.formatted(date: .abbreviated, time: .omitted)
        save(SavedPlace(name: "Set here on \(day)", latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude))
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        problem = nil
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = [.address, .pointOfInterest]
        let response = try? await MKLocalSearch(request: request).start()
        isSearching = false
        results = response?.mapItems ?? []
        if results.isEmpty {
            problem = "Nothing found. Check the address, or you may be offline."
        }
    }

    private func choose(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        save(SavedPlace(name: item.name ?? query, latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private func save(_ newPlace: SavedPlace) {
        place = newPlace
        isOn = true
        dismiss()
    }
}
