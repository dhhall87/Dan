import CoreLocation
import Foundation

extension CaptureService {
    /// The widget extension's capture service. Each capture runs a short GPS burst here, in the
    /// extension. It never asks for permission (an extension can't show the prompt; the app asks on
    /// its first capture). There's no breadcrumb trail, because "+1 mi back" needs the app open,
    /// and no tone, because widget and Control Center captures are silent.
    @MainActor static let shared = CaptureService(
        context: SharedStore.context,
        currentFix: { LocationProvider.shared.freshFix() },
        lateFix: { await LocationProvider.shared.nextUsableFix(timeout: FixPolicy.lateFixWindow) },
        trail: { BreadcrumbBuffer() },
        confirm: { _ in }
    )
}
