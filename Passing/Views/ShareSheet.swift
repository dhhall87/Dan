import SwiftUI
import UIKit

/// The system share sheet (AirDrop, Files, Mail, …) for an exported file. `onFinish` runs once the
/// chosen app has taken the file, or the sheet was cancelled; it's told which (true when shared).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: (_ shared: Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
