import Foundation
import WeekFitPlanner
import WeekFitWidgetShared

/// Builds a Home Screen widget snapshot from live app state (main app only).
enum WidgetSnapshotBuilder {
    static func build(
        now: Date = Date(),
        calendar: Calendar = .current,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        plannedActivities: [PlannedActivity]
    ) -> WeekFitWidgetSnapshot {
        let dateKey = WeekFitWidgetSnapshot.dayKey(for: now, calendar: calendar)
        WeekFitWidgetCopy.applyLanguage(WeekFitUsesRussianLanguage() ? "ru" : "en")
        let activityGoal = max(1, Int(automatedActivityGoal(from: healthManager).rounded()))
        let activityCalories = Int(healthManager.activeCalories.rounded())
        let activityProgress = Double(activityCalories) / Double(activityGoal)
        let hasActivitySignal = healthManager.isHealthAccessGranted || activityCalories > 0

        let budget = NutritionBudgetCalculator.canonicalBudget(from: nutritionViewModel)
        let hasNutritionSignal = nutritionViewModel.nutritionResult != nil || budget.consumed > 0
        let nutritionProgress = budget.progressRatio
        let consumedCalories = Int(budget.consumed.rounded())
        let remainingCalories = TodayNutritionDisplayMetrics.remainingCalories(from: budget)

        let recoveryScore = healthManager.recoveryPercent > 0 ? healthManager.recoveryPercent : nil
        let hasRecoverySignal = healthManager.isHealthAccessGranted && recoveryScore != nil
        let recoveryLabel = recoveryLabel(for: recoveryScore)

        let dayActivities = plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: now)
                && activity.imageName.lowercased() != "hydration"
                && !activity.isSkipped
        }
        let completedItems = dayActivities.filter(\.isCompleted).count
        let totalItems = dayActivities.count

        let presentation = coachCoordinator.state.coachUIPresentation
        let next = nextAction(from: presentation, planned: dayActivities, now: now, calendar: calendar)
        let mode = dayMode(
            recoveryScore: recoveryScore,
            hasAnySignal: hasActivitySignal || hasNutritionSignal || hasRecoverySignal || totalItems > 0
        )
        let guidance = contextualGuidance(
            mode: mode,
            presentation: presentation,
            nextTitle: next.title,
            nextKind: next.kind,
            nextPhase: next.phase,
            hasNext: next.kind != .none && !next.title.isEmpty
        )

        return WeekFitWidgetSnapshot(
            dateKey: dateKey,
            activityProgress: activityProgress,
            activityCalories: activityCalories,
            activityGoal: activityGoal,
            hasActivitySignal: hasActivitySignal,
            nutritionProgress: nutritionProgress,
            consumedCalories: consumedCalories,
            remainingCalories: remainingCalories,
            hasNutritionSignal: hasNutritionSignal,
            recoveryScore: recoveryScore,
            sleepHours: healthManager.sleepHours > 0 ? healthManager.sleepHours : nil,
            recoveryLabel: recoveryLabel,
            hasRecoverySignal: hasRecoverySignal,
            dayMode: mode,
            dayStateLabel: guidance.stateLabel,
            dayGuidance: guidance.hero,
            dayGuidanceDetail: guidance.support,
            nextActionTitle: next.title,
            nextActionSubtitle: next.subtitle,
            nextActionTime: next.time,
            nextActionKind: next.kind,
            nextActionPhase: next.phase,
            completedItems: completedItems,
            totalItems: totalItems,
            updatedAt: now,
            languageCode: WeekFitUsesRussianLanguage() ? "ru" : "en"
        )
    }

    private static func automatedActivityGoal(from healthManager: HealthManager) -> Double {
        let goal = ProfileService().resolvedNutritionGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
        return max(
            ActivityGoalEngine.calculate(
                weightKg: healthManager.weight,
                heightCm: healthManager.heightCm,
                age: healthManager.age,
                sex: healthManager.biologicalSex,
                recoveryPercent: healthManager.recoveryPercent,
                sleepHours: healthManager.sleepHours,
                vo2Max: healthManager.cardioFitnessVO2,
                goal: goal
            ),
            1
        )
    }

    private static func recoveryLabel(for score: Int?) -> String? {
        guard let score else { return nil }
        return WeekFitWidgetCopy.recoveryScoreLabel(for: score)
    }

    private static func dayMode(recoveryScore: Int?, hasAnySignal: Bool) -> WeekFitWidgetSnapshot.DayMode {
        guard hasAnySignal else { return .empty }
        guard let recoveryScore, recoveryScore > 0 else { return .maintain }
        switch recoveryScore {
        case 70...: return .goodToGo
        case 55..<70: return .maintain
        case 40..<55: return .takeItEasy
        default: return .recoveryFocus
        }
    }

    /// Maps Coach + plan into Small hierarchy: state → interpretation → next.
    private static func contextualGuidance(
        mode: WeekFitWidgetSnapshot.DayMode,
        presentation: CoachUIPresentation?,
        nextTitle: String,
        nextKind: WeekFitWidgetSnapshot.NextActionKind,
        nextPhase: WeekFitWidgetSnapshot.NextActionPhase,
        hasNext: Bool
    ) -> (stateLabel: String, hero: String, support: String) {
        if mode == .empty {
            return (
                hasNext ? WeekFitWidgetCopy.dayModeTitle(.empty) : WeekFitWidgetCopy.allClearLabel(),
                hasNext ? WeekFitWidgetCopy.openWeekFitLabel() : WeekFitWidgetCopy.smallHeroFallback(for: .empty, hasNext: false),
                ""
            )
        }

        if !hasNext {
            return (
                mode == .goodToGo || mode == .maintain ? WeekFitWidgetCopy.allClearLabel() : WeekFitWidgetCopy.dayModeTitle(mode),
                WeekFitWidgetCopy.smallHeroFallback(for: mode, hasNext: false),
                ""
            )
        }

        let todayTitle = presentation?.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let recommendation = presentation?.recommendation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let todayMessage = presentation?.todayMessage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let coachNext = presentation?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let eventContextualState: String? = {
            if nextPhase == .inProgress {
                let during = WeekFitWidgetCopy.duringLabel(eventTitle: nextTitle)
                return WeekFitWidgetCopy.compactPhrase(
                    during,
                    limit: WeekFitWidgetCopy.SmallBudget.state,
                    fallback: WeekFitWidgetCopy.dayModeTitle(mode)
                )
            }
            if nextPhase == .due {
                return nil
            }
            if WeekFitWidgetCopy.isEventEcho(todayTitle, nextTitle: nextTitle) {
                return WeekFitWidgetCopy.compactPhrase(
                    todayTitle,
                    limit: WeekFitWidgetCopy.SmallBudget.state,
                    fallback: WeekFitWidgetCopy.beforeLabel(
                        eventTitle: WeekFitWidgetCopy.smallNextTitle(raw: nextTitle, kind: nextKind)
                    )
                )
            }
            if todayTitle.lowercased().contains("before") || todayTitle.lowercased().contains("перед"),
               todayTitle.lowercased().contains(nextTitle.lowercased()) {
                return WeekFitWidgetCopy.compactPhrase(
                    todayTitle,
                    limit: WeekFitWidgetCopy.SmallBudget.state,
                    fallback: WeekFitWidgetCopy.beforeLabel(eventTitle: nextTitle)
                )
            }
            return nil
        }()

        // Prefer a real Coach recommendation as hero when it isn't just echoing the event.
        let recommendationCandidate = [recommendation, coachNext, todayMessage]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { candidate in
                !candidate.isEmpty && !WeekFitWidgetCopy.isEventEcho(candidate, nextTitle: nextTitle)
            }

        if let eventContextualState, let recommendationCandidate {
            let hero = WeekFitWidgetTextFitting.fit(
                recommendationCandidate,
                to: .smallHero,
                fallback: WeekFitWidgetCopy.smallHeroFallback(for: mode, hasNext: true)
            )
            let state = WeekFitWidgetTextFitting.fit(
                eventContextualState,
                to: .smallState,
                fallback: WeekFitWidgetCopy.dayModeTitle(mode)
            )
            return (state, hero, "")
        }

        if let recommendationCandidate {
            return (
                WeekFitWidgetCopy.dayModeTitle(mode),
                WeekFitWidgetTextFitting.fit(
                    recommendationCandidate,
                    to: .smallHero,
                    fallback: WeekFitWidgetCopy.smallHeroFallback(for: mode, hasNext: true)
                ),
                ""
            )
        }

        return (
            WeekFitWidgetCopy.dayModeTitle(mode),
            WeekFitWidgetCopy.smallHeroFallback(for: mode, hasNext: true),
            ""
        )
    }

    private static func nextAction(
        from presentation: CoachUIPresentation?,
        planned: [PlannedActivity],
        now: Date,
        calendar: Calendar
    ) -> (
        title: String,
        subtitle: String,
        time: String?,
        kind: WeekFitWidgetSnapshot.NextActionKind,
        phase: WeekFitWidgetSnapshot.NextActionPhase
    ) {
        let incomplete = planned.filter { !$0.isCompleted }

        let selected: PlannedActivity? = {
            if let live = incomplete.first(where: { phase(for: $0, now: now) == .inProgress }) {
                return live
            }
            if let future = incomplete
                .filter({ $0.date > now })
                .sorted(by: { $0.date < $1.date })
                .first {
                return future
            }
            return incomplete.sorted(by: { $0.date < $1.date }).first
        }()

        if let selected {
            let time = Self.timeString(selected.date, calendar: calendar)
            let duration = selected.durationMinutes > 0 ? "\(selected.durationMinutes) min" : ""
            let resolvedKind = kind(forType: selected.type, imageName: selected.imageName, title: selected.title)
            let title = WeekFitWidgetCopy.mediumNextTitle(raw: selected.title, kind: resolvedKind)
            return (title, duration, time, resolvedKind, phase(for: selected, now: now))
        }

        let action = presentation?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !action.isEmpty else {
            return ("", "", nil, .none, .none)
        }
        let resolvedKind = kind(forType: action, imageName: "", title: action)
        return (
            WeekFitWidgetCopy.mediumNextTitle(raw: action, kind: resolvedKind),
            "",
            nil,
            resolvedKind,
            .upcoming
        )
    }

    /// Maps plan item timing onto widget phase. Duration window = [start, start+duration).
    private static func phase(
        for activity: PlannedActivity,
        now: Date
    ) -> WeekFitWidgetSnapshot.NextActionPhase {
        let start = activity.date
        let durationMinutes = max(0, activity.durationMinutes)
        if now < start { return .upcoming }

        if durationMinutes > 0 {
            let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            if now < end { return .inProgress }
            return .due
        }

        // Point-in-time items: treat as in progress for 15 minutes after start.
        let graceEnd = start.addingTimeInterval(15 * 60)
        if now < graceEnd { return .inProgress }
        return .due
    }

    private static func kind(
        forType type: String,
        imageName: String,
        title: String
    ) -> WeekFitWidgetSnapshot.NextActionKind {
        let haystack = "\(type) \(imageName) \(title)".lowercased()
        if haystack.contains("sauna") || haystack.contains("бан") || haystack.contains("саун") { return .sauna }
        if haystack.contains("cycle") || haystack.contains("bike") || haystack.contains("ride") || haystack.contains("вело") { return .cycling }
        if haystack.contains("run") || haystack.contains("бег") { return .running }
        if haystack.contains("swim") || haystack.contains("плав") { return .swimming }
        if haystack.contains("yoga") || haystack.contains("йога") { return .yoga }
        if haystack.contains("tennis") || haystack.contains("squash") || haystack.contains("теннис") || haystack.contains("сквош") { return .racket }
        if haystack.contains("walk") || haystack.contains("hike") || haystack.contains("ходь") || haystack.contains("прогул") { return .walk }
        if haystack.contains("strength") || haystack.contains("gym") || haystack.contains("lift") || haystack.contains("сил") { return .strength }
        if haystack.contains("recover") || haystack.contains("mobility") || haystack.contains("stretch") || haystack.contains("восстанов") { return .recovery }
        if haystack.contains("meal") || haystack.contains("food") || haystack.contains("eat") { return .meal }
        if haystack.contains("water") || haystack.contains("hydrat") || haystack.contains("drink") { return .hydration }
        if haystack.contains("rest") || haystack.contains("sleep") || haystack.contains("nap") { return .rest }
        return .strength
    }

    private static func timeString(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = WeekFitCurrentLocale()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
