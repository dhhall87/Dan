import Foundation

/// What "Precise location" off keeps: the area to about a kilometer and the rough direction, but
/// no speed and no route. Enough to answer "what town was that", not "which driveway".
enum CoarseLocation {
    /// The accuracy recorded for a coarse pin, in meters.
    static let accuracy: Double = 1_000

    /// Two decimal places of latitude or longitude: about 1 km north to south.
    static func round(_ degrees: Double) -> Double {
        (degrees * 100).rounded() / 100
    }

    /// To the nearest of the eight compass directions (0, 45, 90 … 315 degrees).
    static func roundCourse(_ course: Double) -> Double {
        ((course / 45).rounded() * 45).truncatingRemainder(dividingBy: 360)
    }
}
