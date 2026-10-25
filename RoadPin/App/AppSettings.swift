import Foundation

enum PinMode: String, CaseIterable, Identifiable {
    /// Touch anywhere to drop a pin.
    case oneButton
    /// Four columns: far left, near left, near right, far right.
    case zones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneButton: return "One big button"
        case .zones: return "Four zones"
        }
    }
}

enum MapsApp: String, CaseIterable, Identifiable {
    case apple
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple Maps"
        case .google: return "Google Maps"
        }
    }
}

/// UserDefaults keys shared by the phone UI (@AppStorage) and the CarPlay / Siri code.
/// The @AppStorage defaults in the views must match `AppSettings.defaultValues`.
enum SettingsKey {
    static let mode = "pinMode"
    static let askWhatToLookUp = "askWhatToLookUp"
    static let speakConfirmation = "speakConfirmation"
    static let keepForever = "keepPinsForever"
    static let preferredMaps = "preferredMaps"
}

enum AppSettings {
    static let defaultValues: [String: Any] = [
        SettingsKey.mode: PinMode.zones.rawValue,
        SettingsKey.askWhatToLookUp: true,
        SettingsKey.speakConfirmation: true,
        SettingsKey.keepForever: false,
        SettingsKey.preferredMaps: MapsApp.apple.rawValue,
    ]

    private static let defaults: UserDefaults = {
        let defaults = UserDefaults.standard
        defaults.register(defaults: defaultValues)
        return defaults
    }()

    static var mode: PinMode {
        PinMode(rawValue: defaults.string(forKey: SettingsKey.mode) ?? "") ?? .zones
    }

    static var askWhatToLookUp: Bool { defaults.bool(forKey: SettingsKey.askWhatToLookUp) }

    static var speakConfirmation: Bool { defaults.bool(forKey: SettingsKey.speakConfirmation) }

    static var keepForever: Bool { defaults.bool(forKey: SettingsKey.keepForever) }

    static var preferredMaps: MapsApp {
        MapsApp(rawValue: defaults.string(forKey: SettingsKey.preferredMaps) ?? "") ?? .apple
    }
}
