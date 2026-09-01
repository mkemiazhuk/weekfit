import Foundation

/// Hard boundary: Firebase Analytics parameters must be product-interaction only.
/// No HealthKit, recovery, sleep, readiness, nutrition quantities, or derived health state.
enum AnalyticsPrivacyContract {

    /// Parameter keys that must never leave the device via Analytics.
    static let forbiddenKeys: Set<String> = [
        "recovery_band",
        "has_sleep_data",
        "source_state",
        "proposal_strategy",
        "context_confidence",
        "reason_category",
        "sleep_hours",
        "sleep_score",
        "hrv",
        "rhr",
        "resting_heart_rate",
        "recovery_score",
        "readiness",
        "training_load",
        "calories",
        "macros",
        "protein",
        "carbs",
        "fats",
        "hydration_ml",
        "hydration_amount",
        "barcode",
        "food_name",
        "meal_title",
        "workout_name",
        "user_id",
        "email",
        "name",
        "workspace_id",
        "account_id"
    ]

    /// Substrings that must not appear in parameter **values** (case-insensitive).
    static let forbiddenValueSubstrings: [String] = [
        "recovery_band",
        "has_sleep",
        "hrv",
        "readiness",
        "training_load",
        "deep_sleep",
        "rem_sleep",
        "health_access_denied",
        "healthkit"
    ]

    /// Coach / health topic categories that must not be sent as `category` values.
    static let forbiddenHealthTopicCategories: Set<String> = [
        "sleep",
        "recovery",
        "nutrition",
        "hydration"
    ]

    static func violations(in parameters: [String: String]) -> [String] {
        var found: [String] = []
        for (key, value) in parameters {
            let keyLower = key.lowercased()
            if forbiddenKeys.contains(keyLower) {
                found.append("key:\(key)")
            }
            let valueLower = value.lowercased()
            for needle in forbiddenValueSubstrings where valueLower.contains(needle) {
                found.append("value:\(key)=\(value)")
            }
            if keyLower == "category", forbiddenHealthTopicCategories.contains(valueLower) {
                found.append("health_topic_category:\(value)")
            }
        }
        return found
    }

    /// Last-line strip before Firebase upload. Builders should not emit these.
    static func sanitize(_ parameters: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in parameters {
            let keyLower = key.lowercased()
            if forbiddenKeys.contains(keyLower) { continue }
            let valueLower = value.lowercased()
            if forbiddenValueSubstrings.contains(where: { valueLower.contains($0) }) { continue }
            if keyLower == "category", forbiddenHealthTopicCategories.contains(valueLower) {
                continue
            }
            out[key] = value
        }
        return out
    }
}

extension CoachChangeKind {
    /// Coarse interaction kind for Analytics — no recovery/meal semantics in the token.
    var analyticsInteractionKind: String {
        switch self {
        case .modifyDuration:
            return "modify"
        case .moveActivity:
            return "move"
        case .skipActivity:
            return "skip"
        case .createRecoveryWalk, .createPlannedActivity, .createMealFromLibrary:
            return "create"
        case .guidanceOnly:
            return "guidance"
        }
    }
}
