import SwiftData
import SwiftUI

/// Everything you've marked, newest first, grouped by day.
struct PinsListView: View {
    @Query(sort: \Pin.createdAt, order: .reverse) private var pins: [Pin]
    @AppStorage(SettingsKey.keepForever) private var keepForever = false
    @AppStorage(SettingsKey.preferredMaps) private var preferredMaps: MapsApp = .apple
    @Environment(\.openURL) private var openURL
    @State private var confirmingDeleteAll = false

    var body: some View {
        List {
            if !keepForever && !pins.isEmpty {
                Section {
                    Label("Pins are cleared 7 days after you drop them. Star a pin to keep it, or turn on “Keep pins forever” in Settings.", systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(pinsByDay[day] ?? []) { pin in
                        NavigationLink {
                            PinDetailView(pin: pin)
                        } label: {
                            PinRow(pin: pin)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                openURL(MapLinks.url(for: pin, in: preferredMaps))
                            } label: {
                                Label(preferredMaps.title, systemImage: "map")
                            }
                            .tint(.blue)
                            Button {
                                pin.isStarred.toggle()
                                PinStore.save()
                            } label: {
                                Label(pin.isStarred ? "Unstar" : "Star", systemImage: pin.isStarred ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                PinStore.delete(pin)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(title(for: day))
                }
            }
        }
        .overlay {
            if pins.isEmpty {
                ContentUnavailableView(
                    "No pins yet",
                    systemImage: "mappin.slash",
                    description: Text("Tap the drive screen when you pass something you want to look up later.")
                )
            }
        }
        .navigationTitle("Pins")
        .toolbar {
            if !pins.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete All Pins", systemImage: "trash", role: .destructive) {
                            confirmingDeleteAll = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Delete all pins?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete All Pins", role: .destructive) {
                PinStore.deleteAll()
            }
        } message: {
            Text("This also deletes starred pins.")
        }
    }

    private var pinsByDay: [Date: [Pin]] {
        Dictionary(grouping: pins) { Calendar.current.startOfDay(for: $0.createdAt) }
    }

    private var days: [Date] {
        pinsByDay.keys.sorted(by: >)
    }

    private func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct PinRow: View {
    let pin: Pin

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(pin.title)
                    .font(.headline)
                    .foregroundStyle(pin.note.isEmpty ? Color.secondary : Color.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !pin.placeName.isEmpty {
                    Text(pin.placeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if pin.isStarred {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let time = pin.createdAt.formatted(date: .omitted, time: .shortened)
        return pin.whereSummary.isEmpty ? time : "\(time) · \(pin.whereSummary)"
    }

    private var icon: String {
        if let zone = pin.zone {
            return zone.isLeft ? "arrow.left.circle.fill" : "arrow.right.circle.fill"
        }
        if pin.milesBack > 0 {
            return "arrow.uturn.backward.circle.fill"
        }
        return "mappin.circle.fill"
    }
}
