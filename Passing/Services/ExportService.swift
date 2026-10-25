import Foundation
import SwiftData

/// Writes the active pins (not Recently Deleted) to a JSON, CSV or KML file for the share sheet.
/// `filter` limits it to the group being shown in the list; `groupName` goes in the file name.
@MainActor
enum ExportService {
    static func exportActivePins(as format: ExportFormat, filter: GroupFilter = .all, groupName: String? = nil) throws -> URL {
        // The shared store is looked up here rather than as default arguments: default values are
        // evaluated outside the main actor, and the compiler rejects main-actor state there.
        try exportActivePins(as: format, filter: filter, groupName: groupName, context: SharedStore.context, retention: .shared, now: .now)
    }

    /// The same, with every dependency passed in (used by the tests).
    static func exportActivePins(
        as format: ExportFormat,
        filter: GroupFilter = .all,
        groupName: String? = nil,
        context: ModelContext,
        retention: RetentionService,
        now: Date
    ) throws -> URL {
        try retention.whilePaused {
            let descriptor = FetchDescriptor<Pin>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.capturedAt)]
            )
            let records = try context.fetch(descriptor)
                .filter { filter.includes(groupID: $0.group?.id) }
                .map(PinRecord.init(pin:))
            let data: Data
            switch format {
            case .json: data = try PinExport.json(records, exportedAt: now)
            case .csv: data = Data(PinExport.csv(records).utf8)
            case .kml: data = Data(PinExport.kml(records, title: PinExport.kmlTitle(groupName: groupName), exportedAt: now).utf8)
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(PinExport.fileName(format: format, exportedAt: now, groupName: groupName))
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
            group: pin.group?.name,
            source: pin.source.rawValue,
            isReviewed: pin.isReviewed,
            isKept: pin.isKept,
            deletedAt: pin.deletedAt,
            appleMapsURL: pin.appleMapsURL?.absoluteString,
            googleMapsURL: pin.googleMapsURL?.absoluteString
        )
    }
}
