import SwiftUI
import WidgetKit

/// The watch face complication, also offered in the Smart Stack: the app icon's pin. A tap opens
/// Passing on the watch, ready to pin. It never changes, so it has one entry and never reloads.
@main
struct PassingComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PassingComplication", provider: ComplicationProvider()) { _ in
            ComplicationView()
        }
        .configurationDisplayName("Passing")
        .description("Opens Passing, ready to pin what you pass.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [ComplicationEntry(date: .now)], policy: .never))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                Color.quickSurface
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCorner:
            PinGlyph()
                .padding(2)
                .widgetLabel("Passing")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                PinGlyph()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Passing")
                        .font(.headline)
                        .widgetAccentable()
                    Text("Tap to pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Label("Passing", systemImage: "mappin")
        default:
            ZStack {
                AccessoryWidgetBackground()
                PinGlyph()
                    .padding(9)
            }
        }
    }
}
