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
        let resolvedPriority = priority ?? Self.defaultPriority(for: focus)
        let resolvedLimiter = limiter ?? Self.defaultLimiter(for: resolvedPriority, focus: focus)
        self.priority = resolvedPriority
        self.strength = strength ?? Self.defaultStrength(for: level)
        self.confidence = min(max(confidence, 0), 1)
        self.mode = mode ?? Self.defaultMode(for: resolvedPriority, focus: focus)
        self.limiter = resolvedLimiter
        self.messageFamily = messageFamily ?? Self.defaultMessageFamily(for: resolvedPriority)
        self.priorityScore = priorityScore
        self.insightScore = insightScore
        self.uniquenessScore = uniquenessScore
        self.decisionScore = decisionScore
        self.focus = focus
        self.reason = reason
        self.reasons = reasons ?? [reason]
        self.activity = activity
        self.overridesTimingFocus = overridesTimingFocus
        let resolvedDetailTitle = detailTitle ?? title ?? Self.defaultTitle(for: resolvedPriority, focus: focus)
        let resolvedDetailMessage = detailMessage ?? message ?? reason
        self.detailTitle = resolvedDetailTitle
        self.detailMessage = resolvedDetailMessage
        self.todayTitle = todayTitle ?? Self.defaultTodayTitle(
            for: resolvedPriority,
            focus: focus,
            limiter: resolvedLimiter,
            detailTitle: resolvedDetailTitle
        )
        self.todayMessage = todayMessage ?? Self.defaultTodayMessage(
            for: resolvedPriority,
            focus: focus,
            limiter: resolvedLimiter,
            activity: activity,
            detailMessage: resolvedDetailMessage
        )
        self.supportBullets = supportBullets ?? Self.defaultSupportBullets(for: resolvedPriority, activity: activity)
        self.whyThisMatters = whyThisMatters
        self.planChallenge = planChallenge
        self.horizon = horizon ?? Self.defaultHorizon(for: focus, limiter: resolvedLimiter)
        let resolvedObjective = objective ??
            Self.defaultObjective(
                for: focus,
                priority: resolvedPriority,
                limiter: resolvedLimiter
            )

        let resolvedOpportunity = opportunity ??
            Self.defaultOpportunity(
                for: focus,
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

    static func defaultPriority(for focus: CoachDayFocus) -> CoachDayPriority {
        switch focus {
        case .hydrationBehind:
            return .hydration
        case .fuelBehind:
            return .fueling
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

    static func defaultTodayTitle(
        for priority: CoachDayPriority,
        focus: CoachDayFocus,
        limiter: CoachLimiter,
        detailTitle: String
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
            return detailTitle.localizedCaseInsensitiveContains("heat")
                ? "Prepare for heat"
                : "Bring fluids up"
        case .fueling:
            return detailTitle.localizedCaseInsensitiveContains("tonight")
                ? "Refuel tonight"
                : "Fuel before training"
        case .planChallenge:
            return focus == .tomorrowPlanRisk ? "Protect tomorrow" : "Lower the ceiling"
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
            return ["Lower tomorrow's ceiling", "Prioritize sleep tonight", "Be willing to swap intensity for recovery"]
        case .performance:
            return ["Lower the ceiling", "Keep intensity flexible", "Protect recovery"]
        case .activeSession:
            return activity.map { ["Stay steady in \($0.title)", "Use small adjustments", "Finish cleanly"] } ?? ["Stay steady"]
        case .stable:
            return ["Keep rhythm", "Follow the plan", "Stay consistent"]
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

    var primaryTrainingActivity: PlannedActivity? {
        dayContext.upcomingTrainingActivities.max {
            CoachActivityContextResolverV3.load(for: $0).riskScore < CoachActivityContextResolverV3.load(for: $1).riskScore
        }
    }

    var hasHardTraining: Bool {
        dayContext.upcomingTrainingStressScore >= 3 ||
            dayContext.upcomingTrainingMinutes >= 75 ||
            primaryTrainingActivity.map {
                let load = CoachActivityContextResolverV3.load(for: $0)
                return load == .high || load == .extreme
            } ?? false
    }
}

struct CoachDecisionContext {
    let brain: HumanBrain.State
    let dayContext: CoachDayContext
    let activityContext: CoachDayActivityContext
    let tomorrowContext: CoachTomorrowPlanContext?
    let recoveryContext: CoachRecoveryContext?
    let nutritionContext: CoachNutritionContext?
    let readiness: CoachReadinessStateV3
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
        let commonSenseMode = commonSenseMode(in: context, intent: intent)
        let objective = objective(in: context, mode: commonSenseMode)
        let candidates = [
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

        return protectedResult.withLimiter(
            dynamicPrimaryLimiter(for: protectedResult, in: context)
        )
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

    static func tomorrowProtectionState(
        for result: CoachDayPriorityResult,
        in context: CoachDecisionContext
    ) -> CoachTomorrowProtectionState {
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

        if result.focus == .tomorrowPlanRisk || context.tomorrowContext?.hasHardTraining == true {
            reasons.append("tomorrow training risk")
        }

        reasons = Array(NSOrderedSet(array: reasons).compactMap { $0 as? String })
        let recommended = !reasons.isEmpty &&
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
        let active = recommended &&
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

        guard let preparing = context.activityContext.preparingActivity,
              isTraining(preparing) else {
            return candidates
        }

        let timingCandidates = candidates.filter { candidate in
            candidate.result.activity?.id == preparing.id &&
                (
                    candidate.result.focus == .prepareForActivity ||
                    candidate.result.focus == .performanceReadiness
                )
        }

        guard !timingCandidates.isEmpty else {
            return candidates
        }

        if hasHeatAheadToday(context),
           hydrationIsCriticallyBehind(context) {
            let hydrationCandidates = candidates.filter { candidate in
                candidate.result.priority == .hydration &&
                    candidate.result.limiter == .hydration
            }
            if !hydrationCandidates.isEmpty {
                return hydrationCandidates
            }
        }

        if prepWindowHasCriticalLimiter(context) {
            return candidates.filter { candidate in
                timingCandidates.contains { $0.result.focus == candidate.result.focus && $0.result.activity?.id == candidate.result.activity?.id } ||
                    isCriticalPrepOverride(candidate.result, in: context)
            }
        }

        return timingCandidates
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
        guard CoachDebugSettings.logLevel == .verbose ||
                debugCandidateLoggingEnabled ||
                ProcessInfo.processInfo.environment["WEEKFIT_COACH_PRIORITY_DEBUG"] == "1" else {
            return
        }

        let selectionOverride = selectionOverrideSummary(
            candidates: candidates,
            eligibleCandidates: eligibleCandidates,
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
        context: CoachDecisionContext
    ) -> String {
        guard eligibleCandidates.count != candidates.count else {
            return "override=none"
        }

        guard let preparing = context.activityContext.preparingActivity,
              isTraining(preparing) else {
            return "override=filteredSelection"
        }

        let eligibleIsPreparation = eligibleCandidates.contains { candidate in
            candidate.result.activity?.id == preparing.id &&
                (
                    candidate.result.focus == .prepareForActivity ||
                    candidate.result.focus == .performanceReadiness
                )
        }

        guard eligibleIsPreparation else {
            return "override=filteredSelection"
        }

        let minutes = minutesUntil(preparing, in: context)
        let reason = minutes.map { "\(displayName(preparing)) starts in \($0) minutes" } ??
            "\(displayName(preparing)) is inside the preparation window"
        let stableExcluded = candidates.contains { $0.result.priority == .stable } &&
            !eligibleCandidates.contains { $0.result.priority == .stable }
        let critical = prepWindowHasCriticalLimiter(context)

        return "override=preparationWindow reason=\"\(reason)\" stableExcluded=\(stableExcluded) criticalLimiterAllowed=\(critical)"
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

    private static func logFuelBehindDecision(
        _ signals: FuelBehindSignals,
        result: Bool,
        in context: CoachDecisionContext
    ) {
        guard CoachDebugSettings.logLevel == .verbose ||
                debugCandidateLoggingEnabled ||
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
        if let active = context.activityContext.activeActivity {
            return activeSessionObjective(active, in: context)
        }

        if let recent = context.activityContext.recentlyCompletedActivity,
           isMeaningfulPostActivityTraining(recent) {
            return .recoverFromActivity
        }

        if isLateNight(context) && localHour(in: context) < Thresholds.dayClosedMorningEndHour {
            return .protectTomorrow
        }

        if isLateNight(context) {
            return .completeDay
        }

        if context.tomorrowContext?.hasHardTraining == true,
           (isEveningOrLater(context) || context.brain.currentHour >= 18) {
            return .protectTomorrow
        }

        if context.tomorrowContext?.hasHardTraining == true,
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
            return .protectTomorrow
        case .dayClosed:
            return isLateNight(context) && localHour(in: context) < Thresholds.dayClosedMorningEndHour ? .protectTomorrow : .completeDay
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

        if context.tomorrowContext?.hasHardTraining == true,
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
                    limiter: .sleep,
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
            guard context.tomorrowContext?.hasHardTraining == true else { return nil }
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
                            "Keep sipping before sauna",
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
                        : "Training is close and preparation basics are behind.",
                    activity: activity,
                    overridesTimingFocus: false,
                    priority: heatCriticalHydration ? .hydration : .performance,
                    strength: heatCriticalHydration ? .critical : (heatPreparation ? .medium : .critical),
                    confidence: 0.90,
                    mode: heatCriticalHydration ? .execution : (heatPreparation ? .recovery : .execution),
                    limiter: heatCriticalHydration ? .hydration : (heatPreparation ? .none : .timing),
                    messageFamily: heatCriticalHydration ? .hydration : (heatPreparation ? .recovery : .performance),
                    todayTitle: title,
                    todayMessage: heatCriticalHydration
                        ? "Bring fluids up before sauna."
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
                        heatPreparation ? "Sauna is a recovery heat block." : "Fuel and hydration are behind."
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
            return context.tomorrowContext?.hasHardTraining == true ? .lateEveningRecovery : .dayClosed

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
        let caloriesCovered = nutrition.caloriesGoal > 0 &&
            nutrition.caloriesCurrent / nutrition.caloriesGoal >= 1.0
        let carbsCovered = nutrition.carbsGoal > 0 &&
            nutrition.carbsCurrent / nutrition.carbsGoal >= 1.0
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
        guard let tomorrow = context.tomorrowContext, tomorrow.hasHardTraining else { return nil }

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

        let activity = tomorrow.primaryTrainingActivity
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
        if context.tomorrowContext?.hasHardTraining == true {
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

        let challenge = context.tomorrowContext?.hasHardTraining == true && (isVeryLowSleep(context) || isHighLoadDay(context))
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
        if context.brain.current.activeCalories >= Thresholds.veryHighActiveCalories {
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
        if context.tomorrowContext?.hasHardTraining == true {
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

        let challenge = context.tomorrowContext?.hasHardTraining == true && score >= 78
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
                    focus: .performanceReadiness,
                    level: yesterdayHadLoad ? .useful : .important,
                    reason: hasLoggedActivityContext
                        ? "Logged training or movement context exists, and readiness creates a useful training opportunity."
                        : "\(noPlanReason) Readiness creates a useful training opportunity.",
                    activity: nil,
                    overridesTimingFocus: true,
                    priority: .performance,
                    strength: yesterdayHadLoad ? .medium : .high,
                    confidence: 0.82,
                    mode: .opportunity,
                    limiter: .none,
                    messageFamily: .performance,
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
                    opportunity: .trainingOpportunity,
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
        switch hour {
        case ..<8:
            return 0.10
        case 8..<10:
            return 0.20
        case 10..<12:
            return 0.35
        case 12..<15:
            return 0.50
        case 15..<18:
            return 0.70
        case 18..<21:
            return 0.85
        default:
            return 0.95
        }
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
        let sweatOrLoadDemand = isHighLoadDay(context) || context.brain.current.activeCalories >= 1_200
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
        let eveningRecoveryPressure = hour >= 17 &&
            ratio < 0.20 &&
            (sweatOrLoadDemand || postLoadPressure || context.tomorrowContext?.hasHardTraining == true || recoveryIsLow(context) || sleepIsPoor(context))
        let safetyPressure = severeFatigueDominates(context) ||
            (hasHeatAheadToday(context) && hydrationIsCriticallyBehind(context))
        let hydrationMayLead = heatSoon ||
            longEnduranceSoon ||
            hardTrainingPreparationPressure ||
            (postLoadPressure && ratio < 0.35) ||
            eveningRecoveryPressure ||
            safetyPressure

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

        let title = heatSoon ? "Prepare for heat" : "Bring fluids up"

        let message = heatSoon
            ? "Do not start heat exposure dry. If you cannot bring fluids up calmly, skip or shorten it."
            : "Fluids matter for the next decision. Sip steadily now, but do not chase the full daily target all at once."

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (heatSoon ? 18 : 6),
            uniquenessScore: heatSoon ? 95 : 68,
            result: CoachDayPriorityResult(
                focus: .hydrationBehind,
                level: level(for: score),
                reason: heatSoon ? "Fluids are low before heat exposure." : "Fluids are low enough to affect the next useful decision.",
                activity: activity,
                overridesTimingFocus: heatSoon || activityIsImmediate || score >= 74,
                priority: .hydration,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: heatSoon ? .warning : .opportunity,
                limiter: .hydration,
                messageFamily: .hydration,
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
        let tomorrowHard = context.tomorrowContext?.hasHardTraining == true
        let ratio = nutritionRatio(context)
        let expectedRatio = expectedNutritionRatio(forHour: hour)
        let criticallyBehindForTime = ratio < max(0.10, expectedRatio - 0.35)

        guard fuelIsBehind(context) else { return nil }

        if hardActivity == nil &&
            !tomorrowHard &&
            !isHighLoadDay(context) &&
            !signals.postTrainingRefuelRequired &&
            !criticallyBehindForTime {
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

        if tomorrowHard {
            score += 18
            reasons.append("Tomorrow's training depends on refueling tonight.")
        }

        if signals.carbsRatio < 0.35 && (hardActivity != nil || tomorrowHard || isHighLoadDay(context)) {
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
        if let hardActivity {
            title = "Fuel before training"
            message = "\(hardActivity.title) needs energy available before it starts. Eat something simple now, then keep the session honest."
        } else if signals.postTrainingRefuelRequired {
            title = "Refuel after training"
            message = "The useful move is recovery support, not chasing calories. Add a simple meal that replaces what the session spent."
        } else if tomorrowHard {
            title = "Refuel tonight"
            message = "The gap is not just about calories. Tomorrow's training depends on replacing enough energy tonight to recover from today."
        } else {
            title = "Add useful fuel"
            message = "Fuel is behind for this point in the day. Add something useful, but do not let nutrition override the bigger training or recovery decision."
        }

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score + (hardActivity != nil ? 16 : 6) + (tomorrowHard ? 8 : 0),
            uniquenessScore: hardActivity != nil ? 88 : 66,
            result: CoachDayPriorityResult(
                focus: .fuelBehind,
                level: level(for: score),
                reason: "Fuel is contextually relevant to the next training or recovery step.",
                activity: activity,
                overridesTimingFocus: context.activityContext.preparingActivity != nil || context.activityContext.activeActivity != nil || score >= 80,
                priority: .fueling,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: hardActivity != nil ? .warning : .opportunity,
                limiter: .fueling,
                messageFamily: .fueling,
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
        guard !severeFatigueDominates(context) else { return nil }

        let kind = CoachActivityContextResolverV3.kind(for: active)
        let score = kind == .recovery ? 52.0 : 62.0
        let activeName = displayName(active).lowercased()

        return PriorityCandidate(
            priorityScore: score,
            insightScore: score - 2,
            uniquenessScore: 50,
            result: CoachDayPriorityResult(
                focus: .activeActivity,
                level: level(for: score),
                reason: "An activity is live and no stronger blocker needs to interrupt it.",
                activity: active,
                overridesTimingFocus: false,
                priority: .activeSession,
                strength: strength(for: score),
                confidence: confidence(for: score),
                mode: .execution,
                limiter: .timing,
                messageFamily: .performance,
                todayTitle: kind == .recovery ? "Keep this \(activeName) easy" : "Keep \(activeName) steady",
                todayMessage: kind == .recovery ? "Let this stay restorative." : "Execute the current block first.",
                title: kind == .recovery ? "Keep this \(activeName) easy" : "Keep \(activeName) steady",
                message: kind == .recovery
                    ? "Use this block to feel better afterward, not to prove fitness."
                    : "You are in \(displayName(active).lowercased()) now. Keep the effort repeatable and make small adjustments before fatigue gets loud.",
                supportBullets: kind == .recovery
                    ? ["Stay comfortable", "Let breathing settle", "Finish fresher than you started"]
                    : ["Start easy", "Sip before you feel dry", "Back off if form drops"],
                whyThisMatters: "Good execution is coaching too: keep the session useful without turning it into extra stress.",
                reasons: ["Current session is active.", "No critical fuel, hydration, or recovery blocker is ahead of it."]
            )
        )
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

        guard !isFoodMeal(completed), !isHydrationLog(completed) else { return nil }
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
        let tomorrowHard = context.tomorrowContext?.hasHardTraining == true
        let tomorrowLoad = context.tomorrowContext?.dayContext.upcomingTrainingStressScore ?? 0
        let highLoadToday = isHighLoadDay(context) || context.dayContext.hasMeaningfulLoadCompleted
        let timeBucket = localTimeBucket(in: context)
        let lateNight = timeBucket == .lateNight
        let sleepLimited = sleepIsPoor(context) || isVeryLowSleep(context)
        let recoveryLimited = recoveryIsLow(context)
        let severeEveningLimiter = protectTomorrowHasSafetyLimiter(context)

        guard hydrationBehindNow ||
                fuelBehindNow ||
                tomorrowHard ||
                tomorrowLoad > 0 ||
                highLoadToday ||
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

        if lateNight {
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
            limiter = sleepLimited ? .sleep : .recovery
            title = "Close the day"
            todayTitle = "Close the day"
            todayMessage = "Let recovery take over."
            message = "The day is basically done. Keep the evening calm, recover, and make tomorrow easier to start."
            support = ["Keep the evening calm", "Avoid extra intensity", "Protect sleep"]
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

    private static func highReadinessOpportunityCandidate(in context: CoachDecisionContext) -> PriorityCandidate? {
        guard !hasLiveOrImmediateActivity(context) else { return nil }
        guard !isEveningOrLater(context), !isOvernightBeforeDayStart(context) else { return nil }
        guard !fuelIsBehind(context), !hydrationIsBehind(context), !recoveryIsLow(context), !sleepIsPoor(context) else { return nil }
        guard !context.dayContext.hasMeaningfulLoadCompleted else { return nil }
        guard context.tomorrowContext?.hasHardTraining != true else { return nil }

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
            let tomorrowText = context.tomorrowContext?.hasHardTraining == true
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

        if context.tomorrowContext?.hasHardTraining == true {
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
            if context.tomorrowContext?.hasHardTraining == true {
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
        if let nutrition = context.nutritionContext, nutrition.caloriesGoal > 0 {
            return nutrition.caloriesCurrent / nutrition.caloriesGoal
        }

        return context.brain.current.caloriesProgress
    }

    static func proteinRatio(_ context: CoachDecisionContext) -> Double {
        if let nutrition = context.nutritionContext, nutrition.proteinGoal > 0 {
            return nutrition.proteinCurrent / nutrition.proteinGoal
        }

        return context.brain.current.proteinProgress
    }

    static func carbsRatio(_ context: CoachDecisionContext) -> Double {
        if let nutrition = context.nutritionContext, nutrition.carbsGoal > 0 {
            return nutrition.carbsCurrent / nutrition.carbsGoal
        }

        return context.brain.current.carbsProgress
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
            context.brain.current.energyCoverage < 0.25 ||
            carbsRatio(context) < 0.15
    }

    static func hydrationIsCriticallyBehind(_ context: CoachDecisionContext) -> Bool {
        guard !hydrationGoalReached(context) else { return false }

        return hydrationRatio(context) < 0.30 ||
               context.brain.hydration == .depleted
    }
    
    static func tomorrowPlanRiskPriority(in context: CoachDecisionContext) -> CoachDayPriorityResult? {
        guard let tomorrow = context.tomorrowContext else { return nil }
        guard tomorrow.hasHardTraining else { return nil }
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
        if let tomorrow = context.tomorrowContext, tomorrow.hasHardTraining {
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
        guard hasSeriousReadinessIssue(context) else { return nil }

        let activity = context.activityContext.activeActivity ??
            context.activityContext.preparingActivity ??
            context.activityContext.laterTodayActivity

        guard let activity, isTraining(activity) else { return nil }

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

        return CoachDayPriorityResult(
            focus: .trainingReadinessWarning,
            level: .high,
            reason: "Recovery/readiness is low relative to the training demand today.",
            activity: activity,
            overridesTimingFocus: true
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
            focus: .hydrationBehind,
            level: hasHeatSoon || highLoadHydrationGap ? .high : .important,
            reason: hasHeatSoon
                ? "Fluids are low before heat exposure."
                : (highLoadHydrationGap
                    ? "Fluids are low on a high-load day."
                    : "Fluids are low for what the rest of the day needs."),
            activity: activity,
            overridesTimingFocus: shouldOverride,
            priority: .hydration,
            strength: hasHeatSoon || highLoadHydrationGap ? .critical : .high,
            title: hasHeatSoon ? "Prepare for heat" : "Support the next block",
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

        guard hardActivity != nil ||
              context.brain.current.energyCoverage < Thresholds.fuelBehindHardWorkoutRatio else {
            return nil
        }

        guard !timingIsImmediate || context.brain.current.energyCoverage < 0.45 else {
            return nil
        }

        return CoachDayPriorityResult(
            focus: .fuelBehind,
            level: .important,
            reason: "Nutrition is behind the current day demand.",
            activity: activity,
            overridesTimingFocus: timingIsImmediate,
            priority: .fueling,
            strength: .high,
            title: "Fuel before the hard work",
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
        if context.brain.current.activeCalories >= Thresholds.veryHighActiveCalories {
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
        context.brain.current.activeCalories / Thresholds.estimatedActivityGoalCalories
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
        let caloriesBehind = caloriesRatio < 0.35 || context.brain.current.energyCoverage < 0.35
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
                caloriesRatio < 0.18 ||
                context.brain.current.energyCoverage < 0.45
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

        // Night / early morning: 0 water is normal, not a limiter.
        // Exception: sauna / endurance is active or soon.
        if hour < 10 {
            return heatSoon || enduranceDemand
        }

        // Late morning: only meaningful if still almost nothing logged
        // or there is heat/endurance demand.
        if hour < 12 {
            return heatSoon || enduranceDemand || ratio < 0.15
        }

        // Early afternoon.
        if hour < 15 {
            return ratio < 0.35
        }

        // Afternoon / evening.
        if hour < 20 {
            return ratio < 0.55
        }

        // Late evening.
        return ratio < 0.70
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
        let tomorrowHard = context.tomorrowContext?.hasHardTraining == true
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
        let text = "\(activity.type) \(activity.title)".lowercased()
        return text.contains("walk") ||
            text.contains("walking") ||
            text.contains("hike")
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
