import Foundation
import Testing
@testable import Passing

struct DriveLogTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 08:00:00 UTC
    let utc = TimeZone(identifier: "UTC")!

    private func entry(_ kind: DriveLogEntry.Kind, after seconds: TimeInterval = 0, source: String? = nil, outcome: String? = nil) -> DriveLogEntry {
        DriveLogEntry(at: start.addingTimeInterval(seconds), kind: kind, process: "app", source: source, outcome: outcome)
    }

    @Test func readsAsOneLine() {
        var late = entry(.lateFix, source: "widget", outcome: "attached")
        late.process = "widget"
        late.seconds = 2.34
        late.fixAge = 1.8
        late.accuracy = 6.4
        late.approximate = false
        #expect(late.line(timeZone: utc) == "2027-01-15 08:00:00  widget  lateFix  source=widget outcome=attached waited=2.3s fixAge=+1.8s accuracy=6m approximate=no")
    }

    @Test func durationsStayShort() {
        #expect(DriveLogFormat.duration(0.04) == "0.04s")
        #expect(DriveLogFormat.duration(0) == "0.00s")
        #expect(DriveLogFormat.duration(2.34) == "2.3s")
        #expect(DriveLogFormat.duration(5) == "5s")
        #expect(DriveLogFormat.duration(723) == "12m 03s")
        #expect(DriveLogFormat.duration(4_320) == "1h 12m")
        #expect(DriveLogFormat.median([3, 1, 2]) == 2)
        #expect(DriveLogFormat.median([1, 2, 3, 10]) == 2.5)
        #expect(DriveLogFormat.median([]) == nil)
    }

    @Test func storesOnlyWhatIsThere() throws {
        var gps = entry(.gps, outcome: "screen")
        gps.seconds = 600
        gps.count = 598
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(gps)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("fixAge") && !text.contains("accuracy"), "empty fields are left out")
        #expect(try decoder.decode(DriveLogEntry.self, from: data) == gps)
    }

    @Test func summaryAnswersTheCarQuestions() {
        var tapWithFix = entry(.capture, source: "app", outcome: "left-far")
        tapWithFix.fixAge = -0.4
        tapWithFix.saved = true
        tapWithFix.approximate = false
        var tapWithout = entry(.capture, after: 60, source: "app", outcome: "unknown-unknown")
        tapWithout.saved = true
        var widget = entry(.capture, after: 120, source: "widget", outcome: "left-near")
        widget.saved = true
        var attached = entry(.lateFix, after: 122, source: "widget", outcome: "attached")
        attached.seconds = 2.3
        attached.approximate = false
        var none = entry(.lateFix, after: 75, source: "app", outcome: "none")
        none.seconds = 15
        var answered = entry(.intent, after: 200, source: "siri", outcome: "answered")
        answered.seconds = 6
        var silent = entry(.intent, after: 300, source: "siri", outcome: "nothing")
        silent.seconds = 9
        var restart = entry(.trailRestart, after: 400, outcome: "gap")
        restart.seconds = 20
        var screen = entry(.gps, after: 900, outcome: "screen")
        screen.seconds = 900

        let lines = DriveLogSummary.lines(for: [tapWithFix, tapWithout, none, widget, attached, answered, silent, restart, screen], timeZone: utc)
        #expect(lines.first == "9 events, Jan 15 to Jan 15")
        #expect(lines.contains("Pins: 3 (app 2, widget 1)"))
        #expect(lines.contains("  With a position: 2 · approximate: 0 · not saved: 0"))
        #expect(lines.contains("  App taps with GPS ready at the tap: 1 of 2"))
        #expect(lines.contains("  app: 1 · no position: 1"))
        #expect(lines.contains("  widget: 1 · median 2.3s, slowest 2.3s"))
        #expect(lines.contains("  Siri's question: answered 1 · nothing said 1 · cancelled or failed 0"))
        #expect(lines.contains("Trail restarts: 1 (gap 1)"))
        #expect(lines.contains("GPS on with the capture screen: 1 time, 15m 00s in all, longest 15m 00s"))
    }

    @Test func listsEachVersionOnce() {
        var first = entry(.opened, outcome: "1.0.1 (build 2)")
        first.seconds = 0.8
        var again = entry(.opened, after: 3_600, outcome: "1.0.1 (build 2)")
        again.seconds = 0.6
        var updated = entry(.opened, after: 86_400, outcome: "1.0.2 (build 3)")
        updated.seconds = 0.7
        let lines = DriveLogSummary.lines(for: [first, again, updated], timeZone: utc)
        #expect(lines.contains("Versions: 1.0.1 (build 2), 1.0.2 (build 3)"))
        #expect(AppVersion.text(version: "1.0.1", build: "2") == "1.0.1 (build 2)")
    }

    @Test func watchPinsSayHowLongTheyTookToArrive() {
        var walk = entry(.capture, source: "watch", outcome: "left-far")
        walk.seconds = 95
        var later = entry(.capture, after: 3_600, source: "watch", outcome: "unknown-unknown")
        later.seconds = 4_000
        #expect(walk.line(timeZone: utc).hasSuffix("source=watch outcome=left-far arrived=1m 35s"))
        let lines = DriveLogSummary.lines(for: [walk, later], timeZone: utc)
        #expect(lines.contains("Pins: 2 (watch 2)"))
        #expect(lines.contains("  Apple Watch pins reached the iPhone: median 34m 08s, slowest 1h 06m"))
    }

    @Test func emptyLogSaysSo() {
        #expect(DriveLogSummary.lines(for: []) == ["Nothing logged yet."])
    }
}
