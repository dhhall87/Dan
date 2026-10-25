import Foundation

/// Notes the widget extension leaves in the App Group's shared settings: the widget's "Saved"
/// tick, and the time of the last widget or Control Center pin, so the app knows to refresh its list.
enum WidgetActivity {
    private static let noteKey = "widgetSavedNote"
    private static let lastCaptureKey = "lastWidgetCapture"

    /// Called once a widget or Control Center capture has finished (location attached or given up).
    @MainActor
    static func record(_ pin: Pin, now: Date = .now) {
        guard let defaults = AppGroup.defaults else { return }
        defaults.set(now, forKey: lastCaptureKey)
        if pin.source == .widget {
            let note = WidgetSavedNote(savedAt: now, side: pin.side, distance: pin.distance, hasLocation: pin.hasLocation)
            if let data = try? JSONEncoder().encode(note) {
                defaults.set(data, forKey: noteKey)
            }
        }
    }

    static var lastNote: WidgetSavedNote? {
        guard let data = AppGroup.defaults?.data(forKey: noteKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSavedNote.self, from: data)
    }

    /// When the widget or Control Center last saved a pin, or nil if they never have.
    static var lastCaptureAt: Date? {
        AppGroup.defaults?.object(forKey: lastCaptureKey) as? Date
    }
}
