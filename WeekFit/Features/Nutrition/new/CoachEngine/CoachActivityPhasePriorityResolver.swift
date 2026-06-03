import Foundation

enum CoachActivityPhasePriorityResolver {

    static func resolve(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date()
    ) -> CoachActivityPhaseV3 {

        let calendar = Calendar.current

        let dayActivities = activities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { !$0.isSkipped }
            .filter { isCoachRelevant($0) }

        if let active = highestPriorityActivity(from: activeActivities(dayActivities, now: now)) {
            return .active(
                activity: active,
                kind: CoachActivityContextResolverV3.kind(for: active)
            )
        }

        // Upcoming recovery/workout should beat tiny completed recovery like walk.
        if let upcoming = highestPriorityActivity(from: upcomingActivities(dayActivities, now: now)) {
            return .preparing(
                activity: upcoming,
                kind: CoachActivityContextResolverV3.kind(for: upcoming),
                minutesUntil: minutesUntilStart(upcoming, now: now)
            )
        }

        if let recent = highestPriorityActivity(from: recentCompletedActivities(dayActivities, now: now)) {
            return .recovering(
                activity: recent,
                kind: CoachActivityContextResolverV3.kind(for: recent),
                minutesSinceEnd: minutesSinceActivityEnd(recent, now: now)
            )
        }

        return .stable
    }

    // MARK: - Filters

    private static func isCoachRelevant(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let image = activity.imageName.lowercased()
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        if type == "meal" { return false }
        if kind == .meal { return false }

        if type == "hydration" { return false }
        if image == "hydration" { return false }
        if title.contains("water") { return false }
        if title.contains("hydration") { return false }

        return kind == .workout ||
               kind == .endurance ||
               kind == .recovery ||
               kind == .heat
    }

    // MARK: - Phase Buckets

    private static func activeActivities(
        _ activities: [PlannedActivity],
        now: Date
    ) -> [PlannedActivity] {
        activities.filter { activity in
            guard !activity.isCompleted else { return false }

            let endDate = Calendar.current.date(
                byAdding: .minute,
                value: max(activity.effectiveDurationMinutes, activity.durationMinutes),
                to: activity.date
            ) ?? activity.date

            return activity.date <= now && now <= endDate
        }
    }

    private static func recentCompletedActivities(
        _ activities: [PlannedActivity],
        now: Date
    ) -> [PlannedActivity] {
        activities.filter { activity in
            guard activity.isCompleted else { return false }

            let minutes = minutesSinceActivityEnd(activity, now: now)
            guard minutes >= 0 else { return false }

            return minutes <= recoveryHoldMinutes(for: activity)
        }
    }

    private static func upcomingActivities(
        _ activities: [PlannedActivity],
        now: Date
    ) -> [PlannedActivity] {
        activities.filter { activity in
            guard !activity.isCompleted else { return false }

            let minutes = minutesUntilStart(activity, now: now)
            return minutes >= 0 && minutes <= preparationLookaheadMinutes(for: activity)
        }
    }

    // MARK: - Priority

    private static func highestPriorityActivity(
        from activities: [PlannedActivity]
    ) -> PlannedActivity? {
        activities.max {
            priorityScore(for: $0) < priorityScore(for: $1)
        }
    }

    private static func priorityScore(for activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)

        var score = 0

        switch kind {
        case .workout:
            score += 500
        case .endurance:
            score += 450
        case .heat:
            score += 350
        case .recovery:
            score += 260
        case .meal, .other:
            score -= 1000
        }

        switch load {
        case .extreme:
            score += 160
        case .high:
            score += 120
        case .moderate:
            score += 70
        case .low:
            score += 20
        }

        score += min(max(activity.effectiveDurationMinutes, activity.durationMinutes), 180) / 3

        if isWalkLike(activity) {
            score -= 35
        }

        return score
    }

    // MARK: - Windows

    private static func recoveryHoldMinutes(for activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)

        if kind == .recovery {
            return isWalkLike(activity) ? 8 : 15
        }

        switch load {
        case .extreme:
            return 90
        case .high:
            return 75
        case .moderate:
            return 45
        case .low:
            return 20
        }
    }

    private static func preparationLookaheadMinutes(for activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)

        if kind == .recovery {
            return 120
        }

        switch load {
        case .extreme, .high:
            return 120
        case .moderate:
            return 90
        case .low:
            return 45
        }
    }

    // MARK: - Helpers

    private static func minutesSinceActivityEnd(
        _ activity: PlannedActivity,
        now: Date
    ) -> Int {
        let endDate = Calendar.current.date(
            byAdding: .minute,
            value: max(activity.effectiveDurationMinutes, activity.durationMinutes),
            to: activity.date
        ) ?? activity.date

        return Int(now.timeIntervalSince(endDate) / 60)
    }

    private static func minutesUntilStart(
        _ activity: PlannedActivity,
        now: Date
    ) -> Int {
        max(0, Int(activity.date.timeIntervalSince(now) / 60))
    }

    private static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title)".lowercased()

        return text.contains("walk") ||
               text.contains("walking") ||
               text.contains("hike")
    }
}
