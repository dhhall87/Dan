import SwiftUI
import UIKit

/// The system share sheet (AirDrop, Files, Mail, …) for an exported file. `onFinish` runs once the
/// chosen app has taken the file (or the sheet was cancelled), so the copy can be deleted.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onFinish()
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
