import Foundation

enum Side: String, Codable, CaseIterable, Identifiable {
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

enum Distance: String, Codable, CaseIterable, Identifiable {
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

/// How the pin's target (the thing itself, not the car) was worked out.
enum TargetSource: String, Codable {
    /// The thing was beside the car when the driver tapped; look around the capture point.
    case direct
    /// Estimated by walking back along the breadcrumb trail ("miles back").
    case breadcrumb
    /// Only a description ("about 2 mi back"), because the trail was too short.
    case textOnly
}

/// What triggered the capture.
enum CaptureSource: String, Codable {
    case app
    case siri
    case widget
    case control
    case actionButton

    var title: String {
        switch self {
        case .app: return "Passing app"
        case .siri: return "Siri"
        case .widget: return "Widget"
        case .control: return "Control Center"
        case .actionButton: return "Action Button or Shortcut"
        }
    }
}

/// The tap targets on the four-zone screen, left to right exactly as the road looks.
enum CaptureZone: CaseIterable, Hashable {
    case farLeft
    case nearLeft
    /// The car in the middle: side unknown.
    case car
    case nearRight
    case farRight

    var side: Side {
        switch self {
        case .farLeft, .nearLeft: return .left
        case .nearRight, .farRight: return .right
        case .car: return .unknown
        }
    }

    var distance: Distance {
        switch self {
        case .farLeft, .farRight: return .far
        case .nearLeft, .nearRight: return .near
        case .car: return .unknown
        }
    }
}

enum PinDescription {
    /// "Left, far" / "Right" / "Near" / nil when nothing is known.
    static func sideAndDistance(side: Side, distance: Distance) -> String? {
        switch (side, distance) {
        case (.unknown, .unknown): return nil
        case (.unknown, _): return distance.title
        case (_, .unknown): return side.title
        default: return "\(side.title), \(distance.title.lowercased())"
        }
    }

    /// How to find a miles-back pin's spot, for the review screen. Nil for ordinary pins.
    /// `course` is the direction of travel at the tap; it's only used when `courseReliable`.
    static func milesBackHint(milesBack: Double, targetSource: TargetSource, course: Double?, courseReliable: Bool) -> String? {
        guard milesBack > 0 else { return nil }
        let miles = Geo.milesText(milesBack)
        switch targetSource {
        case .breadcrumb:
            return "Placed \(miles) back along the road you drove. The orange pin is the estimate and the blue line is your route."
        case .textOnly, .direct:
            var hint = "About \(miles) back the way you came."
            if courseReliable, let course {
                hint += " You were heading \(Geo.compassName(for: course)), so look \(Geo.compassName(for: course + 180)) of this spot."
            }
            return hint + " Passing hadn't recorded enough of the drive yet to place it on the map."
        }
    }
}
