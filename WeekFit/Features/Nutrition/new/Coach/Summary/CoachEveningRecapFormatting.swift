import Foundation

/// Locale-consistent number/unit formatting for the evening recap (app language + unit preference).
enum CoachEveningRecapFormatting {

    static var locale: Locale { WeekFitCurrentLocale() }

    static func distanceParts(
        kilometers: Double,
        system: WeekFitResolvedUnitSystem
    ) -> (value: String, unit: String) {
        let value = WeekFitUnitPolicy.distanceValue(kilometers: kilometers, system: system)
        return (formatDecimal(value, fractionDigits: value >= 10 ? 1 : 1), unitLabel(for: system))
    }

    static func formatDistance(
        kilometers: Double,
        system: WeekFitResolvedUnitSystem
    ) -> String {
        let parts = distanceParts(kilometers: kilometers, system: system)
        return "\(parts.value) \(parts.unit)"
    }

    static func formatSteps(_ steps: Int) -> String {
        let formatted = formatInteger(steps)
        return String(
            format: WeekFitLocalizedString("coach.eveningRecap.stepsFormat"),
            locale: locale,
            arguments: [formatted]
        )
    }

    static func formatInteger(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formatDecimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", locale: locale, value)
    }

    static func formatNaturalDuration(_ minutes: Int) -> String {
        let safe = max(minutes, 0)
        if safe >= 60 {
            let hours = Int64(safe / 60)
            let remaining = Int64(safe % 60)
            if remaining == 0 {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.duration.hoursFormat"),
                    locale: locale,
                    arguments: [hours as CVarArg]
                )
            }
            return String(
                format: WeekFitLocalizedString("coach.eveningRecap.duration.hoursMinutesFormat"),
                locale: locale,
                arguments: [hours as CVarArg, remaining as CVarArg]
            )
        }
        return String(
            format: WeekFitLocalizedString("common.duration.minutesFormat"),
            locale: locale,
            arguments: [Int64(safe) as CVarArg]
        )
    }

    private static func unitLabel(for system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.distanceUnitLabel(for: system)
    }
}
