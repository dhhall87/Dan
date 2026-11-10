import AudioToolbox
import Foundation

/// A best guess at whether the iPhone is on silent. iOS has no way to ask, so this uses a
/// long-standing workaround: a silent system sound plays for its full length normally, but ends at
/// once when the Silent switch is on. It lets Passing skip its question and chime on silent
/// (also over Bluetooth and CarPlay, where iOS itself doesn't mute them) and listen straight away.
///
/// Unverified on iOS 26 and 27 from here: the drive log's `silent` field on listen events shows
/// whether it's right. If it can't tell, it says "not silent", and `CaptureAudio`'s sessions, which
/// iOS mutes on silent through the iPhone's own speaker, still apply.
@MainActor
final class SilentSwitch {
    static let shared = SilentSwitch()

    /// A sound that ends sooner than this was cut short by the Silent switch. The sound itself is
    /// 0.4 s long.
    static let cutoff: TimeInterval = 0.12

    private var soundID: SystemSoundID = 0
    private let isLoaded: Bool

    private init() {
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            isLoaded = false
            return
        }
        var id: SystemSoundID = 0
        isLoaded = AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError
        soundID = id
    }

    /// Takes `cutoff` seconds. False when it can't tell (and always in the Simulator, which has no
    /// Silent switch).
    func isSilent() async -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard isLoaded else { return false }
        let ended = Flag()
        Self.play(soundID, ended: ended)
        try? await Task.sleep(for: .seconds(Self.cutoff))
        return ended.isSet
        #endif
    }

    /// Built outside the main actor, because the system calls back on a thread of its own.
    nonisolated private static func play(_ soundID: SystemSoundID, ended: Flag) {
        AudioServicesPlaySystemSoundWithCompletion(soundID) {
            ended.set()
        }
    }
}

/// Set on the system's thread, read on the main actor.
private final class Flag: @unchecked Sendable {
    // @unchecked: `value` is only read and written while holding `lock`.
    private let lock = NSLock()
    private var value = false

    var isSet: Bool { lock.withLock { value } }

    func set() {
        lock.withLock { value = true }
    }
}
