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
/// In the **Sandbox** environment Apple always returns
/// `AppTransaction.originalPurchaseDate` = 2013-08-01 (PDT sentinel). That date
/// is before any realistic monetization cutoff. WeekFit treats the Sandbox
/// sentinel as **non-legacy** so paywall / purchase / expire / restore can be
/// tested. **Production** App Store `environment` still uses the real download
/// date against the cutoff — grandfathering is unchanged for App Store users.
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
        forceLegacyUser: Bool = false,
        forceNonLegacyAppTransaction: Bool = false
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
                cutoff: cutoff,
                forceNonLegacyAppTransaction: forceNonLegacyAppTransaction
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

    /// Entitled subscription periods per Apple StoreKit:
    /// - active `.subscribed` period (not expired)
    /// - `.inGracePeriod` until `gracePeriodExpirationDate` (if known)
    /// - **not** bare `.inBillingRetryPeriod` (retry after grace ended / grace disabled)
    static func isActiveSubscription(
        _ subscription: WeekFitSubscriptionSnapshot,
        now: Date = Date()
    ) -> Bool {
        guard WeekFitSubscriptionProductID(rawValue: subscription.productID) != nil else {
            return false
        }
        if subscription.isRevoked { return false }

        switch subscription.billingState {
        case .inGracePeriod:
            if let graceEnd = subscription.gracePeriodExpirationDate, graceEnd <= now {
                return false
            }
            return true
        case .inBillingRetry:
            // Apple: billing retry without grace is not entitled to service.
            return false
        case .none:
            break
        }

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
    /// - **Production** App Store: real `originalPurchaseDate` vs monetization cutoff.
    /// - **Sandbox**: Apple's 2013-08-01 sentinel must not grandfather (see
    ///   `isSandboxSentinelOriginalPurchaseDate`).
    /// - DEBUG Xcode StoreKit may return artificial dates (e.g. 1970-01-01).
    /// - `forceNonLegacyAppTransaction` is an extra DEBUG launch-arg override.
    private static func isLegacyFromVerifiedAppTransaction(
        originalPurchaseDate: Date,
        environment: String,
        cutoff: Date,
        forceNonLegacyAppTransaction: Bool = false
    ) -> Bool {
        #if DEBUG
        if environment == "Xcode" {
            return false
        }
        if forceNonLegacyAppTransaction {
            return false
        }
        #else
        _ = forceNonLegacyAppTransaction
        #endif
        if isSandboxSentinelOriginalPurchaseDate(originalPurchaseDate, environment: environment) {
            return false
        }
        return isLegacy(originalPurchaseDate: originalPurchaseDate, cutoff: cutoff)
    }

    /// Apple Sandbox always reports `originalPurchaseDate` = 2013-08-01 PDT.
    /// Only applies when StoreKit `environment` is Sandbox — never Production.
    static func isSandboxSentinelOriginalPurchaseDate(
        _ date: Date,
        environment: String
    ) -> Bool {
        guard environment.compare("Sandbox", options: [.caseInsensitive]) == .orderedSame else {
            return false
        }
        return abs(date.timeIntervalSince(Self.sandboxSentinelPurchaseDate)) < 86_400
    }

    /// 2013-08-01 00:00:00 America/Los_Angeles — Apple's documented Sandbox sentinel.
    private static let sandboxSentinelPurchaseDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        return calendar.date(from: DateComponents(year: 2013, month: 8, day: 1)) ?? Date.distantPast
    }()
}
