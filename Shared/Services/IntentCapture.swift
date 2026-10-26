import Foundation

/// What every capture from an App Intent does (Siri, Shortcuts, the widget, Control Center), in order:
/// 1. Save the pin through `CaptureService`, straight away.
/// 2. If there's no label and asking is allowed (Siri only), ask "What did you see?". A cancelled,
///    unanswered or failed question just leaves the pin unlabeled; it never loses it.
/// 3. Give the location a moment to arrive before finishing, so iOS doesn't suspend Passing first.
@MainActor
enum IntentCapture {
    static let question = "What did you see?"

    @discardableResult
    static func run(
        service: CaptureService,
        source: CaptureSource,
        side: Side = .unknown,
        distance: Distance = .unknown,
        milesBack: Int = 0,
        label: String? = nil,
        ask: Bool,
        askForLabel: () async throws -> String?
    ) async -> Pin? {
        let started = Date.now
        let given = clean(label)
        let pin: Pin?
        if milesBack > 0 {
            pin = service.captureMilesBack(source: source, miles: Double(milesBack))
            if let given, let pin { service.setLabel(given, on: pin) }
        } else {
            pin = service.capture(side: side, distance: distance, source: source, label: given)
        }
        guard let pin else { return nil }

        // For the drive log: how Siri's question went.
        var question = given == nil ? "notAsked" : "labelGiven"
        if ask, given == nil {
            do {
                let answer = try await askForLabel()
                if let cleaned = clean(answer) {
                    service.setLabel(cleaned, on: pin)
                    question = "answered"
                } else {
                    question = "nothing"
                }
            } catch {
                // Cancelled, timed out or failed: the pin stays saved, unlabeled.
                question = "error-\(type(of: error))-\((error as NSError).code)"
            }
        }

        await service.waitForLocation(of: pin)
        // One more try before reporting back, in case the first write failed.
        if !service.isSaved(pin) {
            service.retrySave()
        }
        DriveLog.record(DriveLogEntry(
            at: .now, kind: .intent, source: source.rawValue, outcome: question,
            seconds: Date.now.timeIntervalSince(started), saved: service.isSaved(pin)
        ))
        // The request is about to finish, and iOS may suspend the process right after.
        DriveLog.flush()
        return pin
    }

    /// Siri's spoken reply, from what's actually on disk.
    static func dialog(for pin: Pin?, service: CaptureService) -> String {
        dialog(for: pin, state: pin.map { service.saveState(of: $0) } ?? .saved)
    }

    /// Siri's spoken reply. Short, because it's heard while driving. It never says "Saved" for
    /// anything that's only in memory. A pin that didn't save stays pending and is written by the
    /// next save that works, so it doesn't ask for another try (that would make a duplicate).
    static func dialog(for pin: Pin?, state: CaptureService.SaveState) -> String {
        switch state {
        case .notSaved: return "Sorry, I couldn't save that pin."
        case .changesPending: return "I saved the pin, but not all of its details. Check it in Passing later."
        case .saved: break
        }
        guard let pin else { return "Saved." }
        var text: String
        if pin.milesBack > 0 {
            text = "Saved, \(Geo.milesText(pin.milesBack)) back."
        } else if let label = pin.label, !label.isEmpty {
            text = "Saved “\(label)”."
        } else {
            text = "Saved."
        }
        if !pin.hasLocation {
            text += " I couldn't get your location, so it has the time only."
        }
        return text
    }

    static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
