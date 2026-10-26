import Foundation
import Testing
@testable import Passing

struct RetentionPolicyTests {
    let captured = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let day = RetentionPolicy.day

    private func expires(after interval: TimeInterval, isKept: Bool = false, keepIndefinitely: Bool = false) -> Bool {
        RetentionPolicy.shouldExpire(capturedAt: captured, isKept: isKept, keepIndefinitely: keepIndefinitely, now: captured.addingTimeInterval(interval))
    }

    @Test func pinExpiresAtExactlySevenDays() {
        #expect(expires(after: 7 * day))
    }

    @Test func pinJustUnderSevenDaysStays() {
        #expect(!expires(after: 7 * day - 1))
    }

    @Test func pinJustOverSevenDaysExpires() {
        #expect(expires(after: 7 * day + 1))
    }

    @Test func keptPinNeverExpires() {
        #expect(!expires(after: 365 * day, isKept: true))
    }

    @Test func keepIndefinitelyStopsExpiry() {
        #expect(!expires(after: 365 * day, keepIndefinitely: true))
    }

    @Test func recentlyDeletedPurgesAtExactlyThirtyDays() {
        let deleted = captured
        #expect(!RetentionPolicy.shouldPurge(deletedAt: deleted, now: deleted.addingTimeInterval(30 * day - 1)))
        #expect(RetentionPolicy.shouldPurge(deletedAt: deleted, now: deleted.addingTimeInterval(30 * day)))
        #expect(RetentionPolicy.shouldPurge(deletedAt: deleted, now: deleted.addingTimeInterval(30 * day + 1)))
    }

    @Test func intervalsIgnoreTimeZonesAndDaylightSaving() {
        // 7 days is always 604,800 seconds, whatever the calendar does that week.
        #expect(RetentionPolicy.expiryDate(capturedAt: captured).timeIntervalSince(captured) == 604_800)
        #expect(RetentionPolicy.purgeDate(deletedAt: captured).timeIntervalSince(captured) == 2_592_000)
    }

    @Test func recoveringAnOldPinKeepsIt() {
        #expect(!RetentionPolicy.keepOnRecover(capturedAt: captured, now: captured.addingTimeInterval(2 * day)))
        #expect(RetentionPolicy.keepOnRecover(capturedAt: captured, now: captured.addingTimeInterval(8 * day)))
    }

    @Test func expiryCountdownText() {
        func text(after interval: TimeInterval) -> String? {
            RetentionPolicy.expiryText(capturedAt: captured, isKept: false, keepIndefinitely: false, now: captured.addingTimeInterval(interval))
        }
        #expect(text(after: 0) == "Expires in 7 days")
        #expect(text(after: 0.5 * day) == "Expires in 7 days", "6.5 days left rounds up")
        #expect(text(after: 5.5 * day) == "Expires in 2 days")
        #expect(text(after: 5.9 * day) == "Expires in 2 days")
        #expect(text(after: 6 * day) == "Expires in 1 day")
        #expect(text(after: 6.5 * day) == "Expires in under a day")
        #expect(text(after: 8 * day) == "Expires soon")
        #expect(RetentionPolicy.expiryText(capturedAt: captured, isKept: true, keepIndefinitely: false, now: captured) == nil)
        #expect(RetentionPolicy.expiryText(capturedAt: captured, isKept: false, keepIndefinitely: true, now: captured) == nil)
    }

    @Test func purgeCountdownText() {
        #expect(RetentionPolicy.purgeText(deletedAt: captured, now: captured) == "Deleted for good in 30 days")
        #expect(RetentionPolicy.purgeText(deletedAt: captured, now: captured.addingTimeInterval(29.5 * day)) == "Deleted for good in under a day")
    }
}

struct PinExportTests {
    let when = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func record(label: String? = nil, latitude: Double? = 40.7128, longitude: Double? = -74.006, group: String? = nil) -> PinRecord {
        PinRecord(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            capturedAt: when, fixTimestamp: when,
            latitude: latitude, longitude: longitude, horizontalAccuracy: 5,
            course: 225, courseReliable: true,
            side: "left", distance: "far", milesBack: 0,
            targetLatitude: nil, targetLongitude: nil, targetSource: "direct",
            trail: nil, label: label, placeName: nil, group: group, source: "app",
            isReviewed: false, isKept: true, deletedAt: nil,
            appleMapsURL: "https://maps.apple.com/?ll=40.712800,-74.006000&q=Passing%20pin",
            googleMapsURL: "https://www.google.com/maps/search/?api=1&query=40.712800,-74.006000"
        )
    }

    @Test func notesGoInEveryFormat() throws {
        var pin = record(label: "Red barn")
        pin.notes = "For sale, call after 5"
        #expect(PinExport.csv([pin]).contains(",\"For sale, call after 5\","), "quoted, because of the comma")
        let decoded = try PinExport.decodeJSON(PinExport.json([pin], exportedAt: when))
        #expect(decoded.pins.first?.notes == "For sale, call after 5")
        let kml = PinExport.kml([pin], title: "Passing pins", exportedAt: when)
        #expect(kml.contains("<Data name=\"Notes\"><value>For sale, call after 5</value></Data>"))
    }

    @Test func csvHasAHeaderAndOneRowPerPin() {
        var pin = record()
        // Map links contain commas (so they get quoted); leave them out to count fields simply.
        pin.appleMapsURL = nil
        pin.googleMapsURL = nil
        let lines = PinExport.csv([pin, pin]).components(separatedBy: "\r\n")
        #expect(lines.count == 4, "header, 2 rows, trailing empty line")
        #expect(lines[0] == PinExport.csvColumns.joined(separator: ","))
        #expect(lines[1].hasPrefix("11111111-2222-3333-4444-555555555555,"))
        #expect(lines[1].contains(",40.7128,-74.006,5.0,"))
        #expect(lines[1].split(separator: ",", omittingEmptySubsequences: false).count == PinExport.csvColumns.count)
    }

    @Test func csvQuotesLabelsWithCommasQuotesAndLineBreaks() {
        #expect(PinExport.csvField("plain") == "plain")
        #expect(PinExport.csvField("barn, red") == "\"barn, red\"")
        #expect(PinExport.csvField("the \"big\" one") == "\"the \"\"big\"\" one\"")
        #expect(PinExport.csvField("two\nlines") == "\"two\nlines\"")
    }

    @Test func csvLeavesMissingValuesEmpty() {
        let row = PinExport.csv([record(latitude: nil, longitude: nil)]).components(separatedBy: "\r\n")[1]
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        #expect(fields[3].isEmpty && fields[4].isEmpty)
    }

    @Test func jsonRoundTripsEveryField() throws {
        let pins = [record(label: "red barn, \"big\""), record(latitude: nil, longitude: nil)]
        let document = try PinExport.decodeJSON(try PinExport.json(pins, exportedAt: when))
        #expect(document.app == "Passing")
        #expect(document.exportedAt == when)
        #expect(document.pins == pins)
    }

    @Test func exportsNeverIncludeSpeed() throws {
        #expect(!PinExport.csvColumns.contains("speed"))
        let json = String(decoding: try PinExport.json([record()], exportedAt: when), as: UTF8.self)
        #expect(!json.contains("speed"))
    }

    @Test func csvIncludesTheGroup() throws {
        var pin = record(group: "Road trip")
        pin.appleMapsURL = nil
        pin.googleMapsURL = nil
        let row = PinExport.csv([pin]).components(separatedBy: "\r\n")[1]
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        let column = try #require(PinExport.csvColumns.firstIndex(of: "group"))
        #expect(fields[column] == "Road trip")
    }

    @Test func kmlPutsEachPinAtItsEstimateOrTheCar() {
        var milesBack = record(label: "diner")
        milesBack.milesBack = 2
        milesBack.targetLatitude = 40.7
        milesBack.targetLongitude = -74.1
        milesBack.targetSource = "breadcrumb"
        let kml = PinExport.kml([record(label: "red barn"), milesBack], title: "Passing pins", exportedAt: when)

        #expect(kml.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(kml.contains("<name>Passing pins</name>"))
        #expect(kml.contains("<coordinates>-74.006000,40.712800,0</coordinates>"), "longitude first, at the car")
        #expect(kml.contains("<coordinates>-74.100000,40.700000,0</coordinates>"), "at the miles-back estimate")
        #expect(kml.contains("Estimated spot, 2 miles back"))
        #expect(kml.contains("<Data name=\"Miles back\"><value>2 miles</value></Data>"))
        #expect(kml.components(separatedBy: "<Placemark>").count == 3)
    }

    @Test func kmlLeavesOutPinsWithoutALocationAndSaysSo() {
        let kml = PinExport.kml([record(), record(latitude: nil, longitude: nil)], title: "Passing pins", exportedAt: when)
        #expect(kml.components(separatedBy: "<Placemark>").count == 2)
        #expect(kml.contains("1 pin had no location and was left out."))
    }

    @Test func notesAreMarkedInCSVAndLeftOffTheMap() throws {
        var note = record(label: "Call about the farm sale", latitude: nil, longitude: nil)
        note.isNote = true
        note.appleMapsURL = nil
        note.googleMapsURL = nil
        let row = PinExport.csv([note]).components(separatedBy: "\r\n")[1]
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        let column = try #require(PinExport.csvColumns.firstIndex(of: "isNote"))
        #expect(fields[column] == "true")

        let kml = PinExport.kml([record(), note], title: "Passing pins", exportedAt: when)
        #expect(kml.components(separatedBy: "<Placemark>").count == 2)
        #expect(!kml.contains("left out"), "a note isn't a pin missing its location")
    }

    @Test func kmlIncludedIDsMatchItsPlacemarks() {
        var note = record(label: "note")
        note.id = UUID()
        note.isNote = true
        var noLocation = record(latitude: nil, longitude: nil)
        noLocation.id = UUID()
        let mapped = record(label: "barn")
        #expect(PinExport.includedIDs([mapped, note, noLocation], format: .kml) == [mapped.id])
        #expect(PinExport.includedIDs([mapped, note, noLocation], format: .json).count == 3)
    }

    @Test func kmlEscapesTextAndNamesUnlabeledPins() {
        let kml = PinExport.kml([record(label: "Tom & Jerry's <diner>"), record(group: "A \"B\"")], title: "Passing pins - Road trip", exportedAt: when)
        #expect(kml.contains("<name>Tom &amp; Jerry&apos;s &lt;diner&gt;</name>"))
        #expect(kml.contains("<name>Unlabeled</name>"))
        #expect(kml.contains("<value>A &quot;B&quot;</value>"))
        #expect(!kml.contains("<diner>"))
    }

    @Test func kmlTitleNamesTheGroup() {
        #expect(PinExport.kmlTitle(groupName: nil) == "Passing pins")
        #expect(PinExport.kmlTitle(groupName: "Road trip") == "Passing pins - Road trip")
    }

    @Test func fileNameUsesTheLocalDate() {
        let utc = TimeZone(identifier: "UTC")!
        let name = PinExport.fileName(format: .csv, exportedAt: Date(timeIntervalSince1970: 1_793_000_000), timeZone: utc)
        #expect(name == "Passing pins 2026-10-26.csv")
        #expect(PinExport.fileName(format: .json, exportedAt: Date(timeIntervalSince1970: 1_793_000_000), timeZone: utc).hasSuffix(".json"))
        #expect(PinExport.fileName(format: .kml, exportedAt: Date(timeIntervalSince1970: 1_793_000_000), groupName: "Trip 1/2", timeZone: utc)
                == "Passing pins - Trip 1-2 2026-10-26.kml")
    }
}
