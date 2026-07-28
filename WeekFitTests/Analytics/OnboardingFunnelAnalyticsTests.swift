import XCTest
import UserNotifications
@testable import WeekFit

final class OnboardingFunnelAnalyticsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var recording: RecordingAnalyticsService!
    private var funnel: OnboardingFunnelAnalytics!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.onboarding.analytics.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        funnel = OnboardingFunnelAnalytics(defaults: defaults, analytics: { AppAnalytics.shared })
        OnboardingStore.allKnownKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.removeObject(forKey: ProfileService.Keys.nutritionGoalIsManual)
        UserDefaults.standard.removeObject(forKey: "weekfit.healthAccessRequested")
    }

    override func tearDown() {
        AppAnalytics.resetSharedForTests()
        defaults.removePersistentDomain(forName: suiteName)
        OnboardingStore.allKnownKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        recording = nil
        funnel = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testOnboardingStartIsNotDuplicatedWithinSession() {
        funnel.trackStartedIfNeeded()
        funnel.trackStartedIfNeeded()
        funnel.trackStartedIfNeeded()

        XCTAssertEqual(recording.events(named: .onboardingStarted).count, 1)
    }

    func testStepIdentifiersMapToStableAnalyticsValues() {
        for step in OnboardingAnalyticsStep.allCases {
            funnel.trackStepViewedIfNeeded(step)
        }

        let values = recording.parameterValues(for: .onboardingStepViewed, key: AnalyticsParameterKey.step)
        XCTAssertEqual(
            Set(values),
            Set(OnboardingAnalyticsStep.allCases.map(\.rawValue))
        )
        XCTAssertEqual(
            Set(values),
            Set(["promise", "goal", "health", "understanding", "ready"])
        )

        // Back/forward must not re-fire the same step in one lifecycle.
        funnel.trackStepViewedIfNeeded(.promise)
        funnel.trackStepViewedIfNeeded(.goal)
        XCTAssertEqual(recording.events(named: .onboardingStepViewed).count, OnboardingAnalyticsStep.allCases.count)
    }

    func testCompletionTrackedOnlyAfterSuccessfulPersistence() {
        XCTAssertFalse(OnboardingStore.hasCompletedOnboarding)
        XCTAssertEqual(recording.events(named: .onboardingCompleted).count, 0)

        // Production path: finish() → OnboardingStore.markCompleted() after persistence.
        OnboardingStore.markCompleted()
        XCTAssertTrue(OnboardingStore.hasCompletedOnboarding)
        XCTAssertEqual(recording.events(named: .onboardingCompleted).count, 1)

        OnboardingStore.markCompleted()
        XCTAssertEqual(recording.events(named: .onboardingCompleted).count, 1)
    }

    func testHealthConnectionSuccessEmitsExpectedEvent() {
        funnel.trackHealthConnectionStarted()
        funnel.trackHealthConnectionCompleted()

        XCTAssertEqual(recording.events(named: .healthConnectionStarted).count, 1)
        XCTAssertEqual(recording.events(named: .healthConnectionCompleted).count, 1)
        XCTAssertTrue(recording.events(named: .healthConnectionDeclined).isEmpty)
        XCTAssertTrue(recording.events(named: .healthConnectionFailed).isEmpty)
    }

    func testSkipDeclineIsNotRepresentedAsSuccess() {
        funnel.trackHealthConnectionStarted()
        funnel.trackHealthConnectionDeclined()

        XCTAssertEqual(recording.events(named: .healthConnectionDeclined).count, 1)
        XCTAssertTrue(recording.events(named: .healthConnectionCompleted).isEmpty)
    }

    func testTechnicalFailureUsesOnlySafeBoundedReason() {
        let reasons: [HealthConnectionFailureReason] = [
            .unavailable, .authorizationError, .configurationError, .unknown
        ]
        for reason in reasons {
            funnel.trackHealthConnectionFailed(reason: reason)
        }

        let values = recording.parameterValues(for: .healthConnectionFailed, key: AnalyticsParameterKey.reason)
        XCTAssertEqual(
            Set(values),
            Set(["unavailable", "authorization_error", "configuration_error", "unknown"])
        )
        for parameters in recording.events(named: .healthConnectionFailed).map(\.parameters) {
            XCTAssertEqual(parameters.keys.count, 1)
            XCTAssertEqual(parameters.keys.first, AnalyticsParameterKey.reason)
        }
    }

    func testNotificationStatusMapsCorrectly() {
        let mapping: [(UNAuthorizationStatus, NotificationPermissionAnalyticsStatus)] = [
            (.authorized, .authorized),
            (.denied, .denied),
            (.provisional, .provisional),
            (.ephemeral, .ephemeral),
            (.notDetermined, .unknown)
        ]

        for (system, expected) in mapping {
            XCTAssertEqual(NotificationPermissionAnalyticsStatus(system), expected)
            AppAnalytics.shared.track(
                .notificationPermissionResponded,
                parameters: [AnalyticsParameterKey.status: NotificationPermissionAnalyticsStatus(system).rawValue]
            )
        }

        let statuses = recording.parameterValues(
            for: .notificationPermissionResponded,
            key: AnalyticsParameterKey.status
        )
        XCTAssertEqual(
            Set(statuses),
            Set(["authorized", "denied", "provisional", "ephemeral", "unknown"])
        )
    }

    func testNoHealthValuesPresentInEventParameters() {
        funnel.trackStartedIfNeeded()
        funnel.trackStepViewedIfNeeded(.health)
        funnel.trackHealthConnectionStarted()
        funnel.trackHealthConnectionCompleted()
        funnel.trackHealthConnectionDeclined()
        funnel.trackHealthConnectionFailed(reason: .authorizationError)
        funnel.trackCompletedIfNeeded()
        AppAnalytics.shared.track(
            .notificationPermissionResponded,
            parameters: [AnalyticsParameterKey.status: NotificationPermissionAnalyticsStatus.authorized.rawValue]
        )

        let bannedSubstrings = [
            "hrv", "heart", "sleep", "calorie", "recovery", "bpm",
            "hkquantity", "hkcategory", "nserror", "localizeddescription",
            "mailto"
        ]

        for recorded in recording.recordedEvents {
            for (key, value) in recorded.parameters {
                XCTAssertFalse(value.contains("@"), "Email-like value in \(recorded.event.rawValue)")
                let haystack = "\(key)=\(value)".lowercased()
                for banned in bannedSubstrings {
                    XCTAssertFalse(
                        haystack.contains(banned),
                        "Unexpected sensitive token '\(banned)' in \(recorded.event.rawValue) params \(recorded.parameters)"
                    )
                }
            }
        }
    }

    func testFirstRunStepAnalyticsNamesAlignWithTypedEnum() {
        let names = FirstRunOnboardingView.Step.allCases.map(\.analyticsName)
        XCTAssertEqual(Set(names), Set(OnboardingAnalyticsStep.allCases.map(\.rawValue)))
    }
}
