import SwiftUI
import UIKit

/// The screen you use while driving: four big tap zones around the car (or one giant button),
/// with "+1 mi back" along the bottom.
struct DriveView: View {
    @AppStorage(SettingsKey.mode) private var mode: PinMode = .zones
    @State private var flashedZone: RoadZone?
    @State private var flashWholeScreen = false

    private let recorder = PinRecorder.shared
    private let tracker = LocationTracker.shared

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                switch mode {
                case .zones: zones
                case .oneButton: bigButton
                }
                StatusBanner(status: recorder.status, locationDenied: tracker.isDenied)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 0.2), value: recorder.status)
            milesBackButton
        }
        .background(Color.black.ignoresSafeArea())
        // Keep the screen on while it's mounted on the dash, like a navigation app.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Four zones

    private var zones: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(RoadZone.allCases) { zone in
                    Button {
                        drop(zone)
                    } label: {
                        ZoneColumn(zone: zone, isFlashing: flashedZone == zone)
                    }
                    .buttonStyle(PressHighlightStyle())
                    .accessibilityLabel("Drop a pin, \(zone.title.lowercased())")
                }
            }
            .overlay {
                TopDownCar()
                    .frame(width: min(geo.size.width * 0.16, 80))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: One big button

    private var bigButton: some View {
        Button {
            drop(nil)
        } label: {
            ZStack {
                Color.asphalt
                Color.yellow.opacity(flashWholeScreen ? 0.5 : 0)
                VStack(spacing: 24) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 110, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text("Tap anywhere\nto drop a pin")
                        .font(.largeTitle.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressHighlightStyle())
        .accessibilityLabel("Drop a pin")
    }

    // MARK: +1 mi back

    private var milesBackButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await recorder.addMileBack(origin: .phone) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward")
                if recorder.pendingMilesBack > 0 {
                    Text("\(Pin.formatMiles(recorder.pendingMilesBack)) back · tap for +1")
                } else {
                    Text("+1 mi back")
                }
            }
            .font(.title3.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.yellow)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressHighlightStyle())
        .accessibilityLabel(recorder.pendingMilesBack > 0 ? "Move the pin another mile back" : "Drop a pin one mile back")
    }

    // MARK: Actions

    private func drop(_ zone: RoadZone?) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        flash(zone)
        Task { await recorder.dropPin(zone: zone, origin: .phone) }
    }

    private func flash(_ zone: RoadZone?) {
        withAnimation(.easeOut(duration: 0.1)) {
            flashedZone = zone
            flashWholeScreen = zone == nil
        }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.4)) {
                flashedZone = nil
                flashWholeScreen = false
            }
        }
    }
}

/// One of the four columns. The inside two are the road, the outside two are the roadside.
private struct ZoneColumn: View {
    let zone: RoadZone
    let isFlashing: Bool

    var body: some View {
        ZStack {
            zone.isFar ? Color.roadside : Color.asphalt
            // Road edge between the roadside and the road, dashed centre line between the two lanes.
            HStack {
                if zone == .farRight || zone == .nearRight {
                    edge
                    Spacer()
                } else {
                    Spacer()
                    edge
                }
            }
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: zone.isLeft ? "arrow.left" : "arrow.right")
                    .font(.title2.weight(.bold))
                Text(zone.isFar ? "FAR" : "NEAR")
                    .font(.title3.weight(.heavy))
                Text(zone.isLeft ? "left" : "right")
                    .font(.subheadline.weight(.semibold))
                Spacer().frame(height: 28)
            }
            .foregroundStyle(.white.opacity(0.85))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            Color.yellow.opacity(isFlashing ? 0.55 : 0)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var edge: some View {
        if zone.isFar {
            Rectangle().fill(Color.white.opacity(0.9)).frame(width: 4)
        } else {
            VerticalLine()
                .stroke(Color.yellow.opacity(0.8), style: StrokeStyle(lineWidth: 4, dash: [26, 20]))
                .frame(width: 2)
        }
    }
}

private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// Brightens whatever is pressed so a tap is obvious out of the corner of your eye.
struct PressHighlightStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(Color.white.opacity(configuration.isPressed ? 0.25 : 0))
    }
}

struct StatusBanner: View {
    let status: PinRecorder.Status
    let locationDenied: Bool

    var body: some View {
        if let message {
            Label(message.text, systemImage: message.icon)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.tint, in: Capsule())
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var message: (text: String, icon: String, tint: Color)? {
        if locationDenied {
            return ("Location is off for RoadPin. Turn it on in Settings.", "location.slash", .red)
        }
        switch status {
        case .idle:
            return nil
        case .locating:
            return ("Finding your location…", "location", Color(white: 0.3))
        case .saved(let text):
            return (text, "checkmark.circle.fill", .green)
        case .listening(let heard):
            return (heard.isEmpty ? "Pin saved · listening…" : "“\(heard)”", "waveform", .blue)
        case .failed(let text):
            return (text, "exclamationmark.triangle.fill", .red)
        }
    }
}

extension Color {
    static let asphalt = Color(red: 0.20, green: 0.21, blue: 0.24)
    static let roadside = Color(red: 0.11, green: 0.22, blue: 0.14)
}

#Preview {
    NavigationStack {
        DriveView()
    }
}
