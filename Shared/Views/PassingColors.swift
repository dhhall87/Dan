import SwiftUI

/// The capture colors, taken from the app icon and shared with the widget so its buttons match the
/// phone screen. Near and far differ in brightness as well as color, so they stay distinct in
/// peripheral vision and for color-blind drivers.
extension Color {
    /// Behind the capture screen: near-black with a hint of the icon's night-sky navy.
    static let captureBackground = Color(red: 0.020, green: 0.027, blue: 0.051)
    /// Near zones: green like the grass verge, lighter at the top and fading to navy (Dan's values).
    static let nearZoneTop = Color(red: 49 / 255, green: 97 / 255, blue: 74 / 255)
    static let nearZoneBottom = Color(red: 26 / 255, green: 27 / 255, blue: 46 / 255)
    /// Far zones: a deep blue like the distance, lighter at the top (Dan's values).
    static let farZoneTop = Color(red: 30 / 255, green: 39 / 255, blue: 86 / 255)
    static let farZoneBottom = Color(red: 13 / 255, green: 27 / 255, blue: 49 / 255)
    /// The big Simple-mode button: the icon's navy.
    static let quickSurface = Color(red: 0.063, green: 0.102, blue: 0.188)
    /// The icon's road.
    static let asphalt = Color(red: 0.227, green: 0.251, blue: 0.294)
    /// The icon's pin and road markings.
    static let pinYellow = Color(red: 1.0, green: 0.780, blue: 0.0)

    /// A smooth top-to-bottom gradient for a zone. The labels sit in the middle, where both colors
    /// are still dark enough for the white text to stand out.
    static func zoneGradient(far: Bool) -> LinearGradient {
        LinearGradient(
            colors: far ? [farZoneTop, farZoneBottom] : [nearZoneTop, nearZoneBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A soft top-to-bottom shading of a capture color, so the buttons look designed rather than
    /// flat bars: slightly lighter at the top and darker at the bottom. The middle third, where the
    /// labels sit, keeps the full color, so the contrast with the white text doesn't change.
    var softGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: mix(with: .white, by: 0.10), location: 0),
                .init(color: self, location: 0.35),
                .init(color: self, location: 0.65),
                .init(color: mix(with: .black, by: 0.30), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
