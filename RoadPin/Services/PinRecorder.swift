import CoreLocation
import Foundation
import Observation

/// Who asked for the pin. Decides whether RoadPin may listen for a note afterwards:
/// Apple doesn't allow apps to record audio while CarPlay is showing, so CarPlay taps rely on Siri for notes.
enum PinOrigin {
    case phone
    case carPlay
    case siri
}

/// Drops pins. Shared by the phone screen, CarPlay and Siri so they all behave the same way.
@MainActor
@Observable
final class PinRecorder {
    static let shared = PinRecorder()

    enum Status: Equatable {
        case idle
        case locating
        case saved(String)
        case listening(String)
        case failed(String)
    }

    /// Drives the banner on the phone screen.
    private(set) var status: Status = .idle
    /// Miles back for the pin the "+1 mi back" button is currently adjusting, 0 when none.
    private(set) var pendingMilesBack: Double = 0

    /// Extra "+1" taps within this many seconds push the same pin another mile back.
    static let milesBackWindow: TimeInterval = 4

    @ObservationIgnored private var milesBackPin: Pin?
    @ObservationIgnored private var milesBackTimer: Task<Void, Never>?
    @ObservationIgnored private var statusTimer: Task<Void, Never>?

    // MARK: Dropping pins

    /// Saves a pin where the car is right now.
    @discardableResult
    func dropPin(zone: RoadZone?, origin: PinOrigin, note: String? = nil) async -> Pin? {
        settlePendingMilesBackPin()
        PinStore.purgeExpired()
        setStatus(.locating)
        guard let location = await LocationTracker.shared.currentLocation(timeout: origin == .siri ? 6 : 8) else {
            fail(origin: origin)
            return nil
        }
        let pin = Pin(location: location, zone: zone)
        if let note { pin.note = note.trimmingCharacters(in: .whitespacesAndNewlines) }
        PinStore.insert(pin)
        lookUpPlaceName(for: pin)
        setStatus(.saved(zone.map { "Pin saved · \($0.title)" } ?? "Pin saved"), clearAfter: 3)
        if note == nil {
            askForNote(pin: pin, origin: origin, confirmation: "Saved.")
        }
        return pin
    }

    /// "+1 mi back": saves a pin one mile back along the road. Tapping again within a few seconds
    /// moves that same pin another mile back, so three quick taps means "3 miles back".
    @discardableResult
    func addMileBack(origin: PinOrigin) async -> Pin? {
        if let pin = milesBackPin, pin.modelContext != nil {
            pin.milesBack += 1
            place(pin, milesBack: pin.milesBack)
            PinStore.save()
        } else {
            setStatus(.locating)
            guard let location = await LocationTracker.shared.currentLocation() else {
                fail(origin: origin)
                return nil
            }
            let pin = Pin(location: location, zone: nil)
            place(pin, milesBack: 1)
            PinStore.insert(pin)
            milesBackPin = pin
        }
        guard let pin = milesBackPin else { return nil }
        pendingMilesBack = pin.milesBack
        setStatus(.saved("Pin saved \(Pin.formatMiles(pin.milesBack)) back · tap again to go further"))

        // Wait for more taps before naming it.
        milesBackTimer?.cancel()
        milesBackTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(PinRecorder.milesBackWindow))
            guard !Task.isCancelled, let self else { return }
            let finished = self.finishMilesBackPin()
            if let finished {
                self.lookUpPlaceName(for: finished)
                self.setStatus(.saved("Saved \(Pin.formatMiles(finished.milesBack)) back"), clearAfter: 3)
                self.askForNote(pin: finished, origin: origin, confirmation: "Saved, \(Pin.formatMiles(finished.milesBack)) back.")
            }
        }
        return pin
    }

    /// For Siri: one pin a given number of miles back, with its note already known.
    @discardableResult
    func dropPin(milesBack: Int, note: String) async -> Pin? {
        settlePendingMilesBackPin()
        PinStore.purgeExpired()
        guard let location = await LocationTracker.shared.currentLocation(timeout: 6) else { return nil }
        let pin = Pin(location: location, zone: nil)
        pin.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        place(pin, milesBack: Double(max(1, milesBack)))
        PinStore.insert(pin)
        lookUpPlaceName(for: pin)
        return pin
    }

    /// For Siri, after a CarPlay tap: put a note on the most recent pin.
    func nameLatestPin(_ note: String) -> Pin? {
        guard let pin = PinStore.recentPins(limit: 1).first,
              abs(pin.createdAt.timeIntervalSinceNow) < 60 * 60 else { return nil }
        pin.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        PinStore.save()
        return pin
    }

    // MARK: Helpers

    /// Moves a pin back along the recorded road. If we haven't recorded enough of the drive yet,
    /// the pin goes as far back as we can and remembers how much further to look.
    private func place(_ pin: Pin, milesBack: Double) {
        pin.milesBack = milesBack
        let meters = milesBack * Geo.metersPerMile
        guard let result = LocationTracker.shared.trail.point(metersBack: meters) else {
            pin.unresolvedMiles = milesBack
            return
        }
        pin.latitude = result.point.latitude
        pin.longitude = result.point.longitude
        pin.unresolvedMiles = max(0, meters - result.metersCovered) / Geo.metersPerMile
        pin.placeName = ""
    }

    /// A new pin interrupts a "+1 mi back" pin that was still waiting for more taps: keep it as is,
    /// skip asking for its note, but still fill in its street and town.
    private func settlePendingMilesBackPin() {
        if let pending = finishMilesBackPin() {
            lookUpPlaceName(for: pending)
        }
    }

    @discardableResult
    private func finishMilesBackPin() -> Pin? {
        let pin = milesBackPin
        milesBackPin = nil
        pendingMilesBack = 0
        milesBackTimer?.cancel()
        milesBackTimer = nil
        return pin
    }

    private func askForNote(pin: Pin, origin: PinOrigin, confirmation: String) {
        let mayListen = origin == .phone && !CarPlayState.isConnected && AppSettings.askWhatToLookUp
        guard mayListen else {
            if AppSettings.speakConfirmation && origin != .siri {
                Task { await VoicePrompter.shared.announce(confirmation) }
            }
            return
        }
        Task { @MainActor in
            self.setStatus(.listening(""))
            let heard = await VoicePrompter.shared.ask("What do you want to look up?") { [weak self] partial in
                self?.setStatus(.listening(partial))
            }
            guard pin.modelContext != nil else { return }
            if !heard.isEmpty {
                pin.note = heard
                PinStore.save()
                self.setStatus(.saved("Saved: \(heard)"), clearAfter: 3)
                if AppSettings.speakConfirmation {
                    await VoicePrompter.shared.announce("Got it.")
                }
            } else if case .listening = self.status {
                self.setStatus(.saved("Pin saved without a note"), clearAfter: 3)
            }
        }
    }

    private func fail(origin: PinOrigin) {
        let message = LocationTracker.shared.isDenied
            ? "Location is off for RoadPin"
            : "No GPS signal yet, try again in a moment"
        setStatus(.failed(message), clearAfter: 5)
        if origin != .siri && AppSettings.speakConfirmation {
            Task { await VoicePrompter.shared.announce("Couldn't find your location. Pin not saved.") }
        }
    }

    private func setStatus(_ newStatus: Status, clearAfter seconds: TimeInterval? = nil) {
        status = newStatus
        statusTimer?.cancel()
        guard let seconds else { return }
        statusTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.status == newStatus else { return }
            self.status = .idle
        }
    }

    private func lookUpPlaceName(for pin: Pin) {
        let location = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        Task { @MainActor in
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return }
            // The pin may have been deleted, or moved by another "+1" tap, while we waited.
            guard pin.modelContext != nil,
                  pin.latitude == location.coordinate.latitude,
                  pin.longitude == location.coordinate.longitude else { return }
            pin.placeName = PlaceName.describe(placemark)
            PinStore.save()
        }
    }
}

/// Whether the CarPlay screen is connected right now.
@MainActor
enum CarPlayState {
    static var isConnected = false
}

enum PlaceName {
    /// "Golden Gate Bridge, San Francisco, CA" or "Route 9, Hopkinton, MA".
    static func describe(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        func add(_ value: String?) {
            guard let value, !value.isEmpty, !parts.contains(value) else { return }
            parts.append(value)
        }
        add(placemark.areasOfInterest?.first)
        add(placemark.thoroughfare)
        add(placemark.locality ?? placemark.subAdministrativeArea)
        add(placemark.administrativeArea)
        return parts.joined(separator: ", ")
    }
}
