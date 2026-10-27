import Foundation
internal import Combine

protocol ReviewClock: AnyObject {
    var now: Date { get }
}

final class SystemReviewClock: ReviewClock {
    nonisolated init() {}
    var now: Date { Date() }
}

final class FixedReviewClock: ReviewClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

enum ReviewPromptTriggerSource: String, Sendable {
    case meaningfulAction = "meaningful_action"
    case returnedToMain = "returned_to_main"
    case settingsRate = "settings_rate"
    case settingsFeedback = "settings_feedback"
    case settingsFeature = "settings_feature"
    case settingsProblem = "settings_problem"
}

/// Eligibility, engagement, and the direct system review request.
@MainActor
final class ReviewPromptManager: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown.
    nonisolated deinit {}

    @Published private(set) var lastDecision: ReviewEligibilityDecision?

    private let storage: ReviewPromptStoring
    private let analytics: ReviewAnalyticsTracking
    private let reviewRequester: StoreKitReviewRequesting
    private let writeReviewOpener: AppStoreWriteReviewOpening
    private let feedbackService: FeedbackSubmissionServing
    private let clock: ReviewClock
    private let calendar: Calendar
    private let appVersionProvider: () -> String
    private let isReviewDemoMode: () -> Bool
    private let bypassEngagementThresholds: Bool
    private let presentationDelayNanoseconds: UInt64

    private var state: ReviewEligibilityState
    private var isUIBlocked = false
    private var isApplicationActive = true
    private var hasEmittedEligibilityReached = false
    private var pendingEvaluationTask: Task<Void, Never>?
    private var meaningfulActionObserver: NSObjectProtocol?
    private var lastFeedbackTriggerSource = "unknown"

    init(
        storage: ReviewPromptStoring? = nil,
        analytics: ReviewAnalyticsTracking? = nil,
        reviewRequester: StoreKitReviewRequesting? = nil,
        writeReviewOpener: AppStoreWriteReviewOpening? = nil,
        feedbackService: FeedbackSubmissionServing? = nil,
        clock: ReviewClock? = nil,
        calendar: Calendar = .current,
        appVersionProvider: (() -> String)? = nil,
        isReviewDemoMode: (() -> Bool)? = nil,
        bypassEngagementThresholds: Bool? = nil,
        presentationDelayNanoseconds: UInt64 = 900_000_000,
        observesEngagementNotifications: Bool = true
    ) {
        let resolvedStorage = storage ?? ReviewPromptStorage()
        self.storage = resolvedStorage
        self.analytics = analytics ?? ReviewAnalytics.shared
        self.reviewRequester = reviewRequester ?? SystemStoreKitReviewRequester()
        self.writeReviewOpener = writeReviewOpener ?? SystemAppStoreWriteReviewOpener()
        self.feedbackService = feedbackService ?? MailtoFeedbackSubmissionService()
        self.clock = clock ?? SystemReviewClock()
        self.calendar = calendar
        self.appVersionProvider = appVersionProvider ?? {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        }
        self.isReviewDemoMode = isReviewDemoMode ?? {
            AccountSessionController.shared.mode == .reviewDemo
        }
        self.bypassEngagementThresholds = bypassEngagementThresholds
            ?? ReviewPromptDebugOverride.bypassesEngagementThresholds()
        self.presentationDelayNanoseconds = presentationDelayNanoseconds
        self.state = resolvedStorage.load()

        if observesEngagementNotifications {
            meaningfulActionObserver = NotificationCenter.default.addObserver(
                forName: .weekfitMeaningfulAction,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let raw = notification.userInfo?[ReviewEngagement.actionUserInfoKey] as? String,
                      let action = MeaningfulAction(rawValue: raw) else { return }
                Task { @MainActor in
                    self?.recordMeaningfulAction(action)
                }
            }
        }
    }

    var currentAppVersion: String { appVersionProvider() }

    var eligibilityState: ReviewEligibilityState { state }

    // MARK: - Lifecycle / engagement

    func recordAppOpen(on date: Date? = nil) {
        let now = date ?? clock.now
        ensureFirstUse(now)
        recordActiveDay(now)
        persist()
    }

    func recordMeaningfulAction(_ action: MeaningfulAction, evaluatePrompt: Bool = true) {
        let now = clock.now
        ensureFirstUse(now)
        recordActiveDay(now)
        state.meaningfulActionCount += 1
        state.lastMeaningfulActionDate = now
        persist()

        guard evaluatePrompt, !isUIBlocked else { return }
        scheduleSystemReviewRequest()
    }

    func setApplicationActive(_ isActive: Bool) {
        isApplicationActive = isActive
    }

    func cancelPendingSystemReviewRequest() {
        pendingEvaluationTask?.cancel()
        pendingEvaluationTask = nil
    }

    func updateUIBlocking(_ blocked: Bool) {
        isUIBlocked = blocked
        if blocked {
            cancelPendingSystemReviewRequest()
        }
    }

    // MARK: - Eligibility

    @discardableResult
    func evaluateEligibility(triggerSource: ReviewPromptTriggerSource) -> ReviewEligibilityDecision {
        let decision = ReviewEligibilityEvaluator.evaluate(
            state: state,
            now: clock.now,
            calendar: calendar,
            currentAppVersion: currentAppVersion,
            isUIBlocked: isUIBlocked,
            isReviewDemoMode: isReviewDemoMode(),
            bypassEngagementThresholds: bypassEngagementThresholds
        )
        lastDecision = decision

        if decision.isEligible, !hasEmittedEligibilityReached {
            hasEmittedEligibilityReached = true
            analytics.track(
                .reviewEligibilityReached,
                properties: ReviewAnalyticsProperties.base(
                    appVersion: currentAppVersion,
                    triggerSource: triggerSource.rawValue,
                    decision: decision
                )
            )
        }

        return decision
    }

    private func scheduleSystemReviewRequest() {
        pendingEvaluationTask?.cancel()
        pendingEvaluationTask = Task { [weak self] in
            guard let self else { return }
            // Wait until the completed action's UI has settled.
            try? await Task.sleep(nanoseconds: presentationDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.considerSystemReviewRequest()
            }
        }
    }

    private func considerSystemReviewRequest() {
        guard isApplicationActive, !isUIBlocked else { return }
        let decision = evaluateEligibility(triggerSource: .meaningfulAction)
        guard decision.isEligible else { return }
        // Persist only after the system API is actually invoked. iOS may still hide the dialog.
        guard reviewRequester.requestReview() else { return }
        state.nativeReviewRequestAttemptDate = clock.now
        state.systemReviewRequestVersion = currentAppVersion
        persist()
        analytics.track(
            .nativeReviewRequestAttempted,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": ReviewPromptTriggerSource.meaningfulAction.rawValue,
                "surface": "automatic"
            ]
        )
    }

    // MARK: - Settings and feedback

    /// Opens the App Store write-review page. Does not call `requestReview` or consume an attempt.
    @discardableResult
    func openWriteReviewPage() -> Bool {
        let opened = writeReviewOpener.openWriteReview()
        guard opened else { return false }
        analytics.track(
            .appStoreWriteReviewOpened,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": ReviewPromptTriggerSource.settingsRate.rawValue,
                "surface": "app_store_write_review"
            ]
        )
        return true
    }

    func openFeedbackForm(
        intent: FeedbackFormIntent,
        sentiment: FeedbackSentiment? = nil,
        triggerSource: ReviewPromptTriggerSource,
        present: Bool = true
    ) {
        _ = present
        lastFeedbackTriggerSource = triggerSource.rawValue
        analytics.track(
            .feedbackFormOpened,
            properties: ReviewAnalyticsProperties.base(
                appVersion: currentAppVersion,
                triggerSource: triggerSource.rawValue,
                decision: lastDecision
            ).merging([
                "feedback_sentiment": sentiment?.analyticsName ?? "none",
                "feedback_intent": intent.rawValue
            ]) { _, new in new }
        )
    }

    func dismissPresentation(trackAsDismissed: Bool = true) {
        guard trackAsDismissed else { return }
        analytics.track(
            .feedbackDismissed,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": lastFeedbackTriggerSource
            ]
        )
    }

    func submitFeedback(_ draft: FeedbackDraft) async throws {
        let metadata = FeedbackMetadata.current(category: draft.category)
        let submission = FeedbackSubmission(draft: draft, metadata: metadata)
        try await feedbackService.submit(submission)

        analytics.track(
            .feedbackSubmitted,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": lastFeedbackTriggerSource,
                "feedback_sentiment": draft.sentiment?.analyticsName ?? "none",
                "feedback_category": draft.category?.analyticsName ?? "none"
            ]
        )
    }

    func setPermanentlyDismissed(_ dismissed: Bool) {
        state.isPermanentlyDismissed = dismissed
        persist()
    }

    // MARK: - Private

    private func ensureFirstUse(_ now: Date) {
        if state.firstAppUseDate == nil {
            state.firstAppUseDate = now
        }
    }

    private func recordActiveDay(_ now: Date) {
        let dayStart = calendar.startOfDay(for: now).timeIntervalSince1970
        if !state.activeDayTimestamps.contains(where: { abs($0 - dayStart) < 0.5 }) {
            state.activeDayTimestamps.append(dayStart)
        }
    }

    private func persist() {
        storage.save(state)
    }
}
