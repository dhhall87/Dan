import ImageIO
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Adding and removing a pin's photos, while reviewing (never on the capture screen). Each photo is
/// kept as a smaller JPEG; re-encoding it leaves out the original's hidden location and camera
/// details. Saves are checked, like every capture: a photo that couldn't be written is taken back
/// rather than shown as if it were saved.
enum PinPhotos {
    /// Most photos one pin keeps.
    static let maxPerPin = 6
    /// The stored photo's long side, in pixels: sharp on the phone, about 0.3–0.5 MB.
    static let photoPixels = 1600
    /// The thumbnail's long side, in pixels.
    static let thumbnailPixels = 320

    struct Prepared: Sendable {
        let image: Data
        let thumbnail: Data
    }

    static func remaining(for pin: Pin) -> Int {
        max(0, maxPerPin - pin.photoCount)
    }

    /// The pin's photos, oldest first, leaving out any just deleted.
    static func sorted(_ pin: Pin) -> [PinPhoto] {
        pin.photos.filter { !$0.isDeleted }.sorted { $0.addedAt < $1.addedAt }
    }

    /// Makes the smaller copies from a photo's file (JPEG, HEIC, PNG…), away from the main thread.
    static func prepare(_ data: Data) async -> Prepared? {
        await Task.detached(priority: .userInitiated) { () -> Prepared? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = jpeg(from: source, maxPixels: photoPixels, quality: 0.75),
                  let thumbnail = jpeg(from: source, maxPixels: thumbnailPixels, quality: 0.7)
            else { return nil }
            return Prepared(image: image, thumbnail: thumbnail)
        }.value
    }

    /// The same, for a photo just taken with the camera.
    static func prepare(_ image: UIImage) async -> Prepared? {
        let data = await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.95)
        }.value
        guard let data else { return nil }
        return await prepare(data)
    }

    /// Adds a photo to the pin and saves it.
    /// - Returns: whether it's on disk. If not, it's taken back, so nothing shows that isn't saved.
    @MainActor
    @discardableResult
    static func add(
        _ prepared: Prepared,
        to pin: Pin,
        in context: ModelContext,
        now: Date = .now,
        persist: @MainActor (ModelContext) throws -> Void = { try SharedStore.save($0) }
    ) -> Bool {
        guard pin.modelContext != nil, !pin.isDeleted, remaining(for: pin) > 0 else { return false }
        let photo = PinPhoto(imageData: prepared.image, thumbnailData: prepared.thumbnail, addedAt: now)
        context.insert(photo)
        photo.pin = pin
        pin.photoCount += 1
        do {
            try persist(context)
            return true
        } catch {
            print("Passing: photo not saved: \(error)")
            photo.pin = nil
            context.delete(photo)
            pin.photoCount -= 1
            return false
        }
    }

    /// Deletes one photo for good. The pin stays.
    @MainActor
    static func delete(
        _ photo: PinPhoto,
        in context: ModelContext,
        persist: @MainActor (ModelContext) throws -> Void = { try SharedStore.save($0) }
    ) {
        guard photo.modelContext != nil, !photo.isDeleted else { return }
        if let pin = photo.pin, pin.modelContext != nil, !pin.isDeleted {
            pin.photoCount = max(0, pin.photoCount - 1)
        }
        context.delete(photo)
        do {
            try persist(context)
        } catch {
            // Still deleted in memory; the next save that works writes it.
            print("Passing: photo deletion not saved yet: \(error)")
        }
    }

    // MARK: Private

    /// A JPEG at most `maxPixels` on its long side, the right way up. Only the pixels are written:
    /// none of the original's location, camera or date details.
    private static func jpeg(from source: CGImageSource, maxPixels: Int, quality: Double) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
