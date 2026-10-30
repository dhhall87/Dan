import Foundation
import HomeKit
import Observation

/// The main screen's state, and every change Sunrise makes to Home.
@MainActor
@Observable
final class SunriseModel {
    enum Job: Equatable {
        case saving(done: Int, total: Int)
        case switching
        case removing
        case previewing
    }

    struct Problem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Saved by the main screen whenever it changes.
    var settings = SunriseSettings.load()
    private(set) var install = HomeInstall.load()
    private(set) var job: Job?
    var problem: Problem?

    let home = HomeStore()
    let location = LocationService()

    @ObservationIgnored private var previewTask: Task<Void, Never>?

    var savingProgress: (done: Int, total: Int)? {
        guard case .saving(let done, let total) = job else { return nil }
        return (done, total)
    }

    // MARK: Reading Home

    /// The home in the settings, or the primary home until Dan picks one.
    var selectedHome: HMHome? {
        let homes = home.homes
        return homes.first { $0.uniqueIdentifier == settings.homeID }
            ?? homes.first(where: \.isPrimary)
            ?? homes.first
    }

    var lightOptions: [LightOption] {
        _ = home.revision
        guard let selectedHome else { return [] }
        return HomeLights.options(in: selectedHome)
    }

    var homeState: HomeState {
        _ = home.revision
        return HomeSchedule.state(of: install, in: home.home(withID: install?.homeID) ?? selectedHome)
    }

    var hubState: HMHomeHubState? {
        _ = home.revision
        return selectedHome?.homeHubState
    }

    /// True when Home has a sunrise that no longer matches the screen.
    var hasUnsavedChanges: Bool {
        guard let install else { return false }
        var current = settings
        current.homeID = selectedHome?.uniqueIdentifier
        return current.homeShape != install.settings.homeShape
    }

    /// Every chosen light that's still in the selected home.
    var chosenLightCount: Int {
        let available = Set(lightOptions.map(\.id))
        return settings.lightIDs.intersection(available).count
    }

    /// Keeps the chosen home in the settings once homes have loaded.
    func homesLoaded() {
        guard let selectedHome, settings.homeID != selectedHome.uniqueIdentifier else { return }
        settings.homeID = selectedHome.uniqueIdentifier
    }

    // MARK: Changing Home

    func saveToHome() async {
        guard job == nil, let target = selectedHome else { return }
        let lights = HomeLights.targets(in: target, ids: settings.lightIDs)
        guard !lights.isEmpty else {
            problem = Problem(title: "Pick a light", message: "Choose at least one light for the sunrise.")
            return
        }
        var toSave = settings
        toSave.homeID = target.uniqueIdentifier
        job = .saving(done: 0, total: toSave.steps.count)
        defer {
            job = nil
            home.refresh()
        }
        do {
            // A sunrise saved in another home comes out of that one first.
            if let previous = install, previous.homeID != target.uniqueIdentifier, let oldHome = home.home(withID: previous.homeID) {
                try await HomeSchedule.removeAll(from: oldHome, install: previous)
                setInstall(nil)
            }
            let saved = try await HomeSchedule.install(toSave, replacing: install, lights: lights, in: target) { done, total in
                self.job = .saving(done: done, total: total)
            }
            setInstall(saved)
            settings.homeID = target.uniqueIdentifier
        } catch {
            // The old sunrise comes out before the new one goes in, and a new one that fails is
            // rolled back. Anything left over shows as needing a rebuild.
            setInstall(nil)
            problem = Problem(
                title: "Couldn't save to Home",
                message: "\(error.localizedDescription)\n\nCheck that your home hub is on, then save again."
            )
        }
    }

    func setSunriseOn(_ on: Bool) async {
        guard job == nil, let install, let target = home.home(withID: install.homeID) else { return }
        job = .switching
        defer {
            job = nil
            home.refresh()
        }
        do {
            try await HomeSchedule.setEnabled(on, install: install, in: target)
        } catch {
            problem = Problem(title: on ? "Couldn't turn the sunrise on" : "Couldn't turn the sunrise off", message: error.localizedDescription)
        }
    }

    func removeFromHome() async {
        guard job == nil, let target = home.home(withID: install?.homeID) ?? selectedHome else { return }
        job = .removing
        defer {
            job = nil
            home.refresh()
        }
        do {
            try await HomeSchedule.removeAll(from: target, install: install)
            setInstall(nil)
        } catch {
            problem = Problem(title: "Couldn't remove the sunrise", message: error.localizedDescription)
        }
    }

    // MARK: Try it now

    func startPreview() {
        guard job == nil, let target = selectedHome else { return }
        let lights = HomeLights.targets(in: target, ids: settings.lightIDs)
        guard !lights.isEmpty else {
            problem = Problem(title: "Pick a light", message: "Choose at least one light to try the sunrise on.")
            return
        }
        let snapshot = settings
        job = .previewing
        previewTask = Task {
            let failed = await SunrisePreview.play(snapshot, on: lights)
            job = nil
            report(failed: failed)
        }
    }

    func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
    }

    func turnLightsOff() async {
        guard let target = selectedHome else { return }
        // Let a running preview stop first, so its last step can't turn the lights back on.
        if let previewTask {
            previewTask.cancel()
            await previewTask.value
        }
        let failed = await SunrisePreview.turnOff(HomeLights.targets(in: target, ids: settings.lightIDs))
        report(failed: failed)
    }

    private func report(failed: Set<String>) {
        guard !failed.isEmpty else { return }
        problem = Problem(
            title: "Some lights didn't respond",
            message: "\(failed.sorted().joined(separator: ", ")) didn't respond. Check they're on at the switch and show up in the Home app."
        )
    }

    private func setInstall(_ newValue: HomeInstall?) {
        install = newValue
        HomeInstall.save(newValue)
    }
}
