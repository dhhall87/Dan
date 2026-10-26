import Foundation

/// Which pins the review list (and its exports) show.
enum GroupFilter: Hashable {
    case all
    /// Widget, Control Center and Apple Watch pins not yet marked Reviewed (`Pin.needsReview`), in any group.
    /// A smart list rather than a group, so a pin can be in "Road trip" and still need review.
    case needsReview
    /// Pins that aren't in any group.
    case ungrouped
    /// Pins in the group with this ID.
    case group(UUID)

    /// Whether a pin in the group with this ID (nil for no group) is shown.
    func includes(groupID: UUID?, needsReview: Bool) -> Bool {
        switch self {
        case .all: return true
        case .needsReview: return needsReview
        case .ungrouped: return groupID == nil
        case .group(let id): return groupID == id
        }
    }
}

enum GroupOrder {
    /// `items` with the ones at `source` moved to before `destination`, as a List's drag reports
    /// it (`destination` counts positions in the list before the move).
    static func moved<Item>(_ items: [Item], fromOffsets source: IndexSet, toOffset destination: Int) -> [Item] {
        let moving = source.sorted().filter { $0 < items.count }.map { items[$0] }
        var rest = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = min(max(destination - source.filter { $0 < destination }.count, 0), rest.count)
        rest.insert(contentsOf: moving, at: insertAt)
        return rest
    }
}

enum GroupNaming {
    static let maxLength = 40

    /// The name to save, or nil if it's blank or another group already has it (ignoring case).
    /// `existing` should leave out the group being renamed.
    static func clean(_ name: String, existing: [String]) -> String? {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !trimmed.isEmpty else { return nil }
        let taken = existing.contains { $0.compare(trimmed, options: .caseInsensitive) == .orderedSame }
        return taken ? nil : trimmed
    }
}
