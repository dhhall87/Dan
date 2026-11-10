import Foundation
import Testing
@testable import Passing

struct PinBackupTests {
    let made = Date(timeIntervalSinceReferenceDate: 800_000_000.25)

    private func item(_ id: UUID = UUID(), label: String? = "red barn") -> PinBackup.Item {
        PinBackup.Item(
            id: id, capturedAt: made, fixTimestamp: made.addingTimeInterval(-0.4),
            latitude: 40.7128, longitude: -74.006, horizontalAccuracy: 8,
            course: 92, courseReliable: true, side: "left", distance: "far", milesBack: 1,
            targetLatitude: 40.72, targetLongitude: -74.01, targetSource: "breadcrumb",
            trail: Data([1, 2, 3]), label: label, placeName: "Springfield", source: "widget",
            isReviewed: false, isKept: true, isNote: false, placeID: "I123", notes: "call after 5",
            group: "Houses",
            photos: [PinBackup.Photo(addedAt: made, image: Data([9, 8, 7]), thumbnail: Data([6]))]
        )
    }

    @Test func aBackupComesBackExactlyAsItWent() throws {
        let backup = PinBackup(
            createdAt: made,
            groups: [PinBackup.Group(name: "Houses", sortOrder: 2, createdAt: made)],
            pins: [item(), item(label: nil)]
        )
        #expect(try PinBackup.decode(try backup.encoded()) == backup, "times to the fraction of a second, photos and all")
    }

    @Test func otherFilesAreRefused() throws {
        #expect(throws: PinBackup.ReadError.notABackup) { try PinBackup.decode(Data("{\"app\":\"Passing\",\"pins\":[]}".utf8)) }
        #expect(throws: PinBackup.ReadError.notABackup) { try PinBackup.decode(Data("not json".utf8)) }
        var newer = PinBackup(createdAt: made, groups: [], pins: [])
        newer.version = PinBackup.currentVersion + 1
        #expect(throws: PinBackup.ReadError.newerVersion) { try PinBackup.decode(try newer.encoded()) }
    }

    @Test func restoringOnlyAddsPinsThatArentHere() {
        let here = UUID()
        let new = UUID()
        let backup = PinBackup(createdAt: made, groups: [], pins: [item(here), item(new), item(new)])
        #expect(backup.itemsToAdd(existing: [here]).map(\.id) == [new], "nothing replaced, and a repeat in the file added once")
        #expect(backup.itemsToAdd(existing: [here, new]).isEmpty, "restoring the same file again adds nothing")
    }

    @Test func namesAndMessagesReadPlainly() {
        let utc = TimeZone(identifier: "UTC")!
        #expect(PinBackup.fileName(createdAt: Date(timeIntervalSince1970: 1_800_000_000), timeZone: utc) == "Passing backup 2027-01-15.json")
        #expect(PinBackup.restoreMessage(added: 12, alreadyHere: 3) == "Added 12 pins. 3 were already here.")
        #expect(PinBackup.restoreMessage(added: 1, alreadyHere: 1) == "Added 1 pin. 1 was already here.")
        #expect(PinBackup.restoreMessage(added: 0, alreadyHere: 0) == "Added 0 pins.")
    }
}
