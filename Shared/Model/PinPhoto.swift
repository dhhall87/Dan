import Foundation
import SwiftData

/// A photo added to a pin while reviewing it, taken with the camera or chosen from the library.
/// Passing keeps a smaller copy, without the original's hidden location and camera details, and the
/// photo goes when its pin does. A new model, so the store migrates lightly.
@Model
final class PinPhoto {
    var id: UUID = UUID()
    var addedAt: Date = Date()
    /// A JPEG about 1,600 pixels on its long side. Kept in its own file beside the store, so it's
    /// only read when the photo is opened.
    @Attribute(.externalStorage) var imageData: Data?
    /// A small JPEG for the pin screen's row of photos.
    @Attribute(.externalStorage) var thumbnailData: Data?
    var pin: Pin?

    init(imageData: Data, thumbnailData: Data, addedAt: Date = .now) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.addedAt = addedAt
    }
}
