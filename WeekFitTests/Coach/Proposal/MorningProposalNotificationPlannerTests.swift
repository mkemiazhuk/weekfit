import Foundation
import XCTest
@testable import WeekFit

@MainActor
final class MorningProposalNotificationPlannerTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    override func tearDown() {
        MorningProposalNotificationService.shared.resetHandledForTests()
        PendingMorningProposalReview.shared.resetForTests()
        super.tearDown()
    }

    func testFireDateUsesWakePlusTwentyMinutes() {
        let now = date(2026, 8, 6, 5, 0)
        let wake = date(2026, 8, 6, 6, 30)
        let fire = MorningProposalNotificationPlanner.fireDate(
            now: now,
            wakeTime: wake,
            calendar: calendar
        )
        XCTAssertEqual(fire, date(2026, 8, 6, 6, 50))
    }

    func testFireDateFallsBackToSevenAM() {
        let now = date(2026, 8, 6, 5, 0)
        let fire = MorningProposalNotificationPlanner.fireDate(
            now: now,
            wakeTime: nil,
            calendar: calendar
        )
        XCTAssertEqual(fire, date(2026, 8, 6, 7, 20))
    }

    func testFireDateClampsToNowWhenPastPreferred() {
        let now = date(2026, 8, 6, 9, 0)
        let wake = date(2026, 8, 6, 6, 0)
        let fire = MorningProposalNotificationPlanner.fireDate(
            now: now,
            wakeTime: wake,
            calendar: calendar
        )
        XCTAssertEqual(fire, now)
    }

    func testFireDateNilOutsideMorningWindow() {
        let now = date(2026, 8, 6, 13, 0)
        let fire = MorningProposalNotificationPlanner.fireDate(
            now: now,
            wakeTime: date(2026, 8, 6, 7, 0),
            calendar: calendar
        )
        XCTAssertNil(fire)
    }

    func testDecideSchedulesWhenBackgroundAndConfident() {
        let now = date(2026, 8, 6, 8, 0)
        let proposal = confidentProposal(dayKey: "2026-08-06", now: now)
        let action = MorningProposalNotificationPlanner.decide(
            for: MorningProposalNotificationContext(
                now: now,
                proposal: proposal,
                wakeTime: date(2026, 8, 6, 6, 0),
                todaySurfaceVisible: false,
                preferenceEnabled: true,
                handledDayKey: nil
            ),
            calendar: calendar
        )
        guard case .schedule(let fireDate, let dayKey) = action else {
            return XCTFail("Expected schedule, got \(action)")
        }
        XCTAssertEqual(dayKey, "2026-08-06")
        XCTAssertEqual(fireDate, now)
    }

    func testDecideSuppressesWhenTodaySurfaceVisible() {
        let now = date(2026, 8, 6, 8, 0)
        let proposal = confidentProposal(dayKey: "2026-08-06", now: now)
        let action = MorningProposalNotificationPlanner.decide(
            for: MorningProposalNotificationContext(
                now: now,
                proposal: proposal,
                wakeTime: nil,
                todaySurfaceVisible: true,
                preferenceEnabled: true,
                handledDayKey: nil
            ),
            calendar: calendar
        )
        guard case .suppressHandled(let dayKey) = action else {
            return XCTFail("Expected suppressHandled, got \(action)")
        }
        XCTAssertEqual(dayKey, "2026-08-06")
    }

    func testDecideNoneWhenAlreadyHandled() {
        let now = date(2026, 8, 6, 8, 0)
        let proposal = confidentProposal(dayKey: "2026-08-06", now: now)
        let action = MorningProposalNotificationPlanner.decide(
            for: MorningProposalNotificationContext(
                now: now,
                proposal: proposal,
                wakeTime: nil,
                todaySurfaceVisible: false,
                preferenceEnabled: true,
                handledDayKey: "2026-08-06"
            ),
            calendar: calendar
        )
        XCTAssertEqual(action, .none)
    }

    func testDecideCancelsWhenNotConfident() {
        let now = date(2026, 8, 6, 8, 0)
        var proposal = confidentProposal(dayKey: "2026-08-06", now: now)
        proposal.changes = [
            CoachProposedChange(
                id: "soft",
                kind: .guidanceOnly,
                reasonCode: .insufficientConfidence,
                payload: .guidanceOnly(
                    GuidanceOnlyPayload(guidanceCode: .easeIntoFirstEffort, relatedActivityId: nil)
                ),
                defaultSelected: false,
                isSelected: false,
                sortTime: now,
                evidenceScenarioKey: nil
            )
        ]
        let action = MorningProposalNotificationPlanner.decide(
            for: MorningProposalNotificationContext(
                now: now,
                proposal: proposal,
                wakeTime: nil,
                todaySurfaceVisible: false,
                preferenceEnabled: true,
                handledDayKey: nil
            ),
            calendar: calendar
        )
        guard case .cancel(let dayKey) = action else {
            return XCTFail("Expected cancel, got \(action)")
        }
        XCTAssertEqual(dayKey, "2026-08-06")
    }

    func testDecideCancelsWhenPreferenceDisabled() {
        let now = date(2026, 8, 6, 8, 0)
        let proposal = confidentProposal(dayKey: "2026-08-06", now: now)
        let action = MorningProposalNotificationPlanner.decide(
            for: MorningProposalNotificationContext(
                now: now,
                proposal: proposal,
                wakeTime: nil,
                todaySurfaceVisible: false,
                preferenceEnabled: false,
                handledDayKey: nil
            ),
            calendar: calendar
        )
        guard case .cancel = action else {
            return XCTFail("Expected cancel, got \(action)")
        }
    }

    func testDecideCancelsAfterApply() {
        let now = date(2026, 8, 6, 8, 0)
        var proposal = confidentProposal(dayKey: "2026-08-06", now: now)
        proposal.status = .applied
        let action = MorningProposalNotificationPlanner.decide(
            for: MorningProposalNotificationContext(
                now: now,
                proposal: proposal,
                wakeTime: nil,
                todaySurfaceVisible: false,
                preferenceEnabled: true,
                handledDayKey: nil
            ),
            calendar: calendar
        )
        guard case .cancel(let dayKey) = action else {
            return XCTFail("Expected cancel, got \(action)")
        }
        XCTAssertEqual(dayKey, "2026-08-06")
    }

    func testHasRecoverySignalsHelper() {
        XCTAssertTrue(
            MorningProposalEvaluator.hasRecoverySignals(
                sleepMinutes: 420,
                timeInBedMinutes: 0,
                hrvSDNN: 0,
                restingHeartRate: 0
            )
        )
        XCTAssertFalse(
            MorningProposalEvaluator.hasRecoverySignals(
                sleepMinutes: 0,
                timeInBedMinutes: 0,
                hrvSDNN: 0,
                restingHeartRate: 0
            )
        )
    }

    func testReadinessFallbackBands() {
        let good = MorningProposalEvaluator.readinessFallback(readyScore: 80, sleepHours: 7.5)
        XCTAssertEqual(good.recoveryBand, .good)
        let moderate = MorningProposalEvaluator.readinessFallback(readyScore: 60, sleepHours: 7)
        XCTAssertEqual(moderate.recoveryBand, .moderate)
        let low = MorningProposalEvaluator.readinessFallback(readyScore: 40, sleepHours: 5)
        XCTAssertEqual(low.recoveryBand, .low)
        XCTAssertTrue(low.sleepIsLow)
    }

    // MARK: - Helpers

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        components.minute = min
        return calendar.date(from: components)!
    }

    private func confidentProposal(dayKey: String, now: Date) -> MorningPlanProposal {
        let change = CoachProposedChange(
            id: "shorten-1",
            kind: .modifyDuration,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: "run-1",
                    originalDurationMinutes: 60,
                    proposedDurationMinutes: 40,
                    activityTitle: "Run"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: now,
            evidenceScenarioKey: "lowRecoveryPrep"
        )
        return MorningPlanProposal(
            id: "p-1",
            dayKey: dayKey,
            generatedAt: now,
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: dayKey,
                planSignature: "sig",
                tomorrowPlanSignature: "",
                recoveryBand: .low,
                sleepPresence: .present,
                scenarioKey: "lowRecoveryPrep",
                yesterdayHeavy: true,
                schemaVersion: ProposalInputFingerprint.currentSchemaVersion
            ),
            changes: [change],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: MorningPlanProposal.currentSchemaVersion,
            strategy: .recover,
            contextConfidence: .high
        )
    }
}
