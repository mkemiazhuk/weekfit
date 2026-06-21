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
