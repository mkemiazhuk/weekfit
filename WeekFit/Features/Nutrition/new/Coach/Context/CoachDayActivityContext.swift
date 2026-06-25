import Foundation

// MARK: - Resolved day activity context (single source of truth)

struct CoachDayActivityContext {
    let phase: CoachActivityPhase
    let activeActivity: PlannedActivity?
    let activeActivityIdentityIsCertain: Bool
    let activeElapsedMinutes: Int?
    let activeRemainingMinutes: Int?
    let activeSessionPhase: CoachActiveSessionPhase?
    let preparingActivity: PlannedActivity?
    let recentlyCompletedActivity: PlannedActivity?
    /// Next planned item after the active session, or the next future item when nothing is active.
    let nextUpcomingActivity: PlannedActivity?
    /// Next coach-relevant activity later today, used for calm stable copy.
    let laterTodayActivity: PlannedActivity?
    let minutesUntilStart: Int?
    let minutesSinceEnd: Int?
    let isInsidePreparationWindow: Bool

    var coachFocusActivity: PlannedActivity? {
        switch phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            return activity
        case .stable:
            return nil
        }
    }

    var shouldShowPreparingFocus: Bool {
        preparingActivity != nil && isInsidePreparationWindow
    }

    /// Phase used by Today, Coach card, and Coach inside for focus messaging.
    var primaryPhase: CoachActivityPhase { phase }

    var showsImmediateCoachFocusOnToday: Bool {
        switch phase {
        case .active, .recovering:
            return true
        case .preparing:
            return isInsidePreparationWindow
        case .stable:
            return false
        }
    }

    var showsPreparingOnCoachCard: Bool {
        isInsidePreparationWindow && preparingActivity != nil
    }

    var showsPreparingOnCoachInside: Bool {
        showsPreparingOnCoachCard
    }

    var isInPreparationWindow: Bool { isInsidePreparationWindow }

    var calmNextActivity: PlannedActivity? { laterTodayActivity }
}

enum CoachActiveSessionPhase: Equatable {
    case started
    case middle
    case finishing
    case postSession
}

// MARK: - Bridge from kind/load helpers

extension CoachActivityContextResolver {

    static func resolve(
        brain: HumanBrain.State,
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date? = nil
    ) -> CoachActivityPhase {
        resolveDayContext(
            activities: activities,
            selectedDate: selectedDate,
            now: now ?? brain.now,
            brain: brain
        ).phase
    }

    static func resolveDayContext(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date(),
        brain: HumanBrain.State? = nil
    ) -> CoachDayActivityContext {
        CoachDayActivityContextResolver.resolve(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
    }

    static func stablePresentation(
        from context: CoachDayActivityContext
    ) -> (title: String, message: String) {
        (
            title: CoachDayActivityContextResolver.stableInsightTitle(context: context),
            message: CoachDayActivityContextResolver.stableInsightMessage(context: context)
        )
    }

    static func isVisibleScheduleActivity(_ activity: PlannedActivity) -> Bool {
        CoachDayActivityContextResolver.isVisibleScheduleActivity(activity)
    }
}

enum CoachDayActivityContextResolver {

    static func resolve(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date(),
        brain: HumanBrain.State? = nil
    ) -> CoachDayActivityContext {

        let calendar = Calendar.current

        let dayActivities = activities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { !$0.isSkipped }
            .sorted { $0.date < $1.date }

        let coachRelevant = CoachCanonicalDayState.coachRelevantActivities(from: dayActivities)
        let visibleScheduleActivities = coachRelevant

        let completedActivities = coachRelevant.filter { activity in
            let state = activity.terminalState(now: now)
            return state == .completed || state == .partial
        }
        let activeCandidates = coachRelevant.filter { activity in
            isActive(activity, now: now) &&
                !hasCompletedDuplicate(activity, in: completedActivities)
        }
        let active = authoritativeActive(from: activeCandidates)

        if let active {
            let kind = CoachActivityContextResolver.kind(for: active)
            let elapsed = activeElapsedMinutes(active, now: now)
            let remaining = activeRemainingMinutes(active, now: now)
            let next = nextActivity(
                after: active,
                in: visibleScheduleActivities,
                now: now
            )

            return CoachDayActivityContext(
                phase: .active(activity: active, kind: kind),
                activeActivity: active,
                activeActivityIdentityIsCertain: activeIdentityIsCertain(active, among: activeCandidates),
                activeElapsedMinutes: elapsed,
                activeRemainingMinutes: remaining,
                activeSessionPhase: activeSessionPhase(elapsed: elapsed, remaining: remaining, duration: max(active.effectiveDurationMinutes, active.durationMinutes)),
                preparingActivity: nil,
                recentlyCompletedActivity: nil,
                nextUpcomingActivity: next,
                laterTodayActivity: next ?? firstLaterCoachActivity(from: coachRelevant, after: now),
                minutesUntilStart: nil,
                minutesSinceEnd: nil,
                isInsidePreparationWindow: false
            )
        }

        let preparingCandidate = highestPriority(
            from: coachRelevant.filter { activity in
                guard activity.terminalState(now: now) == .planned else { return false }
                let minutes = minutesUntilStart(activity, now: now)
                guard minutes >= 0 else { return false }
                return minutes <= preparationLeadMinutes(for: activity)
            }
        )

        if let preparing = preparingCandidate {
            let minutes = minutesUntilStart(preparing, now: now)
            let next = nextActivity(
                after: preparing,
                in: visibleScheduleActivities,
                now: now,
                excluding: preparing
            )

            return CoachDayActivityContext(
                phase: .preparing(
                    activity: preparing,
                    kind: CoachActivityContextResolver.kind(for: preparing),
                    minutesUntil: minutes
                ),
                activeActivity: nil,
                activeActivityIdentityIsCertain: true,
                activeElapsedMinutes: nil,
                activeRemainingMinutes: nil,
                activeSessionPhase: nil,
                preparingActivity: preparing,
                recentlyCompletedActivity: nil,
                nextUpcomingActivity: next,
                laterTodayActivity: next,
                minutesUntilStart: minutes,
                minutesSinceEnd: nil,
                isInsidePreparationWindow: true
            )
        }

        let recent = highestPriority(
            from: coachRelevant.filter { activity in
                let state = activity.terminalState(now: now)
                guard state == .completed || state == .partial else { return false }
                guard isMeaningfulPostActivityTraining(activity) else { return false }
                let minutes = minutesSinceEnd(activity, now: now)
                guard minutes >= 0 else { return false }
                return minutes <= recoveryHoldMinutes(for: activity, brain: brain)
            }
        )

        if let recent {
            let kind = CoachActivityContextResolver.kind(for: recent)
            let minutesSince = minutesSinceEnd(recent, now: now)
            let next = nextActivity(
                after: recent,
                in: visibleScheduleActivities,
                now: now,
                excluding: recent
            )

            return CoachDayActivityContext(
                phase: .recovering(
                    activity: recent,
                    kind: kind,
                    minutesSinceEnd: minutesSince
                ),
                activeActivity: nil,
                activeActivityIdentityIsCertain: true,
                activeElapsedMinutes: nil,
                activeRemainingMinutes: nil,
                activeSessionPhase: .postSession,
                preparingActivity: nil,
                recentlyCompletedActivity: recent,
                nextUpcomingActivity: next,
                laterTodayActivity: next ?? firstLaterCoachActivity(from: coachRelevant, after: now),
                minutesUntilStart: nil,
                minutesSinceEnd: minutesSince,
                isInsidePreparationWindow: false
            )
        }

        let nextUpcoming = firstFutureActivity(in: visibleScheduleActivities, now: now)
        let laterCoach = firstLaterCoachActivity(from: coachRelevant, after: now)

        return CoachDayActivityContext(
            phase: .stable,
            activeActivity: nil,
            activeActivityIdentityIsCertain: true,
            activeElapsedMinutes: nil,
            activeRemainingMinutes: nil,
            activeSessionPhase: nil,
            preparingActivity: nil,
            recentlyCompletedActivity: nil,
            nextUpcomingActivity: nextUpcoming,
            laterTodayActivity: laterCoach,
            minutesUntilStart: laterCoach.map { minutesUntilStart($0, now: now) },
            minutesSinceEnd: nil,
            isInsidePreparationWindow: false
        )
    }

    static func phase(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date(),
        brain: HumanBrain.State? = nil
    ) -> CoachActivityPhase {
        resolve(
            activities: activities,
            selectedDate: selectedDate,
            now: now,
            brain: brain
        ).phase
    }

    // MARK: - Visibility

    static func isCoachRelevant(_ activity: PlannedActivity) -> Bool {
        CoachCanonicalDayState.isCoachRelevantActivity(activity)
    }

    static func isVisibleScheduleActivity(_ activity: PlannedActivity) -> Bool {
        CoachCanonicalDayState.isCoachRelevantActivity(activity)
    }

    // MARK: - Time windows

    static func preparationLeadMinutes(for activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)

        if kind == .heat {
            return 90
        }

        if kind == .recovery {
            return isWalkLike(activity) ? 15 : 30
        }

        if kind == .endurance {
            return 120
        }

        switch load {
        case .extreme, .high:
            return 120
        case .moderate:
            return 90
        case .low:
            return 90
        }
    }

    static func recoveryHoldMinutes(
        for activity: PlannedActivity,
        brain: HumanBrain.State? = nil
    ) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)

        if kind == .recovery {
            if let brain, brain.hasAnyFoodLogged {
                return isWalkLike(activity) ? 8 : 15
            }
            return isWalkLike(activity) ? 8 : 15
        }

        if kind == .heat {
            return 120
        }

        switch load {
        case .extreme:
            return 120
        case .high:
            return 120
        case .moderate:
            return 120
        case .low:
            return (kind == .workout || kind == .endurance) ? 90 : 20
        }
    }

    // MARK: - Stable copy

    static func stableInsightTitle(context: CoachDayActivityContext) -> String {
        if let later = context.laterTodayActivity {
            let kind = CoachActivityContextResolver.kind(for: later)
            if kind == .recovery {
                return "Keep recovery easy"
            }
            return "No pressure right now"
        }
        return "Day overview"
    }

    static func stableInsightMessage(context: CoachDayActivityContext) -> String {
        if let later = context.laterTodayActivity,
           let minutes = context.minutesUntilStart,
           minutes > preparationLeadMinutes(for: later) {
            let kind = CoachActivityContextResolver.kind(for: later)
            if kind == .recovery {
                return "Use the next easy block to feel better, not to add load."
            }
            return "Nothing needs chasing yet. Keep fuel, fluids, and energy steady until preparation actually matters."
        }

        if context.nextUpcomingActivity != nil {
            return "No coaching move is urgent right now. Let the plan stay in the background."
        }

        return "No urgent issue is asking for attention. Keep food, water, and movement steady."
    }

    // MARK: - Private helpers

    private static func isActive(_ activity: PlannedActivity, now: Date) -> Bool {
        activity.isActive(at: now)
    }

    private static func minutesSinceEnd(_ activity: PlannedActivity, now: Date) -> Int {
        let endDate = Calendar.current.date(
            byAdding: .minute,
            value: max(activity.effectiveDurationMinutes, activity.durationMinutes),
            to: activity.date
        ) ?? activity.date

        return Int(now.timeIntervalSince(endDate) / 60)
    }

    private static func minutesUntilStart(_ activity: PlannedActivity, now: Date) -> Int {
        max(0, Int(activity.date.timeIntervalSince(now) / 60))
    }

    private static func authoritativeActive(from activities: [PlannedActivity]) -> PlannedActivity? {
        let quickStarted = activities.filter { $0.source.lowercased() == "today" }
        if !quickStarted.isEmpty {
            return highestPriority(from: quickStarted)
        }

        return highestPriority(from: activities)
    }

    private static func hasCompletedDuplicate(
        _ activity: PlannedActivity,
        in completedActivities: [PlannedActivity]
    ) -> Bool {
        completedActivities.contains { completed in
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

    private static func activeIdentityIsCertain(
        _ selected: PlannedActivity,
        among activities: [PlannedActivity]
    ) -> Bool {
        if activities.count <= 1 { return true }

        let quickStarted = activities.filter { $0.source.lowercased() == "today" }
        return quickStarted.count == 1 && quickStarted.first?.id == selected.id
    }

    private static func highestPriority(from activities: [PlannedActivity]) -> PlannedActivity? {
        activities.max { priorityScore(for: $0) < priorityScore(for: $1) }
    }

    private static func activeElapsedMinutes(_ activity: PlannedActivity, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(activity.date) / 60))
    }

    private static func activeRemainingMinutes(_ activity: PlannedActivity, now: Date) -> Int {
        let duration = max(activity.effectiveDurationMinutes, activity.durationMinutes)
        return max(0, duration - activeElapsedMinutes(activity, now: now))
    }

    private static func activeSessionPhase(
        elapsed: Int,
        remaining: Int,
        duration: Int
    ) -> CoachActiveSessionPhase {
        if elapsed < 10 {
            return .started
        }

        if remaining <= 10 || Double(elapsed) / Double(max(duration, 1)) >= 0.8 {
            return .finishing
        }

        return .middle
    }

    private static func priorityScore(for activity: PlannedActivity) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)

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

    private static func nextActivity(
        after reference: PlannedActivity,
        in activities: [PlannedActivity],
        now: Date,
        excluding: PlannedActivity? = nil
    ) -> PlannedActivity? {
        let referenceEnd = Calendar.current.date(
            byAdding: .minute,
            value: max(reference.effectiveDurationMinutes, reference.durationMinutes),
            to: reference.date
        ) ?? reference.date

        return activities
            .filter { activity in
                guard activity.terminalState(now: now) == .planned else { return false }
                if let excluding, activity.id == excluding.id { return false }
                if activity.id == reference.id { return false }
                return activity.date >= referenceEnd && activity.date > now
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func firstFutureActivity(
        in activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter { $0.terminalState(now: now) == .planned && $0.date > now }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func firstLaterCoachActivity(
        from activities: [PlannedActivity],
        after now: Date
    ) -> PlannedActivity? {
        activities
            .filter { $0.terminalState(now: now) == .planned && $0.date > now }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title)".lowercased()
        return text.contains("walk") ||
               text.contains("walking") ||
               text.contains("hike")
    }

    private static func isHydrationLog(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let image = activity.imageName.lowercased()

        return type == "hydration" ||
            image == "hydration" ||
            title.contains("water") ||
            title.contains("hydration")
    }

    private static func isNutritionPseudoActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()

        return type == "meal" ||
            title.contains("breakfast") ||
            title.contains("lunch") ||
            title.contains("dinner") ||
            title.contains("snack")
    }

    private static func isMeaningfulPostActivityTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let text = "\(activity.type) \(activity.title)".lowercased()
        let load = CoachActivityContextResolver.load(for: activity)

        guard kind != .heat,
              kind != .recovery,
              !text.contains("hydration"),
              !text.contains("water"),
              !text.contains("mobility"),
              !text.contains("stretch"),
              !text.contains("breath") else {
            return false
        }

        let duration = max(activity.effectiveDurationMinutes, activity.durationMinutes)
        guard duration >= 10 else { return false }

        if isWalkLike(activity) {
            return duration >= 30 && load != .low
        }

        return isTraining(activity) &&
            (
                load == .high ||
                load == .extreme ||
                duration >= 30 ||
                (duration >= 20 && load == .moderate)
            )
    }

    private static func isTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolver.kind(for: activity)
        guard kind == .workout || kind == .endurance else { return false }

        let text = "\(activity.type) \(activity.title)".lowercased()
        return text.contains("run") ||
            text.contains("cycling") ||
            text.contains("cycle") ||
            text.contains("bike") ||
            text.contains("ride") ||
            text.contains("strength") ||
            text.contains("swim") ||
            text.contains("tennis") ||
            text.contains("squash") ||
            text.contains("workout") ||
            text.contains("training") ||
            text.contains("endurance") ||
            text.contains("interval")
    }
}

// MARK: - Activity subtitles

enum CoachActivitySubtitle {

    static func displaySubtitle(for activity: PlannedActivity) -> String {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        switch kind {
        case .meal:
            if title.contains("breakfast") {
                return "Morning fuel"
            }
            if title.contains("snack") {
                return "Energy support"
            }
            if title.contains("recovery") || title.contains("post") {
                return "Recovery fuel"
            }
            return "Nutrition support"

        case .workout:
            if title.contains("strength") ||
                title.contains("upper") ||
                title.contains("lower") ||
                title.contains("gym") ||
                type.contains("strength") {
                return "Strength session"
            }
            return "Training session"

        case .endurance:
            return "Endurance session"

        case .recovery:
            if title.contains("stretch") || title.contains("mobility") || type.contains("stretch") {
                return "Mobility reset"
            }
            if isWalkLike(activity) {
                return "Easy movement"
            }
            return "Recovery session"

        case .heat:
            if title.contains("sauna") || type.contains("sauna") {
                return "Heat recovery"
            }
            return "Heat recovery"

        case .other:
            if type == "hydration" || title.contains("water") || title.contains("hydration") {
                return "Hydration support"
            }
            return "Planned activity"
        }
    }

    static func upNextSubtitle(for activity: PlannedActivity) -> String {
        displaySubtitle(for: activity)
    }

    static func upNextLine(for activity: PlannedActivity) -> String {
        upNextSubtitle(for: activity)
    }

    static func subtitle(for activity: PlannedActivity) -> String {
        displaySubtitle(for: activity)
    }

    private static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title)".lowercased()
        return text.contains("walk") ||
               text.contains("walking") ||
               text.contains("hike")
    }
}
