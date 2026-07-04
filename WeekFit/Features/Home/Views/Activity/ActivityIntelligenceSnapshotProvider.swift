import SwiftUI
import HealthKit
import WeekFitPlanner

final class ActivityIntelligenceSnapshotProvider {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

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
        async let sleep = healthManager.loadRecoverySleepSnapshot(for: date)

        let hourlyCalories = await hourly
        let workoutSamples = await workouts
        let dayMetrics = await metrics
        let sleepSnapshot = await sleep

        let activeCalories = Int(dayMetrics.activeCalories.rounded())
        let goal = healthManager.automatedActivityGoal(for: dayMetrics)

        let percent = goal > 0
            ? Int((Double(activeCalories) / goal * 100.0).rounded())
            : 0
        
        let historicalSameWeekdayPoints = await buildHistoricalSameWeekdayPoints(
            for: date,
            healthManager: healthManager
        )

        let sleepInterval: DateInterval? = {
            guard let bedStart = sleepSnapshot.bedStart,
                  let wakeTime = sleepSnapshot.wakeTime else {
                return nil
            }
            return DateInterval(start: bedStart, end: wakeTime)
        }()

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
            sessions: workoutSamples.map { makeSnapshot(from: $0) },
            hourlyActivityPoints: hourlyCalories.enumerated().map {
                ActivityTimelinePoint(hour: $0.offset, activeCalories: $0.element)
            },
            historicalSameWeekdayPoints: historicalSameWeekdayPoints,
            sleepInterval: sleepInterval
        )
    }

    func makeSnapshot(from workout: HKWorkout) -> ActivitySessionSnapshot {
        let title = workoutTitle(for: workout.workoutActivityType)
        let durationMinutes = max(1, Int(workout.duration / 60.0))
        let icon = ActivityReconciler.icon(for: workout.workoutActivityType)
        let color = workoutColor(for: workout.workoutActivityType)
        let activeCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let distanceKm = workout.totalDistance.map { $0.doubleValue(for: .meter()) / 1000.0 }

        return ActivitySessionSnapshot(
            workoutID: workout.uuid,
            title: title,
            startDate: workout.startDate,
            durationMinutes: durationMinutes,
            icon: icon,
            color: color,
            detail: ActivitySessionDetailSnapshot(
                title: title,
                activityType: workout.workoutActivityType,
                startDate: workout.startDate,
                endDate: workout.endDate,
                durationMinutes: durationMinutes,
                workoutDurationSeconds: workout.duration,
                elapsedDurationSeconds: workout.endDate.timeIntervalSince(workout.startDate),
                source: workout.sourceRevision.source.name,
                icon: icon,
                color: color,
                activeCalories: activeCalories,
                distanceKm: distanceKm,
                averageHeartRate: nil,
                maxHeartRate: nil,
                heartRateSamples: [],
                routePoints: [],
                elevationGain: nil,
                steps: nil,
                cadence: nil
            )
        )
    }

    func makePlannedActivitySnapshot(_ activity: PlannedActivity) -> ActivitySessionSnapshot {
        let durationMinutes = max(1, activity.effectiveDurationMinutes)
        let endDate = Calendar.current.date(
            byAdding: .minute,
            value: durationMinutes,
            to: activity.date
        ) ?? activity.date
        let activityType = inferredWorkoutType(for: activity)
        let icon = activity.icon.isEmpty ? "figure.mixed.cardio" : activity.icon
        let source = activity.isWatchSynced ? "Apple Watch" : activity.source

        return ActivitySessionSnapshot(
            workoutID: activity.healthKitWorkoutUUID.flatMap(UUID.init(uuidString:)),
            title: activity.title,
            startDate: activity.date,
            durationMinutes: durationMinutes,
            icon: icon,
            color: activity.color,
            detail: ActivitySessionDetailSnapshot(
                title: activity.title,
                activityType: activityType,
                startDate: activity.date,
                endDate: endDate,
                durationMinutes: durationMinutes,
                workoutDurationSeconds: TimeInterval(durationMinutes * 60),
                elapsedDurationSeconds: endDate.timeIntervalSince(activity.date),
                source: source,
                icon: icon,
                color: activity.color,
                activeCalories: nil,
                distanceKm: nil,
                averageHeartRate: nil,
                maxHeartRate: nil,
                heartRateSamples: [],
                routePoints: [],
                elevationGain: nil,
                steps: nil,
                cadence: nil
            )
        )
    }

    private func inferredWorkoutType(for activity: PlannedActivity) -> HKWorkoutActivityType {
        let title = activity.title.lowercased()

        if title.contains("run") { return .running }
        if title.contains("walk") { return .walking }
        if title.contains("cycl") || title.contains("bike") || title.contains("ride") { return .cycling }
        if title.contains("hike") { return .hiking }
        if title.contains("swim") { return .swimming }
        if title.contains("yoga") { return .yoga }
        if title.contains("tennis") { return .tennis }
        if title.contains("squash") { return .squash }
        if title.contains("strength") || title.contains("core") || title.contains("body") {
            return .traditionalStrengthTraining
        }
        if title.contains("stretch") || title.contains("breath") { return .mindAndBody }
        if title.contains("sauna") { return .other }

        switch activity.type.lowercased() {
        case "workout":
            return .other
        case "recovery":
            return .mindAndBody
        default:
            return .other
        }
    }

    private func workoutTitle(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return WeekFitLocalizedString("activity.workoutType.run")
        case .walking: return WeekFitLocalizedString("activity.workoutType.walk")
        case .cycling: return WeekFitLocalizedString("activity.workoutType.cycling")
        case .traditionalStrengthTraining, .functionalStrengthTraining: return WeekFitLocalizedString("activity.workoutType.strength")
        case .yoga: return WeekFitLocalizedString("activity.workoutType.yoga")
        case .swimming: return WeekFitLocalizedString("activity.workoutType.swim")
        case .hiking: return WeekFitLocalizedString("activity.workoutType.hiking")
        case .mindAndBody: return WeekFitLocalizedString("activity.workoutType.recovery")
        default: return WeekFitLocalizedString("activity.workoutType.workout")
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
