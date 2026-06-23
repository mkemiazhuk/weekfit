import Foundation
import WeekFitCoachCore

enum CoachActivityClassification {
    static func tokenText(for activity: PlannedActivity) -> String {
        WeekFitCoachCore.CoachActivityClassification.tokenText(for: activity.coachDescriptor)
    }

    static func isRecoveryTier(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isRecoveryTier(activity.coachDescriptor)
    }

    static func isSignificantWorkout(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isSignificantWorkout(activity.coachDescriptor)
    }

    static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isWalkLike(activity.coachDescriptor)
    }

    static func isHikeLike(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isHikeLike(activity.coachDescriptor)
    }
}

/// Keeps completed light recovery modalities on stable day planning unless there is
/// an independent recovery deficit or meaningful training load.
enum CoachLightRecoveryStableDayPolicy {

    static func isActuallyCompleted(_ activity: PlannedActivity, now: Date) -> Bool {
        guard activity.isCompleted else { return false }

        if activity.healthKitWorkoutUUID != nil || activity.source == "appleWorkout" {
            return true
        }

        if let actualMinutes = activity.actualDurationMinutes, actualMinutes > 0 {
            return true
        }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = CoachActivityClassification.tokenText(for: activity)
        if kind == .heat || text.contains("sauna") || text.contains("steam") {
            return false
        }

        return activity.terminalState(now: now) == .completed
    }

    static func isPlannedActivity(_ activity: PlannedActivity, now: Date) -> Bool {
        !isActuallyCompleted(activity, now: now) &&
            activity.terminalState(now: now) == .planned
    }

    static func isLightRecoveryModality(_ activity: PlannedActivity) -> Bool {
        guard !CoachActivityClassification.isSignificantWorkout(activity) else { return false }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        if kind == .heat { return false }

        let text = CoachActivityClassification.tokenText(for: activity)
        return text.contains("walk") ||
            text.contains("walking") ||
            text.contains("hike") ||
            text.contains("yoga") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("breath")
    }

    static func hasIndependentRecoveryDeficit(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 65 {
            return true
        }
        if input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5 {
            return true
        }
        if input.brain.sleep == .short || input.brain.sleep == .veryShort {
            return true
        }
        if input.brain.readiness == .low ||
            input.brain.readiness == .compromised ||
            input.brain.recovery == .compromised ||
            input.brain.recovery == .vulnerable {
            return true
        }
        if guidance.priority.limiter == .sleep ||
            guidance.priority.limiter == .trainingReadiness ||
            guidance.priority.limiter == .accumulatedFatigue ||
            guidance.priority.limiter == .recovery {
            return true
        }
        if input.dayContext.completedActivities.contains(where: CoachActivityClassification.isSignificantWorkout) {
            return true
        }
        if input.dayContext.completedTrainingStressScore >= 2,
           input.dayContext.lastCompletedActivity.map(isLightRecoveryModality) != true {
            return true
        }
        if input.dayContext.hasMeaningfulLoadCompleted,
           input.dayContext.lastCompletedActivity.map(isLightRecoveryModality) != true {
            return true
        }
        if guidance.priority.focus == .tomorrowPlanRisk {
            return true
        }
        return false
    }

    static func lightRecoveryOnlyCompletedToday(_ input: CoachInputSnapshot, now: Date) -> Bool {
        let completed = input.dayContext.completedActivities.filter { isActuallyCompleted($0, now: now) }
        guard !completed.isEmpty else { return false }
        return completed.allSatisfy(isLightRecoveryModality)
    }

    static func isRecoveryPlanModality(_ activity: PlannedActivity) -> Bool {
        isLightRecoveryModality(activity) || isCompletedHeatActivity(activity)
    }

    static func hasOnlyRecoveryPlanModalitiesRemaining(_ input: CoachInputSnapshot) -> Bool {
        let calendar = Calendar.current
        let remaining = input.plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: input.now) &&
                !activity.isCompleted &&
                !activity.isSkipped &&
                activity.date >= input.now
        }
        return remaining.allSatisfy(isRecoveryPlanModality)
    }

    static func ownsStableDayAfterCompletedLightActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard !hasIndependentRecoveryDeficit(input: input, guidance: guidance) else { return false }
        guard lightRecoveryOnlyCompletedToday(input, now: input.now) else { return false }
        guard hasOnlyRecoveryPlanModalitiesRemaining(input) else { return false }
        guard input.recoveryContext.recoveryPercent >= 75 else { return false }
        return true
    }

    static func ownsStableDayAfterCompletedLightActivity(in context: CoachDecisionContext) -> Bool {
        if context.brain.recovery == .compromised ||
            context.brain.recovery == .vulnerable ||
            context.brain.readiness == .low ||
            context.brain.readiness == .compromised ||
            context.brain.sleep == .short ||
            context.brain.sleep == .veryShort {
            return false
        }
        if let recoveryPercent = context.recoveryContext?.recoveryPercent, recoveryPercent < 75 {
            return false
        }
        if context.tomorrowDemand.isHard { return false }

        let completed = context.dayContext.completedActivities.filter {
            isActuallyCompleted($0, now: context.dayContext.now)
        }
        guard !completed.isEmpty, completed.allSatisfy(isLightRecoveryModality) else { return false }

        let calendar = Calendar.current
        let remaining = context.dayContext.upcomingActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: context.dayContext.now) &&
                !activity.isCompleted &&
                !activity.isSkipped &&
                activity.date >= context.dayContext.now
        }
        return remaining.allSatisfy(isRecoveryPlanModality)
    }

    static func stableDayOwnershipRecommendationEnglish() -> (title: String, subtitle: String) {
        (
            title: "Keep today's rhythm steady",
            subtitle: "No extra load is needed now"
        )
    }

    static func stableDayOwnershipRecommendationRussian() -> (title: String, subtitle: String) {
        (
            title: "Сохраняйте обычный ритм",
            subtitle: "Дополнительная нагрузка сейчас не нужна"
        )
    }

    static func stableDayCalmOverviewEnglish() -> (title: String, subtitle: String) {
        (
            title: "Nothing special needs changing",
            subtitle: "The day is unfolding calmly"
        )
    }

    static func stableDayCalmOverviewRussian() -> (title: String, subtitle: String) {
        (
            title: "Ничего специально менять не нужно",
            subtitle: "День развивается спокойно"
        )
    }

    static func isDayPlanningIntentHour(_ now: Date) -> Bool {
        (5..<18).contains(Calendar.current.component(.hour, from: now))
    }

    static func hasActiveInSessionActivity(_ input: CoachInputSnapshot, now: Date) -> Bool {
        input.plannedActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let end = activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, 1) * 60))
            return activity.date <= now && now <= end
        }
    }

    static func shouldForceStableOverview(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard case .stable = guidance.phase else { return false }
        guard !hasIndependentRecoveryDeficit(input: input, guidance: guidance) else { return false }

        if hasActiveInSessionActivity(input, now: input.now) {
            return false
        }

        if let focus = guidance.priority.activity, isLightRecoveryModality(focus) {
            return true
        }

        if lightRecoveryOnlyCompletedToday(input, now: input.now) {
            return true
        }

        return false
    }

    static func recoveryPriorityIsJustified(
        result: CoachDayPriorityResult,
        context: CoachDecisionContext
    ) -> Bool {
        if result.limiter != .none {    
            return true
        }
        if result.focus == .postActivityRecovery || result.focus == .tomorrowPlanRisk {
            return true
        }
        if context.dayContext.completedActivities.contains(where: CoachActivityClassification.isSignificantWorkout) {
            return true
        }
        if context.dayContext.completedTrainingStressScore >= 2 {
            return true
        }
        if context.dayContext.hasMeaningfulLoadCompleted {
            return true
        }
        if context.brain.recovery == .compromised ||
            context.brain.recovery == .vulnerable ||
            context.brain.readiness == .low ||
            context.brain.readiness == .compromised {
            return true
        }
        if context.brain.sleep == .short || context.brain.sleep == .veryShort {
            return true
        }
        if let recoveryPercent = context.recoveryContext?.recoveryPercent, recoveryPercent < 65 {
            return true
        }
        if context.tomorrowDemand.isHard &&
            (context.dayContext.hasMeaningfulLoadCompleted || context.dayContext.completedTrainingStressScore >= 2) {
            return true
        }
        return false
    }

    static func shouldDowngradeRecoveryPriority(
        result: CoachDayPriorityResult,
        context: CoachDecisionContext
    ) -> Bool {
        let isRecoveryPriority = result.focus == .recoveryNeeded ||
            result.focus == .eveningWindDown ||
            result.priority == .recovery
        guard isRecoveryPriority else { return false }
        guard result.limiter == .none else { return false }

        if let activity = result.activity,
           isLightRecoveryModality(activity),
           isPlannedActivity(activity, now: context.dayContext.now) {
            return true
        }

        if recoveryPriorityIsJustified(result: result, context: context) {
            return false
        }

        if let activity = result.activity, isLightRecoveryModality(activity) {
            return true
        }

        return lightRecoveryOnlyCompletedToday(in: context)
    }

    static func lightRecoveryOnlyCompletedToday(in context: CoachDecisionContext) -> Bool {
        let completed = context.dayContext.completedActivities.filter {
            isActuallyCompleted($0, now: context.dayContext.now)
        }
        guard !completed.isEmpty else { return false }
        return completed.allSatisfy(isLightRecoveryModality)
    }

    static func normalizedPriorityResult(
        _ result: CoachDayPriorityResult,
        context: CoachDecisionContext
    ) -> CoachDayPriorityResult {
        guard shouldDowngradeRecoveryPriority(result: result, context: context) else {
            return result
        }

        let hero = stableDayHero(context: context, activity: result.activity)

        return CoachDayPriorityResult(
            focus: .dailyOverview,
            level: .quiet,
            reason: "Light recovery plan day without an independent recovery limiter.",
            activity: result.activity,
            overridesTimingFocus: true,
            priority: .stable,
            strength: .medium,
            confidence: result.confidence,
            mode: .reinforcement,
            limiter: .none,
            messageFamily: .stable,
            priorityScore: result.priorityScore,
            insightScore: result.insightScore,
            uniquenessScore: result.uniquenessScore,
            decisionScore: result.decisionScore,
            todayTitle: hero.english,
            todayMessage: hero.russian,
            detailTitle: hero.english,
            detailMessage: hero.russian,
            supportBullets: result.supportBullets,
            whyThisMatters: "Easy movement and planned recovery should stay on the day plan, not become a recovery intervention.",
            reasons: result.reasons + ["lightRecoveryStableDayInvariant"],
            planChallenge: result.planChallenge,
            horizon: result.horizon,
            objective: .completeDay,
            opportunity: result.opportunity,
            interventionValue: .none,
            interventionCostNote: result.interventionCostNote,
            completionState: result.completionState,
            tomorrowProtection: result.tomorrowProtection
        )
    }

    static func normalizedGuidance(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachGuidanceV3 {
        let priority = guidance.priority
        guard shouldDowngradeRecoveryPriority(
            result: priority,
            input: input,
            guidance: guidance
        ) else {
            return guidance
        }

        let hero = stableDayHero(input: input, activity: priority.activity)
        let normalizedPriority = CoachDayPriorityResult(
            focus: .dailyOverview,
            level: .quiet,
            reason: "Light recovery plan day without an independent recovery limiter.",
            activity: priority.activity,
            overridesTimingFocus: true,
            priority: .stable,
            strength: .medium,
            confidence: priority.confidence,
            mode: .reinforcement,
            limiter: .none,
            messageFamily: .stable,
            priorityScore: priority.priorityScore,
            insightScore: priority.insightScore,
            uniquenessScore: priority.uniquenessScore,
            decisionScore: priority.decisionScore,
            todayTitle: hero.english,
            todayMessage: hero.russian,
            detailTitle: hero.english,
            detailMessage: hero.russian,
            supportBullets: priority.supportBullets,
            whyThisMatters: priority.whyThisMatters,
            reasons: priority.reasons + ["lightRecoveryStableDayInvariant"],
            planChallenge: priority.planChallenge,
            horizon: priority.horizon,
            objective: .completeDay,
            opportunity: priority.opportunity,
            interventionValue: .none,
            interventionCostNote: priority.interventionCostNote,
            completionState: priority.completionState,
            tomorrowProtection: priority.tomorrowProtection
        )

        return CoachGuidanceV3(
            phase: guidance.phase,
            opportunity: guidance.opportunity,
            priority: normalizedPriority,
            shouldSurface: guidance.shouldSurface,
            stateLabel: guidance.stateLabel,
            title: hero.english,
            message: hero.russian,
            insightTitle: guidance.insightTitle,
            insightSubtitle: guidance.insightSubtitle,
            supportActions: guidance.supportActions,
            avoidNotes: guidance.avoidNotes,
            icon: guidance.icon,
            color: guidance.color,
            importance: guidance.importance,
            tone: guidance.tone,
            screenStory: guidance.screenStory,
            v5Contract: guidance.v5Contract,
            narrativePlan: guidance.narrativePlan,
            dayDecisionFrame: guidance.dayDecisionFrame
        )
    }

    static func shouldDowngradeRecoveryPriority(
        result: CoachDayPriorityResult,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let isRecoveryPriority = result.focus == .recoveryNeeded ||
            result.focus == .eveningWindDown ||
            result.priority == .recovery
        guard isRecoveryPriority else { return false }
        guard result.limiter == .none else { return false }

        if let activity = result.activity,
           isLightRecoveryModality(activity),
           isPlannedActivity(activity, now: input.now) {
            return true
        }

        if hasIndependentRecoveryDeficit(input: input, guidance: guidance) {
            return false
        }

        if let activity = result.activity, isLightRecoveryModality(activity) {
            return true
        }

        return lightRecoveryOnlyCompletedToday(input, now: input.now)
    }

    static func stableDayHero(
        context: CoachDecisionContext,
        activity: PlannedActivity?
    ) -> (english: String, russian: String) {
        if let activity,
           isLightRecoveryModality(activity),
           isPlannedActivity(activity, now: context.dayContext.now) {
            return plannedRemainingHero(for: activity)
        }
        if let remaining = context.dayContext.upcomingActivities.sorted(by: { $0.date < $1.date }).first,
           isLightRecoveryModality(remaining) {
            return plannedRemainingHero(for: remaining)
        }
        if lightRecoveryOnlyCompletedToday(in: context) {
            return calmDayHero(completedCount: context.dayContext.completedActivities.count)
        }
        return ("Today is going calmly", "День идёт спокойно")
    }

    static func stableDayHero(
        input: CoachInputSnapshot,
        activity: PlannedActivity?
    ) -> (english: String, russian: String) {
        if let activity,
           isLightRecoveryModality(activity),
           isPlannedActivity(activity, now: input.now) {
            return plannedRemainingHero(for: activity)
        }
        if let summary = CoachDayPlanReadBuilder.build(input: input),
           let remaining = summary.remainingLabels.first {
            if summary.completedLabels.isEmpty || summary.completedLabels.last?.english == remaining.english {
                return plannedRemainingHero(label: remaining)
            }
        }
        if lightRecoveryOnlyCompletedToday(input, now: input.now) {
            return calmDayHero(completedCount: input.dayContext.completedActivities.count)
        }
        return ("Today is going calmly", "День идёт спокойно")
    }

    static func plannedRemainingHero(for activity: PlannedActivity) -> (english: String, russian: String) {
        let text = CoachActivityClassification.tokenText(for: activity)
        if text.contains("walk") || text.contains("walking") || text.contains("hike") {
            return ("Walk is still on today's plan", "Прогулка ещё в плане")
        }
        if text.contains("yoga") {
            return ("Yoga is still on today's plan", "Йога ещё в плане")
        }
        if text.contains("stretch") {
            return ("Stretching is still on today's plan", "Растяжка ещё в плане")
        }
        if text.contains("breath") {
            return ("Breathing is still on today's plan", "Дыхание ещё в плане")
        }
        if text.contains("mobility") {
            return ("Mobility is still on today's plan", "Мобильность ещё в плане")
        }
        let label = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return ("\(label) is still on today's plan", "\(label) ещё в плане")
    }

    static func plannedRemainingHero(label: CoachDayPlanReadBuilder.ActivityLabel) -> (english: String, russian: String) {
        switch label.english {
        case "walk":
            return ("Walk is still on today's plan", "Прогулка ещё в плане")
        case "yoga":
            return ("Yoga is still on today's plan", "Йога ещё в плане")
        case "stretching":
            return ("Stretching is still on today's plan", "Растяжка ещё в плане")
        case "breathing":
            return ("Breathing is still on today's plan", "Дыхание ещё в плане")
        case "mobility":
            return ("Mobility is still on today's plan", "Мобильность ещё в плане")
        default:
            return ("\(label.english) is still on today's plan", "\(label.russian) ещё в плане")
        }
    }

    static func needsVisibleStableDayCorrection(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if story.owner == .recovery || story.owner == .postActivityRecovery {
            return true
        }
        if guidance.priority.focus == .recoveryNeeded || guidance.priority.focus == .eveningWindDown {
            return true
        }
        if guidance.priority.priority == .recovery && guidance.priority.limiter == .none {
            return true
        }
        let title = story.title.resolved.lowercased()
        if title.contains("сауна сделана") ||
            title.contains("отличный прогресс") ||
            title.contains("after sauna") ||
            title.contains("good progress today") {
            return true
        }
        return false
    }

    static func calmHero(for activity: PlannedActivity?) -> (english: String, russian: String) {
        guard let activity else {
            return ("Good day — keep it calm", "Хороший день — дальше спокойно")
        }
        let text = CoachActivityClassification.tokenText(for: activity)
        if text.contains("walk") || text.contains("walking") || text.contains("hike") {
            return ("Walk is logged", "Прогулка учтена")
        }
        return ("Light movement is logged", "Лёгкая активность уже учтена")
    }

    static func calmDayHero(completedCount: Int) -> (english: String, russian: String) {
        if completedCount <= 1 {
            return calmHero(for: nil)
        }
        return ("Good day so far — keep it calm", "Хороший день — дальше спокойно")
    }

    static func isCompletedHeatActivity(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = CoachActivityClassification.tokenText(for: activity)
        return kind == .heat || text.contains("sauna") || text.contains("steam")
    }

    static func caloriesCriticallyLow(_ input: CoachInputSnapshot) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        if calories <= 0 { return true }
        let calorieGoal = input.brain.baseDayGoals.calories
        guard calorieGoal > 0 else { return calories < 200 }
        return calories < 200 || calories / calorieGoal < 0.15
    }

    static func hasHardWorkoutSoonAfter(_ input: CoachInputSnapshot, after referenceDate: Date) -> Bool {
        let calendar = Calendar.current
        return input.plannedActivities.contains { activity in
            guard calendar.isDate(activity.date, inSameDayAs: input.now) else { return false }
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            guard activity.date > referenceDate else { return false }
            if CoachActivityClassification.isSignificantWorkout(activity) { return true }
            let load = CoachActivityContextResolverV3.load(for: activity)
            return load == .high || load == .extreme
        }
    }

    static func shouldShowFuelWarning(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        activity: PlannedActivity?
    ) -> Bool {
        if caloriesCriticallyLow(input) { return true }

        if guidance.priority.focus == .dailyOverview && guidance.priority.priority == .stable {
            return false
        }

        let focusActivity = activity ?? guidance.priority.activity
        guard let focusActivity, isLightRecoveryModality(focusActivity) else {
            if guidance.priority.limiter == .fueling,
               !(guidance.priority.focus == .dailyOverview && guidance.priority.priority == .stable) {
                return true
            }
            return true
        }

        if focusActivity.effectiveDurationMinutes > 60 { return true }
        if CoachActivityClassification.isSignificantWorkout(focusActivity) { return true }
        if hasHardWorkoutSoonAfter(input, after: focusActivity.date) { return true }
        return false
    }

    static func fuelingNeedsPreWorkoutAction(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        activity: PlannedActivity?
    ) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.nutritionContext?.caloriesGoal ?? input.brain.fullDayGoals.calories
        let carbs = input.nutritionContext?.carbsCurrent ?? input.brain.metrics.carbs
        let carbGoal = input.nutritionContext?.carbsGoal ?? input.brain.fullDayGoals.carbs
        let calorieRatio = calorieGoal > 0 ? calories / calorieGoal : 1
        let carbRatio = carbGoal > 0 ? carbs / carbGoal : 1
        let baseFuelingGap = calorieRatio < 0.45 ||
            carbRatio < 0.35 ||
            input.brain.fuel == .underfueled
        guard baseFuelingGap else { return false }
        return shouldShowFuelWarning(input: input, guidance: guidance, activity: activity)
    }
}

/// Prevents completed light-recovery activities from owning the evening wind-down hero.
enum CoachEveningWindDownHeroPolicy {

    static func isEveningWindDownDecision(
        _ guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> Bool {
        if guidance.priority.focus == .eveningWindDown ||
            guidance.priority.priority == .sleepPreparation {
            return true
        }

        return isCalmLateEveningWindDownContext(guidance, input: input)
    }

    static func isCalmLateEveningWindDownContext(
        _ guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> Bool {
        guard CoachFinalStoryBuilder.isLateEveningWindDown(input) else {
            return false
        }
        guard case .stable = guidance.phase else {
            return false
        }
        guard activeActivity(input: input, guidance: guidance) == nil else {
            return false
        }

        // Meals, hydration, and habits can stay on the plan after training is done;
        // only upcoming training should block late-evening wind-down.
        guard input.dayContext.upcomingTrainingActivities.isEmpty else {
            return false
        }

        switch guidance.priority.priority {
        case .stable, .sleepPreparation, .recovery:
            break
        default:
            return false
        }

        switch guidance.priority.focus {
        case .eveningWindDown, .dailyOverview, .recoveryNeeded, .performanceReadiness:
            return true
        default:
            return guidance.priority.limiter == .none
        }
    }

    static func heroTitleReflectsCompletedLightActivity(_ story: CoachFinalStory) -> Bool {
        let title = story.title.resolved.lowercased()
        let english = story.title.fallback.lowercased()

        let markers = [
            "прогулка учтена",
            "walk is logged",
            "лёгкая активность уже учтена",
            "light movement is logged",
            "лёгкая активность — без фанатизма",
            "хороший день — дальше спокойно",
            "good day — keep it calm",
            "good day so far",
            "йога учтена",
            "растяжка учтена",
            "stretching is logged",
            "breathing is logged",
            "mobility is logged",
            "yoga is logged",
            "ещё в плане",
            "still on today's plan"
        ]

        return markers.contains { title.contains($0) || english.contains($0) }
    }

    static func ownerIsDrivenByCompletedLightActivityOnly(
        story: CoachFinalStory,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard story.owner == .recovery ||
                story.owner == .stableOverview ||
                story.owner == .readiness else {
            return false
        }

        guard guidance.priority.focus != .postActivityRecovery else {
            return false
        }

        if let activity = guidance.priority.activity,
           CoachLightRecoveryStableDayPolicy.isActuallyCompleted(activity, now: input.now),
           CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(activity) {
            return true
        }

        if let last = input.dayContext.lastCompletedActivity,
           CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(last),
           input.dayContext.upcomingTrainingActivities.isEmpty,
           activeActivity(input: input, guidance: guidance) == nil {
            return true
        }

        return false
    }

    static func hasRecentSeriousTrainingHeroContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if guidance.priority.focus == .postActivityRecovery {
            if let activity = guidance.priority.activity,
               CoachActivityClassification.isSignificantWorkout(activity) {
                return true
            }
            if input.dayContext.lastCompletedActivity.map(CoachActivityClassification.isSignificantWorkout) == true {
                return true
            }
        }

        if case .recovering(let activity, _, let minutesSinceEnd) = guidance.phase,
           CoachActivityClassification.isSignificantWorkout(activity),
           minutesSinceEnd <= 360 {
            return true
        }

        return false
    }

    static func shouldReplaceHeroWithEveningWindDown(
        story: CoachFinalStory,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard isEveningWindDownDecision(guidance, input: input) else {
            return false
        }

        guard !hasRecentSeriousTrainingHeroContext(input: input, guidance: guidance) else {
            return false
        }

        if heroTitleReflectsCompletedLightActivity(story) {
            return true
        }

        return ownerIsDrivenByCompletedLightActivityOnly(
            story: story,
            input: input,
            guidance: guidance
        )
    }

    static func eveningWindDownStory(
        replacing story: CoachFinalStory,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStory {
        let title = storyText(
            "Evening for recovery",
            russian: "Вечер — на восстановление"
        )
        let assessment = storyText(
            "Today's main activities are already behind you. The priority now is to close the day calmly and protect sleep.",
            russian: "Основные активности на сегодня уже позади. Сейчас важнее спокойно закрыть день и не мешать сну."
        )
        let recommendation = storyText(
            "Leave the plan unchanged and shift into a calm evening rhythm.",
            russian: "Оставьте план без изменений и переходите в спокойный режим."
        )
        let avoid = storyText(
            "Do not add load late in the evening.",
            russian: "Не добавляйте нагрузку поздно вечером."
        )
        let badge = storyText("EVENING", russian: "ВЕЧЕР")
        let heroState = storyText("Wind down", russian: "Спокойный вечер")

        return CoachFinalStory(
            owner: .stableOverview,
            primaryFocus: .eveningWindDown,
            titleKey: story.titleKey,
            subtitleKey: story.subtitleKey,
            badgeState: badge,
            heroState: heroState,
            colorFamily: .stable,
            icon: "moon.stars.fill",
            primaryRecommendationKey: story.primaryRecommendationKey,
            avoidRecommendationKey: story.avoidRecommendationKey,
            title: title,
            subtitle: assessment,
            primaryRecommendation: recommendation,
            avoidRecommendation: avoid,
            whatHappened: assessment,
            whatMattersNow: assessment,
            whatToDoNext: recommendation,
            whatToAvoid: avoid,
            reasons: [
                CoachFinalStoryReason(
                    kind: .time,
                    text: storyText(
                        "Evening wind-down should own the story after today's plan is complete.",
                        russian: "Вечерний режим должен вести историю, когда план на сегодня уже закрыт."
                    ),
                    icon: "moon.stars.fill",
                    colorFamily: .stable
                )
            ],
            supportSignals: completedActivitySupportSignals(
                input: input,
                existing: story.supportSignals
            ),
            upNextContext: nil,
            confidence: story.confidence,
            dataReadinessState: story.dataReadinessState,
            primaryAction: CoachFinalStoryAction(
                title: recommendation,
                icon: "moon.stars.fill"
            ),
            supportActions: [],
            decisionContext: story.decisionContext
        )
    }

    static func completedActivitySupportSignals(
        input: CoachInputSnapshot,
        existing: [CoachFinalStorySupportSignal]
    ) -> [CoachFinalStorySupportSignal] {
        let calendar = Calendar.current
        var signals = existing.filter { $0.kind != .recovery && $0.kind != .activity }

        let completed = input.plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: input.now) }
            .filter { CoachLightRecoveryStableDayPolicy.isActuallyCompleted($0, now: input.now) }
            .sorted { $0.date < $1.date }

        for activity in completed {
            if CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(activity) {
                let calm = CoachLightRecoveryStableDayPolicy.calmHero(for: activity)
                signals.append(
                    CoachFinalStorySupportSignal(
                        kind: .recovery,
                        title: storyText(calm.english, russian: calm.russian),
                        icon: "figure.walk"
                    )
                )
            } else if CoachLightRecoveryStableDayPolicy.isCompletedHeatActivity(activity) {
                signals.append(
                    CoachFinalStorySupportSignal(
                        kind: .recovery,
                        title: storyText("Sauna complete", russian: "Сауна завершена"),
                        icon: "flame.fill"
                    )
                )
            }
        }

        return Array(signals.prefix(3))
    }

    private static func activeActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        switch guidance.phase {
        case .active(let activity, _):
            return activity
        case .preparing, .recovering, .stable:
            return input.plannedActivities.first { $0.isActive(at: input.now) }
        }
    }

    private static func storyText(_ english: String, russian: String) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: "",
            fallback: english,
            russianFallback: russian,
            parameters: [],
            russianParameters: []
        )
    }
}

private extension PlannedActivity {
    var coachDescriptor: CoachActivityDescriptor {
        CoachActivityDescriptor(
            type: type,
            title: title,
            icon: icon,
            imageName: imageName
        )
    }
}
