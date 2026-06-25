import Foundation

enum CoachDayType {
    case open
    case recovery
    case strength
    case endurance
    case mixed
    case highLoad
}

enum CoachDayRisk {
    case low
    case moderate
    case high
}

struct CoachDayContext {

    let date: Date
    let now: Date

    let allActivities: [PlannedActivity]

    let completedActivities: [PlannedActivity]
    let partialActivities: [PlannedActivity]
    let upcomingActivities: [PlannedActivity]
    let skippedActivities: [PlannedActivity]
    let missedActivities: [PlannedActivity]

    let nextActivity: PlannedActivity?
    let followingActivity: PlannedActivity?
    let lastCompletedActivity: PlannedActivity?

    let completedWorkoutsCount: Int
    let upcomingWorkoutsCount: Int

    let completedRecoveryCount: Int
    let upcomingRecoveryCount: Int

    let completedMealsCount: Int
    let upcomingMealsCount: Int

    let completedMinutes: Int
    let upcomingMinutes: Int
    let totalPlannedMinutes: Int

    // Activity volume = all movement / recovery volume
    let completedActivityVolumeMinutes: Int
    let upcomingActivityVolumeMinutes: Int
    let totalActivityVolumeMinutes: Int

    // Training stress = real training demand only
    let completedTrainingActivities: [PlannedActivity]
    let upcomingTrainingActivities: [PlannedActivity]

    let completedTrainingMinutes: Int
    let upcomingTrainingMinutes: Int
    let totalTrainingMinutes: Int

    let completedTrainingStressScore: Int
    let upcomingTrainingStressScore: Int
    let totalTrainingStressScore: Int

    // Backward-compatible names used by existing CoachView code.
    // These now mean training stress, not total recovery volume.
    let completedLoadScore: Int
    let upcomingLoadScore: Int
    let totalLoadScore: Int

    let dayType: CoachDayType
    let dayRisk: CoachDayRisk

    let hasTrainingToday: Bool
    let hasRecoveryToday: Bool
    let hasMultipleSessions: Bool
    let hasMoreLoadAhead: Bool
    let hasMeaningfulLoadCompleted: Bool
}

enum CoachDayContextBuilder {

    static func build(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date()
    ) -> CoachDayContext {

        let calendar = Calendar.current

        let rawDayActivities = activities
            .filter {
                calendar.isDate($0.date, inSameDayAs: selectedDate)
            }
            .sorted {
                $0.date < $1.date
            }

        let dayActivities = CoachCanonicalDayState.coachRelevantActivities(from: rawDayActivities)
        let partial = dayActivities.filter(\.isPartialCompletion)
        let completed = dayActivities.filter(\.isFullCompletion)
        let skipped = dayActivities.filter { $0.isSkipped }

        let upcoming = dayActivities.filter { activity in
            activity.terminalState(now: now) == .planned &&
            activity.date >= now
        }

        let missed = dayActivities.filter { activity in
            let end = activityEnd(activity)

            return activity.terminalState(now: now) == .planned &&
                   now > end
        }

        let nextActivity = upcoming.first
        let followingActivity = upcoming.dropFirst().first

        let lastCompletedActivity = completed
            .sorted { $0.date > $1.date }
            .first

        let partialTrainingActivities = partial.filter { isTrainingStress($0) }
        let completedTrainingActivities = completed.filter { isTrainingStress($0) }
        let upcomingTrainingActivities = upcoming.filter { isTrainingStress($0) }

        let completedRecovery = completed.filter { isRecovery($0) }
        let upcomingRecovery = upcoming.filter { isRecovery($0) }

        let completedMeals = CoachCanonicalDayState.completedMeals(from: rawDayActivities)
        let upcomingMeals = rawDayActivities.filter {
            CoachCanonicalDayState.isNutritionLog($0) &&
                !CoachCanonicalDayState.isHydrationLog($0) &&
                !$0.isCompleted &&
                !$0.isSkipped &&
                $0.date >= now
        }

        let completedMinutes = completed.reduce(0) {
            $0 + effectiveMinutes($1)
        }

        let partialMinutes = partial.reduce(0) {
            $0 + effectiveMinutes($1)
        }

        let upcomingMinutes = upcoming.reduce(0) {
            $0 + effectiveMinutes($1)
        }

        let totalPlannedMinutes = dayActivities.reduce(0) {
            $0 + effectiveMinutes($1)
        }

        let completedActivityVolumeMinutes = (completed + partial)
            .filter { isActivityVolume($0) }
            .reduce(0) {
                $0 + effectiveMinutes($1)
            }

        let upcomingActivityVolumeMinutes = upcoming
            .filter { isActivityVolume($0) }
            .reduce(0) {
                $0 + effectiveMinutes($1)
            }

        let totalActivityVolumeMinutes = dayActivities
            .filter { isActivityVolume($0) }
            .reduce(0) {
                $0 + effectiveMinutes($1)
            }

        let completedTrainingMinutes = (completedTrainingActivities + partialTrainingActivities).reduce(0) {
            $0 + effectiveMinutes($1)
        }

        let upcomingTrainingMinutes = upcomingTrainingActivities.reduce(0) {
            $0 + effectiveMinutes($1)
        }

        let totalTrainingMinutes = completedTrainingMinutes + upcomingTrainingMinutes

        let completedTrainingStressScore = (completedTrainingActivities + partialTrainingActivities).reduce(0) {
            $0 + trainingStressScore(for: $1)
        }

        let upcomingTrainingStressScore = upcomingTrainingActivities.reduce(0) {
            $0 + trainingStressScore(for: $1)
        }

        let totalTrainingStressScore =
            completedTrainingStressScore + upcomingTrainingStressScore

        let trainingCount =
            completedTrainingActivities.count + upcomingTrainingActivities.count

        let recoveryCount =
            completedRecovery.count + upcomingRecovery.count

        let hasTrainingToday = trainingCount > 0
        let hasRecoveryToday = recoveryCount > 0

        let hasMultipleSessions =
            trainingCount >= 2 ||
            totalTrainingStressScore >= 5

        let hasMoreLoadAhead =
            upcomingTrainingStressScore >= 2 ||
            upcomingTrainingActivities.count > 0

        let hasMeaningfulLoadCompleted =
            completedTrainingStressScore >= 2 ||
            completedTrainingActivities.count > 0

        let dayType = resolveDayType(
            activities: dayActivities,
            trainingActivities: completedTrainingActivities + upcomingTrainingActivities,
            recoveryCount: recoveryCount,
            trainingStressScore: totalTrainingStressScore
        )

        let dayRisk = resolveDayRisk(
            completedTrainingStressScore: completedTrainingStressScore,
            upcomingTrainingStressScore: upcomingTrainingStressScore,
            trainingCount: trainingCount,
            totalTrainingMinutes: totalTrainingMinutes,
            missedCount: missed.count
        )

        return CoachDayContext(
            date: selectedDate,
            now: now,
            allActivities: dayActivities,
            completedActivities: completed,
            partialActivities: partial,
            upcomingActivities: upcoming,
            skippedActivities: skipped,
            missedActivities: missed,
            nextActivity: nextActivity,
            followingActivity: followingActivity,
            lastCompletedActivity: lastCompletedActivity,
            completedWorkoutsCount: completedTrainingActivities.count,
            upcomingWorkoutsCount: upcomingTrainingActivities.count,
            completedRecoveryCount: completedRecovery.count,
            upcomingRecoveryCount: upcomingRecovery.count,
            completedMealsCount: completedMeals.count,
            upcomingMealsCount: upcomingMeals.count,
            completedMinutes: completedMinutes + partialMinutes,
            upcomingMinutes: upcomingMinutes,
            totalPlannedMinutes: totalPlannedMinutes,
            completedActivityVolumeMinutes: completedActivityVolumeMinutes,
            upcomingActivityVolumeMinutes: upcomingActivityVolumeMinutes,
            totalActivityVolumeMinutes: totalActivityVolumeMinutes,
            completedTrainingActivities: completedTrainingActivities,
            upcomingTrainingActivities: upcomingTrainingActivities,
            completedTrainingMinutes: completedTrainingMinutes,
            upcomingTrainingMinutes: upcomingTrainingMinutes,
            totalTrainingMinutes: totalTrainingMinutes,
            completedTrainingStressScore: completedTrainingStressScore,
            upcomingTrainingStressScore: upcomingTrainingStressScore,
            totalTrainingStressScore: totalTrainingStressScore,
            completedLoadScore: completedTrainingStressScore,
            upcomingLoadScore: upcomingTrainingStressScore,
            totalLoadScore: totalTrainingStressScore,
            dayType: dayType,
            dayRisk: dayRisk,
            hasTrainingToday: hasTrainingToday,
            hasRecoveryToday: hasRecoveryToday,
            hasMultipleSessions: hasMultipleSessions,
            hasMoreLoadAhead: hasMoreLoadAhead,
            hasMeaningfulLoadCompleted: hasMeaningfulLoadCompleted
        )
    }
}

// MARK: - Helpers

private extension CoachDayContextBuilder {

    static func activityEnd(_ activity: PlannedActivity) -> Date {
        Calendar.current.date(
            byAdding: .minute,
            value: effectiveMinutes(activity),
            to: activity.date
        ) ?? activity.date
    }

    static func effectiveMinutes(_ activity: PlannedActivity) -> Int {
        max(activity.effectiveDurationMinutes, 0)
    }

    static func isActivityVolume(_ activity: PlannedActivity) -> Bool {
        guard !isHydrationLog(activity) else { return false }

        let kind = CoachActivityContextResolver.kind(for: activity)

        return kind == .workout ||
               kind == .endurance ||
               kind == .heat ||
               kind == .recovery
    }

    static func isTrainingStress(_ activity: PlannedActivity) -> Bool {
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

    static func isRecovery(_ activity: PlannedActivity) -> Bool {
        guard !isHydrationLog(activity) else { return false }

        return CoachActivityContextResolver.kind(for: activity) == .recovery
    }

    static func isMeal(_ activity: PlannedActivity) -> Bool {
        CoachActivityContextResolver.kind(for: activity) == .meal
    }

    static func isHydrationLog(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let image = activity.imageName.lowercased()

        return type == "hydration" ||
            image == "hydration" ||
            title.contains("water") ||
            title.contains("hydration")
    }

    static func trainingStressScore(for activity: PlannedActivity) -> Int {
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
            case .low:
                return 1
            case .moderate:
                return 2
            case .high:
                return 3
            case .extreme:
                return 5
            }

        case .endurance:
            switch load {
            case .low:
                return 1
            case .moderate:
                return 2
            case .high:
                return 4
            case .extreme:
                return 6
            }

        case .heat, .recovery, .meal, .other:
            return 0
        }
    }

    static func resolveDayType(
        activities: [PlannedActivity],
        trainingActivities: [PlannedActivity],
        recoveryCount: Int,
        trainingStressScore: Int
    ) -> CoachDayType {

        guard !activities.isEmpty else {
            return .open
        }

        let trainingCount = trainingActivities.count

        if trainingStressScore >= 7 || trainingCount >= 3 {
            return .highLoad
        }

        if trainingCount == 0 && recoveryCount > 0 {
            return .recovery
        }

        let enduranceCount = trainingActivities.filter {
            CoachActivityContextResolver.kind(for: $0) == .endurance
        }.count

        let strengthCount = trainingActivities.filter {
            CoachActivityContextResolver.kind(for: $0) == .workout
        }.count

        if enduranceCount > 0 && strengthCount > 0 {
            return .mixed
        }

        if enduranceCount > 0 {
            return .endurance
        }

        if strengthCount > 0 {
            return .strength
        }

        if recoveryCount > 0 {
            return .recovery
        }

        return .open
    }

    static func resolveDayRisk(
        completedTrainingStressScore: Int,
        upcomingTrainingStressScore: Int,
        trainingCount: Int,
        totalTrainingMinutes: Int,
        missedCount: Int
    ) -> CoachDayRisk {

        let totalStress =
            completedTrainingStressScore + upcomingTrainingStressScore

        if totalStress >= 8 ||
            trainingCount >= 3 ||
            totalTrainingMinutes >= 150 {
            return .high
        }

        if totalStress >= 5 ||
            trainingCount == 2 ||
            totalTrainingMinutes >= 90 ||
            missedCount >= 2 {
            return .moderate
        }

        return .low
    }
}
