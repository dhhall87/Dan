import Foundation

/// What Passing says after a capture when spoken confirmation is on.
enum SpokenConfirmation {
    /// Phrases are capped so confirmations stay brief while driving.
    static let maxPhraseLength = 60
    static let defaultPhrase = "Saved"

    /// "Left, far. Got it boss." for a normal pin; "2 miles back" for a miles-back pin, so you always
    /// hear how far back it went. One of `phrases` is picked at random (`pick` is swappable for tests).
    static func text(
        side: Side,
        distance: Distance,
        milesBack: Double,
        phrases: [String],
        sayClueFirst: Bool,
        pick: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> String {
        if milesBack > 0 {
            return "\(Geo.milesText(milesBack)) back"
        }
        let phrase = phrases.isEmpty ? defaultPhrase : phrases[min(max(pick(phrases.count), 0), phrases.count - 1)]
        guard sayClueFirst, let clue = PinDescription.sideAndDistance(side: side, distance: distance) else {
            return phrase
        }
        return "\(clue). \(phrase)"
    }

    /// Phrases are stored one per line in settings.
    static func phrases(from stored: String) -> [String] {
        stored.split(whereSeparator: \.isNewline)
            .map { clean(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func stored(_ phrases: [String]) -> String {
        phrases.map(clean).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Trims spaces and caps the length.
    static func clean(_ phrase: String) -> String {
        String(phrase.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxPhraseLength))
    }
}
