import Foundation
import Testing
@testable import Passing

/// A straight drive due north, or a drive east then north, fed one GPS fix per second.
enum TestDrive {
    static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let metersPerDegreeLatitude = 111_195.0

    static func north(miles: Double, stepMeters: Double = 20, secondsPerStep: Double = 1, from latitude: Double = 40, longitude: Double = -75, into buffer: inout BreadcrumbBuffer, startingAt time: Date = start) -> Date {
        let steps = Int(miles * Geo.metersPerMile / stepMeters)
        var now = time
        for i in 0...steps {
            now = time.addingTimeInterval(Double(i) * secondsPerStep)
            buffer.add(TrailPoint(latitude: latitude + Double(i) * stepMeters / metersPerDegreeLatitude, longitude: longitude), at: now)
        }
        return now
    }

    static func east(miles: Double, stepMeters: Double = 20, latitude: Double = 40, from longitude: Double = -75, into buffer: inout BreadcrumbBuffer, startingAt time: Date = start) -> Date {
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(latitude * .pi / 180)
        let steps = Int(miles * Geo.metersPerMile / stepMeters)
        var now = time
        for i in 0...steps {
            now = time.addingTimeInterval(Double(i))
            buffer.add(TrailPoint(latitude: latitude, longitude: longitude + Double(i) * stepMeters / metersPerDegreeLongitude), at: now)
        }
        return now
    }
}

struct BreadcrumbBufferTests {
    @Test func keepsAPointRoughlyEvery50Meters() {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 1, stepMeters: 10, into: &buffer)
        let spacings = zip(buffer.points, buffer.points.dropFirst()).map { Geo.distance($0, $1) }
        #expect(spacings.allSatisfy { $0 >= BreadcrumbBuffer.sampleSpacing })
        #expect(spacings.allSatisfy { $0 < BreadcrumbBuffer.sampleSpacing + 11 })
        #expect(abs(buffer.length - Geo.metersPerMile) < 60)
    }

    @Test func remembersAbout25Miles() {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 40, stepMeters: 60, into: &buffer)
        #expect(buffer.length >= BreadcrumbBuffer.maxLength)
        #expect(buffer.length < BreadcrumbBuffer.maxLength + 100)
        let recomputed = zip(buffer.points, buffer.points.dropFirst()).reduce(0) { $0 + Geo.distance($1.0, $1.1) }
        #expect(abs(recomputed - buffer.length) < 1)
    }

    @Test func aLongBreakInGPSStartsANewTrail() {
        var buffer = BreadcrumbBuffer()
        let end = TestDrive.north(miles: 2, into: &buffer)
        let later = end.addingTimeInterval(BreadcrumbBuffer.maxGap + 1)
        buffer.add(TrailPoint(latitude: 41, longitude: -75), at: later)
        #expect(buffer.points == [TrailPoint(latitude: 41, longitude: -75)])
        #expect(buffer.length == 0)
    }

    @Test func anImpossibleJumpStartsANewTrail() {
        // E.g. a GPS glitch, or the Simulator looping a test route back to its start.
        var buffer = BreadcrumbBuffer()
        let end = TestDrive.north(miles: 2, into: &buffer)
        buffer.add(TrailPoint(latitude: 40, longitude: -75), at: end.addingTimeInterval(5))
        #expect(buffer.points == [TrailPoint(latitude: 40, longitude: -75)])
        #expect(buffer.length == 0)
    }

    @Test func aGapThatCouldHideATurnStartsANewTrail() {
        var buffer = BreadcrumbBuffer()
        let end = TestDrive.north(miles: 1, into: &buffer)
        // 400 m east in 20 s: plausible speed, but the road between is unknown.
        let east = 400 / (TestDrive.metersPerDegreeLatitude * cos(40 * .pi / 180))
        let last = buffer.points.last!
        let lost = buffer.length
        let restart = buffer.add(TrailPoint(latitude: last.latitude, longitude: last.longitude + east), at: end.addingTimeInterval(20))
        #expect(buffer.points.count == 1)
        #expect(buffer.length == 0)
        #expect(restart?.reason == .gap)
        #expect(restart?.seconds == 20)
        #expect(restart?.lostMeters == lost)
    }

    @Test func saysWhyTheTrailRestarted() {
        var buffer = BreadcrumbBuffer()
        let end = TestDrive.north(miles: 1, into: &buffer)
        #expect(buffer.add(TrailPoint(latitude: 40, longitude: -75), at: end.addingTimeInterval(5))?.reason == .jump)
        let later = end.addingTimeInterval(5 + BreadcrumbBuffer.maxGap + 1)
        #expect(buffer.add(TrailPoint(latitude: 40, longitude: -75), at: later)?.reason == .longBreak)
        #expect(buffer.add(TrailPoint(latitude: 40.0001, longitude: -75), at: later.addingTimeInterval(1)) == nil, "ordinary driving")
    }

    @Test func aShortGapKeepsTheTrail() {
        var buffer = BreadcrumbBuffer()
        let end = TestDrive.north(miles: 1, into: &buffer)
        let before = buffer.length
        let last = buffer.points.last!
        // 200 m on in 8 s: a missed fix or two.
        buffer.add(TrailPoint(latitude: last.latitude + 200 / TestDrive.metersPerDegreeLatitude, longitude: last.longitude), at: end.addingTimeInterval(8))
        #expect(buffer.length > before + 150)
    }

    @Test func highwaySpeedIsNotAJump() {
        var buffer = BreadcrumbBuffer()
        // 145 m every 5 s is 65 mph, the test route's spacing.
        _ = TestDrive.north(miles: 2, stepMeters: 145, secondsPerStep: 5, into: &buffer)
        #expect(buffer.length > 1.9 * Geo.metersPerMile)
    }

    @Test func walksOneMileBackOnAStraightRoad() throws {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 3, into: &buffer)
        let car = try #require(buffer.points.last)

        let walk = try #require(buffer.walkBack(from: car, meters: Geo.metersPerMile))
        #expect(abs(Geo.distance(car, walk.target) - Geo.metersPerMile) < 2)
        #expect(walk.target.latitude < car.latitude, "behind the car, not ahead")
        #expect(walk.segment.first == car)
        #expect(walk.segment.last == walk.target)
    }

    @Test func followsTheRoadAroundACorner() throws {
        // 1 mile east, then 1 mile north. 1.5 miles back is half a mile before the corner,
        // on the east-west road, even though it's only ~1.1 miles away in a straight line.
        var buffer = BreadcrumbBuffer()
        let cornerTime = TestDrive.east(miles: 1, into: &buffer)
        let corner = try #require(buffer.points.last)
        _ = TestDrive.north(miles: 1, from: corner.latitude, longitude: corner.longitude, into: &buffer, startingAt: cornerTime.addingTimeInterval(1))
        let car = try #require(buffer.points.last)

        let walk = try #require(buffer.walkBack(from: car, meters: 1.5 * Geo.metersPerMile))
        #expect(abs(walk.target.latitude - 40) < 0.0001, "on the east-west road")
        #expect(abs(Geo.distance(walk.target, corner) - 0.5 * Geo.metersPerMile) < 60)
        #expect(Geo.distance(car, walk.target) < 1.2 * Geo.metersPerMile)
    }

    @Test func noTargetWhenTheTrailIsTooShort() throws {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 0.5, into: &buffer)
        let car = try #require(buffer.points.last)
        #expect(buffer.walkBack(from: car, meters: Geo.metersPerMile) == nil)
        #expect(BreadcrumbBuffer().walkBack(from: car, meters: Geo.metersPerMile) == nil, "empty trail")
    }

    @Test func aTrailJustShortOfTheDistanceStillCounts() throws {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 1, into: &buffer)
        let car = try #require(buffer.points.last)
        let walk = try #require(buffer.walkBack(from: car, meters: buffer.length + 30))
        #expect(walk.target == buffer.points.first)
    }

    @Test func noTargetWhenTheCarIsNotOnTheTrail() throws {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 3, into: &buffer)
        let farAway = TrailPoint(latitude: 42, longitude: -75)
        #expect(buffer.walkBack(from: farAway, meters: Geo.metersPerMile) == nil)
    }

    @Test func aShortTrailIsCarriedOnInAStraightLine() throws {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 0.4, into: &buffer)
        let car = try #require(buffer.points.last)
        let estimate = try #require(buffer.estimateBack(from: car, meters: Geo.metersPerMile, heading: 90))
        #expect(abs(estimate.straightMeters - (Geo.metersPerMile - buffer.length)) < 1)
        #expect(abs(Geo.distance(car, estimate.target) - Geo.metersPerMile) < 30, "a straight road north, so a mile south")
        #expect(estimate.target.latitude < buffer.points[0].latitude, "it follows the trail's own direction, not the heading")
    }

    @Test func withNoTrailTheHeadingIsUsed() throws {
        let car = TrailPoint(latitude: 40, longitude: -75)
        let estimate = try #require(BreadcrumbBuffer().estimateBack(from: car, meters: 1_000, heading: 0))
        #expect(estimate.segment == [car])
        #expect(abs(Geo.distance(car, estimate.target) - 1_000) < 1)
        #expect(estimate.target.latitude < car.latitude, "heading north, so back is south")
        #expect(BreadcrumbBuffer().estimateBack(from: car, meters: 1_000, heading: nil) == nil, "no trail and no direction")
    }

    @Test func aLongEnoughTrailIsNotARoughGuess() throws {
        var buffer = BreadcrumbBuffer()
        _ = TestDrive.north(miles: 3, into: &buffer)
        let car = try #require(buffer.points.last)
        let estimate = try #require(buffer.estimateBack(from: car, meters: Geo.metersPerMile, heading: 0))
        #expect(estimate.straightMeters == 0)
    }

    @Test func trailSegmentsSurviveStorage() {
        let points = [TrailPoint(latitude: 40.1, longitude: -75.2), TrailPoint(latitude: 40.2, longitude: -75.3)]
        #expect(TrailCoding.decode(TrailCoding.encode(points)) == points)
        #expect(TrailCoding.encode([]) == nil)
        #expect(TrailCoding.decode(nil).isEmpty)
    }
}

struct GeoTests {
    @Test func bearingsAndDestinations() {
        let start = TrailPoint(latitude: 40, longitude: -75)
        let north = Geo.destination(from: start, bearing: 0, meters: 1_000)
        #expect(abs(Geo.distance(start, north) - 1_000) < 0.5)
        #expect(abs(Geo.bearing(from: start, to: north)) < 0.01 || abs(Geo.bearing(from: start, to: north) - 360) < 0.01)
        let southwest = Geo.destination(from: start, bearing: 225, meters: 5_000)
        #expect(abs(Geo.bearing(from: start, to: southwest) - 225) < 0.1)
        #expect(abs(Geo.distance(start, southwest) - 5_000) < 1)
    }

    @Test func compassNames() {
        #expect(Geo.compassName(for: 0) == "north")
        #expect(Geo.compassName(for: 225) == "southwest")
        #expect(Geo.compassName(for: 225, short: true) == "SW", "the pin screen's Heading row")
        #expect(Geo.compassName(for: -10, short: true) == "N")
        #expect(Geo.compassName(for: 225 + 180) == "northeast")
        #expect(Geo.compassName(for: -90) == "west")
    }

    @Test func milesText() {
        #expect(Geo.milesText(1) == "1 mile")
        #expect(Geo.milesText(3) == "3 miles")
        #expect(Geo.milesText(1.5) == "1.5 miles")
        #expect(Geo.shortMilesText(2) == "2 mi")
    }
}
