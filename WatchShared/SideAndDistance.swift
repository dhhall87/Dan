import Foundation

/// Which side of the road, and how far off it, as the driver (or walker) tapped. Shared with the
/// Apple Watch app, whose buttons save the same values.
enum Side: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .unknown: return "Unknown"
        }
    }
}

enum Distance: String, Codable, CaseIterable, Identifiable, Sendable {
    case near
    case far
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .near: return "Near"
        case .far: return "Far"
        case .unknown: return "Unknown"
        }
    }
}
