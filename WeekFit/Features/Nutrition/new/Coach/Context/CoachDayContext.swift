import Foundation

// MARK: - Day aggregates (input layer)
//
// Ownership: `CoachDayContext` is built once per refresh and embedded in `CoachInputSnapshot`.
// Read by focus selection, tomorrow demand, day load, upcoming-work policy, and Meals.
// Does not route scenarios directly.
//
// Field consumers (PR3 Phase A):
// - `date`, `now` — CoachInputReadiness
// - `allActivities` — CoachCoordinator logging
// - `lastCompletedActivity` — CoachFocusResolver
// - `upcomingActivities` — CoachUpcomingActivityPolicy
// - `completedActivityVolumeMinutes` — CoachEngine day load
// - `upcomingTrainingActivities/Minutes/StressScore` — CoachTomorrowDemandResolver
// - `hasMeaningfulLoadCompleted` — MealsView meal recommendations

struct CoachDayContext {

    let date: Date
    let now: Date

    /// Coach-relevant activities on the selected day (canonical filter applied).
    let allActivities: [CoachPlannedActivitySnapshot]

    let lastCompletedActivity: CoachPlannedActivitySnapshot?
    let upcomingActivities: [CoachPlannedActivitySnapshot]

    /// All movement/recovery volume completed today (minutes).
    let completedActivityVolumeMinutes: Int

    /// Training stress still ahead today — feeds tomorrow demand assessment.
    let upcomingTrainingActivities: [CoachPlannedActivitySnapshot]
    let upcomingTrainingMinutes: Int
    let upcomingTrainingStressScore: Int

    /// True when meaningful training load is already banked today.
    let hasMeaningfulLoadCompleted: Bool
}

enum CoachDayContextBuilder {

    static func build(
        activities: [CoachPlannedActivitySnapshot],
        selectedDate: Date,
        now: Date = Date()
    ) -> CoachDayContext {

        let calendar = Calendar.current

        let rawDayActivities = activities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }

        let dayActivities = CoachCanonicalDayState.coachRelevantSnapshots(from: rawDayActivities)
        let partial = dayActivities.filter(\.isPartialCompletion)
        let completed = dayActivities.filter { $0.isCompleted && !$0.isSkipped }

        let upcoming = dayActivities.filter { activity in
            activity.terminalState(now: now) == .planned && activity.date >= now
        }

        let lastCompletedActivity = completed
            .max(by: { effectiveEndDate($0) < effectiveEndDate($1) })

        let partialTrainingActivities = partial.filter { isTrainingStress($0) }
        let completedTrainingActivities = completed.filter { isTrainingStress($0) && $0.isFullCompletion }
        let upcomingTrainingActivities = upcoming.filter { isTrainingStress($0) }

        let completedActivityVolumeMinutes = completed
            .filter { isActivityVolume($0) }
            .reduce(0) { $0 + effectiveMinutes($1) }

        let completedTrainingMinutes = (completedTrainingActivities + partialTrainingActivities)
            .reduce(0) { $0 + effectiveMinutes($1) }

        let upcomingTrainingMinutes = upcomingTrainingActivities
            .reduce(0) { $0 + effectiveMinutes($1) }

        let completedTrainingStressScore = (completedTrainingActivities + partialTrainingActivities)
            .reduce(0) { $0 + trainingStressScore(for: $1) }

        let upcomingTrainingStressScore = upcomingTrainingActivities
            .reduce(0) { $0 + trainingStressScore(for: $1) }

        let hasMeaningfulLoadCompleted =
            completedTrainingStressScore >= 2 ||
            completedTrainingActivities.count > 0 ||
            partialTrainingActivities.contains { trainingStressScore(for: $0) > 0 }

        return CoachDayContext(
            date: selectedDate,
            now: now,
            allActivities: dayActivities,
            lastCompletedActivity: lastCompletedActivity,
            upcomingActivities: upcoming,
            completedActivityVolumeMinutes: completedActivityVolumeMinutes,
            upcomingTrainingActivities: upcomingTrainingActivities,
            upcomingTrainingMinutes: upcomingTrainingMinutes,
            upcomingTrainingStressScore: upcomingTrainingStressScore,
            hasMeaningfulLoadCompleted: hasMeaningfulLoadCompleted
        )
    }
}

// MARK: - Helpers

private extension CoachDayContextBuilder {

    static func effectiveMinutes(_ activity: CoachPlannedActivitySnapshot) -> Int {
        max(activity.effectiveDurationMinutes, 0)
    }

    static func effectiveEndDate(_ activity: CoachPlannedActivitySnapshot, calendar: Calendar = .current) -> Date {
        calendar.date(
            byAdding: .minute,
            value: max(activity.effectiveDurationMinutes, 1),
            to: activity.date
        ) ?? activity.date
    }

    static func isActivityVolume(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        guard !isHydrationLog(activity) else { return false }

        let kind = CoachActivityContextResolver.kind(for: activity)

        return kind == .workout ||
               kind == .endurance ||
               kind == .heat ||
               kind == .recovery
    }

    static func isTrainingStress(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        guard !isHydrationLog(activity) else { return false }

        if CoachActivityClassification.isWalkLike(activity) {
            return false
        }

        let kind = CoachActivityContextResolver.kind(for: activity)

        guard kind == .workout ||
              kind == .endurance ||
              kind == .heat else {
            return false
        }

        if kind == .heat {
            return false
        }

        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        let isEasyWalk =
            title.contains("walk") ||
            title.contains("walking") ||
            type.contains("walk") ||
            type.contains("walking")

        if isEasyWalk {
            let load = CoachActivityContextResolver.load(for: activity)
            return load == .moderate ||
                   load == .high ||
                   load == .extreme
        }

        return true
    }

    static func isHydrationLog(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let image = activity.imageName.lowercased()

        return type == "hydration" ||
            image == "hydration" ||
            title.contains("water") ||
            title.contains("hydration")
    }

    static func trainingStressScore(for activity: CoachPlannedActivitySnapshot) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)

        guard isTrainingStress(activity) else {
            return 0
        }

        if activity.isPartialCompletion {
            return activity.effectiveDurationMinutes >= 15 ? 1 : 0
        }

        let load = CoachActivityContextResolver.load(for: activity)

        switch kind {
        case .workout:
            switch load {
            case .low: return 1
            case .moderate: return 2
            case .high: return 3
            case .extreme: return 5
            }

        case .endurance:
            switch load {
            case .low: return 1
            case .moderate: return 2
            case .high: return 4
            case .extreme: return 6
            }

        case .heat, .recovery, .meal, .other:
            return 0
        }
    }
}
