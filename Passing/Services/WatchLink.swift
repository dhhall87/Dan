import Foundation
import WatchConnectivity

/// The iPhone's side of WatchConnectivity. Pins from the Apple Watch app arrive here, each is saved
/// through `CaptureService` (once, however often it arrives), and the watch is told which ones are
/// saved so it can let them go. Started at launch, so pins queued while Passing was closed come in
/// as it opens. Since 1.1.7 the watch also sends each pin as a message while the iPhone is in
/// reach, which wakes Passing here in the background, so the pin doesn't wait for Passing to be
/// opened. Apple's docs say the Simulator doesn't deliver these transfers, so syncing is tested on
/// a real iPhone and Apple Watch.
@MainActor
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Private

    /// A pin that came as a queued transfer: saved, then answered with a transfer of its own.
    private func received(_ pin: WatchPin) {
        // Not on disk yet: no answer, so the watch keeps the pin and sends it again later.
        guard save(pin, byMessage: false) else { return }
        let session = WCSession.default
        // The pin came from the watch app, so it's installed: no need to ask the session, whose
        // `isWatchAppInstalled` can read false for an app put on the watch from Xcode.
        guard session.activationState == .activated else { return }
        session.transferUserInfo(WatchMessage.userInfo(saved: [pin.id]))
    }

    /// Saves a pin from the watch and updates the list of saved ones.
    /// - Returns: whether it's on disk.
    private func save(_ pin: WatchPin, byMessage: Bool) -> Bool {
        guard CaptureService.shared.saveWatchPin(pin, byMessage: byMessage) else { return false }
        publishSaved()
        // Passing may have been woken in the background just for this, and be suspended soon.
        DriveLog.flush()
        return true
    }

    /// Puts the watch pins saved here in the application context, which the watch reads whenever
    /// Passing starts there, so it can clear its list even if an answer was slow or lost (Dan,
    /// October 2026: the pins arrived, but the watch kept showing them as waiting to send). Taken
    /// from the pin database, so pins that arrived before any answer could get back are included.
    /// Sent only when the list changes.
    private func publishSaved() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let current = WatchMessage.savedIDs(from: session.applicationContext)
        let saved = WatchMessage.recentlySaved(current, adding: CaptureService.shared.savedWatchPinIDs())
        guard Set(saved) != Set(current) else { return }
        do {
            try session.updateApplicationContext(WatchMessage.userInfo(saved: saved))
        } catch {
            print("Passing: couldn't update the watch's list of saved pins: \(error)")
            DriveLog.record(DriveLogEntry(at: .now, kind: .watchLink, outcome: "contextFailed-\((error as NSError).code)"))
        }
    }

    /// The link started, or the watch changed (paired, Passing installed or removed there). Logged
    /// only with a paired watch, so the drive log shows whether iOS thinks Passing is on it.
    private func linkChanged(paired: Bool, installed: Bool, logsUnpaired: Bool) {
        if paired {
            DriveLog.record(DriveLogEntry(at: .now, kind: .watchLink, outcome: installed ? "ready" : "notInstalled"))
        } else if logsUnpaired {
            DriveLog.record(DriveLogEntry(at: .now, kind: .watchLink, outcome: "notPaired"))
        }
        publishSaved()
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            let code = (error as NSError).code
            DriveLog.record(DriveLogEntry(at: .now, kind: .watchLink, outcome: "activationFailed-\(code)"))
            return
        }
        guard activationState == .activated else { return }
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in self.linkChanged(paired: paired, installed: installed, logsUnpaired: false) }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in self.linkChanged(paired: paired, installed: installed, logsUnpaired: true) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The iPhone switched to another Apple Watch: connect to that one, as Apple's docs describe.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let pin = WatchMessage.pin(from: userInfo) else { return }
        Task { @MainActor in self.received(pin) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // The watch waits for this reply, so there's always one: the pin's id once it's on disk,
        // or none (the watch keeps the pin and its queued copy still comes).
        let reply = Reply(send: replyHandler)
        guard let pin = WatchMessage.pin(from: message) else {
            reply.send(WatchMessage.userInfo(saved: []))
            return
        }
        Task { @MainActor in
            let saved = self.save(pin, byMessage: true)
            reply.send(WatchMessage.userInfo(saved: saved ? [pin.id] : []))
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        // A "saved" answer that couldn't go. The watch still finds out from the application
        // context, if that gets through; the drive log says which one failed.
        guard let error else { return }
        DriveLog.record(DriveLogEntry(at: .now, kind: .watchLink, outcome: "answerFailed-\((error as NSError).code)"))
    }
}

/// WatchConnectivity's reply handler, carried to the main actor where the pin is saved. The session
/// accepts the reply from any thread.
private struct Reply: @unchecked Sendable {
    let send: ([String: Any]) -> Void
}
