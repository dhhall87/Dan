import SwiftData
import SwiftUI

/// Deleted and expired pins wait here for 30 days, then they're gone for good.
struct RecentlyDeletedView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt != nil })
    private var pins: [Pin]
    @State private var selected: Pin?
    @State private var confirmingDeleteAll = false

    private let retention = RetentionService.shared

    var body: some View {
        List {
            if !pins.isEmpty {
                Section {
                    ForEach(newestFirst) { pin in
                        Button {
                            selected = pin
                        } label: {
                            DeletedPinRow(pin: pin)
                        }
                        .tint(Color.primary)
                        .swipeActions(edge: .leading) {
                            Button {
                                retention.recover(pin)
                            } label: {
                                Label("Recover", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                retention.deleteNow(pin)
                            } label: {
                                Label("Delete Now", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("Pins are deleted for good 30 days after they land here, even with “Keep records indefinitely” on. Recovering a pin that's more than 7 days old also keeps it, so it doesn't expire again.")
                }
            }
        }
        .overlay {
            if pins.isEmpty {
                ContentUnavailableView(
                    "Nothing here",
                    systemImage: "trash",
                    description: Text("Deleted and expired pins wait here for 30 days.")
                )
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !pins.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) {
                        confirmingDeleteAll = true
                    }
                }
            }
        }
        .confirmationDialog(selected?.displayLabel ?? "Pin", isPresented: selectionShown, titleVisibility: .visible, presenting: selected) { pin in
            Button("Recover") { retention.recover(pin) }
            Button("Delete Now", role: .destructive) { retention.deleteNow(pin) }
        }
        .confirmationDialog("Delete everything in Recently Deleted?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { retention.emptyRecentlyDeleted() }
        } message: {
            Text("This can't be undone.")
        }
        .onAppear {
            retention.run()
        }
    }

    private var newestFirst: [Pin] {
        pins.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    private var selectionShown: Binding<Bool> {
        Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })
    }
}

private struct DeletedPinRow: View {
    let pin: Pin

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pin.displayLabel)
                .font(.headline)
                .foregroundStyle(pin.label?.isEmpty == false ? Color.primary : Color.secondary)
            Text(details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let deletedAt = pin.deletedAt {
                Text(RetentionPolicy.purgeText(deletedAt: deletedAt, now: AppClock.now))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var details: String {
        let captured = pin.capturedAt.formatted(date: .abbreviated, time: .shortened)
        guard let clue = pin.sideAndDistance else { return captured }
        return "\(captured) · \(clue)"
    }
}
