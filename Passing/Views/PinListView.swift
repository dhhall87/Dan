import SwiftData
import SwiftUI

/// Review list: everything you've pinned, newest first, grouped by day. It can show one group at
/// a time, and switch to a map of the same pins. Exports follow what's shown. Select lets you keep,
/// review, group or delete several pins at once.
struct PinListView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt == nil }, sort: \Pin.capturedAt, order: .reverse)
    private var pins: [Pin]
    @Query(sort: \PinGroup.name) private var groups: [PinGroup]
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false
    @AppStorage(SettingsKey.deleteAfterExport) private var deleteAfterExport = false
    /// A plain count rather than a second live query: Recently Deleted has its own.
    @State private var recentlyDeletedCount = 0
    @State private var filter: GroupFilter
    @State private var showsMap = false
    @State private var managingGroups = false
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    /// What a group made with "New Group…" is for: nothing yet, one pin, or the selected pins.
    @State private var newGroupFor: NewGroupFor?

    private enum NewGroupFor {
        case justMake
        case pin(Pin)
        case selection
    }
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    /// `filter` is where the list starts: All Pins, or Needs Review from a review reminder.
    init(filter: GroupFilter = .all) {
        self.filter = filter
    }
    @State private var addingNote = false
    @State private var noteText = ""

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
        .navigationTitle(isSelecting ? selectionTitle : title)
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button(allShownSelected ? "Deselect All" : "Select All") {
                        selection = allShownSelected ? [] : Set(shownPins.map(\.id))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isSelecting = false
                        selection = []
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    bulkActions
                }
            } else {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Select") {
                        showsMap = false
                        selection = []
                        isSelecting = true
                    }
                    .disabled(shownPins.isEmpty)
                    Button {
                        showsMap.toggle()
                    } label: {
                        Label(showsMap ? "List" : "Map", systemImage: showsMap ? "list.bullet" : "map")
                    }
                    groupMenu
                    exportMenu
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        noteText = ""
                        addingNote = true
                    } label: {
                        // Wider than the round toolbar buttons (about three or four of them), so
                        // it's easy to find and reads as the main action here.
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.pencil")
                            Text("New Note")
                        }
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minWidth: 160)
                    }
                    .accessibilityLabel("New Note")
                }
            }
        }
        .alert("New Note", isPresented: $addingNote) {
            TextField("What did you see?", text: $noteText)
            Button("Save", action: saveNote)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type it, or tap the microphone on the keyboard to dictate.")
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url]) { shared in
                ExportService.removeExportedFiles()
                if shared, deleteAfterExport {
                    deleteExported(file.pinIDs)
                }
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
        .sheet(isPresented: $managingGroups) {
            GroupsView()
        }
        .newGroupAlert(isPresented: newGroupShown, message: newGroupMessage, onCreate: fileNewGroup(for: newGroupFor))
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
        .onChange(of: filter) {
            selection = []
        }
        .onChange(of: needsReviewCount) {
            // Everything reviewed: no reminder should nag about it.
            if needsReviewCount == 0 {
                ReviewReminders.cancel()
            }
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
            if filter == .all, !isSelecting, needsReviewCount > 0 {
                Section {
                    Button {
                        filter = .needsReview
                    } label: {
                        LabeledContent {
                            Text("\(needsReviewCount)")
                        } label: {
                            Label("Needs Review", systemImage: "tray.full")
                        }
                    }
                } footer: {
                    Text("Pins from the widget, CarPlay or Control Center that you haven't marked Reviewed yet.")
                }
            }
            if shownPins.isEmpty {
                if filter == .needsReview {
                    ContentUnavailableView(
                        "All caught up",
                        systemImage: "checkmark.circle",
                        description: Text("Pins you save from the widget, CarPlay or Control Center wait here until you mark them Reviewed: swipe right on one, or open it and turn on Reviewed.")
                    )
                } else if filter == .all {
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
            ForEach(daySections) { section in
                Section {
                    ForEach(section.pins) { pin in
                        row(for: pin)
                            .listRowBackground(rowBackground(for: pin))
                    }
                } header: {
                    DayHeader(title: title(for: section.day), day: section.day, count: section.pins.count)
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

    @ViewBuilder
    private func row(for pin: Pin) -> some View {
        if isSelecting {
            selectableRow(for: pin)
        } else {
            navigableRow(for: pin)
        }
    }

    /// In Select mode a tap ticks the pin instead of opening it.
    private func selectableRow(for pin: Pin) -> some View {
        let isSelected = selection.contains(pin.id)
        return Button {
            if isSelected {
                selection.remove(pin.id)
            } else {
                selection.insert(pin.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                PinRow(pin: pin, keepIndefinitely: keepIndefinitely, showsGroup: showsGroups)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func navigableRow(for pin: Pin) -> some View {
        NavigationLink(value: pin) {
            PinRow(pin: pin, keepIndefinitely: keepIndefinitely, showsGroup: showsGroups)
        }
        .swipeActions(edge: .leading) {
            // A full swipe does the first one: Reviewed in Needs Review, Keep everywhere else.
            if filter == .needsReview {
                reviewedButton(for: pin)
                keepButton(for: pin)
            } else {
                keepButton(for: pin)
                reviewedButton(for: pin)
            }
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
            Button {
                newGroupFor = .pin(pin)
            } label: {
                Label("New Group…", systemImage: "folder.badge.plus")
            }
        }
    }

    // MARK: Select mode

    /// Keep, Reviewed, Group and Delete for every ticked pin. Delete moves them to Recently
    /// Deleted, where they can be recovered for 30 days.
    @ViewBuilder
    private var bulkActions: some View {
        let selected = selectedPins
        let allKept = !selected.isEmpty && selected.allSatisfy(\.isKept)
        let allReviewed = !selected.isEmpty && selected.allSatisfy(\.isReviewed)
        Button {
            for pin in selected { pin.isKept = !allKept }
            try? context.save()
        } label: {
            Label(allKept ? "Unkeep" : "Keep", systemImage: allKept ? "star.slash" : "star")
        }
        .disabled(selected.isEmpty)
        Spacer()
        Button {
            for pin in selected { pin.isReviewed = !allReviewed }
            try? context.save()
        } label: {
            Label(allReviewed ? "Not Reviewed" : "Reviewed", systemImage: allReviewed ? "xmark.circle" : "checkmark.circle")
        }
        .disabled(selected.isEmpty)
        Spacer()
        Menu {
            Button("No Group") {
                PinGroups.move(selected, to: nil, in: context)
            }
            ForEach(groups) { group in
                Button(group.name) {
                    PinGroups.move(selected, to: group, in: context)
                }
            }
            Divider()
            Button {
                newGroupFor = .selection
            } label: {
                Label("New Group…", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("Group", systemImage: "folder")
        }
        .disabled(selected.isEmpty)
        Spacer()
        Button(role: .destructive) {
            RetentionService.shared.moveToRecentlyDeleted(selected)
            selection = []
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(selected.isEmpty)
    }

    private var newGroupShown: Binding<Bool> {
        Binding(get: { newGroupFor != nil }, set: { if !$0 { newGroupFor = nil } })
    }

    /// What to do with the group once it's made. The target is captured now, because the prompt
    /// may clear `newGroupFor` as it closes.
    private func fileNewGroup(for target: NewGroupFor?) -> (PinGroup) -> Void {
        { group in
            switch target {
            case .pin(let pin): PinGroups.move(pin, to: group, in: context)
            case .selection: PinGroups.move(selectedPins, to: group, in: context)
            case .justMake, nil: break
            }
        }
    }

    private var newGroupMessage: String? {
        switch newGroupFor {
        case .pin: return "This pin goes into the new group."
        case .selection: return "The selected pins go into the new group."
        case .justMake, nil: return nil
        }
    }

    private var selectedPins: [Pin] {
        shownPins.filter { selection.contains($0.id) }
    }

    private var allShownSelected: Bool {
        !shownPins.isEmpty && shownPins.allSatisfy { selection.contains($0.id) }
    }

    private var selectionTitle: String {
        let count = selectedPins.count
        return count == 0 ? "Select Pins" : "\(count) Selected"
    }

    /// Widget, CarPlay and Control Center pins still waiting for review get a faint amber tint, so
    /// they stand out in the list. Not in Needs Review itself, where every row is one.
    @ViewBuilder
    private func rowBackground(for pin: Pin) -> some View {
        if pin.needsReview, filter != .needsReview {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                Color.accentColor.opacity(0.12)
            }
        } else {
            Color(.secondarySystemGroupedBackground)
        }
    }

    private func keepButton(for pin: Pin) -> some View {
        Button {
            pin.isKept.toggle()
            try? context.save()
        } label: {
            Label(pin.isKept ? "Unkeep" : "Keep", systemImage: pin.isKept ? "star.slash" : "star")
        }
        .tint(.yellow)
    }

    private func reviewedButton(for pin: Pin) -> some View {
        Button {
            pin.isReviewed.toggle()
            try? context.save()
        } label: {
            Label(pin.isReviewed ? "Not Reviewed" : "Reviewed", systemImage: pin.isReviewed ? "circle" : "checkmark.circle")
        }
        .tint(.green)
    }

    // MARK: Toolbar menus

    private var groupMenu: some View {
        Menu {
            Picker("Show", selection: $filter) {
                Text("All Pins").tag(GroupFilter.all)
                Text("Needs Review").tag(GroupFilter.needsReview)
                Text("Not in a Group").tag(GroupFilter.ungrouped)
                ForEach(groups) { group in
                    Text(group.name).tag(GroupFilter.group(group.id))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button {
                newGroupFor = .justMake
            } label: {
                Label("New Group…", systemImage: "folder.badge.plus")
            }
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
        pins.filter { filter.includes(groupID: $0.group?.id, needsReview: $0.needsReview) }
    }

    private var needsReviewCount: Int {
        pins.reduce(0) { $0 + ($1.needsReview ? 1 : 0) }
    }

    /// Group names on rows, except when the list is already one group.
    private var showsGroups: Bool {
        switch filter {
        case .all, .needsReview: return true
        case .ungrouped, .group: return false
        }
    }

    private var shownGroup: PinGroup? {
        guard case .group(let id) = filter else { return nil }
        return groups.first { $0.id == id }
    }

    private var title: String {
        switch filter {
        case .all: return "Pins"
        case .needsReview: return "Needs Review"
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

    private struct DaySection: Identifiable {
        let day: Date
        let pins: [Pin]
        var id: Date { day }
    }

    /// The shown pins by day, newest day first, grouped in one pass.
    private var daySections: [DaySection] {
        let byDay = Dictionary(grouping: shownPins) { Calendar.current.startOfDay(for: $0.capturedAt) }
        return byDay.keys.sorted(by: >).map { DaySection(day: $0, pins: byDay[$0] ?? []) }
    }

    /// A typed (or keyboard-dictated) note, filed in the group being shown, if any.
    private func saveNote() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        noteText = ""
        guard !text.isEmpty else { return }
        let note = CaptureService.shared.addNote(text)
        if case .group = filter, let group = shownGroup {
            PinGroups.move(note, to: group, in: context)
        }
    }

    private var exportErrorShown: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private func export(_ format: ExportFormat) {
        do {
            let url = try ExportService.exportActivePins(as: format, filter: filter, groupName: groupNameForExport)
            // The export holds exactly the pins shown now (active, in the group being shown).
            exportFile = ExportFile(url: url, pinIDs: Set(shownPins.map(\.id)))
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// "Delete pins after exporting" (off by default): once an export has actually been shared, the
    /// pins in it move to Recently Deleted. Kept (starred) pins stay.
    private func deleteExported(_ ids: Set<UUID>) {
        let exported = pins.filter { ids.contains($0.id) && !$0.isKept }
        RetentionService.shared.moveToRecentlyDeleted(exported)
    }

    private var groupNameForExport: String? {
        switch filter {
        case .all: return nil
        case .needsReview: return "Needs review"
        case .ungrouped: return "Not in a group"
        case .group: return shownGroup?.name
        }
    }

    /// Measured from the same clock as the expiry countdowns, so Settings → Testing's "+ days"
    /// moves earlier pins under Yesterday and older dates.
    private func title(for day: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: AppClock.now)
        if day == today { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

/// A bold day heading over each day's card, so today's and yesterday's pins are told apart at a glance.
private struct DayHeader: View {
    let title: String
    let day: Date
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            if title == "Today" || title == "Yesterday" {
                Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(count == 1 ? "1 pin" : "\(count) pins")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
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
                    .lineLimit(pin.isNote ? 4 : nil)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !pin.isNote {
                    Text(PinFormat.accuracy(of: pin))
                        .font(.caption)
                        .foregroundStyle(pin.lookUpCoordinate != nil ? Color.secondary : Color.orange)
                }
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
                if pin.needsReview {
                    Image(systemName: "tray.full")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Needs review")
                }
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
        if pin.isNote { return "\(time) · Note" }
        return ([time] + [pin.milesBackText, pin.sideAndDistance, pin.placeName].compactMap { $0 }).joined(separator: " · ")
    }

    private var icon: String {
        if pin.isNote { return "note.text" }
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
        let moved = pin.targetSource == .manual
        guard pin.hasLocation, let accuracy = pin.horizontalAccuracy else { return moved ? "Placed by you" : "No location" }
        // Rough pins (Precise location off) in miles, like the rest of the app; GPS precision in meters.
        let distance = accuracy >= 1_000 ? "±" + String(format: "%.1f", accuracy / Geo.metersPerMile) + " mi" : "±\(Int(accuracy.rounded())) m"
        if moved { return "Moved by you · car \(distance)" }
        return pin.isApproximate ? "\(distance) · approximate" : distance
    }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
    /// The pins in the file, for "Delete pins after exporting".
    var pinIDs: Set<UUID> = []
}
