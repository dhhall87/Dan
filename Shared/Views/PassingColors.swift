import SwiftUI

/// The capture colors, taken from the app icon and shared with the widget so its buttons match the
/// phone screen. Near and far differ in brightness as well as color, so they stay distinct in
/// peripheral vision and for color-blind drivers.
extension Color {
    /// Behind the capture screen: near-black with a hint of the icon's night-sky navy.
    static let captureBackground = Color(red: 0.020, green: 0.027, blue: 0.051)
    /// The big Simple-mode button: the icon's navy.
    static let quickSurface = Color(red: 0.063, green: 0.102, blue: 0.188)
    /// The icon's road.
    static let asphalt = Color(red: 0.227, green: 0.251, blue: 0.294)
    /// The icon's pin and road markings.
    static let pinYellow = Color(red: 1.0, green: 0.780, blue: 0.0)

    /// A zone's top-to-bottom shading, sampled from Dan's mockup: brightest about a sixth of the way
    /// down, then darkening smoothly while staying green (near) or blue (far) all the way, so the two
    /// never meet in the same navy. The labels sit in the middle, where white text stands out on both.
    static func zoneGradient(far: Bool) -> LinearGradient {
        func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
            Color(red: red / 255, green: green / 255, blue: blue / 255)
        }
        let stops: [Gradient.Stop] = far
            ? [
                .init(color: rgb(24, 50, 89), location: 0),
                .init(color: rgb(24, 51, 92), location: 0.15),
                .init(color: rgb(22, 46, 81), location: 0.36),
                .init(color: rgb(17, 38, 67), location: 0.59),
                .init(color: rgb(15, 35, 65), location: 0.74),
                .init(color: rgb(13, 33, 61), location: 0.88),
                .init(color: rgb(10, 27, 51), location: 1),
            ]
            : [
                .init(color: rgb(25, 100, 72), location: 0),
                .init(color: rgb(30, 108, 79), location: 0.15),
                .init(color: rgb(25, 100, 72), location: 0.36),
                .init(color: rgb(21, 88, 63), location: 0.59),
                .init(color: rgb(18, 78, 60), location: 0.74),
                .init(color: rgb(15, 68, 52), location: 0.88),
                .init(color: rgb(11, 59, 45), location: 1),
            ]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
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

/// A zone's fill: the top-to-bottom shading, with the side edges about 15% darker so each column
/// looks gently lit from the middle, as in Dan's mockup. Used by the phone's zones and the grid widget.
struct ZoneFill: View {
    let far: Bool

    var body: some View {
        Color.zoneGradient(far: far)
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.15), location: 0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .clear, location: 0.65),
                        .init(color: .black.opacity(0.15), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}
