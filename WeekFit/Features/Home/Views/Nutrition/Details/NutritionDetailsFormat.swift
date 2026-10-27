import Foundation

/// Display decisions for Nutrition Details. Goals of zero and non-finite
/// values stay unknown — they are not rendered as a fake zero progress.
enum NutritionDetailsFormat {

    enum Readout: Equatable {
        case unknown
        case amount(String)
        /// `text` is eaten / goal. `currentAmount` is eaten only, for the calorie hero.
        case ratio(text: String, currentAmount: String, progress: Double, overage: String?)
    }

    enum WaterReadout: Equatable {
        case noneLogged
        case logged(Readout)
    }

    static func calories(
        current: Double,
        goal: Double,
        locale: Locale = WeekFitCurrentLocale()
    ) -> Readout {
        quantity(
            current: current,
            goal: goal,
            currentText: { integer($0, locale: locale) },
            goalText: { integer($0, locale: locale) },
            unit: WeekFitLocalizedString("common.unit.kcal", locale: locale),
            locale: locale
        )
    }

    static func macro(
        current: Double,
        goal: Double,
        locale: Locale = WeekFitCurrentLocale()
    ) -> Readout {
        quantity(
            current: current,
            goal: goal,
            currentText: { integer($0, locale: locale) },
            goalText: { integer($0, locale: locale) },
            unit: WeekFitLocalizedString("common.unit.gramShort", locale: locale),
            locale: locale
        )
    }

    static func water(
        liters: Double,
        goal: Double,
        locale: Locale = WeekFitCurrentLocale()
    ) -> WaterReadout {
        guard liters.isFinite, liters > 0 else { return .noneLogged }
        let readout = quantity(
            current: liters,
            goal: goal,
            currentText: { decimal($0, fractionDigits: 1, locale: locale) },
            goalText: { decimal($0, fractionDigits: 1, locale: locale) },
            unit: WeekFitLocalizedString("nutrition.details.unit.liter", locale: locale),
            locale: locale,
            overageAmount: { value, target in
                let delta = ((value - target) * 10).rounded() / 10
                guard delta > 0 else { return nil }
                return decimal(delta, fractionDigits: 1, locale: locale)
            }
        )
        return .logged(readout)
    }

    static func goalCaption(
        for readout: Readout,
        locale: Locale = WeekFitCurrentLocale()
    ) -> String? {
        switch readout {
        case .unknown, .amount:
            return nil
        case .ratio(let text, _, _, _):
            let goal = goalPortion(of: text)
            guard !goal.isEmpty else { return nil }
            return String(
                format: WeekFitLocalizedString("nutrition.details.calories.goalCaption", locale: locale),
                locale: locale,
                goal
            )
        }
    }

    static func integer(_ value: Double, locale: Locale) -> String {
        Int(value.rounded()).formatted(.number.locale(locale))
    }

    static func decimal(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        value.formatted(
            .number.precision(.fractionLength(fractionDigits)).locale(locale)
        )
    }

    static func progressFraction(current: Double, goal: Double) -> Double? {
        guard current.isFinite, goal.isFinite, goal > 0 else { return nil }
        return min(max(current / goal, 0), 1)
    }

    // MARK: - Private

    private static func quantity(
        current: Double,
        goal: Double,
        currentText: (Double) -> String,
        goalText: (Double) -> String,
        unit: String,
        locale: Locale,
        overageAmount: ((Double, Double) -> String?)? = nil
    ) -> Readout {
        guard current.isFinite else { return .unknown }

        let amount = String(
            format: WeekFitLocalizedString("nutrition.details.quantity.amount", locale: locale),
            locale: locale,
            currentText(current),
            unit
        )

        guard goal.isFinite, goal > 0 else { return .amount(amount) }

        let ratio = String(
            format: WeekFitLocalizedString("nutrition.details.quantity.ratio", locale: locale),
            locale: locale,
            currentText(current),
            goalText(goal),
            unit
        )
        let progress = min(max(current / goal, 0), 1)
        let overage = overageLabel(
            current: current,
            goal: goal,
            unit: unit,
            locale: locale,
            overageAmount: overageAmount
        )
        return .ratio(text: ratio, currentAmount: amount, progress: progress, overage: overage)
    }

    private static func overageLabel(
        current: Double,
        goal: Double,
        unit: String,
        locale: Locale,
        overageAmount: ((Double, Double) -> String?)?
    ) -> String? {
        let amount: String?
        if let overageAmount {
            amount = overageAmount(current, goal)
        } else {
            let delta = Int((current - goal).rounded())
            guard delta > 0 else { return nil }
            amount = integer(Double(delta), locale: locale)
        }
        guard let amount else { return nil }
        return String(
            format: WeekFitLocalizedString("nutrition.details.quantity.overage", locale: locale),
            locale: locale,
            amount,
            unit
        )
    }

    /// "1,840 / 2,100 kcal" → "2,100 kcal" for the secondary goal line.
    private static func goalPortion(of ratio: String) -> String {
        guard let separator = ratio.range(of: " / ") else { return "" }
        return String(ratio[separator.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
