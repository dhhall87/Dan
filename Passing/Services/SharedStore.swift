import Foundation
import SwiftData

/// The one SwiftData store, kept in the App Group container so the app, Siri intents and the
/// widget extension (later milestones) all read and write the same pins.
@MainActor
enum SharedStore {
    /// From the `PassingAppGroup` key in Support/Info.plist. Must match the App Group in
    /// Signing & Capabilities (see README, "Set up the App Group").
    static let appGroupIdentifier: String? = Bundle.main.object(forInfoDictionaryKey: "PassingAppGroup") as? String

    /// False when the App Group isn't set up on this build, so pins live in the app's own
    /// container instead. Settings shows a warning when this happens.
    private(set) static var isUsingAppGroup = false

    static let container: ModelContainer = {
        let schema = Schema([Pin.self])
        if let identifier = appGroupIdentifier, !identifier.isEmpty,
           FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil {
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
