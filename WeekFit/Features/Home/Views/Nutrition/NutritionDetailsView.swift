import SwiftUI
import WeekFitPlanner

struct NutritionDetailsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
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

        Group {
            if palette.isLight {
                lightBody
            } else {
                NutritionDetailsLegacyContent(
                    selectedDate: displayedDate,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fats: fats,
                    fiber: fiber,
                    caloriesGoal: caloriesGoal,
                    proteinGoal: proteinGoal,
                    carbsGoal: carbsGoal,
                    fatsGoal: fatsGoal,
                    fiberGoal: fiberGoal,
                    waterLiters: waterLiters,
                    waterGoal: waterGoal,
                    meals: meals,
                    mealCatalog: mealCatalog,
                    onDateChanged: { newDate in
                        displayedDate = newDate
                        onDateChanged(newDate)
                    }
                )
            }
        }
    }

    // MARK: - Light (reference redesign)

    private var lightBody: some View {
        ZStack {
            NutritionDetailsDesign.canvas
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NutritionDetailsHeader(
                    title: WeekFitLocalizedString("nutrition.details.title"),
                    subtitle: nutritionDetailsDateTitle,
                    onClose: { dismiss() }
                )

                NutritionWeekSelector(
                    selectedDate: $displayedDate,
                    accentColor: NutritionDetailsDesign.nutritionAccent
                ) { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDateChanged(date)
                }
                .padding(.horizontal, NutritionDetailsDesign.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 2)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: NutritionDetailsDesign.sectionSpacing) {
                        NutritionQualityCard(
                            qualityScore: nutritionQualityScore,
                            primaryInsightText: nutritionPrimaryInsight,
                            primaryInsight: nutritionPrimaryInsightKind
                        )

                        metricsRow

                        MacroBalanceCard(
                            protein: protein,
                            carbs: carbs,
                            fats: fats,
                            fiber: fiber,
                            proteinGoal: proteinGoal,
                            carbsGoal: carbsGoal,
                            fatsGoal: fatsGoal,
                            fiberGoal: fiberGoal
                        )

                        NutritionMealTimelineCard(
                            meals: meals,
                            mealCatalog: mealCatalog
                        )

                        NutritionEstimateNotice(
                            message: WeekFitLocalizedString("nutrition.details.note.full")
                        )
                    }
                    .padding(.horizontal, NutritionDetailsDesign.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var metricsRow: some View {
        let waterPercent = percent(waterLiters, of: waterGoal)
        let caloriePercent = percent(calories, of: caloriesGoal)
        let status = hydrationStatus

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                waterCard(percent: waterPercent, status: status)
                caloriesCard(percent: caloriePercent)
            }

            VStack(spacing: 10) {
                waterCard(percent: waterPercent, status: status)
                caloriesCard(percent: caloriePercent)
            }
        }
    }

    private func waterCard(
        percent: Int?,
        status: (text: String, color: Color)?
    ) -> some View {
        NutritionMetricCard(
            kind: .water,
            title: WeekFitLocalizedString("nutrition.details.hydration.short"),
            valueText: waterGoal > 0
                ? String(
                    format: WeekFitLocalizedString("today.quickActions.waterProgressFormat"),
                    waterLiters,
                    waterGoal
                )
                : String(
                    format: WeekFitLocalizedString("nutrition.details.hydration.literFormat"),
                    waterLiters
                ),
            percentOfGoal: percent,
            progress: waterGoal > 0 ? min(max(waterLiters / waterGoal, 0), 1) : 0,
            statusText: status?.text,
            statusColor: status?.color
        )
    }

    private func caloriesCard(percent: Int?) -> some View {
        NutritionMetricCard(
            kind: .calories,
            title: WeekFitLocalizedString("nutrition.macro.calories"),
            valueText: caloriesGoal > 0
                ? String(
                    format: WeekFitLocalizedString("nutrition.details.calories.progressFormat"),
                    Int(calories),
                    Int(caloriesGoal)
                )
                : String(
                    format: WeekFitLocalizedString("nutrition.details.calories.valueFormat"),
                    Int(calories)
                ),
            percentOfGoal: percent,
            progress: caloriesGoal > 0 ? min(max(calories / caloriesGoal, 0), 1) : 0,
            statusText: nil,
            statusColor: nil
        )
    }

    // MARK: - Shared derived state

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
            isToday: Calendar.current.isDate(displayedDate, inSameDayAs: Date())
        )
    }

    private var nutritionQualityScore: Int {
        NutritionQualityPresenter.qualityScore(for: nutritionQualityInput)
    }

    private var nutritionPrimaryInsightKind: NutritionQualityPresenter.PrimaryInsight {
        NutritionQualityPresenter.primaryInsight(for: nutritionQualityInput)
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

    private var hydrationStatus: (text: String, color: Color)? {
        guard waterGoal > 0 else { return nil }

        if waterLiters >= waterGoal {
            return (
                WeekFitLocalizedString("nutrition.details.hydration.status.goalReached"),
                WeekFitLightTokens.success
            )
        }

        if waterLiters >= waterGoal * 0.85 {
            return (
                WeekFitLocalizedString("nutrition.details.hydration.status.onTrack"),
                NutritionDetailsDesign.waterAccent
            )
        }

        return (
            WeekFitLocalizedString("nutrition.details.hydration.status.behind"),
            NutritionDetailsDesign.waterAccent
        )
    }

    private func percent(_ value: Double, of goal: Double) -> Int? {
        guard goal > 0 else { return nil }
        return Int(((value / goal) * 100).rounded())
    }
}

#if DEBUG
#Preview("Nutrition Details — Standard") {
    NutritionDetailsView(
        selectedDate: Date(),
        calories: 445,
        protein: 24,
        carbs: 45,
        fats: 18,
        fiber: 7,
        caloriesGoal: 1986,
        proteinGoal: 153,
        carbsGoal: 194,
        fatsGoal: 66,
        fiberGoal: 27,
        waterLiters: 1.2,
        waterGoal: 3.7,
        meals: [
            PlannedActivity(
                date: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date()) ?? Date(),
                type: "meal",
                title: "Cottage Cheese Toast",
                durationMinutes: 20,
                icon: "fork.knife",
                imageName: "",
                colorRed: 0.9,
                colorGreen: 0.6,
                colorBlue: 0.2,
                calories: 445,
                protein: 24,
                carbs: 45,
                fats: 18,
                fiber: 7,
                source: "preview"
            )
        ]
    )
    .environmentObject(AppLanguageManager())
    .preferredColorScheme(.light)
}

#Preview("Nutrition Details — Empty timeline") {
    NutritionDetailsView(
        selectedDate: Date(),
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
        fiber: 0,
        caloriesGoal: 1986,
        proteinGoal: 153,
        carbsGoal: 194,
        fatsGoal: 66,
        fiberGoal: 27,
        waterLiters: 0.4,
        waterGoal: 3.7,
        meals: []
    )
    .environmentObject(AppLanguageManager())
    .preferredColorScheme(.light)
}

#Preview("Nutrition Details — Long insight") {
    NutritionDetailsView(
        selectedDate: Date(),
        calories: 1200,
        protein: 40,
        carbs: 120,
        fats: 40,
        fiber: 10,
        caloriesGoal: 1986,
        proteinGoal: 153,
        carbsGoal: 194,
        fatsGoal: 66,
        fiberGoal: 27,
        waterLiters: 2.1,
        waterGoal: 3.7,
        meals: []
    )
    .environmentObject(AppLanguageManager())
    .preferredColorScheme(.light)
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Nutrition Details — iPhone mini") {
    NutritionDetailsView(
        selectedDate: Date(),
        calories: 445,
        protein: 24,
        carbs: 45,
        fats: 18,
        fiber: 7,
        caloriesGoal: 1986,
        proteinGoal: 153,
        carbsGoal: 194,
        fatsGoal: 66,
        fiberGoal: 27,
        waterLiters: 1.2,
        waterGoal: 3.7,
        meals: []
    )
    .environmentObject(AppLanguageManager())
    .preferredColorScheme(.light)
}
#endif
