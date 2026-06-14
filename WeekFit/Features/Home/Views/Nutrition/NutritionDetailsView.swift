import SwiftUI

struct NutritionDetailsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager
    @State private var displayedDate: Date

    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double

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

                VStack(spacing: 9) {
                    NutritionHeroCard(
                        nutritionScore: nutritionScore,
                        statusText: nutritionStatusText,
                        insightText: nutritionInsightText
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

                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 13) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.075)))
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.Nutrition.Details.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(nutritionDetailsDateTitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .background {
            NutritionStyle.screenBackground.ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
    }

    private var nutritionScore: Int {
        let values = [
            macroProgress(value: protein, goal: proteinGoal),
            macroProgress(value: carbs, goal: carbsGoal),
            macroProgress(value: fats, goal: fatsGoal),
            macroProgress(value: fiber, goal: fiberGoal)
        ]

        guard !values.isEmpty else { return 0 }

        return Int((values.reduce(0, +) / Double(values.count) * 100).rounded())
    }

    private var nutritionDetailsDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter.string(from: displayedDate)
    }

    private func macroProgress(value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    private var isToday: Bool {
        Calendar.current.isDate(displayedDate, inSameDayAs: Date())
    }

    private var nutritionStatusText: String {
        if meals.isEmpty {
            return WeekFitLocalizedString("nutrition.details.status.noMealsLogged")
        }

        if !isToday {
            switch nutritionScore {
            case 95...:
                return WeekFitLocalizedString("nutrition.details.status.greatBalance")
            case 80..<95:
                return WeekFitLocalizedString("nutrition.details.status.wellBalanced")
            case 55..<80:
                return WeekFitLocalizedString("nutrition.details.status.partlyBalanced")
            default:
                return WeekFitLocalizedString("nutrition.details.status.lowLoggedIntake")
            }
        }

        switch nutritionScore {
        case 95...:
            return WeekFitLocalizedString("nutrition.details.status.onTarget")
        case 80..<95:
            return WeekFitLocalizedString("nutrition.details.status.nearlyBalanced")
        case 55..<80:
            return WeekFitLocalizedString("nutrition.details.status.buildingBalance")
        case 1..<55:
            return WeekFitLocalizedString("nutrition.details.status.needsAttention")
        default:
            return WeekFitLocalizedString("nutrition.details.status.noMealsYet")
        }
    }

    private var nutritionInsightText: String {
        let proteinProgress = macroProgress(value: protein, goal: proteinGoal)
        let fatProgress = macroProgress(value: fats, goal: fatsGoal)
        let fiberProgress = macroProgress(value: fiber, goal: fiberGoal)

        if meals.isEmpty {
            return isToday
            ? WeekFitLocalizedString("nutrition.details.insight.emptyToday")
            : WeekFitLocalizedString("nutrition.details.insight.emptyPastDay")
        }

        if !isToday {
            if nutritionScore >= 95 {
                return WeekFitLocalizedString("nutrition.details.insight.pastStrongBalance")
            }

            if proteinProgress >= 0.65 && fiberProgress < 0.50 {
                return WeekFitLocalizedString("nutrition.details.insight.pastProteinFiberLow")
            }

            if proteinProgress >= 0.65 && fatProgress < 0.45 {
                return WeekFitLocalizedString("nutrition.details.insight.pastProteinFatsLow")
            }

            if fiberProgress >= 0.70 {
                return WeekFitLocalizedString("nutrition.details.insight.pastFiberGood")
            }

            return WeekFitLocalizedString("nutrition.details.insight.pastLoggedMeals")
        }

        if proteinProgress >= 0.65 && fiberProgress < 0.50 {
            return WeekFitLocalizedString("nutrition.details.insight.todayProteinFiberLow")
        }

        if proteinProgress >= 0.65 && fatProgress < 0.45 {
            return WeekFitLocalizedString("nutrition.details.insight.todayProteinFatsLow")
        }

        if fiberProgress >= 0.70 {
            return WeekFitLocalizedString("nutrition.details.insight.todayFiberGood")
        }

        if nutritionScore >= 90 {
            return WeekFitLocalizedString("nutrition.details.insight.todayCloseTargets")
        }

        return WeekFitLocalizedString("nutrition.details.insight.calculated")
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
                .foregroundStyle(.white.opacity(0.34))
                .lineSpacing(2.5)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Hero

private struct NutritionHeroCard: View {
    let nutritionScore: Int
    let statusText: String
    let insightText: String

    private var progress: CGFloat {
        CGFloat(min(max(nutritionScore, 0), 100)) / 100
    }

    var body: some View {
        HStack(spacing: 15) {
            nutritionRing

            VStack(alignment: .leading, spacing: 5) {
                Text(WeekFitLocalizedString("nutrition.details.score.title").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(NutritionStyle.nutritionColor)

                Text(statusText)
                    .font(.system(size: NutritionTypography.heroTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(insightText)
                    .font(.system(size: NutritionTypography.heroText, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .nutritionCard(glow: NutritionStyle.nutritionColor.opacity(0.08))
    }

    private var nutritionRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.075), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            NutritionStyle.proteinColor.opacity(0.80),
                            NutritionStyle.nutritionColor,
                            NutritionStyle.fatColor.opacity(0.85),
                            NutritionStyle.fiberColor.opacity(0.85)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: NutritionStyle.nutritionColor.opacity(0.15), radius: 4)

            VStack(spacing: -2) {
                Text("\(nutritionScore)")
                    .font(.system(size: NutritionTypography.heroScore, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(WeekFitLocalizedString("common.unit.score"))
                    .font(.system(size: NutritionTypography.heroScoreLabel, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
        .frame(width: 70, height: 70)
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

            HStack(alignment: .top, spacing: 8) {
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
        let progress = goal > 0 ? min(max(value / goal, 0), 1) : 0
        let percent = Int((progress * 100).rounded())

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.075), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(percent)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: NutritionTypography.metricTitle, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)

                Text(String(format: WeekFitLocalizedString("nutrition.details.macro.valueFormat"), Int(value), Int(goal)))
                    .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
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
                ScrollView(showsIndicators: false) {
                       VStack(spacing: 0) {
                           ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                               mealRow(meal, isLast: index == meals.count - 1)
                           }
                       }
                       .padding(.vertical, 4)
                   }
                   .frame(maxHeight: 260)
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
                .foregroundStyle(.white.opacity(0.28))

            Text(AppText.Nutrition.Details.emptyTitle)
                .font(.system(size: NutritionTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))

            Text(WeekFitLocalizedString("nutrition.details.empty.timelineMessage"))
                .font(.system(size: NutritionTypography.helperText, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.40))
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
                .foregroundStyle(.white.opacity(0.50))
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
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 8)

                    Text(String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), meal.calories))
                        .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.38))
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
                .foregroundStyle(.white.opacity(0.38))
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
        let text = "\(meal.title) \(meal.imageName) \(meal.icon)".lowercased()

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
            .foregroundStyle(.white.opacity(0.68))
    }
}

// MARK: - Style

private enum NutritionTypography {
    static let sectionLabel: CGFloat = 11

    static let heroTitle: CGFloat = 20
    static let heroText: CGFloat = 12
    static let heroScore: CGFloat = 26
    static let heroScoreLabel: CGFloat = 9

    static let metricTitle: CGFloat = 12
    static let metricValue: CGFloat = 14
    static let metricSecondary: CGFloat = 12
    static let helperText: CGFloat = 11.5
}

private enum NutritionStyle {
    static let screenBackground = Color(red: 0.018, green: 0.019, blue: 0.022)
    static let cardBackground = Color(red: 0.045, green: 0.048, blue: 0.055)
    static let innerCardBackground = Color.white.opacity(0.035)
    static let border = Color.white.opacity(0.065)

    static let nutritionColor = Color(red: 0.95, green: 0.65, blue: 0.12)

    static let proteinColor = Color(red: 0.55, green: 0.40, blue: 0.95)
    static let carbsColor = Color(red: 1.00, green: 0.55, blue: 0.16)
    static let fatColor = Color(red: 1.00, green: 0.22, blue: 0.43)
    static let fiberColor = Color(red: 0.16, green: 0.80, blue: 0.43)
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
                                Color.white.opacity(0.030),
                                Color.white.opacity(0.004)
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
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
    }
}
