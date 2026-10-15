import Foundation

extension Notification.Name {
    /// Posted when the one-time AI photo free trial is consumed (client UX gate).
    static let weekFitPhotoAIFreeTrialConsumed = Notification.Name("WeekFit.photoAI.freeTrialConsumed")
}

/// One complimentary cloud AI photo analysis per install for non‑paid users.
/// Server also enforces once-per Firebase UID; this store drives client UX/gating.
enum PhotoFoodFreeTrialStore {
    static let defaultsKey = "WeekFit.photoAI.freeTrialConsumed"

    private static var defaults: UserDefaults { .standard }

    static var hasRemaining: Bool {
        defaults.bool(forKey: defaultsKey) == false
    }

    static var isConsumed: Bool {
        defaults.bool(forKey: defaultsKey)
    }

    static func markConsumed() {
        guard !isConsumed else { return }
        defaults.set(true, forKey: defaultsKey)
        NotificationCenter.default.post(name: .weekFitPhotoAIFreeTrialConsumed, object: nil)
    }

    /// DEBUG / account reset only.
    static func resetForTesting() {
        defaults.removeObject(forKey: defaultsKey)
    }
}
