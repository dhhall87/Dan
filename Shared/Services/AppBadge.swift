import Foundation
import UserNotifications

/// The number on Passing's icon: how many pins still have no name (2.0, Dan's request, as a nudge
/// to look them up). Off until turned on in Settings → Review Reminders, because iOS only shows a
/// badge once notifications are allowed. Stored in the App Group's settings so the widget follows it.
enum AppBadge {
    static let enabledKey = "appIconBadge"

    static var isOn: Bool {
        AppGroup.defaults?.bool(forKey: enabledKey) ?? false
    }

    /// Shows `count` on the icon, or clears it when the badge is off.
    static func update(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(isOn ? max(count, 0) : 0) { error in
            if let error {
                print("Passing: couldn't set the icon badge: \(error)")
            }
        }
    }
}
