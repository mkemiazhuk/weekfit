import XCTest
@testable import WeekFit

@MainActor
final class ReviewPromptManagerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var storage: ReviewPromptStorage!
    private var analytics: ReviewAnalytics!
    private var reviewRequester: RecordingStoreKitReviewRequester!
    private var feedbackService: RecordingFeedbackSubmissionService!
    private var clock: FixedReviewClock!
    private var manager: ReviewPromptManager!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.review.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        storage = ReviewPromptStorage(defaults: defaults)
        analytics = ReviewAnalytics()
        reviewRequester = RecordingStoreKitReviewRequester()
        feedbackService = RecordingFeedbackSubmissionService()
        clock = FixedReviewClock(now: date(2026, 7, 23))
        manager = makeManager()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        storage = nil
        analytics = nil
        reviewRequester = nil
        feedbackService = nil
        clock = nil
        manager = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewUsersAreNotEligible() {
        manager.recordAppOpen()
        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)

        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.insufficientCalendarDays))
        XCTAssertTrue(decision.failureReasons.contains(.insufficientActiveDays))
        XCTAssertTrue(decision.failureReasons.contains(.insufficientMeaningfulActions))
    }

    func testEligibleAfterRequiredDaysActiveDaysAndActions() {
        seedEligibleEngagement()
        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)

        XCTAssertTrue(decision.isEligible, "reasons: \(decision.failureReasons)")
        XCTAssertGreaterThanOrEqual(decision.daysSinceFirstUse, 5)
        XCTAssertGreaterThanOrEqual(decision.distinctActiveDays, 5)
        XCTAssertGreaterThanOrEqual(decision.meaningfulActionCount, 5)
    }

    func testSameVersionPromptsAreSuppressed() {
        seedEligibleEngagement()
        manager.presentSentimentSheet(triggerSource: .meaningfulAction)
        manager.dismissPresentation(trackAsDismissed: true)

        let decision = manager.evaluateEligibility(triggerSource: .returnedToMain)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.alreadyPromptedThisVersion))
    }

    func testOneHundredTwentyDayCooldownWorks() {
        seedEligibleEngagement()
        manager.presentSentimentSheet(triggerSource: .meaningfulAction)
        manager.dismissPresentation(trackAsDismissed: false)

        // Simulate a new app version after prompt, still inside cooldown.
        manager = makeManager(appVersion: "1.2.1")
        clock.now = calendarDate(addingDays: 30, to: clock.now)
        reseedRecentActionKeepingHistory()

        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.cooldownActive))
        XCTAssertFalse(decision.failureReasons.contains(.alreadyPromptedThisVersion))
    }

    func testPermanentDismissalWorks() {
        seedEligibleEngagement()
        manager.setPermanentlyDismissed(true)

        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.permanentlyDismissed))
    }

    func testPositiveFeedbackAttemptsStoreKitReviewRequest() async {
        seedEligibleEngagement()
        manager.presentSentimentSheet(triggerSource: .meaningfulAction)
        manager.selectSentiment(.great, triggerSource: ReviewPromptTriggerSource.meaningfulAction.rawValue)

        XCTAssertNil(manager.presentation)
        XCTAssertEqual(reviewRequester.requestCount, 1)
        XCTAssertNotNil(manager.eligibilityState.nativeReviewRequestAttemptDate)
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .nativeReviewRequestAttempted })
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .reviewFeedbackSelected })
    }

    func testNeutralAndNegativeFeedbackOpenFeedbackForm() {
        seedEligibleEngagement()
        manager.presentSentimentSheet(triggerSource: .meaningfulAction)
        manager.selectSentiment(.okay, triggerSource: ReviewPromptTriggerSource.meaningfulAction.rawValue)

        guard case .feedbackForm(let intent, let sentiment, _) = manager.presentation else {
            return XCTFail("Expected feedback form presentation")
        }
        XCTAssertEqual(intent, .postSentiment)
        XCTAssertEqual(sentiment, .okay)

        manager.dismissPresentation(trackAsDismissed: false)
        manager.presentSentimentSheet(triggerSource: .meaningfulAction)
        // Already prompted this version — presentation API still allows explicit reopen for test path.
        // Use select after forcing presentation for negative path:
        manager.selectSentiment(.needsImprovement, triggerSource: "test")
        guard case .feedbackForm(_, let negativeSentiment, _) = manager.presentation else {
            return XCTFail("Expected negative feedback form")
        }
        XCTAssertEqual(negativeSentiment, .needsImprovement)
    }

    func testRepeatedEligibilityChecksDoNotDuplicatePromptPresentation() async {
        seedEligibleEngagement()
        manager = makeManager(delayNanoseconds: 0)

        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        // Allow scheduled task to run.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(manager.presentation, .sentimentSheet(triggerSource: ReviewPromptTriggerSource.meaningfulAction.rawValue))

        // Second evaluation while already presenting must not replace / re-fire sheet shown.
        let shownCountBefore = analytics.recordedEvents.filter { $0.event == .reviewFeedbackSheetShown }.count
        manager.noteReturnedToStableMainScreen()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let shownCountAfter = analytics.recordedEvents.filter { $0.event == .reviewFeedbackSheetShown }.count

        XCTAssertEqual(shownCountBefore, 1)
        XCTAssertEqual(shownCountAfter, 1)
    }

    func testHealthDataValuesAreNeverRequiredForEligibility() {
        // Eligibility uses only engagement counters — no recovery score / HRV / sleep inputs exist on the API.
        seedEligibleEngagement()
        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertTrue(decision.isEligible)

        let mirrorChildren = Mirror(reflecting: decision).children.map(\.label)
        XCTAssertFalse(mirrorChildren.contains(where: { ($0 ?? "").lowercased().contains("recovery") }))
        XCTAssertFalse(mirrorChildren.contains(where: { ($0 ?? "").lowercased().contains("health") }))
    }

    func testSensitiveHealthDataNotIncludedInFeedbackMetadataOrAnalytics() async throws {
        let metadata = FeedbackMetadata.current(category: .recovery)
        let keys = Set(metadata.dictionaryRepresentation.keys)
        XCTAssertEqual(
            keys,
            ["app_version", "build_number", "ios_version", "device_model", "locale", "feedback_category"]
        )
        XCTAssertFalse(keys.contains("recovery_score"))
        XCTAssertFalse(keys.contains("hrv"))
        XCTAssertFalse(keys.contains("heart_rate"))

        let clipboard = metadata.diagnosticClipboardText
        XCTAssertTrue(clipboard.contains("WeekFit \(metadata.appVersion) (\(metadata.buildNumber))"))
        XCTAssertTrue(clipboard.contains("iOS \(metadata.iOSVersion)"))
        XCTAssertTrue(clipboard.contains(metadata.deviceModel))
        XCTAssertFalse(clipboard.localizedCaseInsensitiveContains("email"))
        XCTAssertFalse(clipboard.localizedCaseInsensitiveContains("user"))
        XCTAssertFalse(clipboard.localizedCaseInsensitiveContains("hrv"))
        XCTAssertFalse(clipboard.localizedCaseInsensitiveContains("recovery"))

        try await manager.submitFeedback(
            FeedbackDraft(
                category: .recovery,
                message: "Recovery card is confusing",
                allowContact: false,
                sentiment: .okay,
                intent: .postSentiment
            )
        )

        let submitted = try XCTUnwrap(feedbackService.submissions.first)
        XCTAssertEqual(Set(submitted.metadata.dictionaryRepresentation.keys), keys)

        for event in analytics.recordedEvents {
            for key in event.properties.keys {
                XCTAssertFalse(key.contains("recovery_score"))
                XCTAssertFalse(key.contains("hrv"))
                XCTAssertFalse(key.contains("token"))
            }
        }
    }

    func testUIBlockedPreventsEligibility() {
        seedEligibleEngagement()
        manager.updateUIBlocking(true)
        let decision = manager.evaluateEligibility(triggerSource: .returnedToMain)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.uiBlocked))
    }

    func testReviewDemoModePreventsEligibility() {
        seedEligibleEngagement()
        manager = makeManager(isReviewDemo: true)
        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.reviewDemoMode))
    }

    // MARK: - Helpers

    private func makeManager(
        appVersion: String = "1.2.0",
        isReviewDemo: Bool = false,
        delayNanoseconds: UInt64 = 900_000_000
    ) -> ReviewPromptManager {
        ReviewPromptManager(
            storage: storage,
            analytics: analytics,
            reviewRequester: reviewRequester,
            feedbackService: feedbackService,
            clock: clock,
            calendar: Calendar(identifier: .gregorian),
            appVersionProvider: { appVersion },
            isReviewDemoMode: { isReviewDemo },
            presentationDelayNanoseconds: delayNanoseconds,
            observesEngagementNotifications: false
        )
    }

    private func seedEligibleEngagement() {
        let start = date(2026, 7, 18)
        clock.now = start
        manager.recordAppOpen()

        // 5 distinct active days with actions (Jul 18–22).
        for offset in 0..<5 {
            clock.now = calendarDate(addingDays: offset, to: start)
            manager.recordAppOpen()
            manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: false)
        }

        // Advance to day +5 so calendar-days-since-first-use == 5,
        // while keeping the last action within the recent window.
        clock.now = calendarDate(addingDays: 5, to: start)
    }

    private func reseedRecentActionKeepingHistory() {
        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: false)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func calendarDate(addingDays days: Int, to base: Date) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: base)!
    }
}
