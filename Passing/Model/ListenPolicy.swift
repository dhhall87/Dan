import Foundation

/// When listen-after-tap stops listening, and how what was heard becomes a label.
/// Plain values and functions, so they're easy to unit test.
struct ListenPolicy {
    /// Asked out loud before listening (unless the driver chose the chime instead).
    static let question = "What are you passing?"

    /// Give up if nothing is said within this long after the chime.
    var waitForSpeech: TimeInterval = 4
    /// Once the driver is talking, stop after this long with no new words.
    var pauseAfterSpeech: TimeInterval = 1.5
    /// After "stop" or "cancel", stop sooner than the normal pause. Not instantly, because the
    /// recognizer hears "stop" first when the driver is saying "stop sign".
    var pauseAfterStopCommand: TimeInterval = 0.6
    /// Never listen longer than this.
    var maxDuration: TimeInterval = 10

    /// `heard` is everything recognized so far.
    func shouldStop(startedAt: Date, lastHeardAt: Date?, heard: String? = nil, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(startedAt)
        if elapsed >= maxDuration { return true }
        guard let lastHeardAt else { return elapsed >= waitForSpeech }
        let pause = Self.isStopCommand(heard) ? pauseAfterStopCommand : pauseAfterSpeech
        return now.timeIntervalSince(lastHeardAt) >= pause
    }

    /// Labels stay short enough to read at a glance in the list.
    static let maxLabelLength = 100

    /// Saying one of these means "no label", the same as saying nothing, and stops listening at once.
    static let noLabelPhrases: Set<String> = [
        "cancel", "never mind", "nevermind", "nothing", "no", "skip", "no label", "stop", "stop listening",
    ]

    /// What the driver said, tidied up as a label, or nil if there's nothing worth keeping.
    static func label(from transcript: String?) -> String? {
        guard let trimmed = tidy(transcript), !trimmed.isEmpty,
              !noLabelPhrases.contains(trimmed.lowercased())
        else { return nil }
        return String(trimmed.prefix(maxLabelLength))
    }

    /// True when everything said so far is "stop", "cancel" and the like, so listening can end
    /// sooner instead of waiting for the full pause.
    static func isStopCommand(_ transcript: String?) -> Bool {
        guard let trimmed = tidy(transcript) else { return false }
        return noLabelPhrases.contains(trimmed.lowercased())
    }

    private static func tidy(_ transcript: String?) -> String? {
        transcript?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
