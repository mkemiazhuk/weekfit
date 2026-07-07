import CoreLocation
import Foundation

enum NightComfortSolarTimeProvider {

    struct SolarTimes: Equatable, Sendable {
        let sunrise: Date
        let sunset: Date
    }

    static func solarTimes(
        on date: Date,
        coordinate: CLLocationCoordinate2D,
        timeZone: TimeZone,
        calendar: Calendar = .current
    ) -> SolarTimes? {
        guard
            let sunrise = sunEvent(
                on: date,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZone: timeZone,
                calendar: calendar,
                sunrise: true
            ),
            let sunset = sunEvent(
                on: date,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZone: timeZone,
                calendar: calendar,
                sunrise: false
            )
        else {
            return nil
        }

        return SolarTimes(sunrise: sunrise, sunset: sunset)
    }

    // MARK: - NOAA-style solar calculator (approximate, sufficient for UI comfort windows)

    private static func sunEvent(
        on date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        calendar: Calendar,
        sunrise: Bool
    ) -> Date? {
        var calendar = calendar
        calendar.timeZone = timeZone

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let lngHour = longitude / 15.0
        let zenith = 90.833

        let t: Double
        if sunrise {
            t = Double(dayOfYear) + ((6.0 - lngHour) / 24.0)
        } else {
            t = Double(dayOfYear) + ((18.0 - lngHour) / 24.0)
        }

        let meanAnomaly = (0.9856 * t) - 3.289
        var sunLongitude = meanAnomaly
            + (1.916 * sin(degreesToRadians(meanAnomaly)))
            + (0.020 * sin(degreesToRadians(2 * meanAnomaly)))
            + 282.634
        sunLongitude = normalizeDegrees(sunLongitude)

        var rightAscension = radiansToDegrees(atan(0.91764 * tan(degreesToRadians(sunLongitude))))
        rightAscension = normalizeDegrees(rightAscension)

        let longitudeQuadrant = floor(sunLongitude / 90.0) * 90.0
        let rightAscensionQuadrant = floor(rightAscension / 90.0) * 90.0
        rightAscension = (rightAscension + (longitudeQuadrant - rightAscensionQuadrant)) / 15.0

        let sinDeclination = 0.39782 * sin(degreesToRadians(sunLongitude))
        let cosDeclination = cos(asin(sinDeclination))

        let cosHourAngle = (
            cos(degreesToRadians(zenith))
                - (sinDeclination * sin(degreesToRadians(latitude)))
        ) / (cosDeclination * cos(degreesToRadians(latitude)))

        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return nil }

        let hourAngle: Double
        if sunrise {
            hourAngle = 360.0 - radiansToDegrees(acos(cosHourAngle))
        } else {
            hourAngle = radiansToDegrees(acos(cosHourAngle))
        }

        let localMeanTime = (hourAngle / 15.0) + rightAscension - (0.06571 * t) - 6.622
        var universalTime = localMeanTime - lngHour
        universalTime = normalizeHours(universalTime)

        let hour = Int(floor(universalTime))
        let minute = Int(round((universalTime - Double(hour)) * 60.0))

        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? timeZone

        var components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let utcDate = utcCalendar.date(from: components) else { return nil }

        var localComponents = calendar.dateComponents(in: timeZone, from: utcDate)
        localComponents.calendar = calendar
        localComponents.timeZone = timeZone

        return calendar.date(from: localComponents)
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180.0
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180.0 / .pi
    }

    private static func normalizeDegrees(_ value: Double) -> Double {
        var normalized = value
        while normalized < 0 { normalized += 360 }
        while normalized >= 360 { normalized -= 360 }
        return normalized
    }

    private static func normalizeHours(_ value: Double) -> Double {
        var normalized = value
        while normalized < 0 { normalized += 24 }
        while normalized >= 24 { normalized -= 24 }
        return normalized
    }
}
