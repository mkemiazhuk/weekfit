import Foundation
import StoreKit

/// StoreKit 2 JWS proof of an active **standard paid** WeekFit subscription for cloud APIs.
///
/// Accepts only auto-renewable entitlements with **no** App Store offer attached
/// (no introductory / promotional / offer code / win-back). The separate one-time
/// complimentary AI scan uses `freeTrialHTTPHeaderName` instead.
enum WeekFitPaidSubscriptionProof {
    /// Header name sent to WeekFit cloud photo recognition.
    static let httpHeaderName = "X-WeekFit-Subscription-JWS"

    /// HTTP header for the one complimentary non‑paid AI photo scan.
    static let freeTrialHTTPHeaderName = "X-WeekFit-Photo-Free-Trial"

    /// Returns JWS for a verified, unexpired, non-revoked WeekFit subscription
    /// that is **not** on any App Store offer (intro/promo/code/win-back).
    static func currentPaidSubscriptionJWS(now: Date = Date()) async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard isStandardPaidSubscription(transaction, now: now) else { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    /// True when the transaction represents ordinary paid access (no offer / free trial).
    static func isStandardPaidSubscription(_ transaction: Transaction, now: Date = Date()) -> Bool {
        guard WeekFitSubscriptionProductID(rawValue: transaction.productID) != nil else { return false }
        if transaction.revocationDate != nil { return false }
        if let expiration = transaction.expirationDate, expiration <= now { return false }

        // Any App Store offer = intro / promo / offer code / win-back — not standard paid.
        if transaction.offer != nil { return false }

        return true
    }
}
