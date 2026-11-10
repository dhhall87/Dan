import Foundation

/// Rules for "What's here?" on a pin's screen, as plain values so they're easy to unit test.
enum NearbyPlaces {
    /// How far around the pin to look, in meters. Far-side things can be a few fields away.
    static func searchRadius(for distance: Distance) -> Double {
        switch distance {
        case .near: return 300
        case .far, .unknown: return 600
        }
    }

    /// "Look Farther": about a mile around the pin.
    static let widerRadius: Double = 1_609

    /// At most this many places are listed, closest first: enough to find the one you passed,
    /// short enough to scan (7, Dan's choice).
    static let maxShown = 7
    /// After Look Farther, a longer list (15, Dan's choice).
    static let maxShownFarther = 15

    /// How many places to list for a search this wide.
    static func maxShown(radius: Double) -> Int {
        radius >= widerRadius ? maxShownFarther : maxShown
    }

    /// A place this close to dead ahead or dead behind (degrees) isn't called left or right.
    static let sideDeadZone: Double = 15

    /// Which side of the road a place is on, from the car's direction of travel (`course`, degrees)
    /// and the compass bearing from the car to the place. Unknown when it's nearly straight ahead
    /// or behind.
    static func side(course: Double, bearingToPlace: Double) -> Side {
        let relative = ((bearingToPlace - course).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        if relative < sideDeadZone || relative > 360 - sideDeadZone { return .unknown }
        if abs(relative - 180) < sideDeadZone { return .unknown }
        return relative < 180 ? .right : .left
    }

    /// The listed places with those on the side the driver tapped first, each part still closest
    /// first. `sides` holds each place's side, in the same order. Nothing moves when the tap had no
    /// side. The list is cut to length before this, so it never hides a closer place.
    static func tappedSideFirst<Place>(_ places: [Place], sides: [Side], tapped: Side) -> [Place] {
        guard tapped != .unknown, places.count == sides.count else { return places }
        let matching = zip(places, sides).filter { $0.1 == tapped }.map(\.0)
        let others = zip(places, sides).filter { $0.1 != tapped }.map(\.0)
        return matching + others
    }

    /// "Gas Station" from Apple's "MKPOICategoryGasStation"; nil for an unknown format.
    static func categoryTitle(fromRawValue raw: String) -> String? {
        let prefix = "MKPOICategory"
        guard raw.hasPrefix(prefix), raw.count > prefix.count else { return nil }
        let name = raw.dropFirst(prefix.count)
        var words: [String] = []
        var current = ""
        let characters = Array(name)
        for (index, character) in characters.enumerated() {
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            // A new word starts at a capital after a lowercase letter ("GasStation"), or at the last
            // capital of a run before a lowercase letter ("EVCharger" -> "EV", "Charger").
            let startsWord = character.isUppercase && !current.isEmpty
                && (current.last?.isLowercase == true || next?.isLowercase == true)
            if startsWord {
                words.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        return words.joined(separator: " ")
    }

    /// "350 ft" up close, "0.4 mi" farther away, as US drivers read distances.
    static func distanceText(meters: Double) -> String {
        let miles = meters / Geo.metersPerMile
        if miles < 0.1 {
            let feet = Int((meters * 3.280_84 / 10).rounded()) * 10
            return "\(max(feet, 10)) ft"
        }
        return String(format: "%.1f mi", miles)
    }
}
