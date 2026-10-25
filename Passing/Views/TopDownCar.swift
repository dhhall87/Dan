import SwiftUI

/// A simple top-down car, nose pointing up the screen.
struct TopDownCar: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Wheels
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: w * 0.06)
                        .fill(Color.black)
                        .frame(width: w * 0.16, height: h * 0.17)
                        .position(
                            x: index % 2 == 0 ? w * 0.06 : w * 0.94,
                            y: index < 2 ? h * 0.24 : h * 0.76
                        )
                }
                // Body
                RoundedRectangle(cornerRadius: w * 0.35)
                    .fill(Color.white)
                    .frame(width: w * 0.86, height: h)
                    .position(x: w / 2, y: h / 2)
                // Windshield
                RoundedRectangle(cornerRadius: w * 0.12)
                    .fill(Color(white: 0.15))
                    .frame(width: w * 0.66, height: h * 0.18)
                    .position(x: w / 2, y: h * 0.3)
                // Rear window
                RoundedRectangle(cornerRadius: w * 0.1)
                    .fill(Color(white: 0.15))
                    .frame(width: w * 0.62, height: h * 0.1)
                    .position(x: w / 2, y: h * 0.8)
                // Headlights
                HStack(spacing: w * 0.36) {
                    Capsule().fill(Color.yellow).frame(width: w * 0.14, height: h * 0.03)
                    Capsule().fill(Color.yellow).frame(width: w * 0.14, height: h * 0.03)
                }
                .position(x: w / 2, y: h * 0.05)
            }
        }
        .aspectRatio(0.5, contentMode: .fit)
        .shadow(color: .black.opacity(0.5), radius: 8)
        .accessibilityHidden(true)
    }
}

#Preview {
    TopDownCar()
        .frame(height: 200)
        .padding()
        .background(Color.gray)
}
