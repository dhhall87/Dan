import Observation
import UserNotifications

/// Set when a review reminder is tapped; RootView then opens Pins on Needs Review.
@MainActor
@Observable
final class ReviewRoute {
    static let shared = ReviewRoute()
    var openNeedsReview = false
}

/// Handles review reminders for the app: a tap opens Needs Review, and a reminder that arrives
/// while Passing is open goes quietly into Notification Center, with no banner or sound, because
/// nothing may pop up over the capture screen.
@MainActor
final class ReviewReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReviewReminderDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard ReviewReminderSettings.allIDs.contains(response.notification.request.identifier) else { return }
        await MainActor.run {
            ReviewRoute.shared.openNeedsReview = true
        }
    }
}
