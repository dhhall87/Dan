import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct PassingApp: App {
    init() {
        // An export left behind if the app was closed while sharing it.
        ExportService.removeExportedFiles()
        // Set before launch finishes, so tapping a review reminder that launched Passing is handled.
        UNUserNotificationCenter.current().delegate = ReviewReminderDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedStore.container)
        .backgroundTask(.appRefresh(RetentionScheduler.taskIdentifier)) {
            await RetentionScheduler.handleAppRefresh()
        }
    }
}

/// Screens pushed on the navigation stack. Using values (instead of building the next screen
/// inside the current one) means a screen is only created when it opens. Building Recently Deleted
/// inside the Pins list made the two feed back into each other and froze the app.
enum Route: Hashable {
    case pins
    /// The Pins list showing Needs Review (where review reminders lead).
    case needsReview
    case recentlyDeleted
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var showingSettings = false
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    /// The layout Passing opens with. The title button switches away from it for the drive.
    @AppStorage(SettingsKey.captureMode) private var defaultMode: CaptureMode = .quick
    @State private var modeChoice = CaptureModeChoice()
    /// Bumped to rebuild the pin list after the widget or Control Center saved pins.
    @State private var listRefresh = 0
    @State private var seenWidgetCapture = WidgetActivity.lastCaptureAt
    private let feedback = CaptureFeedback.shared
    private let reviewRoute = ReviewRoute.shared

    var body: some View {
        NavigationStack(path: $path) {
            CaptureView(mode: modeChoice.mode(default: defaultMode)) {
                modeChoice.toggle(default: defaultMode)
                UISelectionFeedbackGenerator().selectionChanged()
            }
                // Shown as the back button's name; the visible title is the mode button on the screen.
                .navigationTitle("Passing")
                .navigationBarTitleDisplayMode(.inline)
                // The capture screen is dark and high-contrast in every appearance, so it's never a
                // bright screen on the dash at night. Its title bar matches.
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(Color.captureBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            path.append(Route.pins)
                        } label: {
                            Label("Pins", systemImage: "list.bullet")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        // Hidden while listening: the big Stop listening button below takes the
                        // title's place, so the eye goes to one thing.
                        if !feedback.isListening {
                            GPSPill()
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .pins: PinListView().id(listRefresh)
                    case .needsReview: PinListView(filter: .needsReview).id(listRefresh)
                    case .recentlyDeleted: RecentlyDeletedView()
                    }
                }
                .navigationDestination(for: Pin.self) { pin in
                    PinDetailView(pin: pin)
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: appearance, initial: true) {
            appearance.apply()
        }
        .onChange(of: defaultMode) {
            modeChoice.defaultChanged()
        }
        .onChange(of: reviewRoute.openNeedsReview, initial: true) {
            // A review reminder was tapped: go straight to Needs Review.
            guard reviewRoute.openNeedsReview else { return }
            reviewRoute.openNeedsReview = false
            showingSettings = false
            path = NavigationPath()
            path.append(Route.needsReview)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                // Again here, in case the window didn't exist yet when the setting was first applied.
                appearance.apply()
                modeChoice.cameBack(at: .now)
                RetentionService.shared.run()
                refreshIfWidgetSaved()
                updateReviewReminders()
            case .background:
                modeChoice.wentToBackground(at: .now)
                RetentionScheduler.schedule()
                updateReviewReminders()
            default:
                break
            }
        }
    }

    /// Cancels review reminders once Needs Review is empty, and arms them here if iOS refused them
    /// when the widget tried.
    private func updateReviewReminders() {
        let waiting = CaptureService.shared.needsReviewCount()
        if waiting == 0 {
            ReviewReminders.cancel()
        } else if AppGroup.defaults?.bool(forKey: ReviewReminders.retryKey) == true {
            AppGroup.defaults?.set(false, forKey: ReviewReminders.retryKey)
            ReviewReminders.arm(waiting: waiting)
        }
    }

    /// The widget and Control Center save pins from their own process, and SwiftData's queries don't
    /// reliably notice changes saved by another process. Rebuild the list when they've saved since we last looked.
    private func refreshIfWidgetSaved() {
        let latest = WidgetActivity.lastCaptureAt
        guard latest != seenWidgetCapture else { return }
        seenWidgetCapture = latest
        listRefresh += 1
    }
}

