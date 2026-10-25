import AppIntents
import Foundation

/// "Hey Siri, drop a RoadPin" → "What do you want to look up?" → "that big red barn".
/// Works hands-free from the steering-wheel voice button in CarPlay, AirPods, or the iPhone Action Button.
struct DropPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Drop a RoadPin"
    static let description = IntentDescription("Saves where you are right now, with a note about what to look up later.")

    @Parameter(title: "What to look up", requestValueDialog: "What do you want to look up?")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let pin = await PinRecorder.shared.dropPin(zone: nil, origin: .siri, note: note) else {
            return .result(dialog: "I couldn't find your location, so I didn't save a pin.")
        }
        return .result(dialog: "Saved \(pin.title).")
    }
}

/// "Hey Siri, I missed something in RoadPin" → "How many miles back?" → "two" → "What do you want to look up?"
struct DropPinBehindIntent: AppIntent {
    static let title: LocalizedStringResource = "Drop a RoadPin Miles Back"
    static let description = IntentDescription("Saves a spot you already drove past, a number of miles back along the road.")

    @Parameter(title: "Miles back", requestValueDialog: "How many miles back was it?")
    var miles: Int

    @Parameter(title: "What to look up", requestValueDialog: "What do you want to look up?")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let milesBack = min(max(miles, 1), 50)
        guard let pin = await PinRecorder.shared.dropPin(milesBack: milesBack, note: note) else {
            return .result(dialog: "I couldn't find your location, so I didn't save a pin.")
        }
        if pin.isApproximate {
            return .result(dialog: "Saved \(pin.title). I only had part of your drive, so look a little further back than the pin.")
        }
        return .result(dialog: "Saved \(pin.title), \(Pin.formatMiles(pin.milesBack)) back.")
    }
}

/// For pins dropped with a CarPlay tap (CarPlay doesn't let RoadPin use the microphone itself):
/// "Hey Siri, name my last RoadPin" → "What do you want to look up?"
struct NameLastPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Name My Last RoadPin"
    static let description = IntentDescription("Adds a note to the pin you dropped most recently.")

    @Parameter(title: "What to look up", requestValueDialog: "What do you want to look up?")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard PinRecorder.shared.nameLatestPin(note) != nil else {
            return .result(dialog: "You haven't dropped a pin in the last hour.")
        }
        return .result(dialog: "Got it, \(note).")
    }
}

struct RoadPinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DropPinIntent(),
            phrases: [
                "Drop a \(.applicationName)",
                "Drop a pin in \(.applicationName)",
                "Mark this in \(.applicationName)",
                "Save this spot in \(.applicationName)",
            ],
            shortTitle: "Drop Pin",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: DropPinBehindIntent(),
            phrases: [
                "I missed something in \(.applicationName)",
                "Drop a pin behind me in \(.applicationName)",
            ],
            shortTitle: "Pin Miles Back",
            systemImageName: "arrow.uturn.backward"
        )
        AppShortcut(
            intent: NameLastPinIntent(),
            phrases: [
                "Name my last \(.applicationName)",
                "Add a note in \(.applicationName)",
            ],
            shortTitle: "Name Last Pin",
            systemImageName: "text.bubble"
        )
    }
}
