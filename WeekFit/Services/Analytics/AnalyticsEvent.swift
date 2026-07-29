import Foundation

/// Strongly typed product analytics events.
///
/// Cases may be added ahead of call sites. Do not log HealthKit or personal data
/// in event parameters when instrumenting features.
enum AnalyticsEvent: String, Sendable {
    // Foundation / lifecycle — reserved; Firebase auto-collects sessions.
    case appOpened = "app_opened"

    // Onboarding / activation funnel.
    case onboardingStarted = "onboarding_started"
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingCompleted = "onboarding_completed"

    case healthConnectionStarted = "health_connection_started"
    case healthConnectionCompleted = "health_connection_completed"
    case healthConnectionDeclined = "health_connection_declined"
    case healthConnectionFailed = "health_connection_failed"

    case notificationPermissionResponded = "notification_permission_responded"
    case notificationOpened = "notification_opened"

    // Today.
    case todayPrimaryActionTapped = "today_primary_action_tapped"
    case todaySectionOpened = "today_section_opened"
    case quickLogOpened = "quick_log_opened"

    // Coach (view only — no reliable tap/complete/dismiss handlers in product UI).
    case coachRecommendationViewed = "coach_recommendation_viewed"

    // Food logging.
    case foodLoggingStarted = "food_logging_started"
    case foodLoggingCompleted = "food_logging_completed"
    case foodLoggingCancelled = "food_logging_cancelled"
    case foodLoggingFailed = "food_logging_failed"

    // Meal builder.
    case mealBuilderStarted = "meal_builder_started"
    case mealBuilderCompleted = "meal_builder_completed"
    case mealBuilderCancelled = "meal_builder_cancelled"
    case mealBuilderFailed = "meal_builder_failed"

    // Barcode (photo → Vision → lookup).
    case barcodeScanStarted = "barcode_scan_started"
    case barcodeScanSucceeded = "barcode_scan_succeeded"
    case barcodeScanFailed = "barcode_scan_failed"
    case barcodeScanCancelled = "barcode_scan_cancelled"

    // Hydration.
    case hydrationLoggingStarted = "hydration_logging_started"
    case hydrationLoggingCompleted = "hydration_logging_completed"
    case hydrationLoggingCancelled = "hydration_logging_cancelled"
    case hydrationLoggingFailed = "hydration_logging_failed"

    // Activity (user-initiated only — not HealthKit imports).
    case activityLoggingStarted = "activity_logging_started"
    case activityStarted = "activity_started"
    case activityCompleted = "activity_completed"
    case activityCancelled = "activity_cancelled"
    case activityLoggingFailed = "activity_logging_failed"

    // Plan.
    case planItemCreationStarted = "plan_item_creation_started"
    case planItemCreated = "plan_item_created"
    case planItemEditStarted = "plan_item_edit_started"
    case planItemUpdated = "plan_item_updated"
    case planItemCompleted = "plan_item_completed"
    case planItemDeleted = "plan_item_deleted"

    // Settings / account management.
    case healthSettingsOpened = "health_settings_opened"
    case notificationSettingsOpened = "notification_settings_opened"
    case languageChanged = "language_changed"
    case dataResetStarted = "data_reset_started"
    case dataResetCompleted = "data_reset_completed"

    // Review funnel — wired via ReviewAnalytics → AppAnalytics (same raw names).
    // Does not include a review_submitted event: iOS never confirms App Store review completion.
    case reviewEligibilityReached = "review_eligibility_reached"
    case reviewFeedbackSheetShown = "review_feedback_sheet_shown"
    case reviewFeedbackSelected = "review_feedback_selected"
    case nativeReviewRequestAttempted = "native_review_request_attempted"
    case feedbackFormOpened = "feedback_form_opened"
    case feedbackSubmitted = "feedback_submitted"
    case feedbackDismissed = "feedback_dismissed"
    case rateWeekFitSelectedFromSettings = "rate_weekfit_selected_from_settings"

    // Recovery Stress Index — UI interactions only (no score, category, or health values).
    case stressIndexViewed = "stress_index_viewed"
    case stressIndexDetailsOpened = "stress_index_details_opened"
}
