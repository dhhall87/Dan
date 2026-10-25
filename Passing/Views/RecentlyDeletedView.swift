import SwiftData
import SwiftUI

/// Deleted and expired pins wait here for 30 days, then they're gone for good. Select lets you
/// recover or delete several at once.
///
/// Kept deliberately plain (no navigation from rows, no clean-up on appear) after the first version
/// froze when opened. The Pins list already runs the clean-up before you get here.
struct RecentlyDeletedView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt != nil })
    private var pins: [Pin]
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    /// One confirmation dialog for both kinds of permanent delete.
    @State private var confirming: PermanentDelete?

    private enum PermanentDelete {
        case all
        case selected
    }

    private let retention = RetentionService.shared

    var body: some View {
        List {
            Section {
                ForEach(newestFirst) { pin in
                    if isSelecting {
                        selectableRow(for: pin)
                    } else {
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
                }
            } footer: {
                if !pins.isEmpty {
                    Text("Swipe left on a pin to delete it now, or tap Select to recover or delete several. Pins here are deleted for good 30 days after they arrive, even with “Keep records indefinitely” on. Recovering a pin that's more than 7 days old also keeps it, so it doesn't expire again.")
                }
            }

            if !pins.isEmpty, !isSelecting {
                Section {
                    Button("Delete All Now", role: .destructive) {
                        confirming = .all
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
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionBar
            }
        }
        .navigationTitle(isSelecting ? selectionTitle : "Recently Deleted")
        .toolbar {
            // One button that changes its title, rather than toolbar items that come and go.
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "Done" : "Select") {
                    isSelecting.toggle()
                    selection = []
                }
                .disabled(pins.isEmpty && !isSelecting)
            }
        }
        .onChange(of: pins.count) {
            if pins.isEmpty {
                isSelecting = false
                selection = []
            }
        }
        // `presenting:` hands the choice to the button as it was when the dialog opened, because the
        // dialog clears `confirming` as it closes.
        .confirmationDialog(confirmTitle, isPresented: confirmingShown, titleVisibility: .visible, presenting: confirming) { target in
            Button("Delete", role: .destructive) {
                switch target {
                case .all: retention.emptyRecentlyDeleted()
                case .selected: retention.deleteNow(selectedPins)
                }
                selection = []
            }
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    // MARK: Select

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
                DeletedPinRow(pin: pin)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectionBar: some View {
        let count = selectedPins.count
        return HStack(spacing: 12) {
            Button(allSelected ? "Deselect All" : "Select All") {
                selection = allSelected ? [] : Set(pins.map(\.id))
            }
            Spacer()
            Button("Recover") {
                retention.recover(selectedPins)
                selection = []
            }
            .buttonStyle(.borderedProminent)
            .disabled(count == 0)
            Button("Delete Now", role: .destructive) {
                confirming = .selected
            }
            .buttonStyle(.bordered)
            .disabled(count == 0)
        }
        .padding()
        .background(.bar)
    }

    private var selectedPins: [Pin] {
        pins.filter { selection.contains($0.id) }
    }

    private var allSelected: Bool {
        !pins.isEmpty && pins.allSatisfy { selection.contains($0.id) }
    }

    private var selectionTitle: String {
        let count = selectedPins.count
        return count == 0 ? "Select Pins" : "\(count) Selected"
    }

    private var confirmTitle: String {
        switch confirming {
        case .all: return "Delete everything in Recently Deleted?"
        case .selected:
            let count = selectedPins.count
            return count == 1 ? "Delete 1 pin now?" : "Delete \(count) pins now?"
        case nil: return ""
        }
    }

    private var confirmingShown: Binding<Bool> {
        Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
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
