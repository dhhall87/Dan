import Foundation
import SwiftData

/// A named folder for pins in the review list, like "Road trip" or "Houses to check". A pin is in
/// at most one group, and deleting a group never deletes its pins: they just leave the group.
@Model
final class PinGroup {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    /// Where it goes in group lists, smallest first, set by dragging in Manage Groups. New groups go
    /// at the bottom. Groups from before reordering existed are all 0 and fall back to their names.
    var sortOrder: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \Pin.group)
    var pins: [Pin] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    /// The order groups are listed in everywhere: Dan's order, then by name.
    static var displayOrder: [SortDescriptor<PinGroup>] {
        [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
    }
}
