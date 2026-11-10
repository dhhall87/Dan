import Foundation
import Testing
@testable import Passing

struct NearbyPlacesTests {
    @Test func looksFartherForFarSidePins() {
        #expect(NearbyPlaces.searchRadius(for: .near) < NearbyPlaces.searchRadius(for: .far))
        #expect(NearbyPlaces.searchRadius(for: .unknown) == NearbyPlaces.searchRadius(for: .far))
        #expect(NearbyPlaces.widerRadius > NearbyPlaces.searchRadius(for: .far))
        #expect(abs(NearbyPlaces.widerRadius - 1_609) < 1, "about a mile")
    }

    @Test func lookingFartherListsMore() {
        #expect(NearbyPlaces.maxShown(radius: NearbyPlaces.searchRadius(for: .near)) == 7)
        #expect(NearbyPlaces.maxShown(radius: NearbyPlaces.searchRadius(for: .far)) == 7)
        #expect(NearbyPlaces.maxShown(radius: NearbyPlaces.widerRadius) == 15)
    }

    @Test func categoryNamesReadNaturally() {
        #expect(NearbyPlaces.categoryTitle(fromRawValue: "MKPOICategoryRestaurant") == "Restaurant")
        #expect(NearbyPlaces.categoryTitle(fromRawValue: "MKPOICategoryGasStation") == "Gas Station")
        #expect(NearbyPlaces.categoryTitle(fromRawValue: "MKPOICategoryEVCharger") == "EV Charger")
        #expect(NearbyPlaces.categoryTitle(fromRawValue: "MKPOICategoryATM") == "ATM")
        #expect(NearbyPlaces.categoryTitle(fromRawValue: "Restaurant") == nil)
    }

    @Test func distancesInFeetThenMiles() {
        #expect(NearbyPlaces.distanceText(meters: 100) == "330 ft")
        #expect(NearbyPlaces.distanceText(meters: 1) == "10 ft")
        #expect(NearbyPlaces.distanceText(meters: 650) == "0.4 mi")
    }

    @Test func aPlaceIsLeftOrRightOfTheWayTheCarWasGoing() {
        // Heading north: east is on the right, west on the left.
        #expect(NearbyPlaces.side(course: 0, bearingToPlace: 90) == .right)
        #expect(NearbyPlaces.side(course: 0, bearingToPlace: 270) == .left)
        // Heading south-west (225): north-west (315) is on the right.
        #expect(NearbyPlaces.side(course: 225, bearingToPlace: 315) == .right)
        #expect(NearbyPlaces.side(course: 350, bearingToPlace: 40) == .right, "across north")
        #expect(NearbyPlaces.side(course: 90, bearingToPlace: 95) == .unknown, "nearly dead ahead")
        #expect(NearbyPlaces.side(course: 90, bearingToPlace: 265) == .unknown, "nearly dead behind")
    }

    @Test func placesOnTheTappedSideComeFirstStillClosestFirst() {
        let places = ["near right", "near left", "ahead", "far left", "far right"]
        let sides: [Side] = [.right, .left, .unknown, .left, .right]
        #expect(NearbyPlaces.tappedSideFirst(places, sides: sides, tapped: .left) == ["near left", "far left", "near right", "ahead", "far right"])
        #expect(NearbyPlaces.tappedSideFirst(places, sides: sides, tapped: .unknown) == places, "no side tapped: closest first")
    }
}
