import Foundation

/// The drive log (Settings → Drive Log, off by default): a record of how Passing behaved on real
/// drives, for tuning it. It stays on the iPhone, in the App Group container so the app and the
/// widget extension both write to it, and it never holds a location, label, note or speed.
///
/// Each process writes its own file (`DriveLog-app.jsonl`, `DriveLog-widget.jsonl`), one JSON
/// entry per line, so the two never write to the same file at once. Each file keeps roughly its
/// newest 2,500 entries. All file work happens on one serial background queue, in order, so the
/// caller (often the main actor) never waits for the disk.
enum DriveLog {
    /// In the App Group's shared settings, so the widget follows the switch.
    static let enabledKey = "driveLogOn"
    /// Past this size a file drops its older half.
    static let maxFileBytes = 400_000

    static var isOn: Bool {
        AppGroup.defaults?.bool(forKey: enabledKey) ?? false
    }

    /// "widget" in the widget extension, "app" otherwise.
    static let process = Bundle.main.bundleURL.pathExtension == "appex" ? "widget" : "app"
    private static let processes = ["app", "widget"]
    /// Unit tests run inside the app; they never write to the real log.
    private static let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static let queue = DispatchQueue(label: "Passing.driveLog")

    /// Adds an entry, if the log is on. Returns at once: the line is written in the background.
    static func record(_ entry: DriveLogEntry) {
        guard isOn, !isTesting, let url = file(for: process) else { return }
        var copy = entry
        copy.process = process
        let stamped = copy
        queue.async {
            guard var line = try? encoder.encode(stamped) else { return }
            line.append(UInt8(ascii: "\n"))
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    if try append(line, to: url) > maxFileBytes {
                        trim(url)
                    }
                } else {
                    try line.write(to: url, options: .atomic)
                }
            } catch {
                print("Passing: couldn't write the drive log: \(error)")
            }
        }
    }

    /// Waits until every entry already recorded is on disk. For the moments iOS may suspend the
    /// process soon after: the end of a Siri, widget or Control Center request, and Passing going
    /// to the background. Only a few short appends at most.
    static func flush() {
        queue.sync {}
    }

    /// Both processes' entries, oldest first. Read in the background.
    static func load() async -> [DriveLogEntry] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: readAll())
            }
        }
    }

    static func clear() {
        queue.async {
            for process in processes {
                if let url = file(for: process) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    /// The prefix of the shared text file, so `ExportService.removeExportedFiles` can tidy it away.
    static let exportPrefix = "Passing drive log"

    /// A text file to share: what was and wasn't recorded, the summary, then every entry.
    /// Made in the background.
    static func exportFile(now: Date = .now) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try makeExportFile(now: now) })
            }
        }
    }

    // MARK: Private

    /// Runs on `queue`.
    private static func readAll() -> [DriveLogEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var entries: [DriveLogEntry] = []
        for process in processes {
            guard let url = file(for: process), let data = try? Data(contentsOf: url) else { continue }
            for line in data.split(separator: UInt8(ascii: "\n")) {
                // A line from a newer version, or cut short, is skipped rather than failing the lot.
                if let entry = try? decoder.decode(DriveLogEntry.self, from: Data(line)) {
                    entries.append(entry)
                }
            }
        }
        return entries.sorted { $0.at < $1.at }
    }

    /// Runs on `queue`.
    private static func makeExportFile(now: Date) throws -> URL {
        let entries = readAll()
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd"

        var lines = [
            "Passing drive log",
            "Exported \(now.formatted(date: .abbreviated, time: .shortened)) · Passing \(AppVersion.current) · \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Records timings, GPS accuracy and outcomes only: no locations, labels, notes or speeds.",
            "",
            "SUMMARY",
        ]
        lines += DriveLogSummary.lines(for: entries)
        lines += ["", "EVENTS (oldest first)"]
        lines += entries.map { $0.line() }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(exportPrefix) \(stamp.string(from: now)).txt")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func file(for process: String) -> URL? {
        guard let identifier = AppGroup.identifier,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else { return nil }
        return folder.appendingPathComponent("DriveLog-\(process).jsonl")
    }

    /// Adds `line` to the end of the file. Returns the file's new size.
    private static func append(_ line: Data, to url: URL) throws -> Int {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        try handle.write(contentsOf: line)
        return Int(size) + line.count
    }

    /// Keeps the newer half of the file's lines.
    private static func trim(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let lines = data.split(separator: UInt8(ascii: "\n"))
        var kept = Data()
        for line in lines.suffix(lines.count / 2) {
            kept.append(contentsOf: line)
            kept.append(UInt8(ascii: "\n"))
        }
        try? kept.write(to: url, options: .atomic)
    }
}

// MARK: Entries for pins

extension DriveLogEntry {
    /// A pin just saved. Side and distance go in `outcome`, or how a miles-back pin was placed.
    static func capture(_ pin: Pin, saved: Bool, trailMeters: Double? = nil) -> DriveLogEntry {
        var entry = DriveLogEntry(at: .now, kind: .capture)
        entry.source = pin.source.rawValue
        entry.outcome = pin.milesBack > 0
            ? "milesBack-\(pin.targetSource.rawValue)"
            : "\(pin.side.rawValue)-\(pin.distance.rawValue)"
        entry.saved = saved
        entry.add(fixOf: pin)
        if pin.milesBack > 0 {
            entry.miles = pin.milesBack
            entry.trailMiles = trailMeters.map { $0 / Geo.metersPerMile }
        }
        return entry
    }

    /// An Apple Watch pin's trip, from what the pin carried: how the watch's GPS went, how long from
    /// the tap and from the watch handing it over until it got here, and how many times it was sent.
    mutating func add(watchTrip pin: WatchPin, arrivedAt: Date) {
        seconds = arrivedAt.timeIntervalSince(pin.capturedAt)
        watchGPS = pin.gps?.rawValue
        watchWait = pin.gpsWait
        transfer = pin.sentAt.map { arrivedAt.timeIntervalSince($0) }
        count = pin.sends
    }

    /// The fix stamped on a pin: when it was taken compared to the tap, how accurate, and whether
    /// the pin counts as approximate. Nothing when it has no position.
    mutating func add(fixOf pin: Pin) {
        guard pin.hasLocation, let fixTimestamp = pin.fixTimestamp else { return }
        fixAge = fixTimestamp.timeIntervalSince(pin.capturedAt)
        accuracy = pin.horizontalAccuracy
        approximate = pin.isApproximate
    }
}
