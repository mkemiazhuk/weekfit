import Foundation

enum SubscriptionAnalytics {
    private static var analytics: AnalyticsTracking { AppAnalytics.shared }

    static func paywallViewed(source: SubscriptionAnalyticsSource) {
        analytics.track(
            .paywallViewed,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
        ProductScreenTracker.shared.trackScreenIfChanged(.paywall)
    }

    static func optionSelected(productID: String) {
        analytics.track(
            .subscriptionOptionSelected,
            parameters: [AnalyticsParameterKey.productID: sanitizedProductID(productID)]
        )
    }

    static func purchaseStarted(productID: String) {
        analytics.track(
            .subscriptionPurchaseStarted,
            parameters: [AnalyticsParameterKey.productID: sanitizedProductID(productID)]
        )
    }

    static func purchaseSuccess(productID: String) {
        analytics.track(
            .subscriptionPurchaseSuccess,
            parameters: [AnalyticsParameterKey.productID: sanitizedProductID(productID)]
        )
    }

    static func purchaseCancelled(productID: String) {
        analytics.track(
            .subscriptionPurchaseCancelled,
            parameters: [AnalyticsParameterKey.productID: sanitizedProductID(productID)]
        )
    }

    static func restoreStarted() {
        analytics.track(.subscriptionRestoreStarted)
    }

    static func restoreSuccess() {
        analytics.track(.subscriptionRestoreSuccess)
    }

    /// Only the known WeekFit product ids — never StoreKit localized titles or prices.
    private static func sanitizedProductID(_ productID: String) -> String {
        WeekFitSubscriptionProductID(rawValue: productID)?.rawValue ?? "unknown"
    }
}

enum SubscriptionAnalyticsSource: String, Sendable {
    case onboarding
    case root
    case settings
    case other
}
