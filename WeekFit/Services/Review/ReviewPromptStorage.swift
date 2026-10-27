import Foundation

protocol ReviewPromptStoring: AnyObject {
    func load() -> ReviewEligibilityState
    func save(_ state: ReviewEligibilityState)
    func reset()
}

final class ReviewPromptStorage: ReviewPromptStoring {

    enum Keys {
        static let firstAppUseDate = "weekfit.review.firstAppUseDate"
        static let activeDayTimestamps = "weekfit.review.activeDayTimestamps"
        static let meaningfulActionCount = "weekfit.review.meaningfulActionCount"
        static let lastMeaningfulActionDate = "weekfit.review.lastMeaningfulActionDate"
        static let lastFeedbackPromptDate = "weekfit.review.lastFeedbackPromptDate"
        static let lastPromptedAppVersion = "weekfit.review.lastPromptedAppVersion"
        static let systemReviewRequestVersion = "weekfit.review.systemReviewRequestVersion"
        static let nativeReviewRequestAttemptDate = "weekfit.review.nativeReviewRequestAttemptDate"
        static let migratedSystemAttemptSemantics = "weekfit.review.migratedSystemAttemptSemantics"
        static let lastFeedbackSentiment = "weekfit.review.lastFeedbackSentiment"
        static let isPermanentlyDismissed = "weekfit.review.isPermanentlyDismissed"
    }

    private let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReviewEligibilityState {
        migrateSystemAttemptIfNeeded()
        let activeDays = (defaults.array(forKey: Keys.activeDayTimestamps) as? [Double]) ?? []
        return ReviewEligibilityState(
            firstAppUseDate: date(for: Keys.firstAppUseDate),
            activeDayTimestamps: activeDays,
            meaningfulActionCount: defaults.integer(forKey: Keys.meaningfulActionCount),
            lastMeaningfulActionDate: date(for: Keys.lastMeaningfulActionDate),
            lastFeedbackPromptDate: date(for: Keys.lastFeedbackPromptDate),
            lastPromptedAppVersion: defaults.string(forKey: Keys.lastPromptedAppVersion),
            systemReviewRequestVersion: defaults.string(forKey: Keys.systemReviewRequestVersion),
            nativeReviewRequestAttemptDate: date(for: Keys.nativeReviewRequestAttemptDate),
            lastFeedbackSentimentRaw: defaults.string(forKey: Keys.lastFeedbackSentiment),
            isPermanentlyDismissed: defaults.bool(forKey: Keys.isPermanentlyDismissed)
        )
    }

    func save(_ state: ReviewEligibilityState) {
        setDate(state.firstAppUseDate, for: Keys.firstAppUseDate)
        defaults.set(state.activeDayTimestamps, forKey: Keys.activeDayTimestamps)
        defaults.set(state.meaningfulActionCount, forKey: Keys.meaningfulActionCount)
        setDate(state.lastMeaningfulActionDate, for: Keys.lastMeaningfulActionDate)
        setDate(state.lastFeedbackPromptDate, for: Keys.lastFeedbackPromptDate)
        defaults.set(state.lastPromptedAppVersion, forKey: Keys.lastPromptedAppVersion)
        if let version = state.systemReviewRequestVersion {
            defaults.set(version, forKey: Keys.systemReviewRequestVersion)
        } else {
            defaults.removeObject(forKey: Keys.systemReviewRequestVersion)
        }
        setDate(state.nativeReviewRequestAttemptDate, for: Keys.nativeReviewRequestAttemptDate)
        defaults.set(state.lastFeedbackSentimentRaw, forKey: Keys.lastFeedbackSentiment)
        defaults.set(state.isPermanentlyDismissed, forKey: Keys.isPermanentlyDismissed)
        defaults.set(true, forKey: Keys.migratedSystemAttemptSemantics)
    }

    func reset() {
        [
            Keys.firstAppUseDate,
            Keys.activeDayTimestamps,
            Keys.meaningfulActionCount,
            Keys.lastMeaningfulActionDate,
            Keys.lastFeedbackPromptDate,
            Keys.lastPromptedAppVersion,
            Keys.systemReviewRequestVersion,
            Keys.nativeReviewRequestAttemptDate,
            Keys.lastFeedbackSentiment,
            Keys.isPermanentlyDismissed,
            Keys.migratedSystemAttemptSemantics
        ].forEach { defaults.removeObject(forKey: $0) }
    }

    /// One-time split between the retired custom card and a real `requestReview` call.
    ///
    /// `nativeReviewRequestAttemptDate` was written only when the system API ran
    /// (positive answer on the old card, or the old Settings rate action).
    /// `lastPromptedAppVersion` and `lastFeedbackPromptDate` were written when the
    /// custom card appeared, before the user answered.
    ///
    /// - A stored system-attempt date keeps the 120-day cooldown. A version stored
    ///   beside it is copied forward. If that version came from an earlier card and
    ///   the date came from a later Settings call, keeping both only blocks — it
    ///   does not request review.
    /// - A card version or card date with no system-attempt date is not a system
    ///   request and is not copied.
    private func migrateSystemAttemptIfNeeded() {
        guard defaults.object(forKey: Keys.migratedSystemAttemptSemantics) == nil else { return }
        if date(for: Keys.nativeReviewRequestAttemptDate) != nil,
           let version = defaults.string(forKey: Keys.lastPromptedAppVersion) {
            defaults.set(version, forKey: Keys.systemReviewRequestVersion)
        } else {
            defaults.removeObject(forKey: Keys.systemReviewRequestVersion)
        }
        defaults.set(true, forKey: Keys.migratedSystemAttemptSemantics)
    }

    private func date(for key: String) -> Date? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    private func setDate(_ date: Date?, for key: String) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
