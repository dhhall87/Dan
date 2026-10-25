import Foundation

/// A point on the road we recently drove over.
struct TrailPoint: Equatable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
}

/// Small spherical-earth helpers. Accurate to well under 1% over the distances RoadPin cares about.
enum Geo {
    static let earthRadiusMeters = 6_371_000.0
    static let metersPerMile = 1_609.344

    static func distance(_ a: TrailPoint, _ b: TrailPoint) -> Double {
        distance(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    /// Great-circle (haversine) distance in meters.
    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180
        let dφ = (lat2 - lat1) * .pi / 180
        let dλ = (lon2 - lon1) * .pi / 180
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// The point `meters` away from a start point along a compass bearing (0 = north, 90 = east).
    static func destination(latitude: Double, longitude: Double, bearing: Double, meters: Double) -> (latitude: Double, longitude: Double) {
        let δ = meters / earthRadiusMeters
        let θ = bearing * .pi / 180
        let φ1 = latitude * .pi / 180
        let λ1 = longitude * .pi / 180
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        let lon = (λ2 * 180 / .pi + 540).truncatingRemainder(dividingBy: 360) - 180
        return (φ2 * 180 / .pi, lon)
    }

    /// Eight-point compass name for a bearing in degrees.
    static func compassName(for bearing: Double) -> String {
        let names = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let normalized = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized + 22.5) / 45) % 8]
    }
}

/// The last stretch of road we drove, so a "miles back" pin can land on the road
/// we were actually on instead of in a straight line behind the car.
struct BreadcrumbTrail {
    /// How much road to remember.
    var maxLengthMeters: Double = 50 * Geo.metersPerMile
    /// Points closer together than this are skipped to keep the trail small.
    var minSpacingMeters: Double = 15
    /// A gap in GPS updates longer than this (phone off, app closed) starts a new trail,
    /// because we don't know which road connected the two ends.
    var maxGap: TimeInterval = 5 * 60

    /// Oldest first.
    private(set) var points: [TrailPoint] = []
    private(set) var lengthMeters: Double = 0

    mutating func append(_ point: TrailPoint) {
        guard let last = points.last else {
            points = [point]
            return
        }
        if point.timestamp.timeIntervalSince(last.timestamp) > maxGap {
            reset()
            points = [point]
            return
        }
        let step = Geo.distance(last, point)
        guard step >= minSpacingMeters else { return }
        points.append(point)
        lengthMeters += step
        trimToMaxLength()
    }

    mutating func reset() {
        points = []
        lengthMeters = 0
    }

    /// Walks back along the trail from the newest point.
    ///
    /// - Returns: the point `meters` back along the road, and how much of that distance the trail
    ///   actually covered. When the trail is shorter than `meters`, the oldest point is returned and
    ///   `metersCovered` is less than `meters`. Returns nil when there is no trail at all.
    func point(metersBack meters: Double) -> (point: TrailPoint, metersCovered: Double)? {
        guard var newer = points.last else { return nil }
        guard meters > 0 else { return (newer, 0) }
        var covered = 0.0
        for older in points.dropLast().reversed() {
            let step = Geo.distance(older, newer)
            if covered + step >= meters {
                let fraction = step > 0 ? (meters - covered) / step : 0
                return (interpolate(from: newer, to: older, fraction: fraction), meters)
            }
            covered += step
            newer = older
        }
        return (newer, covered)
    }

    private func interpolate(from a: TrailPoint, to b: TrailPoint, fraction t: Double) -> TrailPoint {
        // Trail points are at most a few hundred meters apart, so a straight blend is plenty accurate.
        TrailPoint(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t,
            timestamp: a.timestamp.addingTimeInterval(b.timestamp.timeIntervalSince(a.timestamp) * t)
        )
    }

    private mutating func trimToMaxLength() {
        var dropCount = 0
        while points.count - dropCount > 2 {
            let first = Geo.distance(points[dropCount], points[dropCount + 1])
            guard lengthMeters - first >= maxLengthMeters else { break }
            lengthMeters -= first
            dropCount += 1
        }
        if dropCount > 0 { points.removeFirst(dropCount) }
    }
}
