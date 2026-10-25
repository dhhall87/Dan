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

    /// The tick for the button that saves `side` and `distance`, if that's the one just tapped.
    func savedNote(side: Side, distance: Distance) -> WidgetSavedNote? {
        guard let note = self.note, note.matches(side: side, distance: distance) else { return nil }
        return note
    }
}

/// The buttons never change, apart from the tick after a tap, so there are no scheduled refreshes.
/// WidgetKit reloads the widget by itself after every button tap.
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
        var entries = [PinEntry(date: now, isSetUp: isSetUp)]
        if let note = WidgetActivity.lastNote, note.isShowing(at: now) {
            // Show the tick now, and go back to the plain buttons when it expires.
            entries = [
                PinEntry(date: now, note: note, isSetUp: isSetUp),
                PinEntry(date: note.hidesAt, isSetUp: isSetUp),
            ]
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
            if entry.isSetUp {
                Button(intent: WidgetPinIntent(side: .unknown, distance: .unknown)) {
                    let note = entry.savedNote(side: .unknown, distance: .unknown)
                    VStack(spacing: 8) {
                        Image(systemName: note == nil ? "mappin.and.ellipse" : "checkmark")
                            .font(.system(size: 48, weight: .bold))
                        Text(note?.shortMessage ?? "Pin")
                            .font(.title2.weight(.heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                NotSetUpView()
            }
        }
        // CarPlay and StandBy remove this background; the white symbol still reads on black.
        .containerBackground(Color.quickSurface, for: .widget)
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
            if entry.isSetUp {
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
        .containerBackground(Color.black, for: .widget)
    }
}

private struct GridButton: View {
    let side: Side
    let distance: Distance
    let note: WidgetSavedNote?

    var body: some View {
        Button(intent: WidgetPinIntent(side: side, distance: distance)) {
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
            .background(distance == .far ? Color.farZone : Color.nearZone, in: ContainerRelativeShape())
        }
        .buttonStyle(.plain)
    }

    /// "← Far", "Near →": the arrow points to the side of the road.
    private var title: String {
        side == .left ? "← \(distance.title)" : "\(distance.title) →"
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

#Preview("Pin by Side", as: .systemSmall) {
    PinGridWidget()
} timeline: {
    PinEntry(date: .now)
    PinEntry(date: .now, note: WidgetSavedNote(savedAt: .now, side: .left, distance: .far, hasLocation: false))
}
