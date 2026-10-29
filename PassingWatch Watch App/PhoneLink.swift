import Foundation
import WatchConnectivity

/// The watch's side of WatchConnectivity. Pins go to the iPhone with `transferUserInfo`, which
/// queues them, delivers them in order, and keeps going while Passing is closed; the iPhone answers
/// with the ones it has saved, and also keeps its latest saved ones in the application context,
/// which is read here as the session starts. Apple's docs say the Simulator doesn't deliver these transfers, so
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
        return Set(session.outstandingUserInfoTransfers.compactMap { WatchMessage.pinID(from: $0.userInfo) })
    }

    /// Queues pins for the iPhone. Does nothing until the session is activated; `onActivated` then
    /// gives the caller another go. With the iPhone in reach, each pin also goes straight away as
    /// a message, which Apple's docs say wakes Passing on the iPhone in the background (1.1.7): the
    /// pin is saved there, and its review reminder set, without waiting for Passing to be opened.
    /// The queued copy stays the sure way; the iPhone saves a pin once however often it arrives.
    func send(_ pins: [WatchPin]) {
        guard let session, isActivated else { return }
        let reachable = session.isReachable
        for pin in pins {
            if let userInfo = WatchMessage.userInfo(for: pin) {
                session.transferUserInfo(userInfo)
            }
            if reachable {
                sendNow(pin, on: session)
            }
        }
    }

    /// Drops the queued copies of pins the iPhone has saved (when the message got there first), so
    /// they aren't sent again for nothing.
    func cancelTransfers(of ids: [UUID]) {
        guard let session, isActivated else { return }
        let saved = Set(ids)
        for transfer in session.outstandingUserInfoTransfers {
            if let id = WatchMessage.pinID(from: transfer.userInfo), saved.contains(id) {
                transfer.cancel()
            }
        }
    }

    /// Built outside the main actor, since WatchConnectivity calls the handlers on its own queue.
    private nonisolated func sendNow(_ pin: WatchPin, on session: WCSession) {
        guard let message = WatchMessage.userInfo(for: pin) else { return }
        session.sendMessage(message, replyHandler: { reply in
            let ids = WatchMessage.savedIDs(from: reply)
            guard !ids.isEmpty else { return }
            Task { @MainActor in self.onSaved?(ids) }
        }, errorHandler: { _ in
            // Out of reach after all, or no answer in time: the queued copy still goes.
        })
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        // The iPhone's latest list of saved pins, in case an answer was missed while Passing was closed.
        let saved = WatchMessage.savedIDs(from: session.receivedApplicationContext)
        Task { @MainActor in
            if !saved.isEmpty {
                self.onSaved?(saved)
            }
            self.onActivated?()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let ids = WatchMessage.savedIDs(from: applicationContext)
        guard !ids.isEmpty else { return }
        Task { @MainActor in self.onSaved?(ids) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        // A transfer that failed is queued again the next time Passing opens or saves a pin: the pin
        // stays on the watch until the iPhone confirms it.
        guard error == nil, let id = WatchMessage.pinID(from: userInfoTransfer.userInfo) else { return }
        Task { @MainActor in self.onDelivered?(id) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let ids = WatchMessage.savedIDs(from: userInfo)
        guard !ids.isEmpty else { return }
        Task { @MainActor in self.onSaved?(ids) }
    }
}
