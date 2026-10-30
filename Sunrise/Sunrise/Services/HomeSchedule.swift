import HomeKit

/// Whether the sunrise Sunrise saved is in Home and switched on.
enum HomeState: Equatable {
    case notSaved
    case on
    case off
    /// Some of its scenes or automations are missing or switched off, or Home has steps that
    /// Sunrise has no record of.
    case damaged
}

/// Writes the sunrise into Apple's Home as one scene and one automation per step. The home hub
/// (HomePod or Apple TV) runs them, so the lights fade in while the iPhone sleeps and Sunrise
/// isn't open.
@MainActor
enum HomeSchedule {
    /// Replaces whatever Sunrise had in Home with the sunrise for `settings`. If anything fails,
    /// the half-built sunrise is taken out again, so Home never runs part of one, and nothing of
    /// Sunrise's is left in Home.
    static func install(
        _ settings: SunriseSettings,
        replacing previous: HomeInstall?,
        lights: [LightTarget],
        in home: HMHome,
        progress: (_ done: Int, _ total: Int) -> Void
    ) async throws -> HomeInstall {
        try await removeAll(from: home, install: previous)
        let steps = settings.steps
        var triggers: [HMTrigger] = []
        var actionSets: [HMActionSet] = []
        do {
            for (index, step) in steps.enumerated() {
                progress(index, steps.count)
                let actionSet = try await home.addActionSet(named: step.name)
                actionSets.append(actionSet)
                for light in lights {
                    for write in LightWrites.writes(for: step.level, turnOn: step.turnsOn, capabilities: light.capabilities) {
                        guard let change = light.change(for: write) else { continue }
                        let action = HMCharacteristicWriteAction(characteristic: change.characteristic, targetValue: change.value)
                        try await actionSet.addAction(action)
                    }
                }
                let trigger = makeTrigger(for: step, settings: settings)
                try await home.addTrigger(trigger)
                triggers.append(trigger)
                // A trigger can only be switched on once it's in the home with a scene that has actions.
                try await trigger.addActionSet(actionSet)
                try await trigger.enable(true)
            }
            progress(steps.count, steps.count)
        } catch {
            for trigger in triggers { try? await home.removeTrigger(trigger) }
            for actionSet in actionSets { try? await home.removeActionSet(actionSet) }
            throw error
        }
        return HomeInstall(
            homeID: home.uniqueIdentifier,
            triggerIDs: triggers.map(\.uniqueIdentifier),
            actionSetIDs: actionSets.map(\.uniqueIdentifier),
            settings: settings,
            savedAt: .now
        )
    }

    /// The automation for one step: a time of day, or an offset from sunrise, on the chosen days.
    static func makeTrigger(for step: SunriseStep, settings: SunriseSettings) -> HMEventTrigger {
        let event: HMEvent
        let recurrences: [DateComponents]
        switch settings.mode {
        case .fixedTime:
            let time = SunriseSchedule.clockTime(hour: settings.wakeHour, minute: settings.wakeMinute, offsetMinutes: step.offsetMinutes)
            event = HMCalendarEvent(fire: DateComponents(hour: time.hour, minute: time.minute))
            recurrences = SunriseSchedule.recurrences(days: settings.days, dayShift: time.dayShift)
        case .sunrise:
            event = HMSignificantTimeEvent(significantEvent: .sunrise, offset: SunriseSchedule.sunriseOffset(minutes: step.offsetMinutes))
            recurrences = SunriseSchedule.recurrences(days: settings.days, dayShift: 0)
        }
        return HMEventTrigger(name: step.name, events: [event], end: nil, recurrences: recurrences, predicate: nil)
    }

    /// Takes every Sunrise scene and automation out of `home`: the ones it recorded, and any
    /// with its step names (left by an earlier install whose record was lost). Automations go
    /// first, so no scene is removed while an automation still uses it.
    static func removeAll(from home: HMHome, install: HomeInstall? = nil) async throws {
        let triggerIDs = Set(install?.triggerIDs ?? [])
        let actionSetIDs = Set(install?.actionSetIDs ?? [])
        for trigger in home.triggers where triggerIDs.contains(trigger.uniqueIdentifier) || isSunriseName(trigger.name) {
            try await home.removeTrigger(trigger)
        }
        for actionSet in home.actionSets where actionSetIDs.contains(actionSet.uniqueIdentifier) || isSunriseName(actionSet.name) {
            try await home.removeActionSet(actionSet)
        }
    }

    static func setEnabled(_ enabled: Bool, install: HomeInstall, in home: HMHome) async throws {
        for trigger in home.triggers where install.triggerIDs.contains(trigger.uniqueIdentifier) && trigger.isEnabled != enabled {
            try await trigger.enable(enabled)
        }
    }

    static func state(of install: HomeInstall?, in home: HMHome?) -> HomeState {
        guard let home else { return .notSaved }
        guard let install, home.uniqueIdentifier == install.homeID else {
            // Steps with no record, left by a save that couldn't finish or a reinstall, still run.
            return home.triggers.contains(where: { isSunriseName($0.name) }) ? .damaged : .notSaved
        }
        let triggers = home.triggers.filter { install.triggerIDs.contains($0.uniqueIdentifier) }
        let actionSetCount = home.actionSets.filter { install.actionSetIDs.contains($0.uniqueIdentifier) }.count
        guard triggers.count == install.triggerIDs.count, actionSetCount == install.actionSetIDs.count else { return .damaged }
        if triggers.allSatisfy(\.isEnabled) { return .on }
        if triggers.allSatisfy({ !$0.isEnabled }) { return .off }
        return .damaged
    }

    nonisolated static func isSunriseName(_ name: String) -> Bool {
        guard name.hasPrefix(SunriseStep.namePrefix) else { return false }
        let number = name.dropFirst(SunriseStep.namePrefix.count)
        return !number.isEmpty && number.allSatisfy(\.isNumber)
    }
}
