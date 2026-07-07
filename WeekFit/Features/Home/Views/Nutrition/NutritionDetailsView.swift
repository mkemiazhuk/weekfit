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

    let waterLiters: Double
    let waterGoal: Double

    let meals: [PlannedActivity]
    let mealCatalog: [Meals]

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
        waterLiters: Double = 0,
        waterGoal: Double = 0,
        meals: [PlannedActivity],
        mealCatalog: [Meals] = [],
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
        self.waterLiters = waterLiters
        self.waterGoal = waterGoal
        self.meals = meals
        self.mealCatalog = mealCatalog
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
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 7) {
                        NutritionHeroCard(
                            qualityScore: nutritionQualityScore,
                            primaryInsightText: nutritionPrimaryInsight
                        )

                        NutritionBalanceCard(
                            waterLiters: waterLiters,
                            waterGoal: waterGoal,
                            calories: calories,
                            caloriesGoal: caloriesGoal,
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
                            mealCatalog: mealCatalog,
                            proteinColor: proteinColor,
                            carbsColor: carbsColor,
                            fatColor: fatColor,
                            fiberColor: fiberColor
                        )

                        noteCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(AppText.Nutrition.Details.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(nutritionDetailsDateTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                    .overlay {
                        Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppText.Common.Action.close))
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NutritionStyle.nutritionColor.opacity(0.62))
                .padding(.top, 1)

            Text(WeekFitLocalizedString("nutrition.details.note.full"))
                .font(.system(size: NutritionTypography.helperText, weight: .regular, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.32))
                .lineSpacing(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(WeekFitTheme.whiteOpacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Hero

private struct NutritionHeroCard: View {
    let qualityScore: Int
    let primaryInsightText: String

    private var progress: CGFloat {
        CGFloat(min(max(qualityScore, 0), 100)) / 100
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            nutritionRing

            VStack(alignment: .leading, spacing: 5) {
                Text(WeekFitLocalizedString("nutrition.details.quality.title"))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(NutritionStyle.nutritionColor)

                Text(primaryInsightText)
                    .font(.system(size: NutritionTypography.heroTitle, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(1.5)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .nutritionCard(glow: NutritionStyle.nutritionColor.opacity(0.07))
    }

    private var nutritionRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: WeekFitProgressRingColor.nutrition,
            size: 58,
            strokeWidth: 3.5,
            gradientColors: [
                Color(red: 0.58, green: 0.38, blue: 0.96).opacity(0.86),
                WeekFitProgressRingColor.nutrition,
                Color(red: 1.00, green: 0.28, blue: 0.38).opacity(0.92),
                Color(red: 0.36, green: 0.88, blue: 0.44).opacity(0.92)
            ]
        ) {
            VStack(spacing: -2) {
                Text("\(qualityScore)")
                    .font(.system(size: NutritionTypography.heroScore, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("/100")
                    .font(.system(size: NutritionTypography.heroScoreLabel, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
            }
        }
    }
}

// MARK: - Balance (hydration + macros)

private struct NutritionBalanceCard: View {
    let waterLiters: Double
    let waterGoal: Double
    let calories: Double
    let caloriesGoal: Double

    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double

    let proteinGoal: Double
    let carbsGoal: Double
    let fatsGoal: Double
    let fiberGoal: Double

    private var hydrationColor: Color {
        Color(red: 0.25, green: 0.55, blue: 0.95)
    }

    private var hydrationStatus: (text: String, color: Color) {
        guard waterGoal > 0 else {
            return (
                WeekFitLocalizedString("nutrition.details.hydration.status.unavailable"),
                WeekFitTheme.whiteOpacity(0.42)
            )
        }

        if waterLiters >= waterGoal {
            return (
                WeekFitLocalizedString("nutrition.details.hydration.status.goalReached"),
                Color(red: 0.36, green: 0.88, blue: 0.44)
            )
        }

        if waterLiters >= waterGoal * 0.85 {
            return (
                WeekFitLocalizedString("nutrition.details.hydration.status.onTrack"),
                hydrationColor
            )
        }

        return (
            WeekFitLocalizedString("nutrition.details.hydration.status.behind"),
            Color(red: 0.96, green: 0.68, blue: 0.30)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                intakePanel(
                    icon: "drop.fill",
                    title: WeekFitLocalizedString("nutrition.details.hydration.short"),
                    value: waterGoal > 0
                        ? String(
                            format: WeekFitLocalizedString("today.quickActions.waterProgressFormat"),
                            waterLiters,
                            waterGoal
                        )
                        : String(format: WeekFitLocalizedString("nutrition.details.hydration.literFormat"), waterLiters),
                    progress: waterGoal > 0 ? min(max(waterLiters / waterGoal, 0), 1) : 0,
                    color: hydrationColor,
                    status: hydrationStatus.text,
                    statusColor: hydrationStatus.color
                )

                intakePanel(
                    icon: "flame.fill",
                    title: WeekFitLocalizedString("nutrition.macro.calories"),
                    value: caloriesGoal > 0
                        ? String(format: WeekFitLocalizedString("nutrition.details.calories.progressFormat"), Int(calories), Int(caloriesGoal))
                        : String(format: WeekFitLocalizedString("nutrition.details.calories.valueFormat"), Int(calories)),
                    progress: caloriesGoal > 0 ? min(max(calories / caloriesGoal, 0), 1) : 0,
                    color: NutritionStyle.nutritionColor,
                    status: nil,
                    statusColor: nil
                )
            }

            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.045))
                .frame(height: 1)

            SectionLabel(WeekFitLocalizedString("nutrition.details.section.macroBalance"))

            HStack(alignment: .top, spacing: 4) {
                macroRing(title: WeekFitLocalizedString("nutrition.macro.protein"), value: protein, goal: proteinGoal, color: NutritionStyle.proteinColor)
                macroRing(title: WeekFitLocalizedString("nutrition.macro.carbs"), value: carbs, goal: carbsGoal, color: NutritionStyle.carbsColor)
                macroRing(title: WeekFitLocalizedString("nutrition.macro.fats"), value: fats, goal: fatsGoal, color: NutritionStyle.fatColor)
                macroRing(title: WeekFitLocalizedString("nutrition.macro.fiber"), value: fiber, goal: fiberGoal, color: NutritionStyle.fiberColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .nutritionCard(glow: NutritionStyle.nutritionColor.opacity(0.04))
    }

    private func intakePanel(
        icon: String,
        title: String,
        value: String,
        progress: Double,
        color: Color,
        status: String?,
        statusColor: Color?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.44))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)

                if let status, let statusColor {
                    Text(status)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            Text(value)
                .font(.system(size: NutritionTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WeekFitTheme.whiteOpacity(0.06))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.72), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress))
                }
            }
            .frame(height: 3.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.026))
        }
    }

    private func macroRing(title: String, value: Double, goal: Double, color: Color) -> some View {
        let progressValue = goal > 0 ? min(max(value / goal, 0), 1) : 0
        let progress = CGFloat(progressValue)
        let percent = Int((progressValue * 100).rounded())

        return VStack(spacing: 5) {
            WeekFitProgressRing(
                progress: progress,
                color: color,
                size: 46,
                strokeWidth: 3,
                gradientColors: [
                    color.opacity(0.78),
                    color,
                    color.opacity(0.90)
                ]
            ) {
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                    .monospacedDigit()
            }

            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: NutritionTypography.metricTitle, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(String(format: WeekFitLocalizedString("nutrition.details.macro.valueFormat"), Int(value), Int(goal)))
                    .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.36))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Timeline

private struct MealTimelineCard: View {
    let meals: [PlannedActivity]
    let mealCatalog: [Meals]
    let proteinColor: Color
    let carbsColor: Color
    let fatColor: Color
    let fiberColor: Color

    private var timelineChromeColor: Color {
        WeekFitTheme.whiteOpacity(0.12)
    }

    private var timelineConnectorColor: Color {
        WeekFitTheme.whiteOpacity(0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(WeekFitLocalizedString("nutrition.details.section.mealTimeline"))

            if meals.isEmpty {
                emptyMeals
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                        mealRow(meal, isLast: index == meals.count - 1)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .nutritionCard()
    }

    private var emptyMeals: some View {
        VStack(spacing: 7) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.26))

            Text(AppText.Nutrition.Details.emptyTitle)
                .font(.system(size: NutritionTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))

            Text(WeekFitLocalizedString("nutrition.details.empty.timelineMessage"))
                .font(.system(size: NutritionTypography.helperText, weight: .regular, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .innerNutritionCard(cornerRadius: 16)
    }

    private func mealRow(_ meal: PlannedActivity, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(meal.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(.system(size: NutritionTypography.metricSecondary, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.46))
                .frame(width: 40, alignment: .leading)
                .padding(.top, 5)

            VStack(spacing: 0) {
                mealAvatar(for: meal)

                if !isLast {
                    Rectangle()
                        .fill(timelineConnectorColor)
                        .frame(width: 1, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(meal.title)
                        .font(.system(size: NutritionTypography.metricValue, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 4)

                    Text(String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), meal.calories))
                        .font(.system(size: NutritionTypography.metricSecondary, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                        .lineLimit(1)
                }

                macroSummaryRow(meal)
            }
            .padding(.top, 2)
        }
        .padding(.bottom, isLast ? 0 : 8)
    }

    @ViewBuilder
    private func mealAvatar(for meal: PlannedActivity) -> some View {
        if let visual = PlanTimelineNutritionVisualResolver.resolve(for: meal, customMeals: mealCatalog) {
            PlanTimelineNutritionAvatar(
                visual: visual,
                accent: .white,
                backgroundOpacity: 0.07,
                foregroundOpacity: 0.88,
                size: 32,
                contentSize: 22
            )
            .overlay {
                Circle()
                    .stroke(timelineChromeColor, lineWidth: 1)
                    .frame(width: 32, height: 32)
            }
        } else {
            ZStack {
                Circle()
                    .fill(timelineChromeColor)
                    .frame(width: 32, height: 32)

                Circle()
                    .stroke(WeekFitTheme.whiteOpacity(0.08), lineWidth: 1)
                    .frame(width: 32, height: 32)

                Image(systemName: mealTimelineIcon(for: meal))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
            }
        }
    }

    private func macroSummaryRow(_ meal: PlannedActivity) -> some View {
        let resolvedFiber = PlannedActivityNutritionResolver.resolvedFiber(for: meal, in: mealCatalog)

        return HStack(spacing: 6) {
            macroInlineItem(
                label: WeekFitLocalizedString("meals.library.macroProtein"),
                value: meal.protein,
                tint: proteinColor
            )

            macroSeparator

            macroInlineItem(
                label: WeekFitLocalizedString("meals.library.macroCarbs"),
                value: meal.carbs,
                tint: carbsColor
            )

            macroSeparator

            macroInlineItem(
                label: WeekFitLocalizedString("meals.library.macroFats"),
                value: meal.fats,
                tint: fatColor
            )

            if resolvedFiber > 0 {
                macroSeparator

                macroInlineItem(
                    label: WeekFitLocalizedString("meals.library.macroFiber"),
                    value: resolvedFiber,
                    tint: fiberColor
                )
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private var macroSeparator: some View {
        Text("·")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.22))
    }

    private func macroInlineItem(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(tint.opacity(0.55))

            Text(String(format: WeekFitLocalizedString("common.unit.gramFormat"), value))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
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
    static let sectionLabel: CGFloat = 10

    static let heroTitle: CGFloat = 16
    static let heroScore: CGFloat = 22
    static let heroScoreLabel: CGFloat = 8

    static let metricTitle: CGFloat = 10.5
    static let metricValue: CGFloat = 13
    static let metricSecondary: CGFloat = 11
    static let helperText: CGFloat = 10.5
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
        cornerRadius: CGFloat = 20,
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
                                WeekFitTheme.whiteOpacity(0.028),
                                WeekFitTheme.whiteOpacity(0.003)
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
                                center: .topTrailing,
                                startRadius: 8,
                                endRadius: 140
                            )
                        )
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(NutritionStyle.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
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
