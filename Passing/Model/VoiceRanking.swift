import Foundation

/// Picks the most natural installed voice for the phone's language, for "Best available" (the
/// default when the driver hasn't chosen a voice). Plain values, so it's easy to unit test.
enum VoiceRanking {
    struct Candidate: Equatable {
        let identifier: String
        /// Like "en-US".
        let language: String
        /// 0 Default, 1 Enhanced, 2 Premium.
        let qualityRank: Int
        let isNovelty: Bool
        let isPersonal: Bool
    }

    /// Best quality first. Among equals, the phone's own region ("en-US") beats another one
    /// ("en-GB"), then the system's default voice wins, then the identifier (so the pick is stable).
    /// Novelty voices and Personal Voice are only used when chosen by hand. Nil when no installed
    /// voice speaks the phone's language.
    static func best(from candidates: [Candidate], language: String, systemDefault: String?) -> String? {
        let languageCode = baseLanguage(language)
        let usable = candidates.filter {
            !$0.isNovelty && !$0.isPersonal && baseLanguage($0.language) == languageCode
        }
        return usable.min { a, b in
            let aKey = (a.qualityRank, a.language == language ? 1 : 0, a.identifier == systemDefault ? 1 : 0)
            let bKey = (b.qualityRank, b.language == language ? 1 : 0, b.identifier == systemDefault ? 1 : 0)
            if aKey != bKey { return aKey > bKey }
            return a.identifier < b.identifier
        }?.identifier
    }

    /// "en" for "en-US" (or "en_US").
    static func baseLanguage(_ code: String) -> String {
        String(code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? Substring(code)).lowercased()
    }
}
