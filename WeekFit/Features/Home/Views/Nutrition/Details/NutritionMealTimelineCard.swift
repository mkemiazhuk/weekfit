import SwiftUI
import WeekFitPlanner

struct NutritionMealTimelineCard: View {
    let meals: [PlannedActivity]
    let mealCatalog: [Meals]
    var onMealTap: ((PlannedActivity) -> Void)? = nil

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var expandedIDs: Set<String>

    init(
        meals: [PlannedActivity],
        mealCatalog: [Meals] = [],
        onMealTap: ((PlannedActivity) -> Void)? = nil
    ) {
        self.meals = meals
        self.mealCatalog = mealCatalog
        self.onMealTap = onMealTap
        _expandedIDs = State(initialValue: [])
    }

    var body: some View {
        NutritionDetailsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(WeekFitLocalizedString("nutrition.details.section.meals"))
                    .nutritionReading(15, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(palette.textPrimary)
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
        .onChange(of: meals.map(\.id)) { _, _ in
            expandedIDs = []
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "fork.knife.circle")
                .nutritionReading(25, weight: .semibold, relativeTo: .title2)
                .foregroundStyle(palette.iconInactive)

            Text(AppText.Nutrition.Details.emptyTitle)
                .nutritionReading(15, weight: .semibold, relativeTo: .body)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(WeekFitLocalizedString("nutrition.details.empty.timelineMessage"))
                .nutritionReading(14, weight: .regular, relativeTo: .subheadline)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func row(_ meal: PlannedActivity, isLast: Bool) -> some View {
        let catalogMeal = resolvedCatalogMeal(for: meal)
        let hasNutritionSnapshot = !(meal.nutritionSnapshotJSON ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let expanded = expandedIDs.contains(meal.id)
        let opensExternalDetail = onMealTap != nil

        VStack(alignment: .leading, spacing: 11) {
            Button {
                if let onMealTap {
                    onMealTap(meal)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if expanded {
                        expandedIDs.remove(meal.id)
                    } else {
                        expandedIDs.insert(meal.id)
                    }
                }
            } label: {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibleMealRow(
                            meal,
                            catalogMeal: catalogMeal,
                            hasNutritionSnapshot: hasNutritionSnapshot,
                            opensExternalDetail: opensExternalDetail,
                            expanded: expanded
                        )
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 12) {
                                mealAvatar(
                                    for: meal,
                                    catalogMeal: hasNutritionSnapshot ? nil : catalogMeal
                                )
                                mealTitles(for: meal, catalogMeal: catalogMeal)
                                    .frame(minWidth: 108, alignment: .leading)
                                calorieLabel(meal.calories)
                                    .fixedSize(horizontal: true, vertical: false)
                                disclosureIcon(opensExternalDetail: opensExternalDetail, expanded: expanded)
                                    .fixedSize()
                            }
                            compactMealRow(
                                meal,
                                catalogMeal: catalogMeal,
                                hasNutritionSnapshot: hasNutritionSnapshot,
                                opensExternalDetail: opensExternalDetail,
                                expanded: expanded
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rowAccessibilityLabel(for: meal, catalogMeal: catalogMeal))
            .accessibilityHint(
                Text(
                    WeekFitLocalizedString(
                        expanded
                            ? "nutrition.details.meal.hideNutrients"
                            : "nutrition.details.meal.showNutrients"
                    )
                )
            )
            .accessibilityAddTraits(expanded ? .isSelected : [])

            if expanded && !opensExternalDetail {
                nutrientDetails(for: meal, catalogMeal: catalogMeal)
            }
        }
        .padding(.bottom, isLast ? 0 : 13)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(palette.isLight ? WeekFitLightTokens.divider : Color.white.opacity(0.10))
                    .frame(height: 0.7)
            }
        }
    }

    private func accessibleMealRow(
        _ meal: PlannedActivity,
        catalogMeal: Meals?,
        hasNutritionSnapshot: Bool,
        opensExternalDetail: Bool,
        expanded: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 12) {
                mealAvatar(
                    for: meal,
                    catalogMeal: hasNutritionSnapshot ? nil : catalogMeal
                )
                Spacer(minLength: 12)
                disclosureIcon(opensExternalDetail: opensExternalDetail, expanded: expanded)
            }
            Text(timelineTitle(for: meal, catalogMeal: catalogMeal))
                .nutritionReading(17, weight: .semibold, relativeTo: .title3)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    mealTime(meal.date)
                        .fixedSize(horizontal: true, vertical: true)
                    Spacer(minLength: 8)
                    calorieLabel(meal.calories)
                }
                VStack(alignment: .leading, spacing: 2) {
                    mealTime(meal.date)
                    calorieLabel(meal.calories)
                }
            }
        }
    }

    private func compactMealRow(
        _ meal: PlannedActivity,
        catalogMeal: Meals?,
        hasNutritionSnapshot: Bool,
        opensExternalDetail: Bool,
        expanded: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            mealAvatar(
                for: meal,
                catalogMeal: hasNutritionSnapshot ? nil : catalogMeal
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(timelineTitle(for: meal, catalogMeal: catalogMeal))
                    .nutritionReading(17, weight: .semibold, relativeTo: .title3)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timeText(for: meal.date))
                        .nutritionReading(14, weight: .regular, relativeTo: .subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .monospacedDigit()
                    Spacer(minLength: 8)
                    calorieLabel(meal.calories)
                }
            }
            disclosureIcon(opensExternalDetail: opensExternalDetail, expanded: expanded)
        }
    }

    private func mealTitles(for meal: PlannedActivity, catalogMeal: Meals?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(timelineTitle(for: meal, catalogMeal: catalogMeal))
                .nutritionReading(17, weight: .semibold, relativeTo: .title3)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            mealTime(meal.date)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func calorieLabel(_ calories: Int) -> some View {
        Text(String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), calories))
            .nutritionReading(15, weight: .semibold, design: .rounded, relativeTo: .body)
            .foregroundStyle(palette.textPrimary)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: true)
    }

    private func disclosureIcon(opensExternalDetail: Bool, expanded: Bool) -> some View {
        Image(systemName: opensExternalDetail ? "chevron.right" : "chevron.down")
            .nutritionReading(12, weight: .semibold, relativeTo: .footnote)
            .foregroundStyle(palette.textTertiary)
            .rotationEffect(.degrees(!opensExternalDetail && expanded ? 180 : 0))
            .frame(width: 22, height: 44)
            .accessibilityHidden(true)
    }

    private func nutrientDetails(for meal: PlannedActivity, catalogMeal: Meals?) -> some View {
        let fiber = resolvedFiber(for: meal, catalogMeal: catalogMeal)
        return VStack(alignment: .leading, spacing: 7) {
            detailLine(
                WeekFitLocalizedString("nutrition.macro.protein"),
                meal.protein,
                WeekFitLightTokens.protein
            )
            detailLine(
                WeekFitLocalizedString("nutrition.macro.carbs"),
                meal.carbs,
                WeekFitLightTokens.carbs
            )
            detailLine(
                WeekFitLocalizedString("nutrition.macro.fats"),
                meal.fats,
                WeekFitLightTokens.fats
            )
            if fiber > 0 {
                detailLine(
                    WeekFitLocalizedString("nutrition.macro.fiber"),
                    fiber,
                    WeekFitLightTokens.fiber
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func detailLine(_ title: String, _ grams: Int, _ tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(title)
                .nutritionReading(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(gramText(grams))
                .nutritionReading(15, weight: .semibold, design: .rounded, relativeTo: .body)
                .foregroundStyle(palette.textSecondary)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: true)
        }
        .frame(minHeight: 25)
    }

    @ViewBuilder
    private func mealAvatar(for meal: PlannedActivity, catalogMeal: Meals?) -> some View {
        let side = NutritionDetailsDesign.Reading.mealPhoto
        if let visual = PlanTimelineNutritionVisualResolver.resolve(
            for: meal,
            customMeals: mealCatalog,
            prematchedMeal: catalogMeal
        ) {
            PlanTimelineNutritionAvatar(
                visual: visual,
                accent: palette.textPrimary,
                backgroundOpacity: palette.isLight ? 0.04 : 0.08,
                foregroundOpacity: 0.92,
                size: side,
                contentSize: side
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        palette.isLight ? WeekFitLightTokens.cardBorder.opacity(0.12) : Color.white.opacity(0.08),
                        lineWidth: 0.7
                    )
            }
            .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .fill(palette.isLight ? WeekFitLightTokens.surfaceTertiary : Color.white.opacity(0.06))
                Image(systemName: "fork.knife")
                    .nutritionReading(18, weight: .semibold, relativeTo: .title3)
                    .foregroundStyle(palette.iconSecondary)
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)
        }
    }

    private func gramText(_ grams: Int) -> String {
        let locale = WeekFitCurrentLocale()
        return String(
            format: WeekFitLocalizedString("nutrition.details.quantity.amount", locale: locale),
            locale: locale,
            NutritionDetailsFormat.integer(Double(grams), locale: locale),
            WeekFitLocalizedString("common.unit.gramShort", locale: locale)
        )
    }

    private func rowAccessibilityLabel(for meal: PlannedActivity, catalogMeal: Meals?) -> String {
        [
            timelineTitle(for: meal, catalogMeal: catalogMeal),
            timeText(for: meal.date),
            String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), meal.calories)
        ].joined(separator: ", ")
    }

    private func resolvedFiber(for meal: PlannedActivity, catalogMeal: Meals?) -> Int {
        if meal.fiber > 0 { return meal.fiber }
        return catalogMeal?.fiber ?? PlannedActivityNutritionResolver.resolvedFiber(for: meal, in: mealCatalog)
    }

    private func mealTime(_ date: Date) -> some View {
        Text(timeText(for: date))
            .nutritionReading(14, weight: .regular, relativeTo: .subheadline)
            .foregroundStyle(palette.textSecondary)
            .monospacedDigit()
    }

    private func timeText(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(WeekFitCurrentLocale())
        )
    }

    private func timelineTitle(for meal: PlannedActivity, catalogMeal: Meals?) -> String {
        if let catalogMeal {
            return catalogMeal.localizedShortTitle
        }

        let trimmedTitle = meal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let quickLocalized = QuickItem.localizedTitle(forStoredTitle: trimmedTitle)
        if quickLocalized != trimmedTitle {
            return quickLocalized
        }

        return MealBuilderTitleComposer.localizedStoredTitle(meal.title)
    }

    private func resolvedCatalogMeal(for meal: PlannedActivity) -> Meals? {
        if let libraryId = meal.libraryMealId?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !libraryId.isEmpty,
           let byId = mealCatalog.first(where: { $0.id == libraryId }) {
            return byId
        }

        return CustomMealStore.meal(
            matchingActivityTitle: meal.title,
            in: mealCatalog
        )
    }
}
