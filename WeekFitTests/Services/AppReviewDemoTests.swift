import XCTest
import SwiftData
@testable import WeekFit

@MainActor
final class AppReviewDemoTests: XCTestCase {

    private let enabledKey = AppReviewDemoStore.enabledKey
    private let scenarioKey = AppReviewDemoStore.scenarioKey

    override func setUp() {
        super.setUp()
        AccountSessionController.shared.resetForTests()
        AppReviewDemoSettings.shared.resetForTests()
        AppReviewDemoActivation.shared.resetForTests()
        AppReviewDemoCredentials.clearSession()
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: scenarioKey)
        CoachObservationStore.clearAll()
    }

    override func tearDown() {
        AccountSessionController.shared.resetForTests()
        AppReviewDemoSettings.shared.resetForTests()
        AppReviewDemoActivation.shared.resetForTests()
        AppReviewDemoCredentials.clearSession()
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: scenarioKey)
        CoachObservationStore.clearAll()
        super.tearDown()
    }

    func testDatasetUsesRelativeDatesAcrossThirtyDays() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let dataset = AppReviewDemoDatasetGenerator.generate(
            scenario: .readyToTrain,
            referenceDate: reference
        )

        XCTAssertEqual(dataset.dayBundles.count, 30)
        XCTAssertNotNil(dataset.bundle(for: reference))
        XCTAssertNotNil(
            dataset.bundle(
                for: Calendar.current.date(byAdding: .day, value: -29, to: reference)!
            )
        )
        XCTAssertNil(
            dataset.bundle(
                for: Calendar.current.date(byAdding: .day, value: -31, to: reference)!
            )
        )
    }

    func testDefaultScenarioTargetsGoodButNotPerfectRecovery() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let dataset = AppReviewDemoDatasetGenerator.generate(
            scenario: .readyToTrain,
            referenceDate: reference
        )
        let provider = AppReviewDemoHealthDataProvider(scenario: .readyToTrain, referenceDate: reference)
        let context = provider.recoveryScoreContext(for: reference)
        let sleep = provider.sleepSnapshot(for: reference)
        let vitals = provider.overnightVitals(for: reference)

        let input = RecoveryScoreInput(
            sleepMinutes: sleep.sleepMinutes,
            timeInBedMinutes: sleep.timeInBedMinutes,
            awakeMinutes: sleep.awakeMinutes,
            awakeningsCount: sleep.awakeningsCount,
            deepSleepMinutes: sleep.deepSleepMinutes,
            remSleepMinutes: sleep.remSleepMinutes,
            hrvSDNN: vitals.hrv,
            restingHeartRate: vitals.restingHeartRate,
            bedtimeDeviationMinutes: context.bedtimeDeviationMinutes,
            baseline: context.baseline,
            priorDayLoad: context.priorDayLoad
        )

        let breakdown = RecoveryScoreEngine.calculate(input)
        let todayMetrics = dataset.activityMetrics(for: reference)

        XCTAssertGreaterThanOrEqual(breakdown.total, 82)
        XCTAssertGreaterThanOrEqual(sleep.sleepMinutes, 450)
        XCTAssertGreaterThanOrEqual(todayMetrics.hrvSDNN, 52)
        XCTAssertGreaterThanOrEqual(context.baseline.hrvSampleCount, 21)
        XCTAssertEqual(dataset.scenario, .readyToTrain)
    }

    func testScenarioSwitchingChangesRecoveryProfile() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!

        func recoveryScore(for scenario: AppReviewDemoScenario) -> Int {
            let provider = AppReviewDemoHealthDataProvider(scenario: scenario, referenceDate: reference)
            let sleep = provider.sleepSnapshot(for: reference)
            let vitals = provider.overnightVitals(for: reference)
            let context = provider.recoveryScoreContext(for: reference)
            let input = RecoveryScoreInput(
                sleepMinutes: sleep.sleepMinutes,
                timeInBedMinutes: sleep.timeInBedMinutes,
                awakeMinutes: sleep.awakeMinutes,
                awakeningsCount: sleep.awakeningsCount,
                deepSleepMinutes: sleep.deepSleepMinutes,
                remSleepMinutes: sleep.remSleepMinutes,
                hrvSDNN: vitals.hrv,
                restingHeartRate: vitals.restingHeartRate,
                bedtimeDeviationMinutes: context.bedtimeDeviationMinutes,
                baseline: context.baseline,
                priorDayLoad: context.priorDayLoad
            )
            return RecoveryScoreEngine.calculate(input).total
        }

        let ready = recoveryScore(for: .readyToTrain)
        let moderate = recoveryScore(for: .keepItModerate)
        let recovery = recoveryScore(for: .recoveryFirst)

        XCTAssertGreaterThan(ready, moderate)
        XCTAssertGreaterThan(moderate, recovery)
    }

    func testDemoSettingsPersistence() {
        AppReviewDemoCredentials.markSessionActive()
        let settings = AppReviewDemoSettings(defaults: UserDefaults.standard)
        settings.setEnabled(true, scenario: .keepItModerate)

        let restored = AppReviewDemoSettings(defaults: UserDefaults.standard)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertEqual(restored.scenario, .keepItModerate)
    }

    func testDemoSettingsClearWithoutReviewSessionOnRestore() {
        let settings = AppReviewDemoSettings(defaults: UserDefaults.standard)
        settings.setEnabled(true, scenario: .keepItModerate)

        AppReviewDemoCredentials.clearSession()
        let restored = AppReviewDemoSettings(defaults: UserDefaults.standard)
        XCTAssertFalse(restored.isEnabled)
    }

    func testAppReviewCredentialsMatchOnlyReviewerAccount() {
        XCTAssertTrue(
            AppReviewDemoCredentials.matches(
                email: AppReviewDemoCredentials.email,
                password: AppReviewDemoCredentials.password
            )
        )
        XCTAssertFalse(
            AppReviewDemoCredentials.matches(
                email: "user@example.com",
                password: AppReviewDemoCredentials.password
            )
        )
    }

    func testCredentialLoginMarksReviewSession() async {
        let authViewModel = AuthViewModel()
        AppReviewDemoActivation.shared.resetForTests()

        await authViewModel.signInWithEmail(
            email: AppReviewDemoCredentials.email,
            password: AppReviewDemoCredentials.password
        )

        XCTAssertTrue(authViewModel.isLoggedIn)
        XCTAssertTrue(AppReviewDemoCredentials.hasActiveSession)
    }

    func testHealthManagerUsesDemoProviderWhenEnabled() async {
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        AppReviewDemoCredentials.markSessionActive()
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain)
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        let metrics = await healthManager.readActivityMetrics(for: Date())
        XCTAssertGreaterThan(metrics.sleepMinutes, 0)
        XCTAssertGreaterThan(metrics.hrvSDNN, 0)
        let accessGranted = await healthManager.checkReadAuthorizationStatus()
        XCTAssertTrue(accessGranted)
        XCTAssertEqual(healthManager.healthDataConnectionState, .connected)
    }

    func testHealthManagerDemoInactiveWithoutReviewSession() async {
        let healthManager = HealthManager()
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain)
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        XCTAssertFalse(healthManager.isAppReviewDemoActive)
    }

    func testTeardownUnlessReviewSessionClearsOrphanedDemo() async {
        let healthManager = HealthManager()
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain)
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        await AppReviewDemoCoordinator.teardownUnlessReviewSession(healthManager: healthManager)

        XCTAssertFalse(AppReviewDemoSettings.shared.isEnabled)
        XCTAssertNil(healthManager.appReviewDemoProvider)
    }

    func testHealthManagerBlocksAuthorizationWhileDemoActive() async {
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        AppReviewDemoCredentials.markSessionActive()
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain)
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        await healthManager.requestAuthorization()
        XCTAssertTrue(healthManager.isAppReviewDemoActive)
    }

    func testDemoPlannedActivitiesAreIsolatedAndRemovable() throws {
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        try AppReviewDemoPlannedActivitySeeder.seed(
            scenario: .readyToTrain,
            modelContext: context
        )

        let demoSource = AppReviewDemoStore.sourceIdentifier
        let demoCount = try context.fetchCount(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate { $0.source == demoSource }
            )
        )
        XCTAssertGreaterThan(demoCount, 0)

        try AppReviewDemoPlannedActivitySeeder.deleteDemoActivities(modelContext: context)

        let remainingDemoCount = try context.fetchCount(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate { $0.source == demoSource }
            )
        )
        XCTAssertEqual(remainingDemoCount, 0)
    }

    func testReviewerCreatedActivitiesAreTaggedDuringDemo() {
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        let activity = PlannedActivity(
            date: Date(),
            type: "meal",
            title: "Reviewer Snack",
            durationMinutes: 5,
            icon: "fork.knife",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9,
            source: "planner"
        )

        AppReviewDemoPlannedActivityTagger.tagIfNeeded(activity)
        XCTAssertEqual(activity.source, AppReviewDemoStore.sourceIdentifier)
    }

    func testDemoSeederUsesPredefinedMealCatalogTitles() throws {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        try AppReviewDemoPlannedActivitySeeder.seed(
            scenario: .readyToTrain,
            modelContext: context,
            referenceDate: reference
        )

        let demoSource = AppReviewDemoStore.sourceIdentifier
        let meals = try context.fetch(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate { $0.source == demoSource && $0.type == "meal" }
            )
        )

        XCTAssertFalse(meals.isEmpty)
        XCTAssertTrue(meals.contains { $0.title == "Chicken Rice Bowl" })
        XCTAssertTrue(meals.contains { $0.title == "Fried Eggs with Spinach" })
        XCTAssertFalse(meals.contains { $0.title == "Breakfast" })
        XCTAssertTrue(meals.allSatisfy { !$0.imageName.isEmpty })
    }

    func testDemoActivityLogIncludesOnlyPhysicalActivities() async throws {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        try AppReviewDemoPlannedActivitySeeder.seed(
            scenario: .readyToTrain,
            modelContext: context,
            referenceDate: reference
        )

        let plannedActivities = try context.fetch(FetchDescriptor<PlannedActivity>())
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        AppReviewDemoCredentials.markSessionActive()
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain, referenceDate: reference)
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        let provider = ActivityIntelligenceSnapshotProvider()
        let snapshot = await provider.buildSnapshot(
            for: reference,
            healthManager: healthManager,
            plannedActivities: plannedActivities
        )

        XCTAssertTrue(snapshot.sessions.allSatisfy { session in
            plannedActivities.contains {
                $0.title == session.title && ($0.type == "workout" || $0.type == "recovery")
            }
        })
        XCTAssertFalse(snapshot.sessions.contains { $0.title == "Chicken Rice Bowl" })
        XCTAssertFalse(snapshot.sessions.contains { $0.title == "Coffee" })
        XCTAssertTrue(snapshot.sessions.contains { $0.title == "Morning Walk" })

        if let walk = snapshot.sessions.first(where: { $0.title == "Morning Walk" }) {
            XCTAssertNotNil(walk.workoutID)
            XCTAssertEqual(walk.detail?.source, "Apple Watch")
            XCTAssertGreaterThan(walk.detail?.heartRateSamples.count ?? 0, 10)
            XCTAssertGreaterThan(walk.detail?.routePoints.count ?? 0, 20)
            XCTAssertNotNil(walk.detail?.averageHeartRate)
            XCTAssertNotNil(walk.detail?.distanceKm)
            XCTAssertNotNil(walk.detail?.steps)
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: reference)!
        let yesterdaySnapshot = await provider.buildSnapshot(
            for: yesterday,
            healthManager: healthManager,
            plannedActivities: plannedActivities
        )
        XCTAssertTrue(yesterdaySnapshot.sessions.contains { $0.title == "Upper Body Strength" })
        XCTAssertTrue(
            yesterdaySnapshot.sessions.contains {
                $0.title == "Upper Body Strength" && ($0.detail?.activeCalories ?? 0) > 0
            }
        )
        XCTAssertTrue(
            yesterdaySnapshot.sessions.contains {
                $0.title == "Upper Body Strength" && ($0.detail?.heartRateSamples.count ?? 0) > 10
            }
        )

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: reference)!
        let upcoming = plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: tomorrow) && !$0.isCompleted
        }
        XCTAssertFalse(upcoming.isEmpty)
    }

    func testCoachSnapshotBuildsFromDemoHealthInputs() async {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let healthManager = HealthManager()
        AccountSessionController.shared.setMode(.reviewDemo, reason: "test")
        AppReviewDemoCredentials.markSessionActive()
        healthManager.installAppReviewDemoProvider(scenario: .readyToTrain, referenceDate: reference)
        AppReviewDemoSettings.shared.setEnabled(true, scenario: .readyToTrain)

        await healthManager.loadHealthData(for: reference)

        XCTAssertGreaterThan(healthManager.recoveryPercent, 0)
        XCTAssertGreaterThan(healthManager.sleepMinutes, 0)
        XCTAssertGreaterThan(healthManager.hrvSDNN, 0)

        let nutritionViewModel = NutritionViewModel()
        nutritionViewModel.updateNutrition(
            metrics: DailyNutritionMetrics(
                protein: healthManager.protein,
                carbs: healthManager.carbs,
                fats: healthManager.fats,
                fiber: healthManager.fiber,
                calories: healthManager.calories,
                waterLiters: healthManager.waterLiters,
                activeCalories: healthManager.activeCalories,
                sleepHours: healthManager.sleepHours,
                weightKg: healthManager.weight
            ),
            profile: CoachMetricsBuilder.standardProfile(),
            plannedActivities: [],
            referenceDate: reference,
            debugSource: "test.demoCoach"
        )

        let snapshot = DailyStateSnapshotBuilder.build(
            selectedDate: reference,
            allPlannedActivities: [],
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            now: reference,
            source: "test.demoCoach"
        )

        XCTAssertGreaterThan(snapshot.recoveryContext.recoveryPercent, 0)
        XCTAssertGreaterThan(snapshot.nutritionMetrics.calories, 0)
    }
}
