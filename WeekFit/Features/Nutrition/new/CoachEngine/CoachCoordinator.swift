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

        let guidance = decisionResolver(input)
        let nextState = CoachState.ready(
            input: input,
            fingerprint: fingerprint,
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

        CoachLogger.compact(
            "[CoachState]",
            "Coach state changed reason=\(reason) stateID=\(nextState.id) fingerprint=\(fingerprint.rawValue)"
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

        CoachLogger.compact(
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
