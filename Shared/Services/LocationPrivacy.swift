import Foundation

/// The "Precise location" switch (Settings → Privacy), on by default. It lives in the App Group's
/// shared settings so the widget and Control Center follow it too.
enum LocationPrivacy {
    static let key = "preciseLocation"

    static var isPrecise: Bool {
        AppGroup.defaults?.object(forKey: key) as? Bool ?? true
    }
}
