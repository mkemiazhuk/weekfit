import XCTest
import HealthKit
import SwiftUI
@testable import WeekFit

final class CoachEveningRecapActivityAggregatorTests: XCTestCase {

    func testCasualStepsWithoutWorkoutsDoNotCountAsWorkouts() {
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 8_420,
            dayWalkingRunningDistanceKm: 6.2,
            sessions: [],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 0)
        XCTAssertEqual(summary.workoutMinutes, 0)
        XCTAssertEqual(summary.dayTone, .active)
        XCTAssertNotNil(summary.hero)
        XCTAssertEqual(summary.hero?.kind, .walking)
        XCTAssertEqual(summary.hero?.unitText, WeekFitUnitPolicy.distanceUnitLabel(for: .metric))
        XCTAssertNil(summary.workoutSummaryLine)
    }

    func testRecordedWalksCaptionWhenMultipleWalkWorkouts() {
        let sessions = (0..<5).map { index in
            makeSession(
                type: .walking,
                title: "Walk",
                minutes: 20,
                distanceKm: 1.2,
                id: UUID(),
                start: Date().addingTimeInterval(Double(index) * 3600)
            )
        }
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 12_000,
            dayWalkingRunningDistanceKm: 8.0,
            sessions: sessions,
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 5)
        XCTAssertEqual(summary.hero?.sessionCaption?.contains("5"), true)
        XCTAssertTrue(summary.rows.isEmpty || summary.rows.allSatisfy { $0.kind != .walking })
    }

    func testDoesNotDoubleCountWalkWorkoutDistanceIntoDayDistance() {
        let walk = makeSession(
            type: .walking,
            title: "Walk",
            minutes: 40,
            distanceKm: 3.0
        )
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 5_000,
            dayWalkingRunningDistanceKm: 6.2,
            sessions: [walk],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutMinutes, 40)
        let heroValue = summary.hero?.accessibilityPrimary ?? ""
        XCTAssertFalse(heroValue.contains("9.2"))
    }

    func testRunningGetsOwnRowAndCombinedDayLabel() {
        let run = makeSession(
            type: .running,
            title: "Run",
            minutes: 30,
            distanceKm: 5.0
        )
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 9_000,
            dayWalkingRunningDistanceKm: 8.0,
            sessions: [run],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.hero?.kind, .running)
        XCTAssertTrue(summary.rows.contains { $0.kind == .walkingAndRunning })
    }

    func testNoHealthAccessIsNotShownAsZeroActivity() {
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 0,
            dayWalkingRunningDistanceKm: 0,
            sessions: [],
            healthAccessGranted: false,
            unitSystem: .metric
        )
        XCTAssertFalse(summary.healthAccessGranted)
        XCTAssertFalse(summary.hasAnyActivitySignal)
        XCTAssertTrue(summary.rows.isEmpty)
        XCTAssertNil(summary.hero)
    }

    func testDedupesSameWorkoutUUID() {
        let id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let a = makeSession(type: .cycling, title: "Ride", minutes: 42, distanceKm: 12.4, id: id)
        let b = makeSession(type: .cycling, title: "Ride", minutes: 42, distanceKm: 12.4, id: id)
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 0,
            dayWalkingRunningDistanceKm: 0,
            sessions: [a, b],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutMinutes, 42)
    }

    func testDedupesOverlappingSameTypeFromDifferentSources() {
        let start = Date()
        let watch = makeSession(
            type: .cycling,
            title: "Outdoor Ride",
            minutes: 60,
            distanceKm: 20,
            id: UUID(),
            start: start
        )
        let phone = makeSession(
            type: .cycling,
            title: "Outdoor Ride",
            minutes: 58,
            distanceKm: 19.5,
            id: UUID(),
            start: start.addingTimeInterval(60)
        )
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 0,
            dayWalkingRunningDistanceKm: 0,
            sessions: [watch, phone],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutMinutes, 60)
    }

    func testNaturalDurationInWorkoutSummary() {
        let a = makeSession(
            type: .traditionalStrengthTraining,
            title: "Gym",
            minutes: 127,
            distanceKm: nil,
            id: UUID(),
            start: Date()
        )
        let b = makeSession(
            type: .traditionalStrengthTraining,
            title: "Gym",
            minutes: 127,
            distanceKm: nil,
            id: UUID(),
            start: Date().addingTimeInterval(5 * 3600)
        )
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 0,
            dayWalkingRunningDistanceKm: 0,
            sessions: [a, b],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertEqual(summary.workoutMinutes, 254)
        let line = summary.workoutSummaryLine ?? ""
        XCTAssertTrue(line.contains("4"), "Expected natural hours in \(line)")
        XCTAssertFalse(line.contains("254 min"))
    }

    func testQuietDayToneWithoutMovement() {
        let summary = CoachEveningRecapActivityAggregator.build(
            steps: 400,
            dayWalkingRunningDistanceKm: 0.2,
            sessions: [],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(summary.dayTone, .quiet)
    }

    func testDayComparisonRequiresEnoughHistory() {
        XCTAssertNil(
            CoachEveningRecapDayComparison.compute(
                todayDistanceKm: 10,
                priorDayMetrics: [(3, 4000), (4, 5000)]
            )
        )
        let priors = (0..<6).map { _ in (distanceKm: 6.0, steps: 8_000) }
        let result = CoachEveningRecapDayComparison.compute(
            todayDistanceKm: 10.0,
            priorDayMetrics: priors
        )
        XCTAssertEqual(result?.deltaKm ?? 0, 4.0, accuracy: 0.01)
        XCTAssertTrue(result?.displayText(unitSystem: .metric).contains("4") == true)
    }

    func testFeelingReactionAvoidsThanksTemplate() {
        let text = CoachEveningRecapCopy.feelingReaction(
            feeling: .tired,
            tone: .active,
            givenName: "Max"
        )
        XCTAssertFalse(text.localizedCaseInsensitiveContains("thanks"))
        XCTAssertTrue(text.contains("Max"))
    }

    func testNoteMergesComparisonWithoutDuplicating() {
        let merged = CoachEveningRecapCopy.noteText(
            commentary: "Keep the evening easy.",
            comparison: "You walked 4 km more than usual.",
            feelingReaction: nil,
            isLoading: false,
            failed: false
        )
        XCTAssertEqual(merged, "You walked 4 km more than usual. Keep the evening easy.")
    }

    func testDaySignalsIncludeSupportingActivityAndSleepWithoutFalseAlarms() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 10_000,
            dayWalkingRunningDistanceKm: 8,
            sessions: [
                makeSession(
                    type: .cycling,
                    title: "Ride",
                    // Keep under the walk-hero threshold so walking stays featured
                    // and the ride appears as a supporting activity row.
                    minutes: 20,
                    distanceKm: 6.0,
                    start: Date().addingTimeInterval(3600)
                )
            ],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1800,
            caloriesGoal: 2200,
            proteinCurrent: 120,
            proteinGoal: 130,
            waterCurrent: 2.0,
            waterGoal: 2.5,
            mealsCount: 3
        )
        let signals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: 7.2,
            recoveryPercent: 72,
            nutrition: nutrition,
            unitSystem: .metric
        )
        // Solid day — sleep duration only, no extra "worst" focus.
        XCTAssertEqual(signals.map(\.kind), [.activity, .recovery])
        XCTAssertEqual(signals[0].systemImage, "bicycle")
        XCTAssertFalse(signals[0].detail.localizedCaseInsensitiveContains("8"))
        XCTAssertEqual(signals[1].title, WeekFitLocalizedString("coach.eveningRecap.signal.sleep.title"))
        XCTAssertTrue(
            signals[1].detail.contains("7")
                || signals[1].detail.localizedCaseInsensitiveContains("hr")
                || signals[1].detail.localizedCaseInsensitiveContains("ч")
        )
    }

    func testWorstBodyFocusPrefersLowProteinOverFineRecovery() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 8_000,
            dayWalkingRunningDistanceKm: 6,
            sessions: [],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1600,
            caloriesGoal: 2200,
            proteinCurrent: 55,
            proteinGoal: 130,
            waterCurrent: 2.0,
            waterGoal: 2.5,
            mealsCount: 3
        )
        let signals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: 7.5,
            recoveryPercent: 74,
            nutrition: nutrition,
            unitSystem: .metric
        )
        XCTAssertTrue(signals.contains {
            $0.kind == .food
                && $0.detail == WeekFitLocalizedString("coach.eveningRecap.signal.food.proteinLight")
        })
        XCTAssertTrue(signals.contains {
            $0.title == WeekFitLocalizedString("coach.eveningRecap.signal.sleep.title")
        })
    }

    func testWorstBodyFocusSurfacesMissingWaterWhenMealsLogged() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 8_000,
            dayWalkingRunningDistanceKm: 6,
            sessions: [],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1800,
            caloriesGoal: 2200,
            proteinCurrent: 125,
            proteinGoal: 130,
            waterCurrent: 0,
            waterGoal: 2.5,
            mealsCount: 3
        )
        let signals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: 7.4,
            recoveryPercent: 72,
            nutrition: nutrition,
            unitSystem: .metric
        )
        XCTAssertTrue(signals.contains {
            $0.kind == .water
                && $0.detail == WeekFitLocalizedString("coach.eveningRecap.signal.food.waterLow")
        })
    }

    func testWorstBodyFocusSurfacesSoftRecoveryScore() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 8_000,
            dayWalkingRunningDistanceKm: 6,
            sessions: [],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 2000,
            caloriesGoal: 2200,
            proteinCurrent: 125,
            proteinGoal: 130,
            waterCurrent: 2.2,
            waterGoal: 2.5,
            mealsCount: 3
        )
        let signals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: 7.0,
            recoveryPercent: 48,
            nutrition: nutrition,
            unitSystem: .metric
        )
        XCTAssertTrue(signals.contains {
            $0.id == "recovery.score.focus"
                && $0.detail == WeekFitLocalizedString("coach.eveningRecap.signal.recovery.scoreSofter")
        })
    }

    func testRecoverySessionsAppearAsRecoverySignalsUnderWalkHero() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 9_800,
            dayWalkingRunningDistanceKm: 7.8,
            sessions: [
                makeSession(
                    type: .yoga,
                    title: "Yoga",
                    minutes: 25,
                    distanceKm: nil,
                    start: Date().addingTimeInterval(3600)
                ),
                makeSession(
                    type: .mindAndBody,
                    title: "Stretch",
                    minutes: 15,
                    distanceKm: nil,
                    icon: "figure.cooldown",
                    start: Date().addingTimeInterval(7200)
                )
            ],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(activity.hero?.kind, .walking)
        XCTAssertTrue(activity.rows.contains { $0.kind == .recovery && $0.title.localizedCaseInsensitiveContains("yoga") })
        XCTAssertTrue(activity.rows.contains { $0.kind == .recovery && $0.title.localizedCaseInsensitiveContains("stretch") })

        let signals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: 7.4,
            recoveryPercent: 68,
            nutrition: nil,
            unitSystem: .metric
        )
        let recoverySignals = signals.filter { $0.kind == .recovery }
        // Yoga + Stretch sessions, then sleep.
        XCTAssertGreaterThanOrEqual(recoverySignals.count, 3)
        XCTAssertTrue(recoverySignals.contains { $0.title.localizedCaseInsensitiveContains("yoga") })
        XCTAssertTrue(recoverySignals.contains { $0.title.localizedCaseInsensitiveContains("stretch") })
        XCTAssertTrue(recoverySignals.contains {
            $0.title == WeekFitLocalizedString("coach.eveningRecap.signal.sleep.title")
        })
        XCTAssertEqual(
            recoverySignals.first { $0.title.localizedCaseInsensitiveContains("yoga") }?.systemImage,
            "figure.yoga"
        )
    }

    func testRecoveryWalkStaysWalkingNotRecoveryRow() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 4_500,
            dayWalkingRunningDistanceKm: 3.2,
            sessions: [
                makeSession(
                    type: .walking,
                    title: "Recovery Walk",
                    minutes: 30,
                    distanceKm: 2.5
                )
            ],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertFalse(activity.rows.contains { $0.kind == .recovery })
        XCTAssertEqual(activity.hero?.kind, .walking)
    }

    func testLongYogaDoesNotStealHeroFromMeaningfulWalk() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 9_000,
            dayWalkingRunningDistanceKm: 7.0,
            sessions: [
                makeSession(
                    type: .yoga,
                    title: "Evening Yoga",
                    minutes: 45,
                    distanceKm: nil
                )
            ],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        XCTAssertEqual(activity.hero?.kind, .walking)
        XCTAssertTrue(activity.rows.contains { $0.kind == .recovery })
    }

    func testEmptyNutritionLogDoesNotInventFoodOrWaterProblems() {
        let activity = CoachEveningRecapActivityAggregator.build(
            steps: 8_000,
            dayWalkingRunningDistanceKm: 6,
            sessions: [],
            healthAccessGranted: true,
            unitSystem: .metric
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2200,
            proteinCurrent: 0,
            proteinGoal: 130,
            waterCurrent: 0,
            waterGoal: 2.5,
            mealsCount: 0
        )
        let signals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: 7.0,
            recoveryPercent: 72,
            nutrition: nutrition,
            unitSystem: .metric
        )
        // Empty log ≠ low protein / low water.
        XCTAssertEqual(signals.map(\.kind), [.recovery])
        XCTAssertEqual(signals[0].title, WeekFitLocalizedString("coach.eveningRecap.signal.sleep.title"))
        XCTAssertFalse(signals.contains { $0.kind == .food || $0.kind == .water })
    }

    private func makeSession(
        type: HKWorkoutActivityType,
        title: String,
        minutes: Int,
        distanceKm: Double?,
        id: UUID = UUID(),
        icon: String = "figure.run",
        start: Date = Date()
    ) -> ActivitySessionSnapshot {
        ActivitySessionSnapshot(
            workoutID: id,
            title: title,
            startDate: start,
            durationMinutes: minutes,
            icon: icon,
            color: .blue,
            detail: ActivitySessionDetailSnapshot(
                title: title,
                activityType: type,
                startDate: start,
                endDate: start.addingTimeInterval(Double(minutes) * 60),
                durationMinutes: minutes,
                workoutDurationSeconds: Double(minutes * 60),
                elapsedDurationSeconds: Double(minutes * 60),
                source: "Apple Watch",
                icon: icon,
                color: .blue,
                activeCalories: nil,
                distanceKm: distanceKm,
                averageHeartRate: nil,
                maxHeartRate: nil,
                heartRateSamples: [],
                routePoints: [],
                elevationGain: nil,
                steps: nil,
                cadence: nil
            )
        )
    }
}
