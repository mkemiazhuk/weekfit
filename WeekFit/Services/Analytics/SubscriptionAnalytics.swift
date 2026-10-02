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

    static func optionSelected(
        productID: String,
        requestedTab: String? = nil,
        paywallInstanceID: String? = nil
    ) {
        analytics.track(
            .subscriptionOptionSelected,
            parameters: productParameters(
                productID: productID,
                requestedTab: requestedTab,
                paywallInstanceID: paywallInstanceID
            )
        )
    }

    static func purchaseStarted(
        productID: String,
        requestedTab: String? = nil,
        paywallInstanceID: String? = nil
    ) {
        analytics.track(
            .subscriptionPurchaseStarted,
            parameters: productParameters(
                productID: productID,
                requestedTab: requestedTab,
                paywallInstanceID: paywallInstanceID
            )
        )
    }

    static func purchaseSuccess(
        productID: String,
        requestedTab: String? = nil,
        paywallInstanceID: String? = nil
    ) {
        analytics.track(
            .subscriptionPurchaseSuccess,
            parameters: productParameters(
                productID: productID,
                requestedTab: requestedTab,
                paywallInstanceID: paywallInstanceID
            )
        )
    }

    static func purchaseCancelled(
        productID: String,
        requestedTab: String? = nil,
        paywallInstanceID: String? = nil
    ) {
        analytics.track(
            .subscriptionPurchaseCancelled,
            parameters: productParameters(
                productID: productID,
                requestedTab: requestedTab,
                paywallInstanceID: paywallInstanceID
            )
        )
    }

    static func purchaseFailed(
        productID: String,
        requestedTab: String? = nil,
        failureReason: SubscriptionPurchaseFailureReason,
        paywallInstanceID: String? = nil
    ) {
        var parameters = productParameters(
            productID: productID,
            requestedTab: requestedTab,
            paywallInstanceID: paywallInstanceID
        )
        parameters[AnalyticsParameterKey.failureReason] = failureReason.rawValue
        parameters[AnalyticsParameterKey.result] = failureReason.rawValue
        analytics.track(.subscriptionPurchaseFailed, parameters: parameters)
    }

    /// Fires only from explicit Restore Purchases actions (paywall / settings).
    static func restoreStarted(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        paywallInstanceID: String? = nil
    ) {
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let paywallInstanceID {
            parameters[AnalyticsParameterKey.paywallInstanceID] = paywallInstanceID
        }
        analytics.track(.subscriptionRestoreStarted, parameters: parameters)
    }

    /// Access confirmed: `restored` or `already_entitled` only.
    static func restoreSuccess(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        result: SubscriptionRestoreResult,
        hasEntitlementBefore: Bool,
        hasEntitlementAfter: Bool,
        restoredProductID: String? = nil,
        paywallInstanceID: String? = nil
    ) {
        precondition(
            result == .restored || result == .alreadyEntitled,
            "restore_success is only for access-confirmed results"
        )
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue,
            AnalyticsParameterKey.result: result.rawValue,
            AnalyticsParameterKey.hasEntitlementBefore: Self.boolToken(hasEntitlementBefore),
            AnalyticsParameterKey.hasEntitlementAfter: Self.boolToken(hasEntitlementAfter)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let restoredProductID {
            parameters[AnalyticsParameterKey.restoredProductID] = sanitizedProductID(restoredProductID)
        }
        if let paywallInstanceID {
            parameters[AnalyticsParameterKey.paywallInstanceID] = paywallInstanceID
        }
        analytics.track(.subscriptionRestoreSuccess, parameters: parameters)
    }

    /// Neutral terminal: request finished without confirming access and without a StoreKit fault.
    /// Used for `no_purchases` and `cancelled` only.
    static func restoreCompleted(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        result: SubscriptionRestoreResult,
        hasEntitlementBefore: Bool,
        hasEntitlementAfter: Bool,
        paywallInstanceID: String? = nil
    ) {
        precondition(
            result == .noPurchases || result == .cancelled,
            "restore_completed is only for no_purchases / cancelled"
        )
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue,
            AnalyticsParameterKey.result: result.rawValue,
            AnalyticsParameterKey.hasEntitlementBefore: Self.boolToken(hasEntitlementBefore),
            AnalyticsParameterKey.hasEntitlementAfter: Self.boolToken(hasEntitlementAfter)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let paywallInstanceID {
            parameters[AnalyticsParameterKey.paywallInstanceID] = paywallInstanceID
        }
        analytics.track(.subscriptionRestoreCompleted, parameters: parameters)
    }

    /// Technical restore failures only: `storekit_error` and `timeout`.
    static func restoreFailed(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        result: SubscriptionRestoreResult,
        hasEntitlementAfter: Bool,
        paywallInstanceID: String? = nil,
        error: Error? = nil
    ) {
        precondition(
            result == .storekitError || result == .timeout,
            "restore_failed is only for technical failures"
        )
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue,
            AnalyticsParameterKey.result: result.rawValue,
            AnalyticsParameterKey.failureReason: result.rawValue,
            AnalyticsParameterKey.hasEntitlementAfter: Self.boolToken(hasEntitlementAfter)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let paywallInstanceID {
            parameters[AnalyticsParameterKey.paywallInstanceID] = paywallInstanceID
        }
        if let error {
            let fields = sanitizedErrorFields(from: error)
            parameters[AnalyticsParameterKey.errorCode] = fields.code
            parameters[AnalyticsParameterKey.errorDomain] = fields.domain
        }
        analytics.track(.subscriptionRestoreFailed, parameters: parameters)
    }

    /// Routes a restore terminal outcome to the correct event by `result` class.
    static func restoreFinished(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil,
        result: SubscriptionRestoreResult,
        hasEntitlementBefore: Bool,
        hasEntitlementAfter: Bool,
        restoredProductID: String? = nil,
        paywallInstanceID: String? = nil,
        error: Error? = nil
    ) {
        switch result {
        case .restored, .alreadyEntitled:
            restoreSuccess(
                source: source,
                requestedTab: requestedTab,
                result: result,
                hasEntitlementBefore: hasEntitlementBefore,
                hasEntitlementAfter: hasEntitlementAfter,
                restoredProductID: restoredProductID,
                paywallInstanceID: paywallInstanceID
            )
        case .noPurchases, .cancelled:
            restoreCompleted(
                source: source,
                requestedTab: requestedTab,
                result: result,
                hasEntitlementBefore: hasEntitlementBefore,
                hasEntitlementAfter: hasEntitlementAfter,
                paywallInstanceID: paywallInstanceID
            )
        case .storekitError, .timeout:
            restoreFailed(
                source: source,
                requestedTab: requestedTab,
                result: result,
                hasEntitlementAfter: hasEntitlementAfter,
                paywallInstanceID: paywallInstanceID,
                error: error
            )
        }
    }

    /// Only the known WeekFit product ids — never StoreKit localized titles or prices.
    private static func sanitizedProductID(_ productID: String) -> String {
        WeekFitSubscriptionProductID(rawValue: productID)?.rawValue ?? "unknown"
    }

    private static func productParameters(
        productID: String,
        requestedTab: String?,
        paywallInstanceID: String?
    ) -> [String: String] {
        var parameters: [String: String] = [
            AnalyticsParameterKey.productID: sanitizedProductID(productID)
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        if let paywallInstanceID {
            parameters[AnalyticsParameterKey.paywallInstanceID] = paywallInstanceID
        }
        return parameters
    }

    /// Safe StoreKit / system error markers — no localizedDescription / userInfo.
    static func sanitizedErrorFields(from error: Error) -> (code: String, domain: String) {
        if error is WeekFitStoreKitRestoreTimeoutError {
            return ("timeout", "weekfit.storekit.restore")
        }
        if error is CancellationError {
            return ("cancelled", "weekfit.storekit.restore")
        }
        let nsError = error as NSError
        let rawDomain = nsError.domain
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filtered = String(rawDomain.unicodeScalars.filter { allowed.contains($0) })
        let domain = String((filtered.isEmpty ? "unknown" : filtered).prefix(64))
        let code = String(nsError.code)
        return (code, domain)
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

/// Terminal restore outcome for analytics `result` (and failed `failure_reason`).
enum SubscriptionRestoreResult: String, Sendable {
    /// Sync found an active WeekFit entitlement the session did not already have.
    case restored
    /// Entitlement was already present before AppStore.sync.
    case alreadyEntitled = "already_entitled"
    /// Sync completed; Apple account has no active WeekFit subscription.
    case noPurchases = "no_purchases"
    /// User dismissed the system Apple ID / restore sheet.
    case cancelled
    /// StoreKit / network threw (non-cancel).
    case storekitError = "storekit_error"
    /// AppStore.sync did not return within the restore timeout.
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
