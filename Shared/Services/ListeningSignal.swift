import Foundation

/// Lets a widget button (on the phone or in CarPlay) stop listen-after-tap, which runs in the app's
/// process. While it's listening, the app notes in the App Group's shared settings until when, so
/// the widgets can show a Stop button. That button sends a system-wide signal the app watches for.
enum ListeningSignal {
    private static let untilKey = "listeningUntil"
    /// The longest a listening session can run (question, listening and wrap-up), so a Stop button
    /// can't get stuck on a widget if the app is closed mid-session.
    static let maxSession: TimeInterval = 25

    /// Posted on the app's main thread when a widget asks it to stop listening.
    static let stopRequested = Notification.Name("PassingStopListening")

    private static var stopName: CFString {
        ((AppGroup.identifier ?? "Passing") + ".stopListening") as CFString
    }

    static func setListening(_ listening: Bool, now: Date = .now) {
        AppGroup.defaults?.set(listening ? now.addingTimeInterval(maxSession) : nil, forKey: untilKey)
    }

    /// Until when the app is listening, or nil if it isn't.
    static func listeningUntil(now: Date = .now) -> Date? {
        guard let until = AppGroup.defaults?.object(forKey: untilKey) as? Date, until > now else { return nil }
        return until
    }

    /// From the widget's Stop button.
    static func postStop() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(stopName), nil, nil, true)
    }

    /// In the app, once: turns the system-wide signal into `stopRequested` on the main thread.
    static func startObserving() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: ListeningSignal.stopRequested, object: nil)
                }
            },
            stopName,
            nil,
            .deliverImmediately
        )
    }
}
