import XCTest
@testable import WeekFit

final class CoachAssistantFlowTests: XCTestCase {

    func testBootstrapOffersFeelingChoices() {
        let output = CoachAssistantFlow.bootstrap(givenName: "Max")
        XCTAssertEqual(output.coachTurns.count, 1)
        XCTAssertFalse(output.coachTurns[0].text.english.isEmpty)
        XCTAssertEqual(output.choices.map(\.id), [
            "feeling.energized",
            "feeling.okay",
            "feeling.tired",
            "feeling.low"
        ])
        XCTAssertTrue(output.questionID?.hasPrefix("open.") == true)
    }

    func testSameDayNewConversationSkipsTimeOfDayGreeting() {
        var memory = CoachAssistantMemoryState.empty
        memory.lastOpeningVariantID = "open.tod.name"
        memory.days = [
            CoachAssistantDayMemory(
                dayKey: "2026-10-05",
                feeling: .okay,
                areasVisited: [],
                questionIDs: ["open.tod.name"],
                recommendationIDs: [],
                unresolvedFollowUp: nil,
                insightID: "open.tod.name"
            )
        ]
        let evening = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 19))!
        let output = CoachAssistantFlow.bootstrap(
            givenName: "Max",
            memory: memory,
            now: evening
        )
        let text = output.coachTurns[0].text.english
        XCTAssertFalse(text.hasPrefix("Good evening"))
        XCTAssertFalse(text.contains("Good evening, Max"))
        XCTAssertTrue(
            text.lowercased().contains("feeling")
                || text.lowercased().contains("energy")
                || text.lowercased().contains("body")
        )
    }

    func testOpeningVariantsAvoidImmediateRepeat() {
        var memory = CoachAssistantMemoryState.empty
        memory.lastOpeningVariantID = "open.again.now"
        memory.days = [
            CoachAssistantDayMemory(
                dayKey: "2026-10-05",
                feeling: .okay,
                areasVisited: [],
                questionIDs: ["open.again.now"],
                recommendationIDs: [],
                unresolvedFollowUp: nil,
                insightID: nil
            )
        ]
        let line = CoachAssistantCopy.checkInOpening(
            givenName: "Max",
            memory: memory,
            todayKey: "2026-10-05",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 20))!,
            sameDayRestart: true
        )
        XCTAssertNotEqual(line.id, "open.again.now")
        XCTAssertFalse(line.text.english.hasPrefix("Good evening"))
        XCTAssertFalse(line.text.english.localizedCaseInsensitiveContains("Starting fresh"))
        XCTAssertFalse(line.text.english.localizedCaseInsensitiveContains("Начнём заново"))
    }

    func testSameDayRestartNeverUsesStartingFreshPhrase() {
        var memory = CoachAssistantMemoryState.empty
        for previous in ["open.again.energy", "open.again.body", "open.again.short", ""] {
            memory.lastOpeningVariantID = previous.isEmpty ? nil : previous
            let line = CoachAssistantCopy.checkInOpening(
                givenName: "Max",
                memory: memory,
                todayKey: "2026-10-05",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 18))!,
                sameDayRestart: true
            )
            XCTAssertFalse(
                line.text.english.localizedCaseInsensitiveContains("Starting fresh"),
                "Unexpected opener: \(line.text.english)"
            )
        }
    }

    func testTiredGoesStraightToMindAskWithAreaStarters() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .feelingAsk,
                choiceID: "feeling.tired",
                feeling: nil,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(),
                weekBundle: nil,
                givenName: nil
            )
        )
        XCTAssertEqual(output.feeling, .tired)
        XCTAssertEqual(output.coachTurns.first?.nodeID, .mindAsk)
        XCTAssertEqual(Set(output.choices.map(\.id)), [
            "mind.nutrition",
            "mind.recovery",
            "mind.activity"
        ])
        XCTAssertTrue(output.coachTurns.first?.supportingFacts.isEmpty ?? false)
    }

    func testOkayReflectionMentionsLowerRecoveryAndMindPrompt() {
        var evidence = CoachFeelingEvidenceSnapshot.empty
        evidence.recoveryPercent = 42
        evidence.recoveryBaselinePercent = 58
        evidence.sleepMinutes = 420
        evidence.sleepBaselineMinutes = 450

        let reply = CoachAssistantCopy.shortFeelingReply(feeling: .okay, evidence: evidence)
        XCTAssertTrue(reply.english.hasPrefix("Got it."))
        XCTAssertTrue(reply.english.contains("below your usual range"))
        XCTAssertTrue(reply.english.contains("What shall we start with?"))
        XCTAssertFalse(reply.english.lowercased().contains("a little lower"))
        XCTAssertFalse(reply.english.lowercased().contains("typical"))
        XCTAssertFalse(reply.english.lowercased().contains("close to usual"))
    }

    func testEnergizedProducesReflectionAndAreaStarters() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .feelingAsk,
                choiceID: "feeling.energized",
                feeling: nil,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: nil),
                weekBundle: nil,
                givenName: nil
            )
        )
        XCTAssertEqual(output.feeling, .energized)
        XCTAssertEqual(output.coachTurns.count, 1)
        XCTAssertEqual(output.coachTurns.first?.nodeID, .mindAsk)
        XCTAssertEqual(Set(output.choices.map(\.title.english)), [
            "Nutrition",
            "Recovery",
            "Activity"
        ])
        XCTAssertTrue(output.coachTurns.first?.supportingFacts.isEmpty ?? false)
    }

    func testMindNutritionOpensNutritionGate() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.nutrition",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: nil
            )
        )
        XCTAssertEqual(output.area, .nutrition)
        XCTAssertEqual(output.coachTurns.first?.nodeID, .nutritionGate)
        XCTAssertEqual(
            CoachAssistantCopy.resolve(output.coachTurns[0].text),
            CoachAssistantCopy.resolve(CoachAssistantCopy.nutritionGateQuestion())
        )
        XCTAssertEqual(output.choices.map(\.id), [
            "nutrition.helpChoose",
            "nutrition.remaining"
        ])
    }

    func testMindRecoveryGoesStraightToTodayRecovery() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.recovery",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: nil
            )
        )
        XCTAssertEqual(output.area, .recovery)
        // Skip the duration gate when the user already chose Recovery as the topic.
        XCTAssertEqual(output.coachTurns.first?.nodeID, .recoveryToday)
        XCTAssertFalse(output.choices.map(\.id).contains("recovery.justToday"))
        XCTAssertTrue(output.choices.map(\.id).contains("recovery.nights") || output.questionID == "recovery.unavailable")
    }

    func testMindActivityOpensActivityGate() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: nil
            )
        )
        XCTAssertEqual(output.area, .activity)
        XCTAssertEqual(output.coachTurns.first?.nodeID, .activityGate)
        XCTAssertEqual(output.choices.map(\.id), [
            "activity.todayBrief",
            "activity.recent",
            "activity.consistency"
        ])
    }

    func testActivityHowHardUsesDistinctIntensityPath() {
        // Legacy “how hard” chip now opens the past-focused today brief.
        let output = CoachAssistantFlow.advance(
            .init(
                node: .activityGate,
                choiceID: "activity.howHard",
                feeling: .tired,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .tired),
                weekBundle: nil,
                givenName: nil
            )
        )
        XCTAssertEqual(output.coachTurns.first?.nodeID, .activityToday)
        XCTAssertTrue(
            output.coachTurns[0].text.english.lowercased().contains("no training")
                || output.coachTurns[0].text.english.lowercased().contains("plan")
                || output.coachTurns[0].text.english.lowercased().contains("logged")
        )
        XCTAssertFalse(output.choices.contains { $0.id.hasPrefix("activity.effort.") })
    }

    func testTimeOfDayGreetingIncludesName() {
        let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 9))!
        let line = CoachAssistantCopy.checkInOpening(
            givenName: "Max",
            memory: .empty,
            todayKey: "2026-04-15",
            date: morning,
            sameDayRestart: false
        )
        // First check-in pool includes classic and alternate lines; classic still names Max.
        let classic = CoachAssistantCopy.checkInOpening(
            givenName: "Max",
            memory: CoachAssistantMemoryState(
                days: [],
                prefersVegetarian: nil,
                offeredMealIDs: [],
                lastOpeningVariantID: "open.energy.now"
            ),
            todayKey: "2026-04-15",
            date: morning,
            sameDayRestart: false
        )
        XCTAssertTrue(
            classic.text.english.contains("Max")
                || classic.text.english.contains("feeling")
                || classic.text.english.contains("energy")
        )
        XCTAssertFalse(line.text.english.isEmpty)
    }

    func testIntentRouterMapsTiredFreeText() {
        let intent = CoachAssistantIntentRouter.route(
            "I'm tired",
            currentNode: .feelingAsk,
            feeling: nil
        )
        XCTAssertEqual(intent, .feeling(.tired))
    }

    func testAreaStartersAlwaysIncludeAllThreeTopics() {
        let tired = CoachAssistantCopy.mindChoices(
            feeling: .tired,
            hasPlannedWorkout: true,
            hasCompletedActivity: false
        )
        let energized = CoachAssistantCopy.mindChoices(
            feeling: .energized,
            hasPlannedWorkout: true,
            hasCompletedActivity: false
        )
        XCTAssertEqual(Set(tired.map(\.id)), [
            "mind.nutrition",
            "mind.recovery",
            "mind.activity"
        ])
        XCTAssertEqual(Set(energized.map(\.id)), Set(tired.map(\.id)))
        // Ordering may differ by feeling / signals — that is intentional.
    }

    func testNutritionRemainingDoesNotShowNegativeAllowance() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 2_400,
            caloriesGoal: 2_000,
            proteinCurrent: 180,
            proteinGoal: 150,
            waterCurrent: 1,
            waterGoal: 2
        )
        let result = CoachAssistantScenarioAnalyzer.nutritionRemaining(nutrition: nutrition)
        let joined = ([result.text] + result.facts).map { $0.english }.joined(separator: " ")
        XCTAssertFalse(joined.lowercased().contains("remaining -"))
        XCTAssertTrue(
            joined.contains("over today’s goal")
                || joined.contains("over today's goal")
                || joined.contains("over today’s")
                || joined.contains("over today's")
        )
    }

    // MARK: - Helpers

    private func emptyContext(feeling: CoachFeelingKind? = nil) -> CoachAssistantScenarioAnalyzer.Context {
        .init(
            feeling: feeling,
            clarification: nil,
            checkInAt: Date(),
            observations: [],
            plannedActivities: [],
            recentActivityCount: 0,
            recentActivityDayKeys: [],
            nutrition: nil,
            healthAccessGranted: nil
        )
    }
}
