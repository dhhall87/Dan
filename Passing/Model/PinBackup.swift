import Foundation

/// A backup of every active pin, as one file that Passing can read back in (Settings → Back Up and
/// Restore). Unlike the JSON, CSV and KML exports, which are for other apps, it carries everything
/// needed to rebuild the pins: groups, notes, the chosen place and the photos. Speed is left out,
/// as in every file that leaves Passing. Plain values, so the format is easy to unit test.
struct PinBackup: Codable, Equatable {
    static let currentVersion = 1
    static let kindName = "passing-backup"
    /// File names start with this, so Passing can tidy its own copy away after sharing.
    static let filePrefix = "Passing backup"

    var kind = PinBackup.kindName
    var version = PinBackup.currentVersion
    var createdAt: Date
    var groups: [Group]
    var pins: [Item]

    struct Group: Codable, Equatable {
        var name: String
        var sortOrder: Int
        var createdAt: Date
    }

    struct Photo: Codable, Equatable {
        var addedAt: Date
        var image: Data
        var thumbnail: Data
    }

    struct Item: Codable, Equatable {
        var id: UUID
        var capturedAt: Date
        var fixTimestamp: Date?
        var latitude: Double?
        var longitude: Double?
        var horizontalAccuracy: Double?
        var course: Double?
        var courseReliable: Bool
        var side: String
        var distance: String
        var milesBack: Double
        var targetLatitude: Double?
        var targetLongitude: Double?
        var targetSource: String
        var trail: Data?
        var label: String?
        var placeName: String?
        var source: String
        var isReviewed: Bool
        var isKept: Bool
        var isNote: Bool
        var placeID: String?
        var notes: String?
        /// The name of the pin's group, if it's in one.
        var group: String?
        var photos: [Photo]
    }

    enum ReadError: Error, Equatable {
        /// Not a Passing backup (another JSON file, or a Passing export meant for other apps).
        case notABackup
        /// Made by a newer version of Passing than this one.
        case newerVersion
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) throws -> PinBackup {
        struct Header: Decodable {
            var kind: String?
            var version: Int?
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data),
              header.kind == kindName, let version = header.version
        else { throw ReadError.notABackup }
        guard version <= currentVersion else { throw ReadError.newerVersion }
        do {
            return try JSONDecoder().decode(PinBackup.self, from: data)
        } catch {
            throw ReadError.notABackup
        }
    }

    /// The pins a restore adds: those not already here, each once (by id). Restoring never changes
    /// or replaces a pin that exists, in Pins or in Recently Deleted.
    func itemsToAdd(existing: Set<UUID>) -> [Item] {
        var seen = existing
        return pins.filter { seen.insert($0.id).inserted }
    }

    /// "Passing backup 2026-11-10.json"
    static func fileName(createdAt: Date, timeZone: TimeZone = .current) -> String {
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.timeZone = timeZone
        stamp.dateFormat = "yyyy-MM-dd"
        return "\(filePrefix) \(stamp.string(from: createdAt)).json"
    }

    /// "Added 12 pins. 3 were already here."
    static func restoreMessage(added: Int, alreadyHere: Int) -> String {
        let addedText = added == 1 ? "Added 1 pin." : "Added \(added) pins."
        guard alreadyHere > 0 else { return addedText }
        return addedText + (alreadyHere == 1 ? " 1 was already here." : " \(alreadyHere) were already here.")
    }
}
