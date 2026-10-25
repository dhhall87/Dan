import AppIntents
import CoreLocation
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.mode) private var mode: PinMode = .zones
    @AppStorage(SettingsKey.askWhatToLookUp) private var askWhatToLookUp = true
    @AppStorage(SettingsKey.speakConfirmation) private var speakConfirmation = true
    @AppStorage(SettingsKey.keepForever) private var keepForever = false
    @AppStorage(SettingsKey.preferredMaps) private var preferredMaps: MapsApp = .apple
    @State private var confirmingDeleteAll = false

    private let tracker = LocationTracker.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Layout", selection: $mode) {
                        ForEach(PinMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Drive screen")
                } footer: {
                    Text(mode == .zones
                         ? "Tap left or right of the car. The inside columns are for things right by the road, the outside columns for things farther away."
                         : "Tap anywhere on the screen to drop a pin.")
                }

                Section {
                    Toggle("Ask “What do you want to look up?”", isOn: $askWhatToLookUp)
                    Toggle("Speak confirmations", isOn: $speakConfirmation)
                } header: {
                    Text("Voice")
                } footer: {
                    Text("After you tap, RoadPin asks what you want to look up and listens for a few seconds. Apple doesn't let apps use the microphone while CarPlay is connected, so in the car, add notes with Siri instead.")
                }

                Section {
                    SiriTipView(intent: DropPinIntent())
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“Hey Siri, drop a RoadPin”")
                        Text("“Hey Siri, I missed something in RoadPin”")
                        Text("“Hey Siri, name my last RoadPin”")
                    }
                    .font(.callout)
                    ShortcutsLink()
                } header: {
                    Text("Siri")
                } footer: {
                    Text("Siri works from your car's voice button, AirPods, or the Action Button. Siri asks what you want to look up, so you never touch the screen.")
                }

                Section {
                    Toggle("Keep pins forever", isOn: $keepForever)
                } header: {
                    Text("Keeping pins")
                } footer: {
                    Text(keepForever
                         ? "Pins stay until you delete them."
                         : "Pins are deleted 7 days after you drop them. Starred pins are always kept.")
                }

                Section("Maps") {
                    Picker("Open pins in", selection: $preferredMaps) {
                        ForEach(MapsApp.allCases) { app in
                            Text(app.title).tag(app)
                        }
                    }
                }

                Section {
                    LabeledContent("Location access", value: locationStatus)
                    if tracker.authorization == .authorizedWhenInUse {
                        Button("Let Siri save pins while RoadPin is closed") {
                            tracker.requestAlwaysAuthorization()
                        }
                    }
                    if tracker.authorization != .notDetermined {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("RoadPin only uses your location while it's open or in CarPlay, unless you allow it all the time for Siri. Your pins stay on this iPhone.")
                }

                Section {
                    Button("Delete All Pins", role: .destructive) {
                        confirmingDeleteAll = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all pins?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All Pins", role: .destructive) {
                    PinStore.deleteAll()
                }
            } message: {
                Text("This also deletes starred pins.")
            }
        }
    }

    private var locationStatus: String {
        switch tracker.authorization {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While using RoadPin"
        case .denied, .restricted: return "Off"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
