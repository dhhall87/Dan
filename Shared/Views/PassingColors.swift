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

/// A zone's fill: the top-to-bottom shading from Dan's mockup with a subtle smoky variation (a
/// `MeshGradient` through `ZoneShade.grid`), and side edges about 15% darker so each column looks
/// gently lit from the middle. Fixed, so it costs nothing after it's drawn. Used by the phone's
/// zones and the grid widget.
struct ZoneFill: View {
    let far: Bool
    /// Which zone, so each gets its own wisps rather than a copy of its neighbour's.
    var seed: Int = 0

    private static let points: [SIMD2<Float>] = (0..<ZoneShade.rows).flatMap { row in
        (0..<ZoneShade.columns).map { column in
            SIMD2(Float(column) / Float(ZoneShade.columns - 1), Float(row) / Float(ZoneShade.rows - 1))
        }
    }

    var body: some View {
        MeshGradient(
            width: ZoneShade.columns,
            height: ZoneShade.rows,
            points: Self.points,
            colors: ZoneShade.grid(far: far, seed: seed).map {
                Color(red: $0.x / 255, green: $0.y / 255, blue: $0.z / 255)
            }
        )
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
