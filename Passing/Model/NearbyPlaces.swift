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

    /// "Look farther" after a first search finds little.
    static let widerRadius: Double = 2_000

    /// At most this many places are listed, closest first.
    static let maxShown = 15

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
