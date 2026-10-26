import Foundation
import WatchConnectivity

/// The watch's side of WatchConnectivity. Pins go to the iPhone with `transferUserInfo`, which
/// queues them, delivers them in order, and keeps going while Passing is closed; the iPhone answers
/// with the ones it has saved. Apple's docs say the Simulator doesn't deliver these transfers, so
/// syncing is tested on a real iPhone and Apple Watch.
@MainActor
final class PhoneLink: NSObject, WCSessionDelegate {
    /// The session is ready, so waiting pins can go.
    var onActivated: (@MainActor () -> Void)?
    /// A pin reached the iPhone (not yet saved there).
    var onDelivered: (@MainActor (UUID) -> Void)?
    /// The iPhone has saved these pins.
    var onSaved: (@MainActor ([UUID]) -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Transfers may only start once the session is activated.
    var isActivated: Bool {
        session?.activationState == .activated
    }

    /// Pins already queued for the iPhone, so none is queued twice.
    var inFlight: Set<UUID> {
        guard let session, isActivated else { return [] }
        return Set(session.outstandingUserInfoTransfers.compactMap { WatchMessage.pin(from: $0.userInfo)?.id })
    }

    /// Queues pins for the iPhone. Does nothing until the session is activated; `onActivated` then
    /// gives the caller another go.
    func send(_ pins: [WatchPin]) {
        guard let session, isActivated else { return }
        for pin in pins {
            if let userInfo = WatchMessage.userInfo(for: pin) {
                session.transferUserInfo(userInfo)
            }
        }
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.onActivated?() }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        // A transfer that failed is queued again the next time Passing opens or saves a pin: the pin
        // stays on the watch until the iPhone confirms it.
        guard error == nil, let id = WatchMessage.pin(from: userInfoTransfer.userInfo)?.id else { return }
        Task { @MainActor in self.onDelivered?(id) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let ids = WatchMessage.savedIDs(from: userInfo)
        guard !ids.isEmpty else { return }
        Task { @MainActor in self.onSaved?(ids) }
    }
}
