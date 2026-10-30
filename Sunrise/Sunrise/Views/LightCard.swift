import SwiftUI

/// How long the sunrise takes, how bright it ends, and its colors.
struct LightCard: View {
    @Binding var settings: SunriseSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Light")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("Sunrise length (minutes)")
                    .font(.subheadline)
                Picker("Sunrise length", selection: $settings.durationMinutes) {
                    ForEach(SunriseCurve.durations, id: \.self) { minutes in
                        Text("\(minutes)").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Brightness at the end", value: "\(settings.finalBrightness)%")
                    .font(.subheadline)
                Slider(value: brightness, in: 10...100, step: 5)
            }
            Toggle(isOn: $settings.usesColor) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sunrise colors")
                    Text(settings.usesColor
                         ? "Amber, then gold, then white."
                         : "Brightness only. The lights keep their color, including Adaptive Lighting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if settings.usesColor {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Ends on", value: "\(SunriseCurve.colorName(kelvin: settings.finalKelvin).capitalized) (\(settings.finalKelvin) K)")
                        .font(.subheadline)
                    Slider(value: kelvin, in: 2700...6500, step: 100)
                }
            }
        }
        .card()
    }

    private var brightness: Binding<Double> {
        Binding(
            get: { Double(settings.finalBrightness) },
            set: { settings.finalBrightness = Int($0.rounded()) }
        )
    }

    private var kelvin: Binding<Double> {
        Binding(
            get: { Double(settings.finalKelvin) },
            set: { settings.finalKelvin = Int($0.rounded()) }
        )
    }
}
