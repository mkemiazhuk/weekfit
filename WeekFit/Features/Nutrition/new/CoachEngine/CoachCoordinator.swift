import Foundation
internal import Combine

@MainActor
final class CoachCoordinator: ObservableObject {

    typealias DecisionResolver = (CoachInputSnapshot) -> CoachGuidanceV3

    @Published private(set) var state: CoachState
    @Published private(set) var nextScheduledCheckpoint: Date?

    private var latestInput: CoachInputSnapshot?
    private var lastResolvedFingerprint: CoachInputFingerprint?
    private let decisionResolver: DecisionResolver

    private(set) var recomputeCount = 0
    private(set) var skippedUnchangedCount = 0
    private(set) var lastRecomputeReason: String?

    init(
        initialState: CoachState = .unavailable(reason: "Coach inputs have not been collected yet."),
        decisionResolver: @escaping DecisionResolver = CoachCoordinator.defaultDecisionResolver
    ) {
        self.state = initialState
        self.decisionResolver = decisionResolver
    }

    func updateInput(_ input: CoachInputSnapshot?) {
        latestInput = input
    }

    @discardableResult
    func recomputeIfNeeded(reason: String) -> CoachState {
        guard let latestInput else {
            if state.hasValidGuidance {
                state = state.preservingPreviousDuringRefresh()
            } else if state.fingerprint != nil || state.guidance != nil {
                state = .unavailable(reason: "Coach inputs are unavailable.")
            }
            nextScheduledCheckpoint = nil
            return state
        }

        return recomputeIfNeeded(input: latestInput, reason: reason)
    }

    @discardableResult
    func forceRecomputeForLanguageChange(reason: String) -> CoachState {
        guard let latestInput else {
            return state
        }

        let fingerprint = CoachInputFingerprint(snapshot: latestInput)
        let readiness = CoachFinalStoryBuilder.readinessAssessment(latestInput)
        guard readiness.allowed else {
            logFinalStoryReadiness(
                input: latestInput,
                reason: reason,
                readiness: readiness,
                outcome: state.hasValidGuidance ? "blockedPreservePrevious" : "blockedSettling"
            )
            state = state.hasValidGuidance
                ? state.preservingPreviousDuringRefresh()
                : .settling(reason: "Coach inputs are still syncing.")
            nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: latestInput)
            return state
        }

        let guidance = decisionResolver(latestInput)
        let rawState = CoachState.ready(
            input: latestInput,
            fingerprint: fingerprint,
            guidance: guidance,
            reason: reason
        )
        let nextState = applyStableRecoveryActivityVisibleOverride(
            rawState,
            input: latestInput,
            guidance: guidance
        )

        lastResolvedFingerprint = fingerprint
        recomputeCount += 1
        lastRecomputeReason = reason
        state = nextState
        nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: latestInput)

        logFinalStoryReadiness(
            input: latestInput,
            reason: reason,
            readiness: readiness,
            outcome: "allowedLanguageRecompute"
        )
        logVisibleFinalState(state: nextState, guidance: guidance, reason: reason)
        CoachLogger.compact(
            "[CoachState]",
            "Coach state recomputed for language change reason=\(reason) stateID=\(nextState.id) priority=\(guidance.priority.priority)/\(guidance.priority.focus) owner=\(nextState.finalStory?.owner.rawValue ?? "nil") title=\"\(nextState.finalStory?.title.resolved ?? "nil")\""
        )

        return nextState
    }

    @discardableResult
    func recomputeIfNeeded(
        input: CoachInputSnapshot,
        reason: String
    ) -> CoachState {
        latestInput = input
        let fingerprint = CoachInputFingerprint(snapshot: input)

        guard fingerprint != lastResolvedFingerprint else {
            skippedUnchangedCount += 1
            return state
        }

        let readiness = CoachFinalStoryBuilder.readinessAssessment(input)
        guard readiness.allowed else {
            logFinalStoryReadiness(
                input: input,
                reason: reason,
                readiness: readiness,
                outcome: state.hasValidGuidance ? "blockedPreservePrevious" : "blockedSettling"
            )
            state = state.hasValidGuidance
                ? state.preservingPreviousDuringRefresh()
                : .settling(reason: "Coach inputs are still syncing.")
            nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: input)
            return state
        }

        let guidance = decisionResolver(input)
        let rawState = CoachState.ready(
            input: input,
            fingerprint: fingerprint,
            guidance: guidance,
            reason: reason
        )
        let nextState = applyStableRecoveryActivityVisibleOverride(
            rawState,
            input: input,
            guidance: guidance
        )
        logContextDebug(
            input: input,
            state: nextState
        )

        lastResolvedFingerprint = fingerprint
        recomputeCount += 1
        lastRecomputeReason = reason
        state = nextState
        nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: input)

        logFinalStoryReadiness(
            input: input,
            reason: reason,
            readiness: readiness,
            outcome: "allowed"
        )
        logVisibleFinalState(state: nextState, guidance: guidance, reason: reason)
        CoachLogger.compact(
            "[CoachState]",
            "Coach state changed reason=\(reason) stateID=\(nextState.id) priority=\(guidance.priority.priority)/\(guidance.priority.focus) owner=\(nextState.finalStory?.owner.rawValue ?? "nil") title=\"\(nextState.finalStory?.title.resolved ?? "nil")\""
        )

        return nextState
    }

    private static func defaultDecisionResolver(input: CoachInputSnapshot) -> CoachGuidanceV3 {
        CoachEngineV3.decide(
            from: input.brain.refreshedForCurrentLocalTime(activities: input.plannedActivities),
            plannedActivities: input.plannedActivities,
            selectedDate: input.selectedDate,
            dayContext: input.dayContext,
            actualLoad: input.actualLoad,
            recoveryContext: input.recoveryContext,
            nutritionContext: input.nutritionContext
        )
    }

    private func logVisibleFinalState(
        state: CoachState,
        guidance: CoachGuidanceV3,
        reason: String
    ) {
        CoachLogger.compact(
            "[CoachV4VisibleFinal]",
            "reason=\(reason) priority=\(guidance.priority.priority)/\(guidance.priority.focus) owner=\(state.finalStory?.owner.rawValue ?? "nil") title=\"\(state.finalStory?.title.resolved ?? "nil")\""
        )
    }

    private func applyStableRecoveryActivityVisibleOverride(
        _ state: CoachState,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachState {
        guard let visibleStory = state.finalStory,
              guidance.priority.priority == .stable,
              guidance.priority.focus == .dailyOverview,
              finalVisiblePhaseIsStable(guidance),
              let activity = finalVisibleCompletedRecoveryActivity(input: input, guidance: guidance),
              (visibleStory.owner == .recovery ||
                visibleStory.owner == .postActivityRecovery ||
                visibleStory.title.resolved.localizedCaseInsensitiveContains("Recovery matters most now") ||
                visibleStory.title.resolved.localizedCaseInsensitiveContains("recovery"))
        else {
            return state
        }

        let title = finalVisibleText(
            "You already added some easy movement",
            russian: "Немного движения сегодня уже есть"
        )
        let assessment = finalVisibleText(
            "You already added a little easy movement today.",
            russian: "Сегодня уже было немного лёгкого движения."
        )
        let recommendation = finalVisibleText(
            "Nothing else needs special attention now.",
            russian: "Сейчас ничего ещё не требует особого внимания."
        )
        let risk = finalVisibleText("", russian: "")
        let guardedStory = CoachFinalStory(
            owner: .stableOverview,
            primaryFocus: .dailyOverview,
            titleKey: visibleStory.titleKey,
            subtitleKey: visibleStory.subtitleKey,
            badgeState: finalVisibleText("STEADY", russian: "РОВНО"),
            heroState: finalVisibleText("Open day", russian: "Спокойный день"),
            colorFamily: .stable,
            icon: "checkmark.seal.fill",
            primaryRecommendationKey: visibleStory.primaryRecommendationKey,
            avoidRecommendationKey: visibleStory.avoidRecommendationKey,
            title: title,
            subtitle: assessment,
            primaryRecommendation: recommendation,
            avoidRecommendation: risk,
            whatHappened: assessment,
            whatMattersNow: finalVisibleText(
                "\(activity.title) counts as easy movement, not training stress.",
                russian: "\(activity.title) — это лёгкое движение, а не тренировочная нагрузка."
            ),
            whatToDoNext: recommendation,
            whatToAvoid: risk,
            reasons: [],
            supportSignals: visibleStory.supportSignals.filter { $0.kind != .recovery },
            upNextContext: nil,
            confidence: visibleStory.confidence,
            dataReadinessState: visibleStory.dataReadinessState,
            primaryAction: CoachFinalStoryAction(
                title: recommendation,
                icon: "checkmark.circle.fill"
            ),
            supportActions: [],
            decisionContext: visibleStory.decisionContext
        )

        CoachLogger.compact(
            "[CoachV4HardOverride]",
            "applied=true reason=stableCompletedRecoveryActivity ownerBefore=\(visibleStory.owner.rawValue) titleBefore=\"\(visibleStory.title.resolved)\" ownerAfter=\(guardedStory.owner.rawValue) titleAfter=\"\(guardedStory.title.resolved)\""
        )

        let avoidNotes = guardedStory.avoidRecommendation.resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? []
            : [guardedStory.avoidRecommendation.resolved]
        return CoachState(
            id: state.id,
            createdAt: state.createdAt,
            status: state.status,
            input: state.input,
            fingerprint: state.fingerprint,
            guidance: state.guidance,
            finalStory: guardedStory,
            todayPresentation: CoachTodayPresentation(
                title: guardedStory.title.resolved,
                message: guardedStory.subtitle.resolved,
                icon: guardedStory.icon,
                color: guardedStory.color
            ),
            coachPresentation: CoachScreenPresentation(
                stateLabel: guardedStory.badgeState.resolved,
                title: guardedStory.title.resolved,
                message: guardedStory.subtitle.resolved,
                recommendation: guardedStory.primaryRecommendation.resolved,
                icon: guardedStory.icon,
                color: guardedStory.color,
                supportActions: guardedStory.supportActions,
                avoidNotes: avoidNotes
            ),
            rationalePresentation: state.rationalePresentation
        )
    }

    private func finalVisibleText(_ english: String, russian: String) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: "",
            fallback: english,
            russianFallback: russian,
            parameters: [],
            russianParameters: []
        )
    }

    private func finalVisiblePhaseIsStable(_ guidance: CoachGuidanceV3) -> Bool {
        if case .stable = guidance.phase {
            return true
        }
        return false
    }

    private func finalVisibleRecoveryActivity(
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
        return candidates.first(where: finalVisibleIsRecoveryTierActivity)
    }

    private func finalVisibleCompletedRecoveryActivity(
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

        return candidates.first { activity in
            finalVisibleIsRecoveryTierActivity(activity) &&
                activity.terminalState(now: input.now) == .completed
        }
    }

    private func finalVisibleHasIndependentRecoveryDeficit(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 65 { return true }
        if input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5 { return true }
        if input.brain.sleep == .short || input.brain.sleep == .veryShort { return true }
        if input.brain.readiness == .low || input.brain.readiness == .compromised { return true }
        if input.brain.recovery == .compromised || input.brain.recovery == .vulnerable { return true }
        return guidance.priority.limiter == .sleep ||
            guidance.priority.limiter == .trainingReadiness ||
            guidance.priority.limiter == .accumulatedFatigue
    }

    private func finalVisibleHasSignificantWorkoutContext(input: CoachInputSnapshot) -> Bool {
        input.plannedActivities.contains { activity in
            guard finalVisibleIsSignificantWorkout(activity) else { return false }
            if activity.isCompleted { return true }
            if activity.isActive(at: input.now) { return true }
            return activity.date >= input.now && Calendar.current.isDate(activity.date, inSameDayAs: input.now)
        }
    }

    private func finalVisibleIsRecoveryTierActivity(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title) \(activity.icon) \(activity.imageName)".lowercased()
        return text.contains("walk") ||
            text.contains("walking") ||
            text.contains("stretch") ||
            text.contains("yoga") ||
            text.contains("breath")
    }

    private func finalVisibleIsSignificantWorkout(_ activity: PlannedActivity) -> Bool {
        guard !finalVisibleIsRecoveryTierActivity(activity) else { return false }
        let text = "\(activity.type) \(activity.title) \(activity.icon) \(activity.imageName)".lowercased()
        return text.contains("cycling") ||
            text.contains("bicycle") ||
            text.contains("running") ||
            text.contains("run") ||
            text.contains("tennis") ||
            text.contains("squash") ||
            text.contains("upper body") ||
            text.contains("lower body") ||
            text.contains("full body") ||
            text.contains("core") ||
            text.contains("strength") ||
            text.contains("workout")
    }

    private func logFinalStoryReadiness(
        input: CoachInputSnapshot,
        reason: String,
        readiness: CoachFinalStoryReadinessAssessment,
        outcome: String
    ) {
        CoachLogger.trace(
            "[CoachFinalStoryReadiness]",
            [
                "outcome=\(outcome)",
                "reason=\(reason)",
                readiness.summary,
                "rawRecovery=\(input.recoveryContext.recoveryPercent)",
                "sleepHours=\(String(format: "%.2f", input.recoveryContext.sleepHours))",
                "brainSleep=\(input.brain.sleep)",
                "brainReadiness=\(input.brain.readiness)",
                "activities=\(input.dayContext.allActivities.count)",
                "source=\(input.source)"
            ].joined(separator: " ")
        )
    }

    private func logContextDebug(
        input: CoachInputSnapshot,
        state: CoachState
    ) {
        let active = input.plannedActivities.first(where: { isActiveActivity($0, now: input.now) })
        let rationale = state.rationalePresentation
        let upcoming = rationale.flatMap { presentation in
            input.plannedActivities.first(where: { $0.id == presentation.sourceActivityID })
        }
        let minutes = upcoming.map { max(0, Int($0.date.timeIntervalSince(input.now) / 60)) }
        let model = input.dayPriorityModel

        CoachLogger.trace(
            "[CoachContextDebug]",
            [
                "activeActivity=\(activitySummary(active))",
                "upcomingWorkout=\(activitySummary(upcoming))",
                "minutesUntilWorkout=\(minutes.map(String.init) ?? "nil")",
                "primaryGuidanceSource=\(active == nil ? "canonicalPriority" : "activeActivity")",
                "secondaryGuidanceSource=\(rationale == nil ? "none" : "dayPriorityRationale")",
                "dayPrimarySession=\(activitySummary(model.primarySession))",
                "daySecondarySession=\(activitySummary(model.secondarySession))",
                "dayGoal=\(model.dayGoal.rawValue)",
                "dayStressLevel=\(model.dayStressLevel.rawValue)",
                "tomorrowDemand=\(model.tomorrowDemand.rawValue)",
                "protectionTarget=\(model.protectionTarget.rawValue)"
            ].joined(separator: " ")
        )
    }

    private func activitySummary(_ activity: PlannedActivity?) -> String {
        guard let activity else { return "nil" }
        return "\"\(activity.title)\"#\(activity.id)"
    }

    private func isActiveActivity(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date

        return activity.date <= now && now <= end
    }
}

enum CoachCheckpointScheduler {
    static func nextCheckpoint(after input: CoachInputSnapshot) -> Date? {
        let calendar = Calendar.current
        let now = input.now
        var checkpoints: [Date] = []

        if let nextPhase = nextTimePhaseBoundary(after: now, calendar: calendar) {
            checkpoints.append(nextPhase)
        }

        if let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) {
            checkpoints.append(tomorrow)
        }

        input.plannedActivities
            .filter { !$0.isSkipped }
            .forEach { activity in
                if activity.date > now {
                    checkpoints.append(activity.date)
                }

                let end = calendar.date(
                    byAdding: .minute,
                    value: activity.effectiveDurationMinutes,
                    to: activity.date
                ) ?? activity.date

                if end > now {
                    checkpoints.append(end)
                }
            }

        return checkpoints
            .map { $0.addingTimeInterval(1) }
            .filter { $0 > now }
            .min()
    }

    private static func nextTimePhaseBoundary(after date: Date, calendar: Calendar) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)
        let boundaries = [6, 11, 16]
            .compactMap { hour in
                calendar.date(
                    byAdding: .hour,
                    value: hour,
                    to: startOfDay
                )
            }

        return boundaries.first { $0 > date } ??
            calendar.date(
                byAdding: .day,
                value: 1,
                to: startOfDay
            ).flatMap {
                calendar.date(
                    byAdding: .hour,
                    value: 6,
                    to: $0
                )
            }
    }
}
