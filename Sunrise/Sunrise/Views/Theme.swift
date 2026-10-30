import SwiftUI

/// Night sky at the top, the first light of dawn at the bottom.
struct SunriseBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.05, blue: 0.13),
                Color(red: 0.11, green: 0.07, blue: 0.18),
                Color(red: 0.25, green: 0.11, blue: 0.14),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08))
            )
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}

/// The sunrise drawn as a strip: each step's color, brighter as it goes.
struct SunriseStrip: View {
    let levels: [SunriseLevel]

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing))
            )
            .frame(height: 44)
            .accessibilityHidden(true)
    }

    private var stops: [Gradient.Stop] {
        guard levels.count > 1 else { return [Gradient.Stop(color: .orange, location: 0)] }
        return levels.enumerated().map { index, level in
            Gradient.Stop(color: Self.color(for: level), location: Double(index) / Double(levels.count - 1))
        }
    }

    /// The step's color, faded by brightness (square root, so the dim start still shows).
    static func color(for level: SunriseLevel) -> Color {
        let light = ColorMath.rgb(kelvin: level.kelvin ?? 3000)
        let opacity = 0.15 + 0.85 * (Double(level.brightness) / 100).squareRoot()
        return Color(red: light.red, green: light.green, blue: light.blue).opacity(opacity)
    }
}
