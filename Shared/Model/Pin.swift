import CoreLocation
import Foundation
import SwiftData

/// One thing the driver passed. Records where the car was plus the driver's directional clue;
/// it never claims to know where the thing itself is.
@Model
final class Pin {
    var id: UUID = UUID()
    /// When the driver acted.
    var capturedAt: Date = Date()
    /// When the GPS fix was taken. Can differ from `capturedAt`; nil if no usable fix arrived.
    var fixTimestamp: Date?
    /// Where the car was. Set once and never overwritten; nil means "no location".
    var latitude: Double?
    var longitude: Double?
    /// Meters.
    var horizontalAccuracy: Double?
    /// Direction of travel in degrees (0 = north).
    var course: Double?
    /// False when the car was too slow (or GPS too unsure) for `course` to mean anything.
    var courseReliable: Bool = false
    /// Meters per second.
    var speed: Double?
    // Enums are stored as raw strings; use `side`, `distance`, `targetSource`, `source`.
    var sideRaw: String = Side.unknown.rawValue
    var distanceRaw: String = Distance.unknown.rawValue
    var milesBack: Double = 0
    /// Optional estimate of where the thing itself is (miles back). Separate from the car's position.
    var targetLatitude: Double?
    var targetLongitude: Double?
    var targetSourceRaw: String = TargetSource.direct.rawValue
    /// Encoded breadcrumb segment for miles-back pins.
    var trail: Data?
    var label: String?
    /// Town or area, filled in later from reverse geocoding.
    var placeName: String?
    var sourceRaw: String = CaptureSource.app.rawValue
    var isReviewed: Bool = false
    var isKept: Bool = false
    /// Set when the pin is in Recently Deleted.
    var deletedAt: Date?

    init(capturedAt: Date, side: Side, distance: Distance, source: CaptureSource) {
        self.capturedAt = capturedAt
        self.sideRaw = side.rawValue
        self.distanceRaw = distance.rawValue
        self.sourceRaw = source.rawValue
    }
}

extension Pin {
    var side: Side {
        get { Side(rawValue: sideRaw) ?? .unknown }
        set { sideRaw = newValue.rawValue }
    }

    var distance: Distance {
        get { Distance(rawValue: distanceRaw) ?? .unknown }
        set { distanceRaw = newValue.rawValue }
    }

    var targetSource: TargetSource {
        get { TargetSource(rawValue: targetSourceRaw) ?? .direct }
        set { targetSourceRaw = newValue.rawValue }
    }

    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    /// The car's position, if a usable fix was recorded.
    var captureCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var targetCoordinate: CLLocationCoordinate2D? {
        guard let targetLatitude, let targetLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: targetLatitude, longitude: targetLongitude)
    }

    /// Where map links point: the estimated target if there is one, otherwise where the car was.
    var lookUpCoordinate: CLLocationCoordinate2D? {
        targetCoordinate ?? captureCoordinate
    }

    /// True when the fix was imprecise, or the car could have moved a fair way between fix and tap.
    var isApproximate: Bool {
        guard let fixTimestamp, let horizontalAccuracy else { return false }
        return FixPolicy.isApproximate(capturedAt: capturedAt, fixTimestamp: fixTimestamp, horizontalAccuracy: horizontalAccuracy, speed: speed)
    }

    var displayLabel: String {
        guard let label, !label.isEmpty else { return "Unlabeled" }
        return label
    }

    var sideAndDistance: String? {
        PinDescription.sideAndDistance(side: side, distance: distance)
    }

    /// "2 mi back", or nil for ordinary pins.
    var milesBackText: String? {
        milesBack > 0 ? "\(Geo.shortMilesText(milesBack)) back" : nil
    }

    /// How to find a miles-back pin's spot ("Placed 2 miles back along the road you drove…").
    var milesBackHint: String? {
        PinDescription.milesBackHint(milesBack: milesBack, targetSource: targetSource, course: course, courseReliable: courseReliable)
    }

    /// The road driven between the miles-back estimate and the tap, for the review map.
    var trailCoordinates: [CLLocationCoordinate2D] {
        TrailCoding.decode(trail).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var appleMapsURL: URL? {
        guard let coordinate = lookUpCoordinate else { return nil }
        return MapLinks.apple(latitude: coordinate.latitude, longitude: coordinate.longitude, label: label)
    }

    var googleMapsURL: URL? {
        guard let coordinate = lookUpCoordinate else { return nil }
        return MapLinks.google(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Stamps the car's position from a GPS fix. Does nothing if the pin already has one,
    /// so capture coordinates are never overwritten.
    func applyFix(_ fix: CLLocation) {
        guard !hasLocation else { return }
        latitude = fix.coordinate.latitude
        longitude = fix.coordinate.longitude
        fixTimestamp = fix.timestamp
        horizontalAccuracy = fix.horizontalAccuracy
        speed = fix.speed >= 0 ? fix.speed : nil
        course = fix.course >= 0 ? fix.course : nil
        courseReliable = FixPolicy.isCourseReliable(course: fix.course, courseAccuracy: fix.courseAccuracy, speed: fix.speed)
    }
}
