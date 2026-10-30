import Foundation

/// What a light can do, read from its HomeKit characteristics.
struct LightCapabilities: Equatable, Hashable {
    /// Percent; nil if the light can't dim.
    var brightness: ClosedRange<Int>?
    /// Color temperature in mireds (1,000,000 ÷ kelvin): the low end is the coolest white,
    /// the high end the warmest. Nil if the light has no white tuning.
    var mireds: ClosedRange<Int>?
    var hueAndSaturation: Bool

    /// "Color", "White", or "Dimmable", for the light list.
    var kind: String {
        if hueAndSaturation { return "Color" }
        if mireds != nil { return "White" }
        return "Dimmable"
    }
}

/// One value written to one characteristic of a light.
enum LightWrite: Equatable {
    case power(Bool)
    case brightness(Int)
    case hue(Double)
    case saturation(Double)
    case mireds(Int)
}

enum LightWrites {
    /// The writes that put a light at `level`. Brightness and color come before power, which the
    /// preview relies on (it writes in this order, so a light comes on at the new level).
    static func writes(for level: SunriseLevel, turnOn: Bool, capabilities: LightCapabilities) -> [LightWrite] {
        var writes: [LightWrite] = []
        if let range = capabilities.brightness {
            let lowest = max(range.lowerBound, 1)
            writes.append(.brightness(min(max(level.brightness, lowest), max(range.upperBound, lowest))))
        }
        if let kelvin = level.kelvin {
            writes += colorWrites(kelvin: kelvin, capabilities: capabilities)
        }
        if turnOn { writes.append(.power(true)) }
        return writes
    }

    /// White tuning where the light can make that white; otherwise a color bulb's hue and
    /// saturation (the amber start of a sunrise is warmer than most bulbs' warmest white);
    /// otherwise the warmest white the light has.
    static func colorWrites(kelvin: Int, capabilities: LightCapabilities) -> [LightWrite] {
        let mireds = Int((1_000_000 / Double(max(kelvin, 1))).rounded())
        if let range = capabilities.mireds, mireds <= range.upperBound {
            return [.mireds(max(mireds, range.lowerBound))]
        }
        if capabilities.hueAndSaturation {
            let color = ColorMath.hueSaturation(kelvin: kelvin)
            return [.hue(color.hue), .saturation(color.saturation)]
        }
        if let range = capabilities.mireds {
            return [.mireds(range.upperBound)]
        }
        return []
    }
}
