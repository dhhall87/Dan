import AppIntents
import SwiftUI
import WidgetKit

// MARK: Timeline

struct PinEntry: TimelineEntry {
    let date: Date
    /// The "Saved" tick, shown for a few seconds after a tap.
    var note: WidgetSavedNote?
    /// False when the widget can't reach the shared pin store, so its pins wouldn't show in the app.
    var isSetUp = true
    /// True while the app is listening for a label after a tap: the buttons become one Stop button.
    var isListening = false

    /// The tick for the button that saves `side` and `distance`, if that's the one just tapped.
    func savedNote(side: Side, distance: Distance) -> WidgetSavedNote? {
        guard let note = self.note, note.matches(side: side, distance: distance) else { return nil }
        return note
    }
}

/// The buttons only change for the tick after a tap and while the app is listening, so there are
/// no scheduled refreshes. WidgetKit reloads the widget after every button tap, and the app reloads
/// it when listening starts and stops.
struct PinTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinEntry {
        PinEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PinEntry) -> Void) {
        completion(PinEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinEntry>) -> Void) {
        let now = Date.now
        let isSetUp = AppGroup.isAvailable
        let note = WidgetActivity.lastNote.flatMap { $0.isShowing(at: now) ? $0 : nil }
        let listeningUntil = ListeningSignal.listeningUntil(now: now)
        // An entry for now, and one for each moment the tick or the Stop button runs out.
        let changes = Set([now, note?.hidesAt, listeningUntil].compactMap { $0 }).sorted()
        let entries = changes.map { date in
            PinEntry(
                date: date,
                note: note.flatMap { $0.isShowing(at: date) ? $0 : nil },
                isSetUp: isSetUp,
                isListening: listeningUntil.map { date < $0 } ?? false
            )
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

// MARK: Single button

/// The whole widget is one button: tap to pin. Small, so it can go in CarPlay and StandBy.
struct PinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PinWidget", provider: PinTimelineProvider()) { entry in
            PinWidgetView(entry: entry)
        }
        .configurationDisplayName("Pin")
        .description("One tap saves where you are. Works in CarPlay.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct PinWidgetView: View {
    let entry: PinEntry

    var body: some View {
        Group {
            if entry.isListening {
                StopListeningButton()
            } else if entry.isSetUp {
                Button(intent: WidgetPinIntent(side: .unknown, distance: .unknown)) {
                    PinButtonFace(note: entry.savedNote(side: .unknown, distance: .unknown))
                        // Greyed "Saving…" from the tap until the save (and its GPS wait) finishes.
                        .invalidatableContent()
                }
                .buttonStyle(.plain)
            } else {
                NotSetUpView()
            }
        }
        // CarPlay and StandBy remove this background; the yellow pin and white text still read on black.
        .containerBackground(Color.quickSurface.softGradient, for: .widget)
    }
}

// MARK: Side and distance grid

/// Four buttons. The columns are the sides of the road, as on the phone; the top row is far and
/// the bottom row near, like looking up the road. Near and far use the phone's two colors.
struct PinGridWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PinGridWidget", provider: PinTimelineProvider()) { entry in
            PinGridWidgetView(entry: entry)
        }
        .configurationDisplayName("Pin by Side")
        .description("Tap the side of the road and how far away. Works in CarPlay.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct PinGridWidgetView: View {
    let entry: PinEntry

    var body: some View {
        Group {
            if entry.isListening {
                StopListeningButton()
            } else if entry.isSetUp {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        GridButton(side: .left, distance: .far, note: entry.savedNote(side: .left, distance: .far))
                        GridButton(side: .right, distance: .far, note: entry.savedNote(side: .right, distance: .far))
                    }
                    HStack(spacing: 4) {
                        GridButton(side: .left, distance: .near, note: entry.savedNote(side: .left, distance: .near))
                        GridButton(side: .right, distance: .near, note: entry.savedNote(side: .right, distance: .near))
                    }
                }
                .padding(4)
            } else {
                NotSetUpView()
            }
        }
        .containerBackground(Color.captureBackground, for: .widget)
    }
}

/// The single Pin button's face. The pin is saved the moment it's tapped, but WidgetKit only redraws
/// the widget once the button's work is done, which includes waiting up to 15 seconds for a GPS
/// reading. So from the tap until then it shows a greyed "Saving…" (WidgetKit marks the content
/// `.invalidated` for that time), then a tick with "Saved" or "No location" for 5 seconds.
private struct PinButtonFace: View {
    let note: WidgetSavedNote?
    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        let isSaving = redactionReasons.contains(.invalidated)
        VStack(spacing: 8) {
            if isSaving || note != nil {
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
            } else {
                // The app icon's pin, as on the phone's Simple screen.
                PinGlyph()
                    .frame(width: 56, height: 56)
            }
            Text(isSaving ? "Saving…" : note?.shortMessage ?? "Pin")
                .font(.system(.title2, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(.white.opacity(isSaving ? 0.5 : 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

private struct GridButton: View {
    let side: Side
    let distance: Distance
    let note: WidgetSavedNote?

    var body: some View {
        Button(intent: WidgetPinIntent(side: side, distance: distance)) {
            GridButtonFace(side: side, distance: distance, note: note)
                // Greyed from the tap until the save finishes, then the tapped button shows a tick.
                .invalidatableContent()
        }
        .buttonStyle(.plain)
    }
}

/// One grid button's face. WidgetKit doesn't say which button was tapped while it waits, so all four
/// grey out together; once the save finishes, the tapped one shows the tick for 5 seconds.
private struct GridButtonFace: View {
    let side: Side
    let distance: Distance
    let note: WidgetSavedNote?
    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        let isSaving = redactionReasons.contains(.invalidated)
        VStack(spacing: 2) {
            if let note {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.heavy))
                Text(note.shortMessage)
                    .font(.caption2.weight(.bold))
            } else {
                Text(title)
                    .font(.headline.weight(.heavy))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZoneFill(far: distance == .far, seed: (side == .left ? 0 : 2) + (distance == .far ? 0 : 1)).clipShape(ContainerRelativeShape()))
        .opacity(isSaving ? 0.45 : 1)
    }

    /// "← Far", "Near →": the arrow points to the side of the road.
    private var title: String {
        side == .left ? "← \(distance.title)" : "\(distance.title) →"
    }
}

// MARK: Stop listening

/// While the app is listening for a label after a tap, the widget's buttons become one big Stop
/// button, so the microphone can be turned off from CarPlay without waiting for it to time out.
private struct StopListeningButton: View {
    var body: some View {
        Button(intent: StopListeningIntent()) {
            VStack(spacing: 8) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 40, weight: .bold))
                Text("Stop listening")
                    .font(.headline.weight(.heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.red.opacity(0.85), in: ContainerRelativeShape())
        }
        .buttonStyle(.plain)
        .padding(4)
    }
}

// MARK: Not set up

/// Shown instead of the buttons when the widget can't reach the shared store, because pins saved
/// here would never show up in the app.
private struct NotSetUpView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("Not set up")
                .font(.headline)
            Text("The widget can't reach Passing's pins. Check the App Group.")
                .font(.caption2)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(10)
    }
}

// MARK: Previews

#Preview("Pin", as: .systemSmall) {
    PinWidget()
} timeline: {
    PinEntry(date: .now)
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .unknown, distance: .unknown, hasLocation: true))
}

#Preview("Saving (just tapped)") {
    PinButtonFace(note: nil)
        .redacted(reason: .invalidated)
        .frame(width: 170, height: 170)
        .background(Color.quickSurface.softGradient)
}

#Preview("Pin by Side", as: .systemSmall) {
    PinGridWidget()
} timeline: {
    PinEntry(date: .now)
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .left, distance: .far, hasLocation: false))
    PinEntry(date: .now, isListening: true)
}
