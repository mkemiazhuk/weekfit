import XCTest
@testable import WeekFit

final class PostWorkoutProteinRecoveryBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenHigherPostWorkoutProteinImprovesNextDayRecovery() {
        let observations = PostWorkoutProteinRecoveryFixtures.observationsWithRecoveryDelta()

        let evaluation = PostWorkoutProteinRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDelta ?? 0, 8)

        let result = PostWorkoutProteinRecoveryBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .postWorkoutProteinRecovery)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenPatternRemainsStable() {
        let emerging = PostWorkoutProteinRecoveryBeliefEvaluator.evaluate(
            observations: PostWorkoutProteinRecoveryFixtures.observationsWithRecoveryDelta(),
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let established = PostWorkoutProteinRecoveryBeliefEvaluator.evaluate(
            observations: PostWorkoutProteinRecoveryFixtures.observationsWithStableDelta(),
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testMissingTimingDataRemainsWatching() {
        let result = PostWorkoutProteinRecoveryBeliefEvaluator.evaluate(
            observations: PostWorkoutProteinRecoveryFixtures.observationsWithoutTimingData(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testInsufficientAnchorsRemainWatching() {
        let result = PostWorkoutProteinRecoveryBeliefEvaluator.evaluate(
            observations: PostWorkoutProteinRecoveryFixtures.observationsWithRecoveryDelta(trainingDayCount: 3),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum PostWorkoutProteinRecoveryFixtures {

    static func observationsWithRecoveryDelta(trainingDayCount: Int = 8) -> [CoachDailyObservation] {
        let cycles: [(windowProtein: Int, nextRecovery: Int)] = [
            (40, 86),
            (15, 70),
            (45, 87),
            (10, 68),
        ]
        let training = Array(repeating: cycles, count: (trainingDayCount + 3) / 4)
            .flatMap { $0 }
            .prefix(trainingDayCount)
            .map { ($0.0, $0.1) }
        return buildPairedSequence(trainingConfigs: Array(training))
    }

    static func observationsWithStableDelta() -> [CoachDailyObservation] {
        let cycles: [(Int, Int)] = [
            (42, 86),
            (12, 70),
            (48, 88),
            (8, 68),
        ]
        let training = Array(repeating: cycles, count: 5).flatMap { $0 }
        return buildPairedSequence(trainingConfigs: training)
    }

    static func observationsWithoutTimingData() -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []

        for index in 0..<14 {
            let offset = 14 - index
            guard let date = calendar.date(byAdding: .day, value: -offset, to: anchor) else { continue }
            let isHard = index % 2 == 0
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 450,
                    recoveryPercent: 80,
                    bedStartNormalizedMinutes: 1_380,
                    exerciseMinutes: isHard ? 80 : 25,
                    activeCalories: isHard ? 700 : 200,
                    workoutCount: 1,
                    workoutTypes: ["strength"],
                    hardWorkoutCount: isHard ? 1 : 0,
                    workoutIntensityBand: isHard ? .hard : .rest,
                    hadHardTraining: isHard,
                    hadRecoveryActivity: !isHard,
                    hadRestDay: !isHard,
                    trainingLoadScore: isHard ? 85 : 20,
                    hardestWorkoutEndMinutes: nil,
                    proteinGrams: 130,
                    carbsGrams: 200,
                    fatGrams: 60,
                    caloriesEaten: 2_200,
                    calorieDeficit: 100,
                    hydrationLiters: 2.2,
                    mealsLoggedCount: 3,
                    hasPopulatedNutritionFields: true,
                    nutritionCompleteness: .complete,
                    nutritionSource: .plannedMeals,
                    proteinWithinPostWorkoutWindowGrams: nil
                )
            )
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    private static func buildPairedSequence(
        trainingConfigs: [(windowProtein: Int, nextRecovery: Int)]
    ) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []
        var dayOffset = trainingConfigs.count * 2 + 1

        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
            observations.append(day(
                date: date,
                band: .rest,
                recovery: 80,
                windowProtein: nil,
                workoutEnd: nil
            ))
        }
        dayOffset -= 1

        for config in trainingConfigs {
            if let trainDate = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
                observations.append(day(
                    date: trainDate,
                    band: .hard,
                    recovery: 74,
                    windowProtein: config.windowProtein,
                    workoutEnd: 18 * 60
                ))
            }
            dayOffset -= 1

            if let restDate = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
                observations.append(day(
                    date: restDate,
                    band: .rest,
                    recovery: config.nextRecovery,
                    windowProtein: nil,
                    workoutEnd: nil
                ))
            }
            dayOffset -= 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    private static func day(
        date: Date,
        band: CoachWorkoutIntensityBand,
        recovery: Int,
        windowProtein: Int?,
        workoutEnd: Int?
    ) -> CoachDailyObservation {
        let isTraining = band == .hard || band == .moderate
        return CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 450,
            recoveryPercent: recovery,
            bedStartNormalizedMinutes: 1_380,
            exerciseMinutes: isTraining ? 80 : 20,
            activeCalories: isTraining ? 700 : 180,
            workoutCount: 1,
            workoutTypes: isTraining ? ["strength"] : ["walking"],
            hardWorkoutCount: band == .hard ? 1 : 0,
            workoutIntensityBand: band,
            hadHardTraining: band == .hard,
            hadRecoveryActivity: !isTraining,
            hadRestDay: band == .rest,
            trainingLoadScore: isTraining ? 85 : 25,
            hardestWorkoutEndMinutes: workoutEnd,
            proteinGrams: 130,
            carbsGrams: 200,
            fatGrams: 60,
            caloriesEaten: 2_200,
            calorieDeficit: 100,
            hydrationLiters: 2.2,
            mealsLoggedCount: 3,
            hasPopulatedNutritionFields: true,
            nutritionCompleteness: .complete,
            nutritionSource: .plannedMeals,
            proteinWithinPostWorkoutWindowGrams: windowProtein
        )
    }
}
