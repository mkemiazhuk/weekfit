import XCTest
@testable import WeekFit

final class MorningProposalBriefComposerTests: XCTestCase {

    func testCompose_prefersSelectedMutationsAsActionLines() {
        let dayKey = "2026-07-31"
        let shorten = CoachProposedChange(
            id: "c1",
            kind: .modifyDuration,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: "a1",
                    originalDurationMinutes: 60,
                    proposedDurationMinutes: 40,
                    activityTitle: "Tempo Run"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            scoreTotal: 90
        )
        let meal = CoachProposedChange(
            id: "c2",
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "m1",
                    title: "Eggs Oatmeal",
                    proposedDate: Date(),
                    durationMinutes: 15,
                    calories: 400,
                    protein: 20,
                    carbs: 40,
                    fats: 10,
                    fiber: 5,
                    imageName: "plate-dark"
                )
            ),
            defaultSelected: false,
            isSelected: false,
            sortTime: Date().addingTimeInterval(3600),
            evidenceScenarioKey: nil,
            scoreTotal: 40
        )
        let tip = CoachProposedChange(
            id: "c3",
            kind: .guidanceOnly,
            reasonCode: .planAlreadyAppropriate,
            payload: .guidanceOnly(
                GuidanceOnlyPayload(guidanceCode: .morningFuelWithoutLibrary, relatedActivityId: nil)
            ),
            defaultSelected: false,
            isSelected: false,
            sortTime: Date(),
            evidenceScenarioKey: nil
        )

        let proposal = MorningPlanProposal(
            id: "p1",
            dayKey: dayKey,
            generatedAt: Date(),
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: dayKey,
                planSignature: "plan",
                tomorrowPlanSignature: "",
                recoveryBand: .low,
                sleepPresence: .present,
                scenarioKey: "lowRecovery",
                yesterdayHeavy: true
            ),
            changes: [shorten, meal, tip],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            strategy: .recover
        )

        let brief = MorningProposalBriefComposer.compose(
            proposal: proposal,
            givenName: "Max",
            weatherLine: "Rain risk — prefer indoor or earlier"
        )

        XCTAssertEqual(brief.addressName, "Max")
        XCTAssertFalse(brief.headline.contains("Max"))
        XCTAssertFalse(brief.headline.hasPrefix("Max"))
        XCTAssertEqual(brief.actionLines.count, 1)
        XCTAssertTrue(brief.actionLines[0].contains("Tempo Run"))
        XCTAssertTrue(brief.actionLines[0].contains("40"))
        XCTAssertEqual(brief.recommendedCount, 2)
        XCTAssertEqual(brief.tipCount, 1)
        // Meta stays human (weather), not tip-count inventory.
        XCTAssertEqual(brief.metaLine, "Rain risk — prefer indoor or earlier")
        XCTAssertFalse(brief.dayMoments.isEmpty)
        XCTAssertEqual(brief.dayMoments.first?.title.contains("Tempo") ?? false, true)
        // Strategy headline should stay short and editorial.
        XCTAssertLessThan(brief.headline.count, 72)
    }

    func testDayMoments_areChronologicAndPreferSelected() {
        let earlier = Date()
        let later = earlier.addingTimeInterval(3 * 3600)
        let walk = CoachProposedChange(
            id: "walk",
            kind: .createRecoveryWalk,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .createRecoveryWalk(
                CreateRecoveryWalkPayload(
                    proposedDate: later,
                    durationMinutes: 25,
                    title: "Walk",
                    activityType: "recovery"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: later,
            evidenceScenarioKey: nil,
            scoreTotal: 80
        )
        let meal = CoachProposedChange(
            id: "meal",
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "m1",
                    title: "Dinner Bowl",
                    proposedDate: earlier,
                    durationMinutes: 15,
                    calories: 500,
                    protein: 30,
                    carbs: 45,
                    fats: 15,
                    fiber: 8,
                    imageName: "plate-dark"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: earlier,
            evidenceScenarioKey: nil,
            scoreTotal: 70
        )
        let proposal = MorningPlanProposal(
            id: "p-day",
            dayKey: "2026-08-02",
            generatedAt: Date(),
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: "2026-08-02",
                planSignature: "plan",
                tomorrowPlanSignature: "",
                recoveryBand: .moderate,
                sleepPresence: .present,
                scenarioKey: "maintain",
                yesterdayHeavy: false
            ),
            changes: [walk, meal],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            strategy: .maintain
        )

        let moments = MorningProposalBriefComposer.dayMoments(for: proposal)
        XCTAssertEqual(moments.count, 2)
        XCTAssertEqual(moments[0].id, "meal")
        XCTAssertEqual(moments[1].id, "walk")
        XCTAssertEqual(moments[0].title, "Dinner Bowl")
    }

    func testActionLine_shortenIncludesActivityTitle() {
        let change = CoachProposedChange(
            id: "c1",
            kind: .modifyDuration,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: "a1",
                    originalDurationMinutes: 75,
                    proposedDurationMinutes: 55,
                    activityTitle: "Evening Ride"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: Date(),
            evidenceScenarioKey: nil,
            scoreTotal: 90
        )
        let line = MorningProposalBriefComposer.actionLine(for: change)
        XCTAssertTrue(line.contains("Evening Ride"))
        XCTAssertTrue(line.contains("75"))
        XCTAssertTrue(line.contains("55"))
    }

    func testActionLine_moveIncludesActivityTitle() {
        let calendar = Calendar.current
        let from = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 18))!
        let to = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
        let change = CoachProposedChange(
            id: "c1",
            kind: .moveActivity,
            reasonCode: .tomorrowDemandProtection,
            payload: .moveActivity(
                MoveActivityPayload(
                    activityId: "a1",
                    originalDate: from,
                    proposedDate: to,
                    activityTitle: "Intervals"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: from,
            evidenceScenarioKey: nil,
            scoreTotal: 80
        )
        let line = MorningProposalBriefComposer.actionLine(for: change)
        XCTAssertTrue(line.contains("Intervals"))
    }

    func testActionLine_habitActivityUsesUsualWeekdayNarrative() {
        let calendar = Calendar.current
        // Friday
        let when = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 10))!
        let change = CoachProposedChange(
            id: "hist-yoga",
            kind: .createPlannedActivity,
            reasonCode: .similarDaySupport,
            payload: .createPlannedActivity(
                CreatePlannedActivityPayload(
                    proposedDate: when,
                    durationMinutes: 40,
                    title: "Yoga",
                    activityType: "recovery",
                    icon: "figure.yoga",
                    imageName: "",
                    colorRed: 0, colorGreen: 0, colorBlue: 0,
                    sourceTemplateDayKey: "2026-07-24"
                )
            ),
            defaultSelected: false,
            isSelected: true,
            sortTime: when,
            evidenceScenarioKey: nil,
            candidateSource: .historicalActivity,
            scoreTotal: 70
        )
        let line = MorningProposalBriefComposer.actionLine(for: change)
        XCTAssertTrue(line.contains("Yoga"))
        XCTAssertTrue(
            line.lowercased().contains("usual") || line.lowercased().contains("обычно"),
            "Habit line should narrate usual weekday pattern: \(line)"
        )
    }

    func testWeatherMetaLine_nilWhenCalm() {
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 22, unit: .celsius),
            feelsLike: Measurement(value: 22, unit: .celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "cloud",
            condition: .cloudy,
            humidityPercent: 50,
            windSpeed: Measurement(value: 10, unit: .kilometersPerHour),
            uvIndex: 3,
            precipitationChance: 10
        )
        XCTAssertNil(MorningProposalBriefComposer.weatherMetaLine(from: summary))
    }

    func testWeatherMetaLine_precip() {
        let summary = WeekFitWeatherSummary(
            temperature: Measurement(value: 18, unit: .celsius),
            feelsLike: Measurement(value: 18, unit: .celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "cloud.rain",
            condition: .rain,
            humidityPercent: 80,
            windSpeed: Measurement(value: 12, unit: .kilometersPerHour),
            uvIndex: 2,
            precipitationChance: 70
        )
        XCTAssertNotNil(MorningProposalBriefComposer.weatherMetaLine(from: summary))
    }

    func testColdStartBrief_usesDedicatedHeadlineAndSurfacesTipsAsActions() {
        let tip = CoachProposedChange(
            id: "c1",
            kind: .guidanceOnly,
            reasonCode: .openDayMovementSupport,
            payload: .guidanceOnly(
                GuidanceOnlyPayload(guidanceCode: .hydrateThroughMorning, relatedActivityId: nil)
            ),
            defaultSelected: false,
            isSelected: false,
            sortTime: Date(),
            evidenceScenarioKey: nil
        )
        let proposal = MorningPlanProposal(
            id: "p1",
            dayKey: "2026-07-31",
            generatedAt: Date(),
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: "2026-07-31",
                planSignature: "plan",
                tomorrowPlanSignature: "",
                recoveryBand: .moderate,
                sleepPresence: .present,
                scenarioKey: "none",
                yesterdayHeavy: false,
                observationContextRevision: "none"
            ),
            changes: [tip],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            strategy: .maintain
        )

        let brief = MorningProposalBriefComposer.compose(proposal: proposal, givenName: nil)
        XCTAssertTrue(MorningProposalBriefComposer.isColdStart(proposal))
        XCTAssertTrue(
            brief.headline.contains("simple") || brief.headline.contains("просто")
            || brief.headline.lowercased().contains("weekfit")
        )
        XCTAssertEqual(brief.actionLines.count, 1)
        XCTAssertNil(brief.metaLine)
    }
}
