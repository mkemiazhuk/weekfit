import XCTest
@testable import WeekFit

final class ReviewAnalyticsBridgeTests: XCTestCase {

    private var recording: RecordingAnalyticsService!
    private var reviewAnalytics: ReviewAnalytics!

    override func setUp() {
        super.setUp()
        recording = RecordingAnalyticsService()
        AppAnalytics.setSharedForTests(recording)
        reviewAnalytics = ReviewAnalytics(analytics: { AppAnalytics.shared })
        reviewAnalytics.resetForTests()
    }

    override func tearDown() {
        reviewAnalytics.resetForTests()
        AppAnalytics.resetSharedForTests()
        reviewAnalytics = nil
        recording = nil
        super.tearDown()
    }

    func testReviewEventsForwardToAppAnalyticsWithSameNames() throws {
        let events: [ReviewAnalyticsEvent] = [
            .reviewEligibilityReached,
            .reviewFeedbackSheetShown,
            .reviewFeedbackSelected,
            .nativeReviewRequestAttempted,
            .feedbackFormOpened,
            .feedbackSubmitted,
            .feedbackDismissed,
            .rateWeekFitSelectedFromSettings
        ]

        for event in events {
            reviewAnalytics.track(
                event,
                properties: ReviewAnalyticsProperties.base(
                    appVersion: "1.2.0",
                    triggerSource: ReviewPromptTriggerSource.meaningfulAction.rawValue
                )
            )
        }

        for event in events {
            let analyticsEvent = try XCTUnwrap(AnalyticsEvent(rawValue: event.rawValue))
            XCTAssertEqual(recording.events(named: analyticsEvent).count, 1)
        }
    }

    func testNoFakeReviewSubmittedEventExists() {
        XCTAssertNil(AnalyticsEvent(rawValue: "review_submitted"))
        XCTAssertNil(ReviewAnalyticsEvent(rawValue: "review_submitted"))
        XCTAssertNil(AnalyticsEvent(rawValue: "app_store_review_completed"))
    }

    func testEligibilityExactCountsAreBucketed() throws {
        reviewAnalytics.track(
            .reviewEligibilityReached,
            properties: ReviewAnalyticsProperties.base(
                appVersion: "1.2.0",
                triggerSource: ReviewPromptTriggerSource.returnedToMain.rawValue,
                decision: ReviewEligibilityDecision(
                    isEligible: true,
                    failureReasons: [],
                    daysSinceFirstUse: 7,
                    distinctActiveDays: 5,
                    meaningfulActionCount: 9
                )
            )
        )

        let event = try XCTUnwrap(recording.events(named: .reviewEligibilityReached).first)
        XCTAssertEqual(event.parameters[ReviewAnalyticsProperties.daysSinceFirstUseBucket], "5_plus")
        XCTAssertEqual(event.parameters[ReviewAnalyticsProperties.distinctActiveDaysBucket], "5_plus")
        XCTAssertEqual(event.parameters[ReviewAnalyticsProperties.meaningfulActionCountBucket], "5_plus")
        XCTAssertNil(event.parameters["days_since_first_use"])
        XCTAssertNil(event.parameters["distinct_active_days"])
        XCTAssertNil(event.parameters["meaningful_action_count"])
    }

    func testSanitizeDropsFreeTextAndUnknownKeys() {
        let sanitized = ReviewAnalyticsProperties.sanitize([
            "app_version": "1.0",
            "trigger_source": "meaningful_action",
            "message": "please fix recovery",
            "email": "user@example.com",
            "feedback_sentiment": "great"
        ])

        XCTAssertEqual(sanitized["feedback_sentiment"], "great")
        XCTAssertNil(sanitized["message"])
        XCTAssertNil(sanitized["email"])
    }

    func testUnknownTriggerSourceMapsToOther() {
        XCTAssertEqual(ReviewAnalyticsProperties.boundedTriggerSource("not_a_real_source"), "other")
    }
}
