import SwiftUI
import UIKit

/// Settings → Appearance. Follows the iPhone's Light/Dark setting unless the driver picks one.
/// The capture screen stays dark either way (see `RootView`).
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Applies the choice to Passing's whole window, sheets included. SwiftUI's
    /// `preferredColorScheme` only reaches the screen it's set on (so Settings, being a sheet, kept
    /// following the iPhone) and doesn't reliably switch back to "System" once set, so this uses the
    /// window's own override instead.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}
