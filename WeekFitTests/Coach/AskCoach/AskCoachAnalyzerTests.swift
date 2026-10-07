import XCTest
@testable import WeekFit

final class AskCoachAnalyzerTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testMissingSleepIsNotTreatedAsZeroAverage() {
        let current = makeDays(count: 7) { index, dayStart in
            AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: index < 2 ? 420 : nil,
                recoveryPercent: nil,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: [],
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: false
            )
        }

        let answer = analyze(question: .recovery, current: current, previous: makeDays(count: 7))
        let sleepCoverage = answer.coverage.first { $0.metricKey == "sleep" }
        XCTAssertEqual(sleepCoverage?.observedDays, 2)
        XCTAssertEqual(sleepCoverage?.totalDays, 7)
        // Below minimum average requirement — should not invent a full-period average claim.
        XCTAssertFalse(AskCoachCopy.resolve(answer.headline).contains("7.0"))
        XCTAssertEqual(answer.loadState, .partialData)
    }

    func testZeroHRVIsIgnoredAsMissing() {
        let current = makeDays(count: 7) { _, dayStart in
            AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: 420,
                recoveryPercent: 70,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: [],
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: false
            )
        }
        // Builder path: 0 must become nil before analyze.
        let vitals = current.map {
            AskCoachMetricsBuilder.VitalInput(dayKey: $0.dayKey, hrvSDNN: 0, restingHeartRate: 0)
        }
        let range = AskCoachPeriodCalculator.range(
            length: .last7Days,
            endingOn: current.last!.dayStart,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let built = AskCoachMetricsBuilder.buildDays(
            range: range,
            observations: current.map {
                .init(
                    dayKey: $0.dayKey,
                    sleepMinutes: $0.sleepMinutes,
                    recoveryPercent: $0.recoveryPercent,
                    hasTrainingFields: false,
                    observationWorkoutCount: 0
                )
            },
            vitals: vitals,
            completedSessions: [],
            localCandidates: [],
            calendar: calendar
        )
        XCTAssertTrue(built.allSatisfy { $0.hrvSDNN == nil })
        XCTAssertTrue(built.allSatisfy { $0.restingHeartRate == nil })
    }

    func testWeeklyOverviewComparesEqualLengthPreviousPeriod() {
        let current = makeSessionDays(count: 7, sessionsPerActiveDay: 1, activeEvery: 2)
        let previous = makeSessionDays(count: 7, sessionsPerActiveDay: 1, activeEvery: 2)

        let answer = analyze(question: .weeklyOverview, current: current, previous: previous)
        let english = answer.headline.english.lowercased()
        XCTAssertFalse(english.isEmpty)
        XCTAssertTrue(answer.followUps.contains(.myRecovery))
        XCTAssertTrue(answer.followUps.contains(.nextWeekFocus))
        XCTAssertLessThanOrEqual(answer.followUps.count, 2)
        XCTAssertLessThanOrEqual(answer.supportingFacts.count, 2)
    }

    func testInsufficientPreviousDataOmitsComparisonClaim() {
        let current = makeSessionDays(count: 7, sessionsPerActiveDay: 1, activeEvery: 1)
        let previous = makeDays(count: 7) // no sessions, no training signal

        let answer = analyze(question: .weeklyOverview, current: current, previous: previous)
        XCTAssertTrue(answer.inlineLimitation?.english.contains("Not enough data") == true)
        XCTAssertFalse(answer.headline.english.lowercased().contains("last week"))
    }

    func testConsistencyDoesNotLabelEmptyDaysAsInactivity() {
        let current = makeSessionDays(count: 7, sessionsPerActiveDay: 1, activeEvery: 3)
        let answer = analyze(question: .consistency, current: current, previous: makeDays(count: 7))
        let explanation = answer.explanation.english.lowercased()
        XCTAssertTrue(explanation.contains("inactivity"))
        XCTAssertTrue(explanation.contains("only completed"))
    }

    func testMixedRecoverySessionsUseActivitiesWording() {
        let current = makeDays(count: 7) { index, dayStart in
            let sessions: [AskCoachCompletedSession] = index < 3 ? [
                AskCoachCompletedSession(
                    id: "w-\(index)",
                    startDate: dayStart.addingTimeInterval(3600),
                    durationMinutes: 40,
                    healthKitWorkoutUUID: UUID(),
                    source: .healthKit,
                    isPlannerSourced: false,
                    isRecoveryActivity: index == 0
                ),
                AskCoachCompletedSession(
                    id: "r-\(index)",
                    startDate: dayStart.addingTimeInterval(7200),
                    durationMinutes: 20,
                    healthKitWorkoutUUID: UUID(),
                    source: .healthKit,
                    isPlannerSourced: false,
                    isRecoveryActivity: true
                )
            ] : []
            return AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: 420,
                recoveryPercent: 70,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: sessions,
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: !sessions.isEmpty
            )
        }
        let answer = analyze(question: .weeklyOverview, current: current, previous: makeDays(count: 7))
        let factBlob = answer.supportingFacts.map(\.english).joined(separator: " ").lowercased()
        XCTAssertTrue(factBlob.contains("activit"))
        XCTAssertFalse(answer.headline.english.lowercased().contains("22"))
        XCTAssertFalse(answer.headline.english.lowercased().contains("workout"))
    }

    func testNoDataStateWhenEmpty() {
        let answer = analyze(
            question: .weeklyOverview,
            current: makeDays(count: 7),
            previous: makeDays(count: 7)
        )
        XCTAssertEqual(answer.loadState, .noData)
    }

    func testPermissionUnavailableState() {
        let range = AskCoachPeriodCalculator.range(
            length: .last7Days,
            endingOn: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let answer = AskCoachAnalyzer.analyze(
            .init(
                question: .weeklyOverview,
                period: .last7Days,
                currentDays: makeDays(count: 7),
                previousDays: makeDays(count: 7),
                range: range,
                previousRange: AskCoachPeriodCalculator.previousRange(for: range, calendar: calendar, timeZone: calendar.timeZone),
                healthAccessGranted: false,
                followUp: nil
            )
        )
        XCTAssertEqual(answer.loadState, .permissionUnavailable)
    }

    func testFocusSuggestionRequiresEvidence() {
        let weak = makeDays(count: 7)
        XCTAssertNil(AskCoachAnalyzer.suggestFocus(current: weak, previous: weak))

        let currentSleep = makeDays(count: 7) { _, dayStart in
            AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: 360,
                recoveryPercent: 55,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: [],
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: false
            )
        }
        let previousSleep = makeDays(count: 7) { _, dayStart in
            AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: 450,
                recoveryPercent: 70,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: [],
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: false
            )
        }
        let suggestion = AskCoachAnalyzer.suggestFocus(current: currentSleep, previous: previousSleep)
        XCTAssertEqual(suggestion?.kind, .steadySleepDuration)
    }

    // MARK: - Helpers

    private func analyze(
        question: AskCoachQuestion,
        current: [AskCoachDayMetrics],
        previous: [AskCoachDayMetrics]
    ) -> AskCoachAnswer {
        let end = current.last?.dayStart ?? Date(timeIntervalSince1970: 1_700_000_000)
        let range = AskCoachPeriodCalculator.range(
            length: current.count <= 7 ? .last7Days : .last28Days,
            endingOn: end,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        return AskCoachAnalyzer.analyze(
            .init(
                question: question,
                period: current.count <= 7 ? .last7Days : .last28Days,
                currentDays: current,
                previousDays: previous,
                range: range,
                previousRange: AskCoachPeriodCalculator.previousRange(
                    for: range,
                    calendar: calendar,
                    timeZone: calendar.timeZone
                ),
                healthAccessGranted: true,
                followUp: nil
            )
        )
    }

    private func makeDays(
        count: Int,
        configure: ((Int, Date) -> AskCoachDayMetrics)? = nil
    ) -> [AskCoachDayMetrics] {
        let end = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        return (0..<count).map { offset in
            let dayStart = calendar.date(byAdding: .day, value: -(count - 1 - offset), to: end)!
            if let configure {
                return configure(offset, dayStart)
            }
            return AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: nil,
                recoveryPercent: nil,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: [],
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: false
            )
        }
    }

    private func makeSessionDays(
        count: Int,
        sessionsPerActiveDay: Int,
        activeEvery: Int
    ) -> [AskCoachDayMetrics] {
        makeDays(count: count) { index, dayStart in
            let active = index % activeEvery == 0
            let sessions: [AskCoachCompletedSession] = active
                ? (0..<sessionsPerActiveDay).map { sessionIndex in
                    AskCoachCompletedSession(
                        id: "\(CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar))-\(sessionIndex)",
                        startDate: dayStart.addingTimeInterval(Double(sessionIndex + 1) * 3600),
                        durationMinutes: 40,
                        healthKitWorkoutUUID: UUID(),
                        source: .healthKit,
                        isPlannerSourced: false,
                        isRecoveryActivity: false
                    )
                }
                : []
            return AskCoachDayMetrics(
                dayStart: dayStart,
                dayKey: CoachDailyObservation.dayKey(for: dayStart, calendar: self.calendar),
                sleepMinutes: 420,
                recoveryPercent: 70,
                hrvSDNN: nil,
                restingHeartRate: nil,
                completedSessions: sessions,
                plannedPlannerSessionCount: 0,
                completedPlannerSessionCount: 0,
                hasTrainingSignal: active
            )
        }
    }
}
