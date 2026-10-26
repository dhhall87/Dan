import Foundation
import Testing
@testable import Passing

struct GPSStatusTests {
    @Test func readyOnlyWithAFreshPreciseFix() {
        #expect(GPSStatus(isAuthorized: true, isDenied: false, isPreciseLocationOff: false, hasFreshFix: true) == .ready)
        #expect(GPSStatus(isAuthorized: true, isDenied: false, isPreciseLocationOff: false, hasFreshFix: false) == .searching)
    }

    @Test func saysWhyThereWontBeAPosition() {
        #expect(GPSStatus(isAuthorized: false, isDenied: true, isPreciseLocationOff: false, hasFreshFix: false) == .off)
        #expect(GPSStatus(isAuthorized: true, isDenied: false, isPreciseLocationOff: true, hasFreshFix: true) == .notPrecise)
        #expect(!GPSStatus.off.pinsGetAPosition)
        #expect(!GPSStatus.notPrecise.pinsGetAPosition)
    }

    @Test func notAskedYetIsNotAnError() {
        let status = GPSStatus(isAuthorized: false, isDenied: false, isPreciseLocationOff: false, hasFreshFix: false)
        #expect(status == .notAsked)
        #expect(status.pinsGetAPosition, "Passing asks on the first pin")
    }

    @Test func aStoreThatWontOpenComesFirst() {
        let status = GPSStatus(isAuthorized: true, isDenied: false, isPreciseLocationOff: false, hasFreshFix: true, canSave: false)
        #expect(status == .cantSave)
        #expect(status.title == "Can't save pins")
    }
}
