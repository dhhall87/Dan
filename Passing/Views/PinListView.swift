import SwiftData
import SwiftUI

/// Review list: everything you've pinned, newest first, grouped by day. It can show one group at
/// a time, and switch to a map of the same pins. Exports follow what's shown.
struct PinListView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt == nil }, sort: \Pin.capturedAt, order: .reverse)
    private var pins: [Pin]
    @Query(sort: \PinGroup.name) private var groups: [PinGroup]
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false
    /// A plain count rather than a second live query: Recently Deleted has its own.
    @State private var recentlyDeletedCount = 0
    @State private var filter: GroupFilter = .all
    @State private var showsMap = false
    @State private var managingGroups = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    var body: some View {
        Group {
            if showsMap {
                // A new map for each filter, so it zooms to fit the pins being shown.
                PinsMapView(pins: shownPins)
                    .id(filter)
            } else {
                list
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsMap.toggle()
                } label: {
                    Label(showsMap ? "List" : "Map", systemImage: showsMap ? "list.bullet" : "map")
                }
                groupMenu
                exportMenu
            }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .sheet(isPresented: $managingGroups) {
            GroupsView()
        }
        .alert("Couldn't export pins", isPresented: exportErrorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .onAppear {
            // Catch up on anything that expired while this screen was closed.
            RetentionService.shared.run()
            refreshRecentlyDeletedCount()
        }
        .onChange(of: pins.count) {
            refreshRecentlyDeletedCount()
        }
        .onChange(of: groups.map(\.id)) {
            // The group being shown was deleted: go back to everything.
            if case .group(let id) = filter, !groups.contains(where: { $0.id == id }) {
                filter = .all
            }
        }
        .task(id: pins.count) {
            // Town names, a few at a time, for pins that don't have one yet.
            await PlaceNameService.shared.fillMissing(in: pins)
        }
    }

    // MARK: List

    private var list: some View {
        List {
            if shownPins.isEmpty {
                if filter == .all {
                    ContentUnavailableView(
                        "No pins yet",
                        systemImage: "mappin.slash",
                        description: Text("Tap the capture screen when you pass something you want to look up later.")
                    )
                } else {
                    ContentUnavailableView(
                        "Nothing here",
                        systemImage: "folder",
                        description: Text("Touch and hold a pin in All Pins, then choose Group, to file it here.")
                    )
                }
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(pinsByDay[day] ?? []) { pin in
                        row(for: pin)
                    }
                } header: {
                    Text(title(for: day))
                }
            }
            Section {
                NavigationLink(value: Route.recentlyDeleted) {
                    LabeledContent {
                        Text("\(recentlyDeletedCount)")
                    } label: {
                        Label("Recently Deleted", systemImage: "trash")
                    }
                }
            } footer: {
                Text(keepIndefinitely
                     ? "Pins are kept until you delete them."
                     : "Pins move to Recently Deleted 7 days after you pin them. Swipe right to keep one.")
            }
        }
    }

    private func row(for pin: Pin) -> some View {
        NavigationLink(value: pin) {
            PinRow(pin: pin, keepIndefinitely: keepIndefinitely, showsGroup: filter == .all)
        }
        .swipeActions(edge: .leading) {
            Button {
                pin.isKept.toggle()
                try? context.save()
            } label: {
                Label(pin.isKept ? "Unkeep" : "Keep", systemImage: pin.isKept ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                RetentionService.shared.moveToRecentlyDeleted(pin)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Picker(selection: groupSelection(for: pin)) {
                Text("No Group").tag(UUID?.none)
                ForEach(groups) { group in
                    Text(group.name).tag(UUID?.some(group.id))
                }
            } label: {
                Label("Group", systemImage: "folder")
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: Toolbar menus

    private var groupMenu: some View {
        Menu {
            Picker("Show", selection: $filter) {
                Text("All Pins").tag(GroupFilter.all)
                Text("Not in a Group").tag(GroupFilter.ungrouped)
                ForEach(groups) { group in
                    Text(group.name).tag(GroupFilter.group(group.id))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button {
                managingGroups = true
            } label: {
                Label("Manage Groups…", systemImage: "folder.badge.gearshape")
            }
        } label: {
            Label("Groups", systemImage: filter == .all ? "folder" : "folder.fill")
        }
    }

    private var exportMenu: some View {
        Menu {
            Section(filter == .all ? "All pins" : "Pins shown: \(title)") {
                ForEach(ExportFormat.allCases) { format in
                    Button("Export \(format.title)") { export(format) }
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(shownPins.isEmpty)
    }

    // MARK: Helpers

    private var shownPins: [Pin] {
        pins.filter { filter.includes(groupID: $0.group?.id) }
    }

    private var shownGroup: PinGroup? {
        guard case .group(let id) = filter else { return nil }
        return groups.first { $0.id == id }
    }

    private var title: String {
        switch filter {
        case .all: return "Pins"
        case .ungrouped: return "Not in a Group"
        case .group: return shownGroup?.name ?? "Pins"
        }
    }

    private func groupSelection(for pin: Pin) -> Binding<UUID?> {
        Binding(
            get: { pin.group?.id },
            set: { id in
                PinGroups.move(pin, to: groups.first { $0.id == id }, in: context)
            }
        )
    }

    private func refreshRecentlyDeletedCount() {
        let descriptor = FetchDescriptor<Pin>(predicate: #Predicate { $0.deletedAt != nil })
        recentlyDeletedCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    private var pinsByDay: [Date: [Pin]] {
        Dictionary(grouping: shownPins) { Calendar.current.startOfDay(for: $0.capturedAt) }
    }

    private var days: [Date] {
        pinsByDay.keys.sorted(by: >)
    }

    private var exportErrorShown: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private func export(_ format: ExportFormat) {
        do {
            exportFile = ExportFile(url: try ExportService.exportActivePins(as: format, filter: filter, groupName: groupNameForExport))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var groupNameForExport: String? {
        switch filter {
        case .all: return nil
        case .ungrouped: return "Not in a group"
        case .group: return shownGroup?.name
        }
    }

    private func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct PinRow: View {
    let pin: Pin
    var keepIndefinitely = false
    /// Off when the list is already showing a single group.
    var showsGroup = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(pin.displayLabel)
                    .font(.headline)
                    .foregroundStyle(pin.label?.isEmpty == false ? Color.primary : Color.secondary)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(PinFormat.accuracy(of: pin))
                    .font(.caption)
                    .foregroundStyle(pin.hasLocation ? Color.secondary : Color.orange)
                if showsGroup, let group = pin.group {
                    Label(group.name, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let expiry = RetentionPolicy.expiryText(capturedAt: pin.capturedAt, isKept: pin.isKept, keepIndefinitely: keepIndefinitely, now: AppClock.now) {
                    Text(expiry)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                if pin.isKept {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Kept")
                }
                if pin.isReviewed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Reviewed")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var details: String {
        let time = pin.capturedAt.formatted(date: .omitted, time: .shortened)
        return ([time] + [pin.milesBackText, pin.sideAndDistance, pin.placeName].compactMap { $0 }).joined(separator: " · ")
    }

    private var icon: String {
        if pin.milesBack > 0 { return "arrow.uturn.backward.circle.fill" }
        switch pin.side {
        case .left: return "arrow.up.left.circle.fill"
        case .right: return "arrow.up.right.circle.fill"
        case .unknown: return "mappin.circle.fill"
        }
    }
}

enum PinFormat {
    /// "±8 m", "±40 m · approximate", or "No location".
    static func accuracy(of pin: Pin) -> String {
        guard pin.hasLocation, let accuracy = pin.horizontalAccuracy else { return "No location" }
        let meters = "±\(Int(accuracy.rounded())) m"
        return pin.isApproximate ? "\(meters) · approximate" : meters
    }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}
