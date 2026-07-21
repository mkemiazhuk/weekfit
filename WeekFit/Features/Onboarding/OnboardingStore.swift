import Foundation
import OSLog

/// First-run onboarding and one-time contextual intro persistence.
enum OnboardingStore {
    enum Keys {
        static let completed = "weekfit.onboarding.completed"
        static let step = "weekfit.onboarding.step"
        static let flowVersion = "weekfit.onboarding.flowVersion"
        static let introToday = "weekfit.onboarding.intro.today"
        static let introCoach = "weekfit.onboarding.intro.coach"
        static let introPlan = "weekfit.onboarding.intro.plan"
        static let introMeals = "weekfit.onboarding.intro.meals"
    }

    /// Bump when step enum / journey shape changes so mid-flow resume stays valid.
    static let currentFlowVersion = 13

    static var allKnownKeys: [String] {
        [
            Keys.completed,
            Keys.step,
            Keys.flowVersion,
            Keys.introToday,
            Keys.introCoach,
            Keys.introPlan,
            Keys.introMeals
        ]
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.completed) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.completed) }
    }

    /// Persists mid-flow progress so relaunch resumes the same step.
    static var persistedStepRawValue: Int? {
        get {
            migrateFlowVersionIfNeeded()
            guard UserDefaults.standard.object(forKey: Keys.step) != nil else { return nil }
            return UserDefaults.standard.integer(forKey: Keys.step)
        }
        set {
            UserDefaults.standard.set(currentFlowVersion, forKey: Keys.flowVersion)
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Keys.step)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.step)
            }
        }
    }

    private static func migrateFlowVersionIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: Keys.flowVersion)
        guard stored != currentFlowVersion else { return }
        UserDefaults.standard.removeObject(forKey: Keys.step)
        UserDefaults.standard.set(currentFlowVersion, forKey: Keys.flowVersion)
    }

    /// Existing installs that already set a goal or requested Health should not see first-run onboarding.
    static func migrateExistingUsersIfNeeded() {
        guard !hasCompletedOnboarding else { return }

        let defaults = UserDefaults.standard
        let hasManualGoal = defaults.bool(forKey: ProfileService.Keys.nutritionGoalIsManual)
        let healthRequested = defaults.bool(forKey: "weekfit.healthAccessRequested")

        if hasManualGoal || healthRequested {
            hasCompletedOnboarding = true
            persistedStepRawValue = nil
            dismissAllTabIntros()
        }
    }

    static func markCompleted() {
        hasCompletedOnboarding = true
        persistedStepRawValue = nil
        dismissAllTabIntros()
    }

    static func dismissAllTabIntros() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.introToday)
        defaults.set(true, forKey: Keys.introCoach)
        defaults.set(true, forKey: Keys.introPlan)
        defaults.set(true, forKey: Keys.introMeals)
    }

    static func shouldShowIntro(for key: String) -> Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    static func dismissIntro(for key: String) {
        UserDefaults.standard.set(true, forKey: key)
    }
}

/// Lightweight funnel hooks — no PII / health values.
/// Debug builds only: Release stays quiet (no console / os_log spam).
enum OnboardingAnalytics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.weekfit.app",
        category: "Onboarding"
    )

    static func started() {
        #if DEBUG
        logger.debug("started flow_version=\(OnboardingStore.currentFlowVersion, privacy: .public)")
        #endif
    }

    static func stepViewed(_ step: String) {
        #if DEBUG
        logger.debug("step_viewed=\(step, privacy: .public)")
        #endif
    }

    static func stepBack(from: String, to: String) {
        #if DEBUG
        logger.debug("step_back from=\(from, privacy: .public) to=\(to, privacy: .public)")
        #endif
    }

    static func healthConnectTapped() {
        #if DEBUG
        logger.debug("health_connect_tapped")
        #endif
    }

    static func healthSkipped() {
        #if DEBUG
        logger.debug("health_skipped")
        #endif
    }

    static func healthAuthorization(result: String) {
        #if DEBUG
        logger.debug("health_authorization=\(result, privacy: .public)")
        #endif
    }

    static func completed() {
        #if DEBUG
        logger.debug("completed")
        #endif
    }

    static func finalCTATapped() {
        #if DEBUG
        logger.debug("final_cta_tapped")
        #endif
    }
}
