import XCTest
@testable import WeekFit

final class CoachDailyObservationNutritionBuilderTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    func testMissingNutritionSourceLeavesFieldsUnset() {
        let snapshot = CoachDailyObservationNutritionBuilder.build(
            totals: .init(
                proteinGrams: 0,
                carbsGrams: 0,
                fatGrams: 0,
                caloriesEaten: 0,
                hydrationLiters: 0,
                mealsLoggedCount: 0
            ),
            calorieTarget: nil,
            nutritionDataAvailable: false
        )

        XCTAssertNil(snapshot)
    }

    func testAllZeroResolvedNutritionDayIsPopulated() {
        let observation = CoachObservationAssembler.makeObservation(
            dayKey: "2026-03-10",
            sleepMinutes: 450,
            recoveryPercent: 82,
            bedStartNormalizedMinutes: 1_380,
            metrics: .empty,
            workouts: [],
            trainingDataAvailable: false,
            healthNutritionSnapshot: NutritionMetricsSnapshot(
                protein: 0,
                carbs: 0,
                fats: 0,
                calories: 0,
                waterLiters: 0,
                mealsLoggedCount: 0,
                isResolved: true
            ),
            plannedActivities: [],
            calorieTarget: 2_200,
            nutritionDataAvailable: true
        )

        XCTAssertTrue(observation.hasPopulatedNutritionFieldsResolved)
        XCTAssertEqual(observation.proteinGrams, 0)
        XCTAssertEqual(observation.carbsGrams, 0)
        XCTAssertEqual(observation.fatGrams, 0)
        XCTAssertEqual(observation.caloriesEaten, 0)
        XCTAssertEqual(observation.calorieDeficit, 2_200)
        XCTAssertEqual(observation.hydrationLiters, 0)
        XCTAssertEqual(observation.mealsLoggedCount, 0)
    }

    func testAssemblerMergesNutritionFromPlannedMeals() {
        let date = makeDate()
        let observation = CoachObservationAssembler.makeObservation(
            dayKey: CoachDailyObservation.dayKey(for: date),
            sleepMinutes: 420,
            recoveryPercent: 78,
            bedStartNormalizedMinutes: nil,
            metrics: .empty,
            workouts: [],
            trainingDataAvailable: false,
            healthNutritionSnapshot: nil,
            plannedActivities: [CoachPlannedActivitySnapshot(from: completedMeal(on: date))],
            calorieTarget: 2_400,
            nutritionDataAvailable: true
        )

        XCTAssertTrue(observation.hasPopulatedNutritionFieldsResolved)
        XCTAssertEqual(observation.proteinGrams, 35)
        XCTAssertEqual(observation.carbsGrams, 40)
        XCTAssertEqual(observation.fatGrams, 12)
        XCTAssertEqual(observation.caloriesEaten, 480)
        XCTAssertEqual(observation.calorieDeficit, 1_920)
        XCTAssertEqual(observation.mealsLoggedCount, 1)
    }

    func testAssemblerWithoutNutritionSourcePreservesSleepOnlyObservation() {
        let observation = CoachObservationAssembler.makeObservation(
            dayKey: "2026-03-11",
            sleepMinutes: 420,
            recoveryPercent: 76,
            bedStartNormalizedMinutes: nil,
            metrics: .empty,
            workouts: [],
            trainingDataAvailable: false,
            healthNutritionSnapshot: nil,
            plannedActivities: [],
            nutritionDataAvailable: false
        )

        XCTAssertEqual(observation.sleepMinutes, 420)
        XCTAssertNil(observation.hasPopulatedNutritionFields)
        XCTAssertFalse(observation.hasPopulatedNutritionFieldsResolved)
    }

    @MainActor
    func testNutritionRichObservationsDoNotEmitNewBeliefEvents() {
        CoachUnderstandingStore.resetForTests()

        let date = makeDate()
        let observations = SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs().map { observation in
            CoachObservationAssembler.makeObservation(
                dayKey: observation.dayKey,
                sleepMinutes: observation.sleepMinutes,
                recoveryPercent: observation.recoveryPercent,
                bedStartNormalizedMinutes: observation.bedStartNormalizedMinutes,
                metrics: .empty,
                workouts: [],
                trainingDataAvailable: false,
                healthNutritionSnapshot: NutritionMetricsSnapshot(
                    protein: 150,
                    carbs: 210,
                    fats: 60,
                    calories: 2_100,
                    waterLiters: 2.5,
                    mealsLoggedCount: 3,
                    isResolved: true
                ),
                plannedActivities: [CoachPlannedActivitySnapshot(from: completedMeal(on: date))],
                calorieTarget: 2_300,
                nutritionDataAvailable: true
            )
        }

        CoachObservationStore.seedForTests(observations)
        CoachUnderstandingService.evaluateBeliefs()

        XCTAssertEqual(CoachBeliefRegistry.registeredBeliefIDs.count, 7)
        XCTAssertEqual(CoachUnderstandingStore.pendingEventsForTests().count, 3)
        XCTAssertEqual(Set(CoachUnderstandingStore.pendingEventsForTests().map(\.beliefID)), Set([
            .sleepConsistencyRecovery,
            .sleepDurationRecovery,
            .lateBedtimeRecovery,
        ]))

        CoachUnderstandingStore.resetForTests()
    }

    func testDebugInspectorReportsNutritionCoverage() {
        CoachObservationStore.seedForTests([
            CoachDailyObservation(
                dayKey: "2026-03-01",
                sleepMinutes: 420,
                recoveryPercent: 80,
                proteinGrams: 120,
                carbsGrams: 180,
                fatGrams: 45,
                caloriesEaten: 1_900,
                hydrationLiters: 2.1,
                mealsLoggedCount: 2,
                hasPopulatedNutritionFields: true
            ),
            CoachDailyObservation(
                dayKey: "2026-03-02",
                sleepMinutes: 430,
                recoveryPercent: 82
            ),
        ])

        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))

        XCTAssertEqual(snapshot.nutritionCoverage.populatedCount, 1)
        XCTAssertEqual(snapshot.nutritionCoverage.missingCount, 1)
        XCTAssertEqual(snapshot.nutritionCoverage.latestDayKey, "2026-03-02")
        XCTAssertEqual(snapshot.nutritionCoverage.latestNutritionStatus, "missing")

        CoachObservationStore.resetForTests()
    }

    // MARK: - Helpers

    private func completedMeal(on date: Date) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "meal",
            title: "Test Lunch",
            durationMinutes: 20,
            icon: "fork.knife",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 480,
            protein: 35,
            carbs: 40,
            fats: 12,
            isCompleted: true
        )
    }

    private func makeDate() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = 13
        return Calendar.current.date(from: components)!
    }
}
