import Foundation

/// A place a review reminder can fire at, chosen in Settings. Kept on this iPhone only.
struct SavedPlace: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
}

/// When Passing reminds you to look at Needs Review. Off until turned on in Settings. Stored in the
/// App Group's settings, because the widget extension saves the pins that arm the reminders.
/// Plain values, so the rules are easy to unit test.
struct ReviewReminderSettings: Codable, Equatable {
    var isOn = false
    /// The next time it's `hour`:`minute` after a widget pin: 8:00 AM unless changed.
    var atTime = true
    var hour = 8
    var minute = 0
    /// Arriving at work, once a place is set.
    var atWork = true
    var work: SavedPlace?
    var atHome = false
    var home: SavedPlace?

    enum Trigger: Equatable {
        case time(hour: Int, minute: Int)
        case arrival(SavedPlace)
    }

    struct Planned: Equatable {
        var id: String
        var trigger: Trigger
    }

    static let timeID = "passing.review.time"
    static let workID = "passing.review.work"
    static let homeID = "passing.review.home"
    static let allIDs = [timeID, workID, homeID]

    /// The reminders to arm while pins are waiting in Needs Review. A place that hasn't been set
    /// arms nothing.
    var planned: [Planned] {
        guard isOn else { return [] }
        var result: [Planned] = []
        if atTime { result.append(Planned(id: Self.timeID, trigger: .time(hour: hour, minute: minute))) }
        if atWork, let work { result.append(Planned(id: Self.workID, trigger: .arrival(work))) }
        if atHome, let home { result.append(Planned(id: Self.homeID, trigger: .arrival(home))) }
        return result
    }

    static func message(waiting count: Int) -> String {
        count == 1
            ? "1 pin to review from your drive. Add a name or note while you're parked."
            : "\(count) pins to review from your drive. Add names or notes while you're parked."
    }

    // MARK: Storage

    static let key = "reviewReminders"

    static func load(from defaults: UserDefaults?) -> ReviewReminderSettings {
        guard let data = defaults?.data(forKey: key),
              let settings = try? JSONDecoder().decode(ReviewReminderSettings.self, from: data)
        else { return ReviewReminderSettings() }
        return settings
    }

    func save(to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}
