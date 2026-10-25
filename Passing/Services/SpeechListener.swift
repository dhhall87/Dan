import AVFoundation
import Speech

/// Listen-after-tap's ears: records for a few seconds and turns what the driver says into text.
/// Recognition happens on the iPhone and the audio never leaves it. The Simulator usually has no
/// on-device speech model, so there (only) it may use Apple's servers so the feature can be tried.
@MainActor
final class SpeechListener {
    enum Availability: Equatable {
        case ready
        /// Microphone or speech recognition permission hasn't been given.
        case needsPermission
        /// This iPhone can't recognize its language on the device.
        case notSupported
    }

    static var availability: Availability {
        guard AVAudioApplication.shared.recordPermission == .granted,
              SFSpeechRecognizer.authorizationStatus() == .authorized
        else { return .needsPermission }
        guard let recognizer = SFSpeechRecognizer(), canRecognize(with: recognizer) else { return .notSupported }
        return .ready
    }

    /// Asks for microphone and speech recognition access. Only called from Settings, never from
    /// the capture screen, where nothing may pop up.
    static func requestPermission() async -> Availability {
        _ = await requestMicrophone()
        _ = await requestSpeechRecognition()
        return availability
    }

    private var policy = ListenPolicy()
    private var startedAt = Date()
    private var lastHeardAt: Date?
    private var transcript: String?
    private var finished = false
    private var stopRequested = false

    /// Listens until the driver stops talking, gives up if they say nothing, and returns the label
    /// to use (nil for nothing). The audio session must already be set up for recording.
    func listen() async -> String? {
        startedAt = .now
        lastHeardAt = nil
        transcript = nil
        finished = false
        stopRequested = false

        guard let recognizer = SFSpeechRecognizer(), Self.canRecognize(with: recognizer) else { return nil }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.requiresOnDeviceRecognition = Self.mustStayOnDevice(recognizer)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // No usable microphone (say, the audio session isn't recording): give up quietly.
        guard format.sampleRate > 0, format.channelCount > 0 else { return nil }
        Self.feed(request, from: input, format: format)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            print("Passing: couldn't start listening: \(error)")
            return nil
        }
        let task = Self.recognize(request, with: recognizer) { [weak self] text, isDone in
            Task { @MainActor in self?.heard(text, isDone: isDone) }
        }

        while !stopRequested, !finished,
              !policy.shouldStop(startedAt: startedAt, lastHeardAt: lastHeardAt, heard: transcript, now: .now) {
            try? await Task.sleep(for: .milliseconds(200))
        }

        // Stop the microphone, then give the recognizer a moment to settle on its final words.
        engine.stop()
        input.removeTap(onBus: 0)
        request.endAudio()
        let settleBy = Date.now.addingTimeInterval(1)
        while !finished, Date.now < settleBy {
            try? await Task.sleep(for: .milliseconds(100))
        }
        task.cancel()
        return ListenPolicy.label(from: transcript)
    }

    /// Ends listening early, keeping whatever was heard so far.
    func stop() {
        stopRequested = true
    }

    /// Starts the waiting time over (another "+1 mi back" tap on the same pin).
    func restartClock() {
        startedAt = .now
        if lastHeardAt != nil {
            lastHeardAt = .now
        }
    }

    // MARK: Private

    private func heard(_ text: String?, isDone: Bool) {
        if let text, !text.isEmpty, text != transcript {
            transcript = text
            lastHeardAt = .now
        }
        if isDone {
            finished = true
        }
    }

    private static func canRecognize(with recognizer: SFSpeechRecognizer) -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return recognizer.supportsOnDeviceRecognition
        #endif
    }

    private static func mustStayOnDevice(_ recognizer: SFSpeechRecognizer) -> Bool {
        #if targetEnvironment(simulator)
        return recognizer.supportsOnDeviceRecognition
        #else
        return true
        #endif
    }

    // The callbacks below run on audio and Speech framework threads, so they're built outside the
    // main actor and only hop back to it with plain values.

    nonisolated private static func feed(_ request: SFSpeechAudioBufferRecognitionRequest, from input: AVAudioInputNode, format: AVAudioFormat) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognize(
        _ request: SFSpeechAudioBufferRecognitionRequest,
        with recognizer: SFSpeechRecognizer,
        update: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            update(result?.bestTranscription.formattedString, (result?.isFinal ?? false) || error != nil)
        }
    }

    nonisolated private static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    nonisolated private static func requestSpeechRecognition() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
