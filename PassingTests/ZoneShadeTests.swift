import Foundation
import Testing
@testable import Passing

struct ZoneShadeTests {
    @Test func followsTheMockupTopToBottom() {
        #expect(ZoneShade.rgb(far: false, at: 0) == [25, 100, 72])
        #expect(ZoneShade.rgb(far: false, at: 1) == [11, 59, 45])
        #expect(ZoneShade.rgb(far: true, at: 1) == [10, 27, 51])
        let middle = ZoneShade.rgb(far: false, at: 0.25)
        #expect(middle.y > 100 && middle.y < 108, "between the 0.15 and 0.36 stops")
    }

    @Test func smokeStaysSubtle() {
        for isFar in [false, true] {
            for seed in 0..<4 {
                let grid = ZoneShade.grid(far: isFar, seed: seed)
                #expect(grid.count == ZoneShade.columns * ZoneShade.rows)
                for (index, color) in grid.enumerated() {
                    let row = index / ZoneShade.columns
                    let base = ZoneShade.rgb(far: isFar, at: Double(row) / Double(ZoneShade.rows - 1))
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
            for color in ZoneShade.grid(far: false, seed: seed) {
                #expect(color.y > color.x && color.y > color.z, "green leads in every near spot")
            }
            for color in ZoneShade.grid(far: true, seed: seed) {
                #expect(color.z > color.x && color.z > color.y, "blue leads in every far spot")
            }
        }
    }

    @Test func eachZoneHasItsOwnPatternThatNeverChanges() {
        #expect(ZoneShade.grid(far: false, seed: 1) != ZoneShade.grid(far: false, seed: 2))
        #expect(ZoneShade.grid(far: false, seed: 1) == ZoneShade.grid(far: false, seed: 1))
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
