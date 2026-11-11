import Foundation

/// Decides when Today may appear. The first frame should already contain the
/// sections whose presence depends on Health, Maya, and the morning proposal,
/// so those blocks do not insert after the screen is visible.
struct TodayFirstPaintGate: Equatable {
    var healthFirstPassDone: Bool
    var mayaAccessResolved: Bool
    /// True after the post-health proposal debounce has had time to land.
    var proposalDebounceSettled: Bool
    var timedOut: Bool
    /// UI tests and screenshot fixtures paint immediately.
    var bypass: Bool

    var shouldReveal: Bool {
        if bypass || timedOut { return true }
        return healthFirstPassDone && mayaAccessResolved && proposalDebounceSettled
    }
}
