import Foundation

enum CoachDayFocus: Equatable {
    case activeActivity
    case prepareForActivity
    case performanceReadiness
    case postActivityRecovery
    case hydrationBehind
    case fuelBehind
    case recoveryNeeded
    case trainingReadinessWarning
    case tomorrowPlanRisk
    case nextActivityLater
    case dailyOverview
    case eveningWindDown
}

enum CoachDayPriority: Equatable {
    case recovery
    case sleepPreparation
    case hydration
    case fueling
    case planChallenge
    case performance
    case activeSession
    case stable
}

enum CoachSeverity {
    case normal
    case caution
    case critical
}

enum CoachingMode: Hashable {
    case execution
    case warning
    case adjustment
    case recovery
    case opportunity
    case reinforcement
}

enum CoachLimiter: Hashable {
    case sleep
    case recovery
    case hydration
    case fueling
    case accumulatedFatigue
    case upcomingTraining
    case excessivePlannedLoad
    case insufficientRecoveryTime
    case timing
    case trainingReadiness
    case none

    var label: String {
        switch self {
        case .sleep:
            return "Sleep"
        case .recovery:
            return "Recovery"
        case .hydration:
            return "Hydration"
        case .fueling:
            return "Fueling"
        case .accumulatedFatigue:
            return "Accumulated fatigue"
        case .upcomingTraining:
            return "Upcoming training"
        case .excessivePlannedLoad:
            return "Planned load"
        case .insufficientRecoveryTime:
            return "Recovery time"
        case .timing:
            return "Timing"
        case .trainingReadiness:
            return "Training readiness"
        case .none:
            return "None"
        }
    }
}

enum CoachMessageFamily: Hashable {
    case recovery
    case hydration
    case fueling
    case sleep
    case performance
    case planAdjustment
    case stable
}

enum CoachCommonSenseMode: Hashable {
    case morningSetup
    case actionableDay
    case preActivityPreparation
    case activeActivity
    case postActivityRecovery
    case lateEveningRecovery
    case dayClosed
}

enum CoachHorizon: Hashable {
    case yesterday
    case today
    case tomorrow
    case trend
}

enum CoachObjective: Hashable {
    case startDay
    case buildReadiness
    case prepareActivity
    case executeActivity
    case recoverFromActivity
    case recoveryDay
    case protectTomorrow
    case completeDay
    case maintainCourse
}

struct CoachTomorrowProtectionState: Hashable {
    let recommended: Bool
    let active: Bool
    let reasons: [String]
    let activeReason: String?

    static let none = CoachTomorrowProtectionState(
        recommended: false,
        active: false,
        reasons: [],
        activeReason: nil
    )
}

struct CoachTomorrowDemandAssessment: Hashable {
    let level: CoachTomorrowDemand
    let primaryTrainingActivity: PlannedActivity?
    let trainingMinutes: Int
    let trainingStressScore: Int

    var hasDemand: Bool {
        level != .none
    }

    var isHard: Bool {
        level == .hard
    }
}

enum CoachTomorrowDemandResolver {
    static func resolve(context: CoachDecisionContext) -> CoachTomorrowDemandAssessment {
        resolve(tomorrowContext: context.tomorrowContext)
    }

    static func resolve(tomorrowContext: CoachTomorrowPlanContext?) -> CoachTomorrowDemandAssessment {
        guard let tomorrowContext else {
            return CoachTomorrowDemandAssessment(
                level: .none,
                primaryTrainingActivity: nil,
                trainingMinutes: 0,
                trainingStressScore: 0
            )
        }

        return resolve(dayContext: tomorrowContext.dayContext)
    }

    static func resolve(dayContext: CoachDayContext) -> CoachTomorrowDemandAssessment {
        resolve(
            activities: dayContext.upcomingTrainingActivities,
            trainingMinutes: dayContext.upcomingTrainingMinutes,
            trainingStressScore: dayContext.upcomingTrainingStressScore
        )
    }

    static func resolve(activities: [PlannedActivity]) -> CoachTomorrowDemandAssessment {
        let trainingActivities = activities
            .filter { !$0.isSkipped }
            .filter { CoachDayPriorityResolver.isTraining($0) }
        let minutes = trainingActivities.reduce(0) { $0 + $1.effectiveDurationMinutes }
        let stress = trainingActivities.reduce(0) { $0 + stressScore($1) }

        return resolve(
            activities: trainingActivities,
            trainingMinutes: minutes,
            trainingStressScore: stress
        )
    }

    private static func resolve(
        activities: [PlannedActivity],
        trainingMinutes: Int,
        trainingStressScore: Int
    ) -> CoachTomorrowDemandAssessment {
        let primary = activities.max {
            CoachActivityContextResolverV3.load(for: $0).riskScore < CoachActivityContextResolverV3.load(for: $1).riskScore
        }
        let hasHardActivity = primary.map {
            let load = CoachActivityContextResolverV3.load(for: $0)
            return load == .high || load == .extreme
        } ?? false

        let level: CoachTomorrowDemand
        if trainingStressScore >= 3 || trainingMinutes >= 75 || hasHardActivity {
            level = .hard
        } else if trainingStressScore > 0 || trainingMinutes > 0 || primary != nil {
            level = trainingStressScore >= 2 || trainingMinutes >= 45 ? .moderate : .easy
        } else {
            level = .none
        }

        return CoachTomorrowDemandAssessment(
            level: level,
            primaryTrainingActivity: primary,
            trainingMinutes: trainingMinutes,
            trainingStressScore: trainingStressScore
        )
    }

    private static func stressScore(_ activity: PlannedActivity) -> Int {
        let load = CoachActivityContextResolverV3.load(for: activity)
        switch load {
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .extreme: return 4
        }
    }
}

enum CoachIntent: Hashable {
    case idleNow
    case dayPlanning
    case preparation
    case liveGuidance
    case postActivity
    case sleepPreparation
}

enum CoachOpportunity: Hashable {
    case none
    case highReadiness
    case recoveryMomentum
    case trainingOpportunity
    case consistencyWin
    case recoveryWindow
}

enum CoachSupportKind: Hashable {
    case hydration
    case fueling
    case recovery
    case pacing
    case sleep
}

enum CoachSupportPriority: Int, Hashable {
    case low = 0
    case useful = 1
    case important = 2
}

struct CoachSupportSignal: Hashable {
    let kind: CoachSupportKind
    let title: String
    let message: String
    let amount: String?
    let timing: String?
    let priority: CoachSupportPriority

    var bulletText: String {
        var parts: [String] = []

        for value in ([title, amount, timing] as [String?]) {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !parts.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { continue }
            parts.append(trimmed)
        }

        return parts
            .joined(separator: " • ")
    }
}

enum CoachInterventionValue: Hashable {
    case none
    case low
    case useful
    case high
}

enum CompletionState: Hashable {
    case incomplete
    case goodEnough
    case complete
}

enum CoachPriorityStrength: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    static func < (lhs: CoachPriorityStrength, rhs: CoachPriorityStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var level: CoachDayPriorityLevel {
        switch self {
        case .low:
            return .quiet
        case .medium:
            return .useful
        case .high:
            return .important
        case .critical:
            return .high
        }
    }
}

enum CoachDayPriorityLevel: Int, Comparable {
    case quiet = 0
    case useful = 1
    case important = 2
    case high = 3

    static func < (lhs: CoachDayPriorityLevel, rhs: CoachDayPriorityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var guidanceImportance: CoachGuidanceImportanceV3 {
        switch self {
        case .quiet: return .quiet
        case .useful: return .useful
        case .important: return .important
        case .high: return .high
        }
    }
}

struct CoachDayPriorityResult {
    let priority: CoachDayPriority
    let strength: CoachPriorityStrength
    let confidence: Double
    let mode: CoachingMode
    let limiter: CoachLimiter
    let messageFamily: CoachMessageFamily
    let priorityScore: Double
    let insightScore: Double
    let uniquenessScore: Double
    let decisionScore: Double
    let focus: CoachDayFocus
    let reason: String
    let reasons: [String]
    let activity: PlannedActivity?
    let overridesTimingFocus: Bool
    let todayTitle: String
    let todayMessage: String
    let detailTitle: String
    let detailMessage: String
    let supportBullets: [String]
    let whyThisMatters: String?
    let planChallenge: String?
    let horizon: CoachHorizon
    let objective: CoachObjective
    let opportunity: CoachOpportunity
    let interventionValue: CoachInterventionValue
    let interventionCostNote: String?
    let completionState: CompletionState
    let tomorrowProtection: CoachTomorrowProtectionState

    var title: String { detailTitle }
    var message: String { detailMessage }

    var level: CoachDayPriorityLevel {
        strength.level
    }

    var severity: CoachSeverity {
        if strength == .critical || isCriticalLimiter {
            return .critical
        }
        if (limiter != .none && limiter != .timing) ||
            focus == .tomorrowPlanRisk ||
            focus == .trainingReadinessWarning ||
            focus == .hydrationBehind ||
            focus == .fuelBehind {
            return .caution
        }
        return .normal
    }

    private var isCriticalLimiter: Bool {
        switch limiter {
        case .hydration:
            return strength == .critical
        case .trainingReadiness, .recovery, .accumulatedFatigue, .excessivePlannedLoad:
            return strength == .critical && priority == .planChallenge
        case .sleep, .fueling, .upcomingTraining, .insufficientRecoveryTime, .timing, .none:
            return false
        }
    }

    static let defaultOverview = CoachDayPriorityResult(
        focus: .dailyOverview,
        level: .quiet,
        reason: "No urgent day signal is ahead of the baseline plan.",
        activity: nil,
        overridesTimingFocus: false
    )

    init(
        focus: CoachDayFocus,
        level: CoachDayPriorityLevel,
        reason: String,
        activity: PlannedActivity?,
        overridesTimingFocus: Bool,
        priority: CoachDayPriority? = nil,
        strength: CoachPriorityStrength? = nil,
        confidence: Double = 0.55,
        mode: CoachingMode? = nil,
        limiter: CoachLimiter? = nil,
        messageFamily: CoachMessageFamily? = nil,
        priorityScore: Double = 0,
        insightScore: Double = 0,
        uniquenessScore: Double = 0,
        decisionScore: Double = 0,
        todayTitle: String? = nil,
        todayMessage: String? = nil,
        detailTitle: String? = nil,
        detailMessage: String? = nil,
        title: String? = nil,
        message: String? = nil,
        supportBullets: [String]? = nil,
        whyThisMatters: String? = nil,
        reasons: [String]? = nil,
        planChallenge: String? = nil,
        horizon: CoachHorizon? = nil,
        objective: CoachObjective? = nil,
        opportunity: CoachOpportunity? = nil,
        interventionValue: CoachInterventionValue? = nil,
        interventionCostNote: String? = nil,
        completionState: CompletionState? = nil,
        tomorrowProtection: CoachTomorrowProtectionState = .none
    ) {
        let requestedPriority = priority ?? Self.defaultPriority(for: focus)
        let resolvedPriority = Self.executionLayerSafePriority(requestedPriority, focus: focus)
        let resolvedFocus = Self.executionLayerSafeFocus(focus, priority: resolvedPriority)
        let requestedLimiter = limiter ?? Self.defaultLimiter(for: resolvedPriority, focus: resolvedFocus)
        let resolvedLimiter = Self.executionLayerSafeLimiter(
            requestedLimiter,
            priority: resolvedPriority,
            focus: resolvedFocus
        )
        let resolvedMessageFamily = Self.executionLayerSafeMessageFamily(
            messageFamily ?? Self.defaultMessageFamily(for: resolvedPriority),
            priority: resolvedPriority
        )
        self.priority = resolvedPriority
        self.strength = strength ?? Self.defaultStrength(for: level)
        self.confidence = min(max(confidence, 0), 1)
        self.mode = mode ?? Self.defaultMode(for: resolvedPriority, focus: resolvedFocus)
        self.limiter = resolvedLimiter
        self.messageFamily = resolvedMessageFamily
        self.priorityScore = priorityScore
        self.insightScore = insightScore
        self.uniquenessScore = uniquenessScore
        self.decisionScore = decisionScore
        self.focus = resolvedFocus
        self.reason = reason
        self.reasons = reasons ?? [reason]
        self.activity = activity
        self.overridesTimingFocus = overridesTimingFocus
        let resolvedDetailTitle = detailTitle ?? title ?? Self.defaultTitle(for: resolvedPriority, focus: resolvedFocus)
        let resolvedDetailMessage = detailMessage ?? message ?? Self.defaultDetailMessage(
            for: resolvedPriority,
            focus: resolvedFocus,
            limiter: resolvedLimiter,
            activity: activity
        )
        self.detailTitle = resolvedDetailTitle
        self.detailMessage = resolvedDetailMessage
        let resolvedTodayTitle = todayTitle ?? Self.defaultTodayTitle(
            for: resolvedPriority,
            focus: resolvedFocus,
            limiter: resolvedLimiter,
            activity: activity,
            canonicalDetailTitle: resolvedDetailTitle
        )
        self.todayTitle = resolvedTodayTitle
        let resolvedTodayMessage = todayMessage ?? Self.defaultTodayMessage(
            for: resolvedPriority,
            focus: resolvedFocus,
            limiter: resolvedLimiter,
            activity: activity,
            detailMessage: resolvedDetailMessage
        )
        self.todayMessage = resolvedTodayMessage
        let resolvedSupportBullets = supportBullets ?? Self.defaultSupportBullets(for: resolvedPriority, activity: activity)
        self.supportBullets = resolvedSupportBullets
        self.whyThisMatters = whyThisMatters
        self.planChallenge = planChallenge
        self.horizon = horizon ?? Self.defaultHorizon(for: resolvedFocus, limiter: resolvedLimiter)
        let resolvedObjective = objective ??
            Self.defaultObjective(
                for: resolvedFocus,
                priority: resolvedPriority,
                limiter: resolvedLimiter
            )

        let resolvedOpportunity = opportunity ??
            Self.defaultOpportunity(
                for: resolvedFocus,
                priority: resolvedPriority,
                mode: self.mode,
                limiter: resolvedLimiter
            )

        let resolvedInterventionValue = interventionValue ??
            Self.defaultInterventionValue(
                for: resolvedPriority,
                level: (strength ?? Self.defaultStrength(for: level)).level,
                opportunity: resolvedOpportunity
            )

        self.objective = resolvedObjective
        self.opportunity = resolvedOpportunity
        self.interventionValue = resolvedInterventionValue
        self.interventionCostNote = interventionCostNote
        self.completionState = completionState ?? Self.defaultCompletionState(for: resolvedPriority, focus: focus)
        self.tomorrowProtection = tomorrowProtection
    }

    func phase(for timingContext: CoachDayActivityContext) -> CoachActivityPhaseV3 {
        switch focus {
        case .activeActivity, .prepareForActivity, .postActivityRecovery:
            return timingContext.phase
        case .nextActivityLater, .dailyOverview, .eveningWindDown:
            return .stable
        case .hydrationBehind, .fuelBehind, .recoveryNeeded, .trainingReadinessWarning, .tomorrowPlanRisk, .performanceReadiness:
            return overridesTimingFocus ? .stable : timingContext.phase
        }
    }

    func withScores(
        priorityScore: Double,
        insightScore: Double,
        uniquenessScore: Double,
        decisionScore: Double
    ) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: supportBullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: tomorrowProtection
        )
    }

    func withHumanStateReasoning(
        horizon: CoachHorizon,
        objective: CoachObjective,
        opportunity: CoachOpportunity,
        interventionValue: CoachInterventionValue,
        interventionCostNote: String?,
        completionState: CompletionState
    ) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: supportBullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: tomorrowProtection
        )
    }

    func withSupportBullets(_ bullets: [String]) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: bullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: tomorrowProtection
        )
    }

    func withLimiter(_ limiter: CoachLimiter) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: supportBullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: tomorrowProtection
        )
    }

    func withReasons(_ reasons: [String]) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: supportBullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: tomorrowProtection
        )
    }

    func withActivity(_ activity: PlannedActivity?) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: supportBullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: tomorrowProtection
        )
    }

    func withTomorrowProtection(_ state: CoachTomorrowProtectionState) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: focus,
            level: level,
            reason: reason,
            activity: activity,
            overridesTimingFocus: overridesTimingFocus,
            priority: priority,
            strength: strength,
            confidence: confidence,
            mode: mode,
            limiter: limiter,
            messageFamily: messageFamily,
            priorityScore: priorityScore,
            insightScore: insightScore,
            uniquenessScore: uniquenessScore,
            decisionScore: decisionScore,
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            detailTitle: detailTitle,
            detailMessage: detailMessage,
            supportBullets: supportBullets,
            whyThisMatters: whyThisMatters,
            reasons: reasons,
            planChallenge: planChallenge,
            horizon: horizon,
            objective: objective,
            opportunity: opportunity,
            interventionValue: interventionValue,
            interventionCostNote: interventionCostNote,
            completionState: completionState,
            tomorrowProtection: state
        )
    }
}

private extension CoachDayPriorityResult {

    static func executionLayerSafePriority(
        _ priority: CoachDayPriority,
        focus: CoachDayFocus
    ) -> CoachDayPriority {
        switch priority {
        case .hydration, .fueling:
            switch focus {
            case .prepareForActivity, .performanceReadiness, .activeActivity:
                return .performance
            case .tomorrowPlanRisk:
                return .planChallenge
            case .postActivityRecovery, .recoveryNeeded, .eveningWindDown, .hydrationBehind, .fuelBehind:
                return .recovery
            case .nextActivityLater, .dailyOverview:
                return .recovery
            case .trainingReadinessWarning:
                return .planChallenge
            }
        default:
            return priority
        }
    }

    static func executionLayerSafeFocus(
        _ focus: CoachDayFocus,
        priority: CoachDayPriority
    ) -> CoachDayFocus {
        switch focus {
        case .hydrationBehind, .fuelBehind:
            switch priority {
            case .performance, .activeSession:
                return .prepareForActivity
            case .planChallenge:
                return .tomorrowPlanRisk
            default:
                return .recoveryNeeded
            }
        default:
            return focus
        }
    }

    static func executionLayerSafeLimiter(
        _ limiter: CoachLimiter,
        priority: CoachDayPriority,
        focus: CoachDayFocus
    ) -> CoachLimiter {
        if focus == .tomorrowPlanRisk {
            return .upcomingTraining
        }

        switch limiter {
        case .hydration, .fueling:
            switch priority {
            case .performance, .activeSession:
                return .timing
            case .planChallenge:
                return .upcomingTraining
            case .sleepPreparation:
                return .sleep
            case .recovery:
                return focus == .postActivityRecovery ? .insufficientRecoveryTime : .recovery
            case .stable:
                return .none
            case .hydration, .fueling:
                return .none
            }
        default:
            return limiter
        }
    }

    static func executionLayerSafeMessageFamily(
        _ family: CoachMessageFamily,
        priority: CoachDayPriority
    ) -> CoachMessageFamily {
        switch family {
        case .hydration, .fueling:
            switch priority {
            case .performance, .activeSession:
                return .performance
            case .planChallenge:
                return .planAdjustment
            case .sleepPreparation:
                return .sleep
            case .recovery:
                return .recovery
            case .stable:
                return .stable
            case .hydration, .fueling:
                return .stable
            }
        default:
            return family
        }
    }

    static func defaultPriority(for focus: CoachDayFocus) -> CoachDayPriority {
        switch focus {
        case .hydrationBehind:
            return .recovery
        case .fuelBehind:
            return .recovery
        case .recoveryNeeded, .postActivityRecovery, .eveningWindDown:
            return .recovery
        case .trainingReadinessWarning, .performanceReadiness:
            return .performance
        case .tomorrowPlanRisk:
            return .planChallenge
        case .activeActivity:
            return .activeSession
        case .prepareForActivity:
            return .performance
        case .nextActivityLater, .dailyOverview:
            return .stable
        }
    }

    static func defaultMode(for priority: CoachDayPriority, focus: CoachDayFocus) -> CoachingMode {
        switch priority {
        case .activeSession:
            return .execution
        case .planChallenge:
            return .adjustment
        case .recovery, .sleepPreparation:
            return .recovery
        case .hydration, .fueling:
            return focus == .prepareForActivity ? .warning : .opportunity
        case .performance:
            return focus == .performanceReadiness ? .reinforcement : .warning
        case .stable:
            return .reinforcement
        }
    }

    static func defaultLimiter(for priority: CoachDayPriority, focus: CoachDayFocus) -> CoachLimiter {
        switch priority {
        case .hydration:
            return .hydration
        case .fueling:
            return .fueling
        case .sleepPreparation:
            return .sleep
        case .recovery:
            return focus == .postActivityRecovery ? .insufficientRecoveryTime : .recovery
        case .planChallenge:
            return .upcomingTraining
        case .performance:
            return .trainingReadiness
        case .activeSession:
            return .timing
        case .stable:
            return .none
        }
    }

    static func defaultMessageFamily(for priority: CoachDayPriority) -> CoachMessageFamily {
        switch priority {
        case .recovery:
            return .recovery
        case .sleepPreparation:
            return .sleep
        case .hydration:
            return .hydration
        case .fueling:
            return .fueling
        case .planChallenge:
            return .planAdjustment
        case .performance, .activeSession:
            return .performance
        case .stable:
            return .stable
        }
    }

    static func defaultStrength(for level: CoachDayPriorityLevel) -> CoachPriorityStrength {
        switch level {
        case .quiet:
            return .low
        case .useful:
            return .medium
        case .important:
            return .high
        case .high:
            return .critical
        }
    }

    static func defaultTitle(for priority: CoachDayPriority, focus: CoachDayFocus) -> String {
        switch priority {
        case .recovery:
            return focus == .eveningWindDown ? "Start winding down" : "Recovery needs protection"
        case .sleepPreparation:
            return "Recovery is the priority tonight"
        case .hydration:
            return "Support the next effort"
        case .fueling:
            return "Make energy available"
        case .planChallenge:
            return "Tomorrow may need adjusting"
        case .performance:
            return "Adjust training readiness"
        case .activeSession:
            return "Keep this session easy"
        case .stable:
            return "Day overview"
        }
    }

    static func defaultDetailMessage(
        for priority: CoachDayPriority,
        focus: CoachDayFocus,
        limiter: CoachLimiter,
        activity: PlannedActivity?
    ) -> String {
        switch priority {
        case .recovery:
            if limiter == .sleep {
                return "Sleep and recovery should lead the next decision."
            }
            if focus == .postActivityRecovery {
                return "The useful work is already done. Recovery now helps you keep it."
            }
            return "Your body will get more from recovery than from extra load right now."
        case .sleepPreparation:
            return "The best next move is a calmer evening and better sleep."
        case .hydration:
            return activity.map { CoachActivityContextResolverV3.kind(for: $0) == .heat } == true
                ? "Heat work goes better when fluids are already moving."
                : "Fluids need attention before the next useful step."
        case .fueling:
            return "A normal meal now supports steady energy without changing the whole plan."
        case .planChallenge:
            return "The plan should stay flexible until readiness improves."
        case .performance:
            return "Start controlled and let the first minutes confirm the right effort."
        case .activeSession:
            return "The current workout is already creating enough load."
        case .stable:
            return "The day does not need a correction right now."
        }
    }

    static func defaultTodayTitle(
        for priority: CoachDayPriority,
        focus: CoachDayFocus,
        limiter: CoachLimiter,
        activity: PlannedActivity?,
        canonicalDetailTitle: String
    ) -> String {
        switch priority {
        case .recovery:
            if limiter == .sleep {
                return "Sleep leads recovery"
            }
            if limiter == .accumulatedFatigue {
                return "The work is done"
            }
            if limiter == .upcomingTraining {
                return "Protect tomorrow"
            }
            return focus == .postActivityRecovery ? "Protect the work you just did" : "Let recovery lead"
        case .sleepPreparation:
            return limiter == .sleep ? "Sleep leads recovery" : "Protect tonight"
        case .hydration:
            let canonicalTitle = canonicalDetailTitle.lowercased()
            let isHeatContext = activity.map { CoachActivityContextResolverV3.kind(for: $0) == .heat } == true ||
                canonicalTitle.contains("heat") ||
                canonicalTitle.contains("sauna")
            return isHeatContext
                ? "Prepare for heat"
                : "Bring fluids up"
        case .fueling:
            let canonicalTitle = canonicalDetailTitle.lowercased()
            return focus == .eveningWindDown || canonicalTitle.contains("tonight")
                ? "Refuel tonight"
                : "Fuel before training"
        case .planChallenge:
            return focus == .tomorrowPlanRisk ? "Save energy for tomorrow" : "Make the plan easier"
        case .performance:
            return "Ready to train"
        case .activeSession:
            return "Stay steady"
        case .stable:
            return focus == .eveningWindDown ? "Protect tonight" : "On track"
        }
    }

    static func defaultTodayMessage(
        for priority: CoachDayPriority,
        focus: CoachDayFocus,
        limiter: CoachLimiter,
        activity: PlannedActivity?,
        detailMessage: String
    ) -> String {
        switch priority {
        case .recovery:
            if limiter == .sleep {
                return "Protect tonight's sleep."
            }
            if limiter == .accumulatedFatigue {
                return "Let recovery do its job."
            }
            if limiter == .upcomingTraining {
                return "Keep tomorrow flexible."
            }
            return focus == .postActivityRecovery
                ? "Recovery starts now. Refuel, rehydrate, and avoid extra intensity."
                : "Keep the next block easy."
        case .sleepPreparation:
            return "Protect tonight's sleep."
        case .hydration:
            return (activity.map { CoachActivityContextResolverV3.kind(for: $0) == .heat } ?? false)
                ? "Do not start sauna dry."
                : "Sip steadily now."
        case .fueling:
            return activity == nil ? "Refuel before tomorrow." : "Add easy fuel now."
        case .planChallenge:
            return "Recovery starts tonight."
        case .performance:
            return "Start easy."
        case .activeSession:
            return "Keep effort smooth."
        case .stable:
            return focus == .eveningWindDown ? "Keep the evening calm." : "No urgent move needed."
        }
    }

    static func defaultSupportBullets(
        for priority: CoachDayPriority,
        activity: PlannedActivity?
    ) -> [String] {
        switch priority {
        case .recovery, .sleepPreparation:
            return ["Keep mobility easy", "Continue with breathing", "Avoid additional training"]
        case .hydration:
            return ["Sip steadily", "Support the next block", "Avoid starting dry"]
        case .fueling:
            return ["Add easy fuel", "Keep it digestible", "Do not wait until the session"]
        case .planChallenge:
            return ["Make tomorrow easier", "Prioritize sleep tonight", "Be willing to swap intensity for recovery"]
        case .performance:
            return ["Start easier than usual", "Keep intensity flexible", "Leave room for recovery"]
        case .activeSession:
            return activity.map { ["Stay steady in \($0.title)", "Use small adjustments", "Finish cleanly"] } ?? ["Stay steady"]
        case .stable:
            return ["Keep rhythm", "Follow the plan", "Stay consistent"]
        }
    }

    static func localizedPriorityDisplayText(_ text: String, fallback: String) -> String {
        if text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil {
            return text
        }

        let localized = WeekFitCoachRuntimeLocalizedString(text)
        if localized != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return localized
        }

        return fallback
    }

    static func russianFallbackTitle(for priority: CoachDayPriority, focus: CoachDayFocus) -> String {
        switch priority {
        case .recovery:
            return focus == .eveningWindDown ? "Начните замедляться" : "Сейчас важнее восстановиться"
        case .sleepPreparation:
            return "Сегодня главное — сон и восстановление"
        case .hydration:
            return "Подготовьте тело к следующей нагрузке"
        case .fueling:
            return "Сделайте энергию доступной"
        case .planChallenge:
            return "План может требовать корректировки"
        case .performance:
            return "Настройте готовность к тренировке"
        case .activeSession:
            return "Держите эту тренировку легкой"
        case .stable:
            return "Обзор дня"
        }
    }

    static func russianFallbackTodayTitle(
        for priority: CoachDayPriority,
        focus: CoachDayFocus,
        limiter: CoachLimiter
    ) -> String {
        switch priority {
        case .recovery:
            if limiter == .sleep { return "Сон сейчас решает больше всего" }
            if limiter == .accumulatedFatigue { return "Работа уже сделана" }
            if limiter == .upcomingTraining { return "Сохраните силы на завтра" }
            return focus == .postActivityRecovery ? "Сохраните сделанную работу" : "Сегодня главное — восстановиться"
        case .sleepPreparation:
            return "Сохраните сон сегодня"
        case .hydration:
            return "Добавьте воды"
        case .fueling:
            return focus == .eveningWindDown ? "Восстановите питание вечером" : "Питание перед тренировкой"
        case .planChallenge:
            return focus == .tomorrowPlanRisk ? "Сохраните силы на завтра" : "Сделайте план легче"
        case .performance:
            return "Готовность к тренировке"
        case .activeSession:
            return "Держите ровно"
        case .stable:
            return focus == .eveningWindDown ? "Сделайте вечер спокойным" : "Все по плану"
        }
    }

    static func russianFallbackMessage(for priority: CoachDayPriority, focus: CoachDayFocus) -> String {
        switch priority {
        case .recovery, .sleepPreparation:
            return "Снизьте нагрузку, дайте организму восстановиться и не добавляйте интенсивность."
        case .hydration:
            return "Пейте воду постепенно, чтобы следующая нагрузка началась спокойнее."
        case .fueling:
            return "Добавьте простой прием пищи или легкие углеводы, чтобы энергия была доступна."
        case .planChallenge:
            return "Оставьте план гибким и снизьте интенсивность, если готовность не улучшится."
        case .performance:
            return "Начните легче обычного и дайте разминке определить темп."
        case .activeSession:
            return "Держите усилие повторяемым и завершите с запасом."
        case .stable:
            return focus == .eveningWindDown
                ? "Держите вечер спокойным и не добавляйте новую нагрузку."
                : "Сохраняйте ритм без лишних исправлений."
        }
    }

    static func russianFallbackTodayMessage(
        for priority: CoachDayPriority,
        focus: CoachDayFocus,
        limiter: CoachLimiter
    ) -> String {
        switch priority {
        case .recovery:
            if limiter == .sleep { return "Сохраните сон сегодня." }
            if limiter == .upcomingTraining { return "Оставьте завтра гибким." }
            return focus == .postActivityRecovery
                ? "Восстановление начинается сейчас: вода, питание и без лишней интенсивности."
                : "Держите следующий блок легким."
        case .sleepPreparation:
            return "Сохраните сон сегодня."
        case .hydration:
            return "Пейте спокойно и постепенно."
        case .fueling:
            return "Добавьте легкое питание сейчас."
        case .planChallenge:
            return "Восстановление начинается сегодня вечером."
        case .performance:
            return "Начните легко."
        case .activeSession:
            return "Держите усилие плавным."
        case .stable:
            return focus == .eveningWindDown ? "Держите вечер спокойным." : "Срочного действия не нужно."
        }
    }

    static func russianFallbackSupportBullets(for priority: CoachDayPriority) -> [String] {
        switch priority {
        case .recovery, .sleepPreparation:
            return ["Держите мобилити легкой", "Продолжайте спокойно дышать", "Избегайте дополнительной тренировки"]
        case .hydration:
            return ["Пейте постепенно", "Подготовьте следующий блок", "Не стартуйте без воды"]
        case .fueling:
            return ["Добавьте легкую еду", "Пусть еда легко усваивается", "Не ждите до самой тренировки"]
        case .planChallenge:
            return ["Сделайте завтра легче", "Сделайте сон главным", "При необходимости замените интенсивность восстановлением"]
        case .performance:
            return ["Сделайте план легче", "Оставьте интенсивность гибкой", "Дайте организму восстановиться"]
        case .activeSession:
            return ["Держите усилие ровным", "Корректируйте малыми шагами", "Завершите чисто"]
        case .stable:
            return ["Сохраняйте ритм", "Следуйте плану", "Оставайтесь последовательными"]
        }
    }

    static func russianFallbackWhy(for priority: CoachDayPriority, focus: CoachDayFocus) -> String {
        switch priority {
        case .recovery, .sleepPreparation:
            return "Восстановление работает лучше, когда после нагрузки есть место для сна и спокойного завершения дня."
        case .hydration:
            return "Вода влияет на качество следующей нагрузки, теплообмен и восстановление."
        case .fueling:
            return "Питание делает энергию доступной и снижает риск начать нагрузку неподготовленным."
        case .planChallenge:
            return "План полезен только тогда, когда организм способен его усвоить."
        case .performance:
            return "Качество тренировки зависит от контролируемого старта и гибкого потолка."
        case .activeSession:
            return "Во время тренировки повторяемое усилие важнее погони за планом любой ценой."
        case .stable:
            return focus == .eveningWindDown
                ? "Спокойный вечер помогает восстановиться лучше, чем новая нагрузка."
                : "Стабильному дню нужен ровный ритм, а не дополнительные исправления."
        }
    }

    static func russianFallbackPlanChallenge(for priority: CoachDayPriority, focus: CoachDayFocus) -> String {
        switch priority {
        case .planChallenge, .performance:
            return "Если готовность не улучшится к тренировке, сделайте ее легче или перенесите интенсивность."
        case .recovery, .sleepPreparation:
            return "Оставьте следующий блок гибким, пока самочувствие не станет надежнее."
        case .hydration:
            return "Не повышайте нагрузку, пока вода не вернется в норму."
        case .fueling:
            return "Не начинайте требовательную работу, пока питание не закрыто."
        case .activeSession:
            return "Пусть текущая тренировка задаст реальный темп нагрузки."
        case .stable:
            return focus == .eveningWindDown ? "Не добавляйте позднюю нагрузку." : "План можно оставить без изменений."
        }
    }

    static func defaultHorizon(for focus: CoachDayFocus, limiter: CoachLimiter) -> CoachHorizon {
        if focus == .tomorrowPlanRisk || limiter == .upcomingTraining {
            return .tomorrow
        }

        if limiter == .accumulatedFatigue {
            return .trend
        }

        if focus == .postActivityRecovery {
            return .yesterday
        }

        return .today
    }

    static func defaultObjective(
        for focus: CoachDayFocus,
        priority: CoachDayPriority,
        limiter: CoachLimiter
    ) -> CoachObjective {
        switch focus {
        case .activeActivity:
            return .executeActivity
        case .prepareForActivity:
            return .prepareActivity
        case .postActivityRecovery:
            return .recoverFromActivity
        case .tomorrowPlanRisk:
            return .protectTomorrow
        case .eveningWindDown:
            return .completeDay
        case .recoveryNeeded:
            return priority == .sleepPreparation ? .protectTomorrow : .recoveryDay
        case .hydrationBehind, .fuelBehind, .trainingReadinessWarning, .performanceReadiness:
            return .buildReadiness
        case .nextActivityLater, .dailyOverview:
            return limiter == .none ? .maintainCourse : .buildReadiness
        }
    }

    static func defaultOpportunity(
        for focus: CoachDayFocus,
        priority: CoachDayPriority,
        mode: CoachingMode,
        limiter: CoachLimiter
    ) -> CoachOpportunity {
        if priority == .performance && limiter == .none {
            return .trainingOpportunity
        }

        if priority == .recovery || priority == .sleepPreparation {
            return focus == .postActivityRecovery ? .recoveryWindow : .recoveryMomentum
        }

        return .none
    }

    static func defaultInterventionValue(
        for priority: CoachDayPriority,
        level: CoachDayPriorityLevel,
        opportunity: CoachOpportunity
    ) -> CoachInterventionValue {
        if priority == .stable && opportunity == .none {
            return .none
        }

        switch level {
        case .high:
            return .high
        case .important, .useful:
            return .useful
        case .quiet:
            return opportunity == .none ? .low : .useful
        }
    }

    static func defaultCompletionState(for priority: CoachDayPriority, focus: CoachDayFocus) -> CompletionState {
        switch priority {
        case .hydration, .fueling, .planChallenge:
            return .incomplete
        case .recovery, .sleepPreparation, .performance:
            return .goodEnough
        case .activeSession:
            return .incomplete
        case .stable:
            return focus == .dailyOverview ? .complete : .goodEnough
        }
    }
}

struct CoachTomorrowPlanContext {
    let dayContext: CoachDayContext

    var demand: CoachTomorrowDemandAssessment {
        CoachTomorrowDemandResolver.resolve(dayContext: dayContext)
    }

    var primaryTrainingActivity: PlannedActivity? {
        demand.primaryTrainingActivity
    }

    var hasHardTraining: Bool {
        demand.isHard
    }

    var hasRealDemand: Bool {
        demand.hasDemand
    }
}

struct CoachDecisionContext {
    let brain: HumanBrain.State
    let dayContext: CoachDayContext
    let activityContext: CoachDayActivityContext
    let tomorrowContext: CoachTomorrowPlanContext?
    let actualLoad: CoachActualLoadSnapshot
    let recoveryContext: CoachRecoveryContext?
    let nutritionContext: CoachNutritionContext?
    let readiness: CoachReadinessStateV3
    let contextConfidence: CoachContextConfidence

    init(
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        activityContext: CoachDayActivityContext,
        tomorrowContext: CoachTomorrowPlanContext?,
        actualLoad: CoachActualLoadSnapshot? = nil,
        recoveryContext: CoachRecoveryContext?,
        nutritionContext: CoachNutritionContext?,
        readiness: CoachReadinessStateV3
    ) {
        self.brain = brain
        self.dayContext = dayContext
        self.activityContext = activityContext
        self.tomorrowContext = tomorrowContext
        self.actualLoad = actualLoad ?? CoachActualLoadSnapshot.fallback(from: brain)
        self.recoveryContext = recoveryContext
        self.nutritionContext = nutritionContext
        self.readiness = readiness
        self.contextConfidence = CoachContextConfidence.resolve(
            brain: brain,
            recoveryContext: recoveryContext,
            actualLoad: self.actualLoad
        )
    }
}

extension CoachDecisionContext {
    var tomorrowDemand: CoachTomorrowDemandAssessment {
        CoachTomorrowDemandResolver.resolve(context: self)
    }
}

struct CoachContextConfidence: Hashable {
    let value: Double
    let sleepIsStable: Bool
    let recoveryIsStable: Bool
    let actualLoadIsStable: Bool
    let dayLevelIsAuthoritative: Bool

    var debugLines: [String] {
        [
            "ContextConfidence.value=\(String(format: "%.2f", value))",
            "ContextConfidence.sleepIsStable=\(sleepIsStable)",
            "ContextConfidence.recoveryIsStable=\(recoveryIsStable)",
            "ContextConfidence.actualLoadIsStable=\(actualLoadIsStable)",
            "ContextConfidence.dayLevelIsAuthoritative=\(dayLevelIsAuthoritative)"
        ]
    }

    static func resolve(
        brain: HumanBrain.State,
        recoveryContext: CoachRecoveryContext?,
        actualLoad: CoachActualLoadSnapshot
    ) -> CoachContextConfidence {
        let sleepHours = recoveryContext?.sleepHours ?? brain.metrics.sleepHours
        let sleepIsStable = sleepHours > 0 || brain.sleep != .unknown
        let recoveryIsStable = (recoveryContext?.recoveryPercent ?? 0) > 0
        let actualLoadIsStable = actualLoad.activeCalories > 0 ||
            actualLoad.exerciseMinutes != nil ||
            actualLoad.source == .healthKitSamplesWithAppGoalEstimate

        let value = [
            sleepIsStable ? 0.34 : 0,
            recoveryIsStable ? 0.46 : 0,
            actualLoadIsStable ? 0.20 : 0
        ].reduce(0, +)

        return CoachContextConfidence(
            value: value,
            sleepIsStable: sleepIsStable,
            recoveryIsStable: recoveryIsStable,
            actualLoadIsStable: actualLoadIsStable,
            dayLevelIsAuthoritative: value >= 0.75 && sleepIsStable && recoveryIsStable
        )
    }
}

enum CoachInsightCategory: String, Hashable {
    case planNextEvent = "plan_next_event"
    case protectTomorrow = "protect_tomorrow"
    case recoverNow = "recover_now"
    case dayComplete = "day_complete"
    case prepareForLaterToday = "prepare_for_later_today"
    case downgradeToday = "downgrade_today"
    case fuelBeforeTraining = "fuel_before_training"
    case refuelAfterTraining = "refuel_after_training"
    case hydrateNow = "hydrate_now"
    case sleepPriority = "sleep_priority"
    case missingSleepData = "missing_sleep_data"
    case noActionNeeded = "no_action_needed"
}

enum CoachLifecyclePhase: String, Hashable {
    case preventive
    case activeGuidance = "active_guidance"
    case wrapUp = "wrap_up"
    case nightMode = "night_mode"
    case nextDayPrep = "next_day_prep"
}

enum CoachSleepStatus: String, Hashable {
    case available
    case missing
    case syncing
    case stale
}

enum CoachActivityLoadClass: String, Hashable {
    case underTarget = "under_target"
    case normal
    case high
    case veryHigh = "very_high"
}

enum CoachNextImportantEvent: Hashable {
    case activeActivity(PlannedActivity)
    case plannedLaterToday(PlannedActivity)
    case plannedTomorrow(PlannedActivity)
    case nutritionGapToday
    case hydrationGapToday
    case sleepWindowTonight
    case none

    var debugDescription: String {
        switch self {
        case .activeActivity(let activity):
            return "active_activity:\(activity.title)"
        case .plannedLaterToday(let activity):
            return "planned_later_today:\(activity.title)"
        case .plannedTomorrow(let activity):
            return "planned_tomorrow:\(activity.title)"
        case .nutritionGapToday:
            return "nutrition_gap_today"
        case .hydrationGapToday:
            return "hydration_gap_today"
        case .sleepWindowTonight:
            return "sleep_window_tonight"
        case .none:
            return "none"
        }
    }
}

struct CoachContext {
    let currentDateTime: Date
    let now: Date
    let currentDayStart: Date
    let currentDayEnd: Date
    let completedActivities: [PlannedActivity]
    let activeActivity: PlannedActivity?
    let nextPlannedActivity: PlannedActivity?
    let laterPlannedActivities: [PlannedActivity]
    let tomorrowPlannedActivities: [PlannedActivity]
    let recoveryMetrics: CoachRecoveryContext?
    let hydrationProgress: Double
    let nutritionProgress: Double
    let timeOfDay: CoachNarrativeTimeOfDay
    let locale: Locale
    let plannedActivitiesToday: [PlannedActivity]
    let completedActivitiesToday: [PlannedActivity]
    let plannedActivitiesTomorrow: [PlannedActivity]
    let completedActivityMinutesToday: Int
    let activeCaloriesToday: Double
    let activityGoalCalories: Double
    let activityPercent: Double
    let workoutCountToday: Int
    let recent7DayTrainingLoad: Int
    let sleepStatus: CoachSleepStatus
    let sleepDuration: Double?
    let sleepScore: Int?
    let hrv: Double?
    let rhr: Double?
    let nutritionCaloriesConsumed: Double
    let nutritionCaloriesTarget: Double
    let proteinProgress: Double
    let carbsProgress: Double
    let fatProgress: Double
    let drinksConsumed: Double
    let drinksTarget: Double
    let lastCoachInsightId: String?
    let lastCoachInsightShownAt: Date?
    let lastCoachInsightCategory: CoachInsightCategory?
    let userCanStillActToday: Bool
    let nextImportantEvent: CoachNextImportantEvent
    let loadClass: CoachActivityLoadClass
}

struct CoachInsightAction: Hashable {
    let title: String
    let subtitle: String
    let type: CoachSupportActionTypeV3
}

struct CoachPipelineInsight: Hashable {
    let id: String
    let category: CoachInsightCategory
    let severity: CoachPriorityStrength
    let confidence: Double
    let lifecyclePhase: CoachLifecyclePhase
    let nextImportantEvent: CoachNextImportantEvent
    let title: String
    let shortSummary: String
    let coachRead: String
    let recommendation: String
    let caution: String
    let evidence: [String]
    let actions: [CoachInsightAction]
    let priority: CoachDayPriority
    let focus: CoachDayFocus
    let limiter: CoachLimiter
    let mode: CoachingMode
    let objective: CoachObjective
}

private struct CoachTrainingReadinessAssessment {
    let score: Double
    let threshold: Double
    let triggerReasons: [String]
    let selectedBecause: String

    var selected: Bool {
        score >= threshold
    }

    var strength: CoachPriorityStrength {
        CoachDayPriorityResolver.strength(for: score)
    }
}

enum CoachLifecycleDecisionPipeline {

    static func normalizedContext(from context: CoachDecisionContext) -> CoachContext {
        let calendar = Calendar.current
        let now = context.dayContext.now
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? now
        let activityGoal = context.actualLoad.activityGoalCalories ?? 450.0
        let activityPercent = context.actualLoad.activityProgress ?? (activityGoal > 0 ? context.actualLoad.activeCalories / activityGoal : 0)
        let sleepDuration = resolvedSleepDuration(context)
        let sleepStatus = resolvedSleepStatus(context, sleepDuration: sleepDuration)
        let plannedToday = context.dayContext.upcomingActivities.filter { !$0.isCompleted && !$0.isSkipped }
        let completedToday = context.dayContext.completedActivities + context.dayContext.partialActivities
        let plannedTomorrow = context.tomorrowContext?.dayContext.upcomingActivities.filter { !$0.isCompleted && !$0.isSkipped } ?? []
        let nutrition = context.nutritionContext
        let hydrationProgress = ratio(
            nutrition?.waterCurrent ?? context.brain.metrics.waterLiters,
            nutrition?.waterGoal ?? context.brain.fullDayGoals.waterLiters
        )
        let nutritionProgress = ratio(
            nutrition?.caloriesCurrent ?? context.brain.metrics.calories,
            nutrition?.caloriesGoal ?? context.brain.fullDayGoals.calories
        )
        let recentLoad = recent7DayTrainingLoad(in: context)
        let hour = resolvedHour(in: context)
        let canStillAct = hour < 22 && now < dayEnd.addingTimeInterval(-60 * 60)
        let loadClass = activityLoadClass(activityPercent: activityPercent)
        let nextEvent = nextImportantEvent(
            in: context,
            plannedToday: plannedToday,
            plannedTomorrow: plannedTomorrow,
            sleepStatus: sleepStatus,
            canStillAct: canStillAct
        )

        return CoachContext(
            currentDateTime: now,
            now: now,
            currentDayStart: dayStart,
            currentDayEnd: dayEnd,
            completedActivities: completedToday,
            activeActivity: context.activityContext.activeActivity,
            nextPlannedActivity: plannedToday.first,
            laterPlannedActivities: Array(plannedToday.dropFirst()),
            tomorrowPlannedActivities: plannedTomorrow,
            recoveryMetrics: context.recoveryContext,
            hydrationProgress: hydrationProgress,
            nutritionProgress: nutritionProgress,
            timeOfDay: normalizedTimeOfDay(now),
            locale: WeekFitCurrentLocale(),
            plannedActivitiesToday: plannedToday,
            completedActivitiesToday: completedToday,
            plannedActivitiesTomorrow: plannedTomorrow,
            completedActivityMinutesToday: context.dayContext.completedActivityVolumeMinutes,
            activeCaloriesToday: context.actualLoad.activeCalories,
            activityGoalCalories: activityGoal,
            activityPercent: activityPercent,
            workoutCountToday: context.dayContext.completedWorkoutsCount,
            recent7DayTrainingLoad: recentLoad,
            sleepStatus: sleepStatus,
            sleepDuration: sleepDuration,
            sleepScore: context.recoveryContext?.recoveryPercent,
            hrv: nil,
            rhr: nil,
            nutritionCaloriesConsumed: nutrition?.caloriesCurrent ?? context.brain.metrics.calories,
            nutritionCaloriesTarget: context.brain.baseDayGoals.calories,
            proteinProgress: ratio(nutrition?.proteinCurrent ?? context.brain.metrics.protein, context.brain.baseDayGoals.protein),
            carbsProgress: ratio(nutrition?.carbsCurrent ?? context.brain.metrics.carbs, context.brain.baseDayGoals.carbs),
            fatProgress: ratio(nutrition?.fatsCurrent ?? context.brain.metrics.fats, context.brain.baseDayGoals.fats),
            drinksConsumed: nutrition?.waterCurrent ?? context.brain.metrics.waterLiters,
            drinksTarget: nutrition?.waterGoal ?? context.brain.fullDayGoals.waterLiters,
            lastCoachInsightId: nil,
            lastCoachInsightShownAt: nil,
            lastCoachInsightCategory: nil,
            userCanStillActToday: canStillAct,
            nextImportantEvent: nextEvent,
            loadClass: loadClass
        )
    }

    static func insight(in context: CoachDecisionContext) -> CoachPipelineInsight? {
        let normalized = normalizedContext(from: context)
        let insight = selectInsight(context: context, normalized: normalized)
        log(context: normalized, insight: insight, original: context)
        return insight
    }
}

extension CoachLifecycleDecisionPipeline {

    static func priorityCandidate(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard let insight = insight(in: context) else { return nil }
        return priorityResult(from: insight)
    }

    static func priorityResult(from insight: CoachPipelineInsight) -> CoachDayPriorityResult {
        CoachDayPriorityResult(
            focus: insight.focus,
            level: insight.severity.level,
            reason: insight.coachRead,
            activity: activity(from: insight.nextImportantEvent),
            overridesTimingFocus: true,
            priority: insight.priority,
            strength: insight.severity,
            confidence: insight.confidence,
            mode: insight.mode,
            limiter: insight.limiter,
            messageFamily: messageFamily(for: insight.category),
            priorityScore: priorityScore(for: insight),
            insightScore: priorityScore(for: insight) + 12,
            uniquenessScore: uniquenessScore(for: insight),
            decisionScore: priorityScore(for: insight) + 8,
            todayTitle: insight.shortSummary,
            todayMessage: oneLineReason(for: insight),
            detailTitle: insight.title,
            detailMessage: insight.recommendation,
            supportBullets: insight.evidence + insight.actions.map(\.title),
            whyThisMatters: insight.evidence.joined(separator: " • "),
            reasons: insight.evidence + ["category=\(insight.category.rawValue)", "lifecycle=\(insight.lifecyclePhase.rawValue)"],
            planChallenge: nil,
            horizon: horizon(for: insight),
            objective: insight.objective,
            opportunity: opportunity(for: insight),
            interventionValue: interventionValue(for: insight),
            interventionCostNote: insight.caution,
            completionState: completionState(for: insight)
        )
    }
}

private extension CoachLifecycleDecisionPipeline {

    static func selectInsight(
        context: CoachDecisionContext,
        normalized c: CoachContext
    ) -> CoachPipelineInsight? {
        let hasHardTomorrow = context.tomorrowDemand.isHard
        let hardTomorrow = hasHardTomorrow ? context.tomorrowContext?.primaryTrainingActivity : nil
        let highLoad = c.loadClass == .high || c.loadClass == .veryHigh || context.dayContext.completedTrainingStressScore >= 4
        let veryHighLoad = c.loadClass == .veryHigh || c.completedActivityMinutesToday >= 150 || c.workoutCountToday >= 2
        let highRecentLoad = recentLoadNeedsCaution(context: context, c: c)
        let poorRecovery = recoveryIsPoor(context, sleepStatus: c.sleepStatus)
        let sleepUnavailable = c.sleepStatus != .available
        let late = !c.userCanStillActToday
        let hydrationRatio = ratio(c.drinksConsumed, c.drinksTarget)
        let calorieRatio = ratio(c.nutritionCaloriesConsumed, c.nutritionCaloriesTarget)
        let nutritionBehind = calorieRatio < 0.55 || c.proteinProgress < 0.45
        let hydrationBehind = hydrationRatio < 0.55
        let completedTraining = context.dayContext.hasMeaningfulLoadCompleted || c.workoutCountToday > 0
        let longEnduranceTomorrow = tomorrowLongEnduranceCandidate(in: context)

        if context.activityContext.activeActivity != nil ||
            context.activityContext.preparingActivity != nil ||
            context.activityContext.recentlyCompletedActivity != nil {
            return nil
        }

        if let later = context.dayContext.upcomingActivities.first(where: { isTraining($0) && $0.date >= c.now }) {
            let readiness = trainingReadinessAssessment(
                activity: later,
                context: context,
                c: c,
                highRecentLoad: highRecentLoad,
                poorRecovery: poorRecovery
            )
            logTrainingReadinessAssessment(
                readiness,
                activity: later,
                source: "CoachLifecycleDecisionPipeline.plannedLaterToday"
            )

            if readiness.selected {
                return makeDowngradeTodayInsight(
                    activity: later,
                    context: context,
                    c: c,
                    highRecentLoad: highRecentLoad,
                    readiness: readiness
                )
            }
            return nil
        }

        if let longEnduranceTomorrow,
           resolvedHour(in: context) >= 18 {
            logTomorrowLoadDebug(
                activity: longEnduranceTomorrow,
                selectedAsFutureLoadSignal: true,
                reason: completedTraining
                    ? "evening completed training load before long endurance session"
                    : "evening before long endurance session"
            )
            return makeProtectTomorrowInsight(tomorrow: longEnduranceTomorrow, context: context, c: c)
        }

        if let tomorrow = longEnduranceTomorrow {
            logTomorrowLoadDebug(
                activity: tomorrow,
                selectedAsFutureLoadSignal: false,
                reason: "not selected by legacy evening completed-load insight; V4 may still protect tomorrow from day priority demand"
            )
        }

        if highLoad && late {
            if hasHardTomorrow, let hardTomorrow {
                return makeRecoveryStartsNowInsight(tomorrow: hardTomorrow, context: context, c: c, sleepUnavailable: sleepUnavailable)
            }
            return makeDayCompleteInsight(context: context, c: c)
        }

        if highLoad && hasHardTomorrow, let hardTomorrow {
            return makeProtectTomorrowInsight(tomorrow: hardTomorrow, context: context, c: c)
        }

        if highLoad {
            return makeDayCompleteInsight(context: context, c: c)
        }

        if hasHardTomorrow, let hardTomorrow {
            return makePlanNextEventInsight(tomorrow: hardTomorrow, context: context, c: c)
        }

        if highRecentLoad && poorRecovery && highLoad {
            return makeRecoverNowInsight(context: context, c: c, highRecentLoad: true)
        }

        if completedTraining && nutritionBehind && c.userCanStillActToday && highLoad {
            return makeRefuelAfterTrainingInsight(context: context, c: c)
        }

        let hour = resolvedHour(in: context)
        let severeHydrationGap = hydrationRatio < 0.20 || context.brain.hydration == .depleted
        if hydrationBehind &&
            severeHydrationGap &&
            c.userCanStillActToday &&
            hour >= 12 &&
            hour < 21 &&
            context.dayContext.allActivities.isEmpty &&
            c.loadClass == .underTarget {
            return makeHydrateNowInsight(context: context, c: c, before: nil)
        }

        return nil
    }

    static func recentLoadNeedsCaution(
        context: CoachDecisionContext,
        c: CoachContext
    ) -> Bool {
        let recentLoadIsHigh = c.recent7DayTrainingLoad >= 7 || context.brain.past.hasHighActivityLoad
        guard recentLoadIsHigh else { return false }

        let sleepIsSupportive = c.sleepDuration.map { $0 >= 7.0 } ?? false
        let recoveryIsSupportive = (context.recoveryContext?.recoveryPercent).map { $0 >= 85 } ?? false
        let currentLoadIsNormal = c.loadClass == .underTarget || c.loadClass == .normal
        let noMeaningfulStressToday = context.dayContext.completedTrainingStressScore < 2 &&
            !context.dayContext.hasMeaningfulLoadCompleted

        if sleepIsSupportive && recoveryIsSupportive && currentLoadIsNormal && noMeaningfulStressToday {
            return false
        }

        return true
    }

    static func trainingReadinessAssessment(
        activity: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext,
        highRecentLoad: Bool,
        poorRecovery: Bool
    ) -> CoachTrainingReadinessAssessment {
        let threshold = 80.0
        var score = 0.0
        var reasons: [String] = []

        switch c.loadClass {
        case .veryHigh:
            score += 62
            reasons.append("current activity load is very high")
        case .high:
            score += 36
            reasons.append("current activity load is high")
        case .normal:
            break
        case .underTarget:
            break
        }

        if c.completedActivityMinutesToday >= 150 {
            score += 18
            reasons.append("150+ active minutes are already logged")
        }

        if c.workoutCountToday >= 2 {
            score += 18
            reasons.append("multiple workouts are already logged today")
        }

        if context.dayContext.completedTrainingStressScore >= 4 {
            score += 28
            reasons.append("completed training stress is high")
        } else if context.dayContext.completedTrainingStressScore >= 2 {
            score += 12
            reasons.append("completed training stress is moderate")
        }

        if poorRecovery {
            score += 36
            reasons.append("recovery or sleep is limiting readiness")
        }

        if highRecentLoad {
            score += 22
            reasons.append("recent 7-day load needs caution")
        }

        let activityLoad = CoachActivityContextResolverV3.load(for: activity)
        switch activityLoad {
        case .extreme:
            score += 24
            reasons.append("\(activity.title) is an extreme-load session")
        case .high:
            score += 16
            reasons.append("\(activity.title) is a high-load session")
        case .moderate:
            score += 8
            reasons.append("\(activity.title) is a moderate-load session")
        case .low:
            break
        }

        if let sleep = c.sleepDuration, sleep >= 7.0 {
            score -= 10
            reasons.append("sleep supports readiness")
        }

        if let recovery = context.recoveryContext?.recoveryPercent, recovery >= 85 {
            score -= 18
            reasons.append("recovery is strong")
        }

        score = max(0, score)

        let selectedBecause = score >= threshold
            ? "trainingReadinessScore crossed downgrade threshold"
            : "trainingReadinessScore stayed below downgrade threshold"

        return CoachTrainingReadinessAssessment(
            score: score,
            threshold: threshold,
            triggerReasons: reasons,
            selectedBecause: selectedBecause
        )
    }

    static func logTrainingReadinessAssessment(
        _ assessment: CoachTrainingReadinessAssessment,
        activity: PlannedActivity,
        source: String
    ) {
        CoachLogger.trace(
            "[CoachTrainingReadinessDebug]",
            """
            source=\(source) activity="\(activity.title)" trainingReadinessScore=\(String(format: "%.1f", assessment.score)) trainingReadinessThreshold=\(String(format: "%.1f", assessment.threshold)) selected=\(assessment.selected) selectedBecause="\(assessment.selectedBecause)" strength=\(assessment.strength) triggerReasons=\(assessment.triggerReasons)
            """
        )
    }

    static func makeActiveInsight(
        activity: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        let name = activityName(activity)
        return CoachPipelineInsight(
            id: "plan_next_event.active.\(activity.id)",
            category: .planNextEvent,
            severity: .high,
            confidence: confidence(base: 0.86, sleepStatus: c.sleepStatus),
            lifecyclePhase: .activeGuidance,
            nextImportantEvent: .activeActivity(activity),
            title: "Keep \(name) easy",
            shortSummary: "Keep it easy",
            coachRead: "\(capitalizedFirst(name)) is active now, so the useful guidance is execution, not a new plan.",
            recommendation: "Keep effort repeatable and finish with enough reserve that recovery can start as soon as the session ends.",
            caution: "Turning a live session into extra intensity because the day still has open targets.",
            evidence: baseEvidence(context: context, c: c) + ["\(capitalizedFirst(name)) is active now"],
            actions: [
                action("Keep effort easy", "Let breathing and form set the ceiling", .controlIntensity),
                action("Finish with reserve", "Leave enough capacity for recovery", .cooldown)
            ],
            priority: .activeSession,
            focus: .activeActivity,
            limiter: .timing,
            mode: .execution,
            objective: .executeActivity
        )
    }

    static func makePrepareLaterTodayInsight(
        activity: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        let name = activityName(activity)
        return CoachPipelineInsight(
            id: "prepare_for_later_today.\(activity.id)",
            category: .prepareForLaterToday,
            severity: .high,
            confidence: confidence(base: 0.88, sleepStatus: c.sleepStatus),
            lifecyclePhase: .activeGuidance,
            nextImportantEvent: .plannedLaterToday(activity),
            title: "Prepare for \(name)",
            shortSummary: "Prepare for \(name)",
            coachRead: "\(capitalizedFirst(name)) is still planned today, and current load is not asking for a downgrade.",
            recommendation: "Keep the next steps practical: arrive fueled, keep fluids steady, and start the session easy.",
            caution: "Adding unrelated activity before the planned work.",
            evidence: baseEvidence(context: context, c: c) + ["\(activity.title) is planned later today"],
            actions: [
                action("Start planned workout", "Use the first minutes to confirm readiness", .controlIntensity),
                action("Fuel before training", "Use an easy meal or snack if needed", .lightFueling),
                action("Sip to comfort", "Keep fluids steady before starting", .hydrateBeforeSession)
            ],
            priority: .performance,
            focus: .prepareForActivity,
            limiter: .timing,
            mode: .execution,
            objective: .prepareActivity
        )
    }

    static func makeDowngradeTodayInsight(
        activity: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext,
        highRecentLoad: Bool,
        readiness: CoachTrainingReadinessAssessment
    ) -> CoachPipelineInsight {
        let name = activityName(activity)
        let planAdjustment = remainingPlanExceedsAbsorption(context: context, c: c)
        let read = planAdjustment
            ? "You already accumulated enough stress today. The planned \(name) is no longer additive fitness; it is mostly additive fatigue."
            : (highRecentLoad && c.loadClass == .normal
                ? "Today looks normal by itself, but the recent 7-day load and recovery signals lower the ceiling for \(name)."
                : "Today's load is already high before \(name), so the plan needs a lower ceiling.")
        return CoachPipelineInsight(
            id: "downgrade_today.\(activity.id).\(c.loadClass.rawValue)",
            category: .downgradeToday,
            severity: readiness.strength,
            confidence: confidence(base: 0.84, sleepStatus: c.sleepStatus),
            lifecyclePhase: .preventive,
            nextImportantEvent: .plannedLaterToday(activity),
            title: planAdjustment ? "Adjust today's plan" : "Downgrade today",
            shortSummary: planAdjustment ? "Change the remaining plan" : "Lower today’s plan",
            coachRead: read,
            recommendation: planAdjustment
                ? "Remove the \(name), replace it with recovery work, or postpone it."
                : "Replace hard work with an easy recovery version, or skip it if warm-up feedback is flat.",
            caution: planAdjustment
                ? "Treating the remaining plan like it is still productive to absorb."
                : "Forcing intensity because it is on the calendar.",
            evidence: baseEvidence(context: context, c: c) +
                ["\(activity.title) is still planned today"] +
                readiness.triggerReasons +
                ["trainingReadinessScore=\(Int(readiness.score)) threshold=\(Int(readiness.threshold))"],
            actions: [
                planAdjustment
                    ? action("Remove the run", "Let recovery create the adaptation", .cooldown)
                    : action("Downgrade to recovery walk", "Keep it conversational and short", .lightRecoveryMovement),
                action("Replace with recovery", "Mobility, stretching, or easy walking", .lightRecoveryMovement),
                action("Hydrate and refuel", "Make the completed work recoverable", .rehydrateGradually)
            ],
            priority: .planChallenge,
            focus: .trainingReadinessWarning,
            limiter: highRecentLoad ? .accumulatedFatigue : .trainingReadiness,
            mode: .warning,
            objective: .buildReadiness
        )
    }

    static func remainingPlanExceedsAbsorption(context: CoachDecisionContext, c: CoachContext) -> Bool {
        let hydrationRatio = ratio(c.drinksConsumed, c.drinksTarget)
        let nutritionBehind = ratio(c.nutritionCaloriesConsumed, c.nutritionCaloriesTarget) < 0.45 ||
            c.proteinProgress < 0.45 ||
            c.carbsProgress < 0.35
        let hydrationBehind = hydrationRatio < 0.60 ||
            context.brain.hydration == .behind ||
            context.brain.hydration == .depleted
        let overloadedDay = c.loadClass == .veryHigh ||
            c.activityPercent >= 1.50 ||
            context.dayContext.completedTrainingStressScore >= 4 ||
            context.dayContext.dayRisk == .high
        let compromisedReadiness = context.brain.readiness == .low ||
            context.brain.recovery == .compromised ||
            (context.recoveryContext?.recoveryPercent ?? 100) < 55

        return overloadedDay &&
            compromisedReadiness &&
            (nutritionBehind || hydrationBehind) &&
            !context.dayContext.upcomingTrainingActivities.isEmpty
    }

    static func makeProtectTomorrowInsight(
        tomorrow: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        let phase: CoachLifecyclePhase = resolvedHour(in: context) >= 19 ? .wrapUp : .preventive
        let isLongEndurance = isLongEnduranceCycling(tomorrow)
        let enduranceLabel = enduranceActivityLabel(for: tomorrow)
        let durationText = durationHoursText(tomorrow.effectiveDurationMinutes)
        let title = isLongEndurance ? "Protect tomorrow's \(enduranceLabel)" : (phase == .wrapUp ? "Keep tonight easy" : "Protect tomorrow")
        return CoachPipelineInsight(
            id: "protect_tomorrow.\(phase.rawValue).\(tomorrow.id)",
            category: .protectTomorrow,
            severity: .high,
            confidence: confidence(base: 0.86, sleepStatus: c.sleepStatus),
            lifecyclePhase: phase,
            nextImportantEvent: .plannedTomorrow(tomorrow),
            title: title,
            shortSummary: "Ready for tomorrow",
            coachRead: isLongEndurance
                ? "Tomorrow has a long \(durationText)-hour \(enduranceLabel) planned, so tonight is part of the session setup."
                : "Today’s load is already above target, and tomorrow has \(activityName(tomorrow)) planned.",
            recommendation: isLongEndurance
                ? "Restore fluids, eat normally, and close the evening calmly so you can start tomorrow with reserve."
                : phase == .wrapUp
                ? "Keep the rest of the evening easy so tomorrow’s planned session has a better chance to feel productive."
                : "Avoid adding extra training today so tomorrow’s planned session stays productive.",
            caution: isLongEndurance
                ? "Do not add intensity tonight — it can take capacity away from tomorrow's \(enduranceLabel)."
                : "Using a strong day as a reason to add non-planned work.",
            evidence: isLongEndurance
                ? ["A long \(enduranceLabel) needs freshness, fluids, and energy before it starts. The evening before matters more than doing extra work today."]
                : baseEvidence(context: context, c: c) + ["Tomorrow has \(tomorrow.title) planned"],
            actions: isLongEndurance ? [
                action("Restore fluids", "Sip gradually instead of catching up at once", .steadyHydration),
                action("Eat normally", "A real meal is better than random snacking", .startRecoveryNutrition),
                action("Prepare tomorrow's \(enduranceLabel)", "Tomorrow's start depends on tonight", .sleepPriority)
            ] : [
                action("Skip extra training", "Keep the remaining load low", .cooldown),
                action("Keep evening easy", "Let recovery take over", .downshiftNervousSystem),
                action("Protect sleep", "Tonight sets up the next session", .sleepPriority)
            ],
            priority: .planChallenge,
            focus: .tomorrowPlanRisk,
            limiter: .upcomingTraining,
            mode: .adjustment,
            objective: .protectTomorrow
        )
    }

    static func makeRecoveryStartsNowInsight(
        tomorrow: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext,
        sleepUnavailable: Bool
    ) -> CoachPipelineInsight {
        let sleepLine = sleepUnavailable ? " Sleep data is still syncing, so this recommendation is based on training load until sleep sync completes." : ""
        return CoachPipelineInsight(
            id: "recover_now.night.\(tomorrow.id)",
            category: .recoverNow,
            severity: .high,
            confidence: confidence(base: sleepUnavailable ? 0.66 : 0.82, sleepStatus: c.sleepStatus),
            lifecyclePhase: .nightMode,
            nextImportantEvent: .sleepWindowTonight,
            title: "Recovery starts now",
            shortSummary: "Recovery starts now",
            coachRead: "Today’s training load is complete, and tomorrow has \(activityName(tomorrow)) planned.\(sleepLine)",
            recommendation: "The next useful action is sleep, not more activity.",
            caution: "Trying to protect tomorrow by doing more tonight.",
            evidence: baseEvidence(context: context, c: c) + ["No activities planned for the rest of today", "Tomorrow has \(tomorrow.title) planned"] + sleepEvidence(c),
            actions: [
                action("Protect sleep", "Make sleep the next performance action", .sleepPriority),
                action("Keep evening easy", "No extra training tonight", .downshiftNervousSystem),
                action("Log sleep when available", "Let Coach reassess when sync completes", .stayConsistent)
            ],
            priority: .recovery,
            focus: .eveningWindDown,
            limiter: .sleep,
            mode: .recovery,
            objective: .completeDay
        )
    }

    static func makeDayCompleteInsight(
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        CoachPipelineInsight(
            id: "day_complete.\(c.loadClass.rawValue)",
            category: .dayComplete,
            severity: c.loadClass == .veryHigh ? .high : .medium,
            confidence: confidence(base: 0.86, sleepStatus: c.sleepStatus),
            lifecyclePhase: c.userCanStillActToday ? .wrapUp : .nightMode,
            nextImportantEvent: c.userCanStillActToday ? .none : .sleepWindowTonight,
            title: "Day complete",
            shortSummary: "Day complete",
            coachRead: "You have already exceeded today’s activity target, and there are no more hard activities planned.",
            recommendation: "No extra work is needed tonight. Keep the rest of the day light and let recovery take over.",
            caution: "Chasing more activity after the useful work is already done.",
            evidence: baseEvidence(context: context, c: c) + ["No hard session planned tomorrow"],
            actions: [
                action("Mark day complete", "No extra work is needed", .stayConsistent),
                action("Keep evening easy", "Let recovery take over", .downshiftNervousSystem)
            ],
            priority: .stable,
            focus: .eveningWindDown,
            limiter: .accumulatedFatigue,
            mode: .reinforcement,
            objective: .completeDay
        )
    }

    static func makePlanNextEventInsight(
        tomorrow: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        CoachPipelineInsight(
            id: "plan_next_event.tomorrow.\(tomorrow.id)",
            category: .planNextEvent,
            severity: .medium,
            confidence: confidence(base: 0.80, sleepStatus: c.sleepStatus),
            lifecyclePhase: c.userCanStillActToday ? .nextDayPrep : .nightMode,
            nextImportantEvent: .plannedTomorrow(tomorrow),
            title: c.userCanStillActToday ? "Prepare for tomorrow" : "Recovery starts now",
            shortSummary: "Ready for tomorrow",
            coachRead: "Tomorrow has \(activityName(tomorrow)) planned, and today does not need extra load.",
            recommendation: c.userCanStillActToday
                ? "Set up the basics now: normal food, steady fluids, and no bonus training."
                : "The next useful action is sleep, not more activity.",
            caution: "Turning preparation into extra training.",
            evidence: baseEvidence(context: context, c: c) + ["Tomorrow has \(tomorrow.title) planned"],
            actions: [
                action("Prepare tomorrow’s basics", "Remove friction before morning", .stayConsistent),
                action("Keep evening easy", "No bonus training needed", .downshiftNervousSystem)
            ],
            priority: .stable,
            focus: .dailyOverview,
            limiter: .upcomingTraining,
            mode: .reinforcement,
            objective: .buildReadiness
        )
    }

    static func makeRecoverNowInsight(
        context: CoachDecisionContext,
        c: CoachContext,
        highRecentLoad: Bool
    ) -> CoachPipelineInsight {
        CoachPipelineInsight(
            id: "recover_now.recent_load",
            category: .recoverNow,
            severity: .high,
            confidence: confidence(base: 0.78, sleepStatus: c.sleepStatus),
            lifecyclePhase: c.userCanStillActToday ? .preventive : .wrapUp,
            nextImportantEvent: .none,
            title: "Let recovery lead",
            shortSummary: "Recovery leads",
            coachRead: highRecentLoad
                ? "Today looks normal, but the recent 7-day load is high enough that recovery should set the ceiling."
                : "Recovery signals are limiting what is useful today.",
            recommendation: "Keep intensity low and avoid adding work just to fill the day.",
            caution: "Treating a normal-looking day as a green light when accumulated load is high.",
            evidence: baseEvidence(context: context, c: c) + ["Recent 7-day load is elevated"],
            actions: [
                action("Keep effort easy", "Let recovery set the ceiling", .controlIntensity),
                action("Downgrade to recovery walk", "Use light movement only", .lightRecoveryMovement)
            ],
            priority: .recovery,
            focus: .recoveryNeeded,
            limiter: .accumulatedFatigue,
            mode: .recovery,
            objective: .recoveryDay
        )
    }

    static func makeFuelBeforeTrainingInsight(
        activity: PlannedActivity,
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        CoachPipelineInsight(
            id: "fuel_before_training.\(activity.id)",
            category: .fuelBeforeTraining,
            severity: .high,
            confidence: confidence(base: 0.82, sleepStatus: c.sleepStatus),
            lifecyclePhase: .activeGuidance,
            nextImportantEvent: .plannedLaterToday(activity),
            title: "Prepare for training",
            shortSummary: "Prepare for training",
            coachRead: "\(activity.title) is planned later today, and food is behind for that effort.",
            recommendation: "Add easy fuel before the session so the workout does not start under-supported.",
            caution: "Starting the planned session with low energy and trying to fix it during intensity.",
            evidence: baseEvidence(context: context, c: c) + ["Nutrition is behind before \(activity.title)"],
            actions: [
                action("Fuel before training", "Use easy carbs and some protein", .lightFueling),
                action("Start planned workout", "Start only after basics are covered", .controlIntensity)
            ],
            priority: .performance,
            focus: .prepareForActivity,
            limiter: .timing,
            mode: .warning,
            objective: .prepareActivity
        )
    }

    static func makeRefuelAfterTrainingInsight(
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        CoachPipelineInsight(
            id: "refuel_after_training",
            category: .refuelAfterTraining,
            severity: .medium,
            confidence: confidence(base: 0.78, sleepStatus: c.sleepStatus),
            lifecyclePhase: .wrapUp,
            nextImportantEvent: .nutritionGapToday,
            title: "Recover from training",
            shortSummary: "Recover from training",
            coachRead: "Training is already logged, and nutrition is still behind the recovery demand.",
            recommendation: "Use a normal meal or protein-forward snack. Keep it light late in the evening.",
            caution: "Skipping recovery food after the training signal is already in.",
            evidence: baseEvidence(context: context, c: c) + ["Calories or protein are behind after training"],
            actions: [
                action("Refuel with protein", "Use a normal meal or snack", .startRecoveryNutrition)
            ],
            priority: .recovery,
            focus: .postActivityRecovery,
            limiter: .recovery,
            mode: .recovery,
            objective: .recoverFromActivity
        )
    }

    static func makeHydrateNowInsight(
        context: CoachDecisionContext,
        c: CoachContext,
        before activity: PlannedActivity?
    ) -> CoachPipelineInsight {
        let late = resolvedHour(in: context) >= 20
        return CoachPipelineInsight(
            id: "hydrate_now.\(late ? "evening" : "day")",
            category: .hydrateNow,
            severity: activity == nil ? .medium : .high,
            confidence: confidence(base: 0.80, sleepStatus: c.sleepStatus),
            lifecyclePhase: activity == nil ? .preventive : .activeGuidance,
            nextImportantEvent: activity.map(CoachNextImportantEvent.plannedLaterToday) ?? .hydrationGapToday,
            title: activity.map { "Prepare for \(activityName($0).lowercased())" } ?? "Support readiness",
            shortSummary: activity == nil ? "Support readiness" : "Prepare for activity",
            coachRead: activity.map { "\($0.title) is planned later today, and drinks are behind." } ?? "Drinks are behind for this point of the day.",
            recommendation: late ? "Take a small drink if thirsty; do not force fluids close to sleep." : "Drink steadily now instead of trying to catch up late.",
            caution: "Over-correcting hydration so it disrupts sleep or replaces food.",
            evidence: baseEvidence(context: context, c: c) + ["Drinks are \(Int(ratio(c.drinksConsumed, c.drinksTarget) * 100))% of target"],
            actions: [
                action(late ? "Drink a small glass" : "Drink steadily", late ? "Only if thirsty before bed" : "Build intake gradually", .steadyHydration)
            ],
            priority: activity == nil ? .recovery : .performance,
            focus: activity == nil ? .recoveryNeeded : .prepareForActivity,
            limiter: activity == nil ? .recovery : .timing,
            mode: .warning,
            objective: activity == nil ? .buildReadiness : .prepareActivity
        )
    }

    static func makeLightMovementInsight(
        context: CoachDecisionContext,
        c: CoachContext
    ) -> CoachPipelineInsight {
        CoachPipelineInsight(
            id: "plan_next_event.light_movement",
            category: .planNextEvent,
            severity: .medium,
            confidence: confidence(base: 0.74, sleepStatus: c.sleepStatus),
            lifecyclePhase: .preventive,
            nextImportantEvent: .none,
            title: "Add light movement",
            shortSummary: "Light movement fits",
            coachRead: "No training is planned today or tomorrow, and activity is still under target.",
            recommendation: "If time allows, add an easy walk or mobility. Keep it light enough that it does not become a workout.",
            caution: "Turning a low-pressure movement day into intensity.",
            evidence: baseEvidence(context: context, c: c) + ["No activities planned today or tomorrow"],
            actions: [
                action("Add light movement", "Easy walk or mobility only", .lightRecoveryMovement)
            ],
            priority: .stable,
            focus: .dailyOverview,
            limiter: .none,
            mode: .opportunity,
            objective: .maintainCourse
        )
    }
}

private extension CoachLifecycleDecisionPipeline {

    static func resolvedSleepDuration(_ context: CoachDecisionContext) -> Double? {
        if context.brain.metrics.sleepHours > 0 { return context.brain.metrics.sleepHours }
        if let value = context.recoveryContext?.sleepHours, value > 0 { return value }
        return nil
    }

    static func resolvedSleepStatus(_ context: CoachDecisionContext, sleepDuration: Double?) -> CoachSleepStatus {
        if sleepDuration != nil, context.brain.sleep != .unknown {
            return .available
        }
        if sleepDuration != nil {
            return .stale
        }
        let hour = resolvedHour(in: context)
        if (4..<12).contains(hour) {
            return .syncing
        }
        return .missing
    }

    static func resolvedHour(in context: CoachDecisionContext) -> Int {
        let dayHour = Calendar.current.component(.hour, from: context.dayContext.now)
        if context.brain.currentHour != dayHour {
            return context.brain.currentHour
        }
        return dayHour
    }

    static func normalizedTimeOfDay(_ date: Date) -> CoachNarrativeTimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<23:
            return .evening
        default:
            return .night
        }
    }

    static func nextImportantEvent(
        in context: CoachDecisionContext,
        plannedToday: [PlannedActivity],
        plannedTomorrow: [PlannedActivity],
        sleepStatus: CoachSleepStatus,
        canStillAct: Bool
    ) -> CoachNextImportantEvent {
        if let active = context.activityContext.activeActivity {
            return .activeActivity(active)
        }
        if let later = plannedToday.first(where: { isTraining($0) }) {
            return .plannedLaterToday(later)
        }
        if let tomorrow = context.tomorrowDemand.primaryTrainingActivity, context.tomorrowDemand.isHard {
            return .plannedTomorrow(tomorrow)
        }
        if nutritionGap(context), canStillAct {
            return .nutritionGapToday
        }
        if hydrationGap(context), canStillAct {
            return .hydrationGapToday
        }
        if !canStillAct && (sleepStatus == .available || sleepStatus == .syncing || sleepStatus == .missing) {
            return .sleepWindowTonight
        }
        _ = plannedTomorrow
        return .none
    }

    static func recent7DayTrainingLoad(in context: CoachDecisionContext) -> Int {
        let start = context.dayContext.now.addingTimeInterval(-7 * 24 * 60 * 60)
        return context.brain.activities
            .filter { $0.isCompleted && $0.date >= start && $0.date <= context.dayContext.now }
            .filter(isTraining)
            .reduce(0) { partial, activity in
                partial + stressScore(activity)
            }
    }

    static func activityLoadClass(activityPercent: Double) -> CoachActivityLoadClass {
        if activityPercent < 0.60 { return .underTarget }
        if activityPercent <= 1.20 { return .normal }
        if activityPercent <= 1.70 { return .high }
        return .veryHigh
    }

    static func recoveryIsPoor(_ context: CoachDecisionContext, sleepStatus: CoachSleepStatus) -> Bool {
        if let recovery = context.recoveryContext?.recoveryPercent, recovery > 0, recovery < 60 {
            return true
        }
        if sleepStatus == .available, let sleep = resolvedSleepDuration(context), sleep < 6.0 {
            return true
        }
        return context.brain.recovery == .compromised || context.brain.readiness == .low
    }

    static func isTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        return kind == .workout || kind == .endurance
    }

    static func tomorrowLongEnduranceCandidate(in context: CoachDecisionContext) -> PlannedActivity? {
        context.tomorrowContext?.dayContext.upcomingActivities
            .filter { !$0.isSkipped }
            .filter(isLongEnduranceCycling)
            .max { $0.effectiveDurationMinutes < $1.effectiveDurationMinutes }
    }

    static func isLongEnduranceCycling(_ activity: PlannedActivity) -> Bool {
        guard activity.effectiveDurationMinutes >= 120 else { return false }
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = "\(activity.title) \(activity.type)".lowercased()
        return kind == .endurance ||
            text.contains("cycling") ||
            text.contains("cycl") ||
            text.contains("bike") ||
            text.contains("ride")
    }

    static func enduranceActivityLabel(for activity: PlannedActivity) -> String {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("run") || text.contains("running") {
            return "run"
        }
        if text.contains("cycling") ||
            text.contains("cycl") ||
            text.contains("bike") ||
            text.contains("ride") {
            return "ride"
        }
        return "endurance session"
    }

    static func durationHoursText(_ minutes: Int) -> String {
        guard minutes % 60 != 0 else {
            return "\(minutes / 60)"
        }
        return String(format: "%.1f", Double(minutes) / 60.0)
    }

    static func logTomorrowLoadDebug(
        activity: PlannedActivity,
        selectedAsFutureLoadSignal: Bool,
        reason: String
    ) {
        CoachLogger.verbose(
            "[TomorrowLoadDebug]",
            """
            TomorrowLoadDebug scope=legacyDayPriorityResolver tomorrowActivityTitle="\(activity.title)" tomorrowActivityType="\(activity.type)" durationMinutes=\(activity.effectiveDurationMinutes) isLongEndurance=\(isLongEnduranceCycling(activity)) selectedAsFutureLoadSignal=\(selectedAsFutureLoadSignal) reason="\(reason)"
            """
        )
    }

    static func stressScore(_ activity: PlannedActivity) -> Int {
        let load = CoachActivityContextResolverV3.load(for: activity)
        switch load {
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .extreme: return 4
        }
    }

    static func nutritionGap(_ context: CoachDecisionContext) -> Bool {
        guard let nutrition = context.nutritionContext else { return false }
        if let lastMealTime = nutrition.lastMealTime {
            let minutesSinceLastMeal = max(0, Int(context.dayContext.now.timeIntervalSince(lastMealTime) / 60))
            if minutesSinceLastMeal <= 120 {
                return false
            }
        }
        return ratio(nutrition.caloriesCurrent, context.brain.baseDayGoals.calories) < 0.45 ||
            ratio(nutrition.proteinCurrent, context.brain.baseDayGoals.protein) < 0.35
    }

    static func hydrationGap(_ context: CoachDecisionContext) -> Bool {
        guard let nutrition = context.nutritionContext else { return false }
        return ratio(nutrition.waterCurrent, nutrition.waterGoal) < 0.55
    }

    static func ratio(_ current: Double, _ target: Double) -> Double {
        guard target > 0 else { return 1 }
        return current / target
    }

    static func confidence(base: Double, sleepStatus: CoachSleepStatus) -> Double {
        switch sleepStatus {
        case .available:
            return min(base, 0.95)
        case .stale:
            return min(base - 0.08, 0.78)
        case .syncing, .missing:
            return min(base - 0.16, 0.70)
        }
    }

    static func baseEvidence(context: CoachDecisionContext, c: CoachContext) -> [String] {
        var evidence = [
            "Activity is \(Int(c.activityPercent * 100))% of daily goal",
            "\(c.completedActivityMinutesToday) active minutes logged today"
        ]
        if context.dayContext.upcomingTrainingActivities.isEmpty {
            evidence.append("No activities planned for the rest of today")
        }
        evidence.append(contentsOf: sleepEvidence(c))
        return evidence
    }

    static func sleepEvidence(_ c: CoachContext) -> [String] {
        switch c.sleepStatus {
        case .available:
            return c.sleepDuration.map { ["Sleep duration is \(String(format: "%.1f", $0))h"] } ?? []
        case .syncing:
            return ["Sleep data is still syncing"]
        case .missing:
            return ["Sleep data is missing"]
        case .stale:
            return ["Sleep data may be stale"]
        }
    }

    static func activityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.localizedCaseInsensitiveContains("strength") { return "strength session" }
        if title.localizedCaseInsensitiveContains("interval") { return "interval session" }
        if title.localizedCaseInsensitiveContains("long run") { return "long run" }
        if title.localizedCaseInsensitiveContains("run") { return "run" }
        if title.localizedCaseInsensitiveContains("ride") || title.localizedCaseInsensitiveContains("cycling") { return "ride" }
        if title.localizedCaseInsensitiveContains("tennis") { return "tennis" }
        if title.localizedCaseInsensitiveContains("squash") { return "squash" }
        return title.isEmpty ? "session" : title.lowercased()
    }

    static func capitalizedFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    static func action(_ title: String, _ subtitle: String, _ type: CoachSupportActionTypeV3) -> CoachInsightAction {
        CoachInsightAction(title: title, subtitle: subtitle, type: type)
    }

    static func activity(from event: CoachNextImportantEvent) -> PlannedActivity? {
        switch event {
        case .activeActivity(let activity), .plannedLaterToday(let activity), .plannedTomorrow(let activity):
            return activity
        case .nutritionGapToday, .hydrationGapToday, .sleepWindowTonight, .none:
            return nil
        }
    }

    static func messageFamily(for category: CoachInsightCategory) -> CoachMessageFamily {
        switch category {
        case .hydrateNow:
            return .recovery
        case .fuelBeforeTraining:
            return .performance
        case .refuelAfterTraining:
            return .recovery
        case .recoverNow, .dayComplete:
            return .recovery
        case .sleepPriority, .missingSleepData:
            return .sleep
        case .protectTomorrow, .downgradeToday:
            return .planAdjustment
        case .planNextEvent, .prepareForLaterToday, .noActionNeeded:
            return .performance
        }
    }

    static func priorityScore(for insight: CoachPipelineInsight) -> Double {
        switch insight.category {
        case .downgradeToday:
            switch insight.severity {
            case .critical:
                return 108
            case .high:
                return 92
            case .medium:
                return 68
            case .low:
                return 44
            }
        case .recoverNow, .sleepPriority: return 112
        case .protectTomorrow: return 108
        case .prepareForLaterToday, .fuelBeforeTraining: return 104
        case .dayComplete: return 98
        case .hydrateNow, .refuelAfterTraining: return 94
        case .planNextEvent: return 88
        case .missingSleepData, .noActionNeeded: return 70
        }
    }

    static func uniquenessScore(for insight: CoachPipelineInsight) -> Double {
        switch insight.lifecyclePhase {
        case .nightMode: return 120
        case .wrapUp: return 108
        case .activeGuidance: return 104
        case .nextDayPrep: return 96
        case .preventive: return 90
        }
    }

    static func oneLineReason(for insight: CoachPipelineInsight) -> String {
        if let evidence = insight.evidence.first {
            return evidence + "."
        }
        return insight.recommendation
    }

    static func horizon(for insight: CoachPipelineInsight) -> CoachHorizon {
        if insight.category == .protectTomorrow {
            return .tomorrow
        }
        if insight.category == .planNextEvent,
           case .plannedTomorrow = insight.nextImportantEvent {
            return .tomorrow
        }
        if insight.category == .recoverNow,
           insight.lifecyclePhase == .nightMode {
            return .tomorrow
        }
        return .today
    }

    static func opportunity(for insight: CoachPipelineInsight) -> CoachOpportunity {
        switch insight.category {
        case .prepareForLaterToday, .planNextEvent:
            return .trainingOpportunity
        case .dayComplete, .protectTomorrow:
            return .consistencyWin
        case .recoverNow:
            return .recoveryWindow
        default:
            return .none
        }
    }

    static func interventionValue(for insight: CoachPipelineInsight) -> CoachInterventionValue {
        switch insight.severity {
        case .critical:
            return .high
        case .high, .medium:
            return .useful
        case .low:
            return .low
        }
    }

    static func completionState(for insight: CoachPipelineInsight) -> CompletionState {
        switch insight.category {
        case .dayComplete, .noActionNeeded:
            return .complete
        case .recoverNow, .protectTomorrow:
            return .goodEnough
        default:
            return .incomplete
        }
    }

    static func log(context c: CoachContext, insight: CoachPipelineInsight?, original: CoachDecisionContext) {
        #if DEBUG
        let selected = insight.map { "\($0.category.rawValue)/\($0.lifecyclePhase.rawValue)" } ?? "none"
        let confidence = insight.map { String(format: "%.2f", $0.confidence) } ?? "nil"
        let actions = insight?.actions.map(\.title).joined(separator: ", ") ?? "none"
        let title = insight?.title ?? "none"
        let nutrition = "calories=\(Int(c.nutritionCaloriesConsumed))/\(Int(c.nutritionCaloriesTarget)) protein=\(Int(c.proteinProgress * 100))% carbs=\(Int(c.carbsProgress * 100))% fat=\(Int(c.fatProgress * 100))%"
        let drinks = "drinks=\(String(format: "%.1f", c.drinksConsumed))/\(String(format: "%.1f", c.drinksTarget))L"
        CoachRefreshDebug.log(
            "[CoachLifecyclePipeline]",
            """
            now=\(c.now) plannedActivitiesToday=\(c.plannedActivitiesToday.map(\.title)) plannedActivitiesTomorrow=\(c.plannedActivitiesTomorrow.map(\.title)) completedActivitiesToday=\(c.completedActivitiesToday.map(\.title)) activityPercent=\(String(format: "%.2f", c.activityPercent)) recent7DayTrainingLoad=\(c.recent7DayTrainingLoad) sleepStatus=\(c.sleepStatus.rawValue) nutrition={\(nutrition)} drinks={\(drinks)} selectedNextImportantEvent=\(c.nextImportantEvent.debugDescription) selectedCategoryPhase=\(selected) confidence=\(confidence) finalTitle="\(title)" finalActions=[\(actions)] previousDecision=replace reason="context recomputed from plan, load, sleep, nutrition, hydration, and actionability" rawRecovery=\(String(describing: original.recoveryContext?.recoveryPercent))
            """
        )
        #endif
    }
}

enum CoachDayPriorityResolver {

    #if DEBUG
    static var debugCandidateLoggingEnabled = false
    #endif

    private enum Thresholds {
        static let eveningHour = 18
        static let lateEveningHour = 21
        static let dayClosedHour = 23
        static let dayClosedMorningEndHour = 2
        static let veryHighActiveCalories = 1_500.0
        static let estimatedActivityGoalCalories = 450.0
        static let highLoadActivityProgress = 1.50
        static let highTrainingStressScore = 4
        static let veryLowSleepHours = 5.0
        static let lowRecoveryPercent = 55
        static let hydrationBehindHighLoadRatio = 0.55
        static let hydrationCompleteRatio = 1.0
        static let fuelBehindHardWorkoutRatio = 0.60
        static let hardWorkoutMinimumMinutes = 60
        static let preTrainingFuelingWindowMinutes = 240
        static let recentMealSuppressionMinutes = 120
        static let heatHydrationLeadMinutes = 90
    }

    enum LocalTimeBucket {
        case afternoon
        case evening
        case night
        case lateNight
    }

    static func localHour(in context: CoachDecisionContext) -> Int {
        Calendar.current.component(.hour, from: context.dayContext.now)
    }

    static func localTimeBucket(in context: CoachDecisionContext) -> LocalTimeBucket {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: context.dayContext.now)
        let hour = components.hour ?? localHour(in: context)
        let minute = components.minute ?? 0
        let minuteOfDay = hour * 60 + minute

        if minuteOfDay >= (23 * 60 + 30) || minuteOfDay < (2 * 60) {
            return .lateNight
        }
        if minuteOfDay >= (22 * 60) {
            return .night
        }
        if minuteOfDay >= (19 * 60) {
            return .evening
        }
        return .afternoon
    }

    private struct PriorityCandidate {
        let priorityScore: Double
        let insightScore: Double
        let uniquenessScore: Double
        let result: CoachDayPriorityResult

        var decisionScore: Double {
            (priorityScore * 0.58) + (insightScore * 0.32) + (uniquenessScore * 0.10)
        }

        init(
            priorityScore: Double,
            insightScore: Double,
            uniquenessScore: Double,
            result: CoachDayPriorityResult
        ) {
            self.priorityScore = priorityScore
            self.insightScore = insightScore
            self.uniquenessScore = uniquenessScore
            self.result = result.withScores(
                priorityScore: priorityScore,
                insightScore: insightScore,
                uniquenessScore: uniquenessScore,
                decisionScore: (priorityScore * 0.58) + (insightScore * 0.32) + (uniquenessScore * 0.10)
            )
        }
    }

    static func resolve(_ context: CoachDecisionContext) -> CoachDayPriorityResult {
        let intent = CoachIntentResolver.resolve(context)
        let decisionFrame = context.dayDecisionFrame
        let commonSenseMode = commonSenseMode(in: context, intent: intent)
        let objective = objective(in: context, mode: commonSenseMode)
        let candidates = [
            dayDecisionFrameCandidate(in: context, frame: decisionFrame),
            lifecycleCandidate(in: context),
            sequenceAwarePreparationCandidate(in: context),
            commonSenseCandidate(in: context, mode: commonSenseMode),
            activeExecutionCandidate(in: context),
            postActivityCandidate(in: context),
            recentQuickCompletionCandidate(in: context),
            activeMealCandidate(in: context),

            sameDayTrainingAdjustmentCandidate(in: context),
            trainingReadinessWarningCandidate(in: context),
            sleepPreparationCandidate(in: context),
            recoveryCandidate(in: context),
            stateBasedTrainingRecommendationCandidate(in: context),
            tomorrowAdjustmentCandidate(in: context),

            performanceReadinessCandidate(in: context),
            emptyDayEveningCandidate(in: context),
            dayManagementCandidate(in: context),
            highReadinessOpportunityCandidate(in: context),
            contextualFallbackCandidate(in: context),
            baselineCandidate(in: context)
        ].compactMap { $0 }

        let eligibleCandidates = candidatesForSelection(candidates, in: context, intent: intent)
        let selected = eligibleCandidates.max {
            if $0.decisionScore == $1.decisionScore {
                if $0.insightScore == $1.insightScore {
                    return $0.result.confidence < $1.result.confidence
                }
                return $0.insightScore < $1.insightScore
            }
            return $0.decisionScore < $1.decisionScore
        }?.result ?? .defaultOverview
        let result = selected.withActivity(
            resolvedOwnerActivity(for: selected, in: context)
        )
        if context.activityContext.activeActivity != nil,
           result.focus != .activeActivity {
            CoachLogger.verbose(
                "[CoachPriorityOwnershipError]",
                "Invalid coach ownership: active activity exists but selected focus is not activeActivity selectedFocus=\(result.focus) selectedPriority=\(result.priority)"
            )
            assertionFailure("Invalid coach ownership: active activity exists but selected focus is not activeActivity")
        }

        logCandidates(
            candidates,
            eligibleCandidates: eligibleCandidates,
            selected: result,
            mode: commonSenseMode,
            objective: objective,
            in: context
        )

        let supportSignals = supportSignals(in: context, intent: intent, selected: result)
        let supportedResult = result.withSupportBullets(
            mergedSupportBullets(
                primary: result.supportBullets,
                signals: supportSignals
            )
        )
        let hydratedResult = withCriticalHydrationContext(supportedResult, in: context)

        let reasonedResult = hydratedResult.withHumanStateReasoning(
            horizon: horizon(for: result, objective: objective, in: context),
            objective: objective,
            opportunity: opportunity(for: result, in: context),
            interventionValue: interventionValue(for: result, in: context),
            interventionCostNote: interventionCostNote(for: result, in: context),
            completionState: completionState(for: result, in: context)
        )

        let protectedResult = reasonedResult.withTomorrowProtection(
            tomorrowProtectionState(for: reasonedResult, in: context)
        )

        let limitedResult = protectedResult.withLimiter(
            dynamicPrimaryLimiter(for: protectedResult, in: context)
        )

        let contributorLines = decisionFrame.contributors
            .map { "contributor=\($0.rawValue)" }
            .filter { !limitedResult.reasons.contains($0) }
        let loadDebugLines = decisionFrame.loadSourceDebug.debugLines.filter { !limitedResult.reasons.contains($0) }
        let confidenceDebugLines = context.contextConfidence.debugLines.filter { !limitedResult.reasons.contains($0) }
        let reasoned = limitedResult.withReasons(limitedResult.reasons + contributorLines + loadDebugLines + confidenceDebugLines)
        return CoachLightRecoveryStableDayPolicy.normalizedPriorityResult(reasoned, context: context)
    }
}

enum CoachIntentResolver {

    static func resolve(_ context: CoachDecisionContext) -> CoachIntent {
        if context.activityContext.activeActivity != nil {
            return .liveGuidance
        }

        if context.activityContext.preparingActivity != nil {
            return .preparation
        }

        if context.activityContext.recentlyCompletedActivity != nil {
            return .postActivity
        }

        if CoachDayPriorityResolver.isSleepPreparationWindow(context) {
            return .sleepPreparation
        }

        if (5..<18).contains(CoachDayPriorityResolver.localHour(in: context)) {
            return .dayPlanning
        }

        return .idleNow
    }
}

private extension CoachDayPriorityResolver {

    private static func lifecycleCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard let result = CoachLifecycleDecisionPipeline.priorityCandidate(in: context) else {
            return nil
        }

        return PriorityCandidate(
            priorityScore: max(result.priorityScore, 100),
            insightScore: max(result.insightScore, 112),
            uniquenessScore: max(result.uniquenessScore, 104),
            result: result
        )
    }

    private static func dayDecisionFrameCandidate(
        in context: CoachDecisionContext,
        frame: CoachDayDecisionFrame
    ) -> PriorityCandidate? {
        guard frame.planStatus.requiresPlanChange || frame.planStatus == .complete else {
            return primarySessionProtectionCandidate(in: context, frame: frame)
        }

        let priority: CoachDayPriority
        let focus: CoachDayFocus
        let strength: CoachPriorityStrength
        let mode: CoachingMode
        let limiter: CoachLimiter
        let objective: CoachObjective
        let interventionValue: CoachInterventionValue

        if frame.primaryDriver == .tomorrowDemand {
            priority = .planChallenge
            focus = .tomorrowPlanRisk
            strength = .high
            mode = .adjustment
            objective = .protectTomorrow
            interventionValue = .high
        } else {
            switch frame.planStatus {
            case .cancel, .replace:
                priority = .planChallenge
                focus = .trainingReadinessWarning
                strength = .critical
                mode = .warning
                objective = .buildReadiness
                interventionValue = .high
            case .downgrade, .adjust:
                priority = .planChallenge
                focus = .trainingReadinessWarning
                strength = .high
                mode = .adjustment
                objective = .buildReadiness
                interventionValue = .high
            case .complete:
                if lightRecoveryOnlyDayWithoutIndependentDeficit(in: context) {
                    priority = .stable
                    focus = .dailyOverview
                    strength = .medium
                    mode = .reinforcement
                    objective = .completeDay
                    interventionValue = .none
                } else {
                    priority = .recovery
                    focus = .recoveryNeeded
                    strength = .high
                    mode = .recovery
                    objective = .recoverFromActivity
                    interventionValue = .useful
                }
            case .valid:
                return nil
            }
        }

        limiter = frame.planStatus == .complete &&
            lightRecoveryOnlyDayWithoutIndependentDeficit(in: context)
            ? .none
            : limiterForPrimaryDriver(frame.primaryDriver)

        let riskDebugLines = frame.remainingActivityRisk?.debugLines ?? []
        let loadDebugLines = frame.loadSourceDebug.debugLines
        let recoveryContributorDebug = CoachRecoveryContributorDebug.resolve(context: context)
        let recoveryContributorDebugLines = recoveryContributorDebug.debugLines
        let scoring = dayDecisionFrameScores(
            for: frame,
            recoveryContributorDebug: recoveryContributorDebug
        )
        let result = CoachDayPriorityResult(
            focus: focus,
            level: strength.level,
            reason: frame.primaryDriverText,
            activity: frame.primaryDriver == .tomorrowDemand
                ? context.tomorrowDemand.primaryTrainingActivity
                : frame.primarySession,
            overridesTimingFocus: true,
            priority: priority,
            strength: strength,
            confidence: dayDecisionFrameConfidence(
                for: frame,
                recoveryContributorDebug: recoveryContributorDebug
            ),
            mode: mode,
            limiter: limiter,
            messageFamily: priority == .planChallenge ? .planAdjustment : .recovery,
            priorityScore: scoring.priority,
            insightScore: scoring.insight,
            uniquenessScore: scoring.uniqueness,
            decisionScore: scoring.decision,
            todayTitle: frame.todayTitle,
            todayMessage: frame.todayMessage,
            detailTitle: frame.title,
            detailMessage: frame.coachMessage,
            supportBullets: frame.contributors.map(\.label),
            whyThisMatters: frame.whyText,
            reasons: [
                "dayDecisionFrame=selected",
                "dayType=\(frame.dayType.rawValue)",
                "primaryDriver=\(frame.primaryDriver.rawValue)",
                "planStatus=\(frame.planStatus.rawValue)",
                "recommendationIntent=\(frame.recommendationIntent.rawValue)",
                "narrativeFamily=\(dayDecisionFrameNarrativeFamily(for: frame))",
                "recommendationFamily=\(priority == .planChallenge ? CoachMessageFamily.planAdjustment : CoachMessageFamily.recovery)"
            ] + frame.contributors.map { "contributor=\($0.rawValue)" } + recoveryContributorDebugLines + loadDebugLines + riskDebugLines,
            planChallenge: frame.planStatusText,
            horizon: frame.primaryDriver == .tomorrowDemand ? .tomorrow : .today,
            objective: objective,
            opportunity: .recoveryWindow,
            interventionValue: interventionValue,
            interventionCostNote: "Treating the remaining plan like it still fits the day.",
            completionState: frame.planStatus == .complete ? .complete : .incomplete
        )

        let narrative = CoachNarrativeComposer.compose(
            CoachNarrativeComposer.context(
                frame: frame,
                priority: result,
                decisionContext: context
            )
        )
        let narrativeDebugLines = CoachNarrativeComposer
            .debugLines(for: narrative)
            .filter { !result.reasons.contains($0) }
        let debuggedResult = result.withReasons(result.reasons + narrativeDebugLines)

        return PriorityCandidate(
            priorityScore: debuggedResult.priorityScore,
            insightScore: debuggedResult.insightScore,
            uniquenessScore: debuggedResult.uniquenessScore,
            result: debuggedResult
        )
    }

    private static func primarySessionProtectionCandidate(
        in context: CoachDecisionContext,
        frame: CoachDayDecisionFrame
    ) -> PriorityCandidate? {
        guard frame.recommendationIntent == .protectPrimarySession,
              let primarySession = frame.primarySession else {
            return nil
        }

        let load = CoachActivityContextResolverV3.load(for: primarySession)
        let isKeySession =
            load == .high ||
            load == .extreme ||
            primarySession.effectiveDurationMinutes >= 90 ||
            context.dayContext.upcomingTrainingStressScore >= 3

        guard isKeySession else { return nil }

        let result = CoachDayPriorityResult(
            focus: .prepareForActivity,
            level: .important,
            reason: "The primary session is the key workload today.",
            activity: primarySession,
            overridesTimingFocus: true,
            priority: .performance,
            strength: .medium,
            confidence: 0.82,
            mode: .opportunity,
            limiter: .upcomingTraining,
            messageFamily: .performance,
            priorityScore: 96,
            insightScore: 108,
            uniquenessScore: 92,
            decisionScore: 110,
            todayTitle: "Prepare for \(displayName(primarySession))",
            todayMessage: "Keep the day pointed at the key session and bring fuel and hydration online.",
            detailTitle: "Prepare for \(displayName(primarySession))",
            detailMessage: "The remaining plan is valid. \(displayName(primarySession)) is the primary session, so the earlier part of the day should protect freshness.",
            supportBullets: ["Start with water", "Add carbs before the session", "Keep extra load out"],
            whyThisMatters: "A valid plan still needs the basics in place before the primary workload.",
            reasons: [
                "dayDecisionFrame=primarySessionProtection",
                "dayType=\(frame.dayType.rawValue)",
                "primaryDriver=\(frame.primaryDriver.rawValue)",
                "planStatus=\(frame.planStatus.rawValue)",
                "recommendationIntent=\(frame.recommendationIntent.rawValue)"
            ] + frame.contributors.map { "contributor=\($0.rawValue)" },
            planChallenge: nil,
            horizon: .today,
            objective: .prepareActivity,
            opportunity: .trainingOpportunity,
            interventionValue: .useful,
            interventionCostNote: "Letting the key session arrive without basics.",
            completionState: .incomplete
        )

        let narrative = CoachNarrativeComposer.compose(
            CoachNarrativeComposer.context(
                frame: frame,
                priority: result,
                decisionContext: context
            )
        )
        let narrativeDebugLines = CoachNarrativeComposer
            .debugLines(for: narrative)
            .filter { !result.reasons.contains($0) }
        let debuggedResult = result.withReasons(result.reasons + narrativeDebugLines)

        return PriorityCandidate(
            priorityScore: debuggedResult.priorityScore,
            insightScore: debuggedResult.insightScore,
            uniquenessScore: debuggedResult.uniquenessScore,
            result: debuggedResult
        )
    }

    private static func limiterForPrimaryDriver(_ driver: CoachPrimaryDriver) -> CoachLimiter {
        switch driver {
        case .poorSleep:
            return .sleep
        case .lowRecovery:
            return .recovery
        case .accumulatedFatigue, .overloadRisk, .excessiveLoad:
            return .accumulatedFatigue
        case .tomorrowDemand:
            return .upcomingTraining
        case .unsafeHeatStress:
            return .hydration
        case .illness, .injury:
            return .trainingReadiness
        case .none:
            return .none
        }
    }

    static func tomorrowProtectionState(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CoachTomorrowProtectionState {
        let hasTomorrowDemand = context.tomorrowDemand.hasDemand
        var reasons: [String] = []
        if isVeryLowSleep(context) || context.brain.sleep == .veryShort {
            reasons.append("short sleep")
            reasons.append("sleep debt")
        } else if context.brain.sleep == .short {
            reasons.append("short sleep")
        }

        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            if recovery.recoveryPercent < 45 {
                reasons.append("compromised recovery")
                reasons.append("low recovery score")
            } else if recovery.recoveryPercent < 60 {
                reasons.append("vulnerable recovery")
            }
        } else if context.brain.recovery == .compromised {
            reasons.append("compromised recovery")
            reasons.append("low recovery score")
        } else if context.brain.recovery == .vulnerable {
            reasons.append("vulnerable recovery")
        }

        if context.dayContext.completedActivities.contains(where: { CoachActivityContextResolverV3.kind(for: $0) == .heat }) {
            reasons.append("sauna completed")
            reasons.append("sauna impact")
        }

        if !context.dayContext.partialActivities.isEmpty {
            reasons.append("partial workout")
        }

        if isHighLoadDay(context) || context.dayContext.completedTrainingStressScore >= 4 {
            reasons.append("heavy training load")
        }

        if hasTomorrowDemand,
           (result.focus == .tomorrowPlanRisk || context.tomorrowDemand.isHard) {
            reasons.append("tomorrow training risk")
        }

        reasons = Array(NSOrderedSet(array: reasons).compactMap { $0 as? String })
        let recommended = hasTomorrowDemand &&
            !reasons.isEmpty &&
            (
                reasons.contains("short sleep") ||
                reasons.contains("compromised recovery") ||
                reasons.contains("sauna impact") ||
                reasons.contains("heavy training load") ||
                reasons.contains("tomorrow training risk")
            )

        let hour = localHour(in: context)
        let lateEvening = hour >= 22
        let severeRecovery = reasons.contains("compromised recovery") ||
            (reasons.contains("short sleep") && reasons.contains("sauna impact")) ||
            severeFatigueDominates(context)
        let active = hasTomorrowDemand &&
            recommended &&
            (
                result.objective == .protectTomorrow ||
                result.focus == .tomorrowPlanRisk ||
                lateEvening ||
                severeRecovery
            )

        let activeReason: String?
        if !active {
            activeReason = nil
        } else if lateEvening || result.focus == .eveningWindDown || result.objective == .protectTomorrow {
            activeReason = "late evening recovery window"
        } else if severeRecovery {
            activeReason = "severe recovery constraint"
        } else if result.focus == .tomorrowPlanRisk {
            activeReason = "tomorrow plan risk"
        } else {
            activeReason = "protect tomorrow objective"
        }

        return CoachTomorrowProtectionState(
            recommended: recommended,
            active: active,
            reasons: reasons,
            activeReason: activeReason
        )
    }

    static func dynamicPrimaryLimiter(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CoachLimiter {
        guard result.tomorrowProtection.active else {
            return result.limiter
        }

        let hour = max(localHour(in: context), context.brain.currentHour)
        guard hour >= 15 else {
            return result.limiter
        }

        let reasons = result.tomorrowProtection.reasons
        if hour >= 18, reasons.contains("partial workout") {
            return .accumulatedFatigue
        }

        if reasons.contains("compromised recovery") ||
            reasons.contains("low recovery score") ||
            reasons.contains("sauna impact") {
            return .recovery
        }

        return result.limiter
    }

    private static func candidatesForSelection(
        _ candidates: [PriorityCandidate],
        in context: CoachDecisionContext,
        intent: CoachIntent
    ) -> [PriorityCandidate] {
        if intent == .liveGuidance {
            let activeCandidates = candidates.filter { candidate in
                candidate.result.focus == .activeActivity
            }
            if !activeCandidates.isEmpty {
                return activeCandidates
            }
        }

        if context.activityContext.activeActivity == nil,
           localHour(in: context) >= 18,
           CoachLifecycleDecisionPipeline.tomorrowLongEnduranceCandidate(in: context) != nil {
            let futureLoadCandidates = candidates.filter { candidate in
                candidate.result.focus == .tomorrowPlanRisk
            }
            if !futureLoadCandidates.isEmpty {
                return futureLoadCandidates
            }
        }

        let dominantReadinessWarnings = candidates.filter {
            isDominantTrainingReadinessWarning($0, candidates: candidates)
        }
        if !dominantReadinessWarnings.isEmpty {
            return dominantReadinessWarnings
        }

        let dominantDayFrameCandidates = candidates.filter {
            isDominantDayDecisionFrameCandidate($0, in: context)
        }
        if !dominantDayFrameCandidates.isEmpty {
            return dominantDayFrameCandidates
        }

        switch intent {
        case .postActivity:
            let postCandidates = candidates.filter { candidate in
                candidate.result.focus == .postActivityRecovery ||
                    candidate.result.focus == .recoveryNeeded
            }
            if !postCandidates.isEmpty {
                return postCandidates
            }

        case .liveGuidance:
            let activeCandidates = candidates.filter { candidate in
                candidate.result.focus == .activeActivity
            }
            if !activeCandidates.isEmpty {
                return activeCandidates
            }

            let liveCandidates = candidates.filter { candidate in
                candidate.result.focus == .recoveryNeeded ||
                    candidate.result.focus == .trainingReadinessWarning
            }
            if !liveCandidates.isEmpty {
                return liveCandidates
            }

        case .sleepPreparation:
            let sleepCandidates = candidates.filter { candidate in
                candidate.result.focus == .eveningWindDown ||
                    candidate.result.focus == .tomorrowPlanRisk ||
                    candidate.result.focus == .recoveryNeeded
            }
            if !sleepCandidates.isEmpty {
                return sleepCandidates
            }

        case .idleNow:
            if isClosedNightBeforeMorning(context),
               context.activityContext.activeActivity == nil,
               context.activityContext.preparingActivity == nil {
                let overnightCandidates = candidates.filter { candidate in
                    candidate.result.focus == .eveningWindDown
                }
                if !overnightCandidates.isEmpty {
                    return overnightCandidates
                }
            }
            break

        case .preparation, .dayPlanning:
            break
        }

        let sequenceCandidates = candidates.filter { isSequenceAwarePreparation($0.result) }
        if !sequenceCandidates.isEmpty {
            return sequenceCandidates
        }

        let recoveryProtectedCandidates = candidatesWithHydrationLimitedByRecovery(candidates, in: context)

        guard let preparing = context.activityContext.preparingActivity,
              isTraining(preparing) else {
            return recoveryProtectedCandidates
        }

        let timingCandidates = recoveryProtectedCandidates.filter { candidate in
            candidate.result.activity?.id == preparing.id &&
                (
                    candidate.result.focus == .prepareForActivity ||
                    candidate.result.focus == .performanceReadiness
                )
        }

        guard !timingCandidates.isEmpty else {
            return recoveryProtectedCandidates
        }

        if hasHeatAheadToday(context),
           hydrationIsCriticallyBehind(context) {
            let hydrationCandidates = recoveryProtectedCandidates.filter { candidate in
                candidate.result.priority == .hydration &&
                    candidate.result.limiter == .hydration
            }
            if !hydrationCandidates.isEmpty {
                return hydrationCandidates
            }
        }

        if prepWindowHasCriticalLimiter(context) {
            return recoveryProtectedCandidates.filter { candidate in
                timingCandidates.contains { $0.result.focus == candidate.result.focus && $0.result.activity?.id == candidate.result.activity?.id } ||
                    isCriticalPrepOverride(candidate.result, in: context)
            }
        }

        return timingCandidates
    }

    private static func isCriticalTrainingReadinessWarning(_ result: CoachDayPriorityResult) -> Bool {
        result.focus == .trainingReadinessWarning &&
            result.priority == .planChallenge &&
            result.strength == .critical
    }

    private static func isDominantDayDecisionFrameCandidate(
        _ candidate: PriorityCandidate,
        in context: CoachDecisionContext
    ) -> Bool {
        let result = candidate.result
        guard result.reasons.contains("dayDecisionFrame=selected") else {
            return false
        }

        let frame = context.dayDecisionFrame
        let overloadStory = frame.dayType == .overload ||
            frame.primaryDriver == .lowRecovery ||
            frame.primaryDriver == .accumulatedFatigue ||
            frame.primaryDriver == .overloadRisk ||
            frame.primaryDriver == .excessiveLoad

        guard overloadStory else {
            return false
        }

        return result.priority == .recovery ||
            result.priority == .planChallenge ||
            result.focus == .recoveryNeeded ||
            result.focus == .trainingReadinessWarning
    }

    private static func dayDecisionFrameNarrativeFamily(for frame: CoachDayDecisionFrame) -> String {
        if frame.dayType == .overload ||
            frame.primaryDriver == .lowRecovery ||
            frame.primaryDriver == .accumulatedFatigue ||
            frame.primaryDriver == .overloadRisk ||
            frame.primaryDriver == .excessiveLoad {
            return "recovery"
        }

        if frame.primaryDriver == .tomorrowDemand {
            return "protection"
        }

        switch frame.recommendationIntent {
        case .protectPrimarySession, .prepareForSession, .executeActiveSession:
            return "performance"
        case .recoverNow:
            return "recovery"
        case .modifyRemainingPlan:
            return "planAdjustment"
        case .protectTomorrow:
            return "protection"
        case .continuePlan:
            return "stable"
        }
    }

    private static func dayDecisionFrameScores(
        for frame: CoachDayDecisionFrame,
        recoveryContributorDebug: CoachRecoveryContributorDebug
    ) -> (priority: Double, insight: Double, uniqueness: Double, decision: Double) {
        let recoveryDominant =
            frame.dayType == .overload ||
            frame.primaryDriver == .lowRecovery ||
            frame.primaryDriver == .accumulatedFatigue ||
            frame.primaryDriver == .overloadRisk ||
            frame.primaryDriver == .excessiveLoad
        let activeRecoveryContributorCount = recoveryContributorDebug.activeContributors.count
        let resolvedRecoveryContributorCount = recoveryContributorDebug.resolvedContributors.count
        let contributorScoreAdjustment = Double(activeRecoveryContributorCount) * 1.4 -
            Double(resolvedRecoveryContributorCount) * 0.8

        if frame.planStatus == .complete {
            if recoveryDominant {
                return (
                    116 + contributorScoreAdjustment,
                    124 + contributorScoreAdjustment,
                    122 + contributorScoreAdjustment,
                    119 + contributorScoreAdjustment
                )
            }
            return (
                94 + contributorScoreAdjustment,
                100 + contributorScoreAdjustment,
                110 + contributorScoreAdjustment,
                97.5 + contributorScoreAdjustment
            )
        }

        if frame.planStatus.requiresPlanChange {
            if recoveryDominant {
                return (
                    138 + contributorScoreAdjustment,
                    144 + contributorScoreAdjustment,
                    128 + contributorScoreAdjustment,
                    139 + contributorScoreAdjustment
                )
            }
            return (
                130 + contributorScoreAdjustment,
                134 + contributorScoreAdjustment,
                110 + contributorScoreAdjustment,
                129.3 + contributorScoreAdjustment
            )
        }

        return (96, 108, 92, 99.4)
    }

    private static func dayDecisionFrameConfidence(
        for frame: CoachDayDecisionFrame,
        recoveryContributorDebug: CoachRecoveryContributorDebug
    ) -> Double {
        let base = frame.planStatus == .complete ? 0.78 : 0.90
        let resolvedAdjustment = Double(recoveryContributorDebug.resolvedContributors.count) * 0.02
        return max(0.70, base - resolvedAdjustment)
    }

    private static func isDominantTrainingReadinessWarning(
        _ candidate: PriorityCandidate,
        candidates: [PriorityCandidate]
    ) -> Bool {
        let result = candidate.result
        guard result.focus == .trainingReadinessWarning,
              result.priority == .planChallenge else {
            return false
        }

        if result.strength == .critical {
            return true
        }

        let bestPreparationScore = candidates
            .filter {
                $0.result.focus == .prepareForActivity ||
                    $0.result.focus == .performanceReadiness
            }
            .map(\.decisionScore)
            .max() ?? 0

        return candidate.decisionScore >= bestPreparationScore &&
            (result.strength == .high || result.level >= .important)
    }

    private static func resolvedOwnerActivity(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> PlannedActivity? {
        if let active = context.activityContext.activeActivity {
            return active
        }

        if let preparing = context.activityContext.preparingActivity,
           isTraining(preparing) || isHeatHydrationStory(result) {
            return preparing
        }

        if let recentTraining = recentCompletedTrainingOwner(in: context),
           ownsRecentCompletedActivity(result, recent: recentTraining, in: context) {
            return recentTraining
        }

        if let recent = context.activityContext.recentlyCompletedActivity,
           ownsRecentCompletedActivity(result, recent: recent, in: context) {
            return recent
        }

        if let storyActivity = nextStoryActivity(for: result, in: context) {
            return storyActivity
        }

        if let preparing = context.activityContext.preparingActivity {
            return preparing
        }

        return mostRecentCompletedOwner(in: context)
    }

    private static func ownsRecentCompletedActivity(
        _ result: CoachDayPriorityResult,
        recent: PlannedActivity,
        in context: CoachDecisionContext
    ) -> Bool {
        guard isMeaningfulPostActivityTraining(recent) else { return false }

        switch result.focus {
        case .postActivityRecovery, .recoveryNeeded:
            return true
        case .eveningWindDown:
            return result.priority == .recovery || result.priority == .sleepPreparation
        default:
            return !hasMeaningfulTrainingRemaining(context) &&
                result.priority != .hydration &&
                result.priority != .fueling
        }
    }

    private static func nextStoryActivity(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> PlannedActivity? {
        if let selected = result.activity,
           !selected.isCompleted,
           !selected.isSkipped,
           selected.date >= context.dayContext.now {
            return selected
        }

        if isTrainingStory(result) {
            return nextTrainingOwner(in: context) ??
                nextFutureOwner(in: context, matching: isTraining)
        }

        if isHeatHydrationStory(result) {
            return heatHydrationActivity(in: context) ??
                nextRecoveryOrHeatOwner(in: context)
        }

        if isRecoveryStory(result, in: context) {
            return nextRecoveryOrHeatOwner(in: context) ??
                nextTrainingOwner(in: context)
        }

        if result.priority == .fueling {
            return hardFuelingActivity(in: context, maximumLeadTimeMinutes: nil) ??
                nextTrainingOwner(in: context) ??
                nextFutureOwner(in: context)
        }

        return nextFutureOwner(in: context)
    }

    private static func isTrainingStory(_ result: CoachDayPriorityResult) -> Bool {
        switch result.priority {
        case .activeSession, .performance, .planChallenge:
            return true
        case .fueling:
            return result.focus == .fuelBehind
        case .recovery, .sleepPreparation, .hydration, .stable:
            break
        }

        switch result.focus {
        case .activeActivity, .prepareForActivity, .performanceReadiness, .trainingReadinessWarning, .tomorrowPlanRisk, .nextActivityLater:
            return true
        case .postActivityRecovery, .hydrationBehind, .fuelBehind, .recoveryNeeded, .dailyOverview, .eveningWindDown:
            return false
        }
    }

    private static func isRecoveryStory(
        _ result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> Bool {
        if result.priority == .recovery || result.priority == .sleepPreparation {
            return true
        }

        if result.focus == .recoveryNeeded ||
            result.focus == .postActivityRecovery ||
            result.messageFamily == .recovery ||
            result.messageFamily == .sleep {
            return true
        }

        return context.dayContext.dayType == .recovery ||
            nextRecoveryOrHeatOwner(in: context) != nil && !hasMeaningfulTrainingRemaining(context)
    }

    private static func candidatesWithHydrationLimitedByRecovery(
        _ candidates: [PriorityCandidate],
        in context: CoachDecisionContext
    ) -> [PriorityCandidate] {
        let recoveryNarrativeActive = candidates.contains {
            isRecoveryStory($0.result, in: context)
        }
        let recoveryShouldLead =
            sleepIsUnderSixHours(context) ||
            context.brain.readiness == .low ||
            context.brain.readiness == .compromised ||
            recoveryNarrativeActive

        guard recoveryShouldLead,
              !hydrationCanLeadAsPrimary(in: context) else {
            return candidates
        }

        let filtered = candidates.filter { candidate in
            !isHydrationPrimaryStory(candidate.result)
        }

        return filtered.isEmpty ? candidates : filtered
    }

    private static func isHydrationPrimaryStory(_ result: CoachDayPriorityResult) -> Bool {
        result.priority == .hydration ||
            result.focus == .hydrationBehind ||
            result.limiter == .hydration ||
            result.messageFamily == .hydration
    }

    private static func sleepIsUnderSixHours(_ context: CoachDecisionContext) -> Bool {
        if let hours = sleepHours(context) {
            return hours < 6.0
        }

        return context.brain.sleep == .veryShort
    }

    private static func isHeatHydrationStory(_ result: CoachDayPriorityResult) -> Bool {
        result.priority == .hydration &&
            result.limiter == .hydration &&
            result.activity.map { CoachActivityContextResolverV3.kind(for: $0) == .heat } == true
    }

    private static func nextTrainingOwner(in context: CoachDecisionContext) -> PlannedActivity? {
        context.dayContext.upcomingTrainingActivities
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= context.dayContext.now }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func recentCompletedTrainingOwner(in context: CoachDecisionContext) -> PlannedActivity? {
        context.dayContext.completedTrainingActivities
            .filter { activity in
                guard isMeaningfulPostActivityTraining(activity) else { return false }
                let end = activityEnd(activity)
                let minutesSinceEnd = Int(context.dayContext.now.timeIntervalSince(end) / 60)
                guard minutesSinceEnd >= 0 else { return false }
                return minutesSinceEnd <= CoachDayActivityContextResolver.recoveryHoldMinutes(
                    for: activity,
                    brain: context.brain
                )
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    private static func nextRecoveryOrHeatOwner(in context: CoachDecisionContext) -> PlannedActivity? {
        nextFutureOwner(in: context) { activity in
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .recovery || kind == .heat
        }
    }

    private static func nextFutureOwner(
        in context: CoachDecisionContext,
        matching matches: (PlannedActivity) -> Bool = { _ in true }
    ) -> PlannedActivity? {
        context.dayContext.upcomingActivities
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= context.dayContext.now }
            .filter(matches)
            .sorted { $0.date < $1.date }
            .first
    }

    private static func mostRecentCompletedOwner(in context: CoachDecisionContext) -> PlannedActivity? {
        context.dayContext.completedActivities
            .filter { !$0.isSkipped }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func prepWindowHasCriticalLimiter(_ context: CoachDecisionContext) -> Bool {
        isVeryLowSleep(context) ||
            veryLowRecovery(context) ||
            hydrationIsCriticallyBehind(context) ||
            fuelIsCriticallyBehind(context)
    }

    private static func isCriticalPrepOverride(
        _ result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> Bool {
        switch result.limiter {
        case .sleep:
            return isVeryLowSleep(context)
        case .recovery:
            return veryLowRecovery(context)
        case .hydration:
            return hydrationIsCriticallyBehind(context)
        case .fueling:
            return fuelIsCriticallyBehind(context)
        case .trainingReadiness:
            return veryLowRecovery(context) || isVeryLowSleep(context)
        case .upcomingTraining, .excessivePlannedLoad:
            return result.priority == .planChallenge && (veryLowRecovery(context) || isVeryLowSleep(context))
        case .accumulatedFatigue, .insufficientRecoveryTime, .timing, .none:
            return result.strength == .critical && (veryLowRecovery(context) || isVeryLowSleep(context))
        }
    }

    private static func isSequenceAwarePreparation(_ result: CoachDayPriorityResult) -> Bool {
        result.focus == .nextActivityLater &&
            result.reason.localizedCaseInsensitiveContains("earlier planned event")
    }

    #if DEBUG
    private static func logCandidates(
        _ candidates: [PriorityCandidate],
        eligibleCandidates: [PriorityCandidate],
        selected: CoachDayPriorityResult,
        mode: CoachCommonSenseMode,
        objective: CoachObjective,
        in context: CoachDecisionContext
    ) {
        guard debugCandidateLoggingEnabled ||
                ProcessInfo.processInfo.environment["WEEKFIT_COACH_PRIORITY_DEBUG"] == "1" else {
            return
        }

        let selectionOverride = selectionOverrideSummary(
            candidates: candidates,
            eligibleCandidates: eligibleCandidates,
            selected: selected,
            context: context
        )
        let header = """
        [CoachDayPriorityResolver] mode=\(mode) \
        phase=\(context.activityContext.phase.debugSummary) \
        selected=\(selected.priority)/\(selected.focus) decision=\(String(format: "%.1f", selected.decisionScore)) \
        \(selectionOverride) \
        prepCritical=\(prepWindowHasCriticalLimiter(context)) \
        waterCurrent=\(String(format: "%.2f", context.nutritionContext?.waterCurrent ?? -1.0)) \
        waterGoal=\(String(format: "%.2f", context.nutritionContext?.waterGoal ?? -1.0)) \
        hydrationRatio=\(String(format: "%.2f", hydrationRatio(context))) \
        \(nutritionDebugSummary(in: context))
        """
        CoachLogger.verbose("[CoachPriorityDebug]", header)
        CoachLogger.verbose("[CoachPriorityDebug]", candidateScoreSummary(candidates, label: "allCandidates"))
        if eligibleCandidates.count != candidates.count {
            CoachLogger.verbose("[CoachPriorityDebug]", candidateScoreSummary(eligibleCandidates, label: "eligibleForSelection"))
        }
        CoachLogger.verbose("[CoachFatigueDebug]", fatigueDiagnosticsSummary(candidates, selected: selected, in: context))

        for candidate in candidates.sorted(by: { $0.decisionScore > $1.decisionScore }) {
            let result = candidate.result
            let selectedMarker = result.priority == selected.priority &&
                result.focus == selected.focus &&
                result.activity?.id == selected.activity?.id
            CoachLogger.verbose("[CoachDayPriorityCandidate]", """
            [CoachDayPriorityCandidate]\(selectedMarker ? " selected=true" : "") \
            priority=\(result.priority) focus=\(result.focus) title="\(result.title)" todayTitle="\(result.todayTitle)" \
            priorityScore=\(String(format: "%.1f", result.priorityScore)) insightScore=\(String(format: "%.1f", result.insightScore)) uniquenessScore=\(String(format: "%.1f", result.uniquenessScore)) decisionScore=\(String(format: "%.1f", result.decisionScore)) \
            confidence=\(String(format: "%.2f", result.confidence)) strength=\(result.strength) critical=\(result.strength == .critical) \
            limiter=\(result.limiter) objective=\(result.objective) mode=\(result.mode) horizon=\(result.horizon) \
            activity=\(result.activity?.title ?? "nil") override=\(result.overridesTimingFocus) \
            reasons=\(result.reasons.isEmpty ? [result.reason] : result.reasons)
            """)
        }
    }

    private static func selectionOverrideSummary(
        candidates: [PriorityCandidate],
        eligibleCandidates: [PriorityCandidate],
        selected: CoachDayPriorityResult,
        context: CoachDecisionContext
    ) -> String {
        if let readiness = eligibleCandidates.first(where: { isCriticalTrainingReadinessWarning($0.result) }) {
            let excluded = excludedCandidateSummary(
                candidates: candidates,
                eligibleCandidates: eligibleCandidates,
                selected: selected,
                fallbackReason: "critical training readiness warning overrides normal preparation"
            )
            return """
            priorityOverrideRule=criticalTrainingReadinessWarning \
            selectedCandidate=\(candidateDebugSummary(readiness.result)) \
            selectedReason="critical readiness warning crossed threshold" \
            \(excluded)
            """
        }

        guard eligibleCandidates.count != candidates.count else {
            return "priorityOverrideRule=none"
        }

        guard let preparing = context.activityContext.preparingActivity,
              isTraining(preparing) else {
            return "priorityOverrideRule=filteredSelection"
        }

        let eligibleIsPreparation = eligibleCandidates.contains { candidate in
            candidate.result.activity?.id == preparing.id &&
                (
                    candidate.result.focus == .prepareForActivity ||
                    candidate.result.focus == .performanceReadiness
                )
        }

        guard eligibleIsPreparation else {
            return "priorityOverrideRule=filteredSelection"
        }

        let minutes = minutesUntil(preparing, in: context)
        let reason = minutes.map { "\(displayName(preparing)) starts in \($0) minutes" } ??
            "\(displayName(preparing)) is inside the preparation window"
        let stableExcluded = candidates.contains { $0.result.priority == .stable } &&
            !eligibleCandidates.contains { $0.result.priority == .stable }
        let critical = prepWindowHasCriticalLimiter(context)

        let excluded = excludedCandidateSummary(
            candidates: candidates,
            eligibleCandidates: eligibleCandidates,
            selected: selected,
            fallbackReason: "preparation window filtered non-preparation candidates"
        )
        return """
        priorityOverrideRule=preparationWindow reason="\(reason)" stableExcluded=\(stableExcluded) criticalLimiterAllowed=\(critical) \
        selectedCandidate=\(candidateDebugSummary(selected)) selectedReason="preparation window owns normal prep guidance" \
        \(excluded)
        """
    }

    private static func excludedCandidateSummary(
        candidates: [PriorityCandidate],
        eligibleCandidates: [PriorityCandidate],
        selected: CoachDayPriorityResult,
        fallbackReason: String
    ) -> String {
        let excluded = candidates
            .filter { candidate in
                !eligibleCandidates.contains { eligible in
                    eligible.result.focus == candidate.result.focus &&
                        eligible.result.priority == candidate.result.priority &&
                        eligible.result.activity?.id == candidate.result.activity?.id
                }
            }
            .filter { $0.result.decisionScore > selected.decisionScore }
            .sorted { $0.result.decisionScore > $1.result.decisionScore }
            .first

        guard let excluded else {
            return "excludedCandidate=nil excludedReason=nil"
        }

        return """
        excludedCandidate=\(candidateDebugSummary(excluded.result)) \
        excludedReason="\(fallbackReason)" \
        selectedCandidate=\(candidateDebugSummary(selected)) \
        selectedReason="eligible candidate selected after priority override"
        """
    }

    private static func candidateDebugSummary(_ result: CoachDayPriorityResult) -> String {
        "\"\(result.priority)/\(result.focus) title=\\\"\(result.title)\\\" decision=\(String(format: "%.1f", result.decisionScore)) strength=\(result.strength) limiter=\(result.limiter)\""
    }

    private static func candidateScoreSummary(_ candidates: [PriorityCandidate], label: String) -> String {
        func bestScore(where matches: (CoachDayPriorityResult) -> Bool) -> String {
            let score = candidates
                .filter { matches($0.result) }
                .map(\.decisionScore)
                .max()
            return score.map { String(format: "%.1f", $0) } ?? "nil"
        }

        return """
        [CoachPriorityCandidateScores \(label)] \
        fueling=\(bestScore { $0.priority == .fueling }) \
        hydration=\(bestScore { $0.priority == .hydration }) \
        recovery=\(bestScore { $0.priority == .recovery }) \
        sleep=\(bestScore { $0.priority == .sleepPreparation || $0.limiter == .sleep }) \
        activity=\(bestScore { $0.priority == .activeSession || $0.priority == .performance || $0.focus == .prepareForActivity }) \
        stable=\(bestScore { $0.priority == .stable })
        """
    }

    private static func fatigueDiagnosticsSummary(
        _ candidates: [PriorityCandidate],
        selected: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> String {
        let recent7DayLoad = CoachLifecycleDecisionPipeline.recent7DayTrainingLoad(in: context)
        let dayTrainingStress = context.dayContext.completedTrainingStressScore
        let activeLoadProgress = activityProgress(context)
        let activeCalories = context.actualLoad.activeCalories
        let recovery = recoveryPercent(context)
        let sleep = sleepHours(context)
        let sleepSupportsRecovery = sleep.map { $0 >= 7.0 } ?? true
        let strongRecoverySignal = strongRecovery(in: context) && sleepSupportsRecovery
        let recentLoadFlag = context.brain.past.hasHighActivityLoad

        let fatigueScore =
            Double(recent7DayLoad) +
            Double(dayTrainingStress * 2) +
            (recentLoadFlag ? 3.0 : 0.0) +
            (activeLoadProgress >= Thresholds.highLoadActivityProgress ? 3.0 : 0.0) +
            (activeCalories >= Thresholds.veryHighActiveCalories ? 4.0 : 0.0) -
            (strongRecoverySignal ? 3.0 : 0.0)

        let fatigueCandidates = candidates
            .filter { candidate in
                candidate.result.limiter == .accumulatedFatigue ||
                    candidate.result.reasons.contains(where: {
                        $0.localizedCaseInsensitiveContains("recent load") ||
                            $0.localizedCaseInsensitiveContains("load trend")
                    })
            }
            .sorted { $0.decisionScore > $1.decisionScore }

        let candidateSummary = fatigueCandidates
            .prefix(4)
            .map { candidate in
                let result = candidate.result
                let priorityContribution = candidate.priorityScore * 0.58
                let insightContribution = candidate.insightScore * 0.32
                let uniquenessContribution = candidate.uniquenessScore * 0.10
                return """
                title="\(result.title)" selected=\(result.priority == selected.priority && result.focus == selected.focus) limiter=\(result.limiter) fatigueContribution=\(String(format: "%.1f", candidate.decisionScore)) decisionScoreContribution={priority=\(String(format: "%.1f", priorityContribution)) insight=\(String(format: "%.1f", insightContribution)) uniqueness=\(String(format: "%.1f", uniquenessContribution)) total=\(String(format: "%.1f", candidate.decisionScore))} reasons=\(result.reasons)
                """
            }
            .joined(separator: " || ")

        return """
        [CoachFatigueDebug] fatigueScore=\(String(format: "%.1f", fatigueScore)) \
        recent7DayTrainingLoad=\(recent7DayLoad) dayTrainingStress=\(dayTrainingStress) activeCalories=\(String(format: "%.0f", activeCalories)) activityProgress=\(String(format: "%.2f", activeLoadProgress)) \
        recovery=\(recovery.map(String.init) ?? "nil") sleepHours=\(sleep.map { String(format: "%.1f", $0) } ?? "nil") strongRecoverySignal=\(strongRecoverySignal) pastHighActivityLoad=\(recentLoadFlag) \
        selected=\(selected.priority)/\(selected.focus) selectedLimiter=\(selected.limiter) \
        fatigueCandidates=\(candidateSummary.isEmpty ? "none" : candidateSummary)
        """
    }

    private static func logFuelBehindDecision(
        _ signals: FuelBehindSignals,
        result: Bool,
        in context: CoachDecisionContext
    ) {
        guard debugCandidateLoggingEnabled ||
                ProcessInfo.processInfo.environment["WEEKFIT_COACH_PRIORITY_DEBUG"] == "1" else {
            return
        }

        CoachLogger.verbose("[CoachFuelBehindDebug]", """
        [CoachFuelBehindDebug] result=\(result) \
        noMealsToday=\(signals.noMealsToday) mealsCount=\(signals.mealsCount) \
        caloriesBehind=\(signals.caloriesBehind) caloriesRatio=\(String(format: "%.2f", signals.caloriesRatio)) energyCoverage=\(String(format: "%.2f", signals.energyCoverage)) \
        carbsBehind=\(signals.carbsBehind) carbsRatio=\(String(format: "%.2f", signals.carbsRatio)) \
        preTrainingFuelingRequired=\(signals.preTrainingFuelingRequired) hardActivitySoon=\(signals.hardActivitySoon?.title ?? "nil") \
        postTrainingRefuelRequired=\(signals.postTrainingRefuelRequired) \
        lateEveningNightSuppression=\(signals.lateEveningNightSuppression) reasonableTimeToEat=\(signals.reasonableTimeToEat) \
        alreadyAteRecently=\(signals.alreadyAteRecently) minutesSinceLastMeal=\(signals.minutesSinceLastMeal.map(String.init) ?? "nil") \
        activityIntensityDurationThreshold=\(signals.activityMeetsFuelingThreshold) nextActivity=\(signals.nextTrainingOrActivity?.title ?? "nil") minutesUntilActivity=\(signals.minutesUntilActivity.map(String.init) ?? "nil") \
        currentTime=\(debugDate(context.dayContext.now))
        """)
    }

    private static func nutritionDebugSummary(in context: CoachDecisionContext) -> String {
        let nutrition = context.nutritionContext
        let mealsCount = nutrition?.mealsCount ?? context.dayContext.completedMealsCount
        let lastMealTime = latestMealTime(in: context)
        let nextActivity = context.activityContext.preparingActivity ??
            context.activityContext.laterTodayActivity ??
            context.activityContext.nextUpcomingActivity ??
            context.dayContext.nextActivity
        let nextTraining = [
            context.activityContext.preparingActivity,
            context.activityContext.laterTodayActivity,
            context.activityContext.nextUpcomingActivity
        ]
        .compactMap { $0 }
        .first { isTraining($0) }

        return """
        nutrition meals=\(mealsCount) \
        calories=\(String(format: "%.1f", nutrition?.caloriesCurrent ?? -1.0))/\(String(format: "%.1f", nutrition?.caloriesGoal ?? -1.0)) \
        protein=\(String(format: "%.1f", nutrition?.proteinCurrent ?? -1.0))/\(String(format: "%.1f", nutrition?.proteinGoal ?? -1.0)) \
        carbs=\(String(format: "%.1f", nutrition?.carbsCurrent ?? -1.0))/\(String(format: "%.1f", nutrition?.carbsGoal ?? -1.0)) \
        fats=\(String(format: "%.1f", nutrition?.fatsCurrent ?? -1.0))/\(String(format: "%.1f", nutrition?.fatsGoal ?? -1.0)) \
        lastMealTime=\(lastMealTime.map(debugDate) ?? "nil") \
        nextTrainingTime=\(nextTraining.map { debugDate($0.date) } ?? "nil") \
        nextActivityTime=\(nextActivity.map { debugDate($0.date) } ?? "nil") \
        currentTime=\(debugDate(context.dayContext.now))
        """
    }

    private static func debugDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
    #else
    private static func logCandidates(
        _ candidates: [PriorityCandidate],
        eligibleCandidates: [PriorityCandidate],
        selected: CoachDayPriorityResult,
        mode: CoachCommonSenseMode,
        objective: CoachObjective,
        in context: CoachDecisionContext
    ) {}
    #endif

    private static func objective(
        in context: CoachDecisionContext,
        mode: CoachCommonSenseMode
    ) -> CoachObjective {
        let hasTomorrowDemand = context.tomorrowDemand.hasDemand
        if let active = context.activityContext.activeActivity {
            return activeSessionObjective(active, in: context)
        }

        if let recent = context.activityContext.recentlyCompletedActivity,
           isMeaningfulPostActivityTraining(recent) {
            return .recoverFromActivity
        }

        if hasTomorrowDemand,
           isLateNight(context) && localHour(in: context) < Thresholds.dayClosedMorningEndHour {
            return .protectTomorrow
        }

        if isLateNight(context) {
            return .completeDay
        }

        if context.tomorrowDemand.isHard,
           (isEveningOrLater(context) || context.brain.currentHour >= 18) {
            return .protectTomorrow
        }

        if context.tomorrowDemand.isHard,
           isRecoveryLimitedForTomorrow(context) {
            return .protectTomorrow
        }

        switch mode {
        case .morningSetup:
            return (5..<9).contains(localHour(in: context)) ? .startDay : .buildReadiness
        case .preActivityPreparation:
            return .prepareActivity
        case .activeActivity:
            return .executeActivity
        case .postActivityRecovery:
            return .recoverFromActivity
        case .lateEveningRecovery:
            return hasTomorrowDemand ? .protectTomorrow : .completeDay
        case .dayClosed:
            return hasTomorrowDemand && isLateNight(context) && localHour(in: context) < Thresholds.dayClosedMorningEndHour ? .protectTomorrow : .completeDay
        case .actionableDay:
            if recoveryIsLow(context) || sleepIsPoor(context) {
                return .buildReadiness
            }
            if !hasMeaningfulTrainingRemaining(context),
               (context.dayContext.dayType == .recovery || isRecoveryBlock(context)) {
                return .recoveryDay
            }
            return .maintainCourse
        }
    }

    private static func activeSessionObjective(
        _ active: PlannedActivity,
        in context: CoachDecisionContext
    ) -> CoachObjective {
        guard isTraining(active) else { return .recoveryDay }

        if context.tomorrowDemand.isHard,
           isRecoveryLimitedForTomorrow(context) {
            return .protectTomorrow
        }

        if hasHeatAheadToday(context),
           hydrationIsCriticallyBehind(context) {
            return .prepareActivity
        }

        if veryLowRecovery(context) || isVeryLowSleep(context) {
            return .buildReadiness
        }

        if fuelIsCriticallyBehind(context) || hydrationIsCriticallyBehind(context) {
            return .buildReadiness
        }

        return .executeActivity
    }

    private static func hasHeatAheadToday(_ context: CoachDecisionContext) -> Bool {
        context.dayContext.upcomingActivities.contains {
            CoachActivityContextResolverV3.kind(for: $0) == .heat
        }
    }

    private static func horizon(
        for result: CoachDayPriorityResult,
        objective: CoachObjective,
        in context: CoachDecisionContext
    ) -> CoachHorizon {
        if objective == .protectTomorrow || result.focus == .tomorrowPlanRisk {
            return .tomorrow
        }

        if context.brain.past.hasHighActivityLoad || context.brain.past.completedWorkoutsCount >= 3 {
            return .trend
        }

        if result.focus == .postActivityRecovery || context.dayContext.hasMeaningfulLoadCompleted {
            return .yesterday
        }

        return .today
    }

    private static func opportunity(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CoachOpportunity {
        if result.opportunity != .none {
            return result.opportunity
        }

        if result.priority == .performance {
            return .trainingOpportunity
        }

        if result.priority == .recovery || result.priority == .sleepPreparation {
            return .recoveryWindow
        }

        if result.priority == .stable && context.dayContext.hasMeaningfulLoadCompleted {
            return .consistencyWin
        }

        if result.priority == .stable,
           strongRecovery(in: context),
           (context.dayContext.dayType == .recovery || isRecoveryBlock(context)) {
            return .recoveryMomentum
        }

        if result.priority == .stable,
           strongRecovery(in: context),
           !fuelIsBehind(context),
           !hydrationIsBehind(context) {
            return .highReadiness
        }

        return .none
    }

    private static func completionState(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CompletionState {
        if hasGoodEnoughProtein(context) || hasGoodEnoughHydration(context) {
            return .goodEnough
        }

        if result.priority == .stable,
           !fuelIsBehind(context),
           !hydrationIsBehind(context),
           !recoveryIsLow(context) {
            return .complete
        }

        return result.completionState
    }

    private static func interventionValue(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CoachInterventionValue {
        if result.priority == .stable && result.level == .quiet {
            return result.opportunity == .none ? .none : .useful
        }

        if isLateNight(context),
           result.priority == .sleepPreparation {
            return .high
        }

        if isEveningOrLater(context),
           completionState(for: result, in: context) == .goodEnough,
           result.priority == .hydration || result.priority == .fueling {
            return .low
        }

        return result.interventionValue
    }

    private static func interventionCostNote(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> String? {
        if let note = result.interventionCostNote {
            return note
        }

        if isLateNight(context) {
            return "Chasing calories, protein, fluids, or extra movement now can cost sleep."
        }

        if result.priority == .planChallenge {
            return "Forcing the plan may create more fatigue than fitness."
        }

        if result.priority == .recovery || result.priority == .sleepPreparation {
            return "Adding load would compete with the recovery you are trying to build."
        }

        if result.priority == .stable {
            return "Doing more is not automatically better today."
        }

        return nil
    }

    private static func commonSenseCandidate(
        in context: CoachDecisionContext,
        mode: CoachCommonSenseMode
    ) -> PriorityCandidate? {
        switch mode {
        case .dayClosed:
            let highLoadDay = isHighLoadDay(context)
            let timeBucket = localTimeBucket(in: context)
            let lateNight = timeBucket == .lateNight
            let night = timeBucket == .night
            let reason = lateNight
                ? "Late night is not a useful time to chase missed targets."
                : (night ? "It is night, so the useful move is protecting sleep." : "The day is closing, so the useful move is a calm reset.")
            let message = lateNight
                ? (highLoadDay
                    ? "Today is already closed, and the work is done. Do not chase missed targets now; sleep is the best recovery decision."
                    : "Today is already closed. Do not chase missed targets now; sleep is the best recovery decision.")
                : (night
                    ? "Do not chase calories or water aggressively now. Keep the evening calm and protect sleep."
                    : "Have a normal dinner if you need it, sip fluids gradually, and keep the rest of the evening calm.")
            let why = lateNight
                ? (highLoadDay
                    ? "The load is already banked; adding more now makes it harder to recover."
                    : "Late calories, fluids, or extra movement are more likely to disrupt recovery than improve it.")
                : "Closing the day calmly supports recovery without turning missed targets into another task."
            return PriorityCandidate(
                priorityScore: 76,
                insightScore: 88,
                uniquenessScore: 92,
                result: CoachDayPriorityResult(
                    focus: .eveningWindDown,
                    level: .important,
                    reason: reason,
                    activity: nil,
                    overridesTimingFocus: true,
                    priority: .sleepPreparation,
                    strength: .high,
                    confidence: 0.86,
                    mode: .recovery,
                    limiter: hasSleepDeficitEvidence(context) ? .sleep : .none,
                    messageFamily: .sleep,
                    todayTitle: "Close the day",
                    todayMessage: lateNight ? "Sleep beats target chasing." : "Keep the evening calm.",
                    title: "Close the day",
                    message: message,
                    supportBullets: [
                        highLoadDay ? "Stop adding load" : "Leave missed targets alone",
                        "Keep the evening calm",
                        "Reset tomorrow"
                    ],
                    whyThisMatters: why,
                    reasons: [
                        lateNight ? "It is late night." : (night ? "It is night." : "It is evening."),
                        highLoadDay ? "Today's load is already high." : "No recent hard workout needs a recovery exception."
                    ],
                    objective: .completeDay,
                    opportunity: CoachOpportunity.none,
                    interventionValue: .low,
                    interventionCostNote: "Chasing late calories, protein, hydration, or movement would cost more sleep than it gives back.",
                    completionState: .goodEnough
                )
            )

        case .lateEveningRecovery:
            guard context.tomorrowDemand.isHard else { return nil }
            return PriorityCandidate(
                priorityScore: 66,
                insightScore: 78,
                uniquenessScore: 86,
                result: CoachDayPriorityResult(
                    focus: .tomorrowPlanRisk,
                    level: .important,
                    reason: "Tomorrow has high-load work, so tonight should protect recovery.",
                    activity: context.tomorrowContext?.primaryTrainingActivity,
                    overridesTimingFocus: true,
                    priority: .planChallenge,
                    strength: .high,
                    confidence: 0.78,
                    mode: .adjustment,
                    limiter: .upcomingTraining,
                    messageFamily: .planAdjustment,
                    todayTitle: "Protect tomorrow",
                    todayMessage: "Recovery starts tonight.",
                    title: "Protect tomorrow",
                    message: "Tomorrow has a high-load session. Recovery decisions tonight matter more than extra work.",
                    supportBullets: [
                        "Start winding down",
                        "Keep tomorrow adjustable",
                        "Avoid extra intensity"
                    ],
                    whyThisMatters: "Tonight decides how much of tomorrow's plan is actually useful.",
                    reasons: [
                        "It is late evening.",
                        "Tomorrow has meaningful training planned."
                    ],
                    planChallenge: "If you wake up flat, reduce tomorrow's intensity before forcing the plan."
                )
            )

        case .morningSetup:
            if let morningBasics = morningBasicsCandidate(in: context) {
                return morningBasics
            }

            guard let activity = context.activityContext.laterTodayActivity, isTraining(activity) else { return nil }
            guard isVeryLowSleep(context) || recoveryIsLow(context) else { return nil }

            return PriorityCandidate(
                priorityScore: 88,
                insightScore: 96,
                uniquenessScore: 90,
                result: CoachDayPriorityResult(
                    focus: .trainingReadinessWarning,
                    level: .important,
                    reason: "Morning readiness is limited before training later today.",
                    activity: activity,
                    overridesTimingFocus: true,
                    priority: .planChallenge,
                    strength: .high,
                    confidence: 0.72,
                    mode: .adjustment,
                    limiter: isVeryLowSleep(context) ? .sleep : .trainingReadiness,
                    messageFamily: .planAdjustment,
                    todayTitle: "Manage intensity",
                    todayMessage: "Readiness sets the ceiling.",
                    title: "Manage intensity today",
                    message: "Sleep or recovery is limiting the day. Keep \(activity.title.lowercased()) flexible and let the warm-up decide intensity.",
                    supportBullets: [
                        "Build the basics early",
                        "Start below planned effort",
                        "Reduce intensity if flat"
                    ],
                    whyThisMatters: "A hard plan only works when the body can absorb it.",
                    reasons: [
                        "It is morning.",
                        "Training is planned against a readiness limiter."
                    ],
                    planChallenge: "If readiness does not improve by training time, make the session easier or move the intensity."
                )
            )

        case .preActivityPreparation:
            guard let activity = context.activityContext.preparingActivity else { return nil }
            let activityKind = CoachActivityContextResolverV3.kind(for: activity)
            let heatPreparation = activityKind == .heat
            let fuelSignals = fuelBehindSignals(in: context)
            let fuelBehind = fuelIsBehind(context)
            let hydrationBehind = hydrationIsBehind(context)
            let heatCriticalHydration = heatPreparation &&
                !hydrationGoalReached(context) &&
                hydrationRatio(context) < 0.30
            guard isTraining(activity) || heatPreparation else { return nil }
            guard fuelBehind || hydrationBehind || heatPreparation else { return nil }
            let activityName = displayName(activity).lowercased()
            let recentFuelStarted = fuelSignals.alreadyAteRecently && fuelSignals.criticalFuelGap
            let score: Double = {
                if heatCriticalHydration { return 94 }
                if heatPreparation { return hydrationBehind ? 90 : 88 }
                if fuelBehind && hydrationBehind {
                    return recentFuelStarted ? 78 : 90
                }
                if hydrationBehind {
                    return 74
                }
                return recentFuelStarted ? 72 : 76
            }()
            let supportBullets: [String] = {
                if heatCriticalHydration {
                    return [
                        "Sip steadily before sauna",
                        "Bring a bottle",
                        "Skip heat if you still feel dry"
                    ]
                }

                if heatPreparation {
                    if hydrationBehind {
                        return [
                            "Stay steady before sauna",
                            "Enter heat well hydrated",
                            "Keep recovery easy"
                        ]
                    }

                    return [
                        "Enter heat well hydrated",
                        "Keep recovery easy",
                        "Stop early if you feel flat"
                    ]
                }

                var bullets: [String] = []
                if hydrationBehind {
                    bullets.append("Drink 500 ml water")
                }
                if fuelBehind {
                    bullets.append(recentFuelStarted ? "Top up with easy carbs if needed" : "Eat 30-60 g carbs")
                }
                bullets.append("Bring a bottle")
                return Array(bullets.prefix(3))
            }()
            let title = "Prepare for \(activityName)"

            return PriorityCandidate(
                priorityScore: score,
                insightScore: score + 8,
                uniquenessScore: 92,
                result: CoachDayPriorityResult(
                    focus: .prepareForActivity,
                    level: .high,
                    reason: heatCriticalHydration
                        ? "Heat exposure is close and fluids are critically low."
                        : "The next activity is inside its preparation window.",
                    activity: activity,
                    overridesTimingFocus: false,
                    priority: .performance,
                    strength: heatCriticalHydration ? .critical : (heatPreparation ? .medium : .critical),
                    confidence: 0.90,
                    mode: heatCriticalHydration ? .execution : (heatPreparation ? .recovery : .execution),
                    limiter: heatCriticalHydration ? .timing : (heatPreparation ? .none : .timing),
                    messageFamily: heatCriticalHydration ? .performance : (heatPreparation ? .recovery : .performance),
                    todayTitle: title,
                    todayMessage: heatCriticalHydration
                        ? "Prepare before sauna."
                        : (heatPreparation ? "Keep sauna easy and avoid extra stress." : "Drink 300-500 ml now and eat 30-60 g carbs before leaving."),
                    title: title,
                    message: heatCriticalHydration
                        ? "Do not start heat exposure dry. Sip steadily first, and shorten or skip it if fluids do not come up calmly."
                        : (heatPreparation
                            ? "\(displayName(activity)) is close. Treat it as recovery heat, enter hydrated, and stop early if you feel flat."
                            : "\(displayName(activity)) is close. Hydration and fueling are the useful levers before it starts."),
                    supportBullets: supportBullets,
                    whyThisMatters: heatPreparation
                        ? "Heat is useful only when it stays easy enough to recover from."
                        : "Starting under-fueled and dry makes the same workout cost more.",
                    reasons: [
                        "The next activity is inside its preparation window.",
                        heatPreparation ? "Sauna is a recovery heat block." : "Fuel and hydration are secondary preparation supports."
                    ]
                )
            )

        case .postActivityRecovery:
            guard let recent = context.activityContext.recentlyCompletedActivity else { return nil }
            guard fuelIsBehind(context) else { return nil }
            let load = CoachActivityContextResolverV3.load(for: recent)
            guard isTraining(recent), load == .high || load == .extreme || recent.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes else {
                return nil
            }

            return PriorityCandidate(
                priorityScore: isEveningOrLater(context) ? 84 : 70,
                insightScore: isEveningOrLater(context) ? 94 : 78,
                uniquenessScore: 88,
                result: CoachDayPriorityResult(
                    focus: .postActivityRecovery,
                    level: .high,
                    reason: "A hard session just ended, so light recovery support is still useful.",
                    activity: recent,
                    overridesTimingFocus: false,
                    priority: .recovery,
                    strength: .high,
                    confidence: 0.86,
                    mode: .recovery,
                    limiter: .insufficientRecoveryTime,
                    messageFamily: .recovery,
                    todayTitle: "Protect the work",
                    todayMessage: "Keep recovery light.",
                    title: "Protect the work",
                    message: "The hard part is already done. A light protein-focused meal makes sense now, but avoid turning it into a heavy late dinner.",
                    supportBullets: [
                        "Keep food light",
                        "Sip fluids calmly",
                        "Start winding down"
                    ],
                    whyThisMatters: "The goal is to recover from the session without disrupting sleep.",
                    reasons: [
                        "A hard activity recently ended.",
                        "Fuel or protein is still behind."
                    ]
                )
            )

        case .activeActivity, .actionableDay:
            return nil
        }
    }

    private static func commonSenseMode(
        in context: CoachDecisionContext,
        intent: CoachIntent
    ) -> CoachCommonSenseMode {
        switch intent {
        case .liveGuidance:
            return .activeActivity

        case .postActivity:
            return .postActivityRecovery

        case .preparation:
            guard let preparing = context.activityContext.preparingActivity else {
                return .preActivityPreparation
            }
            if isLateNight(context),
               !isMeaningfulImmediateActivity(preparing) {
                return .dayClosed
            }
            return .preActivityPreparation

        case .sleepPreparation:
            return context.tomorrowDemand.isHard ? .lateEveningRecovery : .dayClosed

        case .dayPlanning:
            return (5..<12).contains(localHour(in: context)) ? .morningSetup : .actionableDay

        case .idleNow:
            return .actionableDay
        }
    }

    private static func allowsHydrationLead(
        in context: CoachDecisionContext,
        intent: CoachIntent,
        mode: CoachCommonSenseMode
    ) -> Bool {
        guard mode != .dayClosed, mode != .lateEveningRecovery else {
            return false
        }

        switch intent {
        case .liveGuidance, .preparation, .postActivity:
            return true
        case .sleepPreparation:
            return false
        case .dayPlanning, .idleNow:
            return hydrationIsCriticallyBehind(context)
        }
    }

    private static func allowsFuelingLead(
        in context: CoachDecisionContext,
        intent: CoachIntent,
        mode: CoachCommonSenseMode
    ) -> Bool {
        guard mode != .dayClosed, mode != .lateEveningRecovery else {
            return false
        }

        switch intent {
        case .liveGuidance, .preparation, .postActivity:
            return true
        case .sleepPreparation, .dayPlanning, .idleNow:
            return false
        }
    }

    private static func supportSignals(
        in context: CoachDecisionContext,
        intent: CoachIntent,
        selected: CoachDayPriorityResult
    ) -> [CoachSupportSignal] {
        if isSequenceAwarePreparation(selected) {
            return []
        }

        var signals: [CoachSupportSignal] = []

        if let hydration = hydrationSupportSignal(in: context, intent: intent, selected: selected) {
            signals.append(hydration)
        }

        if let fueling = fuelingSupportSignal(in: context, intent: intent, selected: selected) {
            signals.append(fueling)
        }

        if intent == .sleepPreparation {
            let fuelCovered = eveningFuelCovered(in: context)
            signals.append(
                CoachSupportSignal(
                    kind: .sleep,
                    title: fuelCovered ? "Sip gradually if thirsty" : "Do not chase water or calories now",
                    message: "Sleep is the useful intervention.",
                    amount: fuelCovered ? "Sip gradually if thirsty" : "200-300 ml only if thirsty",
                    timing: "Tonight",
                    priority: .important
                )
            )
        }

        if context.activityContext.activeActivity != nil,
           let next = context.activityContext.nextUpcomingActivity,
           isTraining(next) {
            signals.append(
                CoachSupportSignal(
                    kind: .pacing,
                    title: "\(displayName(next)) starts \(timeUntilText(next, in: context))",
                    message: "Keep the current activity easy enough to protect the next block.",
                    amount: nil,
                    timing: "Save energy",
                    priority: .important
                )
            )
        }

        return signals.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            return supportSignalRank(lhs.kind) < supportSignalRank(rhs.kind)
        }
    }

    private static func supportSignalRank(_ kind: CoachSupportKind) -> Int {
        switch kind {
        case .pacing:
            return 0
        case .hydration:
            return 1
        case .fueling:
            return 2
        case .recovery:
            return 3
        case .sleep:
            return 4
        }
    }

    private static func eveningFuelCovered(in context: CoachDecisionContext) -> Bool {
        guard let nutrition = context.nutritionContext else { return false }
        let caloriesCovered = context.brain.baseDayGoals.calories > 0 &&
            nutrition.caloriesCurrent / context.brain.baseDayGoals.calories >= 0.80
        let carbsCovered = context.brain.baseDayGoals.carbs > 0 &&
            nutrition.carbsCurrent / context.brain.baseDayGoals.carbs >= 0.60
        let recentMeal = latestMealTime(in: context).map {
            let minutes = max(0, Int(context.dayContext.now.timeIntervalSince($0) / 60))
            return minutes <= Thresholds.recentMealSuppressionMinutes
        } ?? false

        return caloriesCovered && carbsCovered && recentMeal
    }

    private static func withCriticalHydrationContext(
        _ result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CoachDayPriorityResult {
        result
    }

    private static func hydrationSupportSignal(
        in context: CoachDecisionContext,
        intent: CoachIntent,
        selected: CoachDayPriorityResult
    ) -> CoachSupportSignal? {
        let hour = localHour(in: context)
        let current = context.nutritionContext?.waterCurrent ?? (hydrationRatio(context) * max(context.nutritionContext?.waterGoal ?? 0, 0))
        let goal = context.nutritionContext?.waterGoal ?? 0
        let expected = goal > 0 ? goal * expectedHydrationRatio(forHour: hour) : 0
        let gap = max(0, expected - current)
        let heat = heatHydrationActivity(in: context)
        let activity = context.activityContext.preparingActivity ??
            context.activityContext.activeActivity ??
            context.activityContext.nextUpcomingActivity ??
            selected.activity
        let kind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }

        if intent == .sleepPreparation {
            return nil
        }

        if isEveningOrLater(context) {
            return CoachSupportSignal(
                kind: .hydration,
                title: "Do not chase the full water target",
                message: "Late fluid catch-up can compete with sleep.",
                amount: "200-300 ml only if thirsty",
                timing: "Evening",
                priority: .useful
            )
        }

        if let heat,
           context.activityContext.activeActivity?.id == heat.id || (minutesUntil(heat, in: context).map { $0 <= Thresholds.heatHydrationLeadMinutes } == true) {
            return CoachSupportSignal(
                kind: .hydration,
                title: "Hydration before sauna",
                message: "Heat raises fluid demand.",
                amount: "Add ~400-600 ml",
                timing: "Before sauna",
                priority: .important
            )
        }

        if let progressiveHydration = progressiveHydrationSupportSignal(in: context, selected: selected) {
            return progressiveHydration
        }

        if intent == .postActivity,
           let activity,
           isMeaningfulPostActivityTraining(activity) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return CoachSupportSignal(
                kind: .hydration,
                title: kind == .endurance ? "Rehydrate after the ride" : "Rehydrate after training",
                message: "Replace what the session spent without chasing the full day target.",
                amount: "Add 400-600 ml",
                timing: "Over the next hour",
                priority: .important
            )
        }

        if kind == .endurance {
            let duration = activity?.effectiveDurationMinutes ?? activity?.durationMinutes ?? 0
            return CoachSupportSignal(
                kind: .hydration,
                title: "Fluids for endurance",
                message: "Keep intake steady instead of catching up late.",
                amount: duration >= 60 ? "Take 500-750 ml/hour" : "Add ~400-600 ml",
                timing: intent == .preparation ? "Before and during" : "During",
                priority: .important
            )
        }

        guard gap >= 0.25 else { return nil }

        return CoachSupportSignal(
            kind: .hydration,
            title: "Hydrate steadily",
            message: "Use time-aware progress, not the full-day target.",
            amount: gap >= 0.6 ? "Add ~300-500 ml" : "Add ~200-300 ml",
            timing: "Over the next hour",
            priority: .useful
        )
    }

    private static func criticalHydrationSupportNeeded(_ context: CoachDecisionContext) -> Bool {
        !hydrationGoalReached(context) &&
            hydrationRatio(context) < 0.25
    }

    private static func progressiveHydrationSupportSignal(
        in context: CoachDecisionContext,
        selected: CoachDayPriorityResult
    ) -> CoachSupportSignal? {
        guard !hydrationGoalReached(context) else { return nil }

        let current = context.nutritionContext?.waterCurrent ?? 0
        if current >= 0.75 {
            return CoachSupportSignal(
                kind: .hydration,
                title: "Hydration is improving",
                message: "Do not force another large drink right now.",
                amount: "Keep fluids available",
                timing: nil,
                priority: .important
            )
        }

        if current >= 0.50 {
            return CoachSupportSignal(
                kind: .hydration,
                title: "Hydration is improving",
                message: "Keep fluids available without forcing another large drink.",
                amount: "Keep sipping calmly",
                timing: nil,
                priority: .important
            )
        }

        let ratio = hydrationRatio(context)
        switch ratio {
        case ..<0.20:
            let hydrationOwnsNarrative = selected.limiter == .hydration && selected.strength == .critical
            return CoachSupportSignal(
                kind: .hydration,
                title: hydrationOwnsNarrative ? "Hydration needs attention now" : "Hydration could use attention",
                message: hydrationOwnsNarrative ? "Support the main guidance before the demand rises." : "Support the main guidance without changing it.",
                amount: hydrationOwnsNarrative ? "Add 300-500 ml now" : "Consider a glass of water",
                timing: nil,
                priority: hydrationOwnsNarrative ? .important : .useful
            )
        case 0.20..<0.35:
            return CoachSupportSignal(
                kind: .hydration,
                title: "Hydration is improving",
                message: "Keep bringing fluids back up.",
                amount: "Keep adding fluids",
                timing: nil,
                priority: .important
            )
        case 0.35..<0.55:
            return CoachSupportSignal(
                kind: .hydration,
                title: "Hydration is on the way back",
                message: "Progress is moving in the right direction.",
                amount: "Stay steady",
                timing: nil,
                priority: .useful
            )
        default:
            return nil
        }
    }

    private static func fuelingSupportSignal(
        in context: CoachDecisionContext,
        intent: CoachIntent,
        selected: CoachDayPriorityResult
    ) -> CoachSupportSignal? {
        let activity = context.activityContext.preparingActivity ??
            context.activityContext.activeActivity ??
            context.activityContext.recentlyCompletedActivity ??
            selected.activity
        let kind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }
        let duration = activity?.effectiveDurationMinutes ?? activity?.durationMinutes ?? 0
        let noMealsLogged = (context.nutritionContext?.mealsCount ?? context.dayContext.completedMealsCount) == 0 &&
            !context.brain.hasAnyFoodLogged

        if intent == .postActivity,
           let activity,
           isMeaningfulPostActivityTraining(activity) {
            return CoachSupportSignal(
                kind: .fueling,
                title: "Recovery nutrition",
                message: "Give the body material to repair the work.",
                amount: "25-40g protein + carbs",
                timing: "Next meal",
                priority: .important
            )
        }

        if intent == .preparation,
           let activity,
           isTraining(activity) {
            if let progressiveFueling = progressiveFuelingSupportSignal(
                in: context,
                activity: activity,
                kind: kind,
                duration: duration
            ) {
                return progressiveFueling
            }

            if kind == .endurance && duration >= 120 {
                return CoachSupportSignal(
                    kind: .fueling,
                    title: "Fuel the ride/run",
                    message: "Long endurance needs steady carbs.",
                    amount: "60-90g carbs/hour if tolerated",
                    timing: "During",
                    priority: .important
                )
            }

            if kind == .endurance && duration >= 60 {
                return CoachSupportSignal(
                    kind: .fueling,
                    title: "Fuel endurance",
                    message: "Start with usable energy.",
                    amount: "30-60g carbs/hour",
                    timing: "During",
                    priority: .important
                )
            }

            return CoachSupportSignal(
                kind: .fueling,
                title: "Pre-workout carbs",
                message: "Keep it simple and digestible.",
                amount: "30-60g carbs if hungry",
                timing: "Before training",
                priority: .useful
            )
        }

        if context.dayContext.dayType == .recovery && noMealsLogged {
            return CoachSupportSignal(
                kind: .fueling,
                title: "Eat normally at your next meal",
                message: "Recovery day does not need target chasing.",
                amount: nil,
                timing: "Next meal",
                priority: .useful
            )
        }

        let expected = expectedNutritionRatio(forHour: localHour(in: context))
        guard nutritionRatio(context) < max(0.10, expected - 0.35), noMealsLogged else { return nil }

        return CoachSupportSignal(
            kind: .fueling,
            title: "Eat normally at your next meal",
            message: "Food supports the day without becoming the main priority.",
            amount: nil,
            timing: "Next meal",
            priority: .low
        )
    }

    private static func progressiveFuelingSupportSignal(
        in context: CoachDecisionContext,
        activity: PlannedActivity,
        kind: CoachActivityKindV3?,
        duration: Int
    ) -> CoachSupportSignal? {
        let carbs = carbsRatio(context)
        let nutrition = nutritionRatio(context)
        let meal = activeMeal(in: context)
        let lastMealTime = latestMealTime(in: context)
        let minutesSinceLastMeal = lastMealTime.map {
            max(0, Int(context.dayContext.now.timeIntervalSince($0) / 60))
        }
        let minutesUntilActivity = minutesUntil(activity, in: context)
        let mealsCount = context.nutritionContext?.mealsCount ?? context.dayContext.completedMealsCount
        let hasMealContext = meal != nil || mealsCount > 0 || lastMealTime != nil || context.brain.hasAnyFoodLogged
        let mealJustLogged = minutesSinceLastMeal.map { $0 <= 25 } == true
        let mealRecent = minutesSinceLastMeal.map { $0 <= Thresholds.recentMealSuppressionMinutes } == true
        let closeToTraining = minutesUntilActivity.map { $0 <= 60 } == true
        let heavyCloseMeal = closeToTraining && mealRecent && nutrition >= 0.70
        let enoughFuel = carbs >= 0.35 || (mealRecent && nutrition >= 0.35)
        let someFuel = carbs >= 0.12 || hasMealContext
        let hardEndurance = kind == .endurance && duration >= 60

        if meal != nil || mealJustLogged {
            return CoachSupportSignal(
                kind: .fueling,
                title: "Meal is in",
                message: "Let it settle before training.",
                amount: nil,
                timing: "Give it time to settle",
                priority: .important
            )
        }

        if heavyCloseMeal {
            return CoachSupportSignal(
                kind: .fueling,
                title: "Food is covered",
                message: "Keep the start easy.",
                amount: nil,
                timing: "Before training",
                priority: .important
            )
        }

        if enoughFuel {
            return CoachSupportSignal(
                kind: .fueling,
                title: "Fuel is covered",
                message: "Avoid adding heavy food now.",
                amount: nil,
                timing: "Keep it digestible before training",
                priority: .useful
            )
        }

        if someFuel {
            return CoachSupportSignal(
                kind: .fueling,
                title: "Fuel is started",
                message: "Top up only if you need it.",
                amount: "Add a small carb top-up if hungry",
                timing: nil,
                priority: .useful
            )
        }

        return CoachSupportSignal(
            kind: .fueling,
            title: "Fuel is still missing",
            message: hardEndurance ? "Endurance will need usable carbs." : "Training will need usable energy.",
            amount: hardEndurance ? "Add 30-60g carbs before training" : "Add 30-60g carbs before training",
            timing: nil,
            priority: .important
        )
    }

    private static func mergedSupportBullets(
        primary: [String],
        signals: [CoachSupportSignal]
    ) -> [String] {
        var result: [String] = []

        func add(_ bullet: String) {
            let trimmed = bullet.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard !result.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
            guard !result.contains(where: { supportBulletKey($0) == supportBulletKey(trimmed) }) else { return }
            result.append(trimmed)
        }

        signals.map(\.bulletText).forEach(add)
        primary
            .filter { bullet in
                !shouldSuppressLegacySupportBullet(bullet, whenSignalsExist: !signals.isEmpty, existing: result)
            }
            .forEach(add)

        return Array(result.prefix(4))
    }

    private static func supportBulletKey(_ bullet: String) -> String {
        let normalized = normalizedSupportText(bullet)
        let hydrationTerms = ["hydrate", "hydration", "fluid", "fluids", "water", "sip", "ml"]
        if hydrationTerms.contains(where: { normalized.contains($0) }) {
            if normalized.contains("300") || normalized.contains("500") {
                return "hydration-300-500"
            }
            if normalized.contains("400") || normalized.contains("600") {
                return "hydration-400-600"
            }
            if normalized.contains("750") || normalized.contains("hour") {
                return "hydration-hourly"
            }
            return "hydration"
        }

        if normalized.contains("carb") || normalized.contains("fuel") || normalized.contains("eat") {
            return normalized.contains("hour") ? "fuel-hourly" : "fuel"
        }

        return normalized
    }

    private static func shouldSuppressLegacySupportBullet(
        _ bullet: String,
        whenSignalsExist: Bool,
        existing: [String]
    ) -> Bool {
        let normalized = bullet.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        if existing.contains(where: { existingBullet in
            let existingNormalized = existingBullet.lowercased()
            return existingNormalized.contains(normalized) || normalized.contains(existingNormalized)
        }) {
            return true
        }

        guard whenSignalsExist else { return false }

        let genericNutritionSupport = [
            "add easy carbs",
            "sip fluids steadily",
            "hydrate steadily",
            "eat normally at your next meal",
            "eat normally",
            "keep prep light",
            "add easy fuel",
            "support the next block",
            "avoid starting dry",
            "sip steadily",
            "keep fluids steady"
        ]

        return genericNutritionSupport.contains { normalized.contains($0) }
    }

    private static func sequenceAwarePreparationCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard context.activityContext.activeActivity == nil else { return nil }

        let upcoming = context.dayContext.upcomingActivities
            .filter { !$0.isSkipped }
            .sorted { $0.date < $1.date }

        guard let seriousTraining = upcoming.first(where: { isSeriousTraining($0) }) else {
            return nil
        }

        let earlierUpcoming = upcoming.filter { activity in
            activity.id != seriousTraining.id && activity.date < seriousTraining.date
        }
        let completedToday = context.dayContext.completedActivities
            .filter { $0.date < seriousTraining.date }
            .sorted { $0.date < $1.date }

        guard !earlierUpcoming.isEmpty || !completedToday.isEmpty else {
            return nil
        }

        let nextAnchor = earlierUpcoming.first ?? seriousTraining
        let narrative = sequenceNarrative(
            completed: completedToday,
            upcomingBeforeTraining: earlierUpcoming,
            training: seriousTraining,
            context: context
        )

        return PriorityCandidate(
            priorityScore: 88,
            insightScore: 92,
            uniquenessScore: 94,
            result: CoachDayPriorityResult(
                focus: .nextActivityLater,
                level: .important,
                reason: "Sequence narrative \(narrative.id) should shape preparation before later serious training.",
                activity: nextAnchor,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .high,
                confidence: 0.84,
                mode: .adjustment,
                limiter: CoachLimiter.none,
                messageFamily: .planAdjustment,
                todayTitle: narrative.title,
                todayMessage: narrative.todayMessage,
                title: narrative.title,
                message: narrative.message,
                supportBullets: narrative.supportBullets,
                whyThisMatters: "The useful coaching move is protecting the later work from the things that can drain it first.",
                reasons: [
                    "Narrative ID: \(narrative.id).",
                    "A serious training session is planned later.",
                    "Earlier meaningful events can change how ready the user arrives."
                ],
                planChallenge: narrative.planChallenge
            )
        )
    }

    private struct SequenceNarrative {
        let id: String
        let title: String
        let todayMessage: String
        let message: String
        let supportBullets: [String]
        let planChallenge: String?
    }

    private static func isSeriousTraining(_ activity: PlannedActivity) -> Bool {
        guard isTraining(activity) else { return false }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        return kind == .endurance ||
            load == .moderate ||
            load == .high ||
            load == .extreme ||
            activity.effectiveDurationMinutes >= 45
    }

    private static func sequenceNarrative(
        completed: [PlannedActivity],
        upcomingBeforeTraining: [PlannedActivity],
        training: PlannedActivity,
        context: CoachDecisionContext
    ) -> SequenceNarrative {
        let trainingName = displayName(training)
        let trainingKind = CoachActivityContextResolverV3.kind(for: training)
        let trainingText = trainingKind == .endurance ? enduranceTrainingText(training) : trainingName.lowercased()
        let meal = upcomingBeforeTraining.first(where: isFoodMeal)
        let completedMeal = completed.last(where: isFoodMeal)
        let heat = upcomingBeforeTraining.first(where: { CoachActivityContextResolverV3.kind(for: $0) == .heat })
        let hasMealContext = meal != nil || completedMeal != nil
        let mealJustLogged = completedMeal.map {
            context.dayContext.now.timeIntervalSince($0.date) <= 45 * 60
        } ?? false
        let waterLow = hydrationRatio(context) < 0.45 || context.brain.hydration == .depleted
        let recoveryLimited = isRecoveryLimitedForTomorrow(context) || context.brain.sleep == .short
        let shortHeatGap = heat.map { gapMinutes(from: $0, to: training) <= 45 } ?? false
        let id = sequenceNarrativeID(
            hasMeal: hasMealContext,
            hasHeat: heat != nil,
            endurance: trainingKind == .endurance,
            waterLow: waterLow,
            shortHeatGap: shortHeatGap,
            recoveryLimited: recoveryLimited
        )

        let title: String
        let message: String
        let todayMessage: String

        if let heat, trainingKind == .endurance, hasMealContext {
            title = waterLow ? "Fuel now, do not enter heat dry" : "Fuel now, keep the heat easy"

            let mealText: String
            if let meal {
                mealText = "\(meal.title) is the useful setup now"
            } else if let completedMeal {
                mealText = "\(displayName(completedMeal)) is already in"
            } else {
                mealText = "Eat something useful now"
            }

            let heatText = shortHeatGap
                ? "\(displayName(heat)) is close enough to affect the \(trainingText)"
                : "\(displayName(heat)) is the part that can quietly drain the \(trainingText)"

            message = "\(trainingName) matters later, but the move now is not to chase it early. \(mealText). \(heatText), so keep \(displayName(heat).lowercased()) conservative and go into the \(trainingText) hydrated rather than cooked."
            todayMessage = "\(heatText). Keep the day pointed at the session."

        } else if let heat, trainingKind == .endurance {
            title = shortHeatGap ? "Do not let sauna steal the ride" : "Keep heat from stealing the ride"
            message = "\(displayName(heat)) is the risky part before \(trainingText). Keep it easy, hydrate before and after, and save the hard work for the bike."
            todayMessage = "The heat comes before the real work. Keep it conservative."

        } else if hasMealContext, trainingKind == .endurance {
            title = "Fuel the ride without rushing it"

            let mealText: String
            if let meal {
                mealText = "\(meal.title) is your useful setup now"
            } else if let completedMeal {
                mealText = "\(displayName(completedMeal)) already covers the first fuel step"
            } else {
                mealText = "Fuel first"
            }

            message = "\(trainingName) is later, so do not spend the day staring at the bike. \(mealText); keep food simple and arrive with fluids and carbs ready."
            todayMessage = "Use the meal as setup, then keep the ride protected."

        } else if let heat {
            title = "Keep heat from costing training"
            message = "\(displayName(heat)) comes before \(trainingName). Treat it as optional recovery, not another workout, and shorten it if sleep or recovery feels off."
            todayMessage = "Heat is useful only if it does not steal from training."

        } else if hasMealContext {
            title = "Fuel now, train later"

            let mealText: String
            if let meal {
                mealText = "\(meal.title) is the useful move now"
            } else if let completedMeal {
                mealText = "\(displayName(completedMeal)) is already handled"
            } else {
                mealText = "Eat something useful now"
            }

            message = "\(trainingName) is still later. \(mealText), then keep the gap calm so you are not flat when training starts."
            todayMessage = "Food is setup, not the whole coaching target."

        } else {
            let nextName = upcomingBeforeTraining.first.map(displayName) ?? "The next block"
            title = "Keep the next block easy"
            message = "\(nextName) comes before \(trainingName). Keep it light enough that the real work later still has room."
            todayMessage = "Protect the later session from unnecessary early cost."
        }
        let challenge = heat.map { heatActivity in
            shortHeatGap
                ? "\(displayName(heatActivity)) is close to \(trainingName.lowercased()); skip or shorten it if legs feel flat."
                : "If \(displayName(heatActivity).lowercased()) leaves you drained, shorten or skip it before \(trainingName.lowercased())."
        }

        return SequenceNarrative(
            id: id,
            title: title,
            todayMessage: todayMessage,
            message: message,
            supportBullets: sequenceSupportBullets(
                message: "\(title) \(message)",
                hasHeat: heat != nil,
                training: training,
                mealJustLogged: mealJustLogged,
                waterLow: waterLow,
                shortHeatGap: shortHeatGap,
                recoveryLimited: recoveryLimited
            ),
            planChallenge: challenge
        )
    }

    private static func sequenceNarrativeID(
        hasMeal: Bool,
        hasHeat: Bool,
        endurance: Bool,
        waterLow: Bool,
        shortHeatGap: Bool,
        recoveryLimited: Bool
    ) -> String {
        [
            hasMeal ? "meal" : nil,
            hasHeat ? "heat" : nil,
            endurance ? "endurance" : "training",
            waterLow ? "low-water" : nil,
            shortHeatGap ? "tight-gap" : nil,
            recoveryLimited ? "limited-recovery" : nil
        ]
        .compactMap { $0 }
        .joined(separator: "+")
    }

    private static func sequenceSupportBullets(
        message: String,
        hasHeat: Bool,
        training: PlannedActivity,
        mealJustLogged: Bool,
        waterLow: Bool,
        shortHeatGap: Bool,
        recoveryLimited: Bool
    ) -> [String] {
        let kind = CoachActivityContextResolverV3.kind(for: training)
        var ranked: [String] = []

        if mealJustLogged {
            ranked.append("Meal is in - give it time to settle")
        }

        if hasHeat && waterLow {
            ranked.append("Add 300-500 ml before sauna")
        } else if hasHeat {
            ranked.append("Hydrate before and after sauna")
        } else if waterLow {
            ranked.append("Add 300-500 ml in the next hour")
        }

        if hasHeat {
            ranked.append(shortHeatGap ? "Keep sauna short; the gap is tight" : "Keep sauna short if legs feel flat")
        }

        if kind == .endurance {
            ranked.append("For the ride: 500-750 ml/hour + 30-60g carbs/hour")
        } else {
            ranked.append("For training: bring fluids and easy carbs")
        }

        if recoveryLimited {
            ranked.append("Make the earlier block optional if recovery feels off")
        }

        return deduplicatedSupportBullets(ranked, against: message, limit: 3)
    }

    private static func deduplicatedSupportBullets(
        _ bullets: [String],
        against message: String,
        limit: Int
    ) -> [String] {
        var result: [String] = []
        let normalizedMessage = normalizedSupportText(message)

        for bullet in bullets {
            let normalized = normalizedSupportText(bullet)
            guard !normalized.isEmpty else { continue }
            guard !result.contains(where: { normalizedSupportText($0) == normalized }) else { continue }
            guard !supportBulletIsImplied(normalized, by: normalizedMessage) else { continue }
            result.append(bullet)
            if result.count == limit { break }
        }

        return result
    }

    private static func supportBulletIsImplied(_ bullet: String, by message: String) -> Bool {
        message.contains(bullet)
    }

    private static func normalizedSupportText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func gapMinutes(from first: PlannedActivity, to second: PlannedActivity) -> Int {
        let firstEnd = first.date.addingTimeInterval(TimeInterval(first.effectiveDurationMinutes * 60))
        return max(0, Int(second.date.timeIntervalSince(firstEnd) / 60))
    }

    private static func enduranceTrainingText(_ activity: PlannedActivity) -> String {
        let text = "\(activity.type) \(activity.title)".lowercased()
        if text.contains("ride") || text.contains("cycling") || text.contains("bike") {
            return "ride"
        }
        if text.contains("run") {
            return "run"
        }
        if text.contains("swim") {
            return "swim"
        }
        return "endurance block"
    }

    private static func tomorrowAdjustmentCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard context.tomorrowDemand.isHard else { return nil }

        var score = 34.0
        var reasons: [String] = ["Tomorrow has meaningful training planned."]

        if isHighLoadDay(context) {
            score += 28
            reasons.append("Today's load is already unusually high.")
        }
        if isVeryLowSleep(context) {
            score += 26
            reasons.append("Sleep was very low.")
        } else if sleepHours(context).map({ $0 < 6.0 }) ?? (context.brain.sleep == .short) {
            score += 12
            reasons.append("Sleep is not a strong recovery base.")
        }
        if recoveryPercent(context).map({ $0 < 60 }) ?? recoveryIsLow(context) {
            score += 20
            reasons.append("Recovery is not fully back.")
        }
        if nutritionRatio(context) < 0.35 || carbsRatio(context) < 0.30 {
            score += 14
            reasons.append("Fuel is too low to support another hard day.")
        }
        if context.brain.past.hasHighActivityLoad || context.brain.past.completedWorkoutsCount >= 2 {
            score += 16
            reasons.append("Recent load trend is accumulating.")
        }
        if isEveningOrLater(context) {
            score += 8
            reasons.append("There is little day left to repair the gap.")
        }

        guard score >= 64 else { return nil }

        let activity = context.tomorrowDemand.primaryTrainingActivity
        let trainingName = activity?.title ?? "tomorrow's session"
        let challenge = "\(trainingName) may be too much if sleep, fuel, and recovery do not improve tonight. Consider replacing it with recovery work or an easier aerobic block."
        let support = supportBullets(
            primary: "Decide tomorrow after checking readiness",
            context: context,
            includeFuel: nutritionRatio(context) < 0.60,
            includeHydration: hydrationRatio(context) < 0.70,
            includeSleep: true
        )

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (isVeryLowSleep(context) ? 10 : 0) + (nutritionRatio(context) < 0.45 ? 8 : 0),
            uniquenessScore: 82,
            result: CoachDayPriorityResult(
                focus: .tomorrowPlanRisk,
                level: level(for: score),
                reason: "Tomorrow's plan conflicts with today's recovery state.",
                activity: activity,
                overridesTimingFocus: true,
                priority: .planChallenge,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .adjustment,
                limiter: isHighLoadDay(context) ? .excessivePlannedLoad : .upcomingTraining,
                messageFamily: .planAdjustment,
                title: "Protect tomorrow",
                message: "Today has already taken a lot. If nothing changes tonight, \(trainingName.lowercased()) is likely to cost more than it gives.",
                supportBullets: support,
                whyThisMatters: "Training only works if you can absorb it. Tonight's sleep, fuel, and fluids decide whether tomorrow is adaptation or just more fatigue.",
                reasons: reasons,
                planChallenge: challenge
            )
        )
    }

    private static func morningBasicsCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard (5..<10).contains(localHour(in: context)) else { return nil }
        guard !recoveryIsLow(context), !isVeryLowSleep(context) else { return nil }
        guard hydrationRatio(context) < 0.20 || nutritionRatio(context) < 0.20 || !context.brain.hasAnyFoodLogged else { return nil }
        guard let later = context.activityContext.laterTodayActivity else { return nil }

        let kind = CoachActivityContextResolverV3.kind(for: later)
        guard kind == .recovery || kind == .endurance || kind == .workout else { return nil }

        return PriorityCandidate(
            priorityScore: 42,
            insightScore: 66,
            uniquenessScore: 76,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: "The morning is in a good recovery state, but the basics have not started yet.",
                activity: later,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.68,
                mode: .reinforcement,
                limiter: .none,
                messageFamily: .stable,
                todayTitle: "Start easy today",
                todayMessage: "Build the basics calmly.",
                title: "Start easy today",
                message: "Recovery looks strong this morning. Build the basics calmly so the first movement block stays comfortable.",
                supportBullets: ["Eat normally at your next meal", "Sip steadily now", "Keep effort comfortable"],
                whyThisMatters: "A strong morning still needs a gentle setup before activity.",
                reasons: ["Recovery and sleep are strong.", "No food or water has been logged yet.", "Movement is still ahead."]
            )
        )
    }

    private static func sleepPreparationCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        var score = 0.0
        var reasons: [String] = []

        let hardActivity = hardFuelingActivity(in: context, maximumLeadTimeMinutes: nil)
        let sleepLimitedBeforeTraining = isVeryLowSleep(context) && hardActivity != nil
        let daytimePostWorkoutRecovery = isDaytimePostWorkoutRecoveryWindow(context)

        guard (isEveningOrLater(context) || sleepLimitedBeforeTraining) && !daytimePostWorkoutRecovery else { return nil }
        if isEveningOrLater(context) {
            score += 24
            reasons.append("It is late enough that sleep is the best lever.")
        } else {
            score += 22
            reasons.append("Sleep should lower the ceiling before the next hard session.")
        }

        if isVeryLowSleep(context) {
            score += 30
            reasons.append("Last night's sleep was very low.")
        } else if sleepHours(context).map({ $0 < 6 }) ?? (context.brain.sleep == .short) {
            score += 14
            reasons.append("Sleep is already short.")
        }
        if isHighLoadDay(context) {
            score += 22
            reasons.append("The day load is high.")
        }
        if hasNoMeaningfulPerformanceWorkLeft(context) {
            score += 14
            reasons.append("There is no meaningful performance work left today.")
        }
        if context.tomorrowDemand.isHard {
            score += 12
            reasons.append("Tomorrow depends on recovery quality.")
        }
        if sleepLimitedBeforeTraining {
            score += 24
            reasons.append("\(hardActivity?.title ?? "The next hard session") needs a lower ceiling after poor sleep.")
        }
        if recoveryIsLow(context) {
            score += 8
            reasons.append("Recovery is limited.")
        }

        guard score >= 58 else { return nil }

        let challenge = context.tomorrowDemand.isHard && (isVeryLowSleep(context) || isHighLoadDay(context))
            ? "If you wake up flat, reduce tomorrow's intensity before forcing the planned session."
            : nil

        let limiter: CoachLimiter = isVeryLowSleep(context) ? .sleep : .insufficientRecoveryTime
        let title = isVeryLowSleep(context)
            ? "Sleep leads today"
            : "Protect tonight's sleep"
        let message = isVeryLowSleep(context)
            ? "Fitness is not the issue today. Sleep is the bottleneck, so the best coaching move is to lower the day and give tomorrow a better floor."
            : "The useful move now is to bring the day down. More load will not help; sleep is what gives tomorrow a chance."
        let support = sleepSupportBullets(context: context)

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (isVeryLowSleep(context) ? 18 : 8),
            uniquenessScore: isVeryLowSleep(context) ? 92 : 76,
            result: CoachDayPriorityResult(
                focus: .recoveryNeeded,
                level: level(for: score),
                reason: "Sleep preparation is the highest-value move now.",
                activity: context.activityContext.activeActivity ?? context.activityContext.nextUpcomingActivity,
                overridesTimingFocus: true,
                priority: .sleepPreparation,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .recovery,
                limiter: limiter,
                messageFamily: .sleep,
                title: title,
                message: message,
                supportBullets: support,
                whyThisMatters: "If nothing changes, tomorrow starts with the same fatigue plus one more night of poor recovery.",
                reasons: reasons,
                planChallenge: challenge
            )
        )
    }

    private static func recoveryCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        var score = 0.0
        var reasons: [String] = []

        if recoveryIsLow(context) {
            score += 28
            reasons.append("Recovery is suppressed.")
        }
        if recoveryPercent(context).map({ $0 < 45 }) ?? false {
            score += 24
            reasons.append("Recovery is low enough to make this a recovery-led day.")
        }
        if recoveryPercent(context).map({ $0 < 40 }) ?? false {
            score += 24
            reasons.append("Recovery is low enough to lead even on an easy day.")
        }
        if isHighLoadDay(context) {
            score += 24
            reasons.append("Today's load is high.")
        }
        if context.actualLoad.activeCalories >= Thresholds.veryHighActiveCalories {
            score += 10
            reasons.append("Active calories are unusually high.")
        }
        if isVeryLowSleep(context) || sleepIsPoor(context) {
            score += 16
            reasons.append("Sleep is a recovery limiter.")
        }
        if isEveningOrLater(context) {
            score += 10
            reasons.append("There is little recovery time left today.")
        }
        if hasNoMeaningfulPerformanceWorkLeft(context) {
            score += 10
            reasons.append("No hard work remains today.")
        }
        if context.dayContext.hasMeaningfulLoadCompleted || context.activityContext.recentlyCompletedActivity != nil {
            score += isDaytimePostWorkoutRecoveryWindow(context) ? 24 : 8
            reasons.append("A meaningful session is already banked.")
        }
        if context.tomorrowDemand.isHard {
            score += 8
            reasons.append("Tomorrow will need better recovery.")
        }
        if hydrationRatio(context) < 0.55 {
            reasons.append("Hydration is low, but recovery is the broader limiter.")
        }

        let highLoadEveningWithNoWork = isHighLoadDay(context) &&
            isEveningOrLater(context) &&
            hasNoMeaningfulPerformanceWorkLeft(context)

        guard score >= 50 || (score >= 44 && highLoadEveningWithNoWork) else { return nil }

        let challenge = context.tomorrowDemand.isHard && score >= 78
            ? "Keep tomorrow flexible. If recovery stays low, make the hard work easy or move it."
            : nil

        let narrative = recoveryNarrative(in: context, score: score)

        return PriorityCandidate(
            priorityScore: score,
            insightScore: narrative.insightScore,
            uniquenessScore: narrative.uniquenessScore,
            result: CoachDayPriorityResult(
                focus: .recoveryNeeded,
                level: level(for: score),
                reason: "Recovery is the dominant limiter now.",
                activity: context.activityContext.activeActivity ?? context.activityContext.laterTodayActivity,
                overridesTimingFocus: context.activityContext.activeActivity != nil || context.activityContext.preparingActivity != nil || score >= 70,
                priority: .recovery,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .recovery,
                limiter: narrative.limiter,
                messageFamily: narrative.family,
                title: narrative.title,
                message: narrative.message,
                supportBullets: narrative.supportBullets,
                whyThisMatters: narrative.whyThisMatters,
                reasons: reasons,
                planChallenge: challenge
            )
        )
    }

    private static func sameDayTrainingAdjustmentCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        let activity = hardFuelingActivity(in: context) ??
            context.activityContext.preparingActivity ??
            context.activityContext.laterTodayActivity

        guard let activity, isTraining(activity) else { return nil }
        guard isVeryLowSleep(context) || recoveryIsLow(context) else { return nil }

        var score = 58.0
        var reasons: [String] = ["Training is planned against a readiness limiter."]

        if isVeryLowSleep(context) {
            score += 24
            reasons.append("Sleep is the main limiter today.")
        }

        if recoveryIsLow(context) {
            score += 18
            reasons.append("Recovery is low for the planned work.")
        }

        if isHighLoadDay(context) {
            score += 10
            reasons.append("Today's load already needs respect.")
        }

        let challenge = "\(activity.title) should be reduced or moved if the warm-up feels flat. Do not let the schedule override poor sleep."

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (isVeryLowSleep(context) ? 16 : 8),
            uniquenessScore: 86,
            result: CoachDayPriorityResult(
                focus: .tomorrowPlanRisk,
                level: level(for: score),
                reason: "The planned session conflicts with current readiness.",
                activity: activity,
                overridesTimingFocus: true,
                priority: .planChallenge,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .adjustment,
                limiter: isVeryLowSleep(context) ? .sleep : .trainingReadiness,
                messageFamily: .planAdjustment,
                title: "Reduce today's intensity",
                message: "\(activity.title) is not the problem; the ceiling is. Poor sleep makes intensity expensive today, so start easier and be willing to turn this into easier work.",
                supportBullets: [
                    "Start below planned effort",
                    "Stop if warm-up feels flat",
                    "Move intensity to a better day"
                ],
                whyThisMatters: "A hard session after very low sleep can cost recovery without producing the quality you wanted.",
                reasons: reasons,
                planChallenge: challenge
            )
        )
    }

    private static func stateBasedTrainingRecommendationCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil,
              context.activityContext.laterTodayActivity == nil,
              activeMeal(in: context) == nil,
              !context.dayContext.hasMeaningfulLoadCompleted,
              context.dayContext.upcomingTrainingActivities.isEmpty else {
            return nil
        }

        guard !isEveningOrLater(context),
              !isLateNight(context) else {
            return nil
        }

        let yesterdayHadLoad = context.brain.past.hasHighActivityLoad ||
            context.brain.past.completedWorkoutsCount >= 2
        let hasLoggedActivityContext = !context.dayContext.allActivities.isEmpty
        let nutritionHasStarted = nutritionHasStarted(context)
        let noPlanReason = nutritionHasStarted ? "Nutrition has started." : "No activity is planned."

        let stateIsLimited = recoveryIsLow(context) ||
            sleepIsPoor(context) ||
            isVeryLowSleep(context)

        if !stateIsLimited,
           hydrationIsBehind(context) || fuelIsBehind(context) {
            return nil
        }

        let stateIsStrong = strongRecovery(in: context) &&
            !recoveryIsLow(context) &&
            !sleepIsPoor(context) &&
            !isVeryLowSleep(context)

        if stateIsLimited {
            return PriorityCandidate(
                priorityScore: 76,
                insightScore: 90,
                uniquenessScore: 90,
                result: CoachDayPriorityResult(
                    focus: .recoveryNeeded,
                    level: .important,
                    reason: hasLoggedActivityContext
                        ? "Logged training or movement context exists, and current state should lead the next recommendation."
                        : "\(noPlanReason) Current state should lead the day.",
                    activity: nil,
                    overridesTimingFocus: true,
                    priority: .recovery,
                    strength: .high,
                    confidence: 0.84,
                    mode: .recovery,
                    limiter: recoveryIsLow(context) ? .recovery : .sleep,
                    messageFamily: .recovery,
                    todayTitle: "Recovery leads today",
                    todayMessage: "Keep the day easy.",
                    title: "Make this a recovery-led day",
                    message: hasLoggedActivityContext
                        ? "The day already has context, and your body is not asking for extra load. I would keep the next block easy and let recovery improve first."
                        : "Your body is not asking for extra load. I would keep movement easy and let recovery improve first.",
                    supportBullets: [
                        "Easy walk or mobility",
                        "No forced intensity",
                        "Protect tonight's sleep"
                    ],
                    whyThisMatters: "When readiness is limited, adding training usually costs more than it gives.",
                    reasons: [
                        hasLoggedActivityContext ? "The day already contains logged training or movement context." : noPlanReason,
                        "Recovery or sleep is limiting the day."
                    ],
                    horizon: yesterdayHadLoad ? .trend : .today,
                    objective: .recoveryDay,
                    opportunity: .recoveryWindow,
                    interventionValue: .useful,
                    completionState: .goodEnough
                )
            )
        }

        if stateIsStrong {
            let score = yesterdayHadLoad ? 64.0 : 82.0

            return PriorityCandidate(
                priorityScore: score,
                insightScore: yesterdayHadLoad ? 76 : 94,
                uniquenessScore: 88,
                result: CoachDayPriorityResult(
                    focus: .dailyOverview,
                    level: yesterdayHadLoad ? .useful : .important,
                    reason: hasLoggedActivityContext
                        ? "Logged training or movement context exists, and readiness should guide the day without inventing training preparation."
                        : "\(noPlanReason) Readiness should guide the day without inventing training preparation.",
                    activity: nil,
                    overridesTimingFocus: true,
                    priority: .stable,
                    strength: yesterdayHadLoad ? .medium : .high,
                    confidence: 0.82,
                    mode: .opportunity,
                    limiter: CoachLimiter.none,
                    messageFamily: .stable,
                    todayTitle: yesterdayHadLoad ? "Keep it light" : "Good day to train",
                    todayMessage: yesterdayHadLoad ? "Use easy movement." : "Add a useful session.",
                    title: yesterdayHadLoad ? "Use a light session" : "Good day to train",
                    message: yesterdayHadLoad
                        ? "Readiness looks good, but recent load still matters. I would choose easy aerobic work, mobility, or a short quality session."
                        : (hasLoggedActivityContext
                            ? "Your state looks good and the day is already started. If you add training, make it one clear useful block: light aerobic, strength, or easy strength depending on your goal."
                            : "Your state looks good. I would add one useful training block today: light aerobic, strength, or an easy workout depending on your goal."),
                    supportBullets: yesterdayHadLoad
                        ? ["Keep intensity low", "Move well", "Do not turn it into a hard day"]
                        : ["Start easy", "Choose one clear session", "Build only if you feel good"],
                    whyThisMatters: "A coach should use good readiness as an opportunity, not only react to missing water or food.",
                    reasons: [
                        hasLoggedActivityContext ? "No training remains, but the day already has logged movement context." : noPlanReason,
                        "Recovery and sleep are supportive.",
                        yesterdayHadLoad ? "Recent load lowers the ceiling." : "Recent load does not block training."
                    ],
                    horizon: yesterdayHadLoad ? .trend : .today,
                    objective: .buildReadiness,
                    opportunity: .highReadiness,
                    interventionValue: .useful,
                    completionState: .goodEnough
                )
            )
        }

        return PriorityCandidate(
            priorityScore: 60,
            insightScore: 74,
            uniquenessScore: 78,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: hasLoggedActivityContext
                    ? "Logged training or movement context exists, so the coach should guide the day from state."
                    : "\(noPlanReason) The coach should guide the day from state.",
                activity: nil,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.70,
                mode: .reinforcement,
                limiter: .none,
                messageFamily: .stable,
                todayTitle: "Choose the day",
                todayMessage: "Your state is neutral.",
                title: "Choose a useful block",
                message: hasLoggedActivityContext
                    ? "The day is already in motion and there is no clear limiter. I would choose one simple next block: easy movement, mobility, or quality work."
                    : "There is no clear limiter. I would choose one simple block: easy movement, mobility, or an easy workout.",
                supportBullets: [
                    "Pick one clear session",
                    "Do not overbuild the day",
                    "Adjust by feel"
                ],
                whyThisMatters: hasLoggedActivityContext
                    ? "A day with logged movement should be guided from what already happened, not treated as empty."
                    : "A blank plan still needs coaching, not target chasing.",
                reasons: [
                    hasLoggedActivityContext ? "The day already contains logged training or movement context." : noPlanReason,
                    "No critical limiter is dominant."
                ],
                objective: .maintainCourse,
                interventionValue: .useful,
                completionState: .goodEnough
            )
        )
    }

    private static func expectedHydrationRatio(forHour hour: Int) -> Double {
        HumanBrain.expectedHydrationProgress(for: hour)
    }

    private static func expectedNutritionRatio(forHour hour: Int) -> Double {
        switch hour {
        case ..<8:
            return 0.05
        case 8..<11:
            return 0.20
        case 11..<14:
            return 0.40
        case 14..<17:
            return 0.55
        case 17..<20:
            return 0.75
        case 20..<23:
            return 0.90
        default:
            return 0.95
        }
    }

    private static func hydrationCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        let hour = localHour(in: context)
        guard !hydrationGoalReached(context) else { return nil }

        let contextActivity = context.activityContext.preparingActivity ??
            context.activityContext.activeActivity ??
            context.activityContext.laterTodayActivity

        let heatActivity = heatHydrationActivity(in: context)
        let heatSoon = heatActivity != nil
        let heatMinutesUntil = heatActivity.flatMap { minutesUntil($0, in: context) }
        let heatVerySoon = context.activityContext.activeActivity?.id == heatActivity?.id ||
            heatMinutesUntil.map { $0 <= 30 } == true
        let activity = heatActivity ??
            contextActivity.flatMap {
                CoachActivityContextResolverV3.kind(for: $0) == .heat ? nil : $0
            }

        let enduranceDemand = activity.map {
            CoachActivityContextResolverV3.kind(for: $0) == .endurance
        } ?? false

        let activityIsImmediate = context.activityContext.preparingActivity != nil ||
            context.activityContext.activeActivity != nil

        let ratio = hydrationRatio(context)
        let expectedRatio = expectedHydrationRatio(forHour: hour)
        let criticallyBehindForTime = ratio < max(0.15, expectedRatio - 0.30)
        let sweatOrLoadDemand = isHighLoadDay(context) || context.actualLoad.activeCalories >= 1_200
        let activityMinutesUntil = activity.flatMap { minutesUntil($0, in: context) }
        let longEnduranceSoon = enduranceDemand &&
            (activity?.effectiveDurationMinutes ?? activity?.durationMinutes ?? 0) >= 75 &&
            activityMinutesUntil.map { $0 <= 240 } == true
        let hardTrainingPreparationPressure = activityIsImmediate &&
            activity.map { activity in
                let load = CoachActivityContextResolverV3.load(for: activity)
                return isTraining(activity) &&
                    (
                        load == .high ||
                        load == .extreme ||
                        activity.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes
                    )
            } == true
        let postLoadPressure = context.dayContext.hasMeaningfulLoadCompleted ||
            context.activityContext.recentlyCompletedActivity.map { isMeaningfulPostActivityTraining($0) } == true
        let hydrationMayLead = hydrationCanLeadAsPrimary(in: context)

        guard hydrationMayLead else {
            return nil
        }

        guard hydrationIsBehind(context) else { return nil }

        var score = 26.0
        var reasons: [String] = ["Fluids matter for the current context."]

        if criticallyBehindForTime {
            score += 18
            reasons.append("Water progress is behind what is reasonable for this context.")
        }

        if ratio < 0.30 && (hour >= 12 || heatSoon || enduranceDemand || activityIsImmediate) {
            score += 20
            reasons.append("Water progress is very low for the situation.")
        } else if ratio < 0.45 && hour >= 15 {
            score += 12
            reasons.append("Water progress is materially behind for the afternoon or evening.")
        }

        if heatSoon {
            score += 36
            reasons.append("Heat exposure is inside the hydration preparation window.")
        }

        if heatSoon && ratio >= 0.50 && !heatVerySoon {
            score -= 32
            reasons.append("Hydration is already past half of goal, so heat does not lead yet.")
        }

        if longEnduranceSoon {
            score += 18
            reasons.append("Long endurance work is inside the hydration preparation window.")
        }

        if postLoadPressure {
            score += 16
            reasons.append("Completed load makes fluids part of recovery now.")
        } else if sweatOrLoadDemand {
            score += 14
            reasons.append("Sweat loss or load is likely higher today.")
        }

        if hardTrainingPreparationPressure {
            score += 10
            reasons.append("This blocks the next immediate activity.")
        }

        if severeFatigueDominates(context) && !heatSoon && !enduranceDemand && !activityIsImmediate {
            score -= 30
            reasons.append("Fatigue is the broader problem, so hydration supports rather than leads.")
        }

        if severeFatigueDominates(context) && heatSoon {
            score -= 14
            reasons.append("Heat is risky because fatigue is already high.")
        }

        guard score >= 52 else { return nil }

        let hydrationNarrativeIsPreparation = heatSoon || longEnduranceSoon || hardTrainingPreparationPressure
        let title: String
        if heatSoon {
            title = "Prepare for heat"
        } else if hydrationNarrativeIsPreparation, let activity {
            title = "Prepare for \(displayName(activity).lowercased())"
        } else if postLoadPressure || sweatOrLoadDemand {
            title = "Support recovery"
        } else {
            title = "Support readiness"
        }

        let message = heatSoon
            ? "Do not start heat exposure dry. If you cannot bring fluids up calmly, skip or shorten it."
            : "Fluids matter for the next decision. Sip steadily now, but do not chase the full daily target all at once."
        let narrativeFocus: CoachDayFocus = hydrationNarrativeIsPreparation ? .prepareForActivity : .recoveryNeeded
        let narrativePriority: CoachDayPriority = hydrationNarrativeIsPreparation ? .performance : .recovery
        let narrativeLimiter: CoachLimiter = hydrationNarrativeIsPreparation ? .timing : .recovery
        let narrativeFamily: CoachMessageFamily = hydrationNarrativeIsPreparation ? .performance : .recovery

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (heatSoon ? 18 : 6),
            uniquenessScore: heatSoon ? 95 : 68,
            result: CoachDayPriorityResult(
                focus: narrativeFocus,
                level: level(for: score),
                reason: heatSoon ? "Fluids are low before heat exposure." : "Fluids are low enough to affect the next useful decision.",
                activity: activity,
                overridesTimingFocus: heatSoon || activityIsImmediate || score >= 74,
                priority: narrativePriority,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: heatSoon ? .warning : .opportunity,
                limiter: narrativeLimiter,
                messageFamily: narrativeFamily,
                title: title,
                message: message,
                supportBullets: heatSoon
                    ? ["Sip steadily before sauna", "Add electrolytes if available", "Skip heat if you still feel dry"]
                    : ["Sip steadily for the next hour", "Use thirst and context", "Do not force a full-day catch-up"],
                whyThisMatters: heatSoon
                    ? "Heat magnifies a fluid gap quickly; starting dry turns a recovery tool into extra stress."
                    : "Hydration matters most when timing, heat, training, or accumulated load makes it relevant.",
                reasons: reasons
            )
        )
    }

    private static func fuelingCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        let hour = localHour(in: context)
        let signals = fuelBehindSignals(in: context)
        let hardActivity = signals.hardActivitySoon
        let tomorrowHard = context.tomorrowDemand.isHard
        let ratio = nutritionRatio(context)
        let protein = proteinRatio(context)
        let expectedRatio = expectedNutritionRatio(forHour: hour)
        let criticallyBehindForTime = ratio < max(0.10, expectedRatio - 0.35)
        let highLoadFuelingRequired = ratio < 0.40 &&
            context.actualLoad.activeCalories > 800
        let severeReadinessRisk = (ratio < 0.15 || signals.carbsRatio < 0.15) &&
            (recoveryIsLow(context) || isVeryLowSleep(context) || context.brain.strain == .veryHigh)

        guard fuelIsBehind(context) else { return nil }

        if heatHydrationActivity(in: context) != nil,
           hydrationRatio(context) < 0.40,
           hardActivity == nil {
            return nil
        }

        if hardActivity == nil &&
            !tomorrowHard &&
            !isHighLoadDay(context) &&
            !highLoadFuelingRequired &&
            !signals.postTrainingRefuelRequired &&
            !severeReadinessRisk {
            return nil
        }

        var score = 26.0
        var reasons: [String] = ["Nutrition is behind for the current context."]

        if criticallyBehindForTime {
            score += 18
            reasons.append("Food progress is behind what is reasonable for this time of day.")
        }

        if ratio < 0.20 || signals.carbsRatio < 0.20 {
            if hour >= 11 || hardActivity != nil || tomorrowHard || signals.postTrainingRefuelRequired {
                score += 26
                reasons.append("Calories or carbs are extremely low for the situation.")
            }
        } else if ratio < 0.45 && hour >= 14 {
            score += 14
            reasons.append("Calories are far behind for the afternoon or evening.")
        }

        if let hardActivity {
            score += context.activityContext.preparingActivity?.id == hardActivity.id ? 36 : 24
            reasons.append("\(hardActivity.title) needs usable energy.")
        }

        if signals.postTrainingRefuelRequired {
            score += 22
            reasons.append("A recent session needs recovery fuel.")
        }

        if isHighLoadDay(context) {
            score += 18
            reasons.append("Today's expenditure needs refueling.")
        }

        if highLoadFuelingRequired {
            score += 30
            reasons.append("Calories are below 40% after a high-output day.")
        }

        if protein < 0.25 && highLoadFuelingRequired {
            score += 18
            reasons.append("Protein is still very low for recovery.")
        } else if protein < 0.50 && (highLoadFuelingRequired || signals.postTrainingRefuelRequired || tomorrowHard) {
            score += 10
            reasons.append("Protein is behind for recovery.")
        }

        if tomorrowHard {
            score += 18
            reasons.append("Tomorrow's training depends on refueling tonight.")
        }

        if signals.carbsRatio < 0.35 && (hardActivity != nil || tomorrowHard || isHighLoadDay(context) || highLoadFuelingRequired) {
            score += 10
            reasons.append("Carbs are low for training demand.")
        }

        if severeFatigueDominates(context) && hardActivity == nil && !tomorrowHard && !signals.postTrainingRefuelRequired && ratio > 0.20 {
            score -= 18
            reasons.append("Fatigue is the broader limiter, so fueling supports recovery.")
        }

        guard score >= 52 else { return nil }

        let activity = hardActivity ??
            context.tomorrowContext?.primaryTrainingActivity ??
            context.activityContext.laterTodayActivity
        let title: String
        let message: String
        let narrativeFocus: CoachDayFocus
        let narrativePriority: CoachDayPriority
        let narrativeLimiter: CoachLimiter
        let narrativeFamily: CoachMessageFamily
        if let hardActivity {
            title = "Prepare for training"
            message = "\(hardActivity.title) needs energy available before it starts. Eat something simple now, then keep the session honest."
            narrativeFocus = .prepareForActivity
            narrativePriority = .performance
            narrativeLimiter = .timing
            narrativeFamily = .performance
        } else if signals.postTrainingRefuelRequired || highLoadFuelingRequired {
            title = "Recover from training"
            message = protein < 0.50
                ? "The useful move is recovery support. Add a real meal with protein so the work you banked has something to adapt with."
                : "The useful move is recovery support, not chasing calories. Add a simple meal that replaces what the session spent."
            narrativeFocus = signals.postTrainingRefuelRequired ? .postActivityRecovery : .recoveryNeeded
            narrativePriority = .recovery
            narrativeLimiter = .recovery
            narrativeFamily = .recovery
        } else if tomorrowHard {
            title = "Protect tomorrow"
            message = "The gap is not just about calories. Tomorrow's training depends on replacing enough energy tonight to recover from today."
            narrativeFocus = .tomorrowPlanRisk
            narrativePriority = .planChallenge
            narrativeLimiter = .upcomingTraining
            narrativeFamily = .planAdjustment
        } else {
            title = "Support recovery"
            message = "Fuel is behind for this point in the day. Add something useful, but do not let nutrition override the bigger training or recovery decision."
            narrativeFocus = .recoveryNeeded
            narrativePriority = .recovery
            narrativeLimiter = .recovery
            narrativeFamily = .recovery
        }

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (hardActivity != nil ? 16 : 6) + (tomorrowHard ? 8 : 0),
            uniquenessScore: hardActivity != nil ? 88 : 66,
            result: CoachDayPriorityResult(
                focus: narrativeFocus,
                level: level(for: score),
                reason: "Fuel is contextually relevant to the next training or recovery step.",
                activity: activity,
                overridesTimingFocus: context.activityContext.preparingActivity != nil || context.activityContext.activeActivity != nil || score >= 80,
                priority: narrativePriority,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: hardActivity != nil ? .warning : .opportunity,
                limiter: narrativeLimiter,
                messageFamily: narrativeFamily,
                title: title,
                message: message,
                supportBullets: ["Add easy carbs plus protein", "Keep it digestible", tomorrowHard ? "Review tomorrow after breakfast" : "Match food to the next block"],
                whyThisMatters: "Under-fueling matters most when load, timing, or tomorrow's plan makes it relevant.",
                reasons: reasons,
                planChallenge: tomorrowHard && score >= 82
                    ? "If you cannot refuel tonight, reduce tomorrow's endurance or intensity."
                    : nil
            )
        )
    }

    private static func performanceReadinessCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        let activity = context.activityContext.preparingActivity ?? context.activityContext.laterTodayActivity
        guard let activity, isTraining(activity) else { return nil }
        guard !fuelIsBehind(context), !hydrationIsBehind(context), !recoveryIsLow(context), !isVeryLowSleep(context) else { return nil }
        if context.activityContext.preparingActivity == nil,
           minutesUntil(activity, in: context).map({ $0 > 240 }) == true {
            return nil
        }

        var score = 46.0
        var reasons = ["Readiness signals are strong enough for the planned training."]
        if recoveryPercent(context).map({ $0 >= 80 }) ?? (context.brain.recovery == .strong || context.brain.readiness == .good) {
            score += 14
            reasons.append("Recovery is high.")
        }
        if sleepHours(context).map({ $0 >= 7.0 }) ?? (context.brain.sleep == .strong) {
            score += 10
            reasons.append("Sleep supports training.")
        }
        if hydrationRatio(context) >= 0.75 {
            score += 8
            reasons.append("Hydration is in a good range.")
        }
        if nutritionRatio(context) >= 0.60 {
            score += 8
            reasons.append("Fuel is adequate.")
        }
        if context.brain.past.hasHighActivityLoad == false && context.brain.past.completedWorkoutsCount == 0 {
            score += 4
        } else if context.brain.past.hasHighActivityLoad && recoveryPercent(context).map({ $0 >= 85 }) ?? false {
            reasons.append("Recent trend is improving enough to train.")
        }
        let activityName = displayName(activity)
        let preparingNow = context.activityContext.preparingActivity?.id == activity.id
        let title = preparingNow ? "Prepare for \(activityName.lowercased())" : "Build toward \(activityName.lowercased())"
        let message = preparingNow
            ? "\(activityName) is the next training demand. Keep the setup calm and arrive fresh."
            : "\(activityName) is still later today. Keep the basics steady without chasing the session early."

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score - 4,
            uniquenessScore: 54,
            result: CoachDayPriorityResult(
                focus: .performanceReadiness,
                level: level(for: score),
                reason: "No major blockers are ahead of the next training session.",
                activity: activity,
                overridesTimingFocus: false,
                priority: .performance,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .reinforcement,
                limiter: CoachLimiter.none,
                messageFamily: .performance,
                title: title,
                message: message,
                supportBullets: ["Start below your ceiling", "Keep fluids steady", "Build only if the body agrees"],
                whyThisMatters: "Good readiness is useful, but the best sessions still begin with a calm opening.",
                reasons: reasons
            )
        )
    }

    private static func activeExecutionCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard let active = context.activityContext.activeActivity else { return nil }

        let kind = CoachActivityContextResolverV3.kind(for: active)
        let limiter = activeSessionLimiter(in: context)
        let limiterRequiresCaution = limiter != .timing && limiter != .none
        let score = kind == .recovery ? 52.0 : (limiterRequiresCaution ? 82.0 : 62.0)
        let activeName = displayName(active).lowercased()
        let runningCaution = isRunning(active) && limiterRequiresCaution

        return PriorityCandidate(
            priorityScore: score,
            insightScore: limiterRequiresCaution ? score + 8 : score - 2,
            uniquenessScore: limiterRequiresCaution ? 86 : 50,
            result: CoachDayPriorityResult(
                focus: .activeActivity,
                level: level(for: score),
                reason: limiterRequiresCaution
                    ? "An activity is live, so limiters shape execution instead of replacing the session."
                    : "An activity is live and owns the current coaching narrative.",
                activity: active,
                overridesTimingFocus: false,
                priority: .activeSession,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .execution,
                limiter: limiter,
                messageFamily: .performance,
                todayTitle: activeSessionTitle(
                    kind: kind,
                    runningCaution: runningCaution
                ),
                todayMessage: activeSessionMessage(
                    kind: kind,
                    activeName: activeName,
                    runningCaution: runningCaution
                ),
                title: activeSessionTitle(
                    kind: kind,
                    runningCaution: runningCaution
                ),
                message: runningCaution
                    ? "The run is already live. Keep effort easy, avoid adding intensity, and finish with reserve."
                    : kind == .recovery
                    ? "Use this block to feel better afterward, not to prove fitness."
                    : "You are in \(displayName(active).lowercased()) now. Keep the effort repeatable and make small adjustments before fatigue gets loud.",
                supportBullets: runningCaution
                    ? ["Keep an easy pace", "Shorten if needed", "Finish with reserve"]
                    : kind == .recovery
                    ? ["Stay comfortable", "Let breathing settle", "Finish fresher than you started"]
                    : ["Start easy", "Sip before you feel dry", "Back off if form drops"],
                whyThisMatters: runningCaution
                    ? "Load is already accumulated today, so recovery changes the effort ceiling but does not replace the current workout."
                    : "Good execution is coaching too: keep the session useful without turning it into extra stress.",
                reasons: activeSessionReasons(limiter: limiter)
            )
        )
    }

    private static func activeSessionLimiter(in context: CoachDecisionContext) -> CoachLimiter {
        if isVeryLowSleep(context) || context.brain.sleep == .veryShort {
            return .sleep
        }
        if severeFatigueDominates(context) || isHighLoadDay(context) {
            return .accumulatedFatigue
        }
        if recoveryIsLow(context) || sleepIsPoor(context) {
            return .recovery
        }
        if hydrationIsCriticallyBehind(context) || hydrationIsBehind(context) {
            return .hydration
        }
        if fuelIsCriticallyBehind(context) || fuelIsBehind(context) {
            return .fueling
        }
        if context.tomorrowDemand.isHard {
            return .upcomingTraining
        }
        return .timing
    }

    private static func activeSessionTitle(
        kind: CoachActivityKindV3,
        runningCaution: Bool
    ) -> String {
        if runningCaution {
            return "Keep this run easy"
        }
        if kind == .recovery {
            return "Keep recovery easy"
        }
        return "Control the session"
    }

    private static func activeSessionMessage(
        kind: CoachActivityKindV3,
        activeName: String,
        runningCaution: Bool
    ) -> String {
        if runningCaution {
            return "The run is already live. Keep effort easy, avoid adding intensity, and finish with reserve."
        }
        return kind == .recovery ? "Let this stay restorative." : "Execute the current block first."
    }

    private static func activeSessionReasons(limiter: CoachLimiter) -> [String] {
        [
            "Current session is active.",
            "Active session owns the primary narrative.",
            "Limiter=\(limiter.label) shapes execution but cannot replace activeActivity."
        ]
    }

    private static func isRunning(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.title) \(activity.type)".lowercased()
        return text.contains("run") || text.contains("jog")
    }

    private static func postActivityCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard let recent = context.activityContext.recentlyCompletedActivity else { return nil }
        guard isMeaningfulPostActivityTraining(recent) else { return nil }
        let needsFuel = fuelIsBehind(context)
        let needsHydration = hydrationIsBehind(context)
        let needsRecovery = recoveryIsLow(context)

        let score = 54.0 +
            (needsFuel ? 8 : 0) +
            (needsHydration ? 8 : 0) +
            (needsRecovery ? 8 : 0)

        let isLateHardTraining = isEveningOrLater(context) && isTraining(recent)
        let load = CoachActivityContextResolverV3.load(for: recent)
        let isHardTraining = isTraining(recent) &&
            (load == .high || load == .extreme || recent.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes)
        let title = isLateHardTraining && isHardTraining ? "Protect the work you just did" : "Make the workout count"
        let message = isLateHardTraining && (load == .high || load == .extreme || recent.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes)
            ? "The hard part is already done. Keep protein and fluids light, then let sleep take over."
            : "The training is finished. Recovery now decides how much of it you keep: fluids, food, and no extra intensity for the next block."
        var reasons = ["A meaningful activity just finished."]
        if let ignored = newerCompletedNonAnchor(after: recent, in: context) {
            reasons.append("Ignored newer completion '\(displayName(ignored))' as recovery anchor because it was shorter or less meaningful than '\(displayName(recent))'.")
        }

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (needsFuel || needsHydration || needsRecovery ? 6 : 10),
            uniquenessScore: needsFuel || needsHydration || needsRecovery ? 70 : 76,
            result: CoachDayPriorityResult(
                focus: .postActivityRecovery,
                level: level(for: score),
                reason: "A recent session makes recovery, fuel, and hydration the next useful step.",
                activity: recent,
                overridesTimingFocus: false,
                priority: .recovery,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .recovery,
                limiter: .insufficientRecoveryTime,
                messageFamily: .recovery,
                title: title,
                message: message,
                supportBullets: supportBullets(
                    primary: "Start recovery now",
                    context: context,
                    includeFuel: needsFuel || isHardTraining,
                    includeHydration: needsHydration || isHardTraining,
                    includeSleep: isEveningOrLater(context)
                ),
                whyThisMatters: "Skipping the recovery step makes today's work more expensive tomorrow.",
                reasons: reasons
            )
        )
    }

    private static func isDaytimePostWorkoutRecoveryWindow(_ context: CoachDecisionContext) -> Bool {
        guard !isEveningOrLater(context) else { return false }
        return meaningfulCompletedTraining(in: context, maximumMinutesSinceEnd: 360) != nil
    }

    private static func meaningfulCompletedTraining(
        in context: CoachDecisionContext,
        maximumMinutesSinceEnd: Int
    ) -> PlannedActivity? {
        context.dayContext.completedTrainingActivities
            .filter { activity in
                guard isMeaningfulPostActivityTraining(activity) else { return false }
                let minutesSinceEnd = Int(context.dayContext.now.timeIntervalSince(activityEnd(activity)) / 60)
                return minutesSinceEnd >= 0 && minutesSinceEnd <= maximumMinutesSinceEnd
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    private static func recentQuickCompletionCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil,
              context.activityContext.recentlyCompletedActivity == nil,
              let completed = recentCompletedActivity(in: context, maximumMinutes: 120) else {
            return nil
        }

        guard !isFoodMeal(completed), !CoachCanonicalDayState.isHydrationLog(completed) else { return nil }
        guard !isMeaningfulPostActivityTraining(completed) else { return nil }

        let kind = CoachActivityContextResolverV3.kind(for: completed)
        guard kind == .workout || kind == .endurance || kind == .recovery || kind == .heat else {
            return nil
        }
        if kind == .recovery || kind == .heat {
            guard completedActivityIsWithinHoldWindow(
                completed,
                context: context,
                maximumMinutes: 60
            ) else {
                return nil
            }
        }

        let title: String
        let message: String
        let support: [String]
        if kind == .workout || kind == .endurance {
            title = "Small session logged"
            message = "\(displayName(completed)) is done. It was short enough that it does not change the whole day, but it still counts; keep the next block steady."
            support = ["Keep the next block easy", "Hydrate normally", "Do not add extra intensity just to compensate"]
        } else {
            title = "Recovery action logged"
            message = "\(displayName(completed)) is done. Good, but do not turn a small recovery action into a bigger task; let it support the day quietly."
            support = ["Keep recovery easy", "Return to the day calmly", "Avoid stacking intensity"]
        }

        return PriorityCandidate(
            priorityScore: 54,
            insightScore: 62,
            uniquenessScore: 70,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: "A short completed activity is recent enough to remember, but not heavy enough for post-workout recovery.",
                activity: completed,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.68,
                mode: .reinforcement,
                limiter: CoachLimiter.none,
                messageFamily: .stable,
                todayTitle: title,
                todayMessage: "Acknowledge it, then stay steady.",
                title: title,
                message: message,
                supportBullets: support,
                whyThisMatters: "Small actions should be acknowledged without pretending they created a major recovery need.",
                reasons: ["A completed activity ended within the recent-memory window."]
            )
        )
    }

    private static func activeMealCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil,
              context.activityContext.recentlyCompletedActivity == nil,
              let meal = activeMeal(in: context) else {
            return nil
        }

        let laterTraining = context.dayContext.upcomingTrainingActivities.first
        let hydrationBehindNow = hydrationIsBehind(context)
        let title = laterTraining == nil ? "Use this meal well" : "Make this meal useful"
        let message: String
        if let laterTraining {
            message = "\(displayName(meal)) is the useful move now. Keep it digestible, bring fluids up steadily, and let it set up \(displayName(laterTraining).lowercased()) instead of turning the day into target chasing."
        } else if hydrationBehindNow {
            message = "\(displayName(meal)) is already the right anchor. Eat normally, add fluids steadily, and use the next hour to bring the basics back up."
        } else {
            message = "\(displayName(meal)) is the current useful step. Eat normally, then keep the day steady instead of inventing another task."
        }

        var support = ["Eat normally", "Keep it digestible"]
        if hydrationBehindNow {
            support.insert("Add 300-500 ml over the next hour", at: 0)
        }
        if laterTraining != nil {
            support.append("Save heavier work for training")
        } else {
            support.append("Return to the day calmly")
        }

        return PriorityCandidate(
            priorityScore: 62,
            insightScore: hydrationBehindNow ? 78 : 68,
            uniquenessScore: 78,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: "A meal is active, so the useful coaching move is to anchor the next block around it.",
                activity: meal,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.72,
                mode: .reinforcement,
                limiter: CoachLimiter.none,
                messageFamily: .stable,
                todayTitle: title,
                todayMessage: laterTraining == nil ? "Eat, hydrate, then move on." : "Use food as setup.",
                title: title,
                message: message,
                supportBullets: Array(support.prefix(3)),
                whyThisMatters: "A coach should use the current real-world step instead of ignoring it because it is not a workout.",
                reasons: ["A food meal is currently active.", "No active workout or recent workout should override it."]
            )
        )
    }

    private static func trainingReadinessWarningCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard let result = trainingReadinessWarning(in: context) else { return nil }

        return PriorityCandidate(
            priorityScore: 78,
            insightScore: 88,
            uniquenessScore: 82,
            result: result.withScores(
                priorityScore: 78,
                insightScore: 88,
                uniquenessScore: 82,
                decisionScore: 0
            )
        )
    }

    private static func dayManagementCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        if let stableDay = stableDayAfterCompletedLightActivityCandidate(in: context) {
            return stableDay
        }

        if let recoveryReinforcement = completedRecoveryReinforcementCandidate(in: context) {
            return recoveryReinforcement
        }

        if context.dayContext.skippedActivities.isEmpty == false ||
            context.dayContext.missedActivities.isEmpty == false {
            return PriorityCandidate(
                priorityScore: 48,
                insightScore: 64,
                uniquenessScore: 80,
                result: CoachDayPriorityResult(
                    focus: .dailyOverview,
                    level: .useful,
                    reason: "A missed activity is context, not the whole day.",
                    activity: context.activityContext.laterTodayActivity,
                    overridesTimingFocus: true,
                    priority: .stable,
                    strength: .medium,
                    confidence: 0.66,
                    mode: .reinforcement,
                    limiter: CoachLimiter.none,
                    messageFamily: .stable,
                    todayTitle: "Reset the day",
                    todayMessage: "One miss does not define it.",
                    title: "Reset the day",
                    message: "Missing one block does not define the day. Use the next useful choice to get back into rhythm without trying to repay it.",
                    supportBullets: ["Return to the plan", "Do not double the workload", "Keep the next step simple"],
                    whyThisMatters: "Trying to compensate often adds more fatigue than value.",
                    reasons: ["At least one planned activity was missed or skipped."]
                )
            )
        }

        if context.dayContext.hasMeaningfulLoadCompleted,
           hasNoMeaningfulPerformanceWorkLeft(context),
           !fuelIsBehind(context),
           !hydrationIsBehind(context),
           !recoveryIsLow(context) {
            return PriorityCandidate(
                priorityScore: 46,
                insightScore: 62,
                uniquenessScore: 78,
                result: CoachDayPriorityResult(
                    focus: .dailyOverview,
                    level: .useful,
                    reason: "The key work is already complete and no blocker is louder.",
                    activity: nil,
                    overridesTimingFocus: true,
                    priority: .stable,
                    strength: .medium,
                    confidence: 0.70,
                    mode: .reinforcement,
                    limiter: CoachLimiter.none,
                    messageFamily: .stable,
                    todayTitle: "Keep the day simple",
                    todayMessage: "Protect the work already done.",
                    title: "Keep the day simple",
                    message: "The useful work is already banked. Keep the rest of the day simple and let recovery continue in the background.",
                    supportBullets: ["Stay flexible today", "Continue normal meals", "Consider a glass of water"],
                    whyThisMatters: "Adaptation comes from absorbing the work, not constantly adding more.",
                    reasons: ["Meaningful training is complete.", "No hard work remains today."]
                )
            )
        }

        if context.dayContext.dayType == .recovery,
           let recoveryActivity = context.activityContext.preparingActivity ?? context.activityContext.laterTodayActivity {
            let noMealsLogged = (context.nutritionContext?.mealsCount ?? context.dayContext.completedMealsCount) == 0 &&
                !context.brain.hasAnyFoodLogged
            let support = noMealsLogged
                ? ["Stay comfortable", "Eat normally at your next meal", "Finish fresher"]
                : ["Stay comfortable", "Keep breathing relaxed", "Finish fresher"]

            return PriorityCandidate(
                priorityScore: context.activityContext.preparingActivity == nil ? 48 : 58,
                insightScore: context.activityContext.preparingActivity == nil ? 70 : 78,
                uniquenessScore: 76,
                result: CoachDayPriorityResult(
                    focus: .dailyOverview,
                    level: context.activityContext.preparingActivity == nil ? .quiet : .useful,
                    reason: "Today is a recovery day, so movement should support recovery instead of performance.",
                    activity: recoveryActivity,
                    overridesTimingFocus: true,
                    priority: .stable,
                    strength: context.activityContext.preparingActivity == nil ? .low : .medium,
                    confidence: 0.64,
                    mode: .reinforcement,
                    limiter: CoachLimiter.none,
                    messageFamily: .stable,
                    todayTitle: "Recovery day",
                    todayMessage: "Keep movement easy.",
                    title: "Recovery day",
                    message: "The goal is to feel better afterward, not fitter by force. Keep the movement easy and let it do its job.",
                    supportBullets: support,
                    whyThisMatters: "Recovery work only works when it stays below training stress.",
                    reasons: ["No training stress is planned.", "Recovery movement is the main activity context."]
                )
            )
        }

        return nil
    }

    private static func emptyDayEveningCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil,
              context.activityContext.laterTodayActivity == nil,
              context.activityContext.nextUpcomingActivity == nil,
              context.dayContext.upcomingActivities.isEmpty,
              isEveningOrLater(context) else {
            return nil
        }

        if let recent = context.activityContext.recentlyCompletedActivity,
           isMeaningfulPostActivityTraining(recent) {
            return nil
        }

        let hydrationBehindNow = hydrationIsBehind(context)
        let fuelBehindNow = fuelIsBehind(context)
        let tomorrowDemand = CoachTomorrowDemandResolver.resolve(context: context)
        let tomorrowHard = tomorrowDemand.isHard
        let hasTomorrowDemand = tomorrowDemand.hasDemand
        let highLoadToday = isHighLoadDay(context) || context.dayContext.hasMeaningfulLoadCompleted
        let timeBucket = localTimeBucket(in: context)
        let lateNight = timeBucket == .lateNight
        let sleepLimited = sleepIsPoor(context) || isVeryLowSleep(context)
        let recoveryLimited = recoveryIsLow(context)
        let recentOverload = CoachLifecycleDecisionPipeline.recent7DayTrainingLoad(in: context) >= 7
        let noBasicsLogged = (context.nutritionContext?.mealsCount ?? 0) == 0 &&
            (context.nutritionContext?.waterCurrent ?? 0) <= 0.10 &&
            (context.nutritionContext?.caloriesCurrent ?? 0) <= 0
        let loadNeedsProtection = highLoadToday && (hasTomorrowDemand || sleepLimited || recoveryLimited || recentOverload)
        let severeEveningLimiter = protectTomorrowHasSafetyLimiter(context)

        guard hydrationBehindNow ||
                fuelBehindNow ||
                tomorrowHard ||
                hasTomorrowDemand ||
                loadNeedsProtection ||
                sleepLimited ||
                recoveryLimited ||
                lateNight else {
            return nil
        }

        let limiter: CoachLimiter
        let title: String
        let message: String
        let todayTitle: String
        let todayMessage: String
        let support: [String]
        let priority: CoachDayPriority
        let mode: CoachingMode
        let strength: CoachPriorityStrength
        let baseScore: Double
        let objective: CoachObjective
        let intervention: CoachInterventionValue
        let completion: CompletionState

        if highLoadToday && !loadNeedsProtection && !hydrationBehindNow && !fuelBehindNow {
            limiter = .none
            title = "The work is done"
            todayTitle = "Recovery is holding up"
            todayMessage = "Nothing important needs protecting."
            message = "The work is done, recovery is holding up well, and nothing important needs protecting tonight."
            support = ["Enjoy the evening", "Let recovery keep working", "No extra protection needed"]
            priority = .stable
            mode = .reinforcement
            strength = .medium
            baseScore = 91
            objective = .completeDay
            intervention = .low
            completion = .goodEnough
        } else if lateNight && (sleepLimited || recoveryLimited || hasTomorrowDemand || hydrationBehindNow || fuelBehindNow || recentOverload || noBasicsLogged) {
            if sleepLimited {
                limiter = .sleep
                title = "Protect the night"
                todayTitle = "Protect sleep"
                todayMessage = "Start fresh tomorrow."
                message = "The useful move now is sleep. Do not force food or water late; take a small sip only if thirsty and start fresh tomorrow."
                support = ["Do not chase missed targets", "Small sip only if thirsty", "Start fresh tomorrow"]
                priority = .sleepPreparation
                mode = .recovery
                strength = .high
                baseScore = 94
                objective = .completeDay
                intervention = .low
                completion = .goodEnough
            } else if recoveryLimited {
                limiter = .recovery
                title = "Wind the day down"
                todayTitle = "Wind the day down"
                todayMessage = "Nothing needs to be pushed tonight."
                message = "Recovery still needs protection tonight. Keep the evening calm."
                support = ["Keep the evening calm", "Avoid extra intensity", "Protect sleep"]
                priority = .recovery
                mode = .recovery
                strength = .high
                baseScore = 92
                objective = .completeDay
                intervention = .low
                completion = .goodEnough
            } else {
                limiter = .none
                title = "Wind the day down"
                todayTitle = "Wind the day down"
                todayMessage = "Nothing needs to be pushed tonight."
                message = "Recovery looked solid today. The main job now is to protect tomorrow."
                support = ["Keep the evening calm", "Close the day quietly", "Protect sleep"]
                priority = .stable
                mode = .reinforcement
                strength = .medium
                baseScore = 93
                objective = .completeDay
                intervention = .low
                completion = .goodEnough
            }
        } else if tomorrowHard && highLoadToday {
            limiter = .upcomingTraining
            title = "Protect tomorrow"
            todayTitle = "Protect tomorrow"
            todayMessage = "Recover tonight."
            message = "Today already carried enough load, and tomorrow asks for more. Skip extra intensity tonight, recover, and protect sleep."
            support = protectTomorrowEveningSupport(
                hydrationBehind: hydrationBehindNow,
                fuelBehind: fuelBehindNow
            )
            priority = .sleepPreparation
            mode = .recovery
            strength = severeEveningLimiter ? .critical : .high
            baseScore = 96
            objective = .protectTomorrow
            intervention = .high
            completion = .goodEnough
        } else if tomorrowHard {
            limiter = .upcomingTraining
            title = "Protect tomorrow"
            todayTitle = "Protect tomorrow"
            todayMessage = "Help tomorrow start better."
            message = "Protect sleep, avoid additional load, and finish hydration gradually."
            support = protectTomorrowEveningSupport(
                hydrationBehind: hydrationBehindNow,
                fuelBehind: fuelBehindNow
            )
            priority = .stable
            mode = .reinforcement
            strength = .high
            baseScore = 94
            objective = .protectTomorrow
            intervention = .useful
            completion = .goodEnough
        } else if hydrationBehindNow || fuelBehindNow {
            limiter = .none
            title = "Evening reset"
            todayTitle = "Evening reset"
            todayMessage = "Bring the basics back calmly."
            message = "Have a normal dinner, sip fluids gradually, and do not chase the whole day at once."
            support = eveningNutritionSupport(
                hydrationBehind: hydrationBehindNow,
                fuelBehind: fuelBehindNow,
                includeSleep: false
            )
            priority = .stable
            mode = .reinforcement
            strength = .medium
            baseScore = 92
            objective = .completeDay
            intervention = .useful
            completion = .goodEnough
        } else {
            limiter = .none
            title = highLoadToday ? "The work is done" : "Close the day"
            todayTitle = highLoadToday ? "Recovery is holding up" : "Close the day"
            todayMessage = highLoadToday ? "Nothing important needs protecting." : "Let recovery take over."
            message = highLoadToday
                ? "The work is done, recovery is holding up well, and nothing important needs protecting tonight."
                : "The day is basically done. Keep the evening calm, recover, and make tomorrow easier to start."
            support = highLoadToday
                ? ["Enjoy the evening", "Let recovery keep working", "No extra protection needed"]
                : ["Keep the evening calm", "Avoid extra intensity", "Protect sleep"]
            priority = .stable
            mode = .reinforcement
            strength = .medium
            baseScore = 90
            objective = .completeDay
            intervention = .low
            completion = .goodEnough
        }

        return PriorityCandidate(
            priorityScore: baseScore,
            insightScore: baseScore + 12,
            uniquenessScore: tomorrowHard || lateNight ? 90 : 82,
            result: CoachDayPriorityResult(
                focus: .eveningWindDown,
                level: strength.level,
                reason: emptyDayEveningSelectionReason(timeBucket),
                activity: context.tomorrowContext?.primaryTrainingActivity,
                overridesTimingFocus: true,
                priority: priority,
                strength: strength,
                confidence: tomorrowHard || lateNight ? 0.84 : 0.76,
                mode: mode,
                limiter: limiter,
                messageFamily: lateNight ? .sleep : .stable,
                todayTitle: todayTitle,
                todayMessage: todayMessage,
                title: title,
                message: message,
                supportBullets: support,
                whyThisMatters: tomorrowHard
                    ? "When tomorrow has meaningful load, the best evening move is to reduce friction and restore enough capacity."
                    : "Closing the day well keeps hydration and food useful without turning missed targets into panic.",
                reasons: emptyDayEveningReasons(
                    hydrationBehind: hydrationBehindNow,
                    fuelBehind: fuelBehindNow,
                    tomorrowHard: tomorrowHard,
                    highLoadToday: highLoadToday,
                    timeBucket: timeBucket
                ),
                horizon: tomorrowHard ? .tomorrow : .today,
                objective: objective,
                opportunity: tomorrowHard ? .consistencyWin : .none,
                interventionValue: intervention,
                interventionCostNote: "Chasing missed targets too aggressively can make the evening less recoverable.",
                completionState: completion
            )
        )
    }

    private static func primaryNutritionLimiter(
        hydrationBehind: Bool,
        fuelBehind: Bool,
        fallback: CoachLimiter
    ) -> CoachLimiter {
        if hydrationBehind { return .hydration }
        if fuelBehind { return .fueling }
        return fallback
    }

    private static func eveningNutritionSupport(
        hydrationBehind: Bool,
        fuelBehind: Bool,
        includeSleep: Bool
    ) -> [String] {
        var support: [String] = []

        if fuelBehind {
            support.append("Have a normal dinner")
        }
        if hydrationBehind {
            support.append("Sip fluids gradually")
        }
        support.append(includeSleep ? "Keep the evening calm" : "Do not chase the whole day")
        if includeSleep {
            support.append("Protect sleep")
        }

        return Array(support.prefix(3))
    }

    private static func protectTomorrowEveningSupport(
        hydrationBehind: Bool,
        fuelBehind: Bool
    ) -> [String] {
        var support = ["Skip extra intensity"]

        if hydrationBehind {
            support.append("Sip gradually tonight")
        }
        if fuelBehind {
            support.append("Keep food normal")
        }
        support.append("Protect sleep")

        return Array(support.prefix(3))
    }

    private static func protectTomorrowHasSafetyLimiter(_ context: CoachDecisionContext) -> Bool {
        isVeryLowSleep(context) ||
            veryLowRecovery(context) ||
            (hasHeatAheadToday(context) && hydrationIsCriticallyBehind(context)) ||
            hydrationRatio(context) < 0.20 ||
            fuelIsCriticallyBehind(context)
    }

    private static func emptyDayEveningReasons(
        hydrationBehind: Bool,
        fuelBehind: Bool,
        tomorrowHard: Bool,
        highLoadToday: Bool,
        timeBucket: LocalTimeBucket
    ) -> [String] {
        var reasons = ["No activities remain today.", emptyDayEveningSelectionReason(timeBucket)]
        if tomorrowHard { reasons.append("Tomorrow has meaningful training load.") }
        if highLoadToday { reasons.append("Today already accumulated meaningful load.") }
        if hydrationBehind { reasons.append("Hydration is behind, but should be restored gradually.") }
        if fuelBehind { reasons.append("Nutrition is behind, but should be handled as a normal evening meal.") }
        if timeBucket == .night { reasons.append("It is night, so sleep protection is becoming more important.") }
        if timeBucket == .lateNight { reasons.append("It is late enough that sleep is the useful intervention.") }
        return reasons
    }

    private static func emptyDayEveningSelectionReason(_ timeBucket: LocalTimeBucket) -> String {
        switch timeBucket {
        case .evening:
            return "It is evening and no activities remain today."
        case .night:
            return "It is night and no activities remain today."
        case .lateNight:
            return "It is late night and no activities remain today."
        case .afternoon:
            return "No activities remain today."
        }
    }

    private static func stableDayAfterCompletedLightActivityCandidate(
        in context: CoachDecisionContext
    ) -> PriorityCandidate? {
        guard CoachLightRecoveryStableDayPolicy.ownsStableDayAfterCompletedLightActivity(in: context) else {
            return nil
        }

        let upcomingRecovery = [
            context.activityContext.laterTodayActivity,
            context.activityContext.nextUpcomingActivity
        ]
        .compactMap { $0 }
        .first { CoachLightRecoveryStableDayPolicy.isRecoveryPlanModality($0) }

        return PriorityCandidate(
            priorityScore: 76,
            insightScore: 84,
            uniquenessScore: 88,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: "Light morning work is done and only recovery context remains.",
                activity: upcomingRecovery,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.78,
                mode: .reinforcement,
                limiter: CoachLimiter.none,
                messageFamily: .stable,
                todayTitle: "The day is on plan",
                todayMessage: "Nothing needs fixing.",
                title: "The day is on plan",
                message: "Morning movement is already done. Let the day stay calm — nothing special is needed before the remaining recovery block.",
                supportBullets: [
                    "Stay with today's rhythm",
                    "Calmly keep food and water on track",
                    "Nothing special is needed before sauna"
                ],
                whyThisMatters: "After light morning work, the value is a calm rhythm — not another prep push.",
                reasons: [
                    "Morning movement is already done.",
                    "Only recovery context remains today.",
                    "Recovery remains high."
                ]
            )
        )
    }

    private static func completedRecoveryReinforcementCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard !hasMeaningfulTrainingRemaining(context) else { return nil }
        guard let completed = context.dayContext.lastCompletedActivity else { return nil }
        guard isCompletedRecoveryReinforcementActivity(completed) else { return nil }
        guard completedActivityIsWithinHoldWindow(
            completed,
            context: context,
            maximumMinutes: 60
        ) else {
            return nil
        }

        let activityName = displayName(completed)
        let isHeat = CoachActivityContextResolverV3.kind(for: completed) == .heat
        let noMealsLogged = (context.nutritionContext?.mealsCount ?? context.dayContext.completedMealsCount) == 0 &&
            !context.brain.hasAnyFoodLogged
        let basicsAreLow = hydrationRatio(context) < 0.20 || nutritionRatio(context) < 0.35
        let neutralRecoveryTitle = basicsAreLow ? "Keep the day simple" : "Recovery day is on track"
        let neutralRecoveryMessage = basicsAreLow
            ? "\(activityName) is done. Keep the rest simple and build food and fluids gradually."
            : "\(activityName) is done. That supports the day; no post-workout recovery push is needed."

        var support = isHeat
            ? ["Keep the rest of the day easy", "Sip fluids calmly"]
            : ["Keep recovery easy", "Avoid adding intensity"]

        if noMealsLogged {
            support.append("Eat normally at your next meal")
        } else {
            support.append("Keep normal meals steady")
        }

        return PriorityCandidate(
            priorityScore: 88,
            insightScore: 94,
            uniquenessScore: 82,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: "A recovery activity is complete, and no post-workout recovery intervention is needed.",
                activity: completed,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.76,
                mode: .reinforcement,
                limiter: .none,
                messageFamily: .stable,
                todayTitle: isHeat ? "\(activityName) is done" : neutralRecoveryTitle,
                todayMessage: basicsAreLow ? "Build the day gradually." : "Keep the rest easy.",
                title: isHeat ? "\(activityName) is done" : neutralRecoveryTitle,
                message: isHeat
                    ? "\(activityName) is done. Keep the rest of the day easy and let it support recovery."
                    : neutralRecoveryMessage,
                supportBullets: Array(support.prefix(3)),
                whyThisMatters: "Recovery activities should reinforce restraint, not create another recovery task.",
                reasons: ["A recovery-oriented activity was completed.", "No meaningful training load needs post-workout recovery."]
            )
        )
    }

    private static func completedActivityIsWithinHoldWindow(
        _ activity: PlannedActivity,
        context: CoachDecisionContext,
        maximumMinutes: Int
    ) -> Bool {
        let minutesSinceEnd = Int(context.dayContext.now.timeIntervalSince(activityEnd(activity)) / 60)
        return minutesSinceEnd >= 0 && minutesSinceEnd <= maximumMinutes
    }

    private static func lightRecoveryOnlyDayWithoutIndependentDeficit(
        in context: CoachDecisionContext
    ) -> Bool {
        let completed = context.dayContext.completedActivities.filter {
            CoachLightRecoveryStableDayPolicy.isActuallyCompleted($0, now: context.dayContext.now)
        }
        guard !completed.isEmpty else { return false }
        guard completed.allSatisfy(CoachLightRecoveryStableDayPolicy.isLightRecoveryModality) else { return false }
        guard context.dayContext.completedTrainingStressScore < 2 else { return false }
        guard !context.dayContext.hasMeaningfulLoadCompleted else { return false }
        guard !recoveryIsLow(context), !sleepIsPoor(context) else { return false }
        guard context.tomorrowDemand.isHard == false else { return false }
        return true
    }

    private static func highReadinessOpportunityCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard !hasLiveOrImmediateActivity(context) else { return nil }
        guard !isEveningOrLater(context), !isOvernightBeforeDayStart(context) else { return nil }
        guard !fuelIsBehind(context), !hydrationIsBehind(context), !recoveryIsLow(context), !sleepIsPoor(context) else { return nil }
        guard !context.dayContext.hasMeaningfulLoadCompleted else { return nil }
        guard !context.tomorrowDemand.isHard else { return nil }

        let recoveryStrong = recoveryPercent(context).map { $0 >= 85 } ??
            (context.brain.recovery == .strong || context.brain.readiness == .excellent)
        let sleepStrong = sleepHours(context).map { $0 >= 7.5 } ??
            (context.brain.sleep == .strong)

        guard recoveryStrong && sleepStrong else { return nil }

        return PriorityCandidate(
            priorityScore: 34,
            insightScore: 72,
            uniquenessScore: 86,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: .useful,
                reason: "Recovery and sleep are strong, and no limiter needs intervention.",
                activity: context.activityContext.laterTodayActivity,
                overridesTimingFocus: true,
                priority: .stable,
                strength: .medium,
                confidence: 0.72,
                mode: .opportunity,
                limiter: CoachLimiter.none,
                messageFamily: .stable,
                todayTitle: "Good window today",
                todayMessage: "Use it calmly.",
                title: "Strong recovery day",
                message: "This is one of the better recovery windows. If you want to push meaningful work today, you have room, but there is nothing to force.",
                supportBullets: ["Choose meaningful work", "Start easy", "Keep the basics steady"],
                whyThisMatters: "High readiness is an opportunity, not pressure. The value is using it deliberately.",
                reasons: ["Recovery is high.", "Sleep supports the day.", "No limiter is asking for a correction."],
                objective: .buildReadiness,
                opportunity: .highReadiness,
                interventionValue: .useful,
                completionState: .complete
            )
        )
    }

    private static func contextualFallbackCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard !genericFallbackAllowed(in: context) else { return nil }
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil,
              context.activityContext.recentlyCompletedActivity == nil else {
            return nil
        }

        let hydrationBehindNow = hydrationIsBehind(context)
        let fuelBehindNow = fuelIsBehind(context)
        let recoveryLimited = recoveryIsLow(context) || sleepIsPoor(context) || isVeryLowSleep(context)
        let hasLoggedDay = !context.dayContext.allActivities.isEmpty
        let lastCompleted = context.dayContext.lastCompletedActivity
        let support: [String]
        let title: String
        let message: String
        let score: Double

        if hydrationBehindNow {
            title = "Bring the basics back up"
            message = hasLoggedDay
                ? "The day is already in motion, and fluids are behind for this point. Bring water up steadily now so the next choice is not reactive."
                : "Fluids are behind for this point in the day. Bring water up steadily now and keep the rest simple."
            support = ["Add 300-500 ml over the next hour", "Sip steadily", fuelBehindNow ? "Eat normally at the next meal" : "Keep food normal"]
            score = 52
        } else if recoveryLimited {
            title = "Keep the next block easy"
            message = hasLoggedDay
                ? "You already have day context logged. Recovery is the useful guide now, so keep the next block easy and avoid adding intensity just to fill space."
                : "Recovery is the useful guide now. Keep the next block easy and avoid adding intensity just to fill space."
            support = ["Keep movement easy", "Avoid extra intensity", "Protect tonight's sleep"]
            score = 50
        } else if let lastCompleted {
            title = "Day is already started"
            message = "\(displayName(lastCompleted)) is already logged. No need to pretend the day is blank; keep food, fluids, and effort steady from here."
            support = ["Keep basics steady", "Do not add noise", "Use the next clear step"]
            score = 40
        } else if fuelBehindNow {
            title = "Eat normally next"
            message = "Food is behind enough to matter, but it does not need to become the whole Coach message. Eat normally at the next meal and keep the day steady."
            support = ["Eat normally at the next meal", "Keep it digestible", "Do not chase targets"]
            score = 38
        } else {
            title = "Keep the day steady"
            message = "There is no urgent workout move, but the day still has context. Keep the next choice simple and do not add work just to fill the plan."
            support = ["Keep basics steady", "Avoid extra intensity", "Use the next clear step"]
            score = 34
        }

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + 12,
            uniquenessScore: 64,
            result: CoachDayPriorityResult(
                focus: .dailyOverview,
                level: score >= 50 ? .useful : .quiet,
                reason: "Generic fallback is not allowed because the day has meaningful context.",
                activity: lastCompleted,
                overridesTimingFocus: true,
                priority: .stable,
                strength: score >= 50 ? .medium : .low,
                confidence: 0.64,
                mode: .reinforcement,
                limiter: CoachLimiter.none,
                messageFamily: .stable,
                todayTitle: title,
                todayMessage: "Use the real day context.",
                title: title,
                message: message,
                supportBullets: support,
                whyThisMatters: "Fallback should only happen when there is truly nothing useful to reason about.",
                reasons: ["No active workout, preparation window, or post-workout focus is available.", "The day still has meaningful context."]
            )
        )
    }

    private static func baselineCandidate(in context: CoachDecisionContext) -> PriorityCandidate {
        
        if isOvernightBeforeDayStart(context) {
            return overnightBaselineCandidate(in: context)
        }
        
        if let preparing = context.activityContext.preparingActivity {
            if CoachActivityContextResolverV3.kind(for: preparing) == .recovery {
                return PriorityCandidate(
                    priorityScore: 42,
                    insightScore: 58,
                    uniquenessScore: 72,
                    result: CoachDayPriorityResult(
                        focus: .dailyOverview,
                        level: .useful,
                        reason: "Recovery movement is close, but the coaching need is restraint.",
                        activity: preparing,
                        overridesTimingFocus: true,
                        priority: .stable,
                        strength: .medium,
                        confidence: 0.62,
                        mode: .reinforcement,
                        limiter: CoachLimiter.none,
                        messageFamily: .stable,
                        todayTitle: "Keep it easy",
                        todayMessage: "Let recovery do its job.",
                        title: "Keep recovery easy",
                        message: "This is recovery support, not performance work. Start gently and finish feeling better than you started.",
                        supportBullets: ["Stay comfortable", "Avoid chasing pace", "Finish fresh"],
                        whyThisMatters: "Turning easy movement into work steals from recovery.",
                        reasons: ["A recovery activity is close."]
                    )
                )
            }

            let activityName = displayName(preparing).lowercased()
            return PriorityCandidate(
                priorityScore: 44,
                insightScore: 38,
                uniquenessScore: 40,
                result: CoachDayPriorityResult(
                    focus: .prepareForActivity,
                    level: .important,
                    reason: "The next activity is inside its preparation window.",
                    activity: preparing,
                    overridesTimingFocus: false,
                    priority: .performance,
                    strength: .medium,
                    confidence: 0.58,
                    mode: .execution,
                    limiter: .timing,
                    messageFamily: .performance,
                    todayTitle: "Prepare for \(activityName)",
                    todayMessage: "Start easy and keep fluids available before the session.",
                    title: "Prepare for \(activityName)",
                    message: "The session is close. The useful move is execution readiness, not changing the plan.",
                    supportBullets: ["Start easy", "Bring a bottle"],
                    reasons: ["The next activity is inside its preparation window.", "Preparation overrides stable overview unless a safety limiter is more urgent."]
                )
            )
        }

        if isEveningOrLater(context){
            return PriorityCandidate(
                priorityScore: 28,
                insightScore: 30,
                uniquenessScore: 42,
                result: CoachDayPriorityResult(
                    focus: .eveningWindDown,
                    level: .useful,
                    reason: "Evening is a good time to protect recovery and sleep.",
                    activity: context.activityContext.laterTodayActivity,
                    overridesTimingFocus: false,
                    priority: .stable,
                    strength: .low,
                    confidence: 0.45,
                    mode: .reinforcement,
                    limiter: CoachLimiter.none,
                    messageFamily: .stable,
                    title: "Keep the evening steady",
                    message: "No single blocker is loud. Keep food, fluids, and intensity calm so the day finishes cleanly.",
                    supportBullets: ["Keep intensity low", "Stay steady with fluids", "Do not add extra work"],
                    reasons: ["No dominant limiter is ahead of the evening routine."]
                )
            )
        }

        if let later = context.activityContext.laterTodayActivity {
            if CoachActivityContextResolverV3.kind(for: later) == .recovery || context.dayContext.dayType == .recovery {
                return PriorityCandidate(
                    priorityScore: 24,
                    insightScore: 44,
                    uniquenessScore: 68,
                    result: CoachDayPriorityResult(
                        focus: .dailyOverview,
                        level: .quiet,
                        reason: "Recovery movement is planned, but there is no urgent coaching action.",
                        activity: later,
                        overridesTimingFocus: true,
                        priority: .stable,
                        strength: .low,
                        confidence: 0.56,
                        mode: .reinforcement,
                        limiter: CoachLimiter.none,
                        messageFamily: .stable,
                        todayTitle: "Recovery day",
                        todayMessage: "Keep movement easy.",
                        title: "Recovery day",
                        message: "Nothing needs forcing. Keep the recovery work easy and use the rest of the day to stay steady.",
                        supportBullets: ["Stay comfortable", "Keep fluids steady", "Avoid extra intensity"],
                        whyThisMatters: "Easy movement helps most when it stays easy.",
                        reasons: ["The next coach-relevant activity is recovery-oriented."]
                    )
                )
            }

            if isWalkLike(later) || CoachActivityContextResolverV3.kind(for: later) == .recovery {
                let timing = timeUntilText(later, in: context)
                let title = localHour(in: context) < 12
                    ? "Ease into the morning"
                    : "Prepare calmly for your walk"
                let message = "\(displayName(later)) starts \(timing). Start with the walk, keep it comfortable, then reassess the rest of the day."

                return PriorityCandidate(
                    priorityScore: 28,
                    insightScore: 38,
                    uniquenessScore: 58,
                    result: CoachDayPriorityResult(
                        focus: .nextActivityLater,
                        level: .useful,
                        reason: "A recovery walk is planned later and no limiter is active.",
                        activity: later,
                        overridesTimingFocus: false,
                        priority: .stable,
                        strength: .low,
                        confidence: 0.66,
                        mode: .reinforcement,
                        limiter: CoachLimiter.none,
                        messageFamily: .stable,
                        todayTitle: title,
                        todayMessage: "Start with the walk, then reassess.",
                        title: title,
                        message: message,
                        supportBullets: [
                            "Keep the walk comfortable",
                            "Let the first minutes settle",
                            "Reassess after the walk"
                        ],
                        whyThisMatters: "Recovery movement works best when it stays calm and does not become a warning or a workout.",
                        reasons: ["Recovery walk planned later", "limiter=none"]
                    )
                )
            }

            if isTraining(later) {
                let timing = timeUntilText(later, in: context)
                let kind = CoachActivityContextResolverV3.kind(for: later)
                let isEndurance = kind == .endurance
                let title = isEndurance ? "Set up the ride properly" : "Set up training properly"
                let message = isEndurance
                    ? "\(displayName(later)) is the main work block later. Keep this part of the day calm, bring fluids, and do not wait until you feel flat to fuel."
                    : "\(displayName(later)) is the main work block later. Keep the gap calm, arrive fed enough, and do not add extra intensity before it."
                let support: [String]
                if isEndurance {
                    support = ["Bring fluids", "Plan 30-60g carbs/hour if it runs long", "Start easy"]
                } else {
                    support = ["Keep energy steady", "Do not add extra intensity", "Start easy"]
                }

                return PriorityCandidate(
                    priorityScore: 32,
                    insightScore: 46,
                    uniquenessScore: 64,
                    result: CoachDayPriorityResult(
                        focus: .nextActivityLater,
                        level: .useful,
                        reason: "Meaningful training is later today, but not inside the preparation window yet.",
                        activity: later,
                        overridesTimingFocus: false,
                        priority: .stable,
                        strength: .medium,
                        confidence: 0.62,
                        mode: .reinforcement,
                        limiter: CoachLimiter.none,
                        messageFamily: .stable,
                        todayTitle: title,
                        todayMessage: "\(displayName(later)) starts \(timing). Keep the day pointed at the work, not the clock.",
                        title: title,
                        message: message,
                        supportBullets: support,
                        whyThisMatters: "Good preparation starts before the official prep window: avoid spending energy you want available later.",
                        reasons: ["A meaningful training session is planned later today."]
                    )
                )
            }

            return PriorityCandidate(
                priorityScore: 22,
                insightScore: 24,
                uniquenessScore: 36,
                result: CoachDayPriorityResult(
                    focus: .dailyOverview,
                    level: .quiet,
                    reason: "A coach-relevant activity is planned later, outside the preparation window.",
                    activity: later,
                    overridesTimingFocus: false,
                    priority: .stable,
                    strength: .low,
                    confidence: 0.42,
                    mode: .reinforcement,
                    limiter: CoachLimiter.none,
                    messageFamily: .stable,
                    title: "No pressure yet",
                    message: "No urgent move is needed. Keep fuel, fluids, and energy steady so you are not reacting later.",
                    supportBullets: ["Keep rhythm", "Sip steadily", "Eat normally"],
                    whyThisMatters: "The useful move in a long gap is consistency, not watching the clock.",
                    reasons: ["Nothing is inside a coaching preparation window."]
                )
            )
        }

        return PriorityCandidate(
            priorityScore: 10,
            insightScore: 10,
            uniquenessScore: 30,
            result: .defaultOverview
        )
    }

    struct RecoveryNarrative {
        let title: String
        let message: String
        let supportBullets: [String]
        let whyThisMatters: String
        let limiter: CoachLimiter
        let family: CoachMessageFamily
        let insightScore: Double
        let uniquenessScore: Double
    }

    static func recoveryNarrative(
        in context: CoachDecisionContext,
        score: Double
    ) -> RecoveryNarrative {
        if isVeryLowSleep(context) || sleepIsPoor(context) {
            return RecoveryNarrative(
                title: "Sleep leads today",
                message: "Your fitness did not disappear overnight. The bottleneck is sleep, so I would stop chasing extra work and make tonight the intervention.",
                supportBullets: sleepSupportBullets(context: context),
                whyThisMatters: "A hard push after very low sleep usually gives you cost without the quality that makes training worthwhile.",
                limiter: .sleep,
                family: .sleep,
                insightScore: score + 22,
                uniquenessScore: 94
            )
        }

        if isHighLoadDay(context) {
            let tomorrowText = context.tomorrowDemand.isHard
                ? " That is also how you protect tomorrow's session."
                : ""

            return RecoveryNarrative(
                title: "The work is done",
                message: "Today's training load is already covered. The biggest gain left is making that work recoverable.\(tomorrowText)",
                supportBullets: supportBullets(
                    primary: "Stop adding training load",
                    context: context,
                    includeFuel: nutritionRatio(context) < 0.60,
                    includeHydration: hydrationRatio(context) < 0.70,
                    includeSleep: isEveningOrLater(context)
                ),
                whyThisMatters: "Once load is high, more stress is rarely the opportunity. Absorbing the work is.",
                limiter: .accumulatedFatigue,
                family: .recovery,
                insightScore: score + 16,
                uniquenessScore: 88
            )
        }

        if context.tomorrowDemand.isHard {
            return RecoveryNarrative(
                title: "Protect tomorrow's training",
                message: "Recovery is the limiter today because tomorrow asks for more. I would make the rest of the day quieter instead of borrowing from tomorrow.",
                supportBullets: supportBullets(
                    primary: "Keep tomorrow adjustable",
                    context: context,
                    includeFuel: nutritionRatio(context) < 0.60,
                    includeHydration: hydrationRatio(context) < 0.70,
                    includeSleep: true
                ),
                whyThisMatters: "Tomorrow's quality depends on how much recovery capacity you restore before then.",
                limiter: .upcomingTraining,
                family: .planAdjustment,
                insightScore: score + 12,
                uniquenessScore: 82
            )
        }

        if context.tomorrowContext?.dayContext.dayType == .recovery {
            return RecoveryNarrative(
                title: "Use the recovery space",
                message: "Recovery is asking for a lower ceiling today, and tomorrow gives you room to absorb it. Do not manufacture a make-up session; let the recovery day do its job.",
                supportBullets: supportBullets(
                    primary: "Let tomorrow stay easy",
                    context: context,
                    includeFuel: nutritionRatio(context) < 0.60,
                    includeHydration: hydrationRatio(context) < 0.70,
                    includeSleep: isEveningOrLater(context)
                ),
                whyThisMatters: "A planned recovery day is useful space, not a gap to fill with more training.",
                limiter: .recovery,
                family: .recovery,
                insightScore: score + 14,
                uniquenessScore: 84
            )
        }

        return RecoveryNarrative(
            title: "Let recovery lead",
            message: "Recovery is suppressed enough that the useful move is restraint: keep the next block easy and make the basics boringly consistent.",
            supportBullets: supportBullets(
                primary: "Keep anything left genuinely easy",
                context: context,
                includeFuel: nutritionRatio(context) < 0.60,
                includeHydration: hydrationRatio(context) < 0.70,
                includeSleep: isEveningOrLater(context)
            ),
            whyThisMatters: "If recovery does not improve, tomorrow's plan gets narrower and intensity becomes a gamble.",
            limiter: .recovery,
            family: .recovery,
            insightScore: score + 6,
            uniquenessScore: 66
        )
    }

    static func sleepSupportBullets(context: CoachDecisionContext) -> [String] {
        var bullets = ["Stop adding training load"]

        if nutritionRatio(context) < 0.55 {
            bullets.append("Eat enough to support sleep")
        }

        if hydrationRatio(context) < 0.70 {
            bullets.append("Sip fluids calmly")
        }

        bullets.append("Start winding down now")
        bullets.append("Avoid additional load")

        return Array(bullets.prefix(3))
    }

    static func supportBullets(
        primary: String,
        context: CoachDecisionContext,
        includeFuel: Bool,
        includeHydration: Bool,
        includeSleep: Bool
    ) -> [String] {
        var bullets = [primary]

        if includeFuel {
            bullets.append("Eat easy carbs plus protein")
        }
        if includeHydration {
            bullets.append("Sip fluids steadily")
        }
        if includeSleep {
            bullets.append("Start winding down now")
        }

        if bullets.count < 3 {
            if context.tomorrowDemand.isHard {
                bullets.append("Keep tomorrow adjustable")
            } else {
                bullets.append("Avoid extra intensity")
            }
        }

        return Array(bullets.prefix(3))
    }

    static func strength(for score: Double) -> CoachPriorityStrength {
        switch score {
        case 88...:
            return .critical
        case 68..<88:
            return .high
        case 46..<68:
            return .medium
        default:
            return .low
        }
    }

    static func isOvernightBeforeDayStart(_ context: CoachDecisionContext) -> Bool {
        localHour(in: context) < 5
    }
    
    static func level(for score: Double) -> CoachDayPriorityLevel {
        strength(for: score).level
    }

    static func confidence(for score: Double) -> Double {
        min(0.95, max(0.45, 0.45 + (score / 120.0)))
    }

    static func nutritionRatio(_ context: CoachDecisionContext) -> Double {
        if let nutrition = context.nutritionContext {
            return safeRatio(nutrition.caloriesCurrent, context.brain.baseDayGoals.calories)
        }

        return safeRatio(context.brain.metrics.calories, context.brain.baseDayGoals.calories)
    }

    static func proteinRatio(_ context: CoachDecisionContext) -> Double {
        if let nutrition = context.nutritionContext {
            return safeRatio(nutrition.proteinCurrent, context.brain.baseDayGoals.protein)
        }

        return safeRatio(context.brain.metrics.protein, context.brain.baseDayGoals.protein)
    }

    static func carbsRatio(_ context: CoachDecisionContext) -> Double {
        if let nutrition = context.nutritionContext {
            return safeRatio(nutrition.carbsCurrent, context.brain.baseDayGoals.carbs)
        }

        return context.brain.current.carbsProgress
    }

    static func safeRatio(_ current: Double, _ target: Double) -> Double {
        guard target > 0 else { return 1 }
        return max(0, current / target)
    }

    static func strongRecovery(in context: CoachDecisionContext) -> Bool {
        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            return recovery.recoveryPercent >= 85
        }

        return context.brain.recovery == .strong ||
            context.brain.readiness == .excellent
    }

    static func hasGoodEnoughProtein(_ context: CoachDecisionContext) -> Bool {
        proteinRatio(context) >= 0.90 && proteinRatio(context) < 1.0
    }

    static func hasGoodEnoughHydration(_ context: CoachDecisionContext) -> Bool {
        hydrationRatio(context) >= 0.90
    }

    static func sleepHours(_ context: CoachDecisionContext) -> Double? {
        if context.brain.metrics.sleepHours > 0 {
            return context.brain.metrics.sleepHours
        }

        if let recovery = context.recoveryContext, recovery.sleepHours > 0 {
            return recovery.sleepHours
        }

        return nil
    }

    static func recoveryPercent(_ context: CoachDecisionContext) -> Int? {
        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            return recovery.recoveryPercent
        }

        return nil
    }

    static func hasNoMeaningfulPerformanceWorkLeft(_ context: CoachDecisionContext) -> Bool {
        let remaining = [
            context.activityContext.activeActivity,
            context.activityContext.preparingActivity,
            context.activityContext.laterTodayActivity
        ].compactMap { $0 }

        return remaining.allSatisfy { activity in
            !isTraining(activity)
        }
    }

    static func hasMeaningfulTrainingRemaining(_ context: CoachDecisionContext) -> Bool {
        [
            context.activityContext.activeActivity,
            context.activityContext.preparingActivity,
            context.activityContext.laterTodayActivity
        ]
        .compactMap { $0 }
        .contains { isTraining($0) }
    }

    static func isHardRecentWorkout(in context: CoachDecisionContext) -> Bool {
        guard let recent = context.activityContext.recentlyCompletedActivity else {
            return false
        }

        guard isTraining(recent) else {
            return false
        }

        let load = CoachActivityContextResolverV3.load(for: recent)
        return load == .high ||
            load == .extreme ||
            recent.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes
    }

    static func severeFatigueDominates(_ context: CoachDecisionContext) -> Bool {
        recoveryPercent(context).map { $0 < 45 } ?? false ||
            (isVeryLowSleep(context) && (recoveryIsLow(context) || isHighLoadDay(context)))
    }

    static func fuelIsCriticallyBehind(_ context: CoachDecisionContext) -> Bool {
        nutritionRatio(context) < 0.20 ||
            carbsRatio(context) < 0.15
    }

    static func hydrationIsCriticallyBehind(_ context: CoachDecisionContext) -> Bool {
        guard !hydrationGoalReached(context) else { return false }

        return hydrationCanLeadAsPrimary(in: context) &&
            (
                hydrationRatio(context) < 0.30 ||
                context.brain.hydration == .depleted
            )
    }

    private static func hydrationCanLeadAsPrimary(in context: CoachDecisionContext) -> Bool {
        guard !hydrationGoalReached(context),
              hydrationIsBehind(context) else {
            return false
        }

        return heatHydrationActivity(in: context) != nil ||
            hardOrEnduranceWorkoutWithinNext90Minutes(context) ||
            hasDehydrationRiskIndicators(context)
    }

    private static func trajectoryAdjustedHydrationRatio(_ context: CoachDecisionContext) -> Double {
        let expected = expectedHydrationRatio(forHour: localHour(in: context))
        guard expected > 0 else { return hydrationRatio(context) }
        return hydrationRatio(context) / expected
    }

    private static func hardOrEnduranceWorkoutWithinNext90Minutes(_ context: CoachDecisionContext) -> Bool {
        let candidates = [
            context.activityContext.activeActivity,
            context.activityContext.preparingActivity,
            context.activityContext.laterTodayActivity,
            context.activityContext.nextUpcomingActivity
        ]
        .compactMap { $0 }

        return candidates.contains { activity in
            guard isTraining(activity) else { return false }
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            let load = CoachActivityContextResolverV3.load(for: activity)
            guard kind == .endurance || load == .high || load == .extreme else { return false }
            if context.activityContext.activeActivity?.id == activity.id {
                return true
            }
            return minutesUntil(activity, in: context).map { $0 <= 90 } == true
        } || context.dayContext.upcomingTrainingActivities.contains { activity in
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            let load = CoachActivityContextResolverV3.load(for: activity)
            guard kind == .endurance || load == .high || load == .extreme else { return false }
            return minutesUntil(activity, in: context).map { $0 <= 90 } == true
        }
    }

    private static func hasDehydrationRiskIndicators(_ context: CoachDecisionContext) -> Bool {
        let enduranceSoon = context.dayContext.upcomingActivities.contains { activity in
            guard CoachActivityContextResolverV3.kind(for: activity) == .endurance else {
                return false
            }
            let minutes = minutesUntil(activity, in: context)
            return minutes.map { $0 <= 240 } ?? false
        }

        return context.actualLoad.activeCalories >= 1_200 ||
            context.dayContext.completedTrainingStressScore >= 4 ||
            context.dayContext.hasMeaningfulLoadCompleted ||
            context.brain.strain == .veryHigh ||
            enduranceSoon
    }
    
    static func tomorrowPlanRiskPriority(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard let tomorrow = context.tomorrowContext else { return nil }
        guard context.tomorrowDemand.isHard else { return nil }
        guard isRecoveryLimitedForTomorrow(context) else { return nil }

        let activity = tomorrow.primaryTrainingActivity
        let tomorrowName = activity?.title ?? "tomorrow's hard session"
        let currentLimiters = tomorrowLimiters(in: context)
        let limiterText = currentLimiters.isEmpty ? "today's recovery signals" : currentLimiters.joined(separator: ", ")
        let loadText = tomorrow.dayContext.upcomingTrainingMinutes >= 90 ? "long" : "hard"

        return CoachDayPriorityResult(
            focus: .tomorrowPlanRisk,
            level: .high,
            reason: "Tomorrow has hard training planned while current recovery capacity is limited.",
            activity: activity,
            overridesTimingFocus: true,
            priority: .planChallenge,
            strength: .critical,
            title: "Tomorrow may need adjusting",
            message: "Given \(limiterText), \(tomorrowName.lowercased()) may exceed what you can recover from. I would protect tonight and be ready to swap tomorrow's \(loadText) work for recovery if readiness is still low.",
            supportBullets: [
                "Protect sleep tonight",
                "Check readiness before training",
                "Swap intensity for easy mobility if recovery stays low"
            ],
            whyThisMatters: "The goal is to arrive at tomorrow with enough recovery capacity to adapt, not just complete the plan."
        )
    }

    static func highLoadEveningRecoveryPriority(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard isEveningOrLater(context) else { return nil }
        guard isHighLoadDay(context) else { return nil }

        let tomorrowClause: String
        if context.tomorrowDemand.isHard {
            tomorrowClause = " and keep tomorrow's harder work realistic"
        } else {
            tomorrowClause = ""
        }

        return CoachDayPriorityResult(
            focus: .recoveryNeeded,
            level: .high,
            reason: "A very high load late in the day makes recovery more important than the current activity.",
            activity: context.activityContext.activeActivity ?? context.activityContext.nextUpcomingActivity,
            overridesTimingFocus: true,
            priority: .sleepPreparation,
            strength: .critical,
            title: "Recovery is the priority tonight",
            message: "You've already accumulated enough load today. Use stretching and breathing to transition into recovery mode, support sleep quality\(tomorrowClause).",
            supportBullets: [
                "Keep mobility easy",
                "Continue with breathing",
                "Avoid additional training"
            ],
            whyThisMatters: "Recovery quality tonight will influence tomorrow more than additional exercise."
        )
    }

    static func poorSleepEveningRecoveryPriority(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard isEveningOrLater(context) else { return nil }
        guard isVeryLowSleep(context) else { return nil }
        guard isRecoveryBlock(context) else { return nil }

        return CoachDayPriorityResult(
            focus: .recoveryNeeded,
            level: .high,
            reason: "Very low sleep during an evening recovery block should steer the day toward recovery.",
            activity: context.activityContext.activeActivity ?? context.activityContext.nextUpcomingActivity,
            overridesTimingFocus: true,
            priority: .sleepPreparation,
            strength: .critical,
            title: "Recovery is the priority tonight",
            message: "Sleep was very low, so this recovery block should stay easy and help you downshift for tonight.",
            supportBullets: [
                "Keep mobility easy",
                "Use breathing to settle",
                "Avoid additional load"
            ],
            whyThisMatters: "Better sleep preparation tonight gives tomorrow a better starting point."
        )
    }

    static func trainingReadinessWarning(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        let activity = context.activityContext.activeActivity ??
            context.activityContext.preparingActivity ??
            context.activityContext.laterTodayActivity

        guard let activity, isTraining(activity) else { return nil }

        let normalized = CoachLifecycleDecisionPipeline.normalizedContext(from: context)
        let highRecentLoad = CoachLifecycleDecisionPipeline.recentLoadNeedsCaution(
            context: context,
            c: normalized
        )
        let poorRecovery = CoachLifecycleDecisionPipeline.recoveryIsPoor(
            context,
            sleepStatus: normalized.sleepStatus
        )
        let readiness = CoachLifecycleDecisionPipeline.trainingReadinessAssessment(
            activity: activity,
            context: context,
            c: normalized,
            highRecentLoad: highRecentLoad,
            poorRecovery: poorRecovery
        )
        CoachLifecycleDecisionPipeline.logTrainingReadinessAssessment(
            readiness,
            activity: activity,
            source: "CoachDayPriorityResolver.trainingReadinessWarning"
        )

        guard readiness.selected else { return nil }

        let load = CoachActivityContextResolverV3.load(for: activity)
        let meaningfulActivityNow = context.activityContext.activeActivity != nil ||
            context.activityContext.preparingActivity != nil
        let loadedAlready =
            context.dayContext.hasMeaningfulLoadCompleted ||
            context.dayContext.completedTrainingStressScore >= 2 ||
            context.brain.past.hasHighActivityLoad ||
            context.brain.past.completedWorkoutsCount > 0

        guard meaningfulActivityNow || loadedAlready || load == .high || load == .extreme else {
            return nil
        }

        let planAdjustment = CoachLifecycleDecisionPipeline.remainingPlanExceedsAbsorption(
            context: context,
            c: normalized
        )

        return CoachDayPriorityResult(
            focus: .trainingReadinessWarning,
            level: readiness.strength.level,
            reason: planAdjustment
                ? "The remaining plan exceeds what today can productively absorb."
                : "Recovery/readiness is low relative to the training demand today.",
            activity: activity,
            overridesTimingFocus: true,
            priority: .planChallenge,
            strength: readiness.strength,
            confidence: confidence(for: readiness.score),
            mode: .warning,
            limiter: highRecentLoad ? .accumulatedFatigue : .trainingReadiness,
            messageFamily: .planAdjustment,
            title: planAdjustment ? "Adjust today's plan" : "Downgrade today",
            message: planAdjustment
                ? "The remaining plan is no longer additive fitness; it is mostly additive fatigue. Remove the session, replace it with recovery work, or postpone it."
                : "The readiness score is high enough to lower today's training ceiling. Start easier and downgrade if warm-up feedback is flat.",
            supportBullets: readiness.triggerReasons,
            whyThisMatters: planAdjustment
                ? "The coaching decision is about the day plan, not just the next activity."
                : "A downgrade should only appear when readiness evidence crosses the warning threshold.",
            reasons: readiness.triggerReasons + [
                "trainingReadinessScore=\(Int(readiness.score))",
                "trainingReadinessThreshold=\(Int(readiness.threshold))",
                "selectedBecause=\(readiness.selectedBecause)"
            ] + (planAdjustment ? ["decisionType=planAdjustment"] : [])
        )
    }

    static func postActivityRecovery(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard let recent = context.activityContext.recentlyCompletedActivity else { return nil }
        guard isMeaningfulPostActivityTraining(recent) else { return nil }

        let needsFuel = fuelIsBehind(context)
        let needsHydration = hydrationIsBehind(context)
        let needsRecovery = recoveryIsLow(context)

        guard needsFuel || needsHydration || needsRecovery else { return nil }

        return CoachDayPriorityResult(
            focus: .postActivityRecovery,
            level: .important,
            reason: "A recent session makes recovery, fuel, and hydration the next useful step.",
            activity: recent,
            overridesTimingFocus: false
        )
    }

    static func hydrationPriority(
        in context: CoachDecisionContext,
        dayLevelOnly: Bool
    ) -> CoachDayPriorityResult? {
        guard hydrationIsBehind(context) else { return nil }

        let contextActivity = context.activityContext.preparingActivity ??
            context.activityContext.activeActivity ??
            context.activityContext.laterTodayActivity

        let heatActivity = heatHydrationActivity(in: context)
        let hasHeatSoon = heatActivity != nil
        let heatMinutesUntil = heatActivity.flatMap { minutesUntil($0, in: context) }
        let heatVerySoon = context.activityContext.activeActivity?.id == heatActivity?.id ||
            heatMinutesUntil.map { $0 <= 30 } == true
        let activity = heatActivity ??
            contextActivity.flatMap {
                CoachActivityContextResolverV3.kind(for: $0) == .heat ? nil : $0
            }
        let highLoadHydrationGap = isHighLoadDay(context) && hydrationRatio(context) < Thresholds.hydrationBehindHighLoadRatio
        let shouldOverride = context.activityContext.preparingActivity != nil ||
            context.activityContext.activeActivity != nil ||
            highLoadHydrationGap

        if dayLevelOnly {
            guard hasHeatSoon || highLoadHydrationGap else { return nil }
        }

        if hasHeatSoon && hydrationRatio(context) >= 0.50 && !heatVerySoon && !highLoadHydrationGap {
            return nil
        }

        guard hasHeatSoon ||
              highLoadHydrationGap ||
              context.brain.hydration == .depleted ||
              context.brain.current.waterProgress < 0.45 else {
            return nil
        }

        return CoachDayPriorityResult(
            focus: hasHeatSoon || activity != nil ? .prepareForActivity : .recoveryNeeded,
            level: hasHeatSoon || highLoadHydrationGap ? .high : .important,
            reason: hasHeatSoon
                ? "Fluids are low before heat exposure."
                : (highLoadHydrationGap
                    ? "Fluids are low on a high-load day."
                    : "Fluids are low for what the rest of the day needs."),
            activity: activity,
            overridesTimingFocus: shouldOverride,
            priority: hasHeatSoon || activity != nil ? .performance : .recovery,
            strength: hasHeatSoon || highLoadHydrationGap ? .critical : .high,
            limiter: hasHeatSoon || activity != nil ? .timing : .recovery,
            messageFamily: hasHeatSoon || activity != nil ? .performance : .recovery,
            title: hasHeatSoon ? "Prepare for heat" : (activity != nil ? "Prepare for the next block" : "Support recovery"),
            message: highLoadHydrationGap
                ? "Today's load is high. Bring fluids up before leaning on the next activity."
                : (activity.map { "Before \($0.title.lowercased()), bring fluids back up." }
                    ?? "Bring fluids up for what the rest of the day needs."),
            supportBullets: [
                "Sip steadily",
                "Support the next block",
                "Avoid starting dry"
            ],
            whyThisMatters: highLoadHydrationGap
                ? "High-load days are harder to recover from when fluids stay behind."
                : nil
        )
    }

    static func fuelPriority(
        in context: CoachDecisionContext,
        hardWorkoutOnly: Bool
    ) -> CoachDayPriorityResult? {
        guard fuelIsBehind(context) else { return nil }

        let hardActivity = hardFuelingActivity(in: context)
        if hardWorkoutOnly {
            guard hardActivity != nil else { return nil }
        }

        let activity = hardActivity ??
            context.activityContext.laterTodayActivity ??
            context.activityContext.nextUpcomingActivity

        let timingIsImmediate = context.activityContext.activeActivity != nil ||
            context.activityContext.preparingActivity != nil

        let baseFuelBehind = nutritionRatio(context) < Thresholds.fuelBehindHardWorkoutRatio ||
            proteinRatio(context) < 0.45 ||
            carbsRatio(context) < 0.35

        guard hardActivity != nil || baseFuelBehind else {
            return nil
        }

        guard !timingIsImmediate || nutritionRatio(context) < 0.45 || carbsRatio(context) < 0.30 else {
            return nil
        }

        return CoachDayPriorityResult(
            focus: hardActivity != nil ? .prepareForActivity : .recoveryNeeded,
            level: .important,
            reason: "Nutrition is behind the current day demand.",
            activity: activity,
            overridesTimingFocus: timingIsImmediate,
            priority: hardActivity != nil ? .performance : .recovery,
            strength: .high,
            limiter: hardActivity != nil ? .timing : .recovery,
            messageFamily: hardActivity != nil ? .performance : .recovery,
            title: hardActivity != nil ? "Prepare for the hard work" : "Support recovery",
            message: activity.map { "Nutrition is behind, and \($0.title.lowercased()) still needs usable energy." }
                ?? "Nutrition is behind the current day demand.",
            supportBullets: [
                "Add easy fuel",
                "Keep it digestible",
                "Do not wait until the session"
            ],
            whyThisMatters: "A hard session is easier to execute when energy is available before it starts."
        )
    }

    static func recoveryPriority(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard recoveryIsLow(context) else { return nil }
        guard context.activityContext.activeActivity == nil || isRecoveryBlock(context) else { return nil }

        return CoachDayPriorityResult(
            focus: .recoveryNeeded,
            level: .important,
            reason: "Recovery signals need protection before adding more demand.",
            activity: context.activityContext.laterTodayActivity,
            overridesTimingFocus: context.activityContext.preparingActivity != nil || context.activityContext.activeActivity != nil,
            priority: .recovery,
            strength: .high,
            title: "Protect recovery now",
            message: "Recovery signals need protection before adding more demand.",
            supportBullets: [
                "Keep intensity flexible",
                "Use recovery blocks gently",
                "Avoid extra training"
            ],
            whyThisMatters: "Adding load when recovery is limited can make tomorrow harder than it needs to be."
        )
    }
    
    private static func overnightBaselineCandidate(
        in context: CoachDecisionContext
    ) -> PriorityCandidate {

        let nextActivity = context.activityContext.nextUpcomingActivity ??
            context.activityContext.laterTodayActivity

        if let nextActivity {
            return PriorityCandidate(
                priorityScore: 38,
                insightScore: 66,
                uniquenessScore: 84,
                result: CoachDayPriorityResult(
                    focus: .eveningWindDown,
                    level: .useful,
                    reason: "The day has not fully started yet.",
                    activity: nextActivity,
                    overridesTimingFocus: true,
                    priority: .sleepPreparation,
                    strength: .medium,
                    confidence: 0.72,
                    mode: .recovery,
                    limiter: .sleep,
                    messageFamily: .sleep,
                    todayTitle: "Sleep comes first",
                    todayMessage: "Nothing needs solving now.",
                    title: "Sleep comes first",
                    message: "Nothing useful needs solving overnight. Sleep is the highest-value move before the morning plan matters.",
                    supportBullets: ["Leave the plan alone", "Keep the room calm", "Return to sleep"],
                    whyThisMatters: "The next decision is better made after recovery, not in the middle of the night.",
                    reasons: ["It is still overnight.", "No immediate coaching issue beats sleep."]
                )
            )
        }

        return PriorityCandidate(
            priorityScore: 10,
            insightScore: 10,
            uniquenessScore: 30,
            result: CoachDayPriorityResult(
                focus: .eveningWindDown,
                level: .useful,
                reason: "The day has not fully started yet.",
                activity: nil,
                overridesTimingFocus: true,
                priority: .sleepPreparation,
                strength: .medium,
                confidence: 0.66,
                mode: .recovery,
                limiter: .sleep,
                messageFamily: .sleep,
                todayTitle: "Sleep comes first",
                todayMessage: "No urgent move now.",
                title: "Sleep comes first",
                message: "No coaching action is worth more than protecting sleep right now.",
                supportBullets: ["Keep the night quiet", "Let the day start later", "Protect recovery"],
                whyThisMatters: "At this hour, recovery is mostly won by staying asleep.",
                reasons: ["It is still overnight."]
            )
        )
    }
    
    static func hasLiveOrImmediateActivity(_ context: CoachDecisionContext) -> Bool {
        context.activityContext.activeActivity != nil ||
        context.activityContext.preparingActivity != nil
    }

    static func isEveningOrLater(_ context: CoachDecisionContext) -> Bool {
        switch localTimeBucket(in: context) {
        case .evening, .night, .lateNight:
            return true
        case .afternoon:
            return false
        }
    }

    static func isSleepPreparationWindow(_ context: CoachDecisionContext) -> Bool {
        if isLateNight(context) && !hasMeaningfulTrainingRemaining(context) {
            return true
        }

        return isEveningOrLater(context) && hasNoMeaningfulPerformanceWorkLeft(context)
    }

    static func isLateNight(_ context: CoachDecisionContext) -> Bool {
        localTimeBucket(in: context) == .lateNight
    }

    static func isClosedNightBeforeMorning(_ context: CoachDecisionContext) -> Bool {
        isLateNight(context) && localHour(in: context) < Thresholds.dayClosedMorningEndHour
    }

    static func isDayClosedHour(_ hour: Int) -> Bool {
        hour >= Thresholds.dayClosedHour || hour < Thresholds.dayClosedMorningEndHour
    }

    static func isHighLoadDay(_ context: CoachDecisionContext) -> Bool {
        if context.actualLoad.activeCalories >= Thresholds.veryHighActiveCalories {
            return true
        }

        if activityProgress(context) >= Thresholds.highLoadActivityProgress {
            return true
        }

        return context.dayContext.completedTrainingStressScore >= Thresholds.highTrainingStressScore ||
            context.dayContext.dayType == .highLoad ||
            context.brain.strain == .veryHigh ||
            context.brain.past.hasHighActivityLoad
    }

    static func activityProgress(_ context: CoachDecisionContext) -> Double {
        let progress = context.actualLoad.activityProgress ??
            context.actualLoad.activeCalories / Thresholds.estimatedActivityGoalCalories
        guard context.actualLoad.activeCalories >= 300 ||
                (context.actualLoad.exerciseMinutes ?? 0) >= 30 else {
            return min(progress, 0.99)
        }
        return progress
    }

    static func isVeryLowSleep(_ context: CoachDecisionContext) -> Bool {
        if let hours = sleepHours(context) {
            return hours <= Thresholds.veryLowSleepHours
        }

        return context.brain.sleep == .veryShort
    }

    static func sleepIsPoor(_ context: CoachDecisionContext) -> Bool {
        if let hours = sleepHours(context) {
            return hours < 5.5
        }

        return context.brain.sleep == .short || context.brain.sleep == .veryShort
    }

    static func hasSleepDeficitEvidence(_ context: CoachDecisionContext) -> Bool {
        sleepIsPoor(context) || isVeryLowSleep(context)
    }

    static func isRecoveryBlock(_ context: CoachDecisionContext) -> Bool {
        let activities = [
            context.activityContext.activeActivity,
            context.activityContext.preparingActivity,
            context.activityContext.nextUpcomingActivity
        ]

        return activities.contains { activity in
            guard let activity else { return false }
            return CoachActivityContextResolverV3.kind(for: activity) == .recovery
        }
    }

    private struct FuelBehindSignals {
        let mealsCount: Int
        let noMealsToday: Bool
        let caloriesBehind: Bool
        let carbsBehind: Bool
        let preTrainingFuelingRequired: Bool
        let postTrainingRefuelRequired: Bool
        let lateEveningNightSuppression: Bool
        let alreadyAteRecently: Bool
        let activityMeetsFuelingThreshold: Bool
        let hardActivitySoon: PlannedActivity?
        let nextTrainingOrActivity: PlannedActivity?
        let minutesUntilActivity: Int?
        let minutesSinceLastMeal: Int?
        let caloriesRatio: Double
        let carbsRatio: Double
        let energyCoverage: Double
        let criticalFuelGap: Bool
        let reasonableTimeToEat: Bool
    }

    private static func fuelBehindSignals(in context: CoachDecisionContext) -> FuelBehindSignals {
        let hour = localHour(in: context)
        let caloriesRatio = nutritionRatio(context)
        let carbsRatio = carbsRatio(context)
        let mealsCount = context.nutritionContext?.mealsCount ?? context.dayContext.completedMealsCount
        let lastMealTime = latestMealTime(in: context)
        let minutesSinceLastMeal = lastMealTime.map {
            max(0, Int(context.dayContext.now.timeIntervalSince($0) / 60))
        }
        let alreadyAteRecently = minutesSinceLastMeal.map {
            $0 <= Thresholds.recentMealSuppressionMinutes
        } ?? false
        let nextTrainingOrActivity = context.activityContext.preparingActivity ??
            context.activityContext.laterTodayActivity ??
            context.activityContext.nextUpcomingActivity ??
            context.dayContext.nextActivity
        let hardActivitySoon = hardFuelingActivity(in: context)
        let activityMeetsFuelingThreshold = nextTrainingOrActivity.map { activity in
            guard isTraining(activity) else { return false }
            let load = CoachActivityContextResolverV3.load(for: activity)
            return load == .high ||
                load == .extreme ||
                activity.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes
        } ?? false
        let caloriesBehind = caloriesRatio < 0.35
        let carbsBehind = carbsRatio < 0.25
        let criticalFuelGap = caloriesBehind || carbsBehind
        let reasonableTimeToEat = hour >= 6 && hour < Thresholds.lateEveningHour
        let lateEveningNightSuppression = !reasonableTimeToEat
        let noMealsToday = mealsCount == 0 && !context.brain.hasAnyFoodLogged
        let minutesUntilActivity = nextTrainingOrActivity.flatMap { minutesUntil($0, in: context) }
        let closeTrainingStillUnderFueled = hardActivitySoon != nil &&
            minutesUntilActivity.map { $0 <= 60 } == true &&
            criticalFuelGap &&
            (
                carbsRatio < 0.18 ||
                caloriesRatio < 0.18
            )
        let recentFuelSatisfiesTraining = alreadyAteRecently && !closeTrainingStillUnderFueled
        let insufficientRecentFuel = criticalFuelGap || (noMealsToday && !alreadyAteRecently)
        let preTrainingFuelingRequired = hardActivitySoon != nil &&
            insufficientRecentFuel &&
            reasonableTimeToEat &&
            !recentFuelSatisfiesTraining
        let postTrainingRefuelRequired = isHardRecentWorkout(in: context) &&
            criticalFuelGap &&
            !alreadyAteRecently &&
            (reasonableTimeToEat || hour < Thresholds.dayClosedHour)

        return FuelBehindSignals(
            mealsCount: mealsCount,
            noMealsToday: noMealsToday,
            caloriesBehind: caloriesBehind,
            carbsBehind: carbsBehind,
            preTrainingFuelingRequired: preTrainingFuelingRequired,
            postTrainingRefuelRequired: postTrainingRefuelRequired,
            lateEveningNightSuppression: lateEveningNightSuppression,
            alreadyAteRecently: alreadyAteRecently,
            activityMeetsFuelingThreshold: activityMeetsFuelingThreshold,
            hardActivitySoon: hardActivitySoon,
            nextTrainingOrActivity: nextTrainingOrActivity,
            minutesUntilActivity: minutesUntilActivity,
            minutesSinceLastMeal: minutesSinceLastMeal,
            caloriesRatio: caloriesRatio,
            carbsRatio: carbsRatio,
            energyCoverage: context.brain.current.energyCoverage,
            criticalFuelGap: criticalFuelGap,
            reasonableTimeToEat: reasonableTimeToEat
        )
    }

    static func hydrationRatio(_ context: CoachDecisionContext) -> Double {
        if let nutrition = context.nutritionContext, nutrition.waterGoal > 0 {
            return nutrition.waterCurrent / nutrition.waterGoal
        }

        return context.brain.current.waterProgress
    }

    static func hardFuelingActivity(
        in context: CoachDecisionContext,
        maximumLeadTimeMinutes: Int? = Thresholds.preTrainingFuelingWindowMinutes
    ) -> PlannedActivity? {
        let candidates = [
            context.activityContext.preparingActivity,
            context.activityContext.laterTodayActivity,
            context.activityContext.nextUpcomingActivity
        ]

        return candidates.compactMap { $0 }.first { activity in
            guard isTraining(activity) else { return false }
            let load = CoachActivityContextResolverV3.load(for: activity)
            let meetsThreshold = load == .high ||
                load == .extreme ||
                activity.effectiveDurationMinutes >= Thresholds.hardWorkoutMinimumMinutes
            guard meetsThreshold else { return false }
            guard let maximumLeadTimeMinutes,
                  context.activityContext.preparingActivity?.id != activity.id,
                  context.activityContext.activeActivity?.id != activity.id,
                  let minutes = minutesUntil(activity, in: context) else {
                return true
            }
            return minutes <= maximumLeadTimeMinutes
        }
    }

    static func hydrationIsBehind(_ context: CoachDecisionContext) -> Bool {
        let hour = localHour(in: context)
        let ratio = hydrationRatio(context)

        guard !hydrationGoalReached(context) else { return false }

        let contextActivity = context.activityContext.preparingActivity ??
            context.activityContext.activeActivity ??
            context.activityContext.laterTodayActivity

        let heatSoon = heatHydrationActivity(in: context) != nil
        let activity = contextActivity.flatMap {
            CoachActivityContextResolverV3.kind(for: $0) == .heat && !heatSoon ? nil : $0
        }

        let enduranceDemand = activity.map {
            CoachActivityContextResolverV3.kind(for: $0) == .endurance
        } ?? false

        let expected = expectedHydrationRatio(forHour: hour)
        let deltaFromExpected = ratio - expected
        let materiallyBehindTrajectory = deltaFromExpected < -0.08
        let criticallyLowAdjustedProgress = trajectoryAdjustedHydrationRatio(context) < 0.20

        return heatSoon ||
            enduranceDemand ||
            criticallyLowAdjustedProgress ||
            materiallyBehindTrajectory
    }

    static func hydrationGoalReached(_ context: CoachDecisionContext) -> Bool {
        guard let nutrition = context.nutritionContext,
              nutrition.waterGoal > 0 else {
            return false
        }

        return nutrition.waterCurrent >= nutrition.waterGoal ||
            hydrationRatio(context) >= Thresholds.hydrationCompleteRatio
    }

    static func fuelIsBehind(_ context: CoachDecisionContext) -> Bool {
        let signals = fuelBehindSignals(in: context)
        let hour = localHour(in: context)
        let tomorrowHard = context.tomorrowDemand.isHard
        let recoveryDayWithoutTraining =
            context.dayContext.dayType == .recovery &&
            !hasMeaningfulTrainingRemaining(context)
        let morningNoFoodWarning = hour >= 10 &&
            hour < 12 &&
            !recoveryDayWithoutTraining &&
            signals.noMealsToday &&
            signals.criticalFuelGap &&
            !signals.alreadyAteRecently
        let middayNoFoodWarning = hour >= 12 &&
            !recoveryDayWithoutTraining &&
            signals.noMealsToday &&
            signals.criticalFuelGap &&
            !signals.alreadyAteRecently
        let tomorrowRefuelRequired = tomorrowHard &&
            hour >= 18 &&
            hour < Thresholds.lateEveningHour &&
            signals.criticalFuelGap &&
            !signals.alreadyAteRecently

        let result: Bool
        if signals.lateEveningNightSuppression {
            result = signals.postTrainingRefuelRequired && signals.criticalFuelGap
        } else if signals.alreadyAteRecently && !signals.criticalFuelGap {
            result = false
        } else {
            result = signals.preTrainingFuelingRequired ||
                signals.postTrainingRefuelRequired ||
                tomorrowRefuelRequired ||
                morningNoFoodWarning ||
                middayNoFoodWarning ||
                (
                    hour >= 12 &&
                    !recoveryDayWithoutTraining &&
                    signals.criticalFuelGap &&
                    !signals.alreadyAteRecently
                )
        }

        #if DEBUG
        logFuelBehindDecision(signals, result: result, in: context)
        #endif
        return result
    }

    static func recoveryIsLow(_ context: CoachDecisionContext) -> Bool {
        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            return recovery.recoveryPercent < 55
        }

        return context.brain.recovery == .compromised ||
            context.brain.recovery == .vulnerable ||
            context.brain.readiness == .compromised ||
            context.brain.sleep == .veryShort
    }

    static func veryLowRecovery(_ context: CoachDecisionContext) -> Bool {
        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            return recovery.recoveryPercent < 45
        }

        return context.brain.recovery == .compromised ||
            context.brain.readiness == .compromised
    }

    static func hasSeriousReadinessIssue(_ context: CoachDecisionContext) -> Bool {
        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            return recovery.recoveryPercent < 50
        }

        return context.brain.recovery == .compromised ||
            context.brain.readiness == .compromised ||
            context.brain.readiness == .low ||
            context.brain.sleep == .veryShort ||
            context.brain.strain == .veryHigh
    }

    static func isRecoveryLimitedForTomorrow(_ context: CoachDecisionContext) -> Bool {
        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0 {
            if recovery.recoveryPercent < 60 {
                return true
            }
        }

        if isVeryLowSleep(context) ||
            context.brain.sleep == .short ||
            context.brain.sleep == .veryShort ||
            context.brain.recovery == .compromised ||
            context.brain.recovery == .vulnerable ||
            context.brain.readiness == .low ||
            context.brain.readiness == .compromised {
            return true
        }

        return isHighLoadDay(context) && isEveningOrLater(context)
    }

    static func tomorrowLimiters(in context: CoachDecisionContext) -> [String] {
        var limiters: [String] = []

        if let recovery = context.recoveryContext, recovery.recoveryPercent > 0, recovery.recoveryPercent < 60 {
            limiters.append("recovery is still suppressed")
        } else if context.brain.recovery == .compromised || context.brain.recovery == .vulnerable {
            limiters.append("recovery is not fully back")
        }

        if isVeryLowSleep(context) {
            limiters.append("sleep was very low")
        } else if context.brain.sleep == .short {
            limiters.append("sleep was short")
        }

        if isHighLoadDay(context) {
            limiters.append("today's load is already high")
        }

        return Array(limiters.prefix(3))
    }

    static func isTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        return kind == .workout || kind == .endurance
    }

    static func isMeaningfulPostActivityTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let text = "\(activity.type) \(activity.title)".lowercased()

        guard kind != .heat,
              kind != .recovery,
              !text.contains("hydration"),
              !text.contains("water"),
              !text.contains("mobility"),
              !text.contains("stretch"),
              !text.contains("breath") else {
            return false
        }

        let duration = max(activity.effectiveDurationMinutes, activity.durationMinutes)
        guard duration >= 10 else { return false }

        if isWalkLike(activity) {
            return duration >= 30 && load != .low
        }

        return isTraining(activity) &&
            (
                load == .high ||
                load == .extreme ||
                duration >= 30 ||
                (duration >= 20 && load == .moderate)
            )
    }

    static func isCompletedRecoveryReinforcementActivity(_ activity: PlannedActivity) -> Bool {
        guard activity.isCompleted else { return false }
        guard !isMeaningfulPostActivityTraining(activity) else { return false }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        if kind == .heat || kind == .recovery {
            return true
        }

        let text = "\(activity.type) \(activity.title)".lowercased()
        return text.contains("breath") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("walk") ||
            text.contains("walking") ||
            text.contains("sauna")
    }

    static func displayName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Recovery activity" : title
    }

    static func timeUntilText(_ activity: PlannedActivity, in context: CoachDecisionContext) -> String {
        guard let minutes = minutesUntil(activity, in: context) else {
            return "soon"
        }

        if minutes < 60 {
            return "in \(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "in \(hours)h" : "in \(hours)h \(remainder)m"
    }

    static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        CoachActivityClassification.isWalkLike(activity) ||
            CoachActivityClassification.isHikeLike(activity)
    }

    static func isMeaningfulImmediateActivity(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        return kind == .workout || kind == .endurance || kind == .heat
    }

    static func heatHydrationActivity(in context: CoachDecisionContext) -> PlannedActivity? {
        let activities = [
            context.activityContext.activeActivity,
            context.activityContext.preparingActivity,
            context.activityContext.laterTodayActivity,
            context.activityContext.nextUpcomingActivity
        ]
        .compactMap { $0 }

        return activities.first { activity in
            guard CoachActivityContextResolverV3.kind(for: activity) == .heat else { return false }
            if context.activityContext.activeActivity?.id == activity.id {
                return true
            }
            guard let minutes = minutesUntil(activity, in: context) else {
                return false
            }
            return minutes <= Thresholds.heatHydrationLeadMinutes
        }
    }

    static func isFoodMeal(_ activity: PlannedActivity) -> Bool {
        activity.type.lowercased() == "meal" &&
            activity.imageName != "hydration" &&
            !activity.isSkipped
    }

    static func isHydrationLog(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let image = activity.imageName.lowercased()

        return type == "hydration" ||
            image == "hydration" ||
            title.contains("water") ||
            title.contains("hydration")
    }

    static func recentCompletedActivity(
        in context: CoachDecisionContext,
        maximumMinutes: Int
    ) -> PlannedActivity? {
        context.dayContext.completedActivities
            .filter { activity in
                guard !isHydrationLog(activity), !activity.isSkipped else { return false }
                let end = activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, activity.durationMinutes) * 60))
                let minutes = Int(context.dayContext.now.timeIntervalSince(end) / 60)
                return minutes >= 0 && minutes <= maximumMinutes
            }
            .sorted { $0.date > $1.date }
            .first
    }

    static func newerCompletedNonAnchor(
        after anchor: PlannedActivity,
        in context: CoachDecisionContext
    ) -> PlannedActivity? {
        let anchorEnd = activityEnd(anchor)

        return context.dayContext.completedActivities
            .filter { activity in
                guard activity.id != anchor.id,
                      !activity.isSkipped,
                      !isHydrationLog(activity) else {
                    return false
                }

                let end = activityEnd(activity)
                return end > anchorEnd && end <= context.dayContext.now
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    static func activityEnd(_ activity: PlannedActivity) -> Date {
        activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, activity.durationMinutes) * 60))
    }

    static func activeMeal(in context: CoachDecisionContext) -> PlannedActivity? {
        context.dayContext.allActivities
            .filter { activity in
                guard isFoodMeal(activity), !activity.isCompleted, !activity.isSkipped else {
                    return false
                }
                let end = activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, activity.durationMinutes) * 60))
                return activity.date <= context.dayContext.now && context.dayContext.now <= end
            }
            .sorted { $0.date < $1.date }
            .first
    }

    static func nutritionHasStarted(_ context: CoachDecisionContext) -> Bool {
        (context.nutritionContext?.mealsCount ?? context.dayContext.completedMealsCount) > 0 ||
            context.brain.hasAnyFoodLogged ||
            (context.nutritionContext?.waterCurrent ?? 0) > 0.05
    }

    static func genericFallbackAllowed(in context: CoachDecisionContext) -> Bool {
        guard context.activityContext.activeActivity == nil,
              context.activityContext.preparingActivity == nil,
              context.activityContext.recentlyCompletedActivity == nil,
              activeMeal(in: context) == nil,
              context.activityContext.laterTodayActivity == nil,
              context.dayContext.upcomingActivities.isEmpty,
              context.dayContext.completedActivities.isEmpty,
              context.dayContext.skippedActivities.isEmpty,
              context.dayContext.missedActivities.isEmpty,
              !hydrationIsBehind(context),
              !fuelIsBehind(context),
              !recoveryIsLow(context),
              !sleepIsPoor(context),
              !isVeryLowSleep(context) else {
            return false
        }

        return true
    }

    static func latestMealTime(in context: CoachDecisionContext) -> Date? {
        if let lastMealTime = context.nutritionContext?.lastMealTime {
            return lastMealTime
        }

        return context.dayContext.completedActivities
            .filter { isFoodMeal($0) && $0.isCompleted }
            .map(\.date)
            .max()
    }

    static func minutesUntil(_ activity: PlannedActivity, in context: CoachDecisionContext) -> Int? {
        let interval = activity.date.timeIntervalSince(context.dayContext.now)
        guard interval >= 0 else { return nil }
        return Int(interval / 60)
    }
}

private extension CoachActivityLoadV3 {
    var riskScore: Int {
        switch self {
        case .low:
            return 0
        case .moderate:
            return 1
        case .high:
            return 2
        case .extreme:
            return 3
        }
    }
}

#if DEBUG
private extension CoachActivityPhaseV3 {
    var debugSummary: String {
        switch self {
        case .preparing(let activity, let kind, let minutesUntil):
            return "preparing(activity: \(activity.title), kind: \(kind), minutesUntil: \(minutesUntil))"
        case .active(let activity, let kind):
            return "active(activity: \(activity.title), kind: \(kind))"
        case .recovering(let activity, let kind, let minutesSinceEnd):
            return "recovering(activity: \(activity.title), kind: \(kind), minutesSinceEnd: \(minutesSinceEnd))"
        case .stable:
            return "stable"
        }
    }
}
#endif
