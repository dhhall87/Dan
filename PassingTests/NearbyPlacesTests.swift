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
}
