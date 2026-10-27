import SwiftUI

struct MacroBalanceCard: View {
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double
    let proteinGoal: Double
    let carbsGoal: Double
    let fatsGoal: Double
    let fiberGoal: Double

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        NutritionDetailsCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(WeekFitLocalizedString("nutrition.details.section.nutrients"))
                    .nutritionReading(15, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 14) {
                    row(
                        title: WeekFitLocalizedString("nutrition.macro.protein"),
                        value: protein,
                        goal: proteinGoal,
                        tint: WeekFitLightTokens.protein
                    )
                    row(
                        title: WeekFitLocalizedString("nutrition.macro.carbs"),
                        value: carbs,
                        goal: carbsGoal,
                        tint: WeekFitLightTokens.carbs
                    )
                    row(
                        title: WeekFitLocalizedString("nutrition.macro.fats"),
                        value: fats,
                        goal: fatsGoal,
                        tint: WeekFitLightTokens.fats
                    )
                    row(
                        title: WeekFitLocalizedString("nutrition.macro.fiber"),
                        value: fiber,
                        goal: fiberGoal,
                        tint: WeekFitLightTokens.fiber
                    )
                }
            }
        }
    }

    private func row(title: String, value: Double, goal: Double, tint: Color) -> some View {
        let readout = NutritionDetailsFormat.macro(current: value, goal: goal)
            return VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 11) {
                    Text(title)
                        .nutritionReading(15, weight: .regular, relativeTo: .body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    valueLabel(readout, alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .nutritionReading(15, weight: .regular, relativeTo: .body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    valueLabel(readout, alignment: .leading)
                }
            }

            if case .ratio(_, _, let progress, _) = readout {
                progressBar(progress, tint: tint)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func valueLabel(
        _ readout: NutritionDetailsFormat.Readout,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            switch readout {
            case .unknown:
                Text(WeekFitLocalizedString("nutrition.details.hydration.status.unavailable"))
                    .nutritionReading(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(palette.textSecondary)
            case .amount(let text), .ratio(let text, _, _, _):
                Text(text)
                    .nutritionReading(15, weight: .semibold, design: .rounded, relativeTo: .body)
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: true)
            }
            if case .ratio(_, _, _, let overage?) = readout {
                Text(overage)
                    .nutritionReading(14, weight: .medium, design: .rounded, relativeTo: .subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
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
}
