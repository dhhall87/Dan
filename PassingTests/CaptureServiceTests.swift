import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import Passing

@MainActor
struct CaptureServiceTests {
    let container: ModelContainer
    let tap = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelContainer(for: Pin.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private final class Confirmations {
        var count = 0
    }

    private func fix(at timestamp: Date, accuracy: Double = 8, course: Double = 225, speed: Double = 27) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.006),
            altitude: 10,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }

    private func service(currentFix: CLLocation?, lateFix: CLLocation? = nil, confirmations: Confirmations = Confirmations()) -> CaptureService {
        CaptureService(
            context: container.mainContext,
            currentFix: { currentFix },
            lateFix: { lateFix },
            confirm: { _ in confirmations.count += 1 }
        )
    }

    private func savedPins() throws -> [Pin] {
        try container.mainContext.fetch(FetchDescriptor<Pin>())
    }

    @Test func oneTapSavesAPinWithoutALabel() throws {
        let confirmations = Confirmations()
        let pin = try #require(service(currentFix: fix(at: tap), confirmations: confirmations)
            .capture(side: .unknown, distance: .unknown, source: .app, now: tap))

        #expect(try savedPins().count == 1)
        #expect(pin.label == nil)
        #expect(pin.displayLabel == "Unlabeled")
        #expect(pin.latitude == 40.7128 && pin.longitude == -74.006)
        #expect(pin.horizontalAccuracy == 8)
        #expect(pin.fixTimestamp == tap)
        #expect(pin.course == 225 && pin.courseReliable)
        #expect(pin.targetSource == .direct && pin.targetCoordinate == nil)
        #expect(!pin.isApproximate)
        #expect(confirmations.count == 1)
    }

    @Test(arguments: [CaptureZone.farLeft, .nearLeft, .car, .nearRight, .farRight])
    func eachZoneSavesItsSideAndDistance(zone: CaptureZone) throws {
        let pin = try #require(service(currentFix: fix(at: tap)).capture(side: zone.side, distance: zone.distance, source: .app, now: tap))
        #expect(pin.side == zone.side)
        #expect(pin.distance == zone.distance)
    }

    @Test func noFixStillSavesThePinWithNoLocation() throws {
        let pin = try #require(service(currentFix: nil).capture(side: .left, distance: .far, source: .app, now: tap))
        #expect(try savedPins().count == 1)
        #expect(!pin.hasLocation)
        #expect(pin.fixTimestamp == nil)
        #expect(pin.appleMapsURL == nil && pin.googleMapsURL == nil)
    }

    @Test func repeatTapOnTheSameZoneIsDebounced() throws {
        let capture = service(currentFix: fix(at: tap))
        #expect(capture.capture(side: .left, distance: .far, source: .app, now: tap) != nil)
        #expect(capture.capture(side: .left, distance: .far, source: .app, now: tap.addingTimeInterval(0.4)) == nil)
        #expect(capture.capture(side: .right, distance: .far, source: .app, now: tap.addingTimeInterval(0.5)) != nil)
        #expect(capture.capture(side: .left, distance: .far, source: .app, now: tap.addingTimeInterval(1.0)) != nil)
        #expect(try savedPins().count == 3)
    }

    @Test func lateFixIsAttachedAndFlaggedApproximate() async throws {
        let late = fix(at: tap.addingTimeInterval(6))
        let capture = service(currentFix: nil, lateFix: late)
        let pin = try #require(capture.capture(side: .right, distance: .near, source: .app, now: tap))
        await capture.attachLateFix(to: pin)

        #expect(pin.hasLocation)
        #expect(pin.fixTimestamp == late.timestamp)
        #expect(pin.isApproximate, "fix came 6 s after the tap")
    }

    @Test func oldCachedFixIsNeverAttached() async throws {
        let stale = fix(at: tap.addingTimeInterval(-120))
        let capture = service(currentFix: nil, lateFix: stale)
        let pin = try #require(capture.capture(side: .right, distance: .near, source: .app, now: tap))
        await capture.attachLateFix(to: pin)

        #expect(!pin.hasLocation)
    }

    @Test func captureCoordinatesAreNeverOverwritten() {
        let pin = Pin(capturedAt: tap, side: .left, distance: .near, source: .app)
        pin.applyFix(fix(at: tap))
        let moved = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41, longitude: -75),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0,
            timestamp: tap.addingTimeInterval(1)
        )
        pin.applyFix(moved)
        #expect(pin.latitude == 40.7128 && pin.longitude == -74.006)
        #expect(pin.fixTimestamp == tap)
    }

    @Test func slowSpeedMeansCourseIsUnreliable() throws {
        let pin = try #require(service(currentFix: fix(at: tap, speed: 0.5)).capture(side: .left, distance: .near, source: .app, now: tap))
        #expect(!pin.courseReliable)
    }

    @Test func mapLinksPreferTheTargetOverTheCar() {
        let pin = Pin(capturedAt: tap, side: .left, distance: .far, source: .app)
        pin.applyFix(fix(at: tap))
        #expect(pin.googleMapsURL?.absoluteString == "https://www.google.com/maps/search/?api=1&query=40.712800,-74.006000")

        pin.targetLatitude = 40.7
        pin.targetLongitude = -74.02
        #expect(pin.googleMapsURL?.absoluteString == "https://www.google.com/maps/search/?api=1&query=40.700000,-74.020000")
        // The car's position is untouched.
        #expect(pin.latitude == 40.7128)
    }
}
