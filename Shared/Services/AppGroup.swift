import Foundation

/// The App Group that lets the app and the widget extension share pins and a few notes.
enum AppGroup {
    /// From the `PassingAppGroup` key in each target's Info.plist (Support/Info.plist and
    /// Support/PassingWidget-Info.plist). Must match the App Group in Signing & Capabilities.
    static let identifier: String? = {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "PassingAppGroup") as? String,
              !identifier.isEmpty
        else { return nil }
        return identifier
    }()

    /// False when this build can't reach the shared container (the App Group isn't set up).
    /// Checked once, since it can't change while Passing runs.
    static let isAvailable: Bool = {
        guard let identifier else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }()

    /// Settings both processes can read. Nil when the App Group isn't set up. One instance for the
    /// whole process, rather than a new one on every read (the GPS pill, the drive log and the
    /// privacy switch read it often). Opening it makes iOS print a harmless "Couldn't read values
    /// in CFPrefsPlistSource … kCFPreferencesAnyUser" line in Xcode's console; values still work.
    static let defaults: UserDefaults? = {
        guard isAvailable, let identifier else { return nil }
        return UserDefaults(suiteName: identifier)
    }()
}
