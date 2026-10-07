import Foundation
import HealthKit
import WeekFitHealthKit
import WeekFitPlanner

/// Loads Ask Coach day metrics from existing observation + HealthKit + PlannedActivity sources.
@MainActor
enum AskCoachDataService {

    static func load(
        period: AskCoachPeriodLength,
        question: AskCoachQuestion,
        referenceDate: Date = Date(),
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity],
        includeVitals: Bool? = nil,
        calendar: Calendar = .current
    ) async -> AskCoachPeriodBundle {
        let range = AskCoachPeriodCalculator.range(
            length: period,
            endingOn: referenceDate,
            calendar: calendar
        )
        let previous = AskCoachPeriodCalculator.previousRange(
            for: range,
            calendar: calendar
        )

        let granted = healthManager.isHealthAccessGranted
        guard granted else {
            return AskCoachPeriodBundle(
                currentDays: emptyDays(for: range, calendar: calendar),
                previousDays: emptyDays(for: previous, calendar: calendar),
                range: range,
                previousRange: previous,
                healthAccessGranted: false
            )
        }

        let shouldLoadVitals = includeVitals ?? (question == .recovery)
        let fullSpanStart = previous.start
        let fullSpanEnd = range.endInclusive

        async let healthKit = loadHealthKitCandidates(
            from: fullSpanStart,
            through: fullSpanEnd,
            healthManager: healthManager,
            calendar: calendar
        )

        let localCandidates = localCandidates(
            from: plannedActivities,
            from: fullSpanStart,
            through: fullSpanEnd,
            calendar: calendar
        )

        let hkCandidates = await healthKit
        let completedSessions = AskCoachSessionAggregator.aggregate(
            healthKit: hkCandidates,
            local: localCandidates,
            calendar: calendar
        )

        let observations = AskCoachMetricsBuilder.observationInputs(
            from: CoachObservationStore.allObservations()
        )

        var vitals: [AskCoachMetricsBuilder.VitalInput] = []
        if shouldLoadVitals {
            vitals = await loadVitals(
                from: fullSpanStart,
                through: fullSpanEnd,
                calendar: calendar
            )
        }

        let currentDays = AskCoachMetricsBuilder.buildDays(
            range: range,
            observations: observations,
            vitals: vitals,
            completedSessions: completedSessions,
            localCandidates: localCandidates,
            calendar: calendar
        )
        let previousDays = AskCoachMetricsBuilder.buildDays(
            range: previous,
            observations: observations,
            vitals: vitals,
            completedSessions: completedSessions,
            localCandidates: localCandidates,
            calendar: calendar
        )

        return AskCoachPeriodBundle(
            currentDays: currentDays,
            previousDays: previousDays,
            range: range,
            previousRange: previous,
            healthAccessGranted: true
        )
    }

    // MARK: - Private

    private static func emptyDays(
        for range: AskCoachDateRange,
        calendar: Calendar
    ) -> [AskCoachDayMetrics] {
        AskCoachMetricsBuilder.buildDays(
            range: range,
            observations: [],
            vitals: [],
            completedSessions: [],
            localCandidates: [],
            calendar: calendar
        )
    }

    private static func loadHealthKitCandidates(
        from start: Date,
        through end: Date,
        healthManager: HealthManager,
        calendar: Calendar
    ) async -> [AskCoachSessionAggregator.HealthKitCandidate] {
        var result: [AskCoachSessionAggregator.HealthKitCandidate] = []
        var day = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        while day <= endDay {
            if Task.isCancelled { break }
            let workouts = await healthManager.loadWorkoutSamples(for: day)
            for workout in workouts {
                let minutes = max(1, Int((workout.duration / 60.0).rounded()))
                let imported = ActivityReconciler.importedActivity(for: workout)
                let snapshot = CoachPlannedActivitySnapshot(from: imported)
                result.append(
                    AskCoachSessionAggregator.HealthKitCandidate(
                        uuid: workout.uuid,
                        startDate: workout.startDate,
                        durationMinutes: minutes,
                        isRecoveryActivity: CoachActivityClassification.isRecoveryTier(snapshot)
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            await Task.yield()
        }
        return result
    }

    private static func localCandidates(
        from plannedActivities: [PlannedActivity],
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> [AskCoachSessionAggregator.LocalCompletedCandidate] {
        let startDay = calendar.startOfDay(for: start)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) else {
            return []
        }

        return plannedActivities.compactMap { activity in
            guard activity.date >= startDay, activity.date < endExclusive else { return nil }
            let uuid = activity.healthKitWorkoutUUID.flatMap(UUID.init(uuidString:))
            return AskCoachSessionAggregator.LocalCompletedCandidate(
                id: activity.id,
                startDate: activity.date,
                durationMinutes: max(1, activity.effectiveDurationMinutes),
                healthKitWorkoutUUID: uuid,
                isCompleted: activity.isCompleted,
                isSkipped: activity.isSkipped,
                source: activity.source,
                type: activity.type
            )
        }
    }

    /// Best-effort overnight vitals. Missing/zero values stay nil (never treated as zero samples).
    private static func loadVitals(
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) async -> [AskCoachMetricsBuilder.VitalInput] {
        let provider = RecoveryHealthKitProvider()
        var result: [AskCoachMetricsBuilder.VitalInput] = []
        var day = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        while day <= endDay {
            if Task.isCancelled { break }
            let vitals = await provider.loadOvernightVitals(for: day)
            let dayKey = CoachDailyObservation.dayKey(for: day, calendar: calendar)
            let hrv = (vitals.hrv ?? 0) > 0 ? vitals.hrv : nil
            let rhr = (vitals.restingHeartRate ?? 0) > 0 ? vitals.restingHeartRate : nil
            if hrv != nil || rhr != nil {
                result.append(
                    AskCoachMetricsBuilder.VitalInput(
                        dayKey: dayKey,
                        hrvSDNN: hrv,
                        restingHeartRate: rhr
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            await Task.yield()
        }
        return result
    }
}
