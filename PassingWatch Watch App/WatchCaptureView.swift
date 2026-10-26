import SwiftUI

/// The watch's one screen: four buttons laid out like the 2x2 widget (the columns are the sides of
/// the road or path, far on top, near below, in the phone's colors), and the pin in the middle for a
/// pin with no side, which double tap also presses. Save first, with a wrist tap; nothing asks
/// anything, and nothing moves after a tap.
struct WatchCaptureView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let capture = WatchCapture.shared
    /// The button that just saved, ticked for a moment.
    @State private var tick: WatchCapture.Tap?

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                WatchStatusLine(location: capture.location, waiting: capture.outbox.count, now: context.date)
            }
            ZStack {
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        zone(side: .left, distance: .far)
                        zone(side: .right, distance: .far)
                    }
                    GridRow {
                        zone(side: .left, distance: .near)
                        zone(side: .right, distance: .near)
                    }
                }
                CenterPinButton(tick: shownTick(side: .unknown, distance: .unknown)) {
                    capture.capture(side: .unknown, distance: .unknown)
                }
            }
        }
        .background(Color.captureBackground)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: capture.becameActive()
            case .background: capture.wentToBackground()
            default: capture.becameInactive()
            }
        }
        .onChange(of: capture.lastTap) {
            tick = capture.lastTap
        }
        .task(id: tick) {
            guard tick != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            tick = nil
        }
    }

    private func zone(side: Side, distance: Distance) -> some View {
        ZoneButton(side: side, distance: distance, tick: shownTick(side: side, distance: distance)) {
            capture.capture(side: side, distance: distance)
        }
    }

    private func shownTick(side: Side, distance: Distance) -> WatchCapture.Tap? {
        guard let tick, tick.side == side, tick.distance == distance else { return nil }
        return tick
    }
}

/// One side-and-distance button. Its arrow points to the side; near and far use the phone's two colors.
private struct ZoneButton: View {
    let side: Side
    let distance: Distance
    let tick: WatchCapture.Tap?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let tick {
                    TickFace(saved: tick.saved)
                } else {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ZoneFill(far: distance == .far, seed: (side == .left ? 0 : 2) + (distance == .far ? 0 : 1)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(side.title), \(distance.title.lowercased())")
    }

    /// "← Far", "Near →", as on the 2x2 widget.
    private var title: String {
        side == .left ? "← \(distance.title)" : "\(distance.title) →"
    }
}

/// The app icon's pin, between the four buttons: a pin with no side or distance. Double tap (pinch
/// twice with the watch hand) presses it, so a pin needs no tap at all.
private struct CenterPinButton: View {
    let tick: WatchCapture.Tap?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tick.map { $0.saved ? Color.savedGreen : Color.notSavedRed } ?? Color.quickSurface)
                if let tick {
                    Image(systemName: tick.saved ? "checkmark" : "xmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    PinGlyph()
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 46, height: 46)
            .overlay(Circle().stroke(Color.captureBackground, lineWidth: 4))
        }
        .buttonStyle(.plain)
        .handGestureShortcut(.primaryAction)
        .accessibilityLabel("Pin, no side")
    }
}

/// Saved on the watch (green tick), or not (red cross: tap again). "Saved" means on the watch; the
/// status line counts pins still on their way to the iPhone.
private struct TickFace: View {
    let saved: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: saved ? "checkmark" : "xmark")
                .font(.title3.weight(.heavy))
            Text(saved ? "Saved" : "Not saved")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(saved ? Color.savedGreen : Color.notSavedRed)
    }
}

/// One small line above the buttons: whether a tap now gets a position, and how many pins the
/// iPhone doesn't have yet. A standing notice, never a reaction to a tap.
private struct WatchStatusLine: View {
    let location: WatchLocation
    let waiting: Int
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gpsReady ? Color.savedGreen : Color.noLocationAmber)
                .frame(width: 6, height: 6)
            Text(gpsText)
            if waiting > 0 {
                Text("· \(waiting) to send")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var gpsReady: Bool {
        location.freshFix(now: now) != nil
    }

    private var gpsText: String {
        if location.isDenied { return "Location off" }
        if location.isPreciseLocationOff { return "Precise Location off" }
        if !location.isAuthorized { return "Location not allowed yet" }
        return gpsReady ? "GPS ready" : "Finding GPS…"
    }
}

#Preview {
    WatchCaptureView()
}
