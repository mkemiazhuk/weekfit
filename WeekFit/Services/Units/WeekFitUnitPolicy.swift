import Foundation

/// Centralized unit conversion + formatting policy.
/// Weather and other UI should format in the presentation layer using this policy.
enum WeekFitUnitPolicy {

    static func resolvedSystem(
        for preference: WeekFitUnitPreference,
        locale: Locale = .autoupdatingCurrent
    ) -> WeekFitResolvedUnitSystem {
        switch preference {
        case .automatic:
            // `measurementSystem` is a broad device preference (metric vs imperial).
            // We disambiguate UK vs US only when the device is imperial, using the user's configured region.
            // This is still driven by device locale settings, not physical location/IP.
            if locale.measurementSystem == .metric {
                return .metric
            }
            let regionCode = locale.region?.identifier.uppercased() ?? ""
            if regionCode == "GB" || regionCode == "UK" {
                return .uk
            }
            return .us

        case .metric:
            return .metric
        case .uk:
            return .uk
        case .us:
            return .us
        }
    }

    static func temperatureUnit(for system: WeekFitResolvedUnitSystem) -> UnitTemperature {
        // Per product policy: UK uses Celsius, US uses Fahrenheit.
        switch system {
        case .metric, .uk: return .celsius
        case .us: return .fahrenheit
        }
    }

    static func speedUnit(for system: WeekFitResolvedUnitSystem) -> UnitSpeed {
        // Per product policy: UK + US use mph.
        switch system {
        case .metric: return .kilometersPerHour
        case .uk, .us: return .milesPerHour
        }
    }

    static func distanceUnit(for system: WeekFitResolvedUnitSystem) -> UnitLength {
        switch system {
        case .metric: return .kilometers
        case .uk, .us: return .miles
        }
    }

    static func elevationUnit(for system: WeekFitResolvedUnitSystem) -> UnitLength {
        // Fitness elevation: metric metres; UK/US feet.
        switch system {
        case .metric: return .meters
        case .uk, .us: return .feet
        }
    }

    // MARK: - Weather helpers (temperature + wind)

    static func temperatureValueForBadge(
        _ temperature: Measurement<UnitTemperature>,
        system: WeekFitResolvedUnitSystem
    ) -> Int {
        let unit = temperatureUnit(for: system)
        let converted = temperature.converted(to: unit)
        return Int(converted.value.rounded())
    }

    static func accessibilityTemperatureUnitName(for system: WeekFitResolvedUnitSystem) -> String {
        if WeekFitUsesRussianLanguage() {
            switch system {
            case .metric, .uk: return "Цельсия"
            case .us: return "Фаренгейта"
            }
        }
        switch system {
        case .metric, .uk: return "Celsius"
        case .us: return "Fahrenheit"
        }
    }

    static func formatSpeed(
        _ speed: Measurement<UnitSpeed>,
        system: WeekFitResolvedUnitSystem
    ) -> String {
        let unit = speedUnit(for: system)
        let converted = speed.converted(to: unit)

        let formatter = MeasurementFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short

        // Prefer one decimal if not whole number; for whole numbers, keep it clean.
        if abs(converted.value.rounded() - converted.value) < 0.0001 {
            let rounded = Measurement(value: converted.value.rounded(), unit: unit)
            return formatter.string(from: rounded)
        } else {
            // Keep one decimal for a “premium” feel.
            let rounded = Measurement(value: (converted.value * 10).rounded() / 10, unit: unit)
            return formatter.string(from: rounded)
        }
    }

    static func unitSymbol(for system: WeekFitResolvedUnitSystem) -> String {
        // Used only in custom string composition; avoid hardcoded abbreviations elsewhere.
        switch system {
        case .metric: return UnitLength.kilometers.symbol
        case .uk, .us: return UnitLength.miles.symbol
        }
    }

    // MARK: - Activity helpers (canonical inputs: km, km/h, meters, min/km)

    static func distanceValue(kilometers: Double, system: WeekFitResolvedUnitSystem) -> Double {
        Measurement(value: kilometers, unit: UnitLength.kilometers)
            .converted(to: distanceUnit(for: system))
            .value
    }

    static func speedValue(kilometersPerHour: Double, system: WeekFitResolvedUnitSystem) -> Double {
        Measurement(value: kilometersPerHour, unit: UnitSpeed.kilometersPerHour)
            .converted(to: speedUnit(for: system))
            .value
    }

    static func elevationValue(meters: Double, system: WeekFitResolvedUnitSystem) -> Double {
        Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: elevationUnit(for: system))
            .value
    }

    static func distanceUnitLabel(for system: WeekFitResolvedUnitSystem) -> String {
        switch system {
        case .metric:
            return WeekFitLocalizedString("common.unit.kilometer")
        case .uk, .us:
            return WeekFitLocalizedString("common.unit.mile")
        }
    }

    static func speedUnitLabel(for system: WeekFitResolvedUnitSystem) -> String {
        switch system {
        case .metric:
            return WeekFitLocalizedString("common.unit.kilometerPerHour")
        case .uk, .us:
            return WeekFitLocalizedString("common.unit.milesPerHour")
        }
    }

    static func elevationUnitLabel(for system: WeekFitResolvedUnitSystem) -> String {
        switch system {
        case .metric:
            return WeekFitLocalizedString("common.unit.meter")
        case .uk, .us:
            return WeekFitLocalizedString("common.unit.foot")
        }
    }

    static func formatDistance(kilometers: Double, system: WeekFitResolvedUnitSystem) -> String {
        let value = distanceValue(kilometers: kilometers, system: system)
        let formatted = String(format: value >= 10 ? "%.1f" : "%.2f", value)
        return "\(formatted) \(distanceUnitLabel(for: system))"
    }

    static func formatCompactDistance(kilometers: Double, system: WeekFitResolvedUnitSystem) -> String {
        let value = distanceValue(kilometers: kilometers, system: system)
        return String(format: value >= 10 ? "%.1f" : "%.2f", value)
    }

    static func formatSpeed(kilometersPerHour: Double, system: WeekFitResolvedUnitSystem) -> String {
        let value = speedValue(kilometersPerHour: kilometersPerHour, system: system)
        return String(format: "%.1f %@", value, speedUnitLabel(for: system))
    }

    static func formatCompactSpeed(kilometersPerHour: Double, system: WeekFitResolvedUnitSystem) -> String {
        let value = speedValue(kilometersPerHour: kilometersPerHour, system: system)
        return String(format: "%.1f", value)
    }

    static func formatElevation(meters: Double, system: WeekFitResolvedUnitSystem) -> String {
        let value = elevationValue(meters: meters, system: system)
        return "\(Int(value.rounded())) \(elevationUnitLabel(for: system))"
    }

    static func formatCompactElevation(meters: Double, system: WeekFitResolvedUnitSystem) -> String {
        let value = elevationValue(meters: meters, system: system)
        return "\(Int(value.rounded()))"
    }

    /// Canonical pace is minutes per kilometre.
    static func formatPace(minutesPerKilometer: Double, system: WeekFitResolvedUnitSystem) -> String {
        let minutesPerUnit: Double
        let unitLabel: String
        switch system {
        case .metric:
            minutesPerUnit = minutesPerKilometer
            unitLabel = "/\(distanceUnitLabel(for: .metric))"
        case .uk, .us:
            // 1 mile = 1.60934 km → minutes/mile = minutes/km × 1.60934
            minutesPerUnit = minutesPerKilometer * 1.60934
            unitLabel = "/\(distanceUnitLabel(for: system))"
        }

        let totalSeconds = Int((minutesPerUnit * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d %@", minutes, seconds, unitLabel)
    }
}

