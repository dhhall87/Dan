import Foundation

/// A time of day for a step at a set wake time, and whether it falls on the day before.
struct ClockTime: Equatable {
    var hour: Int
    var minute: Int
    /// -1 when the step is before midnight and the wake time after it.
    var dayShift: Int
}

/// When things happen, as HomeKit needs it and as the main screen shows it.
enum SunriseSchedule {
    static func clockTime(hour: Int, minute: Int, offsetMinutes: Int) -> ClockTime {
        let total = hour * 60 + minute + offsetMinutes
        let dayShift = Int((Double(total) / 1440).rounded(.down))
        let minuteOfDay = total - dayShift * 1440
        return ClockTime(hour: minuteOfDay / 60, minute: minuteOfDay % 60, dayShift: dayShift)
    }

    /// An offset from sunrise for `HMSignificantTimeEvent`, split into hours and minutes
    /// (both negative before sunrise), or nil at sunrise itself.
    static func sunriseOffset(minutes: Int) -> DateComponents? {
        guard minutes != 0 else { return nil }
        var offset = DateComponents()
        if minutes / 60 != 0 { offset.hour = minutes / 60 }
        offset.minute = minutes % 60
        return offset
    }

    /// HomeKit recurrences (weekday only), moved a day earlier for steps that fall before midnight.
    static func recurrences(days: Set<Weekday>, dayShift: Int) -> [DateComponents] {
        days.shifted(by: dayShift).sorted().map { DateComponents(weekday: $0.rawValue) }
    }

    /// The next wake time after `now` on one of the chosen days: the set time, or sunrise where
    /// `place` is. Nil in sunrise mode without a place, or if the sun doesn't rise all week.
    static func nextWake(after now: Date, settings: SunriseSettings, place: SavedPlace?, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)),
                  settings.days.contains(weekday),
                  let wake = wakeTime(on: day, settings: settings, place: place, calendar: calendar),
                  wake > now
            else { continue }
            return wake
        }
        return nil
    }

    /// The wake time on the day that contains `day`.
    static func wakeTime(on day: Date, settings: SunriseSettings, place: SavedPlace?, calendar: Calendar) -> Date? {
        switch settings.mode {
        case .fixedTime:
            return calendar.date(bySettingHour: settings.wakeHour, minute: settings.wakeMinute, second: 0, of: day)
        case .sunrise:
            guard let place else { return nil }
            return SolarCalculator.sunrise(on: day, latitude: place.latitude, longitude: place.longitude, calendar: calendar)
        }
    }

    /// When the lights start to come on for a wake time: the first sunrise step, not the prep step.
    static func start(forWake wake: Date, durationMinutes: Int) -> Date {
        wake.addingTimeInterval(TimeInterval(-max(durationMinutes, 1) * 60))
    }
}
