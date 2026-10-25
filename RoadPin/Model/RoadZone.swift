import Foundation

/// The four tap zones on the drive screen, left to right.
enum RoadZone: String, CaseIterable, Identifiable, Codable {
    case farLeft
    case nearLeft
    case nearRight
    case farRight

    var id: String { rawValue }

    var isLeft: Bool { self == .farLeft || self == .nearLeft }
    var isFar: Bool { self == .farLeft || self == .farRight }

    var title: String {
        switch self {
        case .farLeft: return "Far left"
        case .nearLeft: return "Near left"
        case .nearRight: return "Near right"
        case .farRight: return "Far right"
        }
    }

    /// What the driver was looking at, in plain words.
    var lookHint: String {
        switch self {
        case .farLeft: return "Off in the distance on the left"
        case .nearLeft: return "Right by the road on the left"
        case .nearRight: return "Right by the road on the right"
        case .farRight: return "Off in the distance on the right"
        }
    }

    /// Degrees to add to the direction of travel to face this side of the road.
    var bearingOffset: Double { isLeft ? -90 : 90 }

    /// Roughly how far from the road to sketch the "look this way" line on the map.
    var sketchDistanceMeters: Double { isFar ? 600 : 120 }
}
