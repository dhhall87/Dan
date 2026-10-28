import Foundation
import WatchConnectivity

/// The iPhone's side of WatchConnectivity. Pins from the Apple Watch app arrive here, each is saved
/// through `CaptureService` (once, however often it arrives), and the watch is told which ones are
/// saved so it can let them go. Started at launch, so pins queued while Passing was closed come in
/// as it opens. Apple's docs say the Simulator doesn't deliver these transfers, so syncing is
/// tested on a real iPhone and Apple Watch.
@MainActor
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Private

    private func received(_ pin: WatchPin) {
        // Not on disk yet: no answer, so the watch keeps the pin and sends it again later.
        guard CaptureService.shared.saveWatchPin(pin) else { return }
        let session = WCSession.default
        // The pin came from the watch app, so it's installed: no need to ask the session, whose
        // `isWatchAppInstalled` can read false for an app put on the watch from Xcode.
        guard session.activationState == .activated else { return }
        session.transferUserInfo(WatchMessage.userInfo(saved: [pin.id]))
        // Also in the application context, which the watch reads whenever Passing starts there, so
        // it can clear its list even if the answer above is slow or lost (Dan, October 2026: the
        // pins arrived, but the watch kept showing them as waiting to send).
        let recent = WatchMessage.recentlySaved(WatchMessage.savedIDs(from: session.applicationContext), adding: [pin.id])
        do {
            try session.updateApplicationContext(WatchMessage.userInfo(saved: recent))
        } catch {
            print("Passing: couldn't update the watch's list of saved pins: \(error)")
        }
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The iPhone switched to another Apple Watch: connect to that one, as Apple's docs describe.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let pin = WatchMessage.pin(from: userInfo) else { return }
        Task { @MainActor in self.received(pin) }
    }
}
