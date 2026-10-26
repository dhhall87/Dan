import Foundation

/// A plain copy of a pin for export. Kept separate from the SwiftData model so exporting can't
/// change stored pins, and so the JSON, CSV and KML formatting is easy to unit test. Speed is left
/// out on purpose: an export can end up anywhere, and how fast you were driving isn't needed there.
struct PinRecord: Codable, Equatable {
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
    /// Notes added while reviewing.
    var notes: String?
    var placeName: String?
    /// The name of the pin's group, if it's in one.
    var group: String?
    var source: String
    /// A text note rather than a pin: no location, and `label` holds the text.
    var isNote: Bool = false
    var isReviewed: Bool
    var isKept: Bool
    var deletedAt: Date?
    var appleMapsURL: String?
    var googleMapsURL: String?
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv
    case kml

    var id: String { rawValue }
    var fileExtension: String { rawValue }

    var title: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV (spreadsheet)"
        case .kml: return "KML (Google My Maps)"
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

    /// Column order for CSV. The breadcrumb trail is JSON-only. Speed is never exported.
    static let csvColumns = [
        "id", "capturedAt", "fixTimestamp", "latitude", "longitude", "horizontalAccuracy",
        "course", "courseReliable", "side", "distance", "milesBack",
        "targetLatitude", "targetLongitude", "targetSource", "label", "notes", "placeName", "group", "source",
        "isNote", "isReviewed", "isKept", "deletedAt", "appleMapsURL", "googleMapsURL",
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
                number(pin.course), "\(pin.courseReliable)",
                pin.side, pin.distance, "\(pin.milesBack)",
                number(pin.targetLatitude), number(pin.targetLongitude), pin.targetSource,
                pin.label ?? "", pin.notes ?? "", pin.placeName ?? "", pin.group ?? "", pin.source,
                "\(pin.isNote)", "\(pin.isReviewed)", "\(pin.isKept)", date(pin.deletedAt),
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

    /// "Passing pins 2026-10-25.csv", or "Passing pins - Road trip 2026-10-25.csv" for one group,
    /// using the phone's local date.
    static func fileName(format: ExportFormat, exportedAt: Date, groupName: String? = nil, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = timeZone
        // Slashes and colons aren't allowed in file names.
        let group = groupName.map { " - " + $0.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") } ?? ""
        return "Passing pins\(group) \(formatter.string(from: exportedAt)).\(format.fileExtension)"
    }

    // MARK: KML

    /// The title Google My Maps gives the imported layer: "Passing pins", or "Passing pins - Road trip".
    static func kmlTitle(groupName: String?) -> String {
        groupName.map { "Passing pins - \($0)" } ?? "Passing pins"
    }

    /// The pins that become KML placemarks, with their coordinates: not notes, and with a location.
    static func kmlPlaced(_ pins: [PinRecord]) -> [(PinRecord, String)] {
        pins.filter { !$0.isNote }.compactMap { pin in kmlCoordinate(for: pin).map { (pin, $0) } }
    }

    /// The pins actually written into a file of this format. "Delete pins after exporting" removes
    /// only these, so a note or a pin without a location left out of a KML file stays put.
    static func includedIDs(_ pins: [PinRecord], format: ExportFormat) -> Set<UUID> {
        switch format {
        case .json, .csv: return Set(pins.map(\.id))
        case .kml: return Set(kmlPlaced(pins).map(\.0.id))
        }
    }

    /// A KML file for Google My Maps (Create a new map, then Import) or Google Earth. Each pin is a
    /// placemark at its estimated spot if it has one, otherwise where the car was, with its details
    /// as fields My Maps shows in a table. Pins without a location can't go on a map, so they're left
    /// out, and the document's description says how many. Notes aren't places, so they're left out
    /// without being counted.
    static func kml(_ pins: [PinRecord], title: String, exportedAt: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        display.timeZone = timeZone
        display.locale = locale
        let iso = ISO8601DateFormatter()

        let places = pins.filter { !$0.isNote }
        let mapped = kmlPlaced(pins)
        let missing = places.count - mapped.count
        var summary = "Exported from Passing on \(display.string(from: exportedAt))."
        if missing > 0 {
            summary += missing == 1 ? " 1 pin had no location and was left out." : " \(missing) pins had no location and were left out."
        }

        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<kml xmlns="http://www.opengis.net/kml/2.2">"#,
            "<Document>",
            "  <name>\(xml(title))</name>",
            "  <description>\(xml(summary))</description>",
        ]
        for (pin, coordinate) in mapped {
            let side = Side(rawValue: pin.side) ?? .unknown
            let distance = Distance(rawValue: pin.distance) ?? .unknown
            let fields: [(String, String?)] = [
                ("Pinned", display.string(from: pin.capturedAt)),
                ("Side", PinDescription.sideAndDistance(side: side, distance: distance)),
                ("Miles back", pin.milesBack > 0 ? Geo.milesText(pin.milesBack) : nil),
                ("Place", pin.placeName),
                ("Group", pin.group),
                ("Notes", pin.notes.flatMap { $0.isEmpty ? nil : $0 }),
                ("Accuracy", pin.horizontalAccuracy.map { "±\(Int($0.rounded())) m" }),
                ("Apple Maps", pin.appleMapsURL),
            ]
            let shown = fields.compactMap { name, value in value.map { (name, $0) } }
            var note = shown.filter { $0.0 != "Apple Maps" && $0.0 != "Miles back" }.map { $0.1 }.joined(separator: " · ")
            if pin.targetSource == TargetSource.manual.rawValue {
                note += note.isEmpty ? "Moved to the spot by hand." : ". Moved to the spot by hand."
            } else if pin.milesBack > 0 {
                let miles = Geo.milesText(pin.milesBack)
                note += pin.targetSource == TargetSource.breadcrumb.rawValue
                    ? ". Estimated spot, \(miles) back along the road driven."
                    : ". About \(miles) back the way you came; this marks where you were when you pinned it."
            }
            lines.append("  <Placemark>")
            lines.append("    <name>\(xml(pin.label.flatMap { $0.isEmpty ? nil : $0 } ?? "Unlabeled"))</name>")
            lines.append("    <description>\(xml(note))</description>")
            lines.append("    <TimeStamp><when>\(iso.string(from: pin.capturedAt))</when></TimeStamp>")
            lines.append("    <ExtendedData>")
            for (name, value) in shown {
                lines.append("      <Data name=\"\(xml(name))\"><value>\(xml(value))</value></Data>")
            }
            lines.append("    </ExtendedData>")
            lines.append("    <Point><coordinates>\(coordinate)</coordinates></Point>")
            lines.append("  </Placemark>")
        }
        lines.append("</Document>")
        lines.append("</kml>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// "longitude,latitude,0" (KML puts longitude first) at the estimate if there is one, otherwise
    /// where the car was. Nil when the pin has no location.
    static func kmlCoordinate(for pin: PinRecord) -> String? {
        let latitude: Double
        let longitude: Double
        if let targetLatitude = pin.targetLatitude, let targetLongitude = pin.targetLongitude {
            latitude = targetLatitude
            longitude = targetLongitude
        } else if let captureLatitude = pin.latitude, let captureLongitude = pin.longitude {
            latitude = captureLatitude
            longitude = captureLongitude
        } else {
            return nil
        }
        return String(format: "%.6f,%.6f,0", longitude, latitude)
    }

    /// Escapes text for XML.
    static func xml(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
