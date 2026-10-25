import Foundation
import SwiftData

/// Creating, renaming and deleting groups, and filing pins in them.
@MainActor
enum PinGroups {
    static func all(in context: ModelContext) -> [PinGroup] {
        (try? context.fetch(FetchDescriptor<PinGroup>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    /// Makes a new group. Returns nil if the name is blank or already used.
    @discardableResult
    static func create(named name: String, in context: ModelContext, now: Date = .now) -> PinGroup? {
        guard let name = GroupNaming.clean(name, existing: all(in: context).map(\.name)) else { return nil }
        let group = PinGroup(name: name, createdAt: now)
        context.insert(group)
        save(context)
        return group
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

    /// Files the pin in `group`, or takes it out of its group when `group` is nil.
    static func move(_ pin: Pin, to group: PinGroup?, in context: ModelContext) {
        pin.group = group
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
