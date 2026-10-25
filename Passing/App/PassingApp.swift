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

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            CaptureView()
                .navigationTitle("Passing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            PinListView()
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
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                RetentionService.shared.run()
            case .background:
                RetentionScheduler.schedule()
            default:
                break
            }
        }
    }
}
