import Foundation

enum CoachDailyObservationTrainingBuilder {

    static func build(
        metrics: ActivityMetricsSnapshot,
        workouts: [CoachWorkoutObservationSample],
        trainingDataAvailable: Bool
    ) -> CoachDailyObservationTrainingSnapshot? {
        guard trainingDataAvailable else { return nil }

        let exerciseMinutes = max(metrics.exerciseMinutes, workouts.map(\.durationMinutes).max() ?? 0)
        let workoutCalories = workouts.map(\.activeCalories).reduce(0, +)
        let activeCalories = Int(max(metrics.activeCalories, Double(workoutCalories)).rounded())
        let workoutCount = workouts.count
        let workoutTypes = orderedUniqueTypes(from: workouts)
        let hardWorkoutCount = workouts.filter(\.isHardTraining).count
        let hadHardTraining = hardWorkoutCount > 0
        let hadRecoveryActivity = workouts.contains(where: \.isRecoveryActivity)

        let intensityBand = resolveIntensityBand(
            exerciseMinutes: exerciseMinutes,
            activeCalories: activeCalories,
            workoutCount: workoutCount,
            hardWorkoutCount: hardWorkoutCount
        )

        return CoachDailyObservationTrainingSnapshot(
            exerciseMinutes: exerciseMinutes,
            activeCalories: activeCalories,
            workoutCount: workoutCount,
            workoutTypes: workoutTypes,
            hardWorkoutCount: hardWorkoutCount,
            workoutIntensityBand: intensityBand,
            hadHardTraining: hadHardTraining,
            hadRecoveryActivity: hadRecoveryActivity,
            hadRestDay: intensityBand == .rest,
            trainingLoadScore: trainingLoadScore(for: intensityBand)
        )
    }

    private static func resolveIntensityBand(
        exerciseMinutes: Int,
        activeCalories: Int,
        workoutCount: Int,
        hardWorkoutCount: Int
    ) -> CoachWorkoutIntensityBand {
        if hardWorkoutCount > 0 {
            return .hard
        }

        if exerciseMinutes >= 90 || activeCalories >= 650 {
            return .hard
        }

        if workoutCount > 0 || exerciseMinutes >= 45 || activeCalories >= 350 {
            return .moderate
        }

        if exerciseMinutes >= 15 || activeCalories >= 120 {
            return .light
        }

        return .rest
    }

    private static func trainingLoadScore(for band: CoachWorkoutIntensityBand) -> Int {
        switch band {
        case .rest: return 10
        case .light: return 35
        case .moderate: return 60
        case .hard: return 90
        }
    }

    private static func orderedUniqueTypes(from workouts: [CoachWorkoutObservationSample]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for workout in workouts where seen.insert(workout.typeToken).inserted {
            ordered.append(workout.typeToken)
        }
        return ordered
    }
}
