import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Passing

@MainActor
struct PinPhotosTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: Pin.self, PinGroup.self, PinPhoto.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private struct DiskFull: Error {}

    private var context: ModelContext { container.mainContext }
    private let save: @MainActor (ModelContext) throws -> Void = { try $0.save() }
    private let small = PinPhotos.Prepared(image: Data([1, 2, 3]), thumbnail: Data([4]))

    private func newPin() -> Pin {
        let pin = Pin(capturedAt: .now, side: .left, distance: .far, source: .app)
        context.insert(pin)
        return pin
    }

    @Test func aPhotoIsAddedAndCounted() {
        let pin = newPin()
        #expect(PinPhotos.add(small, to: pin, in: context, persist: save))
        #expect(pin.photoCount == 1)
        #expect(PinPhotos.sorted(pin).first?.imageData == Data([1, 2, 3]))
    }

    @Test func aPinKeepsAtMostSixPhotos() {
        let pin = newPin()
        for _ in 0..<PinPhotos.maxPerPin {
            #expect(PinPhotos.add(small, to: pin, in: context, persist: save))
        }
        #expect(!PinPhotos.add(small, to: pin, in: context, persist: save))
        #expect(pin.photoCount == 6)
        #expect(PinPhotos.remaining(for: pin) == 0)
    }

    @Test func aPhotoThatCouldntBeSavedIsTakenBack() throws {
        let pin = newPin()
        try context.save()
        #expect(!PinPhotos.add(small, to: pin, in: context, persist: { _ in throw DiskFull() }))
        #expect(pin.photoCount == 0)
        #expect(PinPhotos.sorted(pin).isEmpty, "nothing shows as if it were saved")
    }

    @Test func photosAreOldestFirstAndDeletedOneByOne() throws {
        let pin = newPin()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        PinPhotos.add(PinPhotos.Prepared(image: Data([2]), thumbnail: Data()), to: pin, in: context, now: start.addingTimeInterval(60), persist: save)
        PinPhotos.add(PinPhotos.Prepared(image: Data([1]), thumbnail: Data()), to: pin, in: context, now: start, persist: save)
        #expect(PinPhotos.sorted(pin).map(\.imageData) == [Data([1]), Data([2])])

        let first = try #require(PinPhotos.sorted(pin).first)
        PinPhotos.delete(first, in: context, persist: save)
        #expect(pin.photoCount == 1)
        #expect(PinPhotos.sorted(pin).map(\.imageData) == [Data([2])])
    }

    @Test func deletingAPinForGoodDeletesItsPhotos() throws {
        let pin = newPin()
        PinPhotos.add(small, to: pin, in: context, persist: save)
        PinPhotos.add(small, to: pin, in: context, persist: save)
        context.delete(pin)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<PinPhoto>()) == 0)
    }

    @Test func theStoredCopyIsSmallerAndHasNoLocation() async throws {
        // A 3000 × 2000 photo carrying a GPS position, like one from the camera roll.
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let original = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(original as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil))
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 40.7128, kCGImagePropertyGPSLatitudeRef: "N"]
        let pixels = try #require(image.cgImage)
        CGImageDestinationAddImage(destination, pixels, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let prepared = try #require(await PinPhotos.prepare(original as Data))
        for (data, limit) in [(prepared.image, PinPhotos.photoPixels), (prepared.thumbnail, PinPhotos.thumbnailPixels)] {
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
            let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
            #expect(max(width, height) <= limit)
            #expect(properties[kCGImagePropertyGPSDictionary] == nil, "the photo's location is never kept")
        }
    }
}
