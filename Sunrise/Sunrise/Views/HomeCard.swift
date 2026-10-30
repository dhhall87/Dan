import HomeKit
import SwiftUI

/// Saving to Home, switching the sunrise on and off, and trying it out.
struct HomeCard: View {
    @Environment(SunriseModel.self) private var model
    @State private var confirmingRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Home")
                .font(.headline)
            HubStatus(state: model.hubState)
            SaveSection()
            Divider()
            PreviewButtons()
            if model.homeState != .notSaved {
                Button("Remove from Home", role: .destructive) {
                    confirmingRemove = true
                }
                .font(.subheadline)
                .disabled(model.job != nil)
            }
            Text("Sunrise adds its steps to Apple's Home as scenes and automations named “Sunrise App Step …”. Leave them there: Sunrise replaces them each time you save.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
        .confirmationDialog("Remove the sunrise from Home?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove from Home", role: .destructive) {
                Task { await model.removeFromHome() }
            }
        } message: {
            Text("Its scenes and automations come out of the Home app. Your settings here stay.")
        }
    }
}

private struct HubStatus: View {
    let state: HMHomeHubState?

    var body: some View {
        Label {
            Text(message)
                .font(.footnote)
        } icon: {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? Color.green : Color.orange)
        }
    }

    private var isReady: Bool { state == .connected }

    private var message: String {
        switch state {
        case .connected:
            "Your home hub runs the sunrise, even while your iPhone sleeps."
        case .disconnected:
            "Your home hub isn't responding right now. It needs to be on for the sunrise to run."
        default:
            "This home has no home hub. A HomePod or Apple TV set up as a home hub runs automations on schedule."
        }
    }
}

/// Save, Update, Rebuild, or the on/off switch, depending on what's in Home.
private struct SaveSection: View {
    @Environment(SunriseModel.self) private var model

    var body: some View {
        let state = model.homeState
        let steps = model.settings.steps.count
        VStack(alignment: .leading, spacing: 8) {
            if state == .notSaved {
                SaveButton(title: "Save to Home")
                Note("Adds the sunrise to Home as \(steps) scenes and automations, so it runs every chosen day without Sunrise open.")
            } else if state == .damaged {
                SaveButton(title: "Rebuild in Home")
                Note("Some of the sunrise's steps are missing or switched off in Home. Saving again puts it right.")
            } else if model.hasUnsavedChanges {
                SaveButton(title: "Update Home")
                Note("Your changes aren't in Home yet.")
            } else {
                Toggle("Sunrise on", isOn: onBinding(state))
                    .disabled(model.job != nil)
                Note(state == .on ? "Saved in Home." : "Saved in Home, switched off.")
            }
            if model.chosenLightCount == 0 {
                Note("Choose at least one light above.")
            }
        }
    }

    private func onBinding(_ state: HomeState) -> Binding<Bool> {
        Binding(
            get: { state == .on },
            set: { on in
                Task { await model.setSunriseOn(on) }
            }
        )
    }
}

private struct SaveButton: View {
    let title: String
    @Environment(SunriseModel.self) private var model

    var body: some View {
        Button {
            Task { await model.saveToHome() }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.job != nil || model.chosenLightCount == 0)
    }
}

private struct PreviewButtons: View {
    @Environment(SunriseModel.self) private var model

    var body: some View {
        let previewing = model.job == .previewing
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    if previewing { model.stopPreview() } else { model.startPreview() }
                } label: {
                    Label(previewing ? "Stop" : "Try it now", systemImage: previewing ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .disabled(model.chosenLightCount == 0 || (model.job != nil && !previewing))
                Button {
                    Task { await model.turnLightsOff() }
                } label: {
                    Label("Lights off", systemImage: "lightbulb.slash")
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .disabled(model.chosenLightCount == 0 || (model.job != nil && !previewing))
            }
            .buttonStyle(.bordered)
            Note("Try it now plays the whole sunrise in about 45 seconds, straight from your iPhone.")
        }
    }
}

private struct Note: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
