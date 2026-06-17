import XCTest
@testable import WeekFit

final class TodayCoachStressScenarioTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testStressDayWithChangingStatesFromToday() {
        CoachScenarioSnapshotPrinter.resetLogFile()

        let scenario = TodayCoachScenarioFactory()

        let wake = scenario.snapshot(
            checkpoint: "06:30",
            action: "App opens with missing sleep, no meals, no drinks, strength planned at 18:00",
            at: scenario.time(hour: 6, minute: 30)
        )
        assertCommonSnapshot(wake)
        expect(wake.hasMissingSleepData, wake, "Coach must mark sleep as missing before late sleep sync")
        expect(wake.readinessScore <= 35, wake, "Readiness confidence should be low/incomplete before sleep exists")
        expect(wake.plannedActivities.contains("Strength"), wake, "Today should show the planned 18:00 strength workout")
        expect(wake.meals.isEmpty, wake, "No meals should be present at app open")
        expect(wake.drinks.isEmpty, wake, "No drinks should be present at app open")
        assertCoachDoesNotInventSleep(wake)

        scenario.syncPoorSleep()
        let sleepSync = scenario.snapshot(
            checkpoint: "07:30",
            action: "Late sleep sync arrives as poor/short sleep",
            at: scenario.time(hour: 7, minute: 30)
        )
        assertCommonSnapshot(sleepSync, previous: wake)
        expect(!sleepSync.hasMissingSleepData, sleepSync, "Sleep should no longer be missing after sync")
        expect(sleepSync.readinessScore <= 55, sleepSync, "Very short sleep should cap readiness below moderate while still allowing raw improvements; see scoring breakdown")
        expect(sleepSync.readinessBreakdown.cap == 55, sleepSync, "Readiness audit should expose the softer very-short-sleep cap")
        expect(sleepSync.readinessBreakdown.final <= (sleepSync.readinessBreakdown.cap ?? 100), sleepSync, "Readiness cap should be respected without hiding lower raw scores")
        expect(sleepSync.readinessBreakdown.capReason == "veryShortSleep", sleepSync, "Very short sleep cap should be explicit")
        expect(sleepSync.recoveryState == .vulnerable || sleepSync.recoveryState == .compromised, sleepSync, "Poor sleep should put recovery at risk")
        expect(sleepSync.plannedActivities.contains("Strength"), sleepSync, "Planned strength should remain after sleep sync")
        expect(sleepSync.coachHeadline != wake.coachHeadline || sleepSync.coachExplanation != wake.coachExplanation, sleepSync, "Today/Coach headline should refresh after late sleep sync without restart")
        assertRiskyStrengthIsNotBlindlyPushed(sleepSync)

        let breakfast = scenario.logMeal(
            id: "breakfast",
            title: "Breakfast",
            at: scenario.time(hour: 8, minute: 15),
            calories: 520,
            protein: 32,
            carbs: 58,
            fats: 16
        )
        let breakfastSnapshot = scenario.snapshot(
            checkpoint: "08:15",
            action: "User logs breakfast from Today",
            at: scenario.time(hour: 8, minute: 15)
        )
        assertCommonSnapshot(breakfastSnapshot, previous: sleepSync)
        expect(breakfastSnapshot.meals == ["Breakfast"], breakfastSnapshot, "Breakfast should be included in Today and Coach nutrition inputs")
        expect(!breakfastSnapshot.todayCards.contains("mealPrompt:missing"), breakfastSnapshot, "Meal prompt should update after breakfast")
        assertFoodAndDrinkDoNotReservePlannerTime(breakfastSnapshot, activity: breakfast)
        expect(breakfastSnapshot.nutritionContext.caloriesCurrent >= 520, breakfastSnapshot, "Coach nutrition state should update immediately after breakfast")

        scenario.startRecoveryWalk(at: scenario.time(hour: 9, minute: 0))
        let activeWalk = scenario.snapshot(
            checkpoint: "09:00",
            action: "User starts unscheduled recovery walk from Today",
            at: scenario.time(hour: 9, minute: 0)
        )
        assertCommonSnapshot(activeWalk, previous: breakfastSnapshot)
        expect(activeWalk.activeActivity == "Recovery Walk", activeWalk, "Today should show the recovery walk as active")
        expect(activeWalk.plannedActivities.contains("Strength"), activeWalk, "Planned 18:00 strength should still exist while walk is active")
        expect(!activeWalk.completedActivities.contains("Recovery Walk"), activeWalk, "Active recovery walk must not be treated as completed")
        assertRiskyStrengthIsNotBlindlyPushed(activeWalk)

        scenario.cancelRecoveryWalk()
        let cancelledWalk = scenario.snapshot(
            checkpoint: "09:20",
            action: "User cancels active recovery walk",
            at: scenario.time(hour: 9, minute: 20)
        )
        assertCommonSnapshot(cancelledWalk, previous: activeWalk)
        expect(cancelledWalk.activeActivity == nil, cancelledWalk, "Cancelled active walk should disappear from active card")
        expect(cancelledWalk.cancelledActivities.contains("Recovery Walk"), cancelledWalk, "Cancelled walk should be tracked as cancelled")
        expect(!cancelledWalk.completedActivities.contains("Recovery Walk"), cancelledWalk, "Cancelled walk must not count as completed recovery")
        expect(!reservedTitles(cancelledWalk).contains("Recovery Walk"), cancelledWalk, "Planner should not keep a stale reservation for the cancelled walk")
        expect(!cancelledWalk.coachExplanation.localizedCaseInsensitiveContains("completed recovery walk"), cancelledWalk, "Coach must not praise a cancelled walk as completed")

        scenario.startRecoveryWalk(at: scenario.time(hour: 10, minute: 0))
        let restartedWalk = scenario.snapshot(
            checkpoint: "10:00",
            action: "User starts the same recovery walk again",
            at: scenario.time(hour: 10, minute: 0)
        )
        assertCommonSnapshot(restartedWalk, previous: cancelledWalk)
        expect(restartedWalk.activeActivity == "Recovery Walk", restartedWalk, "Restarted walk should be active")
        expect(restartedWalk.todayCards.filter { $0 == "active:Recovery Walk" }.count == 1, restartedWalk, "Today should show one active recovery walk only")
        expect(restartedWalk.dayContext.allActivities.filter { $0.title == "Recovery Walk" }.count == 1, restartedWalk, "Starting same walk twice must not duplicate the stored active activity")

        scenario.completeRecoveryWalk(at: scenario.time(hour: 10, minute: 35))
        let completedWalk = scenario.snapshot(
            checkpoint: "10:35",
            action: "User completes recovery walk",
            at: scenario.time(hour: 10, minute: 35)
        )
        assertCommonSnapshot(completedWalk, previous: restartedWalk)
        expect(completedWalk.activeActivity == nil, completedWalk, "Completed walk should no longer be active")
        expect(completedWalk.completedActivities.contains("Recovery Walk"), completedWalk, "Completed recovery walk should appear in completed activities")
        expect(completedWalk.dayContext.completedRecoveryCount >= 1, completedWalk, "Recovery activity should be counted")
        expect(completedWalk.plannedActivities.contains("Strength"), completedWalk, "Poor-sleep strength workout should still be evaluated after recovery walk")
        assertRiskyStrengthIsNotBlindlyPushed(completedWalk)

        let morningWater = scenario.logWater(
            id: "water-1100",
            title: "Morning Water",
            liters: 0.8,
            at: scenario.time(hour: 11, minute: 0)
        )
        let waterLogged = scenario.snapshot(
            checkpoint: "11:00",
            action: "User logs water through Log Drinks",
            at: scenario.time(hour: 11, minute: 0)
        )
        assertCommonSnapshot(waterLogged, previous: completedWalk)
        expect(waterLogged.drinks == ["Morning Water"], waterLogged, "Water should be logged as a drink")
        expect(!waterLogged.meals.contains("Morning Water"), waterLogged, "Drink logging must not appear as Log Food")
        assertFoodAndDrinkDoNotReservePlannerTime(waterLogged, activity: morningWater)

        let lunch = scenario.logMeal(
            id: "lunch",
            title: "Lunch",
            at: scenario.time(hour: 12, minute: 30),
            calories: 720,
            protein: 45,
            carbs: 82,
            fats: 22
        )
        let lunchSnapshot = scenario.snapshot(
            checkpoint: "12:30",
            action: "User logs lunch from Today",
            at: scenario.time(hour: 12, minute: 30)
        )
        assertCommonSnapshot(lunchSnapshot, previous: waterLogged)
        expect(lunchSnapshot.meals.contains("Lunch"), lunchSnapshot, "Lunch should be included in nutrition state")
        expect(lunchSnapshot.nutritionContext.caloriesCurrent >= waterLogged.nutritionContext.caloriesCurrent + 700, lunchSnapshot, "Lunch should increase nutrition totals")
        assertFoodAndDrinkDoNotReservePlannerTime(lunchSnapshot, activity: lunch)

        scenario.deleteMeal(id: "lunch")
        let lunchDeleted = scenario.snapshot(
            checkpoint: "13:00",
            action: "User deletes lunch from Meals/logs",
            at: scenario.time(hour: 13, minute: 0)
        )
        assertCommonSnapshot(lunchDeleted, previous: lunchSnapshot)
        expect(!lunchDeleted.meals.contains("Lunch"), lunchDeleted, "Deleted lunch must disappear from Today")
        expect(lunchDeleted.deletedMealIDs.contains("lunch"), lunchDeleted, "Deleted lunch ID should be tracked as deleted")
        expect(lunchDeleted.nutritionContext.caloriesCurrent < lunchSnapshot.nutritionContext.caloriesCurrent, lunchDeleted, "Coach nutrition inputs should drop deleted lunch")
        expect(!lunchDeleted.recommendationTrace.localizedCaseInsensitiveContains("Lunch"), lunchDeleted, "Deleted lunch must not remain in recommendations")

        let customMeal = scenario.logMeal(
            id: "custom-meal",
            title: "Custom Meal",
            at: scenario.time(hour: 14, minute: 0),
            calories: 680,
            protein: 48,
            carbs: 66,
            fats: 20
        )
        let customMealSnapshot = scenario.snapshot(
            checkpoint: "14:00",
            action: "User logs custom meal from Today",
            at: scenario.time(hour: 14, minute: 0)
        )
        assertCommonSnapshot(customMealSnapshot, previous: lunchDeleted)
        expect(customMealSnapshot.meals.contains("Custom Meal"), customMealSnapshot, "Custom meal should be included in nutrition totals")
        expect(!customMealSnapshot.meals.contains("Lunch"), customMealSnapshot, "Deleted lunch must not reappear after custom meal")
        expect(customMealSnapshot.nutritionContext.caloriesCurrent >= lunchDeleted.nutritionContext.caloriesCurrent + 650, customMealSnapshot, "Custom meal should update nutrition totals")
        assertFoodAndDrinkDoNotReservePlannerTime(customMealSnapshot, activity: customMeal)

        scenario.startSauna(at: scenario.time(hour: 15, minute: 0))
        let activeSauna = scenario.snapshot(
            checkpoint: "15:00",
            action: "User starts sauna from Today",
            at: scenario.time(hour: 15, minute: 0)
        )
        assertCommonSnapshot(activeSauna, previous: customMealSnapshot)
        expect(activeSauna.activeActivity == "Sauna", activeSauna, "Today should show sauna as active")
        expect(!activeSauna.completedActivities.contains("Sauna"), activeSauna, "Active sauna must not be treated as completed")
        expect(activeSauna.coachExplanation.localizedCaseInsensitiveContains("sauna") || activeSauna.coachHeadline.localizedCaseInsensitiveContains("sauna") || activeSauna.recommendationTrace.localizedCaseInsensitiveContains("sauna") || activeSauna.activityRecommendation == "Sauna", activeSauna, "Coach should acknowledge active sauna context")

        scenario.completeSauna(at: scenario.time(hour: 15, minute: 30))
        let completedSauna = scenario.snapshot(
            checkpoint: "15:30",
            action: "User completes sauna",
            at: scenario.time(hour: 15, minute: 30)
        )
        assertCommonSnapshot(completedSauna, previous: activeSauna)
        expect(completedSauna.completedActivities.contains("Sauna"), completedSauna, "Completed sauna should appear in completed activities")
        expect(completedSauna.recoveryState == .compromised || completedSauna.recoveryState == .vulnerable, completedSauna, "Sauna should apply recovery/fatigue pressure")
        expect(
            completedSauna.tomorrowProtectionState.recommended || completedSauna.activityRecommendation == "Strength",
            completedSauna,
            "After sauna, Coach should either protect tomorrow or keep the unsafe remaining strength plan as the active decision"
        )
        expect(completedSauna.tomorrowProtectionReasons.contains("sauna impact"), completedSauna, "Sauna impact should be an explicit tomorrow-protection reason")
        expect(completedSauna.hydrationPromptVisible || completedSauna.primaryLimiter == .hydration || completedSauna.recommendationTrace.localizedCaseInsensitiveContains("fluid"), completedSauna, "Coach should increase or preserve hydration attention after sauna")
        assertTomorrowProtectionOnlyWhenJustified(completedSauna)

        let postSaunaWater = scenario.logWater(
            id: "water-1600",
            title: "Post-sauna Water",
            liters: 1.2,
            at: scenario.time(hour: 16, minute: 0)
        )
        let postSaunaWaterSnapshot = scenario.snapshot(
            checkpoint: "16:00",
            action: "User logs water after sauna",
            at: scenario.time(hour: 16, minute: 0)
        )
        assertCommonSnapshot(postSaunaWaterSnapshot, previous: completedSauna)
        expect(postSaunaWaterSnapshot.drinks.contains("Post-sauna Water"), postSaunaWaterSnapshot, "Post-sauna water should be logged as drink")
        expect(postSaunaWaterSnapshot.nutritionContext.waterCurrent > completedSauna.nutritionContext.waterCurrent, postSaunaWaterSnapshot, "Hydration should update immediately after post-sauna water")
        assertFoodAndDrinkDoNotReservePlannerTime(postSaunaWaterSnapshot, activity: postSaunaWater)

        let preStrength = scenario.snapshot(
            checkpoint: "17:00",
            action: "Conflict check before planned strength workout",
            at: scenario.time(hour: 17, minute: 0)
        )
        assertCommonSnapshot(preStrength, previous: postSaunaWaterSnapshot)
        assertRiskyStrengthIsNotBlindlyPushed(preStrength)
        expect(reservedTitles(preStrength).filter { $0 == "Strength" }.count == 1, preStrength, "Planner must not duplicate workout slots before strength")

        scenario.startPlannedStrength(at: scenario.time(hour: 18, minute: 0))
        let activeStrength = scenario.snapshot(
            checkpoint: "18:00",
            action: "User starts planned strength workout anyway",
            at: scenario.time(hour: 18, minute: 0)
        )
        assertCommonSnapshot(activeStrength, previous: preStrength)
        expect(activeStrength.activeActivity == "Strength", activeStrength, "Planned strength should transition to active")
        expect(activeStrength.todayCards.filter { $0.contains("Strength") }.count == 1, activeStrength, "Today must not show duplicate planned + active strength cards")

        scenario.stopStrengthEarly(at: scenario.time(hour: 18, minute: 10))
        let stoppedStrength = scenario.snapshot(
            checkpoint: "18:10",
            action: "User stops strength workout early after 10 minutes",
            at: scenario.time(hour: 18, minute: 10)
        )
        assertCommonSnapshot(stoppedStrength, previous: activeStrength)
        expect(stoppedStrength.partialActivities.contains("Strength"), stoppedStrength, "Stopped workout should be marked partial/short")
        expect(!stoppedStrength.completedActivities.contains("Strength"), stoppedStrength, "Stopped workout should not appear as a normal completed workout")
        expect(stoppedStrength.todayCards.contains("partial:Strength"), stoppedStrength, "Today should label stopped strength as partial")
        expect(plannerSlot(stoppedStrength, title: "Strength")?.durationMinutes == 10, stoppedStrength, "Planner reservation should be shortened to actual stopped duration")

        let dinner = scenario.logMeal(
            id: "dinner",
            title: "Dinner",
            at: scenario.time(hour: 19, minute: 0),
            calories: 820,
            protein: 52,
            carbs: 88,
            fats: 26
        )
        let dinnerSnapshot = scenario.snapshot(
            checkpoint: "19:00",
            action: "User logs dinner",
            at: scenario.time(hour: 19, minute: 0)
        )
        assertCommonSnapshot(dinnerSnapshot, previous: stoppedStrength)
        expect(dinnerSnapshot.meals.contains("Dinner"), dinnerSnapshot, "Dinner should update nutrition state")
        expect(!dinnerSnapshot.meals.contains("Lunch"), dinnerSnapshot, "Deleted lunch must not reappear after dinner")
        assertFoodAndDrinkDoNotReservePlannerTime(dinnerSnapshot, activity: dinner)

        let extraDrink = scenario.logWater(
            id: "water-2000",
            title: "Evening Drink",
            liters: 0.6,
            at: scenario.time(hour: 20, minute: 0)
        )
        let extraDrinkSnapshot = scenario.snapshot(
            checkpoint: "20:00",
            action: "User logs extra drink",
            at: scenario.time(hour: 20, minute: 0)
        )
        assertCommonSnapshot(extraDrinkSnapshot, previous: dinnerSnapshot)
        expect(extraDrinkSnapshot.drinks.contains("Evening Drink"), extraDrinkSnapshot, "Extra drink should update hydration state")
        expect(extraDrinkSnapshot.nutritionContext.waterCurrent >= extraDrinkSnapshot.nutritionContext.waterGoal, extraDrinkSnapshot, "Hydration should be at or above target after extra drink")
        expect(!extraDrinkSnapshot.hydrationPromptVisible, extraDrinkSnapshot, "Hydration prompt should disappear when water is enough")
        expect(occurrences(of: "drink", in: extraDrinkSnapshot.recommendationTrace) <= 1, extraDrinkSnapshot, "Duplicate hydration prompts should not appear")
        assertEveningRecommendationDoesNotTreatStrengthAsCurrent(extraDrinkSnapshot)
        assertFoodAndDrinkDoNotReservePlannerTime(extraDrinkSnapshot, activity: extraDrink)

        let eveningReview = scenario.snapshot(
            checkpoint: "21:00",
            action: "Coach evening review",
            at: scenario.time(hour: 21, minute: 0)
        )
        assertCommonSnapshot(eveningReview, previous: extraDrinkSnapshot)
        expect(!eveningReview.completedActivities.isEmpty, eveningReview, "Evening review should see completed/partial actions")
        expect(eveningReview.primaryLimiter != .none || eveningReview.tomorrowProtectionState.recommended, eveningReview, "Evening review should expose a clear limiter or justified tomorrow-protection recommendation")
        assertEveningRecommendationDoesNotTreatStrengthAsCurrent(eveningReview)
        assertTomorrowProtectionOnlyWhenJustified(eveningReview)
        assertNoTodayCoachContradiction(eveningReview)

        let final = scenario.snapshot(
            checkpoint: "22:30",
            action: "Final daily state",
            at: scenario.time(hour: 22, minute: 30)
        )
        assertCommonSnapshot(final, previous: eveningReview)
        expect(final.activeActivity == nil, final, "No active activity should remain at final state")
        expect(final.completedActivities.contains("Recovery Walk"), final, "Final Today state should include completed recovery walk")
        expect(final.completedActivities.contains("Sauna"), final, "Final Today state should include completed sauna")
        expect(!final.completedActivities.contains("Strength"), final, "Final Today state should not list stopped strength as normal completed")
        expect(final.partialActivities.contains("Strength"), final, "Final Today state should include partial/stopped strength")
        expect(!final.meals.contains("Lunch"), final, "Deleted lunch must not reappear in final state")
        expect(final.meals.contains("Breakfast") && final.meals.contains("Custom Meal") && final.meals.contains("Dinner"), final, "Final meals should match actual logged meals")
        expect(final.drinks.count == 3, final, "Final drinks should include all logged drinks")
        expect(reservedTitles(final).allSatisfy { $0 != "Lunch" && $0 != "Breakfast" && $0 != "Custom Meal" && $0 != "Dinner" }, final, "Planner should contain only valid final reservations")
        expect(final.primaryLimiter == .sleep, final, "Final state should expose sleep as the recovery limiter")
        expect(final.coachHeadline.localizedCaseInsensitiveContains("recovery"), final, "Final Coach headline should keep recovery as the visible owner")
        expect(final.tomorrowProtectionReasons.contains("sauna impact"), final, "Final trace should retain sauna impact as context even when recovery owns")
        assertEveningRecommendationDoesNotTreatStrengthAsCurrent(final)
        assertNoTodayCoachContradiction(final)
    }

    private func assertCommonSnapshot(
        _ snapshot: CoachDebugSnapshot,
        previous: CoachDebugSnapshot? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        CoachScenarioSnapshotPrinter.printCheckpoint(
            name: snapshot.checkpoint,
            time: snapshot.now,
            input: snapshot.inputSnapshot,
            output: snapshot.outputSnapshot,
            audit: snapshot.decisionAudit
        )
        XCTContext.runActivity(named: "Checkpoint \(snapshot.checkpoint) input/output snapshot") { activity in
            let attachment = XCTAttachment(string: snapshot.formattedCheckpointSnapshot)
            attachment.name = "Today Coach Pipeline Snapshot"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        expect(!snapshot.todayCards.isEmpty, snapshot, "Today cards should be rebuilt at every checkpoint", file: file, line: line)
        expect(!snapshot.coachHeadline.isEmpty, snapshot, "Coach headline should be present at every checkpoint", file: file, line: line)
        expect(!snapshot.coachExplanation.isEmpty, snapshot, "Coach explanation should be present at every checkpoint", file: file, line: line)
        expect(snapshot.readinessScore >= 0, snapshot, "Readiness score should be available", file: file, line: line)
        expect(snapshot.confidence >= 0 && snapshot.confidence <= 1, snapshot, "Coach confidence should be normalized", file: file, line: line)
        expect(!snapshot.decisionTrace.isEmpty, snapshot, "Decision trace should explain Coach decision", file: file, line: line)
        expect(!snapshot.plannerTrace.debugDescription.isEmpty, snapshot, "Planner trace should explain reservations", file: file, line: line)
        expect(!snapshot.recommendationTrace.isEmpty, snapshot, "Recommendation trace should explain next action", file: file, line: line)
        expect(Set(snapshot.plannerTrace.reservedSlots.map(\.activityID)).count == snapshot.plannerTrace.reservedSlots.count, snapshot, "Planner reserved slots should not duplicate activity IDs", file: file, line: line)
        expect(snapshot.meals.allSatisfy { $0 != "Water" && !$0.localizedCaseInsensitiveContains("Drink") }, snapshot, "Drinks must not leak into meal list", file: file, line: line)
        expect(!snapshot.meals.contains("Lunch") || !snapshot.deletedMealIDs.contains("lunch"), snapshot, "Deleted meals must be excluded from meals", file: file, line: line)
        expect(snapshot.readinessBreakdown.final == snapshot.readinessScore, snapshot, "Readiness final score should match displayed readiness", file: file, line: line)
        expect(snapshot.readinessBreakdown.cap == nil || snapshot.readinessBreakdown.capReason != nil, snapshot, "Readiness cap must explain its cap reason", file: file, line: line)
        assertTerminalStatesAreExclusive(snapshot, file: file, line: line)

        if let previous {
            let deletedIDs = previous.deletedMealIDs.union(snapshot.deletedMealIDs)
            if deletedIDs.contains("lunch") {
                expect(!snapshot.meals.contains("Lunch"), snapshot, "Deleted lunch should stay excluded across later checkpoints", file: file, line: line)
            }
        }
    }

    private func assertCoachDoesNotInventSleep(
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = "\(snapshot.coachHeadline) \(snapshot.coachExplanation) \(snapshot.recommendationTrace)"
        expect(!text.localizedCaseInsensitiveContains("slept well"), snapshot, "Coach must not invent positive sleep when sleep data is missing", file: file, line: line)
        expect(!text.localizedCaseInsensitiveContains("sleep is strong"), snapshot, "Coach must not claim strong sleep before sync", file: file, line: line)
    }

    private func assertRiskyStrengthIsNotBlindlyPushed(
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard snapshot.plannedActivities.contains("Strength") || snapshot.activeActivity == "Strength" else { return }
        let text = "\(snapshot.coachHeadline) \(snapshot.coachExplanation) \(snapshot.recommendationTrace)".lowercased()
        let hasCaution = text.contains("sleep") ||
            text.contains("recovery") ||
            text.contains("easy") ||
            text.contains("control") ||
            text.contains("adjust") ||
            text.contains("risk") ||
            text.contains("shorten") ||
            snapshot.primaryLimiter == .sleep ||
            snapshot.primaryLimiter == .recovery ||
            snapshot.primaryLimiter == .trainingReadiness
        expect(hasCaution, snapshot, "Coach should not blindly push hard strength after poor sleep/sauna/recovery load", file: file, line: line)
    }

    private func assertFoodAndDrinkDoNotReservePlannerTime(
        _ snapshot: CoachDebugSnapshot,
        activity: PlannedActivity,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        expect(!activity.blocksPlannerTime, snapshot, "\(activity.title) should not block planner time", file: file, line: line)
        expect(snapshot.plannerTrace.ignoredFoodAndDrinkIDs.contains(activity.id), snapshot, "\(activity.title) should be ignored by planner reservations", file: file, line: line)
        expect(!snapshot.plannerTrace.reservedSlots.contains { $0.activityID == activity.id }, snapshot, "\(activity.title) should not create planner reservation", file: file, line: line)
        let conflictLine = snapshot.plannerTrace.conflictChecks.first { $0.contains(activity.title) } ?? ""
        expect(conflictLine.contains("conflict=false"), snapshot, "\(activity.title) should not create planner time conflict", file: file, line: line)
    }

    private func assertTomorrowProtectionOnlyWhenJustified(
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard snapshot.tomorrowProtectionState.recommended || snapshot.tomorrowProtectionState.active else { return }
        let justification = "\(snapshot.decisionTrace) \(snapshot.coachExplanation) \(snapshot.recommendationTrace)".lowercased()
        let hasThresholdReason = justification.contains("sleep") ||
            justification.contains("recovery") ||
            justification.contains("fatigue") ||
            justification.contains("tomorrow") ||
            justification.contains("sauna") ||
            snapshot.recoveryState == .compromised ||
            snapshot.primaryLimiter == .sleep ||
            snapshot.primaryLimiter == .recovery
        expect(hasThresholdReason, snapshot, "Tomorrow protection should only be recommended or active when thresholds justify it", file: file, line: line)
    }

    private func assertNoTodayCoachContradiction(
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = "\(snapshot.coachHeadline) \(snapshot.coachExplanation) \(snapshot.recommendationTrace)".lowercased()
        if let active = snapshot.activeActivity?.lowercased() {
            expect(!text.contains("\(active) completed"), snapshot, "Coach explanation should not call an active activity completed", file: file, line: line)
        }
        for meal in snapshot.deletedMealIDs {
            expect(!text.contains(meal.lowercased()), snapshot, "Coach explanation should not reference deleted meal IDs", file: file, line: line)
        }
    }

    private func assertEveningRecommendationDoesNotTreatStrengthAsCurrent(
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard snapshot.partialActivities.contains("Strength") else { return }
        let recommendation = snapshot.activityRecommendation.lowercased()
        let isHistoricalStrength = recommendation.contains("historical") ||
            recommendation.contains("partial") ||
            recommendation == "wind down" ||
            recommendation == "recovery" ||
            recommendation == "sleep preparation" ||
            recommendation == "none"
        expect(isHistoricalStrength, snapshot, "After stopped strength, activityRecommendation must not present Strength as the current activity", file: file, line: line)
    }

    private func assertTerminalStatesAreExclusive(
        _ snapshot: CoachDebugSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let completed = Set(snapshot.completedActivities)
        let partial = Set(snapshot.partialActivities)
        let cancelled = Set(snapshot.cancelledActivities)
        expect(completed.isDisjoint(with: partial), snapshot, "Activities must not be both completed and partial", file: file, line: line)
        expect(completed.isDisjoint(with: cancelled), snapshot, "Activities must not be both completed and cancelled", file: file, line: line)
        expect(partial.isDisjoint(with: cancelled), snapshot, "Activities must not be both partial and cancelled", file: file, line: line)
    }

    private func reservedTitles(_ snapshot: CoachDebugSnapshot) -> [String] {
        snapshot.plannerTrace.reservedSlots.map(\.title)
    }

    private func plannerSlot(_ snapshot: CoachDebugSnapshot, title: String) -> PlannerDebugTrace.ReservedSlot? {
        snapshot.plannerTrace.reservedSlots.first { $0.title == title }
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

    private func expect(
        _ condition: @autoclosure () -> Bool,
        _ snapshot: CoachDebugSnapshot,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !condition() else { return }
        XCTFail(
            """
            Checkpoint failed: \(snapshot.checkpoint)
            User action: \(snapshot.action)
            Expected: \(expected)
            Actual: \(snapshot.outputSnapshot)

            \(snapshot.formattedFailureAudit)

            Failed checkpoint snapshot:
            \(snapshot.formattedCheckpointSnapshot)

            Actual snapshot:
            \(snapshot.debugDescription)
            Why Coach made the decision:
            \(snapshot.decisionTrace)
            """,
            file: file,
            line: line
        )
    }
}
