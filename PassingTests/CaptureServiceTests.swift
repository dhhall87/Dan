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
        container = try ModelContainer(for: Pin.self, PinGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private final class Confirmations {
        var count = 0
    }

    private final class ReviewCounts {
        var values: [Int] = []
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

    private func service(
        currentFix: CLLocation?,
        lateFix: CLLocation? = nil,
        trail: BreadcrumbBuffer = BreadcrumbBuffer(),
        confirmations: Confirmations = Confirmations()
    ) -> CaptureService {
        CaptureService(
            context: container.mainContext,
            currentFix: { currentFix },
            lateFix: { lateFix },
            trail: { trail },
            confirm: { _ in confirmations.count += 1 }
        )
    }

    private func savedPins() throws -> [Pin] {
        try container.mainContext.fetch(FetchDescriptor<Pin>())
    }

    @Test func onlyWidgetAndControlCenterPinsArmReviewReminders() throws {
        let waiting = ReviewCounts()
        let capture = CaptureService(
            context: container.mainContext,
            currentFix: { nil },
            lateFix: { nil },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in },
            reviewWaiting: { waiting.values.append($0) }
        )
        _ = capture.capture(side: .unknown, distance: .unknown, source: .app, now: tap)
        _ = capture.capture(side: .unknown, distance: .unknown, source: .siri, now: tap.addingTimeInterval(1))
        #expect(waiting.values.isEmpty, "phone and Siri pins don't go into Needs Review")

        let first = try #require(capture.capture(side: .left, distance: .far, source: .widget, now: tap.addingTimeInterval(2)))
        _ = capture.capture(side: .unknown, distance: .unknown, source: .control, now: tap.addingTimeInterval(3))
        #expect(waiting.values == [1, 2])
        #expect(first.needsReview)

        first.isReviewed = true
        #expect(!first.needsReview)
        #expect(capture.needsReviewCount() == 1)
    }

    @Test func movingAPinKeepsWhereTheCarWas() throws {
        let pin = try #require(service(currentFix: fix(at: tap)).capture(side: .left, distance: .far, source: .widget, now: tap))
        pin.placeName = "Garden City, KS"
        pin.moveTarget(to: CLLocationCoordinate2D(latitude: 40.72, longitude: -74.01))

        #expect(pin.latitude == 40.7128 && pin.longitude == -74.006, "the capture point is never overwritten")
        #expect(pin.targetLatitude == 40.72 && pin.targetLongitude == -74.01)
        #expect(pin.targetSource == .manual)
        #expect(pin.lookUpCoordinate?.latitude == 40.72, "map links go to the moved spot")
        #expect(pin.needsPlaceName, "the town is looked up again for the new spot")
    }

    @Test func choosingAPlaceNamesAndLinksThePin() throws {
        let pin = try #require(service(currentFix: fix(at: tap)).capture(side: .right, distance: .near, source: .widget, now: tap))
        pin.label = "diner"
        pin.choosePlace(name: "Joe's Diner", coordinate: CLLocationCoordinate2D(latitude: 40.713, longitude: -74.007), placeID: "I521E602783BA9605", town: "Garden City, KS")

        #expect(pin.label == "Joe's Diner")
        #expect(pin.latitude == 40.7128, "the car's position stays")
        #expect(pin.targetLatitude == 40.713)
        #expect(pin.placeName == "Garden City, KS")
        #expect(pin.appleMapsURL?.absoluteString == "https://maps.apple.com/place?place-id=I521E602783BA9605")
        #expect(pin.googleMapsURL?.absoluteString.contains("query=Joe's%20Diner,%20Garden%20City,%20KS") == true)
        #expect(PinFormat.accuracy(of: pin).hasPrefix("Matched to a place"))

        pin.moveTarget(to: CLLocationCoordinate2D(latitude: 40.72, longitude: -74.01))
        #expect(pin.placeID == nil, "moving by hand unlinks the place")
        #expect(pin.appleMapsURL?.absoluteString.hasPrefix("https://maps.apple.com/?ll=") == true)
    }

    @Test func aPinWithNoLocationCanBePlacedByHand() throws {
        let pin = try #require(service(currentFix: nil).capture(side: .unknown, distance: .unknown, source: .widget, now: tap))
        #expect(!pin.hasLocation)
        pin.moveTarget(to: CLLocationCoordinate2D(latitude: 37.97, longitude: -100.87))
        #expect(!pin.hasLocation, "still no car position")
        #expect(pin.lookUpCoordinate != nil)
        #expect(PinFormat.accuracy(of: pin) == "Placed by you")
    }

    @Test func notesSaveTextWithoutLocationOrConfirmation() throws {
        let confirmations = Confirmations()
        let note = service(currentFix: fix(at: tap), confirmations: confirmations)
            .addNote("Call about the farm for sale", now: tap)

        #expect(try savedPins().count == 1)
        #expect(note.isNote)
        #expect(note.label == "Call about the farm for sale")
        #expect(!note.hasLocation, "a note never takes the car's position")
        #expect(note.capturedAt == tap)
        #expect(confirmations.count == 0, "notes give their own feedback")
    }

    @Test func onlyEmptyNotesAreDiscarded() throws {
        let capture = service(currentFix: fix(at: tap))
        let empty = capture.addNote(nil, now: tap)
        let written = capture.addNote("blue silo", now: tap)
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap.addingTimeInterval(5)))
        #expect(empty.displayLabel == "Empty note")

        capture.discardEmptyNote(empty)
        capture.discardEmptyNote(written)
        capture.discardEmptyNote(pin)

        let ids = Set(try savedPins().map(\.id))
        #expect(ids == [written.id, pin.id])
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

    @Test func preciseLocationOffKeepsOnlyRoughlyWhere() throws {
        let capture = CaptureService(
            context: container.mainContext,
            currentFix: { self.fix(at: self.tap) },
            lateFix: { nil },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in },
            isPrecise: { false }
        )
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap))
        #expect(pin.latitude == 40.71 && pin.longitude == -74.01)
        #expect(pin.speed == nil, "no speed without precise location")
        #expect(pin.course == 225, "the direction is kept, to the nearest compass point")
        #expect(pin.horizontalAccuracy == CoarseLocation.accuracy)
        #expect(pin.isApproximate)
    }

    @Test func widgetAndControlCenterTapsAreDebouncedToo() throws {
        let capture = service(currentFix: fix(at: tap))
        #expect(capture.capture(side: .left, distance: .near, source: .widget, now: tap) != nil)
        #expect(capture.capture(side: .left, distance: .near, source: .widget, now: tap.addingTimeInterval(0.3)) == nil,
                "a bounce on the widget button")
        #expect(capture.capture(side: .unknown, distance: .unknown, source: .control, now: tap) != nil)
        #expect(capture.capture(side: .unknown, distance: .unknown, source: .control, now: tap.addingTimeInterval(0.3)) == nil)
        #expect(capture.capture(side: .unknown, distance: .unknown, source: .siri, now: tap) != nil)
        #expect(capture.capture(side: .unknown, distance: .unknown, source: .siri, now: tap.addingTimeInterval(0.3)) != nil,
                "two Siri requests are two pins")
        #expect(try savedPins().count == 4)
    }

    @Test func widgetCapturesAreSilent() throws {
        let confirmations = Confirmations()
        let capture = service(currentFix: fix(at: tap), confirmations: confirmations)
        capture.capture(side: .right, distance: .far, source: .widget, now: tap)
        capture.capture(side: .unknown, distance: .unknown, source: .control, now: tap)
        #expect(confirmations.count == 0, "no tone or haptic from the widget or Control Center")
        #expect(try savedPins().map(\.source).sorted { $0.rawValue < $1.rawValue } == [.control, .widget])
    }

    @Test func lateFixIsAttachedAndFlaggedApproximate() async throws {
        let late = fix(at: tap.addingTimeInterval(6))
        let capture = service(currentFix: nil, lateFix: late)
        let pin = try #require(capture.capture(side: .right, distance: .near, source: .app, now: tap))
        await capture.attachLateFix(to: pin)

        #expect(pin.hasLocation)
        #expect(pin.fixTimestamp == late.timestamp)
        #expect(pin.isApproximate, "fix came 6 s after the tap at 27 m/s")
    }

    @Test func lateFixSoonAfterTheTapWhileParkedIsNotApproximate() async throws {
        let late = fix(at: tap.addingTimeInterval(2), speed: 0)
        let capture = service(currentFix: nil, lateFix: late)
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap))
        await capture.attachLateFix(to: pin)

        #expect(pin.hasLocation)
        #expect(!pin.isApproximate, "the car didn't move")
    }

    @Test func slowLateFixIsApproximateEvenAtAStop() async throws {
        // 6 s after the tap the car is stopped, but it may have braked after passing the thing.
        let late = fix(at: tap.addingTimeInterval(6), speed: 0)
        let capture = service(currentFix: nil, lateFix: late)
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap))
        await capture.attachLateFix(to: pin)

        #expect(pin.hasLocation)
        #expect(pin.isApproximate)
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

    // MARK: Miles back

    /// A trail heading north that ends where the test fix puts the car (40.7128, -74.006).
    private func trailEndingAtFix(miles: Double) -> BreadcrumbBuffer {
        var buffer = BreadcrumbBuffer()
        let startLatitude = 40.7128 - miles * Geo.metersPerMile / TestDrive.metersPerDegreeLatitude
        _ = TestDrive.north(miles: miles, from: startLatitude, longitude: -74.006, into: &buffer)
        return buffer
    }

    @Test func plusOneMovesThePinJustDroppedAlongTheTrail() throws {
        let confirmations = Confirmations()
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 3), confirmations: confirmations)
        let pin = try #require(capture.capture(side: .left, distance: .near, source: .app, now: tap))
        let moved = try #require(capture.milesBackTap(now: tap.addingTimeInterval(6)))

        #expect(moved === pin, "the same pin, not a new one")
        #expect(try savedPins().count == 1)
        #expect(pin.milesBack == 1)
        #expect(pin.side == .left && pin.distance == .near, "it keeps the side and distance tapped")
        #expect(pin.targetSource == .breadcrumb)
        let car = try TrailPoint(latitude: #require(pin.latitude), longitude: #require(pin.longitude))
        let target = try TrailPoint(latitude: #require(pin.targetLatitude), longitude: #require(pin.targetLongitude))
        #expect(abs(Geo.distance(car, target) - Geo.metersPerMile) < 30)
        #expect(pin.latitude == 40.7128, "the car's position is kept separately from the estimate")
        #expect(TrailCoding.decode(pin.trail).count > 2)
        #expect(confirmations.count == 2, "the pin, then the +1")
    }

    @Test func dansExampleEndsTwoMilesBackFromWherePinned() throws {
        // Drop a pin, wait 6 s, +1, wait 4 s, +1.
        var trail = trailEndingAtFix(miles: 5)
        let current = fix(at: tap)
        let capture = CaptureService(
            context: container.mainContext,
            currentFix: { current },
            lateFix: { nil },
            trail: { trail },
            confirm: { _ in }
        )
        let pin = try #require(capture.capture(side: .unknown, distance: .unknown, source: .app, now: tap))
        // Whatever the live trail does meanwhile, "+1" measures from the trail as it was at the pin.
        trail = BreadcrumbBuffer()
        capture.milesBackTap(now: tap.addingTimeInterval(6))
        capture.milesBackTap(now: tap.addingTimeInterval(10))

        #expect(pin.milesBack == 2)
        #expect(try savedPins().count == 1)
        let car = try TrailPoint(latitude: #require(pin.latitude), longitude: #require(pin.longitude))
        let target = try TrailPoint(latitude: #require(pin.targetLatitude), longitude: #require(pin.targetLongitude))
        #expect(abs(Geo.distance(car, target) - 2 * Geo.metersPerMile) < 30)
    }

    @Test func plusOneDoesNothingWithoutAPinJustDropped() throws {
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 3))
        #expect(capture.milesBackTap(now: tap) == nil, "no pin of its own")
        #expect(capture.milesBackClosesAt(now: tap) == nil)

        let pin = try #require(capture.capture(side: .right, distance: .far, source: .app, now: tap))
        #expect(capture.milesBackClosesAt(now: tap) == tap.addingTimeInterval(10))
        #expect(capture.milesBackTap(now: tap.addingTimeInterval(11)) == nil, "more than 10 s after the pin")
        #expect(pin.milesBack == 0)
        #expect(try savedPins().count == 1)
    }

    @Test func eachPlusOneMustComeSoonAfterTheLast() throws {
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 5))
        let pin = try #require(capture.capture(side: .unknown, distance: .unknown, source: .app, now: tap))
        capture.milesBackTap(now: tap.addingTimeInterval(8))
        capture.milesBackTap(now: tap.addingTimeInterval(12.5))
        #expect(pin.milesBack == 2, "4.5 s after the last +1")
        #expect(capture.milesBackTap(now: tap.addingTimeInterval(18)) == nil, "5.5 s after the last +1, and well past the pin")
        #expect(pin.milesBack == 2)
    }

    @Test func onlyTheNewestCaptureScreenPinMoves() throws {
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 3))
        let first = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap))
        let second = try #require(capture.capture(side: .right, distance: .near, source: .app, now: tap.addingTimeInterval(2)))
        capture.capture(side: .left, distance: .near, source: .widget, now: tap.addingTimeInterval(3))
        let moved = capture.milesBackTap(now: tap.addingTimeInterval(4))
        #expect(moved === second, "widget and Siri pins don't count")
        #expect(first.milesBack == 0)
    }

    @Test func aDeletedPinIsNotMoved() throws {
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 3))
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap))
        pin.deletedAt = tap
        #expect(capture.milesBackTap(now: tap.addingTimeInterval(1)) == nil)
        #expect(pin.milesBack == 0)
    }

    @Test func aShortTrailStillGetsARoughPinOnTheMap() throws {
        // 0.3 mi of road heading north, then nothing: the rest of the mile carries on south.
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 0.3))
        let pin = try #require(capture.capture(side: .unknown, distance: .unknown, source: .app, now: tap))
        capture.milesBackTap(now: tap.addingTimeInterval(1))
        #expect(pin.targetSource == .heading)
        let car = try TrailPoint(latitude: #require(pin.latitude), longitude: #require(pin.longitude))
        let target = try TrailPoint(latitude: #require(pin.targetLatitude), longitude: #require(pin.targetLongitude))
        #expect(abs(Geo.distance(car, target) - Geo.metersPerMile) < 30)
        #expect(target.latitude < car.latitude, "back the way the car came")
        #expect(TrailCoding.decode(pin.trail).count > 2, "the part of the road that was recorded")
        #expect(pin.milesBackHint?.contains("rough guess") == true)
    }

    @Test func noTrailAndNoDirectionStaysInWords() throws {
        // Parked (too slow for a direction) with nothing recorded yet.
        let capture = service(currentFix: fix(at: tap, speed: 0), trail: BreadcrumbBuffer())
        let pin = try #require(capture.capture(side: .unknown, distance: .unknown, source: .app, now: tap))
        capture.milesBackTap(now: tap.addingTimeInterval(1))
        #expect(pin.targetSource == .textOnly)
        #expect(pin.targetCoordinate == nil && pin.trail == nil)
        #expect(pin.hasLocation, "the car's own position is still saved")
    }

    @Test func siriMilesBackSavesANewPinThatFarBack() throws {
        let capture = service(currentFix: fix(at: tap), trail: trailEndingAtFix(miles: 3))
        let pin = capture.captureMilesBack(source: .siri, miles: 2, now: tap)
        #expect(pin.milesBack == 2)
        #expect(pin.targetSource == .breadcrumb)
        #expect(try savedPins().count == 1)
    }

    @Test func milesBackWithNoGPSStillSavesAPin() throws {
        let capture = service(currentFix: nil, trail: BreadcrumbBuffer())
        let pin = capture.captureMilesBack(source: .siri, now: tap)
        #expect(try savedPins().count == 1)
        #expect(!pin.hasLocation)
        #expect(pin.targetSource == .textOnly)
    }

    // MARK: Failed saves

    private struct DiskFull: Error {}

    private final class FlakyStore {
        var failing = true
        var failures: [UUID] = []
    }

    private func failingService(_ store: FlakyStore, confirmations: Confirmations) -> CaptureService {
        CaptureService(
            context: container.mainContext,
            currentFix: { nil },
            lateFix: { nil },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in confirmations.count += 1 },
            failed: { store.failures.append($0.id) },
            persist: { context in
                if store.failing { throw DiskFull() }
                try context.save()
            }
        )
    }

    @Test func aFailedSaveIsNeverConfirmed() throws {
        let store = FlakyStore()
        let confirmations = Confirmations()
        let capture = failingService(store, confirmations: confirmations)
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .app, now: tap))
        #expect(confirmations.count == 0, "no success tone or haptic for a pin that isn't on disk")
        #expect(store.failures == [pin.id])
        #expect(!capture.isSaved(pin))

        store.failing = false
        #expect(capture.retrySave())
        #expect(capture.isSaved(pin))
    }

    @Test func aLaterSaveAlsoWritesTheEarlierPin() throws {
        let store = FlakyStore()
        let capture = failingService(store, confirmations: Confirmations())
        let first = try #require(capture.capture(side: .left, distance: .far, source: .widget, now: tap))
        #expect(!capture.isSaved(first))
        #expect(store.failures.isEmpty, "only phone taps get the failure haptic")

        store.failing = false
        let second = try #require(capture.capture(side: .right, distance: .near, source: .widget, now: tap.addingTimeInterval(2)))
        #expect(capture.isSaved(first) && capture.isSaved(second))
    }

    @Test func aFailedBumpIsNotConfirmed() throws {
        let store = FlakyStore()
        store.failing = false
        let confirmations = Confirmations()
        let capture = failingService(store, confirmations: confirmations)
        let pin = try #require(capture.capture(side: .unknown, distance: .unknown, source: .app, now: tap))
        #expect(confirmations.count == 1)

        store.failing = true
        capture.milesBackTap(now: tap.addingTimeInterval(1))
        #expect(pin.milesBack == 1)
        #expect(confirmations.count == 1, "the bump that didn't save gets no tone")
        #expect(store.failures == [pin.id])
        #expect(!capture.isSaved(pin))
    }

    @Test func aNoteThatDidNotSaveIsReported() {
        let store = FlakyStore()
        let capture = failingService(store, confirmations: Confirmations())
        let note = capture.addNote("call the farm", now: tap)
        #expect(!capture.isSaved(note))
        #expect(capture.saveState(of: note) == .notSaved)
    }

    @Test func aDiscardedNoteIsNotWrittenLater() throws {
        // A typed note that didn't save is taken back (its text stays in the box), so trying again
        // doesn't end up saving it twice.
        let store = FlakyStore()
        let capture = failingService(store, confirmations: Confirmations())
        let note = capture.addNote("call the farm", now: tap)
        capture.discardUnsaved(note)
        store.failing = false
        _ = capture.addNote("call the farm", now: tap.addingTimeInterval(5))
        #expect(try savedPins().filter(\.isNote).count == 1)
    }

    @Test func aLabelOrFixThatDidNotSaveIsPending() async throws {
        let store = FlakyStore()
        store.failing = false
        let capture = CaptureService(
            context: container.mainContext,
            currentFix: { nil },
            lateFix: { self.fix(at: self.tap.addingTimeInterval(2), speed: 0) },
            trail: { BreadcrumbBuffer() },
            confirm: { _ in },
            persist: { context in
                if store.failing { throw DiskFull() }
                try context.save()
            }
        )
        let pin = try #require(capture.capture(side: .left, distance: .far, source: .widget, now: tap))
        #expect(capture.saveState(of: pin) == .saved)

        store.failing = true
        #expect(!capture.setLabel("red barn", on: pin))
        #expect(capture.saveState(of: pin) == .changesPending, "on disk, but its label isn't")

        await capture.attachLateFix(to: pin)
        #expect(capture.saveState(of: pin) == .changesPending, "nor its position")

        store.failing = false
        #expect(capture.retrySave())
        #expect(capture.saveState(of: pin) == .saved)
    }
}
