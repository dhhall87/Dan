import CoreLocation
import SwiftUI
import UIKit

/// Settings → Advanced (2.0): the switches that are set once, if ever, moved off the main Settings
/// screen to keep it short.
struct AdvancedSettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @AppStorage(SettingsKey.deleteAfterExport) private var deleteAfterExport = false
    @AppStorage(DriveLog.enabledKey, store: AppGroup.defaults) private var driveLogOn = false
    #if DEBUG
    @AppStorage(SettingsKey.debugDayOffset) private var debugDayOffset = 0
    #endif

    private let location = LocationProvider.shared

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your iPhone's Light or Dark setting. The capture screen always stays dark, so it's never bright on the dash at night.")
            }

            Section {
                Toggle("Delete pins after exporting", isOn: $deleteAfterExport)
            } header: {
                Text("Exports")
            } footer: {
                Text("After you share an export from Pins, the pins in it move to Recently Deleted, except kept ones. Cancelling the share keeps them. Exports never include speed, and Passing deletes its own copy of the file afterwards. Backups (Back Up and Restore) never delete anything.")
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
                Text("Passing uses your location while the capture screen is open, and for a few seconds when you pin from Siri, a widget or Control Center. Passing on Apple Watch uses the watch's own location while it's open. It never tracks you in the background.")
            }

            Section {
                NavigationLink(value: SettingsRoute.driveLog) {
                    LabeledContent("Drive Log", value: driveLogOn ? "On" : "Off")
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("A record of how Passing does on real drives: how long GPS takes, how accurate pins are, whether they saved. No locations, names, notes or speeds. Stays on this iPhone until you share it.")
            }

            #if DEBUG
            Section {
                Stepper("Clock: +\(debugDayOffset) \(debugDayOffset == 1 ? "day" : "days")", value: $debugDayOffset, in: 0...60)
                LabeledContent("Trail recorded", value: Geo.milesText(location.breadcrumbs.length / Geo.metersPerMile))
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
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var locationStatus: String {
        switch location.authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            return location.isPreciseLocationOff ? "While using Passing (not precise)" : "While using Passing"
        case .denied, .restricted: return "Off"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
