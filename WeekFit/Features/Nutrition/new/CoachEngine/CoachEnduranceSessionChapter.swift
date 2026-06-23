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
