import Foundation
import WeekFitPlanner

enum CoachObservationAssembler {

    static func makeObservation(
        dayKey: String,
        sleepMinutes: Int,
        recoveryPercent: Int,
        bedStartNormalizedMinutes: Int?,
        metrics: ActivityMetricsSnapshot,
        workouts: [CoachWorkoutObservationSample],
        trainingDataAvailable: Bool,
        healthNutritionSnapshot: NutritionMetricsSnapshot? = nil,
        plannedActivities: [CoachPlannedActivitySnapshot] = [],
        calorieTarget: Int? = nil,
        nutritionDataAvailable: Bool = false
    ) -> CoachDailyObservation {
        let base = CoachDailyObservation(
            dayKey: dayKey,
            sleepMinutes: sleepMinutes,
            recoveryPercent: recoveryPercent,
            bedStartNormalizedMinutes: bedStartNormalizedMinutes
        )

        let withTraining: CoachDailyObservation
        if let training = CoachDailyObservationTrainingBuilder.build(
            metrics: metrics,
            workouts: workouts,
            trainingDataAvailable: trainingDataAvailable
        ) {
            withTraining = base.mergingTraining(training)
        } else {
            withTraining = base
        }

        guard let date = CoachDailyObservation.date(fromDayKey: dayKey),
              let resolved = CoachNutritionObservationMapper.resolvedTotals(
                for: date,
                plannedActivities: plannedActivities,
                healthSnapshot: healthNutritionSnapshot
              ) else {
            return withTraining
        }

        let hasHealthKitSignal = healthNutritionSnapshot?.isResolved == true
        let hasPlannedMealSignal =
            resolved.totals.mealsLoggedCount > 0
            || resolved.totals.caloriesEaten > 0
            || resolved.totals.proteinGrams > 0
        let source = CoachNutritionSourceClassifier.infer(
            hasHealthKitSignal: hasHealthKitSignal,
            hasPlannedMealSignal: hasPlannedMealSignal
        )
        let dayStart = Calendar.current.startOfDay(for: date)
        let workoutEndMinutes = withTraining.hardestWorkoutEndMinutes
            ?? CoachPostWorkoutNutritionObservation.hardestWorkoutEndMinutes(from: workouts)
        let postWorkoutProtein = CoachPostWorkoutNutritionObservation.proteinGramsWithinWindow(
            dayStart: dayStart,
            workoutEndMinutes: workoutEndMinutes,
            plannedActivities: plannedActivities
        )

        guard let nutrition = CoachDailyObservationNutritionBuilder.build(
            totals: resolved.totals,
            calorieTarget: calorieTarget,
            nutritionDataAvailable: nutritionDataAvailable || resolved.isAvailable,
            source: source,
            proteinWithinPostWorkoutWindowGrams: postWorkoutProtein
        ) else {
            return withTraining
        }

        return withTraining.mergingNutrition(nutrition)
    }
}
