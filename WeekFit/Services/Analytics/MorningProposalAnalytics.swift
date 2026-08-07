import Foundation

/// Privacy-preserving Morning Proposal analytics helpers.
/// Never logs Recovery/HRV/sleep values, activity titles, HealthKit samples, or localized copy.
enum MorningProposalAnalytics {

    private static var analytics: AnalyticsTracking { AppAnalytics.shared }

    private static let lock = NSLock()
    private static var viewedProposalIds = Set<String>()
    private static var acknowledgmentViewedDayKeys = Set<String>()

    static func proposalGenerated(
        changeCount: Int,
        guidanceCount: Int,
        strategy: DailyStrategy? = nil,
        generationMode: MorningProposalGenerationMode? = nil,
        contextConfidence: ProposalContextConfidence? = nil
    ) {
        // Coarse fields only — never recovery/HRV/sleep values or titles.
        var parameters: [String: String] = [
            AnalyticsParameterKey.selectedCountBucket: MorningProposalCountBucket(count: changeCount + guidanceCount).rawValue,
            AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
        ]
        if let strategy {
            parameters["proposal_strategy"] = strategy.rawValue
        }
        if let generationMode {
            parameters["generation_mode"] = generationMode.rawValue
        }
        if let contextConfidence {
            parameters["context_confidence"] = contextConfidence.rawValue
        }
        analytics.track(.morningProposalGenerated, parameters: parameters)
    }

    static func proposalUnavailable(reason: String) {
        analytics.track(
            .morningProposalUnavailable,
            parameters: [
                AnalyticsParameterKey.reason: sanitizeUnavailableReason(reason),
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func proposalNoChanges() {
        analytics.track(
            .morningProposalNoChanges,
            parameters: [AnalyticsParameterKey.source: AnalyticsSource.today.rawValue]
        )
    }

    static func proposalViewed(proposalId: String, changeCount: Int) {
        lock.lock()
        let unseen = viewedProposalIds.insert(proposalId).inserted
        lock.unlock()
        guard unseen else { return }
        analytics.track(
            .morningProposalViewed,
            parameters: [
                AnalyticsParameterKey.selectedCountBucket: MorningProposalCountBucket(count: changeCount).rawValue,
                AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.today.rawValue
            ]
        )
    }

    static func reviewOpened(changeCount: Int) {
        analytics.track(
            .morningProposalReviewOpened,
            parameters: [
                AnalyticsParameterKey.selectedCountBucket: MorningProposalCountBucket(count: changeCount).rawValue,
                AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.review.rawValue
            ]
        )
    }

    static func recommendationSelected(kind: CoachChangeKind, reason: CoachProposalReasonCode) {
        analytics.track(
            .morningProposalRecommendationSelected,
            parameters: [
                AnalyticsParameterKey.changeKind: kind.analyticsRawValue,
                AnalyticsParameterKey.reasonCategory: MorningProposalReasonCategory(reason).rawValue
            ]
        )
    }

    static func recommendationDeselected(kind: CoachChangeKind, reason: CoachProposalReasonCode) {
        analytics.track(
            .morningProposalRecommendationDeselected,
            parameters: [
                AnalyticsParameterKey.changeKind: kind.analyticsRawValue,
                AnalyticsParameterKey.reasonCategory: MorningProposalReasonCategory(reason).rawValue
            ]
        )
    }

    static func reasonExpanded(kind: CoachChangeKind, reason: CoachProposalReasonCode) {
        analytics.track(
            .morningProposalReasonExpanded,
            parameters: [
                AnalyticsParameterKey.changeKind: kind.analyticsRawValue,
                AnalyticsParameterKey.reasonCategory: MorningProposalReasonCategory(reason).rawValue
            ]
        )
    }

    static func applyStarted(selectedCount: Int) {
        analytics.track(
            .morningProposalApplyStarted,
            parameters: [
                AnalyticsParameterKey.selectedCountBucket: MorningProposalCountBucket(count: selectedCount).rawValue
            ]
        )
    }

    static func applySucceeded(appliedCount: Int) {
        analytics.track(
            .morningProposalApplySucceeded,
            parameters: [
                AnalyticsParameterKey.appliedCountBucket: MorningProposalCountBucket(count: appliedCount).rawValue,
                AnalyticsParameterKey.resultType: MorningProposalApplyResultType.succeeded.rawValue
            ]
        )
    }

    static func applyPartial(appliedCount: Int, failedCount: Int) {
        analytics.track(
            .morningProposalApplyPartial,
            parameters: [
                AnalyticsParameterKey.appliedCountBucket: MorningProposalCountBucket(count: appliedCount).rawValue,
                AnalyticsParameterKey.selectedCountBucket: MorningProposalCountBucket(count: failedCount).rawValue,
                AnalyticsParameterKey.resultType: MorningProposalApplyResultType.partial.rawValue
            ]
        )
    }

    static func applyFailed(result: MorningProposalApplyResultType) {
        analytics.track(
            .morningProposalApplyFailed,
            parameters: [
                AnalyticsParameterKey.resultType: result.rawValue
            ]
        )
    }

    static func proposalDismissed() {
        analytics.track(
            .morningProposalDismissed,
            parameters: [AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.today.rawValue]
        )
    }

    static func notificationScheduled(dayKey: String) {
        analytics.track(
            .morningProposalNotificationScheduled,
            parameters: [
                AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.other.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.notification.rawValue
            ]
        )
        _ = dayKey
    }

    static func notificationOpened(dayKey: String?) {
        analytics.track(
            .morningProposalNotificationOpened,
            parameters: [
                AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.other.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.notification.rawValue
            ]
        )
        _ = dayKey
    }

    static func proposalStale() {
        analytics.track(
            .morningProposalStale,
            parameters: [AnalyticsParameterKey.source: AnalyticsSource.today.rawValue]
        )
    }

    static func adjustedItemViewed(changeKind: CoachChangeKind?, source: MorningProposalAnalyticsSurface) {
        var params: [String: String] = [
            AnalyticsParameterKey.surface: source.rawValue
        ]
        if let changeKind {
            params[AnalyticsParameterKey.changeKind] = changeKind.analyticsRawValue
        }
        analytics.track(.morningProposalAdjustedItemViewed, parameters: params)
    }

    static func adjustedItemManuallyEdited(changeKind: CoachChangeKind?) {
        var params: [String: String] = [
            AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.plan.rawValue
        ]
        if let changeKind {
            params[AnalyticsParameterKey.changeKind] = changeKind.analyticsRawValue
        }
        analytics.track(.morningProposalAdjustedItemManuallyEdited, parameters: params)
    }

    static func adjustedItemCompleted(changeKind: CoachChangeKind?) {
        var params: [String: String] = [:]
        if let changeKind {
            params[AnalyticsParameterKey.changeKind] = changeKind.analyticsRawValue
        }
        analytics.track(.morningProposalAdjustedItemCompleted, parameters: params)
    }

    static func coachAcknowledgmentViewed(dayKey: String) {
        lock.lock()
        let unseen = acknowledgmentViewedDayKeys.insert(dayKey).inserted
        lock.unlock()
        guard unseen else { return }
        analytics.track(
            .morningProposalCoachAcknowledgmentViewed,
            parameters: [
                AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.coach.rawValue
            ]
        )
    }

    #if DEBUG
    static func resetAllForTests() {
        lock.lock()
        viewedProposalIds.removeAll()
        acknowledgmentViewedDayKeys.removeAll()
        lock.unlock()
    }
    #endif

    private static func sanitizeUnavailableReason(_ reason: String) -> String {
        switch reason {
        case "health_access_denied", "outside_morning_window", "timeout", "missing_inputs", "day_expired":
            return reason
        default:
            return "other"
        }
    }
}

extension ProductAnalytics {
    static func morningProposalAdjustedItemViewed(
        changeKind: CoachChangeKind?,
        source: MorningProposalAnalyticsSurface
    ) {
        MorningProposalAnalytics.adjustedItemViewed(changeKind: changeKind, source: source)
    }

    static func morningProposalAdjustedItemManuallyEdited(changeKind: CoachChangeKind?) {
        MorningProposalAnalytics.adjustedItemManuallyEdited(changeKind: changeKind)
    }

    static func morningProposalAdjustedItemCompleted(changeKind: CoachChangeKind?) {
        MorningProposalAnalytics.adjustedItemCompleted(changeKind: changeKind)
    }
}
