import Foundation
import Testing
@testable import Passing

struct GroupFilterTests {
    let roadTrip = UUID()
    let houses = UUID()

    @Test func allShowsEverything() {
        #expect(GroupFilter.all.includes(groupID: nil, needsReview: false))
        #expect(GroupFilter.all.includes(groupID: roadTrip, needsReview: false))
    }

    @Test func oneGroupShowsOnlyItsPins() {
        #expect(GroupFilter.group(roadTrip).includes(groupID: roadTrip, needsReview: false))
        #expect(!GroupFilter.group(roadTrip).includes(groupID: houses, needsReview: false))
        #expect(!GroupFilter.group(roadTrip).includes(groupID: nil, needsReview: false))
    }

    @Test func needsReviewShowsThosePinsInAnyGroup() {
        #expect(GroupFilter.needsReview.includes(groupID: nil, needsReview: true))
        #expect(GroupFilter.needsReview.includes(groupID: roadTrip, needsReview: true))
        #expect(!GroupFilter.needsReview.includes(groupID: nil, needsReview: false))
        #expect(GroupFilter.all.includes(groupID: nil, needsReview: false))
    }

    @Test func ungroupedShowsPinsWithoutAGroup() {
        #expect(GroupFilter.ungrouped.includes(groupID: nil, needsReview: false))
        #expect(!GroupFilter.ungrouped.includes(groupID: roadTrip, needsReview: false))
    }
}

struct GroupNamingTests {
    @Test func trimsAndKeepsAGoodName() {
        #expect(GroupNaming.clean("  Road trip ", existing: []) == "Road trip")
    }

    @Test func rejectsBlankNamesAndDuplicatesIgnoringCase() {
        #expect(GroupNaming.clean("   ", existing: []) == nil)
        #expect(GroupNaming.clean("road TRIP", existing: ["Road trip"]) == nil)
        #expect(GroupNaming.clean("Houses", existing: ["Road trip"]) == "Houses")
    }

    @Test func capsTheLength() {
        let long = String(repeating: "a", count: 60)
        #expect(GroupNaming.clean(long, existing: [])?.count == GroupNaming.maxLength)
    }
}

struct PlaceNamingTests {
    @Test func nearbyPinsShareATownLookup() {
        #expect(PlaceNaming.cacheKey(latitude: 37.9712, longitude: -100.8731) == PlaceNaming.cacheKey(latitude: 37.9741, longitude: -100.8688))
        #expect(PlaceNaming.cacheKey(latitude: 37.97, longitude: -100.87) != PlaceNaming.cacheKey(latitude: 38.05, longitude: -100.87))
    }

    @Test func prefersTheTownWithContext() {
        #expect(PlaceNaming.name(cityWithContext: "Garden City, KS", cityName: "Garden City", fallback: "US-50") == "Garden City, KS")
    }

    @Test func fallsBackInOrder() {
        #expect(PlaceNaming.name(cityWithContext: nil, cityName: "Garden City", fallback: "US-50") == "Garden City")
        #expect(PlaceNaming.name(cityWithContext: " ", cityName: nil, fallback: "US-50") == "US-50")
        #expect(PlaceNaming.name(cityWithContext: nil, cityName: "", fallback: nil) == nil)
    }
}
