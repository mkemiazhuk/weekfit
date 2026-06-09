import Foundation

enum CoachStateStabilizer {
    private static let lock = NSLock()
    private static var lastVisibleGuidanceBySurface: [String: CoachGuidanceV3] = [:]
    private static var syncSettlingUntilBySurface: [String: Date] = [:]

    private static let stabilizationInterval: TimeInterval = 0.55

    static func markSyncEvent(source: String) {
        let normalized = source.lowercased()
        let surfaceKey = surfaceKey(for: normalized)

        if isRealityChangeSource(normalized) {
            lock.lock()
            lastVisibleGuidanceBySurface.removeAll()
            syncSettlingUntilBySurface.removeAll()
            lock.unlock()
            return
        }

        guard normalized.contains("health") ||
                normalized.contains("sync") ||
                normalized.contains("completedworkoutsbatch") ||
                normalized.contains("activitycoordinator") else {
            return
        }

        lock.lock()
        let nextSettlingTime = Date().addingTimeInterval(stabilizationInterval)
        let affectedSurfaces = surfaceKey == "shared" ? ["today", "coach", "shared"] : [surfaceKey]
        for affectedSurface in affectedSurfaces {
            syncSettlingUntilBySurface[affectedSurface] = max(
                syncSettlingUntilBySurface[affectedSurface] ?? Date.distantPast,
                nextSettlingTime
            )
        }
        lock.unlock()
    }

    static func stabilized(_ candidate: CoachGuidanceV3, source: String) -> CoachGuidanceV3 {
        markSyncEvent(source: source)

        lock.lock()
        defer { lock.unlock() }

        let surfaceKey = surfaceKey(for: source)
        if let previous = lastVisibleGuidanceBySurface[surfaceKey],
           Date() < (syncSettlingUntilBySurface[surfaceKey] ?? Date.distantPast) {
            if let releaseReason = activeSessionReleaseReason(previous: previous, candidate: candidate) {
                CoachLogger.verbose(
                    "[CoachStateStabilizer]",
                    "releasing previous=\(previous.priority.priority)/\(previous.priority.focus) candidate=\(candidate.priority.priority)/\(candidate.priority.focus) source=\(source) reason=\(releaseReason)"
                )
            } else if shouldHold(previous: previous, candidate: candidate) {
                CoachLogger.verbose(
                    "[CoachStateStabilizer]",
                    "holding previous=\(previous.priority.priority)/\(previous.priority.focus) candidate=\(candidate.priority.priority)/\(candidate.priority.focus) source=\(source)"
                )
                return previous
            }
        }

        lastVisibleGuidanceBySurface[surfaceKey] = candidate
        return candidate
    }

    static func lastVisibleGuidance(source: String) -> CoachGuidanceV3? {
        lock.lock()
        defer { lock.unlock() }

        let surfaceKey = surfaceKey(for: source)
        return lastVisibleGuidanceBySurface[surfaceKey] ?? lastVisibleGuidanceBySurface["shared"]
    }

    static func visibleSignature(for candidate: CoachGuidanceV3, source: String) -> String {
        markSyncEvent(source: source)

        lock.lock()
        defer { lock.unlock() }

        let surfaceKey = surfaceKey(for: source)
        if let previous = lastVisibleGuidanceBySurface[surfaceKey],
           Date() < (syncSettlingUntilBySurface[surfaceKey] ?? Date.distantPast),
           activeSessionReleaseReason(previous: previous, candidate: candidate) == nil,
           shouldHold(previous: previous, candidate: candidate) {
            return signature(for: previous)
        }

        return signature(for: candidate)
    }

    private static func activeSessionReleaseReason(
        previous: CoachGuidanceV3,
        candidate: CoachGuidanceV3
    ) -> String? {
        let previousPriority = previous.priority
        let candidatePriority = candidate.priority

        guard isActiveSessionContext(previousPriority) else {
            return nil
        }

        if let previousActivity = previousPriority.activity {
            if previousActivity.isCompleted {
                return "previous active activity completed \(activitySummary(previousActivity))"
            }
            if previousActivity.isSkipped {
                return "previous active activity skipped \(activitySummary(previousActivity))"
            }
        }

        guard isActiveSessionContext(candidatePriority) else {
            return "candidate priority is \(candidatePriority.priority)/\(candidatePriority.focus); active session is no longer selected"
        }

        guard let candidateActivity = candidatePriority.activity else {
            return "candidate active session has no selected activity"
        }

        if candidateActivity.isCompleted {
            return "candidate active activity completed \(activitySummary(candidateActivity))"
        }
        if candidateActivity.isSkipped {
            return "candidate active activity skipped \(activitySummary(candidateActivity))"
        }

        if let previousActivity = previousPriority.activity,
           previousActivity.id != candidateActivity.id {
            return "candidate selected different activity previous=\(activitySummary(previousActivity)) candidate=\(activitySummary(candidateActivity))"
        }

        return nil
    }

    private static func shouldHold(previous: CoachGuidanceV3, candidate: CoachGuidanceV3) -> Bool {
        guard isDowngrade(from: previous.priority, to: candidate.priority) else {
            return false
        }

        if isImmediateUpgrade(candidate.priority) {
            return false
        }

        if previous.priority.focus == .postActivityRecovery &&
            (candidate.priority.focus == .performanceReadiness ||
             candidate.priority.focus == .dailyOverview ||
             candidate.priority.priority == .stable) {
            return true
        }

        if isActivityContext(previous.priority),
           isGenericFallback(candidate.priority) {
            return true
        }

        return priorityScore(candidate.priority) + 120 < priorityScore(previous.priority)
    }

    private static func surfaceKey(for source: String) -> String {
        let normalized = source.lowercased()
        if normalized.contains("todayview") {
            return "today"
        }
        if normalized.contains("expertcoachview") || normalized.contains("coachscreen") {
            return "coach"
        }
        return "shared"
    }

    private static func isRealityChangeSource(_ normalized: String) -> Bool {
        normalized.contains("plannedactivities") ||
            normalized.contains("activitynotificationaction") ||
            normalized.contains("liveworkout") ||
            normalized.contains("water") ||
            normalized.contains("meal") ||
            normalized.contains("save") ||
            normalized.contains("delete") ||
            normalized.contains("remove") ||
            normalized.contains("completed") ||
            normalized.contains("skipped")
    }

    private static func isDowngrade(from previous: CoachDayPriorityResult, to candidate: CoachDayPriorityResult) -> Bool {
        priorityScore(candidate) < priorityScore(previous)
    }

    private static func isImmediateUpgrade(_ priority: CoachDayPriorityResult) -> Bool {
        priority.focus == .activeActivity ||
            priority.focus == .postActivityRecovery ||
            priority.priority == .hydration ||
            priority.priority == .fueling ||
            priority.strength == .critical
    }

    private static func isActivityContext(_ priority: CoachDayPriorityResult) -> Bool {
        priority.focus == .activeActivity ||
            priority.focus == .prepareForActivity ||
            priority.focus == .postActivityRecovery ||
            priority.focus == .nextActivityLater
    }

    private static func isActiveSessionContext(_ priority: CoachDayPriorityResult) -> Bool {
        priority.priority == .activeSession ||
            priority.focus == .activeActivity
    }

    private static func isGenericFallback(_ priority: CoachDayPriorityResult) -> Bool {
        priority.focus == .dailyOverview ||
            priority.focus == .performanceReadiness ||
            priority.priority == .stable
    }

    private static func priorityScore(_ priority: CoachDayPriorityResult) -> Int {
        switch priority.focus {
        case .activeActivity:
            return 700
        case .postActivityRecovery:
            return 620
        case .trainingReadinessWarning, .tomorrowPlanRisk:
            return 560
        case .prepareForActivity:
            return 500
        case .hydrationBehind, .fuelBehind, .recoveryNeeded:
            return 460
        case .nextActivityLater:
            return 340
        case .performanceReadiness:
            return 260
        case .eveningWindDown:
            return 220
        case .dailyOverview:
            return priority.priority == .stable ? 120 : 180
        }
    }

    private static func signature(for guidance: CoachGuidanceV3) -> String {
        let priority = guidance.priority
        let story = guidance.screenStory
        return [
            "\(guidance.phase)",
            "\(guidance.shouldSurface)",
            guidance.stateLabel,
            guidance.title,
            guidance.message,
            guidance.insightTitle,
            guidance.insightSubtitle ?? "nil",
            "\(priority.priority)",
            "\(priority.focus)",
            "\(priority.limiter)",
            priority.todayTitle,
            priority.todayMessage,
            priority.detailTitle,
            priority.detailMessage,
            priority.activity?.id ?? "none",
            priority.supportBullets.joined(separator: "|"),
            guidance.supportActions.map { "\($0.title):\($0.subtitle)" }.joined(separator: "|"),
            story?.myRead ?? "nil",
            story?.myRecommendation ?? "nil",
            story?.beCarefulWith ?? "nil",
            story?.primaryActions.map { "\($0.title):\($0.subtitle)" }.joined(separator: "|") ?? "nil"
        ].joined(separator: "#")
    }

    private static func activitySummary(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return "id=\(activity.id) title=\"\(title)\" completed=\(activity.isCompleted) skipped=\(activity.isSkipped)"
    }
}
