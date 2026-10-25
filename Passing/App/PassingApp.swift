import SwiftData
import SwiftUI

@main
struct PassingApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
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
    case recentlyDeleted
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var showingSettings = false
    /// Bumped to rebuild the pin list after the widget or Control Center saved pins.
    @State private var listRefresh = 0
    @State private var seenWidgetCapture = WidgetActivity.lastCaptureAt
    private let feedback = CaptureFeedback.shared

    var body: some View {
        NavigationStack(path: $path) {
            CaptureView()
                .navigationTitle("Passing")
                .navigationBarTitleDisplayMode(.inline)
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
                    if feedback.isListening {
                        // Listen after tap: turn the microphone off now. It sits in the title bar so
                        // it never moves or covers the capture buttons, and it never has to be used:
                        // listening stops by itself after a few seconds.
                        ToolbarItem(placement: .principal) {
                            Button {
                                feedback.stopListening()
                            } label: {
                                Label("Stop listening", systemImage: "mic.slash.fill")
                                    .labelStyle(.titleAndIcon)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .pins: PinListView().id(listRefresh)
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
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                RetentionService.shared.run()
                refreshIfWidgetSaved()
            case .background:
                RetentionScheduler.schedule()
            default:
                break
            }
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
