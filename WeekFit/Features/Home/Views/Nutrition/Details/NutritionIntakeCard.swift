import SwiftUI

struct NutritionIntakeCard: View {
    let calories: Double
    let caloriesGoal: Double
    let waterLiters: Double
    let waterGoal: Double
    let isToday: Bool

    @Environment(\.weekFitPalette) private var palette

    private var calorieReadout: NutritionDetailsFormat.Readout {
        NutritionDetailsFormat.calories(current: calories, goal: caloriesGoal)
    }

    private var waterReadout: NutritionDetailsFormat.WaterReadout {
        NutritionDetailsFormat.water(liters: waterLiters, goal: waterGoal)
    }

    var body: some View {
        NutritionDetailsCard(
            edgeInsets: EdgeInsets(top: 18, leading: 18, bottom: 11, trailing: 18)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                calorieBlock

                divider
                    .padding(.top, 14)

                waterRow
                    .padding(.top, 11)
            }
        }
    }

    private var calorieBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(
                WeekFitLocalizedString(
                    isToday
                        ? "nutrition.details.intake.today"
                        : "nutrition.details.intake.other"
                )
            )
            .nutritionReading(14, weight: .medium, relativeTo: .subheadline)
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            calorieValue
                .padding(.top, 7)

            if let overage = calorieOverage {
                Text(overage)
                    .nutritionReading(14, weight: .medium, relativeTo: .subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            if let progress = calorieProgress {
                progressBar(progress, tint: NutritionDetailsDesign.nutritionAccent)
                    .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(calorieAccessibilityLabel)
    }

    @ViewBuilder
    private var calorieValue: some View {
        switch calorieReadout {
        case .unknown:
            Text(WeekFitLocalizedString("nutrition.details.hydration.status.unavailable"))
                .nutritionReading(18, weight: .semibold, relativeTo: .title3)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .amount(let text):
            heroAmount(text)
        case .ratio(_, let currentAmount, _, _):
            heroAmount(currentAmount)
        }
    }

    private func heroAmount(_ text: String) -> some View {
        let goal = NutritionDetailsFormat.goalCaption(for: calorieReadout)
        let number = heroNumber(from: text)
        let unit = heroUnit(from: text)

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                heroLine(primary: number, unit: unit)
                    .fixedSize(horizontal: true, vertical: true)
                if let goal {
                    Spacer(minLength: 12)
                    goalText(goal)
                        .fixedSize(horizontal: true, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    heroLine(primary: number, unit: unit)
                    VStack(alignment: .leading, spacing: 0) {
                        heroNumberText(number)
                        heroUnitText(unit)
                    }
                }
                if let goal {
                    goalText(goal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func goalText(_ goal: String) -> some View {
        Text(goal)
            .nutritionReading(14, weight: .regular, relativeTo: .subheadline)
            .foregroundStyle(palette.textSecondary)
            .multilineTextAlignment(.leading)
    }

    private func heroLine(primary: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            heroNumberText(primary)
            heroUnitText(unit)
        }
    }

    private func heroNumberText(_ text: String) -> some View {
        Text(text)
            .nutritionReading(40, weight: .bold, design: .rounded, relativeTo: .largeTitle)
            .foregroundStyle(palette.textPrimary)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: true)
    }

    private func heroUnitText(_ text: String) -> some View {
        Text(text)
            .nutritionReading(18, weight: .semibold, design: .rounded, relativeTo: .title3)
            .foregroundStyle(NutritionDetailsDesign.nutritionAccent)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var waterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 0) {
                waterIdentity
                    .fixedSize(horizontal: true, vertical: true)
                Spacer(minLength: 12)
                waterValue
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                waterIdentity
                waterValue
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var waterIdentity: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .nutritionReading(15, weight: .semibold, relativeTo: .body)
                .foregroundStyle(WeekFitLightTokens.water)
                .accessibilityHidden(true)

            Text(WeekFitLocalizedString("nutrition.details.hydration.short"))
                .nutritionReading(15, weight: .semibold, relativeTo: .body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var waterValue: some View {
        switch waterReadout {
        case .noneLogged:
            Text(WeekFitLocalizedString("nutrition.details.hydration.none"))
                .nutritionReading(14, weight: .regular, relativeTo: .subheadline)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .logged(.unknown):
            Text(WeekFitLocalizedString("nutrition.details.hydration.status.unavailable"))
                .nutritionReading(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .logged(.amount(let text)), .logged(.ratio(let text, _, _, _)):
            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .nutritionReading(15, weight: .semibold, design: .rounded, relativeTo: .body)
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if case .logged(.ratio(_, _, _, let overage?)) = waterReadout {
                    Text(overage)
                        .nutritionReading(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.isLight ? WeekFitLightTokens.divider : Color.white.opacity(0.10))
            .frame(height: 0.7)
            .accessibilityHidden(true)
    }

    private func progressBar(_ progress: Double, tint: Color) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.isLight ? WeekFitLightTokens.inactiveTrack : Color.white.opacity(0.10))
                Capsule()
                    .fill(tint)
                    .frame(width: fraction <= 0 ? 0 : max(6, width * fraction))
            }
        }
        .frame(height: NutritionDetailsDesign.Reading.barHeight)
        .accessibilityHidden(true)
    }

    private var calorieProgress: Double? {
        if case .ratio(_, _, let progress, _) = calorieReadout { return progress }
        return nil
    }

    private var calorieOverage: String? {
        if case .ratio(_, _, _, let overage) = calorieReadout { return overage }
        return nil
    }

    private var calorieAccessibilityLabel: String {
        var parts = [
            WeekFitLocalizedString(
                isToday
                    ? "nutrition.details.intake.today"
                    : "nutrition.details.intake.other"
            )
        ]
        switch calorieReadout {
        case .unknown:
            parts.append(WeekFitLocalizedString("nutrition.details.hydration.status.unavailable"))
        case .amount(let text):
            parts.append(text)
        case .ratio(let text, _, _, let overage):
            parts.append(text)
            if let goal = NutritionDetailsFormat.goalCaption(for: calorieReadout) {
                parts.append(goal)
            }
            if let overage { parts.append(overage) }
        }
        return parts.joined(separator: ", ")
    }

    /// Splits "1,840 kcal" into the number and the unit. The unit is the last token.
    private func heroNumber(from amount: String) -> String {
        let parts = amount.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return amount }
        return parts.dropLast().joined(separator: " ")
    }

    private func heroUnit(from amount: String) -> String {
        let parts = amount.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, let unit = parts.last else { return "" }
        return String(unit)
    }
}
