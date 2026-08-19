import Foundation
import UserNotifications

/// Bounded, non-localized analytics parameter keys and values.
/// Never put HealthKit quantities, free-form text, or PII in parameters.
enum AnalyticsParameterKey {
    static let step = "step"
    static let reason = "reason"
    static let status = "status"
    static let source = "source"
    static let method = "method"
    static let category = "category"
    static let section = "section"
    static let actionCategory = "action_category"
    static let mode = "mode"
    static let itemType = "item_type"
    static let language = "language"
    static let changeKind = "change_kind"
    static let reasonCategory = "reason_category"
    static let selectedCountBucket = "selected_count_bucket"
    static let appliedCountBucket = "applied_count_bucket"
    static let resultType = "result_type"
    static let surface = "surface"
    static let productID = "product_id"
    /// Release channel: `testflight` | `appstore` (set as default event parameter).
    static let distribution = "distribution"
}

/// Stable onboarding step identifiers matching `FirstRunOnboardingView.Step`.
enum OnboardingAnalyticsStep: String, Sendable, CaseIterable {
    case promise
    case goal
    case health
    case understanding
    case ready
}

/// Technical failure reasons for `health_connection_failed` only.
enum HealthConnectionFailureReason: String, Sendable {
    case unavailable
    case authorizationError = "authorization_error"
    case configurationError = "configuration_error"
    case unknown
}

/// System notification authorization outcomes for analytics.
enum NotificationPermissionAnalyticsStatus: String, Sendable {
    case authorized
    case denied
    case provisional
    case ephemeral
    case unknown

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        case .notDetermined: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

enum AnalyticsSource: String, Sendable {
    case today
    case meals
    case coach
    case plan
    case quickLog = "quick_log"
    case hydration
    case settings
    case notification
    case other
}

enum TodayActionCategory: String, Sendable {
    case coach
    case food
    case hydration
    case activity
    case recovery
    case plan
    case other
}

enum TodaySection: String, Sendable {
    case recovery
    case activity
    case nutrition
    case hydration
    case sleep
    case other
}

enum FoodLoggingMethod: String, Sendable {
    case manual
    case recent
    case barcode
    case mealBuilder = "meal_builder"
    case quickLog = "quick_log"
    case other
}

enum HydrationLoggingMethod: String, Sendable {
    case quickLog = "quick_log"
    case manual
    case recent
    case other
}

enum SafeAnalyticsFailureReason: String, Sendable {
    case invalidInput = "invalid_input"
    case lookupFailed = "lookup_failed"
    case saveFailed = "save_failed"
    case unavailable
    case unknown
}

enum BarcodeScanFailureReason: String, Sendable {
    case cameraPermissionDenied = "camera_permission_denied"
    case cameraUnavailable = "camera_unavailable"
    case barcodeNotRecognized = "barcode_not_recognized"
    case productNotFound = "product_not_found"
    case network
    case decoding
    case unknown
}

enum MealBuilderMode: String, Sendable {
    case new
    case edit
}

enum ActivityAnalyticsCategory: String, Sendable {
    case strength
    case cardio
    case walking
    case running
    case cycling
    case swimming
    case racket
    case recovery
    case other
}

enum PlanItemAnalyticsType: String, Sendable {
    case activity
    case meal
    case hydration
    case recovery
    case habit
    case other

    init(plannerTypeTitle: String) {
        switch plannerTypeTitle.lowercased() {
        case "meal": self = .meal
        case "workout": self = .activity
        case "recovery": self = .recovery
        case "habit": self = .habit
        case "drink", "water": self = .hydration
        default: self = .other
        }
    }

    init(plannedActivityType: String) {
        switch plannedActivityType.lowercased() {
        case "meal", "snack": self = .meal
        case "workout": self = .activity
        case "recovery": self = .recovery
        case "habit": self = .habit
        case "drink": self = .hydration
        default: self = .other
        }
    }
}

enum CoachRecommendationCategory: String, Sendable {
    case recovery
    case activity
    case nutrition
    case hydration
    case sleep
    case general
}

enum NotificationOpenCategory: String, Sendable {
    case activity
    case hydration
    case meal
    case recovery
    case plan
    case general
}

enum AppLanguageAnalyticsCode: String, Sendable {
    case en
    case ru
    case other

    init(languageCode: String) {
        switch languageCode.lowercased() {
        case "en": self = .en
        case "ru": self = .ru
        default: self = .other
        }
    }
}

enum MorningProposalAnalyticsSurface: String, Sendable {
    case today
    case review
    case coach
    case plan
    case activityDetail = "activity_detail"
    case other
}

enum MorningProposalReasonCategory: String, Sendable {
    case recoveryProtection = "recovery_protection"
    case loadProtection = "load_protection"
    case tomorrowProtection = "tomorrow_protection"
    case recoverySupport = "recovery_support"
    case confidence
    case planAppropriate = "plan_appropriate"
    case other

    init(_ code: CoachProposalReasonCode) {
        switch code {
        case .lowRecoveryLoadProtection:
            self = .recoveryProtection
        case .heavyYesterdayProtection, .stackedDayRisk:
            self = .loadProtection
        case .tomorrowDemandProtection:
            self = .tomorrowProtection
        case .recoveryWalkSupport, .recoveryStretchSupport:
            self = .recoverySupport
        case .insufficientConfidence:
            self = .confidence
        case .planAlreadyAppropriate:
            self = .planAppropriate
        case .openDayMovementSupport:
            self = .recoverySupport
        case .similarDaySupport:
            self = .planAppropriate
        case .libraryMealSupport,
             .libraryMealRecoveryBreakfast,
             .libraryMealRecoveryLunch,
             .libraryMealRecoveryDinner,
             .libraryMealSteadyBreakfast,
             .libraryMealSteadyLunch,
             .libraryMealSteadyDinner:
            self = .planAppropriate
        case .weatherOutdoorConflict, .weatherHeatLoad:
            self = .loadProtection
        }
    }
}

enum MorningProposalApplyResultType: String, Sendable {
    case succeeded
    case partial
    case failed
    case stale
    case noValidMutations = "no_valid_mutations"
}

enum MorningProposalCountBucket: String, Sendable {
    case zero = "0"
    case one = "1"
    case two = "2"
    case threeToFour = "3_4"
    case fivePlus = "5_plus"

    init(count: Int) {
        switch count {
        case ..<0: self = .zero
        case 0: self = .zero
        case 1: self = .one
        case 2: self = .two
        case 3...4: self = .threeToFour
        default: self = .fivePlus
        }
    }
}

extension CoachChangeKind {
    var analyticsRawValue: String { rawValue }
}
