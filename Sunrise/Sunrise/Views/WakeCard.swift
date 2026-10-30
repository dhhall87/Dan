import SwiftUI

/// When to wake: a set time or the sunrise, and on which days.
struct WakeCard: View {
    @Binding var settings: SunriseSettings
    let place: SavedPlace?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wake up")
                .font(.headline)
            Picker("Wake up", selection: $settings.mode) {
                ForEach(WakeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            switch settings.mode {
            case .fixedTime:
                DatePicker("Lights full at", selection: wakeTime, displayedComponents: .hourAndMinute)
            case .sunrise:
                SunriseModeNote(place: place)
            }
            DayPicker(days: $settings.days)
        }
        .card()
    }

    /// The wake time as a `Date` today, for the time picker.
    private var wakeTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: settings.wakeHour, minute: settings.wakeMinute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.wakeHour = parts.hour ?? settings.wakeHour
                settings.wakeMinute = parts.minute ?? settings.wakeMinute
            }
        )
    }
}

private struct SunriseModeNote: View {
    let place: SavedPlace?
    @Environment(SunriseModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The lights reach full brightness at sunrise, which your home hub works out each day from your home's location.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if place == nil {
                Button(model.location.isLocating ? "Finding sunrise times…" : "Show sunrise times here") {
                    model.location.locate()
                }
                .font(.footnote.weight(.semibold))
                .disabled(model.location.isLocating)
            }
            if let problem = model.location.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// Seven day buttons in the order the calendar shows them. At least one day stays on.
private struct DayPicker: View {
    @Binding var days: Set<Weekday>

    var body: some View {
        let calendar = Calendar.current
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Repeat")
                Spacer()
                Text(days.summary(in: calendar))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            HStack(spacing: 6) {
                ForEach(Weekday.ordered(for: calendar)) { day in
                    DayButton(title: day.shortName(in: calendar), isOn: days.contains(day)) {
                        toggle(day)
                    }
                }
            }
        }
    }

    private func toggle(_ day: Weekday) {
        if days.contains(day) {
            guard days.count > 1 else { return }
            days.remove(day)
        } else {
            days.insert(day)
        }
    }
}

private struct DayButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 36)
                .foregroundStyle(isOn ? Color.black : Color.primary)
                .background(
                    Capsule().fill(isOn ? Color.accentColor : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
