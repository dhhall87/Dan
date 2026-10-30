import Foundation

/// Sunrise times from NOAA's solar calculator equations, within about a minute between the
/// polar circles. Sunrise uses it only to show the times; the home hub works out its own
/// sunrise for the lights, from the home's location.
enum SolarCalculator {
    /// Sunrise on a calendar day (numbered as it is where the place is), or nil when the sun
    /// doesn't rise or set that day (polar night or midnight sun).
    static func sunrise(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) -> Date? {
        let midnight = julianDay(year: year, month: month, day: day)
        // The second pass recomputes the sun's position at the first answer's time.
        guard let first = sunriseMinutesUTC(julianDay: midnight, latitude: latitude, longitude: longitude),
              let refined = sunriseMinutesUTC(julianDay: midnight + first / 1440, latitude: latitude, longitude: longitude)
        else { return nil }
        return Date(timeIntervalSince1970: (midnight - 2_440_587.5) * 86_400 + refined * 60)
    }

    /// Sunrise on the day that contains `date` in `calendar`'s time zone.
    static func sunrise(on date: Date, latitude: Double, longitude: Double, calendar: Calendar) -> Date? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return sunrise(year: year, month: month, day: day, latitude: latitude, longitude: longitude)
    }

    /// The Julian day at 0:00 UTC on a Gregorian calendar date.
    static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year)
        var m = Double(month)
        if month <= 2 {
            y -= 1
            m += 12
        }
        let a = (y / 100).rounded(.down)
        let b = 2 - a + (a / 4).rounded(.down)
        return (365.25 * (y + 4716)).rounded(.down) + (30.6001 * (m + 1)).rounded(.down) + Double(day) + b - 1524.5
    }

    /// Minutes after 0:00 UTC on the Julian day; negative or past 1,440 far from Greenwich.
    private static func sunriseMinutesUTC(julianDay: Double, latitude: Double, longitude: Double) -> Double? {
        let t = (julianDay - 2_451_545) / 36_525
        let sun = sunPosition(centuries: t)
        let lat = radians(latitude)
        let declination = radians(sun.declination)
        // 90.833° allows for the sun's radius and the atmosphere bending its light.
        let cosHourAngle = cos(radians(90.833)) / (cos(lat) * cos(declination)) - tan(lat) * tan(declination)
        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return nil }
        let hourAngle = degrees(acos(cosHourAngle))
        return 720 - 4 * (longitude + hourAngle) - sun.equationOfTime
    }

    /// The sun's declination (degrees) and the equation of time (minutes), `centuries` Julian centuries after J2000.
    private static func sunPosition(centuries t: Double) -> (declination: Double, equationOfTime: Double) {
        let meanLongitude = (280.46646 + t * (36_000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let anomaly = radians(meanAnomaly)
        let center = sin(anomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * anomaly) * (0.019993 - 0.000101 * t)
            + sin(3 * anomaly) * 0.000289
        let omega = radians(125.04 - 1934.136 * t)
        let apparentLongitude = meanLongitude + center - 0.00569 - 0.00478 * sin(omega)
        let seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
        let obliquity = 23 + (26 + seconds / 60) / 60 + 0.00256 * cos(omega)
        let declination = degrees(asin(sin(radians(obliquity)) * sin(radians(apparentLongitude))))

        let y = pow(tan(radians(obliquity) / 2), 2)
        let longitude = radians(meanLongitude)
        let equation = y * sin(2 * longitude)
            - 2 * eccentricity * sin(anomaly)
            + 4 * eccentricity * y * sin(anomaly) * cos(2 * longitude)
            - 0.5 * y * y * sin(4 * longitude)
            - 1.25 * eccentricity * eccentricity * sin(2 * anomaly)
        return (declination, degrees(equation) * 4)
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
