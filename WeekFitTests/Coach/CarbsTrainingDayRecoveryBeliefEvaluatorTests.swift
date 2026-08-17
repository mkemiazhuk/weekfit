import XCTest
@testable import WeekFit

final class CarbsTrainingDayRecoveryBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenHigherCarbsTrainingDaysImproveNextDayRecovery() {
        let observations = CarbsTrainingDayRecoveryFixtures.observationsWithRecoveryDelta()

        let evaluation = CarbsTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDelta ?? 0, 8)

        let result = CarbsTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .carbsTrainingDayRecovery)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testTinyCarbsSpreadRemainsWatching() {
        let result = CarbsTrainingDayRecoveryBeliefEvaluator.evaluate(
            observations: CarbsTrainingDayRecoveryFixtures.observationsWithTinyCarbsSpread(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum CarbsTrainingDayRecoveryFixtures {

    static func observationsWithRecoveryDelta(trainingDayCount: Int = 9) -> [CoachDailyObservation] {
        let cycles: [(CoachWorkoutIntensityBand, Int, Int)] = [
            (.hard, 320, 86),
            (.moderate, 220, 78),
            (.hard, 120, 68),
        ]
        let training = Array(repeating: cycles, count: (trainingDayCount + 2) / 3)
            .flatMap { $0 }
            .prefix(trainingDayCount)
            .map { ($0.0, $0.1, $0.2) }
        return buildPairedSequence(trainingConfigs: Array(training))
    }

    static func observationsWithTinyCarbsSpread() -> [CoachDailyObservation] {
        let cycles: [(CoachWorkoutIntensityBand, Int, Int)] = [
            (.hard, 210, 84),
            (.moderate, 200, 82),
            (.hard, 190, 80),
        ]
        let training = Array(repeating: cycles, count: 4).flatMap { $0 }
        return buildPairedSequence(trainingConfigs: training)
    }

    private static func buildPairedSequence(
        trainingConfigs: [(CoachWorkoutIntensityBand, Int, Int)]
    ) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []
        var dayOffset = trainingConfigs.count * 2 + 1

        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
            observations.append(day(date: date, band: .rest, carbs: 200, recovery: 80))
        }
        dayOffset -= 1

        for config in trainingConfigs {
            if let trainDate = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
                observations.append(day(date: trainDate, band: config.0, carbs: config.1, recovery: 75))
            }
            dayOffset -= 1
            if let restDate = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) {
                observations.append(day(date: restDate, band: .rest, carbs: 200, recovery: config.2))
            }
            dayOffset -= 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    private static func day(
        date: Date,
        band: CoachWorkoutIntensityBand,
        carbs: Int,
        recovery: Int
    ) -> CoachDailyObservation {
        let isTraining = band == .hard || band == .moderate
        return CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 450,
            recoveryPercent: recovery,
            bedStartNormalizedMinutes: 1_380,
            exerciseMinutes: isTraining ? 70 : 20,
            activeCalories: isTraining ? 600 : 180,
            workoutCount: 1,
            workoutTypes: isTraining ? ["strength"] : ["walking"],
            hardWorkoutCount: band == .hard ? 1 : 0,
            workoutIntensityBand: band,
            hadHardTraining: band == .hard,
            hadRecoveryActivity: !isTraining,
            hadRestDay: band == .rest,
            trainingLoadScore: isTraining ? 80 : 25,
            proteinGrams: 120,
            carbsGrams: carbs,
            fatGrams: 60,
            caloriesEaten: 2_200,
            calorieDeficit: 100,
            hydrationLiters: 2.2,
            mealsLoggedCount: 3,
            hasPopulatedNutritionFields: true,
            nutritionCompleteness: .complete,
            nutritionSource: .plannedMeals
        )
    }
}
