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

enum ReviewPromptPresentation: Equatable {
    case sentimentSheet(triggerSource: String)
    case feedbackForm(intent: FeedbackFormIntent, sentiment: FeedbackSentiment?, triggerSource: String)
}

/// Centralized eligibility, engagement tracking, and prompt presentation orchestration.
@MainActor
final class ReviewPromptManager: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown.
    nonisolated deinit {}

    @Published private(set) var presentation: ReviewPromptPresentation?
    @Published private(set) var lastDecision: ReviewEligibilityDecision?

    private let storage: ReviewPromptStoring
    private let analytics: ReviewAnalyticsTracking
    private let reviewRequester: StoreKitReviewRequesting
    private let feedbackService: FeedbackSubmissionServing
    private let clock: ReviewClock
    private let calendar: Calendar
    private let appVersionProvider: () -> String
    private let isReviewDemoMode: () -> Bool
    private let presentationDelayNanoseconds: UInt64

    private var state: ReviewEligibilityState
    private var isUIBlocked = false
    private var hasEmittedEligibilityReached = false
    private var isSchedulingPresentation = false
    private var pendingEvaluationTask: Task<Void, Never>?
    private var meaningfulActionObserver: NSObjectProtocol?

    init(
        storage: ReviewPromptStoring? = nil,
        analytics: ReviewAnalyticsTracking? = nil,
        reviewRequester: StoreKitReviewRequesting? = nil,
        feedbackService: FeedbackSubmissionServing? = nil,
        clock: ReviewClock? = nil,
        calendar: Calendar = .current,
        appVersionProvider: (() -> String)? = nil,
        isReviewDemoMode: (() -> Bool)? = nil,
        presentationDelayNanoseconds: UInt64 = 900_000_000,
        observesEngagementNotifications: Bool = true
    ) {
        let resolvedStorage = storage ?? ReviewPromptStorage()
        self.storage = resolvedStorage
        self.analytics = analytics ?? ReviewAnalytics.shared
        self.reviewRequester = reviewRequester ?? SystemStoreKitReviewRequester()
        self.feedbackService = feedbackService ?? MailtoFeedbackSubmissionService()
        self.clock = clock ?? SystemReviewClock()
        self.calendar = calendar
        self.appVersionProvider = appVersionProvider ?? {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        }
        self.isReviewDemoMode = isReviewDemoMode ?? {
            AccountSessionController.shared.mode == .reviewDemo
        }
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

        guard evaluatePrompt else { return }
        scheduleEligibilityEvaluation(triggerSource: .meaningfulAction)
    }

    func noteReturnedToStableMainScreen() {
        scheduleEligibilityEvaluation(triggerSource: .returnedToMain)
    }

    func updateUIBlocking(_ blocked: Bool) {
        isUIBlocked = blocked
        if blocked {
            pendingEvaluationTask?.cancel()
            pendingEvaluationTask = nil
            isSchedulingPresentation = false
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
            isUIBlocked: isUIBlocked || presentation != nil || isSchedulingPresentation,
            isReviewDemoMode: isReviewDemoMode()
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

    private func scheduleEligibilityEvaluation(triggerSource: ReviewPromptTriggerSource) {
        pendingEvaluationTask?.cancel()
        pendingEvaluationTask = Task { [weak self] in
            guard let self else { return }
            // Short delay so success animations / navigation can finish.
            try? await Task.sleep(nanoseconds: presentationDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.considerPresenting(triggerSource: triggerSource)
            }
        }
    }

    private func considerPresenting(triggerSource: ReviewPromptTriggerSource) {
        guard presentation == nil, !isSchedulingPresentation else { return }
        let decision = evaluateEligibility(triggerSource: triggerSource)
        guard decision.isEligible else { return }

        isSchedulingPresentation = true
        presentSentimentSheet(triggerSource: triggerSource)
        isSchedulingPresentation = false
    }

    // MARK: - Presentation API

    func presentSentimentSheet(triggerSource: ReviewPromptTriggerSource) {
        guard presentation == nil else { return }
        markPromptShown()
        presentation = .sentimentSheet(triggerSource: triggerSource.rawValue)
        analytics.track(
            .reviewFeedbackSheetShown,
            properties: ReviewAnalyticsProperties.base(
                appVersion: currentAppVersion,
                triggerSource: triggerSource.rawValue,
                decision: lastDecision
            )
        )
    }

    func openFeedbackForm(
        intent: FeedbackFormIntent,
        sentiment: FeedbackSentiment? = nil,
        triggerSource: ReviewPromptTriggerSource,
        present: Bool = true
    ) {
        if present {
            presentation = .feedbackForm(intent: intent, sentiment: sentiment, triggerSource: triggerSource.rawValue)
        }
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

    func selectSentiment(_ sentiment: FeedbackSentiment, triggerSource: String) {
        state.lastFeedbackSentimentRaw = sentiment.rawValue
        persist()

        analytics.track(
            .reviewFeedbackSelected,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": triggerSource,
                "feedback_sentiment": sentiment.analyticsName
            ]
        )

        switch sentiment {
        case .great:
            presentation = nil
            attemptNativeReview(triggerSource: triggerSource)
        case .okay, .needsImprovement:
            presentation = .feedbackForm(
                intent: .postSentiment,
                sentiment: sentiment,
                triggerSource: triggerSource
            )
            analytics.track(
                .feedbackFormOpened,
                properties: [
                    "app_version": currentAppVersion,
                    "trigger_source": triggerSource,
                    "feedback_sentiment": sentiment.analyticsName,
                    "feedback_intent": FeedbackFormIntent.postSentiment.rawValue
                ]
            )
        }
    }

    func dismissPresentation(trackAsDismissed: Bool = true) {
        if trackAsDismissed, presentation != nil {
            analytics.track(
                .feedbackDismissed,
                properties: [
                    "app_version": currentAppVersion,
                    "trigger_source": presentationTriggerSource
                ]
            )
        }
        presentation = nil
    }

    func rateFromSettings() {
        analytics.track(
            .rateWeekFitSelectedFromSettings,
            properties: ["app_version": currentAppVersion, "trigger_source": ReviewPromptTriggerSource.settingsRate.rawValue]
        )
        // Explicit Settings action: show the native in-app StoreKit sheet.
        // Do not consume soft-prompt version/cooldown state — Settings Rate must stay
        // available without suppressing the later sentiment flow.
        state.nativeReviewRequestAttemptDate = clock.now
        persist()
        analytics.track(
            .nativeReviewRequestAttempted,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": ReviewPromptTriggerSource.settingsRate.rawValue,
                "surface": "settings_in_app"
            ]
        )
        reviewRequester.requestReview()
    }

    func attemptNativeReview(triggerSource: String) {
        // Soft-prompt path: record attempt and mark this version as prompted.
        // Apple may still suppress the system dialog.
        state.nativeReviewRequestAttemptDate = clock.now
        state.lastPromptedAppVersion = currentAppVersion
        if state.lastFeedbackPromptDate == nil {
            state.lastFeedbackPromptDate = clock.now
        }
        persist()

        analytics.track(
            .nativeReviewRequestAttempted,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": triggerSource,
                "surface": "soft_prompt"
            ]
        )
        reviewRequester.requestReview()
    }

    func submitFeedback(_ draft: FeedbackDraft) async throws {
        let metadata = FeedbackMetadata.current(category: draft.category)
        let submission = FeedbackSubmission(draft: draft, metadata: metadata)
        try await feedbackService.submit(submission)

        analytics.track(
            .feedbackSubmitted,
            properties: [
                "app_version": currentAppVersion,
                "trigger_source": presentationTriggerSource,
                "feedback_sentiment": draft.sentiment?.analyticsName ?? "none",
                "feedback_category": draft.category?.analyticsName ?? "none"
            ]
        )
        presentation = nil
    }

    func setPermanentlyDismissed(_ dismissed: Bool) {
        state.isPermanentlyDismissed = dismissed
        persist()
    }

    // MARK: - Private

    private var presentationTriggerSource: String {
        switch presentation {
        case .sentimentSheet(let source):
            return source
        case .feedbackForm(_, _, let source):
            return source
        case nil:
            return "unknown"
        }
    }

    private func markPromptShown() {
        state.lastFeedbackPromptDate = clock.now
        state.lastPromptedAppVersion = currentAppVersion
        persist()
    }

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
