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

    /// True until app-entry / Apple restore finishes. Showing Login before this causes a
    /// flash of the welcome screen on every cold start for users who already entered WeekFit.
    private var isResolvingInitialSession: Bool {
        !authViewModel.hasResolvedInitialSession
    }

    /// Root mounts from **app entry**, not Apple authentication.
    /// Local (unauthenticated) users who have entered WeekFit stay in the main app.
    private var shouldShowRoot: Bool {
        authViewModel.hasEnteredWeekFit
            && isAuthenticatedSessionReady
            && !accountSession.isTransitioning
    }

    var body: some View {
        // Force production store open before branching UI so loadFailure is populated.
        let _ = accountSession.activeContainer
        Group {
            if let failure = WeekFitModelContainer.productionLoadFailure {
                PersistenceStartupFailureView(failure: failure)
            } else {
                normalRoot
            }
        }
        .modelContainer(accountSession.activeContainer)
        .onAppear {
            StartupDiagnostics.step(
                7,
                "root view created",
                detail: "ContentView.body ready persistenceFailed=\(WeekFitModelContainer.didFailToLoadProductionStore)"
            )
            #if DEBUG
            authViewModel.applyUITestBypassIfNeeded()
            #endif
        }
    }

    @ViewBuilder
    private var normalRoot: some View {
        ZStack {
            Group {
                if shouldShowRoot {
                    WeekFitRootView(authViewModel: authViewModel)
                        .id(accountSession.containerIdentity)
                        .onAppear {
                            StartupDiagnostics.step(
                                7,
                                "root view created",
                                detail: "WeekFitRootView mounted mode=\(String(describing: accountSession.mode))"
                            )
                        }
                } else if authViewModel.hasResolvedInitialSession, !authViewModel.hasEnteredWeekFit {
                    LoginView(authViewModel: authViewModel)
                        .onAppear {
                            StartupDiagnostics.step(
                                7,
                                "root view created",
                                detail: "LoginView mounted"
                            )
                        }
                }
            }

            if isResolvingInitialSession
                || accountSession.isTransitioning
                || (authViewModel.hasEnteredWeekFit && !isAuthenticatedSessionReady) {
                AccountTransitionView()
            }
        }
        .task(id: authViewModel.sessionCoordinationToken) {
            guard authViewModel.hasResolvedInitialSession else { return }
            StartupDiagnostics.step(
                8,
                "account session apply",
                detail: "hasEntered=\(authViewModel.hasEnteredWeekFit) apple=\(authViewModel.isAppleSignedIn)"
            )
            await AccountSessionCoordinator.applySessionState(
                isLoggedIn: authViewModel.hasEnteredWeekFit,
                accountSession: accountSession,
                healthManager: healthManager,
                activityCoordinator: activityCoordinator,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                appSession: appSession
            )
            StartupDiagnostics.step(
                8,
                "account session apply",
                detail: "complete mode=\(String(describing: accountSession.mode))"
            )
        }
    }
}

/// Shown when the on-disk SwiftData store cannot be opened. Does not delete or reset data.
private struct PersistenceStartupFailureView: View {
    let failure: WeekFitModelContainer.PersistenceLoadFailure

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WeekFit couldn’t open local data")
                .font(.title2.weight(.semibold))
            Text("Your on-disk store was not deleted. Capture the STARTUP logs from Console, then we can fix the open failure.")
                .font(.body)
                .foregroundStyle(.secondary)
            Group {
                Text("error: \(failure.errorDescription)")
                if let domain = failure.errorDomain, let code = failure.errorCode {
                    Text("domain/code: \(domain) / \(code)")
                }
                if let url = failure.storeURL {
                    Text("store: \(url.lastPathComponent)")
                }
                if let existed = failure.storeExisted {
                    Text("store existed: \(existed)")
                }
                if let bytes = failure.storeByteCount {
                    Text("store bytes: \(bytes)")
                }
                Text("last step: \(StartupDiagnostics.lastCompletedStep)")
            }
            .font(.footnote.monospaced())
            .textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            StartupDiagnostics.step(
                2,
                "persistence init",
                detail: "showing PersistenceStartupFailureView (no data wipe)"
            )
        }
    }
}

private struct AccountTransitionView: View {
    var body: some View {
        ZStack {
            // Opaque — used for cold-start session restore as well as account switches.
            Color.black
                .ignoresSafeArea()
            ProgressView()
                .tint(.white.opacity(0.85))
        }
        .accessibilityLabel("Loading")
    }
}
