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
        let schema = Schema([Pin.self])
        if AppGroup.isAvailable, let identifier = AppGroup.identifier {
            do {
                let configuration = ModelConfiguration(
                    "Passing",
                    schema: schema,
                    groupContainer: .identifier(identifier),
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: configuration)
                isUsingAppGroup = true
                return container
            } catch {
                print("Passing: couldn't open the App Group store, using the app's own container: \(error)")
            }
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
