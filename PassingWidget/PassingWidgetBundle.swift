import SwiftUI
import WidgetKit

/// Everything the widget extension offers: two small widgets (both can go in CarPlay and StandBy)
/// and the Control Center control.
@main
struct PassingWidgetBundle: WidgetBundle {
    var body: some Widget {
        PinWidget()
        PinGridWidget()
        PinControl()
    }
}
