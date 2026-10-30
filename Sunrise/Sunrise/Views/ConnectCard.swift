import SwiftUI
import UIKit

/// Shown until Sunrise can read a home: asks for access, waits, or explains what's missing.
struct ConnectCard: View {
    @Environment(SunriseModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            switch model.home.access {
            case .notAsked:
                Text("Sunrise fades your lights in through Apple Home, like the sky before dawn.")
                    .font(.headline)
                Text("It needs access to your home to find your lights and add the sunrise to it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    model.home.connect()
                } label: {
                    Text("Connect to Home")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
            case .waiting:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Opening your home…")
                }
            case .denied:
                Text("Sunrise can't see your home.")
                    .font(.headline)
                Text("Turn on Home access for Sunrise in Settings → Privacy & Security → HomeKit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.bordered)
            case .allowed:
                Text("No home yet.")
                    .font(.headline)
                Text("Set up a home in Apple's Home app with your lights in it, then come back.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
