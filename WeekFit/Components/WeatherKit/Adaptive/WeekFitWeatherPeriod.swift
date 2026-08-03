import Foundation

/// Local solar day period for the adaptive Weather experience.
/// Derived from actual sunrise / sunset — never fixed clock hours.
enum WeekFitWeatherPeriod: String, Equatable, Sendable {
    case dawn
    case day
    case goldenHour
    case dusk
    case night

    var isNightLike: Bool {
        switch self {
        case .dusk, .night: return true
        case .dawn, .day, .goldenHour: return false
        }
    }

    /// Prefer WeatherKit sun events; fall back to Night Comfort solar calculator.
    static func resolve(
        now: Date = Date(),
        sunrise: Date?,
        sunset: Date?,
        isDaylightHint: Bool = true,
        calendar: Calendar = .current
    ) -> WeekFitWeatherPeriod {
        guard let sunrise, let sunset, sunrise < sunset else {
            return isDaylightHint ? .day : .night
        }

        let dawnStart = sunrise.addingTimeInterval(-45 * 60)
        let dawnEnd = sunrise.addingTimeInterval(35 * 60)
        let goldenStart = sunset.addingTimeInterval(-55 * 60)
        let duskEnd = sunset.addingTimeInterval(40 * 60)

        if now >= dawnStart && now < dawnEnd {
            return .dawn
        }
        if now >= goldenStart && now < sunset {
            return .goldenHour
        }
        if now >= sunset && now < duskEnd {
            return .dusk
        }
        if now >= duskEnd || now < dawnStart {
            return .night
        }
        return .day
    }

    var accessibilityLabel: String {
        if WeekFitUsesRussianLanguage() {
            switch self {
            case .dawn: return "Рассвет"
            case .day: return "День"
            case .goldenHour: return "Золотой час"
            case .dusk: return "Сумерки"
            case .night: return "Ночь"
            }
        }
        switch self {
        case .dawn: return "Dawn"
        case .day: return "Day"
        case .goldenHour: return "Golden hour"
        case .dusk: return "Dusk"
        case .night: return "Night"
        }
    }
}
