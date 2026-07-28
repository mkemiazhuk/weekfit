import Foundation

/// Session / lifecycle dedupe for first-run onboarding funnel events.
///
/// - `onboarding_started` once per onboarding lifecycle (until completion / reset)
/// - `onboarding_step_viewed` once per unique step per lifecycle (back/forward does not re-fire)
/// - `onboarding_completed` once after successful persistence of completion
///
/// Feature code should call these helpers (or `AppAnalytics.shared`) — never Firebase.
final class OnboardingFunnelAnalytics: @unchecked Sendable {
    static let shared = OnboardingFunnelAnalytics()

    enum Keys {
        static let started = "weekfit.onboarding.analytics.started"
        static let viewedSteps = "weekfit.onboarding.analytics.viewedSteps"
        static let completed = "weekfit.onboarding.analytics.completed"
    }

    static var allKnownKeys: [String] {
        [Keys.started, Keys.viewedSteps, Keys.completed]
    }

    private let defaults: UserDefaults
    private let analyticsProvider: () -> AnalyticsTracking
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        analytics: @escaping () -> AnalyticsTracking = { AppAnalytics.shared }
    ) {
        self.defaults = defaults
        self.analyticsProvider = analytics
    }

    func trackStartedIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !defaults.bool(forKey: Keys.started) else { return }
        defaults.set(true, forKey: Keys.started)
        analyticsProvider().track(.onboardingStarted)
    }

    func trackStepViewedIfNeeded(_ step: OnboardingAnalyticsStep) {
        lock.lock()
        defer { lock.unlock() }
        var viewed = Set(defaults.stringArray(forKey: Keys.viewedSteps) ?? [])
        guard !viewed.contains(step.rawValue) else { return }
        viewed.insert(step.rawValue)
        defaults.set(Array(viewed).sorted(), forKey: Keys.viewedSteps)
        analyticsProvider().track(
            .onboardingStepViewed,
            parameters: [AnalyticsParameterKey.step: step.rawValue]
        )
    }

    /// Call only after onboarding completion has been persisted.
    func trackCompletedIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !defaults.bool(forKey: Keys.completed) else { return }
        defaults.set(true, forKey: Keys.completed)
        analyticsProvider().track(.onboardingCompleted)
    }

    func trackHealthConnectionStarted() {
        analyticsProvider().track(.healthConnectionStarted)
    }

    func trackHealthConnectionCompleted() {
        analyticsProvider().track(.healthConnectionCompleted)
    }

    func trackHealthConnectionDeclined() {
        analyticsProvider().track(.healthConnectionDeclined)
    }

    func trackHealthConnectionFailed(reason: HealthConnectionFailureReason) {
        analyticsProvider().track(
            .healthConnectionFailed,
            parameters: [AnalyticsParameterKey.reason: reason.rawValue]
        )
    }

    func resetForTests() {
        lock.lock()
        defer { lock.unlock() }
        Self.allKnownKeys.forEach(defaults.removeObject(forKey:))
    }
}
