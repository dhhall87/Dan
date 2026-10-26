import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    /// The whole screen is one capture button.
    case quick
    /// Far left | Near left | car | Near right | Far right.
    case fourZone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Simple"
        case .fourZone: return "Four zones"
        }
    }
}

/// UserDefaults keys shared by the views (@AppStorage) and the services.
/// The @AppStorage defaults in the views must match `AppSettings.defaultValues`.
enum SettingsKey {
    static let captureMode = "captureMode"
    static let confirmationTone = "confirmationTone"
    static let spokenConfirmation = "spokenConfirmation"
    static let keepIndefinitely = "keepRecordsIndefinitely"
    /// Identifier of the chosen speech voice; empty means the system voice for the phone's language.
    static let voiceIdentifier = "voiceIdentifier"
    /// Spoken confirmation phrases, one per line.
    static let confirmationPhrases = "confirmationPhrases"
    /// Say "Left, far." before the phrase.
    static let sayClueFirst = "sayClueFirst"
    /// Pause music and podcasts while Passing speaks or listens (otherwise lower them).
    static let pauseAudioWhileSpeaking = "pauseAudioWhileSpeaking"
    /// After a tap on the capture screen, listen a few seconds for a spoken label.
    static let listenAfterTap = "listenAfterTap"
    /// Ask "What are you passing?" before listening (otherwise just chime).
    static let askBeforeListening = "askBeforeListening"
    /// System, Light or Dark (`Appearance`). The capture screen is always dark.
    static let appearance = "appearance"
    /// After an export is shared, move the exported pins (except kept ones) to Recently Deleted.
    static let deleteAfterExport = "deleteAfterExport"
    /// Ask Apple Maps for each pin's town. Off keeps pin locations entirely on the iPhone.
    static let lookUpPlaceNames = "lookUpPlaceNames"
    /// Keep the capture screen from dimming and locking while Passing is open (for a dash mount).
    /// Off by default: the screen follows iOS Auto-Lock like any app, and GPS stops when it locks.
    static let keepScreenOn = "keepScreenOn"
    /// A pin's screen shows its GPS details (coordinates, accuracy, fix, speed, heading, saved from).
    /// Off by default; the choice is remembered for every pin.
    static let showsPinDetails = "showsPinDetails"
    /// Debug builds only: pushes the retention clock forward this many days for testing.
    static let debugDayOffset = "debugDayOffset"
}

enum AppSettings {
    static let defaultValues: [String: Any] = [
        SettingsKey.captureMode: CaptureMode.quick.rawValue,
        SettingsKey.confirmationTone: true,
        SettingsKey.spokenConfirmation: false,
        SettingsKey.keepIndefinitely: false,
        SettingsKey.voiceIdentifier: "",
        SettingsKey.confirmationPhrases: SpokenConfirmation.defaultPhrase,
        SettingsKey.sayClueFirst: true,
        SettingsKey.pauseAudioWhileSpeaking: true,
        SettingsKey.listenAfterTap: false,
        SettingsKey.askBeforeListening: true,
        SettingsKey.lookUpPlaceNames: true,
        SettingsKey.deleteAfterExport: false,
        SettingsKey.appearance: "system",
    ]

    private static let defaults: UserDefaults = {
        let defaults = UserDefaults.standard
        defaults.register(defaults: defaultValues)
        return defaults
    }()

    static var confirmationTone: Bool { defaults.bool(forKey: SettingsKey.confirmationTone) }

    static var spokenConfirmation: Bool { defaults.bool(forKey: SettingsKey.spokenConfirmation) }

    static var keepIndefinitely: Bool { defaults.bool(forKey: SettingsKey.keepIndefinitely) }

    static var voiceIdentifier: String { defaults.string(forKey: SettingsKey.voiceIdentifier) ?? "" }

    static var confirmationPhrases: [String] {
        SpokenConfirmation.phrases(from: defaults.string(forKey: SettingsKey.confirmationPhrases) ?? "")
    }

    static var sayClueFirst: Bool { defaults.bool(forKey: SettingsKey.sayClueFirst) }

    static var pauseAudioWhileSpeaking: Bool { defaults.bool(forKey: SettingsKey.pauseAudioWhileSpeaking) }

    static var listenAfterTap: Bool { defaults.bool(forKey: SettingsKey.listenAfterTap) }

    static var askBeforeListening: Bool { defaults.bool(forKey: SettingsKey.askBeforeListening) }

    static var lookUpPlaceNames: Bool { defaults.bool(forKey: SettingsKey.lookUpPlaceNames) }
}
