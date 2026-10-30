import Foundation

/// How bright the lights are at one step, and how warm (nil for brightness only).
struct SunriseLevel: Equatable {
    /// Percent.
    var brightness: Int
    var kelvin: Int?
}

/// The shape of the sunrise: when each step happens and what it looks like.
enum SunriseCurve {
    /// At most this many gaps between steps, so 16 steps plus the prep step. Each step is a scene
    /// and an automation in Apple's Home: more would be smoother but would crowd the Home app,
    /// and every save would take longer.
    static let maxIntervals = 15
    /// The first step's color, a deep amber like candlelight.
    static let startKelvin = 1500
    static let startBrightness = 1

    /// The choices on the main screen, in minutes.
    static let durations = [10, 15, 20, 30, 45, 60]

    /// Minutes from the wake time for each step, earliest first, ending at 0. Whole minutes,
    /// because HomeKit's time events have no seconds.
    static func offsets(durationMinutes: Int) -> [Int] {
        let duration = max(durationMinutes, 1)
        let intervals = min(duration, maxIntervals)
        return (0...intervals).map { -duration + $0 * duration / intervals }
    }

    /// The prep step sets the first step's level a minute early without turning the lights on.
    /// HomeKit runs a scene's actions in no set order, so a scene that turns a light on and dims
    /// it can flash the bulb's last brightness first.
    static func prepOffset(durationMinutes: Int) -> Int {
        -max(durationMinutes, 1) - 1
    }

    /// The level at `progress`: 0 at the first step, 1 at the wake time.
    static func level(at progress: Double, finalBrightness: Int, finalKelvin: Int?) -> SunriseLevel {
        let p = min(max(progress, 0), 1)
        let top = min(max(finalBrightness, startBrightness), 100)
        // Squared, so the early minutes stay very dim and most of the light comes near the end.
        let brightness = Int((Double(startBrightness) + Double(top - startBrightness) * p * p).rounded())
        guard let finalKelvin else { return SunriseLevel(brightness: brightness, kelvin: nil) }
        // Even steps in mireds (1,000,000 ÷ kelvin) look even to the eye and stay warm for longer.
        let startMireds = 1_000_000 / Double(startKelvin)
        let endMireds = 1_000_000 / Double(max(finalKelvin, startKelvin))
        let mireds = startMireds + (endMireds - startMireds) * p
        return SunriseLevel(brightness: brightness, kelvin: Int((1_000_000 / mireds).rounded()))
    }

    /// The level at each of `offsets(durationMinutes:)`, by time, so uneven gaps stay smooth.
    static func levels(durationMinutes: Int, finalBrightness: Int, finalKelvin: Int?) -> [SunriseLevel] {
        let times = offsets(durationMinutes: durationMinutes)
        let span = Double(times.first ?? 0)
        return times.map { offset in
            let progress = span == 0 ? 1 : 1 - Double(offset) / span
            return level(at: progress, finalBrightness: finalBrightness, finalKelvin: finalKelvin)
        }
    }

    /// A name for the white the sunrise ends on.
    static func colorName(kelvin: Int) -> String {
        switch kelvin {
        case ..<3300: "warm white"
        case ..<4600: "soft daylight"
        default: "daylight"
        }
    }
}

/// Colors of light by temperature.
enum ColorMath {
    /// The approximate color of light at `kelvin`, each channel 0–1 (Tanner Helland's fit to the
    /// blackbody curve, good from 1,000 K to 40,000 K).
    static func rgb(kelvin: Int) -> (red: Double, green: Double, blue: Double) {
        let t = Double(kelvin) / 100
        let red = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let green = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let blue: Double
        if t >= 66 {
            blue = 255
        } else if t <= 19 {
            blue = 0
        } else {
            blue = 138.5177312231 * log(t - 10) - 305.0447927307
        }
        return (channel(red), channel(green), channel(blue))
    }

    /// Hue (0–360°) and saturation (0–100%) for HomeKit's color characteristics, in whole numbers.
    static func hueSaturation(kelvin: Int) -> (hue: Double, saturation: Double) {
        let color = rgb(kelvin: kelvin)
        let high = max(color.red, color.green, color.blue)
        let low = min(color.red, color.green, color.blue)
        let spread = high - low
        let saturation = high == 0 ? 0 : spread / high * 100
        var hue: Double
        if spread == 0 {
            hue = 0
        } else if high == color.red {
            hue = 60 * ((color.green - color.blue) / spread).truncatingRemainder(dividingBy: 6)
        } else if high == color.green {
            hue = 60 * ((color.blue - color.red) / spread + 2)
        } else {
            hue = 60 * ((color.red - color.green) / spread + 4)
        }
        if hue < 0 { hue += 360 }
        return (hue.rounded(), saturation.rounded())
    }

    private static func channel(_ value: Double) -> Double {
        min(max(value, 0), 255) / 255
    }
}
