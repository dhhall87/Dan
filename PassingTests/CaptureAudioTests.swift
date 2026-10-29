import Testing
@testable import Passing

struct CaptureAudioTests {
    @Test func everythingPassingSaysFollowsTheSilentSwitch() {
        #expect(CaptureAudio.session(for: .tone).followsSilentSwitch)
        #expect(CaptureAudio.session(for: .speech(pausingOthers: true)).followsSilentSwitch)
        #expect(CaptureAudio.session(for: .speech(pausingOthers: false)).followsSilentSwitch)
    }

    @Test func speechPausesMusicOrPlaysOverIt() {
        #expect(CaptureAudio.session(for: .speech(pausingOthers: true)).pausesOthers)
        let over = CaptureAudio.session(for: .speech(pausingOthers: false))
        #expect(!over.pausesOthers && !over.lowersOthers, "lowering would need a session silent can't mute")
        #expect(!CaptureAudio.session(for: .tone).pausesOthers, "the tone mixes with music")
    }

    @Test func listeningPausesOrLowersMusicButCantFollowSilent() {
        let pausing = CaptureAudio.session(for: .listening(pausingOthers: true))
        #expect(pausing.category == .playAndRecord)
        #expect(pausing.pausesOthers)
        #expect(!pausing.followsSilentSwitch, "so nothing is played while the microphone is on")
        #expect(CaptureAudio.session(for: .listening(pausingOthers: false)).lowersOthers)
    }

    @Test func aPreviewInSettingsPlaysEvenOnSilent() {
        #expect(!CaptureAudio.session(for: .preview).followsSilentSwitch)
    }
}
