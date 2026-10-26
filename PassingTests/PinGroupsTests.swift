import Foundation
import SwiftData
import Testing
@testable import Passing

@MainActor
struct PinGroupsTests {
    let container: ModelContainer
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelContainer(for: Pin.self, PinGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private var context: ModelContext { container.mainContext }

    private func pin(_ label: String, source: CaptureSource = .app) -> Pin {
        let pin = Pin(capturedAt: now, side: .left, distance: .near, source: source)
        pin.label = label
        pin.latitude = 37.7
        pin.longitude = -100.3
        context.insert(pin)
        return pin
    }

    @Test func namesMustBeUniqueAndNotBlank() throws {
        #expect(PinGroups.create(named: "Road trip", in: context) != nil)
        #expect(PinGroups.create(named: "road trip", in: context) == nil)
        #expect(PinGroups.create(named: "  ", in: context) == nil)
        let houses = try #require(PinGroups.create(named: "Houses", in: context))
        #expect(!PinGroups.rename(houses, to: "Road Trip", in: context))
        #expect(PinGroups.rename(houses, to: "Houses to check", in: context))
        #expect(PinGroups.all(in: context).map(\.name) == ["Road trip", "Houses to check"], "new groups go at the bottom")
    }

    @Test func dragsPutGroupsInDansOrder() throws {
        for name in ["Road trip", "Houses", "Diners"] {
            _ = try #require(PinGroups.create(named: name, in: context))
        }
        // Drag Diners to the top.
        PinGroups.reorder(PinGroups.all(in: context), fromOffsets: [2], toOffset: 0, in: context)
        #expect(PinGroups.all(in: context).map(\.name) == ["Diners", "Road trip", "Houses"])
        // A group made later still goes at the bottom.
        _ = try #require(PinGroups.create(named: "Barns", in: context))
        #expect(PinGroups.all(in: context).map(\.name).last == "Barns")
    }

    @Test func groupsFromBeforeReorderingListByName() throws {
        // Groups saved before sortOrder existed all read as 0.
        for name in ["Road trip", "Diners"] {
            context.insert(PinGroup(name: name))
        }
        #expect(PinGroups.all(in: context).map(\.name) == ["Diners", "Road trip"])
    }

    @Test func newGroupFromAMenuReusesAnExistingName() throws {
        let trip = try #require(PinGroups.create(named: "Road trip", in: context))
        #expect(PinGroups.createOrFind(named: " road TRIP ", in: context)?.id == trip.id)
        #expect(PinGroups.createOrFind(named: "Houses", in: context)?.name == "Houses")
        #expect(PinGroups.createOrFind(named: "  ", in: context) == nil)
        #expect(PinGroups.all(in: context).count == 2)
    }

    @Test func aPinIsInAtMostOneGroup() throws {
        let trip = try #require(PinGroups.create(named: "Road trip", in: context))
        let houses = try #require(PinGroups.create(named: "Houses", in: context))
        let barn = pin("red barn")
        PinGroups.move(barn, to: trip, in: context)
        PinGroups.move(barn, to: houses, in: context)
        #expect(barn.group?.id == houses.id)
        #expect(trip.pins.isEmpty)
        PinGroups.move(barn, to: nil, in: context)
        #expect(barn.group == nil)
    }

    @Test func filingANeedsReviewPinMarksItReviewed() throws {
        let trip = try #require(PinGroups.create(named: "Road trip", in: context))
        let fromWidget = pin("barn", source: .widget)
        let fromControl = pin("silo", source: .control)
        let fromPhone = pin("diner")
        #expect(fromWidget.needsReview && fromControl.needsReview)

        PinGroups.move(fromWidget, to: nil, in: context)
        #expect(fromWidget.needsReview, "taking a pin out of a group isn't a review")

        PinGroups.move([fromWidget, fromControl, fromPhone], to: trip, in: context)
        #expect(fromWidget.isReviewed && fromControl.isReviewed)
        #expect(!fromWidget.needsReview && !fromControl.needsReview)
        #expect(!fromPhone.isReviewed, "phone pins were never in Needs Review, so they're left as they were")
    }

    @Test func severalPinsMoveTogether() throws {
        let trip = try #require(PinGroups.create(named: "Road trip", in: context))
        let pins = [pin("red barn"), pin("diner"), pin("silo")]
        PinGroups.move(Array(pins.prefix(2)), to: trip, in: context)
        #expect(pins.map { $0.group?.id } == [trip.id, trip.id, nil])
        PinGroups.move(pins, to: nil, in: context)
        #expect(pins.allSatisfy { $0.group == nil })
    }

    @Test func deletingAGroupKeepsItsPins() throws {
        let trip = try #require(PinGroups.create(named: "Road trip", in: context))
        let barn = pin("red barn")
        let diner = pin("diner")
        PinGroups.move(barn, to: trip, in: context)
        PinGroups.move(diner, to: trip, in: context)

        PinGroups.delete(trip, in: context)

        let pins = try context.fetch(FetchDescriptor<Pin>())
        #expect(pins.count == 2)
        #expect(pins.allSatisfy { $0.group == nil })
        #expect(PinGroups.all(in: context).isEmpty)
    }

    @Test func exportFollowsTheGroupBeingShown() throws {
        let trip = try #require(PinGroups.create(named: "Road trip", in: context))
        let barn = pin("red barn")
        _ = pin("diner")
        PinGroups.move(barn, to: trip, in: context)
        let retention = RetentionService(context: context)

        let url = try ExportService.exportActivePins(as: .json, filter: .group(trip.id), groupName: trip.name,
                                                     context: context, retention: retention, now: now).url
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try PinExport.decodeJSON(try Data(contentsOf: url))
        #expect(document.pins.map(\.label) == ["red barn"])
        #expect(document.pins.first?.group == "Road trip")
        #expect(url.lastPathComponent.hasPrefix("Passing pins - Road trip "))

        let kmlURL = try ExportService.exportActivePins(as: .kml, filter: .ungrouped, context: context, retention: retention, now: now).url
        defer { try? FileManager.default.removeItem(at: kmlURL) }
        let kml = try String(contentsOf: kmlURL, encoding: .utf8)
        #expect(kml.contains("<name>diner</name>"))
        #expect(!kml.contains("red barn"))
    }

    @Test func kmlReportsOnlyThePinsItContains() throws {
        let mapped = pin("barn")
        let noLocation = pin("no gps")
        noLocation.latitude = nil
        noLocation.longitude = nil
        let note = pin("call about the farm")
        note.isNote = true
        note.latitude = nil
        note.longitude = nil
        let retention = RetentionService(context: context)

        let kml = try ExportService.exportActivePins(as: .kml, context: context, retention: retention, now: now)
        defer { try? FileManager.default.removeItem(at: kml.url) }
        #expect(kml.pinIDs == [mapped.id], "Delete after exporting must leave the note and the no-location pin alone")

        let csv = try ExportService.exportActivePins(as: .csv, context: context, retention: retention, now: now)
        defer { try? FileManager.default.removeItem(at: csv.url) }
        #expect(csv.pinIDs == [mapped.id, noLocation.id, note.id])
    }
}
