import SwiftData
import SwiftUI

@main
struct RoadPinApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(PinStore.container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.askWhatToLookUp) private var askWhatToLookUp = true
    @State private var showingSettings = false

    private let tracker = LocationTracker.shared

    var body: some View {
        NavigationStack {
            DriveView()
                .navigationTitle("RoadPin")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            PinsListView()
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
            guard phase == .active else { return }
            PinStore.purgeExpired()
            tracker.start()
            requestVoicePermissionsIfNeeded()
        }
        .onChange(of: tracker.authorization) { _, _ in
            requestVoicePermissionsIfNeeded()
        }
    }

    /// Ask for microphone and speech access right after the location prompt (ideally while parked),
    /// rather than the first time you tap while driving.
    private func requestVoicePermissionsIfNeeded() {
        guard askWhatToLookUp, tracker.authorization != .notDetermined else { return }
        Task { _ = await VoicePrompter.shared.requestPermissions() }
    }
}
