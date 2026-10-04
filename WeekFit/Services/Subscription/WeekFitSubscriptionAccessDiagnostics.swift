import Foundation
#if DEBUG
import OSLog

/// DEBUG-only StoreKit access diagnostics. No receipt/JWS/PII.
/// Does not affect entitlement decisions.
enum WeekFitSubscriptionAccessDiagnostics {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "SubscriptionAccess")
    private static let isoUTC: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func utcNow() -> String {
        isoUTC.string(from: Date())
    }

    static func line(
        source: String,
        productID: String,
        transactionID: UInt64?,
        expirationDate: Date?,
        revocationDate: Date?,
        environment: String,
        renewalState: String,
        willAutoRenew: Bool?,
        billingState: WeekFitSubscriptionBillingState,
        isExpiredFlag: Bool,
        isActive: Bool
    ) -> String {
        let exp = expirationDate.map { isoUTC.string(from: $0) } ?? "nil"
        let rev = revocationDate.map { isoUTC.string(from: $0) } ?? "nil"
        let tx = transactionID.map(String.init) ?? "nil"
        let autoRenew = willAutoRenew.map { $0 ? "true" : "false" } ?? "nil"
        return
            """
            source=\(source) productID=\(productID) transactionID=\(tx) expirationUTC=\(exp) revocationUTC=\(rev) environment=\(environment) renewalState=\(renewalState) willAutoRenew=\(autoRenew) billingState=\(billingStateLabel(billingState)) isExpiredFlag=\(isExpiredFlag) isActive=\(isActive)
            """
    }

    static func log(_ message: String) {
        let stamped = "utc=\(utcNow()) \(message)"
        logger.debug("\(stamped, privacy: .public)")
        print("[WeekFit.SubscriptionAccess] \(stamped)")
    }

    static func logLoad(
        entitlementLines: [String],
        selected: WeekFitSubscriptionSnapshot?
    ) {
        if entitlementLines.isEmpty {
            log("currentEntitlements empty")
        } else {
            for line in entitlementLines {
                log(line)
            }
        }
        if let selected {
            let exp = selected.expirationDate.map { isoUTC.string(from: $0) } ?? "nil"
            log(
                "selected productID=\(selected.productID) expirationUTC=\(exp) billingState=\(billingStateLabel(selected.billingState)) isExpired=\(selected.isExpired) isRevoked=\(selected.isRevoked) willAutoRenew=\(selected.willAutoRenew) isActive=\(WeekFitEntitlementPolicy.isActiveSubscription(selected))"
            )
        } else {
            log("selected=nil")
        }
    }

    static func logRefreshResult(
        source: String,
        resolvedAccessState: WeekFitAccessState,
        hasFullAccess: Bool,
        reason: String,
        subscription: WeekFitSubscriptionSnapshot?,
        paywallWouldBlockPremiumTabs: Bool
    ) {
        let exp = subscription?.expirationDate.map { isoUTC.string(from: $0) } ?? "nil"
        log(
            """
            refresh source=\(source) resolved=\(resolvedAccessState) hasFullAccess=\(hasFullAccess) reason=\(reason) productID=\(subscription?.productID ?? "nil") expirationUTC=\(exp) billingState=\(subscription.map { billingStateLabel($0.billingState) } ?? "nil") willAutoRenew=\(subscription.map { String($0.willAutoRenew) } ?? "nil") paywallWouldBlockPremiumTabs=\(paywallWouldBlockPremiumTabs)
            """
        )
    }

    static func logPaywallPresentation(reason: String, requestedTab: String?, accessState: WeekFitAccessState) {
        log(
            "paywallPresent reason=\(reason) requestedTab=\(requestedTab ?? "nil") accessState=\(accessState)"
        )
    }

    private static func billingStateLabel(_ state: WeekFitSubscriptionBillingState) -> String {
        switch state {
        case .none: return "none"
        case .inGracePeriod: return "inGracePeriod"
        case .inBillingRetry: return "inBillingRetry"
        }
    }
}
#endif
