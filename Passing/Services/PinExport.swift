import Foundation

/// A plain copy of a pin for export. Kept separate from the SwiftData model so exporting can't
/// change stored pins, and so the JSON/CSV formatting is easy to unit test.
struct PinRecord: Codable, Equatable {
    var id: UUID
    var capturedAt: Date
    var fixTimestamp: Date?
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var course: Double?
    var courseReliable: Bool
    var speed: Double?
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
    var deletedAt: Date?
    var appleMapsURL: String?
    var googleMapsURL: String?
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }
    var fileExtension: String { rawValue }

    var title: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV (spreadsheet)"
        }
    }
}

enum PinExport {
    struct Document: Codable, Equatable {
        var app: String
        var exportedAt: Date
        var pins: [PinRecord]
    }

    static func json(_ pins: [PinRecord], exportedAt: Date) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Document(app: "Passing", exportedAt: exportedAt, pins: pins))
    }

    static func decodeJSON(_ data: Data) throws -> Document {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Document.self, from: data)
    }

    /// Column order for CSV. The breadcrumb trail is JSON-only.
    static let csvColumns = [
        "id", "capturedAt", "fixTimestamp", "latitude", "longitude", "horizontalAccuracy",
        "course", "courseReliable", "speed", "side", "distance", "milesBack",
        "targetLatitude", "targetLongitude", "targetSource", "label", "placeName", "source",
        "isReviewed", "isKept", "deletedAt", "appleMapsURL", "googleMapsURL",
    ]

    /// RFC 4180 CSV with a header row and CRLF line endings. Missing values are empty fields.
    static func csv(_ pins: [PinRecord]) -> String {
        let dates = ISO8601DateFormatter()
        func date(_ value: Date?) -> String { value.map { dates.string(from: $0) } ?? "" }
        func number(_ value: Double?) -> String { value.map { "\($0)" } ?? "" }

        var lines = [csvColumns.joined(separator: ",")]
        for pin in pins {
            let fields: [String] = [
                pin.id.uuidString, date(pin.capturedAt), date(pin.fixTimestamp),
                number(pin.latitude), number(pin.longitude), number(pin.horizontalAccuracy),
                number(pin.course), "\(pin.courseReliable)", number(pin.speed),
                pin.side, pin.distance, "\(pin.milesBack)",
                number(pin.targetLatitude), number(pin.targetLongitude), pin.targetSource,
                pin.label ?? "", pin.placeName ?? "", pin.source,
                "\(pin.isReviewed)", "\(pin.isKept)", date(pin.deletedAt),
                pin.appleMapsURL ?? "", pin.googleMapsURL ?? "",
            ]
            lines.append(fields.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field if it contains a comma, quote or line break, doubling any quotes inside.
    static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// "Passing pins 2026-10-25.csv", using the phone's local date.
    static func fileName(format: ExportFormat, exportedAt: Date, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = timeZone
        return "Passing pins \(formatter.string(from: exportedAt)).\(format.fileExtension)"
    }
}
