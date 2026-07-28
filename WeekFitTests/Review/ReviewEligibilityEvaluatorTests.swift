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
        var state = eligibleBaseState()
        state.lastFeedbackPromptDate = date(2026, 3, 24)
        state.lastPromptedAppVersion = "1.1.0"

        let decision = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: date(2026, 7, 22), // 120 days later
            calendar: calendar,
            currentAppVersion: "1.2.0",
            isUIBlocked: false,
            isReviewDemoMode: false
        )
        XCTAssertTrue(decision.isEligible, "reasons: \(decision.failureReasons)")
    }

    private func eligibleBaseState() -> ReviewEligibilityState {
        var state = ReviewEligibilityState.empty
        state.firstAppUseDate = date(2026, 7, 10)
        state.activeDayTimestamps = (0..<5).map { Double(date(2026, 7, 10 + $0).timeIntervalSince1970) }
        state.meaningfulActionCount = 5
        state.lastMeaningfulActionDate = date(2026, 7, 22)
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
