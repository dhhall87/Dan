import AVFoundation
import UIKit

/// Non-visual confirmation that a pin was saved: a haptic, a short tone, and (if turned on)
/// a spoken "Left, far, saved". The driver never has to look at the screen.
@MainActor
final class CaptureFeedback: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = CaptureFeedback()

    private let haptics = UINotificationFeedbackGenerator()
    private let synthesizer = AVSpeechSynthesizer()
    private var tonePlayer: AVAudioPlayer?
    private var speechInProgress = false
    private var deactivateTask: Task<Void, Never>?
    /// Turning the audio session on or off can block for a noticeable moment (longer when the
    /// car's Bluetooth or CarPlay route has to wake up), so it never happens on the main thread.
    /// iOS 27 adds async activate/deactivate calls; this queue does the same job on iOS 26 too.
    private let audioQueue = DispatchQueue(label: "Passing.audio-session", qos: .userInitiated)

    override init() {
        super.init()
        synthesizer.delegate = self
        if let url = Bundle.main.url(forResource: "capture-tone", withExtension: "wav") {
            tonePlayer = try? AVAudioPlayer(contentsOf: url)
        }
    }

    /// Warms up the haptic engine and audio so the first tap responds instantly.
    func prepare() {
        haptics.prepare()
        tonePlayer?.prepareToPlay()
    }

    func confirmCapture(of pin: Pin) {
        // The haptic doesn't need the audio session, so it fires the instant the pin is saved.
        haptics.notificationOccurred(.success)
        haptics.prepare()

        let playTone = AppSettings.confirmationTone && tonePlayer != nil
        let spokenText = AppSettings.spokenConfirmation
            ? PinDescription.spokenConfirmation(side: pin.side, distance: pin.distance)
            : nil
        guard playTone || spokenText != nil else { return }

        deactivateTask?.cancel()
        if spokenText != nil { speechInProgress = true }
        audioQueue.async {
            CaptureFeedback.activateAudio(ducking: spokenText != nil)
            Task { @MainActor in
                self.startSounds(tone: playTone, speech: spokenText)
            }
        }
    }

    private func startSounds(tone: Bool, speech: String?) {
        if tone, let tonePlayer {
            tonePlayer.currentTime = 0
            tonePlayer.play()
        }
        if let speech {
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.speak(AVSpeechUtterance(string: speech))
        } else {
            scheduleDeactivation(after: (tonePlayer?.duration ?? 0) + 0.2)
        }
    }

    private func scheduleDeactivation(after delay: TimeInterval) {
        deactivateTask?.cancel()
        deactivateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.speechInProgress else { return }
            self.audioQueue.async {
                CaptureFeedback.deactivateAudio()
            }
        }
    }

    private func speechEnded() {
        speechInProgress = false
        scheduleDeactivation(after: 0.1)
    }

    // MARK: Audio session (runs on `audioQueue`)

    /// The tone mixes with whatever is playing and still plays with the ring switch on silent,
    /// because the haptic is easy to miss with the phone in a dash mount. Speech ducks the music briefly.
    private nonisolated static func activateAudio(ducking: Bool) {
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

    /// Lets ducked music come back up.
    private nonisolated static func deactivateAudio() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechEnded() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // A newer confirmation interrupted this one; that one's own didFinish deactivates audio.
    }
}
