import XCTest
@testable import WeekFit

final class UserNutritionProfileResolveTests: XCTestCase {

    func testSuggestedGoalFromBMI_isHintOnlyNotAutoApplied() {
        let suggested = UserNutritionProfile.suggestedGoal(
            weightKg: 90,
            heightCm: 180
        )
        let resolved = UserNutritionProfile.resolveGoal(
            weightKg: 90,
            heightCm: 180,
            manualGoal: nil,
            isManualGoal: false
        )

        XCTAssertEqual(suggested, .fatLoss)
        XCTAssertEqual(resolved, .maintenance)
    }

    func testManualGoalOverridesBMI() {
        let goal = UserNutritionProfile.resolveGoal(
            weightKg: 90,
            heightCm: 180,
            manualGoal: .muscleGain,
            isManualGoal: true
        )

        XCTAssertEqual(goal, .muscleGain)
    }

    func testMissingHealthData_requiresManualSelection() {
        XCTAssertTrue(
            UserNutritionProfile.needsManualBodyGoalSelection(
                weightKg: 0,
                heightCm: 0,
                manualGoal: nil,
                isManualGoal: false
            )
        )
    }

    func testMissingHealthData_fallsBackToMaintenanceUntilManualPick() {
        let goal = UserNutritionProfile.resolveGoal(
            weightKg: 0,
            heightCm: 0,
            manualGoal: nil,
            isManualGoal: false
        )

        XCTAssertEqual(goal, .maintenance)
    }

    func testManualGoalUsedWhenHealthDataMissing() {
        let goal = UserNutritionProfile.resolveGoal(
            weightKg: 0,
            heightCm: 0,
            manualGoal: .fatLoss,
            isManualGoal: true
        )

        XCTAssertEqual(goal, .fatLoss)
    }

    func testMuscleGainExceedsFatLossWhenRecoveryIsGood() {
        let baseArgs: (Double, Double, Int, BiologicalSex, Int, Double, Double) = (
            80, 180, 35, .male, 75, 7.5, 42
        )

        let lossGoal = ActivityGoalEngine.calculate(
            weightKg: baseArgs.0,
            heightCm: baseArgs.1,
            age: baseArgs.2,
            sex: baseArgs.3,
            recoveryPercent: baseArgs.4,
            sleepHours: baseArgs.5,
            vo2Max: baseArgs.6,
            goal: .fatLoss
        )

        let gainGoal = ActivityGoalEngine.calculate(
            weightKg: baseArgs.0,
            heightCm: baseArgs.1,
            age: baseArgs.2,
            sex: baseArgs.3,
            recoveryPercent: baseArgs.4,
            sleepHours: baseArgs.5,
            vo2Max: baseArgs.6,
            goal: .muscleGain
        )

        XCTAssertLessThan(lossGoal, gainGoal)
    }

    func testFatLossWithGoodRecovery_isAtLeastMaintenanceActivity() {
        let args: (Double, Double, Int, BiologicalSex, Int, Double, Double) = (
            80, 180, 35, .male, 78, 7.5, 42
        )

        let maintenanceGoal = ActivityGoalEngine.calculate(
            weightKg: args.0, heightCm: args.1, age: args.2, sex: args.3,
            recoveryPercent: args.4, sleepHours: args.5, vo2Max: args.6,
            goal: .maintenance
        )

        let fatLossGoal = ActivityGoalEngine.calculate(
            weightKg: args.0, heightCm: args.1, age: args.2, sex: args.3,
            recoveryPercent: args.4, sleepHours: args.5, vo2Max: args.6,
            goal: .fatLoss
        )

        XCTAssertGreaterThanOrEqual(fatLossGoal, maintenanceGoal)
    }

    func testFatLossWithPoorRecovery_matchesMaintenanceActivity() {
        let args: (Double, Double, Int, BiologicalSex, Int, Double, Double) = (
            80, 180, 35, .male, 55, 5.0, 42
        )

        let maintenanceGoal = ActivityGoalEngine.calculate(
            weightKg: args.0, heightCm: args.1, age: args.2, sex: args.3,
            recoveryPercent: args.4, sleepHours: args.5, vo2Max: args.6,
            goal: .maintenance
        )

        let fatLossGoal = ActivityGoalEngine.calculate(
            weightKg: args.0, heightCm: args.1, age: args.2, sex: args.3,
            recoveryPercent: args.4, sleepHours: args.5, vo2Max: args.6,
            goal: .fatLoss
        )

        XCTAssertEqual(fatLossGoal, maintenanceGoal)
    }
}

final class NutritionGoalProfileServiceTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UserNutritionProfileResolveTests")!
        defaults.removePersistentDomain(forName: "UserNutritionProfileResolveTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "UserNutritionProfileResolveTests")
        defaults = nil
        super.tearDown()
    }

    func testBodyGoalNeedsSetupWhenHealthMissingAndNoManualGoal() {
        let service = ProfileService(defaults: defaults)
        XCTAssertTrue(service.bodyGoalNeedsSetup(weightKg: 0, heightCm: 0))
    }

    func testBodyGoalDoesNotNeedSetupWhenHealthPresent() {
        let service = ProfileService(defaults: defaults)
        XCTAssertFalse(service.bodyGoalNeedsSetup(weightKg: 75, heightCm: 180))
    }

    func testSavingManualGoalClearsSetupRequirementEvenWithoutHealth() {
        let service = ProfileService(defaults: defaults)
        service.saveManualNutritionGoal(.fatLoss)

        XCTAssertFalse(service.bodyGoalNeedsSetup(weightKg: 0, heightCm: 0))
        XCTAssertEqual(service.resolvedNutritionGoal(weightKg: 0, heightCm: 0), .fatLoss)
    }
}
