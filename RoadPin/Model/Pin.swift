import CoreLocation
import Foundation
import SwiftData

@Model
final class Pin {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    /// GPS accuracy in meters, or -1 if unknown.
    var horizontalAccuracy: Double = -1
    /// Direction of travel in degrees (0 = north), or -1 if unknown.
    var course: Double = -1
    /// Which zone was tapped, nil for the one-big-button mode, Siri and miles-back pins.
    var zoneRaw: String?
    /// How far back along the road the thing was, for pins added with "+1 mi back".
    var milesBack: Double = 0
    /// Miles of road beyond this pin's coordinate that still need checking, because RoadPin
    /// hadn't recorded enough of the drive to walk all the way back. 0 when the pin is exact.
    var unresolvedMiles: Double = 0
    /// What the driver wanted to look up ("large building", "name of that town").
    var note: String = ""
    /// Nearby street / town, filled in shortly after the pin is saved.
    var placeName: String = ""
    /// Starred pins survive the weekly clear-out.
    var isStarred: Bool = false

    init(latitude: Double, longitude: Double, horizontalAccuracy: Double = -1, course: Double = -1, zone: RoadZone? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.course = course
        self.zoneRaw = zone?.rawValue
    }

    convenience init(location: CLLocation, zone: RoadZone?) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            course: location.course,
            zone: zone
        )
    }
}

extension Pin {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var zone: RoadZone? {
        zoneRaw.flatMap(RoadZone.init(rawValue:))
    }

    var title: String {
        note.isEmpty ? "Untitled pin" : note
    }

    var hasCourse: Bool { course >= 0 }

    var isApproximate: Bool { unresolvedMiles >= 0.05 }

    /// Short description of where to look, e.g. "Far left · facing west" or "2 mi back".
    var whereSummary: String {
        var parts: [String] = []
        if let zone {
            parts.append(zone.title)
        }
        if milesBack > 0 {
            parts.append("\(Self.formatMiles(milesBack)) back")
        }
        if let lookDirection {
            parts.append("looking \(lookDirection)")
        }
        return parts.joined(separator: " · ")
    }

    /// Compass direction the driver was looking, when we know the side and direction of travel.
    var lookDirection: String? {
        guard let zone, hasCourse else { return nil }
        return Geo.compassName(for: course + zone.bearingOffset)
    }

    /// A sentence explaining how to find the thing later.
    var findItHint: String {
        var lines: [String] = []
        if let zone {
            lines.append(zone.lookHint + (lookDirection.map { " (looking \($0))" } ?? "") + ".")
        }
        if milesBack > 0 {
            if isApproximate {
                lines.append("You marked this \(Self.formatMiles(milesBack)) after passing it, but RoadPin only had part of your drive recorded. Look about \(Self.formatMiles(unresolvedMiles)) further back along the road from this pin.")
            } else {
                lines.append("Placed \(Self.formatMiles(milesBack)) back along the road from where you tapped.")
            }
        }
        if lines.isEmpty {
            lines.append("Right where you were when you tapped.")
        }
        return lines.joined(separator: " ")
    }

    /// A point off to the tapped side of the road, used to sketch which way to look on the map.
    var lookTowardCoordinate: CLLocationCoordinate2D? {
        guard let zone, hasCourse else { return nil }
        let point = Geo.destination(latitude: latitude, longitude: longitude, bearing: course + zone.bearingOffset, meters: zone.sketchDistanceMeters)
        return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    static func formatMiles(_ miles: Double) -> String {
        if abs(miles - miles.rounded()) < 0.05 {
            let whole = Int(miles.rounded())
            return whole == 1 ? "1 mile" : "\(whole) miles"
        }
        return String(format: "%.1f miles", miles)
    }
}
