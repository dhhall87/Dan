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
        haptics.notificationOccurred(.success)
        haptics.prepare()

        let playTone = AppSettings.confirmationTone && tonePlayer != nil
        let speak = AppSettings.spokenConfirmation
        guard playTone || speak else { return }

        activateAudio(ducking: speak)
        if playTone, let tonePlayer {
            tonePlayer.currentTime = 0
            tonePlayer.play()
        }
        if speak {
            speechInProgress = true
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.speak(AVSpeechUtterance(string: PinDescription.spokenConfirmation(side: pin.side, distance: pin.distance)))
        } else {
            deactivateAudio(after: (tonePlayer?.duration ?? 0) + 0.2)
        }
    }

    // MARK: Audio session

    /// The tone mixes with whatever is playing and still plays with the ring switch on silent,
    /// because the haptic is easy to miss with the phone in a dash mount. Speech ducks the music briefly.
    private func activateAudio(ducking: Bool) {
        deactivateTask?.cancel()
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

    private func deactivateAudio(after delay: TimeInterval) {
        deactivateTask?.cancel()
        deactivateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.speechInProgress else { return }
            // Lets ducked music come back up.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func speechEnded() {
        speechInProgress = false
        deactivateAudio(after: 0.1)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechEnded() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // A newer confirmation interrupted this one; that one's own didFinish deactivates audio.
    }
}
