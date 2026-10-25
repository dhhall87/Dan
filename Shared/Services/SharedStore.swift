import Foundation
import SwiftData

/// The one SwiftData store, kept in the App Group container so the app, Siri intents and the
/// widget extension all read and write the same pins.
@MainActor
enum SharedStore {
    /// False when the App Group isn't set up on this build, so pins live in this process's own
    /// container instead. Settings and the widget show a warning when this happens.
    private(set) static var isUsingAppGroup = false

    static let container: ModelContainer = {
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
            // a few tries before falling back, because the fallback store can't see existing pins.
            for attempt in 1...3 {
                do {
                    let container = try ModelContainer(for: schema, configurations: configuration)
                    isUsingAppGroup = true
                    return container
                } catch {
                    print("Passing: couldn't open the App Group store (try \(attempt) of 3): \(error)")
                    if attempt < 3 { Thread.sleep(forTimeInterval: 0.5) }
                }
            }
            print("Passing: using the app's own container instead of the App Group store.")
        }
        do {
            let configuration = ModelConfiguration("Passing", schema: schema, groupContainer: .none, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Passing: couldn't open the pin database: \(error)")
        }
    }()

    static var context: ModelContext { container.mainContext }
}
