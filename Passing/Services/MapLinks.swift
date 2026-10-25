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

    static func google(latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: coordinateString(latitude: latitude, longitude: longitude)),
        ]
        return components.url!
    }

    /// "40.712800,-74.006000": always a dot for decimals, whatever the phone's region.
    static func coordinateString(latitude: Double, longitude: Double) -> String {
        String(format: "%.6f,%.6f", latitude, longitude)
    }
}
