import UIKit

/// Draws the CarPlay grid icons: a little top-down road with the tapped zone lit up.
/// Each icon sits on its own dark tile so it reads the same in CarPlay's light and dark modes.
enum CarPlayIcons {
    /// CarPlay's maximum grid icon size.
    static let size = CGSize(width: 40, height: 40)

    private static let tileColor = UIColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 1)
    private static let asphalt = UIColor(red: 0.27, green: 0.29, blue: 0.33, alpha: 1)
    private static let roadside = UIColor(red: 0.16, green: 0.30, blue: 0.20, alpha: 1)
    private static let highlight = UIColor(red: 1.0, green: 0.78, blue: 0.0, alpha: 1)

    static func zone(_ zone: RoadZone, scale: CGFloat) -> UIImage {
        render(scale: scale) { rect in
            let columnWidth = rect.width / 4
            for (index, column) in RoadZone.allCases.enumerated() {
                let columnRect = CGRect(x: CGFloat(index) * columnWidth, y: 0, width: columnWidth, height: rect.height)
                (column == zone ? highlight : (column.isFar ? roadside : asphalt)).setFill()
                UIRectFill(columnRect)
            }
            UIColor.white.withAlphaComponent(0.9).setFill()
            UIRectFill(CGRect(x: columnWidth - 0.5, y: 0, width: 1, height: rect.height))
            UIRectFill(CGRect(x: columnWidth * 3 - 0.5, y: 0, width: 1, height: rect.height))
            drawCar(in: CGRect(x: rect.midX - 5, y: rect.midY - 9, width: 10, height: 18))
        }
    }

    static func symbol(_ name: String, scale: CGFloat) -> UIImage {
        render(scale: scale) { rect in
            let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
            guard let symbol = UIImage(systemName: name, withConfiguration: configuration)?
                .withTintColor(highlight, renderingMode: .alwaysOriginal) else { return }
            let origin = CGPoint(x: rect.midX - symbol.size.width / 2, y: rect.midY - symbol.size.height / 2)
            symbol.draw(at: origin)
        }
    }

    private static func render(scale: CGFloat, drawing: (CGRect) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let tile = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            tileColor.setFill()
            tile.fill()
            tile.addClip()
            drawing(rect)
        }
    }

    private static func drawCar(in rect: CGRect) {
        UIColor.white.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.35).fill()
        tileColor.setFill()
        let windshield = CGRect(x: rect.minX + 1.5, y: rect.minY + rect.height * 0.22, width: rect.width - 3, height: rect.height * 0.2)
        UIBezierPath(roundedRect: windshield, cornerRadius: 1.5).fill()
        let rearWindow = CGRect(x: rect.minX + 1.5, y: rect.minY + rect.height * 0.72, width: rect.width - 3, height: rect.height * 0.12)
        UIBezierPath(roundedRect: rearWindow, cornerRadius: 1.5).fill()
    }
}
