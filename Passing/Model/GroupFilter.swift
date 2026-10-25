import Foundation

/// Which pins the review list (and its exports) show.
enum GroupFilter: Hashable {
    case all
    /// Pins and notes not yet marked Reviewed, from any source and in any group. A smart list
    /// rather than a group, so a pin can be in "Road trip" and still need review.
    case needsReview
    /// Pins that aren't in any group.
    case ungrouped
    /// Pins in the group with this ID.
    case group(UUID)

    /// Whether a pin in the group with this ID (nil for no group) is shown.
    func includes(groupID: UUID?, isReviewed: Bool) -> Bool {
        switch self {
        case .all: return true
        case .needsReview: return !isReviewed
        case .ungrouped: return groupID == nil
        case .group(let id): return groupID == id
        }
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
