import Foundation
import XCTest
@testable import WeekFit

final class MorningAdjustmentsMovementPhaseBTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        CoachAdjustmentProvenanceStore.resetAllForTests()
        ProposalOfferHistoryStore.resetAllForTests()
    }

    override func tearDown() {
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        CoachAdjustmentProvenanceStore.resetAllForTests()
        ProposalOfferHistoryStore.resetAllForTests()
        super.tearDown()
    }

    // MARK: Storage

    func testOneRecordPerDayMergeDoesNotDuplicate() {
        let record = sampleRecord(dayKey: "2026-08-15")
        MorningAdjustmentDayHistoryStore.upsert(record)
        MorningAdjustmentDayHistoryStore.upsert(record)
        XCTAssertEqual(MorningAdjustmentDayHistoryStore.allRecords().count, 1)
    }

    func testNinetyDayCleanup() {
        MorningAdjustmentDayHistoryStore.seedForTests([
            sampleRecord(dayKey: "2026-04-01"),
            sampleRecord(dayKey: "2026-08-01")
        ])
        let ref = date(2026, 8, 22, 8, 0)
        MorningAdjustmentDayHistoryStore.purgeOlderThan(referenceDate: ref)
        let remaining = MorningAdjustmentDayHistoryStore.allRecords().map(\.dayKey)
        XCTAssertFalse(remaining.contains("2026-04-01"))
        XCTAssertTrue(remaining.contains("2026-08-01"))
    }

    func testSchemaDecodeRoundTrip() throws {
        let record = sampleRecord(dayKey: "2026-08-10")
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(MorningAdjustmentDayRecord.self, from: data)
        XCTAssertEqual(decoded.dayKey, record.dayKey)
        XCTAssertEqual(decoded.movementOutcomes[.yoga]?.completed, true)
    }

    // MARK: Family mapping

    func testFamilyMappingCoreFamilies() {
        XCTAssertEqual(RecoveryMovementFamilyResolver.family(for: CoachActivityType.walk), .walk)
        XCTAssertEqual(RecoveryMovementFamilyResolver.family(for: RecoveryMovementProvider.LightOption.stretch), .mobility)
        XCTAssertEqual(RecoveryMovementFamilyResolver.family(for: RecoveryMovementProvider.LightOption.yoga), .yoga)
        XCTAssertEqual(RecoveryMovementFamilyResolver.family(for: RecoveryMovementProvider.LightOption.breathing), .breathing)
        XCTAssertEqual(RecoveryMovementFamilyResolver.family(for: RecoveryMovementProvider.LightOption.easyRun), .easyRun)
        XCTAssertEqual(
            RecoveryMovementFamilyResolver.family(forActivityTypeRaw: "running", title: "Tempo Run"),
            .otherTraining
        )
        XCTAssertEqual(
            RecoveryMovementFamilyResolver.family(forActivityTypeRaw: "yoga", title: "Morning Yoga"),
            .yoga
        )
    }

    func testHistChangeNormalizesToFamily() {
        let candidate = ProposalCandidate(
            id: "hist-yoga-sat",
            source: .historicalActivity,
            kind: .createPlannedActivity,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: Date(),
                    durationMinutes: 25,
                    title: "Yoga",
                    activityType: "yoga",
                    icon: "figure.yoga",
                    imageName: "",
                    colorRed: 0.4,
                    colorGreen: 0.7,
                    colorBlue: 0.6,
                    sourceTemplateDayKey: "2026-08-09"
                )
            ),
            compatibleStrategies: [.recover],
            physiologicalFit: .strong,
            confidence: 0.8,
            burden: .low,
            reasonCodes: [.recoveryStretchSupport],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            identityKey: "yoga:hist"
        )
        XCTAssertEqual(RecoveryMovementFamilyResolver.family(for: candidate), .yoga)
    }

    // MARK: Outcomes

    func testOfferedOnlyNearNeutralSignal() {
        var outcome = MovementFamilyOutcome()
        outcome.offered = true
        XCTAssertEqual(SimilarDayAffinityScorer.outcomeSignal(outcome, daysAgo: 0), 0.5)
    }

    func testExplicitRejectionNegative() {
        var outcome = MovementFamilyOutcome()
        outcome.explicitlyRejected = true
        XCTAssertLessThan(SimilarDayAffinityScorer.outcomeSignal(outcome, daysAgo: 0), 0)
    }

    func testCompletedStrongerThanApplied() {
        var applied = MovementFamilyOutcome()
        applied.applied = true
        var completed = MovementFamilyOutcome()
        completed.completed = true
        completed.origin = .morningAdjustment
        XCTAssertGreaterThan(
            SimilarDayAffinityScorer.outcomeSignal(completed, daysAgo: 0),
            SimilarDayAffinityScorer.outcomeSignal(applied, daysAgo: 0)
        )
    }

    func testPartialCompletionReducedPositive() {
        var full = MovementFamilyOutcome()
        full.completed = true
        full.origin = .morningAdjustment
        var partial = MovementFamilyOutcome()
        partial.completed = true
        partial.partialCompletion = true
        partial.origin = .morningAdjustment
        XCTAssertGreaterThan(
            SimilarDayAffinityScorer.outcomeSignal(full, daysAgo: 0),
            SimilarDayAffinityScorer.outcomeSignal(partial, daysAgo: 0)
        )
    }

    func testUserPlannedCompletedCountsUserPlannedUncompletedDoesNot() {
        let completed = yogaSnapshot(completed: true)
        MorningAdjustmentDayHistoryCapture.captureUserPlannedCompletion(
            snapshot: completed,
            dayKey: "2026-08-12"
        )
        let record = MorningAdjustmentDayHistoryStore.record(for: "2026-08-12")
        XCTAssertEqual(record?.movementOutcomes[.yoga]?.origin, .userPlanned)
        XCTAssertTrue(record?.movementOutcomes[.yoga]?.completed == true)

        MorningAdjustmentDayHistoryStore.resetAllForTests()
        let uncompleted = yogaSnapshot(completed: false)
        MorningAdjustmentDayHistoryCapture.captureUserPlannedCompletion(
            snapshot: uncompleted,
            dayKey: "2026-08-13"
        )
        XCTAssertNil(MorningAdjustmentDayHistoryStore.record(for: "2026-08-13"))
    }

    // MARK: Similarity

    func testSameStrategyRecoveryWeatherOutranksUnrelatedDay() {
        let today = makeContext(recoveryBand: .moderate, outdoor: .adverse, recoveryPercent: 69)
        let similar = sampleRecord(
            dayKey: "2026-08-09",
            band: .moderate,
            outdoor: .adverse,
            percent: 68,
            strategy: .recover
        )
        let unrelated = sampleRecord(
            dayKey: "2026-08-08",
            band: .good,
            outdoor: .good,
            percent: 85,
            strategy: .train
        )
        let simScore = SimilarDayAffinityScorer.daySimilarity(
            record: similar,
            context: today,
            strategy: .recover
        )
        let unrelatedScore = SimilarDayAffinityScorer.daySimilarity(
            record: unrelated,
            context: today,
            strategy: .recover
        )
        XCTAssertGreaterThan(simScore, unrelatedScore)
    }

    func testRecentSimilarDayWeightedHigher() {
        var old = sampleRecord(dayKey: "2026-05-01")
        old.movementOutcomes[.yoga] = MovementFamilyOutcome(completed: true, origin: .morningAdjustment)
        var recent = sampleRecord(dayKey: "2026-08-15")
        recent.movementOutcomes[.yoga] = MovementFamilyOutcome(completed: true, origin: .morningAdjustment)
        MorningAdjustmentDayHistoryStore.seedForTests([old, recent])

        let context = makeContext(recoveryBand: .moderate, outdoor: .adverse, recoveryPercent: 69)
        let affinities = SimilarDayAffinityScorer.affinities(for: context, strategy: .recover)
        let yoga = affinities.first { $0.family == .yoga }
        XCTAssertGreaterThan(yoga?.score ?? 0, 0)
    }

    // MARK: Confidence

    func testZeroHistoryConfidenceNoneAndZeroBonus() {
        let context = makeContext(recoveryBand: .moderate, outdoor: .adverse)
        let affinities = SimilarDayAffinityScorer.affinities(for: context, strategy: .recover)
        XCTAssertTrue(affinities.allSatisfy { $0.confidence == .none })
        XCTAssertEqual(SimilarDayAffinityScorer.bonus(for: .yoga, affinities: affinities), 0)
    }

    func testWeakModerateStrongBonusCaps() {
        let weak = RecoveryMovementFamilyAffinity(family: .yoga, score: 20, sampleCount: 2, confidence: .weak)
        let moderate = RecoveryMovementFamilyAffinity(family: .yoga, score: 20, sampleCount: 4, confidence: .moderate)
        let strong = RecoveryMovementFamilyAffinity(family: .yoga, score: 30, sampleCount: 7, confidence: .strong)
        XCTAssertLessThanOrEqual(abs(SimilarDayAffinityScorer.bonus(for: .yoga, affinities: [weak])), 3)
        XCTAssertLessThanOrEqual(abs(SimilarDayAffinityScorer.bonus(for: .yoga, affinities: [moderate])), 6)
        XCTAssertLessThanOrEqual(abs(SimilarDayAffinityScorer.bonus(for: .yoga, affinities: [strong])), 10)
    }

    // MARK: Phase A golden compatibility

    func testEmptyHistoryMatchesPhaseAPickOption() {
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        let context = makeContext(recoveryBand: .moderate, outdoor: .adverse, recoveryPercent: 69)
        let eligible: [RecoveryMovementProvider.LightOption] = [.stretch, .yoga, .breathing]
        let withoutHistory = RecoveryMovementProvider.pickOption(
            eligible,
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )

        seedSimilarHistory(yogaCompletedDays: 0, stretchCompletedDays: 0)
        let withIrrelevantHistory = RecoveryMovementProvider.pickOption(
            eligible,
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertEqual(withoutHistory, withIrrelevantHistory)
    }

    // MARK: Safety

    func testUnsafeWeatherBlocksWalkDespiteHighWalkAffinity() {
        seedWalkAffinityHistory()
        let context = makeContext(recoveryBand: .moderate, outdoor: .unsafe)
        let eligible = RecoveryMovementProvider.eligibleOptions(
            context: context,
            strategy: .recover,
            allowWalk: false
        )
        XCTAssertFalse(eligible.contains(.walk))
    }

    func testRecoverStrategyNeverOffersEasyRunDespiteAffinity() {
        seedEasyRunAffinityHistory()
        let context = makeContext(recoveryBand: .good, outdoor: .good, yesterdayHeavy: false)
        let eligible = RecoveryMovementProvider.eligibleOptions(
            context: context,
            strategy: .recover,
            allowWalk: true
        )
        XCTAssertFalse(eligible.contains(.easyRun))
    }

    // MARK: Aug 22 personalized regression

    func testAug22PersonalizedHistoryPrefersYogaOverMobility() {
        seedAug22SimilarHistory()
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: .adverse,
            recoveryPercent: 69
        )
        let affinities = SimilarDayAffinityScorer.affinities(for: context, strategy: .recover)
        let yogaBonus = SimilarDayAffinityScorer.bonus(for: .yoga, affinities: affinities)
        let mobilityBonus = SimilarDayAffinityScorer.bonus(for: .mobility, affinities: affinities)
        XCTAssertGreaterThan(yogaBonus, mobilityBonus)

        let pick = RecoveryMovementProvider.pickOption(
            [.stretch, .yoga, .breathing],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertEqual(pick, .yoga)
    }

    func testAug22ZeroHistoryEqualsPhaseABehavior() {
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: .adverse,
            recoveryPercent: 69
        )
        let eligible: [RecoveryMovementProvider.LightOption] = [.stretch, .yoga, .breathing]
        let phaseAPick = rotatePhaseABaseline(eligible, dayKey: context.dayKey)

        seedAug22SimilarHistory()
        MorningAdjustmentDayHistoryStore.resetAllForTests()

        let actual = RecoveryMovementProvider.pickOption(
            eligible,
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertEqual(actual, phaseAPick)
    }

    func testAug22PersonalizedStillProducesMovementNotFuelOnly() {
        seedAug22SimilarHistory()
        let weather = makeWeatherSummary(tempC: 19, windKmh: 25.7, precip: 15, condition: .windy)
        let assessment = OutdoorSuitabilityResolver.assess(from: weather)
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: assessment.suitability,
            weatherRisk: assessment.riskToken,
            recoveryPercent: 69,
            mealLibrary: [meal("m1", "Recovery Bowl", time: "12:30", type: "recovery")]
        )
        let proposal = MorningProposalEngine.generate(
            input: MorningProposalEngineInput(
                now: context.now,
                dayKey: context.dayKey,
                fingerprint: context.fingerprint,
                scenarioKey: nil,
                recoveryBand: context.recoveryBand,
                sleepPresence: context.sleepPresence,
                yesterdayHeavy: context.yesterdayHeavy,
                tomorrowDemand: context.tomorrowDemand,
                stackedLoad: context.stackedLoad,
                generationMode: context.generationMode,
                todayActivities: context.todayActivities,
                tomorrowActivities: context.tomorrowActivities,
                completedWalkToday: context.completedWalkToday,
                canMutate: context.canMutate,
                recentDayTemplates: context.recentDayTemplates,
                mealLibrary: context.mealLibrary,
                walkRejectPenalty: context.walkRejectPenalty,
                stronglyRejectsWalk: context.stronglyRejectsWalk,
                weatherRiskToken: context.weatherRiskToken,
                outdoorSuitability: context.outdoorSuitability
            )
        )
        let mutations = proposal.changes.filter { $0.kind != .guidanceOnly }
        let hasMovement = mutations.contains {
            switch $0.kind {
            case .createRecoveryWalk, .createPlannedActivity, .modifyDuration, .moveActivity, .skipActivity:
                return true
            case .createMealFromLibrary, .guidanceOnly:
                return false
            }
        }
        XCTAssertTrue(hasMovement)
    }

    // MARK: Helpers

    private func sampleRecord(
        dayKey: String,
        band: ProposalRecoveryBandToken = .moderate,
        outdoor: OutdoorSuitability = .adverse,
        percent: Int = 69,
        strategy: DailyStrategy = .recover
    ) -> MorningAdjustmentDayRecord {
        var outcomes: [RecoveryMovementFamily: MovementFamilyOutcome] = [:]
        outcomes[.yoga] = MovementFamilyOutcome(completed: true, origin: .morningAdjustment)
        return MorningAdjustmentDayRecord(
            dayKey: dayKey,
            recordedAt: date(2026, 8, 22, 8, 0),
            weekday: 7,
            isWeekend: true,
            proposalTimeBucket: .morning,
            recoveryPercent: percent,
            recoveryBand: band,
            strategy: strategy,
            outdoorSuitability: outdoor,
            weatherRiskToken: .wind,
            yesterdayHeavy: true,
            previousDayLoad: .heavy,
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            existingPlanSuitability: .none,
            hadMorningProposal: true,
            movementOutcomes: outcomes
        )
    }

    private func seedAug22SimilarHistory() {
        let saturdays = ["2026-08-02", "2026-08-09", "2026-08-16", "2026-07-26"]
        var records: [MorningAdjustmentDayRecord] = []
        for (index, dayKey) in saturdays.enumerated() {
            var outcomes: [RecoveryMovementFamily: MovementFamilyOutcome] = [:]
            if index < 3 {
                outcomes[.yoga] = MovementFamilyOutcome(
                    completed: true,
                    origin: .morningAdjustment
                )
            } else {
                outcomes[.mobility] = MovementFamilyOutcome(
                    completed: true,
                    origin: .morningAdjustment
                )
            }
            records.append(
                MorningAdjustmentDayRecord(
                    dayKey: dayKey,
                    recordedAt: date(2026, 8, 22, 8, 0),
                    weekday: 7,
                    isWeekend: true,
                    proposalTimeBucket: .morning,
                    recoveryPercent: 68,
                    recoveryBand: .moderate,
                    strategy: .recover,
                    outdoorSuitability: .adverse,
                    weatherRiskToken: .wind,
                    yesterdayHeavy: true,
                    previousDayLoad: .heavy,
                    stackedLoad: .unavailable,
                    tomorrowDemand: .none,
                    existingPlanSuitability: .none,
                    hadMorningProposal: true,
                    movementOutcomes: outcomes
                )
            )
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func seedSimilarHistory(yogaCompletedDays: Int, stretchCompletedDays: Int) {
        // Irrelevant days below similarity threshold.
        let records = (0..<3).map { index in
            sampleRecord(
                dayKey: "2026-01-\(index + 1)",
                band: .good,
                outdoor: .good,
                percent: 90,
                strategy: .train
            )
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func seedWalkAffinityHistory() {
        let records = (0..<6).map { index in
            var record = sampleRecord(dayKey: "2026-08-\(index + 1)")
            record.movementOutcomes[.walk] = MovementFamilyOutcome(
                completed: true,
                origin: .morningAdjustment
            )
            return record
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func seedEasyRunAffinityHistory() {
        let records = (0..<6).map { index in
            var record = sampleRecord(dayKey: "2026-08-\(index + 10)")
            record.movementOutcomes[.easyRun] = MovementFamilyOutcome(
                completed: true,
                origin: .morningAdjustment
            )
            return record
        }
        MorningAdjustmentDayHistoryStore.seedForTests(records)
    }

    private func rotatePhaseABaseline(
        _ options: [RecoveryMovementProvider.LightOption],
        dayKey: String
    ) -> RecoveryMovementProvider.LightOption? {
        guard !options.isEmpty else { return nil }
        let bucket = abs(dayKey.utf8.reduce(0) { partial, byte in
            Int(truncatingIfNeeded: (UInt64(partial) &* 31) &+ UInt64(byte))
        })
        return options[bucket % options.count]
    }

    private func yogaSnapshot(completed: Bool) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: "yoga-user",
            date: date(2026, 8, 12, 9, 0),
            type: "yoga",
            title: "Morning Yoga",
            durationMinutes: 25,
            icon: "figure.yoga",
            imageName: "",
            isCompleted: completed,
            isSkipped: false,
            source: "planner",
            actualDurationMinutes: completed ? 25 : nil
        )
    }

    private func makeContext(
        recoveryBand: ProposalRecoveryBandToken,
        outdoor: OutdoorSuitability,
        weatherRisk: ProposalWeatherRiskToken = .unavailable,
        yesterdayHeavy: Bool = true,
        recoveryPercent: Int? = nil,
        mealLibrary: [ProposalMealCandidate] = []
    ) -> DailyContext {
        let mode = MorningProposalGenerationMode.compose
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-08-22",
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: recoveryBand,
            sleepPresence: .present,
            scenarioKey: "none",
            yesterdayHeavy: yesterdayHeavy,
            generationMode: mode
        )
        return DailyContext(
            now: date(2026, 8, 22, 8, 0),
            dayKey: "2026-08-22",
            isMorningEligible: true,
            hasCompletedOrPartialToday: false,
            generationMode: mode,
            contextFreshness: .high,
            recoveryBand: recoveryBand,
            recoveryPercent: recoveryPercent ?? 69,
            recoveryAvailable: true,
            sleepPresence: .present,
            sleepHours: 7.2,
            yesterdayHeavy: yesterdayHeavy,
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            scenarioKey: nil,
            todayActivities: [],
            tomorrowActivities: [],
            todayOpen: [],
            todaySeriousOpen: [],
            hasExistingMovement: false,
            completedWalkToday: false,
            totalPlannedDurationMinutes: 0,
            recentDayTemplates: [],
            historicalObservationRevision: "obs",
            behavioralGeneration: 0,
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false,
            softDismissCount: 0,
            softNegativePenalty: 0,
            preferAvoidHardLoadOnLowRecovery: false,
            mealLibrary: mealLibrary,
            mealLibraryRevision: "1",
            weatherRiskToken: weatherRisk,
            outdoorSuitability: outdoor,
            existingPlanMovementSuitability: .none,
            canMutate: true,
            fingerprint: fingerprint
        )
    }

    private func meal(
        _ id: String,
        _ title: String,
        time: String,
        type: String
    ) -> ProposalMealCandidate {
        ProposalMealCandidate(
            id: id,
            title: title,
            imageName: "",
            calories: 400,
            protein: 25,
            carbs: 40,
            fats: 12,
            fiber: 6,
            mealsTypeRaw: type,
            suggestedTime: time
        )
    }

    private func makeWeatherSummary(
        tempC: Double,
        windKmh: Double,
        precip: Int?,
        condition: WeekFitWeatherCondition
    ) -> WeekFitWeatherSummary {
        WeekFitWeatherSummary(
            temperature: Measurement(value: tempC, unit: UnitTemperature.celsius),
            feelsLike: Measurement(value: tempC, unit: UnitTemperature.celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "wind",
            condition: condition,
            isDaylight: true,
            humidityPercent: 45,
            windSpeed: Measurement(value: windKmh, unit: UnitSpeed.kilometersPerHour),
            uvIndex: 3,
            precipitationChance: precip
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

private extension MovementFamilyOutcome {
    init(
        completed: Bool = false,
        partialCompletion: Bool = false,
        origin: MovementBehaviorOrigin? = nil
    ) {
        self.init()
        self.completed = completed
        self.partialCompletion = partialCompletion
        self.origin = origin
    }
}
