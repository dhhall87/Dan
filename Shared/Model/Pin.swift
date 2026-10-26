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
    /// The folder it's filed in, if any. A pin is in at most one group.
    var group: PinGroup?
    /// A text note rather than a place: no location is recorded, and `label` holds the text.
    /// Added later, with a default, so the store migrates lightly.
    var isNote: Bool = false
    /// The Apple Maps Place ID of the business or landmark chosen from "What's here?", if any.
    /// Apple says Place IDs can be kept and used later. Added later, optional, so it migrates lightly.
    var placeID: String?

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

    /// Where the car was, as a point on the breadcrumb trail.
    var captureTrailPoint: TrailPoint? {
        guard let latitude, let longitude else { return nil }
        return TrailPoint(latitude: latitude, longitude: longitude)
    }

    /// True until the town has been looked up. Pins with no location have nothing to look up,
    /// unless they've been placed on the map by hand.
    var needsPlaceName: Bool { lookUpCoordinate != nil && placeName == nil }

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

    /// In Needs Review: a widget or Control Center pin not yet marked Reviewed.
    var needsReview: Bool { source.needsReviewUntilReviewed && !isReviewed }

    /// Moves the pin to where the thing actually is, picked on a map while reviewing. Where the car
    /// was stays as recorded; map links, Look Around, the town and exports follow the new spot.
    func moveTarget(to coordinate: CLLocationCoordinate2D) {
        targetLatitude = coordinate.latitude
        targetLongitude = coordinate.longitude
        targetSource = .manual
        placeName = nil
        // Moved by hand, so it's no longer that place.
        placeID = nil
    }

    /// "What's here?": this pin is that business or landmark. It takes the place's name as its label,
    /// moves to the place, and links to the place's own card in Apple Maps. The car's position stays.
    func choosePlace(name: String?, coordinate: CLLocationCoordinate2D, placeID: String?, town: String?) {
        moveTarget(to: coordinate)
        if let name, !name.isEmpty {
            label = name
        }
        self.placeID = placeID
        placeName = town
    }

    /// True when the fix was imprecise, or the car could have moved a fair way between fix and tap.
    var isApproximate: Bool {
        guard let fixTimestamp, let horizontalAccuracy else { return false }
        return FixPolicy.isApproximate(capturedAt: capturedAt, fixTimestamp: fixTimestamp, horizontalAccuracy: horizontalAccuracy, speed: speed)
    }

    var displayLabel: String {
        guard let label, !label.isEmpty else { return isNote ? "Empty note" : "Unlabeled" }
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

    /// The chosen place's own card when there is one, otherwise a pin at the spot.
    var appleMapsURL: URL? {
        if let placeID, !placeID.isEmpty {
            return MapLinks.applePlace(id: placeID)
        }
        guard let coordinate = lookUpCoordinate else { return nil }
        return MapLinks.apple(latitude: coordinate.latitude, longitude: coordinate.longitude, label: label)
    }

    /// For a chosen place, a search for its name and town, which usually opens that business in
    /// Google Maps; otherwise a pin at the spot.
    var googleMapsURL: URL? {
        if placeID != nil, let label, !label.isEmpty, let placeName, !placeName.isEmpty {
            return MapLinks.googleSearch(query: "\(label), \(placeName)")
        }
        guard let coordinate = lookUpCoordinate else { return nil }
        return MapLinks.google(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// "Precise location" off: keep only roughly where (about 1 km), the rough direction, no speed and
    /// no route. Done as the pin is saved, so the precise position is never stored.
    func coarsenLocation() {
        if let latitude, let longitude {
            self.latitude = CoarseLocation.round(latitude)
            self.longitude = CoarseLocation.round(longitude)
        }
        if let targetLatitude, let targetLongitude {
            self.targetLatitude = CoarseLocation.round(targetLatitude)
            self.targetLongitude = CoarseLocation.round(targetLongitude)
        }
        horizontalAccuracy = horizontalAccuracy.map { max($0, CoarseLocation.accuracy) }
        speed = nil
        course = course.map(CoarseLocation.roundCourse)
        trail = nil
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
