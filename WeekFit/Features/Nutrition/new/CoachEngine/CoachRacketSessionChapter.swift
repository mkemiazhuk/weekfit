import Foundation

/// Narrative chapter inside a racket session arc. Copy layer only — owners unchanged.
enum CoachRacketSessionChapter: Equatable {
    case warmIn
    case findRhythm
    case manageLoad
    case closeSmart
    case recoveryWindow

    var catalogPhase: CoachRacketDuringPostCopyCatalog.Phase {
        switch self {
        case .warmIn: return .warmIn
        case .findRhythm: return .findRhythm
        case .manageLoad: return .manageLoad
        case .closeSmart: return .closeSmart
        case .recoveryWindow: return .recoveryWindow
        }
    }
}

enum CoachRacketSessionChapterResolver {

    /// Returns `nil` for sessions under 60 min — flat racket copy applies.
    static func duringSessionChapter(
        durationMinutes: Int,
        elapsedMinutes: Int,
        remainingMinutes: Int? = nil
    ) -> CoachRacketSessionChapter? {
        let total = max(durationMinutes, 1)
        guard total >= 60 else { return nil }

        let warmInEnd = total >= 120 ? 20 : 15
        if elapsedMinutes <= warmInEnd {
            return .warmIn
        }

        let closeStart = closeSmartStartElapsedMinutes(durationMinutes: total)
        if elapsedMinutes >= closeStart {
            return .closeSmart
        }

        if total >= 90 {
            let rhythmEnd = warmInEnd + findRhythmMinutes(durationMinutes: total)
            if elapsedMinutes < rhythmEnd {
                return .findRhythm
            }
        }

        return .manageLoad
    }

    static func postChapter(
        durationMinutes: Int,
        minutesSinceEnd: Int
    ) -> CoachRacketSessionChapter? {
        guard durationMinutes >= 60, minutesSinceEnd <= 60 else { return nil }
        return .recoveryWindow
    }

    /// Close Smart begins at the earlier of: last 30 minutes, or 75% of planned duration elapsed.
    static func closeSmartStartElapsedMinutes(durationMinutes: Int) -> Int {
        let total = max(durationMinutes, 1)
        let threeQuarters = Int((Double(total) * 0.75).rounded(.down))
        return max(threeQuarters, total - 30)
    }

    private static func findRhythmMinutes(durationMinutes: Int) -> Int {
        durationMinutes >= 120 ? 40 : 30
    }
}

/// Shared racket arc context for Coach and Today — one chapter model, two surfaces.
enum CoachRacketNarrativeContextResolver {

    enum Phase: Equatable {
        case during
        case postRecoveryWindow
    }

    struct ResolvedContext: Equatable {
        let phase: Phase
        let chapter: CoachRacketSessionChapter
    }

    static func resolve(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> ResolvedContext? {
        guard let activity = CoachPresentationNarrativeContract.focusActivity(story: story, input: input),
              isRacketLike(activity) else {
            return nil
        }

        let durationMinutes = sessionDurationMinutes(for: activity)
        let context = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now
        )

        if let active = context.activeActivity,
           !active.isCompleted,
           active.id == activity.id,
           let chapter = CoachRacketSessionChapterResolver.duringSessionChapter(
               durationMinutes: durationMinutes,
               elapsedMinutes: CoachEnduranceDuringPostCopyCatalog.elapsedMinutes(activity: activity, now: input.now),
               remainingMinutes: CoachEnduranceDuringPostCopyCatalog.remainingMinutes(activity: activity, now: input.now)
           ) {
            return ResolvedContext(phase: .during, chapter: chapter)
        }

        if activity.isCompleted {
            let minutesSinceEnd = CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(activity: activity, now: input.now)
            if let chapter = CoachRacketSessionChapterResolver.postChapter(
                durationMinutes: durationMinutes,
                minutesSinceEnd: minutesSinceEnd
            ) {
                return ResolvedContext(phase: .postRecoveryWindow, chapter: chapter)
            }
        }

        return nil
    }

    static func isActiveRacketSession(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> Bool {
        guard let context = resolve(story: story, input: input) else { return false }
        return context.phase == .during
    }

    private static func sessionDurationMinutes(for activity: PlannedActivity) -> Int {
        max(max(activity.effectiveDurationMinutes, activity.durationMinutes), 1)
    }

    private static func isRacketLike(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        return text.contains("tennis") || text.contains("squash") || text.contains("racket")
    }
}
