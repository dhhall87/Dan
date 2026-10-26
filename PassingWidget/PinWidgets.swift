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
                SavingAware {
                    Button(intent: WidgetPinIntent(side: .unknown, distance: .unknown)) {
                        PinButtonFace(note: entry.savedNote(side: .unknown, distance: .unknown))
                    }
                    .buttonStyle(.plain)
                }
                .invalidatableContent()
            } else {
                NotSetUpView()
            }
        }
        // CarPlay and StandBy remove this background; the yellow pin and white text still read on black.
        .containerBackground(for: .widget) {
            ZoneFill(.pin, seed: 5)
        }
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
                SavingAware {
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
                }
                .invalidatableContent()
            } else {
                NotSetUpView()
            }
        }
        .containerBackground(Color.captureBackground, for: .widget)
    }
}

private struct GridButton: View {
    let side: Side
    let distance: Distance
    let note: WidgetSavedNote?

    var body: some View {
        Button(intent: WidgetPinIntent(side: side, distance: distance)) {
            Group {
                if let note {
                    SavedFace(note: note, compact: true)
                } else {
                    Text(title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ZoneFill(far: distance == .far, seed: (side == .left ? 0 : 2) + (distance == .far ? 0 : 1)))
                }
            }
            .clipShape(ContainerRelativeShape())
        }
        .buttonStyle(.plain)
    }

    /// "← Far", "Near →": the arrow points to the side of the road.
    private var title: String {
        side == .left ? "← \(distance.title)" : "\(distance.title) →"
    }
}

// MARK: Left or right (medium)

/// A wide widget for the Home Screen and Smart Stacks, split down the middle: tap the left half for
/// the left side of the road, the right half for the right. "Passing" sits on the seam as a label
/// only (Dan's request). The two buttons cover the whole widget, edges and seam included, so no tap
/// opens the app. They save the side only; distance can be set later in Pins. CarPlay only shows
/// small widgets, so this one is for the iPhone.
struct PinSidesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PinSidesWidget", provider: PinTimelineProvider()) { entry in
            PinSidesWidgetView(entry: entry)
        }
        .configurationDisplayName("Pin Left or Right")
        .description("Tap the side of the road the thing was on. Fits in a medium Smart Stack.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct PinSidesWidgetView: View {
    let entry: PinEntry

    var body: some View {
        Group {
            if entry.isListening {
                StopListeningButton()
            } else if entry.isSetUp {
                SavingAware {
                    HStack(spacing: 0) {
                        SideButton(side: .left, note: entry.savedNote(side: .left, distance: .unknown))
                        SideButton(side: .right, note: entry.savedNote(side: .right, distance: .unknown))
                    }
                    .overlay {
                        PassingLabel()
                    }
                }
                .invalidatableContent()
            } else {
                NotSetUpView()
            }
        }
        .containerBackground(Color.captureBackground, for: .widget)
    }
}

/// One half of the widget: just an arrow pointing to that side of the road, no words. The face is
/// inset so the halves look like two buttons, but the button itself fills its whole half.
private struct SideButton: View {
    let side: Side
    let note: WidgetSavedNote?

    var body: some View {
        Button(intent: WidgetPinIntent(side: side, distance: .unknown)) {
            Group {
                if let note {
                    SavedFace(note: note, compact: false)
                } else {
                    Image(systemName: side == .left ? "arrow.up.left" : "arrow.up.right")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ZoneFill(.pin, seed: side == .left ? 6 : 7))
                }
            }
            .clipShape(ContainerRelativeShape())
            .padding(.vertical, 6)
            .padding(.leading, side == .left ? 6 : 3)
            .padding(.trailing, side == .left ? 3 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(side == .left ? "Save pin, left side" : "Save pin, right side")
    }
}

/// "Passing" on the seam between the halves. Only a label: taps go through it to the half underneath.
private struct PassingLabel: View {
    var body: some View {
        Text("Passing")
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(Color.pinYellow)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.asphalt, in: Capsule())
            // A ring in the background color, so the label looks set into the gap between the halves.
            .overlay(Capsule().strokeBorder(Color.captureBackground, lineWidth: 3))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: Tap feedback

/// Widget feedback colors. White text reads on both.
private extension Color {
    /// Saving, and saved with a location.
    static let savedGreen = Color(red: 0.12, green: 0.50, blue: 0.26)
    /// Saved, but no GPS reading arrived in time.
    static let noLocationAmber = Color(red: 0.62, green: 0.38, blue: 0.02)
    /// Not saved: the pin couldn't be written, so tap again.
    static let notSavedRed = Color(red: 0.70, green: 0.12, blue: 0.12)
}

private extension WidgetSavedNote {
    var symbol: String {
        if !saved { return "xmark" }
        return hasLocation ? "checkmark" : "location.slash"
    }

    var color: Color {
        if !saved { return .notSavedRed }
        return hasLocation ? .savedGreen : .noLocationAmber
    }
}

/// The pin is saved the moment a button is tapped, but WidgetKit only redraws the widget once the
/// button's work is done, which includes waiting up to 15 seconds for a GPS reading. WidgetKit marks
/// the content `.invalidated` for that time, so this swaps in a green "Saving…" across the whole
/// widget straight away. (It can't tell which button was tapped until the redraw.) After the redraw,
/// the tapped button shows `SavedFace` for 5 seconds.
private struct SavingAware<Content: View>: View {
    @Environment(\.redactionReasons) private var redactionReasons
    @ViewBuilder let content: () -> Content

    var body: some View {
        if redactionReasons.contains(.invalidated) {
            VStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                Text("Saving…")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.savedGreen)
        } else {
            content()
        }
    }
}

/// A button after its save: green with a tick and "Saved", amber with "No location", or red with
/// "Not saved" if the pin couldn't be written.
private struct SavedFace: View {
    let note: WidgetSavedNote
    /// Smaller type for the grid's quarter-size buttons.
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 2 : 6) {
            Image(systemName: note.symbol)
                .font(compact ? .title2.weight(.heavy) : .system(size: 40, weight: .bold))
            Text(note.shortMessage)
                .font(compact ? .caption2.weight(.bold) : .system(.headline, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(note.color)
    }
}

/// The single Pin button: the app icon's pin with "Pin", or `SavedFace` for 5 seconds after a save.
private struct PinButtonFace: View {
    let note: WidgetSavedNote?

    var body: some View {
        Group {
            if let note {
                SavedFace(note: note, compact: false)
            } else {
                VStack(spacing: 8) {
                    // The app icon's pin, as on the phone's Simple screen.
                    PinGlyph()
                        .frame(width: 56, height: 56)
                    Text("Pin")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .contentShape(Rectangle())
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
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .unknown, distance: .unknown, hasLocation: true, saved: false))
}

#Preview("Pin Left or Right", as: .systemMedium) {
    PinSidesWidget()
} timeline: {
    PinEntry(date: .now)
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .left, distance: .unknown, hasLocation: true))
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .right, distance: .unknown, hasLocation: false))
}

#Preview("Saving (just tapped)") {
    SavingAware { Text("Pin") }
        .redacted(reason: .invalidated)
        .frame(width: 170, height: 170)
}

#Preview("Pin by Side", as: .systemSmall) {
    PinGridWidget()
} timeline: {
    PinEntry(date: .now)
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .left, distance: .far, hasLocation: false))
    PinEntry(date: .now, isListening: true)
}
