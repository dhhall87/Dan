import Foundation

/// The rolling, in-memory trail of the last ~25 miles driven while the capture screen is open.
/// Powers "+1 mi back". Never saved to disk, and never recorded in the background.
struct BreadcrumbBuffer {
    /// Keep a point roughly every this many meters.
    static let sampleSpacing: Double = 50
    /// How much road to remember.
    static let maxLength: Double = 25 * Geo.metersPerMile
    /// A break in GPS updates longer than this (screen closed, app in the background) starts a new
    /// trail, because there's no way to know which road joined the two ends.
    static let maxGap: TimeInterval = 120
    /// Faster than this (m/s, about 155 mph) between two fixes means a GPS glitch or a jump, not
    /// driving, so the trail starts again rather than drawing a straight line across the map.
    static let maxPlausibleSpeed: Double = 70
    /// The tap position must be within this many meters of the newest trail point to walk back from it.
    static let maxStartGap: Double = 150
    /// If the trail runs out this close to the requested distance, that still counts.
    static let shortfallTolerance: Double = 50

    /// Oldest first.
    private(set) var points: [TrailPoint] = []
    /// Total road length covered by `points`, in meters.
    private(set) var length: Double = 0
    private var lastFix: (point: TrailPoint, time: Date)?

    mutating func add(_ point: TrailPoint, at timestamp: Date) {
        if let lastFix {
            if timestamp < lastFix.time { return }
            let elapsed = timestamp.timeIntervalSince(lastFix.time)
            let jumped = Geo.distance(lastFix.point, point) > Self.maxPlausibleSpeed * max(elapsed, 1)
            if elapsed > Self.maxGap || jumped { reset() }
        }
        lastFix = (point, timestamp)
        guard let last = points.last else {
            points = [point]
            return
        }
        let step = Geo.distance(last, point)
        guard step >= Self.sampleSpacing else { return }
        points.append(point)
        length += step
        trimToMaxLength()
    }

    mutating func reset() {
        points = []
        length = 0
        lastFix = nil
    }

    struct WalkBack: Equatable {
        /// The estimated spot `meters` back along the road.
        var target: TrailPoint
        /// The road driven, from the tap position back to `target`.
        var segment: [TrailPoint]
    }

    /// Walks backward along the trail from `start` (where the car was at the tap) by `meters` of road.
    /// Returns nil when the trail doesn't reach that far, or doesn't connect to `start`.
    func walkBack(from start: TrailPoint, meters: Double) -> WalkBack? {
        guard meters > 0, let newest = points.last,
              Geo.distance(start, newest) <= Self.maxStartGap else { return nil }
        var segment = [start]
        var covered = 0.0
        var previous = start
        for point in points.reversed() {
            let step = Geo.distance(previous, point)
            if covered + step >= meters {
                let fraction = step > 0 ? (meters - covered) / step : 0
                let target = Geo.interpolate(from: previous, to: point, fraction: fraction)
                segment.append(target)
                return WalkBack(target: target, segment: segment)
            }
            covered += step
            segment.append(point)
            previous = point
        }
        guard meters - covered <= Self.shortfallTolerance else { return nil }
        return WalkBack(target: previous, segment: segment)
    }

    private mutating func trimToMaxLength() {
        var dropCount = 0
        while points.count - dropCount > 2 {
            let oldestStep = Geo.distance(points[dropCount], points[dropCount + 1])
            guard length - oldestStep >= Self.maxLength else { break }
            length -= oldestStep
            dropCount += 1
        }
        if dropCount > 0 {
            points.removeFirst(dropCount)
        }
    }
}

/// Compact storage for a pin's trail segment: a JSON array of [latitude, longitude] pairs.
enum TrailCoding {
    static func encode(_ points: [TrailPoint]) -> Data? {
        guard !points.isEmpty else { return nil }
        return try? JSONEncoder().encode(points.map { [$0.latitude, $0.longitude] })
    }

    static func decode(_ data: Data?) -> [TrailPoint] {
        guard let data, let pairs = try? JSONDecoder().decode([[Double]].self, from: data) else { return [] }
        return pairs.compactMap { pair in
            pair.count == 2 ? TrailPoint(latitude: pair[0], longitude: pair[1]) : nil
        }
    }
}
