import Foundation
import SwiftUI
internal import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}
    @Published var isLoggedIn = false
    @Published private(set) var hasResolvedInitialSession = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var isAuthenticated: Bool {
        isLoggedIn
    }

    private let authService = AuthService()

    /// Cloud sync + account sign-in are not shipped yet; login screen stays the entry point.
    private static let accountAuthEnabled = false

    init() {
        if AppReviewDemoCredentials.hasActiveSession {
            isLoggedIn = true
            hasResolvedInitialSession = true
        } else {
            Task {
                await restorePersistedSessionIfNeeded()
                hasResolvedInitialSession = true
            }
        }
    }

    var sessionCoordinationToken: String {
        "\(hasResolvedInitialSession)-\(isLoggedIn)"
    }

    func signIn(with provider: AuthProvider) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            try await authService.signIn(with: provider)
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
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
                AppReviewDemoCredentials.markSessionActive()
            } else {
                clearAppReviewDemoSession()
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
            // New identity must not inherit the previous account's on-device WeekFit data.
            AccountSessionController.shared.requestLocalDataResetOnNextRealUserEntry()
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
                _ = try await authService.handleAppleCredential(credential)
                isLoggedIn = true
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

    func signOut() {
        Task {
            AppReviewDemoCredentials.clearSession()
            try? await authService.signOut()
            isLoggedIn = false
            errorMessage = nil
            successMessage = nil
        }
    }

    /// Completes account deletion after local/cloud cleanup and the success confirmation.
    /// Tokens and demo session flags are already cleared by `AccountDeletionService`.
    func completeAccountDeletionSignOut() {
        AppReviewDemoCredentials.clearSession()
        AuthSessionStore.clear()
        isLoggedIn = false
        errorMessage = nil
        successMessage = nil
    }

    func applyUITestBypassIfNeeded() {
        guard WeekFitUITestSupport.isActive else { return }
        isLoggedIn = true
        hasResolvedInitialSession = true
        isLoading = false
        errorMessage = nil
    }

    func restorePersistedSessionIfNeeded() async {
        guard !WeekFitUITestSupport.isActive else { return }
        guard !isLoggedIn else { return }

        isLoading = true
        defer { isLoading = false }

        if await authService.restoreAppleSessionIfValid() {
            clearAppReviewDemoSession()
            isLoggedIn = true
        }
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
