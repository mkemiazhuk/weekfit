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

        ZStack {
            palette.appScreenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NutritionDetailsHeader(
                    title: WeekFitLocalizedString("nutrition.details.title"),
                    subtitle: nutritionDetailsDateTitle,
                    background: palette.appScreenBackground,
                    onClose: { dismiss() }
                )

                HealthDetailsWeekPicker(
                    selectedDate: $displayedDate,
                    accentColor: NutritionDetailsDesign.nutritionAccent
                ) { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDateChanged(date)
                }
                .padding(.horizontal, 18)
                .padding(.top, 9)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: NutritionDetailsDesign.Reading.sectionSpacing) {
                        NutritionIntakeCard(
                            calories: calories,
                            caloriesGoal: caloriesGoal,
                            waterLiters: waterLiters,
                            waterGoal: waterGoal,
                            isToday: isToday
                        )

                        NutritionQualityCard(
                            qualityScore: nutritionQualityScore,
                            primaryInsightText: nutritionPrimaryInsight
                        )

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
                    .padding(.horizontal, NutritionDetailsDesign.Reading.horizontalPadding)
                    .padding(.bottom, 25)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("screen.nutritionDetails")
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
