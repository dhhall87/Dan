import Foundation

/// Notes the widget extension leaves in the App Group's shared settings: the widget's note after a
/// tap (shown on the button only when something went wrong), and the time of the last widget or
/// Control Center pin, so the app knows to refresh its list.
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
    /// `state` decides the button's face: "Not saved" if the pin isn't on disk, and "No location"
    /// if its position arrived but couldn't be written.
    /// - Returns: the widget's note for this pin (nil for Control Center).
    @MainActor
    @discardableResult
    static func record(_ pin: Pin, state: CaptureService.SaveState = .saved, now: Date = .now) -> WidgetSavedNote? {
        guard let defaults = AppGroup.defaults else { return nil }
        defaults.set(now, forKey: lastCaptureKey)
        var note: WidgetSavedNote?
        if pin.source == .widget {
            let made = WidgetSavedNote(
                savedAt: now, side: pin.side, distance: pin.distance,
                hasLocation: pin.hasLocation && state == .saved, saved: state != .notSaved
            )
            if let data = try? JSONEncoder().encode(made) {
                defaults.set(data, forKey: noteKey)
            }
            note = made
        }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(savedName), nil, nil, true)
        return note
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
