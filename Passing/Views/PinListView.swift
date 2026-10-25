import SwiftData
import SwiftUI

/// Review list: everything you've pinned, newest first, grouped by day.
struct PinListView: View {
    @Query(filter: #Predicate<Pin> { $0.deletedAt == nil }, sort: \Pin.capturedAt, order: .reverse)
    private var pins: [Pin]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(pinsByDay[day] ?? []) { pin in
                        NavigationLink {
                            PinDetailView(pin: pin)
                        } label: {
                            PinRow(pin: pin)
                        }
                    }
                    .onDelete { offsets in
                        let dayPins = pinsByDay[day] ?? []
                        for index in offsets {
                            context.delete(dayPins[index])
                        }
                        try? context.save()
                    }
                } header: {
                    Text(title(for: day))
                }
            }
        }
        .overlay {
            if pins.isEmpty {
                ContentUnavailableView(
                    "No pins yet",
                    systemImage: "mappin.slash",
                    description: Text("Tap the capture screen when you pass something you want to look up later.")
                )
            }
        }
        .navigationTitle("Pins")
    }

    private var pinsByDay: [Date: [Pin]] {
        Dictionary(grouping: pins) { Calendar.current.startOfDay(for: $0.capturedAt) }
    }

    private var days: [Date] {
        pinsByDay.keys.sorted(by: >)
    }

    private func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct PinRow: View {
    let pin: Pin

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(pin.displayLabel)
                    .font(.headline)
                    .foregroundStyle(pin.label?.isEmpty == false ? Color.primary : Color.secondary)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(PinFormat.accuracy(of: pin))
                    .font(.caption)
                    .foregroundStyle(pin.hasLocation ? Color.secondary : Color.orange)
            }
            Spacer(minLength: 0)
            if pin.isReviewed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Reviewed")
            }
        }
        .padding(.vertical, 2)
    }

    private var details: String {
        let time = pin.capturedAt.formatted(date: .omitted, time: .shortened)
        guard let clue = pin.sideAndDistance else { return time }
        return "\(time) · \(clue)"
    }

    private var icon: String {
        switch pin.side {
        case .left: return "arrow.up.left.circle.fill"
        case .right: return "arrow.up.right.circle.fill"
        case .unknown: return "mappin.circle.fill"
        }
    }
}

enum PinFormat {
    /// "±8 m", "±40 m · approximate", or "No location".
    static func accuracy(of pin: Pin) -> String {
        guard pin.hasLocation, let accuracy = pin.horizontalAccuracy else { return "No location" }
        let meters = "±\(Int(accuracy.rounded())) m"
        return pin.isApproximate ? "\(meters) · approximate" : meters
    }
}
