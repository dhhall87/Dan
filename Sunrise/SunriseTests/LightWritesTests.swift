import Foundation
import Testing
@testable import Sunrise

struct LightWritesTests {
    /// Like a Nanoleaf Essentials bulb: full color, and white from 2,700 K to 6,500 K.
    private let colorBulb = LightCapabilities(brightness: 0...100, mireds: 153...370, hueAndSaturation: true)
    private let whiteBulb = LightCapabilities(brightness: 0...100, mireds: 153...370, hueAndSaturation: false)
    private let colorOnlyBulb = LightCapabilities(brightness: 0...100, mireds: nil, hueAndSaturation: true)
    private let dimmer = LightCapabilities(brightness: 0...100, mireds: nil, hueAndSaturation: false)

    @Test func amberStartUsesColorOnAColorBulb() {
        let writes = LightWrites.writes(for: SunriseLevel(brightness: 1, kelvin: 1500), turnOn: true, capabilities: colorBulb)
        #expect(writes == [.brightness(1), .hue(25), .saturation(100), .power(true)])
    }

    @Test func whitesInRangeUseWhiteTuning() {
        let writes = LightWrites.writes(for: SunriseLevel(brightness: 48, kelvin: 3000), turnOn: true, capabilities: colorBulb)
        #expect(writes == [.brightness(48), .mireds(333), .power(true)])
    }

    @Test func coolerThanTheBulbClampsToItsCoolestWhite() {
        #expect(LightWrites.colorWrites(kelvin: 7000, capabilities: colorBulb) == [.mireds(153)])
    }

    @Test func whiteOnlyBulbUsesItsWarmestWhiteForAmber() {
        #expect(LightWrites.colorWrites(kelvin: 1500, capabilities: whiteBulb) == [.mireds(370)])
    }

    @Test func colorOnlyBulbMakesWhitesFromHueAndSaturation() {
        #expect(LightWrites.colorWrites(kelvin: 4000, capabilities: colorOnlyBulb) == [.hue(27), .saturation(35)])
    }

    @Test func plainDimmerOnlyGetsBrightness() {
        let writes = LightWrites.writes(for: SunriseLevel(brightness: 30, kelvin: 2000), turnOn: false, capabilities: dimmer)
        #expect(writes == [.brightness(30)])
    }

    @Test func brightnessOnlyLeavesColorAlone() {
        let writes = LightWrites.writes(for: SunriseLevel(brightness: 10, kelvin: nil), turnOn: true, capabilities: colorBulb)
        #expect(writes == [.brightness(10), .power(true)])
    }

    @Test func brightnessNeverGoesToZero() {
        let writes = LightWrites.writes(for: SunriseLevel(brightness: 0, kelvin: nil), turnOn: false, capabilities: dimmer)
        #expect(writes == [.brightness(1)])
    }

    @Test func powerComesLastSoTheLightComesOnAtTheNewLevel() {
        let writes = LightWrites.writes(for: SunriseLevel(brightness: 5, kelvin: 1800), turnOn: true, capabilities: colorBulb)
        #expect(writes.last == .power(true))
    }

    @Test func blackbodyColors() {
        let amber = ColorMath.hueSaturation(kelvin: 1500)
        #expect(amber.hue == 25)
        #expect(amber.saturation == 100)
        let warmWhite = ColorMath.hueSaturation(kelvin: 2700)
        #expect(warmWhite.hue == 28)
        #expect(warmWhite.saturation == 66)
        let softDaylight = ColorMath.hueSaturation(kelvin: 4000)
        #expect(softDaylight.hue == 27)
        #expect(softDaylight.saturation == 35)
        let daylight = ColorMath.rgb(kelvin: 6500)
        #expect(daylight.red == 1)
        #expect(daylight.blue > 0.97)
    }

    @Test func capabilityLabels() {
        #expect(colorBulb.kind == "Color")
        #expect(whiteBulb.kind == "White")
        #expect(dimmer.kind == "Dimmable")
    }
}
