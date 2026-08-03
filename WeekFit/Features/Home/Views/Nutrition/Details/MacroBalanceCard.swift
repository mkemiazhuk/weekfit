import SwiftUI

struct MacroProgressItem: View {
    let title: String
    let value: Double
    let goal: Double
    let color: Color

    private var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return CGFloat(min(max(value / goal, 0), 1))
    }

    private var percent: Int {
        Int((Double(progress) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 5) {
            WeekFitProgressRing(
                progress: progress,
                color: color,
                size: NutritionDetailsDesign.macroRingSize,
                strokeWidth: NutritionDetailsDesign.macroRingStroke
            ) {
                Text("\(percent)%")
                    .font(NutritionDetailsDesign.Typography.macroPercent)
                    .foregroundStyle(WeekFitLightTokens.textPrimary)
                    .monospacedDigit()
            }

            VStack(spacing: 1) {
                Text(title)
                    .font(NutritionDetailsDesign.Typography.macroTitle)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(
                    String(
                        format: WeekFitLocalizedString("nutrition.details.macro.valueFormat"),
                        Int(value),
                        Int(goal)
                    )
                )
                .font(NutritionDetailsDesign.Typography.macroValue)
                .foregroundStyle(WeekFitLightTokens.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), \(percent)%, \(Int(value)) / \(Int(goal))"
        )
    }
}

struct MacroBalanceCard: View {
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double
    let proteinGoal: Double
    let carbsGoal: Double
    let fatsGoal: Double
    let fiberGoal: Double

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesGrid: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        NutritionDetailsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(WeekFitLocalizedString("nutrition.details.section.macroBalance"))
                    .font(NutritionDetailsDesign.Typography.sectionTitle)
                    .foregroundStyle(WeekFitLightTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if usesGrid {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 12
                    ) {
                        items
                    }
                } else {
                    HStack(alignment: .top, spacing: 2) {
                        items
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var items: some View {
        MacroProgressItem(
            title: WeekFitLocalizedString("nutrition.macro.protein"),
            value: protein,
            goal: proteinGoal,
            color: NutritionDetailsDesign.protein
        )
        MacroProgressItem(
            title: WeekFitLocalizedString("nutrition.macro.carbs"),
            value: carbs,
            goal: carbsGoal,
            color: NutritionDetailsDesign.carbs
        )
        MacroProgressItem(
            title: WeekFitLocalizedString("nutrition.macro.fats"),
            value: fats,
            goal: fatsGoal,
            color: NutritionDetailsDesign.fats
        )
        MacroProgressItem(
            title: WeekFitLocalizedString("nutrition.macro.fiber"),
            value: fiber,
            goal: fiberGoal,
            color: NutritionDetailsDesign.fiber
        )
    }
}
