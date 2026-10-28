import Foundation

/// How the pin's target (the thing itself, not the car) was worked out.
enum TargetSource: String, Codable {
    /// The thing was beside the car when the driver tapped; look around the capture point.
    case direct
    /// Estimated by walking back along the breadcrumb trail ("miles back").
    case breadcrumb
    /// Only a description ("about 2 mi back"): no trail, and no direction of travel to go on.
    case textOnly
    /// A rough guess: back along the trail as far as it went, then on in a straight line the way the
    /// car came (Dan, October 2026: a short trail used to leave the pin off the map entirely).
    case heading
    /// Moved by hand on a map while reviewing, to where the thing actually is.
    case manual
}

/// What triggered the capture.
enum CaptureSource: String, Codable {
    case app
    case siri
    case widget
    case control
    case actionButton
    /// The Apple Watch app. Its pins arrive on the iPhone when the watch can reach it.
    case watch

    var title: String {
        switch self {
        case .app: return "Passing app"
        case .siri: return "Siri"
        case .widget: return "Widget"
        case .control: return "Control Center"
        case .actionButton: return "Action Button or Shortcut"
        case .watch: return "Apple Watch"
        }
    }

    /// A finger on a button (rather than a spoken or automated request), so a bounce or double
    /// tap within 0.75 s shouldn't make a second pin.
    var isTap: Bool {
        switch self {
        case .app, .widget, .control: return true
        // The watch debounces its own buttons; on the iPhone its pins arrive one by one, often later.
        case .siri, .actionButton, .watch: return false
        }
    }

    /// Pins from the widgets (including CarPlay), Control Center and Apple Watch are saved silently with
    /// no label, so they go into Needs Review until marked Reviewed. Pins from the capture screen and Siri don't.
    var needsReviewUntilReviewed: Bool {
        switch self {
        case .widget, .control, .watch: return true
        case .app, .siri, .actionButton: return false
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
        case .manual:
            return "You moved this pin to the spot yourself. It was saved about \(miles) back."
        case .breadcrumb:
            return "Placed \(miles) back along the road you drove. The orange pin is the estimate and the blue line is your route."
        case .heading:
            return "A rough guess about \(miles) back. Passing hadn't recorded enough of the road to follow it, so the orange pin carries on in a straight line the way you came (dashed). Move it if you know better."
        case .textOnly, .direct:
            var hint = "About \(miles) back the way you came."
            if courseReliable, let course {
                hint += " You were heading \(Geo.compassName(for: course)), so look \(Geo.compassName(for: course + 180)) of this spot."
            }
            return hint + " Passing hadn't recorded enough of the drive yet to place it on the map."
        }
    }
}
