import Foundation

/// A point on the road behind the car.
struct TrailPoint: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}

/// Small spherical-earth helpers. Accurate to well under 1% over the distances Passing cares about.
enum Geo {
    static let earthRadiusMeters = 6_371_000.0
    static let metersPerMile = 1_609.344

    /// Great-circle (haversine) distance in meters.
    static func distance(_ a: TrailPoint, _ b: TrailPoint) -> Double {
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
        let dφ = (b.latitude - a.latitude) * .pi / 180
        let dλ = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// A point part-way from `a` to `b`. Trail points are at most a few hundred meters apart,
    /// so a straight blend of the coordinates is plenty accurate.
    static func interpolate(from a: TrailPoint, to b: TrailPoint, fraction t: Double) -> TrailPoint {
        TrailPoint(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    /// The initial great-circle bearing from `a` to `b`, in degrees (0 = north, clockwise).
    static func bearing(from a: TrailPoint, to b: TrailPoint) -> Double {
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
        let dλ = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// The point `meters` from `start` along a straight (great-circle) line at `bearing` degrees.
    static func destination(from start: TrailPoint, bearing: Double, meters: Double) -> TrailPoint {
        let δ = meters / earthRadiusMeters
        let θ = bearing * .pi / 180
        let φ1 = start.latitude * .pi / 180, λ1 = start.longitude * .pi / 180
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        return TrailPoint(latitude: φ2 * 180 / .pi, longitude: λ2 * 180 / .pi)
    }

    /// Eight-point compass name for a bearing in degrees (0 = north): "southwest", or "SW" when `short`.
    static func compassName(for bearing: Double, short: Bool = false) -> String {
        let names = short
            ? ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            : ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let normalized = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized + 22.5) / 45) % 8]
    }

    /// "1 mile", "3 miles", "1.5 miles".
    static func milesText(_ miles: Double) -> String {
        if abs(miles - miles.rounded()) < 0.05 {
            let whole = Int(miles.rounded())
            return whole == 1 ? "1 mile" : "\(whole) miles"
        }
        return String(format: "%.1f miles", miles)
    }

    /// "1 mi", "3 mi", "1.5 mi".
    static func shortMilesText(_ miles: Double) -> String {
        if abs(miles - miles.rounded()) < 0.05 {
            return "\(Int(miles.rounded())) mi"
        }
        return String(format: "%.1f mi", miles)
    }
}
