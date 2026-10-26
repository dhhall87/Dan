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
        let given = clean(label)
        let pin: Pin?
        if milesBack > 0 {
            pin = service.captureMilesBack(source: source, miles: Double(milesBack))
            if let given, let pin { service.setLabel(given, on: pin) }
        } else {
            pin = service.capture(side: side, distance: distance, source: source, label: given)
        }
        guard let pin else { return nil }

        if ask, given == nil {
            do {
                let answer = try await askForLabel()
                if let cleaned = clean(answer) {
                    service.setLabel(cleaned, on: pin)
                }
            } catch {
                // Cancelled, timed out or failed: the pin stays saved, unlabeled.
            }
        }

        await service.waitForLocation(of: pin)
        // One more try before reporting back, in case the first write failed.
        if !service.isSaved(pin) {
            service.retrySave()
        }
        return pin
    }

    /// Siri's spoken reply. Short, because it's heard while driving.
    static func dialog(for pin: Pin?, saved: Bool = true) -> String {
        guard saved else { return "Sorry, I couldn't save that pin. Please try again." }
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
