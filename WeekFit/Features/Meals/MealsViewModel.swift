import Foundation
internal import Combine

@MainActor
final class MealsViewModel: ObservableObject {

    private let lifecycleToken = "MealsViewModel"

    @Published var selectedDate = Date()
    @Published var customMeals: [Meals] = []
    @Published private(set) var hasLoadedCustomMeals = false
    @Published private(set) var cachedRecommendation: MealRecommendation?
    @Published private(set) var lastRecommendationSignature = ""

    init() {
        WeekFitLifecycleTracker.attach(lifecycleToken)
    }
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {
        WeekFitLifecycleTracker.detach(lifecycleToken)
    }

    func selectedDateTitle(for date: Date) -> String {
        WeekFitShortWeekdayMonthDay(date)
    }

    func plannedActivitiesForSelectedDate(
        selectedDate: Date,
        from plannedActivities: [PlannedActivity]
    ) -> [PlannedActivity] {
        let calendar = Calendar.current
        return plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: selectedDate)
        }
    }

    func loadCustomMealsAsync(storage: String) async -> (meals: [Meals], encodedStorage: String?) {
        await Task.detached(priority: .utility) {
            let loadedMeals = CustomMealStore.load(from: storage)
            let migratedMeals = loadedMeals.map { MealPhotoStore.ensureThumbnail(for: $0) }
            let encoded = migratedMeals != loadedMeals
                ? CustomMealStore.encode(migratedMeals)
                : nil

            MealPhotoStore.releaseMemoryCache()
            return (migratedMeals, encoded)
        }.value
    }

    func applyLoadedCustomMeals(_ meals: [Meals]) {
        customMeals = meals
        hasLoadedCustomMeals = true
    }

    func updateRecommendationIfNeeded(
        source: String,
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        mealItems: [Meals],
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        nutritionResult: NutritionResult?,
        languageCode: String
    ) {
        let signature = recommendationSignature(
            source: source,
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            mealItems: mealItems,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            nutritionResult: nutritionResult,
            languageCode: languageCode
        )
        guard signature != lastRecommendationSignature else { return }

        let nextRecommendation: MealRecommendation?
        if let input = coachCoordinator.state.input {
            nextRecommendation = MealRecommendationEngine.make(
                input: input,
                meals: mealItems,
                now: Date()
            )
        } else {
            nextRecommendation = nil
        }

        lastRecommendationSignature = signature
        if cachedRecommendation != nextRecommendation {
            cachedRecommendation = nextRecommendation
        }
    }

    private func recommendationSignature(
        source: String,
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        mealItems: [Meals],
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        nutritionResult: NutritionResult?,
        languageCode: String
    ) -> String {
        let snapshot = nutritionViewModel.coachMetricsSnapshot
        let goals = snapshot?.result.goals ?? nutritionResult?.goals
        let metrics = snapshot?.metrics
        let guidanceID = coachCoordinator.state.id.uuidString
        let day = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        let dayActivities = plannedActivitiesForSelectedDate(
            selectedDate: selectedDate,
            from: plannedActivities
        )
        let activitySignature = dayActivities
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.type,
                    activity.title,
                    "\(activity.durationMinutes)",
                    "\(activity.calories)",
                    "\(activity.protein)",
                    "\(activity.carbs)",
                    "\(activity.fats)",
                    "\(activity.fiber)",
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    activity.imageName
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        let mealSignature = mealItems
            .sorted { $0.id < $1.id }
            .map { meal in
                [
                    meal.id,
                    meal.title,
                    "\(meal.calories)",
                    "\(meal.protein)",
                    "\(meal.carbs)",
                    "\(meal.fats)",
                    "\(meal.fiber)"
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        return [
            languageCode,
            sourceNutritionSignature(
                nutritionViewModel: nutritionViewModel,
                nutritionResult: nutritionResult
            ),
            snapshot?.id.uuidString ?? "snapshot=nil",
            guidanceID,
            "\(Int(day / 86_400))",
            String(format: "%.1f", metrics?.calories ?? -1),
            String(format: "%.1f", metrics?.protein ?? -1),
            String(format: "%.1f", metrics?.carbs ?? -1),
            String(format: "%.1f", metrics?.fats ?? -1),
            String(format: "%.1f", metrics?.waterLiters ?? -1),
            String(format: "%.1f", goals?.calories ?? -1),
            String(format: "%.1f", goals?.protein ?? -1),
            String(format: "%.1f", goals?.carbs ?? -1),
            String(format: "%.1f", goals?.fats ?? -1),
            String(format: "%.1f", goals?.waterLiters ?? -1),
            activitySignature,
            mealSignature
        ].joined(separator: "#")
    }

    private func sourceNutritionSignature(
        nutritionViewModel: NutritionViewModel,
        nutritionResult: NutritionResult?
    ) -> String {
        if let snapshot = nutritionViewModel.coachMetricsSnapshot {
            return "snapshot:\(snapshot.id)"
        }

        if nutritionResult?.brain != nil {
            return "input"
        }

        return "missing"
    }
}
