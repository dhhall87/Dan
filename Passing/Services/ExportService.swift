import Foundation
import SwiftData

/// Writes the active pins (not Recently Deleted) to a JSON or CSV file for the share sheet.
@MainActor
enum ExportService {
    static func exportActivePins(as format: ExportFormat) throws -> URL {
        // The shared store is looked up here rather than as default arguments: default values are
        // evaluated outside the main actor, and the compiler rejects main-actor state there.
        try exportActivePins(as: format, context: SharedStore.context, retention: .shared, now: .now)
    }

    /// The same, with every dependency passed in (used by the tests).
    static func exportActivePins(
        as format: ExportFormat,
        context: ModelContext,
        retention: RetentionService,
        now: Date
    ) throws -> URL {
        try retention.whilePaused {
            let descriptor = FetchDescriptor<Pin>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.capturedAt)]
            )
            let records = try context.fetch(descriptor).map(PinRecord.init(pin:))
            let data: Data
            switch format {
            case .json: data = try PinExport.json(records, exportedAt: now)
            case .csv: data = Data(PinExport.csv(records).utf8)
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(PinExport.fileName(format: format, exportedAt: now))
            try data.write(to: url, options: .atomic)
            return url
        }
    }
}

extension PinRecord {
    init(pin: Pin) {
        self.init(
            id: pin.id,
            capturedAt: pin.capturedAt,
            fixTimestamp: pin.fixTimestamp,
            latitude: pin.latitude,
            longitude: pin.longitude,
            horizontalAccuracy: pin.horizontalAccuracy,
            course: pin.course,
            courseReliable: pin.courseReliable,
            speed: pin.speed,
            side: pin.side.rawValue,
            distance: pin.distance.rawValue,
            milesBack: pin.milesBack,
            targetLatitude: pin.targetLatitude,
            targetLongitude: pin.targetLongitude,
            targetSource: pin.targetSource.rawValue,
            trail: pin.trail,
            label: pin.label,
            placeName: pin.placeName,
            source: pin.source.rawValue,
            isReviewed: pin.isReviewed,
            isKept: pin.isKept,
            deletedAt: pin.deletedAt,
            appleMapsURL: pin.appleMapsURL?.absoluteString,
            googleMapsURL: pin.googleMapsURL?.absoluteString
        )
    }
}
