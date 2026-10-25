import CoreLocation
import Foundation

extension CaptureService {
    /// The app's capture service: live GPS with the breadcrumb trail for "+1 mi back", a permission
    /// request on the first capture, and the haptic and tone for taps on the capture screen.
    @MainActor static let shared = CaptureService(
        context: SharedStore.context,
        currentFix: { LocationProvider.shared.freshFix() },
        lateFix: {
            LocationProvider.shared.requestPermissionIfNeeded()
            return await LocationProvider.shared.nextUsableFix(timeout: FixPolicy.lateFixWindow)
        },
        trail: { LocationProvider.shared.breadcrumbs },
        confirm: { CaptureFeedback.shared.confirmCapture(of: $0) },
        isPrecise: { LocationPrivacy.isPrecise }
    )
}
