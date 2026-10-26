import Foundation

/// Links that open a spot in Apple Maps or Google Maps (the app if installed, otherwise the website).
enum MapLinks {
    static func apple(latitude: Double, longitude: Double, label: String?) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "ll", value: coordinateString(latitude: latitude, longitude: longitude)),
            URLQueryItem(name: "q", value: label.flatMap { $0.isEmpty ? nil : $0 } ?? "Passing pin"),
        ]
        return components.url!
    }

    /// A place's own card in Apple Maps (name, hours, photos, Add to Guide), from its Apple Maps
    /// Place ID. Apple's unified Maps link, iOS 18.4 and later.
    static func applePlace(id: String) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/place")!
        components.queryItems = [URLQueryItem(name: "place-id", value: id)]
        return components.url!
    }

    /// Searches Apple Maps for `query` (like "diner") in about a 2 km square around a spot, so the
    /// results are real places rather than a dropped pin.
    static func appleSearch(query: String, latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "center", value: coordinateString(latitude: latitude, longitude: longitude)),
            URLQueryItem(name: "span", value: "0.02,0.02"),
        ]
        return components.url!
    }

    static func google(latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: coordinateString(latitude: latitude, longitude: longitude)),
        ]
        return components.url!
    }

    /// Searches Google Maps for a named place, like "Joe's Diner, Garden City, KS", which usually
    /// opens that business. Google's own place IDs need a paid key, so this is the free way.
    static func googleSearch(query: String) -> URL {
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query),
        ]
        return components.url!
    }

    /// "40.712800,-74.006000": always a dot for decimals, whatever the phone's region.
    static func coordinateString(latitude: Double, longitude: Double) -> String {
        String(format: "%.6f,%.6f", latitude, longitude)
    }
}
