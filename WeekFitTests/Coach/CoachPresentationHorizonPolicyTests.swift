import XCTest
@testable import WeekFit

final class CoachPresentationHorizonPolicyTests: XCTestCase {

    // MARK: - Horizon matrix (same recovery scenario, different clock buckets)

    func testRecoveryScenarioHorizonMatrix() throws {
        let expectations: [(CoachTimeOfDay, CoachPresentationHorizon)] = [
            (.morning, .nextHours),       // 08:30
            (.midday, .nextHours),        // 10:47
            (.afternoon, .laterToday),    // 15:00
            (.evening, .evening),         // 19:00
            (.lateEvening, .tomorrow)      // 22:00
        ]

        for (timeOfDay, expectedHorizon) in expectations {
            let input = recoveryDayInput(timeOfDay: timeOfDay, completedWalk: timeOfDay == .midday)
            XCTAssertEqual(
                CoachPresentationHorizonPolicy.resolve(input: input),
                expectedHorizon,
                "horizon at \(timeOfDay.rawValue)"
            )
            XCTAssertEqual(
                input.presentationHorizon,
                expectedHorizon,
                "presentationHorizon property at \(timeOfDay.rawValue)"
            )
        }
    }

    func testRecoveryScenarioCopyPassesHorizonAuditAcrossMatrix() throws {
        let clockLabels: [(CoachTimeOfDay, String)] = [
            (.morning, "08:30"),
            (.midday, "10:47"),
            (.afternoon, "15:00"),
            (.evening, "19:00"),
            (.lateEvening, "22:00")
        ]

        var failures: [String] = []

        for (timeOfDay, label) in clockLabels {
            let completedWalk = timeOfDay == .midday || timeOfDay == .evening || timeOfDay == .lateEvening
            let input = recoveryDayInput(timeOfDay: timeOfDay, completedWalk: completedWalk)
            guard let pack = CoachCopyRegistry.resolve(input) else {
                failures.append("\(label): missing pack")
                continue
            }

            let horizonReport = CoachPresentationHorizonCopyAudit.audit(pack: pack, input: input)
            if !horizonReport.isClean {
                failures.append(
                    "\(label) horizon: " +
                    horizonReport.findings.map { "\($0.section) \($0.phrase)" }.joined(separator: ", ")
                )
            }

            let whyReport = WhyRowTimingAudit.audit(
                rows: pack.supportingSignals.lines.flatMap { [($0.russian, "ru"), ($0.english, "en")] },
                input: input
            )
            if !whyReport.isClean {
                failures.append(
                    "\(label) why: " +
                    whyReport.findings.map { "\($0.phrase) (\($0.reason))" }.joined(separator: ", ")
                )
            }

            let quality = CoachCopyQualityAudit.audit(pack: pack, input: input)
            let horizonViolations = quality.violations.filter { $0.contains("presentation horizon") || $0.contains("why row timing") }
            if !horizonViolations.isEmpty {
                failures.append("\(label) quality: \(horizonViolations.joined(separator: "; "))")
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testActiveSessionForcesNowHorizon() {
        let input = recoveryDayInput(timeOfDay: .midday, completedWalk: false, activityState: .active, sessionPhase: .during)
        XCTAssertEqual(CoachPresentationHorizonPolicy.resolve(input: input), .now)
    }

    // MARK: - Relative progress

    func testWater250mlNormalAt1030BehindAt1900() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1_200,
            caloriesGoal: 2_000,
            proteinCurrent: 60,
            proteinGoal: 140,
            waterCurrent: 0.25,
            waterGoal: 3.0
        )

        let morning = RelativeProgressPolicy.evaluate(
            nutrition: nutrition,
            hour: 10,
            horizon: .nextHours
        )
        XCTAssertFalse(morning.hydrationRelativelyBehind, "250 ml at 10:30 should feel on pace")
        XCTAssertFalse(morning.shouldSurfaceHydrationWhyRow)

        let evening = RelativeProgressPolicy.evaluate(
            nutrition: nutrition,
            hour: 19,
            horizon: .evening
        )
        XCTAssertTrue(evening.hydrationRelativelyBehind)
        XCTAssertTrue(evening.shouldSurfaceHydrationWhyRow)
    }

    func testFuel400kcalAcceptableAt1030BehindAt1900() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 400,
            caloriesGoal: 2_000,
            proteinCurrent: 20,
            proteinGoal: 140,
            waterCurrent: 0.8,
            waterGoal: 3.0
        )

        let morning = RelativeProgressPolicy.evaluate(
            nutrition: nutrition,
            hour: 10,
            horizon: .nextHours,
            mealWindowOpen: true
        )
        XCTAssertFalse(morning.fuelRelativelyBehind)
        XCTAssertFalse(morning.shouldSurfaceFuelWhyRow)

        let evening = RelativeProgressPolicy.evaluate(
            nutrition: nutrition,
            hour: 19,
            horizon: .evening,
            mealWindowOpen: true
        )
        XCTAssertTrue(evening.fuelRelativelyBehind)
        XCTAssertTrue(evening.shouldSurfaceFuelWhyRow)
    }

    func testNextHoursHorizonSuppressesBehindWhyRowsEvenWhenPaceFlagsBehind() {
        let input = CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: true,
                hydrationBehind: true,
                tomorrowDemand: .none,
                activityType: .none,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: .midday,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: CoachAthleteStateResolver.resolve(
                dayReadiness: CoachDayReadiness(
                    recoveryPercent: 80,
                    sleepHours: 7.5,
                    recoveryBand: .good,
                    hadHeavyYesterday: false,
                    sleepIsLow: false
                )
            ),
            fuelState: .behind,
            hydrationState: .behind,
            safetyAlert: nil,
            semanticColor: .stable,
            alertSeverity: .elevated,
            tomorrowWorkout: nil,
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 80,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            ),
            mealWindowOpen: true
        )

        let progress = RelativeProgressPolicy.evaluate(input: input)
        XCTAssertFalse(progress.hydrationRelativelyBehind)
        XCTAssertFalse(progress.fuelRelativelyBehind)
        XCTAssertFalse(progress.shouldSurfaceHydrationWhyRow)
        XCTAssertFalse(progress.shouldSurfaceFuelWhyRow)
        XCTAssertTrue(input.modifiers.hydrationBehind)
        XCTAssertTrue(input.modifiers.fuelBehind)
    }

    // MARK: - Helpers

    private func recoveryDayInput(
        timeOfDay: CoachTimeOfDay,
        completedWalk: Bool,
        activityState: CoachActivityState = .none,
        sessionPhase: CoachSessionPhase = .idle
    ) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 38,
            sleepHours: 5.0,
            recoveryBand: .low,
            hadHeavyYesterday: true,
            sleepIsLow: true
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .fresh,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: completedWalk ? .walk : .none,
                durationBand: .short,
                completedSeriousActivities: .none,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .none
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: completedWalk ? .recentCompleted : .idle,
            sessionPhase: sessionPhase,
            activityState: activityState,
            minutesSinceEnd: completedWalk ? 45 : nil,
            mealWindowOpen: false
        )
    }
}
