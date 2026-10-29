/// Which audio session Passing uses for each kind of sound, and whether the Silent switch mutes it.
/// iOS gives apps no way to read the Silent switch, so following it means playing in a category the
/// system itself mutes on silent: `ambient` (mixes with music) or `soloAmbient` (pauses music).
/// Dan, October 2026: on silent, Passing doesn't speak or chime; it still listens, and a buzz says
/// when. Plain values, so that rule is unit tested.
enum CaptureAudio {
    /// The `AVAudioSession` categories Passing uses.
    enum Category: Equatable {
        case ambient
        case soloAmbient
        case playback
        case playAndRecord
    }

    enum Mode: Equatable {
        /// The confirmation tone, and the chime before listening when the question is turned off.
        case tone
        /// Anything Passing says on the capture screen: spoken confirmations, the listen-after-tap
        /// question, the read-back, "Pin not saved."
        case speech(pausingOthers: Bool)
        /// A voice preview in Settings, tapped on purpose, so it plays even on silent.
        case preview
        /// The microphone is on for listen after tap. Nothing is played in it, since the Silent
        /// switch can't mute a recording session.
        case listening(pausingOthers: Bool)
    }

    struct Session: Equatable {
        let category: Category
        /// Other audio is lowered rather than paused. Apple allows that only in categories the
        /// Silent switch can't mute (`playback`, `playAndRecord`).
        let lowersOthers: Bool

        /// Everything played in it is muted on silent.
        var followsSilentSwitch: Bool {
            category == .ambient || category == .soloAmbient
        }

        /// Other audio pauses while it's on, and resumes after.
        var pausesOthers: Bool {
            category != .ambient && !lowersOthers
        }
    }

    static func session(for mode: Mode) -> Session {
        switch mode {
        case .tone:
            return Session(category: .ambient, lowersOthers: false)
        case .speech(let pausingOthers):
            // Lowering isn't possible here, so with the music setting off Passing speaks over it.
            return Session(category: pausingOthers ? .soloAmbient : .ambient, lowersOthers: false)
        case .preview:
            return Session(category: .playback, lowersOthers: false)
        case .listening(let pausingOthers):
            return Session(category: .playAndRecord, lowersOthers: !pausingOthers)
        }
    }
}
