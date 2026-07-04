import XCTest
@testable import WeekFit

final class UnderfuelingRecoveryBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenUnderfueledDaysAreFollowedByLowerRecovery() {
        let observations = UnderfuelingRecoveryFixtures.observationsWithRecoveryDrop()

        let evaluation = UnderfuelingRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDrop ?? 0, 8)

        let result = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .underfuelingRecovery)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenPatternRemainsStable() {
        let emerging = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: UnderfuelingRecoveryFixtures.observationsWithRecoveryDrop(),
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let established = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: UnderfuelingRecoveryFixtures.observationsWithStableRecoveryDrop(),
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientDataRemainWatching() {
        let result = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: UnderfuelingRecoveryFixtures.observationsWithRecoveryDrop(dayCount: 10),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testTooFewUnderfueledDaysRemainWatching() {
        let result = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: UnderfuelingRecoveryFixtures.observationsWithoutUnderfueledDays(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testMissingNutritionFieldsAreExcluded() {
        let observations = UnderfuelingRecoveryFixtures.observationsWithRecoveryDrop()
            + [
                CoachDailyObservation(
                    dayKey: "2099-01-01",
                    sleepMinutes: 450,
                    recoveryPercent: 40,
                    calorieDeficit: 500
                )
            ]

        let evaluation = UnderfuelingRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.eligibleDayCount, 14)
    }

    func testMissingCalorieDeficitIsExcluded() {
        let observations = UnderfuelingRecoveryFixtures.observationsWithRecoveryDrop()
            + [
                CoachDailyObservation(
                    dayKey: "2099-01-02",
                    sleepMinutes: 450,
                    recoveryPercent: 80,
                    proteinGrams: 120,
                    caloriesEaten: 1_800,
                    hasPopulatedNutritionFields: true
                )
            ]

        let evaluation = UnderfuelingRecoveryBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.eligibleDayCount, 14)
    }

    func testUniformlyLowRecoveryProducesNoEvent() {
        let result = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: UnderfuelingRecoveryFixtures.observationsWithUniformLowRecovery(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testWeakRecoveryDifferenceProducesNoEvent() {
        let result = UnderfuelingRecoveryBeliefEvaluator.evaluate(
            observations: UnderfuelingRecoveryFixtures.observationsWithWeakDrop(),
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }
}

enum UnderfuelingRecoveryFixtures {

    static func observationsWithRecoveryDrop(dayCount: Int = 14) -> [CoachDailyObservation] {
        let configs: [(Int, Int)] = [
            (100, 82), (100, 84), (520, 84), (100, 71), (100, 72),
            (100, 84), (100, 85), (550, 84), (100, 70), (100, 71),
            (100, 84), (100, 85), (520, 84), (100, 69),
        ]
        return buildObservations(configs: Array(configs.prefix(dayCount)))
    }

    static func observationsWithStableRecoveryDrop() -> [CoachDailyObservation] {
        var configs: [(Int, Int)] = [
            (100, 84), (100, 85), (100, 84), (100, 85),
        ]

        let underfuelCycles: [(Int, Int)] = [
            (520, 84), (100, 71), (100, 72),
        ]

        for _ in 0..<5 {
            configs.append(contentsOf: underfuelCycles)
            configs.append((100, 85))
        }

        return buildObservations(configs: configs)
    }

    static func observationsWithoutUnderfueledDays() -> [CoachDailyObservation] {
        let configs = Array(repeating: (100, 84), count: 14)
        return buildObservations(configs: configs)
    }

    static func observationsWithUniformLowRecovery() -> [CoachDailyObservation] {
        let configs: [(Int, Int)] = [
            (100, 52), (100, 53), (520, 52), (100, 50), (100, 51),
            (100, 52), (100, 53), (550, 52), (100, 49), (100, 50),
            (100, 52), (100, 53), (520, 52), (100, 49),
        ]
        return buildObservations(configs: configs)
    }

    static func observationsWithWeakDrop() -> [CoachDailyObservation] {
        let configs: [(Int, Int)] = [
            (100, 82), (100, 83), (520, 82), (100, 79), (100, 80),
            (100, 82), (100, 83), (550, 82), (100, 78), (100, 79),
            (100, 82), (100, 83), (520, 82), (100, 78),
        ]
        return buildObservations(configs: configs)
    }

    private static func buildObservations(configs: [(Int, Int)]) -> [CoachDailyObservation] {
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var observations: [CoachDailyObservation] = []

        for (index, config) in configs.enumerated() {
            let offset = configs.count - index
            guard let date = calendar.date(byAdding: .day, value: -offset, to: anchor) else { continue }

            observations.append(
                nutritionObservation(
                    date: date,
                    recoveryPercent: config.1,
                    calorieDeficit: config.0
                )
            )
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }

    static func nutritionObservation(
        date: Date,
        recoveryPercent: Int,
        calorieDeficit: Int
    ) -> CoachDailyObservation {
        CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 450,
            recoveryPercent: recoveryPercent,
            bedStartNormalizedMinutes: 1_380,
            proteinGrams: calorieDeficit >= 450 ? 90 : 140,
            carbsGrams: calorieDeficit >= 450 ? 150 : 220,
            fatGrams: 50,
            caloriesEaten: max(2_400 - calorieDeficit, 1_200),
            calorieDeficit: calorieDeficit,
            hydrationLiters: calorieDeficit >= 450 ? 1.8 : 2.4,
            mealsLoggedCount: 3,
            hasPopulatedNutritionFields: true
        )
    }
}
