import Foundation
import SwiftData

/// A named folder for pins in the review list, like "Road trip" or "Houses to check". A pin is in
/// at most one group, and deleting a group never deletes its pins: they just leave the group.
@Model
final class PinGroup {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \Pin.group)
    var pins: [Pin] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
