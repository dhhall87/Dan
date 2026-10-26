import Foundation
import SwiftData

/// The one SwiftData store, kept in the App Group container so the app, Siri intents and the
/// widget extension all read and write the same pins.
@MainActor
enum SharedStore {
    enum State {
        /// The shared App Group store. The normal case.
        case shared
        /// No App Group on this build (it isn't set up), so pins live in this process's own store.
        /// Settings explains, and the widgets show "Not set up".
        case appOnly
        /// The App Group is set up but its database wouldn't open. Passing doesn't switch to another
        /// database, because pins saved there would never reach the shared one. It runs on an empty
        /// in-memory store instead, refuses to save (so every capture says it wasn't saved), and tries
        /// the shared store again on the next launch.
        case unavailable
    }

    /// Thrown by the capture save path while the shared store is unavailable.
    struct UnavailableError: Error {}

    /// Which store opened. Reading it opens the store first if needed.
    static var state: State { opened.state }

    static var isUsingAppGroup: Bool { state == .shared }

    /// False only when the App Group's database couldn't be opened.
    static var canSave: Bool { state != .unavailable }

    static var container: ModelContainer { opened.container }

    private static let opened: (container: ModelContainer, state: State) = {
        let started = Date.now
        let result = open()
        DriveLog.record(DriveLogEntry(
            at: .now, kind: .storeOpened, outcome: "\(result.state)",
            seconds: Date.now.timeIntervalSince(started), count: result.tries
        ))
        return (result.container, result.state)
    }()

    private static func open() -> (container: ModelContainer, state: State, tries: Int) {
        let schema = Schema([Pin.self, PinGroup.self])
        if AppGroup.isAvailable, let identifier = AppGroup.identifier {
            let configuration = ModelConfiguration(
                "Passing",
                schema: schema,
                groupContainer: .identifier(identifier),
                cloudKitDatabase: .none
            )
            // Right after an update that changes the pin model, the app and the widget can open the
            // store at the same moment, and one may find it busy while the other upgrades it. Give it
            // a few tries.
            for attempt in 1...3 {
                do {
                    return (try ModelContainer(for: schema, configurations: configuration), .shared, attempt)
                } catch {
                    print("Passing: couldn't open the App Group store (try \(attempt) of 3): \(error)")
                    if attempt < 3 { Thread.sleep(forTimeInterval: 0.5) }
                }
            }
            print("Passing: the App Group store won't open; saving is off until the next launch.")
            return (memoryContainer(schema), .unavailable, 3)
        }
        do {
            let configuration = ModelConfiguration("Passing", schema: schema, groupContainer: .none, cloudKitDatabase: .none)
            return (try ModelContainer(for: schema, configurations: configuration), .appOnly, 1)
        } catch {
            fatalError("Passing: couldn't open the pin database: \(error)")
        }
    }

    static var context: ModelContext { container.mainContext }

    /// The capture save path: refuses while the shared store is unavailable, so nothing is reported
    /// saved that only lives in memory. `sharedOnly` (the widget extension) also refuses the
    /// no-App-Group store, because pins saved there would never reach the app.
    static func save(_ context: ModelContext, sharedOnly: Bool = false) throws {
        guard sharedOnly ? isUsingAppGroup : canSave else { throw UnavailableError() }
        try context.save()
    }

    private static func memoryContainer(_ schema: Schema) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Passing: couldn't open even an in-memory store: \(error)")
        }
    }
}
