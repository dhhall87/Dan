import Foundation

/// When listen-after-tap stops listening, and how what was heard becomes a label.
/// Plain values and functions, so they're easy to unit test.
struct ListenPolicy {
    /// Give up if nothing is said within this long after the chime.
    var waitForSpeech: TimeInterval = 4
    /// Once the driver is talking, stop after this long with no new words.
    var pauseAfterSpeech: TimeInterval = 1.5
    /// Never listen longer than this.
    var maxDuration: TimeInterval = 10

    func shouldStop(startedAt: Date, lastHeardAt: Date?, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(startedAt)
        if elapsed >= maxDuration { return true }
        guard let lastHeardAt else { return elapsed >= waitForSpeech }
        return now.timeIntervalSince(lastHeardAt) >= pauseAfterSpeech
    }

    /// Labels stay short enough to read at a glance in the list.
    static let maxLabelLength = 100

    /// Saying one of these means "no label", the same as saying nothing.
    static let noLabelPhrases: Set<String> = ["cancel", "never mind", "nevermind", "nothing", "no", "skip", "no label"]

    /// What the driver said, tidied up as a label, or nil if there's nothing worth keeping.
    static func label(from transcript: String?) -> String? {
        guard let transcript else { return nil }
        let trimmed = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !noLabelPhrases.contains(trimmed.lowercased()) else { return nil }
        return String(trimmed.prefix(maxLabelLength))
    }
}
