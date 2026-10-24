import Foundation

/// Analytics latch for a purchase whose UI wait ended before StoreKit returned.
///
/// No expiry. Ask to Buy can be approved days later; the UI timeout must not drop it.
/// This does not grant Premium. Success is emitted only for a matching verified
/// transaction, deduped by transaction id — not because entitlement appeared.
enum UnresolvedPurchaseAttemptAnalytics {
    enum Keys {
        static let productID = "weekfit.analytics.purchase.unresolved.productID"
        static let requestedTab = "weekfit.analytics.purchase.unresolved.requestedTab"
        static let markedAt = "weekfit.analytics.purchase.unresolved.markedAt"
    }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard
    private static var now: () -> Date = { Date() }

    static func mark(productID: String, requestedTab: String?) {
        guard WeekFitSubscriptionProductID(rawValue: productID) != nil else { return }
        lock.lock()
        defaults.set(productID, forKey: Keys.productID)
        defaults.set(now().timeIntervalSince1970, forKey: Keys.markedAt)
        if let requestedTab, !requestedTab.isEmpty {
            defaults.set(requestedTab, forKey: Keys.requestedTab)
        } else {
            defaults.removeObject(forKey: Keys.requestedTab)
        }
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: Keys.productID)
        defaults.removeObject(forKey: Keys.requestedTab)
        defaults.removeObject(forKey: Keys.markedAt)
        lock.unlock()
    }

    static func pendingProductID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return defaults.string(forKey: Keys.productID)
    }

    static func markedAt() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let raw = defaults.double(forKey: Keys.markedAt)
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Returns and clears the latch when the product matches. Time does not expire it.
    static func consumeIfMatching(productID: String) -> (productID: String, requestedTab: String?)? {
        lock.lock()
        defer { lock.unlock() }
        guard let pending = defaults.string(forKey: Keys.productID), pending == productID else {
            return nil
        }
        let tab = defaults.string(forKey: Keys.requestedTab)
        defaults.removeObject(forKey: Keys.productID)
        defaults.removeObject(forKey: Keys.requestedTab)
        defaults.removeObject(forKey: Keys.markedAt)
        return (pending, tab)
    }

    #if DEBUG
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func resetForTests() {
        clear()
        lock.lock()
        defaults = .standard
        now = { Date() }
        lock.unlock()
    }
    #endif
}
