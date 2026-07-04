import XCTest
@testable import WeekFit

final class CoachCopyRegistryTests: XCTestCase {

    private let defaultColors = (r: 0.2, g: 0.6, b: 0.9)

    // MARK: - duringEndurance + hydrationBehind

    func testDuringEnduranceHydrationBehindKeepsWorkoutAsMainStory() throws {
        let result = evaluateCycling(hydration: behindHydration())
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .duringEndurance)
        XCTAssertTrue(allText(in: pack.assessment).contains(where: {
            $0.lowercased().contains("bike") || $0.contains("велосипед") || $0.lowercased().contains("ride")
        }))
        XCTAssertFalse(allText(in: pack.assessment).contains(where: { mentionsHydration($0) }))
        XCTAssertFalse(allText(in: pack.recommendation).contains(where: { mentionsHydration($0) }))
        XCTAssertTrue(allText(in: pack.supportingSignals).contains(where: { mentionsHydration($0) }))
        XCTAssertNil(pack.warningLayer)
    }

    func testStableDayFuelBehindKeepsStableCopy() throws {
        let now = CoachTestClock.reference
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )
        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [], nutrition: nutrition, brainHour: 14)
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .stableDay)
        XCTAssertTrue(pack.assessment.lines.first?.english.contains("urgent") == true)
        XCTAssertTrue(allText(in: pack.supportingSignals).contains(where: { mentionsFuel($0) }))
        XCTAssertFalse(allText(in: pack.assessment).contains(where: { mentionsFuel($0) }))
    }

    func testMorningReadinessEmptyNutritionSuppressesSupportingSignals() throws {
        let morning = date(hour: 7, minute: 30)
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2_800,
            proteinCurrent: 0,
            proteinGoal: 140,
            waterCurrent: 0,
            waterGoal: 2.5
        )
        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], nutrition: nutrition, brainHour: 7)
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .morningReadiness)
        XCTAssertTrue(pack.supportingSignals.lines.isEmpty)
        XCTAssertNil(pack.warningLayer)
    }

    // MARK: - tomorrowProtection

    func testTomorrowProtectionCopyFocusesOnSavingForTomorrow() throws {
        let evening = date(hour: 19, minute: 15)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!

        let completedRide = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: CoachTestClock.offset(hours: -10, from: evening),
            durationMinutes: 120,
            completed: true
        )
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, tomorrowRun],
                actualLoad: heavyActualLoad(),
                brainHour: 19
            )
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .tomorrowProtection)
        let storyText = joinedCopy(pack)
        XCTAssertTrue(
            storyText.lowercased().contains("tomorrow") ||
                storyText.contains("завтра") ||
                storyText.lowercased().contains("banked") ||
                storyText.lowercased().contains("sleep") ||
                storyText.contains("нагрузк")
        )
        XCTAssertTrue(
            storyText.lowercased().contains("recovery") ||
                storyText.lowercased().contains("soft") ||
                storyText.lowercased().contains("easy") ||
                storyText.lowercased().contains("protect") ||
                storyText.lowercased().contains("sleep") ||
                storyText.lowercased().contains("banked") ||
                storyText.contains("восстанов") ||
                storyText.contains("мягк") ||
                storyText.contains("лёгк") ||
                storyText.contains("берег") ||
                storyText.contains("сон")
        )
    }

    // MARK: - walkAfterHeavyLoad

    func testWalkAfterHeavyLoadCopyIsAboutRecoveryNotTraining() throws {
        let now = CoachTestClock.reference
        let walkStart = CoachTestClock.offset(minutes: -50, from: now)
        let walk = walkActivity(start: walkStart)
        walk.isCompleted = true

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: now,
                activities: [walk],
                actualLoad: heavyActualLoad(),
                brainHour: 14
            ),
            focusActivity: walk
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .walkAfterHeavyLoad)
        let assessment = pack.assessment.lines.first?.english.lowercased() ?? ""
        XCTAssertTrue(assessment.contains("walk") || assessment.contains("settle") || assessment.contains("day"))
        XCTAssertFalse(assessment.contains("training") || assessment.contains("workout"))
        let avoid = pack.avoid.lines.first?.english.lowercased() ?? ""
        XCTAssertTrue(avoid.contains("step") || avoid.contains("cardio") || avoid.contains("load"))
    }

    // MARK: - morningReadiness

    func testMorningReadinessDoesNotLeadWithFoodOrWater() throws {
        let morning = date(hour: 7, minute: 30)
        let nutrition = behindHydration()
        let fuelBehind = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 0.9,
            waterGoal: 2.5
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], nutrition: fuelBehind, brainHour: 7)
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .morningReadiness)
        XCTAssertFalse(allText(in: pack.assessment).contains(where: { mentionsHydration($0) || mentionsFuel($0) }))
        XCTAssertFalse(allText(in: pack.recommendation).contains(where: { mentionsHydration($0) || mentionsFuel($0) }))
        XCTAssertFalse(allText(in: pack.supportingSignals).contains(where: { mentionsHydration($0) || mentionsFuel($0) }))
        XCTAssertNil(pack.warningLayer)
    }

    // MARK: - safetyAlert warning layer

    func testDuringEnduranceCriticalHydrationAddsWarningWithoutChangingScenario() throws {
        let result = evaluateCycling(hydration: criticalHydration())
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(pack.scenario, .duringEndurance)
        XCTAssertEqual(pack.warningLayer?.alert, .hydrationCritical)
        XCTAssertTrue(allText(in: pack.assessment).contains(where: {
            $0.lowercased().contains("bike") || $0.contains("велосипед")
        }))
    }

    // MARK: - All scenarios registered

    func testAllScenariosResolveCopyPack() {
        for scenario in CoachScenarioKey.allCases {
            let input = CoachCopyQualityTests.baselineInput(for: scenario)
            XCTAssertNotNil(
                CoachCopyRegistry.resolve(input),
                "missing copy pack for \(scenario.rawValue)"
            )
        }
    }

    // MARK: - Helpers

    private func evaluateCycling(hydration: CoachNutritionContext) -> CoachEngine.Result {
        let now = CoachTestClock.reference
        let cycling = PlannedActivity(
            date: CoachTestClock.offset(minutes: -90, from: now),
            type: "workout",
            title: "100 km Cycling",
            durationMinutes: 360,
            icon: "figure.outdoor.cycle",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b,
            calories: 900
        )
        return CoachEngine.evaluate(
            input: makeInput(now: now, activities: [cycling], nutrition: hydration, brainHour: 14),
            focusActivity: cycling
        )
    }

    private func behindHydration() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 1.06,
            waterGoal: 2.5
        )
    }

    private func criticalHydration() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 0.4,
            waterGoal: 2.5
        )
    }

    private func heavyActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 850,
            exerciseMinutes: 110,
            standHours: nil,
            activityGoalCalories: 600,
            activityProgress: 1.6
        )
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        nutrition: CoachNutritionContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        brainHour: Int = 14
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: actualLoad ?? CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: nutrition ?? behindHydration(),
            source: "CoachCopyRegistryTests"
        )
    }

    private func walkActivity(start: Date) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "recovery",
            title: "Walk",
            durationMinutes: 30,
            icon: "figure.walk",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func allText(in section: CoachCopySection) -> [String] {
        section.lines.flatMap { [$0.english, $0.russian] }
    }

    private func joinedCopy(_ pack: CoachCopyPack) -> String {
        [
            allText(in: pack.assessment),
            allText(in: pack.recommendation),
            allText(in: pack.nextAction)
        ].flatMap { $0 }.joined(separator: " ")
    }

    private func mentionsHydration(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("water") || lower.contains("fluid") || lower.contains("hydration") ||
            text.contains("вод") || text.contains("жидк")
    }

    private func mentionsFuel(_ text: String) -> Bool {
        CoachCopyQualityAudit.mentionsFuel(text)
    }
}
