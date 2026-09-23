import Foundation
import HealthKit

/// Values Fitness shows for an `HKWorkout` — not recomputed from a date window.
enum WorkoutFitnessMetrics {
    static func heartRateAverageAndMax(
        from workout: HKWorkout
    ) -> (average: Double?, maximum: Double?) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil)
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let statistics = workout.statistics(for: type)
        let average = statistics?.averageQuantity()?.doubleValue(for: unit)
        let maximum = statistics?.maximumQuantity()?.doubleValue(for: unit)

        return (
            average: (average ?? 0) > 0 ? average : nil,
            maximum: (maximum ?? 0) > 0 ? maximum : nil
        )
    }

    /// Fitness "Duration" (moving / workout time) vs wall-clock elapsed including pauses.
    static func durations(from workout: HKWorkout) -> (workout: TimeInterval, elapsed: TimeInterval) {
        let elapsed = max(0, workout.endDate.timeIntervalSince(workout.startDate))
        let fitnessDuration = max(0, workout.duration)

        // Prefer Apple's workout duration. If pause/resume events imply a shorter
        // active total while `duration` still equals elapsed (some Watch exports),
        // use the active-interval sum so UI can show Workout + Elapsed separately.
        let activeSum = activeIntervals(from: workout).reduce(0.0) { $0 + $1.duration }
        if fitnessDuration > 0, abs(fitnessDuration - elapsed) > 60 {
            return (fitnessDuration, max(elapsed, fitnessDuration))
        }
        if activeSum > 0, activeSum + 60 < elapsed {
            return (activeSum, elapsed)
        }
        let workoutSeconds = fitnessDuration > 0 ? fitnessDuration : elapsed
        return (workoutSeconds, max(elapsed, workoutSeconds))
    }

    /// Quantity identifier Fitness uses for distance on this activity type.
    static func distanceIdentifier(
        for activityType: HKWorkoutActivityType
    ) -> HKQuantityTypeIdentifier {
        switch activityType {
        case .cycling:
            return .distanceCycling
        case .swimming:
            return .distanceSwimming
        case .wheelchairRunPace, .wheelchairWalkPace:
            return .distanceWheelchair
        default:
            return .distanceWalkingRunning
        }
    }

    /// Moving time only. Fitness zone totals follow workout time, not elapsed clock time.
    static func activeIntervals(from workout: HKWorkout) -> [DateInterval] {
        if let pauseIntervals = intervalsFromPauseEvents(workout), !pauseIntervals.isEmpty {
            return WorkoutHeartRateAnalytics.coalesce(pauseIntervals)
        }

        let activities = workout.workoutActivities.compactMap { activity -> DateInterval? in
            let end = activity.endDate ?? activity.startDate.addingTimeInterval(activity.duration)
            guard end.timeIntervalSince(activity.startDate) > 1 else { return nil }
            return DateInterval(start: activity.startDate, end: end)
        }

        // Multiple HKWorkoutActivity segments often overlap the primary workout window.
        // Always coalesce before zone math so time-in-zone cannot exceed moving time.
        if activities.count > 1 {
            return WorkoutHeartRateAnalytics.coalesce(activities)
        }

        if let single = activities.first, abs(single.duration - workout.duration) < 30 {
            return [single]
        }

        return [DateInterval(start: workout.startDate, end: workout.endDate)]
    }

    private static func intervalsFromPauseEvents(_ workout: HKWorkout) -> [DateInterval]? {
        let events = (workout.workoutEvents ?? [])
            .filter { $0.type == .pause || $0.type == .resume }
            .sorted { $0.dateInterval.start < $1.dateInterval.start }

        guard !events.isEmpty else { return nil }

        var intervals: [DateInterval] = []
        var segmentStart = workout.startDate

        for event in events {
            switch event.type {
            case .pause:
                let pauseAt = event.dateInterval.start
                if pauseAt > segmentStart {
                    intervals.append(DateInterval(start: segmentStart, end: pauseAt))
                }
            case .resume:
                segmentStart = event.dateInterval.start
            default:
                continue
            }
        }

        if workout.endDate > segmentStart {
            intervals.append(DateInterval(start: segmentStart, end: workout.endDate))
        }

        return intervals.isEmpty ? nil : intervals
    }
}
