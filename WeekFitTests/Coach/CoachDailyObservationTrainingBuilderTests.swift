import XCTest
@testable import WeekFit

final class CoachDailyObservationTrainingBuilderTests: XCTestCase {

    func testMissingTrainingSourceLeavesFieldsUnset() {
        let snapshot = CoachDailyObservationTrainingBuilder.build(
            metrics: .empty,
            workouts: [],
            trainingDataAvailable: false
        )

        XCTAssertNil(snapshot)
    }

    func testRestDayWhenMovementIsMinimal() {
        let snapshot = CoachDailyObservationTrainingBuilder.build(
            metrics: metrics(exerciseMinutes: 5, activeCalories: 40),
            workouts: [],
            trainingDataAvailable: true
        )

        XCTAssertEqual(snapshot?.workoutIntensityBand, .rest)
        XCTAssertEqual(snapshot?.hadRestDay, true)
        XCTAssertEqual(snapshot?.hadHardTraining, false)
        XCTAssertEqual(snapshot?.trainingLoadScore, 10)
    }

    func testHardDayWhenSeriousWorkoutPresent() {
        let snapshot = CoachDailyObservationTrainingBuilder.build(
            metrics: metrics(exerciseMinutes: 95, activeCalories: 800),
            workouts: [
                CoachWorkoutObservationSample(
                    typeToken: "cycling",
                    durationMinutes: 95,
                    activeCalories: 800,
                    isHardTraining: true,
                    isRecoveryActivity: false
                )
            ],
            trainingDataAvailable: true
        )

        XCTAssertEqual(snapshot?.workoutIntensityBand, .hard)
        XCTAssertEqual(snapshot?.hardWorkoutCount, 1)
        XCTAssertEqual(snapshot?.hadHardTraining, true)
        XCTAssertEqual(snapshot?.workoutTypes, ["cycling"])
        XCTAssertEqual(snapshot?.trainingLoadScore, 90)
    }

    func testModerateDayWithoutHardWorkouts() {
        let snapshot = CoachDailyObservationTrainingBuilder.build(
            metrics: metrics(exerciseMinutes: 55, activeCalories: 420),
            workouts: [
                CoachWorkoutObservationSample(
                    typeToken: "walking",
                    durationMinutes: 55,
                    activeCalories: 420,
                    isHardTraining: false,
                    isRecoveryActivity: true
                )
            ],
            trainingDataAvailable: true
        )

        XCTAssertEqual(snapshot?.workoutIntensityBand, .moderate)
        XCTAssertEqual(snapshot?.hadRecoveryActivity, true)
        XCTAssertEqual(snapshot?.hadHardTraining, false)
    }

    func testAssemblerMergesTrainingIntoObservation() {
        let observation = CoachObservationAssembler.makeObservation(
            dayKey: "2026-03-01",
            sleepMinutes: 450,
            recoveryPercent: 84,
            bedStartNormalizedMinutes: 1_380,
            metrics: metrics(exerciseMinutes: 95, activeCalories: 800),
            workouts: [
                CoachWorkoutObservationSample(
                    typeToken: "cycling",
                    durationMinutes: 95,
                    activeCalories: 800,
                    isHardTraining: true,
                    isRecoveryActivity: false
                )
            ],
            trainingDataAvailable: true
        )

        XCTAssertEqual(observation.exerciseMinutes, 95)
        XCTAssertEqual(observation.workoutIntensityBand, .hard)
        XCTAssertTrue(observation.hasPopulatedTrainingFields)
    }

    func testAssemblerWithoutTrainingSourcePreservesSleepOnlyObservation() {
        let observation = CoachObservationAssembler.makeObservation(
            dayKey: "2026-03-02",
            sleepMinutes: 420,
            recoveryPercent: 76,
            bedStartNormalizedMinutes: nil,
            metrics: .empty,
            workouts: [],
            trainingDataAvailable: false
        )

        XCTAssertEqual(observation.sleepMinutes, 420)
        XCTAssertNil(observation.workoutIntensityBand)
        XCTAssertFalse(observation.hasPopulatedTrainingFields)
    }

    @MainActor
    func testTrainingRichObservationsDoNotEmitNewBeliefEvents() {
        CoachUnderstandingStore.resetForTests()

        var observations = SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs()
        observations = observations.map { observation in
            CoachObservationAssembler.makeObservation(
                dayKey: observation.dayKey,
                sleepMinutes: observation.sleepMinutes,
                recoveryPercent: observation.recoveryPercent,
                bedStartNormalizedMinutes: observation.bedStartNormalizedMinutes,
                metrics: ActivityMetricsSnapshot(
                    activeCalories: 800,
                    steps: 8_000,
                    exerciseMinutes: 95,
                    sleepMinutes: observation.sleepMinutes,
                    timeInBedMinutes: observation.sleepMinutes + 30,
                    awakeMinutes: 20,
                    awakeningsCount: 1,
                    distanceKm: 25,
                    standHours: 10,
                    vo2Max: 48,
                    deepSleepMinutes: 80,
                    remSleepMinutes: 90,
                    coreSleepMinutes: 200,
                    restingHeartRate: 52,
                    hrvSDNN: 65
                ),
                workouts: [
                    CoachWorkoutObservationSample(
                        typeToken: "cycling",
                        durationMinutes: 95,
                        activeCalories: 800,
                        isHardTraining: true,
                        isRecoveryActivity: false
                    )
                ],
                trainingDataAvailable: true
            )
        }

        CoachObservationStore.seedForTests(observations)
        CoachUnderstandingService.evaluateBeliefs()

        XCTAssertEqual(CoachUnderstandingStore.pendingEventsForTests().count, 3)
        XCTAssertEqual(Set(CoachUnderstandingStore.pendingEventsForTests().map(\.beliefID)), Set([
            .sleepConsistencyRecovery,
            .sleepDurationRecovery,
            .lateBedtimeRecovery,
        ]))

        CoachUnderstandingStore.resetForTests()
    }

    // MARK: - Helpers

    private func metrics(exerciseMinutes: Int, activeCalories: Double) -> ActivityMetricsSnapshot {
        ActivityMetricsSnapshot(
            activeCalories: activeCalories,
            steps: 4_000,
            exerciseMinutes: exerciseMinutes,
            sleepMinutes: 450,
            timeInBedMinutes: 480,
            awakeMinutes: 20,
            awakeningsCount: 1,
            distanceKm: 5,
            standHours: 8,
            vo2Max: 45,
            deepSleepMinutes: 80,
            remSleepMinutes: 90,
            coreSleepMinutes: 200,
            restingHeartRate: 52,
            hrvSDNN: 60
        )
    }
}
