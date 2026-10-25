import AVFoundation
import SwiftUI

/// A speech voice installed on this iPhone.
struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String
    let languageName: String
    let qualityRank: Int
    let qualityLabel: String
    let isNovelty: Bool
    let isPersonal: Bool

    init(_ voice: AVSpeechSynthesisVoice) {
        id = voice.identifier
        name = voice.name
        languageCode = voice.language
        languageName = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        qualityRank = AutomaticVoice.qualityRank(voice.quality)
        qualityLabel = ["Default", "Enhanced", "Premium"][qualityRank]
        isNovelty = voice.voiceTraits.contains(.isNoveltyVoice)
        isPersonal = voice.voiceTraits.contains(.isPersonalVoice)
    }

    /// Best quality first, then by name.
    static func sorted(_ options: [VoiceOption]) -> [VoiceOption] {
        options.sorted { ($0.qualityRank, $1.name) > ($1.qualityRank, $0.name) }
    }

    /// The name shown in Settings for a stored voice identifier.
    static func displayName(for identifier: String) -> String {
        guard !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) else {
            return "Best available"
        }
        return voice.name
    }
}

/// Pick the voice for spoken confirmations. Lists the voices installed on this iPhone; Siri's own
/// voices aren't available to other apps, and no voice files are bundled with Passing.
struct VoicePickerView: View {
    @AppStorage(SettingsKey.voiceIdentifier) private var voiceIdentifier = ""
    @State private var voices: [VoiceOption] = []
    @State private var showAllLanguages = false
    @State private var personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus

    /// "en" for an English-language phone.
    private let phoneLanguage = String(AVSpeechSynthesisVoice.currentLanguageCode().split(separator: "-").first ?? "en")
    private let sample = "Left, far. Saved."

    var body: some View {
        List {
            Section {
                VoiceRow(
                    title: "Best available",
                    subtitle: automaticSubtitle,
                    isSelected: voiceIdentifier.isEmpty,
                    preview: { CaptureFeedback.shared.preview(sample, voiceIdentifier: "") },
                    select: { voiceIdentifier = "" }
                )
            }

            if !personalVoices.isEmpty {
                Section("Your Personal Voice") {
                    rows(for: personalVoices)
                }
            }

            Section(showAllLanguages ? "All voices" : "Voices for your language") {
                rows(for: standardVoices)
                Toggle("Show all languages", isOn: $showAllLanguages)
            }

            if !noveltyVoices.isEmpty {
                Section("Novelty voices") {
                    rows(for: noveltyVoices)
                }
            }

            Section {
                personalVoiceControls
            } header: {
                Text("Personal Voice")
            } footer: {
                Text("If you've made a Personal Voice (Settings → Accessibility → Personal Voice), Passing can speak in your own voice with your permission.")
            }

            Section {
                Text("For more natural voices, open iOS **Settings → Accessibility → Spoken Content → Voices**, choose a language, and download an **Enhanced** or **Premium** voice. It appears here automatically, and **Best available** switches to it on its own. Siri's own voices can't be used by other apps.")
                    .font(.callout)
            } header: {
                Text("Getting better voices")
            }
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reload()
            // Voices downloaded or deleted in iOS Settings show up without reopening this screen.
            for await _ in NotificationCenter.default.notifications(named: AVSpeechSynthesizer.availableVoicesDidChangeNotification) {
                reload()
            }
        }
    }

    /// Which voice "Best available" uses right now, so it's clear what downloading a better one changes.
    private var automaticSubtitle: String {
        guard let voice = AutomaticVoice.voice else { return "Your iPhone's default voice" }
        let option = VoiceOption(voice)
        return "The most natural voice installed. Now: \(option.name) · \(option.qualityLabel)"
    }

    @ViewBuilder
    private func rows(for options: [VoiceOption]) -> some View {
        ForEach(options) { option in
            VoiceRow(
                title: option.name,
                subtitle: "\(option.languageName) · \(option.qualityLabel)",
                isSelected: voiceIdentifier == option.id,
                preview: { CaptureFeedback.shared.preview(sample, voiceIdentifier: option.id) },
                select: { voiceIdentifier = option.id }
            )
        }
    }

    @ViewBuilder
    private var personalVoiceControls: some View {
        switch personalVoiceStatus {
        case .notDetermined:
            Button("Use my Personal Voice") {
                Task {
                    personalVoiceStatus = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
                    reload()
                }
            }
        case .authorized:
            if personalVoices.isEmpty {
                Text("Allowed. No Personal Voice found on this iPhone yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Allowed. Your Personal Voice is listed above.")
                    .foregroundStyle(.secondary)
            }
        case .denied:
            Text("Not allowed. You can turn it on in iOS Settings → Passing.")
                .foregroundStyle(.secondary)
        case .unsupported:
            Text("This iPhone doesn't support Personal Voice.")
                .foregroundStyle(.secondary)
        @unknown default:
            EmptyView()
        }
    }

    private var personalVoices: [VoiceOption] {
        VoiceOption.sorted(voices.filter(\.isPersonal))
    }

    private var noveltyVoices: [VoiceOption] {
        VoiceOption.sorted(voices.filter { $0.isNovelty && matchesLanguage($0) })
    }

    private var standardVoices: [VoiceOption] {
        VoiceOption.sorted(voices.filter { !$0.isNovelty && !$0.isPersonal && matchesLanguage($0) })
    }

    private func matchesLanguage(_ option: VoiceOption) -> Bool {
        showAllLanguages || option.languageCode.hasPrefix(phoneLanguage)
    }

    /// The chosen voice is never cleared here: the voice list can briefly come back empty while iOS
    /// loads it, and speaking already falls back to the system voice if the chosen one is gone.
    private func reload() {
        AutomaticVoice.forget()
        voices = AVSpeechSynthesisVoice.speechVoices().map(VoiceOption.init)
        personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    }
}

/// Tap the row to choose the voice; tap ▶︎ to hear it.
private struct VoiceRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let preview: () -> Void
    let select: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: preview) {
                Image(systemName: "play.circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Preview \(title)")
            Image(systemName: "checkmark")
                .foregroundStyle(Color.accentColor)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(!isSelected)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
