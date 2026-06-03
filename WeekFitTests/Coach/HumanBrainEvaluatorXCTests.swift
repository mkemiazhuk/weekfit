import XCTest
@testable import WeekFit

final class HumanBrainEvaluatorXCTests: XCTestCase {

    func testFuel_overfueled_onlyFromAbsoluteCalorieOrCarbProgress() {
        let current = HumanBrain.CurrentContext(
            isMorning: false,
            isAfternoon: true,
            isEvening: false,
            isLateNight: false,
            hasFoodLogged: true,
            activeCalories: 500,
            caloriesProgress: 1.20,
            proteinProgress: 0.8,
            carbsProgress: 0.9,
            fatsProgress: 0.7,
            waterProgress: 0.8,
            expectedWaterProgress: 0.6,
            waterDeltaFromExpected: 0.2,
            expectedNutritionProgress: 0.7,
            expectedCaloriesByNow: 1500,
            energyCoverage: 0.95,
            energyDeficit: 0
        )
        let future = emptyFuture()
        let fuel = HumanBrain.evaluateFuel(
            current: current,
            future: future,
            strain: .high,
            sleep: .okay,
            currentHour: 14
        )
        XCTAssertEqual(fuel, .overfueled)
    }

    func testFuel_notOverfueled_fromHighEnergyCoverageAlone() {
        let current = HumanBrain.CurrentContext(
            isMorning: false,
            isAfternoon: false,
            isEvening: true,
            isLateNight: false,
            hasFoodLogged: true,
            activeCalories: 800,
            caloriesProgress: 0.9,
            proteinProgress: 0.8,
            carbsProgress: 0.85,
            fatsProgress: 0.7,
            waterProgress: 0.8,
            expectedWaterProgress: 0.85,
            waterDeltaFromExpected: -0.05,
            expectedNutritionProgress: 0.9,
            expectedCaloriesByNow: 2000,
            energyCoverage: 1.25,
            energyDeficit: 0
        )
        let fuel = HumanBrain.evaluateFuel(
            current: current,
            future: emptyFuture(),
            strain: .veryHigh,
            sleep: .okay,
            currentHour: 20
        )
        XCTAssertNotEqual(fuel, .overfueled)
    }

    func testExpectedNutritionProgress_increasesThroughDay() {
        let morning = HumanBrain.expectedNutritionProgress(for: 8)
        let afternoon = HumanBrain.expectedNutritionProgress(for: 14)
        let evening = HumanBrain.expectedNutritionProgress(for: 19)
        let late = HumanBrain.expectedNutritionProgress(for: 22)
        XCTAssertLessThan(morning, afternoon)
        XCTAssertLessThan(afternoon, evening)
        XCTAssertLessThanOrEqual(evening, late)
    }

    func testExpectedHydrationProgress_increasesThroughDay() {
        XCTAssertLessThan(
            HumanBrain.expectedHydrationProgress(for: 7),
            HumanBrain.expectedHydrationProgress(for: 16)
        )
    }

    func testBuild_marksVeryHighStrain_fromActiveCalories() {
        let brain = HumanBrainIntegrationBuilder.build(metrics: CoachMetricsBuilder.highActivityDay())
        XCTAssertEqual(brain.strain, .veryHigh)
    }

    func testEnergyThresholds_higherWhenStrainAndWorkoutSoon() {
        let relaxed = HumanBrain.energyThresholds(
            strain: .low,
            sleep: .strong,
            hasWorkoutSoon: false,
            hour: 10
        )
        let loaded = HumanBrain.energyThresholds(
            strain: .veryHigh,
            sleep: .veryShort,
            hasWorkoutSoon: true,
            hour: 16
        )
        XCTAssertGreaterThan(loaded.optimal, relaxed.optimal)
    }

    private func emptyFuture() -> HumanBrain.FutureContext {
        HumanBrain.FutureContext(
            upcomingWorkouts: [],
            nextWorkout: nil,
            hoursToNextWorkout: nil,
            hasUpcomingWorkout: false,
            hasWorkoutSoon: false
        )
    }
}
