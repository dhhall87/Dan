import CoreLocation
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.captureMode) private var mode: CaptureMode = .quick
    @AppStorage(SettingsKey.confirmationTone) private var confirmationTone = true
    @AppStorage(SettingsKey.spokenConfirmation) private var spokenConfirmation = false
    @AppStorage(SettingsKey.keepIndefinitely) private var keepIndefinitely = false
    #if DEBUG
    @AppStorage(SettingsKey.debugDayOffset) private var debugDayOffset = 0
    #endif

    private let location = LocationProvider.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Capture screen", selection: $mode) {
                        ForEach(CaptureMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Capture screen")
                } footer: {
                    Text(mode == .quick
                         ? "The whole screen is one button."
                         : "Tap the side of the road the thing was on. Inner columns are right by the road, outer columns are farther away. Tap the car if you're not sure which side.")
                }

                Section {
                    Toggle("Confirmation tone", isOn: $confirmationTone)
                    Toggle("Spoken confirmation", isOn: $spokenConfirmation)
                } header: {
                    Text("Confirmation")
                } footer: {
                    Text("Every pin gets a haptic. The tone plays even with the ring switch on silent. Spoken confirmation says things like “Left, far, saved.”")
                }

                Section {
                    Toggle("Keep records indefinitely", isOn: $keepIndefinitely)
                } header: {
                    Text("Keeping pins")
                } footer: {
                    Text(keepIndefinitely
                         ? "Pins stay until you delete them. Recently Deleted still empties itself after 30 days."
                         : "Pins move to Recently Deleted 7 days after you pin them, unless you keep (star) them. Recently Deleted empties itself after 30 days.")
                }

                Section {
                    LabeledContent("Location access", value: locationStatus)
                    if location.authorization != .notDetermined {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Passing uses your location only while the capture screen is open. It asks the first time you pin something. Pins stay on this iPhone.")
                }

                #if DEBUG
                Section {
                    Stepper("Clock: +\(debugDayOffset) \(debugDayOffset == 1 ? "day" : "days")", value: $debugDayOffset, in: 0...60)
                    LabeledContent("Pretend it's", value: AppClock.now.formatted(date: .abbreviated, time: .shortened))
                    Button("Run clean-up now") {
                        RetentionService.shared.run()
                    }
                } header: {
                    Text("Testing (debug builds only)")
                } footer: {
                    Text("Moves the clock that expiry and Recently Deleted use, so you can test the 7- and 30-day rules without waiting. Set it back to 0 when you're done. This section isn't in App Store builds.")
                }
                #endif

                if !SharedStore.isUsingAppGroup {
                    Section {
                        Label("The App Group isn't set up, so pins are stored in the app's own space. Siri and widgets (later milestones) won't see them. See “Set up the App Group” in the README.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } header: {
                        Text("Storage")
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
        }
    }

    private var locationStatus: String {
        switch location.authorization {
        case .authorizedAlways, .authorizedWhenInUse: return "While using Passing"
        case .denied, .restricted: return "Off"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
