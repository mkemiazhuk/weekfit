import XCTest
@testable import WeekFit

final class OnboardingStoreTests: XCTestCase {

    private let defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        clearOnboardingKeys()
    }

    override func tearDown() {
        clearOnboardingKeys()
        super.tearDown()
    }

    func testMigrateSkipsExistingUsersWithManualGoal() {
        defaults.set(true, forKey: ProfileService.Keys.nutritionGoalIsManual)
        OnboardingStore.migrateExistingUsersIfNeeded()
        XCTAssertTrue(OnboardingStore.hasCompletedOnboarding)
        XCTAssertFalse(OnboardingStore.shouldShowIntro(for: OnboardingStore.Keys.introToday))
    }

    func testFreshInstallStillNeedsOnboarding() {
        defaults.set(false, forKey: ProfileService.Keys.nutritionGoalIsManual)
        defaults.set(false, forKey: "weekfit.healthAccessRequested")
        OnboardingStore.hasCompletedOnboarding = false
        defaults.set(false, forKey: OnboardingStore.Keys.introToday)

        OnboardingStore.migrateExistingUsersIfNeeded()
        XCTAssertFalse(OnboardingStore.hasCompletedOnboarding)
        XCTAssertTrue(OnboardingStore.shouldShowIntro(for: OnboardingStore.Keys.introToday))
    }

    func testMarkCompletedPersists() {
        OnboardingStore.markCompleted()
        XCTAssertTrue(OnboardingStore.hasCompletedOnboarding)
        XCTAssertFalse(OnboardingStore.shouldShowIntro(for: OnboardingStore.Keys.introToday))
        XCTAssertNil(OnboardingStore.persistedStepRawValue)
    }

    func testPersistedStepSurvivesRelaunchSignal() {
        OnboardingStore.persistedStepRawValue = 3
        XCTAssertEqual(OnboardingStore.persistedStepRawValue, 3)
        OnboardingStore.markCompleted()
        XCTAssertNil(OnboardingStore.persistedStepRawValue)
    }

    func testFlowVersionBumpClearsStaleStep() {
        defaults.set(10, forKey: OnboardingStore.Keys.flowVersion)
        defaults.set(7, forKey: OnboardingStore.Keys.step)
        XCTAssertNil(OnboardingStore.persistedStepRawValue)
        XCTAssertEqual(defaults.integer(forKey: OnboardingStore.Keys.flowVersion), OnboardingStore.currentFlowVersion)
    }

    func testCurrentFlowVersionIsFourteen() {
        XCTAssertEqual(OnboardingStore.currentFlowVersion, 14)
    }

    private func clearOnboardingKeys() {
        // Remove the whole persistent domain for this test runner to avoid cross-test leakage.
        // (Some CI/simulator environments can keep stale values even after removeObject.)
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }

        OnboardingStore.allKnownKeys.forEach(defaults.removeObject(forKey:))
        defaults.removeObject(forKey: ProfileService.Keys.nutritionGoalIsManual)
        defaults.removeObject(forKey: "weekfit.healthAccessRequested")

        // Explicitly force the migration triggers off (more deterministic than relying on defaults).
        defaults.set(false, forKey: ProfileService.Keys.nutritionGoalIsManual)
        defaults.set(false, forKey: "weekfit.healthAccessRequested")
        defaults.set(false, forKey: OnboardingStore.Keys.completed)
        defaults.synchronize()
    }
}
