import Foundation
import SwiftUI

// MARK: - Coach Engine V3
// Philosophy:
// "Only speak when support meaningfully improves outcome."
//
// V3 is not a tracker.
// It is preparation + recovery guidance around meaningful activity moments.

enum CoachEngineV3 {

    private static let decisionLogLock = NSLock()
    private static var lastDecisionLogSignature: String?
    private static let memoLock = NSLock()
    private static var lastMemoSignature: String?
    private static var lastMemoGuidance: CoachGuidanceV3?

    #if DEBUG
    private static let priorityDebugLock = NSLock()
    private static var lastPriorityDebugSignature: String?
    #endif

    static func decide(
        from brain: HumanBrain.State,
        plannedActivities: [PlannedActivity]? = nil,
        selectedDate: Date = Date(),
        dayContext: CoachDayContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        recoveryContext: CoachRecoveryContext? = nil,
        nutritionContext: CoachNutritionContext? = nil
    ) -> CoachGuidanceV3 {

        let activities = plannedActivities ?? brain.activities
        let resolvedDayContext = dayContext ?? CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: selectedDate,
            now: brain.now
        )
        let decisionNow = resolvedDayContext.now
        let inputSignature = memoSignature(
            brain: brain,
            activities: activities,
            selectedDate: selectedDate,
            decisionNow: decisionNow,
            actualLoad: actualLoad,
            recoveryContext: recoveryContext,
            nutritionContext: nutritionContext
        )

        memoLock.lock()
        if inputSignature == lastMemoSignature, let cached = lastMemoGuidance {
            memoLock.unlock()
            CoachLogger.trace(
                "[CoachRefreshSkipped]",
                "Coach refresh skipped: unchanged fingerprint source=CoachEngineV3.decide"
            )
            return cached
        }
        memoLock.unlock()

        let resolvedRecoveryContext = recoveryContext ?? CoachRecoveryContext(
            recoveryPercent: 0,
            sleepHours: 0
        )

        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: decisionNow,
            brain: brain
        )

        let timingPhase = activityContext.phase

        let timingReadiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: timingPhase
        )

        let decisionContext = CoachDecisionContext(
            brain: brain,
            dayContext: resolvedDayContext,
            activityContext: activityContext,
            tomorrowContext: tomorrowPlanContext(
                activities: activities,
                selectedDate: selectedDate,
                now: decisionNow
            ),
            actualLoad: actualLoad ?? CoachActualLoadSnapshot.fallback(from: brain),
            recoveryContext: resolvedRecoveryContext,
            nutritionContext: nutritionContext,
            readiness: timingReadiness
        )
        CoachLogger.trace(
            "[BrainStateSourceDebug]",
            "mappingSource=CoachEngineV3.decide brainStateUsedByCoachContext sleep=\(brain.sleep) recovery=\(brain.recovery) readiness=\(brain.readiness) brainStateUsedByPriorityResolver sleep=\(decisionContext.brain.sleep) recovery=\(decisionContext.brain.recovery) readiness=\(decisionContext.brain.readiness) sourceTimestamp=\(brain.now.timeIntervalSince1970) snapshotID=unavailable"
        )
        let priority = CoachDayPriorityResolver.resolve(decisionContext)
        logTomorrowPipelineContext(context: decisionContext, selected: priority, rawActivities: activities)
        logDecisionChange(context: decisionContext, selected: priority)
        logPriorityResolution(
            context: decisionContext,
            selected: priority,
            rawActivities: activities
        )

        let phase = priority.phase(for: activityContext)

        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: phase
        )

        let opportunity = CoachSupportOpportunityResolverV3.resolve(
            phase: phase,
            readiness: readiness,
            brain: brain
        )

        let gateShouldSurface = CoachInterventionGateV3.shouldSurface(
            opportunity: opportunity,
            phase: phase,
            readiness: readiness,
            brain: brain
        )

        let shouldSurface = gateShouldSurface || priority.level >= .useful

        let humanDecision = HumanCoachDecisionEngine.resolve(
            context: decisionContext,
            priority: priority
        )

        let guidance = HumanCoachDecisionEngine.adapt(
            humanDecision,
            phase: phase,
            opportunity: opportunity,
            legacyPriority: priority,
            activityIdentityIsCertain: activityContext.activeActivityIdentityIsCertain,
            activeSessionPhase: activityContext.activeSessionPhase
        )

        logRenderChain(guidance, nutritionContext: nutritionContext)
        assertLimiterConsistency(guidance)
        assertHydrationRenderConsistency(guidance, nutritionContext: nutritionContext)

        memoLock.lock()
        lastMemoSignature = inputSignature
        lastMemoGuidance = guidance
        memoLock.unlock()

        return guidance
    }
}

private extension CoachEngineV3 {
    static func logRenderChain(
        _ guidance: CoachGuidanceV3,
        nutritionContext: CoachNutritionContext?
    ) {
        #if DEBUG
        let renderedState = guidance.screenStory?.stateLabel ?? guidance.stateLabel
        let screenStoryType = guidance.screenStory.map { story in
            story.narrativePlan.map { "badge=\($0.badgeIntent)" } ?? "legacy"
        } ?? "nil"
        let waterCurrent = nutritionContext?.waterCurrent ?? -1.0
        let waterGoal = nutritionContext?.waterGoal ?? -1.0
        let hydrationRatio = (nutritionContext?.waterGoal ?? 0.0) > 0
            ? (nutritionContext?.waterCurrent ?? 0.0) / (nutritionContext?.waterGoal ?? 1.0)
            : -1.0

        CoachRefreshDebug.log(
            "[CoachRenderChain]",
            """
            priority=\(guidance.priority.priority)/\(guidance.priority.focus) \
            limiter=\(guidance.priority.limiter) strength=\(guidance.priority.strength) \
            screenStoryType=\(screenStoryType) renderedState="\(renderedState)" \
            waterCurrent=\(String(format: "%.2f", waterCurrent)) waterGoal=\(String(format: "%.2f", waterGoal)) hydrationRatio=\(String(format: "%.2f", hydrationRatio))
            """
        )
        #endif
    }

    static func assertHydrationRenderConsistency(
        _ guidance: CoachGuidanceV3,
        nutritionContext: CoachNutritionContext?
    ) {
        #if DEBUG
        guard let nutritionContext else { return }
        let hydrationRatio = nutritionContext.waterGoal > 0
            ? nutritionContext.waterCurrent / nutritionContext.waterGoal
            : 1
        guard nutritionContext.waterCurrent <= 0.05 || hydrationRatio < 0.20 else { return }
        let hydrationOwnsNarrative = guidance.priority.limiter == .hydration &&
            guidance.priority.strength == .critical &&
            guidance.narrativePlan?.primaryLimiter == .hydration
        guard hydrationOwnsNarrative else { return }

        let renderedState = guidance.screenStory?.stateLabel ?? guidance.stateLabel
        let forbiddenStates = ["GOOD TO GO", "ON TRACK"]
        let storyRead = guidance.screenStory?.myRead ?? guidance.message

        assert(
            !forbiddenStates.contains(renderedState),
            "Critical hydration-owned day rendered forbidden neutral state \(renderedState)."
        )
        assert(
            !storyRead.localizedCaseInsensitiveContains("Nothing in the current day asks for a major change right now"),
            "Hydration-limited day rendered neutral no-intervention copy."
        )
        #endif
    }

    static func assertLimiterConsistency(_ guidance: CoachGuidanceV3) {
        #if DEBUG
        guard let narrativeLimiter = guidance.narrativePlan?.primaryLimiter else { return }
        let expectedLimiter = expectedNarrativeLimiter(from: guidance.priority.limiter)
        assert(
            narrativeLimiter == expectedLimiter,
            "Coach render limiter \(narrativeLimiter) diverged from priority limiter \(guidance.priority.limiter)."
        )
        #endif
    }

    static func expectedNarrativeLimiter(from limiter: CoachLimiter) -> CoachNarrativeLimiter {
        switch limiter {
        case .sleep:
            return .sleep
        case .recovery, .accumulatedFatigue, .trainingReadiness, .insufficientRecoveryTime:
            return .recovery
        case .hydration:
            return .hydration
        case .fueling:
            return .fuel
        case .upcomingTraining, .excessivePlannedLoad:
            return .futureLoad
        case .timing:
            return .timing
        case .none:
            return .none
        }
    }

    private static func isHydrationLog(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title) \(activity.imageName) \(activity.source)".lowercased()

        return text.contains("hydration") ||
            text.contains("water")
    }

    static func memoSignature(
        brain: HumanBrain.State,
        activities: [PlannedActivity],
        selectedDate: Date,
        decisionNow: Date,
        actualLoad: CoachActualLoadSnapshot?,
        recoveryContext: CoachRecoveryContext?,
        nutritionContext: CoachNutritionContext?
    ) -> String {
        let selectedDay = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        let activitySignature = activities
            .sorted { $0.id < $1.id }
            .map(activityMemoSignature)
            .joined(separator: "|")
        let hydrationLogCount = activities.filter(isHydrationLog).count

        return [
            "locale=\(WeekFitCurrentLocale().identifier)",
            "day=\(Int(selectedDay))",
            "hydrationLogs=\(hydrationLogCount)",
            metricsSignature(brain.metrics),
            goalsSignature(brain.fullDayGoals),
            "sleep=\(brain.sleep)",
            "hydration=\(brain.hydration)",
            "fuel=\(brain.fuel)",
            "strain=\(brain.strain)",
            "recovery=\(brain.recovery)",
            "readiness=\(brain.readiness)",
            actualLoadSignature(actualLoad),
            recoverySignature(recoveryContext),
            nutritionSignature(nutritionContext),
            activitySignature
        ].joined(separator: "#")
    }

    static func activityMemoSignature(_ activity: PlannedActivity) -> String {
        [
            activity.id,
            "\(Int(activity.date.timeIntervalSince1970 / 60))",
            activity.type,
            activity.title,
            "\(activity.durationMinutes)",
            "\(activity.actualDurationMinutes ?? -1)",
            activity.imageName,
            "\(activity.calories)",
            "\(activity.protein)",
            "\(activity.carbs)",
            "\(activity.fats)",
            "\(activity.isCompleted)",
            "\(activity.isSkipped)",
            activity.source
        ].joined(separator: ":")
    }

    static func metricsSignature(_ metrics: DailyNutritionMetrics) -> String {
        [
            rounded(metrics.calories),
            rounded(metrics.protein),
            rounded(metrics.carbs),
            rounded(metrics.fats),
            rounded(metrics.fiber),
            rounded(metrics.waterLiters),
            rounded(metrics.activeCalories),
            rounded(metrics.sleepHours),
            rounded(metrics.weightKg)
        ].joined(separator: ",")
    }

    static func goalsSignature(_ goals: NutritionGoals) -> String {
        [
            rounded(goals.calories),
            rounded(goals.protein),
            rounded(goals.carbs),
            rounded(goals.fats),
            rounded(goals.fiber),
            rounded(goals.waterLiters)
        ].joined(separator: ",")
    }

    static func recoverySignature(_ context: CoachRecoveryContext?) -> String {
        guard let context else { return "recovery=nil" }
        return "recovery=\(rounded(Double(context.recoveryPercent))):\(rounded(context.sleepHours))"
    }

    static func actualLoadSignature(_ actualLoad: CoachActualLoadSnapshot?) -> String {
        guard let actualLoad else { return "actualLoad=nil" }
        return [
            "actualLoad=\(actualLoad.source.rawValue)",
            rounded(actualLoad.activeCalories),
            "\(actualLoad.exerciseMinutes ?? -1)",
            "\(actualLoad.standHours ?? -1)",
            rounded(actualLoad.activityProgress ?? -1)
        ].joined(separator: ",")
    }

    static func nutritionSignature(_ context: CoachNutritionContext?) -> String {
        guard let context else { return "nutrition=nil" }
        return [
            rounded(context.caloriesCurrent),
            rounded(context.caloriesGoal),
            rounded(context.proteinCurrent),
            rounded(context.proteinGoal),
            rounded(context.carbsCurrent),
            rounded(context.carbsGoal),
            rounded(context.fatsCurrent),
            rounded(context.fatsGoal),
            rounded(context.waterCurrent),
            rounded(context.waterGoal),
            "\(context.mealsCount ?? -1)",
            "\(context.lastMealTime.map { Int($0.timeIntervalSince1970 / 60) } ?? -1)"
        ].joined(separator: ",")
    }

    static func rounded(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func tomorrowPlanContext(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date
    ) -> CoachTomorrowPlanContext? {
        guard let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: selectedDate
        ) else {
            return nil
        }

        let dayContext = CoachDayContextBuilder.build(
            activities: activities,
            selectedDate: tomorrow,
            now: now
        )

        guard !dayContext.allActivities.isEmpty else {
            return nil
        }

        return CoachTomorrowPlanContext(dayContext: dayContext)
    }

    static func logTomorrowPipelineContext(
        context: CoachDecisionContext,
        selected: CoachDayPriorityResult,
        rawActivities: [PlannedActivity]
    ) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: context.dayContext.date)
        let rawTomorrowActivities = tomorrow.map { date in
            rawActivities.filter { calendar.isDate($0.date, inSameDayAs: date) }
        } ?? []
        let plannedActivitiesTomorrow = rawTomorrowActivities.filter { !$0.isCompleted && !$0.isSkipped }
        let filteredTomorrowActivities = context.tomorrowContext?.dayContext.upcomingTrainingActivities ?? []
        let tomorrowDemand = context.tomorrowDemand

        CoachLogger.trace(
            "[CoachTomorrowPipelineDebug]",
            "stage=engine rawTomorrowActivities=\(debugTomorrowActivities(rawTomorrowActivities)) plannedActivitiesTomorrow=\(debugTomorrowActivities(plannedActivitiesTomorrow)) filteredTomorrowActivities=\(debugTomorrowActivities(filteredTomorrowActivities)) tomorrowDemand=\(tomorrowDemand.level.rawValue) upcomingTrainingStress=\(context.tomorrowContext?.dayContext.upcomingTrainingStressScore ?? 0) selectedTomorrowProtectionTarget=\(debugTomorrowActivity(selected.focus == .tomorrowPlanRisk ? selected.activity : tomorrowDemand.primaryTrainingActivity))"
        )
    }

    static func debugTomorrowActivities(_ activities: [PlannedActivity]) -> String {
        "[" + activities.map { debugTomorrowActivity($0) }.joined(separator: " | ") + "]"
    }

    static func debugTomorrowActivity(_ activity: PlannedActivity?) -> String {
        guard let activity else { return "nil" }
        return "\(activity.title){type=\(activity.type),duration=\(activity.effectiveDurationMinutes),completed=\(activity.isCompleted),skipped=\(activity.isSkipped)}"
    }

    static func logDecisionChange(
        context: CoachDecisionContext,
        selected: CoachDayPriorityResult
    ) {
        let intent = CoachIntentResolver.resolve(context)
        let activity = selected.activity ?? context.activityContext.coachFocusActivity
        let activityState = activity.map { $0.terminalState(now: context.dayContext.now).rawValue } ?? "none"
        let phase = debugPhaseName(context.activityContext.phase)
        let signature = [
            "\(intent)",
            "\(selected.priority)",
            "\(selected.focus)",
            "\(selected.limiter)",
            activity?.id ?? "none",
            activityState,
            phase
        ].joined(separator: "#")

        decisionLogLock.lock()
        let shouldLog = signature != lastDecisionLogSignature
        if shouldLog {
            lastDecisionLogSignature = signature
        }
        decisionLogLock.unlock()

        guard shouldLog else { return }

        CoachLogger.decision(
            """
            intent=\(intent) \
            activity=\(activity.map(debugActivityName) ?? "none") \
            activityState=\(activityState) \
            phase=\(phase) \
            priority=\(selected.priority)/\(selected.focus) \
            limiter=\(selected.limiter)
            """
        )
    }

    static func debugActivityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? activity.type : title
    }

    static func debugPhaseName(_ phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .active:
            return "active"
        case .preparing:
            return "preparing"
        case .recovering:
            return "recovering"
        case .stable:
            return "stable"
        }
    }

    #if DEBUG
    static func logPriorityResolution(
        context: CoachDecisionContext,
        selected: CoachDayPriorityResult,
        rawActivities: [PlannedActivity]
    ) {
        let waterCurrent = context.nutritionContext?.waterCurrent ?? 0
        let waterGoal = context.nutritionContext?.waterGoal ?? 0
        let hydrationRatio = waterGoal > 0 ? waterCurrent / waterGoal : 1
        let decisionMinute = Int(context.dayContext.now.timeIntervalSince1970 / 60)
        let brainMinute = Int(context.brain.now.timeIntervalSince1970 / 60)
        let recoveryPercent = context.recoveryContext?.recoveryPercent ?? -1
        let recoverySleepHours = context.recoveryContext?.sleepHours ?? -1
        let signature = [
            "\(decisionMinute)",
            "\(brainMinute)",
            String(format: "%.2f", waterCurrent),
            String(format: "%.2f", waterGoal),
            String(format: "%.2f", hydrationRatio),
            "\(recoveryPercent)",
            String(format: "%.2f", recoverySleepHours),
            String(format: "%.2f", context.brain.metrics.sleepHours),
            "\(selected.priority)",
            "\(selected.focus)",
            "\(selected.limiter)",
            selected.activity?.id ?? "none"
        ].joined(separator: "|")

        priorityDebugLock.lock()
        let shouldLog = signature != lastPriorityDebugSignature
        if shouldLog {
            lastPriorityDebugSignature = signature
        }
        priorityDebugLock.unlock()

        guard shouldLog else { return }

        let selectedDayActivities = CoachCanonicalDayState.selectedDayActivities(
            from: rawActivities,
            selectedDate: context.dayContext.date
        )
        let coachRelevantActivities = CoachCanonicalDayState.coachRelevantActivities(from: selectedDayActivities)

        CoachRefreshDebug.log(
            "[CoachPriorityDebug]",
            "decisionNowMinute=\(decisionMinute) brainNowMinute=\(brainMinute) rawPlannedActivities=\(rawActivities.count) selectedDayActivities=\(selectedDayActivities.count) visibleFutureUpNextActivities=\(visibleUpNextActivities(in: context, rawActivities: rawActivities).count) coachRelevantActivities=\(coachRelevantActivities.count) hydrationLogs=\(rawActivities.filter(isHydrationLog).count) selectedUpNext=\"\(debugActivity(selectedUpNext(in: context, rawActivities: rawActivities)))\" coachIntent=\(CoachIntentResolver.resolve(context)) selectedCoachActivity=\"\(debugActivity(selected.activity ?? context.activityContext.coachFocusActivity))\" hiddenSupportSignals.count=\(selected.supportBullets.count) recoveryPercent=\(recoveryPercent) recoverySleepHours=\(String(format: "%.2f", recoverySleepHours)) brainSleepHours=\(String(format: "%.2f", context.brain.metrics.sleepHours)) brainSleep=\(context.brain.sleep) brainRecovery=\(context.brain.recovery) brainReadiness=\(context.brain.readiness) completedTrainingStress=\(context.dayContext.completedTrainingStressScore) upcomingTrainingStress=\(context.dayContext.upcomingTrainingStressScore) waterCurrent=\(String(format: "%.2f", waterCurrent)) waterGoal=\(String(format: "%.2f", waterGoal)) hydrationRatio=\(String(format: "%.2f", hydrationRatio)) selected=\(selected.priority)/\(selected.focus) limiter=\(selected.limiter) title=\"\(selected.title)\""
        )

        let classification = coachRelevantActivities.map(activityClassificationDebug).joined(separator: " | ")
        CoachRefreshDebug.log(
            "[CoachActivityClassification]",
            "coachRelevantActivities=\(coachRelevantActivities.count) \(classification)"
        )
    }
    #else
    static func logPriorityResolution(
        context: CoachDecisionContext,
        selected: CoachDayPriorityResult,
        rawActivities: [PlannedActivity]
    ) {}
    #endif
}

#if DEBUG
private extension CoachEngineV3 {
    static func debugActivity(_ activity: PlannedActivity?) -> String {
        guard let activity else { return "none" }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let status: String
        if activity.isCompleted {
            status = "completed"
        } else if activity.isSkipped {
            status = "skipped"
        } else {
            status = "planned"
        }

        return "\(activity.title)|\(activity.date)|\(kind)|\(status)"
    }

    static func activityClassificationDebug(_ activity: PlannedActivity) -> String {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let isWorkout = kind == .workout || kind == .endurance || kind == .heat
        let isRecovery = kind == .recovery

        return """
        id=\(activity.id) type=\(activity.type) category=\(kind) source=\(activity.source) \
        isNutrition=\(CoachCanonicalDayState.isNutritionLog(activity)) \
        isHydration=\(CoachCanonicalDayState.isHydrationLog(activity)) \
        isWorkout=\(isWorkout) isRecovery=\(isRecovery)
        """
    }

    static func selectedUpNext(
        in context: CoachDecisionContext,
        rawActivities: [PlannedActivity]
    ) -> PlannedActivity? {
        context.activityContext.activeActivity ??
            visibleUpNextActivities(in: context, rawActivities: rawActivities).first
    }

    static func visibleUpNextActivities(
        in context: CoachDecisionContext,
        rawActivities: [PlannedActivity]
    ) -> [PlannedActivity] {
        let calendar = Calendar.current

        return rawActivities
            .filter { calendar.isDate($0.date, inSameDayAs: context.dayContext.date) }
            .filter { CoachActivityContextResolverV3.isVisibleScheduleActivity($0) }
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= context.dayContext.now }
            .sorted { $0.date < $1.date }
    }
}
#endif

// MARK: - Main Output

struct CoachGuidanceV3 {
    let phase: CoachActivityPhaseV3
    let opportunity: CoachSupportOpportunityV3
    let priority: CoachDayPriorityResult

    let shouldSurface: Bool

    let stateLabel: String

    // COACH SCREEN
    let title: String
    let message: String

    // TODAY / HIGH-LEVEL INSIGHT
    let insightTitle: String
    let insightSubtitle: String?

    let supportActions: [CoachSupportActionV3]
    let avoidNotes: [String]

    let icon: String
    let color: Color
    let importance: CoachGuidanceImportanceV3
    let tone: CoachToneV3
    let screenStory: CoachScreenStory?
    let v5Contract: CoachV5Contract?
    let narrativePlan: CoachNarrativePlan?
    let dayDecisionFrame: CoachDayDecisionFrame?

    init(
        phase: CoachActivityPhaseV3,
        opportunity: CoachSupportOpportunityV3,
        priority: CoachDayPriorityResult = .defaultOverview,
        shouldSurface: Bool,
        stateLabel: String,
        title: String,
        message: String,
        insightTitle: String,
        insightSubtitle: String?,
        supportActions: [CoachSupportActionV3],
        avoidNotes: [String],
        icon: String,
        color: Color,
        importance: CoachGuidanceImportanceV3,
        tone: CoachToneV3,
        screenStory: CoachScreenStory? = nil,
        v5Contract: CoachV5Contract? = nil,
        narrativePlan: CoachNarrativePlan? = nil,
        dayDecisionFrame: CoachDayDecisionFrame? = nil
    ) {
        self.phase = phase
        self.opportunity = opportunity
        self.priority = priority
        self.shouldSurface = shouldSurface
        self.stateLabel = stateLabel
        self.title = title
        self.message = message
        self.insightTitle = insightTitle
        self.insightSubtitle = insightSubtitle
        self.supportActions = supportActions
        self.avoidNotes = avoidNotes
        self.icon = icon
        self.color = color
        self.importance = importance
        self.tone = tone
        self.screenStory = screenStory
        self.v5Contract = v5Contract
        self.narrativePlan = narrativePlan
        self.dayDecisionFrame = dayDecisionFrame
    }
}

// MARK: - Coach Engine V5 Interpretation Contract

enum CoachPrimaryStoryV5: String, Hashable {
    case activeSession
    case trainingExecution
    case recovery
    case sleepProtection
    case tomorrowProtection
    case readinessWarning
    case trainingPreparation
    case dayMaintenance
}

struct CoachInterpretationV5 {
    let storyType: CoachPrimaryStoryV5
    let stateLabel: String
    let title: String
    let text: String
    let icon: String
    let color: Color
    let shouldSurface: Bool
    let sourceActivityID: String?
    let primaryLimiter: CoachLimiter
    let supportSignals: [CoachSupportKind]

    var compactInsight: DynamicInsight {
        DynamicInsight(
            icon: icon,
            title: title,
            text: text,
            color: color,
            actionLabel: "Coach Insight",
            tags: tags
        )
    }

    private var tags: Set<CoachTag> {
        var result = Set<CoachTag>()

        supportSignals.forEach { signal in
            switch signal {
            case .hydration:
                result.insert(.hydration)
            case .fueling:
                result.insert(.carbs)
            case .recovery:
                result.insert(.recovery)
            case .sleep:
                result.insert(.sleep)
            case .pacing:
                result.insert(.consistency)
            }
        }

        if result.isEmpty {
            result.insert(.consistency)
        }

        return result
    }
}

// MARK: - Coach Phase

enum CoachActivityPhaseV3 {
    case preparing(activity: PlannedActivity, kind: CoachActivityKindV3, minutesUntil: Int)
    case active(activity: PlannedActivity, kind: CoachActivityKindV3)
    case recovering(activity: PlannedActivity, kind: CoachActivityKindV3, minutesSinceEnd: Int)
    case stable
}

enum CoachActivityKindV3 {
    case endurance
    case workout
    case heat
    case recovery
    case meal
    case other
}

enum CoachActivityLoadV3 {
    case low
    case moderate
    case high
    case extreme
}

// MARK: - Readiness

struct CoachReadinessStateV3 {
    let fuelSupportUseful: Bool
    let hydrationSupportUseful: Bool
    let mineralSupportUseful: Bool
    let recoveryProtectionUseful: Bool
    let proteinSupportUseful: Bool
    let lightEveningUseful: Bool
    let hasLowConfidence: Bool
    let primarySignals: [CoachSignalV3]
}

struct CoachSignalV3: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let color: Color
}

// MARK: - Opportunity

enum CoachSupportOpportunityTypeV3 {
    case prepareForEndurance
    case prepareForWorkout
    case prepareForHeat
    case activeEnduranceSupport
    case activeWorkoutSupport
    case activeHeatSupport
    case recoverAfterWorkout
    case recoverAfterHeat
    case protectRecoveryBeforeActivity
    case stable
}

struct CoachSupportOpportunityV3 {
    let type: CoachSupportOpportunityTypeV3
    let importance: CoachGuidanceImportanceV3
    let reason: String
}

enum CoachGuidanceImportanceV3: Int {
    case quiet = 0
    case useful = 1
    case important = 2
    case high = 3
}

enum CoachToneV3 {
    case calm
    case supportive
    case preparation
    case recovery
}

// MARK: - Support Actions

enum CoachSupportActionTypeV3 {
    // Pre-workout
    case lightFueling
    case hydrateBeforeSession
    case breathingReset
    case mobilityPrep
    case keepDigestionLight

    // In-workout
    case steadyHydration
    case sustainEnergy
    case controlIntensity

    // Post-workout
    case cooldown
    case rehydrateGradually
    case lightRecoveryMovement
    case downshiftNervousSystem
    case startRecoveryNutrition

    case stayConsistent
    
    case recoveryMeal
    case electrolyteRecovery
    case sleepPriority
}

enum CoachActionProvenance: String, Hashable {
    case contributor
    case resolvedContributor
    case activeSessionExecution
    case sleepProtection
    case heatSafety
    case recoveryPolicy
    case preparationTiming
}

struct CoachSupportActionV3: Identifiable {
    let id = UUID()
    let type: CoachSupportActionTypeV3
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let actionProvenance: CoachActionProvenance

    init(
        type: CoachSupportActionTypeV3,
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        actionProvenance: CoachActionProvenance = .recoveryPolicy
    ) {
        self.type = type
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.actionProvenance = actionProvenance
    }
}

private func coachV3LocalizedActionText(_ text: String, fallback: String) -> String {
    if text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil {
        return text
    }

    let localized = WeekFitLocalizedString(text)
    if localized != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
        return localized
    }
    return fallback
}

private extension CoachSupportActionTypeV3 {
    var v3RussianFallbackTitle: String {
        switch self {
        case .lightFueling:
            return "Добавьте легкое питание"
        case .hydrateBeforeSession:
            return "Выпейте воды перед тренировкой"
        case .breathingReset:
            return "Сбросьте напряжение дыханием"
        case .mobilityPrep:
            return "Добавьте легкую мобилити"
        case .keepDigestionLight:
            return "Держите еду легкой"
        case .steadyHydration:
            return "Пейте воду спокойно"
        case .sustainEnergy:
            return "Добавьте энергии"
        case .controlIntensity:
            return "Контролируйте интенсивность"
        case .cooldown:
            return "Сделайте заминку"
        case .rehydrateGradually:
            return "Восполняйте жидкость постепенно"
        case .lightRecoveryMovement:
            return "Двигайтесь легко"
        case .downshiftNervousSystem:
            return "Снизьте напряжение"
        case .startRecoveryNutrition:
            return "Поешьте после нагрузки"
        case .stayConsistent:
            return "Сохраняйте рутину"
        case .recoveryMeal:
            return "Съешьте нормальную еду после нагрузки"
        case .electrolyteRecovery:
            return "Восполните минералы"
        case .sleepPriority:
            return "Сохраните сон"
        }
    }

    var v3RussianFallbackSubtitle: String {
        switch self {
        case .lightFueling, .sustainEnergy:
            return "Добавьте энергии без лишней тяжести"
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually:
            return "Пейте для самочувствия, не ради цифры"
        case .breathingReset, .downshiftNervousSystem:
            return "Помогите телу перейти в более спокойный режим"
        case .mobilityPrep, .cooldown, .lightRecoveryMovement:
            return "Держите нагрузку легкой"
        case .keepDigestionLight:
            return "Не добавляйте пищеварительный стресс"
        case .controlIntensity:
            return "Пусть готовность задаёт темп нагрузки"
        case .startRecoveryNutrition, .recoveryMeal:
            return "Дайте организму восстановиться и сохранить качество"
        case .stayConsistent:
            return "Дополнительное исправление не нужно"
        case .electrolyteRecovery:
            return "Полезно после тепла или сильного потоотделения"
        case .sleepPriority:
            return "Сегодняшний сон готовит следующую тренировку"
        }
    }
}

// MARK: - Phase Resolver

// MARK: - Phase Resolver

enum CoachActivityContextResolverV3 {

    static func kind(for activity: PlannedActivity) -> CoachActivityKindV3 {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        if title.contains("sauna") ||
            type.contains("sauna") ||
            title.contains("hot yoga") ||
            type.contains("hot yoga") ||
            title.contains("heat") ||
            type.contains("heat") {
            return .heat
        }

        if type == "meal" ||
            title.contains("meal") ||
            title.contains("lunch") ||
            title.contains("dinner") {
            return .meal
        }

        let isExplicitRecovery =
            type.contains("recovery") ||
            title.contains("recovery block") ||
            title.contains("recovery") ||
            title.contains("breath") ||
            type.contains("breath")

        if isExplicitRecovery {
            return .recovery
        }

        let isRun =
            title.contains("run") ||
            type.contains("run")

        let isSwim =
            title.contains("swim") ||
            title.contains("swimming") ||
            type.contains("swim") ||
            type.contains("swimming")

        let isRide =
            title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("biking") ||
            title.contains("ride") ||
            title.contains("cardio") ||
            type.contains("cycling") ||
            type.contains("cycle") ||
            type.contains("bike") ||
            type.contains("biking") ||
            type.contains("ride") ||
            type.contains("cardio")

        let isWalkOrHike =
            CoachActivityClassification.isWalkLike(activity) ||
            CoachActivityClassification.isHikeLike(activity)

        if isWalkOrHike {
            return .recovery
        }

        if isRun || isRide || isSwim {
            return .endurance
        }

        let isRacketSport =
            title.contains("tennis") ||
            title.contains("squash") ||
            title.contains("padel") ||
            title.contains("pickleball") ||
            title.contains("badminton") ||
            type.contains("tennis") ||
            type.contains("squash") ||
            type.contains("padel") ||
            type.contains("pickleball") ||
            type.contains("badminton")

        if title.contains("gym") ||
            title.contains("strength") ||
            title.contains("hiit") ||
            title.contains("training") ||
            title.contains("workout") ||
            type.contains("gym") ||
            type.contains("strength") ||
            type.contains("hiit") ||
            type.contains("training") ||
            type.contains("workout") ||
            isRacketSport {
            return .workout
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            type.contains("yoga") ||
            type.contains("stretch") ||
            type.contains("mobility") {
            return .recovery
        }

        return .other
    }

    static func load(for activity: PlannedActivity) -> CoachActivityLoadV3 {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        let duration = activity.durationMinutes
        let calories = activityCalories(activity)

        if duration >= 180 || calories >= 1800 {
            return .extreme
        }

        if duration >= 120 || calories >= 1000 {
            return .high
        }

        if CoachActivityClassification.isWalkLike(activity) {
            return calories >= 600 ? .moderate : .low
        }

        if CoachActivityClassification.isHikeLike(activity) {
            if duration >= 180 || calories >= 1000 { return .moderate }
            return .low
        }

        if title.contains("walk") || type.contains("walk") {
            return duration >= 90 || calories >= 500 ? .moderate : .low
        }

        if title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("ride") ||
            title.contains("run") ||
            type.contains("cycling") ||
            type.contains("run") {

            if duration >= 120 || calories >= 1000 { return .high }
            if duration >= 60 || calories >= 400 { return .moderate }
            return .low
        }

        if title.contains("strength") ||
            title.contains("gym") ||
            title.contains("hiit") ||
            title.contains("workout") ||
            type.contains("strength") ||
            type.contains("gym") ||
            type.contains("hiit") ||
            type.contains("workout") {

            if duration >= 90 || calories >= 700 { return .high }
            return .moderate
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            title.contains("recovery") ||
            title.contains("breath") ||
            type.contains("breath") {
            return .low
        }

        return .moderate
    }

    static func activityCalories(_ activity: PlannedActivity) -> Int {
        let mirror = Mirror(reflecting: activity)

        let possibleNames = [
            "activeCalories",
            "calories",
            "caloriesBurned",
            "burnedCalories",
            "energyBurned",
            "activeEnergy"
        ]

        for child in mirror.children {
            guard let label = child.label,
                  possibleNames.contains(label) else {
                continue
            }

            if let value = child.value as? Int {
                return value
            }

            if let value = child.value as? Double {
                return Int(value)
            }

            if let value = child.value as? CGFloat {
                return Int(value)
            }

            if let value = child.value as? Optional<Double>,
               let unwrapped = value {
                return Int(unwrapped)
            }

            if let value = child.value as? Optional<Int>,
               let unwrapped = value {
                return unwrapped
            }
        }

        return 0
    }
}

// MARK: - Readiness Analyzer

enum CoachReadinessAnalyzerV3 {

    static func analyze(
        brain: HumanBrain.State,
        phase: CoachActivityPhaseV3
    ) -> CoachReadinessStateV3 {

        var signals: [CoachSignalV3] = []

        let expectedHydration = expectedHydrationProgress(hour: brain.currentHour)
        let baseCalorieProgress = ratio(brain.metrics.calories, brain.baseDayGoals.calories)
        let baseProteinProgress = ratio(brain.metrics.protein, brain.baseDayGoals.protein)
        let hydrationProgress = brain.current.waterProgress

        let fuelSupportUseful =
            baseCalorieProgress < 0.40 ||
            (brain.currentHour >= 18 && baseCalorieProgress < 0.60) ||
            (brain.currentHour >= 20 && baseCalorieProgress < 0.80 && brain.hasAnyFoodLogged == false)

        let hydrationSupportUseful =
            hydrationProgress < hydrationSupportThreshold(expected: expectedHydration, hour: brain.currentHour)

        let mineralSupportUseful =
            brain.hydration == .excessive ||
            brain.current.waterProgress >= 1.10 ||
            isHeatPhase(phase)

        let recoveryProtectionUseful =
            brain.recovery == .compromised ||
            brain.recovery == .vulnerable ||
            brain.sleep == .veryShort ||
            brain.sleep == .short ||
            brain.strain == .veryHigh

        let proteinSupportUseful =
            baseProteinProgress < 0.40 ||
            (brain.currentHour >= 16 && baseProteinProgress < 0.60) ||
            (brain.currentHour >= 20 && baseProteinProgress < 0.80 && brain.hasAnyFoodLogged == false)

        let lightEveningUseful =
            brain.current.isEvening ||
            brain.current.isLateNight ||
            brain.strain == .high ||
            brain.strain == .veryHigh

        let hasLowConfidence =
            !brain.hasAnyFoodLogged &&
            brain.currentHour >= 12

        if fuelSupportUseful {
            signals.append(
                .init(
                    icon: "bolt.fill",
                    title: "Energy support",
                    text: "A small snack may make this feel easier.",
                    color: .orange
                )
            )
        }

        if hydrationSupportUseful {
            signals.append(
                .init(
                    icon: "drop.fill",
                    title: "Hydration support",
                    text: "A little water now can help later.",
                    color: .blue
                )
            )
        }

        if mineralSupportUseful {
            signals.append(
                .init(
                    icon: "drop.triangle.fill",
                    title: "Mineral support",
                    text: "Electrolytes may help more than plain water here.",
                    color: .blue
                )
            )
        }

        if recoveryProtectionUseful {
            signals.append(
                .init(
                    icon: "heart.text.square.fill",
                    title: "Recovery protection",
                    text: "Go easier today and you’ll probably feel better later.",
                    color: WeekFitTheme.purple
                )
            )
        }

        if proteinSupportUseful {
            signals.append(
                .init(
                    icon: "bolt.shield.fill",
                    title: "Recovery support",
                    text: "Some protein after training may help recovery.",
                    color: WeekFitTheme.purple
                )
            )
        }

        return CoachReadinessStateV3(
            fuelSupportUseful: fuelSupportUseful,
            hydrationSupportUseful: hydrationSupportUseful,
            mineralSupportUseful: mineralSupportUseful,
            recoveryProtectionUseful: recoveryProtectionUseful,
            proteinSupportUseful: proteinSupportUseful,
            lightEveningUseful: lightEveningUseful,
            hasLowConfidence: hasLowConfidence,
            primarySignals: Array(signals.prefix(3))
        )
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

    private static func hydrationSupportThreshold(expected: Double, hour: Int) -> Double {
        if hour >= 20 {
            return 0.50
        }
        return expected * (hour < 12 ? 0.50 : 0.75)
    }

    private static func ratio(_ current: Double, _ goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return max(0, current / goal)
    }

    private static func expectedNutritionProgress(hour: Int) -> Double {
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

    private static func isHeatPhase(_ phase: CoachActivityPhaseV3) -> Bool {
        switch phase {
        case .preparing(_, let kind, _),
             .active(_, let kind),
             .recovering(_, let kind, _):
            return kind == .heat

        case .stable:
            return false
        }
    }
}

// MARK: - Opportunity Resolver

enum CoachSupportOpportunityResolverV3 {

    static func resolve(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachSupportOpportunityV3 {

        switch phase {

        case .preparing(let activity, let kind, let minutesUntil):

            if shouldProtectAfterEarlierHighLoad(
                before: activity,
                kind: kind,
                brain: brain
            ) {
                return .init(
                    type: .protectRecoveryBeforeActivity,
                    importance: kind == .recovery ? .useful : .important,
                    reason: "You’ve already done a lot today."
                )
            }

            switch kind {

            case .endurance:
                let load = CoachActivityContextResolverV3.load(for: activity)

                return .init(
                    type: .prepareForEndurance,
                    importance: load == .low
                        ? .useful
                        : (readiness.recoveryProtectionUseful
                            ? .high
                            : (minutesUntil <= 180 ? .high : .important)),
                    reason: load == .low
                        ? "For light movement, keep it simple."
                        : (readiness.recoveryProtectionUseful
                            ? "You have endurance work coming up, but your body may need an easier approach."
                            : "For longer efforts, eating and drinking a bit earlier usually helps.")
                )

            case .workout:
                let load = CoachActivityContextResolverV3.load(for: activity)

                return .init(
                    type: .prepareForWorkout,
                    importance: load == .low
                        ? .useful
                        : (readiness.recoveryProtectionUseful
                            ? .high
                            : (minutesUntil <= 120 ? .important : .useful)),
                    reason: load == .low
                        ? "For a lighter session, keep prep simple."
                        : (readiness.recoveryProtectionUseful
                            ? "You have a workout coming up, but your body may need an easier approach."
                            : "A little prep now can make the session feel smoother.")
                )

            case .heat:
                return .init(
                    type: .prepareForHeat,
                    importance: .high,
                    reason: "Heat can drain fluids faster than expected."
                )

            case .recovery:
                return .init(
                    type: .prepareForWorkout,
                    importance: .useful,
                    reason: "Start recovery or mobility work gently."
                )

            case .meal, .other:
                return stableOpportunity
            }

        case .active(_, let kind):
            switch kind {

            case .heat:
                return .init(
                    type: .activeHeatSupport,
                    importance: .high,
                    reason: "Heat is active now, so fluids and minerals matter more."
                )

            case .endurance:
                return .init(
                    type: .activeEnduranceSupport,
                    importance: .high,
                    reason: "You’re in the session now. Keep things steady."
                )

            case .workout:
                return .init(
                    type: .activeWorkoutSupport,
                    importance: .important,
                    reason: "You’re in the session now. Keep it steady."
                )

            case .recovery:
                return .init(
                    type: .activeWorkoutSupport,
                    importance: .useful,
                    reason: "Keep this gentle and sip a little water."
                )

            case .meal, .other:
                return stableOpportunity
            }

        case .recovering(_, let kind, _):
            switch kind {

            case .heat:
                return .init(
                    type: .recoverAfterHeat,
                    importance: .important,
                    reason: "After heat, rehydrate slowly and give yourself time."
                )

            case .endurance, .workout, .recovery:
                return .init(
                    type: .recoverAfterWorkout,
                    importance: .important,
                    reason: "Right after training is a good time to recover well."
                )

            case .meal, .other:
                return stableOpportunity
            }
            
        case .stable:
            return stableOpportunity
        }
    }

    private static var stableOpportunity: CoachSupportOpportunityV3 {
        .init(
            type: .stable,
            importance: .quiet,
            reason: "No training or recovery moment needs attention right now."
        )
    }
    
    private static func shouldProtectAfterEarlierHighLoad(
        before upcoming: PlannedActivity,
        kind upcomingKind: CoachActivityKindV3,
        brain: HumanBrain.State
    ) -> Bool {

        // Recovery sessions should still stay encouraged.
        // Low-load endurance-like activities, such as a normal walk, should not be treated as a second workout.
        let upcomingLoad = CoachActivityContextResolverV3.load(for: upcoming)

        guard upcomingKind == .workout || (upcomingKind == .endurance && upcomingLoad != .low) else {
            return false
        }

        guard brain.strain == .high || brain.strain == .veryHigh else {
            return false
        }

        let calendar = Calendar.current

        return brain.activities.contains { activity in
            guard activity.isCompleted else { return false }
            guard calendar.isDate(activity.date, inSameDayAs: upcoming.date) else {
                return false
            }

            guard activity.date < upcoming.date else {
                return false
            }

            let kind = CoachActivityContextResolverV3.kind(for: activity)
            let load = CoachActivityContextResolverV3.load(for: activity)

            return kind == .workout ||
                   kind == .heat ||
                   (kind == .endurance && load != .low)
        }
    }
}

// MARK: - Intervention Gate

enum CoachInterventionGateV3 {

    static func shouldSurface(
        opportunity: CoachSupportOpportunityV3,
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> Bool {

        switch opportunity.type {

        case .stable:
            return false

        case .prepareForHeat, .activeHeatSupport, .recoverAfterHeat:
            return true

        case .protectRecoveryBeforeActivity:
            return true

        case .activeEnduranceSupport, .activeWorkoutSupport:
            return readiness.fuelSupportUseful ||
                   readiness.hydrationSupportUseful ||
                   readiness.mineralSupportUseful

        case .prepareForEndurance:
            guard case .preparing(_, _, let minutesUntil) = phase else {
                return false
            }

            return minutesUntil <= 240

        case .prepareForWorkout:
            guard case .preparing(_, _, let minutesUntil) = phase else {
                return false
            }

            return minutesUntil <= 180

        case .recoverAfterWorkout:
            guard case .recovering(_, _, let minutesSinceEnd) = phase else {
                return false
            }

            return minutesSinceEnd <= 120
//            return minutesSinceEnd <= 180 &&
//                   (
//                    readiness.proteinSupportUseful ||
//                    readiness.fuelSupportUseful ||
//                    readiness.hydrationSupportUseful ||
//                    brain.strain == .high ||
//                    brain.strain == .veryHigh
//                   )
        }
    }
}

// MARK: - Guidance Factory old version

enum CoachGuidanceFactoryV3 {

//    static func make(
//        phase: CoachActivityPhaseV3,
//        readiness: CoachReadinessStateV3,
//        opportunity: CoachSupportOpportunityV3,
//        shouldSurface: Bool,
//        brain: HumanBrain.State
//    ) -> CoachGuidanceV3 {
//
//        if !shouldSurface {
//            return stableGuidance(phase: phase, opportunity: opportunity)
//        }
//
//        switch opportunity.type {
//
//        case .prepareForEndurance:
//            return prepareForEndurance(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .prepareForWorkout:
//            return prepareForWorkout(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .prepareForHeat:
//            return prepareForHeat(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .protectRecoveryBeforeActivity:
//            return protectRecoveryBeforeActivity(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .activeEnduranceSupport:
//            return activeEndurance(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .activeWorkoutSupport:
//            return activeWorkout(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .activeHeatSupport:
//            return activeHeat(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .recoverAfterWorkout:
//            return recoverAfterWorkout(
//                   phase: phase,
//                   readiness: readiness,
//                   opportunity: opportunity,
//                   brain: brain
//               )
//
//        case .recoverAfterHeat:
//            return recoverAfterHeat(
//                phase: phase,
//                readiness: readiness,
//                opportunity: opportunity
//            )
//
//        case .stable:
//            return stableGuidance(phase: phase, opportunity: opportunity)
//        }
//    }
    
    //------------------------ new -----------------------------------
    static func make(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        shouldSurface: Bool,
        brain: HumanBrain.State,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext? = nil,
        activityContext: CoachDayActivityContext,
        priority: CoachDayPriorityResult
    ) -> CoachGuidanceV3 {

        if !shouldSurface {
            return stableGuidance(
                phase: phase,
                opportunity: opportunity,
                dayActivityContext: activityContext,
                priority: priority,
                shouldSurface: false
            )
        }

        if let priorityGuidance = guidanceForPriority(
            priority,
            phase: phase,
            readiness: readiness,
            opportunity: opportunity,
            activityContext: activityContext,
            recoveryContext: recoveryContext,
            nutritionContext: nutritionContext
        ) {
            return priorityGuidance
        }

        let scenario = CoachActivityScenarioResolver.resolve(
            phase: phase,
            brain: brain
        )

        let rule = CoachScenarioRuleEngine.resolve(
            scenario: scenario,
            dayContext: dayContext,
            recoveryContext: recoveryContext,
            nutritionContext: nutritionContext,
            readiness: readiness,
            brain: brain
        )

        return guidanceFromRule(
            phase: phase,
            readiness: readiness,
            opportunity: opportunity,
            rule: rule,
            scenario: scenario,
            priority: priority
        )
    }
    
    private static func guidanceFromRule(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        rule: CoachScenarioRule,
        scenario: CoachActivityScenario,
        priority: CoachDayPriorityResult
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)

        return CoachGuidanceV3(
            phase: phase,
            opportunity: opportunity,
            priority: priority,
            shouldSurface: true,
            stateLabel: rule.stateLabel,
            title: rule.title,
            message: rule.message,
            insightTitle: scenario.stage == .stable
                ? rule.title
                : "\(activityTitle) \(insightStageText(scenario.stage))",
            insightSubtitle: rule.supportFocus.first,
            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: rule.supportActions
            ),
            avoidNotes: rule.avoidNotes,
            icon: primaryIcon(for: priority, phase: phase, fallback: icon(for: scenario)),
            color: color(for: scenario),
            importance: opportunity.importance,
            tone: tone(for: scenario.stage)
        )
    }

    private static func insightStageText(_ stage: CoachActivityStage) -> String {
        switch stage {
        case .before: return "coming up"
        case .during: return "in progress"
        case .after: return "completed"
        case .stable: return ""
        }
    }

    private static func icon(for scenario: CoachActivityScenario) -> String {
        switch scenario.kind {
        case .recovery: return "figure.walk"
        case .endurance: return "figure.run"
        case .workout: return "figure.strengthtraining.traditional"
        case .heat: return "drop.triangle.fill"
        case .meal: return "fork.knife"
        case .other: return "sparkles"
        }
    }

    private static func primaryIcon(
        for priority: CoachDayPriorityResult,
        phase: CoachActivityPhaseV3? = nil,
        fallback: String
    ) -> String {
        if let activity = priority.activity {
            return activityIcon(for: activity)
        }

        if let phaseActivity = activity(from: phase) {
            return activityIcon(for: phaseActivity)
        }

        switch priority.focus {
        case .hydrationBehind:
            return "drop.fill"
        case .fuelBehind:
            return "fork.knife"
        default:
            break
        }

        switch priority.priority {
        case .hydration:
            return "drop.fill"
        case .fueling:
            return "fork.knife"
        default:
            return fallback
        }
    }

    private static func activity(from phase: CoachActivityPhaseV3?) -> PlannedActivity? {
        guard let phase else { return nil }

        switch phase {
        case .preparing(let activity, _, _),
             .active(let activity, _),
             .recovering(let activity, _, _):
            return activity
        case .stable:
            return nil
        }
    }

    private static func primaryIcon(for phase: CoachActivityPhaseV3, fallback: String) -> String {
        if let activity = activity(from: phase) {
            return activityIcon(for: activity)
        }

        return fallback
    }

    private static func activityIcon(for activity: PlannedActivity) -> String {
        let text = [
            activity.title,
            activity.type,
            activity.icon,
            activity.imageName
        ]
        .joined(separator: " ")
        .lowercased()

        if text.contains("water") || text.contains("hydration") || text.contains("hydrate") {
            return "drop.fill"
        }

        if text.contains("meal") ||
            text.contains("food") ||
            text.contains("lunch") ||
            text.contains("dinner") ||
            text.contains("breakfast") ||
            text.contains("snack") ||
            text.contains("fuel") {
            return "fork.knife"
        }

        if text.contains("sauna") || text.contains("heat") {
            return "thermometer.sun.fill"
        }

        if text.contains("tennis") || text.contains("squash") {
            return "figure.tennis"
        }

        if text.contains("swim") || text.contains("pool") {
            return "figure.pool.swim"
        }

        if text.contains("cycling") ||
            text.contains("cycle") ||
            text.contains("bike") ||
            text.contains("bicycle") ||
            text.contains("ride") {
            return "bicycle"
        }

        if text.contains("walking") || text.contains("walk") {
            return "figure.walk"
        }

        if text.contains("running") || text.contains("run") {
            return "figure.run"
        }

        if text.contains("strength") ||
            text.contains("workout") ||
            text.contains("gym") ||
            text.contains("dumbbell") ||
            text.contains("weights") ||
            text.contains("lifting") {
            return "dumbbell.fill"
        }

        if text.contains("stretch") || text.contains("mobility") || text.contains("flexibility") {
            return "figure.flexibility"
        }

        if text.contains("yoga") {
            return "figure.mind.and.body"
        }

        return activity.icon.isEmpty ? "sparkles" : activity.icon
    }

    private static func color(for scenario: CoachActivityScenario) -> Color {
        switch scenario.kind {
        case .recovery: return WeekFitTheme.meal
        case .endurance: return .orange
        case .workout: return WeekFitTheme.meal
        case .heat: return .blue
        case .meal: return WeekFitTheme.meal
        case .other: return .white.opacity(0.7)
        }
    }

    private static func tone(for stage: CoachActivityStage) -> CoachToneV3 {
        switch stage {
        case .before: return .preparation
        case .during: return .supportive
        case .after: return .recovery
        case .stable: return .calm
        }
    }
    
    //------------------------ new -----------------------------------

    private static func prepareForEndurance(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)
        let load = activityLoad(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: load == .low ? "EASY PREP" : "PREPARE",

            title: "\(activityTitle) \(timeText)",
            message: load == .low
                ? "A lighter session is coming up. Keep it simple and comfortable."
                : "A little preparation now usually makes the session feel better later.",

            insightTitle: "\(activityTitle) later today",
            insightSubtitle: timeText,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: load == .low
                    ? [.hydrateBeforeSession, .mobilityPrep, .breathingReset]
                    : [.lightFueling, .hydrateBeforeSession, .keepDigestionLight]
            ),
            avoidNotes: load == .low ? [] : ["Keep it light enough to avoid heavy digestion."],
            icon: primaryIcon(for: phase, fallback: load == .low ? "figure.walk" : "figure.run"),
            color: load == .low ? WeekFitTheme.meal : .orange,
            importance: load == .low ? .useful : opportunity.importance,
            tone: .preparation
        )
    }

    private static func prepareForWorkout(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)
        let load = activityLoad(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: load == .low ? "EASY PREP" : "GET READY",

            title: "\(activityTitle) \(timeText)",
            message: load == .low
                ? "A lighter session is coming up. Keep it simple and comfortable."
                : "You’re about to ask more from your body.",

            insightTitle: "\(activityTitle) later today",
            insightSubtitle: timeText,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: load == .low
                    ? [.hydrateBeforeSession, .mobilityPrep, .breathingReset]
                    : [.lightFueling, .hydrateBeforeSession, .mobilityPrep]
            ),
            avoidNotes: load == .low
                ? []
                : (readiness.recoveryProtectionUseful ? ["Keep intensity flexible if your body feels heavy."] : []),
            icon: primaryIcon(for: phase, fallback: load == .low ? "figure.walk" : "dumbbell.fill"),
            color: WeekFitTheme.meal,
            importance: load == .low ? .useful : opportunity.importance,
            tone: .preparation
        )
    }

    private static func prepareForHeat(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "HEAT PREP",

            title: "\(activityTitle) \(timeText)",
            message: "Heat changes what your body needs.",

            insightTitle: "\(activityTitle) later today",
            insightSubtitle: "Heat prep",

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.hydrateBeforeSession, .keepDigestionLight, .breathingReset]
            ),
            avoidNotes: ["Keep food light before heat."],
            icon: primaryIcon(for: phase, fallback: "thermometer.sun.fill"),
            color: .blue,
            importance: opportunity.importance,
            tone: .preparation
        )
    }

    private static func protectRecoveryBeforeActivity(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let timeText = timeText(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "CAUTION",

            title: "You’ve already done a lot today",
            message: "If you still train later, keep it flexible and don’t chase intensity.",

            insightTitle: "Keep it light today",
            insightSubtitle: "\(activityTitle) \(timeText)",
            
            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.controlIntensity, .hydrateBeforeSession, .downshiftNervousSystem]
            ),
            avoidNotes: ["Keep intensity flexible today."],
            icon: primaryIcon(for: phase, fallback: "heart.text.square.fill"),
            color: WeekFitTheme.purple,
            importance: opportunity.importance,
            tone: .supportive
        )
    }

    private static func activeEndurance(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let activityName = activityTitle.lowercased()

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "SUPPORT NOW",

            title: "Keep your \(activityName) steady",
            message: "It gets harder to catch up once energy starts dropping.",

            insightTitle: "\(activityTitle) in progress",
            insightSubtitle: nil,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.steadyHydration, .sustainEnergy, .controlIntensity]
            ),
            avoidNotes: [],
            icon: primaryIcon(for: phase, fallback: "figure.run"),
            color: .orange,
            importance: opportunity.importance,
            tone: .supportive
        )
    }

    private static func activeWorkout(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let load = activityLoad(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "SUPPORT NOW",

            title: load == .low
                ? "Keep it gentle"
                : "Keep the session steady",

            message: load == .low
                ? "Stay comfortable. Don’t turn recovery into another workout."
                : "This is usually where it helps to stay steady.",

            insightTitle: "\(activityTitle) in progress",
            insightSubtitle: nil,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: load == .low
                    ? [.steadyHydration, .controlIntensity, .breathingReset]
                    : [.steadyHydration, .controlIntensity, .sustainEnergy]
            ),
            avoidNotes: [],
            icon: primaryIcon(for: phase, fallback: load == .low ? "figure.walk" : "dumbbell.fill"),
            color: WeekFitTheme.meal,
            importance: opportunity.importance,
            tone: .supportive
        )
    }

    private static func activeHeat(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "HEAT SUPPORT",

            title: "Hydrate calmly",
            message: "Heat can drain fluids faster than expected.",

            insightTitle: "\(activityTitle) active",
            insightSubtitle: nil,

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.hydrateBeforeSession, .keepDigestionLight, .breathingReset]
            ),
            avoidNotes: ["Avoid heavy food until you feel settled."],
            icon: primaryIcon(for: phase, fallback: "thermometer.sun.fill"),
            color: .blue,
            importance: opportunity.importance,
            tone: .supportive
        )
    }
    
    private static func recoverAfterWorkout(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        brain: HumanBrain.State
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)
        let load = activityLoad(from: phase)
        let narrative = recoveryNarrative(
            activityTitle: activityTitle,
            load: load,
            phase: phase,
            readiness: readiness,
            brain: brain
        )

        let stateLabel: String
        let actions: [CoachSupportActionTypeV3]

        switch load {
        case .extreme:
            stateLabel = "RECOVERY PRIORITY"
            actions = [
                .recoveryMeal,
                .electrolyteRecovery,
                .sleepPriority
            ]

        case .high:
            stateLabel = "RECOVERY FOCUS"
            actions = [
                .recoveryMeal,
                .rehydrateGradually,
                .lightRecoveryMovement
            ]

        case .moderate:
            stateLabel = "RECOVER"
            actions = [
                .startRecoveryNutrition,
                .rehydrateGradually,
                .lightRecoveryMovement
            ]

        case .low:
            stateLabel = "EASY RECOVERY"
            actions = [
                .rehydrateGradually,
                .downshiftNervousSystem,
                .lightRecoveryMovement
            ]
        }

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: stateLabel,
            title: narrative.title,
            message: narrative.message,
            insightTitle: narrative.title,
            insightSubtitle: activityStatsText(from: phase),
            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: actions
            ),
            avoidNotes: load == .extreme || load == .high
                ? ["Avoid adding more intensity today."]
                : [],
            icon: primaryIcon(for: phase, fallback: load == .extreme ? "flame.fill" : "heart.fill"),
            color: load == .extreme ? .orange : WeekFitTheme.purple,
            importance: load == .extreme ? .high : opportunity.importance,
            tone: .recovery
        )
    }

    private static func recoveryNarrative(
        activityTitle: String,
        load: CoachActivityLoadV3,
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachNarrative {

        let stats = activityStatsText(from: phase)
        let hasStats = !stats.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch load {
        case .extreme:
            return CoachNarrative(
                title: "Recovery is the priority",
                message: hasStats
                    ? "\(stats) This was a big load. Start with fluids, a real meal and keep the rest of the day easy."
                    : "This was a big load. Start with fluids, a real meal and keep the rest of the day easy."
            )

        case .high:
            return CoachNarrative(
                title: "Recover after \(activityTitle)",
                message: hasStats
                    ? "\(stats) Rehydrate, eat properly and avoid adding more intensity today."
                    : "Rehydrate, eat properly and avoid adding more intensity today."
            )

        case .moderate:
            if readiness.proteinSupportUseful || readiness.fuelSupportUseful {
                return CoachNarrative(
                    title: "\(activityTitle) complete",
                    message: hasStats
                        ? "\(stats) Replace fluids and get some protein when you can."
                        : "Replace fluids and get some protein when you can."
                )
            }

            return CoachNarrative(
                title: "\(activityTitle) complete",
                message: hasStats
                    ? "\(stats) Let your body settle and keep the next block easy."
                    : "Let your body settle and keep the next block easy."
            )

        case .low:
            return CoachNarrative(
                title: "\(activityTitle) complete",
                message: "Light activity is done. Stay hydrated and return to your normal routine."
            )
        }
    }

    private static func activityStatsText(from phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .recovering(let activity, _, _),
             .active(let activity, _),
             .preparing(let activity, _, _):

            let duration = activity.durationMinutes
            let hours = duration / 60
            let minutes = duration % 60
            let durationText = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"

            let calories = CoachActivityContextResolverV3.activityCalories(activity)

            if calories > 0 {
                return "\(durationText) completed • about \(calories) kcal burned."
            }

            return "\(durationText) completed."

        case .stable:
            return ""
        }
    }

    private static func recoverAfterHeat(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3
    ) -> CoachGuidanceV3 {

        let activityTitle = activityTitle(from: phase)

        return .init(
            phase: phase,
            opportunity: opportunity,
            shouldSurface: true,
            stateLabel: "REHYDRATE",

            title: "Recover slowly after heat",
            message: "The next few hours matter more after heat.",

            insightTitle: "\(activityTitle) completed",
            insightSubtitle: "After heat",

            supportActions: supportActions(
                phase: phase,
                readiness: readiness,
                preferred: [.rehydrateGradually, .downshiftNervousSystem, .lightRecoveryMovement]
            ),
            avoidNotes: ["Give your body a calmer few hours."],
            icon: primaryIcon(for: phase, fallback: "thermometer.sun.fill"),
            color: .blue,
            importance: opportunity.importance,
            tone: .recovery
        )
    }

    private static func stableGuidance(
        phase: CoachActivityPhaseV3,
        opportunity: CoachSupportOpportunityV3,
        dayActivityContext: CoachDayActivityContext,
        priority: CoachDayPriorityResult = .defaultOverview,
        shouldSurface: Bool = false
    ) -> CoachGuidanceV3 {

        return .init(
            phase: phase,
            opportunity: opportunity,
            priority: priority,
            shouldSurface: shouldSurface,
            stateLabel: "OVERVIEW",

            title: priority.detailTitle,
            message: priority.detailMessage,

            insightTitle: priority.todayTitle,
            insightSubtitle: priority.todayMessage,

            supportActions: [
                .init(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: prioritySupportBullet(priority, index: 0, fallback: "Keep your rhythm"),
                    subtitle: priority.todayMessage,
                    color: WeekFitTheme.meal
                )
            ],
            avoidNotes: [],
            icon: primaryIcon(for: priority, phase: phase, fallback: "waveform.path.ecg.rectangle.fill"),
            color: WeekFitTheme.meal,
            importance: .quiet,
            tone: .calm
        )
    }

    private static func guidanceForPriority(
        _ priority: CoachDayPriorityResult,
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        opportunity: CoachSupportOpportunityV3,
        activityContext: CoachDayActivityContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext?
    ) -> CoachGuidanceV3? {

        switch priority.focus {
        case .activeActivity:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .controlIntensity,
                        icon: "speedometer",
                        title: prioritySupportBullet(priority, index: 0, fallback: "Stay steady"),
                        subtitle: "Keep the session useful",
                        color: CoachPalette.warning
                    ),
                    .init(
                        type: .steadyHydration,
                        icon: "drop.fill",
                        title: prioritySupportBullet(priority, index: 1, fallback: "Sip steadily"),
                        subtitle: "Small adjustments beat late catch-up",
                        color: .blue
                    ),
                    .init(
                        type: .breathingReset,
                        icon: "wind",
                        title: prioritySupportBullet(priority, index: 2, fallback: "Finish cleanly"),
                        subtitle: "Avoid turning control into extra stress",
                        color: WeekFitTheme.purple
                    )
                ],
                avoidNotes: priorityAvoidNotes(priority, fallback: "Do not let the live session become extra stress."),
                icon: primaryIcon(for: priority, phase: phase, fallback: "figure.strengthtraining.traditional"),
                color: CoachPalette.training,
                importance: priority.level.guidanceImportance,
                tone: .supportive
            )

        case .prepareForActivity:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .mobilityPrep,
                        icon: "figure.cooldown",
                        title: prioritySupportBullet(priority, index: 0, fallback: "Keep prep light"),
                        subtitle: "Save energy for the session itself",
                        color: CoachPalette.recovery
                    ),
                    .init(
                        type: .hydrateBeforeSession,
                        icon: "drop.fill",
                        title: prioritySupportBullet(priority, index: 1, fallback: "Hydrate steadily"),
                        subtitle: "Start with the basics",
                        color: .blue
                    ),
                    .init(
                        type: .controlIntensity,
                        icon: "speedometer",
                        title: prioritySupportBullet(priority, index: 2, fallback: "Start easy"),
                        subtitle: "Let the warm-up set the ceiling",
                        color: CoachPalette.warning
                    )
                ],
                avoidNotes: priorityAvoidNotes(priority, fallback: "Do not spend the session before it starts."),
                icon: primaryIcon(for: priority, phase: phase, fallback: "sparkles"),
                color: CoachPalette.training,
                importance: priority.level.guidanceImportance,
                tone: .preparation
            )

        case .performanceReadiness:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .mobilityPrep,
                        icon: "figure.cooldown",
                        title: prioritySupportBullet(priority, index: 0, fallback: "Warm up first"),
                        subtitle: "Let the first block confirm readiness",
                        color: CoachPalette.training
                    ),
                    .init(
                        type: .steadyHydration,
                        icon: "drop.fill",
                        title: prioritySupportBullet(priority, index: 1, fallback: "Keep fluids steady"),
                        subtitle: "Maintain the basics during training",
                        color: .blue
                    ),
                    .init(
                        type: .controlIntensity,
                        icon: "speedometer",
                        title: prioritySupportBullet(priority, index: 2, fallback: "Hold the planned ceiling"),
                        subtitle: "Build only if the body agrees",
                        color: CoachPalette.warning
                    )
                ],
                avoidNotes: priority.whyThisMatters.map { [$0] } ?? [],
                icon: primaryIcon(for: priority, phase: phase, fallback: "checkmark.seal.fill"),
                color: CoachPalette.stable,
                importance: priority.level.guidanceImportance,
                tone: .preparation
            )

        case .nextActivityLater, .dailyOverview:
            return stableGuidance(
                phase: phase,
                opportunity: opportunity,
                dayActivityContext: activityContext,
                priority: priority,
                shouldSurface: priority.level >= .useful
            )

        case .postActivityRecovery:
            let hydrationText = nutritionContext?.recommendedHydrationText ?? "Rehydrate gradually"
            let proteinText = nutritionContext?.recommendedProteinText ?? "Add recovery nutrition"

            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .rehydrateGradually,
                        icon: "drop.fill",
                        title: hydrationText,
                        subtitle: "Sip steadily instead of rushing it",
                        color: .blue
                    ),
                    .init(
                        type: .startRecoveryNutrition,
                        icon: "fork.knife",
                        title: proteinText,
                        subtitle: "Give the body material to repair",
                        color: .orange
                    ),
                    .init(
                        type: .downshiftNervousSystem,
                        icon: "heart.fill",
                        title: "Downshift",
                        subtitle: "Give your body a quieter few minutes",
                        color: CoachPalette.recovery
                    )
                ],
                avoidNotes: ["Do not stack intensity before you have recovered."],
                icon: primaryIcon(for: priority, phase: phase, fallback: "heart.fill"),
                color: CoachPalette.recovery,
                importance: priority.level.guidanceImportance,
                tone: .recovery
            )

        case .hydrationBehind:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .hydrateBeforeSession,
                        icon: "drop.fill",
                        title: nutritionContext?.recommendedHydrationText ?? "Drink some water",
                        subtitle: "Small steady sips are enough to start",
                        color: .blue
                    )
                ],
                avoidNotes: priority.activity == nil ? [] : ["Do not start the next block dry."],
                icon: primaryIcon(for: priority, phase: phase, fallback: "drop.fill"),
                color: .blue,
                importance: priority.level.guidanceImportance,
                tone: .supportive
            )

        case .fuelBehind:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .lightFueling,
                        icon: "bolt.fill",
                        title: "Add easy fuel",
                        subtitle: "Keep it simple and digestible",
                        color: .orange
                    ),
                    .init(
                        type: .recoveryMeal,
                        icon: "fork.knife",
                        title: nutritionContext?.recommendedProteinText ?? "Add protein",
                        subtitle: "Support recovery and the rest of the day",
                        color: WeekFitTheme.meal
                    )
                ],
                avoidNotes: ["Avoid waiting until the next session to catch up."],
                icon: primaryIcon(for: priority, phase: phase, fallback: "fork.knife"),
                color: .orange,
                importance: priority.level.guidanceImportance,
                tone: .supportive
            )

        case .tomorrowPlanRisk:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .sleepPriority,
                        icon: "moon.fill",
                        title: prioritySupportBullet(priority, index: 0, fallback: "Protect sleep tonight"),
                        subtitle: "Tonight sets up tomorrow's ceiling",
                        color: WeekFitTheme.purple
                    ),
                    .init(
                        type: .controlIntensity,
                        icon: "speedometer",
                        title: prioritySupportBullet(priority, index: 1, fallback: "Check readiness before training"),
                        subtitle: "Let recovery decide the plan",
                        color: CoachPalette.warning
                    ),
                    .init(
                        type: .mobilityPrep,
                        icon: "figure.cooldown",
                        title: prioritySupportBullet(priority, index: 2, fallback: "Swap intensity for recovery"),
                        subtitle: "Use easy work if readiness stays low",
                        color: CoachPalette.recovery
                    )
                ],
                avoidNotes: priorityAvoidNotes(priority, fallback: "Do not force tomorrow's planned intensity if recovery is still suppressed."),
                icon: primaryIcon(for: priority, phase: phase, fallback: "exclamationmark.triangle.fill"),
                color: CoachPalette.warning,
                importance: priority.level.guidanceImportance,
                tone: .supportive
            )

        case .recoveryNeeded:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .mobilityPrep,
                        icon: "figure.cooldown",
                        title: prioritySupportBullet(priority, index: 0, fallback: "Keep mobility easy"),
                        subtitle: "Stay easy and comfortable",
                        color: CoachPalette.recovery
                    ),
                    .init(
                        type: .sleepPriority,
                        icon: "moon.fill",
                        title: prioritySupportBullet(priority, index: 1, fallback: "Protect tonight's sleep"),
                        subtitle: "Use the next block to wind down",
                        color: WeekFitTheme.purple
                    ),
                    .init(
                        type: .controlIntensity,
                        icon: "speedometer",
                        title: prioritySupportBullet(priority, index: 2, fallback: "Avoid additional training"),
                        subtitle: "Do not add more load tonight",
                        color: CoachPalette.warning
                    )
                ],
                avoidNotes: priorityAvoidNotes(priority, fallback: "Do not turn a low-readiness day into a hard push."),
                icon: primaryIcon(for: priority, phase: phase, fallback: "heart.text.square.fill"),
                color: CoachPalette.recovery,
                importance: priority.level.guidanceImportance,
                tone: .recovery
            )

        case .trainingReadinessWarning:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .controlIntensity,
                        icon: "speedometer",
                        title: "Lower the ceiling",
                        subtitle: "Keep the plan adjustable",
                        color: CoachPalette.warning
                    ),
                    .init(
                        type: .hydrateBeforeSession,
                        icon: "drop.fill",
                        title: "Hydrate first",
                        subtitle: "Support the basics before training",
                        color: .blue
                    )
                ],
                avoidNotes: ["Do not chase the planned intensity if your body is not there today."],
                icon: primaryIcon(for: priority, phase: phase, fallback: "exclamationmark.triangle.fill"),
                color: CoachPalette.warning,
                importance: .high,
                tone: .supportive
            )

        case .eveningWindDown:
            return .init(
                phase: phase,
                opportunity: opportunity,
                priority: priority,
                shouldSurface: true,
                stateLabel: priorityStateLabel(priority),
                title: priority.detailTitle,
                message: priority.detailMessage,
                insightTitle: priority.todayTitle,
                insightSubtitle: priority.todayMessage,
                supportActions: [
                    .init(
                        type: .sleepPriority,
                        icon: "moon.fill",
                        title: "Protect sleep",
                        subtitle: "Keep food, fluids, and intensity gentle",
                        color: WeekFitTheme.purple
                    )
                ],
                avoidNotes: ["Avoid adding unnecessary intensity late."],
                icon: primaryIcon(for: priority, phase: phase, fallback: "moon.stars.fill"),
                color: WeekFitTheme.purple,
                importance: priority.level.guidanceImportance,
                tone: .calm
            )
        }
    }

    private static func prioritySupportBullet(
        _ priority: CoachDayPriorityResult,
        index: Int,
        fallback: String
    ) -> String {
        guard priority.supportBullets.indices.contains(index) else {
            return fallback
        }

        return priority.supportBullets[index]
    }

    private static func priorityStateLabel(_ priority: CoachDayPriorityResult) -> String {
        switch priority.mode {
        case .execution:
            return "EXECUTE"
        case .warning:
            return "LIMITER"
        case .adjustment:
            return "PLAN CHECK"
        case .recovery:
            return priority.limiter == .sleep ? "SLEEP" : "RECOVERY"
        case .opportunity:
            return "OPPORTUNITY"
        case .reinforcement:
            return "READY"
        }
    }

    private static func priorityAvoidNotes(
        _ priority: CoachDayPriorityResult,
        fallback: String
    ) -> [String] {
        var notes: [String] = []

        if let why = priority.whyThisMatters {
            notes.append(why)
        }

        if let challenge = priority.planChallenge {
            notes.append(challenge)
        }

        if notes.isEmpty {
            notes.append(fallback)
        }

        return notes
    }

    private static func todayRecoverySubtitle(
        priority: CoachDayPriorityResult,
        activityContext: CoachDayActivityContext
    ) -> String {
        guard priority.priority == .sleepPreparation else {
            return priority.activity.map { "\($0.title) later" } ?? priority.supportBullets.first ?? ""
        }

        let active = activityContext.activeActivity.map(displayName)
        let next = activityContext.nextUpcomingActivity.map(displayName)

        if let active, let next {
            return "\(active) can support this. \(priority.supportBullets.first ?? "Keep it easy tonight.")"
        }

        if let next {
            return "Use \(next.lowercased()) to wind down, not to add load."
        }

        return priority.supportBullets.first ?? "Keep the rest of the day easy."
    }

    private static func displayName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Activity" : title
    }

    private static func supportActions(
        phase: CoachActivityPhaseV3,
        readiness: CoachReadinessStateV3,
        preferred: [CoachSupportActionTypeV3]
    ) -> [CoachSupportActionV3] {

        var result: [CoachSupportActionV3] = []
        let kind = activityKind(from: phase)
        let load = activityLoad(from: phase)
        let isLightMovement = load == .low
        
        func add(_ type: CoachSupportActionTypeV3) {
            guard !result.contains(where: { $0.type == type }) else { return }

            switch type {

            // MARK: - Pre-workout

            case .lightFueling:
                guard readiness.fuelSupportUseful else { return }
                result.append(.init(
                    type: .lightFueling,
                    icon: "bolt.fill",
                    title: "Eat something light",
                    subtitle: preFuelSubtitle(for: kind),
                    color: .orange
                ))

            case .hydrateBeforeSession:
                guard readiness.hydrationSupportUseful || readiness.mineralSupportUseful else { return }
                result.append(.init(
                    type: .hydrateBeforeSession,
                    icon: "drop.fill",
                    title: "Drink some water",
                    subtitle: "Starting hydrated usually feels better",
                    color: .blue
                ))

            case .breathingReset:
                result.append(.init(
                    type: .breathingReset,
                    icon: "wind",
                    title: "Take a quiet minute",
                    subtitle: breathingSubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            case .mobilityPrep:
                result.append(.init(
                    type: .mobilityPrep,
                    icon: "figure.cooldown",
                    title: mobilityTitle(for: kind),
                    subtitle: mobilitySubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            case .keepDigestionLight:
                result.append(.init(
                    type: .keepDigestionLight,
                    icon: "leaf.fill",
                    title: "Keep food light",
                    subtitle: kind == .heat
                        ? "Keep digestion light before heat"
                        : "Avoid anything heavy before moving",
                    color: WeekFitTheme.meal
                ))

            // MARK: - In-workout

            case .steadyHydration:
                guard readiness.hydrationSupportUseful || readiness.mineralSupportUseful else { return }
                result.append(.init(
                    type: .steadyHydration,
                    icon: "drop.fill",
                    title: "Keep fluids steady",
                    subtitle: "No catch-up target is needed",
                    color: .blue
                ))

            case .sustainEnergy:
                guard readiness.fuelSupportUseful else { return }
                result.append(.init(
                    type: .sustainEnergy,
                    icon: "bolt.fill",
                    title: "Don’t wait too long",
                    subtitle: "A small snack now is easier than catching up later",
                    color: .orange
                ))

            case .controlIntensity:
                result.append(.init(
                    type: .controlIntensity,
                    icon: "speedometer",
                    title: intensityTitle(for: kind),
                    subtitle: intensitySubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            // MARK: - Post-workout

            case .cooldown:
                result.append(.init(
                    type: .cooldown,
                    icon: "figure.cooldown",
                    title: cooldownTitle(for: kind),
                    subtitle: cooldownSubtitle(for: kind),
                    color: WeekFitTheme.purple
                ))

            case .rehydrateGradually:
                guard readiness.hydrationSupportUseful || readiness.mineralSupportUseful else { return }
                result.append(.init(
                    type: .rehydrateGradually,
                    icon: "drop.fill",
                    title: isLightMovement ? "Hydrate lightly" : "Rehydrate gradually",
                    subtitle: isLightMovement ? "No need to overdo it after a light walk" : "Sip over the next hour",
                    color: .blue
                ))

            case .lightRecoveryMovement:
                result.append(.init(
                    type: .lightRecoveryMovement,
                    icon: "figure.walk",
                    title: isLightMovement ? "Stay loose" : "Move lightly",
                    subtitle: isLightMovement ? "Let your body settle naturally" : recoveryMovementSubtitle(for: kind),
                    color: WeekFitTheme.meal
                ))

            case .downshiftNervousSystem:
                guard readiness.lightEveningUseful || readiness.recoveryProtectionUseful else { return }
                result.append(.init(
                    type: .downshiftNervousSystem,
                    icon: "moon.fill",
                    title: "Start winding down",
                    subtitle: "Keep the rest of the day easy",
                    color: WeekFitTheme.purple
                ))

            case .startRecoveryNutrition:
                guard readiness.proteinSupportUseful || readiness.recoveryProtectionUseful else { return }
                result.append(.init(
                    type: .startRecoveryNutrition,
                    icon: "bolt.shield.fill",
                    title: "Get some protein",
                    subtitle: "Help your body repair after training",
                    color: WeekFitTheme.purple
                ))

            case .stayConsistent:
                result.append(.init(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: "Keep your rhythm",
                    subtitle: "Keep your normal rhythm",
                    color: WeekFitTheme.meal
                ))
                
            case .recoveryMeal:

                result.append(
                    .init(
                        type: .recoveryMeal,
                        icon: "fork.knife",
                        title: "Add easy recovery food",
                        subtitle: "Protein plus easy carbs is enough",
                        color: WeekFitTheme.meal
                    )
                )

            case .electrolyteRecovery:

                result.append(
                    .init(
                        type: .electrolyteRecovery,
                        icon: "drop.fill",
                        title: "Replace fluids",
                        subtitle: "Water and electrolytes over the next few hours",
                        color: .blue
                    )
                )

            case .sleepPriority:

                result.append(
                    .init(
                        type: .sleepPriority,
                        icon: "moon.fill",
                        title: "Protect tonight's sleep",
                        subtitle: "Recovery continues while you sleep",
                        color: WeekFitTheme.purple
                    )
                )
            }
        }

        preferred.forEach { add($0) }

        if result.isEmpty {
            result.append(.init(
                type: .stayConsistent,
                icon: "waveform.path.ecg",
                title: "Keep your rhythm",
                subtitle: "Nothing special needed",
                color: WeekFitTheme.meal
            ))
        }

        return Array(result.prefix(3))
    }

    private static func activityKind(from phase: CoachActivityPhaseV3) -> CoachActivityKindV3 {
        switch phase {
        case .preparing(_, let kind, _),
             .active(_, let kind),
             .recovering(_, let kind, _):
            return kind

        case .stable:
            return .other
        }
    }

    private static func activityLoad(from phase: CoachActivityPhaseV3) -> CoachActivityLoadV3 {
        switch phase {
        case .preparing(let activity, _, _),
             .active(let activity, _),
             .recovering(let activity, _, _):
            return CoachActivityContextResolverV3.load(for: activity)

        case .stable:
            return .low
        }
    }

    private static func preFuelSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "A small carb snack may help before the session"
        case .workout:
            return "A small snack may help before training"
        case .heat:
            return "Keep food simple before heat"
        case .recovery:
            return "Keep it light and comfortable"
        case .meal, .other:
            return "Keep it light before activity"
        }
    }

    private static func breathingSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .recovery:
            return "Take a quiet minute before mobility"
        case .heat:
            return "Start calm before heat"
        default:
            return "Take a quiet minute before you start"
        }
    }

    private static func mobilityTitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .recovery:
            return "Ease into it"
        default:
            return "Warm up gently"
        }
    }

    private static func mobilitySubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .workout:
            return "Warm up before loading"
        case .recovery:
            return "Start gently before going deeper"
        default:
            return "Get your body moving first"
        }
    }

    private static func intensityTitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .heat:
            return "Keep it moderate"
        case .recovery:
            return "Keep it gentle"
    
        case .endurance:
            return "Keep the pace comfortable"
        default:
            return "Keep effort steady"
        }
    }

    private static func intensitySubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .heat:
                return "15–30 minutes is usually enough"
        case .endurance:
            return "Stay comfortable instead of chasing effort"
        case .recovery:
            return "Don’t turn recovery into a workout"
        default:
            return "Keep it at a pace you can hold"
        }
    }

    private static func cooldownTitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "Cool down easy"
        case .workout:
            return "Cool down easy"
        case .heat:
            return "Cool down slowly"
        case .recovery:
            return "Finish gently"
        case .meal, .other:
            return "Cool down easy"
        }
    }

    private static func cooldownSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "Spin or walk easy for 5–10 minutes"
        case .workout:
            return "Keep the last 5–10 minutes easy"
        case .heat:
            return "Let your body cool down gradually"
        case .recovery:
            return "Finish with calm breathing or easy movement"
        case .meal, .other:
            return "Keep 5–10 min easy before stopping"
        }
    }

    private static func recoveryMovementSubtitle(for kind: CoachActivityKindV3) -> String {
        switch kind {
        case .endurance:
            return "A short walk can help your legs feel less heavy"
        case .workout:
            return "Gentle walking can help with stiffness"
        case .heat:
            return "Keep movement easy while you rehydrate"
        case .recovery:
            return "Stay loose without adding more load"
        case .meal, .other:
            return "Gentle movement can help recovery"
        }
    }

    private static func activityTitle(from phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .preparing(let activity, _, _),
             .active(let activity, _),
             .recovering(let activity, _, _):

            let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "Activity" : title

        case .stable:
            return "Today"
        }
    }

    private static func timeText(from phase: CoachActivityPhaseV3) -> String {
        switch phase {
        case .preparing(_, _, let minutesUntil):
            if minutesUntil < 60 {
                return "in \(minutesUntil) min"
            }

            let hours = minutesUntil / 60
            let minutes = minutesUntil % 60

            if minutes == 0 {
                return "in \(hours)h"
            }

            return "in \(hours)h \(minutes)m"

        case .active:
            return "is active"

        case .recovering(_, _, let minutesSinceEnd):
            if minutesSinceEnd < 60 {
                return "finished \(minutesSinceEnd) min ago"
            }

            let hours = minutesSinceEnd / 60
            return "finished \(hours)h ago"

        case .stable:
            return ""
        }
    }
}

// MARK: - Adapters

extension CoachGuidanceV3 {

    var v5Interpretation: CoachInterpretationV5 {
        let insight = dynamicInsight
        return CoachInterpretationV5(
            storyType: primaryStoryV5,
            stateLabel: screenStory?.stateLabel ?? stateLabel,
            title: insight.title,
            text: insight.text,
            icon: insight.icon,
            color: insight.color,
            shouldSurface: shouldSurface,
            sourceActivityID: priority.activity?.id,
            primaryLimiter: priority.limiter,
            supportSignals: supportSignalKindsV5
        )
    }

    var dynamicInsight: DynamicInsight {
        return DynamicInsight(
            icon: icon,
            title: insightTitle,
            text: todayTeaserText,
            color: color,
            actionLabel: "Coach Insight",
            tags: coachTags
        )
    }

    private var todayTeaserText: String {
        let planMessage = narrativePlan?.sectionIntents.recommendation
        let message = planMessage ?? (screenStory?.stateLabel == CoachStatus.prepareSession.label
            ? (screenStory?.myRecommendation ?? v5Contract?.what ?? insightSubtitle ?? priority.todayMessage)
            : (v5Contract?.what ?? insightSubtitle ?? priority.todayMessage))

        return CoachTodayInsightTeaser.text(
            title: insightTitle,
            message: message,
            screenStory: screenStory,
            phase: phase
        )
    }

    var coachDecision: CoachDecision {
        CoachDecision(
            primaryStrategy: primaryStrategy,
            secondaryPriorities: secondaryPriorities,
            suppressedActions: suppressedActions,
            hydrationAlreadySolved: false,
            needsElectrolytesInsteadOfWater: isHeatSupport
        )
    }



    private var isHeatSupport: Bool {
        switch opportunity.type {
        case .prepareForHeat, .activeHeatSupport, .recoverAfterHeat:
            return true
        default:
            return false
        }
    }
    
    private var coachTags: Set<CoachTag> {
        var tags = Set<CoachTag>()

        supportActions.forEach { action in
            switch action.type {

            case .lightFueling,
                 .sustainEnergy:
                tags.insert(.carbs)

            case .hydrateBeforeSession,
                 .steadyHydration,
                 .rehydrateGradually:
                tags.insert(.hydration)

            case .startRecoveryNutrition,
                 .recoveryMeal:
                tags.insert(.protein)
                tags.insert(.recovery)

            case .electrolyteRecovery:
                tags.insert(.hydration)
                tags.insert(.minerals)
                tags.insert(.recovery)

            case .sleepPriority:
                tags.insert(.recovery)

            case .breathingReset,
                 .mobilityPrep,
                 .keepDigestionLight,
                 .controlIntensity,
                 .cooldown,
                 .lightRecoveryMovement,
                 .downshiftNervousSystem:
                tags.insert(.recovery)

            case .stayConsistent:
                tags.insert(.consistency)
            }
        }

        if isHeatSupport {
            tags.insert(.minerals)
        }

        if tags.isEmpty {
            tags.insert(.consistency)
        }

        return tags
    }

    private var primaryStoryV5: CoachPrimaryStoryV5 {
        switch priority.focus {
        case .activeActivity:
            return .activeSession
        case .prepareForActivity, .nextActivityLater:
            return .trainingPreparation
        case .postActivityRecovery, .recoveryNeeded:
            return .recovery
        case .tomorrowPlanRisk:
            return .tomorrowProtection
        case .trainingReadinessWarning:
            return .readinessWarning
        case .performanceReadiness:
            return priority.activity == nil ? .dayMaintenance : .trainingExecution
        case .eveningWindDown:
            return priority.limiter == .sleep ? .sleepProtection : .dayMaintenance
        case .hydrationBehind, .fuelBehind:
            return priority.activity == nil ? .dayMaintenance : .trainingPreparation
        case .dailyOverview:
            switch priority.priority {
            case .sleepPreparation:
                return .sleepProtection
            case .recovery:
                return .recovery
            case .planChallenge:
                return .readinessWarning
            default:
                return .dayMaintenance
            }
        }
    }

    private var supportSignalKindsV5: [CoachSupportKind] {
        var kinds: [CoachSupportKind] = []

        func append(_ kind: CoachSupportKind) {
            guard !kinds.contains(kind) else { return }
            kinds.append(kind)
        }

        supportActions.forEach { action in
            switch action.type {
            case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
                append(.hydration)
            case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal:
                append(.fueling)
            case .sleepPriority:
                append(.sleep)
            case .breathingReset, .mobilityPrep, .keepDigestionLight, .controlIntensity, .cooldown, .lightRecoveryMovement, .downshiftNervousSystem:
                append(.recovery)
            case .stayConsistent:
                append(.pacing)
            }
        }

        switch priority.limiter {
        case .hydration:
            append(.hydration)
        case .fueling:
            append(.fueling)
        case .sleep:
            append(.sleep)
        case .recovery, .accumulatedFatigue, .trainingReadiness, .insufficientRecoveryTime:
            append(.recovery)
        case .upcomingTraining, .excessivePlannedLoad, .timing:
            append(.pacing)
        case .none:
            break
        }

        return kinds
    }

    private var primaryStrategy: PrimaryStrategy {
        switch opportunity.type {
        case .prepareForEndurance,
             .prepareForWorkout,
             .activeEnduranceSupport,
             .activeWorkoutSupport:
            return .prepareWorkout

        case .prepareForHeat,
             .activeHeatSupport,
             .recoverAfterHeat:
            return .rehydrate

        case .recoverAfterWorkout:
            return .addProtein

        case .protectRecoveryBeforeActivity:
            return .protectRecovery

        case .stable:
            return .maintain
        }
    }

    private var secondaryPriorities: [CoachPriority] {
        var priorities: [CoachPriority] = []

        func add(_ priority: CoachPriority) {
            guard !priorities.contains(priority) else { return }
            priorities.append(priority)
        }

        supportActions.forEach { action in
            switch action.type {

            case .lightFueling,
                 .sustainEnergy:
                add(.carbs)

            case .hydrateBeforeSession,
                 .steadyHydration,
                 .rehydrateGradually:
                add(.hydration)

            case .startRecoveryNutrition:
                add(.protein)
                add(.recovery)

            case .recoveryMeal:
                add(.carbs)
                add(.protein)
                add(.recovery)

            case .electrolyteRecovery:
                add(.hydration)
                add(.minerals)
                add(.recovery)

            case .sleepPriority:
                add(.recovery)

            case .breathingReset,
                 .mobilityPrep,
                 .keepDigestionLight,
                 .controlIntensity,
                 .cooldown,
                 .lightRecoveryMovement,
                 .downshiftNervousSystem:
                add(.recovery)

            case .stayConsistent:
                break
            }
        }

        if isHeatSupport {
            add(.minerals)
        }

        let preferredOrder: [CoachPriority] = [
            .recovery,
            .hydration,
            .protein,
            .carbs,
            .minerals
        ]

        return priorities.sorted {
            (preferredOrder.firstIndex(of: $0) ?? 999)
                <
            (preferredOrder.firstIndex(of: $1) ?? 999)
        }
    }

    private var suppressedActions: Set<CoachSuppression> {
        var suppressed = Set<CoachSuppression>()

        switch opportunity.type {
        case .prepareForHeat, .activeHeatSupport, .recoverAfterHeat:
            suppressed.insert(.heavyFood)
            suppressed.insert(.workoutPush)

        case .protectRecoveryBeforeActivity:
            suppressed.insert(.workoutPush)

        case .recoverAfterWorkout:
            suppressed.insert(.workoutPush)

        case .prepareForEndurance,
             .prepareForWorkout,
             .activeEnduranceSupport,
             .activeWorkoutSupport:
            suppressed.insert(.heavyFood)

        case .stable:
            break
        }

        return suppressed
    }
}

private enum CoachTodayInsightTeaser {
    private static let maxCharacters = 80

    static func text(
        title: String,
        message: String,
        screenStory: CoachScreenStory?,
        phase: CoachActivityPhaseV3
    ) -> String {
        let sourceCandidates: [String?]
        if case .active = phase {
            sourceCandidates = [
                screenStory?.myRead,
                Optional(message),
                screenStory?.activityContext,
                screenStory?.myRecommendation
            ]
        } else {
            sourceCandidates = [
                screenStory?.myRead,
                Optional(message),
                screenStory?.activityContext,
                screenStory?.myRecommendation
            ]
        }

        let source = sourceCandidates
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? message

        if let activeTeaser = activeSessionTeaser(from: source, phase: phase) {
            return activeTeaser
        }

        if source.count <= maxCharacters {
            return source
        }

        return clippedFirstIdea(from: source)
    }

    private static func activeSessionTeaser(
        from text: String,
        phase: CoachActivityPhaseV3
    ) -> String? {
        let lowercased = text.lowercased()

        if case .active(_, .heat) = phase {
            if lowercased.contains("sleep") || lowercased.contains("downshift") {
                return "Use the sauna to downshift, then cool down."
            }

            if lowercased.contains("relax") {
                return "Use the sauna to relax, not extend the day."
            }
        }

        guard case .active = phase else { return nil }

        if lowercased.contains("ignore targets") || lowercased.contains("first few minutes") {
            return "Ignore targets for the first few minutes."
        }

        if lowercased.contains("repeatable") || lowercased.contains("chasing numbers") {
            return "Keep the effort repeatable."
        }

        if lowercased.contains("reserve") {
            return "Finish with enough reserve to recover well."
        }

        if lowercased.contains("recovery is now the priority") {
            return "Recovery is the priority now."
        }

        return nil
    }

    private static func clippedFirstIdea(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let sentenceEnd = trimmed.firstIndex { ".!?".contains($0) }
        let firstSentence = sentenceEnd.map { String(trimmed[...$0]) } ?? trimmed
        if firstSentence.count <= maxCharacters {
            return firstSentence
        }

        let words = firstSentence.split(separator: " ")
        var result = ""

        for word in words {
            let candidate = result.isEmpty ? String(word) : "\(result) \(word)"
            guard candidate.count <= maxCharacters - 1 else { break }
            result = candidate
        }

        return result.isEmpty ? String(firstSentence.prefix(maxCharacters - 1)) + "…" : result + "…"
    }
}
