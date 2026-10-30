import HomeKit

/// A light Dan can pick: one HomeKit accessory with at least one dimmable lightbulb.
struct LightOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    let room: String?
    let isReachable: Bool
    let capabilities: LightCapabilities
}

/// One lightbulb service and the characteristics Sunrise writes to it.
struct LightTarget {
    let name: String
    let power: HMCharacteristic?
    let brightness: HMCharacteristic?
    let mireds: HMCharacteristic?
    let hue: HMCharacteristic?
    let saturation: HMCharacteristic?

    init(service: HMService) {
        func find(_ type: String) -> HMCharacteristic? {
            service.characteristics.first { $0.characteristicType == type }
        }
        name = service.accessory?.name ?? service.name
        power = find(HMCharacteristicTypePowerState)
        brightness = find(HMCharacteristicTypeBrightness)
        mireds = find(HMCharacteristicTypeColorTemperature)
        hue = find(HMCharacteristicTypeHue)
        saturation = find(HMCharacteristicTypeSaturation)
    }

    var capabilities: LightCapabilities {
        LightCapabilities(
            brightness: brightness.map { Self.range(of: $0, default: 0...100) },
            mireds: mireds.map { Self.range(of: $0, default: 140...500) },
            hueAndSaturation: hue != nil && saturation != nil
        )
    }

    /// The characteristic and value for one write, or nil if this light can't take it.
    /// Values use the characteristic's own type: Bool for power, whole numbers for brightness
    /// and mireds, and floating point for hue and saturation.
    func change(for write: LightWrite) -> (characteristic: HMCharacteristic, value: NSNumber)? {
        let target: HMCharacteristic?
        let value: NSNumber
        switch write {
        case .power(let on):
            target = power
            value = NSNumber(value: on)
        case .brightness(let percent):
            target = brightness
            value = NSNumber(value: percent)
        case .mireds(let mireds):
            target = self.mireds
            value = NSNumber(value: mireds)
        case .hue(let degrees):
            target = hue
            value = NSNumber(value: degrees)
        case .saturation(let percent):
            target = saturation
            value = NSNumber(value: percent)
        }
        guard let target else { return nil }
        return (target, value)
    }

    private static func range(of characteristic: HMCharacteristic, default fallback: ClosedRange<Int>) -> ClosedRange<Int> {
        let low = characteristic.metadata?.minimumValue?.intValue ?? fallback.lowerBound
        let high = characteristic.metadata?.maximumValue?.intValue ?? fallback.upperBound
        return low <= high ? low...high : fallback
    }
}

enum HomeLights {
    /// Lights that can dim, sorted by room then name. On/off-only lights are left out: a
    /// sunrise needs dimming, and their prep scene would have nothing in it.
    static func options(in home: HMHome) -> [LightOption] {
        home.accessories.compactMap { accessory -> LightOption? in
            let lights = dimmableLights(of: accessory)
            guard let first = lights.first else { return nil }
            return LightOption(
                id: accessory.uniqueIdentifier,
                name: accessory.name,
                room: accessory.room?.name,
                isReachable: accessory.isReachable,
                capabilities: LightTarget(service: first).capabilities
            )
        }
        .sorted { ($0.room ?? "", $0.name) < ($1.room ?? "", $1.name) }
    }

    /// Every dimmable lightbulb of the chosen accessories.
    static func targets(in home: HMHome, ids: Set<UUID>) -> [LightTarget] {
        home.accessories
            .filter { ids.contains($0.uniqueIdentifier) }
            .flatMap { dimmableLights(of: $0) }
            .map { LightTarget(service: $0) }
    }

    private static func dimmableLights(of accessory: HMAccessory) -> [HMService] {
        accessory.services.filter { service in
            service.serviceType == HMServiceTypeLightbulb
                && service.characteristics.contains { $0.characteristicType == HMCharacteristicTypeBrightness }
        }
    }
}
