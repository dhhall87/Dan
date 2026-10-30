import HomeKit
import SwiftUI

/// Which home, and which of its lights take part.
struct LightsCard: View {
    @Environment(SunriseModel.self) private var model

    var body: some View {
        let options = model.lightOptions
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lights")
                    .font(.headline)
                Spacer()
                HomeMenu()
            }
            if options.isEmpty {
                Text("No dimmable lights in \(model.selectedHome?.name ?? "this home"). Add them in Apple's Home app, then come back.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(options) { light in
                    LightRow(light: light, isOn: model.settings.lightIDs.contains(light.id)) {
                        toggle(light.id)
                    }
                }
            }
        }
        .card()
    }

    private func toggle(_ id: UUID) {
        if model.settings.lightIDs.contains(id) {
            model.settings.lightIDs.remove(id)
        } else {
            model.settings.lightIDs.insert(id)
        }
    }
}

/// The home's name, and a menu to pick another when there's more than one.
private struct HomeMenu: View {
    @Environment(SunriseModel.self) private var model

    var body: some View {
        let homes = model.home.homes
        let name = model.selectedHome?.name ?? ""
        if homes.count > 1 {
            Menu {
                ForEach(homes, id: \.uniqueIdentifier) { home in
                    Button(home.name) { model.settings.homeID = home.uniqueIdentifier }
                }
            } label: {
                Label(name, systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
            }
        } else {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LightRow: View {
    let light: LightOption
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(light.name)
                        .foregroundStyle(.primary)
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(light.isReachable ? Color.secondary : Color.orange)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var details: String {
        var parts = [light.capabilities.kind]
        if let room = light.room { parts.insert(room, at: 0) }
        if !light.isReachable { parts.append("Not responding") }
        return parts.joined(separator: " · ")
    }
}
