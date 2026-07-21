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

    func testCurrentFlowVersionIsThirteen() {
        XCTAssertEqual(OnboardingStore.currentFlowVersion, 13)
    }

    private func clearOnboardingKeys() {
        OnboardingStore.allKnownKeys.forEach(defaults.removeObject(forKey:))
        defaults.removeObject(forKey: ProfileService.Keys.nutritionGoalIsManual)
        defaults.removeObject(forKey: "weekfit.healthAccessRequested")
    }
}
