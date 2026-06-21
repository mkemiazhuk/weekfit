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

        let normalizedGuidance = CoachLightRecoveryStableDayPolicy.normalizedGuidance(
            input: input,
            guidance: guidance
        )

        let dayNarrative = CoachDayNarrativePresentation.resolve(
            input: input,
            guidance: normalizedGuidance
        )
        let frame = normalizedGuidance.dayDecisionFrame
        let frameOwnsNarrative = frame?.shouldOwnNarrative == true
        let frameStory = frameOwnsNarrative ? normalizedGuidance.screenStory : nil
        let stateLabel = frameOwnsNarrative ? frame?.stateLabel ?? normalizedGuidance.stateLabel : dayNarrative?.stateLabel ?? normalizedGuidance.screenStory?.stateLabel ?? normalizedGuidance.stateLabel
        let title = frameOwnsNarrative ? frameStory?.title ?? frame?.title ?? normalizedGuidance.title : dayNarrative?.title ?? validTitle(normalizedGuidance.title) ?? normalizedGuidance.screenStory?.title ?? normalizedGuidance.priority.detailTitle
        let message = frameOwnsNarrative ? frameStory?.myRead ?? frame?.diagnosisText ?? normalizedGuidance.message : dayNarrative?.message ?? normalizedGuidance.screenStory?.myRead ?? normalizedGuidance.message
        let icon = dayNarrative?.icon ?? normalizedGuidance.screenStory?.icon ?? normalizedGuidance.icon
        let color = dayNarrative?.color ?? normalizedGuidance.screenStory?.color ?? normalizedGuidance.color
        let recommendation = frameOwnsNarrative ? frameStory?.myRecommendation ?? normalizedGuidance.insightSubtitle ?? WeekFitLocalizedString("coach.fallback.keepNextStepSimple") : normalizedGuidance.screenStory?.myRecommendation ?? normalizedGuidance.insightSubtitle ?? WeekFitLocalizedString("coach.fallback.keepNextStepSimple")
        let display = CoachPresentationCopy.normalize(
            stateLabel: stateLabel,
            title: title,
            message: message,
            recommendation: recommendation,
            icon: icon,
            color: color,
            input: input,
            guidance: normalizedGuidance
        )
        logV4AuditDecision(input: input, guidance: normalizedGuidance)
        logV4AuditBuilderInput(input: input, guidance: normalizedGuidance)
        let builtFinalStory = CoachFinalStoryBuilder.build(
            input: input,
            guidance: normalizedGuidance,
            display: display
        )
        logV4AuditStateBeforeEmit(story: builtFinalStory, guidance: normalizedGuidance)
        let finalStory = applyV4VisibleStoryContractGuard(
            story: builtFinalStory,
            input: input,
            guidance: normalizedGuidance,
            reason: reason
        )
        logV4AuditStateAfterGuard(before: builtFinalStory, after: finalStory, input: input, guidance: normalizedGuidance)
        logFinalStoryValidationContract(story: finalStory, guidance: normalizedGuidance)
        finalStory.validateVisibleContract()

        return CoachState(
            id: UUID(),
            createdAt: createdAt,
            status: .ready,
            input: input,
            fingerprint: fingerprint,
            guidance: normalizedGuidance,
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
        // The literal "Take it easy for now" is produced inside CoachFinalStoryBuilder's
        // V4 hero text only after a story owner has already become .recovery. Reason rows and
        // render-model fallback copy must remain support/display concerns; they do not own the
        // final story. This final guard exists at the last CoachState boundary so legacy fallback,
        // duplicate filtering, and render defaults cannot turn a stable completed recovery-tier
        // activity into the visible recovery story.
        if (story.owner == .stableOverview || story.owner == .readiness),
           guidance.priority.focus == .dailyOverview,
           !CoachLightRecoveryStableDayPolicy.needsVisibleStableDayCorrection(story: story, guidance: guidance) {
            return story
        }

        let isPhaseStable = v4FinalGuardPhaseIsStable(guidance)

        let recoveryActivity = v4FinalGuardRecoveryTierActivity(input: input, guidance: guidance)
        let isRecoveryTierActivity = recoveryActivity != nil
        let activityState = v4FinalGuardActivityState(recoveryActivity, now: input.now)
        let hasIndependentRecoveryDeficit = v4FinalGuardHasIndependentRecoveryDeficit(input: input, guidance: guidance)
        let hasSignificantWorkoutActive = v4FinalGuardHasSignificantWorkoutActive(input: input, guidance: guidance)
        let hasSignificantWorkoutUpcomingToday = v4FinalGuardHasSignificantWorkoutUpcomingToday(input: input, guidance: guidance)
        let hasRecentlyCompletedSignificantWorkout = v4FinalGuardHasRecentlyCompletedSignificantWorkout(input: input)
        let hasSignificantWorkoutTomorrow = v4FinalGuardHasSignificantWorkoutTomorrow(input: input)
        let shouldForceLightRecoveryStableOverview = CoachLightRecoveryStableDayPolicy.shouldForceStableOverview(
            input: input,
            guidance: guidance
        )
        let needsCorrection = CoachLightRecoveryStableDayPolicy.needsVisibleStableDayCorrection(
            story: story,
            guidance: guidance
        )
        let shouldApply = shouldForceLightRecoveryStableOverview &&
            isRecoveryTierActivity &&
            needsCorrection &&
            !hasIndependentRecoveryDeficit &&
            !hasSignificantWorkoutActive &&
            !hasSignificantWorkoutUpcomingToday &&
            !hasRecentlyCompletedSignificantWorkout &&
            !hasSignificantWorkoutTomorrow
        let failedConditions = v4FinalGuardFailedConditions(
            isPriorityStableDailyOverview: shouldForceLightRecoveryStableOverview,
            isPhaseStable: isPhaseStable,
            isRecoveryTierActivity: isRecoveryTierActivity,
            isCompletedRecoveryTierActivity: activityState == "completed" || activityState == "planned",
            hasIndependentRecoveryDeficit: hasIndependentRecoveryDeficit,
            hasSignificantWorkoutActive: hasSignificantWorkoutActive,
            hasSignificantWorkoutUpcomingToday: hasSignificantWorkoutUpcomingToday,
            hasRecentlyCompletedSignificantWorkout: hasRecentlyCompletedSignificantWorkout,
            hasSignificantWorkoutTomorrow: hasSignificantWorkoutTomorrow,
            storyLooksRecovery: needsCorrection
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

        let hero = CoachLightRecoveryStableDayPolicy.stableDayHero(
            input: input,
            activity: recoveryActivity
        )
        let title = v4FinalGuardText(hero.english, russian: hero.russian)
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
        if let focus = guidance.priority.activity, v4FinalGuardIsRecoveryTierOnly(focus) {
            candidates.append(focus)
        }
        switch guidance.phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            if v4FinalGuardIsRecoveryTierOnly(activity) {
                candidates.append(activity)
            }
        case .stable:
            break
        }
        candidates.append(contentsOf: input.plannedActivities.filter {
            CoachLightRecoveryStableDayPolicy.isActuallyCompleted($0, now: input.now) &&
                Calendar.current.isDate($0.date, inSameDayAs: input.now)
        })

        return candidates
            .filter(v4FinalGuardIsRecoveryTierOnly)
            .sorted { $0.date > $1.date }
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
        CoachActivityClassification.isRecoveryTier(activity)
    }

    private static func v4FinalGuardIsSignificantWorkout(_ activity: PlannedActivity) -> Bool {
        CoachActivityClassification.isSignificantWorkout(activity)
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

    private static func logFinalStoryValidationContract(
        story: CoachFinalStory,
        guidance: CoachGuidanceV3
    ) {
        #if DEBUG
        let reasonKinds = story.reasons.map(\.kind.rawValue).joined(separator: ",")
        let supportSignals = story.supportSignals
            .map { "\($0.kind.rawValue):\($0.title.resolved)" }
            .joined(separator: " | ")
        let supportActions = story.supportActions
            .map { "\($0.type):\($0.title)" }
            .joined(separator: " | ")
        CoachLogger.trace(
            "[CoachFinalStoryValidation.BeforeAssert]",
            [
                "owner=\(story.owner.rawValue)",
                "priority=\(guidance.priority.priority)/\(guidance.priority.focus)",
                "primaryFocus=\(story.primaryFocus)",
                "colorFamily=\(story.colorFamily)",
                "severity=\(guidance.priority.severity)",
                "strength=\(guidance.priority.strength)",
                "title=\"\(story.title.resolved)\"",
                "recommendation=\"\(story.primaryRecommendation.resolved)\"",
                "reasonKinds=[\(reasonKinds)]",
                "supportSignals=[\(supportSignals.isEmpty ? "none" : supportSignals)]",
                "supportActions=[\(supportActions.isEmpty ? "none" : supportActions)]"
            ].joined(separator: " ")
        )

        if story.owner == .recovery || story.owner == .postActivityRecovery {
            let colorPasses = story.colorFamily == .recovery || story.colorFamily == .warning
            if !colorPasses {
                CoachLogger.trace(
                    "[CoachFinalStoryValidation.AssertWouldFail]",
                    "Recovery story must use recovery or warning color. owner=\(story.owner.rawValue) colorFamily=\(story.colorFamily) priority=\(guidance.priority.priority)/\(guidance.priority.focus)"
                )
            }
        }

        if (story.owner == .recovery || story.owner == .postActivityRecovery),
           guidance.priority.focus == .dailyOverview,
           story.primaryFocus == .dailyOverview {
            CoachLogger.trace(
                "[CoachFinalStoryValidation.FocusMismatch]",
                "owner=\(story.owner.rawValue) still carries dailyOverview focus after V4 owner normalization"
            )
        }
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

