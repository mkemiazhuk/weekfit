import Foundation
import WeekFitPlanner
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
              ),
              let nutrition = CoachDailyObservationNutritionBuilder.build(
                totals: resolved.totals,
                calorieTarget: calorieTarget,
                nutritionDataAvailable: nutritionDataAvailable || resolved.isAvailable
              ) else {
            return withTraining
        }

        return withTraining.mergingNutrition(nutrition)
    }
}
