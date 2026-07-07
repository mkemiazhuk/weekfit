import Foundation
import HealthKit
import WeekFitHealthKit

enum CoachWorkoutObservationMapper {

    static func samples(from workouts: [HKWorkout]) -> [CoachWorkoutObservationSample] {
        workouts.map(sample(from:))
    }

    private static func sample(from workout: HKWorkout) -> CoachWorkoutObservationSample {
        let activity = ActivityReconciler.importedActivity(for: workout)
        let snapshot = CoachPlannedActivitySnapshot(from: activity)
        let calories = Int(
            (workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0).rounded()
        )

        return CoachWorkoutObservationSample(
            typeToken: activity.title.lowercased(),
            durationMinutes: activity.effectiveDurationMinutes,
            activeCalories: max(calories, 0),
            isHardTraining: CoachActivityClassifier.isSeriousTraining(snapshot),
            isRecoveryActivity: CoachActivityClassification.isRecoveryTier(snapshot)
        )
    }
}
