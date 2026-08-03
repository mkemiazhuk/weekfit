import SwiftUI
import WeekFitPlanner

struct NutritionMealTimelineCard: View {
    let meals: [PlannedActivity]
    let mealCatalog: [Meals]
    var onMealTap: ((PlannedActivity) -> Void)? = nil

    private let proteinColor = NutritionDetailsDesign.protein
    private let carbsColor = NutritionDetailsDesign.carbs
    private let fatColor = NutritionDetailsDesign.fats
    private let fiberColor = NutritionDetailsDesign.fiber

    var body: some View {
        NutritionDetailsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(WeekFitLocalizedString("nutrition.details.section.mealTimeline"))
                    .font(NutritionDetailsDesign.Typography.sectionTitle)
                    .foregroundStyle(WeekFitLightTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if meals.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                            row(meal, isLast: index == meals.count - 1)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(WeekFitLightTokens.iconInactive)

            Text(AppText.Nutrition.Details.emptyTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WeekFitLightTokens.textPrimary)

            Text(WeekFitLocalizedString("nutrition.details.empty.timelineMessage"))
                .font(NutritionDetailsDesign.Typography.notice)
                .foregroundStyle(WeekFitLightTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func row(_ meal: PlannedActivity, isLast: Bool) -> some View {
        let content = HStack(alignment: .top, spacing: 8) {
            timelineIndicator(isLast: isLast)

            Text(timeText(for: meal.date))
                .font(NutritionDetailsDesign.Typography.mealMeta)
                .foregroundStyle(WeekFitLightTokens.textTertiary)
                .monospacedDigit()
                .frame(width: 38, alignment: .leading)
                .padding(.top, 8)

            mealAvatar(for: meal)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.title)
                    .font(NutritionDetailsDesign.Typography.mealTitle)
                    .foregroundStyle(WeekFitLightTokens.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                macroLine(for: meal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 5)

            Text(String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), meal.calories))
                .font(NutritionDetailsDesign.Typography.mealMeta)
                .foregroundStyle(WeekFitLightTokens.textSecondary)
                .padding(.top, 6)
        }
        .padding(.bottom, isLast ? 0 : 8)

        if let onMealTap {
            Button {
                onMealTap(meal)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
                .accessibilityElement(children: .combine)
        }
    }

    private func timelineIndicator(isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(WeekFitLightTokens.activity)
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            if !isLast {
                Rectangle()
                    .fill(WeekFitLightTokens.activity.opacity(0.22))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 8)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mealAvatar(for meal: PlannedActivity) -> some View {
        if let visual = PlanTimelineNutritionVisualResolver.resolve(for: meal, customMeals: mealCatalog) {
            PlanTimelineNutritionAvatar(
                visual: visual,
                accent: WeekFitLightTokens.textPrimary,
                backgroundOpacity: 0.04,
                foregroundOpacity: 0.95,
                size: 34,
                contentSize: 24
            )
            .overlay {
                Circle()
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.7)
            }
            .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .fill(WeekFitLightTokens.surfaceTertiary)
                    .frame(width: 34, height: 34)

                Image(systemName: "fork.knife")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WeekFitLightTokens.iconSecondary)
            }
            .accessibilityHidden(true)
        }
    }

    private func macroLine(for meal: PlannedActivity) -> some View {
        let fiber = PlannedActivityNutritionResolver.resolvedFiber(for: meal, in: mealCatalog)
        return HStack(spacing: 8) {
            macroChip("P", meal.protein, proteinColor)
            macroChip("C", meal.carbs, carbsColor)
            macroChip("F", meal.fats, fatColor)
            if fiber > 0 {
                macroChip("Fi", fiber, fiberColor)
            }
        }
        .font(NutritionDetailsDesign.Typography.mealMeta)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func macroChip(_ label: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
            Text("\(value)g")
                .foregroundStyle(WeekFitLightTokens.textTertiary)
        }
    }

    private func timeText(for date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}
