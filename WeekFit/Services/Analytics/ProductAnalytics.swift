import Foundation

/// Dedupes `trackScreen` so SwiftUI recomputation / background / language resets
/// do not spam the same active destination.
final class ProductScreenTracker: @unchecked Sendable {
    static let shared = ProductScreenTracker()

    private let lock = NSLock()
    private var lastScreen: AnalyticsScreen?
    private let analyticsProvider: () -> AnalyticsTracking

    init(analytics: @escaping () -> AnalyticsTracking = { AppAnalytics.shared }) {
        self.analyticsProvider = analytics
    }

    /// Tracks only when the active product destination changes.
    func trackScreenIfChanged(_ screen: AnalyticsScreen) {
        let shouldTrack: Bool
        lock.lock()
        if lastScreen == screen {
            shouldTrack = false
        } else {
            lastScreen = screen
            shouldTrack = true
        }
        lock.unlock()

        // Never call Firebase/Crashlytics while holding `lock` — they may hop to MainActor
        // and deadlock with UI that also takes analytics locks during body evaluation.
        guard shouldTrack else { return }
        analyticsProvider().trackScreen(screen)
    }

    /// Forces a screen event even if it matches the last one (rare; prefer `trackScreenIfChanged`).
    func trackScreenForced(_ screen: AnalyticsScreen) {
        lock.lock()
        lastScreen = screen
        lock.unlock()
        analyticsProvider().trackScreen(screen)
    }

    func reset() {
        lock.lock()
        lastScreen = nil
        lock.unlock()
    }

    func resetForTests() {
        reset()
    }
}

/// Product-analytics helpers that always go through `AppAnalytics.shared`.
enum ProductAnalytics {
    private static var analytics: AnalyticsTracking { AppAnalytics.shared }

    static func trackScreen(_ screen: AnalyticsScreen) {
        ProductScreenTracker.shared.trackScreenIfChanged(screen)
    }

    static func trackTab(_ tab: WeekFitTab) {
        switch tab {
        case .today: trackScreen(.today)
        case .coach: trackScreen(.coach)
        case .meals: trackScreen(.meals)
        case .calendar: trackScreen(.plan)
        }
    }

    static func todayPrimaryActionTapped(_ category: TodayActionCategory) {
        analytics.track(
            .todayPrimaryActionTapped,
            parameters: [
                AnalyticsParameterKey.actionCategory: category.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func todaySectionOpened(_ section: TodaySection) {
        analytics.track(
            .todaySectionOpened,
            parameters: [
                AnalyticsParameterKey.section: section.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func quickLogOpened(category: TodayActionCategory) {
        analytics.track(
            .quickLogOpened,
            parameters: [
                AnalyticsParameterKey.actionCategory: category.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.today.rawValue
            ]
        )
    }

    static func coachRecommendationViewed(category: CoachRecommendationCategory = .general) {
        analytics.track(
            .coachRecommendationViewed,
            parameters: [
                AnalyticsParameterKey.category: category.rawValue,
                AnalyticsParameterKey.source: AnalyticsSource.coach.rawValue
            ]
        )
    }

    /// Maps scenario → bounded category; never sends copy or HealthKit values.
    static func coachRecommendationViewed(
        scenario: CoachScenarioKey,
        warningAlert: CoachSafetyAlert? = nil
    ) {
        coachRecommendationViewed(
            category: .from(scenario: scenario, warningAlert: warningAlert)
        )
    }

    static func foodLoggingStarted(method: FoodLoggingMethod, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteFoodStarted(method: method, source: source)
        analytics.track(
            .foodLoggingStarted,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func foodLoggingCompleted(method: FoodLoggingMethod, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteFoodTerminal()
        analytics.track(
            .foodLoggingCompleted,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func foodLoggingCancelled(method: FoodLoggingMethod, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteFoodTerminal()
        analytics.track(
            .foodLoggingCancelled,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    /// Cancels an open food flow if started and no terminal yet. Safe to call from sheet dismiss.
    @discardableResult
    static func foodLoggingCancelIfNeeded() -> Bool {
        ProductAnalyticsFlowTracker.shared.cancelFoodIfNeeded(analytics: analytics)
    }

    static func foodLoggingFailed(method: FoodLoggingMethod, source: AnalyticsSource, reason: SafeAnalyticsFailureReason) {
        ProductAnalyticsFlowTracker.shared.noteFoodTerminal()
        analytics.track(
            .foodLoggingFailed,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue,
                AnalyticsParameterKey.reason: reason.rawValue
            ]
        )
    }

    static func hydrationLoggingStarted(method: HydrationLoggingMethod, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteHydrationStarted(method: method, source: source)
        analytics.track(
            .hydrationLoggingStarted,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func hydrationLoggingCompleted(method: HydrationLoggingMethod, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteHydrationTerminal()
        analytics.track(
            .hydrationLoggingCompleted,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func hydrationLoggingCancelled(method: HydrationLoggingMethod, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteHydrationTerminal()
        analytics.track(
            .hydrationLoggingCancelled,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    @discardableResult
    static func hydrationLoggingCancelIfNeeded() -> Bool {
        ProductAnalyticsFlowTracker.shared.cancelHydrationIfNeeded(analytics: analytics)
    }

    static func hydrationLoggingFailed(method: HydrationLoggingMethod, source: AnalyticsSource, reason: SafeAnalyticsFailureReason) {
        ProductAnalyticsFlowTracker.shared.noteHydrationTerminal()
        analytics.track(
            .hydrationLoggingFailed,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue,
                AnalyticsParameterKey.reason: reason.rawValue
            ]
        )
    }

    static func mealBuilderStarted(mode: MealBuilderMode, source: AnalyticsSource) {
        analytics.track(
            .mealBuilderStarted,
            parameters: [
                AnalyticsParameterKey.mode: mode.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func mealBuilderCompleted(mode: MealBuilderMode, source: AnalyticsSource) {
        analytics.track(
            .mealBuilderCompleted,
            parameters: [
                AnalyticsParameterKey.mode: mode.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func mealBuilderCancelled(mode: MealBuilderMode, source: AnalyticsSource) {
        analytics.track(
            .mealBuilderCancelled,
            parameters: [
                AnalyticsParameterKey.mode: mode.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func mealBuilderFailed(mode: MealBuilderMode, source: AnalyticsSource, reason: SafeAnalyticsFailureReason) {
        analytics.track(
            .mealBuilderFailed,
            parameters: [
                AnalyticsParameterKey.mode: mode.rawValue,
                AnalyticsParameterKey.source: source.rawValue,
                AnalyticsParameterKey.reason: reason.rawValue
            ]
        )
    }

    static func barcodeScanStarted(source: AnalyticsSource) {
        analytics.track(
            .barcodeScanStarted,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
    }

    static func barcodeScanSucceeded(source: AnalyticsSource) {
        analytics.track(
            .barcodeScanSucceeded,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
    }

    static func barcodeScanFailed(source: AnalyticsSource, reason: BarcodeScanFailureReason) {
        analytics.track(
            .barcodeScanFailed,
            parameters: [
                AnalyticsParameterKey.source: source.rawValue,
                AnalyticsParameterKey.reason: reason.rawValue
            ]
        )
    }

    static func barcodeScanCancelled(source: AnalyticsSource) {
        analytics.track(
            .barcodeScanCancelled,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
    }

    static func activityLoggingStarted(source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteActivityLoggingStarted(source: source)
        analytics.track(
            .activityLoggingStarted,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
    }

    static func activityStarted(category: ActivityAnalyticsCategory, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteActivityLoggingTerminal()
        analytics.track(
            .activityStarted,
            parameters: [
                AnalyticsParameterKey.category: category.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func activityCompleted(category: ActivityAnalyticsCategory, source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteActivityLoggingTerminal()
        analytics.track(
            .activityCompleted,
            parameters: [
                AnalyticsParameterKey.category: category.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
    }

    static func activityCancelled(source: AnalyticsSource) {
        ProductAnalyticsFlowTracker.shared.noteActivityLoggingTerminal()
        analytics.track(
            .activityCancelled,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
    }

    @discardableResult
    static func activityLoggingCancelIfNeeded() -> Bool {
        ProductAnalyticsFlowTracker.shared.cancelActivityLoggingIfNeeded(analytics: analytics)
    }

    static func activityLoggingFailed(source: AnalyticsSource, reason: SafeAnalyticsFailureReason) {
        ProductAnalyticsFlowTracker.shared.noteActivityLoggingTerminal()
        analytics.track(
            .activityLoggingFailed,
            parameters: [
                AnalyticsParameterKey.source: source.rawValue,
                AnalyticsParameterKey.reason: reason.rawValue
            ]
        )
    }

    static func planItemCreationStarted(itemType: PlanItemAnalyticsType) {
        analytics.track(
            .planItemCreationStarted,
            parameters: [AnalyticsParameterKey.itemType: itemType.rawValue]
        )
    }

    static func planItemCreated(itemType: PlanItemAnalyticsType) {
        analytics.track(
            .planItemCreated,
            parameters: [AnalyticsParameterKey.itemType: itemType.rawValue]
        )
    }

    static func planItemEditStarted(itemType: PlanItemAnalyticsType) {
        analytics.track(
            .planItemEditStarted,
            parameters: [AnalyticsParameterKey.itemType: itemType.rawValue]
        )
    }

    static func planItemUpdated(itemType: PlanItemAnalyticsType) {
        analytics.track(
            .planItemUpdated,
            parameters: [AnalyticsParameterKey.itemType: itemType.rawValue]
        )
    }

    static func planItemCompleted(itemType: PlanItemAnalyticsType) {
        analytics.track(
            .planItemCompleted,
            parameters: [AnalyticsParameterKey.itemType: itemType.rawValue]
        )
    }

    static func planItemDeleted(itemType: PlanItemAnalyticsType) {
        analytics.track(
            .planItemDeleted,
            parameters: [AnalyticsParameterKey.itemType: itemType.rawValue]
        )
    }

    static func notificationOpened(category: NotificationOpenCategory) {
        analytics.track(
            .notificationOpened,
            parameters: [AnalyticsParameterKey.category: category.rawValue]
        )
    }

    static func healthSettingsOpened() {
        analytics.track(.healthSettingsOpened)
    }

    static func notificationSettingsOpened() {
        analytics.track(.notificationSettingsOpened)
    }

    static func languageChanged(_ code: AppLanguageAnalyticsCode) {
        analytics.track(
            .languageChanged,
            parameters: [AnalyticsParameterKey.language: code.rawValue]
        )
    }

    static func dataResetStarted() {
        analytics.track(.dataResetStarted)
    }

    static func dataResetCompleted() {
        analytics.track(.dataResetCompleted)
    }

    /// Maps planner option / activity type strings to a coarse category without titles.
    static func activityCategory(forType type: String) -> ActivityAnalyticsCategory {
        switch type.lowercased() {
        case "recovery": return .recovery
        case "walk", "walking", "hike": return .walking
        case "run", "running": return .running
        case "ride", "cycling", "bike": return .cycling
        case "swim", "swimming": return .swimming
        case "tennis", "squash", "racket", "badminton", "pickleball": return .racket
        case "strength", "weights", "gym": return .strength
        case "cardio", "hiit": return .cardio
        case "workout": return .other
        default: return .other
        }
    }
}
