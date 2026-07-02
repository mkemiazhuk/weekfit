import SwiftUI
import WeekFitPlanner

struct NutritionDetailsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager
    @State private var displayedDate: Date

    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double

    let caloriesGoal: Double
    let proteinGoal: Double
    let carbsGoal: Double
    let fatsGoal: Double
    let fiberGoal: Double

    let meals: [PlannedActivity]

    var onDateChanged: (Date) -> Void = { _ in }

    private let proteinColor = NutritionStyle.proteinColor
    private let carbsColor = NutritionStyle.carbsColor
    private let fatColor = NutritionStyle.fatColor
    private let fiberColor = NutritionStyle.fiberColor

    init(
        selectedDate: Date,
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        caloriesGoal: Double,
        proteinGoal: Double,
        carbsGoal: Double,
        fatsGoal: Double,
        fiberGoal: Double,
        meals: [PlannedActivity],
        onDateChanged: @escaping (Date) -> Void = { _ in }
    ) {
        self._displayedDate = State(initialValue: selectedDate)
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.caloriesGoal = caloriesGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatsGoal = fatsGoal
        self.fiberGoal = fiberGoal
        self.meals = meals
        self.onDateChanged = onDateChanged
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            NutritionStyle.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                HealthDetailsWeekPicker(
                    selectedDate: $displayedDate,
                    accentColor: NutritionStyle.nutritionColor
                ) { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDateChanged(date)
                }
                .padding(.horizontal, 18)
                .padding(.top, 9)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
                        NutritionHeroCard(
                            qualityScore: nutritionQualityScore,
                            subtitleText: nutritionQualitySubtitle,
                            primaryInsightText: nutritionPrimaryInsight
                        )

                        MacroRingsCard(
                            protein: protein,
                            carbs: carbs,
                            fats: fats,
                            fiber: fiber,
                            proteinGoal: proteinGoal,
                            carbsGoal: carbsGoal,
                            fatsGoal: fatsGoal,
                            fiberGoal: fiberGoal
                        )

                        MealTimelineCard(
                            meals: meals,
                            proteinColor: proteinColor,
                            carbsColor: carbsColor,
                            fatColor: fatColor,
                            fiberColor: fiberColor
                        )

                        noteCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 5)
                    .padding(.bottom, 36)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.Nutrition.Details.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(nutritionDetailsDateTitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                    .overlay {
                        Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppText.Common.Action.close))
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .background {
            NutritionStyle.screenBackground.ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.04))
                .frame(height: 1)
        }
    }

    private var nutritionQualityInput: NutritionQualityPresenter.Input {
        NutritionQualityPresenter.Input(
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            calories: calories,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatsGoal: fatsGoal,
            fiberGoal: fiberGoal,
            caloriesGoal: caloriesGoal,
            mealsLogged: !meals.isEmpty,
            isToday: isToday
        )
    }

    private var nutritionQualityScore: Int {
        NutritionQualityPresenter.qualityScore(for: nutritionQualityInput)
    }

    private var nutritionQualitySubtitle: String {
        NutritionQualityPresenter.subtitleText(isToday: isToday)
    }

    private var nutritionPrimaryInsight: String {
        NutritionQualityPresenter.primaryInsightText(for: nutritionQualityInput)
    }

    private var nutritionDetailsDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter.string(from: displayedDate)
    }

    private var isToday: Bool {
        Calendar.current.isDate(displayedDate, inSameDayAs: Date())
    }

    private var noteCard: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NutritionStyle.nutritionColor.opacity(0.10))
                    .frame(width: 32, height: 32)

                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NutritionStyle.nutritionColor.opacity(0.78))
            }

            Text(WeekFitLocalizedString("nutrition.details.note.full"))
                .font(.system(size: NutritionTypography.helperText, weight: .regular, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.34))
                .lineSpacing(2.5)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(WeekFitTheme.whiteOpacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Hero

private struct NutritionHeroCard: View {
    let qualityScore: Int
    let subtitleText: String
    let primaryInsightText: String

    private var progress: CGFloat {
        CGFloat(min(max(qualityScore, 0), 100)) / 100
    }

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            nutritionRing

            VStack(alignment: .leading, spacing: 8) {
                Text(WeekFitLocalizedString("nutrition.details.quality.title"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(NutritionStyle.nutritionColor)

                Text(primaryInsightText)
                    .font(.system(size: NutritionTypography.heroTitle, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitleText)
                    .font(.system(size: NutritionTypography.heroText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .nutritionCard(glow: NutritionStyle.nutritionColor.opacity(0.08))
    }

    private var nutritionRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: WeekFitProgressRingColor.nutrition,
            size: 70,
            strokeWidth: 4,
            gradientColors: [
                Color(red: 0.58, green: 0.38, blue: 0.96).opacity(0.86),
                WeekFitProgressRingColor.nutrition,
                Color(red: 1.00, green: 0.28, blue: 0.38).opacity(0.92),
                Color(red: 0.36, green: 0.88, blue: 0.44).opacity(0.92)
            ]
        ) {
            VStack(spacing: -1) {
                Text("\(qualityScore)")
                    .font(.system(size: NutritionTypography.heroScore, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("/100")
                    .font(.system(size: NutritionTypography.heroScoreLabel, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
            }
        }
    }
}

// MARK: - Macros

private struct MacroRingsCard: View {
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double

    let proteinGoal: Double
    let carbsGoal: Double
    let fatsGoal: Double
    let fiberGoal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("nutrition.details.section.macroBalance"))

            HStack(alignment: .top, spacing: 6) {
                macroRing(title: WeekFitLocalizedString("nutrition.macro.protein"), value: protein, goal: proteinGoal, color: NutritionStyle.proteinColor)
                macroRing(title: WeekFitLocalizedString("nutrition.macro.carbs"), value: carbs, goal: carbsGoal, color: NutritionStyle.carbsColor)
                macroRing(title: WeekFitLocalizedString("nutrition.macro.fats"), value: fats, goal: fatsGoal, color: NutritionStyle.fatColor)
                macroRing(title: WeekFitLocalizedString("nutrition.macro.fiber"), value: fiber, goal: fiberGoal, color: NutritionStyle.fiberColor)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .nutritionCard(glow: NutritionStyle.nutritionColor.opacity(0.035))
    }

    private func macroRing(title: String, value: Double, goal: Double, color: Color) -> some View {
        let progressValue = goal > 0 ? min(max(value / goal, 0), 1) : 0
        let progress = CGFloat(progressValue)
        let percent = Int((progressValue * 100).rounded())

        return VStack(spacing: 7) {
            WeekFitProgressRing(
                progress: progress,
                color: color,
                size: 54,
                strokeWidth: 3.5,
                gradientColors: [
                    color.opacity(0.78),
                    color,
                    color.opacity(0.90)
                ]
            ) {
                Text("\(percent)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                    .monospacedDigit()
            }

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: NutritionTypography.metricTitle, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(String(format: WeekFitLocalizedString("nutrition.details.macro.valueFormat"), Int(value), Int(goal)))
                    .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Timeline

private struct MealTimelineCard: View {
    let meals: [PlannedActivity]
    let proteinColor: Color
    let carbsColor: Color
    let fatColor: Color
    let fiberColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("nutrition.details.section.mealTimeline"))

            if meals.isEmpty {
                emptyMeals
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                        mealRow(meal, isLast: index == meals.count - 1)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .nutritionCard()
    }

    private var emptyMeals: some View {
        VStack(spacing: 9) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.28))

            Text(AppText.Nutrition.Details.emptyTitle)
                .font(.system(size: NutritionTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.76))

            Text(WeekFitLocalizedString("nutrition.details.empty.timelineMessage"))
                .font(.system(size: NutritionTypography.helperText, weight: .regular, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .innerNutritionCard(cornerRadius: 18)
    }

    private func mealRow(_ meal: PlannedActivity, isLast: Bool) -> some View {
        let accent = mealTimelineAccent(for: meal)

        return HStack(alignment: .top, spacing: 12) {
            Text(meal.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.50))
                .frame(width: 44, alignment: .leading)
                .padding(.top, 7)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.20))
                        .frame(width: 36, height: 36)

                    Circle()
                        .stroke(accent.opacity(0.22), lineWidth: 1)
                        .frame(width: 36, height: 36)

                    Image(systemName: mealTimelineIcon(for: meal))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.95))
                }

                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.14),
                                    accent.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 34)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(meal.title)
                        .font(.system(size: NutritionTypography.metricValue, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 8)

                    Text(String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), meal.calories))
                        .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                        .lineLimit(1)
                }

                macroSummaryRow(meal)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, isLast ? 0 : 12)
    }

    private func macroSummaryRow(_ meal: PlannedActivity) -> some View {
        HStack(spacing: 8) {
            compactMacroText(WeekFitLocalizedString("meals.library.macroProtein"), meal.protein, proteinColor)
            compactMacroText(WeekFitLocalizedString("meals.library.macroCarbs"), meal.carbs, carbsColor)
            compactMacroText(WeekFitLocalizedString("meals.library.macroFats"), meal.fats, fatColor)

            if meal.fiber > 0 {
                compactMacroText(WeekFitLocalizedString("nutrition.macro.fiber"), meal.fiber, fiberColor)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private func compactMacroText(_ title: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 2.5) {
            Text(title)
                .font(.system(size: NutritionTypography.helperText, weight: .semibold, design: .rounded))
                .foregroundStyle(color.opacity(0.92))

            Text(String(format: WeekFitLocalizedString("common.unit.gramFormat"), value))
                .font(.system(size: NutritionTypography.helperText, weight: .regular, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
        }
    }

    private func mealTimelineAccent(for meal: PlannedActivity) -> Color {
        let text = "\(meal.title) \(meal.imageName) \(meal.icon)".lowercased()

        if text.contains("juice") || text.contains("orange") || text.contains("fruit") {
            return NutritionStyle.carbsColor
        }

        if text.contains("chocolate") || text.contains("nuts") || text.contains("snack") {
            return NutritionStyle.proteinColor
        }

        if text.contains("turkey") || text.contains("chicken") || text.contains("egg") || text.contains("protein") {
            return NutritionStyle.proteinColor
        }

        if text.contains("rice") || text.contains("pasta") || text.contains("toast") || text.contains("carb") {
            return NutritionStyle.carbsColor
        }

        if text.contains("cottage") || text.contains("cheese") || text.contains("yogurt") {
            return NutritionStyle.proteinColor
        }

        return NutritionStyle.proteinColor
    }

    private func mealTimelineIcon(for meal: PlannedActivity) -> String {
        let normalizedType = meal.type.lowercased()
        if normalizedType == "drink" || normalizedType == "hydration" {
            return WeekFitActivityIconResolver.resolve(for: meal)
        }

        let text = "\(meal.title) \(meal.imageName) \(meal.icon)".lowercased()

        if text.contains("water") || text.contains("hydration") {
            return WeekFitActivityIconResolver.resolve(for: meal)
        }

        if text.contains("coffee") || text.contains("espresso") || text.contains("latte") || text.contains("tea") {
            return WeekFitActivityIconResolver.resolve(for: meal)
        }

        if text.contains("juice") || text.contains("drink") {
            return "takeoutbag.and.cup.and.straw.fill"
        }

        if text.contains("chocolate") || text.contains("snack") || text.contains("nuts") {
            return "square.grid.2x2.fill"
        }

        if text.contains("egg") || text.contains("toast") || text.contains("breakfast") {
            return "fork.knife"
        }

        if meal.icon.isEmpty {
            return "fork.knife"
        }

        return meal.icon
    }
}

// MARK: - Shared UI

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: NutritionTypography.sectionLabel, weight: .bold, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.68))
    }
}

// MARK: - Style

private enum NutritionTypography {
    static let sectionLabel: CGFloat = 11

    static let heroTitle: CGFloat = 18
    static let heroText: CGFloat = 12
    static let heroScore: CGFloat = 26
    static let heroScoreLabel: CGFloat = 9

    static let metricTitle: CGFloat = 12
    static let metricValue: CGFloat = 14
    static let metricSecondary: CGFloat = 12
    static let helperText: CGFloat = 11.5
}

private enum NutritionStyle {
    static var screenBackground: Color { WeekFitTheme.backgroundColor }
    static var cardBackground: Color { Color(red: 0.045, green: 0.048, blue: 0.055) }
    static var innerCardBackground: Color { WeekFitTheme.cardTertiary }
    static var border: Color { WeekFitTheme.border }

    static var nutritionColor: Color { WeekFitTheme.accent(Color(red: 0.95, green: 0.65, blue: 0.12)) }

    static var proteinColor: Color { WeekFitTheme.accent(Color(red: 0.55, green: 0.40, blue: 0.95)) }
    static var carbsColor: Color { WeekFitTheme.accent(Color(red: 1.00, green: 0.55, blue: 0.16)) }
    static var fatColor: Color { WeekFitTheme.accent(Color(red: 1.00, green: 0.22, blue: 0.43)) }
    static var fiberColor: Color { WeekFitTheme.accent(Color(red: 0.16, green: 0.80, blue: 0.43)) }
}

private extension View {
    func nutritionCard(
        cornerRadius: CGFloat = 22,
        glow: Color = .clear
    ) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(NutritionStyle.cardBackground)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.whiteOpacity(0.030),
                                WeekFitTheme.whiteOpacity(0.004)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if glow != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [glow, .clear],
                                center: .trailing,
                                startRadius: 12,
                                endRadius: 170
                            )
                        )
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(NutritionStyle.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    func innerNutritionCard(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(NutritionStyle.innerCardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
    }
}
