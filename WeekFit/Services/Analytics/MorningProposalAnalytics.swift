import Foundation

/// Privacy-preserving Morning Proposal analytics helpers.
/// Product-interaction only: surfaces, count buckets, apply results, coarse change kinds.
/// Never logs Recovery/HRV/sleep, strategy/confidence, reason categories, titles, or HealthKit.
///
/// Diagnostic outcomes (`unavailable` / `no_changes` / `generated` / `stale`) are
/// system-state events — not engagement. Exposure / apply / review events are engagement.
enum MorningProposalAnalytics {

    enum Keys {
        static let unavailableEmitted = "weekfit.analytics.mp.unavailable.emitted"
        static let noChangesEmitted = "weekfit.analytics.mp.noChanges.emitted"
    }

    static var allKnownKeys: [String] {
        [Keys.unavailableEmitted, Keys.noChangesEmitted]
    }

    private static var analytics: AnalyticsTracking { analyticsProvider() }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard
    private static var analyticsProvider: () -> AnalyticsTracking = { AppAnalytics.shared }
    private static var viewedProposalIds = Set<String>()
    private static var acknowledgmentViewedDayKeys = Set<String>()
    private static let maxStoredKeys = 48

    static func proposalGenerated(
        changeCount: Int,
        guidanceCount: Int,
        generationMode: MorningProposalGenerationMode? = nil
    ) {
        // Interaction telemetry only — no strategy, confidence, or health context.
        var parameters: [String: String] = [
            AnalyticsParameterKey.selectedCountBucket: MorningProposalCountBucket(count: changeCount + guidanceCount).rawValue,
            AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
        ]
        if let generationMode {
            parameters[AnalyticsParameterKey.mode] = generationMode.rawValue
        }
        analytics.track(.morningProposalGenerated, parameters: parameters)
    }

    /// Emits at most once per local `dayKey` + canonical unavailable reason.
    /// Engine re-evaluation is unchanged — only analytics are deduped.
    static func proposalUnavailable(dayKey: String, reason: String) {
        let mapped = MorningProposalUnavailableAnalyticsReason.fromDomainReason(reason)
        let dedupeKey = "\(dayKey)|\(mapped.rawValue)"

        lock.lock()
        var emitted = Set(defaults.stringArray(forKey: Keys.unavailableEmitted) ?? [])
        let inserted = emitted.insert(dedupeKey).inserted
        if inserted {
            let trimmed = Array(emitted).sorted().suffix(maxStoredKeys)
            defaults.set(Array(trimmed), forKey: Keys.unavailableEmitted)
        }
        lock.unlock()
        guard inserted else { return }

        analytics.track(
            .morningProposalUnavailable,
            parameters: [
                AnalyticsParameterKey.reason: mapped.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    /// Emits at most once per local `dayKey` for a no-change engine outcome.
    static func proposalNoChanges(dayKey: String) {
        lock.lock()
        var emitted = Set(defaults.stringArray(forKey: Keys.noChangesEmitted) ?? [])
        let inserted = emitted.insert(dayKey).inserted
        if inserted {
            let trimmed = Array(emitted).sorted().suffix(maxStoredKeys)
            defaults.set(Array(trimmed), forKey: Keys.noChangesEmitted)
        }
        lock.unlock()
        guard inserted else { return }

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

    static func recommendationSelected(kind: CoachChangeKind) {
        analytics.track(
            .morningProposalRecommendationSelected,
            parameters: [
                AnalyticsParameterKey.changeKind: kind.analyticsInteractionKind
            ]
        )
    }

    static func recommendationDeselected(kind: CoachChangeKind) {
        analytics.track(
            .morningProposalRecommendationDeselected,
            parameters: [
                AnalyticsParameterKey.changeKind: kind.analyticsInteractionKind
            ]
        )
    }

    static func reasonExpanded(kind: CoachChangeKind) {
        analytics.track(
            .morningProposalReasonExpanded,
            parameters: [
                AnalyticsParameterKey.changeKind: kind.analyticsInteractionKind
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
            params[AnalyticsParameterKey.changeKind] = changeKind.analyticsInteractionKind
        }
        analytics.track(.morningProposalAdjustedItemViewed, parameters: params)
    }

    static func adjustedItemManuallyEdited(changeKind: CoachChangeKind?) {
        var params: [String: String] = [
            AnalyticsParameterKey.surface: MorningProposalAnalyticsSurface.plan.rawValue
        ]
        if let changeKind {
            params[AnalyticsParameterKey.changeKind] = changeKind.analyticsInteractionKind
        }
        analytics.track(.morningProposalAdjustedItemManuallyEdited, parameters: params)
    }

    static func adjustedItemCompleted(changeKind: CoachChangeKind?) {
        var params: [String: String] = [:]
        if let changeKind {
            params[AnalyticsParameterKey.changeKind] = changeKind.analyticsInteractionKind
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
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func setAnalyticsForTests(_ provider: @escaping () -> AnalyticsTracking) {
        lock.lock()
        analyticsProvider = provider
        lock.unlock()
    }

    static func resetAllForTests() {
        lock.lock()
        viewedProposalIds.removeAll()
        acknowledgmentViewedDayKeys.removeAll()
        allKnownKeys.forEach { defaults.removeObject(forKey: $0) }
        defaults = .standard
        analyticsProvider = { AppAnalytics.shared }
        lock.unlock()
    }
    #endif
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
