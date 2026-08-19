import Foundation

/// One-time presentation flag for the grandfathering thank-you sheet.
/// Not used for entitlement — only to avoid repeating the message.
enum LegacyAccessThanksStore {
    static let key = "weekfit.subscription.legacyThanksShown"

    static var hasShown: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
