import Foundation
import XCTest
@testable import WeekFit

final class MorningProposalEngineV2Tests: XCTestCase {

    override func tearDown() {
        MorningProposalStore.resetAllForTests()
        CoachObservationStore.resetForTests()
        ProposalBehavioralPreferences.resetAllForTests()
        ProposalOfferHistoryStore.resetAllForTests()
        super.tearDown()
    }

    // MARK: - Strategy

    func testStrategyLowRecoveryIsRecover() {
        let context = makeContext(recoveryBand: .low, yesterdayHeavy: false, tomorrowDemand: .none, openCount: 1)
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .recover)
    }

    func testStrategyModerateHeavyYesterdayIsRecover() {
        let context = makeContext(recoveryBand: .moderate, yesterdayHeavy: true, tomorrowDemand: .none, openCount: 2)
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .recover)
    }

    func testStrategyGoodHeavyYesterdayIsRecover() {
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: true,
            tomorrowDemand: .none,
            openCount: 0,
            sleepPresence: .present,
            freshness: .high
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .recover)
    }

    func testStrategyGoodHeavyYesterdayBeatsHabitualTrainPath() {
        let templates = [
            SimilarDayTemplate(
                dayKey: "2026-07-01",
                recoveryBand: .good,
                observationAvailable: true,
                sleepPresence: .present,
                activities: [
                    snap("a1", day: 1, title: "Tempo Run", duration: 80, completed: true),
                    snap("a2", day: 8, title: "Tempo Run", duration: 80, completed: true)
                ]
            ),
            SimilarDayTemplate(
                dayKey: "2026-07-08",
                recoveryBand: .good,
                observationAvailable: true,
                sleepPresence: .present,
                activities: [snap("b1", day: 8, title: "Tempo Run", duration: 80, completed: true)]
            )
        ]
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: true,
            tomorrowDemand: .none,
            openCount: 0,
            sleepPresence: .present,
            freshness: .high,
            templates: templates
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .recover)
    }

    func testHistoricalProviderSkipsElevatedAfterHeavyYesterday() {
        let templates = [
            SimilarDayTemplate(
                dayKey: "2026-07-01",
                recoveryBand: .good,
                observationAvailable: true,
                sleepPresence: .present,
                activities: [snap("w1", day: 1, hour: 18, title: "Workout", duration: 15, completed: true)]
            ),
            SimilarDayTemplate(
                dayKey: "2026-07-08",
                recoveryBand: .good,
                observationAvailable: true,
                sleepPresence: .present,
                activities: [snap("w2", day: 8, hour: 18, title: "Workout", duration: 15, completed: true)]
            )
        ]
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: true,
            tomorrowDemand: .none,
            openCount: 0,
            sleepPresence: .present,
            freshness: .high,
            templates: templates
        )
        let strategy = DailyStrategyResolver.resolve(context: context)
        XCTAssertEqual(strategy, .recover)
        let historical = HistoricalActivityProvider.generate(context: context, strategy: strategy)
        XCTAssertFalse(
            historical.contains { candidate in
                if case .createPlannedActivity(let payload) = candidate.payload {
                    return payload.title == "Workout"
                }
                return false
            }
        )
    }

    func testStrategyGoodHardTomorrowIsProtectTomorrow() {
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: false,
            tomorrowDemand: .hard,
            openCount: 1,
            sleepPresence: .present
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .protectTomorrow)
    }

    func testStrategyModerateNormalIsMaintain() {
        let context = makeContext(
            recoveryBand: .moderate,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 1,
            sleepPresence: .present,
            freshness: .high
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .maintain)
    }

    func testStrategyLowConfidenceContinueExisting() {
        let context = makeContext(
            recoveryBand: .unavailable,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 2,
            sleepPresence: .unavailable,
            freshness: .low,
            canMutate: false
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .continueExistingPlan)
    }

    // MARK: - Historical aggregation

    func testRepeatedCompletedActivityOutranksOneOff() {
        let repeated = SimilarDayTemplate(
            dayKey: "2026-07-01",
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [
                snap("a1", day: 1, title: "Tempo Run", completed: true),
                snap("a2", day: 1, hour: 18, title: "Tempo Run", completed: true)
            ]
        )
        // Two days with same activity completed
        let day2 = SimilarDayTemplate(
            dayKey: "2026-07-08",
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [snap("b1", day: 8, title: "Tempo Run", completed: true)]
        )
        let oneOff = SimilarDayTemplate(
            dayKey: "2026-07-10",
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [snap("c1", day: 10, title: "Odd Circuit", completed: true)]
        )
        let aggregates = HistoricalActivityAggregator.aggregate(
            templates: [repeated, day2, oneOff],
            todayWeekday: 4
        )
        XCTAssertEqual(aggregates.first?.title, "Tempo Run")
        XCTAssertGreaterThanOrEqual(aggregates.first?.completionCount ?? 0, 2)
    }

    func testMissingObservationLowersTrainGate() {
        let templates = [
            SimilarDayTemplate(
                dayKey: "2026-07-01",
                recoveryBand: .unavailable,
                observationAvailable: false,
                sleepPresence: .unavailable,
                activities: [snap("a", day: 1, title: "Long Run", completed: true)]
            )
        ]
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 0,
            sleepPresence: .present,
            freshness: .high,
            templates: templates
        )
        // Without observation-backed repeated success, train should not fire.
        XCTAssertNotEqual(DailyStrategyResolver.resolve(context: context), .train)
    }

    // MARK: - Scoring / composition / validation

    func testScorerHardRejectsIncompatibleSeriousOnRecover() {
        let context = makeContext(recoveryBand: .low, yesterdayHeavy: true, tomorrowDemand: .none, openCount: 0)
        let candidate = ProposalCandidate(
            id: "serious",
            source: .historicalActivity,
            kind: .createPlannedActivity,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: Date(),
                    durationMinutes: 60,
                    title: "Intervals",
                    activityType: "workout",
                    icon: "figure.run",
                    imageName: "",
                    colorRed: 0, colorGreen: 0, colorBlue: 0,
                    sourceTemplateDayKey: nil
                )
            ),
            compatibleStrategies: [.train],
            physiologicalFit: .strong,
            confidence: 0.9,
            burden: .high,
            reasonCodes: [.similarDaySupport],
            conflicts: [],
            defaultSelectionEligibility: .ineligible,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            identityKey: "hist:intervals"
        )
        XCTAssertNil(CandidateScorer.score(candidate, context: context, strategy: .recover))
    }

    func testScorerAppliesLearnedSoftPenaltyForHardCreateWhenPreferAvoid() {
        let baseline = makeContext(
            recoveryBand: .moderate,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 0,
            preferAvoidHardLoadOnLowRecovery: false
        )
        let learned = makeContext(
            recoveryBand: .moderate,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 0,
            preferAvoidHardLoadOnLowRecovery: true
        )
        let candidate = ProposalCandidate(
            id: "serious",
            source: .historicalActivity,
            kind: .createPlannedActivity,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: Date(),
                    durationMinutes: 60,
                    title: "Intervals",
                    activityType: "workout",
                    icon: "figure.run",
                    imageName: "",
                    colorRed: 0, colorGreen: 0, colorBlue: 0,
                    sourceTemplateDayKey: nil
                )
            ),
            compatibleStrategies: [.maintain, .train],
            physiologicalFit: .strong,
            confidence: 0.9,
            burden: .high,
            reasonCodes: [.similarDaySupport],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            identityKey: "hist:intervals"
        )

        let baselineScored = CandidateScorer.score(candidate, context: baseline, strategy: .maintain)
        let learnedScored = CandidateScorer.score(candidate, context: learned, strategy: .maintain)
        XCTAssertNotNil(baselineScored)
        XCTAssertNotNil(learnedScored)
        XCTAssertEqual(learnedScored?.breakdown.fatiguePenalty, -6)
        XCTAssertEqual(baselineScored?.breakdown.fatiguePenalty, 0)
        XCTAssertLessThan(learnedScored?.score ?? 0, baselineScored?.score ?? 0)
        XCTAssertFalse(CandidateScorer.shouldDefaultSelect(learnedScored!, context: learned, strategy: .train))
    }

    func testComposerProtectBlocksCreates() {
        let walk = scoredWalk()
        let composed = PlanComposer.compose(
            scored: [walk],
            context: makeContext(
                recoveryBand: .moderate,
                yesterdayHeavy: false,
                tomorrowDemand: .none,
                openCount: 4,
                mode: .protect
            ),
            strategy: .maintain
        )
        XCTAssertFalse(composed.scoredCandidates.contains { $0.candidate.kind == .createRecoveryWalk })
    }

    func testValidatorDropsDuplicateWalk() {
        let a = scoredWalk(id: "w1")
        let b = scoredWalk(id: "w2")
        let validated = PlanValidator.validate(
            composed: ComposedPlan(strategy: .recover, scoredCandidates: [a, b], droppedCandidateIds: [], validationNotes: []),
            context: makeContext(recoveryBand: .low, yesterdayHeavy: true, tomorrowDemand: .none, openCount: 0)
        )
        let walks = validated.candidates.filter { $0.candidate.kind == .createRecoveryWalk }
        XCTAssertLessThanOrEqual(walks.count, 1)
    }

    func testEngineEndToEndShortenOnRecover() {
        let now = date(2026, 7, 29, 7, 0)
        let run = snap("run-1", day: 29, hour: 18, title: "Evening Run", duration: 75, completed: false)
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: true,
                tomorrowDemand: .moderate,
                today: [run]
            )
        )
        XCTAssertEqual(proposal.strategy, .recover)
        XCTAssertTrue(proposal.changes.contains { $0.kind == .modifyDuration })
        XCTAssertTrue(proposal.changes.first { $0.kind == .modifyDuration }?.defaultSelected == true)
    }

    func testFingerprintMealLibraryRevisionInvalidates() {
        let a = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false,
            mealLibraryRevision: "1"
        )
        let b = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false,
            mealLibraryRevision: "2"
        )
        XCTAssertTrue(a.materialDifference(from: b))
    }

    func testBehavioralFewerThanThreeRejectsNoPenalty() {
        var snapshot = ProposalBehavioralPreferences.Snapshot.empty
        snapshot.walkRejectCount = 2
        snapshot.walkAcceptCount = 0
        snapshot.updatedAt = Date()
        XCTAssertEqual(ProposalBehavioralPreferences.walkRejectPenalty(from: snapshot), 0)
    }

    func testDefaultSelectionNewActivityUnselected() {
        let context = makeContext(recoveryBand: .good, yesterdayHeavy: false, tomorrowDemand: .none, openCount: 0)
        let candidate = ProposalCandidate(
            id: "hist",
            source: .historicalActivity,
            kind: .createPlannedActivity,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: Date(), durationMinutes: 40, title: "Run", activityType: "workout",
                    icon: "figure.run", imageName: "", colorRed: 0, colorGreen: 0, colorBlue: 0,
                    sourceTemplateDayKey: nil
                )
            ),
            compatibleStrategies: [.train],
            physiologicalFit: .strong,
            confidence: 0.9,
            burden: .high,
            reasonCodes: [.similarDaySupport],
            conflicts: [],
            defaultSelectionEligibility: .ineligible,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            identityKey: "hist:run"
        )
        let scored = ScoredCandidate(
            candidate: candidate,
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 22, strategyFit: 18, historicalSuccess: 14,
                behavioralLikelihood: 10, tomorrowProtection: 0, usualTimeFit: 6,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )
        XCTAssertFalse(CandidateScorer.shouldDefaultSelect(scored, context: context, strategy: .train))
    }

    func testDefaultSelectionHighEvidenceHabitSelectedOnTrain() {
        let context = makeContext(recoveryBand: .good, yesterdayHeavy: false, tomorrowDemand: .none, openCount: 0)
        let candidate = ProposalCandidate(
            id: "hist-ride",
            source: .historicalActivity,
            kind: .createPlannedActivity,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: Date(), durationMinutes: 80, title: "Morning Ride", activityType: "workout",
                    icon: "figure.outdoor.cycle", imageName: "", colorRed: 0, colorGreen: 0, colorBlue: 0,
                    sourceTemplateDayKey: nil
                )
            ),
            compatibleStrategies: [.train],
            physiologicalFit: .strong,
            confidence: 0.85,
            burden: .high,
            reasonCodes: [.similarDaySupport],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            identityKey: "hist:ride"
        )
        let scored = ScoredCandidate(
            candidate: candidate,
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 22, strategyFit: 18, historicalSuccess: 14,
                behavioralLikelihood: 10, tomorrowProtection: 0, usualTimeFit: 6,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )
        XCTAssertTrue(CandidateScorer.shouldDefaultSelect(scored, context: context, strategy: .train))
        XCTAssertFalse(CandidateScorer.shouldDefaultSelect(scored, context: context, strategy: .maintain))
    }

    func testOptionalCreateCooloffSuppressesRepeatOffer() {
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 0,
            sleepPresence: .present,
            freshness: .high,
            mode: .compose
        )
        let candidate = ProposalCandidate(
            id: "hist-type|Morning Ride",
            source: .historicalActivity,
            kind: .createPlannedActivity,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: date(2026, 7, 29, 10, 0),
                    durationMinutes: 80,
                    title: "Morning Ride",
                    activityType: "workout",
                    icon: "figure.outdoor.cycle",
                    imageName: "",
                    colorRed: 0,
                    colorGreen: 0,
                    colorBlue: 0,
                    sourceTemplateDayKey: nil
                )
            ),
            compatibleStrategies: [.train],
            physiologicalFit: .strong,
            confidence: 0.9,
            burden: .high,
            reasonCodes: [.similarDaySupport],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: date(2026, 7, 29, 10, 0),
            evidenceScenarioKey: nil,
            identityKey: "hist:type|Morning Ride"
        )
        let scored = ScoredCandidate(
            candidate: candidate,
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 42, strategyFit: 18, historicalSuccess: 14,
                behavioralLikelihood: 10, tomorrowProtection: 0, usualTimeFit: 6,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )

        ProposalOfferHistoryStore.recordOffers(
            dayKey: "2026-07-28",
            changes: [
                CoachProposedChange(
                    id: candidate.id,
                    kind: .createPlannedActivity,
                    reasonCode: .similarDaySupport,
                    payload: candidate.payload,
                    defaultSelected: true,
                    isSelected: true,
                    sortTime: candidate.sortTime,
                    evidenceScenarioKey: nil,
                    candidateSource: .historicalActivity,
                    scoreTotal: scored.score
                )
            ],
            now: date(2026, 7, 28, 8, 0)
        )

        XCTAssertTrue(ProposalRepetitionGuard.shouldSuppress(candidate, context: context))

        let composed = PlanComposer.compose(scored: [scored], context: context, strategy: .train)
        XCTAssertFalse(composed.scoredCandidates.contains(where: { $0.id == candidate.id }))
        XCTAssertTrue(composed.validationNotes.contains(where: { $0.hasPrefix("repeat_cooloff:") }))
    }

    // MARK: - Correctness regressions

    func testPlanStaleIgnoresBehavioralGeneration() {
        let a = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "sig",
            tomorrowPlanSignature: "",
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false,
            behavioralGeneration: 1
        )
        let b = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "sig",
            tomorrowPlanSignature: "",
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false,
            behavioralGeneration: 9
        )
        XCTAssertFalse(a.planStaleDifference(from: b))
        XCTAssertTrue(a.materialDifference(from: b))
    }

    func testProtectModeWithoutDemandContinuesExistingPlan() {
        let context = makeContext(
            recoveryBand: .moderate,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            openCount: 1,
            sleepPresence: .present,
            freshness: .high,
            mode: .protect
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .continueExistingPlan)
    }

    func testMealPickDoesNotTreatBalancedAsMatchAll() {
        let library = [
            ProposalMealCandidate(
                id: "spicy",
                title: "Spicy Bowl",
                imageName: "",
                calories: 500, protein: 30, carbs: 40, fats: 15, fiber: 8,
                mealsTypeRaw: "endurance",
                suggestedTime: "12:00"
            ),
            ProposalMealCandidate(
                id: "balanced",
                title: "Balanced Plate",
                imageName: "",
                calories: 480, protein: 28, carbs: 45, fats: 14, fiber: 10,
                mealsTypeRaw: "balanced",
                suggestedTime: "08:30"
            )
        ]
        let picks = MealLibraryProvider.pickMeals(
            from: library,
            preferredTypes: ["recovery", "balanced"],
            limit: 1
        )
        XCTAssertEqual(picks.map(\.id), ["balanced"])
    }

    func testMealPickFallsBackOnlyWhenNoPreferredTypeMatches() {
        let library = [
            ProposalMealCandidate(
                id: "only",
                title: "Odd Meal",
                imageName: "",
                calories: 400, protein: 20, carbs: 30, fats: 10, fiber: 5,
                mealsTypeRaw: "custom",
                suggestedTime: nil
            )
        ]
        let picks = MealLibraryProvider.pickMeals(
            from: library,
            preferredTypes: ["recovery", "balanced"],
            limit: 1
        )
        XCTAssertEqual(picks.map(\.id), ["only"])
    }

    func testShortenReasonUsesTomorrowProtectionWhenHardTomorrow() {
        let now = date(2026, 7, 29, 7, 0)
        let run = snap("run-1", day: 29, hour: 18, title: "Evening Run", duration: 75, completed: false)
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: false,
                tomorrowDemand: .hard,
                today: [run]
            )
        )
        let shorten = proposal.changes.first { $0.kind == .modifyDuration }
        XCTAssertEqual(shorten?.reasonCode, .tomorrowDemandProtection)
    }

    func testMoveAvoidsOccupiedTomorrowSlot() {
        let now = date(2026, 7, 29, 7, 0)
        let morning = snap("s1", day: 29, hour: 9, title: "Morning Ride", duration: 60, completed: false)
        let evening = snap("s2", day: 29, hour: 18, title: "Evening Run", duration: 50, completed: false)
        let tomorrowBusy = snap("t1", day: 30, hour: 18, title: "Race", duration: 90, completed: false)

        let mode = MorningProposalGenerationModeResolver.resolve(
            openCount: 2,
            hasCompletedOrPartialToday: false,
            isMorningWindow: true
        )
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: [morning, evening],
            tomorrowSnapshots: [tomorrowBusy],
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: CoachScenarioKey.lowRecoveryPrep.rawValue,
            yesterdayHeavy: true,
            generationMode: mode
        )
        let proposal = MorningProposalEngine.generate(
            input: MorningProposalEngineInput(
                now: now,
                dayKey: "2026-07-29",
                fingerprint: fingerprint,
                scenarioKey: .lowRecoveryPrep,
                recoveryBand: .low,
                sleepPresence: .present,
                yesterdayHeavy: true,
                tomorrowDemand: .moderate,
                stackedLoad: .unavailable,
                generationMode: mode,
                todayActivities: [morning, evening],
                tomorrowActivities: [tomorrowBusy],
                completedWalkToday: false,
                canMutate: true,
                recentDayTemplates: [],
                mealLibrary: [],
                walkRejectPenalty: 0,
                stronglyRejectsWalk: false
            )
        )
        let moves = proposal.changes.compactMap { change -> Date? in
            guard case .moveActivity(let payload) = change.payload else { return nil }
            return payload.proposedDate
        }
        for proposed in moves {
            XCTAssertGreaterThan(
                abs(proposed.timeIntervalSince(tomorrowBusy.date)),
                25 * 60,
                "Moved activity should not land on occupied tomorrow slot"
            )
        }
    }

    func testTimeConflictKeepsShortenAlongsideCreate() {
        let context = makeContext(recoveryBand: .low, yesterdayHeavy: true, tomorrowDemand: .none, openCount: 1)
        let sharedTime = date(2026, 7, 29, 12, 30)
        let shorten = ScoredCandidate(
            candidate: ProposalCandidate(
                id: "shorten",
                source: .existingPlanAdjustment,
                kind: .modifyDuration,
                payload: .modifyDuration(
                    ModifyDurationPayload(
                        activityId: "run-1",
                        originalDurationMinutes: 75,
                        proposedDurationMinutes: 55
                    )
                ),
                compatibleStrategies: [.recover],
                physiologicalFit: .strong,
                confidence: 0.85,
                burden: .low,
                reasonCodes: [.lowRecoveryLoadProtection],
                conflicts: [],
                defaultSelectionEligibility: .eligible,
                sortTime: sharedTime,
                evidenceScenarioKey: nil,
                identityKey: "shorten:run-1"
            ),
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 40, strategyFit: 18, historicalSuccess: 0,
                behavioralLikelihood: 0, tomorrowProtection: 0, usualTimeFit: 0,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )
        let walk = ScoredCandidate(
            candidate: ProposalCandidate(
                id: "walk",
                source: .recoveryMovement,
                kind: .createRecoveryWalk,
                payload: .createRecoveryWalk(
                    CreateRecoveryWalkPayload(
                        proposedDate: sharedTime,
                        durationMinutes: 20,
                        title: "Walk",
                        activityType: "recovery"
                    )
                ),
                compatibleStrategies: [.recover],
                physiologicalFit: .strong,
                confidence: 0.8,
                burden: .low,
                reasonCodes: [.recoveryWalkSupport],
                conflicts: [],
                defaultSelectionEligibility: .eligible,
                sortTime: sharedTime,
                evidenceScenarioKey: nil,
                identityKey: "walk:recovery"
            ),
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 38, strategyFit: 18, historicalSuccess: 0,
                behavioralLikelihood: 8, tomorrowProtection: 0, usualTimeFit: 0,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )
        let validated = PlanValidator.validate(
            composed: ComposedPlan(
                strategy: .recover,
                scoredCandidates: [shorten, walk],
                droppedCandidateIds: [],
                validationNotes: []
            ),
            context: context
        )
        XCTAssertTrue(validated.candidates.contains { $0.id == "shorten" })
        XCTAssertTrue(validated.candidates.contains { $0.id == "walk" })
    }

    func testSoftNegativePenaltyDoesNotDropSafetyShorten() {
        var context = makeContext(recoveryBand: .low, yesterdayHeavy: true, tomorrowDemand: .none, openCount: 1)
        // Rebuild with soft penalty.
        context = DailyContext(
            now: context.now,
            dayKey: context.dayKey,
            isMorningEligible: context.isMorningEligible,
            hasCompletedOrPartialToday: context.hasCompletedOrPartialToday,
            generationMode: context.generationMode,
            contextFreshness: context.contextFreshness,
            recoveryBand: context.recoveryBand,
            recoveryPercent: context.recoveryPercent,
            recoveryAvailable: context.recoveryAvailable,
            sleepPresence: context.sleepPresence,
            sleepHours: context.sleepHours,
            yesterdayHeavy: context.yesterdayHeavy,
            stackedLoad: context.stackedLoad,
            tomorrowDemand: context.tomorrowDemand,
            scenarioKey: context.scenarioKey,
            todayActivities: context.todayActivities,
            tomorrowActivities: context.tomorrowActivities,
            todayOpen: context.todayOpen,
            todaySeriousOpen: context.todaySeriousOpen,
            hasExistingMovement: context.hasExistingMovement,
            completedWalkToday: context.completedWalkToday,
            totalPlannedDurationMinutes: context.totalPlannedDurationMinutes,
            recentDayTemplates: context.recentDayTemplates,
            historicalObservationRevision: context.historicalObservationRevision,
            behavioralGeneration: context.behavioralGeneration,
            walkRejectPenalty: context.walkRejectPenalty,
            stronglyRejectsWalk: context.stronglyRejectsWalk,
            softDismissCount: 6,
            softNegativePenalty: 6,
            preferAvoidHardLoadOnLowRecovery: false,
            mealLibrary: context.mealLibrary,
            mealLibraryRevision: context.mealLibraryRevision,
            weatherRiskToken: context.weatherRiskToken,
            canMutate: context.canMutate,
            fingerprint: context.fingerprint
        )
        let candidate = ProposalCandidate(
            id: "shorten",
            source: .existingPlanAdjustment,
            kind: .modifyDuration,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: "run-1",
                    originalDurationMinutes: 75,
                    proposedDurationMinutes: 55
                )
            ),
            compatibleStrategies: [.recover],
            physiologicalFit: .strong,
            confidence: 0.85,
            burden: .low,
            reasonCodes: [.lowRecoveryLoadProtection],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: context.now,
            evidenceScenarioKey: nil,
            identityKey: "shorten:run-1"
        )
        let scored = CandidateScorer.score(candidate, context: context, strategy: .recover)
        XCTAssertNotNil(scored)
        XCTAssertGreaterThanOrEqual(scored?.score ?? 0, CandidateScorer.inclusionThreshold)
    }

    func testComposerPrefersHabitualYogaOverRecoveryWalk() {
        let context = makeContext(recoveryBand: .low, yesterdayHeavy: true, tomorrowDemand: .none, openCount: 0)
        let yoga = ScoredCandidate(
            candidate: ProposalCandidate(
                id: "hist-yoga",
                source: .historicalActivity,
                kind: .createPlannedActivity,
                payload: .createPlannedActivity(
                    CreatePlannedActivityPayload(
                        proposedDate: date(2026, 7, 31, 10, 0),
                        durationMinutes: 40,
                        title: "Yoga",
                        activityType: "recovery",
                        icon: "figure.yoga",
                        imageName: "",
                        colorRed: 0, colorGreen: 0, colorBlue: 0,
                        sourceTemplateDayKey: nil
                    )
                ),
                compatibleStrategies: [.recover, .maintain],
                physiologicalFit: .moderate,
                confidence: 0.7,
                burden: .medium,
                reasonCodes: [.similarDaySupport],
                conflicts: [],
                defaultSelectionEligibility: .ineligible,
                sortTime: date(2026, 7, 31, 10, 0),
                evidenceScenarioKey: nil,
                identityKey: "hist:yoga"
            ),
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 24, strategyFit: 18, historicalSuccess: 8,
                behavioralLikelihood: 6, tomorrowProtection: 0, usualTimeFit: 6,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )
        let walk = scoredWalk(id: "walk")
        let composed = PlanComposer.compose(
            scored: [walk, yoga],
            context: context,
            strategy: .recover
        )
        XCTAssertTrue(composed.scoredCandidates.contains { $0.id == "hist-yoga" })
        XCTAssertFalse(composed.scoredCandidates.contains { $0.candidate.kind == .createRecoveryWalk })
    }

    func testWeekdayWorkdayWalkSlotIsEveningNotMidday() {
        // Friday Jul 31 2026 is a weekday.
        let now = date(2026, 7, 31, 8, 0)
        let context = makeContext(
            recoveryBand: .low,
            yesterdayHeavy: true,
            tomorrowDemand: .none,
            openCount: 0
        )
        // Rebuild with explicit Friday morning now.
        let fridayContext = DailyContext(
            now: now,
            dayKey: context.dayKey,
            isMorningEligible: context.isMorningEligible,
            hasCompletedOrPartialToday: context.hasCompletedOrPartialToday,
            generationMode: context.generationMode,
            contextFreshness: context.contextFreshness,
            recoveryBand: context.recoveryBand,
            recoveryPercent: context.recoveryPercent,
            recoveryAvailable: context.recoveryAvailable,
            sleepPresence: context.sleepPresence,
            sleepHours: context.sleepHours,
            yesterdayHeavy: context.yesterdayHeavy,
            stackedLoad: context.stackedLoad,
            tomorrowDemand: context.tomorrowDemand,
            scenarioKey: context.scenarioKey,
            todayActivities: context.todayActivities,
            tomorrowActivities: context.tomorrowActivities,
            todayOpen: context.todayOpen,
            todaySeriousOpen: context.todaySeriousOpen,
            hasExistingMovement: context.hasExistingMovement,
            completedWalkToday: false,
            totalPlannedDurationMinutes: context.totalPlannedDurationMinutes,
            recentDayTemplates: [],
            historicalObservationRevision: context.historicalObservationRevision,
            behavioralGeneration: context.behavioralGeneration,
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false,
            softDismissCount: 0,
            softNegativePenalty: 0,
            preferAvoidHardLoadOnLowRecovery: false,
            mealLibrary: [],
            mealLibraryRevision: "0",
            weatherRiskToken: .unavailable,
            canMutate: true,
            fingerprint: context.fingerprint
        )
        XCTAssertTrue(RecoveryMovementProvider.isWeekdayWorkday(now))
        let slot = RecoveryMovementProvider.recoveryWalkSlot(context: fridayContext)
        XCTAssertNotNil(slot)
        let hour = Calendar.current.component(.hour, from: slot!)
        XCTAssertEqual(hour, 18, "Weekday walk should default to evening, not 12:30")
    }

    func testHabitualYogaOnWeekdaySuppressesGenericWalk() {
        let now = date(2026, 7, 31, 8, 0) // Friday
        let yogaTemplate = SimilarDayTemplate(
            dayKey: "2026-07-24", // previous Friday
            recoveryBand: .low,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [
                CoachPlannedActivitySnapshot(
                    id: "y1",
                    date: date(2026, 7, 24, 19, 0),
                    type: "recovery",
                    title: "Yoga",
                    durationMinutes: 40,
                    icon: "figure.yoga",
                    imageName: "",
                    isCompleted: true,
                    isSkipped: false,
                    source: "planner"
                )
            ]
        )
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: true,
                tomorrowDemand: .none,
                today: [],
                templates: [yogaTemplate]
            )
        )
        XCTAssertFalse(proposal.changes.contains { $0.kind == .createRecoveryWalk })
        XCTAssertTrue(proposal.changes.contains {
            guard case .createPlannedActivity(let p) = $0.payload else { return false }
            return p.title.lowercased().contains("yoga")
        })
        if let yoga = proposal.changes.first(where: {
            guard case .createPlannedActivity(let p) = $0.payload else { return false }
            return p.title.lowercased().contains("yoga")
        }), case .createPlannedActivity(let payload) = yoga.payload {
            let hour = Calendar.current.component(.hour, from: payload.proposedDate)
            let minute = Calendar.current.component(.minute, from: payload.proposedDate)
            XCTAssertEqual(hour, 19)
            XCTAssertEqual(minute, 0)
        }
    }

    func testLowRecoveryDoesNotInventCyclingFromHistory() {
        let now = date(2026, 7, 31, 8, 0) // Friday
        let rideTemplate = SimilarDayTemplate(
            dayKey: "2026-07-24",
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [
                CoachPlannedActivitySnapshot(
                    id: "ride-hist",
                    date: date(2026, 7, 24, 10, 0),
                    type: "workout",
                    title: "Morning Ride",
                    durationMinutes: 45,
                    icon: "figure.outdoor.cycle",
                    imageName: "workout-cycling",
                    isCompleted: true,
                    isSkipped: false,
                    source: "planner"
                )
            ]
        )
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: true,
                tomorrowDemand: .none,
                today: [],
                templates: [rideTemplate]
            )
        )
        XCTAssertFalse(proposal.changes.contains {
            guard case .createPlannedActivity(let p) = $0.payload else { return false }
            let blob = "\(p.title) \(p.activityType)".lowercased()
            return blob.contains("ride") || blob.contains("cycl") || blob.contains("bike")
        })
    }

    func testColdStartOffersOptionalWalkOnEmptyWeekday() {
        let now = date(2026, 7, 31, 8, 0) // Friday
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .good,
                yesterdayHeavy: false,
                tomorrowDemand: .none,
                today: [],
                templates: []
            )
        )
        let walks = proposal.changes.filter { $0.kind == .createRecoveryWalk }
        XCTAssertEqual(walks.count, 1, "Cold start should offer at least an optional Walk")
        XCTAssertEqual(walks.first?.isSelected, false, "Cold-start Walk must stay unselected")
        XCTAssertEqual(walks.first?.defaultSelected, false)
    }

    func testWeekdayWithHistoryButNoWalkHabitDoesNotInventEveningWalk() {
        let now = date(2026, 7, 31, 8, 0) // Friday
        let mealOnlyTemplate = SimilarDayTemplate(
            dayKey: "2026-07-24",
            recoveryBand: .moderate,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [
                CoachPlannedActivitySnapshot(
                    id: "meal-hist",
                    date: date(2026, 7, 24, 12, 0),
                    type: "meal",
                    title: "Lunch",
                    durationMinutes: 20,
                    icon: "fork.knife",
                    imageName: "",
                    isCompleted: true,
                    isSkipped: false,
                    source: "planner"
                )
            ]
        )
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: true,
                tomorrowDemand: .none,
                today: [],
                templates: [mealOnlyTemplate]
            )
        )
        XCTAssertTrue(
            proposal.changes.contains { $0.kind == .createRecoveryWalk },
            "After a hard day, a weekday without walk habit should still offer an easy recovery walk"
        )
    }

    func testWeekdayWithoutHeavyYesterdayDoesNotInventEveningWalk() {
        let now = date(2026, 7, 31, 8, 0) // Friday
        let mealOnlyTemplate = SimilarDayTemplate(
            dayKey: "2026-07-24",
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [
                CoachPlannedActivitySnapshot(
                    id: "meal-hist",
                    date: date(2026, 7, 24, 12, 0),
                    type: "meal",
                    title: "Lunch",
                    durationMinutes: 20,
                    icon: "fork.knife",
                    imageName: "",
                    isCompleted: true,
                    isSkipped: false,
                    source: "planner"
                )
            ]
        )
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .good,
                yesterdayHeavy: false,
                tomorrowDemand: .none,
                today: [],
                templates: [mealOnlyTemplate]
            )
        )
        XCTAssertFalse(
            proposal.changes.contains { $0.kind == .createRecoveryWalk },
            "Non-cold-start weekday without walk habit must not invent Walk@18"
        )
    }

    func testEmptyMealLibraryKeepsMorningFuelGuidance() {
        let now = date(2026, 7, 31, 8, 0)
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: true,
                tomorrowDemand: .none,
                today: [],
                templates: []
            )
        )
        let fuelTips = proposal.changes.filter {
            guard case .guidanceOnly(let payload) = $0.payload else { return false }
            switch payload.guidanceCode {
            case .morningFuelWithoutLibrary, .morningFuelGentleRecovery, .morningFuelSteadyEnergy:
                return true
            default:
                return false
            }
        }
        XCTAssertFalse(fuelTips.isEmpty, "Empty meal library should still surface morning fuel guidance")
        XCTAssertEqual(proposal.status, .proposalReady)
    }

    func testColdStartOmitsSoftGuidanceOverlay() {
        let now = date(2026, 7, 31, 8, 0) // Friday
        let proposal = MorningProposalEngine.generate(
            input: makeEngineInput(
                now: now,
                recoveryBand: .low,
                yesterdayHeavy: true,
                tomorrowDemand: .hard,
                today: [],
                templates: []
            )
        )
        XCTAssertTrue(
            proposal.changes.contains { $0.kind == .createRecoveryWalk },
            "Cold start should still surface an optional Walk"
        )

        // Soft body tips must not become Review inventory on cold start.
        // Empty-library fuel tips (and weather) may still surface as actionable guidance.
        let softGuidance = proposal.changes.filter { change in
            guard case .guidanceOnly(let payload) = change.payload else { return false }
            switch payload.guidanceCode {
            case .listenToBodyOnLowReadiness,
                 .easeIntoFirstEffort,
                 .hydrateThroughMorning,
                 .fuelBeforeSession,
                 .protectTomorrowFreshness:
                return true
            default:
                return false
            }
        }
        XCTAssertTrue(softGuidance.isEmpty, "Soft cold-start tips must not surface as Morning Adjustments inventory")

        let mutating = proposal.changes.filter { $0.kind != .guidanceOnly }
        if mutating.isEmpty, !MorningProposalPresenter.hasConfidentProposal(proposal) {
            XCTAssertEqual(proposal.status, .noChangesNeeded)
            XCTAssertEqual(MorningProposalPresenter.chromeState(for: proposal), .hidden)
        } else if !mutating.isEmpty || MorningProposalPresenter.hasConfidentProposal(proposal) {
            XCTAssertEqual(proposal.status, .proposalReady)
            XCTAssertNotEqual(MorningProposalPresenter.chromeState(for: proposal), .hidden)
        }
    }

    // MARK: - Helpers

    private func makeContext(
        recoveryBand: ProposalRecoveryBandToken,
        yesterdayHeavy: Bool,
        tomorrowDemand: CoachTomorrowDemand,
        openCount: Int,
        sleepPresence: ProposalSleepPresenceToken = .present,
        freshness: ProposalContextConfidence = .high,
        canMutate: Bool = true,
        mode: MorningProposalGenerationMode? = nil,
        templates: [SimilarDayTemplate] = [],
        preferAvoidHardLoadOnLowRecovery: Bool = false
    ) -> DailyContext {
        let opens = (0..<openCount).map { snap("open-\($0)", day: 29, hour: 10 + $0, title: "Session \($0)", completed: false) }
        let resolvedMode = mode ?? MorningProposalGenerationModeResolver.resolve(
            openCount: openCount,
            hasCompletedOrPartialToday: false,
            isMorningWindow: true
        )
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: opens,
            tomorrowSnapshots: [],
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            scenarioKey: "none",
            yesterdayHeavy: yesterdayHeavy,
            generationMode: resolvedMode
        )
        return DailyContext(
            now: date(2026, 7, 29, 7, 0),
            dayKey: "2026-07-29",
            isMorningEligible: true,
            hasCompletedOrPartialToday: false,
            generationMode: resolvedMode,
            contextFreshness: freshness,
            recoveryBand: recoveryBand,
            recoveryPercent: nil,
            recoveryAvailable: recoveryBand != .unavailable,
            sleepPresence: sleepPresence,
            sleepHours: sleepPresence == .present ? 7 : nil,
            yesterdayHeavy: yesterdayHeavy,
            stackedLoad: .unavailable,
            tomorrowDemand: tomorrowDemand,
            scenarioKey: nil,
            todayActivities: opens,
            tomorrowActivities: [],
            todayOpen: opens,
            todaySeriousOpen: opens.filter { CoachActivityClassifier.isSeriousTraining($0) },
            hasExistingMovement: false,
            completedWalkToday: false,
            totalPlannedDurationMinutes: opens.reduce(0) { $0 + $1.durationMinutes },
            recentDayTemplates: templates,
            historicalObservationRevision: "none",
            behavioralGeneration: 0,
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false,
            softDismissCount: 0,
            softNegativePenalty: 0,
            preferAvoidHardLoadOnLowRecovery: preferAvoidHardLoadOnLowRecovery,
            mealLibrary: [],
            mealLibraryRevision: "0",
            weatherRiskToken: .unavailable,
            canMutate: canMutate,
            fingerprint: fingerprint
        )
    }

    private func makeEngineInput(
        now: Date,
        recoveryBand: ProposalRecoveryBandToken,
        yesterdayHeavy: Bool,
        tomorrowDemand: CoachTomorrowDemand,
        today: [CoachPlannedActivitySnapshot],
        templates: [SimilarDayTemplate] = []
    ) -> MorningProposalEngineInput {
        let mode = MorningProposalGenerationModeResolver.resolve(
            openCount: today.filter { !$0.isCompleted && !$0.isSkipped }.count,
            hasCompletedOrPartialToday: today.contains { $0.isCompleted },
            isMorningWindow: true
        )
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: now)
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: today,
            tomorrowSnapshots: [],
            recoveryBand: recoveryBand,
            sleepPresence: .present,
            scenarioKey: CoachScenarioKey.lowRecoveryPrep.rawValue,
            yesterdayHeavy: yesterdayHeavy,
            observationContextRevision: ProposalObservationContextRevision.make(from: templates),
            generationMode: mode
        )
        return MorningProposalEngineInput(
            now: now,
            dayKey: dayKey,
            fingerprint: fingerprint,
            scenarioKey: .lowRecoveryPrep,
            recoveryBand: recoveryBand,
            sleepPresence: .present,
            yesterdayHeavy: yesterdayHeavy,
            tomorrowDemand: tomorrowDemand,
            stackedLoad: .unavailable,
            generationMode: mode,
            todayActivities: today,
            tomorrowActivities: [],
            completedWalkToday: false,
            canMutate: true,
            recentDayTemplates: templates,
            mealLibrary: [],
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false
        )
    }

    private func scoredWalk(id: String = "walk") -> ScoredCandidate {
        let candidate = ProposalCandidate(
            id: id,
            source: .recoveryMovement,
            kind: .createRecoveryWalk,
            payload: .createRecoveryWalk(
                CreateRecoveryWalkPayload(proposedDate: Date(), durationMinutes: 20, title: "Walk", activityType: "recovery")
            ),
            compatibleStrategies: [.recover, .maintain],
            physiologicalFit: .strong,
            confidence: 0.8,
            burden: .low,
            reasonCodes: [.recoveryWalkSupport],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            identityKey: "walk:\(id)"
        )
        return ScoredCandidate(
            candidate: candidate,
            breakdown: CandidateScoreBreakdown(
                physiologicalFit: 22, strategyFit: 18, historicalSuccess: 0,
                behavioralLikelihood: 8, tomorrowProtection: 0, usualTimeFit: 0,
                rejectionPenalty: 0, confidencePenalty: 0, conflictPenalty: 0, fatiguePenalty: 0
            )
        )
    }

    private func snap(
        _ id: String,
        day: Int,
        hour: Int = 10,
        title: String,
        duration: Int = 45,
        completed: Bool
    ) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: id,
            date: date(2026, 7, day, hour, 0),
            type: "workout",
            title: title,
            durationMinutes: duration,
            icon: "figure.run",
            imageName: "",
            isCompleted: completed,
            isSkipped: false,
            source: "planner"
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return Calendar.current.date(from: comps) ?? Date()
    }
}
