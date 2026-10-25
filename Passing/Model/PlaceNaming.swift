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
}
