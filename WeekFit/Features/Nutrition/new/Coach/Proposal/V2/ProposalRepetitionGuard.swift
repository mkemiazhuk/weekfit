import Foundation

/// Suppresses optional Morning Adjustment creates that were already offered recently.
/// Safety adjustments (shorten / move / skip) are never suppressed.
enum ProposalRepetitionGuard {

    /// Calendar days to look back (excluding today). Same optional create within this window is dropped.
    static let cooloffDays = 2

    static func shouldSuppress(
        _ candidate: ProposalCandidate,
        context: DailyContext
    ) -> Bool {
        guard isOptionalCreate(candidate.kind) else { return false }
        return ProposalOfferHistoryStore.wasRecentlyOffered(
            changeId: candidate.id,
            excludingDayKey: context.dayKey,
            lookingBackDays: cooloffDays,
            referenceDate: context.now
        )
    }

    private static func isOptionalCreate(_ kind: CoachChangeKind) -> Bool {
        switch kind {
        case .createPlannedActivity, .createRecoveryWalk:
            return true
        case .createMealFromLibrary, .modifyDuration, .moveActivity, .skipActivity, .guidanceOnly:
            return false
        }
    }
}
