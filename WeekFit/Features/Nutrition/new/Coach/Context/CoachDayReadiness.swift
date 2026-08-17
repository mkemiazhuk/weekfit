import Foundation

// MARK: - Day readiness (recovery + yesterday load)

enum CoachRecoveryBand: String, Equatable, Sendable {
    case good
    case moderate
    case low
}

struct CoachDayReadiness: Equatable, Sendable {
    let recoveryPercent: Int
    let sleepHours: Double
    let recoveryBand: CoachRecoveryBand
    let hadHeavyYesterday: Bool
    let sleepIsLow: Bool
    let recoveryDataAvailable: Bool

    init(
        recoveryPercent: Int,
        sleepHours: Double,
        recoveryBand: CoachRecoveryBand,
        hadHeavyYesterday: Bool,
        sleepIsLow: Bool,
        recoveryDataAvailable: Bool? = nil
    ) {
        let dataAvailable = recoveryDataAvailable ?? (recoveryPercent > 0 || sleepHours > 0)
        self.recoveryPercent = recoveryPercent
        self.sleepHours = sleepHours
        self.recoveryBand = dataAvailable ? recoveryBand : .moderate
        self.hadHeavyYesterday = hadHeavyYesterday
        self.sleepIsLow = dataAvailable ? sleepIsLow : false
        self.recoveryDataAvailable = dataAvailable
    }

    static let unknown = CoachDayReadiness(
        recoveryPercent: 70,
        sleepHours: 7.5,
        recoveryBand: .moderate,
        hadHeavyYesterday: false,
        sleepIsLow: false,
        recoveryDataAvailable: true
    )

    var isLowRecovery: Bool {
        recoveryDataAvailable && recoveryBand == .low
    }

    var isGoodRecovery: Bool {
        recoveryDataAvailable && recoveryBand == .good
    }
}

enum CoachDayReadinessResolver {

    private static let goodRecoveryThreshold = 70
    private static let lowRecoveryThreshold = 55
    private static let lowSleepHours = 6.0
    /// Single long session (e.g. multi-hour hike) counts as heavy prior load.
    private static let longSessionMinutes = 150
    /// Aggregate completed minutes across yesterday's plan.
    private static let heavyDayTotalMinutes = 180
    /// Hike-like sessions at this duration are already real load.
    private static let longHikeMinutes = 90

    static func resolve(
        from input: CoachInputSnapshot,
        priorDayLoad: RecoveryPriorDayLoad? = nil
    ) -> CoachDayReadiness {
        let recovery = input.recoveryContext
        let hadHeavyYesterday = resolveHadHeavyYesterday(from: input, priorDayLoad: priorDayLoad)
        let recoveryDataAvailable = recovery.recoveryPercent > 0 || recovery.sleepHours > 0

        guard recoveryDataAvailable else {
            return CoachDayReadiness(
                recoveryPercent: 0,
                sleepHours: 0,
                recoveryBand: .moderate,
                hadHeavyYesterday: hadHeavyYesterday,
                sleepIsLow: false,
                recoveryDataAvailable: false
            )
        }

        return CoachDayReadiness(
            recoveryPercent: recovery.recoveryPercent,
            sleepHours: recovery.sleepHours,
            recoveryBand: recoveryBand(for: recovery.recoveryPercent),
            hadHeavyYesterday: hadHeavyYesterday,
            sleepIsLow: recovery.sleepHours < lowSleepHours,
            recoveryDataAvailable: true
        )
    }

    /// Prior-day heavy when HealthKit exercise/calories spike, planned long sessions
    /// (especially hikes), or the legacy brain calorie/workout-count signal fires.
    static func resolveHadHeavyYesterday(
        from input: CoachInputSnapshot,
        priorDayLoad: RecoveryPriorDayLoad? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        if let priorDayLoad, isHeavyPriorDayLoad(priorDayLoad) {
            return true
        }
        if input.brain.past.hasHighActivityLoad || input.brain.past.completedWorkoutsCount >= 2 {
            return true
        }
        return yesterdayPlanWasHeavy(activities: input.plannedActivities, relativeTo: input.selectedDate, calendar: calendar)
    }

    static func isHeavyPriorDayLoad(_ load: RecoveryPriorDayLoad) -> Bool {
        load.strainLevel == .heavy
            || load.exerciseMinutes >= longSessionMinutes
            || (load.workoutCount >= 1 && load.exerciseMinutes >= longHikeMinutes)
    }

    static func yesterdayPlanWasHeavy(
        activities: [CoachPlannedActivitySnapshot],
        relativeTo date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: dayStart) else {
            return false
        }
        let yesterdayCompleted = activities.filter {
            calendar.isDate($0.date, inSameDayAs: yesterday)
                && !$0.isSkipped
                && ($0.isCompleted || ($0.actualDurationMinutes ?? 0) > 0 || $0.isPartialCompletion)
        }
        guard !yesterdayCompleted.isEmpty else { return false }

        let totalMinutes = yesterdayCompleted.reduce(0) { partial, activity in
            partial + max(activity.actualDurationMinutes ?? 0, activity.durationMinutes, activity.effectiveDurationMinutes)
        }
        if totalMinutes >= heavyDayTotalMinutes { return true }

        if yesterdayCompleted.contains(where: { activity in
            let minutes = max(
                activity.actualDurationMinutes ?? 0,
                activity.durationMinutes,
                activity.effectiveDurationMinutes
            )
            if minutes >= longSessionMinutes { return true }
            if CoachActivityClassification.isHikeLike(activity), minutes >= longHikeMinutes {
                return true
            }
            return CoachActivityClassifier.isSeriousTraining(activity) && minutes >= 75
        }) {
            return true
        }

        let elevatedCount = yesterdayCompleted.filter(CoachActivityClassifier.isElevatedTrainingLoad).count
        return elevatedCount >= 2
    }

    private static func recoveryBand(for percent: Int) -> CoachRecoveryBand {
        if percent >= goodRecoveryThreshold { return .good }
        if percent >= lowRecoveryThreshold { return .moderate }
        return .low
    }
}

enum CoachDayReadinessRouter {

    // MARK: - Idle day stories

    static func idleScenario(for context: CoachContext) -> CoachScenarioKey {
        if shouldUseRecoveryAfterHeavyYesterday(context) {
            return .recoveryAfterHeavyYesterday
        }
        if shouldUseProtectTomorrowFresh(context) {
            return .protectTomorrowFresh
        }
        if context.timeOfDay == .morning,
           context.dayLoadBand == .fresh,
           context.completedSeriousActivities == .none {
            return .morningReadiness
        }
        return .stableDay
    }

    static func shouldUseProtectTomorrowFresh(_ context: CoachContext) -> Bool {
        guard context.sessionPhase == .idle else { return false }
        guard context.activityFamily == .none else { return false }
        guard context.dayReadiness.isGoodRecovery else { return false }
        guard context.dayLoadBand != .heavy && context.dayLoadBand != .extreme else { return false }
        guard context.completedSeriousActivities == .none else { return false }
        guard context.tomorrowDemand == .moderate || context.tomorrowDemand == .hard else { return false }
        switch context.timeOfDay {
        case .morning, .midday:
            return true
        default:
            return false
        }
    }

    static func shouldUseRecoveryAfterHeavyYesterday(_ context: CoachContext) -> Bool {
        guard context.sessionPhase == .idle else { return false }
        guard context.activityFamily == .none else { return false }
        guard context.dayReadiness.hadHeavyYesterday else { return false }
        guard context.dayLoadBand == .fresh else { return false }
        if !context.dayReadiness.recoveryDataAvailable {
            return true
        }
        return context.dayReadiness.isLowRecovery || context.dayReadiness.sleepIsLow
    }

    // MARK: - Pre-session protective prep

    static func shouldUseLowRecoveryPrep(_ context: CoachContext) -> Bool {
        guard context.sessionPhase == .pre else { return false }
        guard context.activityState == .upcoming else { return false }
        guard context.dayReadiness.recoveryDataAvailable else { return false }
        switch context.activityFamily {
        case .endurance, .strength, .racket:
            break
        default:
            return false
        }
        let readiness = context.dayReadiness
        return readiness.isLowRecovery
            || readiness.sleepIsLow
            || (readiness.recoveryBand == .moderate && readiness.sleepHours < 5.5)
    }

    static func lowRecoveryPreSessionScenario(for context: CoachContext) -> CoachScenarioKey? {
        shouldUseLowRecoveryPrep(context) ? .lowRecoveryPrep : nil
    }
}
