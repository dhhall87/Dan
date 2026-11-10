import AppIntents
import CoreLocation
import SwiftUI
import UIKit

/// Screens pushed inside Settings.
enum SettingsRoute: Hashable {
    case voice
    case phrases
    case reviewReminders
    case backup
    case advanced
    case driveLog
    case welcome
}

/// Settings, tidied for 2.0: the switches used most are on this screen, each with a short note,
/// and the rest (appearance, exports, location access, the drive log) are under Advanced.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.captureMode) private var mode: CaptureMode = .quick
    @AppStorage(SettingsKey.confirmationTone) private var confirmationTone = true
    @AppStorage(SettingsKey.spokenConfirmation) private var spokenConfirmation = false
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false
    @AppStorage(SettingsKey.voiceIdentifier) private var voiceIdentifier = ""
    @AppStorage(SettingsKey.confirmationPhrases) private var storedPhrases = SpokenConfirmation.defaultPhrase
    @AppStorage(SettingsKey.sayClueFirst) private var sayClueFirst = true
    @AppStorage(SettingsKey.pauseAudioWhileSpeaking) private var pauseAudioWhileSpeaking = true
    @AppStorage(SettingsKey.listenAfterTap) private var listenAfterTap = false
    @AppStorage(SettingsKey.askBeforeListening) private var askBeforeListening = true
    @AppStorage(SettingsKey.lookUpPlaceNames) private var lookUpPlaceNames = true
    /// In the App Group's shared settings, so the widget and Control Center follow it too.
    @AppStorage(LocationPrivacy.key, store: AppGroup.defaults) private var preciseLocation = true
    @AppStorage(SettingsKey.keepScreenOn) private var keepScreenOn = false
    @State private var confirmingDeleteAll = false
    @State private var deletedCount: Int?
    @State private var listenProblem: SpeechListener.Availability?

    var body: some View {
        NavigationStack {
            Form {
                if SharedStore.state == .unavailable {
                    Section {
                        Label("Passing couldn't open its pin database, so new pins can't be saved, and pins saved earlier don't show until it opens. Close Passing (swipe it away in the app switcher) and open it again. If this keeps happening, restart the iPhone.", systemImage: "exclamationmark.octagon.fill")
                            .foregroundStyle(.red)
                    } header: {
                        Text("Storage")
                    }
                }
                captureSection
                soundSection
                listenSection
                siriSection
                pinsSection
                privacySection
                moreSection
                if SharedStore.state == .appOnly {
                    Section {
                        Label("The App Group isn't set up, so pins are stored in the app's own space. The widgets and Control Center can't save pins here. See “Set up the App Group” in the README.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } header: {
                        Text("Storage")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .voice: VoicePickerView()
                case .phrases: PhrasesView()
                case .reviewReminders: ReviewRemindersView()
                case .backup: BackupView()
                case .advanced: AdvancedSettingsView()
                case .driveLog: DriveLogView()
                case .welcome: WelcomeAgainView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all pins?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All Pins", role: .destructive) {
                    deletedCount = RetentionService.shared.deleteAllPins()
                    AppBadge.update(count: CaptureService.shared.unnamedCount())
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every pin and its photos are deleted for good, including kept pins and Recently Deleted. This can't be undone. Your groups stay.")
            }
            .onAppear {
                // Permission can be taken away in iOS Settings; say so rather than silently not listening.
                if listenAfterTap, SpeechListener.availability != .ready {
                    listenProblem = SpeechListener.availability
                }
            }
        }
    }

    // MARK: Sections

    private var captureSection: some View {
        Section {
            Picker("Capture screen", selection: $mode) {
                ForEach(CaptureMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Keep screen on", isOn: $keepScreenOn)
        } header: {
            Text("Capture screen")
        } footer: {
            // Built as a key so the bold parts show as bold.
            Text(LocalizedStringKey((mode == .quick
                  ? "The whole screen is one button."
                  : "Tap the side of the road the thing was on: inner columns are close to the road, outer ones farther away.")
                 + " Tap the **Passing** title on the capture screen to switch during a drive. **Keep screen on** is for a phone in a dash mount; off, the screen follows Auto-Lock."))
        }
    }

    private var soundSection: some View {
        Section {
            Toggle("Confirmation tone", isOn: $confirmationTone)
            Toggle("Spoken confirmation", isOn: $spokenConfirmation)
            if spokenConfirmation {
                NavigationLink(value: SettingsRoute.voice) {
                    LabeledContent("Voice", value: VoiceOption.displayName(for: voiceIdentifier))
                }
                NavigationLink(value: SettingsRoute.phrases) {
                    LabeledContent("Phrases", value: phrasesSummary)
                }
                Toggle("Say side and distance first", isOn: $sayClueFirst)
            }
            if spokenConfirmation || listenAfterTap {
                Toggle(listenAfterTap ? "Pause music while speaking or listening" : "Pause music while speaking", isOn: $pauseAudioWhileSpeaking)
            }
            if spokenConfirmation {
                Button("Preview") {
                    CaptureFeedback.shared.preview(SpokenConfirmation.text(
                        side: .left,
                        distance: .far,
                        milesBack: 0,
                        phrases: SpokenConfirmation.phrases(from: storedPhrases),
                        sayClueFirst: sayClueFirst
                    ))
                }
            }
        } header: {
            Text("Sound")
        } footer: {
            Text(spokenConfirmation
                 ? "Every pin gets a buzz. After each pin, Passing says one of your phrases, like “Left, far. Got it boss.” On silent it plays no tone and doesn't speak. Preview plays even on silent."
                 : "Every pin gets a buzz. On silent there's no tone. Turn on spoken confirmation to choose a voice and your own phrases.")
        }
    }

    private var listenSection: some View {
        Section {
            Toggle("Listen after tap", isOn: listenBinding)
            if listenAfterTap {
                Toggle("Ask “\(ListenPolicy.question)”", isOn: $askBeforeListening)
            }
            if let listenProblem {
                Text(listenProblemText(listenProblem))
                    .foregroundStyle(.orange)
                if listenProblem == .needsPermission {
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
            }
        } header: {
            Text("Labels by voice")
        } footer: {
            Text("After a tap on the capture screen, Passing asks “\(ListenPolicy.question)” (or chimes) and listens for a few seconds. Say what you saw, like “red barn”, and it becomes the pin's name. Say nothing, “cancel” or “stop”, and the pin stays unnamed. **Stop listening** on the capture screen turns the microphone off right away. Speech is recognized on your iPhone and never leaves it. On silent, Passing doesn't ask or chime: it just listens, so talk after the second buzz. While Passing is open, a tap on a Passing widget chimes and listens too.")
        }
    }

    private var siriSection: some View {
        Section {
            SiriTipView(intent: CapturePinIntent())
            ShortcutsLink()
        } header: {
            Text("Siri and the Action Button")
        } footer: {
            Text("Say “Pin that in Passing” or “I missed something in Passing.” Siri asks what you saw, but the pin is already saved, so you can ignore the question. For the Action Button, use **Quick Pin**, which never asks anything.")
        }
    }

    private var pinsSection: some View {
        Section {
            Toggle("Keep records indefinitely", isOn: $keepIndefinitely)
            NavigationLink(value: SettingsRoute.reviewReminders) {
                Label("Review Reminders", systemImage: "bell")
            }
            NavigationLink(value: SettingsRoute.backup) {
                Label("Back Up and Restore", systemImage: "externaldrive")
            }
        } header: {
            Text("Your pins")
        } footer: {
            Text(LocalizedStringKey((keepIndefinitely
                  ? "Pins stay until you delete them."
                  : "Pins move to Recently Deleted after 7 days, unless you keep (star) them. Pins you've added photos or notes to are kept for you.")
                 + " Recently Deleted empties itself after 30 days. **Review Reminders** has reminders for pins waiting in Needs Review, and the number on Passing's icon."))
        }
    }

    private var privacySection: some View {
        Section {
            Toggle("Precise location", isOn: $preciseLocation)
            Toggle("Look up town names", isOn: $lookUpPlaceNames)
            Button("Delete All Pins…", role: .destructive) {
                confirmingDeleteAll = true
            }
            if let deletedCount {
                Text(deletedCount == 1 ? "Deleted 1 pin." : "Deleted \(deletedCount) pins.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Pins, names, photos and groups stay on this iPhone. Passing has no account, no analytics and no server.\n\n**Precise location** off keeps only roughly where each new pin was (within about half a mile), with no speed and no route.\n\n**Town names** are looked up by sending a pin's location to Apple Maps. Off, pin locations leave the iPhone only for map pictures, Look Around and What's here? when you open them.\n\n**Delete All Pins** erases every pin for good, including kept ones and Recently Deleted. Groups and your Work and Home places stay.")
        }
    }

    private var moreSection: some View {
        Section {
            NavigationLink(value: SettingsRoute.advanced) {
                Label("Advanced", systemImage: "slider.horizontal.3")
            }
            NavigationLink(value: SettingsRoute.welcome) {
                Label("How Passing Works", systemImage: "questionmark.circle")
            }
            LabeledContent("Version", value: AppVersion.current)
        } header: {
            Text("More")
        } footer: {
            Text("**Advanced** has appearance, exports, location access and the drive log.")
        }
    }

    /// Turning listening on asks for microphone and speech recognition access here in Settings,
    /// so no permission prompt can ever appear on the capture screen.
    private var listenBinding: Binding<Bool> {
        Binding(
            get: { listenAfterTap },
            set: { turnOn in
                guard turnOn else {
                    listenAfterTap = false
                    listenProblem = nil
                    return
                }
                Task {
                    let availability = await SpeechListener.requestPermission()
                    listenAfterTap = availability == .ready
                    listenProblem = availability == .ready ? nil : availability
                }
            }
        )
    }

    private func listenProblemText(_ problem: SpeechListener.Availability) -> String {
        switch problem {
        case .ready:
            return ""
        case .needsPermission:
            return "Passing needs microphone and speech recognition access to listen. Turn both on for Passing in iOS Settings."
        case .notSupported:
            return "This iPhone can't recognize speech in its language without the internet, so listening is off. Passing only uses on-device recognition."
        }
    }

    private var phrasesSummary: String {
        let count = SpokenConfirmation.phrases(from: storedPhrases).count
        switch count {
        case 0: return "“\(SpokenConfirmation.defaultPhrase)”"
        case 1: return "1 phrase"
        default: return "\(count) phrases"
        }
    }
}

/// The welcome pages again, from Settings → How Passing Works.
private struct WelcomeAgainView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WelcomeView(done: { dismiss() })
            .navigationBarTitleDisplayMode(.inline)
    }
}
