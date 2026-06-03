import XCTest
@testable import WeekFit

final class CoachDecisionEngineXCTests: XCTestCase {

    // MARK: - Primary strategy

    func testOverload_whenCaloriesExceedNormalStrainLimit() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.20, strain: .normal)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .overload)
    }

    func testOverload_whenCarbsSeverelyOverflown() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 0.9, carbsProgress: 1.35, strain: .normal)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .overload)
    }

    func testNotOverload_whenHighStrainAndModerateEnergyCoverage() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.35, strain: .high)
        XCTAssertNotEqual(brain.testDecision.primaryStrategy, .overload)
    }

    func testOverload_whenHighStrainAndEnergyAboveHighStrainLimit() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.45, strain: .high)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .overload)
    }

    func testMorningBaseline_whenNoFoodBeforeNoon() {
        let brain = HumanBrainStateBuilder.make(currentHour: 9, hasAnyFoodLogged: false, hasWorkoutSoon: false)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .maintain)
    }

    func testPrepareWorkout_whenNoFoodAndWorkoutSoon() {
        let brain = HumanBrainStateBuilder.make(currentHour: 9, hasAnyFoodLogged: false, hasWorkoutSoon: true)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .prepareWorkout)
    }

    func testRehydrate_whenNoFoodAndDepletedHydrationAfternoon() {
        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            hasAnyFoodLogged: false,
            waterProgress: 0.2,
            hydration: .depleted
        )
        XCTAssertEqual(brain.testDecision.primaryStrategy, .rehydrate)
    }

    func testAddProtein_whenNoFoodAfternoonAndLowProtein() {
        let brain = HumanBrainStateBuilder.make(currentHour: 14, hasAnyFoodLogged: false, protein: .low)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .addProtein)
    }

    func testOverload_whenExtremeEnergyCoverageBeforeSupercompensation() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 2.55, fuel: .light, strain: .high)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .overload)
    }

    func testSupercompensation_whenStrainVeryHigh() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.0, fuel: .underfueled, strain: .veryHigh)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .supercompensation)
    }

    func testProtectRecovery_whenRecoveryCompromised() {
        let brain = HumanBrainStateBuilder.make(strain: .normal, recovery: .compromised, readiness: .good)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .protectRecovery)
    }

    func testProtectRecovery_whenReadinessCompromised() {
        let brain = HumanBrainStateBuilder.make(strain: .normal, recovery: .stable, readiness: .compromised)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .protectRecovery)
    }

    func testRefuel_whenSeverelyUnderfueledOnHighStrain() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 0.40, fuel: .underfueled, strain: .high)
        XCTAssertEqual(brain.testDecision.primaryStrategy, .refuel)
    }

    func testPrepareWorkout_whenUnderfueledBeforeSession() {
        let brain = HumanBrainStateBuilder.make(
            hasWorkoutSoon: true,
            fuel: .underfueled,
            recovery: .stable,
            readiness: .good
        )
        XCTAssertEqual(brain.testDecision.primaryStrategy, .prepareWorkout)
    }

    func testRefuel_eveningHighStrainLightFuel() {
        let brain = HumanBrainStateBuilder.make(
            currentHour: 17,
            energyCoverage: 0.65,
            fuel: .light,
            strain: .high,
            recovery: .stable,
            readiness: .good
        )
        XCTAssertEqual(brain.testDecision.primaryStrategy, .refuel)
    }

    func testAddProtein_eveningLowProtein() {
        let brain = HumanBrainStateBuilder.make(
            currentHour: 18,
            fuel: .good,
            protein: .low,
            recovery: .stable,
            readiness: .good
        )
        XCTAssertEqual(brain.testDecision.primaryStrategy, .addProtein)
    }

    func testRehydrate_whenHydrationBehindAndMacrosOnTrack() {
        let brain = HumanBrainStateBuilder.make(
            currentHour: 11,
            waterProgress: 0.4,
            hydration: .behind,
            fuel: .good,
            protein: .good
        )
        XCTAssertEqual(brain.testDecision.primaryStrategy, .rehydrate)
    }

    func testMaintain_whenBalancedDay() {
        let brain = HumanBrainStateBuilder.make(
            currentHour: 14,
            energyCoverage: 0.85,
            fuel: .good,
            protein: .good,
            strain: .normal
        )
        XCTAssertEqual(brain.testDecision.primaryStrategy, .maintain)
    }

    // MARK: - Hydration flags

    func testHydrationAlreadySolved_whenCompletedOrExcessive() {
        let completed = HumanBrainStateBuilder.make(hydration: .completed)
        let excessive = HumanBrainStateBuilder.make(hydration: .excessive)
        XCTAssertTrue(completed.testDecision.hydrationAlreadySolved)
        XCTAssertTrue(excessive.testDecision.hydrationAlreadySolved)
    }

    func testNeedsElectrolytes_whenWaterVeryHigh() {
        let brain = HumanBrainStateBuilder.make(waterProgress: 1.20, hydration: .completed)
        let decision = brain.testDecision
        XCTAssertTrue(decision.needsElectrolytesInsteadOfWater)
        XCTAssertTrue(decision.suppressHydrationAdvice)
    }

    // MARK: - Suppressions

    func testSuppressesHeavyFoodLateNightUnlessSupercompensation() {
        let lateMaintain = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 0.9,
            fuel: .good,
            strain: .normal,
            isLateNight: true
        )
        let lateSuper = HumanBrainStateBuilder.make(
            currentHour: 23,
            energyCoverage: 1.0,
            fuel: .light,
            strain: .veryHigh,
            isLateNight: true
        )
        XCTAssertTrue(lateMaintain.testDecision.suppressHeavyFoodAdvice)
        XCTAssertFalse(lateSuper.testDecision.suppressHeavyFoodAdvice)
    }

    func testSuppressesWorkoutPush_whenRecoveryCompromisedOrVeryHighStrain() {
        let compromised = HumanBrainStateBuilder.make(
            strain: .normal,
            recovery: .compromised,
            readiness: .compromised
        )
        let veryHigh = HumanBrainStateBuilder.make(
            energyCoverage: 2.6,
            fuel: .light,
            strain: .veryHigh,
            recovery: .stable
        )
        XCTAssertTrue(compromised.testDecision.suppressWorkoutPush)
        XCTAssertTrue(veryHigh.testDecision.suppressWorkoutPush)
    }

    func testSuppressesFastCarbs_whenEnergyOverload() {
        let brain = HumanBrainStateBuilder.make(energyCoverage: 1.25, strain: .normal)
        XCTAssertTrue(brain.testDecision.suppressedActions.contains(.fastCarbs))
    }

    // MARK: - Secondary priorities

    func testOverloadSecondaryPriorities_recoveryAndSleep() {
        let decision = HumanBrainStateBuilder.make(energyCoverage: 1.25, strain: .normal).testDecision
        XCTAssertTrue(decision.secondaryPriorities.contains(.recovery))
        XCTAssertTrue(decision.secondaryPriorities.contains(.sleep))
    }

    func testSupercompensationSecondaryPriorities() {
        let decision = HumanBrainStateBuilder.make(energyCoverage: 1.0, fuel: .light, strain: .veryHigh).testDecision
        XCTAssertTrue(decision.secondaryPriorities.contains(.recovery))
        XCTAssertTrue(decision.secondaryPriorities.contains(.protein))
        XCTAssertTrue(decision.secondaryPriorities.contains(.sleep))
    }

    func testRefuelSecondaryPriorities_includeProteinAndCarbs() {
        let decision = HumanBrainStateBuilder.make(energyCoverage: 0.4, fuel: .underfueled, strain: .high).testDecision
        XCTAssertTrue(decision.secondaryPriorities.contains(.protein))
        XCTAssertTrue(decision.secondaryPriorities.contains(.carbs))
    }
}
