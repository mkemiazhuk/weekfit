import Foundation

/// Persists Ask-to-Buy / SCA deferred purchase intent across process death.
/// Cleared after unlock analytics fire or when the attempt is cancelled / succeeded inline.
enum WeekFitDeferredPurchaseStore {
    enum Keys {
        static let productID = "weekfit.storekit.deferredPurchase.productID"
        static let requestedTab = "weekfit.storekit.deferredPurchase.requestedTab"
    }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func markPending(productID: String, requestedTab: String?) {
        guard WeekFitSubscriptionProductID(rawValue: productID) != nil else { return }
        lock.lock()
        defaults.set(productID, forKey: Keys.productID)
        if let requestedTab, !requestedTab.isEmpty {
            defaults.set(requestedTab, forKey: Keys.requestedTab)
        } else {
            defaults.removeObject(forKey: Keys.requestedTab)
        }
        lock.unlock()
    }

    static func pendingProductID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return defaults.string(forKey: Keys.productID)
    }

    static func pendingRequestedTab() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return defaults.string(forKey: Keys.requestedTab)
    }

    /// Returns and clears the pending record when `productID` matches.
    static func consumeIfMatching(productID: String) -> (productID: String, requestedTab: String?)? {
        lock.lock()
        defer { lock.unlock() }
        guard let pending = defaults.string(forKey: Keys.productID), pending == productID else {
            return nil
        }
        let tab = defaults.string(forKey: Keys.requestedTab)
        defaults.removeObject(forKey: Keys.productID)
        defaults.removeObject(forKey: Keys.requestedTab)
        return (pending, tab)
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: Keys.productID)
        defaults.removeObject(forKey: Keys.requestedTab)
        lock.unlock()
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
        lock.unlock()
    }

    /// Clears persisted keys without swapping the test `UserDefaults` suite.
    static func clearForTests() {
        clear()
    }
    #endif
}
