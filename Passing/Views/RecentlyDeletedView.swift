import SwiftData
import SwiftUI

/// Deleted and expired pins wait here for 30 days, then they're gone for good.
///
/// Kept deliberately plain (no tappable rows, one dialog, no toolbar that comes and goes, no
/// clean-up on appear) after the first version froze when opened. The Pins list already runs
/// the clean-up before you get here.
struct RecentlyDeletedView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt != nil })
    private var pins: [Pin]
    @State private var confirmingDeleteAll = false

    private let retention = RetentionService.shared

    var body: some View {
        List {
            Section {
                ForEach(newestFirst) { pin in
                    HStack(spacing: 12) {
                        DeletedPinRow(pin: pin)
                        Spacer(minLength: 0)
                        Button("Recover") {
                            retention.recover(pin)
                        }
                        .buttonStyle(.bordered)
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
                if !pins.isEmpty {
                    Text("Swipe left on a pin to delete it now. Pins here are deleted for good 30 days after they arrive, even with “Keep records indefinitely” on. Recovering a pin that's more than 7 days old also keeps it, so it doesn't expire again.")
                }
            }

            if !pins.isEmpty {
                Section {
                    Button("Delete All Now", role: .destructive) {
                        confirmingDeleteAll = true
                    }
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
        .confirmationDialog("Delete everything in Recently Deleted?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                retention.emptyRecentlyDeleted()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var newestFirst: [Pin] {
        pins.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
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
