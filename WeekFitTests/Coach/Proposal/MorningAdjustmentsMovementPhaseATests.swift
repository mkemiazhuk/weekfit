import Foundation
import XCTest
@testable import WeekFit

/// Phase A Morning Adjustments movement decision regressions.
final class MorningAdjustmentsMovementPhaseATests: XCTestCase {

    override func setUp() {
        super.setUp()
        MorningAdjustmentDayHistoryStore.resetAllForTests()
    }

    override func tearDown() {
        MorningAdjustmentDayHistoryStore.resetAllForTests()
        super.tearDown()
    }

    // MARK: Outdoor suitability

    func testWindyConditionIsAdverseEvenAtModerateWindSpeed() {
        let summary = makeWeatherSummary(tempC: 18, windKmh: 25.7, precip: 10, condition: .windy)
        let assessment = OutdoorSuitabilityResolver.assess(from: summary)
        XCTAssertEqual(assessment.suitability, .adverse)
        XCTAssertEqual(assessment.riskToken, .wind)
        XCTAssertNotEqual(assessment.suitability, .good)
        XCTAssertNotEqual(assessment.riskToken, .calm)
    }

    func testStormIsUnsafeAndBlocksOutdoorCreate() {
        let summary = makeWeatherSummary(tempC: 20, windKmh: 12, precip: 80, condition: .storm)
        let assessment = OutdoorSuitabilityResolver.assess(from: summary)
        XCTAssertEqual(assessment.suitability, .unsafe)
        XCTAssertFalse(assessment.suitability.allowsOutdoorCreate)
    }

    // MARK: Eligible set / ranking

    func testRecoverAdverseEmptyPlanInventIndoorMovement() {
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: .adverse,
            recoveryPercent: 69
        )
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(movement.isEmpty)
        XCTAssertTrue(movement.contains(where: isIndoorRecoveryCreate))
        XCTAssertFalse(movement.contains { $0.kind == .createRecoveryWalk })
    }

    func testRecoverUnsafeEmptyPlanInventIndoorOnly() {
        let context = makeContext(recoveryBand: .moderate, outdoor: .unsafe)
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(movement.isEmpty)
        XCTAssertTrue(movement.contains(where: isIndoorRecoveryCreate))
        XCTAssertFalse(movement.contains { $0.kind == .createRecoveryWalk })
    }

    func testRecoverGoodAndAcceptableEmptyPlanProduceMovement() {
        for outdoor in [OutdoorSuitability.good, .acceptable] {
            let context = makeContext(recoveryBand: .moderate, outdoor: outdoor)
            let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
            XCTAssertFalse(movement.isEmpty, "Expected movement for \(outdoor)")
        }
    }

    func testVeryLowRecoveryPrefersGentleIndoorOverWalk() {
        let context = makeContext(recoveryBand: .low, outdoor: .good)
        let eligible = RecoveryMovementProvider.eligibleOptions(
            context: context,
            strategy: .recover,
            allowWalk: true
        )
        let pick = RecoveryMovementProvider.pickOption(
            eligible,
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertNotNil(pick)
        XCTAssertNotEqual(pick, .walk)
        XCTAssertTrue(
            [RecoveryMovementProvider.LightOption.breathing, .stretch, .yoga].contains(pick!)
        )
    }

    func testEasyRunOnlyOnMaintainGoodNotHeavy() {
        let maintain = makeContext(recoveryBand: .good, outdoor: .good, yesterdayHeavy: false)
        XCTAssertTrue(
            RecoveryMovementProvider.eligibleOptions(
                context: maintain,
                strategy: .maintain,
                allowWalk: true
            ).contains(.easyRun)
        )
        let recover = makeContext(recoveryBand: .good, outdoor: .good, yesterdayHeavy: false)
        XCTAssertFalse(
            RecoveryMovementProvider.eligibleOptions(
                context: recover,
                strategy: .recover,
                allowWalk: true
            ).contains(.easyRun)
        )
    }

    // MARK: Existing plan suitability

    func testPlanClassifierYogaSuitableHardRunInappropriate() {
        let yoga = makeActivity(id: "y1", title: "Yoga", type: "yoga", minutes: 20)
        XCTAssertEqual(
            ExistingPlanMovementSuitabilityClassifier.classify(todayOpen: [yoga], strategy: .recover),
            .suitableLight
        )
        let hard = makeActivity(id: "r1", title: "Tempo Run", type: "running", minutes: 75)
        XCTAssertEqual(
            ExistingPlanMovementSuitabilityClassifier.classify(todayOpen: [hard], strategy: .recover),
            .inappropriateHard
        )
    }

    func testRecoverExistingYogaDoesNotInventDuplicate() {
        let yoga = makeActivity(id: "y1", title: "Yoga", type: "yoga", minutes: 20)
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: .good,
            todayOpen: [yoga],
            planSuitability: .suitableLight,
            hasExistingMovement: true
        )
        XCTAssertTrue(
            RecoveryMovementProvider.generate(context: context, strategy: .recover).isEmpty
        )
    }

    func testRecoverExistingRecoveryWalkDoesNotInventDuplicate() {
        let walk = makeActivity(id: "w1", title: "Recovery Walk", type: "walk", minutes: 25)
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: .good,
            todayOpen: [walk],
            planSuitability: .suitableLight,
            hasExistingMovement: true
        )
        XCTAssertTrue(
            RecoveryMovementProvider.generate(context: context, strategy: .recover).isEmpty
        )
    }

    func testRecoverInappropriateHardStillInventLight() {
        let hard = makeActivity(id: "r1", title: "Tempo Run", type: "running", minutes: 75)
        let context = makeContext(
            recoveryBand: .low,
            outdoor: .good,
            todayOpen: [hard],
            planSuitability: .inappropriateHard,
            hasExistingMovement: true
        )
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(movement.isEmpty, "Hard plan must not block recovery invent")
    }

    // MARK: Habit fallback

    func testHabitDetectedStillAllowsInventFallback() {
        let templates = [
            SimilarDayTemplate(
                dayKey: "2026-08-15",
                recoveryBand: .moderate,
                observationAvailable: true,
                sleepPresence: .present,
                activities: [
                    makeActivity(id: "habit-yoga", title: "Morning Yoga", type: "yoga", minutes: 25)
                ]
            )
        ]
        let context = makeContext(
            recoveryBand: .moderate,
            outdoor: .adverse,
            templates: templates
        )
        XCTAssertTrue(HabitualLightRecoveryDetector.hasWeekdayHabit(in: context))
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(movement.isEmpty, "Habit must not erase invent fallback")
    }

    // MARK: Cooloff / variety

    func testWalkCooloffPrefersAlternateRecoveryFamily() {
        ProposalOfferHistoryStore.resetAllForTests()
        defer { ProposalOfferHistoryStore.resetAllForTests() }

        let yesterday = date(2026, 8, 21, 8, 0)
        ProposalOfferHistoryStore.recordOffers(
            dayKey: "2026-08-21",
            changes: [
                CoachProposedChange(
                    id: "walk-recovery",
                    kind: .createRecoveryWalk,
                    reasonCode: .recoveryWalkSupport,
                    payload: .createRecoveryWalk(
                        CreateRecoveryWalkPayload(
                            proposedDate: yesterday,
                            durationMinutes: 25,
                            title: "Walk",
                            activityType: "recovery"
                        )
                    ),
                    defaultSelected: true,
                    isSelected: true,
                    sortTime: yesterday,
                    evidenceScenarioKey: nil
                )
            ],
            now: yesterday
        )

        let context = makeContext(recoveryBand: .moderate, outdoor: .good, yesterdayHeavy: false)
        let eligible = RecoveryMovementProvider.eligibleOptions(
            context: context,
            strategy: .recover,
            allowWalk: true
        )
        let pick = RecoveryMovementProvider.pickOption(
            eligible,
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertNotNil(pick)
        XCTAssertNotEqual(pick, .walk, "Recent walk offer should rotate to another recovery family")
    }

    func testOnlyWalkEligibleMayRepeatAfterCooloff() {
        ProposalOfferHistoryStore.resetAllForTests()
        defer { ProposalOfferHistoryStore.resetAllForTests() }

        let yesterday = date(2026, 8, 21, 8, 0)
        ProposalOfferHistoryStore.recordOffers(
            dayKey: "2026-08-21",
            changes: [
                CoachProposedChange(
                    id: "walk-recovery",
                    kind: .createRecoveryWalk,
                    reasonCode: .recoveryWalkSupport,
                    payload: .createRecoveryWalk(
                        CreateRecoveryWalkPayload(
                            proposedDate: yesterday,
                            durationMinutes: 25,
                            title: "Walk",
                            activityType: "recovery"
                        )
                    ),
                    defaultSelected: true,
                    isSelected: true,
                    sortTime: yesterday,
                    evidenceScenarioKey: nil
                )
            ],
            now: yesterday
        )

        let context = makeContext(recoveryBand: .moderate, outdoor: .good)
        let pick = RecoveryMovementProvider.pickOption(
            [.walk],
            dayKey: context.dayKey,
            context: context,
            strategy: .recover
        )
        XCTAssertEqual(pick, .walk, "Sole safe option may repeat despite cooloff")
    }

    // MARK: Hero

    func testRecoverMovementLeadsHeroOverMeal() {
        let now = date(2026, 8, 22, 8, 0)
        let stretch = CoachProposedChange(
            id: "stretch-recovery",
            kind: .createPlannedActivity,
            reasonCode: .recoveryStretchSupport,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: now,
                    durationMinutes: 10,
                    title: "Mobility",
                    activityType: "stretching",
                    icon: "figure.flexibility",
                    imageName: "",
                    colorRed: 0.4,
                    colorGreen: 0.7,
                    colorBlue: 0.6,
                    sourceTemplateDayKey: nil
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: now.addingTimeInterval(3600),
            evidenceScenarioKey: nil,
            scoreTotal: 50
        )
        let meal = CoachProposedChange(
            id: "meal-1",
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "m1",
                    title: "Recovery Bowl",
                    proposedDate: now,
                    durationMinutes: 15,
                    calories: 400,
                    protein: 25,
                    carbs: 40,
                    fats: 12,
                    fiber: 6,
                    imageName: ""
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: now,
            evidenceScenarioKey: nil,
            scoreTotal: 90
        )
        let proposal = MorningPlanProposal(
            id: "p-recover",
            dayKey: "2026-08-22",
            generatedAt: now,
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: "2026-08-22",
                planSignature: "empty",
                tomorrowPlanSignature: "",
                recoveryBand: .moderate,
                sleepPresence: .present,
                scenarioKey: "none",
                yesterdayHeavy: true
            ),
            changes: [meal, stretch],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            strategy: .recover
        )
        let brief = MorningProposalBriefComposer.compose(proposal: proposal)
        XCTAssertFalse(brief.actionLines.isEmpty)
        XCTAssertTrue(
            brief.actionLines[0].localizedCaseInsensitiveContains("mobility")
                || brief.actionLines[0].localizedCaseInsensitiveContains("stretch"),
            "Recover hero must lead with movement, not FUEL. Got: \(brief.actionLines)"
        )
    }

    func testRecoverAdjustmentLeadsHeroOverMeal() {
        let now = date(2026, 8, 22, 8, 0)
        let shorten = CoachProposedChange(
            id: "shorten-1",
            kind: .modifyDuration,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: "run-1",
                    originalDurationMinutes: 60,
                    proposedDurationMinutes: 30,
                    activityTitle: "Tempo Run"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: now.addingTimeInterval(7200),
            evidenceScenarioKey: nil,
            scoreTotal: 40
        )
        let meal = CoachProposedChange(
            id: "meal-2",
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "m2",
                    title: "Recovery Bowl",
                    proposedDate: now,
                    durationMinutes: 15,
                    calories: 400,
                    protein: 25,
                    carbs: 40,
                    fats: 12,
                    fiber: 6,
                    imageName: ""
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: now,
            evidenceScenarioKey: nil,
            scoreTotal: 95
        )
        let proposal = MorningPlanProposal(
            id: "p-adjust",
            dayKey: "2026-08-22",
            generatedAt: now,
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: "2026-08-22",
                planSignature: "hard",
                tomorrowPlanSignature: "",
                recoveryBand: .moderate,
                sleepPresence: .present,
                scenarioKey: "none",
                yesterdayHeavy: true
            ),
            changes: [meal, shorten],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            strategy: .recover
        )
        let brief = MorningProposalBriefComposer.compose(proposal: proposal)
        XCTAssertFalse(brief.actionLines.isEmpty)
        XCTAssertTrue(
            brief.actionLines[0].contains("Tempo Run") || brief.actionLines[0].contains("30"),
            "Plan-adjust recover hero must lead with movement. Got: \(brief.actionLines)"
        )
    }

    // MARK: Scoring floor

    func testRecoveryIndoorCreatesClearInclusionFloor() {
        let context = makeContext(recoveryBand: .moderate, outdoor: .adverse)
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(movement.isEmpty)
        for candidate in movement where isIndoorRecoveryCreate(candidate) {
            XCTAssertNotNil(
                CandidateScorer.score(candidate, context: context, strategy: .recover),
                "\(candidate.id) must survive inclusion floor"
            )
        }
    }

    // MARK: Aug 22 + recover invariant

    func testAug22WindyModerateRecoverIsNotFuelOnly() {
        let weather = makeWeatherSummary(tempC: 19, windKmh: 25.7, precip: 15, condition: .windy)
        let assessment = OutdoorSuitabilityResolver.assess(from: weather)
        XCTAssertEqual(assessment.suitability, .adverse)

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
        XCTAssertTrue(hasMovement, "Aug 22 must include MOVEMENT")
        XCTAssertFalse(
            !mutations.isEmpty && mutations.allSatisfy { $0.kind == .createMealFromLibrary },
            "Aug 22 must not be FUEL-only"
        )
    }

    func testRecoverInvariantNoSuitableLightYieldsMovement() {
        let context = makeContext(recoveryBand: .moderate, outdoor: .acceptable)
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(movement.isEmpty)
        XCTAssertTrue(movement.contains(where: isRecoveryLightCreate))
    }

    // MARK: Helpers

    private func makeContext(
        recoveryBand: ProposalRecoveryBandToken,
        outdoor: OutdoorSuitability,
        weatherRisk: ProposalWeatherRiskToken = .unavailable,
        yesterdayHeavy: Bool = true,
        recoveryPercent: Int? = nil,
        todayOpen: [CoachPlannedActivitySnapshot] = [],
        planSuitability: ExistingPlanMovementSuitability = .none,
        hasExistingMovement: Bool = false,
        templates: [SimilarDayTemplate] = [],
        mealLibrary: [ProposalMealCandidate] = [],
        stronglyRejectsWalk: Bool = false
    ) -> DailyContext {
        let mode = MorningProposalGenerationMode.compose
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-08-22",
            todaySnapshots: todayOpen,
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
            recoveryPercent: recoveryPercent ?? (recoveryBand == .low ? 40 : 69),
            recoveryAvailable: true,
            sleepPresence: .present,
            sleepHours: 7.2,
            yesterdayHeavy: yesterdayHeavy,
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            scenarioKey: nil,
            todayActivities: todayOpen,
            tomorrowActivities: [],
            todayOpen: todayOpen,
            todaySeriousOpen: todayOpen.filter { CoachActivityClassifier.isSeriousTraining($0) },
            hasExistingMovement: hasExistingMovement,
            completedWalkToday: false,
            totalPlannedDurationMinutes: todayOpen.reduce(0) { $0 + $1.durationMinutes },
            recentDayTemplates: templates,
            historicalObservationRevision: "obs",
            behavioralGeneration: 0,
            walkRejectPenalty: 0,
            stronglyRejectsWalk: stronglyRejectsWalk,
            softDismissCount: 0,
            softNegativePenalty: 0,
            preferAvoidHardLoadOnLowRecovery: false,
            mealLibrary: mealLibrary,
            mealLibraryRevision: "1",
            weatherRiskToken: weatherRisk,
            outdoorSuitability: outdoor,
            existingPlanMovementSuitability: planSuitability,
            canMutate: true,
            fingerprint: fingerprint
        )
    }

    private func makeActivity(
        id: String,
        title: String,
        type: String,
        minutes: Int
    ) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: id,
            date: date(2026, 8, 22, 18, 0),
            type: type,
            title: title,
            durationMinutes: minutes,
            icon: "figure.run",
            imageName: "",
            isCompleted: false,
            isSkipped: false,
            source: "planner"
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

    private func isIndoorRecoveryCreate(_ candidate: ProposalCandidate) -> Bool {
        guard candidate.source == .recoveryMovement,
              case .createPlannedActivity(let payload) = candidate.payload else { return false }
        let type = payload.activityType.lowercased()
        return type == "stretching" || type == "yoga" || type == "breathing"
    }

    private func isRecoveryLightCreate(_ candidate: ProposalCandidate) -> Bool {
        candidate.kind == .createRecoveryWalk || isIndoorRecoveryCreate(candidate)
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
