import Foundation
import SwiftUI
internal import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    /// True when the user has entered WeekFit (local or authenticated). Drives root vs welcome routing.
    /// This is **not** the same as Apple authentication.
    @Published var isLoggedIn = false
    @Published private(set) var hasResolvedInitialSession = false
    /// Published so Profile/Account can react immediately after Sign Out without a cold restart.
    @Published private(set) var isAppleSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// Apple (or App Review demo) authentication — independent of app-entry routing.
    var isAuthenticated: Bool {
        isAppleSignedIn || AppReviewDemoCredentials.hasActiveSession
    }

    /// Alias for clarity at call sites that mean app entry, not auth.
    var hasEnteredWeekFit: Bool { isLoggedIn }

    private let authService = AuthService()

    init() {
        StartupDiagnostics.step(9, "auth session restore", detail: "AuthViewModel.init")
        if AppReviewDemoCredentials.hasActiveSession {
            isLoggedIn = true
            isAppleSignedIn = false
            hasResolvedInitialSession = true
            StartupDiagnostics.step(9, "auth session restore", detail: "review demo session active")
        } else {
            Task {
                await restorePersistedSessionIfNeeded()
                hasResolvedInitialSession = true
                StartupDiagnostics.step(
                    9,
                    "auth session restore",
                    detail: "resolved hasEntered=\(isLoggedIn) apple=\(isAppleSignedIn)"
                )
            }
        }
    }

    var sessionCoordinationToken: String {
        "\(hasResolvedInitialSession)-\(isLoggedIn)-\(isAppleSignedIn)"
    }

    func signIn(with provider: AuthProvider) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.signIn(with: provider)
            AuthSessionStore.markWeekFitEntered()
            refreshAppleSignedInFlag()
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Enters WeekFit on-device without Apple. Opens/claims the local SQLite workspace.
    /// Does **not** create fake authentication state.
    func continueWithoutAccount() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        clearAppReviewDemoSession()
        AuthSessionStore.clearAppleSession()
        AuthSessionStore.markWeekFitEntered()
        WorkspaceOwnerStore.ensureLocalOwnerClaim()

        // Soft-attach: local entry never wipes just because a prior Apple owner marker exists.
        let incoming = WorkspaceOwnerStore.currentIdentityToken()
        if WorkspaceOwnerStore.requiresWorkspaceReset(forIncomingIdentity: incoming) {
            AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()
        }

        refreshAppleSignedInFlag()
        isLoggedIn = true
    }

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.signInWithEmail(
                email: email,
                password: password
            )

            if AppReviewDemoCredentials.matches(email: email, password: password) {
                AuthSessionStore.clear()
                AppReviewDemoCredentials.markSessionActive()
                refreshAppleSignedInFlag()
            } else {
                clearAppReviewDemoSession()
                AuthSessionStore.markWeekFitEntered()
                refreshAppleSignedInFlag()
            }

            isLoggedIn = true
        } catch {
            errorMessage = cleanError(error)
        }
    }

    func createAccountWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.createAccountWithEmail(
                email: email,
                password: password
            )

            clearAppReviewDemoSession()
            // New email identity must not inherit the previous account's on-device WeekFit data.
            AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()
            AuthSessionStore.markWeekFitEntered()
            refreshAppleSignedInFlag()
            isLoggedIn = true
        } catch {
            errorMessage = cleanError(error)
        }
    }

    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.sendPasswordReset(email: email)
            successMessage = "Password reset link sent to your email."
        } catch {
            errorMessage = cleanError(error)
        }
    }

    func handleAppleSignIn(
        _ result: Result<ASAuthorization, Error>
    ) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unable to read Apple credentials."
                return
            }

            do {
                clearAppReviewDemoSession()
                let previousApple = AuthSessionStore.appleUserID
                // Profile name is persisted inside handleAppleCredential before return.
                _ = try await authService.handleAppleCredential(credential)
                AuthSessionStore.markWeekFitEntered()
                WorkspaceOwnerStore.clearGuestToken()

                let incoming = WorkspaceOwnerStore.appleOwnerID(credential.user)
                // Local → Apple starts a clean Apple workspace. Only same Apple owner is kept.
                let shouldWipe =
                    (previousApple != nil && previousApple != credential.user)
                    || WorkspaceOwnerStore.requiresWorkspaceReset(forIncomingIdentity: incoming)
                if shouldWipe {
                    AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()
                } else {
                    WorkspaceOwnerStore.ownerID = incoming
                }

                WeekFitUserSettings.shared.refreshFromStorage()
                refreshAppleSignedInFlag()
                isLoggedIn = true
                // Land on Today after Sign in / Sign up with Apple (Profile dismisses via observers).
                NotificationCenter.default.post(name: .weekfitDidCompleteAppleSignIn, object: nil)
            } catch {
                errorMessage = cleanError(error)
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = cleanError(error)
        }
    }

    /// Ends Apple authentication and returns to the welcome/login entry screen.
    /// Preserves the local SQLite workspace — Sign Out is not Delete Account / Reset.
    func signOut() {
        Task {
            AppReviewDemoCredentials.clearSession()
            try? await authService.signOut()
            // Leave app-entry so ContentView routes to LoginView / welcome.
            AuthSessionStore.clearWeekFitEntry()
            WorkspaceOwnerStore.ensureLocalOwnerClaim()
            refreshAppleSignedInFlag()
            isLoggedIn = false
            errorMessage = nil
            successMessage = nil
        }
    }

    /// After Delete Account cleanup: clear auth + app-entry and return to welcome/login.
    func completeAccountDeletionSignOut() {
        AppReviewDemoCredentials.clearSession()
        AuthSessionStore.clear()
        WorkspaceOwnerStore.clearGuestToken()
        WorkspaceOwnerStore.ownerID = WorkspaceOwnerStore.localOwnerID
        refreshAppleSignedInFlag()
        isLoggedIn = false
        errorMessage = nil
        successMessage = nil
    }

    func applyUITestBypassIfNeeded() {
        guard WeekFitUITestSupport.isActive else { return }
        AuthSessionStore.markWeekFitEntered()
        isLoggedIn = true
        refreshAppleSignedInFlag()
        hasResolvedInitialSession = true
        isLoading = false
        errorMessage = nil
        OnboardingStore.markCompleted()
    }

    /// Test helper: sync published flags from AuthSessionStore without Apple UI.
    func syncPublishedAuthFlagsFromStoreForTests() {
        refreshAppleSignedInFlag()
        isLoggedIn = AuthSessionStore.hasEnteredWeekFit || AuthSessionStore.hasPersistedAppleSession
        hasResolvedInitialSession = true
    }

    func restorePersistedSessionIfNeeded() async {
        guard !WeekFitUITestSupport.isActive else { return }
        guard !isLoggedIn else { return }

        isLoading = true
        defer { isLoading = false }

        if await authService.restoreAppleSessionIfValid() {
            clearAppReviewDemoSession()
            AuthSessionStore.markWeekFitEntered()
            WorkspaceOwnerStore.clearGuestToken()
            AppleIdentityStore.restoreProfileIfNeeded(appleUserID: AuthSessionStore.appleUserID)
            if let appleUserID = AuthSessionStore.appleUserID {
                let incoming = WorkspaceOwnerStore.appleOwnerID(appleUserID)
                if WorkspaceOwnerStore.requiresWorkspaceReset(forIncomingIdentity: incoming) {
                    AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()
                } else {
                    WorkspaceOwnerStore.ownerID = incoming
                }
            }
            refreshAppleSignedInFlag()
            isLoggedIn = true
            return
        }

        // Local entry restore — not authentication.
        if AuthSessionStore.hasEnteredWeekFit {
            clearAppReviewDemoSession()
            WorkspaceOwnerStore.ensureLocalOwnerClaim()
            if let incoming = WorkspaceOwnerStore.currentIdentityToken(),
               WorkspaceOwnerStore.requiresWorkspaceReset(forIncomingIdentity: incoming) {
                AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()
            }
            refreshAppleSignedInFlag()
            isLoggedIn = true
        }
    }

    private func refreshAppleSignedInFlag() {
        isAppleSignedIn = AuthSessionStore.hasPersistedAppleSession
    }

    private func clearAppReviewDemoSession() {
        AppReviewDemoCredentials.clearSession()
    }

    private func cleanError(_ error: Error) -> String {
        let message = error.localizedDescription

        if message.lowercased().contains("invalid") {
            return "Invalid email or password."
        }

        if message.lowercased().contains("already") {
            return "This email is already registered."
        }

        if message.lowercased().contains("network") {
            return "Network error. Please try again."
        }

        return message
    }
}
