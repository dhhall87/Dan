import SwiftUI
import UIKit

/// The screen used while driving. A tap saves a pin immediately; confirmation is a haptic and a
/// tone, never something to read. Nothing pops up or changes screens after a tap.
struct CaptureView: View {
    @AppStorage(SettingsKey.captureMode) private var mode: CaptureMode = .quick

    private let location = LocationProvider.shared

    var body: some View {
        VStack(spacing: 0) {
            if location.isDenied {
                // A standing notice, not a reaction to a tap.
                Label("Location is off. Pins save without a position.", systemImage: "location.slash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.orange)
            }
            switch mode {
            case .quick: QuickCapture()
            case .fourZone: FourZoneCapture()
            }
            MilesBackStrip()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            // Keep the screen awake while it's mounted on the dash.
            UIApplication.shared.isIdleTimerDisabled = true
            location.setCaptureScreenVisible(true)
            CaptureFeedback.shared.prepare()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            location.setCaptureScreenVisible(false)
        }
    }
}

// MARK: Quick mode

private struct QuickCapture: View {
    var body: some View {
        Button {
            CaptureService.shared.capture(side: .unknown, distance: .unknown, source: .app)
        } label: {
            VStack(spacing: 20) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 96, weight: .bold))
                Text("Tap anywhere to pin")
                    .font(.largeTitle.weight(.heavy))
                Text("Capture now. Investigate later.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.quickSurface, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 24))
        .padding(8)
        .accessibilityLabel("Save a pin")
    }
}

// MARK: Four-zone mode

/// Laid out exactly as the road looks: | Far left | Near left | car | Near right | Far right |
private struct FourZoneCapture: View {
    var body: some View {
        HStack(spacing: 6) {
            ZoneColumn(zone: .farLeft)
            ZoneColumn(zone: .nearLeft)
            CarDivider()
            ZoneColumn(zone: .nearRight)
            ZoneColumn(zone: .farRight)
        }
        .padding(6)
    }
}

private struct ZoneColumn: View {
    let zone: CaptureZone

    private var isFar: Bool { zone.distance == .far }
    private var isLeft: Bool { zone.side == .left }

    var body: some View {
        Button {
            CaptureService.shared.capture(side: zone.side, distance: zone.distance, source: .app)
        } label: {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: isLeft ? "arrow.up.left" : "arrow.up.right")
                    .font(.title2.weight(.bold))
                Text(isFar ? "FAR" : "NEAR")
                    .font(.title3.weight(.heavy))
                Text(isLeft ? "left" : "right")
                    .font(.headline)
                Text(isFar ? "Beyond\nroadside" : "Roadside\n")
                    .font(.caption)
                    .opacity(0.75)
                Spacer()
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isFar ? Color.farZone : Color.nearZone, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 16))
        .accessibilityLabel("Save pin, \(zone.distance.title.lowercased()) \(zone.side.title.lowercased())")
    }
}

/// The narrow centre divider. Tapping the car saves a pin with the side unknown.
private struct CarDivider: View {
    var body: some View {
        Button {
            CaptureService.shared.capture(side: .unknown, distance: .unknown, source: .app)
        } label: {
            TopDownCar()
                .frame(width: 28)
                .frame(maxHeight: .infinity)
                .frame(width: 48)
                .background(Color.quickSurface, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 12))
        .accessibilityLabel("Save pin, side unknown")
    }
}

// MARK: +1 mi back

/// One tap saves a pin 1 mile back along the road just driven; each extra tap within 4 seconds
/// pushes that same pin another mile back. Confirmed by haptic and tone on every tap, never by reading.
private struct MilesBackStrip: View {
    var body: some View {
        Button {
            CaptureService.shared.captureMilesBack(source: .app)
        } label: {
            Label("+1 mi back", systemImage: "arrow.uturn.backward")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color.milesBackSurface, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 16))
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .accessibilityLabel("Save a pin one mile back. Tap again to move it further back.")
    }
}

/// Lights up whatever is being pressed. This is the only visual feedback, and it's optional to see.
struct PressHighlightStyle: ButtonStyle {
    var cornerRadius: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0))
            )
    }
}

extension Color {
    /// Near zones: green, like the grass verge.
    static let nearZone = Color(red: 0.13, green: 0.38, blue: 0.25)
    /// Far zones: blue, like the distance.
    static let farZone = Color(red: 0.15, green: 0.28, blue: 0.55)
    static let quickSurface = Color(white: 0.13)
    /// Dark amber, so "+1 mi back" stands apart from the zones.
    static let milesBackSurface = Color(red: 0.42, green: 0.29, blue: 0.04)
}

#Preview("Four zones") {
    NavigationStack {
        CaptureView()
    }
    .onAppear { UserDefaults.standard.set(CaptureMode.fourZone.rawValue, forKey: SettingsKey.captureMode) }
}
