import Foundation

/// The colors down a capture zone, plus a fixed "smoky" variation: a grid of slightly lighter and
/// darker spots that `ZoneFill` blends into soft wisps. Sampled from Dan's mockup; he chose the
/// subtle strength. Plain values in 0–255 RGB, so the rules are easy to unit test.
enum ZoneShade {
    struct Stop {
        var location: Double
        var rgb: SIMD3<Double>
    }

    /// Green, brightest about a sixth of the way down, staying green to the bottom.
    static let near: [Stop] = [
        Stop(location: 0, rgb: [25, 100, 72]),
        Stop(location: 0.15, rgb: [30, 108, 79]),
        Stop(location: 0.36, rgb: [25, 100, 72]),
        Stop(location: 0.59, rgb: [21, 88, 63]),
        Stop(location: 0.74, rgb: [18, 78, 60]),
        Stop(location: 0.88, rgb: [15, 68, 52]),
        Stop(location: 1, rgb: [11, 59, 45]),
    ]

    /// Blue, the same shape, staying blue to the bottom.
    static let far: [Stop] = [
        Stop(location: 0, rgb: [24, 50, 89]),
        Stop(location: 0.15, rgb: [24, 51, 92]),
        Stop(location: 0.36, rgb: [22, 46, 81]),
        Stop(location: 0.59, rgb: [17, 38, 67]),
        Stop(location: 0.74, rgb: [15, 35, 65]),
        Stop(location: 0.88, rgb: [13, 33, 61]),
        Stop(location: 1, rgb: [10, 27, 51]),
    ]

    /// The smoke grid: 4 spots across, 7 down.
    static let columns = 4
    static let rows = 7
    /// How far a spot can move from the plain color: ±9% ("Subtle"). Near and far still read as
    /// one green and one blue at a glance.
    static let smoke = 0.09

    /// The plain color `t` of the way down (0 top, 1 bottom).
    static func rgb(far isFar: Bool, at t: Double) -> SIMD3<Double> {
        let stops = isFar ? far : near
        let t = min(max(t, 0), 1)
        for (a, b) in zip(stops, stops.dropFirst()) where t <= b.location {
            let f = (t - a.location) / (b.location - a.location)
            return a.rgb + (b.rgb - a.rgb) * f
        }
        return stops[stops.count - 1].rgb
    }

    /// A fixed value in -1...1 for spot (`column`, `row`). `seed` gives each zone its own pattern,
    /// so the columns don't look copied. The same every time, so nothing shifts between launches.
    static func wisp(column: Int, row: Int, seed: Int) -> Double {
        let x = sin(Double(column) * 12.9898 + Double(row) * 78.233 + Double(seed) * 37.719) * 43758.5453
        return (x - x.rounded(.down)) * 2 - 1
    }

    /// `rgb` nudged lighter (and a touch paler, like smoke) or darker by `wisp`.
    static func smoky(_ rgb: SIMD3<Double>, wisp: Double) -> SIMD3<Double> {
        var color = rgb * (1 + wisp * smoke)
        if wisp > 0 {
            color += (SIMD3<Double>(repeating: 255) - color) * (wisp * smoke * 0.35)
        }
        return SIMD3(min(max(color.x, 0), 255), min(max(color.y, 0), 255), min(max(color.z, 0), 255))
    }

    /// Every spot's color, row by row from the top, for a zone with this `seed`.
    static func grid(far isFar: Bool, seed: Int) -> [SIMD3<Double>] {
        (0..<rows).flatMap { row in
            let base = rgb(far: isFar, at: Double(row) / Double(rows - 1))
            return (0..<columns).map { column in
                smoky(base, wisp: wisp(column: column, row: row, seed: seed))
            }
        }
    }
}
