import SwiftUI

/// The capture colors, shared with the widget so its buttons match the phone screen.
extension Color {
    /// Near zones: green, like the grass verge.
    static let nearZone = Color(red: 0.13, green: 0.38, blue: 0.25)
    /// Far zones: blue, like the distance.
    static let farZone = Color(red: 0.15, green: 0.28, blue: 0.55)
    static let quickSurface = Color(white: 0.13)
    /// Dark amber, so "+1 mi back" stands apart from the zones.
    static let milesBackSurface = Color(red: 0.42, green: 0.29, blue: 0.04)
}
