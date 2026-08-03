import Foundation

/// Adaptive metric ordering — dimensions stay stable; priority changes by condition.
enum WeekFitWeatherMetricKind: String, CaseIterable, Equatable, Sendable {
    case feelsLike
    case highLow
    case humidity
    case wind
    case uvIndex
    case rainChance
    case visibility
    case sunriseSunset

    var isPrimary: Bool {
        switch self {
        case .feelsLike, .highLow: return true
        default: return false
        }
    }
}

enum WeekFitWeatherMetricsOrder {
    static func secondaryMetrics(
        for summary: WeekFitWeatherSummary,
        period: WeekFitWeatherPeriod
    ) -> [WeekFitWeatherMetricKind] {
        var ordered: [WeekFitWeatherMetricKind] = []

        func append(_ kind: WeekFitWeatherMetricKind) {
            guard !ordered.contains(kind) else { return }
            if kind == .rainChance, summary.precipitationChance == nil { return }
            if kind == .visibility, summary.visibilityKilometers == nil { return }
            if kind == .sunriseSunset, summary.sunrise == nil || summary.sunset == nil { return }
            // UV is less meaningful at night
            if kind == .uvIndex, period.isNightLike { return }
            ordered.append(kind)
        }

        let tempC = summary.temperature.value
        let windKmh = summary.windSpeed.value
        let precip = summary.precipitationChance ?? 0
        let visibilityKm = summary.visibilityKilometers

        switch summary.condition {
        case .rain, .storm:
            append(.rainChance)
            append(.wind)
            append(.humidity)
            append(.visibility)
            append(.uvIndex)
            append(.sunriseSunset)

        case .fog:
            append(.visibility)
            append(.humidity)
            append(.wind)
            append(.rainChance)
            append(.sunriseSunset)
            append(.uvIndex)

        case .snow:
            append(.wind)
            append(.visibility)
            append(.humidity)
            append(.sunriseSunset)
            append(.rainChance)
            append(.uvIndex)

        case .clear, .partlyCloudy:
            if tempC >= 28 {
                append(.uvIndex)
                append(.humidity)
                append(.wind)
                append(.rainChance)
                append(.sunriseSunset)
                append(.visibility)
            } else if windKmh >= 30 {
                append(.wind)
                append(.humidity)
                append(.uvIndex)
                append(.rainChance)
                append(.sunriseSunset)
                append(.visibility)
            } else {
                append(.uvIndex)
                append(.wind)
                append(.humidity)
                append(.rainChance)
                append(.sunriseSunset)
                append(.visibility)
            }

        case .cloudy, .other:
            append(.humidity)
            append(.wind)
            if precip >= 40 { append(.rainChance) }
            append(.uvIndex)
            append(.rainChance)
            append(.sunriseSunset)
            append(.visibility)

        case .windy:
            append(.wind)
            append(.humidity)
            append(.rainChance)
            append(.uvIndex)
            append(.visibility)
            append(.sunriseSunset)
        }

        // Climate overrides
        if tempC <= 0 {
            // Feels-like already primary; push wind / exposure higher in secondary
            ordered.removeAll { $0 == .wind }
            ordered.insert(.wind, at: 0)
        }

        if let visibilityKm, visibilityKm < 2 {
            ordered.removeAll { $0 == .visibility }
            ordered.insert(.visibility, at: 0)
        }

        // Cap secondary grid for calm hierarchy (max 6 cells → 3 rows)
        return Array(ordered.prefix(6))
    }

    static func primaryMetrics(for summary: WeekFitWeatherSummary) -> [WeekFitWeatherMetricKind] {
        var primary: [WeekFitWeatherMetricKind] = [.feelsLike]
        if summary.highTemperature != nil, summary.lowTemperature != nil {
            primary.append(.highLow)
        }
        return primary
    }
}
