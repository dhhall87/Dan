import Foundation

/// Links that open a pin in Apple Maps or Google Maps (the app if installed, otherwise the website).
enum MapLinks {
    static func url(for pin: Pin, in app: MapsApp) -> URL {
        switch app {
        case .apple: return apple(pin)
        case .google: return google(pin)
        }
    }

    static func apple(_ pin: Pin) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "ll", value: coordinateString(pin)),
            URLQueryItem(name: "q", value: pin.note.isEmpty ? "RoadPin" : pin.note),
        ]
        return components.url!
    }

    static func google(_ pin: Pin) -> URL {
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: coordinateString(pin)),
        ]
        return components.url!
    }

    /// Turn-by-turn directions back to the pin, used from CarPlay.
    static func directions(to pin: Pin, in app: MapsApp) -> URL {
        switch app {
        case .apple:
            var components = URLComponents(string: "https://maps.apple.com/")!
            components.queryItems = [
                URLQueryItem(name: "daddr", value: coordinateString(pin)),
                URLQueryItem(name: "dirflg", value: "d"),
            ]
            return components.url!
        case .google:
            var components = URLComponents(string: "https://www.google.com/maps/dir/")!
            components.queryItems = [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "destination", value: coordinateString(pin)),
                URLQueryItem(name: "travelmode", value: "driving"),
            ]
            return components.url!
        }
    }

    static func coordinateString(_ pin: Pin) -> String {
        String(format: "%.6f,%.6f", pin.latitude, pin.longitude)
    }
}
