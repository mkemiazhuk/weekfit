import Foundation

/// Narrative chapter inside an endurance session arc. Lives in the copy layer only —
/// `CoachFinalStoryOwner` stays unchanged (`pacingExecution`, `sustainableExecution`, …).
enum CoachEnduranceSessionChapter: Equatable {
    case opening
    case establish
    case maintain
    case protect
    case recoveryWindow

    var catalogPhase: CoachEnduranceDuringPostCopyCatalog.Phase {
        switch self {
        case .opening: return .opening
        case .establish: return .establish
        case .maintain: return .maintain
        case .protect: return .protect
        case .recoveryWindow: return .recoveryWindow
        }
    }
}

enum CoachEnduranceSessionChapterResolver {

    /// Returns `nil` for short sessions (< 60 min) where legacy flat pacing/sustainable copy applies.
    static func duringSessionChapter(
        durationMinutes: Int,
        elapsedMinutes: Int,
        remainingMinutes: Int? = nil
    ) -> CoachEnduranceSessionChapter? {
        let total = max(durationMinutes, 1)
        guard total >= 60 else { return nil }

        let openingEnd = total >= 120 ? 20 : 15
        if elapsedMinutes <= openingEnd {
            return .opening
        }

        let protectStartElapsed = protectStartElapsedMinutes(durationMinutes: total)
        if elapsedMinutes >= protectStartElapsed {
            return .protect
        }

        if total >= 120 {
            if elapsedMinutes < 60 {
                return .establish
            }
            return .maintain
        }

        if elapsedMinutes < 45 {
            return .establish
        }
        return .maintain
    }

    /// First hour after a significant endurance session ends.
    static func postChapter(
        durationMinutes: Int,
        minutesSinceEnd: Int
    ) -> CoachEnduranceSessionChapter? {
        guard durationMinutes >= 60, minutesSinceEnd <= 60 else { return nil }
        return .recoveryWindow
    }

    /// Protect begins at the earlier of: last 60 minutes, or 75% of planned duration elapsed.
    static func protectStartElapsedMinutes(durationMinutes: Int) -> Int {
        let total = max(durationMinutes, 1)
        let threeQuarters = Int((Double(total) * 0.75).rounded(.down))
        return max(threeQuarters, total - 60)
    }
}

/// Shared endurance arc context for Coach and Today — one chapter model, two surfaces.
enum CoachEnduranceNarrativeContextResolver {

    enum Phase: Equatable {
        case during
        case postRecoveryWindow
    }

    struct ResolvedContext: Equatable {
        let phase: Phase
        let chapter: CoachEnduranceSessionChapter
    }

    static func resolve(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> ResolvedContext? {
        guard let activity = CoachPresentationNarrativeContract.focusActivity(story: story, input: input),
              isEnduranceLike(activity) else {
            return nil
        }

        let durationMinutes = enduranceDurationMinutes(for: activity)
        let context = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.plannedActivities,
            selectedDate: input.selectedDate,
            now: input.now
        )

        if let active = context.activeActivity,
           !active.isCompleted,
           active.id == activity.id,
           let chapter = CoachEnduranceSessionChapterResolver.duringSessionChapter(
               durationMinutes: durationMinutes,
               elapsedMinutes: CoachEnduranceDuringPostCopyCatalog.elapsedMinutes(activity: activity, now: input.now),
               remainingMinutes: CoachEnduranceDuringPostCopyCatalog.remainingMinutes(activity: activity, now: input.now)
           ) {
            return ResolvedContext(phase: .during, chapter: chapter)
        }

        if activity.isCompleted {
            let minutesSinceEnd = CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(activity: activity, now: input.now)
            if let chapter = CoachEnduranceSessionChapterResolver.postChapter(
                durationMinutes: durationMinutes,
                minutesSinceEnd: minutesSinceEnd
            ) {
                return ResolvedContext(phase: .postRecoveryWindow, chapter: chapter)
            }
        }

        return nil
    }

    static func isActiveEnduranceSession(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> Bool {
        guard let context = resolve(story: story, input: input) else { return false }
        return context.phase == .during
    }

    private static func enduranceDurationMinutes(for activity: PlannedActivity) -> Int {
        max(max(activity.effectiveDurationMinutes, activity.durationMinutes), 1)
    }

    private static func isEnduranceLike(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = "\(activity.title) \(activity.type)".lowercased()
        return kind == .endurance ||
            text.contains("run") ||
            text.contains("cycling") ||
            text.contains("ride") ||
            text.contains("bike") ||
            text.contains("bicycle")
    }
}
