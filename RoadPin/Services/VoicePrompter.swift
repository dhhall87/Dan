import AVFoundation
import Foundation
import Speech

/// Speaks short prompts and listens for a short spoken answer after a pin is dropped.
///
/// Third-party apps can't open Siri from a button, so after a tap RoadPin asks the question itself
/// and transcribes the answer with Apple's on-device speech recognizer (the same engine Siri dictation uses).
/// Hands-free, Siri-started pins are handled by the App Intents in `PinIntents.swift` instead.
@MainActor
final class VoicePrompter: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoicePrompter()

    /// Stop listening this long after the driver stops talking.
    var silenceTimeout: TimeInterval = 1.6
    /// Stop listening after this long no matter what.
    var maxListenDuration: TimeInterval = 8

    private let synthesizer = AVSpeechSynthesizer()
    private var speechContinuation: CheckedContinuation<Void, Never>?
    private var currentUtterance: ObjectIdentifier?
    private var session: ListeningSession?
    private var generation = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Ask for speech and microphone permission up front, so the prompts don't pop up mid-drive.
    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Speaks `prompt`, listens for an answer and returns what was heard ("" if nothing).
    func ask(_ prompt: String, onPartial: @escaping (String) -> Void) async -> String {
        generation += 1
        let myGeneration = generation
        session?.finish()

        guard await requestPermissions(), myGeneration == generation else { return "" }
        do {
            try activateAudio(recording: true)
        } catch {
            return ""
        }
        await speak(prompt)

        var heard = ""
        if myGeneration == generation, let recognizer = Self.makeRecognizer() {
            let listening = ListeningSession()
            listening.onPartial = onPartial
            session = listening
            heard = await listening.run(recognizer: recognizer, maxDuration: maxListenDuration, silenceTimeout: silenceTimeout)
            if session === listening { session = nil }
        }
        if myGeneration == generation {
            deactivateAudio()
        }
        return heard.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Speaks a short confirmation without touching the microphone (allowed in CarPlay).
    func announce(_ text: String) async {
        // Don't talk over a question that's still waiting for an answer.
        guard session == nil else { return }
        generation += 1
        let myGeneration = generation
        do {
            try activateAudio(recording: false)
        } catch {
            return
        }
        await speak(text)
        if myGeneration == generation {
            deactivateAudio()
        }
    }

    // MARK: Speaking

    private func speak(_ text: String) async {
        // Finish any earlier utterance first so its continuation can't be resumed twice.
        if let previous = speechContinuation {
            speechContinuation = nil
            previous.resume()
        }
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        currentUtterance = ObjectIdentifier(utterance)
        await withCheckedContinuation { continuation in
            speechContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        guard id == currentUtterance, let continuation = speechContinuation else { return }
        speechContinuation = nil
        currentUtterance = nil
        continuation.resume()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    // MARK: Audio session

    private func activateAudio(recording: Bool) throws {
        let audio = AVAudioSession.sharedInstance()
        if recording {
            try audio.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        } else {
            try audio.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        }
        try audio.setActive(true)
    }

    private func deactivateAudio() {
        // Let the music or podcast that was ducked come back up.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func makeRecognizer() -> SFSpeechRecognizer? {
        let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else { return nil }
        return recognizer
    }
}

/// One round of listening: microphone → speech recognizer → transcript.
@MainActor
private final class ListeningSession {
    var onPartial: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Never>?
    private var transcript = ""
    private var silenceTimer: Task<Void, Never>?
    private var deadlineTimer: Task<Void, Never>?

    func run(recognizer: SFSpeechRecognizer, maxDuration: TimeInterval, silenceTimeout: TimeInterval) async -> String {
        request.shouldReportPartialResults = true
        request.taskHint = .search
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return "" }
        let request = self.request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return ""
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let done = (result?.isFinal ?? false) || error != nil
                Task { @MainActor in
                    self?.handle(text: text, done: done, silenceTimeout: silenceTimeout)
                }
            }
            self.deadlineTimer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(maxDuration))
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        }
    }

    func finish() {
        guard let continuation else { return }
        self.continuation = nil
        silenceTimer?.cancel()
        deadlineTimer?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task?.cancel()
        task = nil
        continuation.resume(returning: transcript)
    }

    private func handle(text: String?, done: Bool, silenceTimeout: TimeInterval) {
        guard continuation != nil else { return }
        if let text, !text.isEmpty {
            transcript = text
            onPartial?(text)
            // Each new word restarts the countdown; a pause means they're done talking.
            silenceTimer?.cancel()
            silenceTimer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(silenceTimeout))
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        }
        if done {
            finish()
        }
    }
}
