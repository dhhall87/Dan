import AVFoundation
import Observation
import UIKit
import WidgetKit

/// Non-visual confirmation that a pin was saved: a haptic, a short tone, and (if turned on)
/// a spoken phrase like "Left, far. Got it boss." The driver never has to look at the screen.
/// With listen-after-tap on, Passing asks "What are you passing?" (or chimes) and listens for a label.
@MainActor
@Observable
final class CaptureFeedback: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = CaptureFeedback()

    private let haptics = UINotificationFeedbackGenerator()
    private let synthesizer = AVSpeechSynthesizer()
    private let audio = AudioWorker()
    private let listener = SpeechListener()
    /// The pin listen-after-tap is asking about or listening for, if any. The audio session stays on
    /// meanwhile, and the capture screen shows its Stop button.
    private var listeningPin: Pin?
    @ObservationIgnored private var speechInProgress = false
    /// The utterance being spoken now, so a cancelled older one isn't mistaken for the end of speech.
    @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
    /// Set by the Stop button, so a session still asking its question doesn't go on to listen.
    @ObservationIgnored private var sessionStopped = false
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    /// When the current listen started, for the drive log.
    @ObservationIgnored private var listenStartedAt = Date.distantPast
    @ObservationIgnored private var deactivateTask: Task<Void, Never>?
    @ObservationIgnored private var stopObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var voicesObserver: (any NSObjectProtocol)?

    /// True from the tap until listening ends, including while the question is asked.
    var isListening: Bool { listeningPin != nil }

    override init() {
        super.init()
        synthesizer.delegate = self
        // A widget's Stop button (on the phone or in CarPlay) runs in another process and signals here.
        ListeningSignal.startObserving()
        stopObserver = NotificationCenter.default.addObserver(forName: ListeningSignal.stopRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopListening() }
        }
        // A voice downloaded in iOS Settings may be better than the one "Best available" picked.
        voicesObserver = NotificationCenter.default.addObserver(forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in AutomaticVoice.forget() }
        }
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

        if AppSettings.listenAfterTap, SpeechListener.availability == .ready {
            listenForLabel(on: pin)
            return
        }

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
        audio.activateAndPlay(tone: playTone, mode: spokenText == nil ? .toneOnly : Self.speechMode) {
            Task { @MainActor in
                self.audioIsActive(speech: spokenText)
            }
        }
    }

    /// A tap whose pin couldn't be written to disk: the error haptic instead of the success one, no
    /// tone, and "Pin not saved" if spoken confirmation is on, so the driver knows to try again.
    func captureFailed() {
        haptics.notificationOccurred(.error)
        haptics.prepare()
        if AppSettings.spokenConfirmation {
            preview("Pin not saved.")
        }
    }

    /// The capture screen's "Add a note" button: asks "What's your note?" and listens. What's said is
    /// saved as a note in Pins (text only, no pin or location). Saying nothing saves nothing.
    /// Permission is only ever asked in Settings, never here.
    func addSpokenNote() {
        guard SpeechListener.availability == .ready else {
            haptics.notificationOccurred(.warning)
            haptics.prepare()
            preview("Voice notes are off. Turn on Listen after tap in Settings once to allow them.")
            return
        }
        // Saved first, like every capture, so a note can't be lost mid-sentence; removed if empty.
        let note = CaptureService.shared.addNote(nil)
        guard CaptureService.shared.isSaved(note) else {
            CaptureService.shared.discardEmptyNote(note)
            captureFailed()
            return
        }
        haptics.notificationOccurred(.success)
        haptics.prepare()
        listenForLabel(on: note, question: ListenPolicy.noteQuestion)
    }

    /// Settings preview: speaks `text` in the given voice (or the chosen one), whatever the
    /// spoken-confirmation switch says.
    func preview(_ text: String, voiceIdentifier: String? = nil) {
        deactivateTask?.cancel()
        speechInProgress = true
        let voice = voiceIdentifier ?? AppSettings.voiceIdentifier
        audio.activateAndPlay(tone: false, mode: Self.speechMode) {
            Task { @MainActor in
                // `_ =` so the task doesn't return the utterance (which can't cross actors).
                _ = self.speak(text, voiceIdentifier: voice)
            }
        }
    }

    /// Speech pauses whatever else is playing (and lets it resume after) unless the driver chose
    /// to have it lowered instead.
    private static var speechMode: AudioWorker.Mode {
        AppSettings.pauseAudioWhileSpeaking ? .speechPausingOthers : .speechLoweringOthers
    }

    /// The voice for an identifier from settings. Empty means "Best available": the most natural
    /// voice installed for the phone's language, which is also the fallback if the chosen voice has
    /// been deleted. Nil (no voice installed for the language at all) leaves it to the system.
    static func voice(identifier: String) -> AVSpeechSynthesisVoice? {
        guard !identifier.isEmpty, let chosen = AVSpeechSynthesisVoice(identifier: identifier) else {
            return AutomaticVoice.voice
        }
        return chosen
    }

    private func audioIsActive(speech: String?) {
        if let speech {
            speak(speech, voiceIdentifier: AppSettings.voiceIdentifier)
        } else {
            scheduleDeactivation(after: audio.toneDuration + 0.2)
        }
    }

    @discardableResult
    private func speak(_ text: String, voiceIdentifier: String) -> AVSpeechUtterance {
        // Made before the old one is stopped, so the two are alive together and can't be mistaken
        // for each other when the old one's "cancelled" callback arrives.
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(identifier: voiceIdentifier)
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = utterance
        synthesizer.speak(utterance)
        return utterance
    }

    /// Speaks `text` and returns once it has finished or been cut off.
    private func say(_ text: String) async {
        speechInProgress = true
        let utterance = speak(text, voiceIdentifier: AppSettings.voiceIdentifier)
        let giveUpAt = Date.now.addingTimeInterval(10)
        while currentUtterance === utterance, Date.now < giveUpAt {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Stops whatever is being said. The cancelled utterance's own callback is then ignored, so
    /// whoever interrupts decides what happens to the audio session next.
    private func interruptSpeech() {
        currentUtterance = nil
        speechInProgress = false
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func scheduleDeactivation(after delay: TimeInterval) {
        deactivateTask?.cancel()
        deactivateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.speechInProgress, self.listeningPin == nil else { return }
            self.audio.deactivate()
        }
    }

    // MARK: Listen after tap

    /// The Stop button (on the capture screen, or a widget in CarPlay): turns the microphone off now
    /// instead of waiting for listening to time out. Anything already heard is kept as the label.
    func stopListening() {
        guard listeningPin != nil else { return }
        sessionStopped = true
        listener.stop()
        // If the question is still being asked, cut it short.
        interruptSpeech()
    }

    /// Passing asks "What are you passing?" (or chimes, if the driver turned the question off), then
    /// listens for a few seconds. Whatever the driver says becomes the pin's label; saying nothing
    /// leaves it unlabeled, silently. The pin is already saved, so none of this can lose it.
    private func listenForLabel(on pin: Pin, question: String = ListenPolicy.question) {
        if let listeningPin, listeningPin === pin {
            // Another "+1 mi back" tap on the same pin: chime again and start the waiting time over.
            audio.playTone()
            listener.restartClock()
            return
        }

        // A new pin while listening for an older one: the older one keeps whatever was heard so far.
        listener.stop()
        let previous = listenTask
        deactivateTask?.cancel()
        interruptSpeech()
        sessionStopped = false
        listeningPin = pin
        listenStartedAt = .now
        ListeningSignal.setListening(true)
        WidgetCenter.shared.reloadAllTimelines()

        let mode = AudioWorker.Mode.listening(pausingOthers: AppSettings.pauseAudioWhileSpeaking)
        let ask = AppSettings.askBeforeListening
        listenTask = Task { @MainActor in
            await previous?.value
            guard self.listeningPin === pin else { return }
            await withCheckedContinuation { continuation in
                self.audio.activateAndPlay(tone: !ask, mode: mode) {
                    continuation.resume()
                }
            }
            if ask {
                await self.say(question)
            }
            // A short gap, so the microphone doesn't catch the end of the question or chime.
            try? await Task.sleep(for: .seconds(ask ? 0.15 : self.audio.toneDuration + 0.1))
            guard self.listeningPin === pin, !self.sessionStopped else {
                self.finishListening(for: pin, heard: nil)
                return
            }
            let label = await self.listener.listen()
            self.finishListening(for: pin, heard: label)
        }
    }

    private func finishListening(for pin: Pin, heard label: String?) {
        let stillCurrent = listeningPin === pin
        DriveLog.record(DriveLogEntry(
            at: .now, kind: .listen, source: pin.isNote ? "note" : pin.source.rawValue,
            outcome: label != nil ? "heard" : sessionStopped ? "stopped" : "nothing",
            seconds: Date.now.timeIntervalSince(listenStartedAt)
        ))
        if stillCurrent {
            listeningPin = nil
            ListeningSignal.setListening(false)
            WidgetCenter.shared.reloadAllTimelines()
        }
        if label == nil, pin.isNote {
            CaptureService.shared.discardEmptyNote(pin)
        }
        if let label {
            CaptureService.shared.setLabel(label, on: pin)
            haptics.notificationOccurred(.success)
            if stillCurrent, AppSettings.spokenConfirmation {
                // Read it back, so the driver knows what was heard without looking.
                speechInProgress = true
                speak(label, voiceIdentifier: AppSettings.voiceIdentifier)
                return
            }
        }
        if stillCurrent {
            scheduleDeactivation(after: 0.1)
        }
    }

    /// Called when an utterance finishes or is cut off. A newer confirmation cancels the one before
    /// it, and that newer one's own end lets the music back. If nothing replaced it (a phone call cut
    /// it off, say), speech is over and the music can come back now rather than staying paused.
    private func utteranceStopped(_ id: ObjectIdentifier) {
        guard let current = currentUtterance, ObjectIdentifier(current) == id else { return }
        currentUtterance = nil
        speechInProgress = false
        scheduleDeactivation(after: 0.1)
    }

    // MARK: AVSpeechSynthesizerDelegate

    // The utterance itself can't cross to the main actor (it isn't Sendable), so pass its identity.

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceStopped(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceStopped(id) }
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
    enum Mode {
        /// Just the tone: mixes with music without interrupting it.
        case toneOnly
        /// Speech: other audio pauses, then resumes when Passing deactivates its session.
        case speechPausingOthers
        /// Speech: other audio is lowered while Passing talks.
        case speechLoweringOthers
        /// Listen after tap: the microphone is on, and other audio pauses (or is lowered) so the
        /// recognizer hears the driver rather than the music.
        case listening(pausingOthers: Bool)
    }

    func activateAndPlay(tone: Bool, mode: Mode, activated: @escaping @Sendable () -> Void) {
        queue.async {
            Self.activateSession(mode)
            if tone, let tonePlayer = self.tonePlayer {
                tonePlayer.currentTime = 0
                tonePlayer.play()
            }
            activated()
        }
    }

    /// Plays the tone again in the session that's already on.
    func playTone() {
        queue.async {
            guard let tonePlayer = self.tonePlayer else { return }
            tonePlayer.currentTime = 0
            tonePlayer.play()
        }
    }

    /// Lets paused or lowered audio come back.
    func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The tone mixes with whatever is playing and still plays with the ring switch on silent,
    /// because the haptic is easy to miss with the phone in a dash mount. Speech either pauses
    /// other audio (a non-mixing session interrupts it; deactivating with `notifyOthersOnDeactivation`
    /// tells it to resume) or lowers it, depending on the driver's setting.
    private static func activateSession(_ mode: Mode) {
        let session = AVAudioSession.sharedInstance()
        do {
            switch mode {
            case .toneOnly:
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            case .speechPausingOthers:
                try session.setCategory(.playback, mode: .voicePrompt, options: [])
            case .speechLoweringOthers:
                try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            case .listening(let pausingOthers):
                // `defaultToSpeaker` keeps the chime and read-back on the loudspeaker instead of the
                // earpiece; Bluetooth HFP lets a car or headset microphone be used.
                var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
                if !pausingOthers {
                    options.insert(.duckOthers)
                }
                try session.setCategory(.playAndRecord, mode: .default, options: options)
                // Recording normally silences haptics; the "got it" haptic should still play.
                try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
            }
            try session.setActive(true)
        } catch {
            print("Passing: couldn't start audio for the confirmation: \(error)")
        }
    }
}
