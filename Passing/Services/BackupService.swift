import Foundation
import SwiftData

/// Settings → Back Up and Restore: writes every active pin (with its group, notes and photos) to
/// one file, and reads such a file back in. A restore only adds pins that aren't here already; it
/// never changes or replaces one that is.
@MainActor
enum BackupService {
    struct RestoreResult: Equatable {
        var added: Int
        var alreadyHere: Int
    }

    /// Makes the backup file in Passing's temporary folder, for the share sheet.
    static func makeBackupFile(context: ModelContext, retention: RetentionService, now: Date = .now) throws -> URL {
        try retention.whilePaused {
            let backup = try backup(context: context, now: now)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(PinBackup.fileName(createdAt: now))
            try backup.encoded().write(to: url, options: .atomic)
            return url
        }
    }

    static func backup(context: ModelContext, now: Date) throws -> PinBackup {
        let pins = try context.fetch(FetchDescriptor<Pin>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.capturedAt)]
        ))
        let groups = PinGroups.all(in: context).map {
            PinBackup.Group(name: $0.name, sortOrder: $0.sortOrder, createdAt: $0.createdAt)
        }
        return PinBackup(createdAt: now, groups: groups, pins: pins.map(PinBackup.Item.init(pin:)))
    }

    /// Reads a backup file picked in Files and adds its pins.
    static func restore(from url: URL, context: ModelContext, now: Date = .now) throws -> RestoreResult {
        // A file picked from Files or iCloud Drive is only readable between these two calls.
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        let backup = try PinBackup.decode(try Data(contentsOf: url))
        return try restore(backup, context: context, now: now)
    }

    static func restore(
        _ backup: PinBackup,
        context: ModelContext,
        now: Date = .now,
        persist: @MainActor (ModelContext) throws -> Void = { try SharedStore.save($0) }
    ) throws -> RestoreResult {
        let existing = Set(try context.fetch(FetchDescriptor<Pin>()).map(\.id))
        let items = backup.itemsToAdd(existing: existing)

        // Groups come back under their names; one that already exists here is reused.
        var groups: [String: PinGroup] = [:]
        for saved in backup.groups.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if let group = PinGroups.createOrFind(named: saved.name, in: context) {
                groups[saved.name] = group
            }
        }

        var added: [Pin] = []
        for item in items {
            let pin = Pin(item)
            // A pin already past its 7 days would be cleaned up straight away, so it comes back kept.
            if RetentionPolicy.keepOnRecover(capturedAt: pin.capturedAt, now: now) {
                pin.isKept = true
            }
            context.insert(pin)
            if let name = item.group {
                pin.group = groups[name] ?? PinGroups.createOrFind(named: name, in: context)
            }
            for photo in item.photos.prefix(PinPhotos.maxPerPin) {
                let restored = PinPhoto(imageData: photo.image, thumbnailData: photo.thumbnail, addedAt: photo.addedAt)
                context.insert(restored)
                restored.pin = pin
                pin.photoCount += 1
            }
            added.append(pin)
        }
        do {
            try persist(context)
        } catch {
            // Nothing half-restored: take them back, so trying again can't double anything.
            for pin in added {
                context.delete(pin)
            }
            throw error
        }
        return RestoreResult(added: added.count, alreadyHere: backup.pins.count - items.count)
    }
}

extension PinBackup.Item {
    @MainActor
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
            side: pin.sideRaw,
            distance: pin.distanceRaw,
            milesBack: pin.milesBack,
            targetLatitude: pin.targetLatitude,
            targetLongitude: pin.targetLongitude,
            targetSource: pin.targetSourceRaw,
            trail: pin.trail,
            label: pin.label,
            placeName: pin.placeName,
            source: pin.sourceRaw,
            isReviewed: pin.isReviewed,
            isKept: pin.isKept,
            isNote: pin.isNote,
            placeID: pin.placeID,
            notes: pin.notes,
            group: pin.group?.name,
            photos: PinPhotos.sorted(pin).compactMap { photo in
                guard let image = photo.imageData, let thumbnail = photo.thumbnailData else { return nil }
                return PinBackup.Photo(addedAt: photo.addedAt, image: image, thumbnail: thumbnail)
            }
        )
    }
}

private extension Pin {
    /// A pin rebuilt from a backup, with the id it had, so restoring twice adds it once.
    convenience init(_ item: PinBackup.Item) {
        self.init(
            capturedAt: item.capturedAt,
            side: Side(rawValue: item.side) ?? .unknown,
            distance: Distance(rawValue: item.distance) ?? .unknown,
            source: CaptureSource(rawValue: item.source) ?? .app
        )
        id = item.id
        fixTimestamp = item.fixTimestamp
        latitude = item.latitude
        longitude = item.longitude
        horizontalAccuracy = item.horizontalAccuracy
        course = item.course
        courseReliable = item.courseReliable
        milesBack = item.milesBack
        targetLatitude = item.targetLatitude
        targetLongitude = item.targetLongitude
        targetSource = TargetSource(rawValue: item.targetSource) ?? .direct
        trail = item.trail
        label = item.label
        placeName = item.placeName
        isReviewed = item.isReviewed
        isKept = item.isKept
        isNote = item.isNote
        placeID = item.placeID
        notes = item.notes
    }
}
