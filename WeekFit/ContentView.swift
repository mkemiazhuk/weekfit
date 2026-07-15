import SwiftUI
import SwiftData

struct ContentView: View {

    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var accountSession = AccountSessionController.shared
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator
    @EnvironmentObject private var appSession: AppSessionState

    private var isAuthenticatedSessionReady: Bool {
        accountSession.mode == .reviewDemo || accountSession.mode == .realUser
    }

    var body: some View {
        ZStack {
            Group {
                if authViewModel.isLoggedIn, isAuthenticatedSessionReady {
                    WeekFitRootView(authViewModel: authViewModel)
                        .id(accountSession.containerIdentity)
                } else if !authViewModel.isLoggedIn {
                    LoginView(authViewModel: authViewModel)
                }
            }
            .opacity(accountSession.isTransitioning ? 0 : 1)

            if accountSession.isTransitioning
                || (authViewModel.isLoggedIn && !isAuthenticatedSessionReady) {
                AccountTransitionView()
            }
        }
        .modelContainer(accountSession.activeContainer)
        .task(id: authViewModel.sessionCoordinationToken) {
            guard authViewModel.hasResolvedInitialSession else { return }
            await AccountSessionCoordinator.applySessionState(
                isLoggedIn: authViewModel.isLoggedIn,
                accountSession: accountSession,
                healthManager: healthManager,
                activityCoordinator: activityCoordinator,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
        }
        .onAppear {
            #if DEBUG
            authViewModel.applyUITestBypassIfNeeded()
            #endif
        }
    }
}

private struct AccountTransitionView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            ProgressView()
                .tint(.white.opacity(0.85))
        }
        .accessibilityLabel("Switching account")
    }
}
