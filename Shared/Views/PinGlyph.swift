import SwiftUI

/// The map pin from the app icon: a round head tapering to a point. The hole is cut out, so whatever
/// is behind shows through, including in widget modes that tint or remove the background.
struct PinGlyph: View {
    var color: Color = .pinYellow

    var body: some View {
        PinShape()
            .fill(color, style: FillStyle(eoFill: true))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// The pin's outline and hole, drawn in a 24 × 24 box like the icon. Fill it even-odd to cut the hole.
struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let left = rect.midX - 12 * scale
        let top = rect.midY - 12 * scale
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: left + x * scale, y: top + y * scale)
        }
        var path = Path()
        path.move(to: point(12, 23))
        path.addLine(to: point(6, 14.7))
        path.addCurve(to: point(4, 9.3), control1: point(4.9, 13.2), control2: point(4, 11.5))
        path.addCurve(to: point(12, 1.5), control1: point(4, 4.9), control2: point(7.6, 1.5))
        path.addCurve(to: point(20, 9.3), control1: point(16.4, 1.5), control2: point(20, 4.9))
        path.addCurve(to: point(18, 14.7), control1: point(20, 11.5), control2: point(19.1, 13.2))
        path.closeSubpath()
        let radius = 3.1 * scale
        let center = point(12, 9.3)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path
    }
}

#Preview {
    PinGlyph()
        .frame(width: 132)
        .padding()
        .background(Color.quickSurface)
}
