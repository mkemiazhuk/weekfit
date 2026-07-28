import Foundation
import UIKit

enum FeedbackSentiment: String, Codable, CaseIterable, Sendable {
    case great
    case okay
    case needsImprovement

    var analyticsName: String {
        switch self {
        case .great: return "great"
        case .okay: return "okay"
        case .needsImprovement: return "needs_improvement"
        }
    }
}

enum FeedbackCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case coaching
    case recovery
    case nutrition
    case activity
    case appleHealth
    case performance
    case bug
    case other
    case featureSuggestion

    var id: String { rawValue }

    var analyticsName: String {
        switch self {
        case .appleHealth: return "apple_health"
        case .featureSuggestion: return "feature_suggestion"
        default: return rawValue
        }
    }

    var localizationKey: String {
        "review.feedback.category.\(rawValue)"
    }
}

enum FeedbackFormIntent: String, Sendable, Hashable {
    case general
    case suggestFeature
    case reportProblem
    case postSentiment

    var preferredCategory: FeedbackCategory? {
        switch self {
        case .general: return nil
        case .suggestFeature: return .featureSuggestion
        case .reportProblem: return .bug
        case .postSentiment: return nil
        }
    }

    var titleKey: String {
        switch self {
        case .general: return "review.feedback.form.title.general"
        case .suggestFeature: return "review.feedback.form.title.feature"
        case .reportProblem: return "review.feedback.form.title.problem"
        case .postSentiment: return "review.feedback.form.title.followUp"
        }
    }
}

struct FeedbackDraft: Equatable, Sendable {
    var category: FeedbackCategory?
    var message: String
    var allowContact: Bool
    var sentiment: FeedbackSentiment?
    var intent: FeedbackFormIntent

    static func blank(intent: FeedbackFormIntent = .general, sentiment: FeedbackSentiment? = nil) -> FeedbackDraft {
        FeedbackDraft(
            category: intent.preferredCategory,
            message: "",
            allowContact: false,
            sentiment: sentiment,
            intent: intent
        )
    }
}

/// Non-sensitive metadata safe to attach to feedback submissions.
struct FeedbackMetadata: Equatable, Sendable {
    var appVersion: String
    var buildNumber: String
    var iOSVersion: String
    var deviceModel: String
    var localeIdentifier: String
    var category: String?

    static func current(category: FeedbackCategory? = nil, bundle: Bundle = .main) -> FeedbackMetadata {
        FeedbackMetadata(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            iOSVersion: UIDevice.current.systemVersion,
            deviceModel: deviceModelIdentifier(),
            localeIdentifier: Locale.current.identifier,
            category: category?.analyticsName
        )
    }

    /// Ensures callers never accidentally serialize health values into feedback payloads.
    var dictionaryRepresentation: [String: String] {
        var dict: [String: String] = [
            "app_version": appVersion,
            "build_number": buildNumber,
            "ios_version": iOSVersion,
            "device_model": deviceModel,
            "locale": localeIdentifier
        ]
        if let category {
            dict["feedback_category"] = category
        }
        return dict
    }

    /// Non-personal diagnostic blurb for Settings copy-to-clipboard.
    var diagnosticClipboardText: String {
        """
        WeekFit \(appVersion) (\(buildNumber))
        iOS \(iOSVersion)
        \(deviceModel)
        """
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? UIDevice.current.model
            }
        }
    }
}

struct FeedbackSubmission: Equatable, Sendable {
    var draft: FeedbackDraft
    var metadata: FeedbackMetadata
}
