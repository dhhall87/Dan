import Foundation
import SwiftData
import Testing
@testable import Passing

@MainActor
struct RetentionServiceTests {
    let container: ModelContainer
    let retention: RetentionService
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let day = RetentionPolicy.day

    init() throws {
        container = try ModelContainer(for: Pin.self, PinGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        retention = RetentionService(context: container.mainContext)
    }

    @discardableResult
    private func pin(capturedDaysAgo days: Double, from now: Date, kept: Bool = false, deletedDaysAgo: Double? = nil) -> Pin {
        let pin = Pin(capturedAt: now.addingTimeInterval(-days * day), side: .left, distance: .near, source: .app)
        pin.isKept = kept
        pin.deletedAt = deletedDaysAgo.map { now.addingTimeInterval(-$0 * day) }
        container.mainContext.insert(pin)
        return pin
    }

    private func allPins() throws -> [Pin] {
        try container.mainContext.fetch(FetchDescriptor<Pin>())
    }

    @Test func expiredPinMovesToRecentlyDeletedNow() throws {
        let fresh = pin(capturedDaysAgo: 7 - 1 / 86_400, from: start)
        let exactlySeven = pin(capturedDaysAgo: 7, from: start)
        let overdue = pin(capturedDaysAgo: 7 + 1 / 86_400, from: start)

        let summary = retention.run(now: start, keepIndefinitely: false)

        #expect(summary.expired == 2)
        #expect(fresh.deletedAt == nil)
        #expect(exactlySeven.deletedAt == start)
        #expect(overdue.deletedAt == start)
        #expect(try allPins().count == 3, "expired pins are moved, not destroyed")
    }

    @Test func keptPinStaysActive() {
        let kept = pin(capturedDaysAgo: 100, from: start, kept: true)
        retention.run(now: start, keepIndefinitely: false)
        #expect(kept.deletedAt == nil)
    }

    @Test func keepIndefinitelyStopsExpiryButNotThePurge() throws {
        let old = pin(capturedDaysAgo: 100, from: start)
        pin(capturedDaysAgo: 100, from: start, deletedDaysAgo: 31)

        let summary = retention.run(now: start, keepIndefinitely: true)

        #expect(summary == RetentionService.Summary(expired: 0, purged: 1))
        #expect(old.deletedAt == nil)
        #expect(try allPins().count == 1)
    }

    @Test func recentlyDeletedPurgesAfterThirtyDays() throws {
        let staying = pin(capturedDaysAgo: 40, from: start, deletedDaysAgo: 30 - 1 / 86_400)
        pin(capturedDaysAgo: 40, from: start, deletedDaysAgo: 30)

        let summary = retention.run(now: start, keepIndefinitely: false)

        #expect(summary.purged == 1)
        #expect(try allPins().map(\.id) == [staying.id])
    }

    @Test func appClosedForTwelveDaysThenOpened() throws {
        let opened = start.addingTimeInterval(12 * day)
        let dayZero = pin(capturedDaysAgo: 12, from: opened)
        let dayFive = pin(capturedDaysAgo: 7, from: opened)
        let dayEight = pin(capturedDaysAgo: 4, from: opened)
        let keptDayZero = pin(capturedDaysAgo: 12, from: opened, kept: true)
        let deletedDayZero = pin(capturedDaysAgo: 12, from: opened, deletedDaysAgo: 12)

        retention.run(now: opened, keepIndefinitely: false)

        // Both overdue pins land in Recently Deleted with a full 30 days from today.
        #expect(dayZero.deletedAt == opened)
        #expect(dayFive.deletedAt == opened)
        #expect(dayEight.deletedAt == nil)
        #expect(keptDayZero.deletedAt == nil)
        #expect(deletedDayZero.deletedAt == opened.addingTimeInterval(-12 * day), "already deleted pins keep their date")

        // Closed again for a month: everything in Recently Deleted is gone, the rest is untouched.
        retention.run(now: opened.addingTimeInterval(31 * day), keepIndefinitely: false)
        let remaining = Set(try allPins().map(\.id))
        #expect(remaining == [keptDayZero.id, dayEight.id])
        #expect(dayEight.deletedAt == opened.addingTimeInterval(31 * day), "it expired during the second break")
    }

    @Test func manualDeleteAndRecover() throws {
        let recent = pin(capturedDaysAgo: 2, from: start)
        retention.moveToRecentlyDeleted(recent, now: start)
        #expect(recent.deletedAt == start)

        retention.recover(recent, now: start)
        #expect(recent.deletedAt == nil)
        #expect(!recent.isKept, "a recent pin just goes back to normal")
    }

    @Test func recoveringAnExpiredPinKeepsItSoItDoesNotExpireAgain() {
        let old = pin(capturedDaysAgo: 9, from: start, deletedDaysAgo: 2)
        retention.recover(old, now: start)
        #expect(old.deletedAt == nil)
        #expect(old.isKept)

        retention.run(now: start, keepIndefinitely: false)
        #expect(old.deletedAt == nil)
    }

    @Test func deleteNowAndEmptyRecentlyDeleted() throws {
        let a = pin(capturedDaysAgo: 1, from: start, deletedDaysAgo: 1)
        pin(capturedDaysAgo: 1, from: start, deletedDaysAgo: 1)
        let active = pin(capturedDaysAgo: 1, from: start)

        retention.deleteNow(a)
        #expect(try allPins().count == 2)

        retention.emptyRecentlyDeleted()
        #expect(try allPins().map(\.id) == [active.id])
    }

    @Test func retentionWaitsForAnExportToFinish() throws {
        let overdue = pin(capturedDaysAgo: 8, from: start)

        let summaryDuringExport = retention.whilePaused {
            let summary = retention.run(now: start, keepIndefinitely: false)
            #expect(overdue.deletedAt == nil, "nothing changes mid-export")
            return summary
        }

        #expect(summaryDuringExport.deferred)
        #expect(overdue.deletedAt == start, "the clean-up ran as soon as the export finished")
    }

    @Test func exportWritesOnlyActivePins() throws {
        let active = pin(capturedDaysAgo: 1, from: start)
        active.label = "red barn"
        pin(capturedDaysAgo: 1, from: start, deletedDaysAgo: 1)

        let url = try ExportService.exportActivePins(as: .json, context: container.mainContext, retention: retention, now: start)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try PinExport.decodeJSON(try Data(contentsOf: url))
        #expect(document.pins.map(\.id) == [active.id])
        #expect(document.pins.first?.label == "red barn")
        #expect(url.pathExtension == "json")
    }
}
