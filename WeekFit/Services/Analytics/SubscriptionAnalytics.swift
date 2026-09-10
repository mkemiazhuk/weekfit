import Foundation

enum SubscriptionAnalytics {
    private static var analytics: AnalyticsTracking { AppAnalytics.shared }

    static func paywallViewed(
        source: SubscriptionAnalyticsSource,
        requestedTab: String? = nil
    ) {
        var parameters: [String: String] = [
            AnalyticsParameterKey.source: source.rawValue
        ]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
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

    static func restoreStarted(requestedTab: String? = nil) {
        var parameters: [String: String] = [:]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        analytics.track(.subscriptionRestoreStarted, parameters: parameters)
    }

    static func restoreSuccess(requestedTab: String? = nil) {
        var parameters: [String: String] = [:]
        if let requestedTab {
            parameters[AnalyticsParameterKey.requestedTab] = requestedTab
        }
        analytics.track(.subscriptionRestoreSuccess, parameters: parameters)
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
}

enum SubscriptionAnalyticsSource: String, Sendable {
    case onboarding
    case root
    case settings
    case tab
    case other
}
