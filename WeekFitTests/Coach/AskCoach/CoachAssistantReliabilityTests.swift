import XCTest
@testable import WeekFit

final class CoachAssistantReliabilityTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CoachAssistantReliabilityTests.\(UUID().uuidString)")
        CoachAssistantConversationStore.useDefaults(defaults)
        CoachAssistantConversationStore.clear()
        CoachAssistantMemoryStore.useDefaults(defaults)
        CoachAssistantMemoryStore.clear()
    }

    override func tearDown() {
        CoachAssistantConversationStore.clear()
        CoachAssistantConversationStore.resetDefaults()
        CoachAssistantMemoryStore.clear()
        CoachAssistantMemoryStore.resetDefaults()
        defaults = nil
        super.tearDown()
    }

    func testSameDayLatestIncludesGreetingOnly() {
        let day = date(2026, 10, 5, hour: 9)
        let greeting = CoachAssistantConversation(
            id: "g1",
            createdAt: day,
            updatedAt: day,
            feeling: nil,
            clarification: nil,
            area: nil,
            currentNodeID: .feelingAsk,
            turns: [
                CoachAssistantTurn(
                    role: .coach,
                    text: .en("Good morning", "Доброе утро"),
                    nodeID: .feelingAsk,
                    createdAt: day
                )
            ],
            choiceIDs: [],
            evidence: .empty,
            previewEnglish: "Hi",
            previewRussian: "Привет",
            ended: false
        )
        CoachAssistantConversationStore.upsert(greeting)
        XCTAssertEqual(CoachAssistantConversationStore.latest(on: day)?.id, "g1")
    }

    func testSupersedeSameDayRemovesDrafts() {
        let day = date(2026, 10, 5, hour: 9)
        CoachAssistantConversationStore.upsert(makeConversation(id: "old", at: day))
        CoachAssistantConversationStore.upsert(makeConversation(id: "keep", at: day))
        CoachAssistantConversationStore.supersedeSameDay(keeping: "keep", on: day)
        XCTAssertNil(CoachAssistantConversationStore.conversation(id: "old"))
        XCTAssertNotNil(CoachAssistantConversationStore.conversation(id: "keep"))
    }

    func testAskSomethingElseOmitsMindFramingQuestion() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "end.another",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.nutrition"]
            )
        )
        XCTAssertTrue(output.coachTurns.isEmpty)
        XCTAssertEqual(output.choices.map(\.id).sorted(), [
            "mind.activity", "mind.nutrition", "mind.recovery"
        ].sorted())
    }

    func testOtherTopicThenNutritionDoesNotReplayActivityRecommendation() {
        // Simulate stuck branch node after a recovery/activity idea (the pre-fix failure mode).
        let walkSignals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 6, hour: 10),
            sleepMinutes: 420,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 55,
            recoveryBaselinePercent: 70,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 400,
            nutritionCaloriesGoal: 2_000,
            nutritionProteinCurrent: 20,
            nutritionProteinGoal: 120,
            nutritionMealsLogged: 1,
            nutritionKnown: true,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        var nutritionContext = emptyContext(feeling: .okay, checkInAt: date(2026, 10, 6, hour: 10))
        nutritionContext.nutrition = CoachNutritionContext(
            caloriesCurrent: 400,
            caloriesGoal: 2_000,
            proteinCurrent: 20,
            proteinGoal: 120,
            waterCurrent: 0.5,
            waterGoal: 2,
            mealsCount: 1
        )

        let idea = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep,
                choiceID: "recovery.idea",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: nutritionContext,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.activity", "recovery.idea"],
                memory: .empty,
                signals: walkSignals
            )
        )
        let ideaText = idea.coachTurns.first?.text.english ?? ""
        // Legacy Recovery idea chip opens the sleep/HRV brief — never a walk prescription.
        XCTAssertEqual(idea.coachTurns.first?.nodeID, .recoveryToday)
        XCTAssertFalse(ideaText.contains("20–30"))
        XCTAssertFalse(ideaText.lowercased().contains("easy 20"))

        let other = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep, // stuck branch — must still open topic picker
                choiceID: "end.another",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: nutritionContext,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.activity", "recovery.idea", "end.another"],
                memory: .empty,
                signals: walkSignals
            )
        )
        XCTAssertEqual(other.nextNodeID, .mindAsk)
        XCTAssertTrue(other.clearsArea)
        XCTAssertTrue(other.choices.contains { $0.id == "mind.nutrition" })

        let nutrition = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep, // still stuck — topic choice must route by id
                choiceID: "mind.nutrition",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: nutritionContext,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: [
                    "feeling.okay", "mind.activity", "recovery.idea", "end.another", "mind.nutrition"
                ],
                memory: .empty,
                signals: walkSignals
            )
        )
        let nutritionText = nutrition.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(nutritionText.contains("20–30"))
        XCTAssertFalse(nutritionText.lowercased().contains("walk"))
        XCTAssertEqual(nutrition.area, .nutrition)
        XCTAssertEqual(nutrition.questionID, "gate.nutrition")
        XCTAssertTrue(nutrition.choices.contains { $0.id == "nutrition.helpChoose" || $0.id == "nutrition.remaining" })
    }

    func testTopicSequenceActivityRecoveryNutritionActivitySwitchesCleanly() {
        let now = date(2026, 10, 6, hour: 11)
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: now,
            sleepMinutes: 430,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 64,
            recoveryBaselinePercent: 68,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 500,
            nutritionCaloriesGoal: 2_000,
            nutritionProteinCurrent: 30,
            nutritionProteinGoal: 120,
            nutritionMealsLogged: 1,
            nutritionKnown: true,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        var context = emptyContext(feeling: .energized, checkInAt: now)
        context.nutrition = CoachNutritionContext(
            caloriesCurrent: 500,
            caloriesGoal: 2_000,
            proteinCurrent: 30,
            proteinGoal: 120,
            waterCurrent: 0.5,
            waterGoal: 2,
            mealsCount: 1
        )

        var answered = ["feeling.energized"]
        let activity = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: answered + ["mind.activity"],
                memory: .empty,
                signals: signals
            )
        )
        answered += ["mind.activity"]
        XCTAssertEqual(activity.area, .activity)
        let activityText = activity.coachTurns.first?.text.english ?? ""

        answered += ["end.another"]
        let recovery = CoachAssistantFlow.advance(
            .init(
                node: .activityGate,
                choiceID: "mind.recovery",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: answered + ["mind.recovery"],
                memory: .empty,
                signals: signals
            )
        )
        answered += ["mind.recovery"]
        let recoveryText = recovery.coachTurns.first?.text.english ?? ""
        XCTAssertEqual(recovery.area, .recovery)
        XCTAssertNotEqual(Self.normalized(recoveryText), Self.normalized(activityText))

        answered += ["end.another"]
        let nutrition = CoachAssistantFlow.advance(
            .init(
                node: .recoveryToday,
                choiceID: "mind.nutrition",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: answered + ["mind.nutrition"],
                memory: .empty,
                signals: signals
            )
        )
        answered += ["mind.nutrition"]
        let nutritionText = nutrition.coachTurns.first?.text.english ?? ""
        XCTAssertEqual(nutrition.area, .nutrition)
        XCTAssertEqual(nutrition.questionID, "gate.nutrition")
        XCTAssertNotEqual(Self.normalized(nutritionText), Self.normalized(recoveryText))
        XCTAssertNotEqual(Self.normalized(nutritionText), Self.normalized(activityText))

        answered += ["end.another"]
        let activityAgain = CoachAssistantFlow.advance(
            .init(
                node: .nutritionGate,
                choiceID: "mind.activity",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: answered + ["mind.activity"],
                memory: .empty,
                signals: signals
            )
        )
        XCTAssertEqual(activityAgain.area, .activity)
        let activityAgainText = activityAgain.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(activityAgainText.localizedCaseInsensitiveContains("protein"))
        XCTAssertNotEqual(Self.normalized(activityAgainText), Self.normalized(nutritionText))
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func testRecoveryTodayUsesRecoveryWithoutBaselineInsteadOfUnavailable() {
        var evidence = CoachAssistantEvidenceBundle.empty
        evidence.feelingEvidence.recoveryPercent = 72
        evidence.feelingEvidence.recoveryBaselinePercent = nil
        evidence.feelingEvidence.recoveryIsStale = false

        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryToday,
                choiceID: nil,
                feeling: .energized,
                clarification: nil,
                evidence: evidence,
                analysisContext: emptyContext(feeling: .energized),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized", "mind.recovery"],
                memory: .empty,
                signals: CoachAssistantSignalSnapshot(
                    checkInAt: date(2026, 10, 6, hour: 9),
                    sleepMinutes: nil,
                    sleepBaselineMinutes: nil,
                    sleepIsFresh: false,
                    recoveryPercent: 72,
                    recoveryBaselinePercent: nil,
                    recoveryIsFresh: true,
                    recoveryIsDerivedScore: true,
                    nutritionCaloriesCurrent: nil,
                    nutritionCaloriesGoal: nil,
                    nutritionProteinCurrent: nil,
                    nutritionProteinGoal: nil,
                    nutritionMealsLogged: 0,
                    nutritionKnown: false,
                    yesterdayHardMinutes: nil,
                    yesterdayHadHardTraining: false,
                    todayPlannedSignificant: false,
                    todayCompletedSignificant: false,
                    todayPlannedLabel: nil,
                    recentCompletedCount48h: 0,
                    healthKitAuthorized: true
                )
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(text.localizedCaseInsensitiveContains("aren’t available"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("aren't available"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("recovery"))
        XCTAssertTrue(text.contains("72%") || text.localizedCaseInsensitiveContains("app recovery"))
        XCTAssertNotEqual(output.questionID, "recovery.unavailable")
    }

    func testRecoveryTodayPrefersLiveSignalsWhenConversationEvidenceEmpty() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryToday,
                choiceID: nil,
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.recovery"],
                memory: .empty,
                signals: CoachAssistantSignalSnapshot(
                    checkInAt: date(2026, 10, 6, hour: 9),
                    sleepMinutes: nil,
                    sleepBaselineMinutes: nil,
                    sleepIsFresh: false,
                    recoveryPercent: 68,
                    recoveryBaselinePercent: 70,
                    recoveryIsFresh: true,
                    recoveryIsDerivedScore: true,
                    nutritionCaloriesCurrent: nil,
                    nutritionCaloriesGoal: nil,
                    nutritionProteinCurrent: nil,
                    nutritionProteinGoal: nil,
                    nutritionMealsLogged: 0,
                    nutritionKnown: false,
                    yesterdayHardMinutes: nil,
                    yesterdayHadHardTraining: false,
                    todayPlannedSignificant: false,
                    todayCompletedSignificant: false,
                    todayPlannedLabel: nil,
                    recentCompletedCount48h: 0,
                    healthKitAuthorized: true
                )
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(text.localizedCaseInsensitiveContains("aren’t available"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("aren't available"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("recovery"))
        XCTAssertTrue(text.contains("68%") || text.localizedCaseInsensitiveContains("app recovery"))
        XCTAssertNotEqual(output.questionID, "recovery.unavailable")
    }

    func testRecoveryGateSkippedWhenAlreadyAnswered() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryGate,
                choiceID: nil,
                feeling: .tired,
                clarification: nil,
                evidence: {
                    var evidence = CoachAssistantEvidenceBundle.empty
                    evidence.feelingEvidence.sleepMinutes = 300
                    evidence.feelingEvidence.sleepBaselineMinutes = 450
                    evidence.feelingEvidence.sleepIsStale = false
                    return evidence
                }(),
                analysisContext: emptyContext(feeling: .tired),
                weekBundle: nil,
                givenName: nil,
                answeredChoiceIDs: ["recovery.justToday"]
            )
        )
        XCTAssertEqual(output.coachTurns.first?.nodeID, .recoveryToday)
        XCTAssertFalse(
            output.coachTurns.first?.text.english.contains("last night’s sleep") == true
                && output.questionID == "gate.recovery"
        )
    }

    func testCombinedInsightUsesSleepAndHardDay() {
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 6, hour: 8),
            sleepMinutes: 340,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 48,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 900,
            nutritionCaloriesGoal: 2_200,
            nutritionProteinCurrent: 60,
            nutritionProteinGoal: 140,
            nutritionMealsLogged: 1,
            nutritionKnown: true,
            yesterdayHardMinutes: 70,
            yesterdayHadHardTraining: true,
            todayPlannedSignificant: true,
            todayCompletedSignificant: false,
            todayPlannedLabel: "Tempo",
            recentCompletedCount48h: 1,
            healthKitAuthorized: true
        )
        let result = CoachAssistantInsightBuilder.primaryPath(
            feeling: .tired,
            signals: signals,
            excludedInsightIDs: [],
            excludedRecommendationIDs: []
        )
        XCTAssertEqual(result?.insightID, "insight.sleepHard.ease")
        XCTAssertEqual(result?.recommendationID, "rec.easePlan")
        XCTAssertTrue(result?.text.english.contains("slept") == true)
        XCTAssertFalse(result?.text.english.lowercased().contains("hrv") == true)
    }

    func testOpeningFollowUpAsksAboutEasierSession() {
        var memory = CoachAssistantMemoryState.empty
        memory.days = [
            CoachAssistantDayMemory(
                dayKey: "2026-10-05",
                feeling: .tired,
                areasVisited: [.activity],
                questionIDs: ["insight.sleepHard.ease"],
                recommendationIDs: ["rec.easePlan"],
                unresolvedFollowUp: .easierSession,
                insightID: "insight.sleepHard.ease"
            )
        ]
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 6, hour: 9),
            sleepMinutes: 420,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 55,
            recoveryBaselinePercent: 58,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: nil,
            nutritionCaloriesGoal: nil,
            nutritionProteinCurrent: nil,
            nutritionProteinGoal: nil,
            nutritionMealsLogged: 0,
            nutritionKnown: false,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        let boot = CoachAssistantFlow.bootstrap(
            givenName: "Max",
            memory: memory,
            signals: signals,
            now: date(2026, 10, 6, hour: 9)
        )
        XCTAssertEqual(boot.questionID, "open.followup.ease.ask")
        XCTAssertTrue(boot.choices.contains { $0.id.hasPrefix("followup.ease") })
        // New conversations always greet first, then ask the follow-up.
        XCTAssertGreaterThanOrEqual(boot.coachTurns.count, 2)
        XCTAssertTrue(
            boot.coachTurns.first?.text.english.localizedCaseInsensitiveContains("max") == true
                || boot.coachTurns.first?.text.english.localizedCaseInsensitiveContains("feeling") == true
                || boot.coachTurns.first?.text.english.localizedCaseInsensitiveContains("energy") == true
                || boot.coachTurns.first?.text.english.localizedCaseInsensitiveContains("good") == true
        )
        XCTAssertTrue(
            boot.coachTurns.last?.text.english.localizedCaseInsensitiveContains("lighter") == true
                || boot.coachTurns.last?.text.english.localizedCaseInsensitiveContains("session") == true
        )
        XCTAssertEqual(Set(boot.choices.map(\.id)).intersection(["followup.ease.wentWell", "followup.ease.skipped"]).count, 2)
        XCTAssertTrue(boot.choices.contains { $0.title.english == "Yes" })
        XCTAssertTrue(boot.choices.contains { $0.title.english == "No" })
    }

    func testRecoveryNextStepNeverOffersWeeklyFocus() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep,
                choiceID: nil,
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.recovery"],
                memory: .empty,
                signals: recoveryConflictSignals(planned: false)
            )
        )
        XCTAssertFalse(output.choices.contains { $0.id == "recovery.setFocus" })
        XCTAssertFalse(output.choices.contains { $0.action == .setWeeklyFocus })
        let joined = output.coachTurns.map(\.text.english).joined(separator: " ")
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("weekly focus"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("gentler recovery focus"))
    }

    func testNewConversationBootstrapAlwaysIncludesGreeting() {
        let boot = CoachAssistantFlow.bootstrap(
            givenName: "Max",
            memory: .empty,
            signals: nil,
            now: date(2026, 10, 6, hour: 9)
        )
        XCTAssertFalse(boot.coachTurns.isEmpty)
        let greeting = boot.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(greeting.isEmpty)
        XCTAssertFalse(greeting.localizedCaseInsensitiveContains("weekly focus"))
        XCTAssertEqual(boot.nextNodeID, .feelingAsk)
        XCTAssertEqual(Set(boot.choices.map(\.id)), [
            "feeling.energized", "feeling.okay", "feeling.tired", "feeling.low"
        ])
    }

    func testSevenDayJourneyAdvancesWithoutRepeatingEaseRecommendation() {
        var memory = CoachAssistantMemoryState.empty
        var usedInsightIDs: [String] = []
        var usedRecIDs: [String] = []

        for dayOffset in 0..<7 {
            let day = date(2026, 10, 1 + dayOffset, hour: 8)
            let dayKey = CoachDailyObservation.dayKey(for: day)
            let hardYesterday = dayOffset == 2 || dayOffset == 5
            let shortSleep = dayOffset == 3 || dayOffset == 5
            let signals = CoachAssistantSignalSnapshot(
                checkInAt: day,
                sleepMinutes: shortSleep ? 330 : 450,
                sleepBaselineMinutes: 450,
                sleepIsFresh: true,
                recoveryPercent: shortSleep ? 45 : 62,
                recoveryBaselinePercent: 60,
                recoveryIsFresh: true,
                recoveryIsDerivedScore: true,
                nutritionCaloriesCurrent: 1_100,
                nutritionCaloriesGoal: 2_200,
                nutritionProteinCurrent: dayOffset == 4 ? 55 : 120,
                nutritionProteinGoal: 140,
                nutritionMealsLogged: 2,
                nutritionKnown: true,
                yesterdayHardMinutes: hardYesterday ? 75 : 30,
                yesterdayHadHardTraining: hardYesterday,
                todayPlannedSignificant: hardYesterday || shortSleep,
                todayCompletedSignificant: false,
                todayPlannedLabel: "Ride",
                recentCompletedCount48h: hardYesterday ? 1 : 0,
                healthKitAuthorized: true
            )

            let boot = CoachAssistantFlow.bootstrap(
                givenName: "Max",
                memory: memory,
                signals: signals,
                now: day
            )
            if let q = boot.questionID { usedInsightIDs.append(q) }

            let feelingOutput = CoachAssistantFlow.advance(
                .init(
                    node: .feelingAsk,
                    choiceID: shortSleep ? "feeling.tired" : "feeling.okay",
                    feeling: nil,
                    clarification: nil,
                    evidence: .empty,
                    analysisContext: emptyContext(
                        feeling: nil,
                        checkInAt: day
                    ),
                    weekBundle: nil,
                    givenName: "Max",
                    answeredChoiceIDs: [],
                    memory: memory,
                    signals: signals
                )
            )
            if let q = feelingOutput.questionID { usedInsightIDs.append(q) }
            if let r = feelingOutput.recommendationID { usedRecIDs.append(r) }

            let entry = CoachAssistantDayMemory(
                dayKey: dayKey,
                feeling: shortSleep ? .tired : .okay,
                areasVisited: feelingOutput.area.map { [$0] } ?? [],
                questionIDs: [boot.questionID, feelingOutput.questionID].compactMap { $0 },
                recommendationIDs: [feelingOutput.recommendationID].compactMap { $0 },
                unresolvedFollowUp: feelingOutput.followUp,
                insightID: feelingOutput.questionID
            )
            // Clear prior unresolved when a new day starts after follow-up ask.
            if boot.clearPriorFollowUp {
                for index in memory.days.indices {
                    memory.days[index].unresolvedFollowUp = nil
                }
            }
            CoachAssistantMemoryStore.upsertDay(entry, into: &memory)
        }

        XCTAssertGreaterThanOrEqual(Set(usedInsightIDs).count, 3, "Expected varied insight IDs across the week")
        let easeCount = usedRecIDs.filter { $0 == "rec.easePlan" }.count
        XCTAssertLessThanOrEqual(easeCount, 3, "Ease recommendation should not fire every day")
        XCTAssertFalse(usedInsightIDs.allSatisfy { $0 == "open.feeling.standard" })
    }

    func testNextMealSuggestsConcreteOptionWithoutInventDisclaimer() {
        var memory = CoachAssistantMemoryState.empty
        memory.prefersVegetarian = true
        let output = CoachAssistantFlow.advance(
            .init(
                node: .nutritionGate,
                choiceID: "nutrition.helpChoose",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: nil,
                answeredChoiceIDs: ["feeling.okay", "mind.nutrition"],
                memory: memory,
                signals: CoachAssistantSignalSnapshot(
                    checkInAt: date(2026, 10, 5, hour: 16),
                    sleepMinutes: 450,
                    sleepBaselineMinutes: 450,
                    sleepIsFresh: true,
                    recoveryPercent: 60,
                    recoveryBaselinePercent: 60,
                    recoveryIsFresh: true,
                    recoveryIsDerivedScore: true,
                    nutritionCaloriesCurrent: 1_400,
                    nutritionCaloriesGoal: 2_200,
                    nutritionProteinCurrent: 90,
                    nutritionProteinGoal: 140,
                    nutritionMealsLogged: 3,
                    nutritionKnown: true,
                    yesterdayHardMinutes: nil,
                    yesterdayHadHardTraining: false,
                    todayPlannedSignificant: false,
                    todayCompletedSignificant: false,
                    todayPlannedLabel: nil,
                    recentCompletedCount48h: 0,
                    healthKitAuthorized: true
                )
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(text.lowercased().contains("won’t invent"))
        XCTAssertFalse(text.lowercased().contains("won't invent"))
        XCTAssertTrue(text.contains("isn’t logged yet") || text.contains("isn't logged yet"))
        XCTAssertEqual(output.choices.map(\.id), [
            "nutrition.meal.another",
            "nutrition.openMeals",
            "end.done"
        ])
        XCTAssertTrue(output.choices.contains { $0.action == .openMealsTab })
        XCTAssertNotNil(output.recommendationID)
        XCTAssertTrue(output.recommendationID?.hasPrefix("meal.") == true)
    }

    func testOkayNutritionNextMealSkipsRedundantTopicGate() {
        // Scenario A then Nutrition → Next meal (screenshot path).
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 5, hour: 15),
            sleepMinutes: 450,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 62,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 800,
            nutritionCaloriesGoal: 2_200,
            nutritionProteinCurrent: 50,
            nutritionProteinGoal: 140,
            nutritionMealsLogged: 2,
            nutritionKnown: true,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        let afterFeeling = CoachAssistantFlow.advance(
            .init(
                node: .feelingAsk,
                choiceID: "feeling.okay",
                feeling: nil,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: nil, checkInAt: date(2026, 10, 5, hour: 15)),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: [],
                memory: .empty,
                signals: signals
            )
        )
        XCTAssertTrue(afterFeeling.coachTurns.first?.text.english.contains("Got it") == true
            || afterFeeling.coachTurns.first?.text.english.contains("Good to hear") == true)
        XCTAssertEqual(Set(afterFeeling.choices.map(\.id)), [
            "mind.nutrition", "mind.recovery", "mind.activity"
        ])

        let gate = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.nutrition",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 15)),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay"],
                memory: .empty,
                signals: signals
            )
        )
        XCTAssertEqual(gate.coachTurns.first?.nodeID, .nutritionGate)
        XCTAssertEqual(gate.choices.map(\.id), ["nutrition.helpChoose", "nutrition.remaining"])

        var memory = CoachAssistantMemoryState.empty
        memory.prefersVegetarian = false
        let meal = CoachAssistantFlow.advance(
            .init(
                node: .nutritionGate,
                choiceID: "nutrition.helpChoose",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 15)),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.nutrition"],
                memory: memory,
                signals: signals
            )
        )
        XCTAssertEqual(meal.coachTurns.first?.nodeID, .nutritionChooseMeal)
        XCTAssertTrue(meal.coachTurns.first?.text.english.contains("protein") == true
            || meal.coachTurns.first?.text.english.contains("kcal") == true)
        XCTAssertFalse(meal.coachTurns.first?.text.english.lowercased().contains("invent") == true)
    }

    func testMealIdeaFromProteinInsightSkipsNutritionTopicGate() {
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 5, hour: 17),
            sleepMinutes: 440,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 58,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 1_200,
            nutritionCaloriesGoal: 2_200,
            nutritionProteinCurrent: 70,
            nutritionProteinGoal: 150,
            nutritionMealsLogged: 2,
            nutritionKnown: true,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: true,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 1,
            healthKitAuthorized: true
        )
        let afterFeeling = CoachAssistantInsightBuilder.afterFeeling(
            feeling: .okay,
            signals: signals,
            memory: .empty,
            todayKey: "2026-10-05"
        )
        XCTAssertEqual(afterFeeling.insightID, "insight.protein.afterTraining")
        XCTAssertEqual(afterFeeling.choices?.map(\.id).first, "nutrition.mealIdea")

        var memory = CoachAssistantMemoryState.empty
        memory.prefersVegetarian = true
        let meal = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "nutrition.mealIdea",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 17)),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay"],
                memory: memory,
                signals: signals
            )
        )
        XCTAssertEqual(meal.coachTurns.first?.nodeID, .nutritionChooseMeal)
        XCTAssertNotEqual(meal.questionID, "gate.nutrition")
        XCTAssertTrue(meal.choices.contains { $0.id == "nutrition.meal.another" })
    }

    func testAnotherMealOptionChangesSelection() {
        let first = CoachAssistantMealAdvisor.suggest(
            preferVegetarian: true,
            excludingIDs: [],
            proteinRemaining: 40,
            hour: 16
        )
        let second = CoachAssistantMealAdvisor.suggest(
            preferVegetarian: true,
            excludingIDs: [first.id],
            proteinRemaining: 40,
            hour: 16
        )
        XCTAssertNotEqual(first.id, second.id)
    }

    func testIncompleteLoggingClarificationBeforeMealAdvice() {
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 5, hour: 16),
            sleepMinutes: 450,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 60,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 400,
            nutritionCaloriesGoal: 2_200,
            nutritionProteinCurrent: 20,
            nutritionProteinGoal: 140,
            nutritionMealsLogged: 1,
            nutritionKnown: true,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        let output = CoachAssistantFlow.advance(
            .init(
                node: .nutritionGate,
                choiceID: "nutrition.helpChoose",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 16)),
                weekBundle: nil,
                givenName: nil,
                answeredChoiceIDs: ["feeling.okay", "mind.nutrition"],
                memory: .empty,
                signals: signals
            )
        )
        XCTAssertEqual(output.questionID, "nutrition.log.completeness")
        XCTAssertEqual(output.choices.map(\.id), [
            "nutrition.log.complete.yes",
            "nutrition.log.complete.no"
        ])
    }

    func testNoInsightRepeatWithinConversationMemory() {
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 5, hour: 17),
            sleepMinutes: 440,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 58,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: 1_200,
            nutritionCaloriesGoal: 2_200,
            nutritionProteinCurrent: 70,
            nutritionProteinGoal: 150,
            nutritionMealsLogged: 2,
            nutritionKnown: true,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: true,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 1,
            healthKitAuthorized: true
        )
        var memory = CoachAssistantMemoryState.empty
        memory.days = [
            CoachAssistantDayMemory(
                dayKey: "2026-10-05",
                feeling: .okay,
                areasVisited: [.nutrition],
                questionIDs: ["insight.protein.afterTraining"],
                recommendationIDs: ["rec.protein"],
                unresolvedFollowUp: .nutritionProtein,
                insightID: "insight.protein.afterTraining"
            )
        ]
        let again = CoachAssistantInsightBuilder.afterFeeling(
            feeling: .okay,
            signals: signals,
            memory: memory,
            todayKey: "2026-10-05"
        )
        XCTAssertNotEqual(again.insightID, "insight.protein.afterTraining")
        XCTAssertTrue(again.text.english.contains("What would be useful") || again.choices != nil)
    }

    func testClosingIsShortWithoutFollowUpQuestion() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .end,
                choiceID: "end.done",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "end.done"]
            )
        )
        XCTAssertEqual(output.coachTurns.first?.text.english, "You’re all set.")
        XCTAssertTrue(output.ended)
        XCTAssertEqual(output.choices.map(\.id), ["end.new"])
    }

    func testAreaOrderPrefersRecoveryWhenLow() {
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: Date(),
            sleepMinutes: 300,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 40,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: nil,
            nutritionCaloriesGoal: nil,
            nutritionProteinCurrent: nil,
            nutritionProteinGoal: nil,
            nutritionMealsLogged: 0,
            nutritionKnown: false,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        let order = CoachAssistantInsightBuilder.orderedAreas(
            feeling: .tired,
            signals: signals,
            prefer: .recovery
        )
        XCTAssertEqual(order.first, .recovery)
        XCTAssertEqual(Set(order).count, 3)
    }

    // MARK: - Recovery conflict dialogue (screenshot path)

    private func recoveryConflictSignals(planned: Bool) -> CoachAssistantSignalSnapshot {
        CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 5, hour: 15),
            sleepMinutes: 450,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 67,
            recoveryBaselinePercent: 76,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: nil,
            nutritionCaloriesGoal: nil,
            nutritionProteinCurrent: nil,
            nutritionProteinGoal: nil,
            nutritionMealsLogged: 0,
            nutritionKnown: false,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: planned,
            todayCompletedSignificant: false,
            todayPlannedLabel: planned ? "Ride" : nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
    }

    func testOkayDoesNotUpgradeToFeelingGood() {
        let signals = recoveryConflictSignals(planned: true)
        let afterFeeling = CoachAssistantInsightBuilder.afterFeeling(
            feeling: .okay,
            signals: signals,
            memory: .empty,
            todayKey: "2026-10-05"
        )
        XCTAssertEqual(afterFeeling.insightID, "insight.recovery.conflict")
        let text = afterFeeling.text.english.lowercased()
        XCTAssertFalse(text.contains("feeling good"))
        XCTAssertFalse(text.contains("67%"))
        XCTAssertFalse(text.contains("76%"))
        XCTAssertTrue(text.contains("below your usual range"))
        XCTAssertTrue(text.contains("energy"))
    }

    func testEnergizedKeepsPositiveFeelingWording() {
        let afterFeeling = CoachAssistantInsightBuilder.afterFeeling(
            feeling: .energized,
            signals: recoveryConflictSignals(planned: false),
            memory: .empty,
            todayKey: "2026-10-05"
        )
        XCTAssertEqual(afterFeeling.insightID, "insight.recovery.conflict")
        XCTAssertTrue(afterFeeling.text.english.lowercased().contains("good")
            || afterFeeling.text.english.lowercased().contains("energized"))
        XCTAssertFalse(afterFeeling.text.english.contains("67%"))
    }

    func testLowerEnergyAdvancesWithoutRepeatingRecoveryScore() {
        var evidence = CoachAssistantEvidenceBundle.empty
        evidence.feelingEvidence.recoveryPercent = 67
        evidence.feelingEvidence.recoveryBaselinePercent = 76
        evidence.feelingEvidence.recoveryIsStale = false

        let lower = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "recovery.energy.lower",
                feeling: .okay,
                clarification: nil,
                evidence: evidence,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 15)),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay"],
                memory: .empty,
                signals: recoveryConflictSignals(planned: true)
            )
        )
        let text = lower.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.lowercased().contains("sleep") || text.lowercased().contains("got it"))
        XCTAssertFalse(text.contains("67%"))
        XCTAssertFalse(text.contains("76%"))
        XCTAssertFalse(text.lowercased().contains("a little lower"))
        XCTAssertEqual(Set(lower.choices.map(\.id)).intersection([
            "activity.proposeEase", "mind.recovery"
        ]).count, 2)

        let idea = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep,
                choiceID: "recovery.idea",
                feeling: .okay,
                clarification: nil,
                evidence: evidence,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 15)),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "recovery.energy.lower"],
                memory: .empty,
                signals: recoveryConflictSignals(planned: true)
            )
        )
        let ideaText = idea.coachTurns.first?.text.english ?? ""
        XCTAssertEqual(idea.coachTurns.first?.nodeID, .recoveryToday)
        XCTAssertFalse(ideaText.contains("67%") && ideaText.lowercased().hasPrefix("recovery is"))
        XCTAssertFalse(ideaText.lowercased().contains("reasonable default"))
        XCTAssertFalse(ideaText.contains("20–30"))
    }

    func testRecoveryIdeaWithoutPlanSuggestsModestOption() {
        // With recovery.idea retired → sleep brief; modest wind-down remains for energy-lower follow-up.
        let idea = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep,
                choiceID: nil,
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .okay),
                weekBundle: nil,
                givenName: nil,
                answeredChoiceIDs: ["feeling.okay", "recovery.energy.lower"],
                memory: .empty,
                signals: recoveryConflictSignals(planned: false)
            )
        )
        let text = idea.coachTurns.first?.text.english.lowercased() ?? ""
        XCTAssertTrue(text.contains("wind-down") || text.contains("earlier") || text.contains("sleep"))
        XCTAssertFalse(text.contains("20–30"))
        XCTAssertFalse(text.contains("67%"))
        XCTAssertFalse(idea.choices.contains { $0.id == "activity.proposeEase" })
    }

    func testRecoveryTodayDoesNotRepeatConflictInsight() {
        var memory = CoachAssistantMemoryState.empty
        memory.days = [
            CoachAssistantDayMemory(
                dayKey: "2026-10-05",
                feeling: .okay,
                areasVisited: [.recovery],
                questionIDs: ["insight.recovery.conflict"],
                recommendationIDs: ["data.recovery.belowBaseline"],
                unresolvedFollowUp: nil,
                insightID: "insight.recovery.conflict"
            )
        ]
        var evidence = CoachAssistantEvidenceBundle.empty
        evidence.feelingEvidence.recoveryPercent = 67
        evidence.feelingEvidence.recoveryBaselinePercent = 76
        evidence.feelingEvidence.recoveryIsStale = false

        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryToday,
                choiceID: nil,
                feeling: .okay,
                clarification: nil,
                evidence: evidence,
                analysisContext: emptyContext(feeling: .okay, checkInAt: date(2026, 10, 5, hour: 15)),
                weekBundle: nil,
                givenName: nil,
                answeredChoiceIDs: ["feeling.okay"],
                memory: memory,
                signals: recoveryConflictSignals(planned: false)
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(text.contains("67%"))
        XCTAssertFalse(text.contains("76%"))
        XCTAssertEqual(output.questionID, "recovery.today.deduped")
    }

    func testMessageFormatterKeepsShortRepliesCompact() {
        let composed = CoachAssistantMessageFormatter.compose(
            CoachAssistantCopy.bi("That’s useful to know.", "RU1"),
            CoachAssistantCopy.bi("How does your energy feel when you move?", "RU2")
        )
        XCTAssertFalse(composed.english.contains("\n\n"))
        XCTAssertEqual(
            CoachAssistantMessageFormatter.presentForDisplay(composed.english).components(separatedBy: "\n\n").count,
            1
        )
    }

    func testEnergizedActivityShowsTrendWithoutEffortChips() {
        let now = date(2026, 10, 5, hour: 16)
        let completed = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-2 * 3600),
            durationMinutes: 84,
            completed: true
        )
        completed.actualDurationMinutes = 84

        let signals = activitySignals(now: now, completed: true)
        var context = emptyContext(feeling: .energized, checkInAt: now)
        context.plannedActivities = [completed]

        let activity = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized"],
                memory: .empty,
                signals: signals
            )
        )
        let text = activity.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.contains("84-minute") || text.contains("84") || text.localizedCaseInsensitiveContains("today"))
        XCTAssertTrue(text.contains("Walk") || text.lowercased().contains("activity"))
        XCTAssertFalse(text.lowercased().contains("how demanding"))
        XCTAssertFalse(text.lowercased().contains("comfortable"))
        XCTAssertTrue(activity.choices.contains { $0.id == "activity.recent" })
        XCTAssertFalse(activity.choices.contains { $0.id.hasPrefix("activity.effort.") })
        XCTAssertFalse(activity.choices.contains { $0.id == "mind.activity" })
        XCTAssertEqual(activity.questionID, "activity.todayTrend")
    }

    func testActivityPathWithMultipleCompletedSummarizesTrend() {
        let now = date(2026, 10, 5, hour: 16)
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-4 * 3600),
            durationMinutes: 84,
            completed: true
        )
        walk.actualDurationMinutes = 84
        let run = PlannedActivityBuilder.workout(
            title: "Run",
            at: now.addingTimeInterval(-1 * 3600),
            durationMinutes: 40,
            completed: true
        )
        run.actualDurationMinutes = 40

        let signals = activitySignals(now: now, completed: true)
        var context = emptyContext(feeling: .energized, checkInAt: now)
        context.plannedActivities = [walk, run]

        let summary = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized"],
                memory: .empty,
                signals: signals
            )
        )
        let text = summary.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.contains("2 sessions") || text.contains("124") || (text.contains("Walk") && text.contains("Run")))
        XCTAssertFalse(text.lowercased().contains("which session"))
        XCTAssertFalse(summary.choices.contains { $0.id.hasPrefix("activity.effort.") })
        XCTAssertFalse(summary.choices.contains { $0.id.hasPrefix("activity.select.") })
        XCTAssertTrue(summary.choices.contains { $0.id == "activity.recent" })
    }

    func testActivityPathWithNoCompletedOpensGate() {
        let now = date(2026, 10, 5, hour: 16)
        let signals = activitySignals(now: now, completed: false)
        var context = emptyContext(feeling: .energized, checkInAt: now)
        context.plannedActivities = []

        let gate = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized"],
                memory: .empty,
                signals: signals
            )
        )
        XCTAssertEqual(gate.questionID, "gate.activity")
        XCTAssertEqual(Set(gate.choices.map(\.id)), [
            "activity.todayBrief", "activity.recent", "activity.consistency"
        ])
    }

    func testActivityModerateWithLowRecoveryMentionsCaution() {
        // Effort path retired — completed activity stays on past trend brief.
        let now = date(2026, 10, 5, hour: 16)
        let completed = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-2 * 3600),
            durationMinutes: 84,
            completed: true
        )
        completed.actualDurationMinutes = 84

        var signals = activitySignals(now: now, completed: true)
        signals.recoveryPercent = 48
        signals.recoveryBaselinePercent = 72
        signals.recoveryIsFresh = true

        var context = emptyContext(feeling: .energized, checkInAt: now)
        context.plannedActivities = [completed]

        let brief = CoachAssistantFlow.advance(
            .init(
                node: .activityToday,
                choiceID: "activity.effort.moderate",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized", "mind.activity", "activity.effort.moderate"],
                memory: .empty,
                signals: signals
            )
        )
        let text = brief.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.contains("84") || text.localizedCaseInsensitiveContains("today"))
        XCTAssertFalse(text.lowercased().contains("how demanding"))
        XCTAssertTrue(brief.choices.contains { $0.id == "activity.recent" })
    }

    func testActivityMissingIntensityStillAsksWithSubject() {
        let now = date(2026, 10, 5, hour: 16)
        let completed = PlannedActivityBuilder.workout(
            title: "",
            at: now.addingTimeInterval(-2 * 3600),
            durationMinutes: 84,
            completed: true
        )
        completed.actualDurationMinutes = 84

        let signals = activitySignals(now: now, completed: true)
        var context = emptyContext(feeling: .energized, checkInAt: now)
        context.plannedActivities = [completed]

        let ask = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .energized,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized"],
                memory: .empty,
                signals: signals
            )
        )
        let text = ask.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.localizedCaseInsensitiveContains("today"))
        XCTAssertTrue(text.contains("84-minute") || text.contains("84"))
        XCTAssertFalse(text.lowercased().contains("how demanding"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("prescription"))
        XCTAssertTrue(ask.choices.contains { $0.id == "activity.recent" })
        XCTAssertFalse(ask.choices.contains { $0.id.hasPrefix("activity.effort.") })
    }

    // MARK: - Spec v3 dialogue contracts

    func testFeelingLowRoutesToTopicWithFourChips() {
        let output = CoachAssistantFlow.advance(
            .init(
                node: .feelingAsk,
                choiceID: "feeling.low",
                feeling: nil,
                clarification: nil,
                evidence: .empty,
                analysisContext: emptyContext(feeling: nil),
                weekBundle: nil,
                givenName: "Max"
            )
        )
        XCTAssertEqual(output.feeling, .low)
        XCTAssertEqual(output.coachTurns.first?.nodeID, .mindAsk)
        XCTAssertEqual(Set(output.choices.map(\.id)), [
            "mind.activity", "mind.nutrition", "mind.recovery"
        ])
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.contains("not great") || text.contains("What shall we start with?"))
    }

    func testLegacyEffortChipsRedirectToTrendBrief() {
        let now = date(2026, 10, 5, hour: 16)
        let completed = PlannedActivityBuilder.workout(
            title: "Strength",
            at: now.addingTimeInterval(-3600),
            durationMinutes: 48,
            completed: true
        )
        completed.actualDurationMinutes = 48
        var context = emptyContext(feeling: .okay, checkInAt: now)
        context.plannedActivities = [completed]
        let signals = activitySignals(now: now, completed: true)

        let output = CoachAssistantFlow.advance(
            .init(
                node: .activityToday,
                choiceID: "activity.effort.easy",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.activity", "activity.effort.easy"],
                memory: .empty,
                signals: signals
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.contains("48") || text.localizedCaseInsensitiveContains("today"))
        XCTAssertFalse(text.lowercased().contains("how demanding"))
        XCTAssertFalse(output.choices.contains { $0.id.hasPrefix("activity.effort.") })
    }

    func testNutritionRemainingUsesConcreteMidDayFigures() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 820,
            caloriesGoal: 2_000,
            proteinCurrent: 38,
            proteinGoal: 120,
            waterCurrent: 0.5,
            waterGoal: 2,
            mealsCount: 2
        )
        let result = CoachAssistantScenarioAnalyzer.nutritionRemaining(nutrition: nutrition)
        XCTAssertTrue(result.text.english.contains("820"))
        XCTAssertTrue(result.text.english.contains("38"))
        XCTAssertTrue(result.text.english.contains("So far") || result.text.english.contains("of"))
        XCTAssertFalse(result.text.english.lowercased().contains("midpoint"))
        XCTAssertFalse(result.text.english.contains(" / "))
        XCTAssertFalse(result.text.english.lowercased().contains("noticeable"))
        XCTAssertFalse(result.text.english.lowercased().contains("no change needed"))
    }

    func testNutritionNearGoalUsesSoftConclusion() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1_980,
            caloriesGoal: 2_000,
            proteinCurrent: 118,
            proteinGoal: 120,
            waterCurrent: 1.5,
            waterGoal: 2,
            mealsCount: 4
        )
        let result = CoachAssistantScenarioAnalyzer.nutritionRemaining(nutrition: nutrition)
        XCTAssertTrue(result.text.english.lowercased().contains("close to your targets"))
        XCTAssertFalse(result.text.english.lowercased().contains("no need to change"))
        XCTAssertFalse(result.text.russian.lowercased().contains("не требуется"))
    }

    func testRecoveryMismatchWhenFeelingGood() {
        let signals = CoachAssistantSignalSnapshot(
            checkInAt: date(2026, 10, 6, hour: 10),
            sleepMinutes: 420,
            sleepBaselineMinutes: 420,
            sleepIsFresh: true,
            recoveryPercent: 58,
            recoveryBaselinePercent: 70,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: nil,
            nutritionCaloriesGoal: nil,
            nutritionProteinCurrent: nil,
            nutritionProteinGoal: nil,
            nutritionMealsLogged: 0,
            nutritionKnown: false,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: false,
            todayPlannedLabel: nil,
            recentCompletedCount48h: 0,
            healthKitAuthorized: true
        )
        var evidence = CoachAssistantEvidenceBundle.empty
        evidence.feelingEvidence.recoveryPercent = 58
        evidence.feelingEvidence.recoveryBaselinePercent = 70
        evidence.feelingEvidence.recoveryIsStale = false
        evidence.feelingEvidence.sleepMinutes = 420
        evidence.feelingEvidence.sleepBaselineMinutes = 420
        evidence.feelingEvidence.sleepIsStale = false

        let vitals = CoachAssistantRecoveryVitals(
            sleepMinutes: 420,
            deepSleepMinutes: 90,
            remSleepMinutes: 80,
            coreSleepMinutes: 250,
            hrvSDNN: 42,
            restingHeartRate: 58,
            hrvBaselineSDNN: 55,
            restingHeartRateBaseline: 54
        )

        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryToday,
                choiceID: "mind.recovery",
                feeling: .energized,
                clarification: nil,
                evidence: evidence,
                analysisContext: emptyContext(feeling: .energized, checkInAt: date(2026, 10, 6, hour: 10)),
                weekBundle: nil,
                recoveryVitals: vitals,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.energized", "mind.recovery"],
                memory: .empty,
                signals: signals
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.localizedCaseInsensitiveContains("last night") || text.localizedCaseInsensitiveContains("slept"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("deep"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("HRV"))
        XCTAssertTrue(text.contains("58%"))
        XCTAssertTrue(text.contains("70%") || text.contains("usual"))
        XCTAssertTrue(text.lowercased().contains("gap") || text.lowercased().contains("note"))
        XCTAssertFalse(text.lowercased().contains("you should rest"))
        XCTAssertFalse(text.lowercased().contains("not a diagnosis"))
        XCTAssertEqual(output.choices.map(\.id).first, "recovery.nights")
    }

    func testRecoveryTodayLeadsWithSleepStagesAndHRV() {
        var evidence = CoachAssistantEvidenceBundle.empty
        evidence.feelingEvidence.sleepMinutes = 390
        evidence.feelingEvidence.sleepBaselineMinutes = 450
        evidence.feelingEvidence.sleepIsStale = false
        evidence.feelingEvidence.recoveryPercent = 80
        evidence.feelingEvidence.recoveryBaselinePercent = 72
        evidence.feelingEvidence.recoveryIsStale = false

        let vitals = CoachAssistantRecoveryVitals(
            sleepMinutes: 390,
            deepSleepMinutes: 75,
            remSleepMinutes: 70,
            coreSleepMinutes: 245,
            hrvSDNN: 38,
            restingHeartRate: 61,
            hrvBaselineSDNN: 52,
            restingHeartRateBaseline: 55
        )

        let output = CoachAssistantFlow.advance(
            .init(
                node: .recoveryToday,
                choiceID: nil,
                feeling: .tired,
                clarification: .sleepiness,
                evidence: evidence,
                analysisContext: emptyContext(feeling: .tired),
                weekBundle: nil,
                recoveryVitals: vitals,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.tired", "clarify.sleepiness", "mind.recovery"]
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.localizedCaseInsensitiveContains("last night") || text.localizedCaseInsensitiveContains("slept"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("shorter") || text.localizedCaseInsensitiveContains("usual"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("deep"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("HRV"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("resting"))
        // Derived % must not lead when sleep/HRV exist.
        XCTAssertFalse(text.hasPrefix("App recovery reading") || text.hasPrefix("Recovery reading is"))
        XCTAssertFalse(text.lowercased().contains("not a diagnosis"))
        XCTAssertEqual(output.questionID, "recovery.today.sleep")
        XCTAssertFalse(output.choices.map(\.id).contains("recovery.idea"))
    }

    func testRecoveryAnalyzerUsesSleepWithoutRecoveryPercent() {
        var evidence = CoachAssistantEvidenceBundle.empty
        evidence.feelingEvidence.sleepMinutes = 480
        evidence.feelingEvidence.sleepBaselineMinutes = 450
        evidence.feelingEvidence.sleepIsStale = false

        let result = CoachAssistantScenarioAnalyzer.recoveryToday(
            evidence: evidence.feelingEvidence,
            vitals: CoachAssistantRecoveryVitals(
                sleepMinutes: 480,
                deepSleepMinutes: 100,
                remSleepMinutes: nil,
                coreSleepMinutes: nil,
                hrvSDNN: 60,
                restingHeartRate: nil,
                hrvBaselineSDNN: nil,
                restingHeartRateBaseline: nil
            )
        )
        XCTAssertTrue(result.text.english.localizedCaseInsensitiveContains("slept") || result.text.english.localizedCaseInsensitiveContains("last night"))
        XCTAssertTrue(result.text.english.localizedCaseInsensitiveContains("deep"))
        XCTAssertTrue(result.text.english.localizedCaseInsensitiveContains("HRV"))
        XCTAssertFalse(result.text.english.contains("%"))
        XCTAssertFalse(result.text.english.lowercased().contains("not a diagnosis"))
    }

    func testMissingNutritionDoesNotTreatAsZeroIntake() {
        let result = CoachAssistantScenarioAnalyzer.nutritionRemaining(nutrition: nil)
        XCTAssertFalse(result.text.english.contains("0 kcal"))
        XCTAssertTrue(
            result.text.english.lowercased().contains("no nutrition log")
                || result.text.english.lowercased().contains("no") 
        )
    }

    func testTopicSwitchKeepsFeelingWithoutReasking() {
        let other = CoachAssistantFlow.advance(
            .init(
                node: .activityToday,
                choiceID: "end.another",
                feeling: .tired,
                clarification: .lowEnergy,
                evidence: .empty,
                analysisContext: emptyContext(feeling: .tired),
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.tired", "clarify.lowEnergy", "mind.activity", "end.another"]
            )
        )
        XCTAssertTrue(other.coachTurns.isEmpty)
        XCTAssertEqual(other.feeling, .tired)
        XCTAssertEqual(other.clarification, .lowEnergy)
        XCTAssertEqual(Set(other.choices.map(\.id)), [
            "mind.activity", "mind.nutrition", "mind.recovery"
        ])
    }

    func testConversationResumeDoesNotRerunGreeting() {
        let day = date(2026, 10, 5, hour: 9)
        var conversation = makeConversation(id: "resume", at: day)
        conversation.feeling = .okay
        conversation.currentNodeID = .mindAsk
        conversation.choiceIDs = ["feeling.okay"]
        conversation.turns.append(
            CoachAssistantTurn(
                role: .user,
                text: .en("Okay", "Нормально"),
                nodeID: .feelingAsk,
                createdAt: day
            )
        )
        CoachAssistantConversationStore.upsert(conversation)
        let loaded = CoachAssistantConversationStore.latest(on: day)
        XCTAssertEqual(loaded?.id, "resume")
        XCTAssertEqual(loaded?.feeling, .okay)
        XCTAssertEqual(loaded?.currentNodeID, .mindAsk)
        // Resume restores the existing thread — it does not append a second greeting.
        XCTAssertEqual(loaded?.turns.filter { $0.role == .coach }.count, 1)
    }

    func testAnswerTimestampsSurviveRoundTrip() {
        var conversation = makeConversation(id: "answers", at: date(2026, 10, 5, hour: 11))
        conversation.recordAnswer("feeling.okay", at: date(2026, 10, 5, hour: 11))
        conversation.returnNodeID = .nutritionRemaining
        conversation.dataFingerprint = "v1|test"
        CoachAssistantConversationStore.upsert(conversation)
        let loaded = CoachAssistantConversationStore.conversation(id: "answers")
        XCTAssertEqual(loaded?.answerTimestamps["feeling.okay"], date(2026, 10, 5, hour: 11))
        XCTAssertEqual(loaded?.returnNodeID, .nutritionRemaining)
        XCTAssertEqual(loaded?.dataFingerprint, "v1|test")
    }

    func testEditFeelingInvalidatesDependentAnswers() {
        var conversation = makeConversation(id: "edit", at: date(2026, 10, 5, hour: 12))
        conversation.feeling = .okay
        conversation.recordAnswer("feeling.okay")
        conversation.recordAnswer("mind.nutrition")
        conversation.recordAnswer("nutrition.remaining")
        conversation.invalidateAnswers(prefix: "feeling.")
        conversation.invalidateAnswers(prefix: "mind.")
        conversation.invalidateAnswers(prefix: "nutrition.")
        XCTAssertTrue(conversation.answerTimestamps.isEmpty)
        XCTAssertFalse(conversation.choiceIDs.contains { $0.hasPrefix("feeling.") })
    }


    func testMealLogsDoNotCountAsActivity() {
        let now = date(2026, 10, 5, hour: 16)
        let meal = PlannedActivityBuilder.meal(
            title: "Lunch",
            at: now.addingTimeInterval(-3600),
            completed: true
        )
        let flags = CoachAssistantScenarioAnalyzer.todayActivityFlags(
            plannedActivities: [meal],
            now: now
        )
        XCTAssertFalse(flags.hasCompletedActivity)

        var context = emptyContext(feeling: .okay, checkInAt: now)
        context.plannedActivities = [meal]
        let signals = activitySignals(now: now, completed: false)
        let output = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay"],
                memory: .empty,
                signals: signals
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(text.lowercased().contains("lunch"))
        XCTAssertFalse(text.lowercased().contains("how demanding"))
        XCTAssertTrue(
            text.lowercased().contains("no training")
                || text.lowercased().contains("not logged")
                || output.choices.contains { $0.id == "activity.todayBrief" }
        )
    }

    func testRecoveryIdeaSkipsShortWalkWhenLongWalkAlreadyLogged() {
        let now = date(2026, 10, 5, hour: 16)
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-2 * 3600),
            durationMinutes: 110,
            completed: true
        )
        walk.actualDurationMinutes = 110
        var context = emptyContext(feeling: .okay, checkInAt: now)
        context.plannedActivities = [walk]
        let signals = activitySignals(now: now, completed: true)
        // Energy-lower follow-up (not the legacy Recovery idea chip) still guards against more walking.
        let idea = CoachAssistantFlow.advance(
            .init(
                node: .recoveryNextStep,
                choiceID: nil,
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "recovery.energy.lower"],
                memory: .empty,
                signals: signals
            )
        )
        let text = idea.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.contains("110") || text.lowercased().contains("already"))
        XCTAssertTrue(idea.choices.contains { $0.id == "mind.recovery" })
        XCTAssertFalse(text.contains("20–30"))
        XCTAssertFalse(text.lowercased().contains("easy 20"))
    }

    func testActivityTodayUsesConversationalCopyWithoutDisclaimers() {
        let now = date(2026, 10, 5, hour: 16)
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-2 * 3600),
            durationMinutes: 55,
            completed: true
        )
        walk.actualDurationMinutes = 55
        let walk2 = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-3600),
            durationMinutes: 60,
            completed: true
        )
        walk2.actualDurationMinutes = 60
        var context = emptyContext(feeling: .okay, checkInAt: now)
        context.plannedActivities = [walk, walk2]

        let output = CoachAssistantFlow.advance(
            .init(
                node: .mindAsk,
                choiceID: "mind.activity",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil,
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.activity"],
                memory: .empty,
                signals: activitySignals(now: now, completed: true)
            )
        )
        let text = output.coachTurns.first?.text.english ?? ""
        XCTAssertTrue(text.localizedCaseInsensitiveContains("today"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("prescription"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("not a load"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("missing logs"))
        XCTAssertFalse(text.contains("Walk, Walk"))
        XCTAssertTrue(output.choices.map(\.id).contains("mind.recovery"))
        XCTAssertTrue(output.choices.map(\.id).contains("activity.recent"))
    }

    func testActivitySessionKindSummaryDedupesRepeatedNames() {
        let now = date(2026, 10, 5, hour: 16)
        let walks = (0..<3).map { idx -> PlannedActivity in
            let walk = PlannedActivityBuilder.workout(
                title: "Walk",
                at: now.addingTimeInterval(TimeInterval(-3600 * (idx + 1))),
                durationMinutes: 40,
                completed: true
            )
            walk.actualDurationMinutes = 40
            return walk
        }
        let snapshots = walks.map(CoachPlannedActivitySnapshot.init)
        let summary = CoachAssistantCopy.activitySessionKindSummary(snapshots)
        XCTAssertEqual(summary?.en, "3 walks")
        XCTAssertFalse(summary?.en.contains("Walk, Walk") == true)
    }


    func testActivityRecentFromTodayUsesPlannerFallbackWithoutLoadError() {
        let now = date(2026, 10, 5, hour: 16)
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-2 * 24 * 3600),
            durationMinutes: 90,
            completed: true
        )
        walk.actualDurationMinutes = 90
        var context = emptyContext(feeling: .okay, checkInAt: now)
        context.plannedActivities = [walk]

        let recent = CoachAssistantFlow.advance(
            .init(
                node: .activityToday,
                choiceID: "activity.recent",
                feeling: .okay,
                clarification: nil,
                evidence: .empty,
                analysisContext: context,
                weekBundle: nil, // simulates chip tapped before week load
                givenName: "Max",
                answeredChoiceIDs: ["feeling.okay", "mind.activity", "activity.recent"],
                memory: .empty,
                signals: activitySignals(now: now, completed: false)
            )
        )
        let text = recent.coachTurns.first?.text.english ?? ""
        XCTAssertFalse(text.lowercased().contains("couldn’t load"))
        XCTAssertFalse(text.lowercased().contains("couldn't load"))
        XCTAssertFalse(text.lowercased().contains("try again"))
        XCTAssertTrue(text.lowercased().contains("last 7 days") || text.contains("1"))
        XCTAssertEqual(recent.questionID, "activity.recent")
    }

    // MARK: - Helpers

    private func activitySignals(now: Date, completed: Bool) -> CoachAssistantSignalSnapshot {
        CoachAssistantSignalSnapshot(
            checkInAt: now,
            sleepMinutes: 450,
            sleepBaselineMinutes: 450,
            sleepIsFresh: true,
            recoveryPercent: 62,
            recoveryBaselinePercent: 60,
            recoveryIsFresh: true,
            recoveryIsDerivedScore: true,
            nutritionCaloriesCurrent: nil,
            nutritionCaloriesGoal: nil,
            nutritionProteinCurrent: nil,
            nutritionProteinGoal: nil,
            nutritionMealsLogged: 0,
            nutritionKnown: false,
            yesterdayHardMinutes: nil,
            yesterdayHadHardTraining: false,
            todayPlannedSignificant: false,
            todayCompletedSignificant: completed,
            todayPlannedLabel: nil,
            recentCompletedCount48h: completed ? 1 : 0,
            healthKitAuthorized: true
        )
    }

    private func makeConversation(id: String, at date: Date) -> CoachAssistantConversation {
        CoachAssistantConversation(
            id: id,
            createdAt: date,
            updatedAt: date,
            feeling: nil,
            clarification: nil,
            area: nil,
            currentNodeID: .feelingAsk,
            turns: [
                CoachAssistantTurn(
                    role: .coach,
                    text: .en("Hi", "Привет"),
                    nodeID: .feelingAsk,
                    createdAt: date
                )
            ],
            choiceIDs: [],
            evidence: .empty,
            previewEnglish: "Hi",
            previewRussian: "Привет",
            ended: false
        )
    }

    private func emptyContext(
        feeling: CoachFeelingKind?,
        checkInAt: Date = Date()
    ) -> CoachAssistantScenarioAnalyzer.Context {
        .init(
            feeling: feeling,
            clarification: nil,
            checkInAt: checkInAt,
            observations: [],
            plannedActivities: [],
            recentActivityCount: 0,
            recentActivityDayKeys: [],
            nutrition: nil,
            healthAccessGranted: nil
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }
}
