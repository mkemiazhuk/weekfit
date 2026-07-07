import Foundation
internal import Combine

@MainActor
final class CoachCoordinator: ObservableObject {

    @Published private(set) var state: CoachState
    @Published private(set) var nextScheduledCheckpoint: Date?

    private var latestInput: CoachInputSnapshot?
    private var lastResolvedFingerprint: CoachInputFingerprint?
    private var settlingRetryTask: Task<Void, Never>?
    private nonisolated(unsafe) var settlingRetryTaskForDeinit: Task<Void, Never>?

    private(set) var recomputeCount = 0
    private(set) var skippedUnchangedCount = 0
    private(set) var lastRecomputeReason: String?

    private let lifecycleToken = "CoachCoordinator"

    init(initialState: CoachState = .unavailable(reason: "Coach inputs have not been collected yet.")) {
        WeekFitLifecycleTracker.attach(lifecycleToken)
        CoachIntegrationMetrics.restoreFromStorageIfNeeded()
        self.state = initialState
    }
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {
        settlingRetryTaskForDeinit?.cancel()
        WeekFitLifecycleTracker.detach(lifecycleToken)
    }

    func updateInput(_ input: CoachInputSnapshot?) {
        latestInput = input
    }

    func invalidateResolvedStateForDayChange() {
        lastResolvedFingerprint = nil
    }

    /// Drops cached coach input before SwiftData mutates or deletes `CoachPlannedActivitySnapshot` rows.
    func invalidateCachedSnapshots(reason: String) {
        latestInput = nil
        lastResolvedFingerprint = nil
        nextScheduledCheckpoint = nil
        if state.hasValidGuidance {
            state = state.preservingPreviousDuringRefresh()
        } else {
            state = .settling(reason: reason)
        }
    }

    @discardableResult
    func recomputeIfNeeded(reason: String) -> CoachState {
        guard let latestInput else {
            if state.hasValidGuidance {
                state = state.preservingPreviousDuringRefresh()
            } else if state.fingerprint != nil {
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
        let readiness = CoachInputReadiness.assessment(latestInput)
        guard readiness.allowed else {
            logInputReadiness(
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

        let rawState = CoachState.ready(
            input: latestInput,
            fingerprint: fingerprint,
            reason: reason
        )
        lastResolvedFingerprint = fingerprint
        recomputeCount += 1
        lastRecomputeReason = reason
        state = rawState
        nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: latestInput)

        logInputReadiness(
            input: latestInput,
            reason: reason,
            readiness: readiness,
            outcome: "allowedLanguageRecompute"
        )
        logVisibleState(state: rawState, reason: reason)
        persistTodayInsightIfNeeded(from: rawState)

        return rawState
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

        if CoachStateStabilizer.isSettling(source: reason) {
            logInputReadiness(
                input: input,
                reason: reason,
                readiness: CoachInputReadiness.assessment(input),
                outcome: state.hasValidGuidance ? "blockedSettlingPreservePrevious" : "blockedSettling"
            )
            state = state.hasValidGuidance
                ? state.preservingPreviousDuringRefresh()
                : .settling(reason: "Coach inputs are still syncing.")
            nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: input)
            scheduleSettlingRetry(for: input, reason: reason)
            return state
        }

        let readiness = CoachInputReadiness.assessment(input)
        guard readiness.allowed else {
            logInputReadiness(
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

        let rawState = CoachState.ready(
            input: input,
            fingerprint: fingerprint,
            reason: reason
        )
        logContextDebug(input: input, state: rawState)

        lastResolvedFingerprint = fingerprint
        recomputeCount += 1
        lastRecomputeReason = reason
        state = rawState
        nextScheduledCheckpoint = CoachCheckpointScheduler.nextCheckpoint(after: input)

        logInputReadiness(
            input: input,
            reason: reason,
            readiness: readiness,
            outcome: "allowed"
        )
        logVisibleState(state: rawState, reason: reason)
        persistTodayInsightIfNeeded(from: rawState)

        return rawState
    }

    private func persistTodayInsightIfNeeded(from state: CoachState) {
        guard state.canRenderTodayCoachInsight,
              let presentation = state.coachUIPresentation,
              let selectedDate = state.input?.selectedDate else {
            return
        }

        CoachTodayInsightCache.store(
            presentation: presentation,
            dayStart: selectedDate,
            languageCode: Self.currentLanguageCode()
        )
        CoachStateStabilizer.markCoachReadyForDay(selectedDate)
    }

    private static func currentLanguageCode() -> String {
        UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.english.rawValue
    }

    private func scheduleSettlingRetry(for input: CoachInputSnapshot, reason: String) {
        guard !reason.hasSuffix(".settlingRetry") else { return }

        settlingRetryTask?.cancel()
        let retryReason = "\(reason).settlingRetry"
        let task = Task { @MainActor [weak self] in
            let delay = CoachStateStabilizer.stabilizationInterval + 0.05
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            guard self.latestInput != nil else { return }
            _ = self.recomputeIfNeeded(input: input, reason: retryReason)
        }
        settlingRetryTask = task
        settlingRetryTaskForDeinit = task
    }

    private func logVisibleState(state: CoachState, reason: String) {
        let v6Summary = state.coachIntegrationDebug?.logSummary ?? "usingCoach=n/a scenario=n/a copyPack=n/a"
        CoachLogger.compact(
            "[CoachState]",
            "Coach state changed reason=\(reason) stateID=\(state.id) scenario=\(state.coachIntegrationDebug?.scenario.rawValue ?? "nil") title=\"\(state.coachUIPresentation?.todayTitle ?? "")\" \(v6Summary)"
        )
    }

    private func logInputReadiness(
        input: CoachInputSnapshot,
        reason: String,
        readiness: CoachInputReadinessAssessment,
        outcome: String
    ) {
        CoachLogger.trace(
            "[CoachInputReadiness]",
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
        let model = input.dayPriorityModel

        CoachLogger.trace(
            "[CoachContextDebug]",
            [
                "activeActivity=\(activitySummary(active))",
                "dayPrimarySession=\(activitySummary(model.primarySession))",
                "daySecondarySession=\(activitySummary(model.secondarySession))",
                "dayGoal=\(model.dayGoal.rawValue)",
                "dayStressLevel=\(model.dayStressLevel.rawValue)",
                "tomorrowDemand=\(model.tomorrowDemand.rawValue)",
                "scenario=\(state.coachIntegrationDebug?.scenario.rawValue ?? "nil")"
            ].joined(separator: " ")
        )
    }

    private func isActiveActivity(_ activity: CoachPlannedActivitySnapshot, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
        return activity.date <= now && now <= end
    }

    private func activitySummary(_ activity: CoachPlannedActivitySnapshot?) -> String {
        guard let activity else { return "nil" }
        return "\(activity.title)@\(activity.date)"
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
