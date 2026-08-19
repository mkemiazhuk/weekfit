import Foundation

/// Pure entitlement policy. Keep this free of SwiftUI, SwiftData, and auth identity.
///
/// ## Production
/// `AppTransaction.originalPurchaseDate < WeekFitMonetizationCutoff.date` → `.legacy`.
/// That date is issued by the App Store and survives reinstall for the same Apple ID.
///
/// ## TestFlight / Sandbox
/// `originalPurchaseDate` is the first *sandbox/TestFlight* install, not the
/// production App Store download. An existing App Store user who installs a
/// TestFlight build of 1.3 may be classified as a new user and see the paywall.
/// Verify grandfathering on a production App Store build.
///
/// ## Unavailable StoreKit
/// If a previous **verified** resolution exists on this install, keep it:
/// expired / unsubscribed stay gated; legacy / trial / subscribed keep access.
/// If entitlement has never been verified here, fail-open (`.loading`) so a
/// legacy user is not locked out during 1.3 migration.
///
/// Local fallback is never used while StoreKit verification is available.
///
/// ## Identity
/// Entitlement belongs to the App Store account. Guest ↔ Sign in with Apple
/// must not change this decision.
enum WeekFitEntitlementPolicy {
    static func hasFullAccess(for state: WeekFitAccessState) -> Bool {
        switch state {
        case .loading, .legacy, .trial, .subscribed:
            return true
        case .expired, .unsubscribed:
            return false
        }
    }

    static func isLegacy(
        originalPurchaseDate: Date?,
        cutoff: Date = WeekFitMonetizationCutoff.date
    ) -> Bool {
        guard let originalPurchaseDate else { return false }
        return originalPurchaseDate < cutoff
    }

    static func resolve(
        appTransaction: WeekFitAppTransactionStatus,
        subscription: WeekFitSubscriptionSnapshot?,
        lastVerified: WeekFitVerifiedEntitlement? = nil,
        bypass: WeekFitEntitlementBypass = .none,
        now: Date = Date(),
        cutoff: Date = WeekFitMonetizationCutoff.date,
        forceNewUser: Bool = false,
        forceLegacyUser: Bool = false
    ) -> WeekFitEntitlementDecision {
        if bypass.grantsAccess || forceLegacyUser {
            return WeekFitEntitlementDecision(state: .legacy, shouldPersistVerifiedEntitlement: false)
        }

        if forceNewUser {
            return WeekFitEntitlementDecision(
                state: expiredOrUnsubscribed(subscription),
                shouldPersistVerifiedEntitlement: false
            )
        }

        if let subscription, isActiveSubscription(subscription, now: now) {
            let state: WeekFitAccessState = subscription.isIntroductoryTrial ? .trial : .subscribed
            return WeekFitEntitlementDecision(state: state, shouldPersistVerifiedEntitlement: true)
        }

        switch appTransaction {
        case .loading:
            return fallbackOrLoading(lastVerified, persist: false)
        case .verified(let date, let environment):
            if isLegacyFromVerifiedAppTransaction(
                originalPurchaseDate: date,
                environment: environment,
                cutoff: cutoff
            ) {
                return WeekFitEntitlementDecision(state: .legacy, shouldPersistVerifiedEntitlement: true)
            }
            return WeekFitEntitlementDecision(
                state: expiredOrUnsubscribed(subscription),
                shouldPersistVerifiedEntitlement: true
            )
        case .unverified(_), .unavailable:
            // Fail-open only when we have never verified an entitlement on this install.
            // If this install has a verified fallback, we still allow the current subscription
            // snapshot to gate (expired/unsubscribed) while AppTransaction is down.
            guard lastVerified != nil else {
                return WeekFitEntitlementDecision(state: .loading, shouldPersistVerifiedEntitlement: false)
            }

            if let subscription {
                return WeekFitEntitlementDecision(
                    state: expiredOrUnsubscribed(subscription),
                    shouldPersistVerifiedEntitlement: true
                )
            }

            return fallbackOrLoading(lastVerified, persist: false)
        }
    }

    static func isActiveSubscription(
        _ subscription: WeekFitSubscriptionSnapshot,
        now: Date = Date()
    ) -> Bool {
        guard WeekFitSubscriptionProductID(rawValue: subscription.productID) != nil else {
            return false
        }
        if subscription.isRevoked { return false }
        if subscription.inGraceOrRetry { return true }
        if subscription.isExpired { return false }
        if let expiration = subscription.expirationDate, expiration <= now {
            return false
        }
        return true
    }

    private static func fallbackOrLoading(
        _ lastVerified: WeekFitVerifiedEntitlement?,
        persist: Bool
    ) -> WeekFitEntitlementDecision {
        if let lastVerified {
            return WeekFitEntitlementDecision(
                state: lastVerified.accessState,
                shouldPersistVerifiedEntitlement: persist
            )
        }
        return WeekFitEntitlementDecision(state: .loading, shouldPersistVerifiedEntitlement: false)
    }

    private static func expiredOrUnsubscribed(
        _ subscription: WeekFitSubscriptionSnapshot?
    ) -> WeekFitAccessState {
        if let subscription, subscription.isExpired || subscription.isRevoked {
            return .expired
        }
        return .unsubscribed
    }

    /// Legacy eligibility from a verified AppTransaction.
    ///
    /// Production / Sandbox / TestFlight environments use the real App Store date.
    /// DEBUG Xcode StoreKit may return artificial dates such as 1970-01-01; those
    /// must not grandfather local test installs.
    private static func isLegacyFromVerifiedAppTransaction(
        originalPurchaseDate: Date,
        environment: String,
        cutoff: Date
    ) -> Bool {
        #if DEBUG
        if environment == "Xcode" {
            return false
        }
        #endif
        return isLegacy(originalPurchaseDate: originalPurchaseDate, cutoff: cutoff)
    }
}
