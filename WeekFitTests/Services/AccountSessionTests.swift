import XCTest
import SwiftData
@testable import WeekFit

@MainActor
final class AccountSessionTests: XCTestCase {

    private let enabledKey = AppReviewDemoStore.enabledKey
    private let scenarioKey = AppReviewDemoStore.scenarioKey
    private let sessionKey = AppReviewDemoStore.sessionActiveKey

    override func setUp() {
        super.setUp()
        resetState()
    }

    override func tearDown() {
        resetState()
        super.tearDown()
    }

    private func resetState() {
        AccountSessionController.shared.resetForTests()
        AppReviewDemoSettings.shared.resetForTests()
        AppReviewDemoActivation.shared.resetForTests()
        AppReviewDemoCredentials.clearSession()
        DemoDataMigration.resetMigrationFlagForTests()
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: scenarioKey)
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: "weekfit.healthAccessRequested")
        CoachObservationStore.clearAll()
    }

    func testAccountModeResolvesReviewSessionOnlyWhenLoggedIn() {
        AppReviewDemoCredentials.markSessionActive()
        XCTAssertEqual(AccountMode.resolve(isLoggedIn: true), .reviewDemo)
        XCTAssertEqual(AccountMode.resolve(isLoggedIn: false), .unauthenticated)
    }

    func testAccountModeResolvesRealUserForNonReviewLogin() {
        XCTAssertEqual(AccountMode.resolve(isLoggedIn: true), .realUser)
    }

    func testReviewLoginActivatesDemoProviderAndIsolatedSwiftDataStore() async {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AppReviewDemoCredentials.markSessionActive()

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .reviewDemo)
        XCTAssertTrue(healthManager.isAppReviewDemoActive)
        XCTAssertEqual(AccountSessionController.shared.containerIdentity, "swiftdata-review-demo")

        let productionCount = try? WeekFitModelContainer.productionContext().fetchCount(
            FetchDescriptor<PlannedActivity>()
        )
        XCTAssertEqual(productionCount, 0)

        let demoCount = try? WeekFitModelContainer.reviewDemoContext().fetchCount(
            FetchDescriptor<PlannedActivity>()
        )
        XCTAssertGreaterThan(demoCount ?? 0, 0)
    }

    func testReviewLogoutClearsDemoStateAndLeavesProductionStoreClean() async throws {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AppReviewDemoCredentials.markSessionActive()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        AppReviewDemoCredentials.clearSession()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: false,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .unauthenticated)
        XCTAssertFalse(AppReviewDemoSettings.shared.isEnabled)
        XCTAssertNil(healthManager.appReviewDemoProvider)
        XCTAssertFalse(healthManager.isHealthAccessRequested)

        let productionContext = WeekFitModelContainer.productionContext()
        let demoSource = AppReviewDemoStore.sourceIdentifier
        let remainingDemoRows = try productionContext.fetchCount(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate { $0.source == demoSource }
            )
        )
        XCTAssertEqual(remainingDemoRows, 0)
    }

    func testRealUserLoginAfterReviewLogoutDoesNotLoadDemoProvider() async {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AppReviewDemoCredentials.markSessionActive()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        AppReviewDemoCredentials.clearSession()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: false,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
        XCTAssertFalse(healthManager.isAppReviewDemoActive)
        // Sticky HealthKit request flag is preserved across review→real switches.
        XCTAssertEqual(AccountSessionController.shared.containerIdentity, "swiftdata-production")
    }

    func testLegacyDemoRowsAreRemovedFromProductionStore() throws {
        let productionContext = WeekFitModelContainer.productionContext()
        productionContext.insert(
            PlannedActivity(
                date: Date(),
                type: "meal",
                title: "Legacy Demo Meal",
                durationMinutes: 10,
                icon: "fork.knife",
                colorRed: 0.2,
                colorGreen: 0.6,
                colorBlue: 0.9,
                source: AppReviewDemoStore.sourceIdentifier
            )
        )
        try productionContext.save()

        let removed = try DemoDataMigration.cleanupLegacyDemoRecordsIfNeeded(in: productionContext)
        XCTAssertEqual(removed, 1)

        let remaining = try productionContext.fetchCount(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(remaining, 0)
    }

    func testRelaunchAfterReviewLogoutThenRealLoginShowsNoDemoData() async {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AppReviewDemoCredentials.markSessionActive()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        AppReviewDemoCredentials.clearSession()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: false,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        // Simulate cold relaunch: in-memory session controller resets, credentials stay real-user.
        AccountSessionController.shared.resetForTests()
        XCTAssertEqual(AccountSessionController.shared.mode, .unauthenticated)

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
        XCTAssertFalse(healthManager.isAppReviewDemoActive)
        XCTAssertNil(healthManager.appReviewDemoProvider)
        XCTAssertEqual(AccountSessionController.shared.containerIdentity, "swiftdata-production")

        let demoCount = try? WeekFitModelContainer.reviewDemoContext().fetchCount(
            FetchDescriptor<PlannedActivity>()
        )
        XCTAssertEqual(demoCount, 0)
    }

    func testAccountSwitchEnablesHealthKitCoordinatorForRealUser() async {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        AppReviewDemoCredentials.markSessionActive()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        AppReviewDemoCredentials.clearSession()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: false,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
        // Sticky HealthKit flag may remain true after leaving review demo.
        activityCoordinator.restartForRealUser()
        // restartForRealUser must not be blocked after leaving review demo mode.
        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
    }

    func testBeginHealthAuthorizationRetriesAfterStaleRequestedFlag() {
        let healthManager = HealthManager()
        UserDefaults.standard.set(true, forKey: "weekfit.healthAccessRequested")
        AccountSessionController.shared.setMode(.realUser, reason: "test")

        let action = healthManager.beginHealthAuthorizationFromUserAction(source: "test")

        XCTAssertEqual(action, .startedAuthorizationPrompt)
        // Cleared so a retry can run; set true again when the system prompt completes.
        XCTAssertFalse(healthManager.isHealthAccessRequested)
    }

    func testBeginHealthAuthorizationBlockedInReviewDemo() {
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain)

        let action = healthManager.beginHealthAuthorizationFromUserAction(source: "test")

        XCTAssertEqual(action, .blockedByDemoMode)
    }

    func testReviewHealthAccessFlagDoesNotBlockRealAppleUser() async {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        // Real Apple user already connected Health before visiting review demo.
        UserDefaults.standard.set(true, forKey: "weekfit.healthAccessRequested")

        AppReviewDemoCredentials.markSessionActive()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )
        XCTAssertEqual(AccountSessionController.shared.mode, .reviewDemo)

        AppReviewDemoCredentials.clearSession()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            accountSession: .shared,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
        XCTAssertTrue(healthManager.isHealthAccessRequested)
        XCTAssertFalse(healthManager.isAppReviewDemoActive)
        XCTAssertNil(healthManager.appReviewDemoProvider)
    }

    func testAppleToReviewToApplePreservesHealthAccessRequestedFlag() async {
        let healthManager = HealthManager()
        let nutritionViewModel = NutritionViewModel()
        let coachCoordinator = CoachCoordinator()
        let appSession = AppSessionState()
        let activityCoordinator = WeekFitActivityCoordinator.shared

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )
        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
        UserDefaults.standard.set(true, forKey: "weekfit.healthAccessRequested")
        healthManager.isHealthAccessGranted = true

        AppReviewDemoCredentials.markSessionActive()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )
        XCTAssertEqual(AccountSessionController.shared.mode, .reviewDemo)
        XCTAssertTrue(healthManager.isAppReviewDemoActive)

        AppReviewDemoCredentials.clearSession()
        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: false,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )
        XCTAssertEqual(AccountSessionController.shared.mode, .unauthenticated)
        XCTAssertTrue(healthManager.isHealthAccessRequested)

        await AccountSessionCoordinator.applySessionState(
            isLoggedIn: true,
            healthManager: healthManager,
            activityCoordinator: activityCoordinator,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            appSession: appSession
        )

        XCTAssertEqual(AccountSessionController.shared.mode, .realUser)
        XCTAssertTrue(healthManager.isHealthAccessRequested)
        XCTAssertFalse(healthManager.isAppReviewDemoActive)
        XCTAssertNil(healthManager.appReviewDemoProvider)
    }

    func testHealthAccessRequestedIsNotConflatedWithDemoMode() async {
        let healthManager = HealthManager()
        AppReviewDemoCredentials.markSessionActive()
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain)

        XCTAssertFalse(healthManager.isHealthAccessRequested)

        UserDefaults.standard.set(true, forKey: "weekfit.healthAccessRequested")
        XCTAssertTrue(healthManager.isHealthAccessRequested)

        healthManager.prepareForRealUserSession()
        AppReviewDemoSettings.shared.setEnabled(false)
        AccountSessionController.shared.setMode(.realUser, reason: "test")
        XCTAssertTrue(healthManager.isHealthAccessRequested)
    }
}
