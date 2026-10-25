import CoreLocation
import Foundation
import UserNotifications

/// Passing's own review reminders: local notifications that iOS delivers at a set time, or when you
/// arrive at a saved place. Nothing is tracked: iOS watches for the arrival itself, under the
/// "While Using" location permission Passing already has, and Passing doesn't need to be running.
/// Armed only when a widget or Control Center pin is saved, and cancelled once Needs Review is empty.
@MainActor
enum ReviewReminders {
    /// Set when iOS refused a reminder the widget tried to arm, so the app arms it next time it opens.
    static let retryKey = "reviewRemindersRetry"

    static var settings: ReviewReminderSettings {
        get { ReviewReminderSettings.load(from: AppGroup.defaults) }
        set { newValue.save(to: AppGroup.defaults) }
    }

    /// Arms the reminders for the pins now waiting, replacing any armed earlier. Does nothing when
    /// reminders are off or nothing is waiting.
    static func arm(waiting count: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ReviewReminderSettings.allIDs)
        let planned = settings.planned
        guard count > 0, !planned.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Passing"
        content.body = ReviewReminderSettings.message(waiting: count)
        content.sound = .default
        let retryKey = retryKey
        for reminder in planned {
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger(for: reminder.trigger))
            center.add(request) { error in
                if error != nil {
                    AppGroup.defaults?.set(true, forKey: retryKey)
                }
            }
        }
    }

    /// Removes waiting and already-shown reminders. Called once Needs Review is empty, or when
    /// reminders are turned off.
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ReviewReminderSettings.allIDs)
        center.removeDeliveredNotifications(withIdentifiers: ReviewReminderSettings.allIDs)
    }

    /// Asks for notification permission (only from Settings). True if Passing may notify.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private static func trigger(for trigger: ReviewReminderSettings.Trigger) -> UNNotificationTrigger {
        switch trigger {
        case .time(let hour, let minute):
            // The next time the clock shows this time: tomorrow morning for an evening drive.
            return UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: false)
        case .arrival(let place):
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                radius: 150,
                identifier: place.name
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            return UNLocationNotificationTrigger(region: region, repeats: false)
        }
    }
}
