import XCTest
@testable import WeekFit

@MainActor
final class ReviewPromptManagerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var storage: ReviewPromptStorage!
    private var analytics: ReviewAnalytics!
    private var reviewRequester: RecordingStoreKitReviewRequester!
    private var writeReviewOpener: RecordingWriteReviewOpener!
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
        writeReviewOpener = RecordingWriteReviewOpener()
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
        writeReviewOpener = nil
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

    func testSameVersionSystemRequestIsSuppressed() async {
        await requestReviewAfterEligibleAction()

        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.alreadyPromptedThisVersion))
        XCTAssertTrue(decision.failureReasons.contains(.cooldownActive))
        XCTAssertEqual(manager.eligibilityState.systemReviewRequestVersion, "1.2.0")
        XCTAssertNotNil(manager.eligibilityState.nativeReviewRequestAttemptDate)
    }

    func testOneHundredTwentyDayCooldownWorks() async throws {
        await requestReviewAfterEligibleAction()
        let attempt = try XCTUnwrap(manager.eligibilityState.nativeReviewRequestAttemptDate)

        manager = makeManager(appVersion: "1.2.1", delayNanoseconds: 0)
        clock.now = calendarDate(addingDays: 30, to: attempt)
        reseedRecentActionKeepingHistory()

        let cooled = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertFalse(cooled.isEligible)
        XCTAssertTrue(cooled.failureReasons.contains(.cooldownActive))
        XCTAssertFalse(cooled.failureReasons.contains(.alreadyPromptedThisVersion))

        clock.now = calendarDate(addingDays: 120, to: attempt)
        reseedRecentActionKeepingHistory()
        let ready = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertTrue(ready.isEligible, "reasons: \(ready.failureReasons)")
    }

    func testPermanentDismissalWorks() {
        seedEligibleEngagement()
        manager.setPermanentlyDismissed(true)

        let decision = manager.evaluateEligibility(triggerSource: .meaningfulAction)
        XCTAssertFalse(decision.isEligible)
        XCTAssertTrue(decision.failureReasons.contains(.permanentlyDismissed))
    }

    func testEligibleActionRequestsStoreReviewOnce() async {
        await requestReviewAfterEligibleAction()

        XCTAssertEqual(reviewRequester.requestCount, 1)
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .nativeReviewRequestAttempted })
        XCTAssertEqual(
            analytics.recordedEvents.first { $0.event == .nativeReviewRequestAttempted }?.properties["surface"],
            "automatic"
        )
        XCTAssertFalse(analytics.recordedEvents.contains { $0.event == .reviewFeedbackSheetShown })
        XCTAssertFalse(analytics.recordedEvents.contains { $0.event == .appStoreWriteReviewOpened })
    }

    func testFeedbackFormDoesNotRequestStoreReview() async throws {
        seedEligibleEngagement()
        manager.openFeedbackForm(
            intent: .general,
            sentiment: nil,
            triggerSource: .settingsFeedback,
            present: false
        )
        try await manager.submitFeedback(
            FeedbackDraft(
                category: .other,
                message: "The plan list is hard to scan",
                allowContact: false,
                sentiment: nil,
                intent: .general
            )
        )
        manager.dismissPresentation(trackAsDismissed: true)

        XCTAssertEqual(reviewRequester.requestCount, 0)
        XCTAssertNil(manager.eligibilityState.nativeReviewRequestAttemptDate)
        XCTAssertNil(manager.eligibilityState.systemReviewRequestVersion)
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .feedbackFormOpened })
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .feedbackSubmitted })
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .feedbackDismissed })
        XCTAssertFalse(analytics.recordedEvents.contains { $0.event == .nativeReviewRequestAttempted })
    }

    func testBurstOfActionsRequestsReviewOnce() async {
        manager = makeManager(delayNanoseconds: 0)
        seedEligibleEngagement()

        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        manager.recordMeaningfulAction(.drinkLogged, evaluatePrompt: true)
        manager.recordMeaningfulAction(.planCreatedOrUpdated, evaluatePrompt: true)
        await waitForPendingReview()

        XCTAssertEqual(reviewRequester.requestCount, 1)

        manager.recordMeaningfulAction(.activityLoggedOrCompleted, evaluatePrompt: true)
        await waitForPendingReview()
        XCTAssertEqual(reviewRequester.requestCount, 1)
    }

    func testBackgroundOrBlockingScreenCancelsPendingRequest() async {
        manager = makeManager(delayNanoseconds: 400_000_000)
        seedEligibleEngagement()

        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        manager.cancelPendingSystemReviewRequest()
        manager.setApplicationActive(true)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(reviewRequester.requestCount, 0)
        XCTAssertNil(manager.eligibilityState.nativeReviewRequestAttemptDate)

        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        manager.updateUIBlocking(true)
        manager.updateUIBlocking(false)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(reviewRequester.requestCount, 0)

        manager.setApplicationActive(false)
        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(reviewRequester.requestCount, 0)
        XCTAssertNil(manager.eligibilityState.systemReviewRequestVersion)
    }

    func testLaunchAndForegroundDoNotRequestReview() async {
        seedEligibleEngagement()
        manager.recordAppOpen()
        manager.setApplicationActive(false)
        manager.setApplicationActive(true)
        await waitForPendingReview()
        XCTAssertEqual(reviewRequester.requestCount, 0)
    }

    func testFailedSystemCallDoesNotConsumeTheAttempt() async {
        manager = makeManager(delayNanoseconds: 0)
        seedEligibleEngagement()
        reviewRequester.acceptsRequest = false

        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        await waitForPendingReview()

        XCTAssertEqual(reviewRequester.requestCount, 1)
        XCTAssertNil(manager.eligibilityState.nativeReviewRequestAttemptDate)
        XCTAssertNil(manager.eligibilityState.systemReviewRequestVersion)
        XCTAssertFalse(analytics.recordedEvents.contains { $0.event == .nativeReviewRequestAttempted })

        reviewRequester.acceptsRequest = true
        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        await waitForPendingReview()
        XCTAssertEqual(reviewRequester.requestCount, 2)
        XCTAssertEqual(manager.eligibilityState.systemReviewRequestVersion, "1.2.0")
    }

    func testSettingsOpensWriteReviewPageWithoutSystemRequest() {
        seedEligibleEngagement()
        XCTAssertTrue(manager.openWriteReviewPage())

        XCTAssertEqual(writeReviewOpener.openCount, 1)
        XCTAssertEqual(reviewRequester.requestCount, 0)
        XCTAssertNil(manager.eligibilityState.nativeReviewRequestAttemptDate)
        XCTAssertNil(manager.eligibilityState.systemReviewRequestVersion)
        XCTAssertTrue(analytics.recordedEvents.contains { $0.event == .appStoreWriteReviewOpened })
        XCTAssertFalse(analytics.recordedEvents.contains { $0.event == .nativeReviewRequestAttempted })
        XCTAssertEqual(
            AppStoreReviewURL.writeReview?.absoluteString,
            "https://apps.apple.com/app/id6776311371?action=write-review"
        )
    }

    func testReviewDemoModeDoesNotRequestReview() async {
        manager = makeManager(isReviewDemo: true, delayNanoseconds: 0)
        seedEligibleEngagement()
        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        await waitForPendingReview()
        XCTAssertEqual(reviewRequester.requestCount, 0)
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

    func testRecoveryChallengeCompletedCountsAsMeaningfulAction() {
        manager.recordAppOpen()
        XCTAssertEqual(manager.eligibilityState.meaningfulActionCount, 0)

        manager.recordMeaningfulAction(.recoveryChallengeCompleted, evaluatePrompt: false)

        XCTAssertEqual(manager.eligibilityState.meaningfulActionCount, 1)
        XCTAssertEqual(MeaningfulAction.recoveryChallengeCompleted.rawValue, "recoveryChallengeCompleted")
        XCTAssertTrue(MeaningfulAction.allCases.contains(.recoveryChallengeCompleted))
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
            writeReviewOpener: writeReviewOpener,
            feedbackService: feedbackService,
            clock: clock,
            calendar: Calendar(identifier: .gregorian),
            appVersionProvider: { appVersion },
            isReviewDemoMode: { isReviewDemo },
            bypassEngagementThresholds: false,
            presentationDelayNanoseconds: delayNanoseconds,
            observesEngagementNotifications: false
        )
    }

    private func requestReviewAfterEligibleAction() async {
        manager = makeManager(delayNanoseconds: 0)
        seedEligibleEngagement()
        manager.recordMeaningfulAction(.foodLogged, evaluatePrompt: true)
        await waitForPendingReview()
    }

    private func waitForPendingReview() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
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

private final class RecordingWriteReviewOpener: AppStoreWriteReviewOpening {
    private(set) var openCount = 0

    @MainActor
    func openWriteReview() -> Bool {
        openCount += 1
        return true
    }
}

@MainActor
final class ReviewPromptMigrationTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var storage: ReviewPromptStorage!

    override func setUp() {
        super.setUp()
        suiteName = "weekfit.tests.review.migration.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        storage = ReviewPromptStorage(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        storage = nil
        suiteName = nil
        super.tearDown()
    }

    func testCustomCardHistoryIsNotASystemRequest() {
        defaults.set("1.2.0", forKey: ReviewPromptStorage.Keys.lastPromptedAppVersion)
        defaults.set(Date().timeIntervalSince1970, forKey: ReviewPromptStorage.Keys.lastFeedbackPromptDate)

        let state = storage.load()

        XCTAssertNil(state.systemReviewRequestVersion)
        XCTAssertNil(state.nativeReviewRequestAttemptDate)
        XCTAssertEqual(state.lastPromptedAppVersion, "1.2.0")
    }

    func testKnownSystemAttemptKeepsVersionAndDate() {
        let attempt = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(attempt.timeIntervalSince1970, forKey: ReviewPromptStorage.Keys.nativeReviewRequestAttemptDate)
        defaults.set("1.2.0", forKey: ReviewPromptStorage.Keys.lastPromptedAppVersion)

        let state = storage.load()

        XCTAssertEqual(state.systemReviewRequestVersion, "1.2.0")
        XCTAssertEqual(state.nativeReviewRequestAttemptDate, attempt)
    }

    func testSettingsOnlySystemAttemptKeepsCooldownWithoutVersion() {
        let attempt = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(attempt.timeIntervalSince1970, forKey: ReviewPromptStorage.Keys.nativeReviewRequestAttemptDate)

        let state = storage.load()

        XCTAssertNil(state.systemReviewRequestVersion)
        XCTAssertEqual(state.nativeReviewRequestAttemptDate, attempt)
    }

    func testMigrationDoesNotRewriteALaterSystemRequestFromTheLegacyCardVersion() {
        defaults.set("1.0.0", forKey: ReviewPromptStorage.Keys.lastPromptedAppVersion)
        _ = storage.load()

        var state = storage.load()
        let attempt = Date(timeIntervalSince1970: 1_800_000_000)
        state.systemReviewRequestVersion = "2.0.0"
        state.nativeReviewRequestAttemptDate = attempt
        storage.save(state)

        let reloaded = storage.load()
        XCTAssertEqual(reloaded.systemReviewRequestVersion, "2.0.0")
        XCTAssertEqual(reloaded.nativeReviewRequestAttemptDate, attempt)
    }

    func testDebugOverrideIsOffUnlessDebugFlagIsSet() {
        XCTAssertFalse(
            ReviewPromptDebugOverride.bypassesEngagementThresholds(defaults: defaults, arguments: [])
        )
        defaults.set(true, forKey: ReviewPromptDebugOverride.defaultsKey)
        #if DEBUG
        XCTAssertTrue(
            ReviewPromptDebugOverride.bypassesEngagementThresholds(defaults: defaults, arguments: [])
        )
        XCTAssertTrue(
            ReviewPromptDebugOverride.bypassesEngagementThresholds(
                defaults: defaults,
                arguments: [ReviewPromptDebugOverride.launchArgument]
            )
        )
        #else
        XCTAssertFalse(
            ReviewPromptDebugOverride.bypassesEngagementThresholds(
                defaults: defaults,
                arguments: [ReviewPromptDebugOverride.launchArgument]
            )
        )
        #endif
    }
}
