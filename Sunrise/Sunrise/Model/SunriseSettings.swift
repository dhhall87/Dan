import Foundation

enum WakeMode: String, Codable, CaseIterable, Identifiable {
    /// The lights reach full brightness at a time Dan picks.
    case fixedTime
    /// The lights reach full brightness at the local sunrise, worked out each day by the home hub.
    case sunrise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedTime: "At a set time"
        case .sunrise: "At sunrise"
        }
    }
}

/// Everything Dan sets on the main screen. Saved in UserDefaults as JSON.
struct SunriseSettings: Codable, Equatable {
    static let defaultsKey = "sunriseSettings"

    var mode: WakeMode = .fixedTime
    var wakeHour = 7
    var wakeMinute = 0
    var durationMinutes = 30
    /// Percent, at the wake time.
    var finalBrightness = 75
    /// Amber → gold → white when on; brightness only when off (keeps Adaptive Lighting's colors).
    var usesColor = true
    /// The white the sunrise ends on.
    var finalKelvin = 4000
    var days: Set<Weekday> = Weekday.everyDay
    var homeID: UUID?
    /// HomeKit accessory identifiers.
    var lightIDs: Set<UUID> = []

    static let brightnessRange = 10...100
    static let kelvinRange = 2700...6500

    init() {}

    // Written out so settings saved by an older version still load after a field is added.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SunriseSettings()
        mode = try values.decodeIfPresent(WakeMode.self, forKey: .mode) ?? defaults.mode
        wakeHour = try values.decodeIfPresent(Int.self, forKey: .wakeHour) ?? defaults.wakeHour
        wakeMinute = try values.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? defaults.wakeMinute
        durationMinutes = try values.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? defaults.durationMinutes
        finalBrightness = try values.decodeIfPresent(Int.self, forKey: .finalBrightness) ?? defaults.finalBrightness
        usesColor = try values.decodeIfPresent(Bool.self, forKey: .usesColor) ?? defaults.usesColor
        finalKelvin = try values.decodeIfPresent(Int.self, forKey: .finalKelvin) ?? defaults.finalKelvin
        days = try values.decodeIfPresent(Set<Weekday>.self, forKey: .days) ?? defaults.days
        homeID = try values.decodeIfPresent(UUID.self, forKey: .homeID)
        lightIDs = try values.decodeIfPresent(Set<UUID>.self, forKey: .lightIDs) ?? defaults.lightIDs
    }

    /// The final color for the curve, or nil for brightness only.
    var curveKelvin: Int? { usesColor ? finalKelvin : nil }

    /// Only what changes the scenes and automations in Home, so switching modes back and forth
    /// (or moving the wake time while in sunrise mode) doesn't count as an unsaved change.
    var homeShape: SunriseSettings {
        var shape = self
        if mode == .sunrise {
            shape.wakeHour = 0
            shape.wakeMinute = 0
        }
        if !usesColor { shape.finalKelvin = 0 }
        return shape
    }

    /// The scenes and automations the home hub runs, in order: the prep step, then the sunrise.
    var steps: [SunriseStep] {
        let offsets = SunriseCurve.offsets(durationMinutes: durationMinutes)
        let levels = SunriseCurve.levels(durationMinutes: durationMinutes, finalBrightness: finalBrightness, finalKelvin: curveKelvin)
        guard let first = levels.first else { return [] }
        let prep = SunriseStep(number: 0, offsetMinutes: SunriseCurve.prepOffset(durationMinutes: durationMinutes), level: first, turnsOn: false)
        let sunrise = zip(offsets, levels).enumerated().map { index, step in
            SunriseStep(number: index + 1, offsetMinutes: step.0, level: step.1, turnsOn: true)
        }
        return [prep] + sunrise
    }

    static func load(from defaults: UserDefaults = .standard) -> SunriseSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(SunriseSettings.self, from: data)
        else { return SunriseSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}

/// One scene plus its automation in Apple's Home.
struct SunriseStep: Equatable {
    /// 0 is the prep step.
    var number: Int
    /// Minutes from the wake time; negative is before it.
    var offsetMinutes: Int
    var level: SunriseLevel
    /// False only for the prep step, which sets the level without turning the lights on.
    var turnsOn: Bool

    /// "Sunrise App Step 00" … Every scene and automation Sunrise makes is named this way, so it
    /// can find and replace them even if its own record of them is lost (after a reinstall).
    var name: String { SunriseStep.namePrefix + String(format: "%02d", number) }

    static let namePrefix = "Sunrise App Step "
}

/// What Sunrise last wrote into Home, so it can switch it on and off, check it, and replace it.
struct HomeInstall: Codable, Equatable {
    static let defaultsKey = "homeInstall"

    var homeID: UUID
    var triggerIDs: [UUID]
    var actionSetIDs: [UUID]
    var settings: SunriseSettings
    var savedAt: Date

    static func load(from defaults: UserDefaults = .standard) -> HomeInstall? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(HomeInstall.self, from: data)
    }

    static func save(_ install: HomeInstall?, to defaults: UserDefaults = .standard) {
        guard let install, let data = try? JSONEncoder().encode(install) else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        defaults.set(data, forKey: defaultsKey)
    }
}

/// Where Dan is, rounded to about a kilometer, for showing sunrise times. Kept apart from
/// `SunriseSettings` because the home hub uses the home's own location, so it never changes Home.
struct SavedPlace: Codable, Equatable {
    static let defaultsKey = "savedPlace"

    var latitude: Double
    var longitude: Double

    /// Rounds to two decimal places (about 1 km), which moves sunrise by a few seconds at most.
    init(latitude: Double, longitude: Double) {
        self.latitude = (latitude * 100).rounded() / 100
        self.longitude = (longitude * 100).rounded() / 100
    }

    static func load(from defaults: UserDefaults = .standard) -> SavedPlace? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SavedPlace.self, from: data)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
