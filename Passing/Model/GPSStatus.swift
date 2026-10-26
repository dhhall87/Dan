import Foundation

/// The "GPS ready" pill at the top of the capture screen: whether a tap right now would get a
/// position, so there's no surprise later. Glanceable, never needed to capture.
enum GPSStatus: Equatable {
    /// A fresh, precise fix is in hand.
    case ready
    /// Allowed, but no fresh fix yet (just opened, or a tunnel).
    case searching
    /// Location hasn't been allowed or refused yet; Passing asks on the first pin.
    case notAsked
    /// Location is turned off for Passing.
    case off
    /// Precise Location is off in iOS Settings, so fixes are too rough to stamp on a pin.
    case notPrecise
    /// The pin database wouldn't open, so taps can't save at all until Passing is reopened.
    /// Shown ahead of any GPS state, because it's the one thing that loses pins.
    case cantSave

    init(isAuthorized: Bool, isDenied: Bool, isPreciseLocationOff: Bool, hasFreshFix: Bool, canSave: Bool = true) {
        if !canSave {
            self = .cantSave
        } else if isDenied {
            self = .off
        } else if !isAuthorized {
            self = .notAsked
        } else if isPreciseLocationOff {
            self = .notPrecise
        } else {
            self = hasFreshFix ? .ready : .searching
        }
    }

    var title: String {
        switch self {
        case .ready: return "GPS ready"
        case .searching: return "Finding GPS…"
        case .notAsked: return "Location asked on first pin"
        case .off: return "Location off"
        case .notPrecise: return "Precise Location off"
        case .cantSave: return "Can't save pins"
        }
    }

    /// Pins still save in every GPS state; this only says whether they'll have a position.
    var pinsGetAPosition: Bool {
        self == .ready || self == .searching || self == .notAsked
    }
}
