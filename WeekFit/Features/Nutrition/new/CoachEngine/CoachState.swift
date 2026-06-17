import Foundation
import SwiftUI

enum CoachFinalStoryOwner: String, Hashable {
    case activeActivity
    case activityPreparation
    case pacingExecution
    case sustainableExecution
    case fuelingDuringActivity
    case hydrationExecution
    case postActivityRecovery
    case recovery
    case readiness
    case tomorrowProtection
    case stableOverview
    case hydration
    case fuel
}

enum CoachFinalStoryColorFamily: String, Hashable {
    case stable
    case ready
    case recovery
    case activity
    case hydration
    case fuel
    case warning
    case stress
    case live

    var color: Color {
        switch self {
        case .stable:
            return CoachPalette.stable
        case .ready:
            return CoachPalette.stable
        case .recovery:
            return CoachPalette.recovery
        case .activity:
            return CoachPalette.activity
        case .hydration:
            return CoachPalette.hydration
        case .fuel:
            return CoachPalette.fueling
        case .warning:
            return CoachPalette.warning
        case .stress:
            return CoachPalette.stress
        case .live:
            return CoachPalette.activity
        }
    }
}

enum CoachFinalStoryDataReadinessState: String, Hashable {
    case coherent
    case settling
}

struct CoachFinalStoryReadinessAssessment {
    let allowed: Bool
    let dataReadinessState: CoachFinalStoryDataReadinessState
    let satisfiedConditions: [String]
    let blockingReasons: [String]

    var summary: String {
        [
            "allowed=\(allowed)",
            "state=\(dataReadinessState.rawValue)",
            "satisfied=\(satisfiedConditions.joined(separator: ","))",
            "blocked=\(blockingReasons.joined(separator: ","))"
        ].joined(separator: " ")
    }
}

struct CoachFinalStoryText: Hashable {
    let key: String
    let fallback: String
    let russianFallback: String
    let parameters: [String]
    let russianParameters: [String]

    var resolved: String {
        if key.hasPrefix("coach.") || key.hasPrefix("common.") || key.hasPrefix("today.") {
            let localized = WeekFitLocalizedString(key)
            if localized != key {
                return String(
                    format: localized,
                    arguments: WeekFitCurrentLocale().identifier.hasPrefix("ru")
                        ? russianParameters.map { $0 as CVarArg }
                        : parameters.map { $0 as CVarArg }
                )
            }
        }

        if WeekFitCurrentLocale().identifier.hasPrefix("ru"),
           !russianFallback.isEmpty {
            return russianFallback
        }

        let runtime = WeekFitCoachRuntimeLocalizedString(fallback)
        if runtime != fallback || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return runtime
        }

        return russianFallback
    }
}

struct CoachFinalStoryAction: Hashable {
    let title: CoachFinalStoryText
    let icon: String
}

struct CoachFinalStorySupportSignal: Hashable {
    enum Kind: String, Hashable {
        case hydration
        case fuel
        case recovery
        case sleep
        case activity
    }

    let kind: Kind
    let title: CoachFinalStoryText
    let icon: String
}

struct CoachFinalStoryUpNextContext: Hashable {
    let activityID: String?
    let title: String?
}

enum CoachFinalDecisionTimeOfDay: String, Hashable {
    case night
    case morning
    case midday
    case afternoon
    case evening
    case lateEvening
}

struct CoachFinalDecisionContext {
    let selectedCoachActivity: PlannedActivity?
    let selectedUpNext: PlannedActivity?
    let hasFutureActivityContext: Bool
    let hasTomorrowDemand: Bool
    let completedLoadMinutes: Int
    let completedTrainingStress: Int
    let timeOfDay: CoachFinalDecisionTimeOfDay

    var hasActivityContext: Bool {
        selectedCoachActivity != nil || selectedUpNext != nil
    }
}

struct CoachFinalStoryReason: Hashable {
    enum Kind: String, Hashable {
        case recovery
        case time
        case training
        case sleep
        case constraint
        case tomorrow
        case hydration
        case fuel
        case stability
    }

    let kind: Kind
    let text: CoachFinalStoryText
    let icon: String
    let colorFamily: CoachFinalStoryColorFamily
}

struct CoachFinalStory {
    let owner: CoachFinalStoryOwner
    let primaryFocus: CoachDayFocus
    let titleKey: String
    let subtitleKey: String
    let badgeState: CoachFinalStoryText
    let heroState: CoachFinalStoryText
    let colorFamily: CoachFinalStoryColorFamily
    let icon: String
    let primaryRecommendationKey: String
    let avoidRecommendationKey: String
    let title: CoachFinalStoryText
    let subtitle: CoachFinalStoryText
    let primaryRecommendation: CoachFinalStoryText
    let avoidRecommendation: CoachFinalStoryText
    let whatHappened: CoachFinalStoryText
    let whatMattersNow: CoachFinalStoryText
    let whatToDoNext: CoachFinalStoryText
    let whatToAvoid: CoachFinalStoryText
    let reasons: [CoachFinalStoryReason]
    let supportSignals: [CoachFinalStorySupportSignal]
    let upNextContext: CoachFinalStoryUpNextContext?
    let confidence: Double
    let dataReadinessState: CoachFinalStoryDataReadinessState
    let primaryAction: CoachFinalStoryAction
    let supportActions: [CoachSupportActionV3]
    let decisionContext: CoachFinalDecisionContext

    var color: Color { colorFamily.color }

    func validateVisibleContract(file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        if owner == .hydration {
            assert(colorFamily == .hydration || colorFamily == .warning, "Hydration story must use hydration or warning color.", file: file, line: line)
        }
        if owner == .fuel {
            assert(colorFamily == .fuel || colorFamily == .warning, "Fuel story must use fuel or warning color.", file: file, line: line)
        }
        if owner == .recovery || owner == .postActivityRecovery {
            assert(colorFamily == .recovery || colorFamily == .warning, "Recovery story must use recovery or warning color.", file: file, line: line)
        }
        if owner == .activeActivity || owner == .pacingExecution || owner == .sustainableExecution {
            assert(
                colorFamily == .live || colorFamily == .activity || colorFamily == .warning || colorFamily == .stress || colorFamily == .recovery,
                "Active activity story must use a semantic active-session color.",
                file: file,
                line: line
            )
        }
        if owner == .fuelingDuringActivity {
            assert(colorFamily == .fuel || colorFamily == .warning, "Fueling execution story must use fuel or warning color.", file: file, line: line)
        }
        if owner == .hydrationExecution {
            assert(colorFamily == .hydration || colorFamily == .warning, "Hydration execution story must use hydration or warning color.", file: file, line: line)
        }
        #endif
    }
}

struct CoachTodayPresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
}

struct CoachScreenPresentation {
    let stateLabel: String
    let title: String
    let message: String
    let recommendation: String
    let icon: String
    let color: Color
    let supportActions: [CoachSupportActionV3]
    let avoidNotes: [String]
}

struct CoachRationalePresentation {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let sourceActivityID: String
}

enum CoachStateStatus: Equatable {
    case ready
    case refreshingPrevious
    case unavailable(reason: String)
    case invalid(reason: String)
}

struct CoachState: Identifiable {
    let id: UUID
    let createdAt: Date
    let status: CoachStateStatus
    let input: CoachInputSnapshot?
    let fingerprint: CoachInputFingerprint?
    let guidance: CoachGuidanceV3?
    let finalStory: CoachFinalStory?
    let todayPresentation: CoachTodayPresentation
    let coachPresentation: CoachScreenPresentation?
    let rationalePresentation: CoachRationalePresentation?

    var hasValidGuidance: Bool {
        guidance != nil && coachPresentation != nil && finalStory != nil
    }

    static func unavailable(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            guidance: nil,
            finalStory: nil,
            todayPresentation: CoachTodayPresentation(
                title: WeekFitLocalizedString("coach.unavailable.title"),
                message: WeekFitLocalizedString("coach.unavailable.message"),
                icon: "sparkles",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil
        )
    }

    static func settling(reason: String, createdAt: Date = Date()) -> CoachState {
        CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .unavailable(reason: reason),
            input: nil,
            fingerprint: nil,
            guidance: nil,
            finalStory: nil,
            todayPresentation: CoachTodayPresentation(
                title: CoachState.localized(english: "Coach is settling", russian: "Коуч обновляется"),
                message: CoachState.localized(english: "Waiting for recovery, sleep, and activity data.", russian: "Ждем данные восстановления, сна и активности."),
                icon: "hourglass",
                color: WeekFitTheme.secondaryText
            ),
            coachPresentation: nil,
            rationalePresentation: nil
        )
    }

    static func ready(
        input: CoachInputSnapshot,
        fingerprint: CoachInputFingerprint,
        guidance: CoachGuidanceV3,
        createdAt: Date = Date(),
        reason: String = "unspecified"
    ) -> CoachState {
        let readiness = CoachFinalStoryBuilder.readinessAssessment(input)
        guard readiness.allowed else {
            CoachLogger.trace(
                "[CoachFinalStoryReadiness]",
                [
                    "outcome=blockedDirectReady",
                    readiness.summary,
                    "rawRecovery=\(input.recoveryContext.recoveryPercent)",
                    "sleepHours=\(String(format: "%.2f", input.recoveryContext.sleepHours))",
                    "brainSleep=\(input.brain.sleep)",
                    "brainReadiness=\(input.brain.readiness)",
                    "source=\(input.source)"
                ].joined(separator: " ")
            )
            return .settling(reason: "Coach inputs are still syncing.", createdAt: createdAt)
        }

        let dayNarrative = CoachDayNarrativePresentation.resolve(
            input: input,
            guidance: guidance
        )
        let frame = guidance.dayDecisionFrame
        let frameOwnsNarrative = frame?.shouldOwnNarrative == true
        let frameStory = frameOwnsNarrative ? guidance.screenStory : nil
        let stateLabel = frameOwnsNarrative ? frame?.stateLabel ?? guidance.stateLabel : dayNarrative?.stateLabel ?? guidance.screenStory?.stateLabel ?? guidance.stateLabel
        let title = frameOwnsNarrative ? frameStory?.title ?? frame?.title ?? guidance.title : dayNarrative?.title ?? validTitle(guidance.title) ?? guidance.screenStory?.title ?? guidance.priority.detailTitle
        let message = frameOwnsNarrative ? frameStory?.myRead ?? frame?.diagnosisText ?? guidance.message : dayNarrative?.message ?? guidance.screenStory?.myRead ?? guidance.message
        let icon = dayNarrative?.icon ?? guidance.screenStory?.icon ?? guidance.icon
        let color = dayNarrative?.color ?? guidance.screenStory?.color ?? guidance.color
        let recommendation = frameOwnsNarrative ? frameStory?.myRecommendation ?? guidance.insightSubtitle ?? WeekFitLocalizedString("coach.fallback.keepNextStepSimple") : guidance.screenStory?.myRecommendation ?? guidance.insightSubtitle ?? WeekFitLocalizedString("coach.fallback.keepNextStepSimple")
        let display = CoachPresentationCopy.normalize(
            stateLabel: stateLabel,
            title: title,
            message: message,
            recommendation: recommendation,
            icon: icon,
            color: color,
            input: input,
            guidance: guidance
        )
        logV4AuditDecision(input: input, guidance: guidance)
        logV4AuditBuilderInput(input: input, guidance: guidance)
        let builtFinalStory = CoachFinalStoryBuilder.build(
            input: input,
            guidance: guidance,
            display: display
        )
        logV4AuditStateBeforeEmit(story: builtFinalStory, guidance: guidance)
        let finalStory = applyV4VisibleStoryContractGuard(
            story: builtFinalStory,
            input: input,
            guidance: guidance,
            reason: reason
        )
        logV4AuditStateAfterGuard(before: builtFinalStory, after: finalStory, input: input, guidance: guidance)
        finalStory.validateVisibleContract()

        return CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .ready,
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            finalStory: finalStory,
            todayPresentation: CoachTodayPresentation(
                title: finalStory.title.resolved,
                message: finalStory.subtitle.resolved,
                icon: finalStory.icon,
                color: finalStory.color
            ),
            coachPresentation: CoachScreenPresentation(
                stateLabel: finalStory.badgeState.resolved,
                title: finalStory.title.resolved,
                message: finalStory.subtitle.resolved,
                recommendation: finalStory.primaryRecommendation.resolved,
                icon: finalStory.icon,
                color: finalStory.color,
                supportActions: finalStory.supportActions,
                avoidNotes: [finalStory.avoidRecommendation.resolved]
            ),
            rationalePresentation: CoachRationalePresentation.resolve(from: input)
        )
    }

    func preservingPreviousDuringRefresh(createdAt: Date = Date()) -> CoachState {
        guard hasValidGuidance else { return self }

        return CoachState(
            id: id,
            createdAt: createdAt,
            status: .refreshingPrevious,
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            finalStory: finalStory,
            todayPresentation: todayPresentation,
            coachPresentation: coachPresentation,
            rationalePresentation: rationalePresentation
        )
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func applyV4VisibleStoryContractGuard(
        story: CoachFinalStory,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        reason: String
    ) -> CoachFinalStory {
        // V4 audit note:
        // The literal "Recovery matters most now" is produced inside CoachFinalStoryBuilder's
        // V4 hero text only after a story owner has already become .recovery. Reason rows and
        // render-model fallback copy must remain support/display concerns; they do not own the
        // final story. This final guard exists at the last CoachState boundary so legacy fallback,
        // duplicate filtering, and render defaults cannot turn a stable completed recovery-tier
        // activity into the visible recovery story.
        let recoveryActivity = v4FinalGuardRecoveryTierActivity(input: input, guidance: guidance)
        let isPriorityStableDailyOverview = guidance.priority.priority == .stable && guidance.priority.focus == .dailyOverview
        let isPhaseStable = v4FinalGuardPhaseIsStable(guidance)
        let isRecoveryTierActivity = recoveryActivity != nil
        let activityState = v4FinalGuardActivityState(recoveryActivity, now: input.now)
        let isCompletedRecoveryTierActivity = activityState == "completed"
        let hasIndependentRecoveryDeficit = v4FinalGuardHasIndependentRecoveryDeficit(input: input, guidance: guidance)
        let hasSignificantWorkoutActive = v4FinalGuardHasSignificantWorkoutActive(input: input, guidance: guidance)
        let hasSignificantWorkoutUpcomingToday = v4FinalGuardHasSignificantWorkoutUpcomingToday(input: input, guidance: guidance)
        let hasRecentlyCompletedSignificantWorkout = v4FinalGuardHasRecentlyCompletedSignificantWorkout(input: input)
        let hasSignificantWorkoutTomorrow = v4FinalGuardHasSignificantWorkoutTomorrow(input: input)
        let storyLooksRecovery = story.owner == .recovery ||
            story.owner == .postActivityRecovery ||
            story.title.resolved.localizedCaseInsensitiveContains("Recovery matters most now") ||
            story.title.resolved.localizedCaseInsensitiveContains("recovery")
        let shouldApply = isPriorityStableDailyOverview &&
            isPhaseStable &&
            isRecoveryTierActivity &&
            isCompletedRecoveryTierActivity &&
            !hasIndependentRecoveryDeficit &&
            !hasSignificantWorkoutActive &&
            !hasSignificantWorkoutUpcomingToday &&
            !hasRecentlyCompletedSignificantWorkout &&
            !hasSignificantWorkoutTomorrow &&
            storyLooksRecovery
        let failedConditions = v4FinalGuardFailedConditions(
            isPriorityStableDailyOverview: isPriorityStableDailyOverview,
            isPhaseStable: isPhaseStable,
            isRecoveryTierActivity: isRecoveryTierActivity,
            isCompletedRecoveryTierActivity: isCompletedRecoveryTierActivity,
            hasIndependentRecoveryDeficit: hasIndependentRecoveryDeficit,
            hasSignificantWorkoutActive: hasSignificantWorkoutActive,
            hasSignificantWorkoutUpcomingToday: hasSignificantWorkoutUpcomingToday,
            hasRecentlyCompletedSignificantWorkout: hasRecentlyCompletedSignificantWorkout,
            hasSignificantWorkoutTomorrow: hasSignificantWorkoutTomorrow,
            storyLooksRecovery: storyLooksRecovery
        )

        logV4FinalGuardEvaluated(
            reason: reason,
            input: input,
            guidance: guidance,
            activity: recoveryActivity,
            activityState: activityState,
            ownerBefore: story.owner,
            titleBefore: story.title.resolved,
            isRecoveryTierActivity: isRecoveryTierActivity,
            hasIndependentRecoveryDeficit: hasIndependentRecoveryDeficit,
            hasSignificantWorkoutActive: hasSignificantWorkoutActive,
            hasSignificantWorkoutUpcomingToday: hasSignificantWorkoutUpcomingToday,
            hasRecentlyCompletedSignificantWorkout: hasRecentlyCompletedSignificantWorkout,
            hasSignificantWorkoutTomorrow: hasSignificantWorkoutTomorrow,
            shouldApply: shouldApply,
            failedConditions: failedConditions
        )

        guard shouldApply, let recoveryActivity else {
            return story
        }

        let title = v4FinalGuardText(
            "You already added some easy movement",
            russian: "Немного движения сегодня уже есть"
        )
        let subtitle = v4FinalGuardText(
            "Today looks steady. Nothing needs special attention now.",
            russian: "День идёт ровно. Ничего срочного сейчас нет."
        )
        let whatHappened = v4FinalGuardText(
            "\(recoveryActivity.title) is logged as easy movement, not a training load.",
            russian: "\(recoveryActivity.title) засчитана как лёгкое движение, а не тренировка."
        )
        let whatMattersNow = v4FinalGuardText(
            "No workout or recovery problem needs to own the day.",
            russian: "Сейчас нет тренировки или проблемы восстановления, которая должна управлять днём."
        )
        let whatToDoNext = v4FinalGuardText(
            "Leave the plan unchanged today.",
            russian: "Оставьте план без изменений сегодня."
        )
        let whatToAvoid = v4FinalGuardText(
            "Do not add intensity just to make the day feel productive.",
            russian: "Не добавляйте интенсивность только ради ощущения продуктивности."
        )
        let guardedStory = CoachFinalStory(
            owner: .stableOverview,
            primaryFocus: .dailyOverview,
            titleKey: story.titleKey,
            subtitleKey: story.subtitleKey,
            badgeState: v4FinalGuardText("STEADY", russian: "РОВНО"),
            heroState: v4FinalGuardText("Open day", russian: "Спокойный день"),
            colorFamily: .stable,
            icon: "checkmark.seal.fill",
            primaryRecommendationKey: story.primaryRecommendationKey,
            avoidRecommendationKey: story.avoidRecommendationKey,
            title: title,
            subtitle: subtitle,
            primaryRecommendation: whatToDoNext,
            avoidRecommendation: whatToAvoid,
            whatHappened: whatHappened,
            whatMattersNow: whatMattersNow,
            whatToDoNext: whatToDoNext,
            whatToAvoid: whatToAvoid,
            reasons: [
                CoachFinalStoryReason(
                    kind: .stability,
                    text: v4FinalGuardText(
                        "Priority is stable and no significant workout is active or upcoming.",
                        russian: "Приоритет ровный, значимой тренировки сейчас или позже сегодня нет."
                    ),
                    icon: "checkmark.seal.fill",
                    colorFamily: .stable
                )
            ],
            supportSignals: story.supportSignals.filter { $0.kind != .recovery },
            upNextContext: nil,
            confidence: story.confidence,
            dataReadinessState: story.dataReadinessState,
            primaryAction: CoachFinalStoryAction(
                title: whatToDoNext,
                icon: "checkmark.circle.fill"
            ),
            supportActions: [],
            decisionContext: story.decisionContext
        )

        logV4FinalGuard(
            applied: true,
            reason: "recoveryActivityCompletedStableDay",
            activity: recoveryActivity,
            ownerBefore: story.owner,
            titleBefore: story.title.resolved,
            ownerAfter: guardedStory.owner,
            titleAfter: guardedStory.title.resolved,
            guidance: guidance
        )
        return guardedStory
    }

    private static func v4FinalGuardText(_ english: String, russian: String) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: "",
            fallback: english,
            russianFallback: russian,
            parameters: [],
            russianParameters: []
        )
    }

    private static func v4FinalGuardPhaseIsStable(_ guidance: CoachGuidanceV3) -> Bool {
        if case .stable = guidance.phase {
            return true
        }
        return false
    }

    private static func v4FinalGuardCompletedRecoveryActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        v4FinalGuardRecoveryTierActivity(input: input, guidance: guidance).flatMap { activity in
            v4FinalGuardActivityState(activity, now: input.now) == "completed" ? activity : nil
        }
    }

    private static func v4FinalGuardRecoveryTierActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        var candidates: [PlannedActivity] = []
        if let activity = guidance.priority.activity {
            candidates.append(activity)
        }
        switch guidance.phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            candidates.append(activity)
        case .stable:
            break
        }
        if let activity = input.dayContext.lastCompletedActivity {
            candidates.append(activity)
        }
        candidates.append(contentsOf: input.dayContext.completedActivities)
        candidates.append(contentsOf: input.plannedActivities)

        return candidates
            .filter(v4FinalGuardIsRecoveryTierOnly)
            .first
    }

    private static func v4FinalGuardHasSignificantWorkoutContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if guidance.priority.activity.map(v4FinalGuardIsSignificantWorkout) == true {
            return true
        }
        switch guidance.phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            if v4FinalGuardIsSignificantWorkout(activity) {
                return true
            }
        case .stable:
            break
        }

        let calendar = Calendar.current
        let todayActivities = input.plannedActivities.filter { calendar.isDate($0.date, inSameDayAs: input.now) }
        let activeOrUpcomingToday = todayActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped, v4FinalGuardIsSignificantWorkout(activity) else {
                return false
            }
            let end = calendar.date(
                byAdding: .minute,
                value: max(activity.durationMinutes, 1),
                to: activity.date
            ) ?? activity.date
            return end >= input.now
        }
        if activeOrUpcomingToday {
            return true
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.now) ?? input.now
        let hasSignificantTomorrow = input.plannedActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                calendar.isDate(activity.date, inSameDayAs: tomorrow) &&
                v4FinalGuardIsSignificantWorkout(activity)
        }
        if hasSignificantTomorrow {
            return true
        }

        if input.dayContext.completedActivities.contains(where: v4FinalGuardIsSignificantWorkout) {
            return true
        }
        if input.dayContext.lastCompletedActivity.map(v4FinalGuardIsSignificantWorkout) == true {
            return true
        }

        if input.dayContext.completedTrainingStressScore >= 2 {
            if let lastCompleted = input.dayContext.lastCompletedActivity {
                return !v4FinalGuardIsRecoveryTierOnly(lastCompleted)
            }
            return true
        }

        return false
    }

    private static func v4FinalGuardHasSignificantWorkoutActive(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        switch guidance.phase {
        case .active(let activity, _):
            if v4FinalGuardIsSignificantWorkout(activity) { return true }
        case .preparing, .recovering, .stable:
            break
        }

        return input.plannedActivities.contains { activity in
            activity.isActive(at: input.now) && v4FinalGuardIsSignificantWorkout(activity)
        }
    }

    private static func v4FinalGuardHasSignificantWorkoutUpcomingToday(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        switch guidance.phase {
        case .preparing(let activity, _, _):
            if v4FinalGuardIsSignificantWorkout(activity) { return true }
        case .active, .recovering, .stable:
            break
        }

        let calendar = Calendar.current
        return input.plannedActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                activity.date >= input.now &&
                calendar.isDate(activity.date, inSameDayAs: input.now) &&
                v4FinalGuardIsSignificantWorkout(activity)
        }
    }

    private static func v4FinalGuardHasRecentlyCompletedSignificantWorkout(
        input: CoachInputSnapshot
    ) -> Bool {
        if input.dayContext.lastCompletedActivity.map(v4FinalGuardIsSignificantWorkout) == true {
            return true
        }
        if input.dayContext.completedActivities.contains(where: v4FinalGuardIsSignificantWorkout) {
            return true
        }
        if input.dayContext.completedTrainingStressScore >= 2 {
            if let lastCompleted = input.dayContext.lastCompletedActivity {
                return !v4FinalGuardIsRecoveryTierOnly(lastCompleted)
            }
            return true
        }
        return false
    }

    private static func v4FinalGuardHasSignificantWorkoutTomorrow(
        input: CoachInputSnapshot
    ) -> Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.now) ?? input.now
        return input.plannedActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                calendar.isDate(activity.date, inSameDayAs: tomorrow) &&
                v4FinalGuardIsSignificantWorkout(activity)
        }
    }

    private static func v4FinalGuardActivityState(_ activity: PlannedActivity?, now: Date) -> String {
        guard let activity else { return "none" }
        return activity.terminalState(now: now).rawValue
    }

    private static func v4FinalGuardFailedConditions(
        isPriorityStableDailyOverview: Bool,
        isPhaseStable: Bool,
        isRecoveryTierActivity: Bool,
        isCompletedRecoveryTierActivity: Bool,
        hasIndependentRecoveryDeficit: Bool,
        hasSignificantWorkoutActive: Bool,
        hasSignificantWorkoutUpcomingToday: Bool,
        hasRecentlyCompletedSignificantWorkout: Bool,
        hasSignificantWorkoutTomorrow: Bool,
        storyLooksRecovery: Bool
    ) -> [String] {
        var failed: [String] = []
        if !isPriorityStableDailyOverview { failed.append("priority") }
        if !isPhaseStable { failed.append("phase") }
        if !isRecoveryTierActivity { failed.append("recoveryTierActivity") }
        if !isCompletedRecoveryTierActivity { failed.append("activityState") }
        if hasIndependentRecoveryDeficit { failed.append("independentRecoveryDeficit") }
        if hasSignificantWorkoutActive { failed.append("significantWorkoutActive") }
        if hasSignificantWorkoutUpcomingToday { failed.append("significantWorkoutUpcomingToday") }
        if hasRecentlyCompletedSignificantWorkout { failed.append("recentSignificantWorkout") }
        if hasSignificantWorkoutTomorrow { failed.append("significantWorkoutTomorrow") }
        if !storyLooksRecovery { failed.append("storyNotRecovery") }
        return failed
    }

    private static func v4FinalGuardHasIndependentRecoveryDeficit(
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
            guidance.priority.limiter == .accumulatedFatigue {
            return true
        }
        if guidance.priority.limiter == .recovery,
           guidance.priority.activity.map(v4FinalGuardIsRecoveryTierOnly) != true {
            return true
        }
        if input.dayContext.completedActivities.contains(where: v4FinalGuardIsSignificantWorkout) {
            return true
        }
        if input.dayContext.completedTrainingStressScore >= 2,
           input.dayContext.lastCompletedActivity.map(v4FinalGuardIsRecoveryTierOnly) != true {
            return true
        }
        return false
    }

    private static func v4FinalGuardIsRecoveryTierOnly(_ activity: PlannedActivity) -> Bool {
        let tokens = [
            activity.type,
            activity.title,
            activity.icon,
            activity.imageName
        ]
        .joined(separator: " ")
        .lowercased()

        return tokens.contains("walk") ||
            tokens.contains("walking") ||
            tokens.contains("stretch") ||
            tokens.contains("yoga") ||
            tokens.contains("breath")
    }

    private static func v4FinalGuardIsSignificantWorkout(_ activity: PlannedActivity) -> Bool {
        guard !v4FinalGuardIsRecoveryTierOnly(activity) else { return false }
        let tokens = [
            activity.type,
            activity.title,
            activity.icon,
            activity.imageName
        ]
        .joined(separator: " ")
        .lowercased()

        return tokens.contains("cycling") ||
            tokens.contains("bicycle") ||
            tokens.contains("running") ||
            tokens.contains("run") ||
            tokens.contains("tennis") ||
            tokens.contains("squash") ||
            tokens.contains("upper body") ||
            tokens.contains("lower body") ||
            tokens.contains("full body") ||
            tokens.contains("core") ||
            tokens.contains("strength") ||
            tokens.contains("workout")
    }

    private static func logV4FinalGuardEvaluated(
        reason: String,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        activity: PlannedActivity?,
        activityState: String,
        ownerBefore: CoachFinalStoryOwner,
        titleBefore: String,
        isRecoveryTierActivity: Bool,
        hasIndependentRecoveryDeficit: Bool,
        hasSignificantWorkoutActive: Bool,
        hasSignificantWorkoutUpcomingToday: Bool,
        hasRecentlyCompletedSignificantWorkout: Bool,
        hasSignificantWorkoutTomorrow: Bool,
        shouldApply: Bool,
        failedConditions: [String]
    ) {
        #if DEBUG
        CoachLogger.trace(
            "[CoachV4FinalGuard]",
            [
                "evaluated=true",
                "reason=\(reason)",
                "priority=\(guidance.priority.priority)/\(guidance.priority.focus)",
                "phase=\(v4AuditPhase(guidance))",
                "activity=\(activity?.title ?? "nil")",
                "activityState=\(activityState)",
                "ownerBefore=\(ownerBefore.rawValue)",
                "titleBefore=\"\(titleBefore)\"",
                "isRecoveryTierActivity=\(isRecoveryTierActivity)",
                "hasIndependentRecoveryDeficit=\(hasIndependentRecoveryDeficit)",
                "hasSignificantWorkoutActive=\(hasSignificantWorkoutActive)",
                "hasSignificantWorkoutUpcomingToday=\(hasSignificantWorkoutUpcomingToday)",
                "hasRecentlyCompletedSignificantWorkout=\(hasRecentlyCompletedSignificantWorkout)",
                "hasSignificantWorkoutTomorrow=\(hasSignificantWorkoutTomorrow)",
                "shouldApply=\(shouldApply)",
                "failedConditions=\(failedConditions.isEmpty ? "none" : failedConditions.joined(separator: ","))",
                "activeCalories=\(Int(input.actualLoad.activeCalories))",
                "recoveryPercent=\(input.recoveryContext.recoveryPercent)",
                "sleepHours=\(String(format: "%.1f", input.recoveryContext.sleepHours))"
            ].joined(separator: " ")
        )
        #endif
    }

    private static func logV4FinalGuard(
        applied: Bool,
        reason: String,
        activity: PlannedActivity,
        ownerBefore: CoachFinalStoryOwner,
        titleBefore: String,
        ownerAfter: CoachFinalStoryOwner,
        titleAfter: String,
        guidance: CoachGuidanceV3
    ) {
        #if DEBUG
        CoachLogger.trace(
            "[CoachV4FinalGuard]",
            [
                "applied=\(applied)",
                "reason=\(reason)",
                "activity=\(activity.title)",
                "activityState=\(activity.isCompleted ? "completed" : "notCompleted")",
                "phase=\(guidance.phase)",
                "priority=\(guidance.priority.priority)/\(guidance.priority.focus)",
                "ownerBefore=\(ownerBefore.rawValue)",
                "titleBefore=\"\(titleBefore)\"",
                "ownerAfter=\(ownerAfter.rawValue)",
                "titleAfter=\"\(titleAfter)\""
            ].joined(separator: " ")
        )
        #endif
    }

    private static func logV4AuditDecision(input: CoachInputSnapshot, guidance: CoachGuidanceV3) {
        #if DEBUG
        let activity = v4AuditActivity(input: input, guidance: guidance)
        CoachLogger.trace(
            "[CoachV4Audit.Decision]",
            "priority=\(guidance.priority.priority)/\(guidance.priority.focus) phase=\(v4AuditPhase(guidance)) activity=\(activity?.title ?? "nil") activityState=\(v4AuditActivityState(activity, now: input.now)) ownerCandidate=\(guidance.priority.focus)"
        )
        #endif
    }

    private static func logV4AuditBuilderInput(input: CoachInputSnapshot, guidance: CoachGuidanceV3) {
        #if DEBUG
        let activity = v4AuditActivity(input: input, guidance: guidance)
        CoachLogger.trace(
            "[CoachV4Audit.Builder.In]",
            "priority=\(guidance.priority.priority)/\(guidance.priority.focus) phase=\(v4AuditPhase(guidance)) activity=\(activity?.title ?? "nil") activityState=\(v4AuditActivityState(activity, now: input.now))"
        )
        #endif
    }

    private static func logV4AuditStateBeforeEmit(story: CoachFinalStory, guidance: CoachGuidanceV3) {
        #if DEBUG
        CoachLogger.trace(
            "[CoachV4Audit.State.BeforeEmit]",
            "owner=\(story.owner.rawValue) title=\"\(story.title.resolved)\" priority=\(guidance.priority.priority)/\(guidance.priority.focus)"
        )
        #endif
    }

    private static func logV4AuditStateAfterGuard(
        before: CoachFinalStory,
        after: CoachFinalStory,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) {
        #if DEBUG
        let applied = before.owner != after.owner || before.title.resolved != after.title.resolved
        let reason = applied && v4FinalGuardCompletedRecoveryActivity(input: input, guidance: guidance) != nil
            ? "recoveryActivityCompletedStableDay"
            : "none"
        CoachLogger.trace(
            "[CoachV4Audit.State.AfterGuard]",
            "applied=\(applied) ownerBefore=\(before.owner.rawValue) titleBefore=\"\(before.title.resolved)\" ownerAfter=\(after.owner.rawValue) titleAfter=\"\(after.title.resolved)\" reason=\(reason)"
        )
        #endif
    }

    private static func v4AuditActivity(input: CoachInputSnapshot, guidance: CoachGuidanceV3) -> PlannedActivity? {
        if let activity = guidance.priority.activity {
            return activity
        }
        switch guidance.phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            return activity
        case .stable:
            return input.dayContext.lastCompletedActivity ?? input.dayContext.completedActivities.sorted { $0.date > $1.date }.first
        }
    }

    private static func v4AuditPhase(_ guidance: CoachGuidanceV3) -> String {
        if case .stable = guidance.phase {
            return "stable"
        }
        return "\(guidance.phase)"
    }

    private static func v4AuditActivityState(_ activity: PlannedActivity?, now: Date) -> String {
        guard let activity else { return "none" }
        return activity.terminalState(now: now).rawValue
    }
}

enum CoachFinalStoryBuilder {
    typealias Display = (stateLabel: String, title: String, message: String, recommendation: String, icon: String, color: Color)

    private struct HumanStory {
        let title: CoachFinalStoryText
        let whatHappened: CoachFinalStoryText
        let whatMattersNow: CoachFinalStoryText
        let whatToDoNext: CoachFinalStoryText
        let whatToAvoid: CoachFinalStoryText
    }

    private enum ActiveSessionAssessment {
        case normalActive
        case activeWithCaution
        case activeAfterOverload
        case activeRecoveryOnly
        case activeSleepRisk
    }

    private enum FinalCopyTheme: String, CaseIterable, Hashable {
        case hydration
        case fuel
        case protein
        case recovery
        case sleep
        case completedLoad
        case upcomingActivity
        case tomorrowDemand
        case flexibility
        case intensityControl
        case saunaHeat
        case cooldown
        case mobility
    }

    private enum CoachActionPool {
        case beforeHardWorkout
        case duringEnduranceSession
        case afterStrengthWorkout
        case afterLongEndurance
        case recoveryDay
        case lowRecoveryPoorReadiness
        case tomorrowBigWorkout
        case optionalRecoveryTools
    }

    private struct CoachActionRecommendation: Hashable {
        let type: CoachSupportActionTypeV3
        let englishTitle: String
        let englishSubtitle: String
        let russianTitle: String
        let russianSubtitle: String
    }

    private enum CoachV4TrainPermission: Hashable {
        case train
        case trainControlled
        case recoveryOnly
        case noTraining
        case noActionNeeded
    }

    private enum CoachV4RecommendedIntensity: Hashable {
        case none
        case easy
        case conversational
        case reduced
        case planned
    }

    private enum CoachV4ActivityClass: Hashable {
        case none
        case recovery
        case training
        case seriousTraining
        case heat
        case nutrition
    }

    private enum CoachV4SeriousTrainingState: Hashable {
        case none
        case upcoming
        case active
        case completed
        case tomorrow
    }

    private enum CoachV4ActivityFamily: Hashable {
        case breathing
        case stretching
        case yoga
        case mobility
        case walk
        case sauna
        case endurance
        case strength
        case racket
        case other
    }

    private enum CoachV4SessionPhase: Hashable {
        case pre
        case during
        case post
        case none
    }

    private enum CoachV4DurationBand: Hashable {
        case shortUnder60
        case medium60To120
        case longOver120
        case none
    }

    private enum CoachV4TimeToSessionWindow: Hashable {
        case fourPlusHours
        case twoToFourHours
        case sixtyTo120Minutes
        case fifteenTo60Minutes
        case under15Minutes
        case none
    }

    private struct CoachV4DayLoadContext {
        let timePhase: CoachFinalDecisionTimeOfDay
        let caloriesBurnedSoFar: Double
        let completedSeriousTrainingToday: Bool
        let completedRecoveryVolumeToday: Int
        let nextImportantActivityToday: PlannedActivity?
        let hoursUntilNextImportantActivity: Double?
        let timeToNextImportantSession: CoachV4TimeToSessionWindow
        let tomorrowDemand: CoachTomorrowDemand
        let shouldProtectUpcomingSession: Bool
        let shouldProtectTomorrow: Bool
    }

    private struct CoachV4DecisionFrame {
        let storyOwner: CoachFinalStoryOwner
        let trainPermission: CoachV4TrainPermission
        let recommendedIntensity: CoachV4RecommendedIntensity
        let objective: CoachObjective
        let primaryLimiter: CoachLimiter
        let activityClass: CoachV4ActivityClass
        let activityFamily: CoachV4ActivityFamily
        let sessionPhase: CoachV4SessionPhase
        let durationBand: CoachV4DurationBand
        let seriousTrainingState: CoachV4SeriousTrainingState
        let dayLoadContext: CoachV4DayLoadContext
        let timePhase: CoachFinalDecisionTimeOfDay
        let hero: CoachFinalStoryText
        let assessment: CoachFinalStoryText
        let situation: CoachFinalStoryText
        let primaryAction: CoachActionRecommendation
        let avoidance: CoachFinalStoryText
        let actions: [CoachActionRecommendation]
        let reasons: [CoachV4Reason]
    }

    private struct CoachV4PlaybookOutput {
        let hero: CoachFinalStoryText
        let assessment: CoachFinalStoryText
        let situation: CoachFinalStoryText
        let primaryAction: CoachActionRecommendation
        let avoidance: CoachFinalStoryText
        let actions: [CoachActionRecommendation]
        let reasons: [CoachV4Reason]
    }

    private struct CoachV4Reason: Hashable {
        let kind: CoachFinalStoryReason.Kind
        let english: String
        let russian: String
        let icon: String
        let colorFamily: CoachFinalStoryColorFamily
    }

    private struct CoachActionLibrary {
        static func recommendations(for pool: CoachActionPool) -> [CoachActionRecommendation] {
            switch pool {
            case .beforeHardWorkout:
                return [
                    action(.hydrateBeforeSession, "Drink another 300-500 ml", "Over the next hour", "Выпейте ещё 300-500 мл воды", "В течение ближайшего часа"),
                    action(.lightFueling, "Finish the main meal with carbs", "2-3 hours before the workout", "Завершите основной приём пищи с углеводами", "За 2-3 часа до старта"),
                    action(.controlIntensity, "Avoid extra activity", "Keep the time before the session quiet", "Не добавляйте лишнюю активность", "До тренировки"),
                    action(.controlIntensity, "Start with 10 minutes easy", "Let the warm-up set the first rhythm", "Начните с 10 минут лёгкого усилия", "Пусть разминка задаст первый ритм"),
                    action(.hydrateBeforeSession, "Prepare hydration and nutrition", "Set it up before you leave", "Подготовьте воду и питание", "Заранее, до выхода"),
                    action(.lightRecoveryMovement, "Keep your legs fresh", "Save them for the main work ahead", "Сохраните ноги свежими", "Для основной работы")
                ]
            case .duringEnduranceSession:
                return [
                    action(.controlIntensity, "Hold the next 10 minutes controlled", "Skip surges while breathing and legs settle", "Следующие 10 минут держите под контролем", "Без рывков, пока дыхание и ноги стабилизируются"),
                    action(.controlIntensity, "Keep the next block below hard effort", "Save intensity for the planned work", "Следующий блок держите ниже тяжёлого усилия", "Сохраните интенсивность для плановой работы"),
                    action(.sustainEnergy, "Fuel before hunger appears", "Check nutrition before the first dip", "Проверьте питание до голода", "До первого провала энергии"),
                    action(.steadyHydration, "Drink in small amounts", "Take regular small sips", "Пейте небольшими порциями", "Регулярно по ходу сессии"),
                    action(.controlIntensity, "Hold a steady rhythm", "Keep the session smooth, not spiky", "Сосредоточьтесь на ровном ритме", "Без резких ускорений")
                ]
            case .afterStrengthWorkout:
                return [
                    action(.recoveryMeal, "Aim for 25-40 g protein", "Within the next hour", "Получите 25-40 г белка", "В ближайший час"),
                    action(.rehydrateGradually, "Drink 300-700 ml fluid", "After the workout", "Выпейте 300-700 мл жидкости", "После тренировки"),
                    action(.cooldown, "Finish 5-10 minutes easy", "Use it as a cooldown", "Сделайте 5-10 минут лёгкой заминки", "В конце тренировки"),
                    action(.controlIntensity, "Avoid another hard workout", "Keep the rest of today lighter", "Не добавляйте ещё одну тяжёлую тренировку", "Сегодня"),
                    action(.recoveryMeal, "Have a complete meal", "Within the next 2 hours", "Закройте полноценный приём пищи", "В течение 2 часов")
                ]
            case .afterLongEndurance:
                return [
                    action(.recoveryMeal, "Eat within 1 hour", "Do not delay the first recovery meal", "Не откладывайте питание больше чем на час", "После длинной работы"),
                    action(.recoveryMeal, "Add carbs and protein", "Put both into the next meal", "Добавьте углеводы и белок", "В ближайший приём пищи"),
                    action(.rehydrateGradually, "Rehydrate through the evening", "Keep fluids moving gradually", "Продолжайте восполнять жидкость", "В течение вечера"),
                    action(.controlIntensity, "Keep the rest of the day calm", "Avoid stacking more load", "Сохраняйте остаток дня спокойным", "Без дополнительной нагрузки"),
                    action(.sleepPriority, "Make sleep part of recovery", "Tonight matters after long work", "Сделайте сон частью восстановления", "Сегодня ночью")
                ]
            case .recoveryDay:
                return [
                    action(.lightRecoveryMovement, "Walk 20-40 minutes easy", "Keep it conversational", "Ограничьтесь лёгкой прогулкой 20-40 минут", "В комфортном темпе"),
                    action(.controlIntensity, "Keep the effort comfortable", "No hard blocks today", "Сохраняйте усилие комфортным", "Без тяжёлых блоков"),
                    action(.mobilityPrep, "Add 5-10 minutes mobility", "Keep the range easy", "Добавьте 5-10 минут мобильности", "Без силовой нагрузки"),
                    action(.controlIntensity, "Do not turn this into training", "Stop before it becomes work", "Не превращайте восстановительный день в тренировку", "Остановитесь до утомления"),
                    action(.controlIntensity, "Finish without extra load", "Keep the day recovery-focused", "Завершите день без дополнительной нагрузки", "Оставьте день восстановительным")
                ]
            case .lowRecoveryPoorReadiness:
                return [
                    action(.controlIntensity, "Reduce intensity by one level", "Use this before the main set", "Снизьте плановую интенсивность на один уровень", "Перед основной частью"),
                    action(.controlIntensity, "Start 10-15 minutes easier", "Then reassess after warm-up", "Начните на 10-15 минут легче обычного", "Затем оцените состояние после разминки"),
                    action(.controlIntensity, "Reassess after warm-up", "Decide from breathing, legs, and control", "Повторно оцените самочувствие после разминки", "По дыханию, ногам и контролю"),
                    action(.controlIntensity, "Prioritize quality over volume", "Stop chasing extra work", "Отдайте приоритет качеству, а не объёму", "Без догонки плана любой ценой"),
                    action(.controlIntensity, "Consider shortening the session", "Cut the least important block first", "Рассмотрите сокращение тренировки", "Сначала уберите наименее важный блок")
                ]
            case .tomorrowBigWorkout:
                return [
                    action(.sleepPriority, "Aim for 7-8 hours sleep", "Make tonight the main recovery block", "Постарайтесь обеспечить 7-8 часов сна", "Сегодня ночью"),
                    action(.controlIntensity, "Avoid another workout today", "Keep the remaining load low", "Не добавляйте ещё одну тренировку", "Сегодня"),
                    action(.sleepPriority, "Finish hard activity early", "Leave several hours before bedtime", "Завершите интенсивную активность заранее", "За несколько часов до сна"),
                    action(.controlIntensity, "Save energy for tomorrow", "Do not spend it tonight", "Сохраните энергию для завтрашней работы", "Не тратьте её сегодня вечером"),
                    action(.downshiftNervousSystem, "Keep the evening calm", "Make the morning easier to start", "Сделайте вечер максимально спокойным", "Чтобы утром было легче начать")
                ]
            case .optionalRecoveryTools:
                return [
                    action(.mobilityPrep, "Stretch 5-10 minutes easy", "Keep it light", "5-10 минут лёгкой растяжки", "Без усилия"),
                    action(.mobilityPrep, "Do 5-10 minutes mobility", "Keep the movement relaxed", "5-10 минут мобильности", "Спокойно, без нагрузки"),
                    action(.downshiftNervousSystem, "Take a cool shower", "Useful after training in heat", "Прохладный душ", "После тренировки в жару"),
                    action(.lightRecoveryMovement, "Walk easy after dinner", "Keep it short and relaxed", "Лёгкая прогулка после ужина", "Коротко и спокойно"),
                    action(.sleepPriority, "Go to bed earlier", "Use it as recovery, not a bonus", "Ранний отход ко сну", "Как часть восстановления")
                ]
            }
        }

        private static func action(
            _ type: CoachSupportActionTypeV3,
            _ englishTitle: String,
            _ englishSubtitle: String,
            _ russianTitle: String,
            _ russianSubtitle: String
        ) -> CoachActionRecommendation {
            CoachActionRecommendation(
                type: type,
                englishTitle: englishTitle,
                englishSubtitle: englishSubtitle,
                russianTitle: russianTitle,
                russianSubtitle: russianSubtitle
            )
        }

        static func noAction(reasonEnglish: String, reasonRussian: String) -> CoachActionRecommendation {
            action(
                .stayConsistent,
                "Do nothing extra",
                reasonEnglish,
                "Ничего дополнительно не делайте",
                reasonRussian
            )
        }
    }

    private struct FinalCopyPlan {
        let humanStory: HumanStory
        let reasons: [CoachFinalStoryReason]
        let supportActions: [CoachSupportActionV3]
    }

    private enum CoachV4ActivityPlaybook {

        static func resolve(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            if frame.storyOwner == .tomorrowProtection || frame.storyOwner == .stableOverview || frame.storyOwner == .readiness {
                return base(frame)
            }
            if frame.activityClass == .heat {
                return sauna(frame)
            }
            if frame.storyOwner == .recovery {
                return base(frame)
            }
            if frame.trainPermission == .noTraining {
                return base(frame)
            }
            if frame.sessionPhase == .during,
               frame.trainPermission == .trainControlled || frame.primaryLimiter == .recovery || frame.primaryLimiter == .accumulatedFatigue {
                return base(frame)
            }

            switch frame.activityFamily {
            case .breathing, .stretching, .yoga, .mobility, .walk:
                return recoveryModality(frame)
            case .sauna:
                return sauna(frame)
            case .endurance:
                return endurance(frame)
            case .strength:
                return strength(frame)
            case .racket:
                return racket(frame)
            case .other:
                return base(frame)
            }
        }

        private static func base(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            CoachV4PlaybookOutput(
                hero: frame.hero,
                assessment: frame.assessment,
                situation: frame.situation,
                primaryAction: frame.primaryAction,
                avoidance: frame.avoidance,
                actions: frame.actions,
                reasons: defaultReasons(frame)
            )
        }

        private static func recoveryModality(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let name = recoveryFamilyName(frame.activityFamily)
            let next = frame.dayLoadContext.nextImportantActivityToday
            let nextName = next.map { CoachFinalStoryBuilder.displayName($0).lowercased() } ?? "next important session"
            let hasNext = next != nil

            let hero: CoachFinalStoryText
            let assessment: CoachFinalStoryText
            let situation: CoachFinalStoryText
            let primary: CoachActionRecommendation
            let avoidance: CoachFinalStoryText

            switch frame.sessionPhase {
            case .pre:
                hero = CoachFinalStoryBuilder.dynamicText("Use \(name.english) as support", russian: "\(name.russian) — как поддержка")
                assessment = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("This can prepare the body, but the important \(nextName) is still ahead.", russian: "Это может подготовить тело, но главная нагрузка ещё впереди.")
                    : CoachFinalStoryBuilder.dynamicText("This is useful recovery work, not a training target.", russian: "Это полезное восстановление, а не тренировочная цель.")
                situation = CoachFinalStoryBuilder.dynamicText("Keep it easy enough to leave the body fresher after it.", russian: "Держите так легко, чтобы после стало свежее.")
                primary = action(.lightRecoveryMovement, "Keep it easy", hasNext ? "Save energy for the session ahead" : "Stop before it becomes work", "Держите легко", hasNext ? "Сохраните силы на следующую сессию" : "Остановитесь до утомления")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not turn this into training.", russian: "Не превращайте это в тренировку.")

            case .during:
                hero = CoachFinalStoryBuilder.dynamicText("Keep \(name.english) relaxed", russian: "Держите \(name.russian) спокойно")
                assessment = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("The important \(nextName) is still ahead, so this \(name.english) should stay easy.", russian: "Главная нагрузка ещё впереди, поэтому \(name.russian) должна остаться лёгкой.")
                    : frame.dayLoadContext.completedSeriousTrainingToday
                    ? CoachFinalStoryBuilder.dynamicText("Today already has training stress, so this should only help recovery.", russian: "Сегодня уже была тренировочная нагрузка, поэтому это должно только помогать восстановлению.")
                    : CoachFinalStoryBuilder.dynamicText("This is low-strain work inside the bigger training day.", russian: "Это лёгкая работа внутри общего тренировочного дня.")
                situation = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("Save energy for the session ahead.", russian: "Сохраните энергию для следующей сессии.")
                    : CoachFinalStoryBuilder.dynamicText("Stay comfortable and finish with more control than you started.", russian: "Оставайтесь в комфорте и завершите с запасом.")
                primary = hasNext
                    ? action(.controlIntensity, "Keep it easy", "Save energy for the session ahead", "Держите легко", "Сохраните силы для следующей сессии")
                    : action(.controlIntensity, "Stay conversational", "Keep effort relaxed the whole time", "Держите разговорное усилие", "Всё время без напряжения")
                avoidance = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("Do not turn this into training.", russian: "Не превращайте это в тренировку.")
                    : CoachFinalStoryBuilder.dynamicText("Do not compete with the recovery work.", russian: "Не соревнуйтесь с восстановительной активностью.")

            case .post:
                hero = CoachFinalStoryBuilder.dynamicText("\(capitalized(name.english)) supported recovery", russian: "\(capitalized(name.russian)) поддержала восстановление")
                assessment = CoachFinalStoryBuilder.dynamicText("This helped recovery without adding meaningful training strain.", russian: "Это помогло восстановлению без значимой тренировочной нагрузки.")
                situation = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("The next important work still matters more than this completed \(name.english).", russian: "Следующая важная нагрузка всё ещё важнее этой активности.")
                    : CoachFinalStoryBuilder.dynamicText("Treat it as support for the day, not as the main work.", russian: "Считайте это поддержкой дня, а не основной работой.")
                primary = action(.stayConsistent, hasNext ? "Save energy for later" : "Do nothing extra", hasNext ? "Keep the rest of the day quiet enough for the next session" : "No recovery alert is needed from this alone", hasNext ? "Сохраните энергию на потом" : "Ничего дополнительно не делайте", hasNext ? "Оставьте день достаточно спокойным для следующей сессии" : "Одна эта активность не требует восстановления")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not count this as the main workout.", russian: "Не считайте это главной тренировкой.")

            case .none:
                hero = CoachFinalStoryBuilder.dynamicText("Use recovery work carefully", russian: "Используйте восстановление аккуратно")
                assessment = CoachFinalStoryBuilder.dynamicText("Recovery work should support the day, not replace the plan.", russian: "Восстановительная активность должна поддерживать день, а не заменять план.")
                situation = CoachFinalStoryBuilder.dynamicText("Let the bigger day context decide how much is useful.", russian: "Общий контекст дня определяет полезный объём.")
                primary = action(.lightRecoveryMovement, "Keep it light", "Use only the amount that leaves you fresher", "Держите легко", "Оставьте только тот объём, после которого свежее")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not add load without a reason.", russian: "Не добавляйте нагрузку без причины.")
            }

            return output(
                frame: frame,
                hero: hero,
                assessment: assessment,
                situation: situation,
                primary: primary,
                avoidance: avoidance,
                extras: recoveryExtras(frame)
            )
        }

        private static func sauna(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let hero: CoachFinalStoryText
            let assessment: CoachFinalStoryText
            let situation: CoachFinalStoryText
            let primary: CoachActionRecommendation
            let avoidance: CoachFinalStoryText

            switch frame.sessionPhase {
            case .pre, .none:
                hero = CoachFinalStoryBuilder.dynamicText("Make sauna easier", russian: "Сделайте сауну легче")
                assessment = CoachFinalStoryBuilder.dynamicText("Sauna adds stress even when it feels relaxing.", russian: "Сауна добавляет стресс, даже если ощущается расслабляющей.")
                situation = frame.dayLoadContext.shouldProtectTomorrow
                    ? CoachFinalStoryBuilder.dynamicText("Tonight should protect tomorrow, so heat exposure should stay conservative.", russian: "Сегодня вечер должен защищать завтра, поэтому тепло лучше держать умеренным.")
                    : CoachFinalStoryBuilder.dynamicText("Hydration decides whether this helps or costs recovery.", russian: "Гидратация определит, поможет это восстановлению или заберёт ресурс.")
                primary = action(.hydrateBeforeSession, "Drink 300-500 ml water", "Over the next hour before sauna", "Выпейте 300-500 мл воды", "В течение часа перед сауной")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not go in dry or try to tolerate fatigue.", russian: "Не заходите обезвоженным и не терпите усталость.")
            case .during:
                hero = CoachFinalStoryBuilder.dynamicText("Keep heat conservative", russian: "Держите тепло умеренным")
                assessment = CoachFinalStoryBuilder.dynamicText("Heat is the load right now, not training.", russian: "Сейчас нагрузка — это тепло, а не тренировка.")
                situation = CoachFinalStoryBuilder.dynamicText("The useful target is leaving before fatigue appears.", russian: "Полезная цель — выйти до появления усталости.")
                primary = action(.controlIntensity, "Exit before fatigue appears", "Keep the exposure controlled", "Выйдите до усталости", "Держите воздействие под контролем")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not stack extra heat stress today.", russian: "Не набирайте лишний тепловой стресс сегодня.")
            case .post:
                hero = CoachFinalStoryBuilder.dynamicText("Recover from heat", russian: "Восстановитесь после тепла")
                assessment = CoachFinalStoryBuilder.dynamicText("Sauna can help relaxation, but fluid loss still has to be replaced.", russian: "Сауна может расслабить, но потерю жидкости всё равно нужно восполнить.")
                situation = CoachFinalStoryBuilder.dynamicText("Rehydration and a calm evening matter more than doing more.", russian: "Вода и спокойный вечер сейчас важнее дополнительных дел.")
                primary = action(.rehydrateGradually, "Drink 300-700 ml gradually", "Keep sipping after heat", "Выпейте 300-700 мл постепенно", "После тепла небольшими глотками")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not add hard work after heat exposure.", russian: "Не добавляйте тяжёлую работу после тепла.")
            }

            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: saunaExtras(frame))
        }

        private static func endurance(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            if frame.sessionPhase == .pre,
               frame.durationBand != .shortUnder60 {
                return preEndurance(frame)
            }

            let hero: CoachFinalStoryText
            let assessment: CoachFinalStoryText
            let situation: CoachFinalStoryText
            let primary: CoachActionRecommendation
            let avoidance: CoachFinalStoryText

            switch (frame.sessionPhase, frame.durationBand) {
            case (.pre, .shortUnder60):
                hero = CoachFinalStoryBuilder.dynamicText("Start controlled", russian: "Начните под контролем")
                assessment = CoachFinalStoryBuilder.dynamicText("This is short enough to execute well if readiness stays stable.", russian: "Это достаточно короткая сессия, если готовность остаётся стабильной.")
                situation = CoachFinalStoryBuilder.dynamicText("Use the warm-up to check legs, breathing, and control.", russian: "Разминку используйте для проверки ног, дыхания и контроля.")
                primary = action(.controlIntensity, "Start 10 minutes easy", "Then decide if planned effort fits", "Начните 10 минут легко", "Потом решите, подходит ли плановое усилие")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not rush the opening minutes.", russian: "Не спешите в первые минуты.")
            case (.pre, .medium60To120), (.pre, .longOver120), (.pre, .none):
                return preEndurance(frame)
            case (.during, _):
                switch frame.storyOwner {
                case .fuelingDuringActivity:
                    return fuelingDuringEndurance(frame)
                case .hydrationExecution:
                    return hydrationDuringEndurance(frame)
                case .pacingExecution:
                    hero = CoachFinalStoryBuilder.dynamicText("Settle into the effort", russian: "Войдите в рабочий ритм")
                    assessment = CoachFinalStoryBuilder.dynamicText("The session has started; the first job is to let breathing, legs, and heart rate settle.", russian: "Сессия началась; сейчас нужно дать дыханию, ногам и пульсу стабилизироваться.")
                    situation = CoachFinalStoryBuilder.dynamicText("Use the opening block as a warm-up, not a fitness test.", russian: "Используйте первый блок как разминку, а не проверку формы.")
                    primary = action(.controlIntensity, "Keep the next 10 minutes easy", "Let effort rise only after the body settles", "Следующие 10 минут держите легко", "Добавляйте усилие только после стабилизации")
                    avoidance = CoachFinalStoryBuilder.dynamicText("Do not test fitness in the opening block.", russian: "Не проверяйте форму в начале.")
                case .sustainableExecution:
                    hero = CoachFinalStoryBuilder.dynamicText("Build a steady rhythm", russian: "Постройте ровный ритм")
                    assessment = CoachFinalStoryBuilder.dynamicText("The warm-up window is over; now the session needs repeatable effort and regular intake.", russian: "Разминочное окно прошло; теперь нужны повторяемое усилие, вода и питание по графику.")
                    situation = CoachFinalStoryBuilder.dynamicText("This is where you make the rest of the ride predictable.", russian: "Сейчас вы делаете остаток сессии предсказуемым.")
                    primary = action(.sustainEnergy, "Take carbs every 20-30 minutes", "Start the schedule before hunger appears", "Принимайте углеводы каждые 20-30 минут", "Начните график до появления голода")
                    avoidance = CoachFinalStoryBuilder.dynamicText("Do not wait for hunger before starting the fueling schedule.", russian: "Не ждите голода, чтобы начать питание.")
                default:
                    hero = CoachFinalStoryBuilder.dynamicText("Build a steady rhythm", russian: "Постройте ровный ритм")
                    assessment = CoachFinalStoryBuilder.dynamicText("The useful job now is repeatable execution inside the whole day.", russian: "Сейчас важна повторяемая работа в контексте всего дня.")
                    situation = CoachFinalStoryBuilder.dynamicText("Keep the session predictable rather than chasing spikes.", russian: "Держите сессию предсказуемой, без скачков.")
                    primary = action(.controlIntensity, "Keep effort repeatable", "Leave enough reserve for the rest of the session", "Держите усилие повторяемым", "Оставьте запас на остаток сессии")
                    avoidance = CoachFinalStoryBuilder.dynamicText("Do not turn one good block into a harder plan.", russian: "Не превращайте один хороший блок в более тяжёлый план.")
                }
            case (.post, .longOver120):
                hero = CoachFinalStoryBuilder.dynamicText("The main work is complete", russian: "Главная работа завершена")
                assessment = CoachFinalStoryBuilder.dynamicText("This long session created meaningful training stress.", russian: "Эта длинная сессия дала заметную тренировочную нагрузку.")
                situation = CoachFinalStoryBuilder.dynamicText("Recovery now determines how much benefit you keep.", russian: "Теперь восстановление определяет, сколько пользы сохранится.")
                primary = action(.recoveryMeal, "Eat 25-40 g protein and 60-100 g carbs", "Within the next hour", "Получите 25-40 г белка и 60-100 г углеводов", "В течение ближайшего часа")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not add another hard session today.", russian: "Не добавляйте сегодня ещё одну тяжёлую сессию.")
            case (.post, .medium60To120):
                hero = CoachFinalStoryBuilder.dynamicText("Start recovery now", russian: "Начните восстановление")
                assessment = CoachFinalStoryBuilder.dynamicText("This session was meaningful enough to deserve recovery support.", russian: "Эта сессия достаточно значимая, чтобы поддержать восстановление.")
                situation = CoachFinalStoryBuilder.dynamicText("Food and fluids matter more than extra work now.", russian: "Еда и вода сейчас важнее дополнительной нагрузки.")
                primary = action(.recoveryMeal, "Add 25-40 g protein", "Before the next hour ends", "Добавьте 25-40 г белка", "До конца ближайшего часа")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not stack extra intensity onto this session.", russian: "Не накладывайте дополнительную интенсивность поверх этой сессии.")
            case (.post, .shortUnder60), (.post, .none):
                hero = CoachFinalStoryBuilder.dynamicText("Close the session cleanly", russian: "Спокойно завершите сессию")
                assessment = CoachFinalStoryBuilder.dynamicText("This was controlled endurance work, not a full recovery demand by itself.", russian: "Это была контролируемая работа на выносливость, но сама по себе она не требует жёсткого восстановления.")
                situation = CoachFinalStoryBuilder.dynamicText("A short cooldown and normal meals are enough unless the day was already heavy.", russian: "Короткой заминки и обычного питания достаточно, если день не был тяжёлым.")
                primary = action(.cooldown, "Cool down 5-10 minutes easy", "Let the body come down", "Сделайте 5-10 минут лёгкой заминки", "Дайте телу спокойно снизить нагрузку")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not add extra volume just because the session felt good.", russian: "Не добавляйте объём только потому, что сессия прошла хорошо.")
            case (.none, _):
                return base(frame)
            }

            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: enduranceExtras(frame))
        }

        private static func preEndurance(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let longSession = frame.durationBand == .longOver120
            let sessionName = longSession ? "long ride" : "endurance session"
            let russianSessionName = longSession ? "длинная велосессия" : "сессия на выносливость"

            let hero: CoachFinalStoryText
            let assessment: CoachFinalStoryText
            let situation: CoachFinalStoryText
            let primary: CoachActionRecommendation
            let avoidance: CoachFinalStoryText
            let extras: [CoachActionRecommendation]

            switch frame.dayLoadContext.timeToNextImportantSession {
            case .fourPlusHours:
                hero = CoachFinalStoryBuilder.dynamicText("Build toward the \(sessionName)", russian: "\(capitalized(russianSessionName)) — главный ориентир")
                assessment = CoachFinalStoryBuilder.dynamicText("\(capitalized(sessionName)) is still several hours away, and recovery is not blocking it.", russian: "\(capitalized(russianSessionName)) ещё через несколько часов, восстановление её не блокирует.")
                situation = CoachFinalStoryBuilder.dynamicText("Use this window to plan food, bottles, and a quiet lead-in.", russian: "Используйте это время для еды, воды и спокойного подведения к старту.")
                primary = action(.lightFueling, "Plan the carb meal", "Finish it 2-3 hours before the session", "Запланируйте углеводный приём пищи", "Завершите его за 2-3 часа до старта")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not add a second workout before the important session.", russian: "Не добавляйте вторую тренировку перед главной сессией.")
                extras = [
                    action(.hydrateBeforeSession, "Start steady hydration", "Keep sipping before the final hour", "Начните ровную гидратацию", "Пейте постепенно до последнего часа"),
                    action(.controlIntensity, "Keep the lead-in quiet", "Save freshness for the session", "Сделайте подводку спокойной", "Сохраните свежесть для сессии")
                ]

            case .twoToFourHours:
                hero = CoachFinalStoryBuilder.dynamicText("Set up the \(sessionName)", russian: "Подведите себя к \(russianSessionName)")
                assessment = CoachFinalStoryBuilder.dynamicText("\(capitalized(sessionName)) is the main training demand later today.", russian: "\(capitalized(russianSessionName)) — главная тренировочная нагрузка позже сегодня.")
                situation = CoachFinalStoryBuilder.dynamicText("The useful move now is to finish fueling and keep the controlled start coming.", russian: "Сейчас полезно закрыть питание и сохранить спокойный старт впереди.")
                primary = action(.lightFueling, "Finish fueling for a controlled start", "Then keep activity low", "Закройте питание для спокойного старта", "Потом держите активность низкой")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not turn the waiting time into extra training.", russian: "Не делайте из ожидания дополнительную тренировку.")
                extras = [
                    action(.hydrateBeforeSession, "Finish steady hydration", "Avoid needing to catch up at the start", "Доведите воду до нормы", "Не догоняйте её на старте"),
                    action(.controlIntensity, "Reduce unnecessary movement", "Arrive fresher, not busier", "Сократите лишнее движение", "Выйдите свежее, а не занятым")
                ]

            case .sixtyTo120Minutes:
                hero = CoachFinalStoryBuilder.dynamicText("Move into preparation mode", russian: "Переходите в режим подготовки")
                assessment = CoachFinalStoryBuilder.dynamicText("The main work is close; keep the next steps simple.", russian: "Главная работа уже близко; следующие шаги должны быть простыми.")
                situation = CoachFinalStoryBuilder.dynamicText("This is the final useful window for a small top-up, bottles, and equipment.", russian: "Это финальное полезное окно для небольшого пополнения, воды и экипировки.")
                primary = action(.hydrateBeforeSession, "Check bottles and take small sips", "Keep the stomach comfortable", "Проверьте бутылки и пейте маленькими глотками", "Оставьте желудок комфортным")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not force a full meal this close to the start.", russian: "Не форсируйте полноценный приём пищи так близко к старту.")
                extras = [
                    action(.lightFueling, "Use only a light carb top-up", "If you are actually hungry", "Добавьте только лёгкие углеводы", "Если реально голодно"),
                    action(.mobilityPrep, "Check kit and route", "Remove decisions before the start", "Проверьте форму и маршрут", "Уберите решения перед стартом")
                ]

            case .fifteenTo60Minutes:
                hero = CoachFinalStoryBuilder.dynamicText("Be fresh at the start", russian: "Подойдите к старту свежим")
                assessment = CoachFinalStoryBuilder.dynamicText("The main work is close; keep the next steps simple.", russian: "Главная работа уже близко; следующие шаги должны быть простыми.")
                situation = CoachFinalStoryBuilder.dynamicText("The meal window has passed; focus on final hydration, kit, and a calm start.", russian: "Окно для еды уже прошло; сейчас важны вода, экипировка и спокойный старт.")
                primary = action(.hydrateBeforeSession, "Finish final hydration", "Small sips only", "Закончите финальную гидратацию", "Только маленькими глотками")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not try to fix fueling with a full meal now.", russian: "Не пытайтесь исправить питание полноценной едой прямо сейчас.")
                extras = [
                    action(.mobilityPrep, "Check equipment", "Pack nutrition, then start warm-up 10-15 minutes before the ride", "Проверьте экипировку", "Соберите питание, затем начните лёгкую разминку за 10-15 минут до старта")
                ]

            case .under15Minutes:
                hero = CoachFinalStoryBuilder.dynamicText("Start the warm-up now", russian: "Начинайте разминку сейчас")
                assessment = CoachFinalStoryBuilder.dynamicText("\(capitalized(sessionName)) is about to start; the useful choices are execution choices now.", russian: "\(capitalized(russianSessionName)) вот-вот начнётся; сейчас важны решения по выполнению.")
                situation = CoachFinalStoryBuilder.dynamicText("Begin calmly and let the body find working rhythm before any pressure.", russian: "Начните спокойно и дайте организму войти в рабочий ритм до любого давления.")
                primary = action(.controlIntensity, "Start warm-up now", "Keep the first 10-15 minutes easy", "Начните разминку сейчас", "Первые 10-15 минут держите легко")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not chase intensity from the first minutes.", russian: "Не гонитесь за интенсивностью с первых минут.")
                extras = [
                    action(.steadyHydration, "Take only a few sips", "No last-minute chugging", "Сделайте только несколько глотков", "Без воды залпом в последнюю минуту"),
                    action(.controlIntensity, "Keep the first 20-30 minutes controlled", "Let the rhythm come to you", "Первые 20-30 минут держите под контролем", "Пусть ритм придёт сам")
                ]

            case .none:
                hero = CoachFinalStoryBuilder.dynamicText("Prepare endurance calmly", russian: "Спокойно подготовьтесь к выносливости")
                assessment = CoachFinalStoryBuilder.dynamicText("The useful move is to start controlled and let readiness show itself.", russian: "Полезный ход — начать спокойно и дать готовности проявиться.")
                situation = CoachFinalStoryBuilder.dynamicText("Use the first minutes as a check, not a test.", russian: "Первые минуты — проверка, а не тест.")
                primary = action(.controlIntensity, "Start 10 minutes easy", "Then settle into the plan", "Начните 10 минут легко", "Затем входите в план")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not force the first block.", russian: "Не форсируйте первый блок.")
                extras = []
            }

            return playbookOnlyOutput(
                hero: hero,
                assessment: assessment,
                situation: situation,
                primary: primary,
                avoidance: avoidance,
                extras: extras,
                reasons: preEnduranceReasons(frame)
            )
        }

        private static func fuelingDuringEndurance(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            playbookOnlyOutput(
                hero: CoachFinalStoryBuilder.dynamicText("Protect energy availability", russian: "Защитите доступную энергию"),
                assessment: CoachFinalStoryBuilder.dynamicText("You are spending energy faster than you are replacing it.", russian: "Вы тратите энергию быстрее, чем восполняете её."),
                situation: CoachFinalStoryBuilder.dynamicText("The next useful move is fueling, not another pacing cue.", russian: "Сейчас полезнее питание, а не ещё одна подсказка про темп."),
                primary: action(.sustainEnergy, "Consume 30-60 g carbohydrates", "Within the next 15 minutes", "Примите 30-60 г углеводов", "В течение ближайших 15 минут"),
                avoidance: CoachFinalStoryBuilder.dynamicText("Waiting for hunger is already too late in a long session.", russian: "В длинной сессии ждать голода уже поздно."),
                extras: [
                    action(.sustainEnergy, "Repeat carbs every 20-30 minutes", "Keep intake ahead of demand", "Повторяйте углеводы каждые 20-30 минут", "Держите питание впереди расхода"),
                    action(.steadyHydration, "Drink 300-500 ml over 20 minutes", "Pair fluid with the fueling block", "Выпейте 300-500 мл за 20 минут", "Совместите воду с блоком питания")
                ],
                reasons: [
                    reason(.training, "Energy expenditure is already high.", "Расход энергии уже высокий.", icon: "flame.fill", colorFamily: .activity),
                    reason(.fuel, "Fuel intake is behind the workload.", "Питание отстаёт от нагрузки.", icon: "bolt.fill", colorFamily: .fuel),
                    reason(.time, "The remaining work still needs usable energy.", "Оставшейся работе нужна доступная энергия.", icon: "clock.fill", colorFamily: .ready)
                ]
            )
        }

        private static func hydrationDuringEndurance(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            playbookOnlyOutput(
                hero: CoachFinalStoryBuilder.dynamicText("Bring fluid intake back on track", russian: "Верните воду в рабочий график"),
                assessment: CoachFinalStoryBuilder.dynamicText("Fluid intake is falling behind the workload.", russian: "Питьё отстаёт от нагрузки."),
                situation: CoachFinalStoryBuilder.dynamicText("A controlled bottle block now protects quality before thirst takes over.", russian: "Контролируемый блок воды сейчас защитит качество до сильной жажды."),
                primary: action(.steadyHydration, "Drink 300-500 ml", "During the next 20 minutes", "Выпейте 300-500 мл", "В течение ближайших 20 минут"),
                avoidance: CoachFinalStoryBuilder.dynamicText("Dehydration will reduce quality before fatigue feels obvious.", russian: "Обезвоживание снизит качество раньше, чем усталость станет явной."),
                extras: [
                    action(.steadyHydration, "Finish one bottle before the next hour", "Small sips, not one large drink", "Закончите одну бутылку до следующего часа", "Маленькими глотками, не залпом"),
                    action(.sustainEnergy, "Take carbs with the next drink", "Keep stomach and energy steady", "Добавьте углеводы со следующим питьём", "Держите желудок и энергию ровно")
                ],
                reasons: [
                    reason(.hydration, "Fluid intake is behind the session demand.", "Воды меньше, чем требует сессия.", icon: "drop.fill", colorFamily: .hydration),
                    reason(.training, "The workload is long enough for hydration to affect quality.", "Сессия достаточно длинная, чтобы вода влияла на качество.", icon: "figure.run", colorFamily: .activity),
                    reason(.constraint, "Catching up later is harder than steady drinking now.", "Позже догонять сложнее, чем пить ровно сейчас.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)
                ]
            )
        }

        private static func strength(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let post = frame.sessionPhase == .post
            let hero = post
                ? CoachFinalStoryBuilder.dynamicText("Recover from strength", russian: "Восстановитесь после силовой")
                : CoachFinalStoryBuilder.dynamicText("Keep strength controlled", russian: "Держите силовую под контролем")
            let assessment = post
                ? CoachFinalStoryBuilder.dynamicText("Strength work needs protein, fluids, and no extra hard blocks today.", russian: "После силовой нужны белок, вода и без дополнительных тяжёлых блоков.")
                : CoachFinalStoryBuilder.dynamicText("Form and reserve matter more than forcing load today.", russian: "Техника и запас сегодня важнее форсирования веса.")
            let situation = frame.dayLoadContext.shouldProtectTomorrow
                ? CoachFinalStoryBuilder.dynamicText("Tomorrow's work should influence how much you spend now.", russian: "Завтрашняя работа должна ограничивать сегодняшний расход.")
                : CoachFinalStoryBuilder.dynamicText("Useful strength should finish with control left.", russian: "Полезная силовая должна закончиться с запасом контроля.")
            let primary = post
                ? action(.recoveryMeal, "Target 25-40 g protein", "In the next meal", "Получите 25-40 г белка", "В ближайший приём пищи")
                : action(.controlIntensity, "Leave 1-2 reps in reserve", "Keep form clean", "Оставьте 1-2 повтора в запасе", "Держите технику чистой")
            let avoidance = CoachFinalStoryBuilder.dynamicText("Do not add sloppy volume.", russian: "Не добавляйте объём ценой техники.")
            let extras = post
                ? [
                    action(.cooldown, "Finish 5-10 minutes easy", "Let the body come down", "Сделайте 5-10 минут легко", "Дайте телу спокойно снизить нагрузку"),
                    action(.rehydrateGradually, "Drink 300-700 ml fluid", "During the next hour", "Выпейте 300-700 мл жидкости", "В течение ближайшего часа")
                ]
                : []
            if post {
                return playbookOnlyOutput(hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: extras, reasons: defaultReasons(frame))
            }
            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: extras)
        }

        private static func racket(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let hero = CoachFinalStoryBuilder.dynamicText("Control the court load", russian: "Контролируйте нагрузку на корте")
            let assessment = CoachFinalStoryBuilder.dynamicText("Racket sessions can become hard through repeated accelerations.", russian: "Игровые сессии могут стать тяжёлыми из-за повторных ускорений.")
            let situation = CoachFinalStoryBuilder.dynamicText("Keep movement sharp without chasing every extra point.", russian: "Держите движение резким, но не гонитесь за каждым лишним очком.")
            let primary = action(.controlIntensity, "Cap repeated sprints", "Keep the hardest rallies selective", "Ограничьте повторные рывки", "Выбирайте самые тяжёлые розыгрыши")
            let avoidance = CoachFinalStoryBuilder.dynamicText("Do not let competition override recovery.", russian: "Не позволяйте азарту перебить восстановление.")
            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: [])
        }

        private static func output(
            frame: CoachV4DecisionFrame,
            hero: CoachFinalStoryText,
            assessment: CoachFinalStoryText,
            situation: CoachFinalStoryText,
            primary: CoachActionRecommendation,
            avoidance: CoachFinalStoryText,
            extras: [CoachActionRecommendation]
        ) -> CoachV4PlaybookOutput {
            let actions = CoachFinalStoryBuilder.dedupedRecommendations([primary] + extras + frame.actions)
            return CoachV4PlaybookOutput(
                hero: hero,
                assessment: assessment,
                situation: situation,
                primaryAction: primary,
                avoidance: avoidance,
                actions: actions,
                reasons: defaultReasons(frame)
            )
        }

        private static func playbookOnlyOutput(
            hero: CoachFinalStoryText,
            assessment: CoachFinalStoryText,
            situation: CoachFinalStoryText,
            primary: CoachActionRecommendation,
            avoidance: CoachFinalStoryText,
            extras: [CoachActionRecommendation],
            reasons: [CoachV4Reason]
        ) -> CoachV4PlaybookOutput {
            let actions = CoachFinalStoryBuilder.dedupedRecommendations([primary] + extras)
            return CoachV4PlaybookOutput(
                hero: hero,
                assessment: assessment,
                situation: situation,
                primaryAction: primary,
                avoidance: avoidance,
                actions: actions,
                reasons: reasons
            )
        }

        private static func preEnduranceReasons(_ frame: CoachV4DecisionFrame) -> [CoachV4Reason] {
            var reasons: [CoachV4Reason] = []
            let longSession = frame.durationBand == .longOver120
            let trainingText = longSession
                ? ("This ride is the biggest training stimulus left today.", "Эта велосессия станет главным тренировочным стимулом дня.")
                : ("This session is the main training demand left today.", "Эта сессия — главная тренировочная нагрузка до конца дня.")

            if frame.dayLoadContext.timeToNextImportantSession == .under15Minutes {
                reasons.append(reason(.time, "Start time is almost here.", "Старт уже почти сейчас.", icon: "clock.fill", colorFamily: .ready))
            } else if let minutes = frame.dayLoadContext.hoursUntilNextImportantActivity.map({ Int(($0 * 60).rounded()) }) {
                let capped = max(minutes, 1)
                reasons.append(reason(.time, "Less than \(capped) minutes remain before the start.", "До старта осталось меньше \(capped) минут.", icon: "clock.fill", colorFamily: .ready))
            }

            if frame.primaryLimiter == .recovery {
                reasons.append(reason(.recovery, "Recovery is the limiting factor today.", "Восстановление сегодня ограничивает нагрузку.", icon: "heart.fill", colorFamily: .recovery))
            } else {
                reasons.append(reason(.recovery, "Recovery is high enough to use the planned session.", "Восстановление достаточно высокое для плановой сессии.", icon: "heart.fill", colorFamily: .recovery))
            }

            reasons.append(reason(.training, trainingText.0, trainingText.1, icon: "figure.run", colorFamily: .activity))
            return Array(reasons.prefix(3))
        }

        private static func defaultReasons(_ frame: CoachV4DecisionFrame) -> [CoachV4Reason] {
            var reasons: [CoachV4Reason] = []

            if frame.storyOwner == .pacingExecution {
                return [
                    reason(.time, "The session is still in the opening block.", "Сессия ещё в стартовом блоке.", icon: "clock.fill", colorFamily: .ready),
                    reason(.training, "Early control sets up the rest of the ride.", "Ранний контроль задаёт качество остатка сессии.", icon: "figure.run", colorFamily: .activity),
                    reason(.recovery, "Recovery is available, so there is no need to force proof now.", "Восстановление доступно, поэтому сейчас не нужно ничего доказывать.", icon: "heart.fill", colorFamily: .recovery)
                ]
            }

            if frame.storyOwner == .sustainableExecution {
                return [
                    reason(.time, "The warm-up window has passed.", "Разминочное окно уже прошло.", icon: "clock.fill", colorFamily: .ready),
                    reason(.training, "The remaining work needs a repeatable rhythm.", "Оставшейся работе нужен повторяемый ритм.", icon: "figure.run", colorFamily: .activity),
                    reason(.fuel, "Fueling and fluid timing start to matter now.", "Сейчас уже важны график питания и воды.", icon: "bolt.fill", colorFamily: .fuel)
                ]
            }

            if frame.activityClass == .heat || frame.activityFamily == .sauna {
                if frame.sessionPhase == .pre,
                   let minutes = frame.dayLoadContext.hoursUntilNextImportantActivity.map({ Int(($0 * 60).rounded()) }) {
                    reasons.append(reason(.time, "Sauna starts in about \(max(minutes, 1)) minutes.", "До сауны осталось примерно \(max(minutes, 1)) минут.", icon: "clock.fill", colorFamily: .ready))
                } else {
                    reasons.append(
                        frame.storyOwner == .tomorrowProtection
                            ? reason(.constraint, "Heat adds stress before tomorrow's session.", "Тепло добавляет стресс перед завтрашней тренировкой.", icon: "flame.fill", colorFamily: .warning)
                            : reason(.training, "Heat is the main stressor in this block.", "В этом блоке основная нагрузка — тепло.", icon: "flame.fill", colorFamily: .activity)
                    )
                }
                reasons.append(
                    frame.storyOwner == .tomorrowProtection
                        ? reason(.constraint, "Going in underhydrated would make tomorrow harder.", "Если зайти обезвоженным, завтра будет тяжелее.", icon: "drop.fill", colorFamily: .warning)
                        : reason(.hydration, "Hydration matters before heat exposure.", "Перед теплом важна гидратация.", icon: "drop.fill", colorFamily: .hydration)
                )
                if frame.primaryLimiter == .sleep || frame.primaryLimiter == .recovery {
                    reasons.append(reason(.sleep, "Sleep was shorter than usual.", "Сон был короче обычного.", icon: "moon.fill", colorFamily: .recovery))
                } else {
                    reasons.append(reason(.recovery, "Recovery is not blocking a conservative sauna.", "Восстановление не мешает умеренной сауне.", icon: "heart.fill", colorFamily: .recovery))
                }
                return Array(reasons.prefix(3))
            }

            if frame.dayLoadContext.completedSeriousTrainingToday {
                reasons.append(reason(.training, "Meaningful training work is already in the day.", "Значимая тренировочная работа сегодня уже была.", icon: "checkmark.circle.fill", colorFamily: .activity))
            }

            if frame.dayLoadContext.shouldProtectTomorrow {
                reasons.append(
                    activeOwnerAllowsOnlyExecutionReasons(frame)
                        ? reason(.constraint, "Tomorrow's training demand reduces today's margin.", "Завтрашняя нагрузка снижает сегодняшний запас.", icon: "calendar", colorFamily: .warning)
                        : reason(.tomorrow, "Tomorrow has a real training demand.", "Завтра есть реальная тренировочная нагрузка.", icon: "calendar", colorFamily: .activity)
                )
            } else if frame.dayLoadContext.nextImportantActivityToday != nil {
                reasons.append(reason(.training, "The next important session is still ahead.", "Следующая важная сессия ещё впереди.", icon: "figure.run", colorFamily: .activity))
            }

            switch frame.primaryLimiter {
            case .recovery:
                reasons.append(reason(.recovery, "Recovery is limiting how much useful work fits today.", "Восстановление ограничивает полезный объём сегодня.", icon: "heart.fill", colorFamily: .recovery))
            case .sleep:
                reasons.append(reason(.sleep, "Sleep is reducing today's margin.", "Сон сегодня снижает запас.", icon: "moon.fill", colorFamily: .recovery))
            case .hydration:
                reasons.append(reason(.hydration, "Fluid intake is behind the session demand.", "Воды меньше, чем требует сессия.", icon: "drop.fill", colorFamily: .hydration))
            case .fueling:
                reasons.append(reason(.fuel, "Available energy is behind the session demand.", "Доступной энергии меньше, чем требует сессия.", icon: "bolt.fill", colorFamily: .fuel))
            default:
                reasons.append(reason(.recovery, "Recovery is not blocking the next step.", "Восстановление не блокирует следующий шаг.", icon: "heart.fill", colorFamily: .recovery))
            }

            if frame.dayLoadContext.caloriesBurnedSoFar >= 700 {
                reasons.append(reason(.constraint, "The day already carries a noticeable energy cost.", "День уже заметно стоил энергии.", icon: "flame.fill", colorFamily: .warning))
            } else if reasons.count < 3 {
                reasons.append(
                    frame.storyOwner == .tomorrowProtection || activeOwnerAllowsOnlyExecutionReasons(frame)
                        ? reason(.constraint, "Extra load today would not help tomorrow.", "Дополнительная нагрузка сегодня не поможет завтра.", icon: "shield.fill", colorFamily: .warning)
                        : reason(.stability, "There is no need to add extra work for its own sake.", "Нет смысла добавлять нагрузку просто ради нагрузки.", icon: "shield.fill", colorFamily: .stable)
                )
            }

            return Array(reasons.prefix(3))
        }

        private static func activeOwnerAllowsOnlyExecutionReasons(_ frame: CoachV4DecisionFrame) -> Bool {
            switch frame.storyOwner {
            case .activeActivity, .pacingExecution, .sustainableExecution, .fuelingDuringActivity, .hydrationExecution:
                return true
            default:
                return false
            }
        }

        private static func reason(
            _ kind: CoachFinalStoryReason.Kind,
            _ english: String,
            _ russian: String,
            icon: String,
            colorFamily: CoachFinalStoryColorFamily
        ) -> CoachV4Reason {
            CoachV4Reason(
                kind: kind,
                english: english,
                russian: russian,
                icon: icon,
                colorFamily: colorFamily
            )
        }

        private static func recoveryExtras(_ frame: CoachV4DecisionFrame) -> [CoachActionRecommendation] {
            var actions: [CoachActionRecommendation] = [
                action(.controlIntensity, "Keep effort comfortable", "No hard blocks", "Сохраняйте комфортное усилие", "Без тяжёлых блоков")
            ]
            if frame.dayLoadContext.shouldProtectUpcomingSession {
                actions.append(action(.stayConsistent, "Save energy for later", "Keep this from costing the next session", "Сохраните энергию на потом", "Не забирайте ресурс у следующей сессии"))
            }
            if frame.dayLoadContext.shouldProtectTomorrow || frame.timePhase == .evening || frame.timePhase == .lateEvening {
                actions.append(action(.sleepPriority, "Keep the evening calm", "Let recovery do the work", "Сделайте вечер спокойным", "Пусть восстановление сделает своё дело"))
            }
            return actions
        }

        private static func saunaExtras(_ frame: CoachV4DecisionFrame) -> [CoachActionRecommendation] {
            var actions = [
                action(.steadyHydration, "Sip to comfort", "Do not drink everything at once", "Пейте до комфорта", "Не выпивайте всё залпом")
            ]
            if frame.dayLoadContext.shouldProtectTomorrow || frame.primaryLimiter == .recovery {
                actions.append(action(.sleepPriority, "Protect sleep tonight", "Keep heat and evening stress low", "Защитите сон сегодня", "Держите тепло и вечерний стресс ниже"))
            }
            return actions
        }

        private static func enduranceExtras(_ frame: CoachV4DecisionFrame) -> [CoachActionRecommendation] {
            var actions: [CoachActionRecommendation] = []
            if frame.sessionPhase == .pre && frame.durationBand != .shortUnder60 {
                actions.append(action(.hydrateBeforeSession, "Drink 300-500 ml water", "Over the next hour", "Выпейте 300-500 мл воды", "В течение ближайшего часа"))
            }
            if frame.sessionPhase == .during && frame.durationBand != .shortUnder60 {
                actions.append(action(.sustainEnergy, "Take carbs every 20-30 minutes", "Use a schedule, not hunger", "Принимайте углеводы каждые 20-30 минут", "Ориентируйтесь на график, не на голод"))
            }
            if frame.sessionPhase == .post && (frame.durationBand == .longOver120 || frame.dayLoadContext.caloriesBurnedSoFar >= 750) {
                actions.append(action(.rehydrateGradually, "Drink 500-750 ml fluid", "During the next hour", "Выпейте 500-750 мл жидкости", "В течение ближайшего часа"))
                actions.append(action(.sleepPriority, "Make sleep part of recovery", "Tonight matters after endurance work", "Сделайте сон частью восстановления", "Сегодня ночью"))
            }
            return actions
        }

        private static func recoveryFamilyName(_ family: CoachV4ActivityFamily) -> (english: String, russian: String) {
            switch family {
            case .breathing:
                return ("breathing", "дыхание")
            case .stretching:
                return ("stretching", "растяжка")
            case .yoga:
                return ("yoga", "йога")
            case .mobility:
                return ("mobility", "мобильность")
            case .walk:
                return ("walk", "прогулка")
            default:
                return ("recovery work", "восстановительная активность")
            }
        }

        private static func capitalized(_ value: String) -> String {
            guard let first = value.first else { return value }
            return first.uppercased() + value.dropFirst()
        }

        private static func action(
            _ type: CoachSupportActionTypeV3,
            _ englishTitle: String,
            _ englishSubtitle: String,
            _ russianTitle: String,
            _ russianSubtitle: String
        ) -> CoachActionRecommendation {
            CoachActionRecommendation(
                type: type,
                englishTitle: englishTitle,
                englishSubtitle: englishSubtitle,
                russianTitle: russianTitle,
                russianSubtitle: russianSubtitle
            )
        }
    }

    private static func humanStory(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        titleFallback: CoachFinalStoryText,
        whatHappenedFallback: CoachFinalStoryText,
        whatToDoNextFallback: CoachFinalStoryText,
        whatToAvoidFallback: CoachFinalStoryText
    ) -> HumanStory {
        let title = humanTitle(owner: owner, input: input, guidance: guidance, fallback: titleFallback)
        let happened = whatHappenedText(owner: owner, input: input, guidance: guidance, fallback: whatHappenedFallback)
        let matters = whatMattersNowText(owner: owner, input: input, guidance: guidance, fallback: happened)
        let next = whatToDoNextText(owner: owner, input: input, guidance: guidance, fallback: whatToDoNextFallback)
        let avoid = whatToAvoidText(owner: owner, input: input, guidance: guidance, fallback: whatToAvoidFallback)

        return HumanStory(
            title: title,
            whatHappened: happened,
            whatMattersNow: matters,
            whatToDoNext: next,
            whatToAvoid: avoid
        )
    }

    private static func coachActionText(_ recommendation: CoachActionRecommendation) -> CoachFinalStoryText {
        dynamicText(
            "\(recommendation.englishTitle). \(recommendation.englishSubtitle).",
            russian: "\(recommendation.russianTitle). \(recommendation.russianSubtitle)."
        )
    }

    private static func localizedTitle(_ recommendation: CoachActionRecommendation) -> String {
        localizedAction(english: recommendation.englishTitle, russian: recommendation.russianTitle)
    }

    private static func localizedSubtitle(_ recommendation: CoachActionRecommendation) -> String {
        localizedAction(english: recommendation.englishSubtitle, russian: recommendation.russianSubtitle)
    }

    private static func humanTitle(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).hero
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload, .activeSleepRisk:
                return dynamicText("I would not continue today.", russian: "Я бы сегодня не продолжал.")
            case .activeRecoveryOnly:
                return dynamicText("Use this only to cool down.", russian: "Используйте это только как заминку.")
            case .activeWithCaution:
                return dynamicText("Keep this session controlled.", russian: "Держите эту сессию под контролем.")
            case .normalActive:
                return dynamicText("Settle the first block.", russian: "Войдите в первый блок спокойно.")
            }
        }

        if owner == .postActivityRecovery {
            return dynamicText("Protect today's work", russian: "Закрепите результат дня")
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            if isHeatActivity(activity) {
                return dynamicText("Make sauna easier", russian: "Сделайте сауну легче")
            }
            return dynamicText(
                "Prepare for \(displayName(activity).lowercased())",
                russian: "Подготовьтесь к следующей нагрузке"
            )
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            return dynamicText(
                "Protect tomorrow's \(labels.english)",
                russian: "Защитите завтрашний \(labels.russian)"
            )
        }

        return fallback
    }

    private static func whatHappenedText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).assessment
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload:
                return dynamicText(
                    "Today's load is already high for your current recovery.",
                    russian: "Сегодняшняя нагрузка уже высокая для текущего восстановления."
                )
            case .activeSleepRisk:
                return dynamicText(
                    "Sleep and recovery are the main limits right now.",
                    russian: "Сон и восстановление сейчас главные ограничения."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Your current state supports only very light work.",
                    russian: "Текущее состояние подходит только для очень лёгкой работы."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Readiness is not fully reliable, so this should stay controlled.",
                    russian: "Готовность сейчас не полностью надёжная, поэтому сессию лучше держать под контролем."
                )
            case .normalActive:
                return dynamicText(
                    "Recovery looks stable enough for a controlled \(displayName(activity).lowercased()).",
                    russian: "Восстановление выглядит достаточно стабильным для контролируемой сессии."
                )
            }
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Today's main training work is complete.",
                    russian: "Главная тренировка на сегодня завершена."
                )
            }
            if let activity = completedActivity(input: input, guidance: guidance) {
                return completedLoadText(activity: activity, input: input)
            }
            return dynamicText(
                "Today's training already delivered the main load.",
                russian: "Главная тренировка на сегодня уже выполнена."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            if kind == .heat {
                return dynamicText(
                    minutesUntil(activity, from: input.now).map { $0 <= 30 } == true
                        ? "Sauna is soon, and water is low."
                        : "Sauna is later today, and water is low.",
                    russian: minutesUntil(activity, from: input.now).map { $0 <= 30 } == true
                        ? "До сауны мало времени, а воды пока мало."
                        : "Сауна сегодня позже, а воды пока мало."
                )
            }
            let isLong = kind == .endurance || activity.effectiveDurationMinutes >= 75
            let name = displayName(activity).lowercased()
            return dynamicText(
                isLong ? "A long \(name) is coming soon." : "\(displayName(activity)) is coming soon.",
                russian: "Скоро начнется главная тренировка дня."
            )
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            let duration = activity.effectiveDurationMinutes
            return dynamicText(
                "Tomorrow has a \(duration)-minute \(labels.english) planned.",
                russian: "Завтра запланирован \(labels.russian) на \(duration) минут."
            )
        }

        if (owner == .readiness || owner == .stableOverview) && recoveryLooksStrong(input) {
            return dynamicText(
                "Your body is in a good place today.",
                russian: "Сегодня организм в хорошем состоянии."
            )
        }

        if let read = specificText(guidance.screenStory?.myRead) {
            return dynamicText(read, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatMattersNowText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).situation
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "This is not the moment to add intensity; sleep is the useful lever now.",
                    russian: "Сейчас не время добавлять интенсивность; главное — сон."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "The training load is already high; more work will cost more than it gives.",
                    russian: "Нагрузка уже высокая; дополнительная тренировка даст меньше, чем заберет."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "This can help recovery only if it stays very easy.",
                    russian: "Для восстановления нагрузка должна оставаться лёгкой."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Use the first minutes to check readiness, not to chase intensity.",
                    russian: "Начните плавно и оцените свои ощущения."
                )
            case .normalActive:
                return dynamicText(
                    "Pace it well instead of adding extra goals.",
                    russian: "Держите ровный темп вместо лишних целей."
                )
            }
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Recovery now depends mostly on the evening and sleep.",
                    russian: "Сейчас главный приоритет — сон и восстановление"
                )
            }
            return dynamicText(
                "Recovery is the objective now: absorb the load and keep the benefit.",
                russian: "Тренировка сделала своё дело, восстановление завершит работу."
            )
        }

        if owner == .activityPreparation {
            if let activity = upcomingActivity(input: input, guidance: guidance),
               isHeatActivity(activity) {
                return dynamicText(
                    "Do not go in dry; make it lighter.",
                    russian: "Не заходите сухим — сделайте легче."
                )
            }
            return dynamicText(
                "Start controlled so the session stays useful.",
                russian: "Начните спокойно, чтобы нагрузка осталась полезной."
            )
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            return dynamicText(
                "Tonight should make tomorrow's \(labels.english) easier to start.",
                russian: "Сегодняшний вечер должен облегчить завтрашний \(labels.russian)."
            )
        }

        if owner == .readiness || owner == .stableOverview {
            return dynamicText(
                "Keep the day consistent.",
                russian: "Держите ровный ритм до конца дня."
            )
        }

        if let why = specificText(guidance.screenStory?.whyThisMatters ?? guidance.priority.whyThisMatters) {
            return dynamicText(why, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatToDoNextText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if let actionText = primaryCoachActionText(owner: owner, input: input, guidance: guidance) {
            return actionText
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "Keep it short or stop, then protect sleep.",
                    russian: "Сейчас сон важнее нагрузки."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "Stay consistent rather than aggressive.",
                    russian: "Работайте стабильно, а не резко."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Keep the effort under control.",
                    russian: "Держите усилие под контролем."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Hold a steady rhythm.",
                    russian: "Сохраняйте ровный ритм."
                )
            case .normalActive:
                return dynamicText(
                    "Keep the effort under control.",
                    russian: "Держите усилие под контролем."
                )
            }
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Keep the rest of the day calm.",
                    russian: "Сохраняйте остаток дня спокойным."
                )
            }
            return dynamicText(
                "Give your body time to start recovering.",
                russian: "Дайте организму начать восстановление."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            if kind == .heat {
                return dynamicText(
                    "Sip 300-500 ml, keep sauna light, and do not drink it all at once.",
                    russian: "Выпейте 300-500 мл небольшими глотками, сделайте сауну легкой и не догоняйте воду залпом."
                )
            }
            if kind == .endurance || activity.effectiveDurationMinutes >= 75 {
                return dynamicText(
                    "Take quick carbs and drink a small amount before the start, then keep the first 15 minutes easy.",
                    russian: "Добавьте быстрые углеводы и немного воды перед стартом, затем первые 15 минут держите легко."
                )
            }
            return dynamicText(
                "Start easy and let your body settle into the session.",
                russian: "Начните спокойно и дайте организму войти в работу."
            )
        }

        if owner == .tomorrowProtection,
           tomorrowProtectionActivity(input: input, guidance: guidance) != nil {
            return dynamicText(
                "Save your energy for tomorrow's work.",
                russian: "Сохраните силы на завтрашнюю работу."
            )
        }

        if owner == .stableOverview || owner == .readiness ||
            owner == .recovery && recoveryLooksStrong(input) {
            return dynamicText("Leave the plan unchanged today.", russian: "Сегодня оставьте план без изменений.")
        }

        if let action = concreteActionText(guidance) {
            return dynamicText(action, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatToAvoidText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).avoidance
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "Do not turn a late evening into another hard session.",
                    russian: "Не добавляйте поздним вечером ещё одну тяжёлую нагрузку."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "Do not continue building load today.",
                    russian: "Не продолжайте наращивать нагрузку сегодня."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Do not turn this into training.",
                    russian: "Не делайте из этого тренировку."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Do not chase intensity if readiness feels off.",
                    russian: "Не гонитесь за интенсивностью, если готовность не ощущается надежной."
                )
            case .normalActive:
                return dynamicText(
                    "Do not rush the opening minutes.",
                    russian: "Не спешите в первые минуты."
                )
            }
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            return dynamicText(
                "Do not spend tomorrow's \(labels.english) capacity tonight.",
                russian: "Не тратьте сегодня ресурс для завтрашнего \(labels.russian)."
            )
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Do not add another hard effort this evening.",
                    russian: "Не добавляйте вечером еще одну тяжелую нагрузку."
                )
            }
            return dynamicText(
                "Do not add another hard session today.",
                russian: "Не добавляйте сегодня еще одну тяжелую сессию."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           CoachActivityContextResolverV3.kind(for: activity) == .endurance || activity.effectiveDurationMinutes >= 75 {
            return dynamicText(
                "Do not chase intensity in the first 15 minutes.",
                russian: "Не гонитесь за интенсивностью в первые 15 минут."
            )
        }

        if !usesCoachV4DecisionFrame(input: input, guidance: guidance),
           owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           isHeatActivity(activity) {
            return dynamicText(
                "Do not drink it all at once.",
                russian: "Не догоняйте воду одним большим объемом."
            )
        }

        if owner == .stableOverview || owner == .readiness ||
            owner == .recovery && recoveryLooksStrong(input) {
            return dynamicText(
                "Do not add intensity just because the day looks easy.",
                russian: "Не добавляйте интенсивность только потому, что день выглядит легким."
            )
        }

        if let avoid = specificText(guidance.avoidNotes.first ?? guidance.screenStory?.beCarefulWith) {
            return dynamicText(avoid, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func usesCoachV4DecisionFrame(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        true
    }

    private static func coachV4DecisionFrame(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachV4DecisionFrame {
        let timePhase = finalDecisionTimeOfDay(input.now)
        let rawActive = activeActivity(input: input, guidance: guidance) ?? ongoingV4Activity(input: input)
        let active = rawActive.flatMap { activity in
            isSignificantCoachActivityV4(activity) || isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna
                ? activity
                : nil
        }
        let upcomingHeat = upcomingV4RecoveryOrHeatActivity(input: input)
        let rawUpcoming = upcomingActivity(input: input, guidance: guidance)
        let upcoming = rawUpcoming.flatMap { isSignificantCoachActivityV4($0) ? $0 : nil } ??
            nextImportantActivityToday(input: input, guidance: guidance)
        let seriousCompleted = recentlyCompletedSeriousTraining(input: input, guidance: guidance)
        let rawLatestCompleted = latestCompletedActivity(input: input, guidance: guidance) ?? latestCompletedV4Activity(input: input)
        let latestCompleted = rawLatestCompleted.flatMap { isSignificantCoachActivityV4($0) ? $0 : nil }
        let tomorrow = tomorrowProtectionActivity(input: input, guidance: guidance)
        let fallbackSelected = selectedCoachActivity(input: input, guidance: guidance).flatMap { isSignificantCoachActivityV4($0) ? $0 : nil }
        let selected = active ?? seriousCompleted ?? upcoming ?? latestCompleted ?? tomorrow ?? upcomingHeat ?? fallbackSelected
        let activityClass = selected.map { v4ActivityClass(for: $0) } ?? .none
        let activityFamily = selected.map { coachV4ActivityFamily(for: $0) } ?? .other
        let sessionPhase = coachV4SessionPhase(
            selected: selected,
            active: active,
            upcoming: upcoming ?? upcomingHeat,
            now: input.now,
            latestCompleted: latestCompleted
        )
        let durationBand = selected.map { coachV4DurationBand(for: $0) } ?? .none
        let dayLoadContext = coachV4DayLoadContext(
            input: input,
            guidance: guidance,
            timePhase: timePhase,
            seriousCompleted: seriousCompleted
        )
        let lowRecovery = lowRecoveryOrReadiness(input)
        let sleepLimited = input.brain.sleep == .short || input.brain.sleep == .veryShort || input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5
        let hasTomorrowDemand = input.dayPriorityModel.tomorrowDemand == .hard || owner == .tomorrowProtection
        let hasUpcomingSerious = upcoming.map(isSeriousTraining) == true
        let hasActiveSerious = active.map(isSeriousTraining) == true
        let completedSerious = seriousCompleted != nil

        let limiter: CoachLimiter = {
            if lowRecovery { return .recovery }
            if sleepLimited { return .sleep }
            if completedSerious { return .accumulatedFatigue }
            if hasTomorrowDemand { return .upcomingTraining }
            if fuelingNeedsPreWorkoutAction(input), upcoming != nil || active != nil { return .fueling }
            if hydrationNeedsPreWorkoutAction(input), upcoming != nil || active != nil { return .hydration }
            return guidance.priority.limiter
        }()

        let seriousState: CoachV4SeriousTrainingState = {
            if completedSerious { return .completed }
            if hasActiveSerious { return .active }
            if hasUpcomingSerious { return .upcoming }
            if hasTomorrowDemand { return .tomorrow }
            return .none
        }()
        let proposedStoryOwner = coachV4StoryOwner(
            baseOwner: owner,
            input: input,
            guidance: guidance,
            selected: selected,
            active: active,
            sessionPhase: sessionPhase,
            durationBand: durationBand,
            activityFamily: activityFamily,
            dayLoadContext: dayLoadContext
        )
        let storyOwner = normalizedV4StoryOwner(
            proposedOwner: proposedStoryOwner,
            baseOwner: owner,
            input: input,
            guidance: guidance,
            selected: selected
        )
        let recoveryOnlyCompletionWithoutDeficit = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance) != nil &&
            !recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)
        logV4OwnerNormalization(
            source: "coachV4DecisionFrame",
            ownerBefore: proposedStoryOwner,
            ownerAfter: storyOwner,
            baseOwner: owner,
            input: input,
            guidance: guidance,
            selected: selected,
            reasonKinds: []
        )

        let permission: CoachV4TrainPermission = {
            if completedSerious && active.map(isRecoveryActivityV4) != true { return active == nil ? .recoveryOnly : .noTraining }
            if hasTomorrowDemand && (timePhase == .evening || timePhase == .lateEvening || lowRecovery) { return .noTraining }
            if active != nil && lowRecovery { return .trainControlled }
            if upcoming != nil && lowRecovery { return .trainControlled }
            if recoveryOnlyCompletionWithoutDeficit && storyOwner == .stableOverview { return .noActionNeeded }
            if storyOwner == .recovery { return .recoveryOnly }
            if active == nil && upcoming == nil && !hasTomorrowDemand && !lowRecovery {
                return .noActionNeeded
            }
            if owner == .stableOverview && recoveryLooksStrong(input) && upcoming == nil && !hasTomorrowDemand && input.actualLoad.activeCalories < 500 {
                return .noActionNeeded
            }
            return .train
        }()

        let intensity: CoachV4RecommendedIntensity = {
            switch permission {
            case .noActionNeeded, .noTraining:
                return .none
            case .recoveryOnly:
                return .easy
            case .trainControlled:
                return .reduced
            case .train:
                if active.map(isEnduranceLike) == true { return .conversational }
                return .planned
            }
        }()

        let objective: CoachObjective = {
            switch permission {
            case .noActionNeeded:
                return .completeDay
            case .noTraining:
                return hasTomorrowDemand ? .protectTomorrow : .recoveryDay
            case .recoveryOnly:
                return completedSerious ? .recoverFromActivity : .recoveryDay
            case .trainControlled:
                return active != nil ? .executeActivity : .prepareActivity
            case .train:
                if active != nil { return .executeActivity }
                if upcoming != nil { return .prepareActivity }
                return .buildReadiness
            }
        }()

        let actions = coachV4RankedActions(
            owner: storyOwner,
            input: input,
            guidance: guidance,
            permission: permission,
            seriousTrainingState: seriousState
        )
        let primaryAction = actions.first ?? CoachActionLibrary.noAction(
            reasonEnglish: "No useful change is needed right now",
            reasonRussian: "Сейчас нет полезного изменения"
        )

        let baseFrame = CoachV4DecisionFrame(
            storyOwner: storyOwner,
            trainPermission: permission,
            recommendedIntensity: intensity,
            objective: objective,
            primaryLimiter: limiter,
            activityClass: activityClass,
            activityFamily: activityFamily,
            sessionPhase: sessionPhase,
            durationBand: durationBand,
            seriousTrainingState: seriousState,
            dayLoadContext: dayLoadContext,
            timePhase: timePhase,
            hero: coachV4HeroText(
                owner: storyOwner,
                input: input,
                guidance: guidance,
                selectedActivity: selected,
                permission: permission,
                seriousTrainingState: seriousState
            ),
            assessment: coachV4AssessmentText(
                owner: storyOwner,
                input: input,
                selectedActivity: selected,
                seriousCompleted: seriousCompleted,
                limiter: limiter,
                permission: permission
            ),
            situation: coachV4SituationText(
                input: input,
                selectedActivity: selected,
                limiter: limiter,
                permission: permission,
                seriousTrainingState: seriousState
            ),
            primaryAction: primaryAction,
            avoidance: coachV4AvoidanceText(
                input: input,
                selectedActivity: selected,
                limiter: limiter,
                permission: permission,
                seriousTrainingState: seriousState
            ),
            actions: actions,
            reasons: []
        )

        let playbook = CoachV4ActivityPlaybook.resolve(baseFrame)

        return CoachV4DecisionFrame(
            storyOwner: baseFrame.storyOwner,
            trainPermission: baseFrame.trainPermission,
            recommendedIntensity: baseFrame.recommendedIntensity,
            objective: baseFrame.objective,
            primaryLimiter: baseFrame.primaryLimiter,
            activityClass: baseFrame.activityClass,
            activityFamily: baseFrame.activityFamily,
            sessionPhase: baseFrame.sessionPhase,
            durationBand: baseFrame.durationBand,
            seriousTrainingState: baseFrame.seriousTrainingState,
            dayLoadContext: baseFrame.dayLoadContext,
            timePhase: baseFrame.timePhase,
            hero: playbook.hero,
            assessment: playbook.assessment,
            situation: playbook.situation,
            primaryAction: playbook.primaryAction,
            avoidance: playbook.avoidance,
            actions: playbook.actions,
            reasons: playbook.reasons
        )
    }

    private static func coachV4StoryOwner(
        baseOwner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?,
        active: PlannedActivity?,
        sessionPhase: CoachV4SessionPhase,
        durationBand: CoachV4DurationBand,
        activityFamily: CoachV4ActivityFamily,
        dayLoadContext: CoachV4DayLoadContext
    ) -> CoachFinalStoryOwner {
        let selectedIsSignificant = selected.map(isSignificantCoachActivityV4) == true
        let selectedIsHeat = selected.map { isHeatActivity($0) || coachV4ActivityFamily(for: $0) == .sauna } == true
        let selectedIsTomorrow = selected.map { !Calendar.current.isDate($0.date, inSameDayAs: input.now) } == true
        let recoveryOnlyCompletionWithoutDeficit = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance) != nil &&
            !recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)

        if sessionPhase == .during,
           let active,
           selectedIsSignificant {
            if activityFamily == .endurance {
                if dayLoadContext.completedSeriousTrainingToday ||
                    lowRecoveryOrReadiness(input) {
                    return .activeActivity
                }

                let elapsed = activeElapsedMinutes(active, now: input.now)
                let longEnoughForFueling = elapsed >= 90 || durationBand == .longOver120 && elapsed >= 75
                let fuelRisk = enduranceFuelingIsBiggestLimiter(input: input, active: active, elapsedMinutes: elapsed)
                let hydrationRisk = enduranceHydrationIsBiggestLimiter(input: input, active: active, elapsedMinutes: elapsed)

                if longEnoughForFueling && fuelRisk {
                    return .fuelingDuringActivity
                }
                if elapsed >= 45 && hydrationRisk {
                    return .hydrationExecution
                }
                if elapsed < 30 {
                    return .pacingExecution
                }
                return .sustainableExecution
            }

            return .activeActivity
        }

        if sessionPhase == .post,
           selectedIsSignificant {
            return dayLoadContext.shouldProtectTomorrow || baseOwner == .tomorrowProtection
                ? .tomorrowProtection
                : .postActivityRecovery
        }

        if selectedIsTomorrow && (baseOwner == .tomorrowProtection || dayLoadContext.shouldProtectTomorrow) {
            return .tomorrowProtection
        }

        if sessionPhase == .pre,
           selectedIsSignificant {
            return .activityPreparation
        }

        if baseOwner == .tomorrowProtection || dayLoadContext.shouldProtectTomorrow {
            return .tomorrowProtection
        }

        if recoveryOnlyCompletionWithoutDeficit,
           baseOwner == .recovery || baseOwner == .postActivityRecovery || selected == nil || selected.map(isRecoveryActivityV4) == true {
            return .stableOverview
        }

        if selectedIsHeat {
            switch sessionPhase {
            case .pre:
                return .activityPreparation
            case .during:
                return .activeActivity
            case .post:
                return .recovery
            case .none:
                return baseOwner
            }
        }

        if selected.map(isRecoveryActivityV4) == true {
            return lowRecoveryOrReadiness(input) ? .recovery : .stableOverview
        }

        if baseOwner == .readiness,
           guidance.priority.focus == .trainingReadinessWarning || lowRecoveryOrReadiness(input) {
            return .readiness
        }

        if lowRecoveryOrReadiness(input) {
            return .recovery
        }

        if !recoveryOnlyCompletionWithoutDeficit &&
            (input.dayContext.completedTrainingStressScore >= 2 || input.actualLoad.activeCalories >= 900) {
            return .recovery
        }

        guard selected != nil else {
            return .stableOverview
        }

        return baseOwner
    }

    private static func activeElapsedMinutes(_ activity: PlannedActivity, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(activity.date) / 60))
    }

    private static func normalizedV4StoryOwner(
        proposedOwner: CoachFinalStoryOwner,
        baseOwner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?
    ) -> CoachFinalStoryOwner {
        let recoveryTierActivity = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance)
        let blockedByV4Contract = proposedOwner == .recovery &&
            isStableDailyOverview(input: input, guidance: guidance) &&
            recoveryTierActivity != nil &&
            !hasSignificantWorkoutContext(input: input, guidance: guidance, selected: selected) &&
            !recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)

        guard blockedByV4Contract else {
            return proposedOwner
        }

        return baseOwner == .readiness ? .readiness : .stableOverview
    }

    private static func isStableDailyOverview(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard guidance.priority.priority == .stable,
              guidance.priority.focus == .dailyOverview else {
            return false
        }
        if case .stable = guidance.phase {
            return true
        }
        return false
    }

    private static func hasSignificantWorkoutContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?
    ) -> Bool {
        if selected.map(isSignificantCoachActivityV4) == true { return true }
        if activeActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        if ongoingV4Activity(input: input).map(isSignificantCoachActivityV4) == true { return true }
        if upcomingActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        if nextImportantActivityToday(input: input, guidance: guidance) != nil { return true }
        if tomorrowProtectionActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        if recentlyCompletedSeriousTraining(input: input, guidance: guidance) != nil { return true }
        if latestCompletedActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        return false
    }

    private static func currentOrLastRecoveryTierOnlyActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        var candidates: [PlannedActivity] = []

        if let activity = guidance.priority.activity {
            candidates.append(activity)
        }

        switch guidance.phase {
        case .active(let activity, _),
             .recovering(let activity, _, _),
             .preparing(let activity, _, _):
            candidates.append(activity)
        case .stable:
            break
        }

        if let activity = input.dayContext.lastCompletedActivity {
            candidates.append(activity)
        }
        candidates.append(contentsOf: input.dayContext.completedActivities)
        candidates.append(contentsOf: input.plannedActivities.filter { $0.isCompleted || $0.date <= input.now })

        return candidates
            .filter { isRecoveryActivityV4($0) && !isSeriousTraining($0) }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func logV4OwnerNormalization(
        source: String,
        ownerBefore: CoachFinalStoryOwner,
        ownerAfter: CoachFinalStoryOwner,
        baseOwner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?,
        reasonKinds: [CoachFinalStoryReason.Kind],
        usedFallback: Bool = false,
        fallbackSource: String = "none"
    ) {
        #if DEBUG
        let recoveryTierActivity = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance)
        let hasIndependentRecoveryDeficit = recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)
        let blockedByV4Contract = ownerBefore == .recovery &&
            ownerAfter != .recovery &&
            isStableDailyOverview(input: input, guidance: guidance) &&
            recoveryTierActivity != nil &&
            !hasIndependentRecoveryDeficit
        CoachLogger.trace(
            "[CoachV4OwnerContract]",
            [
                "source=\(source)",
                "ownerBefore=\(ownerBefore.rawValue)",
                "ownerAfter=\(ownerAfter.rawValue)",
                "baseOwner=\(baseOwner.rawValue)",
                "priority=\(guidance.priority.priority)/\(guidance.priority.focus)",
                "phase=\(guidance.phase)",
                "activity=\(recoveryTierActivity?.title ?? selected?.title ?? "nil")",
                "activityState=\(recoveryTierActivity?.isCompleted == true ? "completed" : selected?.isCompleted == true ? "completed" : "unknown")",
                "reasonKinds=\(reasonKinds.map(\.rawValue).joined(separator: ","))",
                "isRecoveryTierActivity=\(recoveryTierActivity != nil)",
                "hasIndependentRecoveryDeficit=\(hasIndependentRecoveryDeficit)",
                "usedFallback=\(usedFallback)",
                "fallbackSource=\(fallbackSource)",
                "blockedByV4Contract=\(blockedByV4Contract)"
            ].joined(separator: " ")
        )
        #endif
    }

    private static func enduranceFuelingIsBiggestLimiter(
        input: CoachInputSnapshot,
        active: PlannedActivity,
        elapsedMinutes: Int
    ) -> Bool {
        let caloriesBurned = max(input.actualLoad.activeCalories, input.brain.metrics.activeCalories)
        let caloriesConsumed = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let carbs = input.nutritionContext?.carbsCurrent ?? input.brain.metrics.carbs
        let energyDeficit = caloriesBurned - caloriesConsumed
        return elapsedMinutes >= 90 &&
            (energyDeficit >= 500 || caloriesBurned >= 1_200 && caloriesConsumed < 0.70 * caloriesBurned || carbs < 80) &&
            active.effectiveDurationMinutes >= 90
    }

    private static func enduranceHydrationIsBiggestLimiter(
        input: CoachInputSnapshot,
        active: PlannedActivity,
        elapsedMinutes: Int
    ) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        let ratio = ratio(current: water, goal: waterGoal)
        return elapsedMinutes >= 45 &&
            active.effectiveDurationMinutes >= 75 &&
            (ratio < 0.35 || input.brain.hydration == .depleted)
    }

    private static func coachV4HeroText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selectedActivity: PlannedActivity?,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> CoachFinalStoryText {
        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload, .activeSleepRisk:
                return dynamicText("I would not continue today.", russian: "Я бы сегодня не продолжал.")
            case .activeRecoveryOnly:
                return dynamicText("Use this only to cool down.", russian: "Используйте это только как заминку.")
            case .activeWithCaution:
                return dynamicText("Keep this session controlled.", russian: "Держите эту сессию под контролем.")
            case .normalActive:
                return dynamicText("Settle the first block.", russian: "Войдите в первый блок спокойно.")
            }
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            if isHeatActivity(activity) {
                return dynamicText("Make sauna easier", russian: "Сделайте сауну легче")
            }
            return dynamicText(
                "Prepare for \(displayName(activity).lowercased())",
                russian: "Подготовьтесь к следующей нагрузке"
            )
        }

        if owner == .tomorrowProtection {
            if let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
                let labels = enduranceDisplayLabels(for: activity)
                return dynamicText(
                    "Protect tomorrow's \(labels.english)",
                    russian: "Защитите завтрашний \(labels.russian)"
                )
            }
            return dynamicText("Protect tomorrow's session", russian: "Защитите завтрашнюю тренировку")
        }
        if seriousTrainingState == .completed {
            return dynamicText("Protect today's work", russian: "Закрепите результат дня")
        }
        if permission == .noTraining {
            return dynamicText("Save the work for later", russian: "Сохраните ресурс на потом")
        }
        if let activity = selectedActivity {
            return dynamicText("Coach the \(displayName(activity).lowercased())", russian: "Разберите текущую активность")
        }
        if owner == .recovery {
            return dynamicText("Recovery matters most now", russian: "Сейчас важнее восстановление")
        }
        return dynamicText("The day looks quiet", russian: "День выглядит достаточно ровно")
    }

    private static func coachV4AssessmentText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        selectedActivity: PlannedActivity?,
        seriousCompleted: PlannedActivity?,
        limiter: CoachLimiter,
        permission: CoachV4TrainPermission
    ) -> CoachFinalStoryText {
        if let completed = seriousCompleted {
            let labels = recoveryActivityName(completed)
            return dynamicText(
                "The completed \(labels.english) created meaningful training stress.",
                russian: "Завершённая \(labels.russian) дала заметную тренировочную нагрузку."
            )
        }

        if owner == .tomorrowProtection {
            return dynamicText(
                "The best training move now is to keep this evening quiet.",
                russian: "Лучший ход сейчас — сделать вечер спокойным."
            )
        }

        if limiter == .sleep {
            return dynamicText(
                "Sleep is reducing today's readiness.",
                russian: "Сон сегодня снижает готовность."
            )
        }

        if limiter == .recovery {
            return dynamicText(
                "Recovery is limiting how much useful training you can absorb today.",
                russian: "Восстановление сегодня ограничивает объём полезной нагрузки."
            )
        }

        if permission == .noActionNeeded {
            return dynamicText(
                "Nothing important needs attention right now.",
                russian: "Сейчас ничего особенного не требует внимания."
            )
        }

        if selectedActivity.map(isRecoveryActivityV4) == true {
            return dynamicText(
                "This is recovery work, not a training session.",
                russian: "Это восстановительная активность, а не тренировка."
            )
        }

        if let activity = selectedActivity {
            return dynamicText(
                "Recovery looks stable enough for a controlled \(displayName(activity).lowercased()).",
                russian: "Восстановление выглядит достаточно стабильным для контролируемой сессии."
            )
        }

        return dynamicText(
            "The day does not need a training decision right now.",
            russian: "Сейчас день не требует тренировочного решения."
        )
    }

    private static func coachV4SituationText(
        input: CoachInputSnapshot,
        selectedActivity: PlannedActivity?,
        limiter: CoachLimiter,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> CoachFinalStoryText {
        switch permission {
        case .noActionNeeded:
            return dynamicText("Nothing useful needs changing now.", russian: "Сейчас ничего полезного менять не нужно.")
        case .noTraining:
            if input.dayPriorityModel.tomorrowDemand == .hard || localHour(input.now) >= 20 {
                return dynamicText("Sleep is the useful lever now.", russian: "Сейчас главный полезный рычаг — сон.")
            }
            return dynamicText("The useful move is to save capacity, not spend it.", russian: "Полезный ход сейчас — сохранить ресурс, а не тратить его.")
        case .recoveryOnly:
            return seriousTrainingState == .completed
                ? dynamicText("The work is done; recovery determines the benefit from here.", russian: "Работа сделана; дальше пользу определяет восстановление.")
                : dynamicText("Movement should help recovery, not become training.", russian: "Движение должно помогать восстановлению, а не становиться тренировкой.")
        case .trainControlled:
            return dynamicText("Training can happen, but the ceiling is lower today.", russian: "Тренироваться можно, но потолок сегодня ниже.")
        case .train:
            if selectedActivity != nil {
                return dynamicText("Use the opening minutes to confirm the body is responding well.", russian: "Первые минуты используйте, чтобы проверить отклик тела.")
            }
            return dynamicText("Recovery is not blocking the day.", russian: "Восстановление не блокирует день.")
        }
    }

    private static func coachV4AvoidanceText(
        input: CoachInputSnapshot,
        selectedActivity: PlannedActivity?,
        limiter: CoachLimiter,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> CoachFinalStoryText {
        if seriousTrainingState == .completed {
            if localHour(input.now) >= 20 {
                return dynamicText("Do not turn a late evening into another hard session.", russian: "Не добавляйте поздним вечером ещё одну тяжёлую сессию.")
            }
            return dynamicText("Do not add another hard session today.", russian: "Не добавляйте сегодня ещё одну тяжёлую сессию.")
        }
        if permission == .noActionNeeded {
            return dynamicText("Do not add work just to close a number.", russian: "Не добавляйте нагрузку только ради цифры.")
        }
        if limiter == .hydration {
            return dynamicText("Do not start the workout dehydrated.", russian: "Не начинайте тренировку обезвоженным.")
        }
        if limiter == .fueling {
            return dynamicText("Do not start the hard part under-fueled.", russian: "Не начинайте тяжёлую часть без доступной энергии.")
        }
        if limiter == .sleep || input.dayPriorityModel.tomorrowDemand == .hard {
            return dynamicText("Do not spend tomorrow's readiness tonight.", russian: "Не тратьте сегодня готовность для завтрашней нагрузки.")
        }
        if selectedActivity.map(isRecoveryActivityV4) == true {
            return dynamicText("Do not turn recovery work into a workout.", russian: "Не превращайте восстановительную активность в тренировку.")
        }
        return dynamicText("Do not add intensity before the body confirms it.", russian: "Не добавляйте интенсивность, пока тело не подтвердило готовность.")
    }

    private static func concreteActionText(_ guidance: CoachGuidanceV3) -> String? {
        guard !WeekFitCurrentLocale().identifier.hasPrefix("ru") else { return nil }
        let screenTitles = guidance.screenStory?.primaryActions.map(\.title) ?? []
        let supportTitles = guidance.supportActions.map(\.title)
        let titles = (screenTitles.isEmpty ? supportTitles : screenTitles)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isGenericActionText($0) }

        guard let first = titles.first else { return nil }
        if let second = titles.dropFirst().first, !isDuplicateAction(first, second) {
            return "\(first), then \(lowercasedFirst(second))."
        }
        return first
    }

    private static func primaryCoachActionText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryText? {
        coachActionText(coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).primaryAction)
    }

    private static func coachActionSupportActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).actions.map { recommendation in
            supportAction(
                recommendation.type,
                title: localizedTitle(recommendation),
                subtitle: localizedSubtitle(recommendation),
                colorFamily: colorFamily
            )
        }
    }

    private static func coachV4RankedActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> [CoachActionRecommendation] {
        var recommendations: [CoachActionRecommendation] = []

        func append(_ pool: CoachActionPool, where shouldInclude: (CoachActionRecommendation) -> Bool = { _ in true }) {
            recommendations.append(contentsOf: CoachActionLibrary.recommendations(for: pool).filter(shouldInclude))
        }

        if permission == .noActionNeeded {
            return [
                CoachActionLibrary.noAction(
                    reasonEnglish: "Keep the plan quiet and skip extra changes",
                    reasonRussian: "День выглядит спокойно; не добавляйте лишнего"
                ),
                CoachActionRecommendation(
                    type: .stayConsistent,
                    englishTitle: "Keep today as it is",
                    englishSubtitle: "Skip extra training blocks",
                    russianTitle: "Оставьте день как есть",
                    russianSubtitle: "Без дополнительных тренировочных блоков"
                )
            ]
        }

        if permission == .noTraining {
            if let active = activeActivity(input: input, guidance: guidance) {
                if isHeatActivity(active) || coachV4ActivityFamily(for: active) == .sauna {
                    return [
                        CoachActionRecommendation(
                            type: .controlIntensity,
                            englishTitle: "Keep the heat short and controlled",
                            englishSubtitle: "Leave before fatigue shows",
                            russianTitle: "Держите тепло коротким и спокойным",
                            russianSubtitle: "Выйдите до появления усталости"
                        ),
                        CoachActionRecommendation(
                            type: .steadyHydration,
                            englishTitle: "Sip to comfort after",
                            englishSubtitle: "Do not chase the full water target at once",
                            russianTitle: "После пейте до комфорта",
                            russianSubtitle: "Не догоняйте всю воду сразу"
                        )
                    ]
                }
                return [
                    CoachActionRecommendation(
                        type: .controlIntensity,
                        englishTitle: "Stop now or keep the rest controlled",
                        englishSubtitle: "Do not add intensity or extra sets",
                        russianTitle: "Остановитесь или держите остаток под контролем",
                        russianSubtitle: "Без дополнительной интенсивности и лишних подходов"
                    ),
                    CoachActionRecommendation(
                        type: .sleepPriority,
                        englishTitle: "Protect sleep",
                        englishSubtitle: "Make the rest of the evening quiet",
                        russianTitle: "Защитите сон",
                        russianSubtitle: "Остаток вечера сделайте спокойным"
                    )
                ]
            }
            append(.tomorrowBigWorkout) { recommendation in
                recommendation.type == .sleepPriority ||
                    recommendation.englishTitle.contains("Avoid another") ||
                    recommendation.englishTitle.contains("Save energy")
            }
            return dedupedRecommendations(recommendations)
        }

        switch owner {
        case .activityPreparation:
            guard let activity = upcomingActivity(input: input, guidance: guidance) else { break }
            let endurance = isEnduranceLike(activity)
            let hard = endurance || activity.effectiveDurationMinutes >= 60 || CoachActivityContextResolverV3.load(for: activity) == .high
            if hard && hydrationNeedsPreWorkoutAction(input) && fuelingNeedsPreWorkoutAction(input) {
                recommendations.append(
                    CoachActionRecommendation(
                        type: .lightFueling,
                        englishTitle: "Take quick carbs and 300-500 ml water",
                        englishSubtitle: "Then keep the first 15 minutes easy",
                        russianTitle: "Добавьте быстрые углеводы и 300-500 мл воды",
                        russianSubtitle: "Затем первые 15 минут держите легко"
                    )
                )
            }
            if hard {
                append(.beforeHardWorkout) { recommendation in
                    switch recommendation.type {
                    case .hydrateBeforeSession:
                        return hydrationNeedsPreWorkoutAction(input) || endurance
                    case .lightFueling:
                        return fuelingNeedsPreWorkoutAction(input) || activity.effectiveDurationMinutes >= 75
                    default:
                        return true
                    }
                }
            } else {
                append(.beforeHardWorkout) { recommendation in
                    recommendation.englishTitle.contains("10 minutes") ||
                        recommendation.englishTitle.contains("Avoid extra") ||
                        recommendation.englishTitle.contains("Prepare hydration")
                }
            }
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness) { recommendation in
                    recommendation.englishTitle.contains("10-15") || recommendation.englishTitle.contains("Reassess")
                }
            }

        case .activeActivity, .pacingExecution, .sustainableExecution:
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness) { recommendation in
                    recommendation.englishTitle.contains("10-15") ||
                        recommendation.englishTitle.contains("Reassess") ||
                        recommendation.englishTitle.contains("quality") ||
                        recommendation.englishTitle.contains("shortening")
                }
            }
            if let activity = activeActivity(input: input, guidance: guidance),
               isEnduranceLike(activity) {
                append(.duringEnduranceSession)
            } else {
                append(.duringEnduranceSession) { recommendation in
                    recommendation.englishTitle.contains("steady rhythm") ||
                        recommendation.englishTitle.contains("increasing intensity")
                }
            }

        case .postActivityRecovery:
            if let activity = recentlyCompletedSeriousTraining(input: input, guidance: guidance) ?? completedActivity(input: input, guidance: guidance) {
                if isStrengthLike(activity) {
                    append(.afterStrengthWorkout)
                } else if isEnduranceLike(activity) || activity.effectiveDurationMinutes >= 75 {
                    append(.afterLongEndurance)
                } else {
                    append(.afterStrengthWorkout) { recommendation in
                        recommendation.englishTitle.contains("5-10") ||
                            recommendation.englishTitle.contains("300-700") ||
                            recommendation.englishTitle.contains("complete meal")
                    }
                }
            } else {
                append(.afterLongEndurance) { recommendation in
                    recommendation.englishTitle.contains("Rehydrate") ||
                        recommendation.englishTitle.contains("rest of the day") ||
                        recommendation.englishTitle.contains("Sleep")
                }
            }

        case .recovery:
            append(.recoveryDay)
            if localHour(input.now) >= 18 {
                append(.optionalRecoveryTools) { recommendation in
                    recommendation.type == .sleepPriority || recommendation.englishTitle.contains("Walk easy")
                }
            }

        case .tomorrowProtection:
            append(.tomorrowBigWorkout)
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness) { recommendation in
                    recommendation.englishTitle.contains("shortening") || recommendation.englishTitle.contains("quality")
                }
            }

        case .readiness:
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness)
            } else {
                append(.recoveryDay) { recommendation in
                    recommendation.englishTitle.contains("20-40") || recommendation.englishTitle.contains("5-10")
                }
            }

        case .stableOverview:
            if permission == .noActionNeeded {
                break
            }
            append(.recoveryDay) { recommendation in
                recommendation.englishTitle.contains("20-40") || recommendation.englishTitle.contains("comfortable")
            }

        case .hydration, .hydrationExecution:
            append(.beforeHardWorkout) { recommendation in
                recommendation.type == .hydrateBeforeSession
            }

        case .fuel, .fuelingDuringActivity:
            append(.beforeHardWorkout) { recommendation in
                recommendation.type == .lightFueling
            }
        }

        return dedupedRecommendations(recommendations)
    }

    private static func dedupedRecommendations(_ recommendations: [CoachActionRecommendation]) -> [CoachActionRecommendation] {
        var seen = Set<String>()
        return recommendations.filter { recommendation in
            let key = "\(recommendation.type)-\(recommendation.englishTitle.lowercased())"
            return seen.insert(key).inserted
        }
    }

    private static func hydrationNeedsPreWorkoutAction(_ input: CoachInputSnapshot) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        return ratio(current: water, goal: waterGoal) < 0.85 ||
            input.brain.hydration == .behind ||
            input.brain.hydration == .depleted
    }

    private static func fuelingNeedsPreWorkoutAction(_ input: CoachInputSnapshot) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.nutritionContext?.caloriesGoal ?? input.brain.fullDayGoals.calories
        let carbs = input.nutritionContext?.carbsCurrent ?? input.brain.metrics.carbs
        let carbGoal = input.nutritionContext?.carbsGoal ?? input.brain.fullDayGoals.carbs
        return ratio(current: calories, goal: calorieGoal) < 0.45 ||
            ratio(current: carbs, goal: carbGoal) < 0.35 ||
            input.brain.fuel == .underfueled
    }

    private static func lowRecoveryOrReadiness(_ input: CoachInputSnapshot) -> Bool {
        (input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 65) ||
            input.brain.recovery == .compromised ||
            input.brain.readiness == .low ||
            input.brain.readiness == .compromised ||
            input.brain.sleep == .short ||
            input.brain.sleep == .veryShort
    }

    private static func coachV4ActivityFamily(for activity: PlannedActivity) -> CoachV4ActivityFamily {
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        if text.contains("breath") { return .breathing }
        if text.contains("stretch") { return .stretching }
        if text.contains("yoga") { return .yoga }
        if text.contains("mobility") { return .mobility }
        if text.contains("walk") || text.contains("walking") { return .walk }
        if kind == .heat || text.contains("sauna") { return .sauna }
        if isEnduranceLike(activity) { return .endurance }
        if isStrengthLike(activity) { return .strength }
        if text.contains("tennis") || text.contains("squash") || text.contains("racket") { return .racket }
        return .other
    }

    private static func coachV4SessionPhase(
        selected: PlannedActivity?,
        active: PlannedActivity?,
        upcoming: PlannedActivity?,
        now: Date,
        latestCompleted: PlannedActivity?
    ) -> CoachV4SessionPhase {
        guard let selected else { return .none }
        if active?.id == selected.id { return .during }
        if upcoming?.id == selected.id { return .pre }
        if latestCompleted?.id == selected.id || selected.isCompleted { return .post }
        if selected.date > now { return .pre }
        if coachV4EndDate(for: selected) > now { return .during }
        return .none
    }

    private static func coachV4DurationBand(for activity: PlannedActivity) -> CoachV4DurationBand {
        let minutes = activity.effectiveDurationMinutes
        guard minutes > 0 else { return .none }
        if minutes < 60 { return .shortUnder60 }
        if minutes <= 120 { return .medium60To120 }
        return .longOver120
    }

    private static func coachV4DayLoadContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        timePhase: CoachFinalDecisionTimeOfDay,
        seriousCompleted: PlannedActivity?
    ) -> CoachV4DayLoadContext {
        let nextImportant = nextImportantActivityToday(input: input, guidance: guidance)
        let hoursUntilNext = nextImportant.map { max(0, $0.date.timeIntervalSince(input.now) / 3600) }
        let tomorrowDemand = input.dayPriorityModel.tomorrowDemand

        return CoachV4DayLoadContext(
            timePhase: timePhase,
            caloriesBurnedSoFar: input.actualLoad.activeCalories,
            completedSeriousTrainingToday: seriousCompleted != nil || input.dayContext.completedTrainingStressScore >= 4,
            completedRecoveryVolumeToday: input.dayContext.completedActivityVolumeMinutes - input.dayContext.completedTrainingMinutes,
            nextImportantActivityToday: nextImportant,
            hoursUntilNextImportantActivity: hoursUntilNext,
            timeToNextImportantSession: coachV4TimeToSessionWindow(hoursUntilSession: hoursUntilNext),
            tomorrowDemand: tomorrowDemand,
            shouldProtectUpcomingSession: nextImportant != nil && (
                input.dayContext.completedTrainingStressScore > 0 ||
                    input.actualLoad.activeCalories >= 500 ||
                    input.recoveryContext.recoveryPercent < 75 ||
                    input.brain.sleep == .short ||
                    input.brain.sleep == .veryShort
            ),
            shouldProtectTomorrow: tomorrowDemand == .hard || guidance.priority.focus == .tomorrowPlanRisk
        )
    }

    private static func coachV4TimeToSessionWindow(hoursUntilSession: Double?) -> CoachV4TimeToSessionWindow {
        guard let hoursUntilSession else { return .none }
        if hoursUntilSession < 0.25 { return .under15Minutes }
        if hoursUntilSession < 1 { return .fifteenTo60Minutes }
        if hoursUntilSession < 2 { return .sixtyTo120Minutes }
        if hoursUntilSession < 4 { return .twoToFourHours }
        return .fourPlusHours
    }

    private static func nextImportantActivityToday(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let upcoming = upcomingActivity(input: input, guidance: guidance),
           isSignificantCoachActivityV4(upcoming) {
            return upcoming
        }

        return input.dayContext.upcomingTrainingActivities
            .filter { !$0.isSkipped && !$0.isCompleted && $0.date >= input.now }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func ongoingV4Activity(input: CoachInputSnapshot) -> PlannedActivity? {
        input.plannedActivities
            .filter { activity in
                !activity.isCompleted &&
                    !activity.isSkipped &&
                    activity.date <= input.now &&
                    (activity.source == "today" || coachV4EndDate(for: activity) >= input.now) &&
                    (isSignificantCoachActivityV4(activity) || isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func upcomingV4RecoveryOrHeatActivity(input: CoachInputSnapshot) -> PlannedActivity? {
        input.plannedActivities
            .filter { activity in
                !activity.isCompleted &&
                    !activity.isSkipped &&
                    activity.date >= input.now &&
                    (isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func latestCompletedV4Activity(input: CoachInputSnapshot) -> PlannedActivity? {
        input.plannedActivities
            .filter { activity in
                activity.isCompleted &&
                    !activity.isSkipped &&
                    (isSignificantCoachActivityV4(activity) || isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func coachV4EndDate(for activity: PlannedActivity) -> Date {
        activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, 1) * 60))
    }

    private static func v4ActivityClass(for activity: PlannedActivity) -> CoachV4ActivityClass {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        if kind == .heat { return .heat }
        if kind == .meal { return .nutrition }
        if isRecoveryActivityV4(activity) { return .recovery }
        if isSeriousTraining(activity) { return .seriousTraining }
        if isTrainingActivityV4(activity) { return .training }
        return .none
    }

    private static func isRecoveryActivityV4(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        if text.contains("recovery") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("yoga") ||
            text.contains("breath") ||
            text.contains("walk") ||
            text.contains("walking") {
            return !isSeriousTraining(activity)
        }
        return CoachActivityContextResolverV3.kind(for: activity) == .recovery
    }

    private static func isTrainingActivityV4(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        guard kind == .workout || kind == .endurance else { return false }
        return !isRecoveryActivityV4(activity) || isSeriousTraining(activity)
    }

    private static func isSignificantCoachActivityV4(_ activity: PlannedActivity) -> Bool {
        isTrainingActivityV4(activity) && !isRecoveryActivityV4(activity)
    }

    private static func isSeriousTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let minutes = activity.effectiveDurationMinutes
        let text = "\(activity.title) \(activity.type)".lowercased()

        if text.contains("recovery") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("yoga") ||
            text.contains("breath") ||
            text.contains("walk") ||
            text.contains("walking") {
            return false
        }

        if kind == .endurance {
            return minutes >= 75 || load == .high || load == .extreme || text.contains("interval") || text.contains("long")
        }

        if kind == .workout {
            let strength = text.contains("strength") || text.contains("gym") || text.contains("lift") || text.contains("weight")
            let racket = text.contains("tennis") || text.contains("squash")
            return (strength && (minutes >= 45 || load == .high || load == .extreme)) ||
                (racket && (minutes >= 60 || load == .high || load == .extreme)) ||
                load == .extreme
        }

        return false
    }

    private static func recentlyCompletedSeriousTraining(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if case .recovering(let activity, _, _) = guidance.phase,
           activity.isCompleted,
           isSeriousTraining(activity) {
            return activity
        }

        if let activity = guidance.priority.activity,
           activity.isCompleted,
           isSeriousTraining(activity) {
            return activity
        }

        return input.dayContext.completedTrainingActivities
            .filter(isSeriousTraining)
            .sorted { $0.date > $1.date }
            .first
    }

    private static func isEnduranceLike(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = "\(activity.title) \(activity.type)".lowercased()
        return kind == .endurance ||
            text.contains("run") ||
            text.contains("cycling") ||
            text.contains("ride") ||
            text.contains("bike") ||
            text.contains("bicycle")
    }

    private static func isStrengthLike(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = "\(activity.title) \(activity.type)".lowercased()
        return kind == .workout &&
            (text.contains("strength") ||
                text.contains("upper") ||
                text.contains("gym") ||
                text.contains("lift") ||
                text.contains("weight"))
    }

    private static func finalStorySupportActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        humanStory: HumanStory,
        colorFamily: CoachFinalStoryColorFamily,
        supportSignals: [CoachFinalStorySupportSignal]
    ) -> [CoachSupportActionV3] {
        let heroTexts = [
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ]

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           isHeatActivity(activity),
           hasSevereHydrationOrHeatContext(input: input) {
            return saunaHydrationSupportActions(colorFamily: colorFamily)
        }

        let upstream: [CoachSupportActionV3] = WeekFitCurrentLocale().identifier.hasPrefix("ru")
            ? []
            : (
                guidance.screenStory?.primaryActions.map { action in
                    CoachSupportActionV3(
                        type: action.type,
                        icon: action.icon,
                        title: action.title,
                        subtitle: action.subtitle,
                        color: action.color,
                        actionProvenance: action.actionProvenance
                    )
                } ?? []
            ) + guidance.supportActions
        let libraryActions = coachActionSupportActions(
            owner: owner,
            input: input,
            guidance: guidance,
            colorFamily: colorFamily
        )

        if owner == .postActivityRecovery || owner == .recovery {
            let recoveryActions = recoverySupportActions(input: input, guidance: guidance, colorFamily: colorFamily)
            let upstreamRecoveryActions = upstream.filter { !isGenericRecoveryFallbackAction($0) }
            let actions = filterSignalDuplicatingActions(
                mergeActions(libraryActions, recoveryActions + upstreamRecoveryActions, avoiding: heroTexts),
                owner: owner,
                input: input,
                guidance: guidance,
                supportSignals: supportSignals
            )
            if !actions.isEmpty {
                return Array(actions.prefix(3))
            }
            let fallbackRecoveryActions = filterSignalDuplicatingActions(
                mergeActions(libraryActions, recoveryActions, avoiding: heroTexts),
                owner: owner,
                input: input,
                guidance: guidance,
                supportSignals: supportSignals
            )
            if !fallbackRecoveryActions.isEmpty {
                return Array(fallbackRecoveryActions.prefix(3))
            }
        }

        var actions = filterSignalDuplicatingActions(
            dedupedActions(libraryActions + upstream, avoiding: heroTexts),
            owner: owner,
            input: input,
            guidance: guidance,
            supportSignals: supportSignals
        )
        actions = filterStableDayHydrationFuelActions(
            actions,
            owner: owner,
            input: input,
            guidance: guidance
        )

        if actions.isEmpty {
            actions.append(
                fallbackSupportAction(
                    owner: owner,
                    colorFamily: colorFamily
                )
            )
        }

        return Array(actions.prefix(3))
    }

    private static func fallbackSupportAction(
        owner: CoachFinalStoryOwner,
        colorFamily: CoachFinalStoryColorFamily
    ) -> CoachSupportActionV3 {
        switch owner {
        case .activityPreparation:
            return supportAction(
                .controlIntensity,
                title: localizedAction(english: "Start with 10 minutes easy", russian: "Начните с 10 минут лёгкого усилия"),
                subtitle: localizedAction(english: "Let the warm-up set the first rhythm", russian: "Пусть разминка задаст первый ритм"),
                colorFamily: colorFamily
            )
        case .activeActivity:
            return supportAction(
                .controlIntensity,
                title: localizedAction(english: "Hold the next block controlled", russian: "Следующий блок держите под контролем"),
                subtitle: localizedAction(english: "Skip surges until breathing and form settle", russian: "Без рывков, пока дыхание и техника не стабилизируются"),
                colorFamily: colorFamily
            )
        case .pacingExecution:
            return supportAction(
                .controlIntensity,
                title: localizedAction(english: "Keep the next 10 minutes easy", russian: "Следующие 10 минут держите легко"),
                subtitle: localizedAction(english: "Let effort rise only after the body settles", russian: "Добавляйте усилие только после стабилизации"),
                colorFamily: colorFamily
            )
        case .sustainableExecution:
            return supportAction(
                .sustainEnergy,
                title: localizedAction(english: "Take carbs every 20-30 minutes", russian: "Принимайте углеводы каждые 20-30 минут"),
                subtitle: localizedAction(english: "Pair each fueling block with small sips", russian: "Сочетайте каждый блок питания с маленькими глотками"),
                colorFamily: colorFamily
            )
        case .postActivityRecovery:
            return supportAction(
                .recoveryMeal,
                title: localizedAction(english: "Eat within 1 hour", russian: "Не откладывайте питание больше чем на час"),
                subtitle: localizedAction(english: "Start recovery with the next meal", russian: "Начните восстановление с ближайшего приёма пищи"),
                colorFamily: colorFamily
            )
        case .recovery:
            return supportAction(
                .lightRecoveryMovement,
                title: localizedAction(english: "Walk 20-40 minutes easy", russian: "Ограничьтесь лёгкой прогулкой 20-40 минут"),
                subtitle: localizedAction(english: "Keep it conversational", russian: "В комфортном темпе"),
                colorFamily: colorFamily
            )
        case .tomorrowProtection:
            return supportAction(
                .sleepPriority,
                title: localizedAction(english: "Aim for 7-8 hours sleep", russian: "Постарайтесь обеспечить 7-8 часов сна"),
                subtitle: localizedAction(english: "Make tonight the main recovery block", russian: "Сегодня ночью"),
                colorFamily: colorFamily
            )
        case .readiness:
            return supportAction(
                .controlIntensity,
                title: localizedAction(english: "Reduce intensity by one level", russian: "Снизьте плановую интенсивность на один уровень"),
                subtitle: localizedAction(english: "Use this before the main set", russian: "Перед основной частью"),
                colorFamily: colorFamily
            )
        case .fuelingDuringActivity:
            return supportAction(
                .sustainEnergy,
                title: localizedAction(english: "Consume 30-60 g carbs", russian: "Примите 30-60 г углеводов"),
                subtitle: localizedAction(english: "Within the next 15 minutes", russian: "В течение ближайших 15 минут"),
                colorFamily: colorFamily
            )
        case .hydrationExecution:
            return supportAction(
                .steadyHydration,
                title: localizedAction(english: "Drink 300-500 ml", russian: "Выпейте 300-500 мл"),
                subtitle: localizedAction(english: "During the next 20 minutes", russian: "В течение ближайших 20 минут"),
                colorFamily: colorFamily
            )
        case .stableOverview, .hydration, .fuel:
            break
        }

        return supportAction(
            .stayConsistent,
            title: localizedAction(english: "Leave the plan unchanged", russian: "Оставьте план без изменений"),
            subtitle: localizedAction(english: "Do not add a new correction today", russian: "Сегодня не добавляйте новое исправление"),
            colorFamily: colorFamily
        )
    }

    private static func finalCopyPlan(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        humanStory: HumanStory,
        reasons: [CoachFinalStoryReason],
        supportActions: [CoachSupportActionV3]
    ) -> FinalCopyPlan {
        let critical = finalCopyIsCritical(owner: owner, input: input, guidance: guidance)
        let maxWhyRows = critical ? 3 : 2
        let maxActions = critical ? 3 : 2
        let heroTexts = [
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ]
        let heroThemes = Set(heroTexts.flatMap { finalCopyThemes(in: $0) })
        let concreteCriticalActions = supportActions.filter {
            finalCopyConcreteActionIsNecessary($0, critical: critical)
        }
        let concreteCriticalThemes = concreteCriticalActions.flatMap { action in
            finalCopyThemes(for: action)
        }
        let concreteCriticalActionThemes = Set(concreteCriticalThemes.filter { theme in
            theme == .hydration || theme == .fuel || theme == .protein
        })
        var themeCounts = Dictionary(uniqueKeysWithValues: FinalCopyTheme.allCases.map { ($0, heroThemes.contains($0) ? 1 : 0) })
        var seenText = Set(heroTexts.map(finalCopyNormalizedText))
        var cleanedReasons: [CoachFinalStoryReason] = []

        for reason in reasons {
            guard cleanedReasons.count < maxWhyRows else { break }

            let text = reason.text.resolved
            let normalized = finalCopyNormalizedText(text)
            guard !normalized.isEmpty, seenText.insert(normalized).inserted else { continue }

            let themes = finalCopyThemes(for: reason)
            let newThemes = themes.subtracting(heroThemes)
            let concreteActionAlreadyOwnsTheme = !themes.intersection(concreteCriticalActionThemes).isEmpty
            let repeatsHeroOnly = !themes.isEmpty && newThemes.isEmpty

            if concreteActionAlreadyOwnsTheme || (repeatsHeroOnly && !finalCopyReasonCanRestateHero(reason)) {
                continue
            }

            if finalCopyWouldOverRepeat(themes, themeCounts: themeCounts) {
                continue
            }

            cleanedReasons.append(reason)
            finalCopyAddThemes(themes, to: &themeCounts)
        }

        if cleanedReasons.isEmpty, let fallbackReason = finalCopyFallbackReason(
            from: reasons,
            avoiding: seenText,
            themeCounts: themeCounts
        ) {
            cleanedReasons = [fallbackReason]
            finalCopyAddThemes(finalCopyThemes(for: fallbackReason), to: &themeCounts)
            seenText.insert(finalCopyNormalizedText(fallbackReason.text.resolved))
        }

        let whyThemes = Set(cleanedReasons.flatMap { finalCopyThemes(for: $0) })
        var seenActionThemes = Set<FinalCopyTheme>()
        var cleanedActions: [CoachSupportActionV3] = []

        for action in supportActions {
            guard cleanedActions.count < maxActions else { break }

            let normalizedTitle = finalCopyNormalizedText(action.title)
            let normalizedSubtitle = finalCopyNormalizedText(action.subtitle)
            guard !normalizedTitle.isEmpty else { continue }
            guard !finalCopyTextOverlapsAny(normalizedTitle, in: seenText) else { continue }
            guard normalizedSubtitle.isEmpty || !finalCopyTextOverlapsAny(normalizedSubtitle, in: seenText) else { continue }
            seenText.insert(normalizedTitle)

            let themes = finalCopyThemes(for: action)
            let concreteNecessary = finalCopyConcreteActionIsNecessary(action, critical: critical)
            let repeatsWhy = !themes.intersection(whyThemes).isEmpty
            let repeatsActionTheme = !themes.intersection(seenActionThemes).isEmpty
            let genericSignalAction = finalCopyIsGenericHydrationOrFuelAction(action)

            if repeatsActionTheme {
                continue
            }
            if repeatsWhy && (!concreteNecessary || genericSignalAction) {
                continue
            }
            if finalCopyWouldOverRepeat(themes, themeCounts: themeCounts), !concreteNecessary {
                continue
            }

            cleanedActions.append(action)
            seenActionThemes.formUnion(themes)
            finalCopyAddThemes(themes, to: &themeCounts)
        }

        let cleanedHumanStory = finalCopyCompressedHumanStory(
            humanStory,
            owner: owner,
            input: input,
            guidance: guidance,
            supportActions: cleanedActions
        )

        return FinalCopyPlan(
            humanStory: cleanedHumanStory,
            reasons: cleanedReasons,
            supportActions: cleanedActions
        )
    }

    private static func finalCopyCompressedHumanStory(
        _ humanStory: HumanStory,
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        supportActions: [CoachSupportActionV3]
    ) -> HumanStory {
        let actionThemes = Set(supportActions.flatMap { finalCopyThemes(for: $0) })
        var happened = humanStory.whatHappened
        var matters = humanStory.whatMattersNow
        var next = humanStory.whatToDoNext
        var avoid = humanStory.whatToAvoid

        if !usesCoachV4DecisionFrame(input: input, guidance: guidance),
           owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           isHeatActivity(activity) {
            happened = dynamicText(
                "Keep the visit light.",
                russian: "Держите заход лёгким."
            )
            matters = dynamicText("One small step is enough.", russian: "Достаточно одного простого шага.")
            if actionThemes.contains(.hydration) || actionThemes.contains(.saunaHeat) {
                next = dynamicText("Take the simple step.", russian: "Сделайте один простой шаг.")
                avoid = dynamicText("Do not overcomplicate it.", russian: "Без лишних усложнений.")
            }
        }

        return HumanStory(
            title: humanStory.title,
            whatHappened: happened,
            whatMattersNow: matters,
            whatToDoNext: next,
            whatToAvoid: avoid
        )
    }

    private static func finalCopyReasonCanRestateHero(_ reason: CoachFinalStoryReason) -> Bool {
        switch reason.kind {
        case .time, .tomorrow, .sleep:
            return true
        default:
            return false
        }
    }

    private static func finalCopyFallbackReason(
        from reasons: [CoachFinalStoryReason],
        avoiding seenText: Set<String>,
        themeCounts: [FinalCopyTheme: Int]
    ) -> CoachFinalStoryReason? {
        reasons.first { reason in
            let text = finalCopyNormalizedText(reason.text.resolved)
            let themes = finalCopyThemes(for: reason)
            return !text.isEmpty &&
                !finalCopyTextOverlapsAny(text, in: seenText) &&
                !finalCopyWouldOverRepeat(themes, themeCounts: themeCounts)
        } ?? reasons.first { reason in
            !finalCopyNormalizedText(reason.text.resolved).isEmpty
        }
    }

    private static func finalCopyIsCritical(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guidance.priority.strength == .critical ||
            guidance.priority.severity == .critical ||
            owner == .activeActivity ||
            hasSevereHydrationOrHeatContext(input: input) && activitySoon(in: input, matching: { isHeatActivity($0) })
    }

    private static func finalCopyWouldOverRepeat(
        _ themes: Set<FinalCopyTheme>,
        themeCounts: [FinalCopyTheme: Int]
    ) -> Bool {
        themes.contains { (themeCounts[$0] ?? 0) >= 2 }
    }

    private static func finalCopyAddThemes(
        _ themes: Set<FinalCopyTheme>,
        to counts: inout [FinalCopyTheme: Int]
    ) {
        for theme in themes {
            counts[theme, default: 0] += 1
        }
    }

    private static func finalCopyConcreteActionIsNecessary(
        _ action: CoachSupportActionV3,
        critical: Bool
    ) -> Bool {
        let text = "\(action.title) \(action.subtitle)".lowercased()
        let hasAmount = text.contains("ml") || text.contains("мл") || text.range(of: #"\d"#, options: .regularExpression) != nil

        switch action.type {
        case .hydrateBeforeSession:
            return critical || hasAmount
        case .lightFueling, .recoveryMeal, .startRecoveryNutrition, .electrolyteRecovery:
            return critical || hasAmount
        case .controlIntensity, .cooldown, .mobilityPrep, .sleepPriority:
            return true
        default:
            return hasAmount
        }
    }

    private static func finalCopyIsGenericHydrationOrFuelAction(_ action: CoachSupportActionV3) -> Bool {
        switch action.type {
        case .steadyHydration, .rehydrateGradually, .sustainEnergy:
            return true
        default:
            return false
        }
    }

    private static func finalCopyThemes(for reason: CoachFinalStoryReason) -> Set<FinalCopyTheme> {
        var themes = finalCopyThemes(in: reason.text.resolved)
        switch reason.kind {
        case .hydration:
            themes.insert(.hydration)
        case .fuel:
            themes.insert(.fuel)
        case .recovery:
            themes.insert(.recovery)
        case .sleep:
            themes.insert(.sleep)
        case .tomorrow:
            themes.insert(.tomorrowDemand)
        case .time:
            themes.insert(.upcomingActivity)
        case .training:
            themes.insert(.upcomingActivity)
        case .constraint:
            themes.insert(.intensityControl)
        case .stability:
            themes.insert(.flexibility)
        }
        return themes
    }

    private static func finalCopyThemes(for action: CoachSupportActionV3) -> Set<FinalCopyTheme> {
        var themes = finalCopyThemes(in: "\(action.title) \(action.subtitle)")
        switch action.type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            themes.insert(.hydration)
        case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal, .keepDigestionLight:
            themes.insert(.fuel)
        case .controlIntensity:
            themes.insert(.intensityControl)
        case .cooldown:
            themes.insert(.cooldown)
        case .mobilityPrep, .lightRecoveryMovement:
            themes.insert(.mobility)
        case .sleepPriority, .downshiftNervousSystem, .breathingReset:
            themes.insert(.sleep)
        case .stayConsistent:
            themes.insert(.flexibility)
        }
        return themes
    }

    private static func finalCopyThemes(in value: String) -> Set<FinalCopyTheme> {
        let text = finalCopyNormalizedText(value)
        guard !text.isEmpty else { return [] }

        var themes = Set<FinalCopyTheme>()
        func containsAny(_ fragments: [String]) -> Bool {
            fragments.contains { text.contains($0) }
        }

        if containsAny(["water", "hydrate", "hydration", "drink", "sip", "ml", "вода", "воды", "водой", "пей", "выпей", "глот", "мл"]) {
            themes.insert(.hydration)
        }
        if containsAny(["food", "fuel", "fueling", "nutrition", "calorie", "carb", "meal", "eat", "еда", "еды", "питание", "углевод", "калор", "прием пищи"]) {
            themes.insert(.fuel)
        }
        if containsAny(["protein", "белок"]) {
            themes.insert(.protein)
        }
        if containsAny(["recovery", "recover", "readiness", "восстанов", "готовност"]) {
            themes.insert(.recovery)
        }
        if containsAny(["sleep", "сон", "сна"]) {
            themes.insert(.sleep)
        }
        if containsAny(["completed", "done", "logged", "already did", "main load", "main work", "заверш", "выполн", "уже сдел", "нагрузка уже", "главная нагрузка"]) {
            themes.insert(.completedLoad)
        }
        if containsAny(["coming soon", "upcoming", "next effort", "next planned", "before the start", "start", "скоро", "следующ", "перед старт", "до сауны"]) {
            themes.insert(.upcomingActivity)
        }
        if containsAny(["tomorrow", "завтра", "завтраш"]) {
            themes.insert(.tomorrowDemand)
        }
        if containsAny(["flexible", "flexibility", "stay with the plan", "keep the plan", "no rush", "nothing urgent", "plan", "гибк", "план", "спеш", "срочно"]) {
            themes.insert(.flexibility)
        }
        if containsAny(["intensity", "effort", "easy", "light", "hard", "pace", "tempo", "интенсив", "усили", "легк", "лёгк", "тяжел", "тяжёл", "темп"]) {
            themes.insert(.intensityControl)
        }
        if containsAny(["sauna", "heat", "сауна", "сауны", "сауну", "жар"]) {
            themes.insert(.saunaHeat)
        }
        if containsAny(["cool down", "cooldown", "замин"]) {
            themes.insert(.cooldown)
        }
        if containsAny(["mobility", "stretch", "мобиль", "растяж"]) {
            themes.insert(.mobility)
        }

        return themes
    }

    private static func finalCopyNormalizedText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".。!?！？"))
    }

    private static func finalCopyTextOverlapsAny(_ value: String, in existing: Set<String>) -> Bool {
        existing.contains { finalCopyTextsOverlap(value, $0) }
    }

    private static func finalCopyTextsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let left = finalCopyNormalizedText(lhs)
        let right = finalCopyNormalizedText(rhs)
        guard left.count >= 12, right.count >= 12 else {
            return left == right
        }
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func saunaHydrationSupportActions(
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        [
            supportAction(
                .hydrateBeforeSession,
                title: localizedAction(
                    english: "Sip 300-500 ml",
                    russian: "Выпейте 300-500 мл небольшими глотками"
                ),
                subtitle: localizedAction(
                    english: "Small sips are enough before sauna",
                    russian: "Перед сауной достаточно небольших глотков"
                ),
                colorFamily: .hydration
            ),
            supportAction(
                .controlIntensity,
                title: localizedAction(
                    english: "Keep sauna light",
                    russian: "Сократите сауну до лёгкого блока"
                ),
                subtitle: localizedAction(
                    english: "Shorter and easier is the win today",
                    russian: "Сегодня лучше короче и легче"
                ),
                colorFamily: .activity
            ),
            supportAction(
                .steadyHydration,
                title: localizedAction(
                    english: "Do not chug water",
                    russian: "Не догоняйте воду одним большим объёмом"
                ),
                subtitle: localizedAction(
                    english: "One large drink will not help much",
                    russian: "Один большой объём мало поможет"
                ),
                colorFamily: colorFamily
            )
        ]
    }

    private static func filterStableDayHydrationFuelActions(
        _ actions: [CoachSupportActionV3],
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [CoachSupportActionV3] {
        guard owner == .stableOverview || owner == .readiness else {
            return actions
        }
        guard input.dayPriorityModel.tomorrowDemand != .hard,
              activeActivity(input: input, guidance: guidance) == nil else {
            return actions
        }

        return actions.filter { action in
            guard let signalKind = supportSignalKind(for: action.type) else { return true }
            return signalKind != .hydration && signalKind != .fuel
        }
    }

    private static func filterSignalDuplicatingActions(
        _ actions: [CoachSupportActionV3],
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        supportSignals: [CoachFinalStorySupportSignal]
    ) -> [CoachSupportActionV3] {
        guard owner != .postActivityRecovery && owner != .recovery else {
            return actions
        }

        let visibleSignalKinds = Set(supportSignals.map(\.kind))

        return actions.filter { action in
            guard let signalKind = supportSignalKind(for: action.type),
                  visibleSignalKinds.contains(signalKind) else {
                return true
            }

            return signalActionCanOwnMainSlot(
                action.type,
                signalKind: signalKind,
                owner: owner,
                input: input,
                guidance: guidance
            )
        }
    }

    private static func supportSignalKind(
        for actionType: CoachSupportActionTypeV3
    ) -> CoachFinalStorySupportSignal.Kind? {
        switch actionType {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return .hydration
        case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal:
            return .fuel
        case .sleepPriority:
            return .sleep
        case .breathingReset,
             .mobilityPrep,
             .keepDigestionLight,
             .controlIntensity,
             .cooldown,
             .lightRecoveryMovement,
             .downshiftNervousSystem,
             .stayConsistent:
            return nil
        }
    }

    private static func signalActionCanOwnMainSlot(
        _ actionType: CoachSupportActionTypeV3,
        signalKind: CoachFinalStorySupportSignal.Kind,
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        switch signalKind {
        case .hydration:
            return owner == .hydration ||
                actionType == .electrolyteRecovery ||
                activeActivity(input: input, guidance: guidance) != nil ||
                (guidance.priority.limiter == .hydration && guidance.priority.strength == .critical) ||
                activitySoon(in: input) { activity in
                    let kind = CoachActivityContextResolverV3.kind(for: activity)
                    let load = CoachActivityContextResolverV3.load(for: activity)
                    return kind == .heat || load == .high
                }

        case .fuel:
            return owner == .fuel ||
                activeActivity(input: input, guidance: guidance) != nil ||
                (guidance.priority.limiter == .fueling && guidance.priority.strength == .critical) ||
                activitySoon(in: input) { activity in
                    let kind = CoachActivityContextResolverV3.kind(for: activity)
                    let load = CoachActivityContextResolverV3.load(for: activity)
                    return kind == .endurance || load == .high
                }

        case .recovery, .sleep, .activity:
            return true
        }
    }

    private static func mergeActions(
        _ primary: [CoachSupportActionV3],
        _ secondary: [CoachSupportActionV3],
        avoiding heroTexts: [String]
    ) -> [CoachSupportActionV3] {
        dedupedActions(primary + secondary, avoiding: heroTexts)
    }

    private static func dedupedActions(
        _ actions: [CoachSupportActionV3],
        avoiding heroTexts: [String]
    ) -> [CoachSupportActionV3] {
        let normalizedHero = Set(heroTexts.map(normalizedActionText))
        var seen = Set<String>()
        var result: [CoachSupportActionV3] = []

        for action in actions {
            let titleKey = normalizedActionText(action.title)
            let subtitleKey = normalizedActionText(action.subtitle)
            guard !titleKey.isEmpty else { continue }
            guard !actionTextOverlapsAny(titleKey, in: normalizedHero) else { continue }
            guard subtitleKey.isEmpty || !actionTextOverlapsAny(subtitleKey, in: normalizedHero) else { continue }
            guard seen.insert("\(action.type)-\(titleKey)").inserted else { continue }
            guard !result.contains(where: { actionTextsOverlap(normalizedActionText($0.title), titleKey) }) else { continue }
            result.append(action)
        }

        return result
    }

    private static func actionTextOverlapsAny(_ value: String, in existing: Set<String>) -> Bool {
        existing.contains { actionTextsOverlap(value, $0) }
    }

    private static func actionTextsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedActionText(lhs)
        let right = normalizedActionText(rhs)
        guard left.count >= 12, right.count >= 12 else {
            return left == right
        }
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func recoverySupportActions(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        guard completedLoadShouldDriveRecovery(input: input, guidance: guidance) else { return [] }

        let activity = completedActivity(input: input, guidance: guidance)
        let kind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }
        let duration = activity?.effectiveDurationMinutes ?? input.dayContext.completedActivityVolumeMinutes
        let highLoad = duration >= 75 ||
            input.dayContext.completedTrainingStressScore >= 2 ||
            input.actualLoad.activeCalories >= 750
        let veryHighLoad = duration >= 150 ||
            input.dayContext.completedTrainingStressScore >= 4 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
        let evening = localHour(input.now) >= 18
        let nutritionNeedsAction = recoveryNutritionNeedsSupport(input)
        let hydrationNeedsAction = recoveryHydrationNeedsSupport(input) ||
            kind == .some(.endurance) && highLoad

        var actions: [CoachSupportActionV3] = []

        let completedName = activity.map { recoveryActivityName($0).english } ?? "training"
        let isRide = activity.map { activity in
            let text = "\(activity.title) \(activity.type)".lowercased()
            return text.contains("ride") || text.contains("cycl") || text.contains("bike")
        } == true
        let isStrength = kind == .some(.workout) && activity.map { activity in
            let text = "\(activity.title) \(activity.type)".lowercased()
            return text.contains("strength") || text.contains("upper") || text.contains("gym") || text.contains("lift")
        } == true

        actions.append(
            supportAction(
                .cooldown,
                title: localizedAction(english: isStrength ? "Easy cooldown walk" : "Cooldown walk", russian: "Спокойная заминка"),
                subtitle: localizedAction(english: "Keep it easy and let the body downshift", russian: "Держите легко и дайте телу замедлиться"),
                colorFamily: colorFamily
            )
        )

        actions.append(
            supportAction(
                kind == .some(.workout) ? .mobilityPrep : .lightRecoveryMovement,
                title: localizedAction(english: isStrength ? "Mobility work" : "Light stretching", russian: isStrength ? "Мобильность" : "Легкая растяжка"),
                subtitle: localizedAction(english: "Restore range without adding load", russian: "Верните подвижность без новой нагрузки"),
                colorFamily: colorFamily
            )
        )

        if nutritionNeedsAction && highLoad {
            actions.append(
                supportAction(
                    .recoveryMeal,
                    title: localizedAction(english: isStrength ? "Protein feeding" : "Recovery meal with protein and carbs", russian: isStrength ? "Белковый прием пищи" : "Восстановительный прием пищи"),
                    subtitle: localizedAction(english: "Help absorb the completed \(completedName)", russian: "Помогите организму усвоить выполненную нагрузку"),
                    colorFamily: .fuel
                )
            )
        }

        if hydrationNeedsAction {
            actions.append(
                supportAction(
                    .rehydrateGradually,
                    title: localizedAction(english: isRide || kind == .some(.endurance) ? "500 ml hydration" : "Hydrate gradually", russian: "Пейте постепенно"),
                    subtitle: localizedAction(english: "Sip over the next hour instead of catching up fast", russian: "Пейте в течение часа, без резкой компенсации"),
                    colorFamily: .hydration
                )
            )
        }

        if evening || veryHighLoad || noRemainingTrainingToday(input) {
            actions.append(
                supportAction(
                    .sleepPriority,
                    title: localizedAction(english: "Aim for 7-8 hours sleep", russian: "Постарайтесь обеспечить 7-8 часов сна"),
                    subtitle: localizedAction(english: "Keep the evening easy so recovery can land", russian: "Сделайте вечер спокойным, чтобы восстановление сработало"),
                    colorFamily: colorFamily
                )
            )
        }

        if veryHighLoad {
            actions.append(
                supportAction(
                    .controlIntensity,
                    title: localizedAction(english: "No extra hard effort", russian: "Без еще одной тяжелой нагрузки"),
                    subtitle: localizedAction(english: "Do not stack more intensity onto today", russian: "Не добавляйте сегодня еще интенсивности"),
                    colorFamily: .warning
                )
            )
        }

        return actions
    }

    private static func isGenericRecoveryFallbackAction(_ action: CoachSupportActionV3) -> Bool {
        let title = normalizedActionText(action.title)
        return title == "stay relaxed" ||
            title == "slow down" ||
            title == "prepare for sleep" ||
            title == "keep the evening calm" ||
            title == "wind down now" ||
            title == "settle down"
    }

    private static func recoveryNutritionNeedsSupport(_ input: CoachInputSnapshot) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.nutritionContext?.caloriesGoal ?? input.brain.fullDayGoals.calories
        let protein = input.nutritionContext?.proteinCurrent ?? input.brain.metrics.protein
        let proteinGoal = input.nutritionContext?.proteinGoal ?? input.brain.fullDayGoals.protein

        return ratio(current: calories, goal: calorieGoal) < 0.95 ||
            ratio(current: protein, goal: proteinGoal) < 0.95
    }

    private static func recoveryHydrationNeedsSupport(_ input: CoachInputSnapshot) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters

        return ratio(current: water, goal: waterGoal) < 0.85 ||
            input.brain.hydration == .depleted ||
            input.brain.hydration == .behind
    }

    private static func supportAction(
        _ type: CoachSupportActionTypeV3,
        title: String,
        subtitle: String,
        colorFamily: CoachFinalStoryColorFamily
    ) -> CoachSupportActionV3 {
        CoachSupportActionV3(
            type: type,
            icon: supportActionIcon(for: type),
            title: title,
            subtitle: subtitle,
            color: supportActionColor(for: type, fallback: colorFamily.color),
            actionProvenance: .recoveryPolicy
        )
    }

    private static func supportActionIcon(for type: CoachSupportActionTypeV3) -> String {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return "drop.fill"
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return "fork.knife"
        case .sleepPriority:
            return "moon.fill"
        case .cooldown, .mobilityPrep, .lightRecoveryMovement:
            return "figure.cooldown"
        case .breathingReset, .downshiftNervousSystem:
            return "wind"
        case .controlIntensity:
            return "speedometer"
        case .stayConsistent:
            return "checkmark.circle.fill"
        }
    }

    private static func supportActionColor(
        for type: CoachSupportActionTypeV3,
        fallback: Color
    ) -> Color {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return CoachPalette.hydration
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return CoachPalette.fueling
        case .controlIntensity:
            return CoachPalette.warning
        default:
            return fallback
        }
    }

    private static func localizedAction(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func normalizedActionText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func completedLoadShouldDriveRecovery(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if recentlyCompletedSeriousTraining(input: input, guidance: guidance) != nil {
            return true
        }

        if latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance),
           !objectiveStrainIsHigh(input) {
            return false
        }

        return input.dayContext.completedTrainingStressScore >= 2 ||
            objectiveStrainIsHigh(input)
    }

    private static func latestCompletedActivityIsRecoveryOnly(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if let activity = guidance.priority.activity,
           activity.isCompleted,
           isRecoveryActivityV4(activity),
           !isSeriousTraining(activity) {
            return true
        }

        guard let activity = input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .sorted(by: { $0.date > $1.date })
            .first else {
            return false
        }

        return isRecoveryActivityV4(activity) && !isSeriousTraining(activity)
    }

    private static func recoveryOwnerIsIndependentlyJustified(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if recentlyCompletedSeriousTraining(input: input, guidance: guidance) != nil {
            return true
        }
        if lowRecoveryOrReadiness(input) {
            return true
        }
        if input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5 {
            return true
        }
        if input.dayContext.completedTrainingStressScore >= 2 {
            return true
        }
        if input.dayContext.hasMeaningfulLoadCompleted && !latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance) {
            return true
        }
        return false
    }

    private static func objectiveStrainIsHigh(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.completedTrainingStressScore >= 4 ||
            input.brain.metrics.activeCalories >= 1_200 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.exerciseMinutes ?? 0) >= 150 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
    }

    private static func activeActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if case .active(let activity, _) = guidance.phase,
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        if let activity = guidance.priority.activity,
           isActive(activity, now: input.now),
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.dayContext.allActivities,
            selectedDate: input.selectedDate,
            now: input.now,
            brain: input.brain
        )
        if let activity = activityContext.activeActivity,
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        if let manualActive = input.dayContext.allActivities.first(where: { activity in
            activity.source == "today" &&
                isActive(activity, now: input.now) &&
                !isCompletedDuplicate(activity, in: input)
        }) {
            return manualActive
        }

        return nil
    }

    private static func isActive(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
        return activity.date <= now && now <= end
    }

    private static func isCompletedDuplicate(
        _ activity: PlannedActivity,
        in input: CoachInputSnapshot
    ) -> Bool {
        input.dayContext.completedActivities.contains { completed in
            guard completed.id != activity.id else { return false }
            let sameTitle = completed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activity.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            let sameType = completed.type.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activity.type.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            let startDelta = abs(completed.date.timeIntervalSince(activity.date))
            let durationDelta = abs(completed.effectiveDurationMinutes - activity.effectiveDurationMinutes)

            return sameTitle && sameType && startDelta <= 15 * 60 && durationDelta <= 10
        }
    }

    private static func activeSessionAssessment(
        activity: PlannedActivity,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> ActiveSessionAssessment {
        let highLoad = dayAlreadyHasHighLoad(input)
        let criticalReadiness = criticalActiveReadinessWarning(guidance)
        let lateEvening = localHour(input.now) >= 20
        let lightRecovery = isLightRecoveryActivity(activity)
        let compromised = input.brain.readiness == .low ||
            input.brain.readiness == .compromised ||
            input.brain.recovery == .compromised ||
            input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 60 ||
            input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5

        if (highLoad || criticalReadiness) && lateEvening {
            return .activeSleepRisk
        }
        if (highLoad || criticalReadiness) && lightRecovery {
            return .activeRecoveryOnly
        }
        if highLoad || criticalReadiness {
            return .activeAfterOverload
        }
        if compromised || input.dayContext.completedTrainingStressScore >= 2 {
            return .activeWithCaution
        }
        return .normalActive
    }

    private static func dayAlreadyHasHighLoad(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.hasMeaningfulLoadCompleted ||
            input.dayContext.completedActivityVolumeMinutes >= 150 ||
            input.dayContext.completedTrainingStressScore >= 4 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.exerciseMinutes ?? 0) >= 150 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
    }

    private static func criticalActiveReadinessWarning(_ guidance: CoachGuidanceV3) -> Bool {
        guidance.priority.focus == .trainingReadinessWarning &&
            guidance.priority.strength == .critical
    }

    private static func isLightRecoveryActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type.contains("walk") ||
            type.contains("stretch") ||
            type.contains("mobility") ||
            type.contains("yoga") ||
            type.contains("recovery") {
            return true
        }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        return kind == .recovery || load == .low
    }

    private static func eveningSleepRecoveryShouldLead(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        completedLoadShouldDriveRecovery(input: input, guidance: guidance) &&
            noRemainingTrainingToday(input)
    }

    private static func noRemainingTrainingToday(_ input: CoachInputSnapshot) -> Bool {
        let remainingContextActivity = input.dayContext.upcomingActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                CoachDayActivityContextResolver.isCoachRelevant(activity)
        }

        return input.dayContext.upcomingTrainingActivities.allSatisfy { $0.isCompleted || $0.isSkipped } &&
            !remainingContextActivity
    }

    private static func completedActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let activity = recentlyCompletedSeriousTraining(input: input, guidance: guidance) {
            return activity
        }

        if let activity = guidance.priority.activity, activity.isCompleted, !isRecoveryActivityV4(activity) {
            return activity
        }
        return input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .filter { CoachDayActivityContextResolver.isCoachRelevant($0) && !isRecoveryActivityV4($0) }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func latestCompletedActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let activity = guidance.priority.activity, activity.isCompleted {
            return activity
        }

        if case .recovering(let activity, _, _) = guidance.phase,
           activity.isCompleted {
            return activity
        }

        return input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .sorted { $0.date > $1.date }
            .first
    }

    private static func completedLoadText(
        activity: PlannedActivity,
        input: CoachInputSnapshot
    ) -> CoachFinalStoryText {
        let activityName = recoveryActivityName(activity).english.lowercased()
        let russianActivityName = recoveryActivityName(activity).russian
        let duration = durationLoadDescription(minutes: activity.effectiveDurationMinutes).english
        let russianDuration = durationLoadDescription(minutes: activity.effectiveDurationMinutes).russian
        let load = input.brain.metrics.activeCalories >= 1_200 ||
            activity.effectiveDurationMinutes >= 150 ||
            CoachActivityContextResolverV3.kind(for: activity) == .endurance && activity.effectiveDurationMinutes >= 120 ||
            input.dayContext.completedTrainingStressScore >= 4
            ? "main training load"
            : "main training stimulus"
        let russianLoad = load == "main training load" ? "основную тренировочную нагрузку" : "основной тренировочный стимул"

        return formattedText(
            "coach.final.human.recovery.completedLoad",
            fallback: "Today's %@ %@ already delivered the %@.",
            russianFallback: "Сегодняшняя %@ %@ уже дала %@.",
            parameters: [duration, activityName, load],
            russianParameters: [russianDuration, russianActivityName, russianLoad]
        )
    }

    private static func recoveryActivityName(_ activity: PlannedActivity) -> (english: String, russian: String) {
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch type {
        case "cycling", "bike", "biking", "ride":
            return ("cycling session", "велотренировка")
        case "running", "run":
            return ("running session", "беговая тренировка")
        case "walking", "walk":
            return ("walk", "прогулка")
        case "strength", "gym", "lifting":
            return ("strength session", "силовая тренировка")
        default:
            let title = displayName(activity).trimmingCharacters(in: .whitespacesAndNewlines)
            let english = title.localizedCaseInsensitiveContains("session") ? title : "\(title) session"
            return (english, "тренировка")
        }
    }

    private static func durationLoadDescription(minutes: Int) -> (english: String, russian: String) {
        if minutes >= 180 {
            return ("\(minutes / 60)+ hour", "\(minutes / 60)+ часа")
        }
        if minutes >= 120 {
            return ("\(minutes / 60) hour", "\(minutes / 60) часа")
        }
        if minutes >= 75 {
            return ("\(minutes) minute", "\(minutes)-минутная")
        }
        return ("completed", "завершенная")
    }

    private static func upcomingActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if case .preparing(let activity, _, _) = guidance.phase,
           !activity.isCompleted,
           !activity.isSkipped,
           activity.date > input.now,
           CoachDayActivityContextResolver.isCoachRelevant(activity) {
            return activity
        }

        if let activity = guidance.priority.activity,
           !activity.isCompleted,
           !activity.isSkipped,
           activity.date > input.now,
           CoachDayActivityContextResolver.isCoachRelevant(activity) {
            return activity
        }
        return nil
    }

    private static func recoveryLooksStrong(_ input: CoachInputSnapshot) -> Bool {
        input.recoveryContext.recoveryPercent >= 85 &&
            input.recoveryContext.sleepHours >= 7.0 &&
            (input.brain.recovery == .strong || input.brain.readiness == .good)
    }

    private static func displayName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? "training" : type
    }

    private static func tomorrowProtectionActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if guidance.priority.focus == .tomorrowPlanRisk,
           let activity = guidance.priority.activity,
           !activity.isSkipped {
            return activity
        }

        if guidance.priority.focus == .tomorrowPlanRisk,
           let selected = selectedCoachActivity(input: input, guidance: guidance) {
            return selected
        }

        guard input.dayPriorityModel.tomorrowDemand == .hard else { return nil }
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.selectedDate) else {
            return nil
        }
        let tomorrowActivities = input.plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: tomorrow) && !activity.isSkipped
        }
        return CoachTomorrowDemandResolver.resolve(activities: tomorrowActivities).primaryTrainingActivity
    }

    private static func enduranceDisplayLabels(for activity: PlannedActivity) -> (english: String, russian: String) {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("run") || text.contains("running") {
            return ("run", "бег")
        }
        if text.contains("cycling") ||
            text.contains("cycl") ||
            text.contains("bike") ||
            text.contains("ride") {
            return ("ride", "заезд")
        }
        if text.contains("swim") || text.contains("swimming") {
            return ("swim", "заплыв")
        }
        return ("endurance session", "длинный блок")
    }

    private static func specificText(_ value: String?) -> String? {
        guard !WeekFitCurrentLocale().identifier.hasPrefix("ru") else { return nil }
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        guard !isGenericActionText(text) else { return nil }
        return text
    }

    private static func isGenericActionText(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        return normalized == "rebuild the basics" ||
            normalized.contains("rebuild the basics") ||
            normalized == "support recovery" ||
            normalized == "support the next block" ||
            normalized == "hydration supports this story" ||
            normalized == "fuel supports this story" ||
            normalized == "nutrition supports this story" ||
            normalized == "sleep is part of the decision" ||
            normalized == "keep the routine" ||
            normalized == "stay consistent"
    }

    private static func isDuplicateAction(_ first: String, _ second: String) -> Bool {
        let lhs = first.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhs = second.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private static func lowercasedFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private static func dynamicText(_ english: String, russian: String) -> CoachFinalStoryText {
        text("", english, russian)
    }

    private static func formattedText(
        _ key: String,
        fallback: String,
        russianFallback: String,
        parameters: [String],
        russianParameters: [String]
    ) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: key,
            fallback: String(format: fallback, arguments: parameters.map { $0 as CVarArg }),
            russianFallback: String(format: russianFallback, arguments: russianParameters.map { $0 as CVarArg }),
            parameters: parameters,
            russianParameters: russianParameters
        )
    }

    private static func finalDecisionContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalDecisionContext {
        let selected = selectedCoachActivity(input: input, guidance: guidance)
        let selectedUpNext = selected.flatMap { activity -> PlannedActivity? in
            guard !activity.isCompleted,
                  !activity.isSkipped,
                  activity.date > input.now else {
                return nil
            }
            return activity
        }

        return CoachFinalDecisionContext(
            selectedCoachActivity: selected,
            selectedUpNext: selectedUpNext,
            hasFutureActivityContext: selectedUpNext != nil,
            hasTomorrowDemand: input.dayPriorityModel.tomorrowDemand != .none,
            completedLoadMinutes: input.dayContext.completedActivityVolumeMinutes,
            completedTrainingStress: input.dayContext.completedTrainingStressScore,
            timeOfDay: finalDecisionTimeOfDay(input.now)
        )
    }

    private static func selectedCoachActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.dayContext.allActivities,
            selectedDate: input.selectedDate,
            now: input.now,
            brain: input.brain
        )

        if let active = activityContext.activeActivity,
           !isCompletedDuplicate(active, in: input),
           CoachDayActivityContextResolver.isCoachRelevant(active) {
            return active
        }

        if let manualActive = input.dayContext.allActivities.first(where: { activity in
            activity.source == "today" &&
                isActive(activity, now: input.now) &&
                !isCompletedDuplicate(activity, in: input) &&
                CoachDayActivityContextResolver.isCoachRelevant(activity)
        }) {
            return manualActive
        }

        if let activity = guidance.priority.activity,
           !activity.isSkipped,
           CoachDayActivityContextResolver.isCoachRelevant(activity) {
            return activity
        }

        if let preparing = activityContext.preparingActivity,
           CoachDayActivityContextResolver.isCoachRelevant(preparing) {
            return preparing
        }

        if let recent = activityContext.recentlyCompletedActivity,
           CoachDayActivityContextResolver.isCoachRelevant(recent) {
            return recent
        }

        switch guidance.phase {
        case .active(let activity, _):
            return !activity.isSkipped && CoachDayActivityContextResolver.isCoachRelevant(activity) ? activity : nil
        case .preparing(let activity, _, _):
            return !activity.isSkipped && CoachDayActivityContextResolver.isCoachRelevant(activity) ? activity : nil
        case .recovering(let activity, _, _):
            return !activity.isSkipped && CoachDayActivityContextResolver.isCoachRelevant(activity) ? activity : nil
        case .stable:
            return nil
        }
    }

    private static func finalDecisionTimeOfDay(_ date: Date) -> CoachFinalDecisionTimeOfDay {
        switch localHour(date) {
        case 0..<5:
            return .night
        case 5..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        default:
            return .lateEvening
        }
    }

    private static func finalStoryReasons(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        context: CoachFinalDecisionContext
    ) -> [CoachFinalStoryReason] {
        var reasons: [CoachFinalStoryReason] = []

        func append(
            _ kind: CoachFinalStoryReason.Kind,
            _ english: String,
            _ russian: String,
            icon: String,
            colorFamily: CoachFinalStoryColorFamily
        ) {
            guard reasons.count < 3 else { return }
            reasons.append(
                CoachFinalStoryReason(
                    kind: kind,
                    text: dynamicText(english, russian: russian),
                    icon: icon,
                    colorFamily: colorFamily
                )
            )
        }

        switch owner {
        case .stableOverview, .readiness:
            if input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 65 ||
                input.brain.recovery == .compromised ||
                input.brain.sleep == .short ||
                input.brain.sleep == .veryShort {
                append(.sleep, "Sleep or recovery is limiting the day.", "Сон или восстановление ограничивают день.", icon: "moon.fill", colorFamily: .recovery)
            } else {
                append(.recovery, "Recovery is within the normal range.", "Восстановление в обычном диапазоне.", icon: "heart.fill", colorFamily: .recovery)
            }

            if context.hasFutureActivityContext {
                append(.time, "There is enough room before the next important effort.", "До следующей важной нагрузки достаточно времени.", icon: "clock.fill", colorFamily: .ready)
            } else if context.hasTomorrowDemand {
                append(.tomorrow, "Tomorrow has a meaningful demand, but nothing needs forcing now.", "Завтра есть значимая нагрузка, но сейчас ничего не нужно форсировать.", icon: "calendar", colorFamily: .activity)
            } else {
                append(.stability, "No immediate demand is shaping the day.", "Сейчас день не задает срочных требований.", icon: "checkmark.seal.fill", colorFamily: .stable)
            }

            append(.constraint, "Nothing urgent needs changing.", "Срочно ничего менять не нужно.", icon: "shield.fill", colorFamily: .stable)

        case .activityPreparation:
            if let activity = context.selectedUpNext,
               isHeatActivity(activity) {
                let minutes = minutesUntil(activity, from: input.now)
                append(
                    .time,
                    minutes.map { $0 <= 30 } == true ? "Sauna starts in less than half an hour." : "Sauna is still ahead today.",
                    minutes.map { $0 <= 30 } == true ? "До сауны осталось меньше получаса." : "Сауна еще впереди сегодня.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
                append(.hydration, "Water is still low today.", "Воды сегодня пока мало.", icon: "drop.fill", colorFamily: .hydration)
                if input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 7 {
                    append(.sleep, "Sleep was shorter than usual.", "Сон был короче обычного.", icon: "moon.fill", colorFamily: .recovery)
                } else {
                    append(.training, "A lighter sauna will cost less.", "Легкая сауна заберет меньше.", icon: "flame.fill", colorFamily: .activity)
                }
            } else if let activity = context.selectedUpNext {
                let minutes = minutesUntil(activity, from: input.now)
                let labels = enduranceDisplayLabels(for: activity)
                append(
                    .time,
                    minutes.map { "\(labels.english.capitalized) starts in about \($0) minutes." } ?? "\(labels.english.capitalized) is still ahead today.",
                    minutes.map { "\(labels.russian.capitalized) начнётся примерно через \($0) минут." } ?? "\(labels.russian.capitalized) ещё впереди сегодня.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
                append(.training, "The biggest training load is still ahead.", "Главная тренировочная нагрузка ещё впереди.", icon: "figure.run", colorFamily: .activity)
                append(.constraint, "Arriving fresh matters more than adding activity now.", "Сейчас важнее выйти свежим, чем добавить активность.", icon: "figure.cooldown", colorFamily: .warning)
            } else {
                append(.stability, "No selected activity needs special prep.", "Выбранной активности не нужна особая подготовка.", icon: "checkmark.seal.fill", colorFamily: .stable)
                append(.recovery, "Recovery and day stability matter most right now.", "Сейчас важнее восстановление и стабильность дня.", icon: "heart.fill", colorFamily: .recovery)
                append(.constraint, "There is no rush to prepare.", "Спешить с подготовкой не нужно.", icon: "shield.fill", colorFamily: .stable)
            }

        case .activeActivity, .pacingExecution, .sustainableExecution:
            append(.training, "The current session is already creating load.", "Текущая сессия уже создает нагрузку.", icon: "figure.run", colorFamily: .activity)
            append(.constraint, "Effort control protects the rest of the day.", "Контроль усилия защищает остаток дня.", icon: "speedometer", colorFamily: .warning)
            append(.recovery, "Recovery depends on finishing with reserve.", "Восстановление зависит от запаса на финише.", icon: "heart.fill", colorFamily: .recovery)

        case .fuelingDuringActivity:
            append(.training, "Energy expenditure is already high.", "Расход энергии уже высокий.", icon: "flame.fill", colorFamily: .activity)
            append(.fuel, "Fuel intake is behind the workload.", "Питание отстаёт от нагрузки.", icon: "bolt.fill", colorFamily: .fuel)
            append(.time, "The remaining work still needs usable energy.", "Оставшейся работе нужна доступная энергия.", icon: "clock.fill", colorFamily: .ready)

        case .hydrationExecution:
            append(.hydration, "Fluid intake is behind the session demand.", "Воды меньше, чем требует сессия.", icon: "drop.fill", colorFamily: .hydration)
            append(.training, "The workload is long enough for hydration to affect quality.", "Сессия достаточно длинная, чтобы вода влияла на качество.", icon: "figure.run", colorFamily: .activity)
            append(.constraint, "Catching up later is harder than steady drinking now.", "Позже догонять сложнее, чем пить ровно сейчас.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)

        case .postActivityRecovery, .recovery:
            append(.training, "The main useful load is already done.", "Основная полезная нагрузка уже выполнена.", icon: "checkmark.circle.fill", colorFamily: .activity)
            append(.recovery, "Recovery matters more than another hard effort.", "Восстановление важнее еще одной тяжелой нагрузки.", icon: "heart.fill", colorFamily: .recovery)
            append(.constraint, "Extra intensity is unlikely to add benefit.", "Дополнительная интенсивность вряд ли даст пользу.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)

        case .tomorrowProtection:
            if let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
                let labels = enduranceDisplayLabels(for: activity)
                append(
                    .tomorrow,
                    "Tomorrow's \(labels.english) is the higher-priority demand.",
                    "Завтрашний \(labels.russian) — более приоритетная нагрузка.",
                    icon: "calendar",
                    colorFamily: .activity
                )
            } else {
                append(.tomorrow, "Tomorrow has the higher-priority demand.", "Завтра более приоритетная нагрузка.", icon: "calendar", colorFamily: .activity)
            }
            append(.constraint, "Extra load today can lower readiness.", "Лишняя нагрузка сегодня снизит готовность.", icon: "arrow.down.heart.fill", colorFamily: .warning)
            append(.sleep, "Sleep and recovery set up the next session.", "Сон и восстановление готовят следующую сессию.", icon: "moon.fill", colorFamily: .recovery)

        case .hydration:
            append(.hydration, "Water is low right now.", "Воды сейчас мало.", icon: "drop.fill", colorFamily: .hydration)
            if context.hasFutureActivityContext {
                append(.training, "Do not start dry.", "Не начинайте сухим.", icon: "figure.run", colorFamily: .activity)
            } else {
                append(.constraint, "This is easy to fix now.", "Сейчас это легко поправить.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)
            }
            append(.stability, "Small sips are enough.", "Достаточно небольших глотков.", icon: "checkmark.seal.fill", colorFamily: .stable)

        case .fuel:
            append(.fuel, "Food is low right now.", "Еды сейчас мало.", icon: "bolt.fill", colorFamily: .fuel)
            if context.hasFutureActivityContext {
                append(.training, "The next effort needs usable energy.", "Следующей нагрузке нужна доступная энергия.", icon: "figure.run", colorFamily: .activity)
            } else {
                append(.constraint, "Low fuel makes additional intensity less useful.", "При низкой энергии дополнительная интенсивность менее полезна.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)
            }
            append(.stability, "A simple correction keeps the day steadier.", "Простая коррекция сделает день ровнее.", icon: "checkmark.seal.fill", colorFamily: .stable)
        }

        return Array(reasons.prefix(3))
    }

    private static func coachV4FinalReasons(
        frame: CoachV4DecisionFrame,
        humanStory: HumanStory
    ) -> [CoachFinalStoryReason] {
        var seen = Set([
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ].map(finalCopyNormalizedText))

        var reasons: [CoachFinalStoryReason] = []
        for reason in frame.reasons {
            let normalized = finalCopyNormalizedText(localizedAction(english: reason.english, russian: reason.russian))
            guard !normalized.isEmpty else { continue }
            guard !finalCopyTextOverlapsAny(normalized, in: seen) else { continue }
            seen.insert(normalized)
            reasons.append(
                CoachFinalStoryReason(
                    kind: reason.kind,
                    text: dynamicText(reason.english, russian: reason.russian),
                    icon: reason.icon,
                    colorFamily: reason.colorFamily
                )
            )
            if reasons.count == 3 { break }
        }

        return reasons
    }

    private static func coachV4FinalSupportActions(
        frame: CoachV4DecisionFrame,
        humanStory: HumanStory,
        reasons: [CoachFinalStoryReason],
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        var seen = Set((
            [
                humanStory.title.resolved,
                humanStory.whatHappened.resolved,
                humanStory.whatMattersNow.resolved,
                humanStory.whatToAvoid.resolved
            ] + reasons.map { $0.text.resolved }
        ).map(finalCopyNormalizedText))

        var actions: [CoachSupportActionV3] = []
        for recommendation in frame.actions {
            let title = localizedTitle(recommendation)
            let subtitle = localizedSubtitle(recommendation)
            let normalizedTitle = finalCopyNormalizedText(title)
            let normalizedSubtitle = finalCopyNormalizedText(subtitle)
            guard !normalizedTitle.isEmpty else { continue }
            guard !finalCopyTextOverlapsAny(normalizedTitle, in: seen) else { continue }
            guard normalizedSubtitle.isEmpty || !finalCopyTextOverlapsAny(normalizedSubtitle, in: seen) else { continue }
            seen.insert(normalizedTitle)
            if !normalizedSubtitle.isEmpty {
                seen.insert(normalizedSubtitle)
            }
            actions.append(
                supportAction(
                    recommendation.type,
                    title: title,
                    subtitle: subtitle,
                    colorFamily: colorFamily
                )
            )
            if actions.count == 3 { break }
        }

        return actions
    }

    static func build(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        display: Display
    ) -> CoachFinalStory {
        let decisionContext = finalDecisionContext(input: input, guidance: guidance)
        let owner = resolvedOwner(input: input, guidance: guidance)
        logV4AuditBuilderIn(input: input, guidance: guidance, ownerCandidate: owner)
        let title = titleText(owner: owner, fallback: display.title)
        let subtitle = subtitleText(owner: owner, fallback: display.message)
        let recommendation = recommendationText(owner: owner, fallback: display.recommendation)
        let avoid = avoidText(owner: owner, guidance: guidance)
        let assessment = readinessAssessment(input)

        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            let frame = coachV4DecisionFrame(owner: owner, input: input, guidance: guidance)
            let storyOwner = frame.storyOwner
            let colorFamily = resolvedColorFamily(owner: storyOwner, input: input, guidance: guidance)
            let badge = badgeText(owner: storyOwner, fallback: display.stateLabel)
            let icon = resolvedIcon(owner: storyOwner, fallback: display.icon)
            let humanStory = HumanStory(
                title: frame.hero,
                whatHappened: frame.assessment,
                whatMattersNow: frame.situation,
                whatToDoNext: coachActionText(frame.primaryAction),
                whatToAvoid: frame.avoidance
            )
            let reasons = coachV4FinalReasons(frame: frame, humanStory: humanStory)
            let supportActions = coachV4FinalSupportActions(
                frame: frame,
                humanStory: humanStory,
                reasons: reasons,
                colorFamily: colorFamily
            )
            logV4OwnerNormalization(
                source: "CoachFinalStoryBuilder",
                ownerBefore: owner,
                ownerAfter: storyOwner,
                baseOwner: owner,
                input: input,
                guidance: guidance,
                selected: frame.dayLoadContext.nextImportantActivityToday,
                reasonKinds: reasons.map(\.kind),
                usedFallback: false,
                fallbackSource: "v4Playbook"
            )
            let primaryAction = supportActions.first.map { action in
                CoachFinalStoryAction(
                    title: dynamicText(action.title, russian: action.title),
                    icon: action.icon
                )
            } ?? CoachFinalStoryAction(title: humanStory.whatToDoNext, icon: actionIcon(owner: storyOwner))

            let story = CoachFinalStory(
                owner: storyOwner,
                primaryFocus: guidance.priority.focus,
                titleKey: humanStory.title.key,
                subtitleKey: humanStory.whatHappened.key,
                badgeState: badge,
                heroState: humanStory.whatMattersNow,
                colorFamily: colorFamily,
                icon: icon,
                primaryRecommendationKey: humanStory.whatToDoNext.key,
                avoidRecommendationKey: humanStory.whatToAvoid.key,
                title: humanStory.title,
                subtitle: humanStory.whatHappened,
                primaryRecommendation: humanStory.whatToDoNext,
                avoidRecommendation: humanStory.whatToAvoid,
                whatHappened: humanStory.whatHappened,
                whatMattersNow: humanStory.whatMattersNow,
                whatToDoNext: humanStory.whatToDoNext,
                whatToAvoid: humanStory.whatToAvoid,
                reasons: reasons,
                supportSignals: [],
                upNextContext: upNextContext(decisionContext),
                confidence: guidance.priority.confidence,
                dataReadinessState: assessment.dataReadinessState,
                primaryAction: primaryAction,
                supportActions: supportActions,
                decisionContext: decisionContext
            )
            validateFinalStoryDebug(story)
            logV4AuditBuilderOut(story: story, source: "v4Playbook", usedFallback: false)
            return story
        }

        let humanStory = humanStory(
            owner: owner,
            input: input,
            guidance: guidance,
            titleFallback: title,
            whatHappenedFallback: subtitle,
            whatToDoNextFallback: recommendation,
            whatToAvoidFallback: avoid
        )

        let colorFamily = resolvedColorFamily(owner: owner, input: input, guidance: guidance)
        let badge = badgeText(owner: owner, fallback: display.stateLabel)
        let icon = resolvedIcon(owner: owner, fallback: display.icon)
        let signals = supportSignals(owner: owner, input: input, guidance: guidance)
        let reasons = finalStoryReasons(
            owner: owner,
            input: input,
            guidance: guidance,
            context: decisionContext
        )

        let supportActions = finalStorySupportActions(
            owner: owner,
            input: input,
            guidance: guidance,
            humanStory: humanStory,
            colorFamily: colorFamily,
            supportSignals: signals
        )
        let copyPlan = finalCopyPlan(
            owner: owner,
            input: input,
            guidance: guidance,
            humanStory: humanStory,
            reasons: reasons,
            supportActions: supportActions
        )
        let primaryAction = copyPlan.supportActions.first.map { action in
            CoachFinalStoryAction(
                title: dynamicText(action.title, russian: action.title),
                icon: action.icon
            )
        } ?? CoachFinalStoryAction(title: copyPlan.humanStory.whatToDoNext, icon: actionIcon(owner: owner))

        let story = CoachFinalStory(
            owner: owner,
            primaryFocus: guidance.priority.focus,
            titleKey: copyPlan.humanStory.title.key,
            subtitleKey: copyPlan.humanStory.whatHappened.key,
            badgeState: badge,
            heroState: copyPlan.humanStory.whatMattersNow,
            colorFamily: colorFamily,
            icon: icon,
            primaryRecommendationKey: copyPlan.humanStory.whatToDoNext.key,
            avoidRecommendationKey: copyPlan.humanStory.whatToAvoid.key,
            title: copyPlan.humanStory.title,
            subtitle: copyPlan.humanStory.whatHappened,
            primaryRecommendation: copyPlan.humanStory.whatToDoNext,
            avoidRecommendation: copyPlan.humanStory.whatToAvoid,
            whatHappened: copyPlan.humanStory.whatHappened,
            whatMattersNow: copyPlan.humanStory.whatMattersNow,
            whatToDoNext: copyPlan.humanStory.whatToDoNext,
            whatToAvoid: copyPlan.humanStory.whatToAvoid,
            reasons: copyPlan.reasons,
            supportSignals: signals,
            upNextContext: upNextContext(decisionContext),
            confidence: guidance.priority.confidence,
            dataReadinessState: assessment.dataReadinessState,
            primaryAction: primaryAction,
            supportActions: copyPlan.supportActions,
            decisionContext: decisionContext
        )
        validateFinalStoryDebug(story)
        logV4AuditBuilderOut(story: story, source: "legacyFinalStory", usedFallback: true)
        return story
    }

    private static func logV4AuditBuilderIn(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        ownerCandidate: CoachFinalStoryOwner
    ) {
        #if DEBUG
        let activity = builderAuditActivity(input: input, guidance: guidance)
        CoachLogger.trace(
            "[CoachV4Audit.Builder.In]",
            "priority=\(guidance.priority.priority)/\(guidance.priority.focus) phase=\(builderAuditPhase(guidance)) activity=\(activity?.title ?? "nil") activityState=\(builderAuditActivityState(activity, now: input.now)) ownerCandidate=\(ownerCandidate.rawValue)"
        )
        #endif
    }

    private static func logV4AuditBuilderOut(
        story: CoachFinalStory,
        source: String,
        usedFallback: Bool
    ) {
        #if DEBUG
        CoachLogger.trace(
            "[CoachV4Audit.Builder.Out]",
            "owner=\(story.owner.rawValue) title=\"\(story.title.resolved)\" source=\(source) usedFallback=\(usedFallback)"
        )
        #endif
    }

    private static func builderAuditActivity(input: CoachInputSnapshot, guidance: CoachGuidanceV3) -> PlannedActivity? {
        if let activity = guidance.priority.activity {
            return activity
        }
        switch guidance.phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            return activity
        case .stable:
            return input.dayContext.lastCompletedActivity ?? input.dayContext.completedActivities.sorted { $0.date > $1.date }.first
        }
    }

    private static func builderAuditPhase(_ guidance: CoachGuidanceV3) -> String {
        if case .stable = guidance.phase {
            return "stable"
        }
        return "\(guidance.phase)"
    }

    private static func builderAuditActivityState(_ activity: PlannedActivity?, now: Date) -> String {
        guard let activity else { return "none" }
        return activity.terminalState(now: now).rawValue
    }

    private static func validateFinalStoryDebug(_ story: CoachFinalStory) {
        #if DEBUG
        if !story.decisionContext.hasActivityContext,
           textLooksActivitySpecific(visibleFinalStoryText(story)) {
            CoachLogger.verbose(
                "[CoachTextInvalidContext]",
                "owner=\(story.owner) selectedActivity=nil selectedUpNext=nil text=\"\(visibleFinalStoryText(story))\""
            )
        }

        let reasonKinds = Set(story.reasons.map(\.kind))
        let allowed = allowedReasonKinds(for: story.owner, context: story.decisionContext)
        if !reasonKinds.isSubset(of: allowed) {
            CoachLogger.verbose(
                "[CoachReasoningMismatch]",
                "owner=\(story.owner) reasonKinds=\(reasonKinds.map(\.rawValue).joined(separator: ",")) allowed=\(allowed.map(\.rawValue).joined(separator: ","))"
            )
        }

        if (story.owner == .stableOverview || story.owner == .readiness),
           !story.decisionContext.hasFutureActivityContext,
           !story.decisionContext.hasTomorrowDemand {
            let hydrationFuelActions = story.supportActions.filter { action in
                supportSignalKind(for: action.type) == .hydration || supportSignalKind(for: action.type) == .fuel
            }
            let startsWithHydrationOrFuel = story.supportActions.first.map { action in
                supportSignalKind(for: action.type) == .hydration || supportSignalKind(for: action.type) == .fuel
            } ?? false
            if hydrationFuelActions.count >= 2 || startsWithHydrationOrFuel {
                CoachLogger.verbose(
                    "[CoachPriorityViolation]",
                    "owner=\(story.owner) actions=\(story.supportActions.map { "\($0.type):\($0.title)" }.joined(separator: " | "))"
                )
            }
        }
        #endif
    }

    private static func visibleFinalStoryText(_ story: CoachFinalStory) -> String {
        ([
            story.title.resolved,
            story.subtitle.resolved,
            story.heroState.resolved,
            story.primaryRecommendation.resolved,
            story.avoidRecommendation.resolved,
            story.whatHappened.resolved,
            story.whatMattersNow.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved
        ] + story.reasons.map { $0.text.resolved } + story.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")
            .lowercased()
    }

    private static func textLooksActivitySpecific(_ text: String) -> Bool {
        [
            "activity is coming",
            "coming soon",
            "current session",
            "next activity",
            "next planned effort",
            "next effort",
            "session is active",
            "workout",
            "ride",
            "run",
            "prepare for",
            "start easy",
            "first 15 minutes",
            "следующая активность",
            "следующая нагрузка",
            "сессия уже",
            "скоро начнется",
            "подготовьтесь",
            "первые 15 минут"
        ].contains { text.contains($0) }
    }

    private static func allowedReasonKinds(
        for owner: CoachFinalStoryOwner,
        context: CoachFinalDecisionContext
    ) -> Set<CoachFinalStoryReason.Kind> {
        switch owner {
        case .hydration, .hydrationExecution:
            return [.hydration, .training, .constraint, .stability]
        case .fuel, .fuelingDuringActivity:
            return [.fuel, .training, .constraint, .stability]
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return [.training, .constraint, .recovery, .time, .fuel]
        case .activityPreparation:
            return context.hasFutureActivityContext
                ? [.training, .constraint, .time, .hydration, .sleep]
                : [.stability, .recovery, .constraint]
        case .postActivityRecovery, .recovery:
            return [.training, .recovery, .constraint, .sleep]
        case .tomorrowProtection:
            return [.tomorrow, .constraint, .sleep, .recovery]
        case .readiness, .stableOverview:
            return [.recovery, .sleep, .time, .tomorrow, .stability, .constraint]
        }
    }

    static func inputIsCoherent(_ input: CoachInputSnapshot) -> Bool {
        readinessAssessment(input).allowed
    }

    static func readinessAssessment(_ input: CoachInputSnapshot) -> CoachFinalStoryReadinessAssessment {
        var satisfied: [String] = []
        var blocked: [String] = []

        if input.nutritionContext != nil {
            satisfied.append("nutrition")
        } else {
            blocked.append("nutritionMissing")
        }

        if input.recoveryContext.recoveryPercent > 0 {
            satisfied.append("recoveryPercent")
        } else {
            blocked.append("recoveryPlaceholder")
        }

        if input.recoveryContext.sleepHours > 0 && input.brain.metrics.sleepHours > 0 {
            satisfied.append("sleepHours")
        } else {
            blocked.append("sleepPlaceholder")
        }

        if input.brain.sleep != .unknown {
            satisfied.append("sleepState")
        } else {
            blocked.append("sleepUnknown")
        }

        let readinessLooksPlaceholder = input.brain.sleep == .unknown &&
            input.recoveryContext.recoveryPercent <= 0 &&
            (input.brain.readiness == .low || input.brain.readiness == .compromised)
        if readinessLooksPlaceholder {
            blocked.append("readinessPlaceholder:\(input.brain.readiness)")
        } else {
            satisfied.append("readinessState")
        }

        let dayContextMatchesSelectedDate = Calendar.current.isDate(input.dayContext.date, inSameDayAs: input.selectedDate)
        let dayContextClockIsCurrent = abs(input.dayContext.now.timeIntervalSince(input.now)) < 2
        if dayContextMatchesSelectedDate && dayContextClockIsCurrent {
            satisfied.append("activityContext")
        } else {
            blocked.append("activityContextStale")
        }

        let allowed = blocked.isEmpty
        return CoachFinalStoryReadinessAssessment(
            allowed: allowed,
            dataReadinessState: allowed ? .coherent : .settling,
            satisfiedConditions: satisfied,
            blockingReasons: blocked
        )
    }

    private static func resolvedOwner(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryOwner {
        if guidance.priority.focus == .activeActivity ||
            activeActivity(input: input, guidance: guidance) != nil {
            return .activeActivity
        }

        if guidance.priority.focus == .prepareForActivity ||
            guidance.priority.focus == .nextActivityLater {
            return .activityPreparation
        }

        if guidance.priority.focus == .tomorrowPlanRisk {
            return .tomorrowProtection
        }

        if completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            return .postActivityRecovery
        }

        if guidance.priority.focus == .postActivityRecovery,
           latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance),
           !objectiveStrainIsHigh(input) {
            return .recovery
        }

        if hasSevereHydrationOrHeatContext(input: input),
           activitySoon(in: input, matching: { isHeatActivity($0) }) {
            return .activityPreparation
        }

        if guidance.priority.focus == .recoveryNeeded ||
            guidance.priority.focus == .eveningWindDown ||
            guidance.priority.focus == .postActivityRecovery {
            return guidance.priority.focus == .postActivityRecovery ? .postActivityRecovery : .recovery
        }

        if guidance.priority.focus != .activeActivity,
           guidance.priority.focus != .postActivityRecovery,
           !hasHigherLevelHydrationNarrative(input: input, guidance: guidance),
           hydrationMayOwnHero(input: input, guidance: guidance),
           hasSevereHydrationOrHeatContext(input: input) {
            return .hydration
        }

        if guidance.priority.focus != .activeActivity,
           guidance.priority.focus != .postActivityRecovery,
           fuelMayOwnHero(input: input, guidance: guidance),
           hasSevereFuelOrHardTrainingContext(input: input, guidance: guidance) {
            return .fuel
        }

        switch guidance.priority.focus {
        case .activeActivity:
            return .activeActivity
        case .prepareForActivity, .nextActivityLater:
            return .activityPreparation
        case .postActivityRecovery:
            if latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance),
               !objectiveStrainIsHigh(input) {
                return .recovery
            }
            return .postActivityRecovery
        case .recoveryNeeded, .eveningWindDown:
            return .recovery
        case .trainingReadinessWarning:
            return .readiness
        case .tomorrowPlanRisk:
            return .tomorrowProtection
        case .hydrationBehind:
            return hydrationMayOwnHero(input: input, guidance: guidance) ? .hydration : fallbackOwner(input: input, guidance: guidance)
        case .fuelBehind:
            return fuelMayOwnHero(input: input, guidance: guidance) ? .fuel : fallbackOwner(input: input, guidance: guidance)
        case .performanceReadiness:
            return .readiness
        case .dailyOverview:
            return .stableOverview
        }
    }

    private static func fallbackOwner(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryOwner {
        if input.dayContext.completedTrainingStressScore > 0 ||
            input.dayContext.hasMeaningfulLoadCompleted ||
            guidance.priority.priority == .recovery {
            return .recovery
        }

        if input.dayContext.upcomingTrainingActivities.isEmpty {
            return .readiness
        }

        return .activityPreparation
    }

    private static func hasHigherLevelHydrationNarrative(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if activeActivity(input: input, guidance: guidance) != nil ||
            completedLoadShouldDriveRecovery(input: input, guidance: guidance) ||
            input.dayPriorityModel.tomorrowDemand == .hard ||
            activitySoon(in: input, matching: { isHeatActivity($0) }) {
            return true
        }

        switch guidance.priority.focus {
        case .prepareForActivity,
             .nextActivityLater,
             .postActivityRecovery,
             .recoveryNeeded,
             .tomorrowPlanRisk,
             .eveningWindDown:
            return true
        default:
            return false
        }
    }

    private static func hydrationMayOwnHero(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let waterRatio = ratio(
            current: input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        let severeGap = waterRatio < 0.20 || input.brain.hydration == .depleted
        let heatSoon = activitySoon(in: input) { CoachActivityContextResolverV3.kind(for: $0) == .heat }
        let hardSoon = activitySoon(in: input) { activity in
            let load = CoachActivityContextResolverV3.load(for: activity)
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .endurance || load == .high || load == .extreme
        }
        let safetyRisk = guidance.priority.strength == .critical || guidance.priority.limiter == .hydration && guidance.priority.strength == .critical
        let morning = localHour(input.now) < 12

        if morning && !heatSoon && !hardSoon && !safetyRisk {
            return false
        }

        return severeGap || heatSoon || hardSoon || safetyRisk
    }

    private static func hasSevereHydrationOrHeatContext(input: CoachInputSnapshot) -> Bool {
        let waterRatio = ratio(
            current: input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        return waterRatio < 0.20 ||
            input.brain.hydration == .depleted ||
            activitySoon(in: input) { CoachActivityContextResolverV3.kind(for: $0) == .heat }
    }

    private static func fuelMayOwnHero(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieRatio = ratio(current: calories, goal: input.brain.baseDayGoals.calories)
        let noFuel = calories < 120 || calorieRatio < 0.10
        let severeEnergyGap = calorieRatio < 0.20 || input.brain.fuel == .underfueled && calories < 300
        let hardSoon = activitySoon(in: input) { activity in
            let load = CoachActivityContextResolverV3.load(for: activity)
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .endurance || load == .high || load == .extreme
        }
        let postWorkoutRefuel = input.dayContext.hasMeaningfulLoadCompleted &&
            (input.nutritionContext?.needsProteinRecovery == true || severeEnergyGap)
        let readinessRisk = guidance.priority.strength == .critical && guidance.priority.limiter == .fueling
        let morning = localHour(input.now) < 12

        if morning && !hardSoon && !postWorkoutRefuel && !readinessRisk {
            return false
        }

        return (hardSoon && noFuel) || postWorkoutRefuel || severeEnergyGap || readinessRisk
    }

    private static func hasSevereFuelOrHardTrainingContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieRatio = ratio(current: calories, goal: input.brain.baseDayGoals.calories)
        return calorieRatio < 0.20 ||
            input.brain.fuel == .underfueled && calories < 300 ||
            guidance.priority.limiter == .fueling && guidance.priority.strength == .critical ||
            activitySoon(in: input) { activity in
                let load = CoachActivityContextResolverV3.load(for: activity)
                let kind = CoachActivityContextResolverV3.kind(for: activity)
                return kind == .endurance || load == .high || load == .extreme
            }
    }

    private static func resolvedColorFamily(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryColorFamily {
        if guidance.priority.strength == .critical &&
            owner != .activeActivity &&
            owner != .fuelingDuringActivity &&
            owner != .hydrationExecution &&
            owner != .hydration &&
            owner != .fuel {
            switch guidance.priority.limiter {
            case .trainingReadiness, .recovery, .accumulatedFatigue, .excessivePlannedLoad, .insufficientRecoveryTime:
                return .stress
            case .sleep:
                return input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 45 ? .stress : .warning
            case .hydration, .fueling, .upcomingTraining, .timing, .none:
                return .warning
            }
        }

        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            if let activity = activeActivity(input: input, guidance: guidance) {
                switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
                case .activeSleepRisk, .activeAfterOverload:
                    return .stress
                case .activeWithCaution:
                    return .warning
                case .activeRecoveryOnly:
                    return .recovery
                case .normalActive:
                    return .activity
                }
            }
            return .activity
        case .fuelingDuringActivity:
            return .fuel
        case .hydrationExecution:
            return .hydration
        case .activityPreparation:
            return .activity
        case .postActivityRecovery, .recovery:
            return guidance.priority.severity == .critical ? .stress : .recovery
        case .readiness:
            if guidance.priority.focus == .trainingReadinessWarning {
                return guidance.priority.strength == .critical ? .stress : .warning
            }
            return guidance.priority.focus == .performanceReadiness ? .ready : .stable
        case .stableOverview:
            return .stable
        case .tomorrowProtection:
            return .warning
        case .hydration:
            return guidance.priority.strength == .critical ? .warning : .hydration
        case .fuel:
            return guidance.priority.strength == .critical ? .warning : .fuel
        }
    }

    private static func badgeText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity:
            return text("coach.final.badge.live", "LIVE", "СЕЙЧАС")
        case .pacingExecution:
            return text("coach.final.badge.pacing", "PACING", "ТЕМП")
        case .sustainableExecution:
            return text("coach.final.badge.execution", "EXECUTION", "ВЫПОЛНЕНИЕ")
        case .fuelingDuringActivity:
            return text("coach.final.badge.fuelingLive", "FUEL NOW", "ПИТАНИЕ")
        case .hydrationExecution:
            return text("coach.final.badge.hydrationLive", "DRINK NOW", "ВОДА")
        case .activityPreparation:
            return text("coach.final.badge.prepare", "PREPARE", "ПОДГОТОВКА")
        case .postActivityRecovery, .recovery:
            return text("coach.final.badge.recovery", "RECOVERY", "ВОССТАНОВЛЕНИЕ")
        case .readiness:
            return text("coach.final.badge.readiness", "READINESS", "ГОТОВНОСТЬ")
        case .tomorrowProtection:
            return text("coach.final.badge.tomorrow", "PROTECT TOMORROW", "ЗАЩИТИТЬ ЗАВТРА")
        case .stableOverview:
            return text("coach.final.badge.stable", "ON TRACK", "ВСЁ ПО ПЛАНУ")
        case .hydration:
            return text("coach.final.badge.hydration", "HYDRATION", "ВОДА")
        case .fuel:
            return text("coach.final.badge.fuel", "FUEL", "ПИТАНИЕ")
        }
    }

    private static func titleText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.title.live", fallback, "Держите сессию под контролем")
        case .fuelingDuringActivity:
            return text("coach.final.title.fuelingLive", fallback, "Поддержите энергию")
        case .hydrationExecution:
            return text("coach.final.title.hydrationLive", fallback, "Верните воду в график")
        case .activityPreparation:
            return text("coach.final.title.prepare", fallback, "Подготовьтесь к тренировке")
        case .postActivityRecovery, .recovery:
            return text("coach.final.title.recovery", fallback, "Сейчас важнее восстановиться")
        case .readiness:
            return text("coach.final.title.readiness", fallback, "Держите день спокойным")
        case .tomorrowProtection:
            return text("coach.final.title.tomorrow", fallback, "Сохраните силы на завтра")
        case .stableOverview:
            return text("coach.final.title.stable", fallback, "Сегодня нет причин менять план")
        case .hydration:
            return text("coach.final.title.hydration", fallback, "Подготовьте воду")
        case .fuel:
            return text("coach.final.title.fuel", fallback, "Подготовьте питание")
        }
    }

    private static func subtitleText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.subtitle.live", fallback, "Сейчас важнее ровный темп, а не дополнительные цели.")
        case .fuelingDuringActivity:
            return text("coach.final.subtitle.fuelingLive", fallback, "Расход энергии уже требует действий.")
        case .hydrationExecution:
            return text("coach.final.subtitle.hydrationLive", fallback, "Питьё должно догнать нагрузку.")
        case .activityPreparation:
            return text("coach.final.subtitle.prepare", fallback, "Следующая нагрузка важнее напоминаний о воде или еде.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.subtitle.recovery", fallback, "Полезная работа уже учтена. Остаток дня должен поддержать восстановление.")
        case .readiness:
            return text("coach.final.subtitle.readiness", fallback, "Состояние тела сейчас важнее отдельных напоминаний.")
        case .tomorrowProtection:
            return text("coach.final.subtitle.tomorrow", fallback, "Сегодняшний выбор должен помочь завтрашней нагрузке.")
        case .stableOverview:
            return text("coach.final.subtitle.stable", fallback, "День выглядит стабильным и не требует срочных исправлений.")
        case .hydration:
            return text("coach.final.subtitle.hydration", fallback, "Воды сейчас мало. Это легко поправить небольшими глотками.")
        case .fuel:
            return text("coach.final.subtitle.fuel", fallback, "Еда сейчас влияет на готовность к следующей нагрузке.")
        }
    }

    private static func recommendationText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.recommendation.live", fallback, "Держите усилие ровным и завершите с запасом.")
        case .fuelingDuringActivity:
            return text("coach.final.recommendation.fuelingLive", fallback, "Примите углеводы сейчас и продолжайте по графику.")
        case .hydrationExecution:
            return text("coach.final.recommendation.hydrationLive", fallback, "Пейте маленькими глотками в ближайшие 20 минут.")
        case .activityPreparation:
            return text("coach.final.recommendation.prepare", fallback, "Начните легче обычного и оставьте интенсивность гибкой.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.recommendation.recovery", fallback, "Восстановите базу: вода, нормальная еда и без лишней интенсивности.")
        case .readiness:
            return text("coach.final.recommendation.readiness", fallback, "Выберите один лёгкий блок и не добавляйте лишнюю нагрузку.")
        case .tomorrowProtection:
            return text("coach.final.recommendation.tomorrow", fallback, "Снизьте остаток дня и защитите сон.")
        case .stableOverview:
            return text("coach.final.recommendation.stable", fallback, "Продолжайте в привычном ритме.")
        case .hydration:
            return text("coach.final.recommendation.hydration", fallback, "Пейте постепенно и не начинайте сухим.")
        case .fuel:
            return text("coach.final.recommendation.fuel", fallback, "Добавьте простую еду, которую легко переварить.")
        }
    }

    private static func avoidText(owner: CoachFinalStoryOwner, guidance: CoachGuidanceV3) -> CoachFinalStoryText {
        let fallback = guidance.avoidNotes.first ?? guidance.screenStory?.beCarefulWith ?? "Do not add unnecessary intensity."
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.avoid.live", fallback, "Не добавляйте лишний стресс в текущую сессию.")
        case .fuelingDuringActivity:
            return text("coach.final.avoid.fuelingLive", fallback, "Не ждите голода на длинной работе.")
        case .hydrationExecution:
            return text("coach.final.avoid.hydrationLive", fallback, "Не догоняйте воду одним большим объёмом.")
        case .activityPreparation:
            return text("coach.final.avoid.prepare", fallback, "Не тратьте силы до начала основной нагрузки.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.avoid.recovery", fallback, "Не добавляйте нагрузку, когда восстановление уже важнее.")
        case .readiness:
            return text("coach.final.avoid.readiness", fallback, "Не используйте хорошую готовность как повод добавлять лишнее.")
        case .tomorrowProtection:
            return text("coach.final.avoid.tomorrow", fallback, "Не занимайте силы у завтрашней тренировки.")
        case .stableOverview:
            return text("coach.final.avoid.stable", fallback, "Не добавляйте задачи там, где день уже идет нормально.")
        case .hydration:
            return text("coach.final.avoid.hydration", fallback, "Не догоняйте воду одним большим объемом.")
        case .fuel:
            return text("coach.final.avoid.fuel", fallback, "Не откладывайте еду до момента, когда энергия уже провалится.")
        }
    }

    private static func supportSignals(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [CoachFinalStorySupportSignal] {
        var signals: [CoachFinalStorySupportSignal] = []
        let nutrition = input.nutritionContext
        let waterRatio = ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        let waterCurrent = nutrition?.waterCurrent ?? input.brain.metrics.waterLiters
        let caloriesCurrent = nutrition?.caloriesCurrent ?? input.brain.metrics.calories
        let proteinCurrent = nutrition?.proteinCurrent ?? input.brain.metrics.protein
        let calorieRatio = ratio(
            current: caloriesCurrent,
            goal: input.brain.baseDayGoals.calories
        )
        let proteinRatio = ratio(
            current: proteinCurrent,
            goal: nutrition?.proteinGoal ?? input.brain.baseDayGoals.protein
        )

        let ownerIsPostActivityRecovery = owner == .postActivityRecovery
        let hydrationIsMeaningful = owner == .activityPreparation ||
            owner == .activeActivity ||
            ownerIsPostActivityRecovery
            ? (waterRatio < 0.45 && waterCurrent < 1.5 || input.brain.hydration == .depleted)
            : (waterRatio < 0.35 || input.brain.hydration == .depleted)
        if guidance.priority.focus != .hydrationBehind && hydrationIsMeaningful {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .hydration,
                    title: hydrationSupportText(owner: owner, input: input, waterRatio: waterRatio),
                    icon: "drop.fill"
                )
            )
        }

        let fuelIsMeaningful = owner == .activityPreparation ||
            owner == .activeActivity ||
            ownerIsPostActivityRecovery
            ? (calorieRatio < 0.45 && caloriesCurrent < 1_200 ||
                proteinRatio < 0.50 && proteinCurrent < 50 ||
                nutrition?.needsProteinRecovery == true && proteinRatio < 0.75 && proteinCurrent < 70)
            : (calorieRatio < 0.25 && caloriesCurrent < 600)
        if guidance.priority.focus != .fuelBehind && fuelIsMeaningful {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .fuel,
                    title: fuelSupportText(owner: owner, input: input, calorieRatio: calorieRatio),
                    icon: "bolt.fill"
                )
            )
        }

        if guidance.priority.limiter == .sleep {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .sleep,
                    title: text("coach.final.signal.sleep", "Sleep is the limiter.", "Сон сейчас ограничивает готовность."),
                    icon: "moon.fill"
                )
            )
        }

        return Array(signals.prefix(3))
    }

    private static func hydrationSupportText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        waterRatio: Double
    ) -> CoachFinalStoryText {
        if owner == .postActivityRecovery || owner == .recovery {
            return dynamicText(
                "Drink 300-500 ml over the next hour.",
                russian: "Выпейте 300-500 мл в течение следующего часа."
            )
        }

        if owner == .activityPreparation || owner == .activeActivity {
            return dynamicText(
                "Drink a small amount before the start.",
                russian: "Сделайте несколько глотков перед стартом."
            )
        }

        if waterRatio < 0.20 || input.brain.hydration == .depleted {
            return dynamicText(
                "Hydration has not really started.",
                russian: "Вода почти не начата."
            )
        }

        return dynamicText("Hydration is behind.", russian: "Вода отстает.")
    }

    private static func fuelSupportText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        calorieRatio: Double
    ) -> CoachFinalStoryText {
        if owner == .postActivityRecovery || owner == .recovery {
            return dynamicText(
                "Protein and carbs help absorb the work.",
                russian: "Белок и углеводы помогают усвоить нагрузку."
            )
        }

        if owner == .activityPreparation || owner == .activeActivity {
            return dynamicText(
                "Quick carbs make the start easier.",
                russian: "Быстрые углеводы облегчат старт."
            )
        }

        if calorieRatio < 0.20 || input.brain.fuel == .underfueled {
            return dynamicText(
                "Nutrition is materially behind.",
                russian: "Питание заметно отстает."
            )
        }

        return dynamicText("Nutrition is behind.", russian: "Питание отстает.")
    }

    private static func upNextContext(
        _ context: CoachFinalDecisionContext
    ) -> CoachFinalStoryUpNextContext? {
        guard let activity = context.selectedUpNext else {
            return nil
        }

        return CoachFinalStoryUpNextContext(
            activityID: activity.id,
            title: WeekFitCoachRuntimeLocalizedString(activity.title)
        )
    }

    private static func resolvedIcon(owner: CoachFinalStoryOwner, fallback: String) -> String {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return fallback
        case .fuelingDuringActivity:
            return "bolt.fill"
        case .hydrationExecution:
            return "drop.fill"
        case .activityPreparation:
            return fallback.isEmpty ? "figure.run" : fallback
        case .postActivityRecovery, .recovery:
            return "heart.fill"
        case .readiness:
            return "checkmark.seal.fill"
        case .tomorrowProtection:
            return "moon.stars.fill"
        case .stableOverview:
            return "waveform.path.ecg.rectangle.fill"
        case .hydration:
            return "drop.fill"
        case .fuel:
            return "bolt.fill"
        }
    }

    private static func actionIcon(owner: CoachFinalStoryOwner) -> String {
        switch owner {
        case .hydration, .hydrationExecution:
            return "drop.fill"
        case .fuel, .fuelingDuringActivity:
            return "fork.knife"
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return "speedometer"
        case .activityPreparation:
            return "figure.cooldown"
        case .postActivityRecovery, .recovery:
            return "heart.fill"
        case .tomorrowProtection:
            return "moon.fill"
        case .readiness, .stableOverview:
            return "checkmark"
        }
    }

    private static func activitySoon(
        in input: CoachInputSnapshot,
        matching predicate: (PlannedActivity) -> Bool
    ) -> Bool {
        input.dayContext.upcomingActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let minutes = activity.date.timeIntervalSince(input.now) / 60
            return minutes >= 0 && minutes <= 180 && predicate(activity)
        } || input.dayContext.allActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let end = Calendar.current.date(byAdding: .minute, value: activity.effectiveDurationMinutes, to: activity.date) ?? activity.date
            return activity.date <= input.now && input.now <= end && predicate(activity)
        }
    }

    private static func isHeatActivity(_ activity: PlannedActivity) -> Bool {
        CoachActivityContextResolverV3.kind(for: activity) == .heat
    }

    private static func minutesUntil(_ activity: PlannedActivity, from date: Date) -> Int? {
        let minutes = Int(activity.date.timeIntervalSince(date) / 60)
        return minutes >= 0 ? minutes : nil
    }

    private static func localHour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return max(0, current / goal)
    }

    private static func text(
        _ key: String,
        _ fallback: String,
        _ russianFallback: String
    ) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: key,
            fallback: fallback.trimmingCharacters(in: .whitespacesAndNewlines),
            russianFallback: russianFallback,
            parameters: [],
            russianParameters: []
        )
    }
}

private struct CoachDayNarrativePresentation {
    let stateLabel: String
    let title: String
    let message: String
    let todayTitle: String
    let todayMessage: String
    let icon: String
    let color: Color

    static func resolve(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachDayNarrativePresentation? {
        let model = input.dayPriorityModel
        let nutrition = input.nutritionContext
        let constraints = DayConstraints(input: input)
        let isDemandingDay = model.dayGoal == .overload ||
            model.dayStressLevel == .overload ||
            model.dayStressLevel == .high
        let isRecoveryPriority = guidance.priority.focus == .recoveryNeeded ||
            guidance.priority.focus == .postActivityRecovery ||
            guidance.priority.priority == .recovery
        let visualStateIsMisleading = guidance.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "ON TRACK"
        let isRecoveryPhase: Bool
        switch guidance.phase {
        case .recovering, .stable:
            isRecoveryPhase = true
        case .active, .preparing:
            isRecoveryPhase = false
        }

        guard isDemandingDay || isRecoveryPriority else { return nil }
        guard isRecoveryPhase || isRecoveryPriority || visualStateIsMisleading else { return nil }
        guard constraints.hasMeaningfulLimiter || visualStateIsMisleading || isRecoveryPriority else {
            return nil
        }

        let completedLine = accomplishmentLine(model: model, input: input)
        let limiterLine = constraints.limiterLine
        let protectionLine = protectionLine(model: model)
        let message = [
            completedLine,
            limiterLine,
            protectionLine
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return CoachDayNarrativePresentation(
            stateLabel: "RECOVERY PRIORITY",
            title: "Recovery is now the priority",
            message: message,
            todayTitle: "Recovery now leads the day",
            todayMessage: todayMessage(
                model: model,
                constraints: constraints,
                nutrition: nutrition
            ),
            icon: "bolt.shield.fill",
            color: WeekFitTheme.purple
        )
    }

    private static func accomplishmentLine(
        model: DayPriorityModel,
        input: CoachInputSnapshot
    ) -> String {
        if let primary = model.primarySession, primary.isCompleted {
            return "You completed the key workload today."
        }

        if input.dayContext.completedTrainingMinutes > 0 || input.dayContext.completedTrainingStressScore > 0 {
            return "Training work is complete for now."
        }

        return "Today has carried a demanding training load."
    }

    private static func protectionLine(model: DayPriorityModel) -> String? {
        switch model.protectionTarget {
        case .tomorrow:
            return "Protect tomorrow by keeping the rest of today easy."
        case .recovery:
            return "Protect recovery before adding more stress."
        case .primarySession:
            return "Protect the work by letting adaptation start now."
        case .consistency:
            return "Protect consistency by not adding extra fatigue."
        }
    }

    private static func todayMessage(
        model: DayPriorityModel,
        constraints: DayConstraints,
        nutrition: CoachNutritionContext?
    ) -> String {
        if constraints.hasFuelLimiter && constraints.hasHydrationLimiter {
            return "The day was demanding, and fuel plus hydration are now behind. Start recovery before adding more stress."
        }

        if constraints.hasFuelLimiter {
            return "The day was demanding, and fueling is now the limiter. Eat enough to support recovery."
        }

        if constraints.hasHydrationLimiter {
            return "The day was demanding, and hydration is now the limiter. Rehydrate steadily before the next block."
        }

        if model.protectionTarget == .tomorrow {
            return "The day was demanding. Downshift now so tomorrow's training is not compromised."
        }

        if nutrition?.needsProteinRecovery == true {
            return "The key work is done. Protein and recovery now matter more than adding load."
        }

        return "The key work is done. Recovery now matters more than adding load."
    }
}

private enum CoachPresentationCopy {
    static func normalize(
        stateLabel: String,
        title: String,
        message: String,
        recommendation: String,
        icon: String,
        color: Color,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> (stateLabel: String, title: String, message: String, recommendation: String, icon: String, color: Color) {
        let noUpcomingActivity = input.dayContext.upcomingTrainingActivities.isEmpty &&
            input.dayContext.upcomingActivities.filter { !$0.isCompleted && !$0.isSkipped }.isEmpty

        if guidance.priority.focus == .performanceReadiness && noUpcomingActivity {
            return (
                stateLabel: localized(english: "READINESS", russian: "ГОТОВНОСТЬ"),
                title: localized(english: "Keep today light", russian: "Держите день лёгким"),
                message: localized(
                    english: "Recovery looks good, but recent load still matters. Use easy movement and avoid turning the morning into another hard session.",
                    russian: "Восстановление выглядит хорошо, но недавняя нагрузка всё ещё важна. Двигайтесь легко и не добавляйте утром ещё одну тяжёлую тренировку."
                ),
                recommendation: localized(
                    english: "Choose one easy block, keep heat conservative, and let food and water support the day.",
                    russian: "Выберите один лёгкий блок, держите сауну спокойной, а еду и воду оставьте поддержкой дня."
                ),
                icon: "heart.fill",
                color: CoachPalette.stable
            )
        }

        if WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return (
                stateLabel: runtimeLocalized(stateLabel, fallback: stateLabel),
                title: runtimeLocalized(title, fallback: title),
                message: runtimeLocalized(message, fallback: message),
                recommendation: runtimeLocalized(recommendation, fallback: recommendation),
                icon: icon,
                color: color
            )
        }

        return (stateLabel, title, message, recommendation, icon, color)
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func runtimeLocalized(_ value: String, fallback: String) -> String {
        let localized = WeekFitCoachRuntimeLocalizedString(value)
        guard localized != value else { return fallback }
        return localized
    }
}

private struct DayConstraints {
    let hasFuelLimiter: Bool
    let hasHydrationLimiter: Bool
    let hasProteinLimiter: Bool

    init(input: CoachInputSnapshot) {
        let nutrition = input.nutritionContext
        let calorieRatio = Self.ratio(
            current: nutrition?.caloriesCurrent ?? input.brain.metrics.calories,
            goal: input.brain.baseDayGoals.calories
        )
        let proteinRatio = Self.ratio(
            current: nutrition?.proteinCurrent ?? input.brain.metrics.protein,
            goal: input.brain.baseDayGoals.protein
        )
        let waterRatio = Self.ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )

        hasFuelLimiter = calorieRatio < 0.45 ||
            proteinRatio < 0.35
        hasHydrationLimiter = input.brain.hydration == .depleted ||
            input.brain.hydration == .behind ||
            waterRatio < 0.60
        hasProteinLimiter = proteinRatio < 0.50
    }

    var hasMeaningfulLimiter: Bool {
        hasFuelLimiter || hasHydrationLimiter || hasProteinLimiter
    }

    var limiterLine: String? {
        switch (hasFuelLimiter, hasHydrationLimiter, hasProteinLimiter) {
        case (true, true, true):
            return "Recovery, hydration and fueling are now the limiting factors, with protein still behind."
        case (true, true, false):
            return "Recovery, hydration and fueling are now the limiting factors."
        case (true, false, true):
            return "Recovery and fueling are now the limiting factors, with protein still behind."
        case (true, false, false):
            return "Recovery and fueling are now the limiting factors."
        case (false, true, true):
            return "Recovery and hydration are now the limiting factors, with protein still behind."
        case (false, true, false):
            return "Recovery and hydration are now the limiting factors."
        case (false, false, true):
            return "Recovery and protein are now the limiting factors."
        case (false, false, false):
            return nil
        }
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return current / goal
    }
}

extension CoachRationalePresentation {
    static func resolve(from input: CoachInputSnapshot) -> CoachRationalePresentation? {
        guard let active = input.dayContext.allActivities.first(where: { isActiveActivity($0, now: input.now) }) ??
                input.brain.activities.first(where: { isActiveActivity($0, now: input.now) }) else {
            return nil
        }

        let model = input.dayPriorityModel
        let target = rationaleTarget(
            active: active,
            model: model
        )
        guard let target else { return nil }

        let rationale = rationaleCopy(
            active: active,
            target: target,
            model: model
        )

        return CoachRationalePresentation(
            title: rationale.title,
            message: rationale.message,
            icon: icon(for: target),
            color: WeekFitTheme.meal,
            sourceActivityID: target.id
        )
    }

    private static func isActiveActivity(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date

        return activity.date <= now && now <= end
    }

    private static func cleanTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Training" : trimmed
    }

    private static func activeActivityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        if title.contains("walk") || type.contains("walk") {
            return "walk"
        }
        return "session"
    }

    private static func rationaleTarget(
        active: PlannedActivity,
        model: DayPriorityModel
    ) -> PlannedActivity? {
        if let primary = model.primarySession, primary.id != active.id {
            return primary
        }

        if let secondary = model.secondarySession, secondary.id != active.id {
            return secondary
        }

        return nil
    }

    private static func rationaleCopy(
        active: PlannedActivity,
        target: PlannedActivity,
        model: DayPriorityModel
    ) -> (title: String, message: String) {
        let targetName = cleanTitle(target.title)
        let activeName = activeActivityName(active)
        let kind = CoachActivityContextResolverV3.kind(for: target)
        let load = CoachActivityContextResolverV3.load(for: target)

        if model.protectionTarget == .tomorrow {
            return (
                title: "Protect tomorrow",
                message: "Tomorrow carries real demand. Keep this \(activeName) easy so today supports recovery instead of borrowing from the next training day."
            )
        }

        switch kind {
        case .endurance:
            return (
                title: "Protect the main effort",
                message: "\(targetName) is the key workload today. Keep this \(activeName) relaxed so you preserve legs and fueling for the main effort."
            )

        case .workout:
            let loadPhrase = load == .high || load == .extreme
                ? "the highest-value training block"
                : "the priority training block"
            return (
                title: "Save quality for training",
                message: "\(targetName) is \(loadPhrase) today. Use this \(activeName) to stay loose, not to add fatigue before loading."
            )

        case .heat:
            return (
                title: "Arrive settled for heat",
                message: "\(targetName) will add heat stress. Keep this \(activeName) easy so you start hydrated, calm, and not already taxed."
            )

        case .recovery:
            return (
                title: "Keep the day restorative",
                message: "\(targetName) is meant to support recovery. Keep this \(activeName) easy so the day stays restorative, not draining."
            )

        case .meal:
            return (
                title: "Keep digestion easy",
                message: "\(targetName) is the next useful reset. Keep this \(activeName) easy so appetite and digestion stay steady."
            )

        case .other:
            return (
                title: "Protect what comes next",
                message: "\(targetName) is the next meaningful block. Keep this \(activeName) easy so you arrive fresh instead of carrying extra fatigue."
            )
        }
    }

    private static func icon(for activity: PlannedActivity) -> String {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("core") || text.contains("strength") || text.contains("gym") {
            return "figure.core.training"
        }
        if text.contains("run") {
            return "figure.run"
        }
        if text.contains("ride") || text.contains("bike") || text.contains("cycle") {
            return "bicycle"
        }
        return "figure.strengthtraining.traditional"
    }
}

private func validTitle(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
