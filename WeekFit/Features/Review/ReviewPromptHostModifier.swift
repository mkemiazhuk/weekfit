import SwiftUI

/// Tracks review eligibility from the main shell. Does not present a custom rating card.
struct ReviewPromptHostModifier: ViewModifier {
    @ObservedObject var reviewManager: ReviewPromptManager
    @EnvironmentObject private var appSession: AppSessionState
    @ObservedObject private var accountSession = AccountSessionController.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                syncUIBlocking()
                reviewManager.setApplicationActive(scenePhase == .active)
                reviewManager.recordAppOpen()
            }
            .onChange(of: scenePhase) { _, phase in
                reviewManager.setApplicationActive(phase == .active)
                if phase == .background {
                    reviewManager.cancelPendingSystemReviewRequest()
                }
            }
            .onChange(of: appSession.isPresentingOnboarding) { _, _ in syncUIBlocking() }
            .onChange(of: appSession.isPresentingHealthAccess) { _, _ in syncUIBlocking() }
            .onChange(of: appSession.isPresentingSettings) { _, _ in syncUIBlocking() }
            .onChange(of: accountSession.isTransitioning) { _, _ in syncUIBlocking() }
            .onChange(of: isUIBlocked) { _, blocked in
                reviewManager.updateUIBlocking(blocked)
            }
    }

    private var isUIBlocked: Bool {
        appSession.isPresentingOnboarding
            || appSession.isPresentingHealthAccess
            || appSession.isPresentingSettings
            || accountSession.isTransitioning
    }

    private func syncUIBlocking() {
        reviewManager.updateUIBlocking(isUIBlocked)
    }
}

extension View {
    func weekFitReviewPromptHost(manager: ReviewPromptManager) -> some View {
        modifier(ReviewPromptHostModifier(reviewManager: manager))
    }
}
