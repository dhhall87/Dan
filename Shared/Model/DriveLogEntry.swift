import Foundation

/// One line of the drive log: something Passing did that's worth checking after a real drive, like
/// how long a widget pin waited for GPS or how long GPS ran. It never holds a location, a label, a
/// note or a speed. Plain values, so the summary and the text are easy to unit test.
struct DriveLogEntry: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        /// A pin saved (any source). `fixAge` is set when a fix was stamped at the tap. For Apple Watch
        /// pins, `seconds` is how long after the tap the pin reached the iPhone.
        case capture
        /// "+1 mi back" on the capture screen: `outcome` is how the pin just dropped was placed
        /// (breadcrumb or textOnly), or noPin when there was none to move; `seconds` is how long after
        /// that pin was dropped.
        case bump
        /// A pin saved before any fix: what happened next (`outcome` attached, none, tooLate, pinChanged).
        case lateFix
        /// A Siri, Shortcuts, widget or Control Center request finished. `outcome` is how Siri's
        /// "What did you see?" went.
        case intent
        /// GPS turned off: how long it ran (`outcome` screen or burst) and how many readings came.
        case gps
        /// A wait for GPS skipped because no fix could come (`outcome` denied or preciseOff).
        case noGPS
        /// The miles-back trail started again (`outcome` gap, jump or longBreak).
        case trailRestart
        /// Listen after tap (or a spoken note) finished: `outcome` heard, nothing, stopped, or
        /// replaced (a newer tap took over); `seconds` from that listen's own start.
        case listen
        /// The pin database opened (`outcome` shared, appOnly or unavailable).
        case storeOpened
        /// A save to the pin database failed. `outcome` is the error's type.
        case saveFailed
        /// Expiry and Recently Deleted clean-up that changed something or took a while.
        case cleanUp
        /// One town-name request to Apple Maps (`outcome` found, noName or failed).
        case townLookup
        /// Passing opened from scratch: `seconds` until it was on screen and active, and `outcome`
        /// the version running, so a log that spans an update shows which drives used which.
        case opened
    }

    var at: Date
    var kind: Kind
    /// "app" or "widget": which process wrote it. Filled in by `DriveLog`.
    var process: String = ""
    /// `CaptureSource` raw value, for pins and requests.
    var source: String?
    var outcome: String?
    /// A wait or a duration; what it measures depends on `kind` (see `secondsName`).
    var seconds: Double?
    /// When the GPS reading was taken, relative to the tap (negative: before it).
    var fixAge: Double?
    /// The reading's accuracy, in meters.
    var accuracy: Double?
    var approximate: Bool?
    var saved: Bool?
    /// "Miles back" for that pin.
    var miles: Double?
    /// How much trail there was (miles), for miles-back pins and trail restarts.
    var trailMiles: Double?
    /// How far apart the two readings around a trail gap were, in meters.
    var meters: Double?
    var count: Int?

    /// What `seconds` means for this kind, in the exported text.
    var secondsName: String {
        switch kind {
        case .lateFix: return "waited"
        case .intent, .storeOpened, .cleanUp, .townLookup, .listen: return "took"
        case .gps: return "ran"
        case .trailRestart: return "gap"
        case .opened: return "ready"
        case .capture: return "arrived"
        case .bump: return "afterPin"
        case .noGPS, .saveFailed: return "seconds"
        }
    }

    /// What `count` means for this kind.
    var countName: String {
        switch kind {
        case .gps: return "readings"
        case .storeOpened: return "tries"
        case .cleanUp: return "changed"
        default: return "count"
        }
    }

    /// One readable line: "2026-10-27 08:14:03  widget  lateFix  source=widget outcome=attached waited=2.3s …".
    func line(timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var fields: [String] = []
        if let source { fields.append("source=\(source)") }
        if let outcome { fields.append("outcome=\(outcome)") }
        if let seconds { fields.append("\(secondsName)=\(DriveLogFormat.duration(seconds))") }
        if let fixAge { fields.append("fixAge=\(fixAge >= 0 ? "+" : "")\(DriveLogFormat.decimal(fixAge))s") }
        if let accuracy { fields.append("accuracy=\(Int(accuracy.rounded()))m") }
        if let approximate { fields.append("approximate=\(approximate ? "yes" : "no")") }
        if let saved { fields.append("saved=\(saved ? "yes" : "no")") }
        if let miles { fields.append("miles=\(DriveLogFormat.decimal(miles))") }
        if let trailMiles { fields.append("trail=\(DriveLogFormat.decimal(trailMiles))mi") }
        if let meters { fields.append("apart=\(Int(meters.rounded()))m") }
        if let count { fields.append("\(countName)=\(count)") }
        return "\(formatter.string(from: at))  \(process)  \(kind.rawValue)  \(fields.joined(separator: " "))"
    }
}

enum DriveLogFormat {
    /// One decimal place, without a trailing ".0" for whole numbers.
    static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
    }

    /// "2.3s" under a minute, "12m 03s" under an hour, "1h 12m" beyond.
    static func duration(_ seconds: Double) -> String {
        // Hundredths under a second, so a near-instant GPS reading shows as "0.04s", not "0s".
        if seconds < 1 { return String(format: "%.2fs", max(seconds, 0)) }
        if seconds < 60 { return "\(decimal(seconds))s" }
        let whole = Int(seconds.rounded())
        if whole < 3600 { return String(format: "%dm %02ds", whole / 60, whole % 60) }
        return String(format: "%dh %02dm", whole / 3600, (whole % 3600) / 60)
    }

    /// "1 time", "3 times".
    static func times(_ count: Int) -> String {
        count == 1 ? "1 time" : "\(count) times"
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

/// The few numbers that answer "how did it do on real drives?", worked out from the log.
enum DriveLogSummary {
    static func lines(for entries: [DriveLogEntry], timeZone: TimeZone = .current) -> [String] {
        guard let first = entries.first?.at, let last = entries.last?.at else {
            return ["Nothing logged yet."]
        }
        var lines: [String] = []
        let days = DateFormatter()
        days.locale = Locale(identifier: "en_US_POSIX")
        days.timeZone = timeZone
        days.dateFormat = "MMM d"
        lines.append("\(entries.count) events, \(days.string(from: first)) to \(days.string(from: last))")

        func of(_ kind: DriveLogEntry.Kind) -> [DriveLogEntry] { entries.filter { $0.kind == kind } }
        func spread(_ values: [Double]) -> String {
            guard let median = DriveLogFormat.median(values), let slowest = values.max() else { return "" }
            return "median \(DriveLogFormat.duration(median)), slowest \(DriveLogFormat.duration(slowest))"
        }
        func bySource(_ list: [DriveLogEntry]) -> [(String, [DriveLogEntry])] {
            Dictionary(grouping: list) { $0.source ?? "unknown" }.sorted { $0.key < $1.key }
        }

        let captures = of(.capture)
        if !captures.isEmpty {
            let counts = bySource(captures).map { "\($0.0) \($0.1.count)" }.joined(separator: ", ")
            lines.append("Pins: \(captures.count) (\(counts))")
            let lateFixes = of(.lateFix)
            let positioned = captures.filter { $0.fixAge != nil }.count + lateFixes.filter { $0.outcome == "attached" }.count
            let approximate = captures.filter { $0.approximate == true }.count + lateFixes.filter { $0.approximate == true }.count
            let unsaved = captures.filter { $0.saved == false }.count
            lines.append("  With a position: \(positioned) · approximate: \(approximate) · not saved: \(unsaved)")
            let appTaps = captures.filter { $0.source == "app" }
            if !appTaps.isEmpty {
                lines.append("  App taps with GPS ready at the tap: \(appTaps.filter { $0.fixAge != nil }.count) of \(appTaps.count)")
            }
            let arrivals = captures.filter { $0.source == "watch" }.compactMap(\.seconds)
            if !arrivals.isEmpty {
                lines.append("  Apple Watch pins reached the iPhone: \(spread(arrivals))")
            }
        }

        let lateFixes = of(.lateFix)
        if !lateFixes.isEmpty {
            lines.append("Waiting for GPS (pins saved before a reading):")
            for (source, list) in bySource(lateFixes) {
                let attached = list.filter { $0.outcome == "attached" }
                var text = "  \(source): \(list.count)"
                if !attached.isEmpty { text += " · \(spread(attached.compactMap(\.seconds)))" }
                let missed = list.count - attached.count
                if missed > 0 { text += " · no position: \(missed)" }
                lines.append(text)
            }
        }

        let skipped = of(.noGPS)
        if !skipped.isEmpty {
            lines.append("GPS not tried (location or Precise Location off): \(skipped.count)")
        }

        let intents = of(.intent)
        if !intents.isEmpty {
            let parts = bySource(intents).map { "\($0.0) \($0.1.count), \(spread($0.1.compactMap(\.seconds)))" }
            lines.append("Requests took: \(parts.joined(separator: "; "))")
            let asked = intents.filter { $0.source == "siri" }
            if !asked.isEmpty {
                let answered = asked.filter { $0.outcome == "answered" }.count
                let nothing = asked.filter { $0.outcome == "nothing" }.count
                let failed = asked.filter { $0.outcome?.hasPrefix("error") == true }.count
                lines.append("  Siri's question: answered \(answered) · nothing said \(nothing) · cancelled or failed \(failed)")
            }
        }

        // Pins saved miles back: from Siri, or the capture screen before 1.1.1.
        let milesBack = captures.filter { ($0.miles ?? 0) > 0 }
        if !milesBack.isEmpty {
            let estimated = milesBack.filter { $0.outcome == "milesBack-breadcrumb" }.count
            lines.append("Pins saved miles back: \(milesBack.count) (on the trail \(estimated), in words only \(milesBack.count - estimated))")
        }
        let bumps = of(.bump)
        if !bumps.isEmpty {
            let moved = bumps.filter { $0.outcome != "noPin" }
            let onTrail = moved.filter { $0.outcome == TargetSource.breadcrumb.rawValue }.count
            lines.append("+1 mi back taps: \(bumps.count) · moved a pin \(moved.count) (on the trail \(onTrail), in words only \(moved.count - onTrail)) · no pin just before \(bumps.count - moved.count)")
            let after = moved.compactMap(\.seconds)
            if !after.isEmpty {
                lines.append("  Tapped after the pin: \(spread(after))")
            }
        }

        let restarts = of(.trailRestart)
        if !restarts.isEmpty {
            let reasons = Dictionary(grouping: restarts) { $0.outcome ?? "unknown" }
                .sorted { $0.key < $1.key }
                .map { "\($0.key) \($0.value.count)" }
                .joined(separator: ", ")
            lines.append("Trail restarts: \(restarts.count) (\(reasons))")
        }

        let gps = of(.gps)
        for reason in ["screen", "burst"] {
            let runs = gps.filter { $0.outcome == reason }.compactMap(\.seconds)
            guard !runs.isEmpty, let longest = runs.max() else { continue }
            let name = reason == "screen" ? "GPS on with the capture screen" : "GPS bursts for Siri and widgets"
            lines.append("\(name): \(DriveLogFormat.times(runs.count)), \(DriveLogFormat.duration(runs.reduce(0, +))) in all, longest \(DriveLogFormat.duration(longest))")
        }

        let listens = of(.listen)
        if !listens.isEmpty {
            let heard = listens.filter { $0.outcome == "heard" }.count
            let nothing = listens.filter { $0.outcome == "nothing" }.count
            let stopped = listens.filter { $0.outcome == "stopped" }.count
            let replaced = listens.filter { $0.outcome == "replaced" }.count
            var text = "Listening: heard \(heard) · nothing \(nothing) · stopped \(stopped)"
            if replaced > 0 {
                text += " · cut short by a newer tap \(replaced)"
            }
            lines.append(text)
        }

        let opens = of(.storeOpened)
        let failures = of(.saveFailed)
        if !opens.isEmpty || !failures.isEmpty {
            let unavailable = opens.filter { $0.outcome == "unavailable" }.count
            var text = "Database: opened \(DriveLogFormat.times(opens.count))"
            if !opens.isEmpty { text += ", \(spread(opens.compactMap(\.seconds)))" }
            text += " · wouldn't open \(unavailable) · save failures \(failures.count)"
            lines.append(text)
        }

        let launches = of(.opened).compactMap(\.seconds)
        if !launches.isEmpty {
            lines.append("Opening Passing: \(DriveLogFormat.times(launches.count)), \(spread(launches))")
        }
        var versions: [String] = []
        for version in of(.opened).compactMap(\.outcome) where !versions.contains(version) {
            versions.append(version)
        }
        if !versions.isEmpty {
            lines.append("Versions: \(versions.joined(separator: ", "))")
        }

        let lookups = of(.townLookup)
        if !lookups.isEmpty {
            let found = lookups.filter { $0.outcome == "found" }.count
            let failed = lookups.filter { $0.outcome == "failed" }.count
            lines.append("Town lookups: \(lookups.count) (found \(found), failed \(failed)), \(spread(lookups.compactMap(\.seconds)))")
        }

        let cleanUps = of(.cleanUp).compactMap(\.seconds)
        if let slowest = cleanUps.max() {
            lines.append("Clean-up runs logged: \(cleanUps.count), slowest \(DriveLogFormat.duration(slowest))")
        }
        return lines
    }
}
