import Foundation
import OSLog

enum ReviewAnalyticsEvent: String, Sendable {
    case reviewEligibilityReached = "review_eligibility_reached"
    case reviewFeedbackSheetShown = "review_feedback_sheet_shown"
    case reviewFeedbackSelected = "review_feedback_selected"
    case nativeReviewRequestAttempted = "native_review_request_attempted"
    case feedbackFormOpened = "feedback_form_opened"
    case feedbackSubmitted = "feedback_submitted"
    case feedbackDismissed = "feedback_dismissed"
    case rateWeekFitSelectedFromSettings = "rate_weekfit_selected_from_settings"

    /// Maps onto the shared `AnalyticsEvent` catalog (same raw names).
    var analyticsEvent: AnalyticsEvent? {
        AnalyticsEvent(rawValue: rawValue)
    }
}

protocol ReviewAnalyticsTracking: AnyObject {
    func track(_ event: ReviewAnalyticsEvent, properties: [String: String])
}

/// Review funnel sink: forwards sanitized events to `AppAnalytics` (Firebase in production).
/// DEBUG builds also emit OSLog; production does not spam logs.
///
/// Does **not** claim an App Store review was submitted — iOS never confirms that.
final class ReviewAnalytics: ReviewAnalyticsTracking {
    static let shared = ReviewAnalytics()

    private let logger = Logger(subsystem: "com.weekfit.app", category: "ReviewAnalytics")
    private let lock = NSLock()
    private let analyticsProvider: () -> AnalyticsTracking
    private(set) var recordedEvents: [(event: ReviewAnalyticsEvent, properties: [String: String])] = []

    init(analytics: @escaping () -> AnalyticsTracking = { AppAnalytics.shared }) {
        self.analyticsProvider = analytics
    }

    func track(_ event: ReviewAnalyticsEvent, properties: [String: String] = [:]) {
        let sanitized = ReviewAnalyticsProperties.sanitize(properties)

        lock.lock()
        recordedEvents.append((event, sanitized))
        lock.unlock()

        #if DEBUG
        let props = sanitized
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: " ")
        logger.debug("\(event.rawValue, privacy: .public) \(props, privacy: .public)")
        #endif

        guard let analyticsEvent = event.analyticsEvent else { return }
        analyticsProvider().track(analyticsEvent, parameters: sanitized)
    }

    func resetForTests() {
        lock.lock()
        recordedEvents.removeAll()
        lock.unlock()
    }
}

enum ReviewAnalyticsProperties {
    static let appVersion = "app_version"
    static let triggerSource = "trigger_source"
    static let surface = "surface"
    static let feedbackSentiment = "feedback_sentiment"
    static let feedbackIntent = "feedback_intent"
    static let feedbackCategory = "feedback_category"
    static let daysSinceFirstUseBucket = "days_since_first_use_bucket"
    static let distinctActiveDaysBucket = "distinct_active_days_bucket"
    static let meaningfulActionCountBucket = "meaningful_action_count_bucket"

    private static let allowedKeys: Set<String> = [
        appVersion,
        triggerSource,
        surface,
        feedbackSentiment,
        feedbackIntent,
        feedbackCategory,
        daysSinceFirstUseBucket,
        distinctActiveDaysBucket,
        meaningfulActionCountBucket
    ]

    static func base(
        appVersion: String,
        triggerSource: String,
        decision: ReviewEligibilityDecision? = nil
    ) -> [String: String] {
        var props: [String: String] = [
            self.appVersion: appVersion,
            self.triggerSource: boundedTriggerSource(triggerSource)
        ]
        if let decision {
            props[daysSinceFirstUseBucket] = eligibilityBucket(decision.daysSinceFirstUse)
            props[distinctActiveDaysBucket] = eligibilityBucket(decision.distinctActiveDays)
            props[meaningfulActionCountBucket] = eligibilityBucket(decision.meaningfulActionCount)
        }
        return props
    }

    /// Drops free text / unknown keys; buckets legacy exact counts if still passed.
    static func sanitize(_ properties: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in properties {
            switch key {
            case triggerSource:
                out[key] = boundedTriggerSource(value)
            case surface:
                out[key] = boundedSurface(value)
            case feedbackSentiment, feedbackIntent, feedbackCategory, appVersion:
                out[key] = value
            case daysSinceFirstUseBucket, distinctActiveDaysBucket, meaningfulActionCountBucket:
                out[key] = value
            case "days_since_first_use", "distinct_active_days", "meaningful_action_count":
                // Legacy exact counts → coarse buckets (never send raw integers to Firebase).
                let mappedKey: String = {
                    switch key {
                    case "days_since_first_use": return daysSinceFirstUseBucket
                    case "distinct_active_days": return distinctActiveDaysBucket
                    default: return meaningfulActionCountBucket
                    }
                }()
                if let intValue = Int(value) {
                    out[mappedKey] = eligibilityBucket(intValue)
                }
            default:
                continue
            }
        }
        return out.filter { allowedKeys.contains($0.key) }
    }

    static func eligibilityBucket(_ value: Int) -> String {
        switch value {
        case ...2: return "0_2"
        case 3...4: return "3_4"
        default: return "5_plus"
        }
    }

    static func boundedTriggerSource(_ raw: String) -> String {
        if ReviewPromptTriggerSource(rawValue: raw) != nil {
            return raw
        }
        return "other"
    }

    static func boundedSurface(_ raw: String) -> String {
        switch raw {
        case "soft_prompt", "settings_in_app":
            return raw
        default:
            return "other"
        }
    }
}
