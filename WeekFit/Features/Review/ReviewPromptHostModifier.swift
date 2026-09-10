import SwiftUI

/// Hosts the automated review/feedback prompt overlay on the main shell.
struct ReviewPromptHostModifier: ViewModifier {
    @ObservedObject var reviewManager: ReviewPromptManager
    @EnvironmentObject private var appSession: AppSessionState
    @ObservedObject private var accountSession = AccountSessionController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                promptOverlay
            }
            .sheet(item: feedbackFormBinding) { presentation in
                NavigationStack {
                    FeedbackFormView(
                        manager: reviewManager,
                        intent: presentation.intent,
                        sentiment: presentation.sentiment,
                        triggerSource: presentation.triggerSource
                    )
                }
                .presentationDetents([.large])
                .weekFitSheetChrome(cornerRadius: 36)
            }
            .onAppear {
                syncUIBlocking()
                reviewManager.recordAppOpen()
            }
            .onChange(of: appSession.isPresentingOnboarding) { _, _ in syncUIBlocking() }
            .onChange(of: appSession.isPresentingHealthAccess) { _, _ in syncUIBlocking() }
            .onChange(of: accountSession.isTransitioning) { _, _ in syncUIBlocking() }
            .onChange(of: isUIBlocked) { _, blocked in
                reviewManager.updateUIBlocking(blocked)
                if !blocked {
                    reviewManager.noteReturnedToStableMainScreen()
                }
            }
    }

    private var isUIBlocked: Bool {
        appSession.isPresentingOnboarding
            || appSession.isPresentingHealthAccess
            || accountSession.isTransitioning
    }

    private func syncUIBlocking() {
        reviewManager.updateUIBlocking(isUIBlocked)
    }

    @ViewBuilder
    private var promptOverlay: some View {
        if case .sentimentSheet(let triggerSource) = reviewManager.presentation {
            FeedbackSheetView(
                onSelect: { sentiment in
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.86)) {
                        reviewManager.selectSentiment(sentiment, triggerSource: triggerSource)
                    }
                },
                onDismiss: {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.86)) {
                        reviewManager.dismissPresentation(trackAsDismissed: true)
                    }
                }
            )
        }
    }

    private var feedbackFormBinding: Binding<FeedbackFormSheetItem?> {
        Binding(
            get: {
                if case .feedbackForm(let intent, let sentiment, let triggerSource) = reviewManager.presentation {
                    return FeedbackFormSheetItem(intent: intent, sentiment: sentiment, triggerSource: triggerSource)
                }
                return nil
            },
            set: { newValue in
                if newValue == nil, case .feedbackForm = reviewManager.presentation {
                    reviewManager.dismissPresentation(trackAsDismissed: true)
                }
            }
        )
    }
}

private struct FeedbackFormSheetItem: Identifiable {
    let intent: FeedbackFormIntent
    let sentiment: FeedbackSentiment?
    let triggerSource: String

    var id: String {
        "\(intent.rawValue)-\(sentiment?.rawValue ?? "none")-\(triggerSource)"
    }
}

extension View {
    func weekFitReviewPromptHost(manager: ReviewPromptManager) -> some View {
        modifier(ReviewPromptHostModifier(reviewManager: manager))
    }
}
