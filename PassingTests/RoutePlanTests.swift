import Foundation
import Testing
@testable import Passing

struct RoutePlanTests {
    private func stops(_ count: Int) -> [RouteStop] {
        (1...count).map { RouteStop(name: "Pin \($0)", latitude: 40 + Double($0) / 100, longitude: -75) }
    }

    private func values(_ name: String, in url: URL?) -> [String] {
        guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [] }
        return items.filter { $0.name == name }.compactMap(\.value)
    }

    @Test func firstAndLastPinsAreTheEndsByDefault() throws {
        let plan = RoutePlan(pins: stops(4))
        let legs = try #require(plan.legs)
        #expect(legs.source?.name == "Pin 1")
        #expect(legs.waypoints.map(\.name) == ["Pin 2", "Pin 3"])
        #expect(legs.destination.name == "Pin 4")
    }

    @Test func startAndEndCanBeOtherPlaces() throws {
        let home = RouteStop(name: "Home", latitude: 39.9, longitude: -75.1)
        let plan = RoutePlan(pins: stops(2), start: .currentLocation, end: .place(home))
        let legs = try #require(plan.legs)
        #expect(legs.source == nil, "the Maps app starts from where the iPhone is")
        #expect(legs.waypoints.map(\.name) == ["Pin 1", "Pin 2"])
        #expect(legs.destination == home)
    }

    @Test func needsTwoPointsToMakeARoute() {
        #expect(RoutePlan(pins: stops(1)).legs == nil)
        #expect(RoutePlan(pins: []).appleURL == nil)
        #expect(RoutePlan(pins: stops(1), start: .currentLocation).legs != nil, "from here to one pin")
    }

    @Test func appleMapsGetsEveryStopInOrder() {
        let url = RoutePlan(pins: stops(3), mode: .walking).appleURL
        #expect(url?.absoluteString.hasPrefix("https://maps.apple.com/directions?") == true)
        #expect(values("source", in: url) == ["40.010000,-75.000000"])
        #expect(values("waypoint", in: url) == ["40.020000,-75.000000"])
        #expect(values("destination", in: url) == ["40.030000,-75.000000"])
        #expect(values("mode", in: url) == ["walking"])
    }

    @Test func appleMapsStartsFromHereWhenAsked() {
        let url = RoutePlan(pins: stops(2), start: .currentLocation).appleURL
        #expect(values("source", in: url).isEmpty)
        #expect(values("waypoint", in: url).count == 1)
    }

    @Test func shortRoutesAreOneGoogleLink() {
        let urls = RoutePlan(pins: stops(5)).googleURLs
        #expect(urls.count == 1)
        #expect(values("origin", in: urls.first) == ["40.010000,-75.000000"])
        #expect(values("destination", in: urls.first) == ["40.050000,-75.000000"])
        #expect(values("waypoints", in: urls.first).first?.split(separator: "|").count == 3)
        #expect(values("travelmode", in: urls.first) == ["driving"])
        #expect(values("api", in: urls.first) == ["1"])
    }

    @Test func longRoutesSplitIntoGoogleParts() {
        // 12 pins: start, 10 in between, end. Google takes 9 in between per link.
        let urls = RoutePlan(pins: stops(12)).googleURLs
        #expect(urls.count == 2)
        #expect(values("waypoints", in: urls[0]).first?.split(separator: "|").count == 9)
        #expect(values("destination", in: urls[0]) == ["40.110000,-75.000000"])
        #expect(values("origin", in: urls[1]) == ["40.110000,-75.000000"], "part 2 starts where part 1 ended")
        #expect(values("destination", in: urls[1]) == ["40.120000,-75.000000"])
        #expect(values("waypoints", in: urls[1]).isEmpty)
    }

    @Test func pointsIncludeAKnownStartButNotHere() {
        let work = RouteStop(name: "Work", latitude: 39.95, longitude: -75.2)
        #expect(RoutePlan(pins: stops(2), start: .place(work)).points.map(\.name) == ["Work", "Pin 1", "Pin 2"])
        #expect(RoutePlan(pins: stops(2), start: .currentLocation).points.map(\.name) == ["Pin 1", "Pin 2"])
    }

    @Test func straightDistanceAddsUpTheLegs() {
        // Three pins 0.01° of latitude apart: about 1.11 km each.
        let meters = RoutePlan(pins: stops(3)).straightMeters
        #expect(abs(meters - 2_224) < 10)
    }
}
