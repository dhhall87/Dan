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

    private func pin(_ label: String) -> Pin {
        let pin = Pin(capturedAt: now, side: .left, distance: .near, source: .app)
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
        #expect(PinGroups.all(in: context).map(\.name) == ["Houses to check", "Road trip"])
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
                                                     context: context, retention: retention, now: now)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try PinExport.decodeJSON(try Data(contentsOf: url))
        #expect(document.pins.map(\.label) == ["red barn"])
        #expect(document.pins.first?.group == "Road trip")
        #expect(url.lastPathComponent.hasPrefix("Passing pins - Road trip "))

        let kmlURL = try ExportService.exportActivePins(as: .kml, filter: .ungrouped, context: context, retention: retention, now: now)
        defer { try? FileManager.default.removeItem(at: kmlURL) }
        let kml = try String(contentsOf: kmlURL, encoding: .utf8)
        #expect(kml.contains("<name>diner</name>"))
        #expect(!kml.contains("red barn"))
    }
}
