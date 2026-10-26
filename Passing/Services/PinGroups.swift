import Foundation
import SwiftData

/// Creating, renaming and deleting groups, and filing pins in them.
@MainActor
enum PinGroups {
    static func all(in context: ModelContext) -> [PinGroup] {
        (try? context.fetch(FetchDescriptor<PinGroup>(sortBy: PinGroup.displayOrder))) ?? []
    }

    /// Makes a new group. Returns nil if the name is blank or already used.
    @discardableResult
    static func create(named name: String, in context: ModelContext, now: Date = .now) -> PinGroup? {
        let existing = all(in: context)
        guard let name = GroupNaming.clean(name, existing: existing.map(\.name)) else { return nil }
        let group = PinGroup(name: name, createdAt: now)
        // At the bottom of the list.
        group.sortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        context.insert(group)
        save(context)
        return group
    }

    /// The group with this name (ignoring case and surrounding spaces), if there is one.
    static func named(_ name: String, in context: ModelContext) -> PinGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return all(in: context).first { $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame }
    }

    /// "New Group…" from a menu: makes the group, or returns the existing one if the name is
    /// already used. Nil only for a blank name.
    static func createOrFind(named name: String, in context: ModelContext) -> PinGroup? {
        create(named: name, in: context) ?? named(name, in: context)
    }

    /// A drag in Manage Groups: numbers every group in its new place.
    static func reorder(_ groups: [PinGroup], fromOffsets source: IndexSet, toOffset destination: Int, in context: ModelContext) {
        for (index, group) in GroupOrder.moved(groups, fromOffsets: source, toOffset: destination).enumerated()
        where group.sortOrder != index {
            group.sortOrder = index
        }
        save(context)
    }

    /// Returns false (and changes nothing) if the new name is blank or already used.
    @discardableResult
    static func rename(_ group: PinGroup, to name: String, in context: ModelContext) -> Bool {
        let others = all(in: context).filter { $0.id != group.id }.map(\.name)
        guard let name = GroupNaming.clean(name, existing: others) else { return false }
        group.name = name
        save(context)
        return true
    }

    /// Deletes the group. Its pins stay, just without a group.
    static func delete(_ group: PinGroup, in context: ModelContext) {
        for pin in group.pins {
            pin.group = nil
        }
        context.delete(group)
        save(context)
    }

    /// Files the pin in `group`, or takes it out of its group when `group` is nil. Filing a pin that's
    /// waiting in Needs Review also marks it Reviewed (Dan's request): putting it in a group is the review.
    static func move(_ pin: Pin, to group: PinGroup?, in context: ModelContext) {
        move([pin], to: group, in: context)
    }

    /// Several at once (Select in the Pins list), saved together.
    static func move(_ pins: [Pin], to group: PinGroup?, in context: ModelContext) {
        for pin in pins {
            pin.group = group
            if group != nil, pin.needsReview {
                pin.isReviewed = true
            }
        }
        save(context)
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Passing: couldn't save groups: \(error)")
        }
    }
}
