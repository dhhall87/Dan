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
        // Pins saved from a widget or Control Center while Passing is open show up in Pins straight away.
        WidgetActivity.startObserving()
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
    /// Kept here rather than in the Pins list, so rebuilding the list for a widget pin keeps what
    /// it was showing.
    @State private var listFilter: GroupFilter = .all
    /// True while the list has something open that a rebuild would close (Select, a sheet, an
    /// alert, the map), so the refresh waits.
    @State private var listBusy = false
    private let feedback = CaptureFeedback.shared
    private let reviewRoute = ReviewRoute.shared

    var body: some View {
        NavigationStack(path: $path) {
            CaptureView(mode: modeChoice.mode(default: defaultMode), isCovered: showingSettings) {
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
                            listFilter = .all
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
                    case .pins, .needsReview:
                        PinListView(filter: $listFilter, holdsRefresh: $listBusy).id(listRefresh)
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
            listFilter = .needsReview
            path = NavigationPath()
            path.append(Route.needsReview)
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetActivity.pinSaved)) { _ in
            refreshIfWidgetSaved()
        }
        .onChange(of: listBusy) {
            // A widget pin that arrived during Select (or with a sheet open) shows up once it's done.
            if !listBusy {
                refreshIfWidgetSaved()
            }
        }
        .onChange(of: path.count) {
            // Or once the pin opened on top of the list is closed.
            refreshIfWidgetSaved()
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
        guard latest != seenWidgetCapture, listCanRebuild else { return }
        seenWidgetCapture = latest
        listRefresh += 1
    }

    /// Rebuilding the list closes whatever is open in it, so it waits while the list is busy or has
    /// a pin (or Recently Deleted) open on top. With the list closed there's nothing to interrupt.
    private var listCanRebuild: Bool {
        path.isEmpty || (path.count == 1 && !listBusy)
    }
}

