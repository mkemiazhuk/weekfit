import XCTest
@testable import WeekFit

final class ReviewEligibilityEvaluatorTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    func testMissingFirstUseIsIneligible() {
        let decision = ReviewEligibilityEvaluator.evaluate(
            state: .empty,
            now: Date(),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.missingFirstUse))
    }

    func testRecentActionWindowBoundary() {
        let firstUse = date(2026, 7, 1)
        var state = ReviewEligibilityState.empty
        state.firstAppUseDate = firstUse
        state.activeDayTimestamps = (0..<5).map { Double(date(2026, 7, 1 + $0).timeIntervalSince1970) }
        state.meaningfulActionCount = 5
        state.lastMeaningfulActionDate = date(2026, 7, 8) // 8 days before July 16

        let tooOld = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 16),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(tooOld.failureReasons.contains(.noRecentMeaningfulAction))

        state.lastMeaningfulActionDate = date(2026, 7, 9) // 7 days before July 16
        let recentEnough = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 16),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertFalse(recentEnough.failureReasons.contains(.noRecentMeaningfulAction))
    }

    func testCooldownExactlyOneHundredTwentyDaysAllowsPrompt() {
        let attempt = date(2026, 1, 1)
        let day119 = calendar.date(byAdding: .day, value: 119, to: attempt)!
        let day120 = calendar.date(byAdding: .day, value: 120, to: attempt)!

        var state = engagedState(on: day119)
        state.nativeReviewRequestAttemptDate = attempt
        state.systemReviewRequestVersion = "1.1.0"
        state.lastFeedbackPromptDate = attempt
        state.lastPromptedAppVersion = "1.0.0"

        let blocked = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: day119,
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(blocked.failureReasons.contains(.cooldownActive))
        XCTAssertFalse(blocked.failureReasons.contains(.alreadyPromptedThisVersion))

        state = engagedState(on: day120)
        state.nativeReviewRequestAttemptDate = attempt
        state.systemReviewRequestVersion = "1.1.0"
        state.lastFeedbackPromptDate = attempt
        state.lastPromptedAppVersion = "1.0.0"
        let allowed = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: day120,
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(allowed.isEligible, "reasons: \(allowed.failureReasons)")
    }

    func testEngagementThresholdBoundaries() {
        var state = eligibleBaseState()
        state.firstAppUseDate = date(2026, 7, 1)
        state.activeDayTimestamps = (0..<5).map { Double(date(2026, 7, 1 + $0).timeIntervalSince1970) }
        state.meaningfulActionCount = 5
        state.lastMeaningfulActionDate = date(2026, 7, 6)

        let dayFour = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 5),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(dayFour.failureReasons.contains(.insufficientCalendarDays))

        let dayFive = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 6),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertFalse(dayFive.failureReasons.contains(.insufficientCalendarDays))
        XCTAssertTrue(dayFive.isEligible, "reasons: \(dayFive.failureReasons)")

        state.activeDayTimestamps = (0..<4).map { Double(date(2026, 7, 1 + $0).timeIntervalSince1970) }
        let fourDays = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 6),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(fourDays.failureReasons.contains(.insufficientActiveDays))

        state.activeDayTimestamps = (0..<5).map { Double(date(2026, 7, 1 + $0).timeIntervalSince1970) }
        state.meaningfulActionCount = 4
        let fourActions = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 6),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(fourActions.failureReasons.contains(.insufficientMeaningfulActions))
    }

    func testLegacyCustomCardDoesNotCountAsSystemRequest() {
        var state = eligibleBaseState()
        state.lastPromptedAppVersion = "1.2.0"
        state.lastFeedbackPromptDate = date(2026, 7, 22)

        let decision = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 22),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(decision.isEligible, "reasons: \(decision.failureReasons)")
    }

    func testSameSystemRequestVersionStaysBlockedAfterCooldown() {
        let attempt = date(2026, 1, 1)
        let day120 = calendar.date(byAdding: .day, value: 120, to: attempt)!
        var state = engagedState(on: day120)
        state.nativeReviewRequestAttemptDate = attempt
        state.systemReviewRequestVersion = "1.2.0"

        let decision = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: day120,
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(decision.failureReasons.contains(.alreadyPromptedThisVersion))
        XCTAssertFalse(decision.failureReasons.contains(.cooldownActive))
    }

    func testDebugBypassSkipsEngagementThresholdsOnly() {
        let bypassed = ReviewEligibilityEvaluator.evaluate(
            state: .empty,
            now: date(2026, 7, 22),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false,
            bypassEngagementThresholds: true
        )
        XCTAssertTrue(bypassed.isEligible, "reasons: \(bypassed.failureReasons)")

        var requested = ReviewEligibilityState.empty
        requested.systemReviewRequestVersion = "1.2.0"
        requested.nativeReviewRequestAttemptDate = date(2026, 7, 22)
        let stillBlocked = ReviewEligibilityEvaluator.evaluate(
            state: requested,
            now: date(2026, 7, 22),
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false,
            bypassEngagementThresholds: true
        )
        XCTAssertTrue(stillBlocked.failureReasons.contains(.alreadyPromptedThisVersion))
        XCTAssertTrue(stillBlocked.failureReasons.contains(.cooldownActive))
    }

    private func eligibleBaseState() -> ReviewEligibilityState {
        engagedState(on: date(2026, 7, 22))
    }

    private func engagedState(on day: Date) -> ReviewEligibilityState {
        var state = ReviewEligibilityState.empty
        let first = calendar.date(byAdding: .day, value: -10, to: day)!
        state.firstAppUseDate = first
        state.activeDayTimestamps = (0..<5).map {
            Double(calendar.date(byAdding: .day, value: $0, to: first)!.timeIntervalSince1970)
        }
        state.meaningfulActionCount = 5
        state.lastMeaningfulActionDate = day
        return state
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }
}
