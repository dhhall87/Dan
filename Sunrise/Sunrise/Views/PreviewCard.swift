import SwiftUI

/// What the sunrise will look like and when it runs next.
struct PreviewCard: View {
    @Environment(SunriseModel.self) private var model

    var body: some View {
        let settings = model.settings
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your sunrise")
                    .font(.headline)
                Spacer()
                Text("\(settings.durationMinutes) min")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            SunriseStrip(levels: settings.steps.dropFirst().map(\.level))
            Text(colorSummary(settings))
                .font(.subheadline)
            TimelineView(.everyMinute) { context in
                NextSunriseText(settings: settings, place: model.location.place, now: context.date)
            }
        }
        .card()
    }

    private func colorSummary(_ settings: SunriseSettings) -> String {
        guard settings.usesColor else { return "Very dim → \(settings.finalBrightness)% brightness" }
        return "Very dim amber → warm gold → \(SunriseCurve.colorName(kelvin: settings.finalKelvin))"
    }
}

private struct NextSunriseText: View {
    let settings: SunriseSettings
    let place: SavedPlace?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timesLine)
                .font(.subheadline)
            Text(nextLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var calendar: Calendar { .current }

    private var nextWake: Date? {
        SunriseSchedule.nextWake(after: now, settings: settings, place: place, calendar: calendar)
    }

    private var timesLine: String {
        let brightness = "\(settings.finalBrightness)%"
        switch settings.mode {
        case .fixedTime:
            guard let wake = SunriseSchedule.wakeTime(on: now, settings: settings, place: nil, calendar: calendar) else { return "" }
            let start = SunriseSchedule.start(forWake: wake, durationMinutes: settings.durationMinutes)
            return "Starts \(Self.time(start)) · \(brightness) at \(Self.time(wake))"
        case .sunrise:
            guard let wake = nextWake else { return "Reaches \(brightness) at sunrise" }
            let start = SunriseSchedule.start(forWake: wake, durationMinutes: settings.durationMinutes)
            return "Starts about \(Self.time(start)) · \(brightness) at sunrise, about \(Self.time(wake))"
        }
    }

    private var nextLine: String {
        let days = settings.days.summary(in: calendar)
        if settings.mode == .sunrise, place == nil {
            return "\(days). Your home hub works out sunrise from your home's location."
        }
        guard let wake = nextWake else { return days }
        return "\(days) · Next: \(Self.dayName(wake, now: now, calendar: calendar))"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dayName(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.wide))
    }
}
