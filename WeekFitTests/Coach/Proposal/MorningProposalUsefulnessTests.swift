import Foundation
import XCTest
@testable import WeekFit

final class MorningProposalUsefulnessTests: XCTestCase {

    func testInventedSessionNeverExceedsOneHour() {
        XCTAssertEqual(
            ProposalInventedSessionPolicy.durationMinutes(
                raw: 83,
                recoveryBand: .good,
                strategy: .train
            ),
            60
        )
        XCTAssertEqual(
            ProposalInventedSessionPolicy.durationMinutes(
                raw: 83,
                recoveryBand: .moderate,
                strategy: .maintain
            ),
            45
        )
        XCTAssertEqual(
            ProposalInventedSessionPolicy.roundedHalfHour(hour: 15, minute: 3).minute,
            0
        )
        XCTAssertEqual(
            ProposalInventedSessionPolicy.roundedHalfHour(hour: 15, minute: 3).hour,
            15
        )
    }

    func testHistoricalSwimIsCappedAndClockRounded() {
        let templates = [
            swimTemplate(dayKey: "2026-07-01", day: 1, minute: 3),
            swimTemplate(dayKey: "2026-07-08", day: 8, minute: 3)
        ]
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: false,
            templates: templates
        )
        let strategy = DailyStrategyResolver.resolve(context: context)
        let historical = HistoricalActivityProvider.generate(context: context, strategy: strategy)
        guard let swim = historical.compactMap({ candidate -> CreatePlannedActivityPayload? in
            guard case .createPlannedActivity(let payload) = candidate.payload,
                  payload.title == "Swimming" else { return nil }
            return payload
        }).first else {
            return XCTFail("Expected a swimming candidate on a fresh train day")
        }
        XCTAssertLessThanOrEqual(swim.durationMinutes, 60)
        XCTAssertEqual(Calendar.current.component(.minute, from: swim.proposedDate) % 30, 0)
    }

    func testHistoricalProviderSkipsYesterdaysExactSession() {
        let templates = [
            swimTemplate(dayKey: "2026-07-01", day: 1, minute: 0),
            swimTemplate(dayKey: "2026-07-08", day: 8, minute: 0),
            swimTemplate(dayKey: "2026-07-28", day: 28, minute: 0)
        ]
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: false,
            templates: templates
        )
        let historical = HistoricalActivityProvider.generate(context: context, strategy: .train)
        XCTAssertFalse(
            historical.contains { candidate in
                if case .createPlannedActivity(let payload) = candidate.payload {
                    return payload.title == "Swimming"
                }
                return false
            }
        )
    }

    func testRecoverDayDoesNotInventElevatedSwim() {
        let templates = [
            swimTemplate(dayKey: "2026-07-01", day: 1, minute: 0),
            swimTemplate(dayKey: "2026-07-08", day: 8, minute: 0)
        ]
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: true,
            templates: templates
        )
        XCTAssertEqual(DailyStrategyResolver.resolve(context: context), .recover)
        let historical = HistoricalActivityProvider.generate(context: context, strategy: .recover)
        XCTAssertFalse(
            historical.contains { candidate in
                if case .createPlannedActivity(let payload) = candidate.payload {
                    return payload.title == "Swimming"
                }
                return false
            }
        )
    }

    func testMealSlotsStayDistinctAndSkipYesterdayClone() {
        let library = [
            meal("pork", "Pork Tortilla", time: "13:00", type: "recovery"),
            meal("toast", "Cottage Cheese Toast", time: "16:00", type: "balanced"),
            meal("yogurt", "Strawberries Greek Yogurt", time: "19:00", type: "highprotein"),
            meal("bowl", "Recovery Bowl", time: "13:00", type: "recovery")
        ]
        let yesterdayMeal = CoachPlannedActivitySnapshot(
            id: "y-meal",
            date: date(2026, 7, 28, 13, 0),
            type: "meal",
            title: "Pork Tortilla",
            durationMinutes: 20,
            isCompleted: true
        )
        let yesterday = SimilarDayTemplate(
            dayKey: "2026-07-28",
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [yesterdayMeal]
        )
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: true,
            templates: [yesterday],
            mealLibrary: library
        )
        let meals = MealLibraryProvider.generate(context: context, strategy: .recover)
        XCTAssertLessThanOrEqual(meals.count, 2)
        let titles = meals.compactMap { candidate -> String? in
            guard case .createMealFromLibrary(let payload) = candidate.payload else { return nil }
            return payload.title
        }
        XCTAssertFalse(titles.contains("Pork Tortilla"))
        XCTAssertFalse(titles.contains("Cottage Cheese Toast"), "Snack should not fill a recover morning")
        let slots = Set(meals.map { ProposalMealSlot.from(date: $0.sortTime) })
        XCTAssertEqual(slots.count, meals.count, "One meal per slot")
        XCTAssertTrue(slots.contains(.lunch) || slots.contains(.dinner))
    }

    func testRemainingSlotsPreferLunchAndDinnerOverSnack() {
        let library = [
            meal("l", "Lunch", time: "13:00", type: "balanced"),
            meal("s", "Snack", time: "16:00", type: "balanced"),
            meal("d", "Dinner", time: "19:00", type: "balanced")
        ]
        let slots = MealLibraryProvider.remainingSlots(
            now: date(2026, 7, 29, 8, 19),
            strategy: .recover,
            includeSnack: false,
            library: library
        )
        XCTAssertEqual(slots, [.lunch, .dinner])
    }

    func testMealWhyDiffersBySlotAfterHardDay() {
        XCTAssertEqual(
            MealLibraryProvider.mealReason(slot: .lunch, strategy: .recover, yesterdayHeavy: true),
            .libraryMealRecoveryLunch
        )
        XCTAssertEqual(
            MealLibraryProvider.mealReason(slot: .dinner, strategy: .recover, yesterdayHeavy: true),
            .libraryMealRecoveryDinner
        )
        XCTAssertNotEqual(
            CoachProposalReasonCopy.localizedReason(.libraryMealRecoveryLunch),
            CoachProposalReasonCopy.localizedReason(.libraryMealRecoveryDinner)
        )
    }

    func testPostHardDayOffersStretchWhenWalksRejected() {
        let context = makeContext(
            recoveryBand: .good,
            yesterdayHeavy: true,
            templates: [
                SimilarDayTemplate(
                    dayKey: "2026-07-24",
                    recoveryBand: .good,
                    observationAvailable: true,
                    sleepPresence: .present,
                    activities: [
                        CoachPlannedActivitySnapshot(
                            id: "meal",
                            date: date(2026, 7, 24, 12, 0),
                            type: "meal",
                            title: "Lunch",
                            durationMinutes: 20,
                            isCompleted: true
                        )
                    ]
                )
            ],
            stronglyRejectsWalk: true
        )
        let movement = RecoveryMovementProvider.generate(context: context, strategy: .recover)
        XCTAssertTrue(
            movement.contains { candidate in
                if case .createPlannedActivity(let payload) = candidate.payload {
                    return payload.activityType == "stretching"
                }
                return false
            }
        )
        XCTAssertEqual(
            CoachProposalReasonCopy.localizedReason(.recoveryStretchSupport).contains("stretch"),
            true
        )
    }

    // MARK: - Helpers

    private func swimTemplate(dayKey: String, day: Int, minute: Int) -> SimilarDayTemplate {
        SimilarDayTemplate(
            dayKey: dayKey,
            recoveryBand: .good,
            observationAvailable: true,
            sleepPresence: .present,
            activities: [
                CoachPlannedActivitySnapshot(
                    id: "swim-\(day)",
                    date: date(2026, 7, day, 15, minute),
                    type: "workout",
                    title: "Swimming",
                    durationMinutes: 83,
                    icon: "figure.pool.swim",
                    isCompleted: true
                )
            ]
        )
    }

    private func meal(_ id: String, _ title: String, time: String, type: String) -> ProposalMealCandidate {
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

    private func makeContext(
        recoveryBand: ProposalRecoveryBandToken,
        yesterdayHeavy: Bool,
        templates: [SimilarDayTemplate],
        mealLibrary: [ProposalMealCandidate] = [],
        stronglyRejectsWalk: Bool = false
    ) -> DailyContext {
        let mode = MorningProposalGenerationMode.compose
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: "2026-07-29",
            todaySnapshots: [],
            tomorrowSnapshots: [],
            recoveryBand: recoveryBand,
            sleepPresence: .present,
            scenarioKey: "none",
            yesterdayHeavy: yesterdayHeavy,
            generationMode: mode
        )
        return DailyContext(
            now: date(2026, 7, 29, 8, 19),
            dayKey: "2026-07-29",
            isMorningEligible: true,
            hasCompletedOrPartialToday: false,
            generationMode: mode,
            contextFreshness: .high,
            recoveryBand: recoveryBand,
            recoveryPercent: recoveryBand == .good ? 85 : 50,
            recoveryAvailable: true,
            sleepPresence: .present,
            sleepHours: 7.5,
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
            weatherRiskToken: .unavailable,
            canMutate: true,
            fingerprint: fingerprint
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
