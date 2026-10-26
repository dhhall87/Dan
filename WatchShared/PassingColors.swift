import SwiftUI

/// The capture colors, taken from the app icon and shared with the widgets and the watch so their
/// buttons match the phone screen. Near and far differ in brightness as well as color, so they stay distinct in
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

    // Tap feedback on the widgets and the watch. White text reads on all three.

    /// Saving, and saved with a location.
    static let savedGreen = Color(red: 0.12, green: 0.50, blue: 0.26)
    /// Saved, but no GPS reading arrived in time.
    static let noLocationAmber = Color(red: 0.62, green: 0.38, blue: 0.02)
    /// Not saved: the pin couldn't be written, so tap again.
    static let notSavedRed = Color(red: 0.70, green: 0.12, blue: 0.12)
}

/// A capture button's fill: the top-to-bottom shading (from Dan's mockup for the zones) with a
/// subtle smoky variation (a `MeshGradient` through `ZoneShade.grid`), and side edges about 15%
/// darker so each button looks gently lit from the middle. Fixed, so it costs nothing after it's
/// drawn. Used by the phone's zones and Pin it button, the widgets, and the watch's buttons.
struct ZoneFill: View {
    let surface: ZoneShade.Surface
    /// Which button, so each gets its own wisps rather than a copy of its neighbour's.
    var seed: Int = 0

    init(_ surface: ZoneShade.Surface, seed: Int = 0) {
        self.surface = surface
        self.seed = seed
    }

    init(far: Bool, seed: Int = 0) {
        self.init(far ? .far : .near, seed: seed)
    }

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
            colors: ZoneShade.grid(surface, seed: seed).map {
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
