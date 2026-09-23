import Foundation

enum SubscriptionAnalytics {
    private static var analytics: AnalyticsTracking { AppAnalytics.shared }

    /// Bounded ring of recently tracked presentation IDs.
    /// Survives SwiftUI remounts of the *same* presentation without growing forever.
    private static var trackedPaywallInstanceIDs: [String] = []
    private static let maxTrackedPaywallInstanceIDs = 8

    static func resetPaywallViewDedupForTests() {
        trackedPaywallInstanceIDs.removeAll()
    }

    static func paywallViewed(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        currentTab: String? = nil,
        hasFullAccess: Bool,
        paywallInstanceID: String
    ) {
        guard !trackedPaywallInstanceIDs.contains(paywallInstanceID) else { return }
        trackedPaywallInstanceIDs.append(paywallInstanceID)
        if trackedPaywallInstanceIDs.count > maxTrackedPaywallInstanceIDs {
            trackedPaywallInstanceIDs.removeFirst(
                trackedPaywallInstanceIDs.count - maxTrackedPaywallInstanceIDs
            )
        }

        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue,
            AnalyticsParameterKey.hasFullAccess: Self.boolToken(hasFullAccess),
            // Correlation only — do NOT register as a GA4 custom dimension.
            AnalyticsParameterKey.paywallInstanceID: paywallInstanceID
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let currentTab {
            parameters[AnalyticsParameterKey.currentTab] = currentTab
        }
        analytics.track(.paywallViewed, parameters: parameters)
        ProductScreenTracker.shared.trackScreenIfChanged(.paywall)
    }

    static func optionSelected(productID: String, requestedTab: String? = nil) {
        analytics.track(
            .subscriptionOptionSelected,
            parameters: productParameters(productID: productID, requestedTab: requestedTab)
        )
    }

    static func purchaseStarted(productID: String, requestedTab: String? = nil) {
        analytics.track(
            .subscriptionPurchaseStarted,
            parameters: productParameters(productID: productID, requestedTab: requestedTab)
        )
    }

    static func purchaseSuccess(productID: String, requestedTab: String? = nil) {
        analytics.track(
            .subscriptionPurchaseSuccess,
            parameters: productParameters(productID: productID, requestedTab: requestedTab)
        )
    }

    static func purchaseCancelled(productID: String, requestedTab: String? = nil) {
        analytics.track(
            .subscriptionPurchaseCancelled,
            parameters: productParameters(productID: productID, requestedTab: requestedTab)
        )
    }

    static func purchaseFailed(
        productID: String,
        requestedTab: String? = nil,
        failureReason: SubscriptionPurchaseFailureReason
    ) {
        var parameters = productParameters(productID: productID, requestedTab: requestedTab)
        parameters[AnalyticsParameterKey.failureReason] = failureReason.rawValue
        analytics.track(.subscriptionPurchaseFailed, parameters: parameters)
    }

    /// Fires only from explicit Restore Purchases actions (paywall / settings).
    static func restoreStarted(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil
    ) {
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        analytics.track(.subscriptionRestoreStarted, parameters: parameters)
    }

    static func restoreSuccess(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        hasEntitlementBefore: Bool,
        hasEntitlementAfter: Bool,
        restoredProductID: String?
    ) {
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue,
            AnalyticsParameterKey.hasEntitlementBefore: Self.boolToken(hasEntitlementBefore),
            AnalyticsParameterKey.hasEntitlementAfter: Self.boolToken(hasEntitlementAfter)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let restoredProductID {
            parameters[AnalyticsParameterKey.restoredProductID] = sanitizedProductID(restoredProductID)
        }
        analytics.track(.subscriptionRestoreSuccess, parameters: parameters)
    }

    static func restoreFailed(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        failureReason: SubscriptionRestoreFailureReason,
        hasEntitlementAfter: Bool
    ) {
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue,
            AnalyticsParameterKey.failureReason: failureReason.rawValue,
            AnalyticsParameterKey.hasEntitlementAfter: Self.boolToken(hasEntitlementAfter)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        analytics.track(.subscriptionRestoreFailed, parameters: parameters)
    }

    /// Only the known WeekFit product ids — never StoreKit localized titles or prices.
    private static func sanitizedProductID(_ productID: String) -> String {
        WeekFitSubscriptionProductID(rawValue: productID)?.rawValue ?? "unknown"
    }

    private static func productParameters(
        productID: String,
        requestedTab: String?
    ) -> [String: String] {
        var parameters: [String: String] = [
            AnalyticsParameterKey.productID: sanitizedProductID(productID)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        return parameters
    }

    private static func boolToken(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}

enum SubscriptionAnalyticsSource: String, Sendable {
    case onboarding
    case root
    case settings
    case tab
    case other
}

enum SubscriptionRestoreFailureReason: String, Sendable {
    /// AppStore.sync completed but no active WeekFit entitlement.
    case noPurchases = "no_purchases"
    /// StoreKit / network / sync threw (non-cancel).
    case storekitError = "storekit_error"
    /// User cancelled the system restore sheet.
    case cancelled
    /// AppStore.sync did not return within the restore timeout (hung sign-in / network).
    case timeout
}

enum SubscriptionPurchaseFailureReason: String, Sendable {
    case storekitError = "storekit_error"
    /// Purchase transaction JWS was unverified.
    case verificationFailed = "verification_failed"
    /// StoreKit returned a verified transaction, but entitlement refresh never unlocked access.
    case entitlementNotPropagated = "entitlement_not_propagated"
    case productsUnavailable = "products_unavailable"
    /// Ask to Buy / deferred — closes the started→terminal funnel for this attempt.
    case pending
}
