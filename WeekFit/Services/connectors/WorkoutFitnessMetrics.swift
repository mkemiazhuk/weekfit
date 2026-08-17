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

    /// Moving time only. Fitness zone totals follow workout time, not elapsed clock time.
    static func activeIntervals(from workout: HKWorkout) -> [DateInterval] {
        if let pauseIntervals = intervalsFromPauseEvents(workout), !pauseIntervals.isEmpty {
            return pauseIntervals
        }

        let activities = workout.workoutActivities.compactMap { activity -> DateInterval? in
            let end = activity.endDate ?? activity.startDate.addingTimeInterval(activity.duration)
            guard end.timeIntervalSince(activity.startDate) > 1 else { return nil }
            return DateInterval(start: activity.startDate, end: end)
        }

        if activities.count > 1 {
            return activities
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
