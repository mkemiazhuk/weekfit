import Foundation
import WeekFitPlanner

enum MorningAdjustmentHistoryReconciler {

    /// Lightweight reconciliation for completion paths that do not update provenance directly.
    static func reconcileRecentCompletions(
        activities: [PlannedActivity],
        referenceDate: Date,
        calendar: Calendar = .current,
        lookbackDays: Int = 14
    ) {
        guard let oldest = calendar.date(byAdding: .day, value: -lookbackDays, to: referenceDate) else {
            return
        }

        for activity in activities {
            let dayStart = calendar.startOfDay(for: activity.date)
            guard dayStart >= calendar.startOfDay(for: oldest),
                  dayStart <= calendar.startOfDay(for: referenceDate) else { continue }

            let snapshot = CoachPlannedActivitySnapshot(from: activity)
            guard snapshot.isCompleted || snapshot.isPartialCompletion else { continue }

            let dayKey = ProposalInputFingerprintBuilder.dayKey(for: dayStart, calendar: calendar)

            if let adjustment = CoachAdjustmentProvenanceStore.adjustment(forActivityId: activity.id),
               adjustment.dayKey == dayKey,
               let family = familyForAppliedAdjustment(adjustment) {
                MorningAdjustmentDayHistoryStore.merge(dayKey: dayKey) { record in
                    record.mergeOutcome(family) { outcome in
                        outcome.applied = true
                        outcome.completed = snapshot.isFullCompletion
                        outcome.partialCompletion = snapshot.isPartialCompletion
                        outcome.completedDurationMinutes = snapshot.effectiveDurationMinutes
                        outcome.provenanceActivityId = activity.id
                        outcome.provenanceChangeId = adjustment.changeId
                        outcome.origin = originForChangeId(adjustment.changeId)
                    }
                }
                continue
            }

            MorningAdjustmentDayHistoryCapture.captureUserPlannedCompletion(
                snapshot: snapshot,
                dayKey: dayKey
            )
        }
    }

    private static func familyForAppliedAdjustment(_ adjustment: AppliedCoachAdjustment) -> RecoveryMovementFamily? {
        switch adjustment.kind {
        case .createRecoveryWalk:
            return .walk
        case .createPlannedActivity:
            return RecoveryMovementFamilyResolver.family(
                forActivityTypeRaw: adjustment.appliedSnapshot.type,
                title: adjustment.appliedSnapshot.title
            )
        case .modifyDuration, .moveActivity, .skipActivity, .createMealFromLibrary, .guidanceOnly:
            return nil
        }
    }

    private static func originForChangeId(_ changeId: String) -> MovementBehaviorOrigin {
        if changeId.hasPrefix("hist-") { return .historical }
        return .morningAdjustment
    }
}

private extension RecoveryMovementFamilyResolver {
    // Removed duplicate — use shared `family(forActivityTypeRaw:title:)`.
}
