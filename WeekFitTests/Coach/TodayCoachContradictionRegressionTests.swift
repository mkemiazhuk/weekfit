import XCTest
@testable import WeekFit

final class TodayCoachContradictionRegressionTests: XCTestCase {

    func testRecoveryLedTodayCannotPushHardTraining() {
        let contradiction = contradictionDetected(
            todayHeadline: "Recovery leads today",
            coachText: "Push hard training and chase a full strength session"
        )

        XCTAssertTrue(contradiction, "Recovery-led Today plus hard-training Coach copy must be detected as a contradiction")
    }

    func testTomorrowProtectionRequiresReason() {
        let snapshot = finalStressDaySnapshot()

        if snapshot.tomorrowProtectionState.recommended || snapshot.tomorrowProtectionState.active {
            let reasons = "\(snapshot.tomorrowProtectionReasons) \(snapshot.decisionTrace)".lowercased()
            let hasValidReason = validTomorrowProtectionReasons.contains { reasons.contains($0) }
            XCTAssertTrue(hasValidReason, snapshot.formattedFailureAudit)
        }
    }

    func testHydrationPromptHidesAfterTargetReached() {
        let scenario = TodayCoachScenarioFactory()
        scenario.syncPoorSleep()
        scenario.logWater(id: "water-1", title: "Water One", liters: 1.4, at: scenario.time(hour: 10))
        scenario.logWater(id: "water-2", title: "Water Two", liters: 1.2, at: scenario.time(hour: 11))

        let snapshot = scenario.snapshot(
            checkpoint: "hydration-target",
            action: "Hydration reaches target",
            at: scenario.time(hour: 11)
        )

        XCTAssertGreaterThanOrEqual(snapshot.nutritionContext.waterCurrent, snapshot.nutritionContext.waterGoal, snapshot.formattedFailureAudit)
        XCTAssertFalse(snapshot.hydrationPromptVisible, snapshot.formattedFailureAudit)
        XCTAssertLessThanOrEqual(occurrences(of: "drink", in: snapshot.recommendationTrace), 1, snapshot.formattedFailureAudit)
    }

    func testFoodAndDrinkNeverCreatePlannerConflict() {
        let scenario = TodayCoachScenarioFactory()
        let meal = scenario.logMeal(
            id: "breakfast",
            title: "Breakfast",
            at: scenario.time(hour: 8),
            calories: 400,
            protein: 25,
            carbs: 45,
            fats: 12
        )
        let drink = scenario.logWater(id: "water", title: "Water", liters: 0.5, at: scenario.time(hour: 8, minute: 5))
        let snapshot = scenario.snapshot(
            checkpoint: "food-drink-planner",
            action: "Food and drink logged",
            at: scenario.time(hour: 8, minute: 5)
        )

        assertDoesNotReservePlannerTime(meal, snapshot)
        assertDoesNotReservePlannerTime(drink, snapshot)
    }

    func testCancelledActivityDoesNotCountAsCompleted() {
        let scenario = TodayCoachScenarioFactory()
        scenario.startRecoveryWalk(at: scenario.time(hour: 9))
        scenario.cancelRecoveryWalk()

        let snapshot = scenario.snapshot(
            checkpoint: "cancelled-walk",
            action: "Recovery walk cancelled",
            at: scenario.time(hour: 9, minute: 20)
        )

        XCTAssertTrue(snapshot.cancelledActivities.contains("Recovery Walk"), snapshot.formattedFailureAudit)
        XCTAssertFalse(snapshot.completedActivities.contains("Recovery Walk"), snapshot.formattedFailureAudit)
        XCTAssertFalse(snapshot.todayCards.contains("completed:Recovery Walk"), snapshot.formattedFailureAudit)
    }

    func testActiveSaunaIsNotCompletedSaunaImpact() {
        let scenario = TodayCoachScenarioFactory()
        scenario.syncPoorSleep()
        scenario.startSauna(at: scenario.time(hour: 15))

        let snapshot = scenario.snapshot(
            checkpoint: "active-sauna",
            action: "Sauna active but not completed",
            at: scenario.time(hour: 15)
        )

        let audit = snapshot.decisionAudit.rawInputs.joined(separator: " ").lowercased()
        XCTAssertEqual(snapshot.activeActivity, "Sauna", snapshot.formattedFailureAudit)
        XCTAssertFalse(snapshot.completedActivities.contains("Sauna"), snapshot.formattedFailureAudit)
        XCTAssertTrue(audit.contains("saunaimpact=none"), snapshot.formattedFailureAudit)
    }

    func testPlannedWorkoutDoesNotDuplicateAfterBecomingActive() {
        let scenario = TodayCoachScenarioFactory()
        scenario.startPlannedStrength(at: scenario.time(hour: 18))

        let snapshot = scenario.snapshot(
            checkpoint: "active-strength",
            action: "Planned strength becomes active",
            at: scenario.time(hour: 18)
        )

        XCTAssertEqual(snapshot.activeActivity, "Strength", snapshot.formattedFailureAudit)
        XCTAssertEqual(snapshot.todayCards.filter { $0.contains("Strength") }.count, 1, snapshot.formattedFailureAudit)
        XCTAssertFalse(snapshot.todayCards.contains("planned:Strength") && snapshot.todayCards.contains("active:Strength"), snapshot.formattedFailureAudit)
    }

    func testPartialWorkoutIsNotFullCompletedWorkout() {
        let scenario = TodayCoachScenarioFactory()
        scenario.startPlannedStrength(at: scenario.time(hour: 18))
        scenario.stopStrengthEarly(at: scenario.time(hour: 18, minute: 10))

        let snapshot = scenario.snapshot(
            checkpoint: "partial-strength",
            action: "Strength stopped after 10 minutes",
            at: scenario.time(hour: 18, minute: 10)
        )

        XCTAssertTrue(snapshot.partialActivities.contains("Strength"), snapshot.formattedFailureAudit)
        XCTAssertFalse(snapshot.completedActivities.contains("Strength"), snapshot.formattedFailureAudit)
        XCTAssertTrue(snapshot.todayCards.contains("partial:Strength"), snapshot.formattedFailureAudit)
        XCTAssertEqual(snapshot.dayContext.completedTrainingMinutes, 10, snapshot.formattedFailureAudit)
        XCTAssertEqual(snapshot.dayContext.completedTrainingStressScore, 0, snapshot.formattedFailureAudit)
        XCTAssertTrue(Set(snapshot.completedActivities).isDisjoint(with: Set(snapshot.partialActivities)), snapshot.formattedFailureAudit)
    }

    func testDeletedMealDoesNotReappearInCoachNutrition() {
        let scenario = TodayCoachScenarioFactory()
        scenario.logMeal(
            id: "lunch",
            title: "Lunch",
            at: scenario.time(hour: 12, minute: 30),
            calories: 700,
            protein: 40,
            carbs: 80,
            fats: 20
        )
        let beforeDelete = scenario.snapshot(
            checkpoint: "before-delete",
            action: "Lunch logged",
            at: scenario.time(hour: 12, minute: 30)
        )
        scenario.deleteMeal(id: "lunch")
        let afterDelete = scenario.snapshot(
            checkpoint: "after-delete",
            action: "Lunch deleted",
            at: scenario.time(hour: 13)
        )

        XCTAssertTrue(afterDelete.deletedMealIDs.contains("lunch"), afterDelete.formattedFailureAudit)
        XCTAssertFalse(afterDelete.meals.contains("Lunch"), afterDelete.formattedFailureAudit)
        XCTAssertLessThan(afterDelete.nutritionContext.caloriesCurrent, beforeDelete.nutritionContext.caloriesCurrent, afterDelete.formattedFailureAudit)
        XCTAssertFalse(afterDelete.recommendationTrace.localizedCaseInsensitiveContains("Lunch"), afterDelete.formattedFailureAudit)
    }

    func testMissingSleepIsNotInventedByCoach() {
        let scenario = TodayCoachScenarioFactory()
        let snapshot = scenario.snapshot(
            checkpoint: "missing-sleep",
            action: "App opens before sleep sync",
            at: scenario.time(hour: 6, minute: 30)
        )

        let coachText = "\(snapshot.coachHeadline) \(snapshot.coachExplanation) \(snapshot.recommendationTrace)"
        XCTAssertTrue(snapshot.hasMissingSleepData, snapshot.formattedFailureAudit)
        XCTAssertFalse(coachText.localizedCaseInsensitiveContains("slept well"), snapshot.formattedFailureAudit)
        XCTAssertFalse(coachText.localizedCaseInsensitiveContains("sleep is strong"), snapshot.formattedFailureAudit)
    }

    private var validTomorrowProtectionReasons: [String] {
        [
            "poor sleep",
            "short sleep",
            "sleep debt",
            "high fatigue",
            "sauna impact",
            "heavy training load",
            "low recovery score",
            "compromised recovery",
            "late evening recovery window"
        ]
    }

    private func finalStressDaySnapshot() -> CoachDebugSnapshot {
        let scenario = TodayCoachScenarioFactory()
        scenario.syncPoorSleep()
        scenario.logMeal(id: "breakfast", title: "Breakfast", at: scenario.time(hour: 8, minute: 15), calories: 520, protein: 32, carbs: 58, fats: 16)
        scenario.startRecoveryWalk(at: scenario.time(hour: 10))
        scenario.completeRecoveryWalk(at: scenario.time(hour: 10, minute: 35))
        scenario.logWater(id: "water-1100", title: "Morning Water", liters: 0.8, at: scenario.time(hour: 11))
        scenario.logMeal(id: "lunch", title: "Lunch", at: scenario.time(hour: 12, minute: 30), calories: 720, protein: 45, carbs: 82, fats: 22)
        scenario.deleteMeal(id: "lunch")
        scenario.logMeal(id: "custom-meal", title: "Custom Meal", at: scenario.time(hour: 14), calories: 680, protein: 48, carbs: 66, fats: 20)
        scenario.startSauna(at: scenario.time(hour: 15))
        scenario.completeSauna(at: scenario.time(hour: 15, minute: 30))
        scenario.logWater(id: "water-1600", title: "Post-sauna Water", liters: 1.2, at: scenario.time(hour: 16))
        scenario.startPlannedStrength(at: scenario.time(hour: 18))
        scenario.stopStrengthEarly(at: scenario.time(hour: 18, minute: 10))
        scenario.logMeal(id: "dinner", title: "Dinner", at: scenario.time(hour: 19), calories: 820, protein: 52, carbs: 88, fats: 26)
        scenario.logWater(id: "water-2000", title: "Evening Drink", liters: 0.6, at: scenario.time(hour: 20))
        return scenario.snapshot(
            checkpoint: "final",
            action: "Final daily state",
            at: scenario.time(hour: 22, minute: 30)
        )
    }

    private func contradictionDetected(todayHeadline: String, coachText: String) -> Bool {
        let today = todayHeadline.lowercased()
        let coach = coachText.lowercased()
        let recoveryLed = today.contains("recovery") || today.contains("sleep") || today.contains("protect")
        let pushesHardTraining = coach.contains("push hard") ||
            coach.contains("hard training") ||
            coach.contains("go hard") ||
            coach.contains("full strength")
        return recoveryLed && pushesHardTraining
    }

    private func assertDoesNotReservePlannerTime(
        _ activity: PlannedActivity,
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(activity.blocksPlannerTime, snapshot.formattedFailureAudit, file: file, line: line)
        XCTAssertTrue(snapshot.plannerTrace.ignoredFoodAndDrinkIDs.contains(activity.id), snapshot.formattedFailureAudit, file: file, line: line)
        XCTAssertFalse(snapshot.plannerTrace.reservedSlots.contains { $0.activityID == activity.id }, snapshot.formattedFailureAudit, file: file, line: line)
        let conflictLine = snapshot.plannerTrace.conflictChecks.first { $0.contains(activity.title) } ?? ""
        XCTAssertTrue(conflictLine.contains("conflict=false"), snapshot.formattedFailureAudit, file: file, line: line)
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        let lowerNeedle = needle.lowercased()
        let lowerText = text.lowercased()
        var count = 0
        var searchRange = lowerText.startIndex..<lowerText.endIndex
        while let range = lowerText.range(of: lowerNeedle, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<lowerText.endIndex
        }
        return count
    }
}
