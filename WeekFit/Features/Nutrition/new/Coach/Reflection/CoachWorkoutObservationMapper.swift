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
        let endComponents = Calendar.current.dateComponents([.hour, .minute], from: workout.endDate)
        let endMinutes = ((endComponents.hour ?? 0) * 60) + (endComponents.minute ?? 0)

        return CoachWorkoutObservationSample(
            typeToken: activity.title.lowercased(),
            durationMinutes: activity.effectiveDurationMinutes,
            activeCalories: max(calories, 0),
            isHardTraining: CoachActivityClassifier.isSeriousTraining(snapshot),
            isRecoveryActivity: CoachActivityClassification.isRecoveryTier(snapshot),
            endMinutesFromMidnight: endMinutes
        )
    }
}
