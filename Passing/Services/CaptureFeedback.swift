import AVFoundation
import UIKit

/// Non-visual confirmation that a pin was saved: a haptic, a short tone, and (if turned on)
/// a spoken phrase like "Left, far. Got it boss." The driver never has to look at the screen.
@MainActor
final class CaptureFeedback: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = CaptureFeedback()

    private let haptics = UINotificationFeedbackGenerator()
    private let synthesizer = AVSpeechSynthesizer()
    private let audio = AudioWorker()
    private var speechInProgress = false
    private var deactivateTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Warms up the haptic engine and audio so the first tap responds instantly.
    func prepare() {
        haptics.prepare()
        audio.prepare()
    }

    func confirmCapture(of pin: Pin) {
        // The haptic doesn't need the audio session, so it fires the instant the pin is saved.
        haptics.notificationOccurred(.success)
        haptics.prepare()

        let playTone = AppSettings.confirmationTone && audio.hasTone
        let spokenText = AppSettings.spokenConfirmation
            ? SpokenConfirmation.text(
                side: pin.side,
                distance: pin.distance,
                milesBack: pin.milesBack,
                phrases: AppSettings.confirmationPhrases,
                sayClueFirst: AppSettings.sayClueFirst
            )
            : nil
        guard playTone || spokenText != nil else { return }

        deactivateTask?.cancel()
        if spokenText != nil { speechInProgress = true }
        audio.activateAndPlay(tone: playTone, ducking: spokenText != nil) {
            Task { @MainActor in
                self.audioIsActive(speech: spokenText)
            }
        }
    }

    /// Settings preview: speaks `text` in the given voice (or the chosen one), whatever the
    /// spoken-confirmation switch says.
    func preview(_ text: String, voiceIdentifier: String? = nil) {
        deactivateTask?.cancel()
        speechInProgress = true
        let voice = voiceIdentifier ?? AppSettings.voiceIdentifier
        audio.activateAndPlay(tone: false, ducking: true) {
            Task { @MainActor in
                self.speak(text, voiceIdentifier: voice)
            }
        }
    }

    /// The voice for an identifier from settings. Nil means the system voice for the phone's
    /// language, which is also the fallback if the chosen voice has been deleted.
    static func voice(identifier: String) -> AVSpeechSynthesisVoice? {
        guard !identifier.isEmpty else { return nil }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }

    private func audioIsActive(speech: String?) {
        if let speech {
            speak(speech, voiceIdentifier: AppSettings.voiceIdentifier)
        } else {
            scheduleDeactivation(after: audio.toneDuration + 0.2)
        }
    }

    private func speak(_ text: String, voiceIdentifier: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(identifier: voiceIdentifier)
        synthesizer.speak(utterance)
    }

    private func scheduleDeactivation(after delay: TimeInterval) {
        deactivateTask?.cancel()
        deactivateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.speechInProgress else { return }
            self.audio.deactivate()
        }
    }

    private func speechEnded() {
        speechInProgress = false
        scheduleDeactivation(after: 0.1)
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechEnded() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // A newer confirmation interrupted this one; that one's own didFinish deactivates audio.
    }
}

/// Owns the audio session and the tone player, and touches them only on its own serial queue.
/// Turning the session on or off, and playing while it's on, can block for a noticeable moment
/// (longer when the car's Bluetooth or CarPlay route has to wake up), so none of it runs on the
/// main thread. iOS 27 adds async activate/deactivate calls; this queue does the same job on iOS 26.
private final class AudioWorker: @unchecked Sendable {
    // @unchecked: `tonePlayer` is only used on `queue`, which serializes all access.
    private let queue = DispatchQueue(label: "Passing.audio", qos: .userInitiated)
    private let tonePlayer: AVAudioPlayer?
    let toneDuration: TimeInterval

    var hasTone: Bool { tonePlayer != nil }

    init() {
        let player = Bundle.main.url(forResource: "capture-tone", withExtension: "wav")
            .flatMap { try? AVAudioPlayer(contentsOf: $0) }
        tonePlayer = player
        toneDuration = player?.duration ?? 0
    }

    func prepare() {
        queue.async { self.tonePlayer?.prepareToPlay() }
    }

    /// Turns the session on, plays the tone if asked, then calls `activated` (on the queue).
    func activateAndPlay(tone: Bool, ducking: Bool, activated: @escaping @Sendable () -> Void) {
        queue.async {
            Self.activateSession(ducking: ducking)
            if tone, let tonePlayer = self.tonePlayer {
                tonePlayer.currentTime = 0
                tonePlayer.play()
            }
            activated()
        }
    }

    /// Lets ducked music come back up.
    func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The tone mixes with whatever is playing and still plays with the ring switch on silent,
    /// because the haptic is easy to miss with the phone in a dash mount. Speech ducks the music briefly.
    private static func activateSession(ducking: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if ducking {
                try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            print("Passing: couldn't start audio for the confirmation: \(error)")
        }
    }
}
