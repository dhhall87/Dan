import AppIntents
import SwiftUI
import WidgetKit

/// The Control Center button. It can also go on the Lock Screen or the Action Button. One tap saves
/// a pin without opening Passing, and nothing is asked.
struct PinControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "PinControl") {
            ControlWidgetButton(action: ControlPinIntent()) {
                Label("Pin That", systemImage: "mappin.and.ellipse")
            }
        }
        .displayName("Pin That")
        .description("Saves where you are right now, without opening Passing.")
    }
}
