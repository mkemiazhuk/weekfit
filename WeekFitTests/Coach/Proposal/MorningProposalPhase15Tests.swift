import Foundation
import WeekFitPlanner
import XCTest
@testable import WeekFit

final class MorningProposalPhase15Tests: XCTestCase {

    override func tearDown() {
        MorningProposalStore.resetAllForTests()
        CoachObservationStore.resetForTests()
        ProposalBehavioralPreferences.resetAllForTests()
        CoachDecisionHistoryStore.resetAllForTests()
        super.tearDown()
    }

    // MARK: - Historical Recovery

    func testExactRecoveryBandMatchScoresHighest() {
        let todayWeekday = Calendar.current.component(.weekday, from: date(2026, 7, 29, 7, 0))
        let exact = template(
            dayKey: "2026-07-20",
            band: .moderate,
            observationAvailable: true,
            activities: [activity(id: "a", day: 20, title: "Easy Walk", type: "recovery", completed: true)]
        )
        let far = template(
            dayKey: "2026-07-21",
            band: .good,
            observationAvailable: true,
            activities: [activity(id: "b", day: 21, title: "Easy Walk", type: "recovery", completed: true)]
        )
        let exactScore = SimilarDayPlanMiner.scoreTemplate(exact, todayBand: .moderate, todayWeekday: todayWeekday)!
        let farScore = SimilarDayPlanMiner.scoreTemplate(far, todayBand: .moderate, todayWeekday: todayWeekday)!
        XCTAssertGreaterThan(exactScore.bandScore, farScore.bandScore)
        XCTAssertGreaterThan(exactScore.finalScore, farScore.finalScore)
    }

    func testNearbyRecoveryBandMatchBeatsUnavailable() {
        let todayWeekday = Calendar.current.component(.weekday, from: date(2026, 7, 29, 7, 0))
        let nearby = template(
            dayKey: "2026-07-20",
            band: .good,
            observationAvailable: true,
            activities: [activity(id: "a", day: 20, title: "Ride", type: "recovery", completed: true)]
        )
        let missing = template(
            dayKey: "2026-07-21",
            band: .unavailable,
            observationAvailable: false,
            activities: [activity(id: "b", day: 21, title: "Ride", type: "recovery", completed: true)]
        )
        let nearbyScore = SimilarDayPlanMiner.scoreTemplate(nearby, todayBand: .moderate, todayWeekday: todayWeekday)!
        let missingScore = SimilarDayPlanMiner.scoreTemplate(missing, todayBand: .moderate, todayWeekday: todayWeekday)!
        XCTAssertEqual(missingScore.confidencePenalty, 6)
        XCTAssertGreaterThan(nearbyScore.finalScore, missingScore.finalScore)
    }

    func testMissingHistoricalObservationAppliesConfidencePenalty() {
        let todayWeekday = 4
        let missing = template(
            dayKey: "2026-07-10",
            band: .unavailable,
            observationAvailable: false,
            activities: [activity(id: "a", day: 10, title: "Yoga", type: "recovery", completed: true)]
        )
        let score = SimilarDayPlanMiner.scoreTemplate(missing, todayBand: .low, todayWeekday: todayWeekday)!
        XCTAssertFalse(score.observationAvailable)
        XCTAssertEqual(score.confidencePenalty, 6)
        XCTAssertEqual(score.bandScore, 1)
    }

    func testStaleMismatchedDayKeyDoesNotJoinObservation() {
        CoachObservationStore.seedForTests([
            CoachDailyObservation(dayKey: "2026-07-15", sleepMinutes: 420, recoveryPercent: 80)
        ])
        // Template claims a different key than seeded observation.
        let template = SimilarDayTemplate(
            dayKey: "2026-07-16",
            recoveryBand: .unavailable,
            observationAvailable: false,
            sleepPresence: .unavailable,
            activities: [activity(id: "a", day: 16, title: "Swim", completed: true)]
        )
        XCTAssertNil(CoachObservationStore.observation(for: template.dayKey))
        let score = SimilarDayPlanMiner.scoreTemplate(template, todayBand: .good, todayWeekday: 4)!
        XCTAssertEqual(score.confidencePenalty, 6)
    }

    func testDifferentHistoricalBandsChangeWinner() {
        let weekday = Calendar.current.component(.weekday, from: date(2026, 7, 22, 10, 0))
        let lowDay = template(
            dayKey: "2026-07-22",
            band: .low,
            observationAvailable: true,
            activities: [
                activity(id: "walk", day: 22, title: "Recovery Walk", type: "recovery", completed: true)
            ]
        )
        let goodDay = template(
            dayKey: "2026-07-15",
            band: .good,
            observationAvailable: true,
            activities: [
                activity(id: "tempo", day: 15, title: "Tempo Run", completed: true)
            ]
        )

        let lowWinner = SimilarDayPlanMiner.bestTemplate(
            todayBand: .low,
            todayWeekday: weekday,
            candidates: [lowDay, goodDay]
        )
        let goodWinner = SimilarDayPlanMiner.bestTemplate(
            todayBand: .good,
            todayWeekday: weekday,
            candidates: [lowDay, goodDay]
        )
        XCTAssertEqual(lowWinner?.template.dayKey, "2026-07-22")
        XCTAssertEqual(goodWinner?.template.dayKey, "2026-07-15")
    }

    func testDeterministicTieBreakingPrefersObservationThenDayKey() {
        let weekday = 3
        let a = template(
            dayKey: "2026-07-10",
            band: .moderate,
            observationAvailable: false,
            activities: [activity(id: "a", day: 10, title: "Easy Walk", type: "recovery", completed: true)]
        )
        let b = template(
            dayKey: "2026-07-11",
            band: .moderate,
            observationAvailable: true,
            activities: [activity(id: "b", day: 11, title: "Easy Walk", type: "recovery", completed: true)]
        )
        // Equal band + quality → observation available wins.
        let winner = SimilarDayPlanMiner.bestTemplate(
            todayBand: .moderate,
            todayWeekday: weekday,
            candidates: [a, b]
        )
        XCTAssertEqual(winner?.template.dayKey, "2026-07-11")
    }

    // MARK: - Generation modes

    func testModeBoundaries() {
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 0, hasCompletedOrPartialToday: false, isMorningWindow: true),
            .compose
        )
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 1, hasCompletedOrPartialToday: false, isMorningWindow: true),
            .compose
        )
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 2, hasCompletedOrPartialToday: false, isMorningWindow: true),
            .optimize
        )
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 3, hasCompletedOrPartialToday: false, isMorningWindow: true),
            .optimize
        )
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 4, hasCompletedOrPartialToday: false, isMorningWindow: true),
            .protect
        )
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 0, hasCompletedOrPartialToday: true, isMorningWindow: true),
            .closed
        )
        XCTAssertEqual(
            MorningProposalGenerationModeResolver.resolve(openCount: 0, hasCompletedOrPartialToday: false, isMorningWindow: false),
            .closed
        )
    }

    func testProtectModeDoesNotCreateSeriousActivityOrWalk() {
        let now = date(2026, 7, 29, 7, 0)
        let items = (0..<4).map { index in
            activity(id: "open-\(index)", day: 29, hour: 10 + index, title: "Session \(index)", completed: false)
        }
        let historical = template(
            dayKey: "2026-07-20",
            band: .moderate,
            observationAvailable: true,
            activities: [activity(id: "hist", day: 20, title: "Hard Intervals", completed: true)]
        )
        let proposal = MorningProposalEngine.generate(
            input: makeInput(
                now: now,
                recoveryBand: .moderate,
                generationMode: .protect,
                todayActivities: items,
                recentDayTemplates: [historical]
            )
        )
        XCTAssertFalse(proposal.changes.contains { $0.kind == .createPlannedActivity })
        XCTAssertFalse(proposal.changes.contains { $0.kind == .createRecoveryWalk })
    }

    func testClosedModeProducesEmptyUnavailableOrClosed() {
        let now = date(2026, 7, 29, 7, 0)
        let done = activity(id: "done", day: 29, title: "AM Run", completed: true)
        let proposal = MorningProposalEngine.generate(
            input: makeInput(
                now: now,
                recoveryBand: .good,
                generationMode: .closed,
                todayActivities: [done],
                canMutate: false
            )
        )
        XCTAssertTrue(proposal.changes.isEmpty)
        XCTAssertEqual(proposal.status, .unavailable)
    }

    // MARK: - Walk policy

    func testWalkOmitsWhenMovementAlreadyExists() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .compose,
            recoveryBand: .low,
            sleepPresence: .present,
            todayOpen: [activity(id: "run", day: 29, title: "Easy Run", completed: false)],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: false,
            confidence: .high,
            stronglyRejectsWalk: false
        )
        XCTAssertEqual(decision, .omit)
    }

    func testRepeatedWalkRejectionBecomesGuidance() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .compose,
            recoveryBand: .moderate,
            sleepPresence: .present,
            todayOpen: [],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: false,
            confidence: .high,
            stronglyRejectsWalk: true
        )
        XCTAssertEqual(decision, .guidance)
    }

    func testEmptyPlanAloneDoesNotForceSelectedWalkOnGoodRecovery() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .compose,
            recoveryBand: .good,
            sleepPresence: .present,
            todayOpen: [],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: false,
            confidence: .high,
            stronglyRejectsWalk: false
        )
        XCTAssertNotEqual(decision, .selected)
    }

    func testRecoveryWalkSelectedUnderStrongEvidence() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .compose,
            recoveryBand: .low,
            sleepPresence: .present,
            todayOpen: [],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: true,
            confidence: .high,
            stronglyRejectsWalk: false
        )
        XCTAssertEqual(decision, .selected)
    }

    func testSpeculativeWalkUnselectedOnMediumConfidence() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .compose,
            recoveryBand: .moderate,
            sleepPresence: .present,
            todayOpen: [],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: false,
            confidence: .medium,
            stronglyRejectsWalk: false
        )
        XCTAssertEqual(decision, .unselected)
    }

    func testProtectModeOmitsWalk() {
        let decision = MorningProposalWalkPolicy.decide(
            mode: .protect,
            recoveryBand: .low,
            sleepPresence: .present,
            todayOpen: [],
            completedWalkToday: false,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: true,
            confidence: .high,
            stronglyRejectsWalk: false
        )
        XCTAssertEqual(decision, .omit)
    }

    // MARK: - Default selection

    func testDefaultSelectionMatrix() {
        let input = makeInput(
            now: date(2026, 7, 29, 7, 0),
            recoveryBand: .low,
            yesterdayHeavy: true,
            tomorrowDemand: .hard,
            stackedLoad: .elevated,
            generationMode: .compose,
            todayActivities: []
        )
        let confidence = MorningProposalDefaultSelection.ConfidenceBucket.high

        let shorten = CoachProposedChange(
            id: "1", kind: .modifyDuration, reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(ModifyDurationPayload(activityId: "a", originalDurationMinutes: 60, proposedDurationMinutes: 45)),
            defaultSelected: false, isSelected: false, sortTime: Date(), evidenceScenarioKey: nil
        )
        XCTAssertTrue(
            MorningProposalDefaultSelection.shouldSelect(
                change: shorten, input: input, mode: .compose, confidence: confidence, stronglyRejectsWalk: false
            )
        )

        let create = CoachProposedChange(
            id: "2", kind: .createPlannedActivity, reasonCode: .similarDaySupport,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: Date(), durationMinutes: 40, title: "Run", activityType: "workout",
                    icon: "figure.run", imageName: "", colorRed: 0, colorGreen: 0, colorBlue: 0,
                    sourceTemplateDayKey: "2026-07-01"
                )
            ),
            defaultSelected: true, isSelected: true, sortTime: Date(), evidenceScenarioKey: nil
        )
        XCTAssertFalse(
            MorningProposalDefaultSelection.shouldSelect(
                change: create, input: input, mode: .compose, confidence: confidence, stronglyRejectsWalk: false
            )
        )

        let mealHigh = CoachProposedChange(
            id: "3", kind: .createMealFromLibrary, reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "m1", title: "Oats", proposedDate: Date(), durationMinutes: 15,
                    calories: 400, protein: 20, carbs: 50, fats: 10, fiber: 5, imageName: ""
                )
            ),
            defaultSelected: false, isSelected: false, sortTime: Date(), evidenceScenarioKey: nil
        )
        XCTAssertTrue(
            MorningProposalDefaultSelection.shouldSelect(
                change: mealHigh, input: input, mode: .compose, confidence: .high, stronglyRejectsWalk: false
            )
        )
        XCTAssertFalse(
            MorningProposalDefaultSelection.shouldSelect(
                change: mealHigh, input: input, mode: .compose, confidence: .medium, stronglyRejectsWalk: false
            )
        )

        let skip = CoachProposedChange(
            id: "4", kind: .skipActivity, reasonCode: .heavyYesterdayProtection,
            payload: .skipActivity(SkipActivityPayload(activityId: "a", originalDate: Date())),
            defaultSelected: false, isSelected: false, sortTime: Date(), evidenceScenarioKey: nil
        )
        XCTAssertTrue(
            MorningProposalDefaultSelection.shouldSelect(
                change: skip, input: input, mode: .compose, confidence: .high, stronglyRejectsWalk: false
            )
        )

        let guidance = CoachProposedChange(
            id: "5", kind: .guidanceOnly, reasonCode: .insufficientConfidence,
            payload: .guidanceOnly(GuidanceOnlyPayload(guidanceCode: .easeIntoFirstEffort, relatedActivityId: nil)),
            defaultSelected: true, isSelected: true, sortTime: Date(), evidenceScenarioKey: nil
        )
        XCTAssertFalse(
            MorningProposalDefaultSelection.shouldSelect(
                change: guidance, input: input, mode: .compose, confidence: .high, stronglyRejectsWalk: false
            )
        )
    }

    // MARK: - Tomorrow / yesterday

    func testHardTomorrowBlocksSeriousTemplateAdds() {
        let now = date(2026, 7, 29, 7, 0)
        let historical = template(
            dayKey: "2026-07-20",
            band: .good,
            observationAvailable: true,
            activities: [activity(id: "tempo", day: 20, title: "Tempo Run", completed: true)]
        )
        let result = FullDayProposalComposer.compose(
            now: now,
            dayKey: "2026-07-29",
            mode: .compose,
            recoveryBand: .good,
            sleepPresence: .present,
            todayActivities: [],
            recentTemplates: [historical],
            mealLibrary: [],
            scenarioKey: .stableDay,
            completedWalkToday: false,
            tomorrowDemand: .hard,
            walkDecision: .omit,
            confidence: .high
        )
        XCTAssertFalse(result.changes.contains { change in
            guard case .createPlannedActivity(let payload) = change.payload else { return false }
            return CoachActivityClassifier.isSeriousTraining(
                CoachPlannedActivitySnapshot(
                    id: "tmp",
                    date: payload.proposedDate,
                    type: payload.activityType,
                    title: payload.title,
                    durationMinutes: payload.durationMinutes,
                    icon: payload.icon,
                    imageName: payload.imageName,
                    isCompleted: false,
                    isSkipped: false,
                    source: "planner"
                )
            )
        })
    }

    func testHeavyYesterdayShiftsDialBack() {
        let now = date(2026, 7, 29, 7, 0)
        let run = activity(id: "run", day: 29, hour: 18, title: "Evening Run", duration: 80, completed: false)
        let proposal = MorningProposalEngine.generate(
            input: makeInput(
                now: now,
                recoveryBand: .moderate,
                yesterdayHeavy: true,
                tomorrowDemand: .none,
                stackedLoad: .unavailable,
                generationMode: .compose,
                todayActivities: [run]
            )
        )
        XCTAssertTrue(proposal.changes.contains { $0.kind == .modifyDuration })
    }

    func testMissingStackedLoadStaysUnavailable() {
        let token = ProposalStackedLoadResolver.resolve(
            yesterdayHeavy: false,
            tomorrowDemand: .moderate,
            recoveryBand: .good,
            todaySeriousOpenCount: 0
        )
        XCTAssertEqual(token, .unavailable)
    }

    func testElevatedStackedLoadWhenEvidenceClear() {
        let token = ProposalStackedLoadResolver.resolve(
            yesterdayHeavy: true,
            tomorrowDemand: .hard,
            recoveryBand: .moderate,
            todaySeriousOpenCount: 1
        )
        XCTAssertEqual(token, .elevated)
    }

    // MARK: - Stale / behavioral

    func testPlanSignatureChangeMarksMaterialDifference() {
        let a = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: [activity(id: "a", day: 29, title: "A", completed: false)],
            tomorrowSnapshots: [],
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false
        )
        let b = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: [
                activity(id: "a", day: 29, title: "A", completed: false),
                activity(id: "b", day: 29, hour: 12, title: "B", completed: false)
            ],
            tomorrowSnapshots: [],
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false
        )
        XCTAssertTrue(a.materialDifference(from: b))
    }

    func testMarkStaleOnFingerprintMismatch() async {
        let dayKey = "2026-08-11"
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false
        )
        MorningProposalStore.upsert(
            MorningPlanProposal(
                id: "p-stale-1",
                dayKey: dayKey,
                generatedAt: Date(),
                status: .reviewing,
                fingerprint: fingerprint,
                changes: [],
                appliedAt: nil,
                dismissedAt: nil,
                lastErrorCode: nil,
                schemaVersion: 2
            )
        )
        let live = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false
        )
        XCTAssertTrue(fingerprint.materialDifference(from: live))
        await MainActor.run {
            MorningProposalService.markStaleIfNeeded(dayKey: dayKey, liveFingerprint: live)
        }
        let status = await MainActor.run {
            MorningProposalStore.proposal(for: dayKey)?.status
        }
        XCTAssertEqual(status, .stale)
    }

    func testBehavioralWalkPenaltyRequiresMinSamples() {
        var snapshot = ProposalBehavioralPreferences.Snapshot.empty
        snapshot.walkRejectCount = 2
        snapshot.walkAcceptCount = 0
        XCTAssertEqual(ProposalBehavioralPreferences.walkRejectPenalty(from: snapshot), 0)

        snapshot.walkRejectCount = 3
        XCTAssertGreaterThan(ProposalBehavioralPreferences.walkRejectPenalty(from: snapshot), 0)
        XCTAssertLessThanOrEqual(ProposalBehavioralPreferences.walkRejectPenalty(from: snapshot), 12)
    }

    func testQualityScoreRewardsCompletionAndPenalizesSkips() {
        let completed = [
            activity(id: "1", day: 1, title: "A", completed: true),
            activity(id: "2", day: 1, hour: 12, title: "B", completed: true)
        ]
        let skipped = [
            activity(id: "1", day: 1, title: "A", completed: false, skipped: true),
            activity(id: "2", day: 1, hour: 12, title: "B", completed: false, skipped: true),
            activity(id: "3", day: 1, hour: 14, title: "C", completed: false, skipped: true)
        ]
        XCTAssertGreaterThan(
            SimilarDayPlanMiner.qualityScore(for: completed),
            SimilarDayPlanMiner.qualityScore(for: skipped)
        )
    }

    // MARK: - Helpers

    private func makeInput(
        now: Date,
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken = .present,
        scenarioKey: CoachScenarioKey? = .stableDay,
        yesterdayHeavy: Bool = false,
        tomorrowDemand: CoachTomorrowDemand = .none,
        stackedLoad: ProposalStackedLoadToken = .unavailable,
        generationMode: MorningProposalGenerationMode,
        todayActivities: [CoachPlannedActivitySnapshot],
        tomorrowActivities: [CoachPlannedActivitySnapshot] = [],
        recentDayTemplates: [SimilarDayTemplate] = [],
        mealLibrary: [ProposalMealCandidate] = [],
        canMutate: Bool = true,
        walkRejectPenalty: Int = 0,
        stronglyRejectsWalk: Bool = false
    ) -> MorningProposalEngineInput {
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: todayActivities,
            tomorrowSnapshots: tomorrowActivities,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            scenarioKey: scenarioKey?.rawValue ?? "none",
            yesterdayHeavy: yesterdayHeavy,
            stackedLoad: stackedLoad,
            generationMode: generationMode
        )
        return MorningProposalEngineInput(
            now: now,
            dayKey: "2026-07-29",
            fingerprint: fingerprint,
            scenarioKey: scenarioKey,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            yesterdayHeavy: yesterdayHeavy,
            tomorrowDemand: tomorrowDemand,
            stackedLoad: stackedLoad,
            generationMode: generationMode,
            todayActivities: todayActivities,
            tomorrowActivities: tomorrowActivities,
            completedWalkToday: false,
            canMutate: canMutate,
            recentDayTemplates: recentDayTemplates,
            mealLibrary: mealLibrary,
            walkRejectPenalty: walkRejectPenalty,
            stronglyRejectsWalk: stronglyRejectsWalk
        )
    }

    private func template(
        dayKey: String,
        band: ProposalRecoveryBandToken,
        observationAvailable: Bool,
        activities: [CoachPlannedActivitySnapshot]
    ) -> SimilarDayTemplate {
        SimilarDayTemplate(
            dayKey: dayKey,
            recoveryBand: band,
            observationAvailable: observationAvailable,
            sleepPresence: observationAvailable ? .present : .unavailable,
            activities: activities
        )
    }

    private func activity(
        id: String,
        day: Int,
        hour: Int = 10,
        title: String,
        type: String = "workout",
        duration: Int = 45,
        completed: Bool,
        skipped: Bool = false
    ) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: id,
            date: date(2026, 7, day, hour, 0),
            type: type,
            title: title,
            durationMinutes: duration,
            icon: "figure.run",
            imageName: "",
            isCompleted: completed,
            isSkipped: skipped,
            source: "planner"
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return Calendar.current.date(from: comps) ?? Date()
    }
}
