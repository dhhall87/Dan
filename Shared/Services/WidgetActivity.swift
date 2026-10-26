import Foundation

/// Notes the widget extension leaves in the App Group's shared settings: the widget's "Saved"
/// tick, and the time of the last widget or Control Center pin, so the app knows to refresh its list.
/// It also sends a system-wide signal after each save, so a Pins list that's open shows the pin at once.
enum WidgetActivity {
    private static let noteKey = "widgetSavedNote"
    private static let lastCaptureKey = "lastWidgetCapture"

    /// Posted on the app's main thread when the widget or Control Center has saved a pin.
    static let pinSaved = Notification.Name("PassingWidgetPinSaved")

    private static var savedName: CFString {
        ((AppGroup.identifier ?? "Passing") + ".pinSaved") as CFString
    }

    /// Called once a widget or Control Center capture has finished (location attached or given up).
    @MainActor
    static func record(_ pin: Pin, saved: Bool = true, now: Date = .now) {
        guard let defaults = AppGroup.defaults else { return }
        defaults.set(now, forKey: lastCaptureKey)
        if pin.source == .widget {
            let note = WidgetSavedNote(savedAt: now, side: pin.side, distance: pin.distance, hasLocation: pin.hasLocation, saved: saved)
            if let data = try? JSONEncoder().encode(note) {
                defaults.set(data, forKey: noteKey)
            }
        }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(savedName), nil, nil, true)
    }

    /// In the app, once: turns the widget's signal into `pinSaved` on the main thread. It only arrives
    /// while Passing is running; coming back to Passing checks `lastCaptureAt` instead.
    static func startObserving() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: WidgetActivity.pinSaved, object: nil)
                }
            },
            savedName,
            nil,
            .deliverImmediately
        )
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
