import Foundation

/// Persists Ask-to-Buy / SCA deferred purchase intent across process death.
/// Cleared after unlock analytics fire or when the attempt is cancelled / succeeded inline.
enum WeekFitDeferredPurchaseStore {
    enum Keys {
        static let productID = "weekfit.storekit.deferredPurchase.productID"
        static let requestedTab = "weekfit.storekit.deferredPurchase.requestedTab"
        static let markedAt = "weekfit.storekit.deferredPurchase.markedAt"
    }

    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func markPending(productID: String, requestedTab: String?) {
        guard WeekFitSubscriptionProductID(rawValue: productID) != nil else { return }
        lock.lock()
        defaults.set(productID, forKey: Keys.productID)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.markedAt)
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

    /// When this attempt was recorded. Missing on records written before the field existed.
    static func pendingMarkedAt() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let raw = defaults.double(forKey: Keys.markedAt)
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
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
        defaults.removeObject(forKey: Keys.markedAt)
        return (pending, tab)
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: Keys.productID)
        defaults.removeObject(forKey: Keys.requestedTab)
        defaults.removeObject(forKey: Keys.markedAt)
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
