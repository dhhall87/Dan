import Foundation

/// One stop on a multi-stop route: a pin's spot, or a start or end place.
struct RouteStop: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
}

enum RouteMode: String, CaseIterable, Identifiable {
    case driving
    case walking

    var id: String { rawValue }
    var title: String { self == .driving ? "Driving" : "Walking" }
}

/// Where a route starts or ends, other than its pins.
enum RouteEndpoint: Equatable {
    /// The first selected pin (as the start) or the last (as the end).
    case pin
    /// Wherever the iPhone is when the route opens. Apple Maps and Google Maps fill it in
    /// themselves when a link leaves the start out. Start only.
    case currentLocation
    /// A saved place (Home, Work) or a found address.
    case place(RouteStop)
}

/// A multi-stop route through selected pins, in the order they were picked, and the links that open
/// it in Apple Maps or Google Maps. Plain values, so the rules are easy to unit test.
struct RoutePlan: Equatable {
    /// Most pins one route takes. Each road leg is one directions request (Apple limits how many a
    /// phone can make in a short time), and Apple Maps also caps the stops on a route.
    static let maxPins = 15
    /// Google Maps links take at most this many stops between their start and end, so longer routes
    /// are split into parts.
    static let googleMaxWaypoints = 9

    /// The pins, in the order they were picked.
    var pins: [RouteStop]
    var start: RouteEndpoint = .pin
    var end: RouteEndpoint = .pin
    var mode: RouteMode = .driving

    /// The route itself: where it starts (nil for the current location), the stops in between, and
    /// where it ends. Nil until there are two points to go between.
    var legs: (source: RouteStop?, waypoints: [RouteStop], destination: RouteStop)? {
        var middle = pins
        let source: RouteStop?
        switch start {
        case .pin:
            guard !middle.isEmpty else { return nil }
            source = middle.removeFirst()
        case .currentLocation:
            source = nil
        case .place(let stop):
            source = stop
        }
        let destination: RouteStop
        switch end {
        case .pin, .currentLocation:
            guard let last = middle.popLast() else { return nil }
            destination = last
        case .place(let stop):
            destination = stop
        }
        return (source, middle, destination)
    }

    /// Every point in order, for the map: the start (when it's a known place), the pins, the end.
    var points: [RouteStop] {
        guard let legs else { return pins }
        return (legs.source.map { [$0] } ?? []) + legs.waypoints + [legs.destination]
    }

    /// Straight-line distance through the points, in meters.
    var straightMeters: Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + Geo.distance(
                TrailPoint(latitude: pair.0.latitude, longitude: pair.0.longitude),
                TrailPoint(latitude: pair.1.latitude, longitude: pair.1.longitude)
            )
        }
    }

    /// Apple Maps, with every stop in one route (unified Maps URL `/directions`, iOS 18.4+).
    var appleURL: URL? {
        guard let legs else { return nil }
        var items: [URLQueryItem] = []
        if let source = legs.source {
            items.append(URLQueryItem(name: "source", value: Self.coordinate(source)))
        }
        for stop in legs.waypoints {
            items.append(URLQueryItem(name: "waypoint", value: Self.coordinate(stop)))
        }
        items.append(URLQueryItem(name: "destination", value: Self.coordinate(legs.destination)))
        items.append(URLQueryItem(name: "mode", value: mode.rawValue))
        var components = URLComponents(string: "https://maps.apple.com/directions")!
        components.queryItems = items
        return components.url
    }

    /// Google Maps, in as many parts as its stop limit needs. Each part starts where the last ended.
    var googleURLs: [URL] {
        guard let legs else { return [] }
        var remaining = legs.waypoints + [legs.destination]
        var origin = legs.source
        var urls: [URL] = []
        while !remaining.isEmpty {
            let part = Array(remaining.prefix(Self.googleMaxWaypoints + 1))
            remaining.removeFirst(part.count)
            let destination = part[part.count - 1]
            var items = [URLQueryItem(name: "api", value: "1")]
            if let origin {
                items.append(URLQueryItem(name: "origin", value: Self.coordinate(origin)))
            }
            items.append(URLQueryItem(name: "destination", value: Self.coordinate(destination)))
            let between = part.dropLast()
            if !between.isEmpty {
                items.append(URLQueryItem(name: "waypoints", value: between.map(Self.coordinate).joined(separator: "|")))
            }
            items.append(URLQueryItem(name: "travelmode", value: mode.rawValue))
            var components = URLComponents(string: "https://www.google.com/maps/dir/")!
            components.queryItems = items
            if let url = components.url {
                urls.append(url)
            }
            origin = destination
        }
        return urls
    }

    private static func coordinate(_ stop: RouteStop) -> String {
        MapLinks.coordinateString(latitude: stop.latitude, longitude: stop.longitude)
    }
}
