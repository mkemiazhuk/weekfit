import Foundation

/// Strongly typed screen names for screen_view analytics.
///
/// Identifiers match shipped product destinations. Insights/Highlights are unshipped.
enum AnalyticsScreen: String, Sendable, CaseIterable {
    case today = "today"
    case coach = "coach"
    case meals = "meals"
    case plan = "plan"
    case settings = "settings"
    case onboarding = "onboarding"
    case recoveryDetails = "recovery_details"
    case activityDetails = "activity_details"
    case nutritionDetails = "nutrition_details"
    case mealBuilder = "meal_builder"
    case helpWeekFit = "help_weekfit"
    case feedbackForm = "feedback_form"
    case paywall = "paywall"

    /// Legacy alias kept for any older references.
    static var profile: AnalyticsScreen { .settings }
}
