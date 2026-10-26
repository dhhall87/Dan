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
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        session.transferUserInfo(WatchMessage.userInfo(saved: [pin.id]))
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
