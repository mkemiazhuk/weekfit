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

enum CoachTomorrowDemand: String {
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
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let duration = activity.effectiveDurationMinutes
        let calories = CoachActivityContextResolverV3.activityCalories(activity)

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
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
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

        if recovery.recoveryPercent < 55 || todayActivities.allSatisfy(isSupportingActivity) {
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
        if tomorrowDemand == .hard && (goal == .overload || recovery.recoveryPercent < 70) {
            return .tomorrow
        }

        if recovery.recoveryPercent < 55 {
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

enum CoachSystemDayType: String, Hashable {
    case recovery
    case maintenance
    case training
    case performance
    case overload
    case deload
}

enum CoachPrimaryDriver: String, Hashable {
    case accumulatedFatigue
    case poorSleep
    case lowRecovery
    case overloadRisk
    case tomorrowDemand
    case illness
    case injury
    case excessiveLoad
    case unsafeHeatStress
    case none

    var label: String {
        switch self {
        case .accumulatedFatigue:
            return "Accumulated fatigue"
        case .poorSleep:
            return "Poor sleep"
        case .lowRecovery:
            return "Low recovery"
        case .overloadRisk:
            return "Overload risk"
        case .tomorrowDemand:
            return "Tomorrow demand"
        case .illness:
            return "Illness"
        case .injury:
            return "Injury"
        case .excessiveLoad:
            return "Excessive remaining load"
        case .unsafeHeatStress:
            return "Unsafe heat stress"
        case .none:
            return "No plan-changing driver"
        }
    }
}

enum CoachContributor: String, Hashable {
    case underfueled
    case hydrationBehind
    case proteinBehind
    case poorMealTiming
    case heatStress
    case recentSauna
    case highActiveCalories
    case tomorrowDemand

    var label: String {
        switch self {
        case .underfueled:
            return "fueling support"
        case .hydrationBehind:
            return "hydration behind"
        case .proteinBehind:
            return "protein behind"
        case .poorMealTiming:
            return "meal timing"
        case .heatStress:
            return "heat stress"
        case .recentSauna:
            return "recent sauna"
        case .highActiveCalories:
            return "high active calories"
        case .tomorrowDemand:
            return "tomorrow demand"
        }
    }
}

enum CoachContributorLevel: String, Hashable {
    case aheadOfTrajectory
    case onTrajectory
    case slightlyBehind
    case meaningfullyBehind
    case actionRequired

    var isActiveContributor: Bool {
        switch self {
        case .meaningfullyBehind, .actionRequired:
            return true
        case .aheadOfTrajectory, .onTrajectory, .slightlyBehind:
            return false
        }
    }
}

struct CoachRecoveryContributorDebug: Hashable {
    let activeContributors: [CoachContributor]
    let resolvedContributors: [CoachContributor]
    let calorieRatio: Double
    let hydrationRatio: Double
    let proteinRatio: Double
    let expectedCalorieRatio: Double
    let expectedHydrationRatio: Double
    let expectedProteinRatio: Double
    let calorieLevel: CoachContributorLevel
    let hydrationLevel: CoachContributorLevel
    let proteinLevel: CoachContributorLevel

    var debugLines: [String] {
        [
            "RecoveryContributorDebug.activeContributors=\(Self.format(activeContributors))",
            "RecoveryContributorDebug.resolvedContributors=\(Self.format(resolvedContributors))",
            "RecoveryContributorDebug.calorieRatio=\(Self.formatRatio(calorieRatio))",
            "RecoveryContributorDebug.hydrationRatio=\(Self.formatRatio(hydrationRatio))",
            "RecoveryContributorDebug.proteinRatio=\(Self.formatRatio(proteinRatio))",
            "RecoveryContributorDebug.expectedCalorieRatio=\(Self.formatRatio(expectedCalorieRatio))",
            "RecoveryContributorDebug.expectedHydrationRatio=\(Self.formatRatio(expectedHydrationRatio))",
            "RecoveryContributorDebug.expectedProteinRatio=\(Self.formatRatio(expectedProteinRatio))",
            "RecoveryContributorDebug.calorieLevel=\(calorieLevel.rawValue)",
            "RecoveryContributorDebug.hydrationLevel=\(hydrationLevel.rawValue)",
            "RecoveryContributorDebug.proteinLevel=\(proteinLevel.rawValue)"
        ]
    }

    static func resolve(context: CoachDecisionContext) -> CoachRecoveryContributorDebug {
        let nutrition = context.nutritionContext
        let calorieRatio = Self.ratio(
            current: nutrition?.caloriesCurrent ?? context.brain.metrics.calories,
            goal: context.brain.baseDayGoals.calories
        )
        let hydrationRatio = Self.ratio(
            current: nutrition?.waterCurrent ?? context.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? context.brain.fullDayGoals.waterLiters
        )
        let proteinRatio = Self.ratio(
            current: nutrition?.proteinCurrent ?? context.brain.metrics.protein,
            goal: context.brain.baseDayGoals.protein
        )
        let hour = context.brain.currentHour
        let expectedCalorieRatio = Self.expectedCalorieProgress(hour: hour)
        let expectedHydrationRatio = Self.expectedHydrationProgress(hour: hour)
        let expectedProteinRatio = Self.expectedProteinProgress(hour: hour)

        let calorieLevel = Self.nutritionLevel(
            actual: calorieRatio,
            expected: expectedCalorieRatio,
            hour: hour,
            domain: .calories,
            context: context
        )
        let hydrationLevel = Self.hydrationLevel(
            actual: hydrationRatio,
            expected: expectedHydrationRatio,
            hour: hour,
            context: context
        )
        let proteinLevel = Self.nutritionLevel(
            actual: proteinRatio,
            expected: expectedProteinRatio,
            hour: hour,
            domain: .protein,
            context: context
        )

        var active: [CoachContributor] = []
        var resolved: [CoachContributor] = []

        Self.classify(.underfueled, isActive: calorieLevel.isActiveContributor, active: &active, resolved: &resolved)
        Self.classify(.hydrationBehind, isActive: hydrationLevel.isActiveContributor, active: &active, resolved: &resolved)
        Self.classify(.proteinBehind, isActive: proteinLevel.isActiveContributor, active: &active, resolved: &resolved)

        return CoachRecoveryContributorDebug(
            activeContributors: active,
            resolvedContributors: resolved,
            calorieRatio: calorieRatio,
            hydrationRatio: hydrationRatio,
            proteinRatio: proteinRatio,
            expectedCalorieRatio: expectedCalorieRatio,
            expectedHydrationRatio: expectedHydrationRatio,
            expectedProteinRatio: expectedProteinRatio,
            calorieLevel: calorieLevel,
            hydrationLevel: hydrationLevel,
            proteinLevel: proteinLevel
        )
    }

    private static func classify(
        _ contributor: CoachContributor,
        isActive: Bool,
        active: inout [CoachContributor],
        resolved: inout [CoachContributor]
    ) {
        if isActive {
            active.append(contributor)
        } else {
            resolved.append(contributor)
        }
    }

    private static func format(_ contributors: [CoachContributor]) -> String {
        "[\(contributors.map(\.rawValue).joined(separator: ","))]"
    }

    private static func formatRatio(_ ratio: Double) -> String {
        String(format: "%.2f", ratio)
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return max(0, current / goal)
    }

    private enum TrajectoryDomain {
        case calories
        case hydration
        case protein
    }

    private static func nutritionLevel(
        actual: Double,
        expected: Double,
        hour: Int,
        domain: TrajectoryDomain,
        context: CoachDecisionContext
    ) -> CoachContributorLevel {
        let mealsCount = context.nutritionContext?.mealsCount ?? 0
        let hasSeveralMeals = mealsCount >= 3
        let hardTrainingContext = context.dayContext.hasMeaningfulLoadCompleted ||
            context.actualLoad.activeCalories >= 750

        if actual >= 0.95, actual >= expected + 0.10 {
            return .aheadOfTrajectory
        }

        if actual >= 0.80 {
            return .onTrajectory
        }

        let morning = hour < 12
        let earlyAfternoon = hour < 16

        if morning {
            if actual < 0.10 {
                return hardTrainingContext ? .meaningfullyBehind : .slightlyBehind
            }
            return .onTrajectory
        }

        if actual >= 0.60 {
            if hasSeveralMeals, !hardTrainingContext {
                return .onTrajectory
            }
            return .slightlyBehind
        }

        if actual >= 0.40 {
            if domain == .calories, earlyAfternoon {
                return .slightlyBehind
            }
            if domain == .protein, earlyAfternoon, !hardTrainingContext {
                return .slightlyBehind
            }
            return .meaningfullyBehind
        }

        if actual < 0.40 {
            if hour >= 22, !hardTrainingContext {
                return .meaningfullyBehind
            }
            return .actionRequired
        }

        return .onTrajectory
    }

    private static func hydrationLevel(
        actual: Double,
        expected: Double,
        hour: Int,
        context: CoachDecisionContext
    ) -> CoachContributorLevel {
        if actual >= 0.90 {
            return actual >= expected * 1.08 ? .aheadOfTrajectory : .onTrajectory
        }

        if hour >= 20 {
            switch actual {
            case 0.75..<0.90:
                return .slightlyBehind
            case 0.50..<0.75:
                return .meaningfullyBehind
            case ..<0.50:
                return .actionRequired
            default:
                break
            }
        }

        guard expected > 0 else { return .onTrajectory }
        let relativeToExpected = actual / expected
        switch relativeToExpected {
        case 1.10...:
            return .aheadOfTrajectory
        case 0.90..<1.10:
            return .onTrajectory
        case 0.75..<0.90:
            return .slightlyBehind
        case 0.50..<0.75:
            return .meaningfullyBehind
        default:
            let morning = hour < 12
            let hasHydrationRisk = context.dayContext.hasMoreLoadAhead ||
                context.dayContext.hasMeaningfulLoadCompleted ||
                context.dayContext.allActivities.contains {
                    let kind = CoachActivityContextResolverV3.kind(for: $0)
                    return (kind == .heat || kind == .endurance) && !$0.isCompleted
                }
            if morning, !hasHydrationRisk {
                return .meaningfullyBehind
            }
            return .actionRequired
        }
    }

    private static func expectedHydrationProgress(hour: Int) -> Double {
        interpolate(hour: hour, points: [
            (6, 0.08),
            (8, 0.18),
            (12, 0.45),
            (16, 0.68),
            (20, 0.90),
            (22, 1.00)
        ])
    }

    private static func expectedCalorieProgress(hour: Int) -> Double {
        interpolate(hour: hour, points: [
            (6, 0.05),
            (8, 0.12),
            (12, 0.38),
            (16, 0.62),
            (20, 0.88),
            (22, 1.00)
        ])
    }

    private static func expectedProteinProgress(hour: Int) -> Double {
        interpolate(hour: hour, points: [
            (6, 0.04),
            (8, 0.10),
            (12, 0.28),
            (16, 0.52),
            (20, 0.84),
            (22, 0.96)
        ])
    }

    private static func interpolate(hour: Int, points: [(Int, Double)]) -> Double {
        guard let first = points.first, let last = points.last else { return 1 }
        if hour <= first.0 { return first.1 }
        if hour >= last.0 { return last.1 }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let next = points[index]
            guard hour <= next.0 else { continue }
            let span = Double(next.0 - previous.0)
            let progress = span > 0 ? Double(hour - previous.0) / span : 1
            return previous.1 + ((next.1 - previous.1) * progress)
        }

        return last.1
    }
}

enum CoachPlanStatus: String, Hashable {
    case valid
    case adjust
    case downgrade
    case replace
    case cancel
    case complete

    var requiresPlanChange: Bool {
        switch self {
        case .adjust, .downgrade, .replace, .cancel:
            return true
        case .valid, .complete:
            return false
        }
    }
}

enum CoachRecommendationIntent: String, Hashable {
    case continuePlan
    case protectPrimarySession
    case modifyRemainingPlan
    case recoverNow
    case prepareForSession
    case executeActiveSession
    case protectTomorrow
}

enum RemainingActivityRiskLevel: String, Hashable {
    case low
    case medium
    case high
    case critical
}

enum RemainingActivityRecommendedAction: String, Hashable {
    case keep
    case shorten
    case makeEasy
    case replace
    case skip
    case moveToTomorrow
}

enum RemainingActivityRole: String, Hashable {
    case primary
    case secondary
    case support
    case extra
}

struct RemainingActivityRiskAssessment: Hashable {
    let activity: PlannedActivity
    let activityTitle: String
    let activityType: String
    let category: String
    let plannedDuration: Int
    let plannedStartTime: Date
    let minutesUntilStart: Int
    let expectedIntensity: String
    let expectedTrainingStress: Int
    let role: RemainingActivityRole
    let completedLoadToday: Int
    let activeCaloriesToday: Int
    let completedTrainingStress: Int
    let recoveryPercent: Int?
    let readiness: String
    let tomorrowDemand: Bool
    let contributors: [CoachContributor]
    let riskLevel: RemainingActivityRiskLevel
    let recommendedAction: RemainingActivityRecommendedAction
    let maxRecommendedDuration: Int?
    let maxRecommendedIntensity: String?
    let replacementSuggestion: String?
    let reason: String

    var title: String {
        switch recommendedAction {
        case .keep where category == "recovery":
            return "Keep it recovery-only"
        case .makeEasy, .shorten:
            return category == "running" ? "Keep it very easy" : "Keep it easy and short"
        case .replace:
            return "Replace the \(activityNoun)"
        case .skip, .moveToTomorrow:
            return category == "running" ? "Replace the run" : "Move the \(activityNoun)"
        case .keep:
            return "Keep the plan gentle"
        }
    }

    var diagnosisSentence: String {
        switch riskLevel {
        case .low where category == "recovery":
            return "\(activityTitle) is recovery work, not another hard session."
        case .medium:
            return "A \(plannedDuration)-minute \(activityNoun) after this load is only useful if it stays very easy."
        case .high:
            return "A \(plannedDuration)-minute \(activityNoun) now would mostly add fatigue."
        case .critical:
            return "A \(plannedDuration)-minute \(activityNoun) no longer fits what today can absorb."
        case .low:
            return "\(activityTitle) still fits the day if it stays easy."
        }
    }

    var recommendationSentence: String {
        switch recommendedAction {
        case .keep where category == "recovery":
            return "\(activityTitle) is fine. Keep it gentle and avoid turning it into another workout."
        case .keep:
            return "Keep \(activityNoun) as planned, but do not add extra work around it."
        case .shorten, .makeEasy:
            let duration = maxRecommendedDuration.map { "\($0) minutes" } ?? "a short version"
            let intensity = maxRecommendedIntensity ?? "very easy"
            let replacement = replacementSuggestion ?? "walking or stretching"
            return "Only keep the \(activityNoun) if it stays \(duration) at \(intensity). Otherwise replace it with \(replacement)."
        case .replace:
            let duration = maxRecommendedDuration.map { "\($0) minutes" } ?? "20 minutes"
            let intensity = maxRecommendedIntensity ?? "very easy"
            let replacement = replacementSuggestion ?? "recovery work"
            return "Replace \(activityNoun) with \(replacement), or cap it at \(duration) \(intensity) if you still want to move."
        case .skip:
            return "Skip the \(activityNoun). Today's adaptation now depends on recovery."
        case .moveToTomorrow:
            return "Move the \(activityNoun) to another day. Today's adaptation now depends on recovery."
        }
    }

    var trapSentence: String {
        switch recommendedAction {
        case .keep where category == "recovery":
            return "Do not turn recovery work into another workout."
        default:
            return "Do not treat the planned \(activityNoun) as mandatory just because it is on the calendar."
        }
    }

    var debugLines: [String] {
        [
            "RemainingActivityRiskDebug.activityTitle=\(activityTitle)",
            "RemainingActivityRiskDebug.activityType=\(activityType)",
            "RemainingActivityRiskDebug.category=\(category)",
            "RemainingActivityRiskDebug.plannedDuration=\(plannedDuration)",
            "RemainingActivityRiskDebug.minutesUntilStart=\(minutesUntilStart)",
            "RemainingActivityRiskDebug.expectedTrainingStress=\(expectedTrainingStress)",
            "RemainingActivityRiskDebug.role=\(role.rawValue)",
            "RemainingActivityRiskDebug.riskLevel=\(riskLevel.rawValue)",
            "RemainingActivityRiskDebug.recommendedAction=\(recommendedAction.rawValue)",
            "RemainingActivityRiskDebug.maxRecommendedDuration=\(maxRecommendedDuration.map(String.init) ?? "nil")",
            "RemainingActivityRiskDebug.maxRecommendedIntensity=\(maxRecommendedIntensity ?? "nil")",
            "RemainingActivityRiskDebug.replacementSuggestion=\(replacementSuggestion ?? "nil")",
            "RemainingActivityRiskDebug.reason=\(reason)"
        ]
    }

    private var activityNoun: String {
        let normalized = activityTitle.lowercased()
        if normalized.contains("run") { return "run" }
        if normalized.contains("cycl") || normalized.contains("ride") { return "ride" }
        if normalized.contains("stretch") { return "stretching" }
        if normalized.contains("walk") { return "walk" }
        if normalized.contains("sauna") { return "sauna" }
        return normalized
    }
}

struct CoachDayRead: Hashable {
    let past: String
    let present: String
    let future: String

    var summary: String {
        [past, present, future]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct CoachDayDecisionFrame: Hashable {
    let dayRead: CoachDayRead
    let dayType: CoachSystemDayType
    let primarySession: PlannedActivity?
    let secondarySession: PlannedActivity?
    let supportSessions: [PlannedActivity]
    let primaryDriver: CoachPrimaryDriver
    let contributors: [CoachContributor]
    let planStatus: CoachPlanStatus
    let recommendationIntent: CoachRecommendationIntent
    let remainingActivityRisk: RemainingActivityRiskAssessment?
    let loadSourceDebug: CoachLoadSourceDebug
    let contextConfidence: CoachContextConfidence

    var shouldOwnNarrative: Bool {
        contextConfidence.dayLevelIsAuthoritative &&
            (planStatus.requiresPlanChange || planStatus == .complete)
    }

    var stateLabel: String {
        switch planStatus {
        case .cancel, .replace:
            return "REDUCE THE PLAN"
        case .downgrade, .adjust:
            return "ADJUST THE PLAN"
        case .complete:
            return "RECOVERY FIRST"
        case .valid:
            switch recommendationIntent {
            case .executeActiveSession:
                return "LIVE GUIDANCE"
            case .prepareForSession:
                return "PREPARE"
            case .protectTomorrow:
                return "PROTECT TOMORROW"
            default:
                return "ON TRACK"
            }
        }
    }

    var title: String {
        if let risk = remainingActivityRisk,
           planStatus.requiresPlanChange || planStatus == .complete {
            return risk.title
        }

        switch planStatus {
        case .cancel, .replace:
            return "Adjust today's plan"
        case .downgrade:
            return "Lower today's ceiling"
        case .adjust:
            return "Adjust the remaining plan"
        case .complete:
            return "Today's work is already sufficient"
        case .valid:
            return "The day plan still fits"
        }
    }

    var dayReadText: String {
        dayRead.summary
    }

    var diagnosisText: String {
        var parts = [
            dayReadText,
            primaryDriverText
        ]

        if let risk = remainingActivityRisk,
           planStatus.requiresPlanChange || planStatus == .complete {
            parts.append(risk.diagnosisSentence)
        }

        return parts
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var primaryDriverText: String {
        switch primaryDriver {
        case .none:
            return "No single plan-changing limiter is driving the day."
        default:
            return "\(primaryDriver.label) is the primary driver."
        }
    }

    var contributorText: String {
        guard !contributors.isEmpty else {
            return "No major supporting contributors are changing this decision."
        }

        let labels = contributors.map(\.label)
        return "Supporting evidence: \(labels.joined(separator: ", "))."
    }

    var trapText: String {
        if let risk = remainingActivityRisk,
           planStatus.requiresPlanChange || planStatus == .complete {
            return risk.trapSentence
        }

        switch planStatus {
        case .cancel, .replace, .downgrade, .adjust:
            return "Do not treat a scheduled workout as work you still need to complete."
        case .complete:
            return "Do not add work just because there is time left in the day."
        case .valid:
            return "Do not let support gaps become the main story."
        }
    }

    var planStatusText: String {
        switch planStatus {
        case .valid:
            return "The remaining plan is still appropriate."
        case .adjust:
            return "The remaining plan needs adjustment before it is productive."
        case .downgrade:
            return "The remaining plan needs a lower ceiling."
        case .replace:
            return "The remaining plan no longer matches today's accumulated load."
        case .cancel:
            return "The remaining plan should be removed today."
        case .complete:
            return "The useful work for today is already complete."
        }
    }

    var recommendationText: String {
        if let risk = remainingActivityRisk,
           planStatus.requiresPlanChange || planStatus == .complete {
            return risk.recommendationSentence
        }

        switch planStatus {
        case .cancel:
            return "Cancel the remaining training and make recovery the next session."
        case .replace:
            return "Replace the remaining training with recovery work, or postpone it."
        case .downgrade:
            return "Keep the plan only if it becomes an easy version with no intensity."
        case .adjust:
            return "Change the remaining plan so it protects the work already done."
        case .complete:
            return "The best adaptation now comes from recovery, not additional training."
        case .valid:
            switch recommendationIntent {
            case .executeActiveSession:
                return "Execute the current activity inside today's limits."
            case .prepareForSession:
                return "Prepare for the next session without adding extra fatigue."
            case .protectTomorrow:
                return "Protect tomorrow by keeping the rest of today easy."
            default:
                return "Continue the plan and keep the basics steady."
            }
        }
    }

    var whyText: String {
        let riskEvidence = remainingActivityRisk.map {
            "Remaining activity: \($0.plannedDuration) minutes, \($0.expectedIntensity), risk \($0.riskLevel.rawValue)."
        }
        let evidence = [contributorText, riskEvidence]
            .compactMap { $0 }
            .joined(separator: " ")
        switch primaryDriver {
        case .none:
            return evidence
        case .accumulatedFatigue, .overloadRisk, .excessiveLoad:
            return "\(evidence) More work is unlikely to add useful fitness until the existing load is absorbed."
        case .poorSleep:
            return "\(evidence) Sleep changes how much intensity the body can productively use today."
        case .lowRecovery:
            return "\(evidence) Recovery is limiting how much additional stress the body can absorb."
        case .tomorrowDemand:
            return "\(evidence) Tomorrow's demand makes freshness more valuable than extra load today."
        case .illness, .injury, .unsafeHeatStress:
            return "\(evidence) The safety cost is higher than the training upside."
        }
    }

    var coachMessage: String {
        [
            "Day Read\n\(dayReadText)",
            "Primary Driver\n\(primaryDriverText)",
            "Contributors\n\(contributorText)",
            "Plan Status\n\(planStatusText)",
            "Recommendation\n\(recommendationText)",
            "Why\n\(whyText)"
        ].joined(separator: "\n\n")
    }

    var todayTitle: String {
        switch planStatus {
        case .cancel, .replace, .downgrade, .adjust:
            return "Adjust today’s plan"
        case .complete:
            return "Recovery now leads"
        case .valid:
            return "Coach plan is on track"
        }
    }

    var todayMessage: String {
        switch planStatus {
        case .cancel, .replace:
            return "The remaining plan exceeds what today can absorb. Replace it with recovery or postpone it."
        case .downgrade:
            return "Keep any remaining training easy and below the normal ceiling."
        case .adjust:
            return "Change the remaining plan to protect the work already done."
        case .complete:
            return "The best next move is recovery, not additional load."
        case .valid:
            return recommendationText
        }
    }

    static func build(from context: CoachDecisionContext) -> CoachDayDecisionFrame {
        let dayContext = context.dayContext
        let primary = primarySession(in: dayContext)
        let secondary = secondarySession(in: dayContext, excluding: primary)
        let support = supportSessions(in: dayContext, excluding: [primary?.id, secondary?.id].compactMap { $0 })
        let loadDebug = resolveLoadSourceDebug(context: context)
        let dayType = resolveDayType(context: context, primary: primary)
        let contributors = resolveContributors(context: context)
        let primaryDriver = resolvePrimaryDriver(context: context, dayType: dayType, contributors: contributors)
        let planStatus = resolvePlanStatus(
            context: context,
            dayType: dayType,
            primaryDriver: primaryDriver,
            contributors: contributors
        )
        let recommendationIntent = resolveRecommendationIntent(
            context: context,
            planStatus: planStatus,
            primaryDriver: primaryDriver
        )
        let remainingActivityRisk = resolveRemainingActivityRisk(
            context: context,
            primarySession: primary,
            secondarySession: secondary,
            supportSessions: support,
            dayType: dayType,
            primaryDriver: primaryDriver,
            contributors: contributors
        )

        return CoachDayDecisionFrame(
            dayRead: CoachDayRead(
                past: pastRead(context: context),
                present: presentRead(context: context),
                future: futureRead(context: context)
            ),
            dayType: dayType,
            primarySession: primary,
            secondarySession: secondary,
            supportSessions: support,
            primaryDriver: primaryDriver,
            contributors: contributors,
            planStatus: planStatus,
            recommendationIntent: recommendationIntent,
            remainingActivityRisk: remainingActivityRisk,
            loadSourceDebug: loadDebug,
            contextConfidence: context.contextConfidence
        )
    }
}

extension CoachDecisionContext {
    var dayDecisionFrame: CoachDayDecisionFrame {
        CoachDayDecisionFrame.build(from: self)
    }
}

private extension CoachDayDecisionFrame {
    struct HeatRiskFactors {
        let recoveryPoor: Bool
        let severeDehydration: Bool
        let recentTrainingLoadHigh: Bool
        let multipleHardSessionsCompleted: Bool

        var hasAnyRisk: Bool {
            recoveryPoor ||
                severeDehydration ||
                recentTrainingLoadHigh ||
                multipleHardSessionsCompleted
        }

        var isHighRisk: Bool {
            severeDehydration ||
                multipleHardSessionsCompleted ||
                (recoveryPoor && recentTrainingLoadHigh)
        }
    }

    static func primarySession(in context: CoachDayContext) -> PlannedActivity? {
        context.allActivities
            .filter { !isSupporting($0) && sessionScore($0) > 0 }
            .max { sessionScore($0) < sessionScore($1) }
    }

    static func secondarySession(in context: CoachDayContext, excluding primary: PlannedActivity?) -> PlannedActivity? {
        context.allActivities
            .filter { activity in
                activity.id != primary?.id && !isSupporting(activity) && sessionScore(activity) > 0
            }
            .max { sessionScore($0) < sessionScore($1) }
    }

    static func supportSessions(in context: CoachDayContext, excluding ids: [String]) -> [PlannedActivity] {
        context.allActivities.filter { activity in
            !ids.contains(activity.id) && (isSupporting(activity) || sessionScore(activity) < 35)
        }
    }

    static func resolveDayType(
        context: CoachDecisionContext,
        primary: PlannedActivity?
    ) -> CoachSystemDayType {
        let day = context.dayContext
        let actualLoad = context.actualLoad
        let recoveryPercent = context.recoveryContext?.recoveryPercent ?? 0
        let progressCanRepresentHighLoad = actualLoad.activeCalories >= 550 ||
            (actualLoad.exerciseMinutes ?? 0) >= 60
        if (progressCanRepresentHighLoad && actualLoad.activityProgress.map({ $0 >= 1.75 }) == true) ||
            actualLoad.activeCalories >= 800 {
            return .overload
        }
        if context.contextConfidence.dayLevelIsAuthoritative,
           recoveryPercent > 0,
           recoveryPercent < 55,
           !day.hasMoreLoadAhead {
            return .deload
        }
        if day.dayType == .recovery {
            return .recovery
        }
        if primary != nil {
            return day.totalTrainingStressScore >= 4 ? .performance : .training
        }
        return .maintenance
    }

    static func resolvePrimaryDriver(
        context: CoachDecisionContext,
        dayType: CoachSystemDayType,
        contributors: [CoachContributor]
    ) -> CoachPrimaryDriver {
        let day = context.dayContext
        let recovery = context.recoveryContext?.recoveryPercent
        let sleepHours = context.recoveryContext?.sleepHours ?? context.brain.metrics.sleepHours
        let hasHeatNow = [context.activityContext.activeActivity, context.activityContext.preparingActivity]
            .compactMap { $0 }
            .contains { CoachActivityContextResolverV3.kind(for: $0) == .heat }

        if hasHeatNow,
           hydrationRatio(context) < 0.30 {
            return .unsafeHeatStress
        }
        if day.hasMoreLoadAhead,
           !day.hasMeaningfulLoadCompleted,
           context.actualLoad.activeCalories < 750,
           recovery.map({ $0 >= 75 }) == true,
           sleepHours >= 6.0 {
            return .none
        }
        let activityCircleProgress = context.actualLoad.activityProgress ?? 0
        let completedLoadIsHigh = context.actualLoad.activeCalories >= 750 ||
            activityCircleProgress >= 1.5 ||
            (context.actualLoad.exerciseMinutes ?? 0) >= 90
        let recoveryIsActuallyLimited = recovery.map { $0 < 60 } == true ||
            context.brain.recovery == .compromised ||
            sleepHours < 6.0

        if dayType == .overload, day.hasMoreLoadAhead, completedLoadIsHigh || recoveryIsActuallyLimited {
            return completedLoadIsHigh
                ? .accumulatedFatigue
                : .overloadRisk
        }
        if day.hasMoreLoadAhead, completedLoadIsHigh, day.upcomingTrainingStressScore >= 4 {
            return .excessiveLoad
        }
        if context.contextConfidence.dayLevelIsAuthoritative,
           sleepHours > 0,
           sleepHours < 6.0 {
            return .poorSleep
        }
        if context.contextConfidence.dayLevelIsAuthoritative {
            if recovery.map({ $0 < 55 }) == true ||
                context.brain.recovery == .compromised ||
                context.brain.readiness == .compromised {
                return .lowRecovery
            }
        }
        if context.tomorrowDemand.isHard,
           completedLoadIsHigh || contributors.contains(.tomorrowDemand) {
            return .tomorrowDemand
        }
        return .none
    }

    static func resolveContributors(context: CoachDecisionContext) -> [CoachContributor] {
        var contributors: [CoachContributor] = []

        func append(_ contributor: CoachContributor) {
            guard !contributors.contains(contributor) else { return }
            contributors.append(contributor)
        }

        let recoveryContributorDebug = CoachRecoveryContributorDebug.resolve(context: context)
        recoveryContributorDebug.activeContributors.forEach(append)

        if context.nutritionContext?.lastMealTime == nil, context.dayContext.hasMoreLoadAhead {
            append(.poorMealTiming)
        }
        if context.dayContext.allActivities.contains(where: { CoachActivityContextResolverV3.kind(for: $0) == .heat && !$0.isCompleted }) {
            append(.heatStress)
        }
        if context.dayContext.completedActivities.contains(where: { CoachActivityContextResolverV3.kind(for: $0) == .heat }) {
            append(.recentSauna)
        }
        if context.actualLoad.activeCalories >= 750 || context.actualLoad.activityProgress.map({ $0 >= 1.5 }) == true {
            append(.highActiveCalories)
        }
        if context.tomorrowDemand.isHard {
            append(.tomorrowDemand)
        }

        return contributors
    }

    static func resolvePlanStatus(
        context: CoachDecisionContext,
        dayType: CoachSystemDayType,
        primaryDriver: CoachPrimaryDriver,
        contributors: [CoachContributor]
    ) -> CoachPlanStatus {
        let day = context.dayContext
        switch primaryDriver {
        case .unsafeHeatStress, .illness, .injury:
            return .cancel
        case .accumulatedFatigue, .overloadRisk, .excessiveLoad:
            guard day.hasMoreLoadAhead else { return .complete }
            if dayType == .overload,
               context.brain.readiness == .low || context.brain.recovery == .compromised {
                return .replace
            }
            return .downgrade
        case .lowRecovery:
            guard day.hasMoreLoadAhead else { return .complete }
            return context.brain.readiness == .low ? .downgrade : .adjust
        case .poorSleep:
            guard day.hasMoreLoadAhead else { return .complete }
            return .downgrade
        case .tomorrowDemand:
            return day.hasMoreLoadAhead ? .adjust : .complete
        case .none:
            return day.hasMeaningfulLoadCompleted && !day.hasMoreLoadAhead && dayType == .overload ? .complete : .valid
        }
    }

    static func resolveRecommendationIntent(
        context: CoachDecisionContext,
        planStatus: CoachPlanStatus,
        primaryDriver: CoachPrimaryDriver
    ) -> CoachRecommendationIntent {
        if planStatus.requiresPlanChange {
            return .modifyRemainingPlan
        }
        if planStatus == .complete {
            return .recoverNow
        }
        if primaryDriver == .tomorrowDemand {
            return .protectTomorrow
        }
        if context.activityContext.activeActivity != nil {
            return .executeActiveSession
        }
        if context.activityContext.preparingActivity != nil {
            return .prepareForSession
        }
        if context.dayContext.hasMoreLoadAhead {
            return .protectPrimarySession
        }
        return .continuePlan
    }

    static func resolveRemainingActivityRisk(
        context: CoachDecisionContext,
        primarySession: PlannedActivity?,
        secondarySession: PlannedActivity?,
        supportSessions: [PlannedActivity],
        dayType: CoachSystemDayType,
        primaryDriver: CoachPrimaryDriver,
        contributors: [CoachContributor]
    ) -> RemainingActivityRiskAssessment? {
        let now = context.dayContext.now
        guard let activity = nextRemainingActivity(context: context) else { return nil }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let duration = max(activity.effectiveDurationMinutes, activity.durationMinutes)
        let minutesUntilStart = max(0, Int(activity.date.timeIntervalSince(now) / 60))
        let category = riskCategory(activity: activity, kind: kind)
        let role = activity.id == primarySession?.id
            ? RemainingActivityRole.primary
            : (activity.id == secondarySession?.id
                ? .secondary
                : (supportSessions.contains(where: { $0.id == activity.id }) ? .support : .extra))
        let expectedStress = expectedTrainingStress(
            category: category,
            load: load,
            duration: duration
        )
        let expectedIntensity = expectedIntensityText(load: load, category: category)
        let completedLoad = Int(context.actualLoad.activeCalories.rounded())
        let activeCalories = Int(context.actualLoad.activeCalories.rounded())
        let completedStress = actualCompletedTrainingStress(context: context)
        let tomorrowDemand = context.tomorrowDemand.isHard
        let recoveryPercent = context.recoveryContext.map { Int($0.recoveryPercent) }
        let progressCanRepresentHighLoad = activeCalories >= 550 ||
            (context.actualLoad.exerciseMinutes ?? 0) >= 60
        let dayIsLoaded = dayType == .overload ||
            completedStress >= 3 ||
            activeCalories >= 750 ||
            (progressCanRepresentHighLoad && context.actualLoad.activityProgress.map({ $0 >= 1.5 }) == true) ||
            primaryDriver == .accumulatedFatigue ||
            primaryDriver == .overloadRisk ||
            primaryDriver == .excessiveLoad
        let recoveryLimited = context.brain.recovery == .compromised ||
            context.brain.readiness == .low ||
            context.brain.readiness == .compromised ||
            recoveryPercent.map { $0 < 60 } == true
        let severeHydrationDrag = hydrationRatio(context) < 0.30
        let supportDrag = severeHydrationDrag ||
            contributors.contains(.underfueled) ||
            contributors.contains(.proteinBehind)
        let heatRiskFactors = HeatRiskFactors(
            recoveryPoor: recoveryLimited,
            severeDehydration: severeHydrationDrag,
            recentTrainingLoadHigh: completedStress >= 3 ||
                activeCalories >= 750 ||
                (progressCanRepresentHighLoad && context.actualLoad.activityProgress.map({ $0 >= 1.5 }) == true),
            multipleHardSessionsCompleted: context.dayContext.completedTrainingActivities.count >= 2
        )

        let classification = classifyRemainingActivityRisk(
            category: category,
            role: role,
            duration: duration,
            expectedStress: expectedStress,
            dayIsLoaded: dayIsLoaded,
            recoveryLimited: recoveryLimited,
            supportDrag: supportDrag,
            tomorrowDemand: tomorrowDemand,
            heatRiskFactors: heatRiskFactors
        )

        return RemainingActivityRiskAssessment(
            activity: activity,
            activityTitle: activity.title,
            activityType: activity.type,
            category: category,
            plannedDuration: duration,
            plannedStartTime: activity.date,
            minutesUntilStart: minutesUntilStart,
            expectedIntensity: expectedIntensity,
            expectedTrainingStress: expectedStress,
            role: role,
            completedLoadToday: completedLoad,
            activeCaloriesToday: activeCalories,
            completedTrainingStress: completedStress,
            recoveryPercent: recoveryPercent,
            readiness: "\(context.brain.readiness)",
            tomorrowDemand: tomorrowDemand,
            contributors: contributors,
            riskLevel: classification.riskLevel,
            recommendedAction: classification.action,
            maxRecommendedDuration: classification.maxDuration,
            maxRecommendedIntensity: classification.maxIntensity,
            replacementSuggestion: classification.replacement,
            reason: classification.reason
        )
    }

    static func resolveLoadSourceDebug(context: CoachDecisionContext) -> CoachLoadSourceDebug {
        let completed = context.dayContext.completedActivities + context.dayContext.partialActivities
        let synced = completed.filter(isSyncedAppleWorkout)
        let manual = completed.filter { !isSyncedAppleWorkout($0) }
        let plannedCalories = completed.reduce(0.0) {
            $0 + Double(CoachActivityContextResolverV3.activityCalories($1))
        }
        let actualCalories = context.actualLoad.activeCalories

        let discrepancyReason: String?
        if actualCalories >= plannedCalories + 150 {
            discrepancyReason = "activityCircleHigherThanPlanned"
        } else if plannedCalories >= actualCalories + 150 {
            discrepancyReason = "plannedCompletedHigherThanActivityCircle"
        } else if !manual.isEmpty && actualCalories < 120 {
            discrepancyReason = "manualCompletionNotConfirmedByActivityCircle"
        } else if synced.count > 0 && completed.count > synced.count {
            discrepancyReason = "syncedAndManualCompletedActivitiesPresent"
        } else {
            discrepancyReason = nil
        }

        return CoachLoadSourceDebug(
            activityCircleActiveCalories: actualCalories,
            activityCircleExerciseMinutes: context.actualLoad.exerciseMinutes,
            activityCircleProgress: context.actualLoad.activityProgress,
            plannedCompletedActivities: completed.count,
            syncedAppleWorkouts: synced.count,
            manualCompletedActivities: manual.count,
            loadSourceUsed: context.actualLoad.source,
            discrepancyDetected: discrepancyReason != nil,
            discrepancyReason: discrepancyReason
        )
    }

    static func actualCompletedTrainingStress(context: CoachDecisionContext) -> Int {
        let activityProgressStress: Int
        switch context.actualLoad.activityProgress ?? 0 {
        case 1.75...:
            activityProgressStress = 5
        case 1.25..<1.75:
            activityProgressStress = 3
        case 0.75..<1.25:
            activityProgressStress = 1
        default:
            activityProgressStress = 0
        }

        let calorieStress: Int
        switch context.actualLoad.activeCalories {
        case 900...:
            calorieStress = 5
        case 750..<900:
            calorieStress = 4
        case 550..<750:
            calorieStress = 2
        default:
            calorieStress = 0
        }

        let exerciseStress: Int
        switch context.actualLoad.exerciseMinutes ?? 0 {
        case 90...:
            exerciseStress = 4
        case 60..<90:
            exerciseStress = 3
        case 30..<60:
            exerciseStress = 1
        default:
            exerciseStress = 0
        }

        return max(activityProgressStress, calorieStress, exerciseStress)
    }

    static func pastRead(context: CoachDecisionContext) -> String {
        let completed = context.dayContext.completedActivities
            .filter(isMeaningfulCompletedActivity)
        guard !completed.isEmpty else { return "No meaningful activity has been completed yet today." }

        let summary = completedActivitySummary(for: completed)
        let loadIsHigh = context.actualLoad.activeCalories >= 750 ||
            context.actualLoad.activityProgress.map({ $0 >= 1.5 }) == true ||
            actualCompletedTrainingStress(context: context) >= 3

        if loadIsHigh {
            if summary.hasTraining, summary.hasRecovery, summary.hasHeat {
                return "Today combined training, recovery work, and sauna into a high-load day."
            }

            if summary.hasTraining, summary.hasRecovery {
                return "You accumulated a high-load day through training plus recovery work."
            }

            if summary.hasTraining {
                return "You already completed enough meaningful training work today."
            }

            return "You already accumulated a high-load day through \(summary.phrase)."
        }

        if summary.hasTraining, summary.hasRecovery {
            return "Today combined both training and recovery work: \(summary.phrase)."
        }

        return "Today included \(summary.phrase)."
    }

    static func isMeaningfulCompletedActivity(_ activity: PlannedActivity) -> Bool {
        guard !activity.isSkipped else { return false }
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        switch kind {
        case .meal, .other:
            return false
        case .endurance, .workout, .heat, .recovery:
            return true
        }
    }

    struct CompletedActivitySummary {
        let phrase: String
        let hasRecovery: Bool
        let hasTraining: Bool
        let hasHeat: Bool
    }

    static func completedActivitySummary(
        for activities: [PlannedActivity]
    ) -> CompletedActivitySummary {
        var recoveryCounts: [String: Int] = [:]
        var trainingCounts: [String: Int] = [:]
        var heatCounts: [String: Int] = [:]

        for activity in activities {
            switch activitySummaryCategory(for: activity) {
            case .recovery(let key):
                recoveryCounts[key, default: 0] += 1
            case .training(let key):
                trainingCounts[key, default: 0] += 1
            case .heat(let key):
                heatCounts[key, default: 0] += 1
            case .ignore:
                continue
            }
        }

        var parts: [String] = []
        parts.append(contentsOf: recoverySummaryParts(recoveryCounts))
        parts.append(contentsOf: trainingSummaryParts(trainingCounts))
        parts.append(contentsOf: heatSummaryParts(heatCounts))

        let phrase = naturalList(parts.isEmpty ? ["meaningful movement"] : parts)
        return CompletedActivitySummary(
            phrase: phrase,
            hasRecovery: !recoveryCounts.isEmpty,
            hasTraining: !trainingCounts.isEmpty,
            hasHeat: !heatCounts.isEmpty
        )
    }

    enum ActivitySummaryCategory: Hashable {
        case recovery(String)
        case training(String)
        case heat(String)
        case ignore
    }

    static func activitySummaryCategory(for activity: PlannedActivity) -> ActivitySummaryCategory {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let imageName = activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let combined = [title, type, imageName].joined(separator: " ")
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        if kind == .heat || combined.contains("sauna") {
            return .heat("sauna")
        }

        if combined.contains("walk") {
            return .recovery("walk")
        }

        if combined.contains("stretch") {
            return .recovery("stretching")
        }

        if combined.contains("mobility") {
            return .recovery("mobility")
        }

        if kind == .recovery {
            return .recovery("recovery")
        }

        if combined.contains("core") {
            return .training("core")
        }

        if combined.contains("run") {
            return .training("running")
        }

        if combined.contains("cycl") || combined.contains("ride") {
            return .training("cycling")
        }

        if kind == .endurance || kind == .workout {
            return .training("workout")
        }

        return .ignore
    }

    static func recoverySummaryParts(_ counts: [String: Int]) -> [String] {
        var parts: [String] = []
        if let walks = counts["walk"], walks > 0 {
            parts.append(walks >= 2 ? "multiple recovery walks" : "a recovery walk")
        }

        if let stretching = counts["stretching"], stretching > 0 {
            parts.append(stretching >= 2 ? "stretching sessions" : "stretching")
        }

        if let mobility = counts["mobility"], mobility > 0 {
            parts.append(mobility >= 2 ? "mobility sessions" : "mobility")
        }

        let otherRecovery = counts
            .filter { !["walk", "stretching", "mobility"].contains($0.key) }
            .values
            .reduce(0, +)
        if otherRecovery > 0 {
            parts.append(otherRecovery >= 2 ? "recovery sessions" : "recovery work")
        }

        return parts
    }

    static func trainingSummaryParts(_ counts: [String: Int]) -> [String] {
        var parts: [String] = []
        if counts["core", default: 0] > 0 {
            parts.append("Core training")
        }

        if counts["running", default: 0] > 0 {
            parts.append(counts["running", default: 0] >= 2 ? "running sessions" : "a run")
        }

        if counts["cycling", default: 0] > 0 {
            parts.append(counts["cycling", default: 0] >= 2 ? "rides" : "a ride")
        }

        let workouts = counts["workout", default: 0]
        if workouts > 0 {
            parts.append(workouts >= 2 ? "workouts" : "a workout")
        }

        return parts
    }

    static func heatSummaryParts(_ counts: [String: Int]) -> [String] {
        guard counts.values.reduce(0, +) > 0 else { return [] }
        return ["sauna"]
    }

    static func naturalList(_ parts: [String]) -> String {
        switch parts.count {
        case 0:
            return ""
        case 1:
            return parts[0]
        case 2:
            return "\(parts[0]) and \(parts[1])"
        default:
            return "\(parts.dropLast().joined(separator: ", ")), and \(parts.last ?? "")"
        }
    }

    static func presentRead(context: CoachDecisionContext) -> String {
        if let active = context.activityContext.activeActivity {
            return "\(active.title) is active now."
        }
        if let recent = context.activityContext.recentlyCompletedActivity {
            return "\(recent.title) just finished."
        }
        return "Current load is \(Int(context.actualLoad.activeCalories)) active calories."
    }

    static func futureRead(context: CoachDecisionContext) -> String {
        let upcoming = context.dayContext.upcomingTrainingActivities
        if upcoming.isEmpty {
            return "No meaningful training remains today."
        }
        let names = upcoming.prefix(3).map(\.title).joined(separator: ", ")
        return "Remaining training today: \(names)."
    }

    static func sessionScore(_ activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let duration = activity.effectiveDurationMinutes
        let calories = CoachActivityContextResolverV3.activityCalories(activity)

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

        return base + loadBonus + min(duration / 15, 8) + min(calories / 120, 8) + (activity.isCompleted ? 2 : 0)
    }

    static func isSupporting(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        if kind == .recovery || kind == .heat { return true }
        if kind == .workout || kind == .endurance { return false }
        return CoachActivityContextResolverV3.load(for: activity) == .low
    }

    static func hydrationRatio(_ context: CoachDecisionContext) -> Double {
        ratio(
            current: context.nutritionContext?.waterCurrent ?? context.brain.metrics.waterLiters,
            goal: context.nutritionContext?.waterGoal ?? context.brain.fullDayGoals.waterLiters
        )
    }

    static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return max(0, current / goal)
    }

    static func nextRemainingActivity(context: CoachDecisionContext) -> PlannedActivity? {
        if let preparing = context.activityContext.preparingActivity {
            return preparing
        }
        if let next = context.activityContext.nextUpcomingActivity {
            return next
        }
        return context.dayContext.upcomingActivities.first
    }

    static func riskCategory(
        activity: PlannedActivity,
        kind: CoachActivityKindV3
    ) -> String {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        if title.contains("stretch") ||
            title.contains("mobility") ||
            title.contains("yoga") ||
            type.contains("stretch") ||
            type.contains("mobility") ||
            type.contains("yoga") {
            return "recovery"
        }
        if title.contains("run") || type.contains("run") {
            return "running"
        }
        if title.contains("cycl") ||
            title.contains("ride") ||
            type.contains("cycl") ||
            type.contains("bike") {
            return "cycling"
        }
        switch kind {
        case .endurance:
            return "endurance"
        case .workout:
            return "strength"
        case .heat:
            return "sauna"
        case .recovery:
            return "recovery"
        case .meal:
            return "meal"
        case .other:
            return "other"
        }
    }

    static func isSyncedAppleWorkout(_ activity: PlannedActivity) -> Bool {
        let source = activity.source.lowercased()
        return source.contains("health") ||
            source.contains("healthkit") ||
            source.contains("apple") ||
            source.contains("watch") ||
            source.contains("hk")
    }

    static func expectedTrainingStress(
        category: String,
        load: CoachActivityLoadV3,
        duration: Int
    ) -> Int {
        let base: Int
        switch category {
        case "running":
            base = 3
        case "cycling", "endurance":
            base = 2
        case "strength":
            base = 2
        case "sauna":
            base = 1
        case "recovery":
            base = 0
        default:
            base = 1
        }

        let loadBonus: Int
        switch load {
        case .extreme:
            loadBonus = 3
        case .high:
            loadBonus = 2
        case .moderate:
            loadBonus = 1
        case .low:
            loadBonus = 0
        }

        let durationBonus: Int
        if duration >= 90 {
            durationBonus = 3
        } else if duration >= 60 {
            durationBonus = 2
        } else if duration >= 30 {
            durationBonus = 1
        } else {
            durationBonus = 0
        }

        return base + loadBonus + durationBonus
    }

    static func expectedIntensityText(
        load: CoachActivityLoadV3,
        category: String
    ) -> String {
        if category == "recovery" { return "gentle" }
        switch load {
        case .extreme:
            return "very hard"
        case .high:
            return "hard"
        case .moderate:
            return "moderate"
        case .low:
            return "easy"
        }
    }

    static func classifyRemainingActivityRisk(
        category: String,
        role: RemainingActivityRole,
        duration: Int,
        expectedStress: Int,
        dayIsLoaded: Bool,
        recoveryLimited: Bool,
        supportDrag: Bool,
        tomorrowDemand: Bool,
        heatRiskFactors: HeatRiskFactors
    ) -> (
        riskLevel: RemainingActivityRiskLevel,
        action: RemainingActivityRecommendedAction,
        maxDuration: Int?,
        maxIntensity: String?,
        replacement: String?,
        reason: String
    ) {
        if category == "recovery" {
            return (.low, .keep, duration, "gentle", nil, "remaining activity is recovery-support")
        }

        guard dayIsLoaded || recoveryLimited || tomorrowDemand else {
            let risk: RemainingActivityRiskLevel = expectedStress >= 6 ? .medium : .low
            return (risk, .keep, nil, nil, nil, "day load still supports planned activity")
        }

        if category == "running" {
            if duration >= 45 || expectedStress >= 6 {
                return (.critical, tomorrowDemand ? .moveToTomorrow : .skip, nil, nil, "walking or stretching", "running duration is too costly after completed load")
            }
            if duration <= 20 {
                return (.medium, .makeEasy, min(duration, 15), "Zone 1", "walking or stretching", "short run only works as very easy movement")
            }
            return (.high, .replace, 15, "Zone 1", "walking or stretching", "run should be replaced or capped after completed load")
        }

        if category == "cycling" || category == "endurance" {
            if duration >= 75 || expectedStress >= 6 {
                return (.critical, .replace, 20, "very easy", "stretching, mobility, or an easy walk", "long endurance is no longer productive after completed load")
            }
            if duration >= 45 {
                return (.high, .replace, 20, "very easy", "recovery work", "endurance session would mostly add fatigue")
            }
            return (.medium, .makeEasy, min(duration, 20), "very easy", "mobility or walking", "endurance can only stay as short easy movement")
        }

        if category == "strength" {
            if duration >= 45 || expectedStress >= 5 {
                return (.high, .replace, 20, "technique-only", "mobility or stretching", "strength work would add more stress than useful adaptation")
            }
            return (.medium, .makeEasy, min(duration, 20), "technique-only", "mobility", "strength can only stay as low-load movement")
        }

        if category == "sauna" {
            if heatRiskFactors.isHighRisk {
                return (.high, .shorten, min(duration, 10), "easy heat exposure", "mobility or stretching", "heat risk is elevated by recovery, hydration, or completed load")
            }
            if heatRiskFactors.hasAnyRisk {
                return (.medium, .makeEasy, min(duration, 20), "easy heat exposure", nil, "sauna can stay easy with hydration and a clear exit point")
            }
            return (.low, .keep, duration, "easy heat exposure", nil, "sauna is recovery support when sleep, recovery, hydration, and load are stable")
        }

        if role == .support {
            return (.medium, .makeEasy, min(duration, 20), "easy", "mobility or stretching", "support activity should not become extra load")
        }

        return (.high, .replace, 20, "easy", "recovery work", "remaining activity adds load after a high-load day")
    }
}
