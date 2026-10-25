import Foundation
import Testing
@testable import Passing

struct CaptureZoneTests {
    @Test func zonesAreLaidOutLeftToRightLikeTheRoad() {
        #expect(CaptureZone.allCases == [.farLeft, .nearLeft, .car, .nearRight, .farRight])
    }

    @Test func eachZoneSavesTheRightSideAndDistance() {
        #expect(CaptureZone.farLeft.side == .left && CaptureZone.farLeft.distance == .far)
        #expect(CaptureZone.nearLeft.side == .left && CaptureZone.nearLeft.distance == .near)
        #expect(CaptureZone.nearRight.side == .right && CaptureZone.nearRight.distance == .near)
        #expect(CaptureZone.farRight.side == .right && CaptureZone.farRight.distance == .far)
    }

    @Test func tappingTheCarLeavesSideUnknown() {
        #expect(CaptureZone.car.side == .unknown)
        #expect(CaptureZone.car.distance == .unknown)
    }

    @Test func spokenConfirmationNamesTheZone() {
        #expect(PinDescription.spokenConfirmation(side: .left, distance: .far) == "Left, far, saved")
        #expect(PinDescription.spokenConfirmation(side: .right, distance: .near) == "Right, near, saved")
        #expect(PinDescription.spokenConfirmation(side: .right, distance: .unknown) == "Right, saved")
        #expect(PinDescription.spokenConfirmation(side: .unknown, distance: .unknown) == "Saved")
    }
}

struct TapDebouncerTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Feeds taps at the given offsets (seconds) and returns which ones were accepted.
    private func accepted(_ taps: [(CaptureZone, TimeInterval)]) -> [Bool] {
        var debouncer = TapDebouncer<CaptureZone>()
        return taps.map { zone, offset in debouncer.shouldAccept(zone, at: start.addingTimeInterval(offset)) }
    }

    @Test func repeatTapOnTheSameZoneIsIgnored() {
        #expect(accepted([(.farLeft, 0), (.farLeft, 0.5), (.farLeft, 0.75)]) == [true, false, true])
    }

    @Test func differentZonesAreIndependent() {
        #expect(accepted([(.farLeft, 0), (.nearRight, 0.1)]) == [true, true])
    }

    @Test func ignoredTapsDontExtendTheWindow() {
        #expect(accepted([(.car, 0), (.car, 0.5), (.car, 0.8)]) == [true, false, true])
    }
}

struct MapLinksTests {
    @Test func appleMapsLinkUsesCoordinatesAndLabel() {
        let url = MapLinks.apple(latitude: 40.7128, longitude: -74.006, label: "large building")
        #expect(url.absoluteString == "https://maps.apple.com/?ll=40.712800,-74.006000&q=large%20building")
    }

    @Test func appleMapsLinkWithoutLabelStillDropsAPin() {
        let url = MapLinks.apple(latitude: 40.7128, longitude: -74.006, label: nil)
        #expect(url.absoluteString == "https://maps.apple.com/?ll=40.712800,-74.006000&q=Passing%20pin")
        #expect(MapLinks.apple(latitude: 40.7128, longitude: -74.006, label: "") == url)
    }

    @Test func googleMapsLinkUsesCoordinates() {
        let url = MapLinks.google(latitude: -33.856784, longitude: 151.215297)
        #expect(url.absoluteString == "https://www.google.com/maps/search/?api=1&query=-33.856784,151.215297")
    }
}
