import HomeKit
import Observation

/// Sunrise's one `HMHomeManager`, and the homes it has loaded.
@MainActor
@Observable
final class HomeStore: NSObject, HMHomeManagerDelegate {
    enum Access: Equatable {
        /// Sunrise hasn't asked yet (it asks when Dan taps Connect to Home).
        case notAsked
        /// Waiting for the permission prompt or for HomeKit to load.
        case waiting
        case allowed
        case denied
    }

    private(set) var access: Access = .notAsked
    private(set) var homes: [HMHome] = []
    /// Goes up whenever HomeKit's data may have changed. HomeKit updates its objects in place,
    /// so views read this to know when to look at them again.
    private(set) var revision = 0

    @ObservationIgnored private var manager: HMHomeManager?

    /// Set once Dan has connected, so later launches connect straight away instead of
    /// showing the Connect to Home card.
    static let connectedKey = "homeConnected"

    var hasConnectedBefore: Bool { UserDefaults.standard.bool(forKey: Self.connectedKey) }

    /// Creating the manager is what shows HomeKit's permission prompt the first time.
    func connect() {
        guard manager == nil else { return }
        access = .waiting
        UserDefaults.standard.set(true, forKey: Self.connectedKey)
        let manager = HMHomeManager()
        manager.delegate = self
        self.manager = manager
    }

    /// Re-reads homes and permission. HomeKit doesn't tell an app about its own changes, so
    /// Sunrise calls this after every change it makes, too.
    func refresh() {
        guard let manager else { return }
        let status = manager.authorizationStatus
        if status.contains(.authorized) {
            access = .allowed
        } else if status.contains(.determined) || status.contains(.restricted) {
            access = .denied
        }
        homes = manager.homes
        revision += 1
    }

    func home(withID id: UUID?) -> HMHome? {
        guard let id else { return nil }
        return homes.first { $0.uniqueIdentifier == id }
    }

    // HomeKit may call these off the main thread, so each one hops back before touching state.

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in self.refresh() }
    }
}
