import Foundation

enum AskCoachMetricsBuilder {

    struct ObservationInput: Equatable, Sendable {
        let dayKey: String
        let sleepMinutes: Int?
        let recoveryPercent: Int?
        let hasTrainingFields: Bool
        /// Observation workout count is informational; completed sessions are authoritative.
        let observationWorkoutCount: Int?
    }

    struct VitalInput: Equatable, Sendable {
        let dayKey: String
        let hrvSDNN: Double?
        let restingHeartRate: Double?
    }

    static func buildDays(
        range: AskCoachDateRange,
        observations: [ObservationInput],
        vitals: [VitalInput] = [],
        completedSessions: [AskCoachCompletedSession],
        localCandidates: [AskCoachSessionAggregator.LocalCompletedCandidate],
        calendar: Calendar = .current
    ) -> [AskCoachDayMetrics] {
        let observationsByKey = Dictionary(uniqueKeysWithValues: observations.map { ($0.dayKey, $0) })
        let vitalsByKey = Dictionary(uniqueKeysWithValues: vitals.map { ($0.dayKey, $0) })

        return range.dayStarts.map { dayStart in
            let dayKey = CoachDailyObservation.dayKey(for: dayStart, calendar: calendar)
            let observation = observationsByKey[dayKey]
            let vital = vitalsByKey[dayKey]
            let daySessions = AskCoachSessionAggregator.sessions(
                completedSessions,
                on: dayStart,
                calendar: calendar
            )
            let dayLocals = localCandidates.filter {
                calendar.isDate($0.startDate, inSameDayAs: dayStart)
            }
            let planner = AskCoachSessionAggregator.plannerSlots(from: dayLocals)

            let sleep: Int? = {
                guard let minutes = observation?.sleepMinutes, minutes > 0 else { return nil }
                return minutes
            }()
            let recovery: Int? = {
                guard let percent = observation?.recoveryPercent, percent > 0 else { return nil }
                return percent
            }()
            let hrv: Double? = {
                guard let value = vital?.hrvSDNN, value > 0 else { return nil }
                return value
            }()
            let rhr: Double? = {
                guard let value = vital?.restingHeartRate, value > 0 else { return nil }
                return value
            }()

            let hasTraining = observation?.hasTrainingFields == true || !daySessions.isEmpty

            return AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: dayKey,
                sleepMinutes: sleep,
                recoveryPercent: recovery,
                hrvSDNN: hrv,
                restingHeartRate: rhr,
                completedSessions: daySessions,
                plannedPlannerSessionCount: planner.planned,
                completedPlannerSessionCount: planner.completed,
                hasTrainingSignal: hasTraining
            )
        }
    }

    static func observationInputs(from observations: [CoachDailyObservation]) -> [ObservationInput] {
        observations.map { observation in
            ObservationInput(
                dayKey: observation.dayKey,
                sleepMinutes: observation.hasSleepSignal ? observation.sleepMinutes : nil,
                recoveryPercent: observation.hasRecoverySignal ? observation.recoveryPercent : nil,
                hasTrainingFields: observation.hasPopulatedTrainingFields,
                observationWorkoutCount: observation.workoutCount
            )
        }
    }
}
