import XCTest
@testable import WeekFit

final class DynamicMacroAdjusterXCTests: XCTestCase {

    private let adjuster = DynamicMacroAdjuster()
    private let bmrCalculator = MetabolicRateCalculator()

    func testFatLossIsMeaningfullyBelowMaintenanceForTypicalProfile() {
        let bmr = bmrCalculator.calculateBMR(
            weight: 84,
            height: 174,
            age: 40,
            sex: .male
        )
        let activeCalories = 57.0

        let maintenance = adjuster.adjustGoals(
            bmr: bmr,
            activeCalories: activeCalories,
            weight: 84,
            goal: .maintenance
        )
        let fatLoss = adjuster.adjustGoals(
            bmr: bmr,
            activeCalories: activeCalories,
            weight: 84,
            goal: .fatLoss
        )

        let gap = maintenance.calories - fatLoss.calories

        XCTAssertGreaterThan(gap, 150)
        XCTAssertLessThan(fatLoss.calories, maintenance.calories)
        XCTAssertLessThan(fatLoss.calories, bmr)
    }

    func testFatLossDoesNotCollapseToFullBMRFloor() {
        let bmr = bmrCalculator.calculateBMR(
            weight: 84,
            height: 174,
            age: 40,
            sex: .male
        )

        let fatLoss = adjuster.adjustGoals(
            bmr: bmr,
            activeCalories: 57,
            weight: 84,
            goal: .fatLoss
        )

        XCTAssertLessThan(fatLoss.calories, bmr)
        XCTAssertGreaterThanOrEqual(fatLoss.calories, bmr * 0.90 - 1)
    }
}
