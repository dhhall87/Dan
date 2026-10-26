import SwiftUI

/// Passing on Apple Watch: four buttons that save a pin with the watch's own GPS, kept on the watch
/// until Passing on the iPhone has saved it.
@main
struct PassingWatchApp: App {
    init() {
        // Starts the link to the iPhone straight away, so pins waiting from earlier go as soon as
        // they can, and the iPhone's "saved" answers are heard.
        _ = WatchCapture.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchCaptureView()
        }
    }
}
