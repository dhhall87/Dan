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
    /// Two fixes farther apart than this (meters) with nothing between them could have any road
    /// between them, a turn or a bend, so the trail starts again rather than cutting the corner with
    /// a straight line. Fixes arrive about once a second, so while driving they're well under 100 m
    /// apart; this only trips after a gap (a tunnel, poor GPS, or the capture screen closed a while).
    static let maxJoin: Double = 300
    /// The tap position must be within this many meters of the newest trail point to walk back from it.
    static let maxStartGap: Double = 150
    /// If the trail runs out this close to the requested distance, that still counts.
    static let shortfallTolerance: Double = 50

    /// Oldest first.
    private(set) var points: [TrailPoint] = []
    /// Total road length covered by `points`, in meters.
    private(set) var length: Double = 0
    private var lastFix: (point: TrailPoint, time: Date)?

    /// Why the trail started again, for the drive log.
    struct Restart: Equatable {
        enum Reason: String {
            /// Readings more than `maxJoin` apart: a turn could hide between them.
            case gap
            /// Faster than `maxPlausibleSpeed`: a GPS glitch.
            case jump
            /// No reading for more than `maxGap`.
            case longBreak
        }
        var reason: Reason
        var seconds: TimeInterval
        var meters: Double
        /// How much trail was dropped.
        var lostMeters: Double
    }

    /// Adds a reading. Returns why the trail started again, if this reading made it.
    @discardableResult
    mutating func add(_ point: TrailPoint, at timestamp: Date) -> Restart? {
        var restart: Restart?
        if let lastFix {
            if timestamp < lastFix.time { return nil }
            let elapsed = timestamp.timeIntervalSince(lastFix.time)
            let apart = Geo.distance(lastFix.point, point)
            let reason: Restart.Reason? = elapsed > Self.maxGap ? .longBreak
                : apart > Self.maxPlausibleSpeed * max(elapsed, 1) ? .jump
                : apart > Self.maxJoin ? .gap
                : nil
            if let reason {
                restart = Restart(reason: reason, seconds: elapsed, meters: apart, lostMeters: length)
                reset()
            }
        }
        lastFix = (point, timestamp)
        guard let last = points.last else {
            points = [point]
            return restart
        }
        let step = Geo.distance(last, point)
        guard step >= Self.sampleSpacing else { return restart }
        points.append(point)
        length += step
        trimToMaxLength()
        return restart
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

    /// At least this much trail (meters) gives a steady enough direction to carry on in.
    static let minDirectionRun: Double = 100

    /// Where "`meters` back" probably is, even when the trail doesn't reach that far.
    struct Estimate: Equatable {
        var target: TrailPoint
        /// The road driven, from the tap position back as far as the trail goes.
        var segment: [TrailPoint]
        /// How much of the way (meters) is a straight line past the end of the trail: 0 when the
        /// trail covered it all; otherwise the estimate is a rough guess.
        var straightMeters: Double
    }

    /// Walks back along the trail like `walkBack`. If the trail runs out first (Passing was opened a
    /// moment ago, or the phone had locked), it carries on in a straight line for the rest: in the
    /// direction of the trail's oldest stretch, or, with less than `minDirectionRun` of trail, opposite
    /// `heading` (the car's direction of travel at the tap, degrees). Nil when neither is known.
    func estimateBack(from start: TrailPoint, meters: Double, heading: Double?) -> Estimate? {
        guard meters > 0 else { return nil }
        if let walk = walkBack(from: start, meters: meters) {
            return Estimate(target: walk.target, segment: walk.segment, straightMeters: 0)
        }
        var segment = [start]
        var covered = 0.0
        if let newest = points.last, Geo.distance(start, newest) <= Self.maxStartGap {
            var previous = start
            for point in points.reversed() {
                covered += Geo.distance(previous, point)
                segment.append(point)
                previous = point
            }
        }
        let end = segment[segment.count - 1]
        let backBearing: Double
        if covered >= Self.minDirectionRun {
            // The last minDirectionRun meters of trail, continued the same way.
            var index = segment.count - 2
            while index > 0, Geo.distance(segment[index], end) < Self.minDirectionRun {
                index -= 1
            }
            backBearing = Geo.bearing(from: segment[index], to: end)
        } else if let heading {
            backBearing = (heading + 180).truncatingRemainder(dividingBy: 360)
        } else {
            return nil
        }
        let straight = meters - covered
        return Estimate(
            target: Geo.destination(from: end, bearing: backBearing, meters: straight),
            segment: segment,
            straightMeters: straight
        )
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
