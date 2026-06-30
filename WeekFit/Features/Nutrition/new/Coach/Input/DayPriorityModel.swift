import Foundation

enum CoachDayGoal: String {
    case performance
    case recovery
    case maintenance
    case overload
}

enum CoachDayStressLevel: String {
    case low
    case moderate
    case high
    case overload
}

enum CoachTomorrowDemand: String, Equatable, Sendable {
    case none
    case easy
    case moderate
    case hard
}

enum CoachProtectionTarget: String {
    case primarySession
    case tomorrow
    case recovery
    case consistency
}

struct DayPriorityModel {
    let primarySession: PlannedActivity?
    let secondarySession: PlannedActivity?
    let supportingSessions: [PlannedActivity]
    let dayGoal: CoachDayGoal
    let dayStressLevel: CoachDayStressLevel
    let tomorrowDemand: CoachTomorrowDemand
    let protectionTarget: CoachProtectionTarget

    static func build(from input: CoachInputSnapshot) -> DayPriorityModel {
        let calendar = Calendar.current
        let todayActivities = input.plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: input.selectedDate) }
            .filter { !$0.isSkipped }
            .sorted { $0.date < $1.date }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.selectedDate)
        let tomorrowActivities = input.plannedActivities
            .filter { activity in
                guard let tomorrow else { return false }
                return calendar.isDate(activity.date, inSameDayAs: tomorrow) && !activity.isSkipped
            }

        let ranked = todayActivities
            .map { activity in
                RankedDayActivity(
                    activity: activity,
                    score: sessionScore(activity),
                    isSupporting: isSupportingActivity(activity)
                )
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.activity.date < rhs.activity.date
                }
                return lhs.score > rhs.score
            }

        let primary = ranked.first(where: { !$0.isSupporting })?.activity
        let secondary = ranked.dropFirst().first(where: { !$0.activity.isSameSession(as: primary) && !$0.isSupporting })?.activity
        let supporting = ranked
            .filter { ranked in
                ranked.isSupporting ||
                    (ranked.activity.id != primary?.id && ranked.activity.id != secondary?.id && ranked.score < 35)
            }
            .map(\.activity)

        let futurePlanStress = todayActivities
            .filter { !$0.isCompleted && !$0.isPartialCompletion && $0.date >= input.now }
            .reduce(0) { $0 + sessionScore($1) }
        let todayStress = actualLoadStressScore(input.actualLoad) + futurePlanStress
        let tomorrowDemand = CoachTomorrowDemandResolver.resolve(activities: tomorrowActivities).level
        let stressLevel = dayStressLevel(for: todayStress)
        let goal = dayGoal(
            stressLevel: stressLevel,
            primary: primary,
            todayActivities: todayActivities,
            recovery: input.recoveryContext,
            tomorrowDemand: tomorrowDemand
        )

        return DayPriorityModel(
            primarySession: primary,
            secondarySession: secondary,
            supportingSessions: supporting,
            dayGoal: goal,
            dayStressLevel: stressLevel,
            tomorrowDemand: tomorrowDemand,
            protectionTarget: protectionTarget(
                goal: goal,
                primary: primary,
                tomorrowDemand: tomorrowDemand,
                recovery: input.recoveryContext
            )
        )
    }

    private struct RankedDayActivity {
        let activity: PlannedActivity
        let score: Int
        let isSupporting: Bool
    }

    private static func sessionScore(_ activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)
        let duration = activity.effectiveDurationMinutes
        let calories = CoachActivityContextResolver.activityCalories(activity)

        let base: Int
        switch kind {
        case .endurance:
            base = 55
        case .workout:
            base = 48
        case .heat:
            base = 42
        case .recovery:
            base = 12
        case .meal, .other:
            base = 0
        }

        let loadBonus: Int
        switch load {
        case .extreme:
            loadBonus = 35
        case .high:
            loadBonus = 25
        case .moderate:
            loadBonus = 12
        case .low:
            loadBonus = 0
        }

        let durationBonus = min(duration / 15, 8)
        let calorieBonus = min(calories / 120, 8)
        let completionBonus = activity.isCompleted ? 2 : 0

        return base + loadBonus + durationBonus + calorieBonus + completionBonus
    }

    private static func isSupportingActivity(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)
        if kind == .recovery || kind == .heat { return true }
        if kind == .workout || kind == .endurance { return false }
        return load == .low
    }

    private static func dayStressLevel(for stress: Int) -> CoachDayStressLevel {
        if stress >= 140 { return .overload }
        if stress >= 95 { return .high }
        if stress >= 45 { return .moderate }
        return .low
    }

    private static func actualLoadStressScore(_ actualLoad: CoachActualLoadSnapshot) -> Int {
        let calorieScore: Int
        switch actualLoad.activeCalories {
        case 900...:
            calorieScore = 110
        case 750..<900:
            calorieScore = 95
        case 550..<750:
            calorieScore = 70
        case 300..<550:
            calorieScore = 40
        default:
            calorieScore = 0
        }

        let progressCanRepresentLoad = actualLoad.activeCalories >= 300 ||
            (actualLoad.exerciseMinutes ?? 0) >= 30
        let progressScore: Int
        if progressCanRepresentLoad {
            switch actualLoad.activityProgress ?? 0 {
            case 1.9...:
                progressScore = 120
            case 1.5..<1.9:
                progressScore = 95
            case 1.0..<1.5:
                progressScore = 60
            default:
                progressScore = 0
            }
        } else {
            progressScore = 0
        }

        let exerciseScore: Int
        switch actualLoad.exerciseMinutes ?? 0 {
        case 90...:
            exerciseScore = 95
        case 60..<90:
            exerciseScore = 70
        case 30..<60:
            exerciseScore = 35
        default:
            exerciseScore = 0
        }

        return max(calorieScore, progressScore, exerciseScore)
    }

    private static func dayGoal(
        stressLevel: CoachDayStressLevel,
        primary: PlannedActivity?,
        todayActivities: [PlannedActivity],
        recovery: CoachRecoveryContext,
        tomorrowDemand: CoachTomorrowDemand
    ) -> CoachDayGoal {
        if stressLevel == .overload || (stressLevel == .high && tomorrowDemand == .hard) {
            return .overload
        }

        let recoveryDataAvailable = recovery.recoveryPercent > 0 || recovery.sleepHours > 0

        if (recoveryDataAvailable && recovery.recoveryPercent < 55) || todayActivities.allSatisfy(isSupportingActivity) {
            return .recovery
        }

        if primary != nil {
            return .performance
        }

        return .maintenance
    }

    private static func protectionTarget(
        goal: CoachDayGoal,
        primary: PlannedActivity?,
        tomorrowDemand: CoachTomorrowDemand,
        recovery: CoachRecoveryContext
    ) -> CoachProtectionTarget {
        let recoveryDataAvailable = recovery.recoveryPercent > 0 || recovery.sleepHours > 0

        if tomorrowDemand == .hard && (goal == .overload || (recoveryDataAvailable && recovery.recoveryPercent < 70)) {
            return .tomorrow
        }

        if recoveryDataAvailable && recovery.recoveryPercent < 55 {
            return .recovery
        }

        if primary != nil {
            return .primarySession
        }

        return .consistency
    }
}

private extension PlannedActivity {
    func isSameSession(as other: PlannedActivity?) -> Bool {
        guard let other else { return false }
        return id == other.id
    }
}
