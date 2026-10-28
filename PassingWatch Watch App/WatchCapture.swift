import Foundation
import Observation
import WatchKit

/// The watch's single save path: every button calls `capture`. Save first: the pin is written to
/// the outbox file at once, with the watch's own GPS reading if a fresh one is there, otherwise the
/// first usable one within 15 s. Then it's queued for the iPhone, and stays on the watch until the
/// iPhone says it's saved. A wrist tap confirms; nothing on screen asks anything.
@MainActor
@Observable
final class WatchCapture {
    static let shared = WatchCapture()

    /// A button's brief tick after it saved.
    struct Tap: Equatable {
        var side: Side
        var distance: Distance
        var at: Date
        /// False if the pin couldn't be written on the watch.
        var saved: Bool
    }

    private(set) var outbox: WatchOutbox
    private(set) var lastTap: Tap?
    let location = WatchLocation()

    @ObservationIgnored private let link = PhoneLink()
    @ObservationIgnored private var debouncer = TapDebouncer<String>(interval: 0.75)
    @ObservationIgnored private var giveUpTask: Task<Void, Never>?
    /// Pins that reached the iPhone but were never confirmed are sent again once per launch.
    @ObservationIgnored private var resentThisLaunch = false

    private init() {
        outbox = WatchOutboxFile.load()
        location.onFix = { [weak self] fix in self?.received(fix) }
        link.onActivated = { [weak self] in self?.sendReady() }
        link.onDelivered = { [weak self] id in self?.delivered(id) }
        link.onSaved = { [weak self] ids in self?.confirmSaved(ids) }
        link.activate()
    }

    /// Saves a pin now. A repeat tap on the same button within 0.75 s is ignored.
    func capture(side: Side, distance: Distance, now: Date = .now) {
        guard debouncer.shouldAccept("\(side.rawValue)-\(distance.rawValue)", at: now) else { return }
        let pin = WatchPin(id: UUID(), capturedAt: now, side: side, distance: distance, fix: location.freshFix(now: now))
        outbox.add(pin, waitForFix: location.mayGetFix)
        let saved = WatchOutboxFile.save(outbox)
        WKInterfaceDevice.current().play(saved ? .success : .failure)
        lastTap = Tap(side: side, distance: distance, at: now, saved: saved)
        if outbox.isWaitingForFix {
            location.setPinsWaiting(true)
            scheduleGiveUp()
        }
        sendReady()
    }

    /// Passing came on screen.
    func becameActive() {
        location.requestPermissionIfNeeded()
        location.setOnScreen(true)
        giveUpWaiting(now: .now)
        sendReady()
    }

    /// The wrist went down: the screen dims, but pins still waiting keep their GPS for now.
    func becameInactive() {
        location.setOnScreen(false)
    }

    /// Passing is going to the background, where no reading can come: pins still waiting go to the
    /// iPhone without a location, and the transfer carries on while Passing is suspended.
    func wentToBackground() {
        giveUpTask?.cancel()
        location.stopAll()
        if !outbox.stopWaiting(now: .now, all: true).isEmpty {
            WatchOutboxFile.save(outbox)
        }
        sendReady()
    }

    // MARK: Private

    private func received(_ fix: WatchFix) {
        guard outbox.isWaitingForFix else { return }
        if !outbox.attach(fix, now: .now).isEmpty {
            WatchOutboxFile.save(outbox)
            sendReady()
        }
        location.setPinsWaiting(outbox.isWaitingForFix)
    }

    /// Once the newest waiting pin's 15 s are up, the ones still without a reading go without one.
    private func scheduleGiveUp() {
        giveUpTask?.cancel()
        giveUpTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(FixPolicy.lateFixWindow + 0.5))
            guard !Task.isCancelled else { return }
            self?.giveUpWaiting(now: .now)
        }
    }

    private func giveUpWaiting(now: Date) {
        if !outbox.stopWaiting(now: now).isEmpty {
            WatchOutboxFile.save(outbox)
            sendReady()
        }
        location.setPinsWaiting(outbox.isWaitingForFix)
    }

    private func sendReady() {
        guard link.isActivated else { return }
        let resendAt: Date? = resentThisLaunch ? nil : .now
        resentThisLaunch = true
        link.send(outbox.readyToSend(excluding: link.inFlight, resendingAt: resendAt))
    }

    private func delivered(_ id: UUID) {
        outbox.markDelivered(id, at: .now)
        WatchOutboxFile.save(outbox)
    }

    private func confirmSaved(_ ids: [UUID]) {
        let before = outbox.count
        outbox.confirmSaved(ids)
        if outbox.count != before {
            WatchOutboxFile.save(outbox)
        }
    }
}

/// The outbox on the watch's disk, so pins survive Passing being closed or the watch restarting.
enum WatchOutboxFile {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "WatchOutbox.json")
    }

    static func load() -> WatchOutbox {
        guard let data = try? Data(contentsOf: url),
              let outbox = try? JSONDecoder().decode(WatchOutbox.self, from: data)
        else { return WatchOutbox() }
        return outbox
    }

    /// - Returns: whether the outbox is on disk.
    @discardableResult
    static func save(_ outbox: WatchOutbox) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(outbox).write(to: url, options: .atomic)
            return true
        } catch {
            print("Passing: watch outbox not saved: \(error)")
            return false
        }
    }
}
