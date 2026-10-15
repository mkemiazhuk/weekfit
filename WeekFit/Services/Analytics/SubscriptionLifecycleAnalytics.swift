import Foundation

/// Client-observed subscription lifecycle transitions (auto-renew + ordinary expiry).
///
/// **Observability limit:** events fire only when WeekFit refreshes StoreKit (launch,
/// foreground, `Transaction.updates`, purchase/restore). Cancelling in Apple Settings
/// while the app never reopens is invisible until the next observation — event time is
/// *observed change*, not Apple’s cancellation timestamp.
///
/// **Baseline:** the first verified observation after install / wipe persists state and
/// emits nothing. Existing installs therefore establish a quiet baseline on first
/// refresh after this code ships, then emit only subsequent transitions.
///
/// **Not covered here:** App Store Server Notifications V2 (`DID_CHANGE_RENEWAL_STATUS`,
/// `EXPIRED`). No WeekFit backend receives ASN today — see AnalyticsEventDictionary.
enum SubscriptionLifecycleAnalytics {
    enum Keys {
        static let persistedObservation = "weekfit.analytics.subscription_lifecycle.observation.v1"
    }

    /// Bounded refresh provenance for Firebase `source` (never free-form StoreKit text).
    enum ObservationSource: String, Sendable {
        case appStart = "app_start"
        case foreground
        case transactionUpdates = "transaction_updates"
        case purchase
        case restore
        case storefront
        case externalChange = "external_change"
        case refresh
        case other

        static func fromRefreshSource(_ raw: String) -> ObservationSource {
            let value = raw.lowercased()
            if value.hasPrefix("start") { return .appStart }
            if value.hasPrefix("foreground") { return .foreground }
            if value.hasPrefix("transaction.updates") { return .transactionUpdates }
            if value.hasPrefix("purchase") { return .purchase }
            if value.hasPrefix("restore") { return .restore }
            if value.hasPrefix("storefront") { return .storefront }
            if value.hasPrefix("externalsubscriptionchange") { return .externalChange }
            if value.hasPrefix("refresh") { return .refresh }
            return .other
        }
    }

    enum SubscriptionPhase: String, Sendable {
        case trial
        case paid
        case unknown
    }

    /// Local-only observation used for transition detection. Never uploaded to Firebase.
    struct PersistedObservation: Equatable, Codable, Sendable {
        var productID: String?
        var willAutoRenew: Bool?
        var isRenewalInfoVerified: Bool
        var isEntitled: Bool
        var isIntroductoryTrial: Bool
        var billingState: String
        var isExpired: Bool
        var isRevoked: Bool
        /// False until the first successful observation is stored (no events until then).
        var baselineEstablished: Bool
    }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard
    private static var analyticsOverride: AnalyticsTracking?

    private static var analytics: AnalyticsTracking {
        analyticsOverride ?? AppAnalytics.shared
    }

    // MARK: - Observation

    /// Compare `subscription` to the persisted baseline and emit lifecycle events.
    ///
    /// - Parameter subscription: Latest StoreKit-derived snapshot, or `nil` when StoreKit
    ///   returned no usable status/entitlement. `nil` without an expired snapshot is treated
    ///   as inconclusive (no expire event, baseline unchanged).
    static func observe(
        subscription: WeekFitSubscriptionSnapshot?,
        refreshSource: String
    ) {
        let source = ObservationSource.fromRefreshSource(refreshSource)

        // Inconclusive: empty load after entitled baseline may be temporary StoreKit blip.
        guard let subscription else { return }

        let current = makeObservation(from: subscription)
        lock.lock()
        let previous = loadLocked()
        lock.unlock()

        guard let previous, previous.baselineEstablished else {
            // First observation — establish baseline only.
            save(current.establishingBaseline())
            return
        }

        emitTransitions(from: previous, to: current, source: source)
        save(current.establishingBaseline())
    }

    // MARK: - Transitions

    private static func emitTransitions(
        from previous: PersistedObservation,
        to current: PersistedObservation,
        source: ObservationSource
    ) {
        emitAutoRenewTransitions(from: previous, to: current, source: source)
        emitExpirationIfNeeded(from: previous, to: current, source: source)
    }

    private static func emitAutoRenewTransitions(
        from previous: PersistedObservation,
        to current: PersistedObservation,
        source: ObservationSource
    ) {
        guard previous.isRenewalInfoVerified, current.isRenewalInfoVerified else { return }
        guard let previousRenew = previous.willAutoRenew, let currentRenew = current.willAutoRenew else {
            return
        }
        guard previousRenew != currentRenew else { return }

        // Same product only — plan switches must not look like cancel/re-enable churn.
        guard previous.productID != nil,
              previous.productID == current.productID,
              let productID = current.productID
        else { return }

        // Require an entitled period on at least one side so unpaid historical rows
        // with flipped renewal flags do not spam.
        guard previous.isEntitled || current.isEntitled else { return }

        let phase = subscriptionPhase(
            isIntroductoryTrial: current.isIntroductoryTrial || previous.isIntroductoryTrial
        )
        if previousRenew && !currentRenew {
            track(
                .subscriptionAutoRenewDisabled,
                productID: productID,
                source: source,
                phase: phase
            )
        } else if !previousRenew && currentRenew {
            track(
                .subscriptionAutoRenewEnabled,
                productID: productID,
                source: source,
                phase: phase
            )
        }
    }

    private static func emitExpirationIfNeeded(
        from previous: PersistedObservation,
        to current: PersistedObservation,
        source: ObservationSource
    ) {
        // Ordinary expiry only: previously entitled → verified expired, not revoked /
        // grace / billing-retry / unverified emptiness.
        guard previous.isEntitled else { return }
        guard !current.isEntitled else { return }
        guard current.isExpired else { return }
        guard !current.isRevoked else { return }
        guard current.billingState == WeekFitSubscriptionBillingState.none.analyticsToken else {
            return
        }

        let productID = current.productID ?? previous.productID ?? "unknown"
        let phase = subscriptionPhase(
            isIntroductoryTrial: previous.isIntroductoryTrial || current.isIntroductoryTrial
        )
        track(
            .subscriptionExpired,
            productID: productID,
            source: source,
            phase: phase
        )
    }

    private static func track(
        _ event: AnalyticsEvent,
        productID: String,
        source: ObservationSource,
        phase: SubscriptionPhase
    ) {
        // Explicit consent gate (Firebase also disables collection when sharing is off).
        guard ProductAnalyticsConsent.isSharingEnabled() else { return }

        analytics.track(
            event,
            parameters: [
                AnalyticsParameterKey.productID: sanitizedProductID(productID),
                AnalyticsParameterKey.source: source.rawValue,
                AnalyticsParameterKey.subscriptionPhase: phase.rawValue
            ]
        )
    }

    // MARK: - Mapping

    private static func makeObservation(
        from subscription: WeekFitSubscriptionSnapshot
    ) -> PersistedObservation {
        PersistedObservation(
            productID: WeekFitSubscriptionProductID(rawValue: subscription.productID)?.rawValue
                ?? subscription.productID,
            willAutoRenew: subscription.isRenewalInfoVerified ? subscription.willAutoRenew : nil,
            isRenewalInfoVerified: subscription.isRenewalInfoVerified,
            isEntitled: WeekFitEntitlementPolicy.isActiveSubscription(subscription),
            isIntroductoryTrial: subscription.isIntroductoryTrial,
            billingState: subscription.billingState.analyticsToken,
            isExpired: subscription.isExpired,
            isRevoked: subscription.isRevoked,
            baselineEstablished: false
        )
    }

    private static func subscriptionPhase(isIntroductoryTrial: Bool) -> SubscriptionPhase {
        isIntroductoryTrial ? .trial : .paid
    }

    private static func sanitizedProductID(_ productID: String) -> String {
        WeekFitSubscriptionProductID(rawValue: productID)?.rawValue ?? "unknown"
    }

    // MARK: - Persistence

    private static func loadLocked() -> PersistedObservation? {
        guard let data = defaults.data(forKey: Keys.persistedObservation) else { return nil }
        return try? JSONDecoder().decode(PersistedObservation.self, from: data)
    }

    private static func save(_ observation: PersistedObservation) {
        guard let data = try? JSONEncoder().encode(observation) else { return }
        lock.lock()
        defaults.set(data, forKey: Keys.persistedObservation)
        lock.unlock()
    }

    #if DEBUG
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func setAnalyticsForTests(_ analytics: AnalyticsTracking?) {
        lock.lock()
        analyticsOverride = analytics
        lock.unlock()
    }

    static func resetForTests() {
        lock.lock()
        defaults.removeObject(forKey: Keys.persistedObservation)
        defaults = .standard
        analyticsOverride = nil
        lock.unlock()
    }

    static func persistedObservationForTests() -> PersistedObservation? {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    /// Test helper — write a baseline without emitting.
    static func seedBaselineForTests(_ observation: PersistedObservation) {
        save(observation.establishingBaseline())
    }
    #endif
}

private extension SubscriptionLifecycleAnalytics.PersistedObservation {
    func establishingBaseline() -> Self {
        var copy = self
        copy.baselineEstablished = true
        return copy
    }
}

private extension WeekFitSubscriptionBillingState {
    var analyticsToken: String {
        switch self {
        case .none: return "none"
        case .inGracePeriod: return "grace"
        case .inBillingRetry: return "billing_retry"
        }
    }
}
