import SwiftUI
import HealthKit

final class ActivityIntelligenceSnapshotProvider {

    func buildWeekSnapshots(
        endingAt date: Date,
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity]
    ) async -> [ActivityDaySnapshot] {

        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let startOfSelectedDay = calendar.startOfDay(for: date)

        guard let weekInterval = calendar.dateInterval(
            of: .weekOfYear,
            for: startOfSelectedDay
        ) else {
            return []
        }

        let weekStart = calendar.startOfDay(for: weekInterval.start)

        let dates = (0..<7).compactMap { offset in
            calendar.date(
                byAdding: .day,
                value: offset,
                to: weekStart
            )
        }

        var result: [ActivityDaySnapshot] = []

        for day in dates {
            let snapshot = await buildSnapshot(
                for: day,
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )

            result.append(snapshot)
        }

        return result
    }

    func buildSnapshot(
        for date: Date,
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity]
    ) async -> ActivityDaySnapshot {

        async let hourly = healthManager.loadHourlyActiveCalories(for: date)
        async let workouts = healthManager.loadWorkoutSamples(for: date)
        async let metrics = healthManager.readActivityMetrics(for: date)

        let hourlyCalories = await hourly
        let workoutSamples = await workouts
        let dayMetrics = await metrics

        let activeCalories = Int(dayMetrics.activeCalories.rounded())
        let goal = healthManager.automatedActivityGoal(for: dayMetrics)

        let percent = goal > 0
            ? Int((Double(activeCalories) / goal * 100.0).rounded())
            : 0
        
        let historicalSameWeekdayPoints = await buildHistoricalSameWeekdayPoints(
            for: date,
            healthManager: healthManager
        )

        return ActivityDaySnapshot(
            date: date,
            activeCalories: activeCalories,
            activityGoal: Int(goal.rounded()),
            activityPercent: percent,
            exerciseMinutes: dayMetrics.exerciseMinutes,
            standHours: dayMetrics.standHours,
            steps: dayMetrics.steps,
            distanceKm: dayMetrics.distanceKm,
            vo2Max: dayMetrics.vo2Max,
            recoveryPercent: dayMetrics.recoveryPercent,
            sessions: workoutSamples.map { workoutSnapshot(from: $0) },
            hourlyActivityPoints: hourlyCalories.enumerated().map {
                ActivityTimelinePoint(hour: $0.offset, activeCalories: $0.element)
            },
            historicalSameWeekdayPoints: historicalSameWeekdayPoints
        )
    }

    private func workoutSnapshot(from workout: HKWorkout) -> ActivitySessionSnapshot {
        ActivitySessionSnapshot(
            title: workoutTitle(for: workout.workoutActivityType),
            startDate: workout.startDate,
            durationMinutes: max(1, Int(workout.duration / 60.0)),
            icon: workoutIcon(for: workout.workoutActivityType),
            color: workoutColor(for: workout.workoutActivityType)
        )
    }

    private func workoutTitle(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        case .swimming: return "Swim"
        case .hiking: return "Hiking"
        case .mindAndBody: return "Recovery"
        default: return "Workout"
        }
    }

    private func workoutIcon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .functionalStrengthTraining: return "figure.strengthtraining.functional"
        case .yoga: return "figure.mind.and.body"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .mindAndBody: return "wind"
        default: return "figure.mixed.cardio"
        }
    }

    private func workoutColor(for type: HKWorkoutActivityType) -> Color {
        switch type {
        case .mindAndBody, .yoga:
            return Color(red: 0.30, green: 0.72, blue: 0.95)
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return Color(red: 0.58, green: 0.40, blue: 0.95)
        case .walking:
            return Color(red: 0.45, green: 0.78, blue: 0.45)
        default:
            return Color(red: 0.92, green: 0.68, blue: 0.30)
        }
    }
    
    private func buildHistoricalSameWeekdayPoints(
        for date: Date,
        healthManager: HealthManager
    ) async -> [ActivityHistoricalPoint] {
        let calendar = Calendar.current

        let previousDates = (1...8).compactMap { weekOffset in
            calendar.date(byAdding: .day, value: -7 * weekOffset, to: date)
        }
        .reversed()

        var points: [ActivityHistoricalPoint] = []

        for historicalDate in previousDates {
            let metrics = await healthManager.readActivityMetrics(for: historicalDate)

            let calories = Int(metrics.activeCalories.rounded())

            guard calories > 0 else { continue }

            points.append(
                ActivityHistoricalPoint(
                    date: historicalDate,
                    activeCalories: calories
                )
            )
        }

        return points
    }
}
