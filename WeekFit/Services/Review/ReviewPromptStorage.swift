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
        static let nativeReviewRequestAttemptDate = "weekfit.review.nativeReviewRequestAttemptDate"
        static let lastFeedbackSentiment = "weekfit.review.lastFeedbackSentiment"
        static let isPermanentlyDismissed = "weekfit.review.isPermanentlyDismissed"
    }

    private let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReviewEligibilityState {
        let activeDays = (defaults.array(forKey: Keys.activeDayTimestamps) as? [Double]) ?? []
        return ReviewEligibilityState(
            firstAppUseDate: date(for: Keys.firstAppUseDate),
            activeDayTimestamps: activeDays,
            meaningfulActionCount: defaults.integer(forKey: Keys.meaningfulActionCount),
            lastMeaningfulActionDate: date(for: Keys.lastMeaningfulActionDate),
            lastFeedbackPromptDate: date(for: Keys.lastFeedbackPromptDate),
            lastPromptedAppVersion: defaults.string(forKey: Keys.lastPromptedAppVersion),
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
        setDate(state.nativeReviewRequestAttemptDate, for: Keys.nativeReviewRequestAttemptDate)
        defaults.set(state.lastFeedbackSentimentRaw, forKey: Keys.lastFeedbackSentiment)
        defaults.set(state.isPermanentlyDismissed, forKey: Keys.isPermanentlyDismissed)
    }

    func reset() {
        [
            Keys.firstAppUseDate,
            Keys.activeDayTimestamps,
            Keys.meaningfulActionCount,
            Keys.lastMeaningfulActionDate,
            Keys.lastFeedbackPromptDate,
            Keys.lastPromptedAppVersion,
            Keys.nativeReviewRequestAttemptDate,
            Keys.lastFeedbackSentiment,
            Keys.isPermanentlyDismissed
        ].forEach { defaults.removeObject(forKey: $0) }
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
