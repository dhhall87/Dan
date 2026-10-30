import HomeKit

/// "Try it now": plays the whole sunrise on the chosen lights in about 45 seconds. Unlike the
/// real one, it's written straight from the iPhone, so it only runs while Sunrise is open.
@MainActor
enum SunrisePreview {
    static let pause: Duration = .milliseconds(2500)

    /// Returns the names of lights that didn't respond. Stops early if the task is cancelled.
    static func play(_ settings: SunriseSettings, on lights: [LightTarget]) async -> Set<String> {
        var failed: Set<String> = []
        let steps = settings.steps
        for (index, step) in steps.enumerated() {
            if Task.isCancelled { break }
            for light in lights where !failed.contains(light.name) {
                // In order, brightness and color first, so a light that's off comes on at the new level.
                for write in LightWrites.writes(for: step.level, turnOn: step.turnsOn, capabilities: light.capabilities) {
                    guard !Task.isCancelled else { return failed }
                    guard let change = light.change(for: write) else { continue }
                    do {
                        try await change.characteristic.writeValue(change.value)
                    } catch {
                        failed.insert(light.name)
                        break
                    }
                }
            }
            if index < steps.count - 1 {
                try? await Task.sleep(for: pause)
            }
        }
        return failed
    }

    static func turnOff(_ lights: [LightTarget]) async -> Set<String> {
        var failed: Set<String> = []
        for light in lights {
            guard let power = light.power else { continue }
            do {
                try await power.writeValue(NSNumber(value: false))
            } catch {
                failed.insert(light.name)
            }
        }
        return failed
    }
}
