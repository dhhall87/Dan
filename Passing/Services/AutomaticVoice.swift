import AVFoundation

/// The voice "Best available" speaks with: the most natural voice installed for the phone's
/// language. Worked out once and remembered until voices are downloaded or deleted.
@MainActor
enum AutomaticVoice {
    private static var cached: AVSpeechSynthesisVoice??

    static var voice: AVSpeechSynthesisVoice? {
        if let cached {
            return cached
        }
        let found = find()
        cached = .some(found)
        return found
    }

    /// Called when voices are downloaded or deleted in iOS Settings.
    static func forget() {
        cached = nil
    }

    nonisolated static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 2
        case .enhanced: return 1
        default: return 0
        }
    }

    private static func find() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let candidates = AVSpeechSynthesisVoice.speechVoices().map { voice in
            VoiceRanking.Candidate(
                identifier: voice.identifier,
                language: voice.language,
                qualityRank: qualityRank(voice.quality),
                isNovelty: voice.voiceTraits.contains(.isNoveltyVoice),
                isPersonal: voice.voiceTraits.contains(.isPersonalVoice)
            )
        }
        let systemDefault = AVSpeechSynthesisVoice(language: language)?.identifier
        return VoiceRanking.best(from: candidates, language: language, systemDefault: systemDefault)
            .flatMap { AVSpeechSynthesisVoice(identifier: $0) }
    }
}
