import SwiftUI
import UIKit

/// The screen used while driving. A tap saves a pin immediately; confirmation is a haptic and a
/// tone, never something to read. Nothing pops up or changes screens after a tap.
///
/// Sized for an iPhone 16 Pro (402 × 874 points) but laid out flexibly, because iOS 27 lets iPhone
/// apps be resized. The capture buttons are solid colors rather than Liquid Glass, so iOS 27's glass
/// slider can't make them fainter; glass is only on the title bar buttons and the GPS pill.
struct CaptureView: View {
    /// Simple or Four zones. RootView decides: the Settings choice, or the title-button switch.
    let mode: CaptureMode
    /// The title button: flip between Simple and Four zones for the drive.
    var switchMode: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowing = false

    private let location = LocationProvider.shared
    private let feedback = CaptureFeedback.shared

    var body: some View {
        VStack(spacing: 0) {
            // A fixed height, so the capture buttons never move when Stop listening swaps in.
            Group {
                if feedback.isListening {
                    StopListeningButton()
                } else {
                    ModeTitleButton(mode: mode, action: switchMode)
                }
            }
            .frame(height: 62)
            switch mode {
            case .quick: QuickCapture()
            case .fourZone: FourZoneCapture()
            }
            BottomButtons()
        }
        .background(Color.captureBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onAppear {
            // Keep the screen awake while it's mounted on the dash.
            UIApplication.shared.isIdleTimerDisabled = true
            isShowing = true
            updateLocation()
            CaptureFeedback.shared.prepare()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            isShowing = false
            updateLocation()
        }
        .onChange(of: scenePhase) {
            updateLocation()
        }
    }

    /// GPS runs while this screen is showing and Passing is open, and stops the moment Passing goes
    /// to the background. (Pulling down Control Center or a Siri request doesn't count as leaving.)
    private func updateLocation() {
        location.setCaptureScreenVisible(isShowing && scenePhase != .background)
    }
}

// MARK: Title and GPS pill

/// The capture screen's title, which is also the layout switch: "Passing" over "Simple" or
/// "Four zones". A tap flips the layout with a light click; nothing else changes on screen.
struct ModeTitleButton: View {
    let mode: CaptureMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Big and bold, about twice a standard title, in the same rounded face as the zone
                // labels; the layout line stays small.
                Text("Passing")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2.weight(.bold))
                    Text(mode.title)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.pinYellow)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture screen, \(mode.title)")
        .accessibilityHint("Switches between Simple and Four zones")
    }
}

/// Listen after tap: turn the microphone off now. While Passing listens it takes the place of the
/// title (and the GPS pill hides), so it never moves or covers the capture buttons. It never has to
/// be used: listening stops by itself after a few seconds.
private struct StopListeningButton: View {
    var body: some View {
        Button {
            CaptureFeedback.shared.stopListening()
        } label: {
            Label("Stop listening", systemImage: "mic.slash.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity)
                .background(Color.red, in: Capsule())
                .padding(.vertical, 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Whether a tap right now gets a position. Sits in the title bar, above the Passing title.
/// A standing notice, never a reaction to a tap, and never needed to capture: pins save in every state.
struct GPSPill: View {
    private let location = LocationProvider.shared

    var body: some View {
        // Once a second, because a fix goes stale with time as well as with new readings.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = GPSStatus(
                isAuthorized: location.isAuthorized,
                isDenied: location.isDenied,
                isPreciseLocationOff: location.isPreciseLocationOff,
                hasFreshFix: location.freshFix(now: context.date) != nil
            )
            HStack(spacing: 6) {
                Circle()
                    .fill(status.dotColor)
                    .frame(width: 6, height: 6)
                Text(status.title)
                    .lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .glassEffect(.regular, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(status.pinsGetAPosition ? status.title : "\(status.title). Pins still save, without a position.")
        }
    }
}

private extension GPSStatus {
    var dotColor: Color {
        switch self {
        case .ready: return .green
        case .searching: return .yellow
        case .notAsked: return .gray
        case .off: return .red
        case .notPrecise: return .orange
        }
    }
}

// MARK: Simple mode

private struct QuickCapture: View {
    var body: some View {
        Button {
            CaptureService.shared.capture(side: .unknown, distance: .unknown, source: .app)
        } label: {
            VStack(spacing: 10) {
                // Shrinks first when the window is short (landscape, or a resized window on iOS 27).
                PinGlyph()
                    .frame(minWidth: 44, maxWidth: 132, minHeight: 44, maxHeight: 132)
                Text("Pin it")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .padding(.top, 8)
                Text("Tap anywhere")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.66, green: 0.70, blue: 0.78))
            }
            .foregroundStyle(.white)
            .minimumScaleFactor(0.6)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.quickSurface.softGradient, in: RoundedRectangle(cornerRadius: 36))
            .overlay(RoundedRectangle(cornerRadius: 36).strokeBorder(.white.opacity(0.08)))
            .contentShape(RoundedRectangle(cornerRadius: 36))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 36))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .accessibilityLabel("Save a pin")
    }
}

// MARK: Four-zone mode

/// Laid out exactly as the road looks: | Far left | Near left | road | Near right | Far right |
private struct FourZoneCapture: View {
    var body: some View {
        HStack(spacing: 6) {
            ZoneColumn(zone: .farLeft)
            ZoneColumn(zone: .nearLeft)
            RoadDivider()
            ZoneColumn(zone: .nearRight)
            ZoneColumn(zone: .farRight)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
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
            VStack(spacing: 6) {
                Image(systemName: isLeft ? "arrow.up.left" : "arrow.up.right")
                    .font(.system(size: 24, weight: .bold))
                Text(isFar ? "FAR" : "NEAR")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                Text(isLeft ? "left" : "right")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((isFar ? Color.farZone : Color.nearZone).softGradient, in: RoundedRectangle(cornerRadius: 26))
            // A faint edge, so neighbouring columns read as separate shapes rather than one block.
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.07)))
            .contentShape(RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 26))
        .accessibilityLabel("Save pin, \(zone.distance.title.lowercased()) \(zone.side.title.lowercased())")
    }
}

/// The narrow centre divider, drawn as the road with the car on it. Tapping it saves a pin with the
/// side unknown.
private struct RoadDivider: View {
    var body: some View {
        Button {
            CaptureService.shared.capture(side: .unknown, distance: .unknown, source: .app)
        } label: {
            ZStack(alignment: .bottom) {
                RoadMarkings()
                TopDownCar()
                    .frame(width: 24)
                    .padding(.bottom, 22)
            }
            .frame(width: 46)
            .frame(maxHeight: .infinity)
            .background(Color.asphalt)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 18))
        .accessibilityLabel("Save pin, side unknown")
    }
}

/// White edge lines and a dashed yellow centre line, like the app icon's road.
private struct RoadMarkings: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: 5, y: 0))
                path.addLine(to: CGPoint(x: 5, y: height))
                path.move(to: CGPoint(x: width - 5, y: 0))
                path.addLine(to: CGPoint(x: width - 5, y: height))
            }
            .stroke(Color.white.opacity(0.92), lineWidth: 2.5)
            Path { path in
                path.move(to: CGPoint(x: width / 2, y: 0))
                path.addLine(to: CGPoint(x: width / 2, y: height))
            }
            .stroke(Color.pinYellow, style: StrokeStyle(lineWidth: 3, dash: [18, 16]))
        }
        .accessibilityHidden(true)
    }
}

// MARK: +1 mi back

/// One tap saves a pin 1 mile back along the road just driven; each extra tap within 4 seconds
/// pushes that same pin another mile back. Confirmed by haptic and tone on every tap, never by reading.
/// "+1 mi back" and "Add a note", side by side under the capture area.
private struct BottomButtons: View {
    var body: some View {
        HStack(spacing: 10) {
            MilesBackButton()
            AddNoteButton()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

private struct MilesBackButton: View {
    var body: some View {
        Button {
            CaptureService.shared.captureMilesBack(source: .app)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.pinYellow)
                Text("+1 mi back")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .bottomButtonShape()
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 27))
        .accessibilityLabel("Save a pin one mile back. Tap again to move it further back.")
    }
}

/// Asks "What's your note?" and saves what's said as a note in Pins, with no pin or location.
/// Voice only: typing a note happens in Pins, never on this screen.
private struct AddNoteButton: View {
    var body: some View {
        Button {
            CaptureFeedback.shared.addSpokenNote()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.pinYellow)
                Text("Add a note")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .bottomButtonShape()
        }
        .buttonStyle(PressHighlightStyle(cornerRadius: 27))
        .accessibilityLabel("Add a note by voice")
        .accessibilityHint("Asks for your note, then listens")
    }
}

private extension View {
    func bottomButtonShape() -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            .contentShape(Capsule())
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

#Preview("Simple") {
    NavigationStack {
        CaptureView(mode: .quick)
    }
}

#Preview("Four zones") {
    NavigationStack {
        CaptureView(mode: .fourZone)
    }
}
