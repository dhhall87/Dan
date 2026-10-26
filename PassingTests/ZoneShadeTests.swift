import Foundation
import Testing
@testable import Passing

struct ZoneShadeTests {
    @Test func followsTheMockupTopToBottom() {
        #expect(ZoneShade.rgb(.near, at: 0) == [25, 100, 72])
        #expect(ZoneShade.rgb(.near, at: 1) == [11, 59, 45])
        #expect(ZoneShade.rgb(.far, at: 1) == [10, 27, 51])
        let middle = ZoneShade.rgb(.near, at: 0.25)
        #expect(middle.y > 100 && middle.y < 108, "between the 0.15 and 0.36 stops")
    }

    @Test func smokeStaysSubtle() {
        for surface in ZoneShade.Surface.allCases {
            for seed in 0..<6 {
                let grid = ZoneShade.grid(surface, seed: seed)
                #expect(grid.count == ZoneShade.columns * ZoneShade.rows)
                for (index, color) in grid.enumerated() {
                    let row = index / ZoneShade.columns
                    let base = ZoneShade.rgb(surface, at: Double(row) / Double(ZoneShade.rows - 1))
                    // Within about 9% darker or 13% lighter (the pale lift on light wisps), per channel.
                    for channel in 0..<3 {
                        #expect(abs(color[channel] - base[channel]) <= base[channel] * 0.1 + 255 * 0.035)
                    }
                }
            }
        }
    }

    @Test func nearStaysGreenAndFarStaysBlueEverywhere() {
        for seed in 0..<4 {
            for color in ZoneShade.grid(.near, seed: seed) {
                #expect(color.y > color.x && color.y > color.z, "green leads in every near spot")
            }
            for color in ZoneShade.grid(.far, seed: seed) {
                #expect(color.z > color.x && color.z > color.y, "blue leads in every far spot")
            }
        }
    }

    @Test func pinButtonStaysNavyWithItsMiddleUnchanged() {
        #expect(ZoneShade.rgb(.pin, at: 0.5) == [16, 26, 48], "the icon's navy behind \"Pin it\"")
        #expect(ZoneShade.rgb(.pin, at: 0).z > ZoneShade.rgb(.pin, at: 0.5).z, "lighter at the top")
        for (index, color) in ZoneShade.grid(.pin, seed: 5).enumerated() {
            #expect(color.z > color.x && color.z > color.y, "blue leads everywhere")
            #expect(color.z < 90, "still a dark button")
            let row = index / ZoneShade.columns
            if row >= 2 && row <= 4 {
                // Behind "Pin it", so the white text keeps its contrast.
                #expect(color.z < 60)
            }
        }
    }

    @Test func eachZoneHasItsOwnPatternThatNeverChanges() {
        #expect(ZoneShade.grid(.near, seed: 1) != ZoneShade.grid(.near, seed: 2))
        #expect(ZoneShade.grid(.near, seed: 1) == ZoneShade.grid(.near, seed: 1))
        for seed in 0..<4 {
            for row in 0..<ZoneShade.rows {
                for column in 0..<ZoneShade.columns {
                    let wisp = ZoneShade.wisp(column: column, row: row, seed: seed)
                    #expect(wisp >= -1 && wisp <= 1)
                }
            }
        }
    }
}
