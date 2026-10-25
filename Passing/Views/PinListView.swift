import SwiftData
import SwiftUI

/// Review list: everything you've pinned, newest first, grouped by day.
struct PinListView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt == nil }, sort: \Pin.capturedAt, order: .reverse)
    private var pins: [Pin]
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false
    /// A plain count rather than a second live query: Recently Deleted has its own.
    @State private var recentlyDeletedCount = 0
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    var body: some View {
        List {
            if pins.isEmpty {
                ContentUnavailableView(
                    "No pins yet",
                    systemImage: "mappin.slash",
                    description: Text("Tap the capture screen when you pass something you want to look up later.")
                )
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(pinsByDay[day] ?? []) { pin in
                        NavigationLink(value: pin) {
                            PinRow(pin: pin, keepIndefinitely: keepIndefinitely)
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
        .navigationTitle("Pins")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button("Export \(format.title)") { export(format) }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(pins.isEmpty)
            }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
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
    }

    private func refreshRecentlyDeletedCount() {
        let descriptor = FetchDescriptor<Pin>(predicate: #Predicate { $0.deletedAt != nil })
        recentlyDeletedCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    private var pinsByDay: [Date: [Pin]] {
        Dictionary(grouping: pins) { Calendar.current.startOfDay(for: $0.capturedAt) }
    }

    private var days: [Date] {
        pinsByDay.keys.sorted(by: >)
    }

    private var exportErrorShown: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private func export(_ format: ExportFormat) {
        do {
            exportFile = ExportFile(url: try ExportService.exportActivePins(as: format))
        } catch {
            exportError = error.localizedDescription
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
        return ([time] + [pin.milesBackText, pin.sideAndDistance].compactMap { $0 }).joined(separator: " · ")
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
