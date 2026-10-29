import AVFoundation
import Observation
import UIKit
import WidgetKit

/// Non-visual confirmation that a pin was saved: a haptic, a short tone, and (if turned on)
/// a spoken phrase like "Left, far. Got it boss." The driver never has to look at the screen.
/// With listen-after-tap on, Passing asks "What are you passing?" (or chimes) and listens for a label.
/// Everything it plays on the capture screen follows the Silent switch (`CaptureAudio`): on silent
/// it neither speaks nor chimes, and the haptics carry it.
@MainActor
@Observable
final class CaptureFeedback: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = CaptureFeedback()

    private let haptics = UINotificationFeedbackGenerator()
    /// Felt as the microphone opens: the cue to talk, even on silent when there's no question.
    private let listenCue = UIImpactFeedbackGenerator(style: .medium)
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

        // A "+1 mi back" on a pin that already has its label just confirms; one still being listened
        // for (or still unlabeled) listens again.
        let unlabeled = pin.label?.isEmpty ?? true
        if AppSettings.listenAfterTap, SpeechListener.availability == .ready, listeningPin === pin || unlabeled {
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
        audio.activateAndPlay(tone: playTone, mode: spokenText == nil ? .tone : Self.speechMode) {
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
            announce("Pin not saved.")
        }
    }

    /// "+1 mi back" with no pin just dropped to move: the warning haptic, no tone, and "Pin something
    /// first." if spoken confirmation is on, so the driver knows nothing was saved or moved.
    func milesBackUnavailable() {
        haptics.notificationOccurred(.warning)
        haptics.prepare()
        if AppSettings.spokenConfirmation {
            announce("Pin something first.")
        }
    }

    /// The capture screen's "Add a note" button: asks "What's your note?" and listens. What's said is
    /// saved as a note in Pins (text only, no pin or location). Saying nothing saves nothing.
    /// Permission is only ever asked in Settings, never here.
    func addSpokenNote() {
        guard SpeechListener.availability == .ready else {
            haptics.notificationOccurred(.warning)
            haptics.prepare()
            announce("Voice notes are off. Turn on Listen after tap in Settings once to allow them.")
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
    /// spoken-confirmation switch says. Tapped on purpose, so it plays even on silent.
    func preview(_ text: String, voiceIdentifier: String? = nil) {
        speakAlone(text, voiceIdentifier: voiceIdentifier ?? AppSettings.voiceIdentifier, mode: .preview)
    }

    /// A spoken message on the capture screen ("Pin not saved.", a read-back). Silent on silent.
    private func announce(_ text: String) {
        speakAlone(text, voiceIdentifier: AppSettings.voiceIdentifier, mode: Self.speechMode)
    }

    /// Switches the session to `mode`, then speaks. The session goes off again once speech ends.
    private func speakAlone(_ text: String, voiceIdentifier: String, mode: CaptureAudio.Mode) {
        deactivateTask?.cancel()
        speechInProgress = true
        audio.activateAndPlay(tone: false, mode: mode) {
            Task { @MainActor in
                // `_ =` so the task doesn't return the utterance (which can't cross actors).
                _ = self.speak(text, voiceIdentifier: voiceIdentifier)
            }
        }
    }

    /// Speech follows the Silent switch, and pauses whatever else is playing (letting it resume
    /// after) unless the driver turned that off, when it plays over it: lowering other audio is only
    /// possible in a session the Silent switch can't mute.
    private static var speechMode: CaptureAudio.Mode {
        .speech(pausingOthers: AppSettings.pauseAudioWhileSpeaking)
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
    /// The question and the chime play before the microphone comes on, in a session the Silent
    /// switch mutes, so on silent Passing just listens; a buzz marks when.
    private func listenForLabel(on pin: Pin, question: String = ListenPolicy.question) {
        if let listeningPin, listeningPin === pin {
            // Another "+1 mi back" tap on the same pin: start the waiting time over. Its haptic has
            // already played; a chime now would play in the microphone session, which the Silent
            // switch can't mute, and the recognizer would hear it.
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
        ListeningSignal.setListening(true)
        WidgetCenter.shared.reloadAllTimelines()

        let pausingOthers = AppSettings.pauseAudioWhileSpeaking
        let ask = AppSettings.askBeforeListening
        listenCue.prepare()
        // Read now, while the pin is certainly there: by the end it may have been deleted for good.
        let about = ListenTarget(pin: pin, isNote: pin.isNote, source: pin.source, startedAt: .now)
        listenTask = Task { @MainActor in
            await previous?.value
            guard self.listeningPin === pin else { return }
            if ask {
                await self.activate(.speech(pausingOthers: pausingOthers))
                // Starting the audio can take about a second when it pauses music. If a newer tap
                // took over meanwhile, this one ends quietly instead of asking its question after all.
                guard self.listeningPin === pin, !self.sessionStopped else {
                    self.finishListening(about, heard: nil)
                    return
                }
                await self.say(question)
                // A short gap, so switching to the microphone doesn't clip the end of the question.
                try? await Task.sleep(for: .seconds(0.15))
                // Stopped (or replaced) during the question: don't switch the microphone on at all.
                guard self.listeningPin === pin, !self.sessionStopped else {
                    self.finishListening(about, heard: nil)
                    return
                }
            }
            // Without the question, the chime plays first, where the Silent switch can mute it.
            await self.activate(.listening(pausingOthers: pausingOthers), chime: !ask)
            guard self.listeningPin === pin, !self.sessionStopped else {
                self.finishListening(about, heard: nil)
                return
            }
            self.listenCue.impactOccurred()
            let label = await self.listener.listen()
            self.finishListening(about, heard: label)
        }
    }

    /// Turns the session to `mode` (after the tone, with `chime`) and returns once it's on.
    private func activate(_ mode: CaptureAudio.Mode, chime: Bool = false) async {
        await withCheckedContinuation { continuation in
            audio.activateAndPlay(tone: chime, mode: mode) {
                continuation.resume()
            }
        }
    }

    /// The pin being listened for, with what's needed from it read before listening began.
    private struct ListenTarget {
        let pin: Pin
        let isNote: Bool
        let source: CaptureSource
        /// When this listen began, so its own length is logged even when a newer tap overlaps it.
        let startedAt: Date
    }

    /// Ends a listen: always turns the Stop button off and puts the audio back, then labels the pin
    /// if it's still in the store. (Delete All Pins could have removed it meanwhile, and reading a
    /// deleted pin crashes.)
    private func finishListening(_ target: ListenTarget, heard label: String?) {
        let pin = target.pin
        let stillCurrent = listeningPin === pin
        DriveLog.record(DriveLogEntry(
            at: .now, kind: .listen, source: target.isNote ? "note" : target.source.rawValue,
            outcome: label != nil ? "heard" : !stillCurrent ? "replaced" : sessionStopped ? "stopped" : "nothing",
            seconds: Date.now.timeIntervalSince(target.startedAt)
        ))
        if stillCurrent {
            listeningPin = nil
            ListeningSignal.setListening(false)
            WidgetCenter.shared.reloadAllTimelines()
        }
        let pinExists = pin.modelContext != nil && !pin.isDeleted
        if pinExists, label == nil, target.isNote {
            CaptureService.shared.discardEmptyNote(pin)
        }
        if pinExists, let label {
            // Only read back what's actually saved.
            let saved = CaptureService.shared.setLabel(label, on: pin)
            haptics.notificationOccurred(saved ? .success : .error)
            if stillCurrent, AppSettings.spokenConfirmation {
                // Read it back, so the driver knows what was heard without looking (on silent, the
                // haptic above says it).
                announce(saved ? label : "Label not saved.")
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

    /// Plays the tone if asked, then turns the session to `mode` and calls `activated` (on the queue).
    func activateAndPlay(tone: Bool, mode: CaptureAudio.Mode, activated: @escaping @Sendable () -> Void) {
        queue.async {
            if tone, let tonePlayer = self.tonePlayer {
                // The tone (and listen after tap's chime) always plays in a session the Silent
                // switch mutes, so on silent a tap is haptic only (Dan's request). Whatever comes
                // next (speech, the microphone) starts once it has finished, in its own session.
                Self.activateSession(.tone)
                tonePlayer.currentTime = 0
                tonePlayer.play()
                if mode == .tone {
                    activated()
                    return
                }
                Thread.sleep(forTimeInterval: self.toneDuration)
            }
            Self.activateSession(mode)
            activated()
        }
    }

    /// Lets paused or lowered audio come back.
    func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The session for each kind of sound (`CaptureAudio`). The tone and everything Passing says on
    /// the capture screen play in `ambient` or `soloAmbient`, which the Silent switch mutes, since
    /// iOS doesn't let apps read the switch. A non-mixing session (`soloAmbient`, `playback`,
    /// `playAndRecord` without ducking) pauses other audio; deactivating with
    /// `notifyOthersOnDeactivation` tells it to resume.
    private static func activateSession(_ mode: CaptureAudio.Mode) {
        let session = AVAudioSession.sharedInstance()
        let plan = CaptureAudio.session(for: mode)
        do {
            switch plan.category {
            case .ambient:
                try session.setCategory(.ambient, mode: .default, options: [])
            case .soloAmbient:
                try session.setCategory(.soloAmbient, mode: .default, options: [])
            case .playback:
                try session.setCategory(.playback, mode: .voicePrompt, options: [])
            case .playAndRecord:
                // `defaultToSpeaker` keeps the loudspeaker in use instead of the earpiece; Bluetooth
                // HFP lets a car or headset microphone be used.
                var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
                if plan.lowersOthers {
                    options.insert(.duckOthers)
                }
                try session.setCategory(.playAndRecord, mode: .default, options: options)
                // Recording normally silences haptics; the cue to talk and "got it" should still play.
                try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
            }
            try session.setActive(true)
        } catch {
            print("Passing: couldn't start audio for the confirmation: \(error)")
        }
    }
}
