import Foundation

enum PlaceNaming {
    /// The town with a little context ("Garden City, KS") when Apple has it, otherwise the town on
    /// its own, otherwise whatever name the place has. Nil when there's nothing usable.
    static func name(cityWithContext: String?, cityName: String?, fallback: String?) -> String? {
        for candidate in [cityWithContext, cityName, fallback] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    /// Pins within about half a mile of each other share a town lookup, so a run of pins through one
    /// town asks Apple once. Coordinates rounded to two decimals (~1 km squares).
    static func cacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.2f,%.2f", latitude, longitude)
    }
}
