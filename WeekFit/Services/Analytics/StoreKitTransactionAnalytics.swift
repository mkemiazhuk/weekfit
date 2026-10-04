import Foundation
import StoreKit
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Firebase StoreKit 2 IAP logging — only for verified purchases initiated by the app.
///
/// Official Firebase guidance (Analytics SDK 12.5+): StoreKit 1 is automatic;
/// StoreKit 2 requires `Analytics.logTransaction(_:)` on a verified `Transaction`
/// before `finish()`. Do **not** invent a custom revenue event with product price.
///
/// Rules:
/// - Call only from the purchase / Ask-to-Buy completion path (not restore, not
///   entitlement refresh, not grandfathered access).
/// - Deduplicate by StoreKit `transaction.id` so purchase + `Transaction.updates`
///   cannot double-log the same transaction.
/// - Skip Xcode StoreKit Testing environment.
/// - Respect Analytics collection policy (`FirebaseEnvironment`); DEBUG is off.
enum StoreKitTransactionAnalytics {
    enum Keys {
        static let loggedTransactionIDs = "weekfit.analytics.sk2.logged_transaction_ids"
    }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard
    private static let maxStoredIDs = 64
    private static var logHandler: ((Transaction) -> Void)?

    /// Logs a verified StoreKit 2 transaction for Firebase `in_app_purchase` revenue.
    /// Safe to call multiple times for the same id — only the first succeeds.
    static func logVerifiedPurchaseTransactionIfNeeded(_ transaction: Transaction) {
        guard WeekFitSubscriptionProductID(rawValue: transaction.productID) != nil else { return }
        if transaction.environment == .xcode { return }

        let idKey = String(transaction.id)
        lock.lock()
        var logged = Set(defaults.stringArray(forKey: Keys.loggedTransactionIDs) ?? [])
        let inserted = logged.insert(idKey).inserted
        if inserted {
            let trimmed = Array(logged).sorted().suffix(maxStoredIDs)
            defaults.set(Array(trimmed), forKey: Keys.loggedTransactionIDs)
        }
        lock.unlock()
        guard inserted else { return }

        if let logHandler {
            logHandler(transaction)
            return
        }

        #if canImport(FirebaseAnalytics)
        // Firebase derives value/currency from the Transaction (trial / promo → $0).
        Analytics.logTransaction(transaction)
        #endif
    }

    #if DEBUG
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func setLogHandlerForTests(_ handler: ((Transaction) -> Void)?) {
        lock.lock()
        logHandler = handler
        lock.unlock()
    }

    static func resetForTests() {
        lock.lock()
        defaults.removeObject(forKey: Keys.loggedTransactionIDs)
        defaults = .standard
        logHandler = nil
        lock.unlock()
    }

    static func hasLoggedTransactionIDForTests(_ id: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let logged = Set(defaults.stringArray(forKey: Keys.loggedTransactionIDs) ?? [])
        return logged.contains(String(id))
    }
    #endif
}
