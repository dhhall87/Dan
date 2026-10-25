import Foundation
import SwiftData

/// The one database shared by the phone screen, CarPlay and Siri.
@MainActor
enum PinStore {
    /// Pins older than this are cleared out unless "Keep pins forever" is on or the pin is starred.
    static let retention: TimeInterval = 7 * 24 * 60 * 60

    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Pin.self)
        } catch {
            fatalError("Couldn't open the RoadPin database: \(error)")
        }
    }()

    static var context: ModelContext { container.mainContext }

    static func insert(_ pin: Pin) {
        context.insert(pin)
        save()
    }

    static func save() {
        do {
            try context.save()
        } catch {
            print("RoadPin: save failed: \(error)")
        }
    }

    static func delete(_ pin: Pin) {
        context.delete(pin)
        save()
    }

    static func deleteAll() {
        let pins = (try? context.fetch(FetchDescriptor<Pin>())) ?? []
        for pin in pins {
            context.delete(pin)
        }
        save()
    }

    static func recentPins(limit: Int) -> [Pin] {
        var descriptor = FetchDescriptor<Pin>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The weekly clear-out. Runs whenever the app, CarPlay or Siri starts using the database.
    static func purgeExpired(now: Date = .now) {
        guard !AppSettings.keepForever else { return }
        let cutoff = now.addingTimeInterval(-retention)
        let descriptor = FetchDescriptor<Pin>(predicate: #Predicate { pin in
            pin.createdAt < cutoff && pin.isStarred == false
        })
        let expired = (try? context.fetch(descriptor)) ?? []
        guard !expired.isEmpty else { return }
        for pin in expired {
            context.delete(pin)
        }
        save()
    }
}
